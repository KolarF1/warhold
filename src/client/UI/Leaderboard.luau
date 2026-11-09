--!nonstrict
-- Standings: hidden until asked for (Tab, the status bar's tap, or the top row's button), then a sheet from the right
-- edge: Rank, Nation, Land. Troops come on demand (the Troops chip in its head), so what it shows first is the race
-- itself. Your own row is pinned when you are outside the rows that fit; pact partners and oathbreakers are marked. A
-- row's tap takes the camera to that nation. Game admins see a person icon on real players' rows, and every real player
-- outside the top is pinned below it (one click away).
--
-- Every match starts with it closed (close_for_match). It stays as the player leaves it until the match ends.
--
-- Signals: toggled(open). Members: panel, _pill (never shown now; UIRoot lists it with the HUD), expanded, user_hidden.
-- Methods: set_open(on), toggle(), close_for_match(), apply_layout(top), sheet_width(), bottom_edge(), my_rank(),
-- mark_dirty(), refresh(); per frame update(dt).

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local BotPortrait = require("./BotPortrait")
local Cosmetics: any = if typeof(game) == "Instance"
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Cosmetics)
	else (require :: any)("../../shared/Data/Cosmetics")
local Signal = UITheme.core("Signal")

local Leaderboard = W.class(W.Control)

--- The most rows (fewer when the screen is shorter: rows_that_fit).
Leaderboard.ROWS = 20
--- The sheet's width: larger screens and phones.
Leaderboard.W_WIDE = 300.0
Leaderboard.W_PHONE = 270.0
Leaderboard.ROW_H = 26.0
Leaderboard.ROW_H_TOUCH = 44.0
--- Seconds the sheet takes to come in (none under reduced motion).
Leaderboard.SLIDE_S = 0.16

--- How many rows fit a sheet `height` tall with `chrome` px of head and padding, a line left for your pinned row. Pure.
function Leaderboard.rows_that_fit(height: number, chrome: number, row_h: number): number
	return math.clamp(math.floor((height - chrome) / row_h) - 1, 1, Leaderboard.ROWS)
end

--- Game admins: real players outside the top rows pinned below them (desktop / phones).
Leaderboard.ADMIN_PINS = 8
Leaderboard.ADMIN_PINS_COMPACT = 3
-- ---------------------------------------------------------------------------------------------
-- Row
-- ---------------------------------------------------------------------------------------------

local Row = W.class(W.Button)
Leaderboard.Row = Row

