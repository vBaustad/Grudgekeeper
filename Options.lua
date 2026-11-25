-- Grudgekeeper - its settings: a page of the ledger, two pages wide (Window.lua), with the ledger's tabs
-- under it to go back by. Dark, as the game's own options are, whatever the skin, and every control one of
-- the game's: dropdowns, checkboxes and red buttons. "det er cramped, vanskelig å forstå, spesielt lyder og
-- notifications. la oss bruke mer wow knapper og dropdowns og slikt, kanskje det ikke skal være
-- parchment/classic bakgrunn" (the owner, 2026-11-22), who picked A, the dark one, of three drawn with the
-- client's own art (art/mockups/settings2). The pages it replaced (2026-11-12 to 2026-11-22) were written in
-- ink on the parchment, and their dropdowns were words over a thin line.
-- A thing and its sound stand on one row: Sounds was a page of its own, with the same events over again.
-- Yours, a guildie's and the warnings are a page each. Nothing gives a surprise away: no Test, no page of a
-- spree's steps, no voice line to hear ahead - "test for alle sammen er ikke gøy. ødelegger surprisen. og for
-- de vanlige sprees la oss bare ha sound on/off" (the owner, at the first look in game, 2026-11-22).
-- Only a warning has a sound to pick: "synes ikke folk skal kunne velge lyder på notifications hvor vi har splash
-- og sånn. bare på typ.. når du ser noen du har på kill list osv? vi har jo allerede lagd lyder for det andre"
-- (the owner, 2026-11-22). What is a splash or a toast has a box, on or off.
-- A guildie's is a toast or nothing, so there it is a box as well, and no page has a preset: "splash bør være bare
-- for deg, og toast bør være for guildies. burde ikke kunne velge det egentlig? pointless? ... og presets.. fjerne
-- eller?" (the owner, 2026-11-22). Each of the three pages has its own Play sounds, and off it locks and greys
-- what is under it.
-- Nothing here says where a splash or a toast stands: each is moved on its own (Arrange on screen) -
-- "'by the letter icon' blir jo ikke riktig siden de kan flyttes på" (the owner, 2026-11-22).
-- Ours opens in a fight, closes itself while things are moved on screen, and needs no scrolling: a
-- chapter is a page. The game's Options -> AddOns -> Grudgekeeper keeps one button, which opens this.
-- Grudgekeeper is not one of the YippYapp addons (the user, 2026-11-03): no YippYapp page or footer.
-- Quick setup is the first page (2026-11-24): What you see sets the rows of Mine, Guildies and Warnings at once and is
-- Custom when they match none (GK.SEE, Core.lua), and What you share is what Mode was. The presets of 2026-11-20 were
-- the ledger's ink tabs over a page, and players took them for tabs to other things ("folk skjønte ikke at det var
-- presets og trudde det bare var tabs for forskjellige ting", the owner): these are the game's dropdowns, and each says
-- what its choice does, beside it and under the mouse. In the game was eight boxes; it is three pages, and the
-- right-click menu a box a line. Drawn first (art/mockups/modes, A).
-- Two layers: GK.SettingsChapters() is what there is to set, as data (what the tests read); the rest
-- draws it.
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

-- ---------------------------------------------------------------------------
-- What a dropdown offers: { value, the menu's words, the dropdown's own words where those are shorter }
-- ---------------------------------------------------------------------------
local STYLES = { { "splash", "Splash: big", "Splash" }, { "toast", "Toast: small", "Toast" }, { "off", "Off" } }
local WARN_WAYS = { { "screen", "On screen" }, { "chat", "Chat line" }, { "off", "Off" } }
-- What you share (Quick setup and Sharing), Mode's three until 2026-11-24, by what each does. The values stay.
local MODES = { { "normal", "Everything" }, { "streamer", "All but where I am" }, { "private", "Nothing" } }
local SHARE_SAYS = { normal = "Your score, and where you are and see targets.",
    streamer = "Your score, but never where you are or see targets.",
    private = "No score, no zone, no profile. Only what a kill order needs." }
-- A guildie's rows by what Quick setup calls them, when one alone is on (Counted)
local GUILD_WORDS = { spreeGuild = "kill sprees", rankGuild = "new titles", orderDone = "kill orders fulfilled",
    revengeGuild = "revenges", spreeEndedGuild = "sprees ended", spreeTormentorGuild = "tormentors put down" }
local WHEN = { { "always", "Always" }, { "noCombat", "Not in combat" },
    { "noCombatInInstance", "Not in combat in a dungeon or raid", "Not in combat in dungeons" },
    { "noInstance", "Never in a dungeon or raid", "Not in dungeons" } }
-- How long an announcement shows: the seconds a toast does, and a splash half of them (Announce.lua).
-- Beyond these it is a setting nobody needs ("legg settings så folk kan sette lengde selv", the owner,
-- 2026-11-14).
local TIMES = { { 3, "3 seconds, a splash 1.5", "3 seconds" }, { 5, "5 seconds, a splash 2.5", "5 seconds" },
    { 7, "7 seconds, a splash 3.5", "7 seconds" }, { 10, "10 seconds, a splash 5", "10 seconds" },
    { 15, "15 seconds, a splash 7.5", "15 seconds" } }
