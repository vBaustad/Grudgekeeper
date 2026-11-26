-- Grudgekeeper - paying a bounty. The game doesn't let an addon send mail or money by itself (SendMail
-- and a trade's money are restricted), so it does the two things it can:
--   at a mailbox, a card beside it lists what you owe, each with a button that fills the letter in - to
--   whom, what for, how much - and you press Send;
--   money you give someone you owe, by mail or in a trade, pays it, however the letter or the trade was
--   made: oldest first, and what falls short of a whole share counts toward it.
-- ("hvis du har en 'outstanding payment' burde det poppe opp noe når du åpner mailbox ... og så kan vi
-- registrere om det blir sendt penger til personen via mail eller trade", the owner, 2026-11-09.)
-- Whatever window the mailbox is in: TSM hides the game's own and sends with its own code, so the card stood for
-- MailFrame shown and a payment for Blizzard's Send, and with TSM neither came ("ta også hensyn til om noen bruker
-- TSM eller ellesmere UI osv", the owner, 2026-11-24). The mailbox is open from MAIL_SHOW to MAIL_CLOSED, and the
-- money is read where every window sends it: SetSendMailMoney, then SendMail. A skin (ElvUI, EllesmereUI) keeps the
-- game's window, and the card stands beside it.
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

-- 24 wider since the button says what it fills in (Fill in mail, 2026-11-24): the words beside it keep their room
local W, ROW_H, ROWS_TOP, MAX_ROWS = 344, 44, 34, 5
local SEND_WINDOW = 60      -- seconds from Send to the game's word that the letter went
local TRADE_WINDOW = 10     -- seconds after a trade closes that our money may still change for it

local card
local preview       -- the test panel's debt (Debug.lua): the card shown at once, a mailbox or not, until it closes
local sending       -- { to, copper, at }: a letter with money in it, sent, until the game says it went
local mailMoney = 0 -- the money the next letter carries, as the game was last told it (SetSendMailMoney)
local mailOpen      -- the mailbox is open, in the game's window or another addon's (MAIL_SHOW to MAIL_CLOSED)
local frameHooked   -- the game's window: Update when it shows or hides (no field of ours on Blizzard's frame)
local trade         -- { who, before, give, get, closedAt }: the trade open now, or the one just closed
local hooked

local function Ink(fs, colour, size) GK.Ink(fs, colour, GK.TEXT_FONT, size) end

-- The same player, written as a mail's To field or a trade has them and as we keep them: any case, with
-- or without a realm, a first name for a first name and surname (GK.SameName).
local function Same(a, b)
    return type(a) == "string" and type(b) == "string" and GK.SameName(GK.Lower(a), GK.Lower(b))
end

