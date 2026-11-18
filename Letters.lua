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
local LIB = LibStub("LibForever-1.0")

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
local NW, NH = 624, 416
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
-- The rolled ends of a scroll
-- ---------------------------------------------------------------------------
-- In three pieces, so any width keeps the curled ends round: the two ends at their own shape, the
-- middle stretched. roll.tga holds the roll across its full width in rows 16-112 of 128
-- (art/import_grudgekeeper.py puts it there). flip: the bottom roll.
local ROLL_V0, ROLL_V1, ROLL_CAP = 16 / 128, 112 / 128, 0.08
local CAP_ASPECT = 512 * ROLL_CAP / 96          -- an end's width over its height, in the texture

function GK.MakeRoll(parent, height, flip)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)
    local v0, v1 = ROLL_V0, ROLL_V1
    if flip then v0, v1 = v1, v0 end
    local function Piece(u0, u1)
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetTexture(MEDIA .. "roll")
        t:SetTexCoord(u0, u1, v0, v1)
        return t
    end
    local left, middle, right = Piece(0, ROLL_CAP), Piece(ROLL_CAP, 1 - ROLL_CAP), Piece(1 - ROLL_CAP, 1)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(height * CAP_ASPECT)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(height * CAP_ASPECT)
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    return f
end

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
    -- the oldest go past MAX_LETTERS, and the open letter keeps its place in what is left
    while #list > MAX_LETTERS do
        table.remove(list, 1)
        if index then index = math.max(1, index - 1) end
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

--- Somebody paid you for an order you fulfilled: the poster (their reward) or a backer (their share).
function GK.PaidLetter(o, payer, amount)
    Add("paid", { n = o.n, c = o.c, r = o.r, l = o.l, by = payer or o.by, reward = amount or o.reward, o = o.key })
end

function GK.ExpiredLetter(o)
    Add("expired", { n = o.n, c = o.c, r = o.r, l = o.l, guid = o.guid, reward = o.reward, o = o.key })
end

