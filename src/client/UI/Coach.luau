--!nonstrict
-- Counsel: what a sovereign should hear, when it matters. One short line at a time at the left under the top row, about
-- the age you are in, the doctrine waiting and the rival at your door, with a plain pulse on what it talks about (a spot
-- on the map or a HUD control) when there is one. Each line is said once per player; "seen" ids persist in the [ui]
-- settings (tips_seen) and can be reset from the Council.
--
-- Counsel keeps its peace: after one line the next waits COUNSEL_GAP seconds, unless danger can't wait (`urgent`). A line
-- stays as long as it takes to read.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")

local Coach = W.class(W.Control)
local Tut = UICtx.data("Tutorial")
local FLOOR_TIP = string.format(
	"A nation with nobody home falls fast. For your first %d wars, %d%% of your army stays behind.",
	Tut.ROOKIE_MATCHES,
	math.floor(Tut.ROOKIE_FLOOR * 100 + 0.5)
)

--- `again`: said each time it is offered, not once per player (UIAdvisor paces it). `urgent`: it doesn't wait its turn.
Coach.TIPS = {
	floor = { again = true, urgent = true, desktop = FLOOR_TIP, touch = FLOOR_TIP },
	-- the Dawn
	ground = {
		desktop = "Free land costs little now. Take it before your rivals do.",
		touch = "Free land costs little now. Take it before your rivals do.",
	},
	stronghold = {
		desktop = "Dawn favours Cities: more troops for your land. Press one at the bottom to raise it.",
		touch = "Dawn favours Cities: more troops for your land. Build raises one.",
	},
	send = {
		desktop = "SEND, at the bottom right, sets what leaves home: press a share, or keys 1-5. Troops grow back fastest at about half your cap.",
		touch = "SEND sets what leaves home: tap a share under it. Troops grow back fastest at about half your cap.",
	},
	-- your rivals
	rival = {
		desktop = "Your land meets %s. Right-click theirs to size them up, or to offer a pact.",
		touch = "Your land meets %s. Tap theirs to size them up, or to offer a pact.",
	},
	nemesis = {
		urgent = true,
		desktop = "%s hunts you now. Bring it down with your own hand and a bounty is yours.",
		touch = "%s hunts you now. Bring it down with your own hand and a bounty is yours.",
	},
	attacked = {
		urgent = true,
		desktop = "%s has crossed your border. Bastions make that ground far dearer to take.",
		touch = "%s has crossed your border. Bastions make that ground far dearer to take.",
	},
	-- the ages, as each one opens
	age2 = {
		desktop = "The Expansion opens Foundries, Bastions and Frigates. Gold or walls: choose first.",
		touch = "The Expansion opens Foundries, Bastions and Frigates. Gold or walls: choose first.",
	},
	age3 = {
		desktop = "The Conflict opens Flak and Launch Sites. Someone will fire soon.",
		touch = "The Conflict opens Flak and Launch Sites. Someone will fire soon.",
	},
	age4 = {
		desktop = "In the Reckoning landmarks pay double. Hold them to the end.",
		touch = "In the Reckoning landmarks pay double. Hold them to the end.",
	},
	doctrine = {
		desktop = "A doctrine waits for your choice. It shapes your nation for the rest of this war.",
		touch = "A doctrine waits for your choice. It shapes your nation for the rest of this war.",
	},
	sea = {
		desktop = "Your coast can carry an army. A far shore is one order away.",
		touch = "Your coast can carry an army. A far shore is one order away.",
	},
	aim = {
		desktop = "Changed your mind? Right-click calls it off.",
		touch = "Changed your mind? Cancel calls it off.",
	},
}
Coach.PRIORITY = { "attacked", "nemesis", "floor", "rival", "doctrine", "age4", "age3", "age2", "ground", "stronghold", "aim", "send", "sea" }
--- How long counsel keeps quiet between lines that can wait.
Coach.COUNSEL_GAP = 14.0
--- The card's width (phones, larger screens): small, so it never hides the map's middle.
Coach.W_PHONE = 270.0
Coach.W_WIDE = 300.0
--- The band a phone's letters keep under the top row.
Coach.FEED_GAP = 50.0
--- One pulse: seconds, and how far the ring grows.
Coach.PULSE_S = 1.2
Coach.PULSE_GROW = 16.0

local function prio(id: string): number
	return table.find(Coach.PRIORITY, id) or 0
end

--- How long a line stays: as long as it takes to read. Pure.
function Coach.life_of(text: string): number
	local words = 0
	for _ in string.gmatch(text, "%S+") do
		words += 1
	end
	return math.clamp(3.0 + words * 0.4, 5.0, 12.0)
