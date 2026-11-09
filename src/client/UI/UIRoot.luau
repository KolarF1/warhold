--!nonstrict
-- Port of scripts/ui/ui_root.gd (UIRoot)
-- AIRFRONT interface root. Built entirely in code: title screen, spawn banner, the match's HUD (the strategy frame,
-- 2026-11-03: the top strip, the alert row, World Tension, the outliner, the war clock, the selection window, the Build
-- window and a phone's thumbs; UI/FrameRules holds where each stands), tooltips, the order card, help, game menu and the
-- victory / defeat screen. Wire with setup(session, world, audio) (DESIGN.md §10).
--
-- Roblox: one ScreenGui "AirfrontUI" (DisplayOrder 10, above the map-label layer at 0; below
-- Main's top bar at 50) holding a Widgets.Root (the kit's Godot-like node tree, logical px with
-- one UI scale). One render-step loop (after the camera) runs every per-frame update, then the
-- kit's tweens / layout (Widgets.step). Main owns M / Home and the top-bar buttons.

local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")
local UIInteract = require("./UIInteract")
local Telemetry = require("./Telemetry")
local MusicMood = require("../Audio/MusicMood")
local UIAdvisor = require("./UIAdvisor")
local UILayoutProbe = require("./UILayoutProbe")
local HudCoverage = require("./HudCoverage")
local TouchRouter = require("./TouchRouter")
local TitleScreen = require("./TitleScreen")
local SpawnOverlay = require("./SpawnOverlay")
local GameOver = require("./GameOver")
local Takeover = require("./Takeover")
local Locker = require("./Locker")
local CommandCenter = require("./CommandCenter")
local WarReport = require("./WarReport")
local RealmSheet = require("./RealmSheet")
local MatchLog = require("./MatchLog")
local Arsenal = require("./Arsenal")
local StarterOffer = require("./StarterOffer")
local GeneralOffer = require("./GeneralOffer")
local FlagShop = require("./FlagShop")
local ShopHub = require("./ShopHub")
local ArsenalData: any = if typeof(game) == "Instance"
	then require((game :: any):GetService("ReplicatedStorage"):WaitForChild("Airfront").Data.Arsenal)
	else (require :: any)("../../shared/Data/Arsenal")
local CrateOpening = require("./CrateOpening")
local CrateOdds = require("./CrateOdds")
local HelpOverlay = require("./HelpOverlay")
local PauseMenu = require("./PauseMenu")
local MapPicker = require("./MapPicker")
local UIMaps = require("./UIMaps")
local RotateCard = require("./RotateCard")
local Tooltip = require("./Tooltip")
local RadialMenu = require("./RadialMenu")
local HoldRing = require("./HoldRing")
local Tutorial = require("./Tutorial")
local TutorialData = UICtx.data("Tutorial")
local TargetCard = require("./TargetCard")
local CursorReadout = require("./CursorReadout")
local FrameRules = require("./FrameRules")
local NewsLog = require("./NewsLog")
local ListPopup = require("./ListPopup")
local UnitCard = require("./UnitCard")
local PlaceConfirm = require("./PlaceConfirm")
local Coach = require("./Coach")
local Signal = UITheme.core("Signal")
local Defs = UICtx.core("Defs")

local UIRoot = {}
UIRoot.__index = UIRoot

--- Kit components by name (tests may override entries before UIRoot.new).
UIRoot.kit = {}
--- UIRoot.new waits at most this long for the Rubik weights before building (see _make_gui).
UIRoot.FONT_WAIT_S = 2.5
local function kit(name: string): any
	local k = UIRoot.kit[name]
	if k ~= nil then
		return k
	end
	-- (kept once required: _hook_buttons asks again on every slow poll, and a require late in a
	-- session can fail, UICtx.prime)
	return UICtx.mod(name)
end

