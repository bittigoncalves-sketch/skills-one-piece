class_name YoruAudio
extends RefCounted
## Assinatura própria: ar cortado, aço ressonante e energia grave da Yoru.
## PCM mono determinístico, criado uma vez por cue e compartilhado depois.

const RATE := 22050
const DURATIONS := {"swing": 0.26, "impact": 0.34, "parry": 0.64,
	"charge": 0.56, "wave": 0.62}
static var _cache: Dictionary = {}
static var _voices: Array[WeakRef] = []
const MAX_VOICES := 24


static func play(parent: Node3D, kind: String) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if not DURATIONS.has(kind) or DisplayServer.get_name() == "headless":
		return
	_voices = _voices.filter(func(ref: WeakRef) -> bool: return is_instance_valid(ref.get_ref()))
	if _voices.size() >= MAX_VOICES:
		var oldest: Node = _voices.pop_front().get_ref()
		if is_instance_valid(oldest): oldest.queue_free()
	var sound := AudioStreamPlayer3D.new()
	_voices.append(weakref(sound))
	sound.name = "YoruAudio_" + kind
	sound.stream = _stream(kind)
	sound.volume_db = -10.0 if kind == "charge" else -7.0
	sound.unit_size = 5.0
	sound.max_distance = 48.0
	sound.max_polyphony = 1
	sound.top_level = true
	parent.add_child(sound)
	sound.global_position = parent.global_position
	sound.finished.connect(sound.queue_free)
	sound.play()


static func _stream(kind: String) -> AudioStreamWAV:
	if not DURATIONS.has(kind):
		return null
	if _cache.has(kind):
		return _cache[kind] as AudioStreamWAV
	var duration: float = DURATIONS[kind]
	var count := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 9713 + kind.hash()
	var filtered := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var progress := float(i) / (count - 1)
		var noise := random.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, 0.22)
		var high := noise - filtered
		var sample := 0.0
		match kind:
			"swing":
				# Narrow rushing edge with a short descending steel overtone.
				phase += TAU * lerpf(1500.0, 320.0, progress) / RATE
				sample = (high * 0.72 + filtered * 0.4 + sin(phase) * 0.09) \
					* pow(sin(PI * progress), 1.7)
			"impact":
				sample = filtered * 1.4 * exp(-t * 42.0) \
					+ high * 0.5 * exp(-t * 64.0) \
					+ (sin(TAU * 690.0 * t) + sin(TAU * 1107.0 * t) * 0.45) \
					* 0.22 * exp(-t * 17.0)
			"parry":
				# Inharmonic partials distinguish blade contact from a body hit.
				sample = high * 0.55 * exp(-t * 95.0) \
					+ (sin(TAU * 1320.0 * t) * 0.32 \
					+ sin(TAU * 2097.0 * t) * 0.21 \
					+ sin(TAU * 3379.0 * t) * 0.10) * exp(-t * 8.5)
			"charge":
				phase += TAU * lerpf(110.0, 250.0, progress) / RATE
				sample = (sin(phase) * 0.42 + sin(phase * 2.01) * 0.15 \
					+ filtered * 0.4) * pow(sin(PI * progress), 0.7)
			"wave":
				phase += TAU * lerpf(460.0, 85.0, progress) / RATE
				sample = (filtered * 1.15 + high * 0.21 \
					+ sin(phase) * 0.22) * sin(PI * minf(progress * 4.0, 1.0) * 0.5) \
					* pow(1.0 - progress, 1.8)
		# Two millisecond onset and a final fade prevent discontinuity clicks.
		sample *= minf(1.0, t / 0.002) * minf(1.0, (duration - t) / 0.018)
		bytes.encode_s16(i * 2, int(clampf(sample * 0.78, -0.96, 0.96) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	_cache[kind] = stream
	return stream
