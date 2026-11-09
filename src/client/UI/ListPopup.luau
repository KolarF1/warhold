--!nonstrict
-- A small list window of the strategy frame (2026-11-03): a title, a line under it, and rows of words, each with up to two
-- buttons; a press on a row's words runs its `go`. CHANCES, Pacts and Doctrine open one beside what was pressed. It never
-- covers the screen, closes on its X, on a second press of what opened it, and on Esc.
--
--   ListPopup.new(ctx)
--   :open(key, title, sub, rows, at)   rows: { { text, sub?, colour?, go?, actions = { { label, fn, variation? } } } };
--                                       at: the box it stands beside (logical px) ; a second open with the same key closes
--   :close(), .is_open, .key, panel

local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameKit = require("./FrameKit")

local ListPopup = W.class(W.Control)

ListPopup.W = 320
ListPopup.MAX_ROWS = 8

function ListPopup.new(c: any)
	local self = setmetatable({}, ListPopup.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.is_open = false
	self.key = ""
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	local panel = FrameKit.slate(0.97)
	panel:set_mouse_filter(W.MOUSE_STOP)
	self.panel = panel
	self:add_child(panel)
	local v = T.vbox(6)
	v:set_anchors(0, 0, 1, 1)
	v:set_offsets(12, 12, -12, -10)
	self._box = v
	panel:add_child(v)
	local head = T.hbox(8)
	self._title = T.label("", 16, T.DIAL_WEIGHT, T.TEXT, 1)
	self._title.size_flags_horizontal = W.EXPAND_FILL
	self._title.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._title)
	local close = T.button("", "DialGhost", "close", 36.0)
	close:set_min_size(Vector2.new(36, 36))
	close.pressed:Connect(function()
		self:close()
	end)
	self._close = close
	head:add_child(close)
	v:add_child(head)
	self._sub = T.label("", 13, 600, T.DIAL_MUTED)
	self._sub:set_autowrap(true)
	self._sub:set_min_size(Vector2.new(ListPopup.W - 24, 0))
	v:add_child(self._sub)
	self._rows = {}
	for i = 1, ListPopup.MAX_ROWS do
		local row = T.hbox(6)
		local words = W.Button.new("", "DialGhost")
		words:set_min_size(Vector2.new(0, 40))
		words.size_flags_horizontal = W.EXPAND_FILL
		local tv = T.vbox(0)
		tv:set_anchors(0, 0, 1, 1)
		tv:set_offsets(8, 3, -8, -3)
		tv:set_alignment(W.ALIGN_CENTER)
		local line = T.label("", 14, 700, T.TEXT)
		line.clip_text = true
		line.text_overrun_behavior = W.OVERRUN_ELLIPSIS
		tv:add_child(line)
		local sub = T.label("", 12, 600, T.DIAL_MUTED)
		tv:add_child(sub)
		words:add_child(tv)
		row:add_child(words)
		local rec = { row = row, words = words, line = line, sub = sub, btns = {} }
		words.pressed:Connect(function()
			if rec.go ~= nil then
				rec.go()
			end
		end)
		for j = 1, 2 do
			local b = T.button("", "DialGhost", "", 40.0)
			b:set_font_size(13)
			b:set_min_size(Vector2.new(64, 40))
			b.pressed:Connect(function()
				local a = rec.actions and rec.actions[j]
				if a ~= nil and a.fn ~= nil then
					a.fn()
				end
			end)
			row:add_child(b)
			rec.btns[j] = b
		end
		v:add_child(row)
		self._rows[i] = rec
	end
	self:set_visible(false)
	return self
end

--- Opens with `rows` beside the box `at`; the same `key` again closes it.
function ListPopup.open(self, key: string, title: string, sub: string, rows: { any }, at: any)
	if self.is_open and self.key == key then
		self:close()
		return
	end
	self.key = key
	self._at = at
	self:fill(title, sub, rows)
	self.is_open = true
	self:set_visible(true)
	self.ctx:sfx("open", -8.0)
end

--- Rewrites what is open (a refresh of its rows).
function ListPopup.fill(self, title: string, sub: string, rows: { any })
	local T = UITheme
	self._title:set_text(title)
	self._sub:set_text(sub)
	self._sub:set_visible(sub ~= "")
	for i, rec in self._rows do
		local r = rows[i]
		rec.row:set_visible(r ~= nil)
		rec.go = if r ~= nil then r.go else nil
		rec.actions = if r ~= nil then r.actions else nil
		if r ~= nil then
			rec.line:set_text(r.text)
			T.set_font_color(rec.line, r.colour or T.TEXT)
			rec.sub:set_text(r.sub or "")
			rec.sub:set_visible((r.sub or "") ~= "")
			for j, b in rec.btns do
				local a = r.actions and r.actions[j]
				b:set_visible(a ~= nil)
				if a ~= nil then
					b:set_text(a.label)
					b:set_disabled(a.disabled == true)
				end
			end
		end
	end
	self:place()
end

function ListPopup.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	self:set_visible(false)
	self.ctx:sfx("close", -8.0)
end

--- Beside what opened it: under it when there is room, else to its left; always on the screen.
function ListPopup.place(self)
	local ctx = self.ctx
	local p = self.panel
	p:set_min_size(Vector2.new(ListPopup.W, 0))
	p:reset_size()
	local sz = self._box:get_combined_minimum_size() + Vector2.new(24, 22)
	local at = self._at or { x0 = ctx.vp.X * 0.5, y0 = ctx.vp.Y * 0.3, x1 = ctx.vp.X * 0.5, y1 = ctx.vp.Y * 0.3 }
	local x = math.clamp(at.x1 - sz.X, ctx.insets.x + 8, math.max(ctx.insets.x + 8, ctx.vp.X - ctx.insets.z - 8 - sz.X))
	local y = at.y1 + 8
	if y + sz.Y > ctx.vp.Y - ctx.insets.w - 8 then
		y = math.max(ctx.insets.y + 8, at.y0 - 8 - sz.Y)
		x = math.clamp(at.x0 - 8 - sz.X, ctx.insets.x + 8, math.max(ctx.insets.x + 8, ctx.vp.X - ctx.insets.z - 8 - sz.X))
	end
	FrameKit.place(p, { x0 = math.floor(x), y0 = math.floor(y), x1 = math.floor(x + sz.X), y1 = math.floor(y + sz.Y) })
end

function ListPopup.rect(self): Rect?
	return if self.is_open then self.panel:get_global_rect() else nil
end

return ListPopup
