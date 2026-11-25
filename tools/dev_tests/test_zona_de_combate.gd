extends SceneTree
## Zona de combate (10/11/2026): em combate o desenho encurta e as criaturas fora da zona ficam latentes (sem IA, sem spawn/renascimento);
## ao acabar o combate tudo volta. Nunca suspende aliados invocados, chefes nem inimigos de raid.
##   godot --headless --path . --script tools/dev_tests/test_zona_de_combate.gd
const LodDasIlhas := preload("res://src/historia/ilhas/lod_das_ilhas.gd")
const MAPA := "user://test_zona.json"
const SAVE := "user://test_zona_p.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _bandido(pos: Vector3) -> PersonagemMinePiece:
	var b := PersonagemMinePiece.new()
	b.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	b.position = pos
	b.ponto_de_origem = pos
	current_scene.add_child(b)
	return b
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(160, 2, 160)
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var m = current_scene
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var zona: ZonaDeCombate = m.get("_zona_de_combate")
	ok(zona != null, "a cena tem a ZonaDeCombate")
	if zona == null:
		print("test_zona_de_combate: %d ok, %d falhas" % [_ok, _f]); quit(1); return
	var longe := _bandido(j.global_position + Vector3(0, 6, -200))
	var perto := _bandido(j.global_position + Vector3(20, 0, 0))
	var aliado := _bandido(j.global_position + Vector3(0, 6, 190))     # aliado invocado longe: nunca suspenso
	aliado.add_to_group("invocados_do_jogador")
	var raider := _bandido(j.global_position + Vector3(190, 6, 0))
	raider.set_meta("raider", true)
	var camera := j.get_viewport().get_camera_3d()
	var far0 := camera.far if camera != null else 0.0
	await quadros(60)
	ok(not zona.em_combate and not Povoamento.esta_latente(longe), "fora de combate nada é suspenso")
	ok(zona.lod.perto_ate == LodDasIlhas.PERTO_ATE, "fora de combate o desenho é o normal (%.0f m)" % zona.lod.perto_ate)
	# entra em combate (uma raid em andamento: stub com `ativa`, para não mexer na raid real)
	var gd := GDScript.new()
	gd.source_code = "extends Node\nvar ativa := false\n"
	gd.reload()
	var raid_falsa := Node.new()
	raid_falsa.set_script(gd)
	zona.raid = raid_falsa
	raid_falsa.ativa = true
	zona.atualizar()
	await quadros(10)
	ok(zona.em_combate, "raid em andamento = em combate")
	ok(zona.lod.perto_ate == ZonaDeCombate.PERTO_EM_COMBATE, "em combate o desenho encurta (%.0f m)" % zona.lod.perto_ate)
	ok(camera == null or camera.far <= ZonaDeCombate.CAMERA_EM_COMBATE, "a câmera enxerga menos em combate (far %.0f)" % (camera.far if camera else -1.0))
	ok(Povoamento.esta_latente(longe), "criatura fora da zona fica latente (sem IA, sem renascer)")
	ok(not Povoamento.esta_latente(perto), "criatura dentro da zona segue ativa")
	ok(not Povoamento.esta_latente(aliado) and not Povoamento.esta_latente(raider), "aliado invocado e inimigo de raid nunca são suspensos")
	ok(longe.process_mode == Node.PROCESS_MODE_DISABLED and not longe.visible, "a latente não processa nem aparece")
	# sai do combate: histerese e volta tudo
	raid_falsa.ativa = false
	zona.atualizar()
	ok(zona.em_combate, "a histerese mantém o combate por alguns segundos")
	zona._fim = 0.0
	zona.atualizar()
	await quadros(30)
	ok(not zona.em_combate and zona.lod.perto_ate == LodDasIlhas.PERTO_ATE, "fim do combate: desenho normal de volta")
	ok(camera == null or is_equal_approx(camera.far, far0), "a câmera volta ao alcance normal (%.0f)" % (camera.far if camera else -1.0))
	ok(not Povoamento.esta_latente(longe) and longe.visible, "a criatura suspensa volta ao fim do combate")
	print("test_zona_de_combate: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
