-- Grudgekeeper - revenge: their face struck. B in the effect lab (art/lab/effektlab), the owner's pick, 2026-11-20.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
--
-- "skal vi lage en revenge animation isteden for den kjedelige vi har nå med stempel? den trenger ikke være så
-- stor, men både splash og toast kanskje? og ikke bare hvit text heller" (the owner, 2026-11-20). Their face in the
-- bronze ring, a red cut across it (Merciless's slash), blood behind the ring (Butcher's splat), the face flashing
-- red, and REVENGE slammed in under it in blood red. Smaller than a spree's seal: the ring is 120 where the seal is
-- 170, and the line comes up under the word. Your own revenge is the splash (GK.FX), a guildie's the toast
-- (GK.TOASTFX). The line's colours are Announce.lua's.
--
-- The face is placed by hand (Place), as on the WANTED poster (FxOrders.lua): a race's face, or a class's crest,
-- is a corner of one file, and P.Set gives a texture the whole file. It is cut round by the portrait mask, as in
-- the ledger (GK.MakePortrait). The cut grows from its start as Merciless's does, by its width: a texture's turn
-- throws its coordinates away (Effects.lua), so it cannot be revealed by them as the lab first drew it.
local ADDON, GK = ...

GK.FX = GK.FX or {}
GK.TOASTFX = GK.TOASTFX or {}

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local WORD_FONT = "Fonts\\MORPHEUS.ttf"
local WORD_COLOUR = { 0.8, 0.12, 0.07 }
local FACE_K = 0.92                    -- the face under the ring's band, as GK.MakePortrait has it

