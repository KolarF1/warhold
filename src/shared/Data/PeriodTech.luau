--!strict
-- Each start date's own tech and words (the owner, 2026-11-08: time periods should feel like the real time, real tech too:
-- no bombs before modern times). A medieval war is land, sea, walls and siege: the strikes are siege and fire (Greek fire
-- and the plague catapult from the Siege Works, the Trebuchet's stones), the great bombard only in 1241, when gunpowder
-- reached the steppe and the West; nothing flies. Today's world (no period) is the game as it was.
--
--   KITS[period].closed: kind names (structures, nukes, the Arsenal, Data/Eras.BUILD_OPENS keys) that period never has;
--   KITS[period].titles: a kind's name in that period, over UIRules.TITLES / Defs.STRUCT_TITLES / Defs.NUKE_TITLES;
--   KITS[period].events: a world event's { name, line } by its Data/WorldEvents key;
--   KITS[period].blurbs / words: a kind's description, and words of today's (warheads) in that period's (PeriodTech.word).
-- PeriodTech.apply(period) puts a period's words into the shared tables (and back for today); PeriodTech.closed(period,
-- kind) is the one rule the Sim, the AI and the interface ask.
local PeriodTech = {}

local MEDIEVAL_CLOSED = {
	hydrogen = true, -- (gunpowder: 1241 opens it again)
	airfield = true,
	railgun = true,
	mega = true,
	scatter = true,
	airstrike = true,
	slug = true,
}

local MEDIEVAL_TITLES = {
	city = "Town",
	port = "Port",
	factory = "Smithy",
	defense = "Castle",
	sam = "Watchtower",
	silo = "Siege Works",
	warship = "War Galley",
	atom = "Greek Fire",
	mirv = "Plague Catapult",
	warhead = "Plague Carcass",
	artillery = "Trebuchet",
	shell = "Trebuchet Stone",
	reinforce = "Harvest Levy",
	callarms = "Feudal Levy",
	barracks = "Muster Hall",
	fort = "Keep",
}

--- What a kind does, in the Middle Ages' words (over UIRules.BLURBS; the same {placeholders})
local MEDIEVAL_BLURBS = {
	port = "Built on the coast. Its merchants bring gold, and it launches your war galleys.",
	factory = "Where roads meet. Carts earn gold at each stop on their way.",
	sam = "Archers on the walls bring down Greek fire and stones within {sam_r} tiles. Plague carcasses get through.",
	silo = "You need one before any siege engine can loose a shot.",
	warship = "Your ship of war. It goes where you point, hunts what comes by sea and takes trade for you. Your Ports mend it.",
	atom = "A pot of Greek fire. Burns troops and buildings, and scorches the ground.",
	hydrogen = "A great stone from the bombard. Nothing inside its blast survives.",
	mirv = "Flung over one nation: up to {mirv_n} plague carcasses, spread across its land.",
	artillery = "Quiet until war comes. Hurls stones at any nation at war with you within {art_r} tiles, and breaks up forces marching on you.",
}