--- A kill of ours that earned a new title: the one kind of kill with a letter (Kills.lua). An unread one
--- is written over by the next rather than stacked, so two titles before you look are one letter, the
--- newest. Silent: you were there.
function GK.KillLetter(v, zone, title)
    local rank, of = GK.MyRank()
    local list = GK.char.letters
    local last = list[#list]
    local L
    if last and last.kind == "kill" and not last.read then
        L = last
        L.t, L.faded = time(), nil                  -- news again, faded or not
        Hold(L)                                     -- the minute starts again from this kill
    else
        L = Add("kill", {}, true, true)
    end
    L.n, L.c, L.r, L.l, L.z = v.key, v.c, v.r, v.l, zone
    L.rank, L.of, L.total, L.title = rank, of, GK.char.points, title
    GK.NoticeUpdate(false)
    GK.Changed()
end

--- autoOrder: this death posted a kill order on them (GK.AutoOrder), and the letter says so.
function GK.SlainLetter(v, times, zone, autoOrder)
    Add("slain", { n = v.key, guid = v.guid, c = v.c, r = v.r, l = v.l, times = times, z = zone, spell = v.spell,
        autoOrder = autoOrder or nil })
end

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
    Add("kill", S({ n = "Gærd Balle", c = "HUNTER", r = horde and "Night Elf" or "Troll", l = 27,
        z = "Hillsbrad Foothills", title = "Bloodhound", rank = 4, of = 12, total = 31 }))
    Add("slain", S({ times = 24, z = "Hillsbrad Foothills", spell = "Ambush" }))
    Add("news", { sample = true })                 -- about no one: no enemy's class on it
    print(GK.TAG .. ": five sample letters are in your pile - click the letter icon to read them.")
end

-- What's new: one small letter after an update with something worth a word. Once per account, to the
-- first character in after it, and never on a first install, where nothing is new to anyone. Letters
-- off skips it as it skips every letter. "en bitteliten 'what's new' vindu som forklarer nye endringene
-- med assists og kalkuleringer" (the owner, 2026-11-12) - a letter, as all his news is, never a window
-- of its own. Someone who skipped a release gets each letter they missed, oldest first: 1.5.0's came the
-- same day as 1.4.0's (the owner, 2026-11-12: "må vel ha enda en what's new da"). The next one: its id at
-- the end of NEWS, and its words in NEWS_WORDS.
local NEWS = { "1.4.0", "1.5.0", "1.6.0", "1.7.0" }
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
        "Track an enemy, and I'll tell you when they come near. You'll know them by the eye over their head.",
        "",
        "They wait at the top of your Grudges, and nobody else reads that page.",
    }, "seal_black", "Grudges", function() GK.OpenLedgerPage("Grudges") end },
    ["1.6.0"] = { "Blood in a row", {
        "String your kills together and I'll call it out - louder, the longer you last.",
        "",
        "My settings have pages of their own now: have it shouted, shown small, or not at all.",
    }, "seal_red", "Settings", function() GK.OpenOptions("Kill sprees") end },
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
    }, "seal_black", "Settings", function() GK.OpenOptions("Around the game") end },
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
-- The letter: one window for every letter
-- ---------------------------------------------------------------------------
-- Kill orders were a scroll and the rest a note, each its own window, and only the note had arrows: from a
-- note the arrow could open a kill order's scroll, which had none, and the rest of the pile was out of
-- reach ("når det er flere letters på en gang og det er kill orders og notification letters om hverandre
-- så funker det dårlig", the owner, 2026-11-18). Now one window in the note's iron frame holds them all,
-- in one place, with the pile at its foot, and its buttons are ink on the paper under what the letter says:
-- the scroll's red buttons were "ikke bra nok design ... spesielt med knappene" (the same day). Chosen from
-- a sketch over the owner's own screenshot (art/mockups/letters: A, with ink buttons). B, the scroll for
-- every letter, waits there.
local win                          -- the letter window up now, made on first use: one per look (wins)
local wins = {}
-- The letter's looks, while the owner compares them in game (the test panel, 2026-11-18): A, today's - the
-- note's iron frame, the face in a column of its own; F, the same frame made small, the face in the head
-- and the words across under it; P, a loose burnt sheet with no frame, as tall as its words. Sketched over
-- the owner's screenshot first (art/mockups/letters, round 2) after "letter vinduet er også blitt ganske
-- stort. føles unødvendig stort"; F and P were the two asked for. GK.db.letterStyle picks; A until then.
--   w, h: its size (P: h its least, maxH its most). frame: the note's iron frame, else the loose sheet.
--   face: the portrait's side; faceX, faceY its top left. column: the face with the bounty under it in a
--   column of its own and the writing beside it at textX; else the title beside the face and the words
--   under both from textX. right: the margin on the right. headY: the title's top. title, name: their
--   type's size. signY, ruleY, footY: the signature's line, the faint rule, and Read all and Close, up from
--   the foot; sealRoom: what the writing keeps clear over the signature. edge: Read all, Close and the
--   signature this far in from the sides. pile: seals at the foot at most. blood: x, y, size of a death's.
local LAYOUTS = {
    A = { w = NW, h = NH, frame = true, face = 112, faceX = 46, faceY = 70, column = true, textX = 196, right = 44,
          headY = 68, title = 26, name = 20, signY = 104, sealRoom = 38, ruleY = 92, footY = 54, edge = 46,
          pile = 9, blood = { 150, -40, 190 }, key = "note" },
    F = { w = 480, h = 320, frame = true, face = 60, faceX = 38, faceY = 48, textX = 38, right = 38, headY = 46,
          title = 18, name = 16, signY = 80, sealRoom = 30, ruleY = 70, footY = 40, edge = 36, pile = 7,
          blood = { 115, -30, 146 }, key = "noteF" },
    P = { w = 380, h = 280, maxH = 520, face = 60, faceX = 30, faceY = 34, textX = 30, right = 30, headY = 32,
          title = 18, name = 16, signY = 76, sealRoom = 30, ruleY = 66, footY = 30, edge = 28, pile = 7,
          blood = { 100, -40, 150 }, key = "noteP" },
}
local BUTTON_GAP = 12              -- between the words and the letter's buttons

local function LetterStyle()
    local s = GK.db and GK.db.letterStyle
    return LAYOUTS[s] and s or "A"
end

--- The letters closed - by X, Close or Escape: the read ones go. A moment later, so a letter's own button
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

-- Each kind's seal, for the pile at the foot: as the letter's own seal, without building the letter.
local SEALS = { order = "seal_red", complete = "seal_broken", kill = "seal_red", slain = "seal_black",
    paid = "seal_red", expired = "seal_black" }
local function SealOf(L)
    if L.kind == "news" then return (NEWS_WORDS[L.news] or NEWS_WORDS[LATEST])[3] end
    return SEALS[L.kind] or "seal_red"
end

--- The pile at the letter's foot: a seal for each letter, the open one larger in a bronze ring and the read
--- ones grey, an arrow either side, and under them where you are and how many more wait. A seal clicked
--- opens its letter; a long pile shows the nine around the open one.
local function BuildPile(f)
    local p = CreateFrame("Frame", nil, f)
    p:SetSize(200, 24)
    p:SetPoint("BOTTOM", f, "BOTTOM", 0, f.layout.footY + 12)
    p.seals = {}
    p.shown = f.layout.pile
    for i = 1, p.shown do
        local s = CreateFrame("Button", nil, p)
        s.tex = s:CreateTexture(nil, "ARTWORK")
        s.tex:SetAllPoints()
        s.ring = s:CreateTexture(nil, "OVERLAY")
        s.ring:SetTexture(MEDIA .. "portrait_ring")
        s.ring:SetSize(28, 28)
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
        b:SetSize(22, 22)
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Down")
        b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Disabled")
        b:SetScript("OnClick", function() GK.ShowLetter(index + dir) end)
        return b
    end
    p.prev = Arrow("Prev", -1)
    p.prev:SetPoint("RIGHT", p, "LEFT", -6, 0)
    p.next = Arrow("Next", 1)
    p.next:SetPoint("LEFT", p, "RIGHT", 6, 0)
    p.text = f:CreateFontString(nil, "ARTWORK")
    Ink(p.text, FADED, TEXT_FONT, 11)
    p.text:SetPoint("TOP", p, "BOTTOM", 0, -2)
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
            local size = open and 20 or 15
            s.at = at
            s:SetSize(size, size)
            s:ClearAllPoints()
            s:SetPoint("LEFT", p, "LEFT", x, 0)
            s.tex:SetTexture(MEDIA .. SealOf(L))
            s.tex:SetDesaturated(read)
            s.tex:SetAlpha(read and 0.45 or 1)
            s.ring:SetShown(open)
            x = x + size + 5
        end
    end
    p:SetWidth(math.max(1, x - 5))
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
--- The game's own close button (UIPanelCloseButton), for the note frame (letter_frame, GK.MakeNoteFrame),
--- whose iron corner our cross clashed with. It sits on the bronze rivet of the top-right iron (measured
--- from letter_frame.tga: 4.3% of the width in, 6.9% of the height down); at the frame's very corner it
--- hung half off the iron ("litt lenger inn og ned", the owner, 2026-11-06). Its click is our own
--- function: the template's HideUIPanel does nothing in combat when addon code calls it.
function GK.MakeGameCloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    b:SetScript("OnClick", onClick)
    b:SetFrameLevel(parent:GetFrameLevel() + 12)
    b:SetPoint("CENTER", parent, "TOPRIGHT", -parent:GetWidth() * 0.043, -parent:GetHeight() * 0.069)
    return b
end

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
--- when the sheet lies on it - the sheet is anchored to it and goes along. Else the sheet itself.
local function Dragged(f)
    local win = f.onLedger and _G.GrudgekeeperFrame
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

--- A sheet of parchment between two rolls, w x h, with our cross at its top right. It can be dragged
--- anywhere, and Escape closes it before the window under it. Hidden: the caller writes on it first.
function GK.MakeSheet(name, w, h)
    local f = SheetFrame(name, w, h)
    local paper = f:CreateTexture(nil, "BACKGROUND")
    paper:SetAllPoints()
    paper:SetTexture(MEDIA .. "sheet")
    local top = GK.MakeRoll(f, 30)
    top:SetWidth(w + 16)
    top:SetPoint("BOTTOM", f, "TOP", 0, -15)
    local bottom = GK.MakeRoll(f, 30, true)
    bottom:SetWidth(w + 16)
    bottom:SetPoint("TOP", f, "BOTTOM", 0, 15)
    local close = GK.MakeCloseButton(f, 20, function() f:Hide() end, 14)
    close:SetPoint("TOPRIGHT", -12, -12)
    close:SetFrameLevel(f:GetFrameLevel() + 12)
    f:Hide()
    if LIB.RegisterPopup then LIB.RegisterPopup(f) else tinsert(UISpecialFrames, name) end
    return f
end

--- The head of a sheet: whom it is about. A face in the ring, a small caption over the name, and level,
--- race and class under it. head:Set(caption, t, red) with t = { key, c, r, rf, sx, l }; red: the
--- caption in blood (a kill order), else faded ink.
function GK.SheetHead(f, w)
    local width = w - 94 - 34                     -- from the face to the cross
    local h = { face = GK.MakePortrait(f, 56) }
    h.face.tex:SetPoint("CENTER", f, "TOPLEFT", 56, -54)
    h.caption = f:CreateFontString(nil, "ARTWORK")
    SheetInk(h.caption, FADED, TEXT_FONT, 10)
    h.caption:SetPoint("TOPLEFT", 94, -31)
    h.name = f:CreateFontString(nil, "ARTWORK")
    SheetInk(h.name, INK, TITLE_FONT, 20)
    h.name:SetPoint("TOPLEFT", h.caption, "BOTTOMLEFT", 0, -3)
    h.name:SetWidth(width)
    h.name:SetJustifyH("LEFT")
    h.name:SetWordWrap(false)
    h.info = f:CreateFontString(nil, "ARTWORK")
    SheetInk(h.info, FADED, TEXT_FONT, 11)
    h.info:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -3)
    h.info:SetWidth(width)
    h.info:SetJustifyH("LEFT")
    h.info:SetWordWrap(false)
    function h:Set(caption, t, red)
        self.caption:SetText(caption)
        SheetInk(self.caption, red and BLOOD or FADED, TEXT_FONT, 10)
        -- a long name steps down a size or two before the game cuts it short
        for _, size in ipairs({ 20, 17, 15 }) do
            SheetInk(self.name, INK, TITLE_FONT, size)
            self.name:SetText(GK.Show(t.key))
            if (self.name:GetStringWidth() or 0) <= width then break end
        end
        self.info:SetText(GK.Describe(t.l, t.c, t.r))
        self.face:Set(t)
    end
    return h
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

