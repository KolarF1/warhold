--!nonstrict
-- The other side's picture in the command dial (Your front's rows, a tapped nation's strip, the spine's badge): a
-- person's Roblox head shot, a bot player's made-up avatar (UI/BotPortrait), the flag a ruler flies, or else a tile in
-- the nation's colour with its initials ("FR"). Faces are round with a ring in the owner's colour; tiles are square.
--
-- Portrait.new(px) -> a Control px x px. :set_owner(ctx, id, prefer_flag?) draws owner `id`; :clear().
-- Portrait.initials(name) -> the tile's letters. Pure.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local UICtx = require("./UICtx")
local BotPortrait = require("./BotPortrait")

local Portrait = W.class(W.Control)

--- Up to two letters for a name: the first of its first two words, or its first two (a handle is one word). Pure.
function Portrait.initials(name: string?): string
	local words = {}
	for wd in string.gmatch(name or "", "%S+") do
		table.insert(words, wd)
	end
	if #words == 0 then
		return "?"
	end
	if #words >= 2 then
		return string.upper(string.sub(words[1], 1, 1) .. string.sub(words[2], 1, 1))
	end
	return string.upper(string.sub(words[1], 1, 2))
end

--- Relative luminance (WCAG 2), for the letters' contrast. Pure.
local function lum(c: Color3): number
	local function lin(v: number): number
		return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * lin(c.R) + 0.7152 * lin(c.G) + 0.0722 * lin(c.B)
end

--- Ink that reads on a tile of colour `c`: the dial's ink or white, whichever stands out more. Pure.
function Portrait.ink_for(c: Color3): Color3
	local l = lum(c)
	local ink = lum(UITheme.DIAL_INK)
	local dark = (l + 0.05) / (ink + 0.05)
	local light = 1.05 / (l + 0.05)
	return if dark >= light then UITheme.DIAL_INK else UITheme.WHITE
end

--- A tile's back and its letters for a nation of colour `c`: its colour with the ink that stands out more, or, for a
--- middle tone where neither reaches 4.5:1, the colour darkened until white letters do. Pure.
function Portrait.tile_colors(c: Color3): (Color3, Color3)
	local function contrast(a: Color3, b: Color3): number
		local x, y = lum(a), lum(b)
		return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05)
	end
	local ink = Portrait.ink_for(c)
	if contrast(ink, c) >= 4.5 then
		return c, ink
	end
	local bg = c
	for _ = 1, 12 do
		bg = Color3.new(bg.R * 0.88, bg.G * 0.88, bg.B * 0.88)
		if contrast(UITheme.WHITE, bg) >= 4.5 then
			break
		end
	end
	return bg, UITheme.WHITE
end

function Portrait.new(px: number)
	local self = setmetatable({}, Portrait.__mt)
	W.Control._init(self)
	local T = UITheme
	self.px = px
	self.owner_id = 0
	self.mode = "" -- "face", "flag" or "tile"
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_min_size(Vector2.new(px, px))
	self.size_flags_vertical = W.SHRINK_CENTER
	-- the tile: the nation's colour and its letters
	local tile = W.Panel.new()
	tile:set_mouse_filter(W.MOUSE_IGNORE)
	tile:set_anchors(0, 0, 1, 1)
	tile:set_offsets(0, 0, 0, 0)
	tile:add_theme_stylebox_override("panel", T.flat(T.DIAL_SLATE_2, 0))
	self._tile = tile
	self:add_child(tile)
	local letters = T.label("", math.max(12, math.floor(px * 0.36)), T.DIAL_WEIGHT, T.WHITE)
	letters:set_anchors(0, 0, 1, 1)
	letters:set_offsets(0, 0, 0, 0)
	letters.horizontal_alignment = W.ALIGN_CENTER
	letters.vertical_alignment = W.ALIGN_CENTER
	self._letters = letters
	tile:add_child(letters)
	-- a face: round, ringed in the owner's colour
	local img = Instance.new("ImageLabel")
	img.Name = "Face"
	img.BackgroundColor3 = T.color3(T.DIAL_SLATE_2)
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Crop
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = img
	local ring = Instance.new("UIStroke")
	ring.Thickness = 2
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = img
	-- (it fades with whatever holds it, as the picture does)
	self:_part(ring, "Transparency", 1.0)
	self._ring = ring
	self._face_img = img
	self._face = W.wrap(img)
	self._face:set_mouse_filter(W.MOUSE_IGNORE)
	self._face:set_anchors(0, 0, 1, 1)
	self._face:set_offsets(0, 0, 0, 0)
	self._face:set_visible(false)
	self:add_child(self._face)
	-- a flag
	local fimg = Instance.new("ImageLabel")
	fimg.Name = "Flag"
	fimg.BackgroundTransparency = 1
	fimg.BorderSizePixel = 0
	fimg.ScaleType = Enum.ScaleType.Fit
	self._flag_img = fimg
	self._flag = W.wrap(fimg)
	self._flag:set_mouse_filter(W.MOUSE_IGNORE)
	self._flag:set_anchors(0, 0.15, 1, 0.85)
	self._flag:set_offsets(0, 0, 0, 0)
	self._flag:set_visible(false)
	self:add_child(self._flag)
	return self
