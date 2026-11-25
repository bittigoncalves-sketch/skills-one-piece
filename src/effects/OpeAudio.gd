extends RefCounted
## Assets mono de 48 kHz, sintetizados offline; nenhuma síntese no frame de cast.

const CUES := {
	"room": "res://assets/audio/ope_room.wav",
	"shambles": "res://assets/audio/ope_shambles.wav",
	"takt": "res://assets/audio/ope_takt.wav",
	"gamma": "res://assets/audio/ope_gamma.wav",
	"impact": "res://assets/audio/ope_impact.wav",
}
static var _streams: Dictionary = {}

static func play(parent: Node, position: Vector3, cue: String) -> void:
	if not is_instance_valid(parent) or DisplayServer.get_name() == "headless":
		return
	if not CUES.has(cue):
		return
	if not _streams.has(cue):
		_streams[cue] = load(CUES[cue])
	var stream := _streams[cue] as AudioStream
	if stream == null:
		return
	var sound := AudioStreamPlayer3D.new()
	sound.name = "OpeAudio_" + cue
	sound.stream = stream
	sound.volume_db = -9.0 if cue == "impact" else -5.5
	sound.unit_size = 7.0
	sound.max_distance = 60.0
	sound.max_polyphony = 1
	parent.add_child(sound)
	sound.global_position = position
	sound.finished.connect(sound.queue_free)
	sound.play()
