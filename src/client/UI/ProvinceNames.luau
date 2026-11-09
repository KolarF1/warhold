--!nonstrict
-- The Provinces map mode's names (a depth match, docs/DEPTH_DESIGN.md): each province's name at its capital, when the
-- map is close enough to read them. The largest first; one that would overlap a name already placed waits; at most
-- MAX on the screen. Which names show is worked out every PICK_S; the ones shown follow the camera every frame.
local UITheme = require("./UITheme")
local W = require("./Widgets")

local ProvinceNames = W.class(W.Control)

ProvinceNames.MAX = 60
ProvinceNames.PICK_S = 0.25
--- The room (px) kept round each name.
ProvinceNames.GAP = 6

function ProvinceNames.new(c: any)
	local self = setmetatable({}, ProvinceNames.__mt)
	W.Control._init(self)
	self.ctx = c
	self._labels = {}
	self._shown = {}
	self._acc = ProvinceNames.PICK_S
	self:set_mouse_filter(W.MOUSE_IGNORE)
	self:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	return self
end

--- Which provinces get a name: `pos(p)` gives a capital's screen point (or nil off the screen), `size(p)` how wide its
--- name is; the largest province first, none overlapping. Pure.
function ProvinceNames.pick(n: number, order: { number }, pos: (number) -> Vector2?, width: (number) -> number, max: number): { { any } }
	local out = {}
	local boxes = {}
	for _, p in order do
		if #out >= max then
			break
		end
		local at = pos(p)
		if at ~= nil then
			local w = width(p)
			local box = { at.X - w * 0.5 - ProvinceNames.GAP, at.Y - 8 - ProvinceNames.GAP, at.X + w * 0.5 + ProvinceNames.GAP, at.Y + 8 + ProvinceNames.GAP }
			local free = true
			for _, b in boxes do
				if box[1] < b[3] and b[1] < box[3] and box[2] < b[4] and b[2] < box[4] then
					free = false
					break
				end
			end
			if free then
				table.insert(boxes, box)
				table.insert(out, { p, at })
			end
		end
	end
	local _ = n
	return out
end

function ProvinceNames._label(self, i: number): any
	local l = self._labels[i]
	if l ~= nil then
		return l
	end
	local T = UITheme
	l = T.label("", 11, 700, T.c(T.WHITE, 0.85))
	l:set_mouse_filter(W.MOUSE_IGNORE)
	l.horizontal_alignment = W.ALIGN_CENTER
	self:add_child(l)
	self._labels[i] = l
	return l
end

function ProvinceNames.update(self, dt: number)
	local ctx = self.ctx
	local s = ctx.state
	local ds = s and s.depth
	local on = ds ~= nil and ds.P ~= nil and ctx.map_mode == "provinces" and self:is_visible_in_tree()
	if not on then
		for _, l in self._labels do
			l:set_visible(false)
		end
		self._shown = {}
		return
	end
	local P = ds.P
	local vp = ctx.vp
	local function pos(p: number): Vector2?
		local raw = ctx:world_call("screen_pos_of_tile", { P.cap[p] })
		if typeof(raw) ~= "Vector2" then
			return nil
		end
		local at = ctx:to_logical(raw)
		if at.X < 0 or at.Y < 0 or at.X > vp.X or at.Y > vp.Y then
			return nil
		end
		return at
	end
	self._acc += dt
	if self._acc >= ProvinceNames.PICK_S then
		self._acc = 0.0
		if self._order == nil or self._order_n ~= P.n then
			local order = {}
			for p = 1, P.n do
				order[p] = p
			end
			table.sort(order, function(a, b)
				return P.size[a] > P.size[b]
			end)
			self._order, self._order_n = order, P.n
		end
		-- (zoomed far out the names crowd each other: the overlap rule keeps only the largest)
		self._shown = ProvinceNames.pick(P.n, self._order, pos, function(p)
			return UITheme.measure_text(P.name[p], 11, 700) + 4
		end, ProvinceNames.MAX)
	end
	local used = 0
	for _, it in self._shown do
		local p = it[1]
		local at = pos(p)
		if at ~= nil then
			used += 1
			local l = self:_label(used)
			if l.text ~= P.name[p] then
				l:set_text(P.name[p])
			end
			local w = UITheme.measure_text(P.name[p], 11, 700) + 4
			l:set_visible(true)
			l:set_anchors(0, 0, 0, 0)
			l:set_offsets(at.X - w * 0.5, at.Y - 8, at.X + w * 0.5, at.Y + 8)
		end
	end
	for i = used + 1, #self._labels do
		self._labels[i]:set_visible(false)
	end
end

return ProvinceNames
