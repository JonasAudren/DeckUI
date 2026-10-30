# DeckUI – project notes for Claude Code

World of Warcraft addon suite (Lua) for the **Steam Deck and PC**, written by Gottlieb
as a learning project. Retail client, currently **Midnight 12.1.5 (Interface 120105)** - verified in game with
`/deck build` on 2026-10-20, which compares the running client against our `.toc`. That number also
picks the CurseForge game version on upload, so it is the one place to change at a patch
(`bump-version.ps1 <version> -Interface <new>`; 1.7.1 did exactly that for 12.1.5, after the
live UI source was diffed against 12.1.0 and nothing DeckUI uses had moved). Beware the PTR:
a patch exists as `wowxptr` before it goes live, and filing a release under it hides the
addon from everyone who plays.
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
DeckUI_Nav/      module: compass, navigation target, /way (/decknav) off by default
DeckUI_Week/     module: the week overview for all characters (/week) off by default
```
Modules are `LoadOnDemand`, depend on `DeckUI`, and register a settings tab with
`D.RegisterModule(key, { title, build = function(content) end })`. The hub loads
enabled modules from `DeckUIDB.modules` at `ADDON_LOADED`.

`package.ps1` builds the upload zip: `dist\DeckUI-<version>.zip` with the ten addon
folders at the **top level** (a wrapping folder would install everything one level too
deep), README, LICENSE and THIRD-PARTY inside `DeckUI\`, without the `.github`/`utils`
clutter from `libs\oUF` and without the unused LibStub/CallbackHandler copies that the
other libraries bundle. It aborts if the ten `.toc` files disagree on version or interface.
The list of addon folders lives once, in `release-common.ps1`, which both scripts dot-source
(with `Get-TocField`); a new module is added there and to `D.MODULE_*` in `DeckUI/core.lua`.
`bump-version.ps1 <version>` raises `## Version` (and with `-Interface` the interface)
in all ten at once - `package.ps1 -Version` only stamps the staged copies, so without
the bump the repository and CurseForge drift apart. `changelog.ps1 <version>` produces the
changelog the release sends along: the `## <version>` section of `CHANGELOG.md` when there
is one, otherwise the commit subjects since the previous tag. Write the section - the
fallback carries build and release plumbing that means nothing to a player. It falls back
rather than failing so a forgotten section never blocks a release, and `bump-version.ps1`
says so when the section is missing.

