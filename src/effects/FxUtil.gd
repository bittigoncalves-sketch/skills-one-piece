class_name FxUtil
extends RefCounted
const FxQualityPolicy = preload("res://src/effects/FxQuality.gd")
# Helpers para VFX 100% procedurais (sem texturas em disco):
# gradientes de cor, curvas de escala, materiais de partícula e um builder
# de GPUParticles3D. Usado por SandFX / FireFX / IceFX.

# Gradiente 1D a partir de uma lista de cores (offsets uniformes).
static func gradient(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, colors[0])
	g.set_offset(1, 1.0)
	g.set_color(1, colors[colors.size() - 1])
	for i in range(1, colors.size() - 1):
		g.add_point(float(i) / float(colors.size() - 1), colors[i])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

# Curva -> CurveTexture (ex.: escala da partícula ao longo da vida).
static func curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t

# ============================================================================
#  ⚠️ COMO SE FAZ UM EFEITO BRILHAR NESTE JOGO — leia antes de escrever material
#
#  `SHADING_MODE_UNSHADED` **DESCARTA A EMISSÃO**. Um material unshaded devolve
#  só o `albedo_color`, que é limitado a 1,0 — e o limiar do glow é 1,05. Ou
#  seja: `emission_enabled` + `emission_energy_multiplier` num material unshaded
#  não fazem absolutamente nada.
#
#  E era assim que o jogo inteiro estava escrito: 32 combinações em 16 arquivos,
#  todas declarando energia de emissão entre 2,5 e 4,0 e jogando fora. Ninguém
#  notou porque, até 2026-08-25, não existia glow no projeto — dois defeitos
#  escondidos um no outro. Ver `docs/erros.md`.
#
#  MEDIDO (halo em volta de uma esfera, com glow menos sem glow):
#
#      unshaded + emissão 4.0            +0,0000   não brilha
#      unshaded SÓ albedo                +0,0000   idêntico, ao dígito
#      unshaded + albedo ×2,5            +0,0597   brilha
#      unshaded + albedo ×2,5, alpha 0,6 +0,0422   brilha (atenuado pelo alpha)
#      unshaded + albedo ×2,5, aditivo   +0,0625   brilha
#
#  Então: para brilhar, o ALBEDO passa de 1,0. É o que `brilho()` faz.
#
#  ⚠️ E POR QUE NÃO TIRAR O `unshaded`. Material sombreado também brilha
#  (+0,0355), mas aí o efeito passa a ESCURECER quando o golpe atravessa a
#  sombra de um bloco — fogo não apaga na sombra. O unshaded é intencional; o
#  que estava errado era o caminho do brilho.
#  ⚠️ O PISO DE 1,0 NÃO É DETALHE. Alguns materiais declaravam energia MENOR
#  que 1 (o `SandFX` usa 0,8). Como a emissão era descartada, esse número nunca
#  fez nada; aplicá-lo ao albedo deixaria a areia mais ESCURA do que está hoje —
#  a correção viraria regressão silenciosa. Esta função existe para CLAREAR;
#  energia abaixo de 1 significa "não brilha", não "escurece".
#
#  ------------------------------------------------------ ⭐ O BOTÃO DO BRILHO
#  `ESCALA` é a alavanca ÚNICA de "quão fortes são os efeitos". Baixar aqui
#  apaga todos os golpes de todas as frutas de uma vez; subir, o contrário.
#
#  ⚠️ POR QUE COMPRIME EM VEZ DE MULTIPLICAR. As energias escritas nos efeitos
#  (2,5 · 3,0 · 4,0 · 5,0 · 6,0 · 8,0) NUNCA FORAM CALIBRADAS: elas viviam num
#  campo de emissão que era descartado, então ninguém nunca viu o efeito delas.
#  Aplicadas ao pé da letra ficaram fortes demais — relato do dono em
#  2026-08-25, e medido: 3,0% da tela estourada numa cena de um golpe só.
#
#  Uma multiplicação simples (`e * ESCALA`) achataria tudo por igual e mataria a
#  diferença entre um golpe de 2,5 e um de 8,0. A compressão em torno de 1,0
#  preserva a ORDEM que o autor quis e encurta a distância:
#
#      e = 1 + (energia − 1) × ESCALA
#
#      energia   2,5    4,0    6,0    8,0
#      com 0,45  1,68   2,35   3,25   4,15
const ESCALA := 0.45

