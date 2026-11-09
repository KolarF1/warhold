--!strict
-- The price book: what the interface may say a product costs. Roblox's number for this player when it has answered, and
-- the number in Data/Products until then, marked as not yet known so a button can wait rather than promise it (prices move
-- by region and while Roblox tests them). One worker reads the book's wanted list a little at a time, so a window full of
-- Standards can't burst into Roblox's limit; and an entry goes stale on its own, so a price that moves while a server is
-- up reaches the screen.
--
--   Prices.robux(key)        the number to show for Data/Products[key]
--   Prices.known(key)        Roblox has answered for it (a sale may be offered at that number)
--   Prices.want(keys)        put these in the worker's list (each read at most once every STALE_S)
--   Prices.fetch()           want every product but the Standards (they are wanted when their window shows them)
--   Prices.fetch_keys(keys)  the same as want
--   Prices.answer(key, n)    Roblox's number for it (the worker; tests)
--   Prices.changed           Signal(): a number arrived or moved
local UITheme = require("./UITheme")
local Signal = UITheme.core("Signal")

local IS_ROBLOX = typeof(game) == "Instance"
local Products: any = if IS_ROBLOX
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Products)
	else (require :: any)("../../shared/Data/Products")

local Prices = {}

--- A read is good for this long.
Prices.STALE_S = 600
--- The worker's pause between two reads.
Prices.GAP_S = 0.12
Prices.changed = Signal.new()

--- key -> { robux = Roblox's number, at = os.clock() of the read }
local book: { [string]: { robux: number, at: number } } = {}
--- what the worker still has to read, oldest first, and the same as a set
local queue: { string } = {}
local queued: { [string]: boolean } = {}
local working = false

function Prices.robux(key: string): number
	local e = book[key]
	if e ~= nil then
		return e.robux
	end
	local p = Products[key]
	return if type(p) == "table" then tonumber(p.robux) or 0 else 0
end

function Prices.known(key: string): boolean
	return book[key] ~= nil
end

function Prices.answer(key: string, robux: number)
	local e = book[key]
	local moved = e == nil or e.robux ~= robux
	book[key] = { robux = robux, at = os.clock() }
	if moved then
		Prices.changed:Fire()
	end
end

--- Should the worker read `key`? Only a product that exists, and only when its last read has gone stale.
function Prices.due(key: string): boolean
	local p = Products[key]
	if type(p) ~= "table" or (tonumber(p.id) or 0) == 0 or queued[key] then
		return false
	end
	local e = book[key]
	return e == nil or os.clock() - e.at >= Prices.STALE_S
end

--- Readers at once (2026-11-08: one at a time left a shop's BUY buttons waiting behind every Standard's price).
Prices.WORKERS = 4
local busy = 0

local function work()
	busy += 1
	working = busy >= Prices.WORKERS
	local mps = game:GetService("MarketplaceService")
	while #queue > 0 do
		local key = table.remove(queue, 1) :: string
		queued[key] = nil
		local ok, info = pcall(function()
			return mps:GetProductInfo(Products[key].id, Enum.InfoType.Product)
		end)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			Prices.answer(key, info.PriceInRobux)
		end
		task.wait(Prices.GAP_S)
	end
	busy -= 1
	working = busy >= Prices.WORKERS
end

--- `urgent`: a window shows these now, so they go to the front of the list.
function Prices.want(keys: { string }, urgent: boolean?)
	for _, key in keys do
		if urgent and queued[key] then
			local i = table.find(queue, key)
			if i ~= nil then
				table.remove(queue, i)
				table.insert(queue, 1, key)
			end
		elseif Prices.due(key) then
			queued[key] = true
			if urgent then
				table.insert(queue, 1, key)
			else
				table.insert(queue, key)
			end
		end
	end
	-- (task.spawn runs a reader up to its first read, so it has counted itself in before the next test)
	local spawned = 0
	while IS_ROBLOX and #queue > 0 and busy < Prices.WORKERS and spawned < Prices.WORKERS do
		task.spawn(work)
		spawned += 1
	end
end

Prices.fetch_keys = Prices.want

--- Every product's price in one read (MarketplaceService:GetDeveloperProductsAsync; 2026-11-09: one read a product left a
--- shop of Standards grey for seconds). Once a server's client has it, the per-product worker has only stale ones to do.
local listed = false
local fetch_each: () -> ()
function Prices.fetch_all()
	if listed or not IS_ROBLOX then
		return
	end
	listed = true
	task.spawn(function()
		local by_id = {} :: { [number]: string }
		for key, p in Products do
			if type(p) == "table" and (tonumber(p.id) or 0) ~= 0 then
				by_id[tonumber(p.id) :: number] = key
			end
		end
		local ok, pages = pcall(function()
			return game:GetService("MarketplaceService"):GetDeveloperProductsAsync()
		end)
		if not ok or pages == nil then
			-- (no list: a read a product, as before)
			listed = false
			fetch_each()
			return
		end
		while true do
			for _, info in pages:GetCurrentPage() do
				local key = by_id[tonumber(info.ProductId) or -1] or by_id[tonumber(info.DeveloperProductId) or -1]
				if key ~= nil and type(info.PriceInRobux) == "number" then
					Prices.answer(key, info.PriceInRobux)
				end
			end
			if pages.IsFinished then
				break
			end
			local more = pcall(function()
				pages:AdvanceToNextPageAsync()
			end)
			if not more then
				break
			end
		end
	end)
end

function fetch_each()
	local keys = {}
	for key, p in Products do
		if type(p) == "table" and p.shop_flag == nil and p.shop_set == nil then
			table.insert(keys, key)
		end
	end
	Prices.want(keys)
end

--- Every product but the Standards (they are wanted when their window shows them): one read for all of them on Roblox.
function Prices.fetch()
	if IS_ROBLOX then
		Prices.fetch_all()
	else
		fetch_each()
	end
end

return Prices
