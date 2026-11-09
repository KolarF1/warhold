--!nonstrict
-- The Founding Grant's sheet (Data/Starter; UI/Sheet): choose what your nation is founded on. Three cards, one per branch of
-- the War College, each with what it unlocks, its own BUY button and the price Roblox gives. No clock, no struck-through
-- price, and it never opens by itself: it opens from the title's row, stays there until taken, and says plainly what the
-- choice is worth.
-- A BUY opens Roblox's prompt for that founding's own product; the server's receipt unlocks the items (server/Purchases),
-- the inventory says so and the sheet closes with the unlock sound.
--
-- Signals: closed.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local HelpOverlay = require("./HelpOverlay")
local UICtx = require("./UICtx")
local Signal = UITheme.core("Signal")
local Prices = require("./Prices")

local IS_ROBLOX = typeof(game) == "Instance"
local Starter = UICtx.data("Starter")
local Catalog = UICtx.data("Arsenal")
local Products = UICtx.data("Products")

local StarterOffer = W.class(W.Control)

--- The sheet's body on a desktop; a card's width grows from what is left.
StarterOffer.WIDTH = 700
StarterOffer.GAP = 12
--- A purchase whose unlock never shows up gives up waiting after this long (it is saved on the server).
StarterOffer.WAIT_S = 30.0

function StarterOffer.new(c: any)
	local self = setmetatable({}, StarterOffer.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	--- a purchase on its way: { key, product, phase = "prompt" | "granting", since }
	self._pending = nil :: any
	self:_build()
	self:_connect(Prices.changed:Connect(function()
		if self.is_open then
			self:refresh()
		end
	end))
	if IS_ROBLOX then
		game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function(_u, product_id, purchased)
			self:_on_prompt_done(product_id, purchased)
		end)
	end
	self:set_process(true)
	return self
end

function StarterOffer._build(self)
	local T = UITheme
	local v, head = Sheet.attach(self, "FOUNDING GRANT")
	self._tag = T.label("ONCE FOR EACH RULER", 12, 800, T.TEXT_2, 1)
	self._tag.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._tag)
	self._sub = T.label("What is your nation founded on? Choose one.", 14, 600, T.TEXT)
	v:add_child(self._sub)
	local scroll = HelpOverlay.Scroll.new()
	scroll.size_flags_vertical = W.EXPAND_FILL
	v:add_child(scroll)
	local row = T.hbox(StarterOffer.GAP)
	scroll:add_child(row)
	self._cards = {}
	for _, f in Starter.FOUNDINGS do
		self._cards[f.key] = self:_card(row, f)
	end
	self._foot = T.label("", 12, 500, T.TEXT_2)
	self._foot:set_autowrap(true)
	v:add_child(self._foot)
end

--- One founding: its mark and name, what it holds, its BUY.
function StarterOffer._card(self, parent: any, f: any): any
	local T = UITheme
	local card = W.Panel.new()
	card:set_mouse_filter(W.MOUSE_IGNORE)
	card:add_theme_stylebox_override("panel", T.flat(T.FILL, T.R_MD, T.LINE, 1, 12.0, 12.0))
	card.size_flags_horizontal = W.EXPAND_FILL
	local v = T.vbox(8)
	card:add_child(v)
	local top = T.hbox(8)
	local icon = T.icon_rect(f.icon, 20.0, T.TEXT)
	icon.size_flags_vertical = W.SHRINK_CENTER
	top:add_child(icon)
	top:add_child(T.label(f.title, 15, 800, T.TEXT))
	v:add_child(top)
	local line = T.label(f.line, 12, 500, T.TEXT_2)
	line:set_autowrap(true)
	v:add_child(line)
	local lines = { line }
	for _, k in f.items do
		local it = Catalog.item(k)
		local r = T.hbox(8)
		local ic = T.icon_rect(it.icon, 16.0, T.TEXT_2)
		ic.size_flags_vertical = W.SHRINK_CENTER
		r:add_child(ic)
		local name = T.label(it.title, 13, 700, T.TEXT)
		name.size_flags_horizontal = W.EXPAND_FILL
		r:add_child(name)
		v:add_child(r)
	end
	local gift = T.label(if f.renown > 0 then string.format("+%s Renown", UICtx.commas(f.renown)) else "", 13, 700, T.TEXT)
	gift:set_visible(f.renown > 0)
	v:add_child(gift)
	local buy = T.button("", "PrimaryButton", "robux", 44.0)
	buy.pressed:Connect(function()
		self:_buy(f)
	end)
	v:add_child(buy)
	parent:add_child(card)
	return { card = card, buy = buy, lines = lines, f = f }
end

function StarterOffer.bind(self, s: any)
	if s == nil or self._bound == s then
		return
	end
	self._bound = s
	s.inventory_changed:Connect(function()
		self:_on_inventory()
	end)
end

function StarterOffer._offer(self): any
	local s = self.ctx.session
	local inv = if s ~= nil then s.inventory else nil
	return if inv ~= nil then inv.starter else nil
end

