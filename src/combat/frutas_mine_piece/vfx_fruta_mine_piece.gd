class_name VfxFrutaMinePiece
extends RefCounted
## Partículas (tiras de flipbook importadas do mod) e sons por pasta de fruta, para as
## frutas do controlador genérico. Sem o asset importado, a chamada não faz nada.
static var _materiais: Dictionary = {}


static func _material(caminho: String, quadros: int, aditivo: bool) -> StandardMaterial3D:
	if _materiais.has(caminho):
		return _materiais[caminho]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = quadros
	mat.particles_anim_v_frames = 1
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = true
	if ResourceLoader.exists(caminho):
		mat.albedo_texture = load(caminho)
	mat.albedo_color = _acabamento(caminho)
	_materiais[caminho] = mat
	return mat


## `server.sendParticles(tipo, x, y, z, quantidade, dx, dy, dz, velocidade)`: `espalhar` é o
## delta do mod em metros, `velocidade` em m/s. `maximo` limita o custo de uma rajada.
static func particulas(de: Node, caminho: String, quadros: int, onde: Vector3, quantidade: int,
		espalhar: Vector3, velocidade: float, vida := 0.6, tamanho := 0.5, maximo := 32, aditivo := false) -> void:
	var raiz := VfxGoroMinePiece._raiz(de)
	if raiz == null or quantidade <= 0 or not ResourceLoader.exists(caminho):
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clampi(quantidade, 1, maximo)
	p.lifetime = vida
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = espalhar.max(Vector3.ONE * 0.01)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = velocidade * 0.3
	p.initial_velocity_max = velocidade
	p.gravity = Vector3.ZERO
	p.damping_min = velocidade * 1.5
	p.damping_max = velocidade * 2.0
	p.anim_speed_min = 1.0
	p.anim_speed_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.95))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	p.scale_amount_curve = _curva_de_tamanho()
	p.angle_min = -180.0
	p.angle_max = 180.0
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE * tamanho * 1.3        # a curva de tamanho murcha a partícula: 30% a mais compensa e dá corpo à fumaça/luz
	malha.material = _material(caminho, quadros, aditivo)
	p.mesh = malha
	raiz.add_child(p)
	p.global_position = onde
	p.emitting = true
	VfxGoroMinePiece._durar(p, vida + 0.2)


## BRAÇO ESTICADO (Mochi Mochi, 15/11/2026): um cilindro cheio (não aditivo) que sai de `de`, estica até `ate` em `ida` s, segura um instante e RECOLHE, com um punho
## (esfera) na ponta. Lê como o braço de massa do anime. Só desenha; o dano é do golpe. `largura` em m.
static func braco_esticado(de_no: Node, de: Vector3, ate: Vector3, largura: float, cor: Color, ida := 0.12, fica := 0.1, volta := 0.16, punho_cubo := false) -> void:
	var raiz := VfxGoroMinePiece._raiz(de_no)
	var eixo := ate - de
	if raiz == null or eixo.length() < 0.3:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.8
	mat.emission_enabled = true
	mat.emission = cor
	mat.emission_energy_multiplier = 0.35
	var cil := CylinderMesh.new()
	cil.top_radius = 0.5
	cil.bottom_radius = 0.5
	cil.height = 1.0
	cil.radial_segments = 14
	var braco := MeshInstance3D.new()
	braco.mesh = cil
	braco.material_override = mat
	braco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var punho := MeshInstance3D.new()
	if punho_cubo:           # Kaku Mochi: o mochi é comprimido em formato QUADRADO
		var cubo := BoxMesh.new()
		cubo.size = Vector3.ONE * 0.9
		punho.mesh = cubo
	else:
		var esfera := SphereMesh.new()
		esfera.radius = 0.5
		esfera.height = 1.0
		punho.mesh = esfera
	punho.material_override = mat
	punho.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(braco)
	raiz.add_child(punho)
	var dir := eixo.normalized()
	var ref := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(dir).normalized()
	var z := x.cross(dir).normalized()
	var base := Basis(x, dir, z)
	var comprimento := eixo.length()
	var aplicar := func(frac: float) -> void:
		var l := maxf(comprimento * frac, 0.01)
		braco.global_transform = Transform3D(base.scaled_local(Vector3(largura, l, largura)), de + dir * (l * 0.5))
		punho.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * largura * 2.1), de + dir * l)
	aplicar.call(0.01)
	var tw := braco.create_tween()
	tw.tween_method(aplicar, 0.01, 1.0, ida).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(fica)
	tw.tween_method(aplicar, 1.0, 0.01, volta).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		braco.queue_free()
		punho.queue_free())


