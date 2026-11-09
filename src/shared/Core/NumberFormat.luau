--!strict
-- Number display (render_number / render_troops), Warhold's own: values are floored, never rounded,
-- lower-case, with at most one decimal ("2.5k", "123k", "1.2m"; a whole number drops it: "2k"),
-- negatives show as 0, and troops are shown as the internal count / 10 (a 25,000-troop start reads "2.5k").
-- Display only: nothing in the simulation reads these strings back.
local NumberFormat = {}

--- `v` floored to one decimal, without a trailing ".0".
local function short(v: number): string
	local tenths = math.floor(v * 10 + 1e-9)
	if tenths % 10 == 0 then
		return tostring(tenths // 10)
	end
	return string.format("%d.%d", tenths // 10, tenths % 10)
end

function NumberFormat.render_number(num: number): string
	if num ~= num then
		num = 0
	end
	num = math.max(num, 0)
	if num >= 1_000_000_000 then
		return short(num / 1_000_000_000) .. "b"
	elseif num >= 1_000_000 then
		return short(num / 1_000_000) .. "m"
	elseif num >= 100_000 then
		return tostring(math.floor(num / 1000)) .. "k"
	elseif num >= 1000 then
		return short(num / 1000) .. "k"
	end
	return tostring(math.floor(num))
end

--- render_troops: the internal troop count / 10.
function NumberFormat.render_troops(troops: number): string
	return NumberFormat.render_number(troops / 10)
end

return NumberFormat
