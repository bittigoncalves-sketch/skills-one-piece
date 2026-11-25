class_name YoruFX
extends RefCounted
## Fagulhas de aço em ouro/verde; posição mundial fixa e vida finita.
## Um MultiMesh por impacto, sem luzes, física ou dependência de outra fruta.

static var _spark_mesh: PrismMesh
static var _spark_material: StandardMaterial3D


static func impact(parent: Node3D, position: Vector3, parry: bool = false) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if _spark_mesh == null:
		_spark_mesh = PrismMesh.new()
		_spark_mesh.size = Vector3(0.023, 0.15, 0.023)
		_spark_material = StandardMaterial3D.new()
		_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spark_material.vertex_color_use_as_albedo = true
		_spark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var burst := MultiMeshInstance3D.new()
	burst.name = "YoruParrySparks" if parry else "YoruImpactSparks"
	burst.top_level = true
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.material_override = _spark_material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _spark_mesh
	multimesh.instance_count = 18 if parry else 10
	multimesh.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	burst.multimesh = multimesh
	parent.add_child(burst)
	burst.global_position = position
	var random := RandomNumberGenerator.new()
	random.randomize()
	var velocities := PackedVector3Array()
	var colors := PackedColorArray()
	for i in multimesh.instance_count:
		var angle := random.randf_range(0.0, TAU)
		var vertical := random.randf_range(-0.32, 0.85)
		var direction := Vector3(cos(angle), vertical, sin(angle)).normalized()
		velocities.append(direction * random.randf_range(2.0, 4.5 if parry else 3.4))
		# HDR albedo gives this unshaded material the project's bloom convention.
		colors.append(Color(2.3, 1.52, 0.40) if (i % 3 != 0 or parry) \
			else Color(0.30, 1.65, 0.85))
	# O clarão e o apagão são do ACERTO. O aparo tem a própria leitura (mais
	# fagulhas, som próprio) e não pode roubar a do contato limpo.
	if not parry:
		clarao(parent, position)
		escurecer(parent)
	var duration := 0.34 if parry else 0.25
	_update(multimesh, velocities, colors, 0.0, duration)
	var tween := burst.create_tween()
	tween.tween_method(func(time: float) -> void:
		_update(multimesh, velocities, colors, time, duration), 0.0, duration, duration)
	tween.tween_callback(burst.queue_free)


# ============================================================================
#  A ASSINATURA DO CLIQUE — raios roxos no fio, e o clarão de quem conecta
# ============================================================================
#  MEDIDO em `melhorar_as_skills_em_video_ta.mp4` (últimos 3 s), a referência que
#  o dono mandou em 10/09/2026 para o M1:
#
#      arco roxo ......... corpo (0,504 · 0,266 · 0,799), borda (0,782 · 0,421 · 0,976)
#      raios ............. ziguezague curto saindo da borda do arco, mesma matiz
#      no acerto ......... a CENA inteira escurece 2-3 quadros e o ponto de
#                          contato estoura em dourado; o número de dano fica legível
#
#  A divisão de trabalho: a FITA do arco é o `WeaponTrail3D` do controlador, e
#  estes raios são o que faz o arco parecer carregado em vez de pintado. Ficam
#  presos à espada — o gesto continua enquanto eles vivem.
const RAIOS := 9
const RAIO_VIDA := 0.22
# ⚠️ HDR, mas MODERADO. Com (2,6 · 1,05 · 3,4) os raios saíam BRANCOS na captura:
# passado certo ponto o bloom lava a matiz e o roxo vira estouro. Este par
# mantém o brilho e ainda lê como roxo.
const COR_RAIO := Color(1.45, 0.42, 2.15)


