# Grudgekeeper

World PvP score-keeping for WoW: Forever: who you killed, who killed you and how often, a guild
leaderboard, and kill orders with a bounty on them.

- `/grudge` opens the window: kill orders, the leaderboard, your Death Note, the grudges, the guild's news
  and your own page. Letters and the settings are the two red buttons beside the X.
- The kill orders page lists the open orders: those with gold first, the biggest first, then those with
  none, the newest first, with how long ago each was posted.
- The kill orders page has **All**, **Bounties** and **Mine** under its title. An order is a letter, a warning and a pin when it has gold on it, is a friend's, or is about you
  (yours, backed by you, in your Death Note, or on someone who killed you).
- Where a page shows more than one thing - this week or all time, who killed you or the guild, all the news
  or only the kill orders - tabs under the title switch between them.
- `/grudge post` writes a kill order on your target, or asks who when you have none. Posted on someone
  you saw a moment ago, it tells the guild where: the zone, and their pin on the world map.
- Each page of the window that you can add to has its action at the top - **Post a kill order**, **Add
  someone**, **Put someone on Shame** and **Give someone kudos**. It asks who:
  your target, the enemies you met lately, your group and who just left it, or a name you type. For a kill
  order and the Death Note the search has the WANTED poster on its right, and stays open for the next one. Where a list
  has column headings, click one to sort by it; the kill orders page keeps its own order.
- **Death Note** is your own list, and holds only who you put there: **Add someone** on its page, **Add to
  Death Note** on their card or in the right-click menu on an enemy. Up to 100, never shared, and nobody leaves
  it unless you take them off. With **One Death Note for all my characters** on (Settings, Death Note), your
  characters on the same side share it, notes and warning too. One of them near warns you and wears an eye over their nameplate. Adding one
  opens a small window for a note, if you want one: Add works without. The note shows on their row and card,
  where **Edit** changes it, and is never sent. Killing one is a toast of yours, with no letter and nothing
  said to the guild beyond the kill itself. It was called
  Track before, then the Death list, and whoever you tracked is on it.
- **Grudges** is what came by itself. **Killed me** has who killed you: those who lead over you first, the one
  you owe most at the top ("owed 3"), and under a faint line those you stand even with and those you lead.
  **Killed us** has who killed the guild most. The third tab is **Versus**, for the guild yours tracks. Kill one who
  killed you since you last got them and Revenge is told on screen, with where the two of you stand. Kill one
  who still leads over you again and a toast says where you stand now ("Grudge: ... now 2 - 3"), or that you
  are even.
- Kill sprees: your kills in a row, grey and farmed ones left out whatever bonus they give (they don't end a
  spree either), are called out at 3, 5, 7, 10 and 15 and every five after,
  yours as a big splash or a small toast and your guildies' as toasts, each where you put it with Arrange on screen -
  each tier with an effect and sounds of its own. `/grudge spree` shows a sample of both, and `/grudge spree
  merciless` (or bloodied, butcher, smoke, scythe, grudgebound, 20, 100, ended, tormentor, revenge) that one's
  splash, and `/grudge spree grudge` a grudge evened up. Each milestone is a line in the News as well, with a spree an enemy ended and a tormentor put down.
- The settings open on **Quick setup**. **What you see** sets the rows of Mine, Guildies and Warnings at once -
  Standard, Everything, Kill orders, Only mine, Warnings only or Nothing on screen - and says Custom once you change a
  row yourself. **What you share** is Everything, All but where I am (your score, never your zone or where you see a
  target), or Nothing (no score, no zone, no profile; only what a kill order needs). Neither turns down the other.
- In the settings, **Mine** has each of your own moments on a row: splash, toast or off, and its sound.
  **Guildies** has theirs: a toast or not, its sound, a threshold for sprees and titles, and whether only from
  your zone. **Warnings** has who is near or joins your group, and one in your Death Note targeting you (out of a
  fight, one whose nameplate is up, with a sound of its own; off to begin with), and the two with a sound let you pick it, with
  a play button beside each sound in the menu. Each of the three has a Play sounds of its own, which turns
  off and greys out the sounds on that page.
- A kill order fulfilled is told the same way - yours as a splash, with the bounty - and it is in the News's
  Kill orders tab, and for a day first on the guild window's tab: who got them, where and when.
