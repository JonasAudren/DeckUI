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
eine gemeinsame Zip für Retail und MoP. Reihenfolge nach Nutzen fürs Deck: erst Grundgerüst + Cross + Orbs (spielbar),
dann Taschen/Tooltip/Karte, zuletzt Quests/Nav/Week (die am meisten neu brauchen).

**Erster Schritt (10 Minuten von dir):** das vorbereitete Prüf-Addon `DeckUI_Probe` einmal im MoP-Client laufen lassen
(Abschnitt 3). Die Classic-Doku ist unvollständig – erst der Client selbst beantwortet, welche alten Funktionen da sind.
Danach passe ich diesen Plan an die echten Antworten an.

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
geheime Werte nie rechnen – MoP hat die API, vermutlich inaktiv, die Probe sagt es). **IDs nur aus Spieldaten**:
`check-game-data.py` bekommt `--branch wow_classic`, `repdata.lua` wird für MoP neu erzeugt.

---

## 3. Schritt 0 – das Prüf-Addon (vorbereitet, noch nicht installiert)

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

**Auswertung (ich):** `python -I tools/mists/readprobe.py <scratch>` liest
`_classic_\WTF\Account\*\SavedVariables\DeckUI_Probe.lua` und listet pro DeckUI-Datei, was wirklich fehlt.
Danach aktualisiere ich Abschnitt 4 und markiere jede „Probe“-Frage als beantwortet.

---

## 4. Modul für Modul

Legende: ✅ läuft weitgehend · 🔧 anpassen · 🆕 MoP-Fassung neu schreiben · ❌ entfällt in MoP · ❓ hängt an der Probe

### 4.1 Hub `DeckUI/`

| Datei | MoP | Was zu tun ist |
|---|---|---|
| core.lua | 🔧 | `D.IsMists/IsRetail`, `D.FEATURES`, Modul-Liste je Flavor. CVar `synchronizeBindings` ❓ (Tasten pro Gerät) |
| errors.lua, widgets.lua, panel.lua, minimap.lua | ✅ | Templates `OptionsSliderTemplate`, `UIPanelButtonTemplate`, `MoneyInputFrameTemplate` vorhanden. Panel: Optionen über `D.FEATURES` filtern |
| reputation.lua | 🔧 | `C_MajorFactions`, `C_Reputation.GetFactionDataByID` fehlen. MoP: `C_Reputation.GetWatchedFactionData`/`IsFactionParagon` sind da (Paragon gibt es inhaltlich nicht), Ruf über `GetFactionInfoByID` ❓, Freundschaft (Pächter) über `C_GossipInfo.GetFriendshipReputation` ✅ |
| actionbars.lua (Leisten pro Gerät) | 🔧 | Retail-`C_SpellBook.PickupSpellBookItem/GetSpellBookItemInfo/…` fehlen → MoP: alte `PickupSpellBookItem`, `GetSpellBookItemInfo`, `GetNumSpellTabs` ❓; `C_ToyBox`/`C_PetJournal.PickupPet` ❓; Assistent-Slot nur wenn es ihn gibt; Event `ACTIVE_PLAYER_SPECIALIZATION_CHANGED` fehlt → `PLAYER_SPECIALIZATION_CHANGED`/`ACTIVE_TALENT_GROUP_CHANGED` |
| editmode.lua (Layout pro Gerät) | ✅❓ | MoP hat Edit Mode + `C_EditMode.GetLayouts/SetActiveLayout`. Event wie oben tauschen. Testen |
| damagemeter.lua | ❌ | Blizzard_DamageMeter wird in MoP nicht geladen. Nicht in die MoP-Toc |
| merchant.lua | 🔧 | `C_MerchantFrame.SellAllJunkItems/GetNumJunkItems` fehlen → MoP: Taschen durchgehen, graue Gegenstände per `C_Container.UseContainerItem` beim Händler (nicht im Kampf, gedrosselt, max. 12 pro Durchgang wie Blizzards Rückkauf-Grenze). Reparieren: `RepairAllItems`, `CanGuildBankRepair` vorhanden |
| loot.lua | 🔧 | `C_Item.IsDressableItemByID` → `IsDressableItem` (vorhanden). Rest (`LOOT_READY`, `LootSlot`, `GetLootSlotInfo`, `LootFrame`) ✅ |
| softtarget.lua | ❓ | Soft-Target gibt es (CVar `softTargetInteract` in MoP-Einstellungen). Ob der MoP-Plakette ein `SoftTargetFrame` hat → Probe |
| targetarrow.lua, nameplates.lua | ✅❓ | `C_NamePlate`, `NamePlateUnitFrameMixin` vorhanden. Probe: `plate.UnitFrame` vorhanden? |
| talkinghead.lua | ❌ | MoP lädt keine Talking-Head-UI (`C_TalkingHead` fehlt; kam erst mit WoD) |
| infobars.lua | ✅ | `BagsBar`, `MainMenuBarBackpackButton`, `C_AddOnProfiler` vorhanden. Mail-Symbol-Pfad prüfen |
| mainmenu.lua | 🔧 | MoP-Knöpfe: Character, Spellbook, Talent, Achievement, QuestLog, Guild, LFG, PVP, Collections, EJ, Store, Help, MainMenu (+ Socials, WorldMap). Liste je Flavor; Atlanten `UI-HUD-MicroMenu-*` ❓ (sonst Blizzards Normal-Textur des Knopfs) |
| auction.lua | ✅❓ | MoP lädt `Blizzard_AuctionHouseUI` (Classic-Variante), `C_AuctionHouse.ReplicateItems` dokumentiert, `AUCTION_HOUSE_SHOW` gibt es dort noch. Fallback „Legacy-Auktionshaus“ (`IsUsingLegacyAuctionClient`) ❓ |
| auctionstyle.lua | 🔧 | Classic-Variante des Fensters hat teils andere Bausteine → im Spiel prüfen, nur Texturen anpassen |

