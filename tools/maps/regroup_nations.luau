--!nocheck
-- Turns tools/maps/realms_spec.luau into seats on the six real-world maps: writes each map's `nations` block (terrain is
-- never touched; a seat shows its row's `real` name and keeps the key's flag code), the counts in Data/MapList, and each
-- realm's colour in Data/Nations (by key, so renaming never moves a colour). Deterministic: the same spec gives
-- the same seats. A realm with members starts from the middle of their old seats (or `at`, when given); every seat then
-- moves to the nearest land that keeps SEAT_APART from every old seat and from the other realms, preferring solid ground
-- over a thin coast. A row with `fixed = true` keeps its `at` exactly.
-- Run from the repo: lune run tools/maps/regroup_nations.luau
require("../lune_prelude")
local fs = require("@lune/fs")
local process = require("@lune/process")
local Spec = require("./realms_spec")
local WorldMap = require("../../src/shared/Core/WorldMap")

--- The list this replaced, read from git so the tool can run again after it has written.
local OLD_COMMIT = "3ff8738"
local MAPS = {
	{ id = "world", path = "src/shared/Data/Maps/World.luau", apart = 44 },
	{ id = "africa", path = "src/server/MapData/Africa.luau", apart = 60 },
	{ id = "asia", path = "src/server/MapData/Asia.luau", apart = 60 },
	{ id = "europe", path = "src/server/MapData/Europe.luau", apart = 52 },
	{ id = "northamerica", path = "src/server/MapData/NorthAmerica.luau", apart = 60 },
	{ id = "southamerica", path = "src/server/MapData/SouthAmerica.luau", apart = 60 },
}
--- No seat within this of an old seat, in tiles: past Rules.NATION_SPAWN_DELTA's box around it.
local SEAT_APART = 32

local function git_show(path)
	local r = process.exec("git", { "show", OLD_COMMIT .. ":" .. path })
	assert(r.ok, r.stderr)
	return r.stdout
end

local function old_rows(text)
	local out = {}
	for name, flag, x, y in string.gmatch(text, '{ name = "([^"]+)", flag = "([^"]+)", x = (%d+), y = (%d+) }') do
		table.insert(out, { name = name, flag = flag, x = tonumber(x), y = tonumber(y) })
	end
	return out
end

local function solid(map, x, y)
	local n, hit = 0, 0
	for dy = -6, 6, 3 do
		for dx = -6, 6, 3 do
			local px, py = x + dx, y + dy
			if px >= 0 and py >= 0 and px < map.W and py < map.H then
				n += 1
				if map:is_contestable(py * map.W + px) then
					hit += 1
				end
			end
		end
	end
	return hit / math.max(n, 1)
end

local function far(x, y, list, d)
	for _, p in list do
		local dx, dy = p.x - x, p.y - y
		if dx * dx + dy * dy < d * d then
			return false
		end
	end
	return true
end

local function place(map, tx, ty, olds, placed, apart)
	for _, want in { { 0.75, apart }, { 0.45, apart }, { 0.2, apart * 0.8 }, { 0.0, apart * 0.65 } } do
		for r = 0, 420, 3 do
			local best, bs = nil, -1
			local steps = math.max(1, math.min(48, r * 2))
			for i = 0, steps - 1 do
				local a = 2 * math.pi * i / steps
				local x, y = math.floor(tx + math.cos(a) * r + 0.5), math.floor(ty + math.sin(a) * r + 0.5)
				if
					x >= 0
					and y >= 0
					and x < map.W
					and y < map.H
					and map:is_contestable(y * map.W + x)
					and far(x, y, olds, SEAT_APART)
					and far(x, y, placed, want[2])
				then
					local s = solid(map, x, y)
					if s >= want[1] and s > bs then
						best, bs = { x = x, y = y }, s
					end
				end
			end
			if best then
				return best, r
			end
		end
	end
	error("no room near " .. tx .. "," .. ty)
end

local function slug(name)
	local s = string.gsub(string.lower(name), "[^%a]+", "_")
	return "wh_" .. s
end

