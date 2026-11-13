-- Grudgekeeper - a tab of our own on the guild window, and the page it opens: a page of the ledger laid
-- over the whole window, with you this week, the open kill orders, the guild's news, the week's
-- leaderboard, and guild chat to read and write in ("lagt vår tab som en lik guildtab ... så du liksom
-- får en view hvor du kan se stats og chatte i guild på en gang", the owner, 2026-11-13).
--
-- How it came to look as it does, the same day:
--   1. A band over the top of the game's chat and a column over its member list. It read as laid on: no
--      frame, overlapping what was under it, and a different page from another view than Chat ("det var
--      lagt på så det overlappet ting og hadde ikke noe rammer ... gjør det hele til en grudgekeeper tab").
--      So the page covers everything inside the window's frame - the list of clubs too - and is the same
--      page whatever the game was on. The guild's crest gives way to the Grudgekeeper's face.
--   2. One sheet of parchment with ruled lines, the chat a faint box on it ("ser bedre ut. men selve
--      chatten vil jeg ha bedre. og rammer inni osv kunne vært bedre"). So every part is a panel with a
--      line round it and a leather band for its name, and the chat is a chat: dark, in the game's own
--      font and colours, with a scroll bar, names to click and what the game already holds of history.
--
-- Guild chat is a panel of our own, because the game's chat is only there on its Chat view and cannot be
-- asked for. Its lines come from two places: CHAT_MSG_GUILD, kept since login (and the last of them from
-- one session to the next), and - when the game's own chat view has been up - the lines that view holds,
-- read off its message frame as the game wrote them, which reach back before login. What you write goes
-- to guild chat when you press Enter: your own keypress.
--   The two are put together by what the game's view CAN hold, not by comparing them. It listens for
--   chat only from its OnShow to its OnHide, and fills itself afresh from the game's store each time it
--   comes up (CommunitiesChatMixin:OnShow, :OnHide, :DisplayChat). So whatever was said while it was up,
--   or before it last came up, it has; what was said since it went away, it has not. The page shows its
--   lines and, after them, ours from since it went away. The first merge matched a line of ours to one
--   of the game's by the clock and the words, twenty seconds apart at most, and in the game every line
--   came up twice after a look at the game's own Chat tab ("dobler text ... går man til noe annet og
--   tilbake er det dobbelt", the owner, 2026-11-13). Which half of that match failed was never
--   measured; this needs neither half.
--   The game's lines cannot be kept. What somebody said is not text in them: it is a reference the game
--   fills in as it draws the line (ClubDocumentation.lua: a message's content is a "kstringClubMessage"),
--   and a reference the game has let go of is drawn as "Unknown". With the guild window shut for a
--   while, every line the page had copied read "[name]: Unknown" until the player had been to the game's
--   own Chat tab and back (the owner's screenshot, 2026-11-13: "ikke åpnet tabben på en stund ... scrollet
--   opp og alt ble unknown"). The window lets go as it shuts - CommunitiesFrameMixin:OnHide calls
--   C_Club.Flush and takes its eye off the chat stream - which fits; that it is this, and how soon after,
--   was not measured. So the game's lines are read only between its chat view filling itself and the
--   window shutting (fresh), and the page's chat is written again each time the window opens and each
--   time that view fills itself. What we heard ourselves is text, and stays.
--
-- Everything is laid OVER the game's window. Nothing of the game's is called to switch view, and nothing
-- of it is hidden or moved:
--   - Our tab is a button of ours under the game's own. Choosing it never asks the game for a view:
--     CommunitiesFrame:SetDisplayMode run from an addon leaves the window's state written by us, and the
--     roster's own C_GuildInfo.GuildRoster() - a call only the game may make - would be refused the next
--     time the player clicked Roster.
--   - The game's view wins: a click on one of its tabs, or its view changing by any other road, puts
--     our page away.
--   - No secure button of ours hangs on the window: one would make the whole guild window protected, and
--     then any addon could stop it opening or closing in a fight.
--   - Nothing of the chat's is written: not ChatFrameUtil's focus override (a global the game reads when
--     you open chat), not its settings. What the game's chat frame shows is only read.
--   - One thing of the game's is touched, and only its alpha: the chat's scroll bar stands on a strata
--     of its own (CommunitiesChatFrame.xml: frameStrata HIGH), over anything of ours, so it is made
--     see-through while the page is up and put back when it goes.
-- Whether the club chosen is the guild is read off the game's own Info tab, which it shows for the guild
-- alone (CommunitiesFrameMixin:UpdateCommunitiesTabs). C_Club.GetClubInfo would say it outright, but it
-- answers in secrets while chat is locked down (ClubDocumentation.lua: SecretInChatMessagingLockdown).
local ADDON, GK = ...
local LIB = LibStub("LibForever-1.0")
local Secret = GK.Secret

local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"

-- The game's tabs down the window's right edge, top to bottom (CommunitiesFrame.xml).
local THEIR_TABS = { "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab", "GuildPreferredPlaySettingsTab" }

-- The page, in the window's own units. The window is 814 x 426 (CommunitiesFrame.xml, the same file in
-- builds 69876 and 70888) and its frame's background runs from 2,-21 to -2,2 (ButtonFrameBaseTemplate).
-- The frame's bronze edge is some five units deep on every side and its title bar ends 21 down - measured
-- in the owner's screenshots (2026-11-13, 1.2 pixels to a unit) - so the page lies a hair inside that:
-- 803 x 399, with a pixel of the dark behind it showing as a shadow all round.
local PAGE = { 6, -22, -5, 5 }
local PAGE_W, PAGE_H = 814 - PAGE[1] + PAGE[3], 426 + PAGE[2] - PAGE[4]
-- Over everything the window holds: its chat box is at level 1200, a member's details at 1000, the title
-- 510, the crest 300 and 400 (CommunitiesFrame.xml, PortraitFrameBaseTemplate). The game's tabs are at
-- 510 too, but outside the window's edge, where the page does not reach.
local LEVEL = 1300
-- The crest is 60 across with its middle 25,-22 from the window's corner (PortraitOverlay), the portrait
-- under it 62 across around 26,-24 (PortraitContainer). His face in its ring covers both.
local MEDAL, MEDAL_X, MEDAL_Y = 64, 26, -24

-- Four panels under the heading: you; the kill orders over guild chat; the leaderboard.
local TOP, FOOT = -50, 10                         -- where the panels start, and what is left under them
local TALL = PAGE_H + TOP - FOOT                  -- 339: a panel the whole height
local YOU = { 10, TOP, 190, TALL }
local KILLS = { 208, TOP, 384, 108 }
local CHAT = { 208, TOP - 116, 384, TALL - 116 }
local BOARD_AT = { 600, TOP, 193, TALL }
local BAND_H = 21                                 -- the leather band a panel's name is on
local ORDERS, ORDER_H = 3, 26
local NEWS, NEWS_H = 7, 18
local BOARD, BOARD_H = 15, 20
local CHAT_KEEP = 60              -- lines of guild chat kept, in memory and from one session to the next
local CHAT_SHOWN = 200            -- lines the chat holds on the page, with what the game's own view had
local CHAT_LONGEST = 500          -- a line's text is cut here: the game's own limit is half of it

-- A panel's own colours, the same in both skins: dark leather with a gold line under it, the name in
-- cream. (What is written ON a panel takes the skin's ink, through GK.Ink.)
local LEATHER = { 0.15, 0.085, 0.045 }
local GOLD_LINE = { 0.72, 0.57, 0.25 }
local CREAM, CREAM_DIM, GOLD = { 0.94, 0.86, 0.68 }, { 0.79, 0.71, 0.54 }, { 1, 0.82, 0 }
local GREY = { 0.6, 0.6, 0.6 }

local host                        -- the guild window, once it is there
local tab, view                   -- our tab, and the page it shows
local chosen = false              -- our tab is the one chosen
local seenMode                    -- the game's view when we last looked
local weekly = true               -- the leaderboard: this week's, or all time's
local lines = {}                  -- guild chat heard: { t, a (who), f (who, with realm), c (class), m (what
                                  -- they said), l (the game's line number, this session only) }, oldest first
local unseen = 0                  -- how many of the newest lines heard the game's own chat view cannot hold
local dimmed                      -- the game's chat scroll bar, while we hold it see-through
local fresh = false               -- the game's chat view has filled itself since the guild window last shut:
                                  -- only then are its lines read (the note on "Unknown" at the top)
local written = false             -- the page's chat has been written since the guild window last opened

local function Theirs(fn)
    for _, k in ipairs(THEIR_TABS) do
        local t = host[k]
        if type(t) == "table" then fn(t, k) end
    end
end

local function Mode()
    return host.GetDisplayMode and host:GetDisplayMode() or nil
end

-- ---------------------------------------------------------------------------
-- Guild chat: what was said, and how a line is written
-- ---------------------------------------------------------------------------
--- The colour guild chat is written in: the game's own, as the player has set it.
local function GuildColour()
    local types = _G.ChatTypeInfo
    local c = type(types) == "table" and types.GUILD or nil
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    return 0.25, 1, 0.25
end

--- The time before a line, when the player has the game put one there (its showTimestamps setting, read
--- and never written); else nothing.
local function Stamp(t)
    local get = C_CVar and C_CVar.GetCVar
    local fmt = get and get("showTimestamps")
    if type(fmt) ~= "string" or fmt == "" or fmt == "none" then return "" end
    local ok, s = pcall(date, fmt, t)
    return ok and type(s) == "string" and s or ""
end

--- One line of guild chat as the page writes it, and the colour its plain words are in. A line the game's
--- own chat view wrote (raw) goes as it is. One we heard is written the way that view writes its own:
--- the name in its class's colour, in brackets, a link to click - left for a whisper, right for the game's
--- menu on that player - then what was said.
function GK.GuildChatLine(e)
    local r, g, b = GuildColour()
    if e.raw then return e.m, r, g, b end
    local class = e.c and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.c]
    local name = e.a
    if class and class.r then
        name = ("|cff%02x%02x%02x%s|r"):format(math.floor(class.r * 255 + 0.5), math.floor(class.g * 255 + 0.5),
            math.floor(class.b * 255 + 0.5), e.a)
    end
    return ("%s|Hplayer:%s:%d:GUILD:|h[%s]|h: %s"):format(Stamp(e.t), e.f or e.a, e.l or 0, name, e.m), r, g, b
end

local function ShowLine(e)
    view.chat:AddMessage(GK.GuildChatLine(e))
end

--- What the game's own chat view holds of guild chat, the oldest first: { t, m, raw }. Its message frame
--- keeps each line with the message's id (CommunitiesChatMixin:AddMessage: text, r, g, b, club, stream,
--- id), so a line with an id is something somebody said - not a date, not the guild's message of the
--- day - and the id says when. Only lines in guild chat's own colour: the officers' stream, or another
--- club's chat still in the frame, is in another. Read, never asked for: nothing when that view has not
--- been up, or while the game holds chat secret.
local function TheirLines()
    local out = {}
    local frame = type(host.Chat) == "table" and host.Chat.MessageFrame or nil
    if type(frame) ~= "table" or not (frame.GetNumMessages and frame.GetMessageInfo) then return out end
    local ok, n = pcall(frame.GetNumMessages, frame)
    if not ok or type(n) ~= "number" or Secret(n) or n < 1 then return out end
    local gr, gg, gb = GuildColour()
    local function Near(a, b2) return type(a) == "number" and not Secret(a) and math.abs(a - b2) < 0.02 end
    for i = 1, n do
        local got, text, r, g, b, _, _, id = pcall(frame.GetMessageInfo, frame, i)
        if got and type(text) == "string" and not Secret(text) and type(id) == "table" and type(id.epoch) == "number"
                and not Secret(id.epoch) and Near(r, gr) and Near(g, gg) and Near(b, gb) then
            local at = type(id.position) == "number" and not Secret(id.position) and id.position or 0
            out[#out + 1] = { t = id.epoch / 1000000, p = at, m = text, raw = true }
        end
    end
    -- by the ids, whichever end the frame counts from: when it was said, then its place in that moment
    table.sort(out, function(a, b2)
        if a.t ~= b2.t then return a.t < b2.t end
        return a.p < b2.p
    end)
    return out
end

--- Whether the game's own chat view is up, and so hearing what is said.
local function TheirChatUp()
    local chat = host and host.Chat
    return type(chat) == "table" and chat.IsVisible ~= nil and chat:IsVisible() and true or false
end

--- The chat written afresh: each time the page comes up, the guild window opens, or the game's own chat
--- view fills itself. When that view holds guild chat that can still be read (fresh): its lines, then
--- those of ours it cannot have - what was said since it went away (unseen). When it holds none - it has
--- not been up since the window opened, or it is on the officers' chat - everything we heard and kept.
--- keep: written again under a reader, it stays where they had scrolled it to.
local function Rewrite(keep)
    local theirs = fresh and TheirLines() or {}
    local chat = view.chat
    local at = keep and chat.GetScrollOffset and chat:GetScrollOffset() or nil
    written = true
    chat:Clear()
    local n
    if #theirs > 0 then
        for i = math.max(1, #theirs - CHAT_SHOWN + 1), #theirs do ShowLine(theirs[i]) end
        for i = math.max(1, #lines - unseen + 1), #lines do ShowLine(lines[i]) end
        n = #theirs + unseen
    else
        for _, e in ipairs(lines) do ShowLine(e) end
        n = #lines
    end
    view.none:SetShown(n == 0)
    if type(at) == "number" and at > 0 and chat.SetScrollOffset then chat:SetScrollOffset(at) end
end

--- A line of guild chat, heard. Kept whether or not the page is up, so it has something to show when it
--- opens. While the game holds chat back its words and names are secrets, and those lines are left out.
local function OnGuildChat(text, sender, _, _, _, _, _, _, _, _, lineID, guid)
    if GK.db.guildButton == false then return end
    if Secret(text) or Secret(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
    local class
    if type(guid) == "string" and not Secret(guid) and GetPlayerInfoByGUID then
        local ok, _, token = pcall(GetPlayerInfoByGUID, guid)
        if ok and type(token) == "string" and not Secret(token) then class = token end
    end
    -- the sender comes with their realm after a hyphen: the name is shown without it, and kept with it
    -- for the whisper a click on the name starts. The server's clock, as the game's own lines are timed.
    local e = { t = GetServerTime and GetServerTime() or time(), a = sender:match("^[^%-]+") or sender, f = sender,
        c = class, m = text:sub(1, CHAT_LONGEST), l = type(lineID) == "number" and not Secret(lineID) and lineID or nil }
    lines[#lines + 1] = e
    while #lines > CHAT_KEEP do table.remove(lines, 1) end
    -- up, the game's own chat view takes this line in too, and holds every line before it; away, this is
    -- one more it has not got
    unseen = TheirChatUp() and 0 or math.min(unseen + 1, #lines)
    -- on the page at once while our tab is the chosen one, the window open or not; else when it next opens
    if view and view:IsShown() then
        ShowLine(e)
        view.none:Hide()
    end
end

--- What was kept from the last session, as far as it is what we wrote there: the saved file is data.
local function KeptLines()
    local kept = {}
    local saved = GK.char.guildChat
    if type(saved) == "table" then
        for _, e in ipairs(saved) do
            if type(e) == "table" and type(e.t) == "number" and type(e.a) == "string" and type(e.m) == "string"
                    and #e.a <= 64 and #e.m <= CHAT_LONGEST and (e.c == nil or type(e.c) == "string")
                    and (e.f == nil or (type(e.f) == "string" and #e.f <= 96)) then
                kept[#kept + 1] = { t = e.t, a = e.a, f = e.f, c = e.c, m = e.m }
            end
        end
    end
    while #kept > CHAT_KEEP do table.remove(kept, 1) end
    return kept
end

--- What you wrote, to guild chat. Chat sent as the player, so: only from Enter in the page's own box -
--- the player's keypress - and never a slash command, which the game's own chat box is for. Returns
--- true when it went, else false and a word on why.
function GK.SayInGuild(text)
    if type(text) ~= "string" then return false end
    text = text:match("^%s*(.-)%s*$")
    if text == "" then return false end
    if text:sub(1, 1) == "/" then return false, "Slash commands go in the game's own chat box." end
    if not IsInGuild() then return false, "You are not in a guild." end
    if LIB.InChatLockdown() then return false, "The game is holding chat back right now." end
    local may = C_GuildInfo and C_GuildInfo.CanSpeakInGuildChat
    if may then
        local ok, can = pcall(may)
        if ok and can == false then return false, "Your rank may not speak in guild chat." end
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return false, "The game would not send that." end
    if pcall(send, text, "GUILD") then return true end
    return false, "The game would not send that."
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------
local function Text(parent, colour, font, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    GK.Ink(fs, colour, font, size)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Colour(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

local function Plural(n, word) return ("%d %s%s"):format(n, word, n == 1 and "" or "s") end

--- A guildie's count as the leaderboard says it under the mouse: "This week: 13 kills, 12 deaths, 21
--- assists". The assists only for one whose Grudgekeeper counts them.
function GK.BoardLine(r, week)
    local parts = { Plural(r.k or 0, "kill"), Plural(r.d or 0, "death") }
    if r.a then parts[#parts + 1] = Plural(r.a, "assist") end
    return (week and "This week: " or "All time: ") .. table.concat(parts, ", ")
end

--- A ruled line, w long from x,y: down the page with tall, else across it.
local function Rule(parent, x, y, w, tall, alpha)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", x, y)
    rule:SetSize(tall and 1 or w, tall or 1)
    GK.Paint(rule, "rule", alpha)
    return rule
end

--- Four lines round a frame, inset from its edge, in one colour.
local function Outline(f, inset, r, g, b, a)
    local function Line()
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a)
        return t
    end
    local top, foot, left, right = Line(), Line(), Line(), Line()
    top:SetPoint("TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", -inset, -inset)
    top:SetHeight(1)
    foot:SetPoint("BOTTOMLEFT", inset, inset)
    foot:SetPoint("BOTTOMRIGHT", -inset, inset)
    foot:SetHeight(1)
    left:SetPoint("TOPLEFT", inset, -inset)
    left:SetPoint("BOTTOMLEFT", inset, inset)
    left:SetWidth(1)
    right:SetPoint("TOPRIGHT", -inset, -inset)
    right:SetPoint("BOTTOMRIGHT", -inset, inset)
    right:SetWidth(1)
end

--- A panel of the page: a dark line round it and a light one just inside, as if pressed into the paper,
--- and a leather band across its top with its name on, and room at the band's other end for a word
--- more (p.meta). at: { x, y, w, h } on the page. dark: a chat's panel, near black with a bronze line.
local function Panel(at, name, dark)
    local p = CreateFrame("Frame", nil, view)
    p:SetPoint("TOPLEFT", at[1], at[2])
    p:SetSize(at[3], at[4])
    local body = p:CreateTexture(nil, "BACKGROUND")
    body:SetAllPoints()
    if dark then
        body:SetColorTexture(0.03, 0.024, 0.02, 0.94)
        Outline(p, 0, 0.04, 0.03, 0.02, 1)
        Outline(p, 1, 0.54, 0.435, 0.227, 0.9)
    else
        GK.Paint(body, "stripe")
        Outline(p, 0, 0.16, 0.09, 0.04, 0.8)
        Outline(p, 1, 1, 0.93, 0.75, 0.22)
    end
    local band = p:CreateTexture(nil, "ARTWORK")
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetPoint("TOPRIGHT", -1, -1)
    band:SetHeight(BAND_H)
    band:SetColorTexture(LEATHER[1], LEATHER[2], LEATHER[3], 0.93)
    local line = p:CreateTexture(nil, "ARTWORK", nil, 1)
    line:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
    line:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(GOLD_LINE[1], GOLD_LINE[2], GOLD_LINE[3], 1)
    p.title = Text(p, CREAM, GK.TITLE_FONT, 13)
    p.title:SetPoint("TOPLEFT", 8, -5)
    p.title:SetText(name or "")
    p.meta = Text(p, CREAM_DIM, GK.TEXT_FONT, 10, "RIGHT")
    p.meta:SetPoint("TOPRIGHT", -8, -7)
    return p
end

--- A small heading inside a panel, in the middle of its width with a short ruled line at either side.
local function SubHead(parent, x, y, w, words)
    local fs = Text(parent, GK.FADED, GK.TEXT_FONT, 10, "CENTER")
    fs:SetPoint("TOP", parent, "TOPLEFT", x + w / 2, y)
    fs:SetText(words)
    Rule(parent, x, y - 6, 46)
    Rule(parent, x + w - 46, y - 6, 46)
end

--- A row to click, tinted under the mouse.
local function ClickRow(parent, h, onClick)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(h)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    view.washes[#view.washes + 1] = { hover, 0.12 }
    row:SetScript("OnClick", onClick)
    return row
end

--- The page's paper: the ledger's parchment in its tone, or in classic the game's own bronze panel.
local function Dress()
    local bg = view.bg
    if GK.Classic() then
        bg:SetAtlas("heavybronze-frame-background")
        bg:SetDesaturation(0)
        bg:SetVertexColor(1, 1, 1)
    else
        bg:SetTexture(MEDIA .. "sheet_wide")
        bg:SetTexCoord(0, 1, 0, 1)      -- the sheet is 2 to 1, and so is the page: nothing is squeezed
        GK.Tone(bg)
    end
    for _, w in ipairs(view.washes) do GK.Wash(w[1], w[2]) end
end

local Fill      -- defined below; the page's buttons call it

local function BuildYou()
    local p = Panel(YOU)
    local w = YOU[3] - 18               -- what is written keeps nine clear of the panel's lines
    local you = { name = p.title }
    you.title = Text(p, GK.INK, GK.TEXT_FONT, 12)
    you.title:SetPoint("TOPLEFT", 9, -29)
    -- what the title rests on, at the line's other end
    you.total = Text(p, GK.FADED, GK.TEXT_FONT, 10, "RIGHT")
    you.total:SetPoint("TOPRIGHT", -9, -31)
    -- how far you are to the next title
    local track = p:CreateTexture(nil, "ARTWORK")
    track:SetPoint("TOPLEFT", 9, -47)
    track:SetSize(w, 7)
    GK.Paint(track, "rule", 0.45)
    you.bar = p:CreateTexture(nil, "ARTWORK", nil, 1)
    you.bar:SetPoint("TOPLEFT", track, "TOPLEFT")
    you.bar:SetHeight(7)
    GK.Paint(you.bar, "blood")
    you.barW = w
    you.next = Text(p, GK.FADED, GK.TEXT_FONT, 10)
    you.next:SetPoint("TOPLEFT", 9, -58)

    SubHead(p, 9, -80, w, "THIS WEEK")
    you.nums, you.labels = {}, {}
    for i, label in ipairs({ "points", "kills", "deaths", "assists", "in a row", "" }) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local n = Text(p, i == 5 and GK.BLOOD or GK.INK, GK.TEXT_FONT, 18)
        n:SetPoint("TOPLEFT", 12 + col * 58, -98 - row * 42)
        n:SetWidth(56)
        local under = Text(p, GK.FADED, GK.TEXT_FONT, 10)
        under:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -3)
        under:SetText(label)
        you.nums[i], you.labels[i] = n, under
    end

    SubHead(p, 9, -186, w, "LATELY")
    you.news = {}
    for i = 1, NEWS do
        local row = ClickRow(p, NEWS_H, function() GK.OpenLedgerPage("News") end)
        row:SetPoint("TOPLEFT", 9, -203 - (i - 1) * NEWS_H)
        row:SetWidth(w)
        row.when = Text(row, GK.FADED, GK.TEXT_FONT, 10, "RIGHT")
        row.when:SetPoint("RIGHT")
        row.name = Text(row, GK.INK, GK.TEXT_FONT, 11)
        row.name:SetPoint("LEFT")
        row.name:SetPoint("RIGHT", row.when, "LEFT", -6, 0)
        -- the whole line, where the row had room for its short form only
        row:SetScript("OnEnter", function(self)
            if not self.full then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.full, 1, 1, 1, true)
            if self.sub and self.sub ~= "" then GameTooltip:AddLine(self.sub, 0.7, 0.7, 0.7) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        you.news[i] = row
    end
    you.noNews = Text(p, GK.FADED, GK.TEXT_FONT, 11)
    you.noNews:SetPoint("TOPLEFT", 9, -206)
    you.noNews:SetText("Nothing yet.")
    return you
end

local function BuildOrders()
    local p = Panel(KILLS, "Kill orders")
    local orders = { rows = {}, count = p.meta }
    for i = 1, ORDERS do
        local row = ClickRow(p, ORDER_H, function(self)
            if self.orderKey then GK.OpenOrder(self.orderKey) end
        end)
        row:SetPoint("TOPLEFT", 8, -BAND_H - 5 - (i - 1) * ORDER_H)
        row:SetWidth(KILLS[3] - 16)
        if i > 1 then
            local over = Rule(row, 0, 0, KILLS[3] - 16, nil, 0.3)        -- a faint line between two orders
            over:SetPoint("TOPLEFT", 0, 0)
        end
        row.face = GK.MakePortrait(row, 23)
        row.face.tex:SetPoint("LEFT", 2, 0)
        row.pot = Text(row, GK.BLOOD, GK.TEXT_FONT, 12, "RIGHT")
        row.pot:SetPoint("RIGHT", -2, 0)
        row.name = Text(row, GK.INK, GK.TEXT_FONT, 13)
        row.name:SetPoint("LEFT", 30, 0)
        row.name:SetWidth(140)
        row.what = Text(row, GK.FADED, GK.TEXT_FONT, 11)
        row.what:SetPoint("LEFT", 176, 0)
        row.what:SetPoint("RIGHT", row.pot, "LEFT", -8, 0)
        orders.rows[i] = row
    end
    orders.none = Text(p, GK.FADED, GK.TEXT_FONT, 11)
    orders.none:SetPoint("TOPLEFT", 10, -BAND_H - 12)
    orders.none:SetText("No open kill orders.")
    return orders
end

local function BuildChat()
    local p = Panel(CHAT, "Guild chat", true)
    view.online = p.meta
    local gr, gg, gb = GuildColour()
    -- the game's own chat font, so the chat reads as the chat does everywhere else (and writes every
    -- alphabet a name comes in); Grudgekeeper's text face where a client has none
    local function ChatFont(fs)
        if _G.ChatFontNormal and fs.SetFontObject then
            fs:SetFontObject(_G.ChatFontNormal)
        else
            GK.SetFont(fs, GK.TEXT_FONT, 12)
        end
    end
    local chat = CreateFrame("ScrollingMessageFrame", nil, p)
    chat:SetPoint("TOPLEFT", 9, -BAND_H - 6)
    chat:SetPoint("BOTTOMRIGHT", -20, 30)
    ChatFont(chat)
    chat:SetJustifyH("LEFT")
    chat:SetFading(false)
    chat:SetMaxLines(CHAT_SHOWN)
    chat:SetIndentedWordWrap(true)
    chat:SetHyperlinksEnabled(true)
    -- a link under the mouse shows what it is. A click is handed to the game: on a name, a whisper to
    -- them (right-click: the game's menu on that player); on anything else its own tooltip window,
    -- which the game will not open for an addon in a fight.
    -- (a name's link is "player:" in a line of ours and "playerCommunity:" in one the game's view wrote)
    chat:SetScript("OnHyperlinkEnter", function(self, link)
        if type(link) ~= "string" or link:sub(1, 6) == "player" then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then GameTooltip:Show() else GameTooltip:Hide() end
    end)
    chat:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
    chat:SetScript("OnHyperlinkClick", function(_, link, text, button)
        if type(link) ~= "string" or not SetItemRef then return end
        if link:sub(1, 6) == "player" or not InCombatLockdown() then pcall(SetItemRef, link, text, button) end
    end)
    -- the game's own scroll bar, joined to the chat the way the game joins its own; without it the wheel alone
    local bar
    if ScrollUtil and ScrollUtil.InitScrollingMessageFrameWithScrollBar then
        local ok, made = pcall(CreateFrame, "EventFrame", nil, p, "MinimalScrollBar")
        if ok and type(made) == "table" then
            made:SetPoint("TOPRIGHT", -6, -BAND_H - 8)
            made:SetPoint("BOTTOMRIGHT", -6, 32)
            if pcall(ScrollUtil.InitScrollingMessageFrameWithScrollBar, chat, made) then bar = made else made:Hide() end
        end
    end
    if not bar then
        chat:EnableMouseWheel(true)
        chat:SetScript("OnMouseWheel", function(self, delta) self:ScrollByAmount(delta * 3) end)
    end
    view.chat, view.scroll = chat, bar
    view.none = Text(p, GREY, GK.TEXT_FONT, 11)
    view.none:SetPoint("BOTTOMLEFT", 9, 34)
    view.none:SetText("Nobody has said anything since you logged in.")

    -- the line you write on, at the chat's foot: "Guild:" in the chat's colour, as the game's own box says it
    local over = p:CreateTexture(nil, "ARTWORK")
    over:SetPoint("BOTTOMLEFT", 1, 25)
    over:SetPoint("BOTTOMRIGHT", -1, 25)
    over:SetHeight(1)
    over:SetColorTexture(0.54, 0.435, 0.227, 0.9)
    local field = p:CreateTexture(nil, "ARTWORK")
    field:SetPoint("BOTTOMLEFT", 2, 2)
    field:SetPoint("BOTTOMRIGHT", -2, 2)
    field:SetHeight(23)
    field:SetColorTexture(1, 1, 1, 0.04)
    local says = p:CreateFontString(nil, "OVERLAY")
    ChatFont(says)
    says:SetPoint("BOTTOMLEFT", 9, 7)
    says:SetText("Guild:")
    says:SetTextColor(gr, gg, gb)
    local edit = CreateFrame("EditBox", nil, p)
    edit:SetPoint("BOTTOMLEFT", says, "BOTTOMRIGHT", 5, -4)
    edit:SetPoint("BOTTOMRIGHT", -8, 3)
    edit:SetHeight(22)
    edit:SetAutoFocus(false)
    edit:SetMaxBytes(256)
    ChatFont(edit)
    edit:SetTextColor(gr, gg, gb)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self)
        local ok, why = GK.SayInGuild(self:GetText())
        if ok then
            self:SetText("")
        elseif why then
            -- what you wrote stays on the line; why it did not go is said in the chat, as the game says such things
            chat:AddMessage(why, 1, 0.82, 0)
        else
            self:ClearFocus()
        end
    end)
    view.edit = edit
end

local function BuildBoard()
    local p = Panel(BOARD_AT, "Leaderboard")
    local board = { rows = {} }
    -- this week's or all time's: two words on the band to click, the chosen one in gold
    local function Pick(words, isWeek, anchor)
        local b = CreateFrame("Button", nil, p)
        b.text = Text(b, CREAM_DIM, GK.TEXT_FONT, 10, "RIGHT")
        b.text:SetPoint("RIGHT")
        b.text:SetText(words)
        b:SetSize(isWeek and 30 or 40, 16)
        if anchor then
            b:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
        else
            b:SetPoint("TOPRIGHT", -8, -4)
        end
        b:SetScript("OnClick", function()
            weekly = isWeek
            Fill()
        end)
        return b
    end
    board.all = Pick("all time", false)
    board.week = Pick("week", true, board.all)
    for i = 1, BOARD do
        local row = CreateFrame("Frame", nil, p)
        row:SetPoint("TOPLEFT", 2, -BAND_H - 5 - (i - 1) * BOARD_H)
        row:SetSize(BOARD_AT[3] - 4, BOARD_H)
        if i % 2 == 0 then
            local stripe = row:CreateTexture(nil, "BACKGROUND")
            stripe:SetAllPoints()
            GK.Paint(stripe, "stripe")
        end
        row.own = row:CreateTexture(nil, "BACKGROUND", nil, 1)
        row.own:SetAllPoints()
        view.washes[#view.washes + 1] = { row.own, 0.14 }
        row.seal = row:CreateTexture(nil, "ARTWORK")
        row.seal:SetSize(18, 18)
        row.seal:SetPoint("LEFT", 4, 0)
        row.rank = Text(row, GK.FADED, GK.TEXT_FONT, 11, "CENTER")
        row.rank:SetPoint("LEFT", 4, 0)
        row.rank:SetWidth(18)
        row.pts = Text(row, GK.INK, GK.TEXT_FONT, 12, "RIGHT")
        row.pts:SetPoint("RIGHT", -7, 0)
        row.name = Text(row, GK.INK, GK.TEXT_FONT, 12)
        row.name:SetPoint("LEFT", 28, 0)
        row.name:SetPoint("RIGHT", row.pts, "LEFT", -6, 0)
        -- the rest of what the ledger holds on them, under the mouse: the panel has room for their points
        -- only, and a boast or a jibe in the chat beside it wants the kills and the deaths ("se stats og
        -- skryte/mobbe andre samtidig", the owner, 2026-11-13)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if not self.r then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(GK.Show(self.r.who), 1, 1, 1)
            GameTooltip:AddLine(GK.BoardLine(self.r, weekly), 1, 0.82, 0)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        board.rows[i] = row
    end
    return board
end

local function Build()
    view = CreateFrame("Frame", nil, host)
    view:SetPoint("TOPLEFT", host, "TOPLEFT", PAGE[1], PAGE[2])
    view:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", PAGE[3], PAGE[4])
    -- set before anything is made on the page, so every piece is made a step over the one it sits in
    view:SetFrameLevel(host:GetFrameLevel() + LEVEL)
    view:EnableMouse(true)          -- what lies under the page is not clicked through it
    view:Hide()
    view.washes = {}
    local edge = view:CreateTexture(nil, "BACKGROUND")
    edge:SetPoint("TOPLEFT", -1, 1)
    edge:SetPoint("BOTTOMRIGHT", 1, -1)
    edge:SetColorTexture(0, 0, 0, 1)
    view.bg = view:CreateTexture(nil, "BORDER")
    view.bg:SetAllPoints()
    -- the page's own frame: a hairline a little in from its edge, as a ledger's page is ruled
    local W, H = PAGE_W, PAGE_H
    Rule(view, 4, -4, W - 8)
    Rule(view, 4, 5 - H, W - 8)
    Rule(view, 4, -4, 0, H - 8)
    Rule(view, W - 5, -4, 0, H - 8)

    -- his face where the guild's crest is: the window is his while the page is up
    local medal = CreateFrame("Frame", nil, view)
    medal:SetSize(MEDAL, MEDAL)
    medal:SetPoint("CENTER", host, "TOPLEFT", MEDAL_X, MEDAL_Y)
    local face = GK.MakePortrait(medal, MEDAL)
    face.tex:SetPoint("CENTER")
    face.tex:SetTexture(MEDIA .. "portrait")
    face.tex:SetTexCoord(0, 1, 0, 1)
    face.badge:Hide()
    view.medal = medal

    -- the heading: whose ledger, when the week ends, and the way into the whole book
    view.guild = Text(view, GK.BLOOD, GK.TITLE_FONT, 19)
    view.guild:SetPoint("TOPLEFT", 64, -7)
    local under = Text(view, GK.FADED, GK.TEXT_FONT, 11)
    under:SetPoint("TOPLEFT", 65, -29)
    under:SetText("The Grudgekeeper's ledger")
    view.open = CreateFrame("Button", nil, view, "UIPanelButtonTemplate")
    view.open:SetSize(130, 22)
    view.open:SetPoint("TOPRIGHT", -10, -13)
    view.open:SetText("Open the ledger")
    view.open:SetScript("OnClick", function() GK.OpenWindow(2) end)
    view.resets = Text(view, GK.FADED, GK.TEXT_FONT, 11, "RIGHT")
    view.resets:SetPoint("RIGHT", view.open, "LEFT", -12, 0)

    view.you = BuildYou()
    view.orders = BuildOrders()
    BuildChat()
    view.board = BuildBoard()
    -- the page put away while you were writing: the keys go back to the game
    view:SetScript("OnHide", function() view.edit:ClearFocus() end)
end

--- When the week ends, in words; nothing when the game cannot say.
local function WeekEnds()
    local get = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
    local ok, secs = false, nil
    if get then ok, secs = pcall(get) end
    if not (ok and type(secs) == "number" and not Secret(secs) and secs > 0) then return "" end
    local days = math.ceil(secs / 86400)
    return days <= 1 and "the week resets within a day" or ("the week resets in %d days"):format(days)
end

--- How many of the guild are in the game, in words; nothing when the game has not been told yet (the
--- roster is the game's to ask for, and it has asked by the time its guild window is open).
local function Online()
    local ok, total, online = pcall(GetNumGuildMembers)
    if not ok or type(total) ~= "number" or type(online) ~= "number" or Secret(total) or Secret(online) or total < 1 then
        return ""
    end
    return ("%d of %d online"):format(online, total)
end

--- Where a score stands between two titles: the points your title starts at, and the next title's
--- points and name - nil at the highest there is.
local function NextTitle(points)
    local at, nextAt, nextName = 0, nil, nil
    for _, row in ipairs(GK.TITLES) do
        if points >= row[1] then
            at = row[1]
        elseif not nextAt then
            nextAt, nextName = row[1], row[2]
        end
    end
    return at, nextAt, nextName
end

local function Place(list)
    for i, r in ipairs(list) do
        if r.me then return i end
    end
    return #list
end

Fill = function()
    local you, orders, board = view.you, view.orders, view.board
    local me, c, week = LIB.Me(), GK.char, GK.Week()
    local guild = GetGuildInfo and GetGuildInfo("player")
    view.guild:SetText(type(guild) == "string" and not Secret(guild) and guild ~= "" and guild or "Your guild")
    view.resets:SetText(WeekEnds())
    view.online:SetText(Online())

    -- you: your name on the panel's band, a size down when it is longer than the band
    local points = c.points or 0
    GK.Ink(you.name, CREAM, GK.TITLE_FONT, 13)
    you.name:SetText(me and GK.Show(me) or "")
    local wide = you.name.GetUnboundedStringWidth and you.name:GetUnboundedStringWidth() or you.name:GetStringWidth() or 0
    if wide > YOU[3] - 16 then GK.Ink(you.name, CREAM, GK.TITLE_FONT, 11) end
    you.title:SetText(GK.Title(points))
    you.total:SetText(("%d point%s all time"):format(points, points == 1 and "" or "s"))
    local at, nextAt, nextName = NextTitle(points)
    local part = nextAt and (points - at) / (nextAt - at) or 1
    you.bar:SetShown(part > 0)
    you.bar:SetWidth(math.max(1, you.barW * part))
    you.next:SetText(nextAt and ("%d more to %s"):format(nextAt - points, nextName) or "The highest title there is.")
    local thisWeek = GK.Board(true)
    for i, n in ipairs({ week.p or 0, week.k or 0, week.d or 0, week.a or 0, c.spree or 0 }) do
        you.nums[i]:SetText(tostring(n))
    end
    you.nums[6]:SetText("#" .. Place(thisWeek))
    you.labels[6]:SetText(("of %d"):format(#thisWeek))

    local news = GK.LatestNews(NEWS)
    for i, row in ipairs(you.news) do
        local it = news[i]
        row:SetShown(it ~= nil)
        if it then
            row.name:SetText(it.short or it.name)
            row.when:SetText((GK.Ago(it.ts):gsub(" ago$", "")))
            row.full, row.sub = it.name, it.sub
        end
    end
    you.noNews:SetShown(#news == 0)

    -- the kill orders: the biggest bounties first, and how many there are in all
    local open = GK.OpenOrders()
    for i, row in ipairs(orders.rows) do
        local o = open[i]
        row:SetShown(o ~= nil)
        if o then
            local pot = GK.Pot(o)
            row.orderKey = o.key
            row.face:Set({ key = o.n, c = o.c })
            row.name:SetText(GK.Show(o.n))
            row.what:SetText((GK.Describe(o.l, o.c, o.r):gsub("^Level ", "")))
            row.pot:SetText(pot > 0 and GK.MoneyText(pot) or "honour")
            Colour(row.pot, pot > 0 and GK.BLOOD or GK.FADED)
        end
    end
    orders.none:SetShown(#open == 0)
    orders.count:SetText(#open > 0 and ("%d open"):format(#open) or "")

    -- the leaderboard: the top three wear their seals, and you are always on it - in the last row,
    -- when you are further down than the column is long
    local list = weekly and thisWeek or GK.Board(false)
    local place = Place(list)
    for i, row in ipairs(board.rows) do
        local at2 = (i == BOARD and place > BOARD) and place or i
        local r = list[at2]
        row.r = r
        row:SetShown(r ~= nil)
        if r then
            local seal = at2 <= 3 and (r.p or 0) > 0
            row.seal:SetShown(seal)
            if seal then row.seal:SetTexture(MEDIA .. "rank_" .. at2) end
            row.rank:SetShown(not seal)
            row.rank:SetText(tostring(at2))
            row.name:SetText(GK.Show(r.who))
            row.pts:SetText(tostring(r.p))
            row.own:SetShown(r.me == true)
            Colour(row.name, r.me and GK.BLOOD or GK.INK)
            Colour(row.pts, r.me and GK.BLOOD or GK.INK)
        end
    end
    Colour(board.week.text, weekly and GOLD or CREAM_DIM)
    Colour(board.all.text, weekly and CREAM_DIM or GOLD)
end

-- ---------------------------------------------------------------------------
-- The tab
-- ---------------------------------------------------------------------------
--- The game's chat scroll bar see-through while the page is up (it stands over anything of ours), and
--- back as it was when the page goes. Only its alpha: nothing of the game's is hidden, moved or called.
local function Dim(on)
    local bar = type(host.Chat) == "table" and host.Chat.ScrollBar or nil
    if type(bar) ~= "table" or not bar.SetAlpha then return end
    if on and not dimmed then
        bar:SetAlpha(0)
        dimmed = true
    elseif dimmed and not on then
        bar:SetAlpha(1)
        dimmed = false
    end
end

--- The game's own tab for its view checked again, after ours unchecked it: UpdateCommunitiesTabs' rule.
local function Recheck()
    local mode = Mode()
    local applicants = host.IsShowingApplicantList and host:IsShowingApplicantList()
    Theirs(function(t, k)
        t:SetChecked(mode ~= nil and (t.displayMode == mode or (k == "RosterTab" and applicants)) and true or false)
    end)
end

--- Our tab and page as the window now stands. Runs after the game has set its own tabs
--- (UpdateCommunitiesTabs), when the window opens, and after a click on ours or on one of the game's.
local function Update()
    if not tab then return end
    local mode = Mode()
    if mode ~= seenMode then seenMode, chosen = mode, false end     -- the game switched view: its view wins
    -- ours sits under the lowest of the game's tabs that shows; without its Info tab the guild is not
    -- what the window is on (or the window has no tabs up), and ours is not there either
    local last
    Theirs(function(t) if t:IsShown() then last = t end end)
    local info = host.GuildInfoTab
    local show = GK.db.guildButton ~= false and last ~= nil and type(info) == "table" and info:IsShown() and true or false
    if show then
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -20)
    end
    tab:SetShown(show)
    local open = show and chosen
    tab:SetChecked(open)
    if open then
        Theirs(function(t) t:SetChecked(false) end)                 -- one tab chosen at a time: ours
        if not view then Build() end
        Dress()
        Dim(true)
        -- the chat afresh as the page comes up, and as the guild window opens with the page still chosen
        -- (what it showed before the window shut can no longer be read); not again while it stays up
        if not written or not view:IsShown() then Rewrite() end
        view:Show()
        Fill()
    else
        Dim(false)
        if view then view:Hide() end
    end
end

local function Choose()
    seenMode, chosen = Mode(), true
    Update()
end

--- A click on one of the game's tabs: its view, also when the game was on that view already under ours.
local function TheirClick()
    if not chosen then return end
    chosen = false
    Recheck()
    Update()
end

local function MakeTab()
    -- the game's own side tab, which its tabs here are made from (RightSideTabTemplate), so ours wears
    -- what they wear; from the same three textures by hand on a build that has lost the template
    local ok, b = pcall(CreateFrame, "CheckButton", nil, host, "RightSideTabTemplate")
    if not ok or type(b) ~= "table" then
        b = CreateFrame("CheckButton", nil, host)
        b:SetSize(32, 32)
        local back = b:CreateTexture(nil, "BORDER")
        back:SetTexture("Interface\\SpellBook\\SpellBook-SkillLineTab")
        back:SetSize(64, 64)
        back:SetPoint("TOPLEFT", -3, 11)
        b.Icon = b:CreateTexture(nil, "ARTWORK")
        b.Icon:SetSize(30, 30)
        b.Icon:SetPoint("CENTER")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
    end
    if type(b.Icon) == "table" then b.Icon:SetTexture(MEDIA .. "minimap") end
    b:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        Choose()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(GK.TAG)
        GameTooltip:AddLine("Your week, the kill orders, the leaderboard and guild chat on one page.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function Attach()
    if tab then return end
    local f = _G.CommunitiesFrame
    if not (type(f) == "table" and f.GetObjectType and type(f.UpdateCommunitiesTabs) == "function") then return end
    host = f
    tab = MakeTab()
    hooksecurefunc(f, "UpdateCommunitiesTabs", Update)
    f:HookScript("OnShow", Update)
    Theirs(function(t) t:HookScript("OnClick", TheirClick) end)
    -- the game's chat view coming up fills itself with everything said so far: nothing is unseen by it
    if type(f.Chat) == "table" and f.Chat.HookScript then
        f.Chat:HookScript("OnShow", function() unseen = 0 end)
    end
    -- The window shut: the game lets go of what its chat lines said, and the page's copies of them with it.
    -- They are read again once the game's chat view has filled itself afresh, and the page's chat written
    -- with them at once - also when history comes in a moment after the window opened.
    f:HookScript("OnHide", function() fresh, written = false, false end)
    if type(f.Chat) == "table" then
        local function Filled()
            fresh = true
            if view and view:IsVisible() then Rewrite(true) end
        end
        if type(f.Chat.DisplayChat) == "function" then hooksecurefunc(f.Chat, "DisplayChat", Filled) end
        if type(f.Chat.BackfillMessages) == "function" then hooksecurefunc(f.Chat, "BackfillMessages", Filled) end
    end
    -- made while the window stands open on its chat view: that view filled itself as it came up
    fresh = TheirChatUp()
    seenMode = Mode()
    Update()
end

--- After the setting changed (Options: "A tab on the guild window"): the tab there or gone, at once.
function GK.RefreshGuildTab()
    Attach()
    if not tab then return end
    if GK.db.guildButton == false and chosen then
        chosen = false
        Recheck()
    end
    Update()
end

function GK.StartGuildTab()
    -- the lines kept from the last session; the table itself is what is saved, so it is kept as it grows
    lines = KeptLines()
    GK.char.guildChat = lines
    LIB.On("CHAT_MSG_GUILD", OnGuildChat)
    -- the guild window loads on demand: it may be there already, or come later
    Attach()
    LIB.On("ADDON_LOADED", function(name)
        if name == "Blizzard_Communities" then Attach() end
    end)
    -- only while the page is up: a kill, an order or a score from the guild shows on it at once
    LIB.Listen("GRUDGEKEEPER_CHANGED", function()
        if view and view:IsVisible() then Fill() end
    end)
    GK.OnLook(function()
        if not view then return end
        Dress()
        if view:IsShown() then Fill() end
    end)
end
