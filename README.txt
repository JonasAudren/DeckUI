DeckUI - migration from DeckOrbs + DeckCross to a hub with modules
==================================================================

Target structure in ...\_retail_\Interface\AddOns\:

  DeckUI\                 <- NEW (hub)
    DeckUI.toc, core.lua, widgets.lua, panel.lua, minimap.lua
  DeckUI_Orbs\            <- was DeckOrbs
    DeckUI_Orbs.toc, core.lua, layout.lua, config.lua, libs\oUF\ (unchanged)
  DeckUI_Cross\           <- was DeckCross
    DeckUI_Cross.toc, core.lua, input.lua, config.lua, textures\ (button glyphs), libs\ (unchanged)

Step 1: rebuild the folders
  1. Quit WoW. Back up / commit DeckOrbs and DeckCross.
  2. Rename "DeckOrbs" to "DeckUI_Orbs", delete DeckOrbs.toc inside it.
  3. Rename "DeckCross" to "DeckUI_Cross", delete DeckCross.toc inside it.
  4. Copy the three folders from this ZIP into AddOns\, overwrite existing
     files. Leave the libs folders as they are.

Step 2: start and verify
  1. Restart WoW completely.
  2. Addon list: DeckUI, DeckUI Orbs, DeckUI Cross and DeckUI Spec must all be checked
     (the modules are marked "load on demand").
  3. Log in: orbs and cross hotbar are there. Note: frame positions are
     reset ONCE because the position keys are now English - just unlock
     and drag them back into place.
  4. /deck  -> window with tabs General / Orbs / Cross.
     /orbs and /dc jump straight to their tab.
  5. General -> uncheck "Cross" -> message "after /reload".
     /reload -> bar is gone. Check it again -> bar appears IMMEDIATELY
     without reload. (That is the real test: loading a module in-game.)

Boss frames (Orbs)
  Up to five boss orbs in a column on the right, only shown while bosses
  exist. Move them via /deck unlock ("Boss frames" overlay). Blizzard's
  boss frames are hidden meanwhile; switch off in /orbs if you prefer them.

Spec switcher (DeckUI_Spec, replaces QuickSpec)
  Row of round spec icons, click to switch (not in combat), active spec
  has a gold ring. /spec (or /qs) toggles the bar, /deck unlock moves it.
  Delete the old QuickSpec folder, it would conflict on /qs.

Per-device settings
  Frame positions and the size sliders (Orbs, Cross) are stored separately
  for the Steam Deck and the PC. "Reset all positions" only resets the
  current device. Optional: General -> "Set Blizzard UI scale per device
  at login" with one scale value per device.

Commands
  /deck         open/close settings
  /deck unlock  unlock frames (green overlays, draggable)
  /deck lock    lock frames
  /deck reset   reset all positions
  /deck device  print which device was detected (Steam Deck / PC)

Device detection
  Auto = Steam Deck if the screen is 1280x800 or a gamepad is active, else PC.
  Override in General -> Device button (Auto / Steam Deck / PC).
  "Cross hotbar only on Steam Deck" keeps the cross hotbar off on the PC
  (off by default: on the PC the cross hotbar uses keyboard keys instead).

What the crosses show (both devices)
  Buttons 1-12 = Action Bar 1 (left cross + top/right of the right cross,
  with stance/vehicle paging like Blizzard's main bar), buttons 13-24 =
  Action Bar 2. Fill your bars as usual, the crosses follow.
  Steam Deck: LT/RT + D-pad / face buttons. PC: your normal WoW key
  bindings of Action Bar 1 and 2; the labels show the keys.
  Action Bar 1 and 2 themselves are hidden (switch off in /dc -> Look).
