--!nonstrict
-- The bot players' avatars (Data/BotLooks), built on the server: one small model per look number in
-- ReplicatedStorage.BotAvatars (named by the number), which every client clones into the picture beside a bot's name
-- (client UI/BotPortrait). Roblox only (MatchServer.deps.bot_looks).
--
-- Why the server builds them: Players:CreateHumanoidModelFromDescription is the one way to put catalog items on a
-- rig, and its reference page does not say a LocalScript may call it; the server surely can. Built once per look
-- for the whole server, they reach every client by replication, and a client never loads a look twice.
--
-- What is built: an R6 rig cut down to a bust (Head, Torso, the hair / hat / glasses on the head and the shirt on
-- the torso; arms, legs and scripts removed, everything anchored): the cheapest thing that reads as a head shot.
-- The pants are on the description too but the legs are cut off: a head shot never shows them.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local BotLooks = require(RS:WaitForChild("Airfront"):WaitForChild("Data"):WaitForChild("BotLooks")) :: any

local BotAvatars = {}

BotAvatars.FOLDER = "BotAvatars"
--- Looks kept from earlier matches before the folder is cleared (a match has about 30 bots).
BotAvatars.KEEP = 120

local queue: { number } = {}
local queued: { [number]: boolean } = {}
local running = false

local function folder(): Folder
	local f = RS:FindFirstChild(BotAvatars.FOLDER)
	if f == nil then
		f = Instance.new("Folder")
		f.Name = BotAvatars.FOLDER
		f.Parent = RS
	end
	return f :: Folder
end

local function description(look: any): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(look.skin[1], look.skin[2], look.skin[3])
	d.HeadColor = skin
	d.TorsoColor = skin
	d.LeftArmColor = skin
	d.RightArmColor = skin
	d.LeftLegColor = skin
	d.RightLegColor = skin
	d.Face = look.face
	d.HairAccessory = tostring(look.hair)
	d.HatAccessory = if look.hat ~= nil then tostring(look.hat) else ""
	d.FaceAccessory = if look.glasses ~= nil then tostring(look.glasses) else ""
	d.Shirt = look.shirt
	d.Pants = look.pants
	return d
end

local CUT = { "Left Arm", "Right Arm", "Left Leg", "Right Leg", "Animate", "Health" }

local function build(n: number)
	local look = BotLooks.look(n)
	local f = folder()
	if look == nil or f:FindFirstChild(tostring(n)) ~= nil then
		return
	end
	-- (the Async name is the current one; the plain one is deprecated but still there on older builds)
	local ok, model = pcall(function()
		return (Players :: any):CreateHumanoidModelFromDescriptionAsync(description(look), Enum.HumanoidRigType.R6)
	end)
	if not ok then
		ok, model = pcall(function()
			return Players:CreateHumanoidModelFromDescription(description(look), Enum.HumanoidRigType.R6)
		end)
	end
	if not ok or model == nil then
		warn("[BotAvatars] look " .. tostring(n) .. " could not be built: " .. tostring(model))
		return -- (the client shows a silhouette in the bot's colour)
	end
	for _, name in CUT do
		local c = model:FindFirstChild(name)
		if c ~= nil then
			c:Destroy()
		end
	end
	-- every hat / hair / glasses handle on its body attachment before anything is anchored (outside Workspace no
	-- physics would move it there later; WorldCFrame needs no physics)
	for _, acc in model:GetChildren() do
		if acc:IsA("Accessory") then
			local handle = acc:FindFirstChild("Handle")
			local att = if handle ~= nil then handle:FindFirstChildOfClass("Attachment") else nil
			if att ~= nil then
				for _, name in { "Head", "Torso" } do
					local part = model:FindFirstChild(name)
					local body = if part ~= nil then part:FindFirstChild(att.Name) else nil
					if body ~= nil and body:IsA("Attachment") then
						-- (only when it is not there already: then this changes nothing)
						local want = body.WorldCFrame * att.CFrame:Inverse()
						if (handle.Position - want.Position).Magnitude > 0.05 then
							handle.CFrame = want
						end
						break
					end
				end
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum ~= nil then
		-- (no name or health bar over the head in the picture)
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	model.Name = tostring(n)
	model.Parent = f
end

local function run()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			local n = table.remove(queue, 1) :: number
			queued[n] = nil
			build(n)
		end
		running = false
	end)
end

--- Builds the avatars of look numbers `list` (one at a time, in the background; ones already built are kept).
function BotAvatars.build(list: { number })
	local f = folder()
	if #f:GetChildren() > BotAvatars.KEEP then
		f:ClearAllChildren()
	end
	for _, n in list do
		if type(n) == "number" and not queued[n] then
			queued[n] = true
			table.insert(queue, n)
		end
	end
	run()
end

return BotAvatars