function UIRoot.new(opts: any?)
	local self = setmetatable({}, UIRoot)
	opts = opts or {}
	-- the interface flies your banner's colour: the server sets it once your settings load, so wait a moment
	-- for it (a late answer keeps the default until the next visit; Studio: the attribute CTW_BANNER overrides)
	if typeof(game) == "Instance" then
		local player = game:GetService("Players").LocalPlayer
		local index = workspace:GetAttribute("CTW_BANNER")
		local waited = 0.0
		while index == nil and player ~= nil and waited < 1.5 do
			index = player:GetAttribute("Banner")
			if index == nil then
				waited += task.wait(0.1)
			end
		end
		-- (the banner colours your land; the interface keeps the HUD's one amber on every screen: release 2026-11-07)
		local _ = index
	end
	--- Emitted when the UI changes a setting that Main mirrors on a top-bar button.
	self.music_toggled = Signal.new()
	self.labels_toggled = Signal.new()
	self.leaderboard_toggled = Signal.new()
	self.help_toggled = Signal.new()
	--- "title", "spawn", "play" or "over".
	self.screen_changed = Signal.new()
	--- Test hooks: safe-area insets override (x < 0 = use the platform) and forced touch mode.
	self.debug_insets = opts.debug_insets or { x = -1, y = -1, z = -1, w = -1 }
	self.debug_touch = opts.debug_touch or -1
	--- Main may set this: function() -> Rect (viewport px) of its top-bar buttons.
	self.topbar_provider = nil
	self.ctx = UICtx.new()
	--- the soundtrack's mood (title / wait / calm / war / victory / defeat)
	self._music = MusicMood.new()
	--- Creator Dashboard milestones (server/Analytics)
	self.telemetry = Telemetry.new(self.ctx)
	self.ctx.telemetry = self.telemetry
	self.labels_on = true
	self._screen = ""
	self._conns = {}
	self._sconns = {}
	self._apply_pending = false
	self._poll = 0.0
	self._siren_on = false
	self._last_vp = Vector2.zero
	self._last_insets = { x = 0, y = 0, z = 0, w = 0 }
	self._stats = {}
	self._elim_timer = nil
	self._reserved_probe = Rect.new(0, 0, 0, 0)
	self._chat_probe = Rect.new(0, 0, 0, 0)
	self._world_safe = Rect.new(-1, -1, -1, -1)
	--- Transient nodes registered with add_hud_control (banners).
	self._extra_hud = {}
	self._relayout_pending = false
	self._building = false
	--- A solo restart ("Play again" / "Restart match") is building: the old match stays frozen.
	self._restart_pending = false
	self._solo_msec = -100000
	self._threat_poll = 0.0
	self._hook_poll = 0.0
	self._theme = ""
	local ctx = self.ctx
	local UIS = if UICtx.IS_ROBLOX then game:GetService("UserInputService") else nil
	ctx.touch_device = UIS ~= nil and UIS.TouchEnabled and not UIS.MouseEnabled
	if opts.touch_device ~= nil then
		ctx.touch_device = opts.touch_device
	end
	ctx.touch = ctx.touch_device
	UITheme.touch_min = if ctx.touch then 44 else 0
	-- Roblox's accessibility settings: read now, and followed if the player changes them mid-game
	if UICtx.IS_ROBLOX then
		local GS = game:GetService("GuiService")
		local function sync_prefs()
			UITheme.reduced_motion = GS.ReducedMotionEnabled
			UITheme.preferred_transparency = GS.PreferredTransparency
		end
		sync_prefs()
		GS:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(sync_prefs)
		GS:GetPropertyChangedSignal("PreferredTransparency"):Connect(sync_prefs)
	end
	self.labels_on = ctx:setting("labels", true) ~= false
	self:_make_gui(opts.parent)
	self:_build()
	self:_layout()
	self:_apply_screen()
	return self
end

-- =============================================================================================
-- Public API (DESIGN.md §10)
-- =============================================================================================

function UIRoot.setup(self, session: any, world: any, audio: any)
	local ctx = self.ctx
	ctx.session = session
	ctx.world = world
	ctx:world_call("set_borders", { ctx.borders })
	ctx.audio = audio
	-- every button clicks when pressed and ticks under the pointer (the interface kit, Assets/AudioUI)
	W.button_sound = function(kind: string, _button: any)
		if kind == "hover" then
			if not ctx.touch then
				ctx:sfx("hover", -12.0, 0.03)
			end
		elseif kind == "tab" then
			ctx:sfx("tab", -3.0, 0.02)
		else
			ctx:sfx("click", -1.0, 0.03)
		end
	end
	if session ~= nil then
		ctx:reload_settings()
		self.labels_on = ctx:setting("labels", true) ~= false
		self:_sig(session, "state_ready", function(s)
			self:_on_state_ready(s)
		end)
		self:_sig(session, "mode_changed", function(_m)
			self:_request_apply()
		end)
		if self.locker ~= nil then
			self.locker:bind(session)
		end
		if self.arsenal ~= nil then
			self.arsenal:bind(session)
		end
		if self.starter ~= nil then
			self.starter:bind(session)
		end
		if self.general ~= nil then
			self.general:bind(session)
		end
		-- RoWorld General (Data/Subscription): the title's button and greeting, and what a day gave
		self:_sig(session, "general_changed", function(on: boolean, given: any)
			self.title:refresh_general()
			self:_on_general(on, given)
		end)
		if self.flag_shop ~= nil then
			self.flag_shop:bind(session)
		end
		if self.shop_hub ~= nil then
			self.shop_hub:bind(session)
		end
		-- an Arsenal unlock: the build slots open up; outside the Arsenal a toast says so
		self:_sig(session, "unlocked", function(key: string)
			self.bar:refresh_buttons()
			-- (a Founding Grant just bought says so once for its items)
			local pack = self.starter ~= nil and self.starter.bought_at ~= nil and os.clock() - self.starter.bought_at < 5
			if self.arsenal ~= nil and not self.arsenal.is_open and not pack then
				local it = ArsenalData.item(key)
				ctx:sfx("unlock")
				self:_on_notice((if it ~= nil then it.title else "War College item") .. " is yours.", 0)
			end
		end)
		self:_sig(session, "inventory_changed", function()
			self.bar:refresh_buttons()
			-- (the result screen's offers: what was just unlocked is no longer one)
		end)
		self:_sig(session, "hop_result", function(going: boolean)
			self:_on_hop_result(going)
		end)
		-- a match's Stars: the result screen counts them up
		self:_sig(session, "renown_claimed", function(total: any, _balance: any, mustered: any)
			local rest = (tonumber(total) or 0) - (tonumber(mustered) or 0)
			if rest > 0 then
				self:_on_notice(string.format("+%s Renown claimed", UICtx.commas(rest)), 0)
			end
			if self.command ~= nil and self.command.is_open then
				self.command:_rebuild()
			end
		end)
		self:_sig(session, "muster_claimed", function(step: number)
			local Claims = UICtx.data("Claims")
			local amount = Claims.MUSTER[step] or 0
			local text = string.format("Daily muster, day %d of %d: +%s Renown", step, #Claims.MUSTER, UICtx.commas(amount))
			local inv = if session.inventory ~= nil then session.inventory else {}
			if step == #Claims.MUSTER and inv.crates_allowed == true then
				text ..= ". A sealed Spoils waits in your Banners"
			elseif step == #Claims.MUSTER then
				text = string.format("Daily muster, day %d of %d: +%s Renown", step, #Claims.MUSTER, UICtx.commas(amount + Claims.MUSTER_GIFT_RENOWN))
			else
				text ..= string.format(". Tomorrow: +%s", UICtx.commas(Claims.MUSTER[step + 1]))
			end
			self:_on_notice(text, 0)
		end)
		self:_sig(session, "renown_held", function(why: string)
			self:_on_notice(
				if why == "cap"
					then "Today's Renown is all claimed: the rest waits for tomorrow."
					else "Play on: rewards are paid as your wars add up today.",
				0
			)
		end)
		self:_sig(session, "stars_awarded", function(award: any)
			if self.over ~= nil and self.over.is_open then
				self.over:set_award(award)
			end
		end)
		self:_sig(session, "credits_changed", function(_c)
			if self.takeover ~= nil then
				self.takeover:on_credits()
			end
		end)
		self:_sig(session, "credit_result", function(kind, ok, reason)
			if self.takeover ~= nil then
				self.takeover:on_result(kind, ok, reason)
			end
		end)
		self:_sig(session, "took_over", function(id)
			self:_on_took_over(id)
		end)
		self:_sig(session, "lobby_updated", function(info)
			self.title:set_lobby(info)
		end)
		-- public lobbies (hub servers): the game-wide list and join outcomes
		self:_sig(session, "admin_changed", function()
			self.board:mark_dirty()
			self.title:_refresh_greeting()
			ctx:world_call("set_admin_bots", { session.admin_bots })
		end)
		self:_sig(session, "returning_sig", function()
			if self.over.is_open then
				self.over:set_returning()
			end
		end)
		self:_sig(session, "lobbies_updated", function(list)
			self.title:set_lobbies(list, session.lobby_kinds)
		end)
		-- Quick Play: asking, in line, on the way (PUBLIC_STATE)
		self:_sig(session, "public_changed", function(st)
			self.title:set_public(st)
		end)
		-- parties (team games on: staging only for now)
		self:_sig(session, "party_changed", function(st)
			self.title:set_party(st)
		end)
		self:_sig(session, "join_failed", function(_reason)
			self.title:join_failed()
		end)
		self:_sig(session, "joined_owner", function(id)
			self:_on_joined_owner(id)
		end)
		self:_sig(session, "notice", function(text, severity)
			self:_on_notice(text, severity)
		end)
		self:_sig(session, "building_started", function(mode)
			self:_on_building(mode)
		end)
		self:_sig(session, "settings_loaded", function()
			self:_on_settings_loaded()
		end)
		if session.settings_ready == true then
			-- They arrived while the UI was still being built (Main starts the Session first).
			self:_on_settings_loaded()
		end
		if session.state ~= nil then
			self:_bind_state(session.state)
		end
		if type(session.lobby) == "table" then
			self.title:set_lobby(session.lobby)
		end
		if type(session.lobbies) == "table" then
			self.title:set_lobbies(session.lobbies, session.lobby_kinds)
		end
		if type(session.public) == "table" then
			self.title:set_public(session.public)
		end
		if type(session.party) == "table" then
			self.title:set_party(session.party)
		end
	end
	if world ~= nil then
		local inter = self.interact
		self:_sig(world, "tile_hovered", function(t)
			inter:on_hover(t)
		end)
		self:_sig(world, "tile_clicked", function(t)
			inter:on_click(t)
		end)
		self:_sig(world, "tile_context", function(t, pos)
			inter:on_context(t, if typeof(pos) == "Vector2" then ctx:to_logical(pos) else ctx:mouse_pos())
		end)
		ctx:world_call("set_labels_visible", { self.labels_on })
		-- Map labels step around every floating panel (the view tracks their rects itself).
		ctx:world_call("set_hud_controls", { self:hud_controls() })
		-- the globe can't draw territories (editable budget / Mesh-Image APIs off): a notice (R2-3)
		self:_sig(world, "territory_status_changed", function(st)
			self.globe_notice:set_status(st)
		end)
		local st = ctx:world_call("territory_status", {})
		if type(st) == "table" then
			self.globe_notice:set_status(st)
		end
	end
	if audio ~= nil then
		self:_sig(audio, "music_enabled_changed", function(on)
			self.pause:sync_music(on)
		end)
		if audio.pops_enabled_changed ~= nil then
			self:_sig(audio, "pops_enabled_changed", function(on)
				self.pause:sync_pops(on)
			end)
		end
	end
	self._theme = ""
	self:_request_apply()
end

--- A new player (Data/Tutorial.is_new, or "Replay as new player") on the title: their first match
--- starts by itself, as the tutorial (14% of new players never started one). Not in a Studio
--- session with the dev diag on, where it would start under every test (dev diag: `tutorial`).
UIRoot.TUTORIAL_DELAY_S = 0.9

function UIRoot._check_new_player(self, forced: boolean?)
	local ctx = self.ctx
	local s = ctx.session
	if self.tutorial == nil or self.tutorial.active or s == nil then
		return
	end
	if not forced then
		if UICtx.IS_ROBLOX and workspace:GetAttribute("AF_DIAG") == true then
			return
		end
		local stats = if type(s.load_settings) == "function" then s:load_settings("stats") else nil
		-- (a record that didn't load reads as new: never a reason to start the tutorial for a veteran)
		if s.settings_failed == true or not TutorialData.is_new(ctx.settings, stats) then
			if s.settings_failed == true and not self._told_unloaded then
				self._told_unloaded = true
				self:_on_notice("Your record didn't load this time. It is safe: rejoin to see it.", 1)
			end
			return
		end
	end
	self._tutorial_at = UICtx.msec() + UIRoot.TUTORIAL_DELAY_S * 1000
end

function UIRoot._tutorial_step(self)
	local ctx = self.ctx
	if UICtx.msec() < self._tutorial_at then
		return
	end
	if self._autostart ~= nil or self._hop ~= nil or ctx:mode() ~= UICtx.MODE_TITLE or ctx:mp_waiting() then
		self._tutorial_at = nil -- (they are on their way into a match already)
		return
	end
	if self._screen ~= "title" or ctx:session_call("is_building") == true then
		return
	end
	self._tutorial_at = nil
	self:start_tutorial()
end

--- Starts the tutorial's match: a solo match on the default map with the gentlest AI and fewer
--- tribes, the steps on top (UI/Tutorial).
function UIRoot.start_tutorial(self)
	local ctx = self.ctx
	if ctx:session_call("is_building") == true or ctx:mode() ~= UICtx.MODE_TITLE then
		return
	end
	self._solo_msec = UICtx.msec()
	ctx:set_setting("tutorial", "started")
	self.coach.muted = true
	self.coach:clear()
	self.tutorial:begin()
	ctx:session_call("start_solo", {
		TutorialData.DIFFICULTY,
		UIMaps.DEFAULT_ID,
		{
			tribes = TutorialData.TRIBES,
			countdown_ticks = TutorialData.COUNTDOWN_TICKS,
			-- (a new player meets the first draft early, and nations do not out-scale them while they learn)
			era_ticks = UICtx.data("Eras").TUTORIAL,
			doctrines_ai = false,
			draft_timeout_s = 150,
		},
	})
end

--- Rofront Staging, and game admins on production: "Replay as new player" (the game menu, and the
--- settings page: the title's gear). Everything first-time is as new again and the title follows,
--- where the tutorial starts.
function UIRoot.replay_as_new_player(self)
	local ctx = self.ctx
	if not (ctx.staging or ctx:admin()) then
		return
	end
	self.coach:reset()
	self.tutorial:stop("left")
	ctx:set_setting("tutorial", "")
	ctx:session_call("new_player")
	self.telemetry:new_player()
	if self.pause.is_open then
		self.pause:close()
	end
	if ctx:mode() ~= UICtx.MODE_TITLE then
		self:_award_career(0)
		ctx:session_call("leave_match")
	end
	self:_check_new_player(true)
	-- (the way back to the title takes a moment)
	self._tutorial_at = UICtx.msec() + 2500
end

--- The player's saved [ui] settings arrived from the server.
function UIRoot._on_settings_loaded(self)
	local ctx = self.ctx
	ctx:reload_settings()
	self:_check_new_player(false)
	self.labels_on = ctx:setting("labels", true) ~= false
	self.title.difficulty =
		math.clamp(tonumber(ctx:setting("difficulty", UICtx.DEFAULT_DIFFICULTY)) or UICtx.DEFAULT_DIFFICULTY, 0, 2)
	for i, ch in ipairs(self.title._chips) do
		ch:set_pressed_no_signal(i - 1 == self.title.difficulty)
	end
	self.title:_refresh_diff()
	-- the saved solo map arrives with the settings: Play Solo uses it, so the title must show it
	self.title:set_map_name(UIMaps.name_of(UIMaps.valid(ctx:setting("map_id", UIMaps.DEFAULT_ID))))
	ctx:world_call("set_labels_visible", { self.labels_on and self._screen ~= "title" and self._screen ~= "" })
end

--- How many entries hud_controls' list has (it has holes, so its length can't be asked).
UIRoot.HUD_CONTROLS = 24

--- Every HUD panel that floats over the globe (WorldView.set_hud_controls: labels avoid them).
--- Returned as Roblox GuiObjects: viewport rect = AbsolutePosition + GuiService:GetGuiInset(), AbsoluteSize.
function UIRoot.hud_controls(self): { GuiObject }
	local out = {}
	-- (some are nil on some screens: the list has holes, so it is walked to its known length)
	local list = {
		self.top.panel,
		self.top.side,
		self.send_panel.panel,
		self.log_panel.panel,
		self.dock.panel,
		self.board.panel,
		self.outliner.panel,
		self.clock.panel,
		self.bar.panel,
		self.bar._chip,
		self.readout.label,
		self.spawn.panel,
		self.alert.panel,
		self.coach._card,
		self.target_card._panel,
		self.tooltip._panel,
		self.place_confirm._panel,
		self.unit_card._panel,
		self.build_window.panel,
		self.notices._stack,
		self.spectate_pill,
		self.globe_notice and self.globe_notice.card,
		self.list_popup.panel,
		-- the result screen's column (title, copy, stats, buttons): labels keep showing through
		-- the dim around it, never under its text (review R2-3)
		self.over and self.over._center,
	}
	for i = 1, UIRoot.HUD_CONTROLS do
		local n = list[i]
		if n ~= nil and n.gui ~= nil then
			table.insert(out, n.gui)
		end
	end
	for _, rec in self.alerts._slots do
		table.insert(out, rec.button.gui)
	end
	for _, n in ipairs(self._extra_hud) do
		if n.gui ~= nil then
			table.insert(out, n.gui)
		end
	end
	return out
end

--- A transient HUD node (the war-begins banner's text) that map labels avoid while it is up; it
--- is dropped again when the node is freed.
function UIRoot.add_hud_control(self, node: any)
	if node == nil or node.gui == nil or node._freed then
		return
	end
	table.insert(self._extra_hud, node)
	node.tree_exiting:Connect(function()
		local i = table.find(self._extra_hud, node)
		if i ~= nil then
			table.remove(self._extra_hud, i)
			self.ctx:world_call("set_hud_controls", { self:hud_controls() })
		end
	end)
	self.ctx:world_call("set_hud_controls", { self:hud_controls() })
end

--- Closes any open sheet (Help and Settings draw under them, so the top row's buttons would look dead).
function UIRoot._close_sheets(self)
	for _, key in { "locker", "flag_shop", "shop_hub", "starter", "general", "arsenal", "command", "war_report", "map_picker", "crate_odds", "roadmap", "realm" } do
		local w = self[key]
		if w ~= nil and w.is_open and type(w.close) == "function" then
			w:close()
		end
	end
end

function UIRoot.toggle_help(self)
	if self.help.is_open then
		self.help:close()
	else
		self:_close_sheets()
		self.radial:close(false)
		self.interact:cancel_aim(false)
		self.tooltip:hide_tip()
		self.help:open()
		self.help_toggled:Fire(true)
		self.telemetry:help(if self.title.visible then "title" else "match")
	end
	self:_update_input_gate()
	self:_update_pause()
end

function UIRoot.toggle_leaderboard(self)
	if self._screen == "title" or self._screen == "" then
		return
	end
	self.board:toggle()
	self.leaderboard_toggled:Fire(self.board.expanded)
end

--- The Build window (the outliner's Build, a phone's Build, B) or the Warheads window (Warheads, N): opens `mode`,
--- or closes it when it is the one open.
function UIRoot.toggle_build(self, mode: string)
	if self._screen ~= "play" or not self.ctx:alive_player() then
		return
	end
	self.radial:close(false)
	self.tooltip:hide_tip()
	self.interact:cancel_aim(false)
	self.list_popup:close()
	self.build_window:toggle(mode)
end

--- Your own land's right-click (a phone's hold): the Build window, to raise something right at `tile`.
function UIRoot.open_build_here(self, tile: number, struct: any?)
	if self._screen ~= "play" or not self.ctx:alive_player() then
		return
	end
	self.radial:close(false)
	self.target_card:hide_card()
	self.interact:cancel_aim(false)
	self.list_popup:close()
	self.build_window:open("build", tile, struct)
end

--- An entry picked: opened on your land, a building goes up right there when it can; else it is placed as ever (the
--- ghost follows the cursor, a phone's plate confirms), and a warhead is aimed.
function UIRoot._on_build_pick(self, kind: string, tile: number)
	local ctx = self.ctx
	local UIRules = UICtx.mod("UIRules")
	local here = tile >= 0
		and not UIRules.is_nuke(kind)
		and not UIRules.is_call(kind)
		and kind ~= "warship"
		and ctx.rules ~= nil
		and ctx.rules:availability(kind).ok
		and ctx.rules:placement(kind, tile).ok
	if here then
		local pos = ctx:tile_screen_pos(tile)
		self.interact:on_radial("build:" .. kind, tile, if pos.X >= 0 then pos else ctx:mouse_pos())
	else
		self.interact:select_action(kind)
	end
	self:_update_input_gate()
end

--- Selects nation `id` in the selection window (an alert, a rival, CHANCES): the camera goes there too.
function UIRoot.select_owner(self, id: number)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil or s:get_owner(id) == nil or self._screen ~= "play" then
		return
	end
	self.list_popup:close()
	self.build_window:close(false)
	ctx:world_call("focus_owner", { id })
	local tile = s:label_tile(id)
	if tile >= 0 then
		self.interact:select_at(tile)
	end
end

--- The outliner's four buttons and a phone's: Build, Warheads, Pacts, Doctrine, and a phone's Your war.
function UIRoot._on_order_button(self, key: string)
	local ctx = self.ctx
	ctx:sfx("click", -4.0)
	if key == "build" or key == "warheads" then
		self:toggle_build(key)
	elseif key == "pacts" then
		self:_open_pacts()
	elseif key == "doctrine" then
		self:_open_doctrine()
	elseif key == "war" then
		self.build_window:close(false)
		-- (a phone's two sheets never stand together: Your war closes the nation's)
		if not self.outliner.sheet_open and self.target_card.is_open then
			self.target_card:hide_card(true)
		end
		self.outliner:set_sheet(not self.outliner.sheet_open)
	end
end

--- Where a list window opened by `key` stands beside.
function UIRoot._popup_anchor(self, key: string): any
	local b = if self.ctx.compact then self.bar:action_button(if key == "doctrine" then "build" else key) else self.dock:button(key)
	if b ~= nil and b:is_visible_in_tree() then
		local r = b:get_global_rect()
		return { x0 = r.Min.X, y0 = r.Min.Y, x1 = r.Max.X, y1 = r.Max.Y }
	end
	return nil
end

--- Pacts: offers to you (Seal / Refuse), your pacts and when each ends (Keep), your own offers waiting.
function UIRoot._open_pacts(self)
	local ctx = self.ctx
	local s = ctx.state
	local me = ctx:me()
	if s == nil or me == 0 then
		return
	end
	local T = UITheme
	local rows = {}
	for key in s.requests or {} do
		local from, to = key // 1024, key % 1024
		if to == me and s:get_owner(from) ~= nil then
			table.insert(rows, {
				-- (the name on its own line, the offer under it: one line ran out of room, "Vladimir offers a…")
				text = s:owner_name(from),
				sub = "Offers you a pact",
				colour = T.DIAL_AMBER,
				go = function()
					self:select_owner(from)
				end,
				actions = {
					{ label = "Seal", fn = function()
						ctx:send({ type = "ally_reply", target = from, accept = true })
						ctx:sfx("confirm", -6.0)
						self.list_popup:close()
					end },
					{ label = "Refuse", fn = function()
						ctx:send({ type = "ally_reply", target = from, accept = false })
						self.list_popup:close()
					end },
				},
			})
		elseif from == me and s:get_owner(to) ~= nil then
			table.insert(rows, { text = string.format("Your offer to %s", s:owner_name(to)), sub = "No answer yet", colour = T.DIAL_MUTED, go = function()
				self:select_owner(to)
			end })
		end
	end
	for _, other in s:allies_of(me) do
		local ai = s:alliance_info(me, other)
		local sub = "Bound to you"
		local acts = nil
		if ai ~= nil and ai.expires_at >= 0 then
			sub = "Ends in " .. T.fmt_time(math.ceil(ai.ticks_left / Defs.TICK_RATE))
			if ai.in_window and ai.can_extend and not ai.me_asked then
				acts = { { label = "Keep", fn = function()
					ctx:send({ type = "ally_extend", target = other })
					ctx:sfx("confirm", -6.0)
					self.list_popup:close()
				end } }
			elseif ai.me_asked then
				sub ..= " · you asked to keep it"
			end
		end
		table.insert(rows, { text = s:owner_name(other), sub = sub, colour = T.DIAL_GREEN, actions = acts, go = function()
			self:select_owner(other)
		end })
	end
	local sub = if #rows == 0
		then string.format("No pacts and no offers. Select a nation (%s its land) and offer one.", if ctx.touch then "tap" else "right-click")
		else "Press a name to select that nation."
	self.list_popup:open("pacts", "PACTS", sub, rows, self:_popup_anchor("pacts"))
end

--- Doctrine: a draft waiting opens; else your doctrines so far, and the edicts they grant.
function UIRoot._open_doctrine(self)
	local ctx = self.ctx
	local s = ctx.state
	local me = ctx:me()
	if s == nil or me == 0 then
		return
	end
	if self.draft:folded() then
		self.draft:unfold()
		return
	end
	local Doctrines = UICtx.data("Doctrines")
	local by = s.doctrine and s.doctrine[me]
	local rows = {}
	for draft = 1, Doctrines.TIERS do
		local row = by and by[draft]
		if row ~= nil and row[6] >= 1 and row[6] <= Doctrines.OFFER_SIZE then
			local d = Doctrines.LIST[row[2 + row[6]]]
			table.insert(rows, { text = string.format("%s %s", d.glyph, d.name), sub = table.concat(Doctrines.effects(d), " · "), colour = UITheme.DIAL_AMBER })
		end
	end
	local sub = if #rows == 0 then "None yet: each age offers three, and you keep one." else "Each age offers three more, and you keep one."
	self.list_popup:open("doctrine", "DOCTRINE", sub, rows, self:_popup_anchor("doctrine"))
end

--- CHANCES: weak neighbours your send should break, and pact offers; a press selects that nation.
function UIRoot._open_chances(self)
	local rows = {}
	for _, c in self.top:chance_list() do
		table.insert(rows, { text = c.line, colour = if c.kind == "offer" then UITheme.DIAL_AMBER else UITheme.DIAL_GREEN, go = function()
			self:select_owner(c.id)
		end })
	end
	local r = self.top.side:get_global_rect()
	local sub = if #rows == 0 then "Nothing yet: no neighbour your send would break, and no pact offered." else "Press one to select that nation."
	self.list_popup:open("chances", "CHANCES", sub, rows, { x0 = r.Min.X, y0 = r.Min.Y, x1 = r.Max.X, y1 = r.Max.Y })
end

--- Coalesced full re-layout (panel toggles): at most once per frame.
function UIRoot._request_relayout(self)
	if self._relayout_pending then
		return
	end
	self._relayout_pending = true
	W.defer(function()
		self._relayout_pending = false
		self:_layout()
	end)
end

--- The Arsenal (Data/Arsenal): units unlocked with Stars or Robux. `focus`: an item to bring into
--- view; `from`: "title" / "match" (the bar's War College slot) / "locked" (a locked unit pressed) / "over" /
--- "offer" (one of the result screen's offers).
--- A solo match stands still while it is open.
function UIRoot.open_arsenal(self, focus: string?, from: string?)
	if self.arsenal == nil then
		return
	end
	self.interact:cancel_aim(false)
	self.build_window:close(false)
	self.arsenal:open(focus, from)
	self:_update_input_gate()
	self:_update_pause()
end

--- The Standards (FlagShop; Data/Shop): the title's row.
function UIRoot.open_shop(self)
	local fs = self.flag_shop
	if fs == nil or fs.is_open then
		return
	end
	fs:open()
	self:_update_input_gate()
end

--- The whole shop (ShopHub): the title's SHOP row; `tab` opens it at that tab (CTW_CMD "open_shop_hub spoils").
function UIRoot.open_shop_hub(self, tab: any)
	local sh = self.shop_hub
	if sh == nil then
		return
	end
	local want = if type(tab) == "string" and tab ~= "" then tab else nil
	if sh.is_open then
		if want ~= nil then
			sh:show_tab(want)
		end
		return
	end
	sh:open(want)
	self:_update_input_gate()
end

--- The Founding Grant (StarterOffer; Data/Starter): the title's row. It never opens by itself.
function UIRoot.open_starter(self, from: string)
	local st = self.starter
	local s = self.ctx.session
	if st == nil or st.is_open or s == nil then
		return
	end
	local o = s.inventory and s.inventory.starter
	if type(o) ~= "table" then
		return
	end
	st:open(from)
	s:starter_seen() -- (a count, nothing more)
	self:_update_input_gate()
end

--- The Charter's sheet (Data/Subscription): the title's row.
function UIRoot.open_general(self, from: string)
	if self.general == nil or self.general.is_open then
		return
	end
	self.general:open(from)
	self:_update_input_gate()
end

--- The server's word on the Charter: what it just paid says so (a toast), and a new holder is thanked.
function UIRoot._on_general(self, on: boolean, given: any)
	if type(given) == "table" then
		local parts = {}
		if type(given.stars) == "number" then
			local days = tonumber(given.days) or 1
			table.insert(
				parts,
				if days > 1
					then string.format("+%s Renown for %d days", UICtx.commas(given.stars), days)
					else string.format("+%s Renown today", UICtx.commas(given.stars))
			)
		end
		local skin = if type(given.skin) == "string" then UICtx.data("Cosmetics").item(given.skin) else nil
		if skin ~= nil then
			table.insert(parts, skin.name .. " is yours")
		end
		if #parts > 0 then
			self:_on_notice("Charter: " .. table.concat(parts, ", "), 0)
		end
	end
	if on and self.general ~= nil and self.general.is_open then
		self.ctx:sfx("confirm")
	end
end

--- The Locker (Main's crate button on the title): crates, skins and flags.
function UIRoot.open_locker(self)
	if self.locker == nil or self.locker.is_open then
		return
	end
	self.locker:open()
	self:_update_input_gate()
end

--- Studio debug channel (Main's CTW_CMD): shows the end screen ("victory", "defeat", "eliminated"...).
function UIRoot.debug_over(self, kind: any)
	self.over:open(kind or "victory", 0, 0, { duration_s = 300 }, -1)
end

--- Studio debug channel: plays the trailer's scenes by itself for a screen recording (Dev/TrailerDirector).
function UIRoot.trailer(self)
	return require("../Dev/TrailerDirector").start(self)
end

--- Studio debug channel (Main's CTW_CMD): how much of the screen the always-on HUD covers now (HudCoverage), and
--- each part's size in logical px.
function UIRoot.hud_coverage(self)
	local ctx = self.ctx
	local boxes, parts = {}, {}
	local function add(name: string, r: any)
		if r ~= nil and r.Width > 0 and r.Height > 0 then
			table.insert(boxes, { x0 = r.Min.X, y0 = r.Min.Y, x1 = r.Max.X, y1 = r.Max.Y })
			table.insert(parts, string.format("%s %dx%d", name, r.Width, r.Height))
		end
	end
	local function panel(name: string, c: any)
		if c ~= nil and c:is_visible_in_tree() then
			add(name, c:get_global_rect())
		end
	end
	panel("strip", self.top.panel)
	panel("tension", self.top.side)
	panel("outliner", self.outliner.panel)
	panel("clock", self.clock.panel)
	panel("send", self.send_panel.panel)
	panel("log", self.log_panel.panel)
	panel("dock", self.dock.panel)
	for _, r in ipairs(self.alerts:rects()) do
		add("alerts", r)
	end
	for _, r in ipairs(self.bar:rects()) do
		add("thumbs", r)
	end
	-- (the selection window only counts while it is open)
	if self.target_card.is_open then
		add("window", self.target_card:panel_rect())
	end
	if self.topbar_provider ~= nil then
		-- (ours only, in viewport px: Roblox's own buttons are not ours to move)
		local r = self.topbar_provider()
		if r ~= nil then
			add("row", ctx:rect_to_logical(r))
		end
	end
	local share = HudCoverage.share(boxes, ctx.vp.X, ctx.vp.Y)
	return string.format(
		"%.1f%% of %dx%d compact=%s: %s",
		share * 100,
		ctx.vp.X,
		ctx.vp.Y,
		tostring(ctx.compact),
		table.concat(parts, ", ")
	)
end

--- Studio debug channel (Main's CTW_CMD): opens a screen that needs a purchase or a first run to reach.
function UIRoot.debug_screen(self, what: any)
	if what == "general" then
		self.general:open("debug")
	elseif what == "tutorial" then
		self.tutorial:begin()
	elseif what == "odds" then
		self.crate_odds:open(self.locker:_inv().owned)
	elseif what == "renown" then
		self.crate_opening:play({})
		task.delay(1.5, function()
			self.crate_opening:resolve_renown(UICtx.data("Cosmetics").SPOILS_RENOWN)
		end)
	else
		self.crate_opening:play({})
		task.delay(1.5, function()
			self.crate_opening:resolve(what or "")
		end)
	end
end

--- Studio debug channel (Main's CTW_CMD): opens the Field Guide at topic `i` (UI checks: tools/ui_clip_scan.luau).
function UIRoot.help_topic(self, i: any)
	if not self.help.is_open then
		self.help:open()
	end
	self.help:show_topic(tonumber(i) or 1)
end

--- Studio debug channel (Main's CTW_CMD): switches the Locker's tab (1 skins, 2 flags).
function UIRoot.locker_tab(self, i: any)
	local chip = self.locker and self.locker._tabs and self.locker._tabs[tonumber(i) or 1]
	if chip ~= nil then
		chip.pressed:Fire()
	end
end

--- Studio debug channel: takes the open draft's card number `i` (default 1).
function UIRoot.draft_pick(self, i: any)
	local row = self.draft and self.draft._row
	local Doctrines = UICtx.data("Doctrines")
	local d = row and Doctrines.LIST[row[2 + (tonumber(i) or 1)]]
	if row ~= nil and i == "edict" then
		for slot = 1, Doctrines.OFFER_SIZE do
			local c = Doctrines.LIST[row[2 + slot]]
			if c.edict ~= nil then
				d = c
				break
			end
		end
	end
	if d ~= nil then
		self.draft:choose(d.key)
	end
end

--- Studio debug channel: previews a phone-sized logical viewport on the desktop window (`phone 2.2` scales the
--- UI up so the viewport is ~1/2.2 as many logical px; `phone off` restores).
function UIRoot.phone(self, s: any)
	self.root:set_scale_override(tonumber(s))
	self:relayout()
	return tostring(self.root.vp)
end

--- Studio debug channel: the local nation cannot be beaten (troops and gold topped up each second), so a run under
--- AF_DEV_SPEED reaches the Reckoning. Solo only: it writes to the local Sim.
--- Studio debug channel: plants your banner on free land nearest the map's middle (solo), so a match can be driven
--- without a click. Returns the tile or why not.
function UIRoot.debug_spawn(self)
	local sim = self.ctx.session and self.ctx.session._sim
	if not sim then
		return "no match"
	end
	local W, H = sim.W, sim.H
	local best, bd = -1, math.huge
	for k = 0, sim.map.land_count - 1, 7 do
		local t = sim.map:land_tile(k)
		if buffer.readi32(sim.owner, t * 4) == 0 and sim.map:is_contestable(t) then
			local dx, dy = t % W - W * 0.5, t // W - H * 0.5
			local d = dx * dx + dy * dy
			if d < bd then
				best, bd = t, d
			end
		end
	end
	if best < 0 then
		return "nowhere open to plant"
	end
	self.ctx:send({ type = "spawn", tile = best })
	return best
end

--- Studio debug channel: a map mode ("nations", "defences", "provinces").
function UIRoot.debug_map_mode(self, arg: any)
	self.clock:set_mode(tostring(arg or "nations"))
	return self.ctx.map_mode
end

--- Studio debug channel: sends an order, "army kind=raise troops=20000" (numbers become numbers, true / false booleans).
function UIRoot.debug_intent(self, arg: any)
	local words = string.split(tostring(arg or ""), " ")
	local it: { [string]: any } = { type = words[1] }
	for i = 2, #words do
		local k, v = string.match(words[i], "^(%w+)=(.*)$")
		if k ~= nil then
			it[k] = if v == "true" then true elseif v == "false" then false else (tonumber(v) or v)
		end
	end
	self.ctx:send(it)
	return words[1]
end

--- Studio debug channel: the solo war's depth ("long", "quick", or "off" for the classic war).
function UIRoot.debug_depth(self, arg: any)
	local key = tostring(arg or "")
	self.ctx:set_setting("depth", if key == "long" or key == "quick" then key else "")
	if self.title ~= nil and self.title._refresh_depth ~= nil then
		self.title:_refresh_depth()
	end
	return key
end

--- Studio debug channel: the solo start date (Data/Periods key; "" or "today" for today's world) and map id, "1066 europe".
function UIRoot.debug_period(self, arg: any)
	local key, map = string.match(tostring(arg or ""), "^(%S*)%s*(%S*)$")
	self.ctx:set_setting("period", if key == "today" then "" else (key or ""))
	if map ~= nil and map ~= "" then
		self.ctx:set_setting("map_id", map)
	end
	return tostring(key) .. " " .. tostring(map)
end

--- Studio debug channel: the camera on the map point at fractions "fx fy" of its width and height, `rows` map rows tall
--- ("0.72 0.3 600"), and the interface hidden or shown with "hud off" / "hud on": screenshots and thumbnails.
function UIRoot.debug_view(self, arg: any)
	local a = tostring(arg or "")
	if a == "hud off" or a == "hud on" then
		local on = a == "hud on"
		local pg = game:GetService("Players").LocalPlayer.PlayerGui
		for _, n in { "AirfrontUI", "AirfrontTopbar" } do
			local g = pg:FindFirstChild(n)
			if g ~= nil then
				g.Enabled = on
			end
		end
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, on)
		end)
		return a
	end
	local fx, fy, rows = string.match(a, "^(%S+)%s+(%S+)%s*(%S*)$")
	local st = self.ctx.state
	if st == nil or st.map == nil or tonumber(fx) == nil then
		return "need: fx fy [rows]"
	end
	local W, H = st.map.W, st.map.H
	local t = math.floor(tonumber(fy) * H) * W + math.floor(tonumber(fx) * W)
	local r = tonumber(rows) or 400
	self.ctx:world_call("focus_tile", { t, 1.0 + 0.0044 * r, 0.1 })
	return t
end

function UIRoot.god(self)
	task.spawn(function()
		while true do
			local sess = self.ctx.session
			local sim = sess ~= nil and sess._sim
			local me = self.ctx:me()
			if sim and me ~= 0 and sim.o_alive[me] == 1 then
				sim.o_troops[me] = math.max(sim.o_troops[me], 5000000)
				sim.o_gold[me] = math.max(sim.o_gold[me], 5000000)
				sim.o_shield_until[me] = sim.tick + 600
			end
			task.wait(0.5)
		end
	end)
	return "god on"
end

--- Studio debug channel: opens every age, builds a Launch Site on your land and, once it stands, fires warhead `kind`
--- (default "atom") at the nearest land of another nation. Solo only: it writes to the local Sim.
function UIRoot.debug_strike(self, kind: any)
	local sim = self.ctx.session and self.ctx.session._sim
	local me = self.ctx:me()
	if not sim or me == 0 then
		return "no match"
	end
	local W, N = sim.W, sim.N
	local home = nil
	for t = 0, N - 1 do
		if buffer.readi32(sim.owner, t * 4) == me then
			home = t
			break
		end
	end
	if home == nil then
		return "no land"
	end
	-- (the ages run off the clock: bring the next two forward, the Reckoning stays where it was)
	local since = sim.tick - sim.playing_since
	sim.eras = { sim.eras[1], since + 2, since + 4, math.max(sim.eras[4], since + 6) }
	task.spawn(function()
		task.wait(1)
		sim:try_build(me, "silo", home)
		task.wait(14)
		-- (far enough that the blast doesn't take the Site's own land with it)
		for r = 70, 400 do
			for _, t in { home + r, home - r, home + r * W, home - r * W, home + r * W + r, home - r * W - r } do
				local o = if t >= 0 and t < N then buffer.readi32(sim.owner, t * 4) else 0
				if o ~= 0 and o ~= me then
					sim:launch_nuke(me, kind or "atom", t)
					return
				end
			end
		end
	end)
	return "site placed at " .. home
end

--- Studio debug channel: the other way round from debug_strike: a rival builds a Launch Site and fires warhead `kind`
--- (default "atom") at your land (the incoming banner and the siren). Solo only: it writes to the local Sim.
function UIRoot.debug_incoming(self, kind: any)
	local sim = self.ctx.session and self.ctx.session._sim
	local me = self.ctx:me()
	if not sim or me == 0 then
		return "no match"
	end
	local home, foe_home, foe = nil, nil, 0
	for t = 0, sim.N - 1 do
		local o = buffer.readi32(sim.owner, t * 4)
		if o == me and home == nil then
			home = t
		elseif o ~= 0 and o ~= me and foe_home == nil and sim.o_alive[o] == 1 then
			foe_home, foe = t, o
		end
		if home ~= nil and foe_home ~= nil then
			break
		end
	end
	if home == nil or foe_home == nil then
		return "no land"
	end
	local since = sim.tick - sim.playing_since
	sim.eras = { sim.eras[1], since + 2, since + 4, math.max(sim.eras[4], since + 6) }
	task.spawn(function()
		task.wait(1)
		sim.o_gold[foe] = math.max(sim.o_gold[foe], 5000000)
		sim:try_build(foe, "silo", foe_home)
		task.wait(14)
		sim.o_gold[foe] = math.max(sim.o_gold[foe], 5000000)
		sim:launch_nuke(foe, kind or "atom", home)
	end)
	return "rival " .. foe .. " site at " .. foe_home
end

--- Studio debug channel: your truce ends and up to `n` (default 2) nations bordering you march into your land (the
--- attack marks). Solo only.
function UIRoot.debug_attacked(self, n: any)
	local sim = self.ctx.session and self.ctx.session._sim
	local me = self.ctx:me()
	if not sim or me == 0 then
		return "no match"
	end
	local want = tonumber(n) or 2
	local W, N = sim.W, sim.N
	local foes, got = {}, 0
	for t = 0, N - 1 do
		if buffer.readi32(sim.owner, t * 4) == me then
			for _, u in { t - 1, t + 1, t - W, t + W } do
				local o = if u >= 0 and u < N then buffer.readi32(sim.owner, u * 4) else 0
				if o ~= 0 and o ~= me and foes[o] == nil and sim.o_alive[o] == 1 then
					foes[o] = t
					got += 1
				end
			end
		end
		if got >= want then
			break
		end
	end
	local out = {}
	-- (the opening truce shields you: it ends now; the attacks are sized to grind on for a while, not to wipe you out)
	sim.o_shield_until[me] = sim.tick
	sim.o_troops[me] = math.max(sim.o_troops[me], 3000)
	for o, t in foes do
		sim.o_troops[o] = math.max(sim.o_troops[o], 4000)
		sim:intent_attack_troops(o, t, 2500)
		table.insert(out, tostring(o))
	end
	return "attacked by " .. table.concat(out, ",")
end

--- Studio debug channel: the attack marks for 20 s without a war: one at your land and one far off the screen, from two
--- other nations.
function UIRoot.debug_marks(self)
	local sim = self.ctx.session and self.ctx.session._sim
	local me = self.ctx:me()
	if not sim or me == 0 then
		return "no match"
	end
	local o = self.ctx:my()
	local near = if o ~= nil then (o.spawn_tile or -1) else -1
	local others = {}
	for id = 1, #sim.o_alive do
		if id ~= me and sim.o_alive[id] == 1 then
			table.insert(others, id)
			if #others >= 2 then
				break
			end
		end
	end
	if near < 0 or #others < 2 then
		return "no land"
	end
	local far = (near + sim.W * math.floor(sim.H * 0.4) + math.floor(sim.W * 0.3)) % sim.N
	self.threat_marks._list = {
		{ owner = others[1], tile = near + 6, troops = 4200 },
		{ owner = others[2], tile = far, troops = 1300 },
	}
	self.threat_marks.hold_s = 20.0
	return "marks at " .. near .. " and " .. far
end

--- Studio debug channel: back to the title screen.
function UIRoot.to_title(self)
	self:_award_career(0)
	self.ctx:session_call("leave_match")
	local sess = self.ctx.session
	if sess ~= nil and sess:returning() then
		self.over:set_returning()
	else
		self.over:close()
	end
end

--- Studio debug channel: closes the Command Center or the War Report.
function UIRoot.close_panels(self)
	self.command:close()
	self.war_report:close()
end

--- Studio debug channel: starts a solo match in mode `key` on the default map.
function UIRoot.play_mode(self, key: any)
	self.ctx:set_setting("mode", key)
	self._solo_msec = 0
	self._mission = nil
	self.over:close()
	if self.ctx:mode() == UICtx.MODE_SOLO then
		self:_restart_solo(0)
	else
		self:_on_play_solo(0)
	end
	return tostring(key)
end

--- Studio debug channel: what the draft sees (for CTW_RESULT).
function UIRoot.draft_info(self)
	local d = self.draft
	local s = self.ctx.state
	local me = self.ctx:me()
	local by = s ~= nil and s.doctrine ~= nil and s.doctrine[me]
	local n = 0
	if by then
		for _ in by do
			n += 1
		end
	end
	return string.format("row=%s collapsed=%s panel=%s folded=%s doctrine=%s drafts=%d phase=%s me=%s tut=%s", tostring(d._row ~= nil),
		tostring(d._collapsed), tostring(d.panel.visible), tostring(d:folded()), tostring(s ~= nil and s.doctrine ~= nil), n,
		tostring(s and s.phase), tostring(me), tostring(self.tutorial and self.tutorial.active))
end

--- Studio debug channel: fires the edict chip `name` as if pressed.
function UIRoot.edict_fire(self, name: any)
	local chip = self.draft and self.draft.edict_chips[name]
	if chip ~= nil then
		chip.pressed:Fire()
	end
end

function UIRoot.open_pause_menu(self)
	if self.pause.is_open then
		self.pause:close()
		return
	end
	if self.help.is_open then
		self.help:close()
	end
	self.radial:close(false)
	self.interact:cancel_aim(false)
	self.tooltip:hide_tip()
	self.pause:open(self.labels_on)
	self:_update_input_gate()
	self:_update_pause()
end

--- Settings (the top bar's gear): the game menu's window on its settings page, on the title too.
--- A second press closes it; over the open game menu it turns the page.
function UIRoot.open_settings(self)
	self:_close_sheets()
	if self.pause.is_open then
		if self.pause:page() == "settings" then
			self.pause:close()
		else
			self.pause:show_settings()
		end
		return
	end
	if self.help.is_open then
		self.help:close()
	end
	self.radial:close(false)
	self.interact:cancel_aim(false)
	self.tooltip:hide_tip()
	self.pause:open(self.labels_on, "settings")
	self:_update_input_gate()
	self:_update_pause()
end

--- Current screen: "title", "spawn", "play" or "over".
function UIRoot.screen(self): string
	return self._screen
end

-- =============================================================================================
-- Construction
-- =============================================================================================

function UIRoot._make_gui(self, parent: Instance?)
	local sg = Instance.new("ScreenGui")
	sg.Name = "AirfrontUI"
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.ScreenInsets = Enum.ScreenInsets.None
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 10
	local p = parent
	if p == nil and UICtx.IS_ROBLOX then
		local lp = game:GetService("Players").LocalPlayer
		p = if lp then lp:WaitForChild("PlayerGui") else nil
	end
	sg.Parent = p
	self.gui = sg
	-- Exact Rubik metrics make the first layout final, but a cold client (first visit, slow network)
	-- must never sit on a blank screen: wait at most FONT_WAIT_S, then build with approximate metrics
	-- (the kit re-lays out every tree when the fonts arrive; UITheme.init keeps loading meanwhile).
	-- Main starts the Session, the globe and the top bar before building the UI.
	if UICtx.IS_ROBLOX and not UITheme.fonts_ready() then
		task.spawn(UITheme.init)
		local t0 = os.clock()
		while not UITheme.fonts_ready() and os.clock() - t0 < UIRoot.FONT_WAIT_S do
			task.wait()
		end
	end
	local root = W.Root.new(sg, { touch_device = self.ctx.touch_device })
	root.name = "UI"
	self.root = root
	self.ctx.root = root
	W.set_external_driver(true)
end

function UIRoot._layer(self, n: string)
	local c = W.Control.new()
	c.name = n
	c.gui.Name = n
	c:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	c:set_mouse_filter(W.MOUSE_IGNORE)
	return c
end

--- A full-rect node hosting a raw logical canvas (RadialMenu).
function UIRoot._host(self, canvas: GuiObject, n: string)
	local host = self:_layer(n)
	canvas.Parent = host.gui
	canvas.ZIndex = 1
	return host
end

function UIRoot._build(self)
	local ctx = self.ctx
	local root = self.root
	local StrategyStrip = kit("StrategyStrip")
	local Leaderboard = kit("Leaderboard")
	local EventFeed = kit("EventFeed")
	local Outliner = kit("Outliner")
	local WarClock = kit("WarClock")
	local AlertRow = kit("AlertRow")
	local OrderHub = kit("OrderHub")
	local BuildWindow = kit("BuildWindow")
	local AlertBanner = kit("AlertBanner")
	local BusyChip = kit("BusyChip")
	local DoctrineDraft = kit("DoctrineDraft")
	local SendPanel = kit("SendPanel")
	local LogPanel = kit("LogPanel")
	local ThreatMarks = kit("ThreatMarks")
	local ArmyMarks = kit("ArmyMarks")
	local ProvinceNames = kit("ProvinceNames")
	local ActionDock = kit("ActionDock")

	local hud = self:_layer("HUD")
	self.hud = hud
	-- the top strip, World Tension and CHANCES (`top`)
	local top = StrategyStrip.new(ctx)
	top.name = "TopStrip"
	self.top = top
	top.tapped:Connect(function()
		self:_toggle_stats_card()
	end)
	top.chances_wanted:Connect(function()
		self:_open_chances()
	end)
	hud:add_child(top)
	-- a row of the Standings pressed: the map flies there (the row does that) and the nation's window opens
	ctx.read_owner = function(id: number)
		self:select_owner(id)
	end
	-- Standings: Tab's sheet from the right edge (the outliner's RIVALS show the top of it)
	local board = Leaderboard.new(ctx)
	board.name = "Leaderboard"
	self.board = board
	board.toggled:Connect(function(_open)
		self:_request_relayout()
	end)
	hud:add_child(board)
	-- the world's news: the outliner's LOG (`feed`, the toast feed it replaced, for UIAdvisor and the draft)
	local news = NewsLog.new(ctx)
	self.feed = news
	self.news = news
	-- the war clock (`clock`): time, ages, the race, the map modes
	local clock = WarClock.new(ctx)
	clock.name = "WarClock"
	self.clock = clock
	clock.rank_provider = function()
		return board:my_rank()
	end
	top.clock_text = function()
		return clock:short_text()
	end
	hud:add_child(clock)
	-- the send panel on the clock (`send_panel`): the share an order sends, every preset a button
	local send_panel = SendPanel.new(ctx)
	send_panel.name = "SendPanel"
	self.send_panel = send_panel
	hud:add_child(send_panel)
	-- the match log at the bottom left (`log_panel`): always on, folded or hidden by the player
	local log_panel = LogPanel.new(ctx, news)
	log_panel.name = "LogPanel"
	self.log_panel = log_panel
	log_panel.resized:Connect(function()
		self:_request_relayout()
	end)
	hud:add_child(log_panel)
	-- where the attacks on you come in (`threat_marks`): marks on the map, or on the screen's edge pointing the way
	local threat_marks = ThreatMarks.new(ctx)
	threat_marks.name = "ThreatMarks"
	self.threat_marks = threat_marks
	hud:add_child(threat_marks)
	-- a depth match's armies on the map (`army_marks`)
	local army_marks = ArmyMarks.new(ctx, self)
	army_marks.name = "ArmyMarks"
	self.army_marks = army_marks
	-- the Provinces map mode's names (`province_names`)
	local province_names = ProvinceNames.new(ctx)
	province_names.name = "ProvinceNames"
	self.province_names = province_names
	hud:add_child(province_names)
	hud:add_child(army_marks)
	-- the outliner (`outliner`; `attacks` is the name UIAdvisor marks dirty)
	local outliner = Outliner.new(ctx, news)
	outliner.name = "Outliner"
	self.outliner = outliner
	self.attacks = outliner
	outliner.retreat_requested:Connect(function(aid)
		self.interact:retreat(aid)
	end)
	outliner.doctrine_wanted:Connect(function()
		outliner:set_sheet(false)
		self:_on_order_button("doctrine")
	end)
	hud:add_child(outliner)
	-- the command bar at the bottom middle (`dock`): every building and strike on show, then Doctrine and Pacts
	local dock = ActionDock.new(ctx)
	dock.name = "ActionDock"
	self.dock = dock
	dock.button_pressed:Connect(function(key)
		self:_on_order_button(key)
	end)
	dock.picked:Connect(function(kind: string, tile: number)
		ctx:sfx("click", -4.0)
		self.build_window:close(false)
		self:_on_build_pick(kind, tile)
	end)
	dock.arsenal_wanted:Connect(function(key: string)
		ctx:sfx("confirm")
		self:open_arsenal(key, "locked")
	end)
	dock.aim_kind = function()
		return if self.interact ~= nil then self.interact.aim_kind else nil
	end
	hud:add_child(dock)
	-- a phone's thumbs and the placing line (`bar`, the command bar's old name the HUD's modules use)
	local bar = OrderHub.new(ctx)
	bar.name = "Orders"
	self.bar = bar
	bar.strip = top
	bar.send_panel = send_panel
	bar.dock = dock
	bar.outliner = outliner
	bar.action:Connect(function(key)
		self:_on_order_button(key)
	end)
	bar.cancel_placement:Connect(function()
		self.interact:cancel_aim()
	end)
	hud:add_child(bar)
	-- the alerts, by urgency (`alerts`)
	local alerts = AlertRow.new(ctx, self)
	alerts.name = "Alerts"
	self.alerts = alerts
	hud:add_child(alerts)
	local spawn = SpawnOverlay.new(ctx)
	spawn.name = "Spawn"
	self.spawn = spawn
	hud:add_child(spawn)
	-- the warheads' seconds on the map, where the first will fall (its line is the alert row's red hexagon now)
	local alert = AlertBanner.new(ctx)
	alert.name = "NukeAlert"
	alert.line_off = true
	self.alert = alert
	hud:add_child(alert)
	-- every warhead fired, anywhere: who fired at whom, at the top middle (UI/LaunchCall)
	local launch_call = kit("LaunchCall").new(ctx)
	launch_call.name = "LaunchCall"
	self.launch_call = launch_call
	hud:add_child(launch_call)
	self.spectate_pill = self:_build_spectate_pill()
	hud:add_child(self.spectate_pill)
	root:add_child(hud)

	-- the selection window (a phone's sheet)
	local target_card = TargetCard.new(ctx)
	target_card.name = "TargetCard"
	target_card:set_meta("bar", bar)
	self.target_card = target_card
	bar.target_card = target_card
	hud:add_child(target_card)
	target_card.on_show = function()
		if outliner.sheet_open then
			outliner:set_sheet(false)
		end
	end
	log_panel.left_window = function()
		if ctx.compact then
			return nil
		end
		if target_card.is_open then
			return target_card:panel_rect()
		end
		-- (the doctrine draft's column down the left edge: the log steps beside it while it is open)
		return if self.draft ~= nil then self.draft:rect() else nil
	end
	local place_confirm = PlaceConfirm.new(ctx)
	place_confirm.name = "PlaceConfirm"
	place_confirm:set_meta("bar", bar)
	place_confirm.blockers = function()
		local out = {}
		for _, c in ipairs({ top.panel, top.side, board.panel, clock.panel, send_panel.panel, log_panel.panel, dock.panel }) do
			if c ~= nil and c:is_visible_in_tree() then
				table.insert(out, c:get_global_rect())
			end
		end
		for _, list in { outliner:rects(), alerts:rects(), bar:rects() } do
			for _, r in ipairs(list) do
				table.insert(out, r)
			end
		end
		return out
	end
	self.place_confirm = place_confirm
	hud:add_child(place_confirm)
	local unit_card = UnitCard.new(ctx)
	unit_card.name = "UnitCard"
	unit_card:set_meta("bar", bar)
	self.unit_card = unit_card
	hud:add_child(unit_card)
	local coach = Coach.new(ctx)
	coach.name = "Coach"
	self.coach = coach
	-- a new player's first match, step by step (UI/Tutorial, Data/Tutorial); the coach's tips wait
	local tutorial = Tutorial.new(ctx, self)
	tutorial.name = "Tutorial"
	self.tutorial = tutorial
	tutorial.step_done:Connect(function(step: number, _name: string)
		local s = ctx.session
		if s ~= nil and type(s.report) == "function" then
			s:report("tutorial", step)
		end
	end)
	tutorial.closed:Connect(function()
		coach.muted = false
	end)
	tutorial.finished:Connect(function(how: string)
		ctx:set_setting("tutorial", how)
		if how == "done" then
			-- what the steps taught is not said again as a tip
			for _, id in { "ground", "send", "stronghold", "rival" } do
				coach:complete(id)
			end
		end
		if how == "skipped" then
			local s = ctx.session
			if s ~= nil and type(s.report) == "function" then
				s:report("tutorial_skip", tutorial._i)
			end
		end
	end)
	ctx.ratio_changed:Connect(function(_r)
		if self._screen == "play" then
			coach:complete("send")
		end
	end)
	ctx.coach = coach
	coach.blockers = function()
		local out = {}
		for _, c in ipairs({
			top.panel,
			top.side,
			board.panel,
			clock.panel,
			spawn.panel,
		}) do
			if c ~= nil and c:is_visible_in_tree() then
				table.insert(out, c:get_global_rect())
			end
		end
		for _, list in { outliner:rects(), alerts:rects(), bar:rects() } do
			for _, r in ipairs(list) do
				table.insert(out, r)
			end
		end
		if target_card.is_open then
			table.insert(out, target_card:panel_rect())
		end
		-- (the doctrine draft's cards: a tip must not sit under them)
		local dr = if self.draft ~= nil then self.draft:rect() else nil
		if dr ~= nil then
			table.insert(out, dr)
		end
		return out
	end
	coach.keepout = function()
		local r = ctx:world_call("local_label_rect", {})
		if typeof(r) == "Rect" then
			return { ctx:rect_to_logical(r) }
		end
		return nil
	end
	hud:add_child(coach)
	hud:add_child(tutorial)
	-- the doctrine draft (Conquer the World): three cards when an era opens; and the era's banner
	local draft = DoctrineDraft.new(ctx, self)
	draft.name = "DoctrineDraft"
	self.draft = draft
	hud:add_child(draft)
	clock.era_changed:Connect(function(era: number)
		self:_era_banner(era)
		-- (what this age changes, once per player)
		coach:offer("age" .. tostring(era))
	end)
	self.float_layer = self:_layer("Floats")
	root:add_child(self.float_layer)
	-- touch: the ring closing in around a finger held for the menu
	local hold = HoldRing.new(ctx)
	self.hold_ring = hold
	root:add_child(self:_host(hold.gui, "HoldRing"))
	local radial = RadialMenu.new(ctx)
	self.radial = radial
	radial.bottom_limit = function(): number?
		return nil
	end
	self._radial_host = self:_host(radial.gui, "Radial")
	root:add_child(self._radial_host)
	-- the send beside the cursor: a readout over the map (input passes through)
	local readout = CursorReadout.new(ctx)
	self.readout = readout
	hud:add_child(readout.label)
	-- the Build and Warheads windows: over the HUD, under the cards; the map stays playable around them
	local build_window = BuildWindow.new(ctx)
	build_window.name = "BuildWindow"
	self.build_window = build_window
	bar.window = build_window
	build_window.picked:Connect(function(kind: string, tile: number)
		self:_on_build_pick(kind, tile)
	end)
	build_window.arsenal_wanted:Connect(function(key: string)
		ctx:sfx("confirm")
		self:open_arsenal(key, "locked")
	end)
	build_window.closed:Connect(function()
		self:_update_input_gate()
	end)
	root:add_child(build_window)
	-- the small list windows (CHANCES, Pacts, Doctrine)
	local list_popup = ListPopup.new(ctx)
	list_popup.name = "ListPopup"
	self.list_popup = list_popup
	root:add_child(list_popup)
	local tooltip = Tooltip.new(ctx)
	tooltip.name = "Tooltip"
	self.tooltip = tooltip
	ctx.tooltip = tooltip

	local title = TitleScreen.new(ctx)
	title.name = "Title"
	self.title = title
	title.play_solo:Connect(function(d)
		self:_on_play_solo(d)
	end)
	title.play_multi:Connect(function()
		ctx:session_call("join_multiplayer")
	end)
	title.vote_start:Connect(function()
		ctx:session_call("vote_start")
	end)
	title.join_lobby:Connect(function(id: string)
		ctx:sfx("click")
		ctx:session_call("join_lobby", { id })
	end)
	title.join_public:Connect(function(mode: string)
		ctx:sfx("click")
		ctx:session_call("join_public", { mode })
	end)
	title.leave_line:Connect(function()
		ctx:sfx("click")
		ctx:session_call("leave_line")
	end)
	title.party_action:Connect(function(action: string, uid: number?)
		ctx:session_call("party_action", { action, uid })
	end)
	title.show_help:Connect(function()
		self:toggle_help()
	end)
	title.open_council:Connect(function()
		self:open_settings()
	end)
	title.open_locker:Connect(function()
		self:open_locker()
	end)
	title.open_command:Connect(function()
		self:open_command()
	end)
	title.open_shop:Connect(function()
		self:open_shop()
	end)
	title.open_shop_hub:Connect(function(tab: string?)
		ctx:sfx("confirm")
		self:open_shop_hub(tab)
	end)
	title.open_roadmap:Connect(function()
		self.roadmap:open()
		self:_update_input_gate()
	end)
	title.open_starter:Connect(function()
		self:open_starter("button")
	end)
	title.open_general:Connect(function()
		self:open_general("title")
	end)
	title.open_arsenal:Connect(function()
		ctx:sfx("confirm")
		self:open_arsenal(nil, "title")
	end)
	title.pick_map:Connect(function()
		self.map_picker:set_entries(UIMaps.entries())
		self.map_picker:open(UIMaps.valid(ctx:setting("map_id", UIMaps.DEFAULT_ID)))
		self:_update_input_gate()
	end)
	title:set_map_name(UIMaps.name_of(UIMaps.valid(ctx:setting("map_id", UIMaps.DEFAULT_ID))))
	title.leave_queue:Connect(function()
		self:_award_career(0)
		ctx:session_call("leave_match")
	end)
	root:add_child(title)
	local over = GameOver.new(ctx)
	over.name = "GameOver"
	self.over = over
	over.log_provider = function()
		return self._log
	end
	over.war_report:Connect(function()
		self:open_war_report()
	end)
	over.play_again:Connect(function()
		over:close()
		self:_restart_solo(
			math.clamp(tonumber(ctx:setting("difficulty", UICtx.DEFAULT_DIFFICULTY)) or UICtx.DEFAULT_DIFFICULTY, 0, 2)
		)
	end)
	over.spectate:Connect(function()
		self:_update_input_gate()
		self:_layout()
	end)
	over.open_arsenal:Connect(function(key: string?, from: string?)
		ctx:sfx("confirm")
		self:open_arsenal(key, from or "over")
	end)
	over.to_title:Connect(function()
		self:_award_career(0)
		ctx:session_call("leave_match")
		-- (a public war's server: the results stay up until the hub takes us; Session.returning)
		if ctx.session ~= nil and ctx.session:returning() then
			over:set_returning()
		else
			over:close()
		end
	end)
	-- solo: take over the nation that eliminated you (Takeover.luau)
	self.takeover = Takeover.new(self)
	over.take_over:Connect(function()
		self.takeover:start()
	end)
	root:add_child(over)
	local pause = PauseMenu.new(ctx)
	pause.name = "GameMenu"
	self.pause = pause
	pause.closed:Connect(function()
		self:_update_input_gate()
		self:_update_pause()
	end)
	pause.restart_requested:Connect(function()
		self:_restart_solo(
			math.clamp(tonumber(ctx:setting("difficulty", UICtx.DEFAULT_DIFFICULTY)) or UICtx.DEFAULT_DIFFICULTY, 0, 2)
		)
	end)
	pause.tips_reset:Connect(function()
		coach:reset()
	end)
	pause.new_player_requested:Connect(function()
		self:replay_as_new_player()
	end)
	pause.help_requested:Connect(function()
		self:toggle_help()
	end)
	pause.college_requested:Connect(function()
		self:open_arsenal(nil, "match")
	end)
	pause.leave_requested:Connect(function()
		self:_award_career(0)
		ctx:session_call("leave_match")
	end)
	pause.labels_toggled:Connect(function(on)
		self:_set_labels(on)
	end)
	pause.music_toggled:Connect(function(on)
		ctx:set_music(on)
		self.music_toggled:Fire(on)
	end)
	pause.music_volume_changed:Connect(function(v: number, final: boolean)
		ctx:set_music_volume(v, final)
	end)
	pause.pops_toggled:Connect(function(on)
		ctx:set_pops(on)
	end)
	pause.log_hidden_toggled:Connect(function(on)
		self.log_panel:set_hidden(on)
	end)
	root:add_child(pause)
	local help = HelpOverlay.new(ctx)
	help.name = "Help"
	self.help = help
	help.closed:Connect(function()
		self.help_toggled:Fire(false)
		self:_update_input_gate()
		self:_update_pause()
	end)
	root:add_child(help)
	local picker = MapPicker.new(ctx)
	picker.name = "MapPicker"
	self.map_picker = picker
	picker.picked:Connect(function(id: string)
		ctx:set_setting("map_id", id)
		self.title:set_map_name(UIMaps.name_of(id))
	end)
	picker.closed:Connect(function()
		self:_update_input_gate()
	end)
	root:add_child(picker)
	-- the Command Center (the title's COMMAND button) and the War Report (the results screen)
	self._log = MatchLog.new(ctx)
	local command = CommandCenter.new(ctx)
	command.name = "CommandCenter"
	self.command = command
	command.closed:Connect(function()
		self:_update_input_gate()
	end)
	command.start_mission:Connect(function(key)
		self:start_mission(key)
	end)
	command.title_changed = function()
		self.title:_refresh_greeting()
	end
	root:add_child(command)
	local report = WarReport.new(ctx)
	report.name = "WarReport"
	self.war_report = report
	report.closed:Connect(function()
		self:_update_input_gate()
	end)
	root:add_child(report)
	-- the Realm (a depth match: ruler, taxes, wars, armies)
	local realm = RealmSheet.new(ctx)
	realm.name = "RealmSheet"
	self.realm = realm
	realm.closed:Connect(function()
		self:_update_input_gate()
	end)
	realm.march_wanted:Connect(function(aid)
		self.interact.army_aim = aid
		self:_on_notice("Click the land your army marches on. Right-click calls it off.", 0)
	end)
	root:add_child(realm)
	-- the Locker: cosmetic crates, skins and flags (the title's crate button)
	local locker = Locker.new(ctx)
	locker.name = "Locker"
	self.locker = locker
	locker._toast = function(_l, text: string)
		self:_on_notice(text, 0)
	end
	locker.closed:Connect(function()
		self:_update_input_gate()
	end)
	root:add_child(locker)
	-- the Arsenal: units unlocked with Stars or Robux (the title's Arsenal button, the bar's tray)
	local arsenal = Arsenal.new(ctx)
	arsenal.name = "Arsenal"
	self.arsenal = arsenal
	arsenal.closed:Connect(function()
		self:_update_input_gate()
		self:_update_pause()
		self.bar:refresh_buttons()
	end)
	root:add_child(arsenal)
	-- the Founding Grant (the title's row)
	local starter = StarterOffer.new(ctx)
	starter.name = "StarterOffer"
	self.starter = starter
	starter.ui_notice = function(text: string)
		self:_on_notice(text, 0)
	end
	starter.closed:Connect(function()
		self:_update_input_gate()
	end)
	root:add_child(starter)
	-- RoWorld General's window (the title's General button; Data/Subscription)
	local general = GeneralOffer.new(ctx)
	general.name = "GeneralOffer"
	self.general = general
	general.closed:Connect(function()
		self:_update_input_gate()
	end)
	root:add_child(general)
	-- the flag shop (the title's shop button)
	local flag_shop = FlagShop.new(ctx)
	flag_shop.name = "FlagShop"
	self.flag_shop = flag_shop
	flag_shop._toast = function(_f, text: string)
		self:_on_notice(text, 0)
	end
	flag_shop.closed:Connect(function()
		self:_update_input_gate()
	end)
	root:add_child(flag_shop)
	-- the whole shop (the title's SHOP row): it sells through the windows above
	local shop_hub = ShopHub.new(ctx)
	shop_hub.name = "ShopHub"
	shop_hub.ui = self
	self.shop_hub = shop_hub
	shop_hub.closed:Connect(function()
		self:_update_input_gate()
	end)
	root:add_child(shop_hub)
	-- opening a crate: the show above the Locker (CrateOpening.luau)
	local opening = CrateOpening.new(ctx)
	opening.name = "CrateOpening"
	self.crate_opening = opening
	locker:set_opening(opening)
	root:add_child(opening)
	-- the roadmap and every update (the title's patch notes panel)
	local roadmap = kit("Roadmap").new(ctx)
	roadmap.name = "Roadmap"
	self.roadmap = roadmap
	roadmap.closed:Connect(function()
		self:_update_input_gate()
	end)
	root:add_child(roadmap)
	-- every item's own odds, above both (the DETAILS buttons)
	local odds_view = CrateOdds.new(ctx)
	odds_view.name = "CrateOdds"
	self.crate_odds = odds_view
	locker.odds_view = odds_view
	root:add_child(odds_view)
	local busy = BusyChip.new(ctx)
	busy.name = "Busy"
	self.busy = busy
	root:add_child(busy)
	local notices = EventFeed.new(ctx, true)
	notices.name = "Notices"
	self.notices = notices
	root:add_child(notices)
	-- "territory map unavailable" card (review_code.md R2-3)
	local globe_notice = kit("GlobeNotice").new(ctx)
	globe_notice.name = "GlobeNotice"
	self.globe_notice = globe_notice
	root:add_child(globe_notice)
	root:add_child(tooltip)

	self.advisor = UIAdvisor.new(self)
	ctx.floor_held:Connect(function()
		self.advisor:on_floor_held()
	end)
	self.probe = UILayoutProbe.new(self)
	local interact = UIInteract.new(ctx)
	interact.bar = bar
	interact.tooltip = tooltip
	interact.radial = radial
	interact.float_layer = self.float_layer
	interact.ui = self
	self.interact = interact
	radial.picked:Connect(function(id, t)
		interact:on_radial(id, t)
	end)
	interact.target_card = target_card
	interact.place_confirm = place_confirm
	interact.unit_card = unit_card
	unit_card.closed:Connect(function()
		ctx:world_call("set_selected_unit", { -1 })
	end)
	place_confirm.confirmed:Connect(function()
		interact:confirm_ghost()
	end)
	place_confirm.cancelled:Connect(function()
		interact:cancel_aim()
	end)
	target_card.fire:Connect(function()
		interact:fire_from_card()
	end)
	target_card.betray:Connect(function(attack)
		interact:betray_from_card(attack)
	end)
	target_card.donate:Connect(function()
		interact:donate_from_card()
	end)
	target_card.pact:Connect(function()
		interact:pact_from_card()
	end)
	target_card.warhead:Connect(function()
		self:toggle_build("warheads")
	end)
	target_card.more_orders:Connect(function(tile: number)
		local p = ctx:tile_screen_pos(tile)
		interact:open_orders(tile, if p.X >= 0 then p else ctx:mouse_pos())
	end)
	target_card.closed:Connect(function()
		ctx:world_call("set_selected_owner", { 0 })
		ctx:world_call("set_range_mode", { ctx:base_range_mode() })
		ctx:world_call("set_range_owner", { 0 })
	end)
	self.touch_router = TouchRouter.new(self)
	self.touch_router:connect()
	local rotate_card = RotateCard.new(ctx)
	rotate_card.name = "RotateCard"
	self.rotate_card = rotate_card
	root:add_child(rotate_card)
	rotate_card.changed:Connect(function(_shown)
		self:_update_input_gate()
	end)
	interact:connect_input()
	self:_hook_buttons(root)
	if UICtx.IS_ROBLOX then
		local RunService = game:GetService("RunService")
		self._step_name = "AirfrontUI_" .. tostring(math.random(1, 1e9))
		local perf = { frames = 0, process = 0.0, kit = 0.0, max = 0.0 }
		self._perf = perf
		-- (Telemetry "slow" says how much of a slow frame the HUD's own work was)
		self.telemetry.ui_perf = perf
		-- (the frame's dt: a Studio film steps it)
		local FrameClock = require("../Map/FrameClock") :: any
		RunService:BindToRenderStep(self._step_name, Enum.RenderPriority.Camera.Value + 10, function(real_dt)
			local dt = FrameClock.dt(real_dt)
			local t0 = os.clock()
			-- _process guards each component itself; this outer guard keeps W.step (tweens, timers,
			-- layout) running even if something outside those guards throws.
			W.guard("UIRoot._process", self._process, self, dt)
			local t1 = os.clock()
			W.guard("Widgets.step", W.step, dt)
			local t2 = os.clock()
			perf.frames += 1
			perf.process += t1 - t0
			perf.kit += t2 - t1
			perf.max = math.max(perf.max, t2 - t0)
		end)
		table.insert(
			self._conns,
			root.resized:Connect(function()
				self:_layout()
			end)
		)
	end
end

--- The spectating pill's takeover button (Takeover.refresh): nil hides it.
function UIRoot._set_spec_takeover(self, info: any)
	local b = self._spec_take
	if b == nil then
		return
	end
	self._spec_take_info = info
	if info == nil then
		b:set_visible(false)
	else
		b:set_visible(true)
		b:set_disabled(info.busy == true)
		if info.saved > 0 then
			b:set_icon("check")
			b:set_text(if info.busy then "Seizing…" else "Seize (saved)")
		else
			b:set_icon("robux")
			b:set_text(if info.busy then "Seizing…" else string.format("Seize  ·  %d", info.price))
		end
	end
	self:_layout()
end

--- Solo: the player took over nation `id` (Session.take_over): back to playing, camera on it.
function UIRoot._on_took_over(self, id: number)
	local ctx = self.ctx
	if self._elim_timer ~= nil then
		self._elim_timer.cancel()
		self._elim_timer = nil
	end
	self._stats.elim = false
	self._stats.killer = 0
	self._stats.over = false
	-- (a new life: its end counts for the career too; the first life's was counted when it fell. Release audit
	-- 2026-11-07: a bought life that went on to win counted nothing.)
	self._career_state = nil
	if self._log ~= nil then
		self._log:new_life()
	end
	self._stats.kills = 0
	self._stats.peak_share = 0.0
	if self.over.is_open then
		self.over:close()
	end
	-- everything bound to "me" follows the new nation: its borders (attack / expand reach — the
	-- tracker still pointed at the fallen nation: "No border or sea route" everywhere), its structure
	-- counts (build costs), the HUD, its pending alliance requests, its attacks
	ctx.rules:recount()
	self:_bind_refresh()
	self.attacks:mark_dirty()
	self.board:mark_dirty()
	ctx:world_call("focus_owner", { id })
	ctx:sfx("start")
	self:_update_pause()
	self:_update_input_gate()
	self:_request_apply()
end

function UIRoot._build_spectate_pill(self)
	local ctx = self.ctx
	local p = GlassPanel.new(16.0, 8.0, 999, true, 16)
	local h = UITheme.hbox(12)
	p:add_child(h)
	local eye = UITheme.icon_rect("eye", 18.0, UITheme.CYAN)
	eye.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(eye)
	local v = UITheme.vbox(0)
	v.size_flags_vertical = W.SHRINK_CENTER
	v:add_child(UITheme.label("WATCHING", 13, 800, UITheme.TEXT, 2))
	self._spec_sub = UITheme.label("Move the map. Pick a nation to read it", 11, 500, UITheme.TEXT_2)
	v:add_child(self._spec_sub)
	h:add_child(v)
	-- solo: take over the nation that conquered you (Takeover.luau; hidden without an offer)
	self._spec_take = UITheme.button("Seize", "PrimaryButton", "robux", 44.0)
	self._spec_take:set_font_size(13)
	self._spec_take.size_flags_vertical = W.SHRINK_CENTER
	self._spec_take.pressed:Connect(function()
		if self.takeover ~= nil then
			self.takeover:start()
		end
	end)
	self._spec_take:set_visible(false)
	h:add_child(self._spec_take)
	self._spec_again = UITheme.button("Fight again", "PrimaryButton", "play", 44.0)
	self._spec_again:set_font_size(13)
	self._spec_again.pressed:Connect(function()
		self:_restart_solo(
			math.clamp(tonumber(ctx:setting("difficulty", UICtx.DEFAULT_DIFFICULTY)) or UICtx.DEFAULT_DIFFICULTY, 0, 2)
		)
	end)
	self._spec_again.size_flags_vertical = W.SHRINK_CENTER
	h:add_child(self._spec_again)
	local b = UITheme.button("Title", "GlassButton", "exit", 44.0)
	self._spec_leave = b
	b:set_font_size(13)
	b.size_flags_vertical = W.SHRINK_CENTER
	b.pressed:Connect(function()
		self:_award_career(0)
		ctx:session_call("leave_match")
	end)
	h:add_child(b)
	p:set_visible(false)
	return p
end

--- Connect to a signal of a duck-typed object (Session / WorldView / AudioDirector) if it has it.
function UIRoot._sig(self, obj: any, sig: string, cb: (...any) -> ())
	local s = obj[sig]
	if (type(s) == "table" and type(s.Connect) == "function") or typeof(s) == "RBXScriptSignal" then
		table.insert(self._sconns, s:Connect(cb))
	end
end

--- Button sounds (GDScript _on_node_added): click on press, soft hover on desktop. The kit tree
--- has no node_added signal, so new buttons are hooked on layout / every half second: the whole tree
--- only when a node joined it since (W.tree_serial; 2026-10-27: it walked every node of every screen,
--- a thousand and more, twice a second, for nothing new nearly every time).
function UIRoot._hook_buttons(self, n: any)
	local serial = W.tree_serial
	if n == self.root then
		if serial == self._hooked_serial then
			return
		end
		self._hooked_serial = serial
	end
	local ctx = self.ctx
	local Leaderboard = self.board and getmetatable(self.board)
	local function rec(node)
		if node._freed then
			return
		end
		if not node._sfx_hooked and node.pressed ~= nil and node.gui ~= nil and node.gui:IsA("GuiButton") then
			node._sfx_hooked = true
			local quiet = node.__row_of_leaderboard == true
			if quiet then
				node.pressed:Connect(function()
					ctx:sfx("click", -4.0)
				end)
			else
				node.pressed:Connect(function()
					ctx:sfx("click", -2.0)
				end)
				node.mouse_entered:Connect(function()
					if not node.disabled and not ctx.touch then
						ctx:sfx("hover", -14.0)
					end
				end)
			end
		end
		for _, c in ipairs(node.children or {}) do
			rec(c)
		end
		for _, c in ipairs(node._internal or {}) do
			rec(c)
		end
	end
	local _ = Leaderboard
	rec(n)
end

-- =============================================================================================
-- Session
-- =============================================================================================

function UIRoot._on_state_ready(self, s: any)
	self:_end_building()
	-- (a new state schedules the deferred rebind, which ends with the screen switch)
	self:_bind_state(s)
	if s == nil then
		self:_request_apply()
	end
end

function UIRoot._on_joined_owner(self, _id: number)
	local ctx = self.ctx
	if ctx.state ~= nil then
		-- the border scan and the HUD refresh run in the deferred rebind step (_bind_refresh)
		ctx.borders:bind(ctx.state, 0)
		ctx.rules:recount()
		self:_schedule_rebind()
	else
		self:_request_apply()
	end
end

--- The frame that delivers a new match (state_ready / joined_owner) already carries the Session's
--- last build slice and the view's rebind, and the next one the territory rebuild. The UI's own
--- rebind work (~5 ms on desktop, several times that on phones) is therefore spread over the frames
--- after them: _bind_refresh (border scan, HUD refresh) REBIND_FRAMES later, then the screen switch
--- (_apply_screen and its layout) one frame after that. Screen requests meanwhile wait for it.
UIRoot.REBIND_FRAMES = 2

function UIRoot._schedule_rebind(self)
	if self._rebind_refresh_in == nil then
		self._rebind_refresh_in = UIRoot.REBIND_FRAMES
	end
	self._rebind_apply_in = nil
end

--- True while a deferred rebind (refresh or screen switch) is pending.
function UIRoot.rebind_pending(self): boolean
	return self._rebind_refresh_in ~= nil or self._rebind_apply_in ~= nil
end

local function rebind_step(self)
	local n = self._rebind_refresh_in
	if n ~= nil then
		if n > 0 then
			self._rebind_refresh_in = n - 1
			return
		end
		self._rebind_refresh_in = nil
		self._rebind_apply_in = 1
		self:_bind_refresh()
		return
	end
	local a = self._rebind_apply_in
	if a ~= nil then
		if a > 0 then
			self._rebind_apply_in = a - 1
			return
		end
		self._rebind_apply_in = nil
		-- inside the kit step like _request_apply, so its follow-up layout (W.defer) lands next frame
		W.defer(function()
			if not self:rebind_pending() then
				self:_apply_screen()
			end
		end)
	end
end

--- Your nation's card: a phone's tap on the top strip (the crest's hover on a larger screen).
function UIRoot._toggle_stats_card(self)
	local tooltip = self.tooltip
	if tooltip:is_shown() and tooltip.place == Tooltip.Place.PINNED and tooltip:has_meta("stats") then
		tooltip:hide_tip()
		return
	end
	local spec = self.top:stats_spec()
	if spec == nil or next(spec) == nil then
		return
	end
	self.target_card:hide_card()
	local r = self.top.panel:get_global_rect()
	tooltip:show_pinned_at(spec, Vector2.new(r.Min.X + 120.0, r.Max.Y + 80.0))
	tooltip:set_meta("stats", true)
end

--- A solo match started on an outdated server is played on a fresh one (server/FreshServers;
--- 2026-10-04).
--- The server says so in workspace attribute RF_Outdated; it is asked to
--- teleport us (Session.hop_solo) and the match starts on arrival (autostart_solo). Once a session:
--- no answer within HOP_ANSWER_S, "stay", or still here HOP_TRAVEL_S after "going" starts it here.
UIRoot.HOP_ANSWER_S = 4.0
UIRoot.HOP_TRAVEL_S = 25.0

function UIRoot._hop_instead(self, difficulty: number, restart: boolean): boolean
	local ctx = self.ctx
	if not UICtx.IS_ROBLOX or self._hop_tried or self._hop ~= nil then
		return false
	end
	if workspace:GetAttribute("RF_Outdated") ~= true then
		return false
	end
	local s = ctx.session
	local map_id = UIMaps.valid(ctx:setting("map_id", UIMaps.DEFAULT_ID))
	if s == nil or type(s.hop_solo) ~= "function" or not s:hop_solo(difficulty, map_id) then
		return false
	end
	self._hop_tried = true
	self._hop = { difficulty = difficulty, restart = restart, deadline = UICtx.msec() + UIRoot.HOP_ANSWER_S * 1000 }
	self.busy:show_text("Fetching the newest version…")
	return true
end

function UIRoot._on_hop_result(self, going: boolean)
	local h = self._hop
	if h == nil then
		return
	end
	if going then
		h.deadline = UICtx.msec() + UIRoot.HOP_TRAVEL_S * 1000
	else
		self:_hop_fallback()
	end
end

--- The hop is off: the match starts on this server after all.
function UIRoot._hop_fallback(self)
	local h = self._hop
	if h == nil then
		return
	end
	self._hop = nil
	self.busy:hide_chip()
	if h.restart then
		self:_restart_solo(h.difficulty)
	else
		self:_on_play_solo(h.difficulty)
	end
end

--- Arrived from an outdated server with a solo match asked for there (the teleport's data; Main):
--- it starts as soon as the title is up.
function UIRoot.autostart_solo(self, difficulty: number, map_id: string?)
	self._hop_tried = true
	self._autostart = {
		difficulty = math.clamp(math.floor(difficulty), 0, 2),
		map_id = map_id,
		deadline = UICtx.msec() + 20000,
	}
end

function UIRoot._autostart_step(self)
	local a = self._autostart
	local ctx = self.ctx
	if a == nil then
		return
	end
	if UICtx.msec() > a.deadline or ctx:mode() == UICtx.MODE_SOLO or ctx:mode() == UICtx.MODE_MULTI then
		self._autostart = nil
		return
	end
	if self._screen ~= "title" or ctx:session_call("is_building") == true or ctx:mp_waiting() then
		return
	end
	self._autostart = nil
	if a.map_id ~= nil then
		ctx:set_setting("map_id", UIMaps.valid(a.map_id))
	end
	self:_on_play_solo(a.difficulty)
end

function UIRoot._on_play_solo(self, difficulty: number)
	local ctx = self.ctx
	-- A second tap can land after a fast build finished but before the title fades out: never
	-- start a second match over the one just built.
	if
		ctx:session_call("is_building") == true
		or ctx:mode() == UICtx.MODE_SOLO
		or UICtx.msec() - self._solo_msec < 1500
		or self._hop ~= nil
	then
		return
	end
	-- waiting in line for a public match (Quick Play): out of it first
	if self.title:public_busy() then
		ctx:session_call("leave_line")
	end
	if self:_hop_instead(difficulty, false) then
		return
	end
	self._solo_msec = UICtx.msec()
	self._mission = nil
	ctx:set_setting("difficulty", difficulty)
	ctx:sfx("click")
	ctx:session_call("start_solo", { difficulty, UIMaps.valid(ctx:setting("map_id", UIMaps.DEFAULT_ID)), self:_solo_opts() })
end

--- What a solo match starts with: the mode picked on the solo menu.
function UIRoot._solo_opts(self): any
	local Modes = UICtx.data("Modes")
	local base = self.ctx.session ~= nil and self.ctx.session.SOLO_TRIBES or nil
	local cfg = Modes.apply({ tribes = base }, self.ctx:setting("mode", Modes.DEFAULT))
	-- the start date picked on the solo menu (Data/Periods), where the map offers it
	cfg.period = UICtx.mod("TitleScreen").solo_period(self.ctx)
	-- the war's depth picked there (docs/DEPTH_DESIGN.md): Long or Quick, or the classic war
	cfg.depth = UICtx.mod("TitleScreen").solo_depth(self.ctx)
	return { config = cfg, tribes = cfg.tribes }
end

--- A fresh solo match from inside one: the results screen's "Play again", the game menu's "Restart
--- match" and the spectate pill's "Play again". DELIBERATE DEVIATION: ui_root.gd routed these through
--- _on_play_solo, whose "already in solo" guard (meant for a second tap on the title) made all three
--- dead buttons. Session.start_solo builds the new world in the background (the old one stays frozen
--- meanwhile, with the "Deploying a new world…" chip) and swaps it in on state_ready.
function UIRoot._restart_solo(self, difficulty: number)
	local ctx = self.ctx
	if
		ctx:mode() ~= UICtx.MODE_SOLO
		or ctx:session_call("is_building") == true
		or UICtx.msec() - self._solo_msec < 1500
		or self._hop ~= nil
	then
		return
	end
	if self:_hop_instead(difficulty, true) then
		return
	end
	self._solo_msec = UICtx.msec()
	self:_award_career(0)
	ctx:sfx("click")
	self._restart_pending = true
	-- (again on a War Room mission is that mission again)
	local Missions = UICtx.data("Missions")
	local m = if self._mission ~= nil then Missions.LIST[Missions.INDEX[self._mission] or 0] else nil
	if m ~= nil then
		ctx:session_call("start_solo", { m.difficulty, m.map, self:_mission_opts(m) })
	else
		ctx:set_setting("difficulty", difficulty)
		ctx:session_call("start_solo", { difficulty, UIMaps.valid(ctx:setting("map_id", UIMaps.DEFAULT_ID)), self:_solo_opts() })
	end
	self:_update_pause()
end

--- Session builds new worlds in the background: acknowledge instantly, swap when state_ready fires.
function UIRoot._on_building(self, mode: number)
	self._building = true
	local what = if mode == UICtx.MODE_TITLE then "To the title…" else "The map is being drawn…"
	self.title:set_building(mode ~= UICtx.MODE_TITLE)
	self.over:set_building(mode ~= UICtx.MODE_TITLE)
	if mode ~= UICtx.MODE_TITLE or self._screen ~= "title" then
		self.busy:show_text(what)
	end
end

function UIRoot._end_building(self)
	self._restart_pending = false
	if not self._building then
		return
	end
	self._building = false
	self.title:set_building(false)
	self.over:set_building(false)
	self.busy:hide_chip()
end

function UIRoot._bind_state(self, s: any)
	local ctx = self.ctx
	for _, c in ipairs(self._conns_state or {}) do
		c:Disconnect()
	end
	self._conns_state = {}
	ctx.state = s
	-- the mode this state was built for (Session.state_mode): a title backdrop that finishes while
	-- the player waits for a multiplayer match must not pass for the match
	local sm = if ctx.session ~= nil then tonumber(ctx.session.state_mode) else nil
	ctx.state_mode = sm or ctx:mode()
	W.guard("Telemetry.bind", self.telemetry.bind, self.telemetry, s)
	self:_reset_match()
	-- a new match: the Attack bar starts at its default and the leaderboard closed (not the state a
	-- resync hands over mid-match)
	if not (ctx.session ~= nil and ctx.session.state_is_resync == true) then
		ctx:reset_ratio()
		ctx.troop_floor = nil -- (a new player's floor arms again in this match: UIAdvisor.check_floor)
		ctx.alive_from_tick = nil
		if self.board.expanded then
			self.board:close_for_match()
			self.leaderboard_toggled:Fire(false)
			self:_request_relayout()
		end
	end
	local adv = self.advisor
	table.clear(adv._ship_state)
	table.clear(adv._ship_vet)
	table.clear(adv._sam_by_nuke)
	table.clear(adv._volleys)
	table.clear(adv._shells)
	if self.unit_card ~= nil then
		self.unit_card:hide_card()
	end
	if s == nil then
		return
	end
	local function c(name: string, cb: (...any) -> ())
		local sig = s[name]
		if type(sig) == "table" and sig.Connect then
			table.insert(self._conns_state, sig:Connect(cb))
		end
	end
	local bar = self.bar
	c("tiles_changed", function(changed)
		ctx.borders:on_tiles_changed(changed)
		adv:on_tiles_changed(changed)
	end)
	c("stats_changed", function()
		adv:track_stats()
		adv:check_renewals()
		if bar.visible then
			bar:refresh()
		end
		self.board:mark_dirty()
	end)
	c("owner_eliminated", function(id, killer)
		adv:on_owner_eliminated(id, killer)
	end)
	c("structure_added", function(sid)
		adv:on_structure_added(sid)
	end)
	c("structure_changed", function(sid, old)
		local st = ctx.state.structures[sid]
		if st ~= nil and ctx.rules:on_structure(st.kind, old, st.owner) then
			bar:refresh_buttons()
		end
		-- a building of yours taken: a red alert while it is news
		if st ~= nil and old == ctx:me() and old ~= 0 and st.owner ~= old then
			local who = if st.owner ~= 0 and ctx.state:get_owner(st.owner) ~= nil then ctx.state:owner_name(st.owner) else "the enemy"
			self.alerts:push({ key = "lost:" .. sid, kind = "lost", focus_tile = st.tile, owner = st.owner, line = string.format("You lost a %s to %s", Defs.STRUCT_TITLES[st.kind] or "building", who) })
		end
	end)
	c("structure_removed", function(sid)
		local st2 = ctx.state.structures[sid]
		if st2 ~= nil and ctx.rules:on_structure(st2.kind, st2.owner, 0) then
			bar:refresh_buttons()
		end
		if st2 ~= nil and st2.owner == ctx:me() and ctx:me() ~= 0 then
			self.alerts:push({ key = "lost:" .. sid, kind = "lost", focus_tile = st2.tile, line = string.format("Your %s was destroyed", Defs.STRUCT_TITLES[st2.kind] or "building") })
		end
	end)
	c("structure_leveled", function(sid)
		local sl = ctx.state.structures[sid]
		if sl ~= nil and sl.owner == ctx:me() then
			bar:refresh_buttons() -- levels count toward the next price
		end
	end)
	c("unit_added", function(uid)
		adv:on_unit_added(uid)
	end)
	c("sam_launched", function(id)
		adv:on_sam_launched(id)
	end)
	c("shell_fired", function(id)
		adv:on_shell_fired(id)
	end)
	c("shell_impact", function(id, hit)
		adv:on_shell_impact(id, hit)
	end)
	c("unit_removed", function(uid, reason)
		adv:on_unit_removed(uid, reason)
	end)
	for _, sig_name in ipairs({ "unit_state_changed", "unit_hp_changed", "unit_veterancy_changed" }) do
		c(sig_name, function(uid)
			adv:on_unit_changed(uid)
		end)
	end
	c("unit_removed", function(uid, _reason)
		local u = ctx.state.units[uid]
		if u ~= nil and ctx.rules:on_unit(u.kind, u.owner, -1) then
			bar:refresh_buttons()
		end
	end)
	c("nuke_launched", function(uid)
		adv:on_nuke_launched(uid)
		-- (World Tension counts the warheads that flew)
		ctx.warheads_flown = (ctx.warheads_flown or 0) + 1
	end)
	c("nuke_detonated", function(uid, kind, tile, radius, owner)
		adv:on_nuke_detonated(uid, kind, tile, radius, owner)
	end)
	c("attack_started", function(aid)
		adv:on_attack_started(aid)
	end)
	c("attack_updated", function(aid)
		self:_on_attack_touched(aid)
	end)
	c("attack_ended", function(aid)
		self:_on_attack_touched(aid)
	end)
	c("alliance_requested", function(from, to)
		adv:on_alliance_requested(from, to)
	end)
	c("alliance_request_closed", function(from, to)
		adv:on_alliance_request_closed(from, to)
	end)
	c("depth_event", function(e)
		adv:on_depth_event(e)
	end)
	c("alliance_changed", function(a, b, formed, traitor, expired)
		adv:on_alliance_changed(a, b, formed, traitor, expired)
	end)
	c("traitor_marked", function(_id, _until)
		self.board:mark_dirty()
	end)
	c("doctrine_changed", function()
		self.draft:refresh()
		self:relayout()
	end)
	c("edict_changed", function(owner)
		self._log:on_edict(owner)
		self.draft:refresh()
		self:relayout()
	end)
	c("world_event_changed", function(index)
		self._log:on_world_event(index)
		self:_world_event_banner(index)
		self.draft:refresh()
		self:relayout()
	end)
	c("nemesis_changed", function(person, nation)
		if person == ctx:me() and nation > 0 then
			ctx:sfx("confirm", -6.0)
			if ctx.state ~= nil then
				self.coach:offer("nemesis", function()
					local st = ctx.state
					return if st ~= nil and st:get_owner(nation) ~= nil then ctx:tile_screen_pos(st:label_tile(nation)) else Vector2.new(-1, -1)
				end, ctx.state:owner_name(nation))
			end
		end
		self._log:on_nemesis(person, nation)
	end)
	c("ticked", function(tick)
		if self._log.state ~= ctx.state then
			self._log:reset(ctx.state)
		end
		self._log:on_tick(tick)
	end)
	c("structure_added", function(sid)
		self._log:on_structure(sid)
		local st = ctx.state.structures[sid]
		if st ~= nil and st.owner == ctx:me() and Defs.STRUCT_NAMES[st.kind] ~= nil then
			self.alerts:on_built(Defs.STRUCT_NAMES[st.kind])
		end
	end)
	c("nuke_launched", function(uid)
		self._log:on_nuke(uid)
	end)
	c("owner_eliminated", function(id, killer)
		self._log:on_eliminated(id, killer)
		if id == ctx:me() and id ~= 0 then
			self:_award_career(0)
		end
	end)
	c("message", function(to, cat, text)
		adv:on_message(to, cat, text)
	end)
	c("phase_changed", function(phase, left)
		self:_on_phase_changed(phase, left)
	end)
	c("game_over", function(winner, reason)
		adv:on_game_over(winner, reason)
		self:_award_career(winner)
	end)
	c("owner_spawned", function(id, tile)
		self:_on_owner_spawned(id, tile)
	end)
	-- cheap now: the tracker forgets the previous match (its events stop), the rule counts are
	-- current; the full border scan waits for _bind_refresh
	ctx.borders:bind(s, 0)
	ctx.rules:recount()
	ctx.play_start_tick = -1.0
	if s.phase ~= Defs.PHASE_SPAWN then
		-- Joined a running match. time_limit_ticks is absolute (= start of play + the limit), so the
		-- start of play follows exactly; without a limit fall back to the lobby clock.
		if (s.time_limit_ticks or 0) > 0 then
			ctx.play_start_tick = math.max(0.0, s.time_limit_ticks - ctx:match_limit_s() * Defs.TICK_RATE)
		elseif ctx:mode() == UICtx.MODE_MULTI then
			ctx.play_start_tick = math.max(0.0, s.tick - (tonumber(ctx:lobby().elapsed_s) or 0.0) * Defs.TICK_RATE)
		else
			ctx.play_start_tick = 0.0
		end
	end
	self:_schedule_rebind()
end

--- The expensive half of a (re)bind, run a few frames after state_ready (see REBIND_FRAMES): the
--- local player's border scan, the HUD refresh and pending alliance requests. The screen switch
--- follows one frame later.
function UIRoot._bind_refresh(self)
	local ctx = self.ctx
	local s = ctx.state
	if s == nil then
		return
	end
	local bar = self.bar
	self.advisor:track_stats()
	ctx.borders:bind(s, s.local_owner)
	self.clock:on_bind()
	self.draft:refresh()
	self.spawn:on_phase(if s.phase == Defs.PHASE_SPAWN then (s.phase_ticks_left or 0) else 0)
	bar:refresh(false)
	self.top:refresh()
	self.board:refresh()
	self.outliner:mark_dirty()
	self.alerts:refresh()
	ctx.state_bound:Fire()
end

--- Attack events arrive for every war on the planet; only ours matter to the panel.
function UIRoot._on_attack_touched(self, aid: number)
	local ctx = self.ctx
	local a = if ctx.state ~= nil then ctx.state.attacks[aid] else nil
	if a ~= nil and ctx:me() ~= 0 and (a.attacker == ctx:me() or a.target == ctx:me()) then
		self.outliner:mark_dirty()
	end
end

function UIRoot._reset_match(self)
	local ctx = self.ctx
	self.news:clear()
	self.outliner:reset()
	self.alerts:reset()
	self.build_window:close(false)
	self.list_popup:close()
	self.readout:hide()
	self.target_card:hide_card()
	ctx.warheads_flown = 0
	self.coach:clear()
	self.advisor:reset()
	ctx:set_paused(false)
	self.alert:clear()
	if self.launch_call ~= nil then
		self.launch_call:clear()
	end
	self.interact:cancel_aim(false)
	self.radial:close(false)
	self.tooltip:hide_tip()
	if self.over.is_open then
		self.over:close()
	end
	if self._elim_timer ~= nil then
		self._elim_timer.cancel()
	end
	self._elim_timer = nil
	self._stats =
		{ peak_share = 0.0, max_troops = 0, kills = 0, duration_s = 0.0, over = false, elim = false, killer = 0 }
	ctx:world_call("set_selected_owner", { 0 })
end

--- Elimination curtain after `sec` (UIAdvisor).
function UIRoot._start_elim_timer(self, sec: number, killer: number)
	if self._elim_timer ~= nil then
		self._elim_timer.cancel()
	end
	local h
	h = W.timer(sec, function()
		h.done = true
		self.advisor:on_elim_timeout(killer)
	end)
	self._elim_timer = h
end

function UIRoot._elim_timer_pending(self): boolean
	local h = self._elim_timer
	return h ~= nil and not h.cancelled and not h.done
end

-- =============================================================================================
-- GameState events
-- =============================================================================================

function UIRoot._on_notice(self, text: string, severity: number)
	local cat = Defs.MSG_INFO
	if severity == 1 then
		cat = Defs.MSG_BAD
	elseif severity == 2 then
		cat = Defs.MSG_ALERT
	end
	self.notices:toast(cat, text)
	self.ctx:sfx(if severity == 2 then "deny" else "toast", -4.0)
end

function UIRoot._on_phase_changed(self, phase: number, ticks_left: number)
	local ctx = self.ctx
	self.clock:on_phase(phase, ticks_left)
	if phase == Defs.PHASE_SPAWN then
		self.spawn:on_phase(ticks_left)
	end
	if phase == Defs.PHASE_PLAYING and ctx.play_start_tick < 0.0 and ctx.state ~= nil then
		ctx.play_start_tick = ctx.state.tick
	end
	if phase == Defs.PHASE_PLAYING and self._screen == "spawn" and ctx:in_match() and not ctx:needs_spawn() then
		ctx:sfx("start")
		-- After the HUD has switched to play (and the globe's safe area follows), so the camera
		-- push-in and the banner use the final layout.
		self:_request_apply()
		W.defer(function()
			W.defer(function()
				self.advisor:war_begins()
			end)
		end)
		return
	end
	self:_request_apply()
end

function UIRoot._on_owner_spawned(self, id: number, _tile: number)
	local ctx = self.ctx
	if id == ctx:me() and id ~= 0 then
		self.spawn:refresh()
		self:_request_apply()
		-- landed once play had begun (placed automatically after not picking, or a late landing):
		-- the camera goes to the new nation, and the start sound the others heard plays now
		if ctx.state ~= nil and ctx.state.phase == Defs.PHASE_PLAYING and self._screen == "spawn" then
			ctx:world_call("focus_owner", { id })
			ctx:sfx("start")
		end
	end
end

-- =============================================================================================
-- Screens
-- =============================================================================================

function UIRoot._request_apply(self)
	if self._apply_pending then
		return
	end
	self._apply_pending = true
	W.defer(function()
		if self:rebind_pending() then
			-- a deferred rebind is in flight: its last step applies the screen
			self._apply_pending = false
			return
		end
		self:_apply_screen()
	end)
end

function UIRoot._compute_screen(self): string
	local ctx = self.ctx
	local m = ctx:mode()
	if ctx.session == nil or m == UICtx.MODE_TITLE or ctx.state_mode ~= m or ctx.state == nil then
		return "title"
	end
	local ph = ctx.state.phase
	if ph == Defs.PHASE_SPAWN then
		return "spawn"
	elseif ph == Defs.PHASE_PLAYING then
		return if ctx:needs_spawn() then "spawn" else "play"
	end
	return "over"
end

function UIRoot._apply_screen(self)
	local ctx = self.ctx
	self._apply_pending = false
	local scr = self:_compute_screen()
	local prev = self._screen
	self._screen = scr
	local changed = scr ~= prev
	local in_game = scr ~= "title"
	local alive = ctx:alive_player()
	if changed then
		self.radial:close(false)
		self.tooltip:hide_tip()
		self.target_card:hide_card()
		self.interact:cancel_aim(false)
		self.screen_changed:Fire(scr)
		-- back on the title from the tutorial's match: it is over
		if scr == "title" and self.tutorial ~= nil and self.tutorial.active then
			self.tutorial:stop("left")
		end
	end
	if scr == "title" then
		-- Queued for multiplayer: mode is already MULTI but no match state yet, so keep the title's calm map;
		-- its shot frames the part of the map right of the column.
		ctx:world_call("set_attract_mode", { true, ctx:rect_to_view(Rect.new(0, 0, TitleScreen.nav_width(ctx), 1)).Width })
	end
	-- Title
	local title = self.title
	if scr == "title" then
		if changed or not title.visible then
			title:set_visible(true)
			title:on_show()
			self.telemetry:title_shown()
		end
		-- (the settings page may stand open over the title; the game menu goes when the title comes)
		if self.pause.is_open and (changed or self.pause:page() ~= "settings") then
			self.pause:close()
		end
		if self.over.is_open then
			self.over:close()
		end
	elseif title.visible and changed then
		self:_close_sheets()
		title:hide_animated()
	end
	-- Territory labels stay off over the cinematic title globe.
	ctx:world_call("set_labels_visible", { self.labels_on and in_game })
	-- HUD
	self.hud:set_visible(in_game)
	self.spawn:set_visible(scr == "spawn")
	local playing = scr == "play" and alive
	self.top:set_visible(playing and not self.over.is_open)
	if self.over.is_open then
		self.tooltip:hide_tip()
	end
	self.bar:set_visible(playing)
	self.alerts:set_visible(playing and not self.over.is_open)
	self.clock:set_visible((scr == "play" or scr == "over") and not self.over.is_open)
	self.send_panel:set_visible(playing and not self.over.is_open)
	-- (only while you play: the end screen's buttons stand where it would)
	self.log_panel:set_visible(playing and not self.over.is_open)
	self.threat_marks:set_visible(playing and not self.over.is_open)
	self.army_marks:set_visible(playing and not self.over.is_open and self.ctx.state ~= nil and self.ctx.state.depth ~= nil)
	self.dock:set_visible(playing and not self.over.is_open)
	if changed or not playing then
		self.build_window:close(false)
		self.list_popup:close()
		self.readout:hide()
	end
	self.spectate_pill:set_visible(in_game and scr ~= "spawn" and not alive and not self.over.is_open)
	self.board:set_visible(in_game and scr ~= "spawn")
	self.outliner:set_visible(playing)
	self.coach:set_visible((scr == "play" or scr == "spawn") and not self.over.is_open)
	self.interact.enabled = scr == "spawn" or scr == "play"
	self:_layout()
	W.defer(function()
		self:_layout()
	end)
	if changed then
		if scr == "spawn" then
			self.spawn:on_show()
			self.advisor:spawn_view()
		elseif scr == "play" then
			if prev == "spawn" or prev == "title" then
				W.slide_in(self.top.panel, Vector2.new(0, -40), 0.1, 0.5)
				W.slide_in(self.outliner.panel, Vector2.new(40, 0), 0.2, 0.5)
				W.slide_in(self.clock.panel, Vector2.new(40, 0), 0.25, 0.5)
				W.slide_in(self.send_panel.panel, Vector2.new(40, 0), 0.22, 0.5)
				W.slide_in(self.log_panel.panel, Vector2.new(-40, 0), 0.25, 0.5)
			end
			self.bar:refresh(false)
			self.board:refresh()
			self.top:refresh()
			self.clock:refresh()
			self.outliner:mark_dirty()
		end
	end
	self:_play_music(scr)
	if scr == "over" and not self.over.is_open and not self._stats.over and ctx.state ~= nil then
		self.advisor:on_game_over(ctx.state.winner, ctx.state.over_reason)
	end
	self:_update_input_gate()
	self:_hook_buttons(self.root)
end

function UIRoot._play_music(self, _scr: string)
	self:_update_music()
end

--- The soundtrack's mood for the moment (MusicMood); polled, and on every screen change.
function UIRoot._update_music(self)
	local ctx = self.ctx
	local st = ctx.state
	local scr = self._screen
	if scr == "" then
		return -- (booting: AudioDirector already opens with the title music)
	end
	local me = if scr ~= "title" and ctx:in_match() then ctx:me() else 0
	local my = if me ~= 0 then ctx:my() else nil
	local fighting, struck = false, false
	if scr == "play" then
		fighting, struck = MusicMood.fighting(st, me)
	end
	local mood = self._music:mood({
		screen = scr,
		waiting = ctx:mp_waiting(),
		me = me,
		alive = my == nil or my.alive ~= false,
		winner = if st ~= nil then (tonumber(st.winner) or 0) else 0,
		fighting = fighting,
		struck = struck,
	}, os.clock())
	ctx:set_music_mood(mood)
end

function UIRoot._update_input_gate(self)
	local ctx = self.ctx
	local modal = self.help.is_open
		or self.pause.is_open
		or self.over.is_open
		or self.map_picker.is_open
		or (self.locker ~= nil and self.locker.is_open)
		or (self.command ~= nil and self.command.is_open)
		or (self.war_report ~= nil and self.war_report.is_open)
		or (self.realm ~= nil and self.realm.is_open)
		or (self.flag_shop ~= nil and self.flag_shop.is_open)
		or (self.shop_hub ~= nil and self.shop_hub.is_open)
		or (self.roadmap ~= nil and self.roadmap.is_open)
		or (self.arsenal ~= nil and self.arsenal.is_open)
		or (self.starter ~= nil and self.starter.is_open)
		or (self.general ~= nil and self.general.is_open)
	ctx:set_world_input(not modal and not self.rotate_card.visible and not self.radial.is_open)
	self.draft:set_visible(not self.over.is_open)
	self.coach:set_visible(
		self.hud.visible and (self._screen == "play" or self._screen == "spawn") and not self.over.is_open
	)
	self.interact.enabled = not modal
		and not self.rotate_card.visible
		and (self._screen == "spawn" or self._screen == "play")
	self.spectate_pill:set_visible(
		self.hud.visible and self._screen ~= "spawn" and not ctx:alive_player() and not self.over.is_open
	)
	self._spec_again:set_visible(ctx:mode() == UICtx.MODE_SOLO)
	-- a public match's own server: leaving goes back to a hub (the title with the lobby list)
	self._spec_leave:set_text(if ctx:mode() == UICtx.MODE_MULTI then "Leave" else "Title")
	local killer = self._stats.killer or 0
	if ctx:mode() == UICtx.MODE_MULTI and ctx:me() == 0 and ctx.state ~= nil then
		self._spec_sub:set_text("You're watching · drag the map, click a nation")
	elseif self._stats.elim and ctx.state ~= nil then
		self._spec_sub:set_text(
			if killer ~= 0
				then string.format("%s took your land · the war goes on", ctx.state:owner_name(killer))
				else "You are out · they fight on"
		)
	else
		self._spec_sub:set_text("Move the map. Pick a nation to read it")
	end
end

--- Solo freezes the simulation while help or the game menu is open.
function UIRoot._update_pause(self)
	local ctx = self.ctx
	local want = (
		self.help.is_open
		or self.pause.is_open
		or (self.takeover ~= nil and self.takeover:pending())
		or (self.arsenal ~= nil and self.arsenal.is_open)
	)
		and ctx:mode() == UICtx.MODE_SOLO
		and ctx:in_match()
		and ctx.state ~= nil
		and ctx.state.phase ~= Defs.PHASE_OVER
	-- A solo restart is building: the match being replaced stays frozen until the new world swaps in.
	ctx:set_paused(want or (self._restart_pending and ctx:mode() == UICtx.MODE_SOLO))
end

function UIRoot._set_labels(self, on: boolean)
	self.labels_on = on
	self.ctx:set_setting("labels", on)
	self.ctx:world_call("set_labels_visible", { on })
	self.labels_toggled:Fire(on)
end

-- =============================================================================================
-- Layout
-- =============================================================================================

function UIRoot._safe_insets(self): any
	local d = self.debug_insets
	if d.x >= 0.0 then
		return d
	end
	return self.probe:safe_insets()
end

--- Recompute every panel position (viewport, safe area, touch or layout mode changed).
function UIRoot.relayout(self)
	self:_layout()
end

local function insets_equal(a: any, b: any): boolean
	return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w
end

function UIRoot._layout(self)
	local root = self.root
	if root == nil then
		return
	end
	local ctx = self.ctx
	local vp = root.vp
	ctx.vp = vp
	ctx:update_origin()
	ctx.insets = self:_safe_insets()
	self._last_vp = vp
	self._last_insets = ctx.insets
	ctx.compact = vp.Y < 560.0 or vp.X < 900.0
	-- Studio: workspace attribute AF_FORCE_COMPACT previews the phone layout on a desktop viewport
	if not ctx.compact and UICtx.IS_ROBLOX and workspace:GetAttribute("AF_FORCE_COMPACT") == true then
		ctx.compact = game:GetService("RunService"):IsStudio()
	end
	-- (and AF_FORCE_DESKTOP the desktop layout on Studio's small game view, squeezed)
	if ctx.compact and UICtx.IS_ROBLOX and workspace:GetAttribute("AF_FORCE_DESKTOP") == true then
		ctx.compact = not game:GetService("RunService"):IsStudio()
	end
	ctx.wide = vp.X >= 1420.0
	if self.debug_touch >= 0 then
		ctx.touch = self.debug_touch == 1
	elseif UICtx.IS_ROBLOX and workspace:GetAttribute("AF_FORCE_TOUCH") == true then
		-- Studio: preview the touch HUD (tray, place confirm, …) with the mouse
		ctx.touch = ctx.touch or game:GetService("RunService"):IsStudio()
	end
	ctx.reserved_top_left = self.probe:airship_reserved()
	UITheme.min_font_size = if ctx.touch then 12 else 0
	UITheme.touch_min = if ctx.touch then 44 else 0
	self.title:apply_layout()
	self.top:apply_layout()
	self.log_panel:apply_layout()
	self.clock:apply_layout()
	self.send_panel:apply_layout()
	self.dock:apply_layout()
	self.spawn:apply_layout()
	self.bar:apply_layout()
	self.outliner:apply_layout()
	self.alerts:apply_layout()
	self.build_window:apply_layout()
	if self.list_popup.is_open then
		self.list_popup:place()
	end
	if self.target_card.is_open then
		self.target_card:place()
	end
	-- Standings: a sheet from the right edge.
	local board = self.board
	board:apply_layout()
	-- The line slot: one plain line (an era, a world event) under the alert row, beside the left window's column; a phone's
	-- runs under its strip, short of the alerts down the right.
	do
		local r = ctx.reserved_top_left
		local l = FrameRules.layout(vp, ctx.compact, ctx.insets, FrameRules.box(r.Min.X, r.Min.Y, r.Max.X, r.Max.Y), {})
		if self.spawn.visible then
			local sr = self.spawn.panel:get_global_rect()
			ctx.line_top = sr.Max.Y + 6.0
		elseif ctx.compact then
			ctx.line_top = l.strip.y1 + 8.0
		else
			ctx.line_top = l.alerts.y1 + 8.0
		end
		ctx.line_right = nil
		if ctx.compact then
			ctx.line_left = l.popup.x0
			ctx.line_max_w = math.max(200.0, l.popup.x1 - l.popup.x0)
		else
			ctx.line_left = l.popup.x0
			ctx.line_max_w = math.min(560.0, l.popup.x1 - l.popup.x0)
		end
		-- (what stands past the left edge: nothing, now the spine is gone; counsel keeps to the safe inset)
		ctx.rail_w = ctx.insets.x
	end
	local bar = self.bar
	-- (on the title a sheet's head is at the top, the War Room's and the College's: the notices start under it, or a
	-- "+50 Renown claimed" lay over the War Room's subtitle)
	local notices_top = if self._screen ~= "title"
		then ctx.insets.y + (if ctx.compact then 70.0 else 96.0)
		else ctx.insets.y + (if ctx.compact then 56.0 else 64.0)
	if self._screen ~= "title" and self.top.visible and not ctx.compact then
		-- (under the strip and its alert row)
		notices_top = math.max(notices_top, self.top:bottom_edge() + FrameRules.ALERT + 24.0)
	end
	self.notices:apply_layout_top(notices_top)
	self.coach:apply_layout()
	self.tutorial:apply_layout()
	do
		-- the doctrine draft: the pop-up place, from under the alert row (and the tutorial's card) to the foot
		local top_y = (if self.top.visible then self.top:bottom_edge() + FrameRules.ALERT + 8.0 else 12.0 + ctx.insets.y) + 12.0
		local tcard = self.tutorial._card
		-- (under the tutorial's line when it stands in its slot at the left; beside a spot on the map it is out of the way)
		if tcard ~= nil and tcard.visible and self.tutorial._bottom ~= nil then
			top_y = math.max(top_y, self.tutorial._bottom + 10.0)
		end
		local bottom_y = (if bar.visible then bar:top_edge() else vp.Y - ctx.insets.w) - 12.0
		self.draft:apply_layout(top_y, bottom_y)
	end
	-- the territory notice sits top-left under the top bar, below panels reaching that corner
	self.globe_notice:apply_layout({ self.top.panel, self.spawn.panel, self.title._head })
	local sp = self.spectate_pill
	self:_layout_alert()
	local sb = 14.0 + ctx.insets.w
	sp.anchor_left, sp.anchor_right, sp.anchor_top, sp.anchor_bottom = 0.5, 0.5, 1.0, 1.0
	sp.grow_horizontal = W.GROW_BOTH
	sp.grow_vertical = W.GROW_BEGIN
	sp.offset_top = -sb
	sp.offset_bottom = -sb
	sp.offset_left = 0
	sp.offset_right = 0
	UITheme.fix_width(self._spec_sub, if ctx.compact then 250.0 else 330.0, W.ALIGN_LEFT, false)
	sp:reset_size()
	self.help:apply_layout()
	self.pause:apply_layout()
	self.map_picker:apply_layout()
	if self.locker ~= nil and self.locker.is_open then
		self.locker:apply_layout()
		if self.command.is_open then
			self.command:apply_layout()
		end
		if self.war_report.is_open then
			self.war_report:apply_layout()
		end
		if self.realm ~= nil and self.realm.is_open then
			self.realm:apply_layout()
		end
	end
	if self.flag_shop ~= nil and self.flag_shop.is_open then
		self.flag_shop:apply_layout()
	end
	if self.roadmap ~= nil and self.roadmap.is_open then
		self.roadmap:apply_layout()
	end
	if self.shop_hub ~= nil and self.shop_hub.is_open then
		self.shop_hub:apply_layout()
	end
	if self.arsenal ~= nil and self.arsenal.is_open then
		self.arsenal:apply_layout()
	end
	if self.general ~= nil and self.general.is_open then
		self.general:apply_layout()
	end
	if self.starter ~= nil and self.starter.is_open then
		self.starter:apply_layout()
	end
	if self.crate_opening ~= nil then
		self.crate_opening:apply_layout()
	end
	if self.crate_odds ~= nil and self.crate_odds.is_open then
		self.crate_odds:apply_layout()
	end
	if self.over.is_open then
		self.over:apply_layout()
	end
	if UITheme.min_font_size > 0 then
		self.probe:enforce_min_font(root)
	end
	self.rotate_card:refresh()
	ctx:fit_canvas(self.radial.gui)
	self.probe:update_world_safe_area()
	ctx.layout_changed:Fire()
end

--- A finished match pays the commander's career (Data/Career: cosmetic XP, once a match): the feed says
--- how much and, when the rank rose, which.
function UIRoot._award_career(self, winner: number)
	local ctx = self.ctx
	local s = ctx.state
	local me = ctx:me()
	if s == nil or me == 0 or self._career_state == s or self._log == nil or self._log.state ~= s then
		return
	end
	if s.phase ~= Defs.PHASE_PLAYING and s.phase ~= Defs.PHASE_OVER then
		return
	end
	self._career_state = s
	local Career = UICtx.data("Career")
	local Progress = UICtx.data("Progress")
	local saved = ctx:session_call("load_settings", { Career.SECTION })
	local won = winner == me
		or (type(s.is_team_game) == "function" and s:is_team_game() and (s.winner_team or 0) ~= 0 and s:team_of(me) == s.winner_team)
	local sess = ctx.session
	local report = self._log:report(won, {
		peak = if self._stats ~= nil then self._stats.peak_share else nil,
		kills = if self._stats ~= nil then self._stats.kills else 0,
		difficulty = if sess ~= nil and ctx:mode() == UICtx.MODE_SOLO then sess.difficulty else nil, -- (a public war isn't a Warlord one: release audit 2026-11-07)
		mission = if ctx:mode() == UICtx.MODE_SOLO then self._mission else nil,
		-- walked away from a war still going, alive: it pays its XP but is no finished match for orders
		left = s.phase == Defs.PHASE_PLAYING and winner == 0 and self._log.eliminated_at == nil,
	})
	local r = Progress.after_match(saved, report, Progress.day_of(Progress.now()))
	if won then
		self:_ask_notifications()
	end
	r.mission = report.mission and UICtx.data("Missions").LIST[UICtx.data("Missions").INDEX[report.mission]].name or nil
	self._last_result = r
	if r.gained <= 0 then
		return
	end
	ctx:session_call("save_settings", { Career.SECTION, r.career })
	-- (what it earned in Renown: the server checks it, Data/Claims)
	ctx:session_call("sync_claims", {})
	self.title:_refresh_greeting()
	-- a results screen is on its way: the career goes on its War Report button, and the report has the detail
	self.over:set_career(r)
	if report.eliminated or s.phase == Defs.PHASE_OVER then
		return
	end
	local text = string.format("Career: +%d XP · %s", r.gained, string.upper(r.rank.name))
	if r.promoted then
		text ..= " · PROMOTED"
	end
	self:_on_notice(text, 0)
	if r.mission ~= nil then
		self:_on_notice(string.format("%s: %d of 3 laurels", r.mission, r.stars), 0)
	end
end

--- A War Room mission (Data/Missions): the same road as PLAY SOLO, with the mission's own map, difficulty and rules.
function UIRoot.start_mission(self, key: string)
	local ctx = self.ctx
	local Missions = UICtx.data("Missions")
	local m = Missions.LIST[Missions.INDEX[key] or 0]
	if m == nil or ctx:session_call("is_building") == true or self._hop ~= nil then
		return
	end
	if self.title:public_busy() then
		ctx:session_call("leave_line")
	end
	self._solo_msec = UICtx.msec()
	self._mission = key
	ctx:sfx("click")
	ctx:session_call("start_solo", { m.difficulty, m.map, self:_mission_opts(m) })
end

function UIRoot._mission_opts(self, m: any): any
	local Modes = UICtx.data("Modes")
	local base = self.ctx.session ~= nil and self.ctx.session.SOLO_TRIBES or nil
	local cfg = Modes.apply({ tribes = m.tribes or base }, m.mode)
	for k, v in m.config or {} do
		cfg[k] = v
	end
	return { config = cfg, tribes = cfg.tribes }
end

--- The Command Center (the title's COMMAND button).
function UIRoot.open_command(self, tab: any)
	if self.command == nil or self.command.is_open then
		return
	end
	self.command:open(tonumber(tab))
	self:_update_input_gate()
end

--- The War Report (the results screen's button).
--- The Realm sheet of a depth match (the mode chip under the top bar, the R key).
function UIRoot.open_realm(self)
	local s = self.ctx.state
	if self.realm == nil or s == nil or s.depth == nil then
		return
	end
	self.realm:toggle()
	self:_update_input_gate()
end

function UIRoot.open_war_report(self)
	if self.war_report == nil or self._log == nil or self.war_report.is_open then
		return
	end
	self.war_report:open(self._log, self._last_result)
	self:_update_input_gate()
end

--- After a win (the happiest moment a player has here), once: Roblox's own ask to let the game send notifications (the
--- daily muster and new orders). Roblox shows it at most once a month whatever we do; a refusal is kept by Roblox.
--- (release 2026-11-07; the texts are made on the Creator Dashboard and sent by an Open Cloud job: docs/RELEASE_CHECKLIST.md)
--- Off until something sends notifications (an Open Cloud sender: docs/RELEASE_CHECKLIST.md): Roblox lets the ask come
--- once a month, so it must not be spent on nothing (release review 2026-11-07).
UIRoot.ASK_NOTIFICATIONS = false

function UIRoot._ask_notifications(self)
	if not UIRoot.ASK_NOTIFICATIONS or self._asked_notify or self.ctx:setting("notify_asked", false) == true then
		return
	end
	self._asked_notify = true
	task.delay(4.0, function()
		local ok, svc = pcall(function()
			return game:GetService("ExperienceNotificationService")
		end)
		if not ok or svc == nil then
			return
		end
		local can_ok, can = pcall(function()
			return svc:CanPromptOptInAsync()
		end)
		if can_ok and can then
			self.ctx:set_setting("notify_asked", true)
			pcall(function()
				svc:PromptOptIn()
			end)
		end
	end)
end

--- The line of a new age ("Age II: Expansion" and what the era is for).
function UIRoot._era_banner(self, era: number)
	if self._log ~= nil then
		self._log:on_era(era)
	end
	local Eras = UICtx.data("Eras")
	local Banner = UICtx.mod("Banner")
	if self._screen ~= "play" or Eras.NAMES[era] == nil or self.over.is_open then
		return
	end
	local roman = ({ "I", "II", "III", "IV" })[era]
	self.ctx:sfx("unlock", -6.0)
	self.float_layer:add_child(
		Banner.make(self.ctx, string.format("Age %s: %s", roman, Eras.NAMES[era]), Eras.BLURBS[era], UITheme.AMBER, 3.0)
	)
end

--- The line of a world event: its name and what it does, good news in the accent, bad in red.
function UIRoot._world_event_banner(self, index: number)
	local d = UICtx.data("WorldEvents").LIST[index]
	if self._screen ~= "play" or d == nil or self.over.is_open then
		return
	end
	-- (a bad one, a plague or a crash, has its own grim sting: the audio key "world_bad"; playtest 2026-11-08)
	self.ctx:sfx(if d.good then "unlock" else "world_bad", -6.0)
	-- (in the middle of the screen, where it is seen; playtest 2026-11-08)
	self.float_layer:add_child(UICtx.mod("Banner").make(self.ctx, d.name, d.line, if d.good then UITheme.AMBER else UITheme.RED, 4.0, true))
end

function UIRoot.relayout_alert(self)
	self:_layout_alert()
end

function UIRoot._layout_alert(self)
	self.alert:apply_layout()
	if self.launch_call ~= nil then
		self.launch_call:apply_layout()
	end
end

-- =============================================================================================
-- Frame
-- =============================================================================================

local function call_update(comp: any, delta: number)
	comp:update(delta)
end

local function process_interact(self, delta: number)
	self.interact:process_frame(delta)
end

local function update_radial(self, delta: number)
	self.radial:update(delta)
	-- the hold ring follows a finger held on the map (touch only)
	local ctx = self.ctx
	local w = ctx.world
	local inp = if w ~= nil then w.input else nil
	if ctx.touch and inp ~= nil and type(inp.hold_state) == "function" and not self.radial.is_open then
		local pos, k = inp:hold_state()
		self.hold_ring:set(if pos ~= nil then ctx:to_logical(pos) else nil, k)
	else
		self.hold_ring:set(nil, 0)
	end
end

local function slow_poll(self)
	local ctx = self.ctx
	-- A build that ended without a new world (failed, or the Core was missing): don't leave the
	-- "Deploying…" chip up or the old solo match frozen.
	if self._building and ctx:session_call("is_building") == false then
		self:_end_building()
		self:_update_pause()
	end
	self:_poll_layout()
	self:_update_music()
end

local function tips_and_threats(self)
	self.advisor:check_threats()
	self.advisor:check_tips()
	self.advisor:check_floor()
	self.advisor:check_builds()
	self.advisor:flush_volleys()
end

local function telemetry_tick(self)
	self.telemetry:tick()
end

--- Per-frame UI work. Each unit runs under W.guard (one failing component is reported once per
--- distinct error and never stops the others, nor the kit step that follows).
function UIRoot._process(self, delta: number)
	local ctx = self.ctx
	local guard = W.guard
	if self._rebind_refresh_in ~= nil or self._rebind_apply_in ~= nil then
		guard("UIRoot rebind", rebind_step, self)
	end
	guard("UIInteract.process_frame", process_interact, self, delta)
	guard("RadialMenu.update", update_radial, self, delta)
	local comps = self._frame_comps
	if comps == nil then
		comps = {}
		for _, key in ipairs({ "bar", "top", "clock", "send_panel", "log_panel", "threat_marks", "army_marks", "province_names", "dock", "board", "notices", "outliner", "alerts", "alert", "build_window" }) do
			local comp = self[key]
			if comp ~= nil and comp.update then
				table.insert(comps, { comp, key .. ".update" })
			end
		end
		self._frame_comps = comps
	end
	for i = 1, #comps do
		local e = comps[i]
		guard(e[2], call_update, e[1], delta)
	end
	-- the air-raid siren wails while a warhead aimed at the player is in the air (the banner's count)
	local incoming = self.alert ~= nil and self.alert:incoming()
	if incoming ~= self._siren_on then
		self._siren_on = incoming
		ctx:set_siren(incoming)
	end
	self._poll += delta
	if self._poll >= 0.5 then
		self._poll = 0.0
		guard("UIRoot poll", slow_poll, self)
	end
	-- The radial menu takes the globe's input while it is open (GDScript: its full-rect STOP).
	local want_world = not (
		self.help.is_open
		or self.pause.is_open
		or self.over.is_open
		or self.rotate_card.visible
		or self.radial.is_open
	)
	if want_world ~= self._world_input then
		self._world_input = want_world
		ctx:set_world_input(want_world)
	end
	-- Tips step aside while the player is placing something or using the radial menu.
	local coach = self.coach
	local target = if self.radial.is_open or self.build_window.is_open or self.interact.aim_kind ~= "" then 0.0 else 1.0
	local a = Defs.move_toward(coach.modulate_a, target, delta * 6.0)
	if a ~= coach.modulate_a then
		coach:set_modulate_a(a)
	end
	self.telemetry:frame(delta)
	if self._hop ~= nil and UICtx.msec() > self._hop.deadline then
		guard("UIRoot hop", self._hop_fallback, self)
	end
	if self._autostart ~= nil then
		guard("UIRoot autostart", self._autostart_step, self)
	end
	if self._tutorial_at ~= nil then
		guard("UIRoot tutorial", self._tutorial_step, self)
	end
	if self.arsenal ~= nil and self.arsenal.is_open then
		guard("Arsenal.frame", self.arsenal.frame, self.arsenal, delta)
	end
	self._threat_poll += delta
	if self._threat_poll >= 1.0 then
		self._threat_poll = 0.0
		guard("UIAdvisor checks", tips_and_threats, self)
		guard("Telemetry.tick", telemetry_tick, self)
		if self.takeover ~= nil then
			guard("Takeover.tick", self.takeover.tick, self.takeover)
		end
		if self.locker ~= nil and self.locker.is_open then
			guard("Locker.tick", self.locker.tick, self.locker)
		end
		if self.flag_shop ~= nil then
			guard("FlagShop.tick", self.flag_shop.tick, self.flag_shop)
		end
		if self.arsenal ~= nil and self.arsenal.is_open then
			guard("Arsenal.tick", self.arsenal.tick, self.arsenal)
		end
	end
end

--- Twice a second: re-layout on viewport / safe-area changes, keep cross-panel positions current.
function UIRoot._poll_layout(self)
	local ctx = self.ctx
	local vp = self.root.vp
	if
		vp ~= self._last_vp
		or not insets_equal(self:_safe_insets(), self._last_insets)
		or self.probe:airship_bar_moved()
	then
		self:_layout()
	elseif self.hud.visible then
		-- Cross-panel positions follow content size.
		-- (a hidden alert is placed when it comes up, UIAdvisor -> relayout_alert: here its two fixed-width
		-- labels were drawn again glyph by glyph twice a second, 2026-10-27)
		if self.alert.visible then
			self:_layout_alert()
		end
		self.probe:update_world_safe_area()
	end
	self:_hook_buttons(self.root)
end

--- UI CPU cost per frame in ms since the last call: {process, kit, total, max, frames}.
function UIRoot.perf_stats(self): { [string]: number }
	local p = self._perf
	if p == nil or p.frames == 0 then
		return { process = 0, kit = 0, total = 0, max = 0, frames = 0 }
	end
	local n = p.frames
	local out = {
		process = p.process / n * 1000,
		kit = p.kit / n * 1000,
		total = (p.process + p.kit) / n * 1000,
		max = p.max * 1000,
		frames = n,
	}
	p.frames, p.process, p.kit, p.max = 0, 0.0, 0.0, 0.0
	return out
end

--- Tear down (tests): disconnect everything and free the GUI.
function UIRoot.destroy(self)
	if UICtx.IS_ROBLOX and self._step_name then
		game:GetService("RunService"):UnbindFromRenderStep(self._step_name)
	end
	for _, c in ipairs(self._sconns) do
		c:Disconnect()
	end
	for _, c in ipairs(self._conns_state or {}) do
		c:Disconnect()
	end
	for _, c in ipairs(self._conns) do
		c:Disconnect()
	end
	self.interact:destroy()
	self.touch_router:destroy()
	self.root:destroy()
	self.gui:Destroy()
	self.ctx.rules = nil
	self.ctx.state = nil
	self.ctx.coach = nil
	self.ctx.tooltip = nil
end

return UIRoot
