--!nonstrict
-- A sealed dispatch, drawn from plain frames: the folded paper, its two creases and the wax seal. UI/CrateOpening breaks the
-- seal (elsewhere it is a glyph: UITheme.icon "dispatch").
--
--   DispatchArt.build(parent, z) -> parts   the flap fills `parent`
--   DispatchArt.place(parts, w, h)          size it (px)
local UITheme = require("./UITheme")

local DispatchArt = {}

DispatchArt.PAPER = Color3.fromRGB(226, 216, 192)
DispatchArt.FLAP = Color3.fromRGB(206, 194, 166)
DispatchArt.CREASE = Color3.fromRGB(150, 138, 112)
DispatchArt.INK = Color3.fromRGB(38, 34, 28)
DispatchArt.WAX = Color3.fromRGB(128, 34, 38)
DispatchArt.WAX_RIM = Color3.fromRGB(92, 22, 26)
DispatchArt.WAX_MARK = Color3.fromRGB(226, 190, 170)

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local i = Instance.new(class)
	for k, v in props do
		UITheme.assign(i, k, v)
	end
	if parent then
		i.Parent = parent
	end
	return i
end

--- One half of the seal: a clipping box with the whole disc inside, so the two halves can part.
local function half(parent: Instance, name: string, z: number): any
	local box = new("Frame", { Name = name, BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = z }, parent)
	local disc = new("Frame", { Name = "Disc", BackgroundColor3 = DispatchArt.WAX, ZIndex = z }, box)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, disc)
	local rim = new("UIStroke", { Color = DispatchArt.WAX_RIM, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, disc)
	local mark = new("ImageLabel", {
		Name = "Mark",
		BackgroundTransparency = 1,
		Image = UITheme.icon("crown") or "",
		ImageColor3 = DispatchArt.WAX_MARK,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		ZIndex = z + 1,
	}, disc)
	return { box = box, disc = disc, rim = rim, mark = mark }
end

function DispatchArt.build(parent: Instance, z: number): any
	local flap = new("Frame", {
		Name = "Flap",
		BackgroundColor3 = DispatchArt.FLAP,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = z,
	}, parent)
	local stroke = new("UIStroke", { Color = DispatchArt.CREASE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, flap)
	local creases = {}
	for i = 1, 2 do
		creases[i] = new("Frame", {
			Name = "Crease" .. i,
			BackgroundColor3 = DispatchArt.CREASE,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = z + 1,
		}, flap)
	end
	-- (the seal sits over the flap's edge, outside its clip)
	local left = half(parent, "SealLeft", z + 2)
	local right = half(parent, "SealRight", z + 2)
	return { flap = flap, stroke = stroke, creases = creases, left = left, right = right }
end

--- The folded paper at `w` x `h` px: two creases meet under the seal at its centre.
function DispatchArt.place(p: any, w: number, h: number)
	local d = math.floor(math.min(w, h) * 0.42)
	local run = math.sqrt((w * 0.5) ^ 2 + (h * 0.5) ^ 2)
	local angle = math.deg(math.atan2(h * 0.5, w * 0.5))
	for i, c in p.creases do
		c.Size = UDim2.fromOffset(run, 1)
		c.Position = UDim2.fromOffset(if i == 1 then w * 0.25 else w * 0.75, h * 0.25)
		c.Rotation = if i == 1 then angle else -angle
	end
	for i, s in { p.left, p.right } do
		local x = if i == 1 then w * 0.5 - d * 0.5 else w * 0.5
		s.box.Size = UDim2.fromOffset(math.ceil(d * 0.5), d)
		s.box.Position = UDim2.fromOffset(x, h * 0.5 - d * 0.5)
		s.box.BackgroundTransparency = 1
		s.disc.Size = UDim2.fromOffset(d, d)
		s.disc.Position = UDim2.fromOffset(if i == 1 then 0 else -d * 0.5, 0)
	end
end

return DispatchArt
