--!nonstrict
-- The Banners: a sheet (UI/Sheet) from the title that leads with what you fly, and has three sections beside it.
--   your nation  your banner's colour under the Pattern you use, the Standard you fly, and the squares to change the colour
--               (UITheme.BANNERS, the setting "banner": it takes effect on your next war)
--   Patterns, Standards  every item (owned bright, the rest dimmed as a preview of what Spoils can bring); press an owned one
--               to use it, "None" for nothing. An exclusive Pattern (Cosmetics.exclusives) shows only to its owner, first.
--   Spoils      a sealed dispatch, what it holds, the player's own odds per rarity (Cosmetics.odds, shown before every
--               purchase: Roblox's paid random items rules), how many items they hold, and the button: the first
--               dispatch's price, then the usual one (Data/Products), breaking a seal while a bought one waits; under it a
--               satchel and a courier's load for less (_pack_saving). Every prompt goes through Cosmetics.may_buy: nothing is
--               sold where paid random items are restricted (Session.inventory.crates_allowed, PolicyService on the server)
--               nor once it could only pay Renown. A dispatch that is already bought can always be opened (where allowed).
--   reveal      after a seal breaks: UI/CrateOpening.
-- The purchase goes like the takeover's (Takeover.luau): Roblox's prompt, the server stores the crate
-- (server/Purchases), the client opens it (Session.open_crate), the server rolls it.
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local UICtx = require("./UICtx")
local HelpOverlay = require("./HelpOverlay")
local Signal = UITheme.core("Signal")

local IS_ROBLOX = typeof(game) == "Instance"
local function shared(name: string): any
	if IS_ROBLOX then
		return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data[name]) :: any
	end
	return (require :: any)("../../shared/Data/" .. name)
end
local Cosmetics = shared("Cosmetics")
local Products = shared("Products")
local Prices = require("./Prices")
local SkinPreviews: any = (function()
	local ok, m = pcall(function()
		if IS_ROBLOX then
			return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Assets.SkinPreviews)
		end
		return (require :: any)("../../shared/Assets/SkinPreviews")
	end)
	return if ok and type(m) == "table" then m else {}
end)()

local Locker = W.class(W.Control)

Locker.TABS = { { "Patterns", "skin" }, { "Standards", "flag" }, { "Spoils", "spoils" } }
Locker.SPOILS_TAB = 3
--- Wide and low, as a Pattern lies on the land; a Standard's is a little narrower.
Locker.SKIN_CARD = Vector2.new(140, 112)
Locker.FLAG_CARD = Vector2.new(128, 108)
--- The body, desktop: your nation's column, a gap and the sections.
Locker.NATION_W = 212
Locker.NATION_W_PHONE = 200
Locker.SECTIONS_W = 588
Locker.GAP = 18
--- The picture of your nation, how tall.
Locker.PLATE_H = 124
Locker.PLATE_H_PHONE = 62
Locker.BANNER_LABEL = "Your banner"
Locker.BANNER_NOTE = "Flies from your next war."
--- A banner's square (a full tap target on every device).
Locker.BANNER_PX = 44
Locker.BANNER_GAP = 4
Locker.BANNER_COLS = 4
--- The buttons' column in the Spoils section.
Locker.CRATE_W = 230
--- Before a banner is chosen, what you would fly: the default (Data/Banners.flown); your own colour after that (_refresh_banners).
Locker.PREVIEW_COLOR = UITheme.BANNERS[1]
--- The plate's ground: the map's plains and its shallows (MapSurface), and how your colour lies on land there (its fill alpha).
Locker.PLAINS = Color3.fromRGB(0xB9, 0xBD, 0x8C)
Locker.SHALLOWS = Color3.fromRGB(0x4F, 0x9F, 0xB4)
Locker.LAND_ALPHA = 150 / 255
Locker.PREVIEW_TILES = 24
Locker.CREDIT_WAIT_S = 30

local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local FONT_M = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)

-- A skin's preview: its pattern in your banner's colour over our plains, the way the map draws it
-- (MapSurface: fill alpha 150, secondary Cosmetics.SECONDARY_ALPHA, a darker edge). Cached per skin, for one colour
-- at a time: a new colour destroys the old images (phones can run out of EditableImage budget).
local previews: { [string]: any } = {}
local preview_color = Locker.PREVIEW_COLOR
local function set_preview_color(c: Color3)
	if c == preview_color then
		return
	end
	preview_color = c
	for _, img in previews do
		if img then
			img:Destroy()
		end
	end
	table.clear(previews)
