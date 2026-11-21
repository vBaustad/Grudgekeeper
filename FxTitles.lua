-- Grudgekeeper - a new title: a hammer comes striking in and leaves the title's emblem where it struck, and the
-- title's name slams down above. See Effects.lua for how an effect is played and the kit (P) it is drawn with.
--
-- "vi skulle gjerne sett animasjoner/effekter for de forskjellige rankups" (the owner, 2026-11-18). Picked in the
-- effect lab's round 7 (2026-11-21): "jeg tror jeg vil ha en hammer som kommer slående inn og legger fra seg et
-- merke (emblem) med en tung dunkelyd av noe slag. ikke noe kling" - H for your own, a big hammer swinging in round
-- its grip in one stroke from out of sight. A guildie's toast has no hammer: there the emblem pops out of a cloud of
-- dust and blows it away, and its line fades in after it (the owner in game, 2026-11-21: at a toast's size J's
-- hammer and its emblem were too small to read).
-- One heavy blow: a flash, the splash shaken, a ring of dust and one of light along the ground, the dust jetting
-- out, debris; the emblem is there, pressed in and springing back, its outline lit for a moment; the hammer rests a
-- blink and is lifted away, with no bounce. The sound is the tormentor's book's slam, boom and stamp together.
-- Every title has an emblem of its own, Codex's (art/import_titles.py): iron to Slayer, bronze to Reckoner, gold
-- above, and the effect grows with the metal - a bigger emblem, more debris, a harder shake. The headline is the
-- title's name in the metal's colours (the kit's P.Headline), the line under it "New title · 450 points"
-- (Announce.lua's splashLine). The hooks are GK.FX.rank and GK.TOASTFX.rank, for every title (RankItem).
local ADDON, GK = ...

GK.FX = GK.FX or {}
GK.TOASTFX = GK.TOASTFX or {}

local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"

-- each title's metal, by its key (GK.TITLES, Core.lua): 1 iron, 2 bronze, 3 gold
local TIER = { cutthroat = 1, bloodhound = 1, headhunter = 1, slayer = 1, executioner = 2, oathsworn = 2, avenger = 2,
    reckoner = 2, nemesis = 3, grudgebearer = 3, dread_reaper = 3 }
local WORD = { { 0.84, 0.86, 0.9 }, { 0.91, 0.63, 0.38 }, { 1, 0.85, 0.36 } }      -- the headline, by metal
local GLOW = { { 0.45, 0.55, 0.8 }, { 0.8, 0.38, 0.12 }, { 1, 0.6, 0.1 } }
local FLASH = { { 0.9, 0.95, 1 }, { 1, 0.8, 0.55 }, { 1, 0.92, 0.6 } }
local DUST_LINE = 0.087                     -- fx_dust_burst's first streak, below its cell's middle (FxEnded.lua's T4)
local EY = 10                               -- the emblem's middle below the seal's centre (times the frame's scale)
local WORD_AT = 0.3                         -- the headline lands this long after the blow

-- The hammer (art/import_titles.py), fx_hammer_side, turning inside its own square, which leaves it room to: drawn
-- from the side and a little above lying as it strikes, so the top of its head shows and it needs no turn at the
-- blow - its striking face and its grip, parts of its square from its middle.
local SIDE_FACE, SIDE_GRIP = { -0.240, 0.195 }, { 0.246, 0.003 }

local SPLASH = { k = 1, impact = 0.46, swing = 0.2, hammer = 580, tex = "fx_hammer_side", debris = { 16, 22, 28 },
    quake = { 8, 10, 12 } }

-- The toast: the emblem larger than the toast's 64 px seal, a little left of its middle so the line clears it
local TOAST_ES, TOAST_X = 76, -4
local POOF, TOAST_HOLD = 0.4, 3.6           -- when it pops out and the dust blows away; when the toast fades
local PUFFS = 7

--- x, y turned r clockwise (y down), as the kit turns a texture.
local function Rot(x, y, r)
    local c, s = math.cos(r), math.sin(r)
    return x * c - y * s, x * s + y * c
end

--- The blow's shake of the whole frame, px at most, dying away in 0.6 s: x, y (y down).
local function Quake(age, t0, px)
    if age < t0 or age > t0 + 0.6 then return 0, 0 end
    local t = age - t0
    local d = math.exp(-t * 9) * px
    return d * math.sin(t * 61), 0.78 * d * math.cos(t * 47)
end

--- A cell of a 4 by 4 sheet, as P.Set's coord.
local function Cell(i)
    local col, row = i % 4, math.floor(i / 4)
    return { col / 4, (col + 1) / 4, row / 4, (row + 1) / 4 }
end

--- A sheet's 16 frames played at fps from t, each faded into the next (pair: two textures), o as P.Set's.
local function PlaySheet(frame, P, pair, t, fps, o)
    local f = t * fps
    local i = math.floor(f)
    if t < 0 or i >= 16 then
        pair[1]:Hide()
        pair[2]:Hide()
        return
    end
    local w, a = f - i, o.a or 1
    o.coord, o.a = Cell(i), a * (i + 1 < 16 and 1 or 1 - w)
    P.Set(frame, pair[1], o)
    if i + 1 < 16 then
        o.coord, o.a = Cell(i + 1), a * w
        P.Set(frame, pair[2], o)
    else
        pair[2]:Hide()
    end
end

--- The emblem's side on the splash, by its metal.
local function Size(d, tier)
    return (140 + 16 * tier) * d.k
end

--- Everything your new title's splash draws, for the numbers d.
local function BuildTitle(frame, P, d)
    local k, s = d.k, { d = d }
    s.gloom = P.Tex(frame, "fx_gloom", "BACKGROUND", 2)
    s.light = P.Tex(frame, "spree_glow", "BACKGROUND", 3, true)
    s.head = P.Headline(frame, "", WORD[1], GLOW[1], FLASH[1])
    s.shadow = P.Tex(frame, "fx_gloom", "ARTWORK", 1)
    s.ringDust = P.Tex(frame, "glow", "ARTWORK", 1)
    s.ringLight = P.Tex(frame, "glow", "ARTWORK", 1, true)
    s.emblem = P.Tex(frame, nil, "ARTWORK", 3)
    s.mark = P.Tex(frame, nil, "ARTWORK", 4, true)
    s.dust = { P.Tex(frame, "fx_dust_burst", "OVERLAY", 0), P.Tex(frame, "fx_dust_burst", "OVERLAY", 0) }
    s.ghosts = { P.Tex(frame, d.tex, "OVERLAY", 2), P.Tex(frame, d.tex, "OVERLAY", 2) }
    s.hammer = P.Tex(frame, d.tex, "OVERLAY", 3)
    s.glint = P.Tex(frame, "spree_spark", "OVERLAY", 5, true)
    s.flash = P.Tex(frame, "spree_glow", "OVERLAY", 6, true)
    s.debris = {}
    for tier = 1, 3 do
        s.debris[tier] = P.Burst(frame, d.debris[tier], { t0 = d.impact, cy = EY * k + Size(d, tier) * 0.4 - 6 * k,
            speed = 360 * k, life = 0.7, size = 11 * k, file = "fx_dust", add = false, tint = { 0.55, 0.47, 0.38 },
            gravity = 900 * k, angle = -math.pi / 2, arc = 2.7, seed = 900 + tier })
    end
    return s
end

--- Which title this is: its emblem, its metal, and on the splash its name as the headline in the metal's colours,
--- the kit's gap over the emblem's top, and the line just under it (the emblem fills 0.83 of its square). A title
--- with no emblem of its own (none yet) wears Cutthroat's.
local function StartTitle(s, item)
    local key = type(item.titleKey) == "string" and item.titleKey or GK.TitleKey(item.title)
    if not TIER[key] then key = "cutthroat" end
    s.tier = TIER[key]
    s.emblem:SetTexture(MEDIA .. "title_" .. key)
    s.mark:SetTexture(MEDIA .. "title_" .. key .. "_mark")
    if s.head then
        local w = WORD[s.tier]
        s.head.word:SetText(tostring(item.title or ""):upper())
        s.head.word:SetTextColor(w[1], w[2], w[3])
        s.head.glowTint, s.head.flashTint = GLOW[s.tier], FLASH[s.tier]
        local es, ey = Size(s.d, s.tier), EY * s.d.k
        s.head.y = GK.FxKit.HeadOver(ey - es * 0.42)
        s.lineY = ey + es * 0.42 + 16
    end
end

--- The splash's hammer: it comes in already swinging, from far up out of sight, down round its grip in one stroke
--- onto the spot, a smear of it behind; it rests there a blink and is lifted away, slowly at first.
local function DrawSwing(frame, P, s, age, d, hy)
    local E, impact, h = P.E, d.impact, d.hammer * d.k
    local ha = P.prog(age, impact - d.swing, 0.03)
    local function SwingAt(a0) return P.lerp(2.0, 0, P.prog(age - a0, impact - d.swing, d.swing, E.inC)) end
    local r = SwingAt(0)
    if age >= impact then
        r = 1.1 * P.prog(age, impact + 0.1, 0.4, E.inQ)
        ha = ha * (1 - P.prog(age, impact + 0.32, 0.18))
    end
    -- its grip, where it turns round: as it strikes (no turn) its face is on the spot
    local px, py = -(SIDE_FACE[1] - SIDE_GRIP[1]) * h, hy - (SIDE_FACE[2] - SIDE_GRIP[2]) * h
    local gx, gy = Rot(SIDE_GRIP[1] * h, SIDE_GRIP[2] * h, r)
    P.Set(frame, s.hammer, { x = px - gx, y = py - gy, w = h, h = h, r = r, a = ha })
    for g = 1, 2 do
        if age < impact then
            local rg = SwingAt(g * 0.03)
            local x, y = Rot(SIDE_GRIP[1] * h, SIDE_GRIP[2] * h, rg)
            P.Set(frame, s.ghosts[g], { x = px - x, y = py - y, w = h, h = h, r = rg, a = ha * 0.28 / g })
        else
            s.ghosts[g]:Hide()
        end
    end
end

--- A new title at its age: the hammer, the frame shaken by the blow, the emblem it leaves and the blow's dust and
--- light, then the headline, on the splash.
local function DrawTitle(frame, P, s, age, d)
    local k, E, impact, tier = d.k, P.E, d.impact, s.tier or 1
    local es = Size(d, tier)
    local ey = EY * k
    local foot, hy = ey + es * 0.4, ey + 0.24 * es        -- the ground under it, and where the hammer strikes it: low
    frame.fxShakeX, frame.fxShakeY = 0, 0
    if s.gloom then P.Set(frame, s.gloom, { w = 480, h = 440, a = 0.65 * P.prog(age, 0, 0.15) }) end
    -- the shake, before the rest is placed: everything set this frame moves with it, the gloom behind it does not
    frame.fxShakeX, frame.fxShakeY = Quake(age, impact, d.quake[tier])
    DrawSwing(frame, P, s, age, d, hy)
    if age >= impact then
        local t = age - impact
        local e = math.exp(-t * 11) * math.cos(t * 26)
        -- the mark it leaves: the emblem, pressed in and springing back, its outline lit for a moment
        P.Set(frame, s.shadow, { y = foot, w = es * 0.9, h = es * 0.26, a = 0.6 * P.prog(t, 0, 0.1) })
        P.Set(frame, s.emblem, { y = ey, w = es, h = es, s = 1 + 0.12 * math.exp(-t * 9), sx = 1 + 0.16 * e, sy = 1 - 0.16 * e })
        local fl, gl = FLASH[tier], GLOW[tier]
        P.Set(frame, s.mark, { y = ey, w = es, h = es, a = 0.7 * math.exp(-t * 4), cr = fl[1], cg = fl[2], cb = fl[3] })
        -- the blow: a flash, the metal's light behind it, a ring of dust and a quicker one of light along the
        -- ground, the dust jetting out
        P.Set(frame, s.flash, { y = ey, w = es * 2.6, h = es * 1.7, a = 0.9 * math.exp(-t * 9), cr = 1, cg = 0.88, cb = 0.7 })
        if s.light then
            P.Set(frame, s.light, { y = ey, w = 460, h = 380, a = 0.55 * math.exp(-t * 3) + 0.15, cr = gl[1], cg = gl[2],
                cb = gl[3] })
        end
        local q2, q3 = P.prog(t, 0, 0.6, E.outQ), P.prog(t, 0, 0.32, E.outQ)
        P.Set(frame, s.ringDust, { y = foot, w = es * 1.1, h = es * 0.34, s = P.lerp(0.4, 2.8, q2), a = 0.8 * (1 - q2),
            cr = 0.85, cg = 0.72, cb = 0.55 })
        P.Set(frame, s.ringLight, { y = foot, w = es * 1.1, h = es * 0.34, s = P.lerp(0.3, 2.2, q3), a = 0.7 * (1 - q3),
            cr = 1, cg = 0.85, cb = 0.65 })
        PlaySheet(frame, P, s.dust, t, 22, { y = foot - DUST_LINE * 420 * k, w = 420 * k, h = 420 * k })
        -- and once it has settled, a glint over it
        local g = P.prog(t, 0.9, 0.5)
        if g > 0 and g < 1 then
            P.Set(frame, s.glint, { x = P.lerp(-es * 0.3, es * 0.3, g), y = ey - es * 0.2, w = 44 * k, h = 44 * k,
                a = math.sin(math.pi * g) * (0.4 + 0.2 * tier), cr = 1, cg = 0.95, cb = 0.8 })
        else
            s.glint:Hide()
        end
    else
        for _, t in ipairs({ s.shadow, s.emblem, s.mark, s.flash, s.ringDust, s.ringLight, s.glint }) do t:Hide() end
        if s.light then s.light:Hide() end
        PlaySheet(frame, P, s.dust, -1, 22, {})
    end
    s.debris[tier](age)
    if s.head then P.DrawHeadline(frame, s.head, age, impact + WORD_AT) end
end

-- ---------------------------------------------------------------------------
-- The splash: your own new title
-- ---------------------------------------------------------------------------
GK.FX.rank = {
    land = SPLASH.impact + WORD_AT + 0.1,   -- the line and the hold come with the headline
    -- the title's own call (Settings, Sounds) with the blow, one sound with the thud: it came 0.3 s after it, "boom ..
    -- swoosh" where the owner wanted "boomswoosh" (2026-11-21)
    voice = SPLASH.impact,
    cues = { { SPLASH.impact, "boom" }, { SPLASH.impact, "stamp" } },     -- the tormentor's book's slam
    build = function(splash, P)
        splash.rankFx = BuildTitle(splash, P, SPLASH)
    end,
    start = function(splash, item, P)
        StartTitle(splash.rankFx, item)
    end,
    update = function(splash, age, P)
        P.Set(splash, splash.seal, { a = 0 })            -- the emblem is the picture: no seal
        splash.glow:Hide()                               -- and the metal's light stands for the splash's own glow
        DrawTitle(splash, P, splash.rankFx, age, SPLASH)
        -- the line under the emblem, shaken with it (Announce.lua puts it back for the next splash)
        splash.line:ClearAllPoints()
        splash.line:SetPoint("TOP", splash, "TOP", splash.fxShakeX or 0,
            -P.SEAL / 2 - splash.rankFx.lineY - (splash.fxShakeY or 0))
    end,
}

-- ---------------------------------------------------------------------------
-- The toast: a guildie's new title
-- ---------------------------------------------------------------------------
-- A cloud of dust gathers where the seal would be; the emblem pops out of it, larger than the seal, and blows it
-- away; the line fades in beside it; it stands a little, and the toast fades (its hold, TOAST_HOLD).

--- The dust cloud's puffs, and the emblem it gives way to.
local function BuildPoof(frame, P)
    local s, r = { puffs = {} }, P.rng(331)
    for i = 1, PUFFS do
        local p = {}
        p.dir = r() * math.pi * 2
        local rad = 4 + r() * 12
        p.x, p.y = math.cos(p.dir) * rad, math.sin(p.dir) * rad * 0.8
        p.size, p.born, p.rot, p.spin, p.speed = 40 + r() * 20, r() * 0.18, r() * 6.28, (r() - 0.5) * 1.2, 150 + r() * 80
        p.t = P.Tex(frame, "fx_smoke_puff", "OVERLAY", 1)
        s.puffs[i] = p
    end
    s.emblem = P.Tex(frame, nil, "ARTWORK", 3)
    s.mark = P.Tex(frame, nil, "ARTWORK", 4, true)
    s.flash = P.Tex(frame, "spree_glow", "OVERLAY", 3, true)
    return s
end

--- The cloud gathering, the emblem popping out and the dust blown away from it, and the line fading in.
local function DrawPoof(frame, P, s, age)
    local E = P.E
    for _, p in ipairs(s.puffs) do
        local a = 0.85 * P.prog(age, p.born, 0.2)
        local sc = P.lerp(0.4, 1, E.outQ(P.prog(age, p.born, 0.3)))
        local x, y = TOAST_X + p.x, p.y
        if age >= POOF then
            local t = age - POOF
            local out = (1 - math.exp(-6 * t)) / 6 * p.speed
            x, y = x + math.cos(p.dir) * out, y + math.sin(p.dir) * out
            sc = sc * (1 + 0.8 * P.prog(t, 0, 0.45))
            a = a * (1 - P.prog(t, 0, 0.45))
        end
        P.Set(frame, p.t, { x = x, y = y, w = p.size, h = p.size, s = sc, r = p.rot + p.spin * age, a = a, cr = 0.62,
            cg = 0.55, cb = 0.48 })
    end
    if age >= POOF then
        local t, fl = age - POOF, FLASH[s.tier or 1]
        P.Set(frame, s.emblem, { x = TOAST_X, w = TOAST_ES, h = TOAST_ES, s = P.lerp(1.5, 1, E.outBack(P.prog(t, 0, 0.2))),
            a = P.prog(t, 0, 0.05) })
        P.Set(frame, s.mark, { x = TOAST_X, w = TOAST_ES, h = TOAST_ES, a = 0.8 * math.exp(-t * 5), cr = fl[1], cg = fl[2],
            cb = fl[3] })
        P.Set(frame, s.flash, { x = TOAST_X, w = 120, h = 120, a = 0.9 * math.exp(-t * 9), cr = 1, cg = 0.9, cb = 0.75 })
    else
        s.emblem:Hide()
        s.mark:Hide()
        s.flash:Hide()
    end
    frame.line:SetAlpha(P.prog(age, POOF + 0.12, 0.3))       -- the band behind it follows (Announce.lua)
end

GK.TOASTFX.rank = {
    hold = TOAST_HOLD,
    voice = POOF,                                    -- the call with the poof, as the splash's with its blow
    cues = { { POOF, "stamp" } },
    build = function(toast, P)
        toast.fxOrigin = { point = "TOPLEFT", x = 32, y = -32 }      -- the toast's seal's centre (FxToast.lua)
        toast.rankFx = BuildPoof(toast, P)
    end,
    start = function(toast, item, P)
        StartTitle(toast.rankFx, item)
    end,
    update = function(toast, age, P)
        P.Set(toast, toast.seal, { a = 0 })
        DrawPoof(toast, P, toast.rankFx, age)
    end,
}
