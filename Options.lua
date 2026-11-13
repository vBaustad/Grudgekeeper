-- Grudgekeeper - its settings: the ledger's own paper, in a window of our own. Down the left a menu of
-- the chapters by name; beside it the chapter chosen, written in ink and signed. A wax seal is a
-- setting that is on, a dashed ring one that is off. "burde vi ikke bare lage et eget settings
-- panel ... gjøre det sjukt pent" (the owner, 2026-11-12, after the mover met the game's own settings,
-- which lie over the screen and which no addon may close); built to the mockup approved the same day.
-- Ours opens in a fight, closes itself while things are moved on screen, and needs no scrolling: a
-- chapter is a page. The game's Options -> AddOns -> Grudgekeeper keeps one button, which opens this.
-- Grudgekeeper is not one of the YippYapp addons (the user, 2026-11-03): no YippYapp page or footer.
-- Two layers: GK.SettingsChapters() is what there is to set, as data (what the tests read); the rest
-- draws it.
local ADDON, GK = ...
local LIB = LibStub("LibForever-1.0")

local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"

-- ---------------------------------------------------------------------------
-- What there is to set
-- ---------------------------------------------------------------------------
local KINDS = { { "off", "Off" }, { "toast", "Toast" }, { "splash", "Splash" } }
local WHEN = { { "always", "Always" }, { "noCombat", "Not in combat" },
    { "noCombatInInstance", "Not in combat in a dungeon or raid" },
    { "noInstance", "Never in a dungeon or raid" } }

--- A setting that is on or off, kept in GK.db[key]. child: it belongs under the row above. after(on):
--- what else has to happen when it changes.
local function Check(key, label, help, child, after)
    return { kind = "check", key = key, label = label, help = help, child = child,
        get = function() return GK.db[key] and true or false end,
        set = function(on)
            GK.db[key] = on and true or false
            GK.Changed()
            if after then after(on) end
        end }
end

--- A few words to choose between, all on the row (kind "choice"), or more of them in a menu ("pick").
local function Choice(kind, key, label, options, default)
    local row = { kind = kind, key = key, label = label, options = options,
        get = function() return GK.db[key] or default end,
        set = function(value)
            GK.db[key] = value
            GK.Changed()
        end }
    function row.menu(root, done)
        for _, o in ipairs(options) do
            local value = o[1]
            root:CreateRadio(o[2], function() return row.get() == value end, function()
                row.set(value)
                if done then done() end
            end)
        end
    end
    return row
end

--- A sound to pick. Picking one keeps it and plays it, so you hear what you chose, and picking it again
--- plays it again. spree: a spree announcement's, which offers the Grudgekeeper's voice lines too.
local function Sound(key, label, get, set, child, spree)
    local row = { kind = "sound", key = key, label = label, child = child, spree = spree, get = get, set = set }
    function row.menu(root, done)
        if root.SetScrollMode then root:SetScrollMode(420) end
        for _, c in ipairs(GK.SoundChoices(spree)) do
            local picked = c[1]
            root:CreateRadio(c[2], function() return get() == picked end, function()
                set(picked)
                GK.PlayChoice(picked)
                if done then done() end
            end)
        end
    end
    return row
end

local function Head(label) return { kind = "head", label = label } end

