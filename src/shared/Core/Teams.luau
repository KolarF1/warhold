--!strict
-- Team games: the teams of a match, who plays on which, and their colours.
-- Experimental, staging only (2026-10-10: team maps, and a party system so a player can join with
-- a friend).
--
-- The rules:
--   * the team list: a number of teams, or Duos / Trios / Quads (teams of 2 / 3 / 4: as many
--     teams as the players need, at least 2), or Humans Vs Nations. Those four strings are keys that
--     cross servers in lobby configs, never shown: Teams.label says them in Warhold's words (Pairs,
--     Threes, Fours, Rulers against Nations). Up to 7 teams are named Crimson, Azure, Gold, Ivy,
--     Violet, Ember, Tide (shown as they are; only the Sim's snapshot carries them, not a save);
--     more are "Side 1".."Side N";
--   * assignment: a team holds ceil(players / teams) at most. A group (a
--     party that joined together) goes whole onto the team with the fewest players. Everyone else in
--     join order goes where most of their group already is, else to the emptiest team (Duos / Trios /
--     Quads: the fullest one with room, so teams fill up one by one). The fillers come last, shuffled:
--     the bot players that fill a public match's empty slots;
--   * tribes are on no team (friendly to nobody);
--   * colours: a named team has a base colour and 64 shades of it around it (see shade);
--     a numbered team has one colour that its players share;
--   * nobody is left out: a group larger than a team spills over like anyone else, and a player
--     for whom every team is full joins the emptiest.

local Defs = require("./Defs")
local SimColors = require("./SimColors")

local Teams = {}

Teams.DUOS = "Duos"
Teams.TRIOS = "Trios"
Teams.QUADS = "Quads"
Teams.HVN = "Humans Vs Nations"
Teams.HUMANS = "Rulers"
Teams.NATIONS = "Nations"
--- The named teams, in the order they are used.
Teams.NAMED = { "Crimson", "Azure", "Gold", "Ivy", "Violet", "Ember", "Tide" }
--- A side past the named ones (eight sides and more): "Side 8".
Teams.NUMBERED = "Side %d"
--- The base colour of each team.
Teams.BASE = {
	Crimson = "#c62f3b",
	Azure = "#2f6bd8",
	Gold = "#d8a412",
	Ivy = "#3c9a52",
	Violet = "#8638d4",
	Ember = "#e2721a",
	Tide = "#0f9fb8",
	Rulers = "#2f6bd8",
	Nations = "#c62f3b",
}
--- A lobby's team format as a player reads it (the keys above stay what travels).
Teams.WORDS = {
	[Teams.DUOS] = "Pairs",
	[Teams.TRIOS] = "Threes",
	[Teams.QUADS] = "Fours",
	[Teams.HVN] = "Rulers against Nations",
}
--- The same, where a phone has no room for the long one.
Teams.WORDS_SHORT = { [Teams.HVN] = "Against Nations" }
Teams.SHADES = 64

--- Players per team for Duos / Trios / Quads (nil: a number of teams, or Humans Vs Nations).
function Teams.group_size(config: any): number?
	if config == Teams.DUOS then
		return 2
	elseif config == Teams.TRIOS then
		return 3
	elseif config == Teams.QUADS then
		return 4
	end
	return nil
end

--- True when teams fill one by one (Duos / Trios / Quads) rather than evenly.
function Teams.packs(config: any): boolean
	return Teams.group_size(config) ~= nil
end

--- The team names for `config` (a number of teams, Duos / Trios / Quads, Humans Vs Nations) and
--- `players` players (humans and nations, counted at the start).
function Teams.resolve(config: any, players: number): { string }
	if config == Teams.HVN then
		return { Teams.HUMANS, Teams.NATIONS }
	end
	local n
	local size = Teams.group_size(config)
	if size ~= nil then
		n = math.max(2, math.ceil(players / size))
	else
		n = math.max(2, math.floor(tonumber(config) or 2))
	end
	local names = {}
	for i = 1, n do
		names[i] = if n < 8 then Teams.NAMED[i] else Teams.NUMBERED:format(i)
	end
	return names
end

--- A side's name standing alone: "Crimson side", "Side 8", "Rulers", "Nations". ("" stays "".)
function Teams.words(name: string): string
	if name == "" or string.sub(name, 1, 5) == "Side " or name == Teams.HUMANS or name == Teams.NATIONS then
		return name
	end
	return name .. " side"
end

--- The same at the head of a sentence: "The Crimson side", "Side 8", "The Rulers".
function Teams.the(name: string): string
	local w = Teams.words(name)
	return if w == "" or string.sub(w, 1, 5) == "Side " then w else "The " .. w
end

--- Whether a sentence about this side takes a plural verb ("The Rulers take...", "The Crimson side takes...").
function Teams.plural(name: string): boolean
	return name == Teams.HUMANS or name == Teams.NATIONS
end

--- How a team game is described to a player ("2 Sides", "Pairs", "Rulers against Nations"). `short`: the phone's.
function Teams.label(config: any, short: boolean?): string
	if type(config) == "number" then
		return ("%d Sides"):format(config)
	end
	if short and Teams.WORDS_SHORT[config] ~= nil then
		return Teams.WORDS_SHORT[config]
	end
	return Teams.WORDS[config] or tostring(config)
end

export type Player = {
	id: number,
	--- players who joined together (a party): kept on one team while it has room
	group: string?,
	--- fills the empty places after everyone else (a bot player)
	filler: boolean?,
}

--- Who plays on which team: id → team (1..#names). `players` in join order; the fillers among them are
--- placed last in `shuffle(fillers)`'s order (a seeded shuffle; nil: as given).
function Teams.assign(
	players: { Player },
	n_teams: number,
	packing: boolean,
	shuffle: ((list: { Player }) -> ())?
): { [number]: number }
	local out: { [number]: number } = {}
	local sizes = table.create(n_teams, 0)
	local max_size = math.ceil(#players / math.max(n_teams, 1))
	local function put(p: Player, t: number)
		out[p.id] = t
		sizes[t] += 1
	end
	-- the groups, largest first (stable), each onto the team with the fewest players
	local groups: { [string]: { Player } } = {}
	local order: { string } = {}
	for _, p in players do
		if p.group ~= nil and not p.filler then
			local g = groups[p.group]
			if g == nil then
				g = {}
				groups[p.group] = g
				table.insert(order, p.group)
			end
			table.insert(g, p)
		end
	end
	local rank = {}
	for i, key in order do
		rank[key] = i
	end
	table.sort(order, function(a: string, b: string): boolean
		if #groups[a] ~= #groups[b] then
			return #groups[a] > #groups[b]
		end
		return rank[a] < rank[b]
	end)
	local rest: { Player } = {}
	for _, key in order do
		local best = 1
		for t = 2, n_teams do
			if sizes[t] < sizes[best] then
				best = t
			end
		end
		for _, p in groups[key] do
			if sizes[best] < max_size then
				put(p, best)
			else
				table.insert(rest, p)
			end
		end
	end
	--- Placing a player: the team holding most of the player's group, then the emptiest
	--- (packing: the fullest) team with room, the first on ties.
	local function place(p: Player)
		local best, best_friends, best_size = 0, -1, if packing then -1 else math.huge
		for t = 1, n_teams do
			if sizes[t] >= max_size then
				continue
			end
			local friends = 0
			if p.group ~= nil then
				for _, q in players do
					if q.group == p.group and out[q.id] == t then
						friends += 1
					end
				end
			end
			local better = friends > best_friends
				or (friends == best_friends and (if packing then sizes[t] > best_size else sizes[t] < best_size))
			if better then
				best, best_friends, best_size = t, friends, sizes[t]
			end
		end
		if best == 0 then
			-- (every team full: the emptiest)
			best = 1
			for t = 2, n_teams do
				if sizes[t] < sizes[best] then
					best = t
				end
			end
		end
		put(p, best)
	end
	for _, p in rest do
		place(p)
	end
	local fillers: { Player } = {}
	for _, p in players do
		if out[p.id] == nil then
			if p.filler then
				table.insert(fillers, p)
			else
				place(p)
			end
		end
	end
	if shuffle ~= nil then
		shuffle(fillers)
	end
	for _, p in fillers do
		place(p)
	end
	return out
end

--- Shade i of a team's base colour, in OKLCH (lightness and chroma steps sized to OKLab's
--- ranges): i = 0 is the base colour.
local function shade(rgba: number, i: number): number
	if i <= 0 then
		return rgba
	end
	local lab = SimColors.oklab(rgba)
	local l, a, b = lab.x, lab.y, lab.z
	local c = math.sqrt(a * a + b * b)
	local h = math.deg(math.atan2(b, a))
	h = (h + ((i * 137.508) % 12) - 6 + 360) % 360
	c = math.clamp(c * (1 + 0.1 * math.sin(i * 0.7)), 0.03, 0.34)
	l = math.clamp(l + 0.18 * math.sin(math.rad(i * 137.508)), 0.32, 0.86)
	local hr = math.rad(h)
	return SimColors.to_rgba({ x = l, y = c * math.cos(hr), z = c * math.sin(hr) })
end

--- The colour of the `index`-th player (0-based) of team `name` (the `team`-th of the match).
function Teams.color(name: string, team: number, index: number): number
	local hex = Teams.BASE[name]
	if hex ~= nil then
		return shade(Defs.html_rgba(hex), index % Teams.SHADES)
	end
	-- a numbered team: one colour for all its players, the human palette's, spread out
	local pal = SimColors.human_palette()
	return pal[((team - 1) * 7) % #pal + 1]
end

return Teams
