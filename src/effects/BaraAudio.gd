extends RefCounted
## Sons mono produzidos offline. O limite por cena evita rajadas de V sobrepostas.

const CUES := {
	"split": "res://assets/audio/bara_split.wav",
	"shot": "res://assets/audio/bara_shot.wav",
	"impact": "res://assets/audio/bara_impact.wav",
	"return": "res://assets/audio/bara_return.wav",
	"blast": "res://assets/audio/bara_blast.wav",
}
static var _streams: Dictionary = {}

static func play(world: Node, at: Vector3, event: String) -> void:
	if not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion():
		return
	if DisplayServer.get_name() == "headless" or not CUES.has(event):
		return
	if not _streams.has(event):
		if not ResourceLoader.exists(CUES[event]):
			return
		_streams[event] = load(CUES[event])
	var stream := _streams[event] as AudioStream
	if stream == null:
		return
	var voices := world.get_tree().get_nodes_in_group("bara_audio")
	if voices.size() >= 16:
		return
	var sound := AudioStreamPlayer3D.new()
	sound.name = "BaraAudio_" + event
	sound.stream = stream
	sound.volume_db = -7.5 if event in ["shot", "blast"] else -10.0
	sound.unit_size = 7.0
	sound.max_distance = 55.0
	sound.max_polyphony = 1
	world.add_child(sound)
	sound.add_to_group("bara_audio")
	sound.global_position = at
	sound.finished.connect(sound.queue_free)
	sound.play()
