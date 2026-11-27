-- Grudgekeeper - letters: news that waits until you open it.
-- Nothing pops up. A letter goes into your pile, the notice scroll (Notice.lua) shows that something
-- came, and clicking it opens the letter. Every letter opens in ONE window, the iron-framed letter, with
-- the pile at its foot (2026-11-18). Two kinds of page in it:
--   an ORDER's, with the face of whom it is about and the bounty under it:
--     order     KILL ORDER       a guildie put a price on someone       red seal
--     complete  ORDER COMPLETE   an order was fulfilled                 broken seal, FULFILLED stamp
--   a NOTE, written by "the Grudgekeeper", with his own portrait:
--     kill      A new title      a kill earned you one: where you stand  red seal
--     slain     Slain            someone killed you                     black seal, blood
--     paid      Bounty paid      the poster paid you                    red seal
--     expired   Order expired    your order ran out                     black seal
-- The paper, seals and blood are drawn by art/make_grudgekeeper_art.py (or imported from generated art by
-- art/import_grudgekeeper.py); the stamps by art/make_grudgekeeper_stamps.py.
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

local MAX_LETTERS = 30
local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"
local TITLE_FONT = "Fonts\\MORPHEUS.ttf"
local TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local STAMP_ALPHA = 0.55                 -- a letter's stamp, under its writing (BuildLetter)
local INK = { 0.22, 0.13, 0.05 }
local FADED = { 0.35, 0.25, 0.15 }
local BLOOD = { 0.47, 0.06, 0.04 }
-- The letter: the frame's own 3:2, so it isn't stretched. 540 x 360 held a note; a kill order's face, name,
-- words and buttons need the room of the sketch the owner chose (art/mockups/letters, 2026-11-18).
local NOTE = { kill = true, slain = true, paid = true, expired = true, news = true }

-- The badge the notice scroll wears for the newest unread letter: the sealed scroll, or the bloodied
-- letter when someone killed you.
GK.LETTER_ICON = {
    order = MEDIA .. "notice",
    complete = MEDIA .. "notice",
    paid = MEDIA .. "notice",
    expired = MEDIA .. "notice",
    kill = MEDIA .. "notice",
    slain = MEDIA .. "notice_death",
    news = MEDIA .. "notice",
}

-- ---------------------------------------------------------------------------
-- The pile
-- ---------------------------------------------------------------------------
-- A letter is news, and once read it goes: when the letters close, every letter read goes with them. They
-- were kept three days and piled up - "10 of 10" - each saying what the ledger says anyway: "letters
-- burde kanskje ikke bare bli liggende?" (the owner, 2026-11-07). While the letters are open, the ones
-- read stay, so the arrows can go back.
local reading = false            -- the letters are open: what was read stays until they close
local index                      -- which letter in the pile is open (the letter window, below)

local function Prune()
    local list = GK.char.letters
    for i = #list, 1, -1 do
        if list[i].read and not reading then table.remove(list, i) end
    end
    -- Past MAX_LETTERS a guildie's order goes first, the oldest: the ledger lists those, and 29 of them pushed
    -- out the letter that said your own was fulfilled (simulated, 2026-11-22). Never the letter that is open.
    while #list > MAX_LETTERS do
        local out, first
        for i, L in ipairs(list) do
            if not (reading and i == index) then
                first = first or i
                if L.kind == "order" then out = i break end
            end
        end
        out = out or first
        table.remove(list, out)
        if index and out < index then index = index - 1 end
    end
end