**Mists of Pandaria Classic** (5.5.4, Interface 50504, `C:\Spiele\World of Warcraft\_classic_`) is being
ported, plan and probe results in `MISTS_PLAN.md` (phase 1 since 2026-10-25). The client reads
`<Name>_Mists.toc` where a folder has one, else the retail `.toc` - so a folder without one must not be
loaded there: `D.MISTS_MODULES` (core.lua) lists the ported modules and `D.MODULE_ORDER` drops the rest
in Mists. A `_Mists.toc` lists only the files that run there; an option in the settings shows when its
file has loaded (`if D.ApplyX then`), and a debug command of a missing file says so. Code asks
`D.IsMists` / `D.IsRetail`. `package.ps1` checks the `_Mists.toc` files on their own interface number,
`bump-version.ps1 -MistsInterface` raises it; since 2.0.0 the upload files one zip under both games (`upload-curseforge.ps1 -Interface`
takes a list, the workflow hands it `interface` and `mists_interface`). In the classic client `DeckUI`, `DeckUI_Cross`, `DeckUI_Orbs`, `DeckUI_Spec`, `DeckUI_Bags`, `DeckUI_Tooltip`, `DeckUI_Map`, `DeckUI_Quests`, `DeckUI_Nav` and `DeckUI_Week` are junctions; the Mists hub loads every file but damagemeter.lua and talkinghead.lua, Spec runs `core_mists.lua` (talent groups). Bags: Mists' item button template has no mixin (filled through the global SetItemButton* helpers, `PaintMists` in core.lua; its click reads only the parent's ID), `bank_mists.lua` is the old bank (container -1 and bank bags **5..11** - `ITEM_INVENTORY_BANK_BAG_OFFSET` 4, whatever the shared enum calls ReagentBag - so no reagent bag there, in Bags or the info bar), no sorting. Tooltip: `repdata_mists.lua` from wago `wow_classic`, item level of others summed from the inspected gear (no C_PaperDollInfo). Map: Mists' minimap is the old one - border, tracking, clock, zoom and world map button hang off MinimapBackdrop, a child of Minimap, so they are placed or faded like retail's pieces (`PIECES` for Mists); its world map is Cataclysm's and keeps Blizzard's look for now (windowed and movable; never scaled - its canvas reads the raw cursor position, so a scaled map put the highlight and clicks beside the mouse), the coordinate CVars do not exist there. Quests: Blizzard's WatchFrame is switched off (events gone, hidden, faded in combat if shown); `quests_mists.lua` reads the old quest log the way WatchFrame does (GetQuestIndexForWatch, GetQuestLogTitle, SetSuperTrackedQuestID), `tracking_mists.lua` has zone widgets and achievements (GetTrackedAchievements), scenario.lua shows challenge modes with their medal times (`MedalEntry`); no campaign, world quests, delves, hunts or guide. Nav: every file asks `ns.ST` / `ns.UW` / `ns.NAV` (and `ns.NavEvent`, `ns.MapPoint`), which are C_SuperTrack / C_Map / C_Navigation in retail and `nav_mists.lua`'s stand-in in Mists: one waypoint of ours instead of Blizzard's pin, the super-tracked quest Mists has, map yards from two world positions; Ctrl-click on the world map is heard by our own press/release hooks there; no beacon, no vignettes. Week: `data_mists.lua` replaces data.lua, `collect_mists.lua` hands core.lua its collectors (`ns.COLLECTORS`: lockouts plus Raid Finder wings from `GetLFGDungeonNumEncounters`, the world bosses' weekly quests, challenge-mode medals from `C_MythicPlus.GetSeasonTimesForMap`, valor/conquest and the charms, seals and coins, today's dailies, Pandaria's reputations from `ns.MISTS_FACTIONS` through `D.FactionStatus`) and `ns.LearnWeeklies` (GetQuestLogTitle's frequency; dailies go into `DeckWeekDB.dailies` with their quest log header, counted per day with their own `resetAt`), `view_mists.lua` the table's columns and details (`ns.COLS`, `ns.FillCells`, `ns.DetailsTop`/`DetailsRight`) - window.lua keeps frame, lockouts and weekly quests; `/week record` reads `GetQuestsCompleted` there.
**oUF carries Mists patches**, each marked `-- DeckUI: Mists` (blizzard.lua: oUF 13's hide-and-park where
`SetRolesets` is missing; ouf.lua, private.lua, elements/auras.lua, classpower.lua, runes.lua) - **redo them
at every oUF update**. They hand over to two files only the Mists toc loads, before oUF:
`DeckUI_Orbs/auras_mists.lua` (a stand-in for the AuraContainer widget, which Mists lacks: exactly the
container and button methods oUF and DeckUI call, `ns.MistsFlowAxis`; Orbs uses `ns.FLOW` for the axes)
and `classpower_mists.lua` (shadow orbs, embers, fury, eclipse, chi, combo points on the target, rune
colours by type; rules from Blizzard's 5.5.4 class bars, spell IDs from wago `wow_classic`).

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
- **The settings window** (`DeckUI/panel.lua`, rebuilt 2026-10-02 after the menu review; tested in
  game the same day): 600x540, a sidebar of pages grouped by theme (`D.PAGE_GROUPS`, names in
  `D.PAGE_NAMES`; a page no group names lands under "More"), the page scrolls, and a bar at the
  bottom collects changes waiting for a reload (`D.NeedReload(key[, false])`) with a Reload
  button. Pages are registered with `D.RegisterModule` and build themselves; each is measured
  for the scroll height. Pages use **`D.Flow(content)`** (widgets.lua), which stacks the
  widgets without pixel numbers; `D.Tip` puts an explanation on mouse-over instead of a hint line. Buttons wear the flat
  look (`D.FlattenButton`, `D.FlatBox`). **Modules are switched on their own page** (button top
  right, `D.UpdateModuleSwitch`); a module that is off has no page yet, so a stand-in
  (`def.stub`, `D.MODULE_DESCRIPTIONS`) is listed greyed and replaced when the module registers.
  "General" is shown as "Overview" (modules with their state, minimap button, damage meter, Lua
  errors); merchant and loot live on "Loot and merchant" (key "Loot"). "Cross hotbar only on
  Steam Deck" sits on the Cross page and its stand-in (`D.SetCrossDeckOnly`). **Every page is
  built with `D.Flow`** since 2026-10-02 (`Flow:Pair`, `Flow:Cycles` for buttons side by side);
  a new option is one more line, never a pixel shift. Explanations go into the widget's tooltip,
  a page keeps at most a line or two of hint; settings that need a reload call `D.NeedReload`.
  The footer has **Move** (`D.SetUnlocked(true, set)` unlocks only the page's frames,
  `D.PAGE_FRAMES`; `D.IsUnlocked(key)` is what frames ask, unlock callbacks get the set too)
  and **Defaults** (`D.PAGE_RESET`: clears the page's keys in its SavedVariables - `match` where
  pages share a table, `keep` for data like the week's characters - never positions, then
  reloads so every module refills its defaults). `/deck <page>` opens a page (`D.FindPage`).
  **A new frame or page needs its entry in `D.PAGE_FRAMES` / `D.PAGE_RESET`.**
  **Sub-pages** (menu review 2026-10-28, the Overview had eighteen checkboxes): `D.PAGE_PARENT[key]
  = parent` lists a page indented under its parent, and **only while the parent or a sibling is on
  show** (`SubShown` in `LayoutSidebar`, re-run from `ShowTab`); a parent wears ">" / "v" at the
  right. The sidebar is a scroll frame (mouse wheel, the page on show kept in view) - the window
  itself cannot grow, 540 is what the Deck's 800-pixel screen allows.
  Hub sub-pages: Screen / Targets / Windows under the Overview (panel.lua, DeckUIDB keys per page in
  `SCREEN_KEYS` ...). Module sub-pages register with the module (`D.RegisterModule` in its
  config.lua, with their own `D.PAGE_FRAMES` / `D.PAGE_RESET` entries set there where the hub cannot
  know the keys): Player, Target, Target of target, Your debuffs, Buff bar, Enemies and bosses under
  "Player and target"; Controller under the Cross hotbar; Minimap and World map under Maps; Extras
  under Tooltip. The parent page keeps the module switch and what is left; `/deck <name>` finds
  sub-pages by their sidebar name too.
- **Questions to the player go through `D.Dialog`** (`DeckUI/widgets.lua`: text, two buttons,
  optionally a money input), **never `StaticPopup_Show`** - and never a Blizzard function that
  shows one (`QuestMapQuestOptions_AbandonQuest`). StaticPopup1..4 are shared by the whole
  game; one shown from addon code keeps tainted fields for the next Blizzard dialog on the
  same frame. The bank's money, deposit and sort questions, the Cross default-bindings
  question, abandoning a quest and the Edit Mode reload prompt all use it (2026-10-01).
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
  folder instead of on the server (Devices page, "Keep on this device: Key bindings"). The CVar
  lives in Config.wtf, so it is per machine by itself - no DeckUIDB entry. Switching it on
  saves the loaded bindings locally first; switching it off does *not* save, which would
  upload this machine's set over the server's. `/deck device` prints the state.
- **Action bar contents per device** (`DeckUI/actionbars.lua`, `DeckUIDB.keepBars`, off by
  default; tested in game 2026-10-08). What sits on the bars is server-side per character and
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
  default; tested in game 2026-10-08). Blizzard's layouts and the choice of the active one are
  server-side, per character and spec. The owner makes one layout per device in Edit Mode;
  DeckUI learns by *name* which one is active on this device (`DeckUIDB.editLayouts`, keyed
  like the bars) and switches back at login, /reload and spec change. The name is read from
  `EditModeManagerFrame.layoutInfo` (presets first, then saved layouts - `activeLayout`
  indexes that merged list), read only. **`C_EditMode.SetActiveLayout` from an addon leaves
  Edit Mode's manager tainted for the session**, so every switch asks for a reload at once
  (own prompt window, not a StaticPopup), and nothing is learned until that reload - should
  the manager not have caught up, learning the old name would undo the switch.
  `/deck layout` prints active and saved layout.
- **At the merchant** (`DeckUI/merchant.lua`, `DeckUIDB.autoSellJunk` / `autoRepair` /
  `repairGuild`, "Loot and merchant" page, the first two off by default; tested in game 2026-10-01): on
  MERCHANT_SHOW repair first (guild funds when allowed), then `C_MerchantFrame.SellAllJunkItems`,
  and repair once more a second later if the gold was short. C APIs only - Blizzard's "sell all
  junk" button asks through a StaticPopup, which we skip rather than show (see `D.Dialog`).
- **Loot** (`DeckUI/loot.lua`, `DeckUIDB.fastLoot` / `lootWindow`, "Loot and merchant" page, both off by
  default; replacing Plumber's LootUI; tested in game 2026-10-01): fast loot takes every slot with
  `LootSlot` on LOOT_READY, "auto" worked out from `autoLootDefault` and the AUTOLOOTTOGGLE
  modifier (Plumber's fix for auto loot reported as manual). The window: Blizzard's LootFrame
  only gets `UnregisterEvent("LOOT_OPENED"/"LOOT_CLOSED")` - re-registered when switched off -
  and ours shows instead (manual loot, or what auto loot left behind). Bind-on-pickup stays
  Blizzard's LOOT_BIND dialog (UIParent's handler), group rolls are untouched. With auto loot
  a feed lists what was taken for five seconds (owner saw only the chat): the slots are read on
  LOOT_READY before they are taken - not the chat lines, which can be secret. The list has its
  own place ("Loot list"); a `D.OnUnlock` callback shows window and list with a sample
  while unlocked, since both are hidden otherwise and could not be grabbed. Take all is
  also the binding DECKUI_LOOT_ALL. **No slot call outside an open loot** (`lootOpen`: LOOT_READY/OPENED
  to LOOT_CLOSED, a LOOT_OPENED after the close ignored, slots taken once per loot, the window hides
  itself when the loot is gone): Mists crashed the client (ACCESS_VIOLATION, 2026-10-27/28) with our
  window still up after the loot had closed - fixed 2026-10-28 on that suspicion, not yet confirmed.
  It crashed once more (a bind-on-pickup item from a satchel, its row still shown): **a slot is read
  only while `LootSlotHasItem(slot)`** - Blizzard's Mists LootFrame asks that before every
  GetLootSlotInfo. Crash number ten (2026-10-29, a click on a row, the quest book scanner off): **the
  tooltip is dropped before every `LootSlot` and every refill** - `SetLootItem` keeps pointing at its slot,
  and a reused row kept a tooltip of a slot already taken; and `CloseLoot` never runs inside a loot event
  (one frame later). Held in the owner's first test the same day. In Mists LootFrame keeps LOOT_CLOSED, whose handler hides the LOOT_BIND question. The one Blizzard call that writes elsewhere is
  `HandleModifiedItemClick` on a modified click (chat link, dressing room).
- **Loot rolls** (`DeckUI/lootroll.lua`, `DeckUIDB.lootRolls`, "Loot and merchant" page, off, live;
  tested in game (Mists) 2026-10-27, retail not yet; owner's wish 2026-10-27). Both games still roll (retail too, Transmog
  instead of Greed where the item offers it; neither game's frames offer disenchant). START_LOOT_ROLL
  adds a row, CANCEL_LOOT_ROLL / CANCEL_ALL_LOOT_ROLLS remove it, a click is `RollOnLoot(id, 0|1|2|4)`;
  `GetActiveLootRollIDs` refills after a /reload. Blizzard's `GroupLootFrame1-4` are **faded, never
  hidden** (alpha 0 post-hook, mouse off down the tree): they reach the event through UIParent /
  the event router and keep opening and closing themselves - a hidden one would be handed the next
  roll by Blizzard's container. The bind-on-pickup confirmation stays Blizzard's (CONFIRM_LOOT_ROLL).
  Laid out like FFXIV's loot window (same day): title band, a list, the picked row marked like the
  enemy list's target, Need / Greed-or-Transmog / Pass once at the bottom for the picked roll (the
  first is picked by itself). **An uncached item never drops its roll** (owner, second dungeon of
  2026-10-27: nothing showed, Blizzard's frames being faded) - it shows "Loading item..." with only
  Pass, and Draw re-asks every 0.3 s; a roll leaves only by event or a plain time left of 0.
  Movable "Loot rolls", samples while unlocked; `/deck rolls`.
- **Rank marks** (`DeckUI/rankmark.lua`, `DeckUIDB.rankMarks`, Overview, **on**; tested in game
  (Mists) 2026-10-27, retail not yet; owner's wish 2026-10-27). A diamond before enemy names: elite gold, rare silver + star, rare
  elite gold + star, boss red + crown (textures `DeckUI/textures/rank_*.tga`, make-status-masks.py).
  `D.UnitRank(unit)`: `UnitIsBossMob` (retail), `UnitClassification` (worldboss = boss; elite at level
  -1 = boss, Mists' dungeon bosses); any secret answer = no mark. `D.RankMark(parent, size)` makes one
  (`:SetRank(rank)`); drawn on the FFXIV nameplates, the enemy list and the FF/XIV target and focus
  (oUF element `DeckRank` in ffstyle.lua); `D.OnRankMarks(fn)` refreshes them when the box is ticked.
- **The interact target's name** (`DeckUI/softtarget.lua`, `DeckUIDB.softTargetName` /
  `softTargetCast`, Overview page, off by default; not yet tested in game; replaces Plumber's
  "Nameplate: Soft Target", 2026-10-08). On PLAYER_SOFT_INTERACT_CHANGED (30 ms later, the plate
  settles) a frame of ours on UIParent is anchored below the icon of
  `C_NamePlate.GetNamePlateForUnit("softinteract").UnitFrame.SoftTargetFrame` - game objects only.
  **Nothing on the nameplate is changed** (Plumber parents into it and resizes it). Gold/grey
  from the cursor art `SetUnitCursorTexture` puts on a hidden probe texture ("unable" = out of
  reach). The cast ring is a Cooldown fed `UnitCastingDuration`/`UnitChannelDuration` duration
  objects. NAME_PLATE_UNIT_REMOVED of our plate hides it (plates are recycled). Needs the
  interact key and CVar SoftTargetIconGameObject 1 (set on enabling); `/deck softtarget`.
- **Target arrow** (`DeckUI/targetarrow.lua`, `DeckUIDB.targetArrow`, Overview page, off, live;
  tested in game 2026-10-09; owner's FFXIV screenshot the same day). FFXIV's arrowhead over the
  target: a frame of ours on UIParent anchored BOTTOM to TOP of
  `C_NamePlate.GetNamePlateForUnit("target")` - nothing on the plate changes; no plate, no
  arrow. Texture `DeckUI/textures/target_arrow.tga` (make-status-masks.py), a black larger copy
  as outline, an additive gradient as shine, a Translation animation bobbing it. Red when
  `UnitCanAttack`, green when `UnitIsFriend`, gold when either is secret. Updated 30 ms after
  PLAYER_TARGET_CHANGED / NAME_PLATE_UNIT_ADDED/REMOVED / UNIT_FACTION; `/deck targetarrow`.
- **Enemy nameplates, FFXIV style** (`DeckUI/nameplates.lua`, `DeckUIDB.xivPlates`, Overview,
  off, live; tested in game 2026-10-09; owner's FFXIV screenshot the same day). On
  NAME_PLATE_UNIT_ADDED a pooled frame of ours on UIParent is anchored to the plate's CENTER:
  level ("??" for -1), raid marker, name, a thin red bar (tapped grey) - all values straight into
  SetText / StatusBar. Only for units we may attack (a secret answer counts as yes). Blizzard's
  `plate.UnitFrame` is **faded, not hidden or re-parented**: alpha 0 held by a per-frame SetAlpha
  post-hook (hooked once, kept in our own table), alpha 1 again on NAME_PLATE_UNIT_REMOVED and
  when switched off - the plate still takes clicks and the engine still places it. Plates
  GetNamePlateForUnit does not hand out keep Blizzard's look. `/deck plates`.
  **Spacing** (`DeckUIDB.plateSpace`, on; owner 2026-10-28, plates sat on each other in a pack; not
  yet tested): with our plates on, the CVars `nameplateMotion` = 1 (stacking) and `nameplateOverlapV`
  = 1.8 are set, the player's own values kept in `DeckUIDB.plateCVars` and put back when either
  option goes off. **That was not enough** (owner 2026-10-29, still on top of each other - the engine
  stacks by the plate's own size): the option also sets `C_NamePlate.SetNamePlateSize` to ours plus a
  margin (136 x 24, out of combat, the player's size kept as `plateCVars.size`), re-applied after every
  call of Blizzard's driver (post-hook on that function). **Never read a plate's position**: plates are
  restricted regions, `GetCenter` fails ("Can't measure restricted regions", taint - a first fix that
  laid out our frames itself threw it 2800 times in Mists, 2026-10-29). Not yet tested in game.
  `/deck plates` prints the CVars and the plate size.
- **Talking head as a subtitle** (`DeckUI/talkinghead.lua`, `DeckUIDB.talkingHead` /
  `talkingHeadInstances`, Overview page, off by default; not yet tested in game; replaces
  Plumber's "Talking Head", 2026-10-08). Blizzard's `TalkingHeadFrame` only loses
  TALKINGHEAD_REQUESTED (`UnregisterEvent`, re-registered when off; the frame comes with
  Blizzard_TalkingHeadUI, hence `EventUtil.ContinueOnAddOnLoaded`). We read
  `C_TalkingHead.GetCurrentLineInfo`, play the voice with `PlaySound(vo, "Talking Head")` as
  Blizzard's frame did, and show name and text on a dark band (strata MEDIUM, under the world
  map), movable "Talking head" (the Overview page's Move). Name/text may be secret: SetText only.
- **Server info, gold, bag overview** (`DeckUI/infobars.lua`, `DeckUIDB.infoServer` / `infoGold` /
  `infoBags`, Overview page, all off by default, undone by unticking - hidden, events and ticker
  stopped; tested in game 2026-10-09; owner's FFXIV screenshots the same day). Realm, mail letter,
  latency and local time (1 s ticker only while shown), plus FPS, "CPU" and memory (owner's
  wish the same day): the game has no machine CPU, so CPU is the addons' share of the frame
  from `C_AddOnProfiler` (Overall / Application metric, RecentAverageTime; "CPU -" without
  it), memory is `collectgarbage("count")`; the tooltip lists the top five addons of each
  (`UpdateAddOnMemoryUsage` only there); each value has its own switch (`DeckUIDB.infoParts`,
  `D.INFO_PARTS`, on/off buttons under the checkbox, all on by default); gold only with a coin; one block of dots
  per bag (0-5, reagent bag tinted), free count above. The bag overview's click is a
  `SecureActionButtonTemplate` of type "click" on `MainMenuBarBackpackButton` - our Lua never
  calls ToggleAllBags (bank taint, see Bags) - so it shows/hides and resizes only out of combat.
  It is registered for AnyUp *and* AnyDown: with AnyUp alone a click did nothing (tested).
  `DeckUIDB.hideBagBar` (off; tested in game 2026-10-09) parks Blizzard's `BagsBar` (Edit Mode system)
  under a hidden parent and gives it its old parent back when unticked; the overview's click
  still reaches the parked backpack button.
  Movable "Server info", "Gold", "Bag overview".
- **Quest book in Mists** (`DeckUI/questbook.lua`): its tooltip scanner for the names of quests never
  seen in a log (`SetHyperlink("quest:id")` on a hidden GameTooltip, five a second) is **off unless
  `DeckUIDB.questBookScan`** (Windows page, Mists only; 2026-10-28). The Mists client crashed nine
  times on 27/28.10 (ACCESS_VIOLATION, same address) while it ran, mostly at loot; the loot window
  was guarded first and the crash stayed. Not proven - watch `_classic_\Errors`.
  While the server info shows, the minimap's mail letter is **faded** (alpha 0 held by a SetAlpha
  post-hook, mouse off; `MiniMapMailFrame` in Mists, `MinimapCluster.IndicatorFrame.MailFrame` in
  retail - shown and hidden by Blizzard, a layout child in retail) and the server info's tooltip names
  the senders (`GetLatestThreeSenders`; owner's wish 2026-10-28, not yet tested in game).
- **Main menu as FFXIV's round buttons** (`DeckUI/mainmenu.lua`, `DeckUIDB.mainMenu`, off,
  undone by unticking; tested in game 2026-10-09, then made 24 px with 1 px gaps). A row of
  round buttons (disc, gold ring, Blizzard's `UI-HUD-MicroMenu-<textureName>-Up` atlas masked
  round, the player's portrait on the character button), each a `SecureActionButtonTemplate`
  of type "click" on Blizzard's micro button - Blizzard's code opens the windows. Enabled
  state, the alert flash (`FlashBorder` shown -> bright ring) and which buttons exist are read
  twice a second. **Blizzard's `MicroMenu` is faded, never parked** (SetAlpha post-hook, mouse
  off down the tree, like the override bar): Blizzard reparents it into the vehicle bar and to
  full-screen frames (`MicroMenuBar_SetFullScreenFrame`), so no parent of ours would hold.
  Secure buttons: shown, hidden and laid out only out of combat. Movable "Main menu".
  **No game menu button** (removed 2026-10-26): Blizzard's opens the menu only while the mouse is over
  Blizzard's own button (`IsMouseOver` in its OnClick), so a passed-on click never worked; Esc/Start open it.
  The mouse goes off down the faded tree and **each frame's own state comes back** - switching it on for
  every child gave the button's NotificationOverlay the mouse, and it swallowed hover and clicks.
- **Auction prices** (`DeckUI/auction.lua`, `DeckUIDB.ahScan` on, "Loot and merchant" page;
  not yet tested in game; owner's wish 2026-10-08: know prices on the road). On
  AUCTION_HOUSE_SHOW, at most every 15 minutes (`ahLastScan`), `C_AuctionHouse.ReplicateItems()`
  (Blizzard's documented full scan); REPLICATE_ITEM_LIST_UPDATE is read in slices of 4000 per
  frame through `GetReplicateItemInfo(i)` (**0-based**; count 3rd, buyoutPrice 10th, itemID
  17th return), keeping the lowest buyout per piece per item ID in
  `DeckUIDB.ahPrices[GetNormalizedRealmName()] = { time, prices }`. Closing the AH drops a
  half-read scan. Gear shares one price across item levels ("from"). Readers: `D.AuctionPrice
  (itemID)` -> copper, age; `D.OnAuctionPrices(fn)` after a scan. The tooltip shows "AH" (+ the
  stack's value in bags; DeckTooltipDB.ahPrice), the bag windows a footer total
  (DeckBagsDB.ahValue) and a gold coin on slots worth >= `valuableGold` (100g). `/deck ah`.
  **AUCTION_HOUSE_SHOW no longer exists** - Midnight opens the window through the player
  interaction manager; the first version waited for it and never scanned (2026-10-08). The scan
  now starts from a HookScript on AuctionHouseFrame's OnShow (Blizzard_AuctionHouseUI is load on
  demand: `EventUtil.ContinueOnAddOnLoaded`); if no list arrives within ten seconds the status
  line offers "Scan now". **ReplicateItems needs a click**: called from OnShow it was never
  answered (owner's test 2026-10-08), the button worked (17,095 items) - so the window only
  offers the button. `ahLastScan` is written when the list arrives, so an unanswered call does
  not lock the 15 minutes. REPLICATE_ITEM_LIST_UPDATE fires tens of thousands of times (item
  data arriving); only the first after our request is read.
- **The auction house window restyled** (`DeckUI/auctionstyle.lua`, `DeckUIDB.ahStyle`, off by
  default, reload to undo; not yet tested in game; owner's wish 2026-10-08). Textures only, like
  the world map: NineSlice/Bg/portrait/parchment atlases at alpha 0, `D.FlatBox` behind the
  window and its insets, `D.FlattenButton` on panel buttons, bottom tabs' nine pieces at alpha 0
  with a flat box. Never a script or field - buy and post call protected functions.
- **Blizzard's damage meter restyled** (`DeckUI/damagemeter.lua`, `DeckUIDB.styleDamageMeter`,
  Overview page, off by default; tested in game 2026-10-08). Its numbers are secret in combat, so
  only textures and fonts change. **No hook on the bars** (2026-10-26): a post-hook on
  `DamageMeterEntryMixin.UpdateStyle` failed inside its own wrapper on 12.1.5 ("attempt to call a nil
  value", no line of ours on the stack) at every Edit Mode layout. A bar (flat, dark background, no
  shadow edge, our font at Blizzard's size) is restyled when its window's ScrollBox reports it set up
  (`OnInitializedFrame`, after Blizzard's acquire callback ran UpdateStyle) and after the window
  setters that restyle bars - post-hooks on `DamageMeterSessionWindowMixin` SetStyle, SetShowBarIcons,
  SetBarHeight, SetTextScale, SetUseClassColor, SetBackgroundAlpha (flat header and background, a thin
  edge). Mixin functions are copied into frames at creation, so the hooks go in at our ADDON_LOADED via
  `EventUtil.ContinueOnAddOnLoaded`, and existing windows are styled once directly. The
  "background opacity" setting keeps working: it sets the alpha of the textures we recolour.
- Prefer small, complete edits; the owner reads the diffs. Keep debug commands
  (`/dc overlay`, `/dc bare`, `/dc bars`, `/dc page`, `/dc trace`, `/dc assist`, `/dc quick`, `/deck device`, `/deck bars`, `/deck layout`,
  `/deck build`, `/deck errors`, `/deck softtarget`, `/deck ah`, `/deck deck|pc|auto`) – they were essential for Midnight issues.

## Hard-won Midnight facts (do not "simplify" these away)

- **Bindings go to Blizzard's native commands**, not to our buttons:
  `SetOverrideBinding(header, true, "SHIFT-PADDUP", "ACTIONBUTTON1")`. Only the native path runs
  the engine's press-and-hold repeat (single-button assistant, hold-to-cast). `SetOverrideBindingClick`
  onto LibActionButton buttons breaks that. Our cross buttons only *display*; the pushed state is
  mirrored from Blizzard's buttons via `hooksecurefunc(native, "SetButtonState")`.
- **Binding strings take the game's modifier order, ALT-CTRL-SHIFT-<key>.** LT+RT was bound as
  "SHIFT-CTRL-PADDUP", which never matched; with both triggers held the game fell back to a
  binding with one modifier, so the middle crosses lit up while a button of a half fired
  (owner's report 2026-10-08; now "CTRL-SHIFT", tested in game the same day).
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
  (`ResolveBar` in `DeckUI_Cross/input.lua`). Hide by reparenting to a hidden frame + SetParent
  hook, state in our own tables. **No visibility state driver on a Blizzard bar** (removed
  2026-10-26): bars are Edit Mode systems whose Lua `Hide` breaks the snaps of the bars docked to
  them, and `RegisterStateDriver` runs that Hide once from our code - the neighbours' snap fields
  turned tainted and Edit Mode's next layout in combat was blocked (`MultiBarLeft:SetPoint` after a
  level-up in Mists; the same code is in retail). Never call `Hide`/`SetShown` on a bar either.
  Edit Mode itself reparents its bars when it lays them out again (`AddManagedFrame`,
  `BreakFromFrameManager`) - in combat after a level-up the main bar came back: the SetParent hook
  parks it again at once out of combat, and in combat fades it (`SetAlpha(0)`, allowed there) and
  parks it on PLAYER_REGEN_ENABLED (`Repark`).
  **Mists draws the classic bar art as a frame of its own, `MainMenuBar`** (gryphons, slot frames,
  room for XP bar and bags), shown by `MainActionBar:UpdateEndCaps` whenever Edit Mode lays the
  main bar out at its default place - it came back on every level-up (2026-10-26, `/fstack`).
  It is parked with the mirrored bars; `/dc bars` prints where it hangs.
- **Hiding the bars took Blizzard's leave-vehicle button with it** (reported 2026-09-29), which
  left no way out of a vehicle on the Deck. `MainMenuBarVehicleLeaveButton` is a child of
  Action Bar 1 (`MainActionBar`) - confirmed 2026-09-29 with `/dc bars`, which prints its parent
  chain: `MainActionBar > DeckCrossBarHider > UIParent`. The fix does not depend on it: we carry our own
  `DeckCrossLeaveVehicle` (movable, "Leave vehicle"), shown whenever `CanExitVehicle()` or
  `UnitOnTaxi` and none of Blizzard's leave buttons `IsVisible()`, so it never doubles up.
  It is polled (0.2 s) on purpose: taxis have no clean start event, and Blizzard updates its
  own button on the same events, so asking about its visibility there would race it.
  `VehicleExit` / `TaxiRequestEarlyLanding` are not protected - a plain button works in combat.
- **Blizzard's override / vehicle bar (`OverrideActionBar`) is hidden with the mirrored bars**
  (2026-10-08): an encounter that takes over the bar (Avatar of Nalorakk) showed it under the
  crosses with orbs, five buttons and the micro menu, while the crosses already paged to the
  same actions. With it out of sight the ACTIONBUTTONn keys keep working (tested).
  **It is faded, never parked** (alpha 0 held by a SetAlpha post-hook, mouse off down the
  tree): in a vehicle Blizzard moves the micro menu *into* this bar and moves it back only when
  the bar's slide-out animation ends. The first version parked it under the hidden frame like
  the other bars, the animation never ran, and the micro menu was gone after leaving the
  vehicle until a reload (reported 2026-10-08). The fade is tested in game: the menu comes back.
  `BlizzardLeaveVisible` counts its leave button only at a visible alpha, so ours stands in. `/dc bars` prints where the bar hangs.
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
  tested in game 2026-10-01). The owner could not bind it: only Shift/Ctrl/Alt combine with
  another key, and a gamepad button becomes one only through `GamePadEmulate*` - Shift/Ctrl
  are LT/RT, and `SetupGamepad` used to force Alt to "none". With the option LB is Alt, and
  `ALT-PADDUP`/`ALT-PADDDOWN` go to `CAMERAZOOMIN`/`CAMERAZOOMOUT` as override bindings
  (smooth while held, one step on a tap - `Bindings_Standard.xml`). Switched off, Alt goes
  back to "none" only if it is still LB.
- **Stance row at the crosses** (`DeckUI_Cross/stance.lua`, `DeckCrossDB.stanceBar`, off by
  default; tested in game 2026-10-02). Round buttons between the two small middle crosses
  (child of `DeckCrossAnchor`, so it scales and moves with them), one per form/stance/aura;
  Blizzard's stance bar is hidden like the mirrored bars (`ns.SetBlizzardBarHidden`, which
  refuses a bar that resolves to a mirrored one). The buttons are `SecureActionButtonTemplate`
  CheckButtons with type "spell" and the form's spellID (4th return of
  `GetShapeshiftFormInfo`), set out of combat; cooldowns go into the Cooldown frame untouched.
  Keys: the player's own SHAPESHIFTBUTTON1-10 keys are override-clicked onto ours (read at
  login and on toggle - a key bound later needs a /reload). On the Deck LB becomes Alt
  (`ns.LBIsAlt`: zoom *or* stance row): LB + X/Y/B/A = stance 1-4, LB + D-pad right/left =
  next/previous. Next/previous depend on the current form, so a secure state driver on
  `[form:n]` re-binds them with `SetBindingClick` in its snippet - in combat too.
  `/dc bars` prints the row and where `StanceButton1` hangs.
- **Quick menu on RB** (`DeckUI_Cross/quickmenu.lua`, `DeckCrossDB.quickMenu`, off by default,
  Deck only; tested on the Deck 2026-10-09). Holding RB shows a cross of eight entries; the D-pad
  and face buttons open what each slot is set to - **the player chooses** since 2026-10-09
  (`DeckCrossDB.quickEntries[1..8]`, a stepping button per slot on the Cross page, choices in
  `ns.QUICK_COMMANDS`: binding commands plus DeckUI's own DECKUI_WEEK, "NONE" for empty). The keys go to **Blizzard's own binding commands** (TOGGLEWORLDMAP, OPENALLBAGS, ...),
  never to our Lua opening a window (that ran the map's opening tainted, see the Quests notes).
  RB is an override click on a hidden secure button registered for down and up; a
  `SecureHandlerWrapScript` on its OnClick binds the eight keys (`owner:SetBinding`) on the
  press and `ClearBindings` on the release - restricted code, so it works in combat. The
  picture is shown from a plain HookScript. A command the client does not know is left out and
  greyed; `/dc quick` prints the option, RB's binding and each command.
- **Action bars 3-8 in FFXIV's look** (`DeckUI_Cross/bars.lua`, `DeckCrossDB.bars[n].shown` /
  `perRow`, `barScale` per device, page "Action bars"; all off by default; not yet tested in game;
  owner's wish 2026-10-09 with his FFXIV hotbar screenshot). LibActionButton buttons, state 0 =
  the slot (Bar 3 49-60, 4 25-36, 5 37-48, 6 145-156, 7 157-168, 8 169-180), square with rounded
  corners (`textures/slot_rounded.tga` from make-status-masks.py), key top left from
  `keyBoundTarget` = the bar's MULTIACTIONBARnBUTTONi command. **Keys stay Blizzard's**: the
  player's bindings drive Blizzard's own hidden buttons (native path), ours mirror their pushed
  state like the crosses. `ns.ApplyBars` hides Blizzard's bar while ours shows - asked every time,
  since HideBar/ShowBar are idempotent - and decides Action Bar 4 for the ability menu too.
- **Ability menu on B** (`DeckUI_Cross/abilitymenu.lua`, `DeckCrossDB.abilityMenu`, off by
  default, Deck only; not yet tested in game; owner's wish 2026-10-09 - mounts without a mouse).
  A **tap** of B (PAD2, override click on a hidden secure toggle) opens a picture of Action Bar
  4's first seven slots (MultiBarRight, slots 25-31); the D-pad and Y/A/X are bound from the
  toggle's secure wrapper to seven secure buttons of type "action" on those slots, whose wrapper
  clears the bindings on the release - so the keys are only taken while the menu is open, in
  combat too. Tap, not hold: the thumb on B cannot reach Y/A/X. On the Deck Action Bar 4 is
  hidden (`ns.SetBlizzardBarHidden`), on the PC it stays a bar.
- **The Deck sets itself up** (2026-10-09; not yet tested in game). The owner had to press "Set
  up gamepad" and "Default bindings" after every switch from the PC, sometimes mid-session too:
  both write things **the game syncs between devices through its server** - the gamepad CVars
  and the saved key bindings - so the PC handed the Deck its own values. Now, on the Deck:
  `ns.EnsureGamepad` puts GamePadEnable / GamePadEmulateShift / Ctrl (and Alt while LB is in use)
  back at login, on GAME_PAD_CONNECTED/DISCONNECTED/ACTIVE_CHANGED and on CVAR_UPDATE of one of
  them (`DeckCrossDB.autoGamepad`, on); and the default pad keys (A jump, X interact, ...) are
  **override bindings of the session** on keys whose saved binding is empty (`BindPadDefaults`,
  `DeckCrossDB.padDefaults`, on) - never saved, never synced, the player's own keys untouched.
  UPDATE_BINDINGS (a sync arriving) refills them half a second later, ignoring the ones our own
  overrides cause (`lastBindApply`).
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
- **Final Fantasy style for player and target** (`DeckUI_Orbs/ffstyle.lua`,
  `DeckOrbsDB.style` = "orbs" | "ff", the "Style" button, needs a /reload; tested in game
  2026-10-01): FFXIV's parameter bar for the player (HP/MP bars with numbers, class resources as
  squares, cast below, buffs and debuffs above) and its wide target bar at the top (name,
  percent, cast, status icons, the target's target beside it). Spawned instead of the big
  orbs in the same Factory; focus stays an orb, the pet is a small bar shaped like the
  target-of-target's (`DeckFFPet`, 2026-10-08 - in a vehicle oUF puts you on the pet frame,
  and the round pink orb beside the bars looked wrong). Positions are saved under their
  own keys ("Player (FF)", "Target (FF)"), so switching back keeps the orbs' places.
  **Bosses** in this style are FFXIV's enemy list (2026-10-01, `BuildBoss`): marker, name,
  percent, thin bar, "» target" line, a red left edge while the boss targets you
  (`SetAlphaFromBoolean(UnitIsUnit(bossNtarget, "player"))` - a secret boolean for the
  engine), the cast below with oUF's `Shield` as a grey veil when not interruptible, your
  debuffs to the right. Holder "Boss frames (FF)". `/orbs boss` = test mode (five frames of
  your target, in whichever boss style is active). **The bosses' look is a choice of its own**
  since 2026-10-28 (`DeckOrbsDB.bossStyle`: auto / orbs / ff / xiv, "Boss look" on the Orbs page,
  /reload; `ns.BossLook()`, `ns.BossStyleName()`): "xiv" is `BuildBossXIV` / style `DeckXIVBoss`, the
  same rows as capsule bars without a panel; auto follows the player's style (ffxiv -> xiv). Not yet
  tested in game.
  **A third style "ffxiv"** (2026-10-09, owner's screenshot of FFXIV's parameter bar; not yet
  tested in game): no panel, capsule bars (`PillBar`: dark edge, track, gloss/shade gradients
  over the colour), HP and MP side by side with large numbers under them; the target one long
  capsule. **FFXIV's EXP bar replaces Blizzard's** (owner's wish the same day, not under the
  player): `DeckXIVExpBar`, movable "EXP bar", class/level/EXP over a thin bar (rested behind);
  Main/SecondaryStatusTrackingBarContainer parked under a hidden parent (Edit Mode systems, like
  the buff frames), so watched reputation/honour bars go with them. At the cap UnitXPMax is huge
  ("0/100,000,000" at 90), so `GetMaxLevelForPlayerExpansion` decides. At the cap the bar
  shows the **watched faction** instead (`C_Reputation.GetWatchedFactionData` ->
  `D.FactionStatus`, DeckUI/reputation.lua: paragon, renown, friendship or classic standing,
  in that order; not yet tested), "-/-" when none is watched.
  More of FFXIV's screen (2026-10-09, not yet tested): the **focus** is FFXIV's small "FOCUS"
  box in this style (`DeckXIVFocus`, "Focus (FF)"), the **target's target** sits in the
  target's line after a "»" chevron, and **`DeckOrbsDB.xivCastCenter`** (off, reload) moves your
  cast to FFXIV's progress bar in the screen's middle (`CenterCast`, movable "Cast bar": icon,
  name, capsule, time left from oUF's duration binding). The round ends are
  two masks, `textures/bar_cap_left|right.tga` (make-status-masks.py), square at each end and
  loaded with CLAMPTOWHITE so bars of any length keep round ends. Styles `DeckXIV*`; bosses keep
  the FF enemy list, positions are shared with "ff". `ns.IsFFStyle()` is what layout.lua asks,
  `ns.FFStyle(part)` names the oUF style.
- **Enemy list** (`DeckUI_Orbs/enemies.lua`, `DeckOrbsDB.enemyList`, off by default, no reload;
  tested in game 2026-10-09; owner's FFXIV screenshot 2026-10-09). FFXIV's list of the enemies
  fighting you or your group, from the nameplate units (enemy nameplates must be on), polled
  every 0.15 s while on, in the order they joined, up to eight rows: aggro square (red by
  `SetAlphaFromBoolean(UnitIsUnit(unitTarget, "player"))`), raid marker when plain, name and
  health straight into SetText / StatusBar (`ns.PillBar` from ffstyle.lua), your target lit by
  a secret boolean too (one frame: warm band, gold frame, ">" pointer - a faint band was too
  weak to see; PLAYER_TARGET_CHANGED updates at once). **Read-only on purpose**: targeting needs a secure unit button, whose
  unit cannot change in combat. The filter (`Engaged`: attackable, not dead, on the threat table
  of player/party1-4; in a raid UnitAffectingCombat) treats a **secret** answer as "show it".
  Movable "Enemy list", sample rows while unlocked; `/orbs enemies` prints each nameplate
  unit's answers (plain or secret).
- **Player, Target and Target of target pages** (DeckUI_Orbs/config.lua, keys `FramePlayer` /
  `FrameTarget` / `FrameToT`, indented under "Player and target" via `D.PAGE_PARENT`; owner's wish
  2026-10-28; not yet tested in game). They shape the **Final Fantasy frames** (the orbs keep their
  size slider): width and bar height per device **as a percentage of the style's own numbers**
  (`ns.FrameSizeDB()` keeps `playerWidth`, `playerBar`, `targetWidth`, ... at 100 by default;
  `ns.FrameSize(prefix)` turns them into pixels from `FRAME_BASE`, 260/380/140 for "ff" and
  300/420/150 for "ffxiv"; owner's wish 2026-10-28: 100% = as shipped), and shared in `ns.DEFAULTS`: `playerBuffs` / `playerDebuffs`
  (above/below/off each; one `playerAuras` for both until 2026-10-30, migrated at load),
  `playerBuffsRight`, `playerAuraShapes` (the target's FFXIV shapes, `StyleTargetAura`, else squares),
  size, buff and debuff max, `targetDebuffs` / `targetBuffs` (below/above/off each), `targetBuffsRight` (same line from the
  right edge, else a line of their own), `targetAuraSize`, `targetDebuffMax`/`BuffMax`, `totDebuffs`.
  **One layout for both bars, `AuraRows(self, width, spec)`** (ffstyle.lua, 2026-10-30): the kinds in
  `spec.order` (nearest the frame first - the player's buffs, the target's debuffs), a left-edge kind
  takes a line of its own, a right-edge kind shares the open left line and closes it.
  **Everything needs a /reload** (oUF builds a frame once): each widget reports to the reload bar
  against the value the session was built with (`Snap`/`Need`). ffstyle.lua reads them in
  `PlayerAuras` and `TargetAuraRows`, both through `AuraRows` (sets `frame.DeckBelow` / `DeckAbove` =
  the outermost aura line on each side, which debuffs.lua hangs past), and `ToTDebuffs`;
  `AuraRow(..., fromRight, max)` caps a line at `max` icons. Move: Player/Target pages move "Player"/"Player (FF)" and "Target"/"Target
  (FF)"; Defaults clear the `player*`, `target*`, `tot*` keys.
- **Your debuffs** (`DeckUI_Orbs/debuffs.lua`, `DeckOrbsDB.dotTracker`, off, live; not yet tested in
  game; owner's wish 2026-10-28 - a class's own view of its DoTs and poisons). A window of its own,
  movable "Debuffs": a column for the target, a smaller one for the focus (spec list only). Rows
  have fixed places from `LISTS[specID]` (Mists spell IDs, checked against wago `wow_classic`
  SpellName 2026-10-28); a row shows only when `IsPlayerSpell(known or id)`, so talents sort
  themselves out. Auras are matched **by name** (the client's name for the list's ID): missing =
  empty capsule with a red edge (**only while `UnitAffectingCombat("player")`** - out of combat
  only running debuffs show; owner saw "Censure --" at every mob), the last 30% gold with a tick where it starts, the player's other
  debuffs on the target below (sorted by name, up to four). A rogue's weapon poisons are `self`
  rows read from his own buffs. A secret aura name (retail in combat) turns the rows grey, never
  red. Polled every 0.1 s while on; `/orbs dots` prints spec, list, known and what the target carries.
  **While on, the spec's listed debuffs leave the target frame's debuff icons**
  (`ns.ApplyDotExclusion`: `excludeSpellIDs` of the whole list plus the poisons' target debuffs
  through `SetAuraGroupCandidateFilters` on every `ns.targetDebuffs` entry, cleared when off; both
  the AuraContainer and `auras_mists.lua` honour it live). The "other" debuffs shown below the list
  are excluded too, by the spell IDs `Scan` read - re-applied only when that set changes.
  Width per device: `ns.DeviceDB().dotScale` (percent of 240, slider 50-175 = the XIV target bar;
  `ns.ApplyDotWidth` resizes columns and rows live, the focus column keeps 170/240 of it).
  `dotNames` (on, live, `ns.ApplyDotNames`): off, the capsule takes the name's room and the
  row's tooltip names the debuff. Settings on a page of their own, "Your debuffs" (key `Debuffs`, registered in DeckUI_Orbs/config.lua),
  shown indented under "Player and target" through `D.PAGE_PARENT` (panel.lua); Move/Defaults have
  their own entries (`dot*` keys of DeckOrbsDB).
  `DeckOrbsDB.dotAttach` (off, live, `ns.ApplyDotLayout`): the window's frame and title (`c.chrome`)
  hidden, the target column anchored at `DeckFFTarget` / `DeckOrbsTarget`, the focus column at
  `DeckXIVFocus` / `DeckOrbsFocus` - only anchored, nothing on the unit frames changes. Below or
  above (`dotAbove`), clear of what hangs there: under an FF bar below its status icon line (the
  debuff container from `ns.targetDebuffs` whose parent is the frame; since 2026-10-28 the target's
  buffs are a second container of their own on the same line, from the right edge growing left -
  `TargetAuraRows`, `AuraRow(..., fromRight)` - so 8 debuffs left and 6 buffs right never slide),
  under an orb or the FF focus 22 px for name/cast text; above an FF bar 6 px, an orb 22.
- **Buff bar** (`DeckUI_Orbs/buffs.lua`, `DeckOrbsDB.buffBar`, off by default, needs a /reload;
  tested in game 2026-10-08, the combat switch included; owner's wish the same day - Blizzard's buffs grew too long in combat and
  ran into the minimap on the Deck). An oUF frame for "player" with two aura containers laid
  out like FFXIV's status bar (owner's reference screenshot), mirrored at his wish: one strip,
  buffs from the right edge growing left (up to two rows), debuffs from the left edge; narrow upright icons (`width`/`height` on the
  container) with a dark edge, the time small below (`Time` re-anchored; the engine colours it, a SetTextColor of ours is
  overwritten - green would need the container's `durationColors` curve), FFXIV's
  shapes from our own masks (`DeckUI_Orbs/textures/status_up|down.tga`, made by `make-status-masks.py`: a buff's
  top rises to a point, a debuff's bottom falls to one; icon, edge and swipe share them), and
  the dispel colour as a short strip above a debuff (`Border` re-anchored, FFXIV's Esuna mark). **Long buffs only out of combat**: the buff group's candidate filter is
  switched with `SetAuraGroupCandidateFilters` on PLAYER_REGEN_DISABLED/ENABLED between `{}`
  and `{ maxDuration = 60 }` (since 2026-10-30 the Buff bar page's `buffBarCombatMax`, 0 = none,
  `buffBarCombatHide` - in combat the buff group's frame count is 0, enchants and debuffs stay - and
  `buffBarAllOut`; **live switches** through `ns.ApplyBuffBar`: `buffBarBuffs` / `buffBarDebuffs`
  (`SetEnabled` on the block), `buffBarEnchants` (`SetItemEnchantmentEnabled`), `buffRows` 1-3 and
  `buffDebuffMax` (`SetAuraGroupMaxFrameCount`; the Mists stand-in has both setters); built in or
  not, so a reload: `buffBarTime` (the time text and its line spacing), `buffBarDispel` (the debuff
  group's `showDebuffBorder`); the page's reset keys are `buffBar*` plus the sizes and counts,
  panel.lua) - the container has no `minDuration` (Blizzard_AuraContainerUtil,
  read 2026-10-08; its filters are exclude/includeSpellIDs, dispel types, boss/role/priority
  flags, isFromPlayerOrPlayerPet, maxDuration - which drops permanent auras too). Right click
  cancels (`cancelButton`). `BuffFrame`/`DebuffFrame` are parked under a hidden parent (Edit
  Mode never re-parents them). **Temporary weapon enchants** (imbues, oils, stones; 2026-10-30,
  not yet tested in game) are item enchantment slots of the buff container, laid out first so
  they lead the buffs at the right edge: retail's `AddItemEnchantment` / `SetItemEnchantmentLayout`
  (Blizzard_AuraContainer, read 2026-10-30; the button fed like an aura's), in Mists the stand-in
  reads `GetWeaponEnchantInfo` on WEAPON_ENCHANT_CHANGED / WEAPON_SLOT_CHANGED (`ns.MistsEnchantSlots`;
  no right-click cancel there, `CancelItemTempEnchantment` is protected). Blizzard's parked frame
  had taken them with it. The container **sizes itself** to its content once a group is added
  (`OnLayoutComplete`), so a `SetSize` on it only matters before; the engine applies
  `initializeFrame` before the button's access restrictions, so `PostCreateButton` may still
  create textures on buttons made later in the session. The player orb / FF bar drops its own auras while it is on.
  Movable "Buffs"; icon height and buffs per row per device (`buffSize`, `buffPerRow`); 8 debuffs.
- **Party list** (`DeckUI_Orbs/party.lua`, `DeckOrbsDB.showParty`, off by default, needs a
  /reload; tested in game 2026-10-01): FFXIV-style rows on oUF's group header - Blizzard's
  SecureGroupHeaderTemplate, which sorts members in combat by itself, sets the click
  attributes and, with `showParty`, hides Blizzard's party frames for the session (hence the
  reload). Party only (`[group:raid] hide`); tanks, healers, damage. Range and "my target" use
  `SetAlphaFromBoolean` (secret booleans go to the engine as they are); health text is the
  `[deck:partyhp]` tag through `AbbreviateNumbers`. Its holder is movable per device; the
  secure header is only scaled out of combat (`ns.OutOfCombat`). Stacked or side by side is
  per device (`partyAcross`): the header's `point`/`xOffset`/`yOffset` attributes, whose
  change runs Blizzard's SecureGroupHeader_Update (it re-anchors the members itself); auras
  move from beside each row to below it.
  Test mode ("Test" beside the heading, `/orbs test`, session only): five oUF frames for
  "player" in the party style, spawned on first use - secure like the real rows, so they
  switch only out of combat - while the header's visibility is set to "hide".
  **This oUF keeps a frame's unit in `self.__unit`, not `self.unit`** (events.lua) - custom
  elements read `__unit`; with `self.unit` the class icon and the target edge never ran and
  the icon showed the whole sheet of class circles (2026-09-30). The same oUF as the orbs -
  a separate module would need its own copy.
- **Raid frames** (`DeckUI_Orbs/raid.lua`, `DeckOrbsDB.showRaid`, off by default, needs a
  /reload; first version tested in a real raid 2026-10-01, reworked 2026-10-02 - not yet
  tested): a compact grid, one column (or row) per raid group - **eight headers with
  `groupFilter` "1".."8"**, because one header sorted by group fills its columns five at a
  time and a short group would pull the next one in. Sorted by role or class, header 1 takes
  the whole raid (`groupBy`, `maxColumns` 8) and the other seven are hidden. Tiles: name,
  role icon for tanks and healers only, optional health text, `[deck:raidstatus]`
  (Dead/Ghost/Offline), debuffs bottom left, own buffs bottom right, mana for healers (the
  role element's PostUpdate shows the bar). **Shaped like the FF player's parameter bar**
  (owner's wish the same day, after a first "dark" version): dark panel, name in class colour
  on top, debuffs top right, a thin health bar (FF green = oUF's `colorHealth`, or class
  colour) with mana under it for healers, health text and own buffs at the bottom.
  **The dispel frame** is a third aura container over the whole tile: one button the tile's
  size, filter `HARMFUL|` + `AuraUtil.AuraFilters.RaidPlayerDispellable`, icon at alpha 0,
  border coloured by the engine (`AddDispelTypeTexture`) - no dispel type passes through our
  code. **Aggro** is a red edge from `UnitThreatSituation` >= 2, shown only while the value is
  plain. Blizzard's `CompactRaidFrameManager.container` is silenced (`UnregisterAllEvents`
  down the tree) and parked under a hidden frame out of combat - the manager itself
  (markers, ready check) stays. Per device: size, width, height, columns or rows
  (`raidScale`, `raidW`, `raidH`, `raidRows`); the rest is shared (`raid*` in
  `ns.DEFAULTS`). Aura counts and the dispel-only filter need a /reload, everything else
  applies live (`ns.ApplyRaidLayout` out of combat, `ns.ApplyRaidLook` any time). Test mode
  ("Test", `/orbs raid`): forty "player" frames. Settings in their own **Raid** tab
  (DeckUI_Orbs/config.lua); the party list keeps the **Group** tab.

## Bags module (bag window tested in game 2026-09-29, bank 2026-10-08)

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
  are shown - so `bank.lua` parks `BankFrame` under a hidden parent (it stays a UI panel:
  stripping its `UIPanelLayout-*` attributes tainted every bank visit, like the world map;
  so the invisible frame holds the left panel slot while at the bank) and writes
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
- **Auction filter** (auctioneer button, both windows, session only, combinable with the
  others): dims what `C_AuctionHouse.IsSellItemValid(location, false)` refuses - Blizzard's
  own test from ContainerFrame.lua. Tested in game 2026-10-08.
- **Tracked items** (`items.lua`, `DeckBagsDB.trackedItems`, account-wide list, up to six;
  tested in game 2026-10-08): a row above the bag window's footer, item counts like currencies.
  Built instead of fitting Plumber's Backpack Item Tracker, which hangs off Blizzard's parked
  bag frames. Items are added by dropping them on the row (`GetCursorInfo`, then
  `ClearCursor` puts the item back) - the item buttons keep Blizzard's click handling.
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
- **The "find a group" eye** (reported missing 2026-09-30; tested in game 2026-10-08) is
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
- **No click opens a Blizzard window** (2026-10-01): `QuestMapFrame_OpenToQuestDetails`,
  `OpenWorldMap` and `ContentTrackingUtil.OpenMapToTrackable` from our click handlers ran the
  map's whole opening tainted, so its pins were set up tainted and hovering a widget pin failed
  on secret values ("execution tainted by 'DeckUI_Quests'"). Left click super-tracks quests,
  world quests and collections instead (owner's choice); the map opened with M stays clean.
  The same went for achievements, professions (`ProfessionsFrame_LoadUI`, `OpenRecipe`), the
  Traveler's Log and endeavors: those rows only stop tracking (shift) and have a menu.
- **Delves and the hunt** (2026-10-01, replacing Plumber's; tested in game 2026-10-01):
  `delves.lua` takes a single delve power by itself (`DeckQuestsDB.autoDelvePower`, off by
  default; `C_PlayerChoice.SendPlayerChoiceResponse` + `OnUIClosed`, Blizzard's window never
  touched, only when `C_PartyInfo.IsPartyWalkIn()`, exactly one option with one button) and
  shows a Delver's Journey bar of its own on renown gains (`journeyBar`, on; season faction from
  `C_DelvesUI.GetDelvesFactionForSeason`, movable, `/quests journey` previews it). The Nemesis
  count is a line in `DelveEntry` from currencies 3103/3104 (left/total) - no spell ID needed.
  The active hunt (`C_QuestLog.GetActivePreyQuest`) heads the Quests section as "Hunt: ...";
  its left click super-tracks the target.
- **Hunt table stars** (`hunt.lua`, `huntMarks`, on; tested in game 2026-10-01): offers whose
  target an achievement still misses get a star of ours, a child frame of the pin kept in our
  own table - nothing written onto Blizzard's pins (Plumber writes its icons there). No quest
  table either: the open criteria of achievements 42701/42702/42703 (+ 63451/63452 for 12.1's
  new targets) are matched against the offer title, apostrophes stripped, both in the client's
  language. An offer does not say its difficulty, so the star names the lists still missing
  the target (N/H/NM). Hook: `hooksecurefunc` on the quest-offer provider's `RefreshAllData`
  in `CovenantMissionFrame.MapTab.dataProviders`. `/quests hunts` prints what it matched.
- **Scenario guide** (`guide.lua`, `DeckQuestsDB.scenarioGuide`, off, live; tested in game
  2026-10-09; owner's FFXIV screenshot 2026-10-09): a banner top left with the story. Campaigns from
  `C_CampaignInfo.GetAvailableCampaigns`, state InProgress/Stalled, **only the current
  expansion's** (`GetQuestExpansion` of a quest in the log, a chapter's rewardQuestID or the
  next quest, against `GetServerExpansionLevel`) - the first version showed an old campaign once
  Midnight's was done (owner, 2026-10-09); then "Story complete". Among them the one with a
  quest in the log (`C_QuestLog.GetInfo(i).campaignID`), else the newest. A right click
  (`MenuUtil.CreateContextMenu`) picks any open campaign by hand (`DeckQuestsDB.guideCampaign`,
  dropped once it is no longer open) or goes back to automatic. A
  **stalled** campaign's next step is `C_CampaignInfo.GetFailureReason(id)` = { text, questID,
  mapID } - what Blizzard's quest log campaign header shows (WarCampaignTemplates.lua, read
  2026-10-09). Second line: "Chapter n/m: name" or that text. Click super-tracks a quest in the
  log, else sets a user waypoint at `C_QuestLine.GetQuestLineInfo(questID, mapID)` x/y - never
  `OpenWorldMap`, which Blizzard's banner calls (taint). Movable "Scenario guide"; `/quests guide`.
- Blizzard shows no +2/+3 chest times; ours use the keystone rule (80% / 60% of the limit).
- The tracker grows from its top edge (`D.PinTopLeft`); `/quests reset` brings it back.
- **FFXIV's task list** (`DeckQuestsDB.xivLayout`, off, live; tested in game 2026-10-09; owner's
  wish 2026-10-09): `Draw` reads the flag into `xiv` and lays out the same entries differently -
  backdrop at alpha 0, title right with the fold button left of it, headings, titles, lines and
  bars right-aligned to the tracker's right edge (indent counted from the right), objectives
  light blue with ChatFrameExpandArrow after them, ReadyCheck-Ready after done ones. Quest item
  buttons go left of the title's text (`drawn.head`) instead of left of the tracker.
- `/quests debug` says whether Blizzard's tracker is gone, how many widget containers have
  widgets, and the secure button state.

## Map module (tested in game 2026-10-08)

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
  **Round, FFXIV style** (`DeckMapDB.round`, off, live through `ns.ApplyShape`; tested in game
  2026-10-09; owner's wish 2026-10-09): mask `TempPortraitAlphaMask`, our frame's backdrop at
  alpha 0, a ring of our own (three D.DISC layers: gold line, dark band `RING` = 14 px, gold
  line) with N/E/S/W on the band, zone above and clock/coordinates below the holder,
  `GetMinimapShape()` answers "ROUND". With the CVar `rotateMinimap` on the letters turn: north
  sits `GetPlayerFacing()` radians clockwise from the top. DeckUI's minimap button then
  circles at the map's radius + 22.
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
- **The world map is movable** through a post-hook on `UpdateUIPanelPositions` that puts it
  back at our place (`D.ApplyPosition`) after every panel update; it stays a panel, so other
  left panels still make room for its slot. Dragged by a 24-px strip above the breadcrumbs
  (a drag on the map pans it). **Never set `UIPanelLayout-*` attributes on it** (the first
  version did): `ShowUIPanel` reads them on every opening, an attribute written by addon code
  is tainted, so the opening ran tainted, the map pins were set up tainted, and a widget
  tooltip from such a pin created GameTooltip's shared `widgetContainer` tainted - after that
  every widget tooltip failed on a secret width in `Blizzard_UIWidgetTemplateTextWithState`
  (2026-10-01, hovering a rare on the map).
- **The quest log beside it** (QuestMapFrame) is restyled the same way: parchment backgrounds,
  `questlog-frame` borders and the side tabs' `common-sidetab` art at alpha 0 or replaced by
  flat colour, one dark panel behind the content. Quest lines, headers and rewards stay.
- Coordinates and fading on the world map are Blizzard's own CVars (`worldMapShowPlayerCoords`,
  `worldMapShowCursorCoords`, `mapFade` - the last has no checkbox in the game's options),
  driven through `ns.cvars`, a table proxy so `D.Checkbox` can write CVars.
- `Enum.AddOnRestrictionType.Map` exists ("a map that applies addon restrictions"), but
  nothing says which maps or APIs; minimap coordinates are simply blank when the position
  API returns nothing. `/deckmap debug` prints whether the restriction is active.

## Tooltip module (tested in game 2026-10-08)

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
  NineSlice to alpha 0 - Blizzard only Shows/Hides it - and colours our own frame one level
  below the tooltip. The edge takes quality/class colour for one showing.
- **No `BackdropTemplate` on anything sized by a tooltip** (our fill, the health bar edge):
  a tooltip showing a secret value has a secret width, and BackdropTemplate's OnSizeChanged
  does arithmetic on it in Lua - *"attempt to perform arithmetic on local 'width' (a secret
  number value, while execution tainted by 'DeckUI_Tooltip')"* in Backdrop.lua (2026-09-30,
  shipped in 1.3.0, fixed in 1.3.1). `FlatBox` is a fill plus four one-pixel textures that
  are only anchored; the engine lays them out, where secrets are fine.
- Place: a post-hook on `GameTooltip_SetDefaultAnchor` re-anchors only those tooltips to
  `DeckTooltipAnchor` (movable, per device); owned tooltips keep their place.
- Lines: `TooltipDataProcessor.AddTooltipPostCall` for Unit/Item/Spell - Blizzard runs them
  before its own Show and again on `TOOLTIP_DATA_UPDATE`. Unit name, class and GUID are
  secret for units that are not player-controlled: checked with `issecretvalue`, and a
  target name that may be secret goes into `AddDoubleLine` whole, never concatenated.
- Health bar: Blizzard's (it watches the unit securely), restyled with textures only.
- Inspect for other players' spec/item level: one at a time, 1.5 s apart, 5 s timeout, not
  in combat nor while Blizzard's inspect window is open; results cached by GUID for 5 min.
- **Extras** (`extras.lua`, replacing Plumber's tooltip modules; tested in game 2026-10-08): the
  quest an item in the bags starts (bag and slot read from `tooltip.processingInfo`, read
  only), unspent profession knowledge on the profession spell (trait currency per spec tree,
  counted once per currency, cached until a skill/trait event), and the Coffer Key count on a
  delve's rare chest (object named like item 228942, currency 3028 - TWW numbers Plumber still
  uses; if Midnight changed them the line just never shows). Lines only - Plumber's `Show()`,
  rebuilds and line rewrites were not copied. Plumber's delve cache lines are stale TWW data.
  **Reputation and ensembles** (2026-10-09, not yet tested; `reputation` / `ensembles`, on):
  an item's use spell (`C_Item.GetItemSpell`) is looked up in `repdata.lua` - **generated**
  from wago.tools' SpellEffect rows with Effect 103 (SpellID -> EffectMiscValue_0 = faction),
  479 spells; refresh it at a patch the way its header says - and the standing comes from
  `D.FactionStatus`; currencies ask `C_CurrencyInfo.GetFactionGrantedByCurrency`. Ensembles:
  `C_Item.GetItemLearnTransmogSet` -> `C_Transmog.GetAllSetAppearancesByID` ->
  `GetSourceInfo().isCollected`, counted per set and cached until a collection event.
- `/decktip debug` prints the styled count, anchor, scale, NineSlice alpha and inspect state.

## Nav module (tested in game 2026-10-01)

Compass bar, navigation target panel, quest stepping and /way. Built from Blizzard's 12.1.0
source (read 2026-10-01).
- **The target is always Blizzard's super-tracked one** (`C_SuperTrack`): we only read it and
  set it with `SetSuperTrackedQuestID` / `SetUserWaypoint` + `SetSuperTrackedUserWaypoint`,
  so the in-world diamond, the map and the compass agree. Its map position comes from
  `C_Navigation.GetNextWaypointForMap` first (the next route step - a portal when the target
  is in another zone), then per type (user waypoint, quest, world quest, vignette, corpse).
- Geometry is map space: positions on `C_Map.GetBestMapForUnit("player")`, yards from
  `C_Map.GetMapWorldSize`. Angles follow `GetPlayerFacing` (0 = north, counterclockwise);
  map x grows east, map y south, so the bearing is `atan2(-east, north)`. In instances
  facing and position are nil and the compass hides.
- Data is read ten times a second, turning moves the marks every frame; a separate driver
  frame runs both, since the hidden bar runs no OnUpdate.
- Distance is `C_Navigation.GetDistance()` (follows the route) with the map's straight line
  as fallback; arrival time comes from how fast the distance shrinks over three seconds.
- **Key bindings sit in the hub** (`DeckUI/Bindings.xml`, names in DeckUI/core.lua): the game
  reads Bindings.xml at startup, before a LoadOnDemand module exists. They call
  `D.NavStep`, which forwards to `D.navStep` once DeckUI_Nav is loaded.
- **Our beacon in the world** (`beacon.lua`, `DeckNavDB.beacon`, on; tested in game 2026-10-01):
  name, distance and arrival time around the target icon, anchored to the engine's projected
  point `C_Navigation.GetFrame()`; off screen it sits on Blizzard's ellipse (500/200) with an
  arrow. Blizzard's `SuperTrackedFrame` is parked under a hidden frame (`SetParent` only) -
  no OnUpdate, but its events still run, so it still clears waypoints on arrival. Distance and
  arrival time are computed once in compass.lua's driver (`ns.navState`) for panel and beacon.
- `/way` is ours unless TomTom (or another addon) has it; `/dway` always works.
- **Waypoint list and routes** (`waypoints.lua`, `DeckNavDB.waypoints` / `routeMode`; tested in
  game 2026-10-09; owner's wish 2026-10-09, after the scenario guide's click set nothing visible).
  Any number of points (max 50), kept across sessions. **One at a time is pushed into Blizzard's
  user waypoint and super-tracked** (`pushed` remembers what we set), so compass, panel, beacon
  and diamond follow it unchanged. **Adding never needs a click handler of ours on the map**: a
  Ctrl-click sets Blizzard's map pin, USER_WAYPOINT_UPDATED with a point we did not push puts it
  into the list; `/way x y name` adds too. The pin vanishing (Blizzard clears it on arrival, or a
  right click on it) or being within 10 yd counts as arrived: route mode goes to the next point
  in order and loops, otherwise the point is removed and the nearest one left follows. Pins:
  world map = frames of ours as children of `WorldMapFrame.ScrollContainer.Child`, scale
  1/canvas scale, offsets x*w*scale, placed every frame while the map is open; minimap =
  children of Minimap placed by yards (HereBeDragons' zoom table of yards across), turned with
  `rotateMinimap`, clamped to the edge (round or square). **Never a map data provider** - those
  run inside the map's refresh and would taint its pins. Other maps through
  `C_Map.GetWorldPosFromMapPos` / `GetMapPosFromWorldPos`. List window "Waypoint list"
  (`/way list`, Nav page, a click on the compass bar): click = go, right click = remove,
  double click = rename. The compass shows the list's other points as numbered blue dots
  (`ns.WaypointList` / `ns.WaypointPosOn`, up to ten); the active one is its target mark.
- `/decknav debug` prints map, position, facing, map size, the target and its angle.

## Week module (first version worked in game 2026-10-01; reworked 2026-10-02, tested 2026-10-08 - crests, knowledge and hunts included)

The week at a glance for every character (owner's wish, 2026-10-01). Reworked the next day
on the owner's verdict (layout, look and missing content): **one table, a row per
character** (vault rows as squares, keystone, prey hunts N/H/NM, delve weekly + keys,
profession knowledge, weekly quests); a click unfolds the details in two columns below
the row, the character being played starts unfolded. Right click a character: forget it
(`D.Dialog`); right click a weekly quest: hide it for all (`DeckWeekDB.hidden`).
- Read from the game: Great Vault (`C_WeeklyRewards.GetActivities`, grouped by
  `Enum.WeeklyRewardChestThresholdType`, item level of unlocked slots from
  `GetExampleRewardItemHyperlinks`), lockouts (`GetSavedInstanceInfo`, world bosses), keystone
  and runs (`C_MythicPlus`), renown of the current expansion (`C_MajorFactions`), Traveler's
  Log, the active hunt (`C_QuestLog.GetActivePreyQuest`).
- **Kept by ID in `data.lua`** (Midnight; first taken from AlterEgo, Plumber and Myu's Knowledge
  Points Tracker 2026-10-02). **Our IDs rest on the game, not on other addons** (owner's decision
  2026-10-09): `check-game-data.py` (repo root, run at every patch; `--items` adds the slow item
  lookup) compares every hand-kept ID - Week's data.lua, the Nemesis currencies, the hunt
  achievements, the delve chest - with Blizzard's client data from wago.tools (CurrencyTypes,
  Achievement, QuestV2 + QuestV2CliTask titles, ItemSparse; needs a User-Agent, else 403); all
  217 passed on 2026-10-09. Hidden tracking quests (treasures, treatises, hunts) have no name in
  any data file: `/week record [stop|list|clear]` (record.lua) diffs
  `C_QuestLog.GetAllCompletedQuestIDs` every 2 s while on and prints each newly flagged quest
  with zone, title and what data.lua calls it ("not in data.lua" when new); kept in
  `DeckWeekDB.recorded` (last 200). The data:
  crests, catalyst and spark per M+ season (`C_MythicPlus.GetCurrentSeason`: 17 = S1, 18 = S2,
  fallback 18), coffer keys/shards and other currencies, the delve weekly and Trovehunter's
  Bounty, prey quests per difficulty (4 a week each), weekly profession knowledge per base
  skill line (7th return of `GetProfessionInfo`; a "pool" is one quest a week), the important
  weekly quests. Caps come from the currency info itself (weekly or seasonal), never the table.
  The old walk over the currency list (opening collapsed headers) is gone - it found no crests.
- **Snapshots per character** in `DeckWeekDB.chars["Name-Realm"]`, written at most every two
  seconds after the relevant events and at logout; each part collected in its own pcall.
  Each keeps `resetAt`; past it the snapshot counts as stale and everything weekly shows as reset.
- **Other weekly quests are learned**: any quest with `Enum.QuestFrequency.Weekly` in a quest
  log goes into `DeckWeekDB.weeklies` (account-wide) unless `data.lua` knows it
  (`ns.KNOWN_QUESTS`); each character asks `IsQuestFlaggedCompleted` for all of them.
  `/week forget <questID>` removes one.
- Opened by a round button on screen (`DeckWeekButton`, `DeckWeekDB.showButton`, on; badge =
  unlocked vault slots this week; dragged directly with `D.MakeDraggable`, a press that became
  a drag is not a click), `/week`,
  the hub binding DECKUI_WEEK (`D.ToggleWeek` -> `D.weekToggle`) and Shift-click on the
  minimap button.

## Testing checklist (owner does this in-game)

1. `/console scriptErrors 1`, `/reload`, no error window.
2. Chat shows `DeckUI Cross: controller mode` (Deck) / `keyboard mode` (PC).
3. LT/RT + key casts and lights the button; assistant held repeats; icon follows.
4. `/deck unlock` → drag → positions stick per device.
5. Every checkbox / slider / button in all thirteen tabs works without error.
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
