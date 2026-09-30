# DeckUI – project notes for Claude Code

World of Warcraft addon suite (Lua) for the **Steam Deck and PC**, written by Gottlieb
as a learning project. Retail client, currently **Midnight (Interface 120100)** - verified in game with
`/deck build`, which compares the running client against our `.toc`. That number also
picks the CurseForge game version on upload, so it is the one place to change at a patch
(`bump-version.ps1 <version> -Interface <new>`). Beware the PTR: 12.1.5 exists as
`wowxptr` while live is 12.1.0, and filing a release under it hides the addon from
everyone who plays.
The owner tests everything in-game himself; Claude Code cannot run WoW.

## Layout

```
DeckUI/          hub: device detection, settings window (/deck), movable frames, minimap button
DeckUI_Orbs/     module: round unit frames on oUF (/orbs)         libs/oUF
DeckUI_Cross/    module: FFXIV-style cross hotbar (/dc)           libs/LibStub, CallbackHandler, LibActionButton-1.0
                 assist.lua: the assistant indicator, a movable frame of its own
DeckUI_Spec/     module: spec switcher (/spec, /qs)
DeckUI_Bags/     module: bags, bank, warband bank (/bags)        off by default
DeckUI_Quests/   module: own objective tracker (/quests)        off by default
DeckUI_Map/      module: square minimap, smaller world map (/deckmap) off by default
DeckUI_Tooltip/  module: the mouse-over tooltip (/decktip)       off by default
```
Modules are `LoadOnDemand`, depend on `DeckUI`, and register a settings tab with
`D.RegisterModule(key, { title, build = function(content) end })`. The hub loads
enabled modules from `DeckUIDB.modules` at `ADDON_LOADED`.

`package.ps1` builds the upload zip: `dist\DeckUI-<version>.zip` with the eight addon
folders at the **top level** (a wrapping folder would install everything one level too
deep), README, LICENSE and THIRD-PARTY inside `DeckUI\`, without the `.github`/`utils`
clutter from `libs\oUF` and without the unused LibStub/CallbackHandler copies that the
other libraries bundle. It aborts if the eight `.toc` files disagree on version or interface.
The list of addon folders lives once, in `release-common.ps1`, which both scripts dot-source
(with `Get-TocField`); a new module is added there and to `D.MODULE_*` in `DeckUI/core.lua`.
`bump-version.ps1 <version>` raises `## Version` (and with `-Interface` the interface)
in all eight at once - `package.ps1 -Version` only stamps the staged copies, so without
the bump the repository and CurseForge drift apart. `changelog.ps1 <version>` produces the
changelog the release sends along: the `## <version>` section of `CHANGELOG.md` when there
is one, otherwise the commit subjects since the previous tag. Write the section - the
fallback carries build and release plumbing that means nothing to a player. It falls back
rather than failing so a forgotten section never blocks a release, and `bump-version.ps1`
says so when the section is missing.

