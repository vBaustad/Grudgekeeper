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
-- The words show with the seal from the start and grey as it bursts, and the splash fades as the shards do (hold,
-- Announce.lua), whatever the announcement time is set to: they came only after the shatter and stood alone long
-- after it ("spree ended burde ha text med en gang samtidig som bildet og fade bort ca samtidig som bildet", the
-- owner, 2026-11-21). The shards are gone at B + 1.25; the fade takes 0.6.
local ENDED_HOLD = B + 0.65
local ended = { land = 0, voice = B + 1.1, hold = ENDED_HOLD,
    -- the game's own (round 8, the owner's picks in the lab, 2026-11-21): a thunder rumble under the pulse
    -- (FX_TKISLE_MWTHUNDERRUMBLE01), the rock bursting as the seal does (FX_Explosion_Rock_Debris_03), the tribal bell
    -- as its toll (BellTollTribal). No call after it out of the box (Announce.lua): these three are its sound
    cues = { { 0, 838830 }, { B, 930444 }, { B + 0.05, 566027 } } }
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
    local grey = P.prog(age, B, .4)
    splash.line:SetTextColor(P.lerp(1, GREY[1], grey), P.lerp(1, GREY[2], grey), P.lerp(1, GREY[3], grey), 1)
end

-- ---------------------------------------------------------------------------
-- E1 at a toast's size: the cracked seal bursting into its six shards in the toast's 64 px seal. As a toast -
-- which is how your own spree's end comes out of the box - there was no effect, only the broken seal: "lag
-- toast versjon" (the owner, 2026-11-20). The splash's numbers times K. Once the shards have fallen nothing is
-- left of it, as on the splash: the toast's own broken stamp is another drawing, and it does not show.
-- ---------------------------------------------------------------------------
local TOAST_SEAL = 64
local K = TOAST_SEAL / 170             -- the toast's seal against the splash's

GK.TOASTFX = GK.TOASTFX or {}
local endedToast = { hold = ENDED_HOLD, cues = { { 0, 838830 }, { B, 930444 } } }   -- gone with its shards; the splash's sounds
GK.TOASTFX.ended_shatter = endedToast

function endedToast.build(toast, P)
    toast.fxOrigin = { point = "TOPLEFT", x = 32, y = -32 }      -- the toast's seal's centre (FxToast.lua)
    local r = P.rng(11)
    local s = {}
    s.whole = P.Tex(toast, "fx_shatter_whole", "ARTWORK", 1)
    s.bright = P.Tex(toast, "fx_shatter_whole", "ARTWORK", 2, true)
    s.shards = {}
    for i, sh in ipairs(SHARDS) do
        s.shards[i] = { n = P.Tex(toast, "fx_shard_" .. i, "ARTWORK", 4), x0 = sh[1] * K, y0 = sh[2] * K,
            rot = sh[3], vx = (sh[1] * (3 + r() * 2) + (r() - .5) * 80) * K,
            vy = (sh[2] * 2.2 - 160 - r() * 120) * K, spin = (r() - .5) * 6 }
    end
    s.chips = P.Burst(toast, 14, { t0 = B, speed = 380 * K, life = 0.9, size = 5, gravity = 700 * K,
        file = "spree_spark" })
    toast.endedFx = s
end

