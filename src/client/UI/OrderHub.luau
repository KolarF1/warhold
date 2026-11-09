--!nonstrict
-- The strategy frame's orders (2026-11-03): on a phone, the five send presets as large buttons under the left thumb (the
-- send and its troops over them) and four labelled buttons under the right (Build, Warheads, Pacts, Your war); on every
-- screen, the placing line while a building or a warhead is in hand ("Placing a City · click your land ·
-- right-click cancels", with Cancel). The phone's buttons are 44 px or more.
--
-- UIRoot and the HUD's modules know it as `bar` (the command bar of old): button(kind) (the open Build window's entry,
-- or nil), build_button() (the Build button on show), preset_rect(r) (the 25% button the tutorial points at),
-- set_placing(kind), set_active(kind), set_tray(false) (closes the Build window), refresh(), refresh_buttons(),
-- top_edge() / base_edge() (the foot of the map's free band), rect(). Members: panel (a phone's thumbs), window,
-- strip, outliner, target_card (set by UIRoot), _flow. Signals: action(key: "build" | "warheads" | "pacts" | "war"),
-- cancel_placement().

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")
local Signal = UITheme.core("Signal")

local OrderHub = W.class(W.Control)

OrderHub.ACTIONS = {
	{ key = "build", label = "Build", icon = "city" },
	{ key = "warheads", label = "Warheads", icon = "atom" },
	{ key = "pacts", label = "Pacts", icon = "alliance" },
	{ key = "war", label = "Your war", icon = "attack" },
}

local function UIRules(): any
	return UICtx.mod("UIRules")
end

--- The placing line's words for `kind`. Pure.
function OrderHub.placing_text(kind: string, title: string, touch: boolean): string
	local nuke = UIRules().is_nuke(kind)
	if touch then
		return string.format("Placing a %s · tap where it goes", title)
	end
	if nuke then
		return string.format("Aiming a %s · click the target · right-click cancels", title)
	end
	return string.format("Placing a %s · click your land · right-click cancels", title)
end