--- Money we gave a player, by mail or in a trade: it pays what we owe them, oldest first. What falls
--- short of the next whole share is kept toward it (GK.char.credit), so two trades of half pay it. Any
--- money to someone we owe counts: a gift and a bounty look the same, and owing them, it is the bounty.
function GK.GaveMoney(to, copper)
    copper = math.floor(tonumber(copper) or 0)
    if type(to) ~= "string" or to == "" or copper <= 0 then return end
    local debts = {}
    for _, e in ipairs(GK.Owed()) do
        if Same(e.to, to) then debts[#debts + 1] = e end
    end
    if #debts == 0 then return end
    local key = debts[1].to
    GK.char.credit = GK.char.credit or {}
    local have = (GK.char.credit[key] or 0) + copper
    local i = 1
    while debts[i] and have >= debts[i].share do
        local e = debts[i]
        have = have - e.share
        GK.PayShare(e.o, e.to)
        -- Money handled for you: the one kind of news that goes in chat.
        print(("%s: bounty paid - %s to %s for %s."):format(GK.TAG, GK.MoneyText(e.share), GK.Show(key),
            GK.Show(e.o.n)))
        i = i + 1
    end
    if debts[i] and have > 0 then
        GK.char.credit[key] = have
        print(("%s: %s to %s counted - %s still owed for %s."):format(GK.TAG, GK.MoneyText(have), GK.Show(key),
            GK.MoneyText(debts[i].share - have), GK.Show(debts[i].o.n)))
    else
        GK.char.credit[key] = nil
    end
    GK.Changed()
end

-- ---------------------------------------------------------------------------
-- The card at the mailbox
-- ---------------------------------------------------------------------------
-- entry = { o = order, share = copper, to = hunter }: what I owe one hunter on it (GK.Owed).
--- The letter Fill in mail writes: to whom, its subject, its line and the gold - what is still owed on the share.
--- One function for the letter and its tooltip, so what is shown is what is written. The test panel's debt is to
--- nobody real: no name and no gold, so a Send can't pay a stranger - but the one to a player you named yourself
--- (/grudge owe, Debug.lua), which is written in full, so a real payment can be tried alone. And a line in the
--- letter ("kan ikke gjøre så de kan trykke 'pay bounty' når de er ved mail og legge til gold og han som skal motta og
--- melding?", the owner, 2026-11-22).
local function Letter(entry)
    local o = entry.o
    local test = GK.testMode and not o.testNamed
    local credit = GK.char.credit and GK.char.credit[entry.to] or 0
    return { to = test and "" or LIB.WhisperName(entry.to), subject = ("Bounty: %s"):format(GK.Show(o.n)),
        body = ("Your part of the bounty on %s. Thanks for the kill!"):format(GK.Show(o.n)),
        copper = test and 0 or math.max(0, entry.share - credit) }
end

local function Fill(entry)
    if not (MailFrame and MailFrame:IsShown()) then return end   -- the game's own window: the boxes it fills are its
    local l = Letter(entry)
    if MailFrameTab2 then MailFrameTab2:Click() end
    if SendMailNameEditBox then SendMailNameEditBox:SetText(l.to) end
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(l.subject) end
    if SendMailBodyEditBox then SendMailBodyEditBox:SetText(l.body) end       -- Blizzard's own box, as Reply fills it
    -- money, not C.O.D.: Blizzard's own radio, as a click on it would set it
    if SendMailRadioButton_OnClick then SendMailRadioButton_OnClick(1) end
    if MoneyInputFrame_SetCopper and SendMailMoney then MoneyInputFrame_SetCopper(SendMailMoney, l.copper) end
end

local function Row(i)
    local f = card
    local b = CreateFrame("Frame", nil, f)
    b:SetSize(W - 32, ROW_H)
    b:SetPoint("TOPLEFT", 16, -(ROWS_TOP + (i - 1) * ROW_H))
    b.face = GK.MakePortrait(b, 30)
    b.face.tex:SetPoint("CENTER", b, "LEFT", 18, 0)
    local text = W - 32 - 40 - 152
    b.name = b:CreateFontString(nil, "ARTWORK")
    Ink(b.name, GK.INK, 12)
    b.name:SetPoint("TOPLEFT", 40, -8)
    b.name:SetWidth(text)
    b.name:SetJustifyH("LEFT")
    b.name:SetWordWrap(false)
    b.what = b:CreateFontString(nil, "ARTWORK")
    Ink(b.what, GK.FADED, 10)
    b.what:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
    b.what:SetWidth(text)
    b.what:SetJustifyH("LEFT")
    b.what:SetWordWrap(false)
    b.paid = GK.FrameButton(b, "Paid", 54, function() if b.entry then GK.PayShare(b.entry.o, b.entry.to) end end)
    b.paid:SetPoint("RIGHT", 0, 0)
    b.paid:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Paid another way")
        GameTooltip:AddLine("Mark it paid. Money you mail or trade them is marked by itself.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b.paid:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- what it fills in, in its name: "men det burde stå hva den skal 'fylle inn'?" (the owner, 2026-11-24)
    b.fill = GK.FrameButton(b, "Fill in mail", 94, function() if b.entry then Fill(b.entry) end end)
    b.fill:SetPoint("RIGHT", b.paid, "LEFT", -4, 0)
    b.fill:SetMotionScriptsWhileDisabled(true)
    -- the letter it will write, before it writes it ("jeg vil se hva den planlegger å skrive inn", the owner,
    -- 2026-11-24); where it waits for the game's own window, the same lines say what to send
    b.fill:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local live = self:IsEnabled()
        GameTooltip:AddLine(live and "Fill in mail" or "Fill in mail works in the game's own mail window")
        local l = b.entry and Letter(b.entry)
        if l then
            GameTooltip:AddDoubleLine("To", l.to ~= "" and l.to or "nobody: a test", 1, 0.82, 0, 1, 1, 1)
            GameTooltip:AddDoubleLine("Subject", l.subject, 1, 0.82, 0, 1, 1, 1)
            GameTooltip:AddDoubleLine("Gold", GK.Coins(l.copper), 1, 0.82, 0, 1, 1, 1)
            GameTooltip:AddLine(l.body, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine(live and "You press Send." or "Mail it from the window you have open: it is marked paid when "
            .. "it goes.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b.fill:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = b
    return b
end

local function Build()
    card = GK.MakeFrameSheet("GrudgekeeperOwed", W, 120, "Bounties you owe")
    card.rows = {}
    card.more = card:CreateFontString(nil, "ARTWORK")
    Ink(card.more, GK.FADED, 10)
    card.more:SetJustifyH("LEFT")
    card.note = card:CreateFontString(nil, "ARTWORK")
    Ink(card.note, GK.FADED, 10)
    card.note:SetWidth(W - 40)
    card.note:SetJustifyH("LEFT")
    card.note:SetSpacing(2)
    card.note:SetText("Mail or trade them the money and it is marked paid by itself.")
    -- closed by hand: not again until the next visit to a mailbox
    card:HookScript("OnHide", function()
        if mailOpen and not card.updating then card.dismissed = true end
        if not card.updating then preview = nil end
    end)
end

local function Update()
    local atMail = MailFrame and MailFrame:IsShown()      -- the game's own window: the card beside it, Fill in at work
    local open = mailOpen or atMail or preview
    local owed = open and GK.Owed() or {}
    if #owed == 0 then
        if card then
            card.updating = true
            card:Hide()
            card.updating = nil
        end
        return
    end
    if not card then Build() end
    if card.dismissed then return end
    local n = math.min(#owed, MAX_ROWS)
    local first = {}            -- money already given toward a hunter counts on their oldest share only
    local named                 -- a test's debt to a name you gave (/grudge owe): written in full
    for i = 1, n do
        local b = card.rows[i] or Row(i)
        local e = owed[i]
        b.entry = e
        if e.o.testNamed then named = true end
        local r = GK.Store().board[e.to] or {}
        b.face:Set({ key = e.to, c = r.c, rf = r.rf, sx = r.sx })
        b.name:SetText(GK.Show(e.to))
        local credit = not first[e.to] and GK.char.credit and GK.char.credit[e.to] or 0
        first[e.to] = true
        -- in coins ("gold bør vises med icons også", the owner, 2026-11-24), as big as the words
        local left = credit > 0 and (" (%s still)"):format(GK.Coins(e.share - credit, 11)) or ""
        b.what:SetText(("%s%s for %s"):format(GK.Coins(e.share, 11), left, GK.Show(e.o.n)))
        b.fill:SetEnabled(atMail and true or false)
        b:Show()
    end
    for i = n + 1, #card.rows do card.rows[i]:Hide() end
    local y = ROWS_TOP + n * ROW_H + 4
    card.more:SetShown(#owed > n)
    card.more:SetText(("and %d more"):format(#owed - n))
    card.more:SetPoint("TOPLEFT", 56, -y)
    if #owed > n then y = y + 16 end
    card.note:SetPoint("TOPLEFT", 20, -(y + 4))
    card:SetHeight(y + 40)
    -- the test's: "hva betyr 'fill in leaves the name and the gold empty'?" (the owner, 2026-11-24)
    card.note:SetText(not GK.testMode and "Mail or trade them the money and it is marked paid by itself."
        or named and "A test, but a real letter: Fill in mail writes the name you gave and the gold, and Send sends it."
        or "Only a test: Fill in mail adds no name and no gold, so nothing real is sent.")
    card:ClearAllPoints()
    if atMail then card:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 6, 0)
    else card:SetPoint("CENTER", UIParent, "CENTER", 260, 60) end
    card:Show()
end

--- The test panel's debt: the card shown now, beside the mail when it is open (Debug.lua). Off: gone.
function GK.PreviewOwed(on)
    preview = (on and GK.testMode) and true or nil
    if card then card.dismissed = nil end
    Update()
end

-- ---------------------------------------------------------------------------
-- Money given: by mail, and in a trade
-- ---------------------------------------------------------------------------
-- A letter sent, from any window: to whom, and the money the game was told to put in it (SetSendMailMoney, which
-- Blizzard's Send sets to 0 first and a C.O.D. leaves at 0). Read after the game's own functions, as hooks.
local function OnMoneySet(copper) mailMoney = tonumber(copper) or 0 end

local function OnSend(to)
    local copper = mailMoney
    mailMoney = 0
    sending = (type(to) == "string" and to ~= "" and copper > 0) and { to = to, copper = copper, at = GetTime() }
        or nil
end

-- What each side has put in the trade, while it is open: read at every change, kept after it closes.
local function TradeSeen()
    if not trade or trade.closedAt then return end
    local give = GetPlayerTradeMoney and GetPlayerTradeMoney()
    local get = GetTargetTradeMoney and GetTargetTradeMoney()
    if type(give) == "number" then trade.give = give end
    if type(get) == "number" then trade.get = get end
end

-- A trade that closed counts only when our money moved by exactly what it said - the money we put in,
-- less what they did. Cancelled, it never moves; so nothing is read from the game's chat text.
local function TradeDone()
    local t = trade
    if not (t and t.closedAt) then return end
    if GetTime() - t.closedAt > TRADE_WINDOW then
        trade = nil
        return
    end
    if t.give > 0 and GetMoney() == t.before - t.give + t.get then
        trade = nil
        GK.GaveMoney(t.who, t.give)
    end
end

function GK.StartMail()
    LIB.On("MAIL_SHOW", function()
        mailOpen = true
        -- Post-hooks only: the game's functions run as they always do, whichever window called them.
        if not hooked and SendMail and SetSendMailMoney then
            hooksecurefunc("SetSendMailMoney", OnMoneySet)
            hooksecurefunc("SendMail", OnSend)
            hooked = true
        end
        -- the game's window shown or hidden while the mailbox is open (TSM's switch): the card goes with it
        if MailFrame and not frameHooked then
            frameHooked = true
            MailFrame:HookScript("OnShow", function() Update() end)
            MailFrame:HookScript("OnHide", function() if card and card:IsShown() then Update() end end)
        end
        if card then card.dismissed = nil end
        Update()
    end)
    LIB.On("MAIL_CLOSED", function()
        mailOpen = nil
        if not card then return end
        card.updating = true
        card:Hide()
        card.updating = nil
    end)
    LIB.On("MAIL_SEND_SUCCESS", function()
        local s = sending
        sending = nil
        if s and GetTime() - s.at <= SEND_WINDOW then GK.GaveMoney(s.to, s.copper) end
    end)
    LIB.On("MAIL_FAILED", function() sending = nil end)
    LIB.On("SECURE_TRANSFER_CANCEL", function() sending = nil end)

    LIB.On("TRADE_SHOW", function()
        local who = GK.UnitKey("NPC")
        trade = (who and not GK.Secret(who) and GetMoney) and { who = who, before = GetMoney(), give = 0, get = 0 }
            or nil
        TradeSeen()
    end)
    for _, event in ipairs({ "TRADE_MONEY_CHANGED", "PLAYER_TRADE_MONEY", "TRADE_ACCEPT_UPDATE", "TRADE_UPDATE" }) do
        LIB.On(event, TradeSeen)
    end
    LIB.On("TRADE_CLOSED", function()
        local t = trade
        if not t or t.closedAt then return end          -- the game can say it twice
        t.closedAt = GetTime()
        TradeDone()
        C_Timer.After(TRADE_WINDOW + 0.1, function() if trade == t then trade = nil end end)
    end)
    LIB.On("PLAYER_MONEY", TradeDone)
    -- Once per burst of changes (GK.Changed gathers them); Update does nothing while the mail is shut.
    LIB.Listen("GRUDGEKEEPER_CHANGED", Update)
end
