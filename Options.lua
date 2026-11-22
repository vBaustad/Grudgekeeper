-- Grudgekeeper - its settings: a page of the ledger, two pages wide (Window.lua), with the ledger's tabs
-- under it to go back by. Down the left a menu of the chapters by name; beside it the chapter chosen,
-- written in ink and signed. A wax seal is a setting that is on, a dashed ring one that is off. "burde vi
-- ikke bare lage et eget settings panel ... gjøre det sjukt pent" (the owner, 2026-11-12, after the mover
-- met the game's own settings, which lie over the screen and which no addon may close); built to the
-- mockup approved the same day, as a window of its own that took the ledger's place - and its tabs, until
-- 2026-11-18 ("la tabs være der så man kan trykke på de for å komme tilbake isteden").
-- Ours opens in a fight, closes itself while things are moved on screen, and needs no scrolling: a
-- chapter is a page. The game's Options -> AddOns -> Grudgekeeper keeps one button, which opens this.
-- Grudgekeeper is not one of the YippYapp addons (the user, 2026-11-03): no YippYapp page or footer.
-- Two layers: GK.SettingsChapters() is what there is to set, as data (what the tests read); the rest
-- draws it.
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

-- ---------------------------------------------------------------------------
-- What there is to set
-- ---------------------------------------------------------------------------
local WHEN = { { "always", "Always" }, { "noCombat", "Not in combat" },
    { "noCombatInInstance", "Not in combat in a dungeon or raid" },
    { "noInstance", "Never in a dungeon or raid" } }
-- the same, short, where a when-rule stands on a line with others (the Notifications page)
local WHEN_SHORT = { always = "Always", noCombat = "Not in combat", noCombatInInstance = "Not in combat in dungeons",
    noInstance = "Not in dungeons" }
-- How long an announcement shows: the seconds a toast does, and a splash half of them (Announce.lua).
local TIMES = { { 3, "3 seconds - a splash 1.5" }, { 5, "5 seconds - a splash 2.5" }, { 7, "7 seconds - a splash 3.5" },
    { 10, "10 seconds - a splash 5" }, { 15, "15 seconds - a splash 7.5" } }

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

local function Head(label, compact) return { kind = "head", label = label, compact = compact } end

-- ---------------------------------------------------------------------------
-- The notifications: one page for all that shows up (2026-11-20)
-- ---------------------------------------------------------------------------
-- Yours and a guildie's side by side, with the presets over them: "gjør settings bedre, så alt av
-- notifications osv kan stilles på ett sted og lyder og toasts/splashes osv.. det er sikkert flere som ikke
-- ønsker masse popups, spesielt streamers ... tenk en 1000 people guild" (the owner). Drawn first
-- (art/mockups/settings) and built to it. It took in the pages Kill sprees, Warnings and Notes; their sounds
-- went to Sounds, the nameplate marks and the map's pins to Around the game.
local STYLES = { { "splash", "Splash" }, { "toast", "Toast" }, { "off", "Off" } }
local STYLE_NAME = { splash = "Splash", toast = "Toast", off = "Off" }
-- A guildie's sprees: how, and from how many kills in a row ("round": only 25, 50 and 100). { style, from, the
-- menu's words, the page's }. The counts are the tiers' own (GK.SPREE_TIERS).
local GUILD_SPREES = {
    { "off", nil, "Off", "Off" },
    { "toast", 3, "Toast, every one (3+)", "Toast, 3+" },
    { "toast", 7, "Toast, Butcher and up (7+)", "Toast, 7+" },
    { "toast", 10, "Toast, Reaper and up (10+)", "Toast, 10+" },
    { "toast", 15, "Toast, Grudgebound and up (15+)", "Toast, 15+" },
    { "toast", "round", "Toast, only 25, 50 and 100", "Toast, 25/50/100" },
    { "splash", 10, "Splash, Reaper and up (10+)", "Splash, 10+" },
    { "splash", "round", "Splash, only 25, 50 and 100", "Splash, 25/50/100" },
}
-- A guildie's new titles: how, and from which title up, by the points it stands at (GK.TITLES).
local GUILD_TITLES = {
    { "off", nil, "Off", "Off" },
    { "toast", 0, "Toast, every title", "Toast, every title" },
    { "toast", 100, "Toast, Slayer and up", "Toast, Slayer+" },
    { "toast", 450, "Toast, Avenger and up", "Toast, Avenger+" },
    { "toast", 900, "Toast, Nemesis and up", "Toast, Nemesis+" },
    { "splash", 450, "Splash, Avenger and up", "Splash, Avenger+" },
}

