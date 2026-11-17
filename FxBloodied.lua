-- Grudgekeeper - spree effects: Bloodied. BL2, first blood: the meteor slam, then two drops run down the seal.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
local ADDON, GK = ...

local LAND = 0.24                 -- the seal's fall, as the lab's slam
local SEAL_EDGE = 85              -- half the seal, the lab's SEAL_EDGE
-- Two drops: x from the seal's centre, when each starts, how far it runs
local DROPS = { { x = -34, t = LAND + 0.2, len = 64 }, { x = 26, t = LAND + 0.45, len = 50 } }

local E = nil                     -- the kit's easings, set when built

local function Build(splash, P)
    E = P.E
    local b = {}
    -- the ring and the flash are lights, so additive
    b.ring = P.Tex(splash, "spree_glow", "OVERLAY", 0, true)
    b.flash = P.Tex(splash, "spree_glow", "OVERLAY", 0, true)
    -- the seal's sparks leave from where it lands, thrown out and pulled down
    b.sparks = P.Burst(splash, 24, { t0 = LAND, speed = 560, life = 0.65, size = 12, stretch = 2.6,
        gravity = 380, drag = 2.2, seed = 7 })
    -- The drops sit over the seal and under the ribbon. The seal and the ribbon are both ARTWORK 0 and there is
    -- no sublevel between them, so these are ARTWORK 0 too (made later, so drawn over the seal); a head that
    -- reaches the ribbon's top edge may show over it.
    b.drops = {}
    for i, d in ipairs(DROPS) do
        b.drops[i] = { d = d, trail = P.Tex(splash, "fx_drop_trail", "ARTWORK", 0),
            head = P.Tex(splash, "fx_drop_head", "ARTWORK", 0) }
    end
    splash.bloodied = b
end

local function Update(splash, age, P)
    local b = splash.bloodied
    -- the seal falls in from above at 1.5 times, then squashes as it lands; the splash hides it until land
    local y, s, sx, sy = 0, 1, 1, 1
    if age < LAND then
        local p = P.prog(age, 0, LAND, E.inC)
        y, s = P.lerp(-480, 0, p), P.lerp(1.5, 1, p)
    else
        local q = P.prog(age, LAND, 0.45)
        local sq = math.exp(-q * 7) * math.cos(q * 18)
        sx, sy = 1 + 0.22 * sq, 1 - 0.22 * sq
    end
    P.Set(splash, splash.seal, { y = y, s = s, sx = sx, sy = sy })
    splash.seal:Show()
    local k = age - LAND
    P.Set(splash, b.ring, { s = 0.6 + P.prog(age, LAND, 0.5, E.outC) * 2.6, w = P.SEAL * 1.8, h = P.SEAL * 1.8,
        a = k >= 0 and (1 - P.prog(age, LAND, 0.5)) * 1.2 or 0 })
    P.Set(splash, b.flash, { s = 0.5 + P.prog(age, LAND, 0.3), w = P.SEAL * 2.4, h = P.SEAL * 2.4,
        a = k >= 0 and math.max(0, 1.2 - k * 4) or 0 })
    b.sparks(age)
    -- each drop runs down by its own length, its trail stretched behind its head
    for _, r in ipairs(b.drops) do
        local d = r.d
        local len = math.max(1, d.len * P.prog(age, d.t, 0.55, E.outC))
        local y0, on = SEAL_EDGE * 0.25, age >= d.t and 1 or 0
        P.Set(splash, r.trail, { x = d.x, y = y0 + len / 2, w = 16, h = 64, sy = len / 64, a = on * 0.9 })
        P.Set(splash, r.head, { x = d.x, y = y0 + len, w = 16, h = 16, a = on })   -- the drop fills ~22x28 of its 32 px art: the lab's 11x14
    end
end

GK.FX.bloodied_drops = { land = LAND, build = Build, update = Update }
