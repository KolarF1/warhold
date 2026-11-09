--!nonstrict
-- Where you are attacked from (2026-11-03, the owner: indicators for where the attacks come in): one mark for each
-- nation marching into your land, at the front of its largest attack (the attack's anchor tile). On the map it is a
-- red hexagon with crossed swords and "Name · troops" beside it; when that front is off the screen the mark waits on
-- the screen's edge, on the line from the middle towards it, with an arrow pointing the way, and a press flies the
-- camera there. Marks on the map let clicks through (the land under them can still be fought for); marks on the edge
-- keep clear of the HUD's columns.
--
-- Pure: ThreatMarks.incoming(state, me) -> { { owner, tile, troops } } (largest first), ThreatMarks.edge_point(p, c, r)
-- (where the line from `c` to `p` leaves box `r`). UIRoot knows it as `threat_marks`; update(dt) per frame.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")

local ThreatMarks = W.class(W.Control)

--- The most marks on show (the largest attackers).
ThreatMarks.MAX = 6
--- (2026-11-09, the owner: a bigger sign of where an attack comes from: 38 / 28 before)
ThreatMarks.BADGE = 50
ThreatMarks.BADGE_PHONE = 36
--- A new attacker sounds the alarm, no more than once in this many seconds.
ThreatMarks.ALARM_GAP_S = 6.0
--- (2026-11-09, the owner: the alarm was spammy when a nation you attack pushes back; it is for someone actively
--- attacking you) No alarm for a nation you have marched on within this many seconds, and one alarm per attacker
--- within it.
ThreatMarks.ALARM_FORGET_S = 60.0
--- How far in from the screen's edge (and the HUD's columns) a waiting mark stands.
ThreatMarks.INSET = 34
--- Seconds between two reads of the attacks (the marks follow the camera every frame).
ThreatMarks.READ_S = 0.25

--- Every nation attacking `me` now: the anchor of its largest attack and all its troops in them, largest first. Pure.
function ThreatMarks.incoming(s: any, me: number): { any }
	local by: { [number]: any } = {}
	if s == nil or me == 0 then
		return {}
	end
	for _, a in s.attacks or {} do
		local tile = tonumber(a.anchor_tile) or -1
		if a.target == me and a.attacker ~= me and a.attacker ~= 0 and not a.retreating and tile >= 0 then
			local troops = tonumber(a.troops) or 0
			local r = by[a.attacker]
			if r == nil then
				by[a.attacker] = { owner = a.attacker, tile = tile, troops = troops, best = troops }
			else
				r.troops += troops
				if troops > r.best then
					r.best, r.tile = troops, tile
				end
			end
		end
	end
	local out = {}
	for _, r in by do
		table.insert(out, { owner = r.owner, tile = r.tile, troops = r.troops })
	end
	table.sort(out, function(x, y)
		if x.troops ~= y.troops then
			return x.troops > y.troops
		end
		return x.owner < y.owner
	end)
	return out
end

--- Where the line from `c` (inside box `r`) towards `p` leaves `r`. Pure.
function ThreatMarks.edge_point(p: Vector2, c: Vector2, r: any): Vector2
	local d = p - c
	local t = 1.0
	if d.X > 1e-6 then
		t = math.min(t, (r.x1 - c.X) / d.X)
	elseif d.X < -1e-6 then
		t = math.min(t, (r.x0 - c.X) / d.X)
	end
	if d.Y > 1e-6 then
		t = math.min(t, (r.y1 - c.Y) / d.Y)
	elseif d.Y < -1e-6 then
		t = math.min(t, (r.y0 - c.Y) / d.Y)
	end
	return c + d * math.max(t, 0.0)
end

local function inside(p: Vector2, r: any): boolean
	return p.X >= r.x0 and p.X <= r.x1 and p.Y >= r.y0 and p.Y <= r.y1
end

function ThreatMarks.new(c: any)
	local self = setmetatable({}, ThreatMarks.__mt)
	W.Control._init(self)
	self.ctx = c
	self._acc = ThreatMarks.READ_S
	self._t = 0.0
	self._list = {}
	self._marks = {}
	--- Seconds the list is held as set (the Studio debug channel shows marks without a war: UIRoot.debug_marks).
	self.hold_s = 0.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	return self
