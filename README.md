# Grudgekeeper

World PvP score-keeping for WoW: Forever: who you killed, who killed you and how often, a guild
leaderboard, and kill orders with a bounty on them.

- `/grudge` opens the window: kill orders, the leaderboard, who has killed the guild most, your grudges, the
  guild's news and your own page. Letters and the settings are the two red buttons beside the X.
- The kill orders page lists the open orders: those with gold first, the biggest first, then those with
  none, the newest first, with how long ago each was posted. The guild on watch is the line under the title.
- Where a page shows two things - this week or all time, who killed us most or whom the guild marked, all the
  news or only the kill orders - tabs under the title switch between them.
- `/grudge post` writes a kill order on your target, or asks who when you have none. Posted on someone
  you saw a moment ago, it tells the guild where: the zone, and their pin on the world map.
- Each page of the window that you can add to has its action at the top - **Post a kill order**, **Put
  someone on Shame**, **Give someone kudos**, and **Mark someone** on Most wanted's Marked tab. It asks who:
  your target, the enemies you met lately, your group and who just left it, or a name you type. Where a list
  has column headings, click one to sort by it; the kill orders page keeps its own order.
- **Track someone** at the top of your Grudges, or **Track** in the right-click menu on an enemy: your own
  list of enemies to keep an eye on, never shared. One of them near warns you and wears an eye over their
  nameplate.
- Kill sprees: your kills worth points in a row are called out at 3, 5, 7, 10 and 15 and every five after,
  yours and your guildies', as a splash in the middle of the screen or a small toast by the letter icon -
  each tier with an effect and sounds of its own. `/grudge spree` shows a sample of both, and `/grudge spree
  merciless` (or bloodied, butcher, smoke, scythe, grudgebound, 20, 100, ended, tormentor) that one's
  splash. The settings say how long they show, and each milestone is a line in the News as well, with a
  spree an enemy ended and a tormentor put down.
- A kill order fulfilled is told the same way - yours as a splash, with the bounty - and it is in the News's
  Kill orders tab, and for a day first on the guild window's tab: who got them, where and when.
- `/grudge options` opens the settings, a page of the ledger with its tabs still under it. **Arrange on screen** there, or
  `/grudge arrange`, lets you drag the letter icon, the splash and the toasts where you want them.
- `/grudge test` puts five sample letters in your pile.
- The **You** tab is your own page: your card, and your latest kills, assists and deaths.
- Right-click a player and pick **Grudgekeeper profile**: the ledger opens on them - a wanted poster for an
  enemy, the record of a guildie. On an enemy, **Post a kill order** is right below it, and for an officer **Watch their guild**
  when they are in one: the guild watches one enemy guild at a time, and anyone from it warns whoever
  comes across them. `/grudge guild` puts a guild on watch by its name, for one nobody has met lately.
- A grudge that is wrong goes with **Forget grudge** on that player's card (two clicks): your record of
  them, here and in the guild's lists. Your score stays.
- Inspect a guildie and the **Grudgekeeper** tab below the game's own shows their page of the ledger.
- On the guild window, the **Grudgekeeper** tab under the game's own turns the window into a page of the
  ledger: you this week, the biggest kill orders, the leaderboard, and guild chat to read and write in.
  Click one of the game's tabs to have the guild window back.
- Right-click any player and pick **Grudgekeeper notes**: a note on them, or put them on Marked, Shame or
  Kudos with a tag. `/grudge note`, `/grudge shame` and `/grudge kudos` do the same from chat. The notes
  came from Guild Grudge, by dakristia; `/grudge import` takes over its saved notes.

Forever closes the combat log to addons. Grudgekeeper counts what the client does hand over: your
group's killing blows (`PARTY_KILL`), an enemy player's death when someone else finished them (`UNIT_DIED`),
the game's damage meter once a fight is over (for assists), the
death recap, and the enemy players you can see (nameplates, target, mouseover). Open world only - instances and battlegrounds hide who is who.

Uses LibForever-1.0 (fetched by the packager, see `.pkgmeta`). MIT licence.

The Grudgekeeper's voice calling out each kill spree tier (`Media/voice_*.mp3`), and the sound effects and
fanfares the spree effects play (`Media/sfx/*.mp3`), were made with [ElevenLabs](https://elevenlabs.io).
