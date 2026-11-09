--!nonstrict
-- The Realm (a depth match, docs/DEPTH_DESIGN.md): your ruler and traits, taxes, unrest, manpower, food, prestige and
-- ambitions, the ideas and techs you took, your wars, truces and vassals (with their peace terms), and your armies
-- (raise, stance, disband). A sheet (UI/Sheet), opened from the mode chip under the top bar or the R key; it reads
-- GameState.depth (Core/DepthState) and sends the depth intents (tax, peace, army).
local UITheme = require("./UITheme")
local W = require("./Widgets")
local UICtx = require("./UICtx")
local Sheet = require("./Sheet")
local HelpOverlay = require("./HelpOverlay")
local Signal = UITheme.core("Signal")

local RealmSheet = W.class(W.Control)

RealmSheet.WIDTH = 560
--- Seconds between two refreshes while open.
RealmSheet.REFRESH_S = 1.0

function RealmSheet.new(c: any)
	local self = setmetatable({}, RealmSheet.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	--- (aid) a levy is to march: the next click on the map says where (UIRoot)
	self.march_wanted = Signal.new()
	self.is_open = false
	self._acc = 0.0
	local v, head = Sheet.attach(self, "YOUR REALM", { relayout = true })
	self._sub = UITheme.label("", 13, 600, UITheme.TEXT_2)
	self._sub.size_flags_horizontal = W.EXPAND_FILL
	self._sub.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._sub)
	self._scroll = HelpOverlay.Scroll.new()
	self._scroll.size_flags_vertical = W.EXPAND_FILL
	v:add_child(self._scroll)
	self:set_process(true)
	return self
end

--- What the realm sheet says about `id`'s realm, as plain lines (the tests read it). Pure but for the mirrors.
function RealmSheet.summary(gs: any, me: number): { [string]: any }
	local ds = gs.depth
	local out = { ruler = "", traits = {}, tax = 2, unrest = 0, mp = 0, food = 0, food_rate = 0, prestige = 0, gold_s = 0, held = 0, ambitions = {}, ideas = {}, wars = {}, truces = {}, vassals = {}, overlord = 0, armies = {} }
	if ds == nil then
		return out
	end
	local Rulers = UICtx.data("Rulers")
	local r = ds.ruler[me]
	if r ~= nil then
		out.ruler = string.format("%s, %d", Rulers.title(r.name, r.num), r.age)
		for _, k in r.traits do
			table.insert(out.traits, Rulers.BY_KEY[k])
		end
	end
	local m = ds.realm[me]
	if m ~= nil then
		out.tax, out.unrest, out.mp, out.food, out.food_rate, out.prestige, out.gold_s = m.tax, m.unrest, m.mp, m.food, m.food_rate, m.prestige, m.ptax
	end
	out.held = ds:held(me)
	for _, a in ds.amb[me] or {} do
		table.insert(out.ambitions, { text = ds:ambition_text(a), done = a[3] })
	end
	local Doctrines = UICtx.data("Doctrines")
	for _, row in (gs.doctrine and gs.doctrine[me]) or {} do
		if row[6] ~= nil and row[6] > 0 then
			local d = Doctrines.LIST[row[2 + row[6]]]
			if d ~= nil and d.cat ~= nil then
				local name = if gs.period ~= nil and d.m_name ~= nil then d.m_name else d.name
				table.insert(out.ideas, { name = name, cat = Doctrines.CAT_NAMES[d.cat] or d.cat, line = d.line })
			end
		end
	end
	table.sort(out.ideas, function(a, b)
		return a.cat < b.cat or (a.cat == b.cat and a.name < b.name)
	end)
	for _, w in ds:wars_of(me) do
		local other = w[1]
		table.insert(out.wars, { id = other, name = gs:owner_name(other), score = ds:war_score(me, other) })
	end
	for k, _ in ds.truces do
		local a, b = k // 1024, k % 1024
		local other = if a == me then b elseif b == me then a else 0
		if other ~= 0 and ds:truce_left(me, other) > 0 then
			table.insert(out.truces, { id = other, name = gs:owner_name(other), left = ds:truce_left(me, other) })
		end
	end
	for v, o in ds.vassal_of do
		if o == me then
			table.insert(out.vassals, { id = v, name = gs:owner_name(v) })
		end
	end
	out.overlord = ds:overlord(me)
	for _, ar in ds:armies_of(me) do
		table.insert(out.armies, ar)
	end
	return out
end

local function section(v: any, title: string)
	v:add_child(UITheme.label(title, 12, 800, UITheme.AMBER, 2))
end

--- (a touch screen's buttons are a finger's height at least: set by _fill)
local touch_h = 0

local function button(text: string, style: string, h: number, fn: () -> ()): any
	local b = UITheme.button(text, style, "", math.max(h, touch_h))
	b:set_font_size(12)
	b.size_flags_horizontal = W.EXPAND_FILL
	b.pressed:Connect(fn)
	return b
end

