# DeckUI

A compact, controller-friendly interface for World of Warcraft on the **Steam Deck** – that also works on the PC with your normal key bindings.

DeckUI is a hub with seven load-on-demand modules; enable or disable each one in `/deck`.

## DeckUI Orbs – round unit frames
- Player and target as large orbs: health fills the orb, power runs as a ring around it, cast bar inside the orb
- Focus (medium), target-of-target and pet (small, docked), up to five boss orbs
- Round buff/debuff icons, own-debuffs filter, buff duration filter
- Health text as percent, absolute, short (1.2M) or short + percent
- Class resource dots (combo points, holy power, runes, ...) around the player orb
- Big target name announce on every target change
- Class and reaction colours
- Optional **party list in Final Fantasy XIV style**: class icon, role, health and resource bars, your buffs and all debuffs (dispellable ones marked), your target highlighted, faded out of range

## DeckUI Cross – FFXIV-style cross hotbar
- Two halves of round buttons: **LT** = left, **RT** = right, **LT+RT** = the small middle crosses (24 slots)
- Mirrors **Action Bar 1** (with stance/vehicle paging) and **Action Bar 2**, so you fill your bars as usual
- Steam Deck: D-pad and A/B/X/Y with glyphs on the buttons
- PC: your own key bindings for bars 1 and 2, with the bound keys shown on the buttons
- Keys are bound to Blizzard's native commands, so **press-and-hold casting** and the **single-button assistant** work, including its changing icon
- Dimmed out of combat, full brightness in combat or whenever you touch it; size slider
- Hides Blizzard's bars 1 and 2 (optional), and brings its own leave-vehicle button so you are never stuck in a vehicle
- Steam Deck: zoom the camera with **LB + D-pad up/down** (optional)
- Optional **assistant indicator**: shows the spell the single-button assistant wants next – green ring when you can cast it now, grey with a cooldown swirl when waiting is right

## DeckUI Spec – spec switcher
- One round icon per specialization, click to switch (out of combat), gold ring on the active spec

## DeckUI Bags – bags and banks (off until you switch it on)
- All bags in one window that opens wherever Blizzard's would; right clicks use, sell, post and deposit as always
- **Categories**: New, Equipment, Consumables, Trade Goods, Quest, Other, Junk – all free slots folded into one with a count; or a plain grid, one click away
- **Character bank and warband bank** in one window: one tab at a time, deposit everything, buy tabs, move warband gold
- Search, sorting, gold and tracked currencies, item level on gear, junk marked even away from a merchant
- **Old-expansions filter**: dims everything from the current expansion so leftovers stand out
- **Auction filter**: dims everything the auction house would not take
- Columns and size per device (Steam Deck / PC)

## DeckUI Quests – objective tracker (off until you switch it on)
- Takes over everything Blizzard's "All Objectives" window shows, in one compact, scrollable list
- Quests and campaign with progress bars; left-click quest log, shift-click untrack, right-click menu (focus, map, share, abandon)
- **Quest item and scenario spell buttons** beside their line, usable in combat, and the **find a group** eye
- World quests and bonus objectives of your zone, with time left
- **Dungeons, delves, scenarios**: stages, delve header with lives and treasure, bonus steps – and in **Mythic+** the timer, time left for +3/+2, deaths and affixes
- Achievements, Traveler's Log, neighbourhood endeavors, collections and recipes (reagents counted across bags, bank and warband bank), zone widgets such as capture bars
- Fold single sections or the whole tracker; width, size, text size and height limit per device

## DeckUI Map – minimap and world map (off until you switch it on)
- **Square minimap** in a plain frame: zone name, clock and your coordinates on its edges
- Tracking, calendar, addon menu, zoom and addon minimap buttons appear under the mouse; mail, crafting orders and instance difficulty always visible
- **World map as a movable window**, never full screen, controls under the mouse, quest log closed by default and restyled to match
- Switches for Blizzard's own map extras: player and cursor coordinates, fade while moving (no option for it in the game)
- Size and position per device