### 4.2 Orbs `DeckUI_Orbs/`

| Teil | MoP | Was zu tun ist |
|---|---|---|
| oUF-Kern | 🔧 | 4× `SetRolesets` absichern (`if obj.SetRolesets`), `UnitSelectionType`/`Enum.SelectionType` absichern (colors.lua, private.lua), `ArenaEnemyMatchFramesContainer` in blizzard.lua absichern, `C_ClassTalents` in classpower.lua absichern. Patches markieren (`-- DeckUI: MoP`) |
| Auren (alle Stile) | 🆕 | Aura-Container-Ersatz `auras_mists.lua` (2.6.1) |
| Castbar | ✅❓ | 14er Castbar nutzt `UnitCastingDuration`, `SetTimerDuration`, `C_DurationUtil.CreateDurationTextBinding` – in MoP-Doku vorhanden. Probe bestätigt |
| Health/Power/Tags | ✅ | `UnitHealthPercent`, `AbbreviateNumbers` vorhanden |
| Klassenressourcen | 🆕 | MoP-eigene Typen: **Schattenkugeln** (Priester, `Enum.PowerType.ShadowOrbs`=28), **Brennende Glut** (Zerstörung, 14, mit Teilfüllung), **Dämonischer Furor** (Dämonologie, 15, ein Balken), **Eklipse** (Gleichgewicht, `GetEclipseDirection`, Balken −100…100), **Chi** (12), **Heilige Kraft** (9), **Seelensplitter** (7), **Runen mit Typ** (`GetRuneType`: Blut/Frost/Unheilig/Tod), **Stagger** (Braumeister). Kleines eigenes Element `DeckClassPowerMists` für Glut/Furor/Eklipse; Kugeln/Chi/HK/Splitter über oUF-ClassPower-Zuordnung |
| Stile Orbs/FF/XIV | 🔧 | XIV-EXP-Leiste: `MainStatusTrackingBarContainer` gibt es in MoP ✅; Ruf am Max-Level über MoP-Ruf (4.1 reputation). Max-Level 90 (wie Midnight, Zufall). `MAJOR_FACTION_RENOWN_LEVEL_CHANGED` weglassen |
| Gruppe/Raid | 🔧 | `SecureGroupHeaderTemplate`, `CompactRaidFrameManager`, `PartyFrame` vorhanden. Raid-Dispel-Rahmen ohne `AddDispelTypeTexture` → eigene Farbe aus `dispelName`. Rollen `UnitGroupRolesAssigned` ✅ |
| Buffleiste | 🔧 | über den Aura-Ersatz; Masken/Formen bleiben |
| Gegnerliste | ✅ | Threat-Funktionen vorhanden |

