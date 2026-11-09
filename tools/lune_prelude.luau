-- Lune prelude for the generators (and the tests, by way of tests/prelude): exposes the Roblox datatypes shared code
-- may use as globals.
local roblox = require("@lune/roblox")
for _, name in ipairs({
	"Vector2",
	"Vector3",
	"Color3",
	"CFrame",
	"Vector2int16",
	"Vector3int16",
	"Rect",
	"UDim",
	"UDim2",
	"NumberRange",
}) do
	(getfenv() :: any)[name] = (roblox :: any)[name]
end
return roblox
