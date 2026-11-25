extends RefCounted
## O que uma skill do Builder DESENHA e TOCA, numa fonte só (06/10/2026).
##
## A prévia do Builder (`arena_preview.gd`) e o executor do jogo
## (`executor_de_skill.gd`) usam estas funções: o VFX que o dono vê no editor é o
## mesmo que aparece em jogo. Antes elas moravam só na prévia.

## Som de cada opção do catálogo fechado do Builder (`dados_skill.gd`, seção Áudio).
const SONS := {"Vento": "dash", "Impacto": "plop", "Disparo": "pistol",
	# Gelo (Hie refeita, 07/10/2026): o estalo cristalino do Z antigo e um sopro frio.
	"Gelo: disparo": "snap", "Gelo: rajada": "whoosh"}
## "Luz: …" → cue do `PikaAudio` (a voz da Pika, gerada por `tools/generate_pika_audio.py`).
const SONS_DE_LUZ := {"Luz: carga": "carga", "Luz: disparo": "disparo", "Luz: fragmento": "fragmento",
	"Luz: impacto": "impacto", "Luz: viagem": "viagem", "Luz: explosão": "explosao",
	"Luz: teleporte": "teleporte", "Luz: barragem": "barragem"}


static func malha(pai: Node3D, mesh: Mesh, cor: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 1.0
	if cor.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	n.material_override = mat
	pai.add_child(n)
	return n


## Estilos de "fótons cintilantes" (Noro Noro, 06/10/2026): animação própria por estilo.
const ESTILOS_DE_FOTONS := ["Carga", "Feixe", "Fótons"]
const AuraDeLentidao := preload("res://src/skills_builder/aura_de_lentidao.gd")
const N_CARGA := 22
const N_FEIXE := 42
const N_FOTONS := 36

static var _shader_tubo: Shader = null


## Onde o efeito nasce, relativo ao pé e à frente do ator (X lado, Y altura, −Z frente).
static func lugar(p: Dictionary) -> Vector3:
	return Vector3(0, float(p.get("altura", 1.0)), -float(p.get("frente", 1.0)))


## O efeito de um bloco de VFX, já filho de `pai`.
static func vfx(pai: Node3D, p: Dictionary) -> Node3D:
	var fx := Node3D.new()
	pai.add_child(fx)
	var cor := Color(p.cor)
	var estilo: String = p.estilo
	if estilo in ESTILOS_DE_FOTONS:
		_montar_fotons(fx, estilo, cor, float(p.escala), segunda_cor(p))
		return fx
	if estilo == "Cometa":
		_montar_cometa(fx, cor, float(p.escala))
		return fx
	if estilo == "Explosão":
		_montar_explosao(fx, cor, float(p.escala))
		return fx
	if estilo == "Estrela":
		_montar_estrela(fx, cor, float(p.escala))
		return fx
	if estilo == "Rachadura":
		_montar_rachadura(fx, cor, float(p.escala))
		return fx
	if estilo == "Impacto":
		for i in 10:
			var ponta := PrismMesh.new()
			ponta.size = Vector3(0.12, 0.85, 0.12)
			var n := malha(fx, ponta, cor)
			var a := float(i) * TAU / 10
			n.position = Vector3(cos(a), sin(a), 0) * 0.55
			n.rotation.z = a - PI * 0.5
	else:
		var count := 7 if estilo == "Tornado" else (3 if estilo == "Vento" else 1)
		for i in count:
			var anel := TorusMesh.new()
			var r := 0.25 + i * 0.16 if estilo == "Tornado" else 0.7 + i * 0.17
			anel.inner_radius = r
			anel.outer_radius = r + 0.065
			anel.rings = 32
			anel.ring_segments = 6
			var n := malha(fx, anel, cor)
			n.position.y = i * 0.22 - 0.7 if estilo == "Tornado" else i * 0.1
			n.rotation.x = i * 0.17 if estilo == "Vento" else 0.0
	return fx


## O pulso do VFX ao longo do bloco: gira e cresce até o meio, encolhe no fim.
## `local` = segundos dentro do bloco; `u` = fração do bloco (0..1).
static func animar_vfx(fx: Node3D, p: Dictionary, local: float, u: float) -> void:
	match str(p.estilo):
		"Carga": _animar_carga(fx, p, local, u)
		"Feixe": _animar_feixe(fx, p, local, u)
		"Fótons": _animar_burst(fx, p, local, u)
		"Cometa": _animar_cometa(fx, p, local, u)
		"Explosão": _animar_explosao(fx, p, u)
		"Estrela": _animar_estrela(fx, p, local, u)
		"Rachadura": _animar_rachadura(fx, u)
		_:
			fx.rotation.y = local * 8
			fx.scale = Vector3.ONE * float(p.escala) * (0.4 + sin(u * PI) * 0.7)


# ------------------------------------------------------- fótons cintilantes
# Direção (escolha do dono): rosa/lilás com núcleo branco, devagar, cintilando. Tudo é
# calculado pelo TEMPO do bloco (sem partículas de GPU): a régua da prévia volta no
# tempo e o jogo mostra o mesmo desenho.

## Segunda cor dos efeitos de luz (06/10/2026): a das cintilas e do véu do feixe. Vazia =
## o lilás da Noro (o visual aprovado dela não muda); a Pika usa um dourado claro.
static func segunda_cor(p: Dictionary) -> Color:
	var c := str(p.get("cor_2", ""))
	return Color(c) if c.begins_with("#") else Color(0.71, 0.55, 1.0)


static func _montar_fotons(fx: Node3D, estilo: String, cor: Color, escala: float, lilas := Color(0.71, 0.55, 1.0)) -> void:
	var cintilas := Node3D.new()
	cintilas.name = "Cintilas"
	fx.add_child(cintilas)
	var n := N_CARGA if estilo == "Carga" else (N_FEIXE if estilo == "Feixe" else N_FOTONS)
	for i in n:
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * (0.26 if estilo == "Carga" else 0.34) * escala
		q.mesh = quad
		var m := AuraDeLentidao.material_de_cintila()
		m.albedo_color = cor.lerp(lilas, float(i % 4) / 3.0 * 0.6).lerp(Color.WHITE, 0.15 if i % 5 == 0 else 0.0)
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cintilas.add_child(q)
	if estilo == "Carga":
		fx.add_child(esfera_de_brilho("Nucleo", Color.WHITE, 0.16 * escala, 1.2))
		fx.add_child(esfera_de_brilho("Halo", cor, 0.55 * escala, 2.6))
	elif estilo == "Feixe":
		fx.add_child(_tubo("Nucleo", Color(1, 0.97, 1), 0.07 * escala, 1.0))
		fx.add_child(_tubo("Brilho", cor, 0.32 * escala, 2.2))
		fx.add_child(_tubo("Veu", lilas, 0.6 * escala, 3.5))
		fx.add_child(esfera_de_brilho("Boca", Color.WHITE, 0.2 * escala, 1.4))


## Tubo de brilho ao longo de −Z (comprimento 1, escalado em Z na animação).
static func _tubo(nome: String, cor: Color, raio: float, expoente: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var cil := CylinderMesh.new()
	cil.top_radius = raio
	cil.bottom_radius = raio
	cil.height = 1.0
	cil.radial_segments = 18
	cil.rings = 1
	cil.cap_top = false          # sem tampa: o fim do feixe some suave, não vira um disco
	cil.cap_bottom = false
	mi.mesh = cil
	mi.material_override = _material_de_brilho(cor, expoente)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func esfera_de_brilho(nome: String, cor: Color, raio: float, expoente: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var esf := SphereMesh.new()
	esf.radius = raio
	esf.height = raio * 2.0
	esf.radial_segments = 20
	esf.rings = 10
	mi.mesh = esf
	mi.material_override = _material_de_brilho(cor, expoente)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Brilho aditivo de bordas suaves: forte onde a superfície encara a câmera, some na
## borda (a forma lê como luz, não como plástico).
static func _material_de_brilho(cor: Color, expoente: float) -> ShaderMaterial:
	if _shader_tubo == null:
		_shader_tubo = Shader.new()
		_shader_tubo.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 cor : source_color = vec4(1.0);
uniform float expoente = 2.0;
uniform float intensidade = 1.0;
void fragment() {
	float f = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), expoente);
	// Piso de 0,3: visto no sentido do comprimento (a câmera de ombro, atrás de quem
	// atira), a superfície fica de lado para a câmera e o feixe sumia (foto em jogo).
	float g = 0.3 + 0.7 * f;
	ALBEDO = cor.rgb * (0.6 + 1.4 * g) * intensidade;
	ALPHA = clamp(g * cor.a * intensidade, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader_tubo
	m.set_shader_parameter("cor", cor)
	m.set_shader_parameter("expoente", expoente)
	m.set_shader_parameter("intensidade", 1.0)
	return m


static func _brilho(no: Node, intensidade: float) -> void:
	if no is MeshInstance3D and (no as MeshInstance3D).material_override is ShaderMaterial:
		((no as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("intensidade", intensidade)


## Entrada e saída suaves do bloco (0 → 1 → 0).
static func _envelope(u: float, entra := 0.15, sai := 0.2) -> float:
	return clampf(minf(u / entra, (1.0 - u) / sai), 0.0, 1.0)


## CARGA: fótons espiralando PARA o núcleo, que cresce e pulsa.
static func _animar_carga(fx: Node3D, p: Dictionary, local: float, u: float) -> void:
	var e := float(p.escala)
	var env := _envelope(u, 0.1, 0.12)
	var cresce := 0.35 + 0.65 * smoothstep(0.0, 1.0, u)
	var pulso := 1.0 + 0.08 * sin(local * 12.0)
	for nome in ["Nucleo", "Halo"]:
		var no := fx.get_node(nome) as Node3D
		no.scale = Vector3.ONE * cresce * pulso
		_brilho(no, env)
	var cintilas := fx.get_node("Cintilas").get_children()
	for i in cintilas.size():
		var q := cintilas[i] as Node3D
		var fase := fmod(local * 0.9 + float(i) * 0.137, 1.0)       # 0 = longe, 1 = chegou
		var raio := lerpf(1.4, 0.08, fase * fase) * e
		var ang := float(i) * 2.399 + fase * 4.0
		var alt := sin(float(i) * 1.7) * 0.5 * (1.0 - fase) * e
		q.position = Vector3(cos(ang) * raio, alt, sin(ang) * raio)
		q.scale = Vector3.ONE * (0.5 + fase) * env
		var m := (q as MeshInstance3D).material_override as StandardMaterial3D
		m.albedo_color.a = env * smoothstep(0.0, 0.25, fase) * (1.0 - smoothstep(0.85, 1.0, fase))


## FEIXE: cresce até o comprimento, núcleo branco + brilho rosa + véu lilás, e uma fita de
## cintilas ondulando DEVAGAR ao longo dele, correndo para a frente.
static func _animar_feixe(fx: Node3D, p: Dictionary, local: float, u: float) -> void:
	var e := float(p.escala)
	var comp := float(p.get("comprimento", 8.0))
	var env := _envelope(u, 0.08, 0.25)
	var alcance := comp * smoothstep(0.0, 0.18, u)                # sai da mão e estica
	var tremor := 1.0 + 0.06 * sin(local * 23.0) + 0.04 * sin(local * 37.0)
	for nome in ["Nucleo", "Brilho", "Veu"]:
		var no := fx.get_node(nome) as Node3D
		no.rotation = Vector3(PI / 2, 0, 0)                           # eixo Y do cilindro → −Z
		no.scale = Vector3(tremor, maxf(alcance, 0.01), tremor)
		no.position = Vector3(0, 0, -alcance * 0.5)
		_brilho(no, env * (1.0 if nome != "Veu" else 0.7))
	var boca := fx.get_node("Boca") as Node3D
	boca.scale = Vector3.ONE * (1.0 + 0.25 * sin(local * 18.0))
	_brilho(boca, env)
	var cintilas := fx.get_node("Cintilas").get_children()
	for i in cintilas.size():
		var q := cintilas[i] as Node3D
		# Duas fitas em hélice (pares e ímpares em lados opostos), correndo devagar para a
		# frente: é o que faz o feixe ler como FÓTONS e não como laser.
		var k := fmod(float(i) / cintilas.size() + local * 0.35, 1.0)
		var z := -k * alcance
		var giro := z * 1.1 - local * 2.0 + (PI if i % 2 == 1 else 0.0)
		var lado := 0.36 * e * (0.75 + 0.25 * sin(float(i) * 3.1 + local))
		q.position = Vector3(cos(giro) * lado, sin(giro) * lado, z)
		var pisca := 0.5 + 0.5 * sin(local * 9.0 + float(i) * 2.3)
		q.scale = Vector3.ONE * (0.6 + 0.7 * pisca) * env
		var m := (q as MeshInstance3D).material_override as StandardMaterial3D
		m.albedo_color.a = env * (0.35 + 0.65 * pisca) * (1.0 - smoothstep(0.85, 1.0, k))


## FÓTONS: estouro de cintilas que se abrem DEVAGAR e somem (o tempo esticado).
static func _animar_burst(fx: Node3D, p: Dictionary, local: float, u: float) -> void:
	var e := float(p.escala)
	var cintilas := fx.get_node("Cintilas").get_children()
	var abre := 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)
	for i in cintilas.size():
		var q := cintilas[i] as Node3D
		var th := float(i) * 2.399
		var y := 1.0 - 2.0 * (float(i) + 0.5) / cintilas.size()
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var dir := Vector3(cos(th) * r, y, sin(th) * r)
		q.position = dir * (0.25 + 2.0 * abre) * e + Vector3(0, local * 0.15, 0)
		var pisca := 0.5 + 0.5 * sin(local * 7.0 + float(i) * 1.9)
		q.scale = Vector3.ONE * (0.5 + 0.8 * pisca) * (1.0 - u * 0.5)
		var m := (q as MeshInstance3D).material_override as StandardMaterial3D
		m.albedo_color.a = (1.0 - smoothstep(0.55, 1.0, u)) * (0.4 + 0.6 * pisca)


# ------------------------------------------------- cometa e explosão (Pika)

## COMETA (X da Pika, 06/10/2026): o corpo virou luz — núcleo branco, halo na cor da
## skill e uma trilha de luz que fica no MUNDO (o executor esconde o corpo).
static func _montar_cometa(fx: Node3D, cor: Color, escala: float) -> void:
	fx.add_child(esfera_de_brilho("Nucleo", Color(1, 0.98, 0.9), 0.32 * escala, 0.8))
	fx.add_child(esfera_de_brilho("Halo", cor, 0.85 * escala, 2.2))
	var rastro := CPUParticles3D.new()
	rastro.name = "Rastro"
	rastro.local_coords = false
	rastro.amount = 48
	rastro.lifetime = 0.4
	rastro.gravity = Vector3.ZERO
	rastro.spread = 25.0
	rastro.initial_velocity_min = 0.1
	rastro.initial_velocity_max = 0.6
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.8 * escala
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = AuraDeLentidao.textura_de_cintila()
	quad.material = m
	rastro.mesh = quad
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 1.0])
	rampa.colors = PackedColorArray([Color(1, 0.97, 0.85, 1.0), Color(cor, 0.0)])
	rastro.color_ramp = rampa
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 1.0))
	curva.add_point(Vector2(1.0, 0.15))
	rastro.scale_amount_curve = curva
	fx.add_child(rastro)