-- A guildie's sprees, from how many kills in a row (the tiers' own counts and never their names; "round": only
-- 25, 50 and 100), and a guildie's titles, from which title (the points it stands at). How it shows is a dropdown of
-- its own: one menu set both until 2026-11-22.
local SPREES_FROM = { { 3, "3 kills and up" }, { 5, "5 kills and up" }, { 7, "7 kills and up" },
    { 10, "10 kills and up" }, { 15, "15 kills and up" }, { "round", "Only 25, 50 and 100" } }
local TITLES_FROM = { { 0, "Every title" }, { 100, "Slayer and up" }, { 450, "Avenger and up" },
    { 900, "Nemesis and up" } }
local SKINS = { { "parchment", "Parchment" }, { "classic", "Classic" } }
local PLAY_ICON = "common-dropdown-icon-play"

-- ---------------------------------------------------------------------------
-- What there is to set
-- ---------------------------------------------------------------------------
--- A setting that is on or off, kept in GK.db[key]. child: it belongs under the row above. after(on):
--- what else has to happen when it changes.
local function Check(key, label, help, child, after)
    return { kind = "check", key = key, label = label, help = help, child = child,
        get = function() return GK.db[key] and true or false end,
        set = function(on)
            GK.db[key] = on and true or false
            if after then after(on) end
            GK.Changed()
        end }
end

--- A play button at the right of a menu's row. It plays, picks nothing and leaves the menu open: the game's
--- radio row closes its menu at every pick (Blizzard_Menu, MenuTemplates.CreateRadio has no response of its own),
--- so "man ikke må åpne og lukke dropdown hver gang" (the owner, 2026-11-22) needs a button of its own.
local function AddPlay(radio, play)
    if not (radio and radio.AddInitializer and MenuTemplates and MenuTemplates.AttachBasicButton) then return end
    radio:AddInitializer(function(row)
        -- the picture is the row's and the click a clear button's over it: the row's own click never hears it
        local icon = row:AttachTexture()
        icon:SetAtlas(PLAY_ICON)
        icon:SetSize(16, 16)
        icon:SetPoint("RIGHT", -3, 0)
        icon:SetAlpha(0.75)
        local button = MenuTemplates.AttachBasicButton(row, 24, 20)
        button:SetPoint("RIGHT")
        button:SetScript("OnEnter", function() icon:SetAlpha(1) end)
        button:SetScript("OnLeave", function() icon:SetAlpha(0.75) end)
        button:SetScript("OnClick", play)
        -- the row's size is said here: measured from its parts, the button would stand on the last letters
        return math.ceil(row.leftTexture1:GetWidth() + row.fontString:GetWidth()) + 38, 20
    end)
end

