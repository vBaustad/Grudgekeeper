-- Grudgekeeper - a kill order fulfilled: the target's WANTED poster crossed out, and what lands on it - a purse of
-- gold when there was gold in the pot, a heavy stamp when there was none - under KILL ORDER FULFILLED.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
--
-- Not a spree's: a kill order is a contract, so its end is paper, not fire ("kanskje noe helt annet enn de vi
-- har for streaks?", the owner, 2026-11-18). The poster slaps up where the seal would be, the target's face in its
-- window, and two strokes of red ink cross the face out. Then, P and S in the effect lab's round 6 (the owner,
-- 2026-11-21: "pengebaggen om det er gold å få, stempel hvis ikke"): with gold in the pot a fat purse falls onto
-- the poster as the tormentor's book falls, squashes and hops, and the coins burst out of its neck, spinning; with
-- none, a brass stamp falls onto it, stays a blink and lifts away toward the camera, leaving FULFILLED in red.
-- KILL ORDER FULFILLED slams down above, the kit's headline (P.Headline), and the line under the poster says who
-- got them and the gold (Announce.lua's splashLine). Your own order is the splash (GK.FX), a guildie's the toast
-- (GK.TOASTFX): the same, smaller, without the headline. Until then (1.10.0) a dagger pinned the poster and the
-- old FULFILLED stamp was slapped on.
-- The art is Codex's, made for this: fx_poster, fx_ink_a and fx_ink_b (art/import_grudgekeeper.py, fulfilled()),
-- fx_purse, fx_stamp and the spinning coin's sheet fx_coins (art/import_orders.py). The imprint is the old
-- banner's stamp_fulfilled, the dust the tormentor's fx_dust_burst.
--
-- The face is placed by hand (Place), not with P.Set: a class's crest, and a race's face in the old portraits,
-- is a corner of one file, and P.Set gives a texture the whole file when it is given no coordinates. So the
-- poster never turns either - a turn throws the corner away too (Effects.lua). It jolts and shakes instead, and
-- the coins, cells of a sheet, spin in their drawn frames, never by a turn.
local ADDON, GK = ...

GK.FX = GK.FX or {}
GK.TOASTFX = GK.TOASTFX or {}

-- Where things are on fx_poster, as parts of its side (printed by the import): the window the face shows
-- through. The paper is 0.76 of the side wide and all of it high.
local WIN_L, WIN_R, WIN_T, WIN_B = 0.305, 0.688, 0.273, 0.660
local WIN_CX, WIN_CY, WIN_SIDE = (WIN_L + WIN_R) / 2 - 0.5, (WIN_T + WIN_B) / 2 - 0.5, WIN_R - WIN_L
local FACE_K, INK_K = 1.04, 1.3             -- the face a little over the window's frame, the cross well past it
local BACKING = { 0.59, 0.44, 0.27 }        -- the paper behind it: a race's face has corners of its own
local STAMP_TINT = { 1, 0.55, 0.5 }         -- stamp_fulfilled a shade deeper: on the tan paper it read pale
local SPLAT = { 0.55, 0.06, 0.04 }          -- the stamp's ink spattered round it
local ORDER_WORD, ORDER_GLOW, ORDER_FLASH = { 0.94, 0.87, 0.71 }, { 0.75, 0.16, 0.06 }, { 1, 0.82, 0.55 }  -- parchment
local DUST_LINE = 0.087                     -- fx_dust_burst's first streak, below its cell's middle (FxEnded.lua's T4)
local LINE_Y = 142                          -- the line's top, under the poster and what lies on it

--- A texture put where P.Set would put it, with its texture coordinates left alone (a crest's corner), shaken
--- with the frame as P.Set's are.
local function Place(frame, t, x, y, side, a)
    if a <= 0.001 then t:Hide() return end
    local at = frame.fxOrigin
    t:ClearAllPoints()
    t:SetPoint("CENTER", frame, at and at.point or "TOP", (at and at.x or 0) + x + (frame.fxShakeX or 0),
        (at and at.y or -GK.FxKit.SEAL / 2) - y - (frame.fxShakeY or 0))
    t:SetSize(side, side)
    t:SetAlpha(math.min(1, a))
    t:Show()
end

--- The race an order on this player says, where we kept one: what a poster shows when nobody saw them. Any
--- order, open or not - the one just fulfilled is closed by now (GK.OrdersOn gives the open ones), and a race
--- stays what it was. Once a poster, so a walk over the orders kept is cheap.
local function OrderRace(key)
    if type(key) ~= "string" or not GK.Store then return nil end
    for _, o in pairs(GK.Store().orders) do
        if o.n == key and type(o.r) == "string" then return o.r end
    end
end

--- The face on the poster, in its own colours (B in the effect lab, which the owner picked over A's sepia,
--- 2026-11-19): our painted face for their race, the same as on the poster they were posted on (GK.WantedFace,
--- Post.lua: "bruk portrettene på fulfilled-plakaten også", the owner, 2026-11-21), else their class's crest,
--- else the skull (GK.SetPortrait). item.face is the sample's; a real order has the target's key and class (the
--- order's), and what we kept of their looks: race and sex. Never seen, the order's race does: a man's face
--- when no sex is known, as an order names none - never a skull while the order knows their class.
local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"
local function Face(tex, item)
    local face = type(item.face) == "table" and item.face
        or (GK.FaceOf and type(item.targetKey) == "string" and GK.FaceOf(item.targetKey, item.targetClass)) or {}
    local file = GK.WantedFace and GK.WantedFace({ rf = face.rf, sx = face.sx,
        r = not face.rf and OrderRace(item.targetKey) or nil })
    if file then
        tex:SetTexture(MEDIA .. file)
        tex:SetTexCoord(0, 1, 0, 1)
    elseif GK.SetPortrait then
        GK.SetPortrait(tex, face)
    end
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

--- The slam's shake of the whole frame, px at most, dying away in 0.6 s: x, y (y down).
local function Quake(age, t0, px)
    if age < t0 or age > t0 + 0.6 then return 0, 0 end
    local t = age - t0
    local d = math.exp(-t * 9) * px
    return d * math.sin(t * 61), 0.78 * d * math.cos(t * 47)
end

--- A cell of a 4 by 4 sheet, as P.Set's coord.
local function Cell(i)
    local col, row = i % 4, math.floor(i / 4)
    return { col / 4, (col + 1) / 4, row / 4, (row + 1) / 4 }
end

--- A sheet's 16 frames played at fps from t, each faded into the next (pair: two textures), o as P.Set's.
local function PlaySheet(frame, P, pair, t, fps, o)
    local f = t * fps
    local i = math.floor(f)
    if t < 0 or i >= 16 then
        pair[1]:Hide()
        pair[2]:Hide()
        return
    end
    local w, a = f - i, o.a or 1
    o.coord, o.a = Cell(i), a * (i + 1 < 16 and 1 or 1 - w)
    P.Set(frame, pair[1], o)
    if i + 1 < 16 then
        o.coord, o.a = Cell(i + 1), a * w
        P.Set(frame, pair[2], o)
    else
        pair[2]:Hide()
    end
end

-- ---------------------------------------------------------------------------
-- The numbers, the lab's line for line: the splash's, and the toast's at 68 px where its 64 px seal would be
-- ---------------------------------------------------------------------------
local POSTER = 240                          -- fx_poster's side on the splash; the seal it stands in for is 170
local PURSE, PURSE_Y = 160, 66              -- fx_purse's square (the purse fills 0.714 of its height), its middle at rest
local PURSE_FOOT = 0.357                    -- the purse's bottom edge below its middle, of its square
local STAMP, IMPRINT_Y, IMPRINT_R = 200, 42, -0.25   -- fx_stamp's square (the stamp fills 0.8 of it); the imprint
local STAMP_ON = 0.31                       -- the stamp's middle above the imprint at rest, of its square: its face on it
local LIFT, WORD = 0.18, 0.22               -- after the impact: the stamp lifts away; the headline lands

local SPLASH = { k = 1, inn = 0.28, grow = 0.25, drop = 40, fadeIn = 0.1, inkA = 0.24, inkB = 0.38, inkT = 0.14,
    fall0 = 0.36, impact = 0.62, from = -360, coins = 11, debris = 16, stampDebris = 14, quakePurse = 7, quakeStamp = 6 }
local TOAST = { k = 68 / 240, inn = 0.2, grow = 0.3, drop = 0, fadeIn = 0.08, inkA = 0.16, inkB = 0.26, inkT = 0.1,
    fall0 = 0.28, impact = 0.48, from = -90, coins = 4, debris = 6, stampDebris = 6, quakePurse = 2, quakeStamp = 2 }

--- Everything a kill order fulfilled draws, for the numbers d; the headline only on the splash. Both the purse and
--- the stamp are made: start says which one this order gets (s.gold), and the other is never shown.
local function BuildOrder(frame, P, d, headline)
    local k, s = d.k, {}
    if headline then
        s.gloom = P.Tex(frame, "fx_gloom", "BACKGROUND", 2)
        s.head = P.Headline(frame, "KILL ORDER FULFILLED", ORDER_WORD, ORDER_GLOW, ORDER_FLASH, P.HeadOver(-POSTER * k / 2))
    end
    BuildPoster(frame, P, s)
    -- the purse, its shadow and dust, and its coins, each with a glint
    s.purseShadow = P.Tex(frame, "fx_gloom", "OVERLAY", 2)
    s.purseRing = P.Tex(frame, "glow", "OVERLAY", 2)
    s.purseDust = { P.Tex(frame, "fx_dust_burst", "OVERLAY", 2), P.Tex(frame, "fx_dust_burst", "OVERLAY", 2) }
    s.purse = P.Tex(frame, "fx_purse", "OVERLAY", 3)
    local foot = (PURSE_Y + PURSE_FOOT * PURSE) * k
    s.purseDebris = P.Burst(frame, d.debris, { t0 = d.impact, cy = foot - 6 * k, speed = 300 * k, life = 0.7, size = 11 * k,
        file = "fx_dust", add = false, tint = { 0.62, 0.5, 0.36 }, gravity = 800 * k, angle = -math.pi / 2, arc = 2.6,
        seed = 93 })
    local r = P.rng(91)
    s.coins = {}
    for i = 1, d.coins do
        local c = {}
        local out = r() < 0.5 and -1 or 1
        c.vx = out * (40 + r() * 190)
        c.vy = -(330 + r() * 280)
        c.fps = 14 + r() * 14
        c.ph = math.floor(r() * 16)
        c.size = 24 + r() * 14
        c.life = 0.85 + r() * 0.45
        c.delay = r() * 0.08
        c.t = P.Tex(frame, "fx_coins", "OVERLAY", 5)
        c.glint = P.Tex(frame, "spree_spark", "OVERLAY", 6, true)
        s.coins[i] = c
    end
    -- the stamp, its shadow and dust, the imprint it leaves and the ink spattered round it
    s.splatA = P.Tex(frame, "fx_splat_1", "OVERLAY", 2)
    s.splatB = P.Tex(frame, "fx_splat_1", "OVERLAY", 2)
    s.imprint = P.Tex(frame, "stamp_fulfilled", "OVERLAY", 3)
    s.stampShadow = P.Tex(frame, "fx_gloom", "OVERLAY", 4)
    s.stampRing = P.Tex(frame, "glow", "OVERLAY", 4)
    s.stamp = P.Tex(frame, "fx_stamp", "OVERLAY", 5)
    s.stampDebris = P.Burst(frame, d.stampDebris, { t0 = d.impact, cy = IMPRINT_Y * k, speed = 260 * k, life = 0.6,
        size = 10 * k, file = "fx_dust", add = false, tint = { 0.62, 0.5, 0.36 }, gravity = 700 * k,
        angle = -math.pi / 2, arc = 2.8, seed = 97 })
    s.flash = P.Tex(frame, "spree_glow", "OVERLAY", 7, true)
    return s
end

--- The purse: it falls from above, faster and faster, turning straight and coming a little toward the camera,
--- its shadow growing on the paper; it strikes the poster's foot, squashed flat, a flash and a ring of dust, and
--- the coins burst out of its neck. Once down it lies on the poster and jolts with it (jolt), with no hop of its
--- own: one that moved apart looked loose on the paper (the owner in game, 2026-11-21).
local function DrawPurse(frame, P, s, age, d, jolt)
    local k, E, impact = d.k, P.E, d.impact
    local ps, gy = PURSE * k, PURSE_Y * k
    local foot = gy + PURSE_FOOT * ps
    local f = P.prog(age, d.fall0, impact - d.fall0, E.inQ)
    local y, rot, sc, sx, sy = P.lerp(d.from, gy, f), P.lerp(-0.5, 0, E.outQ(f)), P.lerp(1.35, 1, f), 1, 1
    if age >= impact then
        local t = age - impact
        local e = math.exp(-t * 11) * math.cos(t * 26)
        sx, sy = 1 + 0.2 * e, 1 - 0.2 * e
        y = gy + jolt + (1 - sy) * PURSE_FOOT * ps
        rot = 0.06 * math.exp(-t * 5) * math.sin(t * 16)
        sc = 1
    end
    P.Set(frame, s.purseShadow, { y = foot + jolt, w = ps * 0.9, h = ps * 0.3, s = P.lerp(0.35, 1, f), a = 0.75 * f })
    P.Set(frame, s.purse, { y = y, w = ps, h = ps, s = sc, sx = sx, sy = sy, r = rot, a = P.prog(age, d.fall0, 0.05) })
    s.purseDebris(age)
    if age < impact then
        s.flash:Hide()
        s.purseRing:Hide()
        PlaySheet(frame, P, s.purseDust, -1, 22, {})
        for _, c in ipairs(s.coins) do
            c.t:Hide()
            c.glint:Hide()
        end
        return
    end
    local t = age - impact
    P.Set(frame, s.flash, { y = foot - ps * 0.15, w = ps * 2.4, h = ps * 1.3, a = 0.85 * math.exp(-t * 9),
        cr = 1, cg = 0.85, cb = 0.6 })
    local q = P.prog(t, 0, 0.55, E.outQ)
    P.Set(frame, s.purseRing, { y = foot + jolt, w = ps * 0.9, h = ps * 0.3, s = P.lerp(0.4, 2.6, q), a = 0.75 * (1 - q),
        cr = 0.85, cg = 0.72, cb = 0.55 })
    PlaySheet(frame, P, s.purseDust, t, 22, { y = foot + jolt - DUST_LINE * 330 * k, w = 330 * k, h = 330 * k, a = 0.85 })
    for _, c in ipairs(s.coins) do
        local tt = t - c.delay
        if tt < 0 or tt > c.life then
            c.t:Hide()
            c.glint:Hide()
        else
            local x, cy = c.vx * k * tt, gy - 0.28 * ps + c.vy * k * tt + 0.5 * 1150 * k * tt * tt
            local ca = 1 - P.prog(tt, c.life - 0.2, 0.2)
            P.Set(frame, c.t, { x = x, y = cy, w = c.size * k, h = c.size * k,
                coord = Cell(math.floor(tt * c.fps + c.ph) % 16), a = ca })
            P.Set(frame, c.glint, { x = x, y = cy, w = c.size * 0.9 * k, h = c.size * 0.9 * k,
                a = ca * 0.35 * (0.5 + 0.5 * math.sin(tt * 30 + c.ph)), cr = 1, cg = 0.85, cb = 0.4 })
        end
    end
end

--- The stamp: it falls onto the poster, its brass face on the imprint's place, and thuds - a flash, ink spattered,
--- dust - stays a blink, jolting with the poster, then lifts away toward the camera and is gone, leaving FULFILLED in
--- red.
local function DrawStamp(frame, P, s, age, d, jolt)
    local k, E, impact = d.k, P.E, d.impact
    local ss, iy = STAMP * k, IMPRINT_Y * k
    local gy, lift = iy - STAMP_ON * ss, impact + LIFT
    if age >= impact then
        local t = age - impact
        local q = P.prog(t, 0, 0.12, E.outQ)
        P.Set(frame, s.splatA, { x = -58 * k, y = iy + 6 * k + jolt, w = 90 * k, h = 90 * k, s = P.lerp(0.3, 1, q), r = 0.8,
            a = 0.7, cr = SPLAT[1], cg = SPLAT[2], cb = SPLAT[3] })
        P.Set(frame, s.splatB, { x = 64 * k, y = iy - 10 * k + jolt, w = 70 * k, h = 70 * k, s = P.lerp(0.3, 1, q), r = 2.4,
            a = 0.6, cr = SPLAT[1], cg = SPLAT[2], cb = SPLAT[3] })
        P.Set(frame, s.imprint, { y = iy + jolt, w = 200 * k, h = 100 * k, r = IMPRINT_R, s = 1 + 0.04 * math.exp(-t * 10),
            cr = STAMP_TINT[1], cg = STAMP_TINT[2], cb = STAMP_TINT[3] })
    else
        s.splatA:Hide()
        s.splatB:Hide()
        s.imprint:Hide()
    end
    local f = P.prog(age, d.fall0, impact - d.fall0, E.inQ)
    local y, rot, sc, sx, sy = P.lerp(d.from, gy, f), P.lerp(-0.4, 0, E.outQ(f)), P.lerp(1.3, 1, f), 1, 1
    local a, shadow = P.prog(age, d.fall0, 0.05), f
    if age >= impact then
        local t = age - impact
        local e = math.exp(-t * 14) * math.cos(t * 30)
        sx, sy = 1 + 0.12 * e, 1 - 0.12 * e
        y, rot, sc = gy + jolt + (1 - sy) * 0.4 * ss, 0, 1
        if age >= lift then
            local l = P.prog(age, lift, 0.42, E.inQ)
            y, sc, rot = gy - 300 * k * l, P.lerp(1, 1.3, l), 0.18 * l
            a = 1 - P.prog(age, lift + 0.18, 0.24)
            shadow = 1 - P.prog(age, lift, 0.25)
        end
    end
    P.Set(frame, s.stampShadow, { y = iy + jolt + 0.08 * ss, w = ss * 0.7, h = ss * 0.24, s = P.lerp(0.35, 1, f),
        a = 0.75 * shadow })
    P.Set(frame, s.stamp, { y = y, w = ss, h = ss, s = sc, sx = sx, sy = sy, r = rot, a = a })
    if age >= impact then
        local t = age - impact
        P.Set(frame, s.flash, { y = iy, w = ss * 2.2, h = ss * 1.1, a = 0.85 * math.exp(-t * 9), cr = 1, cg = 0.85,
            cb = 0.65 })
        local q = P.prog(t, 0, 0.5, E.outQ)
        P.Set(frame, s.stampRing, { y = iy + jolt + 0.08 * ss, w = ss * 0.8, h = ss * 0.28, s = P.lerp(0.5, 2.4, q),
            a = 0.7 * (1 - q), cr = 0.85, cg = 0.72, cb = 0.55 })
    else
        s.flash:Hide()
        s.stampRing:Hide()
    end
    s.stampDebris(age)
end

--- A kill order fulfilled at its age: the poster slaps up from a little large (on the splash, from a little high),
--- is crossed out stroke by stroke and jolts as what falls on it strikes; the frame shakes with the slam; then the
--- headline, on the splash.
local function DrawOrder(frame, P, s, age, d)
    local k, E, impact = d.k, P.E, d.impact
    frame.fxShakeX, frame.fxShakeY = 0, 0
    if s.gloom then P.Set(frame, s.gloom, { w = 480, h = 440, a = 0.65 * P.prog(age, 0, 0.15) }) end
    -- the shake, before the rest is placed: everything set this frame moves with it, the gloom behind it does not
    frame.fxShakeX, frame.fxShakeY = Quake(age, impact, s.gold and d.quakePurse or d.quakeStamp)
    local inn = P.prog(age, 0, d.inn, E.outBack)
    local side = POSTER * k * (1 + d.grow * (1 - inn))
    local jolt = Jolt(age, impact, (s.gold and 6 or 7) * k)
    DrawPoster(frame, P, s, side, -d.drop * (1 - inn) + jolt, P.prog(age, 0, d.fadeIn),
        P.prog(age, d.inkA, d.inkT, E.outQ), P.prog(age, d.inkB, d.inkT, E.outQ))
    if s.gold then DrawPurse(frame, P, s, age, d, jolt) else DrawStamp(frame, P, s, age, d, jolt) end
    if s.head then P.DrawHeadline(frame, s.head, age, impact + WORD) end
end

--- Which this order gets: the purse when its pot held gold, else the stamp.
local function Gold(item)
    return (tonumber(item.pot) or 0) > 0
end

-- ---------------------------------------------------------------------------
-- The splash: your own order
-- ---------------------------------------------------------------------------
GK.FX.order_fulfilled = {
    land = SPLASH.impact + WORD + 0.1,      -- the line and the hold come with the headline
    -- the order's own sound (the tribal bell, Announce.lua) with the slam, one sound with it: it came as the poster
    -- showed, 0.6 s before the thud (2026-11-21)
    voice = SPLASH.impact,
    -- the poster slaps up with parchment laid down (PutDownParchment_Paper, the owner's pick in the lab's round 8,
    -- 2026-11-21: "pergament legges ned var fin"; the ink strokes stay silent), then the tormentor's book's slam
    cues = { { 0, 567556 }, { SPLASH.impact, "boom" }, { SPLASH.impact, "stamp" } },
    build = function(splash, P)
        splash.fulfilled = BuildOrder(splash, P, SPLASH, true)
    end,
    start = function(splash, item, P)
        local s = splash.fulfilled
        Face(s.face, item)
        s.gold = Gold(item)
    end,
    update = function(splash, age, P)
        P.Set(splash, splash.seal, { a = 0 })            -- the poster is where the seal would be
        splash.glow:Hide()                               -- and the headline's glow stands for the splash's own
        DrawOrder(splash, P, splash.fulfilled, age, SPLASH)
        -- the line under the poster, shaken with it (Announce.lua puts it back for the next splash)
        splash.line:ClearAllPoints()
        splash.line:SetPoint("TOP", splash, "TOP", splash.fxShakeX or 0, -P.SEAL / 2 - LINE_Y - (splash.fxShakeY or 0))
    end,
}

-- ---------------------------------------------------------------------------
-- The toast: a guildie's order
-- ---------------------------------------------------------------------------
GK.TOASTFX.order_fulfilled = {
    voice = TOAST.impact,                    -- the call with the slam, as the splash's
    cues = { { 0, 567556 }, { TOAST.impact, "stamp" } },     -- the parchment as it slaps up, as the splash's
    build = function(toast, P)
        toast.fxOrigin = { point = "TOPLEFT", x = 32, y = -32 }      -- the toast's seal's centre (FxToast.lua)
        toast.fulfilled = BuildOrder(toast, P, TOAST, false)
    end,
    start = function(toast, item, P)
        Face(toast.fulfilled.face, item)
        toast.fulfilled.gold = Gold(item)
    end,
    update = function(toast, age, P)
        P.Set(toast, toast.seal, { a = 0 })
        DrawOrder(toast, P, toast.fulfilled, age, TOAST)
    end,
}
