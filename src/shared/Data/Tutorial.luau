--!strict
-- A new player's first match, designed for phones first: the first tap is marked, a spot is taken for them after
-- AUTO_SPAWN_S, and the first minutes are a list of small goals with a reward at the end, on a match with fewer clans in
-- the way (TRIBES) and the gentlest AI (DIFFICULTY).
--
-- The match is an ordinary solo match otherwise: it goes on after the last step. client/UI/Tutorial
-- runs the steps; server/Analytics logs them as the "Tutorial" funnel (FUNNEL); the Stars are paid
-- once per player (server/Purchases.tutorial_bonus).
local Tutorial = {}

--- Renown for finishing it (the key keeps its old name; a start towards the cheapest War College unlock).
Tutorial.STARS = 1500
--- Clans on the tutorial's map (a normal war has Rules.DEFAULT_TRIBES, 400): room to grow fast.
Tutorial.TRIBES = 48
Tutorial.DIFFICULTY = 0
--- Ticks (10 a second) from placing the capital to the match starting. A solo match waits 50, but
--- (2026-10-04) a 5 s wait after placing the capital confused new players, so the tutorial's round
--- starts much sooner.
Tutorial.COUNTDOWN_TICKS = 10
--- The send while the tutorial runs: it starts at 10%, the first preset (RATIO_START: a first order leaves most of the
--- army at home) and stops at RATIO_CAP (2026-10-04; the presets above it can't be picked while it runs).
Tutorial.RATIO_START = 0.10
Tutorial.RATIO_CAP = 0.5
--- Keeps players from going too low in troop count (2026-10-04): while the tutorial
--- runs an order leaves at least TROOP_FLOOR of the army's cap at home (it is trimmed to what may go,
--- and refused when nothing may). The floor holds from the first time the army reaches FLOOR_ARM of
--- its cap (a new nation starts below it), or from FLOOR_ARM_S seconds into play, whichever comes
--- first (floor_armed).
---   * The seconds since 2026-10-27: a new nation starts at about a fifth of its cap, so a player who
---     sent every troop as it came never reached FLOOR_ARM, and the floor never held for the very
---     players it is for.
---   * Not before the FLOOR_FROM step: until the first neighbour there is nobody to fear, and the cap climbs with every
---     tile taken, so it would refuse the very orders the line asks for. The Send bar's cap (RATIO_CAP) still holds.
Tutorial.TROOP_FLOOR = 0.25
Tutorial.FLOOR_ARM = 0.35
Tutorial.FLOOR_ARM_S = 10
Tutorial.FLOOR_FROM = "attack"
Tutorial.FLOOR_REASON = "Your home guard must stay. More are coming"
--- A new player's first ROOKIE_MATCHES matches (the tutorial's among them) keep a floor under the
--- army after the tutorial too (2026-10-27): an order leaves ROOKIE_FLOOR of the army's cap at home,
--- from the time it arms (floor_armed; client/UI/UIAdvisor.check_floor). An army
--- spent below a fifth of its cap all but loses the match. The first order held back in a match
--- says why (Coach "floor").
Tutorial.ROOKIE_MATCHES = 5
Tutorial.ROOKIE_FLOOR = 0.2

--- True while a player with `matches_before` matches before this one is still a new player.
function Tutorial.rookie(matches_before: number): boolean
	return matches_before < Tutorial.ROOKIE_MATCHES
end

--- True once the floor under a new player's army holds: the army has `troops` of its `cap`, at
--- FLOOR_ARM of it or more, or the match has been played `played_s` seconds, FLOOR_ARM_S or more.
function Tutorial.floor_armed(troops: number, cap: number, played_s: number): boolean
	return played_s >= Tutorial.FLOOR_ARM_S or (cap > 0 and troops >= Tutorial.FLOOR_ARM * cap)
end
--- Seconds on the spawn step before a start is picked for the player.
Tutorial.AUTO_SPAWN_S = 14
--- "attack": passed over when nobody borders the player this long after the step began. (The Send bar's and doctrine's
--- steps come before it since 2026-11-01: this game opens with a doctrine, not a border fight.)
Tutorial.CONTACT_WAIT_S = 25
--- The send step asks for RATIO_GOAL (25%, a preset: 2026-11-03, the strategy frame), anywhere from RATIO_LOW to
--- RATIO_HIGH, left there for RATIO_HOLD_S: one press on the 25% button (the send panel at the bottom right) or the key 2. Never more:
--- since 2026-10-04 the tutorial never encourages an attack with everything (it leaves the nation empty). Above
--- RATIO_HIGH the card says to go back.
---   * Nobody waits on it past RATIO_MAX_S (the other steps: STEP_MAX_S).
Tutorial.RATIO_GOAL = 0.25
Tutorial.RATIO_NAME = "25%"
Tutorial.RATIO_LOW = 0.2
Tutorial.RATIO_HIGH = 0.3
Tutorial.RATIO_HOLD_S = 0.2
Tutorial.RATIO_MAX_S = 30
Tutorial.RATIO_TOO_MUCH = "That leaves home bare. Back to 25%"
--- A step nobody finishes in this long is passed over (the player is never stuck on one).
Tutorial.STEP_MAX_S = 75
--- With no order for this long the pointer shows where to tap again.
Tutorial.NUDGE_S = 5