static func _animar_cometa(fx: Node3D, p: Dictionary, local: float, u: float) -> void:
	var env := _envelope(u, 0.06, 0.12)
	var pulso := 1.0 + 0.12 * sin(local * 31.0)
	for nome in ["Nucleo", "Halo"]:
		var no := fx.get_node(nome) as Node3D
		no.scale = Vector3.ONE * pulso * maxf(env, 0.05)
		_brilho(no, env)


## EXPLOSÃO (esfera de luz no chão, 06/10/2026): clarão branco, bola na cor e um anel
## que se abre, tudo crescendo rápido e apagando; uma luz de verdade no primeiro terço.
static func _montar_explosao(fx: Node3D, cor: Color, escala: float) -> void:
	fx.add_child(esfera_de_brilho("Nucleo", Color(1, 1, 0.95), 0.6 * escala, 0.7))
	fx.add_child(esfera_de_brilho("Bola", cor, 1.0 * escala, 1.8))
	var anel := MeshInstance3D.new()
	anel.name = "Anel"
	var toro := TorusMesh.new()
	toro.inner_radius = 0.92 * escala
	toro.outer_radius = 1.08 * escala
	toro.rings = 40
	toro.ring_segments = 8
	anel.mesh = toro
	anel.material_override = _material_de_brilho(cor, 1.2)
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(anel)
	if escala < 1.0:
		return            # estouro pequeno (a chuva do C): sem luz, são dezenas ao mesmo tempo
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = cor.lerp(Color.WHITE, 0.4)
	luz.omni_range = 7.0 * escala
	luz.light_energy = 0.0
	fx.add_child(luz)