function Row.new(c: any)
	local self = setmetatable({}, Row.__mt)
	W.Control._init(self, "TextButton")
	W.Button._init_button(self, "", "GlassButton")
	local T = UITheme
	self.ctx = c
	self.owner_id = 0
	self.is_me = false
	self.flat = true
	self:set_min_size(Vector2.new(0, Leaderboard.ROW_H))
	for _, st in ipairs(W.BUTTON_STATES) do
		self:add_theme_stylebox_override(st, T.empty_box())
	end
	self._sv.inset = { 2, 1, 2, 1 }
	local h = T.hbox(8)
	h:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	h.offset_left = 10.0
	h.offset_right = -10.0
	self:add_child(h)
	self.rank = T.label("1", 12, 600, T.TEXT_3)
	T.fix_width(self.rank, 26.0, W.ALIGN_RIGHT)
	self.rank.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(self.rank)
	self.sw = T.swatch(T.TEXT, 10.0, T.R_SM)
	h:add_child(self.sw)
	-- the owner's flag (Data/Cosmetics), when one is equipped: placed to the left of the head shot
	-- (2026-10-22)
	local fimg = Instance.new("ImageLabel")
	fimg.BackgroundTransparency = 1
	fimg.ScaleType = Enum.ScaleType.Fit
	self._flag_img = fimg
	self.flag = W.wrap(fimg)
	self.flag:set_min_size(Vector2.new(18, 12))
	self.flag.size_flags_vertical = W.SHRINK_CENTER
	self.flag:set_mouse_filter(W.MOUSE_IGNORE)
	self.flag:set_visible(false)
	self._flag_id = ""
	h:add_child(self.flag)
	-- a person's Roblox head shot (the cosmetics map's `face`; 2026-10-04): a small profile picture
	-- next to each name
	local himg = Instance.new("ImageLabel")
	himg.BackgroundColor3 = T.color3(T.GLASS_RAISED)
	himg.BorderSizePixel = 0
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0.5, 0)
	hc.Parent = himg
	self._face_img = himg
	self.face = W.wrap(himg)
	self.face:set_min_size(Vector2.new(18, 18))
	self.face.size_flags_vertical = W.SHRINK_CENTER
	self.face:set_mouse_filter(W.MOUSE_IGNORE)
	self.face:set_visible(false)
	self._face_id = 0
	h:add_child(self.face)
	self.name_l = T.label("", 13, 600)
	self.name_l.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self.name_l.size_flags_horizontal = W.EXPAND_FILL
	self.name_l:set_min_size(Vector2.new(40, 0))
	self.name_l.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(self.name_l)
	self.mark = T.icon_rect("alliance", 13.0, T.GREEN)
	self.mark.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(self.mark)
	-- game admins only: a person icon on real players' rows (Session.admin_bots; nobody else gets it)
	self.human = T.icon_rect("users", 13.0, T.CYAN)
	self.human.size_flags_vertical = W.SHRINK_CENTER
	self.human:set_visible(false)
	h:add_child(self.human)
	self.land = T.label("", 13, 700)
	T.fix_width(self.land, T.text_width("88.8%", 13, 700) + 2.0, W.ALIGN_RIGHT)
	self.land.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(self.land)
	self.troops = T.label("", 12, 500, T.TEXT_2)
	T.fix_width(self.troops, T.text_width("888.8k", 12, 500) + 2.0, W.ALIGN_RIGHT)
	self.troops.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(self.troops)
	self.mouse_entered:Connect(function()
		if self.ctx.touch then
			return
		end
		self.ctx:world_call("set_hover_owner", { self.owner_id })
		self:_redraw()
	end)
	self.mouse_exited:Connect(function()
		self.ctx:world_call("set_hover_owner", { 0 })
		self:_redraw()
	end)
	self.pressed:Connect(function()
		if self.owner_id ~= 0 then
			local ctx = self.ctx
			ctx:sfx("click")
			-- fly there, and read them: the rival's card comes with it (UIRoot)
			ctx:world_call("focus_owner", { self.owner_id })
			if ctx.read_owner ~= nil then
				ctx.read_owner(self.owner_id)
			end
		end
	end)
	return self
end

