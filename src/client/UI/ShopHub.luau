--!nonstrict
-- The shop (2026-11-08, the owner: "make the offers tab open up a full shop"): everything the game sells, in one sheet, with
-- a tab for each kind. FEATURED (the Founding Grant, the Sovereign's Charter, the first dispatch), SPOILS, STANDARDS and
-- the WAR COLLEGE's unlocks.
--
-- It sells nothing by itself. Each BUY calls the window that owns that purchase (StarterOffer, Locker, FlagShop, Arsenal,
-- GeneralOffer): Roblox's prompt, the wait for the server's word and what the player hears afterwards stay in one place, and
-- the shop only shows their state ("…" while one is on its way). What a tab shows follows the same rules as the title's
-- rows (ShopHub.offers): a product with no id, Spoils where the policy bars them, a Grant already taken, are not offered.
--
-- Signals: closed. UIRoot sets `ui` (itself) before the first open.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local HelpOverlay = require("./HelpOverlay")
local UICtx = require("./UICtx")
local Prices = require("./Prices")
local FlagShop = require("./FlagShop")
local Signal = UITheme.core("Signal")

local Products = UICtx.data("Products")
local ShopArt = if typeof(game) == "Instance"
	then require((game:GetService("ReplicatedStorage"):WaitForChild("Airfront") :: any):WaitForChild("Assets"):WaitForChild("ShopArt"))
	else (require :: any)("../../shared/Assets/ShopArt")
local Starter = UICtx.data("Starter")
local Catalog = UICtx.data("Arsenal")
local Cosmetics = UICtx.data("Cosmetics")
local ShopData = UICtx.data("Shop")
local Subscription = UICtx.data("Subscription")

local ShopHub = W.class(W.Control)

ShopHub.WIDTH = 900
ShopHub.GAP = 12
--- A card is at least this wide; the columns follow from the sheet's width.
ShopHub.CARD_MIN = 250
--- Kept clear on the content's right for the scroll bar (HelpOverlay.Scroll: 6 px, drawn over what it scrolls).
ShopHub.BAR_ROOM = 10
ShopHub.TABS = {
	{ key = "featured", name = "Featured" },
	{ key = "spoils", name = "Spoils" },
	{ key = "standards", name = "Standards" },
	{ key = "college", name = "War College" },
}

local function live(key: string): boolean
	local p = Products[key]
	return type(p) == "table" and (tonumber(p.id) or 0) ~= 0
end

--- The Founding Grant is on sale: one of its products exists (Studio: always, unless CTW_LIVE_SHOP).
local function grant_on_sale(): boolean
	if
		typeof(game) == "Instance"
		and game:GetService("RunService"):IsStudio()
		and workspace:GetAttribute("CTW_LIVE_SHOP") ~= true
	then
		return true
	end
	for _, f in Starter.FOUNDINGS do
		if live(f.product) then
			return true
		end
	end
	return false
end

--- What can really be bought here now, read from the session (the title's rows and the shop's tabs both ask this).
--- { grant, charter, holds, spoils, standards, college, any }
function ShopHub.offers(ctx: any): any
	local s = ctx.session
	local inv = if s ~= nil then s.inventory else nil
	local o = {}
	o.grant = inv ~= nil and type(inv.starter) == "table" and grant_on_sale()
	o.holds = s ~= nil and s.general == true
	o.charter = Subscription.id() ~= "" and inv ~= nil and (inv.charter_allowed == true or o.holds)
	-- (Spoils: only where the policy lets this player buy paid random items)
	o.spoils = inv ~= nil and inv.crates_allowed == true and (live("crate") or live("crate_first"))
	o.standards = FlagShop.on_sale()
	o.college = false
	for _, it in Catalog.ITEMS do
		if it.product ~= nil and live(it.product) then
			o.college = true
			break
		end
	end
	o.featured = o.grant or o.charter or o.spoils
	o.any = o.featured or o.spoils or o.standards or o.college
	return o
end

function ShopHub.new(c: any)
	local self = setmetatable({}, ShopHub.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	self.ui = nil :: any
	self._tab = "featured"
	self._sig = ""
	self._cols = 2
	self:_build()
	self:_connect(Prices.changed:Connect(function()
		if self.is_open then
			self:_rebuild()
		end
	end))
	self:set_process(true)
	return self
end

function ShopHub._build(self)
	local T = UITheme
	local v, head = Sheet.attach(self, "SHOP")
	self._head_note = T.label("", 12, 700, T.TEXT_2, 1)
	self._head_note.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._head_note)
	local tabs = T.hbox(6)
	self._chips = {}
	for _, t in ShopHub.TABS do
		local chip = T.button(t.name, "ChipButton", "", 32.0)
		chip.toggle_mode = true
		chip:set_font_size(12)
		chip.pressed:Connect(function()
			self.ctx:sfx("tab")
			self:show_tab(t.key)
		end)
		self._chips[t.key] = chip
		tabs:add_child(chip)
	end
	v:add_child(tabs)
	local scroll = HelpOverlay.Scroll.new()
	scroll.size_flags_vertical = W.EXPAND_FILL
	self._scroll = scroll
	v:add_child(scroll)
	-- (room on the right for the scroll bar, which is drawn over the content: the last column hid under it)
	local pad = W.Margin.new()
	pad:add_theme_constant_override("margin_right", ShopHub.BAR_ROOM)
	scroll:add_child(pad)
	self._content = T.vbox(14)
	pad:add_child(self._content)
end

function ShopHub.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	s.inventory_changed:Connect(function()
		if self.is_open then
			self:_rebuild()
		end
	end)
end

function ShopHub._inv(self): any
	local s = self.ctx.session
	return if s ~= nil and s.inventory ~= nil then s.inventory else { owned = {}, equipped = {}, unlocks = {} }
end

--- `tab`: open at that tab (default: the first with something in it).
function ShopHub.open(self, tab: string?)
	if self.is_open then
		return
	end
	self.is_open = true
	Prices.fetch()
	self:apply_layout()
	self:show_tab(tab or self:_first_tab())
	Sheet.show(self)
	local s = self.ctx.session
	if s ~= nil and type(s.report) == "function" then
		s:report("shop", "opened", tab or "button")
	end
end

function ShopHub.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function ShopHub._first_tab(self): string
	local o = ShopHub.offers(self.ctx)
	for _, t in ShopHub.TABS do
		if o[t.key] then
			return t.key
		end
	end
	return "featured"
end

function ShopHub.show_tab(self, key: string)
	local o = ShopHub.offers(self.ctx)
	if not o[key] then
		key = self:_first_tab()
	end
	self._tab = key
	for k, chip in self._chips do
		chip:set_visible(o[k] == true)
		chip:set_pressed_no_signal(k == key)
	end
	self:_rebuild()
	local sf = self._scroll.gui :: ScrollingFrame
	sf.CanvasPosition = Vector2.zero
end

-- ---------------------------------------------------------------------------------------------
-- Building blocks
-- ---------------------------------------------------------------------------------------------

local function card_panel(): any
	local T = UITheme
	local card = W.Panel.new()
	card:set_mouse_filter(W.MOUSE_IGNORE)
	card:add_theme_stylebox_override("panel", T.flat(T.FILL, T.R_MD, T.LINE, 1, 12.0, 12.0))
	card.size_flags_horizontal = W.EXPAND_FILL
	return card
end

--- A section's heading and its line.
function ShopHub._heading(self, title: string, line: string?)
	local T = UITheme
	local v = T.vbox(2)
	v:add_child(T.label(string.upper(title), 13, 800, T.TEXT, 1))
	if line ~= nil and line ~= "" then
		local l = T.label(line, 12, 500, T.TEXT_2)
		l:set_autowrap(true)
		l:set_min_size(Vector2.new(self._text_w, 0))
		v:add_child(l)
	end
	self._content:add_child(v)
end

--- Rows of `cols` cards: `make(i)` returns each card.
function ShopHub._grid(self, n: number, make: (number) -> any)
	local T = UITheme
	local cols = self._cols
	local i = 1
	while i <= n do
		local row = T.hbox(ShopHub.GAP)
		for c = 0, cols - 1 do
			if i + c <= n then
				local card = make(i + c)
				card:set_min_size(Vector2.new(self._card_w, 0))
				row:add_child(card)
			else
				-- (an empty cell keeps the last row's cards the same width)
				local pad = W.Control.new()
				pad:set_mouse_filter(W.MOUSE_IGNORE)
				pad:set_min_size(Vector2.new(self._card_w, 0))
				pad.size_flags_horizontal = W.EXPAND_FILL
				row:add_child(pad)
			end
		end
		self._content:add_child(row)
		i += cols
	end
end

--- A wrapped line inside a card.
function ShopHub._card_line(self, text: string, size: number?, color: any?): any
	local l = UITheme.label(text, size or 12, 500, color or UITheme.TEXT_2)
	l:set_autowrap(true)
	l:set_min_size(Vector2.new(self._card_w - 24, 0))
	return l
end

--- A BUY button: the price from Roblox, "…" while it isn't known or a purchase is on its way, or `done` once owned.
function ShopHub._buy_button(self, product: string, pending: boolean, done: string?, on_press: () -> ()): any
	local T = UITheme
	local b = T.button("", if done ~= nil then "GhostButton" else "PrimaryButton", "", 40.0)
	if done ~= nil then
		b:set_text(done)
		b:set_disabled(true)
	elseif pending then
		b:set_text("…")
		b:set_disabled(true)
	elseif not live(product) then
		b:set_text("…")
		b:set_disabled(true)
	else
		-- (2026-11-09, the owner: BUY sat grey for seconds. The set price shows at once and Roblox's replaces it when it
		-- comes; Roblox's own prompt always shows the true one)
		if not Prices.known(product) then
			Prices.want({ product }, true)
		end
		b:set_icon("robux")
		b:set_text(tostring(Prices.robux(product)))
	end
	b.pressed:Connect(on_press)
	return b
end

--- Leave the shop for window `open` (another sheet takes its place).
function ShopHub._go(self, open: () -> ())
	self:close()
	open()
end

-- ---------------------------------------------------------------------------------------------
-- The tabs
-- ---------------------------------------------------------------------------------------------

function ShopHub._rebuild(self)
	if not self.is_open then
		return
	end
	for _, c in table.clone(self._content.children) do
		self._content:remove_child(c)
		c:queue_free()
	end
	local o = ShopHub.offers(self.ctx)
	local tab = self._tab
	if tab == "featured" then
		self:_featured(o)
	elseif tab == "spoils" then
		self:_spoils(o)
	elseif tab == "standards" then
		self:_standards()
	elseif tab == "college" then
		self:_college()
	end
	local stars = tonumber(self:_inv().stars)
	self._head_note:set_text(if stars ~= nil then UICtx.commas(stars) .. " RENOWN" else "")
	self._sig = self:_signature()
	self:apply_layout()
end

function ShopHub._featured(self, o: any)
	local T = UITheme
	local ui = self.ui
	if o.grant and ui.starter ~= nil then
		local offer = self:_inv().starter
		local open = if type(offer) == "table" and type(offer.foundings) == "table" then offer.foundings else {}
		local list = {}
		for _, f in Starter.FOUNDINGS do
			if open[f.key] == true then
				table.insert(list, f)
			end
		end
		if #list > 0 then
			self:_heading("Founding Grant", "Once for each ruler. What is your nation founded on? Choose one.")
			local p = ui.starter._pending
			self:_grid(#list, function(i: number): any
				local f = list[i]
				local card = card_panel()
				local v = T.vbox(8)
				card:add_child(v)
				local top = T.hbox(8)
				local icon = T.icon_rect(f.icon, 20.0, T.TEXT)
				icon.size_flags_vertical = W.SHRINK_CENTER
				top:add_child(icon)
				top:add_child(T.label(f.title, 15, 800, T.TEXT))
				v:add_child(top)
				v:add_child(self:_card_line(f.line))
				for _, k in f.items do
					local it = Catalog.item(k)
					if it ~= nil then
						local r = T.hbox(8)
						local ic = T.icon_rect(it.icon, 16.0, T.TEXT_2)
						ic.size_flags_vertical = W.SHRINK_CENTER
						r:add_child(ic)
						r:add_child(T.label(it.title, 13, 700, T.TEXT))
						v:add_child(r)
					end
				end
				if f.renown > 0 then
					v:add_child(T.label(string.format("+%s Renown", UICtx.commas(f.renown)), 13, 700, T.TEXT))
				end
				v:add_child(self:_buy_button(f.product, p ~= nil and p.key == f.key, nil, function()
					ui.starter:_buy(f)
					self:_rebuild()
				end))
				return card
			end)
		end
	end
	if o.charter then
		self:_heading("Sovereign's Charter", "A monthly subscription, renewed and cancelled through Roblox.")
		self:_grid(1, function(): any
			local card = card_panel()
			local v = T.vbox(8)
			card:add_child(v)
			local top = T.hbox(8)
			local icon = T.icon_rect("charter", 20.0, T.TEXT)
			icon.size_flags_vertical = W.SHRINK_CENTER
			top:add_child(icon)
			top:add_child(T.label(Subscription.NAME, 15, 800, T.TEXT))
			v:add_child(top)
			v:add_child(self:_card_line(string.format("%s Renown for each day it is paid.", UICtx.commas(Subscription.DAILY_RENOWN)), 13, T.TEXT))
			v:add_child(self:_card_line(Subscription.STIPEND_LINE .. ".", 13, T.TEXT))
			v:add_child(self:_card_line("A Pattern of its own, yours to keep.", 13, T.TEXT))
			local b = T.button(if o.holds then "YOU HOLD THE CHARTER" else "SEE THE CHARTER", if o.holds then "GhostButton" else "PrimaryButton", "", 40.0)
			b.pressed:Connect(function()
				self:_go(function()
					ui:open_general("shop")
				end)
			end)
			v:add_child(b)
			return card
		end)
	end
	if o.spoils then
		local inv = self:_inv()
		if (inv.crates_bought or 0) <= 0 and live("crate_first") then
			self:_heading("Your first dispatch", "The first dispatch of Spoils costs less than the rest. Its odds are shown before you buy.")
			self:_spoils_rows(true)
		end
	end
end

--- The Spoils packs (only_first: just the first dispatch, for FEATURED).
function ShopHub._spoils_rows(self, only_first: boolean?)
	local T = UITheme
	local ui = self.ui
	local locker = ui.locker
	if locker == nil then
		return
	end
	local held = locker:_crates()
	local pending = locker._pending ~= nil
	local inv = self:_inv()
	local packs = {}
	local first = (inv.crates_bought or 0) <= 0 and live("crate_first")
	table.insert(packs, { label = "ONE DISPATCH", product = if first then "crate_first" else "crate", pack = nil, art = "spoils_one" })
	if not only_first then
		if live("crate_satchel") then
			table.insert(packs, { label = "A SATCHEL OF 4", product = "crate_satchel", pack = Products.crate_satchel, art = "spoils_satchel" })
		end
		if live("crate_courier") then
			table.insert(packs, { label = "A COURIER'S 9", product = "crate_courier", pack = Products.crate_courier, art = "spoils_courier" })
		end
	end
	local card = card_panel()
	card:set_min_size(Vector2.new(self._text_w, 0))
	local v = T.vbox(10)
	card:add_child(v)
	if held > 0 then
		local open = T.button(string.format("OPEN IN BANNERS  ·  %d WAITING", held), "PrimaryButton", "", 44.0)
		open.pressed:Connect(function()
			self:_go(function()
				ui:open_locker()
				ui:locker_tab(3)
			end)
		end)
		v:add_child(open)
	end
	for _, pk in packs do
		local row = T.hbox(10)
		-- its picture (Assets/ShopArt: made 2026-11-08, Roblox shop style)
		local art = ShopArt[pk.art]
		if art ~= nil then
			local img = Instance.new("ImageLabel")
			img.Name = "Art"
			img.BackgroundTransparency = 1
			img.BorderSizePixel = 0
			img.ScaleType = Enum.ScaleType.Fit
			T.set_image(img, art)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = img
			local pic = W.wrap(img)
			pic:set_mouse_filter(W.MOUSE_IGNORE)
			pic:set_min_size(Vector2.new(72, 72))
			pic.size_flags_vertical = W.SHRINK_CENTER
			row:add_child(pic)
		end
		local name = T.label(pk.label, 14, 800, T.TEXT)
		name.size_flags_horizontal = W.EXPAND_FILL
		name.size_flags_vertical = W.SHRINK_CENTER
		row:add_child(name)
		local b = self:_buy_button(pk.product, pending, nil, function()
			if held > 0 then
				-- (a dispatch already waits: Banners opens it first, as its own button does)
				self:_go(function()
					ui:open_locker()
					ui:locker_tab(3)
				end)
				return
			end
			locker:_buy_pressed(pk.pack)
			self:_rebuild()
		end)
		b:set_min_size(Vector2.new(140, 40))
		row:add_child(b)
		v:add_child(row)
	end
	local odds = T.button("SEE THE ODDS", "GhostButton", "", 36.0)
	odds.pressed:Connect(function()
		if ui.crate_odds ~= nil then
			ui.crate_odds:open(inv.owned)
		end
	end)
	v:add_child(odds)
	self._content:add_child(card)
end

function ShopHub._spoils(self, _o: any)
	self:_heading(
		"Spoils",
		string.format(
			"A sealed dispatch from the front: a Pattern or a Standard you don't own yet, never a repeat. If nothing is left to find, it pays %s Renown instead.",
			UICtx.commas(Cosmetics.SPOILS_RENOWN)
		)
	)
	self:_spoils_rows(false)
end

function ShopHub._standards(self)
	local T = UITheme
	local ui = self.ui
	local fs = ui.flag_shop
	if fs == nil then
		return
	end
	local inv = self:_inv()
	local p = fs._pending
	-- (the Standards' prices are asked for only where they are shown: Prices.fetch leaves them out)
	local want = {}
	for _, age in ShopData.ages() do
		table.insert(want, "shopset_" .. age.id)
		for _, k in age.keys do
			table.insert(want, "shop_" .. k)
		end
	end
	Prices.want(want)
	for _, age in ShopData.ages() do
		local keys = {}
		for _, k in age.keys do
			if live("shop_" .. k) then
				table.insert(keys, k)
			end
		end
		if #keys > 0 then
			self:_heading(age.name, age.line)
			-- the age's set, while some of it is still to buy
			local bundle = Products["shopset_" .. age.id]
			local owned_n = 0
			for _, k in age.keys do
				if inv.owned[ShopData.item_id(k)] == true then
					owned_n += 1
				end
			end
			if type(bundle) == "table" and (tonumber(bundle.id) or 0) ~= 0 and owned_n < #age.keys then
				local row = T.hbox(10)
				local l = T.label(string.format("The whole %s set: %d Standards", age.name, #age.keys), 13, 700, T.TEXT)
				l.size_flags_horizontal = W.EXPAND_FILL
				l.size_flags_vertical = W.SHRINK_CENTER
				row:add_child(l)
				local b = self:_buy_button("shopset_" .. age.id, p ~= nil and p.set == age.id, nil, function()
					fs:_pressed_set(age.id)
					self:_rebuild()
				end)
				b:set_min_size(Vector2.new(140, 40))
				row:add_child(b)
				self._content:add_child(row)
			end
			self:_grid(#keys, function(i: number): any
				local key = keys[i]
				local f = ShopData.flag(key)
				local it = Cosmetics.item(ShopData.item_id(key))
				local card = card_panel()
				local h = T.hbox(12)
				card:add_child(h)
				-- the Standard itself
				local img = Instance.new("ImageLabel")
				img.Name = "Flag"
				img.BackgroundTransparency = 1
				img.BorderSizePixel = 0
				img.ScaleType = Enum.ScaleType.Fit
				if it ~= nil then
					local image, x, y, w, hh = Cosmetics.flag_big(it)
					T.set_image(img, image)
					img.ImageRectOffset = Vector2.new(x, y)
					img.ImageRectSize = Vector2.new(w, hh)
				end
				local flag = W.wrap(img)
				flag:set_mouse_filter(W.MOUSE_IGNORE)
				flag:set_min_size(Vector2.new(78, 52))
				flag.size_flags_vertical = W.SHRINK_CENTER
				h:add_child(flag)
				local v = T.vbox(4)
				v.size_flags_horizontal = W.EXPAND_FILL
				h:add_child(v)
				local rar = Cosmetics.rarity(f.rarity)
				local name = T.label(f.name, 13, 800, T.TEXT)
				name:set_autowrap(true)
				name:set_min_size(Vector2.new(self._card_w - 24 - 78 - 12, 0))
				v:add_child(name)
				v:add_child(T.label(string.upper(rar.name), 11, 700, T.rarity_color(rar), 1))
				local owned = it ~= nil and inv.owned[it.id] == true
				local flying = it ~= nil and inv.equipped.flag == it.id
				local b
				if owned then
					b = T.button(if flying then "FLYING" else "RAISE", if flying then "GhostButton" else "PrimaryButton", "", 36.0)
					b:set_disabled(flying)
					b.pressed:Connect(function()
						fs:_pressed(key)
					end)
				else
					b = self:_buy_button("shop_" .. key, p ~= nil and p.key == key, nil, function()
						fs:_pressed(key)
						self:_rebuild()
					end)
				end
				v:add_child(b)
				return card
			end)
		end
	end
end

function ShopHub._college(self)
	local T = UITheme
	local ui = self.ui
	local ar = ui.arsenal
	if ar == nil then
		return
	end
	local inv = self:_inv()
	local unlocks = inv.unlocks or {}
	local p = ar._pending
	for _, br in Catalog.BRANCHES do
		local list = {}
		for _, it in Catalog.ITEMS do
			if it.branch == br.key and it.product ~= nil and live(it.product) then
				table.insert(list, it)
			end
		end
		if #list > 0 then
			self:_heading(br.name, br.line .. " Each is also taught for Renown in the War College.")
			self:_grid(#list, function(i: number): any
				local it = list[i]
				local card = card_panel()
				local v = T.vbox(8)
				card:add_child(v)
				local top = T.hbox(8)
				local icon = T.icon_rect(it.icon, 20.0, T.TEXT)
				icon.size_flags_vertical = W.SHRINK_CENTER
				top:add_child(icon)
				top:add_child(T.label(it.title, 15, 800, T.TEXT))
				v:add_child(top)
				v:add_child(self:_card_line(it.plain or it.tagline or ""))
				local taught = unlocks[it.key] == true
				local row = T.hbox(8)
				local b = self:_buy_button(it.product, p ~= nil and p.key == it.key, if taught then "TAUGHT" else nil, function()
					ar:_robux_pressed(it)
					self:_rebuild()
				end)
				b.size_flags_horizontal = W.EXPAND_FILL
				row:add_child(b)
				local more = T.button("DETAILS", "GhostButton", "", 40.0)
				more.pressed:Connect(function()
					self:_go(function()
						ui:open_arsenal(it.key, "shop")
					end)
				end)
				row:add_child(more)
				v:add_child(row)
				return card
			end)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Upkeep
-- ---------------------------------------------------------------------------------------------

--- What the cards show depends on: each window's purchase on its way, the dispatches waiting. A change rebuilds.
function ShopHub._signature(self): string
	local ui = self.ui
	local function pend(w: any): string
		local p = w ~= nil and w._pending or nil
		return if p == nil then "-" else tostring(p.key or p.set or p.phase)
	end
	local held = if ui.locker ~= nil then ui.locker:_crates() else 0
	return table.concat({ pend(ui.starter), pend(ui.locker), pend(ui.flag_shop), pend(ui.arsenal), tostring(held) }, "|")
end

function ShopHub._process(self, _dt: number)
	if not self.is_open then
		return
	end
	local now = os.clock()
	if now - (self._polled or 0) < 0.4 then
		return
	end
	self._polled = now
	-- (the scroll area gets its size in the layout pass after a resize or the sheet's opening: the cards follow it)
	if self._scroll.size.X ~= self._laid_w then
		self:apply_layout()
	end
	if self:_signature() ~= self._sig then
		self:_rebuild()
	end
end

function ShopHub.apply_layout(self)
	local m = Sheet.place(self, ShopHub.WIDTH)
	-- The sheet's body sets the width; the scroll area's own, once it has one, only narrows it (its bar: the cards ran
	-- past the edge). Never the other way: content laid out too wide holds the scroll area open at that width, so a
	-- width read from it alone never shrank back (a phone kept a desktop's cards, 2026-11-08).
	local sw = self._scroll.size.X
	self._laid_w = sw
	local body = math.min(m.body_w, ShopHub.WIDTH)
	local w = (if sw > 0 then math.min(sw, body) else body) - ShopHub.BAR_ROOM
	self._text_w = w
	local cols = math.max(1, math.floor((w + ShopHub.GAP) / (ShopHub.CARD_MIN + ShopHub.GAP)))
	self._cols = math.min(cols, 3)
	local card_w = math.floor((w - (self._cols - 1) * ShopHub.GAP) / self._cols)
	-- a width that changed once the scroll area had its size: the cards are made again at the new one
	if self._card_w ~= nil and self._card_w ~= card_w and self.is_open and not self._relaying then
		self._card_w = card_w
		self._relaying = true
		self:_rebuild()
		self._relaying = false
		return
	end
	self._card_w = card_w
end

return ShopHub
