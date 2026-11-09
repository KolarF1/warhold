--!strict
-- 2D map camera for a flat tile map drawn in the GUI.
--
-- Map space: u = tile column + fraction (0..W), v = tile row + fraction (0 = top edge .. H); a
-- tile's centre is (x + 0.5, y + 0.5). Maps are flat rectangles (nothing wraps).
-- Screen space: viewport px (Camera.ViewportSize / InputObject.Position + GuiInset).
--
-- The view is (cu, cv, scale): the map point (cu, cv) sits at the view anchor — the viewport centre
-- moved by screen_offset (the middle of the HUD-free area, MapView.set_safe_area) — and one tile is
-- `scale` px wide. Once the map is bigger than the view it pans until an edge reaches the view
-- anchor; smaller, it stays centred (clamp_axis).
--
-- It also provides the camera-rig API the input controller uses (halt, viewport_size, pan,
-- zoom_by, globe_hit, is_moving, begin_drag, drag_by, end_drag), so the input keeps GlobeInput's
-- touch / mouse model.
-- (Lune tests load this file with the shared modules from the repo.)
local IS_ROBLOX = (game :: any) ~= nil
local Defs = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage"):WaitForChild("Airfront"):WaitForChild("Core"):WaitForChild("Defs")
	) :: any
	else (require :: any)("../../shared/Core/Defs")

local FrameClock = if IS_ROBLOX
	then require((script :: any).Parent:WaitForChild("FrameClock"))
	else (require :: any)("./FrameClock")
local MapCamera = {}
MapCamera.__index = MapCamera

--- Closest zoom: px per tile at a 900 px tall view (scaled with the view height), for a map with
--- k_lin = 2 (a tile is 2 x 2 full-size tiles, so 26 px
--- per full-size tile: a finger picks a tile more easily this close).
MapCamera.MAX_SCALE_900 = 52.0
--- Farthest zoom of a flat map: the whole map fits with this margin (fraction of the view).
MapCamera.FIT_MARGIN = 0.96
--- Wheel / pinch zoom smoothing time constant (s). (Kept short: a pinch must not trail the fingers.)
MapCamera.ZOOM_TAU = 0.09
--- Drag inertia decay per second (velocity multiplier): a shorter, heavier coast, so a map stops near where it was left.
MapCamera.INERTIA_DECAY = 0.001
--- A release this long after the last drag step keeps no inertia (ms).
MapCamera.INERTIA_HOLD_MS = 110
--- How much of each new drag step the coast's speed takes up.
MapCamera.DRAG_SMOOTH = 0.35
--- The fastest fling, in view widths per second.
MapCamera.FLING_CAP = 1.8
--- A long focus trip pulls back at most this much (log of the zoom).
MapCamera.FOCUS_PULL = 0.32
--- The title's shot (set_shot): one slow push on a landmark, from and to this many times the farthest zoom, over this
--- long, moved this often. Then it holds, and nothing on the map is redrawn: an idle phone spends nothing.
MapCamera.SHOT_FROM = 2.0
MapCamera.SHOT_TO = 2.7
MapCamera.SHOT_S = 45.0
MapCamera.SHOT_STEP_S = 0.1
--- How many sample points across the free part of the view, and around the landmark, shot_sites reads for land.
MapCamera.SHOT_SAMPLES = 8

export type MapCamera = typeof(setmetatable(
	{} :: {
		camera: Camera?,
		W: number,
		H: number,
		cu: number,
		cv: number,
		scale: number,
		target_scale: number,
		screen_offset: Vector2,
		dragging: boolean,
		attract: boolean,
		_vel: Vector2,
		_last_drag_ms: number,
		_anchor_map: Vector2?,
		_anchor_screen: Vector2?,
		_focus_active: boolean,
		_focus_t: number,
		_focus_dur: number,
		_focus_from: Vector3,
		_focus_to: Vector3,
		_shake: number,
		_shake_px: Vector2,
		_vp: Vector2,
		version: number,
		lat: number,
		lon: number,
		_shot_u: number?,
		_shot_v: number,
		_shot_side: number,
		_shot_t: number,
		_shot_acc: number,
	},
	MapCamera
))

local function now_ms(): number
	return FrameClock.now() * 1000
