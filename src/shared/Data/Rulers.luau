--!strict
-- Rulers (docs/DEPTH_DESIGN.md Phase 3): every realm of a depth match has one, with a name from its region's pool (by
-- the country its capital stands in), an age and two or three traits. A ruler ages a year every `year_s` seconds of
-- the match (Data/Depth), may die each year after DEATH_FROM, and an heir follows: new traits, a short unrest spike.
-- Trait levers are the doctrines' (Data/Doctrines: gold, atk, def... multiplied; unrest, opinion, prov, general,
-- prestige... summed), plus `death` (yearly risk added).
local Rulers = {}

export type Trait = { key: string, name: string, line: string, [string]: any }

Rulers.TRAITS = {
	{ key = "brave", name = "Brave", line = "Leads from the front.", atk = 0.10, general = 1, death = 0.01, foe = "craven" },
	{ key = "craven", name = "Craven", line = "Never where the fighting is.", atk = -0.08, def = 0.05, foe = "brave" },
	{ key = "greedy", name = "Greedy", line = "Every gold piece counted twice.", gold = 0.10, unrest = 5, foe = "generous" },
	{ key = "generous", name = "Generous", line = "Open hands, loyal subjects.", gold = -0.05, unrest = -6, opinion = 5, foe = "greedy" },
	{ key = "just", name = "Just", line = "Fair to great and small.", unrest = -8 },
	{ key = "administrator", name = "Administrator", line = "Holds a wide realm together.", prov = 6, gold = 0.05 },
	{ key = "strategist", name = "Strategist", line = "Wins wars before they start.", general = 2 },
	{ key = "zealous", name = "Zealous", line = "Faith before peace.", atk = 0.05, opinion = -5, prestige = 0.10, foe = "cynical" },
	{ key = "cynical", name = "Cynical", line = "Believes in gold and steel.", gold = 0.05, prestige = -0.05, foe = "zealous" },
	{ key = "ambitious", name = "Ambitious", line = "Wants it all.", prestige = 0.20, unrest = 3, foe = "content" },
	{ key = "content", name = "Content", line = "Happy with what is.", unrest = -5, prestige = -0.10, foe = "ambitious" },
	{ key = "paranoid", name = "Paranoid", line = "Trusts nobody.", def = 0.08, opinion = -10 },
	{ key = "wise", name = "Wise", line = "Listens, then decides.", regen = 0.08, unrest = -3 },
	{ key = "sickly", name = "Sickly", line = "Not long for this world.", death = 0.05, regen = -0.05 },
	{ key = "charismatic", name = "Charismatic", line = "Loved at home and abroad.", opinion = 15, unrest = -3 },
	{ key = "cruel", name = "Cruel", line = "Rules by fear.", unrest = -4, opinion = -10, atk = 0.04 },
	{ key = "builder", name = "Builder", line = "Leaves stone behind.", rebate = 0.10, fort = 0.20 },
	{ key = "merchant", name = "Merchant Prince", line = "Trade is power.", trade = 0.15, gold = 0.05 },
	{ key = "drunkard", name = "Drunkard", line = "The court runs itself.", gold = -0.05, unrest = 2 },
	{ key = "genius", name = "Genius", line = "Good at everything.", gold = 0.05, atk = 0.05, def = 0.05, general = 1 },
} :: { Trait }

Rulers.BY_KEY = {} :: { [string]: Trait }
Rulers.INDEX = {} :: { [string]: number }
for i, t in Rulers.TRAITS do
	Rulers.BY_KEY[t.key] = t
	Rulers.INDEX[t.key] = i
end

--- Yearly death risk from DEATH_FROM: base + per year past it; never past DEATH_AT.
Rulers.DEATH_FROM = 45
Rulers.DEATH_BASE = 0.015
Rulers.DEATH_PER_YEAR = 0.004
Rulers.DEATH_AT = 92
--- A first ruler's age, an heir's, and how many traits (two, sometimes three).
Rulers.FIRST_AGE = { 20, 48 }
Rulers.HEIR_AGE = { 15, 36 }
Rulers.THIRD_TRAIT = 0.35
--- An heir keeps one of the old ruler's traits this often.
Rulers.INHERIT = 0.4
--- Unrest a succession brings at once.
Rulers.SUCCESSION_UNREST = 8

