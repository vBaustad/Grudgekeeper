-- Grudgekeeper - the window (/grudge, the minimap button): the Grudgekeeper's ledger, a sheet of parchment
-- in the game's own frame (SettingsFrameTemplate, which Forever draws in bronze), as Guildhall's window is.
--   The game's tabs under the frame, one per page of GK.LedgerPages: Kill orders, Leaderboard, Death list,
--   Grudges, News and You, then a step apart Shame and Kudos (NotesUI.lua adds those two lists).
--   On the left that page's table; on the right the row you clicked - an enemy's wanted poster, a
--   guildie's record (Profile.lua writes both, for here and the Inspect tab). Whatever opens a player's
--   card from outside the book opens it here (GK.ShowInLedger).
-- The red arrow beside the X (the spells panel's) folds it to one page: the table, and a click on a row
-- turns that page to the row, with Back to return. GK.db.ledgerFolded keeps the choice.
-- Nothing here ever opens by itself: this is where you come to look.
-- It was an open book until 2026-11-06 ("for mye problemer med custom design med boka", the owner): the
-- book's art had no place for the game's X, tabs or buttons, and everything laid on it looked stuck on.
-- The art: Media/sheet_wide and sheet_single (the parchment), rank_1..3 (the top three's seals),
-- portrait_ring.
local ADDON, GK = ...
local LIB = GK.Lib or LibStub("LibForever-1.0")      -- names by themselves (Core.lua, GK.Lib)

local MEDIA = "Interface\\AddOns\\Grudgekeeper\\Media\\"
local TITLE_FONT = "Fonts\\MORPHEUS.ttf"
local TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- The skin's colours and drawing (Core.lua): the same tables every skinned window holds, so a switch of
-- skin redraws all of them.
local INK, FADED, BLOOD = GK.INK, GK.FADED, GK.BLOOD
-- A grudge's score (FillRow): you leading in a dark olive, they in blood, a tie in ink, the other number
-- and the dash in the page's faded ink. As hex for the |c codes inside one string, made at each fill: a
-- skin switch changes the colours in place. A paler brown, "9a8462", left "1 - 0" "nesten usynlig" (the
-- owner, 2026-11-07).
local LEAD_YOU = { 0.31, 0.37, 0.07 }
local function Hex(c)
    local function B(v) return math.floor(v * 255 + 0.5) end
    return ("%02x%02x%02x"):format(B(c[1]), B(c[2]), B(c[3]))
end
local Ink, Paint, Wash = GK.Ink, GK.Paint, GK.Wash

-- The window, in UI units. A page is the list or the card; open, two pages side by side, folded one.
-- Laid out as Guildhall's window is: the sheet where the template's backdrop goes (7,-18 to -3,3), the
-- pages clear of the frame's edges and under its title bar. The pages kept the book's size, so what is
-- written on them sits as it did.
local PAGE_W, PAGE_H = 368, 496
local FX, FY, FGAP, FB = 20, 34, 16, 14
local OPEN = { W = 2 * FX + 2 * PAGE_W + FGAP, H = FY + PAGE_H + FB, x = FX, y = FY }    -- 792 x 544
OPEN.x2 = FX + PAGE_W + FGAP                         -- where the right-hand page starts
local FOLDED = { W = 2 * FX + PAGE_W, H = OPEN.H, x = FX, y = FY, x2 = FX }               -- 408 x 544
-- Rows of 38 with a faint stripe on every other one, as previewed (2026-11-06): 32 with a ruled line under
-- each read as a column of text. Nine fit between the headings and the page arrows at the foot; a page with no
-- heading row has room for ten (ListFrame).
local ROW_H, ROWS = 38, 9
local FACE = 30                                      -- a row's portrait; 26 blended into the page
-- Where a row's name starts: after its face, and on the leaderboard after its rank as well. Every page
-- kept the rank's room until 2026-11-07, which pushed their rows far to the right ("radene er skjøvet
-- veldig til høyre", the owner); the name's heading, at 48, now stands over the name.
local NAME_X, NAME_X_RANKED = 44, 74
-- How far left of a row its tooltip stands: past the window's own edge, which is the list's 20 (FX) and the
-- row's 4 in from it, and a little more.
local TIP_GAP = 28
local LIST_TOP = 96                                  -- the first row, down from the page's top
local TAB_INK_Y, TAB_INK_GAP = 40, 16                -- the ink tabs under the title: how far down, and apart
-- The foot of a list: its rows stop over the page arrows (page.count, 16 up, the arrows round it), all that
-- stands there since Letters and Settings went to the title bar (2026-11-18). A page fits as many rows as reach
-- it. Until 2026-11-20 only the kill orders page had a tenth, by the foot the buttons had kept, and Grudges and
-- You ended with a row's room empty ("det er plass til en linje til at least? ... det er veldig tomt nederst",
-- the owner).
local LIST_FOOT = PAGE_H - 34
local MAX_ROWS = math.floor((LIST_FOOT - (LIST_TOP - 46)) / ROW_H)    -- the most any page fits: no line, no headings
-- the right-hand column stops short of the row's end: folded, room for the » that says a click turns
-- the page (they ran into each other in the preview)
local COL1, COL2, COL_WIDE, COL_RIGHT = 232, 266, 196, PAGE_W - 36
-- A word under the first count (Grudges' "2 days ago" under how often they killed us): the count
-- stands C1_LIFT higher, the word C1_UNDER under the row's middle, as a grudge's "owed 3" under its
-- score. The line under the name stops C1_UNDER_W short of the column's middle: half of "38 days ago" in
-- that type and a gap. Worked out from the type's size, not measured in the game.
local C1_LIFT, C1_UNDER, C1_UNDER_W = 5, 10, 36
local SCORE_X = COL_RIGHT - 34                       -- the middle of a grudge's score ("0 - 1")
-- The leaderboard's three counts, K, D and A, a little closer than COL1 and COL2: at 34 apart the third
-- left a four-figure score no room. The name keeps 116, and a longer one steps down a size first.
local BOARD_K, BOARD_D, BOARD_A = 210, 240, 270
-- Heading buttons a page has: the leaderboard's six (#, Name, K, D, A, Points). Five there were, and the A
-- column pushed Points off the end - its heading went missing (2026-11-12).
local HEADS = 6
-- How far a list runs: its first LIST_MAX rows, about three pages. A list ran to every row the store holds - 200 on Most wanted, 500 on the
-- leaderboard: "vi kan ikke ha evig pages heller. på most wanted og alt mulig" (the owner, 2026-11-10).
-- Only the pages stop: the store keeps what it kept, and posters, tooltips and warnings know everyone.
-- The kill orders page is the one list that runs to its end (OrderItems).
local LIST_MAX = 25
GK.LIST_MAX = LIST_MAX       -- for the pages other files add (NotesUI.lua)
local TAB_GAP, GROUP_GAP = 3, 16                     -- between two tabs; and before the friendly pages, or Friends
-- How far up the tabs go, behind the frame's bottom edge. The game's own windows put them 2 up and over
-- the edge, which here read as buttons set under the book: "føler ikke tabsene henger helt ordentlig på?"
-- (the owner, 2026-11-08). The edge is 11 deep (rows 30-40 of the owner's screenshot). 10 up hid their tops
-- behind it and they hung from the book, but short: "de er litt lave, trenger ikke være så langt inn under"
-- (the owner, the same day). 6 up, half way.
local TAB_TUCK = 6
-- They are drawn in Forever's heavy tab art, not the game's bottom tabs: those (uiframe-tab-*-c60) have one
-- thin line where the frame's edge has a double one about 6 deep - "de ikke er like tykke i border som selve
-- ramma" (the owner, 2026-11-08). ui-frame-metal-Tabs-c60 is 60 x 60 (and a 2x copy): the same double
-- line, about 6 deep, square on its left side, its right corners cut off (looked at in the art, 2026-11-08).
-- Turned a quarter clockwise it is a bottom tab - the square side meets the frame, the cut corners hang
-- below. HEAVY_CUT leaves off the band along its square side, as the frame's edge is where a tab starts;
-- HEAVY_CORNER keeps the cut corners whole at any width. Its dark ground (-BG-) comes with it, and its
-- yellow glow (-Glow-), full on the chosen tab and fainter on hover (HeavyTab). The glow fades in from the
-- square side as far as 17 (GLOW_CUT): cut at 8 like the line, the rest drew a yellow bar under the edge.
local HEAVY = { ground = "ui-frame-metal-Tabs-BG-c60", edge = "ui-frame-metal-Tabs-c60", glow = "ui-frame-metal-Tabs-Glow-c60" }
local HEAVY_SIZE, HEAVY_CUT, GLOW_CUT, HEAVY_CORNER, HOVER_ALPHA = 60, 8, 17, 16, 0.45
local GLOW_FADE = 6          -- how far down the glow comes in from nothing, below the frame's edge (HeavyTab)
local TAB_H, TAB_H_ON = 36, 42      -- the tab's art, and the chosen tab's, longer: the game's own two heights
-- The text in the middle of what shows between the frame's edge and the art's bottom line, and clear of
-- its side lines and glow: "text er litt overlap med gløden og kantene på knappene" (the owner,
-- 2026-11-08). Measured on that screenshot: the inside runs from 4 to 27 down a tab (to 33 down the
-- chosen one, 6 longer), and the words' capitals stood at 14 to 21 (17 to 24 chosen), their tails to 24
-- (27): 3 up puts as much room over the capitals as under the tails. The game's
-- own tab puts its words 10 from each side (TAB_SIDES_PADDING 20 for both, SharedUIPanelTemplates.lua),
-- which in this art is on its 2-to-8 line and in the 8-to-17 glow: TAB_PAD more gives 16 a side.
local TAB_TEXT_Y, TAB_TEXT_Y_ON = 1, -2
local TAB_PAD = 12
-- Folded the tabs hang down the frame's right side instead, the art as it lies: under the one page they
-- were cut to "Lead..." and "Most..." ("collapsed så legger vi tabs på høyre side nedover isteden", the
-- owner, 2026-11-10). A side tab is as deep as a bottom tab is tall - the button's own 32
-- (PanelTabButtonTemplate, SharedUIPanelTemplates.xml) - so what is on it sits as far out from the edge.
-- The first starts under the title bar, level with the page. On each an icon, its name on the mouse: its
-- words turned to run down it were still cut ("Leade...") and hard to read ("teksten er for lav. men
-- kanskje vi kunne funnet noe gode ikoner isteden?", the owner, the same day). Long enough for the art's two
-- corners (16 each) and the icon between them.
local TAB_BUTTON_H, SIDE_TOP, SIDE_LEN, TAB_ICON = 32, 34, 46, 22
-- The icons: the ledger's own marks where it has one - the skull seal an order puts over a nameplate, the
-- gold seal the leaderboard's first wears - and the game's elsewhere, cut round like them. Every one is in
-- Forever's live build 70790 (manifestinterfacedata). A page another file adds brings its own (def.icon).
local ICONS = "Interface\\Icons\\"
local SWAP_ICON = { Friends = ICONS .. "INV_Misc_GroupNeedMore", Enemies = MEDIA .. "mark" }

--- Where a page's list starts, down from the page's top, and how many rows of it fit over the foot. Under
--- the heading row; without one, where the headings would be (the Grudges page's list "trenger ikke bli
--- dytta så langt inn", the owner, 2026-11-07); and with no line under the title either - no sub, no
--- links - right under the title. Rows to the foot (LIST_FOOT): nine under a heading row, ten without one. The
--- kill orders page has neither line nor headings: its line said
--- how many orders are open and your points and place, its headings sorted a list that is in order, and
--- with Only mine they were "dead space med ting som ikke trengs og bare tar opp plass" (the owner,
--- 2026-11-14).
--- A page's column headings, and its own action: a list or a table, or a function for the view it shows
--- (Grudges' views have each their own).
local function Headings(def)
    if type(def.headings) == "function" then return def.headings() end
    return def.headings or {}
end
local function Action(def)
    if type(def.add) == "function" then return def.add() end
    return def.add
end

--- line: something stands on the line under the title this time - words, tabs or links.
local function ListFrame(def, line)
    local top = LIST_TOP
    if #Headings(def) == 0 then
        top = top - 30
        if not line then top = top - 16 end
    end
    return top, math.floor((LIST_FOOT - top) / ROW_H)
end

--- Where each page of a list starts (0-based offsets into it): perPage rows a page (ROWS, where a page does
--- not say), but a heading is never the last row of a page - it goes over to the next one with its rows. Turning a page goes from one
--- start to the next, so a page never shows what the page before showed: after 1-9 of 10 the last page
--- used to be 2-10, the list pushed back to fill it ("page turning burde jo ikke vise de samme", the
--- owner, 2026-11-07).
function GK.PageStarts(items, perPage)
    perPage = perPage or ROWS
    local starts, at = { 0 }, 0
    while at + perPage < #items do
        local nextAt = at + perPage
        if items[nextAt] and items[nextAt].header and nextAt - 1 > at then nextAt = nextAt - 1 end
        starts[#starts + 1] = nextAt
        at = nextAt
    end
    return starts
end

--- The page after (dir 1) or before (dir -1) the one that starts at `offset`; the same one at either end.
function GK.TurnPage(starts, offset, dir)
    starts = starts or { 0 }
    local at = 1
    for i, s in ipairs(starts) do
        if s <= offset then at = i end
    end
    return starts[math.max(1, math.min(#starts, at + dir))]
end

local win
local tab = 1
local weekly = true          -- the leaderboard shows this week until you ask for all time
local offset = 0             -- the first row shown, per the list as it stands
local selected = {}          -- [tab] = the key of the row whose detail is shown
-- A card opened from outside the book (GK.ShowInLedger) for someone no page has a row for: a select spec,
-- shown on the right over whatever page is up, with no row marked, until a row or a tab is chosen.
local pinned
local turned = false         -- folded: the page shows the detail, not the list
-- The settings (Options.lua) are a page of the ledger since 2026-11-18, two pages wide over the list and the
-- card, with the tabs left under the frame to go back by. A window of their own took the ledger's place,
-- and its tabs with it: "går vi inn i settings så er det litt awkward at alt blir borte av tabs ... la
-- tabs være der så man kan trykke på de for å komme tilbake isteden" (the owner).
local settingsOn = false
local SetSettings            -- made with the tabs, below

--- The book's art toned down: the generated parchment was "veldig bright" in the game. A part
--- desaturation and a darker vertex colour, the same on the book, the sheets and the leather tabs, so
--- nothing stands out brighter than the rest (previewed 2026-11-05: 0.45/0.78 went grey).
local TONE_D, TONE_M = 0.30, 0.86
local function Tone(tex, r, g, b)
    tex:SetDesaturation(TONE_D)
    tex:SetVertexColor((r or 1) * TONE_M, (g or 1) * TONE_M, (b or 1) * TONE_M)
end

local function Plural(n, word) return ("%d %s%s"):format(n, word, n == 1 and "" or "s") end

--- A text's own width, not cut to its box: GetStringWidth on a one-line string with a width set can
--- answer the box, which would always "fit".
local function TextWidth(fs)
    local w = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()
    return w or fs:GetStringWidth() or 0
end

-- folded, but never under the settings: they need both pages
local function Folded() return GK.db and GK.db.ledgerFolded == true and not settingsOn end

-- ---------------------------------------------------------------------------
-- What each page lists. An item: { key, name, short, shortest, painted, class, sub, rank, seal, face = { key, rf, sx, c }, c1, c2, wide,
-- right, rightColour, faded, mine, own, ts, votes, header, select = { kind = "poster", t, order } or
-- { kind = "record", key } or { kind = "card", make } }
-- mine tints the row; own only says the row is yours, for Only mine; votes, bounty, you and they are the
-- numbers a column heading sorts by (GK.SortItems), ts when it happened. past: a row about something
-- over that is not faded - never the row a page chooses by itself (Chosen). ink: the name in this colour.
-- class: the row's name is one player's, of this class - in its colour in the Classic skin (GK.ClassInk).
-- painted: { name, short, shortest } with each player's name in its class's colour, for a line with names
-- in it, made only in the Classic skin.
-- ---------------------------------------------------------------------------
local STATE_WORD = { d = "FULFILLED", p = "PAID", x = "WITHDRAWN", e = "EXPIRED" }

local function PosterSpec(key, x, order)
    return { kind = "poster", order = order,
        t = { key = key, guid = x and x.guid, c = x and x.c, r = x and x.r, l = x and x.l } }
end

--- What they are, short, for after a row's name: "35 Orc Rogue". nil when we know nothing.
local function Short(l, c, r)
    local s = GK.Describe(l, c, r):gsub("^Level ", "")
    return s ~= "" and s or nil
end

-- The views of the pages that have more than one (ink tabs, the owner's pick from the mockup, 2026-11-18). Grudges
-- took Most wanted's place and name on 2026-11-22, when the Death list became a page of its own: "most wanted
-- høres jo nesten likt ut. er det andre bedre navn for den?" (the owner). What the game found, three ways: who
-- killed you ("me"), who killed the guild ("killed"), and the guild on watch with the versus page ("guild").
-- The News: "All" and "Kill orders". As chosen, until the next login.
local grudgesView, newsView = "me", "all"
-- What draws the versus page and picks each side's colour: filled in further down, once Ink and the portraits
-- are there.
local Versus = {}

--- The view Grudges shows, and the guild tracked, if one is. Versus is there with none as well, and says how
--- one gets tracked ("tabben om man ikke tracker noe kan være noe default", the owner, 2026-11-22).
local function GrudgesView()
    return grudgesView, GK.WatchedGuild and GK.WatchedGuild()
end

--- Is Grudges showing the guild on watch?
local function GuildView()
    local view, guild = GrudgesView()
    return view == "guild", guild
end

--- Does Only mine show, and count, on this page as it stands? Not on Grudges' first two views: Killed me is
--- what it was for there, and a tick nobody can see must hide nothing.
local function MineShown(def)
    if not (def and def.sortable == true) then return false end
    if def.onlyMine then return def.onlyMine() and true or false end
    return true
end

--- One order's row on the page, open or closed.
local function OrderRow(o, me)
    local pot, backers = GK.Pot(o)
    local it = { key = "o:" .. o.key, name = GK.Show(o.n), class = o.c, face = { key = o.n, c = o.c },
        select = PosterSpec(o.n, o, o),
        desc = Short(o.l, o.c, o.r), ts = o.t }
    if o.state == "o" then
        it.right = pot > 0 and GK.Coins(pot) or ""
        -- your own order by you, as its card says: "by Critical Mango" over a card's "Posted by You"
        local byMe = o.by == me
        local bits = { o.auto and (byMe and "by your death" or ("by %s's death"):format(GK.Show(o.by)))
            or ("by " .. (byMe and "you" or GK.Show(o.by))) }
        if backers > 0 then bits[#bits + 1] = Plural(backers, "backer") end
        -- where a guildie saw them last: what a hunter needs, and every guildie is one
        if o.seen then
            bits[#bits + 1] = o.seen.z and ("seen in %s, %s"):format(o.seen.z, GK.Ago(o.seen.t))
                or ("seen " .. GK.Ago(o.seen.t))
        end
        it.sub = table.concat(bits, " - ")
    else
        it.faded, it.right, it.rightColour = true, STATE_WORD[o.state] or "", BLOOD
        it.sub = (o.doneBy and ("by " .. (o.doneBy == me and "you" or GK.Show(o.doneBy)) .. " - ") or "")
            .. GK.Ago(o.paidAt or o.doneAt)
    end
    return it
end

--- How long ago, as short as a column takes it: "now", "12m ago", "5h ago", "4d ago".
local function AgoShort(t)
    local s = math.max(0, time() - (t or time()))
    if s < 60 then return "now" end
    if s < 3600 then return ("%dm ago"):format(math.floor(s / 60)) end
    if s < 86400 then return ("%dh ago"):format(math.floor(s / 3600)) end
    return ("%dd ago"):format(math.floor(s / 86400))
end

--- The kill orders page: the open orders, one list with no headings, as in the owner's mockup (2026-11-18).
--- Those with gold first, the biggest first; a faint line; then those with none, the newest first, with how
--- long ago they were posted where the gold would stand - "enklere å se". It had up to seven headings -
--- Fulfilled lately, Open orders, No bounty folded, Killed us most, Closed orders folded, Marked, Watched
--- guild - and a heading could stand at the foot of one turn of the page with its rows on the next ("de
--- sidene der funker ikke så bra, for det blir rotete"). What a guildie got lately is the News's "Kill
--- orders" view now, Marked is Most wanted's second view, the watched guild a line under the title, and a
--- closed order is in the News and on its own card ("closed ones, no need"). Every open order, not LIST_MAX:
--- the minimap counted 46 and the page showed 25 ("minimap sier 46 stk på kill order men ser bare første 25",
--- the owner, 2026-11-21). An open order is live, someone paid for it and it runs out by itself (a week, two
--- at most off the wire: Guild.lua ORDER_DAYS); ten each a poster at most (MAX_OPEN_PER_POSTER), and the pages turn.
-- The kill orders page's view ("kill orders kan bli 200 folk liksom", the owner, 2026-11-22). Its search went the
-- next day: "det ble lagt til et søkefelt øverst i kill order? det likte jeg ikke. fjern det". One table: the
-- file's locals.
local ordersPage = { view = "all" }

--- Is the order on the page as it stands?
function ordersPage.Has(o, me)
    local view = ordersPage.view
    if view == "gold" and (GK.Pot(o)) <= 0 then return false end
    if view == "mine" and o.by ~= me and not (o.pot and o.pot[me]) then return false end
    return true
end

--- Every order again: for an order opened by its key.
function ordersPage.All()
    ordersPage.view = "all"
end

local function OrderItems()
    local items, me = {}, LIB.Me()
    local gold, free = {}, {}
    for _, o in ipairs(GK.OpenOrders()) do
        if ordersPage.Has(o, me) then
            local list = (GK.Pot(o)) > 0 and gold or free
            list[#list + 1] = o
        end
    end
    for _, o in ipairs(gold) do items[#items + 1] = OrderRow(o, me) end
    -- the newest first (GK.OpenOrders already has them so, among equal pots of none)
    for i, o in ipairs(free) do
        local it = OrderRow(o, me)
        it.right, it.rightColour = AgoShort(o.t), FADED
        it.rule = i == 1 and #gold > 0 or nil
        items[#items + 1] = it
    end
    if ordersPage.view == "gold" then return items, "No open kill order has gold on it. All has the rest." end
    if ordersPage.view == "mine" then return items, "None you posted or put gold on. All has the guild's." end
    return items, "No open kill orders. Post one with Post a kill order, at the top of this page - or right-click "
        .. "an enemy player and pick it there."
end

local function BoardItems()
    local items, listed = {}, {}
    local function Add(r, p, k, d, a, rank)
        rank = rank or #items + 1
        listed[r.who] = true
        items[#items + 1] = { key = "b:" .. r.who, rank = rank, seal = rank <= 3 and p > 0,
            name = GK.Show(r.who), class = r.c, sub = GK.Title(r.total), face = { key = r.who, rf = r.rf, sx = r.sx, c = r.c },
            -- a dash for a guildie whose client sends no assists: a 0 would say they had none
            c1 = tostring(k), c2 = tostring(d), c3 = a and tostring(a) or "-", right = tostring(p), mine = r.me,
            select = { kind = "record", key = r.who } }
    end
    -- the top LIST_MAX, and you under them at your own place if you are further down
    for i, r in ipairs(GK.Board(weekly)) do
        if i <= LIST_MAX or r.me then Add(r, r.p, r.k, r.d, r.a, i) end
    end
    -- This week a short board fills its first page with the rest of the guild, at nothing yet: three rows
    -- and six empty ones under them looked like a list that hadn't loaded ("vis this week leaderboard folk
    -- med 0 poeng også", the owner, 2026-11-07). Only the first page - pages of zeros say nothing - and the
    -- best of all time first. The board itself (GK.Board, your place and "of N") counts only who scored.
    if weekly and #items < ROWS then
        for _, r in ipairs(GK.Board(false)) do
            if #items >= ROWS then break end
            if not listed[r.who] then Add(r, 0, 0, 0, r.a and 0) end
        end
    end
    return items, ""
end

--- A name by its first word: the character's own name, without the surname.
local function FirstName(key)
    local s = GK.Show(key)
    return s:match("^[^ ]+") or s                   -- not %S: see GK.SameName
end

-- The seal a kill order puts over its target's nameplate, in a line of text: on Grudges' Killed us it says an
-- order is out on them.
local ORDER_MARK = ("|T%smark:20:20|t"):format(MEDIA)

--- Whom of the guild an enemy killed, for their row on Grudges' Killed us: you first, then who most often - two
--- of them by first name, with how often when more than once, and how many more there are:
--- "killed you, Kriger x2 +1" (the x a multiplication sign). nil for nobody.
local function Victims(w)
    local list = {}
    for who, n in pairs(w.victims or {}) do
        list[#list + 1] = { who = who, n = tonumber(n) or 1, me = LIB.IsMyStoredName(who) and true or false }
    end
    if #list == 0 then return nil end
    table.sort(list, function(a, b)
        if a.me ~= b.me then return a.me end
        if a.n ~= b.n then return a.n > b.n end
        return a.who < b.who
    end)
    local said = {}
    for i = 1, math.min(2, #list) do
        local v = list[i]
        said[i] = (v.me and "you" or FirstName(v.who)) .. (v.n > 1 and (" \195\151" .. v.n) or "")
    end
    local more = #list - #said
    return "killed " .. table.concat(said, ", ") .. (more > 0 and (" +" .. more) or "")
end

--- Who has killed the guild most, every one of them. A page of its own since 2026-11-07: under the
--- leaderboard they pushed it onto a second page ("en tab med most wanted og en tab med leaderboard",
--- the owner). Each row says whom of us they killed, how often in all with when last under it, and
--- whether a kill order is out on them: its seal, and the gold on it when there is any. The last column
--- was headed Bounty and said "order" in red for an order with no gold - the owner had to ask what that
--- meant ("betyr order at det er lagt ut order?", 2026-11-14) - and the row said only when they killed last.
local function WantedItems()
    local items, me = {}, LIB.Me()
    for _, e in ipairs(GK.MostWanted()) do
        local o = GK.OrderOn(e.key)
        local pot = o and (GK.Pot(o)) or 0
        -- their level: at their last kill on us, or what an order on them has them at since, if higher
        items[#items + 1] = { key = "w:" .. e.key, name = GK.Show(e.key),
            desc = Short(GK.HigherLevel(e.w.l, o and o.l), e.w.c, e.w.r),
            class = e.w.c, face = { key = e.key, c = e.w.c }, sub = Victims(e.w),
            c1 = tostring(e.total), c1under = e.w.last and GK.Ago(e.w.last) or nil, killed = e.total,
            -- what the heading sorts by: those with an order first, the most gold first among them
            bounty = o and (pot + 0.5) or 0,
            -- the gold in the game's coins, as on the kill orders page ("kjedelig at kill order bounty ikke
            -- vise gold icon", the owner, 2026-11-10)
            right = o and (ORDER_MARK .. (pot > 0 and (" " .. GK.Coins(pot)) or "")) or "",
            select = PosterSpec(e.key, e.w), ts = e.w.last,
            eye = GK.IsTracked and GK.IsTracked(e.key) or nil,       -- on your Death list
            own = me and e.w.victims[me] and true or nil }
    end
    return items, "Nobody has killed the guild yet - not that the Grudgekeeper heard of."
end

--- Grudges' third view: the guild on watch, with the versus page beside it - "vi må ha en VS på guilden i vi
--- tracker. hvor mange ganger har vi drept dem, hvor mange ganger har de drept oss", then "så killed us most og
--- lista over gamingboys er på venstre side og da spillerprofil og den VS er på høyre" (the owner, 2026-11-22). A
--- row for each of theirs who fought us, the most fought first, each count in its side's colour where it leads.
local function GuildItems(guild)
    local items = {}
    local _, _, rows = GK.GuildScore(guild)
    local ours, theirs = Versus.Inks()
    for _, e in ipairs(rows) do
        items[#items + 1] = { key = "g:" .. e.key, name = GK.Show(e.key), desc = Short(e.l, e.c, e.r),
            class = e.c, face = { key = e.key, c = e.c },
            c1 = tostring(e.k), right = tostring(e.d), them = e.k, killed = e.d,
            c1Colour = e.k >= e.d and ours or FADED, rightColour = e.d > e.k and theirs or FADED,
            select = PosterSpec(e.key, e), ts = e.last, own = e.own }
    end
    return items, ("Nobody of <%s> has fought us yet. A kill or a death counts once we know they are theirs: seen "
        .. "while the guild is tracked, or named so by a guildie."):format(guild)
end


-- Two lists of players since 2026-11-22, where Grudges was one from 2026-11-20 with both in it: "han vil ha en
-- Deathnote tab. KUN de han selv har lagt på lista, ikke randoms han har møtt" (the owner, of a streamer's word).
-- The Death list is whom you put there, and Grudges' Killed me what came by itself. Drawn first
-- (art/mockups/deathlist).
--- Who leads, and by how much: above 0 they lead over you, by what it takes to stand even ("owed 3").
local function Owed(f) return (f.d or 0) - (f.k or 0) end

--- The Death list (Sightings.lua, GK.Track): every one you put there and nobody else, whoever was seen latest
--- first - a warning names them, and here is where to find them after it.
local function DeathListItems()
    local items, c = {}, GK.char
    local tracked = {}
    for key, t in pairs(c.tracked or {}) do
        tracked[#tracked + 1] = { key = key, t = t, s = GK.Seen and GK.Seen(key), name = GK.Show(key) }
    end
    table.sort(tracked, function(a, b)
        local x, y = a.s and a.s.t or -1, b.s and b.s.t or -1
        if x ~= y then return x > y end
        if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
        return a.key < b.key
    end)
    local clock, wall = GetTime(), time()
    for _, e in ipairs(tracked) do
        local f = c.foes[e.key]
        local sub
        if e.s then
            sub = "seen " .. GK.Ago(wall - (clock - e.s.t)) .. (e.s.z and (" \194\183 " .. e.s.z) or "")
        elseif f and f.last then
            sub = "last met " .. GK.Ago(f.last)
        else
            sub = "added " .. GK.Ago(e.t.t)
        end
        local note = GK.DeathNote and GK.DeathNote(e.key)
        if note then sub = '"' .. note .. '"' end            -- when you saw them is on their card
        local look = f or e.t
        local you, they = f and (f.k or 0) or 0, f and (f.d or 0) or 0
        items[#items + 1] = { key = "t:" .. e.key, name = e.name, class = look.c, face = { key = e.key, c = look.c },
            desc = Short(look.l, look.c, look.r), sub = sub, noted = note ~= nil, score = { you, they },
            select = PosterSpec(e.key, look), you = you, they = they, ts = f and f.last or e.t.t, own = true }
    end
    return items, "No names written yet. Add someone, or right-click an enemy and pick Add to Death list."
end

local NO_LOG = "No kills or deaths yet. Only the open world counts: dungeons and battlegrounds hide who is who."

--- One line of your log (GK.AddLog) as a row, the i-th from the newest: a kill, an assist or a death, a
--- click from the enemy's poster. The You page lists them.
local function LogRow(e, i)
    local it = { key = "l:" .. i, face = { key = e.n, c = e.c }, select = PosterSpec(e.n, e), ts = e.t, own = true,
        sub = table.concat({ e.z or "", GK.Ago(e.t) }, e.z and " - " or "") }
    local said = e.k == "K" and "Killed %s" or (e.k == "A" and "Helped kill %s") or "Slain by %s"
    if GK.Classic() then it.painted = { name = said:format(GK.InClass(GK.Show(e.n), e.c)) } end
    if e.k == "K" then
        it.name = "Killed " .. GK.Show(e.n)
        it.right = (e.p or 0) > 0 and ("+%d"):format(e.p) or "no points"
    elseif e.k == "A" then
        it.name = "Helped kill " .. GK.Show(e.n)
        if e.w then it.sub = it.sub .. " - with " .. e.w end
        it.right = (e.p or 0) > 0 and ("+%d"):format(e.p) or "no points"
    else
        -- the spell at the end of the line under the name, not in the right-hand column: there
        -- "Judgement of Righteousness" left the name "Slain by I..." and the place "Wetlands -..."
        -- (the owner, 2026-11-06). At the end it is what gets cut, if anything does.
        it.name = "Slain by " .. GK.Show(e.n)
        if e.s then it.sub = it.sub .. " - " .. e.s end
    end
    return it
end

--- Killed me: who has killed you, the most owed first, then under a faint line who you are even with or lead.
--- One on your Death list is here too, with the eye. "most wanted er jo typ 'de du har møtt som har drept oss'"
--- (the owner, 2026-11-22).
local function KilledMeItems()
    local items, c = {}, GK.char
    -- the last thing that happened with each of them: your log is newest first
    local lastOf = {}
    for _, e in ipairs(c.log) do
        if e.n and not lastOf[e.n] then lastOf[e.n] = e end
    end
    local foes = {}
    for k, v in pairs(c.foes) do
        if (v.d or 0) > 0 then foes[#foes + 1] = { key = k, f = v, name = GK.Show(k), owed = Owed(v) } end
    end
    -- who leads over you, the most owed first; then even; then who you lead, the smallest lead first. Within
    -- each, the latest met first.
    table.sort(foes, function(a, b)
        local x, y = a.owed, b.owed
        if (x > 0) ~= (y > 0) then return x > 0 end
        if x > 0 and x ~= y then return x > y end
        if x <= 0 and y <= 0 and x ~= y then return x > y end
        if (a.f.last or 0) ~= (b.f.last or 0) then return (a.f.last or 0) > (b.f.last or 0) end
        if a.name:lower() ~= b.name:lower() then return a.name:lower() < b.name:lower() end
        return a.key < b.key
    end)
    for i = #foes, LIST_MAX + 1, -1 do foes[i] = nil end
    local lined = false
    for i = 1, #foes do
        local e = foes[i]
        local you, they = e.f.k or 0, e.f.d or 0
        -- what happened last, and where: "killed you 11 min ago · Ashenvale" says more than "last met"
        local last = lastOf[e.key]
        local sub
        if last then
            local what = { K = "you killed them ", A = "you helped kill them " }
            sub = (what[last.k] or "killed you ") .. GK.Ago(last.t) .. (last.z and (" \194\183 " .. last.z) or "")
        else
            sub = "last met " .. GK.Ago(e.f.last)
        end
        -- the score is kills against deaths; assists go first under the name, where they aren't cut
        if (e.f.a or 0) > 0 then sub = Plural(e.f.a, "assist") .. " \194\183 " .. sub end
        -- the faint line over the first who does not lead over you, where anything stands above it
        local rule = nil
        if not lined and e.owed <= 0 then
            lined = true
            rule = #items > 0 or nil
        end
        items[#items + 1] = { key = "f:" .. e.key, name = e.name, class = e.f.c, face = { key = e.key, c = e.f.c },
            desc = Short(e.f.l, e.f.c, e.f.r), sub = sub, score = { you, they }, rule = rule,
            eye = GK.IsTracked and GK.IsTracked(e.key) or nil,
            select = PosterSpec(e.key, e.f), you = you, they = they, ts = e.f.last, own = true }
    end
    -- Your log is the You page's: it stood here under Lately as well, the same 25 rows twice (2026-11-16).
    -- Grudges is who owes you; what you did is on the You page.
    return items, "Nobody has killed you yet. Only the open world counts: dungeons and battlegrounds hide who is who."
end

--- The You page: you at the top, a click from your own card wherever you were on the page, and under you
--- the latest of your log. "vi har ikke en egen grudgekeeper profil? vi må finne oss selv og trykke på for
--- å se?" (the owner, 2026-11-16): your card was the kill orders page's stand-in for a page with nothing on
--- it, your row on the leaderboard, or the Debug panel. LIST_MAX of the log, as every list here: "ikke
--- evig pages" (the owner, 2026-11-10).
local function YouItems()
    local c, me = GK.char, LIB.Me()
    local _, class = UnitClass("player")
    class = GK.ValidClass(class)
    local race, raceFile = UnitRace("player")
    local p = c.points or 0
    local items = { { key = "me", name = GK.Show(me), class = class, sub = GK.Title(p),
        face = { key = me, c = class, rf = raceFile, sx = UnitSex("player") },
        desc = Short(UnitLevel("player"), class, race), right = Plural(p, "point"),
        select = { kind = "record", key = me }, own = true } }
    -- a heading even with nothing under it: the page says what will be there, as the others' empty text
    -- does (that text shows only on a page with no row at all, and you are always on this one)
    items[2] = { header = true, name = #c.log > 0 and "Lately" or "No kills or deaths yet" }
    for i = 1, math.min(#c.log, LIST_MAX) do items[#items + 1] = LogRow(c.log[i], i) end
    return items, NO_LOG
end

-- What the news says, by kind: who, then whom. "AU" is a C whose poster's death posted it.
local SAID = { K = "%s killed %s", H = "%s helped kill %s", D = "%s fell to %s", F = "%s fulfilled the order on %s",
    C = "%s put a price on %s", AU = "%s death put a price on %s", T = "%s added to the pot on %s" }

-- The news that is more than who killed whom, written in the page's other colour: an order fulfilled, a
-- spree's milestone, a spree an enemy ended, a tormentor put down.
local ACCENT = { F = true, S = true, E = true, M = true }
-- The news of kill orders, for the News's "Kill orders" view: posted (C, AU by a death), backed (T), got (F).
local ORDER_NEWS = { F = true, C = true, AU = true, T = true }

-- A kill and the assists on it are one line: the killing blow first, then who helped. Each had a line of
-- its own, so one enemy killed by three of us was three lines, and two such kills filled the first turn of
-- the page ("når mange dreper 1.. blir det mye å legge ut så mange linjer eller?", the owner, 2026-11-14).
-- Put together here, where the news is shown: what is kept and sent is a line each as before, and a
-- guildie's card still says their own kills and assists. An assist is heard when its fight ends and the
-- meter can be read - a minute on in the owner's screenshot, two at the most (Kills.lua) - so it joins the
-- kill on the same enemy up to KILL_JOIN seconds before it.
local KILL_JOIN = 150

--- Which lines of the feed are one kill: [index in the feed] = its group, { k = the kill's own line (nil
--- when the killing blow was nobody's we hear), h = the assists' lines, oldest first, p = their points
--- together, own = one of them is ours, at = the index of the latest of its lines, where it is told }. A
--- second kill on the same enemy, or a second line from the same guildie, starts a new one: they were
--- killed again.
local function KillGroups(feed)
    local groupOf, latest = {}, {}
    for i = #feed, 1, -1 do                        -- oldest first: a kill's line is heard before its assists
        local e = feed[i]
        if (e.kind == "K" or e.kind == "H") and e.n and e.who then
            local name = GK.Show(e.n)
            local g = latest[name]
            if not g or math.abs((e.t or 0) - g.t) > KILL_JOIN or (e.kind == "K" and g.k) or g.who[e.who] then
                g = { t = e.t or 0, h = {}, who = {}, p = 0 }
                latest[name] = g
            end
            if e.kind == "K" then g.k = e else g.h[#g.h + 1] = e end
            g.who[e.who] = true
            g.p = g.p + (e.p or 0)
            if LIB.IsMyStoredName(e.who) then g.own = true end
            g.at = i                               -- oldest first, so the last one written is the latest line
            groupOf[i] = g
        end
    end
    return groupOf
end

-- A line that says nothing: what a kill's lines other than its latest are read as (NewsItems). It has
-- no kind, so no words are found for it and no row made.
local UNSAID = {}

local function NewsItems(limit)
    local items = {}
    local feed = GK.Store().feed
    local groupOf = KillGroups(feed)
    -- In the Classic skin each name in a line is in its class's colour: the enemy's as the line has it, a
    -- guildie's as the leaderboard does, yours as you are (GK.InClass)
    local paint, board = GK.Classic(), GK.Store().board
    local myClass = paint and GK.ValidClass(select(2, UnitClass("player"))) or nil
    -- the orders got, by their target and the hunter, the latest first: a fulfilled order's line opens that
    -- order's card - who posted it, the bounty, where - and says its whole bounty, not the poster's part
    -- (by when it was got, as the line was written then; else the hunter's latest on that target, for a
    -- line whose time the poster's own copy of the order moved since)
    local gotAt, got = {}, {}
    for _, o in pairs(GK.Store().orders) do
        if o.doneBy and o.doneAt and (o.state == "d" or o.state == "p") then
            gotAt[o.n .. "|" .. o.doneAt] = o
            local k = o.n .. "|" .. o.doneBy
            if not got[k] or got[k].doneAt < o.doneAt then got[k] = o end
        end
    end
    local function OrderGot(e)
        return gotAt[tostring(e.n) .. "|" .. tostring(e.t)] or got[tostring(e.n) .. "|" .. tostring(e.who)]
    end
    for i, newest in ipairs(feed) do
        if limit and #items >= limit then break end   -- the guild window's tab asks for a line or ten
        -- A kill is told once, where the latest of its lines stands, in the words of the killing blow's
        -- line - or the first assist's, where the blow was nobody's we hear - with the others named after.
        local g = groupOf[i]
        local e, with = newest, nil
        if g and g.at ~= i then
            e = UNSAID
        elseif g then
            e = g.k or g.h[1]
            with = {}
            for _, h in ipairs(g.h) do
                if h ~= e then with[#with + 1] = h.who end
            end
        end
        -- your own news says You: your full name and surname first left "Critical Mango killed Seedkek..."
        -- no room for whom (the owner, 2026-11-06)
        local mine = e.who ~= nil and LIB.IsMyStoredName(e.who)
        local kind = (e.kind == "C" and e.au) and "AU" or e.kind
        local said = SAID[kind]
        local line, short, shortest, right, painted
        local function ClassOf(k)
            if k == e.n then return e.c end
            if LIB.IsMyStoredName(k) then return myClass end
            local b = board[k]
            return b and b.c
        end
        -- a name as a line says it, in its class's colour when tint is asked for (the Classic skin only)
        local function Named(text, k, tint) return tint and GK.InClass(text, ClassOf(k)) or text end
        if said then
            local function Who(n)
                if kind == "AU" then return mine and "Your" or (n .. "'s") end
                return mine and "You" or n
            end
            -- an order got together, or a kill: everyone who was there, the killing blow first (GK.WhoGotThem)
            local others = (kind == "F" and type(e.h) == "table" and e.h) or with
            local function Who2(show, tint)
                local names = { Named(Who(show(e.who)), e.who, tint) }
                for _, k in ipairs(others or {}) do
                    names[#names + 1] = Named(LIB.IsMyStoredName(k) and "you" or show(k), k, tint)
                end
                if #names == 1 then return names[1] end
                return table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
            end
            -- the short form, for a line too long for its row (FillRow): first names only
            line = said:format(Who2(GK.Show), GK.Show(e.n))
            short = said:format(Who2(FirstName), FirstName(e.n))
            if paint then
                painted = { name = said:format(Who2(GK.Show, true), Named(GK.Show(e.n), e.n, true)),
                    short = said:format(Who2(FirstName, true), Named(FirstName(e.n), e.n, true)) }
            end
            -- The shortest, where even first names run past the row: you if you were in it, else whoever
            -- leads the line, and how many more. Three of us by first name cut the one name that mattered,
            -- whom: "Mezmerizing, you and Umulius killed Ade..." (the owner's screenshot, 2026-11-14).
            if others and #others > 0 then
                local you = mine
                for _, k in ipairs(others) do you = you or LIB.IsMyStoredName(k) end
                shortest = said:format((you and "You" or FirstName(e.who)) .. " +" .. #others, FirstName(e.n))
                if painted then
                    local lead = you and Named("You", LIB.Me(), true) or Named(FirstName(e.who), e.who, true)
                    painted.shortest = said:format(lead .. " +" .. #others, Named(FirstName(e.n), e.n, true))
                end
            end
        end
        -- A spree's news (GK.SpreeNews), each in words of its own: a milestone is about the guildie - their
        -- face, their record at a click, the tier's name at the right - and has no enemy in it; a spree ended
        -- and a tormentor put down are about the enemy, as every other line is.
        local under, face, sel
        if kind == "S" then
            local function Line(show, tint)
                return ("%s: %d kills in a row"):format(Named(mine and "You" or show(e.who), e.who, tint), e.s or 0)
            end
            line, short, right = Line(GK.Show), Line(FirstName), e.tr
            if paint then painted = { name = Line(GK.Show, true), short = Line(FirstName, true) } end
            local b = GK.Store().board[e.who]
            face = { key = e.who, rf = b and b.rf, sx = b and b.sx, c = b and b.c }
            sel = { kind = "record", key = e.who }
        elseif kind == "E" then
            local function Line(show, tint)
                return ("%s ended %s %d-kill spree"):format(Named(show(e.n), e.n, tint),
                    Named(mine and "your" or (show(e.who) .. "'s"), e.who, tint), e.s or 0)
            end
            line, short = Line(GK.Show), Line(FirstName)
            if paint then painted = { name = Line(GK.Show, true), short = Line(FirstName, true) } end
        elseif kind == "M" then
            local function Line(show, tint)
                return ("%s put an end to %s"):format(Named(mine and "You" or show(e.who), e.who, tint),
                    Named(show(e.n), e.n, tint))
            end
            line, short = Line(GK.Show), Line(FirstName)
            if paint then painted = { name = Line(GK.Show, true), short = Line(FirstName, true) } end
            under = ("had killed %d of us"):format(e.s or 0)
        end
        if kind == "K" or kind == "H" then
            -- what the kill was worth to the guild: everyone's points for it together
            local points = g and g.p or (e.p or 0)
            right = points > 0 and ("+%d"):format(points) or nil
        elseif kind == "F" or kind == "C" then
            -- the gold on the order, or nothing: an order with none said "honour" here (and one a death
            -- posted, AU, said nothing else), a word the owner did not want for it (2026-11-14). A fulfilled
            -- one says all of it, backers' shares too, and opens the order's own card.
            local o = kind == "F" and OrderGot(e)
            local gold = o and (GK.Pot(o)) or e.p or 0
            right = gold > 0 and GK.MoneyText(gold) or nil
            if o then sel = PosterSpec(e.n, o, o) end
        elseif kind == "T" then
            right = GK.MoneyText(e.p or 0)
        end
        if line then
            -- an order fulfilled in the page's other colour, the line and its bounty: among the lines of who
            -- killed whom it was one more of them, and the one a guildie who was not there looks for
            -- ("det er mer listene og oversikten", the owner, 2026-11-14). A spree's news the same.
            local accent = ACCENT[kind] and BLOOD or nil
            local bits = { under }
            if e.z then bits[#bits + 1] = e.z end
            bits[#bits + 1] = GK.Ago(e.t)
            local own = (g and g.own) or (e.who and LIB.IsMyStoredName(e.who)) or nil
            items[#items + 1] = { key = "n:" .. i, kind = kind, name = line, short = short, shortest = shortest, painted = painted,
                face = face or { key = e.n, c = e.c },
                right = right, sub = table.concat(bits, " - "), select = sel or PosterSpec(e.n, e),
                ts = e.t, own = own, ink = accent, rightColour = accent }
        end
    end
    return items, "Nothing yet. Kills, deaths and kill orders from everyone in your guild who runs Grudgekeeper "
        .. "show up here."
end

--- The latest n lines of the guild's news, worded as the News page words them, the newest first.
function GK.LatestNews(n)
    return (NewsItems(n))
end

--- The leaderboard's resets-in text, after its links.
local function ResetText()
    local get = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
    local ok, secs = false, nil
    if get then ok, secs = pcall(get) end
    local days = ok and type(secs) == "number" and not GK.Secret(secs) and math.ceil(secs / 86400) or nil
    return days and ("-  resets in " .. Plural(days, "day")) or ""
end

--- How points are counted, for the Points heading's tooltip: from the numbers themselves (Core.lua), so it
--- can't say what they no longer are. The news letter left the numbers out to read like him talking, and
--- sends the reader here.
local function PointsHelp()
    local P = GK.POINTS
    return {
        "How points are counted",
        ("A kill: green %d, yellow %d, orange %d, red %d, grey %d."):format(P.green, P.yellow, P.orange, P.red,
            P.grey),
        ("Revenge +%d. Avenging a guildie +%d, in a later fight than the one they fell in."):format(
            GK.REVENGE_BONUS, GK.AVENGE_BONUS),
        ("The target of a kill order +%d."):format(GK.ORDER_BONUS),
        ("The same player counts %d times a day, then nothing."):format(GK.REPEATS),
        ("An assist: the kill's points less %d, but at least 1 if the kill gives any."):format(GK.ASSIST_LESS),
        "A kill streak counts no grey kill and none farmed, whatever they give.",
    }
end

--- The ledger's pages, in tab order; other files add theirs with GK.AddLedgerPage. A page is
--- { name, items = fn -> items, empty text, headings, sub = fn(items, all) -> text, links = fn -> { { text,
--- on, click } }, linksTail = fn -> text, sortable, max, side, add, icon, default = fn(items) -> the row chosen
--- when none is }. max: a sortable page with no section headings lists at most this many rows (GK.SortItems);
--- all, to sub, is how many there were before it. icon: the texture on its tab folded, down the frame's side.
--- onlyMine: fn -> whether Only mine shows and counts as the page stands (MineShown). versus: fn -> the guild
--- whose versus page stands where the card would, or nil. views, setView, getView: a page whose rows differ
--- by view, for what looks for someone's row (RowAtHome).
--- headings: the column headings over the table, { text, x, justify, sort, tip, help }: a heading with a sort
--- (an item field: "name", or a number, the biggest first) sorts the page when clicked, and tip finishes
--- "Sort by ..." in its tooltip. help: fn -> lines its tooltip starts with, the first as a title, sorting
--- or not. At most HEADS headings a page. sortable: the headings sort and Only mine shows. links: ink links under
--- the title. add: the page's own action, top right - { text, kind } opens the who-picker (Pick.lua) for
--- that kind. side: "right" puts the tab over the right page in the open book (the friendly lists);
--- anything else is over the left page. Folded, the page's group hangs down the frame's side. A page with links and a sub
--- line has the sub text after the links, on their line.
GK.LedgerPages = {
    -- no heading row, no line under the title and nothing to sort by: the list starts right under the
    -- title and has a row more (ListFrame). In its own order: what was got lately, the gold, the rest.
    { name = "Kill orders", items = OrderItems, icon = MEDIA .. "mark", headings = {},
      add = { text = "Post a kill order", kind = "order" },
      setView = function(view) ordersPage.All() ordersPage.view = view end,
      links = function()
          local v = ordersPage.view
          return { { text = "All", on = v == "all", click = function() ordersPage.view = "all" end },
                   { text = "Bounties", on = v == "gold", click = function() ordersPage.view = "gold" end },
                   { text = "Mine", on = v == "mine", click = function() ordersPage.view = "mine" end } }
      end,
      -- with no open order, your own record rather than a blank page; otherwise the first open order
      default = function(items)
          if #items > 0 then return nil end
          return { key = "me", select = { kind = "record", key = LIB.Me() } }
      end },
    { name = "Leaderboard", items = BoardItems, icon = MEDIA .. "rank_1",
      headings = { { "#", 12 }, { "Name", NAME_X_RANKED + 4 }, { "K", BOARD_K, "CENTER" }, { "D", BOARD_D, "CENTER" },
          { "A", BOARD_A, "CENTER" }, { "Points", COL_RIGHT, "RIGHT", nil, nil, PointsHelp } },
      links = function()
          return { { text = "This week", on = weekly, click = function() weekly = true end },
                   { text = "All time", on = not weekly, click = function() weekly = false end } }
      end,
      -- the week alone resets ("fjern resets in 3 days fra all time", the owner, 2026-11-22)
      linksTail = function() return weekly and ResetText() or "" end },   -- the first row is chosen by itself
    -- The list you made, and only that: no row gets here but by your click (DeathListItems). All of it, however
    -- many turns of the page, so no max.
    { name = "Death list", items = DeathListItems, headings = {},
      icon = ICONS .. "Ability_Hunter_SniperShot",          -- the hunter's mark: marked to be hunted
      add = { text = "Add someone", kind = "track" },
      sub = function() return "Every name written here is a death sentence." end,
      default = function(items)
          if #items > 0 then return nil end
          return { key = "me", select = { kind = "record", key = LIB.Me() } }
      end },
    -- What came by itself, Most wanted until 2026-11-22: who killed you, who killed the guild, and the guild on
    -- watch while one is, with the versus page where the profile would be. Each view its own headings.
    { name = "Grudges", sortable = true, max = LIST_MAX, icon = ICONS .. "Ability_DualWield",
      views = { "me", "killed" },                           -- where a card opened from outside looks (GK.ShowInLedger)
      setView = function(view) grudgesView = view end,
      getView = function() return grudgesView end,
      items = function()
          local view, guild = GrudgesView()
          if view == "guild" then
              if guild then return GuildItems(guild) end
              return {}, "No guild tracked yet. " .. (GK.CanWatchGuild and GK.CanWatchGuild()
                  and "Track one with the button at the top, or right-click one of their players."
                  or "An officer or the guild master can track an enemy guild.")
          end
          if view == "killed" then return WantedItems() end
          return KilledMeItems()
      end,
      headings = function()
          local view, guild = GrudgesView()
          if view == "guild" then
              if not guild then return {} end                  -- no rows, so nothing to head
              return { { "Name", 48, nil, "name", "name, A to Z" },
                  { "We killed", COL1, "CENTER", "them", "how often we killed them" },
                  { "Killed us", COL_RIGHT, "RIGHT", "killed", "how often they killed us" } }
          end
          -- each grudge says its own score, in an order of its own (KilledMeItems)
          if view == "me" then return {} end
          return { { "Name", 48, nil, "name", "name, A to Z" },
              { "Killed us", COL1, "CENTER", "killed", "how often they killed us" },
              { "Kill order", COL_RIGHT, "RIGHT", "bounty", "kill order, the most gold first" } }
      end,
      onlyMine = function()
          local on, guild = GuildView()
          return on and guild ~= nil
      end,
      versus = function()                                   -- the guild to draw the versus page of, "" with none
          local on, guild = GuildView()
          if on then return guild or "" end
          return nil
      end,
      -- on Versus an officer's button is the tracking: all of it is here ("ha hele guild tracking greia på
      -- grudges", the owner, 2026-11-22)
      add = function()
          local on, guild = GuildView()
          if on and GK.CanWatchGuild and GK.CanWatchGuild() then
              return { text = guild and "Track another" or "Track a guild", kind = "guild" }
          end
          return { text = "Post a kill order", kind = "order" }
      end,
      links = function()
          local view, guild = GrudgesView()
          local out = { { text = "Killed me", on = view == "me", click = function() grudgesView = "me" end },
              { text = "Killed us", on = view == "killed", click = function() grudgesView = "killed" end } }
          -- never the guild's name: of up to 24 letters it ran off the page on two views and was cut to
          -- "WARDENS OF ..." beside Only mine on the third ("lange guild navn kan gjøre det problematisk i
          -- headeren", the owner, 2026-11-22). The name is on the mouse here and on its banner.
          out[3] = { text = "Versus", tip = guild, on = view == "guild", click = function() grudgesView = "guild" end }
          return out
      end,
      default = function(items)
          if #items > 0 then return nil end
          return { key = "me", select = { kind = "record", key = LIB.Me() } }
      end },
    -- Everything, or the kill orders alone: posted, backed, got. "Fulfilled lately" stood over the open orders
    -- for a day; it is this view now ("fulfilled lately.. skal det være en tab i news isteden", the owner,
    -- 2026-11-18).
    { name = "News", sortable = true, max = LIST_MAX, icon = ICONS .. "INV_Scroll_03",
      items = function()
          local items, empty = NewsItems()
          if newsView ~= "orders" then return items, empty end
          local kept = {}
          for _, it in ipairs(items) do
              if ORDER_NEWS[it.kind] then kept[#kept + 1] = it end
          end
          return kept, "No kill orders in the news yet: one posted, backed or got shows up here."
      end,
      headings = { { "What happened", 48 } },
      links = function()
          return { { text = "All", on = newsView ~= "orders", click = function() newsView = "all" end },
                   { text = "Kill orders", on = newsView == "orders", click = function() newsView = "orders" end } }
      end },
    -- your own page, the last of the enemy's side: your card on the right, opened by itself (your row is
    -- the first). Past the first two, so nothing opened by number moves (GK.AddLedgerPage).
    { name = "You", items = YouItems, headings = {}, icon = ICONS .. "Ability_Warrior_BattleShout",
      sub = function() return "Your record, and what you did lately" end },
}

--- Adds a page, after the ledger's own unless def.before names the page (by its name) to sit in front of;
--- a name nobody has goes last. Only before the book is first built: the tabs are made then. Pages are
--- opened by number only for the first two (GK.OpenWindow(1), (2): Kill orders and Leaderboard), so a
--- page put at 4 or later moves nothing that is opened by number - find a page by its def, not its index.
function GK.AddLedgerPage(def)
    assert(not win, "GK.AddLedgerPage: the ledger is already built")
    for i, page in ipairs(GK.LedgerPages) do
        if def.before and page.name == def.before then
            table.insert(GK.LedgerPages, i, def)
            return
        end
    end
    table.insert(GK.LedgerPages, def)
end

--- What a page is sorted by: the sort of the heading clicked last on it (GK.db.sortBy[page name]), or nil
--- for the page's own order - also when the saved one is no heading of the page (any more).
function GK.SortKey(page)
    local key = page and page.sortable and GK.db.sortBy and GK.db.sortBy[page.name]
    if key == nil then return nil end
    for _, h in ipairs(Headings(page)) do
        if h[4] == key then return key end
    end
    return nil
end

--- A click on a heading: sort the page by it, or, clicked again, back to the page's own order.
function GK.SortBy(page, key)
    if type(GK.db.sortBy) ~= "table" then GK.db.sortBy = {} end
    GK.db.sortBy[page.name] = (GK.SortKey(page) ~= key) and key or nil
end

--- A page's rows in the order its clicked heading asks for, and only yours with GK.db.mineOnly; the page's
--- own order, without Only mine, is left alone. Each section is sorted on its own, under its heading: the
--- open kill orders among themselves, the closed ones folded under theirs - sorted together, a FULFILLED
--- stood among the open orders ("sortering i kill orders burde ikke ta med fulfulled og withdrawn", the
--- owner, 2026-11-10; that page has had no headings to sort by since 2026-11-14, and the rule stands for
--- any page of sections). A heading Only mine left with no rows goes. Names go A to Z, numbers the biggest
--- first; ties go A to Z. A page with a max keeps that many, the first in its own order, after Only mine and
--- before the sort: Killed us by name is still the 25 who killed us most, A to Z, and Only mine finds yours
--- if they are 40th. Returns a new list, or the same one untouched, and how many rows
--- it had before the max.
function GK.SortItems(items, page)
    local key, mineOnly = GK.SortKey(page), GK.db.mineOnly == true and MineShown(page)
    local max = page and page.max
    if not (page and page.sortable) or (not key and not mineOnly and not max) then return items, #items end
    -- the sections: the rows before the first heading, then each heading with the rows under it
    local section, at, all = { rows = {} }, {}, 0
    local sections = { section }
    for _, it in ipairs(items) do
        if it.header then
            section = { head = it, rows = {} }
            sections[#sections + 1] = section
        elseif not mineOnly or it.own or it.mine then
            all = all + 1
            if not max or all <= max then
                section.rows[#section.rows + 1] = it
                at[it] = all
            end
        end
    end
    local function SortName(it) return (it.name or ""):lower() end
    local function Before(a, b)
        if key ~= "name" then
            local x, y = tonumber(a[key]) or 0, tonumber(b[key]) or 0
            if x ~= y then return x > y end
        end
        local na, nb = SortName(a), SortName(b)
        if na ~= nb then return na < nb end
        return at[a] < at[b]                   -- table.sort needs a strict order, or it can error
    end
    local out = {}
    for _, s in ipairs(sections) do
        if key then table.sort(s.rows, Before) end
        if s.head and (#s.rows > 0 or not mineOnly) then out[#out + 1] = s.head end
        for _, it in ipairs(s.rows) do out[#out + 1] = it end
    end
    return out, all
end

-- ---------------------------------------------------------------------------
-- The detail: what the right page (or the turned page) shows
-- ---------------------------------------------------------------------------
--- The card for a selected row. A closed order says so, and what you still owe on it.
local function DetailCard(spec)
    if not spec then return nil end
    if spec.kind == "card" then return spec.make() end
    if spec.kind == "record" then
        local d = GK.RecordCard(spec.key, spec.unit)
        if d then d.buttons = {} end            -- its one button opens the leaderboard: we are in it
        return d
    end
    local d = GK.PosterCard(spec.t, true)
    local o = spec.order
    if o and o.state ~= "o" then
        local word = STATE_WORD[o.state] or "CLOSED"
        local rows = { { "Closed", ("%s%s, %s"):format(word:sub(1, 1) .. word:sub(2):lower(),
            o.doneBy and (" by " .. GK.WhoGotThem(o.doneBy, o.helpers)) or "", GK.Ago(o.paidAt or o.doneAt)) } }
        -- where they were got, the bounty it carried, who posted it and why: what a guildie who was not
        -- there asks, from the news line of it ("når man trykker på den linjen i news så burde det være mer
        -- info om hvem som la ut kill order, for hvor mye og slikt", the owner, 2026-11-16)
        if o.doneZone and o.doneZone ~= "" and o.state ~= "x" and o.state ~= "e" then
            rows[#rows + 1] = { "Where", o.doneZone }
        end
        local pot, backers = GK.Pot(o)
        local givers = backers + ((o.reward or 0) > 0 and 1 or 0)
        rows[#rows + 1] = { "Bounty", pot > 0 and ("%s from %s"):format(GK.Coins(pot), Plural(givers, "guildie"))
            or "None" }
        local byMe = LIB.IsMyStoredName(o.by)
        local poster = byMe and "You" or GK.Show(o.by)
        if o.auto then poster = (byMe and "Your" or (poster .. "'s")) .. " death" end
        rows[#rows + 1] = { "Posted by", ("%s, %s"):format(poster, GK.Ago(o.t)) }
        if o.note and o.note ~= "" then rows[#rows + 1] = { "Why", o.note } end
        -- what we owe on it: a part to each hunter, the bounty shared (GK.Owed)
        local owe = {}
        for _, e in ipairs(GK.Owed()) do
            if e.o == o then owe[#owe + 1] = ("%s %s"):format(GK.Show(e.to), GK.MoneyText(e.share)) end
        end
        if #owe > 0 then
            rows[2] = { "You owe", ("%s - mail or trade it, and it is marked paid."):format(#owe == 1 and owe[1]
                or (table.concat(owe, ", ", 1, #owe - 1) .. " and " .. owe[#owe])) }
            d.buttons = { { "Mark as paid", function() GK.PayShare(o) end } }
        end
        -- yours to tell, by your kill or with you there: here too, since a read letter is gone (GK.TellOrder)
        if GK.CanTellOrder(o) then
            d.buttons = { { "Tell the guild", function() GK.TellOrder(o) end }, d.buttons and d.buttons[1] }
        end
        -- the order's own section first, and the kicker says it is over ("ORDER FULFILLED") - unless a
        -- newer order on them is open, which keeps its own WANTED and its own section
        local open = d.title == "WANTED"
        -- with a newer order open, this one after that one's order and pot, before the History
        local at = 1
        if open then
            at = #d.rich.sections + 1
            for i, sec in ipairs(d.rich.sections) do
                if sec.head == "History" then
                    at = i
                    break
                end
            end
        end
        table.insert(d.rich.sections, at,
            { head = open and "An earlier order" or "The order", kind = "facts", rows = rows })
        -- who put what in it, and who has paid: only when it is the order the card is about, so the
        -- newer order's pot and the History keep their room
        local pot = not open and GK.PotRows(o)
        if pot then table.insert(d.rich.sections, at + 1, { head = "The pot", kind = "facts", rows = pot }) end
        if not open then d.rich.kicker = "Order " .. word:lower() end
    end
    return d
end

--- "All time: 31 kills, 12 deaths." reads as a two-column row: a short label, then the rest.
local function Split(line)
    local label, value = line:match("^([^:,]+): (.+)$")
    if label and #label <= 14 then return label, value end
    return nil, line
end

-- ---------------------------------------------------------------------------
-- Building the book
-- ---------------------------------------------------------------------------
--- A round portrait in the bronze ring (Letters.lua, shared with the sheets' heads).
local MakePortrait = GK.MakePortrait

local Refresh                -- below; the rows and buttons call it

-- ---------------------------------------------------------------------------
-- The versus page: the right page of Grudges' view of the guild on watch
-- ---------------------------------------------------------------------------
-- "så en stilig statisk oversikt ... som bruker hele sida til å vise versus guilden", the list on the left and
-- this on the right, then "jeg liker både score og latest fight" (the owner, 2026-11-22), drawn first
-- (art/mockups/versus). Two of the client's own war banners (Forever's character creation), each side's in its
-- faction's colour, with the score and the top killer on them, and the latest four fights under them.
-- A banner is cut out of its one texture: the cloth above its first hole, stretched to hold the words, and the
-- torn point under them. The holes stood behind the top killer's name on the Horde's ("litt vanskelig å se
-- teksten på horde siden, kanskje hullene i banneret", the owner), so no word stands lower than the cloth, and
-- every word on a banner is cream or gold whatever the class: Shaman blue is 2.8 to 1 on the red.
-- In a block: the file is near Lua 5.1's 200 locals.
do
    local W, H, POINT, FADE, EDGE = 160, 304, 92, 18, 0.035
    local CLOTH_END, POINT_FROM = 1000 / 1588, 1190 / 1588       -- in the atlas's own height
    local X_OURS, X_THEIRS = 86, 282
    local CREAM, BRASS = { 0.957, 0.894, 0.757 }, { 1, 0.82, 0 }
    local FIGHTS, FIGHT_TOP, FIGHT_H = 4, 331, 38
    local BACK_ROOM = 22                                         -- folded, the way back over the banners
    local ALLIANCE = { flag = "charactercreate-factionflag-alliance", logo = "charcreatetest-logo-alliance",
        ink = { 0.11, 0.27, 0.51 }, onDark = { 0.45, 0.66, 1 } }
    local HORDE = { flag = "charactercreate-factionflag-horde", logo = "charcreatetest-logo-horde",
        ink = { 0.52, 0.08, 0.055 }, onDark = { 1, 0.38, 0.32 } }

    --- Our side, then theirs.
    local function Sides()
        if UnitFactionGroup and UnitFactionGroup("player") == "Horde" then return HORDE, ALLIANCE end
        return ALLIANCE, HORDE
    end

    --- Each side's colour on the page as the skin has it, ours first.
    function Versus.Inks()
        local ours, theirs = Sides()
        if GK.Classic() then return ours.onDark, theirs.onDark end
        return ours.ink, theirs.ink
    end

    local function OurName()
        if GK.shotGuild then return GK.shotGuild end            -- the screenshot mode's made-up guild (Shots.lua)
        local name = GetGuildInfo and GetGuildInfo("player")
        if type(name) == "string" and name ~= "" and not GK.Secret(name) then return name end
        return "Us"
    end

    --- One banner, its top at the body's, its middle at x.
    local function Banner(body, x, side)
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(side.flag)
        local file = info and (info.file or info.filename)
        local left, top, over = x - W / 2, H - POINT, H - POINT + FADE
        local cloth = {}
        if file and info.leftTexCoord then
            local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
            -- x and v are shares of the banner's width and of the art's height; y is down the page
            local function Part(sub, x0, x1, y0, y1, v0, v1, atTop, atFoot)
                local tex = body:CreateTexture(nil, "ARTWORK", nil, sub)
                tex:SetTexture(file)
                tex:SetTexCoord(l + (r - l) * x0, l + (r - l) * x1, t + (b - t) * v0, t + (b - t) * v1)
                tex:SetSize(W * (x1 - x0), y1 - y0)
                tex:SetPoint("TOPLEFT", body, "TOPLEFT", left + W * x0, -y0)
                if atTop then
                    tex:SetGradient("VERTICAL", CreateColor(1, 1, 1, atFoot), CreateColor(1, 1, 1, atTop))
                end
                cloth[#cloth + 1] = tex
            end
            local upper = CLOTH_END * top / over
            local lower = POINT_FROM + (1 - POINT_FROM) * FADE / POINT
            Part(0, 0, 1, 0, top, 0, upper)
            -- where they meet the point fades in over the cloth, whose middle stays whole under it; only its
            -- edges, and the shadow outside them, fade out
            Part(0, EDGE, 1 - EDGE, top, over, upper, CLOTH_END)
            Part(0, 0, EDGE, top, over, upper, CLOTH_END, 1, 0)
            Part(0, 1 - EDGE, 1, top, over, upper, CLOTH_END, 1, 0)
            Part(1, 0, 1, top, over, POINT_FROM, lower, 0, 1)
            Part(1, 0, 1, over, H, lower, 1)
        else
            local tex = body:CreateTexture(nil, "ARTWORK")
            tex:SetAtlas(side.flag)
            tex:SetSize(W, H)
            tex:SetPoint("TOPLEFT", body, "TOPLEFT", left, 0)
            cloth[1] = tex
        end
        local logo = body:CreateTexture(nil, "OVERLAY", nil, 1)
        logo:SetAtlas(side.logo)
        logo:SetSize(54, 64)
        logo:SetPoint("CENTER", body, "TOPLEFT", x, -36)
        -- these keep their colours in either skin, so never GK.Ink
        local function Word(y, font, size, colour)
            local fs = body:CreateFontString(nil, "OVERLAY", nil)
            GK.SetFont(fs, font, size)
            fs:SetTextColor(colour[1], colour[2], colour[3])
            fs:SetShadowColor(0, 0, 0, 1)
            fs:SetShadowOffset(1, -1)
            fs:SetWordWrap(false)
            fs:SetPoint("CENTER", body, "TOPLEFT", x, -y)
            return fs
        end
        local banner = { cloth = cloth, side = side,
            name = Word(81, GK.TITLE_FONT, 21, BRASS),
            score = Word(119, GK.TITLE_FONT, 56, CREAM),
            kills = Word(155, GK.TEXT_FONT, 10, CREAM),
            label = Word(176, GK.TEXT_FONT, 10, BRASS),
            who = Word(194, GK.TEXT_FONT, 14, CREAM),
            count = Word(211, GK.TEXT_FONT, 11, CREAM) }
        banner.kills:SetText("KILLS")
        banner.label:SetText("TOP KILLER")
        local line = body:CreateTexture(nil, "OVERLAY", nil, 1)
        line:SetColorTexture(BRASS[1], BRASS[2], BRASS[3], 0.55)
        line:SetSize(84, 1)
        line:SetPoint("CENTER", body, "TOPLEFT", x, -165)
        return banner
    end

    --- The text in the font, stepping down until it fits the width.
    local function Fit(fs, words, font, size, width)
        GK.SetFont(fs, font, size)
        fs:SetText(words)
        while size > 9 and TextWidth(fs) > width do
            size = size - 1
            GK.SetFont(fs, font, size)
        end
    end

    local function FightRow(body, i)
        local f = CreateFrame("Frame", nil, body)
        f:SetSize(360, FIGHT_H)
        f:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -(FIGHT_TOP + (i - 1) * FIGHT_H))
        f.stripe = f:CreateTexture(nil, "BACKGROUND")
        f.stripe:SetAllPoints()
        Paint(f.stripe, "stripe")
        f.stripe:SetShown(i % 2 == 1)
        f.bar = f:CreateTexture(nil, "ARTWORK")
        f.bar:SetSize(4, 30)
        f.bar:SetPoint("LEFT", 2, 0)
        f.face = MakePortrait(f, 32)
        f.face.tex:SetPoint("CENTER", f, "LEFT", 26, 0)
        f.line = f:CreateFontString(nil, "ARTWORK")
        Ink(f.line, INK, TEXT_FONT, 13)
        f.line:SetPoint("TOPLEFT", 48, -5)
        f.line:SetJustifyH("LEFT")
        f.line:SetWordWrap(false)
        f.zone = f:CreateFontString(nil, "ARTWORK")
        Ink(f.zone, FADED, TEXT_FONT, 10)
        f.zone:SetPoint("TOPLEFT", 48, -22)
        f.zone:SetWidth(220)
        f.zone:SetJustifyH("LEFT")
        f.zone:SetWordWrap(false)
        f.when = f:CreateFontString(nil, "ARTWORK")
        Ink(f.when, FADED, TEXT_FONT, 10)
        f.when:SetPoint("TOPRIGHT", -10, -22)
        return f
    end

    --- The page, made the first time a guild on watch is looked at, over the card's own place.
    function Versus.Build(book, detail, back)
        local page = CreateFrame("Frame", "GrudgekeeperVersus", book)
        page:SetFrameLevel(detail:GetFrameLevel())
        page:SetAllPoints(detail)                    -- the card's rect, also while the card is hidden
        page:Hide()
        page.back = CreateFrame("Button", nil, page)
        page.back:SetSize(220, 16)
        page.back:SetPoint("TOPLEFT", 10, -4)
        page.back.text = page.back:CreateFontString(nil, "ARTWORK")
        Ink(page.back.text, BLOOD, TEXT_FONT, 12)
        page.back.text:SetPoint("LEFT")
        page.back.text:SetText("\194\171 Back to grudges")
        page.back:SetScript("OnClick", back)
        local body = CreateFrame("Frame", nil, page)
        body:SetSize(PAGE_W, PAGE_H)
        body:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
        page.body = body
        local ours, theirs = Sides()
        page.ours, page.theirs = Banner(body, X_OURS, ours), Banner(body, X_THEIRS, theirs)
        local clash = body:CreateTexture(nil, "OVERLAY", nil, 2)
        clash:SetAtlas("Start-VersusSplash")
        clash:SetSize(96, 94)
        clash:SetPoint("CENTER", body, "TOPLEFT", 184, -122)
        page.vs = body:CreateFontString(nil, "OVERLAY")
        GK.SetFont(page.vs, GK.TITLE_FONT, 29)
        page.vs:SetTextColor(CREAM[1], CREAM[2], CREAM[3])
        page.vs:SetShadowColor(0, 0, 0, 1)
        page.vs:SetShadowOffset(1, -1)
        page.vs:SetPoint("CENTER", body, "TOPLEFT", 184, -123)
        page.vs:SetText("VS")
        page.verdict = body:CreateFontString(nil, "ARTWORK")
        Ink(page.verdict, BLOOD, TITLE_FONT, 19)
        page.verdict:SetPoint("CENTER", body, "TOPLEFT", PAGE_W / 2, -298)
        page.verdict:SetWordWrap(false)
        page.latest = body:CreateFontString(nil, "ARTWORK")
        Ink(page.latest, FADED, TEXT_FONT, 10)
        page.latest:SetPoint("LEFT", body, "TOPLEFT", 12, -320)
        page.latest:SetText("LATEST FIGHTS")
        page.since = body:CreateFontString(nil, "ARTWORK")
        Ink(page.since, FADED, TEXT_FONT, 9)
        page.since:SetPoint("RIGHT", body, "TOPLEFT", 356, -320)
        page.rule = body:CreateTexture(nil, "BORDER")
        Paint(page.rule, "rule")
        page.rule:SetSize(352, 1)
        page.rule:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -329)
        -- with no guild tracked: what this would be, and an officer's button
        page.call = body:CreateFontString(nil, "ARTWORK")
        Ink(page.call, INK, TEXT_FONT, 12)
        page.call:SetPoint("TOP", body, "TOPLEFT", PAGE_W / 2, -332)
        page.call:SetWidth(300)
        page.call:SetSpacing(3)
        page.track = GK.MakeButton(body, 150, 22)
        page.track:SetPoint("TOP", body, "TOPLEFT", PAGE_W / 2, -400)
        page.track:SetText("Track a guild")
        page.track:SetScript("OnClick", function() GK.OpenPicker("guild") end)
        -- their banner opens their card: who of theirs was seen, and an officer's Stop tracking. It was a click
        -- on the kill orders page's Watching line
        local seen = CreateFrame("Button", nil, body)
        seen:SetSize(W, H - POINT)
        seen:SetPoint("TOP", body, "TOPLEFT", X_THEIRS, 0)
        seen:SetScript("OnEnter", function(self)
            if not page.guild then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(page.guild)
            GameTooltip:AddLine("Click for who of theirs was seen lately.", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        seen:SetScript("OnLeave", function() GameTooltip:Hide() end)
        seen:SetScript("OnClick", function()
            local guild = page.guild
            if not guild then return end
            GK.ShowInLedger({ kind = "card", make = function() return GK.GuildCard(guild) end })
        end)
        page.seen = seen
        page.none = body:CreateFontString(nil, "ARTWORK")
        Ink(page.none, FADED, TEXT_FONT, 11)
        page.none:SetPoint("CENTER", body, "TOPLEFT", PAGE_W / 2, -380)
        page.none:SetText("No fight with them heard of yet.")
        page.fights = {}
        for i = 1, FIGHTS do page.fights[i] = FightRow(body, i) end
        return page
    end

    local function FillBanner(banner, name, score, top)
        Fit(banner.name, name, GK.TITLE_FONT, 21, 126)
        Fit(banner.score, tostring(score), GK.TITLE_FONT, 56, 112)
        Fit(banner.who, top and GK.Show(top.key) or "-", GK.TEXT_FONT, 14, 112)
        banner.count:SetText(top and Plural(top.n, "kill") or "")
    end

    --- One fight's row: who killed whom, each name in its side's colour, the zone and how long ago under it.
    local function FillFight(f, e, ours, theirs)
        local won = e.kind == "K"
        local side = won and ours or theirs
        f.bar:SetColorTexture(side[1], side[2], side[3], 0.9)
        f.face:Set({ key = e.n, c = e.c })
        local function Line(Who)
            local us = ("|cff%s%s|r"):format(Hex(ours), Who(e.who))
            local them = ("|cff%s%s|r"):format(Hex(theirs), Who(e.n))
            return ("%s |cff%skilled|r %s"):format(won and us or them, Hex(FADED), won and them or us)
        end
        local room = 300
        Ink(f.line, INK, TEXT_FONT, 13)
        f.line:SetText(Line(GK.Show))
        if TextWidth(f.line) > room then
            Ink(f.line, INK, TEXT_FONT, 12)
            if TextWidth(f.line) > room then f.line:SetText(Line(FirstName)) end
        end
        f.zone:SetText(e.z or "")
        f.when:SetText(GK.Ago(e.t))
    end

    function Versus.Fill(page, guild, folded)
        local us, them, rows = GK.GuildScore(guild)
        local top, topTheirs = GK.GuildTopKillers(rows)
        local name = OurName()
        page.guild = guild
        FillBanner(page.ours, name, us, top)
        FillBanner(page.theirs, guild or "Who's next?", guild and them or "?", topTheirs)
        local said = guild and "No blood yet" or "Pick a fight"
        if us > them then said = ("%s leads by %d"):format(name, us - them)
        elseif them > us then said = ("%s leads by %d"):format(guild, them - us)
        elseif us > 0 then said = "Dead even" end
        local size = 19
        Ink(page.verdict, BLOOD, TITLE_FONT, size)
        page.verdict:SetText(said)
        while size > 11 and TextWidth(page.verdict) > 344 do
            size = size - 1
            Ink(page.verdict, BLOOD, TITLE_FONT, size)
        end
        local _, _, since = GK.WatchedGuild()
        since = guild and tonumber(since) or nil
        page.since:SetText(since
            and ("Tracked since %d %s"):format(tonumber(date("%d", since)) or 0, date("%B", since)) or "")
        page.back:SetShown(folded)
        page.body:ClearAllPoints()
        page.body:SetPoint("TOPLEFT", page, "TOPLEFT", 0, folded and -BACK_ROOM or 0)
        local shown = folded and FIGHTS - 1 or FIGHTS          -- the fourth would stand past the page's foot
        local list = GK.LatestFights(guild, shown)
        local ours, theirs = Versus.Inks()
        for i, f in ipairs(page.fights) do
            f:SetShown(i <= shown and list[i] ~= nil)
            if i <= shown and list[i] then FillFight(f, list[i], ours, theirs) end
        end
        page.none:SetShown(guild ~= nil and #list == 0)
        page.latest:SetShown(guild ~= nil)
        page.rule:SetShown(guild ~= nil)
        page.call:SetShown(not guild)
        local officer = not guild and GK.CanWatchGuild and GK.CanWatchGuild() or false
        page.track:SetShown(officer)
        if not guild then
            page.call:SetText((officer and "Track an enemy guild" or "An officer or the guild master can track an enemy guild")
                .. " and it's us against them: the score, the top killers and the latest fights.")
        end
    end
end

local function Select(item)
    -- beside the versus page a row opens no profile ("ikke noe spiller profil når man trykker på de", the owner,
    -- 2026-11-22): folded it turns to that page, and a card pinned over it gives way
    local def = GK.LedgerPages[tab]
    if not pinned and not Folded() and def and def.versus and def.versus() then return end
    selected[tab], pinned = item.key, nil
    if Folded() then turned = true end
    GK.Sound("IG_ABILITY_PAGE_TURN")
    Refresh()
end

local function BuildRow(parent, i)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 4, -(LIST_TOP + (i - 1) * ROW_H))
    row:SetPoint("RIGHT", parent, "RIGHT", -6, 0)
    -- every other row a shade darker, so the eye keeps its line across (Refresh fills from the top, so
    -- the stripes stay put while the rows turn)
    row.stripe = row:CreateTexture(nil, "BACKGROUND", nil, -1)
    row.stripe:SetAllPoints()
    Paint(row.stripe, "stripe")
    row.stripe:SetShown(i % 2 == 0)
    row.wash = row:CreateTexture(nil, "BACKGROUND")
    row.wash:SetAllPoints()
    row.rule = row:CreateTexture(nil, "BORDER")            -- under a header row ("Most wanted") only
    Paint(row.rule, "rule")
    row.rule:SetHeight(1)
    row.rule:SetPoint("BOTTOMLEFT", 4, 0)
    row.rule:SetPoint("BOTTOMRIGHT", -4, 0)
    row.over = row:CreateTexture(nil, "BORDER")            -- over a row that starts a group of its own (it.rule)
    Paint(row.over, "rule", 0.6)
    row.over:SetHeight(1)
    row.over:SetPoint("TOPLEFT", NAME_X, 0)
    row.over:SetPoint("TOPRIGHT", -8, 0)
    row.mark = row:CreateTexture(nil, "ARTWORK")           -- the chosen row's red bar, at its start
    Paint(row.mark, "blood", 0.9)
    row.mark:SetPoint("TOPLEFT")
    row.mark:SetPoint("BOTTOMLEFT")
    row.mark:SetWidth(3)
    row.seal = row:CreateTexture(nil, "ARTWORK")
    row.seal:SetSize(24, 24)
    row.seal:SetPoint("LEFT", 2, 0)
    -- every font string gets its font HERE, not when filled: the game refuses SetText - even SetText("")
    -- - on one that has none, and a header row is filled before any player row ever was (2026-11-05)
    row.rank = row:CreateFontString(nil, "OVERLAY")
    Ink(row.rank, FADED, TITLE_FONT, 13)
    row.rank:SetPoint("CENTER", row.seal, "CENTER", 0, 0)
    row.face = MakePortrait(row, FACE)
    row.face.tex:SetPoint("CENTER", row, "LEFT", NAME_X - 19, 0)        -- FillRow moves it for a rank
    -- the eye of one on your Death list, on the face's lower left: the class crest has the lower right. 22 across: at 16
    -- it "kunne vært litt større" (the owner, 2026-11-20)
    row.eye = row:CreateTexture(nil, "OVERLAY", nil, 3)
    row.eye:SetTexture(MEDIA .. "eye")
    row.eye:SetSize(22, 22)
    row.eye:SetPoint("CENTER", row.face.tex, "BOTTOMLEFT", 3, 3)
    row.eye:Hide()
    row.name = row:CreateFontString(nil, "ARTWORK")
    -- the name in the game's plain type: Morpheus' small capitals at this size were "litt vanskelig å
    -- lese" in a list (the owner, 2026-11-06); the titles over the lists and on the card keep it
    Ink(row.name, INK, TEXT_FONT, 13)
    row.name:SetPoint("TOPLEFT", NAME_X, -4)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    -- what they are, in small type after the name ("35 Orc Rogue"), when it fits beside it
    row.desc = row:CreateFontString(nil, "ARTWORK")
    Ink(row.desc, FADED, TEXT_FONT, 10)
    row.desc:SetJustifyH("LEFT")
    row.desc:SetWordWrap(false)
    row.sub = row:CreateFontString(nil, "ARTWORK")
    Ink(row.sub, FADED, TEXT_FONT, 11)
    row.sub:SetPoint("TOPLEFT", NAME_X, -22)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    local function Col(x, justify)
        local fs = row:CreateFontString(nil, "ARTWORK")
        Ink(fs, INK, TEXT_FONT, 12)
        if justify == "RIGHT" then fs:SetPoint("RIGHT", row, "LEFT", x - 4, 0)
        elseif justify == "CENTER" then fs:SetPoint("CENTER", row, "LEFT", x - 4, 0)
        else fs:SetPoint("LEFT", row, "LEFT", x - 4, 0) end
        return fs
    end
    row.c1, row.c2, row.c3 = Col(COL1, "CENTER"), Col(COL2, "CENTER"), Col(BOARD_A, "CENTER")
    row.wide, row.right = Col(COL_WIDE), Col(COL_RIGHT, "RIGHT")
    -- a word under the first count, which then stands a little higher (FillRow): on Grudges, when
    -- they killed last under how often
    row.c1under = row:CreateFontString(nil, "ARTWORK")
    Ink(row.c1under, FADED, TEXT_FONT, 10)
    row.c1under:SetPoint("CENTER", row, "LEFT", COL1 - 4, -C1_UNDER)
    -- A grudge's score, read like a match's: "0 - 1", the leader's number in colour, and under it who
    -- leads. Two bare columns of 0 and 1 under YOU and THEY were "litt dårlig vist" (the owner,
    -- 2026-11-07), and their heading row stood over the page's own big headings.
    -- In the game's plain type: Morpheus' thin strokes left the faded number and the dash all but gone.
    row.score = row:CreateFontString(nil, "ARTWORK")
    Ink(row.score, INK, TEXT_FONT, 15)
    row.score:SetPoint("CENTER", row, "LEFT", SCORE_X, 5)
    row.lead = row:CreateFontString(nil, "ARTWORK")
    Ink(row.lead, FADED, TEXT_FONT, 10)
    row.lead:SetPoint("CENTER", row, "LEFT", SCORE_X, -10)
    -- a heading's own order, a word to click at its right ("most fought first"), where a page has no
    -- heading row
    row.order = row:CreateFontString(nil, "ARTWORK")
    Ink(row.order, FADED, TEXT_FONT, 10)
    row.order:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", COL_RIGHT - 4, 6)
    row.open = row:CreateFontString(nil, "ARTWORK")        -- folded: "this turns the page"
    Ink(row.open, FADED, TEXT_FONT, 13)
    row.open:SetPoint("RIGHT", -4, 0)
    row.open:SetText("\194\187")                            -- », in the game's Latin-1 fonts
    row:SetScript("OnClick", function(self)
        local it = self.item
        if it and not it.header then
            Select(it)
        elseif it and it.click then            -- a heading's order word: the next order
            it.click()
            Refresh()
        end
    end)
    -- The mouse on a row: its hover, and a tooltip where the row has more to say. Kept as row.enter too,
    -- for FillRow to put back when the page is drawn again under a still mouse (Rehover).
    local function Enter(self)
        self.hovered = true
        local it = self.item
        if it and not it.header and not self.chosen then Wash(self.wash, 0.07) end
        if it and it.header and it.click then
            Wash(self.wash, 0.05)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(it.clickTip or "Click to sort", 1, 1, 1)
            GameTooltip:Show()
            self.tipped = true
        elseif it and not it.header then
            -- Every row says what it is, whole: its name or line, what they are, and the line under it. Only a
            -- row the page had to cut had one, and next to a row with a tooltip a row without read as broken
            -- ("jeg prøver å vise hover og tooltip funker på en men ikke andre", the owner, 2026-11-14). Beside
            -- the ledger's left edge: at the row's right it lay over the card, the page that row opens. A
            -- player's name is in their class's colour - the tooltip is dark in either skin.
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("RIGHT", self, "LEFT", -TIP_GAP, 0)
            local c = it.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[it.class]
            if type(c) == "table" and c.r then
                GameTooltip:AddLine(it.name or "", c.r, c.g, c.b, true)
            else
                GameTooltip:AddLine(it.name or "", 1, 1, 1, true)
            end
            if it.desc and it.desc ~= "" then GameTooltip:AddLine(it.desc, 0.8, 0.8, 0.8) end
            if it.sub and it.sub ~= "" then GameTooltip:AddLine(it.sub, 0.8, 0.8, 0.8, true) end
            GameTooltip:Show()
            self.tipped = true
        end
    end
    row.enter = Enter
    row:SetScript("OnEnter", Enter)
    row:SetScript("OnLeave", function(self)
        self.hovered = false
        if self.fill then self.fill() end
        if self.tipped then
            self.tipped = false
            GameTooltip:Hide()
        end
    end)
    return row
end

--- A row drawn again while the mouse is on it gets its hover back, and a tooltip for what it says now.
--- Every guild message draws the page again (GRUDGEKEEPER_CHANGED), which puts each row's wash back to its
--- own, and the game sends no new OnEnter to a frame the mouse never left: the hover was gone until the
--- mouse left the row and came back, and a tooltip went on saying what the row said before ("ikke alltid
--- hover funker", the owner, 2026-11-14). Asked of the mouse itself, not only of what the row last heard:
--- a row hidden or turned away under the mouse may not have heard it leave.
local function Rehover(row)
    if not row.hovered then return end
    if row.tipped then
        row.tipped = false
        GameTooltip:Hide()
    end
    if row:IsMouseOver() then row.enter(row) else row.hovered = false end
end

local function FillRow(row, it, chosen)
    row.item, row.chosen = it, chosen
    local function Tint()
        if chosen then Wash(row.wash, 0.14)
        elseif it.mine then Wash(row.wash, 0.06)
        else row.wash:SetColorTexture(0, 0, 0, 0) end
    end
    row.fill = Tint
    Tint()
    if it.header then
        Ink(row.name, BLOOD, TITLE_FONT, 16)
        row.name:SetPoint("TOPLEFT", 12, -12)
        row.name:SetWidth(PAGE_W - 24)
        row.name:SetText(it.name)
        row.desc:SetText("")
        row.sub:SetText("")
        row.seal:Hide()
        row.rank:SetText("")
        row.face:SetShown(false)
        row.eye:Hide()
        row.mark:Hide()
        row.open:Hide()
        row.rule:Show()
        row.over:Hide()
        row.c1:SetText("") row.c2:SetText("") row.c3:SetText("") row.wide:SetText("") row.right:SetText("")
        row.c1under:SetText("")
        row.score:SetText("") row.lead:SetText("")
        row.order:SetText(it.order or "")
        row.cut = false
        Rehover(row)
        return
    end
    row.rule:Hide()
    row.over:SetShown(it.rule == true)
    row.order:SetText("")
    -- the score: the leader's number in their colour, the other faded, and who leads under it
    local sc = it.score
    if sc then
        local you, they = sc[1], sc[2]
        local tie, dim = Hex(INK), Hex(FADED)
        local mine = you > they and Hex(LEAD_YOU) or (you > 0 and you == they and tie or dim)
        local theirs = they > you and Hex(BLOOD) or (they > 0 and you == they and tie or dim)
        row.score:SetText(("|cff%s%d|r |cff%s-|r |cff%s%d|r"):format(mine, you, dim, theirs, they))
        -- by how much: "owed 3" is what it takes to stand even with them again (2026-11-20)
        if you > they then
            row.lead:SetText(("you lead %d"):format(you - they))
            row.lead:SetTextColor(LEAD_YOU[1], LEAD_YOU[2], LEAD_YOU[3])
        elseif they > you then
            row.lead:SetText(("owed %d"):format(they - you))
            row.lead:SetTextColor(BLOOD[1], BLOOD[2], BLOOD[3])
        else
            row.lead:SetText("even")
            row.lead:SetTextColor(FADED[1], FADED[2], FADED[3])
        end
    else
        row.score:SetText("")
        row.lead:SetText("")
    end
    local x0 = it.rank and NAME_X_RANKED or NAME_X
    row.face.tex:ClearAllPoints()
    row.face.tex:SetPoint("CENTER", row, "LEFT", x0 - 19, 0)
    row.name:SetPoint("TOPLEFT", x0, -4)
    row.sub:SetPoint("TOPLEFT", x0, -22)
    local rc = it.rightColour or (it.faded and FADED or INK)
    row.right:SetTextColor(rc[1], rc[2], rc[3])
    row.right:SetText(it.right or "")
    -- The name runs to whichever column is there. Before a right-hand number it stops at that number's
    -- own width, not a fixed 70 kept for "12g 34s": a "+2" in the news cut "Seedkek One" to "Seedke..."
    -- with half the row empty (2026-11-05), and a long sum ran past the fixed stop into the name. Before
    -- a score, short of the word under it ("owed 3", "you lead 12"), the widest thing there.
    local scoreStop = it.score and SCORE_X - math.max(32, math.ceil(TextWidth(row.lead) / 2) + 8)
    local stop = scoreStop or (it.c3 and BOARD_K - 20) or (it.c1 and COL1 - 20) or (it.wide and COL_WIDE - 8)
        or (it.right and COL_RIGHT - 4 - row.right:GetStringWidth() - 12) or (PAGE_W - 24)
    local room = stop - x0
    -- A line too long for its room steps down a size, then says its short form (first names only, where
    -- the item has one), and only then is cut - whole in the row's tooltip. "Hellig Bro added to the pot
    -- on Ikka Levici" lost its last name in the news (the owner, 2026-11-07).
    -- In the Classic skin a row that is one player's name is in their class's colour, and a line with
    -- names in it has each in its own (painted) - not a closed order's, which is faded as the past is.
    local colour = it.ink or (not it.faded and GK.ClassInk(it.class)) or (it.mine and BLOOD or (it.faded and FADED or INK))
    local painted = GK.Classic() and it.painted or nil
    local function Words(form) return painted and painted[form] or it[form] end
    Ink(row.name, colour, TEXT_FONT, 13)
    row.name:SetText(Words("name") or "")
    if TextWidth(row.name) > room then
        Ink(row.name, colour, TEXT_FONT, 12)
        if TextWidth(row.name) > room and it.short then row.name:SetText(Words("short")) end
        -- and for a line with several of us in it, the shortest: who and how many more (NewsItems)
        if TextWidth(row.name) > room and it.shortest then row.name:SetText(Words("shortest")) end
    end
    Ink(row.sub, it.noted and BLOOD or FADED, TEXT_FONT, 11)
    row.sub:SetText(it.sub or "")
    -- the line under the name stops short of a word under the first count, which is on its line
    local subRoom = it.c1under and math.min(room, COL1 - C1_UNDER_W - x0) or room
    row.cut = row.name:GetText() ~= (Words("name") or "") or TextWidth(row.name) > room or TextWidth(row.sub) > subRoom
    row.name:SetWidth(room)
    row.sub:SetWidth(subRoom)
    -- the description after the name's own width, only when all of it fits before the stop: a cut
    -- "35 Orc Ro..." says less than none, and the name keeps its room
    local nameW = math.ceil(TextWidth(row.name))
    row.desc:SetText(it.desc or "")
    local descW = math.ceil(TextWidth(row.desc))
    local fits = it.desc ~= nil and nameW + 6 + descW <= room
    row.desc:SetShown(fits)
    if fits then
        row.desc:ClearAllPoints()
        row.desc:SetPoint("BOTTOMLEFT", row, "TOPLEFT", x0 + nameW + 6, -18)
    end
    row.seal:SetShown(it.seal == true)
    if it.seal then row.seal:SetTexture(MEDIA .. "rank_" .. it.rank) end
    Ink(row.rank, it.seal and { 0.23, 0.14, 0.02 } or FADED, TITLE_FONT, it.seal and 12 or 13)
    row.rank:SetText(it.rank and tostring(it.rank) or "")
    row.face:SetShown(true)
    row.face:Set(it.face or {})
    row.eye:SetShown(it.eye == true)
    -- with a third count (the leaderboard) the first two move closer, to make it room
    row.c1:ClearAllPoints()
    row.c1:SetPoint("CENTER", row, "LEFT", (it.c3 and BOARD_K or COL1) - 4, it.c1under and C1_LIFT or 0)
    row.c1under:SetText(it.c1under or "")
    row.c2:ClearAllPoints()
    row.c2:SetPoint("CENTER", row, "LEFT", (it.c3 and BOARD_D or COL2) - 4, 0)
    local cc = it.c1Colour or INK
    row.c1:SetTextColor(cc[1], cc[2], cc[3])
    row.c1:SetText(it.c1 or "")
    row.c2:SetText(it.c2 or "")
    row.c3:SetText(it.c3 or "")
    row.wide:SetText(it.wide or "")
    row.mark:SetShown(chosen and not Folded())
    row.open:SetShown(Folded())
    Rehover(row)
end

local function BuildList(page)
    page.title = page:CreateFontString(nil, "ARTWORK")
    Ink(page.title, BLOOD, TITLE_FONT, 22)
    page.title:SetPoint("TOPLEFT", 10, -10)
    page.sub = page:CreateFontString(nil, "ARTWORK")
    Ink(page.sub, FADED, TEXT_FONT, 11)
    page.sub:SetPoint("TOPLEFT", 12, -44)
    page.sub:SetJustifyH("LEFT")
    page.sub:SetWordWrap(false)
    -- A choice of what the page shows - the leaderboard's This week and All time, Grudges' Killed me, Killed us
    -- most and the guild on watch, the News's All and Kill orders: an ink tab on the paper, in capitals, the chosen one
    -- in blood with a thick line under it, and a rule under the row of them (tabRule). The owner's pick from
    -- the mockup (2026-11-18), over a bronze switch and leather bookmarks; it took the place of the game's
    -- radio buttons ("liker ikke de stygge radiobuttonsa"). Ink links with a thin underline, before those,
    -- "det var vanskelig å se at det var tabs der" (2026-11-06): the rule under the row and the thick line
    -- are what make these read as tabs.
    local function Link(click)
        local b = CreateFrame("Button", nil, page)
        b:SetHeight(18)
        b.text = b:CreateFontString(nil, "ARTWORK")
        Ink(b.text, FADED, TEXT_FONT, 11)
        b.text:SetPoint("LEFT", 1, 1)
        b.mark = b:CreateTexture(nil, "ARTWORK")
        Paint(b.mark, "blood", 0.9)
        b.mark:SetHeight(2)
        b.mark:SetPoint("BOTTOMLEFT", 0, -3)
        b.mark:SetPoint("BOTTOMRIGHT", 0, -3)
        function b:Set(text, on)
            self.text:SetText(text:upper())
            self.on = on and true or false
            Ink(self.text, self.on and BLOOD or FADED, TEXT_FONT, 11)
            self.mark:SetShown(self.on)
            self:SetWidth(math.ceil(TextWidth(self.text)) + 2)
        end
        b:SetScript("OnClick", function(self)
            click(self)
            offset = 0
            Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            if not self.on then self.text:SetTextColor(INK[1], INK[2], INK[3]) end
            if self.tip then                                 -- what the tab's word stands for: the guild on watch
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.tip)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function(self)
            if not self.on then self.text:SetTextColor(FADED[1], FADED[2], FADED[3]) end
            if self.tip then GameTooltip:Hide() end
        end)
        return b
    end
    -- the page's own views, laid out from its links()
    page.links = {}
    for i = 1, 4 do
        page.links[i] = Link(function(self)
            self.click()
            -- another view of a page with views: its top name on the right, as when its tab is chosen
            if GK.LedgerPages[tab].views then selected[tab], pinned = nil, nil end
        end)
    end
    page.tabRule = page:CreateTexture(nil, "BORDER")
    Paint(page.tabRule, "rule")
    page.tabRule:SetHeight(1)
    page.tabRule:SetPoint("TOPLEFT", 8, -(TAB_INK_Y + 21))
    page.tabRule:SetPoint("TOPRIGHT", -8, -(TAB_INK_Y + 21))
    -- Only mine: the game's own checkbox, on the line under the title at the page's right, its words in
    -- ink after it. (Drawn in ink at the foot of the page it read as part of the page; the frame has real
    -- controls now, so this is one too - previewed 2026-11-06.)
    local mine = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
    mine:SetSize(22, 22)
    mine.label = page:CreateFontString(nil, "ARTWORK")
    Ink(mine.label, FADED, TEXT_FONT, 11)
    mine.label:SetPoint("LEFT", mine, "RIGHT", 1, 0)
    function mine:Set(text, on)
        self.label:SetText(text)
        self.on = on and true or false
        self:SetChecked(self.on)
        Ink(self.label, self.on and INK or FADED, TEXT_FONT, 11)
        self.width = 23 + math.ceil(TextWidth(self.label))
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", page, "TOPRIGHT", -(self.width + 6), -38)
    end
    mine:SetScript("OnClick", function()
        GK.db.mineOnly = not (GK.db.mineOnly == true)
        offset = 0
        Refresh()
    end)
    mine:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Only mine", 1, 1, 1)
        GameTooltip:AddLine("Only the rows that are yours: what you posted, backed, wrote or voted on.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    mine:SetScript("OnLeave", function() GameTooltip:Hide() end)
    mine:HookScript("OnShow", function(self) self.label:Show() end)
    mine:HookScript("OnHide", function(self) self.label:Hide() end)
    page.mine = mine
    -- The page's own action, where the eye starts: the game's red button on the title's line, at its
    -- right, naming what it does on this page ("Put someone on Shame"). Before, it was ink and a seal on the
    -- page, and "knapper osv ikke har noe tydelig 'jeg er en knapp'" (the owner, 2026-11-06); before that,
    -- three buttons at the foot of the page that said too little, where Post a kill order did nothing
    -- without a target. It opens the who-picker, so it works with no target.
    local add = GK.MakeButton(page, 110, 22)
    add:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, -14)
    function add:Set(def)
        self.def = def
        self:SetText(def.text)
        self:SetWidth(math.max(110, math.ceil(self:GetTextWidth() or 100) + 28))
    end
    add:SetScript("OnClick", function(self) GK.OpenPicker(self.def.kind) end)
    add:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.def.text, 1, 1, 1)
        GameTooltip:AddLine(self.def.kind == "guild" and "Type the guild's name, or pick one seen lately."
            or "Pick who: your target, someone you met lately, or type a name.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    add:SetScript("OnLeave", function() GameTooltip:Hide() end)
    page.add = add
    page.reset = page:CreateFontString(nil, "ARTWORK")    -- the links' tail, anchored after the last one shown
    Ink(page.reset, FADED, TEXT_FONT, 11)
    -- The column headings. One with a sort is a button: a click sorts by it, a second click goes back
    -- to the page's own order; the one in use is in blood and underlined, like a chosen link.
    page.heads = {}
    for i = 1, HEADS do
        local b = CreateFrame("Button", nil, page)
        b:SetHeight(14)
        b.text = b:CreateFontString(nil, "ARTWORK")
        Ink(b.text, FADED, TEXT_FONT, 10)
        b.text:SetPoint("LEFT")
        b.line = b:CreateTexture(nil, "ARTWORK")
        Paint(b.line, "blood", 0.7)
        b.line:SetHeight(1)
        b.line:SetPoint("BOTTOMLEFT", 0, -1)
        b.line:SetPoint("BOTTOMRIGHT", 0, -1)
        b:SetScript("OnClick", function(self)
            if not self.key then return end            -- a heading with only a tooltip to give
            GK.SortBy(GK.LedgerPages[tab], self.key)
            offset = 0
            Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            for n, line in ipairs(self.help and self.help() or {}) do
                if n == 1 then GameTooltip:AddLine(line, 1, 1, 1) else GameTooltip:AddLine(line, nil, nil, nil, true) end
            end
            if self.on then
                GameTooltip:AddLine("Click again for the page's own order", 1, 1, 1)
            elseif self.key then
                GameTooltip:AddLine("Sort by " .. (self.tip or self.text:GetText():lower()), 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        page.heads[i] = b
    end
    local underline = page:CreateTexture(nil, "BORDER")
    Paint(underline, "rule")
    underline:SetHeight(1)
    underline:SetPoint("TOPLEFT", 8, -(LIST_TOP - 4))
    underline:SetPoint("TOPRIGHT", -8, -(LIST_TOP - 4))
    page.underline = underline                         -- a page with no heading row has no line under it
    page.rows = {}
    for i = 1, MAX_ROWS do page.rows[i] = BuildRow(page, i) end        -- as many as any page shows (ListFrame)
    page.empty = page:CreateFontString(nil, "ARTWORK")
    Ink(page.empty, FADED, TEXT_FONT, 12)
    page.empty:SetPoint("TOPLEFT", 12, -(LIST_TOP + 12))
    page.empty:SetPoint("RIGHT", -24, 0)
    page.empty:SetJustifyH("LEFT")
    page.empty:SetSpacing(3)
    -- turning through a long list: the spellbook's page arrows at the foot, and the mouse wheel
    -- in the gap between the last row (58 up) and the buttons at the foot (32 up), its arrows 36 to 56 up:
    -- on the foot's line, Read all covered "1-9" and left "of 21" (the store pictures, 2026-11-10)
    page.count = page:CreateFontString(nil, "ARTWORK")
    Ink(page.count, FADED, TEXT_FONT, 10)
    page.count:SetPoint("BOTTOMRIGHT", -46, 16)
    local function Arrow(kind, dir)
        local b = CreateFrame("Button", nil, page)
        b:SetSize(20, 20)
        b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Up")
        b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Down")
        b:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. kind .. "Page-Disabled")
        b:SetScript("OnClick", function()
            offset = GK.TurnPage(page.starts, offset, dir)
            Refresh()
        end)
        return b
    end
    page.prev = Arrow("Prev", -1)
    page.prev:SetPoint("LEFT", page.count, "RIGHT", 2, 0)
    page.next = Arrow("Next", 1)
    page.next:SetPoint("LEFT", page.prev, "RIGHT", -2, 0)
    page:EnableMouseWheel(true)
    -- the wheel turns a page too: a few rows at a time left pages that began anywhere
    page:SetScript("OnMouseWheel", function(_, delta)
        offset = GK.TurnPage(page.starts, offset, delta > 0 and -1 or 1)
        Refresh()
    end)
    -- Letters and Settings are buttons in the title bar since 2026-11-18, beside the fold and the X (Build):
    -- at the foot of the list they were "litt i veien" (the owner), and the foot is the pager's.
end

-- Where the card's parts sit, in units from the page's top left. The ledger's right page has these; the
-- Inspect tab (Inspect.lua) has a smaller page and lays the same card out tighter, at the same type
-- sizes rather than scaled down (scaled to fit, 12pt ink came out under 10). h: the page's height, for
-- the buttons that follow the lines (else they sit at the foot). rich: the page has room for a card's
-- rich form (Profile.lua's d.rich, FillRich below): its tiles start tilesY down, and a fact's value
-- factX in. A card without one - a note card - is drawn as lines here too.
local DETAIL = { w = PAGE_W, h = PAGE_H, face = 84, faceX = 66, faceY = 76, bigY = 128, bigSize = 26,
    titleX = 124, titleY = 48, titleSize = 24, seal = 46, sealX = 26, sealY = 36, ruleY = 194, linesY = 206,
    padX = 24, valueX = 120, signY = 24, buttonY = 18, rich = true, tilesY = 130, factX = 128, third = true }

-- ---------------------------------------------------------------------------
-- The rich card: tiles, the way to the next title, and sections of facts, pairs or news, as previewed
-- with the owner (2026-11-06). Its texts and textures come from pools on the page and go back at every
-- fill, so a card with more rows than the last makes what it needs once and keeps it.
-- ---------------------------------------------------------------------------
local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"
local SEAL_INK = { 0.23, 0.14, 0.02 }         -- a number on a wax seal, as on the leaderboard's rows

local function Take(pool)
    pool.n = pool.n + 1
    local x = pool[pool.n]
    if not x then
        x = pool.make()
        pool[pool.n] = x
    end
    x:ClearAllPoints()
    x:Show()
    return x
end

local function Reset(pool)
    for i = 1, #pool do pool[i]:Hide() end
    pool.n = 0
end

--- A text's height, never less than its type size: offline (and for an empty string) it can say 0.
local function Height(fs, least) return math.max(least, fs:GetStringHeight() or 0) end

local function Text(page, colour, size, width, lines)
    local fs = Take(page.richParts.texts)
    Ink(fs, colour, TEXT_FONT, size)
    fs:SetWidth(width or 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(lines ~= 1)
    if fs.SetMaxLines then fs:SetMaxLines(lines or 0) end
    fs:SetSpacing(0)
    return fs
end

local function Flat(page, role, a, sub)
    local t = Take(page.richParts.paint)
    Paint(t, role, a)
    t:SetDrawLayer("BORDER", sub or 0)
    return t
end

--- A profile's Highlights ("denne delen på profiler kunne trengt litt mer fixing/styling", the owner, 2026-11-22):
--- the counts side by side, each over its name as the card's tiles are, and under them the nemesis with their
--- face and how often, in a row of their own. rows: { name, value, under, who (the nemesis's key), times }.
--- Down to where, and how many were drawn.
local function Highlights(page, rows, pad, inner, y, limit)
    local counts, nemesis, drawn = {}, nil, 0
    for _, row in ipairs(rows) do
        if row.who then nemesis = row else counts[#counts + 1] = row end
    end
    if #counts > 0 and y + 44 <= limit then
        local cell = inner / #counts
        for i, row in ipairs(counts) do
            local x = pad + (i - 0.5) * cell
            local n = Text(page, INK, 16)
            n:SetText(row[2])
            n:SetPoint("TOP", page, "TOPLEFT", x, -y)
            local name = Text(page, FADED, 9, cell - 4, 1)
            name:SetJustifyH("CENTER")
            name:SetText(row[1]:upper())
            name:SetPoint("TOP", page, "TOPLEFT", x, -(y + 19))
            local under = Text(page, FADED, 9, cell - 4, 1)
            under:SetJustifyH("CENTER")
            under:SetText(row[3] or "")
            under:SetPoint("TOP", page, "TOPLEFT", x, -(y + 31))
            if i > 1 then
                local div = Flat(page, "rule")
                div:SetPoint("TOPLEFT", page, "TOPLEFT", pad + (i - 1) * cell, -(y + 1))
                div:SetSize(1, 39)
            end
            drawn = drawn + 1
        end
        y = y + 48
    end
    if nemesis and y + 36 <= limit then
        local band = Flat(page, "stripe")
        band:SetPoint("TOPLEFT", page, "TOPLEFT", pad - 4, -y)
        band:SetSize(inner + 8, 36)
        local bar = Flat(page, "blood", 0.9, 1)
        bar:SetPoint("TOPLEFT", page, "TOPLEFT", pad - 4, -y)
        bar:SetSize(3, 36)
        local f = Take(page.richParts.faces)
        f:SetPoint("CENTER", page, "TOPLEFT", pad + 18, -(y + 18))
        f.face:Set({ key = nemesis.who })
        local room, stop = inner - 44, pad + inner - 4
        if nemesis.times then
            local n = Text(page, BLOOD, 17)
            n:SetText(nemesis.times)
            n:SetPoint("TOPRIGHT", page, "TOPLEFT", stop, -(y + 2))
            local under = Text(page, FADED, 9)
            under:SetText(nemesis[3] or "")
            under:SetPoint("TOPRIGHT", page, "TOPLEFT", stop, -(y + 22))
            room = room - math.ceil(math.max(TextWidth(n), TextWidth(under))) - 10
        end
        local head = Text(page, BLOOD, 9)
        head:SetText(nemesis[1]:upper())
        head:SetPoint("TOPLEFT", page, "TOPLEFT", pad + 40, -(y + 4))
        local name = Text(page, INK, 13, room, 1)
        name:SetText(nemesis[2])
        if TextWidth(name) > room then Ink(name, INK, TEXT_FONT, 11) end
        name:SetPoint("TOPLEFT", page, "TOPLEFT", pad + 40, -(y + 17))
        y = y + 36
        drawn = drawn + 1
    end
    return y, drawn
end

--- Draw d.rich on a page built with a rich layout. Returns how far down it went, for the buttons.
local function FillRich(page, d, L)
    local rich = d.rich
    local w, pad = L.w, L.padX
    local inner = w - 2 * pad
    local y = L.tilesY
    -- the tiles: a number, what it counts, and a line that says something about it
    local n = #rich.tiles
    if n > 0 then
        local tw = inner / n
        local tallest, divs = 0, {}
        for i, tile in ipairs(rich.tiles) do
            local v = Text(page, INK, 20)
            v:SetText(tile[1])
            v:SetPoint("TOP", page, "TOPLEFT", pad + (i - 0.5) * tw, -y)
            local k = Text(page, FADED, 9)
            k:SetText(tile[2]:upper())
            k:SetPoint("TOP", v, "BOTTOM", 0, -2)
            -- a zone's name may take two lines; a line under it (when the last was) has its own, so a
            -- long guild name is cut rather than pushing the time off the tile
            local s = Text(page, FADED, 10, tw - 6, tile[4] and 1 or 2)
            s:SetJustifyH("CENTER")
            s:SetText(tile[3] or "")
            s:SetPoint("TOP", k, "BOTTOM", 0, -2)
            local h = Height(v, 20) + Height(k, 10) + Height(s, 11) + 4
            if tile[4] then
                local s2 = Text(page, FADED, 10, tw - 6, 1)
                s2:SetJustifyH("CENTER")
                s2:SetText(tile[4])
                s2:SetPoint("TOP", s, "BOTTOM", 0, -1)
                h = h + Height(s2, 11) + 1
            end
            tallest = math.max(tallest, h)
            if i > 1 then
                local div = Flat(page, "rule")
                div:SetPoint("TOPLEFT", page, "TOPLEFT", pad + (i - 1) * tw, -(y + 2))
                divs[#divs + 1] = div
            end
        end
        for _, div in ipairs(divs) do div:SetSize(1, tallest - 2) end
        y = y + tallest + 12
    end
    -- the way to the next title
    local bar = rich.bar
    if bar then
        local track = Flat(page, "rule", 0.3)
        track:SetPoint("TOPLEFT", page, "TOPLEFT", pad, -y)
        track:SetSize(inner, 7)
        if bar.frac > 0 then
            local fill = Flat(page, "blood", 0.85, 1)
            fill:SetPoint("TOPLEFT", track, "TOPLEFT")
            fill:SetSize(math.max(1, math.min(1, bar.frac) * inner), 7)
        end
        local left = Text(page, FADED, 10)
        left:SetText(bar.left)
        left:SetPoint("TOPLEFT", page, "TOPLEFT", pad, -(y + 10))
        local right = Text(page, FADED, 10)
        right:SetText(bar.right)
        right:SetPoint("TOPRIGHT", page, "TOPLEFT", w - pad, -(y + 10))
        y = y + 35
    end
    -- the sections, as many as fit above the buttons and the signature: the last ones give way first
    local limit = L.h - L.signY - 22 - (#d.buttons > 0 and 34 or 0)
    for _, sec in ipairs(rich.sections) do
        if y + 32 > limit then break end
        local top, drawn = y, 0
        -- the section's name in red capitals, its rows' labels in plain grey words: in the same small grey
        -- capitals, every label read as one more heading (the owner, 2026-11-06)
        local head = Text(page, BLOOD, 10)
        head:SetText(sec.head:upper())
        head:SetPoint("TOPLEFT", page, "TOPLEFT", pad, -y)
        local after = pad + math.ceil(TextWidth(head)) + 6
        local line = Flat(page, "rule")
        line:SetPoint("TOPLEFT", page, "TOPLEFT", after, -(y + 5))
        local ruleTo, link = w - pad, nil
        if sec.edit then
            link = Take(page.richParts.links)
            link.run = sec.edit[2]
            link.text:SetText(sec.edit[1])
            local wide = math.ceil(TextWidth(link.text)) + 4
            link:SetSize(wide, 16)
            link:SetPoint("TOPRIGHT", page, "TOPLEFT", w - pad, -(y - 3))
            ruleTo = ruleTo - wide - 6
        end
        line:SetSize(math.max(1, ruleTo - after), 1)
        y = y + 17
        if sec.kind == "highlights" then
            y, drawn = Highlights(page, sec.rows, pad, inner, y, limit)
        elseif sec.kind == "events" then
            for i, e in ipairs(sec.rows) do
                if y + 28 > limit then break end
                if i % 2 == 0 then
                    local stripe = Flat(page, "stripe")
                    stripe:SetPoint("TOPLEFT", page, "TOPLEFT", pad - 4, -(y - 1))
                    stripe:SetSize(inner + 8, 30)
                end
                local icon = Take(page.richParts.icons)
                icon:SetSize(22, 22)
                icon:SetPoint("TOPLEFT", page, "TOPLEFT", pad, -(y + 3))
                local coords = e.c and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.c]
                if coords then
                    icon:SetTexture(CLASS_ICONS)
                    icon:SetTexCoord(unpack(coords))
                else
                    icon:SetTexture(MEDIA .. "portrait")
                    icon:SetTexCoord(0, 1, 0, 1)
                end
                local room = inner - 30
                if e.right then
                    local r = Text(page, INK, 12)
                    r:SetText(e.right)
                    r:SetPoint("TOPRIGHT", page, "TOPLEFT", w - pad, -(y + 8))
                    room = room - math.ceil(TextWidth(r)) - 10
                end
                local t = Text(page, INK, 12, room, 1)
                t:SetText(e.text)
                -- a line a size smaller before it is cut, as a row's name (FillRow)
                if TextWidth(t) > room then Ink(t, INK, TEXT_FONT, 11) end
                t:SetPoint("TOPLEFT", page, "TOPLEFT", pad + 30, -(y + 2))
                local s = Text(page, FADED, 10, room, 1)
                s:SetText(e.under or "")
                s:SetPoint("TOPLEFT", page, "TOPLEFT", pad + 30, -(y + 17))
                y = y + 30
                drawn = drawn + 1
            end
        else
            -- facts: a label in plain words, its value beside it, and after the value - on its line when it
            -- fits, else under it - a grey word on it ("best ever 11"); a row with no label is a paragraph
            local room = w - L.factX - pad
            for _, row in ipairs(sec.rows) do
                if y + 14 > limit then break end
                local k, v, more
                if row[1] then
                    k = Text(page, FADED, 11)
                    k:SetText(row[1])
                    k:SetPoint("TOPLEFT", page, "TOPLEFT", pad, -(y + 1))
                    v = Text(page, INK, 12, room)
                    v:SetPoint("TOPLEFT", page, "TOPLEFT", L.factX, -y)
                else
                    v = Text(page, INK, 12, inner)
                    v:SetPoint("TOPLEFT", page, "TOPLEFT", pad, -y)
                end
                v:SetSpacing(2)
                v:SetText(row[2] or "")
                local h = Height(v, 13)
                if row[1] and row[3] then
                    more = Text(page, FADED, 11, nil, 1)
                    more:SetText(row[3])
                    local used = math.ceil(TextWidth(v))
                    if h <= 16 and used + 8 + TextWidth(more) <= room then
                        more:SetPoint("TOPLEFT", page, "TOPLEFT", L.factX + used + 8, -(y + 1))
                    else
                        more:SetWidth(room)
                        more:SetPoint("TOPLEFT", page, "TOPLEFT", L.factX, -(y + h + 2))
                        h = h + 2 + Height(more, 11)
                    end
                end
                -- the whole row or none of it: its first line fitting said nothing of the second, and "died
                -- to them 5 / times" ran into the poster's buttons (the store pictures, 2026-11-10)
                if y + h > limit then
                    if k then k:Hide() end
                    v:Hide()
                    if more then more:Hide() end
                    break
                end
                y = y + math.max(18, h + 5)
                drawn = drawn + 1
            end
        end
        -- a heading whose first row did not fit goes too, and nothing after it fits either
        if drawn == 0 and #sec.rows > 0 then
            head:Hide()
            line:Hide()
            if link then link:Hide() end
            y = top
            break
        end
        y = y + 6
    end
    return y
end

local function BuildDetail(page, L)
    L = L or DETAIL
    page.layout = L
    page.back = CreateFrame("Button", nil, page)
    page.back:SetSize(220, 16)
    page.back:SetPoint("TOPLEFT", 24, -16)
    page.back.text = page.back:CreateFontString(nil, "ARTWORK")
    Ink(page.back.text, BLOOD, TEXT_FONT, 12)
    page.back.text:SetPoint("LEFT")
    page.back:SetScript("OnClick", function()
        turned = false
        Refresh()
    end)
    page.face = MakePortrait(page, L.face)
    page.face.tex:SetPoint("CENTER", page, "TOPLEFT", L.faceX, -L.faceY)
    page.big = page:CreateFontString(nil, "ARTWORK")
    Ink(page.big, BLOOD, TITLE_FONT, L.bigSize)
    page.big:SetPoint("TOP", page, "TOPLEFT", L.faceX, -L.bigY)
    page.caption = page:CreateFontString(nil, "ARTWORK")
    Ink(page.caption, INK, TEXT_FONT, 11)
    page.caption:SetPoint("TOP", page.big, "BOTTOM", 0, -1)
    page.seal = page:CreateTexture(nil, "ARTWORK")
    page.seal:SetSize(L.seal, L.seal)
    page.seal:SetPoint("TOPRIGHT", -L.sealX, -L.sealY)
    page.blood = page:CreateTexture(nil, "BORDER")
    page.blood:SetTexture(MEDIA .. "blood")
    page.blood:SetSize(170, 170)
    page.blood:SetPoint("CENTER", page, "RIGHT", -80, -10)
    page.blood:SetRotation(-0.5)
    page.blood:SetAlpha(0.4)
    page.title = page:CreateFontString(nil, "ARTWORK")
    Ink(page.title, BLOOD, TITLE_FONT, L.titleSize)
    page.title:SetPoint("TOPLEFT", L.titleX, -L.titleY)
    page.title:SetJustifyH("LEFT")
    page.title:SetWordWrap(false)                  -- one line: FillDetail steps the size down to fit
    page.name = page:CreateFontString(nil, "ARTWORK")
    Ink(page.name, INK, TITLE_FONT, 15)
    page.name:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -4)
    page.name:SetJustifyH("LEFT")
    page.name:SetWordWrap(false)
    page.info = page:CreateFontString(nil, "ARTWORK")
    Ink(page.info, FADED, TEXT_FONT, 11)
    page.info:SetPoint("TOPLEFT", page.name, "BOTTOMLEFT", 0, -3)
    page.info:SetJustifyH("LEFT")
    page.info:SetWordWrap(true)
    page.info:SetMaxLines(2)                       -- two at most: there is room for them over the tiles
    -- A page with room for the rich card: the small red line over the name, the number on a rank's wax
    -- seal, and the pools FillRich draws the rest from.
    if L.rich then
        page.kicker = page:CreateFontString(nil, "ARTWORK")
        Ink(page.kicker, BLOOD, TEXT_FONT, 10)
        page.kicker:SetPoint("BOTTOMLEFT", page.title, "TOPLEFT", 1, 2)
        page.sealNum = page:CreateFontString(nil, "OVERLAY")
        Ink(page.sealNum, SEAL_INK, TITLE_FONT, 16)
        page.sealNum:SetPoint("CENTER", page.seal, "CENTER", 0, 1)
        page.richParts = {
            texts = { n = 0, make = function() return page:CreateFontString(nil, "ARTWORK") end },
            paint = { n = 0, make = function() return page:CreateTexture(nil, "BORDER") end },
            icons = { n = 0, make = function() return page:CreateTexture(nil, "ARTWORK") end },
            faces = { n = 0, make = function()                   -- a portrait in a section's row (the nemesis)
                local f = CreateFrame("Frame", nil, page)
                f:SetSize(30, 30)
                f.face = MakePortrait(f, 30)
                f.face.tex:SetPoint("CENTER")
                return f
            end },
            links = { n = 0, make = function()                   -- a word to click on a section's heading (sec.edit)
                local b = CreateFrame("Button", nil, page)
                b.text = b:CreateFontString(nil, "ARTWORK")
                Ink(b.text, BLOOD, TEXT_FONT, 11)
                b.text:SetPoint("RIGHT")
                b:SetScript("OnClick", function(self) if self.run then self.run() end end)
                b:SetScript("OnEnter", function(self) self.text:SetTextColor(INK[1], INK[2], INK[3]) end)
                b:SetScript("OnLeave", function(self) self.text:SetTextColor(BLOOD[1], BLOOD[2], BLOOD[3]) end)
                return b
            end },
        }
    end
    -- below the portrait's number and its caption (on the ledger they end about 172 down)
    page.rule = page:CreateTexture(nil, "BORDER")
    Paint(page.rule, "rule")
    page.rule:SetHeight(1)
    page.rule:SetPoint("TOPLEFT", L.padX, -L.ruleY)
    page.rule:SetPoint("TOPRIGHT", -L.padX, -L.ruleY)
    page.labels, page.values = {}, {}
    for i = 1, 9 do
        local l = page:CreateFontString(nil, "ARTWORK")
        Ink(l, FADED, TEXT_FONT, 10)
        l:SetJustifyH("LEFT")
        local v = page:CreateFontString(nil, "ARTWORK")
        Ink(v, INK, TEXT_FONT, 12)
        v:SetJustifyH("LEFT")
        v:SetSpacing(2)
        page.labels[i], page.values[i] = l, v
    end
    page.sign = page:CreateFontString(nil, "ARTWORK")
    Ink(page.sign, INK, TITLE_FONT, 14)
    page.sign:SetPoint("BOTTOMRIGHT", -(L.padX + 2), L.signY)
    page.sign:SetText("- the Grudgekeeper")
    page.buttons = {}
    -- a third, under the first, where the layout has the room (third): a poster's Forget grudge. At its lowest
    -- it stands left of the signature, on its line, so it takes no room from the card's rows.
    for i = 1, L.third and 3 or 2 do
        local b = GK.MakeButton(page, 140, 22)
        if i == 1 then b:SetPoint("BOTTOMLEFT", L.padX, L.buttonY)
        elseif i == 2 then b:SetPoint("LEFT", page.buttons[1], "RIGHT", 6, 0)
        else b:SetPoint("TOPLEFT", page.buttons[1], "BOTTOMLEFT", 0, -4) end
        page.buttons[i] = b
    end
end

--- With no card, the page is blank but for the signature: no rule under nothing, and "choose a row" only
--- when the list has rows to choose (in the game it sat beside "0 open orders").
local function FillDetail(page, d, anyRows)
    local L = page.layout
    local rich = L.rich and d and d.rich or nil
    if page.richParts then
        for _, pool in pairs(page.richParts) do Reset(pool) end
        page.kicker:SetText("")
        page.sealNum:SetText("")
    end
    page.rule:SetShown(d ~= nil and not rich)
    if not d then
        page.face:SetShown(false)
        page.title:SetText("")
        page.name:SetText("")
        page.info:SetText(anyRows and "Choose a row on the left." or "")
        page.big:SetText("")
        page.caption:SetText("")
        page.seal:Hide()
        page.blood:Hide()
        for i = 1, #page.labels do page.labels[i]:SetText("") page.values[i]:SetText("") end
        for _, b in ipairs(page.buttons) do b:Hide() end
        return
    end
    page.face:SetShown(true)
    page.face:Set(d)
    -- the rich card's head: its kicker over the name, the name, and under it the title or the nemesis
    local title, sub, seal
    if rich then title, sub, seal = rich.head, rich.sub or "", rich.seal
    else title, sub, seal = d.title or "", d.name or "", d.seal end
    -- The title on one line, beside the seal (or to the edge without one): a long name steps down in size
    -- until it fits rather than breaking in two ("Kriger-" over "Skaalvik" in the Inspect tab, 2026-11-05).
    local room = L.w - L.titleX - (seal and (L.sealX + L.seal + 4) or L.padX)
    page.title:SetWidth(room)
    page.title:SetText(title)
    local size = L.titleSize
    Ink(page.title, BLOOD, TITLE_FONT, size)
    while size > 14 and TextWidth(page.title) > room do
        size = size - 1
        Ink(page.title, BLOOD, TITLE_FONT, size)
    end
    -- The name and what they are stop short of the seal as the title does: "Level 59 Windshaper Skyborne Warrior"
    -- ran under a kill order's seal ("overlapp på texten her", the owner's screenshot, 2026-11-20). The line
    -- under the name goes on to a second line where it is long.
    page.name:SetWidth(room)
    page.name:SetText(sub)
    page.info:SetWidth(room)
    -- what they are right under the name when nothing stands between (a poster's enemy who is no nemesis)
    page.info:ClearAllPoints()
    page.info:SetPoint("TOPLEFT", sub ~= "" and page.name or page.title, "BOTTOMLEFT", 0, -3)
    page.info:SetText((rich and rich.info) or d.info or "")
    page.big:SetText(rich and "" or (d.big or ""))
    page.caption:SetText(rich and "" or (d.caption or ""))
    page.seal:SetShown(seal ~= nil)
    if seal then page.seal:SetTexture(MEDIA .. seal) end
    page.blood:SetShown(d.blood == true)
    local y
    if rich then
        page.kicker:SetText((rich.kicker or ""):upper())
        page.sealNum:SetText(rich.sealNum or "")
        for i = 1, #page.labels do page.labels[i]:SetText("") page.values[i]:SetText("") end
        y = FillRich(page, d, L)
    else
        y = L.linesY
    end
    -- a card without a rich form, as lines: a short "Label: value" as two columns, anything else as a
    -- paragraph
    local lines = rich and {} or d.lines
    for i = 1, rich and 0 or #page.labels do
        local l, v = page.labels[i], page.values[i]
        local line = lines[i]
        l:ClearAllPoints()
        v:ClearAllPoints()
        if line then
            local label, value = Split(line)
            if label then
                l:SetPoint("TOPLEFT", L.padX, -(y + 2))
                l:SetText(label:upper())
                v:SetPoint("TOPLEFT", L.valueX, -y)
                v:SetWidth(L.w - L.valueX - L.padX)
            else
                l:SetText("")
                v:SetPoint("TOPLEFT", L.padX, -y)
                v:SetWidth(L.w - 2 * L.padX)
            end
            v:SetText(value)
            y = y + math.max(18, (v:GetStringHeight() or 14) + 6)
        else
            l:SetText("")
            v:SetText("")
        end
    end
    -- the buttons right under the lines, where the eye already is (at the foot of the page they sat
    -- under a hand's width of nothing) - but never down into the signature
    if L.h then
        local first = page.buttons[1]
        first:ClearAllPoints()
        first:SetPoint("TOPLEFT", L.padX, -math.min(y + 10, L.h - L.signY - 48))
    end
    for i, b in ipairs(page.buttons) do
        local spec = d.buttons[i]
        b:SetShown(spec ~= nil)
        if spec then
            b:SetText(spec[1])
            b:SetScript("OnClick", function()
                spec[2]()
                if page.refill then page.refill() else Refresh() end
            end)
        end
    end
end

--- The ledger's card on a page of someone else's (the Inspect tab): built with its own layout (see
--- DETAIL), filled from GK.RecordCard or GK.PosterCard; refill is called after one of its buttons.
function GK.BuildCardPage(page, layout, refill)
    BuildDetail(page, layout)
    page.back:Hide()
    page.refill = refill
end

function GK.FillCardPage(page, d) FillDetail(page, d, false) end

--- The ledger's own card at the ledger's size, on a page of someone else's: the profile window (Profile.lua),
--- which shows a player as the ledger's right page does. Filled with GK.FillCardPage.
function GK.BuildLedgerCard(page, refill)
    BuildDetail(page, DETAIL)
    page.back:Hide()
    page.refill = refill
end

--- The card a spec opens, as GK.ShowInLedger makes it: nil when there is nothing to show of it.
function GK.CardForSpec(spec) return DetailCard(spec) end

--- The parchment's tone (see Tone), for a page of ours drawn elsewhere.
GK.Tone = function(tex, r, g, b) Tone(tex, r, g, b) end

-- ---------------------------------------------------------------------------
-- The whole window
-- ---------------------------------------------------------------------------
--- The game's tabs under the frame, as the character window has them. Open, all of them: the enemy's
--- pages, then a step apart the friendly ones (side = "right"). Folded the window is one page wide, too
--- narrow for all of them: only the active page's group, then a step apart a last tab that switches to
--- the other group. Each tab at its words' width; if a row is still wider than the window, the chosen
--- tab keeps its width and the others share what is left (the game's own PanelTemplates_ResizeTabsToFit
--- does the same, but wants the tabs in one numbered row).
local TabSide                    -- made with the tabs' art, below: under the frame, or down its right side

--- The icon on a tab folded: ours as drawn, the game's cut round like ours - the square's border trimmed and
--- the round mask on (as Blizzard rounds an icon, AlertFrameSystems.lua) - so they sit together as medallions.
local function SetTabIcon(t, path)
    t.icon:SetTexture(path)
    local game = path:sub(1, #ICONS) == ICONS
    local a, b = game and 0.08 or 0, game and 0.92 or 1
    t.icon:SetTexCoord(a, b, a, b)
    if game and not t.iconMasked then
        t.icon:AddMaskTexture(t.iconMask)
    elseif not game and t.iconMasked then
        t.icon:RemoveMaskTexture(t.iconMask)
    end
    t.iconMasked = game
end

local function PlaceTabs(folded)
    local current = GK.LedgerPages[tab]
    local friends = current ~= nil and current.side == "right"
    local row = {}
    for _, t in ipairs(win.tabs) do
        local show = not folded or (t.side == "right") == friends
        t:SetShown(show)
        if show then row[#row + 1] = t end
    end
    win.swap:SetShown(folded)
    if folded then
        win.swap:SetText(friends and "Enemies" or "Friends")
        row[#row + 1] = win.swap
    end
    -- down the side only in the heavy art, which is drawn as a side tab; the game's thin art is not. Every
    -- tab, the hidden ones too, so none waits the other way round for the next fold
    local side = folded and win.swap.heavy ~= nil
    for _, t in ipairs(win.tabs) do TabSide(t, side) end
    TabSide(win.swap, side)
    for i, t in ipairs(row) do
        t.gap = (i > 1 and (t == win.swap or t.side ~= row[i - 1].side)) and GROUP_GAP or TAB_GAP
    end
    if side then
        -- down the right side, an icon each (TabSide); the switch shows the group it switches to
        SetTabIcon(win.swap, SWAP_ICON[friends and "Enemies" or "Friends"])
        for i, t in ipairs(row) do
            t:SetSize(TAB_BUTTON_H, SIDE_LEN)
            t:ClearAllPoints()
            if i == 1 then t:SetPoint("TOPLEFT", win, "TOPRIGHT", -TAB_TUCK, -SIDE_TOP)
            else t:SetPoint("TOPLEFT", row[i - 1], "BOTTOMLEFT", 0, -t.gap) end
        end
        return
    end
    local width, chosen = 0, nil
    for i, t in ipairs(row) do
        PanelTemplates_TabResize(t, TAB_PAD)
        width = width + t:GetWidth() + (i > 1 and t.gap or 0)
        if t.selected then chosen = t end
    end
    local room = (folded and FOLDED.W or OPEN.W) - 24
    if width > room and #row > 1 then
        local gaps = 0
        for i, t in ipairs(row) do if i > 1 then gaps = gaps + t.gap end end
        local share = math.floor((room - gaps - (chosen and chosen:GetWidth() or 0)) / (#row - (chosen and 1 or 0)))
        for _, t in ipairs(row) do
            if t ~= chosen then PanelTemplates_TabResize(t, TAB_PAD, share) end
        end
    end
    -- Open, the friendly pages sit at the frame's right edge, apart from the enemy's ("skyv shame og kudos
    -- lenger ut til høyre", the owner, 2026-11-07); folded under the frame (no heavy art), the row runs on
    -- from the left.
    local firstRight
    if not folded then
        for i, t in ipairs(row) do
            if t.side == "right" then firstRight = i break end
        end
    end
    for i, t in ipairs(row) do
        t:ClearAllPoints()
        if i == 1 then t:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 12, TAB_TUCK)
        elseif not firstRight or i < firstRight then t:SetPoint("TOPLEFT", row[i - 1], "TOPRIGHT", t.gap, 0) end
    end
    if firstRight then
        for i = #row, firstRight, -1 do
            local t = row[i]
            if i == #row then t:SetPoint("TOPRIGHT", win, "BOTTOMRIGHT", -12, TAB_TUCK)
            else t:SetPoint("TOPRIGHT", row[i + 1], "TOPLEFT", -row[i + 1].gap, 0) end
        end
    end
end

local function Layout()
    local folded = Folded()
    local b = folded and FOLDED or OPEN
    win:SetSize(b.W, b.H)
    -- the skin's background: the parchment, or in classic the frame's own panel, as Guildhall has it. The
    -- settings are on that dark panel in either skin, with no inner frame (the owner's pick A, 2026-11-22)
    if settingsOn or GK.Classic() then
        win.sheet:SetAtlas("heavybronze-frame-background")
        win.sheet:SetDesaturation(0)
        win.sheet:SetVertexColor(1, 1, 1)
    else
        win.sheet:SetTexture(MEDIA .. (folded and "sheet_single" or "sheet_wide"))
        win.sheet:SetTexCoord(0, 1, 0, 1)            -- an atlas before it leaves its corner of the art behind
        Tone(win.sheet)
    end
    win.divider:SetShown(not folded)                 -- folded there is one page: nothing to divide
    if settingsOn then win.divider:Hide() end        -- the settings draw their own, at the menu's edge
    win.inner:SetShown(not settingsOn)
    -- folded, the tabs down the right side stay on the screen with the frame (PlaceTabs)
    win:SetClampRectInsets(0, folded and -(TAB_H_ON - TAB_TUCK) or 0, 0, 0)
    win.list:ClearAllPoints()
    win.list:SetPoint("TOPLEFT", b.x, -b.y)
    win.detail:ClearAllPoints()
    win.detail:SetPoint("TOPLEFT", folded and b.x or b.x2, -b.y)
    PlaceTabs(folded)
    win.fold:Set(folded)
end

-- a switch of skin (Core.lua's GK.SetLook) redraws the texts and lines; the background and panels are ours
GK.OnLook(function()
    if not win then return end
    Layout()
    Refresh()
end)

--- Keep the left edge where it is when the window changes width: anchor it by its top left first.
local function KeepLeft()
    local l, t = win:GetLeft(), win:GetTop()
    if l and t then
        win:ClearAllPoints()
        win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    end
end

local function Fold(on)
    GK.db.ledgerFolded = on or nil
    turned = false
    if settingsOn then SetSettings(false) end        -- the fold is the ledger's: back to its pages
    KeepLeft()
    Layout()
    Refresh()
end

--- One of the heavy art's atlases over a tab (HEAVY, at the top), cut in six: two rows - what stretches with
--- the tab's height, then the cut corners - by three columns - a corner, what stretches with its width, a
--- corner. Under the frame turned a quarter clockwise: the art's x runs down the tab, its y from the tab's
--- right to its left. Down the frame's side as it lies (HeavyCoords): its x across the tab, its y down it.
local function HeavyPieces(t, info, layer, sub, cut, fade)
    local l, r, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local function U(x) return l + (r - l) * x / HEAVY_SIZE end
    local function V(y) return top + (bottom - top) * y / HEAVY_SIZE end
    local S, C = HEAVY_SIZE, HEAVY_CORNER
    local rows, cols = { { cut, S - C }, { S - C, S } }, { { S - C, S }, { C, S - C }, { 0, C } }
    -- with a fade, a short row of its own on top, as long on screen as in the art (TabLook)
    if fade then rows = { { cut, cut + fade }, { cut + fade, S - C }, { S - C, S } } end
    local set = { fade = fade }
    for i, x in ipairs(rows) do
        set[i] = {}
        for j, y in ipairs(cols) do
            local p = t:CreateTexture(nil, layer, nil, sub)
            p:SetTexture(info.file or info.filename)
            p.u, p.v = { U(x[1]), U(x[2]) }, { V(y[1]), V(y[2]) }      -- its piece of the art (HeavyCoords)
            set[i][j] = p
        end
    end
    return set
end

--- The pieces' corners of the art for the way the tab hangs (t.sideways): under the frame the art a quarter
--- turned clockwise; down its right side the art as it lies, as drawn - square side against the frame, cut
--- corners out. The glow's short fade from the frame's edge goes with it: down from the top, or across from
--- the left (HeavyTab says why it fades).
local function HeavyCoords(t)
    local side = t.sideways
    for key, set in pairs(t.heavy) do
        local full = key == "hover" and HOVER_ALPHA or 1
        for i, row in ipairs(set) do
            for _, p in ipairs(row) do
                local u, v = p.u, p.v
                if side then
                    p:SetTexCoord(u[1], u[2], v[1], v[2])
                else
                    -- top left, bottom left, top right, bottom right: the art's bottom left, bottom right,
                    -- top left, top right - the quarter turn
                    p:SetTexCoord(u[1], v[2], u[2], v[2], u[1], v[1], u[2], v[1])
                end
                if set.fade and i == 1 then
                    if side then
                        p:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, full))
                    else
                        p:SetGradient("VERTICAL", CreateColor(1, 1, 1, full), CreateColor(1, 1, 1, 0))
                    end
                end
            end
        end
    end
end

--- Forever's heavy art in place of the tab's thin art: false, and the tab left as the game draws it, when
--- the client has any of the three missing (the client's data has all three, build 70425).
local function HeavyTab(t)
    local info = {}
    for key, atlas in pairs(HEAVY) do
        info[key] = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
        if not (info[key] and (info[key].file or info[key].filename)) then return false end
    end
    t.heavy = {
        ground = HeavyPieces(t, info.ground, "BACKGROUND", 1, HEAVY_CUT),
        glow = HeavyPieces(t, info.glow, "BORDER", 0, GLOW_CUT, GLOW_FADE),
        edge = HeavyPieces(t, info.edge, "BORDER", 1, HEAVY_CUT),
        hover = HeavyPieces(t, info.glow, "HIGHLIGHT", 0, GLOW_CUT, GLOW_FADE),
    }
    for i, row in ipairs(t.heavy.hover) do
        for _, p in ipairs(row) do
            p:SetBlendMode("ADD")
            if i > 1 then p:SetAlpha(HOVER_ALPHA) end        -- the fade's row has it in its gradient, below
        end
    end
    -- The glow begins where the frame's edge ends (TabLook) and fades in from nothing there, over its top
    -- GLOW_FADE. Begun there at full it stopped hard against the edge: "hover gløden har litt hard kant
    -- opp mot ramma ... ser cutoff" (the owner, 2026-11-08). Begun behind the edge instead it showed
    -- through the edge's lower band, which is not solid ("nope", the owner's screenshot the same day: the
    -- band yellow over the tab's sides only). Faded down the whole of the sides, they were brightest just
    -- over the cut corners, which begin at full - "fortsatt en strek midt over gløden?" (the next
    -- screenshot: 115 then 60 across that seam). A gradient's first colour is its bottom, as the game's
    -- nameplates fade theirs (Blizzard_NamePlates.lua) - and as those screenshots showed, brighter down.
    -- The hover's faintness goes into the gradient itself: with SetAlpha as well, the fade's row ended at
    -- full, about twice the rest of the hover glow ("fortsatt glød cut midt på?", the owner, 2026-11-09:
    -- 97 then 49 across that seam, as 1 to 0.45) - the gradient's colours carry an alpha, and it won.
    HeavyCoords(t)
    -- the game's thin art and its glow stay, unseen: the tab's least width is theirs (PanelTemplates_TabResize)
    for _, k in ipairs({ "Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
        "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
        if type(t[k]) == "table" then t[k]:SetAlpha(0) end
    end
    return true
end

--- The heavy art laid out for the tab's state: the chosen tab longer and lit, as the game's own chosen
--- tab is longer. The glow, lit or hover, starts below the frame's edge (HeavyTab says why).
local function TabLook(t)
    local on = t.selected and true or false
    -- the icon (folded, down the side) in the middle of what shows of the tab, as far out from the edge as
    -- the words under the frame sit down from it: 1 toward the edge, and 2 out on the chosen, longer tab
    t.icon:SetPoint("CENTER", t, "CENTER", on and -TAB_TEXT_Y_ON or -TAB_TEXT_Y, 0)
    if not t.heavy then return end
    local h, C = on and TAB_H_ON or TAB_H, HEAVY_CORNER
    for key, set in pairs(t.heavy) do
        local from = (key == "glow" or key == "hover") and TAB_TUCK or 0
        -- the rows' depths out from the frame's edge: the fade's own (the glow), what stretches, the cut
        -- corners - down the tab under the frame, across it down the frame's side
        local tall = set.fade and { set.fade, h - C - from - set.fade, C } or { h - C - from, C }
        local at = from
        for i, row in ipairs(set) do
            for j, p in ipairs(row) do
                p:ClearAllPoints()
                if t.sideways then
                    -- a row of the art is a column here, its three pieces down the tab: the art's bottom
                    -- (piece 1) at the tab's bottom, what stretches with the tab's length between the corners
                    p:SetWidth(tall[i])
                    if j == 2 then
                        p:SetPoint("TOPLEFT", t, "TOPLEFT", at, -C)
                        p:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", at, C)
                    else
                        local corner = j == 1 and "BOTTOMLEFT" or "TOPLEFT"
                        p:SetHeight(C)
                        p:SetPoint(corner, t, corner, at, 0)
                    end
                else
                    p:SetHeight(tall[i])
                    if j == 2 then
                        p:SetPoint("TOPLEFT", t, "TOPLEFT", C, -at)
                        p:SetPoint("TOPRIGHT", t, "TOPRIGHT", -C, -at)
                    else
                        p:SetWidth(C)
                        p:SetPoint(j == 1 and "TOPLEFT" or "TOPRIGHT", t, j == 1 and "TOPLEFT" or "TOPRIGHT", 0, -at)
                    end
                end
            end
            at = at + tall[i]
        end
    end
    for _, row in ipairs(t.heavy.glow) do
        for _, p in ipairs(row) do p:SetShown(on) end
    end
end

--- Hang a tab under the frame (side false) or down its right side (side true, folded): the art turned or as
--- it lies (HeavyCoords), and its words, or down the side its icon in their place (Tab, SetTabIcon).
TabSide = function(t, side)
    side = side and true or false
    if t.sideways == side then return end
    t.sideways = side
    t.Text:SetShown(not side)
    t.icon:SetShown(side)
    if not side then t:SetHeight(TAB_BUTTON_H) end
    if t.heavy then HeavyCoords(t) end
    TabLook(t)
end

--- The settings up in the ledger (on), or its pages again. While they are up no tab is chosen, so every
--- one of them is a way back; the Settings button stays pressed in, and a click on it goes back as well.
SetSettings = function(on)
    settingsOn = on and true or false
    win.settingsPage:SetShown(settingsOn)
    win.settings:SetButtonState(settingsOn and "PUSHED" or "NORMAL", settingsOn)
    for j, t in ipairs(win.tabs) do
        t.selected = not settingsOn and j == tab
        if t.selected then PanelTemplates_SelectTab(t) else PanelTemplates_DeselectTab(t) end
        TabLook(t)
    end
end

--- Out of the settings to the page they lay over, folded again if it was (the settings are two pages wide).
local function LeaveSettings()
    if not settingsOn then return end
    SetSettings(false)
    KeepLeft()
    Layout()
end

local function SelectTab(i)
    -- the tab of the page under the settings: back to that page as it was
    if settingsOn and i == tab then
        LeaveSettings()
        return Refresh()
    end
    LeaveSettings()
    tab, offset, turned = i, 0, false
    -- ...and on the right page the top name of its list, not the row chosen there the last time it was up:
    -- "når vi bytter tabs, burde høyre page swappe til top navn i hvilken enn liste den tabben har" (the
    -- owner, 2026-11-14). Whatever opens a page on a row of its own (GK.OpenOrder, GK.ShowLedgerPage) sets
    -- it after this; the window opened again with no page asked for (GK.OpenWindow()) keeps what it had.
    selected[i], pinned = nil, nil
    -- the game's chosen look on its tab: raised and joined to the frame, and not clickable again
    SetSettings(false)
    PlaceTabs(Folded())                              -- folded, the row shows the group of the page
    Refresh()
end

--- A frame drawn from an atlas cut in nine, so its corners stay as drawn at any size - the ledger open is
--- far wider than the art, folded much narrower. corner: the corner pieces, in the art's pixels and on
--- screen. Without the atlas' numbers it is the art stretched whole, as Skillwright draws it.
--- The art is common-insideframe (107 x 107 in Forever): the profession window's inner panel, thin lines
--- with a small curl at each corner, see-through inside - the frame the owner pointed at in Skillwright
--- (2026-11-06). Options_InnerFrame was tried first and is a filled panel: it laid a second sheet, out of
--- place, over the page ("nå er det blitt skikkelig ødelagt").
local function InnerFrame(parent, atlas, corner)
    local f = CreateFrame("Frame", nil, parent)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    local file = info and (info.file or info.filename)
    if not (file and (info.width or 0) > 2 * corner and (info.height or 0) > 2 * corner) then
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetAtlas(atlas)
        return f
    end
    local du = (info.rightTexCoord - info.leftTexCoord) * corner / info.width
    local dv = (info.bottomTexCoord - info.topTexCoord) * corner / info.height
    local u = { info.leftTexCoord, info.leftTexCoord + du, info.rightTexCoord - du, info.rightTexCoord }
    local v = { info.topTexCoord, info.topTexCoord + dv, info.bottomTexCoord - dv, info.bottomTexCoord }
    f.file, f.u, f.v, f.corner = file, u, v, corner           -- for a line in the same art (the divider)
    local function Piece(col, row)
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetTexture(file)
        t:SetTexCoord(u[col], u[col + 1], v[row], v[row + 1])
        return t
    end
    local tl, tr, bl, br = Piece(1, 1), Piece(3, 1), Piece(1, 3), Piece(3, 3)
    for _, c in ipairs({ { tl, "TOPLEFT" }, { tr, "TOPRIGHT" }, { bl, "BOTTOMLEFT" }, { br, "BOTTOMRIGHT" } }) do
        c[1]:SetSize(corner, corner)
        c[1]:SetPoint(c[2])
    end
    local top, bottom, left, right = Piece(2, 1), Piece(2, 3), Piece(1, 2), Piece(3, 2)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    return f
end

--- One of the game's tabs under the frame. Its size and place are PlaceTabs' alone: the template's own
--- OnShow and OnEvent size it to its words again, which undid a row squeezed to fit the folded window.
--- It sits at the frame's own level, under its edge (Build raises the edge), in Forever's heavy art
--- (HeavyTab), its text in the middle of what shows; the game's select and deselect read the two offsets.
local function Tab(text, onClick, icon)
    local t = CreateFrame("Button", nil, win, "PanelTabButtonTemplate")
    t:SetFrameLevel(win:GetFrameLevel())
    t.deselectedTextY, t.selectedTextY = TAB_TEXT_Y, TAB_TEXT_Y_ON
    t:SetText(text)
    t:SetScript("OnShow", nil)
    t:SetScript("OnEvent", nil)
    t:SetScript("OnClick", function(self)
        GK.Sound("IG_CHARACTER_INFO_TAB")
        onClick(self)
    end)
    -- folded, down the frame's side: an icon in its words' place (TabSide), and its name on the mouse
    t.icon = t:CreateTexture(nil, "ARTWORK")
    t.icon:SetSize(TAB_ICON, TAB_ICON)
    t.icon:Hide()
    t.iconMask = t:CreateMaskTexture()
    t.iconMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    t.iconMask:SetAllPoints(t.icon)
    SetTabIcon(t, icon or (ICONS .. "INV_Misc_QuestionMark"))       -- a page that brought none
    t:HookScript("OnEnter", function(self)
        if not self.sideways then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self:GetText() or "")
        GameTooltip:Show()
    end)
    t:HookScript("OnLeave", function(self)
        if self.sideways then GameTooltip:Hide() end
    end)
    HeavyTab(t)
    TabLook(t)
    return t
end

local function Build()
    -- The game's own frame: its bronze edges, title bar and X. Its flat grey backdrop gives way to the
    -- parchment, where Guildhall puts its wood panel.
    win = CreateFrame("Frame", "GrudgekeeperFrame", UIParent, "SettingsFrameTemplate")
    win:SetSize(OPEN.W, OPEN.H)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetPoint("CENTER", 0, 30)
    if type(win.Bg) == "table" then win.Bg:Hide() end
    if type(win.NineSlice) == "table" and win.NineSlice.Text then win.NineSlice.Text:SetText("Grudgekeeper") end
    win.sheet = win:CreateTexture(nil, "BACKGROUND")       -- the look's background (Layout)
    win.sheet:SetPoint("TOPLEFT", 7, -18)
    win.sheet:SetPoint("BOTTOMRIGHT", -3, 3)
    -- what is written on the pages (+3), the fold beside the X (the X's own level)
    local level = win:GetFrameLevel()
    win.list = CreateFrame("Frame", nil, win)
    win.list:SetFrameLevel(level + 3)
    win.list:SetSize(PAGE_W, PAGE_H)
    BuildList(win.list)
    win.detail = CreateFrame("Frame", nil, win)
    win.detail:SetFrameLevel(level + 3)
    win.detail:SetSize(PAGE_W, PAGE_H)
    BuildDetail(win.detail)
    -- the settings' page (Options.lua draws on it): the whole frame, as their own window was, so what is
    -- on it sits where it sat there
    win.settingsPage = CreateFrame("Frame", "GrudgekeeperSettings", win)
    win.settingsPage:SetFrameLevel(level + 3)
    win.settingsPage:SetAllPoints()
    win.settingsPage:Hide()
    -- One thin inner frame round both pages, the profession window's own as Skillwright has it
    -- (common-insideframe, its corners kept as drawn at any size), and one line between the pages. Two
    -- bronze inset boxes, one per page, "ser litt rart ut" - "hva med den tynne rammen som hadde litt
    -- border pynt? ... bare en strek som deler hver side" (the owner, 2026-11-06). Over the sheet, under
    -- the pages.
    win.inner = InnerFrame(win, "common-insideframe", 32)
    win.inner:SetFrameLevel(level + 2)
    win.inner:SetPoint("TOPLEFT", FX - 8, -(FY - 6))
    win.inner:SetPoint("BOTTOMRIGHT", -(FX - 8), FB - 8)
    -- The line between the pages, in the same art: a strip of the frame's own left edge, run from its top
    -- line to its bottom one down the middle. The edge's line sits LINE_X in from the piece's outer side
    -- (measured on the owner's screenshot, 2026-11-06: about 3.5 of its 32), so the strip starts that much
    -- left of the middle, and is only as wide as the line and its shading. (The Settings window's
    -- divider stood on end was tried first and drew nothing.)
    local LINE_X, STRIP = 4, 8
    local mid = FX + PAGE_W + FGAP / 2 - (FX - 8)            -- the middle, from the inner frame's left
    win.divider = win.inner:CreateTexture(nil, "ARTWORK")
    if win.inner.file then
        local u, v = win.inner.u, win.inner.v
        win.divider:SetTexture(win.inner.file)
        win.divider:SetTexCoord(u[1], u[1] + (u[2] - u[1]) * STRIP / win.inner.corner, v[2], v[3])
    else
        Paint(win.divider, "rule")
    end
    win.divider:SetWidth(STRIP)
    win.divider:SetPoint("TOPLEFT", win.inner, "TOPLEFT", mid - LINE_X, -LINE_X)
    win.divider:SetPoint("BOTTOMLEFT", win.inner, "BOTTOMLEFT", mid - LINE_X, LINE_X)
    -- the tabs (PlaceTabs puts them under the frame)
    win.tabs = {}
    for i, def in ipairs(GK.LedgerPages) do
        local t = Tab(def.name, function() SelectTab(i) end, def.icon)
        t.side = def.side
        win.tabs[i] = t
    end
    -- folded: the last tab of the row, which switches to the other group of pages
    win.swap = Tab("Friends", function()
        local toRight = not (GK.LedgerPages[tab] and GK.LedgerPages[tab].side == "right")
        for i, def in ipairs(GK.LedgerPages) do
            if (def.side == "right") == toRight then return SelectTab(i) end
        end
    end)
    PanelTemplates_DeselectTab(win.swap)
    win.swap:Hide()
    -- The frame's edge over the tabs' tops (they are at the frame's own level, Tab), and under the inner
    -- frame and the pages as before. The template makes it at the frame's own level too.
    if type(win.NineSlice) == "table" then win.NineSlice:SetFrameLevel(level + 1) end
    -- the template's X: its click is our own, as the template's HideUIPanel does nothing in combat. Over
    -- the edge, now the edge is raised: the X sits on its corner.
    local close = type(win.ClosePanelButton) == "table" and win.ClosePanelButton
        or CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetScript("OnClick", function() win:Hide() end)
    close:SetFrameLevel(level + 4)
    win.close = close
    -- The fold: the spells panel's own button beside the X (the owner's screenshot, 2026-11-06), the
    -- game's red square with the arrow - out to open the window, in to fold it to one page. Its own
    -- button with the template's atlases, not MaximizeMinimizeButtonFrameTemplate: that one keeps a state
    -- of its own and resets it from a CVar on show, and ours is GK.db.ledgerFolded. Against the X, 1 apart,
    -- as the world map and the spells panel have theirs.
    local fold = CreateFrame("Button", nil, win)
    fold:SetFrameLevel(close:GetFrameLevel())
    fold:SetPoint("RIGHT", close, "LEFT", -1, 0)
    fold:SetSize(24, 24)
    fold:SetHighlightAtlas("RedButton-Highlight", "ADD")
    function fold:Set(folded)
        local art = folded and "RedButton-Expand" or "RedButton-Condense"
        self:SetNormalAtlas(art)
        self:SetPushedAtlas(art .. "-Pressed")
        self.tip = folded and "Show both pages" or "Fold to one page"
    end
    fold:SetScript("OnClick", function()
        GK.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
        Fold(not Folded())
    end)
    fold:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.tip or "Fold to one page", 1, 1, 1)
        GameTooltip:Show()
    end)
    fold:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.fold = fold
    -- Letters and Settings, the same red squares beside the fold (art/make_grudgekeeper_buttons.py: the game
    -- has no gear or letter in that series), with the game's own glow on them. At the foot of the list they
    -- were "litt i veien" (the owner, 2026-11-18): "bedre å ha noe top right?" A count on the letters while
    -- some are unread; a right-click reads them all, as Read all at the foot did.
    local function TitleButton(art, anchor, tip, onClick)
        local b = CreateFrame("Button", nil, win)
        b:SetFrameLevel(close:GetFrameLevel())
        b:SetSize(24, 24)
        b:SetPoint("RIGHT", anchor, "LEFT", -1, 0)
        b:SetNormalTexture(MEDIA .. art)
        b:SetPushedTexture(MEDIA .. art .. "_down")
        b:SetHighlightAtlas("RedButton-Highlight", "ADD")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnClick", function(self, button)
            GK.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
            onClick(self, button)
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            for n, line in ipairs(tip()) do
                if n == 1 then GameTooltip:AddLine(line, 1, 1, 1) else GameTooltip:AddLine(line, nil, nil, nil, true) end
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    win.settings = TitleButton("button_settings", fold, function()
        if settingsOn then return { SETTINGS or "Settings", "Back to the ledger: click again, or any tab." } end
        return { SETTINGS or "Settings", "Grudgekeeper's settings: letters, warnings, sharing, the look." }
    end, function()
        -- the settings (Options.lua), a page of the ledger over both of its own; pressed in while they are up
        if settingsOn then
            LeaveSettings()
            Refresh()
        else
            GK.OpenOptions()
        end
    end)
    win.letters = TitleButton("button_letters", win.settings, function()
        local n = GK.Unread()
        local out = { n > 0 and ("Letters - %d unread"):format(n) or "Letters",
            "New kill orders, your new titles and what you are owed. A letter goes once it is read and closed - "
                .. "the ledger keeps what it said." }
        if n > 1 then out[#out + 1] = "Right-click: read them all" end
        return out
    end, function(_, button)
        if button == "RightButton" then
            if GK.Unread() > 0 then GK.ReadAllLetters() end
        else
            GK.OpenLetters()
        end
    end)
    -- the count: a small blood-red disc on its corner, while letters wait unread
    local count = CreateFrame("Frame", nil, win.letters)
    count:SetSize(14, 14)
    count:SetPoint("TOPRIGHT", 5, 5)
    count:SetFrameLevel(win.letters:GetFrameLevel() + 2)
    count.disc = count:CreateTexture(nil, "ARTWORK")
    count.disc:SetAllPoints()
    count.disc:SetColorTexture(BLOOD[1], BLOOD[2], BLOOD[3], 1)
    count.mask = count:CreateMaskTexture()
    count.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    count.mask:SetAllPoints(count.disc)
    count.disc:AddMaskTexture(count.mask)
    count.text = count:CreateFontString(nil, "OVERLAY")
    count.text:SetFont(TEXT_FONT, 9, "OUTLINE")
    count.text:SetTextColor(1, 0.89, 0.6)
    count.text:SetPoint("CENTER", 0, 0)
    win.letters.count = count
    function win.letters:Update()
        local n = GK.Unread()
        self.count:SetShown(n > 0)
        self.count.text:SetText(n > 9 and "9+" or tostring(n))
        -- with no letter waiting it has nothing to open: a read letter is gone once closed (Letters.lua)
        local any = #GK.char.letters > 0
        self:SetEnabled(any)
        local art = self:GetNormalTexture()
        if art then art:SetDesaturated(not any) end
    end
    win:Hide()
    if LIB.RegisterWindow then LIB.RegisterWindow(win, GK.db, "window") end
    win:HookScript("OnShow", function() Refresh() end)
    -- a sheet opened on the ledger (a note, a kill order, the who-picker) closes with it (Letters.lua); a
    -- card pinned from outside goes too, a look at one player: opened again, the page is as it was
    win:HookScript("OnHide", function()
        pinned = nil
        GK.CloseLedgerSheets()
        LeaveSettings()                              -- opened again, it opens on its pages
    end)
    Layout()
    SelectTab(tab)
end

--- The row whose detail shows: the chosen one if it is still there, else the page's own default.
local function Chosen(items)
    local key = selected[tab]
    if key then
        for _, it in ipairs(items) do
            if it.key == key then return it end
        end
    end
    local def = GK.LedgerPages[tab]
    local first = def.default and def.default(items)
    if first then return first end
    for _, it in ipairs(items) do
        if not it.header and not it.faded and not it.past then return it end
    end
    return nil
end

Refresh = function()
    if not (win and win:IsShown()) then return end
    win.letters:Update()                               -- the title bar's letters button and its count
    -- the settings over both pages: the list and the card wait under them, as they were
    win.list:SetShown(not settingsOn)
    win.detail:SetShown(not settingsOn)
    if settingsOn then
        if win.versus then win.versus:Hide() end
        return
    end
    local folded = Folded()
    local def = GK.LedgerPages[tab]
    local items, empty = def.items()
    local all = #items                                 -- before the page's max (GK.SortItems)
    if def.sortable then items, all = GK.SortItems(items, def) end
    local list, detail = win.list, win.detail
    -- a card pinned from outside marks no row; one that has nothing to show any more lets the page choose
    local card = pinned and DetailCard(pinned)
    if not card then pinned = nil end
    -- the guild on watch's view has the versus page where a card would be, unless a card was asked for
    local versus = not pinned and def.versus and def.versus() or nil
    local chosen = not pinned and not versus and Chosen(items) or nil
    -- the list page
    list.title:SetText(def.name)
    -- the page's views as ink tabs on the paper, under the title, with a rule under the row of them
    local links = def.links and def.links() or {}
    local last
    for i, b in ipairs(list.links) do
        local l = links[i]
        b:SetShown(l ~= nil)
        if l then
            b:Set(l.text, l.on)
            b.click, b.tip = l.click, l.tip
            b:ClearAllPoints()
            if last then b:SetPoint("LEFT", last, "RIGHT", TAB_INK_GAP, 0) else b:SetPoint("TOPLEFT", 10, -TAB_INK_Y) end
            last = b
        end
    end
    list.tabRule:SetShown(last ~= nil)
    local sortable, mineShown = def.sortable == true, MineShown(def)
    list.mine:SetShown(mineShown)
    if mineShown then
        list.mine:Set("Only mine", GK.db.mineOnly == true)
    end
    -- the tail (the leaderboard's "resets in 1 day") at the tabs' right end, short of Only mine
    list.reset:ClearAllPoints()
    list.reset:SetPoint("TOPRIGHT", list, "TOPRIGHT", -(mineShown and list.mine.width + 14 or 12), -(TAB_INK_Y + 3))
    list.reset:SetText(last and def.linksTail and def.linksTail() or "")
    -- the line under the title on a page without tabs, decided here and not read back: the game's GetText gives
    -- no "" for an empty line
    list.sub:ClearAllPoints()
    list.sub:SetPoint("TOPLEFT", 12, -44)
    list.sub:SetWidth(last and 0 or (PAGE_W - 24 - (mineShown and list.mine.width + 10 or 0)))
    local subText = not last and def.sub and def.sub(items, all) or ""
    list.sub:SetText(subText)
    local heads, action = Headings(def), Action(def)
    list.add:SetShown(action ~= nil)
    list.underline:SetShown(#heads > 0)
    local top, perPage = ListFrame(def, last ~= nil or subText ~= "")
    if list.top ~= top then
        list.top = top
        for i, row in ipairs(list.rows) do row:SetPoint("TOPLEFT", 4, -(top + (i - 1) * ROW_H)) end
    end
    if action then list.add:Set(action) end
    local sortKey = GK.SortKey(def)
    for i, b in ipairs(list.heads) do
        local h = heads[i]
        b:ClearAllPoints()
        b:SetShown(h ~= nil)
        if not h then b.key, b.on = nil, false end
        if h then
            b.key, b.tip, b.help = sortable and h[4] or nil, h[5], h[6]
            b.on = b.key ~= nil and b.key == sortKey
            b:EnableMouse(b.key ~= nil or b.help ~= nil)
            b.text:SetText(h[1]:upper())
            Ink(b.text, b.on and BLOOD or FADED, TEXT_FONT, 10)
            b.line:SetShown(b.on)
            b:SetWidth(math.ceil(TextWidth(b.text)) + 2)
            if h[3] == "RIGHT" then b:SetPoint("BOTTOMRIGHT", list, "TOPLEFT", h[2] - 4, -(LIST_TOP - 6))
            elseif h[3] == "CENTER" then b:SetPoint("BOTTOM", list, "TOPLEFT", h[2] - 4, -(LIST_TOP - 6))
            else b:SetPoint("BOTTOMLEFT", list, "TOPLEFT", h[2], -(LIST_TOP - 6)) end
        end
    end
    -- whole pages: the page the offset falls in, and where it stops
    local starts = GK.PageStarts(items, perPage)
    list.starts = starts
    local at = 1
    for i, s in ipairs(starts) do
        if s <= offset then at = i end
    end
    offset = starts[at]
    local stop = starts[at + 1] or #items              -- the last item on this page
    for i, row in ipairs(list.rows) do
        local it = offset + i <= stop and items[i + offset] or nil
        if it then
            row:Show()
            FillRow(row, it, chosen ~= nil and it.key == chosen.key)
        else
            -- a row the list no longer reaches, under the mouse: its tooltip goes with it, as a heading's does
            if row.tipped then
                row.tipped = false
                GameTooltip:Hide()
            end
            row.hovered = false
            row:Hide()
        end
    end
    list.empty:SetText(#items == 0 and empty or "")
    local more = #starts > 1
    list.count:SetShown(more)
    list.prev:SetShown(more)
    list.next:SetShown(more)
    if more then
        list.count:SetText(offset + 1 == stop and ("%d of %d"):format(stop, #items)
            or ("%d-%d of %d"):format(offset + 1, stop, #items))
        list.prev:SetEnabled(at > 1)
        list.next:SetEnabled(at < #starts)
    end
    -- the detail: the right-hand page, or the page turned
    local showDetail = not folded or turned
    list:SetShown(not folded or not turned)
    detail:SetShown(showDetail and not versus)
    if versus and not win.versus then
        win.versus = Versus.Build(win, detail, function()
            turned = false
            Refresh()
        end)
    end
    if win.versus then win.versus:SetShown(showDetail and versus ~= nil) end
    if showDetail and versus then Versus.Fill(win.versus, versus ~= "" and versus or nil, folded) end
    detail.back:SetShown(folded)
    detail.back.text:SetText("\194\171 Back to " .. def.name:lower())
    if showDetail and not versus then FillDetail(detail, card or DetailCard(chosen and chosen.select), #items > 0) end
end

function GK.OpenWindow(page)
    if not win then Build() end
    if page and win.tabs[page] then SelectTab(page) end
    win:Show()
    win:Raise()
    Refresh()
end

--- A page by its name ("Grudges"): past the first two, a page's number can move (GK.AddLedgerPage).
function GK.OpenLedgerPage(name)
    for i, def in ipairs(GK.LedgerPages) do
        if def.name == name then return GK.OpenWindow(i) end
    end
    GK.OpenWindow(1)
end

--- The kill orders page, on this order (by its key) when it has a row there; else the page as it was.
function GK.OpenOrder(orderKey)
    ordersPage.All()                                 -- whatever was shown: that order's row
    GK.OpenWindow(1)                                 -- first: choosing the tab starts the page afresh
    local o = type(orderKey) == "string" and GK.Store().orders[orderKey]
    if o and o.state ~= "o" then
        -- an order that is over has no row on the page, which lists the open ones: its card, pinned over it
        pinned = PosterSpec(o.n, o, o)
        turned = turned or Folded()
        Refresh()
    elseif o then
        selected[1] = "o:" .. orderKey
        -- the turn of the list its row is on, so the row marked is in sight (Refresh finds the turn's start)
        for n, it in ipairs(GK.LedgerPages[1].items()) do
            if it.key == selected[1] then
                offset = n - 1
                break
            end
        end
        turned = turned or Folded()                  -- folded: the page turned to it
        Refresh()
    end
end

function GK.ToggleWindow()
    if win and win:IsShown() then win:Hide() else GK.OpenWindow() end
end

function GK.CloseWindow()
    if win then win:Hide() end
end

--- The page the settings are drawn on (Options.lua): the frame's whole inside, over the list and the card.
function GK.LedgerSettingsPage()
    if not win then Build() end
    return win.settingsPage
end

--- The ledger open on its settings, its tabs under them to go back by. Folded it opens to both pages, its
--- left edge where it was; it folds again when they are left.
function GK.ShowLedgerSettings()
    if not win then Build() end
    if not settingsOn then
        SetSettings(true)
        KeepLeft()
        Layout()
    end
    win:Show()
    win:Raise()
    Refresh()
end

--- The ledger at a page found by its name, in one of its views: Grudges' "me", "killed" or "guild", the
--- News's "all" or "orders".
function GK.OpenLedgerView(name, view)
    if name == "Grudges" then grudgesView = (view == "guild" or view == "killed") and view or "me" end
    if name == "News" then newsView = view == "orders" and "orders" or "all" end
    GK.OpenLedgerPage(name)
end

-- Where a card opened from outside the book looks for a row about them, after the page that is up: an
-- enemy on your Death list, then your Grudges, who killed you and who killed the guild (an open order on them
-- goes first of all, GK.ShowInLedger); a guildie or you on the You page (yours) and the leaderboard; a note's
-- card on the lists it is from.
local HOMES = { poster = { "Death list", "Grudges" }, record = { "You", "Leaderboard" },
    card = { "Shame", "Kudos" } }

--- Is this row about whom the spec is: the same kind of card, on the same player (GK.SameName: another
--- realm spelling, a surname one side left off). A card made by a function says whose it is with key.
local function About(it, spec)
    local s = it.select
    if it.header or it.faded or not s or s.kind ~= spec.kind then return false end
    local a, b
    if s.kind == "poster" then a, b = s.t and s.t.key, spec.t and spec.t.key
    else a, b = s.key, spec.key end
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    if s.kind == "record" and LIB.IsMyStoredName(a) and LIB.IsMyStoredName(b) then return true end
    return a == b or GK.SameName(a, b)
end

--- A page's row about them: its place in the page's items and its key, or nil.
local function RowAbout(i, spec)
    local def = GK.LedgerPages[i]
    local items = def.items()
    if def.sortable then items = GK.SortItems(items, def) end
    for n, it in ipairs(items) do
        if About(it, spec) then return n, it.key end
    end
end

--- As RowAbout, on a page with views in each of those where a row is a player's card: it is left in the one that
--- has them, and as it was where none has.
local function RowAtHome(i, spec)
    local def = GK.LedgerPages[i]
    if not def.views then return RowAbout(i, spec) end
    local was = def.getView()
    for _, view in ipairs(def.views) do
        def.setView(view)
        local n, key = RowAbout(i, spec)
        if n then return n, key end
    end
    def.setView(was)
end

--- Open the ledger on someone's card: whatever opened a card of its own before - the right-click menu on a
--- player, a kill order's pin on the map, a note's menu - opens it here, the card the ledger and the
--- Inspect tab draw. The small card of its own said less in a note's frame ("den 'profil' ved høyreklikk er
--- jo bare message boksen", the owner, 2026-11-16). spec: a row's select, { kind = "poster", t }, { kind =
--- "record", key, unit } or { kind = "card", make, key }. On the row about them: on the page that is up
--- if it has one, else an open kill order on them, else the first of their HOMES; on none, the card
--- pinned over the page as it is. Folded, the page is turned to it.
function GK.ShowInLedger(spec)
    if type(spec) ~= "table" or not DetailCard(spec) then return end
    if not win then Build() end
    local at, n, key
    if win:IsShown() then
        n, key = RowAbout(tab, spec)
        if n then at = tab end
    end
    local o = not at and spec.kind == "poster" and GK.OrderOn(spec.t.key, spec.t.guid)
    if o and o.state == "o" and o.key then
        GK.OpenOrder(o.key)            -- as a letter opens it: folded under No bounty, it is shown
        return
    end
    for _, name in ipairs(not at and HOMES[spec.kind] or {}) do
        for i, def in ipairs(GK.LedgerPages) do
            if def.name == name then
                n, key = RowAtHome(i, spec)
                if n then at = i end
                break
            end
        end
        if at then break end
    end
    if at and at ~= tab then SelectTab(at) end
    if at then
        selected[at], pinned = key, nil
        -- a card asked for shows over the versus page, whose rows open none
        local def = GK.LedgerPages[at]
        if def.versus and def.versus() then pinned = spec end
        offset = n - 1                 -- the turn of the list the row is on (Refresh finds its start)
    else
        pinned = spec
    end
    LeaveSettings()                    -- a card asked for: off the settings, to the page it is on
    turned = Folded() or turned
    win:Show()
    win:Raise()
    GK.Sound("IG_ABILITY_PAGE_TURN")
    Refresh()
end

--- The ledger open at a page found by its name, on the row with this key when the page has one; the book
--- open or folded (folded, nil: as it is) and the leaderboard on this week or all time (weeklyBoard, nil:
--- as it is). For the screenshot mode (Shots.lua), which names the page it wants a picture of. False when
--- there is no such page.
function GK.ShowLedgerPage(name, rowKey, folded, weeklyBoard)
    if not win then Build() end
    for i, def in ipairs(GK.LedgerPages) do
        if def.name == name then
            if folded ~= nil and folded ~= Folded() then Fold(folded) end
            if weeklyBoard ~= nil then weekly = weeklyBoard end
            SelectTab(i)
            selected[i] = rowKey
            win:Show()
            win:Raise()
            Refresh()
            return true
        end
    end
    return false
end

--- Fold the ledger to one page (on) or open it to two, kept as the choice, as its own button does.
function GK.FoldLedger(on)
    if win then Fold(on) else GK.db.ledgerFolded = on or nil end
end

--- The ledger's frame and its tabs, which hang below it - folded, down its right side: what a picture of the
--- ledger has to take in.
function GK.LedgerFrames()
    if not win then return {} end
    local list = { win, win.swap }                  -- the swap tab: folded, the last of them
    for _, t in ipairs(win.tabs) do list[#list + 1] = t end
    return list
end

-- Once per burst of changes (GK.Changed gathers them); Refresh returns at once while the book is shut.
LIB.Listen("GRUDGEKEEPER_CHANGED", function() Refresh() end)
