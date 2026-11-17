-- Grudgekeeper - spree effects: Reaper. RP1, the scythe sweep, and RP4, from the smoke (GK.db.reaperEffect picks).
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
local ADDON, GK = ...


--- A shadow round the seal only (nothing covers the whole screen but Grudgebound's), soft to nothing at its edge.
local function Gloom(splash, P)
    return P.Tex(splash, "fx_gloom", "BACKGROUND", -1)
end

-- ---------------------------------------------------------------------------
-- RP1, the scythe sweep
-- ---------------------------------------------------------------------------
-- The scythe hangs from a pivot above the splash (the hands): the shaft runs down to the socket and the blade
-- points forward from it, flipped so its curved edge faces the hands, as the arc the tip draws does. Turning the
-- pivot counter-clockwise swings it left to right through the seal, tip first. Nothing here is nested, so every
-- part is placed by turning its point round the pivot by hand.
local C = 0.24                                   -- when the seal lands, as the blade crosses it
local H = { x = -30, y = -290 }                  -- the pivot, from the seal's centre
local LS = 260                                   -- the shaft, pivot to socket
local K = 260 / 1024                             -- fx_scythe's scale: points below are read off the 1024 px art
local SOCK = { (45 - 512) * K, -(450 - 256) * K } -- the socket and the tip, from the blade's centre (the art is the
                                                 -- lab's scythe.png mirrored top to bottom)
local TIP = { (1005 - 512) * K, -(435 - 256) * K }
local BLADE = { -SOCK[1], LS - SOCK[2] }         -- the blade's centre, from the pivot, unturned
local TIP_AT = { TIP[1] - SOCK[1], LS + TIP[2] - SOCK[2] }
-- the swing, as the pivot's turn: it shows at the seal's left, draws back, the stroke, the follow-through out to
-- the right. Only about 115 px above the seal is on screen, so the draw-back is the blade rising half out of it.
local R0, R1, R2, R3, S0, S1 = 0.9, 1.35, -0.9, -1.3, 0.16, 0.32
local SEGS = 10                                  -- pieces of the arc behind the tip

local function Turn(P, t)
    if t < S0 then return P.lerp(R0, R1, P.prog(t, 0, S0, P.E.outQ)) end
    if t < S1 then return P.lerp(R1, R2, P.prog(t, S0, S1 - S0, P.E.inOutC)) end
    return P.lerp(R2, R3, P.prog(t, S1, 0.3, P.E.outC))
end

--- A point given from the pivot, turned rr clockwise, as an offset from the seal's centre.
local function Around(p, rr, scale)
    local x, y, c, s = p[1] * (scale or 1), p[2] * (scale or 1), math.cos(rr), math.sin(rr)
    return H.x + x * c - y * s, H.y + x * s + y * c
end

GK.FX.reaper_scythe = {
    land = C,
    build = function(splash, P)
        local fx = {}
        fx.gloom = Gloom(splash, P)
        fx.shaft = P.Tex(splash, "fx_shaft", "OVERLAY", 3)
        fx.blade = P.Tex(splash, "fx_scythe", "OVERLAY", 4)
        fx.edge, fx.smear = {}, {}
        for i = 1, SEGS do
            fx.edge[i] = P.Tex(splash, "fx_arc_seg", "OVERLAY", 2, true)
            fx.smear[i] = P.Tex(splash, "fx_arc_seg", "ARTWORK", 1, true)   -- the lab's smear is under the ribbon
        end
        -- a cold flash where it hits: the glow, made green, on the seal and under the ribbon
        fx.flash = P.Tex(splash, "spree_glow", "ARTWORK", 1, true)
        fx.flash:SetDesaturated(true)
        splash.reaperScythe = fx
    end,
    update = function(splash, age, P)
        local fx, t = splash.reaperScythe, age
        local hold = splash.hold or 3
        P.Set(splash, fx.gloom, { w = 560, h = 420, a = P.env(t, 0, 0.25, hold - 0.2, hold + 0.5) * 0.55 })
        local rr = Turn(P, t)
        local a = math.min(P.prog(t, 0, 0.06), 1 - P.prog(t, S1 + 0.05, 0.2))
        local sx, sy = Around({ 0, (LS - 120) / 2 }, rr)
        P.Set(splash, fx.shaft, { x = sx, y = sy, w = 32, h = LS + 120, r = rr, a = a })
        local bx, by = Around(BLADE, rr)
        P.Set(splash, fx.blade, { x = bx, y = by, w = 260, h = 130, r = rr, a = a })
        -- the arc: from the tip back to where it was 70 ms ago, brightest at the tip, with a wider smear inside it
        -- where the blade swept; it only runs in the stroke, and fades with the blade
        local fade = t < S0 and 0 or 1 - P.prog(t, S1, 0.15)
        local tail = math.max(S0, t - 0.07)
        local R = math.sqrt(TIP_AT[1] ^ 2 + TIP_AT[2] ^ 2)
        for i = 1, SEGS do
            local q0, q1 = (i - 1) / SEGS, i / SEGS
            local x0, y0 = Around(TIP_AT, Turn(P, P.lerp(t, tail, q0)))
            local x1, y1 = Around(TIP_AT, Turn(P, P.lerp(t, tail, q1)))
            local len, dir = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2), math.atan2(y1 - y0, x1 - x0)
            local on = fade > 0 and len > 0.5 and t >= S0
            local alpha = on and (1 - q0) * fade or 0
            P.Set(splash, fx.edge[i], { x = (x0 + x1) / 2, y = (y0 + y1) / 2, w = len * 1.6, h = 14, r = dir, a = alpha })
            local m0x, m0y = Around(TIP_AT, Turn(P, P.lerp(t, tail, q0)), (R - 45) / R)
            local m1x, m1y = Around(TIP_AT, Turn(P, P.lerp(t, tail, q1)), (R - 45) / R)
            P.Set(splash, fx.smear[i], { x = (m0x + m1x) / 2, y = (m0y + m1y) / 2, w = len * 1.6, h = 70, r = dir,
                a = alpha * 0.45, cr = 0.55, cg = 0.9, cb = 0.65 })
        end
        P.Set(splash, fx.flash, { w = P.SEAL * 2.6, h = P.SEAL * 2.6, s = 0.6 + P.prog(t, C, 0.4),
            a = t >= C and math.max(0, 1 - (t - C) * 2.5) or 0, cr = 0.55, cg = 1, cb = 0.65 })
    end,
}

