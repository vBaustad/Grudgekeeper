-- Grudgekeeper - writing a kill order: a WANTED poster with whom it is about in its window, the bounty, a line
-- about why. "Seal it" sends it to the guild. No gold changes hands now: whoever fulfils the order is paid by
-- you, by mail (Mail.lua fills the letter in).
-- It was a scroll between two rolls, its parts drawn in hairlines - "føles så tynt og skrøpelig ut ... de tynne
-- strekene for skille og text input ... så stusselig" (the owner, 2026-11-21). From the sketches in
-- art/mockups/postsheet the owner took F, a printed bill: the poster a fulfilled order is crossed out on
-- (fx_poster, FxOrders.lua), its boxes in heavy ink with a hard shadow, its headings between thick bars. And a
-- face of our own for every race in its window ("et portrait for hver av rasene ... kun for de wanted posters"):
-- Media/wanted_<race>, painted for it (art/codex_race_portraits.ps1).
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"
local TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local INK = { 0.18, 0.10, 0.03 }                 -- darker than the letters' ink: a printed bill
local INK2 = { 0.29, 0.17, 0.07 }                -- the small print and LEVEL
local BLOOD = { 0.47, 0.06, 0.04 }
local BACKING = { 0.59, 0.44, 0.27 }             -- behind the face, as on the fulfilled poster

-- The poster: fx_poster's paper, u 62-449 of its 512, all of its height. Cut in three down its height - the top
-- with WANTED and the window at its own shape, the plain band under the window stretched, the torn foot at its
-- own shape - so it is as tall as what is written on it without stretching the window.
local W, H = 300, 500
local PAPER_U0, PAPER_U1 = 62 / 512, 449 / 512
local NAT = W / (PAPER_U1 - PAPER_U0)            -- 397: the poster's own height at this width
local CUT_TOP, CUT_FOOT = 0.70, 0.88             -- of the texture's height
-- The window, as parts of the texture's side (printed by the import; FxOrders.lua has the same four), in the
-- poster's units. The face a little over the window's frame, under the paper, as on the fulfilled poster.
local WIN_L = (0.305 - PAPER_U0) / (PAPER_U1 - PAPER_U0) * W
local WIN_R = (0.688 - PAPER_U0) / (PAPER_U1 - PAPER_U0) * W
local WIN_T, WIN_B = 0.273 * NAT, 0.660 * NAT
local FACE_K = 1.04