## Ziguezagues curtos ao longo do fio, redesenhados durante a janela do golpe.
## `base` e `ponta` são os nós que a `YoruSword` já expõe para o rastro.
static func arco_eletrico(sword: Node3D) -> void:
	if not is_instance_valid(sword) or not sword.is_inside_tree():
		return
	var base := sword.get("guarda") as Node3D
	var ponta := sword.get("ponta") as Node3D
	if not is_instance_valid(base) or not is_instance_valid(ponta):
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 1.0)    # esticado no Z e reorientado por raio
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bolt := MultiMeshInstance3D.new()
	bolt.name = "YoruArcSparks"
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.material_override = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = RAIOS
	multimesh.custom_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	bolt.multimesh = multimesh
	# Filho da ESPADA: os raios acompanham o gesto em vez de ficarem no ar onde
	# a lâmina estava quando a janela abriu.
	sword.add_child(bolt)
	var random := RandomNumberGenerator.new()
	random.randomize()
	var comprimento: float = base.global_position.distance_to(ponta.global_position)
	var tween := bolt.create_tween()
	tween.tween_method(func(time: float) -> void:
		_raios(multimesh, random, comprimento, time), 0.0, RAIO_VIDA, RAIO_VIDA)
	tween.tween_callback(bolt.queue_free)


## O clarão de quem conecta: um quad dourado em HDR que abre e some.
## Fica no MUNDO (`top_level`), no ponto de contato, e não segue mais ninguém.
const CLARAO_VIDA := 0.18
const CLARAO_RAIO := 1.35
const COR_CLARAO := Color(4.2, 2.7, 0.75)


static func clarao(parent: Node3D, position: Vector3) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var flash := MeshInstance3D.new()
	flash.name = "YoruHitFlash"
	flash.top_level = true
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	flash.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.albedo_color = COR_CLARAO
	# ⚠️ SEM ESTA TEXTURA O CLARÃO É UM QUADRADO. Um QuadMesh cru pintado de
	# dourado aparece como o retângulo que ele é — foi o que a primeira captura
	# mostrou. O gradiente radial é o que transforma a mesma geometria em luz.
	material.albedo_texture = _textura_clarao()
	flash.material_override = material
	parent.add_child(flash)
	flash.global_position = position
	flash.scale = Vector3.ONE * (CLARAO_RAIO * 0.35)
	var tween := flash.create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * CLARAO_RAIO, CLARAO_VIDA) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, CLARAO_VIDA) \
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(flash.queue_free)


static var _clarao_textura: GradientTexture2D


## Disco de luz: opaco no centro, transparente na borda. Uma vez só, compartilhado.
static func _textura_clarao() -> GradientTexture2D:
	if _clarao_textura != null:
		return _clarao_textura
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.22, 0.58, 1.0])
	rampa.colors = PackedColorArray([
		Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.85),
		Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)])
	_clarao_textura = GradientTexture2D.new()
	_clarao_textura.gradient = rampa
	_clarao_textura.fill = GradientTexture2D.FILL_RADIAL
	_clarao_textura.fill_from = Vector2(0.5, 0.5)
	_clarao_textura.fill_to = Vector2(1.0, 0.5)
	_clarao_textura.width = 128
	_clarao_textura.height = 128
	return _clarao_textura


static var _fita_textura: GradientTexture2D


## O MIOLO ESCURO do arco do clique.
##
## Na referência o crescente roxo não é uma cor chapada: o meio é quase preto e
## só as duas bordas queimam. A fita do `WeaponTrail3D` vai da guarda (UV y = 0)
## à ponta (UV y = 1), então esse gradiente atravessa a LARGURA do arco e põe o
## escuro no lugar certo sem tocar na geometria do rastro.
static func fita_do_clique() -> GradientTexture2D:
	if _fita_textura != null:
		return _fita_textura
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.16, 0.46, 0.72, 1.0])
	rampa.colors = PackedColorArray([
		Color(1.00, 0.92, 1.00, 1.00),   # borda de fora: queimada
		Color(0.72, 0.46, 0.95, 0.92),
		Color(0.16, 0.06, 0.26, 1.00),   # miolo: quase preto, e OPACO
		Color(0.60, 0.34, 0.90, 0.90),
		Color(0.95, 0.86, 1.00, 0.98)])
	_fita_textura = GradientTexture2D.new()
	_fita_textura.gradient = rampa
	_fita_textura.fill_from = Vector2(0.0, 0.0)
	_fita_textura.fill_to = Vector2(0.0, 1.0)
	_fita_textura.width = 8
	_fita_textura.height = 128
	return _fita_textura


