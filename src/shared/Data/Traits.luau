--!strict
-- Historical strengths (the owner, 2026-11-08: certain countries get strengths from their history, the Mongols' horse
-- lords for one, toward the grand strategy feel). A realm with a trait multiplies the Sim's levers by it for the whole
-- match (Core/SimDoctrines._refresh_mults), as a doctrine does: an edge, never a win, so each is small. A period's realms
-- name theirs (Data/Periods); on today's maps a few countries have one by name (BY_NAME). Tribes and players have none.
local Traits = {}

export type Trait = {
	key: string,
	name: string,
	line: string,
	gold: number?,
	cap: number?,
	conq: number?,
	trade: number?,
	atk: number?,
	def: number?,
	regen: number?,
	claim: number?,
	rebate: number?,
}

Traits.LIST = {
	steppe = { key = "steppe", name = "Horse Lords", line = "+15% attack, open land a third cheaper", atk = 1.15, claim = 1.33 },
	raiders = { key = "raiders", name = "Sea Raiders", line = "+10% attack, +30% plunder", atk = 1.10, conq = 1.30 },
	traders = { key = "traders", name = "Merchant Fleets", line = "+30% trade gold, +10% gold", trade = 1.30, gold = 1.10 },
	walls = { key = "walls", name = "Great Walls", line = "+15% defence", def = 1.15 },
	legions = { key = "legions", name = "Standing Armies", line = "+12% troop cap", cap = 1.12 },
	faith = { key = "faith", name = "Holy War", line = "+10% attack, +10% troop regrowth", atk = 1.10, regen = 1.10 },
	bureau = { key = "bureau", name = "Bureaucracy", line = "+15% gold", gold = 1.15 },
	builders = { key = "builders", name = "Master Builders", line = "10% back on every building", rebate = 1.10 },
	mountain = { key = "mountain", name = "Mountain Holds", line = "+12% defence, +8% troop regrowth", def = 1.12, regen = 1.08 },
	masses = { key = "masses", name = "Endless Levies", line = "+20% troop regrowth", regen = 1.20 },
} :: { [string]: Trait }

--- Today's countries whose history gives them a strength plainly, by the place's name on the real-world maps.
Traits.BY_NAME = {
	["Mongolia"] = "steppe",
	["Kazakhstan"] = "steppe",
	["Kyrgyzstan"] = "steppe",
	["Turkmenistan"] = "steppe",
	["England"] = "traders",
	["Netherlands"] = "traders",
	["Portugal"] = "traders",
	["Greece"] = "traders",
	["Oman"] = "traders",
	["Mali"] = "traders",
	["Norway"] = "raiders",
	["Denmark"] = "raiders",
	["Sweden"] = "legions",
	["France"] = "legions",
	["Germany"] = "builders",
	["Italy"] = "builders",
	["Egypt"] = "builders",
	["Switzerland"] = "mountain",
	["Afghanistan"] = "mountain",
	["Nepal"] = "mountain",
	["Tibet"] = "mountain",
	["Georgia"] = "mountain",
	["Armenia"] = "mountain",
	["Ethiopia"] = "mountain",
	["Russia"] = "masses",
	["China"] = "masses",
	["India"] = "masses",
	["Japan"] = "walls",
	["Türkiye"] = "walls",
	["United States"] = "bureau",
	["Iran"] = "bureau",
	["Spain"] = "faith",
	["Saudi Arabia"] = "faith",
} :: { [string]: string }

--- The trait of a nation row (its own `trait`, else its place's on today's maps), or nil. Pure.
function Traits.of_row(row: any): string?
	if type(row) ~= "table" then
		return nil
	end
	local k = if type(row.trait) == "string" then row.trait else Traits.BY_NAME[tostring(row.name or "")]
	return if k ~= nil and Traits.LIST[k] ~= nil then k else nil
end

--- A trait's multiplier on `lever` (1 when it has none). Pure.
function Traits.mult(key: string?, lever: string): number
	local t = if key ~= nil then (Traits.LIST :: any)[key] else nil
	return if t ~= nil and type(t[lever]) == "number" then t[lever] else 1.0
end

return Traits
