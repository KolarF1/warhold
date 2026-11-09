--!nonstrict
-- Opening Spoils: a dispatch reaches your desk, you break its seal, and the paper tells you what was won. Quiet on purpose:
-- nothing shakes or builds up, no light says what is inside before the paper does, and it takes under three seconds.
--
--   arrive  the dark comes up and the folded paper slides in from the side; SPOILS over it
--   seal    it waits for you ("BREAK THE SEAL"): it never opens by itself
--   break   the seal's halves part; if the server's answer is still on its way the paper waits, cracked
--   unfold  the paper opens downward from its fold, the item already written on it
--   stamp   the rarity comes down on the paper; a Mythic also rules the paper's edge in its colour
--   choose  fly it or file it: nothing else is asked here, and another is only offered on the Banners sheet
--
-- With nothing left to find the paper says what it paid in Renown (Purchases.open_crate).
-- UI/Locker drives it: play(info) as it is opened, resolve(item_id) / resolve_renown(n) / fail(text) from the server.
-- Signals: wear(item_id), closed(fail_text?), shown(open). `pace` > 1 slows it all (frame captures).
local UITheme = require("./UITheme")
local W = require("./Widgets")
local DispatchArt = require("./DispatchArt")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")

local IS_ROBLOX = typeof(game) == "Instance"
local Airfront: any = if IS_ROBLOX then (game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront") else nil
local Cosmetics: any = if IS_ROBLOX then require(Airfront.Data.Cosmetics) else (require :: any)("../../shared/Data/Cosmetics")
local TweenService = if IS_ROBLOX then game:GetService("TweenService") else nil
local UserInputService = if IS_ROBLOX then game:GetService("UserInputService") else nil

local CrateOpening = W.class(W.Control)

CrateOpening.ARRIVE_S = 0.32
CrateOpening.BREAK_S = 0.22
CrateOpening.UNFOLD_S = 0.34
--- The moment between the paper opening and its stamp (a rarer one holds a little longer).
CrateOpening.STAMP_WAIT_S = { common = 0.12, rare = 0.18, epic = 0.28, legendary = 0.42 }
CrateOpening.STAMP_S = 0.16
--- How long the server's answer is waited for, seal broken, before the dispatch is said to be safe.
CrateOpening.RESULT_WAIT_S = 12.0

local FONT_B = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FONT_M = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local DARK = Color3.fromRGB(14, 15, 17)
local STAMP_GROUND = Color3.fromRGB(28, 25, 20)

local function c3(hex: number): Color3
	return Color3.fromRGB((hex // 65536) % 256, (hex // 256) % 256, hex % 256)
end

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		UITheme.assign(i, k, v)
	end
	if parent then
		i.Parent = parent
	end
	return i
end

function CrateOpening.new(c: any)
	local self = setmetatable({}, CrateOpening.__mt)
	W.Control._init(self)
	self.ctx = c
	self.wear = Signal.new()
	self.closed = Signal.new()
	self.shown = Signal.new() -- (open: boolean) it starts / ends (the top bar row hides)
	self.is_open = false
	self.pace = 1.0
	self._gen = 0
	self._phase = "off"
	self._item = nil
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	self:set_mouse_filter(W.MOUSE_STOP)
	self:set_visible(false)
	self:_build()
	return self
end

function CrateOpening._tween(self, inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	if TweenService == nil then
		return
	end
	local secs = if UITheme.reduced_motion then 0 else t * self.pace
	TweenService:Create(inst, TweenInfo.new(secs, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ---------------------------------------------------------------------------------------------
-- Build (once)
-- ---------------------------------------------------------------------------------------------

function CrateOpening._build(self)
	local root = self.gui
	-- ZIndex 1: under the kit's buttons row (the kit numbers its children from 11)
	local stage = new("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, root)
	self._stage = stage
	self._dim = new("Frame", {
		Name = "Dim",
		BackgroundColor3 = DARK,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(2, 2),
		Position = UDim2.fromScale(-0.5, -0.5),
		ZIndex = 1,
	}, stage)
	local function text(name: string, font: Font, color: Color3, z: number, parent: Instance): TextLabel
		return new("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			Text = "",
			FontFace = font,
			TextColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = z,
		}, parent)
	end
	self._title = text("Title", FONT_B, UITheme.WHITE, 3, stage)
	self._subtitle = text("Subtitle", FONT_M, Color3.fromRGB(190, 190, 186), 3, stage)
	self._title.TextTransparency, self._subtitle.TextTransparency = 1, 1
	-- what slides in: the open paper under the folded flap and its seal
	local letter = new("Frame", { Name = "Letter", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, stage)
	self._letter = letter
	local sheet = new("Frame", {
		Name = "Sheet",
		BackgroundColor3 = DispatchArt.PAPER,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = 4,
	}, letter)
	self._sheet = sheet
	self._edge = new("UIStroke", { Color = DispatchArt.CREASE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, sheet)
	self._line = text("From", FONT_M, DispatchArt.CREASE, 5, sheet)
	self._line.Text = "FROM THE FRONT"
	self._preview = new("ImageLabel", {
		Name = "Preview",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 5,
	}, sheet)
	self._name = text("ItemName", FONT_B, DispatchArt.INK, 5, sheet)
	self._kind = text("Kind", FONT_M, DispatchArt.CREASE, 5, sheet)
	local fold = new("Frame", { Name = "Fold", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6 }, letter)
	self._fold = fold
	self._art = DispatchArt.build(fold, 6)
	-- the stamp: over the paper's corner, outside its clip
	local stamp = new("Frame", {
		Name = "Stamp",
		BackgroundColor3 = STAMP_GROUND,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = -7,
		Visible = false,
		ZIndex = 9,
	}, stage)
	self._stamp = stamp
	new("UICorner", { CornerRadius = UDim.new(0, 3) }, stamp)
	self._stamp_edge = new("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, stamp)
	self._stamp_scale = new("UIScale", {}, stamp)
	self._stamp_text = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_B,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	}, stamp)
	-- what to do
	self._hint = text("Hint", FONT_B, UITheme.WHITE, 8, stage)
	self._hint.TextTransparency = 1
	-- a press anywhere breaks the seal (the buttons row sits above the stage)
	self._catch = new("TextButton", {
		Name = "Tap",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 18,
	}, stage)
	self._catch.Activated:Connect(function()
		if self._phase == "arrive" or self._phase == "seal" then
			self._tapped = true
		end
	end)
	-- the choice (kit buttons in a row, placed in _layout)
	local row = UITheme.hbox(10)
	row:set_alignment(W.ALIGN_CENTER)
	self._row = row
	self._wear_b = UITheme.button("FLY IT", "PrimaryButton", "check", 48.0)
	self._wear_b.pressed:Connect(function()
		if self._item then
			self.wear:Fire(self._item)
		end
		self:close()
	end)
	row:add_child(self._wear_b)
	self._done_b = UITheme.button("FILE IT", "GlassButton", "", 48.0)
	self._done_b.pressed:Connect(function()
		self:close()
	end)
	row:add_child(self._done_b)
	row:set_visible(false)
	self:add_child(row)
end

-- ---------------------------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------------------------

--- The stage unit: the paper and the words scale with it.
function CrateOpening._size(self): number
	local area = self.ctx:clear_rect()
	return math.min(area.Width * 0.7, area.Height * 0.7, 520)
end

--- Is the paper open yet (the layout keeps it as it is)?
function CrateOpening._opened(self): boolean
	return self._phase == "unfold" or self._phase == "stamp" or self._phase == "choose"
end

-- (the stage's raw instances are sized in px: logical px x UITheme.scale; the kit's buttons row keeps logical px)
function CrateOpening._layout(self)
	local u = UITheme.scale
	local area = self.ctx:clear_rect()
	local SL = self:_size()
	local S = SL * u
	local cx = (area.Min.X + area.Width * 0.5) * u
	local cy = (area.Min.Y + area.Height * 0.46) * u
	local function ts(k: number, lo: number, hi: number): number
		return math.floor(math.clamp(SL * k, lo, hi) * u)
	end
	local w, h, fh = S * 0.8, S * 0.86, S * 0.42
	self._w, self._h, self._fh, self._cx, self._cy = w, h, fh, cx, cy
	self._title.Size = UDim2.fromOffset(S * 2, S * 0.12)
	self._title.TextSize = ts(0.09, 22, 44)
	self._title.Position = UDim2.fromOffset(cx, cy - fh * 0.5 - S * 0.18)
	self._subtitle.Size = UDim2.fromOffset(S * 2, S * 0.06)
	self._subtitle.TextSize = ts(0.036, 12, 16)
	self._subtitle.Position = UDim2.fromOffset(cx, cy - fh * 0.5 - S * 0.09)
	self._hint.Size = UDim2.fromOffset(S * 1.6, S * 0.08)
	self._hint.TextSize = ts(0.04, 13, 18)
	self._hint.Position = UDim2.fromOffset(cx, cy + fh * 0.5 + S * 0.09)
	self._fold.Size = UDim2.fromOffset(w, fh)
	self._fold.Position = UDim2.fromOffset(cx, cy)
	DispatchArt.place(self._art, w, fh)
	self._line.Size = UDim2.fromOffset(w, S * 0.06)
	self._line.TextSize = ts(0.03, 12, 14)
	self._line.Position = UDim2.fromOffset(w * 0.5, S * 0.05)
	self._preview.Size = UDim2.fromOffset(w * 0.78, h * 0.5)
	self._preview.Position = UDim2.fromOffset(w * 0.5, h * 0.4)
	self._name.Size = UDim2.fromOffset(w * 0.94, S * 0.08)
	self._name.TextSize = ts(0.06, 18, 32)
	self._name.Position = UDim2.fromOffset(w * 0.5, h * 0.74)
	self._kind.Size = UDim2.fromOffset(w * 0.94, S * 0.05)
	self._kind.TextSize = ts(0.03, 12, 14)
	self._kind.Position = UDim2.fromOffset(w * 0.5, h * 0.82)
	if self:_opened() then
		self._sheet.Position = UDim2.fromOffset(cx, cy - h * 0.5)
		self._sheet.Size = UDim2.fromOffset(w, h)
	else
		self._sheet.Position = UDim2.fromOffset(cx, cy - fh * 0.5)
		self._sheet.Size = UDim2.fromOffset(w, fh)
	end
	local sw, sh = math.max(S * 0.34, 96 * u), math.max(S * 0.09, 28 * u)
	self._stamp.Size = UDim2.fromOffset(sw, sh)
	-- (under the item's words, where the paper is empty: it never covers what the letter says)
	self._stamp.Position = UDim2.fromOffset(cx, cy + h * 0.42)
	self._stamp_text.TextSize = math.floor(sh * 0.56)
	local compact = self.ctx.compact
	local bh = if compact then 42 else 48
	self._wear_b:set_min_size(Vector2.new(if compact then 128 else 170, bh))
	self._done_b:set_min_size(Vector2.new(if compact then 128 else 170, bh))
	local rs = self._row:get_combined_minimum_size()
	local ry = math.min(area.Max.Y - rs.Y - 8, (cy + h * 0.5) / u + 12)
	local rx = cx / u
	self._row:set_offsets(rx - rs.X * 0.5, ry, rx + rs.X * 0.5, ry + rs.Y)
	self._row:reset_size()
end

function CrateOpening.apply_layout(self)
	if self.is_open then
		self:_layout()
	end
end

-- ---------------------------------------------------------------------------------------------
-- Opening one
-- ---------------------------------------------------------------------------------------------

--- `info` = { crates, wearing } (how many more wait, and what the player uses).
function CrateOpening.play(self, info: any)
	self._gen += 1
	local gen = self._gen
	self._info = info or {}
	self._item, self._renown, self._rar, self._fail, self._tapped = nil, nil, nil, nil, false
	self._phase = "arrive"
	local was_open = self.is_open
	self.is_open = true
	self:set_visible(true)
	if not was_open then
		self.shown:Fire(true)
	end
	self:_layout()
	-- back to folded and sealed
	self._art.flap.BackgroundTransparency = 0
	self._art.stroke.Transparency = 0
	for _, c in self._art.creases do
		c.BackgroundTransparency = 0
	end
	for _, s in { self._art.left, self._art.right } do
		s.disc.BackgroundTransparency = 0
		s.rim.Transparency = 0
		s.mark.ImageTransparency = 0
	end
	DispatchArt.place(self._art, self._w, self._fh)
	self._fold.Visible = true
	self._sheet.BackgroundTransparency = 0
	self._edge.Color = DispatchArt.CREASE
	self._edge.Thickness = 1
	self._edge.Transparency = 0
	self._line.TextTransparency, self._name.TextTransparency, self._kind.TextTransparency = 0, 0, 0
	self._preview.ImageTransparency = 0
	self._name.Text, self._kind.Text = "", ""
	self._preview.Image = ""
	self._stamp.Visible = false
	self._row:set_visible(false)
	self._dim.BackgroundTransparency = 1
	self:_tween(self._dim, 0.25, { BackgroundTransparency = 0.04 })
	self._title.Text = "SPOILS"
	self._subtitle.Text = "Something new for your banner, under seal"
	self._title.TextTransparency, self._subtitle.TextTransparency = 1, 1
	self:_tween(self._title, 0.25, { TextTransparency = 0 })
	self:_tween(self._subtitle, 0.25, { TextTransparency = 0.1 })
	self._hint.TextTransparency = 1
	self._letter.Position = UDim2.fromOffset(-(self._cx + self._w), 0)
	self:_tween(self._letter, CrateOpening.ARRIVE_S, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Cubic)
	self.ctx:sfx("card_whoosh")
	task.spawn(function()
		self:_run(gen)
	end)
end

--- The server's roll.
function CrateOpening.resolve(self, id: string)
	self._item = id
	local it = Cosmetics.item(id)
	if it then
		self._rar = Cosmetics.rarity(it.rarity)
	end
end

--- Nothing was left to find: the dispatch paid `n` Renown.
function CrateOpening.resolve_renown(self, n: number)
	self._renown = n
end

--- It couldn't be opened (the server said why): it ends with a word.
function CrateOpening.fail(self, text: string)
	self._fail = text
	self:close()
end

--- Wait `t` seconds; false once this one was replaced or closed.
function CrateOpening._sleep(self, gen: number, t: number): boolean
	local left = if UITheme.reduced_motion then 0 else t
	while left > 0 do
		if gen ~= self._gen then
			return false
		end
		left -= task.wait() / math.max(self.pace, 0.05)
	end
	return gen == self._gen
end

function CrateOpening._answered(self): boolean
	return self._item ~= nil or self._renown ~= nil
end

function CrateOpening._run(self, gen: number)
	if not self:_sleep(gen, CrateOpening.ARRIVE_S) then
		return
	end
	self._phase = "seal"
	local touch = UserInputService ~= nil and UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	self._hint.Text = if touch then "TAP TO BREAK THE SEAL" else "CLICK TO BREAK THE SEAL"
	self:_tween(self._hint, 0.2, { TextTransparency = 0 })
	while not self._tapped do
		if gen ~= self._gen then
			return
		end
		task.wait()
	end
	self:_tween(self._hint, 0.12, { TextTransparency = 1 })
	if not self:_break_seal(gen) or not self:_await_answer(gen) or not self:_unfold(gen) or not self:_stamp_down(gen) then
		return
	end
	self._phase = "choose"
	self:refresh_buttons()
	self._row:set_visible(true)
	self._row:set_modulate_a(0)
	W.fade(self._row, 1.0, 0.2)
end

--- The seal's two halves part and fade.
function CrateOpening._break_seal(self, gen: number): boolean
	self._phase = "break"
	self.ctx:sfx("crate_open", 0, 0)
	local apart = self._w * 0.12
	for i, s in { self._art.left, self._art.right } do
		local to = s.box.Position + UDim2.fromOffset(if i == 1 then -apart else apart, self._fh * 0.06)
		self:_tween(s.box, CrateOpening.BREAK_S, { Position = to }, Enum.EasingStyle.Quart)
		self:_tween(s.disc, CrateOpening.BREAK_S, { BackgroundTransparency = 1 })
		self:_tween(s.rim, CrateOpening.BREAK_S, { Transparency = 1 })
		self:_tween(s.mark, CrateOpening.BREAK_S, { ImageTransparency = 1 })
	end
	return self:_sleep(gen, CrateOpening.BREAK_S)
end

function CrateOpening._await_answer(self, gen: number): boolean
	local waited = 0.0
	while not self:_answered() do
		if gen ~= self._gen then
			return false
		end
		waited += task.wait()
		if waited > CrateOpening.RESULT_WAIT_S then
			self:fail("These Spoils stayed sealed. They're safe: try again soon.")
			return false
		end
	end
	return gen == self._gen
end

--- The item is written on the paper, and the paper opens downward from the fold.
function CrateOpening._unfold(self, gen: number): boolean
	self._phase = "unfold"
	self:_write()
	self.ctx:sfx("card_flip")
	self:_tween(self._title, 0.15, { TextTransparency = 1 })
	self:_tween(self._subtitle, 0.15, { TextTransparency = 1 })
	self:_tween(self._art.flap, 0.15, { BackgroundTransparency = 1 })
	self:_tween(self._art.stroke, 0.15, { Transparency = 1 })
	for _, c in self._art.creases do
		self:_tween(c, 0.1, { BackgroundTransparency = 1 })
	end
	self:_tween(self._sheet, CrateOpening.UNFOLD_S, {
		Position = UDim2.fromOffset(self._cx, self._cy - self._h * 0.5),
		Size = UDim2.fromOffset(self._w, self._h),
	}, Enum.EasingStyle.Cubic)
	if not self:_sleep(gen, CrateOpening.UNFOLD_S) then
		return false
	end
	self._fold.Visible = false
	return true
end

function CrateOpening._write(self)
	if self._renown ~= nil then
		self._preview.ImageRectOffset, self._preview.ImageRectSize = Vector2.zero, Vector2.zero
		self._preview.ImageColor3 = DispatchArt.INK
		UITheme.set_image(self._preview, UITheme.icon("renown"))
		self._name.Text = string.format("%s Renown", UICtx.commas(self._renown))
		self._kind.Text = "YOUR ARMOURY IS FULL: PAID IN RENOWN"
		return
	end
	local it = Cosmetics.item(self._item)
	self._preview.ImageColor3 = UITheme.WHITE
	self:_show_item(it)
	self._name.Text = if it then it.name else "?"
	self._kind.Text = if it and it.kind == "flag" then "TO FLY BESIDE YOUR NAME" else "TO LAY ACROSS YOUR LAND"
end

--- The rarity comes down on the paper. A Mythic rules the paper's edge in its colour too.
function CrateOpening._stamp_down(self, gen: number): boolean
	self._phase = "stamp"
	local rar = self._rar
	local rid = if rar ~= nil then rar.id else "common"
	if not self:_sleep(gen, CrateOpening.STAMP_WAIT_S[rid] or 0.12) then
		return false
	end
	local col = if rar ~= nil then c3(rar.color) else Color3.fromRGB(230, 226, 214)
	self._stamp_text.Text = if rar ~= nil then string.upper(rar.name) else "PAID"
	self._stamp_text.TextColor3 = col
	self._stamp_edge.Color = col
	self._stamp.Visible = true
	self._stamp_scale.Scale = 1.7
	self:_tween(self._stamp_scale, CrateOpening.STAMP_S, { Scale = 1 }, Enum.EasingStyle.Quint)
	if not self:_sleep(gen, CrateOpening.STAMP_S) then
		return false
	end
	self.ctx:sfx("reveal_" .. rid, 0, 0)
	if rid == "legendary" then
		self._edge.Color = col
		self:_tween(self._edge, 0.4, { Thickness = 4 })
	elseif rid == "epic" then
		self._edge.Color = col
		self._edge.Thickness = 2
	end
	return self:_sleep(gen, 0.25)
end

function CrateOpening._show_item(self, it: any)
	local img = self._preview
	if self.show_item ~= nil then
		-- (the Locker's: Patterns from the uploaded previews, Standards drawn)
		self.show_item(img, it)
		return
	end
	img.ImageRectOffset = Vector2.zero
	img.ImageRectSize = Vector2.zero
	img.Image = ""
	if it ~= nil and it.kind == "flag" then
		UITheme.set_image(img, Cosmetics.flag_image(it))
	end
end

--- The buttons under the paper: FLY IT (unless it flies already, or it paid Renown) and FILE IT, which says how many more wait.
function CrateOpening.refresh_buttons(self)
	local info = if self.info_of then self.info_of() else (self._info or {})
	local it = Cosmetics.item(self._item)
	local flying = it ~= nil and info.wearing ~= nil and info.wearing(it.kind) == it.id
	self._wear_b:set_visible(it ~= nil and not flying)
	local more = tonumber(info.crates) or 0
	self._done_b:set_text(if more > 0 then string.format("FILE IT  ·  %d MORE", more) else "FILE IT")
	self:_layout()
end

-- ---------------------------------------------------------------------------------------------
-- Close
-- ---------------------------------------------------------------------------------------------

function CrateOpening.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	self._gen += 1
	self._phase = "off"
	self._row:set_visible(false)
	self._stamp.Visible = false
	self._fold.Visible = false
	self:_tween(self._dim, 0.18, { BackgroundTransparency = 1 })
	self:_tween(self._sheet, 0.14, { BackgroundTransparency = 1 })
	self:_tween(self._edge, 0.14, { Transparency = 1 })
	self:_tween(self._preview, 0.14, { ImageTransparency = 1 })
	for _, l in { self._title, self._subtitle, self._hint, self._line, self._name, self._kind } do
		self:_tween(l, 0.14, { TextTransparency = 1 })
	end
	local gen = self._gen
	task.delay(0.2, function()
		if gen == self._gen and not self.is_open then
			self:set_visible(false)
		end
	end)
	self.shown:Fire(false)
	self.closed:Fire(self._fail)
end

return CrateOpening
