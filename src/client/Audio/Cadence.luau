--!strict
-- When Warhold's sounds fire and how they stack: the numbers and the small state machines behind
-- AudioDirector, MusicMood's war music and the countdowns. Pure (no Roblox service), so the tests hold them.
-- Taking land is a march, not a stream: a four-beat bar on a tempo grid, its tempo set by how fast land
-- comes in, its root note by how far the nation has got. Big events are short phrases of the samples we own
-- (a thud under the boom, an echo after the alarm). A long war is thinned by a salvo gate, so a Cluster's
-- hundreds of shards are a barrage of a few blows, each quieter than the last.

local Cadence = {}

-- ---------------------------------------------------------------------------------------------
-- Spacing
-- ---------------------------------------------------------------------------------------------

--- Long stings: a full play at most once per cooldown (ms). A repeat inside the cooldown plays the
--- fallback accent instead ("" = stay silent), so rapid clicks never restart or stack a 2-3 s sting.
Cadence.COOLDOWNS = {
	attack_launch = { 900, "order_ack" },
	boat_launch = { 1100, "order_ack" },
	warship = { 1400, "order_ack" },
	spawn_confirm = { 1000, "ui_click" },
	-- (the sample is 3 s: it finishes before it can start again)
	conquer = { 3300, "" },
	betrayal = { 4400, "" },
	alliance = { 1700, "" },
	ally_request = { 2300, "" },
	under_attack = { 6500, "" },
	nuke_alarm = { 3800, "" },
	game_start = { 3600, "" },
	victory = { 6000, "" },
	defeat = { 6000, "" },
}
--- Minimum time between two starts of the same sound (ms) for short / cooldown-free sounds.
Cadence.THROTTLE_MS = {
	expand = 240,
	ui_hover = 45,
	ui_click = 30,
	ui_open = 60,
	ui_error = 120,
	countdown_tick = 300,
	order_ack = 120,
	build = 220,
	sam_intercept = 200,
	nuke_launch = 420,
	nuke_explosion = 260,
	sam_launch = 220,
	shell_fire = 240,
	shell_hit = 180,
	shell_splash = 180,
	ship_sink = 560,
	spectate_switch = 150,
	crate_rattle = 90,
	ui_confirm = 60,
	ui_back = 60,
	ui_tab = 40,
	ui_locked = 150,
	-- (under the march's fastest beat, so a layer or a pick never eats one)
	expand_pop = 110,
	eliminate = 420,
	star_tick = 28,
	star_get = 120,
	buy_spend = 150,
	unlock = 800,
}
Cadence.DEFAULT_THROTTLE_MS = 50
--- At most this many copies of one sound may ring at once (the oldest copy is restarted beyond it).
--- Each copy is a Sound made up front, so these are also the Instances a phone keeps.
Cadence.MAX_SAME = {
	expand = 1,
	ui_hover = 1,
	ui_click = 2,
	order_ack = 2,
	-- (the alarm's echo rings over the alarm: PHRASES)
	nuke_alarm = 2,
	nuke_explosion = 2,
	attack_launch = 1,
	boat_launch = 1,
	warship = 1,
	sam_launch = 2,
	sam_intercept = 2,
	shell_fire = 2,
	shell_hit = 2,
	shell_splash = 1,
	ship_sink = 1,
	under_attack = 1,
	ally_request = 1,
	victory = 1,
	defeat = 1,
	game_start = 1,
	countdown_tick = 1,
	countdown_gamestart = 1,
	queue_start = 1,
	spectate_switch = 1,
	crate_drop = 1,
	crate_land = 1,
	crate_rattle = 2,
	crate_preview_common = 1,
	crate_preview_rare = 1,
	crate_preview_epic = 1,
	crate_preview_legendary = 1,
	crate_open = 1,
	crate_shimmer = 1,
	card_whoosh = 1,
	card_flip = 1,
	reveal_common = 1,
	reveal_rare = 1,
	reveal_epic = 1,
	reveal_legendary = 1,
	ui_confirm = 2,
	ui_back = 2,
	ui_tab = 2,
	ui_locked = 1,
	-- (the sample rings 1.2 s and a beat comes every 0.2 s at the fastest: a few overlap)
	expand_pop = 3,
	eliminate = 1,
	star_tick = 4,
	star_get = 2,
	buy_spend = 1,
	unlock = 1,
}
Cadence.DEFAULT_MAX_SAME = 2
Cadence.VOICE_COUNT = 14

--- Sounds that automatically duck the music: name -> {amount_db, hold_seconds}. Our samples are short
--- (a 3 s win, a 0.6 s defeat, a 2 s boom), so the dips are held about as long as they ring: deep and brief.
Cadence.AUTO_DUCK = {
	nuke_explosion = { 11.0, 1.4 },
	nuke_alarm = { 6.0, 3.0 },
	game_start = { 4.0, 2.2 },
	countdown_gamestart = { 4.0, 1.6 },
	under_attack = { 4.0, 1.8 },
	victory = { 9.0, 3.2 },
	defeat = { 9.0, 1.4 },
	betrayal = { 5.0, 2.2 },
	conquer = { 5.0, 3.0 },
	crate_preview_epic = { 3.0, 1.8 },
	crate_preview_legendary = { 4.0, 2.0 },
	crate_open = { 4.0, 1.5 },
	reveal_epic = { 4.0, 2.5 },
	reveal_legendary = { 6.0, 4.0 },
	unlock = { 5.0, 3.0 },
}
Cadence.DUCK_ATTACK_DB_PER_S = 120.0
Cadence.DUCK_RELEASE_DB_PER_S = 4.0

--- While one of these rings, the march holds off (seconds): the kill sound comes with the last land
--- taken, the march's biggest bite.
Cadence.HUSH_MARCH = { eliminate = 0.6 }

--- The soundtrack's fades (s): the next track over the end of this one, into a new mood, into war.
Cadence.TRACK_OVERLAP_S = 3.0
Cadence.MOOD_FADE_S = 4.5
Cadence.WAR_FADE_S = 1.2
Cadence.CROSSFADE_S = 2.5

-- ---------------------------------------------------------------------------------------------
-- The march: the sound of land coming in
-- ---------------------------------------------------------------------------------------------

--- Speeds are full-size tiles of land gained a second (a 71-nation match: median ~60, 95th percentile
--- ~590). A tier's `below` is the speed under which it holds, `gap` the seconds between its beats, `db`
--- its level. Gaps are whole batches of changes (10 a second), so the grid holds.
Cadence.MARCH_TIERS = {
	{ below = 90.0, gap = 0.6, db = -10.0 },
	{ below = 220.0, gap = 0.4, db = -8.0 },
	{ below = 480.0, gap = 0.3, db = -6.0 },
	{ below = math.huge, gap = 0.2, db = -5.0 },
}
--- Land banked before a beat can fall (full-size tiles): a trickle of land stays silent for a while.
Cadence.MARCH_MIN_TILES = 30.0
--- How quickly the tempo follows the gains (s).
Cadence.MARCH_SMOOTH_S = 0.7
--- A batch this early still takes the beat (batches come a little late or early).
Cadence.MARCH_SLACK_S = 0.02
--- A quiet this long and the next beat is the bar's first again.
Cadence.MARCH_REST_S = 1.4
--- The four beats of the bar: level on top of the tier's, and a step of pitch over the root.
Cadence.MARCH_ACCENT_DB = { 0.0, -6.0, -3.0, -6.0 }
Cadence.MARCH_STEP = { 1.0, 1.06, 1.0, 1.12 }
--- The root by progress towards winning: one level through each quarter, no slow climb.
Cadence.MARCH_ROOTS = { 0.84, 0.9, 0.96, 1.03 }
--- From this tier on the bar's first beat has a tap over it.
Cadence.MARCH_LAYER_TIER = 3
Cadence.MARCH_LAYER = { sfx = "order_ack", db = -12.0, pitch = 0.7 }

--- The land loop (expand_loop): one seamless loop plays while land comes in, in place of the beats when it is there.
--- Its level and speed follow how fast the land comes in, between a trickle (LOOP_SPEED_LOW) and a flood (LOOP_SPEED_HIGH),
--- on a log scale; with no land for LOOP_IDLE_S it fades out over LOOP_FALL_S (it rises over LOOP_RISE_S).
Cadence.LOOP_SPEED_LOW = 20.0
Cadence.LOOP_SPEED_HIGH = 600.0
Cadence.LOOP_DB = { -15.0, -7.0 }
Cadence.LOOP_RATE = { 0.94, 1.1 }
Cadence.LOOP_IDLE_S = 0.35
Cadence.LOOP_RISE_S = 0.08
Cadence.LOOP_FALL_S = 0.45

--- The air-raid siren (nuke_siren): one seamless loop that wails while a warhead aimed at the player is in the air (the
--- banner's count, AlertBanner.incoming), in place of the one-shot nuke_alarm when it is there. It starts from the top
--- of its wind-up, rises in over SIREN_RISE_S and fades out over SIREN_FALL_S once the sky is clear.
Cadence.SIREN_DB = -5.0
Cadence.SIREN_RISE_S = 0.15
Cadence.SIREN_FALL_S = 1.6

--- The loop's level (dB) and playback speed for `speed` full-size tiles a second. Pure.
function Cadence.loop_level(speed: number): (number, number)
	local k = math.clamp(math.log(math.max(speed, 1e-3) / Cadence.LOOP_SPEED_LOW) / math.log(Cadence.LOOP_SPEED_HIGH / Cadence.LOOP_SPEED_LOW), 0, 1)
	local db, rate = Cadence.LOOP_DB, Cadence.LOOP_RATE
	return db[1] + (db[2] - db[1]) * k, rate[1] + (rate[2] - rate[1]) * k
end

function Cadence.new_march(): any
	return { speed = 0.0, bank = 0.0, last_batch = -1e9, last_beat = -1e9, beat = 0 }
end

--- The tier of a speed (its index in MARCH_TIERS).
function Cadence.march_tier(speed: number): number
	local tiers = Cadence.MARCH_TIERS
	for i = 1, #tiers do
		if speed < tiers[i].below then
			return i
		end
	end
	return #tiers
end

--- The root note for `progress` (0..1 towards winning).
function Cadence.march_root(progress: number?): number
	local roots = Cadence.MARCH_ROOTS
	return roots[math.clamp(math.floor(math.clamp(progress or 0, 0, 1) * #roots) + 1, 1, #roots)]
end

--- A batch of `tiles` gained at time `now` (s). Whether a beat falls now, its level and pitch, and whether
--- it has the tap over it. (No table made: this runs ten times a second all match.)
function Cadence.march(m: any, tiles: number, now: number, progress: number?): (boolean, number, number, boolean)
	local dt = math.clamp(now - m.last_batch, 0.1, 3.0)
	m.last_batch = now
	m.speed += (tiles / dt - m.speed) * (1 - math.exp(-dt / Cadence.MARCH_SMOOTH_S))
	m.bank += tiles
	local tier = Cadence.march_tier(m.speed)
	local t = Cadence.MARCH_TIERS[tier]
	local since = now - m.last_beat
	if m.bank < Cadence.MARCH_MIN_TILES or since < t.gap - Cadence.MARCH_SLACK_S then
		return false, 0.0, 1.0, false
	end
	m.bank = 0.0
	m.last_beat = now
	m.beat = if since > Cadence.MARCH_REST_S then 1 else m.beat % #Cadence.MARCH_ACCENT_DB + 1
	return true,
		t.db + Cadence.MARCH_ACCENT_DB[m.beat],
		Cadence.march_root(progress) * Cadence.MARCH_STEP[m.beat],
		m.beat == 1 and tier >= Cadence.MARCH_LAYER_TIER
end

-- ---------------------------------------------------------------------------------------------
-- Phrases: a big event as a few samples, in time
-- ---------------------------------------------------------------------------------------------

--- The boom falls this long after the thud (FxLayer's shake and flash wait as long: StrikeLook.IMPACT_S).
Cadence.IMPACT_S = 0.09

--- name -> its steps: `at` seconds after the cue, the sound, its level (on top of the cue's) and pitch.
--- `main` is the cue's own sound, played at the level and pitch it was asked for. (A layer passes no gate
--- and starts no phrase of its own: the alarm's echo is the alarm's sample.)
Cadence.PHRASES = {
	nuke_explosion = {
		{ at = 0.0, sfx = "shell_fire", db = 6.0, pitch = 0.32 },
		{ at = Cadence.IMPACT_S, main = true },
		{ at = 1.1, sfx = "sam_intercept", db = -13.0, pitch = 0.38 },
	},
	nuke_alarm = {
		{ at = 0.0, main = true },
		{ at = 0.62, sfx = "nuke_alarm", db = -5.0, pitch = 0.94 },
	},
	nuke_launch = {
		{ at = 0.0, sfx = "sam_launch", db = -4.0, pitch = 0.6 },
		{ at = 0.05, main = true },
	},
	betrayal = {
		{ at = 0.0, main = true },
		{ at = 0.24, sfx = "ui_locked", db = -6.0, pitch = 0.7 },
	},
	alliance = {
		{ at = 0.0, main = true },
		{ at = 0.18, sfx = "ui_confirm", db = -8.0, pitch = 1.25 },
	},
	eliminate = {
		{ at = 0.0, main = true },
		{ at = 0.08, sfx = "shell_fire", db = 2.0, pitch = 0.45 },
	},
	spawn_confirm = {
		{ at = 0.0, main = true },
		{ at = 0.12, sfx = "ui_confirm", db = -8.0, pitch = 1.1 },
	},
}

-- ---------------------------------------------------------------------------------------------
-- The salvo gate: many blasts in a moment
-- ---------------------------------------------------------------------------------------------

--- Sounds behind the gate. Each blast adds 1 to the heat, which falls by half every HALF_S. `above`: from
--- this heat on, a blast waits `gap` seconds after the last one heard. `db`: the level taken off per
--- doubling of the heat past FULL_HEAT, under which a blast has its whole phrase.
Cadence.SALVO = { nuke_explosion = true }
Cadence.SALVO_HALF_S = 2.0
Cadence.SALVO_GAPS = {
	{ above = 9.0, gap = 1.0 },
	{ above = 4.0, gap = 0.6 },
	{ above = 1.5, gap = 0.35 },
}
Cadence.SALVO_FULL_HEAT = 2.5
Cadence.SALVO_DB = 2.0

function Cadence.new_salvo(): any
	return { heat = 0.0, last = -1e9, heard = -1e9 }
end

--- A blast at `now` (s): whether it is heard, the level to take off it, and whether it has its whole phrase.
function Cadence.salvo(m: any, now: number): (boolean, number, boolean)
	m.heat = m.heat * 0.5 ^ (math.max(0, now - m.last) / Cadence.SALVO_HALF_S) + 1
	m.last = now
	local gap = 0.0
	for _, g in Cadence.SALVO_GAPS do
		if m.heat >= g.above then
			gap = g.gap
			break
		end
	end
	if now - m.heard < gap then
		return false, 0.0, false
	end
	m.heard = now
	local full = m.heat < Cadence.SALVO_FULL_HEAT
	local off = if full then 0.0 else Cadence.SALVO_DB * (math.log(m.heat / Cadence.SALVO_FULL_HEAT) / math.log(2))
	return true, off, full
end

-- ---------------------------------------------------------------------------------------------
-- Countdowns
-- ---------------------------------------------------------------------------------------------

--- The waiting room's countdown: seconds that sound, and how (sound, level, pitch). Sparse until the last three.
Cadence.LOBBY_TICKS = {
	[10] = { "tick", -8.0, 0.9 },
	[5] = { "tick", -6.0, 1.0 },
	[3] = { "countdown_tick_3", -3.0, 1.0 },
	[2] = { "countdown_tick_2", -2.0, 1.06 },
	[1] = { "countdown_tick_1", -1.0, 1.14 },
	[0] = { "countdown_gamestart", -2.0, 1.0 },
}
--- The spawn screen's last seconds: second -> level, pitch.
Cadence.SPAWN_TICKS = {
	[3] = { -6.0, 1.0 },
	[2] = { -4.0, 1.08 },
	[1] = { -1.0, 1.2 },
}

--- War music: how long the fighting must last before it starts (a warhead starts it at once) and how long
--- it holds after the last sign of fighting: MusicMood.
Cadence.WAR_ONSET_S = 5.0
Cadence.WAR_HOLD_S = 26.0

return Cadence
