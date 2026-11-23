-- Grudgekeeper - revenge: their face struck. B in the effect lab (art/lab/effektlab), the owner's pick, 2026-11-20.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
--
-- "skal vi lage en revenge animation isteden for den kjedelige vi har nå med stempel? den trenger ikke være så
-- stor, men både splash og toast kanskje? og ikke bare hvit text heller" (the owner, 2026-11-20). Their face in the
-- bronze ring, a red cut across it (Merciless's slash), blood behind the ring (Butcher's splat), the face flashing
-- red, and REVENGE slammed in above it in blood red. Smaller than a spree's seal: the ring is 120 where the seal is
-- 170, and the line comes up under the ring. Your own revenge is the splash (GK.FX), a guildie's the toast
-- (GK.TOASTFX). The line's colours are Announce.lua's.
-- REVENGE is the kit's headline (P.Headline, Effects.lua), where TORMENTOR SLAIN stands: H in the effect lab's round
-- 5, the owner's pick (2026-11-21), after "jeg likte texten øverst, og kanskje revenge burde ha texten samme sted?".
-- Until then it was under the ring, at 32.
--
-- The face is placed by hand (Place), as on the WANTED poster (FxOrders.lua): a race's face, or a class's crest,
-- is a corner of one file, and P.Set gives a texture the whole file. It is cut round by the portrait mask, as in
-- the ledger (GK.MakePortrait). The cut grows from its start as Merciless's does, by its width: a texture's turn
-- throws its coordinates away (Effects.lua), so it cannot be revealed by them as the lab first drew it.
local ADDON, GK = ...

GK.FX = GK.FX or {}
GK.TOASTFX = GK.TOASTFX or {}

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local WORD_COLOUR, WORD_GLOW, WORD_FLASH = { 0.8, 0.12, 0.07 }, { 0.85, 0.1, 0.06 }, { 1, 0.45, 0.35 }
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
local LINE_Y = 66                      -- the line's top: just under the ring, where a seal's would be lower

local SPLASH = { ring = 120, ry = -10, inn = 0.26, fadeIn = 0.08, cut = CUT, hit = HIT, len = 240, r = 0.62,
    slashH = 60, splat = 240, splatX = 8, splatTime = 0.14, joltX = 6, joltY = 3,
    -- the cut stays as a scar, fading a little
    slashA = function(age)
        if age < HIT + 0.25 then return 1 end
        return 1 - 0.3 * math.min(1, (age - HIT - 0.25) / 0.5)
    end }