--- Cancel, in faded ink at the sheet's foot on the left: the quiet way out. Hides the sheet.
function GK.SheetCancel(f)
    local b = CreateFrame("Button", nil, f)
    b.text = b:CreateFontString(nil, "ARTWORK")
    SheetInk(b.text, FADED, TEXT_FONT, 12)
    b.text:SetPoint("LEFT")
    b.text:SetText(CANCEL or "Cancel")
    b:SetSize(math.ceil(b.text:GetStringWidth() or 50) + 4, 20)
    b:SetPoint("BOTTOMLEFT", 30, 31)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(INK[1], INK[2], INK[3]) end)
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(FADED[1], FADED[2], FADED[3]) end)
    b:SetScript("OnClick", function() f:Hide() end)
    return b
end

-- ---------------------------------------------------------------------------
-- The notes' sheets in the game's own frame: Blizzard's window (SettingsFrameTemplate, which Forever
-- draws in bronze, as our other addons' windows) on our plain parchment, with the game's own boxes,
-- radio buttons and buttons, and ink for the writing. The scroll suits a kill order; for the notes and
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

--- The note's paper, frame, plaque and portrait, at a look's size (LAYOUTS; A's if none): f.paper, f.blood,
--- and the portrait's parts (KeeperPortrait). Hidden and not yet registered as a window: the caller adds
--- its own writing first.
function GK.MakeNoteFrame(name, L)
    L = L or LAYOUTS.A
    local k = L.w / NW                              -- the frame is one picture: all of it in proportion
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(L.w, L.h)
    f:SetClampedToScreen(true)
    f:SetPoint("CENTER", 0, 120)
    f:EnableMouse(true)
    -- Paper under the iron-and-leather frame; the frame's bands cover the paper's edges. The frame's
    -- top band is about 12% of its height and its sides about 5% of its width (measured from
    -- letter_frame.tga), which is what the insets below keep clear of.
    local paper = f:CreateTexture(nil, "BACKGROUND")
    paper:SetPoint("TOPLEFT", 14 * k, -14 * k)
    paper:SetPoint("BOTTOMRIGHT", -14 * k, 14 * k)
    paper:SetTexture(MEDIA .. "letter_paper")
    f.paper = paper
    Blood(f, L.blood)
    local frame = CreateFrame("Frame", nil, f)
    frame:SetAllPoints()
    frame:SetFrameLevel(f:GetFrameLevel() + 8)
    local border = frame:CreateTexture(nil, "ARTWORK")
    border:SetAllPoints()
    border:SetTexture(MEDIA .. "letter_frame")
    -- Who it's from, on the plaque in the middle of the top band.
    local plaque = frame:CreateFontString(nil, "OVERLAY")
    GK.SetFont(plaque, TITLE_FONT, math.floor(14 * k + 0.5))
    plaque:SetTextColor(1, 0.82, 0.4)
    plaque:SetShadowOffset(1, -1)
    plaque:SetPoint("TOP", 0, -17 * k)
    plaque:SetText("The Grudgekeeper")
    KeeperPortrait(f, L.face, L.faceX, L.faceY)
    f:Hide()
    return f
end

--- P's loose sheet: the burnt parchment, torn at top and bottom (Media/letter_sheet, cut from the post sheet's
--- by art/make_grudgekeeper_letter_sheet.py), in three pieces so it grows to its words without stretching
--- its torn edges; the ledger's iron cross in its corner. As MakeNoteFrame: hidden, not yet registered.
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

