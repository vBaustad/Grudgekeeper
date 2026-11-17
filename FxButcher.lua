-- Grudgekeeper - spree effects: Butcher. BU2, blood bloom: today's splash, and two blood splatters bloom out behind the
-- punch, drying darker. See Effects.lua for how an effect is played and the kit (P) it is drawn with.
-- Left out of the lab's card: its sounds.
local ADDON, GK = ...

local AT = 0.2                      -- when the blood blooms
local SPLATS = {
    { file = "fx_splat_1", size = 340, r = 0.6, x = -20, y = 20, a = 0.85 },
    { file = "fx_splat_2", size = 300, r = 3.4, x = 30, y = -10, a = 0.75 },
}

GK.FX.butcher_bloom = {
    land = 0,

    build = function(splash, P)
        -- after the glow and flames, before the seal: above the flames, below the seal, drawn plain, not as light
        splash.splats = {}
        for i, s in ipairs(SPLATS) do
            splash.splats[i] = P.Tex(splash, s.file, "BACKGROUND", 3)
        end
    end,

    update = function(splash, age, P)
        local b = P.prog(age, AT, 0.15, P.E.outExpo)
        local dry = P.prog(age, AT + 0.2, 2)
        for i, s in ipairs(SPLATS) do
            P.Set(splash, splash.splats[i], { w = s.size, h = s.size, s = 0.3 + 0.7 * b, r = s.r, x = s.x, y = s.y,
                a = age >= AT and s.a or 0, b = 1 - dry * 0.35 })
        end
    end,
}