end

function MapCamera.new(camera: Camera?, map: any?): MapCamera
	local self = setmetatable({
		camera = camera,
		W = Defs.W,
		H = Defs.H,
		cu = Defs.W * 0.5,
		cv = Defs.H * 0.5,
		scale = 2.0,
		target_scale = 2.0,
		screen_offset = Vector2.zero,
		dragging = false,
		attract = false,
		_vel = Vector2.zero,
		_last_drag_ms = 0.0,
		_anchor_map = nil :: Vector2?,
		_anchor_screen = nil :: Vector2?,
		_focus_active = false,
		_focus_t = 0.0,
		_focus_dur = 1.0,
		_focus_from = Vector3.zero,
		_focus_to = Vector3.zero,
		_shake = 0.0,
		_shake_px = Vector2.zero,
		_vp = Vector2.new(1600, 900),
		--- the anchor (anchor()): its screen position, the vectors it was made from, and as a Vector2
		_ax = 0.0,
		_ay = 0.0,
		_a_vp = nil :: Vector2?,
		_a_so = nil :: Vector2?,
		_a_sh = nil :: Vector2?,
		_a_v = nil :: Vector2?,
		--- bumps whenever the view changes (layers skip re-projection while it is unchanged)
		version = 0,
		--- lat / lon (degrees) of the view anchor read as an equirectangular world map (the spawn
		--- advisor reads them like the globe rig's)
		lat = 0.0,
		lon = 0.0,
		--- the title's shot (set_shot): the map point, the column's width in viewport px, how far along, time since its last move
		_shot_u = nil :: number?,
		_shot_v = 0.0,
		_shot_side = 0.0,
		_shot_t = 0.0,
		_shot_acc = 0.0,
	}, MapCamera)
	self:_read_viewport()
	if map ~= nil then
		self:set_map(map)
	end
	self.scale = self:min_scale()
	self.target_scale = self.scale
	return self
end

--- Adopt a map's size (map.W / map.H or width / height).
function MapCamera.set_map(self: MapCamera, map: any)
	local w = tonumber(map.W or map.width) or Defs.W
	local h = tonumber(map.H or map.height) or Defs.H
	if w == self.W and h == self.H then
		return
	end
	self.W, self.H = w, h
	self.cu, self.cv = w * 0.5, h * 0.5
	self:halt()
	self.scale = self:min_scale()
	self.target_scale = self.scale
	self:_clamp()
	self:_bump()
end

function MapCamera._read_viewport(self: MapCamera)
	if not IS_ROBLOX then
		return
	end
	local cam = self.camera or workspace.CurrentCamera
	if cam then
		local v = cam.ViewportSize
		if v.X > 1 and v.Y > 1 then
			self._vp = v
		end
	end
end

function MapCamera.viewport_size(self: MapCamera): Vector2
	return self._vp
end

function MapCamera.viewport_height(self: MapCamera): number
	return self._vp.Y
end

--- Farthest zoom: the whole map fits with a margin.
function MapCamera.min_scale(self: MapCamera): number
	return math.min(self._vp.X / self.W, self._vp.Y / self.H) * MapCamera.FIT_MARGIN
end

function MapCamera.max_scale(self: MapCamera): number
	return math.max(MapCamera.MAX_SCALE_900 * math.max(self._vp.Y, 300.0) / 900.0, self:min_scale() * 2)
end

function MapCamera.clamp_scale(self: MapCamera, s: number): number
	return math.clamp(s, self:min_scale(), self:max_scale())
end

--- The view anchor (viewport px): where (cu, cv) is drawn.
--- The anchor's screen position, kept until the viewport, the offset or the shake is replaced (each
--- is a new Vector2 when it changes: compared by identity). Every map point drawn is projected through
--- it, and building it anew cost three Vector2s a call: two a rail, one a structure, unit and label,
--- every frame the camera moved (2026-10-12, phones).
local function anchor(self: any): (number, number)
	local vp, so, sh = self._vp, self.screen_offset, self._shake_px
	if not (rawequal(vp, self._a_vp) and rawequal(so, self._a_so) and rawequal(sh, self._a_sh)) then
		self._a_vp, self._a_so, self._a_sh = vp, so, sh
		self._ax = vp.X * 0.5 + so.X + sh.X
		self._ay = vp.Y * 0.5 + so.Y + sh.Y
		self._a_v = nil
	end
	return self._ax, self._ay
