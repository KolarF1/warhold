--!nonstrict
-- The world's news (2026-11-03, the strategy frame): what the advisor and the server say ("Spain took Rome's Harbor",
-- "a pact is sealed") goes here, not over the map; the outliner's LOG section shows the latest lines. The alerts hold
-- what needs you (UI/AlertRow), read from the match itself.
--
-- UIAdvisor and DoctrineDraft know it as `ui.feed` (the toast feed it replaced): toast(category, text, icon?, seconds?)
-- logs a line; the letters' calls (alliance_request, close_request, close_all_requests, alliance_renewal, close_renewal)
-- do nothing here, since a pact offer is an amber alert now, and has_request_card / has_renewal_card answer false.
-- Members: lines ({ { text, category, tick } }, newest last), changed (Signal). Methods: clear(), recent(n).

local UITheme = require("./UITheme")
local Signal = UITheme.core("Signal")

local NewsLog = {}
NewsLog.__index = NewsLog

--- The most lines kept.
NewsLog.MAX = 60

function NewsLog.new(c: any)
	local self = setmetatable({}, NewsLog)
	self.ctx = c
	self.lines = {}
	self.changed = Signal.new()
	return self
end

--- A line of news; a repeat of the last line counts up instead of standing twice.
function NewsLog.toast(self, category: number, text: string, _icon: string?, _seconds: number?)
	if type(text) ~= "string" or text == "" then
		return
	end
	local last = self.lines[#self.lines]
	local tick = if self.ctx ~= nil and self.ctx.state ~= nil then self.ctx.state.tick else 0
	if last ~= nil and last.raw == text then
		last.count += 1
		last.text = string.format("%s (x%d)", text, last.count)
		last.tick = tick
	else
		table.insert(self.lines, { raw = text, text = text, category = category, tick = tick, count = 1 })
		while #self.lines > NewsLog.MAX do
			table.remove(self.lines, 1)
		end
	end
	self.changed:Fire()
end

--- The latest `n` lines, newest first.
function NewsLog.recent(self, n: number): { any }
	local out = {}
	for i = #self.lines, math.max(1, #self.lines - n + 1), -1 do
		table.insert(out, self.lines[i])
	end
	return out
end

function NewsLog.clear(self)
	table.clear(self.lines)
	self.changed:Fire()
end

-- the letters' calls: a pact offer is an amber alert now (AlertRow), read from the match
function NewsLog.alliance_request(_self, _from: number) end
function NewsLog.close_request(_self, _from: number) end
function NewsLog.close_all_requests(_self) end
function NewsLog.alliance_renewal(_self, _other: number, _expires_at: number, _other_asked: boolean) end
function NewsLog.close_renewal(_self, _other: number) end
function NewsLog.has_request_card(_self, _from: number): boolean
	return false
end
function NewsLog.has_renewal_card(_self, _other: number): boolean
	return false
end

return NewsLog
