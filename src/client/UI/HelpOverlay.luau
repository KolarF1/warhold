--!nonstrict
-- The Field Guide: a sheet (UI/Sheet) with its topics down the side and one topic at a time beside them, the ages and
-- doctrines first, the credits, licence and source last. Scrolls on small screens.
--
-- Also defines two small containers the kit does not ship: Scroll (ScrollContainer, vertical)
-- and Grid (GridContainer), both with Godot layout semantics.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local UICtx = require("./UICtx")
local UIRules = require("./UIRules")
local Signal = UITheme.core("Signal")
local Defs = UICtx.core("Defs")

local HelpOverlay = W.class(W.Control)

-- =============================================================================================
-- Grid (GridContainer: columns, h_separation, v_separation)
-- =============================================================================================

local Grid = W.class(W.Control)
HelpOverlay.Grid = Grid

function Grid.new(columns: number, hsep: number?, vsep: number?)
	local self = setmetatable({}, Grid.__mt)
	W.Control._init(self)
	self._is_container = true
	self.columns = columns
	self.hsep = hsep or 4
	self.vsep = vsep or 4
	self:set_mouse_filter(W.MOUSE_IGNORE)
	return self
end

function Grid._cells(self): { any }
	local out = {}
	for _, c in ipairs(self.children) do
		if c.visible then
			table.insert(out, c)
		end
	end
	return out
end

function Grid._metrics(self): ({ number }, { number }, { boolean })
	local cells = self:_cells()
	local cols = math.max(1, self.columns)
	local cw, rh, cexp = {}, {}, {}
	for i, c in ipairs(cells) do
		local col = (i - 1) % cols + 1
		local row = (i - 1) // cols + 1
		local m = c:get_combined_minimum_size()
		cw[col] = math.max(cw[col] or 0, m.X)
		rh[row] = math.max(rh[row] or 0, m.Y)
		if bit32.band(c.size_flags_horizontal, W.EXPAND) ~= 0 then
			cexp[col] = true
		end
	end
	for col = 1, cols do
		cw[col] = cw[col] or 0
	end
	return cw, rh, cexp
end

function Grid._get_minimum_size(self): Vector2
	local cw, rh = self:_metrics()
	local w, h = 0, 0
	local nc, nr = 0, 0
	for _, v in ipairs(cw) do
		w += v
		nc += 1
	end
	for _, v in ipairs(rh) do
		h += v
		nr += 1
	end
	return Vector2.new(w + math.max(0, nc - 1) * self.hsep, h + math.max(0, nr - 1) * self.vsep)
end

function Grid._sort_children(self)
	local cells = self:_cells()
	local cols = math.max(1, self.columns)
	local cw, rh, cexp = self:_metrics()
	-- Expanding columns share the spare width (Godot: remaining space split between them).
	local total = 0
	local nexp = 0
	for col = 1, cols do
		total += cw[col]
		if cexp[col] then
			nexp += 1
		end
	end
	local spare = self.size.X - total - (cols - 1) * self.hsep
	if nexp > 0 and spare > 0 then
		for col = 1, cols do
			if cexp[col] then
				cw[col] += spare / nexp
			end
		end
	end
	local y = 0
	for row = 1, #rh do
		local x = 0
		for col = 1, cols do
			local c = cells[(row - 1) * cols + col]
			if c then
				self:fit_child_in_rect(c, Vector2.new(x, y), Vector2.new(cw[col], rh[row]))
			end
			x += cw[col] + self.hsep
		end
		y += rh[row] + self.vsep
	end
end

-- =============================================================================================
-- Scroll (ScrollContainer, vertical only)
-- =============================================================================================

local Scroll = W.class(W.Control)
HelpOverlay.Scroll = Scroll

function Scroll.new()
	local self = setmetatable({}, Scroll.__mt)
	W.Control._init(self, "ScrollingFrame")
	self._is_container = true
	local g = self.gui :: ScrollingFrame
	g.ScrollingDirection = Enum.ScrollingDirection.Y
	g.ScrollBarThickness = 6
	g.ScrollBarImageColor3 = UITheme.WHITE
	g.ScrollBarImageTransparency = 0.82
	g.TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	g.BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"
	g.VerticalScrollBarInset = Enum.ScrollBarInset.None
	g.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	g.CanvasSize = UDim2.fromOffset(0, 0)
	g.ScrollingEnabled = true
	g.Active = true
	self:set_mouse_filter(W.MOUSE_PASS)
	return self
