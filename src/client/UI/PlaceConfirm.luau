--!nonstrict
-- Touch placement: a plate beside the ghost on the map, never over it, that names what stands there and its price, with
-- one square button for the order and one to go back. A warhead's button is held, not tapped: it fills as you hold. The
-- plate follows the ghost's screen position every frame; UIInteract moves the ghost (tap elsewhere, map drag).

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")

local PlaceConfirm = W.class(W.Control)

--- Keep this far (px) from the ghost's centre so the target stays visible and tappable.
PlaceConfirm.CLEAR = 34.0
--- A finger's target.
PlaceConfirm.BTN_H = 44.0
PlaceConfirm.CAPTION_MAX = 180.0
--- Seconds a warhead's button is held before it fires.
PlaceConfirm.HOLD_S = 0.6

function PlaceConfirm.new(c: any)
	local self = setmetatable({}, PlaceConfirm.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.confirmed = Signal.new()
	self.cancelled = Signal.new()
	self.tile = -1
	self.is_open = false
	--- function() -> {Rect}: HUD panels the plate must stay clear of.
	self.blockers = nil
	self._side = -1
	self._hold_on = false
	self._held = -1.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._panel = GlassPanel.new(10.0, 4.0, T.R_SM, true, 16)
	self:add_child(self._panel)
	local h = T.hbox(8)
	self._panel:add_child(h)
	self._caption = T.label("", 13, 700, T.TEXT)
	self._caption.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._caption.clip_text = true
	self._caption.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(self._caption)
	self._ok = T.button("Build", "PrimaryButton", "", PlaceConfirm.BTN_H)
	self._ok.name = "PlaceConfirm"
	self._ok.gui.Name = "PlaceConfirm"
	self._ok:set_font_size(13)
	self._ok:set_min_size(Vector2.new(84, PlaceConfirm.BTN_H))
	self._ok.pressed:Connect(function()
		if not self._hold_on then
			self.confirmed:Fire()
		end
	end)
	self._ok.button_down:Connect(function()
		if self._hold_on then
			self._held = 0.0
		end
	end)
	self._ok.button_up:Connect(function()
		self:_set_held(-1.0)
	end)
	-- (what a hold has filled so far)
	self._fill = W.ColorRect.new(T.c(T.WHITE, 0.3))
	self._fill:set_mouse_filter(W.MOUSE_IGNORE)
	self._fill:set_visible(false)
	self._ok:add_child(self._fill)
	h:add_child(self._ok)
	self._no = T.button("Back", "GlassButton", "", PlaceConfirm.BTN_H)
	self._no.name = "PlaceCancel"
	self._no.gui.Name = "PlaceCancel"
	self._no:set_font_size(13)
	self._no:set_min_size(Vector2.new(56, PlaceConfirm.BTN_H))
	self._no.pressed:Connect(function()
		self.cancelled:Fire()
	end)
	h:add_child(self._no)
	self:set_visible(false)
	self:set_process(true)
	return self
end

--- Show the plate for the ghost at `t`. `danger`: a warhead (its button is held). `verb`: what the button says.
function PlaceConfirm.show_for(self, t: number, caption: string, danger: boolean, ok: boolean?, verb: string?)
	local okv = if ok == nil then true else ok
	self.tile = t
	self._caption:set_text(caption)
	self._caption:set_min_size(Vector2.new(math.min(UITheme.text_width(caption, 13, 700) + 4.0, PlaceConfirm.CAPTION_MAX), 0))
	self._ok:set_disabled(not okv)
	self._ok:set_text(verb or "Build")
	self._hold_on = danger
	self:_set_held(-1.0)
	local variation = if danger then "DangerButton" else "PrimaryButton"
	if self._ok.theme_type_variation ~= variation then
		self._ok.theme_type_variation = variation
		self._ok:_theme_changed()
		self._ok:_restyle_label()
	end
	local was = self.is_open
	self.is_open = true
	self:set_visible(true)
	self._panel:reset_size()
	self._side = -1
	self:_follow(true)
	if not was then
		UICtx.pop_in(self._panel, 0.0, 1.0, 0.14, true)
	end
end

function PlaceConfirm.hide_confirm(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	self.tile = -1
	self:_set_held(-1.0)
	self:set_visible(false)
end

function PlaceConfirm.panel_rect(self): Rect
	return if self.is_open then self._panel:get_global_rect() else UICtx.EMPTY_RECT
end

function PlaceConfirm.button_rects(self): { Rect }
	return if self.is_open then { self._ok:get_global_rect(), self._no:get_global_rect() } else {}
end

--- `v`: seconds held, or -1 when nobody holds it.
function PlaceConfirm._set_held(self, v: number)
	self._held = v
	self._fill:set_visible(v >= 0.0)
	if v >= 0.0 then
		self._fill:set_anchors(0, 0, math.clamp(v / PlaceConfirm.HOLD_S, 0.0, 1.0), 1)
		self._fill:set_offsets(0, 0, 0, 0)
	end
end

function PlaceConfirm._process(self, delta: number)
	if not self.is_open then
		return
	end
	self:_follow(false)
	if self._hold_on and self._held >= 0.0 then
		local v = self._held + delta
		if v >= PlaceConfirm.HOLD_S then
			self:_set_held(-1.0)
			self.confirmed:Fire()
		else
			self:_set_held(v)
		end
	end
end

--- Beside the ghost: above, below, right or left, the first spot inside the free screen area that keeps CLEAR px from
--- the ghost and off the HUD; the chosen side sticks while it still fits.
function PlaceConfirm._follow(self, force: boolean)
	local ctx = self.ctx
	local CLEAR = PlaceConfirm.CLEAR
	local p = ctx:tile_screen_pos(self.tile)
	if p.X < 0.0 then
		self._panel:set_visible(false) -- off the screen: nothing to confirm against right now
		return
	end
	self._panel:set_visible(true)
	local sz = self._panel:get_combined_minimum_size()
	local area = ctx:clear_rect()
	local bar = self:get_meta("bar", nil)
	if bar ~= nil and bar:is_visible_in_tree() then
		area = Rect.new(area.Min.X, area.Min.Y, area.Max.X, math.min(area.Max.Y, bar:top_edge() - 6.0))
	end
	local cands = {
		Vector2.new(p.X - sz.X * 0.5, p.Y - CLEAR - sz.Y), -- above
		Vector2.new(p.X - sz.X * 0.5, p.Y + CLEAR), -- below
		Vector2.new(p.X + CLEAR, p.Y - sz.Y * 0.5), -- right
		Vector2.new(p.X - CLEAR - sz.X, p.Y - sz.Y * 0.5), -- left
	}
	local blocked = if self.blockers then self.blockers() else {}
	local order = { 0, 1, 2, 3 }
	if not force and self._side >= 0 then
		table.remove(order, table.find(order, self._side) :: number)
		table.insert(order, 1, self._side)
	end
	local best = -1
	local best_pos = Vector2.zero
	for _, i in ipairs(order) do
		local q = cands[i + 1]
		local r = UICtx.rect_ps(q, sz)
		if not UICtx.rect_encloses(area, r) then
			continue
		end
		local hit = false
		for _, b in ipairs(blocked) do
			if UICtx.rect_intersects(r, b) then
				hit = true
				break
			end
		end
		if hit then
			continue
		end
		best = i
		best_pos = q
		break
	end
	if best < 0 then
		-- Nothing fits cleanly: clamp the first spot into the area, then push it off the ghost.
		local q2 = cands[1]
		local x = math.clamp(q2.X, area.Min.X, math.max(area.Min.X, area.Max.X - sz.X))
		local y = math.clamp(q2.Y, area.Min.Y, math.max(area.Min.Y, area.Max.Y - sz.Y))
		if UICtx.rect_has_point(UICtx.rect_grow(UICtx.rect_ps(Vector2.new(x, y), sz), CLEAR * 0.5), p) then
			y = if p.Y - CLEAR - sz.Y >= area.Min.Y then p.Y - CLEAR - sz.Y else p.Y + CLEAR
		end
		best_pos = Vector2.new(x, y)
	end
	self._side = best
	UICtx.move_node(self._panel, Vector2.new(math.floor(best_pos.X + 0.5), math.floor(best_pos.Y + 0.5)))
end

return PlaceConfirm
