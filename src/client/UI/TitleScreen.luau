--!nonstrict
-- Warhold's title over the calm map: one column down the left edge (the name, who you are, the way into a campaign, and
-- a row per place to go, each reading its state from the session), the war board at the map's corner, credits. Windows
-- open as sheets against the column's right edge (UI/Sheet, through ctx.title_nav). Also shows the muster (the waiting
-- room) while a match is being prepared.
--
-- The war board shows one war at a time, the one that marches soonest: what kind of war it is, who is in, and one button
-- that marches. "+2" turns to the next. It seats through the same lobby system as ever (Session.join_public).
--
-- Also defines GradientText (the wordmark / end screen headline): per-glyph text with letter spacing.
-- Roblox caps TextSize at 100, so glyphs render at a smaller TextSize under a UIScale.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UIMaps = require("./UIMaps")
local UICtx = require("./UICtx")
local Cadence = require("../Audio/Cadence")
local FlagShop = require("./FlagShop")
local ShopHub = require("./ShopHub")
local PartyPanel = require("./PartyPanel")
local Prices = require("./Prices")
local Sheet = require("./Sheet")
local ShopArt = if typeof(game) == "Instance"
	then require((game:GetService("ReplicatedStorage"):WaitForChild("Airfront") :: any):WaitForChild("Assets"):WaitForChild("ShopArt"))
	else (require :: any)("../../shared/Assets/ShopArt")
local Scroll = (require("./HelpOverlay") :: any).Scroll
local Signal = UITheme.core("Signal")
local Teams = UITheme.core("Teams")

local TitleScreen = W.class(W.Control)

-- =============================================================================================
-- GradientText
-- =============================================================================================

local GradientText = W.class(W.Control)
TitleScreen.GradientText = GradientText
--- The credits line at the foot of the menu column (desktop, phones): the notice OpenFront's licence asks to keep in a
--- reasonably visible place such as the main menu (LICENSE, additional terms, 7(b)). The full notices and the source are
--- in the Field Guide, a row of the same column. (2026-11-08, the owner: no bar across the bottom of the home screen.)
TitleScreen.CREDITS = "© OpenFront and Contributors  ·  GNU AGPL v3"
TitleScreen.CREDITS_SHORT = TitleScreen.CREDITS

