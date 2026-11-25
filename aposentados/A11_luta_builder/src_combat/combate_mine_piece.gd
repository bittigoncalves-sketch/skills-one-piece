extends ExecutorDeSkill
## Adaptação própria das três técnicas desarmadas do Mine Piece v14.
## Recursos originais convertidos por tools/mine_piece/importar_combate.py.
## Usa a mesma fábrica/RPC do Builder; o dano continua exclusivo do servidor.
const PASTA := "res://assets/mine_piece/combate/"
const META := "combate_mine_piece"
const PRIMEIRO_SOCO := 0.0833
const PREPARO_PESADO := 0.35
const CARGA_MAXIMA := 1.25
## Mãos vazias, tamanho base ≈ 1: centro 2,5 blocos à frente, AABB de lado 6.
const CENTRO_DO_GOLPE := 2.5
const LADO_DA_AREA := 6.0
const INICIO_RAJADA := 0.55
const INTERVALO_RAJADA := 0.1
const MINIMO_RAJADA := 1.25
const MAXIMO_RAJADA := 2.55
static var _clipes: Dictionary = {}
static var _impacto: PackedScene
var _slot := ""
var _soltou := false
var _final_em := -1.0
var _proximo := INICIO_RAJADA
var _acertou := false
var _quantidade := 0
var _vida_anterior := INF
var _efeitos: Array[Dictionary] = []
var _pose_inicio := 0.0
var _lado := "right"
var _encerrou := false


func _ready() -> void:
	_slot = str(skill.ativacao.tecla)
	# Uma ação por corpo, inclusive quando dois pedidos chegam no mesmo tick.
	for outro in get_tree().get_nodes_in_group(META):
		if outro != self and outro.ator == ator:
			outro.cancelar()
	add_to_group(META)
	ator.set_meta(META, get_instance_id())
	_vida_anterior = float(ator.get("health")) if ator.get("health") != null else INF
	if _clipes.is_empty():
		_clipes = JSON.parse_string(FileAccess.get_file_as_string(PASTA + "poses.json"))
	if _impacto == null:
		_impacto = load(PASTA + "mp_impacto.glb") as PackedScene
	var executor := ator.get_node_or_null("CombateDirecional")
	if executor != null:
		executor.cancelar(&"tecnica_mine_piece")


func soltar() -> String:
	_soltou = true
	segurando = false
	return "soltou"


func _physics_process(delta: float) -> void:
	if _encerrou:
		return
	if not is_instance_valid(ator) or _interrompido():
		cancelar()
		return
	_t += delta * Lentidao.fator(ator)
	_atualizar_efeitos(delta)
	if _slot == "C":
		if _final_em < 0 and (_t >= MAXIMO_RAJADA or (_soltou and _t >= MINIMO_RAJADA)):
			_final_em = minf(_t, MAXIMO_RAJADA)
			_pose_inicio = _final_em
			_lado = "right"
		while _final_em < 0 and _t >= _proximo:
			_lado = "right" if _quantidade % 2 == 0 else "left"
			_pose_inicio = _proximo - PRIMEIRO_SOCO
			_golpear("rajada", "idle1" if _quantidade % 2 == 0 else "idle2")
			_quantidade += 1
			_proximo += INTERVALO_RAJADA
		if _final_em >= 0 and not _acertou and _t >= _final_em + PRIMEIRO_SOCO:
			_acertou = true
			_golpear("final", "idle3")
		if _final_em >= 0 and _t >= _final_em + 0.5:
			_encerrar()
			return
	else:
		if _slot == "X" and not _soltou and _t >= 0.3 and _segurado < CARGA_MAXIMA:
			_segurado = minf(_segurado + delta, CARGA_MAXIMA)
			_pose_inicio = _t
			_aplicar_pose()
			return
		var preparo := PREPARO_PESADO + _segurado if _slot == "X" else 0.0
		_pose_inicio = preparo
		if not _acertou and _t >= preparo + PRIMEIRO_SOCO:
			_acertou = true
			_golpear("pesado" if _slot == "X" else "soco", "idle3")
		if _t >= preparo + 0.5:
			_encerrar()
			return
	_aplicar_pose()


func _interrompido() -> bool:
	if ator.get("health") != null and (float(ator.get("health")) <= 0 or float(ator.get("health")) < _vida_anterior):
		return true
	if ator.get("current_fruit_id") != null and str(ator.get("current_fruit_id")) != KitDoBuilder.ID_ESTILO_BASE:
		return true
	return float(ator.get_meta("_dano_pose_t", 0.0)) > 0.0 or bool(ator.get_meta("is_frozen", false))


