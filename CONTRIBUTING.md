# Contributing to Grudgekeeper

Grudgekeeper keeps score of world PvP in WoW: Forever. Pull requests are welcome. This file is the brief for you
and for any AI agent working with you (`CLAUDE.md` loads it), so both start from the same rules.

## How we work together

- **Contributors open pull requests against `main`. Only the owner pushes to `main` and pushes tags.** A tag is a
  release: CurseForge builds and publishes from it, so a stray tag ships to every player.
- One feature or fix per pull request. Say what you checked in the game and what you did not. "Not tested in
  game" is a fine sentence; a guess presented as a result is not.
- Before a merge we run a larger private smoke suite: it plays the addon against a mocked client, and every case
  has controls that must fail when the fix is taken out. A pull request can come back with a failing case, or be
  merged with a conflict resolved on our side. Your commits stay in the history either way.
- Some behaviour is settled on purpose: who gets a death when several enemies hit you, what a mode shares, what
  starts off. If a change would turn one of those around, ask in the pull request first.
- "The owner" in comments and pull requests means the repository's owner. They write Norwegian; code, comments
  and pull requests are in English, and their words are quoted as they wrote them.

## Before you claim anything

Every claim carries three lines: **Claim** (one sentence), **How I know** (`file:line`, a test name, a measurement,
or "the owner said so"; when it is a search, paste the search), and **Not checked** (the step between the evidence
and the claim that you did not walk). The third line is never "nothing".

- Verify the thing you depend on, not the nearest thing to it: the API docs are not the game, the tests are not
  the client, the working tree is not the copy the game loaded.
- A green test you cannot explain is not a pass. Ask what the test would have to see to fail.
- A question only the game can answer is asked of someone in the game, not modelled.

## The game

- **Forever runs the Mainline 12.1.5 API with Midnight's addon restrictions.** TOC interface `16001`. No Classic
  or retail fallbacks.
- **No combat log.** `COMBAT_LOG_EVENT_UNFILTERED` can't be registered, not even in a `pcall`. Grudgekeeper counts
  what the client hands over: `PARTY_KILL`, `UNIT_DIED`, the death recap, the damage meter after a fight, and the
  players you can see (nameplates, target, mouseover).
- **Secret values.** Much of another unit is secret (`UnitHealth`, identity on instanced maps), and reading a
  secret aura raises an error. Check `issecretvalue` (Grudgekeeper's `Secret`) before comparing or storing, and
  treat a secret as unknown, never as missing.
- **Names have no realm since build 71037**, and characters have surnames ("First Surname"). Grudgekeeper keys every
  player and guild by name alone (`GK.KeyOf`). Never build a key ending in "-".
- **Combat lockdown.** `HideUIPanel` does nothing from addon code in a fight, so every close path calls `:Hide()`.
  Some calls pop the "blocked" dialog even inside `pcall` (`C_GuildInfo.GuildRoster`, `C_UI.Reload`).
- **Never assign over a Blizzard function or frame script.** Use `hooksecurefunc` and `HookScript`. After
  `LIB.RegisterWindow`, only `HookScript` the window's `OnShow` and `OnHide`.
- Small traps: an empty FontString reads back `nil`, not `""`; a menu's radio row closes the menu; `SendAddonMessage`
  returns a result to read; `GetCoinTextureString` lives in `C_CurrencyInfo`. A changed TOC needs a full client
  restart; a new texture needs only `/reload`.
- Blizzard's own UI code shows how the game does a thing: Gethe's `wow-ui-source`, branch `forever`.

## House rules

- **Everything from another player, a tooltip or a saved file is data.** Strings go through `GK.Clean` (control
  characters out, `|` neutralised so no link, texture or colour code survives, length capped). Numbers and enums
  are range-checked. Cap what a peer can make us keep, and rate-limit per sender. A peer changes only their own
  records; a relay never overwrites the owner's newer data; no message makes us whisper or reply in a loop.
- **The wire stays compatible.** New fields go at the end of a message, never reordered or reused, and an older
  client must still parse it. Write the fields in the protocol header at the top of the file
  (`Core/Guild.lua`, `Core/Notes.lua`).
- **Saved data:** new keys only, old keys keep their meaning, and a migration runs once behind a flag.
- **Quiet by default.** Anything that acts for the player or adds to the screen starts off. No chat line at login
  and no popups: news waits as a letter. Chat is for answers, errors, money handled, and a newer version in the
  guild (the owner asked for that line).
- Grudgekeeper is not a YippYapp addon. It shares only LibForever-1.0, which is its own repository: a change there
  goes there, stays backwards compatible and bumps the version.

## Code

- **Four folders.** `Core/` counts, keeps and sends; `Effects/` plays the splashes and toasts; `UI/` draws the
  windows and pages; `Dev/` is ours alone. The TOC loads them in its own order, so a new file goes in its folder
  and on its line in the TOC.
- **Lua 5.1.** A function holds at most 200 locals, and a `local function` must be defined above its first caller,
  or it is a nil global at runtime.
- Comments say why. When a line exists because the owner asked for it, quote their words and the date.
- Text players read: the feature's name as a player would search for it, short labels, one plain sentence of help,
  WoW terms in English.
- **No real player's name anywhere**: code, tests, screenshots, the changelog. Use made-up ones (Kari, Edvard,
  Pølse Hans, Gærd Balle).
- When a script writes code, read the written line back: a `\n` that became a real line break loads as an
  "unfinished string". Keep each file's line endings as they are.
- Art and sound must be ours to ship. Textures are 32-bit TGA in `Media/`.

## Tests

- `lua5.1 tests/run.lua` from the repository root. Add a test with every change, and say in the pull request how it
  fails without the change.
- The addon loads with no Lua errors (wowless is fine for that).
- `Dev/Debug.lua` (the test panel, `/grudge debug`) and `Dev/Shots.lua` (`/grudge shots`) are in the repository
  and not in the download: the TOC lists them between `#@do-not-package@` tags, and `.pkgmeta` leaves out `Dev`.
  Nothing else may need them.

## Changelog

- New lines go under `## Unreleased` at the top. A section that has been tagged is never edited.
- Write for players: what they notice, one bullet each, with a bold lead. No client markup (`|cff...`, `|T...|t`):
  CurseForge shows it as raw text.
- Read your bullets against the code before you commit. A sentence outlives the feature it described.
