class_name PoderVfx
extends RefCounted
## HTCS — "como construir um poder" (13/11/2026; skill em `~/dev/jjj/repos/htcs/SKILL.md`). As 6 camadas simples de um poder, cada uma uma função
## estática que o poder liga no instante certo: CARGA (partículas puxadas para um ponto), FEIXE (textura esticada entre dois pontos, trocando de forma
## rápido), RASTRO (fita que segue uma parte do corpo), IMPACTO (clarão + anel de onda de choque), SOLO (rachadura, fumaça, pedrinhas/blocos) e TREMOR
## (câmera). `golpe()` junta impacto + solo + tremor no MESMO quadro. Visual puro: nada aqui causa dano nem decide mecânica.
## Teto de custo: `MAX_EMISSORES` partículas vivas ao mesmo tempo (rajadas repetidas no mesmo ponto não empilham).

enum Forma { CIRCULO, QUADRADO, TRIANGULO }

const MAX_EMISSORES := 40
const COR_PADRAO := Color(1.0, 0.85, 0.35)

static var _vivos := 0
static var _tex := {}


static func _raiz(de: Node) -> Node:
	return VfxGoroMinePiece._raiz(de)


static func _durar(no: Node, s: float) -> void:
	if no.get_tree() != null:
		VfxGoroMinePiece._durar(no, s)


