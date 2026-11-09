--!nonstrict
-- The order card (right-click / long-press; the module keeps its old name, which UIRoot and UIInteract use):
-- a flat list of orders opening beside the click. The order that fits the target comes first and largest, the rest
-- follow by weight (UIRules.order_items), and an order that can't be given stays in the list and says why.
-- An item with a `sub` list opens it in the same card, with a Back row on top.
--
-- A list too tall for the screen wraps into a second column (a phone's Build list: 8+ rows of 44 px on a
-- 400 px screen) rather than scrolling: every row stays one tap away.
--
-- Its head says who the land's owner is and what they have, so there is no reading order to give.
--
-- Drawn with plain instances in a logical-px canvas. While open a full-screen button swallows pointer input. A row is
-- picked by a tap on it: the finger that opened the card with a long-press only lifts.
-- Keys (UIInteract._on_key): Up / Down move, Enter / Space / Right pick, Left goes back or closes.

local UICtx = require("./UICtx") :: any
local UIRules = require("./UIRules") :: any
local Signal = UICtx.core("Signal")

local _T: any = nil
local function T(): any
	if _T == nil then
		_T = UICtx.mod("UITheme")
	end
	return _T
end

local RadialMenu = {}
RadialMenu.__index = RadialMenu

--- Row heights: touch (a finger's target) and mouse; the first row, the fitting order, is larger.
RadialMenu.ROW_TOUCH = 44.0
RadialMenu.ROW_MOUSE = 34.0
RadialMenu.TOP_TOUCH = 52.0
RadialMenu.TOP_MOUSE = 40.0
RadialMenu.HEAD_H = 26.0
--- The line under the name.
RadialMenu.HEAD_SUB_H = 16.0
RadialMenu.PAD = 6.0
RadialMenu.GAP = 2.0
RadialMenu.WIDTH_MIN = 190.0
RadialMenu.WIDTH_MAX = 330.0
--- Between the click and the card.
RadialMenu.BESIDE = 14.0
RadialMenu.LABEL_PX = 13
RadialMenu.TOP_LABEL_PX = 15
RadialMenu.DETAIL_PX = 12
local ICON = 18.0

local function text_px(size: number): number
	return math.floor(size * T().LINE_EM + 0.5)
end

--- Where the card goes for a click at `pos` in `area`: `w` x `h`, on the click's right when it fits, else on its left,
--- the first row level with the click, always inside the area. Pure.
function RadialMenu.placement(pos: Vector2, w: number, h: number, area: Rect, first_row_y: number?): Vector2
	local B = RadialMenu.BESIDE
	local x = pos.X + B
	if x + w > area.Max.X then
		x = pos.X - B - w
	end
	x = math.clamp(x, area.Min.X, math.max(area.Min.X, area.Max.X - w))
	local y = pos.Y - (first_row_y or 0)
	y = math.clamp(y, area.Min.Y, math.max(area.Min.Y, area.Max.Y - h))
	return Vector2.new(math.floor(x + 0.5), math.floor(y + 0.5))
end

--- How the rows fall: `heights` in order, into columns of at most `max_h`. Returns { col, y } per row (col from 1)
--- and each column's height. Pure.
function RadialMenu.flow(heights: { number }, max_h: number, gap: number): ({ { col: number, y: number } }, number, number)
	local out = {}
	local col, y, tallest = 1, 0.0, 0.0
	for i, h in heights do
		if y > 0 and y + h > max_h then
			col += 1
			y = 0.0
		end
		out[i] = { col = col, y = y }
		tallest = math.max(tallest, y + h)
		y += h + gap
	end
	return out, col, tallest
end

function RadialMenu.new(c: any)
	local self = setmetatable({}, RadialMenu)
	self.ctx = c
	self.picked = Signal.new() -- (id, tile)
	self.closed = Signal.new()
	self.tile = -1
	--- Where the card was opened (UIInteract floats its confirmations here).
	self.center = Vector2.zero
	self.items = {} :: { any }
	self.title = ""
	self.title_color = T().TEXT
	self.is_open = false
	self._root_items = {} :: { any }
	self._in_sub = false
	--- the lists above the current one (Build > City > x1 x5 x10 xMax)
	self._stack = {} :: { any }
	self._sub_title = ""
	--- The rows on show: { item } or { back = true }; `_hover` an index into them (0: none).
	self._rows = {} :: { any }
	self._hover = 0
	self._close_t = 0.0
	self._closing = false
	--- False until a press lands on the open menu: a lift before that is the finger that opened it.
	self._saw_press = false
	self._conns = {} :: { any }
	self._pool = {} :: { any }
	self:_build()
	return self
end

-- ---------------------------------------------------------------------------------------------
-- Instances
-- ---------------------------------------------------------------------------------------------

function RadialMenu._build(self: any)
	local Th = T()
	local canvas = UICtx.canvas(nil, "OrderCard")
	canvas.Visible = false
	self.gui = canvas
	-- Input sink while open.
	self._blocker = UICtx.make("TextButton", {
		Name = "Blocker",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Active = true,
		Selectable = false,
		ZIndex = 1,
	}, canvas)
	local card = UICtx.make("Frame", {
		Name = "Card",
		BorderSizePixel = 0,
		BackgroundColor3 = Th.color3(Th.GLASS_SOLID),
		BackgroundTransparency = 1 - Th.alpha(Th.GLASS_SOLID),
		ZIndex = 2,
		Visible = false,
	}, canvas)
	UICtx.make("UICorner", { CornerRadius = UDim.new(0, Th.R_LG) }, card)
	UICtx.make("UIStroke", {
		Thickness = 1,
		Color = Th.color3(Th.LINE_2),
		Transparency = 1 - Th.alpha(Th.LINE_2),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, card)
	self._card = card
	self._title = UICtx.make("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		FontFace = Th.font(700),
		TextSize = text_px(RadialMenu.LABEL_PX),
		TextColor3 = Th.TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 4,
	}, card)
	self._head_sub = UICtx.make("TextLabel", {
		Name = "HeadSub",
		BackgroundTransparency = 1,
		FontFace = Th.font(600),
		TextSize = text_px(RadialMenu.DETAIL_PX),
		TextColor3 = Th.TEXT_2,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		ZIndex = 4,
		Visible = false,
	}, card)
end

--- One pooled row: a fill, an icon, its label and the detail (cost, troops, or why not).
function RadialMenu._row_parts(self: any, i: number): any
	local r = self._pool[i]
	if r ~= nil then
		return r
	end
	local Th = T()
	local f = UICtx.make("Frame", { BorderSizePixel = 0, ZIndex = 3 }, self._card)
	UICtx.make("UICorner", { CornerRadius = UDim.new(0, Th.R_MD) }, f)
	r = {
		frame = f,
		icon = UICtx.make("ImageLabel", {
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(ICON, ICON),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			ZIndex = 4,
		}, f),
		label = UICtx.make("TextLabel", {
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
		}, f),
		detail = UICtx.make("TextLabel", {
			BackgroundTransparency = 1,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 4,
		}, f),
		more = UICtx.make("ImageLabel", {
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(12, 12),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Rotation = -90,
			ZIndex = 4,
		}, f),
	}
	self._pool[i] = r
	return r
end

-- ---------------------------------------------------------------------------------------------
-- Open / close
-- ---------------------------------------------------------------------------------------------

function RadialMenu.open_at(self: any, t: number, pos: Vector2, its: { any }, title_text: string, title_col: Color3, head_sub: string?)
	local ctx = self.ctx
	self.tile = t
	self._root_items = its
	self.items = its
	self._in_sub = false
	self._stack = {}
	self.title = title_text
	self.title_color = title_col
	self.head_sub = head_sub or ""
	self.center = pos
	self.is_open = true
	self._closing = false
	self._saw_press = false
	self._hover = 0
	ctx:fit_canvas(self.gui)
	self.gui.Visible = true
	self._blocker.Active = true
	self._blocker.Visible = true
	self:_connect_input()
	ctx:sfx("open", -8.0)
	self:_lay_out()
end

function RadialMenu.close(self: any, emit: boolean?)
	if not self.is_open then
		return
	end
	self.is_open = false
	self._closing = true
	-- Stay input-opaque a moment (the press that closed us must not fall through to the map).
	self._close_t = 0.06
	self._card.Visible = false
	if emit ~= false then
		self.closed:Fire()
	end
end

function RadialMenu._enter_sub(self: any, item: any)
	-- (lists nest: Build > City > x1 x5 x10 xMax; Back goes up one)
	table.insert(self._stack, { items = self.items, title = self._sub_title, in_sub = self._in_sub })
	self.items = table.clone(item.sub or {})
	self._in_sub = true
	self._sub_title = tostring(item.label or "")
	self._hover = 0
	self.ctx:sfx("click", -6.0)
	self:_lay_out()
end

function RadialMenu._back(self: any)
	local prev = table.remove(self._stack)
	if prev == nil then
		self:close()
		return
	end
	self.items = prev.items
	self._sub_title = prev.title
	self._in_sub = prev.in_sub
	self._hover = 0
	self.ctx:sfx("click", -6.0)
	self:_lay_out()
end

--- Back a list, or close from the first.
function RadialMenu.back_or_close(self: any)
	if self._in_sub then
		self:_back()
	else
		self:close()
	end
end

--- Per frame (UIRoot's loop).
function RadialMenu.update(self: any, delta: number)
	if self._closing then
		self._close_t -= delta
		if self._close_t <= 0.0 then
			self._closing = false
			self.gui.Visible = false
			self._blocker.Active = false
			self._blocker.Visible = false
			self:_disconnect_input()
		end
	end
end

-- ---------------------------------------------------------------------------------------------
-- Rows: choosing them
-- ---------------------------------------------------------------------------------------------

--- The row under `p` (0: none).
function RadialMenu._index_at(self: any, p: Vector2): number
	for i, r in self._rows do
		local q = r.rect
		if q ~= nil and p.X >= q.Min.X and p.X <= q.Max.X and p.Y >= q.Min.Y and p.Y <= q.Max.Y then
			return i
		end
	end
	return 0
end

function RadialMenu._set_hover(self: any, h: number)
	if h ~= self._hover then
		self._hover = h
		if h > 0 then
			self.ctx:sfx("hover", -14.0)
		end
		self:_paint()
	end
end

--- Do what row `i` says: go back, open its list, pick it, or refuse with a sound.
function RadialMenu._act(self: any, i: number)
	local row = self._rows[i]
	if row == nil then
		return
	end
	if row.back then
		self:_back()
		return
	end
	local it = row.item
	if not it.ok then
		self.ctx:sfx("deny", -4.0)
		return
	end
	if it.sub ~= nil then
		self:_enter_sub(it)
		return
	end
	local id = tostring(it.id or "")
	local t = self.tile
	self:close(false)
	self.picked:Fire(id, t)
end

--- Keys: move to the next row that can be chosen (`dir` -1 up, +1 down), wrapping round.
function RadialMenu.move_selection(self: any, dir: number)
	local n = #self._rows
	if n == 0 then
		return
	end
	local i = if self._hover > 0 then self._hover elseif dir > 0 then 0 else 1
	for _ = 1, n do
		i = (i + dir - 1) % n + 1
		local row = self._rows[i]
		if row.back or row.item.ok then
			self:_set_hover(i)
			return
		end
	end
end

--- Keys: pick the row in focus; with none, the fitting order on top.
function RadialMenu.confirm_selection(self: any)
	if self._hover > 0 then
		self:_act(self._hover)
		return
	end
	for i, row in self._rows do
		if not row.back and row.item.ok then
			self:_act(i)
			return
		end
	end
end

function RadialMenu._press(self: any, pos: Vector2, right: boolean)
	if not self.is_open then
		return
	end
	self._saw_press = true
	if right then
		self:back_or_close()
		return
	end
	local i = self:_index_at(pos)
	if i == 0 then
		-- (on the card's own padding: nothing; off it: the card closes)
		local c = self._card_rect
		if c == nil or not (pos.X >= c.Min.X and pos.X <= c.Max.X and pos.Y >= c.Min.Y and pos.Y <= c.Max.Y) then
			self:close()
		end
		return
	end
	self:_act(i)
end

function RadialMenu._connect_input(self: any)
	if not UICtx.IS_ROBLOX or #self._conns > 0 then
		return
	end
	local ctx = self.ctx
	local UIS = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local function lpos(io: InputObject): Vector2
		local p = Vector2.new(io.Position.X, io.Position.Y)
		if io.UserInputType == Enum.UserInputType.Touch then
			p += GuiService:GetGuiInset()
		else
			p = UIS:GetMouseLocation()
		end
		return ctx:to_logical(p)
	end
	local b = self._blocker
	table.insert(
		self._conns,
		b.InputBegan:Connect(function(io: InputObject)
			local ty = io.UserInputType
			if ty == Enum.UserInputType.Touch and io.UserInputState ~= Enum.UserInputState.Begin then
				-- not a new touch: a finger already down "begins" on the blocker when it next moves or lifts over it,
				-- and the blocker has just appeared under the finger that opened the card. Taken for a press,
				-- the wobble of that finger lifting closed the menu as soon as it let go, which made press and hold
				-- useless on phones (2026-10-04). Its slide and release are followed below.
				return
			end
			if ty == Enum.UserInputType.MouseButton1 or ty == Enum.UserInputType.Touch then
				self:_press(lpos(io), false)
			elseif ty == Enum.UserInputType.MouseButton2 then
				self:_press(lpos(io), true)
			end
		end)
	)
	-- Hover: the mouse, and the opening finger's slide (it lights a row, which a tap then picks).
	table.insert(
		self._conns,
		UIS.InputChanged:Connect(function(io: InputObject)
			if not self.is_open then
				return
			end
			local ty = io.UserInputType
			if ty == Enum.UserInputType.MouseMovement or (ty == Enum.UserInputType.Touch and not self._saw_press) then
				self:_set_hover(self:_index_at(lpos(io)))
			end
		end)
	)
	table.insert(
		self._conns,
		UIS.InputEnded:Connect(function(io: InputObject)
			if not self.is_open or self._saw_press then
				return
			end
			local ty = io.UserInputType
			if ty == Enum.UserInputType.Touch or ty == Enum.UserInputType.MouseButton1 then
				self._saw_press = true
			end
		end)
	)
end

function RadialMenu._disconnect_input(self: any)
	for _, c in self._conns do
		c:Disconnect()
	end
	table.clear(self._conns)
end

-- ---------------------------------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------------------------------

--- Where the card may go: the safe area.
function RadialMenu._area(self: any): Rect
	local ctx = self.ctx
	local ins = ctx.insets
	local top = ins.y + 8.0
	return UICtx.rect(ins.x + 8.0, top, ctx.vp.X - ins.x - ins.z - 16.0, ctx.vp.Y - top - ins.w - 8.0)
end

--- Fills `self._rows` from `self.items` and lays out the card. Text widths come from T.text_width.
function RadialMenu._lay_out(self: any)
	local ctx = self.ctx
	local Th = T()
	local touch = ctx.touch
	local row_h = if touch then RadialMenu.ROW_TOUCH else RadialMenu.ROW_MOUSE
	local top_h = if touch then RadialMenu.TOP_TOUCH else RadialMenu.TOP_MOUSE
	local rows = {}
	if self._in_sub then
		table.insert(rows, { back = true, height = row_h })
	end
	local ordered = UIRules.order_items(self.items)
	local first_ok = true
	for _, it in ordered do
		local big = not self._in_sub and first_ok and it.ok == true
		first_ok = false
		table.insert(rows, { item = it, big = big, height = if big then top_h else row_h })
	end
	self._rows = rows
	-- text and the width it asks for
	local ratio = ctx.ratio
	local sends = ctx:troops_for_ratio()
	local w = RadialMenu.WIDTH_MIN
	for _, r in rows do
		r.label = if r.back then self._sub_title else tostring(r.item.label or "")
		r.detail = if r.back then "" else UIRules.order_detail(r.item, ratio, sends)
		local lw = Th.text_width(r.label, if r.big then RadialMenu.TOP_LABEL_PX else RadialMenu.LABEL_PX, 700)
		local dw = if r.detail ~= "" then Th.text_width(r.detail, RadialMenu.DETAIL_PX, 600) else 0
		local extra = if not r.back and r.item.sub ~= nil then 16.0 else 0.0
		r.lw, r.dw = lw, dw
		w = math.max(w, 8 + ICON + 8 + lw + (if dw > 0 then 14 + dw else 0) + extra + 10)
	end
	local PAD, GAP = RadialMenu.PAD, RadialMenu.GAP
	local has_sub = not self._in_sub and (self.head_sub or "") ~= ""
	local head = if self._in_sub then 0.0 elseif has_sub then RadialMenu.HEAD_H + RadialMenu.HEAD_SUB_H else RadialMenu.HEAD_H
	if has_sub then
		w = math.max(w, Th.text_width(self.head_sub, RadialMenu.DETAIL_PX, 600) + 16.0)
	end
	local area = self:_area()
	local heights = {}
	for i, r in rows do
		heights[i] = r.height
	end
	local col_max_h = math.max(row_h, area.Height - 2 * PAD - head)
	local flow, cols, tallest = RadialMenu.flow(heights, col_max_h, GAP)
	-- a row that can't take label and detail side by side stacks them (it is tall enough for both)
	local max_w = math.min(RadialMenu.WIDTH_MAX, (area.Width - 2 * PAD - (cols - 1) * GAP) / cols)
	w = math.min(w, max_w)
	local card_w = 2 * PAD + cols * w + (cols - 1) * GAP
	local card_h = 2 * PAD + head + tallest
	self._card_size = Vector2.new(card_w, card_h)
	local tl = RadialMenu.placement(self.center, card_w, card_h, area, PAD + head + (rows[1] ~= nil and rows[1].height or 0) * 0.5)
	-- (off Roblox's corner when there is room below it; a list as tall as the screen may run under its buttons)
	local rtl = ctx.reserved_top_left
	if rtl ~= nil and tl.X < rtl.Max.X and tl.Y < rtl.Max.Y and rtl.Max.Y + card_h <= area.Max.Y then
		tl = Vector2.new(tl.X, rtl.Max.Y)
	end
	self._card_rect = Rect.new(tl.X, tl.Y, tl.X + card_w, tl.Y + card_h)
	local card = self._card
	card.Position = UDim2.fromOffset(tl.X, tl.Y)
	card.Size = UDim2.fromOffset(card_w, card_h)
	card.Visible = true
	-- the head: whose land
	self._title.Visible = not self._in_sub
	self._title.Text = self.title
	self._title.TextColor3 = self.title_color
	self._title.Position = UDim2.fromOffset(PAD + 8, PAD)
	self._title.Size = UDim2.fromOffset(card_w - 2 * PAD - 16, RadialMenu.HEAD_H)
	self._title.TextYAlignment = Enum.TextYAlignment.Center
	self._head_sub.Visible = has_sub
	if has_sub then
		self._head_sub.Text = self.head_sub
		self._head_sub.Position = UDim2.fromOffset(PAD + 8, PAD + RadialMenu.HEAD_H - 4)
		self._head_sub.Size = UDim2.fromOffset(card_w - 2 * PAD - 16, RadialMenu.HEAD_SUB_H)
	end
	-- the rows
	for i, r in rows do
		local fl = flow[i]
		local x = PAD + (fl.col - 1) * (w + GAP)
		local y = PAD + head + fl.y
		r.x, r.y, r.w = x, y, w
		r.rect = Rect.new(tl.X + x, tl.Y + y, tl.X + x + w, tl.Y + y + r.height)
	end
	for i = #rows + 1, #self._pool do
		self._pool[i].frame.Visible = false
	end
	self:_paint()
end

--- Colours, icons and text of every row (the hover moved, or the rows changed).
function RadialMenu._paint(self: any)
	local Th = T()
	for i, r in self._rows do
		local p = self:_row_parts(i)
		local hov = i == self._hover
		local ok = r.back or r.item.ok == true
		local danger = not r.back and r.item.danger == true
		local big = r.big == true
		-- fill
		local fill, fill_a = Th.WHITE, 0.0
		if big then
			fill, fill_a = (if danger then Th.RED else Th.AMBER), 1.0
		elseif hov and ok then
			fill, fill_a = (if danger then Th.RED else Th.WHITE), (if danger then 1.0 else 0.12)
		end
		if big and hov then
			fill = if danger then Th.SURRENDER_RED_HI else Th.AMBER_HI
		end
		local on_fill = big or (hov and ok and danger)
		local col = if not ok then Th.TEXT_3 elseif on_fill then (if danger then Th.WHITE else Th.INK) elseif danger then Th.RED else Th.TEXT
		local f = p.frame
		f.Visible = true
		f.Position = UDim2.fromOffset(r.x, r.y)
		f.Size = UDim2.fromOffset(r.w, r.height)
		f.BackgroundColor3 = fill
		f.BackgroundTransparency = 1 - fill_a
		Th.set_image(p.icon, Th.icon(if r.back then "chevron" else tostring(r.item.icon or "info")))
		p.icon.Rotation = if r.back then 90 else 0
		p.icon.ImageColor3 = col
		p.icon.ImageTransparency = if ok then 0 else 0.45
		-- text
		local px = if big then RadialMenu.TOP_LABEL_PX else RadialMenu.LABEL_PX
		local left = 8 + ICON + 8
		local has_more = not r.back and r.item.sub ~= nil and ok
		local right = if has_more then 24 else 10
		local room = r.w - left - right
		local side = r.detail == "" or r.lw + 14 + r.dw <= room
		p.label.FontFace = Th.font(if big then 800 else 700)
		p.label.TextSize = text_px(px)
		p.label.TextColor3 = col
		p.label.Text = r.label
		p.detail.Visible = r.detail ~= ""
		p.detail.FontFace = Th.font(600)
		p.detail.TextSize = text_px(RadialMenu.DETAIL_PX)
		p.detail.Text = r.detail
		p.detail.TextColor3 = if on_fill then col elseif not ok then Th.TEXT_2 elseif r.item ~= nil and r.item.cost ~= nil then Th.GOLD else Th.TEXT_2
		if side then
			p.label.TextYAlignment = Enum.TextYAlignment.Center
			p.label.Position = UDim2.fromOffset(left, 0)
			p.label.Size = UDim2.fromOffset(if r.detail == "" then room else r.lw + 2, r.height)
			p.detail.TextXAlignment = Enum.TextXAlignment.Right
			p.detail.TextYAlignment = Enum.TextYAlignment.Center
			p.detail.Position = UDim2.fromOffset(left + r.lw + 4, 0)
			p.detail.Size = UDim2.fromOffset(math.max(0, room - r.lw - 4), r.height)
		else
			-- one above the other
			local lh, dh = text_px(px), text_px(RadialMenu.DETAIL_PX)
			local top = math.max(0, (r.height - lh - dh) * 0.5)
			p.label.TextYAlignment = Enum.TextYAlignment.Top
			p.label.Position = UDim2.fromOffset(left, top)
			p.label.Size = UDim2.fromOffset(room, lh)
			p.detail.TextXAlignment = Enum.TextXAlignment.Left
			p.detail.TextYAlignment = Enum.TextYAlignment.Top
			p.detail.Position = UDim2.fromOffset(left, top + lh)
			p.detail.Size = UDim2.fromOffset(room, dh)
		end
		p.more.Visible = has_more
		if has_more then
			Th.set_image(p.more, Th.icon("chevron"))
			p.more.ImageColor3 = col
		end
	end
end

return RadialMenu
