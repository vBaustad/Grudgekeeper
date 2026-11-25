---
name: forever-datamining
description: How to look up WoW: Forever client data from public sources - DB2 tables at a given build (spells, sounds, races, strings, icons, atlases), Blizzard's own UI code and API documentation (which values are secret, which calls are protected), and how to check a sound or an icon before using it. Use it when a change needs a number, an ID, a name or a flag from the game client, or when a new build is out.
---

# Datamining WoW: Forever

Forever is its own game version, with its own builds (`1.60.1.<build>`). Classic or retail data is not Forever's:
spells, races and sounds differ. Look it up for the build players have.

## Which build

- The game reports it: `select(2, GetBuildInfo())` is the build, the fourth value the interface number (`16001`).
  Mixing the two up makes a build check that is always wrong.
- A new build can change data with no patch notes. When one lands, look again at what you rely on.

## DB2 tables: wago.tools

`https://wago.tools/db2/<Table>?build=1.60.1.<build>` shows any client table at any build, as a page.
`&filter[<Column>]=<value>` narrows it, and `useHotfixes=1` adds the server's hotfixes, which can differ from the
files. The CSV button is a download. Tables we have used:

| Table | For |
|---|---|
| `Spell`, `SpellName`, `SpellMisc`, `SpellEffect` | a spell's name, flags and effects |
| `SoundKit`, `SoundKitEntry` | a sound kit's files (`FileDataID`) and its volume (`VolumeFloat`) |
| `ChrRaces` | races and their faction; Forever has Skyborne, one kind per side, both with the token "Skyborne" |
| `GlobalStrings` | the game's own words (`AUCTION_DURATION_ONE`, ...) |
| `ManifestInterfaceData` | every interface file, so whether an icon name or a file ID exists |
| `UiTextureAtlas`, `UiTextureAtlasMember` | atlas names (Forever keeps retail's names with its own bronze art) |

## Blizzard's UI code and API documentation

Gethe's `wow-ui-source` on GitHub, branch `forever`, holds Blizzard's interface code for this client. Two uses:

- **How the game does a thing**: read Blizzard's own frame (the mail window, the nameplates, the menus) before
  building ours around it.
- **What an addon may do**: `Blizzard_APIDocumentationGenerated/*.lua` lists every function and event with its
  arguments and flags. `SecretWhen...` (`SecretWhenUnitIdentityRestricted`, `SecretWhenUnitAuraRestricted`, ...)
  means the value can be secret, `RequiresUnitAuraAccess` that reading it raises an error, and
  `IsProtectedFunction` that addon code can't call it. Read the flag before guarding, not after a bug report.

The docs are not the game: a flag says what may happen, and some behaviour is in no doc at all. What only the game
can answer, ask someone in the game to try.

## Before you use what you found

- **A sound**: download the file from wago.tools and listen to it. Note where its loudest moment falls, and read the
  kit's `VolumeFloat`: some kits are all but silent. `PlaySoundFile(fileDataID, "Master")` plays a file by number
  and skips the kit's volume.
- **An icon or atlas**: check that the name or ID is in the build. A missing icon draws as a blank or green square
  and no test catches it.
- **A spell or race ID**: check it at the build players have, not the one in a guide.
- **Numbers on fan sites** can be rendered for a level other than the one you need. Read the table's raw value.

## Traps we have walked into

- A column that holds the same value on every row of a result is a filter, not a property. Ask what was left out.
- A search pattern that returns a plausible number is more dangerous than one that returns none. Paste the
  pattern with the result, and cross-check by another route, not the same one again.
- Don't crawl Wowhead: it puts up a bot check after about forty page loads a minute. Look up single pages by hand.
