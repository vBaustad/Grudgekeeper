-- Grudgekeeper - moving what comes up on the screen by itself: the letter icon (with the warning line and
-- the bubble that hang from it), the spree splash and the spree toasts. /grudge arrange (move is the notes'
-- command, moving a mark between lists), or Arrange on screen in the settings (which close for it, and
-- open again at Done), shows each where it stands, a sample where there is nothing to show, with a
-- frame and its name over it: drag it where you want it, right-click it to put it back. Done or Escape
-- ends it. "lag en mover for alle slike elementer, litt likt som hvordan headstart har 'move'" (the owner,
-- 2026-11-12) - a lighter one than Headstart's Arrange: three things, no grid, no snapping.
-- Not in a fight: it won't open in one, and one that begins closes it. The bubble's target button is a
-- secure frame, laid over the bubble again only out of combat (Notice.lua).
-- Each thing keeps its own place in its own file (GK.db.notice, splashAt, toastAt); this file only asks.
local ADDON, GK = ...
local LIB = LibStub("LibForever-1.0")

-- { its name; show(on): shown to be moved, returning its frame (on), or as it was (off); moved(): keep
-- where it was dragged; reset(): back where it starts }
local ITEMS = {
    { name = "Letter icon",
      show = function(on) return GK.NoticeForMove(on) end,
      moved = function() GK.NoticeMoved() end,
      reset = function() GK.NoticeReset() end },
    { name = "Spree splash",
      show = function(on) return GK.SplashForMove and GK.SplashForMove(on) end,
      moved = function() GK.SplashMoved() end,
      reset = function() GK.SplashReset() end },
    { name = "Spree toasts",
      show = function(on) return GK.ToastsForMove and GK.ToastsForMove(on) end,
      moved = function() GK.ToastsMoved() end,
      reset = function() GK.ToastsReset() end },
}

local bar
local handles = {}
local open = false

--- The frame and name laid over one thing. Dragging it drags the thing; a right-click puts it back.
local function Handle(item)
    local h = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    h:SetFrameStrata("DIALOG")
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    h:SetBackdropColor(0.47, 0.06, 0.04, 0.25)
    h:SetBackdropBorderColor(1, 0.82, 0.35, 1)
    h.label = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h.label:SetPoint("BOTTOM", h, "TOP", 0, 2)
    h.label:SetText(item.name)
    h:SetScript("OnDragStart", function(self)
        local f = self.target
        if not f then return end
        f:SetMovable(true)
        f:StartMoving()
    end)
    h:SetScript("OnDragStop", function(self)
        local f = self.target
        if not f then return end
        f:StopMovingOrSizing()
        -- ours keeps the place, not the game's layout cache: it would put it back on its own at login
        pcall(f.SetUserPlaced, f, false)
        item.moved()
    end)
    h:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then item.reset() end
    end)
    h:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(item.name, 1, 1, 1)
        GameTooltip:AddLine("Drag to move. Right-click: back where it starts.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return h
end

local Close

local function BuildBar()
    bar = CreateFrame("Frame", "GrudgekeeperMoveBar", UIParent, "BackdropTemplate")
    bar:SetSize(460, 70)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -40)
    bar:SetFrameStrata("DIALOG")
    bar:EnableMouse(true)
    bar:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    bar:SetBackdropColor(0.08, 0.05, 0.04, 0.92)
    bar:SetBackdropBorderColor(0.8, 0.6, 0.3, 1)
    local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("Arrange on screen")
    local hint = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    hint:SetText("Drag Grudgekeeper's things where you want them. Right-click one: back where it starts.")
    local done = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    done:SetSize(80, 22)
    done:SetPoint("TOPRIGHT", -12, -12)
    done:SetText("Done")
    done:SetScript("OnClick", function() Close() end)
    local reset = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    reset:SetSize(90, 22)
    reset:SetPoint("RIGHT", done, "LEFT", -6, 0)
    reset:SetText("Reset all")
    reset:SetScript("OnClick", function()
        for _, item in ipairs(ITEMS) do item.reset() end
    end)
    -- Escape closes it, as any of our popups (and Done does the same)
    bar:SetScript("OnHide", function() if open then Close() end end)
    if LIB.RegisterPopup then LIB.RegisterPopup(bar) else tinsert(UISpecialFrames, "GrudgekeeperMoveBar") end
    -- A frame is made shown, so this Hide runs the OnHide above: the mover must not count as open yet
    -- (GK.OpenMover builds the bar first).
    bar:Hide()
end

Close = function()
    if not open then return end
    open = false
    for i, item in ipairs(ITEMS) do
        if handles[i] then
            handles[i].target = nil
            handles[i]:Hide()
        end
        item.show(false)
    end
    if bar and bar:IsShown() then bar:Hide() end
    if GK.MoverClosed then GK.MoverClosed() end      -- the settings it was opened from come back (Options.lua)
end

function GK.OpenMover()
    if open then return end
    if InCombatLockdown() then
        print(GK.TAG .. ": not in a fight - move things once it is over.")
        return
    end
    -- Built before the mover counts as open. The other way round, the bar's first Hide ran its OnHide and
    -- closed the mover as it opened, the first time after every reload: the settings came straight back
    -- and Done did nothing ("lukker seg ikke ... og jeg kan ikke trykke done", the owner, 2026-11-13).
    if not bar then BuildBar() end
    open = true
    for i, item in ipairs(ITEMS) do
        local f = item.show(true)
        if f then
            handles[i] = handles[i] or Handle(item)
            local h = handles[i]
            h.target = f
            h:ClearAllPoints()
            h:SetAllPoints(f)
            h:Show()
        end
    end
    bar:Show()
end

function GK.ToggleMover()
    if open then Close() else GK.OpenMover() end
end

-- From the button on the game's settings page: the settings lie over the screen, and no addon may close
-- them (SettingsPanel:Close() raises ADDON_ACTION_FORBIDDEN - CLAUDE.md), so the mover waits and opens the
-- moment you close them yourself, with the screen free: "nå støter vi på det 'blizzard options tvinger å
-- være åpen eller lukke settings helt'" (the owner, 2026-11-12). A hook on their OnHide, after the game's
-- own, never a change to it.
local afterSettings, hooked = false, false

--- Open the mover now, or once the settings close when they are open. True when it waits for them.
function GK.OpenMoverAfterSettings()
    local panel = SettingsPanel
    if not (panel and panel:IsShown()) then
        GK.OpenMover()
        return false
    end
    afterSettings = true
    if not hooked then
        hooked = true
        panel:HookScript("OnHide", function()
            if not afterSettings then return end
            afterSettings = false
            -- after the key or click that closed them has done its work: Escape must not close us too
            C_Timer.After(0, GK.OpenMover)
        end)
    end
    return true
end

LIB.On("PLAYER_REGEN_DISABLED", function() if open then Close() end end)