function Row.set_row(self, o: any, r: number)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	self.owner_id = o.id
	self.is_me = o.id == ctx:me()
	self.rank:set_text(tostring(r))
	T.set_swatch_color(self.sw, o.color)
	local cz = s.cosmetics and s.cosmetics[o.id]
	local face = if cz ~= nil and cz.face ~= nil then cz.face else 0
	if face ~= self._face_id or self._face_stale then
		self._face_id = face
		self._face_stale = false
		self._face_col = UITheme.color3(o.color)
		-- (a bot player: its made-up avatar, UI/BotPortrait; a person: their head shot)
		if not BotPortrait.apply(self._face_img, face, self._face_col) then
			UITheme.set_image(self._face_img, if face ~= 0 then Cosmetics.face_image(face) else "")
		end
		self.face:set_visible(face ~= 0)
	end
	local fid = if cz ~= nil and cz.flag ~= nil then cz.flag else ""
	if fid ~= self._flag_id then
		self._flag_id = fid
		local it = if fid ~= "" then Cosmetics.item(fid) else nil
		if it ~= nil and it.kind == "flag" then
			UITheme.set_image(self._flag_img, Cosmetics.flag_image(it))
			self._flag_img.ImageRectOffset = Vector2.new(it.x, it.y)
			self._flag_img.ImageRectSize = Vector2.new(it.w, it.h)
			self.flag:set_visible(true)
		else
			self.flag:set_visible(false)
		end
	end
	self.land:set_text(T.fmt_pct(s:land_share(o.id)))
	-- Who could swallow you: a neighbour with more land than you and twice your army. A mark on the row, not a colour alone.
	local mine = ctx:my()
	local threat = mine ~= nil
		and not self.is_me
		and mine.troops > 0
		and o.troops > 2 * mine.troops
		and s:land_share(o.id) > s:land_share(ctx:me())
		and not s:are_allies(ctx:me(), o.id)
		and ctx.borders ~= nil
		and ctx.borders:borders_owner(o.id)
	self.troops:set_text(T.fmt_troops(o.troops))
	T.set_font_color(self.troops, T.TEXT_2)
	self.name_l:set_text(o.name)
	local ally = s:are_allies(ctx:me(), o.id)
	local traitor = s:is_traitor(o.id)
	self.mark:set_visible(ally or traitor or threat)
	if threat and not (ally or traitor) then
		self.mark:set_icon("target")
		self.mark:set_color(T.ORANGE)
	elseif traitor then
		self.mark:set_icon("betray")
		self.mark:set_color(T.RED)
	elseif ally then
		self.mark:set_icon("alliance")
		self.mark:set_color(T.GREEN)
	end
	local nc = T.TEXT
	if self.is_me then
		nc = T.AMBER_HI
	elseif traitor then
		nc = T.RED
	end
	T.set_font_color(self.name_l, nc)
	T.set_font_color(self.rank, if r == 1 then T.GOLD else T.TEXT_3)
	self.human:set_visible(Leaderboard.is_real_player(ctx, o))
	self:_redraw()
end

function Row._draw_state(self)
	self:_redraw()
end

function Row._draw(self)
	self:_redraw()
end

function Row._redraw(self)
	if self.ctx == nil then
		return
	end
	local T = UITheme
	if self.is_me then
		self._sv:set(T.flat(T.c(T.AMBER, 0.12), T.R_SM, T.c(T.AMBER, 0.35), 1))
	elseif self._hover and not self.ctx.touch then
		self._sv:set(T.flat(T.rgba(1, 1, 1, 0.07), T.R_SM))
	elseif self._sv.style ~= nil then
		self._sv:set(nil)
	end
end

-- ---------------------------------------------------------------------------------------------
-- Leaderboard
-- ---------------------------------------------------------------------------------------------

--- Game admins only (Session.admin_bots): a real player, not a bot filling the lobby.
function Leaderboard.is_real_player(ctx: any, o: any): boolean
	local bots = if ctx.session ~= nil then ctx.session.admin_bots else nil
	return bots ~= nil and o.kind == UITheme.core("Defs").KIND_HUMAN and not bots[o.id]
end

