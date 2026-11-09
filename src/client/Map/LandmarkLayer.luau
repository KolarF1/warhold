--!native
-- Landmarks on the map (Core/SimLandmarks): a disc at each site with the kind's glyph, in the colour of whoever holds
-- the ground under it, so players can see what a war is for and whose it is. Held: the holder's colour, the glyph dark
-- or pale by which stands out more, a dark rim that parts it from land of its own colour (MapStyle.rim_on). Unheld: a plain light disc, a dark glyph and a grey rim. What it is reads from the glyph alone.
-- The sites come from the map alone (SimLandmarks.sites), the same on every client and the server,
-- so nothing about them travels over the wire; the holder is read from the mirrored owner grid every POLL_S, and a
-- badge is written only when its holder or the holder's colour changed.
local RS = game:GetService("ReplicatedStorage")
local Airfront = RS:WaitForChild("Airfront")
local Core = Airfront:WaitForChild("Core")
local SimLandmarks = require(Core:WaitForChild("SimLandmarks")) :: any
local ArtAtlas = require((script :: any).Parent.Parent:WaitForChild("UI"):WaitForChild("ArtAtlas")) :: any
local MapStyle = require((script :: any).Parent:WaitForChild("MapStyle")) :: any

local LandmarkLayer = {}
LandmarkLayer.__index = LandmarkLayer

LandmarkLayer.POLL_S = 0.5
LandmarkLayer.Z = 22
--- (2026-11-03: 38 px, the disc 33 px and its glyph 22 px; it was 34, a 29 px disc. A fixed size at every zoom.)
LandmarkLayer.SIZE = 38
LandmarkLayer.ICONS = SimLandmarks.KIND_ICONS
LandmarkLayer.NEUTRAL = MapStyle.NEUTRAL
LandmarkLayer.NEUTRAL_RIM = MapStyle.NEUTRAL_RIM
LandmarkLayer.RIM = 3

function LandmarkLayer.new(parent: Instance, view: any)
	local self = setmetatable({}, LandmarkLayer) :: any
	local root = Instance.new("Frame")
	root.Name = "Landmarks"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = LandmarkLayer.Z
	root.Parent = parent
	self.root = root
	self.view = view
	self._state = nil :: any
	self._sites = {} :: { any }
	self._badges = {} :: { any }
	self._poll = 0.0
	return self
end

local function make_badge(root: Instance, kind: number, icon: string): any
	local b = Instance.new("Frame")
	b.Name = SimLandmarks.KIND_NAMES[kind] or "Crown"
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Size = UDim2.fromOffset(LandmarkLayer.SIZE, LandmarkLayer.SIZE)
	b.BackgroundTransparency = 1
	b.Visible = false
	b.ZIndex = LandmarkLayer.Z
	local d = Instance.new("Frame")
	d.Name = "Disc"
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(0.5, 0.5)
	d.Size = UDim2.fromScale(0.86, 0.86)
	d.BackgroundColor3 = LandmarkLayer.NEUTRAL
	d.BorderSizePixel = 0
	d.ZIndex = LandmarkLayer.Z
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = d
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = LandmarkLayer.RIM
	stroke.Color = LandmarkLayer.NEUTRAL_RIM
	stroke.Parent = d
	d.Parent = b
	local g = Instance.new("ImageLabel")
	g.Name = "Icon"
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.5)
	g.Size = UDim2.fromScale(0.58, 0.58)
	g.BackgroundTransparency = 1
	g.ImageColor3 = MapStyle.GLYPH_DARK
	g.ZIndex = LandmarkLayer.Z + 1
	ArtAtlas.apply(g, ArtAtlas.icon(icon))
	g.Parent = b
	b.Parent = root
	return { frame = b, disc = d, stroke = stroke, icon = g, held_by = 0, held_col = nil, x = -1, y = -1, vis = false }
end

function LandmarkLayer.bind(self: any, state: any)
	self._state = state
	self._poll = 0.0
	for _, b in self._badges do
		b.frame:Destroy()
	end
	table.clear(self._badges)
	self._sites = SimLandmarks.sites(state.map)
	for i, s in self._sites do
		self._badges[i] = make_badge(self.root, s.kind, LandmarkLayer.ICONS[s.kind])
	end
	-- King of the Hill: the Crown's badge, bigger than the rest
	if state.crown ~= nil then
		local kind = #self._sites + 1
		table.insert(self._sites, { tile = state.crown[1], kind = 0 })
		local b = make_badge(self.root, 0, "crown_hill")
		b.crown = true
		self._badges[kind] = b
	end
end

function LandmarkLayer.unbind(self: any)
	self._state = nil
	for _, b in self._badges do
		b.vis = false
		b.frame.Visible = false
	end
end

function LandmarkLayer.destroy(self: any)
	self:unbind()
	self.root:Destroy()
end

--- A badge in its holder's colour (`col`), or plain when nobody holds it (nil).
function LandmarkLayer.paint(b: any, col: Color3?)
	if col == nil then
		b.disc.BackgroundColor3 = LandmarkLayer.NEUTRAL
		b.stroke.Color = LandmarkLayer.NEUTRAL_RIM
		b.icon.ImageColor3 = MapStyle.GLYPH_DARK
	else
		b.disc.BackgroundColor3 = col
		b.stroke.Color = MapStyle.rim_on(col)
		b.icon.ImageColor3 = MapStyle.glyph_on(col)
	end
end

function LandmarkLayer._refresh_holders(self: any)
	local st = self._state
	for i, s in self._sites do
		local b = self._badges[i]
		local id = st:tile_owner(s.tile)
		local col = if id > 0 then st:owner_color(id) else nil
		-- (the colour too, not just the id: a slot sent again in another colour keeps its id)
		if id ~= b.held_by or col ~= b.held_col then
			b.held_by = id
			b.held_col = col
			LandmarkLayer.paint(b, col)
		end
	end
end

function LandmarkLayer.tick(self: any, dt: number)
	local st = self._state
	if st == nil then
		return
	end
	self._poll -= dt
	if self._poll <= 0 then
		self._poll = LandmarkLayer.POLL_S
		self:_refresh_holders()
	end
	local cam = self.view.rig
	local map = st.map
	-- the Reckoning (the last era): landmarks pay double, and the badges breathe
	local reckoning = st.eras ~= nil
		and st.playing_since >= 0
		and (st.render_tick or st.tick) - st.playing_since >= st.eras[#st.eras]
	local size = LandmarkLayer.SIZE
	if reckoning then
		size = math.floor(LandmarkLayer.SIZE * (1.0 + 0.14 * math.sin(os.clock() * 3.0)) + 0.5)
	end
	for i, s in self._sites do
		local b = self._badges[i]
		local bs = if b.crown then math.floor(size * 1.5) else size
		if b.size ~= bs then
			b.size = bs
			b.frame.Size = UDim2.fromOffset(bs, bs)
		end
		local x, y = cam:map_to_screen(map:tile_x(s.tile) + 0.5, map:tile_y(s.tile) + 0.5)
		local show = cam:on_screen(x, y, 40)
		if show ~= b.vis then
			b.vis = show
			b.frame.Visible = show
		end
		if show and (b.x ~= x or b.y ~= y) then
			b.x, b.y = x, y
			b.frame.Position = UDim2.fromOffset(x, y)
		end
	end
end

return LandmarkLayer
