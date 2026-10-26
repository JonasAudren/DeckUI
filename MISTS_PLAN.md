# DeckUI für Mists of Pandaria Classic – Migrationsplan

Stand: 25.10.2026 · Grundlage: DeckUI 1.7.1 (Retail 12.1.5) · Ziel-Client: **MoP Classic 5.5.4, Build 70579**
Noch nichts am Addon geändert – dies ist nur der Plan plus vorbereitete Werkzeuge (`tools/mists/`).

---

## 0. Kurzfassung

**Die gute Nachricht:** MoP Classic 5.5.4 läuft auf derselben modernen Engine wie Midnight. Fast alles, was DeckUI an
„neuer“ Technik nutzt, gibt es dort auch: `issecretvalue`, `SetAlphaFromBoolean`, Duration-Objekte und
`UnitCastingDuration` (Zauberbalken), `C_UnitAuras`, `C_GamePad`, `C_AddOnProfiler`, Edit Mode samt `C_EditMode`,
`MenuUtil`, `TooltipDataProcessor`, das moderne Auktionshaus mit `C_AuctionHouse.ReplicateItems`. Die
**Aktionsleisten-Kerndateien sind sogar identisch** mit Retail (`ActionBar.lua`, `MultiActionBars.lua`,
`VehicleLeaveButton.lua`, inklusive `MultiBar5`–`7` und denselben Tastenbefehlen).

**Die Arbeit liegt woanders:** Was in DeckUI *Spielinhalt* von The War Within/Midnight abbildet, gibt es in MoP nicht
(Großes Gewölbe, Wappen, Tiefen, Beute-Jagd, Kampagnen, Weltquests, Kriegsmeute-Bank, Blizzard-Navigation/Wegpunkte,
Talking Head, Schadensmesser, Taschen sortieren). Und zwei technische Brocken:

1. **oUF / Auren**: Unser oUF 14 baut Buffs/Debuffs auf Blizzards `CustomAuraContainer` – den liefert MoP **nicht** aus.
   Außerdem ruft der oUF-Kern `SetRolesets` auf (fehlt in MoP). → Lösung: oUF 14 behalten, 4 Stellen absichern und
   für MoP einen **Aura-Container-Ersatz** bauen, der genau die Teile nachbildet, die DeckUI benutzt.
2. **Klassische Systeme**: Bank (alte Bank mit Taschenplätzen), Taschenknöpfe (Classic-Template ohne Mixin),
   Questlog (alte API, `WatchFrame` statt `ObjectiveTracker`), Dual-Spec statt Spec-Wechsel, MoP-Klassenressourcen
   (Schattenkugeln, Glut, Dämonischer Furor, Eklipse, Todesrunen).

**Empfehlung:** Ein Repository, eine Codebasis, **zweite Toc-Datei je Ordner** (`<Name>_Mists.toc`, Interface 50504),
eine gemeinsame Zip für Retail und MoP. Reihenfolge nach Nutzen: erst Grundgerüst + Cross + Orbs (spielbar),
dann Taschen/Tooltip/Karte, zuletzt Quests/Nav/Week (die am meisten neu brauchen).

**Erster Schritt erledigt (25.10.2026):** Das Prüf-Addon `DeckUI_Probe` lief im MoP-Client (Paladin Stufe 1,
enUS, Everlook) fehlerfrei. Es bestätigt die statische Analyse fast vollständig; die Abweichungen stehen in
Abschnitt 3a und sind unten eingearbeitet. Die wichtigsten:
- Den **Kampfassistenten gibt es in MoP** (`C_AssistedCombat`, `IsAssistedCombatAction`), `assist.lua` bleibt drin.
- Die **Spec-Funktionen gibt es nur im Namensraum** (`C_SpecializationInfo.*`). Die globalen `GetSpecialization`,
  `GetSpecializationInfo` und `SetActiveSpecGroup` sind nil.
- `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` **existiert** in MoP. Kein Event-Tausch nötig.
- **Keine Raritäten auf dem Kompass**: `C_VignetteInfo` fehlt.
- **Koordinaten-CVars fehlen** auf Welt- und Minikarte.

---

## 1. Was geprüft wurde – und wie

| Quelle | Inhalt |
|---|---|
| Installierter Client | `C:\Spiele\World of Warcraft\_classic_`, Produkt `wow_classic`, **5.5.4.70579** (`.build.info`) |
| Blizzards UI-Code MoP | Gethe/wow-ui-source, Branch `classic`, Commit `eb90f45fdf` = exakt 5.5.4 (70579) |
| Blizzards UI-Code Retail | Branch `live`, 12.1.5 (70448) – zum Vergleich |
| Spieldaten MoP | wago.tools `?branch=wow_classic` liefert 5.5.4.70579 (z. B. Tapferkeit 396, Eroberung 390, Zeitlose Münzen 777, Kriegsgeschmiedetes Siegel 776) |
| Interface-Nummer | **50504** (5.5.4 → 5|05|04; andere installierte MoP-Addons nutzen 50504) |
| Flavor-Kennung | `WOW_PROJECT_MISTS_CLASSIC = 19`, `WOW_PROJECT_ID = 19` (Blizzard_FrameXMLBase/Mists/Constants.lua) |

**Methode:**
1. Aus den Toc-Dateien des MoP-Clients rekonstruiert, welche 2.229 Blizzard-Dateien MoP *wirklich* lädt
   (`[AllowLoadGameType …]`-Filter, `_Mists`/`_Classic`-Toc-Auswahl) – nicht die ganze Code-Liste, die auch Vanilla/
   Wrath/Retail-Reste enthält.
2. Jeden Blizzard-Namen aus DeckUI (291 APIs, ~1.350 Globale, 180 Events, 111 Enums, 18 Templates, 20 CVars, Atlanten,
   435 Frame-Methoden) gegen Retail und MoP abgeglichen (Doku + tatsächlicher Gebrauch im MoP-Code).
3. Bibliotheken separat geprüft: oUF 14 (unsere Version), oUF 13.4.5, LibActionButton 155.
4. Die Dateien, an die DeckUI andockt, direkt zwischen Retail und MoP verglichen.

**Grenze:** Die Classic-Doku listet viele alte Funktionen nicht (z. B. `GetQuestLogTitle`, `GetPlayerFacing`,
`GetSavedInstanceInfo`), und Blizzards MoP-Code ruft einige undokumentierte `C_`-Funktionen trotzdem auf
(`C_QuestLog.GetLogIndexForQuestID`). Statisch lässt sich „existiert“ also nur eingrenzen. Deshalb Schritt 3.

Ergebnis-Rohdaten: `tools/mists/scan_report_static.txt` (Lücken je DeckUI-Datei, `*` = MoP-Code nutzt es trotzdem).

---

## 2. Grundsatzentscheidungen

### 2.1 Ein Repository, eine Codebasis
- **Empfohlen.** Beide Spiele teilen ~70 % des Codes (Hub, Widgets, Einstellungsfenster, Cross, große Teile von Orbs,
  Taschen, Tooltip, Karte). Ein Fork würde jede Verbesserung doppelt kosten.
- Verworfen: eigener Branch/eigenes Repo „DeckUI-Classic“ – schneller Start, aber dauerhaft doppelte Pflege.

### 2.2 Zwei Toc-Dateien je Ordner
- Der Client sucht zuerst `<Name>_Mists.toc` (MoP), Retail ignoriert diese Datei; Retail liest weiter `<Name>.toc`.
- Jede `_Mists.toc`: `## Interface: 50504`, gleiche `## Version`, gleiche SavedVariables, **eigene Dateiliste**:
  gemeinsame Dateien + MoP-Dateien (`*_mists.lua`), ohne Retail-only-Dateien.
- Regel für Unterschiede: **klein → `if D.IsMists`**, **groß → eigene Datei**, die in der jeweiligen Toc steht und
  dieselbe `ns.`-Schnittstelle bedient. Kein Wildwuchs an `if`-Ketten in derselben Funktion.

### 2.3 Flavor-Erkennung im Hub (`DeckUI/core.lua`)
```lua
D.IsMists  = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC   -- 19
D.IsRetail = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
```
Module fragen nur diese zwei Felder (wie heute `D.IsDeck()`).