-- The presets over the page: each sets the rows it names, and a page that matches none of them is Custom. Big
-- moments is what a new install has (Core.lua's defaults). Where a guildie is, and the warnings (a chapter of
-- their own since 2026-11-20), belong to no preset.
local PRESETS = {
    { key = "all", name = "All of it", hint = "All of yours, and every spree and title from guildies.",
      set = { spreeMine = "splash", rankMine = "splash", orderMine = "splash", spreeEnded = "toast",
          spreeTormentor = "toast", spreeGuild = "toast", spreeGuildFrom = 3, rankGuild = "toast", rankGuildFrom = 0,
          orderDone = "toast", spreeEndedGuild = "toast", spreeTormentorGuild = "toast", guildSounds = true,
          revengeMine = "splash", revengeGuild = "toast", grudgeMine = "toast" } },
    { key = "big", name = "Big moments",
      hint = "All of your own, and only the biggest sprees and titles from guildies.",
      set = { spreeMine = "splash", rankMine = "splash", orderMine = "splash", spreeEnded = "toast",
          spreeTormentor = "toast", spreeGuild = "toast", spreeGuildFrom = 10, rankGuild = "toast",
          rankGuildFrom = 450, orderDone = "toast", spreeEndedGuild = "off", spreeTormentorGuild = "toast",
          guildSounds = true, revengeMine = "splash", revengeGuild = "off", grudgeMine = "toast" } },
    { key = "quiet", name = "Quiet", hint = "Your own as small toasts, and nothing from guildies. Good for streaming.",
      set = { spreeMine = "toast", rankMine = "toast", orderMine = "toast", spreeEnded = "toast",
          spreeTormentor = "toast", spreeGuild = "off", rankGuild = "off", orderDone = "off",
          spreeEndedGuild = "off", spreeTormentorGuild = "off", guildSounds = false,
          revengeMine = "toast", revengeGuild = "off", grudgeMine = "toast" } },
}
GK.NOTIFY_PRESETS = PRESETS
local CUSTOM_HINT = "Your own mix. Pick one of the others to start over from it."

--- The preset the page matches now ("all", "big" or "quiet"), or "custom".
function GK.NotifyPreset()
    for _, p in ipairs(PRESETS) do
        local same = true
        for k, v in pairs(p.set) do
            if GK.db[k] ~= v then
                same = false
                break
            end
        end
        if same then return p.key end
    end
    return "custom"
end

--- What a preset's tab says under it: its hint, or Custom's.
function GK.NotifyPresetHint(key)
    for _, p in ipairs(PRESETS) do
        if p.key == key then return p.hint end
    end
    return CUSTOM_HINT
end

--- Set every row a preset names. Returns whether there is such a preset.
function GK.ApplyNotifyPreset(key)
    for _, p in ipairs(PRESETS) do
        if p.key == key then
            for k, v in pairs(p.set) do GK.db[k] = v end
            GK.Changed()
            return true
        end
    end
    return false
end

-- A cell is one value on a row that holds more than one (a pair's two, an inline row's few): key, the words it
-- shows (text), and its menu's choices, options = { { words, chosen(), pick() } }.

--- Splash, toast or off, kept in GK.db[key].
local function StyleCell(key)
    local cell = { key = key, options = {} }
    for _, s in ipairs(STYLES) do
        local value = s[1]
        cell.options[#cell.options + 1] = { s[2], function() return GK.db[key] == value end, function()
            GK.db[key] = value
            GK.Changed()
        end }
    end
    function cell.text() return STYLE_NAME[GK.db[key]] or "Off" end
    return cell
end

