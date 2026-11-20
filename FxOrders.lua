-- Grudgekeeper - a kill order fulfilled: the target's WANTED poster, pinned, crossed out and stamped.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
--
-- Not a spree's: a kill order is a contract, so its end is paper, not fire ("kanskje noe helt annet enn de vi
-- har for streaks?", the owner, 2026-11-18; "prøv 1-2-3", 2026-11-19). The poster slaps up where the seal would
-- be, the target's face in its window as their portrait is everywhere else (GK.SetPortrait), in its own colours;
-- a dagger pins it, the face is crossed out in red ink, two strokes, and FULFILLED is stamped across it. Your
-- own order is the splash (GK.FX), a guildie's the toast (GK.TOASTFX), which has no dagger: too small for one.
-- The art is Codex's, made for this (art/import_grudgekeeper.py, fulfilled()): fx_poster, fx_dagger, fx_ink_a
-- and fx_ink_b. The stamp is the old banner's (stamp_fulfilled).
--
-- The face is placed by hand (Place), not with P.Set: a class's crest, and a race's face in the old portraits,
-- is a corner of one file, and P.Set gives a texture the whole file when it is given no coordinates. So the
-- poster never turns either - a turn throws the corner away too (Effects.lua). It shakes instead.
local ADDON, GK = ...

GK.FX = GK.FX or {}
GK.TOASTFX = GK.TOASTFX or {}

-- Where things are on fx_poster, as parts of its side (printed by the import): the window the face shows
-- through. The paper is 0.76 of the side wide and all of it high.
local WIN_L, WIN_R, WIN_T, WIN_B = 0.305, 0.688, 0.273, 0.660
local WIN_CX, WIN_CY, WIN_SIDE = (WIN_L + WIN_R) / 2 - 0.5, (WIN_T + WIN_B) / 2 - 0.5, WIN_R - WIN_L
local FACE_K, INK_K = 1.04, 1.3             -- the face a little over the window's frame, the cross well past it
local DAGGER_IN = 0.488                     -- fx_dagger: where its blade goes in, below its centre (of its side)
local BACKING = { 0.59, 0.44, 0.27 }        -- the paper behind it: a race's face has corners of its own
local STAMP_TINT = { 1, 0.55, 0.5 }         -- stamp_fulfilled a shade deeper: on the tan paper it read pale
local NAME_FONT = "Fonts\\MORPHEUS.ttf"

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

