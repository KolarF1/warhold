--!nonstrict
-- The Standards (Data/Shop): a sheet (UI/Sheet) from the title's row, the whole armoury under its four ages. Nothing turns
-- over and nothing has a clock. Each age: its name and line, its bundle (all of it for one price, what that saves, Standards
-- already owned paying back Renown), and its cards. Each card is a wide row: the Standard and its rarity on the left, its
-- name and button on the right: the price (Roblox's for this player: UI/Prices), RAISE for one owned, FLYING for the one
-- that flies. A purchase goes like the Banners': Roblox's prompt, the server stores it and flies it (server/Purchases),
-- the card turns to FLYING.
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local Prices = require("./Prices")
local Signal = UITheme.core("Signal")

local IS_ROBLOX = typeof(game) == "Instance"
local function shared(name: string): any
	if IS_ROBLOX then
		return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data[name]) :: any
	end
	return (require :: any)("../../shared/Data/" .. name)
end
local Shop = shared("Shop")
local Cosmetics = shared("Cosmetics")
local Products = shared("Products")

local FlagShop = W.class(W.Control)

--- A card's width, logical px (phones: CARD_W_PHONE); its height follows its button (_card_size).
FlagShop.CARD_W = 300
FlagShop.CARD_W_PHONE = 236
FlagShop.GAP = 10
--- Cards in a row on desktop (the sheet is as wide as that), and at most on phones.
FlagShop.COLS = 2
FlagShop.COLS_PHONE = 3
--- After a purchase, how long the card waits for the server's word before saying it's on its way.
FlagShop.GRANT_WAIT_S = 30
--- The bundle banner's height (logical px).
FlagShop.BANNER_H = 46

local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local FONT_H = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FONT_M = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
local ROBUX = "rbxasset://textures/ui/common/robux@3x.png"

--- A theme colour as a plain Color3 (the accent is read when a card is built: UITheme.set_accent).
local function col(c: any): Color3
	return UITheme.color3(c)
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

--- The shop has something to sell here: a flag whose product exists (Studio: always).
function FlagShop.on_sale(): boolean
	-- (Studio shows it to test; workspace attribute CTW_LIVE_SHOP = true shows Studio what a live player sees)
	if IS_ROBLOX and game:GetService("RunService"):IsStudio() and workspace:GetAttribute("CTW_LIVE_SHOP") ~= true then
		return #Shop.flags() > 0
	end
	for _, f in Shop.flags() do
		local p = Products["shop_" .. f.key]
		if p ~= nil and p.id ~= 0 then
			return true
		end
	end
	return false
end

function FlagShop.new(c: any)
	local self = setmetatable({}, FlagShop.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	self._cards = {}
	self._pending = nil
	self:_connect(Prices.changed:Connect(function()
		if self.is_open then
			self:_rebuild()
		end
	end))
	local v, head = Sheet.attach(self, "STANDARDS")
	self._v = v
	self._sub = UITheme.label("Sold under the four ages, and always on sale", 13, 600, UITheme.TEXT_2)
	self._sub.size_flags_horizontal = W.EXPAND_FILL
	self._sub.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._sub)
	local host = W.Control.new()
	host:set_mouse_filter(W.MOUSE_PASS)
	host.size_flags_vertical = W.EXPAND_FILL
	self._host = host
	v:add_child(host)
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "FlagShopList"
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Size = UDim2.fromScale(1, 1)
	sf.ScrollBarThickness = 6
	sf.ScrollBarImageColor3 = col(UITheme.TEXT)
	sf.ScrollBarImageTransparency = 0.6
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.ZIndex = 40
	sf.Parent = host.gui
	host:_part(sf, "ScrollBarImageTransparency", 0.4)
	self._sf = sf
	self._list = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }, sf)
	if IS_ROBLOX then
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(_u, product_id, purchased)
			self:_on_prompt_done(product_id, purchased)
		end)
	end
	return self
end

--- The session's inventory (UIRoot.setup, when the session exists).
function FlagShop.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	if s.inventory_changed then
		s.inventory_changed:Connect(function()
			self:_on_inventory()
		end)
	end
end

--- A short notice (UIRoot sets this to its toasts).
function FlagShop._toast(_self, _text: string) end

