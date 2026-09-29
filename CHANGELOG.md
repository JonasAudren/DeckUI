# DeckUI changelog

What users see on the CurseForge file page and in the app. `changelog.ps1`
reads the section whose heading matches the version being released, so the
heading has to be `## <version>` - the rest of the line is free, a date is
welcome. Write for players: what changed for them, not which file moved.
Without a matching section a release falls back to the commit subjects,
which is duller but never blocks a release. A pre-release reads the section
of the version it leads up to, so `v1.0.1-beta` uses `## 1.0.1`.

## 1.1.0

- **New module: DeckUI Bags.** Your bags, your character bank and your
  warband bank, each in one window instead of a stack of small ones. It
  starts switched off, so nothing changes until you want it: tick "Bags"
  in `/deck` -> General.
  - **Bags** open wherever Blizzard's would - B, the bag bar, the mailbox,
    a merchant, the auction house - and right clicks do what they always
    did: use, sell, post, deposit, even a potion in combat.
  - **Categories:** items sort themselves into New, Equipment, Consumables,
    Trade Goods, Quest, Other and Junk, best quality first. All your free
    slots fold into one empty slot with a number on it. Prefer every slot
    where it really is? One button switches to a plain grid.
  - **Bank:** opens at the banker next to your bags. Switch between your
    character bank and the warband bank, one tab at a time, deposit
    everything with one click, buy new tabs, and move gold in and out of
    the warband bank. A locked warband bank tells you why.
  - **Find things:** search, sorting, gold, the currencies you track,
    item level on gear and a coin on grey items even when no merchant is
    open.
  - **Clear out old stuff:** the pocket-watch button dims everything from
    the current expansion, so only what is left over from earlier ones
    stays lit.
  - Drag a window by its frame to move it. Columns and size are set
    separately for the Steam Deck and the PC in the new Bags tab.
- The settings window is a little taller, to fit the fourth module switch.

## 1.0.3

- **You can leave vehicles again.** Hiding Blizzard's action bars took the
  leave-vehicle button with them, so once you were in a vehicle there was no
  way out on the Steam Deck. DeckUI now brings its own. It appears whenever you
  can get out, and on a flight path it asks for an early landing. It works in
  combat, never shows up next to Blizzard's own button, and can be moved with
  `/deck unlock` like every other frame.
- New, optional: an **assistant indicator** that shows the spell the
  single-button assistant wants to cast next. A green ring means you can
  cast it right now; grey with a cooldown swirl means it is not ready yet
  and waiting is the right call. It answers the question a quiet button
  cannot: is there really nothing to press, or am I missing something?
  Switch it on in the Cross settings under "Assistant indicator" and move
  it with `/deck unlock`. The assistant has to sit on one of your action
  bars for it to work.

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