end

function ThreatMarks._mark(self, i: number): any
	local m = self._marks[i]
	if m ~= nil then
		return m
	end
	local T = UITheme
	local node = W.Control.new()
	node.name = "ThreatMark" .. i
	node:set_mouse_filter(W.MOUSE_IGNORE)
	self:add_child(node)
	local badge = FrameKit.badge(ThreatMarks.BADGE)
	badge.set("hexagon", T.DIAL_RED, "attack", nil)
	node:add_child(badge.node)
	local arrow = T.icon_rect("chevron", 26.0, T.DIAL_RED)
	node:add_child(arrow)
	local pill = FrameKit.slate(0.92)
	pill:set_mouse_filter(W.MOUSE_IGNORE)
	local text = T.label("", 13, 700, T.TEXT)
	text:set_anchors(0, 0, 1, 1)
	text:set_offsets(8, 0, -8, 0)
	text.vertical_alignment = W.VALIGN_CENTER
	pill:add_child(text)
	node:add_child(pill)
	m = { node = node, badge = badge, arrow = arrow, pill = pill, text = text, tile = -1 }
	FrameKit.on_click(node, function()
		if m.tile >= 0 then
			self.ctx:sfx("click", -8.0)
			self.ctx:world_call("focus_tile", { m.tile, -1.0, 0.8 })
		end
	end)
	self._marks[i] = m
	return m
end

--- The box a waiting mark stays inside: the screen less its edge and the HUD's columns.
function ThreatMarks._room(self): any
	local ctx = self.ctx
	local r = ctx.reserved_top_left
	local l = FrameRules.layout(ctx.vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), { log_h = ctx.log_h })
	local m = ThreatMarks.INSET
	local x0 = ctx.insets.x + m
	local y0 = math.max(l.strip.y1, l.alerts.y1) + m
	local x1, y1
	if ctx.compact then
		x1 = l.alerts_room.x0 - m
		y1 = math.min(l.presets.y0, l.actions.y0) - m
	else
		x1 = l.outliner.x0 - m
		y1 = ctx.vp.Y - ctx.insets.w - m
	end
	return FrameRules.box(x0, y0, math.max(x0 + 1, x1), math.max(y0 + 1, y1)), l
end

--- Whether the incoming list `list` (ThreatMarks.incoming) is news worth the alarm at `now` (seconds), and updates
--- `mem` ({ hit = owner -> when I last marched on them, heard = owner -> when they last set it off }) from the state's
--- attacks: a nation I am fighting (marching on, or did within ALARM_FORGET_S) is pushing back, not news; an attacker
--- already heard within ALARM_FORGET_S isn't news either. Pure.
function ThreatMarks.alarm_due(s: any, me: number, list: { any }, mem: any, now: number): boolean
	mem.hit = mem.hit or {}
	mem.heard = mem.heard or {}
	for _, a in (if s ~= nil then s.attacks else nil) or {} do
		if a.attacker == me and a.target ~= nil and a.target ~= 0 then
			mem.hit[a.target] = now
		end
	end
	local due = false
	local forget = ThreatMarks.ALARM_FORGET_S
	for _, m in list do
		local fought = now - (mem.hit[m.owner] or -math.huge) < forget
		local heard = now - (mem.heard[m.owner] or -math.huge) < forget
		if not fought and not heard then
			due = true
		end
		-- (still marching on me: the minute runs from their last sighting)
		mem.heard[m.owner] = now
	end
	return due
end

function ThreatMarks._read(self)
	local ctx = self.ctx
	self._list = if ctx:alive_player() then ThreatMarks.incoming(ctx.state, ctx:me()) else {}
	-- (2026-11-09, the owner: a slight alarm when someone attacks you, not when a nation you attack pushes back)
	self._mem = self._mem or {}
	local now = os.clock()
	local due = ThreatMarks.alarm_due(ctx.state, ctx:me(), self._list, self._mem, now)
	if due and now - (self._alarm_at or -math.huge) >= ThreatMarks.ALARM_GAP_S then
		self._alarm_at = now
		ctx:sfx("under_attack", -6.0)
	end
