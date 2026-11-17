-- Grudgekeeper - the spree effects: how each splash arrives. Each tier has its own, picked by both of us
-- on the Streak Lab's board (2026-11-15 and 17): Bloodied's slam and drops, Merciless's cross cut,
-- Reaper's scythe or smoke (a setting), Grudgebound's crown of chains, its number on every 5 after 15, the
-- hundred, a spree ended shattering and a tormentor's debt stamped paid. Butcher keeps 1.8.0's punch.
--
-- An effect is a table in GK.FX, played by the splash (Announce.lua):
--   land     when the seal lands, in seconds after the splash shows. The seal, ribbon, line, glow and fire
--            come then, as 1.8.0's splash does at 0, and the hold counts from it.
--   build(splash, P)          once per splash, to make its textures (P.Tex)
--   start(splash, item, P)    each time it shows
--   update(splash, age, P)    each frame, after the splash has laid out its own parts for that frame, so an
--                             effect may move the seal (P.Set on splash.seal)
-- P is GK.FxKit. Its coordinates are the lab's: x right and y DOWN from the seal's centre, rotation in
-- clockwise radians, so a card's code ports line for line.
local ADDON, GK = ...

local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"
local SEAL = 170
local SEAL_Y = -SEAL / 2          -- the seal's centre, from the splash's top

GK.FX = GK.FX or {}

-- ---------------------------------------------------------------------------
-- Which effect
-- ---------------------------------------------------------------------------
local TIER = { bloodied = "bloodied_drops", merciless = "merciless_cross", grudgebound = "grudgebound_crown" }
local KIND = { ended = "ended_shatter", tormentor = "debt_paid" }

--- The effect a splash plays: kind is "spree", "ended", "tormentor" or "order"; key the spree's tier; spree
--- its kills. nil: none (1.8.0's punch).
function GK.SpreeEffect(kind, key, spree, db)
    if kind ~= "spree" then return KIND[kind] end
    if key == "reaper" then
        return (db and db.reaperEffect == "smoke") and "reaper_smoke" or "reaper_scythe"
    end
    if key == "grudgebound" and spree then
        if spree == 100 then return "hundred" end
        if spree > GK.SPREE_TIERS[#GK.SPREE_TIERS].n then return "grudgebound_repeat" end
    end
    return TIER[key]
end

-- ---------------------------------------------------------------------------
-- The kit
-- ---------------------------------------------------------------------------
local P = {}
GK.FxKit = P
P.SEAL, P.MEDIA = SEAL, MEDIA

function P.lerp(a, b, t) return a + (b - a) * t end
function P.clamp(v, lo, hi) return math.max(lo or 0, math.min(hi or 1, v)) end

--- How far along t is in [t0, t0 + d], 0 to 1, through an easing.
function P.prog(t, t0, d, ease)
    local q = d > 0 and P.clamp((t - t0) / d) or (t >= t0 and 1 or 0)
    return ease and ease(q) or q
end

--- 0 before a, up to 1 by b, 1 until c, down to 0 by d.
function P.env(t, a, b, c, d)
    if t < a or t > d then return 0 end
    if t < b then return (t - a) / (b - a) end
    if t <= c then return 1 end
    return 1 - (t - c) / (d - c)
end

-- the lab's easings (lab.js)
P.E = {
    inQ = function(q) return q * q end,
    outQ = function(q) return 1 - (1 - q) * (1 - q) end,
    inC = function(q) return q * q * q end,
    outC = function(q) return 1 - (1 - q) ^ 3 end,
    inOutC = function(q) return q < 0.5 and 4 * q * q * q or 1 - (-2 * q + 2) ^ 3 / 2 end,
    outBack = function(q) local c = 1.70158 return 1 + (c + 1) * (q - 1) ^ 3 + c * (q - 1) ^ 2 end,
    outExpo = function(q) return q >= 1 and 1 or 1 - 2 ^ (-10 * q) end,
}

--- A seeded random 0..1, so a cloud of puffs is the same every time it plays.
function P.rng(seed)
    local s = (seed or 1) % 2147483647
    if s <= 0 then s = s + 2147483646 end
    return function()
        s = (s * 16807) % 2147483647
        return (s - 1) / 2147483646
    end
end

--- A texture of the effect's own, hidden until set. file: a name in Media (fx_...), or nil for a plain one.
--- layer and sub as CreateTexture's; add: drawn additively, as a light.
function P.Tex(splash, file, layer, sub, add)
    local t = splash:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if file then t:SetTexture(MEDIA .. file) end
    if add then t:SetBlendMode("ADD") end
    t:Hide()
    splash.fxParts = splash.fxParts or {}
    splash.fxParts[#splash.fxParts + 1] = t
    return t
end

--- Place a texture as the lab does: o.x, o.y from the seal's centre (y down), o.w by o.h times o.s (and o.sx,
--- o.sy), turned o.r clockwise, at alpha o.a, brightness o.b (0..1). o.flipY / o.flipX mirror it. An alpha of 0
--- hides it.
function P.Set(splash, t, o)
    local a = o.a == nil and 1 or o.a
    if a <= 0.001 then t:Hide() return end
    local s = o.s or 1
    t:ClearAllPoints()
    t:SetPoint("CENTER", splash, "TOP", o.x or 0, SEAL_Y - (o.y or 0))
    t:SetSize(math.max(0.01, (o.w or SEAL) * s * (o.sx or 1)), math.max(0.01, (o.h or SEAL) * s * (o.sy or 1)))
    t:SetRotation(-(o.r or 0))
    t:SetAlpha(math.min(1, a))
    local b = o.b or 1
    t:SetVertexColor(b * (o.cr or 1), b * (o.cg or 1), b * (o.cb or 1))
    if o.flipY or o.flipX then
        local l, r = o.flipX and 1 or 0, o.flipX and 0 or 1
        local top, bottom = o.flipY and 1 or 0, o.flipY and 0 or 1
        t:SetTexCoord(l, r, top, bottom)
    else
        t:SetTexCoord(0, 1, 0, 1)
    end
    t:Show()
end

--- Hide every effect texture on the splash (a new announcement starts clean).
function P.HideAll(splash)
    for _, t in ipairs(splash.fxParts or {}) do t:Hide() end
end
