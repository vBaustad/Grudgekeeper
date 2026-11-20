-- Grudgekeeper - profiles: what the guild knows about one player, as a card the ledger draws on its right
-- page (Window.lua) and the Inspect tab on its own. Two kinds:
--   a guildie's RECORD   title and points, kills and deaths this week and all time, place on the board,
--                        kill streak, kill orders fulfilled and the bounties on them, nemesis, and the
--                        latest the news has on them
--   a WANTED poster      an enemy player: how often they killed us and whom, how often we got them,
--                        your own score with them, where they were last seen, the order and its pot
-- It opens from the game's right-click menu on a player (the target frame, party and raid frames, a
-- name in chat, the guild roster), from a name in the window and from a pin on the world map - each of
-- them the ledger open on that player (GK.ShowInLedger). Like every window here, it never opens by itself.
-- Everything on a card is what this client has heard: a guildie who never runs Grudgekeeper has no
-- record, and kills made while you were offline count once the killer's next kill tells their total.
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

local LABEL = "Grudgekeeper profile"
local NAMES = 3                  -- names on a line before "and 2 more"
local QUIET_FOR = 7 * GK.DAY     -- a guildie not heard from in this long: the card says when they were

local function Plural(n, word) return ("%d %s%s"):format(n, word, n == 1 and "" or "s") end

local function Who(key)
    if LIB.IsMyStoredName(key) then return "you" end
    return GK.Show(key)
end

--- The record in t under this player's name: the exact key, else the same name written another way
--- (GK.SameName - another realm spelling, a surname one side left off). Only ever asked from a click,
--- so a walk over a few hundred names is fine; nothing that runs per event comes through here.
local function Find(t, key)
    if not (t and type(key) == "string") then return nil end
    if t[key] then return t[key], key end
    for k, v in pairs(t) do
        if GK.SameName(k, key) then return v, k end
    end
    return nil
end

--- "once", "twice", "3 times".
local function Times(n) return n == 1 and "once" or n == 2 and "twice" or (n .. " times") end

--- A count beside a name: "once", "twice", "3x" (with the times sign).
local function Count(n) return n == 1 and "once" or n == 2 and "twice" or (n .. "\195\151") end

