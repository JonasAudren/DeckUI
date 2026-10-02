# DeckUI changelog

What users see on the CurseForge file page and in the app. `changelog.ps1`
reads the section whose heading matches the version being released, so the
heading has to be `## <version>` - the rest of the line is free, a date is
welcome. Write for players: what changed for them, not which file moved.
Without a matching section a release falls back to the commit subjects,
which is duller but never blocks a release. A pre-release reads the section
of the version it leads up to, so `v1.0.1-beta` uses `## 1.0.1`.

## 1.5.0 (2026-10-02)

- **Stance bar at the crosses** - forms, stances, auras and stealth as
  round buttons between the two small middle crosses, in place of
  Blizzard's stance bar. The active one has a gold ring, cooldowns run
  as a circle. On the Steam Deck LB + X/Y/B/A picks a stance and
  LB + D-pad left/right steps to the next or previous one, in combat too;
  on the PC your own stance keys keep working. Tick "Stance bar at the
  crosses" in the Cross tab.
- **Week overview rebuilt** - all characters in one table: Great Vault,
  keystone, prey hunts, delves, profession knowledge and weekly quests at
  a glance. Click a character for the details: vault item levels,
  lockouts, crests, currencies, renown.
  - New: prey hunts per difficulty, the weekly delve quest and
    Trovehunter's Bounty, coffer keys, the week's profession knowledge
    (treatise, weekly quest, treasures and gathering) and the upgrade
    crests of the current season - those were missing before.
  - Midnight's important weekly quests are listed from the start; other
    weekly quests are still learned as they appear.
  - Right click a weekly quest to hide it, right click a character to
    forget it.
  - The round week button on screen can now be dragged anywhere directly,
    without unlocking the frames first.
- **Raid frames rebuilt** - each member is now a small parameter bar like
  the Final Fantasy player frame: name in class colour, a thin health bar
  in FF green (or class colour), debuffs top right, your heals over time
  and shields bottom right, mana for healers. A tile is framed in the
  debuff's colour when you can dispel it, and edged red while the member
  has aggro.
  - A **Raid** tab of its own: size, width and height per device, groups
    as columns or rows, sorted by group, role or class, health text,
    how many debuffs and buffs, background and out-of-range opacity, and
    switches for the dispel frame, aggro edge, mana bars, role icons and
    "only debuffs you can dispel".
- **New settings window** - `/deck` now opens a wider window with the
  pages listed in a sidebar, grouped by theme (units, actions, world,
  inventory, info), instead of two rows of tiny tabs. Pages scroll, and a
  bar at the bottom shows when a change waits for a reload, with a button
  that does it.
- **Navigation:** the arrival time now says its unit ("45 s", "3 min")
  and shows up sooner once you head for the target.

## 1.4.0 (2026-10-01)

- **New module: DeckUI Week** - your week at a glance, for every
  character: Great Vault progress, locked raids and dungeons, keystone and
  runs, weekly quests, renown and every currency with a weekly or seasonal
  cap, in one window with tabs. Characters you are not playing show what
  they had when last seen, marked once the weekly reset has passed. Weekly
  quests are learned as they appear in a quest log. Open it with `/week`,
  the new round button on screen (its number counts your unlocked vault
  slots), a key binding or Shift-click on the minimap button. Switched off
  until you tick "Week" in `/deck` -> General.
- **New module: DeckUI Nav** - finding your way: a compass bar at the top
  (cardinal points, your target, party members, rares and treasures), the
  target's name with an arrow, distance and arrival time, and DeckUI's own
  beacon in the world in place of Blizzard's diamond. Key bindings step
  through your tracked quests, nearest first; `/way 45.2 67.8` sets a
  waypoint. Switched off until you tick "Nav".
- **Final Fantasy style, now for the whole group:**
  - Player and target as FFXIV's parameter bar and wide target bar - pick
    "Style: Final Fantasy" in the Orbs tab.
  - Bosses as FFXIV's enemy list: health, whom the boss is after, a red
    edge while it is you, its cast (grey when it cannot be interrupted)
    and your debuffs. `/orbs boss` shows them on your target to place them.
  - A party list in FFXIV's look, stacked or side by side.
  - **Raid frames:** a compact grid in class colours, one column per
    group, with debuffs, your heals over time and mana for healers.
  - Party and raid have their own **Group** tab, each with a test mode.
- **Loot:** fast auto loot, and an optional loot window in DeckUI's look
  with "Take all" (also a key binding). With auto loot a short list shows
  what you picked up.
- **At the merchant:** sell junk and repair automatically (guild funds
  first), both optional in the General tab.
- **Quests tracker:**
  - Clicking a quest now makes it your navigation target instead of
    opening the map.
  - Delves: a single power on offer is taken for you (optional), the
    Nemesis count shows in the delve header, and a bar shows your
    Delver's Journey gains.
  - The active hunt is listed at the top; on the hunt table a star marks
    targets an achievement still needs.
- **Bags:** track any item's count like a currency - drop it on the row
  above the gold. The auction-house filter dims what cannot be sold there,
  and the free-slot counts now say which kind of bag they count.
