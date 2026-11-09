--!nonstrict
-- The warhead line: one short line under the top bar saying who fired, while warheads aimed at your land are in flight; the
-- seconds stand on the map, where the first one will fall. It carries an icon and its words, so it never relies on colour;
-- when Flak shoots one down the line and the mark say so for a moment. It takes the same slot as the other lines
-- (Banner.place), and comes first.
--
-- Since 2026-11-03 (the strategy frame) the alert row's red hexagon says who fired: with `line_off` the line stays hidden
-- and only the seconds on the map remain.
--
-- Members: panel, line_off. Methods: apply_layout(), clear(), is_green(), track(uid) -> bool, resolve(uid, intercepted);
-- per frame update(dt).

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local Banner = require("./Banner")
local UICtx = require("./UICtx") :: any

local AlertBanner = W.class(W.Control)

--- The line's width, phones and larger screens (long nation names end in "…", so it never stretches).
AlertBanner.W_PHONE = 350.0
AlertBanner.W_WIDE = 460.0
--- Height it takes in the slot: other lines sit under it.
AlertBanner.LINE_H = 34.0

--- How long a stopped warhead's word stays (seconds).
AlertBanner.STOPPED_S = 1.2

--- The line's words: who fired on you, and with what. `count` warheads, `what` the first one's kind. Pure.
function AlertBanner.text(count: number, what: string, from: string, compact: boolean): string
	if count > 1 then
		return string.format("%s has %d %s in the air", from, count, UICtx.data("PeriodTech").word("warheads"))
	end
	if compact then
		return string.format("Incoming, from %s", from)
	end
	return string.format("%s has a %s in the air", from, what)
end

