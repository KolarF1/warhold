--!nonstrict
-- The command bar along the bottom (2026-11-06, the owner: buildings and warheads are not kept inside sub-menus;
-- 2026-11-07: "one big line with the names of each item"): one dark card, one row of slots in three groups: every
-- building (FrameRules.BUILD_GROUPS in reading order), then every warhead, strike and call-up on offer to you now
-- (FrameRules.WARHEAD_GROUPS, BuildWindow.offers), then Doctrine and Pacts. A slot is the thing's icon, its name and its
-- price (a narrow screen drops the name: FrameRules.layout's dock_names); one whose age has not come says the age, one
-- you can't afford shows its price in red, the one in your hand is lit. A press takes it in hand to place on the map
-- (right-click cancels), as the Build window's entries do; hovering says what it does. Doctrine is lit with a PICK badge
-- while a doctrine waits, Pacts gets a red dot while a pact is offered to you. A phone keeps its Build and Warheads
-- buttons (OrderHub) and the windows they open.
--
-- UIRoot knows it as `dock`. Signals: picked(kind, tile), arsenal_wanted(key), button_pressed(key: "doctrine" |
-- "pacts"). Members: panel, aim_kind (() -> string?: what is in hand now; UIRoot sets it). Methods: apply_layout(),
-- refresh(), button(key) (a slot by its kind, or Doctrine / Pacts), rects(), update(dt).

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")
local Signal = UITheme.core("Signal")

local ActionDock = W.class(W.Control)

--- Doctrine and Pacts, at the right end of the bar: key, name, icon, colour.
ActionDock.TILES = {
	{ key = "doctrine", label = "Doctrine", icon = "crown", colour = "DIAL_AMBER" },
	{ key = "pacts", label = "Pacts", icon = "alliance", colour = "CHIP_BLUE" },
}

--- What waits at Doctrine and Pacts: { doctrine = bool, offers = n }. Pure but for `ctx`.
function ActionDock.waiting(ctx: any): { [string]: any }
	local s = ctx.state
	local me = ctx:me()
	local out = { doctrine = false, offers = 0 }
	if s == nil or me == 0 then
		return out
	end
	local ok, row = pcall(function()
		return UICtx.mod("DoctrineDraft").open_row(s, me)
	end)
	out.doctrine = ok and row ~= nil and not ctx.draft_held
	for key in s.requests or {} do
		if key % 1024 == me and key // 1024 ~= me then
			out.offers += 1
		end
	end
	return out
end

--- Every building kind, in the bar's order. Pure.
function ActionDock.building_kinds(): { string }
	local out = {}
	for _, g in FrameRules.BUILD_GROUPS do
		for _, k in g.kinds do
			-- (a depth match's Farm, Market, Barracks and Fort live in the Build window, B: four more slots made the
			-- bar too narrow to press on a tablet)
			if not UICtx.core("Defs").DEPTH_KINDS[k] then
				table.insert(out, k)
			end
		end
	end
	return out
end

--- The warheads, strikes and call-ups on offer (`has(kind)`), in the bar's order, at most `max`. Pure.
function ActionDock.strike_kinds(has: (string) -> boolean, max: number): { string }
	local out = {}
	for _, g in FrameRules.WARHEAD_GROUPS do
		for _, k in g.kinds do
			if #out < max and has(k) then
				table.insert(out, k)
			end
		end
	end
	return out
end

--- A slot's words under its icon for availability `av`, and their tone ("price" | "short" | "dim"). Pure.
function ActionDock.slot_text(av: any): (string, string)
	-- (a start date without it: "—", dimmed; Data/PeriodTech)
	if av.locked and string.sub(tostring(av.reason or ""), 1, 7) == "Not in " then
		return "—", "dim"
	end
	if av.opens ~= nil then
		local Eras = UICtx.data("Eras")
		local i = table.find(Eras.NAMES, av.opens)
		return if i ~= nil then string.format("AGE %d", i) else "LATER", "dim"
	end
	local cost = tonumber(av.cost) or 0
	local text = if cost > 0 then UITheme.fmt_num(cost) else "READY"
	if av.ok then
		return text, "price"
	end
	if string.sub(tostring(av.reason or ""), 1, 9) == "Short by " then
		return text, "short"
	end
	return text, "dim"
end

--- The slots the bar holds with `strikes` strikes on offer. Pure.
function ActionDock.count(strikes: number): number
	return #ActionDock.building_kinds() + strikes + #ActionDock.TILES
end

--- Every strike kind the bar can ever show, in its order. Pure.
function ActionDock.all_strikes(): { string }
	return ActionDock.strike_kinds(function()
		return true
	end, math.huge)
end

--- A building's or a strike's name on its slot.
function ActionDock.title(kind: string): string
	return UICtx.mod("UIRules").TITLES[kind] or kind
end

function ActionDock.new(c: any)
	local self = setmetatable({}, ActionDock.__mt)
	W.Control._init(self)
	self.ctx = c
	self.picked = Signal.new()
	self.arsenal_wanted = Signal.new()
	self.button_pressed = Signal.new()
	self._acc = 0.0
	self._slots = {} -- kind -> rec
	self._strikes = {} -- the strike slots, by position
	self._shown = 0 -- strikes on show
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	local panel = FrameKit.slate()
	panel.name = "CommandBar"
	panel:set_mouse_filter(W.MOUSE_STOP)
	self.panel = panel
	self:add_child(panel)
	-- the buildings
	self._buildings = {}
	for _, kind in ActionDock.building_kinds() do
		local rec = self:_slot()
		rec.kind = kind
		rec.icon:set_icon(kind)
		rec.name:set_text(ActionDock.title(kind))
		self._slots[kind] = rec
		table.insert(self._buildings, rec)
	end
	-- the strikes (filled as they come on offer)
	for i = 1, #ActionDock.all_strikes() do
		self._strikes[i] = self:_slot()
		self._strikes[i].button:set_visible(false)
	end
	-- the hairlines between its groups and its rows (placed by _place_slots)
	self._lines = {}
	for i = 1, 4 do
		local line = FrameKit.bar(UITheme.c(UITheme.WHITE, 0.1))
		line:set_anchors(0, 0, 0, 0)
		line:set_mouse_filter(W.MOUSE_IGNORE)
		panel:add_child(line)
		self._lines[i] = line
	end
	-- Doctrine and Pacts, at the right end
	self._tiles = {}
	self._tile_list = {}
	for _, spec in ActionDock.TILES do
		local rec = self:_tile(spec)
		self._tiles[spec.key] = rec
		table.insert(self._tile_list, rec)
	end
	return self
end

--- The name under a slot's icon: up to two lines, centred.
local function name_label(text: string): any
	local name = UITheme.label(text, 12, 800, UITheme.TEXT)
	name:set_autowrap(true)
	name.horizontal_alignment = W.ALIGN_CENTER
	name.vertical_alignment = W.VALIGN_TOP
	name:set_anchors(0, 0, 1, 0)
	return name
end

--- The colour of a kind's tile, as the top strip's chips are coloured: the economy gold, defence blue, the strike
--- buildings and the strikes red, the warheads violet (the WARHEADS chip's), the call-ups green.
function ActionDock.colour(kind: string): any
	local T = UITheme
	if kind == "city" or kind == "port" or kind == "factory" then
		return T.CHIP_GOLD
	elseif kind == "defense" or kind == "sam" or kind == "artillery" then
		return T.CHIP_BLUE
	elseif kind == "atom" or kind == "hydrogen" or kind == "mirv" or kind == "mega" or kind == "scatter" then
		return T.CHIP_VIOLET
	elseif kind == "reinforce" or kind == "callarms" then
		return T.CHIP_GREEN
	end
	return T.CHIP_RED
end

--- A slot's look: bare on the card (the strip's cells have no boxes), lit only on hover or while in hand.
local function bare_button(): any
	local b = W.Button.new("", "DialSeg")
	b._seg = true
	b:set_anchors(0, 0, 0, 0)
	return b
end

--- A building or strike slot (placed by _place_slots): its coloured tile, its name, its price.
function ActionDock._slot(self): any
	local T = UITheme
	local b = bare_button()
	local tile = FrameKit.tile("city", T.CHIP_GOLD, FrameRules.DOCK_TILE)
	tile:set_anchors(0.5, 0, 0.5, 0)
	b:add_child(tile)
	local icon = tile.icon
	local name = name_label("")
	b:add_child(name)
	local cost = T.label("", 12, 800, T.DIAL_AMBER)
	cost:set_anchors(0, 1, 1, 1)
	cost:set_offsets(1, -16, -1, 0)
	cost.horizontal_alignment = W.ALIGN_CENTER
	cost.clip_text = true
	b:add_child(cost)
	local rec = { button = b, tile = tile, icon = icon, name = name, cost = cost, kind = "" }
	b.pressed:Connect(function()
		self:_pick(rec.kind)
	end)
	b.mouse_entered:Connect(function()
		if rec.kind ~= "" then
			self.ctx:show_hint(b, UICtx.mod("BuildWindow")._hint(self, rec.kind))
		end
	end)
	b.mouse_exited:Connect(function()
		self.ctx:hide_hint(b)
	end)
	self.panel:add_child(b)
	return rec
end

--- Doctrine's or Pacts' slot: its coloured tile, its name, the PICK badge and the red dot.
function ActionDock._tile(self, spec: any): any
	local T = UITheme
	local b = bare_button()
	local tile = FrameKit.tile(spec.icon, T[spec.colour], FrameRules.DOCK_TILE)
	tile:set_anchors(0.5, 0, 0.5, 0)
	b:add_child(tile)
	local name = name_label(spec.label)
	b:add_child(name)
	local badge = FrameKit.round(T.DIAL_AMBER, 8)
	badge:set_anchors(1, 0, 1, 0)
	badge:set_offsets(-40, -8, 4, 8)
	local bl = T.label("PICK", 12, 800, T.DIAL_INK)
	bl:set_anchors(0, 0, 1, 1)
	bl.horizontal_alignment = W.ALIGN_CENTER
	bl.vertical_alignment = W.VALIGN_CENTER
	badge:add_child(bl)
	badge:set_visible(false)
	b:add_child(badge)
	local dot = FrameKit.round(FrameKit.DANGER, 7)
	dot:set_anchors(1, 0, 1, 0)
	dot:set_offsets(-10, -4, 4, 10)
	dot:set_visible(false)
	b:add_child(dot)
	b.pressed:Connect(function()
		self.button_pressed:Fire(spec.key)
	end)
	self.panel:add_child(b)
	return { button = b, tile = tile, name = name, badge = badge, dot = dot, spec = spec }
end

--- A slot pressed: an Arsenal item not yet earned opens the War College; else it is taken in hand to place.
function ActionDock._pick(self, kind: string)
	if kind == "" then
		return
	end
	local rules = self.ctx.rules
	local av = if rules ~= nil then rules:availability(kind) else { ok = true }
	if av.arsenal ~= nil then
		self.arsenal_wanted:Fire(av.arsenal)
		return
	end
	self.picked:Fire(kind, -1)
end

--- FrameRules.layout for `ctx` with `n` slots on the bar (nil: the default count).
local function layout_of(ctx: any, n: number?): any
	local r = ctx.reserved_top_left
	return FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), {
		log_h = ctx.log_h,
		dock_n = n,
	})
