---
name: grudgekeeper-dev
description: How to make a change to Grudgekeeper (the WoW: Forever world-PvP addon in this repository) - where each part lives, recipes for a new setting, wire field, warning, sound, notification or patch note, the tests to add and the pull request to write. Use it before writing code here; CONTRIBUTING.md has the rules it assumes.
---

# Making a change to Grudgekeeper

Read `CONTRIBUTING.md` first: the rules there hold for every step below. This file is the map and the recipes.

## Where things live

| File | What it holds |
|---|---|
| `Core.lua` | `defaults` (every saved setting), migrations, names (`GK.KeyOf`, `GK.Show`, `GK.SameName`), sounds (`GK.SoundChoices`, `GK.PlayChoice`), warnings (`WARN_WAY`, `GK.WarnStyle`, `GK.WarnAs`), `GK.Changed`, `GK.Store`, the `/grudge` commands and their help |
| `Guild.lua` | the guild's wire: protocol header at the top, `Msg`, `Int`, `HANDLERS`, `Paced`, rate limits (`Allowed`); leaderboard, kill orders, the feed, the login catch-up |
| `Kills.lua` | your kills and deaths: `PARTY_KILL`, `UNIT_DIED`, the death recap, the damage meter after a fight, points and streaks |
| `Sightings.lua` | enemy players in sight: nameplates, the seal and the eye, the Death Note, warnings when one is near or targets you |
| `Notes.lua` / `NotesUI.lua` | Shame and Kudos: the data and its own wire (`HANDLERS` in Notes.lua), then the ledger pages, cards, tooltip lines and nameplate rows |
| `Options.lua` | the settings as data (`GK.SettingsChapters`: chapters of rows built with `Check`, `WarnRow`, `SoundCell`, `Choice`, ...) and the pages drawn from it |
| `Window.lua` | the ledger window and its pages |
| `Letters.lua` | letters (news that waits), `NEWS` and the patch notes (`PATCH_NOTES`, `PATCH_LATEST`) |
| `Announce.lua`, `Effects.lua`, `Fx*.lua` | splashes and toasts, and each tier's effect |
| `Notice.lua`, `Move.lua` | the letter icon, and Arrange on screen |
| `Post.lua`, `Pick.lua`, `Profile.lua` | writing a kill order, the who-picker, a player's card |
| `Mail.lua` | the card of bounties you owe at a mailbox, and money given by mail or trade |
| `Social.lua`, `GuildTab.lua`, `Inspect.lua`, `MapPins.lua` | the tooltip line, our tab on the guild window and on Inspect, the map pins |
| `Debug.lua`, `Shots.lua` | the test panel and the store page's pictures: in the repository, never in the download |

The three stores: `GK.db` is the account's (settings), `GK.char` this character's (log, foes, Death Note),
`GK.Store()` the current guild's (board, orders, feed). After changing any of them, call `GK.Changed()`; the
screens listen for it.

## Recipes

**A new setting.** Its default in `Core.lua`'s `defaults`, with a comment saying what it does and who asked. Its
row in `Options.lua`'s `GK.SettingsChapters`, on the page a player would look for it. A test in `tests/run.lua`
that names the page it lands on. A setting that acts for the player or adds to the screen starts off; changing
an existing account's value means a migration that runs once behind a flag.

**A new field on the wire.** At the end of its message, never in the middle. Add it to the protocol header at the
top of the file. Read it with `Int(f[n], lo, hi)`, `GK.Clean(f[n], max)`, `GK.ValidClass` or `GK.ValidLevel`, so a
bad value becomes nil and not an error. Test both ways: an old message without the field still parses, and an
older client reading the new one sees what it always did.

**A new warning.** A key in `defaults` (off to begin with), its way in `WARN_WAY`, a `WarnRow` on the Warnings
page, and `GK.WarnAs(key, text, ...)` where it happens. Only out of a fight unless it has to be in one, and once
per enemy per gap: a warning that repeats is turned off by everyone.

**A new sound.** By FileDataID (`"game:<id>"`), so nothing has to ship. Listen to the file first (see the
`forever-datamining` skill), and mind where its loudest moment falls. A SoundKit's own volume can be near zero.

**A splash, toast or effect.** `Announce.lua` decides what plays and `Effects.lua` with a `Fx*.lua` how. A splash is
the player's own moment, a toast a guildie's. Each has a row under Mine or Guildies.

**A patch note.** `PATCH_NOTES[version]` in `Letters.lua`: short, New and Changed, one line each. The number and
date are the release's.

## Tests

- `lua5.1 tests/run.lua` from the repository root, after every change. Add the test that fails without your change,
  and say in the pull request that you saw it fail.
- Load the addon (wowless is fine) and check for Lua errors. A file that parses can still fail to load.
- What only the game can show - a frame's look, whether an event fires - goes in the pull request as "not
  checked in game", with what to look at.

## The pull request

- A title in the changelog's voice: what a player gets.
- What changed and why, per file, briefly.
- Compatibility: wire fields (with their numbers) and saved data, and what an older client sees.
- Claim / How I know / Not checked for each thing you say works.
- The `## Unreleased` bullet, written for players.
