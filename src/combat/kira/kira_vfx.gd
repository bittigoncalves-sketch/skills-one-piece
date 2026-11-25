extends RefCounted
## Camada visual da Kira Kira: trilha da investida, impacto de cristal e texturas.
## Texturas vêm de `assets/textures/kira_kira/` (Codex); sem o PNG, gera uma equivalente
## em código para o efeito nunca ficar sem imagem. Só visual: dano e hitbox moram nos controladores.
const COR := Color(0.48, 0.87, 1.0)
const CAMINHO := "res://assets/textures/kira_kira/"
static var _cache := {}


static func textura(nome: String) -> Texture2D:
	if _cache.has(nome):
		return _cache[nome]
	var tex: Texture2D = null
	if ResourceLoader.exists(CAMINHO + nome + ".png"):
		tex = load(CAMINHO + nome + ".png") as Texture2D
	if tex == null:
		tex = _procedural(nome)
	_cache[nome] = tex
	return tex


static func _procedural(nome: String) -> Texture2D:
	var tam := 32 if nome in ["pedra_c", "faisca_diamante"] else (64 if nome == "rachadura_impacto" else 16)
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = nome.hash()
	for y in tam:
		for x in tam:
			var c := Color(0, 0, 0, 0)
			match nome:
				"pedra_x", "pedra_c":
					var v := 0.52 + rng.randf() * 0.16
					if (x * 7 + y * 13 + (x / 4) * 5) % 11 == 0:
						v -= 0.16                                   # junta/rachadura
					c = Color(v * 0.92, v * 0.96, v * 1.05)
				"cristal_facetas":
					var tri := (x + y) % 8 < 4
					var v := 0.62 + (0.2 if tri else 0.0) + rng.randf() * 0.1
					if x == 0 or y == 0 or x + y == tam - 1:
						v = 1.0                                     # aresta clara
					c = Color(0.35 + v * 0.45, 0.7 + v * 0.25, 1.0)
				"faisca_diamante":
					var d := Vector2(x - tam * 0.5 + 0.5, y - tam * 0.5 + 0.5).abs()
					var a := clampf(1.0 - (d.x * d.y) / 6.0 - maxf(d.x, d.y) / (tam * 0.5), 0.0, 1.0)
					c = Color(0.8, 0.96, 1.0, a)
				"rachadura_impacto":
					var d := Vector2(x - tam * 0.5, y - tam * 0.5)
					var ang := fposmod(d.angle(), TAU / 7.0)
					var a := 1.0 if (ang < 0.05 and d.length() < tam * 0.48) else 0.0
					c = Color(0.1, 0.12, 0.16, a * 0.8)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## Material de bloco/estilhaço: textura nítida, brilho próprio.
static func material(nome: String, brilho := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = textura(nome)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.35
	m.metallic = 0.15
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = brilho
	return m


static func _mat_brilho() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = textura("faisca_diamante")
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	return m


static func _encolher() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	return c


static func _cacos(qtd: int, vida: float, tamanho: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3.ONE * tamanho
	caixa.material = material("cristal_facetas", 0.9)
	p.mesh = caixa
	p.amount = qtd
	p.lifetime = vida
	p.local_coords = false
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.scale_amount_curve = _encolher()
	p.angle_max = 360.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func _brilhos(qtd: int, vida: float, tamanho: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * tamanho
	q.material = _mat_brilho()
	p.mesh = q
	p.amount = qtd
	p.lifetime = vida
	p.local_coords = false
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.scale_amount_curve = _encolher()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Trilha de cacos e brilhos presa ao corpo durante a investida. `parar` a solta e a apaga.
static func trilha(ator: Node3D) -> Node3D:
	if ator == null or not is_instance_valid(ator) or not ator.is_inside_tree():
		return null
	var raiz := Node3D.new()
	raiz.name = "KiraTrilha"
	ator.add_child(raiz)
	var cacos := _cacos(40, 0.55, 0.16)
	cacos.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cacos.emission_sphere_radius = 0.55
	cacos.direction = Vector3.UP
	cacos.spread = 180.0
	cacos.initial_velocity_min = 0.5
	cacos.initial_velocity_max = 2.5
	cacos.gravity = Vector3(0, -2.0, 0)
	cacos.angular_velocity_min = -360.0
	cacos.angular_velocity_max = 360.0
	raiz.add_child(cacos)
	var brilhos := _brilhos(22, 0.4, 0.55)
	brilhos.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	brilhos.emission_sphere_radius = 0.7
	brilhos.gravity = Vector3.ZERO
	brilhos.initial_velocity_max = 1.0
	raiz.add_child(brilhos)
	return raiz


static func parar(trilha_ativa) -> void:
	if trilha_ativa == null or not is_instance_valid(trilha_ativa):
		return
	for f in trilha_ativa.get_children():
		if f is CPUParticles3D:
			(f as CPUParticles3D).emitting = false
	if trilha_ativa.is_inside_tree():
		trilha_ativa.get_tree().create_timer(0.7, false).timeout.connect(func() -> void:
			if is_instance_valid(trilha_ativa):
				trilha_ativa.queue_free())
	else:
		trilha_ativa.queue_free()


## Estouro de cristal no ponto de contato. `forte` = pegou alguém (lançamento): mais cacos, anel maior, tremor.
static func impacto(pai: Node, posicao: Vector3, forte: bool, normal := Vector3.UP) -> void:
	if pai == null or not is_instance_valid(pai) or not pai.is_inside_tree():
		return
	var raio := 5.2 if forte else 3.4
	PoderVfx.impacto(pai, posicao, COR, raio, PoderVfx.Forma.CIRCULO, normal)
	if forte:
		PoderVfx.solo(pai, posicao - Vector3.UP * 0.8, raio * 0.7)
	PoderVfx.tremor(pai, 0.85 if forte else 0.4)
	var cacos := _cacos(90 if forte else 36, 0.9, 0.2)
	cacos.one_shot = true
	cacos.explosiveness = 1.0
	cacos.direction = normal
	cacos.spread = 75.0
	cacos.initial_velocity_min = 5.0
	cacos.initial_velocity_max = 13.0 if forte else 9.0
	cacos.gravity = Vector3(0, -18.0, 0)
	cacos.angular_velocity_min = -540.0
	cacos.angular_velocity_max = 540.0
	pai.add_child(cacos)
	cacos.global_position = posicao
	cacos.emitting = true
	var brilhos := _brilhos(24 if forte else 10, 0.6, 0.9)
	brilhos.one_shot = true
	brilhos.explosiveness = 1.0
	brilhos.spread = 180.0
	brilhos.initial_velocity_min = 2.0
	brilhos.initial_velocity_max = 7.0
	brilhos.gravity = Vector3.ZERO
	pai.add_child(brilhos)
	brilhos.global_position = posicao
	brilhos.emitting = true
	var luz := OmniLight3D.new()
	luz.light_color = COR
	luz.light_energy = 4.0 if forte else 2.0
	luz.omni_range = 9.0
	luz.shadow_enabled = false
	pai.add_child(luz)
	luz.global_position = posicao + Vector3.UP * 0.5
	var tw := luz.create_tween()
	tw.tween_property(luz, "light_energy", 0.0, 0.3)
	tw.tween_callback(luz.queue_free)
	pai.get_tree().create_timer(1.6, false).timeout.connect(func() -> void:
		for n: Node in [cacos, brilhos]:
			if is_instance_valid(n):
				n.queue_free())
