--!nonstrict
-- The Sovereign's Charter's sheet (UI/Sheet; Data/Subscription): one column, read like a charter: what it grants, article by
-- article, and at its foot the price and the signing (SIGN THE CHARTER), which opens Roblox's own prompt
-- (MarketplaceService:PromptSubscriptionPurchase). Roblox
-- bills and renews it; the server hears of it (server/General, OP.GENERAL) and the sheet then says
-- the player holds it. Opened from the title's Sovereign's Charter row, which only shows to a player the policy lets buy it
-- (inventory.charter_allowed, IsEligibleToPurchaseSubscription); signing checks it again. Everything it says is exact:
-- the sums come from Data/Subscription, and the price is Roblox's for this player or nothing (signing waits for it).
--
--   GeneralOffer.new(ctx)   :bind(session)   :open(from)   :close()   .closed (Signal)   .is_open
local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local UICtx = require("./UICtx")
local Locker = require("./Locker")
local HelpOverlay = require("./HelpOverlay")
local Signal = UITheme.core("Signal")

local IS_ROBLOX = typeof(game) == "Instance"
local Subscription = UICtx.data("Subscription")
local Cosmetics = UICtx.data("Cosmetics")

local GeneralOffer = W.class(W.Control)

--- The sheet's body, desktop: one column.
GeneralOffer.WIDTH = 460
--- What a war's pay is shown on (the bonus as an amount, not a percentage).
GeneralOffer.EXAMPLE_PAY = 1000
--- After a try to subscribe, the server's word is waited for this long before the button comes back.
GeneralOffer.WAIT_S = 30.0

function GeneralOffer.new(c: any)
	local self = setmetatable({}, GeneralOffer.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	--- after Roblox's prompt closed with a try to buy: os.clock() then (the server's word is due)
	self._waiting = nil :: number?
	--- Roblox's price for this player: { robux = n } or { text = "..." } (nil: not known yet)
	self._cost = nil
	self._price_asked = false
	self:_build()
	if IS_ROBLOX then
		pcall(function()
			game:GetService("MarketplaceService").PromptSubscriptionPurchaseFinished:Connect(function(_u, sid, tried)
				if sid == Subscription.id() then
					self:_on_prompt_done(tried == true)
				end
			end)
		end)
	end
	self:set_process(true)
	return self
end

function GeneralOffer._build(self)
	local T = UITheme
	local v, head = Sheet.attach(self, "SOVEREIGN'S CHARTER")
	self._v = v
	self._cap = T.label("", 13, 600, T.TEXT_2)
	self._cap.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._cap)
	local scroll = HelpOverlay.Scroll.new()
	scroll.size_flags_vertical = W.EXPAND_FILL
	v:add_child(scroll)
	-- the document, top to foot: what it grants, then the signing
	local doc = T.vbox(12)
	doc.size_flags_horizontal = W.EXPAND_FILL
	scroll:add_child(doc)
	self._sub = T.label("Granted to the holder, for as long as it runs:", 14, 500, T.TEXT)
	self._sub:set_autowrap(true)
	doc:add_child(self._sub)
	self._perk_daily = self:_perk(doc, "I.")
	self._perk_stars = self:_perk(doc, "II.")
	self._perk_skin = self:_perk(doc, "III.")
	local sw = W.Control.new()
	sw:set_min_size(Vector2.new(44, 44))
	sw:set_mouse_filter(W.MOUSE_IGNORE)
	if IS_ROBLOX then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, T.R_SM)
		corner.Parent = img
		img.Parent = sw.gui
		self._skin_img = img
	end
	self._perk_skin.row:add_child(sw)
	doc:add_child(T.hdivider())
	-- the price, in plain words
	local price = T.hbox(4)
	self._price = T.label("", 20, 800, T.TEXT)
	self._price.size_flags_vertical = W.SHRINK_CENTER
	price:add_child(self._price)
	self._price_unit = T.label("", 13, 600, T.TEXT_2)
	self._price_unit.size_flags_vertical = W.SHRINK_CENTER
	price:add_child(self._price_unit)
	self._price_row = price
	doc:add_child(price)
	self._buy = T.button("SIGN THE CHARTER", "PrimaryButton", "", 48.0)
	self._buy.pressed:Connect(function()
		self:_subscribe()
	end)
	doc:add_child(self._buy)
	self._note = T.label("", 12, 500, T.TEXT_3)
	self._note:set_autowrap(true)
	doc:add_child(self._note)
