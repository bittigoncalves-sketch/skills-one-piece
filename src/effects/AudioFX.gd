class_name AudioFX
extends RefCounted
## Efeitos sonoros PROCEDURAIS (o projeto não tem assets de áudio). Gera WAVs curtos
## em memória e toca em AudioStreamPlayer3D posicional. Reutilizável por qualquer VFX.

const RATE := 22050

# ---- API ----
static func whoosh(world: Node, pos: Vector3, pitch := 1.0) -> void:
	_play(world, pos, _whoosh_stream(), pitch, 0.55)

static func snap(world: Node, pos: Vector3, pitch := 1.0) -> void:
	_play(world, pos, _snap_stream(), pitch, 0.7)

static func impact(world: Node, pos: Vector3, pitch := 1.0) -> void:
	_play(world, pos, _impact_stream(), pitch, 0.8)

static func hurt(world: Node, pos: Vector3, pitch := 1.0) -> void:
	_play(world, pos, _hurt_stream(), pitch, 0.85)

static func gunshot(world: Node, pos: Vector3, pitch := 1.0) -> void:
	_play(world, pos, _gunshot_stream(), pitch, 0.95)

# ---- infra ----
static func _play(world: Node, pos: Vector3, stream: AudioStream, pitch: float, vol_lin: float) -> void:
	if world == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = linear_to_db(clampf(vol_lin, 0.001, 1.0))
	p.max_distance = 45.0
	p.unit_size = 6.0
	world.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)

static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w

# "Fiu" elástico: ruído filtrado (média móvel) com envelope rápido sobe-desce.
static func _whoosh_stream() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / n
		var env: float = sin(t * PI)                      # 0->1->0
		var noise := randf() * 2.0 - 1.0
		prev = lerpf(prev, noise, 0.35)                    # lowpass -> "shh" suave
		s[i] = prev * env * 0.8
	return _wav(s)

# Estalo curto (chicote) — clique de ruído com decaimento muito rápido.
static func _snap_stream() -> AudioStreamWAV:
	var n := int(RATE * 0.09)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / n
		var env: float = pow(1.0 - t, 6.0)
		s[i] = (randf() * 2.0 - 1.0) * env
	return _wav(s)

# Recepção de dano ("ugh") — tom que DESCE rápido de frequência + ruído curto.
static func _hurt_stream() -> AudioStreamWAV:
	var n := int(RATE * 0.22)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / n
		var env: float = pow(1.0 - t, 2.2)
		var freq: float = lerpf(320.0, 90.0, t)               # glissando descendente
		var tone: float = sin(TAU * freq * (float(i) / RATE)) * env
		var grit: float = (randf() * 2.0 - 1.0) * pow(1.0 - t, 5.0) * 0.35
		s[i] = clampf(tone * 0.75 + grit, -1.0, 1.0)
	return _wav(s)

# Impacto — seno grave decaindo + clique inicial (soco chegando/saindo).
static func _impact_stream() -> AudioStreamWAV:
	var n := int(RATE * 0.18)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / n
		var env: float = pow(1.0 - t, 3.0)
		var tone: float = sin(TAU * 120.0 * (float(i) / RATE)) * env
		var click: float = (randf() * 2.0 - 1.0) * pow(1.0 - t, 12.0) * 0.6
		s[i] = clampf(tone * 0.8 + click, -1.0, 1.0)
	return _wav(s)

# Som de tiro de arma de fogo real e potente (explosão do cano, estalo metálico e eco grave).
static func _gunshot_stream() -> AudioStreamWAV:
	var n := int(RATE * 0.28)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / n
		var blast_env := pow(1.0 - minf(t * 3.5, 1.0), 4.0)
		var trail_env := pow(1.0 - t, 2.0)
		var noise := (randf() * 2.0 - 1.0)
		var freq := lerpf(450.0, 50.0, minf(t * 4.0, 1.0))
		var tone := sin(TAU * freq * (float(i) / RATE)) * 0.6 * blast_env
		var rumble := sin(TAU * 75.0 * (float(i) / RATE)) * 0.3 * trail_env
		var sample: float = (noise * 0.95 + tone) * blast_env + (noise * 0.2 + rumble) * trail_env * 0.4
		s[i] = clampf(sample * 1.25, -1.0, 1.0)
	return _wav(s)