### 2.4 Feature-Liste je Flavor
- `D.FEATURES` (Hub) sagt, was es im laufenden Spiel gibt (`talkingHead = D.IsRetail`, `vault = D.IsRetail`, …).
- Die Einstellungsseiten bauen Optionen nur für vorhandene Features (`D.Flow` macht das zu „eine Zeile weniger“).
- `D.MODULE_ORDER`/`D.MODULE_DESCRIPTIONS` je Flavor: Module, die es in MoP (noch) nicht gibt, erscheinen nicht.
- `D.PAGE_FRAMES`/`D.PAGE_RESET` bekommen die MoP-Rahmen (z. B. kein „Talking head“).

### 2.5 SavedVariables
- MoP hat einen eigenen `WTF`-Ordner (`_classic_\WTF`) – keine Kollision mit Retail. Gleiche Namen, eigene Defaults.
- Alles „pro Gerät“ funktioniert unverändert.

### 2.6 Bibliotheken
| Lib | MoP | Plan |
|---|---|---|
| **oUF 14** (unsere) | `SetRolesets` (4×), `CustomAuraContainerTemplate`, `Enum.SelectionType`, `UnitSelectionType`, `ArenaEnemyMatchFramesContainer`, `C_ClassTalents` fehlen | **Behalten** + Mini-Patches (Aufrufe absichern) + **Aura-Ersatz** für MoP (2.6.1) |
| oUF 13.4.5 (Alternative) | passt fast ganz (nur `C_ClassTalents`, `C_PvP.GetHonorRewardInfo`, `Enum.DispelType`, `SelectionType`) | **Nicht empfohlen**: unser Orbs-Code ist gegen die 14er-API geschrieben (Castbar 369, Auren 1.198, Power 100 Zeilen Unterschied) → Orbs müsste zwei oUF-APIs bedienen |
| LibActionButton 155 | kennt MoP nicht namentlich (nur Retail/Vanilla/BCC/Wrath-Schalter), läuft in MoP über die allgemeinen „nicht Retail“-Pfade; die Leisten-Dateien, an denen sie hängt, sind in MoP identisch mit Retail | Behalten; Probe prüft `IsUsableSpell`, `GetMacroSpell`, `GetSpellCount`; im Spiel testen (Phase 2) |
| LibStub, CallbackHandler, LibButtonGlow | flavor-neutral | Behalten |

Hinweis: Offizielles oUF unterstützt Classic grundsätzlich nicht (ab 14.1.1 lädt es ausdrücklich nur Retail). Die
Patches bleiben deshalb bei uns und müssen bei jedem oUF-Update nachgezogen werden → in CLAUDE.md festhalten.

#### 2.6.1 Aura-Container-Ersatz (MoP)
DeckUI benutzt den Container an ~40 Stellen (FF-/XIV-Stil, Buffleiste, Gruppe, Raid, Bosse). Statt alle umzuschreiben:
eine Datei `DeckUI_Orbs/auras_mists.lua`, nur in der MoP-Toc, die `frame:CreateAuras(opts)` mit **genau den Teilen**
bereitstellt, die wir nutzen:
- `AddGroup(filter, {maxFrameCount, candidateFilters = {maxDuration}, showDebuffBorder, showStealableBorder})`
- `SetAuraGroupCandidateFilters(key, filters)` (Buffleiste: Kampf/außer Kampf), `SetEnabled`
- Layout-Felder `layout/layoutLimit/initialAnchor/growthX/growthY/size/width/height/elementSpacing/lineSpacing`
- Knöpfe mit `Icon`, `Count`, `Cooldown`, `Time`, `Border`, `PostCreateButton`, Rechtsklick-Abbrechen (`cancelButton`)
- Dispel-Farbe: statt `AddDispelTypeTexture` Farbe aus `dispelName` (MoP-Werte sind nicht geheim)
- Datenquelle: `C_UnitAuras.GetAuraDataByIndex` / `GetAuraSlots` (in MoP vorhanden), Events `UNIT_AURA`

### 2.7 Release
- **Eine Zip für beide Spiele.** CurseForge erkennt die Toc-Varianten; die Datei bekommt zwei Spielversionen.
- `release-common.ps1`: Liste bleibt; neu `Get-TocPath $addon $flavor`.
- `package.ps1`: prüft getrennt „alle `<Name>.toc` gleiche Interface“ und „alle `<Name>_Mists.toc` gleiche Interface
  (50504)“; Version muss über **alle 20** Tocs gleich sein; stempelt beide.
- `bump-version.ps1`: `-Interface` (Retail) und neu `-MistsInterface`.
- `upload-curseforge.ps1`: nimmt mehrere Interface-Nummern → `12.1.5` **und** `5.5.4` → `gameVersions = [Retail-ID, MoP-ID]`.
  Vorher Workflow-Probelauf (`dry_run`) – der zeigt, ob CurseForge „5.5.4“ führt.
- `.github/workflows/release.yml`: gibt beide Interface-Nummern weiter.
- CHANGELOG/Beschreibung: neuer Abschnitt „Mists of Pandaria Classic“ mit Feature-Liste je Spiel.

### 2.8 Was weiter gilt
Alle Regeln aus CLAUDE.md gelten auch für MoP (Taint, `D.Dialog` statt StaticPopup, nie Felder auf Blizzard-Frames,
geheime Werte nie rechnen – MoP hat `issecretvalue`; laut Probe war `UnitHealth` außerhalb des Kampfs nicht geheim, im
Kampf noch ungetestet). **IDs nur aus Spieldaten**:
`check-game-data.py` bekommt `--branch wow_classic`, `repdata.lua` wird für MoP neu erzeugt.

---

## 3. Schritt 0 – das Prüf-Addon (gelaufen am 25.10.2026, Ergebnis in 3a)

`tools/mists/DeckUI_Probe/` – ändert nichts am Spiel, fragt nur den Client:
- alle 291 APIs, ~1.420 globalen Namen (inkl. ~120 alter Funktionen, die der MoP-Port voraussichtlich braucht:
  Questlog, Ruf, Instanzsperren, Bank, Auktionen, Talente, Eklipse/Runen …), 180 Events (registrieren mit `pcall`),
  111 Enums, 31 CVars (`C_CVar.GetCVarInfo`), Atlanten (`C_Texture.GetAtlasInfo`), 38 Templates
  (`C_XMLUtil.GetTemplateInfo` – erzeugt nichts), 435 Frame-Methoden, Tastenbefehle (`GetBinding`)
- **komplette Liste aller `C_`-Namensräume und Funktionen**, die MoP wirklich hat
- Schlüsselwerte: Interface-Nummer, Aktionsleisten-Seiten, Spec/Dual-Spec, Leistentyp, Gamepad, geheime Werte aktiv?,
  Assistent vorhanden?, Auktionshaus-Variante, Edit-Mode-Layouts, Bank-Konstanten, Mikromenü-Knöpfe,
  Tooltip-Lebensbalken, Namensplaketten-Aufbau

