--!strict
-- Port of scripts/core/ev.gd: event type ids carried in the "ev" array of a Sim delta. Each event
-- is a 1-based Luau array whose first element is one of these ids, followed by the arguments in
-- GDScript order (DESIGN.md §4): { Ev.OWNER_ADD, id, name, color, kind, flags }. Values are part
-- of the network protocol, so never renumber them.
local Ev = {}

Ev.OWNER_ADD = 0 -- id, name, color, kind, flags
Ev.OWNER_OUT = 1 -- id, killer_id
Ev.PHASE = 2 -- phase, ticks_left
Ev.SPAWNED = 3 -- id, tile
Ev.STRUCT_ADD = 4 -- sid, kind, owner, tile
Ev.STRUCT_OWNER = 5 -- sid, new_owner
Ev.STRUCT_DEL = 6 -- sid
Ev.ROAD_ADD = 7 -- rid, sid_a, sid_b, tiles  (a railroad: its tile path from a's end to b's end)
Ev.ROAD_DEL = 8 -- rid (, sid_a, sid_b)
Ev.UNIT_ADD = 9 -- uid, kind, owner, path, start_tick, ticks_per_tile_x100, troops
Ev.UNIT_MOVE = 10 -- uid, tile
Ev.UNIT_DEL = 11 -- uid, reason
Ev.NUKE = 12 -- uid, kind, owner, from_tile, to_tile, launch_tick, flight_ticks
Ev.BOOM = 13 -- uid, kind, tile, radius_tiles, owner
Ev.ATTACK = 14 -- aid, attacker, target, troops, anchor_tile, retreating  (re-sent to update)
Ev.ATTACK_END = 15 -- aid
Ev.ALLY_REQ = 16 -- from, to, created_tick
Ev.ALLY = 17 -- a, b, expires_at
Ev.ALLY_END = 18 -- a, b, traitor_id, expired
Ev.MSG = 19 -- to_owner (-1 all), category, text
Ev.GAME_OVER = 20 -- winner_id, reason
Ev.ALLY_REQ_END = 21 -- from, to   (request answered or expired)
Ev.TRAITOR = 22 -- id, until_tick
Ev.STRUCT_LEVEL = 23 -- sid, level, active_tick  (upgrade, or construction start: active from active_tick)
Ev.SHELL = 24 -- shell_id, shooter_kind (0 warship, 1 defense post), shooter_id (uid / sid), from_tile, target_uid, fire_tick, impact_tick, damage
Ev.UNIT_HP = 25 -- uid, hp, max_hp  (at most once per unit per tick)
Ev.UNIT_VET = 26 -- uid, veterancy_level
Ev.UNIT_STATE = 27 -- uid, state (0 patrolling, 1 retreating, 2 docked / repairing), patrol_tile
Ev.UNIT_PATH = 28 -- uid, path, start_tick, ticks_per_tile_x100  (a warship changed course)
Ev.SAM_LAUNCH = 29 -- sam_sid, nuke_uid, fire_tick, intercept_tick, will_hit  (BOOM radius 0 follows at intercept_tick)
Ev.ALLY_EXT = 30 -- a, b, expires_at, asked  (renewal asked: bit 1 by min(a, b), bit 2 by max(a, b); a renewal resets it to 0)
Ev.CONQUEST = 31 -- conqueror, conquered, gold  (the gold `conqueror` took)
Ev.STRUCT_SHOTS = 32 -- sid, ticks  (SAM / silo: launch or upgrade ticks of its missiles still reloading
--   — each reloads for Rules.SAM / SILO_COOLDOWN_TICKS)

Ev.REINFORCE = 33 -- id, troops, ready_tick  (Reinforcements arrived; the next call is ready at ready_tick)

Ev.BONUS = 34 -- owner, tile, gold  (gold `owner` earned at `tile`, a train's
--   stop at a station. Only for a person, and sent to that person alone)

Ev.DOCTRINE = 35 -- id, draft, a, b, c, chosen, deadline  (Conquer the World: a doctrine draft opened for `id`
--   with offers a, b, c (indices into Data/Doctrines.LIST), or closed: chosen 1..3 = the pick, 0 = open until
--   `deadline`, -1 = closed without one)

Ev.EDICT = 36 -- id, ready_tick, buff_until  (Conquer the World: `id` used an edict; the next is ready at ready_tick;
--   a timed one runs until buff_until, else 0)

Ev.WORLD_EVENT = 37 -- index, start_tick, end_tick, leader  (Conquer the World: a world event began, Data/WorldEvents;
--   leader: the owner a "leader" event falls on, else 0)

Ev.NEMESIS = 38 -- person, nation  (Conquer the World: `nation` is now `person`'s nemesis; 0: it fell)

Ev.CROWN = 39 -- holder, ticks  (Conquer the World: King of the Hill: who holds the Crown, how long they have in all)

Ev.CALL_TO_ARMS = 40 -- id, troops, ready_tick, calls  (`id` called to arms: `troops` joined; the next call is ready at
--   ready_tick; `calls`: how many it has made this match, which sets the next price: Rules.call_cost)

Ev.RULER = 41 -- id, name, num, age, trait1, trait2, trait3, cause  (a depth match: `id`'s ruler; cause 0 = the
--   first, 1 = an heir after a death; traits are indices into Data/Rulers.TRAITS, 0 = none)

Ev.WAR = 42 -- a, b, cb  (a depth match: `a` went to war with `b`; cb 1 = with a reason)
Ev.PEACE = 43 -- a, b, terms, winner  (their war ended: terms 1 white, 2 provinces, 3 tribute, 4 vassal; 0 = one fell)
Ev.PEACE_REQ = 44 -- from, to, terms, tick  (`from` offers `to` peace on `terms` 1-4, which `from` wins; 11-14: `from` yields
--   them, `to` wins; 0 = the offer closed)

Ev.BATTLE = 45 -- tile, winner, loser, winner_losses, loser_losses  (a depth match: two armies met)
Ev.SIEGE = 46 -- province, taker, defender  (a siege ended: the province passes)

Ev.AMBITION = 47 -- id, index, kind  (a depth match: `id` fulfilled its ambition `index`, SimAmbitions.KINDS[kind])

--- Number of event ids (ids are 0..COUNT-1).
Ev.COUNT = 48

return Ev
