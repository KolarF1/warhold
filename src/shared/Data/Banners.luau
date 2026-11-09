--!strict
-- The banner colours a player can fly: your land takes the colour, and the interface takes it as its accent
-- (UITheme.BANNERS holds the same colours; tests/banners.luau keeps the two equal). Saved as the setting
-- ui.banner, an index into this list. Indices are saved: APPEND ONLY.

local Banners = {}

Banners.HEX = {
	"#1cd6b0",
	"#ff5c5c",
	"#ffb02e",
	"#70baff",
	"#be84ff",
	"#ff7ac4",
	"#96de52",
	"#ebeef2",
}

--- The colour of a saved index, or nil when it isn't one.
function Banners.hex(index: any): string?
	return Banners.HEX[tonumber(index) or 0]
end

--- What a player flies: their choice, or the default (the interface's default accent, so the two match).
function Banners.flown(index: any): string
	return Banners.hex(index) or Banners.HEX[1]
end

return Banners
