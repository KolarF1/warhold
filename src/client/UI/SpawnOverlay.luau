--!nonstrict
-- Landfall: one small card at the top middle, in the top bar's place (the status bar is hidden until play): a title that
-- says what to do (TO ARMS IN once your banner is down or the start is near), the seconds left as a number under it, and a
-- thin bar running down. Red and popping each second over the last five. Once your banner is down, a slow ring of dots on
-- the map around it shows it can still move. (Playtest 2026-11-08, the owner: the old pair, a line by Roblox's buttons and a
-- big box over the map, was untidy; one clean card at the top middle.) It lets every click through.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Cadence = require("../Audio/Cadence")
local Defs = UICtx.core("Defs")

local _Rules = nil
local function Rules()
	if _Rules == nil then
		_Rules = UICtx.core("Rules")
	end
	return _Rules
end

local SpawnOverlay = W.class(W.Control)

SpawnOverlay.TITLE_PX = 13
SpawnOverlay.NUM_PX = 15
SpawnOverlay.BAR_H = 3.0
SpawnOverlay.PAD_H = 12.0
--- The card's bar width (logical px).
SpawnOverlay.BAR_W = 200
--- The ring of dots around a planted banner.
SpawnOverlay.RING_DOTS = 8
SpawnOverlay.RING_R = 20.0
SpawnOverlay.RING_DOT_R = 2.5
--- The big count: its number's size, and from how many seconds left it shows before your banner is down.
SpawnOverlay.COUNT_PX = 40
SpawnOverlay.COUNT_PX_PHONE = 30
SpawnOverlay.COUNT_BIG_S = 10.0

--- Whether the big count shows: a timed start, and your banner down or the start near. Pure.
function SpawnOverlay.big_count(timed: boolean, placed: boolean, left: number): boolean
	return timed and left >= 0.0 and (placed or left <= SpawnOverlay.COUNT_BIG_S)
end

--- What the line says for this state. Pure.
function SpawnOverlay.title(me: number, late: boolean, placed: boolean, solo: boolean, left: number): string
	if me == 0 then
		return "THE RULERS LAND"
	elseif late and not placed then
		return "YOU ARE LATE: PLANT NOW"
	elseif placed and solo and left >= 0.0 then
		return "LANDFALL"
	elseif placed then
		return "YOUR BANNER STANDS"
	end
	return "PLANT YOUR BANNER"
end