--- A texture put where P.Set would put it, with its texture coordinates left alone (a crest's corner).
local function Place(frame, t, x, y, side, a)
    if a <= 0.001 then t:Hide() return end
    local at = frame.fxOrigin
    t:ClearAllPoints()
    t:SetPoint("CENTER", frame, at and at.point or "TOP", (at and at.x or 0) + x,
        (at and at.y or -GK.FxKit.SEAL / 2) - y)
    t:SetSize(side, side)
    t:SetAlpha(math.min(1, a))
    t:Show()
end

--- Their face: their race's, else their class's crest, else the skull (GK.SetPortrait). item.face is a sample's;
--- a real revenge has their key and class, and what we kept of their looks when they died.
local function Face(tex, item)
    local face = type(item.face) == "table" and item.face
        or (GK.FaceOf and type(item.targetKey) == "string" and GK.FaceOf(item.targetKey, item.targetClass)) or {}
    if GK.SetPortrait then GK.SetPortrait(tex, face) end
    tex:SetDesaturated(false)
end

--- A jolt as the cut lands: px out, rocking back and settling.
local function Jolt(age, t0, px)
    if age < t0 then return 0 end
    return px * math.exp(-(age - t0) * 13) * math.cos((age - t0) * 38)
end

--- The ring's parts, the same in a splash and a toast, each layer under the next.
local function BuildRing(frame, P, s)
    s.splat = P.Tex(frame, "fx_splat_1", "ARTWORK", 1)
    s.face = P.Tex(frame, nil, "ARTWORK", 3)
    s.mask = frame:CreateMaskTexture()
    s.mask:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    s.mask:SetAllPoints(s.face)
    s.face:AddMaskTexture(s.mask)
    s.ring = P.Tex(frame, "portrait_ring", "ARTWORK", 5)
    s.slash = P.Tex(frame, "fx_slash", "OVERLAY", 2, true)
end

--- The ring at its age, by d's numbers (SPLASH or TOAST): it pops in, the cut crosses it, and as it lands the
--- blood blooms behind, the face flashes red and the ring jolts.
local function DrawRing(frame, P, s, age, d)
    local E = P.E
    local inn = P.prog(age, 0, d.inn, E.outBack)
    local side, a = d.ring * (1 + 0.3 * (1 - inn)), P.prog(age, 0, d.fadeIn)
    local jx, y = Jolt(age, d.hit, d.joltX), d.ry + Jolt(age, d.hit, d.joltY)
    if age >= d.hit then
        local q = P.prog(age, d.hit, d.splatTime, E.outQ)
        P.Set(frame, s.splat, { x = d.splatX + jx, y = y, w = d.splat, h = d.splat, s = P.lerp(0.35, 1, q), r = 0.4,
            a = 0.9 })
    else
        s.splat:Hide()
    end
    Place(frame, s.face, jx, y, side * FACE_K, a)
    -- the red flash: a tinted copy laid over the face at alpha f, as the lab draws it, is this vertex colour
    local f = age >= d.hit and 0.85 * math.exp(-(age - d.hit) * 5) or 0
    s.face:SetVertexColor(1, 1 - 0.7 * f, 1 - 0.75 * f)
    P.Set(frame, s.ring, { x = jx, y = y, w = side, h = side, a = a })
    local q = P.prog(age, d.cut, d.hit - d.cut, E.outQ)
    if q > 0 then
        local mid = -d.len / 2 + d.len * q / 2
        P.Set(frame, s.slash, { x = math.cos(d.r) * mid + jx, y = math.sin(d.r) * mid + y, w = d.len, h = d.slashH,
            sx = q, r = d.r, a = d.slashA(age) })
    else
        s.slash:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- The splash: your own revenge
-- ---------------------------------------------------------------------------
local CUT, HIT, WORD = 0.34, 0.43, 0.74
local WORD_Y, WORD_SIZE = 76, 32       -- REVENGE's middle under the seal's centre, and its size
local LINE_Y = 104                     -- the line's top: under the word, where a seal's would be lower

local SPLASH = { ring = 120, ry = -10, inn = 0.26, fadeIn = 0.08, cut = CUT, hit = HIT, len = 240, r = 0.62,
    slashH = 60, splat = 240, splatX = 8, splatTime = 0.14, joltX = 6, joltY = 3,
    -- the cut stays as a scar, fading a little
    slashA = function(age)
        if age < HIT + 0.25 then return 1 end
        return 1 - 0.3 * math.min(1, (age - HIT - 0.25) / 0.5)
    end }

GK.FX.revenge = {
    land = WORD,                       -- the line and the glow come with the word, and the hold counts from it
    cues = { { 0, "whoosh_50" }, { CUT - 0.02, "schwing" }, { HIT, "boom" }, { WORD - 0.1, "whoosh_50" },
        { WORD, "stamp" } },
    build = function(splash, P)
        local s = {}
        s.gloom = P.Tex(splash, "fx_gloom", "BACKGROUND", 2)
        BuildRing(splash, P, s)
        s.word = splash:CreateFontString(nil, "OVERLAY")
        s.word:SetFont(WORD_FONT, WORD_SIZE, "THICKOUTLINE")
        s.word:SetTextColor(WORD_COLOUR[1], WORD_COLOUR[2], WORD_COLOUR[3])
        s.word:SetText("REVENGE")
        s.word:Hide()
        splash.fxParts[#splash.fxParts + 1] = s.word       -- so the kit's HideAll hides it with the textures
        s.sparks = P.Burst(splash, 14, { t0 = HIT, cy = SPLASH.ry, speed = 260, life = 0.45, size = 9,
            angle = SPLASH.r, arc = 0.7, seed = 11, stretch = 2.5 })
        splash.revenge = s
    end,
    start = function(splash, item, P)
        Face(splash.revenge.face, item)
    end,
    update = function(splash, age, P)
        local s = splash.revenge
        P.Set(splash, splash.seal, { a = 0 })            -- the ring is where the seal would be
        P.Set(splash, s.gloom, { w = 300, h = 260, a = 0.65 * P.prog(age, 0, 0.2) })
        DrawRing(splash, P, s, age, SPLASH)
        s.sparks(age)
        -- REVENGE slammed in under the ring: its text scale from 1.8 to 1, then a small settle
        if age < WORD - 0.12 then
            s.word:Hide()
        else
            local k = P.prog(age, WORD - 0.12, 0.12, P.E.inQ)
            s.word:SetTextScale(age < WORD and P.lerp(1.8, 1, k) or 1 + 0.06 * math.exp(-(age - WORD) * 12))
            s.word:SetAlpha(age < WORD and k or 1)
            s.word:ClearAllPoints()
            s.word:SetPoint("CENTER", splash, "TOP", 0, -P.SEAL / 2 - WORD_Y)
            s.word:Show()
        end
        -- the line up under the word (Announce.lua puts it back for the next splash)
        splash.line:ClearAllPoints()
        splash.line:SetPoint("TOP", splash, "TOP", 0, -P.SEAL / 2 - LINE_Y)
    end,
}

-- ---------------------------------------------------------------------------
-- The toast: a guildie's revenge
-- ---------------------------------------------------------------------------
local TOAST = { ring = 58, ry = 0, inn = 0.2, fadeIn = 0.06, cut = 0.22, hit = 0.3, len = 110, r = 0.62,
    slashH = 28, splat = 96, splatX = 4, splatTime = 0.12, joltX = 3, joltY = 0,
    slashA = function() return 0.9 end }

GK.TOASTFX.revenge = {
    build = function(toast, P)
        toast.fxOrigin = { point = "TOPLEFT", x = 32, y = -32 }      -- the toast's seal's centre (FxToast.lua)
        local s = {}
        BuildRing(toast, P, s)
        toast.revenge = s
    end,
    start = function(toast, item, P)
        Face(toast.revenge.face, item)
    end,
    update = function(toast, age, P)
        P.Set(toast, toast.seal, { a = 0 })
        DrawRing(toast, P, toast.revenge, age, TOAST)
    end,
}
