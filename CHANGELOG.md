# DeckUI changelog

What users see on the CurseForge file page and in the app. `changelog.ps1`
reads the section whose heading matches the version being released, so the
heading has to be `## <version>` - the rest of the line is free, a date is
welcome. Write for players: what changed for them, not which file moved.
Without a matching section a release falls back to the commit subjects,
which is duller but never blocks a release. A pre-release reads the section
of the version it leads up to, so `v1.0.1-beta` uses `## 1.0.1`.

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
