--!strict
-- Roblox badges (release 2026-11-07): free discovery on a player's profile, and a small moment of pride. The owner makes
-- each on the Creator Dashboard (Engagement > Badges) and pastes its id here; an id of 0 is never awarded. The server
-- awards them (server/Badges): it knows a join, a public war it measured, and a solo result.
local Badges = {}

Badges.LIST = {
	welcome = { id = 466974998922347, name = "Called to Arms", description = "Joined Warhold." },
	first_win = { id = 2260698226267658, name = "First Victory", description = "Won your first war." },
	public_win = { id = 196257961709729, name = "Victor of an Open War", description = "Won a war against other players." },
	warlord = { id = 240588980520706, name = "Warlord's Triumph", description = "Won a war alone at Warlord." },
}

--- The badge's id, or 0 when it isn't made yet.
function Badges.id(key: string): number
	local b = Badges.LIST[key]
	return if b ~= nil then b.id else 0
end

return Badges
