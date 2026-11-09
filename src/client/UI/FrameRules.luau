--!strict
-- The strategy frame's pure rules (2026-11-03, the owner's approved "strategy frame", after Hearts of Iron 4 and Crusader
-- Kings 3): where each piece stands at a screen size, the five send presets and how the keys step them (the wheel only
-- zooms since 2026-11-03: the owner),
-- how alerts are tiered, merged and sorted, the odds line's estimate (the Sim's own attack sums, run ahead), the
-- outliner's order, World Tension, the CHANCES list and the Build window's groups. No Instances here: the widgets
-- (StrategyStrip, AlertRow, Outliner, SendPanel, WarClock, LogPanel, TargetCard, BuildWindow, CursorReadout, PhoneControls) read their sizes
-- from these numbers, and tests/ui_strategy_frame.luau checks the fits and the HUD's share of the map (HudCoverage) at
-- 1920x1080 and 1366x768 (both 1600x900 logical on a desktop), 829x400 and 667x375 with a notch.

local FrameRules = {}

export type Box = { x0: number, y0: number, x1: number, y1: number }
export type Insets = { x: number, y: number, z: number, w: number }

local function box(x0: number, y0: number, x1: number, y1: number): Box
	return { x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end
FrameRules.box = box

--- Whether two boxes overlap (touching edges do not). Pure.
function FrameRules.overlaps(a: Box, b: Box): boolean
	return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

-- ---------------------------------------------------------------------------------------------
-- Sizes (logical px)
-- ---------------------------------------------------------------------------------------------

--- The gap kept from the screen's edges, and between pieces.
FrameRules.EDGE = 16
FrameRules.EDGE_PHONE = 8
FrameRules.GAP = 8
--- The top strip: its height (the bottom border in your colour included) and its cells, left to right.
FrameRules.STRIP_H = 58
FrameRules.STRIP_BORDER = 3
--- (SEND left it for the send panel over the war clock, 2026-11-03: ARMY and GOLD took the room to say their cap and rate)
--- (the dark cards, 2026-11-06: the crest holds your name and the age bar, and every stat has its icon tile)
FrameRules.CELLS = {
	{ key = "crest", w = 216 },
	{ key = "army", w = 216 },
	{ key = "gold", w = 196 },
	{ key = "land", w = 214 },
	{ key = "warheads", w = 164 },
	{ key = "pacts", w = 118 },
}
--- The top right: World Tension and CHANCES, as wide as the outliner under it.
FrameRules.SIDE_W = 288
--- The alert row: a badge, the gap between two, the most on show (the rest merge into the last), the line beside them.
FrameRules.ALERT = 44
FrameRules.ALERT_GAP = 8
FrameRules.ALERTS_MAX = 6
FrameRules.ALERT_LINE_W = 360
--- The outliner: a section's head, a row of an attack (a line and its bar), a plain line, the quiet line of an empty
--- section, the most rows a section shows, and the four buttons at its foot.
FrameRules.OUT_HEAD_H = 32
FrameRules.OUT_ROW_H = 42
FrameRules.OUT_LINE_H = 24
FrameRules.OUT_ROWS = 3
FrameRules.OUT_RIVALS = 4
FrameRules.OUT_BUTTONS_H = 70
FrameRules.OUT_PAD = 6
--- (the dark cards, 2026-11-06: each section is its own card, this far apart, with this much inside above and below;
--- the four buttons left the outliner for the dock at the bottom middle)
FrameRules.OUT_CARD_GAP = 10
--- The command bar at the bottom (UI/ActionDock, 2026-11-07, the owner: every item named, not under the match log or the
--- bottom-right panel, and clean): two rows between the log and the war clock, their feet in line. The top row is the
--- ten buildings in their three groups (a wider gap between), the bottom row the strikes on offer with Doctrine and
--- Pacts at its right end. A slot is its icon, its name (two lines at most) and its price, DOCK_SLOT_W wide at most.
--- Where the slots would go under DOCK_NAME_MIN they drop the name (icon and price, the name on hover) and the rows get
--- shorter, rather than squeeze a name under 12 px.
FrameRules.DOCK_SLOT_W = 108
FrameRules.DOCK_SLOT_H = 81
FrameRules.DOCK_SLOT_H_BARE = 50
--- A slot's icon tile (FrameKit.tile, the top strip's chips' look).
FrameRules.DOCK_TILE = 28
FrameRules.DOCK_TILE_Y = 3
FrameRules.DOCK_GAP = 3
FrameRules.DOCK_GROUP_GAP = 8
FrameRules.DOCK_PAD = 4
FrameRules.DOCK_NAME_MIN = 70
--- The narrowest a command bar slot gets (a narrow screen's bar shrinks its slots before anything overlaps).
FrameRules.DOCK_SLOT_MIN = 44
--- The slots the bar holds when nobody says (ten buildings, three strikes, Doctrine and Pacts); the buildings' row.
FrameRules.DOCK_N = 15
FrameRules.DOCK_COLS = 10
--- The bar's height, two rows of named slots or of bare ones.
FrameRules.DOCK_H = 2 * FrameRules.DOCK_SLOT_H + FrameRules.DOCK_GAP + 2 * FrameRules.DOCK_PAD
FrameRules.DOCK_H_BARE = 2 * FrameRules.DOCK_SLOT_H_BARE + FrameRules.DOCK_GAP + 2 * FrameRules.DOCK_PAD

--- The columns the bar needs for `n` slots: the ten buildings' row, or the strikes with Doctrine and Pacts if longer.
--- Pure.
function FrameRules.dock_cols(n: number): number
	return math.max(FrameRules.DOCK_COLS, n - FrameRules.DOCK_COLS)
end

--- The gaps a cramped bar closes to (slot to slot, group to group) before its slots go under DOCK_SLOT_MIN.
FrameRules.DOCK_GAP_TIGHT = 2
FrameRules.DOCK_GROUP_GAP_TIGHT = 6

--- The command bar's width for `n` columns `slot_w` wide, two group gaps among them (`tight`: the cramped gaps). Pure.
function FrameRules.dock_width(n: number, slot_w: number, tight: boolean?): number
	local gap = if tight then FrameRules.DOCK_GAP_TIGHT else FrameRules.DOCK_GAP
	local group = if tight then FrameRules.DOCK_GROUP_GAP_TIGHT else FrameRules.DOCK_GROUP_GAP
	return 2 * FrameRules.DOCK_PAD + n * slot_w + (n - 1) * gap + 2 * (group - gap)
end

--- The slot width for `n` columns in `room` px across, and whether the gaps close up: as wide as DOCK_SLOT_W, never
--- under DOCK_SLOT_MIN. Pure.
function FrameRules.dock_slot_for(n: number, room: number): (number, boolean)
	local slot = math.floor((room - FrameRules.dock_width(n, 0)) / math.max(1, n))
	if slot >= FrameRules.DOCK_SLOT_MIN then
		return math.min(FrameRules.DOCK_SLOT_W, slot), false
	end
	local tight = math.floor((room - FrameRules.dock_width(n, 0, true)) / math.max(1, n))
	return math.max(FrameRules.DOCK_SLOT_MIN, math.min(FrameRules.DOCK_SLOT_W, tight)), true
end
--- A narrow screen's top bar: the compact row of chips (army, gold, land, the time) in place of the full cells.
FrameRules.STRIP_W_NARROW = 340
--- The top bar's cells may narrow to this share of their width to stay on the top row beside Roblox's buttons
--- (playtest 2026-11-08: a few px short, the whole bar dropped under the corner and hugged the left wall).
FrameRules.STRIP_SQUEEZE = 0.88

--- A desktop layout too narrow for the match log, the command bar's smallest slots and the war clock side by side (a
--- small tablet, a small window: 2026-11-06, audit A1). The log then goes into the outliner as on a phone, and the bar
--- takes the foot from the left edge, the left column standing on it. Pure.
function FrameRules.is_medium(vp: Vector2, insets: Insets): boolean
	local e = FrameRules.EDGE
	local need = 2 * e + FrameRules.LOG_W + e + FrameRules.dock_width(FrameRules.DOCK_COLS, FrameRules.DOCK_SLOT_MIN) + e + FrameRules.CLOCK_W
	return vp.X - insets.x - insets.z < need
end
FrameRules.OUT_CARD_PAD = 6
--- The war clock at the bottom right, and the send panel standing on it (the share an order sends, every preset a button).
FrameRules.CLOCK_W = 360
FrameRules.CLOCK_H = 174
FrameRules.SEND_H = 94
--- The match log at the bottom left: its width, its head (the fold), a line, and the lines it shows open.
FrameRules.LOG_W = 340
FrameRules.LOG_HEAD_H = 30
FrameRules.LOG_LINE_H = 21
FrameRules.LOG_LINES = 5
--- The selection window at the left (only while something is selected), and the pop-ups beside it.
FrameRules.SELECT_W = 320
FrameRules.SELECT_MIN_H = 420
--- The Build window: a group's column and a row in it.
FrameRules.BUILD_COL_W = 210
FrameRules.BUILD_COL_W_PHONE = 176
FrameRules.BUILD_ROW_H = 52
FrameRules.BUILD_ROW_H_PHONE = 46
--- Phones: the strip, the alert column, the preset buttons for the left thumb, the four buttons for the right thumb, and
--- the sheet a tapped nation opens.
FrameRules.STRIP_H_PHONE = 36
FrameRules.STRIP_W_PHONE = 470
FrameRules.ALERTS_MAX_PHONE = 4
FrameRules.PRESET = 46
FrameRules.PRESET_GAP = 4
FrameRules.PRESET_CAPTION_H = 16
FrameRules.ACTION_W = 88
FrameRules.ACTION_H = 46
FrameRules.ACTION_GAP = 4
FrameRules.SHEET_W_MAX = 360
FrameRules.SHEET_W_MIN = 300
FrameRules.SHEET_H = 112
--- The phone's outliner ("Your war"): a sheet down the right.
FrameRules.OUT_SHEET_W = 300

--- The strip's width at full size (its cells end to end). Pure.
function FrameRules.strip_width(): number
	local w = 0
	for _, c in FrameRules.CELLS do
		w += c.w
	end
	return w
end

--- The outliner's height for its sections: { { open, rows, row_h? } } (rows 0: the quiet line), plus its buttons. Pure.
function FrameRules.outliner_height(sections: { any }): number
	local h = -FrameRules.OUT_CARD_GAP
	for _, s in sections do
		h += FrameRules.OUT_CARD_GAP + FrameRules.OUT_CARD_PAD * 2
		h += FrameRules.OUT_HEAD_H
		if s.open then
			local n = math.min(s.rows or 0, s.max or FrameRules.OUT_ROWS)
			if n <= 0 then
				h += FrameRules.OUT_LINE_H
			else
				h += n * (s.row_h or FrameRules.OUT_ROW_H)
			end
		end
	end
	return h
end

--- The outliner's resting shape: YOUR ATTACKS and THREATS open and quiet, the top four RIVALS and you (a desktop's log
--- is its own panel at the bottom left).
function FrameRules.quiet_sections(): { any }
	return {
		{ open = true, rows = 0 },
		{ open = true, rows = 0 },
		{ open = true, rows = FrameRules.OUT_RIVALS + 1, max = FrameRules.OUT_RIVALS + 1, row_h = FrameRules.OUT_LINE_H },
	}
