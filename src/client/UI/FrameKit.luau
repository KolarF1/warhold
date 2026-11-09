--!nonstrict
-- The strategy frame's shared pieces (2026-11-03; the dark cards since 2026-11-06, after Build a Phone Empire): the
-- rounded slate cards with their faint edge, rounded bars, icon tiles (a stat's icon on its colour at a fifth), the
-- segmented control's track, captions and value labels,
-- the three alert shapes (a red hexagon, an amber diamond, a green circle) with their count, hover cards and clicks on
-- any node, a nation's rank and relation in words, and the odds of an attack at a send share (FrameRules.estimate fed
-- from the match). Used by StrategyStrip, AlertRow, Outliner, WarClock, TargetCard, BuildWindow and OrderHub.

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")

local FrameKit = {}

FrameKit.PANEL_A = 0.94
FrameKit.DANGER = Color3.fromRGB(217, 65, 58)
FrameKit.CHOICE = UITheme.DIAL_AMBER
FrameKit.AVAILABLE = Color3.fromRGB(44, 136, 80)
--- The colour of each alert tier (FrameRules.TIER).
FrameKit.TIER_COLOUR = { danger = FrameKit.DANGER, choice = FrameKit.CHOICE, available = FrameKit.AVAILABLE }

--- A card (the frame's panels): `alpha` of the slate, rounded, with a faint edge (or `edge`, a colour: a card that wants
--- you), `radius` its corner (default UITheme.DIAL_RADIUS).
function FrameKit.slate(alpha: number?, edge: any?, radius: number?): any
	local p = W.Panel.new()
	FrameKit.set_card(p, alpha, edge, radius)
	-- (a plate, not a container: every slate places its children by their own anchors. A Panel stretches each child over
	-- the whole of it, which in Studio turned a 3 px accent bar into the plate's whole fill and piled the strip's columns)
	return FrameKit.free(p)
end

