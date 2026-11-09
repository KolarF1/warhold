--!nonstrict
-- Depth Phase 6 (docs/DEPTH_DESIGN.md): ambitions and prestige. Each realm of a depth match gets three ambitions from
-- its situation when it first rules: unite its country (hold every province of the country its capital stands in),
-- an empire (hold `empire_n` provinces), a great city (hold the nearest of the period's great cities on the map), a
-- treasury (gold in hand). Each fulfilled pays prestige; prestige also comes from battles, sieges, peace on terms and
-- provinces taken in war, and a revolt or a war without reason costs some. When a timed war ends without a conqueror
-- the most prestige wins (Sim._check_victory: Defs.OVER_PRESTIGE).
--
-- `o_amb[id] = { { kind, arg, done }, ... }`: kind "unite" (arg: ISO), "empire" (arg: provinces), "city" (arg: the
-- province), "treasury" (arg: gold).
local Defs = require("./Defs")
local Ev = require("./Ev")

local SimAmbitions = {}

SimAmbitions.KINDS = { "unite", "empire", "city", "treasury" }
SimAmbitions.KIND_INDEX = { unite = 1, empire = 2, city = 3, treasury = 4 }

--- The great cities: names a province may carry (Natural Earth admin-1, English), for every start date (the medieval
--- ones and today's).
SimAmbitions.CITIES = {
	"Jerusalem", "Lazio", "Istanbul", "Makkah", "Baghdad", "Île-de-France", "Beijing", "Delhi", "Cairo", "Al Qahirah",
	"Moscow", "Moskva", "Isfahan", "Esfahan", "Damascus", "Dimashq", "Samarqand", "Kyoto", "Seoul", "Venezia", "Veneto",
	"Andalucía", "Córdoba", "Tunis", "Kiev", "Kyiv", "Constantinople", "Alexandria", "Al Iskandariyah", "Toledo",
	"Mexico", "Distrito Federal", "Cusco", "Lima", "Kano", "Tombouctou", "Addis Ababa", "London", "Greater London",
	"New York", "California", "Shanghai", "Tokyo", "Mumbai", "Maharashtra", "Lagos", "São Paulo", "Buenos Aires",
}

function SimAmbitions.install(C: any)
	function C:_init_ambitions()
		if self.depth == nil then
			return
		end
		self.o_amb = {}
		--- ISO -> its provinces on this map (unite)
		local by_iso = {}
		local P = self.P
		for p = 1, P.n do
			local iso = P.country[p]
			if iso ~= "" then
				local l = by_iso[iso]
				if l == nil then
					l = {}
					by_iso[iso] = l
				end
				table.insert(l, p)
			end
		end
		self.p_by_iso = by_iso
		--- the great cities found on this map
		local cities = {}
		local want = {}
		for _, n in SimAmbitions.CITIES do
			want[n] = true
		end
		for p = 1, P.n do
			if want[P.name[p]] then
				table.insert(cities, p)
			end
		end
		self.p_cities = cities
	end

	--- `id`'s three ambitions, from where it stands.
	function C:_set_ambitions(id: number)
		local P = self.P
		local dp = self.dp
		local home = self:province_at(self.o_spawn_tile[id])
		local iso = if home > 0 then P.country[home] else ""
		local out = {}
		local list = self.p_by_iso[iso]
		if list ~= nil and #list >= 2 and #list <= dp.unite_max then
			table.insert(out, { "unite", iso, false })
		end
		table.insert(out, { "empire", dp.empire_n, false })
		if #self.p_cities > 0 then
			local W = self.W
			local cap = self.o_spawn_tile[id]
			local best, bd = 0, math.huge
			for _, p in self.p_cities do
				local c = P.cap[p]
				local d = math.abs(c % W - cap % W) + math.abs(c // W - cap // W)
				if d < bd and home ~= p then
					best, bd = p, d
				end
			end
			if best > 0 then
				table.insert(out, { "city", best, false })
			end
		end
		if #out < 3 then
			table.insert(out, { "treasury", dp.treasury_gold, false })
		end
		while #out > 3 do
			table.remove(out)
		end
		self.o_amb[id] = out
		self:_amb_row(id)
	end

	local function fulfilled(self: any, id: number, a: any): boolean
		local kind, arg = a[1], a[2]
		if kind == "unite" then
			for _, p in self.p_by_iso[arg] or {} do
				if self.p_holder[p] ~= id then
					return false
				end
			end
			return true
		elseif kind == "empire" then
			return self.o_pheld[id] >= arg
		elseif kind == "city" then
			return self.p_holder[arg] == id
		elseif kind == "treasury" then
			return self.o_gold[id] >= arg
		end
		return false
	end

	--- Once a second, a share of the realms: ambitions set and checked.
	function C:_ambitions_second()
		if self.o_amb == nil then
			return
		end
		local stride = 5
		local slot = (self.tick // Defs.TICK_RATE) % stride
		for id = 1, self.owner_total do
			if id % stride ~= slot or self.o_alive[id] == 0 or self.o_spawned[id] == 0 or self.o_kind[id] == Defs.KIND_TRIBE then
				continue
			end
			local list = self.o_amb[id]
			if list == nil then
				self:_set_ambitions(id)
				continue
			end
			for i, a in list do
				if not a[3] and fulfilled(self, id, a) then
					a[3] = true
					self:add_prestige(id, self.dp.prestige_ambition)
					self:ev({ Ev.AMBITION, id, i, SimAmbitions.KIND_INDEX[a[1]] })
					self:msg(id, Defs.MSG_GOOD, "An ambition fulfilled: " .. self:ambition_text(a))
					self:_amb_row(id)
				end
			end
		end
	end

	--- An ambition in words: "Unite FRA", "Hold 20 provinces", "Hold Jerusalem", "Amass 3M gold".
	function C:ambition_text(a: any): string
		local kind, arg = a[1], a[2]
		if kind == "unite" then
			return "Unite your homeland"
		elseif kind == "empire" then
			return string.format("Hold %d provinces", arg)
		elseif kind == "city" then
			return "Hold " .. (self.P.name[arg] or "the great city")
		end
		return string.format("Amass %s gold", Defs.format_troops(arg))
	end

	function C:_amb_row(id: number)
		local list = self.o_amb[id]
		if list == nil then
			return
		end
		local row = { id }
		for _, a in list do
			table.insert(row, SimAmbitions.KIND_INDEX[a[1]])
			table.insert(row, if type(a[2]) == "number" then a[2] else 0)
			table.insert(row, if a[3] then 1 else 0)
		end
		local d = self.d_amb
		if d == nil then
			d = {}
			self.d_amb = d
		end
		table.insert(d, row)
	end

	--- Every realm's ambitions and prestige (a snapshot): { id, kind, arg, done x3 } and { id, prestige }.
	function C:_ambition_rows(): ({ { number } }, { { number } })
		local amb, pres = {}, {}
		if self.o_amb == nil then
			return amb, pres
		end
		for id = 1, self.owner_total do
			local list = self.o_amb[id]
			if list ~= nil and self.o_alive[id] == 1 then
				local row = { id }
				for _, a in list do
					table.insert(row, SimAmbitions.KIND_INDEX[a[1]])
					table.insert(row, if type(a[2]) == "number" then a[2] else 0)
					table.insert(row, if a[3] then 1 else 0)
				end
				table.insert(amb, row)
				table.insert(pres, { id, math.floor(self.o_prestige[id]) })
			end
		end
		return amb, pres
	end

	--- Prestige for provinces taken in war, and lost to a revolt.
	local prev_changed = C._on_province_changed
	function C:_on_province_changed(p: number, old: number, holder: number)
		prev_changed(self, p, old, holder)
		if self.o_amb ~= nil and old ~= 0 and holder ~= 0 and self:at_war(old, holder) then
			self:add_prestige(holder, self.dp.prestige_province)
		end
	end
	local prev_revolt = C._on_revolt
	function C:_on_revolt(id: number, p: number)
		prev_revolt(self, id, p)
		if self.o_prestige ~= nil then
			self.o_prestige[id] = math.max(self.o_prestige[id] - self.dp.prestige_revolt, 0)
		end
	end

	--- The realm with the most prestige (alive), or 0.
	function C:prestige_leader(): number
		local best, bp = 0, -1
		for id = 1, self.owner_total do
			if self.o_alive[id] == 1 and self.o_kind[id] ~= Defs.KIND_TRIBE and self.o_prestige[id] > bp then
				best, bp = id, self.o_prestige[id]
			end
		end
		return best
	end
end

return SimAmbitions
