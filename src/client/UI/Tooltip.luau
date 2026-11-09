--!nonstrict
-- Port of scripts/ui/tooltip.gd (UITooltip)
-- The info card. Three placements: following the cursor (tile hover), anchored beside a control (button hints) or
-- pinned beside the tapped / clicked spot (tap-to-inspect). Since the command dial (2026-11-02; the owner: "the info
-- display in the bottom right is too difficult to see") it is big and high in contrast, on the dial's slate, and never
-- tucked in a corner.
-- One order, whatever the spec: a single top line (name, its standing tag at the right), the one action line, then
-- the facts as a short running line ("Troops 2.4k  Land 3.2%"), never a table.
--
-- Spec table: {title, title_color, swatch (Color3), badge, badge_color, sub, rows: {{k, v, color}},
-- body, hint, hint_color, hint_icon, footer}

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")

local Tooltip = W.class(W.Control)

Tooltip.Place = { FOLLOW = 0, ANCHOR = 1, PINNED = 2 }
local Place = Tooltip.Place
--- Tap-to-inspect cards close on their own after this many seconds.
Tooltip.PIN_SECONDS = 6.0

--- The widest a line of facts runs before the next fact starts a new one (logical px).
Tooltip.FACTS_W = 260.0

--- Which facts share a line: `widths` of each in order, into lines at most `max_w` wide, `gap` apart. Returns for each
--- fact its line (from 1). Pure.
function Tooltip.fact_lines(widths: { number }, max_w: number, gap: number): { number }
	local out = {}
	local line, x = 1, 0.0
	for i, w in widths do
		if x > 0 and x + gap + w > max_w then
			line += 1
			x = 0.0
		end
		x += (if x > 0 then gap else 0.0) + w
		out[i] = line
	end
	return out
end

--- A card of size `sz` wanted at `p`, kept off rect `avoid` inside the box `lo`..`hi`: under it if there is room, else beside
--- it, else over it; failing all of those, where it covers least of it. Pure.
function Tooltip.clear_of(p: Vector2, sz: Vector2, avoid: Rect, lo: Vector2, hi: Vector2, gap: number): Vector2
	local x, y = math.clamp(p.X, lo.X, math.max(lo.X, hi.X - sz.X)), math.clamp(p.Y, lo.Y, math.max(lo.Y, hi.Y - sz.Y))
	local a_min, a_max = avoid.Min, avoid.Max
	if x >= a_max.X or x + sz.X <= a_min.X or y >= a_max.Y or y + sz.Y <= a_min.Y then
		return Vector2.new(x, y)
	end
	if a_max.Y + gap + sz.Y <= hi.Y then
		return Vector2.new(x, a_max.Y + gap)
	end
	if a_max.X + gap + sz.X <= hi.X then
		return Vector2.new(a_max.X + gap, y)
	end
	if a_min.Y - gap - sz.Y >= lo.Y then
		return Vector2.new(x, a_min.Y - gap - sz.Y)
	end
	return Vector2.new(math.max(lo.X, hi.X - sz.X), y)
end

--- Stable key of a spec (GDScript var_to_str(spec)).
local function spec_key(spec: any, p: number): string
	local parts = {}
	local keys = {}
	for k in pairs(spec) do
		table.insert(keys, k)
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = spec[k]
		if k == "rows" then
			for _, r in ipairs(v) do
				table.insert(parts, tostring(r[1]) .. "=" .. tostring(r[2]) .. "/" .. tostring(r[3]))
			end
		else
			table.insert(parts, k .. "=" .. tostring(v))
		end
	end
	return table.concat(parts, "|") .. "#" .. p
end

function Tooltip.new(c: any)
	local self = setmetatable({}, Tooltip.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.place = Place.FOLLOW
	self._anchor = nil
	self._key = ""
	self._shown = false
	self._tween = nil
	self._target = Vector2.zero
	self._close = nil
	self._pin_rect = Rect.new(0, 0, 0, 0)
	self._pin_age = 0.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_TOP_LEFT)
	self._panel = GlassPanel.new(14.0, 10.0, 0, true, 10)
	self._panel:set_mouse_filter(W.MOUSE_IGNORE)
	self._panel:set_tint(UITheme.c(UITheme.DIAL_SLATE, 0.97))
	self._panel:set_accent(UITheme.DIAL_AMBER, 3.0)
	self:add_child(self._panel)
	self._box = UITheme.vbox(4)
	self._panel:add_child(self._box)
	self:set_modulate_a(0.0)
	self:set_visible(false)
	return self
end

function Tooltip.is_shown(self): boolean
	return self._shown
end

function Tooltip.anchor_is(self, c: any): boolean
	return self._anchor == c
end

function Tooltip.show_follow(self, spec: any)
	self:_show(spec, Place.FOLLOW, nil)
end

function Tooltip.show_anchor(self, spec: any, anchor: any)
	self:_show(spec, Place.ANCHOR, anchor)
end

function Tooltip.show_pinned(self, spec: any, rect: Rect)
	self._pin_rect = rect
	self._pin_point = nil
	self._pin_age = 0.0
	self:_show(spec, Place.PINNED, nil)
end

--- Pinned beside `point` (logical px): the tapped or clicked spot, which the card never covers.
function Tooltip.show_pinned_at(self, spec: any, point: Vector2)
	self._pin_point = point
	self._pin_age = 0.0
	self:_show(spec, Place.PINNED, nil)
end

function Tooltip.hide_tip(self)
	if not self._shown then
		return
	end
	self._shown = false
	self._key = ""
	if self._tween then
		self._tween:kill()
	end
	self._tween = self:create_tween()
	self._tween:tween_property(self, "modulate:a", 0.0, 0.1)
	self._tween:tween_callback(function()
		if not self._shown then
			self:set_visible(false)
			self:set_process(false)
		end
	end)
end

--- The card's current rect (logical px) — UIInteract.show_inspect keeps it off the tapped spot.
function Tooltip.target_rect(self): Rect
	local sz = self._panel:get_combined_minimum_size()
	return UICtx.rect_ps(self._target, sz)
end

function Tooltip._show(self, spec: any, p: number, anchor: any)
	if self:has_meta("stats") then
		self:remove_meta("stats") -- UIRoot tags its strip-details card after showing it
	end
	local key = spec_key(spec, p)
	local was = self._shown
	self.place = p
	self._anchor = anchor
	self._panel:set_mouse_filter(if p == Place.PINNED then W.MOUSE_STOP else W.MOUSE_IGNORE)
	if key ~= self._key then
		self._key = key
		self:_build(spec)
	end
	self._shown = true
	self:set_visible(true)
	self:set_process(true)
	self._panel:reset_size()
	self._target = self:_compute_target()
	if not was then
		self:_set_pos(self._target)
		if self._tween then
			self._tween:kill()
		end
		self._tween = self:create_tween()
		self._tween:tween_property(self, "modulate:a", 1.0, 0.12)
	elseif self.modulate_a < 1.0 and (self._tween == nil or not self._tween:is_running()) then
		self:set_modulate_a(1.0)
	end
end

function Tooltip._set_pos(self, p: Vector2)
	UICtx.move_node(self, p)
end

function Tooltip._build(self, spec: any)
	for _, ch in ipairs(self._box:get_children()) do
		ch:queue_free()
	end
	local ctx = self.ctx
	local compact = ctx.compact
	local head = UITheme.hbox(8)
	if spec.swatch ~= nil then
		head:add_child(UITheme.swatch(spec.swatch, 11.0, 3))
	end
	local tc = spec.title_color or UITheme.TEXT
	local title = UITheme.label(tostring(spec.title or ""), if compact then 16 else 18, UITheme.DIAL_WEIGHT, tc)
	title.size_flags_horizontal = W.EXPAND_FILL
	head:add_child(title)
	if spec.badge ~= nil and tostring(spec.badge) ~= "" then
		head:add_child(self:_badge(tostring(spec.badge), spec.badge_color or UITheme.TEXT_2))
	end
	self._close = nil
	if self.place == Place.PINNED then
		local b = UITheme.button("", "GhostButton", "close", 44.0)
		b.expand_icon = true
		b:add_theme_constant_override("icon_max_width", 16)
		b:set_min_size(Vector2.new(44, 44))
		b.icon_alignment = W.ALIGN_CENTER
		b:add_theme_color_override("icon_normal_color", UITheme.TEXT)
		b:add_theme_stylebox_override("normal", UITheme.flat(UITheme.FILL, UITheme.R_MD, UITheme.LINE, 1, 12.0, 12.0))
		b.pressed:Connect(function()
			self:hide_tip()
			self.closed:Fire()
		end)
		self._close = b
		head:add_child(b)
	end
	self._box:add_child(head)
	-- the one action line, right under the name
	if spec.hint ~= nil and tostring(spec.hint) ~= "" then
		local hc = spec.hint_color or UITheme.AMBER
		local hint = UITheme.hbox(6)
		if spec.hint_icon ~= nil then
			local ic = UITheme.icon_rect(tostring(spec.hint_icon), 14.0, hc)
			ic.size_flags_vertical = W.SHRINK_CENTER
			hint:add_child(ic)
		end
		local hl = UITheme.label(tostring(spec.hint), 14, 700, hc)
		hl:set_autowrap(true)
		hl.size_flags_horizontal = W.EXPAND_FILL
		hl:set_min_size(Vector2.new(220, 0))
		hint:add_child(hl)
		self._box:add_child(hint)
	end
	self:_add_facts(spec.rows or {})
	if spec.sub ~= nil and tostring(spec.sub) ~= "" then
		self._box:add_child(UITheme.label(tostring(spec.sub), 13, 600, UITheme.DIAL_MUTED))
	end
	if spec.body ~= nil and tostring(spec.body) ~= "" then
		local body = UITheme.label(tostring(spec.body), 13, 500, UITheme.DIAL_MUTED)
		body:set_autowrap(true)
		body:set_min_size(Vector2.new(250, 0))
		self._box:add_child(body)
	end
	if spec.footer ~= nil and tostring(spec.footer) ~= "" then
		self._box:add_child(UITheme.label(tostring(spec.footer), 12, 600, UITheme.DIAL_DIM))
	end
	self._panel:set_min_size(Vector2.new(260, 0))
end

--- The facts: each "key value", running on in short lines.
function Tooltip._add_facts(self, rows: any)
	if #rows == 0 then
		return
	end
	local T = UITheme
	local widths = {}
	for i, r in ipairs(rows) do
		widths[i] = T.text_width(tostring(r[1]), 13, 600) + 4.0 + T.text_width(tostring(r[2]), 13, 800)
	end
	local lines = Tooltip.fact_lines(widths, Tooltip.FACTS_W, 12.0)
	local at, row = 0, nil
	for i, r in ipairs(rows) do
		if lines[i] ~= at then
			at = lines[i]
			row = T.hbox(12)
			self._box:add_child(row)
		end
		local fact = T.hbox(4)
		fact:add_child(T.label(tostring(r[1]), 13, 600, T.DIAL_CAPTION))
		fact:add_child(T.label(tostring(r[2]), 13, 800, r[3] or T.TEXT))
		row:add_child(fact)
	end
end

--- The standing tag: flat, at the right end of the top line.
function Tooltip._badge(self, text: string, c: any)
	local p = W.Panel.new()
	p:set_mouse_filter(W.MOUSE_IGNORE)
	p:add_theme_stylebox_override("panel", UITheme.flat(UITheme.c(c, 0.16), UITheme.R_SM, UITheme.CLEAR, 0, 6.0, 1.0))
	p:add_child(UITheme.label(text, 12, 700, c))
	p.size_flags_vertical = W.SHRINK_CENTER
	return p
end

function Tooltip._compute_target(self): Vector2
	local ctx = self.ctx
	local vp = ctx.vp
	local sz = self._panel:get_combined_minimum_size()
	local ins = ctx.insets
	local margin = 8.0
	local p = Vector2.zero
	if self.place == Place.FOLLOW then
		local m = ctx:mouse_pos()
		p = m + Vector2.new(16, 14)
		local x, y = p.X, p.Y
		if x + sz.X > vp.X - margin - ins.z then
			x = m.X - 16 - sz.X
		end
		if y + sz.Y > vp.Y - margin - ins.w then
			y = m.Y - 14 - sz.Y
		end
		p = Vector2.new(x, y)
	elseif self.place == Place.ANCHOR then
		local a = self._anchor
		if a ~= nil and not a._freed then
			local r = a:get_global_rect()
			local x = r.Min.X + r.Width * 0.5 - sz.X * 0.5
			local y = r.Min.Y - sz.Y - 10.0
			if y < margin then
				y = r.Max.Y + 10.0
			end
			-- (a slot in the left rail: beside it)
			if a.rail then
				x, y = r.Max.X + 10.0, r.Min.Y
			end
			p = Vector2.new(x, y)
		end
	elseif self._pin_point ~= nil then
		-- beside the spot, on its right (its left at the right edge), level with it
		local q = self._pin_point
		local x = q.X + 40
		if x + sz.X > vp.X - margin - ins.z then
			x = q.X - 40 - sz.X
		end
		p = Vector2.new(x, q.Y - sz.Y * 0.5)
	else
		local pr = self._pin_rect
		p = Vector2.new(pr.Min.X + pr.Width - sz.X, pr.Min.Y + pr.Height - sz.Y)
	end
	local out = Vector2.new(
		math.clamp(p.X, margin + ins.x, math.max(margin, vp.X - sz.X - margin - ins.z)),
		math.clamp(p.Y, margin + ins.y, math.max(margin, vp.Y - sz.Y - margin - ins.w))
	)
	-- a phone has little room: a card and Counsel at the same edge overlapped (2026-11-02)
	local coach = ctx.coach
	if ctx.compact and coach ~= nil and coach.card_rect ~= nil then
		local avoid = coach:card_rect()
		if avoid ~= nil then
			out = Tooltip.clear_of(out, sz, avoid, Vector2.new(margin + ins.x, margin + ins.y), Vector2.new(vp.X - margin - ins.z, vp.Y - margin - ins.w), 6.0)
		end
	end
	return out
end

function Tooltip._process(self, delta: number)
	if not self._shown then
		return
	end
	if self.place == Place.ANCHOR then
		local a = self._anchor
		if a == nil or a._freed or not a:is_visible_in_tree() then
			self:hide_tip()
			return
		end
	end
	if self.place == Place.PINNED then
		self._pin_age += delta
		if self._pin_age > Tooltip.PIN_SECONDS then
			self:hide_tip()
			return
		end
	end
	self._target = self:_compute_target()
	local cur = Vector2.new(self.offset_left, self.offset_top)
	if (cur - self._target).Magnitude < 0.25 then
		if cur ~= self._target then
			self:_set_pos(self._target)
		end
		return
	end
	if self.place == Place.FOLLOW then
		self:_set_pos(cur:Lerp(self._target, 1.0 - math.exp(-delta * 22.0)))
	else
		self:_set_pos(self._target)
	end
end

return Tooltip
