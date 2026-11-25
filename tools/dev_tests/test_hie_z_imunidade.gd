extends SceneTree
# ============================================================================
#  Z DA HIE: IMUNIDADE AO GELO SÓ NA 3ª SALVA, E SÓ SE ACERTAR
#  (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_hie_z_imunidade.gd
#
#  Pedido do dono: "hie hie no mi Z, este ataque só concede imunidade ao gelo temporária
#  no terceiro disparo e caso acerte". Antes: a 1ª salva congelava 0,7 s e deixava 0,5 s
#  de imunidade — a 2ª e a 3ª batiam em gelo ou em imune e não prendiam.
#  Na cena real da história (mapa e save de TESTE), Hie comida, boneco parado a 8 m:
#    • as três salvas acertam: o boneco fica PRESO SEM SOLTAR do 1º acerto ao fim, e a
#      imunidade só aparece depois do último gelo;
#    • a 3ª salva erra (o boneco sai da frente depois da 2ª): descongela SEM imunidade;
#    • controle positivo: fora do Modo História (= arena) a 1ª salva já deixa imunidade.
# ============================================================================

const SAVE := "user://test_hie_z_imunidade_progresso.json"
const MAPA := "user://test_hie_z_imunidade_mapa.json"
const ALVO := Vector3(0, 1.0, -8.0)

var total := 0
var falhas := 0
var p: Node3D       # sem tipo Player: tipar compila o Player.gd antes dos autoloads
var boneco: BonecoDeDuelo


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	await process_frame
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	ok(prog.comer_fruta("hie_hie"), "come a Hie")
	await quadros(20)
	ok(str(p.get("current_fruit_id")) == "hie_hie", "Hie equipada")
	var salvas: Array = KitDoBuilder.skill("Z", "hie_hie").get("eventos", []).filter(func(e): return e["tipo"] == "projetil")
	ok(salvas.map(func(e): return bool(e["parametros"].get("imunidade_gelo", true))) == [false, false, true],
		"no Z publicado, só a 3ª salva dá imunidade")
	boneco = BonecoDeDuelo.new()
	boneco.position = ALVO
	current_scene.add_child(boneco)
	await quadros(10)

	print("\n-- as três salvas acertam --")
	var r := await _disparar(-1.0)
	print("     congelado em %s  ·  imune desde %.2f s" % [str(r["periodos"]), r["imune_em"]])
	ok(r["periodos"].size() == 1, "preso sem soltar do 1º acerto ao fim (%d período de gelo)" % r["periodos"].size())
	ok(r["periodos"].size() >= 1 and r["periodos"][0][1] - r["periodos"][0][0] > 1.0,
		"o gelo durou a sequência inteira (%.2f s)" % (r["periodos"][0][1] - r["periodos"][0][0] if r["periodos"].size() >= 1 else 0.0))
	ok(not r["imune_antes_do_fim"], "nenhuma imunidade enquanto as salvas chegam")
	ok(r["imune_em"] >= 0.0 and r["periodos"].size() >= 1 and absf(r["imune_em"] - r["periodos"][-1][1]) < 0.05,
		"a imunidade começa quando o último gelo solta")

	print("\n-- a 3ª salva erra --")
	r = await _disparar(1.25)
	print("     congelado em %s  ·  imune desde %.2f s" % [str(r["periodos"]), r["imune_em"]])
	ok(r["periodos"].size() >= 1, "as primeiras salvas prenderam")
	ok(r["imune_em"] < 0.0, "sem o acerto da 3ª: descongela SEM imunidade")

	print("\n-- controle positivo: fora do Modo História (arena) --")
	current_scene.remove_from_group("modo_historia")
	r = await _disparar(-1.0)
	print("     congelado em %s  ·  imune desde %.2f s" % [str(r["periodos"]), r["imune_em"]])
	var primeiro: Array = r["periodos"][0] if r["periodos"].size() >= 1 else [0.0, 0.0]
	ok(primeiro[1] - primeiro[0] < 0.9 and r["imune_em"] >= 0.0 and absf(r["imune_em"] - primeiro[1]) < 0.05,
		"na arena a 1ª salva prende só 0,7 s (%.2f s) e já deixa imunidade (aos %.2f s)" % [primeiro[1] - primeiro[0], r["imune_em"]])
	current_scene.add_to_group("modo_historia")
	_fim()


## Mira no boneco, aperta Z e amostra o gelo dele por 3 s. `sair_em` > 0: o boneco sai da
## frente nesse instante (a 3ª salva erra). {periodos: [[início, fim]], imune_em, imune_antes_do_fim}
func _disparar(sair_em: float) -> Dictionary:
	boneco.global_position = ALVO
	boneco.set_meta("is_frozen", false)
	boneco.set_meta("ice_immune", false)
	await quadros(70)                       # sobra de gelo/imunidade da rodada anterior
	boneco.global_position = ALVO
	boneco.set_meta("ice_immune", false)
	p.global_position = Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	var d := ALVO - p.global_position
	p.set("_yaw", atan2(-d.x, -d.z))
	p.call("_update_pivot")
	(p.get("_fruit_cooldowns") as Dictionary)["Z"] = 0.0
	p.energy = p.max_energy
	await quadros(40)
	p.begin_charge("Z")
	await physics_frame
	p.release_charge("Z")
	var periodos: Array = []
	var imune_em := -1.0
	var imune_antes := false
	var t := 0.0
	var preso := false
	var saiu := false
	for i in 180:
		await physics_frame
		t += 1.0 / 60.0
		if sair_em > 0.0 and not saiu and t >= sair_em:
			saiu = true
			boneco.global_position = ALVO + Vector3(40, 0, 0)
		var agora := bool(boneco.get_meta("is_frozen", false))
		if agora and not preso:
			periodos.append([t, -1.0])
		elif not agora and preso:
			periodos[-1][1] = t
		preso = agora
		if bool(boneco.get_meta("ice_immune", false)):
			if imune_em < 0.0:
				imune_em = t
			if preso:
				imune_antes = true
	if preso and not periodos.is_empty():
		periodos[-1][1] = t
	p.call("clear_spawned_skills")
	return {"periodos": periodos, "imune_em": imune_em, "imune_antes_do_fim": imune_antes}


func _fim() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAPA))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nHIE_Z_IMUNIDADE %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