--- How and from where, in one menu (GUILD_SPREES, GUILD_TITLES): a choice sets both keys; Off only the way.
local function ComboCell(styleKey, fromKey, list)
    local cell = { key = styleKey, fromKey = fromKey, options = {} }
    local function Chosen(c)
        if c[1] == "off" then return GK.db[styleKey] == "off" end
        return GK.db[styleKey] == c[1] and GK.db[fromKey] == c[2]
    end
    for _, c in ipairs(list) do
        cell.options[#cell.options + 1] = { c[3], function() return Chosen(c) end, function()
            GK.db[styleKey] = c[1]
            if c[2] ~= nil then GK.db[fromKey] = c[2] end
            GK.Changed()
        end }
    end
    function cell.text()
        for _, c in ipairs(list) do
            if Chosen(c) then return c[4] end
        end
        return STYLE_NAME[GK.db[styleKey]] or "Off"      -- a mix the menu has no line for: its way alone
    end
    return cell
end

--- One of a few values, short on the page (short(value)) and in full in its menu.
local function PickCell(key, options, default, short)
    local cell = { key = key, options = {} }
    for _, o in ipairs(options) do
        local value = o[1]
        cell.options[#cell.options + 1] = { o[2], function() return (GK.db[key] or default) == value end, function()
            GK.db[key] = value
            GK.Changed()
        end }
    end
    function cell.text() return short(GK.db[key] or default) end
    return cell
end

local function Pair(label, mine, guild) return { kind = "pair", label = label, mine = mine, guild = guild } end

-- A warning's way (GK.WarnStyle, Core.lua): on screen by the letter icon, a line in chat, or not at all.
local WARN_WAYS = { { "screen", "On screen" }, { "chat", "Chat line" }, { "off", "Off" } }
local function Warning(key, label)
    local row = { kind = "pick", key = key, label = label, options = WARN_WAYS, compact = true,
        get = function() return GK.WarnStyle(key) end,
        set = function(value)
            GK.db[key] = value
            GK.Changed()
        end }
    function row.menu(root, done)
        for _, o in ipairs(WARN_WAYS) do
            local value = o[1]
            root:CreateRadio(o[2], function() return row.get() == value end, function()
                row.set(value)
                if done then done() end
            end)
        end
    end
    return row
end

-- How tall each kind of row is on the page, which holds 380 under its heading (the window, below): drawn
-- at these, and summed by tests/run.lua so that no chapter runs into the signature.
local ROW_HEIGHT = { choice = 26, sound = 24, presets = 36, columns = 16, pair = 22, inline = 24 }
function GK.SettingsRowHeight(r)
    if r.kind == "check" then return r.help and 36 or (r.compact and 24 or 26) end
    if r.kind == "pick" then return r.compact and 22 or 26 end
    if r.kind == "head" then return r.compact and 24 or 28 end
    return ROW_HEIGHT[r.kind] or 26
end

