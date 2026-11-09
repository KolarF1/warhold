--!nonstrict
-- A bot player's picture beside its name (2026-11-02): its made-up Roblox avatar (Data/BotLooks; built by the
-- server, server/BotAvatars) in a ViewportFrame inside the head-shot ImageLabel a person's Roblox head shot uses
-- (the map's name plates, the leaderboard, the spawn overlay's heads). Never a real account's thumbnail.
--
-- How it renders, and why: Roblox can't turn a ViewportFrame (or any 3D render) into an image a script can keep,
-- so a picture can't be made once and reused as an image: each label holds its own ViewportFrame with a clone of
-- the look's bust (the server builds that once per look for everyone). To keep that cheap:
--   * the bust is a cut-down R6 rig (head, torso, hair / hat / glasses, shirt; anchored, no scripts);
--   * at most MAX_LIVE ViewportFrames exist at once across the whole UI (every further bot gets the silhouette);
--   * a caller passes live = false where the picture is too small to read (the map's plates zoomed out), which
--     frees that label's viewport for another;
--   * a hidden label's ViewportFrame isn't drawn (Roblox skips invisible GUI), so culled plates cost nothing.
-- Until the avatar has arrived, beyond the cap, when it is small, or when it can't be built: a plain silhouette (a
-- head and shoulders) in the bot's colour. Never a broken image, never the old flag badge.
--
-- BotPortrait.apply(label, face, colour, live?) -> handled: true for a bot's face (< 0), which it draws; false for
-- anything else, after removing any bot picture from the label (rows are reused: bot, then person, then bot), so
-- the caller then sets the person's head shot as before.
local IS_ROBLOX = typeof(game) == "Instance"

local BotPortrait = {}

BotPortrait.MAX_LIVE = 24
--- The map's plates: below this many pixels a head shows the silhouette (an avatar would be a smudge).
BotPortrait.MIN_LIVE_PX = 14

local states: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local live_count = 0
local waiting: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local hooked: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watching = false

local function shade(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

local function silhouette(label: any, st: any)
	if st.sil == nil then
		local sil = Instance.new("Frame")
		sil.Name = "BotSilhouette"
		sil.BackgroundTransparency = 1
		sil.Size = UDim2.fromScale(1, 1)
		sil.ZIndex = label.ZIndex
		-- (both shapes stay inside the round label: a clip would be square, not round)
		local head = Instance.new("Frame")
		head.Name = "Head"
		head.AnchorPoint = Vector2.new(0.5, 0)
		head.Position = UDim2.fromScale(0.5, 0.17)
		head.Size = UDim2.fromScale(0.38, 0.38)
		head.BorderSizePixel = 0
		head.ZIndex = label.ZIndex
		local hc = Instance.new("UICorner")
		hc.CornerRadius = UDim.new(0.5, 0)
		hc.Parent = head
		head.Parent = sil
		local body = Instance.new("Frame")
		body.Name = "Shoulders"
		body.AnchorPoint = Vector2.new(0.5, 0)
		body.Position = UDim2.fromScale(0.5, 0.6)
		body.Size = UDim2.fromScale(0.6, 0.34)
		body.BorderSizePixel = 0
		body.ZIndex = label.ZIndex
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0.5, 0)
		bc.Parent = body
		body.Parent = sil
		sil.Parent = label
		st.sil = sil
	end
	local fg = shade(st.colour, 1.0)
	for _, ch in st.sil:GetChildren() do
		if ch:IsA("Frame") then
			ch.BackgroundColor3 = fg
		end
	end
	st.sil.Visible = st.vf == nil
end

local function drop_viewport(st: any)
	if st.vf ~= nil then
		st.vf:Destroy()
		st.vf = nil
		live_count -= 1
	end
end

-- frees the slots of labels that are gone (destroyed, or out of the UI) without telling us
local function sweep()
	for label, st in states do
		if st.vf ~= nil and label.Parent == nil then
			drop_viewport(st)
		end
	end
end

local function source(n: number): any
	local f = game:GetService("ReplicatedStorage"):FindFirstChild("BotAvatars")
	return if f ~= nil then f:FindFirstChild(tostring(n)) else nil
end

local refresh: (any) -> ()