--- The steps, in order: Warhold's own opening. Banner, first doctrine, claim land, the Send bar, the first building,
--- what the ages open, a first march, then an age change seen live. `touch` / `desktop`: what the line beside the spot
--- says; `%s` is the neighbour's name. `part`: which of the four marks at the head of the line it belongs to: the
--- founding, the land, the buildings and the march, the ages. `bar`: the step's own mark fills as it goes.
Tutorial.PARTS = 4
Tutorial.STEPS = {
	{ id = "spawn", part = 1, touch = "Plant your banner on any free land", desktop = "Plant your banner on any free land" },
	-- (the draft of the opening is on screen from the first second of play; folded, it waits as an amber diamond badge)
	{
		id = "doctrine",
		part = 1,
		touch = "Choose what your nation will be",
		desktop = "Choose what your nation will be",
		chip = "Tap the amber diamond, then choose",
		chip_desktop = "Click the amber diamond, then choose",
	},
	{ id = "expand", part = 2, touch = "Free land lies at your border. Take it", desktop = "Free land lies at your border. Take it" },
	-- (the send before the next order: it starts at 10%, and this one sets how a ruler sends from now on)
	{
		id = "ratio",
		part = 2,
		touch = "Tap 25% under SEND: the rest guard home",
		desktop = "Press 25% under SEND (or key 2): the rest guard home",
		max_s = Tutorial.RATIO_MAX_S,
	},
	{
		id = "city",
		part = 3,
		touch = "Tap Build, then raise a City",
		desktop = "Dawn opens the City. Press it at the bottom, then raise one",
	},
	-- Lessons: no action to take, a card to read and a Next to press. `body` is plain text with {keys} filled in by the
	-- UI from Rules (so the numbers are never out of date); `kinds` lists build kinds whose own one-line blurb
	-- (UIRules.BLURBS) is shown under it.
	{
		id = "ages",
		part = 3,
		kind = "lesson",
		touch = "Each age opens new buildings",
		desktop = "Each age opens new buildings",
		body = "Dawn gives you Cities, each worth {city} more troops, and Harbors. Expansion opens Foundries, Bastions and Frigates. Conflict opens Flak and Launch Sites. Gold comes in every second, and troops come back free. Each building of a kind costs more than the last.",
	},
	{
		id = "attack",
		part = 3,
		touch = "Tap %s, then press ATTACK",
		desktop = "March on %s: click their land",
	},
	-- (nothing to do but play: its mark fills towards the second age, and the draft that comes with it)
	{
		id = "age",
		part = 4,
		touch = "A new age is near. Hold your ground",
		desktop = "A new age is near. Hold your ground",
		bar = true,
		max_s = 150,
	},
	{
		id = "newage",
		part = 4,
		kind = "lesson",
		touch = "The Expansion has begun",
		desktop = "The Expansion has begun",
		body = "Pick your next doctrine, and Foundries, Bastions and Frigates are open to you. A war has four ages: Dawn, Expansion, Conflict, Reckoning. The WAR ROOM on the title screen has orders, missions and your record.",
	},
	{
		id = "landmarks",
		part = 4,
		kind = "lesson",
		touch = "Fight for landmarks",
		desktop = "Fight for landmarks",
		body = "Round badges on the map mark landmarks, like Gold Mines (a pickaxe) and Garrisons (a tent). Whoever owns the ground under one gets its bonus: a Gold Mine adds {mint}% to your gold, a Garrison {garrison}% to your troop cap. In the Reckoning they pay double.",
	},
}

--- The "Tutorial" funnel's steps (Creator Dashboard): 1 is the match starting, then one a step,
--- then finishing. A step passed over is not logged.
Tutorial.FUNNEL = {
	"Started",
	"Spawned",
	"Chose Doctrine",
	"First Tap",
	"Used Slider",
	"Built City",
	"Learned Ages",
	"Attacked",
	"Saw Age Change",
	"Learned New Age",
	"Learned Landmarks",
	"Completed",
}
--- A lesson is read, not done: a step with `kind = "lesson"`.
Tutorial.LESSON_MAX_S = 90

--- The funnel step of finishing step `id` (2..#STEPS + 1), or nil.
function Tutorial.funnel_step(id: string): number?
	for i, s in Tutorial.STEPS do
		if s.id == id then
			return i + 1
		end
	end
	return nil
end

--- True for a player who has never played: no tutorial state, no match counted, no tip seen.
--- `ui` is the saved [ui] settings, `stats` the saved [stats] ({ matches }).
function Tutorial.is_new(ui: any, stats: any): boolean
	local u = if type(ui) == "table" then ui else {}
	local s = if type(stats) == "table" then stats else {}
	if type(u.tutorial) == "string" and u.tutorial ~= "" then
		return false
	end
	if (tonumber(s.matches) or 0) > 0 then
		return false
	end
	if type(u.tips_seen) == "table" and next(u.tips_seen) ~= nil then
		return false
	end
	return true
end

--- Where step `id` is in STEPS, or nil.
function Tutorial.step_index(id: string): number?
	for i, s in Tutorial.STEPS do
		if s.id == id then
			return i
		end
	end
	return nil
end

return Tutorial