function AlertBanner.new(c: any)
	local self = setmetatable({}, AlertBanner.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self._incoming = {} -- uid -> true
	self._t = 0.0
	--- Seconds left of the "stopped" state (0 = normal).
	self._green = 0.0
	--- The incoming set changed since the text was written (update() writes it).
	self._stale = false
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self.panel = GlassPanel.new(10.0, 6.0, T.R_MD, true, 0)
	self.panel:set_mouse_filter(W.MOUSE_IGNORE)
	self.panel:set_tint(T.GLASS_SOLID)
	self:add_child(self.panel)
	local row = T.hbox(8)
	self.panel:add_child(row)
	self._icon = T.icon_rect("atom", 16.0, T.RED)
	self._icon.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(self._icon)
	self._line = T.label("", 13, 700, T.TEXT)
	self._line.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(self._line)
	-- the seconds, on the map where the first one falls
	self._mark = GlassPanel.new(6.0, 2.0, T.R_SM, true, 0)
	self._mark:set_mouse_filter(W.MOUSE_IGNORE)
	self._mark:set_tint(T.GLASS_SOLID)
	self._mark_text = T.label("", 13, 800, T.RED)
	self._mark_text:set_tabular(true)
	self._mark:add_child(self._mark_text)
	self:add_child(self._mark)
	self._mark:set_visible(false)
	self._mark_tile = -1
	self:_set_red()
	self:set_visible(false)
	return self
end

--- In the line slot (Banner.place).
function AlertBanner.apply_layout(self)
	local ctx = self.ctx
	local T = UITheme
	self.panel:set_mouse_filter(if ctx.touch then W.MOUSE_STOP else W.MOUSE_IGNORE)
	local w = math.min(if ctx.compact then AlertBanner.W_PHONE else AlertBanner.W_WIDE, ctx.line_max_w or AlertBanner.W_WIDE)
	T.fix_width(self._line, w - 20.0 - 16.0 - 8.0, W.ALIGN_LEFT, false)
	self.panel:set_visible(not self.line_off)
	Banner.place(ctx, self.panel)
	self:_note_slot()
end

--- The other lines make room while this one is up.
function AlertBanner._note_slot(self)
	self.ctx.alert_line_h = if self.visible and not self.line_off then AlertBanner.LINE_H else nil
end

function AlertBanner.clear(self)
	table.clear(self._incoming)
	self._green = 0.0
	self._mark_tile = -1
	self._mark:set_visible(false)
	self:set_visible(false)
	self:_note_slot()
	self:_set_red()
end

--- True while a warhead aimed at the local player is in the air (the siren wails while it is).
function AlertBanner.incoming(self): boolean
	return next(self._incoming) ~= nil
end

function AlertBanner.is_green(self): boolean
	return self._green > 0
end

function AlertBanner._show_green(self, last: boolean)
	local T = UITheme
	self._green = AlertBanner.STOPPED_S
	self:set_visible(true)
	self:_note_slot()
	self:set_modulate_a(1.0)
	self._line:set_text(UICtx.data("PeriodTech").say(if last then "Your Flak took it out of the sky" else "Your Flak took one. More are coming"))
	self.panel:set_border(T.c(T.GREEN, 0.9))
	self._icon:set_icon("sam")
	self._icon:set_color(T.GREEN)
	self.panel:reset_size()
	self._mark_text:set_text("Stopped")
	self._mark_text:set_color(T.GREEN)
	self._mark:reset_size()
end

function AlertBanner._set_red(self)
	local T = UITheme
	self.panel:set_border(T.c(T.RED, 0.85))
	self._icon:set_icon("atom")
	self._icon:set_color(T.RED)
end

--- Returns true when this nuke is newly aimed at the local player, and true again when it is the
--- one that brings the line up.
--- (The text is written once a frame, in update(): a MIRV's 350 warheads are tracked in one tick and
--- land within seconds, and each used to rewrite it and size the panel again.)
function AlertBanner.track(self, uid: number): (boolean, boolean)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or s.nukes[uid] == nil or ctx:me() == 0 then
		return false, false
	end
	local n = s.nukes[uid]
	if n.owner == ctx:me() or s:tile_owner(n.to_tile) ~= ctx:me() then
		return false, false
	end
	local first = next(self._incoming) == nil
	self._incoming[uid] = true
	if first then
		self:set_visible(true)
		self:_note_slot()
		self:_refresh()
	else
		self._stale = true
	end
	return true, first
end

function AlertBanner._hide_when_clear(self)
	if next(self._incoming) == nil and self._green <= 0 then
		self._mark_tile = -1
		self._mark:set_visible(false)
		self:set_visible(false)
		self:_note_slot()
	end
end

--- `intercepted`: Flak shot it down (the line says so before it goes).
function AlertBanner.resolve(self, uid: number, intercepted: boolean?)
	if not self._incoming[uid] then
		return
	end
	self._incoming[uid] = nil
	if intercepted then
		self:_show_green(next(self._incoming) == nil)
		return
	end
	if next(self._incoming) == nil then
		self:_hide_when_clear()
	else
		self._stale = true
	end
end

function AlertBanner._refresh(self)
	self._stale = false
	local ctx = self.ctx
	local s = ctx.state
	if s == nil then
		return
	end
	local Defs = UITheme.core("Defs")
	local soonest = 1e9
	local kind = -1
	local from = 0
	local count = 0
	local gone = {}
	for uid in pairs(self._incoming) do
		local n = s.nukes[uid]
		if n == nil then
			table.insert(gone, uid)
		else
			count += 1
			local left = (n.launch_tick + n.flight_ticks) - ctx:render_tick()
			if left < soonest then
				soonest = left
				kind = n.kind
				from = n.owner
				self._mark_tile = n.to_tile
			end
		end
	end
	for _, uid in ipairs(gone) do
		self._incoming[uid] = nil
	end
	if count == 0 then
		return
	end
	local secs = math.max(0, math.ceil(soonest / Defs.TICK_RATE))
	local what = (if kind >= 0 then Defs.NUKE_TITLES[kind] else nil) or "Warhead"
	self._line:set_text(AlertBanner.text(count, what, s:owner_name(from), ctx.compact))
	self.panel:reset_size()
	self._mark_text:set_text(string.format("%ds", secs))
	self._mark_text:set_color(UITheme.RED)
	self._mark:reset_size()
end

--- The mark stays on its spot as the map moves (off the screen: it waits).
function AlertBanner._place_mark(self)
	local ctx = self.ctx
	local p = if self._mark_tile >= 0 then ctx:tile_screen_pos(self._mark_tile) else Vector2.new(-1, -1)
	self._mark:set_visible(p.X >= 0)
	if p.X >= 0 then
		local sz = self._mark:get_combined_minimum_size()
		self._mark.offset_left, self._mark.offset_top = p.X - sz.X * 0.5, p.Y - sz.Y - 10.0
		self._mark.offset_right, self._mark.offset_bottom = self._mark.offset_left, self._mark.offset_top
		self._mark:queue_layout()
	end
end

--- Per frame (GDScript _process).
function AlertBanner.update(self, delta: number)
	if not self.visible then
		return
	end
	self:_place_mark()
	if self._green > 0 then
		self._green -= delta
		if self._green <= 0 then
			self:_set_red()
			if next(self._incoming) == nil then
				self:_hide_when_clear()
			else
				self:_refresh()
			end
		end
		return
	end
	local prev = self._t
	self._t += delta
	if self._stale or math.floor(self._t * 4.0) ~= math.floor(prev * 4.0) then
		self:_refresh()
	end
end

return AlertBanner
