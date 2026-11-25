extends Node3D
## O INDICADOR DE MIRA da fruta (23/09/2026). Enquanto a tecla está pressionada, mostra
## ONDE o golpe vai cair: linha no Z, os três pontos do bombardeio no X, o ponto de queda
## no C. O F não tem alvo, então não desenha nada.
##
## Duas regras que valem sempre:
##   1. **Só no corpo de quem joga.** Nada aqui é replicado; é leitura de câmera local.
##      Desenhar a mira dos outros entregaria de graça para onde cada um vai atirar.
##   2. **A conta é a MESMA do golpe** (`MiraDeRocket`, usada pelo `rocket_controller`).
##      Enquanto o golpe já está saindo, a direção vem TRAVADA do controlador — depois do
##      pedido a mira não manda mais, e mostrar a câmera de agora seria mentira.
const MIRA := preload("res://src/combat/mira_de_rocket.gd")
const RVFX := preload("res://src/effects/rocket_vfx.gd")
const ANEIS := 3

var dono: Node3D
var _slot := ""
var _linha: MeshInstance3D
var _aneis: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _tempo := 0.0


func _ready() -> void:
	top_level = true # posições em espaço de mundo: o corpo gira, a mira não roda junto
	_mat = FxUtil.mesh_emissive_material(RVFX.CREME, 1.8)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(RVFX.CREME, 0.55)
	var haste := CylinderMesh.new()
	haste.top_radius = 0.025
	haste.bottom_radius = 0.025
	haste.height = 1.0
	haste.radial_segments = 8
	_linha = MeshInstance3D.new()
	_linha.mesh = haste
	_linha.material_override = _mat
	_linha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_linha)
	var aro := TorusMesh.new()
	aro.inner_radius = 0.88
	aro.outer_radius = 1.0
	aro.rings = 24
	aro.ring_segments = 6
	for _i in ANEIS:
		var m := MeshInstance3D.new()
		m.mesh = aro
		m.material_override = _mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_aneis.append(m)
	visible = false


func mostrar(slot: String) -> void:
	_slot = slot
	_tempo = 0.0
	visible = true
	_desenhar()


func esconder() -> void:
	_slot = ""
	visible = false


func mostrando() -> String:
	return _slot


func _process(delta: float) -> void:
	if _slot == "":
		return
	_tempo += delta
	_desenhar()


func _desenhar() -> void:
	var ficha := _ficha()
	if ficha == null or not is_instance_valid(dono):
		esconder()
		return
	# Espelho da mira do `CastController`: ele é o dono da verdade e a larga sozinho
	# quando o corpo perde a condição. Sem isto, morrer segurando a tecla deixava o
	# indicador aceso no corpo caído.
	var cast = dono.get("_cast")
	if cast != null and cast.has_method("mirando") and cast.mirando() != _slot:
		esconder()
		return
	var rocket: Node = dono.get("_rocket")
	var direcao: Vector3 = Vector3.FORWARD
	var pe: Vector3 = dono.global_position
	if is_instance_valid(rocket) and rocket.ocupado():
		# Golpe já pedido: a direção está travada no controlador.
		direcao = rocket.direcao
		pe = rocket.posicao
	elif dono.has_method("mira_do_cast"):
		direcao = dono.mira_do_cast().aim
	# ⚠️ A ORIGEM é a do controlador (pé + 1,2 m), não a de `mira_do_cast` (que sai 1,5 m
	# à frente do corpo). Com a origem errada o anel cai mais de 1 m fora do buraco.
	var origem: Vector3 = pe + Vector3.UP * 1.2
	var mundo: World3D = dono.get_world_3d()
	var fora: Array[RID] = [dono.get_rid()]
	# Pisca devagar: presente sem competir com o que está acontecendo na tela.
	_mat.albedo_color = Color(RVFX.CREME, 0.40 + 0.22 * sin(_tempo * 6.0))
	_linha.visible = false
	for m in _aneis:
		m.visible = false
	match ficha.comportamento:
		"missil":
			var fim := MIRA.fim_do_missil(mundo, origem, direcao, ficha.alcance, fora)
			_tracar(origem, fim)
			_anel(0, fim, ficha.raio * 0.8, direcao)
		"bombardeio":
			var pontos := MIRA.pontos_do_bombardeio(mundo, pe, direcao,
					ficha.raio, ANEIS, fora)
			for i in pontos.size():
				_anel(i, pontos[i], ficha.raio, Vector3.UP)
		"mergulho":
			var ponto := MIRA.ponto_mirado(mundo, origem, direcao, ficha.alcance, fora)
			_anel(0, ponto, ficha.raio, Vector3.UP)
		_:
			# O voo não tem alvo no chão: nada a mostrar.
			visible = false


func _ficha() -> TecnicaDeFruta:
	if not is_instance_valid(dono):
		return null
	var perfil: PerfilDeFrutas = dono.get("perfil_de_frutas")
	return perfil.tecnica(_slot) if perfil != null else null


func _tracar(de: Vector3, ate: Vector3) -> void:
	var caminho := ate - de
	if caminho.length_squared() < 0.01:
		return
	_linha.global_position = (de + ate) * 0.5
	_linha.global_basis = Basis(Quaternion(Vector3.UP, caminho.normalized())) \
			.scaled(Vector3(1.0, caminho.length(), 1.0))
	_linha.visible = true


func _anel(i: int, at: Vector3, raio: float, normal: Vector3) -> void:
	if i >= _aneis.size():
		return
	var cima := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var eixo := Vector3.RIGHT if absf(cima.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := eixo.cross(cima).normalized()
	var m := _aneis[i]
	m.global_position = at + cima * 0.04
	m.global_basis = Basis(cima.cross(z), cima, z).scaled(Vector3.ONE * maxf(0.2, raio))
	m.visible = true
