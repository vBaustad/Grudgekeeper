-- Grudgekeeper - the who-picker: who a page's own action is for. The ledger's "Post a kill order",
-- "Add someone" in the Death Note, "Put someone on Shame" and "Give someone kudos" open it, and so does /grudge post with
-- no enemy targeted (it used to do nothing but print a line: "trykke post a kill order gjør ingenting
-- fordi man må ha et target", the owner, 2026-11-06).
-- A small window with a name box and the people you most likely mean: your target, then for Shame and
-- Kudos your group and whoever left it lately, for a kill order or a mark the enemies seen in the last
-- 15 minutes and your grudges. Typing narrows them, and searches everyone we keep a record of; a name
-- nobody has met is taken as typed. For a kill order and the Death list it is twice as wide and a pick fills
-- its right half (Post.lua, GK.ShowPostHalf), so one is done after another in the same window (2026-11-22);
-- for Shame and Kudos a pick opens the note sheet (GK.OpenNoteSheet), filled in.
-- And for an officer, which enemy guild goes on watch (Notes.lua, GK.WatchGuild): typed in, as the
-- right-click menu needs one of its players in sight - "la GM skrive inn et guildnavn ... om vi ikke
-- klarer å finne noen fra den guilden" (the owner, 2026-11-08).
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

-- In the game's own frame (Letters.lua, GK.MakeFrameSheet), in the skin as the note sheet it leads to:
-- parchment and ink, or the game's dark panel in white and gold (Core.lua, GK.SetLook).
local W, H = 300, 400
local INK, FADED, BLOOD = GK.INK, GK.FADED, GK.BLOOD
local ROWS, ROW_H, ROWS_TOP = 9, 30, 68
local WIDE_W, WIDE_H, WIDE_ROWS = 620, 448, 11     -- a kill order's and the Death list's: the half beside the list
local LEFT_FOR = 2 * 3600       -- who left the group stays a suggestion this long
local MAX_RECENT = 40           -- and at most this many of them are remembered

-- What each kind asks, and whom it suggests: enemies (orders, tracking) or the people you group with.
local KINDS = {
    order = { title = "Post a kill order", enemy = true, wide = true },
    track = { title = "Add to Death Note", enemy = true, wide = true },
    watch = { title = "Who goes on Shame?", list = "watch" },
    kudos = { title = "Who gets kudos?", list = "kudos" },
    guild = { title = "Which guild do we track?", guild = true, hint = "Type the guild's name",
        none = "Type the guild's name as the game shows it, in any case: the game's own spelling takes its "
            .. "place when one of theirs is seen." },
}
local HINT = "Type a name, or pick one"
local NONE = "Nobody to suggest yet. Type their name: first name and surname, as the game shows it."

local function Ink(fs, colour, size) GK.Ink(fs, colour, GK.TEXT_FONT, size) end

local function Times(n) return n == 1 and "once" or (n .. " times") end

-- ---------------------------------------------------------------------------
-- Who was in the group: this session only, never saved. A ninja looter has usually left the group by
-- the time you want to put them on Shame, and nothing else remembers them.
-- ---------------------------------------------------------------------------
local recent, recentCount = {}, 0       -- [key] = { key, c, r, rf, sx, l, now = in the group now, left = time() }

local function Forget()
    while recentCount > MAX_RECENT do
        local oldKey, oldest
        for key, e in pairs(recent) do
            if not e.now and (not oldest or (e.left or 0) < oldest) then oldKey, oldest = key, e.left or 0 end
        end
        if not oldKey then return end                 -- all 40 are in the group now: a raid, keep them
        recent[oldKey] = nil
        recentCount = recentCount - 1
    end
end

--- Who is in the group now, and who just left it. Each member is read once, when they first show up.
function GK.GroupChanged()
    if not (GK.db and GK.ReadPlayer) then return end      -- before login: nobody to read yet
    if GK.InBattleground() then return end     -- a battleground's raid is not your group (GK.InBattleground)
    local was = {}
    for key, e in pairs(recent) do
        if e.now then was[key] = true end
        e.now = nil
    end
    local function Add(unit)
        local key = GK.UnitPlayerKey and GK.UnitPlayerKey(unit)
        if not key then return end
        local e = recent[key]
        if not e then
            e = GK.ReadPlayer(unit)
            if not e then return end
            recent[key] = e
            recentCount = recentCount + 1
        end
        e.now, e.left = true, nil
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do Add("raid" .. i) end
    elseif IsInGroup() then
        for i = 1, 4 do Add("party" .. i) end
    end
    local now = time()
    for key in pairs(was) do
        local e = recent[key]
        if e and not e.now then e.left = now end
    end
    Forget()
end

-- ---------------------------------------------------------------------------
-- The suggestions
-- ---------------------------------------------------------------------------
--- The rows for a kind, before any typing: { section = "..." } headings and { t, why } people, each
--- person once, in the order of the sections.
local function Suggestions(kind)
    local k = KINDS[kind]
    local out, have = {}, {}
    local section
    local function Add(t, why, sec)
        if not (t and type(t.key) == "string") or have[t.key] or LIB.IsMyStoredName(t.key) then return end
        if k.enemy and LIB.roster and LIB.roster[t.key] then return end     -- no kill order on a guildie
        have[t.key] = true
        if sec ~= section then
            out[#out + 1] = { section = sec }
            section = sec
        end
        out[#out + 1] = { t = t, why = why }
    end
    -- your target: an enemy for a kill order, any player for the lists
    local target = (kind == "order" or kind == "track") and GK.ReadUnit("target")
        or (GK.ReadPlayer and GK.ReadPlayer("target"))
    if target then
        Add(target, GK.Describe(target.l, target.c, target.r), "Your target")
    end
    if not k.enemy then
        local now, left = {}, {}
        local cut = time() - LEFT_FOR
        for _, e in pairs(recent) do
            if e.now then now[#now + 1] = e
            elseif (e.left or 0) >= cut then left[#left + 1] = e end
        end
        table.sort(now, function(a, b) return a.key < b.key end)
        table.sort(left, function(a, b) return a.left > b.left end)
        for _, e in ipairs(now) do Add(e, GK.Describe(e.l, e.c, e.r), "In your group") end
        for _, e in ipairs(left) do Add(e, "left the group " .. GK.Ago(e.left), "Left your group lately") end
        return out
    end
    local clock, wall = GetTime(), time()
    for _, s in ipairs(GK.SeenList()) do
        Add(s, "seen " .. GK.Ago(wall - (clock - s.t)) .. (s.z and (" - " .. s.z) or ""), "Seen lately")
    end
    local foes = {}
    for key, f in pairs(GK.char.foes) do
        if (f.k or 0) + (f.d or 0) + (f.a or 0) > 0 then foes[#foes + 1] = { key = key, f = f } end
    end
    table.sort(foes, function(a, b)
        if (a.f.last or 0) ~= (b.f.last or 0) then return (a.f.last or 0) > (b.f.last or 0) end
        return a.key < b.key
    end)
    for i = 1, math.min(#foes, 30) do
        local key, f = foes[i].key, foes[i].f
        local why = (f.d or 0) > 0 and ("killed you " .. Times(f.d))
            or ((f.k or 0) > 0 and ("you killed them " .. Times(f.k))) or ("you helped kill them " .. Times(f.a))
        Add({ key = key, c = f.c, r = f.r, l = f.l }, why .. " - " .. GK.Ago(f.last), "Your grudges")
    end
    return out
end

--- A typed name as a key, if it can be one: one or two words of letters ("First Surname"), each given
--- a capital first letter - a to z, ø to Ø and Cyrillic alike (GK.UpperFirst), as the game writes a
--- name. nil for anything else - digits, a realm, a link.
function GK.TypedName(text)
    -- spaces, digits and punctuation by their ASCII bytes, never by %s, %d and %p: those follow the
    -- locale, and under Latin-1 the bytes of a Cyrillic letter count as both (0xBF inside "п", 0xA0
    -- inside "Р") - "петя" was refused in the smoke test's Lua
    text = strtrim(text or ""):gsub("[ \t]+", " ")
    if text == "" or #text > 40 then return nil end
    local words = {}
    for w in text:gmatch("[^ ]+") do
        if w:find("[0-9!-/:-@%[-`{-~]") then return nil end
        words[#words + 1] = GK.UpperFirst(w)
    end
    if #words > 2 then return nil end
    return GK.KeyOf(table.concat(words, " "))
end

--- The rows for a guild to watch: the enemy guilds seen lately, but the one on watch - their guilds are
--- read only while one is (Sightings.lua), so these come when one takes another's place - and the name
--- as typed: first when no guild seen has it in its name, last when one does.
local function GuildRows(text)
    local raw = strtrim(text or "")
    local find = GK.Lower(raw)
    local guilds, order = {}, {}
    for _, s in ipairs(GK.SeenList()) do                 -- the latest first
        local g = type(s.g) == "string" and s.g ~= "" and not GK.IsGuildWatched(s.g) and s.g
        if g then
            if not guilds[g] then
                guilds[g] = { n = 0, t = s.t, z = s.z }
                order[#order + 1] = g
            end
            guilds[g].n = guilds[g].n + 1
        end
    end
    local out, have = {}, {}
    local clock, wall = GetTime(), time()
    for _, g in ipairs(order) do
        if find == "" or GK.Lower(g):find(find, 1, true) then
            if #out == 0 then out[1] = { section = "Seen lately" } end
            local e = guilds[g]
            out[#out + 1] = { t = { guild = g }, why = ("%d of theirs, seen %s%s"):format(e.n,
                GK.Ago(wall - (clock - e.t)), e.z and (" - " .. e.z) or "") }
            have[GK.Lower(g)] = true
        end
    end
    local typed = find ~= "" and GK.ValidGuildName(raw)
    if typed and not have[GK.Lower(typed)] then
        table.insert(out, next(have) and #out + 1 or 1, { t = { guild = typed }, why = "as you wrote it", typed = true })
    end
    return out
end

--- The rows for what is typed: the suggestions whose name has it in them, then everyone else we keep a
--- record of who does (the guild's notes, the leaderboard's names on an enemy kind, your grudges), and
--- the name as typed when it is nobody's. Without typing, the suggestions.
function GK.PickRows(kind, text)
    if KINDS[kind] and KINDS[kind].guild then return GuildRows(text) end
    local rows = Suggestions(kind)
    -- in any case, Cyrillic and ø included: string.lower knows a to z only (GK.Lower)
    text = GK.Lower(strtrim(text or ""))
    if text == "" then return rows end
    local out, have, section = {}, {}, nil
    local function Match(key) return GK.Lower(GK.Show(key)):find(text, 1, true) ~= nil end
    for _, r in ipairs(rows) do
        if r.section then section = r.section
        elseif Match(r.t.key) then
            if section then
                out[#out + 1] = { section = section }
                section = nil
            end
            out[#out + 1] = r
            have[r.t.key] = true
        end
    end
    local more = {}
    local function Known(key, t, why)
        if have[key] or LIB.IsMyStoredName(key) or not Match(key) then return end
        if KINDS[kind].enemy and LIB.roster and LIB.roster[key] then return end
        have[key] = true
        more[#more + 1] = { t = t, why = why }
    end
    for key, p in pairs(GK.Store().people or {}) do
        Known(key, { key = key, c = p.c, r = p.r, rf = p.rf, sx = p.sx, l = p.l }, "in the guild's notes")
    end
    for key, f in pairs(GK.char.foes) do Known(key, { key = key, c = f.c, r = f.r, l = f.l }, "in your grudges") end
    table.sort(more, function(a, b) return a.t.key < b.t.key end)
    if #more > 0 then out[#out + 1] = { section = "Known" } end
    for i = 1, math.min(#more, 20) do out[#out + 1] = more[i] end
    -- the name as typed: first when nobody matches (Enter takes it), last when someone does - "gaer" is
    -- more likely the start of Gaerd Balle than a player called Gaer
    local typed = GK.TypedName(text)
    if typed and not have[typed] and not LIB.IsMyStoredName(typed)
        and not (KINDS[kind].enemy and LIB.roster and LIB.roster[typed]) then
        table.insert(out, next(have) and #out + 1 or 1, { t = { key = typed }, why = "as you wrote it", typed = true })
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The sheet
-- ---------------------------------------------------------------------------
local frame                 -- made on first use
local kind = "order"
local rows = {}             -- what the sheet lists now
local offset = 0
local chosen                -- whom the half is on: { key, ... }
local Fill

--- Whom the right half is on, and their row marked. nil: nobody yet.
local function Choose(t)
    chosen = t
    local wide = KINDS[kind].wide == true
    GK.ShowPostHalf(frame, wide and kind or nil, t)
    frame.pickOne:SetShown(wide and t == nil)
    Fill()
end

local function Pick(r)
    if not (r and r.t) then return end
    if KINDS[kind].wide then
        frame.box:ClearFocus()
        return Choose(r.t)
    end
    frame:Hide()
    if r.t.guild then
        -- on Grudges' Versus, where it shows
        if GK.WatchGuild(r.t.guild, true) then GK.OpenLedgerView("Grudges", "guild")
        else print(GK.TAG .. ": only an officer or the guild master can track a guild.") end
    else
        GK.OpenNoteSheet(r.t, KINDS[kind].list)
    end
end

--- What stands at a row's right: an open order's seal and gold, or the Death list's eye.
local function RowMark(b, t)
    local icon, words
    if kind == "order" and t and GK.OrderOn then
        local o = GK.OrderOn(t.key, t.guid)
        if o and o.state == "o" then
            local pot = GK.Pot(o)
            icon, words = "seal_red", pot > 0 and GK.Coins(pot) or ""
        end
    elseif kind == "track" and t and GK.IsTracked and GK.IsTracked(t.key) then
        icon, words = "eye", ""
    end
    b.mark:SetShown(icon ~= nil)
    if icon then b.mark:SetTexture("Interface\\AddOns\\Grudgekeeper\\Media\\" .. icon) end
    b.pot:SetText(words or "")
    local taken = icon and (22 + (words ~= "" and math.ceil(b.pot:GetStringWidth() or 0) + 10 or 0)) or 0
    b.name:SetWidth(W - 78 - taken)
    b.why:SetWidth(W - 78 - taken)
end

Fill = function()
    rows = GK.PickRows(kind, frame.box:GetText())
    local most = KINDS[kind].wide and WIDE_ROWS or ROWS
    offset = math.max(0, math.min(offset, #rows - most))
    for i, b in ipairs(frame.rows) do
        local r = i <= most and rows[i + offset] or nil
        RowMark(b, r and r.t)
        b.on:SetShown(chosen ~= nil and r ~= nil and r.t ~= nil and r.t.key ~= nil and r.t.key == chosen.key)
        b.r = r
        b:SetShown(r ~= nil)
        if r and r.section then
            b:EnableMouse(false)
            b.face:SetShown(false)
            b.name:SetText("")
            b.why:SetText("")
            b.head:SetText(r.section:upper())
        elseif r then
            b:EnableMouse(true)
            b.head:SetText("")
            b.face:SetShown(true)
            b.face:Set(r.t.guild and {} or r.t)          -- a guild: the seal, as its row in the ledger
            local shown = r.t.guild and ("<" .. r.t.guild .. ">") or GK.Show(r.t.key)
            b.name:SetText(r.typed and ('"' .. shown .. '"') or shown)
            b.why:SetText(r.why or "")
        end
    end
    local any = false
    for _, r in ipairs(rows) do any = any or r.t ~= nil end
    frame.none:SetShown(not any)
end

local function Build()
    local f = GK.MakeFrameSheet("GrudgekeeperPick", W, H, "")
    f.box = GK.FrameBox(f, W - 48, 40, HINT)
    f.box:SetPoint("TOPLEFT", 26, -38)
    f.box:HookScript("OnTextChanged", function()
        offset = 0
        Fill()
    end)
    f.box:SetScript("OnEscapePressed", function() f:Hide() end)
    f.box:SetScript("OnEnterPressed", function()
        for _, r in ipairs(rows) do
            if r.t then return Pick(r) end
        end
    end)

    -- a row is a person (a face in the ring, the name, why they are offered) or a section's heading in
    -- small capitals, in the ink of the ledger
    local inner = W - 40
    f.rows = {}
    for i = 1, WIDE_ROWS do
        local b = CreateFrame("Button", nil, f)
        b:SetSize(inner, ROW_H)
        b:SetPoint("TOPLEFT", 20, -(ROWS_TOP + (i - 1) * ROW_H))
        local hi = b:CreateTexture(nil, "BACKGROUND")
        hi:SetAllPoints()
        GK.Paint(hi, "blood", 0.10)
        hi:Hide()
        b.face = GK.MakePortrait(b, 26)
        b.face.tex:SetPoint("CENTER", b, "LEFT", 16, 0)
        b.name = b:CreateFontString(nil, "ARTWORK")
        Ink(b.name, INK, 12)
        b.name:SetPoint("TOPLEFT", 34, -2)
        b.name:SetWidth(inner - 38)
        b.name:SetJustifyH("LEFT")
        b.name:SetWordWrap(false)
        b.why = b:CreateFontString(nil, "ARTWORK")
        Ink(b.why, FADED, 10)
        b.why:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
        b.why:SetWidth(inner - 38)
        b.why:SetJustifyH("LEFT")
        b.why:SetWordWrap(false)
        b.head = b:CreateFontString(nil, "ARTWORK")
        Ink(b.head, FADED, 10)
        b.head:SetPoint("BOTTOMLEFT", 4, 5)
        b.on = b:CreateTexture(nil, "BACKGROUND", nil, 1)     -- whom the half is on
        b.on:SetAllPoints()
        GK.Paint(b.on, "blood", 0.14)
        b.on:Hide()
        b.mark = b:CreateTexture(nil, "ARTWORK")
        b.mark:SetSize(20, 20)
        b.mark:SetPoint("RIGHT", -4, 0)
        b.mark:Hide()
        b.pot = b:CreateFontString(nil, "ARTWORK")
        Ink(b.pot, INK, 11)
        b.pot:SetPoint("RIGHT", b.mark, "LEFT", -4, 0)
        b:SetScript("OnEnter", function() hi:Show() end)
        b:SetScript("OnLeave", function() hi:Hide() end)
        b:SetScript("OnClick", function(self) Pick(self.r) end)
        f.rows[i] = b
    end
    f.none = f:CreateFontString(nil, "ARTWORK")
    Ink(f.none, FADED, 11)
    f.none:SetPoint("TOPLEFT", 26, -(ROWS_TOP + 8))
    f.none:SetWidth(W - 52)
    f.none:SetJustifyH("LEFT")
    f.none:SetSpacing(3)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        offset = math.max(0, offset - delta * 2)
        Fill()
    end)
    f.cancel = GK.FrameButton(f, CANCEL or "Cancel", 96, function() f:Hide() end)
    f.cancel:SetPoint("BOTTOMRIGHT", -16, 14)
    -- between the halves, and the right one's words while nobody is chosen
    f.divider = f:CreateTexture(nil, "BORDER")
    GK.Paint(f.divider, "rule")
    f.divider:SetSize(1, WIDE_H - 52)
    f.divider:SetPoint("TOPLEFT", W, -34)
    f.pickOne = f:CreateFontString(nil, "ARTWORK")
    Ink(f.pickOne, FADED, 12)
    f.pickOne:SetPoint("CENTER", f, "TOPLEFT", (W + WIDE_W) / 2, -WIDE_H / 2)
    f.pickOne:SetText("Pick someone on the left.")
    -- the guild picker's way to track none
    f.stop = GK.FrameButton(f, "Stop tracking", 120, function()
        local current = GK.WatchedGuild()
        f:Hide()
        if current and GK.WatchGuild(current, false) then GK.OpenLedgerView("Grudges", "guild") end
    end)
    f.stop:SetPoint("BOTTOMLEFT", 16, 14)
    frame = f
end

--- Open the picker for a kind: "order" (a kill order), "track", a list - "watch" or "kudos" - or "guild",
--- the guild on watch.
--- The picker for a kind. t: whom it opens on (a kill order's or the Death list's half); else your target,
--- where that is an enemy.
function GK.OpenPicker(k, t)
    if not KINDS[k] then return end
    if not frame then Build() end
    kind, offset = k, 0
    local wide = KINDS[k].wide == true
    if wide then t = t or GK.ReadUnit("target") else t = nil end
    frame:SetSize(wide and WIDE_W or W, wide and WIDE_H or H)
    frame.divider:SetShown(wide)
    frame.cancel:ClearAllPoints()
    if wide then frame.cancel:SetPoint("BOTTOMRIGHT", -166, 14) else frame.cancel:SetPoint("BOTTOMRIGHT", -16, 14) end
    frame.cancel:SetText(wide and (CLOSE or "Close") or (CANCEL or "Cancel"))
    frame.title:SetText(KINDS[k].title)
    frame.box.hint:SetText(KINDS[k].hint or HINT)
    frame.none:SetText(KINDS[k].none or NONE)
    frame.box:SetText("")
    frame.stop:SetShown(k == "guild" and GK.WatchedGuild() ~= nil and GK.CanWatchGuild())
    Choose(t)
    GK.PlaceSheet(frame)
    frame:Show()
    frame:Raise()
    -- with somebody to seal already the keys stay the player's: it opens from a right-click, out in the world
    if t then frame.box:ClearFocus() else frame.box:SetFocus() end
end

--- The rows again, where the half has changed one (Post.lua).
function GK.PickRefill()
    if frame and frame:IsShown() then Fill() end
end

LIB.On("GROUP_ROSTER_UPDATE", function() GK.GroupChanged() end)
LIB.On("PLAYER_ENTERING_WORLD", function() GK.GroupChanged() end)

-- ---------------------------------------------------------------------------
-- The Death list's small window
-- ---------------------------------------------------------------------------
-- "det må være relativt raskt, så kan komme et veldig lite vindu, med mulighet for å skrive note, avbryt eller
-- legg til uavhengig av ting i note", "ikke ved musa, bare centrert og litt høyere Y" and "et mini vindu samme som
-- søkevinduet" (the owner, 2026-11-22): the picker's frame, box and buttons, small. In a block: its own names.
do
    local MINI_W, MINI_H, MINI_UP = 300, 132, 150
    local mini, noting

    local function Save()
        local t, text = noting, mini.box:GetText()
        noting = nil
        mini:Hide()
        if not t then return end
        if not GK.IsTracked(t.key) and not GK.TrackSaying(t) then return end
        GK.SetDeathNote(t.key, text)
    end

    local function BuildMini()
        local f = GK.MakeFrameSheet("GrudgekeeperDeathNote", MINI_W, MINI_H, "")
        f.who = f:CreateFontString(nil, "ARTWORK")
        Ink(f.who, INK, 14)
        f.who:SetPoint("TOP", 0, -34)
        f.who:SetWidth(MINI_W - 40)
        f.who:SetWordWrap(false)
        f.box = GK.FrameBox(f, MINI_W - 48, GK.DEATH_NOTE_MAX, "Note, if you want one. Only you see it.")
        f.box:SetPoint("TOPLEFT", 26, -58)
        f.box:SetScript("OnEnterPressed", Save)
        f.box:SetScript("OnEscapePressed", function() f:Hide() end)
        f.cancel = GK.FrameButton(f, CANCEL or "Cancel", 96, function() f:Hide() end)
        f.cancel:SetPoint("BOTTOMLEFT", 22, 14)
        f.ok = GK.FrameButton(f, "Add", 120, Save)
        f.ok:SetPoint("BOTTOMRIGHT", -16, 14)
        mini = f
    end

    --- Put someone on the Death list, or write their note: t = { key, c, r, l }. Add works with nothing written.
    --- The box takes the keyboard at a click, not as the window opens: it opens out in the world, and a W meant
    --- to run would be a letter in the note.
    function GK.OpenDeathNote(t)
        if not (t and type(t.key) == "string") then return end
        if not mini then BuildMini() end
        noting = t
        local on = GK.IsTracked(t.key)
        mini.title:SetText(on and "In your Death Note" or "Add to Death Note")
        mini.who:SetText(GK.Show(t.key))
        mini.ok:SetText(on and "Save" or "Add")
        mini.box:SetText(on and GK.DeathNote(t.key) or "")
        mini.box.hint:SetShown((mini.box:GetText() or "") == "")
        mini.box:ClearFocus()
        -- the same place every time, whatever is open and wherever it was dragged to
        mini:ClearAllPoints()
        mini:SetPoint("CENTER", UIParent, "CENTER", 0, MINI_UP)
        mini.onLedger = nil
        mini:Show()
        mini:Raise()
    end
end
