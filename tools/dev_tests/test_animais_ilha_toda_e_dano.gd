extends SceneTree
## 10/11/2026 (pedido do dono): beagle/gato/pássaros com o DOBRO do tamanho e skin mais detalhada; beagle, gato, pássaros, galinhas e patos
## nascem e passeiam na ILHA TODA (não só na vila), menos vaca e cavalos; IA unificada também para o inimigo de peça do mapa;
## dano dos mobs maior.
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const SAVE := "user://test_animais_ilha_toda_progresso.json"
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

func rodar() -> void:
	await process_frame
	var bib := BibliotecaDeModelos.padrao()
	# ---- tamanho dobrado (valores de antes × 2) e skin mais detalhada
	var antes := {"beagle": Vector3(0.107955694, 0.5, 0.538865506), "cat": Vector3(0.0851765, 0.35, 0.3690027), "bird_2": Vector3(0.6, 0.0798936, 0.3732578), "bird-h5izaudltz": Vector3(0.6, 0.2369624, 0.3641202)}
	for id in antes:
		var t := bib.tamanho_padrao(id)
		ok(t.distance_to(antes[id] * 2.0) < 0.01, "%s com o dobro do tamanho (%s)" % [id, str(t.snapped(Vector3.ONE * 0.01))])
		var r = ResourceLoader.load("res://mapas/modelos/%s.voxel.scn" % id, "", ResourceLoader.CACHE_MODE_IGNORE)
		var cubos := 0
		if r != null:
			for mi in r.instantiate().find_children("*", "MeshInstance3D", true, false):
				for s in (mi.mesh as Mesh).get_surface_count():
					cubos += ((mi.mesh as Mesh).surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 24
		ok(cubos >= 1500 or id.begins_with("bird"), "%s: voxel com detalhe (%d cubos)" % [id, cubos])
	ok(bib.tamanho_padrao("cow").distance_to(Vector3(0.537783801, 1.3, 1.982774751)) < 0.01 and bib.tamanho_padrao("horse").y > 1.5 and bib.tamanho_padrao("horse").y < 1.6, "vaca e cavalo NÃO mudaram de tamanho")
	# ---- escalas de dano
	ok(is_equal_approx(BonecoDeDuelo.new().multiplicador_de_dano, 0.5), "bandido/boneco: multiplicador 0,5")
	ok(AnimalDaIlha.ESCALA_DE_DANO == 2.0 and JogadorDoMod.ESCALA_DO_GOLPE_DE_MOB == 3.0, "animais ×2 e mobs do mod ×3")
	# ---- área ilha-toda, unidade
	var area := {"centro": Vector3(120, 5, 30), "meio": Vector3(25, 3, 25), "base": Basis.IDENTITY, "quantidade": 2}
	PopulacaoDeAnimais.expandir_para_a_ilha(area, Rect2(-300, -300, 600, 600))
	ok((area["meio"] as Vector3).x == 300.0 and (area["centro"] as Vector3).x == 0.0 and int(area["quantidade"]) == 4 and area["tentativas"] == 48, "expandir_para_a_ilha: placa inteira, dobro de bichos, mais tentativas")
	ok(PopulacaoDeAnimais.ESPECIES_PELA_ILHA_TODA.has("duck") and PopulacaoDeAnimais.ESPECIES_PELA_ILHA_TODA.has("chicken") and not PopulacaoDeAnimais.ESPECIES_PELA_ILHA_TODA.has("cow") and not PopulacaoDeAnimais.ESPECIES_PELA_ILHA_TODA.has("horse"), "lista: galinha e pato dentro; vaca e cavalo fora")
	# ---- IA unificada: inimigo de peça do mapa
	var ia := IaDosInimigos.new()
	root.add_child(ia)
	var jogador := Node3D.new()
	jogador.add_to_group("player")
	root.add_child(jogador)
	var saco := InimigoDoMapa.new()
	root.add_child(saco)
	saco.add_to_group("enemy")
	saco.global_position = Vector3(150, 0, 0)
	ok(IaDosInimigos.faccao_de(saco) == "mapa" and IaDosInimigos.gerenciavel(saco), "InimigoDoMapa entra na IA dos inimigos, facção 'mapa'")
	ia.varrer(0.5)
	ok(IaUnificada.dormindo(saco), "inimigo de peça a 150 m dorme")
	jogador.global_position = Vector3(120, 0, 0)
	ia.varrer(0.5)
	ok(not IaUnificada.dormindo(saco), "a 30 m acorda")
	IaUnificada.dormir(saco)
	saco.take_damage(1.0)
	ok(not IaUnificada.dormindo(saco), "levar dano acorda")
	for n in [saco, jogador, ia]:
		n.queue_free()
	await process_frame
	await process_frame
	# ---- mapa real, carga por distância
	var Modo = load("res://src/historia/ModoHistoria.gd")
	Modo.set("progresso_forcado", SAVE)
	Modo.set("carregar_tudo_forcado", 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(420)
	var m = current_scene
	var vila := Vector3(125, 0, 20)
	var longe := {}
	var total := {}
	var dist_max := {}
	for a in get_nodes_in_group("animais"):
		var e: String = a.especie
		total[e] = int(total.get(e, 0)) + 1
		var d := Vector2(a.global_position.x - vila.x, a.global_position.z - vila.z).length()
		dist_max[e] = maxf(float(dist_max.get(e, 0.0)), d)
		if d > 90.0: longe[e] = int(longe.get(e, 0)) + 1
	print("  animais por espécie: ", total)
	print("  afastamento máximo da vila (m): ", dist_max)
	for e in ["beagle", "cat", "bird_2", "chicken", "duck"]:
		ok(int(total.get(e, 0)) >= 2 and float(dist_max.get(e, 0.0)) > 90.0, "%s espalhado pela ilha (>90 m da vila): %s" % [e, str(snappedf(float(dist_max.get(e, 0.0)), 1.0))])
	# vaca e cavalo: continuam na ÁREA ORIGINAL de cada um (cow em (110,-150), horse em (150,-92)), mesma quantidade de antes
	var origem := {"cow": Vector2(110, -150), "horse": Vector2(150, -92)}
	var qtd_antes := {"cow": 4, "horse": 3}
	for e in ["cow", "horse"]:
		var pior := 0.0
		for a in get_nodes_in_group("animais"):
			if a.especie == e:
				pior = maxf(pior, Vector2(a.global_position.x, a.global_position.z).distance_to(origem[e]))
		ok(int(total.get(e, 0)) == qtd_antes[e] and pior < 60.0, "%s: %d bichos, a no máximo %.0f m da área original" % [e, int(total.get(e, 0)), pior])
	print("test_animais_ilha_toda_e_dano: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
