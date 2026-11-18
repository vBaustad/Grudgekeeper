-- Grudgekeeper - your kills and your deaths.
-- A kill: PARTY_KILL names the killer and the victim by GUID, for you and anyone in your group. We
-- count the ones landed by you or your pet, on a player of the other faction, in the open world. The
-- level comes from having seen them (Sightings.lua): the kill itself carries none.
-- An assist: the same event, the blow landed by someone in your group (or their pet) on an enemy player
-- you hurt in that fight. The game keeps the combat log from us, but its damage meter says who hit whom
-- once the fight is over, so the kill waits for the end of combat and the meter is asked then: any
-- damage of yours (or your pet's) on the victim makes it an assist, none and it is not one. Taken, with
-- fixes, from dakristia's vBaustad/Grudgekeeper#2.
-- An enemy player a stranger, a guard or a mob finished: no PARTY_KILL names a killer of ours, but
-- UNIT_DIED (or PLAYER_TARGET_DIED, for our target) says they died, and the meter holds our own damage on
-- them whoever landed the blow - it holds you and your group only, never the stranger (/grudge debug
-- meter, 2026-11-11). Any damage of ours makes it an assist too, its helper unknown ("jeg hjalp akkurat
-- noen å drepe en horde men synes ikke i news? det var randoms", the owner, 2026-11-15).
-- A death: the game's death recap names whoever landed the blow (the "You died" chat line carries its
-- id), and the damage meter is asked when the recap is empty. It counts as a PvP death only when that
-- name belongs to an enemy player we saw - a name alone can't tell a rogue from a murloc.
local ADDON, GK = ...
local LIB = LibStub("LibForever-1.0")
local Secret = GK.Secret

local recapId          -- the death recap the last "You died" line pointed at
local deathPending
local lastDeath = "none this session"
local lastAssist = "none this session"
local pending = {}      -- [guid] = { v, at }: a groupmate's kill waiting for the meter to be readable
local PENDING_FOR = 120 -- seconds a kill may wait for a readable meter before it is dropped
local LOOK_BACK = 3     -- fights before "Current" asked too, when another one began before the meter was read
-- A death no kill of ours named (GK.OnUnitDied): it waits DIED_WAIT for a PARTY_KILL that may still come,
-- and a death a PARTY_KILL of ours or the group's took is left alone for SETTLED_FOR - UNIT_DIED may come
-- after the assist was already settled. At most MAX_PENDING wait at once, however big the fight.
local settled = {}      -- [guid] = GetTime() of our or a groupmate's PARTY_KILL on them
local DIED_WAIT, SETTLED_FOR, MAX_PENDING = 1, 30, 40
-- When the fight we are in began, at PLAYER_REGEN_DISABLED. A guildie who fell after that fell in this
-- fight, and is avenged only in a later one (GK.Avenged): one of the group dying first made every kill
-- and assist on their killer worth a point more, for the whole group - "trenger en combat reset i mellom"
-- (the owner, 2026-11-12).
local fightStart = time()
-- Whether we are in a fight, and when the last one ended (GetTime()); and whether the death being resolved
-- came in one. A death out of a fight - lava, a fall, drowning - has no enemy to it but its blow: the death
-- recap keeps the last hits before a death however old they are, and the damage meter's latest fight is an
-- older one. The owner killed two, jumped in lava three or four minutes later for a quest and got "spree
-- ended" (2026-11-16): by elimination, the recap still held the earlier enemy's hits - not the meter, whose
-- player rows went unread until MeterSource (not seen: the recap itself). Dying ends the fight a moment before the game says we died, so a fight that
-- ended FIGHT_GRACE before still counts as the one we died in.
local inFight, fightEndedAt, diedInFight = false, nil, false
local FIGHT_GRACE = 5

function GK.LastDeathDebug() return lastDeath end
function GK.LastAssistDebug() return lastAssist end

--- A screenshot, a moment later. Only ever from a kill you made (an event), never on a timer of its own.
function GK.Shot(delay)
    C_Timer.After(delay or 0.3, function() pcall(Screenshot) end)
end

local function Mine(guid)
    if type(guid) ~= "string" then return false end
    if guid == UnitGUID("player") then return true end
    return UnitExists("pet") and guid == UnitGUID("pet") or false
end

--- Someone else in your group, or their pet: their name to show, or nil.
local function Groupmate(guid)
    if type(guid) ~= "string" or Mine(guid) then return nil end
    local raid = IsInRaid()
    local n = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
    for i = 1, n do
        local unit = (raid and "raid" or "party") .. i
        if UnitGUID(unit) == guid or UnitGUID(unit .. "pet") == guid then
            local name = UnitName(unit)
            return (not Secret(name) and type(name) == "string") and name or "a groupmate"
        end
    end
    return nil
end

--- Today's hits on this enemy, kills and assists alike, with older ones dropped.
local function HitsToday(f, now)
    local today = 0
    for i = #f.hits, 1, -1 do
        if now - f.hits[i] > GK.DAY then table.remove(f.hits, i) else today = today + 1 end
    end
    return today
end

--- They killed you since you last got them, by kill or assist.
local function Revenge(f)
    return (f.lastDeath or 0) > math.max(f.lastKill or 0, f.lastAssist or 0)
end

-- ---------------------------------------------------------------------------
-- Kills
-- ---------------------------------------------------------------------------
--- One kill of ours: points, the log, the guild, any order it fulfils, a letter when it earns a title.
--- v = { key, guid, c, r, l }
function GK.RecordKill(v)
    local now = time()
    local f = GK.Foe(v.key, { n = GK.Show(v.key), c = v.c, r = v.r, l = v.l })
    GK.KeepLooks(v.key, GK.Seen(v.key, v.guid) or v)     -- a grudge now: their race's face is kept
    local today = HitsToday(f, now)
    local orders = GK.OrdersOn(v.key, v.guid)
    -- Revenge: they killed you since you last got them. Avenged: they killed a guildie a moment ago, before
    -- this fight began.
    local revenge = Revenge(f)
    local avenged = GK.Avenged(v.key, now, v.fight or fightStart)
    local c = GK.char
    local titleBefore = GK.Title(c.points)
    local points = GK.Points(UnitLevel("player"), v.l, today, #orders > 0, revenge, avenged)
    f.hits[#f.hits + 1] = now
    f.k = f.k + 1
    f.lastKill = now
    c.kills = c.kills + 1
    c.points = c.points + points
    c.streak = (c.streak or 0) + 1
    c.bestStreak = math.max(c.bestStreak or 0, c.streak)
    -- The spree counts the kills worth points only: a grey kill or a farmed one is in the streak, not here.
    if points > 0 then c.spree = (c.spree or 0) + 1 end
    local week = GK.Week()
    week.p, week.k = week.p + points, week.k + 1
    local zone = GK.Zone()
    GK.AddLog({ k = "K", t = now, n = v.key, c = v.c, r = v.r, l = v.l, z = zone, p = points,
        o = orders[1] and orders[1].key or nil, rv = revenge or nil, av = avenged })
    for _, o in ipairs(orders) do GK.Fulfil(o, zone) end
    GK.SendKill(v, zone, points, avenged, f.k, c.spree)
    -- What the kill made of it, for whatever shows it (GK_SPREE, GK_TORMENTOR). Only after the send: the
    -- guild hears the kill first.
    -- Each is a line in the guild's news as well (GK.SpreeNews), after the kill's own.
    if points > 0 then
        local tier, key = GK.SpreeTier(c.spree)
        if tier then
            LIB.Fire("GK_SPREE", LIB.Me(), c.spree, tier, true, key)
            GK.SpreeNews("S", LIB.Me(), v, zone, c.spree, tier)
        end
    end
    local tormented = GK.TormentorEnded(v.key)
    if tormented then
        LIB.Fire("GK_TORMENTOR", LIB.Me(), GK.Show(v.key), tormented, true)
        GK.SpreeNews("M", LIB.Me(), v, zone, tormented)
    end
    GK.SendBoard()
    -- A new title, told on screen as a spree is (GK_RANKUP, Announce.lua): the letter below waits for the
    -- fight to end, and says where you stand
    if GK.Title(c.points) ~= titleBefore then LIB.Fire("GK_RANKUP", LIB.Me(), GK.Title(c.points), c.points, true) end
    if (#orders > 0 and GK.db.shotFulfil) or GK.db.shotEveryKill then GK.Shot(0.3) end
    -- A letter only for the kill that earns a new title. One for every kill was one after every fight ("den
    -- kan bli litt spam"), and a narrower rule - above your level, revenge, a streak - still sent too many:
    -- "kanskje for kills så kommer melding bare når man ranker opp?" (the owner, 2026-11-07). Every kill
    -- still counts, and the ledger's Grudges and News have them all.
    if #orders == 0 and GK.db.myLetters then
        local title = GK.Title(c.points)
        if title ~= titleBefore then GK.KillLetter(v, zone, title) end
    end
    GK.Changed()
end

--- One assist of ours: a groupmate landed the blow on an enemy we were fighting. Points a little
--- below the kill's, no order fulfilled (the killer does that), and no line in chat - the owner doesn't
--- read them; the ledger's Grudges and News have it. A letter only when it earns a new title, as a kill.
--- v = { key, guid, c, r, l, with }
function GK.RecordAssist(v)
    local now = time()
    local f = GK.Foe(v.key, { n = GK.Show(v.key), c = v.c, r = v.r, l = v.l })
    GK.KeepLooks(v.key, GK.Seen(v.key, v.guid) or v)
    local today = HitsToday(f, now)
    local revenge = Revenge(f)
    local avenged = GK.Avenged(v.key, now, v.fight or fightStart)
    local points = GK.AssistPoints(UnitLevel("player"), v.l, today, revenge, avenged)
    local c = GK.char
    local titleBefore = GK.Title(c.points)
    f.hits[#f.hits + 1] = now
    f.a = (f.a or 0) + 1
    f.lastAssist = now
    c.assists = (c.assists or 0) + 1
    c.points = c.points + points
    local week = GK.Week()
    week.p, week.a = week.p + points, (week.a or 0) + 1
    local zone = GK.Zone()
    GK.AddLog({ k = "A", t = now, n = v.key, c = v.c, r = v.r, l = v.l, z = zone, p = points, w = v.with,
        rv = revenge or nil, av = avenged })
    GK.SendAssist(v, zone, points)
    GK.SendBoard()
    if GK.Title(c.points) ~= titleBefore then LIB.Fire("GK_RANKUP", LIB.Me(), GK.Title(c.points), c.points, true) end
    -- the points of an assist can cross a title as well as a kill's
    if GK.db.myLetters then
        local title = GK.Title(c.points)
        if title ~= titleBefore then GK.KillLetter(v, zone, title) end
    end
    GK.Changed()
end

--- The enemy player a PARTY_KILL names, as we record them; nil when they aren't one we count.
local function Victim(target)
    local ok, _, classFile, race, raceFile, _, name, realm = pcall(GetPlayerInfoByGUID, target)
    if not ok or Secret(name) or type(name) ~= "string" then return nil end
    local s = GK.Seen(nil, target)
    local key = (s and s.key) or GK.PlayerKey(GK.KeyOf(name, realm))
    if not key then return nil end
    -- The other side only: we keep sightings of enemies alone, so having seen them settles it;
    -- otherwise their race decides, and a race that could be either side is not counted.
    if not s and GK.EnemyRace(not Secret(raceFile) and raceFile or nil) ~= true then return nil end
    local level = s and s.l
    if not level and UnitExists("target") and UnitGUID("target") == target then
        local l = UnitLevel("target")
        level = not Secret(l) and GK.ValidLevel(l) or nil
    end
    return { key = key, guid = target,
        c = (s and s.c) or (not Secret(classFile) and GK.ValidClass(classFile)) or nil,
        r = (s and s.r) or GK.Clean(race, 20), l = level }
end

--- The names the meter may give our own rows: "First Surname" as it writes us ("Critical Mango",
--- /grudge debug meter, 2026-11-11), and the first name alone. UnitName gives the two apart on Forever
--- (DECISIONS.md, 2026-09-26): matching on its first value alone, as the PR did, never found us. And our
--- pet's name, for a row the meter marks as a pet's. nil when we can't tell who we are.
local function OurNames()
    local first, surname = UnitName("player")
    if Secret(first) or type(first) ~= "string" or first == "" then return nil end
    local names = { [first] = true }
    if not Secret(surname) and type(surname) == "string" and surname ~= "" then names[first .. " " .. surname] = true end
    local pet = UnitExists("pet") and UnitName("pet") or nil
    return names, (not Secret(pet) and type(pet) == "string" and pet ~= "") and pet or nil
end

--- The rows of who hit one enemy in one fight, by the meter call given; nil when it won't say.
local function Rows(call, ...)
    local ok, src = pcall(call, ...)
    if not ok or type(src) ~= "table" or Secret(src) or type(src.combatSpells) ~= "table" then return nil end
    return src.combatSpells
end

--- What our rows add up to.
local function Ours(rows, names, pet)
    local total = 0
    for _, sp in ipairs(rows) do
        local d = type(sp) == "table" and sp.combatSpellDetails
        local who, amount = type(d) == "table" and d.unitName, type(sp) == "table" and sp.totalAmount
        if type(who) == "string" and not Secret(who) and type(amount) == "number" and not Secret(amount)
            and (names[who] or (pet and who == pet and not Secret(d.isPet) and d.isPet == true)) then
            total = total + amount
        end
    end
    return total
end

--- How much damage we did to this enemy, by the game's damage meter: a number, or nil when the meter
--- can't be read now (secret in combat), or false when this client has no such meter. The last fight
--- first; when we did nothing there, the few fights before it, newest first - a new fight begun before
--- this one was read has become "Current" and would hide ours.
local function OurDamage(guid)
    local meter = C_DamageMeter
    local types, sessions = Enum and Enum.DamageMeterType, Enum and Enum.DamageMeterSessionType
    if type(meter) ~= "table" or not meter.GetCombatSessionSourceFromType
        or not (types and types.EnemyDamageTaken and sessions) then return false end
    local names, pet = OurNames()
    if not names then return nil end
    local rows = Rows(meter.GetCombatSessionSourceFromType, sessions.Current, types.EnemyDamageTaken, guid)
    local total = rows and Ours(rows, names, pet) or nil
    if (total or 0) > 0 or not (meter.GetAvailableCombatSessions and meter.GetCombatSessionSourceFromID) then
        return total
    end
    local ok, list = pcall(meter.GetAvailableCombatSessions)
    if not ok or type(list) ~= "table" or Secret(list) then return total end
    local ids = {}
    for _, s in ipairs(list) do
        local id = type(s) == "table" and s.sessionID
        if type(id) == "number" and not Secret(id) then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b) return a > b end)
    for i = 1, math.min(#ids, LOOK_BACK) do
        local r = Rows(meter.GetCombatSessionSourceFromID, ids[i], types.EnemyDamageTaken, guid)
        if r then
            local t = Ours(r, names, pet)
            if t > 0 then return t end
            total = total or 0
        end
    end
    return total
end

--- Ask the meter about every kill waiting. Out of combat only: in a fight the meter is secret, and the
--- next end of combat tries again. A kill the meter can't be read for in two minutes is dropped.
local function Settle()
    if InCombatLockdown() then return end
    for guid, p in pairs(pending) do
        local v = p.v
        local dmg = OurDamage(guid)
        if dmg == false then
            pending[guid] = nil
            lastAssist = "no damage meter on this client: no assist"
        elseif dmg == nil then
            if GetTime() - p.at > PENDING_FOR then
                pending[guid] = nil
                lastAssist = ("%s: the meter never said"):format(v.key)
            end
        else
            pending[guid] = nil
            local with = v.with or "someone outside your group"
            if dmg > 0 then
                lastAssist = ("%s, with %s (%d damage from you)"):format(v.key, with, dmg)
                GK.RecordAssist(v)
            else
                lastAssist = ("%s got %s, but the meter shows no damage from you"):format(with, v.key)
            end
        end
    end
end

--- Once a fight is over: the meter may need a moment, and a read it refused is tried again a little later.
local function SettleSoon()
    if not next(pending) then return end
    for _, delay in ipairs({ 1, 3, 6 }) do C_Timer.After(delay, Settle) end
end

--- PARTY_KILL (attacker GUID, victim GUID). A function of its own so the smoke test can call it.
--- Your blow is a kill; a groupmate's waits for the meter, and is your assist if you hurt the victim.
function GK.OnPartyKill(attacker, target)
    if Secret(attacker) or Secret(target) or type(target) ~= "string" then return end
    if not target:find("^Player%-") or not GK.InWorld() then return end
    if Mine(attacker) then
        settled[target] = GetTime()
        -- our own blow just after their death was taken for a stranger's: a kill only. A groupmate's assist
        -- waiting on them stays - it is from an earlier death of theirs (tests/run.lua's avenge case).
        local p = pending[target]
        if p and not p.v.with then pending[target] = nil end
        local v = Victim(target)
        if v then GK.RecordKill(v) end
        return
    end
    local with = Groupmate(attacker)
    if not with then return end
    settled[target] = GetTime()
    local v = Victim(target)
    if not v then
        lastAssist = ("%s got a kill, but not of an enemy player we count"):format(with)
        return
    end
    v.with = with
    v.fight = fightStart           -- settled once the fight is over, maybe after the next began: this one counts
    pending[target] = { v = v, at = GetTime() }
    lastAssist = ("%s, with %s: waiting for the fight to end"):format(v.key, with)
    if not InCombatLockdown() then SettleSoon() end
end

-- ---------------------------------------------------------------------------
-- Deaths
-- ---------------------------------------------------------------------------
--- A recap hit's source GUID when the client lets us read it, else nil.
local function GuidOf(e)
    local g = type(e) == "table" and e.sourceGUID
    if type(g) == "string" and not Secret(g) and g ~= "" then return g end
    return nil
end

--- The enemy player we saw behind a hit: by its GUID where the recap's can be read - a Player- GUID finds
--- them when the name would not, and a pet's or a mob's GUID is no player whatever it is called (a pet named
--- as a player) - else by the name (GK.SeenByName, which answers nil, "several" for a name several share).
--- From dakristia's vBaustad/Grudgekeeper#4 (2026-11-17). Not seen in the game: that recap hits carry a
--- readable sourceGUID; without one it is the name, as before.
local function PlayerOf(name, guid)
    if guid then
        if guid:sub(1, 7) ~= "Player-" then return nil end
        local s = GK.Seen(nil, guid)
        if s then return s end
    end
    if type(name) ~= "string" then return nil end
    return GK.SeenByName(name)
end

--- Who landed the killing blow, by the game's death recap: name, spell and GUID, or nil.
local function FromRecap(id)
    if not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then return nil end
    local ok, events = pcall(C_DeathRecap.GetRecapEvents, id)
    if not ok or type(events) ~= "table" or Secret(events) or #events == 0 then return nil end
    -- The blow that killed is the one that overkilled; the first event when none says so.
    local blow = events[1]
    for _, e in ipairs(events) do
        if type(e) == "table" and not Secret(e.overkill) and type(e.overkill) == "number" and e.overkill > 0 then
            blow = e
            break
        end
    end
    if type(blow) ~= "table" or Secret(blow.sourceName) or type(blow.sourceName) ~= "string" then return nil end
    local spell = blow.spellName
    return blow.sourceName, (not Secret(spell) and type(spell) == "string") and spell or nil, GuidOf(blow)
end

--- Whose a damage meter row's damage is: the unit it names - a player, or a pet's owner, as Blizzard's meter
--- lists a pet: its name in creatureName and its unit in unitName (Blizzard_DamageMeter's SpellEntry) - else
--- the creature. Both are always strings, "" for none, so `creatureName or unitName` took the "" of a
--- player's row and read no one: in the game a player's row is "from  / Critical Mango" (VERIFY.md, the
--- meter's (a), 2026-11-11). A hunter's pet that landed the blow went to nobody (a guildie's report,
--- 2026-11-17). Not seen in the game: that a pet's row names its owner in unitName.
local function MeterSource(sp)
    local function Named(v)
        if type(v) == "string" and not Secret(v) and v ~= "" then return v end
        return nil
    end
    local d = type(sp) == "table" and sp.combatSpellDetails
    return (type(d) == "table" and Named(d.unitName)) or (type(sp) == "table" and Named(sp.creatureName)) or nil
end

--- The same from the game's damage meter: the source of the deadly hit. Readable only out of combat,
--- which being dead is.
local function FromMeter()
    local meter = C_DamageMeter
    local types, sessions = Enum and Enum.DamageMeterType, Enum and Enum.DamageMeterSessionType
    if type(meter) ~= "table" or not meter.GetCombatSessionSourceFromType or not (types and sessions) then return nil end
    if InCombatLockdown() then return nil end
    local ok, src = pcall(meter.GetCombatSessionSourceFromType, sessions.Current, types.DamageTaken, UnitGUID("player"))
    if not ok or type(src) ~= "table" or Secret(src) or type(src.combatSpells) ~= "table" then return nil end
    for _, sp in ipairs(src.combatSpells) do
        if type(sp) == "table" and not Secret(sp.isDeadly) and sp.isDeadly then
            local who = MeterSource(sp)
            if who then return who end
        end
    end
    return nil
end

--- When a mob, a guard or a fall landed the blow: the enemy player we saw who did the most of the damage in
--- these rows ({ name, amount, spell }), their sighting and the spell of their biggest hit. Some let a mob
--- finish you so the death costs durability ("hvis du blir last hittet av mob isteden ... burde vi at least
--- tracke at de gjorde det/bidro", the owner, 2026-11-15). A name several enemies share counts for none of
--- them, as for a blow (GK.SeenByName). nil when no enemy player we saw is in the rows.
local function Hurter(rows)
    local total, record, top, spellOf, best = {}, {}, {}, {}, nil
    for _, r in ipairs(rows or {}) do
        local s = PlayerOf(r[1], r[4])
        if s then
            total[s.key] = (total[s.key] or 0) + r[2]
            record[s.key] = s
            if r[2] > (top[s.key] or -1) then top[s.key], spellOf[s.key] = r[2], r[3] end
            if not best or total[s.key] > total[best] then best = s.key end
        end
    end
    if best then return record[best], spellOf[best] end
end

--- Every hit the death recap holds, as Hurter's rows; nil when it can't be read.
local function RecapRows(id)
    if not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then return nil end
    local ok, events = pcall(C_DeathRecap.GetRecapEvents, id)
    if not ok or type(events) ~= "table" or Secret(events) then return nil end
    local rows = {}
    for _, e in ipairs(events) do
        local who = type(e) == "table" and e.sourceName
        if type(who) == "string" and not Secret(who) and who ~= "" then
            -- a hit with no amount the recap gives us still says they hit us
            local amount = (not Secret(e.amount) and tonumber(e.amount)) or 1
            local spell = (not Secret(e.spellName) and type(e.spellName) == "string") and e.spellName or nil
            if amount > 0 then rows[#rows + 1] = { who, amount, spell, GuidOf(e) } end
        end
    end
    return rows
end

--- Every source of the damage we took in the last fight, by the meter, as Hurter's rows: the recap holds a
--- few last hits only, and the enemy may have stood back while the mob finished us. nil when unreadable.
local function MeterRows()
    local meter = C_DamageMeter
    local types, sessions = Enum and Enum.DamageMeterType, Enum and Enum.DamageMeterSessionType
    if type(meter) ~= "table" or not meter.GetCombatSessionSourceFromType or not (types and sessions) then return nil end
    if InCombatLockdown() then return nil end
    local ok, src = pcall(meter.GetCombatSessionSourceFromType, sessions.Current, types.DamageTaken, UnitGUID("player"))
    if not ok or type(src) ~= "table" or Secret(src) or type(src.combatSpells) ~= "table" then return nil end
    local rows = {}
    for _, sp in ipairs(src.combatSpells) do
        local who = MeterSource(sp)
        local amount = type(sp) == "table" and not Secret(sp.totalAmount) and tonumber(sp.totalAmount)
        if who and amount and amount > 0 then rows[#rows + 1] = { who, amount } end
    end
    return rows
end

--- /grudge debug meter: what the game's damage meter holds of the damage enemies took in the last fight,
--- and from whom. A probe, to learn whether a kill a mob or another player finished can go to whoever did
--- the work ("hvis det er mob som dreper så må vi krediteres ... også hvis ... vi har fightet lenge mot han
--- og noen andre sniper kill", the owner, 2026-11-09). The combat log is closed to addons; this meter is
--- not, out of combat. Prints only what it can read, and "(secret)" for what it can't.
function GK.MeterProbe()
    local meter = C_DamageMeter
    local types, sessions = Enum and Enum.DamageMeterType, Enum and Enum.DamageMeterSessionType
    if type(meter) ~= "table" or not (types and sessions and types.EnemyDamageTaken and meter.GetCombatSessionFromType) then
        print(GK.TAG .. ": this client has no damage meter for the damage enemies take.")
        return
    end
    if InCombatLockdown() then
        print(GK.TAG .. ": after the fight - the meter is secret during one.")
        return
    end
    local function S(v) if Secret(v) then return "(secret)" end return tostring(v) end
    -- The first run (2026-11-11, mobs only) never asked who hit them: a mob has no sourceGUID here, so the
    -- creature ID is asked by as well, and the line says which of the two it had. Overall lumps every mob
    -- of a kind together, so only Current is taken apart, and Overall lists the players alone - the ones
    -- with a class - as the mobs drown them (the idea from vBaustad/Grudgekeeper#2).
    for _, kind in ipairs({ "Current", "Overall" }) do
        local ok, session = pcall(meter.GetCombatSessionFromType, sessions[kind], types.EnemyDamageTaken)
        if not ok or type(session) ~= "table" or Secret(session) or type(session.combatSources) ~= "table" then
            print(("%s meter, %s: nothing readable (%s)"):format(GK.TAG, kind, ok and S(session) or tostring(session)))
        else
            print(("%s meter, %s: %d enemies took %s"):format(GK.TAG, kind, #session.combatSources, S(session.totalAmount)))
            local list, mobs = {}, 0
            for _, src in ipairs(session.combatSources) do
                local class = src.classFilename
                if kind == "Current" or (not Secret(class) and type(class) == "string" and class ~= "") then
                    list[#list + 1] = src
                else
                    mobs = mobs + 1
                end
            end
            if mobs > 0 then print(("  (%d without a class - mobs - left out)"):format(mobs)) end
            for i, src in ipairs(list) do
                if i > 6 then break end
                local guid, cid = src.sourceGUID, src.sourceCreatureID
                print(("  %s, %s %s: took %s, died at %s - %s, creature %s"):format(S(src.name), S(src.factionGroup),
                    S(src.classFilename), S(src.totalAmount), S(src.deathTimeSeconds),
                    guid == nil and "no GUID" or Secret(guid) and "GUID secret" or ("GUID " .. tostring(guid):sub(1, 7)),
                    S(cid)))
                local byGuid = (guid ~= nil and not Secret(guid)) and guid or nil
                local byId = (not Secret(cid) and type(cid) == "number") and cid or nil
                if kind ~= "Current" then
                    -- the breakdown is asked for the last fight only
                elseif not (byGuid or byId) then
                    print("    who hit them: nothing to ask by")
                elseif meter.GetCombatSessionSourceFromType then
                    local ok2, d = pcall(meter.GetCombatSessionSourceFromType, sessions[kind], types.EnemyDamageTaken,
                        byGuid, byId)
                    if ok2 and type(d) == "table" and not Secret(d) and type(d.combatSpells) == "table" then
                        if #d.combatSpells == 0 then print("    who hit them: an empty list") end
                        for j, sp in ipairs(d.combatSpells) do
                            if j > 4 then break end
                            local u = type(sp.combatSpellDetails) == "table" and sp.combatSpellDetails or {}
                            print(("    spell %s: %s from %s / %s, mob %s, pet %s, deadly %s"):format(S(sp.spellID),
                                S(sp.totalAmount), S(sp.creatureName), S(u.unitName), S(u.isMob), S(u.isPet),
                                S(sp.isDeadly)))
                        end
                    else
                        print(("    who hit them: nothing readable (%s)"):format(ok2 and S(d) or tostring(d)))
                    end
                end
            end
        end
    end
    -- and what hit us in the last fight, as a death is read (MeterRows): after a death to a hunter's pet,
    -- whether the pet's row names its owner in unitName (a guildie's report, 2026-11-17)
    if types.DamageTaken and meter.GetCombatSessionSourceFromType then
        local ok, src = pcall(meter.GetCombatSessionSourceFromType, sessions.Current, types.DamageTaken,
            UnitGUID("player"))
        if not ok or type(src) ~= "table" or Secret(src) or type(src.combatSpells) ~= "table" then
            print(("%s meter, what hit you: nothing readable (%s)"):format(GK.TAG, ok and S(src) or tostring(src)))
        else
            print(("%s meter, what hit you in the last fight: %d rows"):format(GK.TAG, #src.combatSpells))
            for j, sp in ipairs(src.combatSpells) do
                if j > 6 then break end
                local u = type(sp.combatSpellDetails) == "table" and sp.combatSpellDetails or {}
                print(("  %s from %s / %s, pet %s, mob %s, deadly %s - read as %s"):format(S(sp.totalAmount),
                    S(sp.creatureName), S(u.unitName), S(u.isPet), S(u.isMob), S(sp.isDeadly), S(MeterSource(sp))))
            end
        end
    end
end

--- One death of ours to an enemy player. v = { key, guid, c, r, l, spell }
--- Returns the spree we had before it ended, which is 0 for none.
function GK.RecordDeath(v)
    local f = GK.Foe(v.key, { n = GK.Show(v.key), c = v.c, r = v.r, l = v.l })
    GK.KeepLooks(v.key, GK.Seen(v.key, v.guid) or v)     -- a grudge now: their race's face is kept
    f.d = f.d + 1
    f.lastDeath = time()
    GK.char.deaths = GK.char.deaths + 1
    GK.char.streak = 0
    local spree = GK.char.spree or 0
    GK.char.spree = 0
    GK.TormentorGrew(v.key)
    if spree >= GK.SPREE_MIN then LIB.Fire("GK_SPREE_ENDED", LIB.Me(), spree, GK.Show(v.key), true) end
    local week = GK.Week()
    week.d = week.d + 1
    local zone = GK.Zone()
    GK.AddLog({ k = "D", t = time(), n = v.key, c = v.c, r = v.r, l = v.l, z = zone, s = v.spell })
    GK.SendDeath(v, zone, f.d)
    -- the spree it ended, in the guild's news after the death's own line
    if spree >= GK.SPREE_MIN then GK.SpreeNews("E", LIB.Me(), v, zone, spree) end
    GK.SendBoard()
    -- the third of us in two hours, or the third time for you in half an hour: an order goes out
    local auto = GK.AutoOrder(v)
    -- A letter only for the death that posted that order. One death to someone you will never see again
    -- is no news ("kanskje ikke så viktig å få brev om man bare blir drept en random gang", the owner,
    -- 2026-11-06); it still counts, and the ledger's Grudges and News have it.
    if GK.db.myLetters and auto then GK.SlainLetter(v, f.d, zone, true) end
    GK.Changed()
    return spree
end

function GK.ResolveDeath()
    deathPending = false
    local id = recapId
    recapId = nil
    if not GK.InWorld() then
        lastDeath = "in an instance: not counted"
        return
    end
    local how = "the death recap"
    local name, spell, guid = FromRecap(id)
    if not name and id then name, spell, guid = FromRecap(nil) end
    -- the meter's latest fight is this death's only when we died in a fight
    if not name and diedInFight then
        name, how = FromMeter(), "the damage meter"
    end
    local s, why
    if name then s, why = PlayerOf(name, guid) end
    -- The blow was a mob's, a guard's or a fall's: the enemy player who did the most of the damage is who
    -- we died to. Not when the blow was a name several enemies share - then it was one of them. Not out of a
    -- fight: lava or a fall with no fight going had no enemy in it.
    if not s and why ~= "several" and diedInFight then
        local e, espell = Hurter(RecapRows(id))
        local ehow = "the death recap"
        if not e and id then e, espell = Hurter(RecapRows(nil)) end
        if not e then e, espell, ehow = Hurter(MeterRows()), nil, "the damage meter" end
        if e then
            lastDeath = ("%s, by %s - the blow was %s"):format(e.key, ehow,
                name and (GK.Clean(name, 40) or "?") .. "'s" or "nobody's we know")
            GK.RecordDeath({ key = e.key, guid = e.guid, c = e.c, r = e.r, l = e.l, spell = GK.Clean(espell, 40) })
            return
        end
    end
    if not name then
        lastDeath = diedInFight and "neither the death recap nor the damage meter named anyone"
            or "out of a fight (lava, a fall?), and the recap named no one: not counted"
        return
    end
    if not s and not diedInFight then
        lastDeath = ("%s, by %s - out of a fight, so only the blow counts, and it was no enemy player we saw")
            :format(GK.Clean(name, 40) or "?", how)
        return
    end
    if not s then
        lastDeath = ("%s, by %s - %s, so not counted"):format(GK.Clean(name, 40) or "?", how,
            why == "several" and "several enemy players we saw go by that name" or "not an enemy player we saw")
        return
    end
    lastDeath = ("%s, by %s"):format(s.key, how)
    GK.RecordDeath({ key = s.key, guid = s.guid, c = s.c, r = s.r, l = s.l, spell = GK.Clean(spell, 40) })
end

--- UNIT_DIED (a GUID) or PLAYER_TARGET_DIED (our target's): an enemy player died, perhaps to a stranger, a
--- guard or a mob. A moment later, if no PARTY_KILL of ours or the group's took it, it waits for the meter
--- as a groupmate's kill does: our damage on them makes it an assist, with nobody named beside us.
function GK.OnUnitDied(guid)
    if Secret(guid) or type(guid) ~= "string" or not guid:find("^Player%-") or Mine(guid) then return end
    if not GK.InWorld() or pending[guid] then return end
    C_Timer.After(DIED_WAIT, function()
        local now = GetTime()
        for g, at in pairs(settled) do
            if now - at >= SETTLED_FOR then settled[g] = nil end
        end
        if settled[guid] or pending[guid] then return end
        local n = 0
        for _ in pairs(pending) do n = n + 1 end
        if n >= MAX_PENDING then return end
        local v = Victim(guid)
        if not v then return end
        v.fight = fightStart
        pending[guid] = { v = v, at = now }
        settled[guid] = now         -- once: the same death heard again later is not a second assist
        lastAssist = ("%s died, not to you or your group: waiting for the fight to end"):format(v.key)
        if not InCombatLockdown() then SettleSoon() end
    end)
end

function GK.StartKills()
    LIB.On("PARTY_KILL", function(attacker, target) GK.OnPartyKill(attacker, target) end)
    LIB.On("UNIT_DIED", function(guid) GK.OnUnitDied(guid) end)
    LIB.On("PLAYER_TARGET_DIED", function() GK.OnUnitDied(UnitGUID("target")) end)
    LIB.On("PLAYER_REGEN_ENABLED", function()
        inFight, fightEndedAt = false, GetTime()
        SettleSoon()
    end)
    LIB.On("PLAYER_REGEN_DISABLED", function()
        fightStart, inFight = time(), true
    end)
    LIB.On("CHAT_MSG_SYSTEM", function(text)
        if type(text) ~= "string" or Secret(text) then return end
        local id = text:match("|Hdeath:(%d+)|h")
        if id then recapId = tonumber(id) end
    end)
    LIB.On("PLAYER_DEAD", function()
        if deathPending then return end
        deathPending = true
        -- in a fight, or one that ended a moment ago: dying ends it (FIGHT_GRACE). Read now, not when the
        -- recap is: by then the fight has ended either way.
        diedInFight = inFight or InCombatLockdown() or UnitAffectingCombat("player")
            or (fightEndedAt ~= nil and GetTime() - fightEndedAt <= FIGHT_GRACE)
        diedInFight = diedInFight and true or false
        -- The recap, and the chat line that names it, land just after the death itself.
        C_Timer.After(1.5, GK.ResolveDeath)
    end)
end