static func _animar_explosao(fx: Node3D, p: Dictionary, u: float) -> void:
	var e := float(p.escala)
	var abre := 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)
	var apaga := 1.0 - smoothstep(0.35, 1.0, u)
	(fx.get_node("Nucleo") as Node3D).scale = Vector3.ONE * (0.4 + 1.2 * abre)
	(fx.get_node("Bola") as Node3D).scale = Vector3.ONE * (0.3 + 1.7 * abre)
	_brilho(fx.get_node("Nucleo"), apaga * (1.0 - u * 0.5))
	_brilho(fx.get_node("Bola"), apaga)
	var anel := fx.get_node("Anel") as Node3D
	anel.scale = Vector3.ONE * (0.2 + 2.6 * abre)
	_brilho(anel, apaga)
	if fx.has_node("Luz"):
		(fx.get_node("Luz") as OmniLight3D).light_energy = 6.0 * (1.0 - smoothstep(0.0, 0.35, u)) * clampf(e, 0.5, 2.0)


# ------------------------------------------------------------- rachadura
## RACHADURA (X do Estilo de Combate Base, 14/10/2026): fendas do Blender
## (`tools/blender/rachadura_chao.py`) deitadas no chão. Abre em ~12% do bloco, fica, e
## desbota no fim. A cor da skill tinge as lascas; a fenda é escura. Sem o glb, um anel.
const RACHADURA_GLB := "res://assets/models/vento/rachadura.glb"


