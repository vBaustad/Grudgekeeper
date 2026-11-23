-- Grudgekeeper - writing a kill order: the who-picker's right half (Pick.lua), a short WANTED poster with whom it
-- is about in its window, the bounty and a line about why. "Seal it" sends it to the guild and the window stays,
-- for the next one. No gold changes hands now: whoever fulfils the order is paid by you, by mail (Mail.lua fills
-- the letter in). With the Death list's picker the same half holds your note.
-- It was a poster of its own that took the search's place: "litt kleint at den switcher til wanted posteren helt
-- ... vi utvider søkevinduet til dobbelt så bredt og har deler av designet for wanted posteren på høyre side. da
-- kan man trykke seg igjennom flere ... kan ha litt av assetsa men ikke alt, for det må passe inn med ramma og
-- burde bruke wow knapper isteden" (the owner, 2026-11-22), drawn first (art/mockups/round8). The paper is the
-- poster a fulfilled order is crossed out on (fx_poster, FxOrders.lua), with a face of our own for every race in
-- its window ("et portrait for hver av rasene ... kun for de wanted posters"): Media/wanted_<race>, painted for
-- it (art/codex_race_portraits.ps1).
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"
local TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local INK, FADED, BLOOD = GK.INK, GK.FADED, GK.BLOOD     -- the skin's, as the picker's left half
local BACKING = { 0.59, 0.44, 0.27 }             -- behind the face, as on the fulfilled poster

-- The half, and the poster in it: fx_poster's paper, u 62-449 of its 512, its top with WANTED and the window, and
-- its torn foot right under that. The plain band between is left out: the window's own paper does that job.
local W, H = 312, 426
local POSTER_W, POSTER_Y = 170, 14
local PAPER_U0, PAPER_U1 = 62 / 512, 449 / 512
local NAT = POSTER_W / (PAPER_U1 - PAPER_U0)     -- the poster's own height at this width
local CUT_TOP, CUT_FOOT = 0.70, 0.875            -- of the texture's height
-- The window, as parts of the texture's side (printed by the import; FxOrders.lua has the same four), in the
-- half's units. The face a little over the window's frame, under the paper, as on the fulfilled poster.
local POSTER_X = (W - POSTER_W) / 2
local WIN_L = POSTER_X + (0.305 - PAPER_U0) / (PAPER_U1 - PAPER_U0) * POSTER_W
local WIN_R = POSTER_X + (0.688 - PAPER_U0) / (PAPER_U1 - PAPER_U0) * POSTER_W
local WIN_T, WIN_B = POSTER_Y + 0.273 * NAT, POSTER_Y + 0.660 * NAT
local FACE_K = 1.04

-- Where the writing stands, down from the half's top: the name under the poster, LEVEL under it, the heading, the
-- game's boxes, the small print (higher where there is no why box: a share of someone's pot), the button.
local L = { nameY = 208, name = 18, levelGap = 4, level = 10, head = 262, money = 282, why = 314,
    small = 344, smallPot = 314, gold = 84, silver = 56, gap = 18, whyIn = 30,
    bar = 2, barIn = 24, barGap = 8, heading = 12,
    fullHead = 26, fullSay = 44, fullTop = 84, fullRow = 31, fullIn = 22, withdraw = 84 }

local frame
local target            -- { key, guid, c, r, rf, l }
local plan              -- GK.PostPlan of the target: pot is set when the sheet adds to someone else's open order

local mode = "order"    -- what the half is for: "order" or "track"
local function Ink(fs, colour, font, size) GK.Ink(fs, colour, font, size) end

-- ---------------------------------------------------------------------------
-- The faces on a WANTED poster
-- ---------------------------------------------------------------------------
-- Ours, one for each playable race, by the race's file token. The two Skyborne share "Skyborne" and differ by
-- the race's name (chrraces 95 "High Order Skyborne", Alliance; 96 "Windshaper Skyborne", Horde).
local WANTED_FACES = { Human = "human", Orc = "orc", Dwarf = "dwarf", NightElf = "nightelf", Scourge = "undead",
    Tauren = "tauren", Gnome = "gnome", Troll = "troll" }
local RACE_NAMES = { Human = "Human", Orc = "Orc", Dwarf = "Dwarf", ["Night Elf"] = "NightElf", Undead = "Scourge",
    Tauren = "Tauren", Gnome = "Gnome", Troll = "Troll" }