end
MapCamera.anchor = anchor

function MapCamera.anchor_px(self: MapCamera): Vector2
	local ax, ay = anchor(self)
	local v = self._a_v
	if v == nil then
		v = Vector2.new(ax, ay)
		self._a_v = v
	end
	return v
end

-- ---------------------------------------------------------------------------------------------
-- Projection
-- ---------------------------------------------------------------------------------------------

--- Screen position (viewport px) of map point (u, v).
function MapCamera.map_to_screen(self: MapCamera, u: number, v: number): (number, number)
	local ax, ay = anchor(self)
	local s = self.scale
	return ax + (u - self.cu) * s, ay + (v - self.cv) * s
end

--- Map point under a screen position (may lie off the map).
function MapCamera.screen_to_map(self: MapCamera, x: number, y: number): (number, number)
	local ax, ay = anchor(self)
	local s = self.scale
	return self.cu + (x - ax) / s, self.cv + (y - ay) / s
end

--- Tile index under a screen position, or -1 off the map.
function MapCamera.tile_at_screen(self: MapCamera, pos: Vector2): number
	local u, v = self:screen_to_map(pos.X, pos.Y)
	if v < 0 or v >= self.H or u < 0 or u >= self.W then
		return -1
	end
	return math.floor(v) * self.W + math.floor(u)
end