function Leaderboard.new(c: any)
	local self = setmetatable({}, Leaderboard.__mt)
	W.Control._init(self)
	local T = UITheme
	self.ctx = c
	self.toggled = Signal.new()
	self.expanded = false
	self.user_hidden = false
	self._rows = {}
	self._accum = 0.0
	self._dirty = true
	--- Troops are on demand: the chip in the head.
	self.show_troops = false
	--- How many rows fit (rows_that_fit, from apply_layout).
	self._fit = 8
	--- The sheet's slide: px still to come in, and the base offsets.
	self._slide = 0.0
	self._right = 0.0
	self._width = Leaderboard.W_WIDE
	--- Phones: no separate rank pill (the status panel shows the rank and opens the board).
	self.pill_enabled = true
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self.panel = GlassPanel.new(8.0, 6.0, 0, true, 0)
	self.panel:set_tint(T.GLASS_SOLID)
	self:add_child(self.panel)
	local v = T.vbox(4)
	self.panel:add_child(v)

	self._header = T.hbox(8)
	local hm = W.Margin.new()
	hm:set_mouse_filter(W.MOUSE_IGNORE)
	hm:add_theme_constant_override("margin_left", 10)
	hm:add_theme_constant_override("margin_right", 4)
	hm:add_child(self._header)
	self._header:add_child(T.label("Standings", 15, 800, T.TEXT))
	local sp = W.Control.new()
	sp.size_flags_horizontal = W.EXPAND_FILL
	sp:set_mouse_filter(W.MOUSE_IGNORE)
	self._header:add_child(sp)
	-- game admins only: show just the real players
	self.humans_only = false
	local hf = T.button("PLAYERS", "ChipButton", "", 22.0)
	hf.toggle_mode = true
	hf:set_font_size(10)
	hf.pressed:Connect(function()
		self.humans_only = hf.button_pressed
		self:mark_dirty()
	end)
	hf:set_visible(false)
	self._humans_btn = hf
	self._header:add_child(hf)
	-- Troops, on demand
	local tb = T.button("Troops", "ChipButton", "", 26.0)
	tb.toggle_mode = true
	tb:set_font_size(12)
	tb.pressed:Connect(function()
		self.show_troops = tb.button_pressed
		self:_apply_troops()
		self:refresh()
	end)
	self._troops_btn = tb
	self._header:add_child(tb)
	local close = W.Button.new("", "GhostButton")
	close:set_icon("close")
	close.expand_icon = true
	close:set_min_size(Vector2.new(26, 26))
	close:add_theme_constant_override("icon_max_width", 11)
	close:add_theme_stylebox_override("normal", T.empty_box(6, 6))
	close:add_theme_stylebox_override("hover", T.flat(T.FILL, 6, T.CLEAR, 0, 6, 6))
	close.pressed:Connect(function()
		self:set_open(false)
	end)
	self._close = close
	self._header:add_child(close)
	v:add_child(hm)

	self._cols = T.hbox(8)
	local cm = W.Margin.new()
	cm:set_mouse_filter(W.MOUSE_IGNORE)
	cm:add_theme_constant_override("margin_left", 10)
	cm:add_theme_constant_override("margin_right", 10)
	cm:add_child(self._cols)
	local c1 = T.label("Rank", 12, 500, T.TEXT_3)
	c1:set_min_size(Vector2.new(T.text_width("Rank", 12, 500) + 2.0, 0))
	self._cols:add_child(c1)
	local c2 = T.label("Nation", 12, 500, T.TEXT_3)
	c2.size_flags_horizontal = W.EXPAND_FILL
	c2:set_min_size(Vector2.new(18, 0))
	self._cols:add_child(c2)
	local c3 = T.label("Land", 12, 500, T.TEXT_3)
	c3:set_min_size(Vector2.new(T.text_width("88.8%", 13, 700) + 2.0, 0))
	c3.horizontal_alignment = W.ALIGN_RIGHT
	self._cols:add_child(c3)
	local c4 = T.label("Troops", 12, 500, T.TEXT_3)
	c4:set_min_size(Vector2.new(T.text_width("888.8k", 12, 500) + 2.0, 0))
	c4.horizontal_alignment = W.ALIGN_RIGHT
	self._c_troops = c4
	c4:set_visible(false)
	self._cols:add_child(c4)
	v:add_child(cm)
	self._cols_margin = cm
	v:add_child(T.hdivider())

	self._list = T.vbox(0)
	v:add_child(self._list)
	for _ = 1, Leaderboard.ROWS do
		local r = Row.new(c)
		r.troops:set_visible(false)
		table.insert(self._rows, r)
		self._list:add_child(r)
	end
	-- (between the top and your own row: how many stand between)
	self._pin_sep = T.label("", 11, 600, T.TEXT_3)
	self._pin_sep.horizontal_alignment = W.ALIGN_CENTER
	self._list:add_child(self._pin_sep)
	--- rows pinned below the top: yours, and (admins) real players; grown on demand
	self._pins = {}
	self._pin_more = T.label("", 11, 600, T.TEXT_3)
	self._pin_more.horizontal_alignment = W.ALIGN_CENTER
	self._pin_more:set_visible(false)
	self._list:add_child(self._pin_more)

	local pill = W.Button.new("", "GlassButton")
	pill:set_icon("leaderboard")
	pill:add_theme_constant_override("icon_max_width", 16)
	pill:set_min_size(Vector2.new(0, 40))
	pill:add_theme_stylebox_override("normal", T.flat(T.GLASS, T.R_MD, T.LINE, 1, 14, 6))
	pill:add_theme_stylebox_override("hover", T.flat(T.GLASS_RAISED, T.R_MD, T.LINE_2, 1, 14, 6))
	pill:add_theme_stylebox_override("pressed", T.flat(T.GLASS_RAISED, T.R_MD, T.LINE_2, 1, 14, 6))
	pill:add_theme_stylebox_override("hover_pressed", T.flat(T.GLASS_RAISED, T.R_MD, T.LINE_2, 1, 14, 6))
	pill:set_font_size(13)
	pill.pressed:Connect(function()
		self:set_open(true)
	end)
	self._pill = pill
	self:add_child(pill)
	pill:set_visible(false)
	return self