-- ---------------------------------------------------------------------------
-- RP4, from the smoke
-- ---------------------------------------------------------------------------
-- A heap, not a ring: puffs at random angles, denser towards the middle and a little below the seal, so the
-- cloud rises into place. Each one drifts up, sways and turns the whole time; then they lift off one after
-- another. The seal comes up dark through it before the ribbon lands. Round 2 found the old cloud was eight
-- copies of one puff on a circle that faded in place.
local SC = 0.45                                  -- when the seal lands, out of the smoke
local PUFFS = 30

GK.FX.reaper_smoke = {
    land = SC,
    build = function(splash, P)
        local fx = { puffs = {} }
        fx.gloom = Gloom(splash, P)
        fx.glow = P.Tex(splash, "spree_glow", "ARTWORK", 1, true)     -- the lab's z 1: over the seal, under the ribbon
        fx.glow:SetDesaturated(true)
        local r = P.rng(4)                       -- the same cloud every time
        for i = 1, PUFFS do
            local ang, d, size = r() * 6.283, r() ^ 0.7 * 85, 50 + r() * 80
            fx.puffs[i] = { t = P.Tex(splash, "fx_smoke_puff", "ARTWORK", 3), size = size,
                x = math.cos(ang) * d * 1.15, y = math.sin(ang) * d * 0.8 + 40 + r() * 30, t0 = r() * 0.22,
                rise = 60 + r() * 60, curl = (r() - 0.5) * 2.4, sway = 6 + r() * 14, ph = r() * 6.28,
                r0 = r() * 6.28, a0 = 0.45 + r() * 0.35, out = 0.6 + r() * 0.8, l0 = r() * 0.18 }
        end
        splash.reaperSmoke = fx
    end,
    update = function(splash, age, P)
        local fx, t = splash.reaperSmoke, age
        local hold = splash.hold or 3
        P.Set(splash, fx.gloom, { w = 560, h = 420, a = P.env(t, 0, 0.5, hold - 0.2, hold + 0.5) * 0.6 })
        -- the seal condenses out of the smoke: dark and faint, then sharp and in colour (the lab blurs it too)
        local t0 = SC - 0.4
        local q = P.prog(t, t0, 0.55, P.E.inOutC)
        P.Set(splash, splash.seal, { w = P.SEAL, h = P.SEAL, s = 0.94 + 0.06 * q, b = 0.08 + 0.92 * q,
            a = t < t0 and 0 or math.min(1, q * 1.8) })
        -- the fire catches only once the seal is solid (the splash lit it at the landing, over 0.25 s)
        if splash.fire then
            splash.flames:SetAlpha(splash.fire.alpha * P.clamp((t - SC) / 0.25) * P.prog(t, t0 + 0.45, 0.4))
        end
        P.Set(splash, fx.glow, { y = 45 - 40 * P.prog(t, 0, SC), w = P.SEAL * 2.3, h = P.SEAL * 2.3, s = 0.7 + 0.4 * P.prog(t, 0, SC),
            a = P.env(t, 0.05, SC - 0.1, SC - 0.05, SC + 0.2) * 0.45, cr = 0.55, cg = 1, cb = 0.65 })
        for _, u in ipairs(fx.puffs) do
            local k = t - u.t0
            local grow = P.prog(k, 0, 0.45, P.E.outC)
            local l0 = SC - 0.12 + u.l0
            local lift = P.prog(t, l0, 0.55, P.E.outQ)
            local spread = 0.35 + 0.65 * grow
            P.Set(splash, u.t, { w = u.size, h = u.size,
                x = u.x * spread * (1 + 1.6 * lift * u.out) + math.sin(k * 3 + u.ph) * u.sway,
                y = u.y * spread - u.rise * k - 120 * lift * u.out,
                s = (0.4 + 0.6 * grow) * (1 + 0.7 * lift) * (1 + 0.08 * math.sin(k * 5 + u.ph)),
                r = u.r0 + u.curl * k,
                a = k < 0 and 0 or grow * u.a0 * (1 - 0.6 * P.prog(t, SC - 0.35, 0.3)) * (1 - P.prog(t, l0, 0.35)) })
        end
    end,
}