# ------------------------------------------------------------------ texturas (geradas uma vez)
static func _tex_suave() -> Texture2D:
	if not _tex.has("suave"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tex["suave"] = t
	return _tex["suave"]


## Anel de uma forma (borda de um polígono regular de `lados` lados; 0 = círculo) desenhado numa imagem 128².
static func _tex_anel(forma: Forma) -> Texture2D:
	var chave := "anel%d" % int(forma)
	if _tex.has(chave):
		return _tex[chave]
	var n := 128
	var lados := 4 if forma == Forma.QUADRADO else (3 if forma == Forma.TRIANGULO else 0)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := (Vector2(x, y) + Vector2(0.5, 0.5)) / float(n) * 2.0 - Vector2.ONE
			var d: float
			if lados == 0:
				d = p.length()
			else:
				# distância "poligonal": projeção no apótema mais próximo (quadrado girado 45° fica como losango; triângulo com a ponta para cima)
				var ang := atan2(p.y, p.x) + (PI / 2.0 if lados == 3 else PI / 4.0)
				var setor := TAU / float(lados)
				var a := fposmod(ang + setor * 0.5, setor) - setor * 0.5
				d = p.length() * cos(a) / cos(setor * 0.5)
			var borda := 1.0 - clampf(absf(d - 0.82) / 0.13, 0.0, 1.0)
			var alfa := borda * borda * (3.0 - 2.0 * borda)
			img.set_pixel(x, y, Color(1, 1, 1, alfa))
	_tex[chave] = ImageTexture.create_from_image(img)
	return _tex[chave]


static func _mat_somado(tex: Texture2D, cor: Color, billboard := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.albedo_color = cor
	m.disable_receive_shadows = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m


# ------------------------------------------------------------------ 1. CARGA
## Partículas nascem numa casca de raio `raio` em volta de `ponto` (mundo) e são puxadas para ele durante `duracao`. Se `corpo` for dado, o ponto é
## relativo a ele (segue o corpo): `Vector3.ZERO` = o corpo inteiro (centro), ou uma parte (`Vector3(0.4, 1.2, -0.3)` = a mão). Devolve o emissor
## (queue_free ao fim) para o poder poder cancelar ao soltar.
static func carga(de: Node, corpo: Node3D, ponto_local: Vector3, cor: Color, duracao: float, raio := 1.2, quantidade := 24) -> Node3D:
	var raiz := _raiz(de)
	if raiz == null or _vivos >= MAX_EMISSORES:
		return null
	var p := CPUParticles3D.new()
	p.amount = clampi(quantidade, 4, 64)
	p.lifetime = maxf(duracao * 0.45, 0.2)
	p.explosiveness = 0.0
	p.one_shot = false
	p.local_coords = corpo != null
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = raio
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.radial_accel_min = -raio / (p.lifetime * p.lifetime) * 2.0        # fecha a casca no ponto em ~uma vida
	p.radial_accel_max = p.radial_accel_min * 1.2
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.5))
	c.add_point(Vector2(0.7, 1.0))
	c.add_point(Vector2(1.0, 0.1))
	p.scale_amount_curve = c
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	rampa.colors = PackedColorArray([Color(cor, 0.0), Color(cor.lerp(Color.WHITE, 0.4), 1.0), Color(1, 1, 1, 0.0)])
	p.color_ramp = rampa
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE * clampf(raio * 0.18, 0.08, 0.35)
	malha.material = _mat_somado(_tex_suave(), Color.WHITE, true)
	(malha.material as StandardMaterial3D).vertex_color_use_as_albedo = true
	(malha.material as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.mesh = malha
	if corpo != null and is_instance_valid(corpo):
		corpo.add_child(p)
		p.position = ponto_local
	else:
		raiz.add_child(p)
		p.global_position = ponto_local
	p.emitting = true
	_vivos += 1
	var vida := duracao + p.lifetime
	de.get_tree().create_timer(vida, false).timeout.connect(func() -> void:
		_vivos -= 1
		if is_instance_valid(p): p.queue_free())
	return p


## Fecha a carga antes do fim (soltou o botão).
static func soltar_carga(emissor: Node3D) -> void:
	if emissor != null and is_instance_valid(emissor):
		(emissor as CPUParticles3D).emitting = false


# ------------------------------------------------------------------ 2. FEIXE
## Textura esticada entre `a` e `b` (mundo): núcleo claro + halo, e a forma TROCA a cada ~40 ms (largura e deslocamento sorteados), por `duracao`.
static func feixe(de: Node, a: Vector3, b: Vector3, cor: Color, largura := 0.5, duracao := 0.35) -> Node3D:
	var raiz := _raiz(de)
	if raiz == null or a.distance_to(b) < 0.05:
		return null
	var no := Node3D.new()
	raiz.add_child(no)
	var meio := (a + b) * 0.5
	var dir := (b - a).normalized()
	var base := _base_com_z(dir)
	no.global_transform = Transform3D(base, meio)
	var comp := a.distance_to(b)
	var camadas: Array[MeshInstance3D] = []
	for k in 2:
		var m := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.0, comp)
		m.mesh = q
		m.material_override = _mat_somado(_tex_suave(), (Color(2.2, 2.2, 2.2, 1.0) if k == 0 else Color(cor.r * 2.0, cor.g * 2.0, cor.b * 2.0, 0.7)))
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(m)
		# o quad fica no plano XY local e o comprimento corre em Y → gira para correr em Z (a base já aponta Z para `dir`)
		m.rotation = Vector3(PI / 2.0, 0, k * PI / 2.0)       # dois planos cruzados: lê de qualquer ângulo
		camadas.append(m)
	var t := {"t": 0.0, "prox": 0.0}
	var tween := no.create_tween().set_loops()
	tween.tween_callback(func() -> void:
		var lw := largura * randf_range(0.55, 1.25)
		for i in camadas.size():
			var esc := lw * (0.5 if i == 0 else 2.2)
			camadas[i].scale = Vector3(esc, 1.0, esc)
			camadas[i].position = Vector3(randf_range(-0.04, 0.04), randf_range(-0.04, 0.04), 0.0) * largura)
	tween.tween_interval(0.04)
	# some no fim da duração
	var fade := no.create_tween()
	fade.tween_interval(maxf(duracao - 0.1, 0.01))
	fade.tween_property(no, "scale", Vector3(0.05, 1.0, 0.05), 0.1)
	_durar(no, duracao)
	return no


static func _base_com_z(dir: Vector3) -> Basis:
	var ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := ref.cross(dir).normalized()
	var y := dir.cross(x).normalized()
	return Basis(x, y, dir)


# ------------------------------------------------------------------ 3. RASTRO
## Fita que segue `parte` (o braço, o pé, a lâmina: um Node3D) durante `duracao`; desbota por trás (~0,3 s). `Node` devolvido some sozinho.
static func rastro(de: Node, parte: Node3D, cor: Color, largura := 0.35, duracao := 0.4) -> Node3D:
	var raiz := _raiz(de)
	if raiz == null or parte == null or not is_instance_valid(parte):
		return null
	var r: Node3D = RastroDePoder.new()
	r.set("parte", parte)
	r.set("cor", cor)
	r.set("largura", largura)
	r.set("duracao", duracao)
	raiz.add_child(r)
	return r