static func _montar_rachadura(fx: Node3D, cor: Color, escala: float) -> void:
	var cena := load(RACHADURA_GLB) as PackedScene if ResourceLoader.exists(RACHADURA_GLB) else null
	var corpo := Node3D.new()
	corpo.name = "Corpo"
	fx.add_child(corpo)
	if cena == null:
		var toro := TorusMesh.new()
		toro.inner_radius = 0.7 * escala
		toro.outer_radius = 0.76 * escala
		malha(corpo, toro, cor)
		return
	var modelo := cena.instantiate() as Node3D
	modelo.scale = Vector3.ONE * escala
	corpo.add_child(modelo)
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var m := StandardMaterial3D.new()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		var lasca := "lasca" in mi.name.to_lower()
		m.albedo_color = Color(0.36, 0.3, 0.26).lerp(cor, 0.25) if lasca else Color(0.03, 0.025, 0.02)
		(mi as MeshInstance3D).material_override = m
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).position.y = 0.02 if lasca else 0.01   # acima do piso: sem z-fighting


static func _animar_rachadura(fx: Node3D, u: float) -> void:
	var corpo := fx.get_node("Corpo") as Node3D
	var abre := 1.0 - pow(1.0 - clampf(u / 0.12, 0.0, 1.0), 3.0)
	corpo.scale = Vector3(abre, 1.0, abre)
	var alfa := 1.0 - smoothstep(0.65, 1.0, u)
	for mi in corpo.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m != null:
			m.albedo_color.a = alfa


