# Alt sync: the nudge and grudges across characters

Planned with the owner on 2026-11-27. This file holds the decisions and the plan for the work. The agent that builds
it reads this first.

## Background

- The Death Note (`GK.char.tracked`) is the list of players you picked to watch. The setting `deathNoteShared`
  ("One Death Note for all my characters", `UI/Options.lua:415`) makes every character of the account on the same
  side use one list (`GK.db.deathNotes[faction]`, `GK.TrackedList` in `Core/Sightings.lua`). It is opt-in, and it
  stays opt-in.
- Grudges (`GK.char.foes`) are the automatic score against each enemy. They are per character and never shared.
  The kill log, `deaths` and `won` are per character too.
- Players don't know that the shared Death Note exists. An alt also can't see what another character has stored.

## Decisions

### D1. The nudge

- It shows on any character that is **not the first character the account has seen**, while `deathNoteShared` is
  off and the account has never handled the nudge.
- It does **not** depend on this character's list being empty, or on other characters having grudges.
- **One time per account.** Clicking "Share" or "Keep separate" handles it, and it never shows again on any
  character. The setting then stays whatever the player picked until they change it in Settings. If
  `deathNoteShared` is already on, the nudge never shows.
- **No popup at login.** Too many addons already do that. The nudge lives in the window and waits to be found.
- **Where:** in the Death Note page, as soon as you're on an alt, whether the list is empty or not.
- **Changed after testing in the game (2026-11-27):** the line and the button in the list "gets mixed in all the
  other information" (the user). The nudge is now a glowing "?" in the page's top right corner, beside "Add
  someone". Hovering shows a tooltip ("Share one Death Note?"). A click opens a small window of its own
  (`GK.OpenAltShare`, a frame sheet) with the panel's text and the two buttons. The list stays as it was. The
  "line next to the button" and "click opens a small panel" bullets below describe the first version.
- **Look:** a small button with a breathing gold glow, a soft halo that fades in and out and never flashes (demo A
  at https://claude.ai/artifact/YDY6QxfKn62wvhi24DNwVV; the in-game version is a looping alpha animation on a glow
  texture). The glow stops while the player hovers it. Respect the same quiet-motion habits the addon already has.
- **Line next to the button:** "It looks like you play more than one character. Do you want them to share one
  Death Note?"
- **Click opens a small panel**, not the settings page. It has:
  - a short explanation: one Death Note for every character on this side; this character's own list joins the
    shared one, and it comes back as it was if sharing is turned off (that is how `GK.JoinDeathNote` works);
  - a separate block, after a line break, in the window's faded grey hint colour:
    "Note: Your grudges across all your characters can always be viewed on the Grudges page.";
  - a line saying this can be changed later in Settings;
  - two buttons: "Share my Death Note" (turns `deathNoteShared` on, as the checkbox does) and "Keep separate".
- The shared Death Note is per side (Alliance/Horde). The nudge only concerns characters on the same side.

### D2. Grudges across characters: per-character scores plus an account copy