# ------------------------------------------------------------------ 4. IMPACTO
## Clarão branco de ~0,08 s + anel de onda de choque na forma pedida (cresce de 15% a 100% de `raio` e some), o anel começa ~0,03 s depois do clarão.
## `normal` = para onde o anel "olha" (chão: UP; parede: a normal dela).
static func impacto(de: Node, onde: Vector3, cor: Color, raio := 2.0, forma := Forma.CIRCULO, normal := Vector3.UP) -> void:
	var raiz := _raiz(de)
	if raiz == null:
		return
	VfxGoroMinePiece.clarao(de, onde, raio * 0.55, 0.09, cor.lerp(Color.WHITE, 0.35))
	# anel (depois do clarão)
	var anel := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mat := _mat_somado(_tex_anel(forma), Color(cor.lerp(Color.WHITE, 0.3), 0.0))
	q.material = mat
	anel.mesh = q
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(anel)
	anel.global_position = onde + normal * 0.05
	var n := normal.normalized()
	var ref := Vector3.RIGHT if absf(n.dot(Vector3.RIGHT)) < 0.99 else Vector3.FORWARD
	var x := ref.cross(n).normalized()
	var y := n.cross(x).normalized()
	anel.global_basis = Basis(x, y, n)                  # o quad aponta para +Z local = a normal: deita no plano do chão/parede
	anel.scale = Vector3.ONE * raio * 0.3
	var tw := anel.create_tween()
	tw.tween_interval(0.03)
	tw.set_parallel(true)
	tw.tween_property(mat, "albedo_color:a", 0.95, 0.04)
	tw.tween_property(anel, "scale", Vector3.ONE * raio * 2.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(mat, "albedo_color:a", 0.0, 0.2)
	_durar(anel, 0.7)


# ------------------------------------------------------------------ 5. SOLO
## Rachadura no chão + fumaça + pedrinhas. `blocos`: cor do bloco destruído (o que sai voando e some); Color(0,0,0,0) = pedrinhas cinza.
static func solo(de: Node, onde: Vector3, raio := 2.0, cor_do_chao := Color(0, 0, 0, 0)) -> void:
	var raiz := _raiz(de)
	if raiz == null:
		return
	var espaco: PhysicsDirectSpaceState3D = de.get_world_3d().direct_space_state if de is Node3D else null
	var chao := onde
	if espaco != null:
		var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(onde + Vector3.UP * 1.5, onde + Vector3.DOWN * 4.0, 1))
		if not hit.is_empty():
			chao = hit.position
	# rachadura: estrela de linhas finas deitada no chão (textura gerada), escurece e some
	var rach := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * raio * 2.2
	q.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _tex_rachadura()
	mat.albedo_color = Color(0.05, 0.04, 0.04, 0.9)
	q.material = mat
	rach.mesh = q
	rach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(rach)
	rach.global_position = chao + Vector3.UP * 0.04
	rach.rotation.y = randf() * TAU
	rach.create_tween().tween_property(mat, "albedo_color:a", 0.0, 1.2).set_delay(2.0)
	_durar(rach, 3.4)
	if _vivos >= MAX_EMISSORES:
		return
	# fumaça
	_emissor_de_poeira(de, chao, raio, Color(0.55, 0.52, 0.48, 0.55), 10, 0.9, raio * 0.9, Vector3(0, 0.6, 0), true)
	# pedrinhas / blocos
	var cor := cor_do_chao if cor_do_chao.a > 0.0 else Color(0.5, 0.48, 0.45)
	_emissor_de_poeira(de, chao + Vector3.UP * 0.2, raio * 0.4, cor, clampi(int(raio * 5.0), 6, 22), 1.1, raio * 2.2, Vector3(0, -14.0, 0), false)


