--!nonstrict
-- The Chronicle: how a war ends for you. A sheet docked to the left, the map still in view beside it: how it ended in
-- plain words, then a timeline of this match's four ages (what you held in each and the doctrine you drafted), the
-- Renown it earned as one line, and what to do next: Fight again, Return; Watch on while the war goes on, the War report.
-- A nation that conquered you can be seized from here (Takeover.luau): the offer stands in the sheet, its price on
-- its button.
--
-- UIRoot sets log_provider (() -> MatchLog): the ages come from it and the state's doctrine rows.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local UIRules = require("./UIRules") :: any
local HelpOverlay = require("./HelpOverlay")
local DominionStrip = require("./DominionStrip")
local MatchLog = require("./MatchLog")
local Signal = UITheme.core("Signal")
local Defs = UICtx.core("Defs")

local GameOver = W.class(W.Control)

--- The sheet's width: larger screens and phones.
GameOver.W_WIDE = 420.0
GameOver.W_PHONE = 380.0
GameOver.DIM_ALPHA = 0.25

function GameOver.new(c: any)
	local self = setmetatable({}, GameOver.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.play_again = Signal.new()
	self.war_report = Signal.new()
	self.spectate = Signal.new()
	self.to_title = Signal.new()
	--- solo: the Seize button (Takeover.luau)
	self.take_over = Signal.new()
	--- (its button at the foot: what this war earned can be spent right away)
	self.open_arsenal = Signal.new()
	--- () -> MatchLog (UIRoot)
	self.log_provider = nil
	--- the payout shown ({ lines, total, balance })
	self._award = nil :: any
	self._take_info = nil
	self.is_open = false
	self._kind = ""
	self._next_accum = 0.0
	--- The winner line shows the live leader (not a crowned winner): refreshed while the match runs.
	self._pill_live = false
	self._pill_domination = false
	self._dominated = false
	self._pill_id = 0
	self._pill_text = ""
	self._close_tween = nil
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:set_mouse_filter(W.MOUSE_STOP)
	self:set_visible(false)
	-- (see HelpOverlay: an Active frame doesn't stop a press reaching a button behind it, only a button on top does)
	UICtx.make("TextButton", {
		Name = "Blocker",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Active = true,
		Selectable = false,
		ZIndex = 1,
	}, self.gui)
	self._dim = W.ColorRect.new(T.c(T.BLACK, GameOver.DIM_ALPHA))
	self._dim:set_mouse_filter(W.MOUSE_STOP)
	self._dim:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:add_child(self._dim)

	-- the sheet (UIRoot lists `_center` with the HUD: map labels stay clear of it)
	self._center = GlassPanel.new(0.0, 0.0, 0, true, 0)
	self._center:set_tint(T.GLASS_SOLID)
	self:add_child(self._center)
	local sheet = T.vbox(10)
	self._sheet_v = sheet
	self._center:add_child(sheet)
	self._scroll = HelpOverlay.Scroll.new()
	sheet:add_child(self._scroll)
	local body = T.vbox(8)
	body.size_flags_horizontal = W.EXPAND_FILL
	self._body = body
	self._scroll:add_child(body)

	self._title = T.label("WAR OVER", 24, 800, T.TEXT)
	body:add_child(self._title)
	self._sub = T.label("", 13, 500, T.TEXT)
	self._sub:set_autowrap(true)
	body:add_child(self._sub)
	self._winner = T.hbox(6)
	self._crown = T.icon_rect("crown", 14.0, T.GOLD)
	self._crown.size_flags_vertical = W.SHRINK_CENTER
	self._winner:add_child(self._crown)
	self._winner_sw = T.swatch(T.TEXT, 10.0, T.R_SM)
	self._winner:add_child(self._winner_sw)
	self._winner_name = T.label("", 13, 600, T.TEXT_2)
	self._winner:add_child(self._winner_name)
	body:add_child(self._winner)

	self:_build_takeover(body)

	-- the ages
	self._ages_head = T.label("The Chronicle", 13, 800, T.AMBER)
	body:add_child(self._ages_head)
	self._ages = T.vbox(6)
	body:add_child(self._ages)
	-- what it earned, and the plain numbers
	self._renown = T.label("", 14, 700, T.GOLD)
	self._renown:set_visible(false)
	self._renown:set_mouse_filter(W.MOUSE_STOP)
	self._renown.mouse_entered:Connect(function()
		if self._award ~= nil then
			self.ctx:show_hint(self._renown, self:_stars_spec())
		end
	end)
	self._renown.mouse_exited:Connect(function()
		self.ctx:hide_hint(self._renown)
	end)
	body:add_child(self._renown)
	self._stats = T.label("", 12, 500, T.TEXT_2)
	self._stats:set_autowrap(true)
	body:add_child(self._stats)

	-- pinned under the story: what to do next
	self._next = T.label("", 12, 600, T.TEXT_2)
	self._next:set_autowrap(true)
	sheet:add_child(self._next)
	self._buttons = T.hbox(8)
	sheet:add_child(self._buttons)
	self._again = T.button("Next war", "PrimaryButton", "play", 44.0)
	self._again.size_flags_horizontal = W.EXPAND_FILL
	self._again.pressed:Connect(function()
		self.play_again:Fire()
	end)
	self._buttons:add_child(self._again)
	self._home = T.button("Return", "GlassButton", "exit", 44.0)
	self._home.size_flags_horizontal = W.EXPAND_FILL
	self._home.pressed:Connect(function()
		self.to_title:Fire()
	end)
	self._buttons:add_child(self._home)
	self._buttons2 = T.hbox(8)
	sheet:add_child(self._buttons2)
	self._spec = T.button("Watch on", "GhostButton", "eye", 44.0)
	self._spec.size_flags_horizontal = W.EXPAND_FILL
	self._spec.pressed:Connect(function()
		self:close()
		self.spectate:Fire()
	end)
	self._report = T.button("War report", "GhostButton", "globe", 44.0)
	self._report.size_flags_horizontal = W.EXPAND_FILL
	self._report.pressed:Connect(function()
		self.war_report:Fire()
	end)
	self._college = T.button("College", "GhostButton", "arsenal", 44.0)
	self._college.size_flags_horizontal = W.EXPAND_FILL
	self._college.pressed:Connect(function()
		self.open_arsenal:Fire(nil, "over")
	end)
	self._buttons2:add_child(self._spec)
	self._buttons2:add_child(self._report)
	self._buttons2:add_child(self._college)
	self:set_process(true)
	return self
end

--- The offer to seize the nation that conquered you: flat, its price on its button.
function GameOver._build_takeover(self, parent: any)
	local T = UITheme
	self._take = W.Panel.new()
	self._take:set_mouse_filter(W.MOUSE_IGNORE)
	self._take:add_theme_stylebox_override("panel", T.flat(T.GLASS_RAISED, T.R_MD, T.LINE_2, 1, 10.0, 8.0))
	local tv = T.vbox(6)
	self._take:add_child(tv)
	local head = T.hbox(8)
	-- the nation's flag (GameOver.realm_flag), else its colour
	local flag = Instance.new("ImageLabel")
	flag.BackgroundTransparency = 1
	flag.ScaleType = Enum.ScaleType.Fit
	self._take_flag_img = flag
	self._take_flag = W.wrap(flag)
	self._take_flag:set_mouse_filter(W.MOUSE_IGNORE)
	self._take_flag:_part(flag, "ImageTransparency", 1.0)
	self._take_flag:set_min_size(Vector2.new(30, 20))
	self._take_flag.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._take_flag)
	self._take_sw = T.swatch(T.TEXT, 16.0, T.R_SM)
	head:add_child(self._take_sw)
	self._take_title = T.label("Seize", 15, 800, T.TEXT)
	self._take_title.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._take_title)
	tv:add_child(head)
	self._take_sub = T.label("", 12, 500, T.TEXT_2)
	self._take_sub:set_autowrap(true)
	tv:add_child(self._take_sub)
	self._take_line = T.label("", 12, 700, T.TEXT)
	tv:add_child(self._take_line)
	self._take_btn = T.button("Seize", "PrimaryButton", "robux", 44.0)
	self._take_btn.pressed:Connect(function()
		self.take_over:Fire()
	end)
	tv:add_child(self._take_btn)
	self._take:set_visible(false)
	parent:add_child(self._take)
