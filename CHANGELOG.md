# DeckUI changelog

What users see on the CurseForge file page and in the app. `changelog.ps1`
reads the section whose heading matches the version being released, so the
heading has to be `## <version>` - the rest of the line is free, a date is
welcome. Write for players: what changed for them, not which file moved.
Without a matching section a release falls back to the commit subjects,
which is duller but never blocks a release. A pre-release reads the section
of the version it leads up to, so `v1.0.1-beta` uses `## 1.0.1`.

## 2.0.3

Quality of life, much of it for Mists of Pandaria Classic. Every new part is
off until you switch it on.

**Both games**

- **The dungeon queue as a small window.** While you queue for a dungeon,
  raid finder or scenario: how many tanks, healers and damage dealers are
  found, the estimated wait and how long you have waited. Blizzard's eye at
  the map goes while it is on; right click the window to leave a queue.
  Drag it anywhere. Overview page.
- **Party and raid frames in Final Fantasy XIV's look**, like the XIV player
  frame: capsule bars without a box, the health number large, pink mana, a
  warm band behind the member you target. Switch "Look" on the Group or Raid
  page; the dark panels stay the default.
- **Loot rolls like Final Fantasy XIV's loot window.** Every open group roll
  in one movable list: the item in its quality colour and the time left; pick
  one and roll with Need, Greed (Transmog in retail where it applies) or Pass
  along the bottom - the first item is picked for you. What your character
  cannot pick is greyed, its tooltip says why. "Loot and merchant" page.
- **Elite, rare and boss marks.** A diamond before the name - gold for elites,
  silver with a star for rares, red with a crown for bosses - on the FFXIV
  nameplates, the enemy list and the Final Fantasy target and focus bars.
  Overview page, on by default.
- **Enemy nameplates (FFXIV style) colour the level** by how hard the enemy is
  for you - grey, green, yellow, orange, red; bosses' "??" in red.

**Mists of Pandaria Classic**

- **Character panel:** each slot shows its item level, a red E when an
  enchant is missing and a purple G for an empty socket (the belt buckle
  too); a line below sums it up. Overview page.
- **Gear per talent group:** pick an equipment set for each talent group on
  the Spec page - switching the group puts it on.
- **Mail helper:** a button beside the recipient lists your characters on
  the realm and the last people you mailed; after "Open All" a chat line
  says what it took. Loot and merchant page.
- **Restock at merchants:** keep a list of reagents, flasks and food beside
  the merchant and set how many you want - each visit buys what is missing,
  for gold only. Loot and merchant page.

## 2.0.2

A few wishes and one fix, for both games.

- **The week overview in the round main menu.** One more round button at
  the end of the row opens and closes the week overview, in combat too.
  It shows while the Week module is on.
- **The target's status icons in Final Fantasy XIV's shapes** (FF and XIV
  styles): buffs with a roof on top, debuffs with a point at the bottom,
  the dispel colour as a strip above - like the buff bar.
- **Action bars 3-8 can be see-through.** An "Opacity" slider on the
  Action bars page, from 10% to 100%.
- **Quest items in FFXIV's task list work again.** With the task list on,
  the item buttons could not be clicked and showed no tooltip; they also
  covered the quest's lines. They now sit left of the whole quest and
  take clicks.

## 2.0.1

A few fixes, all but the damage meter for both games.

- **Blizzard's game menu button works again after the round main menu.**
  Switching the round buttons off gave a small notification overlay on
  Blizzard's game menu button the mouse, and it swallowed hover and clicks.
  Blizzard's menu now gets back exactly the mouse settings it had.
- **The round main menu has no game menu button any more.** Blizzard's
  button only opens the menu while the mouse is over Blizzard's own button,
  so ours never could. Esc and Start open it.
- **"Default bindings" keeps Esc on the game menu.** It puts B on the game
  menu; if Esc ever lost it along the way, it is put back.
- **The damage meter style no longer throws an error** (Retail, patch 12.1.5:
  "attempt to call a nil value" whenever the meter was laid out). The
  look is the same.

If Esc does not open the game menu for you, your Esc key may have lost its
binding. Type `/run SetBinding("ESCAPE","TOGGLEGAMEMENU") SaveBindings(GetCurrentBindingSet())`
in chat to put it back.

## 2.0.0

**DeckUI now runs in Mists of Pandaria Classic.** One download for both
games: the same folders load in Retail and in MoP Classic (5.5.4), and each
game gets what fits it. All ten modules came along - unit frames with MoP's
class resources, the cross hotbar, bags and the old bank, the quest
tracker, the maps, the tooltip, the compass with waypoints and a week
overview made for MoP. Everything was played on the PC; the controller
parts are all there in MoP but **not yet tested on the Steam Deck** - tell
us if something does not work for you.

**Mists of Pandaria Classic**

