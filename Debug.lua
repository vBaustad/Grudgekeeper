-- Grudgekeeper - a TEMPORARY test panel: /grudge debug. Buttons that make things happen, so every part
-- can be tried in game before there are real kills to try it on (the user, 2026-11-04: "lag bare et
-- lite panel som vi fjerner senere"). To remove it: delete this file and its line in the TOC, the
-- OpenDebug line in Core.lua's /grudge, and GK.testMode, GK.ReceiveForTest and GK.InvalidateOrders in
-- Guild.lua.
--
-- While the panel is open nothing leaves this client: no addon message to the guild, no line in guild
-- chat. When it closes - or the game logs out or reloads with it open - your own record and the guild's
-- store are put back exactly as they were when it opened, so nothing the buttons did is kept.
-- The pretend guildies are Kari and Edvard; the pretend enemies are Pølse Hans and Gærd Balle, of
-- whichever side is not yours. With an enemy player targeted, "your target" is them instead.
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

local panel
local saved            -- { char, store, storeTable } while testing

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
    -- not ours to put back: test mode with nothing saved here is the screenshot mode's (Shots.lua)
    if not (GK.testMode and saved) then return end
    GK.testMode = false
    if saved then
        PutBack(GK.char, saved.char)
        PutBack(saved.storeTable, saved.store)
        saved = nil
    end
    GK.InvalidateOrders()
    GK.CloseLetters()
    GK.NoticeUpdate(false)
    GK.Changed()
    Say("your record and the guild's are back as they were before the test panel.")
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
    wipe(s)
    s.board, s.orders, s.wanted, s.slain, s.tormentors, s.feed, s.people, s.nextId = {}, {}, {}, {}, {}, {}, {}, 1
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
local WARN_WAY = { alertNear = "screen", leadNear = "screen", noteAlerts = "screen", watchGroup = "screen",
    kudosGroup = "chat" }
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
        -- your own order, fulfilled by Edvard: the card of what you owe shows at a mailbox
        local o = GK.PostOrder(Enemy("Gærd Balle", "HUNTER"), 50000, "Test: you owe Edvard 5g")
        if o then Hear("Edvard", "F", 1, LIB.Me(), o.id, GK.Zone()) end
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

    -- the rows of Settings, Warnings, in its order, and the tracked enemy's, which has no row
    { "Warnings" },
    { "Kill order target near", function()
        local v = TheEnemy()
        Warning("alertNear", ("%s is near!"):format(GK.Show(v.key)), true, nil, v.key)
    end },
    { "One who leads over me", function()
        local v = TheEnemy()
        Warning("leadNear", ("%s is near - owed %d"):format(GK.Show(v.key), 2), true, nil, v.key)
    end },
    { "Tracked enemy near", function()
        local v = TheEnemy()
        GK.Warn(("Tracked: %s is near!"):format(GK.Show(v.key)), true, nil, v.key, v.key)
    end },
    { "Marked player near", function()
        local v = TheEnemy()
        Warning("noteAlerts", ("Marked: %s is near!"):format(GK.Show(v.key)), true, nil, v.key)
    end },
    { "Shame player joins", function()
        Warning("watchGroup", ("Shame list: %s joined your group"):format("Edvard"), true, true)
    end },
    { "Kudos player joins", function()
        Warning("kudosGroup", ("|cff4dff66Kudos:|r %s joined your group"):format("Edvard"), false)
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
-- Notifications page, 2026-11-20). A sound picked in place of a tier's voice is what plays; with Sound off, nothing.
local HELD = { "spreeMine", "spreeGuild", "spreeGuildFrom", "rankMine", "rankGuild", "rankGuildFrom", "orderMine",
    "orderDone", "spreeEnded", "spreeEndedGuild", "spreeTormentor", "spreeTormentorGuild", "guildZoneOnly",
    "guildSounds", "announceWhenMine", "announceWhenGuild", "reaperEffect", "revengeMine", "revengeGuild" }

local function Announce(set, event, ...)
    local was = {}
    for _, k in ipairs(HELD) do was[k] = GK.db[k] end
    GK.db.announceWhenMine, GK.db.announceWhenGuild = "always", "always"
    GK.db.spreeGuildFrom, GK.db.rankGuildFrom, GK.db.guildZoneOnly, GK.db.guildSounds = 3, 0, false, true
    for k, v in pairs(set) do GK.db[k] = v end
    LIB.Fire(event, ...)        -- its listeners run at once (LibForever), so the settings above are what they read
    for _, k in ipairs(HELD) do GK.db[k] = was[k] end
    if not GK.db.sound then Say("Sound is off in Grudgekeeper's settings, so this one is silent.") end
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

-- The rows of Settings, Notifications, in its order: yours as splashes, each with its effect - a spree ended and
-- a tormentor too, which come as toasts out of the box: their splashes are dakristia's shatter and the grudge book
-- slamming down (T4, 2026-11-21), and as toasts the panel showed neither ("hvorfor er det ikke den animasjonen som
-- kom fra daniel hvor streaken knuses?", the owner, 2026-11-20) - then a guildie's, Kari's, as toasts. Each tier of a spree has its own
-- effect and voice; Reaper's is the one Settings, Look picks. The smoke had a button of its own until the
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
        if not a[2] then
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
    panel:HookScript("OnHide", Restore)
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