### 4.3 Cross `DeckUI_Cross/` – das Herz fürs Deck

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Kreuze, Seitenwechsel | ✅ | `MainActionBar`, `ActionButton1-12`, `MultiBarBottomLeftButton*`, `C_ActionBar.Get*BarIndex` identisch. MoP-Haltungen (Krieger 3 Haltungen, Druidenformen, Schurken-Verstohlenheit, Schattenform) laufen über `[bonusbar:1-4]` wie heute |
| Bindungen auf native Befehle | ✅ | `ACTIONBUTTON*`, `MULTIACTIONBAR*BUTTON*` identisch (Probe bestätigt die Liste) |
| Gamepad-Selbsteinrichtung | ✅❓ | `C_GamePad` vollständig, Controller-Modus in den MoP-Einstellungen. CVars `GamePadEnable/EmulateShift/Ctrl/Alt` → Probe |
| Überschreib-/Fahrzeugleiste, Aussteigen | ✅ | `OverrideActionBar`, `MainMenuBarVehicleLeaveButton` vorhanden |
| Haltungsleiste | 🔧 | `StanceBar` + `StanceButtonTemplate` vorhanden; Knopfnamen `StanceButton1…` per Probe bestätigen |
| Leisten 3–8 | ✅ | `MultiBar5-7` existieren auch in MoP |
| Fähigkeiten-Menü auf B, Schnellmenü RB | ✅❓ | Schnellmenü-Befehle je Flavor: `TOGGLETALENTS`, `TOGGLESPELLBOOK`, `TOGGLELFGPARENT`/`TOGGLEGROUPFINDER`, `TOGGLEPVP`, `TOGGLEPETJOURNAL`… → Probe meldet, welche es gibt; unbekannte graut der Code heute schon aus |
| Assistent-Anzeige (assist.lua) | ❓ | `C_AssistedCombat` steht in der MoP-Doku – ob er dort funktioniert, sagt die Probe. Wenn nicht: Datei nicht in die MoP-Toc |
| ConsolePort-Warnung | ✅ | bleibt |

### 4.4 Spec `DeckUI_Spec/` – 🆕
MoP hat **Spezialisierungen und Dual-Spec** (zwei Talentgruppen). Statt „eine von 3–4 Specs anklicken“:
- zwei runde Knöpfe = die beiden Gruppen (Icon der jeweiligen Spec), Klick aktiviert die Gruppe
  (`SetActiveSpecGroup`, 5 s Zauber, nicht im Kampf), goldener Ring auf der aktiven
- Spec *innerhalb* einer Gruppe ändern: wie in MoP über das Talentfenster (`SetSpecialization` ist Blizzards Pfad)
- Events: `ACTIVE_TALENT_GROUP_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED`
- `C_SpecializationInfo.SetSpecialization` fehlt in MoP → nicht benutzen

