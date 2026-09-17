# DeckUI

A compact, controller-friendly interface for World of Warcraft on the **Steam Deck** – that also works on the PC with your normal key bindings.

DeckUI is a hub with three load-on-demand modules; enable or disable each one in `/deck`.

## DeckUI Orbs – round unit frames
- Player and target as large orbs: health fills the orb, power runs as a ring around it, cast bar inside the orb
- Focus (medium), target-of-target and pet (small, docked), up to five boss orbs
- Round buff/debuff icons, own-debuffs filter, buff duration filter
- Health text as percent, absolute, short (1.2M) or short + percent
- Class resource dots (combo points, holy power, runes, ...) around the player orb
- Big target name announce on every target change
- Class and reaction colours

## DeckUI Cross – FFXIV-style cross hotbar
- Two halves of round buttons: **LT** = left, **RT** = right, **LT+RT** = the small middle crosses (24 slots)
- Mirrors **Action Bar 1** (with stance/vehicle paging) and **Action Bar 2**, so you fill your bars as usual
- Steam Deck: D-pad and A/B/X/Y with glyphs on the buttons
- PC: your own key bindings for bars 1 and 2, with the bound keys shown on the buttons
- Keys are bound to Blizzard's native commands, so **press-and-hold casting** and the **single-button assistant** work, including its changing icon
- Dimmed out of combat, full brightness in combat or whenever you touch it; size slider
- Hides Blizzard's bars 1 and 2 (optional)

## DeckUI Spec – spec switcher
- One round icon per specialization, click to switch (out of combat), gold ring on the active spec

## Steam Deck / PC detection
DeckUI detects the device automatically (1280x800 screen or an active gamepad = Steam Deck) and switches input accordingly. Override it in `/deck` → General → Device, or with `/deck deck`, `/deck pc` and `/deck auto`.

## Works alongside ConsolePort
Most of ConsolePort works fine next to DeckUI – its radial menus, camera targeting, interface navigation and inventory menus. Its **action bar** does not: it sits on the same LT/RT plus D-pad and face button combinations, it re-asserts its own key overrides over ours, and it unregisters the events on Blizzard's action buttons that DeckUI reads the pushed state from.

ConsolePort ships as several separate addons, so the fix is one checkbox: uncheck **Console Port Action Bar** in the addon list and keep **Console Port** itself. DeckUI tells you in chat when it sees the bar module enabled. If you would rather keep ConsolePort's bar, switch the Cross module off in `/deck`.


## Commands
- `/deck` – settings, `/deck unlock` / `lock` – move frames, `/deck reset` – reset positions
- `/deck device` – show the detected device, `/deck deck` / `pc` / `auto` – force one
- `/orbs`, `/dc`, `/spec` – jump to a module tab

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

Turning on Lua errors with `/console scriptErrors 1` before reproducing the problem gives you the actual error text, which is worth more than any description.

## Libraries (embedded)
oUF, LibStub, CallbackHandler-1.0, LibActionButton-1.0 and LibButtonGlow-1.0 – all under permissive licences, listed with their authors and terms in `THIRD-PARTY.txt` inside the DeckUI folder.