**Ablauf (du):**
1. Ordner `tools\mists\DeckUI_Probe` nach `C:\Spiele\World of Warcraft\_classic_\Interface\AddOns\` kopieren
   (der Ordner `AddOns` existiert dort noch nicht – einfach anlegen).
2. MoP starten, einloggen, 5 Sekunden warten (oder `/deckprobe`), Chat meldet „DeckUI Probe: done“.
3. `/reload` (schreibt die SavedVariables). Fertig – Bescheid geben.
4. Am besten einmal mit Ziel (ein Gegner) und einmal im Gamepad-Modus; Klasse egal, Druide/Hexer/Priester/DK geben
   zusätzlich Ressourcen-Werte.

**Auswertung (ich):** `python tools/mists/readprobe.py <scratch>` liest
`_classic_\WTF\Account\*\SavedVariables\DeckUI_Probe.lua` und listet pro DeckUI-Datei, was wirklich fehlt.
Der Leser lädt die Datei mit Lua (lupa), weil der Client ohne Einrückung und mit CRLF schreibt.
Ohne `-I` aufrufen, sonst fehlt lupa aus den Benutzerpaketen. `mopscan.json` muss im Scratch-Ordner liegen.

### 3a. Ergebnis der Probe (25.10.2026)

Client 5.5.4 (70579), Interface 50504, Projekt 19. Gelaufen mit Paladin Stufe 1, ohne Ziel und ohne Gamepad.
Ohne Fehler, alle Abschnitte gefüllt.

**Bestätigt vorhanden** (Auswahl dessen, was der Plan voraussetzt):
- **Aktionsleisten**: `ActionButton1`, `MultiBarBottomLeftButton1`, `StanceButton1`, `MainMenuBarVehicleLeaveButton`,
  `OverrideActionBar`, `MicroMenu`. Seiten-Indizes Override 18, Fahrzeug 16, Temp-Form 17 wie Retail.
  Alle `ACTIONBUTTON*`- und `MULTIACTIONBAR1-7BUTTON*`-Befehle sowie `CAMERAZOOMIN/OUT` und `SHAPESHIFTBUTTON1`.
- **Assistent**: `C_AssistedCombat.GetNextCastSpell/GetActionSpell`, `C_ActionBar.IsAssistedCombatAction` und die
  Templates `ActionBarButtonAssistedCombat*`.
- **Gamepad**: `C_GamePad`, CVars `GamePadEnable/EmulateShift/Ctrl/Alt/TapWindowMs`; dazu `synchronizeBindings`,
  `SoftTargetInteract`, `SoftTargetIconGameObject`, `mapFade`, `miniWorldMap`, `rotateMinimap`.
  MoPs Vorgabe für Strg ist `PADLSHOULDER`; `EnsureGamepad` setzt ohnehin unsere Werte.
- **Engine-Technik**: `C_AddOnProfiler`, `C_EditMode` (`GetLayouts`, `SetActiveLayout`),
  `UnitCastingDuration/ChannelDuration`, `C_DurationUtil`, `C_CurveUtil`, `CreateUnitHealPredictionCalculator`,
  `UnitHealthPercent`, `issecretvalue`, `TooltipDataProcessor`, `MenuUtil`, `EventUtil`.
- **Auktionshaus**: modern (`ReplicateItems`, `REPLICATE_ITEM_LIST_UPDATE`,
  `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`, `IsSellItemValid`). Den Legacy-Client gibt es nicht.
- **Alte Funktionen**:
  - Questlog: `GetQuestLogTitle`, `GetQuestLogLeaderBoard`, `GetQuestLogIndexByID`, `IsQuestWatched`,
    `AddQuestWatch/RemoveQuestWatch`, `GetQuestLogSpecialItemInfo`, `C_QuestLog.GetQuestObjectives`,
    `C_QuestLog.GetQuestsOnMap`, globales `SetSuperTrackedQuestID/GetSuperTrackedQuestID`, `WatchFrame`.
  - Instanzen, Erfolge, Inspektion: `GetSavedInstanceInfo`, `GetAchievementCriteriaInfo`, `GetInspectSpecialization`.
  - Klassenressourcen: `GetEclipseDirection`, `GetRuneType`.
  - Zauberbuch, Bank, Gegenstände: `PickupSpellBookItem`, `GetSpellBookItemInfo`, `GetNumSpellTabs`, `PurchaseSlot`,
    `GetBankSlotCost`, `IsDressableItem`, `RepairAllItems`, `C_Container.UseContainerItem`.
  - Ruf: `GetFactionInfoByID`, `C_Reputation.GetWatchedFactionData`, `C_GossipInfo.GetFriendshipReputation`.
  - Sammlungen und Szenarien: `C_ToyBox`, `C_PetJournal.PickupPet`, `C_MountJournal.Pickup`,
    `C_EquipmentSet.PickupEquipmentSet`, `C_ScenarioInfo.GetCriteriaInfo(ByStep)`, `C_Scenario.GetInfo/GetStepInfo`,
    `GetWorldElapsedTime`.
- **Events**: `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `ACTIVE_TALENT_GROUP_CHANGED`,
  `PLAYER_SPECIALIZATION_CHANGED`, `PLAYER_SOFT_INTERACT_CHANGED`, `NAME_PLATE_UNIT_ADDED`, `EDIT_MODE_LAYOUTS_UPDATED`,
  `GAME_PAD_ACTIVE_CHANGED`, `CVAR_UPDATE`, `UPDATE_BINDINGS`, `PLAYERBANKSLOTS_CHANGED`, `QUEST_WATCH_LIST_CHANGED`,
  `SCENARIO_CRITERIA_UPDATE`, `CHALLENGE_MODE_START`.
- **Werte**: Bank `BANK_CONTAINER` −1, 28 Plätze, 7 Banktaschen. Erweiterung 4, Stufenobergrenze 90.
  `GetPlayerFacing` und `UnitPosition` liefern Werte in der offenen Welt, `C_Map.GetPlayerMapPosition` ebenso.
  Der Tooltip-Lebensbalken ist ein StatusBar.

**Bestätigt fehlend** (138 von 291 APIs, 24 von 180 Events, 28 von 111 Enums – deckt sich mit Abschnitt 4):
- Retail-Namensräume: `C_Bank`, `C_CampaignInfo`, `C_ContentTracking`, `C_DelvesUI`, `C_MajorFactions`, `C_Navigation`,
  `C_PerksActivities`, `C_PlayerChoice`, `C_ProfSpecs`, `C_SuperTrack`, `C_TalkingHead`, `C_WeeklyRewards`.
- `C_VignetteInfo` – **neu ❌**, war ❓.
- Moderne QuestLog-Funktionen: `C_QuestLog.GetInfo`, `GetNumQuestLogEntries`, `GetTitleForQuestID`, `IsComplete`,
  `AbandonQuest`, `GetQuestWatchType` …
- Weitere Einzelfunktionen:
  - Behälter und Händler: `C_Container.SortBags/SortBank`, `C_MerchantFrame.*Junk*`.
  - Karte und Inspektion: `C_Map.GetMapWorldSize`, alle User-Waypoint-Funktionen, `C_PaperDollInfo.GetInspectItemLevel`.
  - Gegenstände und Tooltip: `C_Item.IsDressableItemByID`, `C_Item.GetItemLearnTransmogSet`, `C_TooltipInfo.GetHyperlink`.
  - Ruf, Währung, Spec: `C_Reputation.GetFactionDataByID`, `C_CurrencyInfo.GetBackpackCurrencyInfo`,
    `C_CurrencyInfo.GetFactionGrantedByCurrency`, `C_SpecializationInfo.SetSpecialization`, `C_ClassTalents`.
  - M+, Berufe, Zauberbuch: `C_ChallengeMode.GetActiveKeystoneInfo/GetAffixInfo/GetDeathCount`, die Retail-Rezept-APIs
    von `C_TradeSkillUI`, `C_SpellBook.*`.
- **Globale Spec-Funktionen**: `GetSpecialization`, `GetSpecializationInfo`, `SetActiveSpecGroup` sind nil. Es gibt
  nur `C_SpecializationInfo.GetSpecialization/GetSpecializationInfo/GetActiveSpecGroup/SetActiveSpecGroup`.
- `IsAnyBagOpen`, `SortBags`, `GetWatchedFactionInfo`.
- **Templates**: `CustomAuraContainerTemplate`, `BankPanelPurchaseButtonScriptTemplate`,
  `QuestObjectiveFindGroupButtonTemplate`.
- **Widget-Methode**: `SetRolesets`. Alle anderen Methoden, die die Probe nicht fand, stehen in der MoP-Doku; die
  Probe hatte nur kein Widget dieser Art erzeugt (Slider, Minimap, Alpha-Animation, Model).
- **Enums**: `SelectionType` (oUF colors/private), `NavigationState`, `SuperTrackingType`, `CampaignState`,
  `CustomAuraButtonDispelType*`.
- **CVars**: `worldMapShowPlayerCoords`, `worldMapShowCursorCoords`, `minimapShowPlayerCoords`, `coordsByTenths`,
  `nameplateShowFriends`, `bankAutoDepositReagents`, `bankConfirmTabCleanUp`.
- **Tastenbefehle**: `TOGGLECALENDAR`, `TOGGLEDUNGEONSANDRAIDS`, `TOGGLELFGPARENT`, `TOGGLEMOUNTJOURNAL`,
  `TOGGLEPETJOURNAL`, `TOGGLEPVP`. `DECKUI_*` fehlten nur, weil DeckUI nicht installiert war.
- **Atlanten**: `UI-HUD-MicroMenu-Character-Up` (aber `…-Questlog-Up` existiert), `Navigation-Tracked-*`.
- **Mikromenü**: vorhanden sind Character, QuestLog, Guild, Achievement, Collections, EJ, Store, MainMenu.
  Es fehlen `PlayerSpellsMicroButton`, `ProfessionMicroButton`, `LFDMicroButton`, `HousingMicroButton`.

