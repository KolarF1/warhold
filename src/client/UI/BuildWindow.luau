--!nonstrict
-- The strategy frame's Build and Warheads windows (2026-11-03; they replaced the command dial's build wheel): a window,
-- not a radial, with what you can raise in framed groups (FrameRules.BUILD_GROUPS: ECONOMY, DEFENCE, STRIKE; the
-- Warheads window: WARHEADS, STRIKES, CALL-UP), each entry its icon, name, price and key. One whose age has not come
-- says the age it opens in; one you can't afford says by how much. Pick one, then click the map to place it
-- (right-click always cancels); opened from your own land's right-click it raises the building right there when it
-- can. While it is open the digits pick its entries (the keys it shows); B toggles Build, N Warheads. It never takes
-- the map's input: the map stays playable around it.
--
-- Opened on one of your own buildings (a right-click on it), it also offers to pull it down: two presses.
-- Signals: picked(kind, tile), closed(), arsenal_wanted(key). Members: is_open, mode ("build" | "warheads"), tile,
-- struct (the building it was opened on). Methods: open(mode, tile?, struct?), close(user?), toggle(mode), entry(kind) (an entry's button: the tutorial points at the
-- City's), pick_digit(d) -> bool, set_active(kind), mark_dirty(), kinds(), apply_layout(), rect(), update(dt).

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")
local Signal = UITheme.core("Signal")

local BuildWindow = W.class(W.Control)

--- Each group's rim colour (its title names it too: never colour alone).
BuildWindow.RIM = {
	economy = UITheme.GOLD,
	defence = Color3.fromRGB(150, 172, 190),
	strike = UITheme.DIAL_RED,
	warheads = UITheme.DIAL_RED,
	strikes = UITheme.DIAL_RED,
	callup = UITheme.DIAL_GREEN,
}
BuildWindow.TITLE = { build = "BUILD", warheads = "WARHEADS" }

local function UIRules(): any
	return UICtx.mod("UIRules")
end

--- Whether `kind` is on offer to the player now (`rules`: UIRules; nil offers everything). Pure but for `rules`.
function BuildWindow.offers(rules: any, kind: string): boolean
	local R = UIRules()
	if rules == nil then
		return true
	end
	-- (a strike its start date never has is not on offer at all: Data/PeriodTech)
	local st = rules.ctx ~= nil and rules.ctx.state or nil
	if st ~= nil and R.is_nuke(kind) and UICtx.data("PeriodTech").closed(st.period, kind) then
		return false
	end
	if table.find(R.ARSENAL, kind) ~= nil and rules:arsenal_locked(kind) then
		return false
	end
	if table.find(R.ARSENAL_NUKES, kind) ~= nil then
		return rules:struct_count(R.launcher(kind)) > 0
	end
	if R.is_call(kind) then
		return rules.ctx ~= nil and rules.ctx.session ~= nil
	end
	-- (the depth buildings: only in a depth match)
	if UICtx.core("Defs").DEPTH_KINDS[kind] then
		return st ~= nil and st.depth ~= nil
	end
	return true
end

--- What an entry says under its name for availability `av`: the price, the age it opens in, what it lacks. Returns the
--- text and its tone ("price" | "short" | "dim"). Pure.
function BuildWindow.detail(av: any, short: boolean?): (string, string)
	if av.opens ~= nil then
		return (if short then "In the " else "Opens in the ") .. tostring(av.opens), "dim"
	end
	local cost = tonumber(av.cost) or 0
	if av.ok then
		return if cost > 0 then UITheme.fmt_cost(cost) else "Ready", "price"
	end
	local reason = tostring(av.reason or "")
	if string.sub(reason, 1, 9) == "Short by " then
		return string.format("%s · %s", UITheme.fmt_cost(cost), string.lower(reason)), "short"
	end
	return if reason ~= "" then reason else "Not yet", "dim"
end

function BuildWindow.new(c: any)
	local self = setmetatable({}, BuildWindow.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.picked = Signal.new()
	self.closed = Signal.new()
	self.arsenal_wanted = Signal.new()
	self.is_open = false
	self.mode = "build"
	self.tile = -1
	self._active = ""
	self._dirty = false
	self._acc = 0.0
	self._entries = {} -- kind -> rec
	self._order = {}
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	local panel = FrameKit.slate(0.97)
	panel.name = "BuildWindow"
	panel:set_mouse_filter(W.MOUSE_STOP)
	self.panel = panel
	self:add_child(panel)
	local v = T.vbox(8)
	v:set_anchors(0, 0, 0, 0)
	v:set_offsets(14, 12, 14, 12)
	self._box = v
	panel:add_child(v)
	local head = T.hbox(10)
	local tv = T.vbox(0)
	tv.size_flags_horizontal = W.EXPAND_FILL
	self._title = T.label("BUILD", 18, T.DIAL_WEIGHT, T.TEXT, 1)
	tv:add_child(self._title)
	self._sub = T.label("", 13, 600, T.DIAL_MUTED)
	tv:add_child(self._sub)
	head:add_child(tv)
	local close = T.button("", "DialGhost", "close", 40.0)
	close:set_min_size(Vector2.new(40, 40))
	close.pressed:Connect(function()
		self:close(true)
	end)
	head:add_child(close)
	v:add_child(head)
	local cols = T.hbox(FrameRules.GAP)
	self._cols = cols
	v:add_child(cols)
	-- (2026-11-09, the owner: right-click a building to remove it) opened on one of your buildings: pull it down. Two
	-- presses, so a slip never costs a City: the first asks, the second (within ASK_S) does it.
	self.struct = nil
	self._ask_until = 0.0
	self._remove = T.button("", "DialGhost", "", 40.0)
	self._remove.name = "RemoveBuilding"
	self._remove:set_font_size(13)
	self._remove:set_min_size(Vector2.new(0, 40))
	self._remove:add_theme_color_override("font_color", T.DIAL_RED)
	self._remove:add_theme_color_override("font_hover_color", T.DIAL_RED)
	self._remove.pressed:Connect(function()
		self:_press_remove()
	end)
	self._remove:set_visible(false)
	v:add_child(self._remove)
	self._groups = {}
	self:set_visible(false)
	return self
end

--- Seconds the remove button waits for its second press.
BuildWindow.ASK_S = 3.0

--- The remove button's words: "PULL DOWN THE CITY", then "SURE? PRESS AGAIN" while it waits. Pure but for UIRules.
function BuildWindow.remove_words(kind_name: string, asking: boolean): string
	if asking then
		return "SURE? PRESS AGAIN TO PULL IT DOWN"
	end
	local title = UIRules().TITLES[kind_name] or kind_name
	return "PULL DOWN THE " .. string.upper(title)
end

function BuildWindow._remove_text(self)
	local st = self.struct
	if st == nil then
		return
	end
	local Defs = UICtx.core("Defs")
	self._remove:set_text(BuildWindow.remove_words(Defs.STRUCT_NAMES[st.kind] or "building", os.clock() < self._ask_until))
end

function BuildWindow._press_remove(self)
	local st = self.struct
	if st == nil or not self.is_open then
		return
	end
	if os.clock() < self._ask_until then
		self._ask_until = 0.0
		self.ctx:send({ type = "demolish", tile = st.tile })
		self.ctx:sfx("close", -4.0)
		self:close(false)
		return
	end
	self._ask_until = os.clock() + BuildWindow.ASK_S
	self.ctx:sfx("click", -6.0)
	self:_remove_text()
end

--- The groups and their entries for the mode now (FrameRules.groups).
function BuildWindow.groups(self): { any }
	local rules = self.ctx.rules
	local spec = if self.mode == "warheads" then FrameRules.WARHEAD_GROUPS else FrameRules.BUILD_GROUPS
	return FrameRules.groups(spec, function(k)
		return BuildWindow.offers(rules, k)
	end)
end

--- Every kind on offer now, in reading order.
function BuildWindow.kinds(self): { string }
	local out = {}
	for _, g in self:groups() do
		for _, e in g.entries do
			table.insert(out, e.kind)
		end
	end
	return out
end

function BuildWindow._group(self, i: number): any
	local T = UITheme
	local g = self._groups[i]
	if g ~= nil then
		return g
	end
	local frame = FrameKit.free(W.Panel.new())
	frame:set_mouse_filter(W.MOUSE_IGNORE)
	local rim = FrameKit.bar(T.WHITE)
	rim:set_anchors(0, 0, 1, 0)
	rim:set_offsets(0, 0, 0, 3)
	-- (the group's colour is its rounded frame's edge now; a square strip would stick out past its corners)
	rim:set_visible(false)
	frame:add_child(rim)
	local gv = T.vbox(4)
	gv:set_anchors(0, 0, 1, 1)
	gv:set_offsets(8, 8, -8, -8)
	frame:add_child(gv)
	local title = FrameKit.caption("")
	gv:add_child(title)
	local list = T.vbox(4)
	gv:add_child(list)
	g = { frame = frame, rim = rim, title = title, list = list, box = gv, recs = {} }
	self._cols:add_child(frame)
	self._groups[i] = g
	return g
end

function BuildWindow._entry(self, g: any, j: number): any
	local T = UITheme
	local rec = g.recs[j]
	if rec ~= nil then
		return rec
	end
	local b = W.Button.new("", "DialGhost")
	local icon = T.icon_rect("city", 30.0, T.TEXT)
	icon:set_anchors(0, 0.5, 0, 0.5)
	icon:set_offsets(8, -15, 38, 15)
	b:add_child(icon)
	local name = T.label("", 14, 800, T.TEXT)
	name:set_anchors(0, 0, 1, 0.5)
	name:set_offsets(46, 3, -26, 0)
	name.vertical_alignment = W.VALIGN_BOTTOM
	name.clip_text = true
	name.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	b:add_child(name)
	local detail = T.label("", 12, 700, T.DIAL_AMBER)
	detail:set_anchors(0, 0.5, 1, 1)
	detail:set_offsets(46, 1, -8, -3)
	detail.vertical_alignment = W.VALIGN_TOP
	detail.clip_text = true
	detail.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	b:add_child(detail)
	local key = T.label("", 13, 800, T.DIAL_MUTED)
	key:set_anchors(1, 0, 1, 0.5)
	key:set_offsets(-24, 3, -8, 0)
	key.horizontal_alignment = W.ALIGN_RIGHT
	key.vertical_alignment = W.VALIGN_BOTTOM
	b:add_child(key)
	rec = { button = b, icon = icon, name = name, detail = detail, key = key, kind = "" }
	b.pressed:Connect(function()
		self:_pick(rec.kind)
	end)
	b.mouse_entered:Connect(function()
		if rec.kind ~= "" then
			self.ctx:show_hint(b, self:_hint(rec.kind))
		end
	end)
	b.mouse_exited:Connect(function()
		self.ctx:hide_hint(b)
	end)
	g.list:add_child(b)
	g.recs[j] = rec
	return rec
end

--- The card over an entry: what it does, and what stops it now.
function BuildWindow._hint(self, kind: string): any
	local R = UIRules()
	local rules = self.ctx.rules
	local av = if rules ~= nil then rules:availability(kind) else { ok = false, reason = "" }
	local spec = { title = R.TITLES[kind] or kind, body = R.blurb(kind), rows = {} }
	if av.cost ~= nil and av.cost > 0 then
		table.insert(spec.rows, { "Price", UITheme.fmt_cost(av.cost), UITheme.GOLD })
	end
	if not av.ok and tostring(av.reason) ~= "" then
		spec.hint = tostring(av.reason)
		spec.hint_color = UITheme.DIAL_RED
		spec.hint_icon = "info"
	end
	return spec
end

function BuildWindow._pick(self, kind: string)
	if kind == "" then
		return
	end
	local rules = self.ctx.rules
	local av = if rules ~= nil then rules:availability(kind) else { ok = true }
	if av.arsenal ~= nil then
		self.arsenal_wanted:Fire(av.arsenal)
		return
	end
	local t = self.tile
	self:close(false)
	self.picked:Fire(kind, t)
end

--- A digit pressed while it is open: its entry (1..9, then 0). True when one was there.
function BuildWindow.pick_digit(self, d: number): boolean
	if not self.is_open then
		return false
	end
	local kinds = self:kinds()
	local k = kinds[FrameRules.digit_index(d)]
	if k == nil then
		return false
	end
	self:_pick(k)
	return true
end

function BuildWindow._fill(self)
	local ctx = self.ctx
	local T = UITheme
	local R = UIRules()
	local rules = ctx.rules
	self._dirty = false
	self._title:set_text(UICtx.data("PeriodTech").word(BuildWindow.TITLE[self.mode] or "BUILD"))
	local verb = if ctx.touch then "tap" else "click"
	self._sub:set_text(
		if self.tile >= 0 and self.mode == "build"
			then string.format("Pick one to raise it here, or %s elsewhere after.", verb)
			elseif ctx.touch then string.format("Pick one, then %s the map. Cancel stops it.", verb)
			else string.format("Pick one, then %s the map. Right-click cancels.", verb)
	)
	local groups = self:groups()
	-- (a phone's window fills the screen's width: tighter gaps and padding)
	local pad = if ctx.compact then 10 else 14
	self._box:set_offsets(pad, if ctx.compact then 8 else 12, pad, 12)
	self._cols:set_separation(if ctx.compact then 6 else FrameRules.GAP)
	self._pad = pad
	local cw = if ctx.compact then FrameRules.BUILD_COL_W_PHONE else FrameRules.BUILD_COL_W
	local rh = if ctx.compact then FrameRules.BUILD_ROW_H_PHONE else FrameRules.BUILD_ROW_H
	table.clear(self._entries)
	table.clear(self._order)
	for i = 1, math.max(#groups, #self._groups) do
		local g = groups[i]
		local gr = if g ~= nil then self:_group(i) else self._groups[i]
		if gr ~= nil then
			gr.frame:set_visible(g ~= nil)
			if g ~= nil then
				local rim = BuildWindow.RIM[g.key] or T.DIAL_MUTED
				gr.rim:set_color(rim)
				gr.frame:add_theme_stylebox_override("panel", T.flat(T.c(T.DIAL_SLATE_2, 0.55), 12, T.c(rim, 0.55), 1, 0, 0))
				gr.title:set_text(UICtx.data("PeriodTech").word(g.title))
				T.set_font_color(gr.title, rim)
				gr.frame:set_min_size(Vector2.new(cw, 0))
				for j = 1, math.max(#g.entries, #gr.recs) do
					local e = g.entries[j]
					local rec = if e ~= nil then self:_entry(gr, j) else gr.recs[j]
					if rec ~= nil then
						rec.button:set_visible(e ~= nil)
						if e ~= nil then
							rec.kind = e.kind
							rec.button:set_min_size(Vector2.new(cw - 16, rh))
							rec.icon:set_icon(e.kind)
							rec.name:set_text(R.TITLES[e.kind] or e.kind)
							rec.key:set_text(if ctx.touch then "" else e.key)
							local av = if rules ~= nil then rules:availability(e.kind) else { ok = true, cost = 0 }
							local text, tone = BuildWindow.detail(av, ctx.compact)
							-- (a phone's column is narrow: a smaller mark, the name past it, no key)
							local ix = if ctx.compact then 6 else 8
							local isz = if ctx.compact then 24 else 30
							rec.icon:set_offsets(ix, -isz * 0.5, ix + isz, isz * 0.5)
							local nx = ix + isz + 6
							rec.name:set_offsets(nx, 3, if ctx.touch then -8 else -26, 0)
							rec.detail:set_offsets(nx, 1, -8, -3)
							rec.detail:set_text(text)
							-- (the one being placed is an amber block: dark ink on it, as on the command bar; playtest 2026-11-08)
							local lit = e.kind == self._active
							T.set_font_color(rec.detail, if lit then T.DIAL_INK elseif tone == "price" then T.DIAL_AMBER elseif tone == "short" then T.DIAL_RED else T.DIAL_MUTED)
							T.set_font_color(rec.name, if lit then T.DIAL_INK elseif tone == "dim" then T.DIAL_MUTED else T.TEXT)
							rec.icon:set_color(if lit then T.DIAL_INK elseif tone == "dim" then T.DIAL_DIM else T.TEXT)
							FrameKit.set_lit(rec.button, lit)
							self._entries[e.kind] = rec
							table.insert(self._order, e.kind)
						end
					end
				end
				-- (the frame places its column by anchors, so it does not grow with it: as tall as what it holds, or a
				-- column of three ran out past its foot on a phone)
				gr.frame:set_min_size(Vector2.new(cw, gr.box:get_combined_minimum_size().Y + 16))
			end
		end
	end
	self:_place()
end

-- ---------------------------------------------------------------------------------------------
-- Open, close, layout
-- ---------------------------------------------------------------------------------------------

function BuildWindow.open(self, mode: string?, tile: number?, struct: any?)
	self.mode = mode or "build"
	self.tile = tile or -1
	self.struct = if self.mode == "build" then struct else nil
	self._ask_until = 0.0
	self._remove:set_visible(self.struct ~= nil)
	self:_remove_text()
	self.is_open = true
	self:set_visible(true)
	self:_fill()
	UICtx.pop_in(self.panel, 0.0, 0.96, 0.12, true)
	self.ctx:sfx("open", -6.0)
end

function BuildWindow.close(self, user: boolean?)
	if not self.is_open then
		return
	end
	self.is_open = false
	self:set_visible(false)
	self.ctx:hide_hint()
	if user then
		self.ctx:sfx("close", -8.0)
	end
	self.closed:Fire()
end

--- The B / N keys and the buttons: opens `mode`, or closes it when it is the one open.
function BuildWindow.toggle(self, mode: string, tile: number?)
	if self.is_open and self.mode == mode and (tile or -1) == self.tile then
		self:close(true)
	else
		self:open(mode, tile)
	end
end

--- The entry's button for `kind` while open (the tutorial and counsel point at it), else nil.
function BuildWindow.entry(self, kind: string): any
	if not self.is_open then
		return nil
	end
	local rec = self._entries[kind]
	return if rec ~= nil then rec.button else nil
end

function BuildWindow.set_active(self, kind: string)
	self._active = kind
	if self.is_open then
		self._dirty = true
	end
end

function BuildWindow.mark_dirty(self)
	self._dirty = true
end

function BuildWindow.apply_layout(self)
	if self.is_open then
		self:_fill()
	end
end

function BuildWindow._place(self)
	local ctx = self.ctx
	local r = ctx.reserved_top_left
	local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), { log_h = ctx.log_h })
	local pad = self._pad or 14
	local sz = self._box:get_combined_minimum_size() + Vector2.new(2 * pad, 24)
	local area = if self.tile >= 0 and not ctx.compact then l.select else l.build
	local x0
	if ctx.compact then
		x0 = area.x0 + math.max(0, (area.x1 - area.x0 - sz.X) * 0.5)
	elseif self.tile >= 0 then
		x0 = area.x0
	else
		x0 = math.max(area.x0, area.x1 - sz.X)
	end
	local y0 = area.y0
	FrameKit.place(self.panel, { x0 = math.floor(x0), y0 = math.floor(y0), x1 = math.floor(x0 + sz.X), y1 = math.floor(y0 + sz.Y) })
end

function BuildWindow.rect(self): Rect?
	return if self.is_open then self.panel:get_global_rect() else nil
end

function BuildWindow.update(self, delta: number)
	if not self.is_open then
		return
	end
	self._acc += delta
	if self.struct ~= nil and self._ask_until > 0 and os.clock() >= self._ask_until then
		-- (the second press never came: it asks again from the start)
		self._ask_until = 0.0
		self:_remove_text()
	end
	if self._dirty or self._acc >= 0.5 then
		self._acc = 0.0
		self:_fill()
	end
end

return BuildWindow
