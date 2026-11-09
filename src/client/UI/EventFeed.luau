--!nonstrict
-- Dispatches: what has happened in the war, sorted by what it means for you. On a larger screen a thin log on the
-- right-hand edge, headed by the age: DANGER, GAINS, WORD, each line plain with a small mark. Danger stays longest and
-- always reads first; word from afar goes quickly. A report that comes again is folded into its line ("3 reports: ...").
-- On a phone: one line on the bottom edge between the thumbs; a newer one takes its place, and a tap sends it away.
-- Since the strategy frame (2026-11-03) the match's news is the outliner's LOG (UI/NewsLog) and its alerts (UI/AlertRow);
-- this feed is the notices' toasts at the top (UIRoot's `notices`). `quiet` and `letters_off` remain for a feed that wants
-- one line and no letters.
--
-- A pact arrives as a letter: the sender's wax seal, which melts as the offer runs out, and two answers. Letters never
-- move under a finger: they have their own place at the top of the screen, apart from the log.
--
-- EventFeed.new(ctx, top_mode = false). Members: _stack, top_mode.
-- Methods: apply_layout(bottom_y, right_extra, phone_left, phone_right), apply_layout_top(y), stack_rect(), clear(),
-- toast(category, text, icon_name?, seconds?), alliance_request(from_id), close_request(from_id),
-- alliance_renewal(other, expires_at, other_asked), close_renewal(other), has_renewal_card(other),
-- close_all_requests(), has_request_card(from_id); per frame update(dt).

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")

local EventFeed = W.class(W.Control)

