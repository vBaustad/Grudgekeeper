-- Grudgekeeper - spree effects: Grudgebound. GB1, the crown of chains with F3's rise; X1, the number on every 5 after 15; M11, the hundred.
-- See Effects.lua for how an effect is played and the kit (P) it is drawn with.
local ADDON, GK = ...

local SEAL = 170
local NUM_X, NUM_Y = 150, -40         -- the seal's shoulder, where the number slams in
local NUM_R = -0.14

-- What each effect keeps per splash (the splash is built once, its effects' parts with it).
local function State(splash, name)
    splash.fxGB = splash.fxGB or {}
    splash.fxGB[name] = splash.fxGB[name] or {}
    return splash.fxGB[name]
end

-- The darkening round the screen's edges: Grudgebound is the one tier that may dim. It is anchored to the whole
-- screen, not the seal, so it is set by hand rather than with P.Set. Returns draw(age).
local function Dim(splash, P, T)
    local dim = P.Tex(splash, "fx_dim", "BACKGROUND", -8)
    dim:ClearAllPoints()
    dim:SetAllPoints(UIParent)
    return function(age)
        local a = P.env(age, T - 0.3, T, T + 1.2, T + 2) * 0.8
        dim:SetAlpha(a)
        dim:SetShown(a > 0.001)
    end
end

-- The crown of chains: falls onto the seal at L from 2.4x scale, spinning, then a small wobble, with sparks.
-- Returns draw(age).
local function Crown(splash, P, L)
    local ring = P.Tex(splash, "fx_crown_ring", "OVERLAY", -1)
    local hot = P.Tex(splash, "fx_crown_ring_hot", "OVERLAY", 0, true)
    local sparks = P.Burst(splash, 26, { t0 = L, speed = 480, life = 0.6, size = 12, stretch = 2.5, gravity = 300, seed = 31 })
    return function(age)
        local p = P.prog(age, L - 0.3, 0.3, P.E.inQ)
        local set = { w = 290, h = 290 }
        if age < L then
            set.s, set.r = P.lerp(2.4, 1, p), (1 - p) * 2.2
            set.a = age < L - 0.3 and 0 or math.min(1, p * 3)
        else
            set.s = 1 + 0.06 * math.exp(-(age - L) * 9) * math.cos((age - L) * 30)
            set.r, set.a = (age - L) * 0.12, 1
        end
        P.Set(splash, ring, set)
        set.a = age < L and p * 0.5 or math.max(0, 1 - (age - L) * 1.4)
        P.Set(splash, hot, set)
        sparks(age)
    end
end

-- GB1: the seal rises out of the dark, the crown falls on it.
GK.FX.grudgebound_crown = {
    land = 0.5,
    build = function(splash, P)
        local st = State(splash, "crown")
        local T = 0.5
        st.dim = Dim(splash, P, T)
        st.flash = P.Tex(splash, "spree_glow", "ARTWORK", 3, true)
        st.sparks = P.Burst(splash, 24, { t0 = T, speed = 560, life = 0.65, size = 12, stretch = 2.6, gravity = 380,
            drag = 2.2, seed = 7 })
        st.crown = Crown(splash, P, T + 0.55)
    end,
    update = function(splash, age, P)
        local st, T = State(splash, "crown"), 0.5
        st.dim(age)
        if age >= T then
            -- it comes up 30 px over 0.35 s, with no punch-in
            P.Set(splash, splash.seal, { w = SEAL, h = SEAL, y = 30 * (1 - P.prog(age, T, 0.35, P.E.outC)) })
            P.Set(splash, st.flash, { w = SEAL * 2.4, h = SEAL * 2.4, s = 0.5 + P.prog(age, T, 0.3),
                a = math.max(0, 1.2 - (age - T) * 4) })
        end
        st.sparks(age)
        st.crown(age)
    end,
}

-- X1: the crown, and the number slammed in at the seal's shoulder. The text is "×" .. kills, the lab's default
-- (multText's other modes are "times", a count of the 5s, and roman numerals).
GK.FX.grudgebound_repeat = {
    land = 0,
    build = function(splash, P)
        local st = State(splash, "repeat")
        local H = 0.55 + 0.45
        st.crown = Crown(splash, P, 0.55)
        st.num = P.Number(splash, 5)
        st.flash = P.Tex(splash, "spree_glow", "OVERLAY", 3, true)
        st.sparks = P.Burst(splash, 26, { t0 = H, cx = NUM_X, cy = NUM_Y, speed = 520, life = 0.6, size = 12,
            stretch = 2.6, gravity = 400, seed = 11 })
        st.H = H
    end,
    start = function(splash, item, P)
        local st = State(splash, "repeat")
        local kills = item.spree or 20
        st.num.set("×" .. kills)
        st.heat = P.clamp((kills - 15) / 35)
    end,
    update = function(splash, age, P)
        local st, H = State(splash, "repeat"), State(splash, "repeat").H
        st.crown(age)
        local p = P.prog(age, H - 0.16, 0.16, P.E.inQ)
        local wobble = age >= H and 0.1 * math.exp(-(age - H) * 10) * math.cos((age - H) * 34) or 0
        local heat = age >= H and math.max(st.heat * 0.7, 1.3 * math.exp(-(age - H) * 2.2)) or 0.8
        st.num.place({ x = NUM_X, y = NUM_Y, h = 92, r = NUM_R, heat = heat,
            s = (age < H and P.lerp(3, 1, p) or 1) * (1 + wobble),
            a = age < H - 0.16 and 0 or P.prog(age, H - 0.16, 0.06) })
        P.Set(splash, st.flash, { x = NUM_X, y = NUM_Y, w = 260, h = 260, s = 0.6 + P.prog(age, H, 0.3),
            a = age >= H and math.max(0, 1.2 - (age - H) * 4) or 0 })
        st.sparks(age)
    end,
}

-- M11: the hundred. A beat of nothing (the lab freezes the seal for 0.35 s while the sound swells), then x100
-- slams in burning, a shockwave rolls out, the crown comes down and sparks fly. No dim, flash or vignette.
-- The beat is only the quiet before R here: the splash's own
-- flames and glow keep moving through it, as the base cannot be paused.
local FLAME_W = { x = 141, ["0"] = 128, ["1"] = 90, ["2"] = 122, ["3"] = 125, ["4"] = 126, ["5"] = 124,
    ["6"] = 135, ["7"] = 122, ["8"] = 132, ["9"] = 124 }
local HUNDRED = { Z = 0.35, F = 0.35 }
HUNDRED.R = HUNDRED.Z + HUNDRED.F

GK.FX.hundred = {
    land = 0,
    build = function(splash, P)
        local st, R = State(splash, "hundred"), HUNDRED.R
        st.wave = P.Tex(splash, "spree_glow", "ARTWORK", 3, true)
        st.rays = P.Tex(splash, "fx_rays", "BACKGROUND", -2, true)
        st.crown = P.Tex(splash, "fx_crown_ring", "OVERLAY", -1)
        st.num = P.Number(splash, 5)
        st.num.set("×100")
        -- a fire behind each numeral
        st.fires = {}
        for i = 1, 5 do st.fires[i] = P.Tex(splash, "spree_flames", "OVERLAY", 0) end
        st.sparks = P.Burst(splash, 60, { t0 = R, cx = NUM_X, cy = NUM_Y, speed = 900, life = 0.9, size = 14,
            stretch = 3, gravity = 300, seed = 13 })
    end,
    update = function(splash, age, P)
        local st, R, F = State(splash, "hundred"), HUNDRED.R, HUNDRED.F
        local k = age - R
        local live = age < HUNDRED.Z and age or age < R and HUNDRED.Z or age - F   -- the lab's frozen clock
        P.Set(splash, st.rays, { w = 170 * 3.6, h = 170 * 3.6, r = live * 0.2, s = 1 + 0.1 * math.sin(age * 3),
            a = P.env(age, R, R + 0.3, R + 2.4, R + 3.2) })
        P.Set(splash, st.wave, { w = 400, h = 400, s = k >= 0 and 0.5 + k * 9 or 0, a = k >= 0 and math.max(0, 1 - k * 1.4) or 0 })
        P.Set(splash, st.crown, { w = 290, h = 290, r = live * 0.1, s = k >= 0 and 1 + 0.1 * math.exp(-k * 8) or 0,
            a = k >= 0 and 1 or 0 })
        -- the number at the seal's shoulder, and each numeral's fire where the number laid it
        local X, Y, H, r = 160, -40, 110, NUM_R
        local scale = k >= 0 and 1 + 0.3 * math.exp(-k * 9) * math.cos(k * 30) or 0
        st.num.place({ x = X, y = Y, h = H, r = r, s = scale, a = k >= 0 and 1 or 0,
            heat = k >= 0 and math.max(0.8, 1.5 * math.exp(-k * 2)) or 0 })
        local chars, total = st.num.chars, 0
        for _, ch in ipairs(chars) do total = total + FLAME_W[ch] * 0.88 end
        if #chars > 0 then total = total + FLAME_W[chars[#chars]] * 0.12 end
        local kk, cx = H / 200 * scale, -total / 2
        for i, fire in ipairs(st.fires) do
            local ch = chars[i]
            if not ch or k < 0 then
                fire:Hide()
            else
                local w = FLAME_W[ch]
                local lx = (cx + w / 2) * kk
                cx = cx + w * 0.88
                P.Set(splash, fire, { x = X + lx * math.cos(r), y = Y + lx * math.sin(r) - 8, w = 150, h = 150,
                    s = 1.15, r = r })
                local f = math.floor(math.max(0, age + (i - 1) * 0.3) * 12) % 16
                fire:SetTexCoord((f % 4) / 4, (f % 4 + 1) / 4, math.floor(f / 4) / 4, (math.floor(f / 4) + 1) / 4)
            end
        end
        st.sparks(age)
    end,
}