local function BuildLetter(style)
    local L = LAYOUTS[style]
    local name = style == "A" and "GrudgekeeperLetter" or ("GrudgekeeperLetter" .. style)
    local f = L.frame and GK.MakeNoteFrame(name, L) or LetterSheet(name, L)
    f.style, f.layout = style, L
    -- where the writing starts, and how wide it runs: beside the face's column, or beside the face in the head
    local headX = L.column and L.textX or (L.faceX + L.face + 12)
    local headW = L.w - headX - L.right - (L.frame and 0 or 20)          -- the loose sheet's cross in the corner
    local textW = L.w - L.textX - L.right
    f.textW = textW
    -- An order's page: the face of whom it is about in the bronze ring, where his own portrait is on a note,
    -- and the bounty under it - the gold large, what it is under that; in the head a line under who they are.
    f.face = GK.MakePortrait(f, L.face)
    f.face.tex:SetPoint("CENTER", f.disc, "CENTER")
    f.gold = f:CreateFontString(nil, "ARTWORK")
    Ink(f.gold, INK, TITLE_FONT, 24)
    f.gold:SetPoint("TOP", f.disc, "BOTTOM", 0, -12)
    f.goldCap = f:CreateFontString(nil, "ARTWORK")
    Ink(f.goldCap, FADED, TEXT_FONT, 10)
    f.goldSub = f:CreateFontString(nil, "ARTWORK")
    Ink(f.goldSub, FADED, TEXT_FONT, 11)
    f.goldSub:SetPoint("TOP", f.goldCap, "BOTTOM", 0, -2)

    -- The writing, beside the face: the title, whom it is about, the words, and the letter's own buttons
    -- right under them.
    f.title = f:CreateFontString(nil, "ARTWORK")
    Ink(f.title, BLOOD, TITLE_FONT, L.title)
    f.title:SetPoint("TOPLEFT", headX, -L.headY)
    f.name = f:CreateFontString(nil, "ARTWORK")
    Ink(f.name, INK, TITLE_FONT, L.name)
    f.name:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, L.column and -8 or -4)
    f.name:SetWidth(headW)
    f.name:SetJustifyH("LEFT")
    f.name:SetWordWrap(false)
    f.info = f:CreateFontString(nil, "ARTWORK")
    Ink(f.info, FADED, TEXT_FONT, L.column and 12 or 11)
    f.info:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -3)
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
    f.stamp:SetSize(210 * L.w / NW, 105 * L.w / NW)    -- where: FillLetter, under the words
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

    -- The foot: a faint rule, Read all on the left, the pile in the middle, Close on the right. Close stays as
    -- well as the X: "X oppe i høyre funker ikke så bra" (the owner, 2026-11-07), and it was Later once, which
    -- kept the letter unread and brought the notice straight back ("burde være lukk isteden?", 2026-11-08).
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
    -- And the game's own X in the corner: our iron cross sat on top of the frame's iron corner and didn't go
    -- with it (2026-11-06). The loose sheet has no iron: there the cross is ours, as on the post sheet.
    if L.frame then
        f.x = GK.MakeGameCloseButton(f, function() GK.CloseLetters() end)
    else
        f.x = GK.MakeCloseButton(f, 20, function() GK.CloseLetters() end, 14)
        f.x:SetPoint("TOPRIGHT", -14, -14)
        f.x:SetFrameLevel(f:GetFrameLevel() + 12)
    end

    -- Arrives with a small drop and a fade, nothing more; turning to the next letter only turns the page.
    local arrive = f:CreateAnimationGroup()
    local drop = arrive:CreateAnimation("Translation")
    drop:SetOffset(0, -8)
    drop:SetDuration(0.18)
    drop:SetSmoothing("OUT")
    local fadeIn = arrive:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.18)
    f.arrive = arrive

    f:Hide()
    -- where the note stood, if it was moved: most letters were notes (each look its own place)
    if LIB.RegisterWindow then LIB.RegisterWindow(f, GK.db, L.key) end
    -- RegisterWindow owns OnShow/OnHide; ours only ever hooks.
    f:HookScript("OnHide", Closed)
    win = f
    wins[style] = f
