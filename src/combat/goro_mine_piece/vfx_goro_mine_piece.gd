class_name VfxGoroMinePiece
extends RefCounted
# ============================================================================
#  O QUE A GORO GORO (MINE PIECE) MOSTRA E TOCA — sem decidir dano nenhum.
#
#  Cada função é o equivalente de uma chamada de efeito do mod:
#    • `faiscas`  → sendParticles(PARTICLE_THUNDER_LIGHT_BLUE / faíscas vanilla)
#    • `fumaca`   → particle_big_smoke
#    • `clarao`   → `particle minecraft:flash`
#    • `relampago`→ o caminho em zigue-zague do LightningStrike2 e o feixe do El Thor
#    • `raio_do_ceu` → a entidade LightningBolt do Minecraft (Sango e Mamaragan)
#    • `marca`    → BlockDestroyAllDirection, por DECISÃO DO DONO (18/10/2026) só como
#      marca visual: o mapa não muda. GATILHO: o dono pedir terreno destrutível.
#  Texturas e sons vêm de `tools/mine_piece/importar_goro.py` (arte do mod, fora do git):
#  sem eles a fruta funciona igual, só sem o efeito correspondente.
# ============================================================================

const PASTA := "res://assets/mine_piece/goro/"
const COR_RAIO := Color(0.55, 0.85, 1.0)
const COR_NUCLEO := Color(0.92, 0.97, 1.0)
static var _materiais: Dictionary = {}


static func _raiz(de: Node) -> Node:
	var arvore := de.get_tree() if de != null and de.is_inside_tree() else null
	if arvore == null:
		return null
	return arvore.current_scene if arvore.current_scene != null else arvore.root


static func _durar(no: Node, segundos: float) -> void:
	no.get_tree().create_timer(segundos, false).timeout.connect(func():
		if is_instance_valid(no): no.queue_free())


static func _material_de_particula(nome: String, quadros: int) -> StandardMaterial3D:
	if _materiais.has(nome):
		return _materiais[nome]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if nome.contains("thunder") else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.particles_anim_h_frames = quadros
	mat.particles_anim_v_frames = 1
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_use_as_albedo = true
	if nome.contains("smoke"):
		mat.albedo_color = Color(0.8, 0.8, 0.82)
	var caminho := PASTA + nome + ".png"
	if ResourceLoader.exists(caminho):
		mat.albedo_texture = load(caminho)
	_materiais[nome] = mat
	return mat


## `quantidade` partículas num cubo de meio-lado `espalhar` m, saindo a `velocidade` m/s.
static func _particulas(de: Node, onde: Vector3, quantidade: int, espalhar: float,
		velocidade: float, nome: String, quadros: int, vida: float, tamanho: float, maximo: int) -> void:
	var raiz := _raiz(de)
	if raiz == null or quantidade <= 0:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = mini(quantidade, maximo)
	p.lifetime = vida
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3.ONE * maxf(espalhar, 0.01)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = velocidade * 0.3
	p.initial_velocity_max = velocidade
	p.gravity = Vector3.ZERO
	p.damping_min = velocidade * 1.5
	p.damping_max = velocidade * 2.0
	p.anim_speed_min = 1.0
	p.anim_speed_max = 1.0
	# Somem ao fim da vida, como as partículas do Minecraft (sem isso a fumaça acumulada
	# virava uma parede de quadrados na frente da câmera — captura de 18/10/2026).
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = fade
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE * tamanho
	malha.material = _material_de_particula(nome, quadros)
	p.mesh = malha
	raiz.add_child(p)
	p.global_position = onde
	p.emitting = true
	_durar(p, vida + 0.2)


static func faiscas(de: Node, onde: Vector3, quantidade: int, espalhar: float, velocidade := 2.0) -> void:
	_particulas(de, onde, quantidade, espalhar, velocidade, "particle_thunder_light_blue", 22, 0.55, 0.7, 48)


