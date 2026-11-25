class_name UshiAudio
extends RefCounted
## Sons da Ushi Ushi (21/11/2026, pedido do dono: "um som para cada ataque"). PCM mono sintetizado e determinístico, criado UMA vez por cue e
## compartilhado (mesmo desenho do `YoruAudio`): sem arquivos, sem dependência. Cada ataque tem a sua assinatura:
##   z_investida  Z humano/humanoide  — o pescoço se estica: sopro que sobe + "thwip" elástico grave
##   z_pescocada  Z girafa            — chicote: estalo seco + queda de tom + baque do corpo
##   x_corte      X humano/humanoide  — chute aéreo: varrida de ar que sobe + "shing" metálico agudo que ressoa
##   c_corte      C (um por corte)    — talho curto e rápido (3 variantes de tom, para a rajada não soar repetida)
##   martelada    X girafa            — varrida larga e pesada + BONK grave de madeira no contato
##   impacto      acerto do pescoço   — baque grave + estalo; `impacto_corte` = a lâmina entrando no alvo
const RATE := 22050
const DURACAO := {"z_investida": 0.46, "z_pescocada": 0.42, "x_corte": 0.55, "c_corte": 0.17, "c_corte_b": 0.17, "c_corte_c": 0.17,
	"martelada": 0.62, "impacto": 0.30, "impacto_corte": 0.20}
const MAX_VOZES := 20
static var _cache: Dictionary = {}
static var _vozes: Array[WeakRef] = []


## Toca `cue` em `pai`. `variante` escolhe o tom do talho da rajada (0..2). Mudo em --headless.
static func tocar(pai: Node3D, cue: String, variante := 0, volume_db := -6.0) -> void:
	if not is_instance_valid(pai) or not pai.is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	if cue == "c_corte":
		cue = ["c_corte", "c_corte_b", "c_corte_c"][variante % 3]
	if not DURACAO.has(cue):
		return
	_vozes = _vozes.filter(func(r: WeakRef) -> bool: return is_instance_valid(r.get_ref()))
	if _vozes.size() >= MAX_VOZES:
		var velho: Node = _vozes.pop_front().get_ref()
		if is_instance_valid(velho): velho.queue_free()
	var p := AudioStreamPlayer3D.new()
	_vozes.append(weakref(p))
	p.name = "UshiAudio_" + cue
	p.stream = stream(cue)
	p.volume_db = volume_db
	p.unit_size = 6.0
	p.max_distance = 60.0
	p.top_level = true
	pai.add_child(p)
	p.global_position = pai.global_position + Vector3.UP * 1.0
	p.finished.connect(p.queue_free)
	p.play()