- **Tooltip:** items that start a quest show the quest, profession spells
  your unspent knowledge, and a delve's rare chest your keys.
- **Blizzard's damage meter** can wear DeckUI's look (General tab).
- **Fixes:** several "secret value" errors on the world map and in
  tooltips are gone. Opening the map, the bank and Blizzard's dialogs no
  longer happens from DeckUI's code, which left them broken for the rest
  of the session. A new `/deck errors` window (also in the General tab)
  collects any Lua error to copy into a report.

## 1.3.1

- **Tooltip:** fixed an error about a "secret number value" in
  Backdrop.lua that could appear when hovering NPCs or enemies with the
  Tooltip module switched on. The tooltip looks the same as before.

## 1.3.0

- **New module: DeckUI Tooltip.** The mouse-over window in DeckUI's look:
  dark, with a thin edge that takes the item's quality colour or a
  player's class colour, and a slim health bar. Switched off until you
  tick "Tooltip" in `/deck` -> General.
  - It appears at a place of its own that `/deck unlock` moves, separately
    for the Steam Deck and the PC. Tooltips of buttons and frames stay
    beside them. Its size is set per device too.
  - **Players:** name in class colour, their spec and item level - other
    players' a moment later, since the game has to look at their gear.
  - **Whom a unit is targeting**, and a red ">> You <<" when it is you.
  - Hold **Shift** for item, spell and NPC IDs.
- **Steam Deck and PC, each with its own setup.** A new **Devices** tab
  holds everything that differs between the two, and three new switches
  keep what the game otherwise shares between every computer you log in
  from:
  - **Key bindings** stay on the device you set them on.
  - **Action bar layouts:** lay your bars out differently on the Deck and
    on the PC - each device puts its own layout back when you log in or
    change spec. Per character and spec.
  - **Edit Mode layout:** make one layout per device in Edit Mode, and
    each device switches to its own; it asks for a quick reload when it
    does.
  - Tick them on each device. Whatever is set up when you tick a box
    becomes that device's, later changes are remembered.
- **Cross:** zoom the camera on the Deck with **LB + D-pad up/down** -
  hold for a smooth zoom, tap for a step. A new option in the Cross tab;
  LB then works as a modifier and no longer as a button of its own.
- **Quests:**
  - Fixed an error about a "secret number value" that could appear when
    hovering points on the world map while the Quests module was on.
    The tracker no longer borrows Blizzard's widget frames; zone bars,
    scenario widgets and the delve header are drawn by DeckUI itself.
  - The **find a group** button (the eye) is back beside quests, world
    quests and scenarios.
  - The delve header shows whether the **treasure** is earned.
  - World quest time left now counts down on its own; scrolling keeps the
    quest item buttons beside their quests.
  - Much less work in the background, especially in Mythic+: only the
    parts that changed are rebuilt.
- **Map:** the world map's buttons match DeckUI's look, and the world map
  can grow up to 140% for the Deck's screen.
- **Bags:** lighter while casting with the bags open; the Bags tab points
  out the column slider when the window is too tall for the screen.
- **Orbs:** size, focus and boss settings can be changed in combat - they
  apply when combat ends instead of causing an error.
- Plugging in or removing a gamepad mid-session no longer switches the
  device; `/deck device` says when a reload would change it.

## 1.2.0

- **New module: DeckUI Quests.** A compact tracker of its own that takes
  over everything Blizzard's "All Objectives" window showed. Like Bags it
  starts switched off: tick "Quests" in `/deck` -> General.
  - **Quests and campaign** with their objectives and progress bars,
    finished steps in green, the quest you are heading for in gold.
    Left-click opens the quest log, shift-click stops tracking, right-click
    brings the usual menu: focus, map, share, abandon.
  - **Quest items** get a button beside their quest that works in combat
    too.
  - **World quests and bonus objectives** of the zone you are in, plus the
    world quests you track, with time left when one is about to expire.
  - **Dungeons, delves and scenarios:** stages and objectives, the delve
    header with tier and lives, bonus steps, and a button for scenario
    spells. In a **Mythic+** key: the timer, how long you have left for +3
    and +2, deaths with the time they cost, and the affixes.
  - **Everything else** you can track: achievements, the Traveler's Log,
    neighbourhood endeavors, collections (with a hint where to find them)
    and recipes, counting the reagents in your bags, bank and warband bank.
    Zone widgets such as capture bars show up too.
  - Fold a section by clicking its heading, or the whole tracker with the
    "-" in its corner. Taller than your height limit, it scrolls. Drag it
    by its frame; width, size, text size and height limit are set
    separately for the Steam Deck and the PC in the new Quests tab.
    `/quests reset` brings it back if it ever ends up out of sight.