function StarterOffer._report(self, kind: string, a: any?, b: any?)
	local s = self.ctx.session
	if s ~= nil and type(s.report) == "function" then
		s:report(kind, a, b)
	end
end

--- `from`: "button" (the title's row).
function StarterOffer.open(self, from: string?)
	if self.is_open then
		return
	end
	self.is_open = true
	self._pending = nil
	Prices.fetch()
	self:apply_layout()
	self:refresh()
	Sheet.show(self)
	self:_report("starter", "opened", from or "button")
end

function StarterOffer.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

--- Prices, which foundings are open, and the buttons' state.
function StarterOffer.refresh(self)
	local o = self:_offer()
	local open = if type(o) == "table" and type(o.foundings) == "table" then o.foundings else {}
	local p = self._pending
	for key, c in self._cards do
		local product = Products[c.f.product]
		local on = open[key] == true
		c.card:set_visible(on)
		local live = type(product) == "table" and (tonumber(product.id) or 0) ~= 0
		-- (a real product: Roblox's number or nothing)
		-- (the set price at once, Roblox's when it comes: Prices; 2026-11-09)
		local ready = live
		if p ~= nil and p.key == key then
			c.buy:set_icon("")
			c.buy:set_text(if p.phase == "granting" then "FOUNDING…" else "…")
		elseif not ready then
			if live then
				Prices.want({ c.f.product }, true)
			end
			c.buy:set_icon("")
			c.buy:set_text("…")
		else
			c.buy:set_icon("robux")
			c.buy:set_text(tostring(Prices.robux(c.f.product)))
		end
		c.buy:set_disabled(p ~= nil or not ready)
	end
	self._foot:set_text(
		string.format(
			"Each is worth %s Renown at War College prices. What the College has already taught you comes back as Renown.",
			UICtx.commas(Starter.worth(Starter.FOUNDINGS[1]))
		)
	)
	if self.is_open and self.visible then
		self:apply_layout()
	end
end

function StarterOffer._buy(self, f: any)
	if self._pending ~= nil then
		return
	end
	local product = Products[f.product]
	local id = if type(product) == "table" then (tonumber(product.id) or 0) else 0
	self:_report("starter", "clicked", f.key)
	if id == 0 or not IS_ROBLOX then
		self.ctx:sfx("deny", -4.0)
		return
	end
	self._pending = { key = f.key, product = id, phase = "prompt", since = os.clock() }
	local ok = pcall(function()
		game:GetService("MarketplaceService"):PromptProductPurchase(game:GetService("Players").LocalPlayer, id)
	end)
	if not ok then
		self._pending = nil
	end
	self:refresh()
end

function StarterOffer._on_prompt_done(self, product_id: number, purchased: boolean)
	local p = self._pending
	if p == nil or product_id ~= p.product then
		return
	end
	if not purchased then
		if p.phase == "prompt" then
			self._pending = nil
			self:refresh()
		end
		return
	end
	-- bought: the server's receipt unlocks the items, and the inventory says so
	p.phase = "granting"
	p.since = os.clock()
	self:refresh()
	self:_on_inventory()
end

--- The inventory moved: a purchase that landed ends here (the receipt can come before Roblox's prompt says it closed).
function StarterOffer._on_inventory(self)
	local p = self._pending
	if p ~= nil and self:_offer() == false then
		self._pending = nil
		--- (UIRoot: the items' own "is yours" toasts give way to this one)
		self.bought_at = os.clock()
		self.ctx:sfx("unlock")
		local f = Starter.founding(p.key)
		if self.ui_notice ~= nil and f ~= nil then
			local names = {}
			for _, k in f.items do
				table.insert(names, Catalog.item(k).title)
			end
			self.ui_notice(string.format("%s. %s are yours.", f.title, table.concat(names, " and ")))
		end
		self:close()
		return
	end
	if self.is_open then
		local o = self:_offer()
		if (o == false or o == nil) and p == nil then
			self:close() -- (taken elsewhere)
			return
		end
		self:refresh()
	end
end

function StarterOffer._process(self, _dt: number)
	if not self.is_open then
		return
	end
	local p = self._pending
	if p ~= nil and p.phase == "granting" and os.clock() - p.since > StarterOffer.WAIT_S then
		self._pending = nil
		if self.ui_notice ~= nil then
			self.ui_notice("Paid. Your Founding Grant is on its way.")
		end
		self:close()
	end
end

function StarterOffer.apply_layout(self)
	local m = Sheet.place(self, StarterOffer.WIDTH)
	-- (a wrapped label measures against its width)
	local shown = 0
	for _, c in self._cards do
		if c.card.visible then
			shown += 1
		end
	end
	local n = math.max(shown, 1)
	local w = math.floor((m.body_w - 16 - (n - 1) * StarterOffer.GAP) / n) - 24
	for _, c in self._cards do
		c.card:set_min_size(Vector2.new(w + 24, 0))
		for _, l in c.lines do
			l:set_min_size(Vector2.new(w, 0))
		end
	end
	self._foot:set_min_size(Vector2.new(m.body_w, 0))
end

return StarterOffer
