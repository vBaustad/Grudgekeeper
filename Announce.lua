-- Grudgekeeper - the announcements: a spree milestone, a spree that ended, a tormentor put down, a
-- guildie's kill order fulfilled. Each is told as a splash (big, in the middle of the screen,
-- click-through) or a toast (small, stacked under the letter icon), or not at all - the kind's setting
-- says which. Two more settings say when it may come:
-- always, or not in a fight, not in a fight in an instance, not in an instance. One that may not come yet
-- is held, and plays in order when the setting allows (the fight ends, the area changes), one splash
-- after another. Plain frames only: nothing here is secure, protected or a CVar, so it all works in combat.
-- What is told comes from Kills.lua and Guild.lua as GK_SPREE, GK_SPREE_ENDED, GK_TORMENTOR and
-- GK_ORDER_DONE.
local ADDON, GK = ...
local LIB = LibStub("LibForever-1.0")

local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"
local SPLASH_FADE, SPLASH_POP = 0.6, 0.25
local TOAST_FADE, MAX_TOASTS = 0.6, 4
-- How long one shows before it fades is the player's to say (GK.db.announceTime, Options.lua): a toast
-- that many seconds, a splash half of it, as the two were when they were fixed at 5 and 2.5 - which was a
-- little short ("gjør popup visende bittelitt lenger og legg settings så folk kan sette lengde selv", the
-- owner, 2026-11-14): out of the box 7 and 3.5. Read when one is shown, and kept on it, so a change of the
-- setting never cuts one short. A held splash waits for the one before it and a second more.
local TIME_DEFAULT, TIME_MIN, TIME_MAX = 7, 1, 60       -- the default is Core.lua's too (announceTime)

local function ToastHold()
    local t = tonumber(GK.db and GK.db.announceTime) or TIME_DEFAULT
    return math.max(TIME_MIN, math.min(TIME_MAX, t))
end
local function SplashHold() return ToastHold() / 2 end
-- Held announcements are capped: after a long raid in a fight-only setting, a backlog would otherwise all
-- replay at once, long after it mattered. The oldest goes.
local MAX_HELD = 30

-- The sound of each kind until one is picked (GK.db.spreeSounds): the Grudgekeeper calling out each tier.
local DEFAULT_SOUNDS = {
    bloodied = "file:voice_bloodied",
    merciless = "file:voice_merciless",
    butcher = "file:voice_butcher",
    reaper = "file:voice_reaper",
    grudgebound = "file:voice_grudgebound",
    ended = "kit:UI_RAID_BOSS_DEFEATED",
    tormentor = "kit:UI_GARRISON_TOAST_INVASION_ALERT",
    order = "kit:IG_PVP_UPDATE",                 -- a guildie's kill order fulfilled: no row to pick another on
}
GK.SPREE_DEFAULT_SOUNDS = DEFAULT_SOUNDS     -- for the settings page, which shows these until one is picked

