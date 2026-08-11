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

static func cannon(world: Node, pos: Vector3, pitch := 1.0) -> void:
	_play(world, pos, _cannon_stream(), pitch, 1.0)

# ---- ARSENAL DA BUKI BUKI (2026-08-11) ----------------------------------
# As quatro armas tocavam o MESMO `gunshot` (só o canhão era exceção). Som é o
# que separa minigun de sniper sem olhar pra tela: numa troca de arma o jogador
# ouve antes de ver. Cada um ataca uma faixa diferente do espectro e uma duração
# diferente — é o par (brilho, cauda) que identifica a arma, não o volume.
#
#   pistola  0,16 s  estalo curto e AGUDO, cauda quase nenhuma
#   sniper   0,70 s  estalo seco + eco de verdade (duas repetições atrasadas)
#   minigun  0,08 s  poc seco e BAIXO — toca 17×/s, forte vira serra elétrica
#   canhão   0,95 s  (já existia) estouro grave que escorrega de 110 pra 38 Hz
static func pistol(world: Node, pos: Vector3, pitch := 1.0) -> void:
	_play(world, pos, _pool("pistol"), pitch, 0.85)

static func sniper(world: Node, pos: Vector3, pitch := 1.0) -> void:
	_play(world, pos, _pool("sniper"), pitch, 1.0)

static func minigun(world: Node, pos: Vector3, pitch := 1.0) -> void:
	_play(world, pos, _pool("minigun"), pitch, 0.42)

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

# POOL DE VARIANTES. Os sons antigos são sintetizados a CADA disparo — tudo bem
# quando o gatilho é lento, mas o minigun toca 17 vezes por segundo e ficar
# gerando ~1.700 amostras por tiro é trabalho jogado fora. Guardamos 3 versões
# de cada som (o ruído de cada uma é diferente) e sorteamos: repetição sem custo
# e sem virar o mesmo clique metrônomo. Só os sons novos passam por aqui; mexer
# no `gunshot` mexeria também na pistola da Yami, que não é deste trabalho.
const VARIANTES := 3
static var _cache: Dictionary = {}

static func _pool(nome: String) -> AudioStreamWAV:
	if not _cache.has(nome):
		var arr: Array = []
		for _i in VARIANTES:
			arr.append(_gerar(nome))
		_cache[nome] = arr
	var arr2: Array = _cache[nome]
	return arr2[randi() % arr2.size()]

static func _gerar(nome: String) -> AudioStreamWAV:
	match nome:
		"pistol": return _pistol_stream()
		"sniper": return _sniper_stream()
		"minigun": return _minigun_stream()
	return _gunshot_stream()

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

# PISTOLA (Z) — 0,16 s. O oposto do canhão: quase só ATAQUE. O brilho vem de um
# ruído passa-ALTA (amostra menos a média móvel), que é o que dá o "tec" seco;
# ruído cru soa abafado, e a pistola tem que cortar por cima da rajada.
static func _pistol_stream() -> AudioStreamWAV:
	var n := int(RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var media := 0.0
	for i in n:
		var t := float(i) / n
		var estalo := pow(1.0 - minf(t * 7.0, 1.0), 3.0)     # ~23 ms de tapa
		var cauda := pow(1.0 - t, 3.5)
		var ruido := randf() * 2.0 - 1.0
		media = lerpf(media, ruido, 0.45)
		var agudo := ruido - media                            # passa-alta pobre
		var f := lerpf(880.0, 190.0, minf(t * 5.0, 1.0))
		var corpo := sin(TAU * f * (float(i) / RATE)) * 0.45 * estalo
		s[i] = clampf((agudo * 1.5 + corpo) * estalo + agudo * 0.18 * cauda, -1.0, 1.0)
	return _wav(s)

# SNIPER (C) — 0,70 s. Tiro SECO com CAUDA: o estalo é ainda mais curto que o da
# pistola (~13 ms), e o que sobra é o ambiente devolvendo o som. O eco é eco de
# verdade — as amostras já calculadas voltam atrasadas 130 ms e 290 ms —, não um
# tremolo fingido; é a diferença entre "longe" e "com reverb ligado".
static func _sniper_stream() -> AudioStreamWAV:
	var n := int(RATE * 0.70)
	var s := PackedFloat32Array()
	s.resize(n)
	var fase := 0.0
	for i in n:
		var t := float(i) / n
		var estalo := pow(1.0 - minf(t * 54.0, 1.0), 2.0)     # ~13 ms
		var corpo := pow(1.0 - minf(t * 4.5, 1.0), 2.0)
		var ruido := randf() * 2.0 - 1.0
		var f := lerpf(300.0, 62.0, minf(t * 6.0, 1.0))
		fase += TAU * f / RATE
		s[i] = clampf(ruido * 0.95 * estalo + sin(fase) * 0.75 * corpo, -1.0, 1.0)
	var d1 := int(RATE * 0.130)
	var d2 := int(RATE * 0.290)
	for i in range(d1, n):
		var eco: float = s[i - d1] * 0.30
		if i >= d2:
			eco += s[i - d2] * 0.15
		s[i] = clampf(s[i] + eco * pow(1.0 - float(i) / n, 0.8), -1.0, 1.0)
	return _wav(s)

# MINIGUN (V) — 0,08 s. Curto porque a cadência é 0,06 s: som mais longo que o
# intervalo empilha em drone contínuo e some a sensação de tiro-a-tiro. Baixo
# (0,42 de volume) pelo mesmo motivo — são ~17 por segundo, e a soma é que dá o
# volume da rajada.
static func _minigun_stream() -> AudioStreamWAV:
	var n := int(RATE * 0.08)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / n
		var env: float = pow(1.0 - t, 4.0)
		var ruido := randf() * 2.0 - 1.0
		var f := lerpf(700.0, 240.0, minf(t * 3.0, 1.0))
		var corpo := sin(TAU * f * (float(i) / RATE)) * 0.40
		s[i] = clampf((ruido * 0.70 + corpo) * env, -1.0, 1.0)
	return _wav(s)

# CANHÃO — mais longo e mais grave que o tiro de pistola, com três camadas:
#   1. estalo seco do disparo (ruído filtrado, morre em ~40 ms)
#   2. corpo grave que ESCORREGA de 110 Hz para 38 Hz (é essa descida que dá a
#      sensação de calibre; um tom fixo lê como bumbo de bateria)
#   3. cauda de eco, que faz o som "ocupar espaço"
static func _cannon_stream() -> AudioStreamWAV:
	var n := int(RATE * 0.95)
	var s := PackedFloat32Array()
	s.resize(n)
	var sub := 0.0          # integrador do sub-grave (mantém a fase contínua)
	for i in n:
		var t := float(i) / n
		var seg := float(i) / RATE
		var estalo := pow(1.0 - minf(t * 22.0, 1.0), 3.0)
		var corpo := pow(1.0 - minf(t * 1.7, 1.0), 2.2)
		var cauda := pow(1.0 - t, 1.5)

		var f := lerpf(110.0, 38.0, minf(t * 2.4, 1.0))
		sub += TAU * f / RATE
		var grave := sin(sub) * corpo
		var ruido := (randf() * 2.0 - 1.0)
		# eco: repete o estalo atenuado a cada ~180 ms
		var eco := sin(TAU * 52.0 * seg) * cauda * 0.22 * (0.5 + 0.5 * sin(TAU * 5.5 * seg))

		var v: float = ruido * 0.85 * estalo + grave * 0.9 + ruido * 0.10 * cauda + eco
		s[i] = clampf(v * 1.15, -1.0, 1.0)
	return _wav(s)
