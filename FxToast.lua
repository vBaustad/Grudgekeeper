-- Grudgekeeper - spree effects: Toasts. K6, your own spree as a toast, and T3 at a toast's size.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
--
-- A toast's effect is a table in GK.TOASTFX, played by the toast's OnUpdate (Announce.lua) as the splash plays
-- GK.FX:
--   build(toast, P)           once per toast frame, to make its textures (P.Tex)
--   start(toast, item, P)     each time it shows: toasts are pooled, so it resets everything it moved
--   update(toast, age, P)     each frame, after the toast has counted its age
-- The kit's P.Set places from a splash's seal, so a toast has its own placer (Put) from its own seal's centre;
-- same coordinates: x right, y DOWN, rotation clockwise radians.
local ADDON, GK = ...

GK.TOASTFX = GK.TOASTFX or {}

local SEAL_CX, SEAL_CY = 32, -32       -- the toast's 64 px seal's centre, from the toast's top left
local RIB_X = 164                      -- the ribbon's centre, from the seal's (4 gap, 128 half of 256, 32 half of the seal)

--- The effect a toast plays: kind is "spree" or "tormentor"; mine whether the spree is the player's own. nil: none.
function GK.ToastEffect(kind, mine)
    if kind == "tormentor" then return "debt_paid" end
    if kind == "spree" and mine then return "spree_burn" end
    return nil
end

--- Place a texture of the toast from its seal's centre: o.x, o.y (y down), o.w by o.h (64) times o.s, turned o.r,
--- alpha o.a, brightness o.b and colour o.cr/cg/cb, o.cell {col, row, cols, rows} of a sheet. An alpha of 0 hides it.
local function Put(toast, t, o)
    local a = o.a == nil and 1 or o.a
    if a <= 0.001 then t:Hide() return end
    local s = o.s or 1
    t:ClearAllPoints()
    t:SetPoint("CENTER", toast, "TOPLEFT", SEAL_CX + (o.x or 0), SEAL_CY - (o.y or 0))
    t:SetSize(math.max(0.01, (o.w or 64) * s), math.max(0.01, (o.h or 64) * s))
    t:SetRotation(-(o.r or 0))
    t:SetAlpha(math.min(1, a))
    local b = o.b or 1
    t:SetVertexColor(b * (o.cr or 1), b * (o.cg or 1), b * (o.cb or 1))
    local c = o.cell
    if c then
        t:SetTexCoord(c[1] / c[3], (c[1] + 1) / c[3], c[2] / c[4], (c[2] + 1) / c[4])
    else
        t:SetTexCoord(0, 1, 0, 1)
    end
    t:Show()
end

--- A one-shot burst of n sparks from (o.cx, o.cy), as the kit's P.Burst but placed from the toast's seal. o: t0,
--- speed, life, size, stretch, gravity, drag, seed, add (false: plain, as dust), tint. Returns draw(age).
local function Burst(toast, P, n, o)
    local r, ps = P.rng(o.seed or 23), {}
    for i = 1, n do
        local ang = r() * math.pi * 2
        local sp, size = (o.speed or 300) * (0.4 + r() * 0.8), (o.size or 12) * (0.5 + r())
        ps[i] = { t = P.Tex(toast, o.file or "spree_spark", "OVERLAY", 0, o.add ~= false), w = size, h = size * (o.stretch or 1),
            vx = math.cos(ang) * sp, vy = math.sin(ang) * sp, life = (o.life or 0.8) * (0.6 + r() * 0.6),
            rot = o.stretch and ang + math.pi / 2 or r() * 6.28 }
    end
    local tint = o.tint or { 1, 1, 1 }
    return function(age)
        local tt = age - (o.t0 or 0)
        local drag = o.drag or 1.6
        for _, p in ipairs(ps) do
            if tt < 0 or tt > p.life then
                p.t:Hide()
            else
                local k = (1 - math.exp(-drag * tt)) / drag
                Put(toast, p.t, { x = (o.cx or 0) + p.vx * k, y = (o.cy or 0) + p.vy * k + 0.5 * (o.gravity or 0) * tt * tt,
                    w = p.w, h = p.h, r = p.rot, a = 1 - tt / p.life, cr = tint[1], cg = tint[2], cb = tint[3] })
            end
        end
    end