end

--- The match log's height: open (its head and LOG_LINES lines) or folded (its head). Pure.
function FrameRules.log_height(open: boolean): number
	if not open then
		return FrameRules.LOG_HEAD_H
	end
	return FrameRules.LOG_HEAD_H + FrameRules.LOG_LINES * FrameRules.LOG_LINE_H + 8
end

--- The alert row's width for `n` badges with its line. Pure.
function FrameRules.alerts_width(n: number, with_line: boolean?): number
	if n <= 0 then
		return 0
	end
	local w = n * FrameRules.ALERT + (n - 1) * FrameRules.ALERT_GAP
	if with_line then
		w += FrameRules.ALERT_GAP + FrameRules.ALERT_LINE_W
	end
	return w
end

--- Where every piece stands on a `vp` screen (logical px). `reserved`: the top-left corner Roblox's buttons (and an open
--- chat) hold; nothing of ours goes under it. `opts`: out_h (the outliner's height, default the quiet one), alerts (badges
--- on show), sheet_h (a phone's sheet). Returns boxes:
---   desktop: strip, side (tension + CHANCES), alerts, outliner, send (the send panel), clock, log (the match log at the
---            bottom left; opts.log_h: its height now, 0 when hidden), log_aside (where it steps while the left window
---            needs the column's foot: beside that window), select (the left window's column), popup (where a pop-up
---            stands, beside the left window), build (the Build window's area), dock (the command bar along the bottom:
---            opts.dock_n its slots, default DOCK_N; dock_cols its columns, dock_slot_w their width, dock_tight whether its gaps
---            closed up to fit,
---            dock_names whether they have room for their
---            names), draft (the doctrine draft's column down the left edge), plus the flags medium (FrameRules.is_medium:
---            no log panel) and strip_narrow (the top bar shows its compact row of chips);
---   phone:   strip, alerts (the column down the right), presets, actions, sheet (a tapped nation), outliner (the
---            "Your war" sheet), popup, build.
--- Pure.
function FrameRules.layout(vp: Vector2, compact: boolean, insets: Insets, reserved: Box, opts: any?): { [string]: any }
	local o = opts or {}
	local out: { [string]: any } = {}
	if not compact then
		local e = FrameRules.EDGE
		local g = FrameRules.GAP
		local right = vp.X - insets.z - e
		local top = insets.y + 8
		out.side = box(right - FrameRules.SIDE_W, top, right, top + FrameRules.STRIP_H)
		local sw = FrameRules.strip_width()
		local min_x = math.max(insets.x + e, reserved.x1 + 12)
		local max_x = out.side.x0 - 12
		local sy = top
		local room = max_x - min_x
		local squeeze = FrameRules.STRIP_SQUEEZE
		if room < sw * squeeze and max_x - (insets.x + e) >= sw * squeeze then
			-- (the chat holds the corner and the strip will not fit beside it: it runs under the corner instead)
			min_x = insets.x + e
			sy = math.max(reserved.y1, insets.y) + 8
			room = max_x - min_x
		end
		-- (too narrow for the full cells even squeezed: the compact row of chips, beside the corner)
		out.strip_narrow = room < sw * squeeze
		-- the cells' width share (1: full; down to STRIP_SQUEEZE to keep the top row)
		out.strip_k = if out.strip_narrow then 1 else math.min(1, room / sw)
		local w = if out.strip_narrow then math.min(FrameRules.STRIP_W_NARROW, room) else math.floor(sw * out.strip_k)
		-- centred on the screen where the room allows, else as near the centre as it can stand
		local sx = math.clamp(math.floor((vp.X - w) * 0.5), min_x, math.max(min_x, max_x - w))
		out.strip = box(sx, sy, sx + w, sy + FrameRules.STRIP_H)
		local n = o.alerts or 0
		-- the alert row: down the left edge, under the strip and Roblox's corner
		local ax = insets.x + e
		local ay = math.max(out.strip.y1, reserved.y1) + g
		out.alerts = box(ax, ay, ax + math.min(FrameRules.alerts_width(n, n > 0), out.side.x0 - 12 - ax), ay + FrameRules.ALERT)
		local bottom = vp.Y - insets.w - e
		local lx = insets.x + e
		-- the war clock and the send panel keep the bottom-right corner
		out.clock = box(right - FrameRules.CLOCK_W, bottom - FrameRules.CLOCK_H, right, bottom)
		out.send = box(out.clock.x0, out.clock.y0 - g - FrameRules.SEND_H, right, out.clock.y0 - g)
		local medium = FrameRules.is_medium(vp, insets)
		out.medium = medium
		-- the command bar: two rows between the match log and the clock, their feet in line (UI/ActionDock)
		local dn = o.dock_n or FrameRules.DOCK_N
		local cols = FrameRules.dock_cols(dn)
		local bx0 = if medium then lx else lx + FrameRules.LOG_W + e
		local span = out.clock.x0 - e - bx0
		local slot, tight = FrameRules.dock_slot_for(cols, span)
		out.dock_names = slot >= FrameRules.DOCK_NAME_MIN and not tight
		local dh = if out.dock_names then FrameRules.DOCK_H else FrameRules.DOCK_H_BARE
		local dw = FrameRules.dock_width(cols, slot, tight)
		local dx = math.floor(bx0 + math.max(0, (span - dw) * 0.5))
		out.dock = box(dx, bottom - dh, dx + dw, bottom)
		out.dock_slot_w = slot
		out.dock_cols = cols
		out.dock_tight = tight
		-- (the left column keeps the foot, beside the bar; on a narrow screen with no log panel it stands on the bar)
		local left_bottom = if medium then out.dock.y0 - g else bottom
		local oy = out.side.y1 + g
		local oh = o.out_h or FrameRules.outliner_height(FrameRules.quiet_sections())
		out.outliner = box(out.side.x0, oy, out.side.x1, math.min(oy + oh, out.send.y0 - g))
		local ly = math.max(out.alerts.y1, reserved.y1) + 12
		local lh = if medium then 0 elseif o.log_h ~= nil then o.log_h else FrameRules.log_height(true)
		out.log = box(lx, left_bottom - lh, lx + FrameRules.LOG_W, left_bottom)
		-- (the left window keeps SELECT_MIN_H at least: when an open chat holds the corner down to there, it reaches over
		-- the bar's left end while it is open, a nation's window being a passing thing)
		out.select = box(lx, ly, lx + FrameRules.SELECT_W, math.max(left_bottom, math.min(bottom, ly + FrameRules.SELECT_MIN_H)))
		-- (where the log steps while the left column is taken: beside it, standing on the bar)
		local above = out.dock.y0 - g
		out.log_aside = box(out.select.x1 + e, above - lh, out.select.x1 + e + FrameRules.LOG_W, above)
		local px = out.select.x1 + e
		out.popup = box(px, ly, math.max(px, out.outliner.x0 - e), above)
		out.build = box(math.max(lx, out.outliner.x0 - e - 3 * FrameRules.BUILD_COL_W - 2 * g - 2 * 14), ly, out.outliner.x0 - e, out.send.y0 - g)
		-- the doctrine draft: a column of cards down the left edge, the outliner's mirror (2026-11-07, the owner)
		out.draft = box(lx, ly, lx + FrameRules.SIDE_W, left_bottom)
		return out
	end
	local e = FrameRules.EDGE_PHONE
	local right = vp.X - insets.z - e
	local bottom = vp.Y - insets.w - e
	local sx = math.max(insets.x + e, reserved.x1 + e)
	local sy = insets.y + 6
	out.strip = box(sx, sy, math.min(sx + FrameRules.STRIP_W_PHONE, right), sy + FrameRules.STRIP_H_PHONE)
	local pw = 5 * FrameRules.PRESET + 4 * FrameRules.PRESET_GAP
	out.presets = box(insets.x + e, bottom - FrameRules.PRESET - FrameRules.PRESET_CAPTION_H, insets.x + e + pw, bottom)
	local aw = 2 * FrameRules.ACTION_W + FrameRules.ACTION_GAP
	local ah = 2 * FrameRules.ACTION_H + FrameRules.ACTION_GAP
	out.actions = box(right - aw, bottom - ah, right, bottom)
	-- the alerts: a column down the right edge, above the right thumb's buttons
	local ay0 = math.max(out.strip.y1, insets.y) + e
	local room = out.actions.y0 - e - ay0
	local fit = math.max(0, math.floor((room + 6) / (FrameRules.ALERT + 6)))
	local n = math.min(o.alerts or 0, FrameRules.ALERTS_MAX_PHONE, fit)
	out.alerts = box(right - FrameRules.ALERT, ay0, right, ay0 + math.max(0, n * FrameRules.ALERT + (n - 1) * 6))
	out.alerts_room = box(right - FrameRules.ALERT, ay0, right, ay0 + room)
	-- the sheet: between the thumbs when there is room, else above them (never under either)
	local sh = o.sheet_h or FrameRules.SHEET_H
	local gap_x0, gap_x1 = out.presets.x1 + e, out.actions.x0 - e
	if gap_x1 - gap_x0 >= FrameRules.SHEET_W_MIN then
		local w = math.min(FrameRules.SHEET_W_MAX, gap_x1 - gap_x0)
		local x0 = gap_x0 + (gap_x1 - gap_x0 - w) * 0.5
		out.sheet = box(x0, bottom - sh, x0 + w, bottom)
	else
		local x0 = insets.x + e
		local x1 = math.min(x0 + FrameRules.SHEET_W_MAX, out.alerts_room.x0 - e)
		local y1 = math.min(out.presets.y0, out.actions.y0) - e
		out.sheet = box(x0, y1 - sh, x1, y1)
	end
	local top = out.strip.y1 + e
	out.outliner = box(out.alerts_room.x0 - e - FrameRules.OUT_SHEET_W, top, out.alerts_room.x0 - e, out.actions.y0 - e)
	out.popup = box(insets.x + e, top, out.alerts_room.x0 - e, math.min(out.presets.y0, out.actions.y0) - e)
	out.build = box(insets.x + e, top, right, bottom)
	return out
end

--- The always-on boxes HudCoverage counts for a layout: the reserved corner and every resting piece (the left window,
--- pop-ups, a phone's sheets and the Build window only count while open, so not here). Pure.
function FrameRules.resting_boxes(l: { [string]: any }, reserved: Box, compact: boolean): { Box }
	local out = { reserved, l.strip }
	if not compact then
		table.insert(out, l.side)
		table.insert(out, l.outliner)
		table.insert(out, l.send)
		table.insert(out, l.clock)
		table.insert(out, l.dock)
		if l.log.y1 > l.log.y0 then
			table.insert(out, l.log)
		end
	else
		table.insert(out, l.presets)
		table.insert(out, l.actions)
	end
	if l.alerts.x1 > l.alerts.x0 and l.alerts.y1 > l.alerts.y0 then
		table.insert(out, l.alerts)
	end
	return out
end

-- ---------------------------------------------------------------------------------------------
-- Send presets and the keys
-- ---------------------------------------------------------------------------------------------

--- The five shares an order can send at a press (keys 1-5, the send panel's buttons, the selection window's).
FrameRules.PRESETS = { 0.10, 0.25, 0.50, 0.75, 1.00 }
local EPS = 1e-4

--- The preset `r` stands on (1..5), or nil when it is a free percentage between them. Pure.
function FrameRules.preset_index(r: number): number?
	for i, p in FrameRules.PRESETS do
		if math.abs(r - p) < 0.005 then
			return i
		end
	end
	return nil
end

--- Whether preset `i` may be sent under the cap `max` (the tutorial holds the share down). Pure.
function FrameRules.preset_allowed(i: number, max: number?): boolean
	local p = FrameRules.PRESETS[i]
	return p ~= nil and p <= (max or 1.0) + EPS
end

--- One notch from `r` (`dir` > 0 up): the next preset that way, never past `max`; from a free percentage it lands on the
--- nearest preset that way. At either end it stays. Pure.
function FrameRules.step_preset(r: number, dir: number, max: number?): number
	local cap = max or 1.0
	if dir > 0 then
		for _, p in FrameRules.PRESETS do
			if p > r + EPS and p <= cap + EPS then
				return p
			end
		end
		return math.min(r, cap)
	elseif dir < 0 then
		for i = #FrameRules.PRESETS, 1, -1 do
			local p = FrameRules.PRESETS[i]
			if p < r - EPS and p <= cap + EPS then
				return p
			end
		end
	end
	return math.min(r, cap)
end

--- The free percentage one point from `r` (Q / E): 1% at a time, from 1% to `max`. Pure.
function FrameRules.fine_step(r: number, dir: number, max: number?): number
	local cap = math.floor(math.clamp(max or 1.0, 0.01, 1.0) * 100 + 0.5)
	local pct = math.floor(r * 100 + 0.5) + (if dir > 0 then 1 elseif dir < 0 then -1 else 0)
	return math.clamp(pct, 1, cap) / 100
end

--- The send panel's caption, which says the keys (the mouse wheel only zooms the map).
FrameRules.SEND_CAPTION = "SEND · KEYS 1-5"

-- ---------------------------------------------------------------------------------------------
-- Alerts
-- ---------------------------------------------------------------------------------------------

--- The three urgencies, by shape and colour: a red hexagon is danger, an amber diamond a choice waiting, a green circle
--- something now open to you.
FrameRules.TIER = { danger = 1, choice = 2, available = 3 }
FrameRules.TIER_SHAPE = { danger = "hexagon", choice = "diamond", available = "circle" }
--- Each kind of alert's tier, and the order of kinds inside a tier.
FrameRules.KINDS = {
	nuke = { tier = "danger", order = 1, icon = "atom" },
	attack_in = { tier = "danger", order = 2, icon = "attack" },
	lost = { tier = "danger", order = 3, icon = "skull" },
	draft = { tier = "choice", order = 1, icon = "crown" },
	request_in = { tier = "choice", order = 2, icon = "alliance" },
	renewal = { tier = "choice", order = 3, icon = "alliance" },
	-- (a depth match: a peace offer waits for your answer in the sender's window)
	peace_in = { tier = "choice", order = 4, icon = "alliance" },
	edict = { tier = "available", order = 1, icon = "edict" },
	afford = { tier = "available", order = 2, icon = "city" },
}

--- Alert items (each { key, kind, urgency?, line, focus_tile?, owner?, icon? }) into badges: one per kind (repeats merge
--- into a count), the items the player dismissed left out (a badge comes back with a new item), most urgent tier first,
--- then the kind's order, then the most urgent item. A badge: { kind, tier, shape, count, line (its most urgent item's),
--- lines (all, most urgent first), items, icon, focus_tile, owner }. Pure.
function FrameRules.alert_badges(items: { any }, dismissed: { [string]: boolean }?): { any }
	local by: { [string]: any } = {}
	local order: { string } = {}
	local gone = dismissed or {}
	for _, it in items do
		local spec = FrameRules.KINDS[it.kind]
		if spec ~= nil and not gone[it.key] then
			local b = by[it.kind]
			if b == nil then
				b = { kind = it.kind, tier = spec.tier, shape = FrameRules.TIER_SHAPE[spec.tier], items = {}, icon = it.icon or spec.icon }
				by[it.kind] = b
				table.insert(order, it.kind)
			end
			table.insert(b.items, it)
		end
	end
	local out = {}
	for _, k in order do
		local b = by[k]
		table.sort(b.items, function(p, q)
			local up, uq = p.urgency or 0, q.urgency or 0
			if up ~= uq then
				return up > uq
			end
			return tostring(p.key) < tostring(q.key)
		end)
		b.count = #b.items
		local top = b.items[1]
		b.line = top.line
		b.focus_tile = top.focus_tile
		b.owner = top.owner
		b.urgency = top.urgency or 0
		if top.icon ~= nil then
			b.icon = top.icon
		end
		b.lines = {}
		for _, it in b.items do
			table.insert(b.lines, it.line)
		end
		table.insert(out, b)
	end
	table.sort(out, function(p, q)
		local tp, tq = FrameRules.TIER[p.tier], FrameRules.TIER[q.tier]
		if tp ~= tq then
			return tp < tq
		end
		local op, oq = FrameRules.KINDS[p.kind].order, FrameRules.KINDS[q.kind].order
		if op ~= oq then
			return op < oq
		end
		return p.urgency > q.urgency
	end)
	return out
end

--- The badges a row of `max` shows: the first max - 1 as they are, and the rest merged into the last place's count
--- (it keeps the most urgent of them, and says how many more). Pure.
function FrameRules.fit_badges(badges: { any }, max: number): { any }
	if #badges <= max then
		return badges
	end
	local out = {}
	for i = 1, max - 1 do
		out[i] = badges[i]
	end
	local rest = badges[max]
	local more = { kind = rest.kind, tier = rest.tier, shape = rest.shape, icon = rest.icon, items = {}, lines = {}, line = rest.line, focus_tile = rest.focus_tile, owner = rest.owner, urgency = rest.urgency, count = 0, overflow = true }
	for i = max, #badges do
		local b = badges[i]
		more.count += b.count
		for _, it in b.items do
			table.insert(more.items, it)
		end
		for _, l in b.lines do
			table.insert(more.lines, l)
		end
	end
	out[max] = more
	return out
end

-- ---------------------------------------------------------------------------------------------
-- The odds line: the Sim's attack sums (Core/SimAttacks), run ahead on plains
-- ---------------------------------------------------------------------------------------------

--- An attack that takes this share of the defender's land or more breaks through.
FrameRules.BREAK_SHARE = 0.25
--- Under this share it stalls at once; between the two it gains a little and stalls.
FrameRules.DENT_SHARE = 0.05

--- What sending `a.sent` troops at a nation would take, by SimAttacks' own loss per full-size tile (the front's terrain
--- taken as plains, Bastion cover as `a.bastion` of their land): loss = mag * mag_k * traitor * clamp(their troops / yours,
--- 0.6, 2) * (bonus + 0.0039 * their troops per tile), the large-territory bonuses on both sides, the defender losing
--- floor(troops per tile) a tile, and the annexation of a small nation. `R`: Core/Rules (or the same names). `a`: sent,
--- def_troops, def_tiles and att_tiles (full-size tiles), def_tribe, att_tribe, def_human, traitor, bastion (0..1).
--- Doctrines, landmarks and world events also move it: the line calls it an estimate. Returns { taken (full tiles),
--- share (of their land), annex, left (troops) }. Pure.
function FrameRules.estimate(R: any, a: any): { [string]: any }
	local def0 = math.max(tonumber(a.def_tiles) or 0, 1)
	local rem = def0
	local troops = math.max(tonumber(a.sent) or 0, 0)
	local dt = math.max(tonumber(a.def_troops) or 0, 0)
	local att = math.max(tonumber(a.att_tiles) or 1, 1)
	local plains = 80.0
	local b = math.clamp(tonumber(a.bastion) or 0, 0, 1)
	local mag = plains * ((1 - b) + b * (tonumber(R.DEFENSE_POST_MAG) or 5.0))
	local mag_k = if a.def_tribe and not a.att_tribe then (tonumber(R.BOT_DEFENDER_LOSS_MULT) or 0.7) else 1.0
	local trait = if a.traitor then (tonumber(R.TRAITOR_DEFENSE_DEBUFF) or 0.5) else 1.0
	local per_density = tonumber(R.ATTACKER_LOSS_PER_DENSITY) or 0.0039
	local base = tonumber(R.ATTACKER_LOSS_BASE) or 0.463
	local annex_below = tonumber(R.ANNEX_BELOW_FULL_TILES) or 100
	local step = math.max(1, def0 / 400)
	local taken, annex = 0.0, false
	for _ = 1, 2000 do
		if rem <= 0 or troops < 1 then
			break
		end
		local ldb = R.large_territory_bonus(math.max(rem, 1), R.LARGE_DEFENDER_DEPTH)
		local bonus = base * R.large_territory_bonus(att, R.LARGE_ATTACKER_DEPTH) * ldb
		local dloss = dt / math.max(rem, 1)
		local cl = math.clamp(dt / math.max(troops, 1e-6), 0.6, 2.0)
		local loss = mag * mag_k * trait * cl * (bonus + per_density * dloss)
		local chunk = math.min(step, rem)
		if loss > 0 and troops < chunk * loss then
			taken += troops / loss
			troops = 0
			break
		end
		troops -= chunk * loss
		dt = math.max(0, dt - chunk * math.floor(dloss))
		rem -= chunk
		att += chunk
		taken += chunk
		if rem > 0 and rem < annex_below and (not a.def_human or troops > dt) then
			annex = true
			taken = def0
			break
		end
	end
	return { taken = math.min(taken, def0), share = math.min(taken / def0, 1), annex = annex, left = troops }