## Feixe de `de` a `ate`: cilindro aditivo esticado na reta, afinando para a ponta, que estoura e some em `duracao`. Serve para golpes
## cujo alcance é uma LINHA no mod e sem desenho próprio (o Kuma Punch). Acabamento acima do mod (15/11/2026): só desenha, não fere.
static func feixe(de_no: Node, de: Vector3, ate: Vector3, largura: float, cor: Color, duracao := 0.35) -> void:
	var raiz := VfxGoroMinePiece._raiz(de_no)
	var eixo := ate - de
	if raiz == null or eixo.length() < 0.2:
		return
	var cil := CylinderMesh.new()
	cil.top_radius = 0.35
	cil.bottom_radius = 1.0
	cil.height = 1.0
	cil.radial_segments = 14
	cil.rings = 1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(cor.r * 1.7, cor.g * 1.7, cor.b * 1.7, 0.75)
	var no := MeshInstance3D.new()
	no.mesh = cil
	no.material_override = mat
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(no)
	var dir := eixo.normalized()
	var ref := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(dir).normalized()
	var z := x.cross(dir).normalized()
	var comprimento := eixo.length()
	# O cilindro cresce em Y; a base (raio maior) fica em `de` e a ponta fina em `ate`.
	var base := Basis(x, dir, z)
	no.global_transform = Transform3D(base.scaled_local(Vector3(largura * 0.4, comprimento, largura * 0.4)), de + eixo * 0.5)
	var tw := no.create_tween().set_parallel(true)
	tw.tween_property(no, "scale", Vector3(largura * 1.2, comprimento, largura * 1.2) / Vector3(1.0, 1.0, 1.0), duracao).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao).set_ease(Tween.EASE_IN)
	VfxGoroMinePiece._durar(no, duracao + 0.05)


## Rastro de partículas de `de` a `ate`: `quantidade` nuvens espalhadas na reta (a viagem de um golpe que some e reaparece, como o
## White Vine). Acabamento acima do mod (15/11/2026): sem isto o corpo some e nada mostra para onde foi.
static func rastro(de_no: Node, caminho: String, quadros: int, de: Vector3, ate: Vector3, quantidade := 14, tamanho := 0.9) -> void:
	for i in quantidade:
		var f := float(i) / float(maxi(quantidade - 1, 1))
		particulas(de_no, caminho, quadros, de.lerp(ate, f), 2, Vector3.ONE * 0.35, 0.8, 0.9, tamanho, 4)


## Onda de choque: anel achatado e aditivo que varre o chão de `onde` até `raio` m e some. Acabamento acima do mod
## (15/11/2026) para os clímax das técnicas: só desenha, não fere nem empurra. O anel é um toro fino, não um quad, para
## ler como volume de qualquer ângulo; a cor ganha brilho acima de 1 (bloom). Custa um nó e um tween.
static func onda_de_choque(de: Node, onde: Vector3, raio: float, cor: Color, duracao := 0.45) -> void:
	var raiz := VfxGoroMinePiece._raiz(de)
	if raiz == null or raio <= 0.1:
		return
	var toro := TorusMesh.new()
	toro.inner_radius = 0.9
	toro.outer_radius = 1.0
	toro.rings = 32
	toro.ring_segments = 6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(cor.r * 1.8, cor.g * 1.8, cor.b * 1.8, 0.85)
	var no := MeshInstance3D.new()
	no.mesh = toro
	no.material_override = mat
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(no)
	no.global_position = onde
	no.scale = Vector3(0.25, 0.12, 0.25)
	var tw := no.create_tween().set_parallel(true)
	tw.tween_property(no, "scale", Vector3(raio, maxf(raio * 0.06, 0.1), raio), duracao).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao).set_ease(Tween.EASE_IN)
	VfxGoroMinePiece._durar(no, duracao + 0.05)


static var _curva: Curve


## ACABAMENTO ACIMA DO MOD (decisão do dono, 15/11/2026): forma, tempo e quantidade seguem o mod; a COR sai do
## modulador do material. Material unshaded brilha pelo albedo > 1 (ver a nota em `FxUtil`), então o multiplicador
## abaixo clareia a textura sem tocar no asset importado. A fumaça do Moku é cinza-parda (126,120,114) na textura do
## mod; a fruta é branca, e na tela lia como poeira. O gelo ganha frieza e a luz ganha brilho de bloom.
static func _acabamento(caminho: String) -> Color:
	if caminho.ends_with("particle_big_smoke.png"):
		return Color(1.95, 1.95, 2.1, 1.0)
	if caminho.ends_with("particle_ice.png"):
		return Color(1.15, 1.45, 1.8, 1.0)
	if caminho.contains("particle_light"):
		return Color(1.9, 1.8, 1.25, 1.0)
	return Color.WHITE