**Noch offen, weil Stufe 1 ohne Ziel und ohne Gamepad** (wird in den Phasen im Spiel getestet):
- Dual-Spec (erst ab Stufe 30), MoP-Ressourcen anderer Klassen.
- Geheime Werte im Kampf.
- `plate.UnitFrame` und `SoftTargetFrame` an einer echten Plakette.
- Gamepad aktiv.
- `GetBackpackCurrencyInfo` (global, nicht abgefragt).
- `AUCTION_HOUSE_SHOW`, Runen- und Eklipse-Events (nicht abgefragt).

---

## 4. Modul für Modul

Legende: ✅ läuft weitgehend · 🔧 anpassen · 🆕 MoP-Fassung neu schreiben · ❌ entfällt in MoP · ❓ noch offen, wird im Spiel geprüft

### 4.1 Hub `DeckUI/`

| Datei | MoP | Was zu tun ist |
|---|---|---|
| core.lua | 🔧 | `D.IsMists/IsRetail`, `D.FEATURES`, Modul-Liste je Flavor. CVar `synchronizeBindings` ✅ (Tasten pro Gerät). Globale `GetSpecialization/GetSpecializationInfo` fehlen → überall `C_SpecializationInfo.*` (core.lua nutzt sie schon) |
| errors.lua, widgets.lua, panel.lua, minimap.lua | ✅ | Templates `OptionsSliderTemplate`, `UIPanelButtonTemplate`, `MoneyInputFrameTemplate` vorhanden. Panel: Optionen über `D.FEATURES` filtern |
| reputation.lua | 🔧 | `C_MajorFactions`, `C_Reputation.GetFactionDataByID` fehlen. MoP: `C_Reputation.GetWatchedFactionData`/`IsFactionParagon` sind da (Paragon gibt es inhaltlich nicht), Ruf über `GetFactionInfoByID` ✅ (`GetWatchedFactionInfo` fehlt – `GetWatchedFactionData` nehmen), Freundschaft (Pächter) über `C_GossipInfo.GetFriendshipReputation` ✅ |
| actionbars.lua (Leisten pro Gerät) | 🔧 | Retail-`C_SpellBook.PickupSpellBookItem/GetSpellBookItemInfo/…` fehlen → MoP: alte `PickupSpellBookItem`, `GetSpellBookItemInfo`, `GetNumSpellTabs`, `GetSpellTabInfo` ✅; `C_ToyBox`, `C_PetJournal.PickupPet`, `C_MountJournal.Pickup`, `C_EquipmentSet` ✅; Assistent-Slot ✅ (gibt es). `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` gibt es ✅; dazu `ACTIVE_TALENT_GROUP_CHANGED` für den Dual-Spec-Wechsel registrieren. Schlüssel `specID` → in MoP pro Spec-Gruppe prüfen |
| editmode.lua (Layout pro Gerät) | ✅ | `C_EditMode.GetLayouts/SetActiveLayout`, `EDIT_MODE_LAYOUTS_UPDATED`, `EditModeManagerFrame` ✅ (Probe: 1 aktives von 3 Layouts). Im Spiel testen |
| damagemeter.lua | ❌ | Blizzard_DamageMeter wird in MoP nicht geladen. Nicht in die MoP-Toc |
| merchant.lua | 🔧 | `C_MerchantFrame.SellAllJunkItems/GetNumJunkItems` fehlen → MoP: Taschen durchgehen, graue Gegenstände per `C_Container.UseContainerItem` beim Händler (nicht im Kampf, gedrosselt, max. 12 pro Durchgang wie Blizzards Rückkauf-Grenze). Reparieren: `RepairAllItems`, `CanGuildBankRepair` vorhanden |
| loot.lua | 🔧 | `C_Item.IsDressableItemByID` → `IsDressableItem` ✅. Rest (`LOOT_READY`, `LootSlot`, `GetLootSlotInfo`, `LootFrame`) ✅ |
| softtarget.lua | ✅❓ | `PLAYER_SOFT_INTERACT_CHANGED`, CVars `SoftTargetInteract`/`SoftTargetIconGameObject` ✅. Ob die MoP-Plakette einen `SoftTargetFrame` hat, konnte die Probe ohne Plakette nicht sehen → Phase 4 im Spiel |
| targetarrow.lua, nameplates.lua | ✅❓ | `C_NamePlate`, `NAME_PLATE_UNIT_ADDED` ✅. `plate.UnitFrame` → Phase 4 im Spiel (Probe lief ohne Ziel) |
| talkinghead.lua | ❌ | MoP lädt keine Talking-Head-UI (`C_TalkingHead` fehlt; kam erst mit WoD) |
| infobars.lua | ✅ | `BagsBar`, `MainMenuBarBackpackButton`, `C_AddOnProfiler` vorhanden. Mail-Symbol-Pfad prüfen |
| mainmenu.lua | 🔧 | Laut Probe gibt es Character, QuestLog, Guild, Achievement, Collections, EJ, Store, MainMenu (+ laut Code Spellbook, Talent, LFG, PVP, Help, Socials). Es fehlen `PlayerSpells`, `Profession`, `LFD`, `Housing` – der Code fragt ohnehin, welche Knöpfe existieren. Atlanten teils da (`…-Questlog-Up` ✅, `…-Character-Up` fehlt – dort zeigt DeckUI ohnehin das Porträt): pro Knopf auf `GetAtlasInfo` prüfen, sonst Blizzards Normal-Textur |
| auction.lua | ✅ | Modernes Auktionshaus ✅ (`ReplicateItems`, `GetReplicateItemInfo`, `REPLICATE_ITEM_LIST_UPDATE`, `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`); kein Legacy-Client. Start über den OnShow-Hook wie in Retail |
| auctionstyle.lua | 🔧 | Classic-Variante des Fensters hat teils andere Bausteine → im Spiel prüfen, nur Texturen anpassen |

### 4.2 Orbs `DeckUI_Orbs/`

| Teil | MoP | Was zu tun ist |
|---|---|---|
| oUF-Kern | 🔧 | 4× `SetRolesets` absichern (`if obj.SetRolesets`), `UnitSelectionType`/`Enum.SelectionType` absichern (colors.lua, private.lua), `ArenaEnemyMatchFramesContainer` in blizzard.lua absichern, `C_ClassTalents` in classpower.lua absichern. Patches markieren (`-- DeckUI: MoP`) |
| Auren (alle Stile) | 🆕 | Aura-Container-Ersatz `auras_mists.lua` (2.6.1) |
| Castbar | ✅ | `UnitCastingDuration/ChannelDuration`, `C_DurationUtil` von der Probe bestätigt |
| Health/Power/Tags | ✅ | `UnitHealthPercent`, `AbbreviateNumbers`, `CreateUnitHealPredictionCalculator`, `C_CurveUtil` vorhanden |
| Klassenressourcen | 🆕 | MoP-eigene Typen: **Schattenkugeln** (Priester, `Enum.PowerType.ShadowOrbs`=28), **Brennende Glut** (Zerstörung, 14, mit Teilfüllung), **Dämonischer Furor** (Dämonologie, 15, ein Balken), **Eklipse** (Gleichgewicht, `GetEclipseDirection`, Balken −100…100), **Chi** (12), **Heilige Kraft** (9), **Seelensplitter** (7), **Runen mit Typ** (`GetRuneType`: Blut/Frost/Unheilig/Tod), **Stagger** (Braumeister). Kleines eigenes Element `DeckClassPowerMists` für Glut/Furor/Eklipse; Kugeln/Chi/HK/Splitter über oUF-ClassPower-Zuordnung |
| Stile Orbs/FF/XIV | 🔧 | XIV-EXP-Leiste: `MainStatusTrackingBarContainer` gibt es in MoP ✅; Ruf am Max-Level über MoP-Ruf (4.1 reputation). Max-Level 90 (wie Midnight, Zufall). `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` weglassen |
| Gruppe/Raid | 🔧 | `SecureGroupHeaderTemplate`, `CompactRaidFrameManager`, `PartyFrame` vorhanden. Raid-Dispel-Rahmen ohne `AddDispelTypeTexture` → eigene Farbe aus `dispelName`. Rollen `UnitGroupRolesAssigned` ✅ |
| Buffleiste | 🔧 | über den Aura-Ersatz; Masken/Formen bleiben |
| Gegnerliste | ✅ | Threat-Funktionen vorhanden |

