--!native
-- The local player's frontier, kept as a ledger: every tile of ours that touches something else has a
-- line in it saying what it touches, and the totals over those lines answer the UI's questions at once
-- ("do I border this owner?", "how long is that front?", "can a boat reach that coast?"; the Sim still
-- validates everything). Nothing is ever rescanned: a tile change rewrites the lines of that tile and
-- of its four neighbours, so an answer is exact the moment the change has come in and costs no work to
-- read, on a phone mid-war too.
--
-- A line is four digits in one number, one for each side of the tile (a number, not a table: a late
-- game's frontier is tens of thousands of tiles, each rewritten many times a minute):
--   0 this side is ours or off the map; 1 .. 1023 the owner across it; FREE claimable free land across
--   it; WATER anything else nobody owns (the sea, a lake, an unclaimable ice cap).
-- Lines are worked out from the map as it stands, not from the change's values, so a batch whose tiles
-- touch each other comes out the same in any order. Poisoned land is the one thing a tile change does
-- not announce, so it is looked up when the question is asked (see _touches_free).

-- Flat maps: the grid size comes from the bound state's map; tiles on an edge simply have fewer sides
-- (nothing wraps).
local F_FALLOUT = 1

--- A line's digit values (owners are 1 .. 1023: a change is packed as tile * 1024 + owner).
local FREE = 1024
local WATER = 1025
local BASE = 1026

local BorderTracker = {}
BorderTracker.__index = BorderTracker

function BorderTracker.new()
	local self = setmetatable({}, BorderTracker)
	self.state = nil :: any
	self.me = 0
	--- Our tiles touching at least one tile we do not own (incl. water): tile -> its line. (Only the
	--- keys mean anything outside this file.)
	self.border = {} :: { [number]: number }
	--- owner -> how many tile sides we share with them
	self._front = {} :: { [number]: number }
	--- water body -> how many of our frontier tiles are on its coast
	self._coast = {} :: { [number]: number }
	--- sides we share with claimable free land, poisoned or not
	self._free = 0
	--- _touches_free's last answer, good while _free_seen is the fallout count it was worked out at
	--- and no side changed since (nil: work it out)
	self._free_answer = nil :: boolean?
	self._free_seen = -1
	self.W = 1
	self.H = 1
	--- region_touches_me's working tables, kept between clicks
	self._seen = {} :: { [number]: boolean }
	self._queue = {} :: { number }
	return self
end

-- Owner grid accessor: Core keeps per-tile grids as i32 buffers.
local function owner_at(own: any, i: number): number
	if typeof(own) == "buffer" then
		return buffer.readi32(own, i * 4)
	end
	return own[i] or 0
end

local function u8(grid: any, i: number): number
	if typeof(grid) == "buffer" then
		return buffer.readu8(grid, i)
	end
	return grid[i] or 0
end

--- Water body of a coastal tile (maps store 16-bit bodies; older mirrors a u8 grid).
local function coast_body_of(map: any, i: number): number
	if type(map.coast_body_of) == "function" then
		return map:coast_body_of(i)
	end
	return u8(map.coast_body, i)
end

--- What one side of a tile of ours shows: a digit of its line.
local function side(own: any, map: any, me: number, n: number): number
	local o = owner_at(own, n)
	if o == me then
		return 0
	elseif o ~= 0 then
		return o
	end
	return if map:is_contestable(n) then FREE else WATER
end

--- The line of tile `i`, ours: 0 when all it touches is ours (not on the frontier).
local function line_of(self: any, own: any, map: any, i: number): number
	local W, me = self.W, self.me
	local x = i % W
	local line = 0
	if x > 0 then
		line = side(own, map, me, i - 1)
	end
	if x < W - 1 then
		line = line * BASE + side(own, map, me, i + 1)
	end
	if i >= W then
		line = line * BASE + side(own, map, me, i - W)
	end
	if i < W * (self.H - 1) then
		line = line * BASE + side(own, map, me, i + W)
	end
	return line
end

--- Adds a line's sides to the totals (`by` 1), or takes them off (-1).
local function count(self: any, line: number, by: number)
	local front = self._front
	while line > 0 do
		local d = line % BASE
		line //= BASE
		if d == FREE then
			self._free += by
			self._free_answer = nil
		elseif d ~= WATER and d ~= 0 then
			local c = (front[d] or 0) + by
			front[d] = if c > 0 then c else nil
		end
	end
end

--- Rewrites tile `i`'s line from the map as it stands.
local function rewrite(self: any, own: any, map: any, i: number)
	local border = self.border
	local was: number? = border[i]
	local now: number? = nil
	if owner_at(own, i) == self.me then
		local line = line_of(self, own, map, i)
		if line ~= 0 then
			now = line
		end
	end
	if was == now then
		return
	end
	if was ~= nil then
		count(self, was, -1)
	end
	if now ~= nil then
		count(self, now, 1)
	end
	border[i] = now
	-- a tile coming onto or going off the frontier
	if (was == nil) ~= (now == nil) and u8(map.coastal, i) == 1 then
		local body = coast_body_of(map, i)
		local c = (self._coast[body] or 0) + (if now ~= nil then 1 else -1)
		self._coast[body] = if c > 0 then c else nil
	end
end

function BorderTracker.bind(self: any, s: any, owner_id: number)
	self.state = s
	self.me = owner_id
	table.clear(self.border)
	table.clear(self._front)
	table.clear(self._coast)
	self._free = 0
	self._free_answer = nil
	if s ~= nil and s.map ~= nil then
		self.W = s.map.W or s.map.width or 1
		self.H = s.map.H or s.map.height or 1
	end
	if s == nil or owner_id <= 0 then
		return
	end
	local o = s:get_owner(owner_id)
	if o == nil or (o.tiles or 0) <= 0 then
		return
	end
	local own, map = s.owner, s.map
	for i = 0, self.W * self.H - 1 do
		if owner_at(own, i) == owner_id then
			rewrite(self, own, map, i)
		end
	end
end

--- `changed` holds packed (tile << 10) | owner values (buffer of i32 or a Luau array).
function BorderTracker.on_tiles_changed(self: any, changed: any)
	local s = self.state
	if s == nil or self.me <= 0 then
		return
	end
	local own, map = s.owner, s.map
	if typeof(changed) == "buffer" then
		for k = 0, buffer.len(changed) // 4 - 1 do
			self:_on_change(buffer.readi32(changed, k * 4) // 1024, own, map)
		end
	else
		for _, v in changed do
			self:_on_change(v // 1024, own, map)
		end
	end
end

--- Tile `i` changed hands: its line and its neighbours'. (Most changes in a match are other people's,
--- far from us: a tile with no line and no side of ours touches none of ours, and that is all it costs.)
function BorderTracker._on_change(self: any, i: number, own: any, map: any)
	local W, me = self.W, self.me
	local x = i % W
	local left = x > 0 and owner_at(own, i - 1) == me
	local right = x < W - 1 and owner_at(own, i + 1) == me
	local up = i >= W and owner_at(own, i - W) == me
	local down = i < W * (self.H - 1) and owner_at(own, i + W) == me
	if self.border[i] ~= nil or owner_at(own, i) == me or left or right or up or down then
		rewrite(self, own, map, i)
	end
	if left then
		rewrite(self, own, map, i - 1)
	end
	if right then
		rewrite(self, own, map, i + 1)
	end
	if up then
		rewrite(self, own, map, i - W)
	end
	if down then
		rewrite(self, own, map, i + W)
	end
end

--- Whether any of the free land we touch can still be claimed. Poisoned land flips with no tile change,
--- so the sides are gone over here, stopping at the first good one, and only when the sides or the
--- count of poisoned tiles moved since last time.
function BorderTracker._touches_free(self: any): boolean
	if self._free <= 0 then
		return false
	end
	local s = self.state
	local poisoned = tonumber(s.fallout_count) or -1
	-- (no count on this state: asked afresh each time)
	if self._free_answer ~= nil and poisoned >= 0 and poisoned == self._free_seen then
		return self._free_answer
	end
	self._free_seen = poisoned
	local own, map, flags = s.owner, s.map, s.flags
	local W, H = self.W, self.H
	local function open(n: number): boolean
		return owner_at(own, n) == 0 and map:is_contestable(n) and bit32.band(u8(flags, n), F_FALLOUT) == 0
	end
	for i in self.border do
		local x = i % W
		if (x > 0 and open(i - 1)) or (x < W - 1 and open(i + 1)) or (i >= W and open(i - W)) or (i < W * (H - 1) and open(i + W)) then
			self._free_answer = true
			return true
		end
	end
	self._free_answer = false
	return false
end

--- True when we share a land border with `id` (0 = any claimable free land).
function BorderTracker.borders_owner(self: any, id: number): boolean
	if id == 0 then
		return self:_touches_free()
	end
	return self._front[id] ~= nil
end

--- How long our front with `id` is: the tile sides we share. 0 when we do not touch them.
function BorderTracker.front_length(self: any, id: number): number
	return self._front[id] or 0
end

--- Our front with `id` as the hover card says it (nil when we do not touch them): by full-size tiles of it.
BorderTracker.FRONT_WORDS = { { below = 30, word = "Short" }, { below = 120, word = "Broad" }, { below = math.huge, word = "Vast" } }
function BorderTracker.front_word(self: any, id: number): string?
	local sides = self._front[id]
	if sides == nil then
		return nil
	end
	local full = sides * (tonumber(self.state.map.k_lin) or 1)
	for _, w in BorderTracker.FRONT_WORDS do
		if full < w.below then
			return w.word
		end
	end
	return nil
end

--- Neighbour owner ids, ascending (deterministic order).
function BorderTracker.neighbour_ids(self: any): { number }
	local out = {}
	for k in self._front do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

--- The neighbour we share the longest front with (ties to the lower id), or 0 with no neighbour.
function BorderTracker.longest_front(self: any): number
	local best, length = 0, 0
	for id, c in self._front do
		if c > length or (c == length and id < best) then
			best, length = id, c
		end
	end
	return best
end

function BorderTracker.has_coast(self: any): boolean
	return next(self._coast) ~= nil
end

--- A transport can sail from our coast to `tile` (coastal land on a water body we touch).
function BorderTracker.can_reach_by_sea(self: any, tile: number): boolean
	local s = self.state
	if s == nil or tile < 0 then
		return false
	end
	local map = s.map
	return u8(map.coastal, tile) == 1 and self._coast[coast_body_of(map, tile)] ~= nil
end

--- Walks the clicked owner's region from `tile` (bounded) to see whether it touches us by land.
--- Returns 1 = touches, 0 = region fully explored without contact, -1 = budget exhausted.
function BorderTracker.region_touches_me(self: any, tile: number, budget: number?): number
	local s = self.state
	if s == nil or self.me <= 0 or tile < 0 then
		return 0
	end
	local own, map = s.owner, s.map
	local me = self.me
	local target = owner_at(own, tile)
	-- the ledger knows already when we touch no land of that kind anywhere: no walk at all
	if target ~= me and map:is_contestable(tile) then
		if target == 0 then
			if self._free <= 0 then
				return 0
			end
		elseif self._front[target] == nil then
			return 0
		end
	end
	local lim = budget or 3000
	local W, last_row = self.W, self.W * (self.H - 1)
	local seen, queue = self._seen, self._queue
	table.clear(seen)
	seen[tile] = true
	queue[1] = tile
	local head, tail = 1, 1
	-- (one side of a tile: true when it is ours; land of the region not yet reached joins the queue)
	local function look(n: number): boolean
		local o = owner_at(own, n)
		if o == me then
			return true
		end
		if o == target and not seen[n] and map:is_contestable(n) then
			seen[n] = true
			tail += 1
			queue[tail] = n
		end
		return false
	end
	while head <= tail do
		if head - 1 >= lim then
			return -1
		end
		local i = queue[head]
		head += 1
		local x = i % W
		if (x > 0 and look(i - 1)) or (x < W - 1 and look(i + 1)) or (i >= W and look(i - W)) or (i < last_row and look(i + W)) then
			return 1
		end
	end
	return 0
end

return BorderTracker
