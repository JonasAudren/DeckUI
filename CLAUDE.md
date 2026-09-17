# DeckUI – project notes for Claude Code

World of Warcraft addon suite (Lua) for the **Steam Deck and PC**, written by Gottlieb
as a learning project. Retail client, currently **Midnight (Interface 120100)**.
The owner tests everything in-game himself; Claude Code cannot run WoW.

## Layout

```
DeckUI/          hub: device detection, settings window (/deck), movable frames, minimap button
DeckUI_Orbs/     module: round unit frames on oUF (/orbs)         libs/oUF
DeckUI_Cross/    module: FFXIV-style cross hotbar (/dc)           libs/LibStub, CallbackHandler, LibActionButton-1.0
DeckUI_Spec/     module: spec switcher (/spec, /qs)
```
Modules are `LoadOnDemand`, depend on `DeckUI`, and register a settings tab with
`D.RegisterModule(key, { title, build = function(content) end })`. The hub loads
enabled modules from `DeckUIDB.modules` at `ADDON_LOADED`.

Each folder is a separate WoW addon; in `Interface\AddOns\` they are directory
junctions pointing into this repo. Any `.lua` change is live after `/reload`;
`.toc` changes or new folders/textures need a full client restart.

## Conventions

- **Everything in English**: code, comments, menu texts, chat messages, README.
  Slash commands (`/deck`, `/orbs`, `/dc`, `/spec`) and SavedVariables names
  (`DeckUIDB`, `DeckOrbsDB`, `DeckCrossDB`, `DeckSpecDB`) never change.
- Font: `D.FONT = STANDARD_TEXT_FONT` (locale-safe). Masks: `D.MASK`, disc texture `D.DISC`.
- Widgets: `D.Label / D.Button / D.Slider / D.Checkbox` from `DeckUI/widgets.lua`.
  Slider/checkbox take `db` as a **function** returning the table, plus a key and an apply function.
  Widgets with a `Refresh()` method and a place in `content.widgets` are refreshed on tab show.
- Movable frames: `D.MakeMovable(frame, key, db)`; set `frame.defaultPoint` first.
  `key` is the saved-position key and the overlay label – renaming it resets the position.
- **Per-device settings** (`D.DeviceDB(db)` → `db.perDevice[deck|pc]`): frame positions and the
  Orbs/Cross size sliders. Everything else (checkboxes, display options) is shared.
  `D.MigrateToDevice(db, {fields})` moves old flat fields to both devices once.
- Device detection: `D.DetectDevice()` – 1280x800 screen or active gamepad = "deck", else "pc";
  `DeckUIDB.device` = auto|deck|pc overrides. `D.IsDeck()` is the only thing modules should ask.
- Prefer small, complete edits; the owner reads the diffs. Keep debug commands
  (`/dc overlay`, `/dc bare`, `/dc bars`, `/deck device`) – they were essential for Midnight issues.

## Hard-won Midnight facts (do not "simplify" these away)

- **Bindings go to Blizzard's native commands**, not to our buttons:
  `SetOverrideBinding(header, true, "SHIFT-PADDUP", "ACTIONBUTTON1")`. Only the native path runs
  the engine's press-and-hold repeat (single-button assistant, hold-to-cast). `SetOverrideBindingClick`
  onto LibActionButton buttons breaks that. Our cross buttons only *display*; the pushed state is
  mirrored from Blizzard's buttons via `hooksecurefunc(native, "SetButtonState")`.
- The crosses mirror **Action Bar 1** (buttons 1–12, with a page state driver like Blizzard's main
  bar) and **Action Bar 2** (buttons 13–24, slots 61–72). Deck = LT/RT + D-pad/ABXY,
  PC = the player's own Blizzard bindings of those bars (nothing to bind).
- Blizzard's main bar is **not** called `MainMenuBar` anymore and buttons sit in per-button
  containers. Find a bar by climbing parents from `ActionButton1` until the parent is `UIParent`
  (`ResolveBar` in `DeckUI_Cross/input.lua`). Hide by reparenting to a hidden frame +
  visibility state driver + SetParent hook.
- `ActionButtonTemplate` has a `TextOverlayContainer` at frame level 500 whose textures darken the
  button while a modifier is held – strip its textures (`CleanOverlay`).
- Blizzard's template draws the **icon in the BACKGROUND layer**; anything of ours behind the icon
  must be BACKGROUND sublevel -8/-7.
- Blizzard's highlight/pushed/checked textures are neutralised (methods replaced with a no-op)
  and replaced by our own masked additive glows.
- Assisted combat: the purple rotation highlight is hidden on cross buttons; the assistant's
  changing icon is painted by polling `C_AssistedCombat.GetNextCastSpell()` every 0.1 s.
- Gamepad glyph atlases (`Gamepad_Ltr_Face_*`) do not exist on this client; we ship our own
  TGA glyphs in `DeckUI_Cross/textures/`.
- Health/power values may be *secret values*: display them via tags / Blizzard helpers
  (`AbbreviateNumbers`), never compare or compute with them.
- oUF: `ClassPower` / `Runes` dots are StatusBars with a masked WHITE8x8 fill; `[deck:hpshort]`
  is our custom tag.

## Testing checklist (owner does this in-game)

1. `/console scriptErrors 1`, `/reload`, no error window.
2. Chat shows `DeckUI Cross: controller mode` (Deck) / `keyboard mode` (PC).
3. LT/RT + key casts and lights the button; assistant held repeats; icon follows.
4. `/deck unlock` → drag → positions stick per device.
5. Every checkbox / slider / button in all four tabs works without error.
6. Fresh-install test: move SavedVariables away, log in, defaults apply.

## Roadmap / parked

- Release on CurseForge as **Beta** after the checklist (see CURSEFORGE_DESCRIPTION.md;
  fill in `X-Curse-Project-ID` and `X-Website` in the `.toc` files).
- Parked by owner's choice: set switching via LB/RB, controller navigation in the settings
  window (built and removed – he uses the trackpad), German localisation, CurseForge packager
  automation with `.pkgmeta` externals.