--- Name pools by region (medieval), and one for today's rulers.
Rulers.NAMES = {
	latin = { "Charles", "Louis", "Henry", "Philip", "Robert", "Alfonso", "Ferdinand", "Otto", "Frederick", "William", "Richard", "John", "Edward", "Matilda", "Eleanor", "Isabella", "Blanche", "Constance", "Baldwin", "Raymond", "Sancho", "Urraca", "Conrad", "Godfrey" },
	norse = { "Harald", "Olaf", "Magnus", "Sven", "Cnut", "Eric", "Sigurd", "Ingrid", "Astrid", "Haakon", "Ragnhild", "Valdemar", "Inge", "Birger" },
	slavic = { "Vladimir", "Yaroslav", "Boleslaw", "Casimir", "Wenceslaus", "Bela", "Stephen", "Sviatoslav", "Olga", "Ladislaus", "Mstislav", "Premysl", "Vratislav", "Andrew" },
	greek = { "Basil", "Constantine", "Alexios", "John", "Manuel", "Michael", "Theodora", "Irene", "Isaac", "Andronikos", "Romanos", "Zoe", "Nikephoros", "Anna" },
	arab = { "Harun", "Salah ad-Din", "Yusuf", "Ali", "Hasan", "al-Mustansir", "al-Nasir", "Nur ad-Din", "Baybars", "Shajar al-Durr", "Zubaida", "Abd al-Mumin", "Yaqub", "al-Kamil" },
	turkic = { "Alp Arslan", "Tughril", "Malik Shah", "Kilij Arslan", "Kayqubad", "Sanjar", "Mahmud", "Masud", "Kaykhusraw", "Terken", "Arslan", "Togrul" },
	persian = { "Mardavij", "Adud al-Dawla", "Ismail", "Nasr", "Khusraw", "Shirin", "Mahmud", "Bahram", "Kavad", "Ardashir" },
	steppe = { "Temujin", "Ogedei", "Batu", "Mongke", "Kublai", "Toregene", "Chagatai", "Berke", "Hulagu", "Sorghaghtani", "Tolui", "Guyuk" },
	chinese = { "Taizu", "Huizong", "Gaozong", "Xiaozong", "Lizong", "Renzong", "Shenzong", "Zhezong", "Ningzong", "Yingzong", "Zhenzong", "Taizong" },
	japanese = { "Go-Toba", "Shirakawa", "Toba", "Go-Shirakawa", "Yoritomo", "Kiyomori", "Masako", "Takakura", "Yoshitsune", "Go-Saga", "Tokimune", "Sanetomo" },
	korean = { "Wang Geon", "Gwangjong", "Seongjong", "Hyeonjong", "Munjong", "Injong", "Uijong", "Gojong", "Myeongjong", "Sinjong" },
	indian = { "Rajendra", "Rajaraja", "Kulottunga", "Prithviraj", "Bhoja", "Ballala", "Vikramaditya", "Devapala", "Mahipala", "Someshvara", "Rudrama", "Ganapati" },
	seasia = { "Suryavarman", "Jayavarman", "Anawrahta", "Kyansittha", "Airlangga", "Ly Thai To", "Tran Thai Tong", "Dharmavamsa", "Ranggawuni", "Sri Indraditya" },
	african = { "Sundiata", "Dunama", "Lalibela", "Yekuno Amlak", "Sumanguru", "Mansa Wali", "Tenkamenin", "Abdallah", "Dawud", "Gudit", "Idris", "Sakura" },
	american = { "Topiltzin", "Itzcoatl", "Manco", "Sinchi Roca", "Pachacuti", "Huemac", "Mixcoatl", "Ce Acatl", "Lloque", "Mayta" },
	pacific = { "Tui Manu'a", "Kamehameha", "Tangaloa", "Hotu Matua", "Tu'i Tonga", "Mataafa" },
	modern = { "Alex", "Jordan", "Morgan", "Elena", "Marcus", "Sofia", "Daniel", "Amara", "Viktor", "Lena", "Rafael", "Mei", "Omar", "Aiko", "Kwame", "Ingrid", "Diego", "Priya", "Tomas", "Nadia", "Samuel", "Yuki", "Leon", "Zara" },
}

