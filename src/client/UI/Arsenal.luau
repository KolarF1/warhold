--!nonstrict
-- The War College: a sheet (UI/Sheet) for the tree of Data/Arsenal. It opens from the title's column, from the command
-- bar's War College slot, and on its item when a locked unit is pressed in a match.
--
--   the tree  on the left: three branches, Expansion, Economy and War, as three columns where the sheet is wide and as
--             three tabs where it isn't (phones). A node is a press target at least 44 px tall: its mark, its name and
--             what it takes (YOURS, its Renown, its Robux price, or a lock while what it needs isn't yours). Lines run
--             from what an item needs to the item, lit once that's yours.
--   the item  on the right: its name, one plain sentence (Data/Arsenal `plain`), what it opens the way to in the tree, two
--             facts; then how to get it: a BUY button where Roblox sells it, and the Renown way: LEARN IT with the price when
--             the player has it (a press lays out LEARN IT and NOT YET side by side), else how much Renown is still to earn
--             and how far this branch has come, else what must come first. Wide sheets show it big above the words; phones
--             have no room for that.
--   header    the title, one line of what this is, the Renown balance, close.
-- It opens on the item it was asked for, else the first one the player can buy with Renown now, else the first open one,
-- else the first they don't have. An unlock (Session.unlocked, however it was bought) flashes its item.
-- It closes from its back arrow or a press outside the sheet, never from a press on the sheet.
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local Signal = UITheme.core("Signal")

local IS_ROBLOX = typeof(game) == "Instance"
local function shared(name: string): any
	if IS_ROBLOX then
		return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data[name]) :: any
	end
	return (require :: any)("../../shared/Data/" .. name)
end
local Catalog = shared("Arsenal")
local Products = shared("Products")
local Prices = require("./Prices")
local ArsenalDemo = require("./ArsenalDemo")
local FrameClock = require("../Map/FrameClock")

local Art: any = (function()
	local ok, m = pcall(function()
		if IS_ROBLOX then
			return require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Assets.ArsenalArt)
		end
		return (require :: any)("../../shared/Assets/ArsenalArt")
	end)
	return if ok and type(m) == "table" then m else {}
end)()

local Arsenal = W.class(W.Control)

--- Under the title.
Arsenal.SUBTITLE = "Earned with Renown from your wars. Yours to keep."
--- Logical px. A node (desktop, phone: its width comes from the room there is); the gaps between lanes, rows and branches;
--- the tree's width in columns and in tabs; the item's width.
Arsenal.NODE_W = 128
Arsenal.NODE_H = 46
Arsenal.NODE_H_PHONE = 44
Arsenal.LANE_GAP = 8
Arsenal.ROW_GAP = 18
Arsenal.BRANCH_GAP = 16
Arsenal.TAB_H = 44
Arsenal.BRANCH_HEAD_H = 26
--- The margin round the tree inside its scroll area, so a chosen node's ring isn't cut at the edge (owner, 2026-11-09).
Arsenal.EDGE = 4
--- 3 x (2 x NODE_W + LANE_GAP) + 2 x BRANCH_GAP + 2 x EDGE
Arsenal.COLUMNS_W = 832
Arsenal.TABS_W = 300
Arsenal.TABS_W_PHONE = 336
Arsenal.DETAIL_W = 340
Arsenal.PREVIEW_H = 228
--- What the words and buttons under the preview need at their tallest (a short screen gets a shorter preview).
Arsenal.WORDS_H = 296
--- LEARN IT / NOT YET stands this long before going back to the price.
Arsenal.CONFIRM_S = 12.0
--- A purchase whose answer never comes gives up after this long (it is still saved on the server).
Arsenal.WAIT_S = 30.0
--- A note under the buttons stays this long.
Arsenal.NOTE_S = 4.0

local FONT_H = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FONT_B = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local FONT_M = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
--- A theme colour as a plain Color3 (the accent is read when a part is built: UITheme.set_accent).
local function rgb(c: any): Color3
	return UITheme.color3(c)
end
local ROBUX = "rbxasset://textures/ui/common/robux@3x.png"

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

--- 12345 -> "12,345".
function Arsenal.commas(n: number): string
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return if n < 0 then "-" .. out else out
end