--- The words a medieval war uses for today's (PeriodTech.word): its strikes are siege and fire, not warheads
--- (a kind's own names, today's and the period's, are swapped too, from the tracked tables: these are the rest)
local MEDIEVAL_WORDS = {
	warheads = "siege shots",
	warhead = "siege shot",
	["cluster shards"] = "plague carcasses",
	["cluster shard"] = "plague carcass",
	shards = "carcasses",
	["flak sites"] = "Watchtowers",
	["flak site"] = "Watchtower",
	flak = "Watchtowers",
	["long guns"] = "Trebuchets",
	["trade ships"] = "merchant ships",
	trucks = "carts",
}

--- The short names (UIRules.SHORT) a medieval war's buildings and strikes go by
local MEDIEVAL_SHORT = {
	city = "Town",
	port = "Port",
	factory = "Smithy",
	defense = "Castle",
	sam = "Tower",
	silo = "Works",
	warship = "Galley",
	atom = "Fire",
	mirv = "Plague",
	artillery = "Trebuchet",
	hydrogen = "Bombard",
}

local MEDIEVAL_EVENTS = {
	goldrush = { "Silver Strike", "+50% gold everywhere for 90 seconds" },
	tradewinds = { "Fair Season", "Double trade gold for 2 minutes" },
	warfever = { "Holy Zeal", "+25% attack for everyone for a minute" },
	landboom = { "Forest Clearing", "Open land costs half for a minute" },
	buildboom = { "Cathedral Fever", "25% back on every building for 90 seconds" },
	plague = { "Pestilence", "-40% troop regrowth everywhere for a minute" },
	crash = { "Debased Silver", "-30% gold everywhere for a minute" },
	uprising = { "Peasant Revolt", "-50% troop regrowth for a minute" },
}

--- The glyphs a medieval war shows in place of today's (game-icons.net drawings, tools/art/gi_icons.json "m_" keys).
local MEDIEVAL_ICONS = {
	farm = "m_farm",
	market = "m_market",
	barracks = "m_barracks",
	fort = "m_fort",
	city = "m_city",
	factory = "m_factory",
	defense = "m_defense",
	sam = "m_sam",
	silo = "m_silo",
	warship = "m_galley",
	atom = "m_atom",
	mirv = "m_mirv",
	artillery = "m_artillery",
	hydrogen = "m_hydrogen",
}

local function kit(over: { [string]: any }): { [string]: any }
	local icons = table.clone(MEDIEVAL_ICONS)
	for k, v in over.icons or {} do
		icons[k] = v
	end
	local titles = table.clone(MEDIEVAL_TITLES)
	for k, v in over.titles or {} do
		titles[k] = v
	end
	local closed = table.clone(MEDIEVAL_CLOSED)
	for k, v in over.open or {} do
		closed[k] = if v then nil else closed[k]
	end
	local events = table.clone(MEDIEVAL_EVENTS)
	for k, v in over.events or {} do
		events[k] = v
	end
	return { closed = closed, titles = titles, events = events, icons = icons, blurbs = table.clone(MEDIEVAL_BLURBS), words = table.clone(MEDIEVAL_WORDS), short = table.clone(MEDIEVAL_SHORT) }
end

PeriodTech.KITS = {
	["867"] = kit({ titles = { warship = "Longship", port = "Longphort" }, icons = { warship = "m_longship" } }),
	["1066"] = kit({ titles = { warship = "Longship" }, icons = { warship = "m_longship" } }),
	["1187"] = kit({ titles = { warship = "War Galley" } }),
	-- (gunpowder from the steppe: the bombard opens; the plague is the coming Black Death's herald)
	["1241"] = kit({
		titles = { warship = "Cog", hydrogen = "Great Bombard" },
		open = { hydrogen = true },
		events = { plague = { "Black Death", "-40% troop regrowth everywhere for a minute" } },
	}),
} :: { [string]: { [string]: any } }

--- True when start date `period` never has `kind` (a structure's, nuke's or Arsenal kind's name). Today's world has all.
function PeriodTech.closed(period: string?, kind: string?): boolean
	if period == nil or kind == nil then
		return false
	end
	local k = PeriodTech.KITS[period]
	return k ~= nil and k.closed[kind] == true
end

--- Kind `kind`'s name in `period`, or nil (the table's own then).
function PeriodTech.title(period: string?, kind: string): string?
	local k = if period ~= nil then PeriodTech.KITS[period] else nil
	return if k ~= nil then k.titles[kind] else nil
end

-- the tables apply() writes into, and what they held for today's world
local _targets = {} :: { { tbl: { [any]: any }, key: (string) -> any?, keep: { [any]: any }, field: string } }
local _applied: string? = nil

--- Registers a table of names to follow the period: `tbl[key_of(kind)]` is a name by kind (key_of nil: the kind is the key);
--- `field`: which of the kit's tables it takes ("titles", the default; "blurbs", descriptions; "short", short names).
function PeriodTech.track(tbl: { [any]: any }, key_of: ((string) -> any)?, field: string?)
	for _, t in _targets do
		if t.tbl == tbl then
			return
		end
	end
	local keep = table.clone(tbl)
	table.insert(_targets, { tbl = tbl, key = key_of or function(k: string): any
		return k
	end, keep = keep, field = field or "titles" })
	if _applied ~= nil then
		local was = _applied
		_applied = nil
		PeriodTech.apply(was)
	end
end

local build_pairs: (k: { [string]: any }?) -> ()
local _hooks = {} :: { (string?) -> () }

--- Puts start date `period`'s names into every tracked table (nil: today's names back), and its world events' words.
function PeriodTech.apply(period: string?)
	if period == _applied then
		return
	end
	_applied = period
	local k = if period ~= nil then PeriodTech.KITS[period] else nil
	for _, t in _targets do
		for key, v in t.keep do
			t.tbl[key] = v
		end
		if k ~= nil then
			for kind, name in k[t.field] or {} do
				local key = t.key(kind)
				if key ~= nil and t.keep[key] ~= nil then
					t.tbl[key] = name
				end
			end
		end
	end
	local WorldEvents: any = if typeof(game) == "Instance" then require((script :: any).Parent.WorldEvents) else (require :: any)("./WorldEvents")
	PeriodTech._events_keep = PeriodTech._events_keep or {}
	for _, e in WorldEvents.LIST do
		local keep = PeriodTech._events_keep[e.key]
		if keep == nil then
			keep = { e.name, e.line }
			PeriodTech._events_keep[e.key] = keep
		end
		local over = if k ~= nil then k.events[e.key] else nil
		e.name = if over ~= nil then over[1] else keep[1]
		e.line = if over ~= nil then over[2] else keep[2]
	end
	build_pairs(k)
	for _, fn in _hooks do
		local ok, err = pcall(fn, period)
		if not ok then
			warn("[PeriodTech] on_apply: " .. tostring(err))
		end
	end
end

--- The glyph a kind's icon is drawn with under the period whose names are in the tables now, or nil (its own).
function PeriodTech.icon(name: string): string?
	local k = if _applied ~= nil then PeriodTech.KITS[_applied] else nil
	return if k ~= nil then k.icons[name] else nil
end

-- (today's word -> the period's, longest first; built on apply)
local _pairs = {} :: { { string } }

local function cap(w: string): string
	return string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2)
