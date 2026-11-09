--!native
-- Structure icons on the 2D map:
--   * a plate per structure in its owner's colour, its shape the kind's category (Art/Frames: a square for the
--     economy, a shield for defence, a diamond for a strike; MapStyle.plate_fill: the
--     darkest colours lifted a little, muted towards clay while being raised), its rim a dark of that colour, the
--     glyph dark or pale by which stands out more (MapStyle.glyph_on): the glyph says what it is, the colour whose.
--     Restyled only when its owner, state or rank changes, or when an owner's colour does (on_owner_color);
--   * size: ICON_SIZE * iconScale px, iconScale = DOT_SCALE (no glyph)
--     when zoom <= DOTS_ZOOM, zoom / GROW_ZOOM above GROW_ZOOM, else
--     min(1, zoom / SCALE_FACTOR_OUT); zoom = the camera zoom
--     (device px per full-size tile; a tile is k_lin full-size tiles, a GUI px DEVICE_RATIO
--     device px);
--   * level >= 2: the rank cut in Roman numerals on a dark chip at the plate's lower corner, gone with the
--     glyph when zoomed far out (MapStyle.rank_text);
--   * a slim bar under it: gold while it is raised, steel while missiles reload, pale when nearly
--     reloaded (MapStyle.bar_state).
-- Roblox: pooled plates, positions rewritten only when the camera or the structure set changed. A
-- plate is one ImageLabel with the glyph inside it: the shape's rim and fill in one image
-- (Sprites.shapes_one, tinted with the fill colour: its rim pixels are the grey that makes the rim's
-- tenth of the value). It was a Frame holding a rim image, a fill image, the glyph and a level
-- label, five objects for each of a late game's 500 structures, all laid out again on every camera
-- move (2026-10-08, docs/performance.md). The level label is made when a structure has a level to
-- show. While shapes_one has not loaded, every plate keeps a second image for the fill.
-- (2026-10-26, phones' slow frames: a plate and its bar remember what they were last given and are
-- written only what changed, read nothing back from Roblox; a structure's own event redraws that
-- structure alone, where every SAM shot on the map used to redraw every plate.)
local RS = game:GetService("ReplicatedStorage")
local Airfront = RS:WaitForChild("Airfront")
local Rules = require(Airfront:WaitForChild("Core"):WaitForChild("Rules")) :: any
local Sprites = require(script.Parent:WaitForChild("MapArt")) :: any
local PeriodTech = require(game:GetService("ReplicatedStorage"):WaitForChild("Airfront"):WaitForChild("Data"):WaitForChild("PeriodTech")) :: any
local MapStyle = require(script.Parent:WaitForChild("MapStyle")) :: any
--- Sprites.shapes_one is used once it is known to have loaded (an image still in moderation would leave
--- every plate invisible).
local ONE: any = Sprites.shapes_one
local one_ready = false
if ONE ~= nil then
	(require(script.Parent:WaitForChild("AtlasReady")) :: any).watch(ONE.id, function()
		one_ready = true
	end)
end

local StructureLayer = {}
StructureLayer.__index = StructureLayer

-- icon sizes and zooms
--- (2026-11-03, the owner: icons "more visible". At the normal zoom a square plate is 24 px across (it was 16, the
--- glyph spilling over its rim), a diamond 30 px point to point, the glyph 16 px, the rim 2 px.)
StructureLayer.ICON_SIZE = 26
StructureLayer.DEVICE_RATIO = 2.0
--- (the glyph holds further out than a plain dot would need: a building is known by its icon)
StructureLayer.DOTS_ZOOM = 1.0
StructureLayer.DOT_SCALE = 0.34
StructureLayer.SCALE_FACTOR_OUT = 2.6
StructureLayer.GROW_ZOOM = 8.5
--- per structure kind (Defs.S_*, 0-based) — index with kind + 1: the plate's size (x ICON_SIZE) and
--- the share of it the glyph spans (ICON_FILL / SHAPE_SCALE of the plate), set with the art
StructureLayer.SHAPE_SCALE = table.clone(Sprites.shape_scale)
StructureLayer.ICON_FILL = table.clone(Sprites.icon_fill)
--- (the plate's colour is its owner's, MapStyle.plate_fill; what it is reads from the glyph alone)
StructureLayer.BORDER_V = 0.16
StructureLayer.Z = 10
-- progress bar (full-size tiles)
StructureLayer.BAR_W = 12
StructureLayer.BAR_H = 2.4
StructureLayer.BAR_OFFSET_Y = 7.5
StructureLayer.BAR_BORDER = 1
StructureLayer.BAR_MAX_W = 52
StructureLayer.BAR_MAX_H = 6
--- Bars narrower than this (px) are not drawn (far zoomed out).
StructureLayer.BAR_MIN_PX = 10
local SHAPE_SCALE = StructureLayer.SHAPE_SCALE
local ICON_FILL = StructureLayer.ICON_FILL