--- Screen position of a tile's centre.
function MapCamera.tile_to_screen(self: MapCamera, tile: number): (number, number)
	local w = self.W
	return self:map_to_screen(tile % w + 0.5, tile // w + 0.5)
end

--- Map point of a lat / lon (degrees) read as an equirectangular world map (legacy Earth data).
function MapCamera.latlon_to_map(self: MapCamera, lat: number, lon: number): (number, number)
	return (lon + 180.0) / 360.0 * self.W, (90.0 - lat) / 180.0 * self.H
end

--- Map point of a globe direction (x, y, z) — legacy Earth unit poses (until the flat sim lands).
function MapCamera.xyz_to_map(self: MapCamera, x: number, y: number, z: number): (number, number)
	local lat, lon = Defs.xyz_latlon(x, y, z)
	return self:latlon_to_map(lat, lon)
end

--- Screen position of a globe direction.
function MapCamera.xyz_to_screen(self: MapCamera, x: number, y: number, z: number): (number, number)
	local u, v = self:xyz_to_map(x, y, z)
	return self:map_to_screen(u, v)
end

--- True when a screen point is inside the viewport grown by `margin` px.
function MapCamera.on_screen(self: MapCamera, x: number, y: number, margin: number?): boolean
	local m = margin or 0.0
	return x >= -m and y >= -m and x <= self._vp.X + m and y <= self._vp.Y + m
end

--- Visible map rect (u0, v0, u1, v1); may extend past the map.
function MapCamera.visible_rect(self: MapCamera): (number, number, number, number)
	local a = self:anchor_px()
	local s = self.scale
	return self.cu - a.X / s, self.cv - a.Y / s, self.cu + (self._vp.X - a.X) / s, self.cv + (self._vp.Y - a.Y) / s
end

--- Map tiles per screen px.
function MapCamera.tiles_per_px(self: MapCamera): number
	return 1.0 / self.scale
end

--- Degrees of latitude per screen px on the Earth map (the globe rig's unit).
function MapCamera.deg_per_px(self: MapCamera): number
	return 180.0 / self.H / self.scale
end

-- ---------------------------------------------------------------------------------------------
-- Motion
-- ---------------------------------------------------------------------------------------------

-- One axis of the pan limits: a map bigger than the view may be panned until its edge
-- reaches the view anchor (the middle of the HUD-free area), so the top / bottom / side rows can be
-- brought out from under the HUD. A map smaller than the view stays centred, and as the view grows
-- from CENTRE_FROM of the map's size to all of it the range narrows to the centre smoothly. It was a
-- step from one rule to the other: a camera zooming out, away from the middle, snapped across the
-- screen as each axis crossed it (2026-10-12, seen in the trailer's last shot: the camera snapped around
-- while zooming out).
MapCamera.CENTRE_FROM = 0.75
--- The share of the view the camera may pan past the map's edge.
MapCamera.EDGE_SLACK = 0.18
local function clamp_axis(c: number, size: number, before: number, after: number): number
	local span = before + after
	-- (no view to keep the map in: a zero scale, or a viewport not known yet)
	if not (span < math.huge) then
		return size * 0.5
	end
	local centre = (size - after + before) * 0.5
	local t = math.clamp((span / size - MapCamera.CENTRE_FROM) / (1 - MapCamera.CENTRE_FROM), 0, 1)
	local lo = centre * t
	-- (the two ends meet at the centre once t is 1, but in floating point the upper one can land a
	-- hair below the lower, and math.clamp throws when max < min: in 9% of zoomed-out views on v82, the
	-- game's top error that day, half a million a day, and the map's update stopped on those frames)
	local hi = math.max(lo, size + (centre - size) * t)
	-- (some slack past the edges, as the grand strategy maps give: a narrow map like Europe stopped the camera hard at
	-- its border, which felt jumpy; playtest 2026-11-08)
	local slack = span * MapCamera.EDGE_SLACK
	return math.clamp(c, lo - slack, hi + slack)
end
MapCamera._clamp_axis = clamp_axis

function MapCamera._clamp(self: MapCamera)
	local a = self:anchor_px()
	local s = self.scale
	self.cv = clamp_axis(self.cv, self.H, a.Y / s, (self._vp.Y - a.Y) / s)
	self.cu = clamp_axis(self.cu, self.W, a.X / s, (self._vp.X - a.X) / s)
end

function MapCamera._bump(self: MapCamera)
	self.version += 1
	self.lat = 90.0 - self.cv / self.H * 180.0
	self.lon = self.cu / self.W * 360.0 - 180.0
end

-- Globe-camera distance (globe radii, 1 + altitude) <-> map zoom, so callers written for the globe
-- (focus_tile(tile, distance), camera_distance) frame about the same area: px per tile =
-- DIST_K * view height / altitude (the globe's closest zoom, altitude 0.22, is ~18 px per tile on a
-- 900 px view; its default 1.6 is ~2.5, the whole Earth).
local DIST_K = 0.0044

function MapCamera.distance_to_scale(self: MapCamera, d: number): number
	local alt = math.max(d - 1.0, 0.02)
	return self:clamp_scale(DIST_K * self._vp.Y / alt)
end

function MapCamera.scale_to_distance(self: MapCamera, s: number): number
	return 1.0 + DIST_K * self._vp.Y / math.max(s, 1e-3)
end

function MapCamera.begin_drag(self: MapCamera)
	self.dragging = true
	self._focus_active = false
	self._anchor_map = nil
	self._anchor_screen = nil
	self._vel = Vector2.zero
end

--- Move the map with the pointer by `rel` screen px.
function MapCamera.drag_by(self: MapCamera, rel: Vector2)
	local s = self.scale
	self.cu -= rel.X / s
	self.cv -= rel.Y / s
	local now = now_ms()
	local dt = math.max((now - self._last_drag_ms) / 1000.0, 1.0 / 240.0)
	if now - self._last_drag_ms < 100 then
		-- map columns / rows per second, smoothed
		local v = Vector2.new(-rel.X / s, -rel.Y / s) / dt
		self._vel = self._vel:Lerp(v, MapCamera.DRAG_SMOOTH)
	else
		self._vel = Vector2.zero
	end
	self._last_drag_ms = now
	self:_clamp()
	self:_bump()
end

function MapCamera.end_drag(self: MapCamera)
	self.dragging = false
	if now_ms() - self._last_drag_ms > MapCamera.INERTIA_HOLD_MS then
		self._vel = Vector2.zero
	end
	-- cap the fling
	local cap = MapCamera.FLING_CAP * self._vp.X / self.scale
	if self._vel.Magnitude > cap then
		self._vel = self._vel.Unit * cap
	end
end

--- True while a focus animation runs or inertia moves the map faster than `px_per_s`.
function MapCamera.is_moving(self: MapCamera, px_per_s: number): boolean
	if self._focus_active then
		return true
	end
	if self.dragging then
		return false
	end
	return self._vel.Magnitude * self.scale > px_per_s
end

--- Stop any drag, inertia, zoom glide or focus animation.
function MapCamera.halt(self: MapCamera)
	self.dragging = false
	self._vel = Vector2.zero
	self._focus_active = false
	self.target_scale = self.scale
	self._anchor_map = nil
	self._anchor_screen = nil
end

--- Keyboard / programmatic pan in screen directions (x right, y down), `amount` in view heights.
function MapCamera.pan(self: MapCamera, dir: Vector2, amount: number)
	self._focus_active = false
	local px = dir * amount * self._vp.Y
	self.cu += px.X / self.scale
	self.cv += px.Y / self.scale
	self:_clamp()
	self:_bump()
end

--- The map point under a screen position (the anchor zoom_by keeps still), clamped to the map.
function MapCamera.globe_hit(self: MapCamera, screen_pos: Vector2): Vector2
	local u, v = self:screen_to_map(screen_pos.X, screen_pos.Y)
	return Vector2.new(math.clamp(u, 0, self.W), math.clamp(v, 0, self.H))
end

--- factor > 1 zooms in, gliding toward the target (ZOOM_TAU). `anchor` (a map point from
--- globe_hit) stays under the same screen position; nil = the view anchor.
function MapCamera.zoom_by(self: MapCamera, factor: number, anchor: any?)
	if factor <= 0.0 then
		return
	end
	self._focus_active = false
	self.target_scale = self:clamp_scale(self.target_scale * factor)
	if typeof(anchor) == "Vector2" then
		local a = anchor :: Vector2
		local sx, sy = self:map_to_screen(a.X, a.Y)
		self._anchor_map = a
		self._anchor_screen = Vector2.new(sx, sy)
	else
		self._anchor_map = nil
		self._anchor_screen = nil
	end
end

--- Jump to a zoom (px per tile) at once, about the view anchor.
function MapCamera.set_scale_immediate(self: MapCamera, s: number)
	self.scale = self:clamp_scale(s)
	self.target_scale = self.scale
	self._anchor_map = nil
	self:_clamp()
	self:_bump()
end

--- Centre the view anchor on map point (u, v) at once.
function MapCamera.look_at(self: MapCamera, u: number, v: number)
	self.cu = u
	self.cv = v
	self:_clamp()
	self:_bump()
end

--- Animate to map point (u, v) at zoom `scale` (<= 0 keeps the current zoom) over `duration` s.
function MapCamera.focus(self: MapCamera, u: number, v: number, scale: number, duration: number)
	local s1 = if scale > 0 then self:clamp_scale(scale) else self.scale
	self._focus_from = Vector3.new(self.cu, self.cv, self.scale)
	self._focus_to = Vector3.new(u, v, s1)
	self._focus_dur = math.max(duration, 0.01)
	self._focus_t = 0.0
	self._focus_active = true
	self._vel = Vector2.zero
	self._anchor_map = nil
	self.target_scale = s1
end

function MapCamera.focus_tile(self: MapCamera, tile: number, scale: number, duration: number)
	local w = self.W
	self:focus(tile % w + 0.5, tile // w + 0.5, scale, duration)
end

function MapCamera.add_shake(self: MapCamera, strength: number)
	-- (Roblox's Reduce Motion setting: the blast still flashes, the view holds still)
	if (game :: any) ~= nil and game:GetService("GuiService").ReducedMotionEnabled then
		return
	end
	self._shake = math.max(self._shake, strength)
end

local function ease_in_out(t: number): number
	return t * t * t * (t * (t * 6 - 15) + 10)
end

--- (Roblox's Reduce Motion setting: the title's shot holds still)
local function reduced_motion(): boolean
	return (game :: any) ~= nil and game:GetService("GuiService").ReducedMotionEnabled
end

--- The title's shot, worked out: a `w` x `h` map on a viewport `vp`, framing map point (u, v) in the free part right of a
--- column `side` px wide, `k` of the way through the push (0..1). Returns the zoom and the view's centre. Pure.
--- The whole viewport stays on the map, the column's width too: the zoom never goes below the one where the map covers
--- the view (a tall map on a wide screen needs more than SHOT_FROM), and the centre stops where a map edge meets a screen
--- edge. (The player's own pan limits, _clamp, let an edge reach the middle of the screen: half of it empty navy.)
function MapCamera.shot_view(w: number, h: number, vp: Vector2, u: number, v: number, side: number, k: number): (number, number, number)
	local fit = math.min(vp.X / w, vp.Y / h) * MapCamera.FIT_MARGIN
	local cover = math.max(vp.X / w, vp.Y / h)
	local from = math.max(fit * MapCamera.SHOT_FROM, cover)
	local s = from * (MapCamera.SHOT_TO / MapCamera.SHOT_FROM) ^ k
	local half_w, half_h = vp.X * 0.5 / s, vp.Y * 0.5 / s
	local cu = u - side * 0.5 / s
	return s, if half_w * 2 >= w then w * 0.5 else math.clamp(cu, half_w, w - half_w), if half_h * 2 >= h then h * 0.5 else math.clamp(v, half_h, h - half_h)
end

--- The landmarks worth a shot, best first: well inside the land, and framed where the shot means to frame them. `sites` is
--- SimLandmarks.sites, `land_at(u, v)` says whether a map point is land. A site's score is the land in the free part of its
--- view and close around it, less what the map's edge pushed the frame off it (Antarctica, the far north). The best third stays. Pure.
function MapCamera.shot_sites(sites: { any }, w: number, h: number, vp: Vector2, side: number, land_at: (number, number) -> boolean): { any }
	local n = MapCamera.SHOT_SAMPLES
	local scored = {}
	for i, site in sites do
		local u, v = site.tile % w + 0.5, site.tile // w + 0.5
		local s, cu, cv = MapCamera.shot_view(w, h, vp, u, v, side, 0.0)
		local u0, u1 = cu + (side - vp.X * 0.5) / s, cu + vp.X * 0.5 / s
		local v0, v1 = cv - vp.Y * 0.5 / s, cv + vp.Y * 0.5 / s
		local frame, near = 0, 0
		for y = 1, n do
			for x = 1, n do
				local fx, fy = (x - 0.5) / n, (y - 0.5) / n
				if land_at(u0 + (u1 - u0) * fx, v0 + (v1 - v0) * fy) then
					frame += 1
				end
				if land_at(u + (fx - 0.5) * (u1 - u0) * 0.4, v + (fy - 0.5) * (v1 - v0) * 0.4) then
					near += 1
				end
			end
		end
		-- how far the frame slid off the landmark, as a share of the view (0: not at all)
		local slid = math.abs(cu - (u - side * 0.5 / s)) * s / vp.X + math.abs(cv - v) * s / vp.Y
		local score = (frame + near) / (2 * n * n) * math.max(1.0 - slid * 2.0, 0.0)
		table.insert(scored, { site = site, score = score, i = i })
	end
	table.sort(scored, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.i < b.i
	end)
	local out = {}
	for i = 1, math.ceil(#scored / 3) do
		table.insert(out, scored[i].site)
	end
	return out
end

--- The title's shot: frames map point (u, v) in the free part of the view, right of a column `side` viewport px wide, and
--- starts its slow push. The same point again keeps its place in the push (the column can change on a rotation).
function MapCamera.set_shot(self: MapCamera, u: number, v: number, side: number?)
	if self._shot_u ~= u or self._shot_v ~= v then
		self._shot_t = 0.0
	end
	self._shot_u, self._shot_v = u, v
	self._shot_side = side or 0.0
	self._shot_acc = 0.0
	self:_place_shot()
end

--- Puts the view where the shot says, now.
function MapCamera._place_shot(self: MapCamera)
	local u = self._shot_u
	if u == nil then
		return
	end
	local k = if reduced_motion() then 0.0 else ease_in_out(math.min(self._shot_t / MapCamera.SHOT_S, 1.0))
	local s, cu, cv = MapCamera.shot_view(self.W, self.H, self._vp, u, self._shot_v, self._shot_side, k)
	self.scale = s
	self.target_scale = s
	-- (shot_view centres on the screen; the anchor is what (cu, cv) is drawn at)
	local ax, ay = anchor(self)
	self.cu = cu + (ax - self._vp.X * 0.5) / s
	self.cv = cv + (ay - self._vp.Y * 0.5) / s
	self:_clamp()
	self:_bump()
end

--- The title is gone: forget its shot and show the whole map, the view a player chooses a start from. (Going from the title
--- to a war on a map of the same size, set_map changes nothing: the war opened on the title's corner, 2026-11-02.)
function MapCamera.leave_shot(self: MapCamera)
	self._shot_u = nil
	self._shot_t = 0.0
	self:halt()
	self.scale = self:min_scale()
	self.target_scale = self.scale
	self.cu, self.cv = self.W * 0.5, self.H * 0.5
	self:_clamp()
	self:_bump()
end

--- Per-frame: viewport, focus animation, zoom glide, inertia, the title's shot, shake.
function MapCamera.tick(self: MapCamera, dt: number)
	local vp0 = self._vp
	self:_read_viewport()
	local changed = self._vp ~= vp0
	if changed then
		self.scale = self:clamp_scale(self.scale)
		self.target_scale = self:clamp_scale(self.target_scale)
		if self.attract then
			self:_place_shot()
		end
	end
	if self._focus_active then
		self._focus_t += dt / self._focus_dur
		local t = ease_in_out(math.min(self._focus_t, 1.0))
		local a, b = self._focus_from, self._focus_to
		self.cu = a.X + (b.X - a.X) * t
		self.cv = a.Y + (b.Y - a.Y) * t
		-- zoom in log space, with a slight pull-back on long trips
		local ls = math.log(a.Z) + (math.log(b.Z) - math.log(a.Z)) * t
		local dist_px = (math.abs(b.X - a.X) + math.abs(b.Y - a.Y)) * a.Z
		local bump = math.clamp(dist_px / (self._vp.X * 3.0), 0.0, MapCamera.FOCUS_PULL)
		ls -= bump * math.sin(t * math.pi)
		self.scale = self:clamp_scale(math.exp(ls))
		self.target_scale = self.scale
		if self._focus_t >= 1.0 then
			self._focus_active = false
			self.scale = self:clamp_scale(b.Z)
			self.target_scale = self.scale
		end
		changed = true
	elseif math.abs(self.target_scale - self.scale) > 1e-4 * self.scale then
		local k = 1.0 - math.exp(-dt / MapCamera.ZOOM_TAU)
		self.scale = math.exp(math.log(self.scale) + (math.log(self.target_scale) - math.log(self.scale)) * k)
		if math.abs(self.target_scale - self.scale) <= 1e-4 * self.scale then
			self.scale = self.target_scale
		end
		local am, asp = self._anchor_map, self._anchor_screen
		if am and asp then
			-- keep the anchor map point under its screen position
			local ap = self:anchor_px()
			self.cu = am.X - (asp.X - ap.X) / self.scale
			self.cv = am.Y - (asp.Y - ap.Y) / self.scale
		end
		changed = true
	else
		self._anchor_map = nil
		self._anchor_screen = nil
	end
	if not self.dragging and not self._focus_active and self._vel.Magnitude > 1e-3 then
		self.cu += self._vel.X * dt
		self.cv += self._vel.Y * dt
		self._vel *= MapCamera.INERTIA_DECAY ^ dt
		if self._vel.Magnitude * self.scale < 4.0 then
			self._vel = Vector2.zero
		end
		changed = true
	end
	if self.attract and self._shot_u ~= nil and self._shot_t < MapCamera.SHOT_S and not self.dragging and not self._focus_active then
		self._shot_acc += dt
		if self._shot_acc >= MapCamera.SHOT_STEP_S then
			self._shot_t = if reduced_motion() then MapCamera.SHOT_S else self._shot_t + self._shot_acc
			self._shot_acc = 0.0
			self:_place_shot()
		end
	end
	if self._shake > 0.01 then
		local r = self._shake * 10.0
		self._shake_px = Vector2.new((math.random() * 2 - 1) * r, (math.random() * 2 - 1) * r)
		self._shake *= 0.02 ^ dt
		changed = true
	elseif self._shake_px ~= Vector2.zero then
		self._shake = 0.0
		self._shake_px = Vector2.zero
		changed = true
	end
	if changed then
		self:_clamp()
		self:_bump()
	end
end

return MapCamera
