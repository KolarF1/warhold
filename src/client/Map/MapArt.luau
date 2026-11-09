--!nonstrict
-- The map's sprites, ours (src/shared/Art/MapData, drawn by tools/art/mapart.luau): structure plates and glyphs
-- and the units' 13 px sprites, decoded and uploaded once as a few small EditableImages. It has the shape the
-- layers always used (`icons`, `shapes`, `shapes_one`, `units`, `units_one`, `status`: { id, cell, cols }),
-- but `id` is an ArtRef, so a layer sets images through `MapArt.set`. No asset id, so nothing to
-- moderate, nothing to wait for: the layers' "has it loaded yet" paths are ready at once.
local RS = game:GetService("ReplicatedStorage")
local Airfront = RS:WaitForChild("Airfront")
local Pack = require(Airfront:WaitForChild("Art"):WaitForChild("Pack")) :: any
local Data = require(Airfront:WaitForChild("Art"):WaitForChild("MapData")) :: any
local IconData = require(Airfront:WaitForChild("Art"):WaitForChild("IconData")) :: any
local Frames = require(Airfront:WaitForChild("Art"):WaitForChild("Frames")) :: any

local Registry = require(Airfront:WaitForChild("Art"):WaitForChild("Registry")) :: any
local _flags = require((script :: any).Parent.Parent:WaitForChild("UI"):WaitForChild("FlagArt")) :: any -- (registers the flag resolver)

local MapArt = {}

local function upload(rgba: buffer, w: number, h: number): any
	local ok, ref = pcall(function()
		local img = game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(w, h) })
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), rgba)
		return { art = true, content = Content.fromObject(img) }
	end)
	if ok then
		return ref
	end
	return { art = true, content = nil }
end

local function white(mask: buffer, w: number, h: number): buffer
	local rgba = buffer.create(w * h * 4)
	Pack.blit_white(rgba, w, mask, w, h, 0, 0)
	return rgba
end

--- Two masks as the layers' two rows (first on top, second below), white.
local function two_rows(a: buffer, b: buffer, w: number, h: number): buffer
	local rgba = buffer.create(w * h * 2 * 4)
	Pack.blit_white(rgba, w, a, w, h, 0, 0)
	Pack.blit_white(rgba, w, b, w, h, 0, h)
	return rgba
end

--- Rim under body in one image: the rim grey, the body white (one tint colours both). A unit's rim is what lies round
--- its body (mapart: the grown body less the body), so the two add up where they meet; a plate's rim is the whole
--- plate, its inset inside it, so they never add past full. The body's share of a pixel is against what covers it,
--- so a body thinning out with no rim under it (a shell's tracer) fades out in its own colour rather than darkening.
local function one_image(rim: buffer, body: buffer, w: number, h: number, grey: number): buffer
	local rgba = buffer.create(w * h * 4)
	for i = 0, w * h - 1 do
		local ra, ba = buffer.readu8(rim, i), buffer.readu8(body, i)
		local a = math.min(255, ra + ba)
		local k = if a > 0 then ba / a else 0
		local c = math.floor(grey * (1 - k) + 255 * k + 0.5)
		buffer.writeu32(rgba, i * 4, c + c * 256 + c * 65536 + a * 16777216)
	end
	return rgba
end

--- The share of a plate's size (ICON_SIZE, before its frame's scale) that its glyph spans.
MapArt.ICON_FILL = 0.62

local built = false

local function build()
	if built then
		return
	end
	built = true
	local rim = Data.plate_rim
	local inset = Data.plate_inset
	local gl = Data.glyphs
	local ub, ur = Data.unit_body, Data.unit_rim
	local rimm, insm = Pack.mask(rim.data, rim.w, rim.h), Pack.mask(inset.data, inset.w, inset.h)
	local glm = Pack.mask(gl.data, gl.w, gl.h)
	local ubm, urm = Pack.mask(ub.data, ub.w, ub.h), Pack.mask(ur.data, ur.w, ur.h)
	local kinds = #Data.kinds
	MapArt.icons = { id = upload(white(glm, gl.w, gl.h), gl.w, gl.h), cell = 64, cols = kinds }
	-- the medieval start dates' strip (Data/PeriodTech), same kinds and order; today's where the data has none
	local glmm = Data.glyphs_m
	MapArt.icons_m = if glmm ~= nil
		then { id = upload(white(Pack.mask(glmm.data, glmm.w, glmm.h), glmm.w, glmm.h), glmm.w, glmm.h), cell = 64, cols = kinds }
		else MapArt.icons
	-- (one plate a frame: Data.plate_col maps a kind to its cell)
	MapArt.plate_col = Data.plate_col
	MapArt.shapes_one = { id = upload(one_image(rimm, insm, rim.w, rim.h, 40), rim.w, rim.h), cell = 112, cols = kinds }
	-- (the two-row variants the layers used while the one-image atlas had not loaded are the one image here: ours is
	-- ready at once, and a second copy would be EditableImage memory spent for nothing)
	MapArt.shapes = { id = MapArt.shapes_one.id, cell = 112, cols = kinds }
	-- (in rows: a strip past Pack.MAX_SIDE wide would fail to upload, and every unit would draw blank)
	local ucols = #Data.unit_names
	local per = Pack.grid(ucols, ub.h)
	local urgba, uw, uh = Pack.wrap(one_image(urm, ubm, ub.w, ub.h, 70), ucols, ub.h)
	MapArt.units_one = { id = upload(urgba, uw, uh), cell = ub.h, cols = ucols, per = per }
	MapArt.units = { id = MapArt.units_one.id, cell = ub.h, cols = ucols, per = per }
	local cm = Pack.mask(IconData.icons.crown, IconData.size, IconData.size)
	MapArt.status = { id = upload(white(cm, IconData.size, IconData.size), IconData.size, IconData.size), cell = IconData.size, cols = 1, pad = 0 }
	--- per structure kind (index kind + 1): the plate's size (x StructureLayer.ICON_SIZE) and the share of it
	--- the glyph spans. The plate is its kind's category frame (Art/Frames), drawn bigger where the shape holds less
	--- ground (a diamond), so every plate's middle fits the same glyph: ICON_FILL x ICON_SIZE px whatever the frame.
	MapArt.shape_scale = {}
	MapArt.icon_fill = {}
	for i, name in Data.kinds do
		MapArt.shape_scale[i] = Frames.scale[Frames.of[name]] or 1
		MapArt.icon_fill[i] = MapArt.ICON_FILL
	end
end

--- Puts `ref` (an ArtRef, or a legacy string) on `label` as its image; the layers set the rect themselves.
function MapArt.set(label: any, ref: any)
	ref = Registry.resolve(ref)
	if type(ref) == "table" and ref.art == true then
		if ref.content ~= nil then
			label.ImageContent = ref.content
		end
	else
		-- (a reused label that held an EditableImage can stay stuck on it: UI/ArtAtlas.apply)
		pcall(function()
			label.ImageContent = Content.none
		end)
		label.Image = if type(ref) == "string" then ref else ""
	end
end

build()
return setmetatable(MapArt, {})
