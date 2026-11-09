--!strict
-- The game's Roblox community (group), 2026-11-09: the owner asked for it to be offered in the game. Players join it
-- with Roblox's own prompt (GroupService:PromptJoinAsync, client side) from the title screen's COMMUNITY row, the
-- Field Guide's credits, and once on the results screen after a player's first win or first war lasting 10 minutes.
-- No reward is given for joining (yet: the timeline's week-3 "thank you for joining" gift will read the same id).
local Community = {}

--- roblox.com/communities/1025226214 (owned by the game's owner)
Community.ID = 1025226214
--- The results screen's offer comes once per player; a war this long (seconds alive) or a win earns it.
Community.OFFER_AFTER_S = 600
--- What a prompt came to, as the analytics reports it (Enum.GroupMembershipStatus names, ours on the right).
Community.RESULTS = {
	Joined = "joined",
	JoinRequestPending = "pending",
	AlreadyMember = "member",
	None = "none",
}

return Community