function FlagShop._report(self, a: string, b: any?)
	local s = self.ctx.session
	if s ~= nil and type(s.report) == "function" then
		s:report("flag_shop", a, b)
	end
end

function FlagShop._inv(self): any
	local s = self.ctx.session
	return if s ~= nil and s.inventory ~= nil then s.inventory else { owned = {}, equipped = {} }
end

-- ---------------------------------------------------------------------------------------------
-- Buying and wearing
-- ---------------------------------------------------------------------------------------------

function FlagShop._pressed(self, key: string)
	local id = Shop.item_id(key)
	local inv = self:_inv()
	local se = self.ctx.session
	if inv.owned[id] == true then
		if inv.equipped.flag ~= id and se ~= nil then
			self.ctx:sfx("click")
			se:equip("flag", id)
		end
		return
	end
	if self._pending ~= nil then
		return
	end
	local p = Products["shop_" .. key]
	if p == nil or p.id == 0 or not IS_ROBLOX then
		self.ctx:sfx("deny", -6.0)
		return
	end
	self:_report("clicked", key)
	self.ctx:sfx("click")
	self._pending = { key = key, product = p.id, phase = "prompt", since = os.clock() }
	self:_rebuild()
	local ok = pcall(function()
		game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, p.id)
	end)
	if not ok then
		self:_cancel("Roblox isn't taking payment just now. Try again soon.")
	end
end

--- A set's bundle (Products "shopset_<id>").
function FlagShop._pressed_set(self, sid: string)
	if self._pending ~= nil then
		return
	end
	local p = Products["shopset_" .. sid]
	if p == nil or p.id == 0 or not IS_ROBLOX then
		self.ctx:sfx("deny", -6.0)
		return
	end
	self:_report("clicked_pack", sid)
	self.ctx:sfx("click")
	self._pending = { set = sid, product = p.id, phase = "prompt", since = os.clock() }
	self:_rebuild()
	local ok = pcall(function()
		game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, p.id)
	end)
	if not ok then
		self:_cancel("Roblox isn't taking payment just now. Try again soon.")
	end
end

--- How many of set `sid`'s flags the player owns, of how many.
function FlagShop._set_owned(self, sid: string): (number, number)
	local inv = self:_inv()
	local keys = Shop.set_keys(sid)
	local n = 0
	for _, k in keys do
		if inv.owned[Shop.item_id(k)] == true then
			n += 1
		end
	end
	return n, #keys
end

function FlagShop._cancel(self, message: string?)
	self._pending = nil
	if message then
		self:_toast(message)
	end
	if self.is_open then
		self:_rebuild()
	end
end

function FlagShop._on_prompt_done(self, product_id: number, purchased: boolean)
	local p = self._pending
	if p == nil or p.phase ~= "prompt" or product_id ~= p.product then
		return
	end
	if not purchased then
		self:_cancel(nil)
		return
	end
	-- bought: the server stores the flag and says so (the inventory)
	p.phase = "grant"
	p.since = os.clock()
	self:_on_inventory()
end

function FlagShop._on_inventory(self)
	local p = self._pending
	if p ~= nil and p.phase == "grant" and p.set ~= nil then
		local n, of = self:_set_owned(p.set)
		if n >= of then
			self._pending = nil
			local set = Shop.SETS[p.set]
			self.ctx:sfx("confirm")
			self:_toast(string.format("The whole of the %s is yours: %d Standards.", if set then set.name else "age", of))
		end
	elseif p ~= nil and p.phase == "grant" and self:_inv().owned[Shop.item_id(p.key)] == true then
		self._pending = nil
		local f = Shop.flag(p.key)
		self.ctx:sfx("confirm")
		self:_toast((if f then f.name else "Your Standard") .. " is yours and flying now.")
	end
	if self.is_open then
		self:_rebuild()
	end
end

function FlagShop.tick(self)
	local p = self._pending
	if p ~= nil then
		local limit = if p.phase == "prompt" then 180 else FlagShop.GRANT_WAIT_S
		if os.clock() - p.since > limit then
			self:_cancel(if p.phase == "prompt" then nil else "Paid. Your Standard follows in a moment.")
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- The list
-- ---------------------------------------------------------------------------------------------