function OrderHub.new(c: any)
	local self = setmetatable({}, OrderHub.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.action = Signal.new()
	self.cancel_placement = Signal.new()
	self.window = nil
	self.strip = nil
	--- The desktop's send panel (UIRoot sets it): its preset is where the send is picked.
	self.send_panel = nil
	--- The desktop's dock of the four windows (UIRoot sets it): the placing line stands above it.
	self.dock = nil
	self.outliner = nil
	self.target_card = nil
	self._flow = -1
	self._placing = ""
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	-- a phone's thumbs
	local panel = W.Control.new()
	panel.name = "Thumbs"
	panel:set_mouse_filter(W.MOUSE_IGNORE)
	panel:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self.panel = panel
	self:add_child(panel)
	local left = W.Control.new()
	left:set_mouse_filter(W.MOUSE_IGNORE)
	panel:add_child(left)
	self._left = left
	-- (the caption stands on a dark pill, as every word on the map does: bare, pale land washed it out)
	local plate = FrameKit.round(T.c(T.DIAL_SLATE, FrameKit.PANEL_A), 6)
	plate:set_anchors(0, 0, 0, 0)
	plate:set_mouse_filter(W.MOUSE_IGNORE)
	left:add_child(plate)
	self._send_plate = plate
	local cap = FrameKit.caption("SEND", T.DIAL_AMBER)
	cap:set_anchors(0, 0, 1, 0)
	cap:set_offsets(8, -1, 0, FrameRules.PRESET_CAPTION_H - 1)
	left:add_child(cap)
	self._send_cap = cap
	local row = T.hbox(FrameRules.PRESET_GAP)
	row:set_anchors(0, 1, 1, 1)
	row:set_offsets(0, -FrameRules.PRESET, 0, 0)
	left:add_child(row)
	self._presets = FrameKit.preset_buttons(c, row, FrameRules.PRESET, 14)
	for _, b in self._presets do
		b:set_min_size(Vector2.new(FrameRules.PRESET, FrameRules.PRESET))
	end
	local right = W.Control.new()
	right:set_mouse_filter(W.MOUSE_IGNORE)
	panel:add_child(right)
	self._right = right
	self._actions = {}
	for i, spec in OrderHub.ACTIONS do
		-- (words alone: a phone's buttons are too narrow for a mark beside them)
		local b = T.button(UICtx.data("PeriodTech").word(spec.label), "DialGhost", "", FrameRules.ACTION_H)
		UICtx.data("PeriodTech").on_apply(function()
			b:set_text(UICtx.data("PeriodTech").word(spec.label))
		end)
		b:set_font_size(13)
		local col = (i - 1) % 2
		local rw = (i - 1) // 2
		local x0 = col * (FrameRules.ACTION_W + FrameRules.ACTION_GAP)
		local y0 = rw * (FrameRules.ACTION_H + FrameRules.ACTION_GAP)
		b:set_anchors(0, 0, 0, 0)
		b:set_offsets(x0, y0, x0 + FrameRules.ACTION_W, y0 + FrameRules.ACTION_H)
		b.pressed:Connect(function()
			self.action:Fire(spec.key)
		end)
		right:add_child(b)
		self._actions[spec.key] = b
	end
	-- the placing line
	local chip = FrameKit.slate(0.94)
	chip.name = "Placing"
	chip:set_mouse_filter(W.MOUSE_STOP)
	local ch = T.hbox(10)
	ch:set_anchors(0, 0, 1, 1)
	ch:set_offsets(12, 4, -6, -4)
	local cl = T.label("", 14, 700, T.TEXT)
	cl.size_flags_vertical = W.SHRINK_CENTER
	cl.size_flags_horizontal = W.EXPAND_FILL
	ch:add_child(cl)
	local cancel = T.button("Cancel", "DialGhost", "close", 40.0)
	cancel:set_font_size(13)
	cancel.size_flags_vertical = W.SHRINK_CENTER
	cancel.pressed:Connect(function()
		self.cancel_placement:Fire()
	end)
	ch:add_child(cancel)
	chip:add_child(ch)
	self._chip = chip
	self._chip_text = cl
	self:add_child(chip)
	chip:set_visible(false)
	self:_connect(c.ratio_changed:Connect(function(_r)
		self:_refresh_send()
	end))
	return self
end

-- ---------------------------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------------------------

function OrderHub.apply_layout(self)
	local ctx = self.ctx
	local r = ctx.reserved_top_left
	local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), { log_h = ctx.log_h })
	self._layout = l
	self.panel:set_visible(ctx.compact)
	if ctx.compact then
		FrameKit.place(self._left, l.presets)
		FrameKit.place(self._right, l.actions)
	end
	self:_place_chip()
	self:refresh()
end

function OrderHub._place_chip(self)
	local ctx = self.ctx
	local l = self._layout
	if l == nil then
		return
	end
	local w = math.min(560, UITheme.measure_text(self._chip_text.text, 14, 700) + 140)
	local y1
	if ctx.compact then
		y1 = math.min(l.presets.y0, l.actions.y0) - FrameRules.EDGE_PHONE
		w = math.min(w, l.actions.x0 - l.presets.x0 - 16)
	else
		-- (above the command bar)
		y1 = ctx.vp.Y - ctx.insets.w - FrameRules.EDGE - (if self.dock ~= nil then FrameRules.DOCK_H + 10 else 0)
		-- (between the left column, or the match log under it, and the war clock)
		local left = if (ctx.log_h or 0) > 0 then math.max(l.select.x1, l.log.x1) else l.select.x1
		w = math.min(w, l.clock.x0 - left - 32)
	end
	local left_x = if not ctx.compact and (ctx.log_h or 0) > 0 then math.max(l.select.x1, l.log.x1) elseif not ctx.compact then l.select.x1 else 0
	local cx = if ctx.compact then (l.presets.x0 + l.actions.x1) * 0.5 else (left_x + l.clock.x0) * 0.5
	FrameKit.place(self._chip, { x0 = math.floor(cx - w * 0.5), y0 = y1 - 48, x1 = math.floor(cx + w * 0.5), y1 = y1 })