end

function Coach.new(c: any)
	local self = setmetatable({}, Coach.__mt)
	W.Control._init(self)
	self.ctx = c
	self.current = ""
	self._target = nil
	self._queue = {}
	self._age = 0.0
	self._life = 8.0
	self._t = 0.0
	self._quiet = 0.0
	self._point = Vector2.new(-1, -1)
	self._point_hidden = false
	--- (UIRoot still sets these: the card has one fixed place now, so nothing reads them.)
	self.blockers = nil
	self.keepout = nil
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	-- The pulse on the target, under the card.
	self._marker = UICtx.canvas(self.gui, "CoachMarker")
	self._marker.ZIndex = 1
	self._pulse = UICtx.ring(self._marker, Vector2.zero, 8, 2, UITheme.AMBER, 1)
	self._marker.Visible = false

	local card = GlassPanel.new(10.0, 6.0, UITheme.R_SM, true, 10)
	self._card = card
	local h = UITheme.hbox(8)
	card:add_child(h)
	local col = UITheme.vbox(1)
	col.size_flags_horizontal = W.EXPAND_FILL
	col.size_flags_vertical = W.SHRINK_CENTER
	col:add_child(UITheme.caption("Counsel", 11, UITheme.TEXT_3))
	self._text = UITheme.label("", 12, 500, UITheme.TEXT)
	self._text:set_autowrap(true)
	self._text.size_flags_horizontal = W.EXPAND_FILL
	col:add_child(self._text)
	h:add_child(col)
	-- (the X: dismisses the line; a full finger's target under touch, the card's row grows to it)
	local x = UITheme.button("", "GhostButton", "close", 26.0)
	x.expand_icon = true
	x.icon_alignment = W.ALIGN_CENTER
	x:add_theme_constant_override("icon_max_width", 10)
	x.size_flags_vertical = W.SHRINK_CENTER
	x.pressed:Connect(function()
		self:dismiss()
	end)
	self._x = x
	h:add_child(x)
	self:add_child(card)
	card:set_visible(false)
	self:set_process(true)
	return self
end

function Coach.apply_layout(self)
	local ctx = self.ctx
	local side = if ctx.touch then 44 else 26
	self._x:set_min_size(Vector2.new(side, side))
	if self.current ~= "" then
		self:_place()
	end
end

function Coach.seen(self, id: string): boolean
	local d = self.ctx:setting("tips_seen", {})
	return type(d) == "table" and d[id] == true
end

function Coach._mark_seen(self, id: string)
	local d = self.ctx:setting("tips_seen", {})
	local dict = if type(d) == "table" then table.clone(d) else {}
	dict[id] = true
	self.ctx:set_setting("tips_seen", dict)
end

function Coach.reset(self)
	self.ctx:set_setting("tips_seen", {})
	table.clear(self._queue)
	self:dismiss()
end