type Plate = {
	--- the plate: the whole shape (rim and fill in one image, or the rim alone under `fill`)
	frame: ImageLabel,
	--- the inset shape over a two-image plate (made when one is needed)
	fill: ImageLabel?,
	glyph: ImageLabel,
	--- the rank chip (made when a structure has a rank), whether it has one and whether it shows
	level: TextLabel?,
	rank_on: boolean,
	level_vis: boolean?,
	x: number,
	y: number,
	bar: Frame?,
	bar_fill: Frame?,
	kind: number,
	owner: number,
	state_key: number,
	size: number,
	--- what the glyph and the bar were last given (Roblox's own values, kept here: a plate taken
	--- from the pool still shows them, so nothing needs resetting)
	glyph_on: boolean,
	bar_on: boolean,
	bar_w: number,
	bar_h: number,
	bar_x: number,
	bar_y: number,
	bar_edge: number,
	fill_w: number,
	fill_h: number,
	fill_c: number,
	--- the full pass that last saw it on screen
	pass: number,
}

local function value_scale(c: Color3, k: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, v * k)
end

function StructureLayer.new(parent: Instance, view: any)
	local self = setmetatable({}, StructureLayer) :: any
	local root = Instance.new("Frame")
	root.Name = "Structures"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = StructureLayer.Z
	root.Parent = parent
	self.root = root
	self.view = view
	self._state = nil :: any
	self._plates = {} :: { [number]: Plate }
	self._pool = {} :: { Plate }
	self._one_seen = false
	-- The progress bars change every frame while something is built or reloads, and late games
	-- always have some: they live in the map's moving ScreenGui (MapView.moving_overlay), so the
	-- plates' own, some 2,500 objects by then, is left alone between camera moves.
	local bars = Instance.new("Frame")
	bars.Name = "StructureBars"
	bars.BackgroundTransparency = 1
	bars.Size = UDim2.fromScale(1, 1)
	bars.ZIndex = StructureLayer.Z
	bars.Parent = if view ~= nil and view.moving_overlay ~= nil then view.moving_overlay else root
	self._bar_root = bars
	self._dirty = true
	self._cam_version = -1
	self._pass = 0
	--- sids of on-screen plates being built or reloading (updated every frame between full passes)
	self._anim = {} :: { [number]: boolean }
	--- sids a structure event named since the last frame (drawn again on their own)
	self._touched = {} :: { [number]: boolean }
	return self
end

function StructureLayer.bind(self: any, state: any)
	self:unbind()
	self._state = state
	self._dirty = true
end

function StructureLayer.unbind(self: any)
	self._state = nil
	for sid, p in self._plates do
		self:_release(p)
		self._plates[sid] = nil
	end
	table.clear(self._anim)
	table.clear(self._touched)
end

function StructureLayer.destroy(self: any)
	self:unbind()
	self._bar_root:Destroy()
	self.root:Destroy()
end

-- WorldView forwards GameState structure signals by these names (sid first). Only that structure is
-- drawn again: structure_leveled also comes with every SAM / silo shot (Ev.STRUCT_SHOTS, for its
-- reload bar), and in a late game's missile exchange that redrew all 500 plates a frame.
function StructureLayer.on_structure_added(self: any, sid: number?)
	if type(sid) == "number" then
		self._touched[sid] = true
	else
		self._dirty = true
	end
