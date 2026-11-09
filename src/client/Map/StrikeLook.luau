--!strict
-- What a warhead strike looks like and when, as numbers: FxLayer draws them. Pure, so the tests hold them.
-- Seen from above, as the map is: a thin flare, then a jagged burst that opens into a burning rim round a
-- black crater (Art/FxData, tools/art/fx.luau), a broken shock ring and a slower ash ring behind it, and the
-- ground shaking a beat late, with the boom (Audio/Cadence.IMPACT_S). Each kind of warhead has its own size.
-- With Reduced Motion on: no flare, no shaking, no spinning: the blast is one still picture and the
-- ring stands at its full size, both fading.

local StrikeLook = {}

--- A kind's look by Defs.N_* (0 Warhead, 1 Great Warhead, 3 Cluster Shard, 4 Sunbreaker, 5 Shatter Line),
--- in full-size tiles: `ring` the shock ring's radius, `blast` how wide the burst is drawn, `min_px` the least
--- it is drawn on screen, `shake` the camera's shake. A shard has no flare and no ash ring.
StrikeLook.LOOK = {
	[0] = { ring = 58, blast = 54, min_px = 34, shake = 0.34, full = true },
	[1] = { ring = 150, blast = 128, min_px = 48, shake = 0.8, full = true },
	[3] = { ring = 26, blast = 30, min_px = 18, shake = 0.14, full = false },
	[4] = { ring = 104, blast = 92, min_px = 42, shake = 0.62, full = true },
	[5] = { ring = 40, blast = 40, min_px = 24, shake = 0.22, full = false },
}

--- The shake and the flash's height wait for the boom.
StrikeLook.IMPACT_S = 0.09

--- The burst's frames: how long each is up (s). Fast while it blooms, slow as the rim burns out.
StrikeLook.BLAST_FRAME_S = { 0.05, 0.05, 0.07, 0.09, 0.12, 0.16, 0.22, 0.3 }

--- The flare: seconds up, and how wide against the burst.
StrikeLook.FLARE_S = 0.2
StrikeLook.FLARE_K = 1.5

--- The shock ring: seconds, where it starts and ends (of the look's radius), when it starts to fade (of its
--- life) and how fast it turns (degrees a second).
StrikeLook.SHOCK_S = 0.95
StrikeLook.SHOCK_R0 = 0.12
StrikeLook.SHOCK_R1 = 1.25
StrikeLook.SHOCK_FADE = 0.45
StrikeLook.SHOCK_SPIN = 26.0
--- The ash ring: how long after the blast, for how long, how far.
StrikeLook.ASH_DELAY_S = 0.3
StrikeLook.ASH_S = 1.7
StrikeLook.ASH_R1 = 0.85
--- Reduced Motion's ring: how long it fades at its full size.
StrikeLook.STILL_S = 0.7
--- Reduced Motion's burst: the frame shown (the open rim) and how long.
StrikeLook.STILL_FRAME = 4
StrikeLook.STILL_BLAST_S = 0.8
--- At most this many rings up at once (one image each; a Cluster's shards would be hundreds).
StrikeLook.SHOCK_MAX = 40
--- The ring's colours through its life, hot to ash, with where each starts. (Made once: FxLayer's pool
--- compares colours by reference, and a new Color3 a frame is garbage.)
StrikeLook.SHOCK_STEPS = { 0.0, 0.22, 0.5 }
StrikeLook.SHOCK_COLORS = {
	Color3.fromRGB(255, 226, 150),
	Color3.fromRGB(240, 132, 58),
	Color3.fromRGB(150, 112, 96),
}
StrikeLook.ASH_COLOR = Color3.fromRGB(122, 106, 104)
StrikeLook.FLARE_COLOR = Color3.fromRGB(255, 240, 200)

