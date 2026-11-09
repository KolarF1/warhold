--!nonstrict
-- Map picker (the single-player map list): a sheet (UI/Sheet) with a grid of map cards (thumbnail, name, a word for its
-- size) under tabs: the lands we made first, then the real Earth by old and new world. The footer names the public-domain data the World map is made from. The grid is a Roblox
-- ScrollingFrame with a UIGridLayout hosted in a kit Control (the kit has no scroll container); card
-- sizes follow UITheme.scale.
-- Signals: picked(map_id), closed.
-- Entries come from set_entries({ {id, name, width, height, categories, thumb}, ... }).

local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local Signal = UITheme.core("Signal")

local MapPicker = W.class(W.Control)

--- Tabs: { label, predicate on the categories set }.
MapPicker.TABS = {
	{ "Our Lands", { invented = true } },
	{ "The Whole Earth", { world = true } },
	{ "Old World", { europe = true, asia = true, africa = true } },
	{ "New World", { north_america = true, south_america = true, oceania = true, antarctica = true } },
	{ "Every Map", nil },
}
--- A size word by tiles: { from this many, the word }, largest first.
MapPicker.SIZE_WORDS = { { 1950000, "A vast war" }, { 1650000, "A broad war" }, { 0, "A close war" } }
MapPicker.CARD = Vector2.new(190, 122)
--- The sheet's body, desktop: four cards and the scroll bar.
MapPicker.WIDTH = 740
MapPicker.ATTRIBUTION = "Map data: Natural Earth and NOAA ETOPO1 (public domain)"

function MapPicker.new(c: any)
	local self = setmetatable({}, MapPicker.__mt)
	W.Control._init(self)
	self.ctx = c
	self.picked = Signal.new()
	self.closed = Signal.new()
	self.is_open = false
	self.entries = {} :: { any }
	self.selected = ""
	self._tab = 1
	local v = Sheet.attach(self, "PICK A MAP")
	-- tabs
	local tabs = UITheme.hbox(6)
	self._tabs = {}
	for i, t in ipairs(MapPicker.TABS) do
		local chip = UITheme.button(t[1], "ChipButton", "", 32.0)
		chip.toggle_mode = true
		chip:set_font_size(12)
		chip:set_pressed_no_signal(i == self._tab)
		chip.pressed:Connect(function()
			self._tab = i
			for j, ch in ipairs(self._tabs) do
				ch:set_pressed_no_signal(j == i)
			end
			self:_rebuild()
		end)
		table.insert(self._tabs, chip)
		tabs:add_child(chip)
	end
	v:add_child(tabs)
	-- grid host
	local host = W.Control.new()
	host:set_mouse_filter(W.MOUSE_PASS)
	host.size_flags_vertical = W.EXPAND_FILL
	self._host = host
	v:add_child(host)
	local sf = Instance.new("ScrollingFrame")
	sf.Name = "MapGrid"
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
	pad.Parent = sf
	-- footer
	self._foot = UITheme.label(MapPicker.ATTRIBUTION, 12, 500, UITheme.TEXT_3)
	v:add_child(self._foot)
	self._cards = {} :: { [string]: TextButton }
	return self
end

function MapPicker.set_entries(self, entries: { any })
	self.entries = entries or {}
	if self.is_open then
		self:_rebuild()
	end
end

local function in_tab(e: any, set: { [string]: boolean }?): boolean
	if set == nil then
		return true
	end
	for _, c in e.categories or {} do
		if set[c] then
			return true
		end
	end
	return false
end

--- The map's size as a player would say it.
function MapPicker.size_word(e: any): string
	if not (e.width and e.height) then
		return ""
	end
	for _, w in MapPicker.SIZE_WORDS do
		if e.width * e.height >= w[1] then
			return w[2]
		end
	end
	return ""
end

--- Ours first, then by name.
local function is_ours(e: any): boolean
	return table.find(e.categories or {}, "invented") ~= nil
end

