# DeckUI – project notes for Claude Code

World of Warcraft addon suite (Lua) for the **Steam Deck and PC**, written by Gottlieb
as a learning project. Retail client, currently **Midnight (Interface 120100)** - verified in game with
`/deck build`, which compares the running client against our `.toc`. That number also
picks the CurseForge game version on upload, so it is the one place to change at a patch
(`bump-version.ps1 <version> -Interface <new>`). Beware the PTR: 12.1.5 exists as
`wowxptr` while live is 12.1.0, and filing a release under it hides the addon from
everyone who plays.
The owner tests everything in-game himself; Claude Code cannot run WoW.

## Layout

```
DeckUI/          hub: device detection, settings window (/deck), movable frames, minimap button
DeckUI_Orbs/     module: round unit frames on oUF (/orbs)         libs/oUF
DeckUI_Cross/    module: FFXIV-style cross hotbar (/dc)           libs/LibStub, CallbackHandler, LibActionButton-1.0
                 assist.lua: the assistant indicator, a movable frame of its own
DeckUI_Spec/     module: spec switcher (/spec, /qs)
DeckUI_Bags/     module: bag window, later the banks (/bags)    off by default
```
Modules are `LoadOnDemand`, depend on `DeckUI`, and register a settings tab with
`D.RegisterModule(key, { title, build = function(content) end })`. The hub loads
enabled modules from `DeckUIDB.modules` at `ADDON_LOADED`.

`package.ps1` builds the upload zip: `dist\DeckUI-<version>.zip` with the five addon
folders at the **top level** (a wrapping folder would install everything one level too
deep), README, LICENSE and THIRD-PARTY inside `DeckUI\`, without the `.github`/`utils`
clutter from `libs\oUF` and without the unused LibStub/CallbackHandler copies that the
other libraries bundle. It aborts if the five `.toc` files disagree on version or interface.
`bump-version.ps1 <version>` raises `## Version` (and with `-Interface` the interface)
in all five at once - `package.ps1 -Version` only stamps the staged copies, so without
the bump the repository and CurseForge drift apart. `changelog.ps1 <version>` produces the
changelog the release sends along: the `## <version>` section of `CHANGELOG.md` when there
is one, otherwise the commit subjects since the previous tag. Write the section - the
fallback carries build and release plumbing that means nothing to a player. It falls back
rather than failing so a forgotten section never blocks a release, and `bump-version.ps1`
says so when the section is missing.

