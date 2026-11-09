--!native
-- Owner names + troop counts on the 2D map, as an atlas letters them:
--   * placement (_place): the bounding box of the owner's main
--     cluster, a grid at a coarse scaling factor (1..32 by the box size) where a cell is usable if
--     it is the owner's tile, a shoreline tile, ocean with magnitude < 10 or poisoned land; the largest
--     inscribed rectangle of that grid; the line sits at its centre, its font size what fits the name
--     and its strength on one line (MapStyle.label_fit). Recomputed every REPLACE_TICKS and at once for
--     new owners; spawn-phase names use a small box on the spawn;
--   * sizing: baseSize = max(1, floor(size)), nameSize = max(4, floor(baseSize *
--     0.4)), nameScale = min(baseSize * 0.25, 3); the line is nameSize * nameScale full-size
--     tiles tall, the strength beside it TROOP_SIZE_MULT of it; names shorter on screen than the cull threshold
--     hide (hovered ones never do). Positions / sizes glide to new targets (LERP_SPEED);
--   * style: paper letters a little tinted by the owner's colour under a dark ink outline: nations in capitals, a
--     person's name as they wrote it, clans faint, the strength in gold beside the name; the leader's
--     crown stands before the name, not over it.
-- Sizes are in full-size tiles; our tiles are map.k_lin full-size tiles wide.
-- Roblox: one pooled Frame per owner (name + troops TextLabels with UIStroke); TextSize caps at
-- 100 px, beyond that a UIScale enlarges the whole plate.
local RS = game:GetService("ReplicatedStorage")
local Core = RS:WaitForChild("Airfront"):WaitForChild("Core")
local Defs = require(Core:WaitForChild("Defs")) :: any
local Rules = require(Core:WaitForChild("Rules")) :: any
local NumberFormat = require(Core:WaitForChild("NumberFormat")) :: any
local Sprites = require(script.Parent:WaitForChild("MapArt")) :: any
local Cosmetics = require(RS:WaitForChild("Airfront"):WaitForChild("Data"):WaitForChild("Cosmetics")) :: any
local Coop = require(RS:WaitForChild("Airfront"):WaitForChild("Net"):WaitForChild("Coop")) :: any
local FrameClock = require(script.Parent:WaitForChild("FrameClock")) :: any
local MapStyle = require(script.Parent:WaitForChild("MapStyle")) :: any
local BotPortrait = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("BotPortrait")) :: any

local readi32 = buffer.readi32
local readu8 = buffer.readu8

local NameLayer = {}
NameLayer.__index = NameLayer

NameLayer.FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
NameLayer.NAME_SCALE_FACTOR = 0.4
NameLayer.NAME_SCALE_CAP = 3.0
NameLayer.TROOP_SIZE_MULT = MapStyle.TROOP_K
NameLayer.LERP_SPEED = 6.0
--- A name whose line is shorter than this share of the view width hides (CULL_MIN_PX px at least).
NameLayer.CULL_VW = 0.0045
NameLayer.CULL_MIN_PX = 6.0
NameLayer.OUTLINE_K = 0.1 -- outline px per text px
NameLayer.REPLACE_TICKS = 50
NameLayer.SPAWN_DIAMETER = 10 -- full-size tiles
--- Placement work per frame (s). The placements run in a Coop job, so one owner's can go over several
--- frames too (its flood fill and its grid stop at Coop.check()).
---   * Until 2026-10-10 the budget was looked at between owners only. A nation's placement flood-fills
---     its whole cluster: 5 ms on a Mac for one holding a third of World, many times that on a phone,
---     which runs this without native code, every REPLACE_TICKS. "Slow Frames" after v74: "Script -
---     Labels" was 13% of the slow matches, most of them phones, minutes 5 to 9.
NameLayer.BUDGET_S = 0.0015
--- Tiles a flood fill takes between two looks at the clock (Coop.check).
NameLayer.FILL_CHECK = 2048
--- Text line height / TextSize for Rubik.
NameLayer.LINE_K = 1.0
--- The local player's name line is at most this share of the view's height (OWN_MAX_MIN_PX at least);
--- its head, flag, troops and crown follow it. Every other name is sized by its land, and a
--- player holding a big share of the map had a name, a head and a flag across their own front (far
--- too big for their own nametag, and annoying to play behind, 2026-10-10).
NameLayer.OWN_MAX_VH = 0.04
NameLayer.OWN_MAX_MIN_PX = 18.0
--- Any other name line is at most this share of the view's height.
NameLayer.NAME_MAX_VH = 0.075
NameLayer.CROWN_MIN_PX = 16

