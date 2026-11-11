--!nonstrict
-- The doctrine draft (Conquer the World's own): when an era opens, three cards, one doctrine to keep.
-- Not a modal: the match keeps running and the map stays clickable around it. On a desktop it is a column of dark cards
-- down the left edge, the outliner's mirror (2026-11-07, the owner): a head card (the age, the countdown, Later) over
-- one card a doctrine, each with its Choose; on a phone the three cards stand side by side in one glass panel, centred in
-- the free band. One at a time and never full screen; "Later" folds it away, and it waits as an amber diamond in the alert row (UI/AlertRow: a press unfolds it). A player
-- who never chooses gets the first card when the timer runs out (the Sim decides that, this only counts down). A card
-- shows the doctrine's name, its numbers (what it gives, what it costs) and one line of why. The edicts your doctrines
-- grant are green alerts (a press uses one); under the top bar, centred: the match's mode, the Crown's chip (King of the
-- Hill) and the world event's.
--
--   DoctrineDraft.new(ctx, ui)
--   :refresh()                         reads ctx.state: the local player's open offer, if any
--   :apply_layout(top_y, bottom_y)     where it may sit (logical px): from under the alert row (a desktop's column
--                                      down to FrameRules.layout's draft foot, a phone's band to bottom_y)
--   :unfold()                          the amber alert pressed: the cards again
--   .picked (Signal: key)              a card was chosen (the intent is sent here too)
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")
local Defs = UICtx.core("Defs")
local Doctrines = UICtx.data("Doctrines")
local WorldEvents = UICtx.data("WorldEvents")
local Eras = UICtx.data("Eras")

local DoctrineDraft = W.class(W.Control)

DoctrineDraft.CARD_W = 196
DoctrineDraft.CARD_W_COMPACT = 190

--- The local player's open draft row in `state` ({ id, draft, a, b, c, chosen, deadline }), or nil.
function DoctrineDraft.open_row(state: any, me: number): { number }?
	if state == nil or me == 0 or state.doctrine == nil then
		return nil
	end
	local by = state.doctrine[me]
	if by == nil then
		return nil
	end
	local best: { number }? = nil
	for draft = 1, Doctrines.TIERS do
		local row = by[draft]
		if row ~= nil and row[6] == 0 then
			best = row
		end
	end
	return best
end

--- The text a card prints for a doctrine: its effect lines, gains first.
function DoctrineDraft.card_lines(d: any): { string }
	return Doctrines.effects(d)
end

function DoctrineDraft.new(c: any, ui: any)
	local self = setmetatable({}, DoctrineDraft.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.ui = ui
	self.picked = Signal.new()
	self._row = nil :: any
	self._collapsed = false
	self._sent_at = -1.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)

	-- what is on screen: a plain column (a desktop's head card and doctrine cards, or a phone's one glass panel)
	local panel = T.vbox(UICtx.mod("FrameRules").OUT_CARD_GAP)
	self.panel = panel
	-- the head's pieces, shared by both arrangements (_arrange moves them)
	self._title = T.label("DRAFT", 13, 800, T.AMBER, 2)
	self._title.size_flags_vertical = W.SHRINK_CENTER
	self._timer = T.label("", 12, 600, T.TEXT_2)
	self._timer.size_flags_vertical = W.SHRINK_CENTER
	self._sp = W.Control.new()
	self._sp.size_flags_horizontal = W.EXPAND_FILL
	self._sp:set_mouse_filter(W.MOUSE_IGNORE)
	self._later = T.button("Later", "GhostButton", "", 30.0)
	self._later:set_font_size(12)
	self._later:set_min_size(Vector2.new(56, 30))
	self._later.pressed:Connect(function()
		self._collapsed = true
		self:_show()
		self.ui:relayout()
	end)
	self._hint = T.label("Pick one. It stays for the rest of the match.", 12, 500, T.TEXT_3)
	self._hint:set_autowrap(true)
	-- a phone's: one glass panel, the head on one line, the cards side by side
	local glass = GlassPanel.new(14.0, 10.0, T.R_LG, true, 18)
	glass:set_tint(T.GLASS_SOLID)
	glass:set_accent(T.AMBER, 3.0)
	glass:set_border(T.c(T.AMBER, 0.45))
	self._glass = glass
	self._glass_v = T.vbox(8)
	glass:add_child(self._glass_v)
	self._glass_head = T.hbox(10)
	self._cards_box = T.hbox(8)
	-- a desktop's: the head card (age and Later, the countdown, the hint)
	local hc = GlassPanel.new(12.0, 10.0, T.R_MD, false, 0)
	hc:set_tint(T.DIAL_SLATE)
	hc:set_accent(T.AMBER, 3.0)
	hc:set_border(T.c(T.AMBER, 0.45))
	self._head_card = hc
	self._head_v = T.vbox(4)
	hc:add_child(self._head_v)
	self._head_row = T.hbox(10)
	self._mode = nil
	self._cards = {}
	self:add_child(panel)
	panel:set_visible(false)
	self:_arrange()

	self.chip = T.button("DRAFT", "PublicButton", "", 32.0)
	self.chip:set_font_size(12)
	self.chip:set_min_size(Vector2.new(84, 32))
	self.chip.pressed:Connect(function()
		self._collapsed = false
		-- (asked for: it opens even where the band is short, or a phone could never pick)
		self._asked = true
		self:_show()
		self.ui:relayout()
	end)
	self:add_child(self.chip)
	self.chip:set_visible(false)
	-- the active orders ("edicts") the player's doctrines grant: a chip each, with its cooldown
	self.edict_chips = {}
	for _, name in DoctrineDraft.EDICTS do
		local chip = T.button(string.upper(name), "PublicButton", "", 32.0)
		chip:set_font_size(12)
		chip:set_min_size(Vector2.new(132, 32))
		chip.pressed:Connect(function()
			self.ctx:send({ type = "edict", kind = name })
			self.ctx:sfx("confirm", -4.0)
		end)
		chip:set_visible(false)
		self:add_child(chip)
		self.edict_chips[name] = chip
	end
	-- the world event running, with its clock: a press repeats what it does
	self.event_chip = T.button("", "ChipButton", "", 32.0)
	self.event_chip:set_font_size(12)
	self.event_chip:set_min_size(Vector2.new(150, 32))
	-- (not a button: it only tells. Hovered, it says what the event does; playtest 2026-11-08, it looked pressable)
	UICtx.mod("FrameKit").hover(c, self.event_chip, function()
		local we = self.ctx.state ~= nil and self.ctx.state.world_event
		local d = we and WorldEvents.LIST[we[1]]
		if d == nil then
			return nil
		end
		return { title = d.name, body = d.line .. (if d.leader then " It falls on the largest nation." else " It falls on every nation.") }
	end)
	self.event_chip:set_visible(false)
	self:add_child(self.event_chip)
	-- the match's mode, always (2026-11-09, the owner: obvious what mode is being played, not in the way): it only tells
	self.mode_chip = T.button("", "ChipButton", "", 32.0)
	self.mode_chip:set_font_size(12)
	self.mode_chip:set_min_size(Vector2.new(96, 32))
	UICtx.mod("FrameKit").hover(c, self.mode_chip, function()
		local s = self.ctx.state
		local Modes = UICtx.data("Modes")
		local m = Modes.BY_KEY[(s and s.mode) or Modes.DEFAULT]
		if m == nil then
			return nil
		end
		return { title = m.name, body = m.line }
	end)
	self.mode_chip:set_visible(false)
	-- (a depth match: the chip opens your Realm)
	self.mode_chip.pressed:Connect(function()
		if self.ui ~= nil and self.ui.open_realm ~= nil then
			self.ui:open_realm()
		end
	end)
	self:add_child(self.mode_chip)
	-- King of the Hill: who holds the Crown, and for how long in all
	self.crown_chip = T.button("", "ChipButton", "crown", 32.0)
	self.crown_chip:set_font_size(12)
	self.crown_chip:set_min_size(Vector2.new(190, 32))
	self.crown_chip.pressed:Connect(function()
		local crown = self.ctx.state ~= nil and self.ctx.state.crown
		if crown and self.ctx.world ~= nil and type(self.ctx.world.focus_tile) == "function" then
			self.ctx.world:focus_tile(crown[1], -1.0, 0.6)
		end
	end)
	self.crown_chip:set_visible(false)
	self:add_child(self.crown_chip)
	-- (a thin fill along each chip's foot: the Crown's hold toward victory, the event's time left)
	local function foot(chip: any): any
		local fill = W.ColorRect.new(T.GOLD)
		fill:set_mouse_filter(W.MOUSE_IGNORE)
		fill:set_anchors(0, 1, 0, 1)
		fill:set_offsets(4, -4, 4, -2)
		chip:add_child(fill)
		return fill
	end
	self._crown_fill = foot(self.crown_chip)
	self._event_fill = foot(self.event_chip)
	-- (these sit on the map, whatever its colour: a dark plate, or pale land washes their text out)
	local plated = { self.chip, self.mode_chip, self.event_chip, self.crown_chip }
	for _, chip in self.edict_chips do
		table.insert(plated, chip)
	end
	for _, chip in plated do
		local plate = T.flat(T.GLASS, T.R_MD, T.LINE_2, 1, 12.0, 4.0)
		chip:add_theme_stylebox_override("normal", plate)
		chip:add_theme_stylebox_override("hover", T.flat(T.GLASS_RAISED, T.R_MD, T.c(T.AMBER, 0.6), 1, 12.0, 4.0))
		chip:add_theme_stylebox_override("pressed", plate)
		chip:add_theme_color_override("font_color", T.TEXT)
		chip:add_theme_color_override("font_hover_color", T.TEXT)
	end
	-- (the event chip only tells: no lit outline under the pointer, so it never looks pressable)
	local still = T.flat(T.GLASS, T.R_MD, T.LINE_2, 1, 12.0, 4.0)
	self.event_chip:add_theme_stylebox_override("hover", still)
	self.event_chip:add_theme_stylebox_override("pressed", still)
	self.mode_chip:add_theme_stylebox_override("hover", still)
	self.mode_chip:add_theme_stylebox_override("pressed", still)
	self._acc = 0.0
	self:set_process(true)
	return self
end

--- The edict names, in the order their chips sit.
DoctrineDraft.EDICTS = Doctrines.EDICT_ORDER

--- The edicts (names) the local player's doctrines grant.
function DoctrineDraft.my_edicts(state: any, me: number): { [string]: boolean }
	local out = {}
	local by = if state ~= nil and me ~= 0 and state.doctrine ~= nil then state.doctrine[me] else nil
	for draft = 1, Doctrines.TIERS do
		local row = if by ~= nil then by[draft] else nil
		if row ~= nil and row[6] >= 1 and row[6] <= Doctrines.OFFER_SIZE then
			local d = Doctrines.LIST[row[2 + row[6]]]
			if d.edict ~= nil then
				out[d.edict] = true
			end
		end
	end
	return out
end

--- A chip's fill along its foot: `share` of its width (0..1), in `col`.
function DoctrineDraft._set_fill(chip: any, fill: any, share: number, col: Color3)
	local w = math.max(chip.size.X - 8, 0)
	fill:set_offsets(4, -4, 4 + math.floor(w * math.clamp(share, 0, 1) + 0.5), -2)
	fill:set_color(col)
end

--- The running world event, under the top bar: "PLAGUE · 0:42", red for a bad one, gold for a good one, its fill running
--- down with the time left (playtest 2026-11-08: Hard Winter and the rest showed no end). A press says what it does.
--- True when it changed visibility.
function DoctrineDraft._refresh_event(self): boolean
	local ctx = self.ctx
	local s = ctx.state
	local we = if s ~= nil and s.phase == Defs.PHASE_PLAYING then s.world_event else nil
	local left = if we ~= nil then (we[3] - ctx:render_tick()) / Defs.TICK_RATE else 0
	local d = if we ~= nil then WorldEvents.LIST[we[1]] else nil
	local on = left > 0 and d ~= nil
	local was = self.event_chip.visible
	self.event_chip:set_visible(on)
	if on then
		local col = if d.good then UITheme.GOLD else UITheme.RED
		self.event_chip:set_text(string.format("%s · %s", string.upper(d.name), UITheme.fmt_time(math.ceil(left))))
		self.event_chip:add_theme_color_override("font_color", col)
		self.event_chip:add_theme_color_override("font_hover_color", col)
		DoctrineDraft._set_fill(self.event_chip, self._event_fill, left / math.max(d.secs, 1), col)
	end
	return was ~= on
end

--- A draft's title: "DRAFT · DAWN"; a depth match's "IDEAS · MILITARY" or "TECH · AGE 2" (Data/Doctrines.depth_draft).
function DoctrineDraft.draft_title(s: any, draft: number, era_name: string): string
	if s ~= nil and s.depth ~= nil then
		local age, cat = Doctrines.depth_draft(draft)
		if cat == "tech" then
			return string.format("TECH · AGE %d", age)
		end
		return "IDEAS · " .. string.upper(Doctrines.CAT_NAMES[cat] or cat)
	end
	return string.format("DRAFT · %s", string.upper(era_name))
end

--- A card's name: a tech's medieval name in a medieval match.
function DoctrineDraft.card_name(s: any, d: any): string
	if s ~= nil and s.period ~= nil and d.m_name ~= nil then
		return d.m_name
	end
	return d.name
end

--- The mode chip's words and tone: "CONQUEST", "TEAMS · BLITZ", "HARDCORE" (red: the hard war), a phone's the
--- mode's short name. Pure but for Data/Modes.
function DoctrineDraft.mode_words(mode: string?, teams: boolean, short: boolean?): (string, string)
	local Modes = UICtx.data("Modes")
	local m = Modes.BY_KEY[mode or Modes.DEFAULT] or Modes.BY_KEY[Modes.DEFAULT]
	local name = string.upper(if short and m.short ~= nil then m.short else m.name)
	if teams then
		name = "TEAMS · " .. name
	end
	return name, if m.key == "hardcore" then "red" else "dim"
end

--- The mode chip, under the top bar while a match is on. True when it changed visibility or words.
function DoctrineDraft._refresh_mode(self): boolean
	local s = self.ctx.state
	local on = s ~= nil and (s.phase == Defs.PHASE_PLAYING or s.phase == Defs.PHASE_SPAWN)
	local was = self.mode_chip.visible
	self.mode_chip:set_visible(on)
	if not on then
		return was
	end
	local teams = type(s.team_names) == "table" and next(s.team_names) ~= nil
	local text, tone = DoctrineDraft.mode_words(s.mode, teams, self.ctx.compact)
	-- (a depth match says its pace and opens the Realm)
	if s.depth ~= nil then
		-- (Long and Quick are work in progress, the owner 2026-11-09)
		text = string.format("%s · %s WIP · REALM", text, if s.depth.key == "quick" then "QUICK" else "LONG")
	end
	local before = self.mode_chip.text
	if text ~= before then
		self.mode_chip:set_text(text)
		local col = if tone == "red" then UITheme.RED else UITheme.TEXT_DIM
		self.mode_chip:add_theme_color_override("font_color", col)
		self.mode_chip:add_theme_color_override("font_hover_color", col)
	end
	return not was or text ~= before
end

--- The Crown's words: "YOU HOLD THE CROWN · 2:38 TO WIN", "RUSSIA HOLDS THE CROWN · 0:42 TO WIN", "THE CROWN IS
--- UNCLAIMED · TAKE IT", "THE CROWN OPENS IN 1:20"; and its tone ("gold": yours, "red": a rival's, "dim"). Pure.
function DoctrineDraft.crown_words(who: string?, mine: boolean, left_s: number, opens_s: number): (string, string)
	local fmt = UITheme.fmt_time
	if opens_s > 0 then
		return string.format("THE CROWN OPENS IN %s", fmt(math.ceil(opens_s))), "dim"
	elseif who == nil then
		return "THE CROWN IS UNCLAIMED · TAKE IT", "dim"
	elseif mine then
		return string.format("YOU HOLD THE CROWN · %s TO WIN", fmt(math.ceil(math.max(left_s, 0)))), "gold"
	end
	return string.format("%s HOLDS THE CROWN · %s TO WIN", string.upper(who), fmt(math.ceil(math.max(left_s, 0)))), "red"
end

--- The Crown's bar under the top bar: who holds it and how long until they win, its fill the hold so far (playtest
--- 2026-11-08: a win by the Crown came as a surprise; the old chip read "CROWN: YOU 0:23 / 3:01" at the side). A press
--- shows the Crown on the map. True when it changed visibility.
function DoctrineDraft._refresh_crown(self): boolean
	local s = self.ctx.state
	local crown = if s ~= nil and s.phase == Defs.PHASE_PLAYING then s.crown else nil
	local was = self.crown_chip.visible
	self.crown_chip:set_visible(crown ~= nil)
	if crown ~= nil then
		local holder = crown[3]
		-- (when it opens is the match's own, crown[4]: sooner on a small map)
		local opens = (s.playing_since or 0) + (crown[4] or UICtx.core("SimModes").CROWN_OPEN_TICKS) - self.ctx:render_tick()
		local held = if holder > 0 then (s.crown_ticks[holder] or 0) / Defs.TICK_RATE else 0
		local need = crown[2] / Defs.TICK_RATE
		local mine = holder > 0 and holder == self.ctx:me()
		local text, tone = DoctrineDraft.crown_words(if holder > 0 then s:owner_name(holder) else nil, mine, need - held, opens / Defs.TICK_RATE)
		local col = if tone == "gold" then UITheme.GOLD elseif tone == "red" then UITheme.RED else UITheme.TEXT_DIM
		self.crown_chip:set_text(text)
		self.crown_chip:add_theme_color_override("font_color", col)
		self.crown_chip:add_theme_color_override("font_hover_color", col)
		DoctrineDraft._set_fill(self.crown_chip, self._crown_fill, if holder > 0 and opens <= 0 then held / math.max(need, 1) else 0, col)
	end
	return was ~= (crown ~= nil)
end

--- Chips for the edicts held: "WINDFALL" when ready, "WINDFALL 2:41" while it cools.
function DoctrineDraft._refresh_edicts(self)
	local ctx = self.ctx
	local s = ctx.state
	local mine = DoctrineDraft.my_edicts(s, ctx:me())
	local playing = s ~= nil and s.phase == Defs.PHASE_PLAYING
	local ready_at = if s ~= nil and s.edict_ready ~= nil then (s.edict_ready[ctx:me()] or 0) else 0
	local left = math.max(0, math.ceil((ready_at - ctx:render_tick()) / Defs.TICK_RATE))
	for name, chip in self.edict_chips do
		-- (an edict ready is a green alert now, UI/AlertRow: the chips keep their words for the debug channel's edict_fire,
		-- hidden)
		local on = playing and mine[name] == true
		chip:set_visible(false)
		if on then
			local running = if s.edict_buff ~= nil then (s.edict_buff[ctx:me()] or 0) else 0
			local run_left = math.ceil((running - ctx:render_tick()) / Defs.TICK_RATE)
			if run_left > 0 then
				chip:set_text(string.format("%s ON %s", string.upper(name), UITheme.fmt_time(run_left)))
			else
				chip:set_text(if left > 0 then string.format("%s %s", string.upper(name), UITheme.fmt_time(left)) else string.upper(name))
			end
		end
	end
end

local function detach(node: any)
	local p = node:get_parent()
	if p ~= nil then
		p:remove_child(node)
	end
end

--- Puts the head's pieces and the containers in the arrangement for the screen now (a phone's glass panel, or a
--- desktop's column of cards). Cards built for the other arrangement go: the next refresh builds them afresh.
function DoctrineDraft._arrange(self)
	local compact = self.ctx.compact == true
	if self._mode == compact then
		return
	end
	self._mode = compact
	for _, card in self._cards do
		card:queue_free()
	end
	table.clear(self._cards)
	for _, n in { self._title, self._timer, self._sp, self._later, self._hint, self._glass, self._head_card, self._glass_head, self._cards_box, self._head_row } do
		detach(n)
	end
	if compact then
		for _, n in { self._title, self._timer, self._sp, self._later } do
			self._glass_head:add_child(n)
		end
		self._glass_v:add_child(self._glass_head)
		self._glass_v:add_child(self._hint)
		self._glass_v:add_child(self._cards_box)
		self.panel:add_child(self._glass)
	else
		for _, n in { self._title, self._sp, self._later } do
			self._head_row:add_child(n)
		end
		self._head_v:add_child(self._head_row)
		self._head_v:add_child(self._timer)
		self._head_v:add_child(self._hint)
		local w = UICtx.mod("FrameRules").SIDE_W
		self._head_card:set_min_size(Vector2.new(w, 0))
		self._hint:set_min_size(Vector2.new(w - 24, 0))
		self.panel:add_child(self._head_card)
	end
	-- (a phone's band is short: the cards say what to do)
	self._hint:set_visible(not compact)
end

--- A desktop's card for doctrine `d`: a pill as wide as the outliner, its glyph, name and Choose on one line, its numbers
--- under them, then its one line of why.
function DoctrineDraft._column_card(self, d: any): any
	local T = UITheme
	local w = UICtx.mod("FrameRules").SIDE_W
	local card = GlassPanel.new(12.0, 10.0, T.R_MD, false, 0)
	card:set_tint(T.DIAL_SLATE)
	card:set_border(T.LINE_2)
	card:set_min_size(Vector2.new(w, 0))
	local cv = T.vbox(4)
	local top = T.hbox(8)
	local glyph = T.label(d.glyph, 22, 900, T.AMBER)
	glyph.size_flags_vertical = W.SHRINK_CENTER
	top:add_child(glyph)
	local name = T.label(DoctrineDraft.card_name(self.ctx.state, d), 14, 800, T.TEXT)
	name:set_autowrap(true)
	name:set_min_size(Vector2.new(w - 24 - 30 - 92 - 16, 0))
	name.size_flags_horizontal = W.EXPAND_FILL
	name.size_flags_vertical = W.SHRINK_CENTER
	top:add_child(name)
	local pick = T.button("Choose", "PrimaryButton", "", 32.0)
	pick:set_font_size(13)
	pick:set_min_size(Vector2.new(100, 32)) -- (92 left "Choose" 2 px short of its words; 2026-11-08 scan)
	pick.size_flags_vertical = W.SHRINK_CENTER
	pick.pressed:Connect(function()
		self:choose(d.key)
	end)
	top:add_child(pick)
	cv:add_child(top)
	for _, line in DoctrineDraft.card_lines(d) do
		local cost = string.sub(line, 1, 1) == "-"
		cv:add_child(T.label(line, 12, 700, if cost then T.RED else T.GREEN))
	end
	local why = T.label(d.line, 12, 500, T.TEXT_2)
	why:set_autowrap(true)
	why:set_min_size(Vector2.new(w - 24, 0))
	cv:add_child(why)
	card:add_child(cv)
	return card
end

--- Builds the three cards of `row`.
function DoctrineDraft._build_cards(self, row: { number })
	local T = UITheme
	local ctx = self.ctx
	self:_arrange()
	for _, card in self._cards do
		card:queue_free()
	end
	table.clear(self._cards)
	if not ctx.compact then
		for slot = 1, Doctrines.OFFER_SIZE do
			local card = self:_column_card(Doctrines.LIST[row[2 + slot]])
			self.panel:add_child(card)
			table.insert(self._cards, card)
		end
		return
	end
	local w = DoctrineDraft.CARD_W_COMPACT
	local small = true
	for slot = 1, Doctrines.OFFER_SIZE do
		local d = Doctrines.LIST[row[2 + slot]]
		local card = GlassPanel.new(10.0, 8.0, T.R_MD, false, 0)
		card:set_tint(T.GLASS_RAISED)
		card:set_border(T.LINE_2)
		-- (every card the height of the tallest, three effect lines: no ragged row)
		card:set_min_size(Vector2.new(w, if small then 128 else 150))
		local cv = T.vbox(4)
		local top = T.hbox(6)
		local glyph = T.label(d.glyph, if small then 18 else 22, 900, T.AMBER)
		glyph.size_flags_vertical = W.SHRINK_CENTER
		top:add_child(glyph)
		local name = T.label(DoctrineDraft.card_name(self.ctx.state, d), if small then 12 else 14, 800, T.TEXT)
		name:set_autowrap(true)
		-- (a wrapped label measures against its width: without one it asks for a line per letter)
		name:set_min_size(Vector2.new(w - 52, 0))
		name.size_flags_horizontal = W.EXPAND_FILL
		name.size_flags_vertical = W.SHRINK_CENTER
		top:add_child(name)
		cv:add_child(top)
		for _, line in DoctrineDraft.card_lines(d) do
			local cost = string.sub(line, 1, 1) == "-"
			cv:add_child(T.label(line, 12, 700, if cost then T.RED else T.GREEN))
		end
		local why = T.label(d.line, 12, 500, T.TEXT_2)
		why:set_autowrap(true)
		why:set_min_size(Vector2.new(w - 20, 0))
		-- (takes what the card has left: the three buttons stand on one line)
		why.size_flags_vertical = W.EXPAND_FILL
		cv:add_child(why)
		local pick = T.button("Choose", "PrimaryButton", "", if small then 32.0 else 36.0)
		pick:set_font_size(if small then 12 else 14)
		pick.pressed:Connect(function()
			self:choose(d.key)
		end)
		cv:add_child(pick)
		card:add_child(cv)
		self._cards_box:add_child(card)
		table.insert(self._cards, card)
	end
end

--- Takes doctrine `key`: sends the intent and folds away until the Sim's answer arrives.
function DoctrineDraft.choose(self, key: string)
	if self._row == nil then
		return
	end
	self.ctx:send({ type = "doctrine", kind = key })
	self._sent_at = self.ctx:render_tick()
	self.ctx:sfx("confirm", -4.0)
	self.picked:Fire(key)
	self:_show()
end

function DoctrineDraft._show(self)
	local open = self._row ~= nil and (self._sent_at < 0 or self.ctx:render_tick() - self._sent_at > 20)
	self.panel:set_visible(open and not self._collapsed)
	-- (the tutorial holding the draft: nothing else calls for it either, no alert, no PICK, until its step; 2026-11-11 review)
	self.ctx.draft_held = self._row ~= nil and self._collapsed and self:_tutorial_holds(self._row[2])
	-- (folded, it waits as the alert row's amber diamond: the old chip stays hidden)
	self.chip:set_visible(false)
end

--- True while a draft waits folded (the alert row shows it).
function DoctrineDraft.folded(self): boolean
	return self._row ~= nil and self._collapsed
end

--- The amber alert pressed: the cards open again (even where the band is short: a phone must be able to pick).
function DoctrineDraft.unfold(self)
	if self._row == nil then
		return
	end
	self._collapsed = false
	self._asked = true
	self:_show()
	if self.ui ~= nil then
		self.ui:relayout()
	end
end

--- Reads the state: the player's open offer (a new one builds its cards and opens).
function DoctrineDraft.refresh(self)
	local ctx = self.ctx
	local s = ctx.state
	local row = DoctrineDraft.open_row(s, ctx:me())
	if s ~= nil and (s.phase ~= Defs.PHASE_PLAYING) then
		row = nil
	end
	local changed = (row == nil) ~= (self._row == nil) or (row ~= nil and self._row ~= nil and row[2] ~= self._row[2])
	self._row = row
	if changed and row ~= nil then
		self._collapsed = self:_tutorial_holds(row[2])
		self._asked = false
		self._sent_at = -1.0
		self:_build_cards(row)
		local era_name = Eras.NAMES[math.min(row[2], #Eras.NAMES)]
		self._title:set_text(DoctrineDraft.draft_title(s, row[2], era_name))
		ctx:sfx("unlock", -6.0)
	end
	if row ~= nil then
		local left = math.max(0, math.ceil((row[7] - ctx:render_tick()) / Defs.TICK_RATE))
		self._timer:set_text(string.format("Auto-picks in %s", UITheme.fmt_time(left)))
	end
	self:_show()
	self:_refresh_edicts()
	if changed and self.ui ~= nil and self.ui.relayout ~= nil then
		-- (opened or closed: the column comes or goes, and the match log steps aside or back)
		self.ui:relayout()
	end
end

--- True while the tutorial has not reached the step that teaches draft `draft`: it waits folded as the DRAFT chip, so
--- nothing unexplained covers the card the player is on. The first waits for "doctrine", a later one for "newage".
function DoctrineDraft._tutorial_holds(self, draft: number): boolean
	local tut = if self.ui ~= nil then self.ui.tutorial else nil
	if tut == nil or not tut.active then
		return false
	end
	local at = UICtx.data("Tutorial").step_index(if draft >= 2 then "newage" else "doctrine")
	return at ~= nil and (tut._i or 1) < at
end

function DoctrineDraft._process(self, dt: number)
	if self._row ~= nil then
		self:refresh()
		-- (a nation's window opening or closing moves a desktop's column beside it or back to the edge)
		local tc = self.ui and self.ui.target_card
		local open = tc ~= nil and tc.is_open == true
		if self._band ~= nil and open ~= self._beside then
			self:apply_layout(self._band[1], self._band[2])
		end
	end
	self._acc += dt
	if self._acc >= 0.25 then
		self._acc = 0.0
		self:_refresh_edicts()
		local a, b, m = self:_refresh_event(), self:_refresh_crown(), self:_refresh_mode()
		if (a or b or m) and self.ui ~= nil then
			self.ui:relayout()
		end
	end
end

--- Where it sits: the strategy frame's pop-up place (FrameRules.layout: beside the selection window's column, under the
--- alert row), between `top_y` and `bottom_y`; the Crown's chip under the alert row.
function DoctrineDraft.apply_layout(self, top_y: number, bottom_y: number)
	self._band = { top_y, bottom_y }
	local ctx = self.ctx
	local vp, ins = ctx.vp, ctx.insets
	if self._mode ~= (ctx.compact == true) then
		-- (the screen changed between a phone's and a desktop's: the cards are built afresh for it)
		self:_arrange()
		if self._row ~= nil then
			self:_build_cards(self._row)
		end
	end
	local FR = UICtx.mod("FrameRules")
	local rr = ctx.reserved_top_left
	local lay = FR.layout(vp, ctx.compact, ins, FR.box(rr.Min.X, rr.Min.Y, rr.Max.X, rr.Max.Y), {})
	if not ctx.compact then
		-- (a desktop's column ends on the command bar)
		bottom_y = math.min(bottom_y, lay.draft.y1)
	end
	-- (the cards do not fit the free band, as on a phone under the tutorial's card: fold to the alert)
	if self._row ~= nil and not self._collapsed and self._sent_at < 0 and not self._asked then
		self.panel:reset_size()
		if self.panel:get_combined_minimum_size().Y > (bottom_y - top_y) + 4.0 then
			self._collapsed = true
			self:_show()
		end
	end
	local area = lay.popup
	-- the Crown's bar and the world event's chip: side by side, centred under the top bar (2026-11-08, the owner)
	local chips = {}
	for _, c in { self.mode_chip, self.crown_chip, self.event_chip } do
		if c.visible then
			table.insert(chips, c)
		end
	end
	if #chips > 0 then
		-- (rows that fit the strip's width: a phone with the mode, the Crown and an event wraps to a second row)
		local room = lay.strip.x1 - lay.strip.x0
		local rows, row, used = {}, {}, -8.0
		for _, c in chips do
			c:reset_size()
			local sz = c:get_combined_minimum_size()
			if #row > 0 and used + 8.0 + sz.X > room then
				table.insert(rows, { chips = row, w = used })
				row, used = {}, -8.0
			end
			table.insert(row, c)
			used += sz.X + 8.0
		end
		table.insert(rows, { chips = row, w = used })
		local mid = (lay.strip.x0 + lay.strip.x1) * 0.5
		local y = math.floor(lay.strip.y1 + 8.0)
		for _, r in rows do
			local x = math.max(math.floor(mid - r.w * 0.5), lay.strip.x0)
			local tall = 0.0
			for _, c in r.chips do
				local sz = c:get_combined_minimum_size()
				UICtx.move_node(c, Vector2.new(x, y))
				x += sz.X + 8.0
				tall = math.max(tall, sz.Y)
			end
			y += math.floor(tall + 6.0)
		end
		-- (a phone's cards stand under them; a desktop's column is at the left edge, clear of them)
		if ctx.compact then
			top_y = math.max(top_y, y + 2.0)
		end
	end
	if self.panel.visible and not ctx.compact then
		-- a desktop's column: down the left edge from under the alert row, as the outliner hangs down the right
		self.panel:reset_size()
		-- (a nation's window holds the left column while it is open: the draft stands beside it)
		local tc = self.ui and self.ui.target_card
		self._beside = tc ~= nil and tc.is_open == true
		local x = if self._beside then lay.popup.x0 else lay.draft.x0
		UICtx.move_node(self.panel, Vector2.new(math.floor(x), math.floor(math.max(top_y, lay.draft.y0))))
	elseif self.panel.visible then
		self.panel:reset_size()
		local sz = self.panel:get_combined_minimum_size()
		local x = area.x0 + math.max(0, (area.x1 - area.x0 - sz.X) * 0.5)
		x = math.clamp(x, ins.x + 8.0, math.max(ins.x + 8.0, vp.X - ins.z - sz.X - 8.0))
		local y = math.max(top_y, top_y + (bottom_y - top_y - sz.Y) * 0.4)
		-- (opened on request in a short band: it may cover the thumbs for a moment, never run off the screen)
		y = math.min(y, vp.Y - ins.w - sz.Y - 4.0)
		UICtx.move_node(self.panel, Vector2.new(math.floor(x), math.floor(y)))
	end
end

--- The panel's rect in logical px (nil when folded), for what must keep clear of it.
function DoctrineDraft.rect(self)
	if self.panel.visible then
		return self.panel:get_global_rect()
	end
	return nil
end

return DoctrineDraft
