--!nonstrict
-- The selection window (2026-11-03, the strategy frame; it grew out of the command dial's target card): only while a
-- nation or land is selected (a right-click on its land, a phone's tap, a press on a rival or an alert), hidden
-- otherwise. A larger screen's stands in the left column: the nation's crest, name and colour, its relation to you and
-- its rank; ARMY, LAND and DEFENCE; a plain-language odds line at your send ("At 25% you send 2.1k into 8.2k
-- defenders: you will likely stall. 75% or more should break through.", FrameRules.estimate on the Sim's own sums,
-- worded as the estimate it is); the five send presets and a big ATTACK button with the troops; Offer pact and
-- Warhead; and More orders (the order card: landings, aid, the rest). A phone's is a sheet at the foot: the name and
-- troops, a one-line odds, a big ATTACK and Pact. A tap on the map never sends an army by itself. For a pact partner
-- (kind "ally") it offers Aid, and Break your oath, which first names the price.
--
-- Signals: fire(), closed(), betray(attack), donate(), pact(), warhead(), more_orders(tile). Members: tile, owner_id,
-- kind ("attack" | "boat" | "expand" | "ally" | "look"), is_open, confirming. Methods: show_target(tile, kind, act),
-- show_owner(id, tile?), matches(tile, kind), confirm_betray(), hide_card(user?), place(), panel_rect(), preset_rect(r).

local UITheme = require("./UITheme")
local W = require("./Widgets")
local UICtx = require("./UICtx")
local FrameRules = require("./FrameRules")
local FrameKit = require("./FrameKit")
local Portrait = require("./Portrait")
local Signal = UITheme.core("Signal")
local Defs = UICtx.core("Defs")

local _Rules = nil
local function Rules()
	if _Rules == nil then
		_Rules = UICtx.core("Rules")
	end
	return _Rules
end

local TargetCard = W.class(W.Control)

--- How long a selection counts as the same one for a second tap on its land.
TargetCard.LIFETIME = 12.0

--- The big button's words: the order and its troops ("ATTACK · 2.1k", a landing's "LAND · 2.1k"). Pure.
function TargetCard.go_text(kind: string, troops: string, free: boolean?): string
	local verb = if kind == "boat" then "LAND" elseif free or kind == "expand" then "CLAIM" else "ATTACK"
	return verb .. " · " .. troops
end

--- What DEFENCE says: their Bastions and Flak, or none. Pure.
function TargetCard.defence_text(bastions: number, flak: number): string
	local parts = {}
	if bastions > 0 then
		table.insert(parts, string.format("%d Bastion%s", bastions, if bastions == 1 then "" else "s"))
	end
	if flak > 0 then
		table.insert(parts, string.format("%d Flak", flak))
	end
	return if #parts > 0 then table.concat(parts, ", ") else "None"
end

local function close_button(icon_px: number)
	local b = UITheme.button("", "DialGhost", "close", 44.0)
	b.expand_icon = true
	b.icon_alignment = W.ALIGN_CENTER
	b:add_theme_constant_override("icon_max_width", icon_px)
	b:set_min_size(Vector2.new(44, 44))
	return b
end
TargetCard.close_button = close_button

--- The presets' side padding: five at the kit's 12 px came to 312 px in a 292 px column.
TargetCard.PRESET_MH = 4

--- A stat's value shrinks (18 down to 12 px) to fit its tile, rather than end in "…" ("4 Bastions, 2 Flak"; playtest
--- 2026-11-08).
function TargetCard.fit_value(val: any)
	local room = val.size.X
	local px = 18
	if room > 0 then
		while px > 12 and UITheme.measure_text(val.text, px, 800) > room - 2 do
			px -= 1
		end
	end
	val:set_font_size(px)
end

local function tile(caption: string): any
	local T = UITheme
	local p = W.Panel.new()
	p:set_mouse_filter(W.MOUSE_IGNORE)
	p:add_theme_stylebox_override("panel", T.flat(T.c(T.WHITE, 0.05), 10, T.CLEAR, 0, 8, 6))
	p.size_flags_horizontal = W.EXPAND_FILL
	local v = T.vbox(0)
	p:add_child(v)
	v:add_child(FrameKit.caption(caption))
	local val = FrameKit.value("", 18, T.TEXT)
	val.clip_text = true
	val.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	v:add_child(val)
	return p, val
end

