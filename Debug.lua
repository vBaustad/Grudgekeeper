-- Grudgekeeper - a TEMPORARY test panel: /grudge debug. Buttons that make things happen, so every part
-- can be tried in game before there are real kills to try it on (the user, 2026-11-04: "lag bare et
-- lite panel som vi fjerner senere"). To remove it: delete this file and its line in the TOC, the
-- OpenDebug line in Core.lua's /grudge, GK.testMode, GK.ReceiveForTest and GK.InvalidateOrders in Guild.lua,
-- and what By mode asks by: GK.probe, GK.Default and GK.NewsForTest.
--
-- While the panel is open nothing leaves this client: no addon message to the guild, no line in guild
-- chat. When it closes - or the game logs out or reloads with it open - your own record and the guild's
-- store are put back exactly as they were when it opened, so nothing the buttons did is kept. Guild chat is
-- the one thing left as it is: it is real chat, and no button makes any.
-- The pretend guildies are Kari and Edvard; the pretend enemies are Pølse Hans and Gærd Balle, of
-- whichever side is not yours. With an enemy player targeted, "your target" is them instead.
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

local panel
local saved            -- { char, store, storeTable } while testing
local Preview = {}     -- By mode, further down

local function Say(text) print(GK.TAG .. " (test): " .. text) end

-- ---------------------------------------------------------------------------
-- Test mode: nothing sent, everything put back
-- ---------------------------------------------------------------------------
local function Begin()
    if GK.testMode or not GK.char then return end
    local store = GK.Store()
    saved = { char = CopyTable(GK.char), store = CopyTable(store), storeTable = store }
    GK.testMode = true
end

local function PutBack(into, from)
    wipe(into)
    for k, v in pairs(from) do into[k] = v end
end

local function Restore()
    if Preview.Leave then Preview.Leave() end        -- nothing of a run still to come
    if GK.PreviewOwed then GK.PreviewOwed(false) end  -- nor the debt's card
    -- not ours to put back: test mode with nothing saved here is the screenshot mode's (Shots.lua)
    if not (GK.testMode and saved) then return end
    GK.testMode = false
    if saved then
        -- the guild window's page (GuildTab.lua) holds the very table it adds guild chat to: put back as a copy,
        -- every line heard after the panel closed went to a table no longer saved, gone at the next login
        local chat = GK.char.guildChat
        PutBack(GK.char, saved.char)
        GK.char.guildChat = chat
        PutBack(saved.storeTable, saved.store)
        saved = nil
    end
    GK.InvalidateOrders()
    GK.CloseLetters()
    GK.NoticeUpdate(false)
    GK.Changed()
    Say("your record and the guild's are back as they were before the test panel.")
end

--- The panel hid: put back. The game hiding its whole interface (Alt-Z) hides it with its parent: it is still
--- shown, and still the test, and nothing it does may go to the guild.
local function Hidden()
    if panel and panel:IsShown() then return end
    Restore()
end

-- ---------------------------------------------------------------------------
-- Pretend players
-- ---------------------------------------------------------------------------
local function Enemy(name, class)
    local horde = UnitFactionGroup("player") == "Horde"
    return { key = GK.KeyOf(name), c = class, r = horde and "Human" or "Orc",
        l = math.min(60, (UnitLevel("player") or 1) + 1) }
end

--- Your target when it is an enemy player, else Pølse Hans.
local function TheEnemy()
    local t = GK.ReadUnit("target")
    if t then
        t.unit = "target"
        return t
    end
    return Enemy("Pølse Hans", "ROGUE")
end

local function Guildie(name) return GK.KeyOf(name) end

--- A message from a pretend guildie, through the same reader as a real one.
local function Hear(who, ...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        parts[i] = v == nil and "" or tostring(v)
    end
    GK.ReceiveForTest(nil, table.concat(parts, ";"), "GUILD", Guildie(who))
end

--- A guild's store with nothing in it.
local function EmptyStore(s)
    wipe(s)
    s.board, s.orders, s.wanted, s.slain, s.tormentors, s.feed, s.people, s.nextId = {}, {}, {}, {}, {}, {}, {}, 1
end

--- The sample letters open on their kill order: the pile holds it and the Grudgekeeper's own letters, so
--- both kinds are a click of the arrows apart. Made once; read again after that.
-- A first look, as a player who just installed it sees it, in a guild where nobody else has it ("trenger en
-- 'helt fresh addon, no guildies have it' test også", the owner, 2026-11-20): your record starts at nothing
-- and the guild's store is empty while the panel is open - closing it puts both back - and the guild's
-- messages wait outside, as for every button here. Your settings stay as they are.
local function FreshStart()
    local c, s = GK.char, GK.Store()
    local fresh = GK.FreshChar()
    wipe(c)
    for k, v in pairs(fresh) do c[k] = v end
    EmptyStore(s)
    GK.InvalidateOrders()
    GK.CloseLetters()
    GK.NoticeUpdate(false)
    GK.OpenWindow(1)
end

local function ReadSamples()
    local any
    for _, L in ipairs(GK.char.letters) do
        if L.sample then any = true end
    end
    if not any then GK.SampleLetters() end
    for i, L in ipairs(GK.char.letters) do
        if L.sample and L.kind == "order" then return GK.ShowLetter(i) end
    end
    GK.OpenLetters()
end

local KARI_ORDER = 901

--- Kari's and Edvard's scores, as their clients send them: the leaderboard, their cards and Kari's profile.
local function Scores()
    local week = GK.WeekId()
    Hear("Kari", "B", 1, 47, 31, 12, 40, "MAGE", 14, 9, 2, week, 4, 11, 4, 850000,
        Enemy("Pølse Hans").key, 6)
    Hear("Edvard", "B", 1, 23, 15, 20, 38, "WARRIOR", 5, 3, 4, week, 0, 6, 1, 20000,
        Enemy("Gærd Balle").key, 3)
end

-- A warning as its row on Settings, Warnings would tell it, with the words the game uses (Sightings.lua,
-- NotesUI.lua): for that moment the row is its own way, so it comes whatever yours says.
local WARN_WAY = { alertNear = "screen", watchGroup = "screen", kudosGroup = "chat", targetedBy = "screen" }
local function Warning(key, text, urgent, ownSound, target)
    local was = GK.db[key]
    GK.db[key] = WARN_WAY[key]
    GK.WarnAs(key, text, urgent, ownSound, target, target)
    GK.db[key] = was
end

-- The panel as Grudgekeeper is now (2026-11-20): "test panelet er fult av gamle toasts og splashes og
-- animations. og mye gammel testeknapper, oppdater hele" (the owner). Gone: a mark that was a kill order, the
-- letter icon's own mover (Arrange on screen has it), a warning in no row's words, and the research buttons.
-- { label } is a heading; { label, fn } a button.
local ACTIONS = {
    { "Windows" },
    { "Open the ledger", function() GK.OpenWindow(1) end },
    { "Settings", function() GK.OpenOptions() end },
    { "Arrange on screen", function() GK.OpenMover() end },
    { "Kari's profile", function()
        Scores()
        GK.ShowProfile({ kind = "record", key = Guildie("Kari") })
    end },
    { "Your target's grudge file", function() GK.ShowPoster(TheEnemy()) end },
    { "Fresh, no guildies", function() FreshStart() end },
    { "Patch notes", function() GK.OpenPatchNotes() end },

    { "Letters" },
    { "Sample letters", function() GK.SampleLetters() end },
    { "Read the sample letters", ReadSamples },

    { "You" },
    { "Kill your target", function() GK.RecordKill(TheEnemy()) end },
    -- a kill that earns the revenge point: they killed you twice since you last got them (Kills.lua)
    { "Revenge on your target", function()
        local v = TheEnemy()
        local f = GK.Foe(v.key, { n = GK.Show(v.key), c = v.c, r = v.r, l = v.l })
        f.d, f.lastDeath = (f.k or 0) + 2, time() - 60
        GK.RecordKill(v)
    end },
    { "Die to your target", function()
        local v = TheEnemy()
        v.spell = "Ambush"
        GK.RecordDeath(v)
    end },
    { "A rampage: 3 of us dead", function()
        -- Gærd Balle kills Kari and Edvard, then you: the third death posts an order by itself
        local v = Enemy("Gærd Balle", "HUNTER")
        Hear("Kari", "D", 1, v.key, v.c, v.r, v.l, GK.Zone(), 1)
        Hear("Edvard", "D", 1, v.key, v.c, v.r, v.l, GK.Zone(), 1)
        v.spell = "Aimed Shot"
        GK.RecordDeath(v)
    end },
    { "You owe a bounty", function()
        -- your own order, fulfilled by Edvard: the card of what you owe, shown now and at a mailbox ("jeg vil også ha
        -- en test for 'skylder penger' så jeg kan se hvordan det ser ut, og når jeg åpner mailbox", the owner,
        -- 2026-11-22). Fill in mail leaves the name and the gold empty: Edvard is nobody you owe.
        local o = GK.PostOrder(Enemy("Gærd Balle", "HUNTER"), 50000, "Test: you owe Edvard 5g")
        if o then Hear("Edvard", "F", 1, LIB.Me(), o.id, GK.Zone()) end
        GK.PreviewOwed(true)
        Say("to one of your own characters, for money you say, written in full: /grudge owe First Surname 50c")
    end },

    { "The guild" },
    { "Kari posts an order", function()
        local v, now = TheEnemy(), time()
        Hear("Kari", "C", 1, KARI_ORDER, v.key, v.c, v.r, v.l, v.guid, 200000, now, now + 7 * GK.DAY, "o", nil,
            "Camps the flight master.")
    end },
    { "Edvard adds 5g to it", function() Hear("Edvard", "T", 1, Guildie("Kari"), KARI_ORDER, 50000) end },
    { "Edvard saw them here", function()
        -- A sighting lands only on an open order: without Kari's, nothing is placed, and the line below
        -- used to send you to the map anyway.
        local o = GK.Store().orders[Guildie("Kari") .. "#" .. KARI_ORDER]
        if not (o and o.state == "o") then
            Say("there is no open order to see them for - press Kari posts an order first.")
            return
        end
        local ok, m, x, y = pcall(LIB.MyPosition)
        if not (ok and m) then
            Say("the game gives no map position here (indoors, or an instance).")
            return
        end
        Hear("Edvard", "S", 1, Guildie("Kari"), KARI_ORDER, GK.Zone(), TheEnemy().l, m,
            math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5))
        if not (o.seen and o.seen.m) then
            Say("the sighting didn't land on Kari's order.")
            return
        end
        -- the panel's own Restore takes the order away again, and its seal with it
        Say(("open the map (M): the seal is where you stand (map %d, %.1f, %.1f), for 15 minutes "
            .. "- while this panel stays open."):format(m, x * 100, y * 100))
    end },
    { "Edvard fulfils it", function() Hear("Edvard", "F", 1, Guildie("Kari"), KARI_ORDER, GK.Zone()) end },
    { "Kari and Edvard's scores", Scores },
    -- What a login missed (Guild.lua, SayMissed), to see alone: Kari's and Edvard's own kills and deaths since you
    -- were last on, and a count against the guild on watch - in the News, on Versus with a guild on watch, and none
    -- of it announced ("jeg vil teste og se selv ... uten hjelp fra andre", the owner, 2026-11-24).
    { "They answer your login", function()
        local now, v, w = time(), Enemy("Pølse Hans", "ROGUE"), Enemy("Gærd Balle", "HUNTER")
        local watched = GK.WatchedGuild and GK.WatchedGuild()
        local guild = watched or "Bloodfang"
        Hear("Kari", "G", 1, "K", v.key, v.c, v.r, v.l, GK.Zone(), now - 25 * 60, guild, 2, 6)
        Hear("Edvard", "G", 1, "D", w.key, w.c, w.r, w.l, GK.Zone(), now - 50 * 60, guild, 1)
        Hear("Kari", "V", 1, w.key, w.c, w.r, w.l, guild, 3, 1)
        GK.OpenLedgerPage("News")
        Say(("Kari and Edvard answered your login: two fights you missed, in the News%s."):format(
            watched and " and on Versus" or ""))
    end },

    -- the rows of Settings, Warnings, in its order, and the tracked enemy's, which has no row
    { "Warnings" },
    { "Kill order target near", function()
        local v = TheEnemy()
        Warning("alertNear", ("%s is near!"):format(GK.Show(v.key)), true, nil, v.key)
    end },
    { "Death Note: enemy near", function()
        local v = TheEnemy()
        GK.Warn(("Death Note: %s is near!"):format(GK.Show(v.key)), true, nil, v.key, v.key)
    end },
    { "Shame player joins", function()
        Warning("watchGroup", ("Shame list: %s joined your group"):format("Edvard"), true, true)
    end },
    { "Kudos player joins", function()
        Warning("kudosGroup", ("|cff4dff66Kudos:|r %s joined your group"):format("Edvard"), false)
    end },
    { "Death Note: targets you", function()
        local v = TheEnemy()
        Warning("targetedBy", ("Death Note: %s is targeting you!"):format(GK.Show(v.key)), true, true, v.key)
        GK.TargetSound()
    end },
}
GK.debugActions = ACTIONS    -- for tools/smoke_grudgekeeper.py, which presses every one

-- ---------------------------------------------------------------------------
-- What players hear: each splash and toast, down the right
-- ---------------------------------------------------------------------------
-- "jeg vil ha lydene som når det popper opp splash/toasts .. det er vel det folk hører" (the owner,
-- 2026-11-18). Each button fires the event the game fires (Kills.lua, Guild.lua), so Announce.lua makes the
-- splash or toast as it makes a real one: its effect, its sounds and its voice. For that moment the kind's
-- setting is the one the button is listed under and when is "always", so it comes now whatever yours say;
-- then yours are back. A guildie's comes whatever its threshold and zone say, and with its sound (the
-- Guildies page, 2026-11-20). With Play sounds off on Mine yours are silent, and so is one whose box is off.
local HELD = { "spreeMine", "spreeGuild", "spreeGuildFrom", "rankMine", "rankGuild", "rankGuildFrom", "orderMine",
    "orderDone", "spreeEnded", "spreeEndedGuild", "spreeTormentor", "spreeTormentorGuild", "guildZoneOnly",
    "guildSounds", "announceWhenMine", "announceWhenGuild", "revengeMine", "revengeGuild", "grudgeMine" }

local function Announce(set, event, ...)
    local was = {}
    for _, k in ipairs(HELD) do was[k] = GK.db[k] end
    GK.db.announceWhenMine, GK.db.announceWhenGuild = "always", "always"
    GK.db.spreeGuildFrom, GK.db.rankGuildFrom, GK.db.guildZoneOnly, GK.db.guildSounds = 3, 0, false, true
    for k, v in pairs(set) do GK.db[k] = v end
    LIB.Fire(event, ...)        -- its listeners run at once (LibForever), so the settings above are what they read
    for _, k in ipairs(HELD) do GK.db[k] = was[k] end
    if GK.db.mineSounds == false then Say("Play sounds is off on Mine, so yours are silent.") end
end

local function Spree(mine, n, set)
    local tier, key = GK.SpreeTierOf(n)
    set = set or {}
    set[mine and "spreeMine" or "spreeGuild"] = mine and "splash" or "toast"
    Announce(set, "GK_SPREE", mine and LIB.Me() or Guildie("Kari"), n, tier, mine, key)
end

local function OrderDone(mine, pot)
    -- the order's class goes with it, as Guild.lua's does: the poster's face falls back to their class crest. Gold
    -- in its pot brings the purse down on the poster, none the stamp (FxOrders.lua)
    local v = TheEnemy()
    Announce(mine and { orderMine = "splash" } or { orderDone = "toast" }, "GK_ORDER_DONE",
        mine and LIB.Me() or Guildie("Kari"), {}, v.key, pot or 50000, mine, v.c)
end

local function Revenge(mine)
    -- the enemy's key and class go with it, as Kills.lua's and Guild.lua's do: their face in the ring
    local v = TheEnemy()
    Announce(mine and { revengeMine = "splash" } or { revengeGuild = "toast" }, "GK_REVENGE",
        mine and LIB.Me() or Guildie("Kari"), GK.Show(v.key), mine and 3 or 1, mine and 5 or 2, mine, v.key, v.c)
end

--- A grudge evened up (Kills.lua): your target still leads 3 to 2, or you are even, 3 - 3.
local function Grudge(even)
    local v = TheEnemy()
    Announce({ grudgeMine = "toast" }, "GK_GRUDGE", GK.Show(v.key), even and 3 or 2, 3, v.key, v.c)
end

--- A kill on your Death list (Kills.lua): the eye, as a splash.
local function DeathListKill()
    local v = TheEnemy()
    Announce({ grudgeMine = "splash" }, "GK_GRUDGE", GK.Show(v.key), 1, 0, v.key, v.c, true)
end

local function NewTitle(mine, title, points)
    Announce(mine and { rankMine = "splash" } or { rankGuild = "toast" }, "GK_RANKUP",
        mine and LIB.Me() or Guildie("Kari"), title or "Avenger", points or 450, mine)
end

local function Ended(mine)
    Announce(mine and { spreeEnded = "splash" } or { spreeEndedGuild = "toast" }, "GK_SPREE_ENDED",
        mine and LIB.Me() or Guildie("Kari"), 12, GK.Show(TheEnemy().key), mine)
end

local function Tormentor(mine)
    Announce(mine and { spreeTormentor = "splash" } or { spreeTormentorGuild = "toast" }, "GK_TORMENTOR",
        mine and LIB.Me() or Guildie("Kari"), GK.Show(TheEnemy().key), 4, mine)
end

-- The rows of Settings, Mine and Guildies, in their order: yours as splashes, each with its effect - a spree ended and
-- a tormentor too, which come as toasts out of the box: their splashes are dakristia's shatter and the grudge book
-- slamming down (T4, 2026-11-21), and as toasts the panel showed neither ("hvorfor er det ikke den animasjonen som
-- kom fra daniel hvor streaken knuses?", the owner, 2026-11-20) - then a guildie's, Kari's, as toasts. Each tier of a spree has its own
-- effect and voice; Reaper's is the scythe. The smoke had a button of its own until the
-- scythe became Reaper's (2026-11-20).
-- { label } is a heading; { label, fn } a button.
local HEAR = {
    { "Yours" },
    { "Bloodied, 3", function() Spree(true, 3) end },
    { "Merciless, 5", function() Spree(true, 5) end },
    { "Butcher, 7", function() Spree(true, 7) end },
    { "Reaper, 10", function() Spree(true, 10) end },
    { "Grudgebound, 15", function() Spree(true, 15) end },
    { "Grudgebound, 20", function() Spree(true, 20) end },
    { "100 in a row", function() Spree(true, 100) end },
    { "A new title", function() NewTitle(true) end },
    -- a kill order fulfilled: its target's WANTED poster (FxOrders.lua), their face if you have them targeted
    { "A kill order fulfilled", function() OrderDone(true) end },
    { "Kill order, no gold", function() OrderDone(true, 0) end },
    -- their face struck in the ring (FxRevenge.lua), your target's if you have one
    { "Revenge", function() Revenge(true) end },
    -- one who still led over you, got again: where you stand, or even (Announce.lua, GK_GRUDGE)
    { "A grudge, still owed", function() Grudge(false) end },
    { "A grudge evened up", function() Grudge(true) end },
    { "A Death Note kill", DeathListKill },
    { "A spree ended", function() Ended(true) end },
    { "A tormentor put down", function() Tormentor(true) end },
    { "Kari's" },
    { "Kari's kill spree", function() Spree(false, 10) end },
    { "Kari's new title", function() NewTitle(false) end },
    { "Kari's kill order", function() OrderDone(false) end },
    { "Kari's order, no gold", function() OrderDone(false, 0) end },
    { "Kari's revenge", function() Revenge(false) end },
    { "Kari's spree ended", function() Ended(false) end },
    { "Kari's tormentor", function() Tormentor(false) end },
}
GK.debugHear = HEAR          -- for tools/smoke_grudgekeeper.py

-- Every one, and every title (2026-11-21: "legg til muligheten for å teste alle ranks, alle splash, alle toasts.
-- det trengs å testes in game", the owner). Yours queue as real splashes do, each when the one before it has had
-- its time; Kari's toasts come TOAST_GAP apart, as only four show at once. Each title has a button of its own:
-- yours as a splash and Kari's as a toast together, its emblem in both (FxTitles.lua).
local TOAST_GAP = 2.5

--- Every button under a heading of HEAR, in its order: at once (splashes queue), or toasts TOAST_GAP apart.
local function Every(heading, toasts)
    local fns, under = {}, false
    for _, a in ipairs(HEAR) do
        if not a[2] then under = a[1] == heading elseif under then fns[#fns + 1] = a[2] end
    end
    for i, fn in ipairs(fns) do
        if toasts then C_Timer.After((i - 1) * TOAST_GAP, function() pcall(fn) end) else fn() end
    end
    return #fns
end

--- Every title past the first: yours as splashes, one after another, or Kari's as toasts TOAST_GAP apart.
local function EveryTitle(mine)
    local n = 0
    for _, row in ipairs(GK.TITLES) do
        if row[1] > 0 then
            local title, points = row[2], row[1]
            if mine then NewTitle(true, title, points)
            else C_Timer.After(n * TOAST_GAP, function() pcall(NewTitle, false, title, points) end) end
            n = n + 1
        end
    end
    return n
end

local ALL = {
    { "Every one" },
    { "Every splash of yours", function() Every("Yours", false) end },
    { "Every toast of Kari's", function() Every("Kari's", true) end },
    { "Every title" },
    { "Every title, yours", function() EveryTitle(true) end },
    { "Every title, Kari's", function() EveryTitle(false) end },
    { "Each title" },
}
for _, row in ipairs(GK.TITLES) do
    if row[1] > 0 then
        local title, points = row[2], row[1]
        ALL[#ALL + 1] = { ("%s, %d"):format(title, points), function()
            NewTitle(true, title, points)
            NewTitle(false, title, points)
        end }
    end
end
GK.debugAll = ALL            -- for tools/smoke_grudgekeeper.py

-- ---------------------------------------------------------------------------
-- By what you see: each splash, toast and letter one choice of Quick setup lets through, once each
-- ---------------------------------------------------------------------------
-- "jeg tenkte en ting likt som show all splashes men som viste kun de forskjellige splash/toasts/brev som dukker opp i
-- hver mode" (the owner, 2026-11-22). Every one above forces the settings; here each moment happens through the
-- game's own path (Kills.lua, Guild.lua's reader) with the mode's settings, and GK.probe says first what it would
-- show. A guildie's kill order comes as a stranger's with gold where the mode lets that through, else about you.
-- The settings are the mode's only for the moment itself: yours are back before anything is drawn. In a block: the
-- file's locals.
do
    local SETTINGS = { "anyLetters", "letters", "myLetters", "keepLetters", "share", "shareOutside", "autoOrders",
        "alertNear", "watchNearby", "watchGroup", "kudosGroup", "targetedBy", "plateMarks", "plateNotes", "mapPins", "mode",
        "spreeMine", "spreeGuild", "spreeGuildFrom", "rankMine", "rankGuild", "rankGuildFrom", "orderMine",
        "orderDone", "spreeEnded", "spreeEndedGuild", "spreeTormentor", "spreeTormentorGuild", "revengeMine",
        "revengeGuild", "grudgeMine", "guildZoneOnly", "announceWhenMine", "announceWhenGuild", "announceTime",
        "mineSounds", "guildSounds", "warnSounds", "spreeSound", "spreeSoundGuild", "rankSound", "rankSoundGuild",
        "orderSound", "orderSoundGuild", "revengeSound", "revengeSoundGuild", "grudgeSound", "endedSound",
        "endedSoundGuild", "tormentorSound", "tormentorSoundGuild", "nearSound", "shameSound", "targetSound", "shotFulfil",
        "shotEveryKill" }
    -- set: over the settings as installed; none: the player's own. By What you see's choices since 2026-11-24
    -- (GK.SEE): what you share turns nothing down any more, so Normal, Streamer and Private showed the same.
    local MODES = {}
    for i, c in ipairs(GK.SEE) do MODES[i] = { id = c.id, name = c.name, set = c.rows } end
    MODES[#MODES + 1] = { id = "yours", name = "Your settings" }
    local SHOWN = { splash = true, toast = true, letter = true }
    local GAP = { splash = 1.5, toast = 2.5, letter = 0.5 }     -- a splash waits for itself as well (Step)
    local GUILDIE, OTHER = "Kari", "Edvard"          -- the guildie whose moments they are, and one more
    local ID, GOLD_ON_IT = 7701, 50000
    local run, played

    -- -----------------------------------------------------------------------
    -- Each moment, made to happen
    -- -----------------------------------------------------------------------
    local function Them() return Enemy("Pølse Hans", "ROGUE") end

    local function Board(who, points)
        Hear(who, "B", 1, points, 31, 12, 40, who == OTHER and "WARRIOR" or "MAGE", 0, 0, 0, GK.WeekId())
    end

    local function TheirKill(who, spree, revenge)
        local v = Them()
        Hear(who, "K", 1, v.key, v.c, v.r, v.l, GK.Zone(), 1, nil, revenge and 3 or 1, nil, nil, spree,
            revenge and 1 or nil, revenge and 4 or nil)
    end

    local function TheirDeath(who)
        local v = Them()
        Hear(who, "D", 1, v.key, v.c, v.r, v.l, GK.Zone(), 1)
    end

    local function Posts(who, gold)
        local v, now = Them(), time()
        Hear(who, "C", 1, ID, v.key, v.c, v.r, v.l, nil, gold or 0, now, now + 7 * GK.DAY, "o", nil,
            "Camps the flight master.")
    end

    --- Them, on who killed you: an order on them is about you.
    local function KilledYou(k, d, killedLast)
        local v = Them()
        local f = GK.Foe(v.key, { n = GK.Show(v.key), c = v.c, r = v.r, l = v.l })
        local now = time()
        f.k, f.d = k or 0, d or 1
        f.lastKill, f.lastDeath = killedLast and now - 30 or now - 7200, now - 600
        return f
    end

    local function YouKill() GK.RecordKill(Them()) end

    local function YouDie()
        local v = Them()
        v.spell = "Ambush"
        GK.RecordDeath(v)
    end

    local function YourOrder() return GK.PostOrder(Them(), GOLD_ON_IT, "Test: your order") end

    local function Spree(n) return { setup = function() GK.char.spree = n - 1 end, act = YouKill } end

    --- A guildie's moment: shown by every choice that has the guildie's row on.
    local function Theirs(label, act, setup) return { label, { who = GUILDIE, setup = setup, act = act } } end

    -- { label, a way it happens, another way ... }: the first way the mode lets through is the one played
    local MOMENTS = {
        { "Bloodied, 3", Spree(3) }, { "Merciless, 5", Spree(5) }, { "Butcher, 7", Spree(7) },
        { "Reaper, 10", Spree(10) }, { "Grudgebound, 15", Spree(15) }, { "Grudgebound, 20", Spree(20) },
        { "100 in a row", Spree(100) },
        { "A new title", { setup = function() GK.char.points = 299 end, act = YouKill } },
        { "A kill order fulfilled", { setup = function() Posts(GUILDIE, GOLD_ON_IT) end, act = YouKill } },
        { "Kill order, no gold", { setup = function() Posts(GUILDIE, 0) end, act = YouKill } },
        { "Revenge", { setup = function() KilledYou(1, 3) end, act = YouKill } },
        { "A grudge, still owed", { setup = function() KilledYou(1, 3, true) end, act = YouKill } },
        { "A grudge evened up", { setup = function() KilledYou(1, 2, true) end, act = YouKill } },
        { "A Death Note kill", { setup = function() GK.char.tracked[Them().key] = { t = time() } end, act = YouKill } },
        { "A spree ended", { setup = function() GK.char.spree = 12 end, act = YouDie } },
        { "A tormentor put down", { setup = function() GK.Store().tormentors[Them().key] = 4 end, act = YouKill } },
        { "Your death posts an order", { act = YouDie, setup = function()
            TheirDeath(GUILDIE)
            TheirDeath(OTHER)
        end } },
        { "Your order fulfilled", { setup = YourOrder, act = function()
            for _, o in pairs(GK.Store().orders) do Hear(GUILDIE, "F", 1, LIB.Me(), o.id, GK.Zone()) end
        end } },
        { "A bounty paid to you", { setup = function()
            Posts(GUILDIE, GOLD_ON_IT)
            YouKill()
        end, act = function() Hear(GUILDIE, "Y", 1, Guildie(GUILDIE), ID, LIB.Me()) end } },
        { "Your order runs out", { setup = YourOrder, act = function()
            for _, o in pairs(GK.Store().orders) do o.exp = time() - 1 end
            GK.Sweep()
        end } },
        { "What's new", { act = function() GK.NewsForTest() end } },
        { "A guildie's kill order", { who = GUILDIE, act = function(who) Posts(who, GOLD_ON_IT) end },
            { who = GUILDIE, setup = function() KilledYou() end, act = function(who) Posts(who, 0) end } },
        Theirs("A guildie's kill spree", function(who) TheirKill(who, 10) end),
        Theirs("A guildie's new title", function(who)
            TheirKill(who, 0)
            Board(who, 450)
        end, function(who) Board(who, 449) end),
        Theirs("A guildie's revenge", function(who) TheirKill(who, 0, true) end),
        Theirs("A guildie's spree ended", TheirDeath, function(who) TheirKill(who, 12) end),
        Theirs("A guildie's tormentor", function(who) TheirKill(who, 0) end,
            function() GK.Store().tormentors[Them().key] = 4 end),
    }

    -- -----------------------------------------------------------------------
    -- Asked, then played
    -- -----------------------------------------------------------------------
    local function Take()
        local out = {}
        for _, k in ipairs(SETTINGS) do out[k] = GK.db[k] end
        return out
    end

    local function Put(from)
        for _, k in ipairs(SETTINGS) do GK.db[k] = from[k] end
    end

    --- fn with everything that would show told to probe instead; none: shown.
    local function Through(probe, fn, ...)
        local was = GK.probe
        GK.probe = probe
        local ok, err = pcall(fn, ...)
        GK.probe = was
        if not ok then Say("error: " .. tostring(err)) end
    end

    local function Nothing() end

    --- A pretend record and guild for one moment: no spree, short of every title, its guildie known.
    local function World(letters, who, theirs)
        local c = GK.char
        local blank = GK.FreshChar()
        blank.points, blank.letters = 200, letters or blank.letters
        wipe(c)
        for k, v in pairs(blank) do c[k] = v end
        EmptyStore(GK.Store())
        GK.InvalidateOrders()
        Board(who, 40)
        if theirs then
            TheirKill(who, 0)                       -- and no spree of theirs from a moment before this one
        end
    end

    --- One way of a moment, under a mode's settings: they are the mode's for this call alone. probe: only asked.
    --- letters: the pile it lands on.
    local function Happen(way, set, probe, letters)
        local own = Take()
        if set then
            for _, k in ipairs(SETTINGS) do GK.db[k] = GK.Default(k) end
            for k, v in pairs(set) do GK.db[k] = v end
        end
        -- now, whatever a fight says: when it comes is not what this shows. And no screenshot of a kill that wasn't.
        for _, k in ipairs({ "announceWhenMine", "announceWhenGuild" }) do GK.db[k] = "always" end
        GK.db.shotFulfil, GK.db.shotEveryKill = false, false
        Through(Nothing, World, letters, way.who or GUILDIE, way.who ~= nil)
        if way.setup then Through(Nothing, way.setup, way.who) end
        GK.InvalidateOrders()
        Through(probe, way.act, way.who)
        Put(own)
    end

    --- What a mode lets through: { { label, way, got = { how, ... } } } and the count of each kind.
    local function Plan(m)
        local c, s = GK.char, GK.Store()
        local char, store = {}, {}
        -- their own tables, not copies: each moment's world makes tables of its own (World)
        for k, v in pairs(c) do char[k] = v end
        for k, v in pairs(s) do store[k] = v end
        local plan, count = {}, { splash = 0, toast = 0, letter = 0 }
        for _, moment in ipairs(MOMENTS) do
            for i = 2, #moment do
                local got = {}
                Happen(moment[i], m.set, function(how) if SHOWN[how] then got[#got + 1] = how end end)
                if #got > 0 then
                    plan[#plan + 1] = { label = moment[1], way = moment[i], got = got }
                    for _, how in ipairs(got) do count[how] = count[how] + 1 end
                    break
                end
            end
        end
        PutBack(c, char)
        PutBack(s, store)
        GK.InvalidateOrders()
        GK.NoticeUpdate(false)
        return plan, count
    end

    local function Step(r)
        if run ~= r then return end
        -- a splash has its whole time: the next one waits for it
        if r.at > 0 and r.waited < 60 and GK.AnnouncementsWaiting() then
            r.waited = r.waited + 1
            C_Timer.After(0.5, function() Step(r) end)
            return
        end
        r.at, r.waited = r.at + 1, 0
        local entry = r.plan[r.at]
        if not entry then
            run = nil
            -- the letters last, to read: they came by the icon as each moment happened
            if #GK.char.letters > 0 and r.letters > 0 then GK.ShowLetter(1) end
            return
        end
        local gap = 0
        for _, how in ipairs(entry.got) do gap = math.max(gap, GAP[how] or 0) end
        -- the letters of the moments before it stay in the pile
        Happen(entry.way, r.set, nil, r.at > 1 and GK.char.letters or nil)
        played = true
        GK.Changed()
        C_Timer.After(gap, function() Step(r) end)
    end

    --- Play one mode's: what plays already stops.
    local function Play(m)
        if not GK.testMode then return end
        run = nil
        if played then GK.HideAnnouncements() end         -- what the one before was showing
        local plan, count = Plan(m)
        local plural = function(n, word) return ("%d %s%s"):format(n, word, n == 1 and "" or "es") end
        if panel and panel.byMode then
            panel.byMode:SetText(("%s: %s, %d toast%s, %d letter%s"):format(m.name, plural(count.splash, "splash"),
                count.toast, count.toast == 1 and "" or "s", count.letter, count.letter == 1 and "" or "s"))
        end
        run = { plan = plan, at = 0, waited = 0, set = m.set, letters = count.letter }
        Step(run)
        return plan
    end

    -- at the top of the third column: a heading, a button for each, and a line saying what each brought
    table.insert(ALL, 1, { "By what you see" })
    for i, m in ipairs(MODES) do table.insert(ALL, 1 + i, { m.name, function() Play(m) end }) end
    table.insert(ALL, 2 + #MODES, { "", said = true })

    -- for tools/smoke_grudgekeeper.py: what a mode would play, by label
    GK.debugModes = function(id)
        for _, m in ipairs(MODES) do
            if m.id == id then
                local out = {}
                for i, e in ipairs((Plan(m))) do out[i] = e.label end
                return out
            end
        end
    end

    --- Every way out: nothing of a run still to come.
    function Preview.Leave()
        run = nil
        GK.probe = nil
        if played then GK.HideAnnouncements() end
        played = nil
        if panel and panel.byMode then panel.byMode:SetText("") end
    end
end

-- ---------------------------------------------------------------------------
-- The panel
-- ---------------------------------------------------------------------------
local W, BUTTON_W, ROW = 400, 182, 26
local HEAR_W, HEAR_ROW = 150, 22

local function Build()
    panel = CreateFrame("Frame", "GrudgekeeperDebug", UIParent)
    panel:SetPoint("CENTER", -320, 0)
    panel:EnableMouse(true)
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.03, 0.02, 0.94)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Grudgekeeper test panel")
    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 14, -36)
    note:SetWidth(W - 28)
    note:SetJustifyH("LEFT")
    note:SetText("Nothing goes to your guild while this is open. Closing it puts your record and the guild's "
        .. "back as they were (a screenshot taken stays).")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() GK.CloseDebug() end)

    local y, col = -64, 0
    for _, a in ipairs(ACTIONS) do
        if not a[2] then
            if col == 1 then y = y - ROW end
            col = 0
            local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            h:SetPoint("TOPLEFT", 14, y - 6)
            h:SetText(a[1])
            y = y - 26
        else
            local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            b:SetSize(BUTTON_W, 22)
            b:SetPoint("TOPLEFT", 14 + col * (BUTTON_W + 8), y)
            b:SetText(a[1])
            local fn = a[2]
            b:SetScript("OnClick", function()
                local ok, err = pcall(fn)
                if not ok then Say("error: " .. tostring(err)) end
                GK.Changed()
            end)
            col = col + 1
            if col == 2 then
                col = 0
                y = y - ROW
            end
        end
    end
    if col == 1 then y = y - ROW end
    local done = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    done:SetSize(W - 28, 24)
    done:SetPoint("TOPLEFT", 14, y - 10)
    done:SetText("Close and put everything back")
    done:SetScript("OnClick", function() GK.CloseDebug() end)

    -- what players hear, down the right (HEAR above)
    local sy = -64
    panel.hearButtons = {}
    for _, a in ipairs(HEAR) do
        if not a[2] then
            local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            h:SetPoint("TOPLEFT", W, sy - 6)
            h:SetText(a[1])
            sy = sy - 26
        else
            local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            b:SetSize(HEAR_W, 20)
            b:SetPoint("TOPLEFT", W, sy)
            b:SetText(a[1])
            local fn = a[2]
            b:SetScript("OnClick", function()
                local ok, err = pcall(fn)
                if not ok then Say("error: " .. tostring(err)) end
            end)
            panel.hearButtons[a[1]] = b
            sy = sy - HEAR_ROW
        end
    end
    -- every one, and every title, in a third column (ALL above)
    local ax, ay = W + HEAR_W + 12, -64
    for _, a in ipairs(ALL) do
        if a.said then
            panel.byMode = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            panel.byMode:SetPoint("TOPLEFT", ax, ay - 2)
            panel.byMode:SetWidth(HEAR_W)
            panel.byMode:SetJustifyH("LEFT")
            ay = ay - 30
        elseif not a[2] then
            local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            h:SetPoint("TOPLEFT", ax, ay - 6)
            h:SetText(a[1])
            ay = ay - 26
        else
            local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            b:SetSize(HEAR_W, 20)
            b:SetPoint("TOPLEFT", ax, ay)
            b:SetText(a[1])
            local fn = a[2]
            b:SetScript("OnClick", function()
                local ok, err = pcall(fn)
                if not ok then Say("error: " .. tostring(err)) end
            end)
            panel.hearButtons[a[1]] = b
            ay = ay - HEAR_ROW
        end
    end
    panel:SetSize(ax + HEAR_W + 14, math.max(-y + 50, -sy + 14, -ay + 14))
    panel:Hide()
    if LIB.RegisterWindow then LIB.RegisterWindow(panel, GK.db, "debugPanel") end
    -- Closing it any way at all - the X, Escape, the big button - puts everything back.
    panel:HookScript("OnHide", Hidden)
end

-- ---------------------------------------------------------------------------
-- /grudge owe <name> <money>: a debt you can really pay
-- ---------------------------------------------------------------------------
-- The test's debt to a player you name, for the money you say: Fill in mail writes their name and the gold, and a
-- Send pays it as a real one would ("kan vi som test legge inn [a character of mine] som mottaker og 50c som reward?
-- fill in la ikke inn noe", the owner, 2026-11-25). The name is typed in the game, never written here, and the debt
-- goes with everything else when the panel closes; the money you send is real.

--- Money as typed: copper alone ("50"), or numbers with g, s and c ("50c", "5s", "1g20s"). nil for anything else.
local function Copper(text)
    text = (text or ""):lower()
    if text:find("^[0-9]+$") then return tonumber(text) end
    if text == "" or text:gsub("[0-9]+[gsc]", "") ~= "" then return nil end
    local copper, unit = 0, { g = 10000, s = 100, c = 1 }
    for n, u in text:gmatch("([0-9]+)([gsc])") do copper = copper + tonumber(n) * unit[u] end
    return copper
end

--- /grudge owe: only with the test panel open, so the debt goes when it closes.
function GK.TestOwe(text)
    if not (GK.testMode and panel and panel:IsShown()) then
        print(GK.TAG .. ": open the test panel first (/grudge debug) - this debt goes when it closes.")
        return
    end
    local name, money = strtrim(text or ""):match("^(.-) +([^ ]+)$")      -- a chat line holds no tab
    local key, copper = GK.TypedName(name), Copper(money)
    if not (key and copper and copper > 0) then
        Say("a name and the money: /grudge owe First Surname 50c (or 5s, 1g, 1g20s).")
        return
    end
    if key == LIB.Me() then
        Say("that is you - name one of your other characters.")
        return
    end
    local o = GK.PostOrder(Enemy("Gærd Balle", "HUNTER"), copper, "Test: you owe " .. GK.Show(key))
    if not o then return end
    o.testNamed = true
    Hear(key, "F", 1, LIB.Me(), o.id, GK.Zone())
    GK.PreviewOwed(true)
    Say(("you owe %s %s. At a mailbox, Fill in mail writes their name and the gold, and Send really sends it."):format(
        GK.Show(key), GK.MoneyText(copper)))
end

--- /grudge newer: a guildie with a newer Grudgekeeper than ours, as its line in chat reads (Guild.lua,
--- GK.HeardVersion). One newer still each time, so the line comes again.
local newer = 0
function GK.TestNewer()
    local a, b, c = tostring(GK.addonVersion):match("^(%d+)%.(%d+)%.(%d+)$")
    if not a then
        Say("this copy is no release (" .. tostring(GK.addonVersion) .. "), so it hears of none.")
        return
    end
    newer = newer + 1
    GK.HeardVersion(("%d.%d.%d"):format(tonumber(a), tonumber(b), tonumber(c) + newer))
end

--- /grudge debug: open the test panel, and test mode with it.
function GK.OpenDebug()
    if not GK.char then return end
    if GK.shotMode then
        Say("close the screenshot panel first.")
        return
    end
    if not panel then Build() end
    Begin()
    panel:Show()
    panel:Raise()
    Say("test mode on - nothing goes to your guild until you close the panel.")
end

--- Close the panel and put everything back. (Escape hides it without this call: OnHide restores too.)
function GK.CloseDebug()
    if panel then panel:Hide() end
    Restore()
end

-- A reload or logout with the panel open: put everything back before the game saves it.
LIB.On("PLAYER_LOGOUT", Restore)