# ------------------------------------------------- estrela de quatro pontas
## ESTRELA (Z da Pika, 07/10/2026, pedido do dono): "uma esfera começa a brilhar
## intensamente na mão do jogador no formato de uma estrela de quatro pontas". Duas
## estrelas de quatro pontas (uma reta, outra a 45° e menor) cintilando em fases
## diferentes, núcleo branco, halo na cor e uma luz que acende com a carga. Cresce com
## `p.carga` (0..1 = tempo segurado / Tempo de carga; sem carga, o andamento do bloco).
static var _tex_estrela: Array[ImageTexture] = []


static func _texturas_de_estrela() -> Array[ImageTexture]:
	if not _tex_estrela.is_empty():
		return _tex_estrela
	for girada: bool in [false, true]:
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var q := Vector2((x + 0.5) / n * 2.0 - 1.0, (y + 0.5) / n * 2.0 - 1.0)
				if girada:
					q = q.rotated(PI * 0.25)
				# Astroide (√|u| + √|v| < 1): quatro pontas finas; e um miolo redondo.
				var d := sqrt(absf(q.x)) + sqrt(absf(q.y))
				var pontas := pow(clampf(1.0 - d, 0.0, 1.0), 0.9)
				var miolo := exp(-q.length() * 7.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(pontas * 1.5 + miolo, 0.0, 1.0)))
		_tex_estrela.append(ImageTexture.create_from_image(img))
	return _tex_estrela


