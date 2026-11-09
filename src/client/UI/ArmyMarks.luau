--!nonstrict
-- A depth match's armies on the map (docs/DEPTH_DESIGN.md Phase 5): a banner where each army stands, its troops on a
-- pill beside it. Yours gold, a realm at war with you red, the rest grey; a siege shows its seconds left. A press on one
-- of yours readies its march (a levy: the next click on the map says where, UI/UIInteract.army_aim) or opens your Realm
-- (an army on a front). Only what is on the screen is drawn, at most MAX.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local UICtx = require("./UICtx")
local FrameKit = require("./FrameKit")

local ArmyMarks = W.class(W.Control)

ArmyMarks.MAX = 48
ArmyMarks.BADGE = 30
ArmyMarks.BADGE_PHONE = 26

function ArmyMarks.new(c: any, ui: any)
	local self = setmetatable({}, ArmyMarks.__mt)
	W.Control._init(self)
	self.ctx = c
	self.ui = ui
	self._marks = {}
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	return self
end

--- The armies to draw: { ar, tone ("mine" / "foe" / "other") }, yours first. Pure but for the mirrors.
function ArmyMarks.list(gs: any, me: number): { { any } }
	local ds = gs and gs.depth
	local out = {}
	if ds == nil then
		return out
	end
	for _, ar in ds.armies do
		local tone = if ar.owner == me then "mine" elseif me ~= 0 and ds:at_war(me, ar.owner) then "foe" else "other"
		table.insert(out, { ar, tone })
	end
	table.sort(out, function(a, b)
		local ra = if a[2] == "mine" then 0 elseif a[2] == "foe" then 1 else 2
		local rb = if b[2] == "mine" then 0 elseif b[2] == "foe" then 1 else 2
		if ra ~= rb then
			return ra < rb
		end
		return a[1].aid < b[1].aid
	end)
	return out
end

function ArmyMarks._mark(self, i: number): any
	local m = self._marks[i]
	if m ~= nil then
		return m
	end
	local T = UITheme
	local node = W.Control.new()
	node.name = "ArmyMark" .. i
	node:set_mouse_filter(W.MOUSE_STOP)
	self:add_child(node)
	local badge = FrameKit.badge(ArmyMarks.BADGE)
	node:add_child(badge.node)
	local pill = FrameKit.slate(0.9)
	pill:set_mouse_filter(W.MOUSE_IGNORE)
	local text = T.label("", 12, 700, T.TEXT)
	text:set_anchors(0, 0, 1, 1)
	text:set_offsets(6, 0, -6, 0)
	text.vertical_alignment = W.VALIGN_CENTER
	pill:add_child(text)
	node:add_child(pill)
	m = { node = node, badge = badge, pill = pill, text = text, aid = 0, mine = false }
	FrameKit.on_click(node, function()
		self:_pressed(m)
	end)
	self._marks[i] = m
	return m
end

function ArmyMarks._pressed(self, m: any)
	local ctx = self.ctx
	if not m.mine or m.aid == 0 then
		return
	end
	local s = ctx.state
	local ar = s and s.depth and s.depth.armies[m.aid]
	if ar == nil then
		return
	end
	if ar.mode == "march" and self.ui ~= nil and self.ui.interact ~= nil then
		self.ui.interact.army_aim = ar.aid
		ctx:sfx("click", -6.0)
		if self.ui._on_notice ~= nil then
			self.ui:_on_notice("Click the land your army marches on. Right-click calls it off.", 0)
		end
	elseif self.ui ~= nil and self.ui.open_realm ~= nil then
		self.ui:open_realm()
	end
end

function ArmyMarks.update(self, _delta: number)
	if not self:is_visible_in_tree() then
		return
	end
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	local list = ArmyMarks.list(s, ctx:me())
	local px = if ctx.compact then ArmyMarks.BADGE_PHONE else ArmyMarks.BADGE
	local vp = ctx.vp
	local used = 0
	for _, it in list do
		if used >= ArmyMarks.MAX then
			break
		end
		local ar, tone = it[1], it[2]
		local raw = ctx:world_call("screen_pos_of_tile", { ar.tile })
		if typeof(raw) ~= "Vector2" then
			continue
		end
		local p = ctx:to_logical(raw)
		if p.X < -px or p.Y < -px or p.X > vp.X + px or p.Y > vp.Y + px then
			continue
		end
		used += 1
		local m = self:_mark(used)
		m.aid = ar.aid
		m.mine = tone == "mine"
		local col = if tone == "mine" then T.GOLD elseif tone == "foe" then T.DIAL_RED else T.DIAL_MUTED
		m.badge.set("circle", col, if ar.state == "siege" then "fort" else "attack", nil)
		m.node:set_visible(true)
		local half = px * 0.5
		m.node:set_anchors(0, 0, 0, 0)
		m.node:set_offsets(p.X - half, p.Y - half, p.X + half, p.Y + half)
		m.badge.node:set_anchors(0, 0, 1, 1)
		m.badge.node:set_offsets(0, 0, 0, 0)
		local words = T.fmt_troops(ar.troops)
		if ar.state == "siege" then
			words ..= string.format(" · siege %ds", ar.siege_left)
		end
		m.text:set_text(words)
		local w = T.measure_text(words, 12, 700) + 14
		m.pill:set_anchors(0, 0, 0, 0)
		m.pill:set_offsets(px + 2, half - 10, px + 2 + w, half + 10)
	end
	for i = used + 1, #self._marks do
		self._marks[i].node:set_visible(false)
		self._marks[i].aid = 0
	end
end

return ArmyMarks
