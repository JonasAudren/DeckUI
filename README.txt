DeckUI
======

A compact, controller-friendly interface for World of Warcraft on the Steam
Deck - that also works on the PC with your normal key bindings.

DeckUI is a hub with nine load-on-demand modules. Enable or disable each one
in /deck; what you do not use is never loaded.

  DeckUI          the hub: device detection, settings window, movable frames
  DeckUI Orbs     round unit frames (player, target, focus, pet, boss)
  DeckUI Cross    FFXIV-style cross hotbar for controller and keyboard
  DeckUI Spec     one-click specialization switcher
  DeckUI Bags     all bags in one window with search and sorting
                  (off until you switch it on in /deck)
  DeckUI Quests   a compact objective tracker
                  (off until you switch it on in /deck)
  DeckUI Map      a square minimap and a smaller world map
                  (off until you switch it on in /deck)
  DeckUI Tooltip  the mouse-over tooltip in DeckUI's style, at a fixed place
                  (off until you switch it on in /deck)
  DeckUI Nav      a compass bar, the navigation target with an arrow, and /way
                  (off until you switch it on in /deck)
  DeckUI Week     your week at a glance: vault, lockouts, keystone, weeklies,
                  renown and currencies for every character
                  (off until you switch it on in /deck)

Requires World of Warcraft Retail, Interface 120100 (Midnight).
License: MIT, see LICENSE.txt. The bundled libraries and their
licences are listed in THIRD-PARTY.txt.


Installation
------------
1. Quit the game completely.
2. Copy all ten folders into

     World of Warcraft\_retail_\Interface\AddOns\

   so that you end up with AddOns\DeckUI, AddOns\DeckUI_Orbs,
   AddOns\DeckUI_Cross, AddOns\DeckUI_Spec, AddOns\DeckUI_Bags,
   AddOns\DeckUI_Quests, AddOns\DeckUI_Map, AddOns\DeckUI_Tooltip,
   AddOns\DeckUI_Nav and AddOns\DeckUI_Week.
3. Start the game. In the addon list on the character screen, DeckUI,
   DeckUI Orbs, DeckUI Cross, DeckUI Spec, DeckUI Bags, DeckUI Quests,
   DeckUI Map, DeckUI Tooltip, DeckUI Nav and DeckUI Week must all be
   checked. The nine modules are marked "load on demand" and depend on the hub - if the hub is unchecked, nothing loads.
4. Log in. The orbs, the cross hotbar and the spec bar are there.

A full restart is needed after installing or updating; /reload is not enough
for new folders or textures.


First steps
-----------
  /deck                    opens the settings window
  minimap button           left-click settings, right-click unlock/lock,
                           drag to move the button itself

On the Steam Deck, run the two buttons in the Cross tab once:

  /dc  ->  "Set up gamepad (LT/RT)"      enables the gamepad and maps
                                         LT = Shift, RT = Ctrl
  /dc  ->  "Apply default bindings"      A jump, X interact, B game menu,
                                         Y character; D-pad up/down cycles
                                         enemies, left/right cycles friends

Both are per device, so do this once on the Deck and once on the PC if you
play on both. "Apply default bindings" asks before it writes anything and
lists which of your existing bindings it would replace - there is no undo,
so read that list if it appears.

Then fill Action Bar 1 and Action Bar 2 as you normally would - the crosses
mirror those two bars, they do not have their own slots.

Check what DeckUI thinks you are playing on:

  /deck device             prints Steam Deck or PC and why

On login the Cross module also reports its input mode in chat:
"controller mode (LT/RT)" or "keyboard mode".