end

--- The foot of the map's free band: a phone's thumbs; a larger screen holds no bottom band.
function OrderHub.top_edge(self): number
	local ctx = self.ctx
	local l = self._layout
	if ctx.compact and l ~= nil and l.presets ~= nil then
		return math.min(l.presets.y0, l.actions.y0) - 4
	end
	return ctx.vp.Y - ctx.insets.w
end

function OrderHub.base_edge(self): number
	return self:top_edge()
end

--- What a phone's thumbs cover (logical px), as boxes.
function OrderHub.rects(self): { Rect }
	local out = {}
	if self:is_visible_in_tree() and self.panel.visible then
		table.insert(out, self._left:get_global_rect())
		table.insert(out, self._right:get_global_rect())
	end
	if self._chip.visible then
		table.insert(out, self._chip:get_global_rect())
	end
	return out
end

-- ---------------------------------------------------------------------------------------------
-- What the HUD asks of it
-- ---------------------------------------------------------------------------------------------

--- Where `kind` is picked now (the tutorial and counsel point at it): a desktop's command bar slot, else the open Build
--- window's entry, else nil.
function OrderHub.button(self, kind: string): any
	if not self.ctx.compact and self.dock ~= nil then
		local b = self.dock:button(kind)
		if b ~= nil then
			return b
		end
	end
	return if self.window ~= nil then self.window:entry(kind) else nil
end

--- The Build button on show: a phone's right thumb, else the command bar's City.
function OrderHub.build_button(self): any
	if self.ctx.compact then
		return self._actions.build
	end
	return if self.dock ~= nil then self.dock:button("city") else nil
end

--- A phone's action button `key`.
function OrderHub.action_button(self, key: string): any
	return self._actions[key]
end

--- Where the send `r` is picked now: a phone's preset, the selection window's, or the send panel's.
function OrderHub.preset_rect(self, r: number): Rect?
	local ctx = self.ctx
	local i = FrameRules.preset_index(r)
	if ctx.compact and i ~= nil and self._presets[i]:is_visible_in_tree() then
		return self._presets[i]:get_global_rect()
	end
	local tc = self.target_card
	local tr = if tc ~= nil then tc:preset_rect(r) else nil
	if tr ~= nil then
		return tr
	end
	return if self.send_panel ~= nil then self.send_panel:preset_rect(r) else nil
end

function OrderHub.set_tray(self, on: boolean)
	if not on and self.window ~= nil and self.window.is_open then
		self.window:close()
	end
end

function OrderHub.set_placing(self, kind: string)
	self._placing = kind
	if kind ~= "" then
		self:set_tray(false)
	end
	self:set_active(kind)
	local on = kind ~= ""
	self._chip:set_visible(on)
	if on then
		self._chip_text:set_text(OrderHub.placing_text(kind, UIRules().TITLES[kind] or kind, self.ctx.touch))
		self:_place_chip()
	end
end

function OrderHub.set_active(self, kind: string)
	if self.window ~= nil then
		self.window:set_active(kind)
	end
end

function OrderHub._refresh_send(self)
	local ctx = self.ctx
	FrameKit.light_presets(ctx, self._presets)
	local text = string.format("SEND %s", UITheme.fmt_troops(ctx:troops_for_ratio()))
	self._send_cap:set_text(text)
	local w = UITheme.measure_text(text, 12, 800, 1)
	self._send_plate:set_offsets(0, -3, math.ceil(w) + 16, FrameRules.PRESET_CAPTION_H)
end

function OrderHub.refresh(self, _animate: boolean?)
	self:_refresh_send()
end

--- Coalesced into the Build window (it refreshes its entries when open).
function OrderHub.refresh_buttons(self)
	if self.window ~= nil and self.window.is_open then
		self.window:mark_dirty()
	end
end

function OrderHub.update(_self, _delta: number) end

return OrderHub