--- Restyles card `p` (FrameKit.slate's look): its edge in `edge` (2 px) or the faint one.
function FrameKit.set_card(p: any, alpha: number?, edge: any?, radius: number?)
	local T = UITheme
	p:add_theme_stylebox_override(
		"panel",
		T.flat(T.c(T.DIAL_SLATE, alpha or FrameKit.PANEL_A), radius or T.DIAL_RADIUS, edge or T.DIAL_EDGE, if edge ~= nil then 2 else 1, 0, 0)
	)
end

--- A rounded bar (progress fills and tracks, the age bar): `col` and its corner `radius` (default 3). It answers
--- set_color like a plain bar.
function FrameKit.round(col: any, radius: number?): any
	local p = FrameKit.free(W.Panel.new())
	p:set_mouse_filter(W.MOUSE_IGNORE)
	local r = radius or 3
	function p.set_color(self: any, c: any)
		self._round_col = c
		self:add_theme_stylebox_override("panel", UITheme.flat(c, r, UITheme.CLEAR, 0, 0, 0))
	end
	p:set_color(col)
	return p
end

--- An icon tile: a rounded square of `col` at a fifth with icon `icon` in `col` (the stat chips, the dock's tiles).
--- `px` its side (default 36). Returns the tile; its icon is `tile.icon`.
function FrameKit.tile(icon: string, col: any, px: number?): any
	local T = UITheme
	local s = px or 36
	local t = FrameKit.round(T.c(col, 0.2), math.floor(s * 0.28 + 0.5))
	t:set_min_size(Vector2.new(s, s))
	local ic = T.icon_rect(icon, math.floor(s * 0.56), col)
	ic:set_anchors(0.5, 0.5, 0.5, 0.5)
	local h = math.floor(s * 0.28)
	ic:set_offsets(-h, -h, h, h)
	t:add_child(ic)
	t.icon = ic
	return t
end

--- A segmented control's track: a rounded faint plate behind a row of choices (the send presets, the ages, the map
--- modes). Returns the track; lay the row over it with an inset of `pad` (default 4).
function FrameKit.track(radius: number?): any
	local p = FrameKit.free(W.Panel.new())
	p:set_mouse_filter(W.MOUSE_IGNORE)
	p:add_theme_stylebox_override("panel", UITheme.flat(UITheme.DIAL_TRACK, radius or 12, UITheme.CLEAR, 0, 0, 0))
	return p
end

--- Makes Panel `p` place its children by their own anchors instead of stretching each over the whole of it (a Panel
--- is a container: a 3 px accent bar added to one becomes its whole fill). Returns `p`.
function FrameKit.free(p: any): any
	p._is_container = false
	p._sort_children = W.Control._sort_children
	return p
end

--- A plain coloured bar (borders, progress fills, ticks): mouse passes through.
function FrameKit.bar(col: any): any
	local r = W.ColorRect.new(col)
	r:set_mouse_filter(W.MOUSE_IGNORE)
	return r
end

--- A caption: 12 px, bold, spaced, the dial's caption grey (or `col`).
function FrameKit.caption(text: string, col: any?): any
	return UITheme.label(text, 12, 800, col or UITheme.DIAL_CAPTION, 1)
end

--- A number: `size` px in the dial's heavy weight.
function FrameKit.value(text: string, size: number?, col: any?): any
	return UITheme.label(text, size or 22, UITheme.DIAL_WEIGHT, col or UITheme.TEXT)
end

--- A card on hover (the Tooltip system): `spec_fn()` gives its spec when the pointer comes.
function FrameKit.hover(ctx: any, node: any, spec_fn: () -> any)
	node.mouse_entered:Connect(function()
		local spec = spec_fn()
		if spec ~= nil and next(spec) ~= nil then
			ctx:show_hint(node, spec)
		end
	end)
	node.mouse_exited:Connect(function()
		ctx:hide_hint(node)
	end)
end

--- A press released on `node`: `left()` for the main button, `right()` for the other (both optional).
function FrameKit.on_click(node: any, left: (() -> ())?, right: (() -> ())?)
	node.gui_input:Connect(function(e)
		if e.kind ~= "button" or e.pressed then
			return
		end
		if e.button == 1 and left ~= nil then
			left()
		elseif e.button == 2 and right ~= nil then
			right()
		end
	end)
end

--- A button lit as the chosen one (the dial's amber block) or not (its ghost): the send presets. `b._lit` says which.
--- Gives button `b` the theme's look `name` ("DialGhost", "DialGold", ...). `b._lit` forgets what it was.
--- Style `st` for button `b`: as it is, or with b._mh as its side padding (a row of buttons that must fit a narrow card).
local function padded(b: any, st: any): any
	if b._mh == nil then
		return st
	end
	local t = UITheme.dup(st)
	t.mh = b._mh
	if t.margin then
		t.margin[1], t.margin[3] = b._mh, b._mh
	end
	return t
end

function FrameKit.set_style(b: any, name: string)
	local th = UITheme.theme()[name]
	if th == nil or b._style == name then
		return
	end
	b._style = name
	b._lit = nil
	for n, st in th.styles do
		b:add_theme_stylebox_override(n, padded(b, st))
	end
	for n, col in th.colors do
		b:add_theme_color_override(n, col)
	end
end

--- A button in a segmented control (`b._seg`) is bare when not lit.
function FrameKit.set_lit(b: any, on: boolean)
	if b._lit == on then
		return
	end
	b._lit = on
	local th = UITheme.theme()[if on then "DialButton" elseif b._seg then "DialSeg" else "DialGhost"]
	if th == nil then
		return
	end
	for name, st in th.styles do
		b:add_theme_stylebox_override(name, padded(b, st))
	end
	for name, col in th.colors do
		b:add_theme_color_override(name, col)
	end
end

--- The five send presets as buttons in `box` (an hbox or vbox): `label(p)` their words, a press picks one. Returns the
--- buttons; FrameKit.light_presets lights the chosen one and greys those above the cap.
--- `seg`: they sit in a segmented control (FrameKit.track), bare until lit. `mh`: their side padding, for a row that must
--- fit a narrow card (the nation window's: five at 12 px a side ran past its edge, 2026-11-07).
function FrameKit.preset_buttons(ctx: any, box: any, h: number, size: number, label: ((number) -> string)?, seg: boolean?, mh: number?): { any }
	local out = {}
	for i, p in FrameRules.PRESETS do
		local b = UITheme.button(if label ~= nil then label(p) else UICtx.ratio_name(p), if seg then "DialSeg" else "DialGhost", "", h)
		b._seg = seg == true
		if mh ~= nil then
			b._mh = mh
			FrameKit.set_lit(b, false)
		end
		b:set_font_size(size)
		b:set_min_size(Vector2.new(0, h))
		b.size_flags_horizontal = W.EXPAND_FILL
		b.pressed:Connect(function()
			if ctx:pick_preset(i) then
				ctx:sfx("click", -6.0)
			else
				ctx:sfx("deny", -6.0)
			end
		end)
		box:add_child(b)
		out[i] = b
	end
	return out
end

function FrameKit.light_presets(ctx: any, buttons: { any })
	local at = FrameRules.preset_index(ctx.ratio)
	for i, b in buttons do
		FrameKit.set_lit(b, i == at)
		b:set_disabled(not FrameRules.preset_allowed(i, ctx.ratio_max))
	end
end

--- Lays `node` at box `b` (logical px, the screen's top left).
function FrameKit.place(node: any, b: any)
	node:set_anchors(0, 0, 0, 0)
	node:set_offsets(b.x0, b.y0, b.x1, b.y1)
end

-- ---------------------------------------------------------------------------------------------
-- The alert shapes
-- ---------------------------------------------------------------------------------------------

--- An alert badge: `shape` ("hexagon" | "diamond" | "circle") filled `col` with a dark outline, an icon on it and a
--- count bubble at its top right. Returns { node, icon, count, count_box, set(shape, col, icon, n) }.
function FrameKit.badge(px: number): any
	local T = UITheme
	local node = W.Control.new()
	node:set_min_size(Vector2.new(px, px))
	node:set_mouse_filter(W.MOUSE_IGNORE)
	local rec = { node = node, px = px, parts = {} }
	-- the outline (a size up, in the slate), then the fill: a hexagon is three bars turned 0, 60 and 120 degrees
	local function layer(scale: number): { any }
		local out = {}
		for i = 1, 3 do
			local r = FrameKit.bar(T.DIAL_SLATE)
			node:add_child(r)
			out[i] = r
		end
		local circle = W.Panel.new()
		circle:set_mouse_filter(W.MOUSE_IGNORE)
		node:add_child(circle)
		out.circle = circle
		out.scale = scale
		return out
	end
	rec.outline = layer(1.0)
	rec.fill = layer(0.84)
	local icon = T.icon_rect("info", math.floor(px * 0.42), T.WHITE)
	icon:set_anchors(0.5, 0.5, 0.5, 0.5)
	local ih = math.floor(px * 0.21)
	icon:set_offsets(-ih, -ih, ih, ih)
	node:add_child(icon)
	rec.icon = icon
	local cb = W.Panel.new()
	cb:set_mouse_filter(W.MOUSE_IGNORE)
	cb:add_theme_stylebox_override("panel", T.flat(T.WHITE, 9, T.DIAL_SLATE, 1, 4, 0))
	cb:set_anchors(1, 0, 1, 0)
	cb:set_offsets(-14, -4, 6, 16)
	local cl = T.label("", 12, 800, T.DIAL_SLATE)
	cl:set_anchors(0, 0, 1, 1)
	cl.horizontal_alignment = W.ALIGN_CENTER
	cl.vertical_alignment = W.VALIGN_CENTER
	cb:add_child(cl)
	node:add_child(cb)
	rec.count_box = cb
	rec.count = cl
	cb:set_visible(false)
	function rec.set(shape: string, col: any, icon_name: string?, n: number?)
		local s = px
		for _, ly in { rec.outline, rec.fill } do
			local c = if ly == rec.outline then T.DIAL_SLATE else col
			local d = s * ly.scale
			local hex = shape == "hexagon"
			local dia = shape == "diamond"
			for i = 1, 3 do
				local r = ly[i]
				r:set_visible(hex or (dia and i == 1))
				r:set_color(c)
				r:set_anchors(0.5, 0.5, 0.5, 0.5)
				if hex then
					-- a hexagon point up: three bars as wide as it is across its flats, each as thick as its side, turned
					-- 0, 60 and 120 degrees (across the flats is 0.866 of point to point, which is the box)
					local wf = d * 0.866
					local hh = wf / math.sqrt(3) * 0.5
					r:set_offsets(-wf * 0.5, -hh, wf * 0.5, hh)
					r:set_rotation(math.rad((i - 1) * 60))
				elseif dia then
					local side = d * 0.7071 * 0.5
					r:set_offsets(-side, -side, side, side)
					r:set_rotation(math.rad(45))
				end
			end
			local circ = ly.circle
			circ:set_visible(shape == "circle")
			circ:add_theme_stylebox_override("panel", T.flat(c, 999, T.CLEAR, 0, 0, 0))
			circ:set_anchors(0.5, 0.5, 0.5, 0.5)
			circ:set_offsets(-d * 0.5, -d * 0.5, d * 0.5, d * 0.5)
		end
		if icon_name ~= nil and icon_name ~= "" then
			rec.icon:set_icon(icon_name)
		end
		-- (an amber block takes dark ink; red and green take white)
		rec.icon:set_color(if col == FrameKit.CHOICE then T.DIAL_INK else T.WHITE)
		local count = n or 1
		rec.count_box:set_visible(count > 1)
		rec.count:set_text(tostring(count))
	end
	return rec
end

-- ---------------------------------------------------------------------------------------------
-- Words about a nation
-- ---------------------------------------------------------------------------------------------

--- The relation's words for the selection window ("At war with you", "Bound to you by pact", "At peace with you").
function FrameKit.relation_words(rel: string): string
	if rel == "Hostile" then
		return "At war with you"
	elseif rel == "Pact" then
		return "Bound to you by pact"
	elseif rel == "Sworn" then
		return "On your side"
	elseif rel == "Oathbreaker" then
		return "Oathbreaker"
	elseif rel == "You" then
		return "Your nation"
	end
	return "At peace with you"
end

--- The same relation in one or two words, for badges and one-line summaries (the hover card): every place that names
--- a relation takes its words from these two, so a nation is never "Watching" in one place and "Neutral" in another.
function FrameKit.relation_short(rel: string): string
	if rel == "Hostile" then
		return "At war"
	elseif rel == "Pact" then
		return "Pact"
	elseif rel == "Sworn" then
		return "Ally"
	elseif rel == "Oathbreaker" then
		return "Oathbreaker"
	elseif rel == "You" then
		return "You"
	end
	return "At peace"
end

--- Everyone still standing by land (win share), largest first: { id, name, share }.
function FrameKit.standing(ctx: any): { any }
	local s = ctx.state
	local out = {}
	if s == nil then
		return out
	end
	local Defs = UICtx.core("Defs")
	for id, o in s.owners or {} do
		if o.alive ~= false and (o.tiles or 0) > 0 and o.kind ~= Defs.KIND_TRIBE then
			table.insert(out, { id = id, name = o.name, share = ctx:win_share(id) })
		end
	end
	return out
end

--- Owner `id`'s place by land among those standing (0: not ranked).
function FrameKit.rank_of(ctx: any, id: number): number
	for _, r in FrameRules.rivals(FrameKit.standing(ctx), id, 0) do
		if r.id == id then
			return r.rank
		end
	end
	return 0
end

-- ---------------------------------------------------------------------------------------------
-- The odds of an attack
-- ---------------------------------------------------------------------------------------------

--- The estimate of sending `share` of your army at owner `id` (FrameRules.estimate on the match's numbers). Returns
--- est, verdict, sent (troops). Nil when there is no such fight.
function FrameKit.odds(ctx: any, id: number, share: number): (any?, string?, number)
	local s = ctx.state
	local me = ctx:me()
	local mine = ctx:my()
	local o = if s ~= nil and id ~= 0 then s:get_owner(id) else nil
	if o == nil or mine == nil or id == me then
		return nil, nil, 0
	end
	local Defs = UICtx.core("Defs")
	local R = UICtx.core("Rules")
	local k = (tonumber(s.map and s.map.k_lin) or 1.0)
	local k_area = k * k
	local cap = ctx:floor_share()
	local sent = (mine.troops or 0) * math.min(share, cap)
	-- (their Bastions: the share of their land a post covers is not known here, so it counts one post as a tenth)
	local posts = 0
	for _, st in s.structures or {} do
		if st.owner == id and st.kind == Defs.S_DEFENSE then
			posts += 1
		end
	end
	local est = FrameRules.estimate(R, {
		sent = sent,
		def_troops = o.troops or 0,
		def_tiles = (o.tiles or 0) * k_area,
		att_tiles = (mine.tiles or 0) * k_area,
		def_tribe = o.kind == Defs.KIND_TRIBE,
		att_tribe = mine.kind == Defs.KIND_TRIBE,
		def_human = o.kind == Defs.KIND_HUMAN,
		traitor = type(s.is_traitor) == "function" and s:is_traitor(id),
		bastion = math.min(posts * 0.1, 0.6),
	})
	return est, FrameRules.verdict(est), sent
end

--- The odds line for owner `id` at the current send, and its short form and verdict.
function FrameKit.odds_lines(ctx: any, id: number): (string, string, string?)
	local s = ctx.state
	local o = if s ~= nil then s:get_owner(id) else nil
	local est, verdict, sent = FrameKit.odds(ctx, id, ctx.ratio)
	if est == nil or o == nil or verdict == nil then
		return "", "", nil
	end
	local best_i = FrameRules.best_preset(function(i)
		local _, v = FrameKit.odds(ctx, id, FrameRules.PRESETS[i])
		return v
	end, ctx.ratio_max)
	local best = if best_i ~= nil then UICtx.ratio_name(FrameRules.PRESETS[best_i]) else nil
	local pct = UICtx.ratio_name(ctx.ratio)
	return FrameRules.odds_line(pct, UITheme.fmt_troops(sent), UITheme.fmt_troops(o.troops or 0), verdict, best), FrameRules.odds_short(pct, verdict, best), verdict
end

return FrameKit