local function watch()
	if watching then
		return
	end
	local RS = game:GetService("ReplicatedStorage")
	local f = RS:FindFirstChild("BotAvatars")
	if f == nil then
		-- (the folder comes with the first match that has bots)
		watching = true
		local conn
		conn = RS.ChildAdded:Connect(function(ch)
			if ch.Name == "BotAvatars" then
				conn:Disconnect()
				watching = false
				watch()
				for label in table.clone(waiting) do
					refresh(label)
				end
			end
		end)
		return
	end
	watching = true
	f.ChildAdded:Connect(function(ch)
		local n = tonumber(ch.Name)
		for label in table.clone(waiting) do
			local st = states[label]
			if st ~= nil and st.n == n then
				refresh(label)
			end
		end
	end)
end

local function viewport(label: any, st: any, model: any): boolean
	local ok = pcall(function()
		local vf = Instance.new("ViewportFrame")
		vf.Name = "BotAvatar"
		vf.BackgroundTransparency = 1
		vf.Size = UDim2.fromScale(1, 1)
		vf.ZIndex = label.ZIndex
		vf.ImageTransparency = label.ImageTransparency
		vf.Ambient = Color3.fromRGB(165, 165, 165)
		vf.LightColor = Color3.fromRGB(255, 255, 255)
		vf.LightDirection = Vector3.new(-0.5, -1, -0.8)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = vf
		local m = model:Clone()
		m.Parent = vf
		local head = m:FindFirstChild("Head")
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		if head ~= nil then
			-- a head shot: the face from the front, the shoulders at the bottom edge
			local hp = head.Position
			local fwd = head.CFrame.LookVector
			cam.CFrame = CFrame.lookAt(hp + fwd * 4.2 + Vector3.new(0, 0.1, 0), hp + Vector3.new(0, -0.2, 0))
		end
		cam.Parent = vf
		vf.CurrentCamera = cam
		vf.Parent = label
		st.vf = vf
	end)
	if ok then
		live_count += 1
	elseif st.vf ~= nil then
		st.vf:Destroy()
		st.vf = nil
	end
	return ok
end

refresh = function(label: any)
	local st = states[label]
	if st == nil then
		waiting[label] = nil
		return
	end
	waiting[label] = nil
	if st.vf ~= nil and (not st.live or st.vf_n ~= st.n) then
		drop_viewport(st)
	end
	if st.live and st.vf == nil then
		local model = source(st.n)
		if model == nil then
			waiting[label] = true
			watch()
		else
			if live_count >= BotPortrait.MAX_LIVE then
				sweep()
			end
			if live_count < BotPortrait.MAX_LIVE and viewport(label, st, model) then
				st.vf_n = st.n
			end
		end
	end
	silhouette(label, st)
end

local function clear_image(label: any)
	pcall(function()
		label.ImageContent = Content.none
	end)
	label.Image = ""
end

--- Draws bot face `face` (< 0) on `label` in the bot's `colour`; `live` false: the silhouette only. Anything else:
--- removes a bot picture from the label and returns false (the caller sets the head shot).
function BotPortrait.apply(label: any, face: number?, colour: any, live: boolean?): boolean
	local n = if type(face) == "number" and face < 0 then -face else nil
	if not IS_ROBLOX then
		return n ~= nil
	end
	local st = states[label]
	if n == nil then
		if st ~= nil then
			drop_viewport(st)
			if st.sil ~= nil then
				st.sil:Destroy()
			end
			label.BackgroundColor3 = st.bg
			states[label] = nil
			waiting[label] = nil
		end
		return false
	end
	if st == nil then
		st = { bg = label.BackgroundColor3 }
		states[label] = st
	end
	if not hooked[label] then
		-- (once per label: reused rows go bot → person → bot)
		hooked[label] = true
		label.Destroying:Connect(function()
			local s = states[label]
			if s ~= nil then
				drop_viewport(s)
				states[label] = nil
			end
			waiting[label] = nil
		end)
	end
	clear_image(label)
	st.n = n
	st.colour = if typeof(colour) == "Color3" then colour else Color3.fromRGB(150, 160, 175)
	st.live = live ~= false
	-- (the backdrop: the bot's colour, darker, as a head shot has its plain background)
	label.BackgroundColor3 = shade(st.colour, 0.45)
	refresh(label)
	return true
end

--- Live viewports right now (tests, the cost guard).
function BotPortrait.live(): number
	return live_count
end

return BotPortrait
