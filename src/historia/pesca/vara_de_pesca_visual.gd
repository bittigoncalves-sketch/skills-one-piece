class_name VaraDePescaVisual
extends Node
# ============================================================================
#  VARA DE PESCA — o que se VÊ da pesca (03/10/2026): a vara na mão direita, a
#  linha até a boia, a boia, os respingos e o peixe saltando para a mão.
#
#  Só desenha. Quem decide estado, tempo e posição da boia é a `Pescaria`.
#
#  A vara fica presa ao `item_handle` do rig (o mesmo encaixe da fruta e da
#  espada), mas a DIREÇÃO dela é imposta a cada quadro (`orientar`) no espaço do
#  corpo: assim a leitura "vara apontada para a água" não depende do sinal de
#  cada junta do braço (docs/erros.md, 03/10 — braços invertidos na escalada).
# ============================================================================

## Modelo da loja (categoria "pesca"). A malha é comprida em +Y.
const MODELO := "fishing_rod"
const COMPRIMENTO := 1.9          # m, da ponta do cabo à ponteira
## Onde a mão pega, em fração do comprimento a partir do cabo.
const PEGA := 0.22
const RAIO_DA_BOIA := 0.07
const COR_DA_LINHA := Color(0.92, 0.92, 0.88)
const TAMANHO_DO_PEIXE := 0.55    # m, maior lado do peixe saltando
const SEGMENTOS := 18

var biblioteca: BibliotecaDeModelos

var _vara: Node3D = null
var _ponteira := Vector3.ZERO      # local da `_vara`
var _linha: MeshInstance3D
var _malha: ImmediateMesh
var _boia: Node3D


func _ready() -> void:
	_malha = ImmediateMesh.new()
	_linha = MeshInstance3D.new()
	_linha.name = "Linha"
	_linha.mesh = _malha
	_linha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COR_DA_LINHA
	_linha.material_override = mat
	add_child(_linha)
	_boia = _montar_boia()
	_boia.visible = false
	add_child(_boia)


# ------------------------------------------------------------------ vara
## Prende a vara em `mao` (null = guarda). Rig remontado → prende de novo.
func segurar_em(mao: Node3D) -> void:
	if mao == null:
		_soltar_vara()
		return
	if _vara != null and is_instance_valid(_vara) and _vara.get_parent() == mao:
		return
	_soltar_vara()
	_vara = _montar_vara()
	mao.add_child(_vara)
	_vara.position = Vector3(0, 0.08, 0.04)


func segurando() -> bool:
	return _vara != null and is_instance_valid(_vara) and _vara.is_inside_tree()


## Aponta a vara para `direcao` (mundo). `lado` = a direita do corpo (estabiliza o giro).
func orientar(direcao: Vector3, lado: Vector3) -> void:
	if not segurando() or direcao.length_squared() < 1e-6:
		return
	var y := direcao.normalized()
	var x := (lado - y * lado.dot(y))
	if x.length_squared() < 1e-6:
		x = y.cross(Vector3.FORWARD)
	x = x.normalized()
	_vara.global_basis = Basis(x, y, x.cross(y))


func ponteira() -> Vector3:
	return _vara.to_global(_ponteira) if segurando() else Vector3.ZERO


func vara() -> Node3D:
	return _vara if segurando() else null


# ------------------------------------------------------------------ linha e boia
## Linha da ponteira até `ate`. `folga` 0 = esticada, 1 = barriga funda.
func linha(ate: Vector3, folga: float) -> void:
	_malha.clear_surfaces()
	if not segurando():
		return
	var a := ponteira()
	var meio := (a + ate) * 0.5 + Vector3.DOWN * a.distance_to(ate) * 0.2 * clampf(folga, 0.0, 1.0)
	_malha.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in SEGMENTOS + 1:
		var t := float(i) / SEGMENTOS
		_malha.surface_add_vertex(a.lerp(meio, t).lerp(meio.lerp(ate, t), t))
	_malha.surface_end()


func sem_linha() -> void:
	_malha.clear_surfaces()


func boia_em(pos: Vector3) -> void:
	_boia.visible = true
	_boia.global_position = pos


