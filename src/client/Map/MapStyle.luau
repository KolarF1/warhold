--!strict
-- The map's own dressing as numbers and small sums: poisoned ground, ships and their wakes, a building's
-- rank and its bar, the names on the land. Pure, so the tests hold them; the layers draw with them.

local MapStyle = {}

-- ---------------------------------------------------------------------------------------------
-- Poisoned land: burnt ground, inked with a hatch as a chart marks what cannot be held
-- ---------------------------------------------------------------------------------------------

--- The ground, the hatch's lines, every HATCH_EVERY tiles, and a rare ember (0..1), and how much a tile's
--- noise lifts them.
MapStyle.POISON_GROUND = { 0.3, 0.24, 0.23 }
MapStyle.POISON_HATCH = { 0.17, 0.13, 0.14 }
MapStyle.POISON_EMBER = { 0.56, 0.27, 0.13 }
MapStyle.POISON_NOISE = 0.05
MapStyle.HATCH_EVERY = 5
--- A tile's noise (0..1) above this is an ember.
MapStyle.EMBER_ABOVE = 0.965

--- The colour (0..1) of a poisoned tile at (x, y) with noise `nz` (0..1).
function MapStyle.poison_rgb(x: number, y: number, nz: number): (number, number, number)
	local c = MapStyle.POISON_GROUND
	if nz > MapStyle.EMBER_ABOVE then
		c = MapStyle.POISON_EMBER
	elseif (x + y) % MapStyle.HATCH_EVERY == 0 then
		c = MapStyle.POISON_HATCH
	end
	local lift = nz * MapStyle.POISON_NOISE
	return c[1] + lift, c[2] + lift, c[3] + lift
end

-- ---------------------------------------------------------------------------------------------
-- Ships: seen from above, turned to where they sail
-- ---------------------------------------------------------------------------------------------

--- A heading is worked out from here to this many path tiles ahead (the paths are staircases).
MapStyle.HEADING_AHEAD = 6
--- Headings snap to this many degrees: a ship turns in small steps, and a heading that did not change costs nothing.
MapStyle.HEADING_STEP = 15

--- Screen degrees (the sprites point right) of a heading (dx, dy), snapped; nil with no heading.
function MapStyle.heading(dx: number, dy: number): number?
	if dx == 0 and dy == 0 then
		return nil
	end
	local step = MapStyle.HEADING_STEP
	return (math.round(math.deg(math.atan2(dy, dx)) / step) * step) % 360
end

--- A ship's wake: how long it trails (full-size tiles), in how many bars and how strong each is, nearest
--- the ship first.
MapStyle.WAKE_LEN = 34.0
MapStyle.WAKE_ALPHA = { 0.55, 0.36, 0.2, 0.09 }

--- A warhead's trail: strength and width (of the full width) from the launch to the target, in a few steps,
--- fixed for a point of the arc: it hardens as it comes down, and a point never needs writing twice.
MapStyle.TRAIL_ALPHA_FAR = 0.12
MapStyle.TRAIL_ALPHA_NEAR = 0.66
MapStyle.TRAIL_WIDTH_FAR = 0.4
MapStyle.TRAIL_STEPS = 8

--- The trail at `f` (0 launch .. 1 target) along its flight: transparency, and a width factor.
function MapStyle.trail_at(f: number): (number, number)
	local n = MapStyle.TRAIL_STEPS
	local s = math.clamp(math.floor(f * n + 0.5) / n, 0, 1)
	local alpha = MapStyle.TRAIL_ALPHA_FAR + (MapStyle.TRAIL_ALPHA_NEAR - MapStyle.TRAIL_ALPHA_FAR) * s
	return 1 - alpha, MapStyle.TRAIL_WIDTH_FAR + (1 - MapStyle.TRAIL_WIDTH_FAR) * s
end

--- The target ring closes on the point as the warhead comes down: its diameter at `t` (0..1) of the flight,
--- against the blast's.
MapStyle.AIM_OPEN = 1.45

function MapStyle.aim_scale(t: number): number
	return 1 + (MapStyle.AIM_OPEN - 1) * (1 - t) * (1 - t)
end

--- From (x, y) on a route (points xs, ys; `j` the last point at or before it) back along it `dist`: the point
--- reached and its `j`; on running out, the route's start. For a wake that does not run back to the shore.
function MapStyle.walk_back(xs: { number }, ys: { number }, j: number, x: number, y: number, dist: number): (number, number, number)
	while j >= 1 do
		local px, py = xs[j], ys[j]
		local dx, dy = x - px, y - py
		local len = math.sqrt(dx * dx + dy * dy)
		if len >= dist then
			if len <= 0 then
				return x, y, j
			end
			local f = dist / len
			return x - dx * f, y - dy * f, j
		end
		dist -= len
		x, y = px, py
		j -= 1
	end
	return x, y, 1
end

-- ---------------------------------------------------------------------------------------------
-- Buildings
-- ---------------------------------------------------------------------------------------------

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII" }

--- A building's rank as it is cut on its plate: a Roman numeral, plain figures past XII.
function MapStyle.rank_text(level: number): string
	return ROMAN[level] or tostring(level)
end

--- The bar's colours: being raised, reloading, and reloaded soon. Progress at or above BAR_SOON is "soon".
MapStyle.BAR_RAISE = Color3.fromRGB(232, 190, 92)
MapStyle.BAR_RELOAD = Color3.fromRGB(128, 176, 214)
MapStyle.BAR_READY = Color3.fromRGB(226, 240, 250)
MapStyle.BAR_SOON = 0.85

--- Which of them, as a small number (a plate writes the colour only when this changes).
function MapStyle.bar_state(progress: number, building: boolean): number
	if building then
		return 1
	end
	return if progress >= MapStyle.BAR_SOON then 3 else 2
