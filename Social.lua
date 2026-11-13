-- Grudgekeeper - the quiet way in: one line on a tooltip. It never opens anything or makes a sound; it is
-- only there when you are already looking.
--   Tooltip   mouse over an enemy player you have a history with, and one line says it:
--             "Grudge: killed you 24 - you got them 3 - kill order 20s". Nobody you've never met gets one.
-- (The round badge on the guild window's edge lived here until it became a tab there: GuildTab.lua.)
local ADDON, GK = ...
local LIB = LibStub("LibForever-1.0")
local Secret = GK.Secret

-- ---------------------------------------------------------------------------
-- The tooltip line
-- ---------------------------------------------------------------------------
--- The line for an enemy player, from what we know of them: our record, the guild's, an order. nil
--- when there is nothing to say - most enemies, most of the time. Exposed for the smoke test.
function GK.TooltipLine(key, guid)
    if not key then return nil end
    local parts = {}
    local f = GK.char.foes[key]
    if f and (f.d or 0) > 0 then parts[#parts + 1] = ("killed you %d"):format(f.d) end
    if f and (f.k or 0) > 0 then parts[#parts + 1] = ("you got them %d"):format(f.k) end
    if f and (f.a or 0) > 0 then parts[#parts + 1] = ("you helped %d"):format(f.a) end
    local w = GK.Store().wanted[key]
    if w then
        local total, others = 0, 0
        for who, n in pairs(w.victims) do
            total = total + n
            if who ~= LIB.Me() then others = others + n end
        end
        if others > 0 then parts[#parts + 1] = ("killed the guild %d"):format(total) end
    end
    local o = GK.OrderOn(key, guid)
    if o then
        local pot = GK.Pot(o)
        parts[#parts + 1] = pot > 0 and ("kill order %s"):format(GK.MoneyText(pot)) or "kill order"
    end
    if #parts == 0 then return nil end
    return "|cffc8281eGrudge|r  " .. table.concat(parts, "  -  ")
end

-- A tooltip is drawn again and again while the mouse rests on someone: the line is worked out once
-- and kept until the data changes (GK.version) or the mouse finds somebody else.
local memoKey, memoGuid, memoVersion, memoLine

local function OnUnitTip(tooltip)
    if tooltip ~= GameTooltip or not (GK.db and GK.db.tooltip) or not GK.InWorld() then return end
    if not tooltip.GetUnit then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    if not ok or type(unit) ~= "string" or Secret(unit) then return end
    local key, guid = GK.UnitIdentity(unit)
    if not key then return end
    if key ~= memoKey or guid ~= memoGuid or GK.version ~= memoVersion then
        memoKey, memoGuid, memoVersion = key, guid, GK.version
        memoLine = GK.TooltipLine(key, guid)
    end
    if not memoLine then return end
    tooltip:AddLine(memoLine, 0.85, 0.75, 0.6)
    tooltip:Show()
end

function GK.StartSocial()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTip)
    end
end
