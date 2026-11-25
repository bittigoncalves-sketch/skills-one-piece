extends SceneTree
## Povoamento por ilha + IA unificada (10/11/2026), no MAPA REAL com carga por distância (`carregar_tudo_forcado = 0`).
const SAVE := "user://test_povoamento_progresso.json"
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()

func _por_ilha(caixas: Dictionary) -> Dictionary:
	var out := {}
	for n in get_nodes_in_group("enemy"):
		if n is Node3D:
			var ilha := Ilhas.ilha_em(caixas, (n as Node3D).global_position, 120.0)
			out[ilha] = int(out.get(ilha, 0)) + 1
	return out

func rodar() -> void:
	await process_frame
	# ---- Povoamento, unidade
	var corpo := CharacterBody3D.new()
	var filho := StaticBody3D.new()
	corpo.add_child(filho)
	root.add_child(corpo)
	corpo.add_to_group("enemy")
	corpo.collision_layer = 4
	filho.collision_layer = 2
	Povoamento.latente(corpo, true)
	ok(Povoamento.esta_latente(corpo) and not corpo.is_in_group("enemy") and corpo.collision_layer == 0 and filho.collision_layer == 0 and not corpo.visible and corpo.process_mode == Node.PROCESS_MODE_DISABLED, "latente: sem grupo, sem colisão, invisível, parado")
	Povoamento.latente(corpo, true)
	Povoamento.latente(corpo, false)
	ok(not Povoamento.esta_latente(corpo) and corpo.is_in_group("enemy") and corpo.collision_layer == 4 and filho.collision_layer == 2 and corpo.visible and corpo.process_mode == Node.PROCESS_MODE_INHERIT, "acordar devolve grupo, colisão, visibilidade e modo")
	corpo.queue_free()
	# ---- mapa real, distância
	var Modo = load("res://src/historia/ModoHistoria.gd")
	Modo.set("progresso_forcado", SAVE)
	Modo.set("carregar_tudo_forcado", 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(400)
	var m = current_scene
	var j: Node3D = get_first_node_in_group("player")
	var caixas: Dictionary = m.get("_streaming").caixas
	var povoada: String = m.ilha_povoada()
	print("  ilha povoada: '", povoada, "'  ilhas montadas: ", caixas.size())
	ok(not povoada.is_empty(), "o detector marcou a ilha do jogador como povoada")
	var inicio := _por_ilha(caixas)
	print("  inimigos ativos por ilha: ", inicio)
	ok(inicio.keys().all(func(k): return k == povoada or k == ""), "só a ilha do jogador tem inimigos ativos")
	var ativos0 := get_nodes_in_group("enemy").size()
	# ---- IA unificada: dormentes longe
	var ia: IaDosInimigos = m.get("_ia_inimigos")
	ia.varrer(0.5)
	var longe := 0
	var perto_dormindo := 0
	for n in get_nodes_in_group("enemy"):
		if IaDosInimigos.gerenciavel(n):
			var d := (n as Node3D).global_position.distance_to(j.global_position)
			if d > ia.raios("").y and not IaUnificada.dormindo(n) and not n.get_meta(IaUnificada.META_ATE, 0) > Time.get_ticks_msec():
				longe += 1
			if d < ia.raios("").x and IaUnificada.dormindo(n):
				perto_dormindo += 1
	ok(longe == 0, "nenhum inimigo gerenciável longe fica acordado (%d)" % longe)
	ok(perto_dormindo == 0, "ninguém perto do jogador dorme (%d)" % perto_dormindo)
	print("  dormentes: ", ia.dormentes, " de ", ativos0, " inimigos ativos")
	# IA dos animais: separada da dos inimigos, por locomoção
	var ani: IaDosAnimais = m.get("_ia_animais")
	ani.varrer(0.5)
	var por_loc := {}
	var dormindo_loc := {}
	for a in get_nodes_in_group("animais") + get_nodes_in_group("bestas_do_mar"):
		if ani.e_gerenciavel(a):
			var k := IaDosAnimais.locomocao_de(a)
			por_loc[k] = int(por_loc.get(k, 0)) + 1
			if IaUnificada.dormindo(a): dormindo_loc[k] = int(dormindo_loc.get(k, 0)) + 1
	print("  animais gerenciados por locomoção: ", por_loc, "  dormindo: ", dormindo_loc)
	var animal_longe_acordado := 0
	for a in get_nodes_in_group("animais") + get_nodes_in_group("bestas_do_mar"):
		if ani.e_gerenciavel(a) and not IaUnificada.dormindo(a) and (a as Node3D).global_position.distance_to(j.global_position) > ani.raios(IaDosAnimais.locomocao_de(a)).y and not a.get_meta(IaUnificada.META_ATE, 0) > Time.get_ticks_msec():
			animal_longe_acordado += 1
	ok(animal_longe_acordado == 0, "nenhum animal além do raio da locomoção dele fica acordado (%d)" % animal_longe_acordado)
	# chefe nunca dorme
	var chefes_dormindo := 0
	for n in get_nodes_in_group("chefes"):
		if IaUnificada.dormindo(n): chefes_dormindo += 1
	ok(chefes_dormindo == 0, "chefes nunca dormem")
	# acordar ao chegar perto e por dano
	var alvo: Node3D = null
	for n in get_nodes_in_group("enemy"):
		if IaDosInimigos.gerenciavel(n) and IaUnificada.dormindo(n):
			alvo = n
			break
	if alvo != null:
		var onde := j.global_position
		j.global_position = alvo.global_position + Vector3(8, 2, 0)
		ia.varrer(0.5)
		ok(not IaUnificada.dormindo(alvo), "chegar a menos de 60 m acorda")
		j.global_position = onde
		IaUnificada.dormir(alvo)
		ok(IaUnificada.dormindo(alvo) and not alvo.is_physics_processing(), "dormir para o corpo")
		alvo.take_damage(1.0, j.global_position)
		ok(not IaUnificada.dormindo(alvo), "levar dano acorda")
	else:
		print("  (nenhum inimigo dormente para testar o despertar)")
	# ---- troca de ilha
	var outra := ""
	for id in caixas:
		if id != povoada:
			outra = id
			break
	if outra != "":
		await m.garantir_ilha(outra)
		var r: Rect2 = caixas[outra]
		j.global_position = Vector3(r.get_center().x, 6.0, r.get_center().y)
		await quadros(120)
		ok(m.ilha_povoada() == outra, "ao chegar noutra ilha, ela vira a povoada (%s)" % m.ilha_povoada())
		var depois := _por_ilha(caixas)
		print("  inimigos ativos por ilha depois: ", depois)
		ok(depois.keys().all(func(k): return k == outra or k == ""), "depois da troca só a nova ilha tem inimigos ativos")
	print("test_povoamento_e_ia_unificada: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
