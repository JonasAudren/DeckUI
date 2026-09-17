DeckUI
======

A compact, controller-friendly interface for World of Warcraft on the Steam
Deck - that also works on the PC with your normal key bindings.

DeckUI is a hub with three load-on-demand modules. Enable or disable each one
in /deck; what you do not use is never loaded.

  DeckUI          the hub: device detection, settings window, movable frames
  DeckUI Orbs     round unit frames (player, target, focus, pet, boss)
  DeckUI Cross    FFXIV-style cross hotbar for controller and keyboard
  DeckUI Spec     one-click specialization switcher

Requires World of Warcraft Retail, Interface 120100 (Midnight).
License: MIT, see LICENSE.txt.


Installation
------------
1. Quit the game completely.
2. Copy all four folders into

     World of Warcraft\_retail_\Interface\AddOns\

   so that you end up with AddOns\DeckUI, AddOns\DeckUI_Orbs,
   AddOns\DeckUI_Cross and AddOns\DeckUI_Spec.
3. Start the game. In the addon list on the character screen, DeckUI,
   DeckUI Orbs, DeckUI Cross and DeckUI Spec must all be checked. The three
   modules are marked "load on demand" and depend on the hub - if the hub is
   unchecked, nothing loads.
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
                                         Y character, D-pad targeting

Both are per device, so do this once on the Deck and once on the PC if you
play on both.

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

  Forcing a device takes full effect after /reload; it switches input,
  button labels, sizes and the saved positions to that device.

  /orbs                    jump to the Orbs tab
  /dc                      jump to the Cross tab
  /spec  or  /qs           toggle the spec bar
  /spec config             jump to the Spec tab

Diagnostics for the cross hotbar, useful when reporting a problem:

  /dc page                 print the active action bar page and the slot behind a button
  /dc bars                 print which Blizzard bars were found and hidden
  /dc bare                 toggle the button decorations off and on
  /dc overlay [n]          print the visible parts of button n


General tab
-----------
Modules           Orbs, Cross and Spec on or off. Enabling takes effect
                  immediately, disabling after /reload.
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
Show minimap button
                  hide it if you prefer /deck.


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

  Size (this device)       saved separately for Deck and PC
  Out-of-combat opacity    dimmed out of combat, full brightness in combat or
                           whenever you touch it
  Show button labels
  Hide the Blizzard bars the crosses mirror
                           on by default, so nothing shows twice


DeckUI Spec - spec switcher
---------------------------
One round icon per specialization, click to switch out of combat, gold ring on
the active spec. /spec or /qs toggles the bar, /deck unlock moves it.


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
No cross hotbar on the PC
    Either the Cross module is off in the General tab, or "Cross hotbar only
    on Steam Deck" is checked.

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