end

--- An article: its number, a bold line and a muted one under it.
function GeneralOffer._perk(_self, parent: any, number: string): any
	local row = UITheme.hbox(12)
	local n = UITheme.label(number, 15, 800, UITheme.TEXT_2)
	n:set_min_size(Vector2.new(28, 0))
	n.size_flags_vertical = W.SHRINK_BEGIN
	row:add_child(n)
	local col = UITheme.vbox(2)
	col.size_flags_horizontal = W.EXPAND_FILL
	col.size_flags_vertical = W.SHRINK_CENTER
	local head = UITheme.label("", 15, 700, UITheme.TEXT)
	local body = UITheme.label("", 13, 500, UITheme.TEXT_2)
	body:set_autowrap(true)
	col:add_child(head)
	col:add_child(body)
	row:add_child(col)
	parent:add_child(row)
	return { head = head, body = body, row = row }
end

function GeneralOffer.bind(self, s: any)
	self.session = s
	if s ~= nil and s.general_changed ~= nil then
		self:_connect(s.general_changed:Connect(function(on: boolean)
			if on then
				self._waiting = nil
			end
			if self.is_open then
				self:refresh()
			end
		end))
	end
end

function GeneralOffer._report(self, kind: string, a: any?)
	local s = self.ctx.session
	if s ~= nil and type(s.report) == "function" then
		s:report("general", kind, a)
	end
end

--- Subscribed, as the server last said.
function GeneralOffer.subscribed(self): boolean
	local s = self.ctx.session
	return s ~= nil and s.general == true
end

--- Roblox's policy lets this player buy a subscription (a player it never answered for: no).
function GeneralOffer.eligible(self): boolean
	local s = self.ctx.session
	local inv = if s ~= nil then s.inventory else nil
	return type(inv) == "table" and inv.charter_allowed == true
end

--- Roblox's price for this player (MarketplaceService:GetSubscriptionProductInfoAsync), asked once.
function GeneralOffer._fetch_price(self)
	if self._price_asked or not IS_ROBLOX or Subscription.id() == "" then
		return
	end
	self._price_asked = true
	task.spawn(function()
		local ok, info = pcall(function()
			return (game:GetService("MarketplaceService") :: any):GetSubscriptionProductInfoAsync(Subscription.id())
		end)
		if ok and type(info) == "table" then
			local robux = tonumber(info.PriceInRobux)
			if robux ~= nil and robux > 0 then
				self._cost = { robux = robux }
			elseif type(info.DisplayPrice) == "string" and info.DisplayPrice ~= "" then
				self._cost = { text = info.DisplayPrice }
			end
			if self.is_open then
				self:refresh()
			end
		else
			self._price_asked = false -- (asked again next time it opens)
		end
	end)
end