--- HSV to "#rrggbb".
local function hsv(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local rgb = ({ { v, t, p }, { q, v, p }, { p, v, t }, { p, q, v }, { t, p, v }, { v, p, q } })[i % 6 + 1]
	return string.format("#%02x%02x%02x", math.floor(rgb[1] * 255 + 0.5), math.floor(rgb[2] * 255 + 0.5), math.floor(rgb[3] * 255 + 0.5))
end

local realms = {}
local counts = {}
for _, m in MAPS do
	local spec = Spec[m.id]
	local old = old_rows(git_show(m.path))
	local by_name = {}
	for _, r in old do
		by_name[r.name] = r
	end
	local map = WorldMap.get(m.id)
	local placed = {}
	local rows = {}
	local used = {}
	local names = {}
	local shown = {}
	for _, row in spec do
		assert(not names[row[1]], m.id .. ": " .. row[1] .. " twice")
		names[row[1]] = true
		assert(type(row.real) == "string" and row.real ~= "", m.id .. ": " .. row[1] .. " has no real name")
		assert(not shown[row.real], m.id .. ": the name " .. row.real .. " twice")
		shown[row.real] = true
		local sx, sy, n = 0, 0, 0
		for i = 2, #row do
			local o = by_name[row[i]]
			assert(o, m.id .. ": no old seat " .. row[i])
			assert(not used[row[i]], m.id .. ": " .. row[i] .. " used twice")
			used[row[i]] = true
			sx += o.x
			sy += o.y
			n += 1
		end
		local tx, ty
		if row.at then
			tx, ty = row.at[1], row.at[2]
		else
			tx, ty = sx / n, sy / n
		end
		-- (`fixed`: the seat stays on `at`, which must be land: on a crowded island the spacing rule pushed it into the
		-- next country, 2026-11-09, tools/maps/seat_check.py)
		local s, moved
		if row.fixed then
			assert(map:is_contestable(ty * map.W + tx), m.id .. ": " .. row[1] .. "'s fixed seat is not land")
			s, moved = { x = tx, y = ty }, 0
		else
			s, moved = place(map, tx, ty, old, placed, m.apart)
		end
		table.insert(placed, s)
		table.insert(rows, string.format('\t\t{ name = "%s", flag = "%s", x = %d, y = %d },', row.real, slug(row[1]), s.x, s.y))
		realms[row[1]] = realms[row[1]] or {}
		if not table.find(realms[row[1]], row.real) then
			table.insert(realms[row[1]], row.real)
		end
		print(string.format("%-13s %-22s %-22s %4d,%4d  moved %d", m.id, row[1], row.real, s.x, s.y, moved))
	end
	for _, r in old do
		assert(used[r.name], m.id .. ": old seat left out of every realm: " .. r.name)
	end
	local text = fs.readFile(m.path)
	local a = string.find(text, "\tnations = {\n", 1, true)
	local b = string.find(text, "\n\t},\n", a, true)
	assert(a and b, m.id .. ": nations block")
	local out = string.sub(text, 1, a - 1) .. "\tnations = {\n" .. table.concat(rows, "\n") .. string.sub(text, b)
	out = string.gsub(
		out,
		"%-%- Names rewritten by hand for Warhold %(not RoWorld's%): the generators in tools/ would overwrite them, so do not rerun them over this file%.",
		"-- Realms by tools/maps/regroup_nations.luau (Warhold's own grouping, seats and flags): the older generators in tools/ would overwrite them, so do not rerun those over this file.",
		1
	)
	fs.writeFile(m.path, out)
	counts[m.id] = #rows
end

-- the counts in the registry
local list = fs.readFile("src/shared/Data/MapList.luau")
for id, n in counts do
	local changed
	list, changed = string.gsub(list, '(id = "' .. id .. '".-nations = )%d+', "%1" .. n, 1)
	assert(changed == 1, id)
end
fs.writeFile("src/shared/Data/MapList.luau", list)

-- the colours: hues walk the wheel by the golden angle, so names close in the list never sit close in colour
local all = {}
for name in realms do
	table.insert(all, name)
end
table.sort(all)
local lines = {
	"-- Warhold's realms: the authored colour of each flag key on the real-world maps (Data/Maps, server/MapData), read by",
	"-- Core/Sim._create_nations. `name`: the real place the key stands for on each map it is on (World first), for reading",
	"-- only. Written by tools/maps/regroup_nations.luau from tools/maps/realms_spec.luau.",
	"return {",
}
for i, key in all do
	local h = (i * 0.61803398875) % 1
	local s = ({ 0.5, 0.62, 0.74 })[i % 3 + 1]
	local v = ({ 0.86, 0.68, 0.78, 0.6 })[i % 4 + 1]
	table.insert(lines, string.format('\t{ name = "%s", code = "%s", color = "%s" },', table.concat(realms[key], " / "), slug(key), hsv(h, s, v)))
end
table.insert(lines, "}\n")
fs.writeFile("src/shared/Data/Nations.luau", table.concat(lines, "\n"))
for id, n in counts do
	print(id, n)
end
print("realms", #all)