end

function Leaderboard.set_open(self, on: boolean)
	local ctx = self.ctx
	local was = self.expanded
	self.expanded = on
	self.user_hidden = not on
	self:_apply_visibility()
	if on and not was then
		self._slide = if UITheme.reduced_motion then 0.0 else self._width
		self:_place_sheet()
		ctx:sfx("open", -8.0)
	elseif not on and was then
		ctx:sfx("close", -8.0)
	end
	self:refresh()
	if on ~= was then
		self.toggled:Fire(on)
	end
end

function Leaderboard.toggle(self)
	self:set_open(not self.expanded)
end

--- A new match: the board is closed, without the sound or the signal of a player closing it.
function Leaderboard.close_for_match(self)
	self.expanded = false
	self.user_hidden = false
	self:_apply_visibility()
end

function Leaderboard._apply_visibility(self)
	self.panel:set_visible(self.expanded)
	self._pill:set_visible(not self.expanded and self.pill_enabled)
	if not self.expanded then
		-- a closed board gives its bots' avatar viewports back (UI/BotPortrait's cap); set_row draws them again
		for _, list in { self._rows or {}, self._pins or {} } do
			for _, r in ipairs(list) do
				if r._face_id ~= nil and r._face_id < 0 and not r._face_stale then
					BotPortrait.apply(r._face_img, r._face_id, r._face_col, false)
					r._face_stale = true
				end
			end
		end
	end
end

--- The sheet's width on this screen (Fronts move out from under it).
function Leaderboard.sheet_width(self): number
	return if self.ctx.compact then Leaderboard.W_PHONE else Leaderboard.W_WIDE
end

--- Docked to the right edge, full height; `_slide` px of it still off screen.
function Leaderboard._place_sheet(self)
	local p = self.panel
	p.anchor_left, p.anchor_right, p.anchor_top, p.anchor_bottom = 1.0, 1.0, 0.0, 1.0
	p.offset_left = -self._width + self._slide
	p.offset_right = self._slide
	p.offset_top, p.offset_bottom = 0.0, 0.0
	p:queue_layout()
end

--- Troops on demand: the column shows on every row, or on none.
function Leaderboard._apply_troops(self)
	self._c_troops:set_visible(self.show_troops)
	for _, r in ipairs(self._rows) do
		r.troops:set_visible(self.show_troops)
	end
	for _, r in ipairs(self._pins) do
		r.troops:set_visible(self.show_troops)
	end
end