end

--- What the Renown was for: the line's card.
function GameOver._stars_spec(self): { [string]: any }
	local a = self._award
	local StarsData = UICtx.data("Stars")
	local rows = {}
	for _, l in a.lines do
		table.insert(rows, { StarsData.LABELS[l[1]] or l[1], "+" .. UICtx.commas(l[2]), UITheme.GOLD })
	end
	return {
		title = "Renown earned",
		body = "Spend it on doctrines and new ways to fight at the War College.",
		rows = rows,
		hint = string.format("You hold %s Renown", UICtx.commas(a.balance or 0)),
		hint_color = UITheme.GOLD,
		hint_icon = "renown",
	}
end

--- The line for a payout of `total` (nil or 0: none). Pure.
function GameOver.renown_text(total: any): string
	local n = tonumber(total) or 0
	return if n > 0 then string.format("Renown earned: +%s", UICtx.commas(n)) else ""
end

--- The match's payout ({ lines, total, balance }, Session.stars_awarded), or nil.
function GameOver.set_award(self, award: any)
	local text = GameOver.renown_text(if award ~= nil then award.total else nil)
	self._renown:set_visible(text ~= "")
	self._renown:set_text(text)
	if text == "" then
		self._award = nil
		return
	end
	if self._award == award then
		return
	end
	self._award = award
	if self.is_open then
		self.ctx:sfx("star_get")
		self:apply_layout()
	end
