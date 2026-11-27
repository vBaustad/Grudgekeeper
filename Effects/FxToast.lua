-- Grudgekeeper - spree effects: Toasts. K6, your own spree as a toast, and T3 at a toast's size.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
--
-- A toast's effect is a table in GK.TOASTFX, played by the toast's OnUpdate (Announce.lua) as the splash plays
-- GK.FX:
--   build(toast, P)           once per toast frame, to make its textures (P.Tex)
--   start(toast, item, P)     each time it shows: toasts are pooled, so it resets everything it moved
--   update(toast, age, P)     each frame, after the toast has counted its age
-- The kit's P.Set and P.Burst place from the frame's fxOrigin, which a toast sets to its own seal's centre, so
-- the coordinates are the splash's: x right, y DOWN, rotation clockwise radians. A toast's art is 64 px, not 170:
-- pass w and h.
local ADDON, GK = ...

GK.TOASTFX = GK.TOASTFX or {}

local SEAL_CX, SEAL_CY = 32, -32       -- the toast's 64 px seal's centre, from the toast's top left
local TOAST_SEAL = 64                  -- the toast's seal, and its ribbon's height
local RIB_X = 164                      -- the ribbon's centre, from the seal's (4 gap, 128 half of 256, 32 half of the seal)

--- The effect a toast plays: kind is "spree" or "tormentor"; mine whether the spree is the player's own. nil: none.
--- A guildie's spree burns as yours does, with the count past 15: "jeg forventet grudgeboundx20 men fikk grudgebound
--- og subtitle "20 kill streak"" (the owner, 2026-11-26, of a guildie's 20). A toast is how a guildie's moment
--- shows (a splash is only ever yours), and its effect's sounds go by the guildies' sound setting (item.silent).
function GK.ToastEffect(kind, mine)
    if kind == "tormentor" then return "debt_paid" end
    if kind == "spree" then return "spree_burn" end
    return nil
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
                P.Set(toast, m.t, { x = (cx or 0) + m.x + m.vx * tt, y = m.y - m.rise * tt, w = m.size, h = m.size,
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
-- toast has none), and the shake.
local NUM_AT = 0.6                                       -- when the count slams on
local NUM_X, NUM_Y = RIB_X + 118, -20                    -- the count's middle, from the seal's: near the ribbon's end
local FALLBACK_FIRE = { size = 2.15, alpha = 0.85, embers = 10 }

-- K5's sounds, as K6 adds to them: a whoosh as it slides in (half level) and a thump at the punch; with the count,
-- its whoosh (half level) and the iron (at 0.6). The voice is the toast's own, played at once.
-- the seal stamps in with the stamp: the lab's thump carried a high whine through all of it
local BURN_CUES = { { 0, "whoosh_50" }, { 0.35, "stamp" } }
local BURN_NUM_CUES = { { 0, "whoosh_50" }, { 0.35, "stamp" }, { NUM_AT - 0.1, "whoosh_50" }, { NUM_AT, "clang_60" } }

GK.TOASTFX.spree_burn = {
    build = function(toast, P)
        toast.fxOrigin = { point = "TOPLEFT", x = SEAL_CX, y = SEAL_CY }
        local s = {}
        s.glow = P.Tex(toast, "spree_glow", "BACKGROUND", 0, true)
        s.flames = P.Tex(toast, "spree_flames", "BACKGROUND", 1)
        s.trail = Motes(toast, P, 10, { y = 0, spread = 10, ySpread = 18, rise = 10, drift = 60, life = 0.35,
            lifeVar = 0.2, size = 8, seed = 11 })
        s.embers = Motes(toast, P, 11, { y = -20, spread = 26, rise = 30, size = 7, sizeVar = 5, seed = 13 })
        s.sparks = P.Burst(toast, 16, { t0 = 0.35, speed = 260, life = 0.5, size = 9, stretch = 2.4, gravity = 200, seed = 17 })
        s.num = P.Number(toast, 4)
        s.numSparks = P.Burst(toast, 14, { t0 = NUM_AT, cx = NUM_X, cy = NUM_Y, speed = 220, life = 0.45, size = 8,
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
        toast.cueList = s.hasNum and BURN_NUM_CUES or BURN_CUES
    end,
    update = function(toast, age, P)
        local s = toast.burn
        local f = s.fire
        local E = P.E
        local inn = P.prog(age, 0, 0.35, E.outBack)
        local dx = (1 - inn) * 420
        local punch = age > 0.35 and 1 + 0.25 * math.exp(-(age - 0.35) * 10) * math.cos((age - 0.35) * 25) or 1
        local lit = P.prog(age, 0.3, 0.2)
        P.Set(toast, s.glow, { x = dx, w = 120, h = 120, a = (0.4 + 0.2 * math.sin(age * 6)) * lit })
        P.Set(toast, s.flames, { x = dx, y = -3, w = TOAST_SEAL * f.size, h = TOAST_SEAL * f.size, a = f.alpha * lit,
            coord = P.FlameCell(age) })
        P.Set(toast, toast.seal, { x = dx, w = TOAST_SEAL, h = TOAST_SEAL, s = punch })
        if toast.hasRibbon then P.Set(toast, toast.ribbon, { x = RIB_X + dx, w = 256, h = 64 }) end
        toast.line:SetAlpha(P.prog(age, 0.3, 0.3))
        s.trail(age, age < 0.4 and 1 or 0, RIB_X + 110 + dx)
        s.embers(age - 0.35, age > 0.35 and 1 or 0, 0, s.count)
        s.sparks(age)
        if not s.hasNum then return end
        s.numSparks(age)
        local grow = age < NUM_AT and P.lerp(2.6, 1, P.prog(age, NUM_AT - 0.12, 0.12, E.inQ))
            or 1 + 0.1 * math.exp(-(age - NUM_AT) * 10) * math.cos((age - NUM_AT) * 34)
        s.num.place({ x = NUM_X, y = NUM_Y, h = 40, r = -0.14, s = grow, a = P.prog(age, NUM_AT - 0.12, 0.05),
            heat = age >= NUM_AT and math.max(s.heat * 0.7, 1.3 * math.exp(-(age - NUM_AT) * 2.2)) or 0.8 })
    end,
}

-- ---------------------------------------------------------------------------
-- T3: a tormentor's debt, the PAID stamp slamming onto the black seal
-- ---------------------------------------------------------------------------
-- The splash's card at 64 px: 150 down to 64 is 0.427 of it. stamp_paid is green, and a tint only multiplies,
-- so it is desaturated first and the red laid on that. The dust is the lab's (fx_dust).
local PAID_AT, PAID_K = 0.45, TOAST_SEAL / 150   -- when the stamp lands; the card's size, scaled

GK.TOASTFX.debt_paid = {
    cues = { { PAID_AT - 0.12, "whoosh_50" }, { PAID_AT, "stamp" } },     -- T3's, as the splash's
    build = function(toast, P)
        toast.fxOrigin = { point = "TOPLEFT", x = SEAL_CX, y = SEAL_CY }
        local s = {}
        s.stamp = P.Tex(toast, "stamp_paid", "OVERLAY", 3)
        s.stamp:SetDesaturated(true)
        s.dust = P.Burst(toast, 14, { file = "fx_dust", t0 = PAID_AT, speed = 200 * PAID_K, life = 0.5, size = 18 * PAID_K, add = false,
            tint = { 0.8, 0.75, 0.7 }, seed = 29 })
        toast.paid = s
    end,
    update = function(toast, age, P)
        local s = toast.paid
        P.Set(toast, toast.seal, { w = TOAST_SEAL, h = TOAST_SEAL, a = P.prog(age, 0, 0.15), s = 1 + 0.2 * (1 - P.prog(age, 0, 0.2, P.E.outC)) })
        local k = P.prog(age, PAID_AT - 0.12, 0.12, P.E.inQ)
        P.Set(toast, s.stamp, { y = 10 * PAID_K, w = 210 * PAID_K, h = 105 * PAID_K, r = -0.25, cr = 1, cg = 0.3, cb = 0.25,
            s = age < PAID_AT and P.lerp(2.2, 1, k) or 1 + 0.05 * math.exp(-(age - PAID_AT) * 12),
            a = age < PAID_AT - 0.12 and 0 or age < PAID_AT and k * 0.8 or 1 })
        s.dust(age)
    end,
}
