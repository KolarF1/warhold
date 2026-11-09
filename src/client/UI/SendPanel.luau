--!nonstrict
-- The send panel (2026-11-03, the owner: the troop share is a full part of the bottom right, every step a button, no
-- drop-down, the wheel never changes it): a card standing on the war clock, as wide as it. Its head says the share an
-- order sends and its troops; under it the five presets (FrameRules.PRESETS) as one segmented control, the one in use a
-- filled amber block (the dark cards, 2026-11-06).
-- Keys 1-5 pick them and Q / E move the share a point at a time (UIInteract); a free share between presets lights none.
-- A phone has its own presets for the left thumb (OrderHub), so this is the desktop's.
--
-- UIRoot knows it as `send_panel`. Members: panel. Methods: apply_layout(), refresh(), preset_rect(r), rect().

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")

local SendPanel = W.class(W.Control)

SendPanel.BUTTON_H = 34
SendPanel.BUTTON_FONT = 17

function SendPanel.new(c: any)
	local self = setmetatable({}, SendPanel.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	local panel = FrameKit.slate()
	panel.name = "SendPanel"
	panel:set_mouse_filter(W.MOUSE_STOP)
	self.panel = panel
	self:add_child(panel)
	local v = T.vbox(8)
	v:set_anchors(0, 0, 1, 1)
	v:set_offsets(14, 10, -14, -10)
	panel:add_child(v)
	local head = T.hbox(8)
	-- (a touch screen has no keys to name)
	local cap = FrameKit.caption(if c.touch then "SEND" else FrameRules.SEND_CAPTION)
	self._cap = cap
	cap.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(cap)
	self._value = FrameKit.value("", 20, T.DIAL_AMBER)
	self._value.size_flags_horizontal = W.EXPAND_FILL
	self._value.size_flags_vertical = W.SHRINK_CENTER
	self._value.horizontal_alignment = W.ALIGN_RIGHT
	head:add_child(self._value)
	v:add_child(head)
	-- the shares as one segmented control: a faint rounded track, the share in use a filled amber block
	local seg = W.Control.new()
	seg:set_mouse_filter(W.MOUSE_IGNORE)
	seg:set_min_size(Vector2.new(0, SendPanel.BUTTON_H + 8))
	local track = FrameKit.track(14)
	track:set_anchors(0, 0, 1, 1)
	seg:add_child(track)
	local row = T.hbox(4)
	row:set_anchors(0, 0, 1, 1)
	row:set_offsets(4, 4, -4, -4)
	self._presets = FrameKit.preset_buttons(c, row, SendPanel.BUTTON_H, SendPanel.BUTTON_FONT, nil, true)
	seg:add_child(row)
	v:add_child(seg)
	FrameKit.hover(c, head, function()
		return self:card()
	end)
	self:_connect(c.ratio_changed:Connect(function(_r)
		self:refresh()
	end))
	return self
end

function SendPanel.apply_layout(self)
	local ctx = self.ctx
	local r = ctx.reserved_top_left
	local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), {})
	self.panel:set_visible(not ctx.compact)
	if not ctx.compact then
		FrameKit.place(self.panel, l.send)
	end
	self._cap:set_text(if ctx.touch then "SEND" else FrameRules.SEND_CAPTION)
	self:refresh()
end

--- The head's words: the share and the troops it sends ("25% · 2.1k troops").
function SendPanel.text(self): string
	local ctx = self.ctx
	return string.format("%s · %s troops", UICtx.ratio_name(ctx.ratio), UITheme.fmt_troops(ctx:troops_for_ratio()))
end

function SendPanel.refresh(self)
	if self.ctx.state == nil then
		return
	end
	self._value:set_text(self:text())
	FrameKit.light_presets(self.ctx, self._presets)
end

function SendPanel.card(self): { [string]: any }
	local ctx = self.ctx
	return {
		title = "Send",
		body = string.format(
			"One order sends %s of your army: %s troops. Press a share, or keys 1-5 for 10, 25, 50, 75 or 100%%; Q / E move it one point.",
			UICtx.ratio_name(ctx.ratio),
			UITheme.fmt_troops(ctx:troops_for_ratio())
		),
	}
end

--- Where preset `r` is (the tutorial and counsel point at it), or the panel when `r` is a free share.
function SendPanel.preset_rect(self, r: number): Rect?
	if not self.panel:is_visible_in_tree() then
		return nil
	end
	local i = FrameRules.preset_index(r)
	local b = if i ~= nil then self._presets[i] else nil
	return if b ~= nil then b:get_global_rect() else self.panel:get_global_rect()
end

function SendPanel.rect(self): Rect?
	return if self.panel:is_visible_in_tree() then self.panel:get_global_rect() else nil
end

function SendPanel.update(self, delta: number)
	self._acc = (self._acc or 0.0) + delta
	if self._acc >= 0.25 then
		self._acc = 0.0
		if self:is_visible_in_tree() then
			-- (the troops it sends grow with the army)
			self._value:set_text(self:text())
		end
	end
end

return SendPanel
