extends SceneTree
# ============================================================================
#  FLORESTA GIGANTE E MACACOS HUMANOIDES DA ILHA DOS MACACOS (18/11/2026).
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_floresta_macacos.gd
#  Mapa: árvores imensas (> 40 m), densidade, nada na trilha/clareira, macacos e Mestre. No jogo: chegando à ilha, os macacos humanoides e o Macaco-rei
#  (chefe, com a pele de macaco) e o Mestre do Geppo existem vivos; o Mestre abre a loja do Geppo.
# ============================================================================
const CENTRO := Vector2(1500, 0)
var _ok_n := 0
var _falhas := 0
func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
func _init() -> void:
	_executar.call_deferred()
func _executar() -> void:
	await process_frame
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	_ok("mapa válido", lido["ok"])
	var pecas: Array = lido["mapa"]["pecas"]
	var minhas := pecas.filter(func(p): return String(p["id"]).begins_with("macacos_floresta_"))
	var gigantes := 0
	var altas := 0
	var macacos := 0
	var reis := 0
	var mestres := 0
	var maior := 0.0
	for p: Dictionary in minhas:
		var m := String(p.get("modelo", ""))
		var t: Vector3 = p["tamanho"]
		if m.begins_with("floresta_tree_") and t.y >= 45.0:
			gigantes += 1
			maior = maxf(maior, t.y)
			altas += 1 if t.y >= 60.0 else 0
		macacos += 1 if m == "mp_macaco_humanoide" else 0
		reis += 1 if m == "mp_macaco_rei" else 0
		mestres += 1 if m == "npc_mestre_geppo" else 0
	_ok("pelo menos 40 árvores imensas (%d, a maior com %.0f m)" % [gigantes, maior], gigantes >= 40 and maior >= 90.0)
	_ok("a maioria passa dos 60 m (%d de %d)" % [altas, gigantes], altas * 2 >= gigantes)
	_ok("16 macacos humanoides, nenhum Macaco-rei (virou o Gorila-rei, v2) e 1 Mestre do Geppo (%d / %d / %d)" % [macacos, reis, mestres], macacos == 16 and reis == 0 and mestres == 1)
	var plat := minhas.filter(func(p): return String(p["id"]).begins_with("macacos_floresta_plataforma_"))
	var degraus_ok := plat.size() == 8
	for i in range(1, plat.size()):
		var d: float = float(plat[i]["posicao"].y) - float(plat[i - 1]["posicao"].y)
		degraus_ok = degraus_ok and d > 2.0 and d <= 4.0         # um pulo no ar do Geppo vence cada degrau
	_ok("8 plataformas em espiral, cada uma 2–4 m acima da anterior (alcançáveis pelo Geppo)", degraus_ok)
	_ok("o baú do topo está marcado no mapa", minhas.any(func(p): return String(p["id"]) == "macacos_floresta_marca_do_bau_topo"))
	# nenhuma árvore imensa em cima do Mestre/clareira
	var clareira := CENTRO + Vector2(-12, 4)
	var livre := true
	for p: Dictionary in minhas:
		if String(p.get("modelo", "")).begins_with("floresta_tree_") and Vector2(p["posicao"].x, p["posicao"].z).distance_to(clareira) < 16.0:
			livre = false
	_ok("a clareira do Mestre está livre de árvores", livre)
	# no jogo
	var modo = load("res://src/historia/ModoHistoria.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_floresta_macacos.json"))
	modo.set("progresso_forcado", "user://test_floresta_macacos.json")
	var pe := ProgressaoDoPersonagem.carregar("user://test_floresta_macacos.json")
	pe.corpo = "masculino"
	pe.salvar("user://test_floresta_macacos.json")
	root.get_node("GameFlow").start_story()
	for i in 300:
		await physics_frame
	var cena := current_scene
	var j: Node3D = get_first_node_in_group("player")
	_ok("jogo montado", cena != null and j != null)
	if j == null:
		quit(1)
		return
	j.set_meta("damage_immune", true)
	cena.call("ir_a_ilha", "ilha_dos_macacos")
	for i in 400:
		await physics_frame
	var baus: Node3D = cena.get("baus_de_chefe")
	_ok("o baú fixo do topo foi entregue uma vez (%d baú(s) no chão)" % (baus.baus.size() if baus != null else -1), baus != null and baus.baus.size() == 1 and cena.progressao.dados_de("baus_de_chefe").get("fixos", []).has("macacos_topo"))
	var humanos := 0
	var rei: Node = null
	for n in get_nodes_in_group("enemy"):
		var id := str(n.get("id_personagem")) if n.get("id_personagem") != null else ""
		if id == "macaco_humanoide":
			humanos += 1
		elif id == "macaco_rei":
			rei = n
	_ok("%d macacos humanoides vivos na ilha (esperado 16)" % humanos, humanos == 16)
	_ok("o Macaco-rei antigo saiu da ilha (o chefe é o Gorila-rei)", rei == null)
	var mestre: Node = null
	for n in get_nodes_in_group("npc"):
		if n is NpcDaIlha and (n as NpcDaIlha).tipo == "npc_mestre_geppo":
			mestre = n
	_ok("o Mestre do Geppo existe vivo", mestre != null)
	if mestre != null:
		var loja = load(NpcDaIlha.FICHAS["npc_mestre_geppo"]["loja"]).new()
		_ok("e fala do Geppo", loja.fala().contains("Geppo"))
	var humano: Node = null
	for n in get_nodes_in_group("enemy"):
		if str(n.get("id_personagem")) == "macaco_humanoide":
			humano = n
			break
	if humano != null:
		_ok("a pele de macaco está aplicada no corpo (textura própria)", _tem_pele(humano))
	print("\nFLORESTA_MACACOS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
func _tem_pele(no: Node) -> bool:
	for mi in no.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count() if m.mesh != null else 0:
			var o := m.get_surface_override_material(s) as StandardMaterial3D
			if o != null and o.albedo_texture != null and "pelagem_macaco" in o.albedo_texture.resource_path:
				return true
	return false