func _aplicar_pose() -> void:
	var clipe: Dictionary = _clipes["punch_" + _lado]
	var tempo := clampf(_t - _pose_inicio, 0.0, float(clipe.duracao))
	var quadros: Array = clipe.quadros
	var frame := minf(tempo * float(clipe.fps), quadros.size() - 1)
	var a: Dictionary = quadros[int(frame)]
	var b: Dictionary = quadros[mini(int(frame) + 1, quadros.size() - 1)]
	var pose := {}
	var peso := 1.0 - smoothstep(0.25, 0.5, tempo)
	for papel in a:
		var va: Array = a[papel]
		var vb: Array = b[papel]
		pose[papel] = Vector3(float(va[0]), float(va[1]), float(va[2])).lerp(
			Vector3(float(vb[0]), float(vb[1]), float(vb[2])), fmod(frame, 1.0)) * PI / 180.0 * peso
	ator.set_meta(META_POSE, pose)
	var posicoes := {}
	var pa: Dictionary = clipe.posicoes[int(frame)]
	var pb: Dictionary = clipe.posicoes[mini(int(frame) + 1, clipe.posicoes.size() - 1)]
	for papel in pa:
		var va: Array = pa[papel]
		var vb: Array = pb[papel]
		posicoes[papel] = Vector3(float(va[0]), float(va[1]), float(va[2])).lerp(
			Vector3(float(vb[0]), float(vb[1]), float(vb[2])), fmod(frame, 1.0)) * peso
	ator.set_meta("posicoes_mine_piece", posicoes)


func _golpear(tipo: String, animacao: String) -> void:
	var dados: Dictionary = Balance.MINE_PIECE_LUTA[tipo]
	var frente := -_base.z
	var origem := pe() + Vector3.UP * 1.3
	var centro := origem + frente * CENTRO_DO_GOLPE
	# A área não pode nascer atrás de uma parede entre o corpo e o impacto.
	var ray := PhysicsRayQueryParameters3D.create(origem, centro)
	ray.collision_mask = 1
	if ator is CollisionObject3D:
		ray.exclude = [ator.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and not hit.collider.has_method("take_damage"):
		_efeito(hit.position, animacao)
		return
	_efeito(centro, animacao)
	if tipo == "final":
		# O golpe final lança: quem estava paralisado pela rajada tem de poder ser empurrado.
		for alvo in AlvosDeGolpe.todos(get_tree()):
			if alvo != ator and alvo is Node3D and (alvo as Node3D).global_position.distance_to(centro) <= LADO_DA_AREA:
				ImobilizacaoMinePiece.liberar(alvo)
	var zona := DamageZone.new()
	add_child(zona)
	zona.global_position = centro
	var carga := 1.0 + 0.5 * _segurado / CARGA_MAXIMA if tipo == "pesado" else 1.0
	var forma := BoxShape3D.new()
	forma.size = Vector3.ONE * LADO_DA_AREA
	zona.setup(float(dados.dano) * escala_de_dano * carga, float(dados.empurrao) * carga, Vector3.ZERO,
		0.065, ator, 0.0, forma, float(dados.stun))
	zona.cast_id = CombatResolver.novo_cast() # cada soco pode acertar uma vez
	zona.corpo_a_corpo = true
	zona.override_kb_dir = frente
	zona.exige_linha_de_visao = true
	zona.origem_linha_de_visao = origem
	zona.feedback_global = false
	var paralisia := float(dados.get("paralisia", 0.0))
	zona.hit_landed.connect(func(atingido: Node):
		if paralisia > 0.0:
			ImobilizacaoMinePiece.aplicar(atingido, paralisia)
		if multiplayer.has_multiplayer_peer(): _som.rpc(tipo, centro)
		else: _som(tipo, centro))


func _efeito(onde: Vector3, animacao: String) -> void:
	if _impacto == null:
		return
	var visual := _impacto.instantiate() as Node3D
	add_child(visual)
	visual.global_position = onde
	visual.basis = _base
	visual.scale = Vector3.ONE * 2.0
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if DisplayServer.get_name() == "headless": continue
		for i in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(i) as BaseMaterial3D
			if material != null:
				material = material.duplicate()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(i, material)
	var player := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player != null and player.has_animation(animacao):
		player.play(animacao)
		player.advance(0)
	_efeitos.append({"no": visual, "idade": 0.0})


@rpc("authority", "call_local", "unreliable")
func _som(tipo: String, onde: Vector3) -> void:
	var som := AudioStreamPlayer3D.new()
	som.stream = load(PASTA + ("hit_strong.ogg" if tipo in ["pesado", "final"] else "punch_hit1.ogg"))
	som.volume_db = -14.0
	add_child(som)
	som.global_position = onde
	som.finished.connect(som.queue_free)
	som.play()


func _atualizar_efeitos(delta: float) -> void:
	for i in range(_efeitos.size() - 1, -1, -1):
		_efeitos[i].idade += delta
		if _efeitos[i].idade >= 0.3:
			if is_instance_valid(_efeitos[i].no): _efeitos[i].no.queue_free()
			_efeitos.remove_at(i)


func _encerrar() -> void:
	if _encerrou: return
	_encerrou = true
	_limpar_pose()
	super._encerrar()


func _exit_tree() -> void:
	_limpar_pose()


func _limpar_pose() -> void:
	if is_instance_valid(ator) and int(ator.get_meta(META, 0)) == get_instance_id():
		ator.remove_meta(META)
		ator.remove_meta(META_POSE)
		if ator.has_meta("posicoes_mine_piece"): ator.remove_meta("posicoes_mine_piece")