function FlagShop._card_size(self): Vector2
	-- (the words over a button tall enough to press)
	local compact = self.ctx.compact
	return Vector2.new(if compact then FlagShop.CARD_W_PHONE else FlagShop.CARD_W, 8 + 34 + 4 + self:_button_h() + 8)
end

function FlagShop._button_h(self): number
	return math.max(30, UITheme.touch_min)
end

--- An age's head: its name, and its line beside it.
function FlagShop._section(self, order: number, title: string, line: string)
	local s = UITheme.scale
	local row = new("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, -math.floor(12 * s), 0, math.floor(30 * s)),
		ZIndex = 41,
	}, self._sf)
	local t = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_H,
		Text = title,
		TextColor3 = col(UITheme.TEXT),
		TextSize = math.floor(15 * s),
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(0.3, 1),
		ZIndex = 42,
	}, row)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = line,
		TextColor3 = col(UITheme.TEXT_2),
		TextSize = math.floor(12 * s),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.7, 1),
		ZIndex = 42,
	}, row)
	self._host:_part(t, "TextTransparency", 1.0)
	self._host:_part(l, "TextTransparency", 1.0)
	table.insert(self._cards, row)
end

function FlagShop._grid(self, order: number, keys: { string })
	local s = UITheme.scale
	local cs = self:_card_size()
	local gap = FlagShop.GAP
	local cols = self._cols or FlagShop.COLS
	local rows = math.ceil(#keys / cols)
	local g = new("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, -math.floor(12 * s), 0, math.floor((rows * cs.Y + (rows - 1) * gap + 14) * s)),
		ZIndex = 41,
	}, self._sf)
	for i, key in keys do
		local x, y = (i - 1) % cols, (i - 1) // cols
		self:_card(g, key, Vector2.new(x * (cs.X + gap), y * (cs.Y + gap)), cs)
	end
	table.insert(self._cards, g)
end

--- An age's bundle under its head: all its Standards, what that saves at this player's prices, and its price.
--- Its banner shows: it has a bundle, its product exists here (Studio: always), and the
--- player is missing some of the set.
function FlagShop._bundle_shown(self, sid: string): boolean
	local set = Shop.SETS[sid]
	local p = Products["shopset_" .. sid]
	if set == nil or set.bundle == nil or p == nil then
		return false
	end
	if p.id == 0 and not (IS_ROBLOX and game:GetService("RunService"):IsStudio()) then
		return false
	end
	local have, of = self:_set_owned(sid)
	return have < of
end

