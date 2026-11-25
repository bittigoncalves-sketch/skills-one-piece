class_name SwordBlade
extends Node3D
## Sete esferas presas ao fio, varridas entre ticks no servidor. Uma passagem
## coletiva resolve todos os choques antes de qualquer dano desse tick.
## A varredura é linear por amostra; não reconstrói arcos sub-tick desconhecidos.

const Sweep = preload("res://src/combat/SwordSweep.gd")
const GRUPO := "yoru_blade_sweep"
static var _ultimo_tick := -1

const CAMADA_LAMINA := 128          # bit 8, exclusivo das bolinhas
const MASCARA_CORPOS := 15          # camadas 1-4, onde vivem corpos e cenário

const QUANTAS := 7                  # bolinhas entre a guarda e a ponta
const RAIO := 0.28

## Depuração opcional das zonas; desligada na apresentação normal.
const MOSTRAR_ZONAS := false
const COR_ZONA := Color(0.25, 0.75, 1.0, 0.22)

signal acertou(alvo: Node)
signal chocou(outra: SwordBlade)

var base := 0.4                     # onde a lâmina começa (local +Y)
var ponta := 1.8                    # a ponta

var dono: Node = null               # quem empunha
var _bolinhas: Array[Area3D] = []
var _armada := false
var _dano := 0.0
var _kb := 0.0
var _corpo_a_corpo := false
var _hitstun := 0.3
var _cast_id := 0
var _teto := 0.0
var _ja_acertou: Dictionary = {}    # um acerto por corpo POR GOLPE
var _ja_chocou := false
var _anterior: Array[Vector3] = []
var _atual: Array[Vector3] = []
var _acao_anterior := -1


func _ready() -> void:
	name = "Lamina"
	process_physics_priority = 100
	add_to_group(GRUPO)
	_criar_bolinhas()
	desarmar()


func _criar_bolinhas() -> void:
	for i in QUANTAS:
		var t := float(i) / float(maxi(QUANTAS - 1, 1))
		var bola := Area3D.new()
		bola.name = "zona_lamina_%d" % i
		bola.position = Vector3(0.0, lerpf(base, ponta, t), 0.0)
		bola.collision_layer = CAMADA_LAMINA
		bola.collision_mask = MASCARA_CORPOS | CAMADA_LAMINA
		bola.monitorable = false

		var col := CollisionShape3D.new()
		var esfera := SphereShape3D.new()
		esfera.radius = RAIO
		col.shape = esfera
		bola.add_child(col)

		# Os sinais de Area não ordenam clash/dano nem cobrem movimento entre ticks.
		bola.monitoring = false
		add_child(bola)
		_bolinhas.append(bola)

		if MOSTRAR_ZONAS:
			bola.add_child(_desenho())


func _desenho() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RAIO
	sm.height = RAIO * 2.0
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COR_ZONA
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ------------------------------------------------------------------- ligar
## Liga as bolinhas para os quadros ativos de UM golpe. O `_ja_acertou` zera
## aqui, e não no `desarmar`: é o que garante "um acerto por corpo por golpe"
## sem impedir que o próximo golpe do combo acerte o mesmo alvo de novo.
func armar(dano: float, kb: float, hitstun_dur: float, cast_id: int, teto: float, corpo_a_corpo: bool = false) -> void:
	# A mesma ação não pode ser renovada nem ressuscitar após cancelamento.
	# cast_id zero preserva o uso legado, no qual cada armar é uma ação nova.
	if cast_id != 0 and cast_id == _acao_anterior:
		return
	_dano = dano
	_kb = kb
	_corpo_a_corpo = corpo_a_corpo
	_hitstun = hitstun_dur
	_cast_id = cast_id
	_teto = teto
	_ja_acertou.clear()
	_acao_anterior = cast_id
	_ja_chocou = false
	_armada = true
	_anterior = _posicoes()
	_atual = _anterior.duplicate()


func desarmar() -> void:
	_armada = false
	_ligar_monitores(false)


func esta_armada() -> bool:
	return _armada