end

local function plural(w: string): string
	if string.match(w, "[^aeiou]y$") then
		return string.sub(w, 1, -2) .. "ies"
	end
	return if string.match(w, "s$") then w else w .. "s"
end

function build_pairs(k: { [string]: any }?)
	local out = {} :: { { string } }
	if k ~= nil then
		local seen = {} :: { [string]: boolean }
		local function add(from: string, to: string)
			local key = string.lower(from)
			if from == to or seen[key] then
				return
			end
			seen[key] = true
			table.insert(out, { key, to })
		end
		for from, to in k.words do
			add(from, to)
		end
		for _, t in _targets do
			if t.field ~= "blurbs" then
				for key, was in t.keep do
					local now = t.tbl[key]
					if type(was) == "string" and type(now) == "string" and now ~= was then
						add(plural(was), plural(now))
						add(was, now)
					end
				end
			end
		end
		table.sort(out, function(a, b)
			return #a[1] > #b[1]
		end)
	end
	_pairs = out
end

--- `text` in the words of the period whose names are in the tables now: today's kinds' names and words (Warheads,
--- Flak, Launch Site...) become the period's (Siege shots, Watchtowers, Siege Works...), case kept (warheads ->
--- siege shots, Warheads -> Siege shots, WARHEADS -> SIEGE SHOTS). Today's world: `text` as it is.
function PeriodTech.say(text: string): string
	if #_pairs == 0 then
		return text
	end
	local out = text
	for _, p in _pairs do
		local from, to = p[1], p[2]
		local title = string.gsub(from, "(%a)(%w*)", function(a: string, b: string): string
			return string.upper(a) .. b
		end)
		-- (each case the text may hold it in: UPPER, Every Word Capitalised, Capitalised, lower)
		for _, v in { { string.upper(from), string.upper(to) }, { title, cap(to) }, { cap(from), cap(to) }, { from, to } } do
			local pat = "%f[%w]" .. string.gsub(v[1], "%W", "%%%0") .. "%f[%W]"
			out = string.gsub(out, pat, (string.gsub(v[2], "%%", "%%%%")))
		end
	end
	return out
end

--- One word or name in the period's words (PeriodTech.say).
function PeriodTech.word(w: string): string
	return PeriodTech.say(w)
end

--- Calls `fn(period)` after every apply (labels built once, that name a kind or a word, set their text again).
function PeriodTech.on_apply(fn: (string?) -> ())
	table.insert(_hooks, fn)
end

--- The period whose names are in the tables now (nil: today's).
function PeriodTech.applied(): string?
	return _applied
end

return PeriodTech
