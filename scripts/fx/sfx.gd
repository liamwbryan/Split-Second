extends Node
## Autoload. Placeholder sound design. Sounds are synthesized by code, but baked
## to assets/sfx/*.wav once (tools/bake_sfx.sh) so startup just loads files;
## synthesizing ~2 s of audio in GDScript at boot was a visible stall.
## Swap for recorded SFX in M9.

const RATE := 44100
const POOL := 24
const WIND_SECONDS := 4.0
const WIND_FADE := 0.3
const WIND_BUS := &"Wind"
const BAKED := "res://assets/sfx/%s.wav"

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 1337
	_ensure_wind_bus()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_players.append(p)
	_build()


func play(sound: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	p.play()


## A dedicated looping player (wind, slide scrape). Caller owns it.
func make_loop(sound: StringName, parent: Node, bus: StringName = &"Master") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _streams.get(sound)
	p.bus = bus
	p.volume_db = -80.0
	parent.add_child(p)
	p.play()
	return p


## Low-pass on the wind bus: slow air sounds soft and dull, fast air opens up.
func set_wind_cutoff(hz: float) -> void:
	var idx := AudioServer.get_bus_index(WIND_BUS)
	if idx >= 0:
		(AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter).cutoff_hz = hz


func _ensure_wind_bus() -> void:
	if AudioServer.get_bus_index(WIND_BUS) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, WIND_BUS)
	AudioServer.set_bus_send(idx, &"Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 500.0
	lp.resonance = 0.3
	AudioServer.add_bus_effect(idx, lp)


func _build() -> void:
	var baked_all := true
	for sound: StringName in SOUND_NAMES:
		var path := BAKED % sound
		if ResourceLoader.exists(path):
			_streams[sound] = load(path)
		else:
			baked_all = false
	if not baked_all:
		synthesize_all()
	var wind: AudioStreamWAV = _streams[&"wind"]
	wind.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wind.loop_begin = 0
	wind.loop_end = int(RATE * WIND_SECONDS) - int(RATE * WIND_FADE)  # matches the crossfade


const SOUND_NAMES: Array[StringName] = [
	&"shot", &"hit", &"head", &"kill", &"jump", &"double_jump", &"land", &"step", &"slide",
	&"kick", &"mantle", &"grapple_fire", &"grapple_attach", &"grapple_release", &"denied",
	&"reload", &"wind", &"rail", &"bolt", &"slash", &"slash_hit", &"lunge", &"long_shot", &"swap",
]


## Generates every sound from code (fallback, and the source for baking).
func synthesize_all() -> void:
	_streams[&"shot"] = _wav(_gunshot())
	_streams[&"hit"] = _wav(_tone([2300.0, 3450.0], 0.045, 0.5, 90.0))
	_streams[&"head"] = _wav(_tone([2900.0, 4350.0, 5800.0], 0.11, 0.55, 35.0))
	_streams[&"kill"] = _wav(_mix(_tone([700.0, 1050.0, 1400.0], 0.22, 0.45, 14.0), _thump(80.0, 40.0, 0.14, 0.6)))
	_streams[&"jump"] = _wav(_noise_env(0.14, 0.35, 1800.0, 25.0))
	_streams[&"double_jump"] = _wav(_mix(_noise_env(0.2, 0.4, 3000.0, 14.0), _chirp(260.0, 700.0, 0.16, 0.25)))
	_streams[&"land"] = _wav(_mix(_thump(90.0, 45.0, 0.12, 0.8), _noise_env(0.08, 0.35, 900.0, 40.0)))
	_streams[&"step"] = _wav(_noise_env(0.05, 0.3, 1400.0, 70.0))
	_streams[&"slide"] = _wav(_noise_env(0.45, 0.35, 1200.0, 5.0))
	_streams[&"kick"] = _wav(_mix(_thump(120.0, 60.0, 0.1, 0.7), _noise_env(0.18, 0.4, 2500.0, 16.0)))
	_streams[&"mantle"] = _wav(_mix(_noise_env(0.2, 0.3, 1100.0, 12.0), _thump(100.0, 70.0, 0.08, 0.4)))
	_streams[&"grapple_fire"] = _wav(_mix(_chirp(1500.0, 380.0, 0.16, 0.35), _noise_env(0.1, 0.25, 4000.0, 30.0)))
	_streams[&"grapple_attach"] = _wav(_tone([620.0, 1130.0, 1720.0], 0.16, 0.5, 26.0))
	_streams[&"grapple_release"] = _wav(_chirp(500.0, 900.0, 0.08, 0.25))
	_streams[&"denied"] = _wav(_tone([140.0, 147.0], 0.12, 0.35, 20.0))
	_streams[&"reload"] = _wav(_mix(_click(0.0), _click(0.22)))
	_streams[&"wind"] = _wav(_wind_loop())
	# Weapons (M2). Rail: a hard crack, a deep boom and a rising electric whine.
	_streams[&"rail"] = _wav(_mix(_mix(_gunshot(), _thump(70.0, 30.0, 0.35, 0.9)), _chirp(900.0, 2600.0, 0.18, 0.18)))
	_streams[&"bolt"] = _wav(_mix(_mix(_click(0.0), _click(0.11)), _noise_env(0.06, 0.2, 2200.0, 60.0)))
	_streams[&"slash"] = _wav(_noise_env(0.2, 0.45, 5000.0, 16.0))
	_streams[&"slash_hit"] = _wav(_mix(_mix(_thump(110.0, 45.0, 0.16, 1.0), _noise_env(0.12, 0.45, 1500.0, 30.0)), _tone([1800.0, 2700.0], 0.06, 0.25, 60.0)))
	_streams[&"lunge"] = _wav(_mix(_noise_env(0.26, 0.4, 2400.0, 9.0), _chirp(180.0, 420.0, 0.2, 0.2)))
	_streams[&"long_shot"] = _wav(_tone([1320.0, 1980.0, 2640.0, 3300.0], 0.35, 0.45, 9.0))
	_streams[&"swap"] = _wav(_mix(_click(0.0), _noise_env(0.08, 0.2, 1800.0, 40.0)))


## Writes synthesized sounds to assets/sfx (called by tools/bake_sfx.gd).
## Existing files are kept (noise is random, so re-baking would change them);
## pass `overwrite` to redo them all.
func bake(dir: String, overwrite: bool = false) -> void:
	synthesize_all()
	DirAccess.make_dir_recursive_absolute(dir)
	for sound: StringName in SOUND_NAMES:
		var path := "%s/%s.wav" % [dir, sound]
		if overwrite or not FileAccess.file_exists(path):
			(_streams[sound] as AudioStreamWAV).save_to_wav(path)


# --------------------------------------------------------------------------- synthesis

func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _gunshot() -> PackedFloat32Array:
	var n := int(RATE * 0.32)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.5
		lp2 += (noise - lp2) * 0.08
		var crack := lp * exp(-t * 60.0) * 0.9
		var body := lp2 * exp(-t * 14.0) * 1.3
		var f := lerpf(140.0, 45.0, minf(t / 0.08, 1.0))
		phase += TAU * f / RATE
		var thump := sin(phase) * exp(-t * 22.0) * 0.9
		var tail := lp2 * exp(-t * 6.0) * 0.25
		out[i] = tanh((crack + body + thump + tail) * 1.4) * 0.9
	return out


func _tone(freqs: Array, dur: float, amp: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for f in freqs:
			s += sin(TAU * float(f) * t)
		var attack := minf(t / 0.002, 1.0)
		out[i] = s / freqs.size() * amp * exp(-t * decay) * attack
	return out


func _thump(f0: float, f1: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(f0, f1, t / dur) / RATE
		out[i] = sin(phase) * amp * exp(-t * 5.0 / dur) * minf(t / 0.002, 1.0)
	return out


func _chirp(f0: float, f1: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(f0, f1, t / dur) / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		out[i] = (sin(phase) * 0.7 + saw * 0.3) * amp * (1.0 - t / dur) * minf(t / 0.003, 1.0)
	return out


func _noise_env(dur: float, amp: float, cutoff: float, decay: float) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := clampf(TAU * cutoff / RATE, 0.0, 1.0)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1.0, 1.0) - lp) * a
		out[i] = lp * amp * 2.0 * exp(-t * decay) * minf(t / 0.004, 1.0)
	return out


func _click(offset: float) -> PackedFloat32Array:
	var start := int(RATE * offset)
	var n := start + int(RATE * 0.05)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(start, n):
		var t := float(i - start) / RATE
		out[i] = (sin(TAU * 1800.0 * t) * 0.3 + _rng.randf_range(-0.3, 0.3)) * exp(-t * 90.0)
	return out


## Soft broadband air: brown-ish noise with a little airy hiss on top.
## The Wind bus low-pass (driven by speed) shapes it at runtime.
func _wind_loop() -> PackedFloat32Array:
	var n := int(RATE * WIND_SECONDS)
	var out := PackedFloat32Array()
	out.resize(n)
	var brown := 0.0
	var air := 0.0
	for i in n:
		var white := _rng.randf_range(-1.0, 1.0)
		brown = clampf(brown * 0.995 + white * 0.03, -1.0, 1.0)
		air += (white - air) * 0.35
		out[i] = brown * 1.1 + air * 0.08
	# Crossfade the ends so the loop is seamless.
	var fade := int(RATE * WIND_FADE)
	for i in fade:
		var w := float(i) / fade
		out[i] = out[i] * w + out[n - fade + i] * (1.0 - w)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return out