Each folder is a separate WoW addon; in `Interface\AddOns\` they are directory
junctions pointing into this repo. Any `.lua` change is live after `/reload`;
`.toc` changes or new folders/textures need a full client restart.

## Conventions

- **Everything in English**: code, comments, menu texts, chat messages, README.
  Slash commands (`/deck`, `/orbs`, `/dc`, `/spec`) and SavedVariables names
  (`DeckUIDB`, `DeckOrbsDB`, `DeckCrossDB`, `DeckSpecDB`) never change.
- Font: `D.FONT = STANDARD_TEXT_FONT` (locale-safe). Masks: `D.MASK`, disc texture `D.DISC`;
  `D.RoundMask(frame)` makes the round mask every orb, ring and round button uses.
- Widgets: `D.Label / D.Hint / D.Button / D.Slider / D.Checkbox` from `DeckUI/widgets.lua`.
  **Explanatory lines go through `D.Hint`**, which limits the width so the text wraps inside
  the panel - never place newlines by hand, they fight the wrapping and strand single words
  on their own line, and a line without a width limit runs out of the frame. Both were real
  bugs, reported by a stranger on reddit before anyone here noticed them.
  `D.Slider` puts its value **below** the bar: `OptionsSliderTemplate` parks it above, which
  is where the heading is, and the two printed on top of each other.
  Slider/checkbox take `db` as a **function** returning the table, plus a key and an apply function.
  Widgets with a `Refresh()` method and a place in `content.widgets` are refreshed on tab show.
- Movable frames: `D.MakeMovable(frame, key, db)`; set `frame.defaultPoint` first.
  `key` is the saved-position key and the overlay label – renaming it resets the position.
- **Per-device settings** (`D.DeviceDB(db)` → `db.perDevice[deck|pc]`): frame positions and the
  Orbs/Cross size sliders. Everything else (checkboxes, display options) is shared.
  `D.MigrateToDevice(db, {fields})` moves old flat fields to both devices once.
- Device detection: `D.DetectDevice()` – 1280x800 screen or active gamepad = "deck", else "pc";
  `DeckUIDB.device` = auto|deck|pc overrides. `D.IsDeck()` is the only thing modules should ask.
  Auto is decided **once at PLAYER_LOGIN** and kept for the session: re-detected on every
  call it was slow on hot paths and flipped when a gamepad came or went mid-session, sending
  positions into the other device's table. `/deck device` says when it would differ now.
- Key bindings per device: WoW's CVar `synchronizeBindings` = 0 keeps them in the local WTF
  folder instead of on the server (Devices tab, "Keep on this device: Key bindings"). The CVar
  lives in Config.wtf, so it is per machine by itself - no DeckUIDB entry. Switching it on
  saves the loaded bindings locally first; switching it off does *not* save, which would
  upload this machine's set over the server's. `/deck device` prints the state.
- **Action bar contents per device** (`DeckUI/actionbars.lua`, `DeckUIDB.keepBars`, off by
  default; not yet tested in game). What sits on the bars is server-side per character and
  spec, with no CVar - the owner lays out his bars differently on the Deck, and the PC loaded
  that. So `DeckUIDB.barLayouts[device][name-realm][specID]` holds a copy, restored at login,
  /reload and spec change (ACTIVE_PLAYER_SPECIALIZATION_CHANGED, not the talent one), taken
  again a second after the last `ACTIONBAR_SLOT_CHANGED`. Only the player's pages: 1-10 and
  13-15 (page 11 is skyriding, 12 and 16-18 vehicle/possess/override). Placing is the cursor
  path (pick up, `PlaceAction`, `ClearCursor`), protected in combat, so a restore waits for
  PLAYER_REGEN_ENABLED. Macros are stored by name (indices shift), the assistant by
  `IsAssistedCombatAction` and put back with `C_AssistedCombat.GetActionSpell()`. **A copy
  where every slot reads empty is never stored** - that is bars not loaded yet, and restoring
  it would wipe them. `/deck bars` prints the key, the saved layout and the last result.
- **Edit Mode layout per device** (`DeckUI/editmode.lua`, `DeckUIDB.keepLayouts`, off by
  default; not yet tested in game). Blizzard's layouts and the choice of the active one are
  server-side, per character and spec. The owner makes one layout per device in Edit Mode;
  DeckUI learns by *name* which one is active on this device (`DeckUIDB.editLayouts`, keyed
  like the bars) and switches back at login, /reload and spec change. The name is read from
  `EditModeManagerFrame.layoutInfo` (presets first, then saved layouts - `activeLayout`
  indexes that merged list), read only. **`C_EditMode.SetActiveLayout` from an addon leaves
  Edit Mode's manager tainted for the session**, so every switch asks for a reload at once
  (own prompt window, not a StaticPopup), and nothing is learned until that reload - should
  the manager not have caught up, learning the old name would undo the switch.
  `/deck layout` prints active and saved layout.
- Prefer small, complete edits; the owner reads the diffs. Keep debug commands
  (`/dc overlay`, `/dc bare`, `/dc bars`, `/dc page`, `/dc trace`, `/dc assist`, `/deck device`, `/deck bars`, `/deck layout`,
  `/deck build`, `/deck deck|pc|auto`) – they were essential for Midnight issues.

## Hard-won Midnight facts (do not "simplify" these away)

- **Bindings go to Blizzard's native commands**, not to our buttons:
  `SetOverrideBinding(header, true, "SHIFT-PADDUP", "ACTIONBUTTON1")`. Only the native path runs
  the engine's press-and-hold repeat (single-button assistant, hold-to-cast). `SetOverrideBindingClick`
  onto LibActionButton buttons breaks that. Our cross buttons only *display*; the pushed state is
  mirrored from Blizzard's buttons via `hooksecurefunc(native, "SetButtonState")`.
- The crosses mirror **Action Bar 1** (buttons 1–12, with a page state driver like Blizzard's main
  bar) and **Action Bar 2** (buttons 13–24, slots 61–72). Deck = LT/RT + D-pad/ABXY,
  PC = the player's own Blizzard bindings of those bars (nothing to bind).
- **Every page the state driver can select needs a registered state.** `PageMacro()` can return
  `GetOverrideBarIndex()` (18 on retail), so `NUM_PAGES` is derived from that API, never hardcoded.
  Slots are one flat list, page *p* button *i* = `(p-1)*12+i`, so page 18 is 205–216. A missing
  state makes LibActionButton's `GetAction()` return `"empty"` and the button goes blank – that
  was the "mount abilities not shown" bug. `/dc page` prints the active page and the resolved slot.
- **ConsolePort's action bar and our crosses cannot coexist.** `ConsolePort_Bar` claims the same
  LT/RT + D-pad/face combinations, hooks every `SetOverrideBinding*` and re-asserts its own
  override so ours loses, and calls `UnregisterAllEvents` on `ActionButton1-12` – which is
  exactly where our pushed state comes from. It is a separate addon, so the fix is unchecking
  "Console Port Action Bar"; the rest of ConsolePort (cursor, targeting, rings, menus) is fine
  next to us. `WarnConsolePortBar` in `DeckUI_Cross/input.lua` prints that at login – keep it.
- Blizzard's main bar is **not** called `MainMenuBar` anymore and buttons sit in per-button
  containers. Find a bar by climbing parents from `ActionButton1` until the parent is `UIParent`
  (`ResolveBar` in `DeckUI_Cross/input.lua`). Hide by reparenting to a hidden frame +
  visibility state driver + SetParent hook.
- **Hiding the bars took Blizzard's leave-vehicle button with it** (reported 2026-09-29), which
  left no way out of a vehicle on the Deck. `MainMenuBarVehicleLeaveButton` is a child of
  Action Bar 1 (`MainActionBar`) - confirmed 2026-09-29 with `/dc bars`, which prints its parent
  chain: `MainActionBar > DeckCrossBarHider > UIParent`. The fix does not depend on it: we carry our own
  `DeckCrossLeaveVehicle` (movable, "Leave vehicle"), shown whenever `CanExitVehicle()` or
  `UnitOnTaxi` and none of Blizzard's leave buttons `IsVisible()`, so it never doubles up.
  It is polled (0.2 s) on purpose: taxis have no clean start event, and Blizzard updates its
  own button on the same events, so asking about its visibility there would race it.
  `VehicleExit` / `TaxiRequestEarlyLanding` are not protected - a plain button works in combat.
- `ActionButtonTemplate` has a `TextOverlayContainer` at frame level 500 whose textures darken the
  button while a modifier is held – strip its textures (`CleanOverlay`).
- Blizzard's template draws the **icon in the BACKGROUND layer**; anything of ours behind the icon
  must be BACKGROUND sublevel -8/-7.
- Blizzard's highlight/pushed/checked textures are neutralised (methods replaced with a no-op)
  and replaced by our own masked additive glows.
- The assistant's buttons are found through **`C_ActionBar.IsAssistedCombatAction(slot)`** -
  the action bar owns that question, not `C_AssistedCombat`, which has only `GetActionSpell`,
  `GetNextCastSpell`, `GetRotationSpells` and `IsAIAvailable` (swept out of the client on
  2026-09-23, after two wrong guesses cost an evening). **An assistant slot cannot be
  recognised by its contents**: `GetActionInfo` on it returns whatever spell the assistant
  recommends at that moment, so a slot holding the assistant reads as an ordinary changing
  spell. Only that call knows.
  Everything assistant-related hangs off one table (`assistedButtons`): the painted icon, the
  red no-target ring, the failure flash. An empty table means none of it can show, which looks
  like three separate bugs - `/dc assist` prints the API, the buttons holding the action, the
  flag and the ring's actual colour, and when the API is missing it sweeps the namespaces for
  whatever replaced it.
- The assistant indicator (`DeckUI_Cross/assist.lua`, off by default) answers the question a
  button cannot: *is* there nothing to press, or am I missing something? It shows the spell
  `GetNextCastSpell()` recommends, with a green ring when it is castable **right now** and grey
  plus a cooldown swirl when it is not - so a grey ring is the confirmation that waiting is
  correct. Asked for by the owner while tanking, where the assistant is weakest.
  The trick is spell **61304**, the global cooldown itself: a spell whose cooldown ends no later
  than the GCD is only held up by the GCD, and treating that as "not ready" would make the
  indicator flicker with every cast instead of answering anything. The swirl deliberately shows
  the spell's own cooldown only.
  **It only works while the assistant sits on one of the player's action bars** (owner's test,
  2026-09-29) - the settings hint and the 1.0.3 changelog say so. Why was not measured; do not
  "fix" it by guessing at a cause. It is still a separate frame because that slot need not be
  on a cross: the assistant may sit on a bar the crosses do not mirror and be reached by a key
  binding, with no cross button to decorate.
- Feedback that a press arrived: Blizzard's PUSHED state is too short to see on a tap, so
  `ShowPushed` holds our glow for `PUSH_MIN` past the release. A rejected cast flashes
  `DeckFailed` red on whichever button is lit, falling back to the assistant's buttons.
- **State on a cross button is shown with colour, never with brightness.** Brightness is
  already taken: `SetGroup` in `DeckUI_Cross/core.lua` dims whole groups with `b:SetAlpha`,
  and out of combat the bar sits at roughly a quarter alpha, where a darkening veil is
  barely a difference. The "assistant has no target" state therefore rides on the ring
  colour (`RING_NOTARGET`), set inside `SetGroup` itself - it repaints every dim tick, so a
  colour written anywhere else would be overwritten four times a second.
  **Do not skip unchanged ticks**: LibActionButton sets a button back to alpha 1 whenever
  its action updates (every page change), and only the next tick dims it again.
- Assisted combat: the purple rotation highlight is hidden on cross buttons; the assistant's
  changing icon is painted by polling `C_AssistedCombat.GetNextCastSpell()` every 0.1 s. This
  **never ran before 2026-09-23** because the detection above asked a function that does not
  exist, leaving `assistedButtons` empty and the poll returning on its first line. Do not trust
  this entry without `/dc assist` saying `API yes` and a non-zero button count.
  **"The assistant stops while I hold the key" was measured and is not ours** (2026-09-18,
  `/dc trace` on the PC): the engine keeps repeating, the assistant keeps naming Sunfire,
  and every attempt fails with `Invalid target` because the player has no target at all -
  the moment one exists again the rotation continues by itself. `Spell is not ready yet`
  in between is just the repeat outrunning the global cooldown. Re-targeting cannot be
  automated: `TARGETNEARESTENEMY` and friends need a hardware event, which is exactly what
  Blizzard locks down.
  The press-and-hold repeat lives entirely in the engine and stops the moment the key
  combination stops matching. LT/RT are **analog** triggers driving the emulated Shift/Ctrl,
  so easing off below the threshold releases the modifier while the direction key stays
  down, and the returning trigger brings no fresh key-down for the combination - the repeat
  does not resume. `/dc trace` prints modifier edges, casts and any re-applied bindings with
  timestamps to tell that apart from a cast that simply failed.
- **Camera zoom on LB + D-pad up/down** (`DeckCrossDB.lbZoom`, off by default, Deck only;
  not yet tested in game). The owner could not bind it: only Shift/Ctrl/Alt combine with
  another key, and a gamepad button becomes one only through `GamePadEmulate*` - Shift/Ctrl
  are LT/RT, and `SetupGamepad` used to force Alt to "none". With the option LB is Alt, and
  `ALT-PADDUP`/`ALT-PADDDOWN` go to `CAMERAZOOMIN`/`CAMERAZOOMOUT` as override bindings
  (smooth while held, one step on a tap - `Bindings_Standard.xml`). Switched off, Alt goes
  back to "none" only if it is still LB.
- Gamepad glyph atlases (`Gamepad_Ltr_Face_*`) do not exist on this client; we ship our own
  TGA glyphs in `DeckUI_Cross/textures/`.
- Health/power values may be *secret values*: display them via tags / Blizzard helpers
  (`AbbreviateNumbers`), never compare or compute with them.
- **So are cooldown numbers.** `C_Spell.GetSpellCooldown(id)` hands back `startTime`,
  `duration` and `modRate` as secret values for real spells - measured 2026-09-23 on Shield of
  the Righteous, while the same call for the GCD spell 61304 returned plain numbers. Comparing
  one throws *"attempt to compare a secret number value"* and taints the addon. Readable are the
  booleans in that table: `isActive`, `isEnabled`, and `isOnGCD` on the GCD entry. The raw
  numbers may still be passed straight into Blizzard's own `Cooldown:SetCooldown` - handing them
  on is fine, doing arithmetic on them is not. `assist.lua` is built on exactly that line.
- oUF: `ClassPower` / `Runes` dots are StatusBars with a masked WHITE8x8 fill; `[deck:hpshort]`
  is our custom tag.

## Bags module (bag window tested in game 2026-09-29; bank not yet)

Built from Blizzard's 12.1.0 source (Gethe/wow-ui-source, `live`, read 2026-09-29), not from
memory - the bank changed completely in 11.2. Plan: one grid first, categories second.
All windows share one update loop in `core.lua`: events only mark windows dirty, one pass
per frame lays out (`w.Layout()` -> sections, columns, scale) and refreshes the shown ones.
- **Blizzard's bag frames keep running, parked under a hidden frame**; our window shows while
  `IsAnyBagOpen()` says so (hooks on the open/close functions plus a 0.2 s poll). We do not
  replace `ToggleAllBags` and friends: the bank's `OnShow` calls `OpenAllBags`, and our code in
  that call chain would taint the bank frame for the rest of it.
- Item buttons are **Blizzard's `ContainerFrameItemButtonTemplate`**, with no click script of
  ours: its handler covers every case (potion in combat, merchant, auction house, bank deposit,
  split). It learns its bag from an attribute (`SetBagID`) precisely so that stays untainted.
  The grid scales as a whole; the template's overlays are laid out for 37 px.
- Bank facts: `Enum.BagIndex.Bank`, `BankBag_1..7` and `ReagentBank` are gone. Bank slots
  are ordinary bags: `CharacterBankTab_1..6` (6-11), `AccountBankTab_1..5` (12-16), so the
  same item template serves them. A right click on a bag item at the bank deposits into
  `BankFrame:GetActiveBankType()`, which is nil unless Blizzard's `BankFrame` and its panel
  are shown - so `bank.lua` parks `BankFrame` under a hidden parent (and strips its
  `UIPanelLayout-area`, so the invisible frame does not take the left panel slot) and writes
  the type we display into `BankFrame.BankPanel.bankType` - what Inventorian does too.
  The parked frame **must keep a position**: with the panel manager out of the way nothing
  places it, and Blizzard's `GetContainerScale` does arithmetic on `BankFrame:GetRight()`
  whenever a bag opens while the bank counts as shown - nil crashed ContainerFrame.lua:1167
  (2026-09-29). It sits with its right edge on the screen's left edge.
  Never `BankPanel:SetBankType()`: it rebuilds Blizzard's whole invisible panel.
  The bank opens and closes on `PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE` for Banker,
  CharacterBanker and AccountBanker; closing our window calls `C_Bank.CloseBankFrame()`.
  One bank tab at a time: a tab is 98 slots, six in one grid would be 2000 px tall.
  Buying a tab goes through `BankPanelPurchaseButtonScriptTemplate` with the
  `overrideBankType` attribute - Blizzard's own template for addons, so the purchase stays
  untainted. Sorting a bank is `C_Container.SortBank(bankType)`, the only form Blizzard's
  code uses; it asks first while the CVar `bankConfirmTabCleanUp` is on.
- **Category view** (bags only, default on, `DeckBagsDB.categories`; the bank keeps its tabs,
  whose deposit rules a category view would hide). Groups in order: New, Equipment,
  Consumables, Trade Goods, Quest, Other, Junk, then one stand-in empty slot per kind of bag
  (normal / reagent) showing the free count. The class comes from `C_Item.GetItemInfoInstant`,
  which needs no server round trip. Items move between groups, so this view re-lays out on
  `BAG_UPDATE_DELAYED` (`w.relayoutOnMove`) - but never on `ITEM_LOCK_CHANGED`, which fires on
  pickup and would reshuffle the grid under the cursor.
- **Old-expansions filter** (pocket-watch button, both windows, session only): dims items whose
  `expansionID` (15th return of `C_Item.GetItemInfo`) is below `GetServerExpansionLevel()`,
  through the search's own overlay so it combines with a search. Uncached items count as
  current until `ITEM_DATA_LOAD_RESULT`. "Old" is the item's own expansion - a hearthstone is 0.
- `/bags debug` prints Blizzard's open state, slots per bag and how many frames are parked;
  `/bags bank` prints the bank types, their lock state, tabs and slots.

## Quests module (quests tested in game 2026-09-29; the rest not yet)

Our own objective tracker, replacing Blizzard's completely. Built from Blizzard's 12.1.0
source (read 2026-09-29). Sections in Blizzard's order: Scenario (with Mythic+, delve header,
bonus steps, scenario spells), Campaign, Quests, Collections, Achievements,
Traveler's Log, Endeavors, Recipes, Bonus Objectives, World Quests.
- Sections register with `ns.RegisterSection(key, { title, order, Collect, Init })`;
  `core.lua` draws whatever entries they return, redraws at most once per frame, and a
  section that errors shows an error line instead of taking the others down.
  **What a Collect returned is kept per section** (code review, 2026-09-30):
  `ns.RequestUpdate()` drops all of it, `ns.RequestUpdate("recipes", ...)` only the named
  sections, `ns.RequestRedraw()` only lays out again (fold, scroll, move, widget layout,
  settings). `ns.ticking[key]` re-collects just that section - `true` each second (Mythic+
  timer), `"minute"` once a minute (world quest countdowns). tracking.lua narrows its three
  noisy events (`CRITERIA_UPDATE`, `BAG_UPDATE_DELAYED`, `CURRENCY_DISPLAY_UPDATE`); every
  other event still drops everything. A section that looks stale is missing its event.
- **Blizzard's tracker is switched off the kiosk way**: `SetCanAddModules(false)` +
  `RemoveAllModules()` at PLAYER_LOGIN, before `ObjectiveTrackerManager:Init` (which waits for
  PLAYER_ENTERING_WORLD), so no module is ever added and none registers an event. Then
  `ObjectiveTrackerFrame:Hide()` - switched on mid-session, the modules are frozen but alive.
  The frame keeps its own QUEST_ACCEPTED auto-watch (CVar `autoQuestWatch`).
  **Do not go back to removing single modules** (`container:RemoveModule`): that writes into
  Blizzard's module list and taints every later layout of the modules left behind - their
  quest item and scenario spell buttons would be blocked in combat. That was the first
  version, replaced the same day once everything was covered here.
- **Quest items and scenario spells are `SecureActionButtonTemplate`** (type "item" /
  "spell") - Blizzard's buttons call `UseQuestLogSpecialItem` / `CastSpellByID` from
  untainted code, which ours is not. Secure buttons cannot be moved in combat, and neither
  can anything anchored to them, so they hang off UIParent at screen coordinates copied from
  the rows out of combat and are re-placed on PLAYER_REGEN_ENABLED. Spell cooldowns go into
  the Cooldown frame untouched (secret values, see the Cross notes).
- **The "find a group" eye** (reported missing 2026-09-30; not yet tested in game) is
  Blizzard's own `QuestObjectiveFindGroupButtonTemplate` (quests, world quests, bonus
  objectives, shown when `QuestUtil.CanCreateQuestGroup`) and
  `ScenarioObjectiveTrackerFindGroupButtonTemplate` (the scenario stage, when
  `C_LFGList.CanCreateScenarioGroup`; its ID is the 13th return of `C_Scenario.GetInfo`).
  The quest one reads its quest from an attribute (`SetUp`), so the click runs Blizzard's
  code. Not secure buttons: they sit on the rows, one frame level above them.
  Styled like the map's buttons (art at alpha 0, dark square, thin edge) - textures only.
- **No Blizzard UI widgets in the tracker** (removed 2026-09-30). It used to host the zone
  set, the delve header (step widgetSetID) and scenario sets 514/252 in its own
  `UIWidgetContainerTemplate` frames - and that taints: widget frames come from one pool the
  whole game shares, a frame set up from our code keeps fields written while tainted, and its
  next user runs tainted too. In Midnight that is fatal the moment a secret value is involved:
  a map POI tooltip failed with *"attempt to perform arithmetic on local 'barWidth' (a secret
  number value, while execution tainted by 'DeckUI_Quests')"* in `InitPartitions`. **Never
  call `RegisterForWidgetSet` from addon code.** What a widget shows is drawn from the
  `C_UIWidgetManager.Get*WidgetVisualizationInfo` data with frames of our own.
  `ns.WidgetLines(section, setID)` in core.lua reads the common kinds (StatusBar,
  DoubleStatusBar, the text kinds, scenario currencies) into lines; bars take the raw,
  possibly secret numbers (`line.range`), a percentage only when they are plain. It serves
  the zone set ("Zone" section) and the scenario's sets 514/252 plus the stage set.
  The delve header is `DelveEntry` in scenario.lua (tier, lives, the delve's effects, the
  treasure). `UPDATE_UI_WIDGET` re-collects only the section that shows the widget's set;
  a widget with `hasTimer` ticks its section each second. Other widget kinds are skipped.
- Blizzard shows no +2/+3 chest times; ours use the keystone rule (80% / 60% of the limit).
- The tracker grows from its top edge (`D.PinTopLeft`); `/quests reset` brings it back.
- `/quests debug` says whether Blizzard's tracker is gone, how many widget containers have
  widgets, and the secure button state.

## Map module (not yet tested in game)

A square minimap in a DeckUI frame and a smaller world map. Built from Blizzard's 12.1.0
source (read 2026-09-29).
- **The minimap moves out of Edit Mode's reach.** `MinimapCluster` is an Edit Mode system
  (`Enum.EditModeSystem.Minimap`); its SetPoint/SetScale/ClearAllPoints are Edit Mode
  overrides re-applied on every layout update (EDIT_MODE_LAYOUTS_UPDATED, spec change, ...).
  Edit Mode never touches `Minimap` itself, so `Minimap` is reparented into our frame and the
  cluster is parked under a hidden parent. Nothing in the minimap is protected.
- Blizzard's pieces come along: tracking, calendar, addon compartment (on mouse-over, like
  the zoom buttons), mail/crafting indicators and instance difficulty (always). Blizzard
  re-anchors some of them (`SetHeaderUnderneath`, `MiniMapIndicatorFrame_UpdatePosition`),
  so they are re-placed from post-hooks on those. Zone text, clock and coordinates are ours.
- Square: `Minimap:SetMaskTexture(WHITE8x8)`, the round `MinimapCompassTexture` at alpha 0,
  and the global `GetMinimapShape() = "SQUARE"` - an addon convention Blizzard does not
  define; LibDBIcon and DeckUI's own minimap button (`D.UpdateMinimapButton`) read it.
- **The world map is only scaled** (`WorldMapFrame:SetScale`): it is a UI panel re-anchored by
  the panel manager on every update, which divides by the frame's scale - a scale survives,
  a SetPoint would not. Never call `UpdateUIPanelPositions` from our code: it would run the
  panel manager tainted, the classic path to panels blocked in combat.
- **The world map is a minimal window** (owner's choice B+C, 2026-09-29): frame art at alpha 0,
  a thin DeckUI edge, breadcrumbs/close/filter/floor/side-panel toggle only under the mouse,
  maximize button invisible and unclickable, CVar `miniWorldMap` = 1 and `questLogOpen` = 0 at
  login. **The 67-pixel title band stays**: Blizzard's fixed `TITLE_CANVAS_SPACER_FRAME_HEIGHT`,
  and shrinking it means changing the size `Minimize()` hands to the panel manager - tainted,
  that blocks panels in combat.
- **The dark band behind the breadcrumbs hangs off `WorldMapFrame`, not the BorderFrame.**
  The BorderFrame is HIGH strata; as its child the band drew over the breadcrumbs and all but
  hid them (owner's screenshot, 2026-09-30). The one-pixel edge (no fill) may stay up there.
- The map's buttons (breadcrumbs, close, filter, map pin) wear the quest-log-tab look: their
  art at alpha 0, a dark square with a thin edge, gold for the current crumb / active pin.
  Only textures change, never scripts. New crumbs are styled from a post-hook on
  `NavBar_CheckLength`; `/deckmap debug` lists the crumbs.
- **The world map is movable** because it left the panel manager: `UIPanelLayout-defined` =
  true and no `UIPanelLayout-area`, so Show/HideUIPanel just show and hide it (the BankFrame
  trick from Bags), Escape via UISpecialFrames, dragged by a 24-px strip above the breadcrumbs
  (a drag on the map pans it). Other left panels no longer make room for it.
- **The quest log beside it** (QuestMapFrame) is restyled the same way: parchment backgrounds,
  `questlog-frame` borders and the side tabs' `common-sidetab` art at alpha 0 or replaced by
  flat colour, one dark panel behind the content. Quest lines, headers and rewards stay.
- Coordinates and fading on the world map are Blizzard's own CVars (`worldMapShowPlayerCoords`,
  `worldMapShowCursorCoords`, `mapFade` - the last has no checkbox in the game's options),
  driven through `ns.cvars`, a table proxy so `D.Checkbox` can write CVars.
- `Enum.AddOnRestrictionType.Map` exists ("a map that applies addon restrictions"), but
  nothing says which maps or APIs; minimap coordinates are simply blank when the position
  API returns nothing. `/deckmap debug` prints whether the restriction is active.

## Tooltip module (not yet tested in game)

GameTooltip restyled and extended. Built from Blizzard's 12.1.0 source (read 2026-09-30).
**GameTooltip is one frame the whole game shares** - the widget taint above applies to it
just the same, so:
- **Never write a field onto a tooltip, its `NineSlice` or `GameTooltipStatusBar`.** State
  lives in our own tables keyed by frame (`backdrops`, `borderColor`). Only methods that
  change what is drawn (alpha, colour, points, textures).
- **Never call `tooltip:Show()`, `SetWatch` or `RefreshData`.** `GameTooltip_OnShow` does
  padding arithmetic on widths that can be secret. The only rebuild we trigger is Blizzard's
  own `GameTooltip:SetUnit("mouseover")` when an inspect answer arrives.
- Look: a post-hook on `SharedTooltip_SetBackdropStyle` (re-run on every hide) sets the
  NineSlice to alpha 0 - Blizzard only Shows/Hides it - and colours our BackdropTemplate
  frame one level below the tooltip. The edge takes quality/class colour for one showing.
- Place: a post-hook on `GameTooltip_SetDefaultAnchor` re-anchors only those tooltips to
  `DeckTooltipAnchor` (movable, per device); owned tooltips keep their place.
- Lines: `TooltipDataProcessor.AddTooltipPostCall` for Unit/Item/Spell - Blizzard runs them
  before its own Show and again on `TOOLTIP_DATA_UPDATE`. Unit name, class and GUID are
  secret for units that are not player-controlled: checked with `issecretvalue`, and a
  target name that may be secret goes into `AddDoubleLine` whole, never concatenated.
- Health bar: Blizzard's (it watches the unit securely), restyled with textures only.
- Inspect for other players' spec/item level: one at a time, 1.5 s apart, 5 s timeout, not
  in combat nor while Blizzard's inspect window is open; results cached by GUID for 5 min.
- `/decktip debug` prints the styled count, anchor, scale, NineSlice alpha and inspect state.

## Testing checklist (owner does this in-game)

1. `/console scriptErrors 1`, `/reload`, no error window.
2. Chat shows `DeckUI Cross: controller mode` (Deck) / `keyboard mode` (PC).
3. LT/RT + key casts and lights the button; assistant held repeats; icon follows.
4. `/deck unlock` → drag → positions stick per device.
5. Every checkbox / slider / button in all nine tabs works without error.
6. Fresh-install test: move SavedVariables away, log in, defaults apply.

## Roadmap / parked

- Release on CurseForge as **Beta** after the checklist (see CURSEFORGE_DESCRIPTION.md;
  add `X-Curse-Project-ID` back to the four `.toc` files with the real numeric ID – it was
  removed rather than shipped as a placeholder, `X-Website` is already filled in).
  The first Beta goes up **by hand** with `package.ps1`, so the owner sees what users get.
- Releases are automated: push a tag `v<version>` and `.github/workflows/release.yml`
  runs `package.ps1 -Version <tag>` on the runner and uploads the result through the
  CurseForge API with `upload-curseforge.ps1`, with the changelog from `changelog.ps1`
  (hence `fetch-depth: 0` on the checkout - a shallow clone has no tags to diff against).
  Run it by hand first from the Actions tab with **dry_run** on and the release type
  on `auto` - that rehearses a tag exactly, including the type it would pick, and
  builds and resolves the game version without uploading. Needs the repository secret
  `CF_API_TOKEN`. Raise the version with `bump-version.ps1` before tagging.
  **The tag's suffix decides the release type**: `v1.0.1-beta` goes up as a beta,
  `v1.0.1-alpha` as an alpha, and a plain `v1.0.1` as a full release that reaches
  every user - so a stray tag push is no longer harmless. The suffix stays part of
  the version, so archive and `.toc` say what the file page says; a pre-release
  takes the changelog section of the version it leads up to (`1.0.1-beta` reads
  `## 1.0.1`).
  The BigWigs packager was looked at and dropped: it expects the main addon at the repository root, while ours
  sits in `DeckUI/` beside the three modules, which `move-folders` cannot untangle.
  Switching to `.pkgmeta` externals would mean adopting that layout after all.
- Parked by owner's choice: set switching via LB/RB, controller navigation in the settings
  window (built and removed – he uses the trackpad), German localisation.