function GeneralOffer.refresh(self)
	local daily = self._perk_daily
	daily.head:set_text(string.format("%s Renown a day", UICtx.commas(Subscription.DAILY_RENOWN)))
	daily.body:set_text("For every day you hold it, whether you play or not. Days you miss are paid when you come back. The same sum for every holder.")
	self._perk_stars.head:set_text(Subscription.STIPEND_LINE)
	self._perk_stars.body:set_text("A flat sum, on its own line of a war's pay. A campaign pays its share of it, as it does of everything else.")
	local skin = Cosmetics.item(Subscription.skin_for(os.time()))
	self._perk_skin.head:set_text("The Charter's Pattern")
	self._perk_skin.body:set_text((if skin ~= nil then skin.name .. ". " else "") .. "It stays yours if you stop.")
	if self._skin_img ~= nil and skin ~= nil then
		Locker.show_item(self._skin_img, skin)
	end
	local on = self:subscribed()
	local p = self._cost
	self._price:set_text(if p == nil then "" elseif p.text ~= nil then p.text else tostring(p.robux))
	self._price_unit:set_text(if p == nil then "" elseif p.text ~= nil then "a month" else "Robux a month")
	self._cap:set_text(if p == nil then "" elseif p.text ~= nil then p.text .. " a month" else string.format("%d a month", p.robux))
	self._price_row:set_visible(not on and p ~= nil)
	if on then
		self._buy:set_text("CHARTER HELD")
		self._buy:set_disabled(true)
		self._note:set_text("A subscription: it renews each month until you cancel in your Roblox settings. Days already paid for stay paid.")
	elseif not self:eligible() then
		self._buy:set_text("SIGN THE CHARTER")
		self._buy:set_disabled(true)
		self._note:set_text("The Charter isn't open to this account.")
	elseif self._waiting ~= nil then
		self._buy:set_text("ASKING ROBLOX…")
		self._buy:set_disabled(true)
		self._note:set_text("")
	else
		self._buy:set_text("SIGN THE CHARTER")
		self._buy:set_disabled(Subscription.id() == "" or p == nil)
		self._note:set_text(if p == nil then "Asking Roblox for your price." else "A subscription: it renews each month until you cancel in your Roblox settings.")
	end
	if self.is_open and self.visible then
		self:apply_layout() -- (the lines' heights change with what they say)
	end
end

function GeneralOffer._subscribe(self)
	if self:subscribed() or self._waiting ~= nil or Subscription.id() == "" or not IS_ROBLOX then
		return
	end
	if not self:eligible() or self._cost == nil then
		return
	end
	self:_report("clicked")
	local ok = pcall(function()
		(game:GetService("MarketplaceService") :: any):PromptSubscriptionPurchase(
			game:GetService("Players").LocalPlayer,
			Subscription.id()
		)
	end)
	if not ok then
		self._note:set_text("Roblox isn't taking signatures just now. Try again soon.")
	end
end

--- Roblox's prompt closed; `tried`: the player went ahead (the server's word follows: OP.GENERAL).
function GeneralOffer._on_prompt_done(self, tried: boolean)
	if not tried or self:subscribed() then
		return
	end
	self:_report("prompt_done")
	self._waiting = os.clock()
	if self.is_open then
		self:refresh()
	end
end

function GeneralOffer._process(self, _dt: number)
	if self._waiting ~= nil and os.clock() - self._waiting > GeneralOffer.WAIT_S then
		self._waiting = nil
		if self.is_open then
			self:refresh()
		end
	end
end

function GeneralOffer.open(self, from: string?)
	if self.is_open then
		return
	end
	self.is_open = true
	self:_report("opened", from or "button")
	self:_fetch_price()
	self:refresh()
	self:apply_layout()
	Sheet.show(self)
end

function GeneralOffer.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function GeneralOffer.apply_layout(self)
	local m = Sheet.place(self, GeneralOffer.WIDTH)
	-- (wrapped labels measure against their width; a phone's sheet is wide, so the document keeps a reading measure)
	local w = math.min(m.body_w, GeneralOffer.WIDTH) - 14
	self._sub:set_min_size(Vector2.new(w, 0))
	self._note:set_min_size(Vector2.new(w, 0))
	self._buy:set_min_size(Vector2.new(w, 48))
	self._perk_daily.body:set_min_size(Vector2.new(w - 40, 0))
	self._perk_stars.body:set_min_size(Vector2.new(w - 40, 0))
	self._perk_skin.body:set_min_size(Vector2.new(w - 40 - 56, 0))
end

return GeneralOffer