Commands
--------
  /deck                    open/close the settings window
  /deck unlock             unlock frames (green overlays, drag them)
  /deck lock               lock frames
  /deck reset              reset all positions (current device only)
  /deck device             print the detected device
  /deck deck               force Steam Deck mode (test it while on the PC)
  /deck pc                 force PC mode
  /deck auto               back to automatic detection
  /deck bars               print the action bar layout saved for this device
  /deck layout             print the Edit Mode layout saved for this device

  Forcing a device takes full effect after /reload; it switches input,
  button labels, sizes and the saved positions to that device.

  /orbs                    jump to the Orbs tab
  /dc                      jump to the Cross tab
  /spec  or  /qs           toggle the spec bar
  /spec config             jump to the Spec tab
  /bags                    open/close the bags (like B)
  /bags config             jump to the Bags tab
  /quests                  fold or unfold the quest tracker
  /quests config           jump to the Quests tab
  /quests reset            bring the quest tracker back to its default place
  /deckmap                 jump to the Map tab
  /deckmap reset           bring the minimap back to its default place
  /decktip                 jump to the Tooltip tab
  /decknav                 jump to the Nav tab
  /decknav next, prev      step the navigation target through tracked quests
  /way 45.2 67.8           set a waypoint (/way clear removes it; /dway with TomTom)
  /week                    open the week overview (also Shift-click on the minimap button)

Diagnostics for the cross hotbar, useful when reporting a problem:

  /dc page                 print the active action bar page and the slot behind a button
  /dc bars                 print which Blizzard bars were found and hidden
  /dc bare                 toggle the button decorations off and on
  /dc overlay [n]          print the visible parts of button n


General tab
-----------
Modules           each module on or off. Enabling takes effect
                  immediately, disabling after /reload.
Show minimap button
                  hide it if you prefer /deck.
Damage meter in DeckUI's look
                  Blizzard's own damage meter with flat bars, a dark
                  background and a thin edge. Off by default; switching it
                  off again needs a /reload.
Sell junk at the merchant
                  sells what the game counts as junk whenever you talk to a
                  merchant; the buyback tab still has the last twelve items.
Repair at the merchant
                  repairs everything at a merchant who can; first, so the
                  gold is there, and again after the junk sale if it was not.
Repair with guild funds first
                  uses the guild bank when your rank allows it.
                  All three are off by default, apart from guild funds.
Fast auto loot    takes everything the moment the loot is there, and treats
                  loot as auto loot whenever your auto-loot setting says so
                  (with the modifier held it is manual, as usual).
DeckUI's loot window
                  a compact loot list in DeckUI's look instead of Blizzard's
                  window: click to take, "Take all" (also a key binding
                  under Keybindings > AddOns > DeckUI), quest items and
                  appearances you have not collected yet are marked. With
                  auto loot, what was taken is listed for a few seconds;
                  the window itself only appears if something stayed
                  behind. Window and list move on their own: drag them, or
                  /deck unlock shows both with a sample to place them.
                  Drag it by its frame; it opens where you left it.
                  Both are off by default.
Lua errors        collects every Lua error with its stack, to copy into a
                  report (also /deck errors).


Devices tab
-----------
Device            cycles Auto / Steam Deck / PC. Auto means: Steam Deck if
                  the screen is 1280x800 or a gamepad is active, else PC.
Cross hotbar only on Steam Deck
                  keeps the cross hotbar off on the PC. Off by default - on
                  the PC the crosses run on your keyboard bindings instead.
Set Blizzard UI scale per device at login
                  with one scale value per device, for the Deck's small
                  screen. Off by default; when you turn it off again, the
                  current scale simply stays.
Unlock frames / Reset all positions
                  the overlays are labelled Player, Target, Focus, Boss
                  frames, Cross Hotbar and Spec bar. Reset only affects the
                  device you are currently on.
Keep on this device
                  Blizzard keeps key bindings, what sits on your action bars
                  and the active Edit Mode layout on its server, so the Deck
                  and the PC load the same ones. Tick a box on each device
                  and it keeps its own:
                  - Key bindings: WoW's own setting to store them locally.
                  - Action bar layouts: per character and spec; put back at
                    login, /reload and spec change.
                  - Edit Mode layout: make one layout per device in Edit
                    Mode. Switching asks for a reload, so Blizzard's frames
                    pick the layout up cleanly.
                  What is set up when you tick a box becomes that device's;
                  later changes are remembered.


DeckUI Orbs - round unit frames
-------------------------------
Player and target are large orbs: health fills the orb, power runs as a ring
around it, the cast bar sits inside the orb. Focus is medium, target-of-target
and pet are small and docked to their orb, and up to five boss orbs appear in
a column while bosses exist.