--- An item's own sound: the player's pick for it, else the default (the tier's voice).
local function PlayVoice(item)
    if GK.db.sound and not item.silent then
        GK.PlayChoice((GK.db.spreeSounds or {})[item.sound] or DEFAULT_SOUNDS[item.sound])
    end
end

--- Whether an announcement may come now, by its when-setting and where we are.
function GK.AnnounceAllowed(when, inCombat, inInstance)
    if when == "noCombat" then return not inCombat end
    if when == "noCombatInInstance" then return not (inCombat and inInstance) end
    if when == "noInstance" then return not inInstance end
    return true
end

local function InCombat()
    return (InCombatLockdown() or UnitAffectingCombat("player")) and true or false
end

--- Whether an item may come now. leftCombat: the fight just ended, whatever the game still says.
local function Allowed(item, leftCombat)
    local when = item.mine and GK.db.announceWhenMine or GK.db.announceWhenGuild
    -- IsInInstance() itself, not GK.InWorld(): that one is cached and cleared by Core when the area changes,
    -- and this must not depend on whether Core's handler ran before ours
    return GK.AnnounceAllowed(when, not leftCombat and InCombat(), (IsInInstance()) and true or false)
end

-- ---------------------------------------------------------------------------
-- The splash
-- ---------------------------------------------------------------------------
local splash
local splashBusyUntil = 0
local SEAL = 170                  -- the splash seal's size; the ribbon is twice as wide, half as high

-- The fire behind a spree's seal, growing with the tier: the flames' size (times the seal's) and strength,
-- and how many embers rise. Spree ended and tormentor splashes don't burn.
local FIRE = {
    bloodied = { size = 1.83, alpha = 0.55, embers = 4 },
    merciless = { size = 1.98, alpha = 0.7, embers = 7 },
    butcher = { size = 2.15, alpha = 0.85, embers = 10 },
    reaper = { size = 2.32, alpha = 1, embers = 14 },
    grudgebound = { size = 2.54, alpha = 1, embers = 22 },
}
GK.SPREE_FIRE = FIRE             -- for a toast's effect (FxToast.lua), which burns as the splash does
local MAX_EMBERS = 0
for _, fire in pairs(FIRE) do MAX_EMBERS = math.max(MAX_EMBERS, fire.embers) end
-- spree_flames.tga is a sheet of a looping flame: its numbers are GK.FxKit.FLAMES (Effects.lua)
local SHINE_START, SHINE_TIME, SHINE_WIDTH = 0.35, 0.6, 60

--- A dark outline on a line of text, so it reads over snow and sunlit sand as well as at night.
local function Outline(fs)
    local file, size = fs:GetFont()
    if file then fs:SetFont(file, size, "OUTLINE") end
end

--- Where the splash stands: where it was moved to (GK.db.splashAt, Move.lua), else a little above the middle.
local function PlaceSplash()
    splash:ClearAllPoints()
    local p = GK.db.splashAt
    if p and p.point then
        splash:SetPoint(p.point, UIParent, p.relPoint or p.point, p.x or 0, p.y or 0)
    else
        splash:SetPoint("TOP", UIParent, "CENTER", 0, 260)
    end
end

local function BuildSplash()
    splash = CreateFrame("Frame", "GrudgekeeperSplash", UIParent)
    splash:SetFrameStrata("HIGH")
    splash:EnableMouse(false)
    -- Two thirds of the first try, which took too much of the screen (dakristia, who built it, 2026-11-12).
    splash:SetSize(2 * SEAL, SEAL + SEAL / 2 + 40)
    splash:SetMovable(true)                       -- by the mover (Move.lua), to where it was put
    splash:SetClampedToScreen(true)
    PlaceSplash()
    -- A soft ember glow of its own: the letter icon's glow.tga is a ring, and grown this big it read as a
    -- white halo around the seal.
    splash.glow = splash:CreateTexture(nil, "BACKGROUND")
    splash.glow:SetTexture(MEDIA .. "spree_glow")
    splash.glow:SetBlendMode("ADD")
    splash.glow:SetSize(SEAL * 1.8, SEAL * 1.8)
    splash.glow:SetPoint("CENTER", splash, "TOP", 0, -SEAL / 2)
    -- Flames lick up from behind the seal: their middle sits a little above the seal's, as the tops are taller.
    splash.flames = splash:CreateTexture(nil, "BACKGROUND", nil, 1)
    splash.flames:SetTexture(MEDIA .. "spree_flames")
    splash.flames:SetPoint("CENTER", splash, "TOP", 0, -SEAL / 2 + SEAL * 0.04)
    splash.seal = splash:CreateTexture(nil, "ARTWORK")
    splash.seal:SetSize(SEAL, SEAL)
    splash.seal:SetPoint("CENTER", splash, "TOP", 0, -SEAL / 2)
    -- over the seal with room between (sublevel 1) for what the lab draws on the seal and under the ribbon
    splash.ribbon = splash:CreateTexture(nil, "ARTWORK", nil, 2)
    splash.ribbon:SetSize(2 * SEAL, SEAL / 2)
    splash.ribbon:SetPoint("TOP", splash, "TOP", 0, -SEAL + 4)
    -- A light sweeps across the ribbon as it lands, kept to the ribbon's shape by a mask of the ribbon itself.
    splash.shine = splash:CreateTexture(nil, "OVERLAY")
    splash.shine:SetTexture(MEDIA .. "spree_shine")
    splash.shine:SetBlendMode("ADD")
    splash.shine:SetSize(SHINE_WIDTH, SEAL / 2)
    splash.shineMask = splash:CreateMaskTexture()
    splash.shineMask:SetAllPoints(splash.ribbon)
    splash.shine:AddMaskTexture(splash.shineMask)
    splash.embers = {}
    for i = 1, MAX_EMBERS do
        local e = splash:CreateTexture(nil, "OVERLAY")
        e:SetTexture(MEDIA .. "spree_spark")
        e:SetBlendMode("ADD")
        splash.embers[i] = e
    end
    splash.line = splash:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    Outline(splash.line)
    splash.line:SetPoint("TOP", splash, "TOP", 0, -SEAL - SEAL / 2 + 4)
    splash.age, splash.land = 0, 0
    -- The punch (the seal scales in), the glow's pulse, the flames, embers and shine, and the fade, by hand:
    -- one frame's OnUpdate.
    -- With an effect (Effects.lua) all of it starts when the effect's seal lands (k from 0), and the effect
    -- draws over it, and may move the seal, after.
    splash:SetScript("OnUpdate", function(self, dt)
        local age = self.age + dt
        self.age = age
        local k = age - self.land
        local on = k >= 0
        self.seal:SetShown(on)
        self.ribbon:SetShown(on and self.hasRibbon)
        self.line:SetShown(on)
        self.glow:SetShown(on)
        if self.fx then
            self.seal:ClearAllPoints()
            self.seal:SetPoint("CENTER", self, "TOP", 0, -SEAL / 2)
            self.seal:SetRotation(0)
            self.seal:SetVertexColor(1, 1, 1)
            self.seal:SetAlpha(1)
        end
        local s = 1
        if on and k < SPLASH_POP then s = 1.6 - 0.6 * (k / SPLASH_POP) end
        self.seal:SetSize(SEAL * s, SEAL * s)
        self.glow:SetAlpha(0.45 + 0.2 * math.sin(age * 6))
        local fire = self.fire
        self.flames:SetShown(fire ~= nil and on)
        if fire and on then
            local c = GK.FxKit.FlameCell(age)
            self.flames:SetTexCoord(c[1], c[2], c[3], c[4])
            self.flames:SetAlpha(fire.alpha * math.min(1, k / SPLASH_POP))
            local catching = math.min(1, k / 0.3)
            for n = 1, fire.embers do
                local e, m = self.embers[n], self.motes[n]
                local t = (age - m.born) % m.life
                local f = t / m.life
                e:SetPoint("CENTER", self.seal, "CENTER", m.x + m.vx * t, m.y + m.rise * t)
                e:SetAlpha((1 - f) * math.min(1, f * 5) * catching)
            end
        end
        local p = (k - SHINE_START) / SHINE_TIME
        if on and self.hasRibbon and p >= 0 and p <= 1 then
            self.shine:SetPoint("CENTER", self.ribbon, "LEFT", -SHINE_WIDTH + p * (2 * SEAL + 2 * SHINE_WIDTH), 0)
            self.shine:Show()
        else
            self.shine:Hide()
        end
        if self.fx and self.fx.update then self.fx.update(self, age, GK.FxKit) end
        if self.fx then GK.FxKit.Cues(self, self.fx, age) end
        -- the voice comes at the effect's time, as the lab's does, not when the splash shows
        if self.voiceAt and age >= self.voiceAt then
            local item = self.voiceItem
            self.voiceAt, self.voiceItem = nil, nil
            PlayVoice(item)
        end
        -- held: shown to be moved (Move.lua), so it stays until the mover closes
        if self.held then return end
        local hold = self.hold or SplashHold()
        if age >= hold + SPLASH_FADE then
            self:Hide()
        elseif age > hold then
            self:SetAlpha(1 - (age - hold) / SPLASH_FADE)
        end
    end)
    splash:Hide()
end

--- Light the splash's fire for a tier (nil: no fire), with fresh embers each time.
local function Kindle(key)
    local fire = key and FIRE[key]
    splash.fire = fire
    splash.flames:SetShown(fire ~= nil)
    splash.motes = {}
    for n, e in ipairs(splash.embers) do
        e:ClearAllPoints()
        e:SetShown(fire ~= nil and n <= fire.embers)
        if fire and n <= fire.embers then
            local size = 10 + math.random() * 8
            e:SetSize(size, size)
            e:SetAlpha(0)
            -- each mote loops on its own clock: it rises from about the seal's upper half, drifting sideways
            splash.motes[n] = { x = math.random(-60, 60), y = SEAL * 0.3 - math.random(-10, 40),
                vx = math.random(-12, 12), rise = 35 + math.random() * 35,
                life = 0.9 + math.random() * 0.9, born = math.random() * 1.8 }
        end
    end
    if fire then
        splash.flames:SetSize(SEAL * fire.size, SEAL * fire.size)
        splash.flames:SetAlpha(0)
    end
end

--- The splash's effect for an item (Effects.lua), built the first time it plays; nil for none.
local function EffectFor(item)
    local fx = item.effect and GK.FX and GK.FX[item.effect]
    if not fx then return nil end
    splash.fxBuilt = splash.fxBuilt or {}
    if fx.build and not splash.fxBuilt[item.effect] then
        fx.build(splash, GK.FxKit)
        splash.fxBuilt[item.effect] = true
    end
    return fx
end

local function ShowSplash(item)
    if not splash then BuildSplash() end
    splash.seal:SetTexture(item.seal)
    splash.ribbon:SetTexture(item.ribbon)
    splash.hasRibbon = item.ribbon ~= nil
    splash.ribbon:SetShown(item.ribbon ~= nil)
    if item.ribbon then
        splash.shineMask:SetTexture(item.ribbon, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    splash.shine:Hide()
    Kindle(item.fire)
    splash.line:SetText(item.line)
    splash.line:SetTextColor(1, 1, 1, 1)   -- an effect may grey or fade it
    if GK.FxKit then GK.FxKit.HideAll(splash) GK.FxKit.CuesReset(splash) end
    local fx = EffectFor(item)
    splash.fx, splash.land = fx, fx and fx.land or 0
    -- a voice at 0 comes at once, as with no effect, so the call and the splash are never a frame apart
    splash.voiceAt, splash.voiceItem = fx and fx.voice and fx.voice > 0 and fx.voice or nil, item
    if fx and fx.start then fx.start(splash, item, GK.FxKit) end
    -- the hold counts from when the seal lands, so a long arrival never eats it
    splash.age, splash.hold = 0, splash.land + SplashHold()
    splash:SetAlpha(1)
    splash:Show()
    splashBusyUntil = GetTime() + splash.hold + 1
end

-- ---------------------------------------------------------------------------
-- The toasts
-- ---------------------------------------------------------------------------
local active, pool = {}, {}       -- the toasts showing, oldest first, and the frames not in use

local function Relayout()
    local notice = GK.NoticeFrame()
    local at = GK.db.toastAt                      -- where the first was moved to (Move.lua), else under the letter
    for i, t in ipairs(active) do
        t:ClearAllPoints()
        if i == 1 then
            if at and at.point then
                t:SetPoint(at.point, UIParent, at.relPoint or at.point, at.x or 0, at.y or 0)
            elseif notice then
                t:SetPoint("TOPRIGHT", notice, "BOTTOMRIGHT", 0, -26)
            else
                -- the letter is not built until one comes: where it will be
                local rel, x, y = GK.NoticeCorner()
                t:SetPoint("TOPRIGHT", UIParent, rel, x, y - 26)
            end
        else
            t:SetPoint("TOPRIGHT", active[i - 1], "BOTTOMRIGHT", 0, -4)
        end
    end
end

local function RemoveToast(t)
    t:Hide()
    for i, a in ipairs(active) do
        if a == t then table.remove(active, i) break end
    end
    pool[#pool + 1] = t
    Relayout()
end

local function BuildToast()
    local t = CreateFrame("Frame", nil, UIParent)
    t:SetFrameStrata("HIGH")
    t:EnableMouse(false)
    t:SetSize(324, 84)
    t.seal = t:CreateTexture(nil, "ARTWORK")
    t.seal:SetSize(64, 64)
    t.seal:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
    t.ribbon = t:CreateTexture(nil, "ARTWORK")
    t.ribbon:SetSize(256, 64)
    -- from the toast, not the seal: an effect moves the seal and the ribbon each its own way
    t.ribbon:SetPoint("TOPLEFT", t, "TOPLEFT", 68, 0)
    -- a size up from the first try, which was hard to read by the letter icon (dakristia, 2026-11-12)
    t.line = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    Outline(t.line)
    t.line:SetJustifyH("LEFT")
    t:SetMovable(true)                            -- the first is the stack's handle for the mover (Move.lua)
    t:SetClampedToScreen(true)
    t.age = 0
    t:SetScript("OnUpdate", function(self, dt)
        if self.held then return end              -- the mover's sample: it stays until the mover closes
        local age = self.age + dt
        self.age = age
        local hold = self.hold or ToastHold()
        if age >= hold + TOAST_FADE then
            RemoveToast(self)
            return
        elseif age > hold then
            self:SetAlpha(1 - (age - hold) / TOAST_FADE)
        end
        if self.fx and self.fx.update then self.fx.update(self, age, GK.FxKit) end
        if self.fx then GK.FxKit.Cues(self, self.fx, age) end
    end)
    return t
end

--- A toast's effect for an item (FxToast.lua), built the first time this toast plays it; nil for none.
local function ToastEffectFor(t, item)
    local fx = item.toastEffect and GK.TOASTFX and GK.TOASTFX[item.toastEffect]
    if not fx then return nil end
    t.fxBuilt = t.fxBuilt or {}
    if fx.build and not t.fxBuilt[item.toastEffect] then
        fx.build(t, GK.FxKit)
        t.fxBuilt[item.toastEffect] = true
    end
    return fx
end

--- Put a pooled toast's parts back where BuildToast had them: an effect moved, turned, tinted or hid them.
local function ResetToast(t)
    t.seal:ClearAllPoints()
    t.seal:SetPoint("TOPLEFT", t, "TOPLEFT", 0, 0)
    t.seal:SetSize(64, 64)
    t.seal:SetTexCoord(0, 1, 0, 1)                  -- before the turn: the last of the two set wins
    t.seal:SetRotation(0)
    t.seal:SetVertexColor(1, 1, 1)
    t.seal:SetAlpha(1)
    t.seal:Show()
    t.ribbon:ClearAllPoints()
    t.ribbon:SetPoint("TOPLEFT", t, "TOPLEFT", 68, 0)
    t.ribbon:SetSize(256, 64)
    t.ribbon:SetAlpha(1)
    t.line:SetAlpha(1)
    if GK.FxKit then GK.FxKit.HideAll(t) GK.FxKit.CuesReset(t) end   -- the last effect's textures and cues, whatever this one is
end

local function ShowToast(item)
    if #active >= MAX_TOASTS then RemoveToast(active[1]) end
    local t = table.remove(pool) or BuildToast()
    ResetToast(t)
    t.seal:SetTexture(item.seal)
    t.ribbon:SetTexture(item.ribbon)
    t.ribbon:SetShown(item.ribbon ~= nil)
    t.hasRibbon = item.ribbon ~= nil
    t.line:SetText(item.line)
    -- centred under its ribbon, as the splash's line is under its own; with no ribbon, beside the seal. It
    -- stood at the toast's left edge, under the seal: "teksten under det lille banneret er det left aligned
    -- eller noe?" (the owner, 2026-11-12)
    t.line:ClearAllPoints()
    if item.ribbon then
        t.line:SetPoint("TOP", t.ribbon, "BOTTOM", 0, -4)
        t.line:SetWidth(256)
        t.line:SetJustifyH("CENTER")
    else
        t.line:SetPoint("LEFT", t.seal, "RIGHT", 4, 0)
        t.line:SetWidth(256)
        t.line:SetJustifyH("LEFT")
    end
    t.age, t.hold = 0, ToastHold()
    t:SetAlpha(1)
    local fx = ToastEffectFor(t, item)
    t.fx = fx
    if fx and fx.start then fx.start(t, item, GK.FxKit) end
    if fx and fx.update then fx.update(t, 0, GK.FxKit) end     -- so the first frame is the effect's, not the plain toast
    active[#active + 1] = t
    Relayout()
    t:Show()
end

-- ---------------------------------------------------------------------------
-- Showing, holding and releasing
-- ---------------------------------------------------------------------------
local held, ready = {}, {}        -- not allowed yet; allowed and waiting for their turn. Both in arrival order.
local drainTimer = false

--- What an item is shown with, and its sound: when it is shown, not when it was queued.
local function Show(item)
    if item.style == "splash" then ShowSplash(item) else ShowToast(item) end
    -- a splash with an effect plays it at the effect's voice time (its OnUpdate), the rest at once
    if item.style == "splash" and splash.voiceAt then return end
    PlayVoice(item)
end

--- Show what is ready: the toasts at once, the splashes in their own order, each when the one before it has
--- had its time. A toast never waits for a splash.
local function Drain()
    local waiting = {}
    for _, item in ipairs(ready) do
        local wait = splashBusyUntil - GetTime()
        if item.style == "splash" and (wait > 0 or #waiting > 0) then
            waiting[#waiting + 1] = item
        else
            Show(item)
        end
    end
    ready = waiting
    local wait = splashBusyUntil - GetTime()
    if waiting[1] and wait > 0 and not drainTimer then
        drainTimer = true
        C_Timer.After(wait + 0.05, function()
            drainTimer = false
            Drain()
        end)
    end
end

--- The held ones that may come now go to ready, in the order they arrived.
local function ReleaseHeld(leftCombat)
    local keep = {}
    for _, item in ipairs(held) do
        if Allowed(item, leftCombat) then ready[#ready + 1] = item else keep[#keep + 1] = item end
    end
    held = keep
    Drain()
end

local function Tell(item)
    if Allowed(item) then
        ready[#ready + 1] = item
        Drain()
    else
        held[#held + 1] = item
        if #held > MAX_HELD then table.remove(held, 1) end
    end
end

LIB.On("PLAYER_REGEN_ENABLED", function() if #held > 0 then ReleaseHeld(true) end end)
LIB.On("PLAYER_ENTERING_WORLD", function() if #held > 0 then ReleaseHeld(false) end end)
LIB.On("ZONE_CHANGED_NEW_AREA", function() if #held > 0 then ReleaseHeld(false) end end)

-- ---------------------------------------------------------------------------
-- What is told
-- ---------------------------------------------------------------------------
--- A name as it may be printed: a question mark when the game hides it.
local function Hide(name)
    if GK.Secret(name) then return "?" end
    return name
end

local function Name(key) return Hide(GK.Show(key)) end

--- setting: the kind's own (off, toast, splash). nil for anything else, which shows nothing.
local function Style(setting)
    local s = GK.db and GK.db[setting]
    if s == "toast" or s == "splash" then return s end
    return nil
end

local function Add(setting, mine, item)
    item.style = Style(setting)
    if not item.style then return end
    item.mine = mine
    Tell(item)
end

LIB.Listen("GK_SPREE", function(who, spree, tierName, mine, key)
    if not key then return end
    local line = ("%d kills in a row"):format(spree)
    if not mine then line = Name(who) .. ": " .. line end
    Add(mine and "spreeMine" or "spreeGuild", mine, { seal = MEDIA .. "spree_" .. key,
        ribbon = MEDIA .. "spree_" .. key .. "_name", line = line, sound = key, fire = key,
        effect = GK.SpreeEffect and GK.SpreeEffect("spree", key, spree, GK.db), spree = spree,
        toastEffect = GK.ToastEffect and GK.ToastEffect("spree", mine) })
end)

LIB.Listen("GK_SPREE_ENDED", function(who, spree, killerName, mine)
    local line
    if mine then
        line = ("Your %d-kill spree ended (%s)"):format(spree, Hide(killerName))
    else
        line = ("%s's %d-kill spree ended (%s)"):format(Name(who), spree, Hide(killerName))
    end
    Add("spreeEnded", mine, { seal = MEDIA .. "seal_broken", line = line, sound = "ended",
        effect = GK.SpreeEffect and GK.SpreeEffect("ended", nil, spree, GK.db), spree = spree })
end)

LIB.Listen("GK_TORMENTOR", function(who, enemyName, count, mine)
    local line = ("%s put an end to %s, who had killed %d of us"):format(mine and "You" or Name(who), Hide(enemyName), count)
    Add("spreeTormentor", mine, { seal = MEDIA .. "seal_black", line = line, sound = "tormentor",
        effect = GK.SpreeEffect and GK.SpreeEffect("tormentor", nil, count, GK.db),
        toastEffect = GK.ToastEffect and GK.ToastEffect("tormentor", mine) })
end)

-- A guildie got the target of a kill order (Guild.lua, the F we heard): told as it happens, to everyone -
-- also who has a letter coming for it, the poster and who put gold in. Without it nobody who was not
-- there knew, unless the hunter told guild chat ("noen drepte en på kill order nå. men det er ikke
-- egentlig mulig for meg, som ikke var med, å egentlig se det", the owner, 2026-11-14). The seal is the
-- red wax a kill order's letter is sealed with: 128 across as the other two are, where the skull an order
-- puts over a nameplate is 64, too few for a splash.
LIB.Listen("GK_ORDER_DONE", function(who, helpers, targetKey, pot)
    local more = type(helpers) == "table" and #helpers or 0
    local line = ("Kill order fulfilled: %s, by %s%s%s"):format(Name(targetKey), Name(who),
        more > 0 and (" and %d more"):format(more) or "",
        (tonumber(pot) or 0) > 0 and (" - " .. GK.MoneyText(pot)) or "")
    Add("orderDone", false, { seal = MEDIA .. "seal_red", line = line, sound = "order" })
end)

-- what /grudge spree <what> shows: a tier, a number of kills, Reaper's two, a spree ended or a tormentor
local SAMPLE_KILLS = { bloodied = 3, merciless = 5, butcher = 7, reaper = 10, scythe = 10, smoke = 10, grudgebound = 15 }

--- /grudge spree: a sample splash and a sample toast, whatever the settings and the when-rules say.
--- what: a tier's key, "scythe" or "smoke" (Reaper's two), a spree's kills ("20", "100"), "ended" or
--- "tormentor"; none: Butcher, as before. A tier's toast is as your own spree's, with its effect; a spree
--- ended has only the splash.
function GK.AnnounceSample(what)
    what = what and what:lower() or "butcher"
    if what == "ended" or what == "tormentor" then
        local tormentor = what == "tormentor"
        local seal = MEDIA .. (tormentor and "seal_black" or "seal_broken")
        local line = tormentor and "You put an end to Glue Enjoyer, who had killed 4 of us" or "Your 12-kill spree ended (Glue Enjoyer)"
        Show({ style = "splash", seal = seal, sound = what, line = line,
            effect = GK.SpreeEffect(what, nil, 12, GK.db), spree = 12 })
        if tormentor then
            Show({ style = "toast", seal = seal, line = line, silent = true, toastEffect = GK.ToastEffect("tormentor", true) })
        end
        return
    end
    local kills = tonumber(what) or SAMPLE_KILLS[what] or 7
    local _, key = GK.SpreeTierOf(kills)
    key = key or "butcher"
    local effect = GK.SpreeEffect("spree", key, kills, GK.db)
    if what == "scythe" or what == "smoke" then effect = "reaper_" .. what end
    Show({ style = "splash", seal = MEDIA .. "spree_" .. key, ribbon = MEDIA .. "spree_" .. key .. "_name",
        line = ("%d kills in a row"):format(kills), sound = key, fire = key, effect = effect, spree = kills })
    Show({ style = "toast", seal = MEDIA .. "spree_" .. key, ribbon = MEDIA .. "spree_" .. key .. "_name",
        line = ("%d kills in a row"):format(kills), silent = true, fire = key, spree = kills,
        toastEffect = GK.ToastEffect("spree", true) })
end

-- ---------------------------------------------------------------------------
-- The mover (Move.lua): a sample splash and toast that stay to be dragged, and where they were put
-- ---------------------------------------------------------------------------
local sampleToast

--- Where a frame was dragged to, as the letter icon keeps its own: its point, UIParent's, and the offsets.
local function PointOf(f)
    local point, _, relPoint, x, y = f:GetPoint(1)
    return { point = point, relPoint = relPoint, x = x, y = y }
end

local function IsActive(t)
    for _, a in ipairs(active) do
        if a == t then return true end
    end
    return false
end

--- on: the splash shown, with a sample, until the mover closes; returns it. Off: gone.
function GK.SplashForMove(on)
    if not splash then BuildSplash() end
    if not on then
        splash.held = nil
        splash:Hide()
        return nil
    end
    ShowSplash({ seal = MEDIA .. "spree_butcher", ribbon = MEDIA .. "spree_butcher_name",
        line = "7 kills in a row", fire = "butcher" })
    splash.held = true
    return splash
end

function GK.SplashMoved() GK.db.splashAt = PointOf(splash) end

function GK.SplashReset()
    GK.db.splashAt = nil
    if splash then PlaceSplash() end
end

--- on: a sample toast in the stack until the mover closes, and the stack's first, which the rest hang
--- from, to drag; returns that one. Off: the sample gone.
function GK.ToastsForMove(on)
    if not on then
        if sampleToast then
            sampleToast.held = nil
            if IsActive(sampleToast) then RemoveToast(sampleToast) end
            sampleToast = nil
        end
        return nil
    end
    if not (sampleToast and IsActive(sampleToast)) then
        ShowToast({ seal = MEDIA .. "spree_butcher", ribbon = MEDIA .. "spree_butcher_name",
            line = "Glue Enjoyer: 7 kills in a row" })
        sampleToast = active[#active]
        sampleToast.held = true
    end
    return active[1]
end

function GK.ToastsMoved()
    if active[1] then GK.db.toastAt = PointOf(active[1]) end
    Relayout()
end

function GK.ToastsReset()
    GK.db.toastAt = nil
    Relayout()
end
