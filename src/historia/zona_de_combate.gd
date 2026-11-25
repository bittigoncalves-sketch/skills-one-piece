class_name ZonaDeCombate
extends Node
## ZONA DE COMBATE (10/11/2026, pedido do dono: "limitar a distância de renderização quando em combate, e o spawn e o comportamento das
## criaturas fora da zona de combate"). O jogador está EM COMBATE quando levou dano há pouco, há uma raid em andamento ou um inimigo
## está em combate com ele por perto; sai 8 s depois do último motivo (histerese). Enquanto em combate:
##  • DESENHO — a ilha só é desenhada por inteiro até `PERTO_EM_COMBATE` m (o normal é 400) e a câmera enxerga até `CAMERA_EM_COMBATE` m;
##  • CRIATURAS fora do raio da zona (`RAIO`, com folga) ficam LATENTES (`Povoamento`): somem, não colidem, não processam — logo não têm
##    IA nem renascem/spawnam; voltam ao entrar na zona ou quando o combate acaba (soltas em lotes, sem engasgo).
## Nunca suspende: chefes, inimigos de raid, criaturas invocadas/aliadas do jogador, pets e quem está em combate.
## Não destrói nada (o estado fica guardado) e não mexe na latência por ilha: criatura já latente por outro motivo é deixada em paz.
## GATILHOS: ajustar `RAIO`/`PERTO_EM_COMBATE` se a luta pedir mais alcance; migrar a latência por ilha para cá se um dia houver mais regras.

const LodDasIlhas := preload("res://src/historia/ilhas/lod_das_ilhas.gd")
const RAIO := 90.0
const FOLGA := 15.0
const SAIR_APOS := 8.0
const INTERVALO := 0.5
const PERTO_EM_COMBATE := 150.0
const CAMERA_EM_COMBATE := 300.0
const SOLTAS_POR_QUADRO := 4
const GRUPOS := ["enemy", "animais", "bestas_do_mar"]
const META_SUSPENSA := "suspensa_por_combate"

var jogador_de: Callable
var raid: Node = null
var lod: Node = null          # `lod_das_ilhas.gd` (tem `perto_ate`)
var em_combate := false
var _fim := 0.0
var _relogio := 0.0
var _suspensas: Array = []            # criaturas que ESTA zona deixou latentes
var _soltar: Array = []               # fila de liberação ao sair do combate
var _camera_far := 0.0
var _camera: Camera3D = null


func _process(delta: float) -> void:
	for _i in SOLTAS_POR_QUADRO:
		if _soltar.is_empty():
			break
		_liberar(_soltar.pop_front())
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = INTERVALO
	atualizar()


func atualizar() -> void:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or not is_instance_valid(j):
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if _motivo_de_combate(j):
		_fim = agora + SAIR_APOS
	var novo := agora < _fim
	if novo != em_combate:
		em_combate = novo
		_aplicar_desenho(novo)
		if not novo:
			_soltar.append_array(_suspensas)
			_suspensas.clear()
	if em_combate:
		_suspender_e_soltar(j.global_position)


func _motivo_de_combate(j: Node3D) -> bool:
	if j.has_method("em_combate") and bool(j.em_combate()):
		return true
	if raid != null and bool(raid.get("ativa")):
		return true
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and is_instance_valid(e) and e.has_method("em_combate") and bool(e.em_combate()) \
				and (e as Node3D).global_position.distance_to(j.global_position) <= RAIO:
			return true
	return false


## Quem a zona NÃO suspende.
static func e_intocavel(no: Node) -> bool:
	return no.is_in_group(BarrasDeChefes.GRUPO) or no.is_in_group("invocados_do_jogador") or no.is_in_group("invocados_do_mod") \
		or no.is_in_group("pets_historia") or no.has_meta("raider") or Povoamento.esta_latente(no) \
		or (no.has_method("em_combate") and bool(no.em_combate()))


func _suspender_e_soltar(centro: Vector3) -> void:
	var vistos := {}
	for g in GRUPOS:
		for no in get_tree().get_nodes_in_group(g):
			if vistos.has(no) or not (no is Node3D) or not is_instance_valid(no):
				continue
			vistos[no] = true
			if e_intocavel(no):
				continue
			if (no as Node3D).global_position.distance_to(centro) > RAIO + FOLGA:
				Povoamento.latente(no, true)
				no.set_meta(META_SUSPENSA, true)
				_suspensas.append(no)
	# quem voltou para dentro do raio acorda
	var dentro: Array = []
	for no in _suspensas:
		if not is_instance_valid(no) or (no as Node3D).global_position.distance_to(centro) <= RAIO - FOLGA:
			dentro.append(no)
	for no in dentro:
		_suspensas.erase(no)
		_soltar.append(no)


func _liberar(no: Node) -> void:
	if is_instance_valid(no) and no.has_meta(META_SUSPENSA):
		no.remove_meta(META_SUSPENSA)
		Povoamento.latente(no, false)


func _aplicar_desenho(combate: bool) -> void:
	if lod != null:
		lod.perto_ate = PERTO_EM_COMBATE if combate else LodDasIlhas.PERTO_ATE
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if combate:
		if cam != null and _camera == null:
			_camera = cam
			_camera_far = cam.far
			cam.far = minf(cam.far, CAMERA_EM_COMBATE)
	elif _camera != null:
		if is_instance_valid(_camera):
			_camera.far = _camera_far
		_camera = null
