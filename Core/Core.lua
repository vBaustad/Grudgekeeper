-- Grudgekeeper - keep score of world PvP: who you killed, who killed you and how often, a guild
-- leaderboard, and kill orders with a bounty on them.
-- Forever closes the combat log to addons, so nothing here watches a fight. Three things the client
-- does hand us are enough:
--   PARTY_KILL         your killing blow (or your pet's), with the victim's GUID      (Kills.lua)
--   the death recap    the name of whoever landed the blow that killed you            (Kills.lua)
--   units you can see  nameplates, your target and your mouse: level, class, race    (Sightings.lua)
-- All three are open in the world and secret in instances and battlegrounds, so Grudgekeeper keeps
-- score of the open world only. The guild hears about it over the addon channel (Guild.lua), and
-- news arrives as a sealed scroll you open when you like (Letters.lua, Notice.lua) - never a popup.
local ADDON, GK = ...
local REAL = LibStub("LibForever-1.0")

-- ---------------------------------------------------------------------------
-- Every player by name alone: "First Last" (2026-11-20)
-- ---------------------------------------------------------------------------
-- Forever names every player "First Last" and nothing more since build 1.60.1.71037 - no realm in any API, the
-- roster or a sender - and its names are unique in the region (the surname is what makes them so). The realm in
-- our keys was noise besides: the owner's file held one player under up to three ("Critical Mango" with
-- CAMWOWEU4Realm4PvP, CAMWOWEU5Realm6PvP and the beta's), whoever wrote them down giving them their own. "hva om vi
-- trimmmer alt bakover, fjerner - og realmnavn, nå kjører vi bare 'fornavn etternavn'?" (the owner). So
-- Grudgekeeper sees LibForever through GK.Lib: the same lib, with every name it gives or takes plain. The other
-- addons keep the lib's "Name-Realm"; the lib is shared, these are ours. The saved data moved once (keys v4).
local Plain = REAL.Plain or function(key)
    if type(key) ~= "string" then return key end
    local name, rest = key:match("^([^%-#]+)%-[^%s#]*(.*)$")
    return name and (name .. rest) or key
end
GK.Plain = Plain

local Lib = setmetatable({}, { __index = REAL })
local me

--- Who I am, "First Last"; kept once the client has said.
function Lib.Me()
    if me then return me end
    local m = REAL.PlainMe and REAL.PlainMe() or Plain(REAL.Me())
    if type(m) == "string" and m ~= "" then me = m end
    return m
end

-- GK.PlayerKey, not Plain: the lib may read a surname as a realm ("Unc-Allayra"), and Plain would keep only "Unc" -
-- every Unc one player (the smoke's two Uncs, 2026-11-20)
function Lib.UnitKey(unit) return GK.PlayerKey(REAL.UnitKey(unit)) end

--- A name as a key: plain, and nil for none.
function Lib.FullName(name)
    if type(name) ~= "string" or name == "" then return nil end
    return GK.PlayerKey(name)
end

--- Our guild by its name alone: its realm went with every other one.
function Lib.GuildKey()
    if IsInGuild and not IsInGuild() then return nil end
    local name = GetGuildInfo and GetGuildInfo("player")
    if type(name) == "string" and name ~= "" then return name end
    local theirs = REAL.GuildKey and REAL.GuildKey()
    return theirs and Plain(theirs) or nil
end

--- The lib keeps its guildies and itself as "Name-Realm" (its realm remembered, LIB.Realm), or by the name alone
--- while it knows no realm: our plain name in the lib's own spelling, whichever that is.
local function Theirs(key) return REAL.FullName(Plain(key)) or "" end

--- Me, whatever realm a key gives me or none - and an old key without my surname, by the lib's own rule.
function Lib.IsMyStoredName(key)
    if type(key) ~= "string" or key == "" then return false end
    local mine = Lib.Me()
    if mine and Plain(key) == mine then return true end   -- asks the lib nothing about realms
    return REAL.IsMyStoredName(Theirs(key))
end

function Lib.KnownGuildie(key)
    return type(key) == "string" and REAL.KnownGuildie(Theirs(key)) or false
end

function Lib.IsOnline(key)
    return type(key) == "string" and REAL.IsOnline(Theirs(key)) or false
end

function Lib.IsGuildie(key)
    return type(key) == "string" and REAL.IsGuildie(Theirs(key)) or false
end

--- A whisper to the name alone, as the client names everyone.
function Lib.WhisperName(key) return Plain(key) end

-- The roster as the lib holds it, asked with a plain name (the lib's table is made anew at each rebuild).
Lib.roster = setmetatable({}, { __index = function(_, key)
    if type(key) ~= "string" then return nil end
    local r = REAL.roster
    return r and r[Theirs(key)]
end })

GK.Lib = Lib
local LIB = Lib

-- The release, from the TOC. Its own name: GK.version is the count of changes (GK.Changed), and was
-- this until 1.4.0 - the settings page and the help said "v" and that count.
GK.addonVersion = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
GK.TAG = "|cffc8281eGrudgekeeper|r"
local TAG = GK.TAG

-- Account settings; the settings page (Options.lua) says what each one does.
local defaults = {
    anyLetters = true,       -- letters at all; off, nothing arrives as one (Letters.lua: Add)
    letters = true,          -- kill orders your guildies post arrive as letters
    myLetters = true,        -- a letter for a kill that earns a title, and a death that posts an order
    keepLetters = false,     -- an unread letter waits by the icon until read; off, it fades after a while (Letters.lua)
    -- The warnings (Settings, Warnings): "screen" by the letter icon, "chat" one line, or "off".
    -- An older saved file holds true or false here: GK.WarnStyle reads true as the row's own way.
    alertNear = "screen",    -- the target of any open kill order is near, or a guildie sees them
    plateMarks = true,       -- a skull over anyone with an open order on them
    -- a screenshot when you fulfil an order: off to begin with, "ikke la screenshots være på ved default"
    -- (the owner, 2026-11-08). Defaults are written into the saved table, so an account that had it on
    -- keeps it on until the box is unticked.
    shotFulfil = false,
    shotEveryKill = false,   -- a screenshot at every kill
    share = true,            -- tell the guild your kills, deaths and score, and where targets are seen
    shareOutside = true,     -- answer a player on your side outside the guild who asks for your score (Profile.lua)
    mode = "normal",         -- What you share: "normal" everything, "streamer" all but where, "private" nothing (GK.Mode)
    autoOrders = true,       -- your death to someone on a rampage or camping you posts a kill order (Guild.lua)
    deathNoteShared = false, -- one Death Note for every character of the account on the same side (GK.TrackedList)
    deathNotes = {},         -- [faction] = { [key] = entry }: those lists (Sightings.lua)
    sound = true,            -- the ledger's and the letters' own sounds (GK.Sound; Settings, Appearance)
    oldPortraits = true,     -- race faces from the old character-creation screen, not today's race icons (GK.SetPortrait);
                             -- on by default, whichever skin (the owner, 2026-11-11)
    tooltip = true,          -- one line on an enemy player's tooltip: your history with them
    guildButton = true,      -- a Grudgekeeper tab among the guild window's own (GuildTab.lua)
    minimap = {},            -- LibDBIcon's own record: where the button sits, whether it is hidden
    mapPins = true,          -- where an order's target was last seen, on the world map
    -- our lines in the game's right-click menu on a player, each its own (Settings, Right-click menu, GK.MENU_LINES)
    menuFile = true, menuOrder = true, menuDeathNote = true, menuGuild = true,
    menuProfile = true, menuShame = true, menuKudos = true, menuNotes = true,
    inspectTab = true,       -- a tab of ours on the game's Inspect window: a guildie's record, an enemy's poster
    sortBy = {},             -- [ledger page name] = the column heading its rows are sorted by (none: the page's own order)
    mineOnly = false,        -- whether the ledger's sortable pages list only the rows that are yours
    watchNearby = "off",     -- a player on your Shame list is near
    watchGroup = "screen",   -- a Shame list player joins your group
    shameSound = "game:566564", -- and the sound it plays (GK.SoundChoices; "off" for none): the Alliance bell
    nearSound = "call:horn_rush", -- the sound of a target near: War horn rush (GK.NearSound; both the owner's, 2026-11-23)
    kudosGroup = "off",      -- a Kudos player joins your group (off: the owner doesn't read chat lines)
    targetedBy = "off",      -- one in your Death Note you can see targets you, out of a fight (Sightings.lua, TargetedBy)
    targetSound = "call:heartbeat", -- and its own sound, short: Heartbeat ("jeg vil ikke ha 10s dark souls musikk
                             -- hver gang noen targeter meg", the owner, 2026-11-24)
    plateNotes = true,       -- a medal per tag over the nameplate of a player on Shame or Kudos
    guilds = {},             -- [guild key] = { board, orders, wanted, slain, feed, nextId } (Guild.lua)
    -- What is told on screen (Announce.lua; Settings, Mine and Guildies), yours and a guildie's each on its own:
    -- yours "off", "toast" or "splash", a guildie's "off" or "toast" - "splash bør være bare for deg, og toast bør
    -- være for guildies" (the owner, 2026-11-22). A guildie's start at the big moments alone, for a new install
    -- and, since 2026-11-20, for an older one (MoveNotifications, below).
    spreeMine = "splash",    -- your spree milestone
    spreeGuild = "toast",    -- a guildie's spree milestone...
    spreeGuildFrom = 10,     -- ...from this many kills in a row, or "round": only 25, 50 and 100
    rankMine = "splash",     -- your new title
    rankGuild = "toast",     -- a guildie's new title...
    rankGuildFrom = 450,     -- ...from a title this many points up (Avenger)
    orderMine = "splash",    -- a kill order you fulfilled, or a guildie did with you there
    orderDone = "toast",     -- a guildie fulfilled a kill order
    spreeEnded = "toast",    -- your spree, ended by an enemy
    spreeEndedGuild = "off", -- a guildie's spree, ended
    spreeTormentor = "toast", -- you put an end to a tormentor
    spreeTormentorGuild = "toast", -- a guildie put an end to one
    revengeMine = "splash",  -- your revenge: you got one who had killed you since you last got them
    revengeGuild = "off",    -- a guildie's: in a big guild somebody always has one
    grudgeMine = "toast",    -- you got one who led over you, no revenge: where you stand now (Announce.lua, GK_GRUDGE)
    guildZoneOnly = false,   -- a guildie's only when they are in your zone
    -- The sounds, each side's its own under its page's Play sounds: "sounds bør være delt, settings for dine egne,
    -- settings for guildies. og hvis du unchecker 'Play sounds' bør alle ... bli skrudd av men også låse/grey out"
    -- (the owner, 2026-11-22). A master off leaves each box's own pick as it was, for when it is on again.
    mineSounds = true,       -- Mine's Play sounds
    guildSounds = true,      -- Guildies'
    warnSounds = true,       -- Warnings'
    -- One for each moment, its call and its effect's (GK.MOMENT_SOUND; a spree's step is spreeSound), yours and a
    -- guildie's. None has a sound to pick: "synes ikke folk skal kunne velge lyder på notifications hvor vi har
    -- splash og sånn. bare på typ.. når du ser noen du har på kill list osv? vi har jo allerede lagd lyder for det
    -- andre" (the owner, 2026-11-22).
    spreeSound = true, spreeSoundGuild = true,
    rankSound = true, rankSoundGuild = true,
    orderSound = true, orderSoundGuild = true,
    revengeSound = true, revengeSoundGuild = true,
    grudgeSound = true,      -- yours alone: a guildie's score with an enemy is theirs
    endedSound = true, endedSoundGuild = true,
    tormentorSound = true, tormentorSoundGuild = true,
    announceWhenMine = "always",       -- when yours may come: "always", "noCombat", "noCombatInInstance" or "noInstance"
    announceWhenGuild = "noCombat",    -- the same for a guildie's; one held back waits, then comes in order
    announceTime = 7,                  -- how many seconds a toast shows; a splash half of it (Announce.lua)
    alts = {},               -- [charKey] = { name, realm, side, first, copy = { [foe key] = counts and times } }: the account's characters (Alts.lua)
    altFirst = nil,          -- the charKey of the first character the account saw (the nudge's "not the first")
    altRemoved = {},         -- [charKey] = { [foe key] = time }: grudges removed from another character's view
    altNudged = false,       -- the nudge about one Death Note was handled, on any character
    altView = "me",          -- the Grudges page's remembered view: "me" or "all"
    looks = {},              -- [player key] = race file and sex, "Scourge3": their race's face on cards (Sightings.lua)
}
-- This character's own record.
local charDefaults = {
    points = 0, kills = 0, deaths = 0, assists = 0,
    streak = 0, bestStreak = 0,  -- kills in a row since you last died to an enemy player, and the most ever:
    spree = 0,                   -- no grey and no farmed one (GK.CountsInStreak); the spree announced is the same
    done = 0, won = 0,           -- kill orders you fulfilled, and the bounties on them (copper)
    -- week = { id, p, k, d, a }: this week's score, made by GK.Week and started over at the weekly reset
    log = {},                -- newest first: { k = "K", "A" or "D", t, n, c, r, l, z, p, o, w (an assist's killer) }
    foes = {},               -- [key] = { n, c, r, l, k, d, a, last, lastKill, lastAssist, lastDeath, hits = { time, ... } }
    tracked = {},            -- [key] = { t, c, r, l }: your Death list, yours alone (Sightings.lua, GK.Track)
    guildChat = {},          -- the last lines of guild chat, for the page on the guild window (GuildTab.lua)
    letters = {},            -- oldest first (Letters.lua)
    letterId = 0,
    -- pc, u, parts: this PC's mark on the record, whether it held a score before marks existed, and the
    -- other PCs' parts of the score (GK.ClaimPC, and Guild.lua's "One character, more than one PC")
}

--- A character's record as a first install starts it, for the test panel's fresh start (Debug.lua).
function GK.FreshChar() return CopyTable(charDefaults) end

--- A setting as it is installed: for the test panel's modes (Debug.lua).
function GK.Default(key) return defaults[key] end

-- Mode, for a guild of 700 and a streamer in it: "må være mulig å #1 mute guild eller sette en 'personal only' eller
-- 'only personal and from bnet friends'" and "kanskje det er 'streamer mode' og 'private mode'" (the owner,
-- 2026-11-22), built as the table the owner said yes to ("vi kan bygge mode"):
--               news told from          score shared   where you are shared   profile outside the guild
--   normal      everyone                as set         yes                    as set
--   streamer    you (your own orders)   as set         no                     as set
--   private     you                     no             no                     no
-- Streamer heard friends and your group until the same evening: "streamer mode skal vel helst ikke få noe spesielt
-- fra guildies egentlig. ikke notifications om kill orders osv." Its orders about you are your own and those you
-- backed (GK.OrderConcerns); Private's are also a guildie's on your Death list or on one who killed you.
-- Where you are: the zone in a kill, an assist, a death and a fulfilled order, and a sighting's spot on the map.
-- What is yours to say for an order to work - posting it, a bounty, a payment, its fulfilment - goes in every mode.

--- The mode: "normal", "streamer" or "private".
function GK.Mode()
    local m = GK.db and GK.db.mode
    if m == "streamer" or m == "private" then return m end
    return "normal"
end

--- Whether our score goes to the guild: kills, deaths, assists, the board's row, and an order a death posts.
function GK.SharesScore() return GK.db.share ~= false and GK.Mode() ~= "private" end

--- Whether where we are goes with it.
function GK.SharesPlace() return GK.Mode() == "normal" end

--- Whether a player on our side outside the guild who asks is answered (Profile.lua).
function GK.SharesOutside() return GK.db.shareOutside ~= false and GK.Mode() ~= "private" end

-- The right-click menu's lines, each on or off (Settings, Right-click menu, 2026-11-24): "legg til settings for hva du
-- ønsker å se ved dropdown på enemies og friendlies. kanskje noen bare vil se KoS eller Shame osv" (the owner). One
-- box was every line until then. An enemy's four (Profile.lua), then a friendly player's (Profile.lua, NotesUI.lua).
GK.MENU_LINES = { "menuFile", "menuOrder", "menuDeathNote", "menuGuild", "menuProfile", "menuShame", "menuKudos",
    "menuNotes" }

--- Whether this line of ours goes in the game's right-click menu.
function GK.MenuLine(key) return GK.db ~= nil and GK.db[key] ~= false end

--- Whether any does: with none, the menus are left alone altogether.
function GK.MenuAny()
    for _, key in ipairs(GK.MENU_LINES) do
        if GK.MenuLine(key) then return true end
    end
    return false
end

-- What you see (Settings, Quick setup, 2026-11-24): one choice that sets the rows of Mine, Guildies and Warnings, and
-- is Custom when they match none of these. Those rows only: a guildie's thresholds, the sounds, the letters and the
-- rest stay as they are. Standard is the rows as installed. What you share (GK.Mode) turns none of it down: Streamer
-- and Private told nothing of a guildie's until then, and the rows say that now. In a block: Core.lua's locals.
do
    local MINE = { "spreeMine", "rankMine", "orderMine", "revengeMine", "grudgeMine", "spreeEnded", "spreeTormentor" }
    local GUILD = { "spreeGuild", "rankGuild", "orderDone", "revengeGuild", "spreeEndedGuild", "spreeTormentorGuild" }
    local WARN = { "alertNear", "watchNearby", "watchGroup", "kudosGroup", "targetedBy" }
    GK.SEE_MINE, GK.SEE_GUILD, GK.SEE_WARN = MINE, GUILD, WARN
    local function All(keys, v)
        local t = {}
        for _, k in ipairs(keys) do t[k] = v end
        return t
    end
    local function Rows(...)
        local t = {}
        for i = 1, select("#", ...) do
            for k, v in pairs((select(i, ...))) do t[k] = v end
        end
        return t
    end
    local MINE_ON = { spreeMine = "splash", rankMine = "splash", orderMine = "splash", revengeMine = "splash",
        grudgeMine = "toast", spreeEnded = "toast", spreeTormentor = "toast" }
    local GUILD_STANDARD = { spreeGuild = "toast", rankGuild = "toast", orderDone = "toast", revengeGuild = "off",
        spreeEndedGuild = "off", spreeTormentorGuild = "toast" }
    local WARN_STANDARD = { alertNear = "screen", watchNearby = "off", watchGroup = "screen", kudosGroup = "off",
        targetedBy = "off" }
    local ORDERS_ONLY = All(GUILD, "off")
    ORDERS_ONLY.orderDone = "toast"
    GK.SEE = {
        { id = "standard", name = "Standard", says = "Your big moments, the guild's biggest, and warnings.",
          rows = Rows(MINE_ON, GUILD_STANDARD, WARN_STANDARD) },
        { id = "all", name = "Everything", says = "Every moment of yours and the guild's, every warning.",
          rows = Rows(MINE_ON, All(GUILD, "toast"), All(WARN, "screen")) },
        { id = "orders", name = "Kill orders", says = "Your moments. From the guild only kill orders fulfilled.",
          rows = Rows(MINE_ON, ORDERS_ONLY, WARN_STANDARD) },
        { id = "mine", name = "Only mine", says = "Your moments and warnings. Nothing from the guild.",
          rows = Rows(MINE_ON, All(GUILD, "off"), WARN_STANDARD) },
        { id = "warn", name = "Warnings only", says = "Who is near and who joins your group. No splashes or toasts.",
          rows = Rows(All(MINE, "off"), All(GUILD, "off"), WARN_STANDARD) },
        { id = "none", name = "Nothing on screen", says = "No splashes, toasts or warnings. Letters still come.",
          rows = Rows(All(MINE, "off"), All(GUILD, "off"), All(WARN, "off")) },
    }
    local isGuild, isWarn = All(GUILD, true), All(WARN, true)

    --- A row as What you see compares it: a guildie's splash is a toast (Announce.lua, Style), and a warning's old
    --- true or false is its way now (GK.WarnStyle).
    local function Value(key)
        if isWarn[key] then return GK.WarnStyle(key) end
        local v = GK.db[key]
        if isGuild[key] and v ~= "off" then return "toast" end
        return v
    end

    --- What you see now: the id of the choice the rows match, or "custom".
    function GK.SeeChoice()
        if not GK.db then return "custom" end
        for _, c in ipairs(GK.SEE) do
            local same = true
            for key, v in pairs(c.rows) do
                if Value(key) ~= v then
                    same = false
                    break
                end
            end
            if same then return c.id end
        end
        return "custom"
    end

    --- Set the rows a choice names. Returns whether there is such a choice.
    function GK.SetSee(id)
        for _, c in ipairs(GK.SEE) do
            if c.id == id then
                for key, v in pairs(c.rows) do GK.db[key] = v end
                return true
            end
        end
        return false
    end
end

-- ---------------------------------------------------------------------------
-- Values from the client and from other players
-- ---------------------------------------------------------------------------
--- A value the client keeps from us (identity in an instance, say). Anything that can't even be
--- asked about counts as secret.
local function Secret(v)
    if not issecretvalue then return false end
    local ok, s = pcall(issecretvalue, v)
    return (not ok) or (s and true or false)
end
GK.Secret = Secret

--- Text from another player or the client, safe to keep, show and send: no escape codes or control
--- characters (LIB.Sanitize), no ';' (our field separator), capped. nil when nothing is left.
function GK.Clean(s, n)
    if s == nil or Secret(s) then return nil end
    s = LIB.Sanitize(s, n or 48):gsub(";", ",")
    return s ~= "" and s or nil
end

function GK.ValidClass(c)
    return type(c) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[c] and c or nil
end

--- 1-100, or -1 for a level the game shows as "??". nil for anything else.
function GK.ValidLevel(l)
    l = tonumber(l)
    if not l then return nil end
    if l == -1 then return -1 end
    if l < 1 or l > 100 or l ~= math.floor(l) then return nil end
    return l
end

-- Which race is on which side, by the client's file token ("Scourge" is Undead). A race on both sides
-- (Pandaren) is in neither list, and then only having SEEN the player as hostile decides.
local HORDE = { Orc = true, Scourge = true, Tauren = true, Troll = true, BloodElf = true, Goblin = true,
    Nightborne = true, HighmountainTauren = true, MagharOrc = true, ZandalariTroll = true, Vulpera = true }
local ALLIANCE = { Human = true, Dwarf = true, NightElf = true, Gnome = true, Draenei = true, Worgen = true,
    VoidElf = true, LightforgedDraenei = true, DarkIronDwarf = true, KulTiran = true, Mechagnome = true }

--- Is this race on the other side from us? nil when the race doesn't say.
function GK.EnemyRace(raceFile)
    local mine = UnitFactionGroup("player")
    local ours, theirs
    if mine == "Alliance" then ours, theirs = ALLIANCE, HORDE
    elseif mine == "Horde" then ours, theirs = HORDE, ALLIANCE
    else return nil end
    if theirs[raceFile] then return true end
    if ours[raceFile] then return false end
    return nil
end

-- ---------------------------------------------------------------------------
-- Points
-- ---------------------------------------------------------------------------
--- The level at and below which someone is grey to you: the game's own experience rule, the same
--- line classic honour drew between an honourable kill and none.
function GK.GreyLevel(level)
    if level <= 5 then return 0 end
    if level <= 39 then return level - 5 - math.floor(level / 10) end
    return level - 1 - math.floor(level / 5)
end

--- The colour the game gives their level beside yours. -1 is "??": far above you.
function GK.Con(mine, theirs)
    if not (mine and theirs) then return nil end
    if theirs == -1 then return "red" end
    local d = theirs - mine
    if d >= 5 then return "red" end
    if d >= 3 then return "orange" end
    if d >= -2 then return "yellow" end
    if theirs > GK.GreyLevel(mine) then return "green" end
    return "grey"
end

GK.POINTS = { grey = 0, green = 1, yellow = 2, orange = 3, red = 4 }
GK.UNKNOWN_POINTS = 1    -- a level we never saw: the least a real kill is worth
GK.ORDER_BONUS = 3       -- on top, for the kill that fulfils a kill order
GK.REVENGE_BONUS = 1     -- they killed you since you last killed them
GK.AVENGE_BONUS = 1      -- they killed a guildie in the last AVENGE_FOR seconds, before this fight began
GK.AVENGE_FOR = 15 * 60
GK.REPEATS = 2           -- the same player is worth points this many times a day, then nothing
GK.ASSIST_LESS = 1       -- an assist is worth this much less than the kill, and still at least 1
GK.DAY = 24 * 3600

--- Points for one kill: by their level beside yours, plus revenge and avenging a guildie - nothing at
--- all once you have killed the same player REPEATS times today, so farming one player buys nothing,
--- bonuses included - and the order bonus on top. Returns the points and the colour.
function GK.Points(mine, theirs, killedToday, order, revenge, avenged)
    local con = GK.Con(mine, theirs)
    local p = con and GK.POINTS[con] or GK.UNKNOWN_POINTS
    if (killedToday or 0) >= GK.REPEATS then
        p = 0
    else
        if revenge then p = p + GK.REVENGE_BONUS end
        if avenged then p = p + GK.AVENGE_BONUS end
    end
    if order then p = p + GK.ORDER_BONUS end
    return p, con
end

--- Does a kill count in a streak and its spree? Never a grey one, and none of a player farmed today, whatever
--- they were worth: the bonuses give a grey kill points, and by its points it was in the spree ("kill streaks
--- teller grå kills også? burde den det?", the owner, 2026-11-22). A level we never saw counts, as it has points.
function GK.CountsInStreak(mine, theirs, killedToday)
    return (killedToday or 0) < GK.REPEATS and GK.Con(mine, theirs) ~= "grey"
end

--- Points for one assist: the kill's, with no order bonus (the killer fulfils it), a little less. A
--- kill worth nothing (grey, or farmed) is an assist worth nothing.
function GK.AssistPoints(mine, theirs, killedToday, revenge, avenged)
    local p = GK.Points(mine, theirs, killedToday, false, revenge, avenged)
    if p > 0 then p = math.max(p - GK.ASSIST_LESS, 1) end
    return p
end

-- Titles by all-time points: our own words, so nobody takes them for the game's honour ranks. Past
-- Executioner each step is about 1.4 times the last: four titles between it and Grudgebearer, and the last
-- two further off, "for å ha enda mer å strekke seg til" (the owner, 2026-11-18, two weeks after launch,
-- when the best in the guild had 205). Nobody held Grudgebearer or Dread Reaper then, so nobody lost one.
GK.TITLES = {
    { 0, "Unblooded" }, { 10, "Cutthroat" }, { 25, "Bloodhound" }, { 50, "Headhunter" },
    { 100, "Slayer" }, { 200, "Executioner" }, { 300, "Oathsworn" }, { 450, "Avenger" },
    { 650, "Reckoner" }, { 900, "Nemesis" }, { 1300, "Grudgebearer" }, { 2000, "Dread Reaper" },
}

function GK.Title(points)
    local title = GK.TITLES[1][2]
    for _, row in ipairs(GK.TITLES) do
        if (points or 0) >= row[1] then title = row[2] end
    end
    return title
end

--- A title as a key for code and files: "Dread Reaper" is "dread_reaper" (a rank up's effect, Announce.lua).
function GK.TitleKey(title)
    return (tostring(title or ""):lower():gsub("[^%a]+", "_"))
end

--- The week we're in, named by the time of the next weekly reset to the hour, so every client in
--- the guild names it the same. A client that can't say when the reset is counts weeks from 1970.
function GK.WeekId()
    local now = time()
    local get = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
    local ok, secs = false, nil
    if get then ok, secs = pcall(get) end
    if ok and type(secs) == "number" and secs > 0 and not Secret(secs) then
        return math.floor((now + secs) / 3600 + 0.5)
    end
    return math.floor(now / (7 * GK.DAY))
end

--- This character's score this week, started over when the reset has passed.
function GK.Week()
    local id = GK.WeekId()
    local w = GK.char.week
    if type(w) ~= "table" or w.id ~= id then
        w = { id = id, p = 0, k = 0, d = 0, a = 0 }
        GK.char.week = w
    end
    return w
end

--- This PC's mark on the character's record, made the first time it is loaded here. The record lives in
--- this PC's saved file only, so a second PC has a record - and a mark - of its own, and the guild adds
--- the two up (Guild.lua). u: the record held a score already when it got its mark, the score from before
--- marks existed - which an older client may have told the guild as a row of its own.
local MARK = "0123456789abcdefghijklmnopqrstuvwxyz"
function GK.ClaimPC(c)
    if type(c.parts) ~= "table" then c.parts = {} end
    if type(c.pc) == "string" and c.pc:match("^[0-9a-z][0-9a-z][0-9a-z][0-9a-z][0-9a-z][0-9a-z]$") then return end
    local id = {}
    for i = 1, 6 do
        local n = math.random(#MARK)
        id[i] = MARK:sub(n, n)
    end
    c.pc = table.concat(id)
    c.u = ((c.points or 0) + (c.kills or 0) + (c.deaths or 0) + (c.assists or 0) > 0) or nil
    c.parts = {}
end

-- ---------------------------------------------------------------------------
-- Names, places, money
-- ---------------------------------------------------------------------------
--- A key a client wrote with an empty realm, made whole: "Snik Toby-" is "Snik Toby", and "Snik Toby--Realm" -
--- what our realm put after the first makes - is "Snik Toby-Realm". A guildie's client that had no realm yet
--- when it filed an order wrote its poster and target so, and passed them on in a relay: the order came in twice,
--- the second copy under "Snik Toby--Realm" with its target "Mana Berry-", which no nameplate or sighting ever
--- matched, and a letter said "Posted by Snik Toby-'s death" (the owner's screenshot, 2026-11-20; their saved
--- file: 7 orders, each the twin of one under the whole name). No name has a "-" in it. Any other value as it is.
function GK.NoEmptyRealm(key)
    if type(key) ~= "string" then return key end
    return (key:gsub("%-%-+", "-"):gsub("%-$", ""))
end

--- For display: no realm of ours, and the surname only when the player shows surnames.
function GK.Show(key)
    if not key then return "?" end
    -- the screenshot mode (Shots.lua) puts a made-up name where yours would be
    local stand = GK.shotNames and GK.shotNames[key]
    if stand then return stand end
    key = GK.NoEmptyRealm(key)
    -- First name and surname, never a realm: on Forever a realm is one of a server's internal ones
    -- ("CAMWOWEU5Realm2PvP"), which means nothing to anyone reading it ("nemesis viser spiller med
    -- realmnavn bak. det trengs ikke. bare fornavn etternavn", the owner, 2026-11-07). LIB.ShortName drops
    -- only our own realm; a guildie on another wrote the name with theirs. No name has a "-" in it.
    return LIB.ShortName(key:match("^(.-)%-[^%-]*$") or key)
end

--- "Name-Realm" from a name and a realm the client gave us (GetPlayerInfoByGUID).
function GK.KeyOf(name, realm)
    if type(name) ~= "string" or name == "" or Secret(name) then return nil end
    local _ = realm                                  -- a realm names nobody since 2026-11-20 (GK.Lib)
    return LIB.FullName(name)
end

--- Two spellings of one character: the same, or the same first name where one of the two has no
--- surname - the death recap and GetPlayerInfoByGUID may leave a surname off that a unit's name has.
--- Only ever used to match a name to someone we SAW, never to merge two records we keep.
function GK.SameName(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    a = a:gsub("%-[^%-]*$", "")
    b = b:gsub("%-[^%-]*$", "")
    if a == b then return true end
    -- the first word up to a plain space: %S follows the locale, and under Latin-1 it ends a Cyrillic
    -- name at the 0xA0 inside "Р" (GK.Lower's note)
    local fa, fb = a:match("^[^ ]+"), b:match("^[^ ]+")
    if fa ~= fb then return false end
    return a == fa or b == fb
end

--- A guildie's name as another client wrote it into a message, in OUR spelling of it. On Forever's live
--- servers one guild spans several of the server's internal realms (CAMWOWEU4Realm4PvP, ...Realm8PvP,
--- CAMWOWEU5Realm2PvP), and the client gives us every guildie WITHOUT a realm - the sender of an addon
--- message is "Edvard" - so we file them under our own realm. A name a guildie writes into a message is
--- filed the same way on THEIR side, under THEIR realm: Lars, on another realm, names Edvard's order
--- "Edvard-CAMWOWEU4Realm8PvP" and us "Vebjorn-CAMWOWEU4Realm8PvP". Guildhall found it in the game
--- (2026-11-06, GH.LocalKey). A name from the wire whose realm is not ours becomes ours - but only when
--- that spelling is someone we know (ourselves, a guildie we have heard or seen on the roster or the
--- board, or what known(spelling) says, for a record that only its owner can have made), and never when
--- the name as written is known already. The client can't tell two such names apart either: it shows
--- them without a realm.
--- Since 2026-11-20 every key is the name alone (GK.Lib), and a name from the wire is plain whatever realm its
--- writer gave it: GK.PlayerKey. known is no longer asked; kept for the callers.
function GK.LocalKey(full, known)
    local _ = known
    return GK.PlayerKey(full)
end

--- Is this, after a name's dash, a realm? The live servers' internal realms ("CAMWOWEU4Realm4PvP") and the
--- beta's ("ClassicBetaPvP2") carry digits or PvP/PvE; a surname is a plain word. Our own realm is one,
--- whatever it looks like.
local function LooksLikeRealm(s)
    return s == LIB.Realm() or s:find("%d") ~= nil or s:find("PvP", 1, true) ~= nil or s:find("PvE", 1, true) ~= nil
end

--- Any player's key in the one spelling Grudgekeeper keeps: name and surname, and no realm (GK.Lib's note,
--- 2026-11-20). Every Forever character has a surname (DECISIONS.md, 2026-10-03), and a name is unique across
--- the region, so the realm part of a key tells nobody apart - but on the live servers it varied, and so the
--- same player had several keys:
---   - LibForever reads the surname of a player on another of the server's internal realms as the realm:
---     "Unc-Shark" for Unc Shark. Every Unc then lost their surname wherever a realm was cut off, and
---     a death to Unc Allayra went to Unc Shark (the owner, 2026-11-06). A dash followed by a plain
---     word is put back as the surname.
---   - a guildie on another realm writes everyone with THEIR realm ("Unc Shark-CAMWOWEU4Realm8PvP"), so
---     their kill orders never met the same enemy on our nameplates. The realm goes.
--- A name with no surname and a realm after it is the name alone: "Unc-<realm>" is "Unc", a name we were
--- given without one (a death recap, an old record), and no surname is guessed for it.
function GK.PlayerKey(key)
    if type(key) ~= "string" then return key end
    key = GK.NoEmptyRealm(key)
    if key == "" then return nil end
    local name, after = key:match("^(.-)%-([^%-]+)$")
    if not name or name == "" then return Plain(key) end
    if not name:find(" ", 1, true) and not LooksLikeRealm(after) then
        return name .. " " .. after                    -- the surname, read as a realm
    end
    return name
end

-- What was kept before GK.PlayerKey (0.1.0-beta2 and the live servers' first days) moves to its spelling
-- once: GK.db.keys and GK.char.keys say it has. A record that meets one already under the new key is
-- added into it where we know how (the counts of a foe, the tallies of the guild); anything else keeps
-- its old key rather than lose either.
-- 2: the keys a relay wrote with an empty realm (GK.NoEmptyRealm), 2026-11-20
-- 3: the guild's store kept under "Guild-" while the client named no realm (Forever's 1.60.1.71037, 2026-11-20)
-- 4: every player by name alone, "First Last" (GK.Lib, 2026-11-20)

local function MaxInto(into, from)
    for who, n in pairs(from or {}) do
        if type(n) == "number" and (into[who] or 0) < n then into[who] = n end
    end
end

local MERGE = {
    foes = function(a, b)
        a.k, a.d = (a.k or 0) + (b.k or 0), (a.d or 0) + (b.d or 0)
        a.last = math.max(a.last or 0, b.last or 0)
        if b.lastDeath and (a.lastDeath or 0) < b.lastDeath then a.lastDeath = b.lastDeath end
    end,
    wanted = function(a, b)
        a.victims = a.victims or {}
        MaxInto(a.victims, b.victims)
        a.last = math.max(a.last or 0, b.last or 0)
    end,
    slain = function(a, b)
        a.by = a.by or {}
        MaxInto(a.by, b.by)
        a.last = math.max(a.last or 0, b.last or 0)
    end,
}

--- Move a table keyed by players to the one spelling; merge(new, old) when both are there, else keep both.
local function Rekey(t, merge)
    if type(t) ~= "table" then return end
    local moves = {}
    for k in pairs(t) do
        local nk = type(k) == "string" and GK.PlayerKey(k) or k
        if nk ~= k then moves[#moves + 1] = { k, nk } end
    end
    for _, m in ipairs(moves) do
        local old, new = m[1], m[2]
        local v = t[old]
        if t[new] == nil then
            t[old], t[new] = nil, v
        elseif merge then
            merge(t[new], v)
            t[old] = nil
        end
    end
end

local function RekeyList(list, field)
    for _, e in ipairs(type(list) == "table" and list or {}) do
        if type(e) == "table" and type(e[field]) == "string" then e[field] = GK.PlayerKey(e[field]) end
    end
end

--- A guildie's key, or an order's ("<poster>#<id>"), written with an empty realm, made whole: our realm where
--- none is left, as a guildie's always is (GK.LocalKey's note). Any other value as it is.
local function Whole(k)
    if type(k) ~= "string" then return k end
    local nk = GK.NoEmptyRealm(k)
    if nk == k then return k end
    local name, rest = nk:match("^([^#]*)(.*)$")
    if not name:find("-", 1, true) then name = LIB.FullName(name) or name end
    return name .. rest
end

--- A table keyed by players or orders: a key with an empty realm (any number of dashes: each relay hop added
--- one, "Lavish Bandito---Realm") moves onto fix(key), and where a record is there already it is the same one
--- twice: merge(kept, old) when given, else the one there stays. Only such keys move. Returns the keys that went
--- into a record that was there already, as a set.
local function RekeyBroken(t, fix, merge)
    local merged = {}
    if type(t) ~= "table" then return merged end
    local moves = {}
    for k in pairs(t) do
        if type(k) == "string" and GK.NoEmptyRealm(k) ~= k then moves[#moves + 1] = { k, fix(k) } end
    end
    table.sort(moves, function(a, b) return #a[1] < #b[1] end)      -- the fewest dashes first: the likeliest original
    for _, m in ipairs(moves) do
        local v = t[m[1]]
        t[m[1]] = nil
        if m[2] == nil then
            -- no key to move it to: dropped
        elseif t[m[2]] == nil then
            t[m[2]] = v
        else
            merged[m[1]] = true
            if merge then t[m[2]] = merge(t[m[2]], v) end
        end
    end
    return merged
end

local function Larger(a, b)
    if type(a) == "number" and type(b) == "number" then return math.max(a, b) end
    return a
end

--- Every name in an order a relay may have written with an empty realm, made whole.
local function MendOrder(o)
    o.key, o.by, o.doneBy = Whole(o.key), Whole(o.by), Whole(o.doneBy)
    if type(o.n) == "string" then o.n = GK.PlayerKey(o.n) end
    if type(o.helpers) == "table" then
        for i, k in ipairs(o.helpers) do o.helpers[i] = Whole(k) end
    end
    RekeyBroken(o.pot, Whole, Larger)
    if type(o.seen) == "table" then o.seen.by = Whole(o.seen.by) end
end

--- Once, at login: every name Grudgekeeper keeps for another player, in GK.PlayerKey's spelling.
--- v3: a guild's store kept under "Guild-" goes into the guild's own. Forever's build 1.60.1.71037 named no realm,
--- and LibForever's guild key came out "YippYapp-": a new, empty store, so every order the guild passed on was
--- fresh and a letter - 30 for the owner at one login (2026-11-20). An order its own store lacks moves there, with
--- its letter; one it had already is a copy, and the copy's letter goes (the keys returned). Asked once the lib
--- knows the realm again; with none known it waits for a login that does.
local function MendEmptyRealmStores()
    local realm = LIB.Realm()
    if not realm then return nil end
    local copies = {}
    for key, g in pairs(GK.db.guilds) do
        local guild = type(key) == "string" and key:match("^(.+)%-$")
        if guild and type(g) == "table" then
            local own = GK.db.guilds[guild .. "-" .. realm]
            if own then
                for k, o in pairs(g.orders or {}) do
                    if own.orders[k] then
                        copies[k] = true
                    elseif type(k) == "string" and GK.NoEmptyRealm(k) == k and k:find("%-[^%-#]+#") then
                        own.orders[k] = o
                    end
                end
            end
            GK.db.guilds[key] = nil
        end
    end
    return copies
end

-- ---------------------------------------------------------------------------
-- v4 (2026-11-20): every player by name alone (GK.Lib). The realm goes from the keys and the names in every place
-- the saved data keeps them - found in the owner's files: the tables keyed by players, orders or guilds (KEYED),
-- the fields of NAME_FIELDS and the lists of NAME_LISTS. Not the free text (notes, an order's note, a sound, a GUID)
-- nor the screenshots' names (db.shots), which only look like names ("most-wanted"). Two keys that become one are
-- one player kept under two realms, and the two are one record: our own foes' counts add up (each fight was kept
-- once), the guild's tallies take the larger, a guildie's row and the rest the newer, an order kept twice the closed
-- one, a guild's store the fuller; whatever the kept one lacks comes from the other.
-- ---------------------------------------------------------------------------
local KEYED = { looks = true, guilds = true, slain = true, wanted = true, victims = true, tormentors = true,
    foes = true, orders = true, pot = true, board = true, people = true, notes = true, marks = true, tracked = true,
    by = true }
local NAME_FIELDS = { n = true, o = true, av = true, key = true, by = true, doneBy = true, who = true, nm = true }
local NAME_LISTS = { helpers = true, recent = true, h = true }
local NOT_NAMES = { shots = true }

local function Stamp(r) return tonumber(r.t) or tonumber(r.last) or tonumber(r.doneAt) or 0 end
local function Size(store)
    local n = 0
    for _ in pairs(type(store) == "table" and type(store.board) == "table" and store.board or {}) do n = n + 1 end
    for _ in pairs(type(store) == "table" and type(store.orders) == "table" and store.orders or {}) do n = n + 1 end
    return n
end

--- What kept lacks, from other; a table keyed by players in both, the two together.
local function FillIn(kept, other)
    for k, v in pairs(other) do
        if kept[k] == nil then
            kept[k] = v
        elseif type(kept[k]) == "table" and type(v) == "table" and KEYED[k] then
            FillIn(kept[k], v)
        end
    end
end

local function MergeRecords(field, kept, other)
    if type(kept) == "number" and type(other) == "number" then return math.max(kept, other) end
    if type(kept) ~= "table" or type(other) ~= "table" then return kept end
    if MERGE[field] then
        MERGE[field](kept, other)
        return kept
    end
    if field == "orders" then
        if kept.state == "o" and type(other.state) == "string" and other.state ~= "o" then kept, other = other, kept end
    elseif field == "guilds" then
        if Size(other) > Size(kept) then kept, other = other, kept end
    elseif Stamp(other) > Stamp(kept) then
        kept, other = other, kept
    end
    FillIn(kept, other)
    return kept
end

--- An order's key or a guild's: the realm out, its "#id" kept. A player's: GK.PlayerKey.
local function PlainKey(k) return Plain(GK.NoEmptyRealm(k)) end

--- The keys of t, plain. A guild's store kept under "Guild-" (no realm, 2026-11-20) whose orders the guild's own
--- had already: those order keys go into copies, for their letters to go.
local function PlainKeys(t, field, copies)
    local fix = (field == "orders" or field == "guilds") and PlainKey or GK.PlayerKey
    local moves = {}
    for k in pairs(t) do
        if type(k) == "string" then
            local nk = fix(k)
            if nk and nk ~= k then moves[#moves + 1] = { k, nk } end
        end
    end
    -- the same every time; a key with no realm ("Guild-", this evening's) last, so the store it meets is the real one
    table.sort(moves, function(a, b)
        local ea, eb = a[1]:sub(-1) == "-", b[1]:sub(-1) == "-"
        if ea ~= eb then return eb end
        return a[1] < b[1]
    end)
    for _, m in ipairs(moves) do
        local v = t[m[1]]
        t[m[1]] = nil
        local there = t[m[2]]
        if there == nil then
            t[m[2]] = v
        elseif field == "guilds" and m[1]:sub(-1) == "-" and type(there) == "table" and type(v) == "table" then
            -- a store kept under "Guild-" is never the one kept, whatever its size: the guild's own takes in what
            -- it lacks, and the orders both had are copies
            local inThere = {}
            for ok in pairs(there.orders or {}) do inThere[PlainKey(ok)] = true end
            for ok in pairs(v.orders or {}) do
                if copies and inThere[PlainKey(ok)] then copies[PlainKey(ok)] = true end
            end
            FillIn(there, v)
        else
            if field == "guilds" and copies and type(v) == "table" and type(there) == "table" then
                -- one store's keys may be plain already and the other's not: compared plain
                local inThere = {}
                for ok in pairs(there.orders or {}) do inThere[PlainKey(ok)] = true end
                for ok in pairs(v.orders or {}) do
                    if inThere[PlainKey(ok)] then copies[PlainKey(ok)] = true end
                end
            end
            t[m[2]] = MergeRecords(field, there, v)
        end
    end
end

local function PlainNames(t, field, depth, copies)
    if depth > 8 then return end
    if KEYED[field] then PlainKeys(t, field, copies) end
    for k, v in pairs(t) do
        if type(v) == "string" then
            if NAME_FIELDS[k] then
                local nv = (k == "o" or k == "key") and PlainKey(v) or GK.PlayerKey(v)
                if nv and nv ~= v then t[k] = nv end
            end
        elseif type(v) == "table" and not (depth == 0 and NOT_NAMES[k]) then
            if NAME_LISTS[k] then
                for i, s in ipairs(v) do
                    if type(s) == "string" then v[i] = GK.PlayerKey(s) or s end
                end
            else
                PlainNames(v, type(k) == "string" and k or "", depth + 1, copies)
            end
        end
    end
end

function GK.RekeyStores()
    -- the guild's first (v2): the letters below need to know which orders were copies of another
    local mergedOrders = {}
    -- v3, before the rest: the orders a store under "Guild-" had again, whose letters go below
    local copiedOrders
    if (GK.db.keys or 0) < 3 then copiedOrders = MendEmptyRealmStores() end
    if (GK.db.keys or 0) < 2 then
        for _, g in pairs(GK.db.guilds) do
            Rekey(g.wanted, MERGE.wanted)
            Rekey(g.slain, MERGE.slain)
            Rekey(g.people)
            for key, p in pairs(g.people or {}) do
                if type(p) == "table" then p.n = key end
            end
            for _, o in pairs(g.orders or {}) do
                if type(o.n) == "string" then o.n = GK.PlayerKey(o.n) end
            end
            RekeyList(g.feed, "n")
            -- v2: what a relay wrote with an empty realm. An order kept under such a poster is the order kept
            -- under the whole one, come again: each spelling was a fresh order and a new letter ("Lavish
            -- Bandito-", "--", "---", one id three times in the owner's file, 2026-11-20). The one under the
            -- whole key stays; a copy with nothing there moves onto it.
            RekeyBroken(g.board, Whole)
            for k in pairs(RekeyBroken(g.orders, Whole)) do mergedOrders[k] = true end
            for _, o in pairs(g.orders or {}) do
                if type(o) == "table" then MendOrder(o) end
            end
            RekeyBroken(g.tormentors, GK.PlayerKey, Larger)
            for _, e in ipairs(type(g.feed) == "table" and g.feed or {}) do
                if type(e) == "table" then
                    e.who = Whole(e.who)
                    if type(e.h) == "table" then
                        for i, k in ipairs(e.h) do e.h[i] = Whole(k) end
                    end
                end
            end
        end
        GK.db.keys = 2
    end
    if (GK.char.keys or 0) < 2 then
        Rekey(GK.char.foes, MERGE.foes)
        for key, f in pairs(GK.char.foes) do f.n = GK.Show(key) end
        RekeyList(GK.char.log, "n")
        RekeyList(GK.char.letters, "n")
        -- v2: a letter a copy of an order brought goes - the order had its letter when it first came - and so
        -- does a second letter onto one order; the rest point at the order's whole key
        local onto, keep = {}, {}
        for _, L in ipairs(GK.char.letters) do
            if type(L) == "table" and type(L.o) == "string" and Whole(L.o) == L.o then onto[(L.kind or "") .. L.o] = true end
        end
        for _, L in ipairs(GK.char.letters) do
            if type(L) ~= "table" then
                keep[#keep + 1] = L
            else
                L.by = Whole(L.by)
                local whole = Whole(L.o)
                if whole == L.o then
                    keep[#keep + 1] = L
                elseif not mergedOrders[L.o] and not onto[(L.kind or "") .. whole] then
                    onto[(L.kind or "") .. whole] = true            -- a copy with no twin: its letter, once
                    L.o = whole
                    keep[#keep + 1] = L
                end
            end
        end
        wipe(GK.char.letters)
        for i, L in ipairs(keep) do GK.char.letters[i] = L end
        GK.char.keys = 2
    end
    -- v3: an unread letter for an order a store under "Guild-" had again goes - the order had its letter when it
    -- first came to the guild's own store. Done once the store was mended; a login with no realm known waits.
    if copiedOrders then
        if (GK.char.keys or 0) < 3 then
            for i = #GK.char.letters, 1, -1 do
                local L = GK.char.letters[i]
                if type(L) == "table" and L.kind == "order" and not L.read and type(L.o) == "string"
                    and copiedOrders[L.o] then
                    table.remove(GK.char.letters, i)
                end
            end
            GK.char.keys = 3
        end
        GK.db.keys = 3
    end
    -- v4: every name by itself, the account's data and then this character's
    local copies
    if (GK.db.keys or 0) < 4 then
        copies = {}
        PlainNames(GK.db, "", 0, copies)
        GK.db.keys = 4
    end
    if (GK.char.keys or 0) < 4 then
        PlainNames(GK.char, "", 0)
        if type(GK.char.guild) == "string" then GK.char.guild = PlainKey(GK.char.guild) end
        -- an unread letter for an order a store under "Guild-" had again (v3's, where no realm was known then)
        for i = #GK.char.letters, 1, -1 do
            local L = GK.char.letters[i]
            if copies and type(L) == "table" and L.kind == "order" and not L.read and type(L.o) == "string"
                and copies[L.o] then
                table.remove(GK.char.letters, i)
            end
        end
        -- one order kept under two of its poster's realms had a letter for each: by name alone they are one
        -- order, and it keeps its first letter
        local had, keep = {}, {}
        for _, L in ipairs(GK.char.letters) do
            local one = type(L) == "table" and type(L.o) == "string" and ((L.kind or "") .. "\1" .. L.o)
            if not (one and had[one]) then
                if one then had[one] = true end
                keep[#keep + 1] = L
            end
        end
        wipe(GK.char.letters)
        for i, L in ipairs(keep) do GK.char.letters[i] = L end
        GK.char.keys = 4
    end
end

--- A unit's player in that spelling (LIB.UnitKey, made GK.PlayerKey's), or nil.
function GK.UnitKey(unit)
    local key = LIB.UnitKey(unit)
    return key and GK.PlayerKey(key) or nil
end

--- "Level 35 Orc Rogue", from whatever we know.
function GK.Describe(l, c, r)
    local parts = {}
    if l then parts[#parts + 1] = l == -1 and "Level ??" or ("Level " .. l) end
    if r then parts[#parts + 1] = r end
    local cn = c and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[c]
    if cn then parts[#parts + 1] = cn end
    return table.concat(parts, " ")
end

-- Where we are is asked for at every nameplate that comes up, and only changes when we change area:
-- worked out once, and again when the client says the area changed.
local zoneNow, worldNow
local function PlaceChanged() zoneNow, worldNow = nil, nil end
LIB.On("PLAYER_ENTERING_WORLD", PlaceChanged)
LIB.On("ZONE_CHANGED_NEW_AREA", PlaceChanged)

function GK.Zone()
    if zoneNow == nil then
        zoneNow = GK.Clean((GetRealZoneText and GetRealZoneText()) or GetZoneText(), 40) or false
    end
    return zoneNow or nil
end

--- The open world: not a dungeon, raid or battleground, where the client hides who is who.
function GK.InWorld()
    if worldNow == nil then
        local inside = IsInInstance()
        worldNow = not inside
    end
    return worldNow
end

--- A battleground or an arena, where Grudgekeeper sleeps: "grudgekeeper kan IKKE være aktiv i
--- battlegrounds" (the owner, 2026-11-15). Nothing is counted there (GK.InWorld says so already), and
--- nothing is told: no warning, announcement, letter or letter icon, no Shame alert for the battleground's
--- raid. What the guild sends meanwhile is kept, and told once you are out. The instance type is the
--- client's own test for one (Blizzard_Game/Vanilla/EventImplementation.lua). Asked each time, never
--- cached: Announce.lua and Letters.lua ask on the very event that changes it, whichever handler runs first.
function GK.InBattleground()
    local inside, kind = IsInInstance()
    return (inside and (kind == "pvp" or kind == "arena")) and true or false
end

-- Spree tiers: the kill that makes a spree one of these numbers is a milestone. Grudgebound comes again at
-- every 5 after the last number. The key is the tier's art file name (Media/spree_<key>.tga).
GK.SPREE_TIERS = {
    { n = 3, key = "bloodied", name = "Bloodied" },
    { n = 5, key = "merciless", name = "Merciless" },
    { n = 7, key = "butcher", name = "Butcher" },
    { n = 10, key = "reaper", name = "Reaper" },
    { n = 15, key = "grudgebound", name = "Grudgebound" },
}

GK.SPREE_MIN = GK.SPREE_TIERS[1].n       -- the shortest spree that is one: below it nothing is told

--- The tier a spree of n is in (nil below the first), and whether n is the number that begins that tier.
local function TierFor(n)
    if type(n) ~= "number" then return nil end
    local tier
    for _, t in ipairs(GK.SPREE_TIERS) do
        if n >= t.n then tier = t end
    end
    if not tier then return nil end
    local last = GK.SPREE_TIERS[#GK.SPREE_TIERS]
    return tier, n == tier.n or (tier == last and n % 5 == 0)
end

--- The tier a spree of n is in now: its name and key, nil below the first tier.
function GK.SpreeTierOf(n)
    local tier = TierFor(n)
    if tier then return tier.name, tier.key end
end

--- The tier a spree of n begins, when n is a milestone: its name and key. nil for any other number.
function GK.SpreeTier(n)
    local tier, begins = TierFor(n)
    if tier and begins then return tier.name, tier.key end
end

--- "20s", "1g 50s" - for chat and the wire. Letters draw coins with GK.Coins.
function GK.MoneyText(copper)
    copper = math.floor(tonumber(copper) or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = g .. "g" end
    if s > 0 then out[#out + 1] = s .. "s" end
    if c > 0 or #out == 0 then out[#out + 1] = c .. "c" end
    return table.concat(out, " ")
end

-- GetCoinTextureString is not a global in Forever: it lives in C_CurrencyInfo. Called through pcall, plain
-- text when it isn't there. Looked up at each call - two table reads - so nothing is kept from before it was.
-- height: the coins' size, as the words beside them (the game's default 14).
function GK.Coins(copper, height)
    local coinString = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString
    if coinString then
        local ok, s = pcall(coinString, math.floor(tonumber(copper) or 0), height or 14)
        if ok and type(s) == "string" then return s end
    end
    return GK.MoneyText(copper)
end

function GK.Sound(kit)
    if not (GK.db and GK.db.sound) then return end
    local id = SOUNDKIT and SOUNDKIT[kit]
    if id then pcall(PlaySound, id, "Master") end
end

-- A sound you pick for a warning (a Shame player joining your group, 2026-11-08: "spille denne ... eller
-- andre lyder man kan velge i settings"). Keys: "off", "file:<ours>" for a file in Media, "kit:<name>" for
-- one of the game's own by its SOUNDKIT name (one this client lacks is left out), and "lsm:<name>" for a
-- sound another addon registered with LibSharedMedia - we embed no library, so those are there only when
-- something else has loaded it.
-- A file can be for one guild only, and then it is neither listed nor played anywhere else: "Måkke ta med
-- han" is a Norwegian clip, for the guild it was made for (the owner, 2026-11-09: "det burde nok ikke være
-- standard lyden med mindre du er medlem i yippyapp.. siden det er norskt", then "kankje bare yippyapp ahr
-- det som et valg i det hele tatt").
-- The war horn made for a target near and two God of War clips were taken out before 1.2.0 (the owner,
-- 2026-11-10: "ta de to ut. fjern warhorn"): a soundtrack's music has no place in a public package, and
-- the game's own sounds below say "warning" well enough.
local SOUND_FILES = {
    { "makke", "Måkke ta med han", "Interface\\AddOns\\Grudgekeeper\\Media\\makke.mp3", guild = "YippYapp" },
    -- the Grudgekeeper calling out each spree tier (ElevenLabs, 2026-11-12). spree: offered for the spree
    -- announcements only, never for a target near or a Shame player: "lydene er kun for spree og slikt, ikke
    -- for normalt" (the owner, 2026-11-12)
    { "voice_bloodied", "Voice: Bloodied", "Interface\\AddOns\\Grudgekeeper\\Media\\voice_bloodied.mp3", spree = true },
    { "voice_merciless", "Voice: Merciless", "Interface\\AddOns\\Grudgekeeper\\Media\\voice_merciless.mp3", spree = true },
    { "voice_butcher", "Voice: Butcher", "Interface\\AddOns\\Grudgekeeper\\Media\\voice_butcher.mp3", spree = true },
    { "voice_reaper", "Voice: Reaper", "Interface\\AddOns\\Grudgekeeper\\Media\\voice_reaper.mp3", spree = true },
    { "voice_grudgebound", "Voice: Grudgebound", "Interface\\AddOns\\Grudgekeeper\\Media\\voice_grudgebound.mp3",
      spree = true },
}
-- A moment told on screen and the setting that is its sound, on or off (Announce.lua); a spree's step is spreeSound.
GK.MOMENT_SOUND = { rank = "rankSound", order = "orderSound", revenge = "revengeSound", grudge = "grudgeSound",
    deathlist = "grudgeSound",
    ended = "endedSound", tormentor = "tormentorSound" }

--- Whether one of our files is ours to offer: one for a guild only while we are in it (in any case), and
--- not while the client can't say which guild that is.
local function Offered(s)
    if not s.guild then return true end
    local mine = GetGuildInfo and GetGuildInfo("player")
    return type(mine) == "string" and not Secret(mine) and GK.SameGuild(mine, s.guild)
end
-- The game's own, grouped as the menu lists them. "flere av lydene er dårlige, noen funker ikke. men du fant jo
-- masse sound effects når vi bygde lydene for streaks ... forskjellige horns og sånn. det er kanskje artigere enn
-- kjedelige lyder som ikke gir like mye mening" (the owner, 2026-11-22). There were seventeen kits, and the live
-- client's SoundKit (build 71037) has the chime at VolumeFloat 0.01, the map ping 34 dB under full, the alarm 23.
-- The four left are the ones a default plays. The rest are files by FileDataID (PlaySoundFile takes the number and
-- plays the client's own file, so none ships): the effect lab's, every one the owner liked there among them, and a
-- few roars and a horn more. Each was fetched from that build and decoded: none quieter than 16 dB under full.
-- A name is 17 letters at most: the narrowest sound dropdown holds no more.
local HORNS, BELLS, ROARS, BLOWS, BREAKS, RUMBLES, SIGNALS = "Horns and drums", "Bells and gongs", "Roars",
    "Blows and blades", "Breaking", "Rumbles", "Signals"
local URGENT = "Urgent"
local SOUND_GROUPS = { URGENT, HORNS, BELLS, ROARS, BLOWS, BREAKS, RUMBLES, SIGNALS }
-- The urgent ones, first: "hvis kill order target er nære, så må det være litt urgency ... mange av de bjellene og
-- roars og horns osv et veldig tamme" (the owner, 2026-11-22). Each is two to four of the client's files so close
-- that they are one sound, { seconds in, FileDataID }. Mixed from build 71037 and measured, they reach -2.8 to -5.9
-- LUFS momentary, within a fifth of a second; the Battleground horn reaches -10.8. The ten that measured tamest are
-- `tame`: out of the menu, unless picked, and still played where a pick or the addon itself names one.
local SOUND_CALLS = {
    { "red_alert", "Red alert", parts = { { 0, 568165 }, { 0.30, 3512969 } } },          -- the flag taken, and a bell
    { "alarm_bells", "Alarm bells", parts = { { 0, 3512969 }, { 0.36, 3512971 }, { 0.72, 3512974 } } },
    { "attack_alarm", "Attack alarm", parts = { { 0, 1487138 }, { 0.02, 775389 }, { 0.45, 568165 } } },
    { "war_call", "War call", parts = { { 0, 1487138 }, { 0.05, 4191279 } } },           -- an alarm drum, and a horn
    { "battle_trumpet", "Battle trumpet", parts = { { 0, 1487138 }, { 0.02, 598187 } } },
    { "under_attack", "Under attack", parts = { { 0, 1487139 }, { 0.05, 568165 } } },
    { "horn_rush", "War horn rush",
      parts = { { 0, 569112 }, { 0, 1487138 }, { 0.30, 1487139 }, { 0.55, 1487138 } } },
    { "ambush", "Ambush", parts = { { 0, 1603948 }, { 0.10, 6908124 } } },
    { "battle_roar", "Battle roar", parts = { { 0, 1487138 }, { 0.05, 2118810 }, { 0.40, 1487139 } } },
    { "heartbeat", "Heartbeat", parts = { { 0, 1630809 }, { 0.50, 1630809 }, { 0.85, 568312 } } },
}
local SOUND_KITS = {
    { "PVP_THROUGH_QUEUE", "Battleground horn", HORNS },
    { "UI_GARRISON_TOAST_INVASION_ALERT", "Invasion alert", SIGNALS },
    { "UI_BATTLEGROUND_COUNTDOWN_FINISHED", "Countdown", SIGNALS },
    { "UI_PVP_HONOR_PRESTIGE_RANK_UP", "Rank up", SIGNALS },
}
local SOUND_GAME = {
    { 568959, "Horde horn", HORNS },         -- PVPFlagCapturedHorde
    { 569112, "Horde war horn", HORNS },     -- PVPWarningHorde
    { 568320, "Alliance war horn", HORNS, tame = true },  -- PVPWarningAlliance
    { 567084, "Horn of Echeyakee", HORNS },  -- G_HornofEcheyakee
    { 566064, "Dwarven horn", HORNS, tame = true },       -- DwarfHorn
    { 4854661, "Swoghorn", HORNS, tame = true },          -- Swoghorn_cast
    { 566719, "Zeppelin horn", HORNS, tame = true },      -- ZeppelinHorn
    { 568812, "Bloodlust", HORNS, tame = true },          -- bloodlust_player_cast_head
    { 566027, "Tribal bell", BELLS, tame = true },        -- BellTollTribal: a kill order fulfilled's call
    { 565853, "Horde bell", BELLS },         -- BellTollHorde
    { 566564, "Alliance bell", BELLS },      -- BellTollAlliance
    { 3512970, "Great bell", BELLS },        -- Valkyr_Bell_Large
    { 669384, "Breaking bell", BELLS },      -- DivineBell_Ring_Destroyed
    { 565564, "Troll gong", BELLS },         -- G_GongTroll01: a Shame player's, to begin with
    { 565945, "Blackrock gong", BELLS },     -- ShieldGongCustom0_06
    { 930379, "Gronn roar", ROARS },         -- MON_GRONN_BattleRoar_02
    { 645422, "Sha roar", ROARS },           -- MON_Sha_Boss_BattleRoar
    { 1034591, "Elemental roar", ROARS },    -- MON_FireElementalDraenor_BattleRoar_03
    { 4565235, "Bronze blow", BLOWS },       -- Magic_Bronze_Impact_Large_02
    { 1345549, "Heavy rock", BLOWS },        -- FX_RockImpact_Heavy_Short_01
    { 1258136, "Cleave", BLOWS },            -- Spell_WR_Cleave_Cast_01
    { 1267929, "Mortal Strike", BLOWS },     -- Spell_WR_MortalStrike_Cast_01
    { 1093788, "Whirlwind", BLOWS },         -- SPELL_WR_WHIRLWIND_01
    { 1036057, "Chain snap 1", BREAKS },     -- FX_Chain_Break_Large_01
    { 1036058, "Chain snap 2", BREAKS },     -- FX_Chain_Break_Large_02
    { 596411, "Breaking pillar", BREAKS, tame = true },   -- Deepholm MineralColumn
    { 930442, "Rock blast 1", BREAKS },      -- FX_Explosion_Rock_Debris_02
    { 930444, "Rock blast 2", BREAKS },      -- FX_Explosion_Rock_Debris_03
    { 565728, "Cracking coral", BREAKS, tame = true },    -- AbyssalCoralChunkCeilingBreak
    { 568874, "Earthquake", RUMBLES, tame = true },       -- EarthquakeCameraShake
    { 838830, "Thunder", RUMBLES, tame = true },          -- MWThunderRumble01
}

--- Whether a pick is one of ours that left the package: a file (the war horn, the God of War clips) or a
--- kit taken off the list (HARDCORE_DUEL, which plays nothing on Forever). Only our own: another addon's
--- sound may simply not be loaded yet at login.
local function Gone(pick)
    if type(pick) ~= "string" then return false end
    local kind, name = pick:match("^(%a+):(.+)$")
    local list = (kind == "file" and SOUND_FILES) or (kind == "kit" and SOUND_KITS) or (kind == "game" and SOUND_GAME)
        or (kind == "call" and SOUND_CALLS)
    if not list then return false end
    if kind == "game" then name = tonumber(name) end
    for _, s in ipairs(list) do
        if s[1] == name then return false end
    end
    return true
end

--- Whether a pick is one of the Grudgekeeper's voice lines, which are for the spree announcements only.
local function SpreeOnly(pick)
    local name = type(pick) == "string" and pick:match("^file:(.+)$")
    if not name then return false end
    for _, s in ipairs(SOUND_FILES) do
        if s[1] == name then return s.spree == true end
    end
    return false
end

--- A gone pick goes back to the default: it would play the fallback, or nothing, under a dropdown showing
--- nothing picked. So does a voice line picked for a target near or a Shame player (a build that offered
--- them there): their pickers don't list it.
function GK.ForgetGoneSounds(db)
    for field, default in pairs({ nearSound = defaults.nearSound, shameSound = defaults.shameSound }) do
        if Gone(db[field]) or SpreeOnly(db[field]) then db[field] = default end
    end
    -- What was told on screen had a sound to pick until 2026-11-22. A pick goes, and None is that moment's box
    -- off - but not a spree ended's, which stood on None out of the box with its effect's sounds playing.
    local picks = db.spreeSounds
    db.spreeSounds = nil
    if type(picks) ~= "table" then return end
    local silenced = 0
    for _, t in ipairs(GK.SPREE_TIERS) do
        if picks[t.key] == "off" then silenced = silenced + 1 end
    end
    if silenced == #GK.SPREE_TIERS then db.spreeSound = false end
    for key, setting in pairs(GK.MOMENT_SOUND) do
        if key ~= "ended" and picks[key] == "off" then db[setting] = false end
    end
end

local function SharedMedia()
    if type(LibStub) ~= "table" then return nil end
    local ok, lib = pcall(LibStub, "LibSharedMedia-3.0", true)
    return ok and type(lib) == "table" and type(lib.HashTable) == "function" and lib or nil
end

local function SharedSounds()
    local lsm = PlaySoundFile and SharedMedia()
    if not lsm then return nil end
    local ok, sounds = pcall(lsm.HashTable, lsm, "sound")
    return ok and type(sounds) == "table" and sounds or nil
end

--- Every sound there is to pick, { { key, label } }: none, ours, the game's, then other addons' by name.
--- Never the Grudgekeeper's voice lines: a pick plays it, and hearing them ahead spoils the sprees (2026-11-22).
function GK.SoundChoices()
    local list = { { "off", "None" } }
    for _, s in ipairs(SOUND_FILES) do
        if Offered(s) and not s.spree then list[#list + 1] = { "file:" .. s[1], s[2] } end
    end
    for _, c in ipairs(SOUND_CALLS) do list[#list + 1] = { "call:" .. c[1], c[2], group = URGENT } end
    local near, shame = GK.db and GK.db.nearSound, GK.db and GK.db.shameSound
    for _, group in ipairs(SOUND_GROUPS) do
        for _, s in ipairs(SOUND_KITS) do
            if s[3] == group and SOUNDKIT and SOUNDKIT[s[1]] then
                list[#list + 1] = { "kit:" .. s[1], s[2], group = group }
            end
        end
        for _, s in ipairs(SOUND_GAME) do
            local key = "game:" .. s[1]
            if s[3] == group and (not s.tame or key == near or key == shame) then
                list[#list + 1] = { key, s[2], group = group }
            end
        end
    end
    local shared = SharedSounds()
    if shared then
        local names = {}
        for name in pairs(shared) do
            if type(name) == "string" and name ~= "None" then names[#names + 1] = name end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            list[#list + 1] = { "lsm:" .. name, name, group = "Other addons", sub = true }
        end
    end
    return list
end

--- One of the urgent ones: its first file now and the rest on their beats, under one handle a preview can stop
--- (StopPlaying). False when the first won't play: then the caller's fallback does.
local function PlayCall(call)
    if not PlaySoundFile then return false end
    local run = { handles = {} }
    local function Strike(file)
        if run.stopped then return false end
        local ok, played, handle = pcall(PlaySoundFile, file, "Master")
        if not (ok and played) then return false end
        if handle then run.handles[#run.handles + 1] = handle end
        return true
    end
    if not Strike(call.parts[1][2]) then return false end
    for i = 2, #call.parts do
        local at, part = call.parts[i][1], call.parts[i][2]
        if at > 0 then C_Timer.After(at, function() Strike(part) end) else Strike(part) end
    end
    return true, run
end

--- Stop what GK.PlayChoice started: a sound's handle, or an urgent one's, whose later files then never start.
local function StopPlaying(handle)
    if type(handle) == "table" then
        handle.stopped = true
        if StopSound then
            for _, h in ipairs(handle.handles or {}) do pcall(StopSound, h) end
        end
    elseif handle and StopSound then
        pcall(StopSound, handle)
    end
end

--- Play a picked sound, whatever the Sounds setting says (the caller asks it). Returns true when the game
--- took it, false for none picked or one that can't be played - a file gone, a sound pack uninstalled.
function GK.PlayChoice(key)
    if type(key) ~= "string" then return false end
    local kind, name = key:match("^(%a+):(.+)$")
    local file
    if kind == "call" then
        for _, c in ipairs(SOUND_CALLS) do
            if c[1] == name then return PlayCall(c) end
        end
        return false
    end
    if kind == "kit" then
        local id = SOUNDKIT and SOUNDKIT[name]
        if not id then return false end
        local ok, played, handle = pcall(PlaySound, id, "Master")
        if not ok then return false end
        return played ~= false, handle
    elseif kind == "file" then
        for _, s in ipairs(SOUND_FILES) do
            if s[1] == name and Offered(s) then file = s[3] end
        end
    elseif kind == "game" then
        for _, s in ipairs(SOUND_GAME) do
            if s[1] == tonumber(name) then file = s[1] end
        end
    elseif kind == "lsm" then
        local shared = SharedSounds()
        file = shared and shared[name]
    end
    if not (file and PlaySoundFile) then return false end
    local ok, played, handle = pcall(PlaySoundFile, file, "Master")
    if not (ok and played) then return false end
    return true, handle
end

local previewing                          -- the handle of the sound last tried in the settings
--- A sound tried in the settings: the one tried before it stops, as they run up to seven seconds.
function GK.PreviewSound(key)
    if previewing then StopPlaying(previewing) end
    local _, handle = GK.PlayChoice(key)
    previewing = handle
end

--- The sound of a target near (a tracked enemy's, and the watched guild's): the one picked, the horn when it
--- can't be played - a warning never goes silent because a file went missing - and nothing for None or with
--- Warnings' Play sounds off.
function GK.NearSound()
    if not GK.db or GK.db.warnSounds == false then return end
    local key = GK.db.nearSound or defaults.nearSound
    if key == "off" then return end
    if not GK.PlayChoice(key) then GK.PlayChoice("kit:PVP_THROUGH_QUEUE") end
end

--- The sound of one in your Death Note targeting you (Sightings.lua): the one picked on its row, the horn when it
--- can't be played, nothing for None or with Warnings' Play sounds off.
function GK.TargetSound()
    if not GK.db or GK.db.warnSounds == false then return end
    local key = GK.db.targetSound or defaults.targetSound
    if key == "off" then return end
    if not GK.PlayChoice(key) then GK.PlayChoice("kit:PVP_THROUGH_QUEUE") end
end

--- The sound a Shame player joining plays: the one picked in the settings, else the Alliance bell. "auto" - the
--- clip of a guild we are in, or the troll gong - was where it started until 1.12.0 moved everyone to the bell.
function GK.ShameSoundKey()
    local key = GK.db and GK.db.shameSound
    if type(key) == "string" and key ~= "auto" then return key end
    return defaults.shameSound
end

--- Something changed that a window may show. Every guild message calls this, and at login they come
--- by the hundred, so the windows, the nameplate skulls and the mailbox button hear about it ONCE per
--- burst, a moment later, rather than once per message (each of them used to start its own timer per
--- message). GK.version counts every change at once, for anything that keeps an answer until the
--- data changes (the tooltip line).
local changePending = false
GK.version = 0
local function FireChanged()
    changePending = false
    LIB.Fire("GRUDGEKEEPER_CHANGED")
end
function GK.Changed()
    GK.version = GK.version + 1
    if changePending then return end
    changePending = true
    C_Timer.After(0.2, FireChanged)
end

-- ---------------------------------------------------------------------------
-- Our own record
-- ---------------------------------------------------------------------------
local MAX_FOES, MAX_LOG = 400, 200

--- The guild's shared store: the leaderboard, its kill orders, who is wanted, the feed. Guildless,
--- it is a store of your own. While the client hasn't said which guild yet (early at login) it is the
--- last one this character was in, so nothing lands in a store of its own for a minute.
function GK.Store()
    local key = LIB.GuildKey()
    -- "Guild-" is a guild key with no realm, from a lib or a session that had none (2026-11-20): never kept,
    -- never used - it was a new empty store, and every order the guild passed on came again as a letter
    if key and key:sub(-1) == "-" then key = nil end
    if key then GK.char.guild = key
    elseif IsInGuild() and type(GK.char.guild) == "string" and GK.char.guild:sub(-1) ~= "-" then key = GK.char.guild end
    key = key or "-"
    local g = GK.db.guilds[key]
    if not g then
        g = { board = {}, orders = {}, wanted = {}, slain = {}, tormentors = {}, enemyGuilds = {}, feed = {}, people = {},
            nextId = 1 }
        GK.db.guilds[key] = g
    end
    if not g.slain then g.slain = {} end      -- a store from before the guild kept its tally
    if not g.tormentors then g.tormentors = {} end   -- and from before it counted who kills us
    if not g.enemyGuilds then g.enemyGuilds = {} end -- and from before it knew an enemy's guild (Guild.lua, 2026-11-22)
    -- the notes (Notes.lua), here from the start: made by the first read instead, an empty one turned up
    -- after the test panel had put the store back (smoke_grudgekeeper, 2026-11-05)
    if not g.people then g.people = {} end
    return g
end

-- Tormentors: an enemy who has killed 3 or more of the guild since any of us last killed them. Each client
-- counts from what it hears (our deaths, a guildie's D) and clears the count at any kill of theirs (ours, or
-- a guildie's K), so two clients that were offline at different times differ a little. That is fine.
local MAX_TORMENTORS = 200
local TORMENTOR_AT = 3

--- One more of the guild killed by this enemy. Their count after it. At most MAX_TORMENTORS enemies are
--- kept: when a new one comes to a full table, the one with the smallest count goes.
function GK.TormentorGrew(key)
    local t = GK.Store().tormentors
    if not t[key] then
        local n, least, leastKey = 0, nil, nil
        for k, v in pairs(t) do
            n = n + 1
            if not least or v < least then least, leastKey = v, k end
        end
        if n >= MAX_TORMENTORS and leastKey then t[leastKey] = nil end
    end
    t[key] = (t[key] or 0) + 1
    return t[key]
end

--- The count of guildies this enemy killed, when it was 3 or more, so the kill that ends it can be told; nil
--- otherwise. The count starts over either way (a count of 0 is no entry, which keeps the table small).
function GK.TormentorEnded(key)
    local t = GK.Store().tormentors
    local n = t[key]
    t[key] = nil
    return n and n >= TORMENTOR_AT and n or nil
end

--- Our record of one enemy player, made when first needed. At most MAX_FOES: the one met longest ago
--- goes first.
function GK.Foe(key, info)
    local foes = GK.char.foes
    local f = foes[key]
    if not f then
        f = { k = 0, d = 0, hits = {}, last = time() }
        foes[key] = f
        local n, oldest, oldKey = 0, nil, nil
        local tracked = GK.TrackedList and GK.TrackedList()
        for k2, v in pairs(foes) do
            n = n + 1
            -- never one in your Death Note: their score is what its row says
            if k2 ~= key and not (tracked and tracked[k2]) and (not oldest or (v.last or 0) < oldest) then
                oldest, oldKey = v.last or 0, k2
            end
        end
        if n > MAX_FOES and oldKey then foes[oldKey] = nil end
    end
    if info then
        f.n = info.n or f.n
        f.c = info.c or f.c
        f.r = info.r or f.r
        f.l = info.l or f.l
    end
    f.last = time()
    return f
end

function GK.AddLog(e)
    local log = GK.char.log
    table.insert(log, 1, e)
    for i = #log, MAX_LOG + 1, -1 do log[i] = nil end
end

--- The one who has killed you most: key and record, or nil.
function GK.Nemesis()
    local best, bestKey
    for key, f in pairs(GK.char.foes) do
        if (f.d or 0) > 0 and (not best or f.d > best.d) then best, bestKey = f, key end
    end
    return bestKey, best
end

--- The guild's leaderboard with you in it, best first: { { who, p, k, d, a, l, c, total, me } }. a is
--- nil for a guildie whose client sends no assists (the released one).
--- weekly: this week's score; a guildie whose last word was from another week has none this week,
--- and one with nothing this week isn't listed. total is all-time points either way (for the title).
-- Guildies under this level are left off the board: alts parked in a starting zone filled it with rows of
-- nothing ("leaderboard kan kanskje filtrere ut folk under lvl 10 elns?", the owner, 2026-11-07). Their
-- score is kept, and they are back on it at 10. A row that never said its level stays; you always do.
local BOARD_MIN_LEVEL = 10

function GK.Board(weekly)
    local list, me, week = {}, LIB.Me(), GK.WeekId()
    for who, r in pairs(GK.Store().board) do
        if who ~= me and (r.l or BOARD_MIN_LEVEL) >= BOARD_MIN_LEVEL then
            local p, k, d, a = r.p or 0, r.k or 0, r.d or 0, r.a
            if weekly then
                if r.wid == week then p, k, d, a = r.wp or 0, r.wk or 0, r.wd or 0, r.wa
                else p, k, d, a = 0, 0, 0, r.a and 0 end
            end
            if not weekly or p > 0 or k > 0 or d > 0 or (a or 0) > 0 then
                list[#list + 1] = { who = who, p = p, k = k, d = d, a = a, l = r.l, c = r.c, total = r.p or 0,
                    rf = r.rf, sx = r.sx }
            end
        end
    end
    local _, class = UnitClass("player")
    local _, raceFile = UnitRace("player")
    local c, w = GK.char, GK.Week()
    list[#list + 1] = { who = me or "?", p = weekly and w.p or c.points, k = weekly and w.k or c.kills,
        d = weekly and w.d or c.deaths, a = weekly and (w.a or 0) or (c.assists or 0), l = UnitLevel("player"), c = class, total = c.points, me = true,
        rf = raceFile, sx = UnitSex("player") }
    table.sort(list, function(a, b)
        if a.p ~= b.p then return a.p > b.p end
        if a.k ~= b.k then return a.k > b.k end
        return a.who < b.who
    end)
    return list
end

--- Your place on the guild's board (this week's, with weekly), and how many are on it.
function GK.MyRank(weekly)
    local list = GK.Board(weekly)
    for i, r in ipairs(list) do
        if r.me then return i, #list end
    end
    return #list, #list
end

-- ---------------------------------------------------------------------------
-- Minimap button, addon compartment, slash command
-- ---------------------------------------------------------------------------
local function OnIconClick(button)
    if button == "RightButton" then GK.OpenOptions() else GK.ToggleWindow() end
end

local function TooltipLines(add)
    add(TAG)
    local rank, of = GK.MyRank()
    add(("%d points - %d kills, %d assists, %d deaths"):format(GK.char.points, GK.char.kills, GK.char.assists or 0,
        GK.char.deaths), 1, 1, 1)
    if of > 1 then add(("#%d of %d in the guild"):format(rank, of), 1, 0.82, 0) end
    local open = GK.OpenOrders and #GK.OpenOrders() or 0
    if open > 0 then add(("%d open kill order%s"):format(open, open == 1 and "" or "s"), 1, 0.5, 0.4) end
    add("Left-click: open Grudgekeeper", 0.8, 0.8, 0.8)
    add("Right-click: settings", 0.8, 0.8, 0.8)
end

function Grudgekeeper_OnAddonCompartmentClick(_, button) OnIconClick(button) end
function Grudgekeeper_OnAddonCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    TooltipLines(function(...) GameTooltip:AddLine(...) end)
    GameTooltip:Show()
end
function Grudgekeeper_OnAddonCompartmentLeave() GameTooltip:Hide() end

-- A minimap button of its own, straight through LibDBIcon: Grudgekeeper is not one of the YippYapp
-- addons, so it doesn't sit behind their shared button.
local ICON = "Interface\\AddOns\\Grudgekeeper\\Media\\minimap"
local function RegisterMinimap()
    local ldb, dbicon = LibStub("LibDataBroker-1.1", true), LibStub("LibDBIcon-1.0", true)
    if not (ldb and dbicon) then return end
    local obj = ldb:GetDataObjectByName("Grudgekeeper")
        or ldb:NewDataObject("Grudgekeeper", { type = "launcher", icon = ICON, label = "Grudgekeeper" })
    if not obj then return end
    obj.OnClick = function(_, button) OnIconClick(button) end
    obj.OnTooltipShow = function(tt) TooltipLines(function(...) tt:AddLine(...) end) end
    if not dbicon:IsRegistered("Grudgekeeper") then dbicon:Register("Grudgekeeper", obj, GK.db.minimap) end
end

function GK.SetMinimapShown(on)
    GK.db.minimap.hide = not on
    local dbicon = LibStub("LibDBIcon-1.0", true)
    if not dbicon then return end
    if on then dbicon:Show("Grudgekeeper") else dbicon:Hide("Grudgekeeper") end
end

local function Help()
    print(TAG .. " v" .. GK.addonVersion .. " commands:")
    print("  /grudge  - open the window: kill orders, the leaderboard, your Death Note, grudges")
    print("  /grudge post  - write a kill order on your target (no enemy targeted: it asks who)")
    print("  /grudge letters  - read your letters")
    print("  /grudge test  - four sample letters, to see what they look like")
    print("  /grudge news  - the patch notes of this version")
    print("  /grudge arrange  - put the letter icon, the splash and the toasts where you want them")
    print("  /grudge spree  - show a sample spree splash and toast (or: spree fulfilled, spree tormentor, spree revenge, spree grudge)")
    print("  /grudge rank  - show a sample new-title splash and toast (or: rank nemesis, rank all)")
    print("  /grudge options  - open the settings")
    print("  /grudge guild  - officers: track an enemy guild by its name")
end

SLASH_GRUDGEKEEPER1 = "/grudge"
SLASH_GRUDGEKEEPER2 = "/grudgekeeper"
SlashCmdList.GRUDGEKEEPER = function(msg)
    local cmd = strtrim((msg or ""):lower())
    if cmd == "" then
        GK.ToggleWindow()
    elseif cmd == "orders" or cmd == "hitlist" then
        GK.OpenWindow(1)
    elseif cmd == "board" or cmd == "leaderboard" then
        GK.OpenWindow(2)
    elseif cmd == "post" then
        GK.PostOnTarget()
    elseif cmd == "letters" or cmd == "read" then
        GK.OpenLetters()
    elseif cmd == "test" then
        GK.SampleLetters()
    elseif cmd == "news" or cmd == "patch notes" or cmd == "patchnotes" then
        GK.OpenPatchNotes()
    elseif cmd == "arrange" or cmd == "notice" then
        -- the letter icon, the splash and the toasts (Move.lua); "move" is the notes' (NotesUI.lua)
        if GK.ToggleMover then GK.ToggleMover() end
    elseif cmd == "notice reset" then
        GK.NoticeReset()
    elseif cmd == "spree" or cmd:match("^spree ") then
        GK.AnnounceSample(cmd:match("^spree (%S+)"))   -- a sample splash and toast (Announce.lua)
    elseif cmd == "rank" or cmd:match("^rank ") then
        GK.RankSample(cmd:match("^rank (.+)$"))         -- a new title's splash and toast (Announce.lua)
    elseif cmd == "options" or cmd == "settings" then
        GK.OpenOptions()
    elseif cmd == "guild" then
        -- the guild on watch, typed in (Pick.lua): for an officer or the guild master, as on the ledger.
        -- Not "watch": that is the Shame list's word (NotesUI.lua)
        if GK.CanWatchGuild() then GK.OpenPicker("guild")
        else print(TAG .. ": only an officer or the guild master can track a guild.") end
    elseif cmd == "owe" or cmd:match("^owe ") then
        -- the test panel's debt to a name and money you give, written in full at a mailbox (Debug.lua)
        if GK.TestOwe then GK.TestOwe(strtrim(msg or ""):sub(4)) else Help() end
    elseif cmd == "newer" and GK.TestNewer then
        GK.TestNewer()                -- a guildie with a newer Grudgekeeper, its line in chat (Debug.lua)
    elseif cmd == "debug meter" then
        GK.MeterProbe()               -- the game's damage meter after a fight (Kills.lua)
    elseif cmd == "debug" then
        if GK.OpenDebug then GK.OpenDebug() else GK.Debug() end
    elseif cmd == "shots" and GK.OpenShots then
        GK.OpenShots()                -- pictures for the store page, with a made-up guild (Shots.lua)
    else
        Help()
    end
end

--- /grudge debug: what the addon can see right now, for telling us what this client allows.
function GK.Debug()
    local inside, kind = IsInInstance()
    print(("%s debug: faction %s, guild %s, in instance %s (%s)"):format(TAG, tostring(UnitFactionGroup("player")),
        tostring(LIB.GuildKey()), tostring(inside), tostring(kind)))
    if LIB.CommStats then
        local sent, received, refused = LIB.CommStats(GK.PREFIX)
        print(("  messages: %s sent, %s received, %s refused"):format(tostring(sent), tostring(received), tostring(refused)))
    end
    if GK.SeenCount then print(("  enemy players seen this session: %d"):format(GK.SeenCount())) end
    if GK.LastDeathDebug then print("  last death: " .. GK.LastDeathDebug()) end
    if GK.LastAssistDebug then print("  last assist: " .. GK.LastAssistDebug()) end
    -- each PC's part of the score, this one's first by its mark (Guild.lua's "One character, more than one PC")
    if GK.MyPartsText then print(("  this PC %s; parts: %s"):format(tostring(GK.char.pc), GK.MyPartsText() or "none")) end
    local s = GK.Store()
    local n = 0
    for _ in pairs(s.board) do n = n + 1 end
    print(("  board: %d guildies; open orders: %d"):format(n, GK.OpenOrders and #GK.OpenOrders() or 0))
end

-- ---------------------------------------------------------------------------
-- The two skins (GK.db.look): the Grudgekeeper's parchment, and the game's own classic dark panels in gold
-- and white, as Guild Grudge had them ("lage en classic stil som setter bakgrunner osv til classic
-- fargene og ikke parchments" - "vi vil ha 2 skins", the owner, 2026-11-06). They dress the windows in the
-- game's frame: the ledger, the note and the who-picker. The letters, the kill order's scroll and the
-- profile cards are the Grudgekeeper's own paper in both.
-- Whatever a skin dresses is drawn in GK.INK, GK.FADED or GK.BLOOD, through GK.Ink and GK.Paint, which
-- remember what they drew: a skin writes its colours into those three tables (every file holds the same
-- tables) and GK.SetLook draws it all again, then calls what GK.OnLook registered - a window's
-- background, its layout - so the switch needs no /reload.
--   title, titleScale: the face and size titles and names are set in (Morpheus on parchment; the game's
--   own Friz Quadrata, a little smaller, in classic). shadow: classic text has the game's drop shadow.
--   wash: the chosen, hovered and own rows' tint. stripe, rule: every other row, the ruled lines.
-- ---------------------------------------------------------------------------
GK.TITLE_FONT, GK.TEXT_FONT = "Fonts\\MORPHEUS.ttf", "Fonts\\FRIZQT__.TTF"
-- Every button with words on it (GK.MakeButton): the game's newer three-piece red button (ThreeSliceButton-
-- Template.xml, atlas 128-RedButton), which Forever draws in its own bronze (128-redbutton-*-c60) and its
-- friends window wears (SocialUIActionButtonTemplate) - in classic. On parchment the old red is drawn over it.
GK.BUTTON = "SharedButtonTemplate"
GK.LOOKS = {
    -- faded: 0.35/0.25/0.15 read too light on the toned parchment in a list (2026-11-06)
    parchment = { ink = { 0.2, 0.12, 0.05 }, faded = { 0.29, 0.2, 0.11 }, blood = { 0.47, 0.06, 0.04 },
        title = GK.TITLE_FONT, titleScale = 1, shadow = false, wash = { 0.6, 0.12, 0.05 },
        stripe = { 0.35, 0.2, 0.05, 0.07 }, rule = { 0.42, 0.33, 0.22, 0.6 } },
    classic = { ink = { 1, 1, 1 }, faded = { 0.66, 0.66, 0.66 }, blood = { 1, 0.82, 0 },
        title = GK.TEXT_FONT, titleScale = 0.85, shadow = true, wash = { 1, 0.82, 0 },
        stripe = { 1, 1, 1, 0.035 }, rule = { 0.62, 0.52, 0.32, 0.55 } },
}
GK.LOOK = GK.LOOKS.parchment
GK.INK, GK.FADED, GK.BLOOD = { 0.2, 0.12, 0.05 }, { 0.29, 0.2, 0.11 }, { 0.47, 0.06, 0.04 }

--- Put a skin's colours in place, without drawing anything again (at login, before any window is built).
function GK.UseLook(name)
    GK.LOOK = GK.LOOKS[name] or GK.LOOKS.parchment
    for i = 1, 3 do
        GK.INK[i], GK.FADED[i], GK.BLOOD[i] = GK.LOOK.ink[i], GK.LOOK.faded[i], GK.LOOK.blood[i]
    end
end

function GK.Classic() return GK.LOOK == GK.LOOKS.classic end

-- A player's name in their class's colour, in the Classic skin, as the game writes names on its own dark
-- panels ("tenker vi at navn skal være i class color?", the owner, 2026-11-14). Never on the parchment: every
-- class colour reads there at 1.0 to 2.5 against the 4.5 small text needs, Warrior's and Druid's at exactly
-- the parchment's own lightness, where the ink names are written in reads at 6.3 (chrclasses, build 70938,
-- against sheet_single as Window.lua tones it - DECISIONS.md). So no setting: the skin is the choice.
local classInk = {}

--- The colour a name of this class is written in - { r, g, b }, as GK.Ink takes it - or nil: on parchment,
--- or for a class the game has no colour for.
function GK.ClassInk(class)
    if not (class and GK.Classic()) then return nil end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not (type(c) == "table" and c.r and c.g and c.b) then return nil end
    local ink = classInk[class]
    if not ink then
        ink = { c.r, c.g, c.b }
        classInk[class] = ink
    end
    return ink
end

--- A name inside a line of text, in its class's colour where GK.ClassInk has one: the game's colour codes
--- round it, which a line in another colour keeps for that name alone. As it is where there is none.
function GK.InClass(text, class)
    local c = GK.ClassInk(class)
    if not (c and type(text) == "string") then return text end
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
        math.floor(c[3] * 255 + 0.5), text)
end

-- ---------------------------------------------------------------------------
-- Every alphabet a name is written in
-- ---------------------------------------------------------------------------
-- Friz Quadrata and Morpheus hold the Latin letters only, so a character named in Cyrillic was drawn as
-- nothing in our windows ("vi må ha support for russiske bokstaver ... fordi noen characters har slike
-- navn", the owner, 2026-11-07). The game's own fonts are families with one file per alphabet
-- (Blizzard_Fonts_Shared/GameFonts.xml), and ours are too: CreateFontFamily (FontDocumentation.lua) makes
-- one per face, size and flags, the first time it is asked for. Without it, the face alone.
local OTHER_ALPHABETS = {
    { "russian", { ["Fonts\\MORPHEUS.ttf"] = "Fonts\\MORPHEUS_CYR.ttf" }, "Fonts\\FRIZQT___CYR.TTF" },
    { "korean", {}, "Fonts\\2002.TTF" },
    { "simplifiedchinese", {}, "Fonts\\ARKai_T.ttf" },
    { "traditionalchinese", {}, "Fonts\\blei00d.TTF" },
}
local families, familyCount = {}, 0

local function Family(file, size, flags)
    if not CreateFontFamily then return nil end
    local id = file .. "|" .. size .. "|" .. flags
    local family = families[id]
    if family == nil then
        local members = { { alphabet = "roman", file = file, height = size, flags = flags } }
        for _, a in ipairs(OTHER_ALPHABETS) do
            members[#members + 1] = { alphabet = a[1], file = a[2][file] or a[3], height = size, flags = flags }
        end
        familyCount = familyCount + 1
        local ok, made = pcall(CreateFontFamily, "GrudgekeeperFont" .. familyCount, members)
        family = ok and made or false
        families[id] = family
    end
    return family or nil
end

--- A text's face and size, in a family that also writes Cyrillic, Korean and Chinese names; the face
--- alone on a client without font families.
function GK.SetFont(fs, file, size, flags)
    flags = flags or ""
    local family = Family(file, size, flags)
    if family then fs:SetFontObject(family) else fs:SetFont(file, size, flags) end
end

--- Lower case for the letters names are written in: a to z, the Latin-1 letters (Ø to ø) and Cyrillic (Ж
--- to ж). string.lower knows a to z only, so "ПЕТЯ" never found "Петя" - and under a Latin-1 locale it
--- lowers the lead byte of a UTF-8 letter too (0xD0 to 0xF0: the smoke test's Lua did), breaking it. So A
--- to Z by their bytes, never by the locale.
function GK.Lower(s)
    s = s:gsub("[A-Z]", function(c) return string.char(c:byte() + 32) end)
    s = s:gsub("\195([\128-\158])", function(b) if b ~= "\151" then return "\195" .. string.char(b:byte() + 32) end end)
    s = s:gsub("\208([\144-\159])", function(b) return "\208" .. string.char(b:byte() + 32) end)
    s = s:gsub("\208([\160-\175])", function(b) return "\209" .. string.char(b:byte() - 32) end)
    s = s:gsub("\208([\128-\143])", function(b) return "\209" .. string.char(b:byte() + 16) end)
    return s
end

--- A word with its first letter a capital, as the game writes a name: a to z, Latin-1 and Cyrillic.
function GK.UpperFirst(w)
    local a, b = w:byte(1, 2)
    if not a then return w end
    if a < 128 then return (w:gsub("^%l", string.upper)) end
    if a == 195 and b and b >= 160 and b <= 190 and b ~= 183 then return string.char(195, b - 32) .. w:sub(3) end
    if a == 208 and b and b >= 176 and b <= 191 then return string.char(208, b - 32) .. w:sub(3) end
    if a == 209 and b and b >= 128 and b <= 143 then return string.char(208, b + 32) .. w:sub(3) end
    if a == 209 and b and b >= 144 and b <= 159 then return string.char(208, b - 16) .. w:sub(3) end
    return w
end

-- What GK.Ink and GK.Paint drew, to draw again in the other skin (weak: a thing let go is forgotten).
local inked = setmetatable({}, { __mode = "k" })
local painted = setmetatable({}, { __mode = "k" })
local onLook = {}

--- A text in a colour (GK.INK, GK.FADED, GK.BLOOD, or one of its own), in GK.TEXT_FONT or GK.TITLE_FONT
--- - which in classic is the game's own face, a little smaller.
function GK.Ink(fs, colour, font, size)
    inked[fs] = { colour, font, size }
    local look = GK.LOOK
    if font == GK.TITLE_FONT then
        font, size = look.title, math.floor(size * look.titleScale + 0.5)
    end
    GK.SetFont(fs, font, size)
    fs:SetTextColor(colour[1], colour[2], colour[3])
    if look.shadow then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

--- A flat colour from the skin: "stripe", "rule", or "blood" (GK.BLOOD), at alpha a or the skin's own.
function GK.Paint(tex, role, a)
    painted[tex] = { role, a }
    if role == "blood" then
        tex:SetColorTexture(GK.BLOOD[1], GK.BLOOD[2], GK.BLOOD[3], a or 1)
    else
        local c = GK.LOOK[role]
        tex:SetColorTexture(c[1], c[2], c[3], a or c[4])
    end
end

--- A row's tint in the skin's wash colour: the chosen row, a hovered one, your own.
function GK.Wash(tex, a)
    local c = GK.LOOK.wash
    tex:SetColorTexture(c[1], c[2], c[3], a)
end

--- fn() runs after every switch of skin: a window's background, its layout.
function GK.OnLook(fn) onLook[#onLook + 1] = fn end

--- Switch skin ("classic", or anything else for parchment) and draw everything again in it.
function GK.SetLook(name)
    GK.db.look = (name == "classic") and "classic" or nil
    GK.UseLook(GK.db.look)
    for fs, spec in pairs(inked) do GK.Ink(fs, spec[1], spec[2], spec[3]) end
    for tex, spec in pairs(painted) do GK.Paint(tex, spec[1], spec[2]) end
    for _, fn in ipairs(onLook) do fn() end
end

-- A button with words on it, in the skin's own: in classic the game's bronze one (GK.BUTTON), as the friends
-- window has; on parchment the old red of UIPanelButtonTemplate, its own three pieces of the old files over
-- the bronze one's, which wait unseen. The ink boxes on the letter were "basically bare border ... flatt og
-- dårlig" (the owner, 2026-11-18); the bronze "funker dårlig på parchment men bra på classic stilen", and
-- of the six styles tried on parchment: "best å bare bruke knapp nummer 1" - the old red. A switch of skin
-- redraws every one, no reload.
local OLD_RED = "Interface\\Buttons\\UI-Panel-Button-"
local OLD_U = { { 0, 0.09375 }, { 0.09375, 0.53125 }, { 0.53125, 0.625 } }   -- its left, middle and right (its XML)
local OLD_V = 0.6875
local made = setmetatable({}, { __mode = "k" })

--- The old red's state: up, down while pressed, or disabled - as UIPanelButton_OnMouseDown and the rest set it.
local function OldRedState(b)
    local state = not b:IsEnabled() and "Disabled" or (b.down and "Down" or "Up")
    for _, t in ipairs(b.oldRed) do t:SetTexture(OLD_RED .. state) end
end

local function ButtonLook(b)
    local old = not GK.Classic()
    b.parchment = old
    for _, t in ipairs(b.oldRed) do t:SetShown(old) end
    for _, k in ipairs({ "Left", "Center", "Right" }) do
        if type(b[k]) == "table" then b[k]:SetAlpha(old and 0 or 1) end
    end
    if old then
        b:SetHighlightTexture(OLD_RED .. "Highlight", "ADD")
        local hl = b:GetHighlightTexture()
        if hl then hl:SetTexCoord(0, 0.625, 0, OLD_V) end
    else
        b:SetHighlightAtlas("128-RedButton-Highlight")
    end
    OldRedState(b)
end

function GK.MakeButton(parent, width, height)
    local b = CreateFrame("Button", nil, parent, GK.BUTTON)
    b:SetSize(width or 96, height or 22)
    b.oldRed = {}
    for i, u in ipairs(OLD_U) do
        local t = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetTexCoord(u[1], u[2], 0, OLD_V)
        b.oldRed[i] = t
    end
    local l, m, r = b.oldRed[1], b.oldRed[2], b.oldRed[3]
    l:SetWidth(12)
    l:SetPoint("TOPLEFT")
    l:SetPoint("BOTTOMLEFT")
    r:SetWidth(12)
    r:SetPoint("TOPRIGHT")
    r:SetPoint("BOTTOMRIGHT")
    m:SetPoint("TOPLEFT", l, "TOPRIGHT")
    m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    -- hooks, so the template's own scripts still draw the bronze one's pressed and disabled look
    b:HookScript("OnMouseDown", function(self)
        self.down = self:IsEnabled()
        OldRedState(self)
    end)
    b:HookScript("OnMouseUp", function(self)
        self.down = false
        OldRedState(self)
    end)
    b:HookScript("OnShow", function(self)
        self.down = false                       -- hidden before the mouse came up
        OldRedState(self)
    end)
    b:HookScript("OnEnable", OldRedState)
    b:HookScript("OnDisable", OldRedState)
    made[b] = true
    ButtonLook(b)
    return b
end

GK.OnLook(function()
    for b in pairs(made) do ButtonLook(b) end
end)

-- ---------------------------------------------------------------------------
-- The notifications, one page since 2026-11-20 (Settings, Notifications)
-- ---------------------------------------------------------------------------
-- "gjør settings bedre, så alt av notifications osv kan stilles på ett sted ... tenk en 1000 people guild"
-- (the owner, 2026-11-20). Yours and a guildie's became two settings each, and a guildie's side got a threshold
-- and the Big moments by default. An older saved file is moved once, before the defaults fill it in: a new
-- title was told by the sprees' settings, so it keeps what they said; your kill order came with a guildie's and
-- Off turned both off; a spree ended and a tormentor were one setting for both, so a guildie's keeps an Off.
-- Everything else of a guildie's starts at the Big moments.
local function MoveNotifications(db)
    if type(db) ~= "table" or db.notifyV2 then return end
    if db.rankMine == nil then db.rankMine = db.spreeMine end
    if db.rankGuild == nil then db.rankGuild = db.spreeGuild end
    if db.orderMine == nil and db.orderDone == "off" then db.orderMine = "off" end
    if db.spreeEndedGuild == nil and db.spreeEnded == "off" then db.spreeEndedGuild = "off" end
    if db.spreeTormentorGuild == nil and db.spreeTormentor == "off" then db.spreeTormentorGuild = "off" end
end
GK.MoveNotifications = MoveNotifications     -- for tests/run.lua

-- Revenge came on 2026-11-20 with a row of its own each side. A saved file from before it: yours as your sprees
-- are, so a streamer's toasts stay toasts, and a guildie's off - but a toast for who had everything from guildies
-- (the preset All of it, retired 2026-11-22: "presets.. fjerne eller?", the owner).
local HAD_EVERYTHING = { spreeMine = "splash", rankMine = "splash", orderMine = "splash", spreeEnded = "toast",
    spreeTormentor = "toast", spreeGuild = "toast", spreeGuildFrom = 3, rankGuild = "toast", rankGuildFrom = 0,
    orderDone = "toast", spreeEndedGuild = "toast", spreeTormentorGuild = "toast", guildSounds = true }
local function MoveRevenge(db)
    if type(db) ~= "table" or db.revengeMine ~= nil then return end
    local all = true
    for k, v in pairs(HAD_EVERYTHING) do
        if db[k] ~= v then all = false end
    end
    if all then
        db.revengeMine, db.revengeGuild = "splash", "toast"
        return
    end
    local s = db.spreeMine
    db.revengeMine = (s == "splash" or s == "toast" or s == "off") and s or "splash"
    db.revengeGuild = "off"
end
GK.MoveRevenge = MoveRevenge                 -- for tests/run.lua

-- Yours and a guildie's apart (2026-11-22). A guildie's splash is a toast. Once for each account: Sounds was one
-- switch for everything and a moment's box was for both sides, so what was off there is off on each side now.
local GUILD_ROWS = { "spreeGuild", "rankGuild", "orderDone", "revengeGuild", "spreeEndedGuild", "spreeTormentorGuild" }
local SHARED_BOXES = { "spreeSound", "rankSound", "orderSound", "revengeSound", "endedSound", "tormentorSound" }
local function SplitSides(db)
    for _, key in ipairs(GUILD_ROWS) do
        if db[key] == "splash" then db[key] = "toast" end
    end
    if db.soundSplit then return end
    db.soundSplit = true
    if db.sound == false then db.mineSounds, db.guildSounds, db.warnSounds = false, false, false end
    for _, key in ipairs(SHARED_BOXES) do
        if db[key] == false then db[key .. "Guild"] = false end
    end
end

-- A warning's row: "screen" by the letter icon, "chat" one line, or "off". true and false are an older saved
-- file's, from when each row was a box to tick: true is the row's own way, as it was then.
local WARN_WAY = { alertNear = "screen", watchNearby = "chat", watchGroup = "screen", kudosGroup = "chat",
    targetedBy = "screen" }

--- How a warning is told now: "screen", "chat" or "off".
function GK.WarnStyle(key)
    local v = GK.db and GK.db[key]
    if v == "screen" or v == "chat" or v == "off" then return v end
    if v == true then return WARN_WAY[key] or "screen" end
    return "off"
end

--- Tell a warning its row's way (GK.WarnStyle): on screen (GK.Warn, with the rest of its arguments), as a line
--- in chat, or not at all. Returns whether it was told.
function GK.WarnAs(key, text, urgent, ownSound, target, soundKey)
    local how = GK.WarnStyle(key)
    if how == "screen" then
        GK.Warn(text, urgent, ownSound, target, soundKey)
        return true
    elseif how == "chat" then
        print(TAG .. ": " .. text)
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------
LIB.On("PLAYER_LOGIN", function()
    local fresh = GrudgekeeperDB == nil             -- a first install: no "what's new" (GK.DeliverNews)
    MoveNotifications(GrudgekeeperDB)
    MoveRevenge(GrudgekeeperDB)
    GK.db = LIB.PrepareDB(GrudgekeeperDB, defaults, nil, 1)
    GK.db.notifyV2 = true
    GrudgekeeperDB = GK.db
    GK.UseLook(GK.db.look)
    GK.char = LIB.PrepareDB(GrudgekeeperCharDB, charDefaults, nil, 1)
    GrudgekeeperCharDB = GK.char
    -- Ours for LibForever to remember this character's realm in, and to find it in our own old keys where the
    -- client names none (Forever's 1.60.1.71037, 2026-11-20: LIB.Realm). Before the store is first asked for.
    if LIB.RegisterSavedTable then
        LIB.RegisterSavedTable(GK.db)
        LIB.RegisterSavedTable(GK.char)
    end
    -- Retired 2026-11-07, when taking an order went: the orders you took, and the warning for every
    -- order beside the one for yours (every order warns now). Gone from the saved files too.
    GK.char.accepted, GK.db.alertAll = nil, nil
    -- Retired 2026-11-22: the warning for one who leads over you near ("leads over me kanskje ikke ha alert? men
    -- heller en sånn notification om du dreper noen du har grudge mot", the owner) - a toast at the kill now
    -- (grudgeMine) - and Marked, with its warning (kill orders and Track do its work).
    GK.db.leadNear, GK.db.noteAlerts = nil, nil
    -- Retired 2026-11-22: Reaper's choice of the scythe or the smoke, and the one move to the scythe before it.
    GK.db.reaperEffect, GK.db.reaperScythe = nil, nil
    -- Hear from (2026-11-22, never released) is Mode's now: its friends and Only me are Streamer's and Private's
    if GK.db.hearFrom == "friends" and GK.db.mode == "normal" then GK.db.mode = "streamer" end
    if GK.db.hearFrom == "me" and GK.db.mode == "normal" then GK.db.mode = "private" end
    GK.db.hearFrom = nil
    -- "screenshots av by default btw" (the owner, 2026-11-22). The betas had a fulfilled order's on out of the box,
    -- written into every saved file, and nothing tells that apart from a pick: each account is moved off once,
    -- and keeps what it picks after.
    if not GK.db.shotsOff then GK.db.shotFulfil, GK.db.shotsOff = false, true end
    -- "war horn for kill order near og alliance bell for shame player joins? og reset det for alle nå med nye
    -- patchen" (the owner, 2026-11-23): each account is moved to the two once, and keeps what it picks after.
    if not GK.db.sounds112 then
        GK.db.nearSound, GK.db.shameSound, GK.db.sounds112 = defaults.nearSound, defaults.shameSound, true
    end
    -- Mode's halves apart (2026-11-24): what you share is still db.mode, what you see is the rows (Quick setup).
    -- Streamer and Private told nothing of a guildie's until then, and a guildie's kill order came as a letter only
    -- when it was about you: each such account has the guildies' toasts and the kill order letters turned off once,
    -- so nothing new shows up, and keeps what it picks after. And the right-click menu's one box is a box a line:
    -- one that was off is every line off.
    if not GK.db.modesSplit then
        if GK.db.mode == "streamer" or GK.db.mode == "private" then
            for _, key in ipairs(GK.SEE_GUILD) do GK.db[key] = "off" end
            GK.db.letters = false
        end
        if GK.db.unitMenu == false then
            for _, key in ipairs(GK.MENU_LINES) do GK.db[key] = false end
        end
        GK.db.modesSplit = true
    end
    GK.db.unitMenu = nil
    GK.ClaimPC(GK.char)
    GK.ForgetGoneSounds(GK.db)
    SplitSides(GK.db)                                -- after it: a None picked is a box off by then
    GK.RekeyStores()
    if GK.StartAlts then GK.StartAlts() end          -- removal notes before anything else touches the grudges (alt-sync D4)
    RegisterMinimap()
    GK.StartGuild()
    GK.StartSightings()
    GK.StartKills()
    GK.StartLetters(fresh)
    GK.StartMail()
    GK.StartSocial()
    -- GuildTab.lua came in an update: the game reads the list of files when it starts, so a /reload
    -- after an update has the new Core.lua and not the new file. Without it there is no tab until the
    -- game is started again - and everything after this line still starts.
    if GK.StartGuildTab then GK.StartGuildTab() end
    GK.StartProfiles()
    GK.StartInspect()
    GK.StartMapPins()
    GK.RegisterOptions()
end)
