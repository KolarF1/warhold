--!strict
-- Which soundtrack mood fits the moment (AudioDirector.set_music_mood). Pure logic, polled by UIRoot:
--   title    the title screen                     wait     a public match's waiting room
--   calm     a match, no fighting                 war      fighting a nation or a player
--   victory  the match is over and we won          defeat   the match is over for us (lost, or out)
-- War: an attack between us and a nation or a player (clans don't count: early expansion isn't a war) that
-- has lasted WAR_ONSET_S, so a border skirmish keeps the calm, or a warhead of ours or at our land, which
-- brings it at once. It lasts WAR_HOLD_S after the last sign of fighting, so the music doesn't flip back and forth.

local Cadence = require("./Cadence")

local MusicMood = {}
MusicMood.__index = MusicMood

MusicMood.WAR_HOLD_S = Cadence.WAR_HOLD_S
MusicMood.WAR_ONSET_S = Cadence.WAR_ONSET_S
local KIND_TRIBE = 1 -- Defs.KIND_TRIBE

export type Input = {
	screen: string, -- UIRoot screen: "title", "spawn", "play", "over"
	waiting: boolean, -- queued for / in a public match's waiting room
	me: number, -- our nation (0: spectating)
	alive: boolean,
	winner: number,
	fighting: boolean, -- MusicMood.fighting(state, me) this poll
	struck: boolean?, -- its second answer: a warhead is in the air (war at once)
}

function MusicMood.new()
	local self = setmetatable({}, MusicMood) :: any
	self._war_until = -math.huge
	--- when the fighting now going on began (nil: none going on)
	self._fight_since = nil :: number?
	return self
end

--- Any sign of war for `me` in `st` (GameState): attacks with a nation / player, warheads; and whether a
--- warhead is among them.
function MusicMood.fighting(st: any, me: number): (boolean, boolean)
	if st == nil or me == 0 then
		return false, false
	end
	local owners = st.owners or {}
	local function rival(id: number): boolean
		local o = owners[id]
		return id ~= 0 and id ~= me and o ~= nil and o.kind ~= KIND_TRIBE
	end
	local tile_owner = st.tile_owner
	for _, n in st.nukes or {} do
		if n.owner == me then
			return true, true
		end
		if tile_owner ~= nil and tile_owner(st, n.to_tile) == me then
			return true, true
		end
	end
	for _, a in st.attacks or {} do
		if (a.attacker == me and rival(a.target)) or (a.target == me and rival(a.attacker)) then
			return true, false
		end
	end
	return false, false
end

function MusicMood.mood(self: any, input: Input, now_s: number): string
	if input.screen == "title" then
		self._war_until = -math.huge
		self._fight_since = nil
		return if input.waiting then "wait" else "title"
	end
	if input.me == 0 then
		return "calm" -- watching a match
	end
	if input.screen == "over" or not input.alive then
		return if input.winner ~= 0 and input.winner == input.me then "victory" else "defeat"
	end
	if input.fighting then
		local since = self._fight_since or now_s
		self._fight_since = since
		-- (a war already on goes on; a skirmish must last to start one)
		if input.struck or now_s < self._war_until or now_s - since >= MusicMood.WAR_ONSET_S then
			self._war_until = now_s + MusicMood.WAR_HOLD_S
		end
	else
		self._fight_since = nil
	end
	return if now_s < self._war_until then "war" else "calm"
end

return MusicMood