end

--- Embers that loop on their own clocks, rising: n of them, from y (+- ySpread) and x (+- spread). Returns
--- draw(t, a, cx, count): count of them shown, about cx.
local function Motes(toast, P, n, o)
    local r, ms = P.rng(o.seed or 3), {}
    for i = 1, n do
        ms[i] = { t = P.Tex(toast, "spree_spark", "OVERLAY", 0, true), x = (r() - 0.5) * 2 * (o.spread or 20),
            y = (o.y or 0) + (r() - 0.5) * 2 * (o.ySpread or 0), vx = (r() - 0.5) * (o.drift or 20),
            rise = (o.rise or 30) * (0.7 + r() * 0.6), life = (o.life or 1) + r() * (o.lifeVar or 0.6),
            born = r() * 2, size = (o.size or 8) + r() * (o.sizeVar or 0) }
    end
    return function(t, a, cx, count)
        for i, m in ipairs(ms) do
            if i > (count or n) then
                m.t:Hide()
            else
                local tt = (t + m.born) % m.life
                local f = tt / m.life
                Put(toast, m.t, { x = (cx or 0) + m.x + m.vx * tt, y = m.y - m.rise * tt, w = m.size, h = m.size,
                    a = (1 - f) * math.min(1, f * 5) * a })
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- K6: your own spree as a toast
-- ---------------------------------------------------------------------------
-- It slides in from the right and punches, with the tier's fire behind the seal and embers; past Grudgebound's
-- 15 the count slams onto the end of the ribbon, hot and cooling. Left out: the shine across the ribbon (a
-- toast has none), and the sound and shake.
local FLAME_FRAMES, FLAME_COLS, FLAME_ROWS, FLAME_FPS = 16, 4, 4, 12      -- as the splash plays the sheet
local NUM_AT = 0.6                                       -- when the count slams on
local NUM_X, NUM_Y = RIB_X + 118, -20                    -- the count's middle, from the seal's: near the ribbon's end
local FALLBACK_FIRE = { size = 2.15, alpha = 0.85, embers = 10 }

-- The count's middle, as P.Number places it: from a splash's seal, 85 under its top and in its middle. Here
-- the toast's top middle (it is 324 wide) is 130 right of the seal's centre and 32 above, so the kit's own
-- numerals can be used as they are with the difference taken out.
local function NumberAt(x, y)
    return x + SEAL_CX - 162, y - (85 - 32)
end