static func brilho(cor: Color, energia: float, alpha: float = -1.0) -> Color:
	var e: float = 1.0 + (maxf(energia, 1.0) - 1.0) * ESCALA
	var a: float = cor.a if alpha < 0.0 else alpha
	return Color(cor.r * e, cor.g * e, cor.b * e, a)


# Material de partícula billboard (unshaded, alpha, brilho opcional/aditivo).
static func particle_material(base: Color, emission_energy: float, additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	# O brilho vai no ALBEDO, não na emissão — ver a nota acima. Este é o ponto
	# de maior alcance da correção: 13 chamadas em 6 arquivos passam por aqui.
	m.albedo_color = brilho(base, emission_energy) if emission_energy > 0.0 else base
	return m

# Cria um GPUParticles3D já configurado.
static func particles(amount: int, lifetime: float, one_shot: bool,
		proc: ParticleProcessMaterial, mesh: Mesh, explosiveness: float = 0.0,
		categoria: String = "padrao") -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = FxQualityPolicy.quantidade(amount, categoria)
	p.lifetime = FxQualityPolicy.duracao(lifetime, categoria)
	p.one_shot = one_shot
	p.explosiveness = explosiveness
	p.process_material = proc
	p.draw_pass_1 = mesh
	p.emitting = true
	return p

# Quad pequeno para grão/faísca de partícula, já com material billboard que usa
# a cor da partícula (color_ramp) como albedo. Efeitos aditivos (fogo) podem
# sobrepor com material_override no próprio GPUParticles3D.
static func grain(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, 1)
	m.disable_receive_shadows = true
	q.material = m
	return q

# ONDE UM EFEITO DEVE NASCER.
#
# ⚠️ Efeito pendurado em `get_tree().current_scene` NÃO É LIMPO por
# `Player.clear_spawned_skills()` (2026-08-22) — ela só varre os filhos do
# contêiner `Skills_<jogador>`. Era por isso que trocar de fruta ou morrer
# deixava golpe vivo no mapa: quatro efeitos escapavam para a cena e ninguém
# mais era dono deles.
#
# Use isto no lugar de `current_scene` sempre que o efeito PERTENCER a um golpe.
# Quem não tem caster (ou caster sem contêiner) cai na cena, como antes.
static func mundo_de_skills(caster: Node, alternativa: Node = null) -> Node:
	if is_instance_valid(caster) and caster.has_method("_get_skills_container"):
		var c = caster._get_skills_container()
		if is_instance_valid(c):
			return c
	if is_instance_valid(alternativa):
		return alternativa
	var arv := Engine.get_main_loop() as SceneTree
	return arv.current_scene if arv != null else null

# Agenda a remoção do nó após `t` segundos.
#
# ⚠️ NÃO USE `node.get_tree()` SOZINHO (corrigido em 2026-08-22). Ele é NULO
# enquanto o nó não está na árvore — e isso acontece de verdade no caminho normal
# do jogo: `Player._get_skills_container()` entra na cena por
# `add_child.call_deferred(...)`, então no PRIMEIRO golpe de uma vida o contêiner
# ainda não está na árvore quando o efeito nasce dentro dele. Quem chamasse
# `autofree` aí levava "Cannot call method 'create_timer' on a null value", o
# temporizador nunca era criado e **o nó ficava no mapa para sempre**.
#
# Encontrado ao rotear o V da Goro Goro pelo `_fire_skill`, mas o buraco é geral:
# vale para qualquer efeito criado no primeiro cast.
#
# O `Engine.get_main_loop()` é o mesmo `SceneTree`, e não depende de o nó já
# estar pendurado em algum lugar.
static func autofree(node: Node, t: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var arv: SceneTree = node.get_tree()
	if arv == null:
		arv = Engine.get_main_loop() as SceneTree
	if arv == null:
		return                                  # sem laço principal: nada a agendar
	arv.create_timer(t).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free())

# Piscada VERMELHA de dano: aplica um overlay vermelho translúcido em TODAS as meshes
# do modelo e o desvanece (não altera os materiais base). Vale p/ qualquer ser.
static func flash_red(root: Node3D) -> void:
	if root == null:
		return
	var meshes: Array = []
	_collect_meshes(root, meshes)
	if meshes.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var is_aim_target: bool = false
	if Engine.has_singleton("ScreenFX") or root.get_tree().root.has_node("ScreenFX"):
		var screen_fx := root.get_node("/root/ScreenFX")
		if screen_fx and screen_fx.has_method("is_aim_target_highlighted"):
			is_aim_target = screen_fx.is_aim_target_highlighted(root)
	var flash_col := Color(1.0, 0.9, 0.2, 0.85) if is_aim_target else Color(1.0, 0.12, 0.1, 0.55)
	mat.albedo_color = flash_col
	for mi in meshes:
		(mi as GeometryInstance3D).material_overlay = mat
	var tw := (meshes[0] as Node).create_tween()
	tw.tween_method(func(a: float):
		if is_instance_valid(mat):
			mat.albedo_color = Color(flash_col.r, flash_col.g, flash_col.b, a)
	, flash_col.a, 0.0, 0.35)
	tw.tween_callback(func():
		for mi2 in meshes:
			if is_instance_valid(mi2):
				var restore_red := false
				var sfx := root.get_node_or_null("/root/ScreenFX")
				if sfx and sfx.has_method("is_aim_target_highlighted"):
					restore_red = sfx.is_aim_target_highlighted(root)
				if restore_red and sfx.has_method("get_target_material"):
					(mi2 as GeometryInstance3D).material_overlay = sfx.get_target_material()
				else:
					(mi2 as GeometryInstance3D).material_overlay = null)


# Número de DANO flutuante (Label3D que sobe e some) sobre o alvo atingido.
static func damage_number(world: Node, pos: Vector3, amount: float, color: Color = Color(1, 1, 1)) -> void:
	if world == null:
		return
	var lbl := Label3D.new()
	lbl.text = str(int(round(amount)))
	lbl.font_size = 72
	lbl.modulate = color
	lbl.outline_size = 14
	lbl.outline_modulate = Color(0, 0, 0, 0.9)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.006
	world.add_child(lbl)
	lbl.global_position = pos + Vector3(randf_range(-0.3, 0.3), 0.25, randf_range(-0.3, 0.3))
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y + 1.5, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.15)
	tw.tween_callback(lbl.queue_free)