end

function MapStyle.bar_color(state: number): Color3
	return if state == 1 then MapStyle.BAR_RAISE elseif state == 3 then MapStyle.BAR_READY else MapStyle.BAR_RELOAD
end

-- ---------------------------------------------------------------------------------------------
-- Whose it is: buildings and landmarks wear their owner's colour
-- ---------------------------------------------------------------------------------------------
-- A building's plate and a held landmark's disc are the owner's colour; the glyph on it is dark ink or pale paper,
-- whichever stands out more from that colour (the larger contrast ratio, as for text); the rim is a deep shade of the
-- colour, so the token parts from its own land, which is the same colour under a wash. Worked out when the owner
-- or the colour changes, never a frame.

--- Glyphs: dark on a light colour, pale on a dark one.
MapStyle.GLYPH_DARK = Color3.fromRGB(20, 18, 24)
MapStyle.GLYPH_LIGHT = Color3.fromRGB(250, 246, 236)
--- An owner colour darker than this (relative luminance) is lifted towards the pale this much for a plate: a plate's
--- rim is always a dark of its fill, and on the darkest colours both would sink into the land under them.
MapStyle.LIFT_BELOW = 0.1
MapStyle.LIFT = 0.3
--- A building being raised: its owner's colour, this far towards a dull clay.
MapStyle.RAISE_CLAY = Color3.fromRGB(150, 138, 118)
MapStyle.RAISE_MIX = 0.55
--- An unheld landmark: a plain light disc and a grey rim.
MapStyle.NEUTRAL = Color3.fromRGB(240, 236, 226)
MapStyle.NEUTRAL_RIM = Color3.fromRGB(70, 72, 80)

local function channel(v: number): number
	return if v <= 0.04045 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
end

--- Relative luminance (0 black .. 1 white) of a colour.
function MapStyle.luminance(c: Color3): number
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

--- The contrast ratio of two luminances (1 .. 21).
local function ratio(a: number, b: number): number
	return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end

local DARK_L = MapStyle.luminance(MapStyle.GLYPH_DARK)
local LIGHT_L = MapStyle.luminance(MapStyle.GLYPH_LIGHT)

--- The glyph colour on a fill: whichever of the dark and the pale stands out more.
function MapStyle.glyph_on(fill: Color3): Color3
	local l = MapStyle.luminance(fill)
	return if ratio(l, DARK_L) >= ratio(l, LIGHT_L) then MapStyle.GLYPH_DARK else MapStyle.GLYPH_LIGHT
end

--- True when the dark glyph is the one on this fill (a light colour).
function MapStyle.is_light(fill: Color3): boolean
	return MapStyle.glyph_on(fill) == MapStyle.GLYPH_DARK
end

--- A building's plate colour for its owner's colour (`raising`: still being built).
function MapStyle.plate_fill(owner: Color3, raising: boolean?): Color3
	local c = owner
	if MapStyle.luminance(c) < MapStyle.LIFT_BELOW then
		c = c:Lerp(MapStyle.GLYPH_LIGHT, MapStyle.LIFT)
	end
	if raising then
		c = c:Lerp(MapStyle.RAISE_CLAY, MapStyle.RAISE_MIX)
	end
	return c
end

--- A disc's rim for its fill: always a deep shade of it, like a building plate's rim (the owner asked for a dark
--- outline on every map token, 2026-11-03; a pale ring round a dark disc read as a second disc).
function MapStyle.rim_on(fill: Color3): Color3
	local h, s, v = fill:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.1), math.min(v * 0.22, 0.16))
end

-- ---------------------------------------------------------------------------------------------
-- Names on the land: as an atlas letters them, the nation in capitals, its strength beside it
-- ---------------------------------------------------------------------------------------------

--- Letter colours: paper, tinted by the owner's colour this much (nations, clans a little less).
MapStyle.PAPER = Color3.fromRGB(246, 238, 220)
MapStyle.INK = Color3.fromRGB(18, 15, 22)
MapStyle.TINT_NATION = 0.22
MapStyle.TINT_CLAN = 0.14
--- A clan's letters and strokes are this see-through: nations stand out over the small fry.
MapStyle.CLAN_FADE = 0.2
--- Strength beside the name: its size against the name's, and its colour.
MapStyle.TROOP_K = 0.74
MapStyle.TROOP_COLOR = Color3.fromRGB(242, 208, 134)
--- A name line's width in font sizes: a letter, a capital, and the room kept for "12.3K" beside it (less than
--- it takes: a name may run a little over its land, a phone's small nations stay readable).
MapStyle.LETTER_W = 0.42
MapStyle.CAPS_K = 1.16
MapStyle.TROOP_CHARS = 3.5

--- What a name reads on the map: a nation's in capitals, a person's as they wrote it.
function MapStyle.label_text(name: string, is_person: boolean): string
	return if is_person then name else string.upper(name)
end

--- The letters' colour for an owner's colour.
function MapStyle.label_fill(col: Color3, is_person: boolean, is_clan: boolean): Color3
	if is_person then
		return MapStyle.PAPER
	end
	return MapStyle.PAPER:Lerp(col, if is_clan then MapStyle.TINT_CLAN else MapStyle.TINT_NATION)
end

--- The font size that fits a name of `len` characters and its strength on one line in a box (full-size tiles).
function MapStyle.label_fit(width: number, height: number, len: number, is_person: boolean): number
	local chars = math.max(len, 1) * (if is_person then 1 else MapStyle.CAPS_K) + MapStyle.TROOP_CHARS * MapStyle.TROOP_K
	return math.min(width / (chars * MapStyle.LETTER_W), height / 2.4)
end

return MapStyle
