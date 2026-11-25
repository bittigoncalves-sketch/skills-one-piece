class_name GomuAudio
extends RefCounted
## Efeitos sonoros originais e determinísticos da Gomu Gomu no Mi, Gear 2 e Gear 3.
## Assets espaciais mono a 48 kHz sintetizados offline; zero síntese em tempo de execução.

const CUES := {
	"stretch": "res://assets/audio/gomu_stretch.wav",
	"pistol": "res://assets/audio/gomu_pistol.wav",
	"bazooka": "res://assets/audio/gomu_bazooka.wav",
	"gatling": "res://assets/audio/gomu_gatling.wav",
	"gear2_steam": "res://assets/audio/gomu_gear2_steam.wav",
	"jet_pistol": "res://assets/audio/gomu_jet_pistol.wav",
	"gear3_inflate": "res://assets/audio/gomu_gear3_inflate.wav",
	"gear3_impact": "res://assets/audio/gomu_gear3_impact.wav",
}
static var _streams: Dictionary = {}

static func play(parent: Node, position: Vector3, cue: String, volume_offset: float = 0.0) -> void:
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
	sound.name = "GomuAudio_" + cue
	sound.stream = stream
	sound.volume_db = -4.5 + volume_offset
	sound.unit_size = 9.0 if cue.begins_with("gear3") else 7.0
	sound.max_distance = 80.0 if cue.begins_with("gear3") else 60.0
	sound.max_polyphony = 2
	parent.add_child(sound)
	sound.global_position = position
	sound.finished.connect(sound.queue_free)
	sound.play()