--- The chapters, in the order of the menu: { name, intro, rows }. Made anew at each
--- call, so a test reads it without a window.
function GK.SettingsChapters()
    local chapters = {
        { name = "Letters",
          intro = "Small sealed letters from the Grudgekeeper. The ledger keeps what they said.",
          rows = {
            Check("anyLetters", "Letters", "News as small sealed letters by the letter icon.", false,
                function() if GK.NoticeUpdate then GK.NoticeUpdate(false) end end),     -- the icon at once
            Check("letters", "Kill orders", "A new order lands as a letter.", true),
            Check("myLetters", "My own kills and deaths", "A new title, or a death that posted an order.", true),
            Check("keepLetters", "Wait until read", "Off: an unread letter fades after two minutes.", true,
                function(on) if not on and GK.FadeLetters then GK.FadeLetters() end end),   -- what waited fades
          } },
        { name = "Warnings",
          intro = "When someone the guild wants dead is close.",
          rows = {
            Check("alertNear", "A kill order target is near",
                "A warning by the letter icon, and a bubble to target them."),
            Sound("near", "Sound", function() return GK.db.nearSound end,
                function(key) GK.db.nearSound = key end, true),
            Check("plateMarks", "A seal over their nameplate",
                "The eye over those you track, too. Needs enemy nameplates."),
            Check("mapPins", "Last seen on the map", "Where a guildie saw a target, for 15 minutes."),
          } },
        { name = "Notes",
          intro = "Players the guild has written down.",
          rows = {
            Check("noteAlerts", "A Marked player is near", "The same warning as for a kill order target."),
            Check("watchNearby", "A Shame player is near", "One line in chat."),
            Check("watchGroup", "A Shame player joins my group", "A warning, with the sound below."),
            Sound("shame", "Sound", function() return GK.ShameSoundKey() end,
                function(key) GK.db.shameSound = key end, true),
            Check("kudosGroup", "A Kudos player joins my group", "One friendly line in chat."),
            Check("plateNotes", "Mark their nameplates", "A small mark for anyone you have notes on."),
          } },
        { name = "Guild",
          intro = "What your guild hears from you.",
          rows = {
            Check("share", "Share my score with the guild", "Your kills, deaths and points on the leaderboard.",
                false, function(on) if on then GK.SendBoard() end end),
            Check("autoOrders", "Orders on enemies who keep killing us",
                "Three of the guild in two hours: your death posts one."),
          } },
        { name = "Around the game",
          intro = "Where Grudgekeeper shows up outside its ledger.",
          rows = {
            Check("tooltip", "A line on enemy tooltips", "Only for enemies you have a history with."),
            Check("unitMenu", "In the right-click menu", "A poster, record, notes, a kill order, Track."),
            Check("inspectTab", "A tab on the Inspect window", "A guildie's record, right there."),
            { kind = "check", key = "guildButton", label = "A badge on the guild window",
              help = "Click it for the leaderboard.",
              get = function() return GK.db.guildButton ~= false end,
              set = function(on)
                  GK.db.guildButton = on and true or false
                  GK.RefreshGuildBadge()
              end },
            { kind = "check", key = "minimap", label = "Minimap button",
              help = "Left-click opens the ledger, right-click these pages.",
              get = function() return not (GK.db.minimap and GK.db.minimap.hide) end,
              set = function(on) GK.SetMinimapShown(on) end },
            Check("sound", "Sounds", "A page turning, the stamp, the horn."),
            Head("Screenshots"),
            Check("shotFulfil", "When I fulfil a kill order"),
            Check("shotEveryKill", "At every kill"),
          } },
        { name = "Look",
          intro = "How the ledger and its faces are drawn.",
          rows = {
            -- the skin dresses the ledger, the notes and these pages (GK.SetLook); the letters and the
            -- kill order's scroll are the Grudgekeeper's paper in both
            { kind = "choice", key = "look", label = "Skin",
              options = { { "parchment", "Parchment" }, { "classic", "Classic" } },
              get = function() return GK.db.look or "parchment" end,
              set = function(value) GK.SetLook(value) end },
            -- the faces go with neither skin ("classic portraits no matter what ... en egen settings
            -- uavhengig av classic/parchment settings", the owner, 2026-11-11)
            Check("oldPortraits", "Old race portraits", "Faces from the old character screen. Off: today's icons."),
          } },
    }
    -- Kill sprees (Announce.lua): third, after Warnings.
    if GK.SPREE_TIERS then
        local rows = {
            Choice("choice", "spreeMine", "My sprees", KINDS, "splash"),
            Choice("choice", "spreeGuild", "Guildies' sprees", KINDS, "toast"),
            Choice("choice", "spreeEnded", "A spree ended", KINDS, "toast"),
            Choice("choice", "spreeTormentor", "A tormentor put down", KINDS, "toast"),
            Choice("pick", "announceWhenMine", "Show mine", WHEN, "always"),
            Choice("pick", "announceWhenGuild", "Show guildies'", WHEN, "noCombat"),
            Head("The keeper's voice"),
        }
        -- one sound for each tier, rising, then the two that are no tier; the voice lines are offered here only
        local function SpreeSound(key, label)
            rows[#rows + 1] = Sound(key, label, function()
                return (GK.db.spreeSounds or {})[key] or GK.SPREE_DEFAULT_SOUNDS[key]
            end, function(picked)
                GK.db.spreeSounds = GK.db.spreeSounds or {}
                GK.db.spreeSounds[key] = picked
            end, false, true)
        end
        for _, t in ipairs(GK.SPREE_TIERS) do SpreeSound(t.key, t.name) end
        SpreeSound("ended", "Spree ended")
        SpreeSound("tormentor", "Tormentor")
        table.insert(chapters, 3, { name = "Kill sprees",
            intro = "Splash: big, in the middle of the screen. Toast: small, by the letter icon.", rows = rows })
    end
    return chapters
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------
local W, H = 792, 544                    -- the open ledger's size
local SIDE_X, SIDE_W, TOP = 30, 190, 44   -- the menu down the left: the chapters by name
local PAGE_X = SIDE_X + SIDE_W + 40       -- the chapter's settings, right of the line between them
local PAGE_W = W - PAGE_X - 30
local MENU_H = 28
local SPEAKER = "Interface\\Common\\VoiceChat-Speaker"

local win, chapters
local current = 1
local buttons, pages = {}, {}
local pageTitle, pageIntro, host
local reopen = false                     -- closed to move things on screen: open again when that is done
local RefreshPage

local function OpenMenu(owner, fill)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root) fill(root) end)
end

