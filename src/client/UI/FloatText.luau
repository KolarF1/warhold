--!nonstrict
-- A confirmation beside the map cursor: plain text with a small tick in the action's colour, there for a moment and
-- gone ("Marching on Brazil with 2.4k"). No pill, and it doesn't move. A refusal ("Too far to reach") shows a small
-- cross instead of a tick. One at a time: a newer one replaces it.
--
-- FloatText.spawn(parent_node, pos_logical, text, icon_name, col, bounds_rect?)
-- FloatText.bounds_provider: () -> Rect (logical px) -- live area floats must stay inside, re-read
-- every frame (a tray opening later pushes floats above it).

local UITheme = require("./UITheme")
local W = require("./Widgets")

local FloatText = W.class(W.Control)

FloatText.bounds_provider = nil :: (() -> Rect)?
--- Seconds on screen.
FloatText.LIFETIME = 1.6
--- From the cursor to the tick.
FloatText.BESIDE = Vector2.new(16, -10)

--- The mark: UIInteract floats a refusal with the "info" icon, everything else is an order given.
function FloatText.mark(icon_name: string?): string
	return if icon_name == "info" then "×" else "✓"
end

local _current: any = nil

function FloatText.spawn(parent: any, pos: Vector2, text: string, icon_name: string?, col: any, bounds: Rect?)
	if parent == nil or text == nil or text == "" then
		return nil
	end
	if _current ~= nil and not _current._freed then
		_current:queue_free()
	end
	local T = UITheme
	local ft = setmetatable({}, FloatText.__mt)
	W.Control._init(ft)
	_current = ft
	ft:set_mouse_filter(W.MOUSE_IGNORE)
	ft._age = 0.0
	ft._fixed_bounds = bounds
	parent:add_child(ft)
	local row = T.hbox(5)
	row:set_mouse_filter(W.MOUSE_IGNORE)
	local mark = T.label(FloatText.mark(icon_name), 14, 800, col)
	mark:set_shadow(T.rgba(0, 0, 0, 0.75), 1, 3)
	mark.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(mark)
	local l = T.label(text, 13, 700, T.TEXT)
	l:set_shadow(T.rgba(0, 0, 0, 0.75), 1, 3)
	l.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(l)
	row:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	ft:add_child(row)
	ft._sz = row:get_combined_minimum_size()
	local p = pos + FloatText.BESIDE
	ft._x, ft._base_y = p.X, p.Y
	ft:_clamp()
	ft:set_process(true)
	return ft
end

function FloatText._clamp(self)
	local b = self._fixed_bounds
	local prov = FloatText.bounds_provider
	if prov ~= nil then
		local ok, v = pcall(prov)
		if ok and typeof(v) == "Rect" and v.Width > 0 then
			b = v
		end
	end
	if b == nil or b.Width <= 0 then
		local vp = if self.root then self.root.vp else Vector2.new(1600, 900)
		b = Rect.new(0, 0, vp.X, vp.Y)
	end
	local sz = self._sz
	local x = math.clamp(self._x, b.Min.X + 8.0, math.max(b.Min.X + 8.0, b.Max.X - sz.X - 8.0))
	local y = math.clamp(self._base_y, b.Min.Y + 8.0, math.max(b.Min.Y + 8.0, b.Max.Y - sz.Y - 8.0))
	self.offset_left = x
	self.offset_top = y
	self.offset_right = x + sz.X
	self.offset_bottom = y + sz.Y
	self:_layout_free()
end

function FloatText._process(self, delta: number)
	self._age += delta
	if self._age >= FloatText.LIFETIME then
		self:queue_free()
		return
	end
	self:_clamp()
end

return FloatText
