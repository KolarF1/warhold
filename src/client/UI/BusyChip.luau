--!nonstrict
-- One plain line low on the screen while a match is being built: the map forms behind it. No plate to speak of, nothing that spins.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local UICtx = require("./UICtx")

local BusyChip = W.class(W.Control)

--- How far above the bottom safe edge the line stands.
BusyChip.BOTTOM = 64.0

function BusyChip.new(c: any)
	local self = setmetatable({}, BusyChip.__mt)
	W.Control._init(self)
	self.ctx = c
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._plate = W.Panel.new()
	self._plate:set_mouse_filter(W.MOUSE_IGNORE)
	self._plate:add_theme_stylebox_override("panel", UITheme.flat(UITheme.GLASS_SOLID, UITheme.R_SM, UITheme.CLEAR, 0, 12.0, 5.0))
	self._label = UITheme.label("", 13, 600, UITheme.TEXT)
	self._plate:add_child(self._label)
	self:add_child(self._plate)
	self:set_visible(false)
	return self
end

function BusyChip.show_text(self, text: string)
	self._label:set_text(text)
	local p = self._plate
	local b = -(BusyChip.BOTTOM + self.ctx.insets.w)
	p.anchor_left, p.anchor_right, p.anchor_top, p.anchor_bottom = 0.5, 0.5, 1.0, 1.0
	p.grow_horizontal = W.GROW_BOTH
	p.grow_vertical = W.GROW_BEGIN
	p.offset_left, p.offset_right = 0.0, 0.0
	p.offset_top, p.offset_bottom = b, b
	p:reset_size()
	if not self.visible then
		self:set_visible(true)
		self:set_modulate_a(0.0)
		W.fade(self, 1.0, 0.12)
	end
end

function BusyChip.hide_chip(self)
	if not self.visible then
		return
	end
	local t = self:create_tween()
	t:tween_property(self, "modulate:a", 0.0, 0.14)
	t:tween_callback(function()
		self:set_visible(false)
		self:set_modulate_a(1.0)
	end)
end

return BusyChip