end

--- The word for an estimate: "all" (their whole land), "break" (a breakthrough), "dent" (a little, then a stall),
--- "stall". Pure.
function FrameRules.verdict(est: { [string]: any }): string
	if est.annex or est.share >= 0.999 then
		return "all"
	elseif est.share >= FrameRules.BREAK_SHARE then
		return "break"
	elseif est.share >= FrameRules.DENT_SHARE then
		return "dent"
	end
	return "stall"
end

--- Whether a verdict breaks through.
function FrameRules.breaks(v: string): boolean
	return v == "all" or v == "break"
end

--- The smallest preset (index) that breaks through, given `verdict_at(i)` for each allowed preset, or nil. Pure.
function FrameRules.best_preset(verdict_at: (number) -> string?, max: number?): number?
	for i = 1, #FrameRules.PRESETS do
		if FrameRules.preset_allowed(i, max) then
			local v = verdict_at(i)
			if v ~= nil and FrameRules.breaks(v) then
				return i
			end
		end
	end
	return nil
end

local VERDICT_WORDS = {
	all = "you should take all of their land",
	["break"] = "you should break through",
	dent = "you take a little, then stall",
	stall = "you will likely stall",
}
FrameRules.VERDICT_WORDS = VERDICT_WORDS

--- The selection window's odds line: "At 25% you send 2.1k into 8.2k defenders: you will likely stall. 75% or more
--- should break through." `best`: the smallest preset's name that breaks through (nil: none does). Pure.
function FrameRules.odds_line(pct: string, sent: string, defenders: string, verdict: string, best: string?): string
	local line = string.format("At %s you send %s into %s defenders: %s.", pct, sent, defenders, VERDICT_WORDS[verdict] or VERDICT_WORDS.stall)
	if FrameRules.breaks(verdict) then
		return line
	end
	if best ~= nil then
		return line .. string.format(" %s or more should break through.", best)
	end
	return line .. " Even 100% would stall: grow first."
