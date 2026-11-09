--!strict
-- What a bot player looks like (2026-11-02, the owner: "give bots roblox character pictures like players have
-- instead of flags"). Each bot gets a made-up Roblox avatar put together from Roblox's own free catalog items, so
-- its picture beside its name reads like a person's head shot and belongs to nobody. Never a real user's
-- thumbnail.
--
-- Pure and deterministic: a bot's look NUMBER comes from the match seed and its owner id (BotLooks.number), travels
-- in the cosmetics map as `badge` (GameState keeps it as a negative `face`), and BotLooks.look(n) turns it into
-- the items. The server builds one avatar per look (server/BotAvatars); the client shows it (UI/BotPortrait).
--
-- Every id below was checked on 2026-11-02 against economy.roblox.com/v2/assets/<id>/details: the asset type
-- named, creator Roblox (user 1), price 0. Shirts, pants, the type-41 hair, hats and glasses are on sale for free
-- now (or come in a free Roblox bundle: John, bundle 126; Lin, bundle 130). The classic faces are Roblox's old
-- free faces (price 0, off sale today; Smile is the default face everyone has); a HumanoidDescription shows them
-- without anyone owning them. Ids that could not be checked, or were not what they seemed, were left out.

local BotLooks = {}

--- Skin tones (RGB 0..255): Roblox's usual body colours, light to dark, and the classic yellow.
BotLooks.SKINS = {
	{ 255, 204, 153 }, -- Pastel brown
	{ 234, 184, 146 }, -- Light orange
	{ 204, 142, 105 }, -- Nougat
	{ 175, 148, 131 }, -- Beige
	{ 160, 95, 53 }, -- Dark orange
	{ 124, 92, 70 }, -- Brown
	{ 86, 66, 54 }, -- Dark taupe
	{ 245, 205, 48 }, -- Bright yellow (the classic look)
}

--- Classic faces (asset type 18, Face).
BotLooks.FACES = {
	144075659, -- Smile (the default face)
	7074764, -- Chill
	7699174, -- Silly Fun
	8560971, -- Stare
	12145366, -- Freckles
	209995366, -- Joyful Smile
	25166274, -- Squiggle Mouth
	209994875, -- Smiling Girl
	4637244809, -- Classic Male v2 - Face
}

--- Hair (asset type 41, HairAccessory).
BotLooks.HAIR = {
	63690008, -- Pal Hair
	451221329, -- True Blue Hair
	451220849, -- Lavender Updo
	376548738, -- Brown Charmer Hair
	62234425, -- Brown Hair
	376526888, -- Straight Blonde Hair
	376524487, -- Blonde Spiked Hair
	7193455510, -- Braided Hair - Red
	9244148336, -- Braided Hair - Blonde
	9244150641, -- Braided Hair - Cool Brown
	7193454569, -- Braided Hair - Black
	2956239660, -- Belle Of Belfast Long Red Hair
	1103003368, -- Orange Beanie with Black Hair
	301819845, -- John's Hair (bundle John)
	301818464, -- Lin's Hair (bundle Lin)
}

--- Hats (asset type 8, Hat): some bots wear one over their hair.
BotLooks.HATS = {
	607702162, -- Roblox Baseball Cap
	417457461, -- ROBLOX 'R' Baseball Cap
	48474313, -- Red Roblox Cap
	2646473721, -- Roblox Visor
}

--- Glasses (asset type 42, FaceAccessory).
BotLooks.GLASSES = {
	376527500, -- Orange Shades
	376526673, -- Stylish Aviators
	301820310, -- Lin's Glasses (bundle Lin)
}

--- Classic shirts (asset type 11, Shirt).
BotLooks.SHIRTS = {
	607785314, -- ROBLOX Jacket
	3670737444, -- Roblox Shirt - Simple Pattern
	398633584, -- Denim Jacket with White Hoodie
	144076358, -- Blue and Black Motorcycle Shirt
	382538059, -- Green Jersey
	398635081, -- Blue Plaid Shirt
	398634295, -- Pastel Starburst Top with Gray Jacket
	4047886060, -- Purple and Teal Top
	4047884939, -- My Favorite Pizza Shirt
	4047884046, -- Guitar Tee with Black Jacket
	144076436, -- Grey Striped Shirt with Denim Jacket
	382537702, -- Teal Shirt
	382537085, -- I <3 Pizza Shirt
}

--- Classic pants (asset type 12, Pants).
BotLooks.PANTS = {
	398633812, -- Black Jeans with White Shoes
	398635338, -- Ripped Skater Pants
	398634487, -- Beautiful You Jeans
	144076760, -- Dark Green Jeans
	382538503, -- Black Jeans with Sneakers
	382537569, -- Black Jeans
	382537950, -- Jean Shorts with White Shoes
	382537806, -- Jean Shorts
}

--- Shares of bots wearing a hat / glasses (people mostly don't).
BotLooks.HAT_SHARE = 0.25
BotLooks.GLASSES_SHARE = 0.15

--- Look numbers are 1..MAX (they travel as a negative `face`, so they must stay positive whole numbers).
BotLooks.MAX = 0x3FFFFFFF

-- (a 32-bit integer mix: the low avalanche of murmur3's finaliser)
local function mix(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = bit32.band(h * 0x85EB, 0xFFFFFFFF)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = bit32.band(h * 0xC2B2, 0xFFFFFFFF)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

--- The look number of bot `id` in the match with `seed` (`salt` gives the next try when two bots look alike).
function BotLooks.number(seed: number, id: number, salt: number?): number
	local h = mix(bit32.band(math.floor(seed) % 4294967296, 0xFFFFFFFF))
	h = mix(bit32.bxor(h, bit32.band(math.floor(id) * 0x9E37 + 0x79B9, 0xFFFFFFFF)))
	h = mix(bit32.bxor(h, math.floor(salt or 0) % 65536))
	return bit32.band(h, BotLooks.MAX) % BotLooks.MAX + 1
end

-- A small generator from a look number: the n-th pick of a look.
local function picker(n: number): (count: number) -> number
	local state = math.floor(n) % 4294967296
	return function(count: number): number
		state = mix(bit32.band(state + 0x6D2B, 0xFFFFFFFF))
		return state % count + 1
	end
end

export type Look = {
	n: number,
	key: string,
	skin: { number },
	face: number,
	hair: number,
	hat: number?,
	glasses: number?,
	shirt: number,
	pants: number,
}

--- The look of look number `n` (nil for anything that is not one).
function BotLooks.look(n: any): Look?
	if type(n) ~= "number" or n < 1 or n > BotLooks.MAX or n ~= math.floor(n) then
		return nil
	end
	local pick = picker(n)
	local skin = BotLooks.SKINS[pick(#BotLooks.SKINS)]
	local face = BotLooks.FACES[pick(#BotLooks.FACES)]
	local hair = BotLooks.HAIR[pick(#BotLooks.HAIR)]
	local shirt = BotLooks.SHIRTS[pick(#BotLooks.SHIRTS)]
	local pants = BotLooks.PANTS[pick(#BotLooks.PANTS)]
	local hat = if pick(1000) <= BotLooks.HAT_SHARE * 1000 then BotLooks.HATS[pick(#BotLooks.HATS)] else nil
	local glasses = if pick(1000) <= BotLooks.GLASSES_SHARE * 1000 then BotLooks.GLASSES[pick(#BotLooks.GLASSES)] else nil
	-- (what the look is made of: two bots with the same key share one built avatar)
	local key = string.format(
		"%d,%d,%d|%d|%d|%d|%d|%d|%d",
		skin[1],
		skin[2],
		skin[3],
		face,
		hair,
		hat or 0,
		glasses or 0,
		shirt,
		pants
	)
	return {
		n = n,
		key = key,
		skin = skin,
		face = face,
		hair = hair,
		hat = hat,
		glasses = glasses,
		shirt = shirt,
		pants = pants,
	}
end

--- Look numbers for bots `ids` in the match with `seed`: different looks while there are bots (a clash takes the
--- next salt, a few times). { [id] = n }
function BotLooks.assign(seed: number, ids: { number }): { [number]: number }
	local out = {}
	local used = {}
	for _, id in ids do
		local n = BotLooks.number(seed, id, 0)
		for salt = 1, 8 do
			local l = BotLooks.look(n)
			if l == nil or not used[l.key] then
				break
			end
			n = BotLooks.number(seed, id, salt)
		end
		local l = BotLooks.look(n)
		if l ~= nil then
			used[l.key] = true
		end
		out[id] = n
	end
	return out
end

--- Every catalog id a look can use, by kind (for tests and the server's checks).
function BotLooks.ids(): { [string]: { number } }
	return {
		face = BotLooks.FACES,
		hair = BotLooks.HAIR,
		hat = BotLooks.HATS,
		glasses = BotLooks.GLASSES,
		shirt = BotLooks.SHIRTS,
		pants = BotLooks.PANTS,
	}
end

return BotLooks