--- A capital's country (Natural Earth ISO a3, Data/Provinces) to its medieval name pool; the rest by continent.
Rulers.CULTURE = {
	GBR = "latin", IRL = "latin", FRA = "latin", ESP = "latin", PRT = "latin", ITA = "latin", DEU = "latin", AUT = "latin",
	CHE = "latin", BEL = "latin", NLD = "latin", LUX = "latin", MLT = "latin", SVN = "latin", HRV = "latin",
	NOR = "norse", SWE = "norse", DNK = "norse", ISL = "norse", FIN = "norse", GRL = "norse", EST = "norse",
	POL = "slavic", CZE = "slavic", SVK = "slavic", HUN = "slavic", RUS = "slavic", UKR = "slavic", BLR = "slavic", LTU = "slavic",
	LVA = "slavic", SRB = "slavic", BIH = "slavic", MNE = "slavic", BGR = "slavic", ROU = "slavic", MDA = "slavic", MKD = "slavic",
	GRC = "greek", CYP = "greek", ALB = "greek",
	TUR = "turkic", AZE = "turkic", TKM = "turkic", UZB = "turkic", KAZ = "steppe", KGZ = "turkic", TJK = "persian",
	IRN = "persian", AFG = "persian", IRQ = "arab", SYR = "arab", LBN = "arab", ISR = "arab", PSE = "arab", JOR = "arab",
	SAU = "arab", YEM = "arab", OMN = "arab", ARE = "arab", QAT = "arab", KWT = "arab", BHR = "arab", EGY = "arab", LBY = "arab",
	TUN = "arab", DZA = "arab", MAR = "arab", ESH = "arab", MRT = "arab", SDN = "arab", GEO = "greek", ARM = "greek",
	MNG = "steppe", CHN = "chinese", TWN = "chinese", JPN = "japanese", KOR = "korean", PRK = "korean",
	IND = "indian", PAK = "indian", BGD = "indian", NPL = "indian", LKA = "indian", BTN = "indian",
	MMR = "seasia", THA = "seasia", LAO = "seasia", KHM = "seasia", VNM = "seasia", MYS = "seasia", IDN = "seasia", PHL = "seasia", BRN = "seasia",
	AUS = "pacific", NZL = "pacific", PNG = "pacific", FJI = "pacific",
	USA = "american", CAN = "american", MEX = "american", GTM = "american", PER = "american", BOL = "american",
}

--- The rest of Africa and the Americas.
Rulers.AFRICA = {}
for _, k in { "NGA", "GHA", "MLI", "NER", "TCD", "ETH", "SOM", "KEN", "TZA", "UGA", "RWA", "BDI", "COD", "COG", "GAB", "CMR",
	"CAF", "SSD", "ERI", "DJI", "SEN", "GMB", "GIN", "GNB", "SLE", "LBR", "CIV", "BFA", "TGO", "BEN", "AGO", "ZMB", "ZWE",
	"MWI", "MOZ", "MDG", "NAM", "BWA", "ZAF", "LSO", "SWZ", "GNQ", "CPV", "STP", "COM", "MUS", "SYC" } do
	Rulers.AFRICA[k] = true
end
Rulers.AMERICAS = {}
for _, k in { "BRA", "ARG", "CHL", "COL", "VEN", "ECU", "PRY", "URY", "GUY", "SUR", "BLZ", "HND", "SLV", "NIC", "CRI", "PAN",
	"CUB", "HTI", "DOM", "JAM", "PRI", "BHS", "TTO" } do
	Rulers.AMERICAS[k] = true
end

--- The pool of a capital in country `iso` (an ISO a3; "" on an invented map), in a medieval match or today's.
function Rulers.pool(iso: string?, medieval: boolean): { string }
	if not medieval then
		return Rulers.NAMES.modern
	end
	local c = if iso ~= nil then Rulers.CULTURE[iso] else nil
	if c == nil and iso ~= nil and iso ~= "" then
		c = if Rulers.AFRICA[iso] then "african" elseif Rulers.AMERICAS[iso] then "american" else nil
	end
	if c == nil then
		-- (an invented map, or a country no pool names: the Latin pool)
		c = "latin"
	end
	return Rulers.NAMES[c] or Rulers.NAMES.latin
end

--- The roman numeral of `n` (1-39), "" for 1.
function Rulers.numeral(n: number): string
	if n <= 1 then
		return ""
	end
	local out = ""
	local vals = { { 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" } }
	local k = n
	for _, v in vals do
		while k >= v[1] do
			out ..= v[2]
			k -= v[1]
		end
	end
	return out
end

--- A ruler's name as shown: "Henry II".
function Rulers.title(name: string, num: number): string
	local r = Rulers.numeral(num)
	return if r == "" then name else name .. " " .. r
end

--- The sum of trait lever `lever` over trait keys `keys`.
function Rulers.sum(keys: { string }, lever: string): number
	local m = 0.0
	for _, k in keys do
		local t = Rulers.BY_KEY[k]
		if t ~= nil then
			m += t[lever] or 0
		end
	end
	return m
end

return Rulers