--- 20000 -> "20k", 1500 -> "1,500" (a list row's room).
function Arsenal.short(n: number): string
	if n >= 10000 and n % 1000 == 0 then
		return Arsenal.commas(n / 1000) .. "k"
	end
	return Arsenal.commas(n)
end

--- The item the window opens on: `focus`, else the first the player's Renown can buy now, else the first open one, else
--- the first they don't have, else the first.
function Arsenal.pick(inv: any, focus: string?): string
	if focus ~= nil and Catalog.item(focus) ~= nil then
		return focus
	end
	local unlocks = inv.unlocks or {}
	local stars = inv.stars or 0
	for _, it in Catalog.ITEMS do
		if not unlocks[it.key] and it.stars ~= nil and stars >= it.stars and #Catalog.missing(it, unlocks) == 0 then
			return it.key
		end
	end
	for _, it in Catalog.ITEMS do
		if not unlocks[it.key] and it.stars ~= nil and #Catalog.missing(it, unlocks) == 0 then
			return it.key
		end
	end
	for _, it in Catalog.ITEMS do
		if not unlocks[it.key] then
			return it.key
		end
	end
	return Catalog.ITEMS[1].key
end

--- Where a branch's item stands in its branch, logical px from the branch's top left: x, y. Pure.
function Arsenal.node_pos(it: any, node_w: number, node_h: number): (number, number)
	return (it.lane - 1) * (node_w + Arsenal.LANE_GAP), (it.row - 1) * (node_h + Arsenal.ROW_GAP)
end

function Arsenal.new(c: any)
	local self = setmetatable({}, Arsenal.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	--- the tree's nodes: key -> parts
	self._rows = {} :: { [string]: any }
	--- the branch showing in tabs (Catalog.BRANCHES index), and whether the sheet is wide enough for columns
	self._branch = 1
	self._columns = false
	--- the item shown on the right, and its parts
	self._sel = nil :: string?
	self._detail = nil :: any
	--- { key, how = "stars" | "robux", product?, since }: a purchase on its way
	self._pending = nil :: any
	--- key whose Stars button reads "PRESS AGAIN", and until when
	self._confirm = nil :: string?
	self._confirm_until = 0.0
	self._note = nil :: string?
	self._note_until = 0.0
	-- (Roblox's prices arrive a moment after the first look, and move with its price tests)
	self:_connect(Prices.changed:Connect(function()
		if self.is_open then
			self:_refresh()
		end
	end))
	self._focus = nil :: string?
	self._from = "title"
	--- items whose row was pressed this visit (each reported once)
	self._viewed = {} :: { [string]: boolean }
	local v, head = Sheet.attach(self, "WAR COLLEGE")
	self._v = v
	self._sub = UITheme.label(Arsenal.SUBTITLE, 12, 500, UITheme.TEXT_2)
	self._sub.text_overrun_behavior = W.OVERRUN_ELLIPSIS
	self._sub.clip_text = true
	self._sub.size_flags_horizontal = W.EXPAND_FILL
	self._sub.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._sub)
	-- the Renown balance: a plain number with its mark, gold on the number only
	local bh = UITheme.hbox(6)
	bh.size_flags_vertical = W.SHRINK_CENTER
	local mark = UITheme.icon_rect("renown", 16.0, UITheme.TEXT_2)
	mark.size_flags_vertical = W.SHRINK_CENTER
	bh:add_child(mark)
	self._balance = UITheme.label("0", 16, 800, UITheme.GOLD)
	self._balance.size_flags_vertical = W.SHRINK_CENTER
	bh:add_child(self._balance)
	self._balance_row = bh
	head:add_child(bh)
	-- body: the tree | the item
	local body = UITheme.hbox(14)
	body.size_flags_vertical = W.EXPAND_FILL
	v:add_child(body)
	local list_host = W.Control.new()
	list_host:set_mouse_filter(W.MOUSE_PASS)
	self._list_host = list_host
	body:add_child(list_host)
	--- the three tabs, where the tree shows one branch at a time
	self._tabs = new("Frame", { Name = "BranchTabs", BackgroundTransparency = 1, ZIndex = 41 }, list_host.gui)
	self._list = new("ScrollingFrame", {
		Name = "CollegeTree",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = rgb(UITheme.TEXT),
		ScrollBarImageTransparency = 0.6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 40,
	}, list_host.gui)
	local detail_host = W.Control.new()
	detail_host:set_mouse_filter(W.MOUSE_PASS)
	self._detail_host = detail_host
	body:add_child(detail_host)
	if IS_ROBLOX then
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(_u, product_id, purchased)
			self:_on_prompt_done(product_id, purchased)
		end)
	end
	return self
end

--- The session's inventory, unlock answers and unlocks (UIRoot.setup, when the session exists).
function Arsenal.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	s.inventory_changed:Connect(function()
		if self.is_open then
			self:_refresh()
		end
	end)
	s.unlock_result:Connect(function(key: string, ok: boolean, reason: string?)
		self:_on_unlock_result(key, ok, reason)
	end)
	s.unlocked:Connect(function(key: string)
		self:_on_unlocked(key)
	end)
end

function Arsenal._inv(self): any
	local s = self.ctx.session
	return if s ~= nil and s.inventory ~= nil then s.inventory else { stars = 0, unlocks = {}, loaded = false }
end

function Arsenal._report(self, kind: string, a: any?, b: any?)
	local s = self.ctx.session
	if s ~= nil and type(s.report) == "function" then
		s:report(kind, a, b)
	end
end

--- The Robux price of `it` (Roblox's own once it answered), or nil while its product doesn't exist.
function Arsenal._robux(_self, it: any): number?
	local p = Products[it.product]
	if p == nil or p.id == 0 then
		return nil
	end
	return Prices.robux(it.product)
end

-- ---------------------------------------------------------------------------------------------
-- The tree
-- ---------------------------------------------------------------------------------------------

--- A branch's index in Catalog.BRANCHES.
local function branch_index(key: string): number
	for i, b in Catalog.BRANCHES do
		if b.key == key then
			return i
		end
	end
	return 1
end

--- The three tabs (where the tree shows one branch at a time): the branch's mark and name, 44 px tall.
function Arsenal._build_tabs(self)
	for _, ch in self._tabs:GetChildren() do
		ch:Destroy()
	end
	local u = UITheme.scale
	local on = not self._columns
	self._tabs.Visible = on
	local tab_h = if on then Arsenal.TAB_H else 0
	self._tabs.Size = UDim2.new(1, 0, 0, tab_h * u)
	local pad = if on then tab_h + 6 else 0
	self._list.Position = UDim2.fromOffset(0, pad * u)
	self._list.Size = UDim2.new(1, 0, 1, -pad * u)
	if not on then
		return
	end
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4 * u),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, self._tabs)
	local n = #Catalog.BRANCHES
	for i, br in Catalog.BRANCHES do
		local chosen = i == self._branch
		local b = new("TextButton", {
			Name = "Tab_" .. br.key,
			Text = string.upper(br.name),
			FontFace = FONT_B,
			TextSize = math.floor(12 * u),
			TextColor3 = if chosen then rgb(UITheme.INK) else rgb(UITheme.TEXT),
			AutoButtonColor = false,
			BackgroundColor3 = if chosen then rgb(UITheme.AMBER) else rgb(UITheme.GLASS_RAISED),
			BorderSizePixel = 0,
			LayoutOrder = i,
			Size = UDim2.new(1 / n, -4 * u * (n - 1) / n, 0, tab_h * u),
			ZIndex = 42,
		}, self._tabs)
		new("UICorner", { CornerRadius = UDim.new(0, UITheme.R_SM * u) }, b)
		b.Activated:Connect(function()
			self:_show_branch(i)
		end)
	end
end

--- The branch `i` shows (tabs): its nodes replace the last one's.
function Arsenal._show_branch(self, i: number)
	if i == self._branch then
		return
	end
	self._branch = i
	self.ctx:sfx("tab", -4.0)
	self:_build_list()
	self:_refresh_list()
end

--- The line from what `it` needs (`from`) to `it`: straight down, or down, across and down. Flat frames only.
function Arsenal._link(self, from: any, it: any, x0: number, y0: number, nw: number, nh: number, u: number)
	local px, py = Arsenal.node_pos(from, nw, nh)
	local cx, cy = Arsenal.node_pos(it, nw, nh)
	local ax, ay = x0 + px + nw / 2, y0 + py + nh
	local bx, by = x0 + cx + nw / 2, y0 + cy
	local t = 2
	local segs = {}
	if ax == bx then
		table.insert(segs, { ax - t / 2, ay, t, by - ay })
	else
		-- (out of the side of the row above, so it never crosses a node between them)
		local my = by - Arsenal.ROW_GAP / 2
		table.insert(segs, { ax - t / 2, ay, t, my - ay })
		table.insert(segs, { math.min(ax, bx) - t / 2, my - t / 2, math.abs(bx - ax) + t, t })
		table.insert(segs, { bx - t / 2, my, t, by - my })
	end
	local parts = {}
	for _, sg in segs do
		table.insert(parts, new("Frame", {
			Name = "Link",
			BackgroundColor3 = rgb(UITheme.TEXT_3),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(sg[1] * u, sg[2] * u),
			Size = UDim2.fromOffset(math.max(sg[3], t) * u, math.max(sg[4], t) * u),
			ZIndex = 41,
		}, self._list))
	end
	table.insert(self._links, { from = from.key, parts = parts })
end

function Arsenal._build_list(self)
	for _, ch in self._list:GetChildren() do
		if ch:IsA("GuiObject") then
			ch:Destroy()
		end
	end
	table.clear(self._rows)
	self._links = {}
	self:_build_tabs()
	local u = UITheme.scale
	local nh = if self.ctx.compact then Arsenal.NODE_H_PHONE else Arsenal.NODE_H
	nh = math.max(nh, UITheme.touch_min or 0)
	local nw = self._node_w or Arsenal.NODE_W
	local bottom = 0
	for i, br in Catalog.BRANCHES do
		if self._columns or i == self._branch then
			local x0 = Arsenal.EDGE + (if self._columns then (i - 1) * (2 * nw + Arsenal.LANE_GAP + Arsenal.BRANCH_GAP) else 0)
			local y0 = Arsenal.EDGE
			if self._columns then
				new("TextLabel", {
					Name = "Branch",
					BackgroundTransparency = 1,
					Text = string.upper(br.name),
					FontFace = FONT_B,
					TextSize = math.floor(13 * u),
					TextColor3 = rgb(UITheme.TEXT_2),
					TextXAlignment = Enum.TextXAlignment.Left,
					Position = UDim2.fromOffset(x0 * u, 0),
					Size = UDim2.fromOffset((2 * nw + Arsenal.LANE_GAP) * u, 20 * u),
					ZIndex = 41,
				}, self._list)
				y0 = Arsenal.EDGE + Arsenal.BRANCH_HEAD_H
			end
			for _, it in Catalog.in_branch(br.key) do
				for _, k in it.needs do
					self:_link(Catalog.item(k), it, x0, y0, nw, nh, u)
				end
				local x, y = Arsenal.node_pos(it, nw, nh)
				self._rows[it.key] = self:_row(it, x0 + x, y0 + y, nw, nh, u)
				bottom = math.max(bottom, y0 + y + nh)
			end
		end
	end
	self._list.CanvasSize = UDim2.fromOffset(0, (bottom + Arsenal.EDGE + 6) * u)
end

--- A node: a press target with its mark, its name and what it takes.
function Arsenal._row(self, it: any, x: number, y: number, nw: number, nh: number, u: number): any
	local b = new("TextButton", {
		Name = "Row_" .. it.key,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = rgb(UITheme.GLASS_RAISED),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x * u, y * u),
		Size = UDim2.fromOffset(nw * u, nh * u),
		ZIndex = 42,
	}, self._list)
	new("UICorner", { CornerRadius = UDim.new(0, UITheme.R_MD * u) }, b)
	local stroke = new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = rgb(UITheme.AMBER),
		Thickness = 1.5,
		Transparency = 1,
	}, b)
	local th = 24
	local shot = if type(Art.renders) == "table" then Art.renders[it.key] else nil
	local mark = new("ImageLabel", {
		Name = "Render",
		BackgroundTransparency = 1,
		Image = if shot ~= nil then shot.id else (UITheme.icon(it.icon) or ""),
		ImageColor3 = if shot ~= nil then UITheme.WHITE else rgb(UITheme.TEXT),
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6 * u, 0.5, 0),
		Size = UDim2.fromOffset(th * u, th * u),
		ZIndex = 43,
	}, b)
	-- (a long name shrinks to fit rather than being cut, never under 12)
	local tx0 = th + 12
	local name = new("TextLabel", {
		Name = "Name",
		BackgroundTransparency = 1,
		Text = it.title,
		FontFace = FONT_B,
		TextScaled = true,
		TextColor3 = rgb(UITheme.TEXT),
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(tx0 * u, (nh / 2 - 16) * u),
		Size = UDim2.fromOffset((nw - tx0 - 4) * u, 16 * u),
		ZIndex = 43,
	}, b)
	new("UITextSizeConstraint", { MaxTextSize = math.floor(13 * u), MinTextSize = 12 }, name)
	-- what it takes
	local right = new("Frame", {
		Name = "Price",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(tx0 * u, nh / 2 * u),
		Size = UDim2.fromOffset((nw - tx0 - 4) * u, 16 * u),
		ZIndex = 43,
	}, b)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3 * u),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, right)
	local pic = new("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(12 * u, 12 * u),
		LayoutOrder = 1,
		ZIndex = 44,
	}, right)
	local tx = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT_H,
		TextSize = math.floor(12 * u),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16 * u),
		LayoutOrder = 2,
		ZIndex = 44,
	}, right)
	b.MouseEnter:Connect(function()
		if self._sel ~= it.key then
			b.BackgroundColor3 = rgb(UITheme.lerp(UITheme.GLASS_RAISED, UITheme.AMBER, 0.08))
		end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = if self._sel == it.key then rgb(UITheme.lerp(UITheme.GLASS_RAISED, UITheme.AMBER, 0.16)) else rgb(UITheme.GLASS_RAISED)
	end)
	b.Activated:Connect(function()
		self:_select(it.key, true)
	end)
	return { button = b, stroke = stroke, name = name, mark = mark, icon = pic, text = tx }
end

function Arsenal._refresh_list(self)
	local inv = self:_inv()
	local stars = inv.stars or 0
	for key, r in self._rows do
		local it = Catalog.item(key)
		local on = self._sel == key
		r.button.BackgroundColor3 = if on then rgb(UITheme.lerp(UITheme.GLASS_RAISED, UITheme.AMBER, 0.16)) else rgb(UITheme.GLASS_RAISED)
		r.stroke.Transparency = if on then 0 else 1
		local locked = not inv.unlocks[key] and it.stars ~= nil and #Catalog.missing(it, inv.unlocks) > 0
		r.name.TextColor3 = if locked then rgb(UITheme.TEXT_2) else rgb(UITheme.TEXT)
		r.icon.Visible = true
		if inv.unlocks[key] then
			UITheme.set_image(r.icon, UITheme.icon("check"))
			r.icon.ImageColor3 = rgb(UITheme.GREEN)
			r.text.Text = "YOURS"
			r.text.TextColor3 = rgb(UITheme.GREEN)
		elseif it.stars ~= nil then
			-- (a lock says it can't be had yet; the price says what it will take)
			UITheme.set_image(r.icon, UITheme.icon(if locked then "lock" else "renown"))
			r.icon.ImageColor3 = rgb(UITheme.TEXT_2)
			r.text.Text = Arsenal.short(it.stars)
			r.text.TextColor3 = if not locked and stars >= it.stars then rgb(UITheme.GOLD) else rgb(UITheme.TEXT_2)
		else
			local price = self:_robux(it)
			r.icon.Visible = price ~= nil
			r.icon.Image = ROBUX
			r.icon.ImageColor3 = rgb(UITheme.TEXT_2)
			r.text.Text = if price ~= nil then Arsenal.commas(price) else "SOON"
			r.text.TextColor3 = if price ~= nil then rgb(UITheme.GOLD) else rgb(UITheme.TEXT_2)
		end
	end
	-- a line is lit once what it comes from is yours
	for _, link in self._links or {} do
		local c = if inv.unlocks[link.from] then rgb(UITheme.AMBER) else rgb(UITheme.TEXT_3)
		for _, part in link.parts do
			part.BackgroundColor3 = c
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- The item
-- ---------------------------------------------------------------------------------------------

--- The item's area in logical px for this layout: its width, its height, whether it goes without a preview (phones: no
--- room), and the preview's size.
function Arsenal._detail_geometry(self): (number, number, boolean, Vector2)
	local size = self._detail_size or Vector2.new(Arsenal.DETAIL_W, Arsenal.PREVIEW_H + 250)
	local side = self.ctx.compact
	local pv = if side then Vector2.new(0, 0) else Vector2.new(size.X, math.clamp(size.Y - Arsenal.WORDS_H, 120, Arsenal.PREVIEW_H))
	return size.X, size.Y, side, pv
end