function MapPicker._card(self, e: any, order: number): TextButton
	local s = UITheme.scale
	local b = Instance.new("TextButton")
	b.Name = e.id
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
	stroke.Color = UITheme.WHITE
	stroke.Transparency = 0.88
	stroke.Thickness = 1
	stroke.Parent = b
	local img = Instance.new("ImageLabel")
	img.Name = "Thumb"
	img.BackgroundTransparency = 1
	UITheme.set_image(img, e.thumb)
	img.ScaleType = Enum.ScaleType.Fit
	img.Position = UDim2.fromOffset(math.floor(8 * s), math.floor(8 * s))
	img.Size = UDim2.new(1, -math.floor(16 * s), 1, -math.floor(46 * s))
	img.ZIndex = 42
	img.Parent = b
	local name = Instance.new("TextLabel")
	name.Name = "MapName"
	name.BackgroundTransparency = 1
	name.FontFace = UITheme.font(700)
	name.TextSize = math.floor(14 * s)
	name.TextColor3 = UITheme.TEXT
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = e.name or e.id
	name.Position = UDim2.new(0, math.floor(8 * s), 1, -math.floor(36 * s))
	name.Size = UDim2.new(1, -math.floor(16 * s), 0, math.floor(18 * s))
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.ZIndex = 42
	name.Parent = b
	local sub = Instance.new("TextLabel")
	sub.Name = "Size"
	sub.BackgroundTransparency = 1
	sub.FontFace = UITheme.font(500)
	sub.TextSize = math.floor(12 * s)
	sub.TextColor3 = UITheme.TEXT_2
	sub.Text = MapPicker.size_word(e)
	sub.Position = UDim2.new(0, math.floor(8 * s), 1, -math.floor(18 * s))
	sub.Size = UDim2.new(1, -math.floor(16 * s), 0, math.floor(14 * s))
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.ZIndex = 42
	sub.Parent = b
	-- Every piece is a part of the grid host, so the panel's pop-in / fade-out reaches the cards
	-- (raw instances showed at full strength before the panel did).
	local host = self._host
	host:_part(b, "BackgroundTransparency", 0.06)
	host:_part(stroke, "Transparency", 0.12)
	host:_part(img, "ImageTransparency", 1.0)
	host:_part(name, "TextTransparency", 1.0)
	host:_part(sub, "TextTransparency", 1.0)
	b.MouseEnter:Connect(function()
		host:_part(b, "BackgroundTransparency", 0.12)
	end)
	b.MouseLeave:Connect(function()
		host:_part(b, "BackgroundTransparency", 0.06)
	end)
	b.Activated:Connect(function()
		self.selected = e.id
		self.ctx:sfx("click")
		self.picked:Fire(e.id)
		self:close()
	end)
	b.Parent = self._sf
	return b
end

function MapPicker._rebuild(self)
	for _, b in self._cards do
		self._host:_drop_part(b)
		for _, d in b:GetDescendants() do
			self._host:_drop_part(d)
		end
		b:Destroy()
	end
	table.clear(self._cards)
	local s = UITheme.scale
	self._grid.CellSize = UDim2.fromOffset(math.floor(MapPicker.CARD.X * s), math.floor(MapPicker.CARD.Y * s))
	self._grid.CellPadding = UDim2.fromOffset(math.floor(10 * s), math.floor(10 * s))
	local set = MapPicker.TABS[self._tab][2]
	local list = {}
	for _, e in self.entries do
		if in_tab(e, set) then
			table.insert(list, e)
		end
	end
	table.sort(list, function(a, b)
		if is_ours(a) ~= is_ours(b) then
			return is_ours(a)
		end
		return (a.name or a.id) < (b.name or b.id)
	end)
	for i, e in list do
		local b = self:_card(e, i)
		if e.id == self.selected then
			local st = b:FindFirstChildOfClass("UIStroke") :: UIStroke
			st.Color = UITheme.color3(UITheme.to_rgba(UITheme.AMBER))
			self._host:_part(st, "Transparency", 1.0)
			st.Thickness = 2
		end
		self._cards[e.id] = b
	end
	self._sf.CanvasPosition = Vector2.zero
end

function MapPicker.open(self, selected: string?)
	if self.is_open then
		return
	end
	self.is_open = true
	self.selected = selected or self.selected
	-- open on the tab that shows the selected map
	self._tab = #MapPicker.TABS
	for i, t in ipairs(MapPicker.TABS) do
		for _, e in self.entries do
			if e.id == self.selected and in_tab(e, t[2]) then
				self._tab = i
				break
			end
		end
		if self._tab == i then
			break
		end
	end
	for j, ch in ipairs(self._tabs) do
		ch:set_pressed_no_signal(j == self._tab)
	end
	self:apply_layout()
	Sheet.show(self)
end

function MapPicker.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function MapPicker.apply_layout(self)
	local m = Sheet.place(self, MapPicker.WIDTH)
	-- (a narrow sheet: slimmer chips, so all the tabs fit across the smallest screens)
	local compact = m.body_w < MapPicker.WIDTH
	if compact ~= self._tabs_compact then
		self._tabs_compact = compact
		for _, chip in self._tabs do
			for _, state in W.BUTTON_STATES do
				local st = UITheme.dup(UITheme.theme().ChipButton.styles[state])
				st.mh = if compact then 8.0 else 14.0
				chip:add_theme_stylebox_override(state, st)
			end
		end
	end
	if self.is_open then
		self:_rebuild()
	end
end

return MapPicker