--- What the sheet would show, as one string: the body is rebuilt only when it changes (a rebuild every second sent a
--- phone's scroll back to the top and could drop a press). Pure but for the mirrors.
function RealmSheet.signature(gs: any, me: number): string
	local sum = RealmSheet.summary(gs, me)
	local parts = { sum.ruler, sum.tax, sum.unrest, math.floor(sum.mp / 1000), math.floor(sum.food / 100), math.floor(sum.food_rate), sum.prestige, math.floor(sum.gold_s), sum.held, sum.overlord }
	for _, t in sum.traits do
		table.insert(parts, t.key)
	end
	for _, a in sum.ambitions do
		table.insert(parts, a.text .. tostring(a.done))
	end
	for _, d in sum.ideas do
		table.insert(parts, d.name)
	end
	for _, w in sum.wars do
		table.insert(parts, w.id .. ":" .. math.floor(w.score))
	end
	for _, t in sum.truces do
		table.insert(parts, t.id .. "t" .. math.floor(t.left))
	end
	for _, v in sum.vassals do
		table.insert(parts, "v" .. v.id)
	end
	for _, ar in sum.armies do
		table.insert(parts, table.concat({ ar.aid, math.floor(ar.troops / 100), ar.state, ar.stance, ar.target, ar.siege_left }, ","))
	end
	return table.concat(parts, "|")
end

--- Rebuilds the body from the mirrors, when anything in it changed (the scroll stays where it was).
function RealmSheet._fill(self, force: boolean?)
	local T = UITheme
	local ctx = self.ctx
	local s = ctx.state
	local sig = if s ~= nil and s.depth ~= nil then RealmSheet.signature(s, ctx:me()) else "none"
	if not force and self._content ~= nil and sig == self._sig then
		return
	end
	self._sig = sig
	touch_h = if ctx.touch then 44 else 0
	local keep = (self._scroll.gui :: any).CanvasPosition
	if self._content ~= nil then
		self._scroll:remove_child(self._content)
		self._content:queue_free()
		self._content = nil
	end
	local v = T.vbox(8)
	v.size_flags_horizontal = W.EXPAND_FILL
	local wrap = T.hbox(0)
	wrap:add_child(v)
	local gutter = W.Control.new()
	gutter:set_min_size(Vector2.new(12, 0))
	gutter:set_mouse_filter(W.MOUSE_IGNORE)
	wrap:add_child(gutter)
	self._content = wrap
	self._scroll:add_child(wrap)
	if s == nil or s.depth == nil then
		v:add_child(T.label("Only Long and Quick wars have realms.", 13, 600, T.TEXT_2))
		return
	end
	local me = ctx:me()
	local sum = RealmSheet.summary(s, me)
	local ds = s.depth
	self._sub:set_text(string.format("%s · %d provinces · prestige %d", sum.ruler, sum.held, sum.prestige))
	-- the ruler
	section(v, "RULER")
	v:add_child(T.label(if sum.ruler ~= "" then sum.ruler else "No ruler yet", 15, 800, T.TEXT))
	for _, tr in sum.traits do
		local l = T.label(string.format("%s: %s", tr.name, tr.line), 12, 600, T.TEXT_2)
		l:set_autowrap(true)
		v:add_child(l)
	end
	-- the treasury and the people
	section(v, "TAXES")
	local taxes = T.hbox(4)
	local DepthState = UICtx.core("DepthState")
	for i, key in DepthState.TAX_KEYS do
		local chosen = sum.tax == i
		local b = button(DepthState.TAX_NAMES[i], if chosen then "PrimaryButton" else "DialGhost", 36.0, function()
			ctx:send({ type = "tax", kind = key })
			ctx:sfx("confirm", -4.0)
		end)
		taxes:add_child(b)
	end
	v:add_child(taxes)
	local stats = {
		string.format("Unrest %d of 100%s", sum.unrest, if sum.unrest >= 80 then ": revolts!" elseif sum.unrest >= 50 then ": gold and regrowth suffer" else ""),
		string.format("Province taxes %s gold a second", T.fmt_num(sum.gold_s)),
		string.format("Manpower %s", T.fmt_troops(sum.mp)),
		string.format("Food %s (%s%.1f a second)%s", T.fmt_num(sum.food), if sum.food_rate >= 0 then "+" else "", sum.food_rate, if sum.food <= 0 then ": starving" else ""),
		string.format("Prestige %d", sum.prestige),
	}
	for i, line in stats do
		local warn = (i == 1 and sum.unrest >= 50) or (i == 4 and sum.food <= 0)
		v:add_child(T.label(line, 13, 600, if warn then T.DIAL_RED else T.TEXT))
	end
	-- ambitions
	section(v, "AMBITIONS")
	if #sum.ambitions == 0 then
		v:add_child(T.label("Set when your realm takes shape.", 12, 600, T.TEXT_2))
	end
	for _, a in sum.ambitions do
		v:add_child(T.label((if a.done then "Done: " else "") .. a.text, 13, 600, if a.done then T.GREEN else T.TEXT))
	end
	-- ideas and techs
	section(v, "IDEAS AND TECHS")
	if #sum.ideas == 0 then
		v:add_child(T.label("Each age brings three ideas to choose, and a tech halfway through.", 12, 600, T.TEXT_2))
	end
	for _, d in sum.ideas do
		local l = T.label(string.format("%s (%s): %s", d.name, d.cat, d.line), 12, 600, T.TEXT_2)
		l:set_autowrap(true)
		v:add_child(l)
	end
	-- diplomacy
	section(v, "WARS AND PEACE")
	if #sum.wars == 0 and #sum.truces == 0 and #sum.vassals == 0 and sum.overlord == 0 then
		v:add_child(T.label("At peace with the world.", 12, 600, T.TEXT_2))
	end
	for _, w in sum.wars do
		v:add_child(T.label(string.format("At war with %s · score %+d", w.name, math.floor(w.score)), 13, 700, T.DIAL_RED))
		local row = T.hbox(4)
		for i, key in DepthState.TERM_KEYS do
			row:add_child(button(DepthState.TERM_NAMES[i], "DialGhost", 34.0, function()
				ctx:send({ type = "peace", target = w.id, kind = key })
				ctx:sfx("confirm", -4.0)
			end))
		end
		v:add_child(row)
		-- (or yield, to end a war you are losing)
		local yrow = T.hbox(4)
		for i, key in DepthState.YIELD_KEYS do
			yrow:add_child(button(DepthState.YIELD_NAMES[i], "DialGhost", 34.0, function()
				ctx:send({ type = "peace", target = w.id, kind = key })
				ctx:sfx("confirm", -4.0)
			end))
		end
		v:add_child(yrow)
	end
	for _, t in sum.truces do
		v:add_child(T.label(string.format("Truce with %s · %s", t.name, T.fmt_time(math.ceil(t.left))), 12, 600, T.TEXT_2))
	end
	if sum.overlord ~= 0 then
		v:add_child(T.label("Your overlord: " .. s:owner_name(sum.overlord), 12, 700, T.AMBER))
	end
	for _, x in sum.vassals do
		v:add_child(T.label("Your vassal: " .. x.name, 12, 600, T.GREEN))
	end
	-- armies
	section(v, "ARMIES")
	local mode_words = if ds.armies ~= nil and s.period ~= nil then "Levies march: pick one, then click the land to march on." else "Armies hold or push a front against one realm."
	v:add_child(T.label(mode_words, 12, 600, T.TEXT_2))
	for _, ar in sum.armies do
		local what
		if ar.mode == "front" then
			what = if ar.target ~= 0 then string.format("%s against %s", string.upper(string.sub(ar.stance, 1, 1)) .. string.sub(ar.stance, 2), s:owner_name(ar.target)) else "Waiting for orders"
		else
			what = if ar.state == "siege" then string.format("Besieging %s · %ds", (if ds.P ~= nil then ds.P.name[ar.siege_p] else nil) or "a province", ar.siege_left)
				elseif ar.state == "march" then "Marching"
				elseif ar.state == "home" then "Going home"
				else "Waiting for orders"
		end
		v:add_child(T.label(string.format("Army %d · %s of %s · general %d · %s", ar.aid, T.fmt_troops(ar.troops), T.fmt_troops(ar.size), ar.general, what), 13, 600, T.TEXT))
		local row = T.hbox(4)
		if ar.mode == "front" and #sum.wars > 0 then
			local foe = if ar.target ~= 0 then ar.target else sum.wars[1].id
			for _, st in DepthState.STANCES do
				row:add_child(button(string.upper(string.sub(st, 1, 1)) .. string.sub(st, 2), if ar.stance == st then "PrimaryButton" else "DialGhost", 34.0, function()
					ctx:send({ type = "army", kind = st, uid = ar.aid, target = foe })
					ctx:sfx("confirm", -4.0)
				end))
			end
		elseif ar.mode == "march" then
			row:add_child(button("March: click the map", "DialGhost", 34.0, function()
				self.march_wanted:Fire(ar.aid)
				self:close()
			end))
		end
		row:add_child(button("Disband", "DialGhost", 34.0, function()
			ctx:send({ type = "army", kind = "disband", uid = ar.aid })
			ctx:sfx("confirm", -4.0)
		end))
		v:add_child(row)
	end
	v:add_child(button("Raise an army (your send)", "PublicButton", 40.0, function()
		ctx:send({ type = "army", kind = "raise", troops = math.floor(ctx:troops_for_ratio()) })
		ctx:sfx("confirm", -4.0)
	end))
	if keep ~= nil then
		(self._scroll.gui :: any).CanvasPosition = keep
	end
end

function RealmSheet.open(self)
	self.is_open = true
	self:_fill(true)
	self:apply_layout()
	Sheet.show(self)
end

function RealmSheet.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function RealmSheet.toggle(self)
	if self.is_open then
		self:close()
	else
		self:open()
	end
end

function RealmSheet.apply_layout(self)
	Sheet.place(self, RealmSheet.WIDTH)
end

function RealmSheet._process(self, dt: number)
	if not self.is_open then
		return
	end
	self._acc += dt
	if self._acc >= RealmSheet.REFRESH_S then
		self._acc = 0.0
		self:_fill()
	end
end

return RealmSheet