-- Where the writing stands, down from the top: the name under the window, LEVEL under it, the bounty's heading,
-- its boxes, the why box, the small print (higher where there is no why box: a share of someone's pot).
-- box: a box's height; gold, silver: the bounty boxes' widths, gap between them; whyIn: the why box this far in
-- from either side. border, shadow: the boxes' ink and their print shadow; bar: the heading's bars, barIn from
-- the sides and barGap from its words.
local L = { nameY = WIN_B + 8, name = 22, levelGap = 5, level = 11, head = 316, money = 336, why = 374,
    small = 410, smallPot = 366, box = 26, gold = 78, silver = 54, gap = 10, whyIn = 40, border = 2.5, shadow = 3,
    shadowA = 0.6, bar = 4, barIn = 40, barGap = 8, heading = 14 }

local frame
local target            -- { key, guid, c, r, rf, l }
local plan              -- GK.PostPlan of the target: pot is set when the sheet adds to someone else's open order

local function Ink(fs, colour, font, size)
    GK.SetFont(fs, font, size)                   -- a family: names in Cyrillic too (Core.lua)
    fs:SetTextColor(colour[1], colour[2], colour[3])
    fs:SetShadowOffset(0, 0)
end

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
--- A box printed in heavy ink: a faint fill, a border, and a hard shadow down its right and along its foot,
--- outside it only. box:Edge(colour) inks the border (blood while it is written in).
local function Box(parent, w, h)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(w, h)
    local function Tex(layer, c, a)
        local t = b:CreateTexture(nil, layer)
        t:SetColorTexture(c[1], c[2], c[3], a)
        return t
    end
    local right = Tex("BACKGROUND", INK, L.shadowA)
    right:SetPoint("TOPLEFT", b, "TOPRIGHT", 0, -L.shadow)
    right:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", L.shadow, -L.shadow)
    local foot = Tex("BACKGROUND", INK, L.shadowA)
    foot:SetPoint("TOPLEFT", b, "BOTTOMLEFT", L.shadow, 0)
    foot:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, -L.shadow)
    local fill = Tex("BORDER", { 1, 0.94, 0.78 }, 0.28)
    fill:SetAllPoints()
    b.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" },
        { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = Tex("ARTWORK", INK, 1)
        t:SetPoint(side[1])
        t:SetPoint(side[2])
        if i <= 2 then t:SetHeight(L.border) else t:SetWidth(L.border) end
        b.edges[i] = t
    end
    function b:Edge(c)
        for _, t in ipairs(self.edges) do t:SetColorTexture(c[1], c[2], c[3], 1) end
    end
    return b
end

--- A box to write in: the sheets' own line (Letters.lua, GK.SheetLine) filling a printed box, its rule left out.
--- size: the type's; coin: a coin's icon inside on the right (a bounty's box). Returns the edit box; e.box is
--- the box.
local function WriteBox(parent, w, letters, hint, numeric, size, coin)
    local box = Box(parent, w, L.box)
    local e = GK.SheetLine(box, w, letters, hint, numeric)
    e:ClearAllPoints()
    e:SetPoint("TOPLEFT", L.border, -L.border)
    e:SetPoint("BOTTOMRIGHT", -L.border, L.border)
    e.rule:Hide()
    GK.SetFont(e, TEXT_FONT, size)
    e:SetTextInsets(5, coin and 22 or 5, 0, 0)
    e.hint:ClearAllPoints()
    e.hint:SetPoint("LEFT", 6, 0)
    if coin then
        local c = box:CreateTexture(nil, "OVERLAY")
        c:SetTexture(coin)
        c:SetSize(15, 15)
        c:SetPoint("RIGHT", -6, 0)
    end
    e:HookScript("OnEditFocusGained", function() box:Edge(BLOOD) end)
    e:HookScript("OnEditFocusLost", function() box:Edge(INK) end)
    e.box = box
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

--- Cancel: a printed box at the poster's foot on the left, blood under the mouse. Hides the poster.
local function CancelButton(f)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(76, 24)
    b:SetPoint("BOTTOMLEFT", 30, 28)
    local box = Box(b, 76, 24)
    box:SetAllPoints()
    b.text = box:CreateFontString(nil, "OVERLAY")
    Ink(b.text, INK, TEXT_FONT, 13)
    b.text:SetPoint("CENTER")
    b.text:SetText(CANCEL or "Cancel")
    b:SetScript("OnEnter", function()
        box:Edge(BLOOD)
        b.text:SetTextColor(BLOOD[1], BLOOD[2], BLOOD[3])
    end)
    b:SetScript("OnLeave", function()
        box:Edge(INK)
        b.text:SetTextColor(INK[1], INK[2], INK[3])
    end)
    b:SetScript("OnClick", function() f:Hide() end)
    return b
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

local function Seal()
    local gold = tonumber(frame.gold:GetText()) or 0
    local silver = tonumber(frame.silver:GetText()) or 0
    local copper = gold * 10000 + silver * 100
    if not GK.PostSubmit(target, copper, frame.note:GetText(), plan) then return end
    frame:Hide()
    GK.OpenWindow(1)
end

-- ---------------------------------------------------------------------------
-- The poster
-- ---------------------------------------------------------------------------
local function Build()
    frame = GK.MakeSheet("GrudgekeeperPost", W, H)
    -- the paper in three, over the face: the window is a hole in it
    local top, mid, foot = frame:CreateTexture(nil, "BORDER"), frame:CreateTexture(nil, "BORDER"),
        frame:CreateTexture(nil, "BORDER")
    for _, t in ipairs({ top, mid, foot }) do t:SetTexture(MEDIA .. "fx_poster") end
    top:SetTexCoord(PAPER_U0, PAPER_U1, 0, CUT_TOP)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    top:SetHeight(NAT * CUT_TOP)
    foot:SetTexCoord(PAPER_U0, PAPER_U1, CUT_FOOT, 1)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(NAT * (1 - CUT_FOOT))
    mid:SetTexCoord(PAPER_U0, PAPER_U1, CUT_TOP, CUT_FOOT)
    mid:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
    mid:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
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
    frame.crest:SetSize(26, 26)
    frame.crest:SetPoint("CENTER", frame, "TOPLEFT", WIN_R - 4, -(WIN_B - 4))
    frame.crest:SetTexture(CLASS_ICONS)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(frame.crest)
    frame.crest:AddMaskTexture(mask)
    frame.crestRing = frame:CreateTexture(nil, "ARTWORK", nil, 3)
    frame.crestRing:SetTexture(MEDIA .. "portrait_ring")
    frame.crestRing:SetDesaturation(0.35)
    frame.crestRing:SetSize(32, 32)
    frame.crestRing:SetPoint("CENTER", frame.crest, "CENTER")

    frame.name = frame:CreateFontString(nil, "ARTWORK")
    Ink(frame.name, INK, TEXT_FONT, L.name)
    frame.name:SetPoint("TOP", frame, "TOP", 0, -L.nameY)
    frame.name:SetWidth(W - 40)
    frame.name:SetWordWrap(false)
    frame.level = frame:CreateFontString(nil, "ARTWORK")
    Ink(frame.level, INK2, TEXT_FONT, L.level)
    frame.level:SetPoint("TOP", frame.name, "BOTTOM", 0, -L.levelGap)

    frame.bounty = Heading(frame, L.head)
    local x = (W - L.gold - L.gap - L.silver) / 2
    frame.gold = WriteBox(frame, L.gold, 4, nil, true, 17, "Interface\\MoneyFrame\\UI-GoldIcon")
    frame.gold.box:SetPoint("TOPLEFT", x, -L.money)
    frame.silver = WriteBox(frame, L.silver, 2, nil, true, 17, "Interface\\MoneyFrame\\UI-SilverIcon")
    frame.silver.box:SetPoint("TOPLEFT", x + L.gold + L.gap, -L.money)
    frame.note = WriteBox(frame, W - 2 * L.whyIn, 80, "what did they do?", false, 14)
    frame.note.box:SetPoint("TOPLEFT", L.whyIn, -L.why)
    frame.noteBox = frame.note.box

    frame.small = frame:CreateFontString(nil, "ARTWORK")
    Ink(frame.small, INK2, TEXT_FONT, 11)
    frame.small:SetWidth(W - 60)
    frame.small:SetSpacing(2)
    if frame.small.SetMaxLines then frame.small:SetMaxLines(4) end

    frame.seal = GK.SheetSeal(frame, Seal)
    frame.seal:ClearAllPoints()
    frame.seal:SetPoint("BOTTOMRIGHT", -22, 20)
    frame.cancel = CancelButton(frame)
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
    else
        p.case = mine and "change" or "new"
        p.title, p.bounty = "KILL ORDER", "Bounty"
        -- one line on the poster where three sentences stood: nothing is taken now, and it runs a week
        p.small = "You pay it by mail when it's fulfilled - runs 7 days"
        p.button = mine and "Change it" or "Seal it"
        p.amount = mine and mine.reward or 0
    end
    p.asksWhy = not pot
    p.note = mine and mine.note or ""
    return p
end

--- Open the sheet for a target: { key, guid, c, r, rf, l }. Three ways it can go (see GK.PostPlan).
function GK.OpenPost(t)
    if not (t and t.key) then return end
    if not frame then Build() end
    target = t
    plan = GK.PostPlan(t)
    DressFace(t)
    -- a long name steps down a size or two before the game cuts it short
    for _, size in ipairs({ L.name, L.name - 3, L.name - 6 }) do
        Ink(frame.name, INK, TEXT_FONT, size)
        frame.name:SetText(GK.Show(t.key))
        if (frame.name:GetStringWidth() or 0) <= W - 40 then break end
    end
    frame.level:SetText(t.l and ("LEVEL " .. (t.l == -1 and "??" or t.l)) or "")
    frame.bounty:Label(plan.bounty)
    frame.small:SetText(plan.small)
    frame.small:ClearAllPoints()
    frame.small:SetPoint("TOP", 0, -(plan.asksWhy and L.small or L.smallPot))   -- into the why's room when it has none
    frame.seal:Set(plan.button)
    local amount = plan.amount
    frame.noteBox:SetShown(plan.asksWhy)
    frame.gold:SetText(amount >= 10000 and tostring(math.floor(amount / 10000)) or "")
    frame.silver:SetText(amount % 10000 >= 100 and tostring(math.floor(amount / 100) % 100) or "")
    frame.note:SetText(plan.note)
    GK.PlaceSheet(frame)
    frame:Show()
    frame:Raise()
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
