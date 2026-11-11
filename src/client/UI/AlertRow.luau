--!nonstrict
-- The strategy frame's alerts (2026-11-03; they replaced the command dial's toasts as the main news): badges under the
-- top strip whose shape and colour say how urgent they are (FrameRules.alert_badges): a red hexagon is danger (an attack
-- on you, a warhead coming, a building lost), an amber diamond a choice waiting (a doctrine to pick, a pact offered,
-- a pact its partner would keep), a green circle something now open to you (a building you can afford since its age
-- came, an edict ready). Repeats merge into one badge with a count. A left-click goes there (the camera to the place,
-- the choice opened), a right-click dismisses (a new item brings the badge back), a hover shows every line. A short
-- line beside the badges says the most urgent one. A phone stacks them down the right edge; a tap goes there.
--
-- Read from the match, never from the news (the news goes to the outliner's LOG). UIRoot knows it as `alerts`.
-- Methods: refresh(), apply_layout(), push(item, seconds) (an item that stands a while: a building lost), on_built(kind),
-- rect_of(kind) (a badge's rect: the tutorial and counsel point at the doctrine's), count(), rects(); update(dt).

local UICtx = require("./UICtx") :: any
local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")

local AlertRow = W.class(W.Control)

--- How long a pushed item stands (a building lost), and a "you can build" one.
AlertRow.PUSH_S = 30
AlertRow.AFFORD_S = 45
AlertRow.TIER_WORD = { danger = "Danger", choice = "Your choice", available = "Open to you" }

local function UIRules(): any
	return UICtx.mod("UIRules")
end

function AlertRow.new(c: any, ui: any)
	local self = setmetatable({}, AlertRow.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.ui = ui
	self.badges = {}
	self._dismissed = {}
	self._timed = {}
	self._could = {}
	self._acc = 0.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self._slots = {}
	for i = 1, math.max(FrameRules.ALERTS_MAX, FrameRules.ALERTS_MAX_PHONE) do
		local b = W.Button.new("", "GhostButton")
		b.name = "Alert" .. i
		b:set_flat(true)
		for _, st in ipairs(W.BUTTON_STATES or {}) do
			b:add_theme_stylebox_override(st, T.empty_box())
		end
		b:set_min_size(Vector2.new(FrameRules.ALERT, FrameRules.ALERT))
		local shape = FrameKit.badge(FrameRules.ALERT)
		shape.node:set_anchors(0, 0, 1, 1)
		b:add_child(shape.node)
		local rec = { button = b, shape = shape, badge = nil }
		b.pressed:Connect(function()
			self:_press(rec)
		end)
		FrameKit.on_click(b, nil, function()
			if rec.badge ~= nil then
				self:dismiss(rec.badge)
			end
		end)
		b.mouse_entered:Connect(function()
			if rec.badge ~= nil then
				c:show_hint(b, self:card(rec.badge))
			end
		end)
		b.mouse_exited:Connect(function()
			c:hide_hint(b)
		end)
		self:add_child(b)
		b:set_visible(false)
		self._slots[i] = rec
	end
	-- the line: the most urgent one, in words
	local line = FrameKit.slate(0.9)
	line:set_mouse_filter(W.MOUSE_IGNORE)
	local edge = FrameKit.bar(FrameKit.DANGER)
	edge:set_anchors(0, 0, 0, 1)
	edge:set_offsets(0, 0, 3, 0)
	line:add_child(edge)
	self._line_edge = edge
	local lt = T.label("", 13, 700, T.TEXT)
	lt:set_anchors(0, 0, 1, 1)
	lt:set_offsets(12, 0, -8, 0)
	lt.vertical_alignment = W.VALIGN_CENTER
	lt.clip_text = true
	lt.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	line:add_child(lt)
	self._line = line
	self._line_text = lt
	self:add_child(line)
	line:set_visible(false)
	return self
end

-- ---------------------------------------------------------------------------------------------
-- The items, from the match
-- ---------------------------------------------------------------------------------------------

--- An item that stands `seconds` (a building lost): { key, kind, line, focus_tile?, owner? }.
function AlertRow.push(self, item: any, seconds: number?)
	self._timed[item.key] = { item = item, until_ms = UICtx.msec() + (seconds or AlertRow.PUSH_S) * 1000 }
	self._dismissed[item.key] = nil
	self:refresh()
end

--- A new match: nothing carried over.
function AlertRow.reset(self)
	table.clear(self._dismissed)
	table.clear(self._timed)
	table.clear(self._could)
	self.badges = {}
	self:_fill()
end

--- A building of `kind` went up: its "you can build" alert has done its work.
function AlertRow.on_built(self, kind: string)
	self._timed["afford:" .. kind] = nil
	self:refresh()
end

--- Every item now. Pure but for the match it reads.
function AlertRow.collect(self): { any }
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	local me = ctx:me()
	local out = {}
	if s == nil or me == 0 or not ctx:alive_player() then
		return out
	end
	local Defs = UICtx.core("Defs")
	local now = ctx:render_tick()
	local rate = Defs.TICK_RATE
	local mine = math.max((ctx:my() or {}).troops or 1, 1)
	for uid, n in s.nukes or {} do
		local to = tonumber(n.to_tile) or -1
		if to >= 0 and n.owner ~= me and s:tile_owner(to) == me then
			local left = math.max(0, math.ceil(((tonumber(n.launch_tick) or 0) + (tonumber(n.flight_ticks) or 0) - now) / rate))
			local what = (Defs.NUKE_TITLES and Defs.NUKE_TITLES[n.kind]) or "Warhead"
			table.insert(out, { key = "nuke:" .. uid, kind = "nuke", urgency = 300 + math.max(0, 30 - left), focus_tile = to, owner = n.owner, line = string.format("%s from %s lands in %s", what, s:owner_name(n.owner), T.fmt_time(left)) })
		end
	end
	for aid, a in s.attacks or {} do
		if a.target == me and a.attacker ~= me and s:get_owner(a.attacker) ~= nil then
			local troops = tonumber(a.troops) or 0
			table.insert(out, { key = "atk:" .. aid, kind = "attack_in", urgency = 200 + math.min(troops / mine, 9), focus_tile = a.anchor_tile, owner = a.attacker, line = string.format("%s pushes into your land · %s", s:owner_name(a.attacker), T.fmt_troops(troops)) })
		end
	end
	local row = UICtx.mod("DoctrineDraft").open_row(s, me)
	local draft_open = self.ui ~= nil and self.ui.draft ~= nil and self.ui.draft.panel.visible
	if row ~= nil and s.phase == Defs.PHASE_PLAYING and not draft_open and not ctx.draft_held then
		local left = math.max(0, math.ceil((row[7] - now) / rate))
		local what = if s.depth ~= nil then "An idea is ready to choose" else "A doctrine is ready to pick"
		table.insert(out, { key = "draft:" .. row[2], kind = "draft", urgency = 150 + math.max(0, 60 - left), line = string.format("%s · auto-picks in %s", what, T.fmt_time(left)) })
	end
	for key in s.requests or {} do
		local from, to = key // 1024, key % 1024
		if to == me and from ~= me and s:get_owner(from) ~= nil then
			table.insert(out, { key = "req:" .. from, kind = "request_in", urgency = 150, owner = from, line = string.format("%s offers a pact", s:owner_name(from)) })
		end
	end
	-- (a depth match: peace offered to you, answered in the sender's window)
	if s.depth ~= nil then
		local DepthState = UICtx.core("DepthState")
		for from, r in s.depth.peace_in do
			if s:get_owner(from) ~= nil then
				table.insert(out, { key = "peace:" .. from, kind = "peace_in", urgency = 160, owner = from, line = string.format("%s offers peace: %s", s:owner_name(from), DepthState.offer_words(r.terms)) })
			end
		end
	end
	if type(s.allies_of) == "function" then
		for _, other in s:allies_of(me) do
			local ai = s:alliance_info(me, other)
			if ai ~= nil and ai.in_window and ai.other_asked and not ai.me_asked and ai.can_extend then
				table.insert(out, { key = "renew:" .. other, kind = "renewal", urgency = 120, owner = other, line = string.format("%s would keep your pact · it ends in %s", s:owner_name(other), T.fmt_time(math.ceil(ai.ticks_left / rate))) })
			end
		end
	end
	-- edicts ready (your doctrines' active orders)
	local Draft = UICtx.mod("DoctrineDraft")
	local ready_at = if s.edict_ready ~= nil then (s.edict_ready[me] or 0) else 0
	local running = if s.edict_buff ~= nil then (s.edict_buff[me] or 0) else 0
	if s.phase == Defs.PHASE_PLAYING and ready_at <= now and running <= now then
		for name in Draft.my_edicts(s, me) do
			local word = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
			table.insert(out, { key = "edict:" .. name, kind = "edict", urgency = 50, edict = name, line = string.format("%s is ready to use", word) })
		end
	end
	-- a building newly within reach (its age came, or the gold did): once, until built or a while has passed
	if ctx.rules ~= nil then
		local R = UIRules()
		local kinds = table.clone(R.BUILD_KINDS)
		for _, k in R.ARSENAL_BUILD do
			if not ctx.rules:arsenal_locked(k) then
				table.insert(kinds, k)
			end
		end
		for _, k in kinds do
			local ok = ctx.rules:availability(k).ok == true
			if ok and self._could[k] == false and ctx.rules:owned(k) == 0 then
				self._timed["afford:" .. k] = { item = { key = "afford:" .. k, kind = "afford", urgency = 10, build = k, icon = k, line = string.format("You can build a %s", R.TITLES[k]) }, until_ms = UICtx.msec() + AlertRow.AFFORD_S * 1000 }
			end
			self._could[k] = ok
		end
	end
	local ms = UICtx.msec()
	for key, t in self._timed do
		if ms > t.until_ms then
			self._timed[key] = nil
		else
			table.insert(out, t.item)
		end
	end
	return out
end

function AlertRow.refresh(self)
	local ctx = self.ctx
	local items = self:collect()
	-- (a dismissed item that is gone forgets it was dismissed: the same key later is news again)
	local live = {}
	for _, it in items do
		live[it.key] = true
	end
	for key in self._dismissed do
		if not live[key] then
			self._dismissed[key] = nil
		end
	end
	local all = FrameRules.alert_badges(items, self._dismissed)
	local max = if ctx.compact then self._phone_fit or FrameRules.ALERTS_MAX_PHONE else FrameRules.ALERTS_MAX
	self.badges = FrameRules.fit_badges(all, max)
	self:_fill()
end

function AlertRow._fill(self)
	local ctx = self.ctx
	local n = #self.badges
	for i, rec in self._slots do
		local b = self.badges[i]
		rec.badge = b
		rec.button:set_visible(b ~= nil)
		if b ~= nil then
			rec.shape.set(b.shape, FrameKit.TIER_COLOUR[b.tier], b.icon, b.count)
		end
	end
	local top = self.badges[1]
	self._line:set_visible(top ~= nil and not ctx.compact)
	if top ~= nil then
		self._line_text:set_text(if top.count > 1 then string.format("%s (+%d)", top.line, top.count - 1) else top.line)
		self._line_edge:set_color(FrameKit.TIER_COLOUR[top.tier])
	end
	self:_place(n)
end

-- ---------------------------------------------------------------------------------------------
-- Acts
-- ---------------------------------------------------------------------------------------------

--- A badge's left-click: the camera to the place, or the choice opened.
function AlertRow.act(self, b: any)
	local ctx = self.ctx
	local ui = self.ui
	local k = b.kind
	ctx:sfx("click", -6.0)
	if k == "draft" then
		if ui ~= nil and ui.draft ~= nil then
			ui.draft:unfold()
		end
	elseif k == "request_in" or k == "renewal" or k == "peace_in" then
		if ui ~= nil and ui.select_owner ~= nil and (b.owner or 0) ~= 0 then
			ui:select_owner(b.owner)
		end
	elseif k == "edict" then
		local it = b.items[1]
		ctx:send({ type = "edict", kind = it.edict })
		ctx:sfx("confirm", -4.0)
		self._dismissed[it.key] = true
	elseif k == "afford" then
		local it = b.items[1]
		if ui ~= nil and ui.interact ~= nil then
			ui.interact:select_action(it.build)
		end
		self._dismissed[it.key] = true
	elseif (b.focus_tile or -1) >= 0 then
		ctx:world_call("focus_tile", { b.focus_tile, -1.0, 0.8 })
	elseif (b.owner or 0) ~= 0 then
		ctx:world_call("focus_owner", { b.owner })
	end
	self:refresh()
end

--- A badge pressed: it acts, and on a touch screen its card shows. The badge is held first: acting refreshes the row,
--- which can empty the slot (live 2026-11-10: 162 errors from a card asked of a slot that had just emptied).
function AlertRow._press(self, rec: any)
	local badge = rec.badge
	if badge == nil then
		return
	end
	self:act(badge)
	if self.ctx.touch then
		self.ctx:show_hint(rec.button, self:card(badge), true)
	end
end

--- A badge's right-click: gone until something new of its kind comes.
function AlertRow.dismiss(self, b: any)
	for _, it in b.items do
		self._dismissed[it.key] = true
	end
	self.ctx:sfx("close", -8.0)
	self.ctx:hide_hint()
	self:refresh()
end

--- A badge's card: every line it holds, and what the clicks do.
function AlertRow.card(self, b: any): { [string]: any }
	local lines = {}
	for i, l in b.lines do
		if i > 6 then
			table.insert(lines, string.format("and %d more", #b.lines - 6))
			break
		end
		table.insert(lines, l)
	end
	local how = if self.ctx.touch then "Tap: go there" else "Left-click: go there · right-click: dismiss"
	if b.kind == "edict" then
		how = if self.ctx.touch then "Tap: use it now" else "Left-click: use it now · right-click: dismiss"
	elseif b.kind == "afford" then
		how = if self.ctx.touch then "Tap: place one" else "Left-click: place one · right-click: dismiss"
	end
	return { title = AlertRow.TIER_WORD[b.tier] or "", body = table.concat(lines, "\n"), hint = how, hint_color = UITheme.DIAL_MUTED, hint_icon = "info" }
end

-- ---------------------------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------------------------

function AlertRow.apply_layout(self)
	self:refresh()
end

function AlertRow._place(self, n: number)
	local ctx = self.ctx
	local r = ctx.reserved_top_left
	local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), { alerts = n })
	self._layout = l
	local a = l.alerts
	if ctx.compact then
		local room = l.alerts_room
		self._phone_fit = math.max(1, math.floor((room.y1 - room.y0 + 6) / (FrameRules.ALERT + 6)))
	end
	for i, rec in self._slots do
		local x, y
		if ctx.compact then
			x, y = a.x0, a.y0 + (i - 1) * (FrameRules.ALERT + 6)
		else
			x, y = a.x0 + (i - 1) * (FrameRules.ALERT + FrameRules.ALERT_GAP), a.y0
		end
		FrameKit.place(rec.button, { x0 = x, y0 = y, x1 = x + FrameRules.ALERT, y1 = y + FrameRules.ALERT })
	end
	if not ctx.compact and n > 0 then
		local lx = a.x0 + n * (FrameRules.ALERT + FrameRules.ALERT_GAP)
		local w = math.min(FrameRules.ALERT_LINE_W, math.max(0, a.x1 - lx))
		FrameKit.place(self._line, { x0 = lx, y0 = a.y0 + 6, x1 = lx + w, y1 = a.y1 - 6 })
		self._line:set_visible(w >= 120)
	end
end

--- The rect of the badge of `kind` on show (the tutorial points at the doctrine's), or nil.
function AlertRow.rect_of(self, kind: string): Rect?
	for _, rec in self._slots do
		if rec.badge ~= nil and rec.badge.kind == kind and rec.button:is_visible_in_tree() then
			return rec.button:get_global_rect()
		end
	end
	return nil
end

function AlertRow.count(self): number
	return #self.badges
end

--- What of it is on screen (logical px).
function AlertRow.rects(self): { Rect }
	local out = {}
	if not self:is_visible_in_tree() then
		return out
	end
	for _, rec in self._slots do
		if rec.button.visible then
			table.insert(out, rec.button:get_global_rect())
		end
	end
	if self._line.visible then
		table.insert(out, self._line:get_global_rect())
	end
	return out
end

function AlertRow.update(self, delta: number)
	self._acc += delta
	if self._acc >= 0.5 then
		self._acc = 0.0
		if self:is_visible_in_tree() then
			self:refresh()
		end
	end
end

return AlertRow