function Arsenal._build_detail(self)
	if self._detail ~= nil then
		if self._detail.demo ~= nil then
			self._detail.demo:destroy()
		end
		self._detail.root:Destroy()
		self._detail = nil
	end
	local it = Catalog.item(self._sel or "")
	if it == nil then
		return
	end
	local u = UITheme.scale
	local compact = self.ctx.compact
	local dw, dh, side, pv = self:_detail_geometry()
	local root = new("Frame", {
		Name = "ArsenalItem",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(dw * u, dh * u),
		ZIndex = 40,
	}, self._detail_host.gui)
	local demo, sticker, flash = nil, nil, nil
	if not side then
		-- the preview: what it does in a match (ArsenalDemo), its render a sticker in the corner
		local pw, ph = pv.X * u, pv.Y * u
		local ground = new("CanvasGroup", {
			Name = "Preview",
			BackgroundColor3 = rgb(UITheme.GLASS_RAISED),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(pw, ph),
			ZIndex = 41,
		}, root)
		new("UICorner", { CornerRadius = UDim.new(0, UITheme.R_MD * u) }, ground)
		demo = if ArsenalDemo["_build_" .. it.key] ~= nil
			then ArsenalDemo.new(ground, it, Vector2.new(pw, ph), u, 0, root, UITheme.R_MD * u)
			else nil
		if demo ~= nil and demo:has_map() then
			-- (the map lies under the group: ArsenalDemo._map)
			ground.BackgroundTransparency = 1
		end
		local shot = if type(Art.renders) == "table" then Art.renders[it.key] else nil
		local image = if shot ~= nil then shot.id else (UITheme.icon(it.icon, true) or "")
		-- (no render of ours: the item's glyph, square, in the middle of the preview)
		local sh = (if demo ~= nil then 0.36 elseif shot ~= nil then 0.8 else 0.5) * ph
		local sw = if shot ~= nil then sh * shot.w / shot.h else sh
		local max_w = pw * (if demo ~= nil then 0.28 else 0.8)
		if sw > max_w then
			sh *= max_w / sw
			sw = max_w
		end
		sticker = new("ImageLabel", {
			Name = "Render",
			BackgroundTransparency = 1,
			Image = image,
			ImageColor3 = if shot ~= nil then UITheme.WHITE else rgb(UITheme.TEXT),
			AnchorPoint = if demo ~= nil then Vector2.new(0, 0) else Vector2.new(0.5, 0.5),
			Position = if demo ~= nil
				then UDim2.fromOffset(8 * u, 6 * u)
				elseif shot ~= nil then UDim2.fromScale(0.5, 0.5)
				else UDim2.fromOffset(pw * 0.5, ph * 0.5),
			Size = UDim2.fromOffset(sw, sh),
			ZIndex = 45,
		}, root)
		flash = new("Frame", {
			Name = "Flash",
			BackgroundColor3 = rgb(UITheme.AMBER),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(pw, ph),
			ZIndex = 49,
		}, root)
		new("UICorner", { CornerRadius = UDim.new(0, UITheme.R_MD * u) }, flash)
	end
	-- the words: under the preview, or on their own on phones
	local x0 = 0
	local y0 = if side then 0 else pv.Y + 12
	local tw = dw
	local col = new("Frame", {
		Name = "Words",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x0 * u, y0 * u),
		Size = UDim2.fromOffset(tw * u, (dh - y0) * u),
		ZIndex = 41,
	}, root)
	local y = 0
	local name_fs = if compact then 18 else 24
	new("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = string.upper(it.title),
		FontFace = FONT_H,
		TextSize = math.floor(name_fs * u),
		TextColor3 = rgb(UITheme.TEXT),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, (name_fs + 4) * u),
		ZIndex = 42,
	}, col)
	y += name_fs + 6
	-- the one sentence
	local plain_fs = if compact then 12 else 14
	local plain = it.plain or it.tagline
	local plain_h = UITheme.wrapped_height(plain, plain_fs, 500, tw) + 2
	new("TextLabel", {
		Name = "Plain",
		BackgroundTransparency = 1,
		Text = plain,
		FontFace = FONT_M,
		TextSize = math.floor(plain_fs * u),
		TextColor3 = rgb(UITheme.TEXT),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, plain_h * u),
		ZIndex = 42,
	}, col)
	y += plain_h + 4
	-- where it leads in the tree
	local leads = {}
	for _, other in Catalog.ITEMS do
		if table.find(other.needs, it.key) then
			table.insert(leads, other.title)
		end
	end
	if #leads > 0 then
		local leads_text = "Leads to " .. table.concat(leads, ", ")
		local leads_h = UITheme.wrapped_height(leads_text, 12, 500, tw) + 2
		new("TextLabel", {
			Name = "Leads",
			BackgroundTransparency = 1,
			Text = leads_text,
			FontFace = FONT_M,
			TextSize = math.floor(12 * u),
			TextColor3 = rgb(UITheme.TEXT_2),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Position = UDim2.fromOffset(0, y * u),
			Size = UDim2.new(1, 0, 0, leads_h * u),
			ZIndex = 42,
		}, col)
		y += leads_h + 4
	end
	-- what kind of thing it is, and that it's forever
	local chips = new("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, 20 * u),
		ZIndex = 42,
	}, col)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6 * u),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chips)
	-- (the row doesn't wrap: what doesn't fit is left out, the facts first to stay)
	local chip_room = tw
	local function chip(text: string, color: Color3, order: number)
		local w = UITheme.text_width(text, 12, 700) + 16
		if w > chip_room then
			return
		end
		chip_room -= w + 6
		local l = new("TextLabel", {
			BackgroundColor3 = rgb(UITheme.GLASS_RAISED),
			Text = text,
			FontFace = FONT_B,
			TextSize = math.floor(12 * u),
			TextColor3 = color,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20 * u),
			LayoutOrder = order,
			ZIndex = 43,
		}, chips)
		new("UICorner", { CornerRadius = UDim.new(0, UITheme.R_SM * u) }, l)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8 * u), PaddingRight = UDim.new(0, 8 * u) }, l)
	end
	for i, f in it.facts or {} do
		chip(string.upper(f), rgb(UITheme.TEXT_2), 2 + i)
	end
	-- (the facts only: the node's mark says what kind it is, the subtitle that it's forever)
	y += if compact then 24 else 30
	-- how to get it (rebuilt on every refresh: _build_cta)
	local cta = new("Frame", {
		Name = "Get",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 1, -y * u),
		ZIndex = 42,
	}, col)
	self._detail = {
		key = it.key,
		root = root,
		demo = demo,
		sticker = sticker,
		flash = flash,
		cta = cta,
		width = tw,
	}
	self:_build_cta()
end

--- A full-width button at `y` (logical px), `h` tall; its row lays out the words and icons. Returns its parts.
local function button(parent: Instance, name: string, y: number, h: number, u: number, fill: Color3, stroke: Color3?): any
	local b = new("TextButton", {
		Name = name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = fill,
		-- (outlined: a faint wash of its colour, so it doesn't read as a hole)
		BackgroundTransparency = if stroke ~= nil then 0.9 else 0,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, y * u),
		Size = UDim2.new(1, 0, 0, h * u),
		ZIndex = 43,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, UITheme.R_MD * u) }, b)
	if stroke ~= nil then
		new("UIStroke", { Color = stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	end
	local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 44 }, b)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6 * u),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local base = b.BackgroundTransparency
	b.MouseEnter:Connect(function()
		b.BackgroundTransparency = if stroke ~= nil then 0.8 else 0.12
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundTransparency = base
	end)
	return { button = b, row = row }
end

