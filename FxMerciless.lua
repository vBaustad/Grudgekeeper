-- Grudgekeeper - spree effects: Merciless. C4, the cross cut: two blade slashes cross in an X and the seal punches out of it.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
-- Left out of the lab's card: the screen shake. The card has no full-screen layer.
local ADDON, GK = ...

local H = 0.32                  -- when the cuts cross and the seal lands
local CUT_ROT = { -0.62, 0.62 }
local CUT_GAP = 0.13            -- the second cut follows the first

GK.FX.merciless_cross = {
    land = H,
    -- C4's sounds: a whoosh for each cut, the hit and the crack where they cross. The card has no fanfare.
    voice = H + 0.08,
    cues = { { 0, "whoosh" }, { 0.13, "whoosh" }, { H, "boom" }, { H, "crack" } },

    build = function(splash, P)
        -- below the seal, as the lab draws them before its core
        splash.cuts = {}
        for i, r in ipairs(CUT_ROT) do
            splash.cuts[i] = { t = P.Tex(splash, "fx_slash", "ARTWORK", -2, true), r = r, t0 = (i - 1) * CUT_GAP }
        end
        -- the flash lies on the seal and under the ribbon, as the lab draws it after the seal
        splash.cutFlash = P.Tex(splash, "spree_glow", "ARTWORK", 1, true)
        -- made once: the burst is drawn from the splash's age, so it plays again from the start
        splash.cutSparks = P.Burst(splash, 28, { t0 = H, speed = 560, life = 0.5, size = 12, stretch = 3, seed = 4 })
    end,

    update = function(splash, age, P)
        for _, c in ipairs(splash.cuts) do
            -- the slash is drawn in from one end: it grows from nothing while it slides in to centre
            local k = P.prog(age, c.t0, 0.14, P.E.outC)
            local fade = age < c.t0 and 0 or math.max(0, 1 - math.max(0, age - c.t0 - 0.2) * 1.2)
            P.Set(splash, c.t, { w = 700, h = 120, r = c.r, sx = math.max(0.001, k),
                x = (1 - k) * -350 * math.cos(c.r), y = (1 - k) * -350 * math.sin(c.r),
                a = fade, sy = 1 - P.prog(age, c.t0 + 0.2, 0.8) * 0.7 })
        end
        -- the flash where they cross, as the seal punches out
        P.Set(splash, splash.cutFlash, { w = P.SEAL * 2.4, h = P.SEAL * 2.4, s = 0.5 + P.prog(age, H, 0.3),
            a = age >= H and math.max(0, 1.3 - (age - H) * 4) or 0 })
        splash.cutSparks(age)
    end,
}