end

--- What the match paid the career (Data/Progress.after_match): shown on the War report button.
function GameOver.set_career(self, r: any)
	self._career_gain = if r ~= nil and r.gained > 0 then r.gained else nil
	self._career_news = if r ~= nil then #r.medals + #r.orders + (if r.promoted then 1 else 0) else 0
	-- (a promotion is a moment: it shows on the button itself, not only inside the report; release audit 2026-11-07)
	self._promoted = r ~= nil and r.promoted == true
	if self.is_open then
		self:apply_layout()
	end
end

--- The timeline: one entry per age, a mark for each that this match reached.
function GameOver._fill_ages(self, end_s: number)
	local T = UITheme
	local ctx = self.ctx
	local s = ctx.state
	local log = if self.log_provider ~= nil then self.log_provider() else nil
	local samples = if log ~= nil then log.samples else {}
	local picks = DominionStrip.picks_by_draft(s, ctx:me())
	local ages = MatchLog.chronicle(if s ~= nil then s.eras else nil, samples, picks, end_s)
	for _, ch in ipairs(self._ages:get_children()) do
		self._ages:remove_child(ch)
		ch:queue_free()
	end
	for _, a in ages do
		local row = T.hbox(8)
		local mark = W.ColorRect.new(if a.reached then T.AMBER else T.c(T.WHITE, 0.14))
		mark:set_mouse_filter(W.MOUSE_IGNORE)
		mark:set_min_size(Vector2.new(3, 30))
		row:add_child(mark)
		local v = T.vbox(0)
		v.size_flags_horizontal = W.EXPAND_FILL
		local head = string.format("%s  %s", a.roman, a.name)
		v:add_child(T.label(head, 13, 700, if a.reached then T.TEXT else T.TEXT_3))
		v:add_child(T.label(GameOver.age_line(a), 12, 500, if a.reached then T.TEXT_2 else T.TEXT_3))
		row:add_child(v)
		self._ages:add_child(row)
	end
end

--- What the timeline says of an age. Pure.
function GameOver.age_line(a: any): string
	if not a.reached then
		return "Never reached"
	end
	local parts = {}
	table.insert(parts, if a.held ~= nil then "Held " .. UITheme.fmt_pct(a.held) else "Began at " .. UITheme.fmt_time(a.start_s))
	if a.doctrine ~= nil then
		table.insert(parts, a.doctrine)
	end
	return table.concat(parts, " · ")
end

