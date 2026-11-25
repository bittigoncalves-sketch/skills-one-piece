extends RefCounted
## Visual 3D da Luta (Z/X/C), 20/11/2026 — construído em código a partir das referências do Codex em
## `art_src/references/luta_visual/` (01 impacto leve, 02 carga em 3 níveis, 03 rajada, 04 final, 05 combate aéreo).
## Tudo é VOXEL (cubos sem sombra, material sem luz, branco/dourado) para casar com o resto do jogo, e vive poucos décimos de
## segundo. Nada aqui decide dano: é só apresentação, e funciona em qualquer direção (inclusive quase vertical, no ar).
##
## Custo: cada impacto cria até ~25 nós (força 1: 1 núcleo + 12 faíscas + 14 do anel = 27) e a rajada solta um fantasma por soco; os nós morrem sozinhos (Tween) e o dono ainda os varre
## ao cancelar. Os dois materiais são compartilhados — nenhuma alocação de material por golpe.
const DOURADO := Color(1.0, 0.78, 0.12)
const BRANCO := Color(1.0, 0.97, 0.85)
const VIDA := 0.30
const NIVEIS_DE_CARGA := 3

static var _mat_dourado: StandardMaterial3D
static var _mat_branco: StandardMaterial3D
static var _mat_rastro: StandardMaterial3D
static var _cubo: BoxMesh