# ---------------------------------------------------------- o mundo apaga
#  Decisão do dono em 10/09/2026, com a pergunta feita e a alternativa recusada:
#  o escurecimento entra SEMPRE, inclusive em PvP, como no vídeo. O custo aceito
#  é conhecido — quem está apanhando também perde a leitura da cena por um
#  instante, e a etapa 4 do PLANO_YORU tinha excluído câmera forçada do PvP.
#
#  Feito na EXPOSIÇÃO, não com um retângulo preto por cima: é o que a referência
#  mostra (o clarão dourado e o número continuam estourados enquanto o resto
#  apaga) e é o que um retângulo não conseguiria, porque ele escureceria o
#  clarão junto.
const ESCURO_FATOR := 0.40
const ESCURO_SEGURA := 0.045
const ESCURO_VOLTA := 0.17


static func escurecer(node: Node3D) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var mundo := node.get_world_3d()
	if mundo == null or mundo.environment == null:
		return
	var ambiente := mundo.environment
	# A base mora no PRÓPRIO ambiente: trocar de cena traz outro Environment, e um
	# valor guardado numa estática devolveria a exposição da cena anterior.
	if not ambiente.has_meta("yoru_exposicao_base"):
		ambiente.set_meta("yoru_exposicao_base", ambiente.tonemap_exposure)
	var base: float = float(ambiente.get_meta("yoru_exposicao_base"))
	var arvore := node.get_tree()
	if arvore == null:
		return
	# Tween da ÁRVORE, não do nó: se o efeito for liberado no meio (alvo morre,
	# arma some), um tween preso a ele morreria junto e o mundo ficaria escuro.
	ambiente.tonemap_exposure = base * ESCURO_FATOR
	var tween := arvore.create_tween()
	tween.tween_interval(ESCURO_SEGURA)
	tween.tween_property(ambiente, "tonemap_exposure", base, ESCURO_VOLTA)


static func _raios(multimesh: MultiMesh, random: RandomNumberGenerator,
		comprimento: float, time: float) -> void:
	var fade := 1.0 - time / RAIO_VIDA
	for i in multimesh.instance_count:
		# Espalhados pelo comprimento do fio, saltando para fora dele.
		var altura: float = comprimento * (0.15 + 0.85 * float(i) / float(maxi(multimesh.instance_count - 1, 1)))
		var origem := Vector3(random.randf_range(0.0, 0.22), altura, random.randf_range(-0.12, 0.12))
		var salto := Vector3(random.randf_range(0.10, 0.45), random.randf_range(-0.20, 0.20),
			random.randf_range(-0.18, 0.18))
		var orientacao := Basis(Quaternion(Vector3.BACK, salto.normalized()))
		orientacao = orientacao.scaled(Vector3(fade, fade, salto.length()))
		multimesh.set_instance_transform(i, Transform3D(orientacao, origem))
		var cor := COR_RAIO
		cor.a = fade
		multimesh.set_instance_color(i, cor)


static func _update(multimesh: MultiMesh, velocities: PackedVector3Array,
		colors: PackedColorArray, time: float, duration: float) -> void:
	var fade := 1.0 - time / duration
	for i in velocities.size():
		var velocity := velocities[i]
		var point := velocity * time + Vector3.DOWN * 3.0 * time * time
		var direction := (velocity + Vector3.DOWN * 6.0 * time).normalized()
		var orientation := Basis(Quaternion(Vector3.UP, direction))
		orientation = orientation.scaled(Vector3.ONE * maxf(0.05, fade))
		multimesh.set_instance_transform(i, Transform3D(orientation, point))
		var color := colors[i]
		color.a = fade
		multimesh.set_instance_color(i, color)