## DeckUI Tooltip – the mouse-over window (off until you switch it on)
- DeckUI's look: dark with a thin edge in the item's quality or the player's class colour, slim health bar
- At a place of its own, moved with `/deck unlock` – separately for the Steam Deck and the PC; tooltips of buttons stay beside them
- Players: class colour, **spec and item level**
- Whom the unit is targeting, with a warning when it is you
- Hold Shift for item, spell and NPC IDs

## Steam Deck and PC
DeckUI detects the device automatically (1280x800 screen or an active gamepad = Steam Deck) and switches input accordingly. Override it in `/deck` → Devices → Device, or with `/deck deck`, `/deck pc` and `/deck auto`.

Frame positions and sizes are kept per device anyway. Three switches in the **Devices** tab keep what the game otherwise shares between every computer you play on:
- **Key bindings** stay on the device you set them on
- **Action bar layouts** – a different layout on the Deck and on the PC, per character and spec, put back at login
- **Edit Mode layout** – one layout per device, switched automatically

## Works alongside ConsolePort
Most of ConsolePort works fine next to DeckUI – its radial menus, camera targeting, interface navigation and inventory menus. Its **action bar** does not: it sits on the same LT/RT plus D-pad and face button combinations, it re-asserts its own key overrides over ours, and it unregisters the events on Blizzard's action buttons that DeckUI reads the pushed state from.

ConsolePort ships as several separate addons, so the fix is one checkbox: uncheck **Console Port Action Bar** in the addon list and keep **Console Port** itself. DeckUI tells you in chat when it sees the bar module enabled. If you would rather keep ConsolePort's bar, switch the Cross module off in `/deck`.


## Commands
- `/deck` – settings, `/deck unlock` / `lock` – move frames, `/deck reset` – reset positions
- `/deck device` – show the detected device, `/deck deck` / `pc` / `auto` – force one
- `/orbs`, `/dc`, `/spec` – jump to a module tab
- `/bags` – open or close the bags, `/bags config` – the Bags tab
- `/quests` – fold or unfold the tracker, `/quests config` – the Quests tab, `/quests reset` – bring it back into view
- `/deckmap` – the Map tab, `/deckmap reset` – bring both maps back to their default places
- `/decktip` – the Tooltip tab

## Setup on the Steam Deck
1. `/dc` → "Set up gamepad (LT/RT)" once (enables the gamepad, LT = Shift, RT = Ctrl)
2. `/dc` → "Apply default bindings" once: A jump, B menu, X interact, Y character; D-pad up/down cycles enemies, left/right cycles friends

Step 2 writes into your key bindings, so it asks first and lists exactly which of your existing bindings it would replace. There is no undo, so read that list before you confirm – and if you would rather keep your own bindings, say no. The crosses work either way.

## Reporting a bug
Please open an issue at **https://github.com/JonasAudren/DeckUI/issues** – that keeps reports in one place with a history. Comments here are fine for short questions.

DeckUI ships diagnostic commands whose output makes a report much easier to act on. Run the fitting one and paste what it prints in chat:

- `/deck device` – which device DeckUI detected and why
- `/dc page` – the active action bar page and the slot behind a button (use this when buttons are blank or show the wrong thing)
- `/dc bars` – which Blizzard bars were found and hidden
- `/dc overlay` – the visible parts of a cross button
- `/bags debug` / `/bags bank` – what the bag and bank windows are built from
- `/quests debug` – whether Blizzard's tracker is off, and the state of the tracker's buttons
- `/deckmap debug` – where the minimap sits, the world map's scale and the map options
- `/deck bars` / `/deck layout` – the action bar and Edit Mode layout saved for this device
- `/decktip debug` – the tooltip's anchor, size and what it is waiting for

Turning on Lua errors with `/console scriptErrors 1` before reproducing the problem gives you the actual error text, which is worth more than any description.

## Libraries (embedded)
oUF, LibStub, CallbackHandler-1.0, LibActionButton-1.0 and LibButtonGlow-1.0 – all under permissive licences, listed with their authors and terms in `THIRD-PARTY.txt` inside the DeckUI folder.