static func _material(cor: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _preparar() -> void:
	if _cubo != null:
		return
	_cubo = BoxMesh.new()
	_cubo.size = Vector3.ONE
	_mat_dourado = _material(DOURADO)
	_mat_branco = _material(BRANCO)
	_mat_rastro = _material(Color(DOURADO.r, DOURADO.g, DOURADO.b, 0.38))
	_mat_rastro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


static func _no(pai: Node, onde: Vector3, tamanho: Vector3, branco: bool) -> MeshInstance3D:
	_preparar()
	var m := MeshInstance3D.new()
	m.mesh = _cubo
	m.material_override = _mat_branco if branco else _mat_dourado
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(m)
	m.global_position = onde
	m.scale = tamanho
	return m


## Dois eixos perpendiculares à direção do golpe. Para cima/baixo o UP é paralelo à direção, então usa outro vetor de referência.
static func eixos(frente: Vector3) -> Array[Vector3]:
	var ref := Vector3.UP if absf(frente.y) < 0.98 else Vector3.RIGHT
	var u := frente.cross(ref).normalized()
	var v := frente.cross(u).normalized()
	return [u, v]


static func _sumir(no: Node3D, vida: float, deslocamento := Vector3.ZERO) -> void:
	var t := no.create_tween().set_parallel(true)
	t.tween_property(no, "scale", Vector3.ZERO, vida).set_ease(Tween.EASE_IN)
	if deslocamento != Vector3.ZERO:
		t.tween_property(no, "global_position", no.global_position + deslocamento, vida).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(no.queue_free)


## O clarão do contato: núcleo que encolhe + faíscas de cubo que saem em leque (para a frente e para os lados) + anel nos golpes
## pesados. `forca` 0..1 escala tudo (soco ≈ 0,3, rajada ≈ 0,15, pesado carregado até 1, final ≈ 0,85).
static func estourar(pai: Node, onde: Vector3, frente: Vector3, forca: float) -> Array[Node3D]:
	var criados: Array[Node3D] = []
	if not is_instance_valid(pai) or not pai.is_inside_tree():
		return criados
	var e := eixos(frente)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(onde.x * 977.0 + onde.y * 331.0 + onde.z * 173.0) + Engine.get_physics_frames()
	var nucleo := _no(pai, onde, Vector3.ONE * (0.18 + 0.40 * forca), true)
	_sumir(nucleo, VIDA * 0.45)
	criados.append(nucleo)
	var n := 5 + int(round(7.0 * forca))
	for i in n:
		var ang := rng.randf() * TAU
		var radial: Vector3 = e[0] * cos(ang) + e[1] * sin(ang)
		var dir := (frente * rng.randf_range(0.2, 0.9) + radial * rng.randf_range(0.5, 1.0)).normalized()
		var lado := 0.11 + 0.07 * rng.randf() + 0.05 * forca
		var f := _no(pai, onde, Vector3(lado, lado, lado * rng.randf_range(1.6, 3.0)), i % 3 == 0)
		f.look_at(onde + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT)
		_sumir(f, VIDA * rng.randf_range(0.7, 1.0), dir * rng.randf_range(0.7, 1.3) * (0.8 + 0.9 * forca))
		criados.append(f)
	if forca >= 0.5:
		var pontos := 10 + int(round(6.0 * forca))
		for i in pontos:
			var a := TAU * float(i) / float(pontos)
			var radial: Vector3 = e[0] * cos(a) + e[1] * sin(a)
			var c := _no(pai, onde + radial * 0.25, Vector3.ONE * (0.10 + 0.08 * forca), false)
			_sumir(c, VIDA, radial * (0.7 + 0.8 * forca))
			criados.append(c)
	return criados


## O punho-fantasma (ref. 03): um PUNHO de cubo que avança ao longo do golpe, deixando duas imagens residuais e um rastro translúcido que
## some em ~0,16 s. `lado` desloca o braço que bateu (+1 direito, −1 esquerdo) no plano perpendicular ao golpe, para a alternância ficar
## legível. Devolve o RASTRO (a barra comprida, alinhada à mira); o resto é apresentação e morre sozinho.
static func fantasma(pai: Node, origem: Vector3, frente: Vector3, lado: float, alcance: float) -> Node3D:
	if not is_instance_valid(pai) or not pai.is_inside_tree():
		return null
	_preparar()
	var e := eixos(frente)
	var desloc: Vector3 = e[0] * 0.28 * lado
	var ref := Vector3.UP if absf(frente.y) < 0.98 else Vector3.RIGHT
	var centro: Vector3 = origem + desloc + frente * alcance * 0.5
	var barra := _no(pai, centro, Vector3(0.14, 0.14, alcance), false)
	barra.material_override = _mat_rastro
	barra.look_at(centro + frente, ref)
	barra.scale = Vector3(0.14, 0.14, alcance)
	var t := barra.create_tween().set_parallel(true)
	t.tween_property(barra, "scale", Vector3(0.02, 0.02, alcance * 1.2), 0.16).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(barra.queue_free)
	for fracao in [0.3, 0.55]:                                   # imagens residuais do punho
		var res := _no(pai, origem + desloc + frente * alcance * fracao, Vector3.ONE * 0.26, false)
		res.material_override = _mat_rastro
		_sumir(res, 0.14)
	var punho := _no(pai, origem + desloc + frente * alcance * 0.35, Vector3.ONE * 0.32, true)
	var tp := punho.create_tween()
	tp.tween_property(punho, "global_position", origem + desloc + frente * alcance * 0.95, 0.07).set_ease(Tween.EASE_OUT)
	tp.tween_property(punho, "scale", Vector3.ZERO, 0.10)
	tp.tween_callback(punho.queue_free)
	return barra


## Nível discreto de carga (0..3) para o X: cada terço do teto acende mais a aura (ref. 02).
## Nível 1 ao começar a carregar, 2 a partir de 34 % e 3 a partir de 67 % do teto — o 3º nível dura ~0,4 s e dá para ler antes do golpe.
static func nivel_de_carga(carga: int, maximo: int) -> int:
	if carga <= 0:
		return 0
	var f := float(carga) / float(maximo)
	return 1 + (1 if f >= 0.34 else 0) + (1 if f >= 0.67 else 0)


## A aura do punho enquanto o X carrega: um cubo que cresce e clareia por nível, mais um anel girando a partir do nível 2.
## Devolve o nó (o dono guarda e chama `liberar_aura`); chamar de novo com o mesmo nó só o reposiciona e o reescala.
static func aura(pai: Node, existente: Node3D, onde: Vector3, frente: Vector3, nivel: int, tempo: float) -> Node3D:
	if not is_instance_valid(pai) or not pai.is_inside_tree():
		return null
	var no := existente
	if not is_instance_valid(no):
		no = _no(pai, onde, Vector3.ONE * 0.1, false)
	no.global_position = onde
	var lado := 0.22 + 0.16 * float(nivel) + 0.03 * sin(tempo * 28.0)
	no.scale = Vector3.ONE * lado
	no.rotation = Vector3(tempo * 3.0, tempo * 4.0, 0.0)
	no.material_override = _mat_branco if nivel >= 2 else _mat_dourado
	# Anel de satélites girando em volta do núcleo: 4 no nível 2, 8 no nível 3.
	var satelites := 0 if nivel < 2 else (4 if nivel == 2 else 8)
	while no.get_child_count() < satelites:
		var i := no.get_child_count()
		var m := MeshInstance3D.new()
		m.mesh = _cubo
		m.material_override = _mat_dourado
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(m)
		var a := TAU * float(i % 4) / 4.0 + (TAU / 8.0 if i >= 4 else 0.0)      # o 2º grupo de 4 fica a 45° do 1º
		m.position = Vector3(cos(a), sin(a), 0.0) * 1.5
		m.scale = Vector3.ONE * 0.28
	return no


static func liberar_aura(no: Node3D) -> void:
	if is_instance_valid(no):
		no.queue_free()