### 4.3 Cross `DeckUI_Cross/` – das Herz fürs Deck

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Kreuze, Seitenwechsel | ✅ | `MainActionBar`, `ActionButton1-12`, `MultiBarBottomLeftButton*`, `C_ActionBar.Get*BarIndex` identisch. MoP-Haltungen (Krieger 3 Haltungen, Druidenformen, Schurken-Verstohlenheit, Schattenform) laufen über `[bonusbar:1-4]` wie heute |
| Bindungen auf native Befehle | ✅ | `ACTIONBUTTON*`, `MULTIACTIONBAR1-7BUTTON*`, `SHAPESHIFTBUTTON*`, `CAMERAZOOMIN/OUT` von der Probe bestätigt |
| Gamepad-Selbsteinrichtung | ✅ | `C_GamePad` und CVars `GamePadEnable/EmulateShift/Ctrl/Alt` ✅, Events `GAME_PAD_*`, `CVAR_UPDATE`, `UPDATE_BINDINGS` ✅. MoP-Vorgabe Strg = LB – `EnsureGamepad` überschreibt sie |
| Überschreib-/Fahrzeugleiste, Aussteigen | ✅ | `OverrideActionBar`, `MainMenuBarVehicleLeaveButton` vorhanden |
| Haltungsleiste | ✅ | `StanceBar`, `StanceButton1` (Probe) vorhanden |
| Leisten 3–8 | ✅ | `MultiBar5-7` existieren auch in MoP |
| Fähigkeiten-Menü auf B, Schnellmenü RB | ✅ | In MoP fehlen `TOGGLECALENDAR`, `TOGGLEDUNGEONSANDRAIDS`, `TOGGLELFGPARENT`, `TOGGLEMOUNTJOURNAL`, `TOGGLEPETJOURNAL`, `TOGGLEPVP`; die übrigen aus `QUICK_COMMANDS` gibt es. Unbekannte graut der Code schon aus. `QUICK_DEFAULTS` prüfen, damit kein Standardplatz leer bleibt |
| Assistent-Anzeige (assist.lua) | ✅❓ | Probe: `C_AssistedCombat.GetNextCastSpell/GetActionSpell` und `IsAssistedCombatAction` vorhanden. Bleibt in der MoP-Toc; ob der Assistent im Spiel Vorschläge macht, testet Phase 2 |
| ConsolePort-Warnung | ✅ | bleibt |

### 4.4 Spec `DeckUI_Spec/` – 🆕
MoP hat **Spezialisierungen und Dual-Spec** (zwei Talentgruppen). Statt „eine von 3–4 Specs anklicken“:
- zwei runde Knöpfe = die beiden Gruppen (Icon der jeweiligen Spec), Klick aktiviert die Gruppe
  (`C_SpecializationInfo.SetActiveSpecGroup`, 5 s Zauber, nicht im Kampf), goldener Ring auf der aktiven
- Spec *innerhalb* einer Gruppe ändern: wie in MoP über das Talentfenster (`SetSpecialization` ist Blizzards Pfad)
- Events: `ACTIVE_TALENT_GROUP_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED` ✅
- **Probe:** Die globalen `GetSpecialization`, `GetSpecializationInfo`, `SetActiveSpecGroup`, `GetActiveSpecGroup` sind
  nil, ebenso `C_SpecializationInfo.SetSpecialization`. Es gibt nur
  `C_SpecializationInfo.GetSpecialization/GetSpecializationInfo/GetActiveSpecGroup/SetActiveSpecGroup`, und
  `GetNumSpecGroups` gibt es global. Der Retail-Code in `DeckUI_Spec/core.lua` ruft die globalen Fassungen auf und
  braucht deshalb ohnehin die neue MoP-Datei

### 4.5 Taschen `DeckUI_Bags/`

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Fenster, Kategorien, Suche, Gold, Währungen | ✅🔧 | Kategorie-Logik bleibt. `C_CurrencyInfo.GetBackpackCurrencyInfo` fehlt (Probe) → globales `GetBackpackCurrencyInfo` ❓ (nicht abgefragt; in Phase 5 mit `/dump` prüfen) |
| Gegenstandsknöpfe | 🔧 | MoP-`ContainerFrameItemButtonTemplate` hat **keinen Mixin**: Tasche kommt aus `GetParent():GetID()` – unser Holder-Rahmen mit `SetID(bag)` passt schon. Statt `b:SetBagID/UpdateExtended/UpdateQuestItem/UpdateNewItem/SetMatchesSearch` die globalen Classic-Helfer (`SetItemButtonTexture/Count/Desaturated/Quality`, `ContainerFrame_UpdateCooldown`, Quest-Textur `$parentIconQuestTexture`) → `core_mists.lua` mit `ns.UpdateButton` |
| Offen/zu folgen | 🔧 | `IsAnyBagOpen` fehlt (Probe) → eigene Prüfung über `IsBagOpen(0..4)` ✅ |
| Sortieren | ❌ | MoP hat kein `C_Container.SortBags/SortBank` und kein `SortBags` (Probe). Knopf ausblenden (eigenes Sortieren wäre ein eigenes Projekt) |
| Bank | 🆕 | Alte Bank (Probe: −1 / 28 / 7, `PurchaseSlot`, `GetBankSlotCost`, `BankItemButtonGenericTemplate`, `PLAYERBANKSLOTS_CHANGED` ✅): `BANK_CONTAINER` (−1), 28 Plätze + 7 Banktaschen, Taschenplätze kaufen (`PurchaseSlot`, `GetBankSlotCost`), `BankFrame` (Mists/BankFrame.xml), Events `BANKFRAME_OPENED/CLOSED`, `PLAYERBANKSLOTS_CHANGED`. Keine Kriegsmeute-Bank, keine Reagenzienbank, keine Tabs → `bank_mists.lua` |
| Alte-Erweiterung-Filter, Auktions-Filter | 🔧 | Auktions-Filter: `C_AuctionHouse.IsSellItemValid` ✅ (Probe); Alt-Filter nutzlos (alles ist „alt“) → ausblenden |
| Verfolgte Gegenstände, AH-Wert | ✅ | |

### 4.6 Quests `DeckUI_Quests/`

| Abschnitt | MoP | Was zu tun ist |
|---|---|---|
| Blizzards Tracker abschalten | 🆕 | MoP nutzt **`WatchFrame`** (Wrath-Stil), nicht ObjectiveTracker. Abschalten = Ereignisse ab + verstecken (Taint-Regeln wie heute: nichts in Blizzards Listen schreiben) |
| Quests | 🆕 | Alte Questlog-API (`GetNumQuestLogEntries`, `GetQuestLogTitle`, `GetQuestLogLeaderBoard`, `IsQuestWatched`, `GetQuestLogSpecialItemInfo` für Quest-Gegenstände) – Rendering/Layout/sichere Knöpfe bleiben gleich, nur das Daten-Sammeln ist neu (`quests_mists.lua`) |
| Erfolge | 🔧 | `GetTrackedAchievements`, `GetAchievementCriteriaInfo` |
| Szenario | ✅🔧 | MoP **hat** Szenarien: `C_Scenario.GetInfo/GetStepInfo` und `C_ScenarioInfo.GetCriteriaInfo/GetCriteriaInfoByStep` ✅ – genau das, was scenario.lua heute nutzt. Retail-Teile (Tiefen-Kopf, Widgets, `C_ChallengeMode.GetActiveKeystoneInfo/GetDeathCount` fehlen) absichern |
| Herausforderungsmodus | 🆕 | MoP-Dungeon-Zeitläufe mit Gold/Silber/Bronze: `GetWorldElapsedTime` ✅, `C_ChallengeMode.GetActiveChallengeMapID/GetMapUIInfo` ✅, `GetChallengeModeMapTimes` (Doku), `CHALLENGE_MODE_START` ✅ |
| Kampagne, Weltquests, Bonusziele, Inhaltsverfolgung, Reisetagebuch, Initiativen, Rezepte, Tiefen, Jagd, Szenarioführer | ❌ | gibt es in MoP nicht (Dateien world.lua, tracking.lua-Teile, delves.lua, hunt.lua, guide.lua nicht in die MoP-Toc) |
| Klick = verfolgen | 🔧 | statt `C_SuperTrack`: globales `SetSuperTrackedQuestID/GetSuperTrackedQuestID` ✅ (Probe) – Klick verfolgt die Quest wie heute |
| Quests | 🔧 | Probe: `GetQuestLogTitle`, `GetQuestLogLeaderBoard`, `GetQuestLogIndexByID`, `IsQuestWatched`, `AddQuestWatch/RemoveQuestWatch`, `GetQuestLogSpecialItemInfo`, `C_QuestLog.GetQuestObjectives`, `QUEST_WATCH_LIST_CHANGED` ✅; `C_QuestLog.GetInfo/GetTitleForQuestID/IsComplete/AbandonQuest` fehlen |

