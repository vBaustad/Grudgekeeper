-- Grudgekeeper - the spree effects: how each splash arrives. Each tier has its own, picked by both of us
-- on the Streak Lab's board (2026-11-15 and 17): Bloodied's slam and drops, Merciless's cross cut,
-- Butcher's blood bloom, Reaper's scythe or smoke (a setting), Grudgebound's crown of chains, its number on
-- every 5 after 15, the hundred, a spree ended shattering and a tormentor's debt stamped paid. The card
-- names in the files (BL2, C4, RP1, RP4, GB1, X1, M11, E1, T3, K6) are the Streak Lab's: the board where the
-- guild picked each effect, so a reader can find the card an effect was ported from.
--
-- An effect is a table in GK.FX, played by the splash (Announce.lua):
--   land     when the seal lands, in seconds after the splash shows. The seal, ribbon, line, glow and fire
--            come then, as 1.8.0's splash does at 0, and the hold counts from it.
--   build(splash, P)          once per splash, to make its textures (P.Tex)
--   start(splash, item, P)    each time it shows
--   update(splash, age, P)    each frame, after the splash has laid out its own parts for that frame, so an
--                             effect may move the seal (P.Set on splash.seal)
-- P is GK.FxKit. Its coordinates are the lab's: x right and y DOWN from the seal's centre, rotation in
-- clockwise radians, so a card's code ports line for line. A frame with fxOrigin (a toast) has its own centre.
local ADDON, GK = ...

local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"
local SEAL = 170                  -- the splash seal's size, as Announce.lua's
local SEAL_Y = -SEAL / 2          -- the seal's centre, from the splash's top

GK.FX = GK.FX or {}

-- ---------------------------------------------------------------------------
-- Which effect
-- ---------------------------------------------------------------------------
local TIER = { bloodied = "bloodied_drops", merciless = "merciless_cross", butcher = "butcher_bloom", grudgebound = "grudgebound_crown" }
local KIND = { ended = "ended_shatter", tormentor = "debt_paid" }

--- The effect a splash plays: kind is "spree", "ended" or "tormentor"; key the spree's tier; spree
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

--- Place a texture as the lab does: o.x, o.y from the seal's centre (y down; a frame's fxOrigin = { point, x, y },
--- the frame point the lab's (0,0) sits at, replaces the splash seal's centre), o.w by o.h times o.s (and o.sx,
--- o.sy), turned o.r clockwise, at alpha o.a, brightness o.b (0..1), tinted o.cr, o.cg, o.cb. o.coord: the part
--- of the texture to show, { left, right, top, bottom } (a cell of a sheet). An alpha of 0 hides it.
function P.Set(splash, t, o)
    local a = o.a == nil and 1 or o.a
    if a <= 0.001 then t:Hide() return end
    local s = o.s or 1
    t:ClearAllPoints()
    local at = splash.fxOrigin
    t:SetPoint("CENTER", splash, at and at.point or "TOP", (at and at.x or 0) + (o.x or 0),
        (at and at.y or SEAL_Y) - (o.y or 0))
    t:SetSize(math.max(0.01, (o.w or SEAL) * s * (o.sx or 1)), math.max(0.01, (o.h or SEAL) * s * (o.sy or 1)))
    t:SetAlpha(math.min(1, a))
    local b = o.b or 1
    t:SetVertexColor(b * (o.cr or 1), b * (o.cg or 1), b * (o.cb or 1))
    -- the texture's coordinates before its turn: the two share the texture's corners, so the last one set wins.
    -- Art that is drawn mirrored is mirrored in its file for the same reason.
    local c = o.coord
    if c then t:SetTexCoord(c[1], c[2], c[3], c[4]) else t:SetTexCoord(0, 1, 0, 1) end
    t:SetRotation(-(o.r or 0))
    t:Show()
end

--- A one-shot burst of n sparks from a point, as the lab's api.burst: returns draw(age), age the splash's. o: t0,
--- cx, cy, speed, life, size, stretch, gravity, drag, angle and arc (radians; no arc: all round), file
--- (spree_spark), seed, alpha, layer, add (false: plain, as dust), tint { r, g, b }.
function P.Burst(splash, n, o)
    local r, ps = P.rng(o.seed or 23), {}
    local tint = o.tint or { 1, 1, 1 }
    for i = 1, n do
        local ang = (o.angle or 0) + (o.arc and (r() - 0.5) * o.arc or r() * math.pi * 2)
        local sp, size = (o.speed or 300) * (0.4 + r() * 0.8), (o.size or 12) * (0.5 + r())
        local t = P.Tex(splash, o.file or "spree_spark", o.layer or "OVERLAY", 0, o.add ~= false)
        ps[i] = { t = t, w = size, h = size * (o.stretch or 1), vx = math.cos(ang) * sp, vy = math.sin(ang) * sp,
            life = (o.life or 0.8) * (0.6 + r() * 0.6), rot = o.stretch and ang + math.pi / 2 or r() * 6.28 }
    end
    return function(age)
        local tt = age - (o.t0 or 0)
        local drag = o.drag or 1.6
        for _, p in ipairs(ps) do
            if tt < 0 or tt > p.life then
                p.t:Hide()
            else
                local k = (1 - math.exp(-drag * tt)) / drag
                P.Set(splash, p.t, { x = (o.cx or 0) + p.vx * k, y = (o.cy or 0) + p.vy * k + 0.5 * (o.gravity or 0) * tt * tt,
                    w = p.w, h = p.h, r = p.rot, a = (1 - tt / p.life) * (o.alpha or 1),
                    cr = tint[1], cg = tint[2], cb = tint[3] })
            end
        end
    end