static func fumaca(de: Node, onde: Vector3, quantidade: int, espalhar: float, velocidade := 1.0) -> void:
	_particulas(de, onde, quantidade, espalhar, velocidade, "particle_big_smoke", 12, 0.6, 0.8, 6)


## O feixe de partículas do ParticleGeneratorProcedure: faíscas ao longo de uma reta.
static func faiscas_na_linha(de: Node, de_p: Vector3, ate: Vector3, quantidade: int, raio: float) -> void:
	var raiz := _raiz(de)
	if raiz == null or quantidade <= 0:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = mini(quantidade, 64)
	p.lifetime = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	var pontos := PackedVector3Array()
	for i in p.amount:
		var t := randf()
		pontos.append(de_p.lerp(ate, t) - de_p + Vector3(randf_range(-raio, raio), randf_range(-raio, raio), randf_range(-raio, raio)))
	p.emission_points = pontos
	p.spread = 180.0
	p.initial_velocity_max = 1.0
	p.gravity = Vector3.ZERO
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE * maxf(raio, 0.5)
	malha.material = _material_de_particula("particle_thunder_light_blue", 22)
	p.mesh = malha
	raiz.add_child(p)
	p.global_position = de_p
	p.emitting = true
	_durar(p, 0.5)


static func clarao(de: Node, onde: Vector3, raio: float, duracao := 0.15, cor := Color(0.6, 0.85, 1.0)) -> void:
	var raiz := _raiz(de)
	if raiz == null:
		return
	# Sprite somado, sem OmniLight: luz de alcance grande saía como um retângulo
	# serrilhado no chão (iluminação em clusters; captura de 18/10/2026).
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE * maxf(raio * 2.0, 0.5)
	var chave := "clarao_%s" % cor.to_html(false)
	if not _materiais.has(chave):
		# núcleo branco que esfria até a cor da fruta, com a borda caindo suave (antes: branco → azul para toda fruta)
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), cor.lerp(Color.WHITE, 0.55), Color(cor, 0.55), Color(cor, 0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var base := StandardMaterial3D.new()
		base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		base.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		base.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		base.albedo_texture = tex
		_materiais[chave] = base
	var mat := (_materiais[chave] as StandardMaterial3D).duplicate() as StandardMaterial3D
	malha.material = mat
	var no := MeshInstance3D.new()
	no.mesh = malha
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(no)
	no.global_position = onde
	# estoura: nasce a 40% e cresce rápido (ease-out) enquanto some, em vez de só apagar parado
	no.scale = Vector3.ONE * 0.4
	var tw := no.create_tween().set_parallel(true)
	tw.tween_property(no, "scale", Vector3.ONE * 1.15, duracao).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao).set_ease(Tween.EASE_IN)
	_durar(no, duracao + 0.05)


## Polilinha luminosa (dois quadriláteros cruzados por trecho), some em `duracao`.
static func relampago(de: Node, pontos: PackedVector3Array, largura := 0.35, duracao := 0.2,
		cor := COR_RAIO) -> void:
	var raiz := _raiz(de)
	if raiz == null or pontos.size() < 2:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pontos.size() - 1:
		var a := pontos[i]
		var b := pontos[i + 1]
		var eixo := (b - a)
		if eixo.length_squared() < 0.0001:
			continue
		var lado := eixo.cross(Vector3.UP)
		if lado.length_squared() < 0.0001:
			lado = eixo.cross(Vector3.RIGHT)
		lado = lado.normalized() * largura * 0.5
		var cima := eixo.cross(lado).normalized() * largura * 0.5
		for d in [lado, cima]:
			st.add_vertex(a - d); st.add_vertex(a + d); st.add_vertex(b + d)
			st.add_vertex(a - d); st.add_vertex(b + d); st.add_vertex(b - d)
	var no := MeshInstance3D.new()
	no.mesh = st.commit()
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = cor
	no.material_override = mat
	raiz.add_child(no)
	no.create_tween().tween_property(mat, "albedo_color:a", 0.0, duracao)
	_durar(no, duracao + 0.05)