# ⚠️ `set_deferred`, NÃO atribuição direta. Mexer em `monitoring` durante o
# processamento de física do Godot é erro de "flushing queries"; a espada é
# armada e desarmada de dentro de temporizadores que correm justamente ali.
func _ligar_monitores(ligado: bool) -> void:
	for b in _bolinhas:
		if is_instance_valid(b):
			b.set_deferred("monitoring", false)
			b.set_deferred("monitorable", ligado)


func _autoridade() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _posicoes() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for bola in _bolinhas:
		points.append(bola.global_position)
	return points


func _excluir_dono() -> Array[RID]:
	var skip: Array[RID] = []
	if is_instance_valid(dono) and dono is CollisionObject3D:
		skip.append(dono.get_rid())
	return skip


func _origem() -> Vector3:
	return dono.global_position if is_instance_valid(dono) and dono is Node3D else global_position


func _physics_process(_delta: float) -> void:
	if not _autoridade() or _ultimo_tick == Engine.get_physics_frames():
		return
	_ultimo_tick = Engine.get_physics_frames()
	var blades: Array[SwordBlade] = []
	for node in get_tree().get_nodes_in_group(GRUPO):
		var blade := node as SwordBlade
		if is_instance_valid(blade) and not blade.is_queued_for_deletion() and blade._armada and blade._autoridade():
			blade._atual = blade._posicoes()
			blades.append(blade)
	# Primeiro, todos os pares. Nenhum take_damage pode antecipar um clash.
	for i in blades.size():
		for j in range(i + 1, blades.size()):
			blades[i]._varrer_choque(blades[j])
	for blade in blades:
		if blade._armada:
			blade._varrer_corpos()
		blade._anterior = blade._atual.duplicate()


func _varrer_choque(outra: SwordBlade) -> void:
	if not _armada or not outra._armada or dono == outra.dono:
		return
	if get_world_3d() != outra.get_world_3d():
		return
	var space := get_world_3d().direct_space_state
	var skip := _excluir_dono()
	skip.append_array(outra._excluir_dono())
	for i in _atual.size():
		for j in outra._atual.size():
			var hit := Sweep.sphere_clash(_anterior[i], _atual[i],
				outra._anterior[j], outra._atual[j], RAIO * 2.0)
			if hit.is_empty():
				continue
			var point: Vector3 = hit.position
			if Sweep.visible(space, _origem(), point, MASCARA_CORPOS, skip) and Sweep.visible(space, outra._origem(), point, MASCARA_CORPOS, skip):
				_resolver_choque(outra, point)
				return


func _varrer_corpos() -> void:
	var space := get_world_3d().direct_space_state
	var skip := _excluir_dono()
	for ponto in _atual:
		DestruicaoDeEstruturas.golpe(get_tree(), ponto, RAIO + 0.25)      # a lâmina quebra construções
	for i in _atual.size():
		for hit in Sweep.contacts(space, _anterior[i], _atual[i], RAIO, MASCARA_CORPOS, skip):
			if not _armada:
				return
			var body: Node3D = hit.body
			var point: Vector3 = hit.position
			# Também barra a lâmina que já nasceu do outro lado de uma parede.
			if Sweep.visible(space, _origem(), point, MASCARA_CORPOS, skip):
				_acertar_corpo(body, point)


# Compatibilidade para ferramentas antigas; eventos de Area não chamam isto.
func _no_corpo(corpo: Node3D, bola: Area3D) -> void:
	if _autoridade() and is_instance_valid(bola):
		_acertar_corpo(corpo, bola.global_position)