end
StructureLayer.on_structure_changed = StructureLayer.on_structure_added
StructureLayer.on_structure_removed = StructureLayer.on_structure_added
StructureLayer.on_structure_leveled = StructureLayer.on_structure_added

function StructureLayer.mark_structures_dirty(self: any)
	self._dirty = true
end

--- An owner's colour changed (a slot sent again in another colour, a snapshot): its plates are styled again on the
--- next pass; nil = every owner's.
function StructureLayer.on_owner_color(self: any, id: number?)
	for _, p in self._plates do
		if id == nil or p.owner == id then
			p.state_key = -1
		end
	end
	self._dirty = true
end

local function image(parent: Instance, name: string, id: string, z: number): ImageLabel
	local l = Instance.new("ImageLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	Sprites.set(l, id)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.5)
	l.ZIndex = z
	l.Parent = parent
	return l
end

function StructureLayer._acquire(self: any): Plate
	local p = table.remove(self._pool)
	if p then
		p.frame.Visible = true
		return p
	end
	local f = Instance.new("ImageLabel")
	f.Name = "Structure"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.ZIndex = StructureLayer.Z
	local glyph = image(f, "Glyph", Sprites.icons.id, StructureLayer.Z + 2)
	f.Parent = self.root
	return {
		frame = f,
		fill = nil,
		glyph = glyph,
		level = nil,
		rank_on = false,
		level_vis = nil,
		kind = -1,
		owner = -1,
		state_key = -1,
		size = -1,
		x = -1e9,
		y = -1e9,
		glyph_on = true,
		bar_on = false,
		bar_w = -1,
		bar_h = -1,
		bar_x = -1e9,
		bar_y = -1e9,
		bar_edge = -1,
		fill_w = -1,
		fill_h = -1,
		fill_c = -1,
		pass = -1,
	}
end

--- The rank chip of a plate, made on first use: one label, on the plate's lower corner.
local function level_label(p: Plate): TextLabel
	local level = p.level
	if level == nil then
		local l = Instance.new("TextLabel")
		l.Name = "Level"
		l.BackgroundColor3 = MapStyle.INK
		l.BackgroundTransparency = 0.08
		l.BorderSizePixel = 0
		l.AnchorPoint = Vector2.new(1, 1)
		l.Position = UDim2.fromScale(1.12, 1.12)
		l.Size = UDim2.fromScale(0.66, 0.46)
		l.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
		l.TextScaled = true
		l.TextColor3 = MapStyle.PAPER
		l.ZIndex = StructureLayer.Z + 3
		l.Parent = p.frame
		p.level = l
		level = l
	end
	return level :: TextLabel
end

function StructureLayer._release(self: any, p: Plate)
	p.frame.Visible = false
	if p.bar ~= nil and p.bar_on then
		p.bar.Visible = false
		p.bar_on = false
	end
	p.kind = -1
	p.owner = -1
	p.x, p.y = -1e9, -1e9
	p.state_key = -1
	table.insert(self._pool, p)
end

function StructureLayer._style(self: any, p: Plate, s: any, building: boolean)
	local st = self._state
	local k = s.kind
	-- one image for the plate once it has loaded (see the header)
	local one = one_ready
	-- (a number, not a string: built for every plate on screen at every camera move, and a phone pays
	-- for the strings it made; 2026-10-12)
	local key = (((k * 1024 + s.owner) * 2 + (if building then 1 else 0)) * 4096 + math.min(s.level or 1, 4095)) * 2
		+ (if one then 1 else 0)
	if key == p.state_key then
		return
	end
	p.state_key = key
	p.owner = s.owner
	local shapes, icons, col = Sprites.shapes, Sprites.icons, k
	-- the owner's colour (muted towards clay while it is raised); the rim is a dark of it (baked into the one image
	-- as grey, BORDER_V on the two-image path), the glyph dark or pale by which stands out more
	local fill_col = MapStyle.plate_fill(st:owner_color(s.owner), building)
	local rim_col = value_scale(fill_col, StructureLayer.BORDER_V)
	p.glyph.ImageColor3 = MapStyle.glyph_on(fill_col)
	local plate = p.frame
	local cell = shapes.cell
	plate.ImageRectSize = Vector2.new(cell, cell)
	-- (plates are one a frame, shared: MapArt.plate_col maps the kind to its frame's cell)
	local pc = if Sprites.plate_col ~= nil then (Sprites.plate_col[k + 1] or k) else k
	plate.ImageRectOffset = Vector2.new(pc * cell, 0)
	if one then
		Sprites.set(plate, ONE.id)
		plate.ImageColor3 = fill_col
		if p.fill ~= nil then
			p.fill.Visible = false
		end
	else
		Sprites.set(plate, shapes.id)
		plate.ImageColor3 = rim_col
		local fill = p.fill
		if fill == nil then
			local f = image(plate, "Fill", shapes.id, StructureLayer.Z + 1)
			f.Size = UDim2.fromScale(1, 1)
			p.fill = f
			fill = f
		end
		local f = fill :: ImageLabel
		f.Visible = true
		Sprites.set(f, shapes.id)
		f.ImageRectOffset = Vector2.new(pc * cell, cell)
		f.ImageRectSize = Vector2.new(cell, cell)
		f.ImageColor3 = fill_col
	end
	-- (a medieval start date draws its own glyphs: Data/PeriodTech, MapArt.icons_m)
	if PeriodTech.applied() ~= nil and Sprites.icons_m ~= nil then
		icons = Sprites.icons_m
	end
	Sprites.set(p.glyph, icons.id)
	local ic = icons.cell
	p.glyph.ImageRectOffset = Vector2.new(col * ic, 0)
	p.glyph.ImageRectSize = Vector2.new(ic, ic)
	-- the glyph spans ICON_FILL / SHAPE_SCALE of the plate
	local g = ICON_FILL[k + 1] / SHAPE_SCALE[k + 1]
	p.glyph.Size = UDim2.fromScale(g, g)
	local lv = s.level or 1
	p.rank_on = lv >= 2
	if p.rank_on then
		level_label(p).Text = MapStyle.rank_text(lv)
	end
end

--- Construction progress, else (SAM / silo) missile
--- readiness while any missile reloads; nil = no bar.
function StructureLayer.progress(s: any, rt: number): number?
	local at = s.active_tick or 0
	if at > rt then
		local dur = Rules.BUILD_TICKS[s.kind] or 50
		return math.clamp(1 - (at - rt) / math.max(1, dur), 0, 1)
	end
	local shots = s.shots
	-- (a SAM's and a silo's missiles; an aerodrome rearming, a railgun reloading: Rules.RELOAD_TICKS)
	local reload = Rules.RELOAD_TICKS[s.kind] or 0
	if reload > 0 and shots ~= nil and #shots > 0 then
		local cd = reload
		local slots = math.max(1, s.level or 1)
		local reloading, done = 0, 0.0
		for _, t in shots do
			local e = rt - t
			if e < cd then
				reloading += 1
				done += math.max(0, e) / cd
			end
		end
		if reloading > 0 then
			local r = math.clamp((slots - reloading) / slots + done / slots, 0, 1)
			if r < 1 then
				return r
			end
		end
	end
	return nil
end

function StructureLayer._bar(self: any, p: Plate, progress: number?, x: number, y: number, ppt: number, building: boolean, size: number?)
	local w = StructureLayer.BAR_W * ppt
	if progress == nil or w < StructureLayer.BAR_MIN_PX then
		if p.bar ~= nil and p.bar_on then
			p.bar.Visible = false
			p.bar_on = false
		end
		return
	end
	local bar, fill = p.bar, p.bar_fill
	if bar == nil or fill == nil then
		local b = Instance.new("Frame")
		b.Name = "Bar"
		b.BorderSizePixel = 0
		b.BackgroundColor3 = Color3.fromRGB(8, 14, 18)
		b.BackgroundTransparency = 0.1
		b.ZIndex = StructureLayer.Z + 4
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 2)
		bc.Parent = b
		local f = Instance.new("Frame")
		f.Name = "Fill"
		f.BorderSizePixel = 0
		f.ZIndex = StructureLayer.Z + 5
		local fc = Instance.new("UICorner")
		fc.CornerRadius = UDim.new(0, 1)
		fc.Parent = f
		f.Parent = b
		b.Parent = self._bar_root
		p.bar, p.bar_fill = b, f
		bar, fill = b, f
	end
	local b = bar :: Frame
	local f = fill :: Frame
	-- (zoomed right in, 14 x 3 tiles is a slab 200 px wide: the bar stops growing, a slim pill)
	local h = math.clamp(math.round(StructureLayer.BAR_H * ppt), 3, StructureLayer.BAR_MAX_H)
	local bw = math.clamp(math.round(StructureLayer.BAR_BORDER * ppt), 1, 2)
	local wr = math.round(math.min(w, StructureLayer.BAR_MAX_W))
	-- (each written only when it changed: a pan moves the bar, a reload grows its fill now and then)
	if not p.bar_on then
		p.bar_on = true
		b.Visible = true
	end
	if p.bar_w ~= wr or p.bar_h ~= h then
		p.bar_w, p.bar_h = wr, h
		b.Size = UDim2.fromOffset(wr, h)
	end
	-- (below the plate, never over it: zoomed out, BAR_OFFSET_Y tiles is less than half a plate)
	local below = math.max(StructureLayer.BAR_OFFSET_Y * ppt, (size or 0) * 0.5 + 2)
	local bx, by = math.round(x - wr / 2), math.round(y + below)
	if p.bar_x ~= bx or p.bar_y ~= by then
		p.bar_x, p.bar_y = bx, by
		b.Position = UDim2.fromOffset(bx, by)
	end
	local inner = math.max(0, wr - 2 * bw)
	if p.bar_edge ~= bw then
		p.bar_edge = bw
		f.Position = UDim2.fromOffset(bw, bw)
	end
	local fw, fh = math.round(progress * inner), math.max(1, h - 2 * bw)
	if p.fill_w ~= fw or p.fill_h ~= fh then
		p.fill_w, p.fill_h = fw, fh
		f.Size = UDim2.fromOffset(fw, fh)
	end
	local ci = MapStyle.bar_state(progress, building)
	if p.fill_c ~= ci then
		p.fill_c = ci
		f.BackgroundColor3 = MapStyle.bar_color(ci)
	end