static func _collect_meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)

# ---- GEPPO (Pulo Duplo / Técnica do CP9) ----
# Gera os emblemáticos anéis de ar comprimido no pé do personagem ao chutar o ar no pulo duplo,
# acompanhado de explosão de cubos (voxels) de vento e uma trilha de velocidade em voo.
static func geppo_effect(world: Node, feet_pos: Vector3, move_dir: Vector3 = Vector3.ZERO, facing_yaw: float = 0.0, attach_to: Node3D = null) -> void:
	if world == null:
		return
	# 1. Anel Externo de Ar Comprimido (Onda de choque principal)
	var mi_out := MeshInstance3D.new()
	var tm_out := TorusMesh.new()
	tm_out.inner_radius = 0.68
	tm_out.outer_radius = 0.92
	mi_out.mesh = tm_out
	var mat_out := StandardMaterial3D.new()
	mat_out.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_out.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_out.albedo_color = brilho(Color(0.85, 0.95, 1.0, 0.85), 3.0)
	mat_out.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi_out.material_override = mat_out
	mi_out.scale = Vector3(0.35, 0.25, 0.35)
	world.add_child(mi_out)
	mi_out.global_position = feet_pos
	
	var tw1 := mi_out.create_tween()
	tw1.set_parallel(true)
	tw1.tween_property(mi_out, "scale", Vector3(3.4, 0.1, 3.4), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw1.tween_property(mat_out, "albedo_color:a", 0.0, 0.35)
	tw1.tween_callback(mi_out.queue_free).set_delay(0.36)

	# 2. Anel Interno de Choque (Núcleo branco de alta pressão)
	var mi_in := MeshInstance3D.new()
	var tm_in := TorusMesh.new()
	tm_in.inner_radius = 0.28
	tm_in.outer_radius = 0.52
	mi_in.mesh = tm_in
	var mat_in := StandardMaterial3D.new()
	mat_in.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_in.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_in.albedo_color = brilho(Color(1.0, 1.0, 1.0, 0.95), 4.0)
	mat_in.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi_in.material_override = mat_in
	mi_in.scale = Vector3(0.2, 0.35, 0.2)
	world.add_child(mi_in)
	mi_in.global_position = feet_pos + Vector3(0, 0.05, 0)
	
	var tw2 := mi_in.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(mi_in, "scale", Vector3(2.1, 0.08, 2.1), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(mat_in, "albedo_color:a", 0.0, 0.25)
	tw2.tween_callback(mi_in.queue_free).set_delay(0.26)

	# 3. Explosão Voxel de Ar (Cubos brancos/azuis disparados para baixo ao chutar o ar)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1.0, 0)
	pm.spread = 65.0
	pm.initial_velocity_min = 5.5
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3(0, -16.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = gradient([Color(1, 1, 1, 0.95), Color(0.8, 0.92, 1.0, 0.7), Color(0.7, 0.85, 1.0, 0)])
	
	var voxel_mesh := BoxMesh.new()
	voxel_mesh.size = Vector3(0.22, 0.22, 0.22)
	var p_mat := particle_material(Color(1, 1, 1, 1), 2.2, true)
	voxel_mesh.material = p_mat
	
	var burst := particles(45, 0.45, true, pm, voxel_mesh, 0.92)
	world.add_child(burst)
	burst.global_position = feet_pos
	autofree(burst, 0.7)

	# 4. Trilha de Movimento (Estrias/rasto de ar comprimido durante a impulsão aérea)
	if attach_to and is_instance_valid(attach_to):
		var trail_pm := ParticleProcessMaterial.new()
		trail_pm.direction = Vector3(0, -0.2, 1.0) # para trás em relação ao corpo (-Z é frente)
		trail_pm.spread = 18.0
		trail_pm.initial_velocity_min = 2.5
		trail_pm.initial_velocity_max = 5.5
		trail_pm.scale_min = 0.6
		trail_pm.scale_max = 1.4
		trail_pm.color_ramp = gradient([Color(0.85, 0.95, 1.0, 0.75), Color(0.7, 0.88, 1.0, 0.3), Color(1, 1, 1, 0)])
		
		var trail_mesh := BoxMesh.new()
		trail_mesh.size = Vector3(0.16, 0.16, 0.16)
		trail_mesh.material = particle_material(Color(0.9, 0.95, 1.0, 1), 1.8, true)
		
		var trail := GPUParticles3D.new()
		trail.amount = 28
		trail.lifetime = 0.28
		trail.one_shot = false
		trail.explosiveness = 0.05
		trail.process_material = trail_pm
		trail.draw_pass_1 = trail_mesh
		attach_to.add_child(trail)
		trail.position = Vector3(0, -0.5, 0.1)
		trail.emitting = true
		
		var timer := attach_to.get_tree().create_timer(0.32)
		timer.timeout.connect(func():
			if is_instance_valid(trail):
				trail.emitting = false
				autofree(trail, 0.4))

# ---- DASH EFFECT (Cópia horizontal do Geppo) ----
# `move_dir` é para onde o jogador ARRANCA. Todo o efeito nasce do lado CONTRÁRIO
# — é o ar deixado para trás no arranque, então ele fica visível atrás do corpo em
# vez de ser atropelado por ele.
const DASH_FX_RECUO := 0.6   # metros atrás do jogador onde o efeito nasce

static func dash_effect(world: Node, base_pos: Vector3, move_dir: Vector3) -> void:
	if world == null or move_dir.length_squared() < 0.01:
		return

	var fwd := move_dir.normalized()
	var up := Vector3.UP if abs(fwd.y) < 0.95 else Vector3.FORWARD
	var right := fwd.cross(up).normalized()
	var real_up := right.cross(fwd).normalized()
	var ring_basis := Basis(right, real_up, -fwd)
	var recuo := -fwd * DASH_FX_RECUO   # deslocamento p/ TRÁS do movimento

	# 1. Anel Externo de Ar Comprimido (Onda de choque principal)
	var mi_out := MeshInstance3D.new()
	var tm_out := TorusMesh.new()
	tm_out.inner_radius = 0.68
	tm_out.outer_radius = 0.92
	mi_out.mesh = tm_out
	var mat_out := StandardMaterial3D.new()
	mat_out.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_out.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_out.albedo_color = brilho(Color(0.85, 0.95, 1.0, 0.85), 3.0)
	mat_out.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi_out.material_override = mat_out
	mi_out.scale = Vector3(0.35, 0.25, 0.35)
	world.add_child(mi_out)
	mi_out.global_position = base_pos + Vector3(0, 1.0, 0) + recuo

	# Rotaciona para que o anel fique de pé e cresça perpendicular ao fwd
	mi_out.transform.basis = ring_basis.rotated(right, PI/2.0)
	
	var tw1 := mi_out.create_tween()
	tw1.set_parallel(true)
	tw1.tween_property(mi_out, "scale", Vector3(3.4, 0.1, 3.4), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw1.tween_property(mat_out, "albedo_color:a", 0.0, 0.35)
	tw1.tween_callback(mi_out.queue_free).set_delay(0.36)

	# 2. Anel Interno de Choque (Núcleo branco de alta pressão)
	var mi_in := MeshInstance3D.new()
	var tm_in := TorusMesh.new()
	tm_in.inner_radius = 0.28
	tm_in.outer_radius = 0.52
	mi_in.mesh = tm_in
	var mat_in := StandardMaterial3D.new()
	mat_in.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_in.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_in.albedo_color = brilho(Color(1.0, 1.0, 1.0, 0.95), 4.0)
	mat_in.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi_in.material_override = mat_in
	mi_in.scale = Vector3(0.2, 0.35, 0.2)
	world.add_child(mi_in)
	mi_in.global_position = base_pos + Vector3(0, 1.0, 0) + recuo - fwd * 0.1
	mi_in.transform.basis = ring_basis.rotated(right, PI/2.0)
	
	var tw2 := mi_in.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(mi_in, "scale", Vector3(2.1, 0.08, 2.1), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(mat_in, "albedo_color:a", 0.0, 0.25)
	tw2.tween_callback(mi_in.queue_free).set_delay(0.26)

	# 3. Explosão Voxel de Ar (Cubos atirados na direção CONTRÁRIA ao dash)
	var pm := ParticleProcessMaterial.new()
	pm.direction = -fwd
	pm.spread = 45.0
	pm.initial_velocity_min = 5.5
	pm.initial_velocity_max = 13.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = gradient([Color(1, 1, 1, 0.95), Color(0.8, 0.92, 1.0, 0.7), Color(0.7, 0.85, 1.0, 0)])
	
	var voxel_mesh := BoxMesh.new()
	voxel_mesh.size = Vector3(0.22, 0.22, 0.22)
	var p_mat := particle_material(Color(1, 1, 1, 1), 2.2, true)
	voxel_mesh.material = p_mat
	
	var burst := particles(45, 0.45, true, pm, voxel_mesh, 0.92)
	world.add_child(burst)
	burst.global_position = base_pos + Vector3(0, 0.5, 0) + recuo
	autofree(burst, 0.7)

# Efeito de sangramento: gotas quadradas caindo no chão com partículas extras
static func bleed(world: Node, pos: Vector3, amount: int = 8) -> void:
	if world == null:
		return
		
	# 1. Partículas de Sangue (Efeito Imediato/Spray)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1.0, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(0, -15.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = gradient([Color(0.8, 0.0, 0.0, 1.0), Color(0.4, 0.0, 0.0, 0.8), Color(0.2, 0.0, 0.0, 0)])
	
	var blood_mesh := BoxMesh.new()
	blood_mesh.size = Vector3(0.08, 0.08, 0.08)
	blood_mesh.material = particle_material(Color(0.7, 0.0, 0.0, 1), 0.5, false)
	
	var burst := particles(25, 0.6, true, pm, blood_mesh, 0.95)
	world.add_child(burst)
	burst.global_position = pos
	autofree(burst, 1.0)
	
	# 2. Gotas Físicas (RigidBody3D) que espirram, caem no chão e somem
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.6, 0.0, 0.0, 1.0)
	drop_mat.roughness = 0.2
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var drop_box := BoxMesh.new()
	drop_box.size = Vector3(0.12, 0.12, 0.12)
	drop_box.material = drop_mat
	
	var drop_shape := BoxShape3D.new()
	drop_shape.size = drop_box.size
	
	for i in range(amount):
		var rb := RigidBody3D.new()
		# Camada 0 e Mascara 1 garantem que ela não bata no jogador, apenas no cenário
		rb.collision_layer = 0
		rb.collision_mask = 1 
		
		var mi := MeshInstance3D.new()
		mi.mesh = drop_box
		rb.add_child(mi)
		
		var col := CollisionShape3D.new()
		col.shape = drop_shape
		rb.add_child(col)
		
		world.add_child(rb)
		rb.global_position = pos + Vector3(randf_range(-0.2, 0.2), randf_range(0.0, 0.5), randf_range(-0.2, 0.2))
		
		# Impulso para espalhar
		var dir = Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.5), randf_range(-1.0, 1.0)).normalized()
		var force = randf_range(3.0, 7.0)
		rb.apply_central_impulse(dir * force)
		rb.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.5)
		
		# Fade scale and delete
		var tw := rb.create_tween()
		tw.tween_interval(randf_range(1.5, 3.5))
		tw.tween_property(mi, "scale", Vector3.ZERO, 1.0).set_ease(Tween.EASE_IN)
		tw.tween_callback(rb.queue_free)