Options in the Orbs tab:

  Size (this device)       saved separately for Deck and PC
  Opacity, Brightness
  Buffs up to duration     hides long buffs; takes effect after /reload
  Health text              Percent / Absolute / Short (1.2M) / Short + %
  Show cast in orb
  Show buffs and debuffs
  Only own debuffs on target
  Show focus frame
  Show boss frames         hides Blizzard's boss frames while on; switch it
                           off if you prefer Blizzard's
  Class resource dots on player orb
                           combo points, holy power, runes and so on
  Announce target          shows the target's name large on every change
  Style                    Orbs, or Final Fantasy: the player as long HP/MP bars
                           with their numbers, the target as a wide bar at the
                           top with its cast, status icons and its own target,
                           the bosses as FFXIV's enemy list: name, health, a
                           red edge while one targets you, whom it targets,
                           its cast (grey if it cannot be interrupted) and your
                           debuffs. Needs a /reload; focus and pet stay orbs.
                           /orbs boss shows five boss rows of your target, to
                           place them with /deck unlock.
Party and raid settings sit in the Group tab:

  Party list               Final Fantasy style rows for your party: class icon,
                           role, health with its number, a thin resource bar,
                           your buffs and all debuffs, a gold edge on the member
                           you target, faded out of range. Replaces Blizzard's
                           party frames, needs a /reload, off by default; in a
                           raid Blizzard's raid frames stay. /deck unlock moves it.
  Side by side             the party in one row across instead of a column,
                           per device; the auras then sit below each member
  Party list size          saved separately for Deck and PC
  Test (or /orbs test)     shows five rows of yourself, to set size, layout and
                           place without a group; off again with a second click
  Raid frames              a compact grid, one column per raid group: tiles in
                           class colour with name, a role icon for tanks and
                           healers, up to three debuffs (dispellable ones with a
                           coloured border), your own buffs and mana for healers.
                           Replaces Blizzard's raid frames (the raid tools on the
                           left stay), needs a /reload, off by default.
  Raid frame size          saved separately for Deck and PC
  Test (or /orbs raid)     shows a full raid of yourself


DeckUI Cross - cross hotbar
---------------------------
Two halves of round buttons, 24 slots in total:

  LT      left cross
  RT      right cross
  LT+RT   the small middle crosses

The crosses mirror Action Bar 1 (buttons 1-12: the left cross and the upper
half of the right one, with the same stance and vehicle paging as Blizzard's
main bar) and Action Bar 2 (buttons 13-24). Fill your bars as usual and the
crosses follow.

  Steam Deck    LT/RT plus D-pad and A/B/X/Y, with controller glyphs on the
                buttons
  PC            your own WoW key bindings for bars 1 and 2, with the bound
                keys shown on the buttons - nothing to set up

Keys are bound to Blizzard's native commands, so press-and-hold casting and
the single-button assistant work, including its changing icon.

Options in the Cross tab:

  LB + D-pad up/down zooms the camera
                           off by default, Steam Deck only. LB becomes Alt
                           (the only way the game combines LB with another
                           button), so it is no longer a button of its own.
                           Hold for a smooth zoom, tap for one step.
  Size (this device)       saved separately for Deck and PC
  Out-of-combat opacity    dimmed out of combat, full brightness in combat or
                           whenever you touch it
  Show button labels
  Hide the Blizzard bars the crosses mirror
                           on by default, so nothing shows twice


DeckUI Tooltip - the mouse-over window
--------------------------------------
A dark tooltip with a thin edge, like the rest of DeckUI. The edge takes the
item's quality colour, or the class colour of a player. Tooltips that belong
to a button or a frame stay beside it; all others appear at their own place,
which /deck unlock moves - separately for the Steam Deck and the PC.

Options in the Tooltip tab:

  At its own place         on by default; off leaves Blizzard's corner
  Size (this device)       saved separately for Deck and PC
  Players in their class colour
  Spec and item level of players
                           others need a short look at their gear, so the
                           line appears a moment later, never in combat
  Whom the unit is targeting
  Item, spell and NPC IDs while Shift is held