--- kind: "victory", "defeat", "eliminated" or "result" (the match ended while you were not in it).
--- reason: Defs.OVER_* (ignored for "eliminated"). stats: {peak_share, max_troops, kills, duration_s}
function GameOver.open(self, kind: string, winner: number, killer: number, stats: any, reason: number?)
	-- (a new war's results: not on the way anywhere yet)
	self._returning = false
	self._home:set_disabled(false)
	self._again:set_disabled(false)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	local rsn = reason or -1
	-- Already on screen (e.g. CONQUERED, then the match ends): swap the words in place. A close
	-- fade still in flight would otherwise hide the new screen when it finishes.
	local was_shown = self.visible
	if self._close_tween ~= nil then
		self._close_tween:kill()
		self._close_tween = nil
	end
	self.is_open = true
	self:set_visible(true)
	self:set_modulate_a(1.0)
	self._kind = kind
	local copy = self:_copy(kind, winner, killer, rsn, tonumber(stats.duration_s) or 0.0)
	self._title:set_text(copy.title)
	T.set_font_color(self._title, copy.bottom)
	self._sub:set_text(copy.sub)
	-- Winner line: a real winner gets the crown; otherwise it reads "Now leading".
	local real_winner = (kind == "victory" or kind == "defeat" or kind == "result")
		and winner ~= 0
		and (rsn == Defs.OVER_DOMINATION or rsn == Defs.OVER_TIME or rsn == Defs.OVER_CROWN or rsn == Defs.OVER_PRESTIGE)
	local pill_id = if real_winner then winner else self:_leader_id()
	-- A domination winner's share is the victory metric (land outside poisoned land), like the headline.
	self._pill_domination = real_winner and rsn == Defs.OVER_DOMINATION and self._dominated
	self._pill_live = not real_winner
	self._pill_id = -1
	self._pill_text = ""
	self._crown:set_visible(real_winner)
	self:_set_pill(pill_id)
	-- The match's length: a result reached after an elimination still reports the whole match
	-- (stats.match_s), not the moment the player fell (review R2-6).
	local secs = UIRules.result_seconds(kind, stats)
	-- (the Chronicle under it tells the war, age by age; this is only how long it ran)
	self._stats:set_text(T.fmt_time(secs) .. " of war")
	self:_fill_ages(secs)
	local solo = ctx:mode() == UICtx.MODE_SOLO
	local running = s ~= nil and s.phase == Defs.PHASE_PLAYING
	-- the Renown this match (or this life) paid, if the payout is in already
	local sess = ctx.session
	self:set_award(if sess ~= nil then sess.last_award else nil)
	self._again:set_visible(solo)
	self._spec:set_visible(kind == "eliminated" and running)
	self._next:set_visible(ctx:mode() == UICtx.MODE_MULTI and kind ~= "eliminated")
	self:_refresh_next()
	self:_show_takeover()
	self:apply_layout()
	if not was_shown then
		self._dim:set_modulate_a(0.0)
		W.fade(self._dim, 1.0, 0.2)
		UICtx.pop_in(self._center, 0.0, 1.0, 0.16, true)
	end
	ctx:set_world_input(false)
end

--- The takeover offer (Takeover.refresh): {name, color, price, saved, busy} or nil. Kept, and shown
--- on the CONQUERED screen whenever it is up.
function GameOver.set_takeover(self, info: any)
	self._take_info = info
	if self.is_open then
		self:_show_takeover()
		self:apply_layout()
	end
end

--- Nation names spelled differently from their flag's name (the maps' nations vs the flags' names).
--- A nation's flag on this map: its manifest's key draws it (Art/Emblem draws from any key, the same on every device); a
--- nation in the manifest with no key has its name for one. { item, image } as a flag item's, or nil for a name not on the
--- map (it shows its colour). `nations`: WorldMap.load_nations.
function GameOver.realm_flag(name: string, nations: { any }?): any
	local Cosmetics = UICtx.data("Cosmetics")
	for _, nd in nations or {} do
		if type(nd) == "table" and nd.name == name then
			local it = { emblem = nd.flag or ("realm_" .. string.lower(name)), x = 0, y = 0, w = Cosmetics.FLAG_W, h = Cosmetics.FLAG_H }
			return { item = it, image = Cosmetics.flag_image(it) }
		end
	end
	return nil
end

function GameOver._show_takeover(self)
	local T = UITheme
	local info = self._take_info
	local show = info ~= nil and self._kind == "eliminated"
	self._take:set_visible(show)
	-- one primary button at a time: the offer's (Fight again steps back while it shows)
	local again = if show then "GlassButton" else "PrimaryButton"
	if self._again.theme_type_variation ~= again then
		self._again.theme_type_variation = again
		self._again:_theme_changed()
	end
	if not show then
		return
	end
	local name = tostring(info.name)
	local st = self.ctx.state
	local fl = GameOver.realm_flag(name, if st ~= nil and st.map ~= nil then st.map:load_nations() else nil)
	self._take_flag:set_visible(fl ~= nil)
	self._take_sw:set_visible(fl == nil)
	if fl ~= nil then
		local img = self._take_flag_img
		T.set_image(img, fl.image)
		img.ImageRectOffset = Vector2.new(fl.item.x, fl.item.y)
		img.ImageRectSize = Vector2.new(fl.item.w, fl.item.h)
	elseif info.color ~= nil then
		T.set_swatch_color(self._take_sw, info.color)
	end
	self._take_title:set_text("Seize " .. name)
	self._take_btn:set_disabled(info.busy == true)
	local saved = info.saved > 0
	self._take_sub:set_text(
		if saved
			then "You hold a Seize already. Use it, and " .. name .. " is yours to lead from here."
			else "Lead " .. name .. " from here, with all it holds. The war goes on."
	)
	self._take_btn:set_text(if info.busy then "…" elseif saved then "Claim it now" else string.format("Seize  %d", info.price))
	self._take_btn:set_icon(if saved or info.busy then "" else "robux")
	self:_refresh_take_chips()
end

--- What the offer gives, live: the nation's land, troops and gold.
function GameOver._refresh_take_chips(self)
	local info = self._take_info
	local s = self.ctx.state
	local o = if info ~= nil and s ~= nil then s:get_owner(info.target) else nil
	if o == nil then
		return
	end
	self._take_line:set_text(
		string.format(
			"%s of the land is theirs, with %s troops and %s gold.",
			UITheme.fmt_pct(s:land_share(info.target)),
			UITheme.fmt_troops(tonumber(o.troops) or 0),
			UITheme.fmt_num(tonumber(o.gold) or 0)
		)
	)
end

function GameOver.set_building(self, on: boolean)
	self._again:set_disabled(on)
	self._again:set_text(if on then "Landing…" else "Fight again")
end

--- Fills the winner / leader line for owner `id` (hidden when there is none, and on a triumph).
--- Only touches the label when the text changes (called on every live refresh).
function GameOver._set_pill(self, id: number)
	local s = self.ctx.state
	local wo = if s ~= nil and id ~= 0 then s:get_owner(id) else nil
	local show = wo ~= nil and self._kind ~= "victory"
	if show ~= self._winner.visible then
		self._winner:set_visible(show)
	end
	if wo == nil then
		self._pill_id = id
		return
	end
	local share = if self._pill_domination then self:_win_share(id) else s:land_share(id)
	local prefix = if self._pill_live then "Now leading: " else ""
	local text = string.format("%s%s, %s", prefix, wo.name, UITheme.fmt_pct(share))
	if id ~= self._pill_id then
		UITheme.set_swatch_color(self._winner_sw, wo.color)
	end
	self._pill_id = id
	if text ~= self._pill_text then
		self._pill_text = text
		self._winner_name:set_text(text)
	end
end

--- Share of the land that counts for victory: contestable land outside poisoned land (the Sim wins a
--- nation at Rules.WIN_SHARE of it). Equals land_share when nothing is poisoned.
function GameOver._win_share(self, id: number): number
	local ctx = self.ctx
	if ctx.win_share ~= nil then
		return ctx:win_share(id)
	end
	local s = ctx.state
	return if s ~= nil then s:land_share(id) else 0.0
end

--- "80.1% of all land" / "80.1% of the land outside poison": the victory metric, worded so it
--- can never read as short of the 80% goal while poisoned land shrinks the land that counts (review R2-4).
function GameOver._win_phrase(self, id: number, all_land: string): string
	local s = self.ctx.state
	return UIRules.win_phrase(
		self:_win_share(id),
		if s ~= nil then s:land_share(id) else 0.0,
		if s ~= nil then (tonumber(s.fallout_count) or 0) else 0,
		all_land
	)
end

function GameOver._leader_id(self): number
	local s = self.ctx.state
	if s == nil then
		return 0
	end
	local r = s:ranking()
	return if #r > 0 then r[1].id else 0
end

--- Headline words for every way a match can end, so the screen never claims something untrue.
function GameOver._copy(self, kind: string, winner: number, killer: number, reason: number, secs: number): any
	local ctx = self.ctx
	local s = ctx.state
	local R = UICtx.core("Rules")
	local wname = if s ~= nil and winner ~= 0 then s:owner_name(winner) else "No one"
	local wshare = if s ~= nil and winner ~= 0 then UITheme.fmt_pct(s:land_share(winner)) else "0%"
	-- Domination is decided on the land outside poisoned land (Sim._check_victory): the words use the same
	-- metric, so they always agree with the 80% goal (review R2-4).
	local dominated = s ~= nil and winner ~= 0 and self:_win_share(winner) >= (if s ~= nil and s.win_share ~= nil then s.win_share else R.WIN_SHARE) - 0.0005
	self._dominated = dominated
	local wdom = if s ~= nil and winner ~= 0 then self:_win_phrase(winner, "") else "0%"
	local age = self:_age_words(s)
	local lead = self:_leader_id()
	local lname = if s ~= nil and lead ~= 0 then s:owner_name(lead) else "No one"
	local lshare = if s ~= nil and lead ~= 0 then UITheme.fmt_pct(s:land_share(lead)) else "0%"
	local c = { title = "ENDED IN " .. age, sub = "", bottom = UITheme.TEXT }
	-- a team game: the team won, together
	local wt = if s ~= nil then tonumber(s.winner_team) or 0 else 0
	if kind ~= "eliminated" and wt ~= 0 and ctx.team_share ~= nil then
		local tshare = UITheme.fmt_pct(ctx:team_share(wt))
		local tname = ctx:team_label(wt)
		local the = ctx:team_the(wt)
		if kind == "victory" then
			c.title = "TRIUMPH IN " .. age
			c.bottom = UITheme.AMBER
			c.sub = if reason == Defs.OVER_TIME
				then string.format("At the last hour your side held the most ground: %s.", tshare)
				else string.format("Your side held %s of the land. The war is yours.", tshare)
		else
			c.title = if kind == "defeat" then "LOST IN " .. age else "ENDED IN " .. age
			c.bottom = if kind == "defeat" then UITheme.RED else UITheme.TEXT
			c.sub = if reason == Defs.OVER_TIME
				then string.format("At the last hour %s held the most ground: %s.", string.lower(string.sub(the, 1, 1)) .. string.sub(the, 2), tshare)
				else string.format("This war belongs to %s: %s of the land.", string.lower(string.sub(the, 1, 1)) .. string.sub(the, 2), tshare)
		end
		return c
	end
	if kind == "eliminated" then
		c.title = "FELL IN " .. age
		c.bottom = UITheme.RED
		c.sub = if s ~= nil and killer ~= 0 and killer == self.ctx:me()
			then string.format("Your own %s burned the last of your ground, %s in.", UICtx.data("PeriodTech").word("warhead"), UITheme.fmt_time(secs))
			elseif s ~= nil and killer ~= 0 then string.format("%s has the last of your ground. %s in, your banner came down.", s:owner_name(killer), UITheme.fmt_time(secs))
			else string.format("%s in, your banner came down.", UITheme.fmt_time(secs))
	elseif kind == "victory" then
		c.title = "TRIUMPH IN " .. age
		c.bottom = UITheme.AMBER
		if reason == Defs.OVER_TIME then
			c.sub = string.format("At the last hour the most ground was yours: %s.", wshare)
		elseif reason == Defs.OVER_PRESTIGE then
			c.sub = "At the last hour no realm stood higher in prestige than yours."
		elseif reason == Defs.OVER_CROWN then
			c.sub = "You held the Crown long enough to rule them all."
		else
			c.sub = string.format(
				"You answer to nobody now. You hold %s.",
				if s ~= nil and winner ~= 0 then self:_win_phrase(winner, " of all land") else wshare
			)
		end
	elseif kind == "defeat" then
		c.bottom = UITheme.RED
		c.title = "LOST IN " .. age
		if reason == Defs.OVER_TIME then
			c.title = "THE CLOCK RAN OUT"
			c.sub = string.format("At the last hour the most ground was %s's: %s.", wname, wshare)
		elseif reason == Defs.OVER_PRESTIGE then
			c.title = "THE CLOCK RAN OUT"
			c.sub = string.format("At the last hour %s had the most prestige.", wname)
		elseif reason == Defs.OVER_CROWN then
			c.sub = string.format("%s kept the Crown.", wname)
		elseif dominated then
			c.sub = string.format("The map answers to %s now: %s.", wname, wdom)
		else
			c.sub = string.format("%s holds %s of the land, and the war is theirs.", wname, wshare)
		end
	else
		if reason == Defs.OVER_TIME then
			c.title = "THE CLOCK RAN OUT"
			c.sub = string.format("At the last hour the most ground was %s's: %s.", wname, wshare)
		elseif reason == Defs.OVER_PRESTIGE then
			c.title = "THE CLOCK RAN OUT"
			c.sub = string.format("At the last hour %s had the most prestige.", wname)
		elseif reason == Defs.OVER_CROWN then
			c.sub = string.format("%s kept the Crown.", wname)
		elseif reason == Defs.OVER_DOMINATION then
			c.sub = if dominated
				then string.format("The map answers to %s now: %s.", wname, wdom)
				else string.format("%s holds %s of the land, and the war is theirs.", wname, wshare)
		elseif reason == Defs.OVER_DEFEATED then
			c.sub = string.format("No ruler is left on the map. %s ends it first, on %s.", lname, lshare)
		elseif reason == Defs.OVER_ABANDONED then
			c.sub = string.format("The last ruler walked away. %s ends it first, on %s.", lname, lshare)
		else
			c.sub = string.format("%s ends it first, on %s.", lname, lshare)
		end
	end
	return c
end

--- The age the war ended in, for the end's heading: "THE CONFLICT".
function GameOver._age_words(_self, s: any): string
	local Eras = UICtx.data("Eras")
	local played = if s ~= nil and (s.playing_since or -1) >= 0 then s.tick - s.playing_since else 0
	local i = if s ~= nil and s.eras ~= nil then Eras.index(played, s.eras) else 1
	return "THE " .. string.upper(Eras.NAMES[i] or Eras.NAMES[1])
end

--- Multiplayer: when the next match starts (results timer, then the lobby countdown).
--- On the way back to a hub (Session.returning): the results stay, their way out says so and waits.
function GameOver.set_returning(self)
	self._returning = true
	self._next:set_visible(true)
	self._next:set_text("Returning to camp…")
	self._home:set_disabled(true)
	self._again:set_disabled(true)
end

function GameOver._refresh_next(self)
	if self._returning then
		self._next:set_text("Returning to camp…")
		return
	end
	if not self._next.visible then
		return
	end
	local ctx = self.ctx
	local lb = ctx:lobby()
	local stage = tostring(lb.stage or "")
	local cd = tonumber(lb.countdown_s) or 0.0
	if type(lb.got_at) == "number" then
		cd = math.max(cd - (os.clock() - lb.got_at), 0.0)
	end
	if stage == "over" and lb.kind == "match" then
		-- a public lobby's war is played once: everyone goes back to a hub, never into another war here
		self._next:set_text("Back to camp in " .. UITheme.fmt_time(math.ceil(cd)))
	elseif stage == "over" then
		local rematch = 12.0
		local sess = ctx.session
		if sess ~= nil and type(sess.REMATCH_COUNTDOWN_SEC) == "number" then
			rematch = sess.REMATCH_COUNTDOWN_SEC
		end
		self._next:set_text("Next war in " .. UITheme.fmt_time(math.ceil(cd + rematch)))
	elseif stage == "lobby" then
		self._next:set_text("Next war in " .. UITheme.fmt_time(math.ceil(cd)))
	else
		self._next:set_text("Another war is gathering.")
	end
end

function GameOver.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	local t = self:create_tween()
	self._close_tween = t
	t:tween_property(self, "modulate:a", 0.0, 0.12)
	t:tween_callback(function()
		if self._close_tween == t then
			self._close_tween = nil
		end
		if not self.is_open then
			self:set_visible(false)
			self:set_modulate_a(1.0)
		end
	end)
	self.ctx:set_world_input(true)
end

--- Docked left under the top bar's row; the story scrolls if the screen is too short, the buttons stay.
function GameOver.apply_layout(self)
	local ctx = self.ctx
	local compact = ctx.compact
	local ins = ctx.insets
	local pad = if compact then 12.0 else 18.0
	local bar = ctx.airship_bar or UICtx.rect(0, 0, 0, 0)
	local top = math.max(ins.y, bar.Max.Y) + 4.0
	local w = math.min(if compact then GameOver.W_PHONE else GameOver.W_WIDE, ctx.vp.X - ins.x - ins.z)
	local inner = w - 2.0 * pad
	local p = self._center
	p:set_padding(ins.x + pad, top, pad, ins.w + (if compact then 6.0 else 14.0))
	p:set_anchors(0, 0, 0, 1)
	p:set_offsets(0, 0, ins.x + w, 0)
	self._title:set_font_size(if compact then 20 else 24)
	self._sub:set_min_size(Vector2.new(inner - 14.0, 0))
	self._stats:set_min_size(Vector2.new(inner - 14.0, 0))
	self._next:set_min_size(Vector2.new(inner, 0))
	self._take_sub:set_min_size(Vector2.new(inner - 34.0, 0))
	-- the buttons: phones on one row with short words, larger screens on two
	local gain = if self._promoted then "  ·  PROMOTED"
		elseif self._career_gain ~= nil then string.format("  +%d XP", self._career_gain)
		else ""
	self._report:set_text((if compact then "Report" else "War report") .. gain)
	self._spec:set_text(if compact then "Watch" else "Watch on")
	for _, b in ipairs({ self._again, self._home, self._spec, self._report }) do
		b:set_font_size(if compact then 12 else 14)
		b:set_min_size(Vector2.new(0, 44))
	end
	for _, b in ipairs({ self._spec, self._report }) do
		local on_row = if compact then self._buttons else self._buttons2
		if b.parent ~= on_row then
			if b.parent ~= nil then
				b.parent:remove_child(b)
			end
			on_row:add_child(b)
		end
	end
	self._buttons2:set_visible(not compact)
	-- the story takes what is left
	local foot = 44.0 + (if compact then 0.0 else 54.0) + (if self._next.visible then 26.0 else 0.0) + 10.0
	local bottom = ins.w + (if compact then 6.0 else 14.0)
	self._scroll:set_min_size(Vector2.new(inner, math.max(80.0, ctx.vp.Y - top - bottom - foot)))
	self._body:set_min_size(Vector2.new(inner - 14.0, 0))
	p:_layout_free()
end

function GameOver._process(self, delta: number)
	if not self.is_open then
		return
	end
	self._next_accum += delta
	if self._next_accum >= 0.25 then
		self._next_accum = 0.0
		self:_refresh_next()
		-- CONQUERED while the war goes on: the leader line follows the race
		-- (review R2-2; the original kept the snapshot taken when the screen opened).
		local s = self.ctx.state
		if self._pill_live and s ~= nil and s.phase == Defs.PHASE_PLAYING then
			self:_set_pill(self:_leader_id())
		end
		if self._take.visible then
			self:_refresh_take_chips()
		end
	end
end

return GameOver