function endedToast.update(toast, age, P)
    local s = toast.endedFx
    local pulse = 0
    if age < B then
        for i, h in ipairs({ .07, .67 }) do
            if age >= h then pulse = math.max(pulse, (i == 2 and 1 or .55) * math.exp(-(age - h) * 7)) end
        end
    end
    local whole = { w = TOAST_SEAL * 1.15, h = TOAST_SEAL * 1.15, a = 0 }
    if age < B then
        whole.a = P.prog(age, 0, .15)
        whole.s = 1 + pulse * .03 + (age / B) * .04
        if age > B - .3 then whole.x = (math.random() - .5) * 2 end
    end
    P.Set(toast, s.whole, whole)
    local bright = {}
    for k, v in pairs(whole) do bright[k] = v end
    bright.a = whole.a * pulse * .5
    P.Set(toast, s.bright, bright)
    for _, sh in ipairs(s.shards) do
        local d = age - B
        if d < 0 then
            sh.n:Hide()
        else
            P.Set(toast, sh.n, { w = 92 * K, h = 92 * K, x = sh.x0 + sh.vx * d, y = sh.y0 + sh.vy * d + 650 * K * d * d,
                r = sh.rot + sh.spin * d, a = math.max(0, 1 - d * .8) })
        end
    end
    s.chips(age)
    -- only the seal that shatters, as on the splash: the toast's own stamp never shows. It settled after the burst,
    -- another drawing beside the shards ("vi skal ikke ha stempelet, kun det som knuses", the owner, 2026-11-20).
    -- The line is there from the start and greys as the seal bursts: a toast's words are what it says, and they
    -- came only after the shatter ("viser den splash animasjonen først uten text og så kommer text")
    toast.seal:Hide()
    local grey = P.prog(age, B, .4)
    toast.line:SetTextColor(P.lerp(1, GREY[1], grey), P.lerp(1, GREY[2], grey), P.lerp(1, GREY[3], grey), 1)
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