function Leaderboard.apply_layout(self, _top: number?)
	local ctx = self.ctx
	self.pill_enabled = false
	self._width = self:sheet_width()
	local row_h = if ctx.touch then Leaderboard.ROW_H_TOUCH else Leaderboard.ROW_H
	-- (its words stay clear of the notch and of Roblox's corner)
	self.panel:set_padding(8.0, 6.0 + ctx.insets.y, 8.0 + ctx.insets.z, 6.0 + ctx.insets.w)
	self._width += ctx.insets.z
	self:_place_sheet()
	self._c_troops:set_visible(self.show_troops)
	for _, r in ipairs(self._rows) do
		r:set_min_size(Vector2.new(0, row_h))
	end
	for _, r in ipairs(self._pins) do
		r:set_min_size(Vector2.new(0, row_h))
	end
	self._close:set_min_size(if ctx.touch then Vector2.new(44, 44) else Vector2.new(26, 26))
	self._troops_btn:set_min_size(Vector2.new(if ctx.touch then 64 else 56, if ctx.touch then 44 else 26))
	-- head + column names + padding
	local chrome = 12.0 + ctx.insets.y + ctx.insets.w + (if ctx.touch then 44.0 else 26.0) + 18.0 + 12.0
	self._fit = Leaderboard.rows_that_fit(ctx.vp.Y, chrome, row_h)
	self:_apply_visibility()
	self._dirty = true
end

function Leaderboard.bottom_edge(self): number
	if self.panel.visible then
		return self.panel:get_rect().Max.Y
	end
	if self._pill.visible then
		return self._pill:get_rect().Max.Y
	end
	return -1.0
end

--- My rank (1-based) for other panels; 0 when unranked.
function Leaderboard.my_rank(self): number
	local ctx = self.ctx
	if ctx.state == nil or ctx:me() == 0 then
		return 0
	end
	return ctx:rank_of(ctx:me())
end

function Leaderboard.mark_dirty(self)
	self._dirty = true
end

function Leaderboard.refresh(self)
	local ctx = self.ctx
	self._dirty = false
	local s = ctx.state
	if s == nil then
		return
	end
	local admin = ctx.session ~= nil and ctx.session.admin_bots ~= nil
	self._humans_btn:set_visible(admin)
	local humans_only = admin and self.humans_only
	-- Closed (every match starts so): only the pill can show (not on a phone); the rows and the panel
	-- are filled when it opens (set_open). (2026-10-27: a closed board sorted the ranking, filled its
	-- hidden rows and laid its hidden panel out every second.)
	if not self.expanded and not humans_only then
		local me = ctx:me()
		self:_set_pill(if me ~= 0 then ctx:rank_of(me) else 0, ctx:leader())
		return
	end
	local ranking = s:ranking()
	if humans_only then
		local only = {}
		for _, o in ipairs(ranking) do
			if Leaderboard.is_real_player(ctx, o) then
				table.insert(only, o)
			end
		end
		ranking = only
	end
	local me = ctx:me()
	local shown = math.min(self._fit, #ranking)
	local my_rank = -1
	for i, o in ipairs(ranking) do
		if o.id == me then
			my_rank = i
			break
		end
	end
	for i, r in ipairs(self._rows) do
		r:set_visible(i <= shown)
		if i <= shown then
			r:set_row(ranking[i], i)
		end
	end
	-- pinned below the top: your own row, and for admins the real players (up to a cap)
	local cap = if ctx.compact then Leaderboard.ADMIN_PINS_COMPACT else Leaderboard.ADMIN_PINS
	local pins, humans, more = {}, 0, 0
	for i = shown + 1, #ranking do
		local o = ranking[i]
		if o.id == me and me ~= 0 then
			table.insert(pins, i)
		elseif Leaderboard.is_real_player(ctx, o) then
			if humans < cap then
				humans += 1
				table.insert(pins, i)
			else
				more += 1
			end
		end
	end
	for j, i in ipairs(pins) do
		local r = self._pins[j]
		if r == nil then
			r = Row.new(ctx)
			r:set_min_size(Vector2.new(0, if ctx.touch then Leaderboard.ROW_H_TOUCH else Leaderboard.ROW_H))
			r.troops:set_visible(self.show_troops)
			self._pins[j] = r
			self._list:add_child(r)
			self._list:move_child(self._pin_more, -1)
		end
		r:set_visible(true)
		r:set_row(ranking[i], i)
	end
	for j = #pins + 1, #self._pins do
		self._pins[j]:set_visible(false)
		self._pins[j].owner_id = 0
	end
	-- ranks between the top rows and the first row pinned under them
	local between = if #pins > 0 then pins[1] - Leaderboard.ROWS - 1 else 0
	self._pin_sep:set_visible(between > 0)
	if between > 0 then
		self._pin_sep:set_text(string.format("%d %s between", between, if between == 1 then "realm" else "realms"))
	end
	self._pin_more:set_visible(more > 0)
	if more > 0 then
		self._pin_more:set_text(string.format("+%d other %s", more, if more == 1 then "player" else "players"))
	end
	self:_refresh_teams()
	self:_set_pill(my_rank, ranking[1])
end

--- The pill: my rank (`my_rank` > 0) and land, else the leader's name (cut to 10 characters) and
--- land. (Written when it changed: a button's text lays the HUD out again even when it is the same.)
function Leaderboard._set_pill(self, my_rank: number, leader: any)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	local text = "Standings"
	if my_rank > 0 then
		text = string.format("#%d  ·  %s", my_rank, T.fmt_pct(s:land_share(ctx:me())))
	elseif leader ~= nil then
		local nm = leader.name
		if utf8.len(nm) and (utf8.len(nm) :: number) > 10 then
			local cut = utf8.offset(nm, 10)
			nm = string.sub(nm, 1, (cut or 10) - 1) .. "…"
		end
		text = string.format("%s  %s", nm, T.fmt_pct(s:land_share(leader.id)))
	end
	if text ~= self._pill.text then
		self._pill:set_text(text)
	end
end

--- A team game (Core/Teams): the teams above the players, by land: the
--- team's colour, its name and its share of the land that counts; the
--- player's own team in its colour. Phones show the top 3 (and the player's team).
Leaderboard.TEAM_ROWS = 7
function Leaderboard._refresh_teams(self)
	local ctx = self.ctx
	local T = UITheme
	local s = ctx.state
	local on = s ~= nil and type(s.is_team_game) == "function" and s:is_team_game()
	if not on then
		if self._team_box ~= nil then
			self._team_box:set_visible(false)
		end
		return
	end
	if self._team_box == nil then
		self._team_box = T.vbox(2)
		self._list:add_child(self._team_box)
		self._list:move_child(self._team_box, 0)
	end
	local box = self._team_box
	box:set_visible(true)
	for _, ch in ipairs(box:get_children()) do
		box:remove_child(ch)
		ch:queue_free()
	end
	local mine = if ctx:me() ~= 0 then s:team_of(ctx:me()) else 0
	local teams = s:team_ranking()
	local limit = if ctx.compact then 3 else Leaderboard.TEAM_ROWS
	for i, r in ipairs(teams) do
		if i > limit and r.team ~= mine then
			continue
		end
		local row = T.hbox(6)
		row:set_min_size(Vector2.new(0, 22))
		local col = s:team_color(r.team)
		local sw = T.swatch(col, 10.0, T.R_SM)
		sw.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(sw)
		local nm = T.label(ctx:team_label(r.team), 12, if r.team == mine then 800 else 600, if r.team == mine then T.owner_ui_color(col) else T.TEXT)
		nm.size_flags_horizontal = W.EXPAND_FILL
		nm.size_flags_vertical = W.SHRINK_CENTER
		nm.text_overrun_behavior = W.OVERRUN_ELLIPSIS
		nm.clip_text = true
		row:add_child(nm)
		local sh = T.label(T.fmt_pct(ctx:team_share(r.team)), 12, 700, T.TEXT)
		sh.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(sh)
		box:add_child(row)
	end
	local sep = T.hdivider()
	box:add_child(sep)
end

--- Per frame (GDScript _process).
function Leaderboard.update(self, delta: number)
	if self._slide > 0.0 then
		self._slide = math.max(0.0, self._slide - delta * self._width / Leaderboard.SLIDE_S)
		self:_place_sheet()
	end
	self._accum += delta
	if self._accum >= 1.0 and self:is_visible_in_tree() and self._dirty then
		self._accum = 0.0
		self:refresh()
	end
end

return Leaderboard