--- A string's width; where the client can't say yet, about what its letters take.
local function TextWidth(fs, text)
    local w = fs:GetStringWidth()
    if type(w) ~= "number" or w < 1 then w = #text * 7 end
    return math.ceil(w)
end

local function SoundName(key, spree)
    for _, c in ipairs(GK.SoundChoices(spree)) do
        if c[1] == key then return c[2] end
    end
    return "The chime"                   -- what plays when the one picked is gone (a sound pack uninstalled)
end

--- A setting on or off: the red seal, or the ring where one would be pressed. The whole row is the click.
local function CheckRow(parent, y, r)
    local indent = r.child and 28 or 0
    local height = r.help and 36 or 26
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(PAGE_W - indent, height)
    b:SetPoint("TOPLEFT", indent, -y)
    b.wash = b:CreateTexture(nil, "BACKGROUND")
    b.wash:SetAllPoints()
    b.wash:Hide()
    b.seal = b:CreateTexture(nil, "ARTWORK")
    b.seal:SetSize(22, 22)
    b.seal:SetPoint("TOPLEFT", 4, -2)
    b.label = b:CreateFontString(nil, "ARTWORK")
    GK.Ink(b.label, GK.INK, GK.TEXT_FONT, 13)
    b.label:SetPoint("TOPLEFT", 34, -4)
    b.label:SetText(r.label)
    if r.help then
        b.help = b:CreateFontString(nil, "ARTWORK")
        GK.Ink(b.help, GK.FADED, GK.TEXT_FONT, 11)
        b.help:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -3)
        b.help:SetWidth(PAGE_W - indent - 40)
        b.help:SetJustifyH("LEFT")
        b.help:SetWordWrap(false)
        b.help:SetText(r.help)
    end
    b:SetScript("OnEnter", function(self)
        GK.Wash(self.wash, 0.06)
        self.wash:Show()
    end)
    b:SetScript("OnLeave", function(self) self.wash:Hide() end)
    b:SetScript("OnClick", function()
        local on = not r.get()
        r.set(on)
        GK.Sound(on and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        RefreshPage()
    end)
    function b:Refresh()
        if r.get() then
            self.seal:SetTexture(MEDIA .. "seal_red")
            self.seal:SetVertexColor(1, 1, 1)
        else
            self.seal:SetTexture(MEDIA .. "toggle_off")
            self.seal:SetVertexColor(GK.FADED[1], GK.FADED[2], GK.FADED[3])
        end
    end
    return b, height
end

--- A few words on the row, the one chosen in blood and underlined.
local function ChoiceRow(parent, y, r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, 26)
    f:SetPoint("TOPLEFT", 0, -y)
    f.label = f:CreateFontString(nil, "ARTWORK")
    GK.Ink(f.label, GK.INK, GK.TEXT_FONT, 13)
    f.label:SetPoint("LEFT", 6, 0)
    f.label:SetText(r.label)
    f.options = {}
    local right = -6
    for i = #r.options, 1, -1 do                         -- laid out from the page's right edge
        local o = r.options[i]
        local b = CreateFrame("Button", nil, f)
        b.value = o[1]
        b.text = b:CreateFontString(nil, "ARTWORK")
        GK.Ink(b.text, GK.FADED, GK.TEXT_FONT, 12)
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(o[2])
        local w = TextWidth(b.text, o[2]) + 4
        b:SetSize(w, 20)
        b:SetPoint("RIGHT", f, "RIGHT", right, 0)
        right = right - w - 12
        b.line = b:CreateTexture(nil, "ARTWORK")
        GK.Paint(b.line, "blood")
        b.line:SetHeight(2)
        b.line:SetPoint("BOTTOMLEFT", 0, 0)
        b.line:SetPoint("BOTTOMRIGHT", 0, 0)
        b:SetScript("OnClick", function()
            r.set(o[1])
            GK.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
            RefreshPage()
        end)
        f.options[#f.options + 1] = b
    end
    function f:Refresh()
        local value = r.get()
        for _, b in ipairs(self.options) do
            local chosen = b.value == value
            GK.Ink(b.text, chosen and GK.BLOOD or GK.FADED, GK.TEXT_FONT, 12)
            b.line:SetShown(chosen)
        end
    end
    return f, 26
end

--- The value of a row that opens a menu: its words over a thin line, in blood under the mouse.
local function ValueButton(f, rightOffset)
    local b = CreateFrame("Button", nil, f)
    b:SetHeight(20)
    b:SetPoint("RIGHT", f, "RIGHT", rightOffset, 0)
    b.text = b:CreateFontString(nil, "ARTWORK")
    GK.Ink(b.text, GK.INK, GK.TEXT_FONT, 12)
    b.text:SetPoint("RIGHT", 0, 1)
    b.line = b:CreateTexture(nil, "ARTWORK")
    GK.Paint(b.line, "rule")
    b.line:SetHeight(1)
    b.line:SetPoint("BOTTOMLEFT", 0, 1)
    b.line:SetPoint("BOTTOMRIGHT", 0, 1)
    b:SetScript("OnEnter", function(self) GK.Ink(self.text, GK.BLOOD, GK.TEXT_FONT, 12) end)
    b:SetScript("OnLeave", function(self) GK.Ink(self.text, GK.INK, GK.TEXT_FONT, 12) end)
    function b:Set(text)
        self.text:SetText(text)
        self:SetWidth(TextWidth(self.text, text) + 2)
    end
    return b
end

--- More words than a row holds: the one chosen, and a menu of them all on a click.
local function PickRow(parent, y, r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, 26)
    f:SetPoint("TOPLEFT", 0, -y)
    f.label = f:CreateFontString(nil, "ARTWORK")
    GK.Ink(f.label, GK.INK, GK.TEXT_FONT, 13)
    f.label:SetPoint("LEFT", 6, 0)
    f.label:SetText(r.label)
    f.value = ValueButton(f, -6)
    f.value:SetScript("OnClick", function(self) OpenMenu(self, function(root) r.menu(root, RefreshPage) end) end)
    function f:Refresh()
        local value, text = r.get(), nil
        for _, o in ipairs(r.options) do
            if o[1] == value then text = o[2] end
        end
        self.value:Set(text or tostring(value))
    end
    return f, 26
end

--- A sound: its name opens the menu of them, and the speaker beside it plays the one picked.
local function SoundRow(parent, y, r)
    local indent = r.child and 28 or 0
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W - indent, 24)
    f:SetPoint("TOPLEFT", indent, -y)
    f.label = f:CreateFontString(nil, "ARTWORK")
    GK.Ink(f.label, GK.FADED, GK.TEXT_FONT, 12)
    f.label:SetPoint("LEFT", r.child and 34 or 6, 0)
    f.label:SetText(r.label)
    f.value = ValueButton(f, -28)
    f.value:SetScript("OnClick", function(self) OpenMenu(self, function(root) r.menu(root, RefreshPage) end) end)
    f.play = CreateFrame("Button", nil, f)
    f.play:SetSize(18, 18)
    f.play:SetPoint("RIGHT", -4, 0)
    f.play.tex = f.play:CreateTexture(nil, "ARTWORK")
    f.play.tex:SetAllPoints()
    f.play.tex:SetTexture(SPEAKER)
    f.play:SetScript("OnClick", function() GK.PlayChoice(r.get()) end)
    f.play:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Play it", 1, 1, 1)
        GameTooltip:Show()
    end)
    f.play:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function f:Refresh()
        self.value:Set(SoundName(r.get(), r.spree))
        self.play.tex:SetVertexColor(GK.INK[1], GK.INK[2], GK.INK[3])
    end
    return f, 24
