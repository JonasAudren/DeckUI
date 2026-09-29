# DeckUI changelog

What users see on the CurseForge file page and in the app. `changelog.ps1`
reads the section whose heading matches the version being released, so the
heading has to be `## <version>` - the rest of the line is free, a date is
welcome. Write for players: what changed for them, not which file moved.
Without a matching section a release falls back to the commit subjects,
which is duller but never blocks a release. A pre-release reads the section
of the version it leads up to, so `v1.0.1-beta` uses `## 1.0.1`.

## 1.0.3

- **You can leave vehicles again.** Hiding Blizzard's action bars took the
  leave-vehicle button with them, so once you were in a vehicle there was no
  way out on the Steam Deck. DeckUI now brings its own. It appears whenever you
  can get out, and on a flight path it asks for an early landing. It works in
  combat, never shows up next to Blizzard's own button, and can be moved with
  `/deck unlock` like every other frame.

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