--- The chapters, in the order of the menu: { name, intro, rows }. Made anew at each
--- call, so a test reads it without a window.
function GK.SettingsChapters()
    local zoneOnly = Check("guildZoneOnly", "Guildies' only when they are in my zone")
    zoneOnly.compact = true
    local chapters = {
        { name = "Notifications", intro = "Splashes and toasts: what shows up on your screen.",
          rows = {
            { kind = "presets" },
            { kind = "columns" },
            Pair("Kill sprees", StyleCell("spreeMine"), ComboCell("spreeGuild", "spreeGuildFrom", GUILD_SPREES)),
            Pair("A new title", StyleCell("rankMine"), ComboCell("rankGuild", "rankGuildFrom", GUILD_TITLES)),
            Pair("A kill order fulfilled", StyleCell("orderMine"), StyleCell("orderDone")),
            Pair("Revenge", StyleCell("revengeMine"), StyleCell("revengeGuild")),
            -- yours alone: a guildie's score with an enemy is theirs (Announce.lua, GK_GRUDGE)
            Pair("A grudge evened up", StyleCell("grudgeMine")),
            Pair("A spree ended", StyleCell("spreeEnded"), StyleCell("spreeEndedGuild")),
            Pair("A tormentor put down", StyleCell("spreeTormentor"), StyleCell("spreeTormentorGuild")),
            zoneOnly,
            { kind = "inline", parts = { "Show mine",
                PickCell("announceWhenMine", WHEN, "always", function(v) return WHEN_SHORT[v] or v end),
                "guildies'", PickCell("announceWhenGuild", WHEN, "noCombat", function(v) return WHEN_SHORT[v] or v end) } },
            -- how long one shows ("legg settings så folk kan sette lengde selv", the owner, 2026-11-14)
            { kind = "inline", parts = { "Show for",
                PickCell("announceTime", TIMES, 7, function(v) return v .. " seconds" end) } },
          } },
        -- The warnings had the foot of Notifications until Revenge and a sixth warning made it taller than the
        -- page (2026-11-20).
        { name = "Warnings", intro = "Who is near, or joins your group.",
          rows = {
            Warning("alertNear", "A kill order target is near"),
            Warning("watchNearby", "A Shame player is near"),
            Warning("watchGroup", "A Shame player joins my group"),
            Warning("kudosGroup", "A Kudos player joins my group"),
          } },
        { name = "Letters",
          intro = "Letters from the Grudgekeeper, by the letter icon.",
          rows = {
            Check("anyLetters", "Letters", "News as small sealed letters by the letter icon.", false,
                function() if GK.NoticeUpdate then GK.NoticeUpdate(false) end end),     -- the icon at once
            Check("letters", "Kill orders", "A new order lands as a letter.", true),
            Check("myLetters", "My own kills and deaths", "A new title, or a death that posted an order.", true),
            Check("keepLetters", "Wait until read", "Off: an unread letter leaves the icon after two minutes.", true,
                function(on) if not on and GK.FadeLetters then GK.FadeLetters() end end),   -- what waited fades
          } },
        { name = "Guild",
          intro = "What you share with your guild.",
          rows = {
            Check("share", "Share my score with the guild", "Your kills, deaths and points on the leaderboard.",
                false, function(on) if on then GK.SendBoard() end end),
            Check("autoOrders", "Orders on enemies who keep killing us",
                "Three of the guild in two hours: your death posts one."),
            -- a player on your side outside the guild who opens your profile or inspects you (2026-11-20)
            Check("shareOutside", "Share my profile outside the guild",
                "Players on your side who ask see your title, points, kills and deaths."),
          } },
        { name = "Around the game",
          intro = "Tooltips, the right-click menu, nameplates and the map.",
          rows = {
            Check("tooltip", "A line on enemy tooltips", "Only for enemies you have a history with."),
            Check("unitMenu", "In the right-click menu", "An enemy: profile, kill order, Track. A friend: Shame, Kudos."),
            Check("plateMarks", "A seal over a kill order target's nameplate",
                "The eye over those you track, too. Needs enemy nameplates."),
            Check("plateNotes", "Mark noted players' nameplates", "A medal for each tag over Kudos players, a small mark for Shame."),
            Check("mapPins", "Last seen on the map", "Where a guildie saw a target, for 15 minutes."),
            Check("inspectTab", "A tab on the Inspect window", "A guildie's record, right there."),
            { kind = "check", key = "guildButton", label = "A tab on the guild window",
              help = "Your week, the kill orders, the leaderboard and guild chat on one page.",
              get = function() return GK.db.guildButton ~= false end,
              set = function(on)
                  GK.db.guildButton = on and true or false
                  GK.RefreshGuildTab()
              end },
            { kind = "check", key = "minimap", label = "Minimap button",
              help = "Left-click opens the ledger, right-click these pages.",
              get = function() return not (GK.db.minimap and GK.db.minimap.hide) end,
              set = function(on) GK.SetMinimapShown(on) end },
            Head("Screenshots"),
            Check("shotFulfil", "When I fulfil a kill order"),
            Check("shotEveryKill", "At every kill"),
          } },
        { name = "Look",
          intro = "Skin, portraits and the Reaper splash.",
          rows = {
            -- the skin dresses the ledger, the notes and these pages (GK.SetLook); the letters and the
            -- kill order's poster are the Grudgekeeper's paper in both
            { kind = "choice", key = "look", label = "Skin",
              options = { { "parchment", "Parchment" }, { "classic", "Classic" } },
              get = function() return GK.db.look or "parchment" end,
              set = function(value) GK.SetLook(value) end },
            -- the faces go with neither skin ("classic portraits no matter what ... en egen settings
            -- uavhengig av classic/parchment settings", the owner, 2026-11-11)
            Check("oldPortraits", "Old race portraits", "Faces from the old character screen. Off: today's icons."),
            -- Reaper's splash had two we both liked (the Streak Lab, 2026-11-17); the scythe out of the box
            -- since 2026-11-20 ("mye bedre enn reaper smoke", the owner)
            { kind = "choice", key = "reaperEffect", label = "Reaper's splash",
              options = { { "scythe", "Scythe" }, { "smoke", "Smoke" } },
              get = function() return GK.db.reaperEffect or "scythe" end,
              set = function(value) GK.db.reaperEffect = value end },
          } },
    }
    -- Sounds: every sound in one place, second (2026-11-20). One switch for them all, one for a guildie's, a
    -- sound for each spree tier rising, then the three that are no tier (a spree ended, a tormentor, revenge),
    -- then the warnings'. The voice lines are offered for the splashes and toasts only.
    local rows = {
        Check("sound", "Sounds", "Every sound Grudgekeeper plays."),
        Check("guildSounds", "Sounds from guildies", "Their sprees, titles and kill orders play their sound when they show."),
    }
    if GK.SPREE_TIERS then
        rows[#rows + 1] = Head("Splashes and toasts")
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
        SpreeSound("revenge", "Revenge")
    end
    rows[#rows + 1] = Head("Warnings")
    rows[#rows + 1] = Sound("near", "A kill order target is near", function() return GK.db.nearSound end,
        function(key) GK.db.nearSound = key end)
    rows[#rows + 1] = Sound("shame", "A Shame player joins my group", function() return GK.ShameSoundKey() end,
        function(key) GK.db.shameSound = key end)
    table.insert(chapters, 2, { name = "Sounds", intro = "Turn sounds on or off and choose them.", rows = rows })
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

-- A setting on or off is a box to tick (the owner's pick A, 2026-11-20, art/mockups/grudges): on the parchment
-- a box drawn in ink with an ink tick, in the Classic skin the game's own checkbox. It was a red wax seal for
-- on and a faint ring for off: "settings med stemplene gjør at det er vanskelig å skjønne at det faktisk er
-- checkboxes" (the owner). The tick is the game's, its gold taken out and inked on the parchment.
local GAME_BOX, GAME_TICK = "Interface\\Buttons\\UI-CheckBox-Up", "Interface\\Buttons\\UI-CheckBox-Check"
local INK_BOX = 16                       -- the drawn box, across; its lines 2 thick
local GAME_BOX_SIZE = 26                 -- the game's art has room round its box: about 16 of it is the box

--- A setting on or off: the box, ticked or not. The whole row is the click.
local function CheckRow(parent, y, r)
    local indent = r.child and 28 or 0
    local height = GK.SettingsRowHeight(r)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(PAGE_W - indent, height)
    b:SetPoint("TOPLEFT", indent, -y)
    b.wash = b:CreateTexture(nil, "BACKGROUND")
    b.wash:SetAllPoints()
    b.wash:Hide()
    -- the box's middle where the seal's was, 15 in and 13 down
    b.fill = b:CreateTexture(nil, "BORDER")
    b.fill:SetSize(INK_BOX, INK_BOX)
    b.fill:SetPoint("CENTER", b, "TOPLEFT", 15, -13)
    b.fill:SetColorTexture(1, 0.96, 0.85, 0.25)
    b.edges = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
                            { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetPoint(side[1], b.fill, side[1])
        t:SetPoint(side[2], b.fill, side[2])
        if i <= 2 then t:SetHeight(2) else t:SetWidth(2) end
        b.edges[i] = t
    end
    b.box = b:CreateTexture(nil, "ARTWORK")
    b.box:SetTexture(GAME_BOX)
    b.box:SetSize(GAME_BOX_SIZE, GAME_BOX_SIZE)
    b.box:SetPoint("CENTER", b.fill, "CENTER")
    b.tick = b:CreateTexture(nil, "OVERLAY")
    b.tick:SetTexture(GAME_TICK)
    b.tick:SetSize(GAME_BOX_SIZE, GAME_BOX_SIZE)
    b.tick:SetPoint("CENTER", b.fill, "CENTER", 1, 1)
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
        local classic = GK.Classic and GK.Classic()
        self.fill:SetShown(not classic)
        for _, t in ipairs(self.edges) do
            t:SetColorTexture(GK.INK[1], GK.INK[2], GK.INK[3], 0.9)
            t:SetShown(not classic)
        end
        self.box:SetShown(classic and true or false)
        self.tick:SetShown(r.get())
        self.tick:SetDesaturated(not classic)
        if classic then
            self.tick:SetVertexColor(1, 1, 1)
        else
            self.tick:SetVertexColor(GK.INK[1], GK.INK[2], GK.INK[3])
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
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
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
    return f, height
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
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
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
    return f, height
end

-- The Notifications page's own rows (2026-11-20): the presets over it, the Yours and Guildies' columns, a pair
-- of cells on a row, and a line of words with cells among them.
local COL_MINE, COL_GUILD = 236, 352      -- where a pair row's two cells start, and their headings over them

--- A cell's value on the page (a pair's, an inline row's): its words over a thin line, in blood under the
--- mouse, Off faded; a click opens its menu.
local function CellButton(parent, cell)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    b.text = b:CreateFontString(nil, "ARTWORK")
    GK.Ink(b.text, GK.INK, GK.TEXT_FONT, 12)
    b.text:SetPoint("LEFT", 0, 1)
    b.line = b:CreateTexture(nil, "ARTWORK")
    GK.Paint(b.line, "rule")
    b.line:SetHeight(1)
    b.line:SetPoint("BOTTOMLEFT", 0, 1)
    b.line:SetPoint("BOTTOMRIGHT", 0, 1)
    b.cell = cell
    function b:Refresh()
        local text = cell.text()
        self.text:SetText(text)
        self:SetWidth(TextWidth(self.text, text) + 2)
        GK.Ink(self.text, text == "Off" and GK.FADED or GK.INK, GK.TEXT_FONT, 12)
    end
    b:SetScript("OnEnter", function(self) GK.Ink(self.text, GK.BLOOD, GK.TEXT_FONT, 12) end)
    b:SetScript("OnLeave", function(self) self:Refresh() end)
    b:SetScript("OnClick", function(self)
        OpenMenu(self, function(root)
            for _, o in ipairs(cell.options) do
                root:CreateRadio(o[1], o[2], function()
                    o[3]()
                    RefreshPage()
                end)
            end
        end)
    end)
    return b
end

--- The presets over the page, as the ledger's ink tabs: the one the page matches in blood and underlined,
--- Custom lit when it matches none (and not to be clicked: it is what you made); under them what it means.
local function PresetsRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    f.tabs = {}
    local list = {}
    for _, p in ipairs(GK.NOTIFY_PRESETS) do list[#list + 1] = { key = p.key, name = p.name } end
    list[#list + 1] = { key = "custom", name = "Custom" }
    local x = 6
    for _, p in ipairs(list) do
        local b = CreateFrame("Button", nil, f)
        b.key = p.key
        b.text = b:CreateFontString(nil, "ARTWORK")
        GK.Ink(b.text, GK.FADED, GK.TEXT_FONT, 11)
        b.text:SetPoint("TOPLEFT", 0, -2)
        local words = p.name:upper()
        b.text:SetText(words)
        local w = TextWidth(b.text, words) + 2
        b:SetSize(w, 18)
        b:SetPoint("TOPLEFT", x, 0)
        x = x + w + 16
        b.line = b:CreateTexture(nil, "ARTWORK")
        GK.Paint(b.line, "blood")
        b.line:SetHeight(2)
        b.line:SetPoint("BOTTOMLEFT", 0, 0)
        b.line:SetPoint("BOTTOMRIGHT", 0, 0)
        if p.key ~= "custom" then
            b:SetScript("OnClick", function()
                GK.ApplyNotifyPreset(p.key)
                GK.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
                RefreshPage()
            end)
        end
        f.tabs[#f.tabs + 1] = b
    end
    f.hint = f:CreateFontString(nil, "ARTWORK")
    GK.Ink(f.hint, GK.FADED, GK.TEXT_FONT, 11)
    f.hint:SetPoint("TOPLEFT", 6, -22)
    f.hint:SetWidth(PAGE_W - 12)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetWordWrap(false)
    function f:Refresh()
        local now = GK.NotifyPreset()
        for _, b in ipairs(self.tabs) do
            local chosen = b.key == now
            GK.Ink(b.text, chosen and GK.BLOOD or GK.FADED, GK.TEXT_FONT, 11)
            b.line:SetShown(chosen)
        end
        self.hint:SetText(GK.NotifyPresetHint(now))
    end
    return f, height
end

--- YOURS and GUILDIES' over the pair rows' two cells.
local function ColumnsRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    for i, x in ipairs({ COL_MINE, COL_GUILD }) do
        local fs = f:CreateFontString(nil, "ARTWORK")
        GK.Ink(fs, GK.FADED, GK.TEXT_FONT, 10)
        fs:SetPoint("BOTTOMLEFT", x, 2)
        fs:SetText(i == 1 and "YOURS" or "GUILDIES'")
    end
    function f:Refresh() end
    return f, height
end

--- What is told, yours and a guildie's: the label, then each cell under its column.
local function PairRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    f.label = f:CreateFontString(nil, "ARTWORK")
    GK.Ink(f.label, GK.INK, GK.TEXT_FONT, 13)
    f.label:SetPoint("LEFT", 6, 0)
    f.label:SetText(r.label)
    f.mine = CellButton(f, r.mine)
    f.mine:SetPoint("LEFT", COL_MINE, 0)
    -- a row of yours alone has no guildie's cell (A grudge evened up)
    if r.guild then
        f.guild = CellButton(f, r.guild)
        f.guild:SetPoint("LEFT", COL_GUILD, 0)
    end
    function f:Refresh()
        self.mine:Refresh()
        if self.guild then self.guild:Refresh() end
    end
    return f, height
end

--- A line of words with cells among them ("Show mine [Always] guildies' [Not in combat]"), laid out from the
--- left as each cell's words are now.
local function InlineRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    f.parts = {}
    for _, part in ipairs(r.parts) do
        if type(part) == "string" then
            local fs = f:CreateFontString(nil, "ARTWORK")
            GK.Ink(fs, GK.INK, GK.TEXT_FONT, 13)
            fs:SetText(part)
            f.parts[#f.parts + 1] = { words = fs, text = part }
        else
            f.parts[#f.parts + 1] = { button = CellButton(f, part) }
        end
    end
    function f:Refresh()
        local x = 6
        for _, p in ipairs(self.parts) do
            if p.words then
                p.words:ClearAllPoints()
                p.words:SetPoint("LEFT", x, 0)
                x = x + TextWidth(p.words, p.text) + 6
            else
                p.button:Refresh()
                p.button:ClearAllPoints()
                p.button:SetPoint("LEFT", x, 0)
                x = x + p.button:GetWidth() + 14
            end
        end
    end
    return f, height
end

local ROW = { check = CheckRow, choice = ChoiceRow, pick = PickRow, sound = SoundRow, head = HeadRow,
    presets = PresetsRow, columns = ColumnsRow, pair = PairRow, inline = InlineRow }

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
    GK.CloseWindow()                                 -- the ledger these pages are a page of
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
    win = GK.LedgerSettingsPage()            -- the ledger's frame, X and tabs round these pages

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

    -- The foot of the menu, one of the game's buttons: Arrange on screen. Back to the ledger stood under it
    -- ("men det er ikke noe 'back'?", the owner, 2026-11-13) until the ledger's tabs stayed under these
    -- pages: any of them is the way back, and the Settings button pressed in on the title bar.
    local move = GK.MakeButton(win, SIDE_W, 22)
    move:SetPoint("BOTTOMLEFT", SIDE_X, 26)
    move:SetText("Arrange on screen")
    move:SetScript("OnClick", MoveThings)
    move:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Closes these pages and shows the letter icon, the spree splash and its toasts: drag "
            .. "each where you want it. Done opens the pages again.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    move:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.move = move

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
--- to it. The ledger opens on them, or turns to them where it is open.
function GK.OpenOptions(chapter)
    if not win then Build() end
    local turnTo = current
    for i, ch in ipairs(chapters) do
        if ch.name == chapter then turnTo = i end
    end
    Select(turnTo)
    GK.ShowLedgerSettings()
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
        note:SetText("Grudgekeeper keeps its settings in its own ledger. The Settings button on the ledger, a "
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
