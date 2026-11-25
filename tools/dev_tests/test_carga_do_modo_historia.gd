extends SceneTree
# ============================================================================
#  MONITOR DE CARGA E TELA DE CARREGAMENTO (28/10/2026): "quero ver o que está sendo carregado".
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_carga_do_modo_historia.gd
#
#  Sem janela de verdade o monitor só mede; aqui `forcar_passos` liga a tela e a carga em etapas, como no jogo. Headless não
#  desenha: o que NÃO é visto aqui é a aparência (cores, tipografia, as listas rolando).
# ============================================================================

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func rodar() -> void:
	ok(MonitorDeCarga.marcos.size() >= 2, "marcos da inicialização do jogo registrados (%d)" % MonitorDeCarga.marcos.size())
	ok(FileAccess.file_exists("user://carga/inicio_do_jogo.txt"), "gravou user://carga/inicio_do_jogo.txt")

	MonitorDeCarga.forcar_passos = true
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_carga_do_modo_historia.json")
	root.get_node("GameFlow").start_story()
	for i in 3:
		await process_frame
	var tela := root.get_node_or_null("TelaDeCarregamento")
	ok(tela != null and MonitorDeCarga.ativo, "a tela de carregamento aparece assim que o modo história começa")
	var vistas := {}
	var processando_durante := false
	var quadros := 0
	while MonitorDeCarga.ativo and quadros < 1500:
		await process_frame
		quadros += 1
		if tela != null and is_instance_valid(tela):
			vistas[(tela.get_node("Etapa") if tela.find_child("Etapa", true, false) == null else tela.find_child("Etapa", true, false)).text.rstrip(".")] = true
		var cena := current_scene
		if cena != null and cena.get("progressao") != null and cena.process_mode != Node.PROCESS_MODE_DISABLED and MonitorDeCarga.ativo:
			processando_durante = true
	ok(not MonitorDeCarga.ativo, "a carga termina sozinha (%d quadros)" % quadros)
	ok(vistas.size() >= 12, "a tela mostrou %d etapas diferentes enquanto carregava" % vistas.size())
	ok(not processando_durante, "a cena não processa nada enquanto carrega (só a tela anda)")
	var nomes: Array = MonitorDeCarga.etapas.map(func(e: Dictionary) -> String: return str(e.nome))
	ok(nomes.size() >= 20, "%d etapas medidas" % nomes.size())
	for esperado in ["Abrindo a cena", "Interface do modo história (HUD)", "Montando Ilha Inicial", "Personagens do Mine Piece (East Blue)", "Nascimento do jogador"]:
		ok(esperado in nomes, "etapa \"%s\" medida" % esperado)
	ok(MonitorDeCarga.etapas.all(func(e: Dictionary) -> bool: return int(e.ms) >= 0), "todas as etapas têm tempo")
	ok(current_scene.process_mode == Node.PROCESS_MODE_INHERIT, "o processamento da cena volta ao fim da carga")
	var jogador := get_first_node_in_group("player")
	await process_frame
	ok(jogador != null or get_first_node_in_group("player") != null, "o jogador existe quando a tela some")
	ok(FileAccess.file_exists("user://carga/ultima_carga.txt"), "gravou user://carga/ultima_carga.txt")
	var texto := FileAccess.get_file_as_string("user://carga/ultima_carga.txt")
	ok("ETAPAS (na ordem)" in texto and "AS 5 ETAPAS MAIS LENTAS" in texto and "modelos 3D" in texto, "o resumo traz etapas, as mais lentas e os modelos")
	print(texto.get_slice("\n", 0), " | ", texto.get_slice("\n", 2))
	await create_timer(1.3, true, false, true).timeout        # o fade dura ~0,8 s de tempo REAL
	ok(root.get_node_or_null("TelaDeCarregamento") == null, "a tela de carregamento é removida depois do fade")

	print("\n%d/%d" % [total - falhas, total])
	MonitorDeCarga.forcar_passos = false
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
