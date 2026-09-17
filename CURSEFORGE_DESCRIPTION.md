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
DeckUI detects the device automatically (1280x800 screen or an active gamepad = Steam Deck) and switches input accordingly. Override it in `/deck` → General → Device.

## Commands
- `/deck` – settings, `/deck unlock` / `lock` – move frames, `/deck reset` – reset positions, `/deck device` – detected device
- `/orbs`, `/dc`, `/spec` – jump to a module tab

## Setup on the Steam Deck
1. `/dc` → "Set up gamepad (LT/RT)" once (enables the gamepad, LT = Shift, RT = Ctrl)
2. `/dc` → "Apply default bindings" once (D-pad targeting, A jump, B menu, X interact, Y character)

## Libraries (embedded)
oUF, LibStub, CallbackHandler-1.0, LibActionButton-1.0 – see the LICENSE files in the libs folders.