Each folder is a separate WoW addon; in `Interface\AddOns\` they are directory
junctions pointing into this repo. Any `.lua` change is live after `/reload`;
`.toc` changes or new folders/textures need a full client restart.

## Conventions

- **Everything in English**: code, comments, menu texts, chat messages, README.
  Slash commands (`/deck`, `/orbs`, `/dc`, `/spec`) and SavedVariables names
  (`DeckUIDB`, `DeckOrbsDB`, `DeckCrossDB`, `DeckSpecDB`) never change.
- Font: `D.FONT = STANDARD_TEXT_FONT` (locale-safe). Masks: `D.MASK`, disc texture `D.DISC`.
- Widgets: `D.Label / D.Hint / D.Button / D.Slider / D.Checkbox` from `DeckUI/widgets.lua`.
  **Explanatory lines go through `D.Hint`**, which limits the width so the text wraps inside
  the panel - never place newlines by hand, they fight the wrapping and strand single words
  on their own line, and a line without a width limit runs out of the frame. Both were real
  bugs, reported by a stranger on reddit before anyone here noticed them.
  `D.Slider` puts its value **below** the bar: `OptionsSliderTemplate` parks it above, which
  is where the heading is, and the two printed on top of each other.
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
  (`/dc overlay`, `/dc bare`, `/dc bars`, `/dc page`, `/dc trace`, `/dc assist`, `/deck device`,
  `/deck build`, `/deck deck|pc|auto`) – they were essential for Midnight issues.

## Hard-won Midnight facts (do not "simplify" these away)

- **Bindings go to Blizzard's native commands**, not to our buttons:
  `SetOverrideBinding(header, true, "SHIFT-PADDUP", "ACTIONBUTTON1")`. Only the native path runs
  the engine's press-and-hold repeat (single-button assistant, hold-to-cast). `SetOverrideBindingClick`
  onto LibActionButton buttons breaks that. Our cross buttons only *display*; the pushed state is
  mirrored from Blizzard's buttons via `hooksecurefunc(native, "SetButtonState")`.
- The crosses mirror **Action Bar 1** (buttons 1–12, with a page state driver like Blizzard's main
  bar) and **Action Bar 2** (buttons 13–24, slots 61–72). Deck = LT/RT + D-pad/ABXY,
  PC = the player's own Blizzard bindings of those bars (nothing to bind).
- **Every page the state driver can select needs a registered state.** `PageMacro()` can return
  `GetOverrideBarIndex()` (18 on retail), so `NUM_PAGES` is derived from that API, never hardcoded.
  Slots are one flat list, page *p* button *i* = `(p-1)*12+i`, so page 18 is 205–216. A missing
  state makes LibActionButton's `GetAction()` return `"empty"` and the button goes blank – that
  was the "mount abilities not shown" bug. `/dc page` prints the active page and the resolved slot.
- **ConsolePort's action bar and our crosses cannot coexist.** `ConsolePort_Bar` claims the same
  LT/RT + D-pad/face combinations, hooks every `SetOverrideBinding*` and re-asserts its own
  override so ours loses, and calls `UnregisterAllEvents` on `ActionButton1-12` – which is
  exactly where our pushed state comes from. It is a separate addon, so the fix is unchecking
  "Console Port Action Bar"; the rest of ConsolePort (cursor, targeting, rings, menus) is fine
  next to us. `WarnConsolePortBar` in `DeckUI_Cross/input.lua` prints that at login – keep it.
- Blizzard's main bar is **not** called `MainMenuBar` anymore and buttons sit in per-button
  containers. Find a bar by climbing parents from `ActionButton1` until the parent is `UIParent`
  (`ResolveBar` in `DeckUI_Cross/input.lua`). Hide by reparenting to a hidden frame +
  visibility state driver + SetParent hook.
- **Hiding the bars took Blizzard's leave-vehicle button with it** (reported 2026-09-29), which
  left no way out of a vehicle on the Deck. `MainMenuBarVehicleLeaveButton` is a child of
  Action Bar 1 (`MainActionBar`) - confirmed 2026-09-29 with `/dc bars`, which prints its parent
  chain: `MainActionBar > DeckCrossBarHider > UIParent`. The fix does not depend on it: we carry our own
  `DeckCrossLeaveVehicle` (movable, "Leave vehicle"), shown whenever `CanExitVehicle()` or
  `UnitOnTaxi` and none of Blizzard's leave buttons `IsVisible()`, so it never doubles up.
  It is polled (0.2 s) on purpose: taxis have no clean start event, and Blizzard updates its
  own button on the same events, so asking about its visibility there would race it.
  `VehicleExit` / `TaxiRequestEarlyLanding` are not protected - a plain button works in combat.
- `ActionButtonTemplate` has a `TextOverlayContainer` at frame level 500 whose textures darken the
  button while a modifier is held – strip its textures (`CleanOverlay`).
- Blizzard's template draws the **icon in the BACKGROUND layer**; anything of ours behind the icon
  must be BACKGROUND sublevel -8/-7.
- Blizzard's highlight/pushed/checked textures are neutralised (methods replaced with a no-op)
  and replaced by our own masked additive glows.
- The assistant's buttons are found through **`C_ActionBar.IsAssistedCombatAction(slot)`** -
  the action bar owns that question, not `C_AssistedCombat`, which has only `GetActionSpell`,
  `GetNextCastSpell`, `GetRotationSpells` and `IsAIAvailable` (swept out of the client on
  2026-09-23, after two wrong guesses cost an evening). **An assistant slot cannot be
  recognised by its contents**: `GetActionInfo` on it returns whatever spell the assistant
  recommends at that moment, so a slot holding the assistant reads as an ordinary changing
  spell. Only that call knows.
  Everything assistant-related hangs off one table (`assistedButtons`): the painted icon, the
  red no-target ring, the failure flash. An empty table means none of it can show, which looks
  like three separate bugs - `/dc assist` prints the API, the buttons holding the action, the
  flag and the ring's actual colour, and when the API is missing it sweeps the namespaces for
  whatever replaced it.
- The assistant indicator (`DeckUI_Cross/assist.lua`, off by default) answers the question a
  button cannot: *is* there nothing to press, or am I missing something? It shows the spell
  `GetNextCastSpell()` recommends, with a green ring when it is castable **right now** and grey
  plus a cooldown swirl when it is not - so a grey ring is the confirmation that waiting is
  correct. Asked for by the owner while tanking, where the assistant is weakest.
  The trick is spell **61304**, the global cooldown itself: a spell whose cooldown ends no later
  than the GCD is only held up by the GCD, and treating that as "not ready" would make the
  indicator flicker with every cast instead of answering anything. The swirl deliberately shows
  the spell's own cooldown only.
  **It only works while the assistant sits on one of the player's action bars** (owner's test,
  2026-09-29) - the settings hint and the 1.0.3 changelog say so. Why was not measured; do not
  "fix" it by guessing at a cause. It is still a separate frame because that slot need not be
  on a cross: the assistant may sit on a bar the crosses do not mirror and be reached by a key
  binding, with no cross button to decorate.
- Feedback that a press arrived: Blizzard's PUSHED state is too short to see on a tap, so
  `ShowPushed` holds our glow for `PUSH_MIN` past the release. A rejected cast flashes
  `DeckFailed` red on whichever button is lit, falling back to the assistant's buttons.
- **State on a cross button is shown with colour, never with brightness.** Brightness is
  already taken: `SetGroup` in `DeckUI_Cross/core.lua` dims whole groups with `b:SetAlpha`,
  and out of combat the bar sits at roughly a quarter alpha, where a darkening veil is
  barely a difference. The "assistant has no target" state therefore rides on the ring
  colour (`RING_NOTARGET`), set inside `SetGroup` itself - it repaints every dim tick, so a
  colour written anywhere else would be overwritten four times a second.
- Assisted combat: the purple rotation highlight is hidden on cross buttons; the assistant's
  changing icon is painted by polling `C_AssistedCombat.GetNextCastSpell()` every 0.1 s. This
  **never ran before 2026-09-23** because the detection above asked a function that does not
  exist, leaving `assistedButtons` empty and the poll returning on its first line. Do not trust
  this entry without `/dc assist` saying `API yes` and a non-zero button count.
  **"The assistant stops while I hold the key" was measured and is not ours** (2026-09-18,
  `/dc trace` on the PC): the engine keeps repeating, the assistant keeps naming Sunfire,
  and every attempt fails with `Invalid target` because the player has no target at all -
  the moment one exists again the rotation continues by itself. `Spell is not ready yet`
  in between is just the repeat outrunning the global cooldown. Re-targeting cannot be
  automated: `TARGETNEARESTENEMY` and friends need a hardware event, which is exactly what
  Blizzard locks down.
  The press-and-hold repeat lives entirely in the engine and stops the moment the key
  combination stops matching. LT/RT are **analog** triggers driving the emulated Shift/Ctrl,
  so easing off below the threshold releases the modifier while the direction key stays
  down, and the returning trigger brings no fresh key-down for the combination - the repeat
  does not resume. `/dc trace` prints modifier edges, casts and any re-applied bindings with
  timestamps to tell that apart from a cast that simply failed.
- Gamepad glyph atlases (`Gamepad_Ltr_Face_*`) do not exist on this client; we ship our own
  TGA glyphs in `DeckUI_Cross/textures/`.
- Health/power values may be *secret values*: display them via tags / Blizzard helpers
  (`AbbreviateNumbers`), never compare or compute with them.
- **So are cooldown numbers.** `C_Spell.GetSpellCooldown(id)` hands back `startTime`,
  `duration` and `modRate` as secret values for real spells - measured 2026-09-23 on Shield of
  the Righteous, while the same call for the GCD spell 61304 returned plain numbers. Comparing
  one throws *"attempt to compare a secret number value"* and taints the addon. Readable are the
  booleans in that table: `isActive`, `isEnabled`, and `isOnGCD` on the GCD entry. The raw
  numbers may still be passed straight into Blizzard's own `Cooldown:SetCooldown` - handing them
  on is fine, doing arithmetic on them is not. `assist.lua` is built on exactly that line.
- oUF: `ClassPower` / `Runes` dots are StatusBars with a masked WHITE8x8 fill; `[deck:hpshort]`
  is our custom tag.

## Bags module (in progress, not yet tested in game)

Built from Blizzard's 12.1.0 source (Gethe/wow-ui-source, `live`, read 2026-09-29), not from
memory - the bank changed completely in 11.2. Plan: one grid first, categories second.
- **Blizzard's bag frames keep running, parked under a hidden frame**; our window shows while
  `IsAnyBagOpen()` says so (hooks on the open/close functions plus a 0.2 s poll). We do not
  replace `ToggleAllBags` and friends: the bank's `OnShow` calls `OpenAllBags`, and our code in
  that call chain would taint the bank frame for the rest of it.
- Item buttons are **Blizzard's `ContainerFrameItemButtonTemplate`**, with no click script of
  ours: its handler covers every case (potion in combat, merchant, auction house, bank deposit,
  split). It learns its bag from an attribute (`SetBagID`) precisely so that stays untainted.
  The grid scales as a whole; the template's overlays are laid out for 37 px.
- Bank facts for the next step: `Enum.BagIndex.Bank`, `BankBag_1..7` and `ReagentBank` are
  gone. Bank slots are ordinary bags: `CharacterBankTab_1..6` (6-11), `AccountBankTab_1..5`
  (12-16). A right click on a bag item at the bank deposits into
  `BankFrame:GetActiveBankType()`, which is nil unless Blizzard's `BankFrame` and its panel
  are shown - so the bank has to be parked like the bags, not replaced.
  Sorting a bank is `C_Container.SortBank(bankType)`, the only form Blizzard's code uses.
- `/bags debug` prints Blizzard's open state, slots per bag and how many frames are parked.

## Testing checklist (owner does this in-game)

1. `/console scriptErrors 1`, `/reload`, no error window.
2. Chat shows `DeckUI Cross: controller mode` (Deck) / `keyboard mode` (PC).
3. LT/RT + key casts and lights the button; assistant held repeats; icon follows.
4. `/deck unlock` → drag → positions stick per device.
5. Every checkbox / slider / button in all five tabs works without error.
6. Fresh-install test: move SavedVariables away, log in, defaults apply.

## Roadmap / parked

- Release on CurseForge as **Beta** after the checklist (see CURSEFORGE_DESCRIPTION.md;
  add `X-Curse-Project-ID` back to the four `.toc` files with the real numeric ID – it was
  removed rather than shipped as a placeholder, `X-Website` is already filled in).
  The first Beta goes up **by hand** with `package.ps1`, so the owner sees what users get.
- Releases are automated: push a tag `v<version>` and `.github/workflows/release.yml`
  runs `package.ps1 -Version <tag>` on the runner and uploads the result through the
  CurseForge API with `upload-curseforge.ps1`, with the changelog from `changelog.ps1`
  (hence `fetch-depth: 0` on the checkout - a shallow clone has no tags to diff against).
  Run it by hand first from the Actions tab with **dry_run** on and the release type
  on `auto` - that rehearses a tag exactly, including the type it would pick, and
  builds and resolves the game version without uploading. Needs the repository secret
  `CF_API_TOKEN`. Raise the version with `bump-version.ps1` before tagging.
  **The tag's suffix decides the release type**: `v1.0.1-beta` goes up as a beta,
  `v1.0.1-alpha` as an alpha, and a plain `v1.0.1` as a full release that reaches
  every user - so a stray tag push is no longer harmless. The suffix stays part of
  the version, so archive and `.toc` say what the file page says; a pre-release
  takes the changelog section of the version it leads up to (`1.0.1-beta` reads
  `## 1.0.1`).
  The BigWigs packager was looked at and dropped: it expects the main addon at the repository root, while ours
  sits in `DeckUI/` beside the three modules, which `move-folders` cannot untangle.
  Switching to `.pkgmeta` externals would mean adopting that layout after all.
- Parked by owner's choice: set switching via LB/RB, controller navigation in the settings
  window (built and removed – he uses the trackpad), German localisation.