function FlagShop._bundle(self, order: number, sid: string)
	if not self:_bundle_shown(sid) then
		return
	end
	local set = Shop.SETS[sid]
	local key = "shopset_" .. sid
	local have, of = self:_set_owned(sid)
	local s = UITheme.scale
	local px = function(v: number): number
		return math.floor(v * s + 0.5)
	end
	local each = 0
	for _, k in Shop.set_keys(sid) do
		each += Prices.robux("shop_" .. k)
	end
	local price = Prices.robux(key)
	-- (the saving against buying each one: the subline's "N% less"; it was read here undefined and broke the sheet the
	-- day the bundles first had ids)
	local off = if each > 0 then math.floor((1 - price / each) * 100 + 0.5) else 0
	local pending = self._pending ~= nil and self._pending.set == sid
	local h = math.max(FlagShop.BANNER_H, UITheme.touch_min + 14)
	local row = new("Frame", {
		Name = "Bundle",
		LayoutOrder = order,
		Size = UDim2.new(1, -px(12), 0, px(h + 10)),
		BackgroundTransparency = 1,
		ZIndex = 41,
	}, self._sf)
	local box = new("Frame", {
		Name = "Box",
		BackgroundColor3 = col(UITheme.GLASS_RAISED),
		Size = UDim2.new(1, 0, 0, px(h)),
		ZIndex = 41,
	}, row)
	new("UICorner", { CornerRadius = UDim.new(0, px(UITheme.R_MD)) }, box)
	local stroke = new("UIStroke", { Color = col(UITheme.LINE_2), Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
	local title = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_H,
		Text = string.format("THE WHOLE OF %s, %d", string.upper(set.name), of),
		TextColor3 = col(UITheme.TEXT),
		TextSize = px(14),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(px(14), px(6)),
		Size = UDim2.new(1, -px(150), 0, px(18)),
		ZIndex = 42,
	}, box)
	local sub = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = (if off > 0 then string.format("%d%% less", off) else "One price for all")
			.. (if have > 0 then "  ·  Renown back for those you hold" else ""),
		TextColor3 = col(UITheme.TEXT_2),
		TextSize = px(12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(px(14), px(25)),
		Size = UDim2.new(1, -px(150), 0, px(14)),
		ZIndex = 42,
	}, box)
	local btn = new("TextButton", {
		Name = "BuyAll",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = col(UITheme.AMBER),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -px(4), 0.5, 0),
		Size = UDim2.fromOffset(px(124), px(math.max(h - 8, UITheme.touch_min))),
		ZIndex = 43,
	}, box)
	new("UICorner", { CornerRadius = UDim.new(0, px(UITheme.R_MD)) }, btn)
	local inner = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 44 }, btn)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, px(4)),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, inner)
	local icon = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = ROBUX,
		ImageColor3 = col(UITheme.INK),
		Size = UDim2.fromOffset(px(15), px(15)),
		LayoutOrder = 1,
		Visible = not pending,
		ZIndex = 45,
	}, inner)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_H,
		Text = if pending then "..." else tostring(price),
		TextColor3 = col(UITheme.INK),
		TextSize = px(15),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, px(math.max(h - 8, UITheme.touch_min))),
		LayoutOrder = 2,
		ZIndex = 45,
	}, inner)
	local host = self._host
	host:_part(box, "BackgroundTransparency", 1.0)
	host:_part(stroke, "Transparency", UITheme.LINE_2.alpha)
	host:_part(title, "TextTransparency", 1.0)
	host:_part(sub, "TextTransparency", 1.0)
	host:_part(btn, "BackgroundTransparency", 1.0)
	host:_part(icon, "ImageTransparency", 1.0)
	host:_part(label, "TextTransparency", 1.0)
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = col(UITheme.AMBER_HI)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = col(UITheme.AMBER)
	end)
	btn.Activated:Connect(function()
		self:_pressed_set(sid)
	end)
	table.insert(self._cards, row)
end