-- ---------------------------------------------------------------------------
-- T4: the grudge book slams down. G in the effect lab (art/lab/effektlab), the owner's pick, 2026-11-21.
-- ---------------------------------------------------------------------------
-- "la oss tenke ut andre løsninger som er litt slik 'bang' tormentor slain!" (the owner, after a book slamming
-- shut could not be made smooth from drawn frames). The shut grudge book (fx_book, Codex', art/import_tormentor.py)
-- drops from above, turning a little, its shadow growing under it, and strikes the ground: a flash and a red bloom,
-- squashed flat against the ground and bouncing, the whole splash shaken (P.Set's fxShakeX/Y), a ring of dust and a
-- ring of light running out along the ground, the drawn dust jetting sideways (fx_dust_burst, 16 frames, the next
-- faded in over each), debris and sparks; then TORMENTOR SLAIN slams down over it, and embers rise. Every part is a
-- still moved by code, as the poster is, so it runs at the screen's own rate. The sounds: the impact, and the
-- event's own call (Settings, Sounds) with the word. A guildie's is the toast: the same fall and impact, no word.
-- The lab's numbers are by its picture of 210 (L); fx_book has room round the book to turn in its square, so it
-- is drawn larger (T4_BOOK) for the book to stand as tall as the lab's.
local T4_BOOK = 246                    -- fx_book's square on the splash; the book fills 0.713 of it: 175 tall
local T4_FOOT = 80                     -- the book's bottom edge below its middle: the ground it strikes
local T4_DUST_LINE = 0.087             -- the dust's first streak, below its cell's middle (fx_dust_burst)
local T4_LINE_Y = 122                  -- the line's top; the word is the kit's headline (P.Headline, Effects.lua)
local T4_BOOK_FILL = 0.713             -- how much of fx_book's square the book stands
local T4_WORD_COLOUR, T4_WORD_GLOW, T4_WORD_FLASH = { 1, 0.69, 0.25 }, { 1, 0.45, 0.15 }, { 1, 0.7, 0.4 }  -- ember gold

local T4_SPLASH = { k = 1, gy = 18, fall0 = 0.18, impact = 0.46, from = -380, word = true, debris = 22, sparks = 26,
    sparkSize = 9, embers = 14, emberSize = 1, shake = 1 }
local T4_TOAST = { k = 0.3, gy = 2, fall0 = 0.06, impact = 0.3, from = -90, word = false, debris = 8, sparks = 8,
    sparkSize = 5, embers = 5, emberSize = 0.6, shake = 0.35 }
local T4_WORD_AT = T4_SPLASH.impact + 0.34

--- A 4 by 4 sheet's cell, { l, r, t, b }; mirrored, its left and right swapped.
local function SheetCell(i, mirror)
    local col, row = i % 4, math.floor(i / 4)
    local l, r = col / 4, (col + 1) / 4
    if mirror then l, r = r, l end
    return { l, r, row / 4, (row + 1) / 4 }
end

--- A flipbook t seconds in, at fps, the next frame faded in over each so it runs smooth: pair is two textures of
--- the sheet, o as P.Set's (its a the whole sheet's), mirror swaps it left to right.
local function PlaySheet(frame, P, pair, t, fps, frames, o, mirror)
    local f = t * fps
    local i = math.floor(f)
    if t < 0 or i >= frames then
        pair[1]:Hide()
        pair[2]:Hide()
        return
    end
    local w, a = f - i, o.a or 1
    o.coord, o.a = SheetCell(i, mirror), a * (i + 1 < frames and 1 or 1 - w)
    P.Set(frame, pair[1], o)
    if i + 1 < frames then
        o.coord, o.a = SheetCell(i + 1, mirror), a * w
        P.Set(frame, pair[2], o)
    else
        pair[2]:Hide()
    end
end

local function BuildDrop(frame, P, d)
    local k, s = d.k, {}
    local foot = d.gy + T4_FOOT * k
    if d.word then
        s.gloom = P.Tex(frame, "fx_gloom", "BACKGROUND", 2)
        s.bloom = P.Tex(frame, "spree_glow", "BACKGROUND", 3, true)
        -- the headline the kit's gap over the book's top edge (the book fills T4_BOOK_FILL of its square)
        s.head = P.Headline(frame, "TORMENTOR SLAIN", T4_WORD_COLOUR, T4_WORD_GLOW, T4_WORD_FLASH,
            P.HeadOver(d.gy - T4_BOOK * k * T4_BOOK_FILL / 2))
        s.wsparks = P.Burst(frame, 20, { t0 = T4_WORD_AT, cy = s.head.y, speed = 280, life = 0.5, size = 8, stretch = 2,
            gravity = 200, seed = 71 })
    end
    s.shadow = P.Tex(frame, "fx_gloom", "ARTWORK", 0)
    s.ringDust = P.Tex(frame, "glow", "ARTWORK", 1)
    s.ringLight = P.Tex(frame, "glow", "ARTWORK", 1, true)
    s.dustBack = { P.Tex(frame, "fx_dust_burst", "ARTWORK", 1), P.Tex(frame, "fx_dust_burst", "ARTWORK", 1) }
    s.smear = { P.Tex(frame, "fx_book", "ARTWORK", 2), P.Tex(frame, "fx_book", "ARTWORK", 2) }
    s.book = P.Tex(frame, "fx_book", "ARTWORK", 3)
    s.dust = { P.Tex(frame, "fx_dust_burst", "OVERLAY", 0), P.Tex(frame, "fx_dust_burst", "OVERLAY", 0) }
    s.flash = P.Tex(frame, "spree_glow", "OVERLAY", 4, true)
    s.debris = P.Burst(frame, d.debris, { t0 = d.impact, cy = foot - 6 * k, speed = 360 * k, life = 0.8, size = 12 * k,
        file = "fx_dust", add = false, tint = { 0.45, 0.38, 0.32 }, gravity = 900 * k, angle = -math.pi / 2, arc = 2.6,
        seed = 61 })
    s.sparks = P.Burst(frame, d.sparks, { t0 = d.impact, cy = foot - 10 * k, speed = 440 * k, life = 0.6,
        size = d.sparkSize, gravity = 700 * k, angle = -math.pi / 2, arc = 2.8, stretch = 2.2, seed = 67 })
    -- embers rising from round the book, each on its own loop
    local r, L = P.rng(73), 210 * k
    s.embers = {}
    for i = 1, d.embers do
        s.embers[i] = { t = P.Tex(frame, "spree_spark", "OVERLAY", 1, true), x = (r() - 0.5) * L * 1.1, born = r() * 1.6,
            life = 1.2 + r() * 0.8, rise = (70 + r() * 60) * k, drift = (r() - 0.5) * 30 * k,
            size = (4 + r() * 5) * d.emberSize }
    end
    return s
end

local function DrawDrop(frame, P, s, age, d)
    local k, E, impact = d.k, P.E, d.impact
    local L = 210 * k                                   -- the lab's picture: the numbers below are by it
    local foot = d.gy + T4_FOOT * k
    frame.fxShakeX, frame.fxShakeY = 0, 0
    if s.gloom then P.Set(frame, s.gloom, { w = 480, h = 440, a = 0.65 * P.prog(age, 0, 0.15) }) end
    -- the shake, before the rest is placed: everything set this frame moves with it
    local shx, shy = 0, 0
    if age >= impact and age < impact + 0.6 then
        local t = age - impact
        local dd = math.exp(-t * 9) * d.shake
        shx, shy = 9 * dd * math.sin(t * 61), 7 * dd * math.cos(t * 47)
    end
    if d.word and age >= T4_WORD_AT and age < T4_WORD_AT + 0.3 then
        local t = age - T4_WORD_AT
        local dd = math.exp(-t * 12)
        shx, shy = shx + 3 * dd * math.sin(t * 70), shy + 2 * dd * math.cos(t * 55)
    end
    frame.fxShakeX, frame.fxShakeY = shx, shy
    -- the fall: from above, faster and faster, turning straight and coming a little toward the camera
    local f = P.prog(age, d.fall0, impact - d.fall0, E.inQ)
    local a = P.prog(age, d.fall0, 0.06)
    local y, rot, sc, sx, sy = P.lerp(d.from, d.gy, f), P.lerp(-0.45, 0, E.outQ(f)), P.lerp(1.3, 1, f), 1, 1
    -- on the ground: squashed flat against it and springing back, a hop, a slow float after
    if age >= impact then
        local t = age - impact
        local e = math.exp(-t * 10) * math.cos(t * 24)
        sx, sy = 1 + 0.22 * e, 1 - 0.22 * e
        y = d.gy - 14 * k * math.max(0, math.sin(t * 11)) * math.exp(-t * 5) + (1 - sy) * T4_FOOT * k
        rot = 0.05 * math.exp(-t * 5) * math.sin(t * 18)
        y = y + 2.5 * k * math.sin((t - 1.2) * 2) * P.prog(t, 0.9, 0.8)
        sc = 1
    end
    -- its shadow on the ground, growing as it comes; a smear of it behind while it falls
    P.Set(frame, s.shadow, { y = foot, w = L * 1.05, h = L * 0.34, s = P.lerp(0.35, 1, f), a = 0.75 * f })
    for g = 1, 2 do
        if age < impact and f > 0.2 then
            P.Set(frame, s.smear[g], { y = y - g * 26 * k * f, w = T4_BOOK * k, h = T4_BOOK * k, s = sc,
                r = rot - g * 0.03, a = a * 0.26 / g })
        else
            s.smear[g]:Hide()
        end
    end
    P.Set(frame, s.book, { y = y, w = T4_BOOK * k, h = T4_BOOK * k, s = sc, sx = sx, sy = sy, r = rot, a = a })
    if age >= impact then
        local t = age - impact
        -- the flash, and a red bloom round it (soft-edged: a filled box would show as a box on the world)
        if s.bloom then
            P.Set(frame, s.bloom, { y = foot - L * 0.3, w = 520, h = 420, a = 0.7 * math.exp(-t * 5), cr = 0.75, cg = 0.06,
                cb = 0.03 })
        end
        P.Set(frame, s.flash, { y = foot - L * 0.15, w = L * 2.6, h = L * 1.4, a = 0.9 * math.exp(-t * 9), cr = 1,
            cg = 0.85, cb = 0.7 })
        -- a ring of dust and a quicker ring of light, running out along the ground
        local q2, q3 = P.prog(t, 0, 0.6, E.outQ), P.prog(t, 0, 0.32, E.outQ)
        P.Set(frame, s.ringDust, { y = foot, w = L * 0.9, h = L * 0.3, s = P.lerp(0.4, 3.0, q2), a = 0.8 * (1 - q2),
            cr = 0.85, cg = 0.72, cb = 0.55 })
        P.Set(frame, s.ringLight, { y = foot, w = L * 0.9, h = L * 0.3, s = P.lerp(0.3, 2.4, q3), a = 0.75 * (1 - q3),
            cr = 1, cg = 0.8, cb = 0.6 })
        -- the drawn dust jetting out along the ground, and a larger, fainter one mirrored behind it
        PlaySheet(frame, P, s.dust, t, 22, 16, { y = foot - T4_DUST_LINE * 440 * k, w = 440 * k, h = 440 * k })
        PlaySheet(frame, P, s.dustBack, t - 0.04, 20, 16, { y = foot - T4_DUST_LINE * 540 * k - 8 * k, w = 540 * k,
            h = 540 * k, a = 0.5 }, true)
        for _, m in ipairs(s.embers) do
            local u = ((t + m.born) % m.life) / m.life
            P.Set(frame, m.t, { x = m.x + m.drift * u, y = foot - 10 * k - m.rise * u, w = m.size, h = m.size,
                a = math.sin(math.pi * u) * 0.8 * P.prog(t, 0.15, 0.4) })
        end
    else
        if s.bloom then s.bloom:Hide() end
        s.flash:Hide()
        s.ringDust:Hide()
        s.ringLight:Hide()
        for _, pair in ipairs({ s.dust, s.dustBack }) do
            pair[1]:Hide()
            pair[2]:Hide()
        end
        for _, m in ipairs(s.embers) do m.t:Hide() end
    end
    s.debris(age)
    s.sparks(age)
    -- the word slams down over it (the kit's headline), and sparks fly from it
    if d.word then
        P.DrawHeadline(frame, s.head, age, T4_WORD_AT)
        s.wsparks(age)
    end
end

GK.FX.tormentor = {
    land = T4_WORD_AT + 0.1,           -- the line and the hold come with the word
    -- the event's own call (Settings, Sounds) with the slam, one sound with it: it came 0.34 s later, "litt mye pause
    -- imellom" (the owner, 2026-11-21). And a heavy rock impact under the boom and the stamp: in game the slam was
    -- not "like punchy" as in the lab, where nothing else plays - the boom has next to nothing above 100 Hz, which
    -- the game's music covers; the rock (FX_RockImpact_Heavy_Short_01) has its body at 100-1000 Hz and starts at once
    voice = T4_SPLASH.impact,
    cues = { { T4_SPLASH.impact, "boom" }, { T4_SPLASH.impact, "stamp" }, { T4_SPLASH.impact, 1345549 } },
    build = function(splash, P) splash.drop = BuildDrop(splash, P, T4_SPLASH) end,
    update = function(splash, age, P)
        P.Set(splash, splash.seal, { a = 0 })         -- the book is the picture: the splash shows no seal, no glow
        splash.glow:Hide()
        DrawDrop(splash, P, splash.drop, age, T4_SPLASH)
        -- the line under the book, shaken with it (Announce.lua puts it back for the next splash)
        splash.line:ClearAllPoints()
        splash.line:SetPoint("TOP", splash, "TOP", splash.fxShakeX or 0, -P.SEAL / 2 - T4_LINE_Y - (splash.fxShakeY or 0))
    end,
}

GK.TOASTFX.tormentor = {
    voice = T4_TOAST.impact,                    -- the call with the slam, as the splash's
    cues = { { T4_TOAST.impact, "stamp" } },
    build = function(toast, P)
        toast.fxOrigin = { point = "TOPLEFT", x = 32, y = -32 }      -- the toast's seal's centre (FxToast.lua)
        toast.drop = BuildDrop(toast, P, T4_TOAST)
    end,
    update = function(toast, age, P)
        toast.seal:Hide()                                           -- the book is the picture
        DrawDrop(toast, P, toast.drop, age, T4_TOAST)
    end,
}