--- BUY: one flat block of the banner's colour, the word on the left and the price on the right. `price` nil: SOON,
--- grey; `busy`: "..." alone.
local function buy_button(parent: Instance, y: number, h: number, u: number, price: number?, busy: boolean, fs: number): any
	local on = price ~= nil
	local face = if on then rgb(UITheme.AMBER) else rgb(UITheme.GLASS_RAISED)
	local ink = if on then rgb(UITheme.INK) else rgb(UITheme.TEXT_2)
	local b = new("TextButton", {
		Name = "Buy",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = face,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, h * u),
		ZIndex = 43,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, UITheme.R_MD * u) }, b)
	new("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Text = if busy then "..." elseif on then "BUY" else "SOON",
		FontFace = FONT_H,
		TextSize = math.floor(fs * u),
		TextColor3 = ink,
		TextXAlignment = if busy or not on then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18 * u, 0),
		Size = UDim2.new(1, -36 * u, 1, 0),
		ZIndex = 46,
	}, b)
	if on and not busy then
		local price_row = new("Frame", {
			Name = "Price",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -18 * u, 0.5, 0),
			Size = UDim2.fromOffset(0, h * u),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 46,
		}, b)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 5 * u),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, price_row)
		new("ImageLabel", {
			Name = "Robux",
			BackgroundTransparency = 1,
			Image = ROBUX,
			ImageColor3 = ink,
			Size = UDim2.fromOffset(math.floor((fs + 1) * u), math.floor((fs + 1) * u)),
			LayoutOrder = 1,
			ZIndex = 47,
		}, price_row)
		new("TextLabel", {
			Name = "Amount",
			BackgroundTransparency = 1,
			Text = Arsenal.commas(price :: number),
			FontFace = FONT_H,
			TextSize = math.floor(fs * u),
			TextColor3 = ink,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, h * u),
			LayoutOrder = 2,
			ZIndex = 47,
		}, price_row)
	end
	b.MouseEnter:Connect(function()
		if on then
			b.BackgroundColor3 = rgb(UITheme.AMBER_HI)
		end
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = face
	end)
	return { button = b }
end

local function words(row: Instance, text: string, size: number, color: Color3, u: number, order: number, h: number)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		FontFace = FONT_H,
		TextSize = math.floor(size * u),
		TextColor3 = color,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, h * u),
		LayoutOrder = order,
		ZIndex = 45,
	}, row)
end

local function pic(row: Instance, image: string, size: number, color: Color3, u: number, order: number)
	return new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = image,
		ImageColor3 = color,
		Size = UDim2.fromOffset(size * u, size * u),
		LayoutOrder = order,
		ZIndex = 45,
	}, row)
end

