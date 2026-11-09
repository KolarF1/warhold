--!nonstrict
-- The strategy frame's war clock (2026-11-03; it replaced the command dial's age track): at the bottom right, the time the
-- war has run (or what is left of a timed war), a status line (the truce, the next age and when, the world event
-- running), the four ages (Data/Eras: Dawn, Expansion, Conflict, Reckoning) as a bar with the current one lit, RACE TO
-- 80% (Rules.WIN_SHARE) with marks for you and the top three, and the map modes that exist (Nations; Defences: every Flak, Bastion and
-- Long Guns range on the map, RangeLayer's "all"). A phone has no clock of its own: its strip shows short_text().
--
-- UIRoot knows it as `clock`. Signals: era_changed(era), map_mode_changed(mode). Members: panel, rank_provider.
-- Methods: apply_layout(), on_phase(phase, ticks_left), on_bind(), refresh(), grace_left(), short_text(), age_card(),
-- bottom_edge(); per frame update(dt).

local UITheme = require("./UITheme")
local W = require("./Widgets")
local UICtx = require("./UICtx")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")
local DominionStrip = require("./DominionStrip")
local Signal = UITheme.core("Signal")
local Eras = UICtx.data("Eras")

local WarClock = W.class(W.Control)

--- The map modes that work: their key, button words and card.
WarClock.MODES = {
	{ key = "nations", label = "Nations", body = "Every nation in its own colour. Your own Flak and Bastion rings show faint." },
	{ key = "defences", label = "Defences", body = "Every Flak, Bastion and Long Guns range on the map, each ring in its owner's colour: where an attack or a warhead will be costly." },
	-- (a depth match only: _light_modes hides it elsewhere)
	{ key = "provinces", label = "Provinces", body = "Every province's border. A province is held by whoever owns most of it; it pays taxes, feeds your realm and has slots for buildings.", depth = true },
}

--- Who is in the race: you and the three largest, as { id, share, colour, me }. Pure but for `ctx`.
function WarClock.racers(ctx: any): { any }
	local list = FrameKit.standing(ctx)
	local me = ctx:me()
	local rows = FrameRules.rivals(list, me, 3)
	local out = {}
	local s = ctx.state
	for _, r in rows do
		local o = s:get_owner(r.id)
		table.insert(out, { id = r.id, share = r.share, colour = UITheme.owner_ui_color(o.color), me = r.me })
	end
	return out
end

function WarClock.new(c: any)
	local self = setmetatable({}, WarClock.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.era_changed = Signal.new()
	self.map_mode_changed = Signal.new()
	self.rank_provider = nil
	self._era = 0
	self._phase_end_tick = -1.0
	self._acc = 0.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	local panel = FrameKit.slate()
	panel.name = "WarClock"
	panel:set_mouse_filter(W.MOUSE_STOP)
	self.panel = panel
	self:add_child(panel)
	local v = T.vbox(7)
	v:set_anchors(0, 0, 1, 1)
	v:set_offsets(14, 10, -14, -10)
	panel:add_child(v)
	local head = T.hbox(8)
	self._time = FrameKit.value("0:00", 26, T.TEXT)
	self._time.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._time)
	self._status = T.label("", 13, 600, T.DIAL_MUTED)
	self._status.size_flags_horizontal = W.EXPAND_FILL
	self._status.size_flags_vertical = W.SHRINK_CENTER
	self._status.horizontal_alignment = W.ALIGN_RIGHT
	self._status.clip_text = true
	self._status.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._status:set_min_size(Vector2.new(200, 0))
	head:add_child(self._status)
	v:add_child(head)
	-- the four ages: a segmented strip, the current one a filled amber block
	local age_seg = W.Control.new()
	age_seg:set_mouse_filter(W.MOUSE_STOP)
	age_seg:set_min_size(Vector2.new(0, 30))
	local age_track = FrameKit.track(10)
	age_track:set_anchors(0, 0, 1, 1)
	age_seg:add_child(age_track)
	local ages = T.hbox(3)
	ages:set_anchors(0, 0, 1, 1)
	ages:set_offsets(3, 3, -3, -3)
	ages:set_mouse_filter(W.MOUSE_IGNORE)
	age_seg:add_child(ages)
	self._ages = {}
	for i, name in Eras.NAMES do
		local blk = W.Panel.new()
		blk:set_mouse_filter(W.MOUSE_IGNORE)
		blk:set_min_size(Vector2.new(0, 24))
		blk.size_flags_horizontal = W.EXPAND_FILL
		local l = T.label(string.upper(name), 12, 800, T.DIAL_MUTED, 1)
		l:set_anchors(0, 0, 1, 1)
		l.horizontal_alignment = W.ALIGN_CENTER
		l.vertical_alignment = W.VALIGN_CENTER
		blk:add_child(l)
		ages:add_child(blk)
		self._ages[i] = { node = blk, label = l }
	end
	v:add_child(age_seg)
	FrameKit.hover(c, age_seg, function()
		return self:age_card()
	end)
	-- the race
	self._race_cap = FrameKit.caption("RACE TO 80%")
	v:add_child(self._race_cap)
	local track = W.Control.new()
	track:set_min_size(Vector2.new(0, 12))
	track:set_mouse_filter(W.MOUSE_STOP)
	local back = FrameKit.round(T.c(T.WHITE, 0.12), 4)
	back:set_anchors(0, 0, 1, 1)
	back:set_offsets(0, 2, 0, -2)
	track:add_child(back)
	self._marks = {}
	for i = 1, 4 do
		local m = FrameKit.round(T.WHITE, 2)
		m:set_anchors(0, 0, 0, 1)
		track:add_child(m)
		m:set_visible(false)
		self._marks[i] = m
	end
	self._race = track
	v:add_child(track)
	FrameKit.hover(c, track, function()
		return self:race_card()
	end)
	-- the map modes: a segmented control
	local mode_seg = W.Control.new()
	mode_seg:set_mouse_filter(W.MOUSE_IGNORE)
	mode_seg:set_min_size(Vector2.new(0, 38))
	local mode_track = FrameKit.track(12)
	mode_track:set_anchors(0, 0, 1, 1)
	mode_seg:add_child(mode_track)
	local modes = T.hbox(4)
	modes:set_anchors(0, 0, 1, 1)
	modes:set_offsets(3, 3, -3, -3)
	mode_seg:add_child(modes)
	self._modes = {}
	for _, m in WarClock.MODES do
		local b = T.button(m.label, "DialSeg", "", 32.0)
		b._seg = true
		b:set_font_size(13)
		b:set_min_size(Vector2.new(0, 32))
		b.size_flags_horizontal = W.EXPAND_FILL
		b.pressed:Connect(function()
			self:set_mode(m.key)
		end)
		b.mouse_entered:Connect(function()
			c:show_hint(b, { title = m.label, body = UICtx.data("PeriodTech").say(m.body) })
		end)
		b.mouse_exited:Connect(function()
			c:hide_hint(b)
		end)
		modes:add_child(b)
		self._modes[m.key] = b
	end
	v:add_child(mode_seg)
	self:_light_modes()
	return self
end

--- A map mode: the view's range rings follow it (UICtx.base_range_mode).
function WarClock.set_mode(self, key: string)
	local ctx = self.ctx
	if ctx.map_mode == key then
		return
	end
	local was = ctx.map_mode
	ctx.map_mode = key
	ctx:world_call("set_range_mode", { ctx:base_range_mode() })
	-- (into or out of the Provinces mode: the map draws the province borders, or stops)
	if key == "provinces" or was == "provinces" then
		local ds = ctx.state ~= nil and ctx.state.depth or nil
		local on = key == "provinces" and ds ~= nil and ds.P ~= nil
		ctx:world_call("set_province_view", { if on then ds.P.grid else nil, if on then ds.P.dev else nil })
	end
	self:_light_modes()
	self.map_mode_changed:Fire(key)
end

function WarClock._light_modes(self)
	local cur = self.ctx.map_mode or "nations"
	local depth = self.ctx.state ~= nil and self.ctx.state.depth ~= nil
	for key, b in self._modes do
		FrameKit.set_lit(b, key == cur)
		if key == "provinces" then
			b:set_visible(depth)
		end
	end
end

function WarClock.apply_layout(self)
	local ctx = self.ctx
	self:_light_modes()
	local r = ctx.reserved_top_left
	local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), {})
	self._layout = l
	self.panel:set_visible(not ctx.compact)
	if not ctx.compact then
		FrameKit.place(self.panel, l.clock)
	end
	self:refresh()
