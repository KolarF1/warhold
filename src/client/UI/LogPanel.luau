--!nonstrict
-- The match log (2026-11-03, the owner: the log is always on screen at the bottom left, with a fold to hide it, and a
-- setting to keep it hidden): a slate at the bottom left with a head (MATCH LOG and its fold) and the latest news,
-- newest first (UI/NewsLog, the same lines the outliner's LOG held). Folded it is its head alone; with the setting
-- "log_hidden" on it is gone. Its height now is ctx.log_h (0 when hidden), which the placing line keeps clear of
-- (FrameRules.layout's log_h). While the selection window reaches down into it, the log stands back (hidden: the command
-- bar holds the room beside it since 2026-11-06), and comes back when it closes. A phone keeps its log in the "Your war" sheet.
--
-- UIRoot knows it as `log_panel`. Signals: resized() (its height changed: the HUD lays out again). Members: panel,
-- left_window (() -> Rect?: the selection window's rect while it is open; UIRoot sets it).
-- Methods: apply_layout(), refresh(), set_open(on), set_hidden(on), is_open(), update(dt).

local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")
local Signal = UITheme.core("Signal")

local LogPanel = W.class(W.Control)

--- The saved settings: the fold, and the Settings switch that keeps it hidden.
LogPanel.OPEN_KEY = "log_open"
LogPanel.HIDDEN_KEY = "log_hidden"

function LogPanel.new(c: any, log: any)
	local self = setmetatable({}, LogPanel.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.log = log
	self.resized = Signal.new()
	self._dirty = true
	self._aside = false
	self.left_window = nil
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	-- (solid: the map's names showed through it, playtest 2026-11-08)
	local panel = FrameKit.slate(0.97)
	panel.name = "MatchLog"
	panel:set_mouse_filter(W.MOUSE_STOP)
	panel:set_clip_contents(true)
	self.panel = panel
	self:add_child(panel)
	-- the head: a press folds it
	local head = W.Button.new("", "GhostButton")
	head:set_flat(true)
	for _, st in ipairs(W.BUTTON_STATES or {}) do
		head:add_theme_stylebox_override(st, T.empty_box())
	end
	head:set_anchors(0, 0, 1, 0)
	head:set_offsets(0, 0, 0, FrameRules.LOG_HEAD_H)
	local title = FrameKit.caption("MATCH LOG")
	title:set_anchors(0, 0, 1, 1)
	title:set_offsets(12, 0, -40, 0)
	title.vertical_alignment = W.VALIGN_CENTER
	head:add_child(title)
	self._fold = T.label("–", 15, 800, T.DIAL_MUTED)
	self._fold:set_anchors(1, 0, 1, 1)
	self._fold:set_offsets(-34, 0, -12, 0)
	self._fold.horizontal_alignment = W.ALIGN_RIGHT
	self._fold.vertical_alignment = W.VALIGN_CENTER
	head:add_child(self._fold)
	head.pressed:Connect(function()
		c:sfx("click", -8.0)
		self:set_open(not self:is_open())
	end)
	self._head = head
	panel:add_child(head)
	-- the lines, newest first
	local body = T.vbox(0)
	body:set_anchors(0, 0, 1, 0)
	body:set_offsets(12, FrameRules.LOG_HEAD_H, -10, FrameRules.LOG_HEAD_H)
	self._body = body
	panel:add_child(body)
	self._lines = {}
	self._dots = {}
	self._rows = {}
	for i = 1, FrameRules.LOG_LINES do
		-- (each line: a dot in its kind's colour, then the words)
		local row = T.hbox(8)
		row:set_min_size(Vector2.new(0, FrameRules.LOG_LINE_H))
		local dot = FrameKit.round(T.TEXT_2, 4)
		dot:set_min_size(Vector2.new(8, 8))
		dot.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(dot)
		local l = T.label("", 14, 600, T.TEXT)
		l.size_flags_horizontal = W.EXPAND_FILL
		l.vertical_alignment = W.VALIGN_CENTER
		l.clip_text = true
		l.text_overrun_behavior = W.OVERRUN_ELLIPSIS
		row:add_child(l)
		body:add_child(row)
		self._lines[i] = l
		self._dots[i] = dot
		self._rows[i] = row
	end
	self._quiet = T.label("No news yet", 13, 600, T.DIAL_MUTED)
	self._quiet:set_min_size(Vector2.new(0, FrameRules.LOG_LINE_H))
	body:add_child(self._quiet)
	self:_connect(log.changed:Connect(function()
		self._dirty = true
	end))
	c.log_h = self:height()
	return self
end

function LogPanel.is_open(self): boolean
	return self.ctx:setting(LogPanel.OPEN_KEY, true) ~= false
end

function LogPanel.is_hidden(self): boolean
	return self.ctx:setting(LogPanel.HIDDEN_KEY, false) == true
end

--- Its height now: open, folded to its head, or 0 (hidden, or on a phone).
function LogPanel.height(self): number
	-- (a phone, or a screen too narrow for it beside the command bar: the log is in the outliner then)
	if self.ctx.compact or self:is_hidden() or FrameRules.is_medium(self.ctx.vp, self.ctx.insets) then
		return 0
	end
	return FrameRules.log_height(self:is_open())
end

function LogPanel.set_open(self, on: boolean)
	if on == self:is_open() then
		return
	end
	self.ctx:set_setting(LogPanel.OPEN_KEY, on)
	self:_resize()
end

--- The Settings switch: kept hidden (the fold is not shown either).
function LogPanel.set_hidden(self, on: boolean)
	if on == self:is_hidden() then
		return
	end
	self.ctx:set_setting(LogPanel.HIDDEN_KEY, on)
	self:_resize()
end

function LogPanel._resize(self)
	self.ctx.log_h = self:height()
	self:apply_layout()
	self.resized:Fire()
end

function LogPanel.apply_layout(self)
	local ctx = self.ctx
	ctx.log_h = self:height()
	local r = ctx.reserved_top_left
	local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), { log_h = ctx.log_h })
	self._aside = self:_wants_aside(l)
	self.panel:set_visible(ctx.log_h > 0 and not self._aside)
	if ctx.log_h > 0 then
		FrameKit.place(self.panel, l.log)
	end
	self._dirty = true
	self:refresh()
end

--- Whether the selection window reaches down into the log's place (then the log stands beside it).
function LogPanel._wants_aside(self, l: any): boolean
	if self.ctx.compact or self.left_window == nil then
		return false
	end
	local r = self.left_window()
	return r ~= nil and r.Max.Y > l.log.y0 - FrameRules.GAP
end

function LogPanel.refresh(self)
	self._dirty = false
	local open = self:is_open()
	self._fold:set_text(if open then "–" else "+")
	self._body:set_visible(open)
	if not open then
		return
	end
	local recent = self.log:recent(FrameRules.LOG_LINES)
	for i, lbl in self._lines do
		local line = recent[i]
		lbl:set_visible(line ~= nil)
		self._rows[i]:set_visible(line ~= nil)
		if line ~= nil then
			lbl:set_text(line.text)
			-- (the words in plain light text, the kind of news in the dot: whole lines of green and red were hard to read,
			-- playtest 2026-11-08)
			local col = UITheme.msg_color(line.category)
			UITheme.set_font_color(lbl, UITheme.TEXT)
			self._dots[i]:set_color(col)
		end
	end
	self._quiet:set_visible(#recent == 0)
end

--- What of it is on screen (logical px).
function LogPanel.rects(self): { Rect }
	if not (self:is_visible_in_tree() and self.panel.visible) then
		return {}
	end
	return { self.panel:get_global_rect() }
end

function LogPanel.update(self, _delta: number)
	if not self:is_visible_in_tree() then
		return
	end
	if self.left_window ~= nil and (self.ctx.log_h or 0) > 0 then
		local ctx = self.ctx
		local r = ctx.reserved_top_left
		local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), { log_h = ctx.log_h })
		if self:_wants_aside(l) ~= self._aside then
			self:apply_layout()
		end
	end
	if self._dirty then
		self:refresh()
	end
end

return LogPanel