end

--- One structure's plate at (x, y) (screen px), `size` px: style, size, position (written only when
--- they changed), its progress bar. Returns the progress (nil = no bar).
function StructureLayer._place(
	self: any,
	p: Plate,
	s: any,
	rt: number,
	x: number,
	y: number,
	size: number,
	dots: boolean,
	ppt: number
): number?
	local building = (s.active_tick or 0) > rt
	self:_style(p, s, building)
	local px = math.round(size)
	if p.size ~= px then
		p.size = px
		p.frame.Size = UDim2.fromOffset(px, px)
	end
	if p.glyph_on == dots then
		p.glyph_on = not dots
		p.glyph.Visible = not dots
	end
	local chip = p.rank_on and not dots
	if p.level ~= nil and p.level_vis ~= chip then
		p.level_vis = chip
		p.level.Visible = chip
	end
	local rx, ry = math.round(x), math.round(y)
	if rx ~= p.x or ry ~= p.y then
		p.x, p.y = rx, ry
		p.frame.Position = UDim2.fromOffset(rx, ry)
	end
	local progress = StructureLayer.progress(s, rt)
	self:_bar(p, progress, x, y, ppt, building, px)
	return progress
end

--- One structure drawn on its own (between full passes, the camera still): placed when on screen,
--- its plate let go when not or when it is gone. True while it is built or reloads.
function StructureLayer._visit(
	self: any,
	st: any,
	sid: number,
	rt: number,
	base: number,
	dots: boolean,
	ppt: number
): boolean
	local cam = self.view.rig
	local s = st.structures[sid]
	local p = self._plates[sid]
	if s ~= nil then
		local x, y = cam:tile_to_screen(s.tile)
		local size = base * (SHAPE_SCALE[s.kind + 1] or 1.0)
		if cam:on_screen(x, y, size) then
			if p == nil then
				p = self:_acquire()
				self._plates[sid] = p
			end
			local progress = self:_place(p :: Plate, s, rt, x, y, size, dots, ppt)
			return progress ~= nil or (s.active_tick or 0) > rt
		end
	end
	if p ~= nil then
		self:_release(p)
		self._plates[sid] = nil
	end
	return false
