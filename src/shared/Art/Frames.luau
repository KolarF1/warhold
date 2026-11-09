--!strict
-- The frame an icon sits in tells its kind before the glyph does: a square plate for the economy, a shield for
-- defence, a diamond for strikes, a disc for a landmark. One table for the map (tools/art/mapart.luau draws the
-- building plates from it) and the HUD (the frame_* icons in Art/IconData are these shapes, filled).
-- The shapes are on the icons' 64 x 64 grid; each is convex, so an inset is the shape less a band along its edges.
local Frames = {}

--- An icon's category frame, by icon name: "square" | "shield" | "diamond" | "circle".
Frames.of = {
	-- economy
	city = "square",
	port = "square",
	factory = "square",
	farm = "square",
	market = "square",
	-- defence
	defense = "shield",
	sam = "shield",
	artillery = "shield",
	barracks = "shield",
	fort = "shield",
	-- strike: what builds or fires a blow, and the blows themselves
	warship = "diamond",
	silo = "diamond",
	airfield = "diamond",
	railgun = "diamond",
	atom = "diamond",
	hydrogen = "diamond",
	mega = "diamond",
	mirv = "diamond",
	scatter = "diamond",
	airstrike = "diamond",
	slug = "diamond",
	-- landmarks
	lm_mine = "circle",
	lm_garrison = "circle",
	lm_citadel = "circle",
	lm_harbor = "circle",
	wheat = "circle",
	lm_foundry = "circle",
}

--- The HUD's icon for each frame (filled; the HUD tints it and rims it).
Frames.icon = {
	square = "frame_square",
	shield = "frame_shield",
	diamond = "frame_diamond",
	circle = "frame_circle",
}

--- How big each frame is drawn against a square plate's box (the map's SHAPE_SCALE), so all four hold about the
--- same ground: a diamond has half a square's area in the same box, a shield a little less.
Frames.scale = {
	square = 1.0,
	shield = 1.06,
	diamond = 1.2,
	circle = 1.04,
}

local function bezier(out: { number }, x0: number, y0: number, x1: number, y1: number, x2: number, y2: number, x3: number, y3: number, n: number)
	for i = 1, n do
		local t = i / n
		local u = 1 - t
		table.insert(out, u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3)
		table.insert(out, u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3)
	end
end

--- The shield's outline: a flat-topped heater shield, its point at the foot.
local function shield_pts(): { number }
	local p = { 32, 3, 59, 10, 59, 30 }
	bezier(p, 59, 30, 59, 46, 47, 55, 32, 61, 6)
	bezier(p, 32, 61, 17, 55, 5, 46, 5, 30, 6)
	table.insert(p, 5)
	table.insert(p, 10)
	return p
end

local OUTLINE = {
	shield = shield_pts(),
	diamond = { 32, 1, 63, 32, 32, 63, 1, 32 },
}

--- The frame `kind` as a shape list, shrunk inwards by `inset` grid units (0: the whole shape).
function Frames.shape(kind: string, inset: number): { any }
	if kind == "square" then
		local s = 3 + inset
		return { { "box", s, s, 64 - s, 64 - s, math.max(2, 10 - inset) } }
	elseif kind == "circle" then
		return { { "circle", 32, 32, 30 - inset } }
	end
	local pts = OUTLINE[kind]
	assert(pts, "no frame " .. kind)
	local list: { any } = { { "poly", table.unpack(pts) } }
	if inset > 0 then
		local n = #pts // 2
		for i = 0, n - 1 do
			local j = (i + 1) % n
			table.insert(list, { "erase", { "line", pts[i * 2 + 1], pts[i * 2 + 2], pts[j * 2 + 1], pts[j * 2 + 2], inset * 2 } })
		end
	end
	return list
end

return Frames
