--!nonstrict
-- A new player's first match, step by step (Data/Tutorial: the steps and why; made for phones first). One small goal at a
-- time, said where it is to be done:
--   * one short line, beside the spot on the map or the control it is about, with four marks at its head for the four
--     parts of the drill (the founding, the land, the buildings and the march, the ages) and an X. With nothing to point
--     at, it stands in its slot at the left under the top row. It never covers the spot;
--   * a planted flag on the map spot, or a ring around the control. It hides while the player is busy and comes back
--     after Data/Tutorial.NUDGE_S without an order;
--   * a goal with progress (troops marching home, the next age) fills the current part's mark;
--   * lessons (a step with kind = "lesson": what the ages open, the new age, landmarks) have no goal: the card carries a
--     few lines of body text (and a line for each building it names, from UIRules.BLURBS) and a Next button, and no mark;
--   * a finished step is simply followed by the next line.
-- The spawn step has no line (the spawn line is up there): only the flag on a roomy spot, which is taken for the player
-- after AUTO_SPAWN_S. The City step tops the player's gold up to a City's price. A step nobody finishes in
-- STEP_MAX_S is passed over. While it runs counsel is off (UIRoot); it takes over afterwards. While it runs the send slider
-- starts at its default and stops at Data.RATIO_CAP, and an order leaves Data.TROOP_FLOOR of the army's cap at home
-- (UICtx.ratio_max / .troop_floor): a new player can't empty their nation.
--
--   Tutorial.new(ctx, ui)
--   :begin()                 the tutorial match was asked for
--   :stop(how)               "done" | "skipped" | "left"
--   .active, .finished (Signal: how), .step_done (Signal: funnel step, name), .closed (Signal: the
--   last card is gone)
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local UIRules = require("./UIRules")
local Signal = UITheme.core("Signal")
local Defs = UICtx.core("Defs")
local Data = UICtx.data("Tutorial")
local Eras = UICtx.data("Eras")
local SimLandmarks = UICtx.core("SimLandmarks")

local Tutorial = W.class(W.Control)

