-- Grudgekeeper - the characters of one account.
-- Each character keeps its own grudges (GK.char.foes) as it always did. On top of that every character
-- writes a small copy of them into account data (GK.db.alts[charKey].copy), so another character can show
-- "all my characters" without anyone's score being merged or moved: a bug here can hide a row, never lose
-- history. A grudge removed from another character's view is a note (GK.db.altRemoved) that character
-- applies at its next login, before anything else touches its foes (docs/alt-sync.md, D2 and D4).
-- Saved account keys (all new): alts, altFirst, altRemoved, altNudged, altView.
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")
local Secret = GK.Secret or function() return false end

-- The fields of a grudge the copy keeps: the counts, the times, and what a row needs to draw. Not `hits`.
local COPY_FIELDS = { "n", "c", "r", "l", "k", "d", "a", "last", "lastKill", "lastAssist", "lastDeath" }
local TIME_FIELDS = { "last", "lastKill", "lastAssist", "lastDeath" }

--- This character's side, "Alliance" or "Horde", or nil when the client does not say (or says Neutral).
local function MySide()
    local side = UnitFactionGroup("player")
    if Secret(side) then return nil end
    if side == "Alliance" or side == "Horde" then return side end
    return nil
end

--- This character's name and realm. The lib may give "Name-Realm" or the name alone; the realm then
--- comes from LIB.Realm. No realm known: realm is nil.
local function MyNameRealm()
    local me = LIB.Me()
    if type(me) ~= "string" or me == "" or Secret(me) then return nil end
    local name, realm = me:match("^(.-)%-([^%-]*)$")
    if not name or name == "" then name, realm = me, nil end
    if not realm or realm == "" then
        realm = LIB.Realm and LIB.Realm() or nil
        if type(realm) ~= "string" or realm == "" or Secret(realm) then realm = nil end
    end
    return name, realm
end

--- This character's key on the account, "Name-Realm"; the name alone when no realm is known, and never a key
--- ending in "-". Nil when the lib does not know who we are yet.
function GK.MyAltKey()
    local name, realm = MyNameRealm()
    if not name then return nil end
    if realm then return name .. "-" .. realm end
    return name
end

--- A grudge in the shape the copy keeps: only the fields it has, no hits.
local function CopyRow(f)
    local row = {}
    for _, field in ipairs(COPY_FIELDS) do
        if f[field] ~= nil then row[field] = f[field] end
    end
    return row
end

local function CopyOfFoes(foes)
    local copy = {}
    for key, f in pairs(foes or {}) do
        if type(f) == "table" then copy[key] = CopyRow(f) end
    end
    return copy
end

--- Rebuild this character's roster entry and its copy of the grudges. The first entry the roster ever gets
--- is remembered as the first character the account saw (the nudge, D1). Not in the test panel's mode.
function GK.WriteAltCopy()
    if GK.testMode or not (GK.db and GK.char) then return end
    local key, side = GK.MyAltKey(), MySide()
    if not (key and side) then return end
    local name, realm = MyNameRealm()
    local alts = GK.db.alts
    local entry = alts[key]
    if not entry then
        entry = { first = time() }
        alts[key] = entry
    end
    entry.name, entry.realm, entry.side = name, realm, side
    entry.copy = CopyOfFoes(GK.char.foes)
    if GK.db.altFirst == nil then GK.db.altFirst = key end
end

--- A grudge and its log lines gone from this character, with no word to the guild (GK.ForgetGrudge tells it).
local function DropFoe(key)
    GK.char.foes[key] = nil
    local log = GK.char.log
    for i = #log, 1, -1 do
        if log[i].n == key then table.remove(log, i) end
    end
end

--- The newest time of a kill, an assist or a death in a grudge, 0 when it has none.
local function LatestEvent(f)
    return math.max(f.lastKill or 0, f.lastAssist or 0, f.lastDeath or 0)
end

--- Another character removed grudges from this one's view: delete them here, then clear the notes. A grudge with
--- a kill, death or assist newer than its note stays (D4's safeguard), and so does its note's end: the note goes.
function GK.ApplyAltRemovals()
    if GK.testMode or not (GK.db and GK.char) then return end
    local key = GK.MyAltKey()
    local notes = key and GK.db.altRemoved[key]
    if not notes then return end
    for foeKey, at in pairs(notes) do
        local f = GK.char.foes[foeKey]
        if f and not (LatestEvent(f) > (tonumber(at) or 0)) then DropFoe(foeKey) end
    end
    GK.db.altRemoved[key] = nil
end

local listening = false

--- Start: removals first (D4: before anything else touches the grudges), then the copy, then keep it fresh.
function GK.StartAlts()
    GK.ApplyAltRemovals()
    GK.WriteAltCopy()
    if not listening then
        listening = true
        LIB.Listen("GRUDGEKEEPER_CHANGED", GK.WriteAltCopy)
    end
end

--- The characters of this account on my side, me included, by name: roster entries ({ name, realm, side, first,
--- copy }) each with its charKey as `key`.
function GK.AltsOnSide()
    local out, side = {}, MySide()
    if not (GK.db and GK.db.alts and side) then return out end
    for key, e in pairs(GK.db.alts) do
        if e.side == side then
            out[#out + 1] = { key = key, name = e.name or key, realm = e.realm, side = e.side, first = e.first,
                copy = e.copy }
        end
    end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return a.key < b.key
    end)
    return out