end

-- spree_flames.tga is a 4x4 sheet of a 16-frame loop, played at 12 frames a second
P.FLAMES = { frames = 16, cols = 4, rows = 4, fps = 12 }

--- The flame sheet's cell at an age (plus an offset, to desync copies), as a coord for P.Set: { l, r, t, b }.
function P.FlameCell(age, offset)
    local F = P.FLAMES
    local i = math.floor(math.max(0, age + (offset or 0)) * F.fps) % F.frames
    local col, row = i % F.cols, math.floor(i / F.cols)
    return { col / F.cols, (col + 1) / F.cols, row / F.rows, (row + 1) / F.rows }
end

-- The rimmed-iron numerals (Media/fx_num_<glyph>, with a hot copy fx_num_<glyph>_hot drawn as light): the lab's
-- forged iron with a dark rim baked in, so they read on snow and sand. Each sits in the middle of a 256 by 256
-- canvas, the glyph 200 high and as wide as here.
local GLYPH_H = 200
P.GLYPH_W = { x = 141, ["0"] = 128, ["1"] = 90, ["2"] = 122, ["3"] = 125, ["4"] = 126, ["5"] = 124,
    ["6"] = 135, ["7"] = 122, ["8"] = 132, ["9"] = 124 }
P.KERN = -0.12                    -- each glyph's advance is its width times 1 + KERN: they tuck together
local GLYPH_W, KERN = P.GLYPH_W, P.KERN

--- A number such as "×20" or "100" on the splash, up to max glyphs. num.set(text), then num.place(o) each frame,
--- o: x, y (its middle), h (height, 90), s, r, a and heat (0..1.5, the hot copy's strength). place returns each
--- glyph's centre as { x, y }, in the order of num.chars, for what goes behind or on a numeral.
function P.Number(splash, max)
    local glyphs = {}
    for i = 1, max or 4 do
        glyphs[i] = { n = P.Tex(splash, nil, "OVERLAY", 1), hot = P.Tex(splash, nil, "OVERLAY", 2, true) }
    end
    local num = { chars = {} }
    function num.set(text)
        num.chars = {}
        for ch in text:gsub("×", "x"):gmatch(".") do
            if GLYPH_W[ch] then num.chars[#num.chars + 1] = ch end
        end
        for i, g in ipairs(glyphs) do
            local ch = num.chars[i]
            if ch then
                g.n:SetTexture(MEDIA .. "fx_num_" .. ch)
                g.hot:SetTexture(MEDIA .. "fx_num_" .. ch .. "_hot")
            end
        end
    end
    function num.place(o)
        local chars, total = num.chars, 0
        for _, ch in ipairs(chars) do total = total + GLYPH_W[ch] * (1 + KERN) end
        if #chars > 0 then total = total - GLYPH_W[chars[#chars]] * KERN end
        local k = (o.h or 90) / GLYPH_H * (o.s or 1)
        local r, cx = o.r or 0, -total / 2
        local centres = {}
        for i, g in ipairs(glyphs) do
            local ch = chars[i]
            if not ch then
                g.n:Hide()
                g.hot:Hide()
            else
                local w = GLYPH_W[ch]
                local lx = (cx + w / 2) * k
                cx = cx + w * (1 + KERN)
                local at = { x = (o.x or 0) + lx * math.cos(r), y = (o.y or 0) + lx * math.sin(r), w = 256, h = 256,
                    s = k, r = r, a = o.a }
                P.Set(splash, g.n, at)
                at.a = (o.a or 1) * math.min(1.5, o.heat or 0)
                P.Set(splash, g.hot, at)
                centres[i] = { x = at.x, y = at.y }
            end
        end
        return centres
    end
    return num
end

--- Hide every effect texture on the splash (a new announcement starts clean).
function P.HideAll(splash)
    for _, t in ipairs(splash.fxParts or {}) do t:Hide() end
end
