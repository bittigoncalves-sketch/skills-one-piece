extends SceneTree
## Regressão: o arremesso inativo apagava a inclinação da parede e colocava
## a raiz visual em Y=0 (o rig nasce em aproximadamente -0,81 m).
## Mede o ciclo real por teclas no Modo História e o ciclo de posse da pose.
##
## 03/10/2026: o "andar na superfície" foi removido (fatia 2 de
## docs/PARKOUR_MIRRORS_EDGE_PLANO.md). O ciclo agora é o WALL RUN novo — correr
## rente à parede, Espaço entra (corpo inclina para longe dela), Espaço salta para
## longe — e o critério é o mesmo: a inclinação aparece e, depois de pousar, o
## corpo volta EXATAMENTE ao repouso, sem deslocamento acumulado entre ciclos.
const DT := 1.0 / 60.0
var _falhas := 0
var _classe: GDScript

func _init() -> void:
	await process_frame
	_classe = load("res://src/player/player_arremesso.gd")
	_contrato_da_pose()
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_pouso_parede.json")
	get_root().get_node("GameFlow").start_story()
	await _quadros(120)
	var p = get_first_node_in_group("player")
	_ok(p != null, "jogador do Modo História presente")
	if p == null:
		quit(1)
		return
	var parede := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(30, 30, 1)
	col.shape = caixa
	parede.add_child(col)
	current_scene.add_child(parede)
	parede.position = Vector3(0, 15, -5)
	var repouso: Vector3 = p._char_model.position
	var escala: Vector3 = p._char_model.scale
	# Parede no plano z = −4,5 (normal +Z). Corre em +X a 0,6 m dela: parede à
	# ESQUERDA de quem corre.
	for ciclo in 3:
		p.global_position = Vector3(-8, 0.81, -3.9)
		p.velocity = Vector3.ZERO
		p._yaw = -PI / 2.0
		await _quadros(60)
		_ok(p.is_on_floor(), "ciclo %d: começa apoiado no chão" % ciclo)
		_tecla(KEY_W, true)
		await _quadros(30)
		await _espaco()
		await _quadros(10)
		var na_parede: bool = p._parkour.correndo_na_parede()
		_ok(na_parede and p._parkour.parede.lado == -1,
			"ciclo %d: entrou no wall run com a parede à esquerda" % ciclo)
		var cima: Vector3 = p._char_model.global_basis.y.normalized()
		_ok(cima.dot(Vector3.BACK) > sin(deg_to_rad(15.0)),
			"ciclo %d: corpo inclinado para longe da parede (%.0f°)" % [ciclo, rad_to_deg(asin(clampf(cima.dot(Vector3.BACK), -1.0, 1.0)))])
		await _espaco()
		_ok(not p._parkour.correndo_na_parede() and p.velocity.z > 3.0,
			"ciclo %d: saltou para longe da parede (vz %.1f m/s)" % [ciclo, p.velocity.z])
		_tecla(KEY_W, false)
		await _quadros(180)
		var pe := minf(_min_y(p._char_model.find_child("Foot_L", true, false)),
			_min_y(p._char_model.find_child("Foot_R", true, false)))
		print("POUSO %d: raiz=%s pé-chão=%.5f m" % [ciclo, p._char_model.position, pe])
		_ok(p.is_on_floor() and not p._inclinado_na_parede,
			"ciclo %d: pousou e o corpo endireitou" % ciclo)
		_ok(p._char_model.position.distance_to(repouso) < 0.001 and absf(pe) < 0.04,
			"ciclo %d: pés voltam ao piso sem deslocamento acumulado" % ciclo)
		_ok(p._char_model.scale.distance_to(escala) < 0.001,
			"ciclo %d: escala preservada" % ciclo)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("POUSO PAREDE: %d falhas" % _falhas)
	quit(1 if _falhas else 0)

func _contrato_da_pose() -> void:
	var controle = _classe.new()
	var corpo := CharacterBody3D.new()
	var modelo := Node3D.new()
	root.add_child(corpo)
	corpo.add_child(modelo)
	modelo.position = Vector3(0.03, -0.81, 0.02)
	modelo.rotation = Vector3(PI / 2.0, 0.3, 0.1)
	var alheia := modelo.transform
	controle.apresentar(modelo, DT)
	_ok(modelo.transform.is_equal_approx(alheia), "inativo preserva posição e inclinação alheias")
	controle.cancelar(modelo)
	_ok(modelo.transform.is_equal_approx(alheia), "cancelar sem arremesso também preserva a pose")
	modelo.rotation = Vector3.ZERO
	controle.iniciar(corpo, Vector3(0, 6, 8), false, modelo)
	var deitou := false
	var levantou := false
	for i in 240:
		controle.tick_remoto(DT, i > 35)
		controle.apresentar(modelo, DT)
		deitou = deitou or modelo.rotation.x > 1.4
		levantou = levantou or controle.fase == "getup"
	_ok(deitou and levantou and not controle.ativo(), "arremesso continua deitando e levantando")
	_ok(absf(modelo.position.y + 0.81) < 0.00001 and modelo.rotation.x == 0.0,
		"fim do arremesso restaura exatamente o repouso")
	modelo.position.y = -0.93
	modelo.rotation.x = -0.7
	alheia = modelo.transform
	controle.apresentar(modelo, DT)
	controle.cancelar(modelo)
	_ok(modelo.transform.is_equal_approx(alheia), "arremesso terminado devolve controle ao parkour")
	controle.iniciar(corpo, Vector3(0, 6, 8), false, modelo)
	controle.apresentar(modelo, DT)
	# Outra animação pode zerar X antes do cancelamento: Y ainda precisa voltar.
	modelo.rotation.x = 0.0
	modelo.position.y = 0.25
	controle.cancelar(modelo)
	_ok(absf(modelo.position.y + 0.93) < 0.00001, "cancelamento restaura Y mesmo com X já zerado")
	corpo.free()

func _quadros(n: int) -> void:
	for i in n: await physics_frame

func _espaco() -> void:
	_tecla(KEY_SPACE, true)
	await _quadros(4)
	_tecla(KEY_SPACE, false)

func _tecla(k: int, pressionada: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = pressionada
	Input.parse_input_event(e)

func _min_y(n: Node) -> float:
	var y := INF
	if n is MeshInstance3D:
		for i in 8:
			y = minf(y, (n.global_transform * n.get_aabb().get_endpoint(i)).y)
	for filho in n.get_children(): y = minf(y, _min_y(filho))
	return y

func _ok(condicao: bool, descricao: String) -> void:
	print(("  OK  " if condicao else "  XX  ") + descricao)
	if not condicao: _falhas += 1