static func _emissor_de_poeira(de: Node, onde: Vector3, extensao: float, cor: Color, qtd: int, vida: float, vel: float, grav: Vector3, fumaca: bool) -> void:
	var raiz := _raiz(de)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = qtd
	p.lifetime = vida
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(extensao * 0.25, 0.1)
	p.direction = Vector3.UP
	p.spread = 70.0 if not fumaca else 180.0
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = grav
	p.local_coords = false
	var malha: Mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	if fumaca:
		var qm := QuadMesh.new()
		qm.size = Vector2.ONE * clampf(extensao * 0.7, 0.4, 2.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _tex_suave()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.material = mat
		malha = qm
		var c := Curve.new()
		c.add_point(Vector2(0, 0.4))
		c.add_point(Vector2(1, 1.3))
		p.scale_amount_curve = c
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([cor, Color(cor, 0.0)])
		p.color_ramp = g
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * clampf(extensao * 0.08, 0.06, 0.22)
		mat.albedo_color = cor
		bm.material = mat
		malha = bm
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
	p.mesh = malha
	raiz.add_child(p)
	p.global_position = onde
	p.emitting = true
	_vivos += 1
	de.get_tree().create_timer(vida + 0.3, false).timeout.connect(func() -> void:
		_vivos -= 1
		if is_instance_valid(p): p.queue_free())


static func _tex_rachadura() -> Texture2D:
	if _tex.has("rachadura"):
		return _tex["rachadura"]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var centro := Vector2(n / 2.0, n / 2.0)
	for r in 9:
		var ang := TAU * float(r) / 9.0 + rng.randf_range(-0.25, 0.25)
		var pos := centro
		var largura := 2.2
		var passos := rng.randi_range(14, 24)
		for s in passos:
			ang += rng.randf_range(-0.35, 0.35)
			pos += Vector2(cos(ang), sin(ang)) * 2.4
			for dy in range(-int(largura), int(largura) + 1):
				for dx in range(-int(largura), int(largura) + 1):
					var q := pos + Vector2(dx, dy)
					if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n and Vector2(dx, dy).length() <= largura:
						img.set_pixelv(Vector2i(q), Color(1, 1, 1, 1.0 - float(s) / float(passos) * 0.6))
			largura = maxf(largura - 0.07, 0.6)
	_tex["rachadura"] = ImageTexture.create_from_image(img)
	return _tex["rachadura"]


# ------------------------------------------------------------------ 6. TREMOR
## Tremida de câmera proporcional ao peso (0..1). Só o jogador local sente (`add_camera_shake` ignora quem não tem autoridade).
static func tremor(de: Node, forca: float) -> void:
	if de == null or not de.is_inside_tree():
		return
	var j := de.get_tree().get_first_node_in_group("player")
	if j != null and j.has_method("add_camera_shake"):
		j.add_camera_shake(clampf(forca, 0.0, 1.0))


# ------------------------------------------------------------------ composto
## Contato de um golpe: impacto + solo + tremor no MESMO quadro. `peso` 0..1 (0,3 = leve, 1,0 = devastador).
static func golpe(de: Node, onde: Vector3, cor: Color, raio := 2.0, peso := 0.5, forma := Forma.CIRCULO, tocar_solo := true) -> void:
	impacto(de, onde, cor, raio, forma)
	if tocar_solo and peso >= 0.35:
		solo(de, onde, raio * 0.8)
	tremor(de, peso * 0.6)


# ------------------------------------------------------------------ ASSINATURA: tigre de partículas (Zushi Zushi C, Raging Tiger)
## Uma SILHUETA de tigre feita só de partículas (pontos amostrados num tigre desenhado à mão: corpo, cabeça, orelhas, patas em passada, cauda) com listras escuras, que
## corre para a frente de `onde` na `direcao` por `alcance` m em `duracao` s e se desfaz. É a camada "assinatura" do HTCS: o golpe ganha uma forma legível.
static func tigre(de: Node, onde: Vector3, direcao: Vector3, cor: Color, escala := 1.0, alcance := 8.0, duracao := 0.9, perfil_para := Vector3.ZERO) -> Node3D:
	var raiz := _raiz(de)
	if raiz == null or _vivos >= MAX_EMISSORES:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var pts := PackedVector3Array()
	var cores := PackedColorArray()
	var escuro := Color(0.06, 0.02, 0.12, 1.0)
	var claro := Color(cor.r * 1.5, cor.g * 1.5, cor.b * 1.5, 1.0)
	# espaço do tigre: x = para a frente (m), y = para cima (m); depois vira (z = −x, y) com espessura lateral pequena
	var amostras: Array = [
		["corpo", 150], ["cabeca", 50], ["orelha", 12], ["pata_d1", 22], ["pata_d2", 22], ["pata_t1", 22], ["pata_t2", 22], ["cauda", 28], ["focinho", 14]]
	for g in amostras:
		for i in int(g[1]):
			var p := Vector2.ZERO
			var listra := false
			match g[0]:
				"corpo":
					var a := rng.randf() * TAU
					var r := sqrt(rng.randf())
					p = Vector2(0.0 + cos(a) * r * 0.62, 0.62 + sin(a) * r * 0.24)
					listra = fmod(absf(p.x + 0.7) * 7.0, 1.0) < 0.38
				"cabeca":
					var a2 := rng.randf() * TAU
					var r2 := sqrt(rng.randf())
					p = Vector2(0.78 + cos(a2) * r2 * 0.2, 0.78 + sin(a2) * r2 * 0.19)
					listra = fmod(absf(p.y) * 14.0, 1.0) < 0.3
				"focinho":
					p = Vector2(rng.randf_range(0.93, 1.06), rng.randf_range(0.66, 0.76))
				"orelha":
					var lado := -1.0 if i % 2 == 0 else 1.0
					p = Vector2(0.72 + (0.0 if lado < 0.0 else 0.1) + rng.randf() * 0.05, rng.randf_range(0.95, 1.08))
				"pata_d1": p = Vector2(0.45 + rng.randf() * 0.1 + (rng.randf() * 0.25), 0.5 - rng.randf() * 0.5)
				"pata_d2": p = Vector2(0.30 - rng.randf() * 0.25 + (rng.randf() * 0.1), 0.5 - rng.randf() * 0.5)
				"pata_t1": p = Vector2(-0.4 - rng.randf() * 0.25, 0.5 - rng.randf() * 0.5)
				"pata_t2": p = Vector2(-0.55 + rng.randf() * 0.2, 0.5 - rng.randf() * 0.5)
				"cauda":
					var t := rng.randf()
					p = Vector2(-0.62 - t * 0.55, 0.72 + sin(t * PI) * 0.35 + t * 0.1)
			pts.append(Vector3(rng.randf_range(-0.12, 0.12), p.y * escala * 1.4, -p.x * escala * 1.4))
			cores.append(escuro if listra else claro)
	var p3 := CPUParticles3D.new()
	p3.one_shot = true
	p3.explosiveness = 1.0
	p3.amount = pts.size()
	p3.lifetime = duracao
	p3.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p3.emission_points = pts
	p3.emission_colors = cores
	p3.gravity = Vector3.ZERO
	p3.initial_velocity_min = 0.0
	p3.initial_velocity_max = 0.0
	p3.local_coords = true
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.7))
	curva.add_point(Vector2(0.6, 1.0))
	curva.add_point(Vector2(1.0, 0.1))
	p3.scale_amount_curve = curva
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE * 0.17 * escala
	var mat := _mat_somado(_tex_suave(), Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	malha.material = mat
	p3.mesh = malha
	var no := Node3D.new()
	raiz.add_child(no)
	var dir := direcao
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	no.global_position = onde
	# `perfil_para` (ex.: o eixo X da câmera): para onde o tigre OLHA na tela. Visto por trás, um perfil que corre para longe fica "de borda" (uma coluna de pontos): o perfil
	# fica virado para a câmera (cabeça para a direita) e só o deslocamento segue `direcao`.
	var olhar := perfil_para
	olhar.y = 0.0
	olhar = olhar.normalized() if olhar.length() > 0.01 else dir
	no.look_at(onde + olhar, Vector3.UP)
	no.add_child(p3)
	p3.emitting = true
	var tw := no.create_tween()
	tw.tween_property(no, "global_position", onde + dir * alcance, duracao * 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_vivos += 1
	de.get_tree().create_timer(duracao + 0.3, false).timeout.connect(func() -> void:
		_vivos -= 1
		if is_instance_valid(no): no.queue_free())
	return no