### 4.7 Karte `DeckUI_Map/`

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Minikarte eckig/rund | 🔧 | `MinimapCluster`, `MinimapBackdrop`, `MinimapCompassTexture`, `MiniMapMailFrame`, `MiniMapInstanceDifficulty`, `MiniMapChallengeMode`, `MinimapZoomIn/Out`, `GameTimeFrame` vorhanden; `AddonCompartmentFrame`, `ExpansionLandingPageMinimapButton`, `MiniMapIndicatorFrame_UpdatePosition` fehlen → PIECES-Liste je Flavor. Edit Mode kennt auch in MoP das System „Minimap“ |
| Weltkarte | 🔧 | `WorldMapFrame` mit `BorderFrame`, `ScrollContainer`, `MaximizeMinimizeFrame`, `NavBar_CheckLength` vorhanden; im Spiel prüfen, welche Teile wir umfärben. Probe: `mapFade`, `miniWorldMap`, `rotateMinimap` ✅; **`worldMapShowPlayerCoords`, `worldMapShowCursorCoords`, `minimapShowPlayerCoords`, `coordsByTenths` fehlen** → diese Kästchen in MoP ausblenden, Koordinaten auf der Minikarte zeigen wir ohnehin selbst |
| Questlog daneben | 🔧 | MoP hat `QuestMapFrame` (Wrath-Stil) *und* `QuestLogFrame` – welches das Spiel zeigt, entscheidet `miniWorldMap`/`questLogOpen`; testen |

### 4.8 Tooltip `DeckUI_Tooltip/`

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Aussehen, Anker, Zeilen | ✅ | `TooltipDataProcessor`, `GameTooltip_SetDefaultAnchor`, `SharedTooltip_SetBackdropStyle` vorhanden. Lebensbalken: `GameTooltip.StatusBar` ist ein StatusBar ✅ (Probe). Name von `GameTooltipStatusBar` im Spiel prüfen |
| Quest-Gegenstand (extras.lua) | 🔧 | `QuestDescription` liest die Questbeschreibung über `C_TooltipInfo.GetHyperlink` – fehlt in MoP (Probe). In MoP die Beschreibung weglassen (nur „Startet eine Quest“ zeigen), Abfrage mit `if C_TooltipInfo and C_TooltipInfo.GetHyperlink` absichern |
| Spec/Itemlevel anderer Spieler | 🔧 | `C_PaperDollInfo.GetInspectItemLevel` fehlt → Spec über `GetInspectSpecialization` ✅, Itemlevel selbst aus den Inspektions-Gegenständen berechnen (oder nur Spec zeigen) |
| Quest-Gegenstand, AH-Preis | ✅ | |
| Ruf-Gegenstände | 🔧 | `repdata_mists.lua` aus wago `wow_classic` neu erzeugen; Ruf über MoP-Ruf (4.1) |
| Berufswissen, Schlüssel der Tiefen-Truhe, Ensembles | ❌ | gibt es in MoP nicht |

### 4.9 Nav `DeckUI_Nav/` – größter Umbau
MoP hat **keine** Blizzard-Navigation: kein `C_SuperTrack`, kein `C_Navigation` (Raute in der Welt, Distanz,
Routen), keine Nutzer-Wegpunkte (`C_Map.SetUserWaypoint`, `USER_WAYPOINT_UPDATED`), kein `C_Map.GetMapWorldSize`.

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Kompass (Himmelsrichtungen, Gruppe) | 🔧 | `GetPlayerFacing`, `UnitPosition`, `C_Map.GetPlayerMapPosition`, `C_Map.GetWorldPosFromMapPos` ✅ (Probe, offene Welt). **Raritäten ❌**: `C_VignetteInfo` fehlt laut Probe → die Vignetten-Schleife in compass.lua und der Vignetten-Zweig in Nav/core.lua nur in Retail. Meter ohne `GetMapWorldSize`: über `C_Map.GetWorldPosFromMapPos` (vorhanden) zwei Ecken der Karte → Größe in Metern (so macht es HereBeDragons) |
| Ziel-Anzeige (Name, Pfeil, Distanz, Ankunft) | 🆕 | Ziel ist **unser** aktiver Wegpunkt oder die verfolgte Quest (Quest-POI aus `C_QuestLog.GetQuestsOnMap`); Distanz selbst gerechnet |
| Leuchtfeuer in der Welt | ❌ | ohne `C_Navigation.GetFrame` keine Bildschirmposition → entfällt |
| Wegpunktliste/Routen | 🔧 | Liste, Nadeln, Kompass-Punkte, Routen bleiben. Neu: **eigener Strg+Klick-Handler** auf der Weltkarte (`ScrollContainer`-HookScript), Ankunft nur noch über eigene Distanz |
| Quest-Durchschalten (Taste) | 🔧 | über alte Quest-Watch-API |

