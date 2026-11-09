--!nonstrict
-- Our own art on the device: the packed glyph masks (shared/Art/IconData, drawn by tools/art and checked in
-- contact sheets) decoded and uploaded once into one EditableImage atlas. No asset id is involved, so
-- nothing depends on an upload or on an account's permissions. An ArtRef is { art = true, content, offset,
-- size }; `apply` puts a ref (or a legacy string id) on an ImageLabel. Without EditableImage (Lune, a
-- refused allocation) `icon` returns nil and every caller already degrades to "no icon".
local IS_ROBLOX = typeof(game) == "Instance"
local Pack = if IS_ROBLOX
	then require((game:GetService("ReplicatedStorage"):WaitForChild("Airfront") :: any):WaitForChild("Art"):WaitForChild("Pack"))
	else (require :: any)("../../shared/Art/Pack")
local IconData = if IS_ROBLOX
	then require((game:GetService("ReplicatedStorage"):WaitForChild("Airfront") :: any):WaitForChild("Art"):WaitForChild("IconData"))
	else (require :: any)("../../shared/Art/IconData")

local Registry = if IS_ROBLOX
	then require((game:GetService("ReplicatedStorage"):WaitForChild("Airfront") :: any):WaitForChild("Art"):WaitForChild("Registry"))
	else (require :: any)("../../shared/Art/Registry")
-- (loading FlagArt registers the flag resolver)
local FlagArt = if IS_ROBLOX then require((script :: any).Parent:WaitForChild("FlagArt")) else (require :: any)("./FlagArt")
local ThumbArt = if IS_ROBLOX then require((script :: any).Parent:WaitForChild("ThumbArt")) else (require :: any)("./ThumbArt")

local ArtAtlas = {}

ArtAtlas.COLS = 8
--- The atlas cell in pixels: the glyphs ship at IconData.size (twice this) and are shrunk into it; a glyph drawn
--- large asks for `ArtAtlas.large`, its own image at the full size.
ArtAtlas.CELL = 64
ArtAtlas.LARGE_PX = 56

local _built = false
local _refs: { [string]: any } = {}
local _failed = false

--- Names of every glyph in the atlas, sorted (the layout order).
function ArtAtlas.names(): { string }
	local out = {}
	for k in IconData.icons do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

--- The atlas pixel size and the cell of glyph number `i` (1-based).
function ArtAtlas.layout(count: number): (number, number)
	local rows = math.ceil(count / ArtAtlas.COLS)
	return ArtAtlas.COLS * ArtAtlas.CELL, rows * ArtAtlas.CELL
end

--- The atlas as RGBA bytes (white, coverage in alpha) and each glyph's cell offset: the part that needs
--- no Roblox (the tests run it).
function ArtAtlas.pixels()
	local names = ArtAtlas.names()
	local size, cell = IconData.size, ArtAtlas.CELL
	local f = size // cell
	local w, h = ArtAtlas.layout(#names)
	local rgba = buffer.create(w * h * 4)
	local cells = {}
	for i, name in names do
		local cx, cy = ((i - 1) % ArtAtlas.COLS) * cell, ((i - 1) // ArtAtlas.COLS) * cell
		Pack.blit_white_scaled(rgba, w, Pack.mask(IconData.icons[name], size, size), size, size, cx, cy, f)
		cells[name] = { cx, cy }
	end
	return rgba, w, h, cells
end

local function build()
	if _built then
		return
	end
	_built = true
	if not IS_ROBLOX then
		return
	end
	local ok = pcall(function()
		local rgba, w, h, cells = ArtAtlas.pixels()
		local img = game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(w, h) })
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), rgba)
		local content = Content.fromObject(img)
		local s = ArtAtlas.CELL
		for name, c in cells do
			_refs[name] = { art = true, content = content, offset = Vector2.new(c[1], c[2]), size = Vector2.new(s, s) }
		end
	end)
	if not ok then
		_failed = true
		table.clear(_refs)
	end
end

--- The ref of glyph `name` (an alias resolves), or nil.
function ArtAtlas.icon(name: string): any?
	build()
	return _refs[IconData.aliases[name] or name]
end

local _large: { [string]: any } = {}
--- The ref of glyph `name` at its full shipped size (IconData.size), its own image: for a glyph drawn bigger than
--- LARGE_PX, where the atlas cell would be stretched soft. Falls back to the atlas ref.
function ArtAtlas.large(name: string): any?
	local key = IconData.aliases[name] or name
	if _large[key] ~= nil then
		return _large[key]
	end
	local text = IconData.icons[key]
	if text == nil or not IS_ROBLOX then
		return ArtAtlas.icon(name)
	end
	local ok, ref = pcall(function()
		local s = IconData.size
		local rgba = buffer.create(s * s * 4)
		Pack.blit_white(rgba, s, Pack.mask(text, s, s), s, s, 0, 0)
		local img = game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(s, s) })
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(s, s), rgba)
		return { art = true, content = Content.fromObject(img), offset = Vector2.zero, size = Vector2.new(s, s) }
	end)
	if not ok then
		return ArtAtlas.icon(name)
	end
	_large[key] = ref
	return ref
end

--- True when `name` is one of ours (an atlas or not: a name check for tests).
function ArtAtlas.has(name: string): boolean
	return IconData.icons[IconData.aliases[name] or name] ~= nil
end

--- Puts `ref` on `label`: an ArtRef as content + rect, a string as its id, nil as no image.
function ArtAtlas.apply(label: any, ref: any)
	ref = Registry.resolve(ref)
	if type(ref) == "table" and ref.art == true then
		if ref.content ~= nil then
			label.ImageContent = ref.content
		end
		label.ImageRectOffset = ref.offset or Vector2.zero
		label.ImageRectSize = ref.size or Vector2.zero
	else
		-- (an ImageLabel that held an EditableImage can stay stuck on it when a string id is set next: clear the
		-- content first, DevForum "ImageContent bugs after switching from URI to Object to URI")
		if IS_ROBLOX then
			pcall(function()
				label.ImageContent = Content.none
			end)
		end
		label.Image = if type(ref) == "string" then ref else ""
		if IS_ROBLOX then
			label.ImageRectOffset = Vector2.zero
			label.ImageRectSize = Vector2.zero
		end
	end
end

return ArtAtlas