DeckUI Nav - compass and waypoints
----------------------------------
A compass bar at the top of the screen turns with you: cardinal points, the
navigation target (at the edge, faded, when it lies behind you), your party in
class colour, and the rares and treasures the minimap shows. Below it, the
target's name with an arrow pointing at it, the distance and the arrival time
at your current pace. In the world, DeckUI's own beacon replaces Blizzard's
diamond: the target's name above it, distance and arrival time below; off
screen it moves to the edge with an arrow. The target is always the one Blizzard's navigation
follows, so the diamond in the world, the map and the compass agree.

Two key bindings (Options > Keybindings > AddOns > DeckUI) step through your
tracked quests, nearest first - put them on a controller button to switch
targets without opening the map. /way 45.2 67.8 sets Blizzard's own waypoint;
decimal commas work too. The compass hides in instances, where the game gives
no position. /deck unlock moves compass and target separately per device.


DeckUI Week - your week at a glance
-----------------------------------
One window with six tabs: an overview (Great Vault, keystone and runs, locked
raids and dungeons, open weekly quests, Traveler's Log, time to the reset),
all characters side by side, the locked instances, the weekly quests, renown
and every currency with a weekly or seasonal cap. Each character saves its
week while you play it; the others show what they had when last seen, and
once the weekly reset has passed that is marked. Weekly quests are learned:
every weekly quest that appears in a quest log is remembered for all your
characters. Open it with /week, a key binding or Shift-click on the minimap
button.


DeckUI Spec - spec switcher
---------------------------
One round icon per specialization, click to switch out of combat, gold ring on
the active spec. /spec or /qs toggles the bar, /deck unlock moves it.


Using DeckUI with ConsolePort
-----------------------------
ConsolePort is the established controller addon for World of Warcraft, and
most of it works fine next to DeckUI. Its action bar does not.

ConsolePort ships as several separate addons, so this is one checkbox:
uncheck "Console Port Action Bar" in the addon list and leave "Console Port"
itself checked. You keep its radial menus, camera targeting, interface
navigation and inventory menus, and DeckUI brings the cross hotbar and the
orbs.

Why the two cannot share: ConsolePort's own bar sits on the same LT/RT plus
D-pad and face button combinations, it re-asserts its own key overrides over
ours, and it unregisters the events on Blizzard's action buttons - which is
where DeckUI reads the pushed state from. DeckUI says so in chat when it
sees the bar module enabled.

If you would rather keep ConsolePort's bar, switch the Cross module off in
/deck and use DeckUI for the orbs and the spec bar.


Per-device settings
-------------------
Frame positions and the two size sliders (Orbs, Cross) are stored separately
for the Steam Deck and the PC, because the Deck's 1280x800 screen needs a
different layout than a monitor. Everything else - checkboxes, display
options, UI scale values - is shared.

SavedVariables: DeckUIDB, DeckOrbsDB, DeckCrossDB, DeckSpecDB.


Upgrading from DeckOrbs, DeckCross or QuickSpec
-----------------------------------------------
Delete the old DeckOrbs, DeckCross and QuickSpec folders from AddOns\ before
starting. QuickSpec in particular would fight over /qs.

Your frame positions are reset once, because the saved position keys changed.
Just /deck unlock and drag everything back into place.


Troubleshooting
---------------
Cross buttons light up but cast the wrong thing
    ConsolePort's action bar is enabled and claims the same keys. See
    "Using DeckUI with ConsolePort" above.


No cross hotbar on the PC
    Either the Cross module is off in the General tab, or "Cross hotbar only
    on Steam Deck" is checked in the Devices tab.

Cross buttons are empty
    The crosses only display Action Bar 1 and 2. Put your spells on those two
    bars.

Blizzard's bars show as well
    Cross tab -> "Hide the Blizzard bars the crosses mirror".

LT/RT do nothing on the Deck
    Cross tab -> "Set up gamepad (LT/RT)", then reload. The game needs the
    gamepad enabled before it sees the triggers as modifiers.

Something is broken and you want to see the error
    /console scriptErrors 1, then /reload.

Start over completely
    Quit the game and delete the DeckUI*.lua files in
    _retail_\WTF\Account\<account>\SavedVariables\. Defaults apply on the
    next login.


Author
------
Gottlieb Nowara - https://github.com/JonasAudren/DeckUI