end

--- One letter on the window: an order's page or a note, its buttons, its seal, the pile.
local function FillLetter(L)
    local f = win
    local lay = f.layout
    local d = GK.LetterContent(L)
    local order = not d.note
    -- "ORDER COMPLETE" fills the line at the size "KILL ORDER" wants
    Ink(f.title, BLOOD, TITLE_FONT, #d.title > 11 and lay.title - 4 or lay.title)
    f.title:SetText(d.title)

    -- the head: whom an order is about, and its bounty; on a note, the Grudgekeeper with their class on his
    -- shoulder
    f.name:SetShown(order)
    f.info:SetShown(order)
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
    f.gold:SetShown(lay.column and gold and true or false)
    f.goldCap:SetShown(b ~= nil)
    f.goldSub:SetShown(lay.column and b ~= nil)
    f.goldCap:ClearAllPoints()
    if order then
        f.face:SetShown(true)                       -- its ring as well: Set shows the face alone
        f.face:Set({ key = L.n, c = L.c, rf = L.rf, sx = L.sx })
        f.name:SetText(d.name or "")
        f.info:SetText(d.info or "")
    else
        f.face:SetShown(false)
    end
    if b and not lay.column then
        -- in the head: one line under who they are, the gold first
        Ink(f.goldCap, gold and INK or BLOOD, TEXT_FONT, 11)
        f.goldCap:SetPoint("TOPLEFT", f.info, "BOTTOMLEFT", 0, -3)
        f.goldCap:SetText(gold and (GK.Coins(b.copper) .. " bounty" .. ((b.from or 0) > 1
            and (" - from %d guildies"):format(b.from) or "")) or "No bounty - for the guild's honour")
    elseif gold then
        f.gold:SetText(GK.Coins(b.copper))
        Ink(f.goldCap, FADED, TEXT_FONT, 10)
        f.goldCap:SetText("BOUNTY")
        f.goldCap:SetPoint("TOP", f.disc, "BOTTOM", 0, -42)
        f.goldSub:SetText((b.from or 0) > 1 and ("from %d guildies"):format(b.from) or "")
    elseif b then
        -- an order with no gold: said where the gold would be, in the order's own words
        Ink(f.goldCap, BLOOD, TITLE_FONT, 13)
        f.goldCap:SetText("NO BOUNTY")
        f.goldCap:SetPoint("TOP", f.disc, "BOTTOM", 0, -14)
        f.goldSub:SetText("for the guild's honour")
    end

    -- the words, under the head, as many as the room above the buttons and the seal holds
    local top = lay.headY + (f.title:GetStringHeight() or lay.title)
    if lay.column and order then
        top = top + 8 + (f.name:GetStringHeight() or 20) + 3 + (f.info:GetStringHeight() or 12) + 10
    elseif lay.column then
        top = top + 12
    else
        -- the head beside the face, the words under whichever ends lower
        if order then
            top = top + 4 + (f.name:GetStringHeight() or lay.name) + 3 + (f.info:GetStringHeight() or 11)
                + (b and 3 + (f.goldCap:GetStringHeight() or 11) or 0)
        end
        top = math.max(top, lay.faceY + lay.face) + 10
    end
    f.body:ClearAllPoints()
    f.body:SetPoint("TOPLEFT", f, "TOPLEFT", lay.textX, -top)
    -- what the letter asks of you, and on an order the way to it in the ledger, which closes the letter: two
    -- windows on one order is one too many
    local specs = {}
    for _, spec in ipairs(d.buttons or {}) do specs[#specs + 1] = spec end
    if order and L.o then
        specs[#specs + 1] = { "Open in the ledger", function() GK.OpenOrder(L.o) end, away = true }
    end
    -- the room down to the seal over the signature: the loose sheet's most, which it grows to as it needs
    local buttonsH = #specs > 0 and (LETTER_BUTTON_H + BUTTON_GAP) or 0
    local room = (lay.maxH or lay.h) - lay.signY - lay.sealRoom - 6 - buttonsH - top
    FitBody(f.body, d.lines, d.give, room)
    if lay.maxH then
        local h = top + (f.body:GetStringHeight() or 0) + buttonsH + 6 + lay.sealRoom + lay.signY
        f:SetHeight(math.max(lay.h, math.min(lay.maxH, math.ceil(h))))
    end
    -- a stamp under the words: in the writing's column, or across the letter under the head
    f.stamp:ClearAllPoints()
    if lay.column then
        f.stamp:SetPoint("CENTER", f, "TOPLEFT", lay.textX + f.textW / 2, -170)
    else
        f.stamp:SetPoint("CENTER", f, "TOPLEFT", lay.w / 2, -(top + 40))
    end
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
                if spec.away then
                    f:Hide()
                    spec[2]()
                    return
                end
                spec[2]()
                if f:IsShown() and GK.char.letters[index] == L then FillLetter(L) end
            end)
        end
    end

    -- the signature and the seal; blood on a death; the stamp waits for the letter to be shown (GK.ShowLetter)
    local k = lay.sealRoom / 38                       -- the seal in proportion to the room kept for it
    if order then
        Ink(f.sign, FADED, TEXT_FONT, lay.column and 12 or 11)
        f.sign:SetText(d.foot or "")
        f.seal:SetSize(38 * k, 38 * k)
    else
        Ink(f.sign, INK, TITLE_FONT, lay.column and 16 or 14)
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
    index = math.max(1, math.min(i or #list, #list))
    local L = list[index]
    L.read = true
    reading = true
    holding[L] = nil                                -- read before its minute was up: nothing left to land
    GK.Sound("IG_ABILITY_PAGE_TURN")
    -- the window of the look in use (GK.SetLetterStyle); another look's goes
    local style = LetterStyle()
    if win and win ~= wins[style] and win:IsShown() then win:Hide() end
    if wins[style] then win = wins[style] else BuildLetter(style) end
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

--- The look letters open in (LAYOUTS: "A" today's, "F" the small frame, "P" the loose sheet), for the test
--- panel while the owner compares them; what is open turns to it at once.
function GK.SetLetterStyle(style)
    GK.db.letterStyle = (LAYOUTS[style] and style ~= "A") and style or nil
    if win and win:IsShown() and index then GK.ShowLetter(index) end
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
        if L and win and win:IsShown() then FillLetter(L) end
    end)
end