end

function Scroll._get_minimum_size(self): Vector2
	local w = 0
	for _, c in ipairs(self.children) do
		if c.visible then
			w = math.max(w, c:get_combined_minimum_size().X)
		end
	end
	return Vector2.new(w, 0)
end

function Scroll._sort_children(self)
	local h = 0
	for _, c in ipairs(self.children) do
		if c.visible then
			-- Width first (autowrapped labels compute their height from it), then the height.
			c:_apply_rect(Vector2.zero, Vector2.new(self.size.X, c:get_combined_minimum_size().Y))
			local m = c:get_combined_minimum_size()
			c:_apply_rect(Vector2.zero, Vector2.new(self.size.X, math.max(m.Y, 0)))
			h = math.max(h, m.Y)
		end
	end
	self._content_h = h;
	(self.gui :: ScrollingFrame).CanvasSize = UDim2.fromOffset(0, math.floor(h * UITheme.scale + 0.5))
end

--- How far the content is scrolled, in logical px (Control.get_global_position subtracts it).
function Scroll._canvas_offset(self): Vector2
	return (self.gui :: ScrollingFrame).CanvasPosition / UITheme.scale
end

function Scroll.scroll_by(self, px: number)
	local g = self.gui :: ScrollingFrame
	local s = UITheme.scale
	local max_y = math.max(0, (self._content_h or 0) * s - g.AbsoluteWindowSize.Y)
	g.CanvasPosition = Vector2.new(0, math.clamp(g.CanvasPosition.Y + px * s, 0, max_y))
end

-- =============================================================================================
-- Help content
-- =============================================================================================

local function Rules()
	return UICtx.core("Rules")
end

