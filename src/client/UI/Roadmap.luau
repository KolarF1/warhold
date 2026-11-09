--!nonstrict
-- The roadmap (the main menu's patch notes panel opens it; the owner, 2026-11-08): what is being built now, what comes
-- next and later (Data/PatchNotes.ROADMAP), and every update so far under it, newest first.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local UICtx = require("./UICtx")
local HelpOverlay = require("./HelpOverlay")
local Signal = UITheme.core("Signal")

local Roadmap = W.class(W.Control)

Roadmap.WIDTH = 560

function Roadmap.new(c: any)
	local self = setmetatable({}, Roadmap.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	local v = Sheet.attach(self, "ROADMAP")
	self._scroll = HelpOverlay.Scroll.new()
	self._scroll.size_flags_vertical = W.EXPAND_FILL
	v:add_child(self._scroll)
	self._labels = {}
	return self
end

--- A wrapped line, kept so the layout can give it its width.
function Roadmap._line(self, text: string, size: number, weight: number, col: any): any
	local l = UITheme.label(text, size, weight, col)
	l:set_autowrap(true)
	table.insert(self._labels, l)
	return l
end

function Roadmap._fill(self)
	local T = UITheme
	if self._list ~= nil then
		self._list:queue_free()
	end
	table.clear(self._labels)
	local PN = UICtx.data("PatchNotes")
	local list = T.vbox(6)
	list.size_flags_horizontal = W.EXPAND_FILL
	self._list = list
	self._scroll:add_child(list)
	for i, sec in PN.ROADMAP do
		if i > 1 then
			local gap = W.Control.new()
			gap:set_min_size(Vector2.new(0, 8))
			list:add_child(gap)
		end
		list:add_child(T.label(sec.title, 13, 800, if i == 1 then T.AMBER else T.TEXT_2, 1))
		for _, line in sec.lines do
			list:add_child(self:_line("•  " .. line, 14, 600, T.TEXT))
		end
	end
	local gap = W.Control.new()
	gap:set_min_size(Vector2.new(0, 16))
	list:add_child(gap)
	list:add_child(T.label("EVERY UPDATE", 13, 800, T.TEXT_2, 1))
	for _, r in PN.RELEASES do
		list:add_child(T.label(string.format("v%s  ·  %s  ·  %s", r.version, r.title, r.date), 14, 800, T.TEXT))
		for _, line in r.lines do
			list:add_child(self:_line("•  " .. line, 13, 500, T.TEXT_2))
		end
	end
end

function Roadmap.apply_layout(self)
	local m = Sheet.place(self, Roadmap.WIDTH)
	-- (a wrapped label measures against its width; clear of the scroll bar)
	for _, l in self._labels do
		l:set_min_size(Vector2.new(math.max(m.body_w - 14, 80), 0))
	end
end

function Roadmap.open(self)
	if self.is_open then
		return
	end
	self.is_open = true
	self:_fill()
	self:apply_layout()
	Sheet.show(self)
end

function Roadmap.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

return Roadmap