end

--- One character's copy without the grudges removed from its view by a note.
local function VisibleCopy(charKey)
    local e = GK.db.alts[charKey]
    local out = {}
    if not (e and e.copy) then return out end
    local removed = GK.db.altRemoved[charKey]
    for foeKey, row in pairs(e.copy) do
        if not (removed and removed[foeKey]) then out[foeKey] = row end
    end
    return out
end

--- The grudges to show: which is "me" (live, this character's own), a charKey (that character's copy, minus what
--- was removed), or "all" (the same side's characters added up: kills, deaths and assists summed, the times the
--- newest, name, class, race and level from the one met last). { [foeKey] = row }, rows as the copy has them.
function GK.AltGrudges(which)
    if not (GK.db and GK.char) then return {} end
    local mine = GK.MyAltKey()
    if which == "me" or which == mine then return CopyOfFoes(GK.char.foes) end
    if which ~= "all" then return VisibleCopy(which) end
    local sources = { CopyOfFoes(GK.char.foes) }
    local side = MySide()
    for key, e in pairs(GK.db.alts) do
        if key ~= mine and e.side == side then sources[#sources + 1] = VisibleCopy(key) end
    end
    local out, newest = {}, {}
    for _, src in ipairs(sources) do
        for foeKey, row in pairs(src) do
            local sum = out[foeKey]
            if not sum then
                sum = { k = 0, d = 0, a = 0 }
                out[foeKey] = sum
            end
            sum.k, sum.d, sum.a = sum.k + (row.k or 0), sum.d + (row.d or 0), sum.a + (row.a or 0)
            for _, field in ipairs(TIME_FIELDS) do
                if row[field] and row[field] > (sum[field] or 0) then sum[field] = row[field] end
            end
            if not newest[foeKey] or (row.last or 0) > newest[foeKey] then
                newest[foeKey] = row.last or 0
                for _, field in ipairs({ "n", "c", "r", "l" }) do sum[field] = row[field] end
            end
        end
    end
    return out
end

--- Remove a grudge from a view (D4). "me" or my own key: as today (GK.ForgetGrudge), and my copy follows. Another
--- character: a note it applies at its next login, and its row is hidden at once. "all": mine, and a note for
--- each other character on my side that has the grudge.
function GK.RemoveAltGrudge(which, foeKey)
    if not (GK.db and GK.char) or type(foeKey) ~= "string" then return end
    local mine = GK.MyAltKey()
    local function noteFor(charKey)
        local notes = GK.db.altRemoved[charKey] or {}
        notes[foeKey] = time()
        GK.db.altRemoved[charKey] = notes
    end
    local function forgetMine()
        if GK.ForgetGrudge then GK.ForgetGrudge(foeKey) else DropFoe(foeKey) end
        GK.WriteAltCopy()
    end
    if which == "me" or which == mine then
        forgetMine()
    elseif which == "all" then
        -- only a grudge this character has: ForgetGrudge tells the guild, and there is nothing to tell
        if GK.char.foes[foeKey] then forgetMine() end
        local side = MySide()
        for key, e in pairs(GK.db.alts) do
            if key ~= mine and e.side == side and e.copy and e.copy[foeKey] then noteFor(key) end
        end
    elseif GK.db.alts[which] then
        noteFor(which)
    end
end

--- The nudge in the Death Note page (D1): on a character that is not the first the account saw, while the shared
--- Death Note is off and the nudge never handled. The shared note is per side, so the nudge only concerns
--- characters on the same side: it needs another character of mine on this side, or there is nobody to share with.
function GK.ShowAltNudge()
    if GK.testMode or not (GK.db and GK.char) then return false end
    if GK.db.deathNoteShared or GK.db.altNudged then return false end
    local me = GK.MyAltKey()
    if not me or GK.db.altFirst == me then return false end
    for _, e in ipairs(GK.AltsOnSide()) do
        if e.key ~= me then return true end
    end
    return false
end

--- The One Death Note setting turned on: this character's own list joins the shared one (the Settings box and
--- the nudge both do this).
function GK.DeathNoteTurnedOn()
    GK.db.deathNoteTick = (GK.db.deathNoteTick or 0) + 1
    if GK.JoinDeathNote then GK.JoinDeathNote() end
end

--- The nudge's "Share my Death Note": the setting on, as its box does, and the nudge handled.
function GK.AltNudgeShare()
    if not GK.db then return end
    GK.db.deathNoteShared = true
    GK.DeathNoteTurnedOn()
    GK.db.altNudged = true
end

--- The nudge's "Keep separate": handled, the setting as it was.
function GK.AltNudgeKeep()
    if GK.db then GK.db.altNudged = true end
end
