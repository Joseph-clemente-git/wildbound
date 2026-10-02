extends Node
## Audio hooks (autoload "Sfx").
##
## Gameplay and UI only ever call `Sfx.play("hook_name")`. Until recorded audio
## exists, each hook is backed by a small procedurally synthesized sound so the
## game has feedback; swapping in real assets only means filling `overrides`.

const MIX_RATE := 22050
const POOL_SIZE := 10

## hook -> synthesis recipe.
## freq/freq_end: tone sweep (Hz). noise: 0..1 noise mix. tone_shape: sine/square/tri.
## cutoff: 0..1 one-pole low-pass on noise. attack/duration in seconds.
const RECIPES := {
	"ui_click": {"freq": 880.0, "freq_end": 660.0, "duration": 0.06, "volume": 0.35},
	"ui_back": {"freq": 520.0, "freq_end": 380.0, "duration": 0.08, "volume": 0.3},
	"ui_confirm": {"freq": 660.0, "freq_end": 990.0, "duration": 0.14, "volume": 0.35},
	"ui_error": {"freq": 220.0, "freq_end": 180.0, "duration": 0.16, "volume": 0.3, "tone_shape": "square"},
	"swing": {"freq": 300.0, "freq_end": 120.0, "duration": 0.14, "noise": 0.8, "cutoff": 0.35, "volume": 0.3},
	"heavy_swing": {"freq": 160.0, "freq_end": 60.0, "duration": 0.24, "noise": 0.8, "cutoff": 0.2, "volume": 0.4},
	"hit": {"freq": 180.0, "freq_end": 90.0, "duration": 0.12, "noise": 0.55, "cutoff": 0.5, "volume": 0.5},
	"heavy_hit": {"freq": 110.0, "freq_end": 45.0, "duration": 0.26, "noise": 0.5, "cutoff": 0.3, "volume": 0.65},
	"block": {"freq": 900.0, "freq_end": 700.0, "duration": 0.1, "noise": 0.4, "cutoff": 0.8, "volume": 0.4, "tone_shape": "tri"},
	"perfect_block": {"freq": 1320.0, "freq_end": 1760.0, "duration": 0.22, "volume": 0.4, "tone_shape": "tri"},
	"guard_break": {"freq": 260.0, "freq_end": 70.0, "duration": 0.35, "noise": 0.6, "cutoff": 0.4, "volume": 0.6},
	"dodge": {"freq": 500.0, "freq_end": 900.0, "duration": 0.16, "noise": 0.9, "cutoff": 0.6, "volume": 0.25},
	"perfect_dodge": {"freq": 700.0, "freq_end": 1400.0, "duration": 0.24, "noise": 0.3, "cutoff": 0.7, "volume": 0.3},
	"stagger": {"freq": 200.0, "freq_end": 140.0, "duration": 0.2, "tone_shape": "square", "volume": 0.25},
	"exhausted": {"freq": 330.0, "freq_end": 160.0, "duration": 0.4, "tone_shape": "tri", "volume": 0.3},
	"cast": {"freq": 420.0, "freq_end": 840.0, "duration": 0.35, "noise": 0.15, "volume": 0.3, "tone_shape": "tri"},
	"fire": {"freq": 140.0, "freq_end": 90.0, "duration": 0.45, "noise": 0.85, "cutoff": 0.45, "volume": 0.45},
	"wind": {"freq": 300.0, "freq_end": 600.0, "duration": 0.5, "noise": 1.0, "cutoff": 0.25, "volume": 0.4},
	"knockout": {"freq": 300.0, "freq_end": 70.0, "duration": 0.7, "tone_shape": "tri", "volume": 0.45},
	"victory": {"freq": 523.0, "freq_end": 1046.0, "duration": 0.6, "tone_shape": "tri", "volume": 0.4},
	"defeat": {"freq": 392.0, "freq_end": 196.0, "duration": 0.7, "tone_shape": "tri", "volume": 0.35},
	"growth": {"freq": 660.0, "freq_end": 1320.0, "duration": 0.4, "tone_shape": "sine", "volume": 0.35},
	"coins": {"freq": 1568.0, "freq_end": 2093.0, "duration": 0.12, "tone_shape": "square", "volume": 0.18},
	"step": {"freq": 90.0, "freq_end": 60.0, "duration": 0.05, "noise": 0.7, "cutoff": 0.2, "volume": 0.15},
}

## Optional recorded assets: hook -> AudioStream. Takes priority over synthesis.
var overrides: Dictionary = {}

var _cache: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _ambient: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Music"
	_ambient.volume_db = -14.0
	add_child(_ambient)


func play(hook: String, pitch_variance: float = 0.06) -> void:
	var stream := _stream_for(hook)
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_variance, pitch_variance)
	player.play()


## Soft looping wind bed used on the title, story and lodge scenes.
func play_ambient() -> void:
	if _ambient.playing:
		return
	if not _cache.has("_ambient"):
		_cache["_ambient"] = _make_ambient()
	_ambient.stream = _cache["_ambient"]
	_ambient.play()


func stop_ambient() -> void:
	_ambient.stop()


func has_hook(hook: String) -> bool:
	return overrides.has(hook) or RECIPES.has(hook)


func _stream_for(hook: String) -> AudioStream:
	if overrides.has(hook):
		return overrides[hook]
	if not RECIPES.has(hook):
		push_warning("Sfx: unknown hook '%s'" % hook)
		return null
	if not _cache.has(hook):
		_cache[hook] = _synthesize(RECIPES[hook])
	return _cache[hook]


func _synthesize(recipe: Dictionary) -> AudioStreamWAV:
	var duration: float = recipe.get("duration", 0.1)
	var freq: float = recipe.get("freq", 440.0)
	var freq_end: float = recipe.get("freq_end", freq)
	var noise_mix: float = recipe.get("noise", 0.0)
	var cutoff: float = recipe.get("cutoff", 1.0)
	var volume: float = recipe.get("volume", 0.4)
	var shape: String = recipe.get("tone_shape", "sine")
	var attack: float = recipe.get("attack", 0.008)
	var count := int(duration * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var filtered := 0.0
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = hash(recipe)
	for i in count:
		var t := float(i) / MIX_RATE
		var progress := float(i) / count
		var f := lerpf(freq, freq_end, progress)
		phase = fmod(phase + f / MIX_RATE, 1.0)
		var tone := 0.0
		match shape:
			"square":
				tone = 1.0 if phase < 0.5 else -1.0
			"tri":
				tone = 4.0 * absf(phase - 0.5) - 1.0
			_:
				tone = sin(phase * TAU)
		filtered = lerpf(filtered, noise_rng.randf_range(-1.0, 1.0), cutoff)
		var envelope := minf(t / attack, 1.0) * pow(1.0 - progress, 2.0)
		var sample := (tone * (1.0 - noise_mix) + filtered * noise_mix) * envelope * volume
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _make_ambient() -> AudioStreamWAV:
	var seconds := 6.0
	var count := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var noise_rng := RandomNumberGenerator.new()
	noise_rng.seed = 7
	var filtered := 0.0
	for i in count:
		var t := float(i) / count
		# Slow gusts that loop seamlessly over the buffer.
		var gust := 0.55 + 0.45 * sin(t * TAU * 2.0) * sin(t * TAU * 3.0)
		filtered = lerpf(filtered, noise_rng.randf_range(-1.0, 1.0), 0.04 + 0.03 * gust)
		data.encode_s16(i * 2, int(clampf(filtered * gust * 2.2, -1.0, 1.0) * 32767.0 * 0.5))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav
