--!nonstrict
-- The ages' model, pure (2026-11-03: the strategy frame's war clock, UI/WarClock, draws it): where a
-- match stands among its ages, how long until the next, where a stretch of ticks falls across them, and the doctrines
-- a player drafted.
--
--   DominionStrip.model(eras, since_play, picks) -> the age, its name, how far through, the next and its time, glyphs
--   DominionStrip.spans(starts, from, to), DominionStrip.next_text(...), picks_of(state, me), picks_by_draft(state, me)
local UICtx = require("./UICtx")
local Eras = UICtx.data("Eras")
local Doctrines = UICtx.data("Doctrines")

local DominionStrip = {}

DominionStrip.ROMAN = { "I", "II", "III", "IV" }
--- A timed war's last stretch: under this many seconds its time reads as urgent.
DominionStrip.LAST_S = 120

--- Where the stretch from tick `from` to tick `to` (since play) falls on the strip: era -> { a, b }, each a share of that
--- era's segment. The last era runs on for as long as the one before it did. Pure.
function DominionStrip.spans(starts: { number }, from: number, to: number): { [number]: { number } }
	local out = {}
	for i, st in starts do
		local en = starts[i + 1] or (st + (st - (starts[i - 1] or 0)))
		local span = math.max(en - st, 1)
		local a, b = math.max(from, st), math.min(to, en)
		if b > a then
			out[i] = { (a - st) / span, (b - st) / span }
		end
	end
	return out
end

--- The time that matters now, as the strip says it: until the next age, or until a timed war ends when that comes first.
--- Returns the text and whether it is urgent. Pure. `fmt`: seconds to text.
function DominionStrip.next_text(next_name: string?, next_s: number?, end_s: number?, fmt: (number) -> string): (string, boolean)
	if end_s ~= nil and (next_s == nil or end_s <= next_s) then
		local urgent = end_s < DominionStrip.LAST_S
		return string.format("Ends in %s%s", fmt(end_s), if urgent then " !" else ""), urgent
	end
	if next_s ~= nil then
		return string.format("%s in %s", next_name or "", fmt(next_s)), false
	end
	return "Last age", false
end

--- What the strip shows for a match with era starts `eras`, `since_play` ticks into play, and a
--- player who picked `picks` (doctrine keys): the era, its name, how far through it (0..1), seconds to
--- the next (nil in the last), and the picks' glyphs.
function DominionStrip.model(eras: { number }?, since_play: number, picks: { string }?)
	local starts = eras or Eras.DEFAULT
	local era = Eras.index(since_play, starts)
	local left = Eras.ticks_to_next(since_play, starts)
	local progress = 1.0
	if left ~= nil then
		local span = starts[era + 1] - starts[era]
		progress = math.clamp(1.0 - left / span, 0.0, 1.0)
	end
	local glyphs = {}
	for _, k in picks or {} do
		local d = Doctrines.BY_KEY[k]
		if d ~= nil then
			table.insert(glyphs, d.glyph)
		end
	end
	return {
		era = era,
		name = Eras.NAMES[era],
		roman = DominionStrip.ROMAN[era],
		blurb = Eras.BLURBS[era],
		progress = progress,
		next_s = if left ~= nil then math.ceil(left / 10) else nil,
		next_name = if left ~= nil then Eras.NAMES[era + 1] else nil,
		glyphs = glyphs,
		segments = #starts,
	}
end

--- The picks of the local player: doctrine keys in draft order.
function DominionStrip.picks_of(state: any, me: number): { string }
	local out = {}
	local by = if state ~= nil and me ~= 0 then state.doctrine[me] else nil
	if by == nil then
		return out
	end
	for draft = 1, Doctrines.TIERS do
		local row = by[draft]
		if row ~= nil and row[6] >= 1 and row[6] <= Doctrines.OFFER_SIZE then
			table.insert(out, Doctrines.LIST[row[2 + row[6]]].key)
		end
	end
	return out
end

--- The picks of the local player by draft: draft index -> doctrine key (the Chronicle ties them to their ages).
function DominionStrip.picks_by_draft(state: any, me: number): { [number]: string }
	local out = {}
	local rows = if state ~= nil then state.doctrine else nil
	local by = if rows ~= nil and me ~= 0 then rows[me] else nil
	if by == nil then
		return out
	end
	for draft = 1, Doctrines.TIERS do
		local row = by[draft]
		if row ~= nil and row[6] >= 1 and row[6] <= Doctrines.OFFER_SIZE then
			out[draft] = Doctrines.LIST[row[2 + row[6]]].key
		end
	end
	return out
end

return DominionStrip
