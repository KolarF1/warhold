--!strict
-- Awards the badges of Data/Badges (release 2026-11-07). Each is asked of Roblox at most once a session per player, in
-- the background; a badge whose id is 0 (not made yet) is skipped, and any error from Roblox is only logged.
local Badges = {}

local Data: any = if typeof(game) == "Instance"
	then require(game:GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Badges)
	else (require :: any)("../shared/Data/Badges")

local given: { [any]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any
local service: any = nil

--- Award `key` to `player` (a Player). Never yields the caller.
function Badges.award(player: any, key: string)
	local id = Data.id(key)
	if id == 0 or player == nil then
		return
	end
	local mine = given[player] or {}
	given[player] = mine
	if mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		local ok, err = pcall(function()
			service = service or game:GetService("BadgeService")
			if not service:UserHasBadgeAsync(player.UserId, id) then
				service:AwardBadge(player.UserId, id)
			end
		end)
		if not ok then
			warn("[Warhold] badge " .. key .. ": " .. tostring(err))
		end
	end)
end

return Badges
