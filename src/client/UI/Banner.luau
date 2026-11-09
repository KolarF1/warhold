--!nonstrict
-- A short plain line under the top bar, for a moment that matters (an era begins, a world event, landfall over):
-- a small flat plate with a tick in the moment's colour, the words, and nothing else. No band, no letter-spaced
-- slam, no scale. One at a time: a newer line replaces the one on show.
--
-- Where it goes is the "line slot" UIRoot keeps on the context (ctx.line_top, ctx.line_left / ctx.line_right,
-- ctx.line_max_w); the warhead line (AlertBanner) uses the same slot and comes first.

local UITheme = require("./UITheme")
local W = require("./Widgets")

local Banner = W.class(W.Control)

Banner.TITLE_PX = 13
Banner.SUB_PX = 12
Banner.PAD_H = 10.0
--- Between a line's title and its words (the heavy title draws a little wider than it measures).
Banner.WORD_GAP = 16
Banner.PAD_V = 5.0
Banner.TICK_W = 3.0

--- Where a plate `w` wide goes in the line slot: pins `c` there. Used by the warhead line too.
function Banner.place(ctx: any, c: any, y_extra: number?)
	local y = (ctx.line_top or (12.0 + ctx.insets.y)) + (y_extra or 0.0)
	c.anchor_top, c.anchor_bottom = 0.0, 0.0
	c.grow_vertical = W.GROW_END
	c.offset_top, c.offset_bottom = y, y
	if ctx.line_right ~= nil then
		c.anchor_left, c.anchor_right = 1.0, 1.0
		c.grow_horizontal = W.GROW_BEGIN
		c.offset_left, c.offset_right = -ctx.line_right, -ctx.line_right
	else
		local x = ctx.line_left or (12.0 + ctx.insets.x)
		c.anchor_left, c.anchor_right = 0.0, 0.0
		c.grow_horizontal = W.GROW_END
		c.offset_left, c.offset_right = x, x
	end
	c:reset_size()
end

--- How `title` and `sub` sit in `max_w`: side by side if they fit, else one above the other (true). Pure.
function Banner.stacks(title: string, sub: string, max_w: number): boolean
	if sub == "" then
		return false
	end
	local T = UITheme
	local room = max_w - 2 * Banner.PAD_H - Banner.TICK_W - 8.0 - Banner.WORD_GAP
	return T.text_width(title, Banner.TITLE_PX, 800) + T.text_width(sub, Banner.SUB_PX, 500) > room
end

local _current: any = nil

--- Banner.make(ctx, title, sub, col, hold = 2): add the returned node to a full-rect layer; it frees itself.
--- `.text_area` is the plate, for map labels to step around.
--- `centre` (a world event, 2026-11-08: more central): the plate stands at the top middle, a fifth of the way down.
function Banner.make(ctx: any, title: string, sub: string, col: any, hold: number?, centre: boolean?)
	local T = UITheme
	local b = setmetatable({}, Banner.__mt)
	W.Control._init(b)
	b:set_mouse_filter(W.MOUSE_IGNORE)
	b:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	if _current ~= nil and not _current._freed then
		_current:queue_free()
	end
	_current = b
	local plate = W.Panel.new()
	plate:set_mouse_filter(W.MOUSE_IGNORE)
	plate:add_theme_stylebox_override("panel", T.flat(T.GLASS_SOLID, T.R_MD, T.LINE, 1, Banner.PAD_H, Banner.PAD_V))
	local max_w = ctx.line_max_w or (ctx.vp.X - ctx.insets.x - ctx.insets.z - 24.0)
	local stacked = Banner.stacks(title, sub, max_w)
	local row = T.hbox(8)
	row:set_mouse_filter(W.MOUSE_IGNORE)
	local tick = W.ColorRect.new(col)
	tick:set_mouse_filter(W.MOUSE_IGNORE)
	tick:set_min_size(Vector2.new(Banner.TICK_W, 14))
	tick.size_flags_vertical = W.EXPAND_FILL
	row:add_child(tick)
	local words = if stacked then T.vbox(1) else T.hbox(Banner.WORD_GAP)
	words:set_mouse_filter(W.MOUSE_IGNORE)
	local t = T.label(title, Banner.TITLE_PX, 800, T.TEXT)
	t.size_flags_vertical = W.SHRINK_CENTER
	words:add_child(t)
	if sub ~= "" then
		local s = T.label(sub, Banner.SUB_PX, 500, T.TEXT_2)
		s.size_flags_vertical = W.SHRINK_CENTER
		if stacked then
			s:set_autowrap(true)
			s:set_min_size(Vector2.new(math.max(120.0, max_w - 2 * Banner.PAD_H - Banner.TICK_W - 8.0), 0))
		end
		words:add_child(s)
	end
	row:add_child(words)
	plate:add_child(row)
	b:add_child(plate)
	b.title_label = t
	b.text_area = plate
	if centre then
		plate.anchor_left, plate.anchor_right = 0.5, 0.5
		plate.anchor_top, plate.anchor_bottom = 0.0, 0.0
		plate.grow_horizontal = W.GROW_BOTH
		plate.grow_vertical = W.GROW_END
		local y = math.floor(ctx.vp.Y * 0.2)
		plate.offset_left, plate.offset_right = 0, 0
		plate.offset_top, plate.offset_bottom = y, y
		plate:reset_size()
	else
		-- (the warhead line has the slot first: this one sits under it)
		Banner.place(ctx, plate, ctx.alert_line_h)
	end
	local hold_s = hold or 2.0
	if T.reduced_motion then
		task.delay(hold_s + 0.5, function()
			if not b._freed then
				b:queue_free()
			end
		end)
		return b
	end
	b:set_modulate_a(0.0)
	W.defer(function()
		if b._freed then
			return
		end
		local tw = b:create_tween()
		tw:tween_property(b, "modulate:a", 1.0, 0.12)
		tw:tween_interval(hold_s)
		tw:tween_property(b, "modulate:a", 0.0, 0.25)
		tw:tween_callback(function()
			b:queue_free()
		end)
	end)
	return b
end

return Banner