end

--- A phone's one line: "25% stalls · 75% breaks through". Pure.
function FrameRules.odds_short(pct: string, verdict: string, best: string?): string
	if FrameRules.breaks(verdict) then
		return string.format("%s breaks through", pct)
	end
	local now = if verdict == "dent" then pct .. " gains a little" else pct .. " stalls"
	if best ~= nil then
		return string.format("%s · %s breaks through", now, best)
	end
	return now .. " · even 100% stalls"
end

-- ---------------------------------------------------------------------------------------------
-- The outliner, World Tension, CHANCES
-- ---------------------------------------------------------------------------------------------

--- Your attacks, the largest first (ties by key, so the order never flickers). Items: { key, troops }. Pure (in place).
function FrameRules.sort_attacks(list: { any }): { any }
	table.sort(list, function(a, b)
		local ta, tb = tonumber(a.troops) or 0, tonumber(b.troops) or 0
		if ta ~= tb then
			return ta > tb
		end
		return tostring(a.key) < tostring(b.key)
	end)
	return list
end

--- RIVALS: the `n` largest by land (ties by id), you among them highlighted; when you are not in the top `n`, your own
--- row follows with your real rank. `list`: { id, name, share }. Returns rows { rank, id, name, share, me }. Pure.
function FrameRules.rivals(list: { any }, me: number, n: number): { any }
	local sorted = table.clone(list)
	table.sort(sorted, function(a, b)
		if a.share ~= b.share then
			return a.share > b.share
		end
		return a.id < b.id
	end)
	local out = {}
	local mine = nil
	for i, r in sorted do
		local row = { rank = i, id = r.id, name = r.name, share = r.share, me = r.id == me }
		if i <= n then
			table.insert(out, row)
		end
		if row.me then
			mine = row
		end
	end
	if mine ~= nil and mine.rank > n then
		table.insert(out, mine)
	end
	return out
