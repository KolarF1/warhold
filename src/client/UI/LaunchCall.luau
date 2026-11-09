--!nonstrict
-- The launch call (playtest 2026-11-08, the owner: make it plain when a warhead is fired, and by whom, without taking the
-- camera): a short red card down the right, beside the outliner (moved off the middle 2026-11-08), for every warhead that leaves a silo,
-- anywhere on the map: "RUSSIA'S GREAT WARHEAD FLIES AT FRANCE". One aimed at you says so ("AT YOU") and pulses. A
-- volley (a Cluster Warhead's shards, a second silo firing) adds to its card ("×3") instead of stacking more. A press
-- shows where it will fall; nothing moves the camera on its own. At most MAX cards; each lasts HOLD_S (12 s since 2026-11-08).
--
-- UIRoot knows it as `launch_call`; UIAdvisor.on_nuke_launched pushes each warhead. Methods: push(n), clear(),
-- apply_layout().

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local Defs = UICtx.core("Defs")

local LaunchCall = W.class(W.Control)

LaunchCall.MAX = 3
LaunchCall.HOLD_S = 12.0
--- A launch of the same shooter and kind within this many seconds joins the card already up.
LaunchCall.MERGE_S = 3.0
LaunchCall.GAP = 6.0

--- The card's words. `shooter`/`target` are names (target nil: open ground), `mine` the shooter is you, `at_me` the
--- target is you, `count` the warheads in the card. Pure.
function LaunchCall.text(shooter: string, what: string, target: string?, mine: boolean, at_me: boolean, count: number): string
	local whose = if mine then "YOUR" else string.upper(shooter) .. "'S"
	local whom = if at_me then "YOU" elseif target ~= nil then string.upper(target) else "OPEN GROUND"
	local s = string.format("%s %s FLIES AT %s", whose, string.upper(what), whom)
	if count > 1 then
		s ..= string.format(" ×%d", count)
	end
	return s
end

function LaunchCall.new(c: any)
	local self = setmetatable({}, LaunchCall.__mt)
	W.Control._init(self)
	self.ctx = c
	self._cards = {} -- { panel, label, key, count, left, tile, at_me }
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:set_process(true)
	return self
end

function LaunchCall._make(self, at_me: boolean): any
	local T = UITheme
	local panel = GlassPanel.new(10.0, 5.0, T.R_MD, true, 6)
	panel:set_tint(T.GLASS_SOLID)
	panel:set_border(if at_me then T.RED else T.c(T.RED, 0.55))
	panel:set_mouse_filter(W.MOUSE_STOP)
	local row = T.hbox(8)
	panel:add_child(row)
	local icon = T.icon_rect("atom", 14.0, T.RED)
	icon.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(icon)
	local label = T.label("", 12, 700, if at_me then T.RED else T.TEXT)
	label.size_flags_vertical = W.SHRINK_CENTER
	row:add_child(label)
	self:add_child(panel)
	return panel, label
end

--- A warhead left its silo (GameState.nukes record). Flat shots (shells, raids, slugs) are not called.
function LaunchCall.push(self, n: any)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or n == nil then
		return
	end
	local me = ctx:me()
	local target = if n.to_tile ~= nil and n.to_tile >= 0 then s:tile_owner(n.to_tile) else 0
	local at_me = me ~= 0 and target == me
	local key = tostring(n.owner) .. ":" .. tostring(n.kind) .. ":" .. tostring(target)
	-- (a Cluster Warhead's shards are the one strike already called: never a card each)
	local kind = if n.kind == Defs.N_WARHEAD then Defs.N_MIRV else n.kind
	for _, c in self._cards do
		if c.key == key and LaunchCall.HOLD_S - c.left <= LaunchCall.MERGE_S then
			if n.kind ~= Defs.N_WARHEAD then
				c.count += 1
			end
			c.left = LaunchCall.HOLD_S
			self:_write(c)
			return
		end
	end
	if n.kind == Defs.N_WARHEAD then
		return -- (a shard with no card of its Cluster Warhead: it came with it)
	end
	if #self._cards >= LaunchCall.MAX then
		local old = table.remove(self._cards, 1)
		old.panel:queue_free()
	end
	local panel, label = self:_make(at_me)
	local c = {
		panel = panel,
		label = label,
		key = key,
		count = 1,
		left = LaunchCall.HOLD_S,
		tile = n.to_tile,
		at_me = at_me,
		shooter = s:owner_name(n.owner),
		mine = me ~= 0 and n.owner == me,
		target = if target > 0 then s:owner_name(target) else nil,
		what = Defs.NUKE_TITLES[kind] or "Warhead",
	}
	UICtx.mod("FrameKit").on_click(panel, function()
		if c.tile ~= nil and c.tile >= 0 and ctx.world ~= nil and type(ctx.world.focus_tile) == "function" then
			ctx.world:focus_tile(c.tile, -1.0, 0.6)
		end
	end)
	table.insert(self._cards, c)
	self:_write(c)
	UICtx.pop_in(panel, 0.0, 0.92, 0.2, true)
	self:apply_layout()
end

function LaunchCall._write(self, c: any)
	c.label:set_text(LaunchCall.text(c.shooter, c.what, c.target, c.mine, c.at_me, c.count))
	c.panel:reset_size()
	-- (placed again: a card that grew, "×3", kept its old place and ran past the plate's right edge; playtest 2026-11-08)
	self:apply_layout()
end

function LaunchCall.clear(self)
	for _, c in self._cards do
		c.panel:queue_free()
	end
	table.clear(self._cards)
end

--- Off to the side (playtest 2026-11-08: less in the way): down the right, beside the outliner's column, newest on top;
--- a phone's under its top bar at the right edge.
function LaunchCall.apply_layout(self)
	local ctx = self.ctx
	local FR = UICtx.mod("FrameRules")
	local rr = ctx.reserved_top_left
	local lay = FR.layout(ctx.vp, ctx.compact, ctx.insets, FR.box(rr.Min.X, rr.Min.Y, rr.Max.X, rr.Max.Y), {})
	local right = if lay.outliner ~= nil and not ctx.compact then lay.outliner.x0 - 10.0 else ctx.vp.X - ctx.insets.z - 8.0
	local y = lay.strip.y1 + 8.0 + 32.0 + 8.0
	for i = #self._cards, 1, -1 do
		local c = self._cards[i]
		c.panel:reset_size()
		local sz = c.panel:get_combined_minimum_size()
		UICtx.move_node(c.panel, Vector2.new(math.floor(right - sz.X), math.floor(y)))
		y += sz.Y + LaunchCall.GAP
	end
end

function LaunchCall._process(self, delta: number)
	if #self._cards == 0 then
		return
	end
	local gone = false
	local t = os.clock()
	for i = #self._cards, 1, -1 do
		local c = self._cards[i]
		c.left -= delta
		if c.at_me and not UITheme.reduced_motion then
			c.panel:set_modulate_a(0.75 + 0.25 * math.abs(math.sin(t * 4.0)))
		end
		if c.left <= 0 then
			c.panel:queue_free()
			table.remove(self._cards, i)
			gone = true
		elseif c.left < 0.4 then
			c.panel:set_modulate_a(c.left / 0.4)
		end
	end
	if gone then
		self:apply_layout()
	end
end

return LaunchCall
