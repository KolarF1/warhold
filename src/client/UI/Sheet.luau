--!nonstrict
-- How Warhold opens a window: a full-height sheet docked to the left, not a popup in the middle of the screen. On the
-- title it stands against the column's right edge (TitleScreen sets ctx.title_nav); in a match, against the screen's
-- left edge; on phones it takes the whole width, its words right of the safe area. It comes in with a short slide and
-- fade with no overshoot, over a light dim of the map, under a left-aligned heading with a back arrow at its top left.
--
--   local v, head = Sheet.attach(win, "BANNERS")   win: a W.Control with `ctx`, `is_open` and `close()`
--   local m = Sheet.place(win, want_w)             from apply_layout: m.body_w and m.body_h are what the body may use
--   Sheet.show(win)   Sheet.hide(win)              from open() and close(), which keep their own is_open and signals
--
-- `head` is the heading's row, for what a window adds beside its title. Add the body to `v`; a tall body scrolls inside.
local UITheme = require("./UITheme")
local W = require("./Widgets")
local GlassPanel = require("./GlassPanel")
local UICtx = require("./UICtx")

local Sheet = {}

--- The slide and fade in, seconds (under 0.2), how far it slides, and the fade out.
Sheet.SLIDE_S = 0.16
Sheet.SLIDE_PX = 24
Sheet.FADE_OUT_S = 0.12
--- How dark the map goes behind a sheet (the old popups' dim was 0.6 to 0.8, navy).
Sheet.DIM_ALPHA = 0.3
--- The heading's row: the back arrow's height (a tap target on every device).
Sheet.HEAD_H = 44

--- Where a sheet sits (logical px). `left`: the title column's right edge, 0 in a match; `bar`: Rect of the top bar row
--- (Roblox's buttons and ours, drawn above every window); `want_w`: the width the window's body would like.
function Sheet.metrics(vp: Vector2, ins: any, compact: boolean, left: number, bar: any, want_w: number): any
	local pad = if compact then 12 else 20
	local x, w, pl, pr
	if compact then
		-- (its ground runs under the notch, its words stay right of the safe area)
		x, w = 0, vp.X
		pl, pr = ins.x + pad, ins.z + pad
	else
		x = left
		pl = (if left > 0 then 0 else ins.x) + pad
		w = math.min(want_w + pl + pad, vp.X - x)
		pr = pad + math.max(0, x + w - (vp.X - ins.z))
	end
	-- the arrow goes under the top bar row only where the sheet reaches under it
	local top = if x < bar.Max.X then math.max(ins.y, bar.Max.Y) else ins.y
	local pt = top + (if compact then 2 else 12)
	local pb = ins.w + (if compact then 6 else 16)
	local sep = if compact then 6 else 10
	return {
		x = x,
		w = w,
		pl = pl,
		pt = pt,
		pr = pr,
		pb = pb,
		sep = sep,
		body_w = w - pl - pr,
		body_h = vp.Y - pt - pb - Sheet.HEAD_H - sep,
	}
end

--- The back arrow (the kit has one chevron, pointing right: UnitCard flips it the same way).
function Sheet.back_button(on_press: () -> ()): any
	local b = UITheme.button("", "GhostButton", "chevron", Sheet.HEAD_H)
	b.expand_icon = true
	b.icon_alignment = W.ALIGN_CENTER
	b:add_theme_constant_override("icon_max_width", 16)
	b:set_min_size(Vector2.new(Sheet.HEAD_H, Sheet.HEAD_H))
	b.size_flags_vertical = W.SHRINK_CENTER
	b._icon.gui.Rotation = 180
	b._icon:set_color(UITheme.TEXT)
	b.pressed:Connect(on_press)
	return b
end

--- Builds the dim, the sheet and its heading on `win`. opts.relayout: UIRoot doesn't lay this window out, so it follows
--- ctx.layout_changed itself; opts.outside: nil, or a function that says whether a press on the dim may close it now.
function Sheet.attach(win: any, title: string, opts: any?): (any, any)
	opts = opts or {}
	win:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	win:set_mouse_filter(W.MOUSE_STOP)
	win:set_visible(false)
	-- (see HelpOverlay: an Active frame doesn't stop a press reaching a button behind it, only a button on top does)
	UICtx.make("TextButton", {
		Name = "Blocker",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		Active = true,
		Selectable = false,
		ZIndex = 1,
	}, win.gui)
	local dim = W.ColorRect.new(UITheme.c(UITheme.BLACK, Sheet.DIM_ALPHA))
	dim:set_anchors_and_offsets_preset(W.PRESET_FULL_RECT)
	dim:set_mouse_filter(W.MOUSE_STOP)
	dim.gui_input:Connect(function(e)
		-- (a press on the sheet's own ground reaches the dim too: only one outside it closes)
		if e.pressed and not win._panel:has_global_point(e.global_position) and (opts.outside == nil or opts.outside()) then
			win:close()
			-- (the title's column stays in view beside a sheet: a press on one of its rows goes there too)
			if win.ctx.title_nav_press ~= nil then
				win.ctx.title_nav_press(e.global_position)
			end
		end
	end)
	win._dim = dim
	win:add_child(dim)
	local panel = GlassPanel.new(0.0, 0.0, 0, true, 0)
	panel:set_tint(UITheme.GLASS_SOLID)
	win._panel = panel
	win:add_child(panel)
	local v = UITheme.vbox(10)
	win._sheet_v = v
	panel:add_child(v)
	local head = UITheme.hbox(10)
	head:add_child(Sheet.back_button(function()
		win:close()
	end))
	local label = UITheme.label(title, 20, UITheme.DIAL_WEIGHT, UITheme.TEXT, 2)
	label.size_flags_vertical = W.SHRINK_CENTER
	win._sheet_title = label
	head:add_child(label)
	win._sheet_head = head
	v:add_child(head)
	local changed = win.ctx.layout_changed
	if opts.relayout and changed ~= nil then
		win:_connect(changed:Connect(function()
			if win.is_open then
				win:apply_layout()
			end
		end))
	end
	return v, head
end

--- Docks the sheet for the screen as it is now and says how much room its body has.
function Sheet.place(win: any, want_w: number): any
	local ctx = win.ctx
	local left = if ctx.title_nav ~= nil then ctx.title_nav() else 0
	local bar = ctx.airship_bar or UICtx.rect(0, 0, 0, 0)
	local m = Sheet.metrics(ctx.vp, ctx.insets, ctx.compact == true, left, bar, want_w)
	local panel = win._panel
	panel:set_padding(m.pl, m.pt, m.pr, m.pb)
	win._sheet_v:set_separation(m.sep)
	win._sheet_title:set_font_size(if ctx.compact then 17 else 20)
	panel:set_anchors(0, 0, 0, 1)
	panel:set_offsets(m.x, 0, m.x + m.w, 0)
	panel:_layout_free()
	return m
end

function Sheet.show(win: any)
	win:set_visible(true)
	win._dim:set_modulate_a(0.0)
	W.fade(win._dim, 1.0, Sheet.SLIDE_S)
	-- (eases out with no overshoot; under reduced motion it only fades)
	W.slide_in(win._panel, Vector2.new(-Sheet.SLIDE_PX, 0), 0.0, Sheet.SLIDE_S)
	win.ctx:sfx("open")
end

function Sheet.hide(win: any)
	win.ctx:sfx("close")
	local t = win:create_tween():set_parallel(true)
	t:tween_property(win._dim, "modulate:a", 0.0, Sheet.FADE_OUT_S)
	t:tween_property(win._panel, "modulate:a", 0.0, Sheet.FADE_OUT_S)
	t:chain():tween_callback(function()
		if not win.is_open then
			win:set_visible(false)
		end
	end)
end

return Sheet