end

function Portrait._show(self, mode: string)
	self.mode = mode
	self._tile:set_visible(mode == "tile" or mode == "flag")
	self._letters:set_visible(mode == "tile")
	self._face:set_visible(mode == "face")
	self._flag:set_visible(mode == "flag")
end

function Portrait.clear(self)
	self.owner_id = 0
	self._face_id = nil
	self._flag_id = nil
	self:_show("tile")
	self._letters:set_text("")
	self._tile:add_theme_stylebox_override("panel", UITheme.flat(UITheme.DIAL_SLATE_2, 0))
end

--- Draws owner `id` of the bound match. `prefer_flag`: a flag before a face (the spine's own badge).
function Portrait.set_owner(self, ctx: any, id: number, prefer_flag: boolean?)
	local T = UITheme
	local s = ctx.state
	local o = if s ~= nil and id ~= 0 then s:get_owner(id) else nil
	if o == nil then
		self:clear()
		return
	end
	self.owner_id = id
	local col = T.owner_ui_color(o.color)
	local cz = s.cosmetics and s.cosmetics[id]
	local face = if cz ~= nil and cz.face ~= nil then cz.face else 0
	local fid = if cz ~= nil and cz.flag ~= nil then cz.flag else ""
	local Cosmetics = UICtx.data("Cosmetics")
	local flag = if fid ~= "" then Cosmetics.item(fid) else nil
	if flag ~= nil and flag.kind ~= "flag" then
		flag = nil
	end
	if face ~= 0 and not (prefer_flag and flag ~= nil) then
		self._ring.Color = col
		if face ~= self._face_id then
			self._face_id = face
			-- (a bot player: its made-up avatar, UI/BotPortrait; a person: their head shot)
			if not BotPortrait.apply(self._face_img, face, col) then
				T.set_image(self._face_img, Cosmetics.face_image(face))
			end
		end
		self:_show("face")
		return
	end
	self._tile:add_theme_stylebox_override("panel", T.flat(col, 0))
	if flag ~= nil then
		if fid ~= self._flag_id then
			self._flag_id = fid
			T.set_image(self._flag_img, Cosmetics.flag_image(flag))
			if flag.x ~= nil then
				self._flag_img.ImageRectOffset = Vector2.new(flag.x, flag.y)
				self._flag_img.ImageRectSize = Vector2.new(flag.w, flag.h)
			end
		end
		self:_show("flag")
		return
	end
	self._letters:set_text(Portrait.initials(o.name))
	local bg, ink = Portrait.tile_colors(col)
	self._tile:add_theme_stylebox_override("panel", T.flat(bg, 0))
	T.set_font_color(self._letters, ink)
	self:_show("tile")
end

return Portrait