func esconder_boia() -> void:
	_boia.visible = false


func boia() -> Node3D:
	return _boia


## Anel na água que abre e some (cair da boia, mordida, peixe brigando).
func respingo(pos: Vector3, forca := 1.0) -> void:
	var anel := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.09
	toro.outer_radius = 0.13
	toro.rings = 20
	toro.ring_segments = 4
	anel.mesh = toro
	anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.8)
	anel.material_override = mat
	anel.name = "Respingo"
	add_child(anel)
	anel.global_position = pos + Vector3.UP * 0.03
	anel.scale = Vector3.ONE * (0.6 + 0.4 * forca)
	var tw := anel.create_tween().set_parallel()
	tw.tween_property(anel, "scale", Vector3(1, 0.2, 1) * (3.0 + 2.0 * forca), 0.55)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(anel.queue_free)


## O peixe pego salta da água até `ate` girando, e some (0,7 s).
func peixe_saltando(id: String, de: Vector3, ate: Vector3) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "PeixeSaltando"
	var m := biblioteca.instanciar(id) if biblioteca != null and biblioteca.tem(id) else null
	if m != null:
		var e: Dictionary = biblioteca.info(id)
		var t: Vector3 = e["tamanho"]
		var k := TAMANHO_DO_PEIXE / maxf(maxf(t.x, t.y), maxf(t.z, 0.0001))
		m.scale = Vector3.ONE * k
		m.position = -(e["centro"] as Vector3) * k
		raiz.add_child(m)
	add_child(raiz)
	raiz.global_position = de
	var tw := raiz.create_tween()
	tw.tween_method(func(u: float):
		if is_instance_valid(raiz):
			raiz.global_position = de.lerp(ate, u) + Vector3.UP * sin(u * PI) * 2.2
			raiz.rotation = Vector3(u * TAU * 1.5, u * PI, 0.0), 0.0, 1.0, 0.7)
	tw.tween_callback(raiz.queue_free)
	return raiz


# ------------------------------------------------------------------ montagem
func _montar_vara() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "VaraDePesca"
	var m := biblioteca.instanciar(MODELO) if biblioteca != null and biblioteca.tem(MODELO) else null
	if m != null:
		var e: Dictionary = biblioteca.info(MODELO)
		var tam: Vector3 = e["tamanho"]
		var centro: Vector3 = e["centro"]
		var k := COMPRIMENTO / maxf(tam.y, 0.0001)
		var base_y := centro.y - tam.y * 0.5
		var pega := Vector3(centro.x, base_y + tam.y * PEGA, centro.z)
		m.scale = Vector3.ONE * k
		m.position = -pega * k
		_ponteira = (Vector3(centro.x, base_y + tam.y, centro.z) - pega) * k
		raiz.add_child(m)
	else:
		# Sem o modelo na loja: um caniço simples, para a pesca não depender dele.
		var c := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.008
		cil.bottom_radius = 0.02
		cil.height = COMPRIMENTO
		c.mesh = cil
		c.position = Vector3.UP * COMPRIMENTO * (0.5 - PEGA)
		raiz.add_child(c)
		_ponteira = Vector3.UP * COMPRIMENTO * (1.0 - PEGA)
	return raiz


func _montar_boia() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Boia"
	for metade in [[Color(0.86, 0.1, 0.08), 0.0], [Color(0.96, 0.96, 0.94), PI]]:
		var mi := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = RAIO_DA_BOIA
		esfera.height = RAIO_DA_BOIA
		esfera.is_hemisphere = true
		esfera.radial_segments = 16
		esfera.rings = 6
		mi.mesh = esfera
		var mat := StandardMaterial3D.new()
		mat.albedo_color = metade[0]
		mat.roughness = 0.5
		mi.material_override = mat
		mi.rotation.x = metade[1]
		raiz.add_child(mi)
	return raiz


func _soltar_vara() -> void:
	if _vara != null and is_instance_valid(_vara):
		if _vara.get_parent() != null:
			_vara.get_parent().remove_child(_vara)
		_vara.queue_free()
	_vara = null