--- The race's face, by its token or its name: "skyborne_windshaper", "troll", or nil.
local function RaceFace(rf, r)
    if type(r) == "string" then
        if r:find("Windshaper", 1, true) then return "skyborne_windshaper" end
        if r:find("High Order", 1, true) then return "skyborne_highorder" end
        rf = rf or RACE_NAMES[r]
    end
    if rf == "Skyborne" then
        return UnitFactionGroup("player") == "Horde" and "skyborne_highorder" or "skyborne_windshaper"
    end
    return type(rf) == "string" and WANTED_FACES[rf] or nil
end

--- The painted face a WANTED poster shows for a player, info = { rf (race file token), r (race name), sx (the
--- game's sex: 2 a man, 3 a woman) }: the texture's name under Media. A woman's face where we know they are one,
--- else a man's: an order names no sex, and their race's face says more than none. A Skyborne known by the token
--- alone is the other side's: everyone a kill order is out on is an enemy. Nobody knows their race: the other
--- side's first race, an orc for the Alliance and a human for the Horde, in your own body type - "så om jeg er orc
--- female og vil poste på noen jeg ikke veit hva er, så vises female human" (the owner, 2026-11-21; it showed their
--- class's crest, or the skull). nil only where the client names no side for you. The kill order's poster and the
--- fulfilled one both ask here.
function GK.WantedFace(info)
    if type(info) ~= "table" then return nil end
    local f, sx = RaceFace(info.rf, info.r), info.sx
    if not f then
        local side = UnitFactionGroup and UnitFactionGroup("player")
        f = (side == "Alliance" and "orc") or (side == "Horde" and "human") or nil
        if not f then return nil end
        sx = UnitSex and UnitSex("player")
    end
    return "wanted_" .. f .. (sx == 3 and "_female" or "")
end

-- ---------------------------------------------------------------------------
-- The printed parts
-- ---------------------------------------------------------------------------
--- A box of the game's to write in (Letters.lua, GK.FrameBox). coin: a coin's icon inside on the right (a
--- bounty's). A box for a number is selected whole as it is clicked into, so what is typed replaces what stood
--- there: the sheet opens with your bounty in it, and a 1 typed at a 1 sealed 11g (a guildie's report, 2026-11-22).
local function WriteBox(parent, w, letters, hint, numeric, coin)
    local e = GK.FrameBox(parent, w, letters, hint)
    if coin then
        e:SetTextInsets(0, 20, 0, 0)
        local c = e:CreateTexture(nil, "OVERLAY")
        c:SetTexture(coin)
        c:SetSize(14, 14)
        c:SetPoint("RIGHT", -4, 0)
    end
    if numeric then
        e:SetNumeric(true)
        e:SetJustifyH("RIGHT")
        -- selected as focus comes, and again as that click lets go: the click sets the cursor, which can come
        -- after the focus and takes the selection with it. A later click in the box sets the cursor as usual.
        e:HookScript("OnEditFocusGained", function(self)
            self.fresh = true
            self:HighlightText()
        end)
        e:HookScript("OnMouseUp", function(self)
            if not self.fresh then return end
            self.fresh = nil
            self:HighlightText()
        end)
    end
    return e
end

--- A heading between two thick bars, centred y down from the top. fs:Label(words) renames it, and the bars
--- move with the words.
local function Heading(f, y)
    local fs = f:CreateFontString(nil, "ARTWORK")
    Ink(fs, INK, TEXT_FONT, L.heading)
    fs:SetPoint("TOP", f, "TOP", 0, -y)
    local function Bar()
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetColorTexture(INK[1], INK[2], INK[3], 1)
        t:SetHeight(L.bar)
        return t
    end
    fs.left, fs.right = Bar(), Bar()
    function fs:Label(words)
        self:SetText(words:upper())
        for _, bar in ipairs({ self.left, self.right }) do bar:SetColorTexture(INK[1], INK[2], INK[3], 1) end
        local half = math.ceil((self:GetStringWidth() or 60) / 2) + L.barGap
        local mid = -(y + L.heading / 2)
        self.left:ClearAllPoints()
        self.left:SetPoint("LEFT", f, "TOPLEFT", L.barIn, mid)
        self.left:SetPoint("RIGHT", f, "TOP", -half, mid)
        self.right:ClearAllPoints()
        self.right:SetPoint("LEFT", f, "TOP", half, mid)
        self.right:SetPoint("RIGHT", f, "TOPRIGHT", -L.barIn, mid)
    end
    return fs
end

-- ---------------------------------------------------------------------------
-- Sealing it
-- ---------------------------------------------------------------------------
--- Sealing the sheet (for any look): adds to the plan's pot, or posts the order. plan: the one the sheet
--- was opened with (default: worked out now). False, and a line in chat, when the order couldn't be posted.
function GK.PostSubmit(t, copper, note, plan)
    plan = plan or GK.PostPlan(t)
    if plan.pot then
        GK.Contribute(plan.pot, copper)
    else
        local o, why = GK.PostOrder(t, copper, note)
        if not o then
            print(GK.TAG .. ": " .. (why or "the order couldn't be posted."))
            return false
        end
    end
    GK.Sound("IG_QUEST_LIST_OPEN")
    return true
end

local Dress     -- the half filled for a target (below)

--- What was done, where the small print stood.
local function Said(words)
    frame.small:SetText(words)
    Ink(frame.small, BLOOD, TEXT_FONT, 11)
end

-- ---------------------------------------------------------------------------
-- Full: your ten, each to withdraw
-- ---------------------------------------------------------------------------
--- The half's poster and its boxes, shown or not: your full list takes their place.
local function ShowSheet(on)
    for _, part in ipairs(frame.sheetParts) do part:SetShown(on) end
end

local function FullRow(i)
    local f = frame.full
    local r = CreateFrame("Frame", nil, f)
    r:SetSize(W - 2 * L.fullIn, L.fullRow)
    r:SetPoint("TOPLEFT", L.fullIn, -(L.fullTop + (i - 1) * L.fullRow))
    r.name = r:CreateFontString(nil, "ARTWORK")
    Ink(r.name, INK, TEXT_FONT, 12)
    r.name:SetPoint("TOPLEFT", 0, -3)
    r.name:SetWidth(W - 2 * L.fullIn - L.withdraw - 8)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.what = r:CreateFontString(nil, "ARTWORK")
    Ink(r.what, FADED, TEXT_FONT, 10)
    r.what:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.what:SetWidth(W - 2 * L.fullIn - L.withdraw - 8)
    r.what:SetJustifyH("LEFT")
    r.what:SetWordWrap(false)
    r.withdraw = GK.FrameButton(r, "Withdraw", L.withdraw, function()
        local o = r.order
        if not o then return end
        GK.Withdraw(o)
        if GK.PickRefill then GK.PickRefill() end
        Dress(target)
        if not plan.full then Said(("%s withdrawn. Now seal the new one."):format(GK.Show(o.n))) end
    end)
    r.withdraw:SetPoint("RIGHT", 0, 0)
    f.rows[i] = r
    return r
end

--- Your open orders in the poster's place, with why there is no poster.
local function ShowFull(t, mine)
    local f = frame.full
    f.head:Label(("Your %d kill orders"):format(#mine))
    f.say:SetText(("That is as many as you can have. Withdraw one to post on %s."):format(GK.Show(t.key)))
    for i, o in ipairs(mine) do
        local r = f.rows[i] or FullRow(i)
        r.order = o
        r.name:SetText(GK.Show(o.n))
        local pot = (GK.Pot(o))
        local what = o.auto and "your death posted it" or (pot > 0 and GK.MoneyText(pot) or "no gold")
        r.what:SetText(what .. " - " .. GK.Ago(o.t))
        r:Show()
    end
    for i = #mine + 1, #f.rows do f.rows[i]:Hide() end
    f:Show()
end

local function Seal()
    if not target then return end
    if mode == "track" then
        if not GK.IsTracked(target.key) and not GK.TrackSaying(target) then return end
        GK.SetDeathNote(target.key, frame.tnote:GetText())
        frame.tnote:ClearFocus()
        Dress(target)
        Said("On your Death list. Pick the next one, or Close.")
    else
        local gold = tonumber(frame.gold:GetText()) or 0
        local silver = tonumber(frame.silver:GetText()) or 0
        local copper = gold * 10000 + silver * 100
        if not GK.PostSubmit(target, copper, frame.note:GetText(), plan) then return end
        frame.note:ClearFocus()
        Dress(target)
        Said("Sealed. Pick the next one, or Close.")
    end
    if GK.PickRefill then GK.PickRefill() end         -- the seal or the eye on their row
end

-- ---------------------------------------------------------------------------
-- The poster
-- ---------------------------------------------------------------------------
local function Build(parent)
    frame = CreateFrame("Frame", "GrudgekeeperPost", parent)
    frame:SetSize(W, H)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 304, -22)
    -- the paper over the face: the window is a hole in it
    local top, foot = frame:CreateTexture(nil, "BORDER"), frame:CreateTexture(nil, "BORDER")
    for _, t in ipairs({ top, foot }) do t:SetTexture(MEDIA .. "fx_poster") end
    top:SetTexCoord(PAPER_U0, PAPER_U1, 0, CUT_TOP)
    top:SetSize(POSTER_W, NAT * CUT_TOP)
    top:SetPoint("TOPLEFT", POSTER_X, -POSTER_Y)
    foot:SetTexCoord(PAPER_U0, PAPER_U1, CUT_FOOT, 1)
    foot:SetSize(POSTER_W, NAT * (1 - CUT_FOOT))
    foot:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
    frame.paper = top

    -- the face in the window, on the paper's colour (a crest has corners of its own)
    local side = (WIN_R - WIN_L) * FACE_K
    local cx, cy = (WIN_L + WIN_R) / 2, (WIN_T + WIN_B) / 2
    local back = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    back:SetColorTexture(BACKING[1], BACKING[2], BACKING[3], 1)
    back:SetSize(side, side)
    back:SetPoint("CENTER", frame, "TOPLEFT", cx, -cy)
    frame.face = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    frame.face:SetSize(side, side)
    frame.face:SetPoint("CENTER", frame, "TOPLEFT", cx, -cy)
    -- their class, a crest in the bronze ring on the window's corner, as on the ledger's faces
    frame.crest = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    frame.crest:SetSize(20, 20)
    frame.crest:SetPoint("CENTER", frame, "TOPLEFT", WIN_R - 3, -(WIN_B - 3))
    frame.crest:SetTexture(CLASS_ICONS)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(frame.crest)
    frame.crest:AddMaskTexture(mask)
    frame.crestRing = frame:CreateTexture(nil, "ARTWORK", nil, 3)
    frame.crestRing:SetTexture(MEDIA .. "portrait_ring")
    frame.crestRing:SetDesaturation(0.35)
    frame.crestRing:SetSize(25, 25)
    frame.crestRing:SetPoint("CENTER", frame.crest, "CENTER")

    frame.name = frame:CreateFontString(nil, "ARTWORK")
    Ink(frame.name, INK, TEXT_FONT, L.name)
    frame.name:SetPoint("TOP", frame, "TOP", 0, -L.nameY)
    frame.name:SetWidth(W - 32)
    frame.name:SetWordWrap(false)
    frame.level = frame:CreateFontString(nil, "ARTWORK")
    Ink(frame.level, FADED, TEXT_FONT, L.level)
    frame.level:SetPoint("TOP", frame.name, "BOTTOM", 0, -L.levelGap)

    frame.bounty = Heading(frame, L.head)
    local x = (W - L.gold - L.gap - L.silver) / 2
    frame.gold = WriteBox(frame, L.gold, 4, nil, true, "Interface\\MoneyFrame\\UI-GoldIcon")
    frame.gold:SetPoint("TOPLEFT", x, -L.money)
    frame.silver = WriteBox(frame, L.silver, 2, nil, true, "Interface\\MoneyFrame\\UI-SilverIcon")
    frame.silver:SetPoint("TOPLEFT", x + L.gold + L.gap, -L.money)
    frame.note = WriteBox(frame, W - 2 * L.whyIn, 80, "what did they do?")
    frame.note:SetPoint("TOPLEFT", L.whyIn, -L.why)
    frame.noteBox = frame.note
    -- the Death list's: your note, where the bounty is
    frame.tnote = WriteBox(frame, W - 2 * L.whyIn, GK.DEATH_NOTE_MAX or 80, "Optional. Only you see it.")
    frame.tnote:SetPoint("TOPLEFT", L.whyIn, -L.money)

    frame.small = frame:CreateFontString(nil, "ARTWORK")
    Ink(frame.small, FADED, TEXT_FONT, 11)
    frame.small:SetWidth(W - 44)
    frame.small:SetSpacing(2)
    if frame.small.SetMaxLines then frame.small:SetMaxLines(4) end

    frame.seal = GK.FrameButton(frame, "Seal it", 140, Seal)
    frame.seal:SetPoint("BOTTOMRIGHT", -16, 14)
    -- what gives way to your list of ten (ShowFull)
    frame.sheetParts = { top, foot, back, frame.face, frame.crest, frame.crestRing, frame.name, frame.level,
        frame.bounty, frame.bounty.left, frame.bounty.right, frame.gold, frame.silver, frame.note, frame.small,
        frame.seal }
    frame.full = CreateFrame("Frame", nil, frame)
    frame.full:SetAllPoints(frame)
    frame.full.rows = {}
    frame.full.head = Heading(frame.full, L.fullHead)
    frame.full.say = frame.full:CreateFontString(nil, "ARTWORK")
    Ink(frame.full.say, FADED, TEXT_FONT, 11)
    frame.full.say:SetPoint("TOP", 0, -L.fullSay)
    frame.full.say:SetWidth(W - 2 * L.fullIn)
    frame.full.say:SetSpacing(2)
    frame.full:Hide()
end

--- The face for a target, in the window: our painting of their race, else their class's crest, else our seal
--- (GK.SetPortrait). The crest on the window's corner only beside a painting. Race from the target, else from
--- what we kept of their looks (GK.FaceOf), and their sex from the looks: a target is seen as it is targeted.
local function DressFace(t)
    local look = GK.FaceOf and GK.FaceOf(t.key, t.c) or {}
    local file = GK.WantedFace({ rf = t.rf or look.rf, r = t.r, sx = t.sx or look.sx })
    if file then
        frame.face:SetTexture(MEDIA .. file)
        frame.face:SetTexCoord(0, 1, 0, 1)
    else
        GK.SetPortrait(frame.face, { c = t.c })
    end
    local coords = file and t.c and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[t.c]
    if coords then frame.crest:SetTexCoord(unpack(coords)) end
    frame.crest:SetShown(coords and true or false)
    frame.crestRing:SetShown(coords and true or false)
end

--- The orders on a target that decide what the sheet does: yours, and the first guildie's.
local function Orders(t)
    local me = LIB.Me()
    local mine, theirs
    for _, o in ipairs(GK.OrdersOn(t.key, t.guid)) do
        if o.by == me then mine = o elseif not theirs then theirs = o end
    end
    return mine, theirs, me
end

--- What GK.OpenPost(t) will do, said as the line in the right-click menu: decided by the same Orders, so the
--- line can't promise a new order and open someone else's pot.
function GK.PostLabel(t)
    local mine, theirs = Orders(t)
    if mine then return "Change your kill order" end
    if theirs then return "Add to the pot" end
    return "Post a kill order"
end

--- Which of the sheet's three ways it goes for a target { key, guid, c, r, l }, and what it says:
---   you have an open order on them   "change": it is filled in, and sealing changes it
---   a guildie has one                "pot": the sheet adds your share to THEIR pot - one order, one pot,
---                                    rather than two orders racing for the same kill
---   nobody has                       "new": a new order
--- Returns { case, pot (the order whose pot it is, for "pot"), mine, title, bounty (the label), small (the
--- explanation), button, amount (copper, to start with), note (to start with), asksWhy (it takes a note) }.
function GK.PostPlan(t)
    local mine, theirs, me = Orders(t)
    local pot = (not mine) and theirs or nil
    local p = { pot = pot, mine = mine }
    if pot then
        local total, backers = GK.Pot(pot)
        p.case = "pot"
        p.title, p.bounty = "ADD TO THE POT", "Your share"
        p.small = ("%s already has an order on them: %s%s. Your share goes on top, and you pay it "
            .. "to whoever fulfils it."):format(GK.Show(pot.by), GK.MoneyText(total),
            backers > 0 and (" from %d backer%s and them"):format(backers, backers == 1 and "" or "s") or "")
        p.button = "Add it"
        p.amount = pot.pot and pot.pot[me] or 0
        if p.amount > 0 then
            -- a share is set, never added to (GK.Contribute): with one in already the sheet says so
            p.small = ("%s already has an order on them: %s in all. Your share is %s now. A new amount replaces it.")
                :format(GK.Show(pot.by), GK.MoneyText(total), GK.MoneyText(p.amount))
            p.button = "Change it"
        end
    else
        p.case = mine and "change" or "new"
        p.title, p.bounty = "KILL ORDER", "Bounty"
        -- one line on the poster where three sentences stood: nothing is taken now, and it runs a week
        p.small = "You pay it by mail when it's fulfilled - runs 7 days"
        p.button = mine and "Change it" or "Seal it"
        p.amount = mine and mine.reward or 0
        -- a new one where you have as many open as there can be: your list, to withdraw one (ShowFull)
        if not mine then
            p.open = GK.MyOpenOrders and GK.MyOpenOrders() or {}       -- Guild.lua's, where it is loaded
            p.full = #p.open >= (GK.MAX_OPEN_PER_POSTER or 10)
        end
    end
    p.asksWhy = not pot
    p.note = mine and mine.note or ""
    return p
end

--- The half filled for a target { key, guid, c, r, rf, l }: an order (GK.PostPlan's three ways), or your Death
--- list's note. Nothing is focused: the keys stay the player's until a box is clicked.
Dress = function(t)
    target = t
    frame.full:Hide()
    ShowSheet(true)
    DressFace(t)
    -- a long name steps down a size or two before the game cuts it short
    for _, size in ipairs({ L.name, L.name - 3, L.name - 6 }) do
        Ink(frame.name, INK, TEXT_FONT, size)
        frame.name:SetText(GK.Show(t.key))
        if (frame.name:GetStringWidth() or 0) <= W - 32 then break end
    end
    frame.level:SetText(t.l and ("LEVEL " .. (t.l == -1 and "??" or t.l)) or "")
    Ink(frame.small, FADED, TEXT_FONT, 11)
    frame.small:ClearAllPoints()
    -- out of the boxes first: one still being written in gets no new focus when clicked, so no selection
    frame.gold:ClearFocus()
    frame.silver:ClearFocus()
    local order = mode ~= "track"
    frame.gold:SetShown(order)
    frame.silver:SetShown(order)
    frame.tnote:SetShown(not order)
    if not order then
        frame.noteBox:Hide()
        local on = GK.IsTracked(t.key)
        frame.bounty:Label("Your note")
        frame.tnote:SetText(on and GK.DeathNote(t.key) or "")
        frame.small:SetText(on and "On your Death list." or "A warning and an eye over them when they are near.")
        frame.small:SetPoint("TOP", 0, -L.smallPot)
        frame.seal:SetText(on and "Save the note" or "Add to Death list")
        return
    end
    plan = GK.PostPlan(t)
    if plan.full then
        ShowSheet(false)
        ShowFull(t, plan.open)
        return
    end
    frame.bounty:Label(plan.bounty)
    frame.small:SetText(plan.small)
    frame.small:SetPoint("TOP", 0, -(plan.asksWhy and L.small or L.smallPot))   -- into the why's room when it has none
    frame.seal:SetText(plan.button)
    frame.noteBox:SetShown(plan.asksWhy)
    local amount = plan.amount
    frame.gold:SetText(amount >= 10000 and tostring(math.floor(amount / 10000)) or "")
    frame.silver:SetText(amount % 10000 >= 100 and tostring(math.floor(amount / 100) % 100) or "")
    frame.note:SetText(plan.note)
end

--- The picker's right half (Pick.lua): for "order" or "track", on t; none chosen, none shown. The half's frame.
function GK.ShowPostHalf(parent, kind, t)
    local on = (kind == "order" or kind == "track") and t ~= nil and t.key ~= nil
    if not frame then
        if not on then return nil end
        Build(parent)
    end
    frame:SetShown(on)
    if on then
        mode = kind
        Dress(t)
    end
    return frame
end

--- Open the kill order window on a target: { key, guid, c, r, rf, l } - the search, with them chosen.
function GK.OpenPost(t)
    if not (t and t.key) then return end
    GK.OpenPicker("order", t)
end

--- /grudge post: an order on your target, if that is an enemy player - else the who-picker (Pick.lua),
--- rather than a chat line nobody reads.
function GK.PostOnTarget()
    local u = GK.ReadUnit("target")
    if u then
        GK.OpenPost(u)
        return
    end
    GK.OpenPicker("order")
end