- At a mailbox a card beside it lists the bounties you owe - each hunter and their part, in coins - in the game's
  mail window or another addon's, such as TSM's. **Fill in mail** writes the letter in the game's own window (hover
  it to see the letter first), and you press Send. Gold you mail or trade someone you owe marks it paid by itself;
  **Paid** marks one paid another way.
- `/grudge options` opens the settings, a page of the ledger with its tabs still under it. **Arrange on screen** there, or
  `/grudge arrange`, lets you drag the letter icon, the splash and the toasts where you want them.
- `/grudge test` puts four sample letters in your pile.
- `/grudge news` opens the patch notes of this version.
- The **You** tab is your own page: your card, and your latest kills, assists and deaths.
- Each of our lines in the game's right-click menu on a player has a box of its own under Settings, **Right-click
  menu**: on an enemy the Grudge file, the kill order, the Death Note and, for an officer, their guild; on a player on
  your side the profile, Shame, Kudos and their notes.
- Right-click a player on your side and pick **Grudgekeeper profile**: their profile in a window of its own -
  title, points, kills and deaths - with the way to the ledger under it. A player outside your guild is asked
  for theirs as it opens, and it fills in when they answer. On an enemy the line is **Grudge file**: what your
  guild knows of them. **Post a kill order** is right below it, and for an officer **Track their guild**
  when they are in one: the guild tracks one enemy guild at a time, and anyone from it warns whoever
  comes across them. An officer can also type one in: **Track a guild** on Versus, or `/grudge guild`.
- **Versus**, on Grudges, is the guild yours tracks: up to 25 of theirs who fought us on the left - how often we
  killed them and they killed us - and on the right both guilds' scores and top killers, who leads, the latest
  fights and since when they are tracked. A click on their banner shows who of theirs was seen lately. A row
  opens no card. Folded, a click turns to the versus page. With no guild tracked, the tab says how one is.
  It is what your client heard. A player counts once we know they are in that guild - seen with it while it is
  tracked, or named so by a guildie - and so do the kills and deaths against them your client heard of before.
- When you log in, each guildie online sends you their own kills and deaths since you were last on (half a day at
  most) and their count against the guild on watch, so the News and Versus fill in what you missed. None of it is
  a toast. A guildie who is offline then tells you when they log in while you are on. For Versus they
  also say their count against up to 40 of the guild on watch and their latest 20 fights against them,
  however old.
- When a guildie has a newer Grudgekeeper than yours, one line in chat says which version you have and which is new.
- A grudge that is wrong goes with **Forget grudge** on that player's card (two clicks): your record of
  them, here and in the guild's lists. Your score stays.
- Inspect a guildie and the **Grudgekeeper** tab below the game's own shows their page of the ledger. Inspect a
  player outside your guild who has Grudgekeeper, and the tab comes once they have answered.
- On the guild window, the **Grudgekeeper** tab under the game's own turns the window into a page of the
  ledger: you this week, the biggest kill orders, the leaderboard, and guild chat to read and write in.
  Click one of the game's tabs to have the guild window back.
- Right-click a player on your own side and pick **Put on Shame** or **Give kudos**, with a tag. A note in
  words is written in the ledger: the action at the top of Shame or Kudos, or **Add a note** on their notes'
  card.
  `/grudge note`, `/grudge shame` and `/grudge kudos` do the same from chat. The notes
  came from Guild Grudge, by dakristia; `/grudge import` takes over its saved notes.
- A Kudos player wears a medal for each tag over their nameplate, out of combat and out in the world, and a
  Shame player a badge for each of theirs, in a fight too. One player can be on both lists, with a row for each
  (Shame's on top), and each list keeps its own tags. The badges and both lists are dakristia's.

Forever closes the combat log to addons. Grudgekeeper counts what the client does hand over: your
group's killing blows (`PARTY_KILL`), an enemy player's death when someone else finished them (`UNIT_DIED`),
the game's damage meter once a fight is over (for assists), the
death recap, and the enemy players you can see (nameplates, target, mouseover). Open world only - instances and battlegrounds hide who is who.

Uses LibForever-1.0 (fetched by the packager, see `.pkgmeta`). MIT licence.

The Grudgekeeper's voice calling out each kill spree tier (`Media/voice_*.mp3`), and the sound effects and
fanfares the spree effects play (`Media/sfx/*.mp3`), were made with [ElevenLabs](https://elevenlabs.io).
The heavier sounds - bells, horns, rock, chains and blades - are the game's own, played from the client's files
by their number, so none of them ships with the addon.