type Plate = {
	frame: Frame,
	scaler: UIScale,
	name: TextLabel,
	troops: TextLabel,
	flag: ImageLabel,
	flag_id: string,
	name_stroke: UIStroke,
	troop_stroke: UIStroke,
	-- glide state (map tiles for x / y, the font size for s)
	sx: number,
	sy: number,
	ss: number,
	tx: number,
	ty: number,
	ts: number,
	t0: number,
	-- last written
	text: string,
	troop_text: string,
	px: number,
	shown: boolean,
	rect: { number },
}

function NameLayer.new(parent: Instance, view: any)
	local self = setmetatable({}, NameLayer) :: any
	local root = Instance.new("Frame")
	root.Name = "Names"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 20
	root.Parent = parent
	self.root = root
	self.view = view
	self.visible = true
	self.hover_owner = 0
	self.safe_rect = nil
	self.obstacles = {}
	self.layout_dirty = true
	self._state = nil :: any
	self._plates = {} :: { [number]: Plate }
	--- owner -> { x, y (map tiles, name centre), size (the name's font size) }
	self._targets = {} :: { [number]: { number } }
	self._queue = {} :: { number }
	--- the Coop job placing _queue's owners (nil: none running)
	self._job = nil :: any
	self._last_place_tick = -1000
	--- game admins only (Session.admin_bots): owner id → true for bot players; nil for everyone else
	self.admin_bots = nil :: { [number]: boolean }?
	--- The crown: over the name of the alive owner with the most land
	self.crown_owner = 0
	self._crown_t = 0.0
	local crown = Instance.new("ImageLabel")
	crown.Name = "Crown"
	crown.BackgroundTransparency = 1
	crown.AnchorPoint = Vector2.new(0.5, 0)
	Sprites.set(crown, Sprites.status.id)
	crown.ImageColor3 = Color3.fromRGB(255, 205, 70) -- (our crown is a white mask: the colour is here)
	local st = Sprites.status
	crown.ImageRectOffset = Vector2.new(st.pad, st.pad) -- cell 0 = crown
	crown.ImageRectSize = Vector2.new(st.cell - 2 * st.pad, st.cell - 2 * st.pad)
	crown.ScaleType = Enum.ScaleType.Fit
	crown.ZIndex = 21
	crown.Visible = false
	crown.Parent = root
	self._crown = crown
	self._visit = buffer.create(0)
	self._visit_gen = 0
	return self
end

function NameLayer.bind(self: any, state: any)
	self:unbind()
	self._state = state
	self._last_place_tick = -1000
end

function NameLayer.unbind(self: any)
	self._state = nil
	for _, p in self._plates do
		p.frame:Destroy()
	end
	table.clear(self._plates)
	table.clear(self._targets)
	table.clear(self._queue)
	self._job = nil
	self.crown_owner = 0
	self._crown.Visible = false
end

function NameLayer.set_visible(self: any, on: boolean)
	self.visible = on
	self.root.Visible = on
end

function NameLayer.destroy(self: any)
	self:unbind()
	self.root:Destroy()
end

-- ---------------------------------------------------------------------------------------------
-- Placement
-- ---------------------------------------------------------------------------------------------

local function k_lin(map: any): number
	return tonumber(map and map.k_lin) or Rules.K_LIN
end

--- Largest rectangle in a histogram (heights[1..n]): x (0-based), width, height.
local function largest_in_histogram(h: { number }, n: number): (number, number, number)
	local stack = {}
	local top = 0
	local best, bx, bw, bh = 0, 0, 0, 0
	for i = 0, n do
		local cur = if i == n then 0 else h[i + 1]
		while top > 0 and cur < h[stack[top] + 1] do
			local height = h[stack[top] + 1]
			top -= 1
			local width = if top == 0 then i else i - stack[top] - 1
			if height * width > best then
				best = height * width
				bx = if top == 0 then 0 else stack[top] + 1
				bw, bh = width, height
			end
		end
		top += 1
		stack[top] = i
	end
	return bx, bw, bh
end

--- Bounding box of the owner's cluster containing `seed` (4-connected flood fill). Inside the placement
--- job it may pause (Coop.check) while the map changes: the box is then of the tiles it went through.
--- (Another fill in between, a new owner's at once, takes the next generation: this one may go through
--- some of its tiles again, once each.)
function NameLayer._cluster_box(self: any, st: any, id: number, seed: number): (number, number, number, number)
	local map = st.map
	local W, H = map.W or Defs.W, map.H or Defs.H
	local N = W * H
	if buffer.len(self._visit) ~= N * 4 then
		self._visit = buffer.create(N * 4)
		self._visit_gen = 0
	end
	self._visit_gen += 1
	local gen = self._visit_gen
	local visit = self._visit
	local own = st.owner
	local stack = { seed }
	buffer.writeu32(visit, seed * 4, gen)
	local x0, y0, x1, y1 = seed % W, seed // W, seed % W, seed // W
	local n = 1
	local check = NameLayer.FILL_CHECK
	local left = check
	while n > 0 do
		left -= 1
		if left <= 0 then
			left = check
			Coop.check()
		end
		local i = stack[n]
		stack[n] = nil
		n -= 1
		local x = i % W
		local y = i // W
		if x < x0 then
			x0 = x
		elseif x > x1 then
			x1 = x
		end
		if y < y0 then
			y0 = y
		elseif y > y1 then
			y1 = y
		end
		if x > 0 and buffer.readu32(visit, (i - 1) * 4) ~= gen and readi32(own, (i - 1) * 4) == id then
			buffer.writeu32(visit, (i - 1) * 4, gen)
			n += 1
			stack[n] = i - 1
		end
		if x < W - 1 and buffer.readu32(visit, (i + 1) * 4) ~= gen and readi32(own, (i + 1) * 4) == id then
			buffer.writeu32(visit, (i + 1) * 4, gen)
			n += 1
			stack[n] = i + 1
		end
		if y > 0 and buffer.readu32(visit, (i - W) * 4) ~= gen and readi32(own, (i - W) * 4) == id then
			buffer.writeu32(visit, (i - W) * 4, gen)
			n += 1
			stack[n] = i - W
		end
		if y < H - 1 and buffer.readu32(visit, (i + W) * 4) ~= gen and readi32(own, (i + W) * 4) == id then
			buffer.writeu32(visit, (i + W) * 4, gen)
			n += 1
			stack[n] = i + W
		end
	end
	return x0, y0, x1, y1
end

local function font_size(width: number, height: number, o: any): number
	return MapStyle.label_fit(width, height, #(o.name or ""), o.kind == Defs.KIND_HUMAN)
end

--- Placement: target { x, y, size } in map tiles / font size, or nil.
function NameLayer._place(self: any, st: any, id: number): { number }?
	local o = st:get_owner(id)
	if o == nil or (o.tiles or 0) <= 0 then
		return nil
	end
	local seed = st:label_tile(id)
	if seed < 0 then
		return nil
	end
	local map = st.map
	local W = map.W or Defs.W
	local k = k_lin(map)
	local tile_bytes: buffer? = self.view.surface and self.view.surface.tile_bytes or nil
	local own = st.owner
	local flags = st.flags
	local x0, y0, x1, y1 = self:_cluster_box(st, id, seed)
	-- box size in full-size tiles picks the grid scaling factor (in full-size tiles, then ours)
	local size_of = math.min(x1 - x0, y1 - y0) * k
	local sf_of = if size_of < 25
		then 1
		elseif size_of < 50 then 2
		elseif size_of < 100 then 4
		elseif size_of < 250 then 8
		elseif size_of < 500 then 16
		else 32
	local sf = math.max(1, math.floor(sf_of / k + 0.5))
	local gx0, gy0 = x0 // sf, y0 // sf
	local gw, gh = x1 // sf - gx0 + 1, y1 // sf - gy0 + 1
	local heights = table.create(gw, 0)
	local best, bx, by, bw, bh = 0, 0, 0, 0, 0
	for gy = 0, gh - 1 do
		local ty = (gy0 + gy) * sf
		for gx = 0, gw - 1 do
			local tx = (gx0 + gx) * sf
			local t = ty * W + tx
			local usable = readi32(own, t * 4) == id
			if not usable then
				if tile_bytes then
					local b = readu8(tile_bytes, t)
					usable = bit32.band(b, 64) ~= 0 or (b < 128 and bit32.band(b, 32) ~= 0 and bit32.band(b, 31) < 10)
				end
				usable = usable or bit32.band(readu8(flags, t), Defs.F_FALLOUT) ~= 0
			end
			heights[gx + 1] = if usable then heights[gx + 1] + 1 else 0
		end
		local rx, rw, rh = largest_in_histogram(heights, gw)
		if rw * rh > best then
			best = rw * rh
			bx, by, bw, bh = rx, gy - rh + 1, rw, rh
		end
		Coop.check()
	end
	local rx = bx * sf
	local ry = by * sf
	local rw = bw * sf
	local rh = bh * sf
	local cx = math.floor(rx + rw / 2 + gx0 * sf)
	local cy = math.floor(ry + rh / 2 + gy0 * sf)
	return { cx + 0.5, cy + 0.5, font_size(rw * k, rh * k, o) }
end

--- Spawn-phase placement: an 8-tile box on the spawn tile.
function NameLayer._place_spawn(_self: any, st: any, id: number): { number }?
	local o = st:get_owner(id)
	if o == nil or (o.spawn_tile or -1) < 0 then
		return nil
	end
	local W = st.map.W or Defs.W
	local d = NameLayer.SPAWN_DIAMETER
	local t = o.spawn_tile
	return { t % W + 0.5, t // W + 0.5, font_size(d, d, o) }
end

function NameLayer._refresh_queue(self: any, st: any)
	table.clear(self._queue)
	for id, o in st.owners do
		if (o.tiles or 0) > 0 then
			table.insert(self._queue, id)
		end
	end
end

function NameLayer._placement_step(self: any, st: any)
	local tick = st.tick or 0
	local spawn = st.phase == Defs.PHASE_SPAWN
	if tick - self._last_place_tick >= NameLayer.REPLACE_TICKS or tick < self._last_place_tick then
		self._last_place_tick = tick
		self:_refresh_queue(st)
	end
	-- new owners get a target at once
	for id, o in st.owners do
		if (o.tiles or 0) > 0 and self._targets[id] == nil then
			local t = if spawn then self:_place_spawn(st, id) else self:_place(st, id)
			if t then
				self._targets[id] = t
			end
		end
	end
	local q = self._queue
	if self._job == nil then
		if #q == 0 then
			return
		end
		self._job = Coop.job(function()
			while #q > 0 and self._state == st do
				local id = table.remove(q)
				local t = if st.phase == Defs.PHASE_SPAWN then self:_place_spawn(st, id) else self:_place(st, id)
				if self._state == st then
					self._targets[id] = t
				end
			end
		end)
	end
	local job = self._job
	if job:step(NameLayer.BUDGET_S) then
		self._job = nil
		if not job.ok then
			error(job.err, 0)
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------------------------

local function new_text(parent: Instance, name: string, z: number): (TextLabel, UIStroke)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = NameLayer.FONT
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 0)
	l.ZIndex = z
	l.Parent = parent
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = l
	return l, s
end

function NameLayer._plate(self: any, id: number): Plate
	local p = self._plates[id]
	if p then
		return p
	end
	local f = Instance.new("Frame")
	f.Name = "Owner" .. id
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0)
	f.Size = UDim2.fromOffset(0, 0)
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.ZIndex = 20
	f.Visible = false
	local scaler = Instance.new("UIScale")
	scaler.Parent = f
	local lay = Instance.new("UIListLayout")
	lay.FillDirection = Enum.FillDirection.Vertical
	lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Padding = UDim.new(0, 0)
	lay.Parent = f
	-- (no PLAYER badge over real players' names any more: admins saw it on every person, which says nothing in a
	-- warband of friends; playtest 2026-11-08. The leaderboard's small person icon still tells admins who is real.)
	-- the name line: [flag] [head] name (the flag only when the owner has one equipped, Data/Cosmetics;
	-- a person's Roblox head shot; the flag sits left of it, 2026-10-22)
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Size = UDim2.fromOffset(0, 0)
	line.AutomaticSize = Enum.AutomaticSize.XY
	line.LayoutOrder = 1
	line.ZIndex = 21
	line.Parent = f
	local ll = Instance.new("UIListLayout")
	ll.FillDirection = Enum.FillDirection.Horizontal
	ll.VerticalAlignment = Enum.VerticalAlignment.Center
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Padding = UDim.new(0, 3)
	ll.Parent = line
	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.BackgroundColor3 = Color3.fromRGB(40, 52, 82)
	face.BorderSizePixel = 0
	face.LayoutOrder = 0
	face.ZIndex = 21
	face.Visible = false
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0.5, 0)
	fc.Parent = face
	local fs = Instance.new("UIStroke")
	fs.Color = Color3.new(0, 0, 0)
	fs.Transparency = 0.4
	fs.Thickness = 1
	fs.Parent = face
	face.Parent = line
	local flag = Instance.new("ImageLabel")
	flag.Name = "Flag"
	flag.BackgroundTransparency = 1
	flag.ScaleType = Enum.ScaleType.Fit
	flag.LayoutOrder = -1
	flag.ZIndex = 21
	flag.Visible = false
	flag.Parent = line
	local name, ns = new_text(line, "Name", 21)
	name.LayoutOrder = 1
	-- (its strength on the same line, after the name)
	local troops, ts = new_text(line, "Troops", 21)
	troops.LayoutOrder = 2
	f.Parent = self.root
	p = {
		frame = f,
		scaler = scaler,
		name = name,
		troops = troops,
		line_layout = ll,
		flag = flag,
		flag_id = "",
		face = face,
		face_id = 0,
		name_stroke = ns,
		troop_stroke = ts,
		sx = 0,
		sy = 0,
		ss = 0,
		tx = 0,
		ty = 0,
		ts = 0,
		t0 = -1,
		text = "",
		troop_text = "",
		px = -1,
		shown = false,
		rect = { 0, 0, 0, 0 },
	}
	self._plates[id] = p
	return p
end

--- The crown goes to the alive owner (any kind) with the most tiles; ties to the lower id.
function NameLayer.crown_of(st: any): number
	-- King of the Hill: the crown over a name is the Crown's holder, never the biggest (playtest 2026-11-08: the two
	-- crowns read as one, and a win by the Crown seemed to come from nowhere)
	if st.crown ~= nil then
		local holder = tonumber(st.crown[3]) or 0
		local o = if holder > 0 then st.owners[holder] else nil
		return if o ~= nil and o.alive then holder else 0
	end
	local best, bt = 0, 0
	for id, o in st.owners do
		local t = o.tiles or 0
		if o.alive and t > 0 and (t > bt or (t == bt and id < best)) then
			best, bt = id, t
		end
	end
	return best
end

function NameLayer.tick(self: any, dt: number)
	local st = self._state
	if st == nil or not self.visible then
		self._crown.Visible = false
		return
	end
	self._crown_t -= dt
	if self._crown_t <= 0 then
		self._crown_t = 0.25
		self.crown_owner = NameLayer.crown_of(st)
	end
	local crown_shown = false
	self:_placement_step(st)
	local cam = self.view.rig
	local k = k_lin(st.map)
	local now = FrameClock.now()
	local cull_px = math.max(NameLayer.CULL_MIN_PX, NameLayer.CULL_VW * cam._vp.X)
	-- (reused every frame: late games draw dozens of plates 60 times a second)
	local seen = self._seen
	if seen == nil then
		seen = {}
		self._seen = seen
	else
		table.clear(seen)
	end
	for id, t in self._targets do
		local o = st:get_owner(id)
		if o == nil or (o.tiles or 0) <= 0 then
			continue
		end
		seen[id] = true
		local p = self:_plate(id)
		if p.t0 < 0 then
			p.sx, p.sy, p.ss = t[1], t[2], t[3]
			p.tx, p.ty, p.ts = t[1], t[2], t[3]
			p.t0 = now
		elseif t[1] ~= p.tx or t[2] ~= p.ty or t[3] ~= p.ts then
			-- restart the glide from where the plate is now
			local a = math.min(1 - math.exp(-NameLayer.LERP_SPEED * (now - p.t0)), 1)
			p.sx, p.sy, p.ss = p.sx + (p.tx - p.sx) * a, p.sy + (p.ty - p.sy) * a, p.ss + (p.ts - p.ss) * a
			p.tx, p.ty, p.ts = t[1], t[2], t[3]
			p.t0 = now
		end
		local a = math.min(1 - math.exp(-NameLayer.LERP_SPEED * (now - p.t0)), 1)
		local wx = p.sx + (p.tx - p.sx) * a
		local wy = p.sy + (p.ty - p.sy) * a
		local ws = p.ss + (p.ts - p.ss) * a
		local base = math.max(1, math.floor(ws))
		local name_size = math.max(4, math.floor(base * NameLayer.NAME_SCALE_FACTOR))
		local name_scale = math.min(base * 0.25, NameLayer.NAME_SCALE_CAP)
		local line_px = name_size * name_scale / k * cam.scale * NameLayer.LINE_K
		if id == st.local_owner then
			line_px = math.min(line_px, math.max(NameLayer.OWN_MAX_MIN_PX, cam._vp.Y * NameLayer.OWN_MAX_VH))
		else
			-- (zoomed right in, a nation's name was half the screen; 2026-10-31, seen in Studio)
			line_px = math.min(line_px, math.max(NameLayer.OWN_MAX_MIN_PX, cam._vp.Y * NameLayer.NAME_MAX_VH))
		end
		local hovered = id == self.hover_owner
		local sx, sy = cam:map_to_screen(wx, wy)
		local vis = (line_px >= cull_px or hovered) and cam:on_screen(sx, sy, line_px * 4)
		if not vis then
			if p.shown then
				p.frame.Visible = false
				p.shown = false
				if p.face_id < 0 and p.face_live then
					-- (an off-screen bot gives its avatar's viewport back: UI/BotPortrait's cap)
					BotPortrait.apply(p.face, p.face_id, st:owner_color(id), false)
					p.face_live = false
					p.px = -1
				end
			end
			continue
		end
		if not p.shown then
			p.frame.Visible = true
			p.shown = true
		end
		-- text + style
		local text = o.name or ""
		if p.text ~= text then
			p.text = text
			local person = o.kind == Defs.KIND_HUMAN
			local clan = o.kind == Defs.KIND_TRIBE
			p.name.Text = MapStyle.label_text(text, person)
			p.size_dirty = 3
			p.name.TextColor3 = MapStyle.label_fill(st:owner_color(id), person, clan)
			p.troops.TextColor3 = MapStyle.TROOP_COLOR
			p.name_stroke.Color = MapStyle.INK
			p.troop_stroke.Color = MapStyle.INK
			local fade = if clan then MapStyle.CLAN_FADE else 0
			p.name.TextTransparency = fade
			p.troops.TextTransparency = fade
			p.name_stroke.Transparency = fade
			p.troop_stroke.Transparency = fade
		end
		-- a person's head shot (a bot player's made-up avatar: UI/BotPortrait) and the owner's flag
		-- (Data/Cosmetics), left of the name
		local cz = st.cosmetics and st.cosmetics[id]
		local face_id = if cz ~= nil and cz.face ~= nil then cz.face else 0
		if face_id ~= p.face_id then
			p.face_id = face_id
			if BotPortrait.apply(p.face, face_id, st:owner_color(id), p.face_live == true) then
				-- (drawn; live once the head is big enough to read, below)
			elseif face_id ~= 0 then
				Sprites.set(p.face, Cosmetics.face_image(face_id))
			else
				Sprites.set(p.face, "")
			end
			p.face.Visible = face_id ~= 0
			p.px = -1 -- size the head with the name
			p.size_dirty = 3
		end
		local fid = if cz ~= nil and cz.flag ~= nil then cz.flag else ""
		if fid ~= p.flag_id then
			p.flag_id = fid
			local it = if fid ~= "" then Cosmetics.item(fid) else nil
			if it ~= nil and it.kind == "flag" then
				Sprites.set(p.flag, Cosmetics.flag_image(it))
				p.flag.ImageRectOffset = Vector2.new(it.x, it.y)
				p.flag.ImageRectSize = Vector2.new(it.w, it.h)
				p.flag.Visible = true
			else
				p.flag.Visible = false
			end
			p.px = -1 -- size the flag with the name
			p.size_dirty = 3
		end
		local troops = o.troops or 0
		if p.troop_n ~= troops then
			p.troop_n = troops
			local tt = NumberFormat.render_troops(troops)
			if p.troop_text ~= tt then
				p.troop_text = tt
				p.troops.Text = tt
				p.size_dirty = 3
			end
		end
		-- size: TextSize caps at 100, a UIScale takes the rest
		local px = math.floor(line_px * 2 + 0.5) / 2
		if px ~= p.px then
			p.px = px
			p.size_dirty = 3
			local ts = math.min(px, 100)
			local sc = px / ts
			p.name.TextSize = ts
			p.troops.TextSize = math.max(1, ts * NameLayer.TROOP_SIZE_MULT)
			p.line_layout.Padding = UDim.new(0, math.max(3, math.round(ts * 0.3)))
			if p.flag.Visible then
				-- a flag about as tall as the capitals, its own aspect kept (Fit)
				local fh = math.max(4, math.round(ts * 0.78))
				p.flag.Size = UDim2.fromOffset(math.round(fh * 1.5), fh)
			end
			if p.face.Visible then
				-- a head about as tall as the name's line
				local hh = math.max(6, math.round(ts * 1.05))
				p.face.Size = UDim2.fromOffset(hh, hh)
				-- a bot's avatar only where it can be read (its silhouette below that: the cost guard, UI/BotPortrait)
				local live = hh * sc >= BotPortrait.MIN_LIVE_PX
				if p.face_id < 0 and live ~= p.face_live then
					BotPortrait.apply(p.face, p.face_id, st:owner_color(id), live)
				end
				p.face_live = live
			end
			p.scaler.Scale = sc
			local stroke = math.max(1, ts * NameLayer.OUTLINE_K)
			p.name_stroke.Thickness = stroke
			p.troop_stroke.Thickness = math.max(1, stroke * NameLayer.TROOP_SIZE_MULT)
		end
		-- (wx, wy) is the name line's centre: the plate hangs from the top of the name line
		local top = math.round(sy - px * 0.5)
		local pos = UDim2.fromOffset(math.round(sx), top)
		if p.frame.Position ~= pos then
			p.frame.Position = pos
		end
		-- (AbsoluteSize can force a GUI layout pass: read it only for a few frames after the text or
		-- size changed — the layout may settle a frame late)
		if p.abs == nil or (p.size_dirty or 0) > 0 then
			p.size_dirty = math.max(0, (p.size_dirty or 1) - 1)
			p.abs = p.frame.AbsoluteSize
		end
		local sz = p.abs
		local r = p.rect
		r[1], r[2], r[3], r[4] = sx - sz.X * 0.5, top, sx + sz.X * 0.5, top + sz.Y
		local z = if hovered then 22 else 20
		if p.z ~= z then
			p.z = z
			p.frame.ZIndex = z
		end
		if id == self.crown_owner then
			-- an icon a little taller than the line, standing before it (the plate's width is known here)
			-- (at least CROWN_MIN_PX so the leader stays easy to spot on a phone)
			local icon = math.max(line_px * 1.1, NameLayer.CROWN_MIN_PX)
			self._crown.Size = UDim2.fromOffset(icon, icon)
			self._crown.Position = UDim2.fromOffset(math.round(sx - sz.X * 0.5 - icon * 0.55), math.round(sy - icon * 0.5))
			crown_shown = true
		end
	end
	if self._crown.Visible ~= crown_shown then
		self._crown.Visible = crown_shown
	end
	for id, p in self._plates do
		if not seen[id] then
			p.frame:Destroy()
			self._plates[id] = nil
			self._targets[id] = nil
		end
	end
end

--- Map-tile centre { u, v } of `id`'s name, or nil before it has one.
function NameLayer.name_location(self: any, id: number): { number }?
	local t = self._targets[id]
	if t == nil then
		return nil
	end
	return { t[1], t[2] }
end

--- Viewport rect of the local player's plate (coach tips keep clear of it), or nil.
function NameLayer.local_label_rect(self: any): Rect?
	local st = self._state
	if st == nil then
		return nil
	end
	local p = self._plates[st.local_owner or 0]
	if p == nil or not p.shown then
		return nil
	end
	local r = p.rect
	return Rect.new(r[1], r[2], r[3], r[4])
end

return NameLayer