--- The ash and embers a strike leaves: the sprite, how far out it can lie and how close in (of the look's
--- radius), and how many (radius x density). They lie round the rim: the crater itself stays clear.
StrikeLook.DEBRIS_PLAN = {
	{ kind = "ember", outer = 0.62, inner = 0.3, density = 1 / 16 },
	{ kind = "ash", outer = 0.7, inner = 0.25, density = 1 / 34 },
	{ kind = "pall", outer = 0.5, inner = 0.2, density = 1 / 80 },
}
StrikeLook.DEBRIS_S = 4.2
StrikeLook.DEBRIS_FADE_IN = 0.05
StrikeLook.DEBRIS_FADE_OUT = 0.5
--- At most this many sprites at once; of one strike's shards, about WARHEAD_DEBRIS leave any, picked at
--- random over all of them, counted over WARHEAD_WINDOW_S.
StrikeLook.BURST_MAX = 64
StrikeLook.DEBRIS_MAX = 120
StrikeLook.WARHEAD_DEBRIS = 16
StrikeLook.WARHEAD_WINDOW_S = 8.0

--- A ship or warhead shot down: the small ring (s; full-size tiles).
StrikeLook.POP_S = 0.55
StrikeLook.POP_RADIUS = 9.0

--- The burst's frame `el` seconds in, or nil once it is over (`times` as BLAST_FRAME_S).
function StrikeLook.frame_at(times: { number }, el: number): number?
	local t = 0.0
	for i = 1, #times do
		t += times[i]
		if el < t then
			return i - 1
		end
	end
	return nil
end

--- The shock ring `t` (0..1) through its life: its size (0..1 of the way from R0 to R1): it snaps out, then coasts.
function StrikeLook.shock_ease(t: number): number
	return 1 - (1 - t) ^ 5
end

--- The ring's transparency `t` through its life, fading after `from`.
function StrikeLook.shock_fade(t: number, from: number): number
	return if t <= from then 0.0 else (t - from) / (1 - from)
end

--- The ring's colour `t` through its life.
function StrikeLook.shock_color(t: number): Color3
	local steps = StrikeLook.SHOCK_STEPS
	for i = #steps, 2, -1 do
		if t >= steps[i] then
			return StrikeLook.SHOCK_COLORS[i]
		end
	end
	return StrikeLook.SHOCK_COLORS[1]
end

--- 32-bit multiply, low 32 bits (Math.imul, unsigned)
local function imul(a: number, b: number): number
	local ah, al = a // 65536, a % 65536
	return ((ah * b) % 65536 * 65536 + al * b) % 4294967296
end

--- mulberry32: a float in [0, 1) from an integer seed.
function StrikeLook.seeded_random(seed: number): number
	local s = (seed + 0x6d2b79f5) % 4294967296
	local t = imul(bit32.bxor(s, bit32.rshift(s, 15)), bit32.bor(1, s))
	t = bit32.bxor((t + imul(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(61, t))) % 4294967296, t)
	return bit32.bxor(t, bit32.rshift(t, 14)) / 4294967296
end

--- The debris a strike leaves: offsets from the tile (full-size tiles divided by k) and sprites, for a strike
--- of look radius `radius` (full-size tiles) at `tile`.
function StrikeLook.debris_plan(tile: number, radius: number, k: number): { { kind: string, du: number, dv: number } }
	local out = {}
	local idx = 0
	for _, d in StrikeLook.DEBRIS_PLAN do
		local count = math.floor(radius * d.density)
		for _ = 1, count do
			local seed = tile * 997 + idx
			idx += 1
			local angle = StrikeLook.seeded_random(seed) * math.pi * 2
			local dist = radius * (d.inner + StrikeLook.seeded_random(seed + 0x10000) * (d.outer - d.inner))
			table.insert(out, {
				kind = d.kind,
				du = math.floor(math.cos(angle) * dist) / k,
				dv = math.floor(math.sin(angle) * dist) / k,
			})
		end
	end
	return out
end

return StrikeLook
