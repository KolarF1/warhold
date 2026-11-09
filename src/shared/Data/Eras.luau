--!strict
-- Eras (Warhold's own): a match has an arc. Four eras by ticks since play began; each of the first three
-- opens a Doctrine draft (Data/Doctrines) and the last, the Reckoning, doubles what landmarks
-- pay. Pure data and pure functions: the Sim, the client mirror and the UI all read the same table (the
-- Sim puts it in its snapshot as `eras`, so a client never guesses a match's own).
local Eras = {}

Eras.NAMES = { "Dawn", "Expansion", "Conflict", "Reckoning" }
--- One line each: what the era is for (shown on the banner and the Dominion panel).
Eras.BLURBS = {
	"Choose your first doctrine. Claim land and find your neighbours.",
	"Foundries, Bastions and Frigates open. Take your first landmarks.",
	"Flak and Launch Sites open. The fronts harden.",
	"Landmarks pay double. Finish it.",
}
--- Ticks (10 a second) since the start of play at which each era begins.
Eras.DEFAULT = { 0, 1500, 4500, 8100 } -- 0:00, 2:30, 7:30, 13:30
--- The tutorial's match: the second age comes as soon as its steps are done, so the player sees an age change.
Eras.TUTORIAL = { 0, 1200, 4200, 7800 }

--- The ages scale to the map (owner's call, 2026-11-06): a map that is one big landmass is fought out in 6 to 10
--- minutes (bot audit: Spine, Europe, Crescent, Primeval, the Americas, Africa), so its ages come sooner and the
--- Conflict and the Reckoning arrive before someone wins; World, split by oceans, runs 20 to 30 and keeps the
--- DEFAULT starts. What sets the pace is how much of the land is one landmass (Eras.MAINLAND), not land per
--- nation: World has the least land per nation of all and is the slowest, so a land-per-nation rule would rush it most.
--- Mainland share at or under SCALE_FULL_AT: scale 1; at or over SCALE_MIN_AT: SCALE_MIN; linear between.
Eras.SCALE_FULL_AT = 0.5
Eras.SCALE_MIN_AT = 0.9
Eras.SCALE_MIN = 0.45
--- The floor: no age is shorter than this (90 s: a doctrine draft's 60 s, with room to play the pick).
Eras.MIN_AGE_TICKS = 900

--- Each map's mainland share: the largest 4-connected landmass over all its land (measured on the full-size
--- terrain; tests/eras_scale.luau recomputes it, so a redrawn map that drifts fails there). A map not listed: scale 1.
Eras.MAINLAND = {
	africa = 0.98,
	asia = 0.95,
	crescent = 1.00,
	europe = 0.90,
	marenostrum = 1.00,
	northamerica = 0.89,
	primeval = 1.00,
	southamerica = 1.00,
	spine = 1.00,
	thousandisles = 0.20,
	twinrealms = 1.00,
	world = 0.40,
} :: { [string]: number }

--- How fast the ages come on a map whose largest landmass holds `mainland` (0..1) of the land: 1 = DEFAULT.
--- Nil or junk (a map we have no number for): 1.
function Eras.map_scale(mainland: number?): number
	if type(mainland) ~= "number" or mainland ~= mainland then
		return 1
	end
	local k = (mainland - Eras.SCALE_FULL_AT) / (Eras.SCALE_MIN_AT - Eras.SCALE_FULL_AT)
	if k <= 0 then
		return 1
	elseif k >= 1 then
		return Eras.SCALE_MIN
	end
	return 1 - k * (1 - Eras.SCALE_MIN)
end

--- The age scale of map `map_id` ("spine", or a smaller build "spine@50": the same map, the same scale).
function Eras.scale_for_map(map_id: string?): number
	if type(map_id) ~= "string" then
		return 1
	end
	return Eras.map_scale(Eras.MAINLAND[string.match(map_id, "^(.-)@%d+$") or map_id])
end

--- `starts` (default DEFAULT) with every start times `scale`, whole ticks, each age at least MIN_AGE_TICKS long
--- (scale 1 or more: the starts as they are). Always a valid table.
function Eras.scaled(scale: number, starts: { number }?): { number }
	local s = starts or Eras.DEFAULT
	local out = table.clone(s)
	if type(scale) ~= "number" or scale ~= scale or scale >= 1 then
		return out
	end
	for i = 2, #s do
		out[i] = math.max(math.floor(s[i] * math.max(scale, 0) + 0.5), out[i - 1] + Eras.MIN_AGE_TICKS)
	end
	return out
end

--- The age (1..4) each kind opens in (Warhold's own: the first buildings differ from an inherited build bar). The Sim
--- refuses a kind before its age, for people and AI alike (a match without doctrines has no ages: everything is open).
--- The War College's Long Guns and Aerodrome open in the Conflict, so a win has minutes left to use what was earned; its
--- Lance Cannon waits for the Reckoning: late, loud, and for finishing a war.
Eras.BUILD_OPENS = {
	city = 1,
	port = 1,
	factory = 2,
	defense = 2,
	warship = 2,
	sam = 3,
	silo = 3,
	artillery = 3,
	airfield = 3,
	railgun = 4,
	-- (a depth match's buildings, docs/DEPTH_DESIGN.md: food and markets from the start, barracks and forts with the
	-- Expansion)
	farm = 1,
	market = 1,
	barracks = 2,
	fort = 2,
} :: { [string]: number }
--- Landmark bonuses in the last era.
Eras.RECKONING_LANDMARK_MULT = 2.0

--- The era (1..#starts) `since_play` ticks into play falls in; 1 before play and for junk.
function Eras.index(since_play: number, starts: { number }?): number
	local s = starts or Eras.DEFAULT
	local t = if type(since_play) == "number" and since_play == since_play then since_play else 0
	local era = 1
	for i = 2, #s do
		if t >= s[i] then
			era = i
		end
	end
	return era
end

--- Ticks until the next era begins (nil in the last one).
function Eras.ticks_to_next(since_play: number, starts: { number }?): number?
	local s = starts or Eras.DEFAULT
	local era = Eras.index(since_play, s)
	if era >= #s then
		return nil
	end
	return s[era + 1] - math.max(since_play, 0)
end

--- The doctrine draft an era opens. Ours starts in the first minute: draft 1 at once, then one each age until the
--- drafts run out (the last age is for finishing). The tutorial teaches the first draft as its second step, so it runs the same.
function Eras.draft_of(era: number, _starts: { number }?): number
	return math.min(era, 3)
end

--- The age a build kind opens in (a kind not listed: the first).
function Eras.opens_in(kind_name: string): number
	return Eras.BUILD_OPENS[kind_name] or 1
end

--- True when `kind_name` may be built in age `era`.
function Eras.build_open(kind_name: string, era: number): boolean
	return era >= Eras.opens_in(kind_name)
end

--- "Opens in the Conflict": what a locked slot's card says (the same words as the build window).
function Eras.opens_text(kind_name: string): string
	return "Opens in the " .. (Eras.NAMES[Eras.opens_in(kind_name)] or Eras.NAMES[1])
end

--- True when `starts` is a usable era table: numbers, strictly rising, the first 0, four of them.
function Eras.valid(starts: any): boolean
	if type(starts) ~= "table" or #starts ~= #Eras.NAMES or starts[1] ~= 0 then
		return false
	end
	for i = 2, #starts do
		if type(starts[i]) ~= "number" or starts[i] ~= starts[i] or starts[i] <= starts[i - 1] then
			return false
		end
	end
	return true
end

return Eras
