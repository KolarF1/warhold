-- Touch: a short bar filling under a finger held on the map, in your banner's colour, until the order card opens. It
-- shows that the hold is counting (keep still) and when it will open. Driven each frame by UIRoot from
-- MapInput.hold_state(); drawn on a raw logical-px canvas (UICtx.canvas), input-transparent. (The module keeps its old
-- name, which UIRoot uses.)
local UICtx = require("./UICtx") :: any

local HoldRing = {}
HoldRing.__index = HoldRing

--- The bar appears once a hold is this far along (a tap never flashes it).
HoldRing.SHOW_FROM = 0.3
HoldRing.W = 56.0
HoldRing.H = 5.0
--- Under the finger, so the finger doesn't hide it.
HoldRing.BELOW = 38.0

function HoldRing.new(c: any)
	local self = setmetatable({}, HoldRing)
	self.ctx = c
	local canvas = UICtx.canvas(nil, "HoldBar")
	canvas.Visible = false
	self.gui = canvas
	local track = UICtx.make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = UICtx.mod("UITheme").BLACK,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(HoldRing.W, HoldRing.H),
		ZIndex = 1,
	}, canvas)
	self._track = track
	self._fill = UICtx.make("Frame", {
		Name = "Fill",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 2,
	}, track)
	return self
end

--- pos: the finger (logical px) or nil; k: the hold's progress 0..1.
function HoldRing.set(self: any, pos: Vector2?, k: number)
	if pos == nil or k < HoldRing.SHOW_FROM or k >= 1 then
		if self.gui.Visible then
			self.gui.Visible = false
		end
		return
	end
	if not self.gui.Visible then
		self.ctx:fit_canvas(self.gui)
		self.gui.Visible = true
		local o = self.ctx:my()
		self._fill.BackgroundColor3 = if o ~= nil then UICtx.mod("UITheme").owner_ui_color(o.color) else UICtx.mod("UITheme").WHITE
	end
	self._track.Position = UDim2.fromOffset(pos.X, pos.Y + HoldRing.BELOW)
	self._fill.Size = UDim2.fromScale((k - HoldRing.SHOW_FROM) / (1 - HoldRing.SHOW_FROM), 1)
end

return HoldRing
