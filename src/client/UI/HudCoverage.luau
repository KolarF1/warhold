--!strict
-- How much of the screen the always-on HUD covers (2026-11-01: the map is the game, so the HUD has a budget).
-- Pure: the share of a screen covered by a list of rects, overlaps counted once. UIRoot.hud_coverage (Studio's
-- debug channel) feeds it the real panels; tests/hud_coverage.luau checks the sums.

local HudCoverage = {}

--- Share of the screen the HUD may cover with nothing opened. Our own numbers, not a published standard:
--- OpenFront's HUD measured about 9% on a phone (a screenshot, by eye).
---   * 2026-11-03, the strategy frame (the owner's approved mock-up, after Hearts of Iron 4 and Crusader Kings 3): a strip
---     of numbers along the top, World Tension and the outliner down the right, the war clock at the bottom right; the
---     left window, pop-ups and the Build window only count while open. Roblox's own top-left corner is counted too.
---     Measured by tests/ui_strategy_frame.luau (FrameRules.resting_boxes): a larger screen 17.0% quiet, 21.8% busy (four
---     alerts, three attacks and three threats listed); a phone (829x400) 16.9% quiet, 19.5% with four alerts; the
---     smallest phone (667x375 with a notch) 22.4% quiet, 24.9% with four alerts. The budgets sit just above those.
---     (The command dial before it: 12.4% / 14.9% desktop, 16.8% phone, 21.6% smallest phone.)
--- (raised 2026-11-03 from 17.5% and 22.5%: the owner asked for the send panel at the bottom right and the match log
--- always open at the bottom left, about 5% of a 1600x900 screen between them)
--- (and again 2026-11-06 for the dark cards: the dock of the four windows at the bottom middle, a taller bar)
--- (and 2026-11-06 again: the dock grew into the command bar, every building and strike on show)
--- (and 2026-11-07: the owner asked for every item on the command bar named, the bar between the log and the war clock
--- and under neither; they chose two named rows: 32.0% / 37.3% measured; with the strip's icon tiles 32.8% / 38.1%)
HudCoverage.BUDGET_DESKTOP = 0.33
HudCoverage.BUDGET_DESKTOP_BUSY = 0.385
HudCoverage.BUDGET_PHONE = 0.20
HudCoverage.BUDGET_PHONE_SMALL = 0.255

export type Box = { x0: number, y0: number, x1: number, y1: number }

--- The union's area of `boxes` clipped to a w x h screen, as a share of the screen (0..1).
function HudCoverage.share(boxes: { Box }, w: number, h: number): number
	if w <= 0 or h <= 0 then
		return 0
	end
	-- cut the screen at every box's left and right edge; in each slice, add up the merged spans
	local xs = { 0, w }
	for _, b in boxes do
		table.insert(xs, math.clamp(b.x0, 0, w))
		table.insert(xs, math.clamp(b.x1, 0, w))
	end
	table.sort(xs)
	local area = 0
	for i = 1, #xs - 1 do
		local a, z = xs[i], xs[i + 1]
		if z > a then
			local spans = {}
			for _, b in boxes do
				if b.x0 < z and b.x1 > a and b.y1 > b.y0 then
					table.insert(spans, { math.clamp(b.y0, 0, h), math.clamp(b.y1, 0, h) })
				end
			end
			table.sort(spans, function(p, q)
				return p[1] < q[1]
			end)
			local covered, reach = 0, 0
			for _, sp in spans do
				local from = math.max(sp[1], reach)
				if sp[2] > from then
					covered += sp[2] - from
					reach = sp[2]
				end
			end
			area += covered * (z - a)
		end
	end
	return area / (w * h)
end

return HudCoverage