--- "Vebjørn 5, Kari 4 and 3 more" from { [who] = count }, the most first; the sum of the counts (yours
--- too); and how many names it has. count: how a count is written after the name (Count), else as a
--- plain number. notMe: leave yourself out of the names, where a line of your own already says yours.
local function Names(map, count, notMe)
    local list, total = {}, 0
    for who, n in pairs(map) do
        if not (notMe and LIB.IsMyStoredName(who)) then list[#list + 1] = { who = who, n = n } end
        total = total + n
    end
    table.sort(list, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.who < b.who
    end)
    local parts = {}
    for i = 1, math.min(NAMES, #list) do
        parts[i] = ("%s %s"):format(Who(list[i].who), count and count(list[i].n) or tostring(list[i].n))
    end
    local text = table.concat(parts, ", ")
    if #list > NAMES then text = text .. (" and %d more"):format(#list - NAMES) end
    return text, total, #list
end

--- How long ago, short, for a number on the card: "now", "12 min", "5 h", "3 d".
local function Since(t)
    local s = time() - (t or 0)
    if s < 90 then return "now" end
    if s < 3600 then return math.floor(s / 60) .. " min" end
    if s < 2 * GK.DAY then return math.floor(s / 3600) .. " h" end
    return math.floor(s / GK.DAY) .. " d"
end

--- The same, as the line under a number: "just now", "12 min ago", "3 d ago".
local function SinceAgo(t)
    local s = Since(t)
    return s == "now" and "just now" or (s .. " ago")
end

--- How long until: "in 5 days", "in 3 h", "within the hour".
local function Until(t)
    local s = (t or 0) - time()
    if s < 3600 then return "within the hour" end
    if s < 2 * GK.DAY then return ("in %d h"):format(math.floor(s / 3600)) end
    return ("in %d days"):format(math.floor(s / GK.DAY))
end

--- "Kari, Lars and you": a list of names, the last joined with "and", at most NAMES and "2 more".
local function AndList(names)
    local shown = {}
    for i = 1, math.min(NAMES, #names) do shown[i] = names[i] end
    if #names > NAMES then shown[#shown + 1] = ("%d more"):format(#names - NAMES) end
    if #shown < 2 then return shown[1] or "" end
    return table.concat(shown, ", ", 1, #shown - 1) .. " and " .. shown[#shown]
end

local function Upper(s) return GK.UpperFirst(s) end      -- a name's first letter in any alphabet (Core.lua)

--- What a tile counts, said for one or for more: "1 DEATH", "3 DEATHS".
local function Counted(n, word) return n == 1 and word or (word .. "s") end

--- Our guild's name, for the line under an enemy's kills and deaths; "us" without one, or while the
--- client can't say.
local function OurGuild()
    if GK.shotGuild then return GK.shotGuild end        -- the screenshot mode's made-up guild (Shots.lua)
    local name = GetGuildInfo and GetGuildInfo("player")
    if type(name) == "string" and name ~= "" and not GK.Secret(name) then return name end
    return "us"
end

--- Where and when an enemy was last seen, from the best we have: a guildie's sighting of an order's
--- target, our own look in the last 15 minutes, or the guild's news of a kill on either side (which
--- says where). { t = time(), z } or nil.
local function LastSeen(key, o, live)
    local best
    local function Take(t, z)
        if t and (not best or t > best.t) then best = { t = t, z = z } end
    end
    if o and o.seen and o.seen.t then Take(o.seen.t, o.seen.z) end
    if live and live.t and GetTime then Take(time() - math.floor(GetTime() - live.t), live.z) end
    for _, e in ipairs(GK.Store().feed) do
        if (e.kind == "K" or e.kind == "H" or e.kind == "D") and e.n and (e.n == key or GK.SameName(e.n, key)) then
            Take(e.t, e.z)
            break                                   -- the feed is newest first
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- What a card says. Plain data, so the smoke test can read it without a frame:
-- { title, name, info, lines, big, caption, seal, blood, buttons = { { text, fn } }, c, unit, key, rich }
-- title, name, info, lines, big and caption are the card as a page without room for rich draws it (the
-- Inspect tab; a note's card, which has no rich): a line that starts "Label: " is a label and its value
-- there, in two columns.
-- rich is the same card for a page with room for it, the ledger's (Window.lua, FillRich), as previewed
-- with the owner (2026-11-06): every number in a tile with a name and a line that says something, then
-- sections of facts.
--   { kicker, head, sub, info, seal, sealNum, tiles = { { value, label, under, under2 } },
--     bar = { frac, left, right }, sections = { { head, kind, rows } } }
--   kicker: the small red line over the name ("WANTED", "#1 THIS WEEK"); head: the name; sub: under it.
--   kind "facts": rows { label, value, more } (no label: a paragraph; more: a grey word after the
--   value); "events": { c, text, under, right }, each with their class's crest.
-- ---------------------------------------------------------------------------

-- Who put what in a pot. The bounty tile said "from 2 guildies" and no more ("se hvem som har lagt til i
-- potten", the owner, 2026-11-07): the card says it in a section of its own rather than behind a button,
-- since a card has the room and nobody has to know to click.
local MAX_POT_ROWS = 4

--- An order's pot as rows for a card's facts, the most first: { amount, who, a grey word }. The poster's
--- reward is theirs and says so; on a fulfilled order each share says whether it is paid. More givers
--- than MAX_POT_ROWS end on one row for the rest. nil when nobody but the poster put gold in: the bounty
--- tile and Posted by say all there is then.
function GK.PotRows(o)
    if not (o and o.pot and next(o.pot)) then return nil end
    local givers = {}
    if (o.reward or 0) > 0 then givers[1] = { who = o.by, copper = o.reward, poster = true } end
    for who, copper in pairs(o.pot) do givers[#givers + 1] = { who = who, copper = copper } end
    table.sort(givers, function(a, b)
        if a.copper ~= b.copper then return a.copper > b.copper end
        return a.who < b.who
    end)
    local owed = o.state == "d" or o.state == "p"
    local rows = {}
    local shown = #givers <= MAX_POT_ROWS and #givers or MAX_POT_ROWS - 1
    for i = 1, shown do
        local g = givers[i]
        local note = g.poster and "posted it" or nil
        if owed then
            -- each giver pays each hunter a part (GK.Part): paid, part of it, or none yet
            local due, paid = 0, 0
            for _, h in ipairs(GK.Hunters(o)) do
                if h ~= g.who then
                    due = due + 1
                    if GK.IsPaid(o, g.who, h) then paid = paid + 1 end
                end
            end
            if due == 0 then
                note = g.poster and "posted it" or nil
            elseif paid >= due then
                note = "paid"
            else
                note = paid > 0 and ("paid %d of %d"):format(paid, due) or "not paid yet"
            end
        end
        rows[#rows + 1] = { GK.Coins(g.copper), Upper(Who(g.who)), note }
    end
    if shown < #givers then
        local rest = 0
        for i = shown + 1, #givers do rest = rest + givers[i].copper end
        rows[#rows + 1] = { GK.Coins(rest), Plural(#givers - shown, "other") }
    end
    return rows
end

-- Forget grudge, readied by a first click: whose, and until when (GetTime()).
local FORGET_ARMED_FOR = 5
local forgetArmed, forgetUntil = nil, 0

--- An enemy player. t = { key, guid, c, r, l, unit }: whatever the caller knows. inLedger: drawn on
--- the ledger's own page (Window.lua), where your own order's button withdraws it rather than
--- opening the hitlist you are already looking at.
function GK.PosterCard(t, inLedger)
    local key, guid = t.key, t.guid
    local s = GK.Store()
    local w = Find(s.wanted, key)
    local e = Find(s.slain, key)
    local f, fkey = Find(GK.char.foes, key)
    local o = GK.OrderOn(key, guid)
    local live = GK.Seen(key, guid)
    local function Pick(field)
        return t[field] or (live and live[field]) or (o and o[field]) or (f and f[field]) or (e and e[field])
            or (w and w[field])
    end
    -- Their level is the highest anyone has it at: a level only goes up, and the caller's is from when its
    -- row was made - an order's posting, their last kill on us (GK.HigherLevel, Guild.lua).
    local c, r, l = Pick("c"), Pick("r"), t.l
    for _, known in ipairs({ live or false, o or false, f or false, e or false, w or false }) do
        if known then l = GK.HigherLevel(l, known.l) end
    end
    -- Their race's face, from race and sex seen or kept (GK.FaceOf), under whichever spelling we have
    -- them by - the card may be asked for a name alone.
    local function Known(k) return k and GK.FaceOf(k).rf and k or nil end
    local faceKey = Known(key) or Known(fkey) or Known(o and o.n) or key
    local look = GK.FaceOf(faceKey, c)
    local d = { key = key, unit = t.unit, c = c, name = GK.Show(key), info = GK.Describe(l, c, r), lines = {},
        buttons = {}, rf = look.rf, sx = look.sx, faceKey = faceKey }
    local rich = { head = d.name, info = d.info, tiles = {}, sections = {} }
    d.rich = rich
    local lines = d.lines
    local killedUs, weKilled = 0, 0
    local history = {}             -- the rich card's History: you, then whom they killed, then who got them
    local nemesis = f ~= nil and fkey ~= nil and GK.Nemesis() == fkey
    if f and (f.k or 0) + (f.d or 0) + (f.a or 0) > 0 then
        local said = {}
        if (f.k or 0) > 0 then said[#said + 1] = "killed them " .. Times(f.k) end
        if (f.a or 0) > 0 then said[#said + 1] = "helped kill them " .. Times(f.a) end
        if (f.d or 0) > 0 then said[#said + 1] = "died to them " .. Times(f.d) end
        history[1] = { "You", table.concat(said, ", ") }
    end
    -- With a You row, the guild's lists name only the others: "You: killed them once" over "Killed by:
    -- you once" said the same thing twice (the owner, 2026-11-06). A list left empty goes.
    local youSaid = history[1] ~= nil
    if w and next(w.victims) then
        local names, total = Names(w.victims)
        killedUs = total
        lines[#lines + 1] = ("Killed us: %s - %s."):format(Plural(total, "time"), names)
        local others, _, n = Names(w.victims, Count, youSaid)
        if n > 0 then history[#history + 1] = { "They killed", others } end
    end
    if e and next(e.by) then
        local names, total = Names(e.by)
        weKilled = total
        lines[#lines + 1] = ("We killed them: %s - %s."):format(Plural(total, "time"), names)
        local others, _, n = Names(e.by, Count, youSaid)
        if n > 0 then history[#history + 1] = { "Killed by", others } end
    end
    if f and (f.k or 0) + (f.d or 0) + (f.a or 0) > 0 then
        lines[#lines + 1] = ("You: %s, %s%s%s"):format(Plural(f.k or 0, "kill"),
            Plural(f.a or 0, "assist") .. ", ", Plural(f.d or 0, "death"),
            nemesis and " - your nemesis." or ".")
    end
    -- The rich card's numbers are THEIR score against the guild, read as a scoreboard: "7 KILLS on
    -- YippYapp", "3 DEATHS by YippYapp", and under it when the last was. Named from our side - "7 KILLED
    -- US", "3 WE KILLED" - the number read as the start of a sentence; "to us" became the guild's name
    -- (the owner, 2026-11-06). The guild on a line of its own, so a long name is cut, never the time.
    rich.sub = nemesis and "Your nemesis" or nil
    local guild = OurGuild()
    local kills = { tostring(killedUs), Counted(killedUs, "Kill"), "on " .. guild }
    if killedUs > 0 and w.last then kills[4] = SinceAgo(w.last) end
    local deaths = { tostring(weKilled), Counted(weKilled, "Death"), "by " .. guild }
    if weKilled > 0 and e.last then deaths[4] = SinceAgo(e.last) end
    local spotted = LastSeen(key, o, live)
    local seenTile = spotted and { Since(spotted.t), "Last seen", spotted.z or "" } or { "-", "Last seen", "not lately" }
    -- Last seen: anyone in the guild, through the order; else our own look in the last 15 minutes.
    local seen = o and o.seen
    if seen and seen.t then
        lines[#lines + 1] = ("Last seen: %s, %s, by %s."):format(seen.z or "the world", GK.Ago(seen.t), Who(seen.by))
    elseif live then
        lines[#lines + 1] = ("Last seen: by you, lately, in %s."):format(live.z or "the world")
    end
    local me = LIB.Me()
    if o then
        local pot, backers = GK.Pot(o)
        local extra = {}
        if backers > 0 then extra[#extra + 1] = Plural(backers, "backer") end
        local tail = #extra > 0 and (" - " .. table.concat(extra, ", ")) or ""
        -- An order their own killing posted (GK.AutoOrder) says why, in the Grudgekeeper's words, and
        -- was posted by a death rather than by a guildie's hand. One a guildie posted says the why they
        -- wrote, if they wrote one.
        local by = Who(o.by)
        if o.auto then
            by = (by == "you" and "your" or (by .. "'s")) .. " death"
            -- A to Z only: %u follows the locale, and under Latin-1 it takes the lead byte of a Cyrillic letter
            local why = o.note and (o.note:gsub("^[A-Z]", string.lower)) or nil
            lines[#lines + 1] = why and ("The guild wants them dead: %s"):format(why) or "The guild wants them dead."
        elseif o.note and o.note ~= "" then
            lines[#lines + 1] = ("Why: %s"):format(o.note)
        end
        if pot > 0 then
            lines[#lines + 1] = ("Posted by: %s - a bounty of %s%s."):format(by, GK.MoneyText(pot), tail)
            d.big = pot >= 10000 and (math.floor(pot / 10000) .. "g") or GK.MoneyText(pot)
            d.caption = "bounty"
        else
            lines[#lines + 1] = ("Posted by: %s - for the guild's honour%s."):format(by, tail)
        end
        -- The rich card: the bounty and how many put gold in it, then the order itself - who posted it and
        -- when, why, when it runs out. Nobody takes an order, so nobody is listed as hunting them: any
        -- guildie's kill fulfils it, and "Hunting: nobody yet" read as a sign-up it was waiting for ("jeg
        -- vil ikke at noen skal ta ordre", the owner, 2026-11-07).
        local givers = backers + ((o.reward or 0) > 0 and 1 or 0)
        -- "None" over BOUNTY for an order with no gold: it said "honour", a word the owner did not want for
        -- it (2026-11-14), and "No bounty" is wider than the tile, a quarter of the card
        rich.tiles[1] = { pot > 0 and GK.Coins(pot) or "None", "Bounty",
            givers > 0 and ("from %d guildie%s"):format(givers, givers == 1 and "" or "s") or "no gold on it" }
        local order = { { "Posted by", ("%s, %s"):format(Upper(by), GK.Ago(o.t)) } }
        -- they have levelled since: what the order said when posted, where we knew it (GK.OrderLevel)
        if o.was and o.l and o.l > o.was then
            order[#order + 1] = { "Level", ("%d when posted, seen at %d since"):format(o.was, o.l) }
        end
        if o.note and o.note ~= "" then order[#order + 1] = { "Why", o.note } end
        if o.exp then order[#order + 1] = { "Runs out", Until(o.exp) } end
        rich.sections[1] = { head = "The order", kind = "facts", rows = order }
        local potRows = GK.PotRows(o)
        if potRows then rich.sections[2] = { head = "The pot", kind = "facts", rows = potRows } end
        if o.by ~= me then
            d.buttons[1] = { (o.pot and me and o.pot[me]) and "Your share" or "Add to the pot", function()
                GK.OpenPost({ key = o.n, guid = o.guid, c = o.c, r = o.r, l = o.l })
            end }
        elseif inLedger then
            d.buttons[1] = { "Withdraw", function() GK.Withdraw(o) end }
        else
            d.buttons[1] = { "Kill orders", function() GK.OpenWindow(1) end }   -- named as the tab it opens
        end
    else
        d.buttons[1] = { "Post a kill order", function()
            GK.OpenPost({ key = key, guid = guid, c = c, r = r, l = l })
        end }
    end
    -- The second button, beside the kill order's (two fit): Stop tracking for one you track (Sightings.lua);
    -- else Forget grudge for a grudge of yours; else Track. Track someone you have a grudge with from the
    -- top of your Grudges or the right-click menu.
    -- A grudge of yours can be forgotten (GK.ForgetGrudge, Guild.lua): a wrong one stayed for good before.
    -- It asks twice - the first click readies it for a few seconds and the button says so.
    if GK.IsTracked and GK.IsTracked(key) then
        d.buttons[#d.buttons + 1] = { "Stop tracking", function() GK.Untrack(key) end }
    elseif f and fkey and (f.k or 0) + (f.d or 0) + (f.a or 0) > 0 then
        local armed = forgetArmed == fkey and GetTime() < forgetUntil
        d.buttons[#d.buttons + 1] = { armed and "Really forget?" or "Forget grudge", function()
            if forgetArmed == fkey and GetTime() < forgetUntil then
                forgetArmed = nil
                GK.ForgetGrudge(fkey)
                return
            end
            forgetArmed, forgetUntil = fkey, GetTime() + FORGET_ARMED_FOR
            C_Timer.After(FORGET_ARMED_FOR + 0.1, GK.Changed)        -- back to Forget grudge
            GK.Changed()
        end }
    elseif GK.TrackSaying then
        d.buttons[#d.buttons + 1] = { "Track", function() GK.TrackSaying({ key = key, c = c, r = r, l = l }) end }
    end
    if not d.big and killedUs > 0 then d.big, d.caption = tostring(killedUs), "killed us" end
    if o then
        d.title, d.seal = "WANTED", "mark"
    elseif #history > 0 then
        d.title, d.seal = "A GRUDGE", "seal_black"
    else
        d.title = "NO RECORD"
        lines[#lines + 1] = "Nobody in the guild has killed them or died to them - not that the Grudgekeeper heard of."
        history[1] = { nil, lines[#lines] }
    end
    rich.kicker, rich.seal = d.title, d.seal
    rich.tiles[#rich.tiles + 1] = kills
    rich.tiles[#rich.tiles + 1] = deaths
    rich.tiles[#rich.tiles + 1] = seenTile
    rich.sections[#rich.sections + 1] = { head = "History", kind = "facts", rows = history }
    d.blood = f ~= nil and (f.d or 0) > 0       -- they have killed you
    return d
end

-- What a guildie did, as the rich card's Lately says it; the right-hand column is what it was worth.
local DID = { K = "Killed %s", H = "Helped kill %s", D = "Fell to %s", F = "Fulfilled the kill order on %s", C = "Put a price on %s",
    T = "Added to the pot on %s" }

--- The last few things the news says a guildie did, newest first: { c, text, under, right }.
local function Lately(key, me, most)
    local out = {}
    for _, e in ipairs(GK.Store().feed) do
        if #out >= most then break end
        -- an own order's target got by its poster closed it; on the card it is the kill, not a fulfilment
        if DID[e.kind] and not (e.kind == "F" and e.own) and (e.who == key or (me and LIB.IsMyStoredName(e.who))) then
            local right
            if e.kind == "K" or e.kind == "H" then
                right = (e.p or 0) > 0 and ("+%d"):format(e.p) or nil
            elseif e.kind == "C" then
                right = (e.p or 0) > 0 and GK.Coins(e.p) or nil
            elseif e.kind == "T" then
                right = (e.p or 0) > 0 and GK.Coins(e.p) or nil
            end
            out[#out + 1] = { c = e.c, text = DID[e.kind]:format(GK.Show(e.n)),
                under = (e.z and (e.z .. " \194\183 ") or "") .. GK.Ago(e.t), right = right }
        end
    end
    return out
end

--- How far a score is on its way to the next title: { frac, left = this title, right = what is left }.
local function Progress(p)
    local at = 1
    for i, row in ipairs(GK.TITLES) do
        if p >= row[1] then at = i end
    end
    local now, after = GK.TITLES[at], GK.TITLES[at + 1]
    if not after then return { frac = 1, left = now[2], right = "the highest title" } end
    return { frac = (p - now[1]) / (after[1] - now[1]), left = now[2],
        right = ("%s to %s"):format(Plural(after[1] - p, "point"), after[2]) }
end

--- The latest the news says about a guildie: one line, or nil.
local function Latest(key, me)
    for _, e in ipairs(GK.Store().feed) do
        if (e.who == key or (me and LIB.IsMyStoredName(e.who))) and not (e.kind == "F" and e.own) then
            local target = GK.Show(e.n)
            local when = GK.Ago(e.t)
            if e.kind == "K" then
                return ("Lately: killed %s%s, %s."):format(target, (e.p or 0) > 0 and (" (+%d)"):format(e.p) or "", when)
            elseif e.kind == "H" then
                return ("Lately: helped kill %s%s, %s."):format(target, (e.p or 0) > 0 and (" (+%d)"):format(e.p) or "", when)
            elseif e.kind == "D" then
                return ("Lately: fell to %s, %s."):format(target, when)
            elseif e.kind == "F" then
                return ("Lately: fulfilled the kill order on %s, %s."):format(target, when)
            elseif e.kind == "C" then
                return ("Lately: put a price on %s, %s."):format(target, when)
            end
        end
    end
    return nil
end

--- A guildie, or you: their record as they last sent it (B). nil when we have none.
function GK.RecordCard(key, unit)
    local me = LIB.IsMyStoredName(key)
    local r
    if me then
        local c, w = GK.char, GK.Week()
        local nemesis, nf = GK.Nemesis()
        local _, class = UnitClass("player")
        local _, raceFile = UnitRace("player")
        r = { p = c.points, k = c.kills, d = c.deaths, wp = w.p, wk = w.k, wd = w.d, wid = w.id,
            st = c.streak, bs = c.bestStreak, od = c.done, ow = c.won, nm = nemesis, nt = nf and nf.d,
            c = class, l = UnitLevel("player"), t = time(), rf = raceFile, sx = UnitSex("player"),
            a = c.assists or 0, wa = w.a or 0 }
        key = LIB.Me() or key
    else
        r, key = Find(GK.Store().board, key)
        if not r then return nil end
    end
    local p = r.p or 0
    local d = { key = key, unit = unit, c = r.c, rf = r.rf, sx = r.sx, title = GK.Show(key),
        name = GK.Title(p), lines = {}, buttons = {},   -- the points are the big number, not said twice
        big = tostring(p), caption = p == 1 and "point" or "points" }
    -- place on the board: all time, and this week if they are on this week's
    local function Place(weekly)
        local list = GK.Board(weekly)
        for i, e in ipairs(list) do
            if (me and e.me) or (not me and e.who == key) then return i, #list end
        end
        return nil
    end
    -- Both counts say what they count: all time is everyone whose score reached us, this week only who
    -- has a kill, death or point this week - the leaderboard's default list. "#1 of 4 in the guild, #1
    -- this week" read as four on a list that showed one (the owner, 2026-11-06).
    local rank, of = Place(false)
    local weekRank, weekOf = Place(true)
    local where = GK.Describe(r.l, r.c)
    if rank and of > 1 then
        where = ("#%d of %d all time%s"):format(rank, of,
            weekRank and (", #%d of %d this week"):format(weekRank, weekOf) or "")
    end
    d.info = where
    local lines = d.lines
    -- assists from a client that sends them, 0 included; the released one sends none, and then nothing is said
    local function Assists(n) return n and (Plural(n, "assist") .. ", ") or "" end
    lines[#lines + 1] = ("All time: %s, %s%s."):format(Plural(r.k or 0, "kill"), Assists(r.a), Plural(r.d or 0, "death"))
    local thisWeek = r.wid == GK.WeekId()
    if thisWeek and ((r.wk or 0) + (r.wd or 0) + (r.wp or 0) + (r.wa or 0)) > 0 then
        lines[#lines + 1] = ("This week: %s, %s%s, %s."):format(Plural(r.wk or 0, "kill"), Assists(r.wa),
            Plural(r.wd or 0, "death"), Plural(r.wp or 0, "point"))
    else
        lines[#lines + 1] = "Nothing yet this week."
    end
    -- The rich card (the ledger): the all-time numbers in tiles, this week's under each; the place on
    -- the board with what it counts; the way to the next title; the highlights; and the news of them.
    -- The kicker is this week's place, the list the leaderboard opens on.
    local function Week(n) return thisWeek and (n or 0) > 0 and ("%d this week"):format(n) or "none this week" end
    local wp = thisWeek and (r.wp or 0) or 0
    local info = GK.Describe(r.l, r.c)
    if not me and r.t and time() - r.t > QUIET_FOR then info = info .. " \194\183 last heard " .. GK.Ago(r.t) end
    local streak, best = r.st or 0, math.max(r.bs or 0, r.st or 0)
    local rich = { head = d.title, sub = d.name, info = info,
        kicker = (weekRank and ("#%d this week"):format(weekRank)) or (rank and ("#%d all time"):format(rank)) or nil,
        seal = weekRank and weekRank <= 3 and wp > 0 and ("rank_" .. weekRank) or nil,
        tiles = {
            { tostring(p), Counted(p, "Point"), Week(r.wp) },
            { tostring(r.k or 0), Counted(r.k or 0, "Kill"), Week(r.wk) },
            { tostring(r.d or 0), Counted(r.d or 0, "Death"), Week(r.wd) },
            { rank and ("#" .. rank) or "-", "Place", rank and ("of %d all time"):format(of) or "" } },
        bar = Progress(p), sections = {} }
    rich.sealNum = rich.seal and tostring(weekRank) or nil
    -- Only the highlights there are: four rows of "none yet" and "nobody yet" were most of the card for a
    -- new player, and made the rest hard to find (the owner, 2026-11-06). The bounties go with the orders
    -- they were won on.
    local highlights = {}
    if r.a then highlights[#highlights + 1] = { "Assists", tostring(r.a), Week(r.wa) } end
    if best > 0 then
        highlights[#highlights + 1] = { "Kill streak", tostring(streak),
            best > streak and ("best ever %d"):format(best) or (me and "your best yet" or "their best yet") }
    end
    if r.nm then
        highlights[#highlights + 1] = { "Nemesis", GK.Show(r.nm),
            r.nt and ("has killed %s %s"):format(me and "you" or "them", Times(r.nt)) or nil }
    end
    if (r.od or 0) > 0 then
        highlights[#highlights + 1] = { "Orders fulfilled", tostring(r.od),
            (r.ow or 0) > 0 and (GK.Coins(r.ow) .. " in bounties") or nil }
    end
    if #highlights > 0 then rich.sections[1] = { head = "Highlights", kind = "facts", rows = highlights } end
    local news = Lately(key, me, 3)
    if #news > 0 then rich.sections[#rich.sections + 1] = { head = "Lately", kind = "events", rows = news } end
    d.rich = rich
    if (r.bs or 0) > 0 then
        lines[#lines + 1] = ("Kill streak: %d now, best %d."):format(r.st or 0, r.bs)
    end
    if (r.od or 0) > 0 then
        lines[#lines + 1] = ("Kill orders fulfilled: %d%s."):format(r.od,
            (r.ow or 0) > 0 and (", for %s in bounties"):format(GK.MoneyText(r.ow)) or "")
    end
    if r.nm then
        lines[#lines + 1] = r.nt and ("Nemesis: %s, who has killed %s %s."):format(GK.Show(r.nm), me and "you" or "them",
            Plural(r.nt, "time")) or ("Nemesis: %s."):format(GK.Show(r.nm))
    end
    local latest = Latest(key, me)
    if latest then lines[#lines + 1] = latest end
    if not me and r.t and time() - r.t > QUIET_FOR then
        lines[#lines + 1] = ("Last heard from %s."):format(GK.Ago(r.t))
    end
    d.buttons[1] = { "Leaderboard", function() GK.OpenWindow(2) end }
    return d
end

--- Is there a record to show for this friendly player: you, or a guildie on the board.
function GK.HasRecord(key)
    if type(key) ~= "string" then return false end
    return LIB.IsMyStoredName(key) or Find(GK.Store().board, key) ~= nil
end

-- ---------------------------------------------------------------------------
-- The card: on the ledger's right page
-- ---------------------------------------------------------------------------
-- These opened a small card of their own, in a note's frame, with less on it than the ledger's page and
-- the Inspect tab drew from the same card tables ("den 'profil' ved høyreklikk er jo bare message
-- boksen", the owner, 2026-11-16). Now each opens the ledger on that player (GK.ShowInLedger, Window.lua).

--- The wanted poster for an enemy player. t = { key, guid, c, r, l, unit }.
function GK.ShowPoster(t)
    if not (t and t.key) then return end
    GK.ShowInLedger({ kind = "poster", t = t })
end

--- A guildie's record (or yours). unit: the unit it was opened from, if any.
function GK.ShowRecord(key, unit)
    if type(key) ~= "string" then return end
    GK.ShowInLedger({ kind = "record", key = key, unit = unit })
end

--- Any other card, for a file that builds its own: make() returns a card table (see above) and is called
--- again whenever the page refills; key: whose card it is, so the ledger opens on their row where a page
--- has one (GK.NotesItems' rows say theirs). Nothing opens if make() has nothing to show.
function GK.ShowCard(make, key)
    GK.ShowInLedger({ kind = "card", make = make, key = key })
end

-- ---------------------------------------------------------------------------
-- The game's right-click menu on a player
-- ---------------------------------------------------------------------------
-- Menu.ModifyMenu is how the game lets addons add to its menus: our part runs after Blizzard's own
-- entries are built, and adds its lines at the end. Nothing of Blizzard's is replaced or wrapped.
-- An enemy player gets the poster, the kill order on them and Track, and an officer their guild on watch:
-- the only lines of ours on an enemy, since Shame and Kudos are a friendly player's (NotesUI.lua, 2026-11-20).
-- A friendly player gets the record line only when there is a record: you, or a guildie on the board.
local FRIENDLY = { "SELF", "PLAYER", "PARTY", "RAID_PLAYER", "RAID", "FRIEND", "COMMUNITIES_GUILD_MEMBER", "GUILD" }

--- A name from the menu's context: a plain string the client lets us read, or nil.
local function Text(v)
    if type(v) ~= "string" or GK.Secret(v) or v == "" then return nil end
    return v
end

local function AddLine(root, label, fn, also, alsoFn)
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton(label, fn)
    if also then root:CreateButton(also, alsoFn) end
end

-- ---------------------------------------------------------------------------
-- Asking a player outside the guild for their score (2026-11-20)
-- ---------------------------------------------------------------------------
-- A guildie's score reaches us on the guild's channel. A player on your side outside it is asked, one at a time,
-- when you open their profile or inspect them, and only they can answer: "melding mellom de som ikke er i guild
-- må være spesifikk så en inspect sender forespørsel og kun den du inspecter kan svare" (the owner). It goes on
-- a channel of its own, straight through the client: LibForever's comms read no whisper from outside the guild,
-- and send only from inside one. An ask is a whisper to that player with a number of ours (the nonce), and the
-- answer counts only when it comes from them, with that number, within ANSWER_WAIT. What they answer is shown
-- and kept in memory alone: not on the board, never passed on. An enemy is never asked (no addon message crosses
-- factions), nor a guildie (their score is on the board).
--   A;1;nonce                                           the ask
--   R;1;nonce;points;kills;deaths;assists;best streak   the answer
local PROFILE_PREFIX = "GKProfile"
local ASK_GAP = 60            -- the same player asked once a minute at most, however often their profile opens
local ANSWER_WAIT = 10        -- an answer counts this long after the ask
local MAX_ANSWERS = 5         -- answers we give in a minute, to anyone: the asks past them go unanswered
local MAX_KEPT = 100          -- players asked, answered or answering, kept at most (in memory)
local asked, heard = {}, {}   -- [key] = { nonce, t }; [key] = { p, k, d, a, bs, t }
local answers, answeredTo = {}, {}   -- when we answered this past minute; [key] = when we last answered them

--- Forget the oldest entry of t once it holds more than MAX_KEPT. An entry is a time, or a table with one (t).
local function Prune(t)
    local n, oldest, at = 0, nil, nil
    for k, v in pairs(t) do
        n = n + 1
        local when = type(v) == "table" and v.t or v
        if not at or when < at then oldest, at = k, when end
    end
    if n > MAX_KEPT and oldest then t[oldest] = nil end
end

--- A whisper on our own channel to one player. Nothing while the test panel or the pictures stand in for the
--- world (GK.testMode): nothing leaves this client then.
local function SendProfile(key, text)
    if GK.testMode or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    local ok = pcall(C_ChatInfo.SendAddonMessage, PROFILE_PREFIX, text, "WHISPER", LIB.WhisperName(key))
    return ok
end

--- A whole number off the wire within lo..hi, or nil.
local function Int(v, lo, hi)
    local n = tonumber(v)
    if not n or n ~= math.floor(n) or n < lo or n > hi then return nil end
    return n
end

--- The ask an answer is for: by the sender's key, else by name alone - a name off the wire may carry another of
--- the live servers' internal realms than the one we file them under (CLAUDE.md).
local function AskOf(sender)
    if asked[sender] then return sender, asked[sender] end
    local name = GK.Lower(sender:match("^(.-)%-[^%-]+$") or sender)
    for key, a in pairs(asked) do
        if GK.Lower(key:match("^(.-)%-[^%-]+$") or key) == name then return key, a end
    end
    return nil
end

--- Ask a player outside the guild for their score: once a minute at most, and never yourself, a guildie or a
--- player we have a record of. Returns whether an ask went out.
function GK.AskProfile(key)
    if type(key) ~= "string" or LIB.IsMyStoredName(key) or GK.HasRecord(key) or LIB.KnownGuildie(key) then
        return false
    end
    local now = GetTime()
    local a = asked[key]
    if a and now - a.t < ASK_GAP then return false end
    local nonce = tostring(math.random(100000, 999999999))
    asked[key] = { nonce = nonce, t = now }
    Prune(asked)
    if not SendProfile(key, ("A;1;%s"):format(nonce)) then return false end
    C_Timer.After(ANSWER_WAIT + 0.1, GK.Changed)        -- the tiles' "..." becomes "-" when no answer came
    return true
end

--- Where an ask of this player stands: "answered" and what they said, "asking", "silent" (no answer in time),
--- or nil (never asked).
function GK.ProfileHeard(key)
    if heard[key] then return "answered", heard[key] end
    local a = asked[key]
    if not a then return nil end
    if GetTime() - a.t <= ANSWER_WAIT then return "asking" end
    return "silent"
end

local function OnProfileMessage(prefix, text, channel, sender)
    if prefix ~= PROFILE_PREFIX or channel ~= "WHISPER" or type(text) ~= "string" or #text > 120 then return end
    if not (GK.db and GK.char) then return end
    sender = LIB.FullName(GK.Clean(sender, 64))
    if not sender or LIB.IsMyStoredName(sender) then return end
    local f = {}
    for part in (text .. ";"):gmatch("([^;]*);") do f[#f + 1] = part end
    if Int(f[2], 1, 1) ~= 1 then return end
    if f[1] == "A" then
        -- asked: answered when we share outside the guild, once a minute to each, a few a minute to all
        local nonce = f[3]
        if not (nonce and nonce:match("^%d+$") and #nonce <= 10) then return end
        if GK.db.shareOutside == false or GK.testMode then return end
        local now = GetTime()
        if answeredTo[sender] and now - answeredTo[sender] < ASK_GAP then return end
        local recent = {}
        for _, t in ipairs(answers) do
            if now - t < 60 then recent[#recent + 1] = t end
        end
        answers = recent
        if #answers >= MAX_ANSWERS then return end
        answers[#answers + 1] = now
        answeredTo[sender] = now
        Prune(answeredTo)
        local c = GK.char
        SendProfile(sender, ("R;1;%s;%d;%d;%d;%d;%d"):format(nonce, c.points or 0, c.kills or 0, c.deaths or 0,
            c.assists or 0, c.bestStreak or 0))
    elseif f[1] == "R" then
        -- an answer: only from the player we asked, with our number, in time - and only once
        local key, a = AskOf(sender)
        if not (a and a.nonce and f[3] == a.nonce and GetTime() - a.t <= ANSWER_WAIT) then return end
        local p, k, d = Int(f[4], 0, 1e7), Int(f[5], 0, 1e6), Int(f[6], 0, 1e6)
        local as, bs = Int(f[7], 0, 1e6), Int(f[8], 0, 1e6)
        if not (p and k and d and as and bs) then return end
        a.nonce = nil
        heard[key] = { p = p, k = k, d = d, a = as, bs = bs, t = time() }
        Prune(heard)
        GK.Changed()
    end
end

-- ---------------------------------------------------------------------------
-- A player on your side we have no record of
-- ---------------------------------------------------------------------------
local DOTS, DASH = "\226\128\166", "\226\128\147"   -- the tiles while it asks, and with no answer

--- What the game shows of a player on your side - level, class, race, face and guild - read when their profile
--- opens, so a unit token that later means someone else ("target") never puts another player's on their card.
--- nil when the unit is not that player.
function GK.UnitLook(key, unit)
    if type(unit) ~= "string" or not UnitExists(unit) or GK.UnitKey(unit) ~= key then return nil end
    local function Plain(v)
        if v ~= nil and not GK.Secret(v) then return v end
        return nil
    end
    local _, class = UnitClass(unit)
    local race, raceFile = UnitRace(unit)
    return { l = GK.ValidLevel(Plain(UnitLevel(unit))), c = GK.ValidClass(Plain(class)), r = GK.Clean(Plain(race), 20),
        rf = Plain(raceFile), sx = Plain(UnitSex(unit)), g = GK.Clean(Plain((GetGuildInfo(unit))), 32) }
end

--- Their card: what the game shows of them (look, GK.UnitLook), and their score once they answered an ask
--- (GK.AskProfile). The tiles say "..." while it asks and "-" with no answer; nothing else is said.
function GK.StrangerCard(key, look)
    if type(key) ~= "string" then return nil end
    look = look or {}
    local state, h = GK.ProfileHeard(key)
    local function Tile(v)
        if h then return tostring(v) end
        return state == "asking" and DOTS or DASH
    end
    local title = h and GK.Title(h.p) or nil
    local guild = look.g and ("<" .. look.g .. ">") or nil
    local info = GK.Describe(look.l, look.c, look.r)
    local d = { key = key, c = look.c, rf = look.rf, sx = look.sx, title = GK.Show(key),
        name = title or guild or "", info = info, lines = {}, buttons = {} }
    if h then
        d.lines[1] = ("All time: %s, %s, %s."):format(Plural(h.k, "kill"), Plural(h.a, "assist"), Plural(h.d, "death"))
        if h.bs > 0 then d.lines[2] = ("Best kill streak: %d."):format(h.bs) end
    end
    local sub = (title and guild) and (title .. " \194\183 " .. guild) or title or guild or ""
    d.rich = { head = GK.Show(key), sub = sub, info = info,
        kicker = LIB.KnownGuildie(key) and "Your guild" or "Not in your guild",
        tiles = { { Tile(h and h.p), "Points" }, { Tile(h and h.k), "Kills" }, { Tile(h and h.d), "Deaths" },
            { Tile(h and h.a), "Assists" } },
        sections = {} }
    if h and h.bs > 0 then
        d.rich.sections[1] = { head = "Highlights", kind = "facts", rows = { { "Best spree", ("%d kills in a row"):format(h.bs) } } }
    end
    return d
end

-- ---------------------------------------------------------------------------
-- The profile window (2026-11-20)
-- ---------------------------------------------------------------------------
-- The right-click menu's line opens a player here, in a window of their own, as the ledger's right page shows
-- them - the ledger's own card at its size (GK.BuildLedgerCard) - with the way to the ledger under it: "eget
-- vindu kanskje? profil vindu når man høyreklikker? standalone fra inspect og tab og main addon vindu?" (the
-- owner). Drawn first (art/mockups/profile) and built to it. From 2026-11-16 the line opened the ledger itself,
-- and before that a small card with less on it than the ledger.
local PAGE_W, PAGE_H = 368, 496
local profile, shown             -- the window, and the spec it shows (as GK.ShowInLedger takes one)

local function FillProfile()
    if not (profile and shown) then return end
    local d = GK.CardForSpec(shown)
    if d then GK.FillCardPage(profile.page, d) end
end

local function BuildProfile()
    profile = GK.MakeFrameSheet("GrudgekeeperProfile", PAGE_W + 10, PAGE_H + 60, "Grudgekeeper")
    profile.page = CreateFrame("Frame", nil, profile)
    profile.page:SetSize(PAGE_W, PAGE_H)
    profile.page:SetPoint("TOP", 2, -22)
    GK.BuildLedgerCard(profile.page, FillProfile)
    local open = GK.MakeButton(profile, 180, 22)
    open:SetPoint("BOTTOM", 2, 10)
    open:SetText("Open in the ledger")
    open:SetScript("OnClick", function()
        local spec = shown
        profile:Hide()
        if spec then GK.ShowInLedger(spec) end
    end)
    profile.open = open
    LIB.Listen("GRUDGEKEEPER_CHANGED", function() if profile:IsShown() then FillProfile() end end)
    GK.OnLook(function() if profile:IsShown() then FillProfile() end end)
end

--- Open a player in the profile window. spec: as GK.ShowInLedger takes one. Nothing opens for a spec with
--- nothing to show; returns whether it opened.
function GK.ShowProfile(spec)
    if type(spec) ~= "table" or not GK.CardForSpec(spec) then return false end
    if not profile then BuildProfile() end
    shown = spec
    FillProfile()
    profile:Show()
    profile:Raise()
    return true
end

--- What a friendly player's profile opens on: their record (you, or a guildie on the board), else what the game
--- shows of them and what they answer when asked.
local function FriendSpec(key, unit)
    if GK.HasRecord(key) then return { kind = "record", key = key, unit = unit } end
    local look = GK.UnitLook(key, unit)
    return { kind = "card", key = key, make = function() return GK.StrangerCard(key, look) end }
end
GK.FriendProfileSpec = FriendSpec        -- for the Inspect tab (Inspect.lua)

--- Who a friendly menu is about, as a key: from its unit, else the name it was opened on (a chat
--- line's full "Name-Realm" before the menu split it, then the plain name), else its GUID.
function GK.MenuKey(ctx)
    if type(ctx) ~= "table" then return nil end
    local unit = Text(ctx.unit)
    if unit then return GK.UnitKey(unit), unit end
    local name = Text(ctx.chatTarget) or Text(ctx.name)
    if name then return GK.PlayerKey(GK.KeyOf(name)), nil end
    local guid = Text(ctx.guid)
    if guid and GetPlayerInfoByGUID then
        local ok, _, _, _, _, _, gname, realm = pcall(GetPlayerInfoByGUID, guid)
        if ok then return GK.PlayerKey(GK.KeyOf(Text(gname), Text(realm))), nil end
    end
    return nil
end

-- An enemy's line is their Grudge file: what the guild knows of them, which is no profile - an enemy has no way
-- to share one ("nå vises det som om det er en kill order? litt confusing ... det er jo egentlig ikke profiler",
-- the owner, 2026-11-20).
local FILE_LABEL = "Grudge file"

local function OnEnemyMenu(_, root, ctx)
    if not (GK.db and GK.db.unitMenu and GK.char) or type(ctx) ~= "table" then return end
    local unit = Text(ctx.unit)
    local t = unit and GK.ReadUnit(unit)   -- an enemy player we can tell apart, or nil
    if not t then return end
    t.unit = unit
    -- and the kill order itself, one click from the enemy: opening the ledger to post one was too much
    -- work (the owner, 2026-11-05). The label says which of the sheet's three cases it will open.
    AddLine(root, FILE_LABEL, function() GK.ShowProfile({ kind = "poster", t = t }) end, GK.PostLabel(t),
        function() GK.OpenPost(t) end)
    -- Tracked (Sightings.lua): yours alone, one line that says which way it goes
    if GK.IsTracked then
        local on = GK.IsTracked(t.key)
        root:CreateButton(on and "Stop tracking" or "Track", function()
            if on then GK.Untrack(t.key) else GK.TrackSaying(t) end
        end)
    end
    -- Their guild on watch, or off it, for an officer (Notes.lua): the right spelling comes from the game,
    -- which typing one wouldn't. One guild at a time, so the line says which it replaces.
    local ok, guild = pcall(GetGuildInfo, unit)
    if ok and not GK.Secret(guild) and type(guild) == "string" and guild ~= "" and GK.CanWatchGuild
        and GK.CanWatchGuild() then
        local current = GK.WatchedGuild()
        local same = GK.SameGuild(current, guild)        -- the one on watch, if typed in another case
        local label = (same and ("Stop watching <%s>"):format(guild))
            or (current and ("Watch <%s> instead of <%s>"):format(guild, current))
            or ("Watch their guild <%s>"):format(guild)
        root:CreateButton(label, function() GK.WatchGuild(same and current or guild, not same) end)
    end
end

-- A friendly player's profile, every one of them since 2026-11-20: a player outside the guild is asked for
-- their score as it opens (GK.AskProfile), and it fills in when they answer.
local function OnFriendlyMenu(_, root, ctx)
    if not (GK.db and GK.db.unitMenu and GK.char) then return end
    local key, unit = GK.MenuKey(ctx)
    if not key then return end
    AddLine(root, LABEL, function()
        GK.ShowProfile(FriendSpec(key, unit))
        GK.AskProfile(key)
    end)
end

function GK.StartProfiles()
    -- the channel a player outside the guild is asked on, and answers on
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PROFILE_PREFIX)
    end
    LIB.On("CHAT_MSG_ADDON", OnProfileMessage)
    if not (Menu and Menu.ModifyMenu) then return end
    -- pcall: a menu tag this client doesn't have must not stop the others
    pcall(Menu.ModifyMenu, "MENU_UNIT_ENEMY_PLAYER", OnEnemyMenu)
    for _, which in ipairs(FRIENDLY) do pcall(Menu.ModifyMenu, "MENU_UNIT_" .. which, OnFriendlyMenu) end
end
