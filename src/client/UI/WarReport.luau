--!nonstrict
-- The War Report (Warhold's own; the results screen's WAR REPORT button): how the match went: your land
-- against the leader's over time (a bar chart, drawn from UI/MatchLog's samples), the moments worth remembering, and
-- what the match paid your career, in XP and in Renown (Data/Claims: the server pays that part once it has checked it).
local UITheme = require("./UITheme")
local W = require("./Widgets")
local UICtx = require("./UICtx")
local Sheet = require("./Sheet")
local HelpOverlay = require("./HelpOverlay")
local Signal = UITheme.core("Signal")

local WarReport = W.class(W.Control)

--- The sheet's body, desktop.
WarReport.WIDTH = 640
WarReport.CHART_H = 120

function WarReport.new(c: any)
	local self = setmetatable({}, WarReport.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.is_open = false
	local v, head = Sheet.attach(self, "WAR REPORT", { relayout = true })
	self._sub = UITheme.label("", 13, 600, UITheme.TEXT_2)
	self._sub.size_flags_horizontal = W.EXPAND_FILL
	self._sub.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._sub)
	self._scroll = HelpOverlay.Scroll.new()
	self._scroll.size_flags_vertical = W.EXPAND_FILL
	v:add_child(self._scroll)
	return self
end

--- The chart: one column per sample; the leader's land behind, yours in front.
function WarReport._chart(self, samples: { { number } }): any
	local T = UITheme
	local chart = W.Control.new()
	chart:set_mouse_filter(W.MOUSE_IGNORE)
	chart:set_min_size(Vector2.new(0, WarReport.CHART_H))
	chart.size_flags_horizontal = W.EXPAND_FILL
	local n = #samples
	local top = 0.05
	for _, s in samples do
		top = math.max(top, s[3], s[2])
	end
	for i, s in samples do
		local l, r = (i - 1) / n, i / n
		local lead = W.ColorRect.new(T.c(T.WHITE, 0.14))
		lead:set_mouse_filter(W.MOUSE_IGNORE)
		lead:set_anchors(l, 1 - s[3] / top, r, 1)
		lead:set_offsets(0, 0, -1, 0)
		chart:add_child(lead)
		local mine = W.ColorRect.new(T.AMBER)
		mine:set_mouse_filter(W.MOUSE_IGNORE)
		mine:set_anchors(l, 1 - s[2] / top, r, 1)
		mine:set_offsets(0, 0, -1, 0)
		chart:add_child(mine)
	end
	return chart
end

--- A line of the report that earned Renown: its words, the Renown mark, the amount.
local function renown_line(text: string, color: any, amount: number): any
	local T = UITheme
	local row = T.hbox(4)
	local l = T.label(text, 12, 600, color)
	l.size_flags_horizontal = W.EXPAND_FILL
	row:add_child(l)
	row:add_child(T.icon_rect("renown", 12.0, T.GOLD))
	row:add_child(T.label(string.format("+%d", amount), 12, 700, T.GOLD))
	return row
end

--- `log`: UI/MatchLog; `result`: Data/Progress.after_match's answer (nil when the match paid nothing).
function WarReport.open(self, log: any, result: any)
	local T = UITheme
	if self._content ~= nil then
		self._scroll:remove_child(self._content)
		self._content:queue_free()
	end
	local v = T.vbox(8)
	v.size_flags_horizontal = W.EXPAND_FILL
	local wrap = T.hbox(0)
	wrap:add_child(v)
	local gutter = W.Control.new()
	gutter:set_min_size(Vector2.new(12, 0))
	gutter:set_mouse_filter(W.MOUSE_IGNORE)
	wrap:add_child(gutter)
	self._content = wrap
	self._scroll:add_child(wrap)
	local samples = log.samples
	local best = 0.0
	for _, s in samples do
		best = math.max(best, s[2])
	end
	self._sub:set_text(string.format("Best: %s of the land", T.fmt_pct(best)))
	if #samples >= 2 then
		local legend = T.hbox(12)
		legend:add_child(T.label("YOUR LAND", 12, 800, T.AMBER, 1))
		legend:add_child(T.label("THE LEADER'S", 12, 800, T.TEXT_2, 1))
		v:add_child(legend)
		v:add_child(self:_chart(samples))
	else
		v:add_child(T.label("Too short a match for a chart.", 12, 500, T.TEXT_2))
	end
	if result ~= nil and result.gained > 0 then
		v:add_child(T.label(string.format("CAREER: +%d XP · %s", result.gained, string.upper(result.rank.name)), 12, 800, T.AMBER, 1))
		for _, line in result.lines do
			v:add_child(T.label(string.format("%s  +%d", line[1], line[2]), 12, 600, T.TEXT_2))
		end
		local Claims = UICtx.data("Claims")
		local earned = Claims.of_result(result)
		if result.stars ~= nil and result.mission ~= nil then
			v:add_child(renown_line(string.format("War Room: %s, %d of 3 laurels", result.mission, result.stars), T.AMBER, earned.laurels))
		end
		for _, order in result.orders do
			v:add_child(renown_line("Order complete: " .. order.text, T.GREEN, Claims.order_amount(order)))
		end
		for _, m in result.medals do
			v:add_child(renown_line("Medal: " .. m.name, T.AMBER, Claims.medal_amount(m)))
		end
		if earned.season > 0 then
			v:add_child(renown_line(string.format("Season level %d", result.season_level), T.AMBER, earned.season))
		end
		for _, t in result.new_titles do
			v:add_child(T.label("New title: " .. t, 12, 700, T.AMBER))
		end
	end
	if #log.moments > 0 then
		v:add_child(T.label("MOMENTS", 12, 800, T.AMBER, 2))
		for _, m in log.moments do
			local row = T.hbox(10)
			local at = T.label(T.fmt_time(m[1]), 12, 700, T.TEXT_3)
			at:set_min_size(Vector2.new(46, 0))
			row:add_child(at)
			row:add_child(T.label(m[2], 12, 600, if m[3] then T.TEXT else T.TEXT_2))
			v:add_child(row)
		end
	end
	self.is_open = true
	self:apply_layout()
	Sheet.show(self)
end

function WarReport.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function WarReport.apply_layout(self)
	Sheet.place(self, WarReport.WIDTH)
end

return WarReport