## Zigue-zague de `de_p` até `ate` (a entidade LightningBolt e o raio guiado do mod).
static func zigue_zague(de_p: Vector3, ate: Vector3, desvio: float, trechos: int) -> PackedVector3Array:
	var pontos := PackedVector3Array([de_p])
	for i in range(1, trechos):
		var t := float(i) / trechos
		var p := de_p.lerp(ate, t)
		pontos.append(p + Vector3(randf_range(-desvio, desvio), randf_range(-desvio, desvio) * 0.3,
			randf_range(-desvio, desvio)))
	pontos.append(ate)
	return pontos


## LightningBolt: o raio do céu até `ate`, com clarão e trovão.
static func raio_do_ceu(de: Node, ate: Vector3) -> void:
	var topo := ate + Vector3(randf_range(-4, 4), 60.0, randf_range(-4, 4))
	relampago(de, zigue_zague(topo, ate, 3.0, 14), 0.9, 0.35, COR_NUCLEO)
	clarao(de, ate + Vector3.UP, 3.0, 0.25)
	som(de, ate, "thunder_impact", 0.0)


## A descarga do Vari: arcos curtos do centro para fora, em todas as direções.
static func descarga(de: Node, centro: Vector3, raio: float, arcos: int) -> void:
	for i in arcos:
		var ponta := centro + Vector3(randf_range(-1, 1), randf_range(-0.6, 1), randf_range(-1, 1)).normalized() * raio * randf_range(0.5, 1.0)
		relampago(de, zigue_zague(centro, ponta, raio * 0.12, 5), 0.12, 0.1)


## Marca de impacto no chão (a "quebra de blocos" do mod virou marca: decisão do dono).
static var _marcas: Array[Vector4] = []   # (x, y, z, instante)


static func marca(de: Node, onde: Vector3, raio: float, duracao := 5.0) -> void:
	var raiz := _raiz(de)
	if raiz == null or raio <= 0.0:
		return
	# Feixe e chuva de raios marcam o mesmo chão a cada tick: uma marca por lugar.
	var agora := Time.get_ticks_msec() / 1000.0
	for i in range(_marcas.size() - 1, -1, -1):
		var m4 := _marcas[i]
		if agora - m4.w > 1.5:
			_marcas.remove_at(i)
		elif Vector3(m4.x, m4.y, m4.z).distance_to(onde) < raio * 0.8:
			return
	_marcas.append(Vector4(onde.x, onde.y, onde.z, agora))
	var hit: Dictionary = (de as Node3D).get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		onde + Vector3.UP * 2.0, onde + Vector3.DOWN * (raio + 4.0), MundoMinePiece.MASCARA_MUNDO))
	if hit.is_empty():
		return
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE * raio * 2.0
	malha.orientation = PlaneMesh.FACE_Y
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.05, 0.07, 0.35))
	grad.set_color(1, Color(0.05, 0.05, 0.07, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = tex
	malha.material = mat
	var no := MeshInstance3D.new()
	no.mesh = malha
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(no)
	no.global_position = hit.position + hit.normal * 0.04
	no.create_tween().tween_property(mat, "albedo_color:a", 0.0, 1.5).set_delay(duracao - 1.5)
	_durar(no, duracao)


static func som(de: Node, onde: Vector3, nome: String, volume_db := -6.0) -> void:
	var raiz := _raiz(de)
	# `sons/...` = os sons novos de 24/11/2026 (WAV gerado por `tools/generate_goro_mp_audio.py`); o resto, os .ogg do mod.
	var caminho := PASTA + nome + (".wav" if nome.begins_with("sons/") else ".ogg")
	if raiz == null or not ResourceLoader.exists(caminho):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = load(caminho)
	p.volume_db = volume_db
	p.max_distance = 120.0
	raiz.add_child(p)
	p.global_position = onde
	p.finished.connect(p.queue_free)
	p.play()