## Estoura e murcha: nasce a 55%, chega a 100% em um quarto da vida e termina a 35% (antes: tamanho fixo e a partícula só desbotava, parada e dura).
static func _curva_de_tamanho() -> Curve:
	if _curva == null:
		_curva = Curve.new()
		_curva.add_point(Vector2(0.0, 0.55))
		_curva.add_point(Vector2(0.25, 1.0))
		_curva.add_point(Vector2(1.0, 0.35))
	return _curva


static func som(de: Node, caminho: String, onde: Vector3, volume := 1.0, tom := 1.0) -> void:
	var raiz := VfxGoroMinePiece._raiz(de)
	if raiz == null or not ResourceLoader.exists(caminho):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(caminho)
	# Volume do Minecraft (0–n, linear; acima de 1 só aumenta o alcance) em dB.
	p.volume_db = linear_to_db(clampf(volume, 0.05, 1.0)) - 4.0
	p.max_distance = 16.0 * maxf(volume, 1.0) * MundoMinePiece.METROS_POR_BLOCO * 4.0
	p.pitch_scale = clampf(tom, 0.5, 2.0)
	raiz.add_child(p)
	p.global_position = onde
	p.finished.connect(p.queue_free)
	p.play()


static var _placas: Array[Vector4] = []


## A marca que um procedimento de blocos (BlockToIce…) deixaria: uma placa no chão de
## raio `raio` m, sem alterar o mapa. Uma placa por lugar enquanto ela dura.
static func placa(de: Node3D, onde: Vector3, raio: float, cor: Color, duracao := 10.0) -> void:
	var raiz := VfxGoroMinePiece._raiz(de)
	if raiz == null or raio <= 0.05:
		return
	var agora := Time.get_ticks_msec() / 1000.0
	for i in range(_placas.size() - 1, -1, -1):
		var p4 := _placas[i]
		if agora - p4.w > duracao:
			_placas.remove_at(i)
		elif Vector3(p4.x, p4.y, p4.z).distance_to(onde) < raio * 0.6:
			return
	var hit: Dictionary = de.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		onde + Vector3.UP * 2.0, onde + Vector3.DOWN * (raio + 4.0), MundoMinePiece.MASCARA_MUNDO))
	if hit.is_empty():
		return
	_placas.append(Vector4(onde.x, onde.y, onde.z, agora))
	var grad := Gradient.new()
	grad.set_color(0, cor)
	grad.set_color(1, Color(cor, 0.0))
	grad.set_offset(0, 0.55)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	# Gelo compactado (packed_ice): brilho moderado; especular alto refletia o sol como um clarão.
	mat.metallic_specular = 0.35
	mat.roughness = 0.35
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE * raio * 2.0
	malha.orientation = PlaneMesh.FACE_Y
	malha.material = mat
	var no := MeshInstance3D.new()
	no.mesh = malha
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(no)
	no.global_position = hit.position + hit.normal * 0.03
	no.create_tween().tween_property(mat, "albedo_color:a", 0.0, 1.5).set_delay(maxf(duracao - 1.5, 0.0))
	VfxGoroMinePiece._durar(no, duracao)


## RenderType.entityTranslucent (o render de quase toda entidade do mod): textura com alfa
## de verdade, sem descarte de face e sem brilho especular (o Minecraft não tem; com ele a
## textura branca refletia o céu e saía azul). Aplicar no modelo importado da entidade.
static func render_do_mod(modelo: Node) -> void:
	if modelo == null:
		return
	for malha in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := malha as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var base := mi.get_active_material(i) as BaseMaterial3D
			if base == null:
				continue
			var m := base.duplicate() as BaseMaterial3D
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.metallic = 0.0
			m.metallic_specular = 0.0
			m.roughness = 1.0
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.set_surface_override_material(i, m)


## RenderType.eyes (o `GeoRenderLayer` de brilho do mod, ex. `PadLayer` com tex_white): sem luz nem sombra. A textura do mod
## (`tex_white.png`) é quase preta (RGB ≤ 51), então o original soma ~20% de branco: um fantasma que some à luz do dia. ADAPTAÇÃO
## declarada: aqui a textura é trocada por uma cor chapada `cor` (branco translúcido), para a entidade LER no jogo; a forma, o
## tamanho e a trajetória continuam os do mod. Aplicar no modelo importado de entidade que o mod desenha só pela camada luminosa.
static func brilho_do_mod(modelo: Node, cor := Color(1, 1, 1, 0.6)) -> void:
	if modelo == null:
		return
	for malha in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := malha as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = cor
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			# Com a câmera colada/dentro de um modelo grande (a pata do Ursus Shock, 20 blocos) o branco cobria a tela inteira: a luz some perto da câmera.
			m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
			m.distance_fade_min_distance = 1.5
			m.distance_fade_max_distance = 6.0
			mi.set_surface_override_material(i, m)