end

--- 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th, 21st. Pure.
function FrameRules.ordinal(n: number): string
	local tens = n % 100
	local suffix = "th"
	if tens < 11 or tens > 13 then
		local one = n % 10
		suffix = if one == 1 then "st" elseif one == 2 then "nd" elseif one == 3 then "rd" else "th"
	end
	return tostring(n) .. suffix
end

--- World Tension from what the match shows: how many of the standing nations fight one another, and how many warheads
--- have flown. Returns the score (0..1) and its word. Pure.
FrameRules.TENSION_WORDS = { { 0.15, "Calm" }, { 0.35, "Uneasy" }, { 0.6, "Rising" }, { 0.85, "High" }, { math.huge, "Boiling" } }
function FrameRules.tension(at_war: number, nations: number, warheads: number): (number, string)
	local share = if nations > 0 then math.clamp(at_war / nations, 0, 1) else 0
	local score = math.clamp(0.7 * share + 0.08 * math.max(warheads, 0), 0, 1)
	for _, w in FrameRules.TENSION_WORDS do
		if score < w[1] then
			return score, w[2]
		end
	end
	return score, "Boiling"
end

--- CHANCES: neighbours your current send should break through (the weakest first), then pact offers to you. `weak`:
--- { id, name, verdict, troops }, `offers`: { id, name }. Returns rows { kind ("weak" | "offer"), id, line }. Pure.
function FrameRules.chances(weak: { any }, offers: { any }, pct: string): { any }
	local out = {}
	local w = {}
	for _, n in weak do
		if FrameRules.breaks(n.verdict) then
			table.insert(w, n)
		end
	end
	table.sort(w, function(a, b)
		if a.troops ~= b.troops then
			return a.troops < b.troops
		end
		return a.id < b.id
	end)
	for _, n in w do
		table.insert(out, { kind = "weak", id = n.id, line = string.format("%s: %s should break through", n.name, pct) })
	end
	local o = table.clone(offers)
	table.sort(o, function(a, b)
		return a.id < b.id
	end)
	for _, n in o do
		table.insert(out, { kind = "offer", id = n.id, line = string.format("%s offers a pact", n.name) })
	end
	return out
