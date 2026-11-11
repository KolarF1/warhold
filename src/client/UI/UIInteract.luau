-- Port of scripts/ui/ui_interact.gd
-- Globe interaction for the HUD: hover tooltips and previews, the send beside the cursor on a target (the strategy
-- frame, UI/CursorReadout), primary clicks (spawn / expand / attack / boat / inspect: a left-click on land you can
-- attack attacks with the current send), build & nuke placement mode, the selection window on a right-click
-- (UI/TargetCard; on your own land the Build window to raise something right there), the order card (RadialMenu: a
-- phone's hold, and the window's More orders) and its actions, and the keyboard / touch detection (hotkeys: 1-5 the
-- send presets, or the open Build window's entries; B the Build window, N the Warheads window, Q / E the send one point
-- at a time, Space, Tab; arrows and Enter on an open order card; M / Home live in Main). The wheel only zooms the map
-- (2026-11-03, the owner: no scrolling the send; the send panel's buttons and the keys set it).
--
-- Input: UserInputService events, respecting gameProcessedEvent (chat typing never triggers a
-- hotkey). Positions are viewport coordinates (see UICtx).

local UICtx = require("./UICtx") :: any
local UIRules = require("./UIRules") :: any
local FrameRules = require("./FrameRules") :: any
local Defs = UICtx.core("Defs")

local _T: any = nil
local function T(): any
	if _T == nil then
		_T = UICtx.mod("UITheme")
	end
	return _T
end
local _FT: any = nil
local function FloatText(): any
	if _FT == nil then
		_FT = UICtx.mod("FloatText")
	end
	return _FT
end

local UIInteract = {}
UIInteract.__index = UIInteract

-- One physical tap can reach us twice (a platform that reports both mouse and touch); identical
-- globe clicks inside this window are ignored.
UIInteract.DUP_MS = 180
--- Touch taps sample a ring this wide (logical px) around the finger; the mouse a small one.
UIInteract.PICK_TOUCH_PX = 22.0
UIInteract.PICK_MOUSE_PX = 6.0
--- Touch / mouse radius (px) for picking a warship.
UIInteract.UNIT_PICK_TOUCH = 26.0
UIInteract.UNIT_PICK_MOUSE = 12.0

local TAU = 2 * math.pi

function UIInteract.new(c: any)
	local self = setmetatable({}, UIInteract)
	self.ctx = c
	self.bar = nil :: any
	self.tooltip = nil :: any
	self.radial = nil :: any
	self.float_layer = nil :: any
	self.ui = nil :: any
	self.target_card = nil :: any
	self.place_confirm = nil :: any
	self.unit_card = nil :: any
	--- Current placement kind ("" = none): a structure, "warship" or a nuke.
	self.aim_kind = ""
	self.hover_tile = -1
	self.enabled = false

	self._confirm_tile = -1
	--- The tile the last globe tap resolved to (tests / diagnostics).
	self.last_pick = -1
	-- Touch placement ghost: the resolved tile, the screen point it was picked at (a map drag
	-- under it moves the ghost) and the raw tile last seen there.
	self._ghost_tile = -1
	self._ghost_anchor = Vector2.new(-1, -1)
	self._ghost_raw = -1
	self._ghost_hit = -1
	self._ghost_res = {}
	--- Tile whose SAM / post rings the inspect card is showing (-1 = none).
	self._range_focus = -1
	self._last_click_msec = -100000
	self._last_click_tile = -2
	self._last_ctx_msec = -100000
	self._confirm_msec = 0
	self._tip_accum = 0.0
	self._tip_dirty = false
	self._tip_wait = 0.0
	self._conns = {} :: { any }
	return self
end

-- ---------------------------------------------------------------------------------------------
-- Placement mode
-- ---------------------------------------------------------------------------------------------

function UIInteract.select_action(self: any, kind: string)
	local ctx = self.ctx
	if not self.enabled or not ctx:alive_player() then
		return
	end
	local b = self.bar:button(kind)
	local av = ctx.rules:availability(kind)
	if av.arsenal ~= nil then
		-- an Arsenal unit the player hasn't unlocked: the Arsenal opens on it
		ctx:sfx("locked")
		if self.ui ~= nil and type(self.ui.open_arsenal) == "function" then
			self.ui:open_arsenal(av.arsenal, "locked")
		end
		return
	end
	if not av.ok then
		-- (the action bar's slots are plain buttons with no shake of their own since the HUD's rebuild: only a button that
		-- has one shakes; the reason below says why either way. Live 2026-11-10: 290 errors from calling it on every slot)
		if b ~= nil and type(b.deny) == "function" then
			b:deny()
		end
		ctx:sfx("deny")
		self:_float(tostring(av.reason), "info", T().RED, self:_anchor_pos(b))
		return
	end
	if UIRules.is_call(kind) then
		-- the Harvest Levy and the Call to Arms: an order, not a placement
		self:cancel_aim(false)
		ctx:send({ type = kind })
		ctx:sfx("confirm")
		return
	end
	if self.aim_kind == kind then
		self:cancel_aim()
		return
	end
	self.aim_kind = kind
	self._confirm_tile = -1
	self:_clear_ghost()
	if self.target_card ~= nil then
		self.target_card:hide_card()
	end
	-- Aiming a nuke shows every hostile SAM's coverage.
	ctx:world_call("set_range_mode", { if UIRules.is_nuke(kind) then "nuke_aim" else ctx:base_range_mode() })
	self.bar:set_placing(kind)
	ctx:hide_hint()
	ctx:sfx("click")
	if ctx.touch and self.place_confirm ~= nil then
		self:_first_ghost(kind)
	elseif ctx.coach ~= nil then
		ctx.coach:offer("aim")
	end
	self:on_hover(self.hover_tile)
end

--- Touch: the plate is there at once, on the ghost at the middle of the view (your own land, for a building); a tap or a
--- drag moves it.
function UIInteract._first_ghost(self: any, kind: string)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil then
		return
	end
	local me = ctx:me()
	local mid = Vector2.new(ctx.vp.X * 0.5, ctx.vp.Y * 0.5)
	local t = ctx:tile_at(mid)
	local weapon = UIRules.is_nuke(kind) or kind == "warship"
	if not weapon and (t < 0 or s:tile_owner(t) ~= me) then
		t = s:label_tile(me)
	end
	if t < 0 then
		t = s:label_tile(me)
	end
	if t < 0 then
		return
	end
	local p = ctx:tile_screen_pos(t)
	if p.X < 0.0 then
		-- (your land is off the screen: go there)
		ctx:world_call("focus_tile", { t })
		p = mid
	end
	self:_move_ghost(self:pick(t, p), p, true)
end

function UIInteract.cancel_aim(self: any, play_sound: boolean?)
	if self.aim_kind == "" then
		return
	end
	local ctx = self.ctx
	local was_mirv = self.aim_kind == "mirv"
	self.aim_kind = ""
	self._confirm_tile = -1
	self:_clear_ghost()
	self.bar:set_placing("")
	ctx:set_aim("", -1, 0)
	ctx:world_call("set_range_mode", { ctx:base_range_mode() })
	if was_mirv then
		ctx:world_call("set_selected_owner", { 0 })
	end
	if play_sound ~= false then
		ctx:sfx("close", -6.0)
	end
	self:on_hover(self.hover_tile)
end

function UIInteract._anchor_pos(self: any, c: any): Vector2
	if c ~= nil and type(c) == "table" and c.get_global_rect ~= nil and not c._freed and c:is_visible_in_tree() then
		local r = c:get_global_rect()
		return Vector2.new(UICtx.rect_center(r).X, r.Min.Y)
	end
	return self.ctx:mouse_pos()
end

-- ---------------------------------------------------------------------------------------------
-- World signals
-- ---------------------------------------------------------------------------------------------

function UIInteract.on_hover(self: any, tile: number)
	local ctx = self.ctx
	local tooltip = self.tooltip
	self.hover_tile = tile
	if not self.enabled or ctx.state == nil then
		ctx:world_call("set_hover_owner", { 0 })
		if tooltip.place == tooltip.Place.FOLLOW then
			tooltip:hide_tip()
		end
		return
	end
	local s = ctx.state
	local own = if tile >= 0 then s:tile_owner(tile) else 0
	ctx:world_call("set_hover_owner", { own })
	-- Placement preview (the view draws blast radii, hostile SAM cover and SAM / post range rings
	-- from the detail; an invalid spot shows the preview greyed).
	if self.aim_kind ~= "" then
		if ctx.touch then
			if self._ghost_tile < 0 then
				ctx:set_aim("", -1, 0, false) -- touch: nothing to preview until the first tap
			end
			-- else the ghost only moves on a tap or a map drag (process_frame)
		else
			local locked = self._confirm_tile >= 0 and self:_locks_target(self.aim_kind)
			local t = if locked then self._confirm_tile else tile
			if t >= 0 then
				self:_show_aim(t, ctx.rules:placement(self.aim_kind, t), locked)
			else
				ctx:set_aim("", -1, 0, false)
			end
		end
	end
	-- The hover card is rebuilt at most ~16x per second (its hint may flood-fill the map).
	self._tip_dirty = true
	if self._tip_wait <= 0.0 then
		self._tip_wait = 0.06
		self._tip_dirty = false
		self:_update_tooltip()
	end
end

function UIInteract._update_tooltip(self: any)
	local tooltip = self.tooltip
	local P = tooltip.Place
	-- on land you can attack or claim, the send beside the cursor says it all (the card would only repeat it)
	local ring = self:_update_ring()
	if tooltip.place == P.PINNED and tooltip:is_shown() then
		return
	end
	if tooltip.place == P.ANCHOR and tooltip:is_shown() then
		return
	end
	if self.ctx.touch or self.radial.is_open or not self.enabled then
		if tooltip.place == P.FOLLOW then
			tooltip:hide_tip()
		end
		return
	end
	if ring then
		if tooltip.place == P.FOLLOW then
			tooltip:hide_tip()
		end
		return
	end
	local spec = self:hover_spec(self.hover_tile)
	if next(spec) == nil then
		tooltip:hide_tip()
	else
		tooltip:show_follow(spec)
	end
end

--- The ring's target under the cursor: the order a click gives there, or nil. Pure but for `rules`.
function UIInteract.ring_target(self: any, tile: number): any
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or tile < 0 or self.aim_kind ~= "" or ctx.touch or not self.enabled then
		return nil
	end
	if s.phase ~= Defs.PHASE_PLAYING or not ctx:alive_player() then
		return nil
	end
	local act = ctx.rules:primary(tile)
	local ty = tostring(act.type)
	if not act.ok or (ty ~= "attack" and ty ~= "expand" and ty ~= "boat") then
		return nil
	end
	local own = s:tile_owner(tile)
	local o = if own ~= 0 then s:get_owner(own) else nil
	-- the hover card's other facts (their land, a building here, an oath broken, a pact's end), in one line
	local facts = {}
	if o ~= nil then
		local spec = self:hover_spec(tile)
		if spec.badge ~= nil and spec.badge ~= "" then
			table.insert(facts, spec.badge)
		end
		for _, r in spec.rows or {} do
			if r[1] ~= "Troops" and r[1] ~= "Your front" then
				table.insert(facts, string.format("%s %s", tostring(r[1]), tostring(r[2])))
			end
		end
	end
	return {
		verb = if ty == "boat" then "land" elseif ty == "expand" then "claim" else "march",
		name = if o ~= nil then o.name else "Free land",
		troops = if o ~= nil then T().fmt_troops(o.troops) else nil,
		colour = if o ~= nil then T().owner_ui_color(o.color) else T().DIAL_MUTED,
		facts = table.concat(facts, "  ·  "),
	}