end
local function skin_preview(skin: any): any
	local cached = previews[skin.id]
	if cached ~= nil then
		return cached or nil
	end
	if not IS_ROBLOX then
		return nil
	end
	-- (a skin with several colours shows twice the tiles: its pattern is larger, as in the atlas)
	local n = if skin.colors ~= nil then Locker.PREVIEW_TILES * 2 else Locker.PREVIEW_TILES
	local ok, img = pcall(function()
		return game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(n, n) })
	end)
	if not ok or img == nil then
		previews[skin.id] = false
		return nil
	end
	local mask, mw, mh = Cosmetics.mask(skin)
	local c = preview_color
	local r, g, b = c.R, c.G, c.B
	local sr, sg, sb = Cosmetics.secondary(skin, r, g, b)
	-- (MapSurface's plains)
	local tr, tg, tb = 0xB9 / 255, 0xBD / 255, 0x8C / 255
	local a1, a2 = 150 / 255, Cosmetics.SECONDARY_ALPHA / 255
	local buf = buffer.create(n * n * 4)
	for y = 0, n - 1 do
		for x = 0, n - 1 do
			local cr, cg, cb, a
			if x == 0 or y == 0 or x == n - 1 or y == n - 1 then
				cr, cg, cb, a = r * 0.875, g * 0.875, b * 0.875, 1
			else
				local mx = bit32.rshift(x, skin.scale or 0) % mw
				local my = bit32.rshift(y, skin.scale or 0) % mh
				local k = buffer.readu8(mask, my * mw + mx)
				local kr, kg, kb
				if skin.colors ~= nil and k ~= 0 then
					kr, kg, kb = Cosmetics.color(skin, k)
				end
				if kr ~= nil then
					cr, cg, cb, a = kr, kg :: number, kb :: number, Cosmetics.skin_alpha(skin) / 255
				elseif k ~= 0 and skin.colors == nil then
					cr, cg, cb, a = sr, sg, sb, a2
				else
					cr, cg, cb, a = r, g, b, a1
				end
			end
			local k = (y * n + x) * 4
			buffer.writeu8(buf, k, math.floor((tr * (1 - a) + cr * a) * 255 + 0.5))
			buffer.writeu8(buf, k + 1, math.floor((tg * (1 - a) + cg * a) * 255 + 0.5))
			buffer.writeu8(buf, k + 2, math.floor((tb * (1 - a) + cb * a) * 255 + 0.5))
			buffer.writeu8(buf, k + 3, 255)
		end
	end
	local wrote = pcall(function()
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(n, n), buf)
	end)
	previews[skin.id] = if wrote then img else false
	return if wrote then img else nil
end