function FlagShop._card(self, parent: Instance, key: string, pos: Vector2, size: Vector2)
	local f = Shop.flag(key)
	local it = Cosmetics.item(Shop.item_id(key))
	if f == nil or it == nil then
		return
	end
	local s = UITheme.scale
	local px = function(v: number): number
		return math.floor(v * s + 0.5)
	end
	local cs = size
	local inv = self:_inv()
	local owned = inv.owned[it.id] == true
	local wearing = inv.equipped.flag == it.id
	local pending = self._pending ~= nil and self._pending.key == key
	local rar = Cosmetics.rarity(f.rarity)
	local rc = UITheme.rarity_color(rar)
	local card = new("Frame", {
		Name = key,
		BackgroundColor3 = col(UITheme.GLASS_RAISED),
		Position = UDim2.fromOffset(px(pos.X), px(pos.Y)),
		Size = UDim2.fromOffset(px(size.X), px(size.Y)),
		ZIndex = 41,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, px(UITheme.R_MD)) }, card)
	local stroke = new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = if wearing then col(UITheme.AMBER) else rc,
		Thickness = if wearing then 2 else 1,
	}, card)
	-- the Standard on the left, its rarity under it
	local fh = cs.Y - 16 - 16
	local fw = math.floor(fh * 3 / 2)
	local img = new("ImageLabel", {
		Name = "Flag",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(px(8), px(8)),
		Size = UDim2.fromOffset(px(fw), px(fh)),
		ZIndex = 42,
	}, card)
	local image, x, y, w, h = Cosmetics.flag_big(it)
	UITheme.set_image(img, image)
	img.ImageRectOffset = Vector2.new(x, y)
	img.ImageRectSize = Vector2.new(w, h)
	new("UICorner", { CornerRadius = UDim.new(0, px(UITheme.R_SM)) }, img)
	local sub = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_M,
		Text = string.upper(rar.name),
		TextColor3 = rc,
		TextSize = px(12),
		Position = UDim2.fromOffset(px(8), px(8 + fh + 1)),
		Size = UDim2.fromOffset(px(fw), px(14)),
		ZIndex = 42,
	}, card)
	-- its name and its button on the right: the price, RAISE / FLYING, or a moment's wait
	local rx = 8 + fw + 8
	local rw = cs.X - rx - 8
	local name_size = if self.ctx.compact then 12 else 13
	local name = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = f.name,
		TextColor3 = col(UITheme.TEXT),
		TextSize = px(name_size),
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(px(rx), px(8)),
		Size = UDim2.fromOffset(px(rw), px(34)),
		ZIndex = 42,
	}, card)
	local bh = self:_button_h()
	local btn = new("TextButton", {
		Name = "Buy",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = if owned then col(UITheme.GLASS_SOLID) else col(UITheme.AMBER),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, px(rx), 1, -px(8)),
		Size = UDim2.fromOffset(px(rw), px(bh)),
		ZIndex = 43,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, px(UITheme.R_MD)) }, btn)
	local row = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 44,
	}, btn)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, px(4)),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local text = if wearing then "FLYING" elseif owned then "RAISE" elseif pending then "..." else nil
	local parts = { btn }
	if text == nil then
		local icon = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = ROBUX,
			ImageColor3 = col(UITheme.INK),
			Size = UDim2.fromOffset(px(15), px(15)),
			LayoutOrder = 1,
			ZIndex = 45,
		}, row)
		table.insert(parts, icon)
		text = tostring(Prices.robux("shop_" .. key))
	end
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_H,
		Text = text,
		TextColor3 = if wearing then col(UITheme.AMBER) elseif owned then col(UITheme.TEXT) else col(UITheme.INK),
		TextSize = px(14),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, px(bh)),
		LayoutOrder = 2,
		ZIndex = 45,
	}, row)
	local host = self._host
	host:_part(card, "BackgroundTransparency", 1.0)
	host:_part(stroke, "Transparency", if wearing then 1.0 else 0.55)
	host:_part(img, "ImageTransparency", 1.0)
	host:_part(name, "TextTransparency", 1.0)
	host:_part(sub, "TextTransparency", 1.0)
	host:_part(label, "TextTransparency", 1.0)
	for _, pt in parts do
		if pt:IsA("ImageLabel") then
			host:_part(pt, "ImageTransparency", 1.0)
		else
			host:_part(pt, "BackgroundTransparency", if wearing then 0.6 else 1.0)
		end
	end
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = if owned then col(UITheme.GLASS_RAISED) else col(UITheme.AMBER_HI)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = if owned then col(UITheme.GLASS_SOLID) else col(UITheme.AMBER)
	end)
	btn.Activated:Connect(function()
		self:_pressed(key)
	end)
end

function FlagShop._rebuild(self)
	for _, b in self._cards do
		self._host:_drop_part(b)
		for _, d in b:GetDescendants() do
			self._host:_drop_part(d)
		end
		b:Destroy()
	end
	table.clear(self._cards)
	local keys = {}
	local order = 0
	for _, age in Shop.ages() do
		order += 1
		self:_section(order, string.upper(age.name), age.line)
		order += 1
		self:_bundle(order, age.id)
		order += 1
		self:_grid(order, age.keys)
		for _, k in age.keys do
			table.insert(keys, "shop_" .. k)
		end
		table.insert(keys, "shopset_" .. age.id)
	end
	Prices.fetch_keys(keys)
end

-- ---------------------------------------------------------------------------------------------
-- Open / close / layout
-- ---------------------------------------------------------------------------------------------

function FlagShop.open(self)
	if self.is_open then
		return
	end
	self.is_open = true
	self:_report("opened")
	self:apply_layout()
	Sheet.show(self)
end

function FlagShop.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function FlagShop.apply_layout(self)
	local ctx = self.ctx
	local cs = self:_card_size()
	-- phones: as many cards across as the sheet holds
	local gw = cs.X * FlagShop.COLS + (FlagShop.COLS - 1) * FlagShop.GAP + 14
	local m = Sheet.place(self, gw)
	local cols = math.floor((m.body_w - 14 + FlagShop.GAP) / (cs.X + FlagShop.GAP))
	self._cols = math.clamp(cols, 2, if ctx.compact then FlagShop.COLS_PHONE else FlagShop.COLS)
	self._sub:set_visible(not ctx.compact or m.body_w > 480)
	if self.is_open then
		self:_rebuild()
	end
end

return FlagShop