end

function StructureLayer.tick(self: any, _dt: number)
	local st = self._state
	if st == nil then
		return
	end
	-- (a structure added, captured, removed, upgraded or starting to reload is drawn again on its own
	-- next frame: on_structure_* above, forwarded from GameState's signals)
	local cam = self.view.rig
	local rt = st.render_tick or st.tick or 0
	local k = tonumber(st.map and st.map.k_lin) or Rules.K_LIN
	-- the zoom: device px per full-size tile
	local zoom = cam.scale / k * StructureLayer.DEVICE_RATIO
	local icon_scale
	if zoom <= StructureLayer.DOTS_ZOOM then
		icon_scale = StructureLayer.DOT_SCALE
	elseif zoom >= StructureLayer.GROW_ZOOM then
		icon_scale = zoom / StructureLayer.GROW_ZOOM
	else
		icon_scale = math.min(1.0, zoom / StructureLayer.SCALE_FACTOR_OUT)
	end
	local dots = zoom <= StructureLayer.DOTS_ZOOM
	local base = StructureLayer.ICON_SIZE * icon_scale
	local ppt = cam.scale / k
	-- (the one-image atlas arrived: every plate is styled again)
	if one_ready ~= self._one_seen then
		self._one_seen = one_ready
		self._dirty = true
	end
	local anim = self._anim
	local touched = self._touched
	if not self._dirty and cam.version == self._cam_version then
		-- nothing moved: only the plates being built or reloading change (their bar, and their
		-- style once finished) — late games always have some, and redrawing every plate each frame
		-- cost the most there — and those a structure event named (added, captured, removed,
		-- upgraded, a missile fired)
		for sid in touched do
			anim[sid] = true
		end
		table.clear(touched)
		for sid in anim do
			if not self:_visit(st, sid, rt, base, dots, ppt) then
				anim[sid] = nil
			end
		end
		return
	end
	self._dirty = false
	self._cam_version = cam.version
	table.clear(touched)
	table.clear(anim)
	local pass = self._pass + 1
	self._pass = pass
	-- (MapCamera.tile_to_screen and on_screen worked out here, the same sums: every structure on the
	-- map goes through them on every frame of a pan or a pinch, and off the screen that is all it
	-- costs; two method calls each were most of it on a phone, which runs Luau without native code)
	local ax, ay = cam:anchor()
	local sc, cu, cv, W = cam.scale, cam.cu, cam.cv, cam.W
	local vp = cam:viewport_size()
	local vw, vh = vp.X, vp.Y
	local plates = self._plates
	for sid, s in st.structures do
		local tile = s.tile
		local x = ax + (tile % W + 0.5 - cu) * sc
		local y = ay + (tile // W + 0.5 - cv) * sc
		local size = base * (SHAPE_SCALE[s.kind + 1] or 1.0)
		if not (x >= -size and y >= -size and x <= vw + size and y <= vh + size) then
			continue
		end
		local p = plates[sid]
		if p == nil then
			p = self:_acquire()
			plates[sid] = p
		end
		p.pass = pass
		local progress = self:_place(p, s, rt, x, y, size, dots, ppt)
		if progress ~= nil or (s.active_tick or 0) > rt then
			anim[sid] = true
		end
	end
	for sid, p in plates do
		if p.pass ~= pass then
			self:_release(p)
			plates[sid] = nil
		end
	end
end

return StructureLayer
