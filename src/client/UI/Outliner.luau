--!nonstrict
-- The strategy frame's outliner (2026-11-03; it replaced the command dial's "Your front" panel and the Standings pill):
-- a column down the right edge under World Tension, in sections whose heads fold them: YOUR ATTACKS (each with its
-- troops and how much of them is left, a press takes the camera there, Recall beside it), THREATS (warheads coming,
-- nations marching or massing on you), RIVALS (the top four by land, you marked with your rank) and, on a phone, LOG
-- (the world's news, UI/NewsLog; a desktop has it always open at the bottom left since 2026-11-03: UI/LogPanel). Each
-- section is its own dark card, THREATS with a red edge (2026-11-06); the four windows' buttons are the dock at the
-- bottom middle now (UI/ActionDock). A phone opens it as the "Your war" sheet from its right thumb's buttons.
--
-- Rows come from FrontModel (attacks and threats, read from the match) and FrameRules.rivals.
-- UIRoot knows it as `outliner` (and `attacks`, the name UIAdvisor marks dirty). Signals: retreat_requested(aid),
-- doctrine_wanted() (a phone's YOUR DOCTRINES, at the head of Your war).
-- Members: panel, sheet_open, log (NewsLog).
-- Methods: refresh(), mark_dirty(), reset(), apply_layout(), set_sheet(on), toggle_section(key), rects();
-- update(dt).

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")
local FrontModel = require("./FrontModel")
local HelpOverlay = require("./HelpOverlay")
local Signal = UITheme.core("Signal")

local Outliner = W.class(W.Control)

Outliner.SECTIONS = {
	{ key = "attacks", title = "YOUR ATTACKS", quiet = "No march of yours under way" },
	{ key = "threats", title = "THREATS", quiet = "Nobody marches on you", colour = "red" },
	{ key = "rivals", title = "RIVALS", quiet = "" },
	{ key = "log", title = "LOG", quiet = "No news yet" },
}
Outliner.LOG_LINES = 6
--- The rivals' medals: gold, silver and bronze for the first three places.
Outliner.MEDALS = { UITheme.CHIP_GOLD, Color3.fromRGB(201, 209, 220), Color3.fromRGB(217, 154, 94) }

local function tone_colour(tone: string?): any
	local T = UITheme
	if tone == "red" then
		return T.DIAL_RED
	elseif tone == "amber" then
		return T.DIAL_AMBER
	elseif tone == "green" then
		return T.DIAL_GREEN
	end
	return T.DIAL_MUTED
end

function Outliner.new(c: any, log: any)
	local self = setmetatable({}, Outliner.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.log = log
	self.retreat_requested = Signal.new()
	self.open = { attacks = true, threats = true, rivals = true, log = false }
	self.lists = { threats = {}, marches = {}, talks = {} }
	self.sheet_open = false
	self._seen = {}
	self._dirty = true
	self._acc = 0.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	-- (a column of cards: the column itself is bare, each section is its own card)
	-- (a plain control, not a Panel: a Panel grows to its content, and a phone's sheet must stop above the thumbs and clip)
	local panel = W.Control.new()
	panel.name = "Outliner"
	panel:set_mouse_filter(W.MOUSE_IGNORE)
	panel:set_clip_contents(true)
	self.panel = panel
	self:add_child(panel)
	-- (the cards scroll when they are taller than their room: a phone's Your war sheet with the log open ran off its
	-- foot, out of reach; release audit 2026-11-07)
	local scroll = HelpOverlay.Scroll.new()
	scroll:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._scroll = scroll
	panel:add_child(scroll)
	local v = T.vbox(FrameRules.OUT_CARD_GAP)
	self._box = v
	scroll:add_child(v)
	-- a phone's way to its doctrines (the desktop has the command bar's Doctrine): a card at the head of Your war
	self.doctrine_wanted = Signal.new()
	local doc = T.button("YOUR DOCTRINES", "DialGhost", "crown", 44.0)
	doc:set_font_size(14)
	doc.alignment = W.ALIGN_LEFT
	doc.pressed:Connect(function()
		self.doctrine_wanted:Fire()
	end)
	doc:set_visible(false)
	self._doctrines = doc
	v:add_child(doc)
	self._sections = {}
	for _, sec in Outliner.SECTIONS do
		local head = W.Button.new("", "GhostButton")
		head:set_flat(true)
		for _, st in ipairs(W.BUTTON_STATES or {}) do
			head:add_theme_stylebox_override(st, T.empty_box())
		end
		head:set_min_size(Vector2.new(0, FrameRules.OUT_HEAD_H))
		local hl = T.label(sec.title, 15, T.DIAL_WEIGHT, if sec.colour == "red" then T.DIAL_RED else T.TEXT, 1)
		hl:set_anchors(0, 0, 1, 1)
		hl:set_offsets(12, 0, -40, 0)
		hl.vertical_alignment = W.VALIGN_CENTER
		head:add_child(hl)
		local fold = T.label("–", 15, 800, T.DIAL_MUTED)
		fold:set_anchors(1, 0, 1, 1)
		fold:set_offsets(-34, 0, -12, 0)
		fold.horizontal_alignment = W.ALIGN_RIGHT
		fold.vertical_alignment = W.VALIGN_CENTER
		head:add_child(fold)
		local rule = FrameKit.bar(T.c(T.WHITE, 0.08))
		rule:set_anchors(0, 1, 1, 1)
		rule:set_offsets(0, -1, 0, 0)
		head:add_child(rule)
		head.pressed:Connect(function()
			self:toggle_section(sec.key)
		end)
		local card = W.Panel.new()
		card:set_mouse_filter(W.MOUSE_STOP)
		card:add_theme_stylebox_override(
			"panel",
			T.flat(T.c(T.DIAL_SLATE, FrameKit.PANEL_A), T.DIAL_RADIUS, if sec.colour == "red" then T.c(FrameKit.DANGER, 0.55) else T.DIAL_EDGE, if sec.colour == "red" then 2 else 1, 0, FrameRules.OUT_CARD_PAD)
		)
		local cv = T.vbox(0)
		card:add_child(cv)
		cv:add_child(head)
		local body = T.vbox(0)
		cv:add_child(body)
		v:add_child(card)
		-- (an empty section's quiet line, inset like the rows)
		local quiet = W.Control.new()
		quiet:set_mouse_filter(W.MOUSE_IGNORE)
		quiet:set_min_size(Vector2.new(0, FrameRules.OUT_LINE_H))
		local ql = T.label(sec.quiet, 13, 600, T.DIAL_MUTED)
		ql:set_anchors(0, 0, 1, 1)
		ql:set_offsets(12, 0, -12, 0)
		ql.vertical_alignment = W.VALIGN_CENTER
		quiet:add_child(ql)
		body:add_child(quiet)
		self._sections[sec.key] = { card = card, head = head, title = hl, fold = fold, body = body, quiet = quiet, rows = {}, spec = sec }
	end
	self:_connect(log.changed:Connect(function()
		if self.open.log then
			self:mark_dirty()
		end
	end))
	return self
end

function Outliner.mark_dirty(self)
	self._dirty = true
end

function Outliner.reset(self)
	table.clear(self._seen)
	self.lists = { threats = {}, marches = {}, talks = {} }
	self:set_sheet(false)
	self._dirty = true
end

--- The button `key` (the tutorial points at Build).
function Outliner.toggle_section(self, key: string)
	self.open[key] = not self.open[key]
	self.ctx:sfx("tab", -10.0)
	self:refresh()
end

--- A phone's "Your war" sheet.
function Outliner.set_sheet(self, on: boolean)
	if self.sheet_open == on then
		return
	end
	self.sheet_open = on
	self:apply_layout()
end

-- ---------------------------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------------------------

function Outliner._row(self, sec: any, i: number): any
	local T = UITheme
	local r = sec.rows[i]
	if r ~= nil then
		return r
	end
	local b = W.Button.new("", "GhostButton")
	b:set_flat(true)
	for _, st in ipairs(W.BUTTON_STATES or {}) do
		b:add_theme_stylebox_override(st, T.empty_box())
	end
	local line = T.label("", 14, 700, T.TEXT)
	line:set_anchors(0, 0, 1, 0)
	line:set_offsets(12, 4, -74, 22)
	line.clip_text = true
	line.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	b:add_child(line)
	local right = T.label("", 13, 700, T.DIAL_MUTED)
	right:set_anchors(1, 0, 1, 0)
	right:set_offsets(-72, 4, -12, 22)
	right.horizontal_alignment = W.ALIGN_RIGHT
	b:add_child(right)
	local track = FrameKit.round(T.c(T.WHITE, 0.12), 3)
	track:set_anchors(0, 0, 1, 0)
	track:set_offsets(12, 28, -74, 33)
	b:add_child(track)
	local fill = FrameKit.round(T.DIAL_AMBER, 3)
	fill:set_anchors(0, 0, 0, 1)
	track:add_child(fill)
	-- (a rival's place: a medal for the first three, a plain disc after)
	local medal = FrameKit.round(T.c(T.WHITE, 0.12), 10)
	medal:set_anchors(0, 0.5, 0, 0.5)
	medal:set_offsets(12, -10, 32, 10)
	local ml = T.label("", 11, 800, T.DIAL_INK)
	ml:set_anchors(0, 0, 1, 1)
	ml.horizontal_alignment = W.ALIGN_CENTER
	ml.vertical_alignment = W.VALIGN_CENTER
	medal:add_child(ml)
	medal:set_visible(false)
	b:add_child(medal)
	local recall = T.button("Recall", "DialGhost", "", 30.0)
	recall:set_font_size(12)
	recall:set_anchors(1, 0, 1, 0)
	recall:set_offsets(-68, 8, -10, 36)
	b:add_child(recall)
	r = { button = b, line = line, right = right, track = track, fill = fill, recall = recall, medal = medal, medal_text = ml, item = nil }
	b.pressed:Connect(function()
		self:_focus(r.item)
	end)
	recall.pressed:Connect(function()
		if r.item ~= nil and r.item.aid ~= nil then
			self.retreat_requested:Fire(r.item.aid)
			self:mark_dirty()
		end
	end)
	sec.body:add_child(b)
	sec.rows[i] = r
	return r
end

function Outliner._focus(self, it: any)
	local ctx = self.ctx
	if it == nil then
		return
	end
	ctx:sfx("click", -8.0)
	if (it.focus_tile or -1) >= 0 then
		ctx:world_call("focus_tile", { it.focus_tile, -1.0, 0.8 })
	elseif (it.owner or 0) ~= 0 then
		ctx:world_call("focus_owner", { it.owner })
	end
	if ctx.compact then
		self:set_sheet(false)
	end
end

--- Fills section `key` with `items` ({ line, right?, colour?, progress?, aid?, focus_tile?, owner?, me? }).
function Outliner._fill(self, key: string, items: { any }, max: number, row_h: number)
	local T = UITheme
	local sec = self._sections[key]
	local open = self.open[key] == true
	sec.fold:set_text(if open then "–" else "+")
	sec.body:set_visible(open)
	local n = math.min(#items, max)
	sec.quiet:set_visible(open and n == 0 and sec.spec.quiet ~= "")
	for i = 1, math.max(n, #sec.rows) do
		local it = items[i]
		local r = if i <= n then self:_row(sec, i) else sec.rows[i]
		if r ~= nil then
			r.item = if i <= n then it else nil
			r.button:set_visible(i <= n)
			if i <= n then
				r.button:set_min_size(Vector2.new(0, row_h))
				r.line:set_text(it.line)
				T.set_font_color(r.line, if it.me then T.DIAL_AMBER else (it.colour or T.TEXT))
				r.right:set_text(it.right or "")
				T.set_font_color(r.right, if it.me then T.DIAL_AMBER else (it.right_colour or T.DIAL_MUTED))
				local bar = it.progress ~= nil
				r.track:set_visible(bar)
				if bar then
					r.fill:set_anchors(0, 0, math.clamp(it.progress, 0, 1), 1)
					r.fill:set_color(it.bar_colour or T.DIAL_AMBER)
				end
				r.recall:set_visible(it.aid ~= nil)
				r.right:set_visible(it.aid == nil)
				-- (a row without a bar is one line: centred in its height)
				local ranked = it.rank ~= nil
				r.medal:set_visible(ranked)
				if ranked then
					r.medal:set_color(Outliner.MEDALS[it.rank] or T.c(T.WHITE, 0.12))
					r.medal_text:set_text(tostring(it.rank))
					T.set_font_color(r.medal_text, if Outliner.MEDALS[it.rank] ~= nil then T.DIAL_INK else T.TEXT)
				end
				r.line:set_offsets(if ranked then 40 else 12, if bar then 4 else 0, -74, if bar then 22 else row_h)
				r.line.vertical_alignment = if bar then W.VALIGN_TOP else W.VALIGN_CENTER
				r.right:set_offsets(-72, if bar then 4 else 0, -12, if bar then 22 else row_h)
				r.right.vertical_alignment = r.line.vertical_alignment
			end
		end
	end
end

function Outliner.refresh(self)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	local me = ctx:me()
	self._dirty = false
	local o = ctx:my()
	self.lists = FrontModel.collect({
		state = s,
		me = me,
		my_troops = if o ~= nil then o.troops else 0,
		tick = ctx:render_tick(),
		tick_rate = UICtx.core("Defs").TICK_RATE,
		neighbours = if ctx.borders ~= nil and type(ctx.borders.neighbour_ids) == "function" then ctx.borders:neighbour_ids() else {},
		seen = self._seen,
		request_ticks = tonumber(UICtx.core("Rules").ALLY_REQUEST_TICKS) or 200,
		transport_kind = UICtx.core("Defs").U_TRANSPORT,
		title_of_nuke = function(kind)
			return UICtx.core("Defs").NUKE_TITLES[tonumber(kind) or 0] or "Warhead"
		end,
		fmt_troops = T.fmt_troops,
		fmt_time = T.fmt_time,
	})
	-- your attacks: the target and the troops in it, a bar of what is left
	local attacks = {}
	for _, it in self.lists.marches do
		local name = if it.kind == "claim" then "Free land" elseif (it.owner or 0) ~= 0 and s ~= nil and s:get_owner(it.owner) ~= nil then s:owner_name(it.owner) else "Free land"
		local a = if it.aid ~= nil and s ~= nil and s.attacks ~= nil then s.attacks[it.aid] else nil
		local t = if a ~= nil then tonumber(a.troops) or 0 else 0
		table.insert(attacks, {
			key = it.key,
			troops = t,
			line = if it.kind == "landing" then string.format("By sea: %s", name) else string.format("%s · %s", name, T.fmt_troops(t)),
			progress = it.progress,
			bar_colour = if it.kind == "claim" then T.DIAL_GREEN else nil,
			aid = if it.actions ~= nil then it.aid else nil,
			focus_tile = it.focus_tile,
			owner = it.owner,
			right = if it.kind == "landing" then string.format("%d%%", math.floor((it.progress or 0) * 100 + 0.5)) else nil,
		})
	end
	FrameRules.sort_attacks(attacks)
	self:_fill("attacks", attacks, FrameRules.OUT_ROWS, FrameRules.OUT_ROW_H)
	-- threats: who, how many, and how near
	local threats = {}
	for _, it in self.lists.threats do
		local word = if it.kind == "nuke" then "falling" elseif it.kind == "attack_in" then "inside" else "massing"
		local who = if (it.owner or 0) ~= 0 and s ~= nil and s:get_owner(it.owner) ~= nil then s:owner_name(it.owner) else "?"
		local line = it.line
		if it.kind == "attack_in" or it.kind == "massing" then
			local tr = 0
			if it.kind == "attack_in" then
				for _, a in s.attacks or {} do
					if a.attacker == it.owner and a.target == me then
						tr += tonumber(a.troops) or 0
					end
				end
			else
				tr = (s:get_owner(it.owner) or {}).troops or 0
			end
			line = string.format("%s · %s", who, T.fmt_troops(tr))
		end
		table.insert(threats, { key = it.key, line = line, right = word, right_colour = tone_colour(it.tone), focus_tile = it.focus_tile, owner = it.owner })
	end
	self:_fill("threats", threats, FrameRules.OUT_ROWS, FrameRules.OUT_LINE_H)
	-- rivals: the top four by land, and you; a team game: the teams by land, yours marked (playtest 2026-11-08)
	local rivals = {}
	local teams = s ~= nil and type(s.is_team_game) == "function" and s:is_team_game()
	local rsec = self._sections.rivals
	local rtitle = if teams then "TEAMS" else "RIVALS"
	if rsec ~= nil and rsec.title.text ~= rtitle then
		rsec.title:set_text(rtitle)
	end
	if teams then
		local mine = if me ~= 0 then s:team_of(me) else 0
		for i, r in s:team_ranking() do
			if i > FrameRules.OUT_RIVALS + 1 and r.team ~= mine then
				continue
			end
			local label = ctx:team_label(r.team)
			table.insert(rivals, {
				key = "t" .. r.team,
				line = if r.team == mine then label .. " (yours)" else label,
				rank = i,
				right = T.fmt_pct(ctx:team_share(r.team)),
				me = r.team == mine,
				colour = T.owner_ui_color(s:team_color(r.team)),
				focus_tile = -1,
			})
		end
	elseif s ~= nil then
		for _, r in FrameRules.rivals(FrameKit.standing(ctx), me, FrameRules.OUT_RIVALS) do
			table.insert(rivals, { key = "r" .. r.id, line = if r.me then "You" else r.name, rank = r.rank, right = T.fmt_pct(r.share), me = r.me, owner = r.id, focus_tile = -1 })
		end
	end
	self:_fill("rivals", rivals, FrameRules.OUT_RIVALS + 1, FrameRules.OUT_LINE_H)
	-- the log: the latest news, newest first
	local lines = {}
	for _, l in self.log:recent(Outliner.LOG_LINES) do
		table.insert(lines, { key = tostring(l.tick), line = l.text, colour = UITheme.msg_color(l.category), focus_tile = -1 })
	end
	self:_fill("log", lines, Outliner.LOG_LINES, FrameRules.OUT_LINE_H)
	-- (a desktop's log is the panel at the bottom left)
	local log_sec = self._sections.log
	-- (a phone's, or a narrow screen's where the log panel has no room: FrameRules.is_medium)
	log_sec.card:set_visible(ctx.compact or FrameRules.is_medium(ctx.vp, ctx.insets))
	self._doctrines:set_visible(ctx.compact)
	self:_place()
end

-- ---------------------------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------------------------

function Outliner.apply_layout(self)
	self:refresh()
end

function Outliner._place(self)
	local ctx = self.ctx
	local r = ctx.reserved_top_left
	local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), {})
	local b = l.outliner
	local want = self._box:get_combined_minimum_size().Y
	self.panel:set_visible(not ctx.compact or self.sheet_open)
	if ctx.compact then
		FrameKit.place(self.panel, b)
	else
		FrameKit.place(self.panel, { x0 = b.x0, y0 = b.y0, x1 = b.x1, y1 = math.min(b.y0 + want, l.send.y0 - FrameRules.GAP) })
	end
end

--- What of it is on screen (logical px).
function Outliner.rects(self): { Rect }
	if not (self:is_visible_in_tree() and self.panel.visible) then
		return {}
	end
	return { self.panel:get_global_rect() }
end

function Outliner.update(self, delta: number)
	self._acc += delta
	if (self._dirty or self._acc >= 0.5) and self:is_visible_in_tree() then
		self._acc = 0.0
		self:refresh()
	end
end

return Outliner