--- The face on the poster: the target's race's face, else their class, else the skull (GK.SetPortrait), in its
--- own colours: B in the effect lab, which the owner picked over A's sepia (2026-11-19).
--- item.face is the sample's; a real order has the target's key and class (the order's), and what we kept
--- of their looks: "wanted burde ha race icon tilhørende rasen til den som var wanted" (the owner,
--- 2026-11-20). A race's face needs race and sex, and an order names no sex, so with neither seen nor kept
--- it is their class's crest - never a skull while the order knows their class.
local function Face(tex, item)
    local face = type(item.face) == "table" and item.face
        or (GK.FaceOf and type(item.targetKey) == "string" and GK.FaceOf(item.targetKey, item.targetClass)) or {}
    if GK.SetPortrait then GK.SetPortrait(tex, face) end
    tex:SetDesaturated(false)
    tex:SetVertexColor(1, 1, 1)
end

--- One ink stroke, q (0..1) of it drawn: ink_a from its left (it runs from the top left), ink_b from its right.
local function Stroke(frame, P, t, q, x, y, side, fromRight)
    if q <= 0 then t:Hide() return end
    local w = side * q
    P.Set(frame, t, { x = fromRight and x + side / 2 - w / 2 or x - side / 2 + w / 2, y = y, w = w, h = side,
        coord = fromRight and { 1 - q, 1, 0, 1 } or { 0, q, 0, 1 }, a = 0.95 })
end

--- The poster's own parts, the same in a splash and a toast: the paper behind the face, the face, the poster
--- and the cross, each texture's layer under the next.
local function BuildPoster(frame, P, s)
    s.backing = P.Tex(frame, nil, "ARTWORK", 3)
    s.backing:SetColorTexture(1, 1, 1, 1)
    s.face = P.Tex(frame, nil, "ARTWORK", 4)
    s.poster = P.Tex(frame, "fx_poster", "ARTWORK", 5)
    s.inkA = P.Tex(frame, "fx_ink_a", "OVERLAY", 1)
    s.inkB = P.Tex(frame, "fx_ink_b", "OVERLAY", 1)
end

--- Draw the poster at side px, its middle oy below where it hangs, alpha a; the cross q1 and q2 drawn.
local function DrawPoster(frame, P, s, side, oy, a, q1, q2)
    local wx, wy, ws = WIN_CX * side, WIN_CY * side + oy, WIN_SIDE * side
    P.Set(frame, s.backing, { x = wx, y = wy, w = ws * FACE_K, h = ws * FACE_K, a = a,
        cr = BACKING[1], cg = BACKING[2], cb = BACKING[3] })
    Place(frame, s.face, wx, wy, ws * FACE_K, a)
    P.Set(frame, s.poster, { y = oy, w = side, h = side, a = a })
    Stroke(frame, P, s.inkA, q1, wx, wy, ws * INK_K, false)
    Stroke(frame, P, s.inkB, q2, wx, wy, ws * INK_K, true)
end

--- A poster's jolt as something hits it at t0: down by px, rocking back and settling.
local function Jolt(age, t0, px)
    if age < t0 then return 0 end
    return px * math.exp(-(age - t0) * 13) * math.cos((age - t0) * 38)
end

-- ---------------------------------------------------------------------------
-- The splash: your own order
-- ---------------------------------------------------------------------------
local POSTER = 240                   -- fx_poster's side on the splash; the seal it stands in for is 170
local DAG, DAG_R = 110, -0.42        -- the dagger's side, and its lean: anticlockwise, its hilt out to the left
local ENTRY_X, ENTRY_Y = -70, -100   -- where its blade goes in: the poster's top left corner
local NAME_Y = 90                    -- the name, on the band under the window
local STAMP_Y, STAMP_R, STAMP_W = 42, -0.25, 200
local DAGGER_AT, INK_A, INK_B, STAMP_AT, INK_TIME = 0.5, 0.74, 0.96, 1.35, 0.16

GK.FX.order_fulfilled = {
    land = STAMP_AT,                 -- the line and the glow come with the stamp, and the hold counts from it
    voice = 0,                       -- the order's own sound (the game's PvP alert) as it shows, as before
    cues = { { 0, "whoosh_50" }, { DAGGER_AT - 0.04, "schwing" }, { DAGGER_AT, "stamp" }, { INK_A, "whoosh_50" },
        { STAMP_AT - 0.12, "whoosh_50" }, { STAMP_AT, "boom" }, { STAMP_AT, "stamp" } },
    build = function(splash, P)
        local s = {}
        BuildPoster(splash, P, s)
        s.name = splash:CreateFontString(nil, "OVERLAY")
        s.name:SetFont(NAME_FONT, 18, "")
        s.name:SetTextColor(0.24, 0.11, 0.04)
        s.name:SetWidth(POSTER * 0.66)
        s.name:SetWordWrap(false)
        s.name:Hide()
        splash.fxParts[#splash.fxParts + 1] = s.name      -- so the kit's HideAll hides it with the textures
        s.shadow = P.Tex(splash, "fx_dagger", "OVERLAY", 2)
        s.dagger = P.Tex(splash, "fx_dagger", "OVERLAY", 3)
        s.stamp = P.Tex(splash, "stamp_fulfilled", "OVERLAY", 4)
        s.splinters = P.Burst(splash, 10, { t0 = DAGGER_AT, cx = ENTRY_X, cy = ENTRY_Y, speed = 150, life = 0.4,
            size = 9, file = "fx_dust", add = false, tint = { 0.85, 0.68, 0.45 }, seed = 41 })
        s.dust = P.Burst(splash, 14, { t0 = STAMP_AT, cy = STAMP_Y, speed = 200, life = 0.5, size = 18,
            file = "fx_dust", add = false, tint = { 0.8, 0.75, 0.7 }, seed = 29 })
        splash.fulfilled = s
    end,
    start = function(splash, item, P)
        local s = splash.fulfilled
        Face(s.face, item)
        local name = tostring(item.target or "")
        s.name:SetFont(NAME_FONT, #name > 14 and 14 or 18, "")
        s.name:SetText(name)
    end,
    update = function(splash, age, P)
        local s, E = splash.fulfilled, P.E
        P.Set(splash, splash.seal, { a = 0 })            -- the poster is where the seal would be
        -- it slaps up from a little large and high, and the dagger and then the stamp each jolt it
        local inn = P.prog(age, 0, 0.28, E.outBack)
        local side = POSTER * (1 + 0.25 * (1 - inn))
        local oy = -40 * (1 - inn) + Jolt(age, DAGGER_AT, 7) + Jolt(age, STAMP_AT, 4)
        DrawPoster(splash, P, s, side, oy, P.prog(age, 0, 0.1),
            P.prog(age, INK_A, INK_TIME, E.outQ), P.prog(age, INK_B, INK_TIME, E.outQ))
        s.name:ClearAllPoints()
        s.name:SetPoint("CENTER", splash, "TOP", 0, -P.SEAL / 2 - (NAME_Y + oy))
        s.name:SetAlpha(P.prog(age, 0.22, 0.12))         -- once the poster has settled: the name does not scale
        s.name:Show()
        -- the dagger flies in along its own blade, from in front, and stays in the poster as it jolts
        if age < DAGGER_AT - 0.12 then
            s.dagger:Hide()
            s.shadow:Hide()
        else
            local f = P.prog(age, DAGGER_AT - 0.12, 0.12, E.inQ)
            local scale = P.lerp(1.6, 1, f)
            local ux, uy = -math.sin(DAG_R), math.cos(DAG_R)     -- along the blade, towards its point
            local back, off = (1 - f) * 220, DAGGER_IN * DAG * scale
            local cx = ENTRY_X - ux * (off + back)
            local cy = ENTRY_Y + Jolt(age, DAGGER_AT, 7) + Jolt(age, STAMP_AT, 4) - uy * (off + back)
            P.Set(splash, s.dagger, { x = cx, y = cy, w = DAG, h = DAG, s = scale, r = DAG_R,
                a = P.prog(age, DAGGER_AT - 0.12, 0.04) })
            P.Set(splash, s.shadow, { x = cx + 6, y = cy + 5, w = DAG, h = DAG, r = DAG_R, cr = 0, cg = 0, cb = 0,
                a = 0.4 * P.prog(age, DAGGER_AT, 0.05) })
        end
        local k = P.prog(age, STAMP_AT - 0.12, 0.12, E.inQ)
        P.Set(splash, s.stamp, { y = STAMP_Y + Jolt(age, STAMP_AT, 4), w = STAMP_W, h = STAMP_W / 2, r = STAMP_R,
            cr = STAMP_TINT[1], cg = STAMP_TINT[2], cb = STAMP_TINT[3],
            s = age < STAMP_AT and P.lerp(2.2, 1, k) or 1 + 0.05 * math.exp(-(age - STAMP_AT) * 12),
            a = age < STAMP_AT - 0.12 and 0 or age < STAMP_AT and k * 0.8 or 1 })
        s.splinters(age)
        s.dust(age)
    end,
}

-- ---------------------------------------------------------------------------
-- The toast: a guildie's order
-- ---------------------------------------------------------------------------
local TOAST_POSTER = 68              -- its paper 52 wide, where the toast's 64 px seal would be
local TOAST_K = TOAST_POSTER / POSTER
local T_INK_A, T_INK_B, T_STAMP, T_INK_TIME = 0.22, 0.36, 0.62, 0.12

GK.TOASTFX.order_fulfilled = {
    cues = { { T_STAMP - 0.12, "whoosh_50" }, { T_STAMP, "stamp" } },
    build = function(toast, P)
        toast.fxOrigin = { point = "TOPLEFT", x = 32, y = -32 }      -- the toast's seal's centre (FxToast.lua)
        local s = {}
        BuildPoster(toast, P, s)
        s.stamp = P.Tex(toast, "stamp_fulfilled", "OVERLAY", 3)
        s.dust = P.Burst(toast, 10, { t0 = T_STAMP, cy = STAMP_Y * TOAST_K, speed = 200 * TOAST_K, life = 0.5,
            size = 18 * TOAST_K, file = "fx_dust", add = false, tint = { 0.8, 0.75, 0.7 }, seed = 31 })
        toast.fulfilled = s
    end,
    start = function(toast, item, P)
        Face(toast.fulfilled.face, item)
    end,
    update = function(toast, age, P)
        local s, E = toast.fulfilled, P.E
        P.Set(toast, toast.seal, { a = 0 })
        local inn = P.prog(age, 0, 0.2, E.outBack)
        DrawPoster(toast, P, s, TOAST_POSTER * (1 + 0.3 * (1 - inn)), Jolt(age, T_STAMP, 2), P.prog(age, 0, 0.08),
            P.prog(age, T_INK_A, T_INK_TIME, E.outQ), P.prog(age, T_INK_B, T_INK_TIME, E.outQ))
        local k = P.prog(age, T_STAMP - 0.12, 0.12, E.inQ)
        P.Set(toast, s.stamp, { y = STAMP_Y * TOAST_K, w = 84, h = 42, r = STAMP_R,
            cr = STAMP_TINT[1], cg = STAMP_TINT[2], cb = STAMP_TINT[3],
            s = age < T_STAMP and P.lerp(2.2, 1, k) or 1 + 0.05 * math.exp(-(age - T_STAMP) * 12),
            a = age < T_STAMP - 0.12 and 0 or age < T_STAMP and k * 0.8 or 1 })
        s.dust(age)
    end,
}