end

--- A small heading inside a chapter, over a rule.
local function HeadRow(parent, y, r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, 28)
    f:SetPoint("TOPLEFT", 0, -y)
    f.label = f:CreateFontString(nil, "ARTWORK")
    GK.Ink(f.label, GK.FADED, GK.TEXT_FONT, 10)
    f.label:SetPoint("BOTTOMLEFT", 6, 7)
    f.label:SetText(r.label:upper())
    f.rule = f:CreateTexture(nil, "ARTWORK")
    GK.Paint(f.rule, "rule")
    f.rule:SetHeight(1)
    f.rule:SetPoint("BOTTOMLEFT", 6, 3)
    f.rule:SetPoint("BOTTOMRIGHT", -6, 3)
    function f:Refresh() end
    return f, 28
end

local ROW = { check = CheckRow, choice = ChoiceRow, pick = PickRow, sound = SoundRow, head = HeadRow }

--- A chapter's page, made the first time it is turned to: its rows under one another.
local function BuildPage(i)
    local page = CreateFrame("Frame", nil, host)
    page:SetAllPoints(host)
    page.rows = {}
    local y = 0
    for _, r in ipairs(chapters[i].rows) do
        local row, height = ROW[r.kind](page, y, r)
        row.setting = r
        page.rows[#page.rows + 1] = row
        y = y + height
    end
    pages[i] = page
    return page
end

RefreshPage = function()
    local page = pages[current]
    if not page then return end
    for _, row in ipairs(page.rows) do row:Refresh() end
end

--- Turn to a chapter: its name in the menu lit, its settings beside it.
local function Select(i)
    current = chapters[i] and i or 1
    for n, b in ipairs(buttons) do
        local chosen = n == current
        if chosen then GK.Wash(b.wash, 0.1) end
        b.wash:SetShown(chosen)
        b.edge:SetShown(chosen)
        GK.Ink(b.name, chosen and GK.BLOOD or GK.INK, GK.TEXT_FONT, 14)
    end
    local ch = chapters[current]
    pageTitle:SetText(ch.name)
    pageIntro:SetText(ch.intro)
    for n, page in pairs(pages) do page:SetShown(n == current) end
    if not pages[current] then BuildPage(current) end
    pages[current]:Show()
    RefreshPage()
end

--- Back to the ledger, which these pages took the place of.
local function BackToLedger()
    win:Hide()
    GK.OpenWindow()
end

--- Arrange on screen (Move.lua): these pages close, and open again at Done. The button was "Move things
--- on screen"; "Edit mode" was the owner's first word for it, and is the game's own for its HUD ("kall
--- knappen 'edit mode' eller noe annet (ikke forvirr med vanlig edit mode)", 2026-11-13) - so the word
--- Headstart's button and our own /grudge arrange already use.
local function MoveThings()
    if InCombatLockdown() then
        GK.OpenMover()                               -- it says why not
        return
    end
    reopen = true
    win:Hide()
    GK.OpenMoverAfterSettings()                      -- at once, or when the game's own settings close under us
end

--- The mover closed (Move.lua): back to the pages it was opened from, but not into a fight that ended it.
function GK.MoverClosed()
    if not reopen then return end
    reopen = false
    if not InCombatLockdown() then GK.OpenOptions() end
end

local function Build()
    chapters = GK.SettingsChapters()
    win = GK.MakeFrameSheet("GrudgekeeperSettings", W, H, "Grudgekeeper", true)

    -- The menu down the left: the chapters by name and nothing else, as a settings window has them. The
    -- first build gave each a seal and a line of its own, half the window wide, and it read as a list of
    -- things rather than as tabs: "det er litt vanskelig faktisk å skjønne at det er settings tabs. så
    -- fjern ikoner og gjør det mer som ordentlig settings" (the owner, 2026-11-13).
    local title = win:CreateFontString(nil, "ARTWORK")
    GK.Ink(title, GK.BLOOD, GK.TITLE_FONT, 26)
    title:SetPoint("TOPLEFT", SIDE_X, -TOP)
    title:SetText("Settings")
    local version = win:CreateFontString(nil, "ARTWORK")
    GK.Ink(version, GK.FADED, GK.TEXT_FONT, 11)
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 3)
    version:SetText("v" .. GK.addonVersion)
    local rule = win:CreateTexture(nil, "ARTWORK")
    GK.Paint(rule, "rule")
    rule:SetSize(SIDE_W, 1)
    rule:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    for i, ch in ipairs(chapters) do
        local b = CreateFrame("Button", nil, win)
        b:SetSize(SIDE_W, MENU_H - 2)
        b:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -8 - (i - 1) * MENU_H)
        b.wash = b:CreateTexture(nil, "BACKGROUND")
        b.wash:SetAllPoints()
        b.wash:Hide()
        b.edge = b:CreateTexture(nil, "BORDER")
        GK.Paint(b.edge, "blood")
        b.edge:SetSize(3, MENU_H - 2)
        b.edge:SetPoint("LEFT")
        b.edge:Hide()
        b.name = b:CreateFontString(nil, "ARTWORK")
        GK.Ink(b.name, GK.INK, GK.TEXT_FONT, 14)
        b.name:SetPoint("LEFT", 12, 0)
        b.name:SetText(ch.name)
        b:SetScript("OnClick", function()
            GK.Sound("IG_ABILITY_PAGE_TURN")
            Select(i)
        end)
        b:SetScript("OnEnter", function(self)
            if i ~= current then
                GK.Wash(self.wash, 0.06)
                self.wash:Show()
            end
        end)
        b:SetScript("OnLeave", function(self) self.wash:SetShown(i == current) end)
        buttons[i] = b
    end
    -- the line between the menu and the chapter's settings
    local divide = win:CreateTexture(nil, "ARTWORK")
    GK.Paint(divide, "rule")
    divide:SetSize(1, H - TOP - 66)
    divide:SetPoint("TOPLEFT", SIDE_X + SIDE_W + 20, -TOP)

    -- The foot of the menu, two of the game's buttons: back to the ledger these pages took the place of
    -- ("men det er ikke noe 'back'?", the owner, 2026-11-13), and Arrange on screen over it.
    local back = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    back:SetSize(SIDE_W, 22)
    back:SetPoint("BOTTOMLEFT", SIDE_X, 26)
    back:SetText("Back to the ledger")
    back:SetScript("OnClick", BackToLedger)
    local move = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
    move:SetSize(SIDE_W, 22)
    move:SetPoint("BOTTOMLEFT", back, "TOPLEFT", 0, 6)
    move:SetText("Arrange on screen")
    move:SetScript("OnClick", MoveThings)
    move:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Closes these pages and shows the letter icon, the spree splash and its toasts: drag "
            .. "each where you want it. Done opens the pages again.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    move:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.back, win.move = back, move

    -- the chapter chosen, right of the line: its name, what it is about, its settings, and his name under them
    pageTitle = win:CreateFontString(nil, "ARTWORK")
    GK.Ink(pageTitle, GK.BLOOD, GK.TITLE_FONT, 22)
    pageTitle:SetPoint("TOPLEFT", PAGE_X, -TOP - 4)
    pageIntro = win:CreateFontString(nil, "ARTWORK")
    GK.Ink(pageIntro, GK.FADED, GK.TEXT_FONT, 12)
    pageIntro:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -4)
    pageIntro:SetWidth(PAGE_W)
    pageIntro:SetJustifyH("LEFT")
    pageIntro:SetWordWrap(false)
    local rule2 = win:CreateTexture(nil, "ARTWORK")
    GK.Paint(rule2, "rule")
    rule2:SetSize(PAGE_W, 1)
    rule2:SetPoint("TOPLEFT", pageIntro, "BOTTOMLEFT", 0, -8)
    host = CreateFrame("Frame", nil, win)
    host:SetSize(PAGE_W, 380)
    host:SetPoint("TOPLEFT", rule2, "BOTTOMLEFT", 0, -6)
    local sign = win:CreateFontString(nil, "ARTWORK")
    GK.Ink(sign, GK.INK, GK.TITLE_FONT, 14)
    sign:SetPoint("BOTTOMRIGHT", win, "BOTTOMLEFT", PAGE_X + PAGE_W, 28)
    sign:SetText("- the Grudgekeeper")

    win.chapters, win.pages = buttons, pages
    -- another skin, or a setting changed from somewhere else (the minimap button's own menu): drawn again
    GK.OnLook(function() if win:IsShown() then Select(current) end end)
    LIB.Listen("GRUDGEKEEPER_CHANGED", function() if win:IsShown() then RefreshPage() end end)
end

--- Open the settings, in a fight too: plain frames, nothing of the game's own. chapter: its name, to turn
--- to it. over: a window whose place they take (the ledger, which its Settings button then hides).
function GK.OpenOptions(chapter, over)
    if not win then Build() end
    local turnTo = current
    for i, ch in ipairs(chapters) do
        if ch.name == chapter then turnTo = i end
    end
    if over and over.GetLeft and over:GetLeft() and over:GetTop() then
        win:ClearAllPoints()
        win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", over:GetLeft(), over:GetTop())
    end
    Select(turnTo)
    win:Show()
    win:Raise()
    return true
end

-- ---------------------------------------------------------------------------
-- The game's own Options -> AddOns -> Grudgekeeper: one button, which opens ours
-- ---------------------------------------------------------------------------
local category

function GK.RegisterOptions()
    if category then return end
    local panel = CreateFrame("Frame")
    panel:SetSize(572, 200)
    local built = false
    panel:SetScript("OnShow", function(self)
        if built then return end
        built = true
        local name = self:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        name:SetPoint("TOPLEFT", 18, -16)
        name:SetText("Grudgekeeper")
        local version = self:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        version:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 8, 1)
        version:SetText("v" .. GK.addonVersion)
        local note = self:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        note:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -8)
        note:SetWidth(520)
        note:SetJustifyH("LEFT")
        note:SetText("Grudgekeeper keeps its settings in pages of its own. The ledger's Settings button, a "
            .. "right-click on the minimap button and /grudge options open them too.")
        local open = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        open:SetSize(220, 24)
        open:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -14)
        open:SetText("Open Grudgekeeper's settings")
        open:SetScript("OnClick", function() GK.OpenOptions() end)
        self.open = open
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "Grudgekeeper")
        Settings.RegisterAddOnCategory(category)
    end
end