end

-- ---------------------------------------------------------------------------------------------
-- The Build window
-- ---------------------------------------------------------------------------------------------

--- Its three framed groups, by what each building does.
FrameRules.BUILD_GROUPS = {
	-- (Farm, Market, Barracks and Fort: a depth match only; BuildWindow.offers leaves them out elsewhere)
	{ key = "economy", title = "ECONOMY", kinds = { "city", "port", "factory", "farm", "market" } },
	{ key = "defence", title = "DEFENCE", kinds = { "defense", "sam", "artillery", "fort", "barracks" } },
	{ key = "strike", title = "STRIKE", kinds = { "warship", "silo", "airfield", "railgun" } },
}
--- The Warheads window's groups.
FrameRules.WARHEAD_GROUPS = {
	{ key = "warheads", title = "WARHEADS", kinds = { "atom", "hydrogen", "mirv", "mega", "scatter" } },
	{ key = "strikes", title = "STRIKES", kinds = { "airstrike", "slug" } },
	{ key = "callup", title = "CALL-UP", kinds = { "reinforce", "callarms" } },
}

--- The groups with only the kinds `has(kind)` offers (an empty group goes), each entry with its key ("1".."9", "0"
--- in reading order; past ten, none). Returns { { key, title, entries = { { kind, key } } } }. Pure.
function FrameRules.groups(groups: { any }, has: (string) -> boolean): { any }
	local out = {}
	local n = 0
	for _, g in groups do
		local entries = {}
		for _, k in g.kinds do
			if has(k) then
				n += 1
				table.insert(entries, { kind = k, key = if n <= 9 then tostring(n) elseif n == 10 then "0" else "" })
			end
		end
		if #entries > 0 then
			table.insert(out, { key = g.key, title = g.title, entries = entries })
		end
	end
	return out
end

--- The entry a digit picks in an open window: 1..9, then 0 for the tenth. Pure.
function FrameRules.digit_index(digit: number): number
	return if digit == 0 then 10 else digit
end

return FrameRules
