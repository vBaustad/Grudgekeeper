# Grudgekeeper

World PvP score-keeping for WoW: Forever: who you killed, who killed you and how often, a guild
leaderboard, and kill orders with a bounty on them.

- `/grudge` opens the window: kill orders, the leaderboard, who has killed the guild most, your grudges, the
  guild's news and your own page. Letters and the settings are the two red buttons beside the X.
- The kill orders page lists the open orders: those with gold first, the biggest first, then those with
  none, the newest first, with how long ago each was posted. The guild on watch is the line under the title.
- Where a page shows two things - this week or all time, who killed us most or the guild on watch, all the
  news or only the kill orders - tabs under the title switch between them.
- `/grudge post` writes a kill order on your target, or asks who when you have none. Posted on someone
  you saw a moment ago, it tells the guild where: the zone, and their pin on the world map.
- Each page of the window that you can add to has its action at the top - **Post a kill order**, **Put
  someone on Shame** and **Give someone kudos**. It asks who:
  your target, the enemies you met lately, your group and who just left it, or a name you type. Where a list
  has column headings, click one to sort by it; the kill orders page keeps its own order.
- **Grudges** puts who you owe first: the enemies you track, then those who lead over you, the one you owe
  most first ("owed 3"), and under a faint line those you stand even with and those you lead. Kill one who
  killed you since you last got them and Revenge is told on screen, with where the two of you stand. Kill one
  who still leads over you again and a toast says where you stand now ("Grudge: ... now 2 - 3"), or that you
  are even.
- **Track someone** at the top of your Grudges, or **Track** in the right-click menu on an enemy: your own
  list of enemies to keep an eye on, never shared. One of them near warns you and wears an eye over their
  nameplate.
- Kill sprees: your kills worth points in a row are called out at 3, 5, 7, 10 and 15 and every five after,
  yours and your guildies', as a big splash or a small toast, each where you put it with Arrange on screen -
  each tier with an effect and sounds of its own. `/grudge spree` shows a sample of both, and `/grudge spree
  merciless` (or bloodied, butcher, smoke, scythe, grudgebound, 20, 100, ended, tormentor, revenge) that one's
  splash, and `/grudge spree grudge` a grudge evened up. Each milestone is a line in the News as well, with a spree an enemy ended and a tormentor put down.
- Settings, **Notifications** holds every splash and toast: your own and your guildies' side by side, each a
  splash, a toast or off. The warnings, who is near or joins your group, are on **Warnings**. **All of it**, **Big moments** and
  **Quiet** set them all at once (Quiet: your own as small toasts, nothing from guildies). A guildie's sprees
  and titles have a threshold, and can be held to your zone. Every sound is on **Sounds**, where your
  guildies' can be switched off.
- A kill order fulfilled is told the same way - yours as a splash, with the bounty - and it is in the News's
  Kill orders tab, and for a day first on the guild window's tab: who got them, where and when.
- `/grudge options` opens the settings, a page of the ledger with its tabs still under it. **Arrange on screen** there, or
  `/grudge arrange`, lets you drag the letter icon, the splash and the toasts where you want them.
- `/grudge test` puts five sample letters in your pile.
- The **You** tab is your own page: your card, and your latest kills, assists and deaths.
- Right-click a player on your side and pick **Grudgekeeper profile**: their profile in a window of its own -
  title, points, kills and deaths - with the way to the ledger under it. A player outside your guild is asked
  for theirs as it opens, and it fills in when they answer. On an enemy the line is **Grudge file**: what your
  guild knows of them. **Post a kill order** is right below it, and for an officer **Watch their guild**
  when they are in one: the guild watches one enemy guild at a time, and anyone from it warns whoever
  comes across them. `/grudge guild` puts a guild on watch by its name, for one nobody has met lately.
- While a guild is on watch, **Most wanted** has a tab for it: up to 25 of theirs who fought us, how often we
  killed them and how often they killed us, and the score of them all, as far as your client heard. The line under the kill orders page's title
  says the score too. A player counts once we know they are in that guild - seen with it while it is on watch,
  or named so by a guildie - and so do the kills and deaths against them your client heard of before.
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

Forever closes the combat log to addons. Grudgekeeper counts what the client does hand over: your
group's killing blows (`PARTY_KILL`), an enemy player's death when someone else finished them (`UNIT_DIED`),
the game's damage meter once a fight is over (for assists), the
death recap, and the enemy players you can see (nameplates, target, mouseover). Open world only - instances and battlegrounds hide who is who.

Uses LibForever-1.0 (fetched by the packager, see `.pkgmeta`). MIT licence.

The Grudgekeeper's voice calling out each kill spree tier (`Media/voice_*.mp3`), and the sound effects and
fanfares the spree effects play (`Media/sfx/*.mp3`), were made with [ElevenLabs](https://elevenlabs.io).
The heavier sounds - bells, horns, rock, chains and blades - are the game's own, played from the client's files
by their number, so none of them ships with the addon.