static func _quad_de_estrela(nome: String, tex: Texture2D, cor: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mi.mesh = quad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = tex
	m.albedo_color = cor
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _montar_estrela(fx: Node3D, cor: Color, escala: float) -> void:
	var tex := _texturas_de_estrela()
	fx.add_child(_quad_de_estrela("Pontas", tex[0], Color(1, 0.98, 0.88)))
	fx.add_child(_quad_de_estrela("Pontas45", tex[1], cor))
	fx.add_child(esfera_de_brilho("Nucleo", Color(1, 1, 0.95), 0.07 * escala, 0.8))
	fx.add_child(esfera_de_brilho("Halo", cor, 0.2 * escala, 2.2))
	var luz := OmniLight3D.new()
	luz.name = "Luz"
	luz.light_color = cor.lerp(Color.WHITE, 0.3)
	luz.omni_range = 3.5 * escala
	luz.light_energy = 0.0
	fx.add_child(luz)


static func _animar_estrela(fx: Node3D, p: Dictionary, local: float, u: float) -> void:
	var e := float(p.escala)
	var carga := clampf(float(p.get("carga", u)), 0.0, 1.0)
	var entra := smoothstep(0.0, 0.08, local)
	# O bloco só anda depois do soltar: no fim dele a estrela apaga (o raio já saiu).
	var some := 1.0 - smoothstep(0.55, 1.0, u)
	var vivo := entra * some
	# Carga cheia: cintila forte, para o jogador saber que pode soltar.
	var cheia := 1.0 + 0.3 * smoothstep(0.92, 1.0, carga) * (0.5 + 0.5 * sin(local * 38.0))
	var a := e * (0.5 + 1.3 * carga) * (1.0 + 0.12 * sin(local * 17.0)) * cheia
	var b := e * (0.3 + 0.75 * carga) * (1.0 + 0.18 * sin(local * 23.0 + 1.3)) * cheia
	(fx.get_node("Pontas") as Node3D).scale = Vector3.ONE * maxf(a * vivo, 0.001)
	(fx.get_node("Pontas45") as Node3D).scale = Vector3.ONE * maxf(b * vivo, 0.001)
	(fx.get_node("Nucleo") as Node3D).scale = Vector3.ONE * (0.6 + 0.8 * carga) * maxf(vivo, 0.05)
	(fx.get_node("Halo") as Node3D).scale = Vector3.ONE * (0.5 + 1.0 * carga) * maxf(vivo, 0.05)
	_brilho(fx.get_node("Nucleo"), vivo)
	_brilho(fx.get_node("Halo"), vivo * (0.6 + 0.4 * carga))
	(fx.get_node("Luz") as OmniLight3D).light_energy = (0.6 + 3.4 * carga) * vivo * cheia


## A forma da hitbox (Esfera, Caixa ou Cápsula) com as medidas do bloco.
static func forma_da_hitbox(p: Dictionary) -> Shape3D:
	if p.forma == "Caixa":
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(p.largura, p.altura, p.profundidade)
		return caixa
	if p.forma == "Cápsula":
		var capsula := CapsuleShape3D.new()
		capsula.radius = float(p.raio)
		capsula.height = maxf(float(p.altura), float(p.raio) * 2)
		return capsula
	var esfera := SphereShape3D.new()
	esfera.radius = float(p.raio)
	return esfera


## Som 3D do bloco de áudio, em `pos`. Some sozinho ao terminar.
static func som_3d(pai: Node3D, p: Dictionary, pos: Vector3) -> AudioStreamPlayer3D:
	if SONS_DE_LUZ.has(str(p.som)):
		# O volume do bloco é relativo ao da voz (−8 dB = o volume dela).
		return PikaAudio.play(pai, pos, SONS_DE_LUZ[str(p.som)], float(p.get("tom", 1.0)), float(p.get("volume", -8.0)) + 8.0)
	var som := AudioStreamPlayer3D.new()
	som.stream = AudioFX._pool(SONS.get(p.som, "dash"))
	som.volume_db = float(p.volume)
	som.pitch_scale = float(p.tom)
	pai.add_child(som)
	som.global_position = pos
	som.finished.connect(som.queue_free)
	som.play()
	return som