--- Queue a line. `target` returns the screen point to pulse on (Vector2(-1, -1) = none).
function Coach.offer(self, id: string, target: (() -> Vector2)?, arg: string?)
	-- (the tutorial's steps are the counsel while it runs: UI/Tutorial)
	local tip = Coach.TIPS[id]
	if self.muted or tip == nil or id == self.current or (not tip.again and self:seen(id)) then
		return
	end
	for _, q in ipairs(self._queue) do
		if q.id == id then
			return
		end
	end
	table.insert(self._queue, { id = id, target = target, arg = arg or "" })
	table.sort(self._queue, function(a, b)
		return prio(a.id) < prio(b.id)
	end)
	if self.current == "" then
		self:_next()
	end
end

--- The player did what the line asked: close it (and never offer it again).
function Coach.complete(self, id: string)
	if not self:seen(id) then
		self:_mark_seen(id)
	end
	for i = #self._queue, 1, -1 do
		if self._queue[i].id == id then
			table.remove(self._queue, i)
		end
	end
	if self.current == id then
		self:dismiss()
	end
end

function Coach.dismiss(self)
	if self.current == "" then
		return
	end
	self.current = ""
	self._target = nil
	self._quiet = Coach.COUNSEL_GAP
	local t = self._card:create_tween()
	t:tween_property(self._card, "modulate:a", 0.0, 0.2)
	t:tween_callback(function()
		if self.current == "" then
			self._card:set_visible(false)
			self:_draw_marker()
			self:_next()
		end
	end)
	self:_draw_marker()
end

function Coach.clear(self)
	table.clear(self._queue)
	self.current = ""
	self._quiet = 0.0
	self._card:set_visible(false)
	self:_draw_marker()
end

function Coach._next(self)
	if #self._queue == 0 or self.current ~= "" then
		return
	end
	-- (the first in line that may speak now: danger always may)
	local at = nil
	for i, q in ipairs(self._queue) do
		if self._quiet <= 0.0 or Coach.TIPS[q.id].urgent then
			at = i
			break
		end
	end
	if at == nil then
		return
	end
	local ctx = self.ctx
	local q = table.remove(self._queue, at)
	local id = q.id
	local tip = Coach.TIPS[id]
	if not tip.again and self:seen(id) then
		self:_next()
		return
	end
	self.current = id
	self._target = q.target
	local txt = if ctx.touch then tip.touch else tip.desktop
	-- (a medieval start date's words: Data/PeriodTech)
	txt = if type(txt) == "string" then UICtx.data("PeriodTech").say(txt) else txt
	if string.find(txt, "%s", 1, true) then
		txt = string.format(txt, q.arg)
	end
	self._text:set_text(txt)
	if not tip.again then
		self:_mark_seen(id)
	end
	self._age = 0.0
	self._life = Coach.life_of(txt)
	local w = if ctx.compact then Coach.W_PHONE else Coach.W_WIDE
	self._card:set_min_size(Vector2.new(w, 0))
	self._text:set_min_size(Vector2.new(w - 20.0 - 16.0 - (if ctx.touch then 44.0 else 26.0), 0))
	self._card:set_visible(true)
	self._card:set_modulate_a(1.0)
	self._card:reset_size()
	self:_place()
	UICtx.pop_in(self._card, 0.0, 1.0, 0.15, true)
	ctx:sfx("open", -10.0)
end

--- Where the card sits: `x`, `y`, at the left under the top row (past `rail_w`, the safe inset now). Pure.
function Coach.spot(compact: boolean, inset_x: number, rail_w: number?, line_top: number?, bar_bottom: number?): Vector2
	if compact then
		return Vector2.new(math.max(8.0 + inset_x, (rail_w or 0.0) + 8.0), (bar_bottom or 58.0) + Coach.FEED_GAP)
	end
	return Vector2.new(math.max(8.0 + inset_x, (rail_w or 0.0) + 8.0), (line_top or (bar_bottom or 58.0)) + 34.0)
end

--- The card's rect while a line is up (nil: none): the hover card keeps off it on a phone (Tooltip.clear_of).
function Coach.card_rect(self): Rect?
	local card = self._card
	if self.current == "" or not card.visible or card.modulate_a <= 0.01 then
		return nil
	end
	return card:get_global_rect()
end

function Coach._place(self)
	local ctx = self.ctx
	local bar = ctx.airship_bar
	local p = Coach.spot(ctx.compact, ctx.insets.x, ctx.rail_w, ctx.line_top, if bar ~= nil then bar.Max.Y else nil)
	UICtx.move_node(self._card, p)
end

function Coach._process(self, delta: number)
	if self._quiet > 0.0 then
		self._quiet -= delta
	end
	if self.current == "" then
		if #self._queue > 0 and self._quiet <= 0.0 and not self._card.visible then
			self:_next()
		end
		return
	end
	self._t += delta
	self._age += delta
	if self._age > self._life then
		self:dismiss()
		return
	end
	local p = Vector2.new(-1, -1)
	if self._target ~= nil then
		local ok, v = pcall(self._target)
		if ok and typeof(v) == "Vector2" then
			p = v
		end
	end
	self._point = p
	self:_place()
	self:_draw_marker()
end

--- A plain pulse on the target: a ring that grows and fades (standing still under reduced motion).
function Coach._draw_marker(self)
	local marker = self._marker
	local card = self._card
	if self.current == "" or self._point.X < 0.0 or not card.visible then
		marker.Visible = false
		return
	end
	-- The whole coach fades while the player aims / uses the order card (UIRoot sets its alpha).
	local a = card.modulate_a * (self._eff_a or 1.0)
	if a <= 0.001 then
		marker.Visible = false
		return
	end
	self.ctx:fit_canvas(marker)
	marker.Visible = true
	local k = if UITheme.reduced_motion then 0.3 else (self._t % Coach.PULSE_S) / Coach.PULSE_S
	UICtx.set_circle(self._pulse, self._point, 8.0 + Coach.PULSE_GROW * k);
	(self._pulse:FindFirstChild("Stroke") :: UIStroke).Transparency = 1 - (1.0 - k) * 0.9 * a
end

return Coach