### 4.5 Taschen `DeckUI_Bags/`

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Fenster, Kategorien, Suche, Gold, Währungen | ✅🔧 | Kategorie-Logik bleibt. `C_CurrencyInfo.GetBackpackCurrencyInfo` fehlt → `GetBackpackCurrencyInfo` ❓ |
| Gegenstandsknöpfe | 🔧 | MoP-`ContainerFrameItemButtonTemplate` hat **keinen Mixin**: Tasche kommt aus `GetParent():GetID()` – unser Holder-Rahmen mit `SetID(bag)` passt schon. Statt `b:SetBagID/UpdateExtended/UpdateQuestItem/UpdateNewItem/SetMatchesSearch` die globalen Classic-Helfer (`SetItemButtonTexture/Count/Desaturated/Quality`, `ContainerFrame_UpdateCooldown`, Quest-Textur `$parentIconQuestTexture`) → `core_mists.lua` mit `ns.UpdateButton` |
| Offen/zu folgen | 🔧 | `IsAnyBagOpen` fehlt → eigene Prüfung über `IsBagOpen(0..4)` |
| Sortieren | ❌ | MoP hat kein `C_Container.SortBags/SortBank` (kam mit WoD). Knopf ausblenden (eigenes Sortieren wäre ein eigenes Projekt) |
| Bank | 🆕 | Alte Bank: `BANK_CONTAINER` (−1), 28 Plätze + 7 Banktaschen, Taschenplätze kaufen (`PurchaseSlot`, `GetBankSlotCost`), `BankFrame` (Mists/BankFrame.xml), Events `BANKFRAME_OPENED/CLOSED`, `PLAYERBANKSLOTS_CHANGED`. Keine Kriegsmeute-Bank, keine Reagenzienbank, keine Tabs → `bank_mists.lua` |
| Alte-Erweiterung-Filter, Auktions-Filter | 🔧 | Auktions-Filter: `C_AuctionHouse.IsSellItemValid` nutzt MoPs Auktionshaus selbst → ✅❓; Alt-Filter nutzlos (alles ist „alt“) → ausblenden |
| Verfolgte Gegenstände, AH-Wert | ✅ | |

### 4.6 Quests `DeckUI_Quests/`

| Abschnitt | MoP | Was zu tun ist |
|---|---|---|
| Blizzards Tracker abschalten | 🆕 | MoP nutzt **`WatchFrame`** (Wrath-Stil), nicht ObjectiveTracker. Abschalten = Ereignisse ab + verstecken (Taint-Regeln wie heute: nichts in Blizzards Listen schreiben) |
| Quests | 🆕 | Alte Questlog-API (`GetNumQuestLogEntries`, `GetQuestLogTitle`, `GetQuestLogLeaderBoard`, `IsQuestWatched`, `GetQuestLogSpecialItemInfo` für Quest-Gegenstände) – Rendering/Layout/sichere Knöpfe bleiben gleich, nur das Daten-Sammeln ist neu (`quests_mists.lua`) |
| Erfolge | 🔧 | `GetTrackedAchievements`, `GetAchievementCriteriaInfo` |
| Szenario | 🔧 | MoP **hat** Szenarien: `C_Scenario.GetInfo/GetStepInfo` (von MoP-Code benutzt), Kriterien über `C_Scenario.GetCriteriaInfo` ❓ |
| Herausforderungsmodus | 🆕 | MoP-Dungeon-Zeitläufe mit Gold/Silber/Bronze: `GetWorldElapsedTime`, `C_ChallengeMode.GetChallengeModeMapTimes/GetActiveChallengeMapID` |
| Kampagne, Weltquests, Bonusziele, Inhaltsverfolgung, Reisetagebuch, Initiativen, Rezepte, Tiefen, Jagd, Szenarioführer | ❌ | gibt es in MoP nicht (Dateien world.lua, tracking.lua-Teile, delves.lua, hunt.lua, guide.lua nicht in die MoP-Toc) |
| Klick = verfolgen | 🔧 | statt `C_SuperTrack`: MoP-Quest-POI-Verfolgung über `SetSuperTrackedQuestID` (global) ❓ – sonst Klick öffnet nichts und markiert die Quest nur |