--- How to get the item shown: YOURS, or BUY with Robux where Roblox sells it and under it the Renown way.
function Arsenal._build_cta(self)
	local d = self._detail
	if d == nil then
		return
	end
	for _, ch in d.cta:GetChildren() do
		ch:Destroy()
	end
	local it = Catalog.item(d.key)
	local u = UITheme.scale
	local compact = self.ctx.compact
	local inv = self:_inv()
	local stars = inv.stars or 0
	local pending = self._pending
	local busy = pending ~= nil and pending.key == it.key
	local bh = if compact then 44 else 48
	local sh = math.max(if compact then 30 else 36, UITheme.touch_min)
	local y = 0
	if inv.unlocks[it.key] then
		local green = rgb(UITheme.GREEN)
		local own = button(d.cta, "Owned", y, bh, u, green, green)
		pic(own.row, UITheme.icon("check") or "", 18, green, u, 1)
		words(own.row, "YOURS", if compact then 15 else 17, green, u, 2, bh)
		own.button.Active = false
		y += bh + 8
		self:_line(
			d.cta,
			y,
			if it.kind == "boost"
				then "It works on its own in each war."
				elseif it.kind == "doctrine" then "It can come up in your drafts, every match."
				else "It waits on your rail in every war, once its age opens.",
			rgb(UITheme.TEXT_2)
		)
		return
	end
	-- BUY with Robux: where Roblox sells it, or a grey SOON on what Renown can't buy (nothing else says how to get it)
	local price = self:_robux(it)
	d.buy = nil
	if price ~= nil or it.stars == nil then
		local buy = buy_button(d.cta, y, bh, u, price, busy and pending.how == "robux", if compact then 15 else 18)
		buy.button.Activated:Connect(function()
			self:_robux_pressed(it)
		end)
		d.buy = buy
		y += bh + 8
	end
	-- the other way: Renown
	local needs = Catalog.missing(it, inv.unlocks)
	if it.stars == nil then
		self:_line(d.cta, y, "Sold for Robux only.", rgb(UITheme.TEXT_2))
		y += 18
	elseif #needs > 0 then
		-- what must come first, and what it will cost once it has
		local names = {}
		for _, n in needs do
			table.insert(names, n.title)
		end
		self:_line(d.cta, y, string.format("First earn %s. Then %s Renown.", table.concat(names, " and "), Arsenal.commas(it.stars)), rgb(UITheme.TEXT_2))
		y += 32
	elseif stars >= it.stars then
		local confirm = self._confirm == it.key
		local tx = rgb(UITheme.TEXT)
		local num = rgb(UITheme.GOLD)
		if busy and pending.how == "stars" then
			local alt = button(d.cta, "Stars", y, sh, u, tx, rgb(UITheme.TEXT_3))
			words(alt.row, "...", 12, tx, u, 1, sh)
		elseif confirm then
			-- (asked in place: the price on one side, a way out on the other)
			local yes = button(d.cta, "Stars", y, sh, u, rgb(UITheme.AMBER))
			yes.button.Size = UDim2.new(0.66, -4 * u, 0, sh * u)
			words(yes.row, "LEARN IT", 12, rgb(UITheme.INK), u, 1, sh)
			pic(yes.row, UITheme.icon("renown") or "", 15, rgb(UITheme.INK), u, 2)
			words(yes.row, Arsenal.commas(it.stars), 12, rgb(UITheme.INK), u, 3, sh)
			yes.button.Activated:Connect(function()
				self:_stars_pressed(it)
			end)
			local no = button(d.cta, "NotYet", y, sh, u, tx, rgb(UITheme.TEXT_3))
			no.button.Position = UDim2.new(0.66, 4 * u, 0, y * u)
			no.button.Size = UDim2.new(0.34, -4 * u, 0, sh * u)
			words(no.row, "NOT YET", 12, tx, u, 1, sh)
			no.button.Activated:Connect(function()
				self._confirm = nil
				self.ctx:sfx("tab")
				self:_build_cta()
			end)
		else
			local alt = button(d.cta, "Stars", y, sh, u, tx, rgb(UITheme.TEXT_3))
			words(alt.row, "LEARN IT", if compact then 12 else 14, tx, u, 1, sh)
			pic(alt.row, UITheme.icon("renown") or "", 15, rgb(UITheme.TEXT_2), u, 2)
			words(alt.row, Arsenal.commas(it.stars), if compact then 12 else 14, num, u, 3, sh)
			alt.button.Activated:Connect(function()
				self:_stars_pressed(it)
			end)
		end
		y += sh + 8
	else
		-- what is still to earn, and how far this branch has come
		local row = new("Frame", {
			Name = "Earn",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y * u),
			Size = UDim2.new(1, 0, 0, 16 * u),
			ZIndex = 43,
		}, d.cta)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4 * u),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)
		local fs = 12
		new("TextLabel", {
			BackgroundTransparency = 1,
			Text = "Still to earn:",
			FontFace = FONT_M,
			TextSize = math.floor(fs * u),
			TextColor3 = rgb(UITheme.TEXT_2),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16 * u),
			LayoutOrder = 1,
			ZIndex = 44,
		}, row)
		pic(row, UITheme.icon("renown") or "", 12, rgb(UITheme.TEXT_2), u, 2)
		new("TextLabel", {
			BackgroundTransparency = 1,
			Text = Arsenal.commas(it.stars - stars),
			FontFace = FONT_B,
			TextSize = math.floor(fs * u),
			TextColor3 = rgb(UITheme.GOLD),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16 * u),
			LayoutOrder = 3,
			ZIndex = 44,
		}, row)
		y += 20
		local branch_items = Catalog.in_branch(it.branch)
		local learned = 0
		for _, b in branch_items do
			if inv.unlocks[b.key] then
				learned += 1
			end
		end
		local branch_name = it.branch
		for _, b in Catalog.BRANCHES do
			if b.key == it.branch then
				branch_name = b.name
			end
		end
		self:_line(d.cta, y, string.format("%s: %d of %d learned.", branch_name, learned, #branch_items), rgb(UITheme.TEXT_2))
		y += 18
	end
	-- a note about the last press
	if self._note ~= nil and os.clock() < self._note_until then
		self:_line(d.cta, y, self._note, self._note_color or rgb(UITheme.TEXT))
	end
end

--- A line of small text in the "how to get it" area, at `y` (logical px).
function Arsenal._line(self, parent: Instance, y: number, text: string, color: Color3)
	local u = UITheme.scale
	new("TextLabel", {
		Name = "Line",
		BackgroundTransparency = 1,
		Text = text,
		FontFace = FONT_M,
		TextSize = math.floor(12 * u),
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, y * u),
		Size = UDim2.new(1, 0, 0, 30 * u),
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 44,
	}, parent)
end

--- Show item `key` on the right. `by_player`: a press on its row (reported).
function Arsenal._select(self, key: string, by_player: boolean?)
	if Catalog.item(key) == nil then
		return
	end
	local it = Catalog.item(key)
	if not self._columns and branch_index(it.branch) ~= self._branch then
		-- (asked for from elsewhere: its branch comes up with it)
		self._branch = branch_index(it.branch)
		self:_build_list()
	end
	if key ~= self._sel then
		self._sel = key
		self._confirm = nil
		self._note = nil
		self:_build_detail()
		if by_player then
			self.ctx:sfx("tab", -4.0)
			if not self._viewed[key] then
				self._viewed[key] = true
				self:_report("arsenal_view", key)
			end
		end
	end
	self:_refresh_list()
end

--- The list's prices, the balance, and the item's buttons, from the inventory and what's pending.
function Arsenal._refresh(self)
	local inv = self:_inv()
	-- (still loading: "…", never a 0 that reads as Renown lost; release review 2026-11-07)
	self._balance:set_text(if inv.loaded == false then "…" else Arsenal.commas(inv.stars or 0))
	self:_refresh_list()
	self:_build_cta()
end

--- A note under the item's buttons for a moment (the last press: not enough Stars, PRESS AGAIN...).
function Arsenal._say(self, text: string, color: any?)
	self._note = text
	self._note_color = if typeof(color) == "Color3"
		then color
		elseif color ~= nil then UITheme.color3(UITheme.to_rgba(color))
		else nil
	self._note_until = os.clock() + Arsenal.NOTE_S
	self:_build_cta()
end

function Arsenal._rebuild(self)
	self:_build_list()
	self:_build_detail()
	self:_refresh()
end

-- ---------------------------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------------------------

function Arsenal._stars_pressed(self, it: any)
	local inv = self:_inv()
	if self._pending ~= nil or inv.unlocks[it.key] or it.stars == nil or #Catalog.missing(it, inv.unlocks) > 0 then
		return
	end
	if (inv.stars or 0) < it.stars then
		self.ctx:sfx("deny", -4.0)
		local short = Arsenal.commas(it.stars - (inv.stars or 0))
		self:_say(string.format("%s more Renown needed. Matches pay it.", short))
		return
	end
	if self._confirm ~= it.key or os.clock() > self._confirm_until then
		-- the first press asks once more
		self._confirm = it.key
		self._confirm_until = os.clock() + Arsenal.CONFIRM_S
		self.ctx:sfx("tab")
		self:_build_cta()
		return
	end
	self._confirm = nil
	local s = self.ctx.session
	if s == nil or not s:buy_unlock(it.key) then
		self.ctx:sfx("deny")
		self:_say("The server didn't answer. Try again soon.", UITheme.RED)
		return
	end
	self:_report("arsenal_click", it.key, "stars")
	self.ctx:sfx("buy")
	self._pending = { key = it.key, how = "stars", since = os.clock() }
	self:_refresh()
end

function Arsenal._robux_pressed(self, it: any)
	local inv = self:_inv()
	local p = Products[it.product]
	if self._pending ~= nil or inv.unlocks[it.key] then
		return
	end
	if p == nil or p.id == 0 or not IS_ROBLOX then
		self.ctx:sfx("deny", -4.0)
		self:_say(it.title .. " can't be bought with Robux yet.", UITheme.TEXT_2)
		return
	end
	self._confirm = nil
	self:_report("arsenal_click", it.key, "robux")
	self.ctx:sfx("confirm")
	self._pending = { key = it.key, how = "robux", product = p.id, phase = "prompt", since = os.clock() }
	self:_refresh()
	local ok = pcall(function()
		game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, p.id)
	end)
	if not ok then
		self._pending = nil
		self:_say("The shop is shut for now.", UITheme.RED)
		self:_refresh()
	end