--- Numbers in the help text come from Rules, so the text follows balance changes. `win_share`: the match's own goal
--- (a mode or mission may set another; nil outside a match: Rules.WIN_SHARE).
function HelpOverlay._fill_rules(text: string, win_share: number?): string
	local R = Rules()
	return UIRules.format(text, {
		traitor_s = tostring(Defs.round(R.TRAITOR_TICKS / R.TICK_RATE)),
		traitor_def = tostring(Defs.round(R.TRAITOR_DEFENSE_DEBUFF * 100.0)),
		spacing = tostring(Defs.round(R.STRUCT_MIN_DIST)),
		def_mag = tostring(Defs.round(R.DEFENSE_POST_MAG)),
		def_cost = tostring(Defs.round(R.DEFENSE_POST_COST)),
		sam_r = tostring(Defs.round(R.sam_range(1))),
		ws_retreat = tostring(
			Defs.round((tonumber(UIRules.rules_const("WARSHIP_RETREAT_FRAC", 0.75)) or 0.75) * 100.0)
		),
		post_shoot = if UIRules.rules_const("DEFENSE_POST_SHOOTS", false) == true
			then " A Bastion also shoots at any landing near it."
			else "",
		win = tostring(Defs.round((if type(win_share) == "number" then win_share else R.WIN_SHARE) * 100.0)),
		crown_win = tostring(Defs.round((UICtx.data("Modes").BY_KEY.crown.config.win_share or R.WIN_SHARE) * 100.0)),
		solo_s = tostring(Defs.round(R.SOLO_COUNTDOWN_TICKS / R.TICK_RATE)),
		call_pct = tostring(Defs.round(R.CALL_TO_ARMS_FRACTION * 100.0)),
		call_s = tostring(Defs.round(R.CALL_TO_ARMS_COOLDOWN_TICKS / R.TICK_RATE)),
		warband = tostring(Defs.round(UICtx.data("Stars").WARBAND_BONUS * 100.0)),
		muster_1 = UICtx.commas(UICtx.data("Claims").MUSTER[1]),
		muster_7 = UICtx.commas(UICtx.data("Claims").MUSTER[#UICtx.data("Claims").MUSTER]),
		flag_price = UICtx.commas(UICtx.data("Cosmetics").RENOWN_FLAG_PRICE),
	})
end

--- The topics, in the order a ruler meets them. `builds`: the buildings' list goes under the words; `orders` and `credits`
--- have their own bodies (_orders, _credits).
HelpOverlay.TOPICS = {
	{
		icon = "crown",
		title = "The four ages",
		text = "Every war runs through four ages: the Dawn, the Expansion, the Conflict and the Reckoning. The strip in the top bar shows where you stand. Each age opens its own buildings. On a map that is one great landmass, where wars end sooner, the ages come sooner too.\n\nDawn: Cities and Harbors.\nExpansion: Foundries, Bastions and Frigates.\nConflict: Flak, Launch Sites, Long Guns, Aerodromes and the Call to Arms.\nReckoning: the Lance Cannon.\n\nLong Guns, Aerodromes and the Lance Cannon are learned at the War College first.",
	},
	{
		icon = "charter",
		title = "Doctrines",
		text = "In each of the first three ages you choose one of three doctrines. It lasts the whole war, and some ask for something in return. Nations choose too. Wait too long and the first is chosen for you. A doctrine's gold works on all your income: trade and trucks too.\n\nA Reckoning doctrine also hands you an edict: an order you can give once every three minutes.",
	},
	{
		icon = "target",
		title = "First moves",
		text = "Press any free land and your nation lands there. Alone, you have {solo_s} seconds to change your mind.\n\nAfter that, press free land beside you to claim it, or a rival to attack it. SEND, at the bottom right, sets how much of your army goes: 10, 25, 50, 75 or 100% (press one, or keys 1 – 5), or any share at all (Q / E). Right-click a nation to see its army and your odds first. Troops grow back by themselves, fastest at about half your cap: the mark on the army gauge shows it.",
	},
	{
		icon = "city",
		title = "Gold and buildings",
		builds = true,
		text = "Gold comes in every second, with more from trade ships, trucks and conquest. Each building of a kind costs more than the last, and they must stand {spacing} tiles apart. Press one in the command bar at the bottom (or right-click your own land), then place it on the map. Near a Bastion, attackers pay {def_mag}× the troops and take {def_cost}× as long.\n\nFrom the Conflict, spare gold buys troops. The Call to Arms, under CALL-UP in the Warheads window, brings {call_pct}% of your troop cap every {call_s} s. Each call costs half as much again per troop.",
	},
	{
		icon = "alliance",
		title = "Rivals",
		text = "Each nation has a temper: Conqueror, Merchant Prince, Warden, Schemer or Zealot. Its card tells you which.\n\nOne that keeps coming for you turns into your nemesis. Bring it down yourself and a gold bounty is yours.",
	},
	{
		icon = "users",
		title = "Pacts",
		text = "Offer a pact from a nation's window; Pacts lists yours and the offers you have. While it holds, neither of you can attack the other, and each can send the other troops.\n\nBreak your word and the whole map sees an Oathbreaker for {traitor_s} s. Your land then costs only {traitor_def}% of the usual troops to take, and falls faster.",
	},
	{
		icon = "boat",
		title = "The sea",
		text = "A coast you can't walk to is still in reach: press it, and a landing sets out from your nearest shore.\n\nFrigates, built from a Harbor, hold the water you point them at. They go for landings first, then other Frigates, then trade ships, whose gold they seize. Hurt below {ws_retreat}%, a Frigate goes home to mend. Kills raise its rank. Press one of yours, then the sea, to send it.{post_shoot}",
	},
	{
		icon = "lm_citadel",
		title = "Landmarks",
		text = "The badges on the map pay whoever holds the ground beneath them.\n\nGold Mines (a mine cart) raise all your gold income. Garrisons (a tent) raise your troop cap. Citadels (a tower) harden your defence. Lighthouses pay trade gold. Granaries (wheat) speed regrowth. Forges (an anvil) give back part of every building.\n\nIn the Reckoning they all pay double.",
	},
	{
		icon = "globe",
		title = "World events",
		text = "Every few minutes something lands on the whole map for a minute or two: a Gold Rush, a Plague, a Hard Winter, a Market Crash. An Uprising or a Tax Revolt falls on the largest nation. A chip under the top bar names it and counts it down; a bad one sounds a grim bell.",
	},
	{
		icon = "atom",
		title = "Warheads",
		-- (a medieval start date's own, Data/PeriodTech)
		text_m = "A Siege Works lets you loose Greek Fire and the Plague Catapult (and, from 1241, the Great Bombard). Where a shot lands, troops and buildings are gone, and the ground stays scorched until someone pays dearly to take it back.\n\nWatchtowers bring down shots aimed within {sam_r} tiles of them. Plague carcasses slip through.",
		text = "A Launch Site lets you fire Warheads, Great Warheads and Cluster Warheads. Where one lands, troops and buildings are gone, and the ground stays poisoned until someone pays dearly to take it back.\n\nFlak Batteries stop warheads aimed within {sam_r} tiles of them. Cluster Shards slip through.",
	},
	{
		icon = "play",
		title = "Kinds of war",
		text = "Conquest: the whole war.\nBlitz: the ages race by.\nKing of the Hill: hold the Crown at the map's heart; conquest alone needs {crown_win}% of the land.\nDeadline: twenty minutes, then the largest nation wins (only taking the whole world ends it sooner).\nSkirmish: twelve nations on open land.\nTotal War: no pacts at all.\n\nYou pick when you campaign alone. Open wars take turns.",
	},
	{
		icon = "fort",
		title = "The deep war",
		text = "Long and Quick wars (WAR on the solo menu) go deeper. Open your Realm with the chip under the top bar or the R key.\n\nProvinces: the land is cut into provinces. Hold most of one and it is yours: it pays taxes, feeds you and has slots for buildings. The Provinces map mode shows their borders.\n\nYour realm: set taxes from Low to Crushing. High taxes pay more and stir unrest; past 80 provinces revolt and break away. Troops grow back only as fast as your manpower refills, and troops at war eat food. Farms feed you, Markets pay, Barracks train men, Forts guard a province.\n\nYour ruler ages, has traits, and dies in time; an heir follows. Each age you choose three ideas (Administrative, Military, Diplomatic) and, halfway through, a tech.\n\nWar needs a reason: a claim, an attack on you, or your nemesis. Without one your people grumble and the world remembers. A pact partner joins the war. Offer peace from a nation's window: white peace, its provinces, tribute or vassalage. A truce follows.\n\nArmies: raise one from your Realm or a nation's window. Today they push a front (attack, advance) or hold one. In the Middle Ages levies march: meet an enemy army and a battle is fought; reach an enemy province and you lay siege until it falls.\n\nAmbitions and battles earn prestige. When the clock runs out, the most prestige wins.",
	},
	{
		icon = "standard",
		title = "Winning",
		text = "Hold {win}% of the world's land; poisoned land doesn't count. An open war runs against the clock, and when it stops the largest nation takes it. Lose all your land and you're out.\n\nSome kinds of war and some missions set another goal. The top bar always shows it.",
	},
	{
		icon = "leaderboard",
		title = "Your record",
		text = "The WAR ROOM on the title keeps your record: daily and weekly Field Orders, 24 missions, medals and the season track. They all raise your rank and titles, and none of it can be bought.",
	},
	{
		icon = "renown",
		title = "Renown",
		text = "Renown is what your wars earn: every war pays by how long you lasted, how much you held and whom you beat, and a public war beside a friend from your warband pays {warband}% more. Field Orders, laurels, medals and season levels pay too, claimed for you in the War Room.\n\nCome back each day for the daily muster: seven days climb from {muster_1} to {muster_7} Renown with a free Spoils on the seventh, and a missed day only pauses the climb.\n\nRenown buys the War College's doctrines and weapons, and any nation's plain Standard for {flag_price} in the Banners.",
	},
	{ icon = "orders", title = "Your orders", orders = true },
	{ icon = "github", title = "Credits and source", credits = true },
}
--- The side list's width, and the gap beside it (logical px).
HelpOverlay.SIDE_W = 200
HelpOverlay.SIDE_W_PHONE = 168
HelpOverlay.GAP = 14
--- The sheet's body on a desktop.
HelpOverlay.WIDTH = 800
--- The credits, the last topic: the AGPL's Appropriate Legal Notices (a copyright notice, no
--- warranty, that the game may be shared under the licence, where the licence is) and the credits
--- (2026-10-25: the AGPL licence and its notices and the copyright notice; the flags, map icons, sprites
--- and effects are RoWorld's own or public domain since that day, and the World map since 2026-10-26).
--- NOTICE.md and LICENSE in the source have the full text.
HelpOverlay.LEGAL = {
	"Warhold is a modified version of RoWorld (Snick Co.), itself a modified version of OpenFront. © OpenFront and Contributors. Changes © 2026 Snick Co. Changes © 2026 the Warhold developers.",
	"Warhold is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License, version 3, with the additional terms in its LICENSE file. It comes with ABSOLUTELY NO WARRANTY. The licence comes with the game's source code.",
	"Maps made with Natural Earth and NOAA ETOPO1 data (public domain).",
	"Icons made by Lorc, Delapouite, Skoll, HeavenlyDog and Pierre Leducq, from game-icons.net (CC BY 3.0).",
	"Warhold is not affiliated with or endorsed by OpenFront or Snick Co.",
}
--- Where the source lives, under the credits: plain text with the GitHub mark, since Roblox games
--- can't link off-platform (2026-10-25: "Source <github logo> <repo>" at the bottom; the public repo is
--- lukechatton/roworld, lukechatton/rofront is private).
HelpOverlay.SOURCE_REPO = "KolarF1/warhold" -- (AGPL section 13: where this game's source is published)
--- The card that pops up over the repo name when it's pressed (2026-10-25), and how long it stays.
HelpOverlay.SOURCE_TIP = {
	title = "Where the source is",
	body = "This game's full source is public on GitHub, at " .. HelpOverlay.SOURCE_REPO,
}
HelpOverlay.SOURCE_TIP_S = 4.0

-- Roblox: Esc opens Roblox's own menu (games never receive it), so cancel is right-click or the same slot's key.
--- The controls by what you are doing, each as { what, on a mouse and keys, on a touch screen }; a device with no way shows no row.
HelpOverlay.ORDERS = {
	{
		"Fighting",
		{ "Act on what you point at", "Click", "Tap" },
		{ "Attack where you point", "Space" },
		{ "Size up a nation", "Right-click", "Tap" },
		{ "More orders (landings, aid)", "More orders in its window", "Long-press" },
		{ "Move on the order card", "Up / Down, Enter" },
		{ "How much you send", "1 – 5, or the shares under SEND", "The shares under SEND" },
		{ "Any share at all", "Q / E" },
		{ "Recall an attack", "YOUR ATTACKS, then its Recall", "Your war, then its Recall" },
		{ "Aid them, or break your oath", nil, "Tap a pact partner" },
	},
	{
		"Building and firing",
		{ "Buildings", "Its slot in the command bar (B opens the list)", "Build, then a pick" },
		{ "Warheads", "Its slot in the command bar (N opens the list)", "Warheads, then a pick" },
		{ "Set it down", "Click the map", "Pick a spot, confirm with ✓" },
		{ "Call it off", "Cancel, or a right-click", "Cancel" },
		{ "Send a Frigate", "Click it, then the sea", "Tap it, then the sea" },
	},
	{
		"Looking around",
		{ "Move the map", "Drag, WASD or arrows", "Drag" },
		{ "Zoom", "Wheel / + −", "Pinch" },
		{ "Look closer", nil, "Tap your land" },
		{ "Find your land", "Home" },
		{ "Standings", "Tab" },
		{ "Music", "M" },
		{ "The Council", "Menu button", "Menu button" },
	},
}

function HelpOverlay.new(c: any)
	local self = setmetatable({}, HelpOverlay.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	self._topic = 1
	self._text_w = 400
	local T = UITheme
	local v, head = Sheet.attach(self, "FIELD GUIDE")
	self._sub = T.label("", 13, 500, T.TEXT_2)
	self._sub.size_flags_horizontal = W.EXPAND_FILL
	self._sub.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._sub)
	local body = T.hbox(HelpOverlay.GAP)
	body.size_flags_vertical = W.EXPAND_FILL
	v:add_child(body)
	-- the topics, down the side
	self._side = Scroll.new()
	body:add_child(self._side)
	local list = T.vbox(2)
	list.size_flags_horizontal = W.EXPAND_FILL
	self._side:add_child(list)
	self._topic_rows = {}
	for i, d in ipairs(HelpOverlay.TOPICS) do
		local b = T.button(d.title, "GhostButton", d.icon, 44.0)
		b.alignment = W.ALIGN_LEFT
		b:set_font_size(13)
		b:add_theme_constant_override("icon_max_width", 16)
		b.size_flags_horizontal = W.EXPAND_FILL
		b.pressed:Connect(function()
			self:show_topic(i)
			self.ctx:sfx("tab")
		end)
		table.insert(self._topic_rows, b)
		list:add_child(b)
	end
	UICtx.data("PeriodTech").on_apply(function()
		for i, b in ipairs(self._topic_rows) do
			b:set_text(UICtx.data("PeriodTech").word(HelpOverlay.TOPICS[i].title))
		end
	end)
	-- the topic
	self._scroll = Scroll.new()
	self._scroll.size_flags_horizontal = W.EXPAND_FILL
	body:add_child(self._scroll)
	return self
end

--- Turns to topic `i` (an index into TOPICS).
function HelpOverlay.show_topic(self, i: number)
	self._topic = i
	self:_fill()
end

function HelpOverlay._fill(self)
	local T = UITheme
	for i, b in ipairs(self._topic_rows) do
		local on = i == self._topic
		b:add_theme_stylebox_override("normal", T.flat(if on then T.FILL_2 else T.CLEAR, T.R_MD, if on then T.LINE_2 else T.CLEAR, if on then 1 else 0, 10.0, 0.0))
		b:add_theme_stylebox_override("hover", T.flat(T.FILL_2, T.R_MD, if on then T.LINE_2 else T.CLEAR, if on then 1 else 0, 10.0, 0.0))
		b:add_theme_stylebox_override("pressed", T.flat(T.FILL_2, T.R_MD, if on then T.LINE_2 else T.CLEAR, if on then 1 else 0, 10.0, 0.0))
	end
	local old = self._page
	if old ~= nil then
		self._scroll:remove_child(old)
		old:queue_free()
	end
	local d = HelpOverlay.TOPICS[self._topic]
	local page = T.vbox(10)
	page.size_flags_horizontal = W.EXPAND_FILL
	self._page = page
	self._scroll:add_child(page)
	page:add_child(T.label(UICtx.data("PeriodTech").word(d.title), 18, 800, T.TEXT))
	if d.orders then
		self:_orders(page)
	elseif d.credits then
		self:_credits(page)
	else
		page:add_child(self:_words(self:_topic_text(d)))
		if d.builds then
			page:add_child(self:_builds())
		end
	end
	local g = self._scroll.gui :: ScrollingFrame
	g.CanvasPosition = Vector2.zero
end

--- A topic's words, with this game's numbers in them, for this device.
function HelpOverlay._topic_text(self, d: any): string
	local st = self.ctx.state
	local medieval = UICtx.data("PeriodTech").applied() ~= nil
	local body = HelpOverlay._fill_rules(if medieval and d.text_m ~= nil then d.text_m else d.text, if st ~= nil then st.win_share else nil)
	body = UICtx.data("PeriodTech").say(body)
	if self.ctx.touch then
		body = body
			:gsub(" %(press one, or keys 1 – 5%), or any share at all %(Q / E%)", " (the buttons under your left thumb)")
			:gsub("SEND, at the bottom right, sets", "SEND sets")
			:gsub("Right%-click a nation", "Tap a nation")
			:gsub("Press one in the command bar at the bottom %(or right%-click your own land%)", "Press Build and pick one (or hold your own land)")
	end
	return body
end

--- A wrapped block of text at the topic's width.
function HelpOverlay._words(self, text: string, size: number?, color: any?): any
	local t = UITheme.label(text, size or 14, 500, color or UITheme.TEXT_2)
	t:set_autowrap(true)
	t:set_min_size(Vector2.new(self._text_w, 0))
	return t
end

--- The buildings, each with its own mark and line.
function HelpOverlay._builds(self): any
	local T = UITheme
	local g = Grid.new(if self._text_w >= 460 then 2 else 1, 18, 8)
	g.size_flags_horizontal = W.EXPAND_FILL
	for _, k in ipairs(UIRules.BUILD_KINDS) do
		local item = T.hbox(10)
		item.size_flags_horizontal = W.EXPAND_FILL
		local ic = T.icon_rect(k, 18.0, T.TEXT)
		ic.size_flags_vertical = W.SHRINK_BEGIN
		item:add_child(ic)
		local tv = T.vbox(0)
		tv.size_flags_horizontal = W.EXPAND_FILL
		tv:add_child(T.label(UIRules.TITLES[k], 13, 700))
		local bl = T.label(UIRules.blurb(k), 12, 500, T.TEXT_3)
		bl:set_autowrap(true)
		bl:set_min_size(Vector2.new(if self._text_w >= 460 then 180 else self._text_w - 28, 0))
		tv:add_child(bl)
		item:add_child(tv)
		g:add_child(item)
	end
	return g
end

--- The controls of this device, by what you are doing.
function HelpOverlay._orders(self, page: any)
	local T = UITheme
	local col = if self.ctx.touch then 3 else 2
	for _, group in ipairs(HelpOverlay.ORDERS) do
		page:add_child(T.caption(group[1], 12, T.TEXT_3))
		local g = Grid.new(2, 12, 6)
		for i = 2, #group do
			local row = group[i]
			local way = row[col]
			if way ~= nil then
				local what = T.label(row[1], 13, 500, T.TEXT_2)
				what.size_flags_vertical = W.SHRINK_CENTER
				what.size_flags_horizontal = W.EXPAND_FILL
				g:add_child(what)
				g:add_child(T.label(way, 13, 700, T.TEXT))
			end
		end
		page:add_child(g)
	end
end

--- The licence's notices (LEGAL), and where the source is. Games can't open web links, so pressing the repo name says
--- where to find it instead (SOURCE_TIP).
function HelpOverlay._credits(self, page: any)
	local T = UITheme
	for _, para in ipairs(HelpOverlay.LEGAL) do
		page:add_child(self:_words(para, 13, T.TEXT_2))
	end
	local row = T.hbox(6)
	local cap = T.label("Source", 13, 500, T.TEXT_3)
	cap.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(cap)
	local b = T.button(HelpOverlay.SOURCE_REPO, "GhostButton", "github", 44.0)
	b:set_font_size(13)
	b:add_theme_constant_override("icon_max_width", 18)
	b.size_flags_vertical = W.SHRINK_CENTER
	b.pressed:Connect(function()
		self:_show_source_tip(b)
	end)
	row:add_child(b)
	page:add_child(row)
end

--- The tooltip card above the repo name (forced, so taps show it too); it hides after SOURCE_TIP_S,
--- or with the window (the card drops an anchor that is no longer visible).
function HelpOverlay._show_source_tip(self, b: any)
	self.ctx:show_hint(b, HelpOverlay.SOURCE_TIP, true)
	self._tip_serial = (self._tip_serial or 0) + 1
	local serial = self._tip_serial
	task.delay(HelpOverlay.SOURCE_TIP_S, function()
		if self._tip_serial == serial then
			self.ctx:hide_hint(b)
		end
	end)
end

function HelpOverlay.apply_layout(self)
	local compact = self.ctx.compact
	local side = if compact then HelpOverlay.SIDE_W_PHONE else HelpOverlay.SIDE_W
	local m = Sheet.place(self, HelpOverlay.WIDTH)
	self._side:set_min_size(Vector2.new(side, 0))
	-- (clear of the scroll bar; a wrapped label measures against its width)
	local w = math.max(m.body_w - side - HelpOverlay.GAP - 14, 120)
	local changed = w ~= self._text_w
	self._text_w = w
	if self.is_open and changed then
		self:_fill()
	end
end

function HelpOverlay.open(self)
	if self.is_open then
		return
	end
	self.is_open = true
	local ctx = self.ctx
	local paused = ctx:mode() == UICtx.MODE_SOLO and ctx:in_match()
	self._sub:set_text(if paused then "War paused" else "What a ruler needs to know")
	self:apply_layout()
	self:_fill()
	Sheet.show(self)
end

function HelpOverlay.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function HelpOverlay.scroll_by(self, px: number)
	if self._scroll ~= nil then
		self._scroll:scroll_by(px)
	end
end

return HelpOverlay