end

--- The layout this bar stands in now (its slot count included).
function ActionDock.layout(self): any
	return layout_of(self.ctx, ActionDock.count(self._shown))
end

function ActionDock.apply_layout(self)
	local ctx = self.ctx
	self.panel:set_visible(not ctx.compact)
	self:_fill()
	if not ctx.compact then
		self:_place()
	end
	self:_paint_all()
end

--- Places the card and lays its slots out for the strikes on show.
function ActionDock._place(self)
	local l = self:layout()
	FrameKit.place(self.panel, l.dock)
	self:_place_slots(l.dock_slot_w or FrameRules.DOCK_SLOT_W, l.dock_names ~= false, l.dock_tight == true)
end

--- Lays the slots out in two rows, `slot_w` wide: the buildings on top in their three groups (a wider gap between), the
--- strikes below from the left with Doctrine and Pacts at the right end; `names`: room for the names; `tight`: the
--- cramped gaps (FrameRules.dock_slot_for).
function ActionDock._place_slots(self, slot_w: number, names: boolean, tight: boolean?)
	local gap = if tight then FrameRules.DOCK_GAP_TIGHT else FrameRules.DOCK_GAP
	local group = if tight then FrameRules.DOCK_GROUP_GAP_TIGHT else FrameRules.DOCK_GROUP_GAP
	self._slot_w = slot_w
	self._names = names
	local p = FrameRules.DOCK_PAD
	local h = if names then FrameRules.DOCK_SLOT_H else FrameRules.DOCK_SLOT_H_BARE
	local cols = FrameRules.dock_cols(ActionDock.count(self._shown))
	local inner_right = p + FrameRules.dock_width(cols, slot_w, tight) - 2 * p
	local function at(rec: any, tile: boolean, x: number, y: number)
		rec.button:set_offsets(x, y, x + slot_w, y + h)
		local isz = FrameRules.DOCK_TILE
		local lh = UITheme.line_height(12)
		-- the tile, the name (one line or two, as it wraps) and the price, as one block centred in the slot
		-- (a name within a few px of the slot's width is given two lines: the measure and the drawn text can differ by a
		-- px or two, and a name that wrapped into one line's room ran over its price; "Lance Cannon", playtest 2026-11-08)
		local lines = if names or tile
			then (if UITheme.measure_text(rec.name.text, 12, 800) > (slot_w - 2) * 0.92 then 2 else 1)
			else 0
		local below = if tile then 0 else lh
		local block = isz + 1 + lines * lh + below
		local iy = math.max(FrameRules.DOCK_TILE_Y, math.floor((h - block) * 0.5))
		rec.tile:set_offsets(-isz / 2, iy, isz / 2, iy + isz)
		local ny = iy + isz + 1
		rec.name:set_visible(lines > 0)
		rec.name:set_offsets(1, ny, -1, ny + lines * lh)
		if rec.cost ~= nil then
			local cy = ny + lines * lh
			rec.cost:set_anchors(0, 0, 1, 0)
			rec.cost:set_offsets(1, cy, -1, cy + lh)
		end
	end
	-- the buildings, a wider gap between their groups (FrameRules.BUILD_GROUPS)
	local x = p
	local i = 0
	for gi, g in FrameRules.BUILD_GROUPS do
		if gi > 1 then
			x += group - gap
		end
		for _, k in g.kinds do
			if UICtx.core("Defs").DEPTH_KINDS[k] then
				continue
			end
			i += 1
			at(self._buildings[i], false, x, p)
			x += slot_w + gap
		end
	end
	-- the strikes from the left, Doctrine and Pacts at the right end
	local y = p + h + gap
	x = p
	for k = 1, self._shown do
		at(self._strikes[k], false, x, y)
		x += slot_w + gap
	end
	x = inner_right - #self._tile_list * slot_w - (#self._tile_list - 1) * gap
	local tiles_x = x
	for _, rec in self._tile_list do
		at(rec, true, x, y)
		x += slot_w + gap
	end
	-- the hairlines, as between the strip's cells: between the buildings' groups, before Doctrine and Pacts, and
	-- between the two rows
	local function vline(line: any, lx: number, y0: number, y1: number)
		line:set_offsets(lx, y0 + 8, lx + 1, y1 - 8)
	end
	local gx = p
	for gi, g in FrameRules.BUILD_GROUPS do
		local n = 0
		for _, k in g.kinds do
			if not UICtx.core("Defs").DEPTH_KINDS[k] then
				n += 1
			end
		end
		gx += n * (slot_w + gap) - gap
		if gi < #FrameRules.BUILD_GROUPS then
			vline(self._lines[gi], gx + math.floor((group - gap) * 0.5 + gap * 0.5), p, p + h)
			gx += group - gap + gap
		end
	end
	vline(self._lines[3], tiles_x - math.ceil(gap * 0.5) - 1, y, y + h)
	local hl = self._lines[4]
	hl:set_offsets(p + 8, p + h + math.floor(gap * 0.5), inner_right - 8, p + h + math.floor(gap * 0.5) + 1)
end

--- Paints slot `rec` for its kind's availability now.
function ActionDock._paint(self, rec: any)
	local T = UITheme
	local rules = self.ctx.rules
	local av = if rules ~= nil then rules:availability(rec.kind) else { ok = true, cost = 0 }
	local text, tone = ActionDock.slot_text(av)
	rec.cost:set_text(text)
	local lit = self.aim_kind ~= nil and self.aim_kind() == rec.kind
	if lit then
		-- the slot being placed: its block goes amber, so everything on it is the dark ink (playtest 2026-11-08: white
		-- words and an amber price on the amber block could hardly be read)
		T.set_font_color(rec.cost, T.DIAL_INK)
		rec.tile:set_color(T.c(T.DIAL_INK, 0.18))
		rec.icon:set_color(T.DIAL_INK)
		T.set_font_color(rec.name, T.DIAL_INK)
	else
		T.set_font_color(rec.cost, if tone == "price" then T.DIAL_AMBER elseif tone == "short" then T.DIAL_RED else T.DIAL_MUTED)
		-- (the tile in its kind's colour; an age not yet come greys it, as the strip greys what is out of reach)
		local col = if tone == "dim" then T.DIAL_DIM else ActionDock.colour(rec.kind)
		rec.tile:set_color(T.c(col, 0.2))
		rec.icon:set_color(col)
		T.set_font_color(rec.name, if tone == "dim" then T.DIAL_MUTED else T.TEXT)
	end
	FrameKit.set_lit(rec.button, lit)
end

--- Fills the strike slots with what is on offer now; true when how many are on show, or which, changed.
function ActionDock._fill(self): boolean
	local strikes = {}
	if self.ctx.state ~= nil then
		local rules = self.ctx.rules
		local BuildWindow = UICtx.mod("BuildWindow")
		strikes = ActionDock.strike_kinds(function(k)
			return BuildWindow.offers(rules, k)
		end, #self._strikes)
	end
	-- (a slot taking another kind's name is laid out afresh: its name may wrap otherwise)
	local renamed = false
	for i, rec in self._strikes do
		local kind = strikes[i]
		rec.button:set_visible(kind ~= nil)
		if rec.kind ~= "" and rec.kind ~= kind and self._slots[rec.kind] == rec then
			self._slots[rec.kind] = nil
		end
		if kind ~= nil then
			if rec.kind ~= kind then
				rec.kind = kind
				rec.icon:set_icon(kind)
				rec.name:set_text(ActionDock.title(kind))
				renamed = true
			end
			self._slots[kind] = rec
		else
			rec.kind = ""
		end
	end
	local changed = #strikes ~= self._shown or renamed
	self._shown = #strikes
	return changed
end

function ActionDock._paint_all(self)
	if self.ctx.state == nil then
		return
	end
	-- a start date's own names and glyphs (Data/PeriodTech): the slots were made before the match said its date
	local per = self.ctx.state.period or ""
	if per ~= self._period then
		self._period = per
		local PT = UICtx.data("PeriodTech")
		for _, rec in self._buildings do
			if rec.kind ~= "" then
				rec.icon.icon_name = nil -- (the same name may draw another glyph now)
				rec.icon:set_icon(rec.kind)
				rec.name:set_text(ActionDock.title(rec.kind))
				-- (a building the date never has is not on the bar at all: the Aerodrome in 1066)
				rec.button:set_visible(not PT.closed(self.ctx.state.period, rec.kind))
			end
		end
		for _, rec in self._strikes do
			if rec.kind ~= "" then
				rec.icon.icon_name = nil -- (the same name may draw another glyph now)
				rec.icon:set_icon(rec.kind)
				rec.name:set_text(ActionDock.title(rec.kind))
			end
		end
		self:apply_layout()
	end
	for _, rec in self._buildings do
		self:_paint(rec)
	end
	for i = 1, self._shown do
		self:_paint(self._strikes[i])
	end
	local w = ActionDock.waiting(self.ctx)
	local d = self._tiles.doctrine
	d.badge:set_visible(w.doctrine)
	-- (a gold edge, not a filled block: its amber tile stays seen)
	FrameKit.set_style(d.button, if w.doctrine then "DialGold" else "DialSeg")
	self._tiles.pacts.dot:set_visible(w.offers > 0)
end

function ActionDock.refresh(self)
	if self.ctx.state == nil then
		return
	end
	-- (a strike coming on offer widens the bar: it re-centres)
	if self:_fill() and not self.ctx.compact then
		self:_place()
	end
	self:_paint_all()
end

--- Slot `key` (a building or strike kind) or the Doctrine / Pacts tile: pop-ups stand beside it, the tutorial points
--- at the City's.
function ActionDock.button(self, key: string): any
	local t = self._tiles[key]
	if t ~= nil then
		return t.button
	end
	local s = self._slots[key]
	return if s ~= nil then s.button else nil
end

--- What of it is on screen (logical px).
function ActionDock.rects(self): { Rect }
	if not (self:is_visible_in_tree() and self.panel.visible) then
		return {}
	end
	return { self.panel:get_global_rect() }
end

function ActionDock.update(self, delta: number)
	self._acc += delta
	if self._acc >= 0.25 then
		self._acc = 0.0
		if self:is_visible_in_tree() then
			self:refresh()
		end
	end
end

return ActionDock