end

function ThreatMarks._place(self)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	local n = math.min(#self._list, ThreatMarks.MAX)
	local room, l = nil, nil
	if n > 0 then
		room, l = self:_room()
	end
	local px = if ctx.compact then ThreatMarks.BADGE_PHONE else ThreatMarks.BADGE
	local pulse = if T.reduced_motion then 1.0 else 0.8 + 0.2 * math.sin(self._t * 5.0)
	for i = 1, math.max(n, #self._marks) do
		local m = if i <= n then self:_mark(i) else self._marks[i]
		if i > n then
			m.node:set_visible(false)
			m.tile = -1
			continue
		end
		local it = self._list[i]
		local raw = ctx:world_call("screen_pos_of_tile", { it.tile })
		if typeof(raw) ~= "Vector2" then
			m.node:set_visible(false)
			continue
		end
		local p = ctx:to_logical(raw)
		local centre = Vector2.new((room.x0 + room.x1) * 0.5, (room.y0 + room.y1) * 0.5)
		local on_map = inside(p, room)
		local at = if on_map then p else ThreatMarks.edge_point(p, centre, room)
		if not on_map and not ctx.compact then
			-- (a waiting mark never sits on the send panel and the clock, nor on the log)
			for _, b in { l.send, l.clock, if (ctx.log_h or 0) > 0 then l.log else nil } do
				if b ~= nil and at.X >= b.x0 - ThreatMarks.INSET and at.Y >= b.y0 - ThreatMarks.INSET and at.X <= b.x1 + ThreatMarks.INSET then
					at = Vector2.new(at.X, math.min(at.Y, b.y0 - ThreatMarks.INSET))
				end
			end
		end
		m.tile = it.tile
		m.node:set_visible(true)
		m.node:set_mouse_filter(if on_map then W.MOUSE_IGNORE else W.MOUSE_STOP)
		m.node:set_modulate_a(pulse)
		local half = px * 0.5
		m.node:set_anchors(0, 0, 0, 0)
		m.node:set_offsets(at.X - half, at.Y - half, at.X + half, at.Y + half)
		m.badge.node:set_anchors(0, 0, 1, 1)
		m.badge.node:set_offsets(0, 0, 0, 0)
		-- the arrow points from the mark to the front (off the screen), beyond the badge
		m.arrow:set_visible(not on_map)
		if not on_map then
			local d = p - at
			local ang = math.atan2(d.Y, d.X)
			local k = half + 16
			local ax, ay = half + math.cos(ang) * k, half + math.sin(ang) * k
			m.arrow:set_anchors(0, 0, 0, 0)
			m.arrow:set_offsets(ax - 13, ay - 13, ax + 13, ay + 13)
			m.arrow:set_rotation(ang)
		end
		-- the words, on the side away from the screen's edge
		local words = string.format("%s · %s", s:owner_name(it.owner), T.fmt_troops(it.troops))
		m.text:set_text(words)
		local w = T.measure_text(words, 13, 700) + 18
		local left = at.X > (room.x0 + room.x1) * 0.5 and not on_map
		m.pill:set_anchors(0, 0, 0, 0)
		if left then
			m.pill:set_offsets(-w - 6, half - 12, -6, half + 12)
		else
			m.pill:set_offsets(px + 6, half - 12, px + 6 + w, half + 12)
		end
	end
end

--- What of it is on screen (logical px): the waiting marks only (the ones on the map are part of it).
function ThreatMarks.count(self): number
	return math.min(#self._list, ThreatMarks.MAX)
end

function ThreatMarks.update(self, delta: number)
	if not self:is_visible_in_tree() then
		return
	end
	self._t += delta
	self._acc += delta
	self.hold_s = math.max(0.0, self.hold_s - delta)
	if self._acc >= ThreatMarks.READ_S and self.hold_s <= 0.0 then
		self._acc = 0.0
		self:_read()
	end
	self:_place()
end

return ThreatMarks