--- One value from a few: what a dropdown is. options is the list, or a function that makes it.
local function Cell(key, options, get, set)
    local cell = { key = key, get = get or function() return GK.db[key] end }
    cell.set = set or function(value)
        GK.db[key] = value
        GK.Changed()
    end
    function cell.choices()
        if type(options) == "function" then return options() end
        return options
    end
    function cell.text()
        local value = cell.get()
        for _, o in ipairs(cell.choices()) do
            if o[1] == value then return o[3] or o[2] end
        end
        return cell.missing or (value == nil and "" or tostring(value))
    end
    function cell.fill(root, done)
        local list = cell.choices()
        if cell.scroll and root.SetScrollMode then root:SetScrollMode(420) end
        local into, group = root, nil
        for _, o in ipairs(list) do
            local value = o[1]
            -- a sound's menu: a title over each kind, and the other addons' in a menu of their own at the end
            if o.group and o.group ~= group then
                group, into = o.group, root
                if o.sub and root.CreateButton then
                    into = root:CreateButton(group)
                    if into.SetScrollMode then into:SetScrollMode(420) end
                elseif root.CreateTitle then
                    root:CreateTitle(group)
                end
            end
            local radio = into:CreateRadio(o[2], function() return cell.get() == value end, function()
                cell.set(value)
                if cell.picked then cell.picked(value) end
                if done then done() end
            end)
            if cell.preview and value ~= "off" then AddPlay(radio, function() cell.preview(value) end) end
            -- what a choice does, under the mouse (What you see's): the game's menu has one line a row
            if o.tip and radio and radio.SetTooltip then
                radio:SetTooltip(function(tooltip)
                    tooltip:SetText(o[2])
                    tooltip:AddLine(o.tip, 1, 1, 1, true)
                end)
            end
        end
    end
    return cell
end

--- A warning's sound to pick. Each has a play button in the menu; picking one keeps it and plays it as well.
local function SoundCell(key, get, set)
    local cell = Cell(key, function() return GK.SoundChoices() end, get, set)
    cell.scroll = true
    cell.missing = "Missing sound"       -- one picked that is gone (a pack taken away): the default plays
    function cell.picked(value) GK.PreviewSound(value) end
    function cell.preview(value) GK.PreviewSound(value) end
    function cell.enabled() return GK.db.warnSounds ~= false end
    cell.lockedWords = "None"            -- Play sounds off: grey and None, the pick kept for when it is on again
    return cell
end

-- What stands on a row after its label, x from the row's left.
local function Drop(x, w, cell) return { kind = "drop", x = x, w = w, cell = cell } end
local function Tick(x, w, check) return { kind = "tick", x = x, w = w, check = check } end

local function Columns(...)
    local row = { kind = "columns", at = {} }
    for i = 1, select("#", ...), 2 do
        local x, words = select(i, ...)
        row.at[#row.at + 1] = { x = x, text = words }
    end
    return row
end

local function Ruled() return { kind = "rule" } end
local function Section(label) return { kind = "head", label = label } end
--- A choice of Quick setup: its dropdown, and beside it what the choice does (says()).
local function Choice(cell, says) return { kind = "choice", cell = cell, says = says } end
--- A line of what a choice comes to: value() gives the words, and true after them for a no (grey).
local function Fact(label, value) return { kind = "fact", label = label, value = value } end
--- Words of the page's own, in the quiet grey.
local function Note(text) return { kind = "note", text = text } end
--- Two settings on or off side by side, each with its words: the right-click menu's, an enemy's and a friend's.
local function Pair(left, right) return { kind = "pair", left = left, right = right } end

--- A moment's sound box: locked, unticked and grey while its page's Play sounds is off, or while it doesn't show.
local function SoundBox(label, key, master, shownBy)
    local check = Check(key, "")         -- the column says Sound: the box needs no words beside it
    check.name = label .. ": sound"
    function check.enabled() return GK.db[master] ~= false and GK.db[shownBy] ~= "off" end
    function check.why()
        if GK.db[master] == false then return "Locked while Play sounds is off." end
        return "It doesn't show, so it has no sound."
    end
    return check
end

--- A row of Mine: splash, toast or off, and its sound.
local function MineMoment(label, setting, sound)
    return { kind = "line", label = label, stripe = true, parts = { Drop(268, 118, Cell(setting, STYLES)),
        Tick(420, 52, SoundBox(label, sound, "mineSounds", setting)) } }
end

--- What you share (Core.lua, GK.Mode), Mode until 2026-11-24: on Quick setup and on Sharing, one setting. It decides
--- what goes out and nothing else: what you see is the rows' (SeeCell).
local function ShareCell()
    return Cell("mode", MODES, function() return GK.Mode() end, function(value)
        local was = GK.Mode()
        GK.db.mode = value
        if was == "private" and value ~= "private" then GK.SendBoard() end     -- sharing again: the guild hears it
        GK.Changed()
    end)
end

local function ShareSays() return SHARE_SAYS[GK.Mode()] end

local function ShareRow()
    return { kind = "line", label = "What you share", height = 54, help = ShareSays,
        parts = { Drop(268, 200, ShareCell()) } }
end

--- What you see (Core.lua, GK.SEE): the rows of Mine, Guildies and Warnings at once, Custom when they match none.
--- Each choice says what it does under the mouse.
local function SeeCell()
    local list = {}
    for i, c in ipairs(GK.SEE) do list[i] = { c.id, c.name, tip = c.says } end
    local cell = Cell("see", list, function() return GK.SeeChoice() end, function(id)
        GK.SetSee(id)
        GK.Changed()
    end)
    cell.missing = "Custom"
    return cell
end

local function SeeSays()
    local id = GK.SeeChoice()
    for _, c in ipairs(GK.SEE) do
        if c.id == id then return c.says end
    end
    return "You changed rows on the pages. Pick one to start over."
end

--- How many of a page's rows show: all, none, "Only" the one, or "n of N". True after the words for none.
local function Counted(keys, on, all, none, words)
    local shown, last = 0, nil
    for _, key in ipairs(keys) do
        if on(key) then shown, last = shown + 1, key end
    end
    if shown == 0 then return none, true end
    if shown == #keys then return all end
    if shown == 1 and words and words[last] then return "Only " .. words[last] end
    return ("%d of %d"):format(shown, #keys)
end

local function Shown(key) return GK.db[key] ~= "off" end
local function Warned(key) return GK.WarnStyle(key) ~= "off" end
local function Yes(on) return on and "Yes" or "No", not on end

--- A setting of Sharing that sharing Nothing turns off: unticked, grey and kept for when it is on again.
local function Shared(check)
    function check.enabled() return GK.Mode() ~= "private" end
    function check.why() return "What you share is Nothing." end
    return check
end

--- A row of Guildies: a toast or nothing, its sound, and for sprees and titles from how many.
local function GuildMoment(label, setting, sound, from)
    local toast = { kind = "check", key = setting, label = "",
        get = function() return GK.db[setting] ~= "off" end,
        set = function(on)
            GK.db[setting] = on and "toast" or "off"
            GK.Changed()
        end }
    local parts = { Tick(230, 52, toast), Tick(298, 52, SoundBox(label, sound, "guildSounds", setting)) }
    if from then parts[#parts + 1] = Drop(378, 182, from) end
    return { kind = "line", label = label, stripe = true, parts = parts }
end

--- A page's own Play sounds, over the column of what it locks.
local function PlaySounds(key, x, tip)
    local check = Check(key, "")
    check.name, check.tip = "Play sounds", tip
    return { kind = "line", label = "Play sounds", height = 40, parts = { Tick(x, 52, check) } }
end

local function WarnRow(setting, label, sound, help)
    local parts = { Drop(282, 106, Cell(setting, WARN_WAYS, function() return GK.WarnStyle(setting) end)) }
    if sound then parts[#parts + 1] = Drop(404, 158, sound) end
    return { kind = "line", label = label, help = help, stripe = true, height = help and 56 or 44, parts = parts }
end

-- How tall each kind of row is on the page, which holds PAGE_ROOM under its heading (the window, below):
-- drawn at these, and summed by tests/run.lua so that no chapter runs past the frame.
local PAGE_ROOM = 430
local ROW_HEIGHT = { columns = 24, rule = 14, head = 28, choice = 48, fact = 24, note = 40, pair = 58 }
GK.SETTINGS_ROOM = PAGE_ROOM
function GK.SettingsRowHeight(r)
    if r.height then return r.height end
    if r.kind == "check" then return r.help and 50 or 38 end
    return ROW_HEIGHT[r.kind] or 37
end

--- The chapters, in the order of the menu: { group, name, title, intro, rows }. Made anew at each call, so a
--- test reads it without a window.
function GK.SettingsChapters()
    local mine = {
        PlaySounds("mineSounds", 420, "The sounds of your own splashes and toasts."),
        Columns(10, "WHEN", 268, "SHOW AS", 426, "SOUND"),
        MineMoment("Kill spree", "spreeMine", "spreeSound"),
        MineMoment("New title", "rankMine", "rankSound"),
        MineMoment("Kill order fulfilled", "orderMine", "orderSound"),
        MineMoment("Revenge", "revengeMine", "revengeSound"),
        -- yours alone: a guildie's score with an enemy is theirs (Announce.lua, GK_GRUDGE)
        MineMoment("Grudge or Death Note kill", "grudgeMine", "grudgeSound"),
        MineMoment("Spree ended", "spreeEnded", "endedSound"),
        MineMoment("Tormentor put down", "spreeTormentor", "tormentorSound"),
        Ruled(),
        -- each says what it sets: "Show them" read "Show the...", and said nothing whole either ("samme på flere
        -- sider, gir ikke så mye mening", the owner, 2026-11-22)
        { kind = "line", label = "Show my notifications", parts = {
            Drop(268, 240, Cell("announceWhenMine", WHEN, function() return GK.db.announceWhenMine or "always" end)) } },
        { kind = "line", label = "How long notifications stay", parts = {
            Drop(268, 130, Cell("announceTime", TIMES, function() return GK.db.announceTime or 7 end)) } },
    }

    local spreesFrom = Cell("spreeGuildFrom", SPREES_FROM)
    spreesFrom.enabled = function() return GK.db.spreeGuild ~= "off" end
    local titlesFrom = Cell("rankGuildFrom", TITLES_FROM)
    titlesFrom.enabled = function() return GK.db.rankGuild ~= "off" end
    local guild = {
        PlaySounds("guildSounds", 298, "The sounds of your guildies' toasts."),
        Columns(10, "WHEN A GUILDIE HAS", 236, "TOAST", 304, "SOUND", 378, "ONLY FROM"),
        GuildMoment("A kill spree", "spreeGuild", "spreeSoundGuild", spreesFrom),
        GuildMoment("A new title", "rankGuild", "rankSoundGuild", titlesFrom),
        GuildMoment("A kill order fulfilled", "orderDone", "orderSoundGuild"),
        GuildMoment("A revenge", "revengeGuild", "revengeSoundGuild"),
        GuildMoment("A spree ended", "spreeEndedGuild", "endedSoundGuild"),
        GuildMoment("Put a tormentor down", "spreeTormentorGuild", "tormentorSoundGuild"),
        Ruled(),
        { kind = "line", label = "Show guildie notifications", parts = {
            Drop(268, 240, Cell("announceWhenGuild", WHEN,
                function() return GK.db.announceWhenGuild or "noCombat" end)) } },
        Check("guildZoneOnly", "Only when they are in my zone"),
    }

    local warnings = {
        PlaySounds("warnSounds", 398, "The sounds of the warnings on this page."),
        Columns(10, "WARN ME WHEN", 282, "SHOW AS", 404, "SOUND"),
        WarnRow("alertNear", "A kill order target is near",
            SoundCell("near", function() return GK.db.nearSound end, function(value)
                GK.db.nearSound = value
                GK.Changed()
            end),
            "Also the sound for your Death Note and the tracked guild."),
        WarnRow("watchNearby", "A Shame player is near"),
        WarnRow("watchGroup", "A Shame player joins my group",
            SoundCell("shame", function() return GK.ShameSoundKey() end, function(value)
                GK.db.shameSound = value
                GK.Changed()
            end)),
        WarnRow("kudosGroup", "A Kudos player joins my group"),
        -- 2026-11-24: "skal vi prøve å legge til warning om fiender targeter oss?" (the owner); off to begin with
        WarnRow("targetedBy", "A Death Note enemy targets me",
            SoundCell("target", function() return GK.db.targetSound end, function(value)
                GK.db.targetSound = value
                GK.Changed()
            end),
            "Out of a fight, and only one you can see: enemy nameplates on."),
    }

    -- Quick setup (2026-11-24): what you see, what you share, and what each comes to
    local quick = {
        Section("WHAT YOU SEE"),
        Choice(SeeCell(), SeeSays),
        Fact("Your splashes and toasts", function() return Counted(GK.SEE_MINE, Shown, "On", "Off") end),
        Fact("Guildies' toasts", function() return Counted(GK.SEE_GUILD, Shown, "All of them", "None", GUILD_WORDS) end),
        Fact("Warnings", function() return Counted(GK.SEE_WARN, Warned, "All of them", "Off") end),
        Ruled(),
        Section("WHAT YOU SHARE"),
        Choice(ShareCell(), ShareSays),
        Fact("Score on the leaderboard", function() return Yes(GK.SharesScore()) end),
        Fact("Where you are", function() return Yes(GK.SharesPlace()) end),
        Fact("Profile outside the guild", function() return Yes(GK.SharesOutside()) end),
        Ruled(),
        Note("Seals and marks over players are on Nameplates & map. Letters have a page of their own."),
    }

    return {
        { name = "Quick setup", title = "Quick setup",
          intro = "Start here. Every page after this one can still be changed row by row.", rows = quick },
        { group = "NOTIFICATIONS", name = "Mine", title = "My notifications",
          intro = "What you see and hear when it happens to you.", rows = mine },
        { group = "NOTIFICATIONS", name = "Guildies", title = "Guildie notifications",
          intro = "What you see and hear when it happens to someone in your guild.", rows = guild },
        { group = "NOTIFICATIONS", name = "Warnings", title = "Warnings",
          intro = "Who is near, and who joins your group.", rows = warnings },
        { group = "GENERAL", name = "Letters", title = "Letters", intro = "Sealed letters from the Grudgekeeper.",
          rows = {
            Check("anyLetters", "Letters", "News as small sealed letters.", false,
                function() if GK.NoticeUpdate then GK.NoticeUpdate(false) end end),     -- the icon at once
            Check("letters", "Kill orders", "A new one with gold, from a friend or about you.", true),
            Check("myLetters", "My own deaths", "A death that posted a kill order.", true),
            Check("keepLetters", "Wait until read", "Off: an unread letter fades after two minutes.", true,
                function(on) if not on and GK.FadeLetters then GK.FadeLetters() end end),   -- what waited fades
          } },
        -- a page of its own, for its one setting (the owner, 2026-11-24: "kanskje egen page for death note")
        { group = "GENERAL", name = "Death Note", title = "Death Note", intro = "Your own list of the enemies you want dead.",
          rows = {
            Check("deathNoteShared", "One Death Note for all my characters",
                "Every character of yours on the same side shares the names, your notes and the warning.", false,
                function(on)
                    if on then
                        GK.db.deathNoteTick = (GK.db.deathNoteTick or 0) + 1
                        GK.JoinDeathNote()
                    end
                end),
            Ruled(),
            Note("The warning's sound is on Warnings, and the eye over their nameplate on Nameplates & map."),
          } },
        { group = "GENERAL", name = "Sharing", title = "Sharing", intro = "What others get to see.",
          rows = {
            ShareRow(),
            Shared(Check("share", "Share my score with the guild", "Your kills, deaths and points on the leaderboard.",
                false, function(on) if on then GK.SendBoard() end end)),
            -- a player on your side outside the guild who opens your profile or inspects you (2026-11-20)
            Shared(Check("shareOutside", "Share my profile outside the guild",
                "Players on your side who ask see your title, points, kills and deaths.")),
            -- each player's own: it is the victim's client that posts (Guild.lua, GK.AutoOrder). "dette er en
            -- settings for deg selv personlig er det ikke. skrevet som om du bestemmer settingen for hele guilden"
            -- (the owner, 2026-11-22)
            Shared(Check("autoOrders", "My deaths can post kill orders",
                "When someone kills you 3 times in half an hour, or 3 of the guild in two hours.")),
          } },
        -- In the game's eight boxes are three pages (2026-11-24): "sidebar items under general burde ha bedre navn. i
        -- hvert fall 'in the game'" (the owner). The right-click menu has a box a line.
        { group = "GENERAL", name = "Nameplates & map", title = "Nameplates & map",
          intro = "What Grudgekeeper puts on players and on the map.",
          rows = {
            Check("tooltip", "Line on enemy tooltips", "Only for enemies you have a history with."),
            Check("plateMarks", "Seal over kill order targets", "And an eye over your Death Note. Needs enemy nameplates."),
            Check("plateNotes", "Mark over Shame and Kudos players", "A medal for each Kudos tag, out of combat. A small mark for Shame."),
            Check("mapPins", "Last seen on the map", "Where a guildie saw a target, for 15 minutes."),
          } },
        { group = "GENERAL", name = "Right-click menu", title = "Right-click menu",
          intro = "Our lines in the game's menu when you right-click a player.",
          rows = {
            Columns(10, "ON AN ENEMY", 286, "ON A FRIENDLY PLAYER"),
            Pair(Check("menuFile", "Grudge file", "What the guild knows of them."),
                Check("menuProfile", "Grudgekeeper profile", "Their title and score.")),
            Pair(Check("menuOrder", "Kill order", "Post one, or add to the pot."),
                Check("menuShame", "Shame", "Put them on it, with a tag.")),
            Pair(Check("menuDeathNote", "Death Note", "Write them in, or take them out."),
                Check("menuKudos", "Kudos", "Give them kudos, with a tag.")),
            Pair(Check("menuGuild", "Track their guild", "Officers: put their guild on watch."),
                Check("menuNotes", "Their notes", "When someone has written about them.")),
            Ruled(),
            Note("A line that is off is left out of the menu. With every line off, Grudgekeeper adds nothing to it."),
          } },
        { group = "GENERAL", name = "Buttons & tabs", title = "Buttons & tabs",
          intro = "Where Grudgekeeper shows up in the game's own windows.",
          rows = {
            Check("inspectTab", "Tab on the Inspect window", "A guildie's record, right there."),
            { kind = "check", key = "guildButton", label = "Tab on the guild window",
              help = "Your week, the kill orders, the leaderboard and guild chat.",
              get = function() return GK.db.guildButton ~= false end,
              set = function(on)
                  GK.db.guildButton = on and true or false
                  GK.RefreshGuildTab()
              end },
            { kind = "check", key = "minimap", label = "Minimap button",
              help = "Left-click opens the ledger, right-click the settings.",
              get = function() return not (GK.db.minimap and GK.db.minimap.hide) end,
              set = function(on) GK.SetMinimapShown(on) end },
          } },
        { group = "GENERAL", name = "Appearance", title = "Appearance",
          intro = "The ledger, portraits and screenshots.",
          rows = {
            -- the skin dresses the ledger and the notes (GK.SetLook), never these pages; the letters and the
            -- kill order's poster are the Grudgekeeper's paper in both
            { kind = "line", label = "Ledger skin", height = 48, parts = {
                Drop(212, 180, Cell("look", SKINS, function() return GK.db.look or "parchment" end,
                    function(value) GK.SetLook(value) end)) } },
            -- the faces go with neither skin ("classic portraits no matter what ... en egen settings
            -- uavhengig av classic/parchment settings", the owner, 2026-11-11)
            Check("oldPortraits", "Old race portraits", "Faces from the old character screen. Off: today's icons."),
            Check("sound", "Ledger and letter sounds", "Pages, tabs and letters. The notifications have their own."),
            Ruled(),
            Section("SCREENSHOTS"),
            Check("shotFulfil", "When I fulfil a kill order"),
            Check("shotEveryKill", "At every kill"),
          } },
    }
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------
-- The ledger open is 792 by 544; these are the mockup's own numbers (art/mockups/settings2), in points.
local MENU_X, MENU_W, MENU_TOP, MENU_STEP = 16, 176, 44, 29
local SPLIT_X = 198
local PAGE_X, PAGE_W, PAGE_Y = 208, 570, 94
local TEXT_X = 10                         -- where a row's words begin
-- these pages' own colours, whatever the skin: the game's options' gold and white, and a quiet grey
local GOLD, WHITE, QUIET = { 1, 0.82, 0 }, { 1, 1, 1 }, { 0.73, 0.68, 0.6 }
local OFF_WORDS = "|cff8d8d8d%s|r"
local CHECKBOX, DROPDOWN = "MinimalCheckboxTemplate", "WowStyle1DropdownTemplate"

local win, chapters
local current = 1
local buttons, pages = {}, {}
local pageTitle, pageIntro, host
local reopen = false                     -- closed to move things on screen: open again when that is done
local RefreshPage

--- Words on these pages. Not GK.Ink: they keep their colours when the skin is switched.
local function Words(parent, size, colour)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    GK.SetFont(fs, GK.TEXT_FONT, size)        -- the font first: the game refuses text before it
    fs:SetTextColor(colour[1], colour[2], colour[3])
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Tip(owner, first, second)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(first, 1, 1, 1, true)
    if second then GameTooltip:AddLine(second, nil, nil, nil, true) end
    GameTooltip:Show()
end

--- One of the game's checkboxes with its words. The whole of it is the click, and the box only shows it.
local function TickBox(parent, r, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.wash = b:CreateTexture(nil, "BACKGROUND")
    b.wash:SetAllPoints()
    b.wash:SetColorTexture(1, 1, 1, 0.05)
    b.wash:Hide()
    b.box = CreateFrame("CheckButton", nil, b, CHECKBOX)
    b.box:SetPoint("TOPLEFT", 6, -2)
    b.box:EnableMouse(false)
    b.label = Words(b, 13, GOLD)
    b.label:SetPoint("TOPLEFT", 40, -9)
    b.label:SetWidth(width - 44)
    b.label:SetText(r.label)
    if r.help then
        b.help = Words(b, 11, QUIET)
        b.help:SetPoint("TOPLEFT", 40, -28)
        b.help:SetWidth(width - 44)
        b.help:SetText(r.help)
    end
    b:SetScript("OnEnter", function(self)
        local live = self.live ~= false
        self.wash:SetShown(live)
        if not live and r.why then Tip(self, r.name or r.label, r.why())
        elseif r.tip then Tip(self, r.name or r.label, r.tip) end
    end)
    b:SetScript("OnLeave", function(self)
        self.wash:Hide()
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self)
        if self.live == false then return end            -- locked: it keeps what it was
        local on = not r.get()
        r.set(on)
        GK.Sound(on and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        RefreshPage()
    end)
    -- locked, it is unticked, grey and deaf to a click, and still says why under the mouse
    function b:Refresh()
        local live = not r.enabled or r.enabled()
        self.live = live and true or false
        self.box:SetChecked(self.live and r.get() and true or false)
        self.box:SetEnabled(self.live)
        self:SetAlpha(self.live and 1 or 0.45)
    end
    return b
end

--- One of the game's dropdowns. Its words are set here rather than read from its menu: the menu is longer
--- ("Splash: big" for Splash), and a sound's holds every sound pack's.
local function DropBox(parent, part)
    local cell = part.cell
    local d = CreateFrame("DropdownButton", nil, parent, DROPDOWN)
    d:SetWidth(part.w)
    d.cell = cell
    d:SetupMenu(function(_, root) cell.fill(root, RefreshPage) end)
    function d:Refresh()
        local live = not cell.enabled or cell.enabled()
        local words = not live and cell.lockedWords or cell.text()
        if not live or words == "Off" or words == "None" then words = OFF_WORDS:format(words) end
        self:OverrideText(words)
        if cell.enabled then self:SetEnabled(live and true or false) end
    end
    return d
end

--- A setting on or off, a row of its own.
local function CheckRow(parent, y, r)
    local indent = r.child and 30 or 0
    local height = GK.SettingsRowHeight(r)
    local b = TickBox(parent, r, PAGE_W - indent, height)
    b:SetPoint("TOPLEFT", indent, -y)
    return b, height
end

--- A label and what stands after it.
local function LineRow(parent, y, r, striped)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    if striped then
        f.stripe = f:CreateTexture(nil, "BACKGROUND")
        f.stripe:SetAllPoints()
        f.stripe:SetColorTexture(1, 1, 1, 0.035)
    end
    local middle = r.help and 20 or height / 2        -- from the row's top, where its controls stand
    f.label = Words(f, 13, GOLD)
    f.label:SetPoint("LEFT", f, "TOPLEFT", TEXT_X, -middle)
    local first = r.parts[1]
    if first then f.label:SetWidth(first.x - TEXT_X - 6) end
    f.label:SetText(r.label)
    if r.help then
        f.help = Words(f, 11, QUIET)
        f.help:SetPoint("TOPLEFT", TEXT_X, -36)
        f.help:SetWidth(PAGE_W - 2 * TEXT_X)
        f.help:SetText(type(r.help) == "function" and (r.help() or "") or r.help)
    end
    f.parts = {}
    for i, part in ipairs(r.parts) do
        local c
        if part.kind == "drop" then c = DropBox(f, part) else c = TickBox(f, part.check, part.w, 33) end
        c:SetPoint("LEFT", f, "TOPLEFT", part.x, -middle)
        f.parts[i] = c
    end
    function f:Refresh()
        for _, c in ipairs(self.parts) do c:Refresh() end
        if self.help and type(r.help) == "function" then self.help:SetText(r.help() or "") end   -- What you share's
    end
    return f, height
end

--- A choice of Quick setup: the dropdown, and what the choice does beside it in grey, two lines at most.
local function ChoiceRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    f.drop = DropBox(f, { w = 250, cell = r.cell })
    f.drop:SetPoint("TOPLEFT", TEXT_X, -8)
    f.says = Words(f, 12, QUIET)
    f.says:SetPoint("TOPLEFT", 280, -6)
    f.says:SetWidth(PAGE_W - 280 - TEXT_X)
    f.says:SetWordWrap(true)
    function f:Refresh()
        self.drop:Refresh()
        self.says:SetText(r.says() or "")
    end
    return f, height
end

--- What a choice comes to: its label in gold, the value in white, or grey for a no.
local function FactRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    f.label = Words(f, 13, GOLD)
    f.label:SetPoint("LEFT", TEXT_X, 0)
    f.label:SetText(r.label)
    f.value = Words(f, 13, WHITE)
    f.value:SetPoint("LEFT", 222, 0)
    function f:Refresh()
        local text, off = r.value()
        self.value:SetText(text or "")
        local c = off and QUIET or WHITE
        self.value:SetTextColor(c[1], c[2], c[3])
    end
    return f, height
end

--- The page's own words, in grey.
local function NoteRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    f.text = Words(f, 12, QUIET)
    f.text:SetPoint("TOPLEFT", TEXT_X, -12)
    f.text:SetWidth(PAGE_W - 2 * TEXT_X)
    f.text:SetWordWrap(true)
    f.text:SetText(r.text)
    function f:Refresh() end
    return f, height
end

--- Two boxes side by side, each with its words: an enemy's line of the menu on the left, a friend's on the right.
local PAIR_X = 280
local function PairRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    f.left = TickBox(f, r.left, PAIR_X - 4, height)
    f.left:SetPoint("TOPLEFT", 0, 0)
    f.right = TickBox(f, r.right, PAGE_W - PAIR_X, height)
    f.right:SetPoint("TOPLEFT", PAIR_X, 0)
    function f:Refresh()
        self.left:Refresh()
        self.right:Refresh()
    end
    return f, height
end

--- The small words over a page's columns.
local function ColumnsRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    for _, at in ipairs(r.at) do
        local fs = Words(f, 11, QUIET)
        fs:SetPoint("BOTTOMLEFT", at.x, 4)
        fs:SetText(at.text)
    end
    function f:Refresh() end
    return f, height
end

local function Divider(parent, width)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetAtlas("Options_HorizontalDivider")
    t:SetSize(width, 1)
    return t
end

local function RuleRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    Divider(f, PAGE_W - 4):SetPoint("LEFT", 2, 0)
    function f:Refresh() end
    return f, height
end

local function SectionRow(parent, y, r)
    local height = GK.SettingsRowHeight(r)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(PAGE_W, height)
    f:SetPoint("TOPLEFT", 0, -y)
    f.label = Words(f, 11, QUIET)
    f.label:SetPoint("BOTTOMLEFT", TEXT_X, 4)
    f.label:SetText(r.label)
    function f:Refresh() end
    return f, height
end

local ROW = { check = CheckRow, line = LineRow, columns = ColumnsRow, rule = RuleRow, head = SectionRow,
    choice = ChoiceRow, fact = FactRow, note = NoteRow, pair = PairRow }

--- A chapter's page, made the first time it is turned to: its rows under one another, every other one of
--- a table's shaded.
local function BuildPage(i)
    local page = CreateFrame("Frame", nil, host)
    page:SetAllPoints(host)
    page.rows = {}
    local y, n = 0, 0
    for _, r in ipairs(chapters[i].rows) do
        if r.stripe then n = n + 1 else n = 0 end
        local row, height = ROW[r.kind](page, y, r, n % 2 == 1)
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
        b.lit:SetShown(chosen)
        b.glow:Hide()
        local c = chosen and WHITE or GOLD
        b.name:SetTextColor(c[1], c[2], c[3])
    end
    local ch = chapters[current]
    pageTitle:SetText(ch.title)
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

--- The menu down the left: the two groups over their chapters' names, in the game's options' own lit and
--- hover strips. Names and nothing else: with seals and lines it read as a list of things ("fjern ikoner og
--- gjør det mer som ordentlig settings", the owner, 2026-11-13).
local function BuildMenu()
    local y, group = MENU_TOP, nil
    for i, ch in ipairs(chapters) do
        if ch.group ~= group then
            if i > 1 then y = y + 20 end           -- under Quick setup, which has no group over it, too
            group = ch.group
            local head = Words(win, 11, QUIET)
            head:SetPoint("TOPLEFT", MENU_X + 6, -y)
            head:SetText(group)
            y = y + 20
        end
        local b = CreateFrame("Button", nil, win)
        b:SetSize(MENU_W, 25)
        b:SetPoint("TOPLEFT", MENU_X, -y)
        b.lit = b:CreateTexture(nil, "BACKGROUND")
        b.lit:SetAtlas("Options_List_Active")
        b.lit:SetAllPoints()
        b.lit:Hide()
        b.glow = b:CreateTexture(nil, "BORDER")
        b.glow:SetAtlas("Options_List_Hover")
        b.glow:SetAllPoints()
        b.glow:Hide()
        b.name = Words(b, 14, GOLD)
        b.name:SetPoint("LEFT", 18, 0)
        b.name:SetText(ch.name)
        b:SetScript("OnClick", function()
            GK.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
            Select(i)
        end)
        b:SetScript("OnEnter", function(self) self.glow:SetShown(i ~= current) end)
        b:SetScript("OnLeave", function(self) self.glow:Hide() end)
        buttons[i] = b
        y = y + MENU_STEP
    end
end

local function Build()
    chapters = GK.SettingsChapters()
    win = GK.LedgerSettingsPage()            -- the ledger's frame, X and tabs round these pages
    BuildMenu()

    local split = win:CreateTexture(nil, "ARTWORK")
    split:SetColorTexture(0.67, 0.53, 0.31, 0.45)
    split:SetSize(1, 492)
    split:SetPoint("TOPLEFT", SPLIT_X, -34)

    -- The foot of the menu: the version, and Arrange on screen. Back to the ledger stood under it ("men det
    -- er ikke noe 'back'?", the owner, 2026-11-13) until the ledger's tabs stayed under these pages: any of
    -- them is the way back, and the Settings button pressed in on the title bar.
    local version = Words(win, 11, QUIET)
    version:SetPoint("BOTTOMLEFT", 28, 62)
    version:SetText("v" .. GK.addonVersion)
    local move = CreateFrame("Button", nil, win, GK.BUTTON)
    move:SetSize(158, 26)
    move:SetPoint("BOTTOMLEFT", 26, 28)
    move:SetText("Arrange on screen")
    move:SetScript("OnClick", MoveThings)
    move:HookScript("OnEnter", function(self)
        Tip(self, "Closes the settings and shows the splash, the toasts and the letter icon.",
            "Drag each where you want it. Done opens the settings again.")
    end)
    move:HookScript("OnLeave", function() GameTooltip:Hide() end)
    win.move = move

    -- the chapter chosen, right of the line: its name, what it is about, and its settings
    pageTitle = Words(win, 20, GOLD)
    pageTitle:SetPoint("TOPLEFT", PAGE_X + 6, -40)
    pageIntro = Words(win, 12, QUIET)
    pageIntro:SetPoint("TOPLEFT", PAGE_X + 6, -66)
    pageIntro:SetWidth(PAGE_W - 12)
    Divider(win, PAGE_W - 4):SetPoint("TOPLEFT", PAGE_X + 2, -88)
    host = CreateFrame("Frame", nil, win)
    host:SetSize(PAGE_W, PAGE_ROOM)
    host:SetPoint("TOPLEFT", PAGE_X, -PAGE_Y)

    win.chapters, win.pages, win.title = buttons, pages, pageTitle
    -- a setting changed from somewhere else (the minimap button's own menu): drawn again
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