func _acertar_corpo(corpo: Node3D, onde: Vector3) -> void:
	if not _armada or not _autoridade() or not is_instance_valid(corpo):
		return
	if corpo == dono or _ja_acertou.has(corpo.get_instance_id()) or not corpo.has_method("take_damage"):
		return
	var defense = corpo.get("_yoru_combat")
	if is_instance_valid(defense) and defense.has_method("is_parrying") and defense.is_parrying(_origem()):
		# Desarma antes de callbacks: nenhum contato posterior desta ação vaza.
		desarmar()
		_cancelar_golpe_de(dono, "parried")
		if defense.has_method("on_parry"):
			defense.on_parry(dono, onde)
		_efeito_de_choque(onde)
		return
	_ja_acertou[corpo.get_instance_id()] = true
	var multiplier := 1.0
	if is_instance_valid(defense) and defense.has_method("guard_multiplier"):
		multiplier = clampf(float(defense.guard_multiplier(_origem())), 0.0, 1.0)
	var empurrao := Knockback.calcular(onde, corpo.global_position,
		_kb, Knockback.PADRAO, Vector3.ZERO)
	CombatResolver.aplicar(corpo, _dano * multiplier, _cast_id, _teto, onde,
		empurrao, _hitstun, 0.0, false, dono if _corpo_a_corpo else null, dono)
	_faiscar(onde)
	acertou.emit(corpo)
	var placar := get_tree().get_first_node_in_group("scoreboard") if get_tree() else null
	if placar and placar.has_method("register_hit"):
		placar.register_hit(corpo, dono)


func _na_area(area: Area3D, bola: Area3D) -> void:
	if not _autoridade() or not is_instance_valid(area) or not is_instance_valid(bola):
		return
	var outra := area.get_parent() as SwordBlade
	if outra != null and outra != self and outra.dono != dono:
		_resolver_choque(outra, (bola.global_position + area.global_position) * 0.5)


func _resolver_choque(outra: SwordBlade, ponto: Vector3) -> void:
	if not _autoridade() or not outra._autoridade() or not _armada or not outra._armada or _ja_chocou or outra._ja_chocou:
		return
	_ja_chocou = true
	outra._ja_chocou = true
	desarmar()
	outra.desarmar()
	_cancelar_golpe_de(dono)
	_cancelar_golpe_de(outra.dono)
	_efeito_de_choque(ponto)
	chocou.emit(outra)
	outra.chocou.emit(self)


## "anulando ambos os movimentos" — o golpe em voo dos DOIS é zerado. O
## `MeleeController.cancelar_golpe()` já existia para dash-cancel e morte: ele
## limpa `_passo_em_curso`, a trava de recuperação e o buffer de clique, que é
## exatamente o que "anular o movimento" quer dizer aqui.
func _cancelar_golpe_de(quem: Node, reason: String = "clash") -> void:
	if quem == null or not is_instance_valid(quem):
		return
	var controller = quem.get("_yoru_combat")
	if is_instance_valid(controller) and controller.has_method("cancel"):
		controller.cancel(reason)
		return
	var mc = quem.get("_melee")
	if mc != null and mc.has_method("cancelar_golpe"):
		mc.cancelar_golpe()
	if quem.has_method("lock_movement"):
		quem.lock_movement(0.0, "")


## ⚠️ ONDE PENDURAR O EFEITO. `get_tree().current_scene` é NULO num script
## rodado com `-s`, e o `BaseTest` do projeto já registra essa armadilha: "vários
## efeitos penduram nós em `current_scene`; num script -s isso é nulo e o efeito
## some sem avisar". Some sem avisar é a parte ruim — um teste que cobra o efeito
## reprova sem que haja defeito no jogo. A raiz da árvore é a reserva.
func _palco_de_efeitos() -> Node:
	var arvore := get_tree()
	if arvore == null:
		return null
	if arvore.current_scene != null and is_instance_valid(arvore.current_scene):
		return arvore.current_scene
	return arvore.root


## Fagulhas do fio mordendo. Menor que o choque de espadas de propósito: acertar
## é o caso comum e um clarão do tamanho do clash a cada corte vira sopa.
func _faiscar(ponto: Vector3) -> void:
	_contact(ponto, false)

func _efeito_de_choque(ponto: Vector3) -> void:
	_contact(ponto, true)

func _contact(ponto: Vector3, parry: bool) -> void:
	var net = dono.get("_yoru_network") if is_instance_valid(dono) else null
	if is_instance_valid(net) and net.has_method("contact"):
		net.contact(ponto, parry)
	else:
		YoruFX.impact(self, ponto, parry)
		YoruAudio.play(self, "parry" if parry else "impact")