GK.TOASTFX.spree_burn = {
    build = function(toast, P)
        local s = {}
        s.glow = P.Tex(toast, "spree_glow", "BACKGROUND", 0, true)
        s.flames = P.Tex(toast, "spree_flames", "BACKGROUND", 1)
        s.trail = Motes(toast, P, 10, { y = 0, spread = 10, ySpread = 18, rise = 10, drift = 60, life = 0.35,
            lifeVar = 0.2, size = 8, seed = 11 })
        s.embers = Motes(toast, P, 11, { y = -20, spread = 26, rise = 30, size = 7, sizeVar = 5, seed = 13 })
        s.sparks = Burst(toast, P, 16, { t0 = 0.35, speed = 260, life = 0.5, size = 9, stretch = 2.4, gravity = 200, seed = 17 })
        s.num = P.Number(toast, 4)
        s.numSparks = Burst(toast, P, 14, { t0 = NUM_AT, cx = NUM_X, cy = NUM_Y, speed = 220, life = 0.45, size = 8,
            stretch = 2.4, gravity = 260, seed = 5 })
        toast.burn = s
    end,
    start = function(toast, item, P)
        local s = toast.burn
        s.fire = GK.SPREE_FIRE and GK.SPREE_FIRE[item.fire] or FALLBACK_FIRE
        s.count = math.max(1, math.floor(s.fire.embers / 2 + 0.5))
        local top = GK.SPREE_TIERS and GK.SPREE_TIERS[#GK.SPREE_TIERS].n or 15
        s.hasNum = item.fire == "grudgebound" and (tonumber(item.spree) or 0) > top
        s.heat = s.hasNum and P.clamp((item.spree - top) / 35) or 0
        if s.hasNum then s.num.set("×" .. item.spree) end
    end,
    update = function(toast, age, P)
        local s = toast.burn
        local f = s.fire
        local E = P.E
        local inn = P.prog(age, 0, 0.35, E.outBack)
        local dx = (1 - inn) * 420
        local punch = age > 0.35 and 1 + 0.25 * math.exp(-(age - 0.35) * 10) * math.cos((age - 0.35) * 25) or 1
        local lit = P.prog(age, 0.3, 0.2)
        Put(toast, s.glow, { x = dx, w = 120, h = 120, a = (0.4 + 0.2 * math.sin(age * 6)) * lit })
        local i = math.floor(age * FLAME_FPS) % FLAME_FRAMES
        Put(toast, s.flames, { x = dx, y = -3, w = 64 * f.size, h = 64 * f.size, a = f.alpha * lit,
            cell = { i % FLAME_COLS, math.floor(i / FLAME_COLS), FLAME_COLS, FLAME_ROWS } })
        Put(toast, toast.seal, { x = dx, s = punch })
        if toast.hasRibbon then Put(toast, toast.ribbon, { x = RIB_X + dx, w = 256, h = 64 }) end
        toast.line:SetAlpha(P.prog(age, 0.3, 0.3))
        s.trail(age, age < 0.4 and 1 or 0, RIB_X + 110 + dx)
        s.embers(age - 0.35, age > 0.35 and 1 or 0, 0, s.count)
        s.sparks(age)
        if not s.hasNum then return end
        s.numSparks(age)
        local x, y = NumberAt(NUM_X, NUM_Y)
        local grow = age < NUM_AT and P.lerp(2.6, 1, P.prog(age, NUM_AT - 0.12, 0.12, E.inQ))
            or 1 + 0.1 * math.exp(-(age - NUM_AT) * 10) * math.cos((age - NUM_AT) * 34)
        s.num.place({ x = x, y = y, h = 40, r = -0.14, s = grow, a = P.prog(age, NUM_AT - 0.12, 0.05),
            heat = age >= NUM_AT and math.max(s.heat * 0.7, 1.3 * math.exp(-(age - NUM_AT) * 2.2)) or 0.8 })
    end,
}

-- ---------------------------------------------------------------------------
-- T3: a tormentor's debt, the PAID stamp slamming onto the black seal
-- ---------------------------------------------------------------------------
-- The splash's card at 64 px: 150 down to 64 is 0.427 of it. stamp_paid is green, and a tint only multiplies,
-- so it is desaturated first and the red laid on that. The dust is the lab's (fx_dust).
local PAID_AT, PAID_K = 0.45, 64 / 150

GK.TOASTFX.debt_paid = {
    build = function(toast, P)
        local s = {}
        s.stamp = P.Tex(toast, "stamp_paid", "OVERLAY", 3)
        s.stamp:SetDesaturated(true)
        s.dust = Burst(toast, P, 14, { file = "fx_dust", t0 = PAID_AT, speed = 200 * PAID_K, life = 0.5, size = 18 * PAID_K, add = false,
            tint = { 0.8, 0.75, 0.7 }, seed = 29 })
        toast.paid = s
    end,
    start = function() end,
    update = function(toast, age, P)
        local s = toast.paid
        Put(toast, toast.seal, { a = P.prog(age, 0, 0.15), s = 1 + 0.2 * (1 - P.prog(age, 0, 0.2, P.E.outC)) })
        local k = P.prog(age, PAID_AT - 0.12, 0.12, P.E.inQ)
        Put(toast, s.stamp, { y = 10 * PAID_K, w = 210 * PAID_K, h = 105 * PAID_K, r = -0.25, cr = 1, cg = 0.3, cb = 0.25,
            s = age < PAID_AT and P.lerp(2.2, 1, k) or 1 + 0.05 * math.exp(-(age - PAID_AT) * 12),
            a = age < PAID_AT - 0.12 and 0 or age < PAID_AT and k * 0.8 or 1 })
        s.dust(age)
    end,
}