The owner picked this over sharing the grudges themselves (that would mean moving `foes` into account data and
merging the scores, and a merge bug would lose history that can't be recovered).

- Each character keeps its own `GK.char.foes` as it is today. Nothing is migrated.
- Each character also writes a copy of its grudges into account data. The copy has the counts and the last times
  only (`k`, `d`, `a`, `last`, `lastKill`, `lastAssist`, `lastDeath`, plus what a row needs to draw: name, class,
  race, level). It leaves out the `hits` timestamps, to keep the saved file small on accounts with many alts.
- The copy is written at login and whenever this character's grudges change.
- **The totals do not need the Death Note setting.** They are read-only and harmless, so a player who keeps separate
  Death Notes can still see who killed them most across all characters.
- The account also keeps a roster of its characters: name with realm, side, and which one was seen first (for D1).
  Old characters show up once they log in with the new version. The owner knows this; don't mention it again.

### D3. The character switch on the Grudges page

- A small dropdown on the Grudges page: "This character", "All my characters", and one entry for each character on
  this side.
- It appears on the "Killed me" view whenever the account has more than one character on this side. It is hidden on
  "Killed us" and "Versus", which are guild views that already cover everyone.
- "All my characters" adds up each enemy's scores across characters, so "who has killed me most across all my
  characters" is "Killed me" plus "All", sorted as usual.
- **The remembered view:** the page opens on whichever of "This character" or "All my characters" the player
  used last, saved for the account. Picking one specific character is a quick look. It is never saved, and it lasts
  until the window closes or the player switches back. No separate "default view" setting.
- "Post a kill order" and opening a player's record work the same from every view.

### D4. Removing a grudge from any view

- A grudge can be removed from any view, not only from the current character's.
- Removing it from another character's view, or from "All", writes a removal note into account data: the enemy, the
  character (every character, for "All"), and the time. The account copy hides the row straight away.
- When that character logs in, it applies the removal notes for it before anything else and deletes the grudge
  from its own `foes`, then clears the note.
- An alt can only kill someone while it's logged in, and it applies the notes at login, so a kill can never land
  between a removal and its note being applied. A kill after that starts a fresh grudge from zero, which shows up on
  the page again. Keep the time on the note as a safeguard anyway: never delete a kill newer than the note.
- Removing from the current character's view works as it does today (`Core/Guild.lua:1492`), and it also updates
  this character's account copy.

### D5. Share brings in every character's Death Note

- The owner decided on 2026-11-27, after testing in the game, that the account copy also holds each character's own
  Death Note list (`entry.tracked`, written by `GK.WriteAltCopy`), and that turning sharing on merges every
  same-side character's list into the shared one at once (`GK.JoinAltDeathNotes`, called from
  `GK.DeathNoteTurnedOn`).
- Why: clicking "Share my Death Note" on an alt showed nothing from the main, because `GK.JoinDeathNote` only reads
  the list of the character that is logged in.
- This adds to D2's copy, so it is to be raised with the owner in the pull request.
- Re-add guard: `GK.db.altJoined[charKey]` holds the Death Note tick at which that character's list was merged. At
  that character's next login `GK.JoinDeathNote` sees it and merges nothing, so a name removed from the shared list
  stays removed.
- The copied list is data from a saved file: strings go through `GK.Clean`, numbers are range-checked, and the merge
  stops at `GK.MAX_TRACKED`.

## Plan

Work on a branch in a worktree, for example `.worktrees/alt-sync` on `feat/alt-sync`. Follow the repo's
`CLAUDE.md` and `CONTRIBUTING.md`. The comment style quotes the owner with dates. Tests run with
`../wow-addon-workshop/bin/test Grudgekeeper` (from the workspace layout).

| Unit | Agent | What |
|------|-------|------|
| 1 | orchestrator | Commit this file on the branch. |
| 2 | worker (Sonnet) | Account data: the roster (D2), each character's grudge copy (D2), removal notes applied at login (D4). Tests. |
| 3 | worker (Sonnet) | Nudge logic (D1): a function that says whether to show it, and the "Share" and "Keep separate" handlers that set the setting and the handled flag. Tests. |
| 4 | orchestrator | Grudges page (D3, D4): the character switch, the remembered view, the summed "All" view, removal from any view. `UI/Window.lua`, the Grudges entry near line 940. |
| 5 | orchestrator | Nudge UI (D1): the line and the glowing button in the Death Note page, the glow stopping on hover, the panel. |
| 6 | orchestrator | Review the whole branch, then deploy with `./deploy.sh Grudgekeeper` from `~/source/repos/wow-workspace` (it builds the dev-name copy), so the owner can try it in the game. |

Stay out of `GK.testMode` (the test panel and screenshots), as `GK.TrackedList` does.