end

--- Shows or hides the send beside the cursor for the hovered tile; true while it shows.
function UIInteract._update_ring(self: any): boolean
	local ro = self.ui and self.ui.readout
	if ro == nil then
		return false
	end
	local spec = if self.radial.is_open then nil else self:ring_target(self.hover_tile)
	if spec == nil then
		ro:hide()
		return false
	end
	ro:show(self.ctx:mouse_pos(), spec)
	return true
end

--- Whether the send stands beside the cursor now.
function UIInteract.ring_on(self: any): boolean
	local ro = self.ui and self.ui.readout
	return ro ~= nil and ro.shown
end

function UIInteract.on_click(self: any, tile: number)
	local ctx = self.ctx
	if not self.enabled or ctx.state == nil then
		return
	end
	local now = UICtx.msec()
	if tile == self._last_click_tile and now - self._last_click_msec < UIInteract.DUP_MS then
		return
	end
	self._last_click_tile = tile
	self._last_click_msec = now
	if self.radial.is_open then
		self.radial:close()
		return
	end
	-- (a depth match's levy waiting for its march: this click says where, UI/RealmSheet)
	if (self.army_aim or 0) > 0 then
		local aid = self.army_aim
		self.army_aim = 0
		if tile >= 0 and ctx.state.map:is_land(tile) then
			ctx:send({ type = "army", kind = "march", uid = aid, tile = tile })
			ctx:sfx("confirm", -4.0)
		else
			ctx:sfx("deny", -4.0)
		end
		return
	end
	local pos = self:tap_pos(tile)
	local unit_card = self.unit_card
	-- Warships: a tap on one selects it; with your own selected, a tap on the sea moves it there and
	-- any other tap just deselects (never also an order).
	if self.aim_kind == "" then
		-- On land a ship must be right under the finger (land taps near a coast stay land orders);
		-- with your own ship selected, sea taps are move orders unless another ship is right there.
		local on_land = tile >= 0 and ctx.state.map:is_land(tile)
		local steering = unit_card ~= nil and unit_card.is_open and unit_card.own and not on_land
		local uid = self:unit_at(pos, if on_land or steering then 12.0 else -1.0)
		if uid ~= 0 and not (steering and uid == unit_card.uid) then
			self:select_unit(uid)
			return
		end
		if unit_card ~= nil and unit_card.is_open then
			if unit_card.own and tile >= 0 and ctx.state.map:is_water(tile) then
				self:_move_selected(tile, pos)
			else
				self:deselect_unit(true)
			end
			return
		end
	end
	tile = self:pick(tile, pos)
	self.last_pick = tile
	if self.aim_kind ~= "" then
		self:_place(tile, pos)
		return
	end
	local act = ctx.rules:primary(tile)
	local kind = tostring(act.type)
	local selectable = (kind == "attack" or kind == "boat") and act.ok
	-- Touch: an ally's land opens their card (Donate / Break alliance) instead of a bare info card.
	local ally_own = if ctx.touch then self:_ally_at(tile) else 0
	local target_card = self.target_card
	local tooltip = self.tooltip
	-- A larger screen with one-click orders: the selection window is a reading, never in the way of an order. A click on
	-- its nation's land attacks as ever and leaves it open; a click anywhere else closes it and does what it does.
	if target_card ~= nil and target_card.is_open and not ctx.touch and not self:confirm_orders() then
		local own_here = ctx.state:tile_owner(tile)
		if own_here == 0 or own_here ~= target_card.owner_id then
			target_card:hide_card()
		end
		target_card = nil
	end
	-- A target card is up (a phone, or "Confirm attacks" on): the card gives the order, by what you commit. Another tap on
	-- the same target leaves it open; anything else changes or closes the selection (a "tap elsewhere to close" must
	-- never also give an order).
	if target_card ~= nil and target_card.is_open then
		if selectable and target_card:matches(tile, kind) then
			return
		end
		local same_ally = ally_own ~= 0 and target_card.kind == "ally" and target_card.owner_id == ally_own
		target_card:hide_card()
		if ally_own ~= 0 and not same_ally then
			self:_select(tile, "ally", act)
		elseif selectable and self:confirm_orders() then
			self:_select(tile, kind, act)
		end
		return
	end
	if ally_own ~= 0 then
		tooltip:hide_tip()
		self:_select(tile, "ally", act)
		return
	end
	if tooltip.place == tooltip.Place.PINNED and tooltip:is_shown() then
		tooltip:hide_tip()
		if ctx.touch then
			return
		end
	end
	if selectable and self:confirm_orders() then
		self:_select(tile, kind, act)
		return
	end
	if kind == "inspect" then
		local own = ctx.state:tile_owner(tile)
		ctx:world_call("set_selected_owner", { own })
		if ctx.touch and own ~= 0 then
			if own ~= ctx:me() and target_card ~= nil and ctx.state.phase == Defs.PHASE_PLAYING then
				-- (a nation out of reach: its sheet all the same, the order greyed with the reason)
				target_card:show_owner(own, tile)
			else
				self:show_inspect(tile)
			end
		end
		return
	end
	if kind == "none" or not act.ok then
		local reason = tostring(act.reason)
		if reason ~= "" then
			ctx:sfx("deny", -4.0)
			self:_float(reason, "info", T().TEXT_2, pos)
		end
		if act.floor == true then
			ctx.floor_held:Fire()
		end
		return
	end
	local intent = ctx.rules:primary_intent(tile, act)
	if next(intent) == nil then
		return
	end
	ctx:send(intent)
	local coach = ctx.coach
	if coach ~= nil then
		if kind == "expand" then
			coach:complete("ground")
		elseif kind == "attack" then
			coach:complete("ground")
			coach:complete("rival")
		elseif kind == "boat" then
			coach:complete("sea")
		end
	end
	if kind == "spawn" then
		ctx:sfx("spawn")
	elseif kind == "expand" then
		self:_float(ctx.rules:confirm_text(act), "attack", T().TEXT, pos)
	elseif kind == "attack" then
		self:_float(ctx.rules:confirm_text(act), "attack", T().TEXT, pos)
	elseif kind == "boat" then
		self:_float(ctx.rules:confirm_text(act), "boat", T().TEXT, pos)
	end
end

--- Touch plays "look before you act": attacks and boat invasions need a selection first.
--- Desktop keeps one-click orders unless the player turns "Confirm attacks" on.
function UIInteract.confirm_orders(self: any): boolean
	local ctx = self.ctx
	if ctx.touch then
		return ctx:setting("confirm_orders", ctx.touch_device or ctx.touch) and true or false
	end
	return ctx:setting("confirm_orders_desktop", false) and true or false
end

function UIInteract._select(self: any, tile: number, kind: string, act: { [string]: any })
	local ctx = self.ctx
	if self.target_card == nil then
		return
	end
	self.target_card:show_target(tile, kind, act)
	local own = ctx.state:tile_owner(tile)
	ctx:world_call("set_selected_owner", { own })
	-- Show the target's defense posts (their protection radius) while sizing them up.
	if own ~= 0 and kind ~= "ally" then
		ctx:world_call("set_range_owner", { own })
		ctx:world_call("set_range_mode", { "attack_aim" })
	end
	-- A tapped SAM / post shows its own ring (the view ignores tiles without one).
	self._range_focus = tile
	ctx:world_call("set_range_focus", { tile })
end

function UIInteract._fire_selected(self: any, pos: Vector2)
	local ctx = self.ctx
	local tc = self.target_card
	local t = tc.tile
	local k = tc.kind
	tc:hide_card()
	ctx:world_call("set_selected_owner", { 0 })
	local act = ctx.rules:primary(t)
	if tostring(act.type) == "none" or not act.ok then
		ctx:sfx("deny", -4.0)
		local r = tostring(act.reason)
		self:_float(if r ~= "" then r else "Too far", "info", T().TEXT_2, pos)
		if act.floor == true then
			ctx.floor_held:Fire()
		end
		return
	end
	if tostring(act.type) ~= k and not (k == "attack" and tostring(act.type) == "expand") then
		act.type = k
	end
	local intent = ctx.rules:primary_intent(t, act)
	if next(intent) == nil then
		return
	end
	ctx:send(intent)
	if ctx.coach ~= nil then
		ctx.coach:complete("ground")
		ctx.coach:complete("rival")
		if k == "boat" then
			ctx.coach:complete("sea")
		end
	end
	self:_float(
		ctx.rules:confirm_text(act),
		if k == "attack" then "attack" else "boat",
		T().TEXT,
		pos
	)
end

function UIInteract.fire_from_card(self: any)
	local tc = self.target_card
	if tc == nil or not tc.is_open then
		return
	end
	local p = self.ctx:tile_screen_pos(tc.tile)
	self:_fire_selected(if p.X >= 0.0 then p else UICtx.rect_center(tc:panel_rect()))
end

--- The alliance partner owning `tile` while playing (0 = none).
function UIInteract._ally_at(self: any, tile: number): number
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or tile < 0 or s.phase ~= Defs.PHASE_PLAYING or not ctx:alive_player() then
		return 0
	end
	local own = s:tile_owner(tile)
	return if own ~= 0 and own ~= ctx:me() and s:are_allies(ctx:me(), own) then own else 0
end

--- Break the pact from the card's second press.
function UIInteract.betray_from_card(self: any, _attack: boolean)
	local ctx = self.ctx
	local tc = self.target_card
	if tc == nil or not tc.is_open or tc.owner_id == 0 then
		return
	end
	local own = tc.owner_id
	local p = ctx:tile_screen_pos(tc.tile)
	tc:hide_card()
	ctx:world_call("set_selected_owner", { 0 })
	ctx:send({ type = "ally_break", target = own })
	ctx:sfx("deny", -2.0)
	self:_float("Your oath to " .. ctx.state:owner_name(own) .. " is broken", "betray", T().RED, if p.X >= 0.0 then p else ctx:mouse_pos())
end

function UIInteract.donate_from_card(self: any)
	local ctx = self.ctx
	local tc = self.target_card
	if tc == nil or not tc.is_open or tc.owner_id == 0 then
		return
	end
	local own = tc.owner_id
	local p = ctx:tile_screen_pos(tc.tile)
	if self:donate_to(own, if p.X >= 0.0 then p else ctx:mouse_pos()) then
		tc:hide_card()
		ctx:world_call("set_selected_owner", { 0 })
	end
end

--- Pact on the target card: seal their offer, or send one.
function UIInteract.pact_from_card(self: any)
	local ctx = self.ctx
	local tc = self.target_card
	if tc == nil or not tc.is_open or tc.owner_id == 0 or ctx.state == nil then
		return
	end
	local own = tc.owner_id
	local p = ctx:tile_screen_pos(tc.tile)
	local pos = if p.X >= 0.0 then p else ctx:mouse_pos()
	tc:hide_card()
	if ctx.state:has_request(own, ctx:me()) then
		ctx:send({ type = "ally_reply", target = own, accept = true })
		self:_float("Your seal is on it", "alliance", T().TEXT, pos)
	else
		ctx:send({ type = "ally_request", target = own })
		ctx:sfx("click")
		self:_float("Your envoy rides to " .. ctx.state:owner_name(own), "alliance", T().TEXT, pos)
	end
end

--- Send troops to ally `own` (ratio share, capped at their troop headroom; see UIRules.donate_plan)
--- with a float at `pos`. False (and a deny float) when nothing useful can be sent.
function UIInteract.donate_to(self: any, own: number, pos: Vector2): boolean
	local ctx = self.ctx
	local plan = ctx.rules:donate_plan(own)
	local name = ctx.state:owner_name(own)
	if plan.want < 1 or plan.full or plan.amount < 1 then
		ctx:sfx("deny", -4.0)
		self:_float(
			if plan.want < 1 then "You have none to spare" else name .. "'s ranks are full",
			"info",
			T().RED,
			pos
		)
		return false
	end
	ctx:send({ type = "donate", target = own, troops = plan.amount })
	self:_float(
		if plan.capped
			then string.format("%s's ranks are full now, +%s", name, T().fmt_troops(plan.amount))
			else string.format("%s's ranks, +%s", name, T().fmt_troops(plan.amount)),
		"donate",
		T().GREEN,
		pos
	)
	return true
end

function UIInteract.on_context(self: any, tile: number, screen_pos: Vector2)
	local ctx = self.ctx
	if not self.enabled or ctx.state == nil then
		return
	end
	local now = UICtx.msec()
	if now - self._last_ctx_msec < 350 then
		return
	end
	self._last_ctx_msec = now
	if self.aim_kind ~= "" then
		self:cancel_aim()
		return
	end
	if (self.army_aim or 0) > 0 then
		-- (a levy's march waiting for its click: a right-click calls it off)
		self.army_aim = 0
		ctx:sfx("close", -6.0)
		return
	end
	tile = self:pick(tile, screen_pos)
	if tile < 0 then
		return
	end
	if self.target_card ~= nil and self.target_card.is_open then
		self.target_card:hide_card()
	end
	local s = ctx.state
	if s.phase == Defs.PHASE_SPAWN then
		return
	end
	self.tooltip:hide_tip()
	-- your own land: the Build window, to raise something right there (on one of your buildings: or to pull it down)
	if s:tile_owner(tile) == ctx:me() and ctx:alive_player() and self.ui ~= nil and self.ui.open_build_here ~= nil then
		self.ui:open_build_here(tile, self:own_building_at(screen_pos))
		return
	end
	-- a larger screen: the selection window (its More orders opens the order card); a phone's hold: the order card
	if not ctx.touch and self.target_card ~= nil and s.phase == Defs.PHASE_PLAYING then
		self:select_at(tile)
		return
	end
	self:open_orders(tile, screen_pos)
end

--- How near (logical px) a right-click must fall to one of your buildings' icons to mean that building.
UIInteract.BUILDING_HIT_PX = 22.0

--- Your building whose icon is under `pos` (the nearest within BUILDING_HIT_PX), or nil.
function UIInteract.own_building_at(self: any, pos: Vector2): any
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or s.structures == nil then
		return nil
	end
	local me = ctx:me()
	local best, bd = nil, UIInteract.BUILDING_HIT_PX
	for _, st in s.structures do
		if st.owner == me then
			local p = ctx:tile_screen_pos(st.tile)
			if p.X >= 0 then
				local d = (p - pos).Magnitude
				if d <= bd then
					best, bd = st, d
				end
			end
		end
	end
	return best
end

--- The selection window for the land at `tile`: a nation (whatever a click there would do), or free land to claim.
function UIInteract.select_at(self: any, tile: number)
	local ctx = self.ctx
	local s = ctx.state
	local tc = self.target_card
	if s == nil or tc == nil or tile < 0 then
		return
	end
	local own = s:tile_owner(tile)
	local act = ctx.rules:primary(tile)
	local ty = tostring(act.type)
	if own ~= 0 then
		tc:show_owner(own, tile)
	elseif ty == "expand" or ty == "boat" then
		tc:show_target(tile, ty, act)
	else
		return
	end
	ctx:world_call("set_selected_owner", { own })
	if own ~= 0 and own ~= ctx:me() then
		ctx:world_call("set_range_owner", { own })
		ctx:world_call("set_range_mode", { "attack_aim" })
	end
	self._range_focus = tile
	ctx:world_call("set_range_focus", { tile })
end

--- The order card for `tile` at `screen_pos` (a phone's hold; the selection window's More orders).
function UIInteract.open_orders(self: any, tile: number, screen_pos: Vector2)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or tile < 0 then
		return
	end
	local own = s:tile_owner(tile)
	local title = ctx:terrain_title(tile)
	local col = T().TEXT_2
	if own ~= 0 then
		title = s:owner_name(own)
		col = T().owner_ui_color(UICtx.color3(s:owner_color(own)))
	elseif s.map:is_contestable(tile) then
		title = "Free land"
	end
	local items = ctx.rules:radial_items(tile)
	if #items == 0 then
		-- (nothing to order here: what there is to read about it)
		if own ~= 0 then
			self:show_inspect(tile)
		end
		return
	end
	self.radial:open_at(tile, screen_pos, items, title, col, self:_order_head(own))
end

--- The order card's head: who they are and what they have (a nation's own card, in one line).
function UIInteract._order_head(self: any, own: number): string
	local ctx = self.ctx
	local s = ctx.state
	local o = if own ~= 0 and own ~= ctx:me() then s:get_owner(own) else nil
	if o == nil then
		return ""
	end
	local parts = { UICtx.mod("FrameKit").relation_short(ctx:relation(own)) }
	local persona = ctx:persona_of(own)
	if persona ~= nil then
		table.insert(parts, persona.name)
	end
	table.insert(parts, T().fmt_troops(o.troops) .. " troops")
	table.insert(parts, T().fmt_pct(s:land_share(own)) .. " land")
	return table.concat(parts, "  ·  ")
end

--- Space bar: primary action at the hovered tile.
function UIInteract.primary_at_hover(self: any)
	if self.hover_tile >= 0 then
		self:on_click(self.hover_tile)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------------------------

local function shift_down(): boolean
	if not UICtx.IS_ROBLOX then
		return false
	end
	local UIS = game:GetService("UserInputService")
	return UIS:IsKeyDown(Enum.KeyCode.LeftShift) or UIS:IsKeyDown(Enum.KeyCode.RightShift)
end

function UIInteract._place(self: any, tile: number, pos: Vector2)
	local ctx = self.ctx
	local kind = self.aim_kind
	local av = ctx.rules:availability(kind)
	if not av.ok then
		ctx:sfx("deny")
		self:_float(tostring(av.reason), "info", T().RED, pos)
		self:cancel_aim(false)
		return
	end
	if ctx.touch and self.place_confirm ~= nil then
		-- Touch: a tap only moves the ghost; the plate's button builds / fires.
		self:_move_ghost(tile, pos)
		return
	end
	local pl = ctx.rules:placement(kind, tile)
	if not pl.ok then
		ctx:sfx("deny", -4.0)
		self:_float(tostring(pl.reason), "info", T().RED, pos)
		return
	end
	if pl.tile ~= nil then
		tile = pl.tile -- the snapped site / the structure an upgrade applies to
	end
	if UIRules.is_nuke(kind) then
		local now = UICtx.msec()
		local confirmed = self._confirm_tile >= 0
			and now - self._confirm_msec < 6000
			and Defs.tile_distance(self._confirm_tile, tile) <= 6.0
		-- a strike (an Air Strike, a Railgun shot) is free and reloads: one click fires it
		if UIRules.is_strike(kind) then
			confirmed = true
			self._confirm_tile = tile
		end
		if not confirmed then
			self._confirm_tile = tile
			self._confirm_msec = now
			ctx:sfx("click")
			local what = UIRules.TITLES[kind]
			self:on_hover(tile)
			local n_sam = tonumber(ctx:world_call("aim_sams")) or 0
			if n_sam > 0 and kind ~= "mirv" then
				self:_float(
					UICtx.data("PeriodTech").say(string.format("%d Flak site%s cover this. Once more to fire the %s", n_sam, if n_sam == 1 then "" else "s", what)),
					"sam",
					T().RED,
					pos
				)
			else
				self:_float(string.format("Aim set. Press again and the %s flies", what), "target", T().RED, pos)
			end
			return
		end
		ctx:send({ type = "nuke", kind = kind, tile = self._confirm_tile })
		self:_float(UIRules.TITLES[kind] .. " away", kind, T().RED, pos)
		self:cancel_aim(false)
		return
	end
	self:_send_build(kind, tile, pl, pos)
	if not shift_down() then
		self:cancel_aim(false)
	end
end

function UIInteract._send_build(self: any, kind: string, tile: number, pl: { [string]: any }, pos: Vector2)
	local ctx = self.ctx
	local av = ctx.rules:availability(kind)
	ctx:send({ type = "build", kind = kind, tile = tile })
	if kind == "city" and ctx.coach ~= nil then
		ctx.coach:complete("stronghold")
	end
	local title = UIRules.TITLES[kind]
	self:_float(
		string.format("%s rises  ·  %s spent", UIRules.level_name(title, if pl.upgrade then tonumber(pl.level) or 2 else 1), T().fmt_cost(av.cost)),
		kind,
		T().TEXT,
		pos
	)
end

--- Preview on the globe for `kind` at `t` given its placement result (snapped site, upgrade level).
function UIInteract._show_aim(self: any, t: number, pl: { [string]: any }, locked: boolean?)
	local ctx = self.ctx
	local nuke = UIRules.is_nuke(self.aim_kind)
	local ok = locked or (pl.ok == true)
	local at = if ok then (tonumber(pl.tile) or t) else t
	local radius = if nuke then UIRules.nuke_radius(self.aim_kind) else 0
	if self.aim_kind == "mirv" then
		-- The MIRV rains over the whole target nation: highlight it instead of a huge circle.
		radius = 0
		ctx:world_call("set_selected_owner", { if ok then ctx.state:tile_owner(at) else 0 })
	end
	ctx:set_aim(if nuke then "nuke" else "build", at, radius, ok, self.aim_kind, tonumber(pl.level) or 1)
end

--- Touch: put the ghost where a tap at `tile` really builds / aims, with its plate beside it.
function UIInteract._move_ghost(self: any, tile: number, pos: Vector2, quiet: boolean?)
	local ctx = self.ctx
	local kind = self.aim_kind
	local pl = ctx.rules:placement(kind, tile)
	self._ghost_anchor = pos
	self._ghost_raw = tile
	self._ghost_hit = ctx:tile_at(pos)
	self._ghost_res = pl
	local ok = pl.ok == true
	local moved_to = if ok then (tonumber(pl.tile) or tile) else tile
	local changed = moved_to ~= self._ghost_tile
	self._ghost_tile = moved_to
	self:_show_aim(self._ghost_tile, pl)
	local verb = if UIRules.is_nuke(kind) then "Hold to fire" elseif kind == "warship" then "Send" elseif pl.upgrade then "Raise" else "Build"
	self.place_confirm:show_for(self._ghost_tile, self:_ghost_caption(kind, pl), UIRules.is_nuke(kind), ok, verb)
	if not quiet or changed then
		ctx:sfx(if ok then "click" else "deny", -8.0)
	end
end

function UIInteract._ghost_caption(self: any, kind: string, pl: { [string]: any }): string
	local ctx = self.ctx
	local title = UIRules.TITLES[kind]
	if not pl.ok then
		local r = pl.reason
		return if r ~= nil and r ~= "" then tostring(r) else "Not here"
	end
	local cost = T().fmt_cost(ctx.rules:availability(kind).cost)
	if pl.upgrade then
		return string.format("%s · %s", UIRules.level_name(title, tonumber(pl.level) or 2), cost)
	end
	if UIRules.is_nuke(kind) then
		local n_sam = tonumber(ctx:world_call("aim_sams")) or 0
		if n_sam > 0 and kind ~= "mirv" then
			return UICtx.data("PeriodTech").say(string.format("Under %d Flak site%s", n_sam, if n_sam == 1 then "" else "s"))
		end
	end
	return string.format("%s · %s", title, cost)
end

--- The plate's button: build / fire at the ghost.
function UIInteract.confirm_ghost(self: any)
	local ctx = self.ctx
	if self.aim_kind == "" or self._ghost_tile < 0 then
		return
	end
	local kind = self.aim_kind
	local pos = ctx:tile_screen_pos(self._ghost_tile)
	local at = if pos.X >= 0.0 then pos else ctx:mouse_pos()
	local av = ctx.rules:availability(kind)
	if not av.ok then
		ctx:sfx("deny")
		self:_float(tostring(av.reason), "info", T().RED, at)
		return
	end
	-- Re-check at the moment of the tap (the world moved on since the ghost was placed).
	local pl = ctx.rules:placement(kind, if not UIRules.is_nuke(kind) then self._ghost_raw else self._ghost_tile)
	if not pl.ok then
		ctx:sfx("deny", -4.0)
		self:_float(tostring(pl.reason), "info", T().RED, at)
		self:_move_ghost(self._ghost_raw, self._ghost_anchor)
		return
	end
	if UIRules.is_nuke(kind) then
		ctx:send({ type = "nuke", kind = kind, tile = self._ghost_tile })
		self:_float(UIRules.TITLES[kind] .. " away", kind, T().RED, at)
	else
		self:_send_build(kind, tonumber(pl.tile) or self._ghost_tile, pl, at)
	end
	self:cancel_aim(false)
end

function UIInteract._clear_ghost(self: any)
	self._ghost_tile = -1
	self._ghost_raw = -1
	self._ghost_anchor = Vector2.new(-1, -1)
	self._ghost_res = {}
	if self.place_confirm ~= nil then
		self.place_confirm:hide_confirm()
	end
end

--- A map drag under the ghost's screen point moves the ghost with it (fine positioning).
function UIInteract._follow_ghost(self: any)
	if self._ghost_tile < 0 or self.aim_kind == "" or self._ghost_anchor.X < 0.0 then
		return
	end
	local t = self.ctx:tile_at(self._ghost_anchor)
	if t < 0 or t == self._ghost_hit then
		return
	end
	self:_move_ghost(self:pick(t, self._ghost_anchor), self._ghost_anchor, true)
end

-- ---------------------------------------------------------------------------------------------
-- Warships
-- ---------------------------------------------------------------------------------------------

--- Warship under screen `pos` (0 = none): WorldView.unit_at_screen when the view has it, else the
--- nearest warship whose tile projects within the pick radius.
function UIInteract.unit_at(self: any, pos: Vector2, radius: number?): number
	local ctx = self.ctx
	local s = ctx.state
	if s == nil then
		return 0
	end
	local rad = radius or -1.0
	local w = ctx.world
	if w ~= nil and type(w.unit_at_screen) == "function" then
		local v = ctx:world_call("unit_at_screen", { ctx:to_view(pos), if rad > 0 then rad * ctx:ui_scale() else rad })
		local u0 = if type(v) == "number" then s.units[v] else nil
		if u0 ~= nil and u0.kind == Defs.U_WARSHIP then
			return u0.uid
		end
		-- The view only knows ships it has drawn: fall through to the mirror (e.g. just launched).
	end
	local r = if rad > 0.0 then rad else (if ctx.touch then UIInteract.UNIT_PICK_TOUCH else UIInteract.UNIT_PICK_MOUSE)
	local best = 0
	local bd = r * r
	for _, u in s.units do
		if u.kind ~= Defs.U_WARSHIP or u.path == nil or #u.path == 0 then
			continue
		end
		local p = ctx:tile_screen_pos(u.path[1])
		if p.X < 0.0 then
			continue
		end
		local d = (p - pos).Magnitude
		d *= d
		if d <= bd and (d < bd or best == 0 or u.uid < best) then
			bd = d
			best = u.uid
		end
	end
	return best
end

function UIInteract.select_unit(self: any, uid: number)
	if self.target_card ~= nil then
		self.target_card:hide_card()
	end
	self.tooltip:hide_tip()
	self.unit_card:show_unit(uid)
	self.ctx:world_call("set_selected_unit", { uid })
end

function UIInteract.deselect_unit(self: any, user: boolean?)
	if self.unit_card ~= nil and self.unit_card.is_open then
		self.unit_card:hide_card(user)
	end
	self.ctx:world_call("set_selected_unit", { -1 })
end

function UIInteract._move_selected(self: any, tile: number, pos: Vector2)
	local ctx = self.ctx
	local uid = self.unit_card.uid
	ctx:send({ type = "move_warship", uid = uid, tile = tile })
	self.unit_card:mark_destination(tile)
	ctx:sfx("click", -4.0)
	self:_float("Under sail", "warship", T().TEXT, pos)
end

-- ---------------------------------------------------------------------------------------------
-- Forgiving picking
-- ---------------------------------------------------------------------------------------------

--- Screen point of the tap that hit `tile`: the pointer when it agrees with the hit, else the
--- tile's centre.
function UIInteract.tap_pos(self: any, tile: number): Vector2
	local ctx = self.ctx
	local pos = ctx:mouse_pos()
	if ctx:tile_at(pos) == tile then
		return pos
	end
	local c = ctx:tile_screen_pos(tile)
	return if c.X >= 0.0 then c else pos
end

--- The tile a tap at screen `pos` (which hit `tile`) means in the current context:
---   * placing a structure -> the nearest of the player's own land tiles;
---   * nukes / warships -> exactly what was hit;
---   * everything else (spawn, expand, attack, boat, inspect) -> the tile under the finger when it
---     is contestable land, else the nearest contestable land (small islands, crisp coastlines that
---     are water on the tile grid), preferring the owner of the land under the finger.
function UIInteract.pick(self: any, tile: number, pos: Vector2): number
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or ctx.world == nil then
		return tile
	end
	local map = s.map
	if self.aim_kind ~= "" and (UIRules.is_nuke(self.aim_kind) or self.aim_kind == "warship") then
		return tile
	end
	-- The pointer position must belong to this tap (else fall back to the tile's centre).
	if ctx:tile_at(pos) ~= tile then
		local c = ctx:tile_screen_pos(tile)
		if c.X >= 0.0 then
			pos = c
		end
	end
	local own_build = self.aim_kind ~= ""
	local me = ctx:me()
	local function good(t: number): boolean
		if t < 0 then
			return false
		end
		if own_build then
			return s:tile_owner(t) == me and map:is_land(t)
		end
		return map:is_contestable(t)
	end
	if good(tile) then
		return tile
	end
	local r_max = if ctx.touch then UIInteract.PICK_TOUCH_PX else UIInteract.PICK_MOUSE_PX
	local prefer_owner = if tile >= 0 and map:is_land(tile) then s:tile_owner(tile) else -1
	local best = -1
	local best_score = math.huge
	local rings = { r_max }
	if ctx.touch then
		rings = { r_max * 0.35, r_max * 0.7, r_max }
	end
	for _, r in rings do
		local n = if r < 10.0 then 8 elseif r < 18.0 then 12 else 16
		for i = 0, n - 1 do
			local a = TAU * i / n
			local q = pos + Vector2.new(math.cos(a), math.sin(a)) * r
			local t = ctx:tile_at(q)
			if not good(t) then
				continue
			end
			local score = r
			if prefer_owner >= 0 and s:tile_owner(t) ~= prefer_owner then
				score += r_max * 0.5
			end
			if score < best_score then
				best_score = score
				best = t
			end
		end
	end
	if best >= 0 then
		return best
	end
	-- Sub-pixel islands: search the tile grid around the hit tile (≈ the ring's size in tiles).
	local span = self:_px_to_tiles(r_max, pos)
	if tile >= 0 and span > 0 then
		local map = ctx.state and ctx.state.map
		local W = if map then map.W else Defs.W
		local H = if map then map.H else Defs.H
		local cx = tile % W
		local cy = tile // W
		local bd = math.huge
		for dy = -span, span do
			local y = cy + dy
			if y < 0 or y >= H then
				continue
			end
			for dx = -span, span do
				local x = cx + dx
				if x < 0 or x >= W then
					continue
				end
				local t2 = y * W + x
				if good(t2) then
					local d = dx * dx + dy * dy
					if d < bd then
						bd = d
						best = t2
					end
				end
			end
		end
	end
	return if best >= 0 then best else tile
end

--- How many grid tiles `px` screen pixels span around `pos` (at least 1).
function UIInteract._px_to_tiles(self: any, px: number, pos: Vector2): number
	local ctx = self.ctx
	local a = ctx:tile_at(pos)
	local b = ctx:tile_at(pos + Vector2.new(px, 0))
	if a < 0 or b < 0 then
		return 1
	end
	local map = ctx.state and ctx.state.map
	local W = if map then map.W else Defs.W
	local dx = math.abs(a % W - b % W)
	local dy = math.abs(a // W - b // W)
	return math.clamp(math.max(dx, dy), 1, 6)
end

--- Aims that take two clicks: warheads on desktop (touch holds the plate's button instead).
function UIInteract._locks_target(self: any, kind: string): boolean
	return UIRules.is_nuke(kind) and not self.ctx.touch
end

function UIInteract.on_radial(self: any, id: string, tile: number, at: Vector2?)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil then
		return
	end
	local own = s:tile_owner(tile)
	local pos = at or self.radial.center
	-- "build:<kind>" or "build:<kind>:<amount>" (the bulk ring: several levels at once), likewise nukes
	if string.sub(id, 1, 6) == "build:" then
		local k, amt = string.match(id, "^build:([%w_]+):?(%d*)$")
		k = k or string.sub(id, 7)
		local n = math.max(1, tonumber(amt) or 1)
		local cost = if n > 1 then ctx.rules:bulk_cost(k, n) else ctx.rules:cost(k)
		ctx:send({ type = "build", kind = k, tile = tile, amount = if n > 1 then n else nil })
		self:_float(
			string.format(
				"%s%s rises  ·  %s spent",
				UIRules.TITLES[k],
				if n > 1 then string.format(", %d levels,", n) else "",
				T().fmt_cost(cost)
			),
			k,
			T().TEXT,
			pos
		)
		return
	end
	if string.sub(id, 1, 5) == "nuke:" then
		local nk, amt = string.match(id, "^nuke:([%w_]+):?(%d*)$")
		nk = nk or string.sub(id, 6)
		local n = math.max(1, tonumber(amt) or 1)
		ctx:send({ type = "nuke", kind = nk, tile = tile, amount = if n > 1 then n else nil })
		self:_float(
			string.format(
				"%s%s away, bound for %s",
				if n > 1 then string.format("%d of ", n) else "",
				UIRules.TITLES[nk],
				s:owner_name(own)
			),
			nk,
			T().RED,
			pos
		)
		return
	end
	if id == "attack" then
		local act = ctx.rules:primary(tile)
		ctx:send({ type = "attack", tile = tile, ratio = ctx:order_ratio() })
		self:_float(ctx.rules:confirm_text(act), "attack", T().TEXT, pos)
	elseif id == "boat" then
		local landing = ctx.rules:boat_landing(tile)
		ctx:send({ type = "boat", tile = if landing >= 0 then landing else tile, ratio = ctx:order_ratio() })
		local act2 = ctx.rules:primary(tile)
		act2.type = "boat"
		self:_float(ctx.rules:confirm_text(act2), "boat", T().TEXT, pos)
	elseif id == "ally_request" then
		ctx:send({ type = "ally_request", target = own })
		ctx:sfx("click")
		self:_float("Your envoy rides to " .. s:owner_name(own), "alliance", T().TEXT, pos)
	elseif id == "ally_accept" then
		ctx:send({ type = "ally_reply", target = own, accept = true })
		self:_float("Your seal is on it", "alliance", T().TEXT, pos)
	elseif id == "ally_extend" then
		ctx:send({ type = "ally_extend", target = own })
		ctx:sfx("confirm", -6.0) -- (the list's Keep sounds the same: UIRoot; it was silent here, tests/action_feedback)
	elseif id == "ally_break" then
		-- Never in one tap: the card asks first and names the price.
		self:_select(tile, "ally", ctx.rules:primary(tile))
		self.target_card:confirm_betray()
	elseif id == "donate" then
		self:donate_to(own, pos)
	elseif id == "retreat" then
		local aid = self:my_attack_on(own)
		if aid >= 0 then
			self:retreat(aid)
		end
	end
end

--- What a ruler would want to know about ground they might plant on: within GROUND_TILES full-size tiles, a landmark, the
--- coast, and the nearest rival by name.
UIInteract.GROUND_TILES = 88.0
function UIInteract.ground_rows(self: any, tile: number): { any }
	local ctx = self.ctx
	local s = ctx.state
	local rows = {}
	if s == nil or tile < 0 then
		return rows
	end
	local Th = T()
	local map = s.map
	local r = UIInteract.GROUND_TILES / (tonumber(map.k_lin) or 1.0)
	local mark = ctx:landmark_within(tile, r)
	if mark ~= nil then
		table.insert(rows, { "Close by", mark, Th.GOLD })
	end
	-- the coast, by a few looks outward
	local W, H = map.W, map.H
	local hx, hy = tile % W, tile // W
	local coast = false
	for ring = 1, 3 do
		for i = 0, 11 do
			local a = TAU * i / 12
			local x = hx + math.floor(math.cos(a) * r * ring / 3)
			local y = hy + math.floor(math.sin(a) * r * ring / 3)
			if x >= 0 and x < W and y >= 0 and y < H and map:is_coastal(y * W + x) then
				coast = true
				break
			end
		end
		if coast then
			break
		end
	end
	table.insert(rows, { "Coast", if coast then "In reach: landings, Harbors" else "Far off", Th.TEXT_2 })
	-- the rival you would meet first
	local me = ctx:me()
	local near, near_d = nil, math.huge
	for _, o in s.owners do
		if o.alive and o.id ~= me and o.kind ~= Defs.KIND_TRIBE then
			local t = if (o.spawn_tile or -1) >= 0 then o.spawn_tile else (o.label_tile or -1)
			if t >= 0 then
				local dx, dy = t % W - hx, t // W - hy
				local d = dx * dx + dy * dy
				if d < near_d then
					near, near_d = o, d
				end
			end
		end
	end
	if near ~= nil then
		table.insert(rows, { "First rival", near.name, Th.TEXT })
	end
	return rows
end

--- Our newest outgoing attack against `target` (0 = expansion), or -1.
function UIInteract.my_attack_on(self: any, target: number): number
	local best = -1
	local ctx = self.ctx
	if ctx.state == nil then
		return best
	end
	local me = ctx:me()
	for _, a in ctx.state.attacks do
		if a.attacker == me and a.target == target and a.aid > best then
			best = a.aid
		end
	end
	return best
end

function UIInteract.retreat(self: any, aid: number)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or s.attacks[aid] == nil then
		return
	end
	local a = s.attacks[aid]
	ctx:send({ type = "retreat", attack_id = aid })
	ctx:sfx("click")
	local who = if a.target ~= 0 then s:owner_name(a.target) else "free land"
	self:_float("Pulling back from " .. who, "retreat", T().TEXT, ctx:mouse_pos())
end

--- A note beside the order: in your banner's colour, whatever the order; refused and fired orders keep their own.
function UIInteract._float(self: any, text: string, icon_name: string, col: Color3, pos: Vector2)
	local FT = FloatText()
	if col == T().TEXT then
		local o = self.ctx:my()
		if o ~= nil then
			col = T().owner_ui_color(o.color)
		end
	end
	if FT.bounds_provider == nil then
		FT.bounds_provider = function()
			return self:float_bounds()
		end
	end
	FT.spawn(self.float_layer, pos, text, icon_name, col, self:float_bounds())
end

--- Where floating confirmations may appear: below the top bar row, above the command bar / tray.
function UIInteract.float_bounds(self: any): Rect
	local area = self.ctx:clear_rect()
	local bottom = if self.bar ~= nil and self.bar:is_visible_in_tree() then self.bar:top_edge() else area.Max.Y
	return Rect.new(area.Min.X, area.Min.Y, area.Max.X, math.min(area.Max.Y, bottom))
end

-- ---------------------------------------------------------------------------------------------
-- Tooltip / inspect content
-- ---------------------------------------------------------------------------------------------

function UIInteract.show_inspect(self: any, tile: number)
	local ctx = self.ctx
	local tooltip = self.tooltip
	local spec = self:hover_spec(tile, true)
	if next(spec) == nil then
		return
	end
	-- beside the tapped / clicked spot, never in a corner (the command dial: "too difficult to see")
	local tp = ctx:tile_screen_pos(tile)
	if tp.X < 0 then
		tp = ctx:mouse_pos()
	end
	tooltip:show_pinned_at(spec, tp)
	-- A tapped SAM / defense post shows its range ring while the card is open.
	self._range_focus = tile
	ctx:world_call("set_range_focus", { tile })
end

function UIInteract.hover_spec(self: any, tile: number, pinned: boolean?): { [string]: any }
	local ctx = self.ctx
	local Th = T()
	local s = ctx.state
	if s == nil or tile < 0 then
		return {}
	end
	local map = s.map
	local own = s:tile_owner(tile)
	local terrain = ctx:terrain_title(tile)
	local spec = {} :: { [string]: any }
	if self.aim_kind ~= "" and not pinned then
		return self:_aim_spec(tile)
	end
	if own ~= 0 then
		local o = s:get_owner(own)
		if o == nil then
			return {}
		end
		local rel = ctx:relation(own)
		spec.title = o.name
		spec.swatch = UICtx.color3(o.color)
		spec.badge = UICtx.mod("FrameKit").relation_short(rel)
		spec.badge_color = ctx:relation_color(rel)
		local persona = ctx:persona_of(own)
		-- (who they are, then the ground only when it is hard; a clan needs no label)
		local who = if persona ~= nil then persona.name elseif o.kind == Defs.KIND_TRIBE then "" else ctx:kind_title(o.kind)
		if s.nemesis ~= nil and s.nemesis[ctx:me()] == own then
			who = "Your nemesis"
		end
		local hard = map:is_land(tile) and (ctx:terrain_at(tile) == Defs.T_HIGHLAND or ctx:terrain_at(tile) == Defs.T_MOUNTAIN)
		spec.sub = if hard and who ~= "" then string.format("%s  ·  %s", who, terrain) elseif hard then terrain else who
		local rows = {
			{ "Troops", Th.fmt_troops(o.troops), Th.TEXT },
			{ "Land", Th.fmt_pct(s:land_share(own)), Th.TEXT },
		}
		-- its historical strength (Data/Traits), if it has one
		local tk = if s.traits ~= nil then s.traits[own] else nil
		local tr = if tk ~= nil then UICtx.data("Traits").LIST[tk] else nil
		if tr ~= nil then
			table.insert(rows, { tr.name, tr.line, Th.VIOLET })
		end
		local lm = ctx:landmark_near(tile)
		if lm ~= nil then
			table.insert(rows, { lm.name, lm.line, Th.GOLD })
		end
		if own == ctx:me() or pinned then
			table.insert(rows, { "Gold", Th.fmt_num(o.gold), Th.GOLD })
		end
		local st = ctx:structure_at(tile, 1)
		if st ~= nil and st.owner == own then
			table.insert(rows, { "Building", UIRules.level_name(Defs.STRUCT_TITLES[st.kind], st.level), Th.TEXT })
			if st.active_tick > s.tick then
				-- Under construction: it does nothing yet (no cap, trade, defense, interception, launch).
				table.insert(
					rows,
					{ "Rising in", Th.fmt_time(math.ceil((st.active_tick - s.tick) / Defs.TICK_RATE)), Th.ORANGE }
				)
			end
		end
		if s:is_traitor(own) then
			table.insert(
				rows,
				{ "Oathbreaker", string.format("%ds more", math.ceil((o.traitor_until - s.tick) / Defs.TICK_RATE)), Th.RED }
			)
		end
		-- game admins only: whether this "player" is a real person
		local bots = if ctx.session ~= nil then ctx.session.admin_bots else nil
		if bots ~= nil and o.kind == Defs.KIND_HUMAN and own ~= ctx:me() then
			table.insert(rows, if bots[own] then { "Ruled by", "a bot", Th.TEXT_3 } else { "Ruled by", "a player", Th.CYAN })
		end
		-- the player panel's "Alliance Expires In": red in the last 30 s, yellow in the last 60 s
		local ai = if own ~= ctx:me() then s:alliance_info(ctx:me(), own) else nil
		if ai ~= nil and ai.expires_at >= 0 then
			local secs = math.ceil(ai.ticks_left / Defs.TICK_RATE)
			local col = if secs <= 30 then Th.RED elseif secs <= 60 then Th.AMBER else Th.GREEN
			table.insert(rows, { "Pact ends", Th.fmt_time(secs), col })
			if ai.me_asked or ai.other_asked then
				table.insert(
					rows,
					{ "Extension", if ai.me_asked then "you asked, no reply yet" else "they are asking", Th.VIOLET }
				)
			end
		end
		spec.rows = rows
	elseif map:is_land(tile) then
		local fallout = s:has_fallout(tile)
		spec.title = if not fallout then "Free land" else "Poisoned land"
		local lm = ctx:landmark_near(tile)
		if lm ~= nil then
			spec.sub = string.format("%s: %s", lm.name, lm.line)
		end
		spec.title_color = if not fallout then Th.TEXT_2 else Th.ORANGE
		local st2 = ctx:structure_at(tile, 0)
		if st2 ~= nil then
			spec.sub = Defs.STRUCT_TITLES[st2.kind]
		end
	else
		if not pinned then
			return {}
		end
		spec.title = terrain
		spec.title_color = Th.TEXT_2
	end
	if pinned then
		if own ~= 0 and own ~= ctx:me() and s.phase == Defs.PHASE_PLAYING and ctx:alive_player() then
			spec.hint = "Hold their land to give an order"
			spec.hint_color = Th.TEXT_2
			spec.hint_icon = "info"
		end
		return spec
	end
	local act = ctx.rules:primary(tile)
	local ty = tostring(act.type)
	if ty == "spawn" then
		spec.hint = "Plant your banner here"
		spec.hint_color = Th.AMBER
		spec.hint_icon = "target"
		local rows2 = spec.rows or {}
		for _, row in self:ground_rows(tile) do
			table.insert(rows2, row)
		end
		spec.rows = rows2
	elseif ty == "expand" or ty == "attack" then
		if act.ok then
			-- what goes, in the words of the Send bar: the click was taught once, by the first war's counsel
			spec.hint = string.format(
				"%s · %s · %s",
				if ty == "expand" then "Claim" else "March",
				Th.fmt_troops(act.troops),
				UICtx.ratio_name(ctx.ratio)
			)
			spec.hint_color = if ty == "expand" then Th.GREEN else Th.AMBER
			spec.hint_icon = "attack"
		end
		-- how much of a border this war would be
		local front = if ty == "attack" and own ~= 0 then ctx.borders:front_word(own) else nil
		if front ~= nil then
			local rows3 = spec.rows or {}
			table.insert(rows3, { "Your front", front, Th.TEXT_2 })
			spec.rows = rows3
		end
	elseif ty == "boat" then
		if act.ok then
			spec.hint = string.format("Landing · %s · %s", Th.fmt_troops(act.troops), UICtx.ratio_name(ctx.ratio))
			spec.hint_color = Th.CYAN
			spec.hint_icon = "boat"
		else
			spec.hint = tostring(act.reason)
			spec.hint_color = Th.TEXT_3
			spec.hint_icon = "boat"
		end
	elseif ty == "none" then
		if tostring(act.reason) ~= "" then
			spec.hint = tostring(act.reason)
			spec.hint_color = Th.TEXT_3
			spec.hint_icon = "info"
		end
	end
	return spec
end

function UIInteract._aim_spec(self: any, tile: number): { [string]: any }
	local ctx = self.ctx
	local Th = T()
	local k = self.aim_kind
	local nuke = UIRules.is_nuke(k)
	local title = UIRules.TITLES[k]
	local av = ctx.rules:availability(k)
	local pl = ctx.rules:placement(k, tile)
	-- a plate: the name (with the level it would reach) and the price; what would stop it, if anything
	local upgrade = pl.ok and pl.upgrade == true and not nuke
	local spec = {
		title = string.format("%s · %s", UIRules.level_name(title, if upgrade then tonumber(pl.level) or 2 else 1), Th.fmt_cost(av.cost)),
		title_color = if nuke then Th.RED else Th.TEXT,
	} :: { [string]: any }
	local rows = {}
	if nuke then
		table.insert(rows, { "Blast", UIRules.blast_text(k), Th.TEXT })
		if tile >= 0 and ctx.state:tile_owner(tile) ~= 0 then
			table.insert(rows, { "On", ctx.state:owner_name(ctx.state:tile_owner(tile)), Th.TEXT })
		end
		-- Hostile Flak over the aimed tile (the view counts it for the current aim, and draws its circles).
		local n_sam = tonumber(ctx:world_call("aim_sams")) or 0
		if n_sam > 0 and k ~= "mirv" then
			table.insert(rows, { UICtx.data("PeriodTech").say("Flak"), string.format("Under %d site%s", n_sam, if n_sam == 1 then "" else "s"), Th.RED })
		end
	end
	spec.rows = rows
	if not pl.ok then
		spec.hint = tostring(pl.reason)
		spec.hint_color = Th.RED
		spec.hint_icon = "info"
	elseif nuke and self._confirm_tile >= 0 then
		spec.hint = "Once more to fire"
		spec.hint_color = Th.RED
		spec.hint_icon = "target"
	elseif tostring(pl.warn or "") ~= "" then
		spec.body = tostring(pl.warn)
	end
	return spec
end

function UIInteract.process_frame(self: any, delta: number)
	local ctx = self.ctx
	local tooltip = self.tooltip
	self:_follow_ghost()
	local ro = self.ui and self.ui.readout
	if ro ~= nil and ro.shown then
		if ctx.touch or not self.enabled or self.radial.is_open then
			ro:hide()
		else
			ro:move(ctx:mouse_pos())
		end
	end
	if
		self._range_focus >= 0
		and not (tooltip:is_shown() and tooltip.place == tooltip.Place.PINNED)
		and not (self.target_card ~= nil and self.target_card.is_open)
	then
		self._range_focus = -1
		ctx:world_call("set_range_focus", { -1 })
	end
	if self._tip_wait > 0.0 then
		self._tip_wait -= delta
		if self._tip_wait <= 0.0 and self._tip_dirty then
			self._tip_dirty = false
			self._tip_wait = 0.06
			self:_update_tooltip()
		end
	end
	-- Keep the hover card's numbers fresh while the pointer rests.
	self._tip_accum += delta
	if self._tip_accum >= 0.5 then
		self._tip_accum = 0.0
		if self.enabled and tooltip.place == tooltip.Place.FOLLOW and tooltip:is_shown() then
			self:_update_tooltip()
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Keyboard, wheel and touch detection
-- ---------------------------------------------------------------------------------------------

--- Touch InputObject positions exclude the top GUI inset: viewport px = Position + inset.
local function io_view_pos(io: InputObject): Vector2
	local p = Vector2.new(io.Position.X, io.Position.Y)
	local inset = game:GetService("GuiService"):GetGuiInset()
	return p + inset
end
UIInteract.io_view_pos = io_view_pos

--- Hooks UserInputService (Godot _input + _unhandled_key_input).
function UIInteract.connect_input(self: any)
	if not UICtx.IS_ROBLOX then
		return
	end
	local UIS = game:GetService("UserInputService")
	table.insert(
		self._conns,
		UIS.InputBegan:Connect(function(io: InputObject, gp: boolean)
			self:_on_input_began(io, gp)
		end)
	)
	table.insert(
		self._conns,
		UIS.InputChanged:Connect(function(io: InputObject, gp: boolean)
			self:_on_input_changed(io, gp)
		end)
	)
	table.insert(
		self._conns,
		UIS.InputEnded:Connect(function(io: InputObject, _gp: boolean)
			if io.UserInputType == Enum.UserInputType.Touch then
				self.ctx.pointer = self.ctx:to_logical(io_view_pos(io))
			end
		end)
	)
	-- Esc opens Roblox's own menu (games never receive it): the transient things Esc cancelled in
	-- the original (radial menu, placement, selection cards) are cancelled when that menu opens.
	table.insert(
		self._conns,
		game:GetService("GuiService").MenuOpened:Connect(function()
			if self.radial.is_open then
				self.radial:close()
			end
			if self.ui ~= nil and self.ui.build_window ~= nil and self.ui.build_window.is_open then
				self.ui.build_window:close(false)
			end
			if self.unit_card ~= nil and self.unit_card.is_open then
				self:deselect_unit(false)
			end
			if self.target_card ~= nil and self.target_card.is_open then
				self.target_card:hide_card(false)
			end
			if self.aim_kind ~= "" then
				self:cancel_aim(false)
			end
		end)
	)
end

function UIInteract.destroy(self: any)
	for _, c in self._conns do
		c:Disconnect()
	end
	table.clear(self._conns)
end

function UIInteract._on_input_began(self: any, io: InputObject, gp: boolean)
	local ty = io.UserInputType
	if ty == Enum.UserInputType.Touch then
		self.ctx.pointer = self.ctx:to_logical(io_view_pos(io))
		self:_set_touch(true)
		-- A slot's long-press card stays up until the next tap anywhere.
		local tt = self.tooltip
		if tt.place == tt.Place.ANCHOR and tt:is_shown() then
			tt:hide_tip()
		end
		return
	end
	if ty == Enum.UserInputType.Keyboard then
		-- Esc belongs to Roblox's system menu: when it still reaches us, it cancels like the original
		-- (a bonus); right-click and the same slot's key are the always-available cancels.
		if io.KeyCode == Enum.KeyCode.Escape then
			if not game:GetService("GuiService").MenuIsOpen then
				self:escape()
			end
			return
		end
		if not gp then
			self:_on_key(io.KeyCode)
		end
	end
end

function UIInteract._on_input_changed(self: any, io: InputObject, gp: boolean)
	local ty = io.UserInputType
	if ty == Enum.UserInputType.MouseMovement then
		if not self.ctx.touch_device and io.Delta.Magnitude > 0.5 then
			self:_set_touch(false)
		end
		return
	end
	if ty == Enum.UserInputType.Touch then
		self.ctx.pointer = self.ctx:to_logical(io_view_pos(io))
		return
	end
	local _ = gp
end

function UIInteract._set_touch(self: any, on: boolean)
	local ctx = self.ctx
	-- Phones and tablets stay in touch mode.
	if self.ui.debug_touch >= 0 or on == ctx.touch or (not on and ctx.touch_device) then
		return
	end
	ctx.touch = on
	if on then
		self.tooltip:hide_tip()
	end
	if self.bar ~= nil then
		self.bar._flow = -1
	end
	self.ui:relayout()
end

local HOTKEY_INDEX: { [any]: number } = {}
if UICtx.IS_ROBLOX then
	local K = Enum.KeyCode
	HOTKEY_INDEX = {
		[K.One] = 1,
		[K.KeypadOne] = 1,
		[K.Two] = 2,
		[K.KeypadTwo] = 2,
		[K.Three] = 3,
		[K.KeypadThree] = 3,
		[K.Four] = 4,
		[K.KeypadFour] = 4,
		[K.Five] = 5,
		[K.KeypadFive] = 5,
		[K.Six] = 6,
		[K.KeypadSix] = 6,
		[K.Seven] = 7,
		[K.KeypadSeven] = 7,
		[K.Eight] = 8,
		[K.KeypadEight] = 8,
		[K.Nine] = 9,
		[K.KeypadNine] = 9,
		[K.Zero] = 10,
		[K.KeypadZero] = 10,
	}
end

--- Hotkeys. Returns true when handled.
function UIInteract._on_key(self: any, key: Enum.KeyCode): boolean
	local ctx = self.ctx
	local ui = self.ui
	local UIS = game:GetService("UserInputService")
	local K = Enum.KeyCode
	if
		UIS:IsKeyDown(K.LeftControl)
		or UIS:IsKeyDown(K.RightControl)
		or UIS:IsKeyDown(K.LeftMeta)
		or UIS:IsKeyDown(K.RightMeta)
		or UIS:IsKeyDown(K.LeftAlt)
		or UIS:IsKeyDown(K.RightAlt)
		or UIS:IsKeyDown(K.LeftSuper)
		or UIS:IsKeyDown(K.RightSuper)
		or ctx:pause_menu_open()
	then
		return false
	end
	-- an open order card has the keys: nothing acts under it
	if self.radial.is_open then
		if key == K.Up or key == K.Down then
			self.radial:move_selection(if key == K.Up then -1 else 1)
		elseif key == K.Return or key == K.KeypadEnter or key == K.Space or key == K.Right then
			self.radial:confirm_selection()
		elseif key == K.Left then
			self.radial:back_or_close()
		elseif key == K.Escape then
			self.radial:close()
		end
		return true
	end
	local handled = true
	if key == K.Escape then
		handled = self:escape()
	elseif key == K.R and ctx.state ~= nil and ctx.state.depth ~= nil and ui.open_realm ~= nil then
		-- (a depth match: R opens your Realm)
		ui:open_realm()
	elseif key == K.Tab then
		-- the leaderboard (Tab, as in most games; Roblox's own player list is off)
		if ui:screen() == "title" then
			handled = false
		else
			ui:toggle_leaderboard()
		end
	elseif key == K.Space then
		if ui:screen() == "play" or ui:screen() == "spawn" then
			self:primary_at_hover()
		else
			handled = false
		end
	elseif key == K.B or key == K.N then
		if ui:screen() == "play" and self.enabled then
			ui:toggle_build(if key == K.N then "warheads" else "build")
		else
			handled = false
		end
	elseif key == K.Q or key == K.E then
		if ui:screen() == "play" and self.enabled then
			ctx:fine_ratio(if key == K.E then 1 else -1)
		else
			handled = false
		end
	else
		-- the digits: an open Build window's entries (the keys it shows), else 1-5 the send presets
		local idx = HOTKEY_INDEX[key]
		local win = ui.build_window
		if idx ~= nil and ui:screen() == "play" and self.enabled then
			if win ~= nil and win.is_open then
				handled = win:pick_digit(idx % 10)
			elseif idx <= #FrameRules.PRESETS then
				if ctx:pick_preset(idx) then
					ctx:sfx("click", -8.0)
				else
					ctx:sfx("deny", -8.0)
				end
			else
				handled = false
			end
		else
			handled = false
		end
	end
	return handled
end

--- Esc: close the top-most transient thing. Returns false when there was nothing to close.
function UIInteract.escape(self: any): boolean
	local ui = self.ui
	local radial = self.radial
	if radial.is_open then
		radial:close()
		return true
	end
	if ui.build_window ~= nil and ui.build_window.is_open then
		ui.build_window:close(true)
		return true
	end
	if ui.list_popup ~= nil and ui.list_popup.is_open then
		ui.list_popup:close()
		return true
	end
	if self.unit_card ~= nil and self.unit_card.is_open then
		self:deselect_unit(true)
		return true
	end
	if self.target_card ~= nil and self.target_card.is_open then
		self.target_card:hide_card(true)
		return true
	end
	if self.aim_kind ~= "" then
		self:cancel_aim()
		return true
	end
	if ui.help.is_open then
		ui.help:close()
		return true
	end
	if ui.pause.is_open then
		ui.pause:close()
		return true
	end
	local tt = self.tooltip
	if tt:is_shown() and tt.place == tt.Place.PINNED then
		tt:hide_tip()
		return true
	end
	return false
end

return UIInteract