### 4.7 Karte `DeckUI_Map/`

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Minikarte eckig/rund | 🔧 | `MinimapCluster`, `MinimapBackdrop`, `MinimapCompassTexture`, `MiniMapMailFrame`, `MiniMapInstanceDifficulty`, `MiniMapChallengeMode`, `MinimapZoomIn/Out`, `GameTimeFrame` vorhanden; `AddonCompartmentFrame`, `ExpansionLandingPageMinimapButton`, `MiniMapIndicatorFrame_UpdatePosition` fehlen → PIECES-Liste je Flavor. Edit Mode kennt auch in MoP das System „Minimap“ |
| Weltkarte | 🔧 | `WorldMapFrame` mit `BorderFrame`, `ScrollContainer`, `MaximizeMinimizeFrame`, `NavBar_CheckLength` vorhanden; im Spiel prüfen, welche Teile wir umfärben. Koordinaten-CVars (`worldMapShowPlayerCoords`, `mapFade`) ❓; MoP hat CVar `minimapShowPlayerCoords`/`coordsByTenths` |
| Questlog daneben | 🔧 | MoP hat `QuestMapFrame` (Wrath-Stil) *und* `QuestLogFrame` – welches das Spiel zeigt, entscheidet `miniWorldMap`/`questLogOpen`; testen |

### 4.8 Tooltip `DeckUI_Tooltip/`

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Aussehen, Anker, Zeilen | ✅ | `TooltipDataProcessor`, `GameTooltip_SetDefaultAnchor`, `SharedTooltip_SetBackdropStyle` vorhanden. Lebensbalken `GameTooltipStatusBar` ❓ (Classic-Name) |
| Spec/Itemlevel anderer Spieler | 🔧 | `C_PaperDollInfo.GetInspectItemLevel` fehlt → Spec über `GetInspectSpecialization`, Itemlevel selbst aus den Inspektions-Gegenständen berechnen (oder nur Spec zeigen) |
| Quest-Gegenstand, AH-Preis | ✅ | |
| Ruf-Gegenstände | 🔧 | `repdata_mists.lua` aus wago `wow_classic` neu erzeugen; Ruf über MoP-Ruf (4.1) |
| Berufswissen, Schlüssel der Tiefen-Truhe, Ensembles | ❌ | gibt es in MoP nicht |

### 4.9 Nav `DeckUI_Nav/` – größter Umbau
MoP hat **keine** Blizzard-Navigation: kein `C_SuperTrack`, kein `C_Navigation` (Raute in der Welt, Distanz,
Routen), keine Nutzer-Wegpunkte (`C_Map.SetUserWaypoint`, `USER_WAYPOINT_UPDATED`), kein `C_Map.GetMapWorldSize`.

| Teil | MoP | Was zu tun ist |
|---|---|---|
| Kompass (Himmelsrichtungen, Gruppe, Raritäten) | 🔧 | `GetPlayerFacing` ❓, `C_Map.GetPlayerMapPosition` vorhanden, `C_VignetteInfo` undokumentiert, aber von MoPs eigenem (geladenem) Kartencode benutzt ❓. Meter ohne `GetMapWorldSize`: über `C_Map.GetWorldPosFromMapPos` (vorhanden) zwei Ecken der Karte → Größe in Metern (so macht es HereBeDragons) |
| Ziel-Anzeige (Name, Pfeil, Distanz, Ankunft) | 🆕 | Ziel ist **unser** aktiver Wegpunkt oder die verfolgte Quest (Quest-POI aus `C_QuestLog.GetQuestsOnMap`); Distanz selbst gerechnet |
| Leuchtfeuer in der Welt | ❌ | ohne `C_Navigation.GetFrame` keine Bildschirmposition → entfällt |
| Wegpunktliste/Routen | 🔧 | Liste, Nadeln, Kompass-Punkte, Routen bleiben. Neu: **eigener Strg+Klick-Handler** auf der Weltkarte (`ScrollContainer`-HookScript), Ankunft nur noch über eigene Distanz |
| Quest-Durchschalten (Taste) | 🔧 | über alte Quest-Watch-API |

