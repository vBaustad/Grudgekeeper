-- Grudgekeeper - spree effects: Ended and tormentor. E1, a spree ended shatters; T3, a tormentor's debt stamped paid.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
local ADDON, GK = ...

-- ---------------------------------------------------------------------------
-- E1: the cracked seal pulses twice and bursts into six shards
-- ---------------------------------------------------------------------------
local B = 0.9                          -- when it bursts
-- where each shard sits in the whole seal (x, y, turn), roughly: the art was cut up from the whole, not placed
local SHARDS = { { -40, -42, -.3 }, { 42, -44, .2 }, { -46, 6, .1 }, { 46, 8, -.1 }, { -30, 46, .2 }, { 34, 46, -.2 } }
local GREY = { 0.79, 0.76, 0.72 }     -- the line, greyed out rather than red

-- E1's sounds: two dying heartbeats, the crack, the shatter over its boom, the defeat stinger; the voice after the
-- dust settles
local ended = { land = 0, voice = B + 1.1,
    cues = { { 0, "endpulse" }, { B - 0.05, "crack" }, { B, "endshatter" }, { B + 0.05, "sting_ended" } } }
GK.FX.ended_shatter = ended

function ended.build(splash, P)
    local r = P.rng(11)
    local s = {}
    -- the lab's order: the whole seal, its glow over it, then the shards and the dust. WoW can't brighten a texture
    -- past 1, so the heartbeat's brightening is an additive copy of the whole seal laid on it.
    s.whole = P.Tex(splash, "fx_shatter_whole", "ARTWORK", 1)
    s.bright = P.Tex(splash, "fx_shatter_whole", "ARTWORK", 2, true)
    s.glow = P.Tex(splash, "spree_glow", "ARTWORK", 3, true)
    s.shards = {}
    for i, sh in ipairs(SHARDS) do
        s.shards[i] = { n = P.Tex(splash, "fx_shard_" .. i, "ARTWORK", 4), x0 = sh[1], y0 = sh[2], rot = sh[3],
            vx = sh[1] * (3 + r() * 2) + (r() - .5) * 80, vy = sh[2] * 2.2 - 160 - r() * 120, spin = (r() - .5) * 6 }
    end
    s.dust = {}
    for i = 1, 3 do s.dust[i] = P.Tex(splash, "fx_dust", "ARTWORK", 5) end
    s.chips = P.Burst(splash, 26, { t0 = B, speed = 380, life = 1.1, size = 9, gravity = 700, file = "spree_spark" })
    splash.ended = s
end

function ended.update(splash, age, P)
    local s = splash.ended
    -- the card draws its own whole seal, then shards: the base seal stays hidden
    splash.seal:Hide()
    splash.glow:Hide()                 -- the card has no base glow
    local pulse = 0
    if age < B then
        for i, h in ipairs({ .07, .67 }) do
            if age >= h then pulse = math.max(pulse, (i == 2 and 1 or .55) * math.exp(-(age - h) * 7)) end
        end
    end
    local whole = { w = P.SEAL * 1.15, h = P.SEAL * 1.15, a = 0 }
    if age < B then
        whole.a = P.prog(age, 0, .15)
        whole.s = 1 + pulse * .03 + (age / B) * .04
        if age > B - .3 then whole.x = (math.random() - .5) * 4 end   -- a tremble before it goes
    end
    P.Set(splash, s.whole, whole)
    -- the lab's b: 1 + pulse * .5, as a copy laid on the seal at the same place, size and turn
    local bright = {}
    for k, v in pairs(whole) do bright[k] = v end
    bright.a = whole.a * pulse * .5
    P.Set(splash, s.bright, bright)
    P.Set(splash, s.glow, { w = P.SEAL * 1.6, h = P.SEAL * 1.6,
        a = age < B and pulse * .7 or math.max(0, 1 - (age - B) * 3), s = 1 + (age > B and (age - B) * 2 or 0) })
    for _, sh in ipairs(s.shards) do
        local d = age - B
        if d < 0 then
            sh.n:Hide()
        else
            P.Set(splash, sh.n, { w = 92, h = 92, x = sh.x0 + sh.vx * d, y = sh.y0 + sh.vy * d + 650 * d * d,
                r = sh.rot + sh.spin * d, a = math.max(0, 1 - d * .8) })
        end
    end
    for i, d in ipairs(s.dust) do
        local k = age - B - (i - 1) * .06
        P.Set(splash, d, { w = 200, h = 200, x = (i - 2) * 40, y = 10 - k * 30, s = .4 + k * 1.2,
            a = k > 0 and math.max(0, .9 - k * .7) or 0 })
    end
    s.chips(age)
    splash.line:SetTextColor(GREY[1], GREY[2], GREY[3], P.prog(age, B + .3, .4))
end

-- ---------------------------------------------------------------------------
-- T3: the black seal, and a PAID stamp slammed onto it at an angle
-- ---------------------------------------------------------------------------
local H = 0.45                         -- when the stamp lands
local T3_SEAL = 150                    -- the card's seal: smaller than the splash's

-- T3's sounds: the stamp's swing (at half level) and the stamp; the voice after it
local paid = { land = 0, voice = H + 0.35, cues = { { H - 0.12, "whoosh_50" }, { H, "stamp" } } }
GK.FX.debt_paid = paid

function paid.build(splash, P)
    local s = {}
    s.stamp = P.Tex(splash, "stamp_paid", "OVERLAY", 3)
    s.stamp:SetDesaturated(true)       -- the stamp is green: grey it first, so the red tint takes
    s.dust = P.Burst(splash, 14, { t0 = H, speed = 200, life = .5, size = 18, file = "fx_dust", add = false })
    splash.paid = s
end

function paid.update(splash, age, P)
    local s = splash.paid
    -- the card's seal fades in at 1.2 times and settles, where the base punches in from 1.6 at 170
    P.Set(splash, splash.seal, { w = T3_SEAL, h = T3_SEAL, a = P.prog(age, 0, .15),
        s = 1 + .2 * (1 - P.prog(age, 0, .2, P.E.outC)) })
    local k = P.prog(age, H - .12, .12, P.E.inQ)
    P.Set(splash, s.stamp, { w = 210, h = 105, y = 10, r = -.25, cr = 1, cg = .3, cb = .25,
        s = age < H and P.lerp(2.2, 1, k) or 1 + .05 * math.exp(-(age - H) * 12),
        a = age < H - .12 and 0 or (age < H and k * .8 or 1) })
    s.dust(age)
    splash.line:SetTextColor(1, 1, 1, P.prog(age, H + .1, .3))
end