function TargetCard.new(c: any)
	local self = setmetatable({}, TargetCard.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.fire = Signal.new()
	self.closed = Signal.new()
	--- Break the pact; `attack` is always false here (an attack is its own order, afterwards).
	self.betray = Signal.new()
	self.donate = Signal.new()
	--- Pact pressed: offer one, or seal theirs.
	self.pact = Signal.new()
	self.warhead = Signal.new()
	self.more_orders = Signal.new()
	self.tile = -1
	self.owner_id = 0
	self.kind = ""
	self.confirming = false
	self.shown_msec = 0
	self.is_open = false
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	local panel = FrameKit.slate(0.96)
	panel.name = "SelectionWindow"
	panel:set_mouse_filter(W.MOUSE_STOP)
	self._panel = panel
	self:add_child(panel)
	-- (the nation's colour is the card's edge: the dark cards, 2026-11-06; the old side bar stays hidden)
	local edge = FrameKit.bar(T.DIAL_RED)
	edge:set_visible(false)
	self._edge = edge
	panel:add_child(edge)
	local v = T.vbox(10)
	v:set_anchors(0, 0, 0, 0)
	self._box = v
	panel:add_child(v)
	-- the head: crest, name, relation and rank, close
	local head = T.hbox(12)
	self._portrait = Portrait.new(48)
	self._portrait.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._portrait)
	local who = T.vbox(0)
	who.size_flags_horizontal = W.EXPAND_FILL
	who.size_flags_vertical = W.SHRINK_CENTER
	self._name = T.label("", 22, T.DIAL_WEIGHT, T.TEXT, 1)
	self._name.clip_text = true
	self._name.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._name:set_min_size(Vector2.new(60, 0))
	who:add_child(self._name)
	self._rel = T.label("", 13, 700, T.DIAL_RED)
	-- (a long relation, title and rank end in "…" inside the window: 2026-11-07, at full length it pushed every row past
	-- the window's edge)
	self._rel.clip_text = true
	self._rel.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	who:add_child(self._rel)
	head:add_child(who)
	self._close = close_button(14)
	self._close.size_flags_vertical = W.SHRINK_CENTER
	self._close.pressed:Connect(function()
		self:hide_card(true)
	end)
	head:add_child(self._close)
	v:add_child(head)
	-- ARMY, LAND, DEFENCE
	local stats = T.hbox(6)
	local p1, army = tile("ARMY")
	local p2, land = tile("LAND")
	local p3, def = tile("DEFENCE")
	stats:add_child(p1)
	stats:add_child(p2)
	stats:add_child(p3)
	self._stats, self._army, self._land, self._def = stats, army, land, def
	v:add_child(stats)
	-- the odds line
	local odds = FrameKit.free(W.Panel.new())
	odds:set_mouse_filter(W.MOUSE_STOP)
	self._odds_panel = odds
	local oedge = FrameKit.bar(T.DIAL_RED)
	oedge:set_anchors(0, 0, 0, 1)
	oedge:set_offsets(0, 0, 3, 0)
	oedge:set_visible(false)
	odds:add_child(oedge)
	self._odds_edge = oedge
	local ol = T.label("", 13, 600, T.TEXT)
	ol:set_autowrap(true)
	ol:set_anchors(0, 0, 1, 1)
	ol:set_offsets(10, 6, -8, -6)
	self._odds = ol
	odds:add_child(ol)
	FrameKit.hover(c, odds, function()
		return {
			title = "An estimate",
			body = "From the war's own sums for an attack on open ground at your send. Their doctrines, the land's landmarks and the ground itself can move it either way.",
		}
	end)
	v:add_child(odds)
	-- attack with: the presets and the order
	self._with = FrameKit.caption("ATTACK WITH")
	v:add_child(self._with)
	local pr = T.hbox(4)
	self._presets_row = pr
	self._presets = FrameKit.preset_buttons(c, pr, 40.0, 16, nil, nil, TargetCard.PRESET_MH)
	v:add_child(pr)
	local go_row = T.hbox(6)
	self._go_btn = T.button("ATTACK", "DangerButton", "", 48.0)
	self._go_btn:set_font_size(20)
	self._go_btn.size_flags_horizontal = W.EXPAND_FILL
	self._go_btn.pressed:Connect(function()
		self.fire:Fire()
	end)
	go_row:add_child(self._go_btn)
	-- (a phone's Pact stands beside the order)
	self._pact_phone = T.button("Pact", "DialGhost", "", 48.0)
	self._pact_phone:set_font_size(14)
	self._pact_phone:set_min_size(Vector2.new(96, 48))
	self._pact_phone.pressed:Connect(function()
		self.pact:Fire()
	end)
	go_row:add_child(self._pact_phone)
	self._go_row = go_row
	v:add_child(go_row)
	-- Offer pact, Warhead; a pact partner's Aid and Break
	local row2 = T.hbox(6)
	self._pact = T.button("Offer pact", "DialGhost", "alliance", 40.0)
	self._pact:set_font_size(14)
	self._pact.size_flags_horizontal = W.EXPAND_FILL
	self._pact.pressed:Connect(function()
		self.pact:Fire()
	end)
	row2:add_child(self._pact)
	self._nuke = T.button(UICtx.data("PeriodTech").word("Warhead"), "DialGhost", "atom", 40.0)
	UICtx.data("PeriodTech").on_apply(function()
		self._nuke:set_text(UICtx.data("PeriodTech").word("Warhead"))
	end)
	self._nuke:set_font_size(14)
	self._nuke.size_flags_horizontal = W.EXPAND_FILL
	self._nuke.pressed:Connect(function()
		self.warhead:Fire()
	end)
	row2:add_child(self._nuke)
	self._donate = T.button("Aid", "DialGhost", "donate", 44.0)
	self._donate:set_font_size(14)
	self._donate.size_flags_horizontal = W.EXPAND_FILL
	self._donate.pressed:Connect(function()
		self.donate:Fire()
	end)
	row2:add_child(self._donate)
	self._go = T.button("Break your oath", "DangerButton", "betray", 44.0)
	self._go:set_font_size(14)
	self._go.size_flags_horizontal = W.EXPAND_FILL
	self._go.pressed:Connect(function()
		self:_on_go()
	end)
	row2:add_child(self._go)
	self._row2 = row2
	v:add_child(row2)
	-- a depth match (docs/DEPTH_DESIGN.md): the province and the realm, war or peace, and the armies
	self._prov_line = T.label("", 12, 600, T.TEXT_2)
	self._prov_line:set_autowrap(true)
	self._prov_line:set_visible(false)
	v:add_child(self._prov_line)
	self._realm_line = T.label("", 12, 600, T.TEXT_2)
	self._realm_line:set_autowrap(true)
	self._realm_line:set_visible(false)
	v:add_child(self._realm_line)
	self._war_btn = T.button("Declare war", "DangerButton", "attack", if c.touch then 44.0 else 40.0)
	self._war_btn:set_font_size(13)
	self._war_btn.pressed:Connect(function()
		if self.owner_id ~= 0 then
			self.ctx:send({ type = "war", target = self.owner_id })
			self.ctx:sfx("confirm", -4.0)
		end
	end)
	self._war_btn:set_visible(false)
	v:add_child(self._war_btn)
	-- peace: four terms in two rows (winning: what you demand; losing: what you yield)
	self._peace = {}
	self._peace_keys = table.clone(TargetCard.TERM_KEYS)
	self._peace_box = T.vbox(4)
	self._peace_box:set_visible(false)
	for r = 0, 1 do
		local row = T.hbox(4)
		for c = 1, 2 do
			local i = r * 2 + c
			local b = T.button(TargetCard.TERM_NAMES[i], "DialGhost", "", if self.ctx.touch then 44.0 else 36.0)
			b:set_font_size(12)
			b.size_flags_horizontal = W.EXPAND_FILL
			b.pressed:Connect(function()
				if self.owner_id ~= 0 then
					self.ctx:send({ type = "peace", target = self.owner_id, kind = self._peace_keys[i] })
					self.ctx:sfx("confirm", -4.0)
				end
			end)
			row:add_child(b)
			self._peace[i] = b
		end
		self._peace_box:add_child(row)
	end
	v:add_child(self._peace_box)
	-- their peace offer to you: accept or refuse (a depth match)
	local reply = T.hbox(4)
	self._reply_yes = T.button("Accept peace", "PrimaryButton", "", if c.touch then 44.0 else 38.0)
	self._reply_yes:set_font_size(13)
	self._reply_yes.size_flags_horizontal = W.EXPAND_FILL
	self._reply_yes.pressed:Connect(function()
		if self.owner_id ~= 0 then
			self.ctx:send({ type = "peace_reply", target = self.owner_id, accept = true })
			self.ctx:sfx("confirm", -4.0)
		end
	end)
	reply:add_child(self._reply_yes)
	local no = T.button("Refuse", "DialGhost", "", if c.touch then 44.0 else 38.0)
	no:set_font_size(13)
	no.size_flags_horizontal = W.EXPAND_FILL
	no.pressed:Connect(function()
		if self.owner_id ~= 0 then
			self.ctx:send({ type = "peace_reply", target = self.owner_id, accept = false })
			self.ctx:sfx("click", -6.0)
		end
	end)
	reply:add_child(no)
	reply:set_visible(false)
	self._reply = reply
	v:add_child(reply)
	self._army_btn = T.button("Send your army", "DialGhost", "attack", if c.touch then 44.0 else 38.0)
	self._army_btn:set_font_size(13)
	self._army_btn.pressed:Connect(function()
		self:_army_order()
	end)
	self._army_btn:set_visible(false)
	v:add_child(self._army_btn)
	self._more = T.button("More orders", "DialGhost", "", 36.0)
	self._more:set_font_size(13)
	self._more.pressed:Connect(function()
		local t = self.tile
		self:hide_card(false)
		self.more_orders:Fire(t)
	end)
	v:add_child(self._more)
	self._warn = T.label("", 13, 600, T.TEXT)
	self._warn:set_autowrap(true)
	self._warn:set_visible(false)
	v:add_child(self._warn)
	self:set_visible(false)
	self:set_process(true)
	c.ratio_changed:Connect(function(_r)
		if self.is_open and self.kind ~= "ally" then
			self:_fill_go()
		end
	end)
	return self
end

TargetCard.TERM_KEYS = { "white", "provinces", "tribute", "vassal" }
TargetCard.TERM_NAMES = { "White peace", "Take provinces", "Tribute", "Vassal" }
--- Losing a war: what you may yield instead (SimDiplomacy.YIELD_INDEX).
TargetCard.YIELD_KEYS = { "white", "concede", "pay", "submit" }
TargetCard.YIELD_NAMES = { "White peace", "Cede provinces", "Pay tribute", "Become vassal" }

--- A depth match's lines for the land at `t` of owner `id`, seen by `me` (Core/DepthState `ds`, GameState `gs`):
--- the province ("Normandy · Plains · Dev 6 · 2 of 3 slots · held by France"), the realm ("Ruler: Henry II, 34 ·
--- Unrest 20 · Prestige 40"), and the war state: "war" (with the score), "truce" (seconds), "vassal", "overlord",
--- "peace" (with the reason to fight, or nil). Pure.
function TargetCard.depth_lines(ds: any, gs: any, me: number, id: number, t: number): (string, string, { [string]: any })
	local Provinces = UICtx.core("Provinces")
	local p = ds:province_at(t)
	local prov = ""
	if p > 0 then
		local P = ds.P
		local h = ds.holder[p] or 0
		prov = string.format("%s · %s · Dev %d · %d of %d slots", P.name[p], Provinces.TERRAIN_NAMES[P.terr[p]] or "", P.dev[p], ds:slots_used(p), P.slots[p])
		prov ..= if h == 0 then " · held by nobody" else " · held by " .. gs:owner_name(h)
	end
	local realm = ""
	if id > 0 then
		local bits = {}
		local title = ds:ruler_title(id)
		if title ~= nil then
			table.insert(bits, string.format("Ruler: %s, %d", title, ds.ruler[id].age))
		end
		local r = ds.realm[id]
		if r ~= nil then
			table.insert(bits, string.format("Unrest %d", r.unrest))
			table.insert(bits, string.format("Prestige %d", r.prestige))
		end
		table.insert(bits, string.format("%d provinces", ds:held(id)))
		realm = table.concat(bits, " · ")
	end
	local st: { [string]: any } = { kind = "none" }
	if id > 0 and id ~= me then
		if ds:at_war(me, id) then
			st = { kind = "war", score = ds:war_score(me, id) }
		elseif ds:truce_left(me, id) > 0 then
			st = { kind = "truce", left = ds:truce_left(me, id) }
		elseif ds:overlord(id) == me then
			st = { kind = "vassal" }
		elseif ds:overlord(me) == id then
			st = { kind = "overlord" }
		else
			-- a reason to fight, as the Sim reckons one (SimDiplomacy.casus_belli; a grudge it can't see here is
			-- left out: their marches on you are)
			local reason = nil
			if gs.nemesis ~= nil and (gs.nemesis[me] == id or gs.nemesis[id] == me) then
				reason = "your nemesis"
			end
			for _, a in gs.attacks or {} do
				if a.attacker == id and a.target == me then
					reason = "they attacked you"
				end
			end
			if reason == nil then
				local mo = gs:get_owner(me)
				local home = if mo ~= nil and mo.spawn_tile ~= nil then ds:province_at(mo.spawn_tile) else 0
				local iso = if home > 0 then ds.P.country[home] else ""
				if iso ~= "" then
					for q, h in ds.holder do
						if h == id and ds.P.country[q] == iso then
							reason = "a claim on " .. ds.P.name[q]
							break
						end
					end
				end
			end
			st = { kind = "peace", reason = reason }
		end
	end
	return prov, realm, st
end

--- Sends the local player's first army at the selected realm: on a front (today's maps) or marching to the land picked
--- (a medieval map); with no army, raises one first.
function TargetCard._army_order(self)
	local ctx = self.ctx
	local s = ctx.state
	local ds = s and s.depth
	if ds == nil or self.owner_id == 0 then
		return
	end
	local mine = ds:armies_of(ctx:me())
	if #mine == 0 then
		ctx:send({ type = "army", kind = "raise", troops = math.floor(ctx:troops_for_ratio()) })
		ctx:sfx("confirm", -4.0)
		return
	end
	local ar = mine[1]
	if ar.mode == "front" then
		ctx:send({ type = "army", kind = "attack", uid = ar.aid, target = self.owner_id })
		ctx:sfx("confirm", -4.0)
	else
		ctx:send({ type = "army", kind = "march", uid = ar.aid, tile = self.tile })
		ctx:sfx("confirm", -4.0)
	end
end

--- The depth rows for what is shown now.
function TargetCard._fill_depth(self)
	local ctx = self.ctx
	local s = ctx.state
	local ds = s and s.depth
	local on = ds ~= nil and self.tile >= 0
	self._prov_line:set_visible(on)
	self._realm_line:set_visible(on and self.owner_id ~= 0)
	self._war_btn:set_visible(false)
	self._peace_box:set_visible(false)
	self._army_btn:set_visible(false)
	self._reply:set_visible(false)
	if not on then
		return
	end
	local me = ctx:me()
	local id = self.owner_id
	local prov, realm, st = TargetCard.depth_lines(ds, s, me, id, self.tile)
	self._prov_line:set_text(prov)
	local extra = ""
	if st.kind == "war" then
		extra = string.format(" · AT WAR, score %+d", math.floor(st.score))
	elseif st.kind == "truce" then
		extra = string.format(" · truce %s", UITheme.fmt_time(math.ceil(st.left)))
	elseif st.kind == "vassal" then
		extra = " · your vassal"
	elseif st.kind == "overlord" then
		extra = " · your overlord"
	end
	self._realm_line:set_text(realm .. extra)
	local o = if id ~= 0 then s:get_owner(id) else nil
	local realmish = o ~= nil and id ~= me and o.kind ~= Defs.KIND_TRIBE and not s:same_team(me, id) and not s:are_allies(me, id)
	if realmish and st.kind == "peace" then
		self._war_btn:set_visible(true)
		self._war_btn:set_text(if st.reason ~= nil then "Declare war: " .. st.reason else "Declare war (no reason: unrest)")
	end
	if realmish and st.kind == "war" then
		self._peace_box:set_visible(true)
		-- (losing: the buttons offer what you yield; else what you demand)
		local losing = st.score < -10
		for i, b in self._peace do
			self._peace_keys[i] = if losing then TargetCard.YIELD_KEYS[i] else TargetCard.TERM_KEYS[i]
			b:set_text(if losing then TargetCard.YIELD_NAMES[i] else TargetCard.TERM_NAMES[i])
		end
		-- (their offer to you, when there is one: its terms on the button)
		local offer = ds.peace_in[id]
		if offer ~= nil then
			self._reply:set_visible(true)
			self._reply_yes:set_text("Accept: " .. UICtx.core("DepthState").offer_words(offer.terms))
		end
	end
	if realmish and (st.kind == "war" or st.kind == "peace") then
		self._army_btn:set_visible(true)
		local mine = ds:armies_of(me)
		self._army_btn:set_text(if #mine == 0 then "Raise an army" elseif mine[1].mode == "front" then "Army: attack them" else "Army: march here")
	end
end

--- Selects owner `id` (a rival pressed, an alert, CHANCES): its land at `tile`, or where its name stands.
function TargetCard.show_owner(self, id: number, tile_hint: number?)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or id == 0 or s:get_owner(id) == nil then
		return
	end
	local t = tile_hint or -1
	if t < 0 or s:tile_owner(t) ~= id then
		t = if type(s.label_tile) == "function" then s:label_tile(id) else -1
	end
	if t < 0 then
		return
	end
	local act = if ctx.rules ~= nil then ctx.rules:primary(t) else { type = "none" }
	local k = tostring(act.type)
	if s:are_allies(ctx:me(), id) and id ~= ctx:me() then
		k = "ally"
	elseif k ~= "attack" and k ~= "boat" then
		k = "look"
	end
	self:show_target(t, k, act)
end

--- Select `t` for order `k`; `act` is UIRules.primary() for that tile.
function TargetCard.show_target(self, t: number, k: string, act: any)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	if s == nil then
		return
	end
	-- (a phone's sheets never stand together: the nation's closes Your war; UIRoot sets it)
	if ctx.compact and self.on_show ~= nil then
		self.on_show()
	end
	self.tile = t
	self.kind = k
	self._act = act
	self.confirming = false
	self.owner_id = s:tile_owner(t)
	self.shown_msec = UICtx.msec()
	local id = self.owner_id
	local o = if id ~= 0 then s:get_owner(id) else nil
	if o ~= nil then
		self._portrait:set_visible(true)
		self._portrait:set_owner(ctx, id)
		self._name:set_text(string.upper(o.name))
		self:_fit_name()
		local col = T.owner_ui_color(o.color)
		self._edge:set_color(col)
		FrameKit.set_card(self._panel, 0.96, T.c(col, 0.8))
		local rel = ctx:relation(id)
		local rank = FrameKit.rank_of(ctx, id)
		local words = FrameKit.relation_words(rel)
		if s.nemesis ~= nil and s.nemesis[ctx:me()] == id then
			words ..= " · your nemesis"
		end
		-- (its temper, which the Field Guide promises here: a phone has no hover card to show it; audit B7)
		local persona = ctx:persona_of(id)
		if persona ~= nil then
			words ..= " · " .. persona.name
		end
		-- (one line, never cut short with "…": what does not fit drops, the temper first, then the rank; playtest 2026-11-08)
		local base = FrameKit.relation_words(rel)
		if s.nemesis ~= nil and s.nemesis[ctx:me()] == id then
			base ..= " · your nemesis"
		end
		local tries = {
			if rank > 0 then string.format("%s · %s", words, FrameRules.ordinal(rank)) else words,
			if rank > 0 then string.format("%s · %s", base, FrameRules.ordinal(rank)) else base,
			base,
		}
		local room = self._rel.size.X
		local pick = tries[1]
		if room > 0 then
			for _, t in tries do
				pick = t
				if T.measure_text(t, 13, 700) <= room - 2 then
					break
				end
			end
		end
		self._rel:set_text(pick)
		T.set_font_color(self._rel, if rel == "Hostile" or rel == "Oathbreaker" then T.DIAL_RED elseif rel == "Pact" or rel == "Sworn" then T.DIAL_GREEN else T.DIAL_MUTED)
		self._army:set_text(T.fmt_troops(o.troops or 0))
		self._land:set_text(T.fmt_pct(ctx:win_share(id)))
		local bastions, flak = 0, 0
		for _, st in s.structures or {} do
			if st.owner == id then
				if st.kind == Defs.S_DEFENSE then
					bastions += 1
				elseif st.kind == Defs.S_SAM then
					flak += 1
				end
			end
		end
		self._def:set_text(UICtx.data("PeriodTech").say(TargetCard.defence_text(bastions, flak)))
		TargetCard.fit_value(self._def)
	else
		self._portrait:set_visible(false)
		self._edge:set_color(T.DIAL_MUTED)
		FrameKit.set_card(self._panel, 0.96)
		self._name:set_text("FREE LAND")
		self:_fit_name()
		self._rel:set_text("Nobody holds it")
		T.set_font_color(self._rel, T.DIAL_MUTED)
		self._army:set_text("0")
		self._land:set_text("")
		self._def:set_text("None")
	end
	self._stats:set_visible(o ~= nil and not ctx.compact)
	local ally = self.kind == "ally"
	local can_order = self.kind == "attack" or self.kind == "boat" or self.kind == "expand"
	local same_team = o ~= nil and s:same_team(ctx:me(), id)
	self._with:set_visible(can_order and not ctx.compact)
	self._presets_row:set_visible(can_order and not ctx.compact)
	self._go_row:set_visible(not ally)
	self._go_btn:set_disabled(not can_order)
	self._pact:set_visible(not ally and not ctx.compact and o ~= nil and not same_team and id ~= ctx:me())
	self._pact_phone:set_visible(not ally and ctx.compact and o ~= nil and not same_team)
	self._nuke:set_visible(not ally and not ctx.compact and o ~= nil and id ~= ctx:me())
	self._donate:set_visible(ally)
	self._go:set_visible(ally and not same_team)
	self._more:set_visible(not ctx.compact and not ally and t >= 0)
	self._warn:set_visible(false)
	if ally then
		local plan = if ctx.rules ~= nil then ctx.rules:donate_plan(id) else nil
		self._odds:set_text(
			if plan ~= nil and plan.capped
				then string.format("%s. Their ranks have room for %s more.", if same_team then "Fights at your side" else "Bound to you by pact", T.fmt_troops(plan.room))
				else (if same_team then "Fights at your side." else "Bound to you by pact: neither of you may attack the other.")
		)
		self._odds_edge:set_color(T.DIAL_GREEN)
		self._go:set_text("Break your oath")
		self._go:set_icon("betray")
		local amt = if plan ~= nil then plan.amount else ctx:troops_for_ratio()
		local full = plan ~= nil and plan.full
		self._donate:set_text(if full then "Ranks are full" else "Aid " .. T.fmt_troops(amt))
		self._donate:set_disabled(amt < 1.0 or full)
	else
		self:_fill_go()
		self:_fill_pact()
	end
	self:_fill_depth()
	local was = self.is_open
	self.is_open = true
	self:set_visible(true)
	self:place()
	if not was then
		UICtx.pop_in(self._panel, 0.0, 1.0, 0.12, true)
	end
	ctx:sfx("click", -8.0)
end

--- The odds line and the big button: the order at the send held now.
function TargetCard._fill_go(self)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	if s == nil then
		return
	end
	local id = self.owner_id
	local troops = T.fmt_troops(ctx:troops_for_ratio())
	local can_order = self.kind == "attack" or self.kind == "boat" or self.kind == "expand"
	self._go_btn:set_text(if can_order then TargetCard.go_text(self.kind, troops, id == 0) else "ATTACK")
	FrameKit.light_presets(ctx, self._presets)
	local line, short, verdict = "", "", nil
	if id ~= 0 and id ~= ctx:me() then
		line, short, verdict = FrameKit.odds_lines(ctx, id)
	elseif id == 0 then
		line = string.format("At %s you send %s to claim free land.", UICtx.ratio_name(ctx.ratio), troops)
		short = line
	end
	if not can_order then
		local reason = if self._act ~= nil then tostring(self._act.reason or "") else ""
		if id == ctx:me() then
			line = "Your own land. Right-click it to build here."
		elseif reason ~= "" then
			-- (no odds: you can't send there, and saying what you would send read as if you could)
			line = reason .. "."
			verdict = nil
		end
		short = line
	end
	self._odds:set_text(if ctx.compact then short else line)
	self._odds_panel:set_visible(line ~= "")
	local col = if verdict == nil then T.DIAL_MUTED elseif FrameRules.breaks(verdict) then T.DIAL_GREEN elseif verdict == "dent" then T.DIAL_AMBER else T.DIAL_RED
	self._odds_edge:set_color(col)
	self._odds_panel:add_theme_stylebox_override("panel", T.flat(T.c(col, 0.12), 12, T.CLEAR, 0, 0, 0))
end

--- Pact: offer one, or say an offer stands (theirs to seal, or yours waiting).
function TargetCard._fill_pact(self)
	local ctx = self.ctx
	local s = ctx.state
	local me, own = ctx:me(), self.owner_id
	if own == 0 or s == nil then
		return
	end
	for _, b in { self._pact, self._pact_phone } do
		local long = b == self._pact
		if s:has_request(own, me) then
			b:set_text(if long then "Seal their pact" else "Seal")
			b:set_disabled(false)
		elseif s:has_request(me, own) then
			b:set_text("Offered")
			b:set_disabled(true)
		else
			local wait = if type(s.request_cooldown_left) == "function" then s:request_cooldown_left(me, own) else 0
			b:set_text(if long then "Offer pact" else "Pact")
			b:set_disabled(wait > 0 or own == me)
		end
	end
end

--- Same target as the current selection (owner for attacks; nearby coast for boats), still fresh.
function TargetCard.matches(self, t: number, k: string): boolean
	if not self.is_open or k ~= self.kind or UICtx.msec() - self.shown_msec > TargetCard.LIFETIME * 1000.0 then
		return false
	end
	local s = self.ctx.state
	if s == nil then
		return false
	end
	if k == "attack" then
		return s:tile_owner(t) == self.owner_id and self.owner_id ~= 0
	end
	return Defs.tile_distance(t, self.tile) <= 4.0 or (self.owner_id ~= 0 and s:tile_owner(t) == self.owner_id)
end

--- Pact partner's window: one more press, with the price named.
function TargetCard.confirm_betray(self)
	if not self.is_open or self.kind ~= "ally" then
		return
	end
	local ctx = self.ctx
	local R = Rules()
	self.confirming = true
	self._warn:set_text(
		string.format(
			"Your oath breaks. For %d s every nation sees it, and your land costs them %d%% of the usual troops.",
			Defs.round(R.TRAITOR_TICKS / R.TICK_RATE),
			Defs.round(R.TRAITOR_DEFENSE_DEBUFF * 100.0)
		)
	)
	self._warn:set_visible(true)
	self._donate:set_visible(false)
	self._go:set_text("Break it")
	self:place()
	ctx:sfx("open", -8.0)
end

function TargetCard._on_go(self)
	if not self.confirming then
		self:confirm_betray()
	else
		self.betray:Fire(false)
	end
end

function TargetCard.hide_card(self, user: boolean?)
	if not self.is_open then
		return
	end
	self.is_open = false
	local t = self:create_tween()
	t:tween_property(self, "modulate:a", 0.0, 0.12)
	t:tween_callback(function()
		if not self.is_open then
			self:set_visible(false)
		end
		self:set_modulate_a(1.0)
	end)
	if user then
		self.ctx:sfx("close", -8.0)
	end
	self.closed:Fire()
end

--- A larger screen's: the left column (FrameRules.layout's select box). A phone's: the sheet at the foot, between the
--- thumbs' buttons (above them where they leave no room).
function TargetCard.place(self)
	local ctx = self.ctx
	local r = ctx.reserved_top_left
	local reserved = FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y)
	local compact = ctx.compact
	local v = self._box
	local pad = if compact then 10 else 14
	if compact then
		local l = FrameRules.layout(ctx.vp, true, ctx.insets, reserved, {})
		local w = l.sheet.x1 - l.sheet.x0
		self._odds:set_min_size(Vector2.new(w - 2 * pad - 14, 0))
		self._warn:set_min_size(Vector2.new(w - 2 * pad, 0))
		self._name_px = 18
		self._portrait:set_min_size(Vector2.new(34, 34))
		self:_fit_head(w - 2 * pad, 34)
		v:set_separation(8)
		v:set_offsets(pad, pad, pad + (w - 2 * pad), pad)
		local h = v:get_combined_minimum_size().Y + 2 * pad
		l = FrameRules.layout(ctx.vp, true, ctx.insets, reserved, { sheet_h = h })
		FrameKit.place(self._panel, l.sheet)
		self._edge:set_anchors(0, 0, 1, 0)
		self._edge:set_offsets(0, 0, 0, 3)
	else
		local l = FrameRules.layout(ctx.vp, false, ctx.insets, reserved, { log_h = ctx.log_h })
		local w = FrameRules.SELECT_W
		self._odds:set_min_size(Vector2.new(w - 2 * pad - 14, 0))
		self._warn:set_min_size(Vector2.new(w - 2 * pad, 0))
		self._name_px = 22
		self._portrait:set_min_size(Vector2.new(48, 48))
		self:_fit_head(w - 2 * pad, 48)
		v:set_separation(10)
		v:set_offsets(pad, pad, w - pad, pad)
		local h = v:get_combined_minimum_size().Y + 2 * pad
		local b = l.select
		FrameKit.place(self._panel, { x0 = b.x0, y0 = b.y0, x1 = b.x1, y1 = math.min(b.y0 + h, b.y1) })
		self._edge:set_anchors(0, 0, 0, 1)
		self._edge:set_offsets(0, 0, 4, 0)
	end
	-- (the odds line's words sit inside its tinted block)
	self._odds:set_anchors(0, 0, 1, 1)
	self._odds:set_offsets(12, 6, -8, -6)
	local om = self._odds:get_combined_minimum_size()
	self._odds_panel:set_min_size(Vector2.new(0, om.Y + 12))
end

--- The head's name and relation lines get the width left beside the crest and the close button in a column `inner`
--- px wide, so they wrap or clip there instead of widening the window.
function TargetCard._fit_head(self, inner: number, crest: number)
	local room = math.max(60, inner - crest - 44 - 2 * 12)
	self._name_room = room
	self._name:set_min_size(Vector2.new(room, 0))
	self._rel:set_min_size(Vector2.new(room, 0))
	self:_fit_name()
end

--- The nation's name at the largest size that fits its line (down to TargetCard.NAME_MIN_PX, then "…").
TargetCard.NAME_MIN_PX = 15
function TargetCard._fit_name(self)
	local px = self._name_px or 22
	local room = self._name_room
	if room ~= nil then
		while px > TargetCard.NAME_MIN_PX and UITheme.measure_text(self._name.text, px, UITheme.DIAL_WEIGHT, 1) > room do
			px -= 1
		end
	end
	self._name:set_font_size(px)
	-- (2026-11-09, the owner: names were cut. The real realms' longest, "Principality of Antioch and Tripoli", don't
	-- fit at the smallest size: they take a second line, never an ellipsis)
	local wrap = room ~= nil and UITheme.measure_text(self._name.text, px, UITheme.DIAL_WEIGHT, 1) > room
	self._name:set_autowrap(wrap)
	self._name.clip_text = not wrap
	self._name.text_overrun_behavior = if wrap then W.OVERRUN_NONE else W.OVERRUN_ELLIPSIS
end

function TargetCard.panel_rect(self): Rect
	return if self.is_open then self._panel:get_global_rect() else UICtx.EMPTY_RECT
end

--- The preset button for share `r` while the window shows them (the tutorial points at 25%), else nil.
function TargetCard.preset_rect(self, r: number): Rect?
	local i = FrameRules.preset_index(r)
	local b = if i ~= nil then self._presets[i] else nil
	if b ~= nil and self.is_open and b:is_visible_in_tree() then
		return b:get_global_rect()
	end
	return nil
end

function TargetCard._process(self, _delta: number)
	if not self.is_open then
		return
	end
	-- Breaking an oath is a destructive choice: it waits for an answer, and goes when the pact is gone anyway.
	local ctx = self.ctx
	if self.confirming then
		local s = ctx.state
		if s == nil or not s:are_allies(ctx:me(), self.owner_id) then
			self:hide_card()
		end
	end
	-- (a nation that fell takes its window with it)
	local s = ctx.state
	if s ~= nil and self.owner_id ~= 0 and s:get_owner(self.owner_id) == nil then
		self:hide_card()
	end
end

return TargetCard
