--!nonstrict
-- The War Room (Warhold's own; the title's WAR ROOM row): the ruler's own screens under one roof. Tabs: Orders
-- (Data/Orders), Missions (Data/Missions), Medals (Data/Medals), Season (Data/Season), Record (Data/Career,
-- Data/Progress). Everything is read from the career settings section; a mission's PLAY fires `.start_mission` (key).
-- What each pays in Renown shows beside it, and whether it has been paid (Data/Claims, the server's word). The War
-- Report (UI/WarReport) uses the same window.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local Sheet = require("./Sheet")
local UICtx = require("./UICtx")
local HelpOverlay = require("./HelpOverlay")
local Signal = UITheme.core("Signal")

local CommandCenter = W.class(W.Control)

CommandCenter.TABS = { "Orders", "Missions", "Medals", "Season", "Record" }
--- The sheet's body, desktop.
CommandCenter.WIDTH = 760

local function new_panel(pad: number?): any
	local p = GlassPanel.new(pad or 12.0, (pad or 12.0) * 0.8, UITheme.R_MD, false, 0)
	p:set_tint(UITheme.GLASS_RAISED)
	p:set_border(UITheme.LINE)
	return p
end

function CommandCenter.new(c: any)
	local self = setmetatable({}, CommandCenter.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.start_mission = Signal.new()
	self.is_open = false
	self._tab = 1
	local v, head = Sheet.attach(self, "WAR ROOM", { relayout = true })
	self._sub = UITheme.label("", 13, 600, UITheme.TEXT_2)
	self._sub.size_flags_horizontal = W.EXPAND_FILL
	self._sub.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._sub)
	local tabs = UITheme.hbox(6)
	self._tabs = {}
	for i, name in CommandCenter.TABS do
		local chip = UITheme.button(name, "ChipButton", "", 32.0)
		chip.toggle_mode = true
		chip:set_font_size(12)
		chip:set_pressed_no_signal(i == self._tab)
		chip.pressed:Connect(function()
			self:show_tab(i)
		end)
		table.insert(self._tabs, chip)
		tabs:add_child(chip)
	end
	v:add_child(tabs)
	self._scroll = HelpOverlay.Scroll.new()
	self._scroll.size_flags_vertical = W.EXPAND_FILL
	v:add_child(self._scroll)
	return self
end

function CommandCenter._career(self): any
	return UICtx.data("Progress").clean(self.ctx:session_call("load_settings", { UICtx.data("Career").SECTION }))
end

function CommandCenter._day(_self): number
	return UICtx.data("Progress").day_of(UICtx.data("Progress").now())
end

--- What claim `id` pays: the Renown mark and the amount, and PAID once the server has paid it.
function CommandCenter._renown(self, amount: number, id: string): any
	local s = self.ctx.session
	local inv = if s ~= nil then s.inventory else nil
	local paid = UICtx.data("Claims").is_paid(if inv ~= nil then inv.claims else nil, id, self:_day())
	local row = UITheme.hbox(3)
	row.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(UITheme.icon_rect("renown", 12.0, if paid then UITheme.TEXT_3 else UITheme.GOLD))
	row:add_child(UITheme.label(string.format("+%d", amount), 12, 700, if paid then UITheme.TEXT_3 else UITheme.GOLD))
	if paid then
		row:add_child(UITheme.label("PAID", 12, 700, UITheme.GREEN))
	end
	return row
end

function CommandCenter.show_tab(self, i: number)
	self._tab = i
	for j, ch in self._tabs do
		ch:set_pressed_no_signal(j == i)
	end
	self.ctx:sfx("tab")
	self:_rebuild()
end

--- A bar: `f` of the way along, in `color`.
local function bar(f: number, color: any, h: number?): any
	local track = W.ColorRect.new(UITheme.c(UITheme.WHITE, 0.1))
	track:set_min_size(Vector2.new(0, h or 6))
	track:set_mouse_filter(W.MOUSE_IGNORE)
	track.size_flags_horizontal = W.EXPAND_FILL
	local fill = W.ColorRect.new(color)
	fill:set_mouse_filter(W.MOUSE_IGNORE)
	fill:set_anchors(0, 0, math.clamp(f, 0, 1), 1)
	fill:set_offsets(0, 0, 0, 0)
	track:add_child(fill)
	return track
end

local function wrapped(text: string, size: number, weight: number, color: any, width: number): any
	local l = UITheme.label(text, size, weight, color)
	l:set_autowrap(true)
	l:set_min_size(Vector2.new(width, 0))
	l.size_flags_horizontal = W.EXPAND_FILL
	return l
end

function CommandCenter._rebuild(self)
	if self._content ~= nil then
		self._scroll:remove_child(self._content)
		self._content:queue_free()
	end
	local v = UITheme.vbox(if self.ctx.compact then 6 else 8)
	v.size_flags_horizontal = W.EXPAND_FILL
	-- (room on the right for the scroll bar)
	local wrap = UITheme.hbox(0)
	wrap:add_child(v)
	local gutter = W.Control.new()
	gutter:set_min_size(Vector2.new(12, 0))
	gutter:set_mouse_filter(W.MOUSE_IGNORE)
	wrap:add_child(gutter)
	self._content = wrap
	self._scroll:add_child(wrap)
	local c = self:_career()
	local builders = { self._orders_tab, self._war_tab, self._medals_tab, self._season_tab, self._record_tab }
	builders[self._tab](self, v, c)
end

-- Orders -------------------------------------------------------------------------------------------

function CommandCenter._order_rows(self, v: any, list: { any }, counts: { number })
	for i, order in list do
		local p = new_panel()
		local col = UITheme.vbox(4)
		local line = UITheme.hbox(8)
		local done = counts[i] >= order.goal
		local name = UITheme.label(order.text, 14, 700, if done then UITheme.GREEN else UITheme.TEXT)
		name.size_flags_horizontal = W.EXPAND_FILL
		line:add_child(name)
		local Claims = UICtx.data("Claims")
		line:add_child(self:_renown(Claims.order_amount(order), Claims.order_id(order)))
		line:add_child(UITheme.label(string.format("+%d XP", order.xp), 12, 700, UITheme.TEXT_2))
		col:add_child(line)
		local row2 = UITheme.hbox(8)
		row2:add_child(bar(counts[i] / order.goal, if done then UITheme.GREEN else UITheme.AMBER))
		local num = UITheme.label(string.format("%d / %d", math.min(counts[i], order.goal), order.goal), 12, 600, UITheme.TEXT_2)
		row2:add_child(num)
		col:add_child(row2)
		p:add_child(col)
		v:add_child(p)
	end
end

--- The daily muster (Data/Claims.MUSTER): the seven days as pips, today's rung, and what tomorrow brings.
function CommandCenter._muster_row(self, v: any, day: number)
	local Claims = UICtx.data("Claims")
	local session = self.ctx.session
	local st = if session ~= nil and session.inventory ~= nil then session.inventory.claims else nil
	local nxt, open = Claims.muster_next(st, day)
	-- (the rung taken today, or the one about to be: days done this week of the ladder)
	local done = nxt - 1
	if not open and nxt == 1 then
		done = #Claims.MUSTER -- (the seventh taken today: the ladder starts again tomorrow)
	end
	local p = new_panel()
	local col = UITheme.vbox(6)
	local line = UITheme.hbox(8)
	local name = UITheme.label("DAILY MUSTER", 14, 800, UITheme.TEXT, 1)
	name.size_flags_horizontal = W.EXPAND_FILL
	line:add_child(name)
	local tomorrow = Claims.MUSTER[nxt] or Claims.MUSTER[1]
	line:add_child(UITheme.label(
		if open then "Paid when you come in" else string.format("Tomorrow: +%s Renown", UICtx.commas(tomorrow)),
		12,
		700,
		UITheme.TEXT_2
	))
	col:add_child(line)
	local pips = UITheme.hbox(6)
	for i = 1, #Claims.MUSTER do
		local text = string.format("%d · %s", i, UICtx.commas(Claims.MUSTER[i]))
		if i == #Claims.MUSTER then
			text ..= " + Spoils" -- (a free one on the seventh day)
		end
		local chip = UITheme.label(text, 12, 700,
			if i <= done then UITheme.AMBER else UITheme.TEXT_3)
		pips:add_child(chip)
	end
	col:add_child(pips)
	col:add_child(UITheme.label("A missed day pauses the climb; it never starts it over.", 12, 500, UITheme.TEXT_3))
	p:add_child(col)
	v:add_child(p)
end

function CommandCenter._orders_tab(self, v: any, c: any)
	local Orders = UICtx.data("Orders")
	local day = self:_day()
	local o = Orders.current(c.o, day)
	self._sub:set_text("Field Orders pay Renown and career XP")
	self:_muster_row(v, day)
	v:add_child(UITheme.label("TODAY", 12, 800, UITheme.AMBER, 2))
	self:_order_rows(v, Orders.daily(day), { o.a, o.b, o.c })
	v:add_child(UITheme.label("THIS WEEK", 12, 800, UITheme.AMBER, 2))
	self:_order_rows(v, Orders.weekly(day), { o.x, o.y, o.z })
end

-- War Room -----------------------------------------------------------------------------------------

--- Three stars in a row: `n` lit.
local function star_row(n: number): any
	local row = UITheme.hbox(2)
	row.size_flags_vertical = W.SHRINK_CENTER
	for i = 1, 3 do
		row:add_child(UITheme.icon_rect("laurel", 14.0, if i <= n then UITheme.AMBER else UITheme.c(UITheme.WHITE, 0.16)))
	end
	return row
end

function CommandCenter._war_tab(self, v: any, c: any)
	local Missions = UICtx.data("Missions")
	local UIMaps = UICtx.mod("UIMaps")
	local Modes = UICtx.data("Modes")
	local best = Missions.best(c.missions)
	local total = Missions.total_stars(best)
	self._sub:set_text(string.format("%d of %d laurels, %d Renown each", total, Missions.MAX_STARS, UICtx.data("Claims").LAUREL))
	local theatre = 0
	local DIFF = { [0] = "Recruit", [1] = "Veteran", [2] = "Warlord" }
	for i, m in Missions.LIST do
		if m.theatre ~= theatre then
			theatre = m.theatre
			local t = Missions.THEATRES[theatre]
			local open = total >= t.stars
			v:add_child(UITheme.label(string.format("THEATRE %d · %s", theatre, string.upper(t.name)), 13, 800, if open then UITheme.AMBER else UITheme.TEXT_3, 2))
			v:add_child(UITheme.label(if open then t.line else string.format("Opens at %d laurels", t.stars), 12, 500, UITheme.TEXT_2))
		end
		local open = Missions.unlocked(i, best)
		local p = new_panel()
		local line = UITheme.hbox(10)
		local col = UITheme.vbox(3)
		col.size_flags_horizontal = W.EXPAND_FILL
		local head = UITheme.hbox(8)
		head:add_child(UITheme.label(string.format("%d. %s", i, m.name), 14, 800, if open then UITheme.TEXT else UITheme.TEXT_3))
		head:add_child(star_row(best[i]))
		col:add_child(head)
		if open then
			local mode = Modes.BY_KEY[m.mode or Modes.DEFAULT]
			col:add_child(UITheme.label(string.format("%s · %s · %s", UIMaps.name_of(m.map), DIFF[m.difficulty], mode.name), 12, 600, UITheme.TEXT_2))
			col:add_child(wrapped(m.brief, 12, 500, UITheme.TEXT_2, 400))
			for k, ob in m.objectives do
				local got = best[i] >= 1 and k <= best[i]
				local oline = UITheme.hbox(5)
				oline:add_child(UITheme.icon_rect("laurel", 12.0, if got then UITheme.AMBER else UITheme.c(UITheme.WHITE, 0.16)))
				local olabel = UITheme.label(Missions.objective_text(ob), 12, 600, if got then UITheme.AMBER else UITheme.TEXT_2)
				olabel.size_flags_horizontal = W.EXPAND_FILL
				oline:add_child(olabel)
				local Claims = UICtx.data("Claims")
				oline:add_child(self:_renown(Claims.LAUREL, Claims.laurel_id(m, k)))
				col:add_child(oline)
			end
		else
			col:add_child(UITheme.label("Locked", 12, 600, UITheme.TEXT_3))
		end
		line:add_child(col)
		if open then
			local play = UITheme.button("PLAY", "PrimaryButton", "", 40.0)
			play:set_min_size(Vector2.new(92, 40))
			play:set_font_size(13)
			play.size_flags_vertical = W.SHRINK_CENTER
			play.pressed:Connect(function()
				self:close()
				self.start_mission:Fire(m.key)
			end)
			line:add_child(play)
		end
		p:add_child(line)
		v:add_child(p)
	end
end

-- Medals -------------------------------------------------------------------------------------------

function CommandCenter._medals_tab(self, v: any, c: any)
	local Medals = UICtx.data("Medals")
	local earned = Medals.earned(c.medals)
	local n = 0
	for _, on in earned do
		if on then
			n += 1
		end
	end
	self._sub:set_text(string.format("%d of %d earned", n, #Medals.LIST))
	local cols = if self.ctx.compact then 2 else 3
	local grid = HelpOverlay.Grid.new(cols, 8, 8)
	for i, m in Medals.LIST do
		local on = earned[i]
		local p = new_panel(10.0)
		local col = UITheme.vbox(2)
		col:add_child(UITheme.label(m.name, 13, 800, if on then UITheme.AMBER else UITheme.TEXT_3))
		col:add_child(wrapped(m.line, 11, 500, if on then UITheme.TEXT_2 else UITheme.TEXT_3, 200))
		if m.title ~= nil then
			col:add_child(UITheme.label("Title: " .. m.title, 12, 700, if on then UITheme.AMBER else UITheme.TEXT_3))
		end
		local Claims = UICtx.data("Claims")
		col:add_child(self:_renown(Claims.medal_amount(m), Claims.medal_id(m)))
		p:add_child(col)
		p.size_flags_horizontal = W.EXPAND_FILL
		grid:add_child(p)
	end
	v:add_child(grid)
end

-- Season -------------------------------------------------------------------------------------------

function CommandCenter._season_tab(self, v: any, c: any)
	local Season = UICtx.data("Season")
	local sea = Season.current(self:_day())
	local xp = if c.season == sea.number then c.season_xp else 0
	local lv = Season.level(xp)
	self._sub:set_text(string.format("Season %d · %d days left", sea.number, sea.days_left))
	local p = new_panel()
	local col = UITheme.vbox(6)
	col:add_child(UITheme.label(string.upper(sea.theme.name), 18, 900, UITheme.AMBER, 2))
	col:add_child(UITheme.label(sea.theme.line, 12, 500, UITheme.TEXT_2))
	local row = UITheme.hbox(8)
	row:add_child(UITheme.label(string.format("LEVEL %d", lv.level), 14, 800, UITheme.TEXT))
	row:add_child(bar(lv.progress, UITheme.AMBER, 8))
	row:add_child(UITheme.label(if lv.level >= Season.LEVELS then "MAX" else string.format("%d / %d XP", lv.into, Season.XP_PER_LEVEL), 12, 600, UITheme.TEXT_2))
	col:add_child(row)
	p:add_child(col)
	v:add_child(p)
	local Claims = UICtx.data("Claims")
	local pays = UITheme.hbox(4)
	pays:add_child(UITheme.icon_rect("renown", 12.0, UITheme.GOLD))
	pays:add_child(UITheme.label(string.format("Each level pays %d Renown, each fifth %d", Claims.SEASON_LEVEL, Claims.SEASON_FIFTH), 12, 600, UITheme.GOLD))
	v:add_child(pays)
	v:add_child(UITheme.label("EVERY FIFTH LEVEL IS A TITLE, YOURS FOR GOOD", 12, 800, UITheme.AMBER, 1))
	for slot, title in sea.theme.titles do
		local level = slot * 5
		local got = lv.level >= level
		local line = UITheme.hbox(10)
		local lvl = UITheme.label(string.format("Level %d", level), 12, 700, if got then UITheme.AMBER else UITheme.TEXT_3)
		lvl:set_min_size(Vector2.new(72, 0))
		line:add_child(lvl)
		local tl = UITheme.label(title, 13, 700, if got then UITheme.TEXT else UITheme.TEXT_3)
		tl.size_flags_horizontal = W.EXPAND_FILL
		line:add_child(tl)
		line:add_child(self:_renown(Claims.season_amount(level), Claims.season_id(level)))
		v:add_child(line)
	end
end

-- Record -------------------------------------------------------------------------------------------

function CommandCenter._record_tab(self, v: any, c: any)
	local Career = UICtx.data("Career")
	local Progress = UICtx.data("Progress")
	local r = Career.rank(c.xp)
	self._sub:set_text(string.format("%s %s", r.name, r.insignia))
	local p = new_panel()
	local col = UITheme.vbox(6)
	local row = UITheme.hbox(8)
	row:add_child(UITheme.label(string.upper(r.name), 18, 900, UITheme.AMBER, 2))
	row:add_child(bar(r.progress, UITheme.AMBER, 8))
	local nextr = Career.RANKS[r.index + 1]
	row:add_child(UITheme.label(if nextr ~= nil then string.format("%d XP to %s", r.span - r.into, nextr[1]) else "Top of the ladder", 12, 600, UITheme.TEXT_2))
	col:add_child(row)
	p:add_child(col)
	v:add_child(p)
	local t = c.t
	local cells = {
		{ "Matches", c.matches }, { "Wins", c.wins }, { "Minutes", t.minutes },
		{ "Nations beaten", t.kills }, { "Buildings", t.builds }, { "Warheads fired", t.nukes },
		{ "Edicts", t.edicts }, { "Doctrines", t.drafts }, { "Nemeses slain", t.nemeses },
		{ "Best land", tostring(t.best_land) .. "%" }, { "Most landmarks", t.best_lm }, { "War Room laurels", t.stars },
	}
	local grid = HelpOverlay.Grid.new(if self.ctx.compact then 3 else 4, 8, 8)
	for _, cell in cells do
		local box = new_panel(10.0)
		local cv = UITheme.vbox(0)
		cv:add_child(UITheme.label(tostring(cell[2]), 18, 900, UITheme.TEXT))
		cv:add_child(UITheme.label(cell[1], 12, 600, UITheme.TEXT_2))
		box:add_child(cv)
		box.size_flags_horizontal = W.EXPAND_FILL
		grid:add_child(box)
	end
	v:add_child(grid)
	-- titles: a press wears one
	v:add_child(UITheme.label("TITLES", 12, 800, UITheme.AMBER, 2))
	local titles = Progress.titles(c)
	if #titles == 0 then
		v:add_child(UITheme.label("Earn medals and climb the season to win titles.", 12, 500, UITheme.TEXT_2))
	end
	local tgrid = HelpOverlay.Grid.new(if self.ctx.compact then 2 else 3, 6, 6)
	for _, title in titles do
		local b = UITheme.button(title, if title == c.title then "PrimaryButton" else "GlassButton", "", 36.0)
		b:set_font_size(12)
		b.size_flags_horizontal = W.EXPAND_FILL
		b.pressed:Connect(function()
			self:_wear(if title == c.title then "" else title)
		end)
		tgrid:add_child(b)
	end
	v:add_child(tgrid)
end

function CommandCenter._wear(self, title: string)
	local Career = UICtx.data("Career")
	local c = self:_career()
	c.title = title
	self.ctx:session_call("save_settings", { Career.SECTION, c })
	self.ctx:sfx("confirm")
	self:_rebuild()
	if self.title_changed ~= nil then
		self.title_changed()
	end
end

-- The window ---------------------------------------------------------------------------------------

function CommandCenter.open(self, tab: number?)
	if self.is_open then
		return
	end
	self.is_open = true
	self._tab = tab or self._tab
	-- (anything earned and not yet paid is asked for again)
	self.ctx:session_call("sync_claims", {})
	for j, ch in self._tabs do
		ch:set_pressed_no_signal(j == self._tab)
	end
	self:apply_layout()
	self:_rebuild()
	Sheet.show(self)
end

function CommandCenter.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function CommandCenter.apply_layout(self)
	Sheet.place(self, CommandCenter.WIDTH)
end

return CommandCenter