GK.FX.revenge = {
    land = WORD,                       -- the line and the glow come with the word, and the hold counts from it
    voice = HIT,                       -- its own call with the hit, one sound with it: it came as the splash showed (2026-11-21)
    cues = { { 0, "whoosh_50" }, { CUT - 0.02, "schwing" }, { HIT, "boom" }, { WORD - 0.1, "whoosh_50" },
        { WORD, "stamp" } },
    build = function(splash, P)
        local s = {}
        s.gloom = P.Tex(splash, "fx_gloom", "BACKGROUND", 2)
        BuildRing(splash, P, s)
        s.head = P.Headline(splash, "REVENGE", WORD_COLOUR, WORD_GLOW, WORD_FLASH, P.HeadOver(SPLASH.ry - SPLASH.ring / 2))
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
        -- the gloom reaches up behind the word as well as the ring
        P.Set(splash, s.gloom, { y = -40, w = 420, h = 400, a = 0.65 * P.prog(age, 0, 0.2) })
        DrawRing(splash, P, s, age, SPLASH)
        s.sparks(age)
        P.DrawHeadline(splash, s.head, age, WORD)        -- REVENGE above the ring
        -- the line up under the ring (Announce.lua puts it back for the next splash)
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
    voice = TOAST.hit,                 -- the call with the hit, as the splash's
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

-- ---------------------------------------------------------------------------
-- A Death list kill: the eye. A1 in the effect lab's round 10, the owner's pick, 2026-11-23.
-- ---------------------------------------------------------------------------
-- "kan vi ikke bare ha 1 ting for hele death listen? you killed someone on your deathlist kinda? de skal ikke bli
-- borte fra listen med mindre man selv fjerner dem" (the owner): nothing is struck off. The Death list's own mark,
-- the black wax seal with the eye that stands over their plates (Media/eye), slams in with the eye shut; it opens and
-- glows blood red, a notch is cut in the wax for the kill, and DEATH LIST slams down over it. Codex drew the seal as
-- 16 frames after the owner's own (art/import_deathlist.py: fx_deathlist_eye), the next laid over each as it comes.
-- Its sounds are the owner's picks in the lab: a boom as the seal lands, Backstab (Spell_RO_Backstab_Cast_01) on the
-- notch, no call and nothing on the word. Here because it is a grudge's kill as revenge is, and a file of its own
-- would need the game started again to load.
local EYE_SHEET = "fx_deathlist_eye"
local EYE_FPS, EYE_OPEN, EYE_GLOW, EYE_HIT = 12, 2, 6, 9            -- frames: the eye opens, glows, is notched
local EYE_HIT_X, EYE_HIT_Y = 0.27, -0.27                            -- the notch, as shares of the picture from its middle
local EYE_ART = 0.8                                                 -- how much of a cell the seal fills
local EYE_WORD_COLOUR = { 0.8, 0.12, 0.07 }                         -- REVENGE's blood red: the same family of kill
local EYE_SPLASH = { size = 210, y = -20, start = 0.12, slam = 0.14, k = 1, dust = 16, sparks = 18, jolt = 4 }
local EYE_TOAST = { size = 63, y = 0, start = 0.05, slam = 0.12, k = 0.3, dust = 6, sparks = 6, jolt = 4 }

local function EyeTimes(d)
    local land = d.start + d.slam
    return land, land + EYE_HIT / EYE_FPS
end
local EYE_LAND, EYE_HIT_T = EyeTimes(EYE_SPLASH)
local EYE_WORD = EYE_HIT_T + 0.32
local EYE_T_LAND, EYE_T_HIT = EyeTimes(EYE_TOAST)
local EYE_CELL = function(i)
    local col, row = i % 4, math.floor(i / 4)
    return { col / 4, (col + 1) / 4, row / 4, (row + 1) / 4 }
end

local function BuildEye(frame, P, d)
    local s, k = {}, d.k
    local hx, hy = EYE_HIT_X * d.size, d.y + EYE_HIT_Y * d.size
    s.glow = P.Tex(frame, "spree_glow", "ARTWORK", 1, true)
    -- the frame and the next laid over it: the old stays whole underneath, never see-through
    s.eye = { P.Tex(frame, EYE_SHEET, "ARTWORK", 3), P.Tex(frame, EYE_SHEET, "ARTWORK", 4) }
    s.landFlash = P.Tex(frame, "spree_glow", "OVERLAY", 2, true)
    s.flash = P.Tex(frame, "spree_glow", "OVERLAY", 3, true)
    s.dust = P.Burst(frame, d.dust, { t0 = d.start + d.slam + EYE_HIT / EYE_FPS, cx = hx, cy = hy, speed = 220 * k, life = 0.5,
        size = 14 * k, file = "fx_dust", add = false, tint = { 0.3, 0.2, 0.35 }, seed = 81 })
    s.sparks = P.Burst(frame, d.sparks, { t0 = d.start + d.slam + EYE_HIT / EYE_FPS, cx = hx, cy = hy, speed = 300 * k,
        life = 0.45, size = d.k < 1 and 5 or 9, stretch = 2, tint = { 1, 0.3, 0.2 }, seed = 82 })
    return s
end

local function DrawEye(frame, P, s, age, d)
    local E, S, Y = P.E, d.size, d.y
    local land = d.start + d.slam
    local hit = land + EYE_HIT / EYE_FPS
    local hx, hy = EYE_HIT_X * S, Y + EYE_HIT_Y * S
    -- the seal comes in at 2.2 times and lands, rocking a little; the sheet plays from its landing
    local kq = P.prog(age, d.start, d.slam, E.inQ)
    local sc = age < land and P.lerp(2.2, 1, kq) or 1 + 0.08 * math.exp(-(age - land) * 12) * math.cos((age - land) * 30)
    local a = P.prog(age, d.start, 0.06)
    local j = (Jolt(age, hit, d.jolt) + Jolt(age, land, 6)) * d.k
    local t = age - land
    local pos = t < 0 and 0 or math.min(15, t * EYE_FPS)
    -- the eye's red behind it from the frame it glows, breathing
    local glowAt = land + EYE_GLOW / EYE_FPS
    if age >= glowAt then
        P.Set(frame, s.glow, { y = Y, w = S * 1.5, h = S * 1.5, a = P.prog(age, glowAt, 0.3) * (0.55 + 0.15 * math.sin(age * 5)),
            cr = 0.85, cg = 0.08, cb = 0.05 })
    else
        s.glow:Hide()
    end
    if age >= land then
        P.Set(frame, s.landFlash, { y = Y, w = S * 1.8, h = S * 1.4, a = 0.6 * math.exp(-(age - land) * 9), cr = 0.75, cg = 0.55, cb = 1 })
    else
        s.landFlash:Hide()
    end
    local i = math.floor(pos)
    local w = pos - i
    local o = { y = Y + j, w = S, h = S, s = sc }
    if i >= 15 or w < 0.4 then
        o.coord, o.a = EYE_CELL(i), a
        P.Set(frame, s.eye[1], o)
        s.eye[2]:Hide()
    else
        local fresh = P.clamp((w - 0.4) / 0.4)
        local old = 1 - P.clamp((w - 0.8) / 0.2)
        o.coord, o.a = EYE_CELL(i), a * old
        P.Set(frame, s.eye[1], o)
        P.Set(frame, s.eye[2], { y = Y + j, w = S, h = S, s = sc, coord = EYE_CELL(i + 1), a = a * fresh })
    end
    if age >= hit then
        P.Set(frame, s.flash, { x = hx, y = hy, w = S * 1.5, h = S, a = 0.85 * math.exp(-(age - hit) * 7), cr = 1, cg = 0.3, cb = 0.2 })
    else
        s.flash:Hide()
    end
    s.dust(age)
    s.sparks(age)
end

GK.FX.deathlist = {
    land = EYE_WORD + 0.1,             -- the line and the glow come after the word, and the hold counts from them
    voice = false,                     -- no call (the owner's pick in the lab: "Kallet: Ingen"); its cues are its sound
    cues = { { EYE_LAND, "boom" }, { EYE_HIT_T, 1305792 } },
    build = function(splash, P)
        local s = BuildEye(splash, P, EYE_SPLASH)
        s.gloom = P.Tex(splash, "fx_gloom", "BACKGROUND", 2)
        s.head = P.Headline(splash, "DEATH LIST", EYE_WORD_COLOUR, WORD_GLOW, WORD_FLASH,
            P.HeadOver(EYE_SPLASH.y - EYE_SPLASH.size * EYE_ART / 2))
        splash.deathlist = s
    end,
    update = function(splash, age, P)
        local s = splash.deathlist
        P.Set(splash, splash.seal, { a = 0 })            -- the eye is where the seal would be
        P.Set(splash, s.gloom, { y = EYE_SPLASH.y, w = EYE_SPLASH.size * 1.9, h = EYE_SPLASH.size * 1.6, a = 0.6 * P.prog(age, 0, 0.2) })
        DrawEye(splash, P, s, age, EYE_SPLASH)
        P.DrawHeadline(splash, s.head, age, EYE_WORD)
        -- the line up under the eye (Announce.lua puts it back for the next splash)
        splash.line:ClearAllPoints()
        splash.line:SetPoint("TOP", splash, "TOP", 0,
            -P.SEAL / 2 - (EYE_SPLASH.y + EYE_SPLASH.size * EYE_ART / 2 + 14))
    end,
}

GK.TOASTFX.deathlist = {
    voice = false,
    cues = { { EYE_T_LAND, "boom" }, { EYE_T_HIT, 1305792 } },
    build = function(toast, P)
        toast.fxOrigin = { point = "TOPLEFT", x = 32, y = -32 }      -- the toast's seal's centre (FxToast.lua)
        toast.deathlist = BuildEye(toast, P, EYE_TOAST)
    end,
    update = function(toast, age, P)
        P.Set(toast, toast.seal, { a = 0 })
        DrawEye(toast, P, toast.deathlist, age, EYE_TOAST)
    end,
}