function SpawnOverlay.new(c: any)
	local self = setmetatable({}, SpawnOverlay.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self._end_tick = -1.0
	self._total = 1.0
	self._last_sec = -1
	self._accum = 0.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	local panel = GlassPanel.new(SpawnOverlay.PAD_H, 7.0, T.R_LG, true, 12)
	panel:set_mouse_filter(W.MOUSE_IGNORE)
	self.panel = panel
	self:add_child(panel)
	local v = T.vbox(2)
	panel:add_child(v)
	self._title = T.label("PLANT YOUR BANNER", SpawnOverlay.TITLE_PX, 800, T.TEXT_DIM)
	self._title.horizontal_alignment = W.ALIGN_CENTER
	v:add_child(self._title)
	self._num = T.label("", SpawnOverlay.COUNT_PX, 900, T.TEXT)
	self._num.horizontal_alignment = W.ALIGN_CENTER
	self._num:set_tabular(true)
	v:add_child(self._num)
	self._bar = W.ColorRect.new(T.c(T.WHITE, 0.14))
	self._bar:set_mouse_filter(W.MOUSE_IGNORE)
	self._bar:set_min_size(Vector2.new(SpawnOverlay.BAR_W, SpawnOverlay.BAR_H))
	self._bar.size_flags_horizontal = W.SHRINK_CENTER
	v:add_child(self._bar)
	self._fill = W.ColorRect.new(T.AMBER)
	self._fill:set_mouse_filter(W.MOUSE_IGNORE)
	self._fill:set_anchors(0, 0, 1, 1)
	self._fill:set_offsets(0, 0, 0, 0)
	self._bar:add_child(self._fill)
	-- the ring around a planted banner
	self._ring = UICtx.canvas(self.gui, "BannerRing")
	self._ring.Visible = false
	self._dots = {}
	for i = 1, SpawnOverlay.RING_DOTS do
		self._dots[i] = UICtx.circle(self._ring, Vector2.zero, SpawnOverlay.RING_DOT_R, T.TEXT, 0)
	end
	self._t = 0.0
	self:set_process(true)
	return self
end

--- How wide the line may be on this screen.
function SpawnOverlay._room(self): number
	local ctx = self.ctx
	local res = ctx.reserved_top_left
	return ctx.vp.X - (if res ~= nil then res.Max.X else 0.0) - ctx.insets.z - 18.0
end

function SpawnOverlay.apply_layout(self)
	local ctx = self.ctx
	local panel = self.panel
	panel:set_mouse_filter(if ctx.touch then W.MOUSE_STOP else W.MOUSE_IGNORE)
	panel.anchor_top, panel.anchor_bottom = 0.0, 0.0
	panel.grow_vertical = W.GROW_END
	-- the top middle, on every screen
	self._num:set_font_size(if ctx.compact then SpawnOverlay.COUNT_PX_PHONE else SpawnOverlay.COUNT_PX)
	panel.anchor_left, panel.anchor_right = 0.5, 0.5
	panel.grow_horizontal = W.GROW_BOTH
	panel.offset_left, panel.offset_right = 0.0, 0.0
	local y = 8.0 + ctx.insets.y
	panel.offset_top, panel.offset_bottom = y, y
	panel:reset_size()
end

function SpawnOverlay.bottom_edge(self): number
	local r = self.panel:get_global_rect()
	return r.Max.Y
end

function SpawnOverlay.on_show(self)
	self._last_sec = -1
	self:refresh()
	UICtx.pop_in(self.panel, 0.0, 1.0, 0.15, true)
end

function SpawnOverlay.on_phase(self, ticks_left: number)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil then
		return
	end
	self._end_tick = if ticks_left > 0 then s.tick + ticks_left else -1.0
	if ticks_left > 0 then
		local R = Rules()
		local solo_total = if ctx:mode() == UICtx.MODE_SOLO then R.SOLO_COUNTDOWN_TICKS else R.DEFAULT_SPAWN_TICKS
		self._total = math.max(ticks_left, solo_total) / Defs.TICK_RATE
	end
	self:refresh()
end

function SpawnOverlay.refresh(self)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	if s == nil then
		return
	end
	local o = ctx:my()
	local placed = o ~= nil and o.spawned
	local solo = ctx:mode() == UICtx.MODE_SOLO
	local left = -1.0
	if self._end_tick > 0.0 then
		left = math.max(0.0, (self._end_tick - ctx:render_tick()) / Defs.TICK_RATE)
	end
	local timed = left >= 0.0 and s.phase == Defs.PHASE_SPAWN
	self._num:set_visible(timed)
	self._bar:set_visible(timed)
	if left >= 0.0 then
		local urgent = left <= 5.0
		local sec = math.ceil(left)
		self._num:set_text(tostring(sec))
		T.set_font_color(self._num, if urgent then T.RED else T.TEXT)
		self._fill:set_color(if urgent then T.RED else T.AMBER)
		self._fill:set_anchors(0, 0, math.clamp(left / math.max(self._total, 0.1), 0.0, 1.0), 1)
		self._fill:set_offsets(0, 0, 0, 0)
		if sec ~= self._last_sec and urgent and self._last_sec >= 0 then
			UICtx.pop_in(self._num, 0.0, 0.8, 0.25, true)
		end
		-- (the last three seconds sound, rising: Audio/Cadence)
		local beat = Cadence.SPAWN_TICKS[sec]
		if sec ~= self._last_sec and beat ~= nil and self._last_sec >= 0 then
			ctx:sfx("tick", beat[1], 0.0, beat[2])
		end
		self._last_sec = sec
	end
	-- (TO ARMS IN once your banner is down, or in the last seconds; before that, what to do)
	local arms = SpawnOverlay.big_count(timed, placed == true, left)
	self._title:set_text(if arms then "TO ARMS IN" else SpawnOverlay.title(ctx:me(), s.phase == Defs.PHASE_PLAYING, placed == true, solo, left))
	self.panel:reset_size()
end

--- The ring of dots on the map around your planted banner, turning slowly.
function SpawnOverlay._draw_ring(self, delta: number)
	local ctx = self.ctx
	local s = ctx.state
	local o = if s ~= nil then ctx:my() else nil
	local tile = if o ~= nil and o.spawned then (o.spawn_tile or -1) else -1
	local p = if tile >= 0 and s.phase == Defs.PHASE_SPAWN then ctx:tile_screen_pos(tile) else Vector2.new(-1, -1)
	if p.X < 0.0 then
		self._ring.Visible = false
		return
	end
	ctx:fit_canvas(self._ring)
	self._ring.Visible = true
	if not UITheme.reduced_motion then
		self._t += delta
	end
	for i, d in self._dots do
		local a = self._t * 0.6 + (i - 1) / #self._dots * 2 * math.pi
		UICtx.set_circle(d, p + Vector2.new(math.cos(a), math.sin(a)) * SpawnOverlay.RING_R, SpawnOverlay.RING_DOT_R)
	end
end

function SpawnOverlay._process(self, delta: number)
	if self:is_visible_in_tree() then
		self:_draw_ring(delta)
	elseif self._ring.Visible then
		self._ring.Visible = false
	end
	self._accum += delta
	if self._accum >= 0.1 and self:is_visible_in_tree() then
		self._accum = 0.0
		self:refresh()
	end
end

return SpawnOverlay