### 4.10 Week `DeckUI_Week/` – 🆕 eigene MoP-Woche
Gleiche Tabelle/Fenster, neue Datenbasis (`data_mists.lua`, `collect_mists.lua`):
- **Schlachtzüge**: Sperren (Mogu'shan, Herz der Angst, Terrasse, Thron des Donners, Schlacht um Orgrimmar) inkl.
  **LFR-Flügel** – `GetSavedInstanceInfo`/`GetNumSavedInstances` ✅
- **Weltbosse** (Galleon, Sha des Zorns, Nalak, Oondasta, Erhabene, Ordos) – wöchentliche Quest-Flags
  (IDs per `/week record` + wago bestätigen)
- **Wochen-Obergrenzen**: Tapferkeit (396), Eroberung (390) aus `C_CurrencyInfo.GetCurrencyInfo` (Wochenwerte)
- **Glücksbringer**: Kriegsgeschmiedetes Siegel (776) / Mogu-Rune (752) – Wochenquest für Siegel
- **Herausforderungsmodus**: Medaille je Dungeon (`C_ChallengeMode.GetMapTable/GetChallengeBestTime`)
- Zeitlose Insel: Münzen (777) und ggf. Wochenaufgaben
- Großes Gewölbe, Schlüsselstein, Wappen, Tiefen, Beute-Jagd, Berufswissen, Renown → ❌
- Reset: `C_DateAndTime.GetSecondsUntilWeeklyReset` vorhanden ✅

---

## 5. Was für MoP entfernt (= nicht in die MoP-Toc aufgenommen) wird

| Datei / Teil | Grund |
|---|---|
| `DeckUI/damagemeter.lua` | Blizzard-Schadensmesser in MoP nicht geladen |
| `DeckUI/talkinghead.lua` | keine Talking-Head-UI |
| `DeckUI_Quests/world.lua`, `delves.lua`, `hunt.lua`, `guide.lua`; aus `tracking.lua` Inhaltsverfolgung, Reisetagebuch, Initiativen, Rezepte | Inhalte gibt es nicht |
| `DeckUI_Nav/beacon.lua` | keine Navigations-API |
| `DeckUI_Bags/bank.lua` (Retail-Bank) | durch `bank_mists.lua` ersetzt |
| `DeckUI_Week/data.lua` + Retail-Teile von `core.lua` | durch MoP-Datenbasis ersetzt |
| `DeckUI_Tooltip/repdata.lua` | durch `repdata_mists.lua` ersetzt |
| Tooltip-Extras Berufswissen/Tiefen-Truhe/Ensembles | Inhalte gibt es nicht |
| Taschen sortieren, Alt-Erweiterungs-Filter | API fehlt bzw. sinnlos |
| Kompass-Raritäten (`C_VignetteInfo`) | API fehlt (Probe) |
| Karten-Koordinaten-Kästchen (CVars) | CVars fehlen (Probe) |
| Retail-Events `ACTIVE_PLAYER_SPECIALIZATION_CHANGED`, `MAJOR_FACTION_RENOWN_LEVEL_CHANGED`, `ACCOUNT_MONEY`, `BANK_TAB*`, `CONTENT_TRACKING*`, `PERKS_*`, `NAVIGATION_FRAME_*`, `SUPER_TRACKING_PATH_UPDATED`, `USER_WAYPOINT_UPDATED`, `TALKINGHEAD_*`, `PLAYER_CHOICE_UPDATE` | MoP kennt sie nicht – ein `RegisterEvent` darauf wirft einen Fehler. In gemeinsamem Code nur über eine Hilfsfunktion `D.RegisterEventIfKnown(frame, event)` |

Nichts davon wird aus Retail gelöscht – es steht nur nicht in den MoP-Tocs.

---

## 6. Was MoP-spezifisch neu gebraucht wird

1. **Flavor-Gerüst**: `_Mists.toc` ×10, `D.IsMists`, `D.FEATURES`, `D.RegisterEventIfKnown`, Modul-Liste je Flavor
2. **Aura-Container-Ersatz** für oUF (2.6.1) + oUF-Mini-Patches
3. **MoP-Klassenressourcen**: Schattenkugeln, Brennende Glut, Dämonischer Furor, Eklipse, Runentypen inkl. Todesrunen
4. **Dual-Spec**-Umschalter (Spec-Modul)
5. **Classic-Taschenknöpfe** + **alte Bank** (Taschenplätze, Kauf)
6. **Schrott verkaufen** ohne `SellAllJunkItems`
7. **Questlog/Tracker** auf alter API, `WatchFrame` abschalten, Szenario + Herausforderungsmodus
8. **Navigation ohne Blizzard-Navigation**: Kompass-Meter, Ziel-Anzeige, Strg+Klick auf der Karte
9. **MoP-Woche**: Raids/LFR, Weltbosse, Tapferkeit/Eroberung, Siegel, Herausforderungsmodus
10. **MoP-Ruf** (inkl. Freundschaft der Pächter) für EXP-Leiste und Tooltip
11. **Release mit zwei Spielversionen**, `check-game-data.py --branch wow_classic`, `repdata_mists.lua`
12. Junctions im MoP-Client: `C:\Spiele\World of Warcraft\_classic_\Interface\AddOns\DeckUI*` → Repo-Ordner
    (**erst nach Phase 1** – vorher würde MoP die Retail-Toc lesen und Retail-Code ausführen)

---

## 7. Reihenfolge (Phasen) mit Ziel und Test

**Getestet wird am PC (Entscheidung des Besitzers, 26.10.2026).** MoP wird vorerst nicht auf dem Steam Deck gespielt –
der Port ist ein Entgegenkommen an die PC-Spieler. Alles Deck-Spezifische (Gamepad-Einrichtung, LT/RT-Kreuze,
LB-Zoom, Haltungen über LB, Schnellmenü RB, Fähigkeiten-Menü B, Pad-Standardtasten) wird trotzdem **in jeder Phase
mitgebaut** und bleibt im Code, aber erst in **Phase 11** auf dem Deck getestet. Bis dahin prüft jede Phase am PC:
Tastatur und Maus, keine Lua-Fehler, kein Taint.

| Phase | Inhalt | Fertig, wenn … |
|---|---|---|
| **0** ✅ | Probe laufen lassen, Plan aktualisieren | erledigt 25.10.2026 (Abschnitt 3a); Rest-❓ werden in den Phasen im Spiel geklärt |
| **1** ✅ | Flavor-Gerüst, `_Mists.toc` (zunächst nur Hub + Cross), Release-Skripte, Junctions | MoP lädt DeckUI ohne Lua-Fehler, Einstellungsfenster öffnet, `/deck build` zeigt 50504. **Gebaut 25.10.2026, im Spiel getestet 26.10. (PC, Tastaturmodus: Kreuze zeigen und zaubern, keine Fehler)**: `D.IsMists/IsRetail`, `D.MISTS_MODULES = { Cross }`, Hub-Toc mit core/errors/widgets/panel/minimap, Cross-Toc mit allen Dateien, Optionen und `/deck`-Befehle nur bei geladener Datei, Minikarten-Knopf am MoP-Radius, `package.ps1`/`bump-version.ps1 -MistsInterface`, Junctions für DeckUI und DeckUI_Cross. Statt `D.FEATURES` vorerst „Option da, wenn ihre Datei geladen ist“ – die Toc entscheidet |
| **2** ✅ | Cross komplett (Kreuze, Haltungen, Leisten 3–8, Menüs; Gamepad-Teile mitgebaut) | Am PC: Kreuze mit eigenen Tasten zaubern und leuchten, Gedrückt-halten wiederholt, Seitenwechsel (Haltung/Form, Fahrzeug, Reittier), Aussteigen, Haltungsleiste, Leisten 3–8, Assistent-Anzeige, jede Option der Seiten Cross/Action bars ohne Fehler. Gamepad-Teile: nur „lädt ohne Fehler“. **Am PC getestet 26.10.2026**; einzige Änderung: Classic-Quickslot-Quadrat auf leeren Plätzen ausgeblendet |
| **3** ✅ | Orbs: oUF-Patches, Aura-Ersatz, Ressourcen, alle Stile, Gruppe/Raid | Spieler/Ziel/Fokus/Gruppe/Raid ohne Fehler, Auren sichtbar, jede MoP-Klasse zeigt ihre Ressource. **Gebaut und am PC getestet 26.10.2026**: oUF-Patches (`-- DeckUI: Mists`), `auras_mists.lua` (Container-Ersatz, Layout/Filter im Trockenlauf getestet), `classpower_mists.lua` (Regeln aus Blizzards 5.5.4-Klassenleisten, IDs aus wago `wow_classic`), `ns.FLOW`, Orbs-Toc + Junction. Eklipse vorerst als ein Balken (links Mond, rechts Sonne, Farbe nach Seite) |
| **4** ✅ | Spec (Dual-Spec), Hub-Rest (Händler, Beute, Ruf, Leisten/Layout pro Gerät, Mikromenü, Infozeile) | Overview-Seite vollständig nutzbar. **Gebaut und am PC getestet 26.10.2026**: `DeckUI_Spec/core_mists.lua` (ein Knopf je Talentgruppe, `SetActiveSpecGroup`), Hub-Toc mit allen Dateien außer damagemeter/talkinghead, Schrott-Verkauf über die Taschen (max. 12 = Rückkauf), Ruf über `GetFactionInfoByID`, Flugmenüs über die alten Zauberbuch-Funktionen, `ACTIVE_TALENT_GROUP_CHANGED` für Leisten/Layout pro Gerät, Mikromenü mit MoP-Knöpfen und Classic-Symbolen |
| **5** ✅ | Taschen + Bank, Tooltip | Taschen/Bank benutzen, ablegen, verkaufen ohne Taint-Meldung. **Gebaut und am PC getestet 26.10.2026**: MoP-Knopfpflege (`PaintMists`), `bank_mists.lua` (28 Plätze + Banktaschen 5–11, Taschenplätze mit Blizzards Vorlage, Kauf über D.Dialog), kein Sortieren, eigenes `IsAnyBagOpen`, keine Reagenzientasche (Container 5 ist in MoP die erste Banktasche – auch in der Infozeile), Währungen über `GetBackpackCurrencyInfo`; Tooltip: Itemlevel anderer selbst berechnet, Quest-Gegenstände über `C_QuestLog.GetQuestInfo`/`IsQuestComplete`, `repdata_mists.lua` (93 Zauber aus wago `wow_classic`), Berufswissen/Tiefen-Truhe/Ensembles ausgeblendet |
| **6** ✅ | Karte (Minikarte, Weltkarte) | beide Formen, Weltkarte verschiebbar, keine Taint-Meldung beim Hovern. **Gebaut und am PC getestet 26.10.2026**: MoP-Teile der alten Minikarte eigens platziert (Verfolgung, Kalender, Weltkartenknopf, Zoom, Post, Schlachtfeld, LFG-Auge, Schwierigkeit, Herausforderungsmodus), runder Rand/Nordmarke/Blizzard-Uhr ausgeblendet; Weltkarte (Cataclysm-Fassung) Fenstermodus und verschiebbar, **nicht skaliert** (MoPs Karte rechnet die Maus ohne Skalierung – Hervorhebung lag neben der Maus, 26.10.) – **eigener DeckUI-Stil für sie offen** (Screenshot 26.10. liegt vor: Pergamentrahmen, Titelleiste mit Maximieren/Schließen, „Map Options“); Koordinaten-Kästchen und „Controls only under the mouse“ in MoP ausgeblendet |
| **7** ✅ | Quests (Tracker, Erfolge, Szenario, Herausforderungsmodus) | Tracker ersetzt WatchFrame vollständig, Quest-Gegenstände im Kampf nutzbar. **Gebaut und am PC getestet 26.10.2026** (Szenario/Herausforderungsmodus noch nicht erlebt): WatchFrame abgeschaltet, `quests_mists.lua` (alte Questlog-API wie WatchFrame, Fokus über SetSuperTrackedQuestID, Aufgeben über D.Dialog, Teilen), `tracking_mists.lua` (Zone-Widgets, Erfolge über GetTrackedAchievements), Herausforderungsmodus mit Medaillenzeiten; Führer/Tiefen/Jagd-Optionen ausgeblendet |
| **8** ✅ | Nav (Kompass, Ziel, Wegpunkte, Routen) | Wegpunkt per Strg+Klick, Ankunft, Route. **Gebaut und am PC getestet 26.10.2026**: `nav_mists.lua` als Ersatz für C_SuperTrack/Nutzer-Wegpunkt/C_Navigation (über `ns.ST/UW/NAV`, im Trockenlauf getestet), Kartengröße aus Weltkoordinaten, Strg+Klick über eigene Druck/Loslass-Haken, Ziel = aktiver Wegpunkt oder im Tracker fokussierte Quest; kein Leuchtfeuer, keine Raritäten |
| **9** ✅ | Week (MoP-Daten) | Tabelle für alle Charaktere mit MoP-Inhalten. **Gebaut und am PC getestet 26.10.2026**: Spalten Schlachtzug-Bosse der Woche (inkl. LFR-Flügel über `GetLFGDungeonNumEncounters`), Tapferkeit/Eroberung mit Wochengrenze, Weltbosse (Wochenquests 32099/32098/32518/32519/33117/33118 – in wago `QuestV2` vorhanden, Namen per `/week record` bestätigen), Gold-Medaillen im Herausforderungsmodus; Details: Wochengrenzen, Sperren, Wochenquests (gelernt aus dem Questlog, z. B. „Sealing Fate“), Weltbosse, Medaille + Bestzeit je Dungeon, Währungen (Tapferkeit, Eroberung, Gerechtigkeit, Ehre, Glücksbringer, Mogu-Rune, Kriegsgeschmiedetes Siegel, Zeitlose/Blutige Münzen – alle in wago `CurrencyTypes` 5.5.4) |
| **10** | Release (CHANGELOG, Beschreibung „Retail + MoP Classic“), CurseForge mit beiden Versionen | Datei auf CurseForge mit 12.1.5 **und** 5.5.4. In der Beschreibung: Steam-Deck-Teile in MoP „not yet tested on the Steam Deck“ |
| **11** | **Steam-Deck-Test in MoP** (alles auf einmal) | Junctions auf dem Deck; Controller-Modus-Meldung, Gamepad-Selbsteinrichtung, LT/RT-Kombinationen (auch LT+RT), Gedrückt-halten, LB-Zoom, Haltungen über LB, Schnellmenü RB, Fähigkeiten-Menü B, Pad-Standardtasten, Positionen und Größen pro Gerät, alle Module auf 1280×800 |

Phasen 1–3 sind der Kern: danach ist DeckUI in MoP am PC spielbar. Ab Phase 4 kann jede Phase einzeln
released werden (Module, die noch nicht portiert sind, fehlen in der MoP-Toc einfach – keine halben Sachen).

## 8. Tests (du, in MoP, am PC – das Deck kommt in Phase 11)
1. `/console scriptErrors 1`, `/console taintLog 1`, `/reload` – kein Fehlerfenster.
2. `/deck build` → Client 5.5.4, Interface 50504, Toc 50504.
3. PC: „keyboard mode“-Meldung, eigene Tasten der Leisten 1+2 auf den Kreuzen, Haltungswechsel (Krieger/Druide/Schurke),
   Fahrzeug + Aussteigen.
4. Jede Seite in `/deck`: jede Option einmal an/aus, kein Fehler, nichts Retail-only sichtbar.
5. Je Klasse mit Sonderressource einmal einloggen (Priester Schatten, Hexer alle 3, Druide Gleichgewicht, DK, Mönch).
6. Taschen/Bank/Händler/Auktionshaus/Post: benutzen, ablegen, verkaufen, kein „blocked“.
7. Gruppe + Raid (Testmodus und echt), Szenario, ein Herausforderungsmodus.
8. Frischinstallation (SavedVariables weg) in MoP.
9. Gegenprobe Retail: alles wie vorher (die Retail-Toc darf sich nur um `D.IsMists`-Zweige ändern).

## 9. Risiken und offene Fragen
- **Probe beantwortet** (3a): Gamepad-CVars, alte Quest-, Ruf- und Instanz-Funktionen, `GetPlayerFacing`,
  Haltungsknöpfe, Schnellmenü-Befehle und Assistent-API. Offen sind nur Dinge, die eine Stufe-1-Figur ohne Ziel nicht
  zeigt: Dual-Spec, Ressourcen, Plaketten, geheime Werte im Kampf.
- **Geheime Werte in MoP**: API vorhanden, `UnitHealth` außerhalb des Kampfs nicht geheim. Unser Code verträgt beides;
  falls im Kampf aktiv, gelten die Retail-Regeln 1:1.
- **CurseForge**: führt es „5.5.4“ als Spielversion für dieses Projekt? → Workflow-Probelauf.
- **MoP-Patches**: Classic-Inhaltsphasen ändern IDs/Inhalte (5.5.4 ≈ Inhalt von 5.4, Zeitlose Insel/Schlacht um
  Orgrimmar). `check-game-data.py --branch wow_classic` bei jeder Phase laufen lassen.
- **oUF-Updates**: unsere MoP-Patches müssen bei jedem oUF-Update erneut rein → in CLAUDE.md dokumentieren.
- **Taint**: MoPs UI ist ein Mix aus Classic- und modernem Code; die Taint-Regeln gelten unverändert, aber an
  anderen Stellen (WatchFrame, alte Bank, Classic-Taschenknöpfe). Jede Phase mit `taintLog` testen.
- **Aufwand Nav/Quests/Week**: die drei brauchen am meisten Neues; sie kommen bewusst zuletzt.

## 10. Grobe Aufwandsschätzung (Sitzungen wie bisher)
| Phase | Umfang |
|---|---|
| 0 Probe | kurz |
| 1 Gerüst + Release-Skripte | 1 Sitzung |
| 2 Cross | 1 Sitzung (meist Testen) |
| 3 Orbs | 2–3 Sitzungen (Aura-Ersatz, Ressourcen) |
| 4 Spec + Hub-Rest | 1–2 Sitzungen |
| 5 Taschen/Bank + Tooltip | 2 Sitzungen |
| 6 Karte | 1 Sitzung |
| 7 Quests | 2 Sitzungen |
| 8 Nav | 2 Sitzungen |
| 9 Week | 1–2 Sitzungen |
| 10 Release | 1 Sitzung |
| 11 Deck-Test | 1 Sitzung (Testen, kleine Korrekturen) |

## 11. Vorbereitete Dateien
| Pfad | Zweck |
|---|---|
| `tools/mists/DeckUI_Probe/` | Prüf-Addon (`_Mists.toc` 50504 + `.toc` 120105 für eine Retail-Gegenprobe) |
| `tools/mists/readprobe.py` | liest das Probe-Ergebnis, Bericht je DeckUI-Datei |
| `tools/mists/makeprobe.py` | baut das Prüf-Addon neu (nach Code-Änderungen) |
| `tools/mists/mopfiles.py` | ermittelt die Dateien, die der MoP-Client lädt |
| `tools/mists/mopscan.py`, `mopverify.py`, `mopbyfile.py`, `mopmissing.py`, `mopmethods.py`, `mopq.py`, `dumpapi.py` | statische Analyse gegen Blizzards Quellcode |
| `tools/mists/scan_report_static.txt` | Ergebnis der statischen Analyse je Datei |

Blizzards Quellcode für eine neue Analyse: `https://codeload.github.com/Gethe/wow-ui-source/tar.gz/<commit>` –
MoP: Branch `classic`, Retail: Branch `live`. `tools/` gehört nicht ins Paket (`package.ps1` nimmt nur die zehn
Addon-Ordner) und ist nicht committet.