### 4.10 Week `DeckUI_Week/` – 🆕 eigene MoP-Woche
Gleiche Tabelle/Fenster, neue Datenbasis (`data_mists.lua`, `collect_mists.lua`):
- **Schlachtzüge**: Sperren (Mogu'shan, Herz der Angst, Terrasse, Thron des Donners, Schlacht um Orgrimmar) inkl.
  **LFR-Flügel** – `GetSavedInstanceInfo` ❓
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
| `DeckUI_Cross/assist.lua` | nur falls die Probe keinen Assistenten findet |
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

| Phase | Inhalt | Fertig, wenn … |
|---|---|---|
| **0** | Probe laufen lassen, Plan aktualisieren | Auswertung liegt vor, ❓ beantwortet |
| **1** | Flavor-Gerüst, `_Mists.toc` (zunächst nur Hub + Cross), Release-Skripte, Junctions | MoP lädt DeckUI ohne Lua-Fehler, Einstellungsfenster öffnet, `/deck build` zeigt 50504 |
| **2** | Cross komplett (Kreuze, Gamepad, Haltungen, Leisten 3–8, Menüs) | Auf dem Deck in MoP spielbar: LT/RT+Tasten zaubern, Gedrückt-halten wiederholt, Fahrzeuge |
| **3** | Orbs: oUF-Patches, Aura-Ersatz, Ressourcen, alle Stile, Gruppe/Raid | Spieler/Ziel/Fokus/Gruppe/Raid ohne Fehler, Auren sichtbar, jede MoP-Klasse zeigt ihre Ressource |
| **4** | Spec (Dual-Spec), Hub-Rest (Händler, Beute, Ruf, Leisten/Layout pro Gerät, Mikromenü, Infozeile) | Overview-Seite vollständig nutzbar |
| **5** | Taschen + Bank, Tooltip | Taschen/Bank benutzen, ablegen, verkaufen ohne Taint-Meldung |
| **6** | Karte (Minikarte, Weltkarte) | beide Formen, Weltkarte verschiebbar, keine Taint-Meldung beim Hovern |
| **7** | Quests (Tracker, Erfolge, Szenario, Herausforderungsmodus) | Tracker ersetzt WatchFrame vollständig, Quest-Gegenstände im Kampf nutzbar |
| **8** | Nav (Kompass, Ziel, Wegpunkte, Routen) | Wegpunkt per Strg+Klick, Ankunft, Route |
| **9** | Week (MoP-Daten) | Tabelle für alle Charaktere mit MoP-Inhalten |
| **10** | Release (CHANGELOG, Beschreibung „Retail + MoP Classic“), CurseForge mit beiden Versionen | Datei auf CurseForge mit 12.1.5 **und** 5.5.4 |

Phasen 1–3 sind der Kern: danach ist DeckUI in MoP auf dem Deck spielbar. Ab Phase 4 kann jede Phase einzeln
released werden (Module, die noch nicht portiert sind, fehlen in der MoP-Toc einfach – keine halben Sachen).

## 8. Tests (du, in MoP)
1. `/console scriptErrors 1`, `/console taintLog 1`, `/reload` – kein Fehlerfenster.
2. `/deck build` → Client 5.5.4, Interface 50504, Toc 50504.
3. Deck: Controller-Modus-Meldung, LT/RT-Kombinationen, Haltungswechsel (Krieger/Druide/Schurke), Fahrzeug + Aussteigen.
4. Jede Seite in `/deck`: jede Option einmal an/aus, kein Fehler, nichts Retail-only sichtbar.
5. Je Klasse mit Sonderressource einmal einloggen (Priester Schatten, Hexer alle 3, Druide Gleichgewicht, DK, Mönch).
6. Taschen/Bank/Händler/Auktionshaus/Post: benutzen, ablegen, verkaufen, kein „blocked“.
7. Gruppe + Raid (Testmodus und echt), Szenario, ein Herausforderungsmodus.
8. Frischinstallation (SavedVariables weg) in MoP.
9. Gegenprobe Retail: alles wie vorher (die Retail-Toc darf sich nur um `D.IsMists`-Zweige ändern).

## 9. Risiken und offene Fragen
- **Probe-Ergebnis** entscheidet bei: Gamepad-CVars, alten Quest-/Ruf-/Instanz-Funktionen, `GetPlayerFacing`,
  Tooltip-Lebensbalken, Haltungsknopf-Namen, Schnellmenü-Befehlen, Assistent, geheimen Werten.
- **Geheime Werte in MoP**: API vorhanden, vermutlich nie aktiv. Unser Code verträgt beides; falls aktiv, gelten die
  Retail-Regeln 1:1.
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