--- The menu's foot: the licence line, then the version this server runs (Data/Version; 2026-11-08, the owner: a way to
--- see an update arrived, as a proper version number). A server older than the latest publish shows the older version
--- until it closes.
function TitleScreen.footer_text(room: number?): string
	local v = "v" .. tostring(UICtx.data("Version").VERSION)
	local one = TitleScreen.CREDITS .. "  ·  " .. v
	-- (where one line can't hold both, the version takes the next line on its own, never one that starts with "·")
	if room ~= nil and UITheme.measure_text(one, math.max(11, UITheme.min_font_size), 500, 1) > room then
		return TitleScreen.CREDITS .. "\n" .. v
	end
	return one
end

local SHINE_HALF = 70.0 -- smoothstep(0, 70, |x - sweep - (y - y0) * 0.35|)

function GradientText.new(text: string, px: number, weight: number?)
	local self = setmetatable({}, GradientText.__mt)
	W.Control._init(self)
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self.text = text
	self.px = px
	self.weight = weight or 900
	self.spacing = 0
	self.top_color = UITheme.WHITE
	self.bottom_color = UITheme.DIAL_AMBER_HI -- the HUD's light amber
	self.y0 = 0.0 -- gradient start (logical px from the top of the line)
	self.span = 100.0
	self.sweep = -10000.0 -- shine centre x (logical px), off by default
	self.shine = 0.4
	self.shadow = { color = Color3.new(0.0, 0.02, 0.08), alpha = 0.55, offset_y = 6, outline = 14 }
	local canvas = UICtx.canvas(self.gui, "Word")
	canvas.ZIndex = 1
	self._canvas = canvas
	local inner = UICtx.frame(canvas)
	inner.Name = "Inner"
	self._inner = inner
	self._inner_scale = UICtx.make("UIScale", { Scale = 1 }, inner)
	self._glyphs = {}
	self._ts = 1
	self:_rebuild()
	return self
end

--- Roblox TextSize used for the glyphs and the extra scale to reach the Godot font size.
function GradientText._sizes(self): (number, number)
	local want = self.px * UITheme.LINE_EM
	local ts = math.clamp(math.floor(want + 0.5), 1, 100)
	return ts, want / ts
end

function GradientText._rebuild(self)
	for _, g in ipairs(self._glyphs) do
		for _, inst in ipairs({ g.shadow, g.text, g.shine, g.shadow_stroke }) do
			self:_drop_part(inst)
		end
		g.shadow:Destroy()
		g.text:Destroy()
		g.shine:Destroy()
	end
	table.clear(self._glyphs)
	local ts = self:_sizes()
	self._ts = ts
	for _, cp in utf8.codes(self.text) do
		local ch = utf8.char(cp)
		local function lab(z: number): TextLabel
			return UICtx.make("TextLabel", {
				BackgroundTransparency = 1,
				Text = ch,
				FontFace = UITheme.font(self.weight),
				TextSize = ts,
				TextColor3 = UITheme.WHITE,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = z,
			}, self._inner)
		end
		local g = { ch = ch, shadow = lab(1), text = lab(2), shine = lab(3) }
		local sst = UICtx.make("UIStroke", { Thickness = 1, LineJoinMode = Enum.LineJoinMode.Round }, g.shadow)
		g.shadow_stroke = sst
		-- Register as parts so the node's modulate (fades) reaches them.
		self:_part(g.text, "TextTransparency", 1.0)
		self:_part(g.shine, "TextTransparency", 1.0)
		self:_part(g.shadow, "TextTransparency", self.shadow.alpha)
		self:_part(sst, "Transparency", self.shadow.alpha)
		g.grad = UICtx.make("UIGradient", { Rotation = 90 }, g.text)
		g.shine_grad = UICtx.make("UIGradient", {}, g.shine)
		table.insert(self._glyphs, g)
	end
	self:update_minimum_size()
	self:_redraw()
end

function GradientText.set_text(self, t: string)
	if t == self.text then
		return
	end
	self.text = t
	self:_rebuild()
end

function GradientText.set_px(self, px: number)
	if px == self.px then
		return
	end
	self.px = px
	local ts = self:_sizes()
	if ts ~= self._ts then
		self:_rebuild()
	else
		self:update_minimum_size()
		self:_redraw()
	end
end

function GradientText.set_colors(self, top: Color3, bottom: Color3)
	self.top_color = top
	self.bottom_color = bottom
	self:_redraw()
end

--- Glyph pen positions in logical px (kerning of the whole string, + spacing after each glyph).
function GradientText._pens(self): ({ number }, number)
	local ts, k = self:_sizes()
	local xs = {}
	local prefix = ""
	local n = 0
	for _, cp in utf8.codes(self.text) do
		n += 1
		table.insert(xs, UITheme.measure_px(prefix, ts, self.weight) * k + (n - 1) * self.spacing)
		prefix ..= utf8.char(cp)
	end
	local total = UITheme.measure_px(self.text, ts, self.weight) * k + n * self.spacing
	return xs, total
end

function GradientText._get_minimum_size(self): Vector2
	local _, total = self:_pens()
	return Vector2.new(math.ceil(total), self.px * UITheme.LINE_EM)
end

function GradientText._on_geometry(self)
	self:_redraw()
end

function GradientText._restyle(self)
	self:_redraw()
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

function GradientText._redraw(self)
	local canvas = self._canvas
	canvas.Size = UDim2.fromOffset(self.size.X, self.size.Y);
	(canvas:FindFirstChild("Scale") :: UIScale).Scale = UITheme.scale
	local ts, k = self:_sizes()
	self._inner_scale.Scale = k
	local line_h = self.px * UITheme.LINE_EM
	local xs, total = self:_pens()
	-- Centre the word horizontally in the node (Label HORIZONTAL_ALIGNMENT_CENTER).
	local x0 = math.floor((self.size.X - total) * 0.5 + 0.5)
	-- Vertical gradient from y0 to y0 + span (WORD_SHADER): keypoints in the glyph's own [0, 1].
	local a = clamp01(self.y0 / line_h)
	local b = clamp01((self.y0 + self.span) / line_h)
	if b <= a then
		b = math.min(1, a + 0.001)
	end
	local cseq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, self.top_color),
		ColorSequenceKeypoint.new(a, self.top_color),
		ColorSequenceKeypoint.new(b, self.bottom_color),
		ColorSequenceKeypoint.new(1, self.bottom_color),
	})
	local sh = self.shadow
	for i, g in ipairs(self._glyphs) do
		local gx = x0 + xs[i]
		local next_x = if i < #self._glyphs then x0 + xs[i + 1] - self.spacing else x0 + total - self.spacing
		local gw = math.max(1, next_x - gx)
		-- Inner units: logical / k.
		local ix, iw, ih = gx / k, gw / k + ts * 0.3, ts
		for _, lab in ipairs({ g.text, g.shadow, g.shine }) do
			lab.Position = UDim2.fromOffset(ix, 0)
			lab.Size = UDim2.fromOffset(iw, ih)
		end
		g.grad.Color = cseq
		-- Shadow: offset down, expanded by an outline (Godot shadow_outline_size).
		g.shadow.Position = UDim2.fromOffset(ix, sh.offset_y / k)
		g.shadow.TextColor3 = sh.color
		self:_part(g.shadow, "TextTransparency", sh.alpha)
		g.shadow_stroke.Color = sh.color
		g.shadow_stroke.Thickness = math.max(0, sh.outline * 0.5 / k)
		self:_part(g.shadow_stroke, "Transparency", sh.alpha)
		-- Shine band: + shine * (1 - smoothstep(0, 70, |x - sweep - (y - y0) * 0.35|)), drawn as a
		-- white copy whose transparency gradient is that band in this glyph's box (rotated by the
		-- 0.35 shear converted to the box's aspect).
		local rel = self.sweep - gx -- band centre at the glyph's y0 row, in glyph logical px
		if rel < -SHINE_HALF - gw - line_h or rel > gw + SHINE_HALF + line_h then
			g.shine.Visible = false
		else
			g.shine.Visible = true
			local W_px, H_px = iw * k, ih * k
			-- isolines x - 0.35 y = c  ->  gradient axis along (1, -0.35) in px; in UV space the
			-- direction becomes (1 / W, -0.35 / H) scaled by the box: angle = atan2(-0.35 H, W)...
			local ang = math.deg(math.atan2(-0.35 * H_px, W_px))
			g.shine_grad.Rotation = ang
			-- Distance along the gradient axis per unit t: project the box onto the axis.
			local c, s = math.cos(math.rad(ang)), math.sin(math.rad(ang))
			local L = math.abs(W_px * c) + math.abs(H_px * s) -- px spanned by t = 0..1
			local half_t = SHINE_HALF / math.max(L, 1) * math.sqrt(1 + 0.35 * 0.35)
			-- centre of the band: pixel (rel + y0*0.35 ... ) -> t of the band line through (rel, y0)
			local px_c = rel + 0.35 * self.y0
			local tc = 0.5 + ((px_c - W_px * 0.5) * c + (0 - H_px * 0.5) * s) / L
			local pts = {}
			local function kp(t: number, v: number)
				if t > 0.0005 and t < 0.9995 then
					table.insert(pts, NumberSequenceKeypoint.new(t, v))
				end
			end
			table.insert(pts, NumberSequenceKeypoint.new(0, 1))
			for j = -4, 4 do
				local d = j / 4 -- -1..1 of the half width
				local sm = 1
					- (function(x)
						local u = clamp01(x)
						return u * u * (3 - 2 * u)
					end)(math.abs(d))
				kp(tc + d * half_t, 1 - self.shine * sm)
			end
			table.insert(pts, NumberSequenceKeypoint.new(1, 1))
			table.sort(pts, function(p, q)
				return p.Time < q.Time
			end)
			-- NumberSequence needs strictly increasing times.
			local clean = {}
			local last = -1
			for _, p in ipairs(pts) do
				if p.Time > last + 1e-4 then
					table.insert(clean, p)
					last = p.Time
				end
			end
			if clean[#clean].Time < 1 then
				table.insert(clean, NumberSequenceKeypoint.new(1, 1))
			end
			g.shine_grad.Transparency = NumberSequence.new(clean)
		end
	end
end

-- =============================================================================================
-- Title screen
-- =============================================================================================

--- A war leaves the board when its countdown here reaches this (the server closes joins at
--- LobbyRules.JOIN_CLOSE_S = 6 s; the board's whole seconds round up).
TitleScreen.JOIN_CLOSE_S = 5
TitleScreen.DIFFS = { [0] = "Recruit", "Veteran", "Warlord" }
TitleScreen.DIFF_BLURB = {
	[0] = "They lag behind each age and seldom pick a fight.",
	"They keep pace with every age and strike when it pays.",
	"They race each age open and come for you first.",
}

function TitleScreen.new(c: any)
	local self = setmetatable({}, TitleScreen.__mt)
	W.Control._init(self)
	self.ctx = c
	self.play_solo = Signal.new()
	--- the map's picture: UIRoot opens the map picker
	self.pick_map = Signal.new()
	self.play_multi = Signal.new()
	self.show_help = Signal.new()
	self.leave_queue = Signal.new()
	--- the waiting room's vote-to-start toggle
	self.vote_start = Signal.new()
	--- (lobby_id) a public lobby was picked (nothing on the title asks for one lobby now; UIRoot still hears it)
	self.join_lobby = Signal.new()
	--- (mode) Quick Play: a seat in the soonest public match of that kind ("ffa" | "team")
	self.join_public = Signal.new()
	--- Quick Play: leave the line
	self.leave_line = Signal.new()
	--- the Spoils row: UIRoot opens the Locker
	self.open_locker = Signal.new()
	self.open_command = Signal.new()
	self.open_arsenal = Signal.new()
	--- the Founding Grant's row (until it is taken): UIRoot opens its sheet
	self.open_starter = Signal.new()
	self.open_shop = Signal.new()
	--- the SHOP row: the whole shop (UI/ShopHub)
	self.open_shop_hub = Signal.new()
	--- the patch notes panel's Roadmap button
	self.open_roadmap = Signal.new()
	--- the Sovereign's Charter's row (Data/Subscription): UIRoot opens its window
	self.open_general = Signal.new()
	--- the Council's row: UIRoot opens its sheet
	self.open_council = Signal.new()
	--- the COMMUNITY row: Roblox's prompt to join the game's community (UIRoot._join_community)
	self.open_community = Signal.new()
	--- (action, user_id?) the party panel (Session.party_action)
	self.party_action = Signal.new()
	self.difficulty =
		math.clamp(tonumber(c:setting("difficulty", UICtx.DEFAULT_DIFFICULTY)) or UICtx.DEFAULT_DIFFICULTY, 0, 2)
	self._lobby = {}
	self._lobby_msec = 0
	self._lobbies = nil :: { any }?
	self._lobbies_msec = 0
	self._joining = nil :: string?
	self._joining_msec = 0
	--- the kinds of public match the hub offers (nil: not said yet)
	self._kinds = nil :: { string }?
	--- Quick Play (Session.public): asking / in line / on the way, and since when (UICtx.msec)
	self._public = { state = "idle" } :: { [string]: any }
	self._public_msec = 0
	self._public_since = 0
	self._accum = 0.0
	self._tick_sec = -1
	self._hide_tween = nil
	self._chips = {}
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	-- where a sheet docks while the title is up (UI/Sheet)
	c.title_nav = function(): number
		return if self.visible then TitleScreen.nav_width(c) + TitleScreen.NAV_EDGE else 0
	end
	-- a press that closed a sheet, on a place in the column: goes there, so one press moves between sheets
	c.title_nav_press = function(at: Vector2)
		if not self.visible then
			return
		end
		for _, b in { self._online, self._solo, unpack(self._nav_list) } do
			if b.visible and not b.disabled and b:has_global_point(at) then
				b.pressed:Fire()
				return
			end
		end
	end
	self:_build_head()
	self:_build_dock()
	self:_build_queue()
	self:_build_pick()
	self:_build_news()
	self:_build_solo_menu()
	self:_build_nav()
	-- credits: the copyright notice the code's licence asks to keep visible, Rodrigo Flores'
	-- soundtrack (Orchestral Ambients) and the licence (2026-10-25: the full
	-- notices are in How to play, HelpOverlay.LEGAL); phones get the short line (apply_layout)
	-- It stands at the foot of the menu column, on the column's own dark ground, so no coast or shadow can take it.
	self._credits = UITheme.label(TitleScreen.footer_text(), 11, 500, UITheme.TEXT_2, 1)
	self._credits:set_alignment(W.ALIGN_LEFT)
	self._credits:set_autowrap(true)
	self:add_child(self._credits)
	-- the party (team games on: staging only for now; hidden until the server sends one)
	self._party = PartyPanel.new(c)
	self._party.on_action = function(action: string, uid: number?)
		self.party_action:Fire(action, uid)
	end
	self:add_child(self._party)
	--- in a party, and whether this player leads it (only the leader picks a public match)
	self._in_party = false
	self._party_leader = true
	self:set_process(true)
	return self
end

--- The player's party (server/Party.state), or nil (parties are off).
function TitleScreen.set_party(self, st: any)
	self._party:set_state(st)
	local n = if type(st) == "table" and type(st.members) == "table" then #st.members else 0
	self._in_party = n >= 2
	self._party_leader = not self._in_party or st.leader == true
	self:_refresh_mp()
end

function TitleScreen._build_head(self)
	self._head = UITheme.vbox(0)
	self._head:set_alignment(W.ALIGN_BEGIN)
	self:add_child(self._head)

	local word = GradientText.new("WARHOLD", 120, 900)
	word.spacing = 2
	word.shadow = { color = UITheme.BLACK, alpha = 0.0, offset_y = 0, outline = 0 }
	word:set_colors(UITheme.TEXT, UITheme.TEXT) -- (flat, set in the column, no gradient)
	word.size_flags_horizontal = W.SHRINK_CENTER
	self._word = word
	self._head:add_child(word)

	self._tag_row = UITheme.hbox(0)
	self._tag_row:set_alignment(W.ALIGN_BEGIN)
	self._tag = UITheme.label("Hold the world, age by age", 13, 500, UITheme.TEXT_2)
	self._tag_row:add_child(self._tag)
	self._head:add_child(self._tag_row)
end

function TitleScreen._build_dock(self)
	local T = UITheme
	self._greet = T.label("", 13, 500, T.TEXT_2)
	-- (it wraps to a second line rather than end in "…"; playtest 2026-11-08)
	self._greet:set_autowrap(true)

	-- (2026-11-08, the owner: multiplayer leads the title now. PLAY ONLINE marches into the soonest war on the board, the
	-- board below lists every war forming; the campaign alone is the second way in.)
	self._online = T.button("PLAY ONLINE", "PrimaryButton", "users", 58.0)
	self._online:add_theme_constant_override("icon_max_width", 18)
	self._online:set_font_size(19)
	self._online.size_flags_horizontal = W.EXPAND_FILL
	self._online.pressed:Connect(function()
		self:_online_pressed()
	end)
	self._solo = T.button("CAMPAIGN ALONE", "GlassButton", "play", 58.0)
	self._solo:add_theme_constant_override("icon_max_width", 18)
	self._solo:set_font_size(19)
	self._solo.size_flags_horizontal = W.EXPAND_FILL
	self._solo.pressed:Connect(function()
		self:open_solo_menu()
	end)

	-- the war board: the wars forming, the soonest (or the one you turned to) on top with the way to it, the others as rows
	local dock = GlassPanel.new(16.0, 12.0, 14, true, 18)
	self._dock = dock
	self:add_child(dock)
	local v = T.vbox(8)
	dock:add_child(v)
	local head = T.label("MULTIPLAYER · WARS FORMING", 12, 800, T.TEXT_3, 1)
	self._board_head = head
	v:add_child(head)
	local row = T.hbox(10)
	v:add_child(row)
	local next_b = T.button("", "GhostButton", "chevron", 44.0)
	next_b:add_theme_constant_override("icon_max_width", 14)
	next_b:set_min_size(Vector2.new(44, 44))
	next_b:set_font_size(13)
	next_b.size_flags_vertical = W.SHRINK_CENTER
	next_b:set_visible(false)
	next_b.pressed:Connect(function()
		self:_next_front()
	end)
	self._next_b = next_b
	row:add_child(next_b)
	local words = T.vbox(1)
	words.size_flags_horizontal = W.EXPAND_FILL
	words.size_flags_vertical = W.SHRINK_CENTER
	self._war_title = T.label("OPEN WAR", 17, 800, T.TEXT, 2)
	self._war_title.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._war_title.clip_text = true
	words:add_child(self._war_title)
	self._war_line = T.label("Sending riders…", 12, 500, T.TEXT_2)
	self._war_line.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._war_line.clip_text = true
	self._war_line:set_min_size(Vector2.new(60, 0))
	self._war_line.size_flags_horizontal = W.EXPAND_FILL
	-- (the countdown has its own label: however long the map's name, the name gives way and the clock stays)
	local status = T.hbox(6)
	status:add_child(self._war_line)
	self._war_left = T.label("", 12, 700, T.TEXT)
	self._war_left:set_tabular(true)
	status:add_child(self._war_left)
	self._war_status = status
	words:add_child(status)
	row:add_child(words)
	local march = T.button("MARCH", "PrimaryButton", "", 44.0)
	march:set_font_size(14)
	march.size_flags_vertical = W.SHRINK_CENTER
	march.pressed:Connect(function()
		self:_march_pressed()
	end)
	self._march = march
	row:add_child(march)
	-- who has mustered, of the seats there are: a thin bar along the foot, no count of seats in words
	local track = W.ColorRect.new(T.c(T.TEXT, 0.12))
	track:set_mouse_filter(W.MOUSE_IGNORE)
	track:set_min_size(Vector2.new(0, 3))
	self._muster_track = track
	v:add_child(track)
	local fill = W.ColorRect.new(T.AMBER)
	fill:set_mouse_filter(W.MOUSE_IGNORE)
	fill:set_anchors(0, 0, 0, 1)
	fill:set_offsets(0, 0, 0, 0)
	self._muster_fill = fill
	track:add_child(fill)
	-- the other wars on offer: a row each, a press turns the board to it
	local others = T.vbox(4)
	self._others = others
	self._other_rows = {}
	v:add_child(others)
end

--- PLAY ONLINE: the matchmaking screen's choice of war (every kind on offer, Hardcore's own queue among them).
function TitleScreen._online_pressed(self)
	self.ctx:sfx("open", -6.0)
	self._mm_open = true
	self:_refresh_queue_mode()
	self:_refresh_pick()
end

--- The main menu's right side (2026-11-08, the owner): the featured shop item at the top right, and under it the latest
--- patch notes (Data/PatchNotes), always there, with the Roadmap a button in the same panel.
TitleScreen.NEWS_W = 340

function TitleScreen._build_news(self)
	local T = UITheme
	-- the featured shop item
	local f = GlassPanel.new(14.0, 12.0, 14, true, 12)
	self._featured = f
	self:add_child(f)
	local fh = T.hbox(12)
	f:add_child(fh)
	local img = Instance.new("ImageLabel")
	img.Name = "FeaturedArt"
	img.BackgroundTransparency = 1
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Fit
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = img
	self._feat_img = img
	local pic = W.wrap(img)
	pic:set_mouse_filter(W.MOUSE_IGNORE)
	pic:set_min_size(Vector2.new(64, 64))
	pic.size_flags_vertical = W.SHRINK_CENTER
	fh:add_child(pic)
	local fw = T.vbox(2)
	fw.size_flags_horizontal = W.EXPAND_FILL
	fw:add_child(T.label("FEATURED", 11, 800, T.AMBER, 1))
	self._feat_name = T.label("", 15, 800, T.TEXT)
	fw:add_child(self._feat_name)
	self._feat_line = T.label("", 12, 500, T.TEXT_2)
	self._feat_line:set_autowrap(true)
	fw:add_child(self._feat_line)
	fh:add_child(fw)
	local go = T.button("SHOP", "PrimaryButton", "", 40.0)
	go:set_min_size(Vector2.new(84, 40))
	go.size_flags_vertical = W.SHRINK_CENTER
	go.pressed:Connect(function()
		self.open_shop_hub:Fire(self._feat_tab)
	end)
	fh:add_child(go)
	-- the patch notes, with the Roadmap
	local n = GlassPanel.new(16.0, 14.0, 14, true, 12)
	self._news = n
	self:add_child(n)
	local v = T.vbox(6)
	n:add_child(v)
	local PN = UICtx.data("PatchNotes")
	local r = PN.latest()
	local head = T.hbox(8)
	local cap = T.label("WHAT'S NEW", 12, 800, T.TEXT_2, 1)
	cap.size_flags_horizontal = W.EXPAND_FILL
	head:add_child(cap)
	head:add_child(T.label("v" .. r.version, 12, 700, T.AMBER))
	v:add_child(head)
	v:add_child(T.label(string.upper(r.title), 17, 800, T.TEXT, 1))
	self._news_lines = {}
	for _, line in r.lines do
		local l = T.label("•  " .. line, 12, 500, T.TEXT)
		l:set_autowrap(true)
		v:add_child(l)
		table.insert(self._news_lines, l)
	end
	local road = T.button("ROADMAP", "GlassButton", "chevron", 40.0)
	road:add_theme_constant_override("icon_max_width", 12)
	road.pressed:Connect(function()
		self.ctx:sfx("open", -6.0)
		self.open_roadmap:Fire()
	end)
	self._road_btn = road
	v:add_child(road)
	self:_refresh_featured()
end

--- What the featured card shows, from what the shop has on offer for this player (ShopHub.offers: the one rule, so
--- Spoils only where paid random items are allowed): { name, line, art, tab } or nil (nothing on offer). Pure in `o`.
function TitleScreen.featured_pick(o: any): any?
	if o == nil or not o.any then
		return nil
	end
	if o.grant then
		return { name = "Founding Grant", line = "A strong start for a new ruler, once.", art = "spoils_one", tab = "featured" }
	elseif o.charter and not o.holds then
		return { name = "Sovereign's Charter", line = "Daily Renown and the Charter's own Standards.", art = "spoils_satchel", tab = "featured" }
	elseif o.spoils then
		return { name = "Spoils", line = "Sealed dispatches from the front, never a repeat.", art = "spoils_courier", tab = "spoils" }
	elseif o.standards then
		return { name = "Standards", line = "New flags for your realm.", art = nil, tab = "standards" }
	end
	return { name = "War College", line = "Weapons and edicts for Renown or Robux.", art = nil, tab = "college" }
end

function TitleScreen._refresh_featured(self)
	if self._featured == nil then
		return
	end
	local ok, o = pcall(function()
		return UICtx.mod("ShopHub").offers(self.ctx)
	end)
	local pick = TitleScreen.featured_pick(if ok then o else nil)
	self._feat_pick = pick
	if pick == nil then
		return
	end
	self._feat_tab = pick.tab
	self._feat_name:set_text(pick.name)
	self._feat_line:set_text(pick.line)
	local art = if pick.art ~= nil then ShopArt[pick.art] else nil
	UITheme.set_image(self._feat_img, art or UITheme.icon("standard", true))
end

--- The right side's places: the featured card at the top right, the notes under it down to the board; a phone, or a
--- screen too short for them, keeps the map clear (the notes are in the Roadmap too).
function TitleScreen._layout_news(self, menu: boolean)
	local ctx = self.ctx
	local vp = ctx.vp
	local w = TitleScreen.NEWS_W
	local right = ctx.insets.z + 16.0
	local room = vp.X - TitleScreen.nav_width(ctx) - 32.0
	local wide = not ctx.compact and room >= w + TitleScreen.BOARD_W * 0.5
	local feat_on = menu and wide and self._feat_pick ~= nil
	self._featured:set_visible(feat_on)
	local y = ctx.insets.y + 16.0
	if feat_on then
		self._feat_line:set_min_size(Vector2.new(w - 64 - 84 - 24 - 28, 0))
		self._featured:set_min_size(Vector2.new(w, 0))
		self._featured:reset_size()
		local sz = self._featured:get_combined_minimum_size()
		UICtx.move_node(self._featured, Vector2.new(math.floor(vp.X - right - sz.X), math.floor(y)))
		y += sz.Y + 12.0
	end
	-- (the board stands at the bottom right: the notes stop above it)
	local board_top = vp.Y - ctx.insets.w - 12.0 - self._dock:get_combined_minimum_size().Y - 12.0
	for _, l in self._news_lines do
		l:set_min_size(Vector2.new(w - 32, 0))
	end
	self._news:set_min_size(Vector2.new(w, 0))
	self._news:reset_size()
	local sz = self._news:get_combined_minimum_size()
	local news_on = menu and wide and y + sz.Y <= board_top
	self._news:set_visible(news_on)
	if news_on then
		UICtx.move_node(self._news, Vector2.new(math.floor(vp.X - right - sz.X), math.floor(y)))
	end
end

--- The matchmaking screen (2026-11-08, the owner: waiting for other players is a screen of its own, not the main menu):
--- "pick" (choosing a war), "line" (asking the hub for a seat, or waiting in line), "muster" (on the war's own server,
--- waiting for it to march), or nil (the main menu).
function TitleScreen._mm_state(self): string?
	if self.ctx:mp_waiting() then
		return "muster"
	elseif self._public ~= nil and self._public.state ~= "idle" then
		return "line"
	elseif self._mm_open then
		return "pick"
	end
	return nil
end

--- The kind of war's name on the matchmaking screen. Pure.
function TitleScreen.kind_name(kind: string, l: any?): string
	local Modes = UICtx.data("Modes")
	local war = if l ~= nil and type(l.war_mode) == "string" then Modes.BY_KEY[l.war_mode] else nil
	if kind == "team" then
		return "Team war"
	elseif kind == "hardcore" then
		return "Hardcore"
	elseif kind == "world" then
		return "World war"
	elseif war ~= nil then
		return war.name
	end
	return "Quick play"
end

--- What each kind is, under its name on the matchmaking screen.
TitleScreen.KIND_LINES = {
	ffa = "Any map, any mode in the rotation. The fastest way into a war.",
	world = "The whole World, every ruler for themselves.",
	team = "Sides of players and bots. Win together.",
	hardcore = "Brutal rivals, no world events, slower regrowth. Its own queue.",
}

--- The matchmaking screen's choice of war: a card per kind on offer with where it forms, when, who is in, and MARCH.
function TitleScreen._build_pick(self)
	local T = UITheme
	local dim = W.ColorRect.new(T.c(T.BLACK, 0.55))
	dim:set_mouse_filter(W.MOUSE_STOP)
	dim:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	dim:set_visible(false)
	self._mm_dim = dim
	self:add_child(dim)
	self:move_child(dim, 0)
	local p = GlassPanel.new(22.0, 18.0, 14, true, 18)
	self._pick = p
	self:add_child(p)
	local v = T.vbox(10)
	p:add_child(v)
	local head = T.hbox(10)
	head:add_child(Sheet.back_button(function()
		self._mm_open = false
		self.ctx:sfx("close", -6.0)
		self:_refresh_queue_mode()
	end))
	local title = T.label("CHOOSE YOUR WAR", 20, 800, T.TEXT, 2)
	title.size_flags_horizontal = W.EXPAND_FILL
	title.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(title)
	v:add_child(head)
	self._pick_rows = T.vbox(8)
	v:add_child(self._pick_rows)
	self._pick_cards = {}
	p:set_visible(false)
end

--- Fills the choice of war from the lobby list (TitleScreen._fronts): every kind the hub offers, soonest first.
function TitleScreen._refresh_pick(self)
	if self._pick == nil or not self._pick.visible then
		return
	end
	local T = UITheme
	local ctx = self.ctx
	local elapsed = (UICtx.msec() - (self._lobbies_msec or UICtx.msec())) / 1000.0
	local fronts = self:_fronts(elapsed)
	local Modes = UICtx.data("Modes")
	for i = 1, math.max(#fronts, #self._pick_cards) do
		local fr = fronts[i]
		local c = self._pick_cards[i]
		if fr ~= nil and c == nil then
			local card = W.Panel.new()
			card:add_theme_stylebox_override("panel", T.flat(T.c(T.WHITE, 0.05), 10, T.LINE, 1, 14, 10))
			local row = T.hbox(12)
			card:add_child(row)
			local words = T.vbox(2)
			words.size_flags_horizontal = W.EXPAND_FILL
			local name = T.label("", 17, 800, T.TEXT, 1)
			words:add_child(name)
			local line = T.label("", 12, 500, T.TEXT_2)
			line:set_autowrap(true)
			words:add_child(line)
			local where = T.label("", 12, 700, T.AMBER)
			where.text_overrun_behavior = W.OVERRUN_ELLIPSIS
			where.clip_text = true
			words:add_child(where)
			row:add_child(words)
			local go = T.button("MARCH", "PrimaryButton", "", 44.0)
			go:set_min_size(Vector2.new(120, 44))
			go.size_flags_vertical = W.SHRINK_CENTER
			row:add_child(go)
			c = { card = card, name = name, line = line, where = where, go = go }
			go.pressed:Connect(function()
				if c.kind ~= nil and self._public.state == "idle" and self._joining == nil then
					self._front_pick = c.kind
					self:set_public({ state = "joining", mode = c.kind })
					self.join_public:Fire(c.kind)
					self:_refresh_queue_mode()
				end
			end)
			self._pick_rows:add_child(card)
			self._pick_cards[i] = c
		end
		if c ~= nil then
			c.card:set_visible(fr ~= nil)
			if fr ~= nil then
				c.kind = fr.kind
				local l = fr.lobby
				c.name:set_text(string.upper(TitleScreen.kind_name(fr.kind, l)))
				c.line:set_text(TitleScreen.KIND_LINES[fr.kind] or "")
				local bits = {}
				if l ~= nil then
					local where = tostring(l.map_name or l.map)
					local per = if type(l.id) == "string" then Modes.period_pick(l.id, l.map) else nil
					table.insert(bits, if per ~= nil then where .. " in " .. per else where)
					table.insert(bits, "marches in " .. T.fmt_time(math.max(0, math.ceil((tonumber(l.starts_in) or 0) - elapsed))))
					local n = tonumber(l.players) or 0
					table.insert(bits, if n == 1 then "1 ruler in" else string.format("%d rulers in", n))
				else
					table.insert(bits, "Nothing forming yet: be the first in line")
				end
				c.where:set_text(table.concat(bits, "  ·  "))
				c.go:set_disabled(self._joining ~= nil or (self._in_party and not self._party_leader))
			end
		end
	end
	self._pick:reset_size()
end

--- The rows under the board's war: every other war on offer, its kind, where, when, and who is in. Pure in its inputs
--- but for the widgets it fills.
function TitleScreen._fill_others(self, fronts: { any }, shown: string?, elapsed: number)
	local T = UITheme
	local ctx = self.ctx
	local Modes = UICtx.data("Modes")
	local list = {}
	local shown_id = nil
	for _, fr in fronts do
		if fr.kind == shown and fr.lobby ~= nil then
			shown_id = fr.lobby.id
		end
	end
	for _, fr in fronts do
		-- (the free-for-all can show World's own lobby: that war is already on top, not a row again)
		if fr.kind ~= shown and (fr.lobby == nil or fr.lobby.id ~= shown_id) then
			table.insert(list, fr)
		end
	end
	for i = 1, math.max(#list, #self._other_rows) do
		local fr = list[i]
		local b = self._other_rows[i]
		if fr ~= nil and b == nil then
			b = T.button("", "GhostButton", "chevron", 34.0)
			b.alignment = W.ALIGN_LEFT
			b:add_theme_constant_override("icon_max_width", 12)
			b:set_font_size(13)
			b.text_overrun_behavior = W.OVERRUN_ELLIPSIS
			b.clip_text = true
			b.pressed:Connect(function()
				if b._kind ~= nil then
					self._front_pick = b._kind
					ctx:sfx("tab")
					self:_refresh_mp()
				end
			end)
			self._others:add_child(b)
			self._other_rows[i] = b
		end
		if b ~= nil then
			b:set_visible(fr ~= nil)
			if fr ~= nil then
				b._kind = fr.kind
				local l = fr.lobby
				local war = if l ~= nil and type(l.war_mode) == "string" then Modes.BY_KEY[l.war_mode] else nil
				local name = if fr.kind == "team" then "Team war"
					elseif fr.kind == "hardcore" then "Hardcore"
					elseif war ~= nil then war.name
					elseif fr.kind == "world" then "World war"
					else "Open war"
				local bits = { name }
				if l ~= nil then
					local where = tostring(l.map_name or l.map)
					local per = if type(l.id) == "string" then Modes.period_pick(l.id, l.map) else nil
					table.insert(bits, if per ~= nil then where .. " in " .. per else where)
					table.insert(bits, T.fmt_time(math.max(0, math.ceil((tonumber(l.starts_in) or 0) - elapsed))))
					local n = tonumber(l.players) or 0
					if n > 0 then
						table.insert(bits, string.format("%d in", n))
					end
				else
					table.insert(bits, "be the first in line")
				end
				b:set_text(table.concat(bits, "  ·  "))
			end
		end
	end
	self._others:set_visible(#list > 0)
end

--- The column on the left that carries the title screen: the name, who you are, and one row per place to go.
function TitleScreen._build_nav(self)
	local bg = W.ColorRect.new(UITheme.rgba(0.06, 0.064, 0.07, 0.97))
	self._nav_bg = bg
	self:add_child(bg)
	self:move_child(bg, 0)
	-- your banner's colour down the column's edge
	local edge = W.ColorRect.new(UITheme.AMBER)
	edge:set_mouse_filter(W.MOUSE_IGNORE)
	self._nav_edge = edge
	self:add_child(edge)
	self:move_child(edge, 1)
	-- (the rows scroll inside the column: a phone can't always show them all)
	local scroll = Scroll.new()
	self._nav_scroll = scroll
	self:add_child(scroll)
	local v = UITheme.vbox(4)
	self._nav_v = v
	-- (room on the right for the scroll bar, drawn over the rows when a phone has to scroll them: a row's highlight ran under it)
	local pad = W.Margin.new()
	pad:add_theme_constant_override("margin_right", 8)
	scroll:add_child(pad)
	pad:add_child(v)
	self._nav_rows = {}
	local function row(key: string, text: string, icon: string, sig: any)
		local b = UITheme.button(text, "GhostButton", icon, 46.0)
		b.alignment = W.ALIGN_LEFT
		b:set_font_size(14)
		b:add_theme_constant_override("icon_max_width", 18)
		b.size_flags_horizontal = W.EXPAND_FILL
		b.pressed:Connect(function()
			sig:Fire()
		end)
		self._nav_rows[key] = b
		return b
	end
	-- SHOP opens the whole shop (UI/ShopHub: the Grant, the Charter, Spoils, Standards and the College's unlocks in one
	-- sheet; 2026-11-08, the owner: it used to fold out a row for each). The rows below stay for anything that opens one
	-- window directly, hidden.
	self._offers_open = false
	local offers = UITheme.button("SHOP", "GhostButton", "standard", 46.0)
	offers.alignment = W.ALIGN_LEFT
	offers:set_font_size(14)
	offers:add_theme_constant_override("icon_max_width", 18)
	offers.size_flags_horizontal = W.EXPAND_FILL
	offers.pressed:Connect(function()
		self.open_shop_hub:Fire()
	end)
	self._nav_rows.offers = offers
	self._nav_list = {
		row("room", "WAR ROOM", "crown", self.open_command),
		row("college", "WAR COLLEGE", "arsenal", self.open_arsenal),
		row("spoils", "BANNERS", "dispatch", self.open_locker),
		offers,
		row("standards", "STANDARDS", "standard", self.open_shop),
		row("grant", "FOUNDING GRANT", "city", self.open_starter),
		row("charter", "SOVEREIGN'S CHARTER", "charter", self.open_general),
		row("guide", "FIELD GUIDE", "help", self.show_help),
		row("community", "COMMUNITY", "alliance", self.open_community),
		row("council", "COUNCIL", "settings", self.open_council),
	}
	-- (read once: which products exist doesn't change while a server runs)
	self._shop_on_sale = FlagShop.on_sale()
end

--- A row's words, set only when they change.
local function row_text(b: any, text: string)
	if b.text ~= text then
		b:set_text(text)
	end
end

local function row_shown(b: any, on: boolean)
	if b.visible ~= on then
		b:set_visible(on)
	end
end

--- The rows say what's on sale, what's waiting and how much Renown there is, read from the session each time.
function TitleScreen._refresh_nav(self)
	local r = self._nav_rows
	local s = self.ctx.session
	local inv = if s ~= nil then s.inventory else nil
	if inv ~= nil and not self._prices_asked then
		self._prices_asked = true
		Prices.fetch()
	end
	-- Renown, once the save has loaded
	local stars = if inv ~= nil and inv.loaded == true then tonumber(inv.stars) else nil
	local college = if self.ctx.compact then "COLLEGE" else "WAR COLLEGE"
	row_text(r.college, if stars ~= nil then college .. "  ·  " .. UICtx.commas(stars) else college)
	-- Spoils waiting to open
	local allowed = inv ~= nil and inv.crates_allowed == true
	local credits = if s ~= nil and type(s.credits) == "table" then (tonumber(s.credits.crate) or 0) else 0
	row_text(r.spoils, if allowed and credits > 0 then "BANNERS  ·  " .. tostring(credits) else "BANNERS")
	-- SHOP: shown while anything can really be bought here (the shop's own rules: ShopHub.offers)
	local o = ShopHub.offers(self.ctx)
	row_shown(r.offers, o.any)
	row_shown(r.standards, false)
	row_shown(r.grant, false)
	row_shown(r.charter, false)
end

--- The solo map under its picture (the picture is the setting's: the picker saves it before it says the name).
function TitleScreen.set_map_name(self, name: string)
	self._map_name:set_text(name)
	local e = UIMaps.get(self.ctx:setting("map_id", UIMaps.DEFAULT_ID))
	UITheme.set_image(self._map_thumb, if e then e.thumb else nil)
	self:_refresh_period()
end

--- The solo start date picked for the map in use (Data/Periods key), or nil for today's world: a date the map does not
--- offer plays today's.
function TitleScreen.solo_period(ctx: any): string?
	local key = tostring(ctx:setting("period", "") or "")
	local Periods = UICtx.data("Periods")
	if key == "" or Periods.seats(key, UIMaps.valid(ctx:setting("map_id", UIMaps.DEFAULT_ID))) == nil then
		return nil
	end
	return key
end

--- The war's depth on the solo menu: { setting, chip, line, work in progress }. (the owner, 2026-11-09: Long and Quick
--- are marked work in progress while their roadmap is planned)
TitleScreen.DEPTHS = {
	{ "", "Classic", "The classic war: land, gold and troops." },
	{ "long", "Long", "The deep war: provinces, rulers, taxes and food, wars with reasons, armies and sieges, ambitions.", true },
	{ "quick", "Quick", "The deep war at today's pace: every system, faster clocks.", true },
}

--- Said on a work-in-progress war's button and its hover.
TitleScreen.WIP_TAG = "WIP"
TitleScreen.WIP_LINE = "Work in progress: still being built and balanced, and it may change."

--- The WAR button's words for depth row `it`.
function TitleScreen.depth_label(it: { any }): string
	local s = "WAR: " .. string.upper(it[2])
	return if it[4] then s .. " · " .. TitleScreen.WIP_TAG else s
end

--- A member of the game's community has no COMMUNITY row (UIRoot asks Roblox once the title is up).
function TitleScreen.set_community_member(self, member: boolean)
	local b = self._nav_rows and self._nav_rows.community
	if b ~= nil then
		b:set_visible(not member)
	end
end

--- The depth picked on the solo menu ("long" / "quick"), or nil for the classic war.
function TitleScreen.solo_depth(ctx: any): string?
	local key = tostring(ctx:setting("depth", "") or "")
	return if key == "long" or key == "quick" then key else nil
end

function TitleScreen._refresh_depth(self)
	if self._depth_btn == nil then
		return
	end
	local cur = TitleScreen.solo_depth(self.ctx) or ""
	for _, it in TitleScreen.DEPTHS do
		if it[1] == cur then
			self._depth_btn:set_text(TitleScreen.depth_label(it))
		end
	end
end

--- The start-date chips: shown when the map offers dates, the one in use lit, its name and line under them.
function TitleScreen._refresh_period(self)
	if self._period_row == nil then
		return
	end
	local ctx = self.ctx
	local Periods = UICtx.data("Periods")
	local offered = #Periods.offered(UIMaps.valid(ctx:setting("map_id", UIMaps.DEFAULT_ID))) > 0
	self._period_row:set_visible(offered)
	self._period_desc:set_visible(offered)
	local cur = TitleScreen.solo_period(ctx) or ""
	for key, chip in self._period_chips do
		chip:set_pressed_no_signal(key == cur)
	end
	local p = Periods.get(cur)
	self._period_desc:set_text(if p ~= nil then string.format("%d · %s. %s", p.year, p.name, p.blurb) else "Today's world, today's nations.")
end

--- The game-wide public lobbies ({id, map, map_name, max, players, starts_in, joinable}, soonest
--- first) from the hub server, and the kinds of public match it offers (Quick Play).
function TitleScreen.set_lobbies(self, list: { any }?, kinds: { string }?)
	self._lobbies = list
	self._lobbies_msec = UICtx.msec()
	if kinds ~= nil then
		self._kinds = kinds
	end
	if self._joining ~= nil and UICtx.msec() - (self._joining_msec or 0) > 20000 then
		self._joining = nil -- the teleport never happened (a notice explains why)
	end
	-- asking, or seated and on the way, with no word for 20 s: the teleport never happened
	local st = self._public.state
	if (st == "joining" or st == "going") and UICtx.msec() - self._public_msec > 20000 then
		self._public = { state = "idle" }
	end
	self:_refresh_mp()
end

--- Quick Play's state from the hub (Session.public): { state = "joining" | "line" | "going" |
--- "idle", mode, info = { map, map_name }? }.
function TitleScreen.set_public(self, st: { [string]: any })
	local prev = self._public.state
	self._public = table.clone(st)
	if st.state ~= prev then
		self._public_msec = UICtx.msec()
		if prev == "idle" then
			self._public_since = UICtx.msec()
		end
	end
	self:_refresh_mp()
end

--- True while asking for, waiting for, or on the way to a public match.
function TitleScreen.public_busy(self): boolean
	return self._public.state ~= "idle"
end

--- A join attempt ended without a teleport (the server said why).
function TitleScreen.join_failed(self)
	self._joining = nil
	if self._public.state == "joining" then
		self._public = { state = "idle" }
	end
	self:_refresh_mp()
end

--- The muster (the waiting room): what war this is and when it marches, who has come, the call to march, and a way out.
function TitleScreen._build_queue(self)
	local T = UITheme
	self._queue = GlassPanel.new(22.0, 18.0, 14, true, 18)
	self:add_child(self._queue)
	local v = T.vbox(8)
	self._queue:add_child(v)
	local head = T.hbox(12)
	local words = T.vbox(1)
	words.size_flags_horizontal = W.EXPAND_FILL
	self._q_title = T.label("OPEN WAR", 20, 800, T.TEXT, 2)
	self._q_title.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._q_title.clip_text = true
	words:add_child(self._q_title)
	self._q_where = T.label("", 13, 500, T.TEXT_2)
	self._q_where.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._q_where.clip_text = true
	words:add_child(self._q_where)
	head:add_child(words)
	self._q_status = T.label("", 14, 700, T.AMBER)
	self._q_status.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._q_status)
	v:add_child(head)
	self._q_players = T.label("", 13, 500, T.TEXT)
	self._q_players:set_autowrap(true)
	self._q_players:set_min_size(Vector2.new(340, 0))
	v:add_child(self._q_players)
	local btns = T.hbox(8)
	local vote = T.button("Call to march", "PrimaryButton", "play", 44.0)
	vote.size_flags_horizontal = W.EXPAND_FILL
	self._q_vote = vote
	vote.pressed:Connect(function()
		self.vote_start:Fire()
	end)
	vote:set_visible(false)
	btns:add_child(vote)
	local leave = T.button("Step away", "GhostButton", "exit", 44.0)
	self._q_leave = leave
	leave.pressed:Connect(function()
		-- (the muster on a war's own server: step away; still on the hub, in line: out of the line)
		if self.ctx:mp_waiting() then
			self.leave_queue:Fire()
		else
			self.leave_line:Fire()
		end
	end)
	btns:add_child(leave)
	v:add_child(btns)
	self._queue:set_visible(false)
end

-- ---------------------------------------------------------------------------------------------
-- Layout & state
-- ---------------------------------------------------------------------------------------------

--- The accent line down the column's right edge; a sheet stands against it.
TitleScreen.NAV_EDGE = 3.0
--- The widest the war board, the campaign's choices and the muster go (logical px).
TitleScreen.BOARD_W = 540.0
TitleScreen.SOLO_W = 600.0
TitleScreen.MUSTER_W = 480.0

--- The column's width with the safe area on its left, logical px.
function TitleScreen.nav_width(ctx: any): number
	return (if ctx.compact then 224.0 else 300.0) + ctx.insets.x
end

function TitleScreen.apply_layout(self)
	local ctx = self.ctx
	local vp = ctx.vp
	local compact = ctx.compact
	-- The name, who you are and where to go stand in a column down the left edge; the map has the rest.
	local nav_w = if compact then 224.0 else 300.0
	self._nav_w = TitleScreen.nav_width(ctx)
	local inner = nav_w - (if compact then 24.0 else 44.0)
	local col_left = ctx.insets.x + (if compact then 12.0 else 22.0)
	-- the word fills the column's width (twice: its letter spacing follows its size in whole px)
	local word_px = 44.0
	for _ = 1, 2 do
		self:_size_word(word_px)
		word_px = word_px * inner / math.max(self._word:get_combined_minimum_size().X, 1.0)
	end
	self:_size_word(word_px)
	self._nav_bg:set_anchors(0, 0, 0, 1)
	self._nav_bg:set_offsets(0, 0, self._nav_w, 0)
	self._nav_edge:set_anchors(0, 0, 0, 1)
	self._nav_edge:set_offsets(self._nav_w, 0, self._nav_w + TitleScreen.NAV_EDGE, 0)
	self._tag:set_font_size(if compact then 12 else 13)
	self._tag_row:set_visible(true)
	local head_top = ctx.reserved_top_left.Max.Y + (if compact then 2.0 else 14.0) + ctx.insets.y
	local head = self._head
	head.anchor_left, head.anchor_right, head.anchor_top, head.anchor_bottom = 0.0, 0.0, 0.0, 0.0
	head.grow_horizontal = W.GROW_END
	head.grow_vertical = W.GROW_END
	head.offset_left, head.offset_right = col_left, col_left
	head.offset_top, head.offset_bottom = head_top, head_top
	head:reset_size()
	self:_reflow_dock()
	local map_left = self._nav_w + TitleScreen.NAV_EDGE + (if compact then 8.0 else 16.0)
	local map_right = ctx.insets.z + (if compact then 8.0 else 16.0)
	local map_room = vp.X - map_left - map_right
	-- the rows, under the name
	local nav_top = head_top + head:get_combined_minimum_size().Y + (if compact then 6.0 else 16.0)
	self._nav_scroll:set_anchors(0, 0, 0, 0)
	-- (the rows stop above the licence line at the column's foot; its room is what its words need at the column's width,
	-- at the font a phone really draws, so it never runs below the screen: at a fixed 34 it did, on a phone)
	local cfont = math.max(11, UITheme.min_font_size)
	local foot = TitleScreen.footer_text(inner)
	local lines = select(2, string.gsub(foot, "\n", "")) + math.max(1, math.ceil(UITheme.measure_text((string.match(foot, "^[^\n]*")), cfont, 500, 1) / math.max(inner, 1.0)))
	local credits_h = math.max(lines * UITheme.line_height(cfont) + 2.0, 16.0)
	local credits_bottom = vp.Y - ctx.insets.w - (if compact then 6.0 else 12.0)
	local credits_top = credits_bottom - credits_h
	self._nav_scroll:set_offsets(col_left - 2.0, nav_top, col_left + inner + 2.0, credits_top - 4.0)
	self._credits:set_anchors(0, 0, 0, 0)
	self._credits.grow_vertical = W.GROW_BEGIN
	self._credits:set_offsets(col_left, credits_top, col_left + inner, credits_bottom)
	self._nav_v:set_separation(if compact then 2 else 4)
	self._dock:set_min_size(Vector2.new(math.min(TitleScreen.BOARD_W, map_room), 0))
	if compact then
		self._dock:set_padding(10.0, 6.0, 10.0, 6.0)
	else
		self._dock:set_padding(16.0, 12.0, 16.0, 12.0)
	end
	self._war_title:set_font_size(if compact then 14 else 17)
	self._march:set_min_size(Vector2.new(if compact then 96 else 130, if compact then 44 else 50))
	self._online:set_min_size(Vector2.new(0, if compact then 44 else 54))
	self._online:set_font_size(if compact then 13 else 16)
	self._online:set_text(if compact then "ONLINE" else "PLAY ONLINE")
	self._solo:set_min_size(Vector2.new(0, if compact then 40 else 46))
	self._solo:set_font_size(if compact then 12 else 14)
	self._solo:set_text(if compact then "ALONE" else "CAMPAIGN ALONE")
	local solo_w = math.min(TitleScreen.SOLO_W, map_room)
	self._solo_panel:set_min_size(Vector2.new(solo_w, 0))
	self._queue:set_min_size(Vector2.new(math.min(TitleScreen.MUSTER_W, map_room), 0))
	self._q_players:set_min_size(Vector2.new(math.min(TitleScreen.MUSTER_W, map_room) - 44, 0))
	self._q_vote:set_font_size(if compact then 13 else 15)
	self._q_leave:set_font_size(if compact then 13 else 15)
	if compact then
		self._solo_panel:set_padding(12.0, 8.0, 12.0, 8.0)
		self._solo_v:set_separation(6)
		self._queue:set_padding(12.0, 8.0, 12.0, 8.0)
	else
		self._solo_panel:set_padding(20.0, 16.0, 20.0, 16.0)
		self._solo_v:set_separation(10)
		self._queue:set_padding(22.0, 18.0, 22.0, 18.0)
	end
	-- the map's picture beside what can be changed; a wrapped line measures against its width
	local tile_w = if compact then 132.0 else 190.0
	self._map_btn:set_min_size(Vector2.new(tile_w, if compact then 118.0 else 150.0))
	local side_w = solo_w - tile_w - 10.0 - (if compact then 24.0 else 40.0)
	self._diff_desc:set_min_size(Vector2.new(side_w, 0))
	self._mode_desc:set_min_size(Vector2.new(side_w, 0))
	-- (the shortest phones: the mode's line gives way so the choices fit; the list's rows still say it)
	self._mode_desc:set_visible(not (compact and ctx.vp.Y < 390))
	self._start:set_min_size(Vector2.new(0, if compact then 46 else 54))
	self._start:set_font_size(if compact then 16 else 18)
	for _, ch in ipairs(self._chips) do
		ch:set_min_size(Vector2.new(0, if ctx.touch then 44 else 34))
		ch:set_font_size(if compact then 12 else 13)
	end
	self._greet:set_visible(not compact)
	for _, b in ipairs(self._nav_list) do
		b:set_min_size(Vector2.new(0, if ctx.touch then 44 else (if compact then 40 else 46)))
		b:set_font_size(if compact then 12 else 14)
	end
	-- (phones: slimmer edges on the rows, so the longest name fits the narrow column)
	if compact ~= self._nav_compact then
		self._nav_compact = compact
		for _, b in ipairs(self._nav_list) do
			for _, state in W.BUTTON_STATES do
				local st = UITheme.dup(UITheme.theme().GhostButton.styles[state])
				st.mh = if compact then 8.0 else 16.0
				b:add_theme_stylebox_override(state, st)
			end
		end
	end
	self:_refresh_nav()
	-- (the board and panels stand on the map's foot: the licence line is in the column now)
	local bottom = (if compact then 6.0 else 12.0) + ctx.insets.w
	-- the muster and the campaign's choices stand by the column, the board at the map's far corner
	for _, cn in ipairs({ self._queue, self._solo_panel }) do
		cn.anchor_left, cn.anchor_right, cn.anchor_top, cn.anchor_bottom = 0.0, 0.0, 1.0, 1.0
		cn.grow_horizontal = W.GROW_END
		cn.grow_vertical = W.GROW_BEGIN
		cn.offset_left, cn.offset_right = map_left, map_left
		cn.offset_top, cn.offset_bottom = -bottom, -bottom
		cn:reset_size()
	end
	local dock = self._dock
	dock.anchor_left, dock.anchor_right, dock.anchor_top, dock.anchor_bottom = 1.0, 1.0, 1.0, 1.0
	dock.grow_horizontal = W.GROW_BEGIN
	dock.grow_vertical = W.GROW_BEGIN
	dock.offset_left, dock.offset_right = -map_right, -map_right
	dock.offset_top, dock.offset_bottom = -bottom, -bottom
	dock:reset_size()
	-- phones too: the line at the column's foot (placed with the rows above)
	self._credits:set_visible(true)
	self._credits:set_text(foot)
	self._credits:set_font_size(11)
	-- (the column's rows are 4 narrower than `inner`: 8 kept for the scroll bar, 4 the scroll area is wider)
	self._party:dock_in(self._nav_v, inner - 4)
	self._party:apply_layout()
	-- (the matchmaking screen, when it is up, keeps its own place in the middle)
	if self._mm_dim ~= nil then
		self:_refresh_queue_mode()
	end
end

--- The server's word on the Sovereign's Charter (Session.general).
function TitleScreen.refresh_general(self)
	self:_refresh_nav()
	self:_refresh_greeting()
end

--- One short line that leads with what is ours: rank, name, then your rival or how far your last war went (Data/Progress.greeting).
function TitleScreen._refresh_greeting(self)
	local n = self.ctx:username()
	-- (a Charter holder is greeted as one: Data/Subscription)
	local s0 = self.ctx.session
	local Career = UICtx.data("Career")
	local Progress = UICtx.data("Progress")
	local saved = Progress.clean(self.ctx:session_call("load_settings", { Career.SECTION }))
	local career = Career.rank(saved.xp)
	local rank = if s0 ~= nil and s0.general == true then "Charter holder" else career.name
	local name = if n ~= UICtx.NO_NAME then n else ""
	local text = Progress.greeting(rank, name, saved)
	-- game admins (the server told this client which players are bots): say so, so it's easy to check
	local s = self.ctx.session
	local admin = if s ~= nil and s.admin_bots ~= nil then "  ·  Admin" else ""
	-- (two lines at most in the narrow column: a long name gives way first; it wraps, never cut short with "…")
	local room = TitleScreen.nav_width(self.ctx) - self.ctx.insets.x - (if self.ctx.compact then 24.0 else 44.0)
	if UITheme.measure_text(text .. admin, 13, 500) > 2 * room then
		text = Progress.greeting(rank, "", saved)
	end
	-- (the Admin mark on a line of its own when it won't share the first: never a line that starts with "·")
	if admin ~= "" and UITheme.measure_text(text .. admin, 13, 500) > room then
		text ..= "\nAdmin"
	else
		text ..= admin
	end
	self._greet:set_min_size(Vector2.new(math.max(room, 40), 0))
	self._greet:set_text(text)
end

--- The column is put together once: who you are, then the way in, then the rows.
function TitleScreen._reflow_dock(self)
	if self._nav_built then
		return
	end
	self._nav_built = true
	local nv = self._nav_v
	nv:add_child(self._greet)
	self._greet:set_alignment(W.ALIGN_BEGIN)
	nv:add_child(self._online)
	nv:add_child(self._solo)
	for _, b in ipairs(self._nav_list) do
		nv:add_child(b)
	end
end

--- World's own kind of public match (LobbyRules.MODE_WORLD, on LobbyRules.WORLD_ID): its war always shows it.
TitleScreen.WORLD_MAP = "world"

--- A campaign's choices: the war first, then its map, shown as a picture and not as a labelled button, and who you face.
--- (It takes the board's place while open.)
function TitleScreen._build_solo_menu(self)
	local T = UITheme
	local ctx = self.ctx
	local p = GlassPanel.new(20.0, 16.0, 14, true, 18)
	self._solo_panel = p
	self._solo_open = false
	self:add_child(p)
	local v = T.vbox(10)
	self._solo_v = v
	p:add_child(v)
	local head = T.hbox(10)
	head:add_child(Sheet.back_button(function()
		self:close_solo_menu()
	end))
	local title = T.label("CAMPAIGN ALONE", 17, 800, T.TEXT, 2)
	title.size_flags_horizontal = W.EXPAND_FILL
	title.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(title)
	v:add_child(head)
	local body = T.hbox(10)
	v:add_child(body)
	-- the map: its picture and its name (a press opens the picker)
	local mb = W.Button.new("", "GlassButton")
	mb.pressed:Connect(function()
		self.pick_map:Fire()
	end)
	self._map_btn = mb
	local mv = T.vbox(4)
	mv:set_mouse_filter(W.MOUSE_IGNORE)
	mv:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	mv:set_offsets(6, 6, -6, -4)
	mb:add_child(mv)
	local th = W.Control.new()
	th:set_mouse_filter(W.MOUSE_IGNORE)
	th.size_flags_vertical = W.EXPAND_FILL
	local img = Instance.new("ImageLabel")
	img.Name = "Thumb"
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.Size = UDim2.fromScale(1, 1)
	img.ZIndex = 20
	img.Parent = th.gui
	-- a registered part follows the title's fades (a raw image showed before its panel did)
	th:_part(img, "ImageTransparency", 1.0)
	self._map_thumb = img
	mv:add_child(th)
	self._map_name = T.label("", 13, 700, T.TEXT)
	self._map_name:set_alignment(W.ALIGN_CENTER)
	self._map_name.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._map_name.clip_text = true
	mv:add_child(self._map_name)
	body:add_child(mb)
	local side = T.vbox(4)
	side.size_flags_horizontal = W.EXPAND_FILL
	body:add_child(side)
	-- the kind of war: a drop-down of every mode (Data/Modes; 2026-11-03, the owner: a drop-down, not a press that steps
	-- to the next). The button says the mode in use; a press opens the list under it, a row picks one and closes it.
	local Modes = UICtx.data("Modes")
	self._mode_btn = T.button("", "GlassButton", "chevron", 44.0)
	self._mode_btn:add_theme_constant_override("icon_max_width", 14)
	self._mode_btn.alignment = W.ALIGN_LEFT
	self._mode_btn:set_font_size(15)
	self._mode_desc = T.label("", 12, 500, T.TEXT_2)
	self._mode_desc:set_autowrap(true)
	local list = T.vbox(2)
	list:set_visible(false)
	self._mode_list = list
	self._mode_rows = {}
	local function show_mode()
		local cur = ctx:setting("mode", Modes.DEFAULT)
		local m = Modes.BY_KEY[cur] or Modes.BY_KEY[Modes.DEFAULT]
		self._mode_btn:set_text(string.upper(m.name))
		self._mode_desc:set_text(m.line)
		for key, row in self._mode_rows do
			row:set_pressed_no_signal(key == m.key)
		end
	end
	for _, m in Modes.LIST do
		local row = T.button(m.name, "ChipButton", "", 36.0)
		row.toggle_mode = true
		row.alignment = W.ALIGN_LEFT
		row:set_font_size(14)
		row.mouse_entered:Connect(function()
			self._mode_desc:set_text(m.line)
		end)
		row.mouse_exited:Connect(function()
			show_mode()
		end)
		row.pressed:Connect(function()
			ctx:set_setting("mode", m.key)
			ctx:sfx("tab")
			list:set_visible(false)
			show_mode()
		end)
		list:add_child(row)
		self._mode_rows[m.key] = row
	end
	self._mode_btn.pressed:Connect(function()
		list:set_visible(not list.visible)
		ctx:sfx(if list.visible then "open" else "click", -6.0)
		show_mode()
	end)
	show_mode()
	side:add_child(self._mode_btn)
	side:add_child(list)
	side:add_child(self._mode_desc)
	-- the start date (Data/Periods; 2026-11-08, the owner): today's world, or a year the great medieval strategy games
	-- bookmark, on a map that offers it
	local Periods = UICtx.data("Periods")
	local pr = T.hbox(4)
	self._period_row = pr
	self._period_chips = {}
	local keys = { "" }
	for _, p in Periods.LIST do
		table.insert(keys, p.key)
	end
	for _, key in keys do
		local chip = T.button(if key == "" then "Today" else key, "ChipButton", "", 32.0)
		chip.toggle_mode = true
		chip.size_flags_horizontal = W.EXPAND_FILL
		chip:set_font_size(13)
		chip.pressed:Connect(function()
			ctx:set_setting("period", key)
			ctx:sfx("tab")
			self:_refresh_period()
		end)
		pr:add_child(chip)
		self._period_chips[key] = chip
	end
	-- (across the panel's full width, under the map and the choices beside it: five chips don't fit the side column on a
	-- phone; placed before BEGIN below)
	self._period_desc = T.label("", 12, 500, T.TEXT_2)
	self._period_desc:set_autowrap(true)
	-- the depth of the war (docs/DEPTH_DESIGN.md, 2026-11-09): Classic, or the deep war at the Long or Quick pace; one
	-- button in the side column that steps through them (a row under the map ran a phone's panel off the screen)
	self._depth_btn = T.button("", "ChipButton", "", 32.0)
	self._depth_btn:set_font_size(13)
	self._depth_btn.pressed:Connect(function()
		local cur = TitleScreen.solo_depth(ctx) or ""
		local nxt = ""
		for i, it in TitleScreen.DEPTHS do
			if it[1] == cur then
				nxt = TitleScreen.DEPTHS[i % #TitleScreen.DEPTHS + 1][1]
			end
		end
		ctx:set_setting("depth", nxt)
		ctx:sfx("tab")
		self:_refresh_depth()
	end)
	UICtx.mod("FrameKit").hover(ctx, self._depth_btn, function()
		local cur = TitleScreen.solo_depth(ctx) or ""
		for _, it in TitleScreen.DEPTHS do
			if it[1] == cur then
				return { title = it[2] .. " war", body = if it[4] then TitleScreen.WIP_LINE .. "\n" .. it[3] else it[3] }
			end
		end
		return nil
	end)
	side:add_child(self._depth_btn)
	-- who you face
	local dr = T.hbox(6)
	self._diff_row = dr
	for i = 0, 2 do
		local chip = T.button(TitleScreen.DIFFS[i], "ChipButton", "", 34.0)
		chip.toggle_mode = true
		chip.size_flags_horizontal = W.EXPAND_FILL
		chip:set_pressed_no_signal(i == self.difficulty)
		chip.pressed:Connect(function()
			-- ButtonGroup: exactly one chip stays pressed.
			self.difficulty = i
			for j, ch in ipairs(self._chips) do
				ch:set_pressed_no_signal(j - 1 == i)
			end
			ctx:set_setting("difficulty", i)
			self:_refresh_diff()
		end)
		table.insert(self._chips, chip)
		dr:add_child(chip)
	end
	side:add_child(dr)
	self._diff_desc = T.label("", 12, 500, T.TEXT_2)
	self._diff_desc:set_autowrap(true)
	side:add_child(self._diff_desc)
	self:_refresh_diff()
	local start = T.button("BEGIN", "PrimaryButton", "play", 54.0)
	start:add_theme_constant_override("icon_max_width", 18)
	start:set_font_size(18)
	start.pressed:Connect(function()
		self.play_solo:Fire(self.difficulty)
	end)
	self._start = start
	v:add_child(self._period_row)
	v:add_child(self._period_desc)
	self:_refresh_depth()
	v:add_child(start)
	self:set_map_name("World")
	p:set_visible(false)
end

function TitleScreen.open_solo_menu(self)
	if self._solo_open then
		return
	end
	self._solo_open = true
	self._dock:set_visible(false)
	self._solo_panel:set_visible(true)
	W.slide_in(self._solo_panel, Vector2.new(-Sheet.SLIDE_PX, 0), 0.0, Sheet.SLIDE_S)
	self.ctx:sfx("open", -6.0)
end

--- Back to the board (`quiet`: no sound, e.g. when the title hides).
function TitleScreen.close_solo_menu(self, quiet: boolean?)
	if not self._solo_open then
		return
	end
	self._solo_open = false
	self._solo_panel:set_visible(false)
	self._dock:set_visible(not self.ctx:mp_waiting())
	if not quiet then
		self.ctx:sfx("close", -6.0)
	end
end

function TitleScreen._refresh_diff(self)
	self._diff_desc:set_text(TitleScreen.DIFF_BLURB[self.difficulty])
end

function TitleScreen._size_word(self, px: number)
	self._word:set_px(px)
	self._word.spacing = math.floor(px * 0.12)
	self._word_target_spacing = self._word.spacing
	self._word:update_minimum_size()
	self._word:_redraw()
end

function TitleScreen.on_show(self)
	self:_refresh_greeting()
	if self._hide_tween ~= nil then
		self._hide_tween:kill()
		self._hide_tween = nil
	end
	self:_refresh_queue_mode()
	self:_refresh_mp()
	self:set_modulate_a(1.0)
	self:_refresh_diff()
	-- Entrance: the map is simply there; the column comes in from the edge, the board rises after it.
	self:_refresh_nav()
	for _, n in { self._nav_bg, self._nav_edge, self._head, self._nav_scroll } do
		W.slide_in(n, Vector2.new(-60, 0), 0.0, 0.28)
	end
	W.slide_in(self._dock, Vector2.new(0, 24), 0.2, 0.3)
	W.slide_in(self._queue, Vector2.new(0, 24), 0.2, 0.3)
end

--- Play Solo was pressed: the new world is being built in the background.
function TitleScreen.set_building(self, on: boolean)
	self._solo:set_disabled(on)
	self._online:set_disabled(on)
	self._start:set_disabled(on)
	self._start:set_text(if on then "MARCHING…" else "BEGIN")
	for _, ch in ipairs(self._chips) do
		ch:set_disabled(on)
	end
end

function TitleScreen.hide_animated(self)
	if not self.visible or (self._hide_tween ~= nil and self._hide_tween:is_running()) then
		return
	end
	self._hide_tween = self:create_tween()
	self._hide_tween:tween_property(self, "modulate:a", 0.0, 0.3):set_trans(W.TRANS_CUBIC):set_ease(W.EASE_IN)
	self._hide_tween:tween_callback(function()
		self:set_visible(false)
		self:set_modulate_a(1.0)
		-- next time the title shows, it opens on the board again
		self:close_solo_menu(true)
	end)
end

function TitleScreen.set_lobby(self, info: any)
	self._lobby = info or {}
	self._lobby_msec = UICtx.msec()
	self:_refresh_mp()
end

function TitleScreen._refresh_queue_mode(self)
	local waiting = self.ctx:mp_waiting()
	if waiting and not self._was_waiting then
		self.ctx:sfx("queue_start") -- (Airship BedWars' queue sound: the waiting room opens)
	end
	self._was_waiting = waiting
	local mm = self:_mm_state()
	if mm ~= nil then
		self:close_solo_menu(true)
	end
	-- the matchmaking screen: the menu's column and board step aside, the map dims, one panel in the middle
	local menu = mm == nil
	for _, n in { self._head, self._nav_scroll, self._nav_bg, self._nav_edge, self._credits } do
		if n ~= nil and n.visible ~= menu then
			n:set_visible(menu)
		end
	end
	self._mm_dim:set_visible(not menu)
	if self._news ~= nil then
		self:_layout_news(menu and not self._solo_open)
	end
	self._pick:set_visible(mm == "pick")
	self._queue:set_visible(mm == "muster" or mm == "line")
	self._dock:set_visible(menu and not self._solo_open)
	for _, cn in { self._queue, self._pick } do
		if cn.visible then
			cn.anchor_left, cn.anchor_right, cn.anchor_top, cn.anchor_bottom = 0.5, 0.5, 0.5, 0.5
			cn.grow_horizontal = W.GROW_BOTH
			cn.grow_vertical = W.GROW_BOTH
			cn.offset_left, cn.offset_right, cn.offset_top, cn.offset_bottom = 0, 0, 0, 0
			cn:set_min_size(Vector2.new(math.min(TitleScreen.MUSTER_W + 80, self.ctx.vp.X - 32), 0))
			cn:reset_size()
		end
	end
	if mm == "pick" then
		self:_refresh_pick()
	elseif mm == "line" then
		self:_show_line()
	end
end

--- The matchmaking screen while the hub finds a seat: the war asked for, how it stands, and a way out of the line.
function TitleScreen._show_line(self)
	local pub = self._public
	local T = UITheme
	local elapsed = (UICtx.msec() - (self._lobbies_msec or UICtx.msec())) / 1000.0
	local lobby = nil
	for _, fr in self:_fronts(elapsed) do
		if fr.kind == pub.mode then
			lobby = fr.lobby
		end
	end
	self._q_title:set_text(string.upper(TitleScreen.kind_name(tostring(pub.mode), lobby)))
	self._q_vote:set_visible(false)
	if pub.state == "line" then
		self._q_where:set_text("Every seat is taken. You're next in line.")
		self._q_status:set_text(T.fmt_time(math.max(0, math.floor((UICtx.msec() - (self._public_since or UICtx.msec())) / 1000))))
	elseif pub.state == "going" then
		self._q_where:set_text("Marching to the war…")
		self._q_status:set_text("")
	else
		self._q_where:set_text("Finding you a seat…")
		self._q_status:set_text("")
	end
	if lobby ~= nil then
		local where = tostring(lobby.map_name or lobby.map)
		local per = if type(lobby.id) == "string" then UICtx.data("Modes").period_pick(lobby.id, lobby.map) else nil
		local n = tonumber(lobby.players) or 0
		self._q_players:set_text(string.format("On %s%s  ·  %d %s in", where, if per ~= nil then " in " .. per else "", n, if n == 1 then "ruler" else "rulers"))
	else
		self._q_players:set_text("")
	end
	self._q_leave:set_text("Leave the line")
end

function TitleScreen._countdown(self): number
	local cd = tonumber(self._lobby.countdown_s) or 0.0
	return math.max(0.0, cd - (UICtx.msec() - self._lobby_msec) / 1000.0)
end

--- The wars on offer from the lobby list (hub servers), the soonest first: { { kind, lobby? } }.
function TitleScreen._fronts(self, elapsed: number): { any }
	-- the open lobbies with room (running matches aren't shown)
	local open = {}
	for _, lb in self._lobbies or {} do
		if lb.live then
			continue
		elseif
			((tonumber(lb.max) or 0) <= 0 or (tonumber(lb.players) or 0) < (tonumber(lb.max) or 0))
			and lb.joinable ~= false
			and math.ceil((tonumber(lb.starts_in) or 0) - elapsed) > TitleScreen.JOIN_CLOSE_S
		then
			-- (a lobby that filled up, or whose joins closed while the list counted down here, is
			-- gone: the next one is the one to join)
			table.insert(open, lb)
		end
	end
	-- Quick Play: a war per kind on offer, showing the soonest of the lobbies MARCH may seat in; MARCH asks the hub for a seat
	-- in that kind, and with every match of it full the player waits in line.
	local soonest: { [string]: any } = {}
	local has_team = false
	for _, lb in open do
		local k = if lb.mode == "team" or lb.mode == "world" or lb.mode == "hardcore" then lb.mode else "ffa"
		soonest[k] = soonest[k] or lb
		has_team = has_team or k == "team"
	end
	-- the free-for-all takes World's seats too (the server's LobbyRules.takes_from): its next war is World's when that
	-- starts sooner (a tie: the free-for-all, as the server picks)
	local of_kind: { [string]: any } = table.clone(soonest)
	local w, f = soonest.world, soonest.ffa
	if w ~= nil and (f == nil or (tonumber(w.starts_in) or 0) < (tonumber(f.starts_in) or 0)) then
		of_kind.ffa = w
	end
	local out = {}
	for i, kind in self._kinds or (if has_team then { "ffa", "team" } else { "ffa" }) do
		table.insert(out, { kind = kind, lobby = of_kind[kind], order = i })
	end
	-- (the board leads with what marches first, not with a fixed order of kinds)
	table.sort(out, function(a, b)
		local la, lb = a.lobby, b.lobby
		if (la ~= nil) ~= (lb ~= nil) then
			return la ~= nil
		end
		local sa, sb = if la then tonumber(la.starts_in) or 0 else 0, if lb then tonumber(lb.starts_in) or 0 else 0
		if sa ~= sb then
			return sa < sb
		end
		return a.order < b.order
	end)
	return out
end

--- "+2": the board turns to the next war on offer.
function TitleScreen._next_front(self)
	local fronts = self._shown_fronts or {}
	local at = 0
	for i, fr in fronts do
		if fr.kind == self._front_mode then
			at = i
		end
	end
	local nx = fronts[at % math.max(#fronts, 1) + 1]
	if nx ~= nil then
		self._front_pick = nx.kind
		self.ctx:sfx("tab")
		self:_refresh_mp()
	end
end

--- MARCH: a seat in the war shown, or out of the line again; with no list yet, the server's own way in.
function TitleScreen._march_pressed(self)
	local kind = self._front_mode
	if kind == nil then
		-- (no list yet. A public hub runs no war itself, so it is Quick Play's first kind of war, never a match on the
		-- hub: release audit 2026-11-07. Studio, with no teleports, plays the war on this server.)
		local studio = false
		pcall(function()
			studio = game:GetService("RunService"):IsStudio()
		end)
		local lobby = if self.ctx.session ~= nil then self.ctx.session.lobby else nil
		if studio or (type(lobby) == "table" and lobby.kind == "match") then
			self.play_multi:Fire()
		elseif self._public.state == "idle" and self._joining == nil then
			self:set_public({ state = "joining", mode = "ffa" })
			self.join_public:Fire("ffa")
		end
		return
	end
	local pub = self._public
	if pub.state == "line" and pub.mode == kind then
		self.leave_line:Fire()
	elseif pub.state == "idle" and self._joining == nil then
		self:set_public({ state = "joining", mode = kind })
		self.join_public:Fire(kind)
	end
end

--- How full a war is, on the thin bar (0 hides it).
function TitleScreen._set_muster(self, have: number, of: number)
	local share = if of > 0 then math.clamp(have / of, 0, 1) else 0
	self._muster_fill:set_anchors(0, 0, share, 1)
	self._muster_fill:set_offsets(0, 0, 0, 0)
end

--- The war on the board, from the lobby list.
function TitleScreen._refresh_fronts(self)
	local elapsed = (UICtx.msec() - self._lobbies_msec) / 1000.0
	local fronts = self:_fronts(elapsed)
	self._shown_fronts = fronts
	local pub = self._public
	-- your own ask stays on the board; else the war you turned to, while it is on offer; else the soonest
	local want = if pub.state ~= "idle" then pub.mode else self._front_pick
	local front = fronts[1]
	for _, fr in fronts do
		if fr.kind == want then
			front = fr
		end
	end
	if front == nil then
		self._front_mode = nil
		return
	end
	self._front_mode = front.kind
	self:_show_front(front.kind, front.lobby, elapsed)
	-- (every other war has its own row under it now: no "+2" to step through them)
	self._next_b:set_visible(false)
	self:_fill_others(if pub.state == "idle" then fronts else {}, front.kind, elapsed)
end

--- What the board says of one war: `l`, its soonest lobby with room (nil: none listed; MARCH still puts the player in line).
function TitleScreen._show_front(self, kind: string, l: any?, elapsed: number)
	local ctx = self.ctx
	local pub = self._public
	local mine = pub.state ~= "idle" and pub.mode == kind
	local busy_other = pub.state ~= "idle" and not mine
	local follower = self._in_party and not self._party_leader
	local going = mine and pub.state == "going" and type(pub.info) == "table"
	-- the kind of war leads: its sides in a team war, else its mode (the server's word, LobbyRules.public_view)
	local war = if l ~= nil and type(l.war_mode) == "string" then UICtx.data("Modes").BY_KEY[l.war_mode] else nil
	local sides = if l ~= nil and l.mode == "team" and l.teams ~= nil then Teams.label(l.teams, ctx.compact) else nil
	local name = if sides ~= nil
		then sides
		elseif war ~= nil then (if ctx.compact then war.short or war.name else war.name)
		elseif kind == "team" then "A war of sides"
		else "An open war"
	self._war_title:set_color(UITheme.TEXT)
	self._war_title:set_text(string.upper(if going then tostring(pub.info.map_name or pub.info.map or name) else name))
	-- where and who. A free-for-all can seat you in another of its lobbies, so it says where one is forming, no more.
	local where = if kind == "world"
		then "On the World"
		elseif l == nil then nil
		elseif kind == "ffa" and not ctx.compact then "Forming on " .. tostring(l.map_name or l.map)
		elseif kind == "ffa" then tostring(l.map_name or l.map)
		else "On " .. tostring(l.map_name or l.map)
	-- its start date, when the war plays one (Data/Modes.period_pick: the match plays what the card says)
	local per = if l ~= nil and type(l.id) == "string" then UICtx.data("Modes").period_pick(l.id, l.map) else nil
	if per ~= nil and where ~= nil then
		where ..= " in " .. per
	end
	local text
	local clock = ""
	if mine and pub.state == "line" then
		clock = UITheme.fmt_time(math.max(0, math.floor((UICtx.msec() - self._public_since) / 1000)))
		text = "Every seat is taken. You're next."
	elseif mine then
		text = if pub.state == "going" then "Marching…" else "Sending word…"
	elseif l ~= nil then
		clock = UITheme.fmt_time(math.max(0, math.ceil((tonumber(l.starts_in) or 0) - elapsed)))
		local n = tonumber(l.players) or 0
		local who = if n <= 0
			then "Nobody yet"
			elseif ctx.compact then string.format("%d in", n)
			else string.format("%d %s in", n, if n == 1 then "ruler" else "rulers")
		text = string.format("%s  ·  %s", where, who)
	else
		text = if kind == "world" then where .. "  ·  be the first in line" else "Nothing forming. Be the first in line."
	end
	self._war_line:set_text(text)
	self._war_left:set_text(clock)
	self:_set_muster(if l ~= nil then tonumber(l.players) or 0 else 0, if l ~= nil then tonumber(l.max) or 0 else 0)
	self._march:set_visible(true)
	self._march:set_text(
		if follower
			then (if ctx.compact then "CAPTAIN" else "CAPTAIN'S CALL")
			elseif mine and pub.state == "line" then "STEP OUT"
			elseif mine then "…"
			else "MARCH"
	)
	local ready = not follower and not busy_other and (pub.state == "idle" or (mine and pub.state == "line"))
	self._march:set_disabled(not ready or self._joining ~= nil)
end

function TitleScreen._refresh_mp(self)
	local ctx = self.ctx
	if self._lobbies ~= nil and not ctx:mp_waiting() then
		self:_refresh_fronts()
		if self._front_mode ~= nil then
			return
		end
	end
	-- no lobby list (yet): one short word on the server, and the way in it offers
	self._front_mode = nil
	self._next_b:set_visible(false)
	self:_fill_others({}, nil, 0)
	self:_set_muster(0, 0)
	local mpa = ctx:session_call("multiplayer_available")
	local st = ctx:session_call("multiplayer_status")
	local status = if type(st) == "string" then st else (if mpa == true then "connected" else "offline")
	local avail = status == "connected"
	local stage = tostring(self._lobby.stage or "idle")
	local players = self._lobby.players or {}
	local n = #players
	local text
	local march = "MARCH"
	if status == "connecting" then
		text = "Sending riders…"
		march = ""
	elseif not avail then
		text = "The riders didn't get through."
		march = "TRY AGAIN"
	elseif stage == "lobby" then
		text = "Marches in " .. UITheme.fmt_time(math.ceil(self:_countdown()))
	elseif stage == "spawn" or stage == "playing" then
		text = "A war is under way."
	else
		text = "Nobody has marched yet."
	end
	self._war_title:set_text("OPEN WAR")
	self._war_title:set_color(if avail then UITheme.TEXT else UITheme.TEXT_2)
	self._war_line:set_text(text)
	self._war_left:set_text("")
	self._march:set_visible(march ~= "")
	self._march:set_text(march)
	self._march:set_disabled(false)
	-- The muster
	if ctx:mp_waiting() and self._lobby.kind == "match" then
		-- a public lobby's own server: the muster until the match starts
		local e = UIMaps.get(self._lobby.map_id)
		local tm = self._lobby.teams
		local Modes = UICtx.data("Modes")
		local wm = Modes.BY_KEY[self._lobby.war_mode]
		self._q_title:set_text(string.upper(if tm ~= nil then Teams.label(tm, ctx.compact) elseif wm ~= nil then wm.name else "Open war"))
		local pr = UICtx.data("Periods").get(self._lobby.period)
		self._q_where:set_text("On " .. (if e then e.name else "the World") .. (if pr ~= nil then string.format(" in %d · %s", pr.year, pr.name) else ""))
		local maxp = tonumber(self._lobby.max) or 0
		local votes = tonumber(self._lobby.votes) or 0
		local need = math.max(tonumber(self._lobby.votes_needed) or 1, 1)
		local started = self._lobby.vote_started == true
		if stage == "lobby" then
			self._q_status:set_text(UITheme.fmt_time(math.ceil(self:_countdown())))
		elseif stage == "spawn" or stage == "playing" then
			self._q_status:set_text("Marching…")
		else
			self._q_status:set_text("")
		end
		local names = {}
		for _, p in ipairs(players) do
			table.insert(names, tostring(p))
		end
		local open = maxp - n
		self._q_players:set_text(
			if n <= 0
				then "Nobody has marched yet."
				elseif open > 0 then string.format("%s  ·  %d more can come", table.concat(names, ", "), open)
				else table.concat(names, ", ")
		)
		self._q_leave:set_text("Step away")
		-- the call to march: two thirds of the rulers here send it in 10 s (MatchServer.VOTE_SHARE)
		local can_vote = stage == "lobby" and self._lobby.spectating ~= true
		self._q_vote:set_visible(can_vote)
		if can_vote then
			local to_go = math.max(need - votes, 0)
			local min_players = tonumber(self._lobby.vote_min_players) or 2
			local lonely = (tonumber(self._lobby.vote_players) or n) < min_players
			-- alone: a lone call may start the match after a short wait (MatchServer.VOTE_SOLO_AFTER_S)
			local solo_in = tonumber(self._lobby.vote_solo_in)
			if solo_in ~= nil then
				solo_in = math.max(0, math.ceil(solo_in - (UICtx.msec() - self._lobby_msec) / 1000.0))
			end
			self._q_vote:set_text(
				if started
					then "Marching…"
					elseif lonely and solo_in ~= nil then "March alone at " .. UITheme.fmt_time(solo_in)
					elseif lonely then string.format("A march takes %d rulers", min_players)
					elseif self._lobby.voted == true then
						(if ctx.compact then "You called  ·  undo" elseif to_go > 0 then string.format("You called  ·  %d more  ·  take it back", to_go) else "You called  ·  take it back")
					elseif to_go > 0 then string.format("Call to march  ·  %d more", to_go)
					else "Call to march"
			)
			self._q_vote:set_disabled(started or (lonely and self._lobby.voted ~= true))
		end
	elseif ctx:mp_waiting() then
		self._q_vote:set_visible(false)
		self._q_title:set_text("OPEN WAR")
		self._q_where:set_text("")
		self._q_leave:set_text("Step away")
		if stage == "lobby" then
			self._q_status:set_text(UITheme.fmt_time(math.ceil(self:_countdown())))
		elseif stage == "spawn" or stage == "playing" then
			self._q_where:set_text("Joining a war under way")
			self._q_status:set_text("")
		elseif stage == "over" then
			self._q_where:set_text("The last war is ending")
			self._q_status:set_text("")
		else
			self._q_where:set_text("Sending riders…")
			self._q_status:set_text("")
		end
		local names = {}
		for _, p in ipairs(players) do
			table.insert(names, tostring(p))
		end
		self._q_players:set_text(if n > 0 then table.concat(names, ", ") else "Nobody has marched yet.")
	end
end

function TitleScreen._process(self, delta: number)
	if not self.visible then
		return
	end
	self._accum += delta
	if self._accum >= 0.25 then
		self._accum = 0.0
		self:_refresh_queue_mode()
		self:_refresh_mp()
		self:_refresh_greeting()
		self:_refresh_nav()
		-- the party: on the title itself, not over the waiting room
		local party_on = self._party.state ~= nil and not self.ctx:mp_waiting()
		if self._party.visible ~= party_on then
			self._party:set_visible(party_on)
			self._party:apply_layout()
		end
	end
	self:_countdown_ticks()
end

TitleScreen.TICK_FROM_S = 10

--- The muster: BedWars' countdown — its tick each second over the last TICK_FROM_S
--- before the match starts, its numbered ticks over the last five, its start sound at zero.
function TitleScreen._countdown_ticks(self)
	local ctx = self.ctx
	if not ctx:mp_waiting() or tostring(self._lobby.stage) ~= "lobby" then
		self._tick_sec = -1
		return
	end
	local sec = math.ceil(self:_countdown())
	local prev = self._tick_sec or -1
	if sec == prev then
		return
	end
	self._tick_sec = sec
	-- (the first reading only arms it; a countdown that jumps back up doesn't tick)
	if prev < 0 or sec >= prev or sec > TitleScreen.TICK_FROM_S then
		return
	end
	-- (sparse until the last three: Audio/Cadence)
	local beat = Cadence.LOBBY_TICKS[math.max(sec, 0)]
	if beat ~= nil then
		ctx:sfx(beat[1], beat[2], 0.0, beat[3])
	end
end

return TitleScreen