--- Show item `it` in ImageLabel `img` (a skin's preview or a flag from its atlas).
local function show_item(img: ImageLabel, it: any)
	img.ImageRectOffset = Vector2.zero
	img.ImageRectSize = Vector2.zero
	img.ImageContent = Content.none
	img.Image = ""
	if it == nil then
		return
	end
	if it.kind == "flag" then
		img.ResampleMode = Enum.ResamplerMode.Default
		UITheme.set_image(img, Cosmetics.flag_image(it))
		img.ImageRectOffset = Vector2.new(it.x, it.y)
		img.ImageRectSize = Vector2.new(it.w, it.h)
	else
		img.ResampleMode = Enum.ResamplerMode.Pixelated
		-- the uploaded atlas (Assets/SkinPreviews); a runtime EditableImage only without it (phones can
		-- run out of EditableImage budget: an Epic reveal card came out empty live, 2026-09-29)
		local cell = SkinPreviews.cells and SkinPreviews.cells[it.id]
		if cell ~= nil and SkinPreviews.image then
			img.Image = SkinPreviews.image
			img.ImageRectOffset = Vector2.new(cell[1], cell[2])
			img.ImageRectSize = Vector2.new(cell[3], cell[4])
			return
		end
		local ed = skin_preview(it)
		if ed ~= nil then
			img.ImageContent = Content.fromObject(ed)
		end
	end
end
Locker.show_item = show_item

function Locker.new(c: any)
	local self = setmetatable({}, Locker.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	-- (Roblox's price of the crate arrives a moment after the first look: UI/Prices)
	self:_connect(Prices.changed:Connect(function()
		if self.is_open then
			self:_refresh_crate()
		end
	end))
	self._tab = 1
	self._pending = nil
	self._cards = {}
	local v = Sheet.attach(self, "BANNERS", {
		outside = function()
			return not (self.opening ~= nil and self.opening.is_open)
		end,
	})
	self._v = v
	-- body: your nation | the sections
	local body = UITheme.hbox(Locker.GAP)
	body.size_flags_vertical = W.EXPAND_FILL
	self._body = body
	v:add_child(body)
	self:_build_nation(body)
	local right = UITheme.vbox(10)
	right.size_flags_horizontal = W.EXPAND_FILL
	self._right = right
	body:add_child(right)
	local tabs = UITheme.hbox(6)
	self._tabs = {}
	for i, t in ipairs(Locker.TABS) do
		local chip = UITheme.button(t[1], "ChipButton", "", 32.0)
		chip.toggle_mode = true
		chip:set_font_size(12)
		chip:set_pressed_no_signal(i == self._tab)
		chip.pressed:Connect(function()
			self:_show_tab(i)
		end)
		table.insert(self._tabs, chip)
		tabs:add_child(chip)
	end
	right:add_child(tabs)
	local host = W.Control.new()
	host:set_mouse_filter(W.MOUSE_PASS)
	host.size_flags_vertical = W.EXPAND_FILL
	self._host = host
	right:add_child(host)
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "LockerGrid"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Size = UDim2.fromScale(1, 1)
	sf.ScrollBarThickness = 6
	sf.ScrollBarImageColor3 = UITheme.WHITE
	sf.ScrollBarImageTransparency = 0.6
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.ZIndex = 40
	sf.Parent = host.gui
	host:_part(sf, "ScrollBarImageTransparency", 0.4)
	self._sf = sf
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = sf
	self._grid = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingLeft = UDim.new(0, 2)
	-- (room for the scroll bar: a card at a row's end ran 2 px under it; 2026-11-08 scan)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = sf
	self:_build_crate(right)
	-- Roblox: the purchase prompt (the session's signals: bind, once UIRoot has one)
	if IS_ROBLOX then
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(_u, product_id, purchased)
			self:_on_prompt_done(product_id, purchased)
		end)
	end
	return self
end

--- The session's inventory, credits and crate answers (UIRoot.setup, when the session exists).
function Locker.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	if s.inventory_changed then
		s.inventory_changed:Connect(function()
			self:_on_inventory()
		end)
	end
	if s.credits_changed then
		s.credits_changed:Connect(function()
			self:_on_credits()
		end)
	end
	if s.crate_result then
		s.crate_result:Connect(function(ok, res, renown)
			self:_on_result(ok, res, renown)
		end)
	end
	if s.cosmetic_result then
		s.cosmetic_result:Connect(function(id: string, ok: boolean, reason: string?)
			local it = Cosmetics.item(id)
			if ok and it ~= nil then
				self.ctx:sfx("unlock", -6.0)
				self:_toast(string.format("%s is yours, and flies now.", it.name))
			elseif not ok then
				self:_toast(
					if reason == "not enough" then "Still short of Renown."
						elseif reason == "owned" then "It's already yours."
						else "That didn't work, and nothing was spent. Try again soon."
				)
			end
			if self.is_open then
				self:_rebuild()
			end
		end)
	end
end

-- ---------------------------------------------------------------------------------------------
-- The Spoils section
-- ---------------------------------------------------------------------------------------------

function Locker._build_crate(self, parent: any)
	-- (it scrolls inside the sheet, so a short phone still reaches every price)
	local scroll = HelpOverlay.Scroll.new()
	scroll.size_flags_vertical = W.EXPAND_FILL
	self._crate_scroll = scroll
	parent:add_child(scroll)
	local body = UITheme.hbox(16)
	body.size_flags_horizontal = W.EXPAND_FILL
	self._crate = body
	scroll:add_child(body)
	-- the dispatch and the ways to get one
	local v = UITheme.vbox(8)
	self._crate_v = v
	v.size_flags_vertical = W.SHRINK_BEGIN
	body:add_child(v)
	local top = UITheme.hbox(10)
	self._art = UITheme.icon_rect("dispatch", 40.0, UITheme.TEXT)
	self._art:set_mouse_filter(W.MOUSE_IGNORE)
	self._art.size_flags_vertical = W.SHRINK_CENTER
	top:add_child(self._art)
	local words = UITheme.vbox(0)
	words.size_flags_vertical = W.SHRINK_CENTER
	self._crate_title = UITheme.label("SPOILS", 16, 800, UITheme.TEXT, 2)
	words:add_child(self._crate_title)
	self._count = UITheme.label("", 12, 600, UITheme.TEXT_2)
	words:add_child(self._count)
	top:add_child(words)
	v:add_child(top)
	self._crate_sub = UITheme.label("Each one carries something new for your banner.", 12, 500, UITheme.TEXT_2)
	self._crate_sub:set_autowrap(true)
	self._crate_sub:set_min_size(Vector2.new(Locker.CRATE_W, 0))
	v:add_child(self._crate_sub)
	self._buy = UITheme.button("", "PrimaryButton", "robux", 48.0)
	self._buy:set_min_size(Vector2.new(Locker.CRATE_W, 48))
	self._buy.pressed:Connect(function()
		self:_buy_pressed()
	end)
	v:add_child(self._buy)
	-- a satchel, for less than its dispatches one by one
	self._buy3 = UITheme.button("", "GlassButton", "robux", 42.0)
	self._buy3:set_min_size(Vector2.new(Locker.CRATE_W, 42))
	self._buy3:set_font_size(13)
	self._buy3:set_visible(false)
	self._buy3.pressed:Connect(function()
		self:_buy_pressed(Products.crate_satchel)
	end)
	v:add_child(self._buy3)
	-- and a courier's load
	self._buy10 = UITheme.button("", "GlassButton", "robux", 42.0)
	self._buy10:set_min_size(Vector2.new(Locker.CRATE_W, 42))
	self._buy10:set_font_size(13)
	self._buy10:set_visible(false)
	self._buy10.pressed:Connect(function()
		self:_buy_pressed(Products.crate_courier)
	end)
	v:add_child(self._buy10)
	self._note = UITheme.label("", 12, 500, UITheme.TEXT_3)
	self._note:set_autowrap(true)
	self._note:set_min_size(Vector2.new(Locker.CRATE_W, 0))
	v:add_child(self._note)
	-- the odds (the player's own; shown before any purchase)
	local side = UITheme.vbox(6)
	side.size_flags_horizontal = W.EXPAND_FILL
	side.size_flags_vertical = W.SHRINK_BEGIN
	body:add_child(side)
	self._odds_side = side
	local odds = UITheme.vbox(3)
	self._odds_box = odds
	self._odds = {}
	self._odds_labels = {}
	for _, r in Cosmetics.RARITIES do
		local row = UITheme.hbox(8)
		local sw = UITheme.swatch(UITheme.rarity_color(r), 10.0, UITheme.R_SM)
		sw.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(sw)
		local name = UITheme.label(r.name, 12, 600, UITheme.TEXT)
		name.size_flags_horizontal = W.EXPAND_FILL
		row:add_child(name)
		local pct = UITheme.label("", 12, 700, UITheme.TEXT)
		row:add_child(pct)
		self._odds[r.id] = pct
		table.insert(self._odds_labels, name)
		table.insert(self._odds_labels, pct)
		odds:add_child(row)
	end
	side:add_child(odds)
	-- every item's own odds (the rows above are per rarity: the policy wants each outcome, and a word on
	-- the control)
	self._details = UITheme.button("DETAILS", "GlassButton", "", 32.0)
	self._details:set_font_size(12)
	self._details.pressed:Connect(function()
		if self.odds_view ~= nil then
			self.odds_view:open(self:_inv().owned)
		end
	end)
	side:add_child(self._details)
end

-- ---------------------------------------------------------------------------------------------
-- Your nation
-- ---------------------------------------------------------------------------------------------

--- The column that leads the sheet: your banner's colour under your Pattern, your Standard on it, and the colour squares.
--- The chosen square has a ring set clear of it, so it reads on the near-white banner and on the accent's own colour.
function Locker._build_nation(self, parent: any)
	local col = UITheme.vbox(8)
	col.size_flags_vertical = W.SHRINK_BEGIN
	self._nation = col
	parent:add_child(col)
	local plate = W.Control.new()
	plate:set_mouse_filter(W.MOUSE_IGNORE)
	self._plate = plate
	col:add_child(plate)
	-- a corner of the map, in plain frames (no EditableImage, which a phone can run out of): the plains, a coast of shallows,
	-- and your land on them, its colour over the terrain and its border as the map draws them
	local terrain = Instance.new("Frame")
	terrain.Name = "Terrain"
	terrain.BackgroundColor3 = Locker.PLAINS
	terrain.BorderSizePixel = 0
	terrain.Size = UDim2.fromScale(1, 1)
	terrain.ZIndex = 40
	terrain.Parent = plate.gui
	plate:_part(terrain, "BackgroundTransparency", 1.0)
	self._plate_terrain = terrain
	local sea = Instance.new("Frame")
	sea.Name = "Sea"
	sea.BackgroundColor3 = Locker.SHALLOWS
	sea.BorderSizePixel = 0
	sea.AnchorPoint = Vector2.new(1, 0)
	sea.Position = UDim2.fromScale(1, 0)
	sea.Size = UDim2.fromScale(0.14, 1)
	sea.ZIndex = 41
	sea.Parent = plate.gui
	plate:_part(sea, "BackgroundTransparency", 1.0)
	-- your land: the Pattern's picture lies on it when you wear one (it holds the terrain and the colour already)
	local ground = Instance.new("ImageLabel")
	ground.Name = "Ground"
	ground.BackgroundColor3 = Locker.PREVIEW_COLOR
	ground.BorderSizePixel = 0
	ground.AnchorPoint = Vector2.new(0, 1)
	-- (its border is drawn outside it: held in by that much, the plate's edge stays clean)
	ground.Position = UDim2.new(0, 2, 1, -2)
	ground.Size = UDim2.new(0.74, -2, 0.84, -2)
	ground.ScaleType = Enum.ScaleType.Crop
	ground.ZIndex = 42
	ground.Parent = plate.gui
	plate:_part(ground, "BackgroundTransparency", Locker.LAND_ALPHA)
	plate:_part(ground, "ImageTransparency", 1.0)
	self._plate_ground = ground
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Thickness = 2
	edge.Color = Locker.PREVIEW_COLOR
	edge.Parent = ground
	-- (it fades with the screen: left out, the border stayed drawn over the title after the Banners closed)
	plate:_part(edge, "Transparency", 1.0)
	self._plate_edge = edge
	local flag = Instance.new("ImageLabel")
	flag.Name = "Flown"
	flag.BackgroundTransparency = 1
	flag.AnchorPoint = Vector2.new(0, 1)
	flag.Position = UDim2.new(0, 6, 1, -6)
	flag.Size = UDim2.fromOffset(54, 36)
	flag.ZIndex = 43
	flag.Parent = plate.gui
	plate:_part(flag, "ImageTransparency", 1.0)
	self._plate_flag = flag
	local words = UITheme.vbox(0)
	words:add_child(UITheme.label(Locker.BANNER_LABEL, 13, 800, UITheme.TEXT))
	words:add_child(UITheme.label(Locker.BANNER_NOTE, 12, 500, UITheme.TEXT_2))
	self._banner_words = words
	col:add_child(words)
	local squares = HelpOverlay.Grid.new(Locker.BANNER_COLS, Locker.BANNER_GAP, Locker.BANNER_GAP)
	self._banner_row = squares
	self._banners = {}
	for i, c in UITheme.BANNERS do
		local b = W.Button.new("", "GhostButton")
		b.name = "Banner" .. i
		b:set_min_size(Vector2.new(Locker.BANNER_PX, Locker.BANNER_PX))
		local sw = W.Panel.new()
		sw:set_mouse_filter(W.MOUSE_IGNORE)
		sw:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
		sw:set_offsets(6, 6, -6, -6)
		sw:add_theme_stylebox_override("panel", UITheme.flat(c, UITheme.R_SM))
		b:add_child(sw)
		b.pressed:Connect(function()
			self:_pick_banner(i)
		end)
		table.insert(self._banners, b)
		squares:add_child(b)
	end
	col:add_child(squares)
end

--- The saved banner (an index into UITheme.BANNERS), or nil while the player hasn't chosen one.
function Locker.banner_index(self): number?
	local i = tonumber(self.ctx:setting("banner", nil))
	return if i ~= nil and UITheme.BANNERS[i] ~= nil then i else nil
end

function Locker._pick_banner(self, i: number)
	self.ctx:set_setting("banner", i)
	self:_refresh_banners()
	if self.is_open and Locker.TABS[self._tab][2] == "skin" then
		self:_rebuild()
	end
end

function Locker._refresh_banners(self)
	local chosen = self:banner_index()
	for i, b in self._banners do
		local ring = if i == chosen then UITheme.TEXT else UITheme.CLEAR
		local bw = if i == chosen then 2 else 0
		b:add_theme_stylebox_override("normal", UITheme.flat(UITheme.CLEAR, UITheme.R_MD, ring, bw))
		b:add_theme_stylebox_override("hover", UITheme.flat(UITheme.FILL, UITheme.R_MD, ring, bw))
		b:add_theme_stylebox_override("pressed", UITheme.flat(UITheme.FILL_2, UITheme.R_MD, ring, bw))
	end
	-- what is shown is what will fly: Patterns in this colour from now on
	set_preview_color(if chosen ~= nil then UITheme.BANNERS[chosen] else Locker.PREVIEW_COLOR)
	self:_refresh_plate()
end

--- The picture of your nation: the colour, the Pattern over it and the Standard on it, as they are now.
function Locker._refresh_plate(self)
	local ground, flag = self._plate_ground, self._plate_flag
	ground.BackgroundColor3 = preview_color
	self._plate_edge.Color = preview_color:Lerp(UITheme.BLACK, 0.125)
	show_item(ground, Cosmetics.item(self:_equipped("skin")))
	local standard = Cosmetics.item(self:_equipped("flag"))
	flag.Visible = standard ~= nil
	show_item(flag, standard)
end

--- A section: Patterns, Standards, or the Spoils.
--- Spoils show only while there is something to do there: a dispatch to break, or one for sale here (no product yet:
--- no tab, no odds, no grey button that does nothing; release audit 2026-11-07).
function Locker.spoils_offered(self): boolean
	if self:_crates() > 0 then
		return true
	end
	local p = self:_product()
	return p ~= nil and p.id ~= 0
end

function Locker._show_tab(self, i: number)
	local offered = self:spoils_offered()
	local spoils_chip = self._tabs[Locker.SPOILS_TAB]
	if spoils_chip ~= nil then
		spoils_chip:set_visible(offered)
	end
	if i == Locker.SPOILS_TAB and not offered then
		i = 1
	end
	self._tab = i
	for j, ch in ipairs(self._tabs) do
		ch:set_pressed_no_signal(j == i)
	end
	local spoils = Locker.TABS[i][2] == "spoils"
	self._host:set_visible(not spoils)
	self._crate_scroll:set_visible(spoils)
	if spoils then
		self:_refresh_crate()
	end
	self:_rebuild()
end

function Locker._inv(self): any
	local s = self.ctx.session
	return if s ~= nil and s.inventory ~= nil
		then s.inventory
		else { owned = {}, equipped = {}, crates_bought = 0, crates_allowed = false }
end

function Locker._crates(self): number
	local s = self.ctx.session
	local c = if s ~= nil then s.credits else nil
	return if type(c) == "table" then (tonumber(c.crate) or 0) else 0
end

--- The crate product to sell now: the first crate's price until one was bought.
function Locker._product(self): any
	local inv = self:_inv()
	if (inv.crates_bought or 0) <= 0 and Products.crate_first and Products.crate_first.id ~= 0 then
		return Products.crate_first
	end
	return Products.crate
end

--- Its price in Robux: Roblox's for this player (UI/Prices).
function Locker._price(self): number
	return Prices.robux(if self:_product() == Products.crate_first then "crate_first" else "crate")
end

--- A pack's (`key`: "crate_satchel", "crate_courier") Robux saved against its dispatches one by one at Roblox's price for
--- this player; nil when it isn't offered: not created here, not cheaper (each price moves on its own), or may_buy says
--- there wouldn't be enough left to find.
function Locker._pack_saving(self, key: string): number?
	local p = Products[key]
	if p == nil or p.id == 0 then
		return nil
	end
	local n = math.max(1, tonumber(p.count) or 1)
	local save = n * Prices.robux("crate") - Prices.robux(key)
	if save <= 0 or not Cosmetics.may_buy(self:_inv().owned, self:_crates(), n, self:_inv().crates_allowed) then
		return nil
	end
	return save
end

function Locker._refresh_crate(self)
	local inv = self:_inv()
	local total = #Cosmetics.all()
	local owned = Cosmetics.crate_owned(inv.owned)
	self._count:set_text(string.format("%d of %d claimed", owned, total))
	for _, e in Cosmetics.odds(inv.owned) do
		local l = self._odds[e.rarity.id]
		if l then
			l:set_text(if e.left > 0 then (Cosmetics.odds_text(e.odds)) else "all yours")
		end
	end
	local all_owned = owned >= total
	local waiting = self:_crates()
	local busy = self._pending ~= nil
	local prod = self:_product()
	local allowed = inv.crates_allowed == true
	local sellable = Cosmetics.may_buy(inv.owned, waiting, 1, allowed)
	-- (a dispatch already bought can always be opened, even with nothing left to find: it pays Renown)
	self._buy:set_visible((allowed and (waiting > 0 or sellable)) or (not allowed and waiting > 0))
	self._odds_box:set_visible(allowed and not all_owned)
	self._details:set_visible(allowed and not all_owned)
	-- (no product yet and nothing waiting: a price here would be a button that does nothing)
	local for_sale = waiting > 0 or (prod ~= nil and prod.id ~= 0)
	self._buy:set_disabled(busy or not for_sale)
	local packs = allowed and not busy and waiting <= 0
	local save = if packs then self:_pack_saving("crate_satchel") else nil
	local save_big = if packs then self:_pack_saving("crate_courier") else nil
	self._buy3:set_visible(save ~= nil)
	if save ~= nil then
		self._buy3:set_text(string.format("A SATCHEL OF %d  ·  %d", Products.crate_satchel.count, Prices.robux("crate_satchel")))
	end
	self._buy10:set_visible(save_big ~= nil)
	if save_big ~= nil then
		self._buy10:set_text(string.format("A COURIER'S %d  ·  %d", Products.crate_courier.count, Prices.robux("crate_courier")))
	end
	if not allowed and waiting > 0 then
		self._buy:set_disabled(busy)
		self._buy:set_icon("renown")
		self._buy:set_text(string.format("TAKE AS RENOWN  ·  %s", UICtx.commas(Products.crate.robux * UICtx.data("Shop").RENOWN_PER_ROBUX)))
	elseif busy then
		self._buy:set_icon("")
		self._buy:set_text("UNSEALING…")
	elseif waiting > 0 then
		self._buy:set_icon("dispatch")
		self._buy:set_text(if waiting > 1 then string.format("BREAK A SEAL  ·  %d LEFT", waiting) else "BREAK THE SEAL")
	else
		self._buy:set_icon(if for_sale then "robux" else "")
		self._buy:set_text(if for_sale then string.format("ONE DISPATCH  ·  %d", self:_price()) else "SOON")
	end
	if not allowed then
		self._note:set_text(
			if waiting > 0
				then "Spoils aren't open to this account (its region, age or device). Each one you hold can be taken as Renown."
				else "Spoils aren't open to this account (its region, age or device). Nothing you hold is lost."
		)
	elseif all_owned then
		self._note:set_text(
			if waiting > 0
				then string.format("Your armoury is full: each dispatch left pays %s Renown.", UICtx.commas(Cosmetics.SPOILS_RENOWN))
				else "Your armoury is full."
		)
	elseif not sellable and waiting > 0 then
		self._note:set_text("Break the seals you have: nothing is left to find after them.")
	elseif waiting <= 0 and prod == Products.crate_first then
		self._note:set_text(string.format("The first rides for %d, the rest for %d.", self:_price(), Prices.robux("crate")))
	elseif save_big ~= nil or save ~= nil then
		local key = if save_big ~= nil then Products.crate_courier else Products.crate_satchel
		self._note:set_text(string.format("%d together cost %d less.", key.count, save_big or save))
	else
		self._note:set_text("Never what you already hold.")
	end
end

-- ---------------------------------------------------------------------------------------------
-- Buying and opening
-- ---------------------------------------------------------------------------------------------

--- A short notice (UIRoot sets this to its toasts).
function Locker._toast(_self, _text: string) end

function Locker._report(self, kind: string)
	local s = self.ctx.session
	if s ~= nil and type(s.report) == "function" then
		s:report(kind)
	end
end

--- `pack`: a pack's button (Products.crate_satchel, crate_courier); otherwise the main button (or the next one). The only
--- prompt for Spoils in the game: it asks Cosmetics.may_buy first.
function Locker._buy_pressed(self, pack: any?)
	local inv = self:_inv()
	if self._pending ~= nil then
		return
	end
	if inv.crates_allowed ~= true then
		-- (Spoils barred here: a dispatch held is taken as Renown by the server, no show of a roll)
		local s = self.ctx.session
		if self:_crates() > 0 and s ~= nil and s:open_crate() then
			self._pending = { phase = "opening", since = os.clock(), plain = true }
			self:_refresh_crate()
		end
		return
	end
	self:_report("crate_click")
	if self:_crates() > 0 then
		self:_open()
		return
	end
	local prod = pack or self:_product()
	if prod == nil or prod.id == 0 or not IS_ROBLOX then
		return
	end
	if not Cosmetics.may_buy(inv.owned, self:_crates(), tonumber(prod.count) or 1, inv.crates_allowed) then
		return
	end
	self._pending = { phase = "prompt", product = prod.id, since = os.clock() }
	self:_refresh_crate()
	local ok = pcall(function()
		game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, prod.id)
	end)
	if not ok then
		self:_cancel("Roblox isn't taking payment just now. Try again soon.")
	end
end

function Locker._open(self)
	self._pending = { phase = "opening", since = os.clock() }
	self:_refresh_crate()
	-- the show starts at once: the server's roll lands while the chest drops / shakes
	if self.opening ~= nil then
		self.opening:play(self:_offer())
	end
	local s = self.ctx.session
	if s == nil or not s:open_crate() then
		if self.opening ~= nil then
			self.opening:fail("The server didn't answer. Try again soon.")
		end
		self:_cancel("The server didn't answer. Try again soon.")
	end
end

--- What the opening show needs to know: how many more wait, and what the player uses.
function Locker._offer(self): any
	return {
		crates = self:_crates(),
		wearing = function(slot: string): string?
			return self:_equipped(slot)
		end,
	}
end

--- The opening show (UIRoot makes it, above the Locker).
function Locker.set_opening(self, o: any)
	self.opening = o
	o.preview_of = skin_preview
	o.show_item = show_item
	o.info_of = function()
		return self:_offer()
	end
	o.wear:Connect(function(id: string)
		local it = Cosmetics.item(id)
		local se = self.ctx.session
		if it ~= nil and se ~= nil then
			self.ctx:sfx("click")
			se:equip(it.kind, it.id)
		end
	end)
	o.closed:Connect(function(fail_text: string?)
		if fail_text then
			self:_toast(fail_text)
		end
		if self.is_open then
			-- (more seals waiting: back where the next one breaks; else the section that shows what came)
			if self:_crates() > 0 then
				self._tab = Locker.SPOILS_TAB
			end
			self:_refresh_banners()
			self:_show_tab(self._tab)
		end
	end)
end

function Locker._cancel(self, message: string?)
	self._pending = nil
	if message then
		self:_toast(message)
	end
	self:_refresh_crate()
end

function Locker._on_prompt_done(self, product_id: number, purchased: boolean)
	local p = self._pending
	if p == nil or p.phase ~= "prompt" or product_id ~= p.product then
		return
	end
	if not purchased then
		self:_cancel(nil)
		return
	end
	-- bought: the server stores the crate and says so (credits); then it opens
	p.phase = "credit"
	p.since = os.clock()
	if self:_crates() > 0 then
		self:_open()
	end
end

function Locker._on_credits(self)
	local p = self._pending
	if p ~= nil and p.phase == "credit" and self:_crates() > 0 then
		self:_open()
	end
	if self.is_open then
		self:_show_tab(self._tab)
	end
end

function Locker._on_inventory(self)
	if self.is_open then
		self:_refresh_crate()
		self:_rebuild()
	end
	if self.opening ~= nil and self.opening.is_open then
		self.opening:refresh_buttons()
	end
end

function Locker._on_result(self, ok: boolean, res: string, renown: number?)
	local p = self._pending
	if p == nil or p.phase ~= "opening" then
		return
	end
	self._pending = nil
	self:_refresh_crate()
	local o = self.opening
	if p.plain then
		self:_toast(if ok then string.format("+%s Renown", UICtx.commas(renown or 0)) else "Not now. Your Spoils stay safe.")
		return
	end
	if ok and res == "renown" then
		if o ~= nil then
			o:resolve_renown(renown or Cosmetics.SPOILS_RENOWN)
		end
	elseif ok then
		local it = Cosmetics.item(res)
		if it ~= nil then
			-- the section behind shows the new item
			self._tab = if it.kind == "flag" then 2 else 1
		end
		if o ~= nil then
			o:resolve(res)
		end
	elseif o ~= nil then
		o:fail(
			if res == "not allowed" then "Spoils aren't open to this account (its region, age or device). Your Spoils stay safe."
				else "Those Spoils won't open right now. They're safe: try again."
		)
	end
end

--- Once a second while open: a purchase that never came back gives up (a crate bought stays saved).
function Locker.tick(self)
	local p = self._pending
	if p ~= nil then
		local limit = if p.phase == "prompt" then 180 else Locker.CREDIT_WAIT_S
		if os.clock() - p.since > limit then
			self:_cancel(if p.phase == "prompt" then nil else "The courier is late. Your Spoils will wait here for you.")
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- The grid
-- ---------------------------------------------------------------------------------------------

function Locker._equipped(self, slot: string): string?
	local inv = self:_inv()
	return inv.equipped and inv.equipped[slot] or nil
end

function Locker._card(self, it: any, order: number, slot: string): TextButton
	local s = UITheme.scale
	local inv = self:_inv()
	local owned = it == nil or inv.owned[it.id] == true
	local equipped = if it == nil then self:_equipped(slot) == nil else self:_equipped(slot) == it.id
	local rar = if it ~= nil then Cosmetics.rarity(it.rarity) else nil
	local b = Instance.new("TextButton")
	b.Name = if it then it.id else "none"
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = UITheme.WHITE
	b.BackgroundTransparency = 0.94
	b.LayoutOrder = order
	b.ZIndex = 41
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.floor(UITheme.R_MD * s))
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = if equipped then UITheme.color3(UITheme.to_rgba(UITheme.AMBER)) else UITheme.WHITE
	stroke.Transparency = if equipped then 0 else 0.88
	stroke.Thickness = if equipped then 2 else 1
	stroke.Parent = b
	local img = Instance.new("ImageLabel")
	img.Name = "Preview"
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	img.Position = UDim2.fromOffset(math.floor(10 * s), math.floor(10 * s))
	img.Size = UDim2.new(1, -math.floor(20 * s), 1, -math.floor(48 * s))
	img.ZIndex = 42
	img.Parent = b
	show_item(img, it)
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.FontFace = FONT
	name.TextSize = math.floor(12 * s)
	name.TextColor3 = UITheme.TEXT
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = if it then it.name else "None"
	name.Position = UDim2.new(0, math.floor(8 * s), 1, -math.floor(36 * s))
	name.Size = UDim2.new(1, -math.floor(16 * s), 0, math.floor(16 * s))
	name.ZIndex = 42
	name.Parent = b
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.FontFace = FONT_M
	sub.TextSize = math.floor(12 * s)
	sub.TextColor3 = if equipped
		then UITheme.color3(UITheme.to_rgba(UITheme.AMBER))
		elseif rar and owned then UITheme.rarity_color(rar)
		else UITheme.TEXT_3
	-- (a country's Standard Renown can buy: its price, and on a first press the ask to confirm)
	local renown = if not owned and it ~= nil then Cosmetics.renown_price(it) else nil
	-- (where a locked one comes from, when the Spoils are on sale: every Pattern and rarer Standard rides in them)
	local spoils_route = it ~= nil and not it.exclusive and not it.general and not it.shop and self:spoils_offered()
	local asking = renown ~= nil and self._confirm_id == it.id
	if renown ~= nil then
		sub.TextColor3 = if asking then UITheme.color3(UITheme.to_rgba(UITheme.AMBER)) else UITheme.GOLD
	end
	sub.Text = if equipped then "IN USE"
		elseif asking then "PRESS AGAIN: IT'S YOURS"
		elseif renown ~= nil then UICtx.commas(renown) .. " RENOWN"
		elseif not owned and spoils_route then "FROM SPOILS"
		elseif not owned then "LOCKED"
		elseif rar then string.upper(rar.name)
		else ""
	sub.Position = UDim2.new(0, math.floor(8 * s), 1, -math.floor(20 * s))
	sub.Size = UDim2.new(1, -math.floor(16 * s), 0, math.floor(16 * s))
	sub.ZIndex = 42
	sub.Parent = b
	local host = self._host
	host:_part(b, "BackgroundTransparency", 0.06)
	host:_part(stroke, "Transparency", 1 - stroke.Transparency)
	host:_part(img, "ImageTransparency", if owned or renown ~= nil then 1.0 else 0.3)
	host:_part(name, "TextTransparency", if owned or renown ~= nil then 1.0 else 0.45)
	host:_part(sub, "TextTransparency", 1.0)
	b.MouseEnter:Connect(function()
		host:_part(b, "BackgroundTransparency", 0.12)
	end)
	b.MouseLeave:Connect(function()
		host:_part(b, "BackgroundTransparency", 0.06)
	end)
	b.Activated:Connect(function()
		if not owned and renown ~= nil then
			local se = self.ctx.session
			local inv = if se ~= nil then se.inventory else nil
			-- (the balance first, before any confirm: a loading record is said to be loading, never 6,000 short)
			if inv == nil or inv.loaded ~= true then
				self.ctx:sfx("deny", -6.0)
				self:_toast("Your Renown is still loading. Try again in a moment.")
			elseif (inv.stars or 0) < renown then
				self.ctx:sfx("deny", -6.0)
				self._confirm_id = nil
				self:_toast(string.format("%s Renown more needed", UICtx.commas(renown - (inv.stars or 0))))
			elseif not asking then
				self.ctx:sfx("click")
				self._confirm_id = it.id
				self:_rebuild()
			elseif se ~= nil and se:buy_cosmetic(it.id) then
				self.ctx:sfx("click")
				self._confirm_id = nil
			end
			return
		end
		if not owned then
			self.ctx:sfx("deny", -6.0)
			return
		end
		local se = self.ctx.session
		if se ~= nil then
			self.ctx:sfx("click")
			se:equip(slot, if it then it.id else false)
		end
	end)
	b.Parent = self._sf
	return b
end

function Locker._rebuild(self)
	for _, b in self._cards do
		self._host:_drop_part(b)
		for _, d in b:GetDescendants() do
			self._host:_drop_part(d)
		end
		b:Destroy()
	end
	table.clear(self._cards)
	local s = UITheme.scale
	local slot = Locker.TABS[self._tab][2]
	if slot == "spoils" then
		return
	end
	local cell = if slot == "skin" then Locker.SKIN_CARD else Locker.FLAG_CARD
	if self.ctx.compact then
		cell *= 0.84
	end
	self._grid.CellSize = UDim2.fromOffset(math.floor(cell.X * s), math.floor(cell.Y * s))
	self._grid.CellPadding = UDim2.fromOffset(math.floor(8 * s), math.floor(8 * s))
	local inv = self:_inv()
	-- None first, then owned (by rarity, rarest first), then the rest
	local list = {}
	for _, it in Cosmetics.all() do
		if it.kind == slot then
			table.insert(list, it)
		end
	end
	-- (an exclusive only for whoever owns it: nobody else can get one; a shop flag once bought, the
	-- crate can't give one)
	for _, it in Cosmetics.exclusives() do
		if it.kind == slot and inv.owned[it.id] == true then
			table.insert(list, it)
		end
	end
	-- (a General skin once given: Data/Subscription)
	for _, it in Cosmetics.generals() do
		if it.kind == slot and inv.owned[it.id] == true then
			table.insert(list, it)
		end
	end
	for _, it in Cosmetics.shop_items() do
		if it.kind == slot and inv.owned[it.id] == true then
			table.insert(list, it)
		end
	end
	local rank = { exclusive = 0, general = 0, legendary = 1, epic = 2, rare = 3, common = 4 }
	table.sort(list, function(a, b)
		local oa, ob = inv.owned[a.id] == true, inv.owned[b.id] == true
		if oa ~= ob then
			return oa
		end
		local ra, rb = rank[a.rarity] or 9, rank[b.rarity] or 9
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	table.insert(self._cards, self:_card(nil, 0, slot))
	for i, it in list do
		table.insert(self._cards, self:_card(it, i, slot))
	end
end

-- ---------------------------------------------------------------------------------------------
-- Open / close / layout
-- ---------------------------------------------------------------------------------------------

function Locker.open(self)
	if self.is_open then
		return
	end
	self.is_open = true
	self:_report("crate_shop")
	Prices.fetch()
	-- (a sealed dispatch waiting: straight to it)
	if self:_crates() > 0 then
		self._tab = Locker.SPOILS_TAB
	end
	self:_refresh_banners()
	self:apply_layout()
	self:_show_tab(self._tab)
	Sheet.show(self)
end

function Locker.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function Locker.apply_layout(self)
	local ctx = self.ctx
	local compact = ctx.compact
	local nation_w = if compact then Locker.NATION_W_PHONE else Locker.NATION_W
	local m = Sheet.place(self, nation_w + Locker.GAP + Locker.SECTIONS_W)
	self._nation:set_min_size(Vector2.new(nation_w, 0))
	self._plate:set_min_size(Vector2.new(nation_w, if compact then Locker.PLATE_H_PHONE else Locker.PLATE_H))
	-- (phones: a lower plate and no words, so the squares stay in reach without a scroll)
	self._banner_words:set_visible(not compact)
	-- the Spoils: the buttons' column and the odds beside it
	local right_w = m.body_w - nation_w - Locker.GAP
	local cw = math.min(Locker.CRATE_W, math.floor(right_w * 0.56))
	self._crate_sub:set_visible(not compact)
	self._odds_box:set_separation(if compact then 1 else 3)
	self._crate_title:set_font_size(if compact then 14 else 16)
	self._crate_sub:set_min_size(Vector2.new(cw, 0))
	self._note:set_min_size(Vector2.new(cw, 0))
	self._buy:set_min_size(Vector2.new(cw, if compact then 40 else 48))
	self._buy3:set_min_size(Vector2.new(cw, if compact then 34 else 42))
	self._buy10:set_min_size(Vector2.new(cw, if compact then 34 else 42))
	self._buy3:set_font_size(if compact then 12 else 13)
	self._buy10:set_font_size(if compact then 12 else 13)
	self._crate_v:set_separation(if compact then 5 else 8)
	if self.is_open then
		self:_refresh_crate()
		self:_rebuild()
	end
end

return Locker