- **Orbs and Final Fantasy bars** with MoP's resources: shadow orbs, burning
  embers, demonic fury, eclipse, chi, combo points on the target and runes
  coloured by type. Party list, raid frames, buff bar and enemy list as in
  Retail.
- **Cross hotbar** with stances and forms, vehicles, the stance row, Action
  Bars 3-8, the quick menu and the ability menu.
- **Spec bar**: one button per talent group (dual spec), click to switch.
- **Bags and bank**: one window for all bags and the old bank with its bank
  bags; no sorting, which MoP does not have.
- **Quest tracker** in place of MoP's: quests with their item buttons,
  achievements, zone widgets, scenarios and **challenge modes with the
  medal times**.
- **Minimap** square or round, the world map as a movable window.
- **Tooltip** with spec and item level of other players.
- **Compass and waypoints**: Ctrl-click the world map or `/way`; routes,
  pins on both maps, the waypoint list.
- **Week overview for MoP**: raid lockouts (Raid Finder wings included),
  valor and conquest of their weekly caps, the world bosses, your medal in
  every challenge mode, charms, seals and coins - for all your characters.
- Not in MoP, because the game has none of it: the damage meter style, the
  talking head subtitle, delves, world quests, hunts and the scenario guide,
  the beacon in the world.

**Both games**

- **Neutral creatures are yellow, not red**, on the FFXIV nameplates, in the
  enemy list and on the target arrow - red once they attack you.
- **Fast loot switches the game's auto loot on** as well; without it the
  loot window still waited for a click.
- **Hidden action bars stay hidden after a level-up in combat** - the game
  put the main bar back, and could block the right bars in combat.
- **The waypoint list** opens with a click on the navigation target below
  the compass too, and you can drag it by its title while it is open.
- Switching a module on from its own page no longer shows an error.

## 1.7.1

- **Updated for patch 12.1.5.** DeckUI now loads without "out of date" on
  the current patch. Nothing else changes - the game's interface code was
  checked against everything DeckUI uses, and none of it moved.

## 1.7.0

The Final Fantasy XIV update: much of FFXIV's screen as options to tick,
and the Steam Deck no longer needs setting up again after the PC. Apart
from the Deck's self-setup, every new part is off until you switch it on.

**Steam Deck**

The self-setup, the ability menu and the new action bars are still being
tested on the Steam Deck - tell us if something does not work for you.

- **The Steam Deck sets itself up (still being tested).** After playing on the PC you no
  longer have to press "Set up gamepad" and "Default bindings" again:
  the game shares those settings between your devices, so the PC used to
  take them away. DeckUI now puts the gamepad settings back by itself
  whenever they change, and gives the controller buttons you have not
  bound yourself their default keys for the session, without writing them
  into your key bindings. Both are on by default, on the Cross page.
- **Ability menu on B (still being tested)** - tap B and the first seven slots of Action Bar 4
  appear; the D-pad and Y, A, X use one - your mounts, toys or anything
  else you put on that bar - and B again closes it. On the Deck the bar
  itself is hidden, on the PC it stays a normal bar. Tick "Ability menu
  on B" on the Cross page.
- **Quick menu: your own choice** - each of the eight buttons can open
  what you pick on the Cross page: map, bags, quest log, character,
  talents, spellbook, professions, group finder, adventure guide,
  collections, mounts, achievements, guild, friends, calendar, the week
  overview or the game menu. Tested on the Steam Deck now.

**Final Fantasy XIV's look**

- **A third style for player and target: Final Fantasy XIV** - rounded
  glossy bars without a box, HP and MP side by side with large numbers,
  the target as one long bar with name and percent above it and its own
  target beside it after a chevron, and the focus as FFXIV's small focus
  box. Blizzard's experience bar becomes FFXIV's too: class, level and
  EXP over a thin bar - at the level cap the reputation you watch. Your
  cast can move to the middle of the screen with its icon and the time
  left. Pick it with the "Style" button on the Orbs page (reload needed).
- **Action bars (still being tested)** - Action Bars 3 to 8 can be DeckUI's own: square slots
  with rounded corners like FFXIV's hotbars, your key in the corner, one
  row, one column or anything between, size per device. Your keys keep
  working as before. Tick them on the new "Action bars" page.
- **Enemy nameplates** - over each enemy just its level, marker and name
  with a thin red health bar under it. And an **arrow over your target**,
  bobbing, red for enemies and green for friends. Both on the Overview
  page.
- **Enemy list** - the enemies fighting you or your group, one row each:
  a square that turns red while it targets you, its raid marker, name and
  health, your current target lit. On the Orbs page; it needs enemy
  nameplates switched on, and it is for reading - a click does not target.
- **Scenario guide** - a small banner at the top left with the current
  expansion's campaign quest, or, while the story waits, the next step
  and what it needs. A click follows it with a waypoint; a right click
  picks another campaign. On the Quests page.