end

function WarClock.bottom_edge(self): number
	return if self._layout ~= nil and self._layout.clock ~= nil then self._layout.clock.y0 else self.ctx.vp.Y
end

--- Call on bind and on every phase change.
function WarClock.on_phase(self, phase: number, ticks_left: number)
	local s = self.ctx.state
	if s == nil then
		return
	end
	local Defs = UITheme.core("Defs")
	self._phase_end_tick = if ticks_left > 0 and phase ~= Defs.PHASE_OVER then s.tick + ticks_left else -1.0
	self:refresh()
end

function WarClock.on_bind(self)
	self._era = 0
	self._phase_end_tick = -1.0
	local s = self.ctx.state
	if s == nil then
		return
	end
	self:on_phase(s.phase, s.phase_ticks_left)
	-- (a new match: the Provinces mode only where there are provinces; the view follows the new map's)
	self:_light_modes()
	if self.ctx.map_mode == "provinces" then
		if s.depth == nil or s.depth.P == nil then
			self:set_mode("nations")
		else
			self.ctx:world_call("set_province_view", { s.depth.P.grid, s.depth.P.dev })
		end
	end
end

--- Early peace: nations will not declare war on a commander during the grace window
--- (Rules.human_grace_ticks(difficulty), counted from the start of play).
function WarClock.grace_left(self): number
	local ctx = self.ctx
	local Defs = UITheme.core("Defs")
	local s = ctx.state
	if s == nil or s.phase ~= Defs.PHASE_PLAYING or not ctx:alive_player() or ctx.play_start_tick == nil or ctx.play_start_tick < 0 then
		return 0.0
	end
	local diff = tonumber(UITheme.core("Rules").SMART_VS_PLAYERS) or 0
	if ctx:mode() == 1 and ctx.session ~= nil then
		diff = tonumber(ctx.session.difficulty) or 1
	end
	local g = ctx:rules_call("human_grace_ticks", { diff })
	if type(g) ~= "number" then
		return 0.0
	end
	return (ctx.play_start_tick + g - ctx:render_tick()) / Defs.TICK_RATE
end

--- The age model now (nil for a war without ages), and seconds to a timed war's end (nil: no end).
function WarClock._model(self): (any, number?)
	local ctx = self.ctx
	local s = ctx.state
	local Defs = UITheme.core("Defs")
	if s == nil then
		return nil, nil
	end
	local now = ctx:render_tick()
	local end_s = nil
	if s.phase == Defs.PHASE_PLAYING and (s.time_limit_ticks or 0) > 0 then
		end_s = math.ceil(math.max(0, (s.time_limit_ticks - now) / Defs.TICK_RATE))
	end
	if s.eras == nil or s.playing_since == nil or s.playing_since < 0 then
		return nil, end_s
	end
	return DominionStrip.model(s.eras, now - s.playing_since, nil), end_s
end

--- The status line: the truce, then the next age (or a timed war's end), then the world event running.
function WarClock.status_text(self): (string, boolean)
	local T = UITheme
	local m, end_s = self:_model()
	local parts = {}
	local grace = self:grace_left()
	if grace > 0 then
		table.insert(parts, "Truce " .. T.fmt_time(math.ceil(grace)))
	elseif m ~= nil and m.era == 1 then
		table.insert(parts, "Truce over")
	end
	local urgent = false
	local next_text = ""
	if m ~= nil then
		next_text, urgent = DominionStrip.next_text(m.next_name, m.next_s, end_s, T.fmt_time)
	elseif end_s ~= nil then
		next_text = "Ends in " .. T.fmt_time(end_s)
	end
	if next_text ~= "" then
		table.insert(parts, (string.gsub(next_text, " !$", "")))
	end
	-- (the world event has its own chip under the top bar now, with its time left: DoctrineDraft. The line ran out of
	-- room with it, "Truce 0:06 · Reckoning in 1:41 · Tax...", playtest 2026-11-08)
	return table.concat(parts, " · "), urgent
end

--- A phone's time and age, for its strip: "12:34 · EXPANSION".
function WarClock.short_text(self): string
	local T = UITheme
	local m, end_s = self:_model()
	local t = T.fmt_time(if end_s ~= nil then end_s else self.ctx:match_seconds())
	if m == nil then
		return t
	end
	return string.format("%s · %s", t, string.upper(m.name))
end

--- The age's card: what it is for, and when the next comes.
function WarClock.age_card(self): { [string]: any }
	local T = UITheme
	local m = self:_model()
	local spec = { title = "Ages", rows = {} }
	if m ~= nil then
		spec.title = m.name
		spec.body = m.blurb
		if m.next_s ~= nil then
			table.insert(spec.rows, { m.next_name .. " in", T.fmt_time(m.next_s), T.TEXT })
		end
	end
	table.insert(spec.rows, { "War has run", T.fmt_time(self.ctx:match_seconds()), T.TEXT })
	local grace = self:grace_left()
	if grace > 0 then
		table.insert(spec.rows, { "Truce ends in", T.fmt_time(math.ceil(grace)), T.TEXT })
	end
	return spec
end

--- The race's card: who stands where on the way to the win line.
function WarClock.race_card(self): { [string]: any }
	local T = UITheme
	local ctx = self.ctx
	local s = ctx.state
	if s == nil then
		return {}
	end
	local goal = s.win_share or T.core("Rules").WIN_SHARE
	local rows = {}
	for _, r in WarClock.racers(ctx) do
		table.insert(rows, { if r.me then "You" else s:owner_name(r.id), T.fmt_pct(r.share), r.colour })
	end
	return { title = string.format("Race to %s", T.fmt_pct(goal)), body = "The first nation to hold this much of the land wins the war.", rows = rows }
end

function WarClock.refresh(self)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	if s == nil or self._layout == nil then
		return
	end
	local m, end_s = self:_model()
	if not ctx.compact then
		self._time:set_text(T.fmt_time(if end_s ~= nil then end_s else ctx:match_seconds()))
		local status, urgent = self:status_text()
		self._status:set_text(status)
		T.set_font_color(self._status, if urgent then T.DIAL_RED else T.DIAL_MUTED)
		for i, rec in self._ages do
			local cur = m ~= nil and i == m.era
			local done = m ~= nil and i < m.era
			rec.node:add_theme_stylebox_override("panel", T.flat(if cur then T.DIAL_AMBER else T.CLEAR, 8, T.CLEAR, 0, 0, 0))
			T.set_font_color(rec.label, if cur then T.DIAL_INK elseif done then T.DIAL_DIM else T.TEXT)
		end
		local goal = s.win_share or T.core("Rules").WIN_SHARE
		-- (a war only the bell decides, Deadline: its goal is the land itself, not a share)
		self._race_cap:set_text(
			if goal >= 1.0 then "MOST LAND AT THE BELL" else string.format("RACE TO %d%%", math.floor(goal * 100 + 0.5))
		)
		local w = math.max(self._race.size.X, 1)
		local racers = WarClock.racers(ctx)
		for i, mk in self._marks do
			local r = racers[i]
			mk:set_visible(r ~= nil)
			if r ~= nil then
				local x = math.clamp(r.share / math.max(goal, 0.01), 0, 1) * (w - 4)
				mk:set_color(r.colour)
				mk:set_offsets(x, if r.me then -3 else 0, x + 4, if r.me then 3 else 0)
			end
		end
	end
	-- a new age (the first look at a match does not count)
	if m ~= nil and m.era ~= self._era then
		local first = self._era == 0
		self._era = m.era
		if not first and m.era > 1 then
			self.era_changed:Fire(m.era)
		end
	end
end

function WarClock.update(self, delta: number)
	self._acc += delta
	if self._acc >= 0.25 then
		self._acc = 0.0
		if self.ctx.state ~= nil then
			self:refresh()
		end
	end
end

return WarClock
