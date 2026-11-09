--!nonstrict
-- The Council: a sheet (UI/Sheet) with what you can change on one side and what you can do on the other, on the title and
-- in a war. No separate settings page and no resume row: the sheet's back arrow goes back to the war. What can't be undone
-- asks first, in place.
--
-- (`page`: UIRoot's gear asks for "settings" on the title and the top bar's menu for "menu" in a match. It is the same
-- sheet; the word only says what closed it.)

local UITheme = require("./UITheme")
local W = require("./Widgets")
local Sheet = require("./Sheet")
local UICtx = require("./UICtx")
local Scroll = (require("./HelpOverlay") :: any).Scroll
local Signal = UITheme.core("Signal")
local Defs = UICtx.core("Defs")
local UserInputService = game:GetService("UserInputService")

local PauseMenu = W.class(W.Control)

-- =============================================================================================
-- Switch (a row button with an animated toggle on the right)
-- =============================================================================================

local Switch = W.class(W.Button)
PauseMenu.Switch = Switch

function Switch.new(text: string, icon_name: string)
	local self = setmetatable({}, Switch.__mt)
	W.Control._init(self, "TextButton")
	W.Button._init_button(self, "", "GlassButton")
	self.on = false
	self._k = 0.0
	self:set_min_size(Vector2.new(0, 46))
	local normal = UITheme.flat(UITheme.FILL, UITheme.R_MD, UITheme.LINE, 1)
	local hover = UITheme.flat(UITheme.FILL_2, UITheme.R_MD, UITheme.LINE, 1)
	self:add_theme_stylebox_override("normal", normal)
	self:add_theme_stylebox_override("pressed", normal)
	self:add_theme_stylebox_override("disabled", normal)
	self:add_theme_stylebox_override("hover", hover)
	self:add_theme_stylebox_override("hover_pressed", hover)
	local h = UITheme.hbox(12)
	h:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	h.offset_left = 14.0
	h.offset_right = -70.0
	self:add_child(h)
	local ic = UITheme.icon_rect(icon_name, 18.0, UITheme.TEXT_2)
	ic.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(ic)
	local l = UITheme.label(text, 14, 600)
	l.size_flags_vertical = W.SHRINK_CENTER
	-- (the row's free width, not the measured one: at 14 px the drawn words ran a few px past it; 2026-11-08 scan)
	l.size_flags_horizontal = W.EXPAND_FILL
	h:add_child(l)
	-- Track + knob (drawn parts).
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.ZIndex = 6
	track.Parent = self.gui
	self._track_corner = Instance.new("UICorner")
	self._track_corner.Parent = track
	self._track = track
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = UITheme.WHITE
	knob.ZIndex = 7
	knob.Parent = self.gui
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(0, UITheme.R_SM)
	kc.Parent = knob
	self._knob = knob
	self:_part(knob, "BackgroundTransparency", 1.0)
	self.pressed:Connect(function()
		self:set_on(not self.on)
	end)
	self:_draw_switch()
	return self
end

function Switch.set_on(self, v: boolean)
	self.on = v
	self:set_process(true)
end

function Switch._process(self, delta: number)
	local target = if self.on then 1.0 else 0.0
	if math.abs(self._k - target) > 1e-4 then
		self._k = Defs.move_toward(self._k, target, delta * 8.0)
		self:_draw_switch()
	else
		self:set_process(false)
	end
end

function Switch._draw(self)
	self:_draw_switch()
end

function Switch._draw_switch(self)
	local s = UITheme.scale
	local k = self._k
	local tw, th = 40.0, 22.0
	local track = self._track
	track.Position = UDim2.new(1, -math.floor(14 * s + 0.5), 0.5, 0)
	track.Size = UDim2.fromOffset(math.floor(tw * s + 0.5), math.floor(th * s + 0.5))
	self._track_corner.CornerRadius = UDim.new(0, math.floor(UITheme.R_SM * s + 0.5))
	local col = UITheme.lerp(UITheme.rgba(1, 1, 1, 0.14), UITheme.to_rgba(UITheme.AMBER), k)
	track.BackgroundColor3 = UITheme.color3(col)
	self:_part(track, "BackgroundTransparency", UITheme.alpha(col))
	local kx = (-14 - tw + 11) + (tw - 22) * k
	self._knob.Position = UDim2.new(1, math.floor(kx * s + 0.5), 0.5, 0)
	self._knob.Size = UDim2.fromOffset(math.floor(16 * s + 0.5), math.floor(16 * s + 0.5))
end

-- =============================================================================================
-- VolumeRow (a row like a Switch with a slider on the right: the music's level)
-- =============================================================================================

--- A music volume slider (2026-10-21). It began as a Music switch with a Volume row under it; two rows
--- were one too many, so it is one row as a Switch's
--- (icon and label on the left), with Tribes' slider on the right: a track and the value in a fixed column.
--- Tap or drag the track (the grab area is the row's right part, its full height), or the mouse wheel over
--- the row; `changed(v, final)`: v in 0..1, final once the finger lifts (save then).
local VolumeRow = W.class(W.Control)
PauseMenu.VolumeRow = VolumeRow
--- Logical px: the room the icon and label keep on the left, the gap at the right, the value's column,
--- the gap before it, and the track's limits (it takes the room left between).
VolumeRow.LEFT_W = 112.0
VolumeRow.RIGHT = 14.0
VolumeRow.PCT_W = 40.0
VolumeRow.GAP = 10.0
VolumeRow.TRACK_MIN = 80.0
VolumeRow.TRACK_MAX = 170.0
--- A wheel notch moves it this much.
VolumeRow.WHEEL_STEP = 0.05

local FONT_PCT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

function VolumeRow.new(text: string, icon_name: string)
	local self = setmetatable({}, VolumeRow.__mt)
	W.Control._init(self)
	self.gui.Name = "MusicVolume"
	--- (set by the menu: a tick as the value steps)
	self.ctx = nil :: any
	self.value = 1.0
	self.changed = Signal.new()
	self._drag = false
	self:set_min_size(Vector2.new(0, 46))
	self:set_mouse_filter(W.MOUSE_STOP)
	local g = self.gui
	local bg = Instance.new("Frame")
	bg.Name = "Bg"
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = UITheme.WHITE
	bg.Size = UDim2.fromScale(1, 1)
	bg.ZIndex = 4
	bg.Parent = g
	self._bg_corner = Instance.new("UICorner")
	self._bg_corner.Parent = bg
	local stroke = Instance.new("UIStroke")
	stroke.Color = UITheme.WHITE
	stroke.Parent = bg
	-- (a Switch's look: 4% white, 7% under the mouse, a 8% line)
	self:_part(bg, "BackgroundTransparency", 0.04)
	self:_part(stroke, "Transparency", 0.08)
	self:_connect(g.MouseEnter:Connect(function()
		self:_part(bg, "BackgroundTransparency", 0.07)
	end))
	self:_connect(g.MouseLeave:Connect(function()
		self:_part(bg, "BackgroundTransparency", 0.04)
	end))
	local h = UITheme.hbox(12)
	h:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	h.offset_left = 14.0
	h.offset_right = -(VolumeRow.RIGHT + VolumeRow.PCT_W + VolumeRow.GAP + VolumeRow.TRACK_MIN)
	h:set_mouse_filter(W.MOUSE_IGNORE)
	self:add_child(h)
	local ic = UITheme.icon_rect(icon_name, 18.0, UITheme.TEXT_2)
	ic.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(ic)
	local l = UITheme.label(text, 14, 600)
	l.size_flags_vertical = W.SHRINK_CENTER
	-- (the row's free width, not the measured one: at 14 px the drawn words ran a few px past it; 2026-11-08 scan)
	l.size_flags_horizontal = W.EXPAND_FILL
	h:add_child(l)
	local function part(name: string, z: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, 0.5)
		f.ZIndex = z
		f.Parent = g
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, UITheme.R_SM)
		c.Parent = f
		return f
	end
	self._track = part("VolTrack", 6)
	self._fill = part("VolFill", 7)
	self._knob = part("VolKnob", 8)
	self._knob.AnchorPoint = Vector2.new(0.5, 0.5)
	self._knob.BackgroundColor3 = UITheme.WHITE
	local ks = Instance.new("UIStroke")
	ks.Color = Color3.fromRGB(120, 72, 8)
	ks.Thickness = 2
	ks.Parent = self._knob
	self:_part(self._knob, "BackgroundTransparency", 1.0)
	self:_part(ks, "Transparency", 0.9)
	self:_part(self._fill, "BackgroundTransparency", 1.0)
	local pct = Instance.new("TextLabel")
	pct.Name = "VolPct"
	pct.BackgroundTransparency = 1
	pct.AnchorPoint = Vector2.new(1, 0.5)
	pct.FontFace = FONT_PCT
	pct.TextXAlignment = Enum.TextXAlignment.Right
	pct.TextColor3 = UITheme.color3(UITheme.to_rgba(UITheme.TEXT_2))
	pct.Text = "100%"
	pct.ZIndex = 6
	pct.Parent = g
	self:_part(pct, "TextTransparency", 1.0)
	self._pct = pct
	self:_connect(g.InputBegan:Connect(function(io: InputObject)
		local t = io.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			local x = self:_local_x(io)
			if x >= self:_track_x() - 18.0 then
				self._drag = true
				self._drag_input = io
				self:_set_from_x(x, false)
				self:_draw_row()
			end
		end
	end))
	self:_connect(g.InputChanged:Connect(function(io: InputObject)
		if io.UserInputType == Enum.UserInputType.MouseWheel and io.Position.Z ~= 0 then
			local v = math.clamp(self.value + VolumeRow.WHEEL_STEP * math.sign(io.Position.Z), 0.0, 1.0)
			self:_set(math.floor(v * 20 + 0.5) / 20, true)
		end
	end))
	self:_connect(UserInputService.InputChanged:Connect(function(io: InputObject)
		if not self._drag then
			return
		end
		local t = io.UserInputType
		if t == Enum.UserInputType.MouseMovement or (t == Enum.UserInputType.Touch and io == self._drag_input) then
			self:_set_from_x(self:_local_x(io), false)
		end
	end))
	self:_connect(UserInputService.InputEnded:Connect(function(io: InputObject)
		if not self._drag then
			return
		end
		local t = io.UserInputType
		if t == Enum.UserInputType.MouseButton1 or (t == Enum.UserInputType.Touch and io == self._drag_input) then
			self._drag = false
			self._drag_input = nil
			self:_draw_row()
			self.changed:Fire(self.value, true)
		end
	end))
	self:_draw_row()
	return self
end

--- The pointer's x in the row (logical px).
function VolumeRow._local_x(self, io: InputObject): number
	return W.screen_to_logical(W.input_pos(io), self).X - self:get_global_position().X
end

--- The track's width: the room the row leaves after the icon and label and the value (logical px).
function VolumeRow._track_w(self): number
	local room = self.size.X - VolumeRow.LEFT_W - (VolumeRow.RIGHT + VolumeRow.PCT_W + VolumeRow.GAP)
	return math.clamp(room, VolumeRow.TRACK_MIN, VolumeRow.TRACK_MAX)
end

--- The track's left edge in the row (logical px).
function VolumeRow._track_x(self): number
	return self.size.X - VolumeRow.RIGHT - VolumeRow.PCT_W - VolumeRow.GAP - self:_track_w()
end

function VolumeRow._set_from_x(self, x: number, final: boolean)
	local v = math.clamp((x - self:_track_x()) / self:_track_w(), 0.0, 1.0)
	self:_set(math.floor(v * 20 + 0.5) / 20, final) -- (steps of 5%)
end

function VolumeRow._set(self, v: number, final: boolean)
	if v ~= self.value or final then
		if v ~= self.value and self.ctx ~= nil then
			self.ctx:sfx("ui_click", -10.0, 0, 0.8 + v * 0.6) -- (a tick per step, as Tribes', higher as it rises)
		end
		self:set_value(v)
		self.changed:Fire(self.value, final)
	end
end

--- Show `v` (0..1) without firing changed.
function VolumeRow.set_value(self, v: number)
	self.value = math.clamp(tonumber(v) or 1.0, 0.0, 1.0)
	self._pct.Text = string.format("%d%%", math.floor(self.value * 100 + 0.5))
	self:_draw_row()
end

function VolumeRow._on_geometry(self)
	self:_draw_row()
end

function VolumeRow._draw(self)
	self:_draw_row()
end

-- (raw instances in px: logical px x UITheme.scale)
function VolumeRow._draw_row(self)
	local sc = UITheme.scale
	local px = function(v: number): number
		return math.floor(v * sc + 0.5)
	end
	self._bg_corner.CornerRadius = UDim.new(0, px(UITheme.R_MD))
	local tw = self:_track_w()
	local from_right = VolumeRow.RIGHT + VolumeRow.PCT_W + VolumeRow.GAP + tw
	local th = 6.0
	self._track.Position = UDim2.new(1, -px(from_right), 0.5, 0)
	self._track.Size = UDim2.fromOffset(px(tw), px(th))
	local tcol = UITheme.rgba(1, 1, 1, 0.14)
	self._track.BackgroundColor3 = UITheme.color3(tcol)
	self:_part(self._track, "BackgroundTransparency", UITheme.alpha(tcol))
	local fw = tw * self.value
	self._fill.Visible = fw > 0.5
	self._fill.Position = UDim2.new(1, -px(from_right), 0.5, 0)
	self._fill.Size = UDim2.fromOffset(px(math.max(fw, th)), px(th))
	self._fill.BackgroundColor3 = UITheme.color3(UITheme.to_rgba(UITheme.AMBER))
	self._knob.Position = UDim2.new(1, -px(from_right - fw), 0.5, 0)
	local k = if self._drag then 19 else 16
	self._knob.Size = UDim2.fromOffset(px(k), px(k))
	self._pct.Position = UDim2.new(1, -px(VolumeRow.RIGHT), 0.5, 0)
	self._pct.Size = UDim2.fromOffset(px(VolumeRow.PCT_W), px(20))
	self._pct.TextSize = math.max(px(13), 8)
end

-- =============================================================================================
-- The Council
-- =============================================================================================

--- The sheet's body on a desktop, and the gap between its columns on a phone.
PauseMenu.WIDTH = 380
PauseMenu.GAP = 12

function PauseMenu.new(c: any)
	local self = setmetatable({}, PauseMenu.__mt)
	W.Control._init(self)
	self.ctx = c
	self.closed = Signal.new()
	self.help_requested = Signal.new()
	--- the War College's row (in a match: the build wheel is all orders)
	self.college_requested = Signal.new()
	self.leave_requested = Signal.new()
	self.labels_toggled = Signal.new()
	self.music_toggled = Signal.new()
	--- (v 0..1, final): the music volume slider; final once the drag ends (UIRoot saves then)
	self.music_volume_changed = Signal.new()
	self.pops_toggled = Signal.new()
	--- (on) the "always hide the match log" switch (UI/LogPanel.set_hidden)
	self.log_hidden_toggled = Signal.new()
	self.restart_requested = Signal.new()
	self.tips_reset = Signal.new()
	--- Staging, and game admins: "Train again" was pressed and confirmed
	self.new_player_requested = Signal.new()
	self.is_open = false
	self._page = "menu"
	self._layout_compact = -1
	self._confirm_action = ""
	local T = UITheme
	local v, head = Sheet.attach(self, "COUNCIL")
	self._sub = T.label("", 13, 500, T.TEXT_2)
	self._sub.size_flags_horizontal = W.EXPAND_FILL
	self._sub.size_flags_vertical = W.SHRINK_CENTER
	head:add_child(self._sub)
	-- what you can change, and what you can do: one column on a desktop, side by side on a phone (short screens)
	self._scroll = Scroll.new()
	self._scroll.size_flags_vertical = W.EXPAND_FILL
	v:add_child(self._scroll)
	self._main = T.hbox(PauseMenu.GAP)
	self._main.size_flags_horizontal = W.EXPAND_FILL
	self._scroll:add_child(self._main)
	self._col_a = T.vbox(8)
	self._col_a.size_flags_horizontal = W.EXPAND_FILL
	self._col_b = T.vbox(8)
	self._col_b.size_flags_horizontal = W.EXPAND_FILL
	self._main:add_child(self._col_a)
	self._main:add_child(self._col_b)
	-- Music: one slider row (0% = off), as Tribes' settings. Music stays on/off underneath (the top bar's
	-- button and M toggle it): 0% is silent at once and switches it off when the finger lifts, any level
	-- above switches it on, and the level saved and kept for the button is the last one above 0.
	self._music = VolumeRow.new("Music", "music_on")
	self._music.ctx = c
	self._music_on = true
	self._music_keep = 1.0
	self._music.changed:Connect(function(val: number, final: boolean)
		if val <= 0 then
			self.music_volume_changed:Fire(0, false)
			if final and self._music_on then
				self._music_on = false
				self.music_toggled:Fire(false)
			end
			return
		end
		self.music_volume_changed:Fire(val, final)
		if final then
			self._music_keep = val
		end
		if not self._music_on then
			self._music_on = true
			self.music_toggled:Fire(true)
		end
	end)
	-- Effects: every sound but the music, one slider (release 2026-11-07: alarms and blasts could only be silenced with
	-- the music)
	self._sfx = VolumeRow.new("Effects", "atom")
	self._sfx.ctx = c
	self._sfx.changed:Connect(function(val: number, final: boolean)
		c:set_sfx_volume(val, final)
	end)
	self._pops = Switch.new("Land-taking sound", "pops")
	self._pops.pressed:Connect(function()
		self.pops_toggled:Fire(self._pops.on)
	end)
	self._labels = Switch.new("Nation names on the map", "layers")
	self._labels.pressed:Connect(function()
		self.labels_toggled:Fire(self._labels.on)
	end)
	self._log_sw = Switch.new("Always hide the match log", "log")
	self._log_sw.pressed:Connect(function()
		self.log_hidden_toggled:Fire(self._log_sw.on)
	end)
	self._confirm_sw = Switch.new("Confirm each attack on its card", "target")
	self._confirm_sw.pressed:Connect(function()
		self.ctx:set_setting(self:_confirm_key(), self._confirm_sw.on)
	end)
	local function act(text: string, icon: string): any
		local b = T.button(text, "GlassButton", icon, 46.0)
		b.alignment = W.ALIGN_LEFT
		b:set_font_size(14)
		return b
	end
	self._help_btn = act("Field Guide", "help")
	self._help_btn.pressed:Connect(function()
		self:close()
		self.help_requested:Fire()
	end)
	self._college = act("War College", "arsenal")
	self._college.pressed:Connect(function()
		self:close()
		self.college_requested:Fire()
	end)
	self._tips = act("Hear Counsel's tips again", "info")
	self._tips.pressed:Connect(function()
		self.tips_reset:Fire()
		self._tips:set_text("They'll come again")
		self._tips:set_disabled(true)
	end)
	-- Staging (and Studio), and game admins on production (2026-10-27): be a new player again, to see the tutorial and every
	-- other first-time thing. Asked first: it ends the war being played, and on production it is a real account's war count.
	self._new_player = act("Train again from the start", "retreat")
	self._new_player.pressed:Connect(function()
		self:_ask_new_player()
	end)
	self._new_player:set_visible(false)
	self._restart = act("Fresh world", "retreat")
	self._restart.pressed:Connect(function()
		self:_ask_restart()
	end)
	self._leave = T.button("LEAVE WAR", "SurrenderButton", "exit", 46.0)
	self._leave.pressed:Connect(function()
		self:_ask_leave()
	end)
	-- asking first, in place of the rows
	self._confirm = T.vbox(12)
	self._confirm:set_visible(false)
	v:add_child(self._confirm)
	self._confirm_text = T.label("", 14, 500, T.TEXT)
	self._confirm_text:set_autowrap(true)
	self._confirm:add_child(self._confirm_text)
	local row = T.hbox(10)
	local cancel = T.button("Not yet", "GlassButton", "", 46.0)
	cancel.size_flags_horizontal = W.EXPAND_FILL
	cancel.pressed:Connect(function()
		self._confirm:set_visible(false)
		self._scroll:set_visible(true)
	end)
	row:add_child(cancel)
	self._confirm_go = T.button("Go", "SurrenderButton", "exit", 46.0)
	self._confirm_go.size_flags_horizontal = W.EXPAND_FILL
	self._confirm_go.pressed:Connect(function()
		self:close()
		if self._confirm_action == "restart" then
			self.restart_requested:Fire()
		elseif self._confirm_action == "new_player" then
			self.new_player_requested:Fire()
		else
			self.leave_requested:Fire()
		end
	end)
	row:add_child(self._confirm_go)
	self._confirm:add_child(row)
	self:_reflow(false)
	return self
end

--- Puts the question in place of the rows.
function PauseMenu._ask(self, action: string, text: string, go: string, icon: string)
	self._confirm_action = action
	self._confirm_text:set_text(text)
	self._confirm_go:set_text(go)
	self._confirm_go:set_icon(icon)
	self._scroll:set_visible(false)
	self._confirm:set_visible(true)
end

function PauseMenu._ask_restart(self)
	self:_ask("restart", "Give up this war and start on a fresh world?", "Fresh world", "retreat")
end

function PauseMenu._ask_new_player(self)
	self:_ask(
		"new_player",
		"Go through the training again? Your war count starts over"
			.. (if self.ctx:in_match() then " and this one is over." else ".")
			.. " Nothing you own is lost.",
		"Train again",
		"retreat"
	)
end

function PauseMenu._ask_leave(self)
	local ctx = self.ctx
	if not ctx:in_match() then
		self:close()
		self.leave_requested:Fire()
		return
	end
	local o = ctx:my()
	local mp = ctx:mode() == UICtx.MODE_MULTI
	if o ~= nil and o.alive and ctx.state ~= nil and ctx.state.phase == Defs.PHASE_PLAYING then
		self:_ask(
			"leave",
			"Yield your nation? " .. (if mp then "It stays on the map with nobody to lead it." else "You lose this war."),
			"Yield",
			"exit"
		)
	else
		self:_ask("leave", "Leave this war for the title?", "Leave", "exit")
	end
end

--- `page`: "settings" (the gear on the title), else "menu".
function PauseMenu.open(self, labels_on: boolean, page: string?)
	if self.is_open then
		return
	end
	local ctx = self.ctx
	self.is_open = true
	self._page = if page == "settings" then "settings" else "menu"
	self._labels.on = labels_on
	self._labels._k = if labels_on then 1.0 else 0.0
	self._labels:_draw_switch()
	self._music_on = ctx:music_enabled()
	if ctx:music_volume() > 0 then
		self._music_keep = ctx:music_volume()
	end
	self._music:set_value(if self._music_on then ctx:music_volume() else 0)
	self._sfx:set_value(ctx:sfx_volume())
	self._pops.on = ctx:pops_enabled()
	self._pops._k = if self._pops.on then 1.0 else 0.0
	self._pops:_draw_switch()
	local cs = if ctx.touch
		then ctx:setting(self:_confirm_key(), ctx.touch_device or ctx.touch)
		else ctx:setting(self:_confirm_key(), false)
	self._confirm_sw.on = cs == true
	self._confirm_sw._k = if self._confirm_sw.on then 1.0 else 0.0
	self._confirm_sw:_draw_switch()
	self._log_sw.on = ctx:setting("log_hidden", false) == true
	self._log_sw._k = if self._log_sw.on then 1.0 else 0.0
	self._log_sw:_draw_switch()
	local mp = ctx:mode() == UICtx.MODE_MULTI
	local on_title = not ctx:in_match()
	local diff = { [0] = "Recruit", "Veteran", "Warlord" }
	local d =
		math.clamp(tonumber(ctx:setting("difficulty", UICtx.DEFAULT_DIFFICULTY)) or UICtx.DEFAULT_DIFFICULTY, 0, 2)
	if on_title then
		self._sub:set_text(if ctx:mp_waiting() then "In line for the next open war" else "")
	else
		self._sub:set_text(if mp then "Open war" else string.format("Campaign  ·  %s  ·  paused", diff[d]))
	end
	self._restart:set_visible(not mp and not on_title)
	self._labels:set_visible(not on_title)
	self._confirm_sw:set_visible(not on_title)
	-- (a phone keeps its log in Your war: the switch would do nothing there; audit 2026-11-06)
	self._log_sw:set_visible(not ctx.compact)
	self._tips:set_text("Hear Counsel's tips again")
	self._tips:set_disabled(false)
	self._new_player:set_visible(ctx.staging == true or ctx:admin())
	local o = ctx:my()
	local alive = o ~= nil and o.alive and ctx.state ~= nil and ctx.state.phase == Defs.PHASE_PLAYING
	self._leave:set_visible(not on_title or ctx:mp_waiting())
	if on_title then
		self._leave:set_text("STEP AWAY")
	else
		self._leave:set_text(if alive then "YIELD" else "LEAVE WAR")
	end
	self._scroll:set_visible(true)
	self._confirm:set_visible(false)
	self:apply_layout()
	Sheet.show(self)
end

--- Separate settings for touch and mouse (UIInteract.confirm_orders reads the same keys).
function PauseMenu._confirm_key(self): string
	return if self.ctx.touch then "confirm_orders" else "confirm_orders_desktop"
end

function PauseMenu.sync_music(self, on: boolean)
	self._music_on = on
	if on and self.ctx:music_volume() <= 0 then
		-- (back on from the top bar or M after the slider went to 0: the last level above 0)
		self.ctx:set_music_volume(self._music_keep, false)
	end
	self._music:set_value(if on then self.ctx:music_volume() else 0)
end

function PauseMenu.sync_pops(self, on: boolean)
	self._pops:set_on(on)
end

--- What the sheet was last asked for: "menu" or "settings".
function PauseMenu.page(self): string
	return self._page
end

--- The gear pressed over the open sheet: it is all one page, and a second press closes it.
function PauseMenu.show_settings(self)
	self._page = "settings"
end

function PauseMenu.close(self)
	if not self.is_open then
		return
	end
	self.is_open = false
	Sheet.hide(self)
	self.closed:Fire()
end

function PauseMenu.apply_layout(self)
	local compact = self.ctx.compact == true
	self:_reflow(compact)
	local m = Sheet.place(self, PauseMenu.WIDTH)
	self._confirm_text:set_min_size(Vector2.new(m.body_w, 0))
end

--- One column on a desktop, two side by side on a phone.
function PauseMenu._reflow(self, compact: boolean)
	local want = if compact then 1 else 0
	if want == self._layout_compact then
		return
	end
	self._layout_compact = want
	for _, cc in ipairs({ self._music, self._sfx, self._pops, self._labels, self._log_sw, self._confirm_sw, self._help_btn, self._college, self._tips, self._new_player, self._restart, self._leave }) do
		if cc:get_parent() ~= nil then
			cc:get_parent():remove_child(cc)
		end
		cc:set_min_size(Vector2.new(0, if compact then 44.0 else 46.0))
	end
	local a = { self._music, self._sfx, self._pops, self._labels, self._log_sw, self._confirm_sw }
	local b = { self._help_btn, self._college, self._tips, self._new_player, self._restart, self._leave }
	self._main.vertical = not compact
	self._main:update_minimum_size()
	for _, c2 in ipairs(a) do
		self._col_a:add_child(c2)
	end
	for _, c3 in ipairs(b) do
		self._col_b:add_child(c3)
	end
end

return PauseMenu
