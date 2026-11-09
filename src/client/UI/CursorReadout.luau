--!nonstrict
-- The send beside the cursor (2026-11-03, the strategy frame; it replaced the command dial's ring): over land a click
-- would attack or claim, a read-only "25% · 2.1k" stands just right of the pointer, in the send's amber. It is a
-- readout, not a control: the send panel's presets and the keys set the send. Mouse only: a phone has no hover.
--
-- Members: label (the node), shown. Methods: show(pos, spec), move(pos), hide(), refresh(). `spec`: UIInteract's
-- ring_target ({ verb, name, ... }); only that a target is there matters here.

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameKit = require("./FrameKit")

local CursorReadout = {}
CursorReadout.__index = CursorReadout

--- How far right of and below the pointer it stands.
CursorReadout.OFFSET = Vector2.new(18, 8)

--- The words: "25% · 2.1k". Pure.
function CursorReadout.text(ratio: number, troops: number): string
	return string.format("%s · %s", UICtx.ratio_name(ratio), UITheme.fmt_troops(troops))
end

function CursorReadout.new(c: any)
	local self = setmetatable({}, CursorReadout)
	local T = UITheme
	self.ctx = c
	self.shown = false
	self._pos = Vector2.zero
	local label = FrameKit.slate(0.9)
	label.name = "CursorReadout"
	label:set_mouse_filter(W.MOUSE_IGNORE)
	local text = FrameKit.value("", 16, T.DIAL_AMBER)
	text:set_anchors(0, 0, 1, 1)
	text:set_offsets(8, 0, -8, 0)
	text.vertical_alignment = W.VALIGN_CENTER
	label:add_child(text)
	self.label = label
	self._text = text
	label:set_visible(false)
	c.ratio_changed:Connect(function(_r)
		if self.shown then
			self:refresh()
		end
	end)
	return self
end

function CursorReadout.refresh(self)
	local ctx = self.ctx
	local t = CursorReadout.text(ctx.ratio, ctx:troops_for_ratio())
	self._text:set_text(t)
	self._w = UITheme.measure_text(t, 16, UITheme.DIAL_WEIGHT) + 18
end

function CursorReadout.show(self, pos: Vector2, _spec: any)
	if not self.shown then
		self.shown = true
		self.label:set_visible(true)
	end
	self:refresh()
	self:move(pos)
end

function CursorReadout.move(self, pos: Vector2)
	self._pos = pos
	local p = pos + CursorReadout.OFFSET
	local w = self._w or 96
	FrameKit.place(self.label, { x0 = math.floor(p.X), y0 = math.floor(p.Y), x1 = math.floor(p.X + w), y1 = math.floor(p.Y + 26) })
end

function CursorReadout.hide(self)
	if not self.shown then
		return
	end
	self.shown = false
	self.label:set_visible(false)
end

return CursorReadout