--- The last line stays this long.
Tutorial.END_S = 9.0
--- The flag on the map: its pole's height.
Tutorial.FLAG_H = 26.0
--- Between a spot and its line; and how far a spot must move before the line follows it (it mustn't jitter under a thumb).
Tutorial.BESIDE = 30.0
Tutorial.FOLLOW_PX = 48.0
--- Spawn spots tried for the roomiest one.
Tutorial.SPAWN_TRIES = 240
--- Free land this far (tiles) from every nation is roomy enough.
Tutorial.SPAWN_ROOM = 35.0
--- The camera shows the suggested spot with tiles this many px across.
Tutorial.SPAWN_PX = 5.0

function Tutorial.new(c: any, ui: any)
	local self = setmetatable({}, Tutorial.__mt)
	W.Control._init(self)
	self.ctx = c
	self.ui = ui
	self.active = false
	self.finished = Signal.new()
	self.step_done = Signal.new()
	--- the last card (the reward) is gone: the screen is the coach's again
	self.closed = Signal.new()
	self._i = 0
	self._t = 0.0
	self._step_t = 0.0
	self._ending = 0.0
	self._sent = 0
	self._idle = 0.0
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	-- the mark: a flag planted on a spot of the map, a ring around a control
	self._mark = UICtx.canvas(self.gui, "TutorialMark")
	self._mark.ZIndex = 1
	self._ring = UICtx.ring(self._mark, Vector2.zero, 10, 2, UITheme.AMBER, 1)
	self._pole = UICtx.make("Frame", {
		BackgroundColor3 = UITheme.WHITE,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(2, Tutorial.FLAG_H),
		AnchorPoint = Vector2.new(0.5, 1),
	}, self._mark)
	self._pennant = UICtx.make("Frame", {
		BackgroundColor3 = UITheme.AMBER,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(14, 9),
	}, self._mark)
	self._mark.Visible = false
	-- the line
	local card = GlassPanel.new(10.0, 6.0, UITheme.R_SM, true, 18)
	self._card = card
	local h = UITheme.hbox(8)
	card:add_child(h)
	local v = UITheme.vbox(5)
	v.size_flags_horizontal = W.EXPAND_FILL
	v.size_flags_vertical = W.SHRINK_CENTER
	-- (the four marks: the current one fills when its step has progress to show)
	local pips = UITheme.hbox(3)
	self._pips = {}
	for i = 1, Data.PARTS do
		local pip = W.ColorRect.new(UITheme.c(UITheme.WHITE, 0.14))
		pip:set_mouse_filter(W.MOUSE_IGNORE)
		pip:set_min_size(Vector2.new(18, 4))
		local fill = W.ColorRect.new(UITheme.AMBER)
		fill:set_mouse_filter(W.MOUSE_IGNORE)
		fill:set_anchors(0, 0, 0, 1)
		fill:set_offsets(0, 0, 0, 0)
		pip:add_child(fill)
		pips:add_child(pip)
		self._pips[i] = { bg = pip, fill = fill }
	end
	v:add_child(pips)
	self._text = UITheme.label("", 14, 700, UITheme.TEXT)
	self._text:set_autowrap(true)
	self._text:set_min_size(Vector2.new(220, 0))
	v:add_child(self._text)
	-- (a lesson's body: what the thing is and how it works)
	self._body = UITheme.label("", 12, 500, UITheme.TEXT_2)
	self._body:set_autowrap(true)
	self._body:set_min_size(Vector2.new(220, 0))
	self._body:set_visible(false)
	v:add_child(self._body)
	h:add_child(v)
	self._skip = UITheme.button("", "GhostButton", "close", 36.0)
	self._skip.expand_icon = true
	self._skip.icon_alignment = W.ALIGN_CENTER
	self._skip:add_theme_constant_override("icon_max_width", 12)
	self._skip:set_min_size(Vector2.new(36, 36))
	self._skip.size_flags_vertical = W.SHRINK_CENTER
	self._skip.pressed:Connect(function()
		if self._ending > 0.0 then
			self:_close()
		else
			self:stop("skipped")
		end
	end)
	self._next = UITheme.button("Next", "PublicButton", "", 36.0)
	self._next:set_font_size(13)
	self._next:set_min_size(Vector2.new(64, 36))
	self._next.size_flags_vertical = W.SHRINK_CENTER
	self._next.pressed:Connect(function()
		self._next_pressed = true
	end)
	self._next:set_visible(false)
	h:add_child(self._next)
	h:add_child(self._skip)
	self:add_child(card)
	card:set_visible(false)
	self:set_process(true)
	return self
end

--- The tutorial match was asked for: the steps begin with its spawn phase.
function Tutorial.begin(self)
	self.active = true
	self._i = 1
	self._step_t = 0.0
	self._ending = 0.0
	self._idle = 0.0
	self._spot = nil
	self._spot_state = nil
	self._picked = false
	self._base = nil
	self._neighbour = nil
	self._gold_given = false
	self._folded = false
	self._sent = #self.ctx.sent_log
	self._card:set_visible(false)
	self._started = false
	-- the send slider: from 15%, never past the cap; the floor under the army comes from the
	-- FLOOR_FROM step, once it arms (Data.floor_armed; _process)
	local ctx = self.ctx
	ctx.ratio_max = 1.0
	ctx:set_ratio(Data.RATIO_START)
	ctx:set_ratio_max(Data.RATIO_CAP)
	ctx.troop_floor = nil
end

function Tutorial.stop(self, how: string)
	if not self.active then
		return
	end
	self.active = false
	self._mark.Visible = false
	self._point = nil
	self.ctx:set_ratio_max(1.0)
	self.ctx.troop_floor = nil
	if how == "done" then
		-- the last line: what is next
		self._ending = Tutorial.END_S
		self._point = nil
		self._text:set_text(string.format("Your first true war awaits\n%s Renown to your name", UICtx.commas(Data.STARS)))
		self:_set_pips(Data.PARTS + 1, nil)
		self._body:set_visible(false)
		self._next:set_visible(false)
		self._card:set_visible(true)
		self:_place()
		self.ctx:sfx("confirm", -6.0)
	else
		self._card:set_visible(false)
	end
	self.finished:Fire(how)
	if how ~= "done" then
		self.closed:Fire()
	end
end

function Tutorial._close(self)
	self._ending = 0.0
	self._card:set_visible(false)
	self.closed:Fire()
end

--- The four marks: those before `part` are done, `part` itself is lit (or filled to `progress`).
function Tutorial._set_pips(self, part: number, progress: number?)
	for i, p in self._pips do
		local k = if i < part then 1.0 elseif i == part then (progress or 1.0) else 0.0
		p.fill:set_color(if i < part then UITheme.c(UITheme.AMBER, 0.55) else UITheme.AMBER)
		p.fill:set_anchors(0, 0, k, 1)
		p.fill:set_offsets(0, 0, 0, 0)
	end
end

function Tutorial.apply_layout(self)
	if self._card.visible then
		self:_place()
	end
end

--- Where the line goes for a spot `p`: on its right, else on its left, level with it, inside `area`; with no spot, `slot`.
--- Pure.
function Tutorial.spot(p: Vector2?, sz: Vector2, area: Rect, slot: Vector2): (Vector2, boolean)
	if p == nil or p.X < 0.0 or p.Y < 0.0 then
		return slot, true
	end
	local x = p.X + Tutorial.BESIDE
	if x + sz.X > area.Max.X then
		x = p.X - Tutorial.BESIDE - sz.X
	end
	x = math.clamp(x, area.Min.X, math.max(area.Min.X, area.Max.X - sz.X))
	local y = math.clamp(p.Y - sz.Y * 0.5, area.Min.Y, math.max(area.Min.Y, area.Max.Y - sz.Y))
	return Vector2.new(x, y), false
end

--- The line: beside what it speaks of, else in its slot at the left under the top row and the status.
function Tutorial._place(self)
	local ctx = self.ctx
	local ins = ctx.insets
	local c = ctx.compact
	self._text:set_font_size(if c then 13 else 15)
	-- (the last line's two rows are a little longer than a step's)
	local w = if self._ending > 0.0 then 256 elseif c then 200 else 260
	self._text:set_min_size(Vector2.new(w, 0))
	self._body:set_font_size(if c then 12 else 13)
	self._body:set_min_size(Vector2.new(w, 0))
	local side = if ctx.touch then 44.0 else 36.0
	self._skip:set_min_size(Vector2.new(side, side))
	self._next:set_min_size(Vector2.new(64, side))
	self._card:reset_size()
	local sz = self._card:get_combined_minimum_size()
	local y = ins.y + (if c then 62.0 else 74.0)
	-- (never under the status's bottom edge)
	local top = if self.ui ~= nil then self.ui.top else nil
	if top ~= nil and top.visible and not c then
		y = math.max(y, top:bottom_edge() + 8.0)
	end
	local slot = Vector2.new(math.max(ins.x + 8.0, (ctx.rail_w or 0.0) + 8.0), y)
	local area = if ctx.clear_rect ~= nil then ctx:clear_rect() else Rect.new(0, 0, ctx.vp.X, ctx.vp.Y)
	local p, in_slot = Tutorial.spot(self._point, sz, area, slot)
	UICtx.move_node(self._card, Vector2.new(math.floor(p.X), math.floor(p.Y)))
	--- where the line ends, when it stands in its slot (the layout flush has not run yet when the doctrine draft is placed
	--- under it); beside a spot it leaves the draft alone
	self._bottom = if in_slot then math.floor(p.Y) + sz.Y else nil
end

--- The spot the line speaks of moved: it follows when the move is worth following.
function Tutorial._aim_line(self, p: Vector2)
	local on = p.X >= 0.0 and p.Y >= 0.0
	local had = self._point ~= nil
	if on == had and (not on or (p - self._point).Magnitude < Tutorial.FOLLOW_PX) then
		return
	end
	self._point = if on then p else nil
	if self._card.visible then
		self:_place()
	end
end

-- ---------------------------------------------------------------------------------------------
-- What the player did
-- ---------------------------------------------------------------------------------------------

--- The orders sent since the last look: any, an attack on a neighbour, on empty land.
function Tutorial._orders(self): (boolean, boolean, boolean)
	local log = self.ctx.sent_log
	local s = self.ctx.state
	local any, on_owner, on_land = false, false, false
	-- (the log is a window of the last orders: after it wraps, count from its end)
	if self._sent > #log then
		self._sent = 0
	end
	for i = self._sent + 1, #log do
		local it = log[i].intent
		if type(it) == "table" and (it.type == "attack" or it.type == "boat") then
			any = true
			local target = tonumber(it.target)
			if target == nil and type(it.tile) == "number" and s ~= nil then
				target = s:tile_owner(it.tile)
			end
			if target ~= nil and target > 0 then
				on_owner = true
			else
				on_land = true
			end
		end
	end
	self._sent = #log
	return any, on_owner, on_land
end

--- A roomy place to start: of SPAWN_TRIES free land tiles, one far from every nation's start
--- (SPAWN_ROOM tiles is far enough) and away from the map's top and bottom edges (the first pick on
--- the world map was the middle of Antarctica: empty, and nothing to see).
function Tutorial._find_spot(self): number?
	local s = self.ctx.state
	local map = s and s.map
	if map == nil or type(map.land_tile) ~= "function" or (map.land_count or 0) <= 0 then
		return nil
	end
	local starts = {}
	for _, o in s.owners do
		if type(o.spawn_tile) == "number" and o.spawn_tile >= 0 then
			table.insert(starts, o.spawn_tile)
		end
	end
	local best, best_d = nil, -1.0
	for _ = 1, Tutorial.SPAWN_TRIES do
		local t = map:land_tile(math.random(0, map.land_count - 1))
		if map:is_contestable(t) and s:tile_owner(t) == 0 and not map:is_coastal(t) then
			local d = math.huge
			for _, o in starts do
				d = math.min(d, Defs.tile_distance(t, o))
			end
			d = math.min(d, Tutorial.SPAWN_ROOM)
			local W, H = map.W or Defs.W, map.H or Defs.H
			local off = math.abs((t // W) / H - 0.45)
			d -= math.max(0.0, off - 0.27) * 300.0
			if d > best_d then
				best, best_d = t, d
			end
		end
	end
	return best
end

function Tutorial._say(self, i: number, arg: string?)
	local step = Data.STEPS[i]
	local txt = if self.ctx.touch then step.touch else step.desktop
	if string.find(txt, "%s", 1, true) then
		txt = string.format(txt, arg or "them")
	end
	self:_set_pips(step.part or 1, if step.bar then 0.0 else nil)
	self._text:set_text(txt)
	local lesson = step.kind == "lesson"
	self._next_pressed = false
	self._next:set_visible(lesson)
	self._body:set_visible(lesson)
	if lesson then
		self._body:set_text(self:_lesson_body(step))
	end
	self._fill_f = 0.0
	-- (a lesson has nothing to point at; the next spot is found this frame)
	if lesson then
		self._point = nil
	end
	self._card:set_visible(i > 1)
	if i > 1 then
		self:_place()
		UICtx.pop_in(self._card, 0.0, 1.0, 0.18, true)
		-- (a lesson's card is taller than a step's: whatever sits under it moves down)
		if self.ui ~= nil and self.ui.relayout ~= nil then
			self.ui:relayout()
		end
	end
end

--- A lesson's body: its text with the numbers from the rules, then a line per building it names.
function Tutorial._lesson_body(self, step: any): string
	local R = UICtx.core("Rules")
	local text = UIRules.format(step.body or "", {
		city = UITheme.fmt_troops(R.CITY_TROOPS),
		mint = tostring(math.floor(SimLandmarks.MINT_GOLD_BONUS * 100 + 0.5)),
		garrison = tostring(math.floor(SimLandmarks.GARRISON_CAP_BONUS * 100 + 0.5)),
	})
	if step.kinds ~= nil then
		local lines = { text }
		for _, k in step.kinds do
			local blurb = UIRules.blurb(k)
			if self.ctx.compact then
				-- (a phone's card is short on room: the first sentence of each)
				blurb = string.match(blurb, "^[^%.]*%.") or blurb
			end
			table.insert(lines, string.format("%s: %s", UIRules.TITLES[k] or k, blurb))
		end
		text = table.concat(lines, "\n")
	end
	return text
end

--- Step `i` is finished (`passed`: nobody did it in time, it is passed over without a tick).
function Tutorial._advance(self, passed: boolean?)
	local step = Data.STEPS[self._i]
	if not passed then
		self.step_done:Fire(Data.funnel_step(step.id), Data.FUNNEL[Data.funnel_step(step.id)])
		self.ctx:sfx("tick", -6.0)
	end
	self._i += 1
	self._step_t = 0.0
	self._idle = 0.0
	self._shown = nil
	if self._i > #Data.STEPS then
		self.step_done:Fire(#Data.FUNNEL, Data.FUNNEL[#Data.FUNNEL])
		self:stop("done")
	end
end

-- ---------------------------------------------------------------------------------------------
-- Per frame
-- ---------------------------------------------------------------------------------------------

function Tutorial._process(self, delta: number)
	self._t += delta
	if self._ending > 0.0 then
		self._ending -= delta
		if self._ending <= 0.0 then
			self:_close()
		end
		return
	end
	if not self.active then
		return
	end
	local ctx = self.ctx
	local ui = self.ui
	local s = ctx.state
	if s == nil or ctx:mode() ~= UICtx.MODE_SOLO then
		return
	end
	if s.phase == Defs.PHASE_OVER then
		self:stop("left")
		return
	end
	local i = self._i
	local step = Data.STEPS[i]
	local o = ctx:my()
	local any, on_owner, on_land = self:_orders()
	self._step_t += delta
	if
		ctx.troop_floor == nil
		and i >= (Data.step_index(Data.FLOOR_FROM) or 1)
		and o ~= nil
		and Data.floor_armed(o.troops or 0, o.max_troops or 0, ctx:alive_seconds())
	then
		ctx.troop_floor = Data.TROOP_FLOOR
	end
	if not self._started and self._step_t > 1.0 then
		-- the match is up (and reported: the server logs a step for a match it knows of)
		self._started = true
		self.step_done:Fire(1, Data.FUNNEL[1])
	end
	self._idle = if any then 0.0 else self._idle + delta
	local point = Vector2.new(-1, -1)
	--- (a control's radius, when the mark is for one: it goes around it)
	local around: number? = nil
	local id = step.id
	if id == "spawn" then
		if o ~= nil and o.spawned then
			self:_advance()
			return
		end
		if self._spot == nil or self._spot_state ~= s then
			self._spot = self:_find_spot()
			self._spot_state = s
			self._step_t = 0.0
			if self._spot ~= nil then
				-- the camera goes there, close enough that a thumb hits the land around it
				local w = ctx.world
				local d = if w ~= nil and w.rig ~= nil and type(w.rig.scale_to_distance) == "function"
					then w.rig:scale_to_distance(Tutorial.SPAWN_PX)
					else -1.0
				ctx:world_call("focus_tile", { self._spot, d, 0.9 })
			end
		end
		if self._spot ~= nil then
			point = ctx:tile_screen_pos(self._spot)
			if self._step_t > Data.AUTO_SPAWN_S and not self._picked and s:tile_owner(self._spot) == 0 then
				-- nobody picked: this spot is theirs
				self._picked = true
				ctx:send({ type = "spawn", tile = self._spot })
			end
		end
	elseif o ~= nil and o.spawned and o.alive == false then
		self:stop("left") -- (conquered: the result screen takes over)
		return
	elseif o == nil or not ctx:alive_player() or s.phase ~= Defs.PHASE_PLAYING then
		self._mark.Visible = false
		return
	else
		if self._shown ~= i then
			-- the step's line (and what it needs) once, when it comes up
			self._shown = i
			if id == "doctrine" or id == "newage" then
				-- the draft waited folded while the player was on an earlier step: it opens now
				local d = ui.draft
				if d ~= nil and d._row ~= nil and d._collapsed then
					d._collapsed = false
					d:_show()
					ui:relayout()
				end
			elseif id == "attack" then
				self._neighbour = nil
			elseif id == "ratio" then
				self._ratio_ok = 0.0
				self._ratio_high = false
			elseif id == "city" and not self._gold_given then
				self._gold_given = true
				local sim = ctx:session_call("local_sim")
				local cost = ctx.rules:cost("city")
				if sim ~= nil and type(sim.o_gold) == "table" and cost > 0 and (sim.o_gold[ctx:me()] or 0) < cost then
					sim.o_gold[ctx:me()] = cost
				end
			end
			self:_say(i, if self._neighbour ~= nil then s:owner_name(self._neighbour) else nil)
		end
		if step.kind == "lesson" then
			-- (read, then Next; there is no mark)
			if self._next_pressed then
				self:_advance()
				return
			end
		elseif id == "doctrine" then
			local by = if s.doctrine ~= nil then s.doctrine[ctx:me()] else nil
			local row = if by ~= nil then by[1] else nil
			if row ~= nil and row[6] ~= 0 then
				self:_advance()
				return
			end
			-- folded (a phone's short band, or the player pressed Later): the mark goes around the alert row's amber diamond
			local d = ui.draft
			local badge = if ui.alerts ~= nil then ui.alerts:rect_of("draft") else nil
			local folded = d ~= nil and d:folded() and badge ~= nil
			if folded ~= self._folded then
				self._folded = folded
				self._text:set_text(
					if not folded then (if ctx.touch then step.touch else step.desktop)
						elseif ctx.touch then step.chip
						else step.chip_desktop
				)
			end
			if folded and badge ~= nil then
				point = UICtx.rect_center(badge)
				around = math.max(badge.Width, badge.Height) * 0.5
			end
		elseif id == "age" then
			-- the second age comes by itself: the bar counts it in, and a first look at it is the step
			local starts = s.eras
			local since = ctx:render_tick() - (s.playing_since or 0)
			if starts == nil or Eras.index(since, starts) >= 2 then
				self:_advance()
				return
			end
			local f = math.clamp(since / math.max(starts[2], 1), 0, 1)
			if math.abs(f - (self._fill_f or 0.0)) >= 0.005 then
				self._fill_f = f
				self:_set_pips(step.part or 1, f)
			end
		elseif id == "expand" then
			if any then
				self:_advance()
				return
			end
			point = ui.advisor:frontier_point()
		elseif id == "ratio" then
			-- a moderate share, and left there: never a push to send everything
			local r = ctx.ratio
			if r >= Data.RATIO_LOW and r <= Data.RATIO_HIGH then
				self._ratio_ok = (self._ratio_ok or 0.0) + delta
				if self._ratio_ok >= Data.RATIO_HOLD_S then
					self:_advance()
					return
				end
			else
				self._ratio_ok = 0.0
			end
			local high = r > Data.RATIO_HIGH
			if high ~= self._ratio_high then
				self._ratio_high = high
				self._text:set_text(
					if high then Data.RATIO_TOO_MUCH elseif ctx.touch then step.touch else step.desktop
				)
			end
			-- the mark goes around the preset to press (a phone's thumb, the selection window's), or the strip's SEND
			local r = ui.bar:preset_rect(Data.RATIO_GOAL)
			if r ~= nil then
				point = UICtx.rect_center(r)
				around = math.min(r.Width, r.Height) * 0.5
			end
		elseif id == "attack" then
			if on_owner then
				self:_advance()
				return
			end
			if self._neighbour == nil or s:get_owner(self._neighbour) == nil then
				local longest = ctx.borders:longest_front()
				if longest ~= 0 then
					self._neighbour = longest
					self:_say(i, s:owner_name(longest))
				elseif self._step_t > Data.CONTACT_WAIT_S then
					self:_advance(true) -- nobody to attack yet
					return
				else
					-- no neighbour yet: keep growing towards one
					self._text:set_text("No rival in sight yet. Claim on")
					if self._idle > Data.NUDGE_S then
						point = ui.advisor:frontier_point()
					end
				end
			end
			if self._neighbour ~= nil and s:get_owner(self._neighbour) ~= nil then
				point = ctx:tile_screen_pos(s:label_tile(self._neighbour))
			end
		elseif id == "city" then
			for _, st in s.structures do
				if st.owner == ctx:me() and st.kind == Defs.S_CITY then
					self:_advance()
					return
				end
			end
			local cb = ui.bar:button("city")
			local b = if cb ~= nil and cb:is_visible_in_tree() then cb else ui.bar:build_button()
			local pc = ui.place_confirm
			local placing = ui.interact.aim_kind == "city"
			-- (while the City is in hand its plate says what is needed: the line steps aside and only the mark leads on)
			if self._card.visible == placing then
				self._card:set_visible(not placing)
			end
			if pc ~= nil and pc.is_open and pc._ok:is_visible_in_tree() then
				-- a spot is picked: the plate's button builds it
				local r = pc._ok:get_global_rect()
				point = UICtx.rect_center(r)
				around = math.max(r.Width, r.Height) * 0.5
			elseif placing then
				-- the City is in hand: the mark moves to the player's land
				point = ctx:tile_screen_pos(s:label_tile(ctx:me()))
			elseif b ~= nil and b:is_visible_in_tree() then
				local r = b:get_global_rect()
				point = UICtx.rect_center(r)
				around = math.max(r.Width, r.Height) * 0.5
			end
		end
		if self._step_t > (step.max_s or (if step.kind == "lesson" then Data.LESSON_MAX_S else Data.STEP_MAX_S)) then
			self:_advance(true)
			return
		end
	end
	self:_aim_line(point)
	self:_draw_mark(point, around)
end

--- The mark at logical point `p` ((-1, -1): none). `around`: it is for a control of this radius: one ring, pulsing at its
--- edge. Without it, a spot on the map: a flag planted there, with a ring spreading from its foot.
function Tutorial._draw_mark(self, p: Vector2, around: number?)
	local ctx = self.ctx
	local mark = self._mark
	if p.X < 0.0 or p.Y < 0.0 or p.X > ctx.vp.X or p.Y > ctx.vp.Y then
		mark.Visible = false
		return
	end
	ctx:fit_canvas(mark)
	mark.Visible = true
	local k = if UITheme.reduced_motion then 0.4 else (self._t % 1.3) / 1.3
	local inner = if around ~= nil then around + 4.0 else 5.0
	UICtx.set_circle(self._ring, p, inner + 14.0 * k);
	(self._ring:FindFirstChild("Stroke") :: UIStroke).Transparency = 0.1 + 0.9 * k
	local flag = around == nil
	self._pole.Visible = flag
	self._pennant.Visible = flag
	if flag then
		self._pole.Position = UDim2.fromOffset(p.X, p.Y)
		self._pennant.Position = UDim2.fromOffset(p.X + 1, p.Y - Tutorial.FLAG_H)
	end
end

return Tutorial