- **Quest tracker as FFXIV's task list** - no box, everything
  right-aligned, the objectives in light blue with an arrow and a tick
  once done. On the Quests page.
- **Round minimap** - a round map in a gold ring with N, E, S and W
  (they turn with you when the game rotates the minimap), the zone above
  it, clock and coordinates below. On the Map page.
- **Main menu as round buttons** - the game's menu buttons as a row of
  round buttons with a gold ring that lights up when a button has news.
  On the Overview page.
- **Server info, gold and a bag overview** - your realm with frame rate,
  addon CPU share, memory, latency, waiting mail and the time (the busiest
  addons on mouse-over, each value can be switched off); the gold you
  carry; and a block of dots per bag for used and free slots, which opens
  your bags on a click. Blizzard's bag buttons can be hidden too. All on
  the Overview page, movable.

**Finding your way**

- **Waypoints and routes** - as many waypoints as you like: Ctrl-click
  the world map or type /way 45.2 67.8 name. They show as numbered pins on
  the world map, the minimap and the compass, and in a list (/way list, a
  click on the compass, or the Nav page) where you pick, rename or remove
  them. Reaching one moves on to the nearest, or with Route on to the next
  in order - for farming and gathering rounds.

**Tooltip**

- **Reputation and ensembles** - items and currencies that give
  reputation show the faction and your standing with it, and transmog
  ensembles how much of the set you have collected already. Both can be
  switched off on the Tooltip page.

## 1.6.0 (2026-10-08)

- **Buff bar in Final Fantasy's style** - your status icons as a bar of
  their own in place of Blizzard's buffs, which grew far too long in
  combat and ran into the minimap on the Steam Deck. Buffs line up from
  the right edge, debuffs from the left, each shaped like FFXIV's (a
  point on top for a buff, at the bottom for a debuff) with the time left
  below it and a coloured mark above a debuff you can dispel. Out of
  combat it shows every buff, in combat only those of a minute or less.
  Right click cancels a buff. Icon size and icons per row per device.
  Tick "Own buff bar" on the Player and target page.
- **Quick menu on the Steam Deck (still being tested)** - hold RB, then
  the D-pad opens the map, bags, quest log or character, and Y, B, A, X
  the talents, group finder, collections or game menu. Tick "Quick menu:
  hold RB" on the Cross page. It has not been tried on a Steam Deck yet -
  off by default, and feedback is very welcome.
- **Name of the interact target** - with the interact key, the object it
  would use (a chest, an ore vein, a herb) gets its name below the game's
  icon, gold in reach and grey out of it, and a ring fills while you
  gather. Takes over from Plumber's soft target nameplate. Tick "Name of
  the interact target" on the Overview page.
- **Talking head as a subtitle** - the box with the speaking portrait
  that pops up during quests becomes a quiet line of text on a dark band,
  the speaker in gold; the voice plays as before and an open map covers
  it. Optionally only the voice in instances. Takes over from Plumber's
  talking head. Tick "Talking head as a subtitle" on the Overview page.
- **Auction prices on the road** - a "Scan now" button below the auction
  house reads every listing (at most every 15 minutes, the game's limit),
  and from then on every item's tooltip shows its cheapest buyout and
  the age of the scan, a stack in your bags its whole value. The bag
  window shows what it all would fetch, and valuable slots (100g and up,
  adjustable) get a gold coin. On the Loot and merchant, Tooltip and Bags pages. The auction
  house window itself can wear DeckUI's look too.
- **Fixed: LT + RT** on the Steam Deck fired a button of the left or right
  half instead of the small middle crosses.
- **Vehicles and encounters** that take over your action bar no longer
  show Blizzard's old bar under the crosses - the crosses already show
  those actions, and DeckUI's own leave button stands in for its one.
- **Final Fantasy style:** your pet is now a small bar beside yours instead
  of a round orb. In a vehicle it shows you, while your bar shows the
  vehicle.

## 1.5.0 (2026-10-02)

- **Stance bar at the crosses** - forms, stances, auras and stealth as
  round buttons between the two small middle crosses, in place of
  Blizzard's stance bar. The active one has a gold ring, cooldowns run
  as a circle. On the Steam Deck LB + X/Y/B/A picks a stance and
  LB + D-pad left/right steps to the next or previous one, in combat too;
  on the PC your own stance keys keep working. Tick "Stance bar at the
  crosses" on the Cross page.
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
  - Every module is switched on and off at the top of its own page;
    modules that are off are listed in grey and say what they do.
  - "General" became an Overview of all modules, merchant and loot
    settings have a page of their own, and the long explanations moved
    into tooltips - pages are much shorter.
  - At the bottom of each page: "Move" unlocks just that page's frames,
    "Defaults" puts that page's settings back (places on screen stay).
  - `/deck raid`, `/deck bags`, `/deck week` ... open a page directly.
  - New test buttons for the boss frames and the Delver's Journey bar.
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
