--!strict
-- Depth (docs/DEPTH_PLAN.md, docs/DEPTH_DESIGN.md): the constants of every depth system, by pace. A match runs at
-- `long` (the new normal: every system at full pace) or `quick` (today's pace: the same systems, faster clocks); a
-- match without `depth` in its config runs none of them. Seconds are match seconds (Defs.TICK_RATE ticks).
local Depth = {}

export type Pace = { [string]: any }

Depth.KEYS = { "long", "quick" }

local long: Pace = {
	-- Phase 1: provinces. A province is held by whoever owns more than this share of its land.
	hold_share = 0.5,
	--- Dirty provinces recounted each tick at most (the rest wait their turn: the cost stays flat).
	recount_per_tick = 200,
	--- Land outside the provinces you hold counts this much toward income and the troop cap.
	loose_land = 0.7,
	--- Whole-province handovers (revolts, peace deals, sieges): tiles moved a tick at most.
	handover_per_tick = 2500,

	-- Phase 2: taxes, unrest, manpower, food, buildings.
	--- Gold a second per weighted tile of the provinces you hold (a 10-province realm: about 600), and a Market's.
	tax_per_tile = 0.06,
	market_gold = 160,
	--- Low / Fair / High / Crushing: gold, and the unrest each aims for.
	tax_gold = { 0.7, 1.0, 1.3, 1.6 },
	tax_unrest = { 0, 10, 28, 55 },
	--- Unrest moves toward its target this much a second (twice as fast down).
	unrest_rate = 0.25,
	--- From this unrest gold and regrowth fall, to x unrest_floor at 100; revolts from revolt_at, every revolt_s.
	unrest_hurts = 50,
	unrest_floor = 0.6,
	revolt_at = 80,
	revolt_s = 45,
	revolt_relief = 15,
	--- War exhaustion: losses against the troop cap (x exhaust_k), decaying each second; a province lost.
	exhaust_k = 25,
	exhaust_max = 30,
	exhaust_decay = 0.985,
	province_lost_unrest = 6,
	--- Overextension: provinces held past base + per age, each this much unrest (up to max).
	provinces_base = 18,
	provinces_per_age = 10,
	overextend_k = 0.8,
	overextend_max = 30,
	--- Food: made a second per weighted tile of plains / hills, by a Farm's level; eaten by troops at home and at war.
	food_plains = 0.004,
	food_hills = 0.0025,
	farm_food = 30,
	--- (troops are kept at ten times what the screen shows: these are per kept troop. Studio 2026-11-09: at 0.0002 a
	--- new realm starved in minutes)
	food_home = 0.00003,
	food_war = 0.0002,
	--- Every realm's capital feeds this much a second whatever it holds.
	food_capital = 3,
	food_start = 3000,
	food_store_s = 300,
	--- Starving: regrowth and attacks fall, unrest rises.
	starving_regen = 0.3,
	starving_atk = 0.85,
	starving_unrest = 20,
	--- Manpower: the pool regrowth draws on refills at mp_rate of the cap a second, holds mp_cap of it; barracks add.
	mp_rate = 0.012,
	mp_cap = 0.6,
	barracks_mp = 0.15,
	barracks_mp_cap = 0.05,
	barracks_cap = 0.04,
	barracks_cap_levels = 8,
	--- A fort: attacks on its province cost this much more a level (up to fort_max levels) and take longer.
	fort_mag = 0.35,
	fort_cost = 0.25,
	fort_max = 3,
	--- Supply lines: attacks lose up to supply_max more, from supply_free tiles from a held province's capital over
	--- supply_span tiles.
	supply_free = 60,
	supply_span = 200,
	supply_max = 0.5,

	-- Phase 3: rulers. A year of a ruler's life passes every year_s seconds.
	year_s = 15,

	-- Phase 4: diplomacy.
	--- A province you held this lately is a claim.
	claim_s = 300,
	--- A war without a reason: unrest at once, aggression (others' standing toward you), fading by ae_decay a second.
	nocb_unrest = 15,
	nocb_ae = 20,
	ae_decay = 0.995,
	--- An AI goes to war without a reason this rarely (it tries again later).
	ai_nocb_chance = 0.15,
	--- A truce after a peace.
	truce_s = 240,
	--- Tribute: this share of the loser's gold. Vassals pay this share of their income a second.
	tribute_share = 0.3,
	vassal_share = 0.2,
	--- A vassal is no bigger than this share of its overlord.
	vassal_size = 0.5,
	--- War score an AI wants before it accepts: white, provinces, tribute, vassal.
	peace_need = { 10, 25, 15, 50 },
	--- After this long a war tires everyone: white peace comes easier.
	weary_s = 600,
	--- A person has this long to answer a peace offer.
	request_s = 60,
	--- The AI weighs peace every ai_peace_stride seconds per realm, after ai_peace_after_s of war; it sues at this
	--- war score, demands at that one.
	ai_peace_stride = 10,
	ai_peace_after_s = 90,
	ai_sue_at = 35,
	ai_demand_at = 40,
	--- Prestige for a peace on terms (per step past white).
	prestige_peace = 10,
	--- A realm drawn into a war bears its aggressor a grudge this long.
	join_grudge_s = 300,

	-- Phase 5: armies.
	--- At most this many armies a realm; each takes up to this share of the troops at home, at least army_min.
	army_max_count = 4,
	army_max_share = 0.8,
	army_min = 2000,
	--- Gold a second per soldier raised; a front army refills this share of its size a second from home.
	army_upkeep = 0.02,
	army_refill = 0.08,
	--- A front army sends this share of its troops into each attack it feeds; a held front makes the enemy's attacks
	--- cost up to hold_k more; a general's skill point makes its attacks this much cheaper (and its battles stronger).
	front_send = 0.5,
	hold_k = 0.6,
	general_k = 0.06,
	--- Battles: the defender's ground and fort; what the winner (by the odds) and the loser lose; how near armies meet.
	battle_mountain = 1.3,
	battle_hills = 1.15,
	battle_fort = 0.25,
	battle_win_loss = 0.35,
	battle_lose_loss = 0.7,
	battle_reach = 4,
	--- Sieges: base seconds, each fort level and development point longer, siege skill and the general shorter; the
	--- besiegers' losses a second and the share sent against the land around every 5 s.
	siege_base_s = 25,
	siege_fort = 0.6,
	siege_dev = 0.05,
	siege_general = 0.05,
	siege_attrition = 0.002,
	siege_send = 0.15,
	--- Tiles an army marches a second.
	march_tiles = 2,
	--- Prestige for a battle won and a siege taken.
	prestige_battle = 5,
	prestige_siege = 8,
	--- The AI's armies: weighed every ai_army_stride seconds per realm, raised with this share of its troops.
	ai_army_stride = 8,
	ai_army_share = 0.35,
	--- An AI army marches to meet an enemy army this near (tiles) to its land or itself.
	ai_intercept = 90,

	-- Phase 6: ambitions and prestige.
	--- "Unite" only for a country of at most this many provinces; "empire" holds this many; "treasury" this much gold.
	unite_max = 30,
	empire_n = 20,
	treasury_gold = 3000000,
	--- Prestige: an ambition, a province taken in war; lost to a revolt or a war without a reason.
	prestige_ambition = 30,
	prestige_province = 2,
	prestige_revolt = 5,
	prestige_nocb = 5,
}

local quick: Pace = table.clone(long)
quick.unrest_rate = 0.5
quick.revolt_s = 30
quick.mp_rate = 0.025
quick.provinces_base = 24
quick.provinces_per_age = 14
quick.exhaust_decay = 0.97
quick.year_s = 8
quick.truce_s = 120
quick.claim_s = 180
quick.weary_s = 300
quick.march_tiles = 3
quick.siege_base_s = 15
quick.empire_n = 14

Depth.PACE = { long = long, quick = quick } :: { [string]: Pace }

--- A Long war's ages run this much longer than today's (Quick keeps today's).
Depth.LONG_AGE_SCALE = 1.5

--- The pace of `key` ("long" / "quick"), or nil (no depth).
function Depth.pace(key: string?): Pace?
	if key == nil then
		return nil
	end
	return Depth.PACE[key]
end

--- A province's weight before the map's normalisation: development and terrain (plains, hills, mountains, frozen).
Depth.TERRAIN_W = { 1.0, 0.9, 0.7, 0.3 }
function Depth.raw_weight(dev: number, terrain: number): number
	return (0.55 + 0.09 * dev) * (Depth.TERRAIN_W[terrain] or 1.0)
end

return Depth