--- The log's groups, in reading order, and how long a line of each stays (seconds; a phone's are shorter).
EventFeed.GROUPS = { "danger", "gain", "word" }
EventFeed.GROUP_TITLE = { danger = "DANGER", gain = "GAINS", word = "WORD" }
EventFeed.GROUP_MARK = { danger = "!", gain = "+", word = "·" }
EventFeed.LIFE = { danger = 11.0, gain = 5.5, word = 3.2 }
EventFeed.LIFE_PHONE = { danger = 6.0, gain = 3.2, word = 2.2 }
--- A larger screen's log: its width, and the most lines on show.
EventFeed.LOG_W = 300.0
EventFeed.MAX_LINES = 5
--- A top-of-screen notice (a session's news): its width, and the most on show.
EventFeed.NOTICE_W = 440.0
EventFeed.NOTICE_W_PHONE = 340.0
EventFeed.MAX_NOTICES = 3
--- The same report inside this long is folded into its line.
EventFeed.FOLD_MS = 5000
--- A phone's line: its height, its widest, and the least room worth using between the thumbs.
EventFeed.PHONE_LINE_H = 28.0
EventFeed.PHONE_MAX_W = 420.0
EventFeed.PHONE_MIN_W = 180.0
EventFeed.PHONE_FONT = 12
--- A letter's wax seal, and the width kept for its answers under a finger.
EventFeed.SEAL_PX = 22.0
EventFeed.SEAL_PX_PHONE = 18.0

local function msec(): number
	return os.clock() * 1000.0
end

local function Defs(): any
	return UITheme.core("Defs")
end

--- The group a message category belongs to: what it means for you. Pure.
function EventFeed.group_of(category: number): string
	local D = Defs()
	if category == D.MSG_ALERT or category == D.MSG_BAD then
		return "danger"
	elseif category == D.MSG_GOOD or category == D.MSG_ALLIANCE then
		return "gain"
	end
	return "word"
end

--- A line's text once the report has come `count` times. Pure.
function EventFeed.folded(text: string, count: number): string
	return if count > 1 then string.format("%d reports: %s", count, text) else text
end

--- A line's life: `seconds` when given, else its group's. Pure.
function EventFeed.life_of(group: string, compact: boolean, seconds: number?): number
	if seconds ~= nil and seconds > 0 then
		return seconds
	end
	return (if compact then EventFeed.LIFE_PHONE else EventFeed.LIFE)[group]
end

--- A phone's line: between Build's plate (`left`) and the Send bar's (`right`) on the bottom edge when that leaves room,
--- else above Build. Returns x, y, width. Pure.
function EventFeed.phone_slot(left: number, right: number, vp_w: number, inset_x: number, bottom: number, bar_top: number)
	local room = right - left - 16.0
	if room >= EventFeed.PHONE_MIN_W then
		return left + 8.0, bottom - EventFeed.PHONE_LINE_H - 8.0, math.min(room, EventFeed.PHONE_MAX_W)
	end
	return inset_x + 8.0, bar_top - EventFeed.PHONE_LINE_H - 8.0, math.min(vp_w - inset_x - 16.0, EventFeed.PHONE_MAX_W)
end

function EventFeed.new(c: any, top: boolean?)
	local self = setmetatable({}, EventFeed.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	--- Top-of-screen variant (session notices): grows downwards, visible on every screen.
	self.top_mode = top == true
	--- One quiet line on every screen (the command dial's world news), and no letters.
	self.quiet = false
	self.letters_off = false
	self._cards = {} -- from owner id -> a letter
	self._recent = {} -- text -> {node, count, msec, label, text}
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._stack = T.vbox(3)
	self._stack:set_alignment(if self.top_mode then W.ALIGN_BEGIN else W.ALIGN_END)
	self:add_child(self._stack)
	-- the log's head (the age) and its groups
	self._age_l = T.caption("", 11, T.TEXT_2)
	self._age_l:set_visible(false)
	self._stack:add_child(self._age_l)
	self._groups = {}
	for _, key in EventFeed.GROUPS do
		local box = T.vbox(3)
		local cap = T.caption(EventFeed.GROUP_TITLE[key], 11, T.TEXT_3)
		box:add_child(cap)
		local lines = T.vbox(3)
		box:add_child(lines)
		box:set_visible(false)
		self._stack:add_child(box)
		self._groups[key] = { box = box, cap = cap, lines = lines }
	end
	-- letters: their own column
	self._letters = T.vbox(6)
	self:add_child(self._letters)
	return self
end

--- Top of the screen, for notices.
function EventFeed.apply_layout_top(self, y: number)
	local ctx = self.ctx
	local w = if not ctx.compact then EventFeed.NOTICE_W else EventFeed.NOTICE_W_PHONE
	local st = self._stack
	st.anchor_left, st.anchor_right, st.anchor_top, st.anchor_bottom = 0.5, 0.5, 0.0, 0.0
	st.grow_horizontal = W.GROW_BOTH
	st.grow_vertical = W.GROW_END
	w = math.min(w, ctx.vp.X - ctx.insets.x - ctx.insets.z - 24.0)
	local dx, yy = ctx:place_top(w, y)
	st.offset_left = dx - w * 0.5
	st.offset_right = dx + w * 0.5
	st.offset_top = yy
	st.offset_bottom = yy
	st:set_min_size(Vector2.new(w, 0))
	self._line_w = w
end

--- `bottom_y`: the line above the command bar. `right_extra`: an opened Standings sheet's width (the log moves out from
--- under it). `phone_left`, `phone_right`: where Build's plate ends and the Send bar's begins.
--- One line at a time: a phone's, and the quiet feed's.
function EventFeed._one_line(self): boolean
	return self.ctx.compact or self.quiet
end

function EventFeed.apply_layout(self, bottom_y: number, right_extra: number?, phone_left: number?, phone_right: number?)
	local ctx = self.ctx
	local st = self._stack
	local bottom = ctx.vp.Y - ctx.insets.w
	if self:_one_line() then
		local x, y, w = EventFeed.phone_slot(phone_left or 0.0, phone_right or 0.0, ctx.vp.X, ctx.insets.x, bottom, bottom_y + 12.0)
		st.anchor_left, st.anchor_right, st.anchor_top, st.anchor_bottom = 0.0, 0.0, 0.0, 0.0
		st.grow_vertical = W.GROW_END
		st.grow_horizontal = W.GROW_END
		st:set_alignment(W.ALIGN_BEGIN)
		st.offset_left, st.offset_right = x, x + w
		st.offset_top, st.offset_bottom = y, y
		st:set_min_size(Vector2.new(w, 0))
		self._line_w = w
	else
		-- the right-hand edge, standing on the foot of the screen: the corner your own card does not hold
		local right = 8.0 + ctx.insets.z + (right_extra or 0.0)
		st:set_alignment(W.ALIGN_END)
		st.anchor_left, st.anchor_right, st.anchor_top, st.anchor_bottom = 1.0, 1.0, 1.0, 1.0
		st.grow_vertical = W.GROW_BEGIN
		st.grow_horizontal = W.GROW_BEGIN
		st.offset_left, st.offset_right = -right, -right
		st.offset_bottom = -(ctx.insets.w + 12.0)
		st.offset_top = st.offset_bottom
		st:set_min_size(Vector2.new(EventFeed.LOG_W, 0))
		self._line_w = EventFeed.LOG_W
	end
	st:queue_layout()
	-- letters: a phone's under the top row at the left, a larger screen's at the top right
	local ls = self._letters
	ls.anchor_top, ls.anchor_bottom = 0.0, 0.0
	ls.grow_vertical = W.GROW_END
	if ctx.compact then
		local x = 8.0 + ctx.insets.x
		ls.anchor_left, ls.anchor_right = 0.0, 0.0
		ls.grow_horizontal = W.GROW_END
		ls.offset_left, ls.offset_right = x, x
		local top = ctx.airship_bar.Max.Y + 2.0
		ls.offset_top, ls.offset_bottom = top, top
	else
		local right = 8.0 + ctx.insets.z + (right_extra or 0.0)
		ls.anchor_left, ls.anchor_right = 1.0, 1.0
		ls.grow_horizontal = W.GROW_BEGIN
		ls.offset_left, ls.offset_right = -right, -right
		local top = 12.0 + ctx.insets.y
		ls.offset_top, ls.offset_bottom = top, top
	end
	ls:queue_layout()
	self:_trim()
end

function EventFeed.stack_rect(self): Rect
	if self:is_visible_in_tree() then
		return self._stack:get_global_rect()
	end
	return Rect.new(0, 0, 0, 0)
end

function EventFeed.clear(self)
	for _, line in ipairs(self:_all_lines()) do
		line:queue_free()
	end
	for _, card in pairs(self._cards) do
		card:queue_free()
	end
	table.clear(self._cards)
	table.clear(self._recent)
	self:_sync_groups()
end

-- ---------------------------------------------------------------------------------------------
-- Lines
-- ---------------------------------------------------------------------------------------------

--- Every line on show, oldest first within its place: the top mode and the phone keep theirs flat in the stack.
function EventFeed._all_lines(self): { any }
	local out = {}
	for _, c in ipairs(self._stack.children) do
		if c:get_meta("kind", "") == "line" then
			table.insert(out, c)
		end
	end
	for _, key in EventFeed.GROUPS do
		for _, c in ipairs(self._groups[key].lines.children) do
			table.insert(out, c)
		end
	end
	return out
end

function EventFeed.toast(self, category: number, text: string, _icon_name: string?, seconds: number?)
	local ctx = self.ctx
	if text == nil or string.match(text, "^%s*$") then
		return
	end
	local group = EventFeed.group_of(category)
	local now = msec()
	local prev = self._recent[text]
	if prev ~= nil and not prev.node._freed and not prev.node:has_meta("leaving") and now - prev.msec < EventFeed.FOLD_MS then
		prev.count += 1
		prev.msec = now
		prev.label:set_text(EventFeed.folded(text, prev.count))
		prev.node:set_meta("expire", now + EventFeed.life_of(group, ctx.compact) * 1000.0)
		return
	end
	local flat = self:_one_line() or self.top_mode
	if self:_one_line() and not self.top_mode then
		-- one line: a newer one takes its place, except that word from afar never pushes out a danger barely seen
		for _, c in ipairs(self:_all_lines()) do
			if not c:has_meta("leaving") then
				if group == "word" and c:get_meta("group", "") == "danger" and now - c:get_meta("born", 0) < 2000 then
					return
				end
				if c.parent ~= nil then
					c.parent:remove_child(c) -- (swapped in place: the line never jumps)
				end
				c:queue_free()
			end
		end
	end
	local line, label = self:_make_line(group, text)
	line:set_meta("expire", now + EventFeed.life_of(group, ctx.compact, seconds) * 1000.0)
	line:set_meta("kind", "line")
	line:set_meta("group", group)
	line:set_meta("born", now)
	if flat then
		self._stack:add_child(line)
	else
		self._groups[group].lines:add_child(line)
	end
	self._recent[text] = { node = line, count = 1, msec = now, label = label }
	UICtx.pop_in(line, 0.0, 1.0, 0.18, true)
	self:_trim()
	self:_sync_groups()
end

--- One line: a thin flat strip, its group's small mark and the words. On a finger it swallows taps (they would otherwise
--- order an attack underneath), and a tap sends it away.
function EventFeed._make_line(self, group: string, text: string): (any, any)
	local ctx = self.ctx
	local T = UITheme
	local plate = W.Panel.new()
	plate:add_theme_stylebox_override("panel", T.flat(T.GLASS, T.R_SM, T.CLEAR, 0, 8.0, 3.0))
	plate:set_mouse_filter(if ctx.touch then W.MOUSE_STOP else W.MOUSE_IGNORE)
	if ctx.touch then
		plate.gui_input:Connect(function(e)
			if e.kind == "button" and e.button == 1 and not e.pressed then
				self:_remove(plate, true)
			end
		end)
	end
	local row = T.hbox(6)
	row:set_mouse_filter(W.MOUSE_IGNORE)
	plate:add_child(row)
	local col = if group == "danger" then T.RED elseif group == "gain" then T.GOLD else T.TEXT_3
	local mark = T.label(EventFeed.GROUP_MARK[group], 13, 800, col)
	mark.size_flags_vertical = W.SHRINK_BEGIN
	row:add_child(mark)
	local phone = self:_one_line() and not self.top_mode
	local label = T.label(text, if phone then EventFeed.PHONE_FONT else 13, 500, T.TEXT)
	local w = (self._line_w or EventFeed.LOG_W) - 16.0 - 18.0
	if phone then
		-- one line, ending in "…" when it runs long
		label.text_overrun_behavior = W.OVERRUN_ELLIPSIS
		label:set_min_size(Vector2.new(math.min(T.measure_text(text, EventFeed.PHONE_FONT, 500) + 2.0, w), 0))
		plate.size_flags_horizontal = W.SHRINK_BEGIN
	else
		label:set_autowrap(true)
		label:set_min_size(Vector2.new(w, 0))
	end
	label.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(label)
	return plate, label
end

function EventFeed._remove(self, node, fast: boolean?)
	if node._freed or node:has_meta("leaving") then
		return
	end
	node:set_meta("leaving", true)
	local t = node:create_tween()
	t:tween_property(node, "modulate:a", 0.0, if fast then 0.12 else 0.6)
	t:tween_callback(function()
		node:queue_free()
		self:_sync_groups()
	end)
end

--- Each group shows its heading only while it has a line; the log is headed by the age it is written in.
function EventFeed._sync_groups(self)
	if self.top_mode or self:_one_line() then
		for _, key in EventFeed.GROUPS do
			if self._groups[key].box.visible then
				self._groups[key].box:set_visible(false)
			end
		end
		if self._age_l.visible then
			self._age_l:set_visible(false)
		end
		return
	end
	local any = false
	for _, key in EventFeed.GROUPS do
		local g = self._groups[key]
		local has = false
		for _, c in ipairs(g.lines.children) do
			if not c._freed then
				has = true
				break
			end
		end
		any = any or has
		if g.box.visible ~= has then
			g.box:set_visible(has)
		end
	end
	if self._age_l.visible ~= any then
		self._age_l:set_visible(any)
	end
	if any then
		local name = self:_age_name()
		if name ~= self._age_shown then
			self._age_shown = name
			self._age_l:set_text(if name ~= "" then name else "DISPATCHES")
		end
	end
end

--- The age the war is in, for the log's head ("" before play).
function EventFeed._age_name(self): string
	local s = self.ctx.state
	if s == nil or s.eras == nil or s.playing_since == nil or s.playing_since < 0 or self.ctx.render_tick == nil then
		return ""
	end
	local Eras = UICtx.data("Eras")
	return string.upper(Eras.NAMES[Eras.index(self.ctx:render_tick() - s.playing_since, s.eras)] or "")
end

function EventFeed._trim(self)
	-- Word goes first, then gains: danger is what stays on the screen.
	local ctx = self.ctx
	local most = if self.top_mode then EventFeed.MAX_NOTICES elseif self:_one_line() then 1 else EventFeed.MAX_LINES
	local lines = {}
	for _, c in ipairs(self:_all_lines()) do
		if not c:has_meta("leaving") then
			table.insert(lines, c)
		end
	end
	local rank = { word = 1, gain = 2, danger = 3 }
	local guard = 0
	while #lines > most and guard < 12 do
		guard += 1
		local at = 1
		for i, c in lines do
			if rank[c:get_meta("group", "word")] < rank[lines[at]:get_meta("group", "word")] then
				at = i
			end
		end
		local c = table.remove(lines, at)
		if c.parent ~= nil then
			c.parent:remove_child(c)
		end
		c:queue_free()
	end
end

-- ---------------------------------------------------------------------------------------------
-- Letters
-- ---------------------------------------------------------------------------------------------

--- A pact offered: its letter, whose seal melts with the offer.
function EventFeed.alliance_request(self, from_id: number)
	local ctx = self.ctx
	self:_letter(from_id, from_id, {
		text = "asks for your seal on a pact",
		row_text = "asks your seal",
		yes = "Seal",
		no = "Refuse",
		on_yes = function()
			ctx:send({ type = "ally_reply", target = from_id, accept = true })
		end,
		on_no = function()
			ctx:send({ type = "ally_reply", target = from_id, accept = false })
		end,
		tick_start = ctx:render_tick(),
		span = UITheme.core("Rules").ALLY_REQUEST_TICKS,
	})
end

--- A pact in its last ALLIANCE_EXTEND_WINDOW_TICKS: the letter answers with ally_extend (renewed once both asked). The
--- seal melts with the pact.
function EventFeed.alliance_renewal(self, other: number, expires_at: number, other_asked: boolean)
	local ctx = self.ctx
	local window = UITheme.core("Rules").ALLIANCE_EXTEND_WINDOW_TICKS
	self:_letter(-other, other, {
		text = if other_asked then "asks to hold the oath longer" else "your pact is near its end",
		row_text = if other_asked then "would keep it" else "pact near its end",
		yes = "Keep it",
		no = "Let it end",
		on_yes = function()
			ctx:send({ type = "ally_extend", target = other })
		end,
		on_no = function() end,
		tick_start = expires_at - window,
		span = window,
	})
end

function EventFeed.close_renewal(self, other: number)
	self:close_request(-other)
end

function EventFeed.has_renewal_card(self, other: number): boolean
	return self._cards[-other] ~= nil
end

--- The seal: a disc in the sender's colour that shrinks to nothing as the time runs out.
function EventFeed._seal(_self, col: any, px: number): (any, any)
	local T = UITheme
	local box = W.Control.new()
	box:set_mouse_filter(W.MOUSE_IGNORE)
	box:set_min_size(Vector2.new(px, px))
	box.size_flags_vertical = W.SHRINK_CENTER
	local wax = W.Panel.new()
	wax:set_mouse_filter(W.MOUSE_IGNORE)
	wax:add_theme_stylebox_override("panel", T.flat(col, 999))
	wax:set_anchors(0, 0, 1, 1)
	wax:set_offsets(0, 0, 0, 0)
	box:add_child(wax)
	return box, wax
end

function EventFeed._letter(self, key: number, owner_id: number, spec: { [string]: any })
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	if s == nil or self._cards[key] ~= nil or self.letters_off then
		return
	end
	local o = s:get_owner(owner_id)
	if o == nil then
		return
	end
	local wax_col = T.owner_ui_color(o.color)
	local phone = ctx.compact
	local card = GlassPanel.new(if phone then 8.0 else 12.0, if phone then 0.0 else 10.0, T.R_SM, true, 14)
	card:set_meta("kind", "card")
	card.size_flags_horizontal = if phone then W.SHRINK_BEGIN else W.SHRINK_END
	local bh = if ctx.touch then 44.0 else 34.0
	local seal, wax = self:_seal(wax_col, if phone then EventFeed.SEAL_PX_PHONE else EventFeed.SEAL_PX)
	local accept = T.button(spec.yes, "PrimaryButton", "", bh)
	accept:set_font_size(13)
	local decline = T.button(spec.no, "GlassButton", "", bh)
	decline:set_font_size(13)
	if phone then
		-- one row: seal, who and what, the two answers
		local row = T.hbox(6)
		card:add_child(row)
		row:add_child(seal)
		local nl = T.label(o.name, 13, 700)
		nl.text_overrun_behavior = W.OVERRUN_ELLIPSIS
		nl:set_min_size(Vector2.new(math.min(T.measure_text(o.name, 13, 700) + 2.0, 100.0), 0))
		nl.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(nl)
		local wl = T.label(spec.row_text, EventFeed.PHONE_FONT, 500, T.TEXT_2)
		wl.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(wl)
		row:add_child(accept)
		row:add_child(decline)
	else
		local v = T.vbox(8)
		card:add_child(v)
		local head = T.hbox(10)
		head:add_child(seal)
		local tv = T.vbox(0)
		tv.size_flags_horizontal = W.EXPAND_FILL
		tv:add_child(T.caption("A letter from", 11, T.TEXT_3))
		local nl = T.label(o.name, 14, 700)
		nl.text_overrun_behavior = W.OVERRUN_ELLIPSIS
		nl:set_min_size(Vector2.new(170, 0))
		tv:add_child(nl)
		tv:add_child(T.label(spec.text, 12, 500, T.TEXT_2))
		head:add_child(tv)
		v:add_child(head)
		local btns = T.hbox(8)
		accept.size_flags_horizontal = W.EXPAND_FILL
		decline.size_flags_horizontal = W.EXPAND_FILL
		btns:add_child(accept)
		btns:add_child(decline)
		v:add_child(btns)
	end
	accept.pressed:Connect(function()
		spec.on_yes()
		self:close_request(key)
	end)
	decline.pressed:Connect(function()
		spec.on_no()
		self:close_request(key)
	end)
	card:set_meta("tick_start", spec.tick_start)
	card:set_meta("span", spec.span)
	card:set_meta("owner_name", o.name)
	card:set_meta("wax", wax)
	self._cards[key] = card
	self._letters:add_child(card)
	UICtx.pop_in(card, 0.0, 1.0, 0.2, true)
end

function EventFeed.close_request(self, from_id: number)
	local card = self._cards[from_id]
	self._cards[from_id] = nil
	if card ~= nil then
		self:_remove(card)
	end
end

function EventFeed.close_all_requests(self)
	local ids = {}
	for id in pairs(self._cards) do
		table.insert(ids, id)
	end
	for _, id in ipairs(ids) do
		self:close_request(id)
	end
end

function EventFeed.has_request_card(self, from_id: number): boolean
	return self._cards[from_id] ~= nil
end

--- Per frame.
function EventFeed.update(self, _delta: number)
	local now = msec()
	for _, c in ipairs(self:_all_lines()) do
		local e = c:get_meta("expire", nil)
		if e ~= nil and now > e then
			self:_remove(c)
		end
	end
	if not self.top_mode and not self:_one_line() and self._age_l.visible then
		self:_sync_groups()
	end
	-- The seals (drawn again when they melt a step).
	if next(self._cards) == nil then
		return
	end
	local tick = self.ctx:render_tick()
	local done = nil
	for from_id, card in pairs(self._cards) do
		if card._freed then
			done = done or {}
			table.insert(done, from_id)
		else
			local start = card:get_meta("tick_start", tick)
			local left = 1.0 - (tick - start) / math.max(card:get_meta("span", 1), 1)
			local k = math.clamp(math.floor(left * 24.0 + 0.999) / 24.0, 0.0, 1.0)
			if k ~= card:get_meta("melt", 2.0) then
				card:set_meta("melt", k)
				local wax = card:get_meta("wax", nil)
				if wax ~= nil then
					local m = (1.0 - (0.25 + 0.75 * k)) * 0.5
					wax:set_anchors(m, m, 1.0 - m, 1.0 - m)
					wax:set_offsets(0, 0, 0, 0)
				end
			end
			if left <= 0 then
				done = done or {}
				table.insert(done, from_id)
			end
		end
	end
	if done ~= nil then
		for _, id in ipairs(done) do
			self:close_request(id)
		end
	end
end

return EventFeed