-- A letter about your own kill waits before the notice shows it: it goes into the pile at once, but
-- the notice and the unread count leave it out until a minute after the kill AND you are out of combat.
-- Right after a fight it was one more thing blinking at you (the owner, 2026-11-05: "it can be annoying
-- when it pops right after combat - wait a minute?"). Another kill in that minute joins the same letter
-- and starts the minute again. Kept here, not in the saved letter: a reload lets it land at once.
local KILL_HOLD = 60
local holding = setmetatable({}, { __mode = "k" })   -- letter -> GetTime() it may land
local releasePending = false
local Release

-- An unread letter fades from the letter icon after a while, so they do not stand there blinking for
-- ever: "kanskje uleste brev fader bort etter en liten stund også. slik at folk ikke blir spammet. og så i
-- settings kan de velge senere om de vil ha de oppe hele tiden" (the owner, 2026-11-10). It is not thrown
-- away: it stays in the pile, faded (L.faded, saved), and out of the unread count - Letters in the ledger
-- still opens it, and what it said is in the ledger and the mailbox's card anyway. "Letters wait until
-- read" in the settings (GK.db.keepLetters) keeps them by the icon until read, as before.
local FADE_AFTER = 120
local landedAt = setmetatable({}, { __mode = "k" })  -- letter -> GetTime() it landed, this session
local fadePending = false
local FadeDue

--- A letter is news from now: its time by the icon starts.
local function Landed(L)
    landedAt[L] = GetTime()
    if not fadePending then
        fadePending = true
        C_Timer.After(FADE_AFTER + 0.1, FadeDue)
    end
end

FadeDue = function()
    fadePending = false
    if GK.db.keepLetters then return end
    -- out of sight in a battleground, nothing fades: each letter's while starts again as you leave
    if GK.InBattleground() then return end
    local now, soonest, faded = GetTime(), nil, false
    for _, L in ipairs(GK.char.letters) do
        local at = landedAt[L]
        -- the letters open in front of you: nothing fades; Closed looks again once they close
        if at and not L.read and not L.faded and not holding[L] and not reading then
            if now - at >= FADE_AFTER then
                L.faded, faded = true, true
                landedAt[L] = nil
            else
                soonest = math.min(soonest or math.huge, FADE_AFTER - (now - at))   -- again when it is due
            end
        end
    end
    if soonest and not fadePending then
        fadePending = true
        C_Timer.After(soonest + 0.1, FadeDue)
    end
    if faded then
        GK.NoticeUpdate(false, nil, true)
        GK.Changed()
    end
end
--- "Letters wait until read" unticked: what has waited long enough fades now (Options.lua).
GK.FadeLetters = FadeDue

local function Hold(L)
    landedAt[L] = nil                               -- held, it is not by the icon: its time starts on landing
    holding[L] = GetTime() + KILL_HOLD
    if not releasePending then
        releasePending = true
        C_Timer.After(KILL_HOLD + 0.1, Release)
    end
end

Release = function()
    releasePending = false
    local now, soonest, landed = GetTime(), nil, false
    for L, at in pairs(holding) do
        if at > now then
            soonest = math.min(soonest or math.huge, at - now)
        elseif not InCombatLockdown() and not GK.InBattleground() then
            holding[L], landed = nil, true
            Landed(L)
        end
        -- its minute is up but you are fighting: PLAYER_REGEN_ENABLED calls this again; or in a
        -- battleground: leaving it does (GK.StartLetters)
    end
    if soonest and not releasePending then
        releasePending = true
        C_Timer.After(soonest + 0.1, Release)
    end
    if landed then
        GK.NoticeUpdate(true, true)
        GK.Changed()
    end
end

--- A letter still held back after your own kill: in the pile, not yet news.
function GK.Held(L) return holding[L] ~= nil end

-- silent: no sound as it lands - a letter about something you just did yourself, like a kill, is no
-- news to you, so it only waits by the minimap. hold: it waits a minute and for the fight to end first.
local function Add(kind, data, silent, hold)
    -- letters off: nothing arrives as one ("tillat å skru av letters", the owner, 2026-11-09) - the ledger,
    -- the warnings and the mailbox's card still say what matters
    if GK.db.anyLetters == false then return data end
    -- the test panel asking what would come (Debug.lua): said, and no letter made
    if GK.probe then
        GK.probe("letter", kind, (hold or GK.InBattleground()) and true or nil)
        return data
    end
    GK.char.letterId = (GK.char.letterId or 0) + 1
    data.id, data.kind, data.t, data.read = GK.char.letterId, kind, time(), false
    local list = GK.char.letters
    list[#list + 1] = data
    Prune()
    -- in a battleground it waits like a kill's letter, and lands once you are out (GK.InBattleground)
    if hold or GK.InBattleground() then Hold(data) else Landed(data) end
    GK.NoticeUpdate(not hold, silent)
    GK.Changed()
    return data
end

--- Unread letters: how many, and the first one's place in the pile. A held letter isn't news yet, and with
--- letters off none is. One that faded from the icon (FadeDue) is still unread: the letter window, the
--- ledger's Letters button and the arrows count it - "notification og slikt blir bare borte" (the owner,
--- 2026-11-18). GK.Waiting is the icon's count.
function GK.Unread()
    local n, first = 0, nil
    if GK.db.anyLetters == false then return 0, nil end
    for i, l in ipairs(GK.char.letters) do
        if not l.read and not holding[l] then
            n = n + 1
            first = first or i
        end
    end
    return n, first
end

--- What the letter icon waits with: the unread letters that have not faded from it. With letters off, none:
--- the notice shows only a warning then.
function GK.Waiting()
    local n, first = 0, nil
    if GK.db.anyLetters == false then return 0, nil end         -- letters off: the icon waits with none
    for i, l in ipairs(GK.char.letters) do
        if not l.read and not l.faded and not holding[l] then
            n = n + 1
            first = first or i
        end
    end
    return n, first
end

function GK.OrderLetter(o)
    local w = GK.Store().wanted[o.n]
    Add("order", { n = o.n, c = o.c, r = o.r, l = o.l, by = o.by, reward = o.reward, note = o.note, o = o.key,
        times = w and w.victims[o.by] or nil, auto = o.auto })
end

--- Your own kill that fulfilled it waits like a kill letter does.
--- So does one got with you there (GK.Helped): you were in that fight too.
function GK.CompleteLetter(o)
    local me = LIB.Me()
    local ours = o.doneBy == me or GK.Helped(o)
    Add("complete", { n = o.n, c = o.c, r = o.r, l = o.l, by = o.by, reward = o.reward, o = o.key,
        doneBy = o.doneBy, z = o.doneZone, pot = (GK.Pot(o)), share = o.pot and o.pot[me] or nil,
        helpers = o.helpers }, ours, ours)
end

-- A bounty paid to you has no letter since 2026-11-22: "bounty paid trengs vel ikke, de får jo mail?" (the owner) -
-- or a trade, which they see. One in the pile from before is still read as it was (FillLetter's "paid").

function GK.ExpiredLetter(o)
    Add("expired", { n = o.n, c = o.c, r = o.r, l = o.l, guid = o.guid, reward = o.reward, o = o.key })
end

-- A new title has no letter since 2026-11-22: its splash says it (Announce.lua). One in the pile from before is still
-- read as it was (FillLetter's "kill"), and the store pictures still draw one (Shots.lua).

--- autoOrder: this death posted a kill order on them (GK.AutoOrder), and the letter says so.
function GK.SlainLetter(v, times, zone, autoOrder)
    Add("slain", { n = v.key, guid = v.guid, c = v.c, r = v.r, l = v.l, times = times, z = zone, spell = v.spell,
        autoOrder = autoOrder or nil })
end

--- The test panel's What's new: a real letter's way in, for nobody's news (Debug.lua).
function GK.NewsForTest() return Add("news", { sample = true }, true) end

--- /grudge test: one of each, so the look can be judged without a fight. Marked as samples: their
--- buttons do nothing and they count for nothing.
function GK.SampleLetters()
    local me = LIB.Me() or "you"
    -- The enemies in the samples are from the other side, whichever side you're on.
    local horde = UnitFactionGroup("player") == "Horde"
    local ph = { n = "Pølse Hans", c = "ROGUE", r = horde and "Human" or "Orc", l = 35 }
    local function S(t)
        for k, v in pairs(ph) do if t[k] == nil then t[k] = v end end
        t.sample = true
        return t
    end
    Add("order", S({ by = "Edvard", reward = 2000, note = "Camps the flight master in Tarren Mill.", times = 24 }))
    Add("complete", S({ by = me, reward = 2000, doneBy = "Vebjørn", z = "Hillsbrad Foothills" }))
    Add("slain", S({ times = 24, z = "Hillsbrad Foothills", spell = "Ambush" }))
    Add("news", { sample = true })                 -- about no one: no enemy's class on it
    print(GK.TAG .. ": four sample letters are in your pile - click the letter icon to read them.")
end

-- What's new: one small letter after an update with something worth a word. Once per account, to the
-- first character in after it, and never on a first install, where nothing is new to anyone. Letters
-- off skips it as it skips every letter. "en bitteliten 'what's new' vindu som forklarer nye endringene
-- med assists og kalkuleringer" (the owner, 2026-11-12) - a letter, as all his news is, never a window
-- of its own. Someone who skipped a release gets each letter they missed, oldest first: 1.5.0's came the
-- same day as 1.4.0's (the owner, 2026-11-12: "må vel ha enda en what's new da"). The next one: its id at
-- the end of NEWS, and its words in NEWS_WORDS.
local NEWS = { "1.4.0", "1.5.0", "1.6.0", "1.7.0", "1.9.0", "1.12.0", "1.13.0", "1.14.0" }
local LATEST = NEWS[#NEWS]

-- Each letter in his voice: two short paragraphs with air between and no numbers, and a button to where
-- it is. The first draft gave rules with their numbers in one block and read as a manual: "nei, dette
-- synes jeg ikke er et bra brev" (the owner, 2026-11-12). The numbers are on the leaderboard's Points
-- heading (Window.lua). { title, paragraphs, seal, button, what the button does }
local NEWS_WORDS = {
    ["1.4.0"] = { "A word from the keeper", {
        "I've started writing down assists. Help a groupmate bring someone down, and part of the blood is yours.",
        "",
        "Avenging a fallen guildie pays when you come back for the killer - not in the fight where they fell.",
    }, "seal_red", "Leaderboard", function() GK.OpenWindow(2) end },
    ["1.5.0"] = { "Eyes on them", {
        "Put an enemy in your Death Note, and I'll tell you when they come near. You'll know them by the eye over their head.",
        "",
        "They wait in that book, and nobody else reads that page.",
    }, "seal_black", "Death Note", function() GK.OpenLedgerPage("Death Note") end },
    ["1.6.0"] = { "Blood in a row", {
        "String your kills together and I'll call it out - louder, the longer you last.",
        "",
        "My settings have pages of their own now: have it shouted, shown small, or not at all.",
    }, "seal_red", "Settings", function() GK.OpenOptions("Mine") end },
    -- The button goes to the tab's switch, not to the guild window: opening the game's window from an
    -- addon would run its opening as ours, and its roster asks the game for things only the game may ask.
    -- A first draft said what is on the page ("your week, the orders, the board"): "nja prøv annen tekst
    -- ... du kan se alle sine stats ved siden av guild chatten og se hvem som jobber og hvem som slacker
    -- ... se stats og skryte/mobbe andre samtidig" (the owner, 2026-11-13). So it says what the page is FOR.
    -- The jibe is his own, said to whoever reads it: a line telling the player what to ask a guildie was
    -- turned down ("jeg liker ikke at vi sier 'ask them this'", the owner, the same day).
    ["1.7.0"] = { "Who's slacking?", {
        "A tab on your guild window puts my ledger beside guild chat. Now everyone sees who's working, and who's slacking.",
        "",
        "Brag if you've earned it. And if all you do is die - maybe try killing someone, for a change.",
    }, "seal_black", "Settings", function() GK.OpenOptions("Buttons & tabs") end },
    -- 1.8.0 went out without one. 1.9.0's: the spree splashes and the longer title ladder, what a player
    -- hears and reaches for ("lage en liten 'what's new'?", the owner, 2026-11-18, who said ok to these words).
    ["1.9.0"] = { "Louder now", {
        "Every kill spree has a fanfare of its own now, and when you earn a new title, the whole guild hears it.",
        "",
        "I've added rungs to the ladder as well. The last ones are further off than they were - you'll have to earn them.",
    }, "seal_red", "Leaderboard", function() GK.OpenLedgerPage("Leaderboard") end },
    -- From 1.12.0 an update's letter opens its patch notes (GK.OpenPatchNotes, below) in place of a scroll: these
    -- words stand only where a scroll is drawn anyway (a picture of it, a test).
    ["1.12.0"] = { "Patch notes", {
        "A new version of Grudgekeeper is here, with a Death list of your own and a Mode for streaming.",
        "",
        "The patch notes say what is new.",
    }, "seal_red", "Patch notes", function() GK.OpenPatchNotes("1.12.0") end },
    ["1.13.0"] = { "Patch notes", {
        "A new version of Grudgekeeper is here: a quick setup for your settings, and the news you missed while away.",
        "",
        "The patch notes say what is new.",
    }, "seal_red", "Patch notes", function() GK.OpenPatchNotes("1.13.0") end },
    ["1.14.0"] = { "Patch notes", {
        "A new version of Grudgekeeper is here: your grudges across all your characters, and one Death Note for them if you like.",
        "",
        "The patch notes say what is new.",
    }, "seal_red", "Patch notes", function() GK.OpenPatchNotes("1.14.0") end },
}

--- The news letters not seen yet, oldest first: all of them when none was, those after the one seen last,
--- and none for an id we don't know (one from a newer Grudgekeeper, back on this one).
local function Unseen(seen)
    if seen == nil then return NEWS end
    for i = #NEWS, 1, -1 do
        if NEWS[i] == seen then
            local out = {}
            for j = i + 1, #NEWS do out[#out + 1] = NEWS[j] end
            return out
        end
    end
    return nil
end

function GK.DeliverNews(fresh)
    if fresh then GK.db.newsSeen = LATEST end
    if GK.db.newsSeen == LATEST then return end
    -- a moment after login, so it lands with the rest of the UI rather than under the loading screen
    C_Timer.After(5, function()
        local due = Unseen(GK.db.newsSeen)
        if not due then return end
        GK.db.newsSeen = LATEST
        for _, id in ipairs(due) do Add("news", { news = id }, true) end
    end)
end


-- ---------------------------------------------------------------------------
-- Patch notes: a window in the game's bronze frame, in the ledger's skin
-- ---------------------------------------------------------------------------
-- "isteden for parchment for nye endringer i addonen, lag en standard frame som følger stilen valgt i settings, med
-- bronze rammen osv fra spillet (samme som add to kill order) med fin punkliste osv og mer som vanlig patch notes ...
-- jeg vil ha Patch notes og noe mer forklarende under noen punkter om det trengs" (the owner, 2026-11-23). An update's
-- letter by the icon still says there is news; opening it opens these. /grudge news opens the latest.
-- { version, date, { { heading, { { lead, text, more } ... } } ... }, button }: more is the line under a point, when
-- it needs one; button, { words, what it does }, stands beside Close ("forholdsvis kort, og med en 'open settings'
-- knapp som kan sende de til settings", the owner, 2026-11-24).
local PATCH_NOTES = {
    ["1.12.0"] = { "23 November 2026", {
        { "New", {
            { "Death list", "Your own list of the enemies you want dead. Add them, and you are warned when they come near." },
            { "Mode", "Normal, Streamer or Private, under Settings.",
              "Streamer hides your guildies' notifications and never shares where you are." },
            { "Versus", "A tab under Grudges for the enemy guild your officers track." },
            { "Kudos medals", "On nameplates, one for each tag." },
        } },
        { "Changed", {
            { "Settings", "A full overhaul. It should make more sense now, and notifications and sounds are easier to turn on and off." },
            { "Kill orders", "Posting one is a single window: find them, set the bounty, seal it. Orders with no gold are quieter." },
            { "Grudges", "Replaces Most wanted. Marked is gone." },
            { "Kill streaks", "Grey and farmed kills no longer count." },
        } },
    } },
    -- the next version's, kept short (the owner, 2026-11-24); its number and date are the tag's to set
    ["1.13.0"] = { "25 November 2026", {
        { "New", {
            { "Quick setup", "The settings open on two choices: what you see and what you share. Every row can still be changed." },
            { "Catching up", "When you log in, the guildies online fill in the kills and deaths you missed, in the News and on Versus." },
            { "Right-click menu", "Turn each of Grudgekeeper's lines on or off, under Settings." },
            { "Death Note on every character", "Turn it on under Settings, Death Note, and your alts share the list." },
            { "Targeted", "A warning when someone in your Death Note targets you, out of a fight. Off to begin with, under Warnings." },
        } },
        { "Changed", {
            { "Death Note", "The Death list has a new name." },
        } },
    }, { "Open settings", function() GK.OpenOptions("Quick setup") end } },
    ["1.14.0"] = { "27 November 2026", {
        { "New", {
            { "All your characters", "Grudges, Killed me, has a box at the bottom left: this character, all of yours on this side, or one of them." },
            { "One Death Note", "With two characters on a side, a ? on the Death Note page offers to share one list." },
            { "Search the settings", "A search box beside the settings' title finds any setting." },
        } },
        { "Changed", {
            { "Guildies' sprees", "Their toasts burn like yours, with the count from 20." },
            { "AddOn list", "Grudgekeeper sits under PvP, and adds no YippYapp page to Options." },
        } },
    }, { "Open settings", function() GK.OpenOptions("Quick setup") end } },
}
local PATCH_LATEST = "1.14.0"
GK.PATCH_NOTES, GK.PATCH_LATEST = PATCH_NOTES, PATCH_LATEST       -- for tools/smoke_grudgekeeper.py

local NOTES_W, NOTES_H, NOTES_TEXT_W = 460, 520, 392      -- the notes scroll when they run past about 390
local notes

--- A colour of the skin's as a |c code, for a point's lead word in the line it opens.
local function Hex(c) return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
    math.floor(c[3] * 255 + 0.5)) end

local function BuildNotes()
    local f = GK.MakeFrameSheet("GrudgekeeperPatchNotes", NOTES_W, NOTES_H, "Grudgekeeper")
    f.head = f:CreateFontString(nil, "ARTWORK")
    f.head:SetPoint("TOPLEFT", 26, -34)
    f.sub = f:CreateFontString(nil, "ARTWORK")
    f.sub:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 1, -4)
    -- the notes scroll: the game's own bar where the client has it, else the wheel alone
    f.scroll = CreateFrame("ScrollFrame", nil, f)
    f.scroll:SetPoint("TOPLEFT", 24, -84)
    f.scroll:SetPoint("BOTTOMRIGHT", -34, 48)
    f.body = CreateFrame("Frame", nil, f.scroll)
    f.body:SetSize(NOTES_TEXT_W, 10)
    f.scroll:SetScrollChild(f.body)
    local barMade = false
    if ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar then
        local ok, bar = pcall(CreateFrame, "EventFrame", nil, f, "MinimalScrollBar")
        if ok and type(bar) == "table" then
            bar:SetPoint("TOPLEFT", f.scroll, "TOPRIGHT", 8, 0)
            bar:SetPoint("BOTTOMLEFT", f.scroll, "BOTTOMRIGHT", 8, 0)
            barMade = pcall(ScrollUtil.InitScrollFrameWithScrollBar, f.scroll, bar)
            if not barMade then bar:Hide() end
        end
    end
    if not barMade then
        f.scroll:EnableMouseWheel(true)
        f.scroll:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.max(0, math.min(range, (self:GetVerticalScroll() or 0) - delta * 40)))
        end)
    end
    f.lines = {}
    f.close = GK.FrameButton(f, "Close", 110, function() f:Hide() end)
    f.close:SetPoint("BOTTOMRIGHT", -16, 14)
    -- a version's way to what it is about (Open settings): the notes close, and there it opens
    f.go = GK.FrameButton(f, "", 130, function()
        local go = f.goFn
        f:Hide()
        if go then go() end
    end)
    f.go:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.go:Hide()
    notes = f
end

--- The next line of the notes' body, made once and kept: a font string in the skin's ink at size.
local function NotesLine(i, colour, font, size)
    local fs = notes.lines[i]
    if not fs then
        fs = notes.body:CreateFontString(nil, "ARTWORK")
        fs:SetJustifyH("LEFT")
        fs:SetSpacing(2)
        notes.lines[i] = fs
    end
    GK.Ink(fs, colour, font, size)
    fs:Show()
    return fs
end

--- Open the patch notes of a version (none: the latest). Drawn anew each time, in the skin of the moment.
function GK.OpenPatchNotes(version)
    local p = PATCH_NOTES[version or PATCH_LATEST] or PATCH_NOTES[PATCH_LATEST]
    if not notes then BuildNotes() end
    local f = notes
    GK.Ink(f.head, GK.INK, GK.TITLE_FONT, 24)
    f.head:SetText("Patch notes")
    GK.Ink(f.sub, GK.FADED, GK.TEXT_FONT, 11)
    f.sub:SetText(("Version %s \194\183 %s"):format(version or PATCH_LATEST, p[1]))
    local y, n = 0, 0
    local function Put(fs, x, gap)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", x, -y)
        fs:SetWidth(NOTES_TEXT_W - x)
        y = y + (fs:GetStringHeight() or 12) + gap
    end
    for si, section in ipairs(p[2]) do
        if si > 1 then y = y + 10 end
        n = n + 1
        local h = NotesLine(n, GK.BLOOD, GK.TITLE_FONT, 17)
        h:SetText(section[1])
        Put(h, 0, 6)
        for _, point in ipairs(section[2]) do
            n = n + 1
            local fs = NotesLine(n, GK.INK, GK.TEXT_FONT, 12)
            fs:SetText(("\226\128\162  %s%s|r - %s"):format(Hex(GK.BLOOD), point[1], point[2]))
            Put(fs, 4, point[3] and 3 or 7)
            if point[3] then
                n = n + 1
                local more = NotesLine(n, GK.FADED, GK.TEXT_FONT, 11)
                more:SetText(point[3])
                Put(more, 18, 7)
            end
        end
    end
    for i = n + 1, #f.lines do f.lines[i]:Hide() end
    local go = p[3]
    f.goFn = go and go[2] or nil
    if go then f.go:SetText(go[1]) end
    f.go:SetShown(go ~= nil)
    f.body:SetHeight(math.max(10, y))
    f.scroll:SetVerticalScroll(0)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    f:Show()
    f:Raise()
    return f
end

-- ---------------------------------------------------------------------------
-- What a letter says
-- ---------------------------------------------------------------------------
local function Ordinal(n)
    local tens = n % 100
    if tens >= 11 and tens <= 13 then return n .. "th" end
    local last = n % 10
    return n .. ((last == 1 and "st") or (last == 2 and "nd") or (last == 3 and "rd") or "th")
end

local function Ago(t)
    local s = time() - (t or 0)
    if s < 90 then return "just now" end
    if s < 3600 then return math.floor(s / 60) .. " min ago" end
    if s < 2 * GK.DAY then return math.floor(s / 3600) .. " h ago" end
    return math.floor(s / GK.DAY) .. " days ago"
end
GK.Ago = Ago

local function Order(L)
    return L.o and GK.Store().orders[L.o] or nil
end


-- The Grudgekeeper's last word, picked by the letter's number so a letter always says the same thing.
local CLOSING = {
    kill = { "That's how a grudge is kept.", "They'll remember your name.", "Keep them coming." },
    slain = { "Some debts are paid in blood.", "I've written it down. I always do.", "Rise, and remember." },
    paid = { "A debt settled. The book balances." },
    expired = { "Grudges keep. Orders don't.", "Post it again, if the grudge still burns." },
}

-- The small letters are the Grudgekeeper talking to you - the old keeper of the guild's book of grudges,
-- who signs every one - not a receipt: "mer roleplay" and "det skal liksom være en som prater til deg"
-- (the owner, 2026-11-10). Slogans set apart from the news ("You have the scent now") read like nobody
-- talks: he says what happened, what it means, and adds a word of his own. A new title is greeted by name,
-- and what he says last goes with the title; it stands where the closing line would, as the letter has
-- room for four or five lines.
local TITLE_REMARKS = {
    Cutthroat = "Not a bad start.",
    Bloodhound = "Keep hunting.",
    Headhunter = "The others have started to notice you.",
    Slayer = "I hear the enemy whispers your name now.",
    Executioner = "Not many in this guild have come this far.",
    Oathsworn = "You've sworn yourself to the grudge now. There's no taking it back.",
    Avenger = "Our dead rest easier with you out there.",
    Reckoner = "You settle the accounts faster than I can write them.",
    Nemesis = "Somewhere out there, someone checks the map for you before they log in.",
    Grudgebearer = "I'm running out of pages for you, you know.",
    ["Dread Reaper"] = "There's no higher name in my book. Wear it well.",
}

--- The scroll: title, name, info, body (lines), foot, seal, stamp, buttons { { text, fn } }
local function ScrollContent(L)
    local me, show = LIB.Me(), GK.Show
    local info = GK.Describe(L.l, L.c, L.r)
    local body, buttons = {}, {}
    local o = Order(L)
    -- The way to the ledger and the way out are the bar under the scroll (BuildScroll), for every scroll;
    -- the buttons here are only what this one asks of you.
    if L.kind == "order" then
        -- An order that posted itself carries the Grudgekeeper's reason, not the poster's words.
        if L.note then body[#body + 1] = L.auto and L.note or ('"' .. L.note .. '"') end
        -- the lines that give way when the sheet has no room for all, the least needed first (FitBody): the
        -- scroll ran on under its button, its seal and its bottom roll (the store pictures, 2026-11-10)
        local killed, seen, backed, sight
        if L.times then
            killed = ("Has killed %s %s."):format(show(L.by), L.times == 1 and "once" or (L.times .. " times"))
            body[#body + 1] = killed
        end
        if o and o.seen then
            seen = ("Last seen in %s, %s."):format(o.seen.z or "the world", Ago(o.seen.t))
            body[#body + 1] = seen
        end
        body[#body + 1] = " "
        -- the pot as it stands now, if we still have the order; as posted otherwise. The gold stands under the
        -- face (bounty; "No bounty" there when there is none); the body says who put it in.
        local pot, backers = L.reward or 0, 0
        if o then pot, backers = GK.Pot(o) end
        if pot > 0 and backers > 0 and o then
            -- who chipped in, the biggest share first: the poster's own reward leads
            local shares = {}
            if (o.reward or 0) > 0 then shares[1] = { who = o.by, copper = o.reward } end
            for who, copper in pairs(o.pot) do shares[#shares + 1] = { who = who, copper = copper } end
            table.sort(shares, function(a, b) return a.copper > b.copper end)
            local names = {}
            for i = 1, math.min(3, #shares) do
                names[i] = ("%s %s"):format(show(shares[i].who), GK.MoneyText(shares[i].copper))
            end
            local more = #shares - #names
            backed = "In the pot: " .. table.concat(names, ", ") .. (more > 0 and (" and %d more"):format(more) or "")
            body[#body + 1] = backed
        end
        -- how many put gold in: the poster's reward and each backer
        local bounty = { copper = pot, from = o and (backers + ((o.reward or 0) > 0 and 1 or 0)) or nil }
        if o and o.state ~= "o" then body[#body + 1] = "(This order is closed.)" end
        -- Nothing to take or accept: the order is the whole message - "hey, we put out an order, kill this
        -- one" (the owner, 2026-11-07). Any guildie's kill fulfils it.
        if o and o.state == "o" then
            sight = pot > 0 and "Wanted for crimes against the guild. Whoever ends them collects."
                or "Wanted for crimes against the guild."
            body[#body + 1] = sight
        end
        if o and o.state == "o" and o.by ~= me then
            buttons[#buttons + 1] = { "Add to the pot", function() GK.OpenPost({ key = o.n, guid = o.guid, c = o.c,
                r = o.r, l = o.l }) end }
        end
        -- short: the foot shares its line with the seal on a 300-wide sheet
        local foot = L.auto and ("Posted by %s's death"):format(show(L.by)) or ("Posted by " .. show(L.by))
        local give = {}
        for _, t in ipairs({ sight or false, " ", backed or false, seen or false, killed or false }) do
            if t then give[#give + 1] = t end
        end
        return "KILL ORDER", show(L.n), info, body, foot, "seal_red", nil, buttons, give, bounty
    end
    -- complete
    local doneBy = L.doneBy and show(L.doneBy) or "Someone"
    local where = L.z and (" in " .. L.z) or ""
    local pot = L.pot or L.reward or 0
    local owe = (L.by == me and (L.reward or 0)) or L.share or 0     -- what I promised: reward or share
    -- who else was there: the group members near the killing blow (GroupHelpers, Guild.lua) - "det stod ikke
    -- noe om at han hadde vært med" (the owner, 2026-11-09)
    local others = {}
    for _, k in ipairs(L.helpers or {}) do
        if not LIB.IsMyStoredName(k) then others[#others + 1] = k end
    end
    local helped = L.doneBy ~= me and GK.Helped(L)
    -- "you and Kari", "you, Kari and Lars": you first, then everyone else who was there
    local function YouAnd(keys)
        local names = { "you" }
        for _, k in ipairs(keys) do names[#names + 1] = show(k) end
        return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
    end
    -- what we have coming: our part of everyone else's gold, the bounty shared among all who got them
    -- (GK.Part, Guild.lua); the letter's own pot when the order is gone
    local shared = o and #GK.Hunters(o) > 1
    local due = o and GK.DueTo(o, me) or nil
    local function Coming(copper)
        if copper <= 0 then return end
        if shared then
            body[#body + 1] = ("Your part: %s of %s, to come by mail."):format(GK.MoneyText(copper), GK.MoneyText(pot))
        else
            body[#body + 1] = ("%s in all, to come by mail."):format(GK.MoneyText(copper))
        end
    end
    if L.doneBy == me and L.by == me then
        -- your own order: nobody mails you your own reward, only its backers their shares
        if #others > 0 then
            body[#body + 1] = ("Your own order - %s got them%s."):format(YouAnd(others), where)
        else
            body[#body + 1] = "Your own order - you got them yourself" .. where .. "."
        end
        local backed = due or (pot - (L.reward or 0))
        if backed > 0 then body[#body + 1] = ("%s from its backers, to come by mail."):format(GK.MoneyText(backed)) end
    elseif L.doneBy == me then
        body[#body + 1] = "You collected the bounty" .. (#others > 0 and (" with " .. GK.NameList(others)) or "")
            .. where .. "."
        Coming(due or pot)
    elseif helped then
        -- you were there: it is yours too, and yours to tell
        local all = { L.doneBy }
        for _, k in ipairs(others) do all[#all + 1] = k end
        local together = YouAnd(all)
        body[#body + 1] = ("%s got them%s. %s had the killing blow."):format(together:sub(1, 1):upper()
            .. together:sub(2), where, doneBy)
        if L.by ~= me then Coming(due or 0) end
    end
    -- One line in guild chat for the guildies without Grudgekeeper - only ever from this click, or the
    -- order's card in the ledger (GK.TellOrder).
    if not L.sample and GK.CanTellOrder(o, L) then
        buttons[#buttons + 1] = { "Tell the guild", function() GK.TellOrder(o, L) end }
    end
    if L.doneBy ~= me and not helped then
        body[#body + 1] = (L.helpers and GK.WhoGotThem(L.doneBy, L.helpers) or doneBy)
            .. (L.by == me and " collected the bounty" or " got there first") .. where .. "."
    end
    -- what we owe on it: a part to each hunter (GK.Owed); as the letter has it when the order is gone
    local debts = {}
    if o then
        for _, e in ipairs(GK.Owed()) do
            if e.o == o then debts[#debts + 1] = ("%s %s"):format(show(e.to), GK.MoneyText(e.share)) end
        end
    end
    if #debts > 0 then
        body[#body + 1] = " "
        body[#body + 1] = ("You owe %s - mail or trade it, and it is marked paid by itself."):format(#debts == 1
            and debts[1] or (table.concat(debts, ", ", 1, #debts - 1) .. " and " .. debts[#debts]))
        buttons[#buttons + 1] = { "Mark as paid", function() GK.PayShare(o) end }
    elseif not o and L.doneBy ~= me and not helped and owe > 0 then
        body[#body + 1] = " "
        body[#body + 1] = ("You owe them %s - mail or trade it to them, and it is marked paid by itself."):format(
            GK.MoneyText(owe))
    end
    -- the order's seal, broken: it has been opened and carried out
    return "ORDER COMPLETE", show(L.n) .. " is dead", info, body, "Posted by " .. show(L.by), "seal_broken",
        "stamp_fulfilled", buttons, nil, { copper = pot }
end

--- The note: title, paragraphs, seal, blood, the action button { text, fn } or nil
local function NoteContent(L)
    local show = GK.Show
    local p = {}
    local action
    local function PostOn() GK.OpenPost({ key = L.n, guid = L.guid, c = L.c, r = L.r, l = L.l }) end
    local closing = CLOSING[L.kind]
    if L.kind == "news" then
        -- What's new (GK.DeliverNews, NEWS_WORDS); a sample has no id and says the latest
        local w = NEWS_WORDS[L.news] or NEWS_WORDS[LATEST]
        for i, line in ipairs(w[2]) do p[i] = line end
        return w[1], p, nil, w[3], false, { w[4], w[5] }
    end
    if L.kind == "kill" then
        -- A kill gets a letter only for a new title (Kills.lua), and it says three things: the title, the kill
        -- that got it, where you stand. Seven lines - the kill, its points, a streak, "and 1 more", the total
        -- and the title - ran into the seal ("kanskje ikke så mye text?", the owner, 2026-11-07). A letter
        -- from before then, with no title, says the kill and where you stand.
        -- "So, Gærd Balle is dead - in Hillsbrad Foothills, I hear." What he heard, and where
        p[1] = ("So, %s is dead%s."):format(show(L.n), L.z and (" - in " .. L.z .. ", I hear") or "")
        local stand = (L.of or 0) > 1 and ("That makes you %s of %d in the guild, with %d points."):format(
            Ordinal(L.rank or 0), L.of, L.total or 0) or ("You have %d points."):format(L.total or 0)
        if L.title then
            p[1] = p[1] .. (" From today I'm writing you down as %s."):format(L.title)
            stand = stand .. (TITLE_REMARKS[L.title] and (" " .. TITLE_REMARKS[L.title]) or "")
            closing = nil                                -- what he says last goes with the title
        end
        p[#p + 1] = stand
        action = { "Leaderboard", function() GK.OpenWindow(2) end }
        return L.title and ("Rise, " .. L.title) or "Blood drawn", p, closing, "seal_red", false, action
    elseif L.kind == "slain" then
        -- the name alone: the portrait and its badge say what they are, and "Gærd Balle, a level 27 Troll
        -- Hunter, got you" is not how anyone says it
        p[#p + 1] = ("%s got you%s%s."):format(show(L.n), L.spell and (" with " .. L.spell) or "",
            L.z and (" in " .. L.z) or "")
        if L.times then
            -- "my book": the ledger is his; "started a page on them" needed explaining (the owner, 2026-11-10)
            p[#p + 1] = L.times == 1 and "First time - I've written their name in my book. Don't forget it."
                or ("That's the %s time they've got you. I've written it down."):format(Ordinal(L.times))
        end
        if L.autoOrder then
            -- posted in your name by this very death: say so - its Kill orders button is the way to it, the
            -- sentence that said so read as a manual ("den setningen liker jeg ikke", the owner, 2026-11-10)
            -- Short, and no closing line after it: this is the longest of the small letters, and at eight
            -- lines its last one met the seal and signature (the preview of 2026-11-04).
            -- The button is named as the ledger's tab it opens; it was "Hitlist", the tab's name long ago.
            p[#p + 1] = "I've told the guild. There's a kill order out on them now, in your name."
            closing = nil
            action = { "Kill orders", function() GK.OpenWindow(1) end }
        elseif GK.OrderOn(L.n, L.guid) then
            p[#p + 1] = "There's a price on their head already. Someone will collect."
            closing = nil                                -- three lines of his: no room for a fourth
            action = { "Kill orders", function() GK.OpenWindow(1) end }
        else
            action = { "Put a price on them", PostOn }
        end
        return "Slain", p, closing, "seal_black", true, action
    elseif L.kind == "paid" then
        p[#p + 1] = ("%s paid up: %s for the head of %s. It's waiting in your mail."):format(
            show(L.by), GK.MoneyText(L.reward), show(L.n))
        action = { "Kill orders", function() GK.OpenWindow(1) end }
        return "Bounty paid", p, closing, "seal_red", false, action
    end
    -- expired
    -- how long it ran is left out: one your death posted runs three days, not a week (Guild.lua, AUTO_DAYS)
    p[#p + 1] = ("Your kill order on %s has run out, and they're still walking around."):format(show(L.n))
    action = { "Post it again", PostOn }
    return "Order expired", p, closing, "seal_black", false, action
end

--- What a letter says, apart from how it is drawn (FillLetter draws from it):
--- { note (the Grudgekeeper's, else an order's page), title, name, info, lines, foot, seal, stamp, blood,
--- buttons = { { text, fn } }, bounty = { copper, from }, c, rf, sx, key, sample, give }. name, info, foot,
--- stamp and bounty are an order's only. give lists lines of the body in the order they give way when the
--- page has no room for all (FitBody). buttons are only what the letter asks of you: the way to the order in
--- the ledger is the window's own (FillLetter).
function GK.LetterContent(L)
    local d = { c = L.c, rf = L.rf, sx = L.sx, key = L.n, sample = L.sample }
    if not NOTE[L.kind] then
        local title, name, info, body, foot, seal, stamp, buttons, give, bounty = ScrollContent(L)
        d.title, d.name, d.info, d.lines, d.foot, d.seal, d.stamp, d.buttons = title, name, info, body, foot, seal,
            stamp, buttons
        d.give, d.bounty = give, bounty
        return d
    end
    local title, paragraphs, closing, seal, blood, action = NoteContent(L)
    local lines = {}
    for i, text in ipairs(paragraphs) do lines[i] = text end
    -- The closing line only on a short letter: a long one (a death that posted a kill order) would push it
    -- into the seal and the signature.
    if closing and #paragraphs <= 4 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = closing[(L.id or 1) % #closing + 1]
        d.give = { lines[#lines] }                  -- his last word gives way first on a page with no room
    end
    d.note, d.title, d.lines, d.seal, d.blood, d.buttons = true, title, lines, seal, blood, { action }
    return d
end

-- ---------------------------------------------------------------------------
-- The letter: one window for every letter, a loose sheet of burnt parchment
-- ---------------------------------------------------------------------------
-- Kill orders were a scroll and the rest a note, each its own window, and only the note had arrows: from a
-- note the arrow could open a kill order's scroll, which had none, and the rest of the pile was out of
-- reach ("når det er flere letters på en gang og det er kill orders og notification letters om hverandre
-- så funker det dårlig", the owner, 2026-11-18). Now one window holds them all, in one place, with the pile
-- at its foot. It was the note's iron frame until the same evening - "letter vinduet er også blitt ganske
-- stort" - and of the two smaller looks then compared in the game (art/mockups/letters, round 2) the owner
-- chose the loose sheet: "ordne kill order så det viser parchment osv? ikke de store bulkete rammene ...
-- ja. P" (2026-11-18). B, the scroll for every letter, waits in BACKLOG.md.
local win                          -- the letter window, made on first use
-- Where its parts stand. w, h: its width and least height; maxH its most - it grows to its words. face: the
-- portrait's side; faceX, faceY its top left. The title stands beside the face, the words under both from
-- textX. right: the margin on the right. headY: an order's title's top. title, name: their type's size on an
-- order (titleLong for a long one); note, noteLong: a note's title, which has nothing under it. signY,
-- ruleY, footY: the signature's line, the faint rule, and Read all and Close, up from the foot; sealRoom:
-- what the writing keeps clear over the signature. edge: Read all, Close and the signature this far in from
-- the sides. pileY: the pile's row, up from the foot, over Read all and Close. pile: dots in it at most.
-- blood: x, y and size of a death's. 380 wide, the foot was one row - Read all, the pile, its count and Close
-- all on it - and they ran into each other: "de er litt små fordi du ser ting overlapper nederst" (the
-- owner, 2026-11-18). Wider, and the pile a row of its own. The titles were 18, small beside the portrait
-- with room under them: "gjør header på kortene (spesielt de som ikke har sub headers osv større?) ser dumt
-- ut når det er stort mellomrom og liten skrift" (the owner, the same day). On an order the name was small and
-- the level, race and class a faint line under it: "navnet på spilleren er for lite. og med icon + class icon
-- så trenger vi ikke extra text 'undead rogue' og lvl 33 kan flyttes til høyre side og gjøres større ... og
-- reward kan også gjøres større" (the owner, 2026-11-19). The name 16 to 21, the level a number on the right
-- (levelW wide), the bounty 11 to 14; race and class are the face and the crest on its shoulder. Then: "forsatt
-- vanskelig å se navnet. er det litt lite luft og kanskje pga fonten? ... level i hjørnet også er litt tynn og
-- vanskelig å se ... kanskje litt langt ut i hjørnet" (2026-11-20). The name in the plain text font, not the
-- title's thin capitals, at 19, with nameGap over it and bountyGap under it; the level in the same plain font,
-- dark, levelIn further in from the right margin and down by the face's middle (levelY).
local LAYOUT = { w = 440, h = 300, maxH = 540, face = 60, faceX = 30, faceY = 34, textX = 30, right = 30, headY = 32,
    title = 22, titleLong = 18, note = 28, noteLong = 22, name = 19, level = 26, levelW = 72, levelIn = 16,
    levelY = 45, nameGap = 8, bountyGap = 6, bounty = 14, signY = 100, sealRoom = 30, ruleY = 90, footY = 28, pileY = 62, edge = 28, pile = 9, blood = { 120, -40, 160 } }
local BUTTON_GAP = 12              -- between the words and the letter's buttons

--- The letters closed - by Close or Escape: the read ones go. A moment later, so a letter's own button
--- that opens something else (the order in the ledger) has run first.
local function Closed()
    C_Timer.After(0, function()
        if win and win:IsShown() then return end
        reading, index = false, nil
        Prune()
        GK.NoticeUpdate(false)
        GK.Changed()
        if not fadePending then FadeDue() end      -- what waited while they were open may fade now
    end)
end

local function Ink(fs, colour, font, size)
    GK.SetFont(fs, font, size)                   -- a family: names in Cyrillic too (Core.lua)
    fs:SetTextColor(colour[1], colour[2], colour[3])
    fs:SetShadowOffset(0, 0)
end

--- A button on the letter: the skin's own (GK.MakeButton, Core.lua). It was ink on the paper, a word in a
--- thin ruled box, until "når de er basically bare border så ser det så flatt og dårlig ut" (the owner,
--- 2026-11-18). b:Set(text) sizes it to its word; b.w is its width.
local LETTER_BUTTON_H = 24
local function LetterButton(parent)
    local b = GK.MakeButton(parent, 90, LETTER_BUTTON_H)
    function b:Set(text)
        self:SetText(text)
        self.w = math.max(90, math.ceil(self:GetTextWidth() or 60) + 40)
        self:SetWidth(self.w)
    end
    return b
end

--- Can it be pressed: a sample letter's buttons do nothing (GK.SampleLetters), and look it.
local function Pressable(b, on)
    b:SetEnabled(on)
    b:SetAlpha(on and 1 or 0.45)
end

--- The pile at the letter's foot, a row of its own over Read all and Close: a dot for each letter - the open
--- one larger in a bronze ring, the unread in blood, the read faint - an arrow either side, and on the
--- buttons' row between them where you are and how many more wait. A dot clicked opens its letter; a long
--- pile shows the nearest around the open one. They were the letters' wax seals, a row of little stamps
--- that ran into Read all and Close: "pass på at nederste carousel ikonene osv ikke overlapper. kanskje
--- heller ikke ha stamps på de for det ser litt out of place ut" (the owner, 2026-11-18).
local DOT, DOT_OPEN, DOT_GAP = 9, 12, 8
local function BuildPile(f)
    local L = f.layout
    local p = CreateFrame("Frame", nil, f)
    p:SetSize(200, 20)
    p:SetPoint("BOTTOM", f, "BOTTOM", 0, L.pileY)
    p.seals = {}
    p.shown = L.pile
    for i = 1, p.shown do
        local s = CreateFrame("Button", nil, p)
        s:SetHitRectInsets(-4, -4, -6, -6)          -- a dot is small: a little more to hit than to see
        s.tex = s:CreateTexture(nil, "ARTWORK")
        s.tex:SetAllPoints()
        local mask = s:CreateMaskTexture()
        mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(s.tex)
        s.tex:AddMaskTexture(mask)
        s.ring = s:CreateTexture(nil, "OVERLAY")
        s.ring:SetTexture(MEDIA .. "portrait_ring")
        s.ring:SetSize(DOT_OPEN + 8, DOT_OPEN + 8)
        s.ring:SetPoint("CENTER")
        s:SetScript("OnClick", function(self) GK.ShowLetter(self.at) end)
        s:SetScript("OnEnter", function(self)
            local L = GK.char.letters[self.at]
            if not L then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(GK.LetterLine and GK.LetterLine(L) or "", 1, 1, 1)
            GameTooltip:Show()
        end)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p.seals[i] = s
    end
    -- the spellbook's page arrows, as the ledger turns its lists (Window.lua)
    local function Arrow(kind, dir)
        local b = CreateFrame("Button", nil, p)
        b:SetSize(20, 20)
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Down")
        b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Disabled")
        b:SetScript("OnClick", function() GK.ShowLetter(index + dir) end)
        return b
    end
    p.prev = Arrow("Prev", -1)
    p.prev:SetPoint("RIGHT", p, "LEFT", -8, 0)
    p.next = Arrow("Next", 1)
    p.next:SetPoint("LEFT", p, "RIGHT", 8, 0)
    -- where you are, on the buttons' row in the middle, between Read all and Close
    p.text = f:CreateFontString(nil, "ARTWORK")
    Ink(p.text, FADED, TEXT_FONT, 11)
    p.text:SetPoint("CENTER", f, "BOTTOM", 0, L.footY + LETTER_BUTTON_H / 2)
    return p
end

--- The pile drawn for the letter open now. Returns how many other letters are unread.
local function UpdatePile(p)
    local list = GK.char.letters
    local n = #list
    local first = 1
    local shown = p.shown
    if n > shown then first = math.max(1, math.min(index - math.floor(shown / 2), n - shown + 1)) end
    local x = 0
    for i, s in ipairs(p.seals) do
        local at = first + i - 1
        local L = list[at]
        s:SetShown(L ~= nil)
        if L then
            local open, read = at == index, L.read and at ~= index
            local size = open and DOT_OPEN or DOT
            local c = read and INK or BLOOD
            s.at = at
            s:SetSize(size, size)
            s:ClearAllPoints()
            s:SetPoint("LEFT", p, "LEFT", x, 0)
            s.tex:SetColorTexture(c[1], c[2], c[3], 1)
            s.tex:SetAlpha(read and 0.45 or 1)
            s.ring:SetShown(open)
            x = x + size + DOT_GAP
        end
    end
    p:SetWidth(math.max(1, x - DOT_GAP))
    Pressable(p.prev, index > 1)
    Pressable(p.next, index < n)
    local more = 0
    for i, L in ipairs(list) do
        if i ~= index and not L.read and not holding[L] then more = more + 1 end
    end
    p.text:SetText(more > 0 and ("%d of %d, %d more unread"):format(index, n, more) or ("%d of %d"):format(index, n))
    return more
end

--- The body, as much of it as the room between the head and the buttons holds: a long note, three backers
--- and where they were last seen ran a kill order on under its buttons and its seal (the store pictures,
--- 2026-11-10). What gives way goes first - give, then a blank line - and what still runs on is cut at the
--- last line that fits.
local LINE_H = 16                 -- a line of the body: 13 high, and 3 between lines
local function FitBody(fs, lines, give, room)
    local kept = {}
    for i, t in ipairs(lines) do kept[i] = t end
    if fs.SetMaxLines then fs:SetMaxLines(0) end
    fs:SetText(table.concat(kept, "\n"))
    local order = {}
    for _, t in ipairs(give or {}) do order[#order + 1] = t end
    order[#order + 1] = " "
    order[#order + 1] = ""
    for _, t in ipairs(order) do
        if (fs:GetStringHeight() or 0) <= room then break end
        for i = #kept, 1, -1 do
            if kept[i] == t then
                table.remove(kept, i)
                break
            end
        end
        fs:SetText(table.concat(kept, "\n"))
    end
    if (fs:GetStringHeight() or 0) > room and fs.SetMaxLines then
        fs:SetMaxLines(math.max(1, math.floor((room + 3) / LINE_H)))
    end
end

-- ---------------------------------------------------------------------------
-- Close buttons, portraits and the sheets: shared with the ledger, the post sheet and the notes
-- ---------------------------------------------------------------------------
--- Grudgekeeper's own close button: the iron X (Media/close), a red glow behind it under the mouse,
--- a shade darker pressed. Every close path is our own Hide, so it works in combat too. size: the
--- button's side (what a click can hit); art: the cross's own side, smaller, so it sits inside a
--- socket rather than over its rim (the preview of 2026-11-04 had it filling the hole). b.cross and
-- b.glow are kept, for a caller whose socket changes size (the ledger, open and folded).
function GK.MakeCloseButton(parent, size, onClick, art)
    art = art or size
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local glow = b:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(MEDIA .. "glow")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.2, 0.1)
    glow:SetSize(art * 1.8, art * 1.8)
    glow:SetPoint("CENTER")
    glow:Hide()
    local x = b:CreateTexture(nil, "ARTWORK")
    x:SetTexture(MEDIA .. "close")
    x:SetSize(art, art)
    x:SetPoint("CENTER")
    b:SetScript("OnEnter", function() glow:Show() end)
    b:SetScript("OnLeave", function() glow:Hide() x:SetVertexColor(1, 1, 1) end)
    b:SetScript("OnMouseDown", function() x:SetVertexColor(0.7, 0.7, 0.7) end)
    b:SetScript("OnMouseUp", function() x:SetVertexColor(1, 1, 1) end)
    b:SetScript("OnClick", onClick)
    b.cross, b.glow = x, glow
    return b
end

-- The client's race portraits (raceicon128-<race>-<sex>, in Forever's atlas data) by the race's file
-- token; Undead is "Scourge" to the client and "undead" to the atlas.
local RACE_ATLAS = { Scourge = "undead" }

-- The old character-creation sheet (file 131152, in the live build's manifest, 70888): 8 columns by 4
-- rows, the male faces in rows 0 and 1 and the female ones two rows lower (dakristia's PR,
-- vBaustad/Grudgekeeper#2, 2026-11-11). A race added after the sheet was made is not on it and keeps
-- today's icon.
local RACE_SHEET = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races"
local RACE_TILES = {
    Human = { 0, 0 }, Dwarf = { 1, 0 }, Gnome = { 2, 0 }, NightElf = { 3, 0 },
    Draenei = { 4, 0 }, Worgen = { 5, 0 }, Pandaren = { 6, 0 },
    Tauren = { 0, 1 }, Scourge = { 1, 1 }, Troll = { 2, 1 }, Orc = { 3, 1 },
    BloodElf = { 4, 1 }, Goblin = { 5, 1 },
}

--- A race's tile on the sheet, 8% in on every side so the tile's own frame stays outside the round
--- mask: left, right, top, bottom.
local function SheetCoords(rf, sx)
    local col, row = RACE_TILES[rf][1], RACE_TILES[rf][2] + (sx == 3 and 2 or 0)
    local w, h = 1 / 8, 1 / 4
    return col * w + w * 0.08, (col + 1) * w - w * 0.08, row * h + h * 0.08, (row + 1) * h - h * 0.08
end

--- Dress a portrait texture for a player: their race's face when we know race and sex, else their
--- class crest, else the Grudgekeeper's red seal. info = { rf (race file token), sx (2 male, 3
--- female), c (class) }. Returns "race", "class" or "seal", so the caller knows whether the class
--- still needs showing (as a badge) beside a face. With "Old race portraits" on, a race the old sheet
--- has gets its face from there.
function GK.SetPortrait(tex, info)
    info = info or {}
    local rf, sx = info.rf, info.sx
    if GK.db and GK.db.oldPortraits and type(rf) == "string" and (sx == 2 or sx == 3) and RACE_TILES[rf] then
        tex:SetTexture(RACE_SHEET)
        tex:SetTexCoord(SheetCoords(rf, sx))
        return "race"
    end
    if type(rf) == "string" and (sx == 2 or sx == 3) and tex.SetAtlas then
        local atlas = ("raceicon128-%s-%s"):format(RACE_ATLAS[rf] or rf:lower(), sx == 3 and "female" or "male")
        local known = not (C_Texture and C_Texture.GetAtlasInfo) or C_Texture.GetAtlasInfo(atlas)
        if known and pcall(tex.SetAtlas, tex, atlas) then
            tex:SetTexCoord(0, 1, 0, 1)
            return "race"
        end
    end
    local coords = info.c and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[info.c]
    if coords then
        tex:SetTexture(CLASS_ICONS)
        tex:SetTexCoord(unpack(coords))
        return "class"
    end
    tex:SetTexture(MEDIA .. "mark")
    tex:SetTexCoord(0, 1, 0, 1)
    return "seal"
end

-- A player's own face is not shown at all, only their race's (race and sex) with their class on its
-- shoulder. The game draws a real face only from a unit and nothing reads it back, so a real one lasted
-- only while the session did and only for those you had targeted: the same player's picture switched
-- between the two ("dropp personal ikon ... så flipper ikke bildet hele tida", the owner, 2026-11-07).

--- A round portrait in the bronze ring, for the ledger's rows and the sheets' heads alike. p:Set(face)
--- dresses it (GK.SetPortrait), with a class crest on its shoulder beside a race's face. With
--- face.key and no race and sex of its own, what we kept of that player fills them in (GK.FaceOf).
function GK.MakePortrait(parent, size)
    local p = { parent = parent }
    p.tex = parent:CreateTexture(nil, "ARTWORK")
    -- The ring's hole is 0.80 of it across and its band runs out to the edge (portrait_ring, measured
    -- 2026-11-06). At 0.82 the face's masked circle - the game's mask has a soft edge - came out smaller
    -- than the hole, and the page showed between face and ring ("glippe mellom ikonet og ramma", the
    -- owner). At 0.92 the face's edge is under the band.
    p.tex:SetSize(size * 0.92, size * 0.92)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(p.tex)
    p.tex:AddMaskTexture(mask)
    p.ring = parent:CreateTexture(nil, "OVERLAY")
    p.ring:SetTexture(MEDIA .. "portrait_ring")
    -- the bronze dulled a little: polished, it was "litt shiny" beside the page (the owner, 2026-11-06)
    p.ring:SetDesaturation(0.35)
    p.ring:SetVertexColor(0.8, 0.74, 0.68)
    p.ring:SetSize(size, size)
    p.ring:SetPoint("CENTER", p.tex, "CENTER")
    -- No dark rim behind the ring: one was tried for contrast and read as a brown halo ("ser litt rart
    -- ut", 2026-11-05).
    p.badge = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    p.badge:SetSize(size * 0.42, size * 0.42)
    p.badge:SetPoint("CENTER", p.tex, "BOTTOMRIGHT", -size * 0.11, size * 0.11)   -- where it sat at 0.82
    function p:Set(face)
        face = face or {}
        local key = face.faceKey or face.key
        if key and not (face.rf and face.sx) and GK.FaceOf then face = GK.FaceOf(key, face.c) end
        self.kind = GK.SetPortrait(self.tex, face)
        self.tex:Show()
        -- the class crest on the shoulder of a race's face, never beside the crest itself
        local coords = self.kind == "race" and face.c and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[face.c]
        self.badge:SetShown(coords and true or false)
        if coords then
            self.badge:SetTexture(CLASS_ICONS)
            self.badge:SetTexCoord(unpack(coords))
        end
    end
    function p:SetShown(on)
        self.tex:SetShown(on)
        self.ring:SetShown(on)
        if not on then self.badge:Hide() end
    end
    return p
end

-- ---------------------------------------------------------------------------
-- The sheets: the kill order, the note and the who-picker share one look, ink on the parchment and
-- nothing of the game's own kit. A face in the bronze ring at the head, each part named in small
-- capitals over a thin rule, lines to write on, and the red wax seal as the button that sends it.
-- The game's dark input boxes and red buttons on our paper read as "en intern har lagd" (the owner,
-- 2026-11-06); the look was previewed with the addon's own art before it was built.
-- ---------------------------------------------------------------------------
local function SheetInk(fs, colour, font, size)
    GK.SetFont(fs, font, size)
    fs:SetTextColor(colour[1], colour[2], colour[3])
    fs:SetShadowOffset(0, 0)
end

-- Every sheet made, the scroll and the framed ones alike. One opened on the ledger lies on it
-- (f.onLedger, GK.PlaceSheet): a drag on it moves the ledger, and it closes with the ledger - "henge
-- sammen er nice. lukkes hoved lukkes begge" (the owner, 2026-11-06).
local sheets = {}

--- What a drag on a sheet moves: the ledger, through the ledger's own drag (which saves where it is),
--- when the sheet lies on it - the sheet is anchored to it and goes along. Else the sheet itself, and always a
--- sheet with f.ownDrag set (the Death Note's share sheet: "movable separate from the rest of the window", the
--- user, 2026-11-27).
local function Dragged(f)
    local win = f.onLedger and not f.ownDrag and _G.GrudgekeeperFrame
    if win and win:IsShown() then return win end
    return f
end
local function DragStart(f)
    local t = Dragged(f)
    local fn = t ~= f and t:GetScript("OnDragStart")
    if fn then fn(t) else t:StartMoving() end
end
local function DragStop(f)
    local t = Dragged(f)
    local fn = t ~= f and t:GetScript("OnDragStop")
    if fn then fn(t) else t:StopMovingOrSizing() end
end

--- A sheet's frame and what every sheet does: the dialog strata, kept on screen, dragged as above.
local function SheetFrame(name, w, h, template)
    local f = CreateFrame("Frame", name, UIParent, template)
    f:SetSize(w, h)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", DragStart)
    f:SetScript("OnDragStop", DragStop)
    sheets[#sheets + 1] = f
    return f
end

--- The ledger closing: the sheets lying on it close with it (Window.lua hooks its OnHide).
function GK.CloseLedgerSheets()
    for _, f in ipairs(sheets) do
        if f.onLedger then f:Hide() end
    end
end

--- A sheet's frame, w x h, for its maker to draw its paper on: it can be dragged anywhere (or moves the ledger it
--- lies on), and Escape closes it before the window under it. Hidden: the caller writes on it first. The kill
--- order's WANTED poster is drawn on one (Post.lua); it was a scroll between two rolls with our cross in its
--- corner until 2026-11-21.
function GK.MakeSheet(name, w, h)
    local f = SheetFrame(name, w, h)
    f:Hide()
    if LIB.RegisterPopup then LIB.RegisterPopup(f) else tinsert(UISpecialFrames, name) end
    return f
end

--- A part of a sheet: its name in small capitals at y down from the top, and a thin rule from there to
--- the sheet's edge. The rule is placed from the sheet on both ends, so they can't disagree on its height.
--- fs:Label(words) renames it, and the rule moves with the words.
--- fs:Place(y) moves it down the sheet, rule and all (the note sheet's parts move with its tags).
function GK.SheetSection(f, text, y)
    local fs = f:CreateFontString(nil, "ARTWORK")
    fs.rule = f:CreateTexture(nil, "ARTWORK")
    if f.skinned then
        -- on a window in the game's frame, in the skin's colours (GK.MakeFrameSheet)
        GK.Ink(fs, GK.FADED, TEXT_FONT, 10)
        GK.Paint(fs.rule, "rule")
    else
        SheetInk(fs, FADED, TEXT_FONT, 10)
        fs.rule:SetColorTexture(FADED[1], FADED[2], FADED[3], 0.45)
    end
    fs.rule:SetHeight(1)
    function fs:Place(at)
        self.y = at
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -at)
        self.rule:ClearAllPoints()
        self.rule:SetPoint("TOPLEFT", f, "TOPLEFT", 30 + math.ceil(self:GetStringWidth() or 30) + 8, -(at + 5))
        self.rule:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -(at + 5))
    end
    function fs:Label(words)
        self:SetText(words:upper())
        self:Place(self.y)
    end
    fs.y = y
    fs:Label(text)
    function fs:ShowAll(on)
        self:SetShown(on)
        self.rule:SetShown(on)
    end
    return fs
end

--- A line to write on: an edit box drawn as a ruled line in ink. The hint stands on it in faded ink
--- while it is empty, and the line turns to blood while you write. e.onChange(e, byHand) runs on every
--- change of its text (OnTextChanged is the line's own: set onChange, not the script).
function GK.SheetLine(f, width, letters, hint, numeric)
    local e = CreateFrame("EditBox", nil, f)
    e:SetSize(width, 20)
    e:EnableMouse(true)
    e:SetAutoFocus(false)
    e:SetMaxLetters(letters)
    GK.SetFont(e, TEXT_FONT, 13)                 -- what is typed: a name in Cyrillic shows as it is typed
    e:SetTextColor(INK[1], INK[2], INK[3])
    e:SetShadowOffset(0, 0)
    e:SetTextInsets(2, 2, 0, 0)
    e:SetHighlightColor(BLOOD[1], BLOOD[2], BLOOD[3], 0.35)
    if numeric then
        e:SetNumeric(true)
        e:SetJustifyH("RIGHT")
    end
    e.rule = e:CreateTexture(nil, "ARTWORK")
    e.rule:SetHeight(1)
    e.rule:SetPoint("BOTTOMLEFT")
    e.rule:SetPoint("BOTTOMRIGHT")
    e.hint = e:CreateFontString(nil, "ARTWORK")
    SheetInk(e.hint, FADED, TEXT_FONT, 12)
    e.hint:SetAlpha(0.7)
    e.hint:SetPoint("LEFT", 2, 0)
    e.hint:SetText(hint or "")
    local function Look(self)
        self.hint:SetShown((self:GetText() or "") == "")
        local c = self:HasFocus() and BLOOD or FADED
        self.rule:SetColorTexture(c[1], c[2], c[3], self:HasFocus() and 0.8 or 0.55)
    end
    e:SetScript("OnTextChanged", function(self, byHand)
        Look(self)
        if self.onChange then self.onChange(self, byHand) end
    end)
    e:SetScript("OnEditFocusGained", Look)
    e:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        Look(self)
    end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    Look(e)
    return e
end

--- The button that sends a sheet: its word in blood beside the red wax seal, at the sheet's foot on the
--- right. b:Set(word).
function GK.SheetSeal(f, onClick)
    local b = CreateFrame("Button", nil, f)
    b:SetHeight(50)
    b:SetPoint("BOTTOMRIGHT", -20, 16)
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetTexture(MEDIA .. "glow")
    b.glow:SetBlendMode("ADD")
    b.glow:SetVertexColor(1, 0.25, 0.1)
    b.glow:SetAlpha(0.45)
    b.glow:SetSize(84, 84)
    b.glow:Hide()
    b.wax = b:CreateTexture(nil, "ARTWORK")
    b.wax:SetTexture(MEDIA .. "seal_red")
    b.wax:SetSize(50, 50)
    b.wax:SetPoint("RIGHT")
    b.glow:SetPoint("CENTER", b.wax, "CENTER")
    b.text = b:CreateFontString(nil, "ARTWORK")
    SheetInk(b.text, BLOOD, TITLE_FONT, 18)
    b.text:SetPoint("RIGHT", b.wax, "LEFT", -2, 0)
    function b:Set(word)
        self.text:SetText(word)
        self:SetWidth(52 + math.ceil(self.text:GetStringWidth() or 60))
    end
    b:SetScript("OnEnter", function(self) self.glow:Show() end)
    b:SetScript("OnLeave", function(self)
        self.glow:Hide()
        self.wax:SetVertexColor(1, 1, 1)
    end)
    b:SetScript("OnMouseDown", function(self) self.wax:SetVertexColor(0.72, 0.72, 0.72) end)
    b:SetScript("OnMouseUp", function(self) self.wax:SetVertexColor(1, 1, 1) end)
    b:SetScript("OnClick", onClick)
    return b
end

-- ---------------------------------------------------------------------------
-- The notes' sheets in the game's own frame: Blizzard's window (SettingsFrameTemplate, which Forever
-- draws in bronze, as our other addons' windows) on our plain parchment, with the game's own boxes,
-- radio buttons and buttons, and ink for the writing. A poster suits a kill order; for the notes and
-- the who-picker the owner asked for "blizz bars rundt og ikke scroll ... litt mer clean", then "med
-- parchment bakgrunn" (2026-11-06).
-- ---------------------------------------------------------------------------
--- A window in the game's frame, w x h, titled; dragged as every sheet is, closed by its X (which hides
--- it directly: the template's HideUIPanel does nothing in combat) and by Escape before the window under it.
function GK.MakeFrameSheet(name, w, h, title)
    local f = SheetFrame(name, w, h, "SettingsFrameTemplate")
    -- the template's flat grey backdrop gives way to the skin's background, as on the ledger: the plain
    -- parchment (sheet_single, the page with no torn edge) in its tone, or in classic the frame's own panel
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 7, -18)
    bg:SetPoint("BOTTOMRIGHT", -3, 3)
    local function Back()
        if GK.Classic() then
            bg:SetAtlas("heavybronze-frame-background")
            bg:SetDesaturation(0)
            bg:SetVertexColor(1, 1, 1)
        else
            bg:SetTexture(MEDIA .. "sheet_single")
            bg:SetTexCoord(0, 1, 0, 1)
            if GK.Tone then GK.Tone(bg) end
        end
    end
    Back()
    GK.OnLook(Back)
    f.bg = bg
    f.skinned = true                  -- what is written on it takes the skin's colours (SheetSection)
    if type(f.Bg) == "table" then f.Bg:Hide() end
    if type(f.ClosePanelButton) == "table" then f.ClosePanelButton:SetScript("OnClick", function() f:Hide() end) end
    -- the title bar's own text; a font string of ours where a template has none
    f.title = type(f.NineSlice) == "table" and f.NineSlice.Text or nil
    if not f.title then
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOP", 0, -5)
    end
    f.title:SetText(title or "")
    f:Hide()
    if LIB.RegisterPopup then LIB.RegisterPopup(f) else tinsert(UISpecialFrames, name) end
    return f
end

--- The head of a framed sheet: whom it is about. The face in the bronze ring, the name in the ledger's
--- ink and type, and level, race and class under it. head:Set(t), t = { key, c, r, rf, sx, l }.
function GK.FrameHead(f, w)
    local width = w - 82 - 24
    local h = { face = GK.MakePortrait(f, 48) }
    h.face.tex:SetPoint("CENTER", f, "TOPLEFT", 50, -60)
    h.name = f:CreateFontString(nil, "ARTWORK")
    GK.Ink(h.name, GK.INK, GK.TITLE_FONT, 19)              -- in the skin's colours, as the frame is skinned
    h.name:SetPoint("TOPLEFT", 82, -44)
    h.name:SetWidth(width)
    h.name:SetJustifyH("LEFT")
    h.name:SetWordWrap(false)
    h.info = f:CreateFontString(nil, "ARTWORK")
    GK.Ink(h.info, GK.FADED, GK.TEXT_FONT, 11)
    h.info:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -4)
    h.info:SetWidth(width)
    h.info:SetJustifyH("LEFT")
    h.info:SetWordWrap(false)
    function h:Set(t)
        self.name:SetText(GK.Show(t.key))
        self.info:SetText(GK.Describe(t.l, t.c, t.r))
        self.face:Set(t)
    end
    return h
end

--- The game's own text box, with a grey hint on it while it is empty (as the game's search boxes have).
--- Hook OnTextChanged to follow it, rather than setting it.
local function Hint(box) box.hint:SetShown((box:GetText() or "") == "") end
function GK.FrameBox(parent, width, letters, hint)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width, 20)
    e:SetAutoFocus(false)
    e:SetMaxLetters(letters)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e.hint = e:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    e.hint:SetPoint("LEFT", 2, 0)
    e.hint:SetText(hint or "")
    e:HookScript("OnTextChanged", Hint)
    Hint(e)
    return e
end

--- The game's own button, its words in the game's small type in every state (setting only the current
--- one loses them when the button is disabled, Guildhall found).
function GK.FrameButton(parent, text, width, onClick)
    local b = GK.MakeButton(parent, width or 96, 22)
    b:SetNormalFontObject("GameFontNormal")
    b:SetHighlightFontObject("GameFontHighlight")
    b:SetDisabledFontObject("GameFontDisable")
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

--- Where a sheet opens: on the ledger when it is open - over the middle of the book, its top well below
--- the tabs (a scroll laid right under them looked as if they were its own), anchored to the ledger so
--- the two go together (see sheets, above). Beside the book was tried and the owner wanted it on top
--- (2026-11-06). Without the ledger, high in the middle. Anchored by its top either way, so a sheet that
--- grows grows downward.
function GK.PlaceSheet(f)
    local win = _G.GrudgekeeperFrame
    f:ClearAllPoints()
    f.onLedger = (win and win:IsShown()) and true or nil
    if f.onLedger then
        f:SetPoint("TOP", win, "TOP", 0, -80)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end
end

--- The Grudgekeeper himself, cut round, with the class of whoever the letter is about as a small badge on his
--- shoulder: f.disc, f.portrait, f.badge, f.badgeRing. size: the disc's side; x, y: its top left.
local function KeeperPortrait(f, size, x, y)
    local k = size / 112                             -- drawn for 112 (the note's), the rest in proportion
    local disc = f:CreateTexture(nil, "ARTWORK")
    disc:SetSize(size, size)
    disc:SetPoint("TOPLEFT", x, -y)
    disc:SetColorTexture(0.12, 0.06, 0.03, 0.95)
    local discMask = f:CreateMaskTexture()
    discMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    discMask:SetAllPoints(disc)
    disc:AddMaskTexture(discMask)
    local portrait = f:CreateTexture(nil, "ARTWORK", nil, 1)
    portrait:SetSize(size - 6 * k, size - 6 * k)
    portrait:SetPoint("CENTER", disc, "CENTER")
    portrait:SetTexture(MEDIA .. "portrait")
    local portraitMask = f:CreateMaskTexture()
    portraitMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    portraitMask:SetAllPoints(portrait)
    portrait:AddMaskTexture(portraitMask)
    f.badge = f:CreateTexture(nil, "ARTWORK", nil, 3)
    f.badge:SetSize(32 * k, 32 * k)
    f.badge:SetPoint("CENTER", disc, "BOTTOMRIGHT", -12 * k, 12 * k)
    local badgeRing = f:CreateTexture(nil, "ARTWORK", nil, 2)
    badgeRing:SetSize(36 * k, 36 * k)
    badgeRing:SetPoint("CENTER", f.badge, "CENTER")
    badgeRing:SetColorTexture(0.12, 0.06, 0.03, 0.95)
    local ringMask = f:CreateMaskTexture()
    ringMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ringMask:SetAllPoints(badgeRing)
    badgeRing:AddMaskTexture(ringMask)
    f.badgeRing = badgeRing
    f.disc, f.portrait = disc, portrait
end

--- A death's blood on the paper, under the writing.
local function Blood(f, spot)
    f.blood = f:CreateTexture(nil, "BORDER")
    f.blood:SetTexture(MEDIA .. "blood")
    f.blood:SetSize(spot[3], spot[3])
    f.blood:SetPoint("CENTER", spot[1], spot[2])
    f.blood:SetRotation(-0.5)
    f.blood:SetAlpha(0.5)
end

--- The letter's sheet: the burnt parchment, torn at top and bottom (Media/letter_sheet, cut from the post sheet's
--- by art/make_grudgekeeper_letter_sheet.py), in three pieces so it grows to its words without stretching
--- its torn edges. Hidden and not yet registered as a window: the caller adds its writing first.
local SHEET_EDGE = 64 / 512                          -- each torn edge, of the texture's height
local function LetterSheet(name, L)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(L.w, L.h)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER", 0, 120)
    f:EnableMouse(true)
    local edge = L.w * SHEET_EDGE                    -- on screen, as wide as the sheet is in the texture
    local top, mid, bottom = f:CreateTexture(nil, "BACKGROUND"), f:CreateTexture(nil, "BACKGROUND"),
        f:CreateTexture(nil, "BACKGROUND")
    for _, t in ipairs({ top, mid, bottom }) do t:SetTexture(MEDIA .. "letter_sheet") end
    top:SetTexCoord(0, 1, 0, SHEET_EDGE)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(edge)
    bottom:SetTexCoord(0, 1, 1 - SHEET_EDGE, 1)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    bottom:SetHeight(edge)
    mid:SetTexCoord(0, 1, SHEET_EDGE, 1 - SHEET_EDGE)
    mid:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
    mid:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
    f.paper = mid
    Blood(f, L.blood)
    KeeperPortrait(f, L.face, L.faceX, L.faceY)
    f:Hide()
    return f
end

local function BuildLetter()
    local L = LAYOUT
    local f = LetterSheet("GrudgekeeperLetter", L)
    f.layout = L
    -- where the writing starts: the title beside the face, to the right margin (an order's short of its level);
    -- the words under both
    local headX = L.faceX + L.face + 12
    local headW = L.w - headX - L.right
    local textW = L.w - L.textX - L.right
    -- An order's page: the face of whom it is about in the bronze ring, where his own portrait is on a note,
    -- and its bounty a line under who they are.
    f.face = GK.MakePortrait(f, L.face)
    f.face.tex:SetPoint("CENTER", f.disc, "CENTER")
    -- the face opens the order in the ledger, and the letter shuts: two windows on one order is one too many.
    -- It was a button, Open in the ledger, beside Add to the pot ("fjern 'open in the ledger' kanskje?", the
    -- owner, 2026-11-19); the face is where you look to see who it is.
    f.faceButton = CreateFrame("Button", nil, f)
    f.faceButton:SetSize(L.face, L.face)
    f.faceButton:SetPoint("CENTER", f.disc, "CENTER")
    f.faceButton:SetFrameLevel(f:GetFrameLevel() + 6)
    local lit = f.faceButton:CreateTexture(nil, "HIGHLIGHT")
    lit:SetAllPoints()
    lit:SetTexture(MEDIA .. "portrait_ring")
    lit:SetBlendMode("ADD")
    lit:SetAlpha(0.45)
    f.faceButton:SetScript("OnClick", function()
        local key = f.faceOrder
        if not key then return end
        f:Hide()
        GK.OpenOrder(key)
    end)
    f.faceButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Open in the ledger", 1, 1, 1)
        GameTooltip:Show()
    end)
    f.faceButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.goldCap = f:CreateFontString(nil, "ARTWORK")
    Ink(f.goldCap, FADED, TEXT_FONT, L.bounty)
    -- an order's level, on the right of the head by the face's middle: LEVEL small, the number large under it,
    -- both in the plain font and dark ink (the title's capitals were thin and the faded ink hard to see)
    f.levelCap = f:CreateFontString(nil, "ARTWORK")
    Ink(f.levelCap, INK, TEXT_FONT, 10)
    f.levelCap:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(L.right + L.levelIn), -L.levelY)
    f.levelCap:SetText("LEVEL")
    f.level = f:CreateFontString(nil, "ARTWORK")
    Ink(f.level, INK, TEXT_FONT, L.level)
    f.level:SetPoint("TOPRIGHT", f.levelCap, "BOTTOMRIGHT", 0, -2)
    f.level:SetWidth(L.levelW - L.levelIn)
    f.level:SetJustifyH("RIGHT")

    -- The writing, beside the face: the title, whom it is about, the words, and the letter's own buttons
    -- right under them.
    f.title = f:CreateFontString(nil, "ARTWORK")
    Ink(f.title, BLOOD, TITLE_FONT, L.title)
    f.title:SetPoint("TOPLEFT", headX, -L.headY)          -- where: FillLetter, by the kind of letter
    f.title:SetWidth(headW)
    f.title:SetJustifyH("LEFT")
    f.title:SetMaxLines(2)                                 -- a long title takes two lines before it runs on
    f.name = f:CreateFontString(nil, "ARTWORK")
    Ink(f.name, INK, TEXT_FONT, L.name)
    f.name:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -L.nameGap)
    f.name:SetWidth(headW - L.levelW)                      -- an order's alone: short of its level
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.body = f:CreateFontString(nil, "ARTWORK")
    Ink(f.body, INK, TEXT_FONT, 13)
    f.body:SetWidth(textW)
    f.body:SetJustifyH("LEFT")
    f.body:SetSpacing(3)
    f.buttons = {}
    for i = 1, 3 do f.buttons[i] = LetterButton(f) end

    -- The signature by the right edge, the seal pressed beside it: his name on a note, the poster on an order.
    f.sign = f:CreateFontString(nil, "ARTWORK")
    Ink(f.sign, INK, TITLE_FONT, 16)
    f.sign:SetPoint("BOTTOMRIGHT", -L.edge, L.signY)
    f.seal = f:CreateTexture(nil, "OVERLAY")
    f.seal:SetSize(44, 44)
    f.seal:SetPoint("RIGHT", f.sign, "LEFT", -6, 2)

    -- The FULFILLED stamp UNDER the writing and half faded, as ink stamped on paper: over it, at full strength,
    -- it made the letter "vanskelig å lese" (the owner, 2026-11-06). It comes down hard: big and faint to its
    -- size, then the letter jolts.
    f.stamp = f:CreateTexture(nil, "BORDER", nil, 2)
    f.stamp:SetSize(128, 64)                         -- where: FillLetter, under the words
    f.stamp:SetAlpha(STAMP_ALPHA)
    f.stamp:Hide()
    local slam = f.stamp:CreateAnimationGroup()
    local grow = slam:CreateAnimation("Scale")
    grow:SetScaleFrom(2.4, 2.4)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(0.16)
    grow:SetSmoothing("IN")
    local fade = slam:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(STAMP_ALPHA)
    fade:SetDuration(0.08)
    local jolt = f:CreateAnimationGroup()
    for i, dx in ipairs({ 5, -9, 4 }) do
        local t = jolt:CreateAnimation("Translation")
        t:SetOffset(dx, 0)
        t:SetDuration(0.04)
        t:SetOrder(i)
    end
    slam:SetScript("OnFinished", function()
        jolt:Play()
        GK.Sound("IG_QUEST_LIST_COMPLETE")
    end)
    f.slam = slam

    -- The foot: a faint rule, Read all on the left, the pile in the middle, Close on the right. Close is the one
    -- way out (and Escape): "X oppe i høyre funker ikke så bra" (the owner, 2026-11-07), and the cross went when
    -- it was "vi trenger ikke to close. men close button ser bedre ut der den er enn X button" (2026-11-19).
    -- Close was Later once, which kept the letter unread and brought the notice back ("burde være lukk
    -- isteden?", 2026-11-08).
    f.rule = f:CreateTexture(nil, "ARTWORK")
    f.rule:SetHeight(1)
    f.rule:SetPoint("BOTTOMLEFT", L.edge - 6, L.ruleY)
    f.rule:SetPoint("BOTTOMRIGHT", -(L.edge - 6), L.ruleY)
    f.rule:SetColorTexture(FADED[1], FADED[2], FADED[3], 0.45)
    f.readAll = LetterButton(f)
    f.readAll:Set("Read all")
    f.readAll:SetPoint("BOTTOMLEFT", L.edge, L.footY)
    -- every letter read at once, and so gone (GK.ReadAllLetters): it was a right-click on the ledger's
    -- Letters button alone, which nobody finds
    f.readAll:SetScript("OnClick", function() GK.ReadAllLetters() end)
    local close = LetterButton(f)
    close:Set("Close")
    close:SetPoint("BOTTOMRIGHT", -L.edge, L.footY)
    close:SetScript("OnClick", function() GK.CloseLetters() end)
    f.closeButton = close
    f.pile = BuildPile(f)

    -- Arrives with a fade, nothing more; turning to the next letter only turns the page. A fade alone: it
    -- dropped 8 into place as well, but a Translation's offset goes when the animation ends,
    -- so the sheet slid down and then jumped back up - "de åpnes og så snapper de typ, 10 px opp nesten med en
    -- gang" (the owner, 2026-11-18).
    local arrive = f:CreateAnimationGroup()
    local fadeIn = arrive:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.18)
    f.arrive = arrive

    f:Hide()
    -- where it stood, if it was moved (a key of its own: the iron frame's place was for a frame twice its size)
    if LIB.RegisterWindow then LIB.RegisterWindow(f, GK.db, "letter") end
    -- Nothing is drawn again under the mouse while it is dragged: what changed meanwhile waits for it to be
    -- let go. The letter was filled again on every change the guild sent, as it moved: "det er noe rart med
    -- texten når jeg drar vinduet rundt, det flickerer" (the owner, 2026-11-18).
    f:HookScript("OnDragStart", function(self) self.dragging = true end)
    f:HookScript("OnDragStop", function(self)
        self.dragging = false
        if self.stale then
            self.stale = false
            GK.Changed()                          -- the open letter is filled again (StartLetters)
        end
    end)
    -- RegisterWindow owns OnShow/OnHide; ours only ever hooks.
    f:HookScript("OnHide", Closed)
    win = f
end

--- One letter on the window: an order's page or a note, its buttons, its seal, the pile.
local function FillLetter(L)
    local f = win
    local lay = f.layout
    local d = GK.LetterContent(L)
    local order = not d.note
    -- The title. An order's at the head's top, whom it is about and the bounty under it ("ORDER COMPLETE"
    -- fills the line at the size "KILL ORDER" wants). A note's has nothing under it: large, and in the middle
    -- of the portrait beside it, where it hung small at the top with the room under it empty.
    local headX = lay.faceX + lay.face + 12
    local headW = lay.w - headX - lay.right
    f.title:ClearAllPoints()
    f.title:SetWidth(order and headW - lay.levelW or headW)
    if order then
        Ink(f.title, BLOOD, TITLE_FONT, #d.title > 11 and lay.titleLong or lay.title)
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", headX, -lay.headY)
    else
        Ink(f.title, BLOOD, TITLE_FONT, #d.title > 16 and lay.noteLong or lay.note)
    end
    f.title:SetText(d.title)
    if not order then
        -- in the middle of the portrait by its top edge, on a whole pixel: by its own middle a title of an
        -- odd height stood on a half pixel, and a half pixel can round either way as the sheet is dragged
        local h = f.title:GetStringHeight() or lay.note
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", headX, -(lay.faceY + math.floor((lay.face - h) / 2 + 0.5)))
    end

    -- the head: whom an order is about, and its bounty; on a note, the Grudgekeeper with their class on his
    -- shoulder
    f.name:SetShown(order)
    -- the level, on the right of an order's head; none when we never saw it
    local lvl = order and tonumber(L.l) or nil
    f.level:SetText(lvl == -1 and "??" or lvl and tostring(math.floor(lvl)) or "")
    f.level:SetShown(lvl ~= nil)
    f.levelCap:SetShown(lvl ~= nil)
    -- the face opens the order in the ledger, while we still have it; a sample's opens nothing
    f.faceOrder = order and not L.sample and L.o or nil
    f.faceButton:SetShown(f.faceOrder ~= nil)
    f.disc:SetShown(not order)
    f.portrait:SetShown(not order)
    local coords = not order and L.c and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[L.c]
    f.badge:SetShown(coords and true or false)
    f.badgeRing:SetShown(coords and true or false)
    if coords then
        f.badge:SetTexture(CLASS_ICONS)
        f.badge:SetTexCoord(unpack(coords))
    end
    local b = order and d.bounty or nil
    local gold = b and (b.copper or 0) > 0
    f.goldCap:SetShown(b ~= nil)
    f.goldCap:ClearAllPoints()
    if order then
        f.face:SetShown(true)                       -- its ring as well: Set shows the face alone
        f.face:Set({ key = L.n, c = L.c, rf = L.rf, sx = L.sx })
        f.name:SetText(d.name or "")
    else
        f.face:SetShown(false)
    end
    if b then
        -- one line under who they are: the gold first, or the order's own words where there is none
        Ink(f.goldCap, gold and INK or BLOOD, TEXT_FONT, lay.bounty)
        f.goldCap:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -lay.bountyGap)
        f.goldCap:SetText(gold and (GK.Coins(b.copper) .. " bounty" .. ((b.from or 0) > 1
            and (" - from %d guildies"):format(b.from) or "")) or "No bounty - for the guild's honour")
    end

    -- the words, under the head, as many as the room above the buttons and the seal holds
    -- the head beside the face, the words under whichever ends lower
    local top = lay.headY + (f.title:GetStringHeight() or lay.title)
    if order then
        top = top + lay.nameGap + (f.name:GetStringHeight() or lay.name)
            + (b and lay.bountyGap + (f.goldCap:GetStringHeight() or lay.bounty) or 0)
    end
    top = math.floor(math.max(top, lay.faceY + lay.face) + 10 + 0.5)      -- a whole pixel (see the title)
    f.body:ClearAllPoints()
    f.body:SetPoint("TOPLEFT", f, "TOPLEFT", lay.textX, -top)
    -- what the letter asks of you (the way to an order in the ledger is its face)
    local specs = {}
    for _, spec in ipairs(d.buttons or {}) do specs[#specs + 1] = spec end
    -- the room down to the seal over the signature, at the sheet's most; then the sheet as tall as its words
    local buttonsH = #specs > 0 and (LETTER_BUTTON_H + BUTTON_GAP) or 0
    local room = lay.maxH - lay.signY - lay.sealRoom - 6 - buttonsH - top
    FitBody(f.body, d.lines, d.give, room)
    local h = top + (f.body:GetStringHeight() or 0) + buttonsH + 6 + lay.sealRoom + lay.signY
    f:SetHeight(math.max(lay.h, math.min(lay.maxH, math.ceil(h))))
    -- a stamp under the words, across the sheet under the head
    f.stamp:ClearAllPoints()
    f.stamp:SetPoint("CENTER", f, "TOPLEFT", lay.w / 2, -(top + 40))
    local x = 0
    for i, btn in ipairs(f.buttons) do
        local spec = specs[i]
        btn:SetShown(spec ~= nil)
        if spec then
            btn:Set(spec[1])
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", f.body, "BOTTOMLEFT", x, -BUTTON_GAP)
            x = x + btn.w + 8
            Pressable(btn, not L.sample)
            btn:SetScript("OnClick", function()
                spec[2]()
                if f:IsShown() and GK.char.letters[index] == L then FillLetter(L) end
            end)
        end
    end

    -- the signature and the seal; blood on a death; the stamp waits for the letter to be shown (GK.ShowLetter)
    local k = lay.sealRoom / 38                       -- the seal in proportion to the room kept for it
    if order then
        Ink(f.sign, FADED, TEXT_FONT, 11)
        f.sign:SetText(d.foot or "")
        f.seal:SetSize(38 * k, 38 * k)
    else
        Ink(f.sign, INK, TITLE_FONT, 14)
        f.sign:SetText("- the Grudgekeeper")
        f.seal:SetSize(44 * k, 44 * k)
    end
    f.seal:SetTexture(MEDIA .. d.seal)
    f.blood:SetShown(d.blood == true)
    f.stamp:Hide()
    f.stampName = d.stamp
    if d.stamp then f.stamp:SetTexture(MEDIA .. d.stamp) end

    -- the pile; Read all only while another letter waits unread
    local more = UpdatePile(f.pile)
    f.readAll:SetShown(more > 0)
end

-- ---------------------------------------------------------------------------
-- Opening and closing
-- ---------------------------------------------------------------------------
--- Show letter i of the pile in the letter window. Reading it marks it read.
function GK.ShowLetter(i)
    local list = GK.char.letters
    if #list == 0 then
        GK.CloseLetters()
        return
    end
    -- an update's letter with patch notes opens them, read, in place of a scroll (2026-11-23)
    local P = list[math.max(1, math.min(i or #list, #list))]
    if P and P.kind == "news" and not P.sample and PATCH_NOTES[P.news] then
        P.read = true
        holding[P] = nil
        GK.CloseLetters()
        GK.OpenPatchNotes(P.news)
        GK.NoticeUpdate(false)
        GK.Changed()
        return
    end
    index = math.max(1, math.min(i or #list, #list))
    local L = list[index]
    L.read = true
    reading = true
    holding[L] = nil                                -- read before its minute was up: nothing left to land
    GK.Sound("IG_ABILITY_PAGE_TURN")
    if not win then BuildLetter() end
    local was = win:IsShown()
    FillLetter(L)
    win:Show()
    if not was then win.arrive:Play() end
    if win.stampName then
        win.stamp:Show()
        win.slam:Play()
    end
    GK.NoticeUpdate(false)
    GK.Changed()
end

--- Every letter read at once, and so gone - a pile of them after a while away ("med mange notifications kan
--- vi tillate noe 'mark all as read'", the owner, 2026-11-09). The ledger keeps what they said. Returns how
--- many were unread.
function GK.ReadAllLetters()
    local n = 0
    for _, L in ipairs(GK.char.letters) do
        if not L.read then n = n + 1 end
        L.read = true
        holding[L] = nil
    end
    GK.CloseLetters()
    reading = false
    Prune()
    GK.NoticeUpdate(false)
    GK.Changed()
    return n
end

--- Open the pile at the first unread letter (or the newest).
function GK.OpenLetters()
    local list = GK.char.letters
    if #list == 0 then
        print(GK.TAG .. ": no letters. Kill orders from your guild, your new titles and a death that posted a "
            .. "kill order arrive here.")
        return
    end
    local _, first = GK.Unread()
    GK.ShowLetter(first or #list)
end

function GK.CloseLetters()
    if win and win:IsShown() then win:Hide() end
end

--- fresh: the account's saved table was missing at login - a first install, with nothing new to anyone.
function GK.StartLetters(fresh)
    GK.DeliverNews(fresh)
    Prune()
    -- what waited unread since last time is news again from this login, and fades as a new one does
    for _, L in ipairs(GK.char.letters) do
        if not L.read and not L.faded then Landed(L) end
    end
    GK.NoticeUpdate(false)
    LIB.On("PLAYER_REGEN_ENABLED", function() if next(holding) then Release() end end)
    -- Into a battleground (GK.InBattleground) the letter goes out of sight. Out of one, the letters by the
    -- icon get their while again, as they stood out of sight; what waited there lands; the letter shows
    -- again. Only on the way in and out - on every change of zone, a letter would never fade on a long ride.
    local inBattleground = GK.InBattleground()
    local function PlaceChanged()
        local now = GK.InBattleground()
        if now == inBattleground then return end
        inBattleground = now
        if not now then
            for _, L in ipairs(GK.char.letters) do
                if landedAt[L] then Landed(L) end
            end
            if next(holding) then Release() end
        end
        GK.NoticeUpdate(false)
    end
    LIB.On("PLAYER_ENTERING_WORLD", PlaceChanged)
    LIB.On("ZONE_CHANGED_NEW_AREA", PlaceChanged)
    -- An open letter follows changes to its order (taken, paid, closed), and its pile a letter landing.
    LIB.Listen("GRUDGEKEEPER_CHANGED", function()
        local L = index and GK.char.letters[index]
        if not (L and win and win:IsShown()) then return end
        if win.dragging then win.stale = true return end   -- when it is let go (BuildLetter)
        FillLetter(L)
    end)
end