static func stream(cue: String) -> AudioStreamWAV:
	if _cache.has(cue):
		return _cache[cue]
	var n := int(float(DURACAO[cue]) * RATE)
	var amostras := PackedFloat32Array()
	amostras.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21112026 + cue.hash()
	var baixo := 0.0       # filtro passa-baixa do ruído
	var fase1 := 0.0
	var fase2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / (n - 1)
		var ruido := rng.randf_range(-1.0, 1.0)
		var s := 0.0
		match cue:
			"z_investida":
				# sopro que sobe até 0,22 s e some; "thwip" elástico: seno que cai de 260 para 90 Hz
				var env := pow(sin(clampf(u / 0.55, 0.0, 1.0) * PI * 0.5), 1.5) * exp(-maxf(0.0, u - 0.5) * 7.0)
				baixo = lerpf(baixo, ruido, lerpf(0.10, 0.5, u))
				fase1 += TAU * lerpf(260.0, 90.0, minf(1.0, u * 1.6)) / RATE
				s = baixo * env * 0.9 + sin(fase1) * exp(-u * 4.0) * 0.45 * (1.0 if u > 0.35 else u / 0.35)
			"z_pescocada":
				# estalo seco (ruído agudo muito curto) + queda de tom de chicote + baque grave em 0,14 s
				var estalo := (ruido - baixo) * exp(-t * 55.0)
				baixo = lerpf(baixo, ruido, 0.3)
				fase1 += TAU * lerpf(520.0, 110.0, minf(1.0, t / 0.2)) / RATE
				fase2 += TAU * 62.0 / RATE
				s = estalo * 0.9 + sin(fase1) * exp(-t * 14.0) * 0.5 + sin(fase2) * exp(-maxf(0.0, t - 0.14) * 16.0) * (0.0 if t < 0.14 else 0.8)
			"x_corte":
				# varrida de ar (passa-banda subindo) + "shing" metálico: dois senos agudos inarmônicos com decaimento longo a partir de 0,22 s
				var cutoff := lerpf(0.06, 0.55, pow(minf(1.0, u / 0.45), 2.0))
				baixo = lerpf(baixo, ruido, cutoff)
				var ar := (ruido - baixo) * sin(clampf(u / 0.5, 0.0, 1.0) * PI) * 0.7
				var ts := maxf(0.0, t - 0.22)
				fase1 += TAU * lerpf(3100.0, 2300.0, minf(1.0, ts / 0.3)) / RATE
				fase2 += TAU * lerpf(4650.0, 3500.0, minf(1.0, ts / 0.3)) / RATE
				var metal := (sin(fase1) * 0.5 + sin(fase2) * 0.25) * exp(-ts * 9.0) * (0.0 if t < 0.22 else 1.0)
				s = ar + metal * 0.7
			"c_corte", "c_corte_b", "c_corte_c":
				var f0 := 3300.0 if cue == "c_corte" else (2600.0 if cue == "c_corte_b" else 4100.0)
				baixo = lerpf(baixo, ruido, 0.35)
				fase1 += TAU * lerpf(f0, f0 * 0.6, minf(1.0, u * 1.3)) / RATE
				s = (ruido - baixo) * exp(-t * 28.0) * 0.6 + sin(fase1) * exp(-t * 22.0) * 0.5
			"martelada":
				# varrida larga e grave (0..0,3 s) + BONK em 0,30 s: seno que cai de 170 para 55 Hz + clique de madeira
				var cut := lerpf(0.04, 0.22, minf(1.0, u / 0.5))
				baixo = lerpf(baixo, ruido, cut)
				var vento := baixo * sin(clampf(t / 0.3, 0.0, 1.0) * PI * 0.5) * (1.0 if t < 0.3 else exp(-(t - 0.3) * 18.0)) * 1.1
				var tb := maxf(0.0, t - 0.30)
				fase1 += TAU * lerpf(170.0, 55.0, minf(1.0, tb / 0.18)) / RATE
				var bonk := sin(fase1) * exp(-tb * 11.0) * (0.0 if t < 0.30 else 1.0) * 1.0
				var clique := (ruido - baixo) * exp(-tb * 60.0) * (0.0 if t < 0.30 else 0.7)
				s = vento * 0.8 + bonk + clique
			"impacto":
				baixo = lerpf(baixo, ruido, 0.25)
				fase1 += TAU * lerpf(150.0, 60.0, minf(1.0, t / 0.12)) / RATE
				s = sin(fase1) * exp(-t * 14.0) * 0.9 + (ruido - baixo) * exp(-t * 60.0) * 0.5
			"impacto_corte":
				baixo = lerpf(baixo, ruido, 0.4)
				fase1 += TAU * lerpf(900.0, 300.0, minf(1.0, t / 0.1)) / RATE
				s = (ruido - baixo) * exp(-t * 35.0) * 0.5 + sin(fase1) * exp(-t * 26.0) * 0.5
		# ataque curtíssimo (evita estalo de clique no início) e saída suave
		s *= minf(1.0, float(i) / 40.0) * minf(1.0, float(n - i) / 200.0)
		amostras[i] = clampf(s, -1.0, 1.0)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(amostras[i] * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	_cache[cue] = w
	return w


## Pico absoluto e duração de um cue (teste: nenhum cue pode sair mudo ou estourar).
static func pico(cue: String) -> float:
	var d := stream(cue).data
	var m := 0.0
	for i in range(0, d.size(), 2):
		m = maxf(m, absf(float(d.decode_s16(i))) / 32767.0)
	return m
