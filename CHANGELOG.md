# DeckUI changelog

What users see on the CurseForge file page and in the app. `changelog.ps1`
reads the section whose heading matches the version being released, so the
heading has to be `## <version>` - the rest of the line is free, a date is
welcome. Write for players: what changed for them, not which file moved.
Without a matching section a release falls back to the commit subjects,
which is duller but never blocks a release.

## 1.0.0

First public beta.

- Round unit frames (orbs) for player, target and focus, on oUF.
- An FFXIV-style cross hotbar: LT/RT together with the D-pad and the face
  buttons on a controller, your own action bar bindings on a keyboard.
- One-click specialization switching.
- Settings are per device: frame positions and the orb and cross sizes are
  remembered separately for the Steam Deck and the PC, so the same account
  fits both screens.
- Note for ConsolePort users: uncheck "Console Port Action Bar". It claims
  the same LT/RT combinations and wins, which leaves the DeckUI crosses
  unlit. Everything else in ConsolePort works fine next to DeckUI, and the
  addon says so at login.
