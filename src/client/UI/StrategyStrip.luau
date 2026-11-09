--!nonstrict
-- The strategy frame's top strip (2026-11-03, the owner's approved mock-up; it replaced the command dial's spine and age
-- track): starting right of Roblox's own top-left buttons, a slate band with a bottom border in your colour holding,
-- left to right, your crest, ARMY (troops, the cap in its caption, and the regrowth a second), GOLD (and income a
-- second), LAND (your share of what wins, a bar with a tick at the win line), WARHEADS ready and PACTS. (SEND moved to
-- the send panel over the war clock, 2026-11-03: UI/SendPanel.) Every number explains itself in a card on hover. At the
-- top right: World Tension and CHANCES (weak neighbours your send should break, and pact offers; a press lists them). A
-- phone's strip is read-only and compact: army, send, gold, land, and the war's time and age (a tap shows your nation's
-- card).
--
-- UIRoot knows it as `top`. Signals: tapped() (a phone's tap), chances_wanted(). Members: panel, side (the top right),
-- clock_text (() -> string: the phone's time and age, set by UIRoot), stats_spec().
-- Methods: apply_layout(), refresh(), bottom_edge(), update(dt).

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")
local Portrait = require("./Portrait")
local Signal = UITheme.core("Signal")

local StrategyStrip = W.class(W.Control)

--- A stat chip's icon tile, and where its words start.
StrategyStrip.TILE = 36
StrategyStrip.TEXT_X = 58
--- A phone's tiles (its strip is FrameRules.STRIP_H_PHONE tall).
StrategyStrip.TILE_PHONE = 22

local function UIRules(): any
	return UICtx.mod("UIRules")
end

function StrategyStrip.new(c: any)
	local self = setmetatable({}, StrategyStrip.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.tapped = Signal.new()
	self.chances_wanted = Signal.new()
	self.clock_text = nil
	self._acc = 0.0
	self._rate = 0.0
	self._col = T.DIAL_AMBER
	self._chances = {}
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	-- the strip
	local panel = FrameKit.slate()
	panel.name = "TopStrip"
	panel:set_mouse_filter(W.MOUSE_STOP)
	FrameKit.on_click(panel, function()
		if c.touch then
			self.tapped:Fire()
		end
	end)
	self.panel = panel
	self:add_child(panel)
	self._cells = {}
	-- a cell: `icon` its chip's tile (in `icon_col`), then its caption over its number
	local function cell(key: string, caption: string?, value_size: number, value_col: any, icon: string?, icon_col: any?): any
		local n = W.Control.new()
		n.name = "Cell_" .. key
		n:set_mouse_filter(W.MOUSE_STOP)
		panel:add_child(n)
		local rec = { node = n, key = key }
		local x = 14
		if icon ~= nil then
			local tile = FrameKit.tile(icon, icon_col or T.TEXT, StrategyStrip.TILE)
			tile:set_anchors(0, 0.5, 0, 0.5)
			local h = StrategyStrip.TILE * 0.5
			tile:set_offsets(12, -h, 12 + StrategyStrip.TILE, h)
			n:add_child(tile)
			rec.tile = tile
			x = StrategyStrip.TEXT_X
		end
		if caption ~= nil then
			rec.caption = FrameKit.caption(UICtx.data("PeriodTech").word(caption))
			UICtx.data("PeriodTech").on_apply(function()
				rec.caption:set_text(UICtx.data("PeriodTech").word(caption))
			end)
			rec.caption:set_anchors(0, 0, 1, 0)
			rec.caption:set_offsets(x, 9, -6, 24)
			n:add_child(rec.caption)
		end
		local row = T.hbox(6)
		row:set_anchors(0, 0, 1, 1)
		row:set_offsets(x, 24, -6, -6)
		row:set_alignment(W.ALIGN_BEGIN)
		rec.row = row
		rec.value = FrameKit.value("", value_size, value_col)
		rec.value.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(rec.value)
		rec.rate = T.label("", 16, 700, T.DIAL_GREEN)
		rec.rate.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(rec.rate)
		n:add_child(row)
		-- (a hairline between cells)
		local line = FrameKit.bar(T.c(T.WHITE, 0.1))
		line:set_anchors(1, 0, 1, 1)
		line:set_offsets(-1, 8, 0, -10)
		n:add_child(line)
		rec.line = line
		self._cells[key] = rec
		FrameKit.hover(c, n, function()
			return self:card(key)
		end)
		return rec
	end
	-- the crest: your colour and flag on a rounded tile, your nation's name, and the age as a thin bar
	local crest = cell("crest", nil, 16, T.TEXT)
	crest.row:set_visible(false)
	self._crest_back = FrameKit.round(T.DIAL_AMBER, 12)
	self._crest_back:set_anchors(0, 0.5, 0, 0.5)
	self._crest_back:set_offsets(10, -21, 52, 21)
	crest.node:add_child(self._crest_back)
	self._portrait = Portrait.new(34)
	self._portrait:set_anchors(0, 0.5, 0, 0.5)
	self._portrait:set_offsets(14, -17, 48, 17)
	crest.node:add_child(self._portrait)
	self._name = FrameKit.value("", 15, T.TEXT)
	self._name:set_anchors(0, 0, 1, 0)
	self._name:set_offsets(62, 8, -10, 26)
	self._name.clip_text = true
	self._name.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	crest.node:add_child(self._name)
	self._age_cap = T.label("", 12, 700, T.DIAL_CAPTION)
	self._age_cap:set_anchors(0, 0, 1, 0)
	self._age_cap:set_offsets(62, 26, -8, 40)
	crest.node:add_child(self._age_cap)
	self._age_track = FrameKit.round(T.c(T.WHITE, 0.1), 2)
	self._age_track:set_anchors(0, 0, 1, 0)
	self._age_track:set_offsets(62, 44, -14, 48)
	crest.node:add_child(self._age_track)
	self._age_fill = FrameKit.round(T.CHIP_BLUE, 2)
	self._age_fill:set_anchors(0, 0, 0, 1)
	self._age_track:add_child(self._age_fill)
	cell("army", "ARMY", 22, T.TEXT, "troops", T.CHIP_RED)
	cell("gold", "GOLD", 22, T.GOLD, "gold", T.CHIP_GOLD)
	local land = cell("land", "LAND", 22, T.TEXT, "land", T.CHIP_GREEN)
	land.row:set_visible(false)
	self._land_track = FrameKit.round(T.c(T.WHITE, 0.12), 4)
	self._land_track:set_anchors(0, 0, 1, 0)
	self._land_track:set_offsets(StrategyStrip.TEXT_X, 32, -16, 40)
	land.node:add_child(self._land_track)
	self._land_fill = FrameKit.round(T.CHIP_GREEN, 4)
	self._land_fill:set_anchors(0, 0, 0, 1)
	self._land_track:add_child(self._land_fill)
	self._land_tick = FrameKit.bar(T.DIAL_AMBER)
	self._land_tick:set_anchors(1, 0, 1, 1)
	self._land_tick:set_offsets(-2, -4, 0, 4)
	self._land_track:add_child(self._land_tick)
	cell("warheads", "WARHEADS", 22, T.TEXT, "atom", T.CHIP_VIOLET)
	local pacts = cell("pacts", "PACTS", 22, T.TEXT, "alliance", T.CHIP_BLUE)
	pacts.line:set_visible(false)
	-- a phone's: one row, army, gold and land each beside its icon tile, then the war's time and age (2026-11-06: its send
	-- left for the caption over the phone's own share buttons, to make room for the tiles)
	local ph = T.hbox(10)
	ph:set_anchors(0, 0, 1, 1)
	ph:set_offsets(10, 0, -10, -2)
	ph:set_alignment(W.ALIGN_BEGIN)
	self._phone_row = ph
	self._ph = {}
	local tiles = { army = { "troops", T.CHIP_RED }, gold = { "gold", T.CHIP_GOLD }, land = { "land", T.CHIP_GREEN } }
	for _, k in { "army", "gold", "land", "clock" } do
		local l = FrameKit.value("", 16, if k == "gold" then T.GOLD elseif k == "clock" then T.DIAL_MUTED else T.TEXT)
		l.size_flags_vertical = W.SHRINK_CENTER
		local t = tiles[k]
		if t ~= nil then
			local chip = T.hbox(5)
			chip.size_flags_vertical = W.SHRINK_CENTER
			local tile = FrameKit.tile(t[1], t[2], StrategyStrip.TILE_PHONE)
			tile.size_flags_vertical = W.SHRINK_CENTER
			chip:add_child(tile)
			chip:add_child(l)
			ph:add_child(chip)
		else
			ph:add_child(l)
		end
		self._ph[k] = l
	end
	panel:add_child(ph)
	-- the top right: World Tension and CHANCES
	local side = FrameKit.slate()
	side.name = "Tension"
	side:set_mouse_filter(W.MOUSE_STOP)
	self.side = side
	self:add_child(side)
	local meter = W.Control.new()
	meter:set_mouse_filter(W.MOUSE_IGNORE)
	meter:set_anchors(0, 0, 0, 0)
	meter:set_offsets(10, 14, 40, 42)
	side:add_child(meter)
	-- (the gauge: five blocks, lit up to the tension's step)
	self._meter = {}
	for i = 1, 5 do
		local b = FrameKit.bar(T.c(T.WHITE, 0.16))
		b:set_anchors(0, 1, 0, 1)
		b:set_offsets((i - 1) * 6, -6 - i * 4, (i - 1) * 6 + 4, 0)
		meter:add_child(b)
		self._meter[i] = b
	end
	local tv = T.vbox(0)
	tv:set_anchors(0, 0, 1, 1)
	tv:set_offsets(44, 7, -128, -6)
	tv:set_mouse_filter(W.MOUSE_STOP)
	tv:add_child(FrameKit.caption("WORLD TENSION"))
	self._tension = FrameKit.value("Calm", 18, T.DIAL_GREEN)
	tv:add_child(self._tension)
	side:add_child(tv)
	FrameKit.hover(c, tv, function()
		return self:card("tension")
	end)
	self._tension_box = tv
	local chances = T.button("CHANCES 0", "DialGold", "", 40.0)
	chances:set_font_size(14)
	chances:set_anchors(1, 0.5, 1, 0.5)
	chances:set_offsets(-120, -20, -12, 20)
	chances.pressed:Connect(function()
		self.chances_wanted:Fire()
	end)
	chances.mouse_entered:Connect(function()
		c:show_hint(chances, self:card("chances"))
	end)
	chances.mouse_exited:Connect(function()
		c:hide_hint(chances)
	end)
	self._chances_btn = chances
	side:add_child(chances)
	return self
end

-- ---------------------------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------------------------

function StrategyStrip.apply_layout(self)
	local ctx = self.ctx
	local r = ctx.reserved_top_left
	local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), {})
	self._layout = l
	FrameKit.place(self.panel, l.strip)
	local compact = ctx.compact
	-- (a screen too narrow for the full cells shows the phone's compact row of chips instead of dropping cells:
	-- FrameRules' strip_narrow, audit A1)
	local narrow = compact or l.strip_narrow == true
	self.side:set_visible(not compact)
	self._phone_row:set_visible(narrow)
	-- (a narrow desktop has its war clock on screen: the row needs no time of its own)
	self._ph.clock:set_visible(compact)
	local x = 0
	local width = l.strip.x1 - l.strip.x0
	local k = l.strip_k or 1
	for _, spec in FrameRules.CELLS do
		local rec = self._cells[spec.key]
		local cw = math.floor(spec.w * k)
		local on = not narrow and x + cw <= width + 0.5
		rec.node:set_visible(on)
		rec.node:set_anchors(0, 0, 0, 1)
		rec.node:set_offsets(x, 0, x + cw, 0)
		x += cw
	end
	if not compact then
		FrameKit.place(self.side, l.side)
	end
	self:refresh()
end

--- The foot of the strip (what stands under it starts there).
function StrategyStrip.bottom_edge(self): number
	if not self.panel.visible or self._layout == nil then
		return 12.0 + self.ctx.insets.y
	end
	return self._layout.strip.y1
end

-- ---------------------------------------------------------------------------------------------
-- Data
-- ---------------------------------------------------------------------------------------------

function StrategyStrip._difficulty(self): number
	local session = self.ctx.session
	return if session ~= nil then (tonumber(session.difficulty) or 1) else 1
end

--- Which age the war is in (1..4, 0 before play), how many there are, and how far through this one (0..1; 1 in the last).
function StrategyStrip.age_progress(self): (number, number, number)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or s.eras == nil or s.playing_since == nil or s.playing_since < 0 then
		return 0, 4, 0
	end
	local t = ctx:render_tick() - s.playing_since
	local eras = s.eras
	local era = 1
	for i = 1, #eras do
		if t >= eras[i] then
			era = i
		end
	end
	local nxt = eras[era + 1]
	local k = if nxt ~= nil then (t - eras[era]) / math.max(nxt - eras[era], 1) else 1
	return era, #eras, k
end

--- Your share of what wins, and the win line (a team game: your side's).
function StrategyStrip.land(self): (number, number)
	local ctx = self.ctx
	local s = ctx.state
	local me = ctx:me()
	local goal = (s and s.win_share) or UITheme.core("Rules").WIN_SHARE
	local held = ctx:win_share(me)
	if s ~= nil and type(s.is_team_game) == "function" and s:is_team_game() then
		held = ctx:team_share(s:team_of(me))
	end
	return held, goal
end

--- How many pacts you hold.
function StrategyStrip.pact_count(self): number
	local s = self.ctx.state
	local me = self.ctx:me()
	if s == nil or me == 0 or type(s.allies_of) ~= "function" then
		return 0
	end
	return #s:allies_of(me)
end

function StrategyStrip.refresh(self)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	local o = ctx:my()
	if s == nil or o == nil then
		return
	end
	local Rules = T.core("Rules")
	local Defs = T.core("Defs")
	local col = T.owner_ui_color(o.color)
	if col ~= self._col then
		self._col = col
		self._crest_back:set_color(col)
	end
	self._portrait:set_owner(ctx, o.id, true)
	self._name:set_text(o.name or "")
	local era, of, k = self:age_progress()
	local Eras = UICtx.data("Eras")
	-- (a match with a start date says its year in place of the count: "1241 · DAWN"; Data/Periods)
	local per = if ctx.state ~= nil then ctx.state.period else nil
	if era > 0 and per ~= nil then
		self._age_cap:set_text(string.format("%s · %s", per, string.upper(Eras.NAMES[era] or "")))
	else
		self._age_cap:set_text(if era > 0 then string.format("AGE %d OF %d · %s", era, of, string.upper(Eras.NAMES[era] or "")) else "")
	end
	self._age_fill:set_anchors(0, 0, math.clamp(k, 0, 1), 1)
	local cap = math.max(o.max_troops or 1, 1)
	self._rate = Rules.troop_growth(o.kind, o.troops, cap, self:_difficulty()) * Defs.TICK_RATE
	local cells = self._cells
	cells.army.caption:set_text("ARMY · CAP " .. string.upper(T.fmt_troops(cap)))
	cells.army.value:set_text(T.fmt_troops(o.troops))
	cells.army.rate:set_text(UIRules().troop_rate_text(self._rate))
	cells.gold.value:set_text(T.fmt_num(o.gold))
	cells.gold.rate:set_text(T.fmt_rate(o.income))
	local held, goal = self:land()
	cells.land.caption:set_text(string.format("LAND %d%% OF %d%%", math.floor(held * 100 + 0.5), math.floor(goal * 100 + 0.5)))
	self._land_fill:set_color(col)
	self._land_fill:set_anchors(0, 0, math.clamp(held / math.max(goal, 0.01), 0, 1), 1)
	local ready = if ctx.rules ~= nil then ctx.rules:ready_missiles() else 0
	cells.warheads.value:set_text(string.format("%d ready", ready))
	-- (a medieval start date fights with siege and fire, not warheads: Data/PeriodTech)
	local cap = if ctx.state ~= nil and ctx.state.period ~= nil then "SIEGE" else "WARHEADS"
	if cells.warheads.caption ~= nil and cells.warheads.caption.text ~= cap then
		cells.warheads.caption:set_text(cap)
	end
	cells.pacts.value:set_text(tostring(self:pact_count()))
	-- a phone's row
	local ph = self._ph
	ph.army:set_text(T.fmt_troops(o.troops))
	ph.gold:set_text(T.fmt_num(o.gold))
	ph.land:set_text(string.format("%d%% / %d", math.floor(held * 100 + 0.5), math.floor(goal * 100 + 0.5)))
	ph.clock:set_text(if self.clock_text ~= nil then self.clock_text() else "")
	-- the top right
	local score, word = self:tension()
	self._tension:set_text(word)
	T.set_font_color(self._tension, if score >= 0.6 then T.DIAL_RED elseif score >= 0.35 then T.DIAL_AMBER else T.DIAL_GREEN)
	for i, b in self._meter do
		b:set_color(if score >= (i - 1) / 5 + 0.01 then (if i >= 4 then T.DIAL_RED elseif i >= 2 then T.DIAL_AMBER else T.DIAL_GREEN) else T.c(T.WHITE, 0.16))
	end
	self._chances = self:chances()
	self._chances_btn:set_text(string.format("CHANCES %d", #self._chances))
end

--- World Tension: (score, word, nations at war, nations standing, warheads flown).
function StrategyStrip.tension(self): (number, string, number, number, number)
	local s = self.ctx.state
	if s == nil then
		return 0, "Calm", 0, 0, 0
	end
	local Defs = UITheme.core("Defs")
	local fighting = {}
	local nations = 0
	for id, o in s.owners or {} do
		if o.alive ~= false and (o.tiles or 0) > 0 and o.kind ~= Defs.KIND_TRIBE then
			nations += 1
		end
	end
	for _, a in s.attacks or {} do
		local at, tg = s:get_owner(a.attacker), if a.target ~= 0 then s:get_owner(a.target) else nil
		if at ~= nil and tg ~= nil and at.kind ~= Defs.KIND_TRIBE and tg.kind ~= Defs.KIND_TRIBE then
			fighting[a.attacker] = true
			fighting[a.target] = true
		end
	end
	local n = 0
	for _ in fighting do
		n += 1
	end
	local flown = tonumber(self.ctx.warheads_flown) or 0
	local score, word = FrameRules.tension(n, nations, flown)
	return score, word, n, nations, flown
end

--- CHANCES: neighbours the current send should break, then pact offers to you (FrameRules.chances).
function StrategyStrip.chances(self): { any }
	local ctx = self.ctx
	local s = ctx.state
	local me = ctx:me()
	if s == nil or me == 0 or not ctx:alive_player() then
		return {}
	end
	local weak = {}
	local ids = if ctx.borders ~= nil and type(ctx.borders.neighbour_ids) == "function" then ctx.borders:neighbour_ids() else {}
	for _, id in ids do
		local o = s:get_owner(id)
		if o ~= nil and o.alive ~= false and not s:are_allies(me, id) then
			local _, v = FrameKit.odds(ctx, id, ctx.ratio)
			if v ~= nil then
				table.insert(weak, { id = id, name = o.name, verdict = v, troops = o.troops or 0 })
			end
		end
	end
	local offers = {}
	for key in s.requests or {} do
		local from, to = key // 1024, key % 1024
		if to == me and from ~= me and s:get_owner(from) ~= nil then
			table.insert(offers, { id = from, name = s:owner_name(from) })
		end
	end
	return FrameRules.chances(weak, offers, UICtx.ratio_name(ctx.ratio))
end

function StrategyStrip.chance_list(self): { any }
	return self._chances
end

-- ---------------------------------------------------------------------------------------------
-- The cards (every number says what it means)
-- ---------------------------------------------------------------------------------------------

--- Your nation's card: the crest's, and a phone's tap on the strip.
function StrategyStrip.stats_spec(self): { [string]: any }
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	local o = ctx:my()
	if s == nil or o == nil then
		return {}
	end
	local DominionStrip = UICtx.mod("DominionStrip")
	local rows: { any } = {}
	if s.eras ~= nil and s.playing_since ~= nil and s.playing_since >= 0 then
		local picks = DominionStrip.picks_of(s, ctx:me())
		local m = DominionStrip.model(s.eras, ctx:render_tick() - s.playing_since, picks)
		table.insert(rows, { "Age", if m.next_s ~= nil then string.format("%s · %s %s", m.name, m.next_name, T.fmt_time(m.next_s)) else m.name })
		if #m.glyphs > 0 then
			table.insert(rows, { "Doctrines", table.concat(m.glyphs, " "), T.GOLD })
		end
	end
	table.insert(rows, { "Troops", string.format("%s of %s", T.fmt_troops(o.troops), T.fmt_troops(o.max_troops)) })
	table.insert(rows, { "Coming back", UIRules().troop_rate_text(self._rate), T.TEXT })
	table.insert(rows, { "Gold", string.format("%s  %s", T.fmt_num(o.gold), T.fmt_rate(o.income)), T.GOLD })
	local held, goal = self:land()
	table.insert(rows, { "Land", string.format("%s of the %s that wins", T.fmt_pct(held), T.fmt_pct(goal)) })
	table.insert(rows, { "Send", string.format("%s · %s", UICtx.ratio_name(ctx.ratio), T.fmt_troops(ctx:troops_for_ratio())), T.DIAL_AMBER })
	return { title = o.name, swatch = o.color, rows = rows }
end

--- The card over cell `key`: what the number is, in a sentence or two.
function StrategyStrip.card(self, key: string): { [string]: any }
	local ctx = self.ctx
	local T = UITheme
	local o = ctx:my()
	if o == nil and key ~= "tension" then
		return {}
	end
	if key == "crest" then
		return self:stats_spec()
	elseif key == "army" then
		return {
			title = "Army",
			body = string.format(
				"%s troops of the %s your land can hold. They grow back by themselves, %s now, and fastest while you hold well under the cap.",
				T.fmt_troops(o.troops),
				T.fmt_troops(o.max_troops or 0),
				UIRules().troop_rate_text(self._rate)
			),
		}
	elseif key == "gold" then
		return {
			title = "Gold",
			body = string.format("%s in the treasury, %s from your land, trade and Foundries. Each building of a kind costs more than the last.", T.fmt_num(o.gold), T.fmt_rate(o.income)),
		}
	elseif key == "land" then
		local held, goal = self:land()
		return {
			title = "Land",
			body = string.format("You hold %s of the land. The first to hold %s wins the war.", T.fmt_pct(held), T.fmt_pct(goal)),
		}
	elseif key == "warheads" then
		local ready = if ctx.rules ~= nil then ctx.rules:ready_missiles() else 0
		return {
			title = UICtx.data("PeriodTech").word("Warheads"),
			body = if UICtx.data("PeriodTech").applied() ~= nil
				then string.format("%d ready to loose: each needs a Siege Works with nothing reloading. Siege Works open in the Conflict.", ready)
				else string.format("%d ready to fly: each needs a Launch Site with nothing reloading. Launch Sites open in the Conflict.", ready),
		}
	elseif key == "pacts" then
		return {
			title = "Pacts",
			body = string.format("%d nations bound to you by pact. Neither side may attack while it lasts; it can be kept when it nears its end.", self:pact_count()),
		}
	elseif key == "tension" then
		local _, word, n, nations, flown = self:tension()
		return {
			title = "World Tension: " .. word,
			body = string.format("%d of the %d nations standing are fighting one another, and %d %s have flown. It reads how close the world is to all-out war.", n, nations, flown, UICtx.data("PeriodTech").word("warheads")),
		}
	elseif key == "chances" then
		return {
			title = "Chances",
			body = "Neighbours your current send should break through, and pacts offered to you. Press to list them.",
		}
	end
	return {}
end

function StrategyStrip.update(self, delta: number)
	self._acc += delta
	if self._acc >= 0.25 then
		self._acc = 0.0
		if self:is_visible_in_tree() then
			self:refresh()
		end
	end
end

return StrategyStrip