- **New module: DeckUI Map.** A tidier minimap and world map, also
  switched off until you tick "Map" in `/deck` -> General.
  - **Minimap:** square, in a plain DeckUI frame, with the zone name on
    top and the clock and your coordinates along the bottom. Tracking,
    calendar, the addon button menu, zoom and other addons' minimap
    buttons only show while your mouse is over the map; mail, crafting
    orders and the instance difficulty always stay. Drag it where you want
    it and set its size - separately for the Steam Deck and the PC.
  - **World map:** always a window, never full screen, and movable by the
    strip along its top edge. Its breadcrumbs and buttons appear under
    the mouse, it opens without the quest log (the toggle on the map still
    brings it up), and the quest log beside it now matches DeckUI's look.
    Its size is set per device too.
  - Switches for Blizzard's own world map extras: your coordinates, the
    cursor's coordinates, and fading the map while you move - that last
    one has no checkbox anywhere in the game's options.
  - `/deckmap reset` brings both maps back to their default places.
- The settings window puts its tabs into two rows now that there are
  seven, and uses a slightly smaller tab font.

## 1.1.0

- **New module: DeckUI Bags.** Your bags, your character bank and your
  warband bank, each in one window instead of a stack of small ones. It
  starts switched off, so nothing changes until you want it: tick "Bags"
  in `/deck` -> General.
  - **Bags** open wherever Blizzard's would - B, the bag bar, the mailbox,
    a merchant, the auction house - and right clicks do what they always
    did: use, sell, post, deposit, even a potion in combat.
  - **Categories:** items sort themselves into New, Equipment, Consumables,
    Trade Goods, Quest, Other and Junk, best quality first. All your free
    slots fold into one empty slot with a number on it. Prefer every slot
    where it really is? One button switches to a plain grid.
  - **Bank:** opens at the banker next to your bags. Switch between your
    character bank and the warband bank, one tab at a time, deposit
    everything with one click, buy new tabs, and move gold in and out of
    the warband bank. A locked warband bank tells you why.
  - **Find things:** search, sorting, gold, the currencies you track,
    item level on gear and a coin on grey items even when no merchant is
    open.
  - **Clear out old stuff:** the pocket-watch button dims everything from
    the current expansion, so only what is left over from earlier ones
    stays lit.
  - Drag a window by its frame to move it. Columns and size are set
    separately for the Steam Deck and the PC in the new Bags tab.
- The settings window is a little taller, to fit the fourth module switch.

## 1.0.3

- **You can leave vehicles again.** Hiding Blizzard's action bars took the
  leave-vehicle button with them, so once you were in a vehicle there was no
  way out on the Steam Deck. DeckUI now brings its own. It appears whenever you
  can get out, and on a flight path it asks for an early landing. It works in
  combat, never shows up next to Blizzard's own button, and can be moved with
  `/deck unlock` like every other frame.
- New, optional: an **assistant indicator** that shows the spell the
  single-button assistant wants to cast next. A green ring means you can
  cast it right now; grey with a cooldown swirl means it is not ready yet
  and waiting is the right call. It answers the question a quiet button
  cannot: is there really nothing to press, or am I missing something?
  Switch it on in the Cross settings under "Assistant indicator" and move
  it with `/deck unlock`. The assistant has to sit on one of your action
  bars for it to work.

## 1.0.2

- The settings window reads properly now: percentages sit below their
  sliders instead of on top of the headings, and the explanations wrap
  inside the window instead of running off the edge. Thanks to the person
  on reddit who pointed both out.
- Pressing a button is visible again. A short tap used to flash by too
  quickly to notice; the button now stays lit long enough to see.
- A spell the game refuses - no target, out of range, not enough resources -
  flashes the button red. That tells "nothing happened" apart from "my press
  never arrived", which used to look the same.
- **The single-button assistant works with the crosses now.** Its button
  shows the spell it is about to cast, and its ring turns red while you have
  no target, which is the usual reason the assistant seems to stall. This
  never ran in any earlier version: DeckUI asked the game a question it
  could not answer, and quietly got "no" every time.

## 1.0.1

- **The hotbar no longer fades when you stand still.** It used to dim itself
  after a few quiet seconds; now it stays where you put it. If you liked the
  fading, switch "Dim the crosses when idle" back on in the Cross settings -
  the opacity slider belongs to that setting and greys out while it is off.
- The assistant button now shows a **red ring while you have no target**. The
  game keeps firing the button as long as you hold the key, but every cast is
  refused when there is nothing to cast at, which looks exactly like a frozen
  addon. Now you can see it and re-target. (An addon is not allowed to pick a
  target for you, so showing the state is as far as this can go.)
- Settings, frame positions and key bindings carry over untouched.

## 1.0.0

First public beta.

- Round unit frames (orbs) for player, target, target of target, focus, pet
  and the boss frames.
- An FFXIV-style cross hotbar: LT/RT together with the D-pad and the face
  buttons on a controller, your own action bar bindings on a keyboard.
- One-click specialization switching.
- Settings are per device: frame positions and the orb and cross sizes are
  remembered separately for the Steam Deck and the PC, so the same account
  fits both screens.
- ConsolePort users: uncheck "Console Port Action Bar", which claims the
  same LT/RT combinations and wins, leaving the DeckUI crosses unlit.
  Everything else in ConsolePort works fine next to DeckUI.