end

function Arsenal._on_prompt_done(self, product_id: number, purchased: boolean)
	local p = self._pending
	if p == nil or p.how ~= "robux" or p.phase ~= "prompt" or p.product ~= product_id then
		return
	end
	if not purchased then
		self._pending = nil
		if self.is_open then
			self:_refresh()
		end
		return
	end
	-- bought: the server's receipt unlocks it and the inventory says so (Session.unlocked)
	p.phase = "granting"
	p.since = os.clock()
	if self:_inv().unlocks[p.key] then
		self:_on_unlocked(p.key)
	end
end

function Arsenal._on_unlock_result(self, key: string, ok: boolean, reason: string?)
	local p = self._pending
	if p == nil or p.key ~= key or p.how ~= "stars" then
		return
	end
	if ok then
		return -- (the inventory follows: Session.unlocked flashes the item)
	end
	self._pending = nil
	self.ctx:sfx("deny")
	self:_say(
		if reason == "not enough"
			then "Still short of Renown."
			elseif reason == "owned" then "It's already yours."
			elseif reason == "locked" then "Earn what comes before it first."
			else "That didn't work, and nothing was spent. Try again soon.",
		UITheme.RED
	)
	self:_refresh()
end

--- An item was unlocked (however it was bought): it shows, flashing.
function Arsenal._on_unlocked(self, key: string)
	local p = self._pending
	if p ~= nil and p.key == key then
		self._pending = nil
	end
	if not self.is_open then
		return
	end
	local it = Catalog.item(key)
	self.ctx:sfx("unlock")
	self:_select(key, false)
	self:_say(string.upper(it.title) .. " IS YOURS", UITheme.GREEN)
	self:_refresh()
	local d = self._detail
	if d ~= nil and d.key == key then
		-- a brief wash of the accent over the preview, gone in the frames that follow (Arsenal.frame)
		if d.flash ~= nil then
			d.flash.BackgroundTransparency = if UITheme.reduced_motion then 1 else 0.5
		end
	end
end

--- Every frame while open (UIRoot._process): the item's scene plays; a just-unlocked item's wash fades.
function Arsenal.frame(self, delta: number?)
	local d = self._detail
	if d == nil then
		return
	end
	local now = FrameClock.now()
	if d.demo ~= nil then
		d.demo:step(now)
	end
	if d.flash ~= nil and d.flash.BackgroundTransparency < 1 then
		d.flash.BackgroundTransparency = math.min(1, d.flash.BackgroundTransparency + (delta or 0.016) * 1.5)
	end
end

--- Once a second while open: LEARN IT / NOT YET runs out, a purchase that never answers gives up, a note goes.
function Arsenal.tick(self)
	local now = os.clock()
	local again = false
	if self._confirm ~= nil and now > self._confirm_until then
		self._confirm = nil
		again = true
	end
	local p = self._pending
	if p ~= nil and p.phase ~= "prompt" and now - p.since > Arsenal.WAIT_S then
		self._pending = nil
		self:_say("Still waiting on Roblox. If you paid, it's safe and will arrive soon.", UITheme.TEXT_2)
		again = true
	end
	if self._note ~= nil and now >= self._note_until then
		self._note = nil
		again = true
	end
	if again then
		self:_refresh()
	end
end

-- ---------------------------------------------------------------------------------------------
-- Open / close / layout
-- ---------------------------------------------------------------------------------------------

--- `focus`: an item key to show (a locked unit pressed in a match); `from`: where it was opened from
--- ("title" / "match" / "locked" / "over" / "offer": the result screen's own offers), for the analytics.
function Arsenal.open(self, focus: string?, from: string?)
	self._focus = if focus ~= nil and Catalog.item(focus) ~= nil then focus else nil
	self._from = from or "title"
	self._confirm = nil
	self._note = nil
	local opening = false
	if not self.is_open then
		self.is_open = true
		table.clear(self._viewed)
		self:_report("arsenal_shop", self._from)
		opening = true
	end
	Prices.fetch()
	ArsenalDemo.preload()
	self._sel = Arsenal.pick(self:_inv(), self._focus)
	self._branch = branch_index(Catalog.item(self._sel).branch)
	self:apply_layout()
	if opening then
		Sheet.show(self)
	end
end

function Arsenal.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function Arsenal.apply_layout(self)
	local ctx = self.ctx
	local compact = ctx.compact
	-- (the tree and the item take the sheet's whole height: the tree scrolls)
	local m = Sheet.place(self, Arsenal.COLUMNS_W + 14 + Arsenal.DETAIL_W)
	self._columns = not compact and m.body_w >= Arsenal.COLUMNS_W + 14 + Arsenal.DETAIL_W
	local tree_w = if self._columns then Arsenal.COLUMNS_W elseif compact then math.min(Arsenal.TABS_W_PHONE, math.floor(m.body_w * 0.52)) else Arsenal.TABS_W
	-- (tabs: the two lanes share the width, less the scroll bar's)
	self._node_w = if self._columns then Arsenal.NODE_W else math.floor((tree_w - Arsenal.LANE_GAP - 8 - 2 * Arsenal.EDGE) / 2)
	local dw = m.body_w - tree_w - 14
	local dh = m.body_h
	self._sub:set_visible(m.body_w >= 560)
	self._detail_size = Vector2.new(dw, dh)
	self._list_host:set_min_size(Vector2.new(tree_w, 0))
	self._detail_host:set_min_size(Vector2.new(dw, 0))
	if self.is_open then
		if self._sel == nil then
			self._sel = Arsenal.pick(self:_inv(), self._focus)
		end
		self:_rebuild()
	end
end

return Arsenal
