--!nonstrict
-- The crate's Details window: every item a crate can still give this player, with its own odds (Roblox's
-- paid random items policy: each outcome before purchase, behind a control that says "Details"). The rows
-- are the player's, from Cosmetics.item_odds, which is what the server rolls.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local UICtx = require("./UICtx")
local HelpOverlay = require("./HelpOverlay")
local Signal = UITheme.core("Signal")
local Cosmetics = UICtx.data("Cosmetics")

local CrateOdds = W.class(W.Control)

--- The sheet's body, desktop.
CrateOdds.WIDTH = 520

function CrateOdds.new(c: any)
	local self = setmetatable({}, CrateOdds.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	local v = Sheet.attach(self, "SPOILS ODDS")
	self._note = UITheme.label("", 12, 500, UITheme.TEXT_2)
	self._note:set_autowrap(true)
	v:add_child(self._note)
	self._scroll = HelpOverlay.Scroll.new()
	self._scroll.size_flags_vertical = W.EXPAND_FILL
	v:add_child(self._scroll)
	return self
end

--- One row: the item's name, and its odds at the right.
local function row(name: string, odds: string): any
	local r = UITheme.hbox(10)
	local n = UITheme.label(name, 13, 500, UITheme.TEXT)
	n.size_flags_horizontal = W.EXPAND_FILL
	r:add_child(n)
	r:add_child(UITheme.label(odds, 13, 600, UITheme.TEXT))
	-- (clear of the scroll bar)
	local gap = W.Control.new()
	gap:set_min_size(Vector2.new(8, 0))
	gap:set_mouse_filter(W.MOUSE_IGNORE)
	r:add_child(gap)
	return r
end

--- `owned`: the set of item ids the player owns.
function CrateOdds._fill(self, owned: any)
	local old = self._list
	if old ~= nil then
		old:queue_free()
	end
	local list = UITheme.vbox(3)
	list.size_flags_horizontal = W.EXPAND_FILL
	self._list = list
	self._scroll:add_child(list)
	local any_rounded = false
	local shown = nil
	for _, e in Cosmetics.item_odds(owned) do
		if e.rarity ~= shown then
			shown = e.rarity
			local head = UITheme.hbox(8)
			head:add_child(UITheme.swatch(UITheme.rarity_color(e.rarity), 10.0, UITheme.R_SM))
			head:add_child(UITheme.label(string.upper(e.rarity.name), 12, 800, UITheme.TEXT_2, 1))
			if #list:get_children() > 0 then
				local gap = W.Control.new()
				gap:set_min_size(Vector2.new(0, 6))
				gap:set_mouse_filter(W.MOUSE_IGNORE)
				list:add_child(gap)
			end
			list:add_child(head)
		end
		local text, rounded = Cosmetics.odds_text(e.odds)
		any_rounded = any_rounded or rounded
		local kind = if e.item.kind == "flag" then "Standard" else "Pattern"
		list:add_child(row(string.format("%s  ·  %s", e.item.name, kind), text))
	end
	local note = "What the next dispatch may carry, for you. It never brings what you hold, so these move as you collect."
	if any_rounded then
		note ..= " " .. Cosmetics.ODDS_ROUNDED_NOTE
	end
	self._note:set_text(note)
end

function CrateOdds.apply_layout(self)
	local m = Sheet.place(self, CrateOdds.WIDTH)
	-- (a wrapped label measures against its width: without one it asks for a line per letter)
	self._note:set_min_size(Vector2.new(m.body_w, 0))
end

function CrateOdds.open(self, owned: any)
	if self.is_open then
		return
	end
	self.is_open = true
	self:_fill(owned or {})
	self:apply_layout()
	Sheet.show(self)
end

function CrateOdds.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

return CrateOdds
