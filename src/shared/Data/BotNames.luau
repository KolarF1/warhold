--!strict
-- Names for bot players (the AI commanders that fill empty public-match slots). By design they look
-- like ordinary player names (2026-09-26, so that bots pass for real players): the mix real Roblox
-- handles have, built from word lists: "FrostyPanda", "sneakygoose2012", "tiny_walrus", "Jake2011",
-- "xXCrimsonYetiXx", "itsLily", "KaiPlays", "zoeyyy", "PickleKing77". Every name is a valid Roblox
-- username (3-20 letters, digits and at most one underscore, never first or last) and family-friendly;
-- no word is a real person or a brand. Deterministic for a given random source (the Sim's RNG), unique
-- within one call's `taken` set, ignoring case (as Roblox usernames are).

local BotNames = {}

--- Adjectives and prefixes that open a handle.
local ADJ = {
	"Frosty", "Crispy", "Toasty", "Wobbly", "Dashy", "Sparky", "Zippy", "Snowy", "Misty", "Soggy",
	"Super", "Funky", "Groovy", "Cheesy", "Bouncy", "Cranky", "Mellow", "Shiny", "Ultra", "Wacky",
	"Crimson", "Nifty", "Rowdy", "Sneaky", "Fluffy", "Tiny", "Big", "Cool", "Clumsy", "Dizzy",
	"Chunky", "Elite", "Frozen", "Bubbly", "Wavy", "Cyber", "Atomic", "Spiffy", "Steady", "Blitz",
	"Sleepy", "Happy", "Derpy", "Spicy", "Salty", "Sunny", "Stormy", "Fuzzy", "Hasty", "Quick",
	"Breezy", "Grumpy", "Jolly", "Volt", "Gloomy", "Lumpy", "Crunchy", "Silver", "Glitch", "Sonar",
	"Retro", "Snappy", "Thunder", "Ember", "Fancy", "Peppy", "Plucky", "Loopy", "Zesty", "Zoomy",
}

--- Nouns: animals, gamer roles, foods and things.
local NOUN = {
	"Gecko", "Wombat", "Walrus", "Narwhal", "Lobster", "Puffin", "Ferret", "Beaver", "Raccoon", "Squid",
	"Toad", "Chicken", "Burrito", "Pretzel", "Biscuit", "Cupcake", "Popcorn", "Nacho", "Bagel", "Toast",
	"Meatball", "Dumpling", "Pudding", "Ramen", "Brick", "Boulder", "Striker", "Brawler", "Champ", "Chef",
	"Goblin", "Zombie", "Dino", "Spud", "Trucker", "Monk", "Gladiator", "Cowboy", "Bandit", "Outlaw",
	"Sheriff", "Medic", "Sprout", "Tornado", "Meteor", "Nebula", "Pebble", "Astro", "Gamer", "Panda",
	"Kitty", "Bunny", "Duck", "Taco", "Pizza", "Cookie", "Muffin", "Noodle", "Pickle", "Potato",
	"Waffle", "Nugget", "Builder", "Tank", "Captain", "Warrior", "Penguin", "Llama", "Sloth", "Turtle",
	"Frog", "Rocket", "Yeti", "Pancake", "Donut", "Bean", "Goose", "Hamster", "Koala", "Mango",
	"Cactus", "Wizard", "King", "Queen", "Cat", "Lion",
}

--- First names (common ones, no one in particular).
local NAME = {
	"Jake", "Liam", "Noah", "Mason", "Ethan", "Logan", "Lucas", "Aiden", "Ryan", "Tyler",
	"Kai", "Brody", "Max", "Owen", "Caleb", "Eli", "Jaden", "Dylan", "Evan", "Cole",
	"Emma", "Ava", "Mia", "Lily", "Zoe", "Chloe", "Ella", "Stella", "Violet", "Ruby",
	"Ivy", "Nora", "Bella", "Sophie", "Grace", "Quinn", "Hailey", "Kayla", "Abby", "Sam",
	"Alex", "Jordan", "Riley", "Charlie", "Finn", "Jack", "Oscar", "Miles", "Jonah", "Zack",
	"Emily", "Hazel", "Layla", "Tessa", "Mila", "Leah", "Adam", "Ben", "Toby", "Gabe",
	"Isaac", "Hudson", "Wyatt", "Chase", "Blake", "Nina", "Eva", "Piper", "Willow", "Wes",
}

--- What players put after their name.
local TAG = { "Plays", "Gaming", "YT", "Pro", "GG", "XD", "HD", "OP", "TV", "Gamer", "Builds", "Fan" }

--- What players put before it ("itsLuna", "TheRealJake").
local LEAD = { "its", "Its", "Im", "The", "TheReal", "Mr", "Lil", "Not", "Just", "Only", "Sir", "x" }

--- Rude words a join of fragments must never spell (lower case), and the bot tell the tests look for.
BotNames.BANNED = {
	"ass", "fuck", "shit", "cunt", "dick", "cock", "piss", "slut", "whore", "fag", "nazi", "sex",
	"porn", "nigg", "rape", "kkk", "tit", "cum", "damn", "crap", "hell", "kill", "bot", "jew", "gay",
	"butt", "anal", "pee", "poo", "wtf", "stfu", "god", "drug", "weed", "nude",
	-- and a brand or a staff tell spelled across a join ("PurpLEGOose", "RoGUEStorm")
	"lego", "guest", "admin", "mod", "roblox", "mrbean", "mrpotato",
}

--- A username Roblox would accept: 3-20 of [A-Za-z0-9_], at most one "_", not at either end.
function BotNames.valid(name: string): boolean
	if #name < 3 or #name > 20 or string.find(name, "[^%w_]") ~= nil then
		return false
	end
	local _, n = string.gsub(name, "_", "")
	return n <= 1 and string.sub(name, 1, 1) ~= "_" and string.sub(name, -1) ~= "_"
end

--- No banned word inside it, whatever the case.
function BotNames.clean(name: string): boolean
	local low = string.lower(name)
	for _, w in BotNames.BANNED do
		if string.find(low, w, 1, true) ~= nil then
			return false
		end
	end
	return true
end

--- A name from `rand` (a function returning [0, 1)); `nil` when this draw made one too long or unclean
--- (the caller draws again).
local function draw(rand: () -> number): string?
	local function pick(list: { string }): string
		return list[math.floor(rand() * #list) + 1]
	end
	local function digits(): string
		local r = rand()
		if r < 0.3 then
			return tostring(math.floor(rand() * 9) + 1)
		elseif r < 0.55 then
			return tostring(math.floor(rand() * 90) + 10)
		elseif r < 0.75 then
			return tostring(2008 + math.floor(rand() * 9)) -- a year
		elseif r < 0.9 then
			return tostring(math.floor(rand() * 900) + 100)
		end
		local d = tostring(math.floor(rand() * 9) + 1)
		return string.rep(d, 2 + math.floor(rand() * 2)) -- "77", "999"
	end
	local style = rand()
	local name: string
	if style < 0.16 then
		-- FrostyPanda, NeonFalcon42
		name = pick(ADJ) .. pick(NOUN)
		if rand() < 0.5 then
			name ..= digits()
		end
	elseif style < 0.3 then
		-- darkwolf2012
		name = string.lower(pick(ADJ) .. pick(NOUN)) .. digits()
	elseif style < 0.4 then
		-- tiny_otter, sleepy_goose7
		name = string.lower(pick(ADJ)) .. "_" .. string.lower(pick(NOUN))
		if rand() < 0.35 then
			name ..= digits()
		end
	elseif style < 0.53 then
		-- Jake2011, maya_2010, Leo_Fox
		local r = rand()
		if r < 0.45 then
			name = pick(NAME) .. digits()
		elseif r < 0.75 then
			name = string.lower(pick(NAME)) .. "_" .. digits()
		else
			name = pick(NAME) .. "_" .. pick(NOUN)
		end
	elseif style < 0.6 then
		-- xXShadowFoxXx, xXLunaXx
		local core = if rand() < 0.5 then pick(ADJ) .. pick(NOUN) else pick(NAME)
		name = "xX" .. core .. "Xx"
	elseif style < 0.7 then
		-- itsLuna, TheRealJake, Lil_Kai, NotAPotato
		local lead = pick(LEAD)
		local who = if rand() < 0.6 then pick(NAME) else pick(NOUN)
		if lead == "Not" or lead == "Just" then
			who = "A" .. pick(NOUN)
		end
		name = if rand() < 0.25 and lead ~= "x" then lead .. "_" .. who else lead .. who
		if rand() < 0.25 then
			name ..= digits()
		end
	elseif style < 0.8 then
		-- KaiPlays, Ethan_Gaming, LunaYT
		local sep = if rand() < 0.3 then "_" else ""
		name = pick(NAME) .. sep .. pick(TAG)
	elseif style < 0.88 then
		-- zoeyyy, mayaa2010, LILY_x
		local n = string.lower(pick(NAME))
		name = n .. string.rep(string.sub(n, -1), 1 + math.floor(rand() * 2))
		local r = rand()
		if r < 0.35 then
			name ..= digits()
		elseif r < 0.5 then
			name ..= "_x"
		end
	else
		-- PickleKing77, PotatoLord, noodle_master
		local who = pick(NOUN)
		local rank = pick({ "King", "Queen", "Lord", "Boss", "Master", "Chief", "Hero", "Fan", "Lover", "Guy" })
		if who == rank then
			return nil
		end
		name = if rand() < 0.3 then string.lower(who) .. "_" .. string.lower(rank) else who .. rank
		if rand() < 0.5 then
			name ..= digits()
		end
	end
	if not BotNames.valid(name) or not BotNames.clean(name) then
		return nil
	end
	return name
end

--- A name from `rand` (a function returning [0, 1)).
function BotNames.one(rand: () -> number): string
	for _ = 1, 20 do
		local name = draw(rand)
		if name ~= nil then
			return name
		end
	end
	return NAME[math.floor(rand() * #NAME) + 1] .. tostring(math.floor(rand() * 9000) + 1000)
end

--- `n` distinct names not in `taken` (a set of names already used in the match; updated). Distinct ignoring case.
function BotNames.many(n: number, rand: () -> number, taken: { [string]: boolean }?): { string }
	local used = taken or {}
	local low: { [string]: boolean } = {}
	for k in used do
		low[string.lower(k)] = true
	end
	local out = {}
	local guard = 0
	while #out < n and guard < n * 50 do
		guard += 1
		local name = BotNames.one(rand)
		if not used[name] and not low[string.lower(name)] then
			used[name] = true
			low[string.lower(name)] = true
			table.insert(out, name)
		end
	end
	-- the word lists are large; this never runs short in practice
	local k = 1000
	while #out < n do
		local name = "Player" .. tostring(k)
		k += 1
		if not used[name] and not low[string.lower(name)] then
			used[name] = true
			low[string.lower(name)] = true
			table.insert(out, name)
		end
	end
	return out
end

return BotNames
