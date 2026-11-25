extends SceneTree
# ============================================================================
#  ▶ TESTAR NO JOGO do Skills Builder (07/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_testar_no_jogo.gd
#
#  Pedido do dono: "adicionar uma plataforma e um botão de play para teste das skills".
#  Pelo BOTÃO do editor, com uma skill do Kit (tecla Z) que não está publicada:
#    • abre o Modo História na plataforma de teste, com o Kit comido, a skill do editor
#      na tecla, energia cheia, 4 bonecos e o aviso do teste;
#    • a tecla lança a skill (executor do Builder nasce);
#    • Esc volta ao editor com a MESMA skill aberta;
#    • nada do jogo de verdade mudou (catálogo publicado, mapa/save forçados limpos);
#    • sair do teste pelo menu também limpa (o catálogo de teste não vaza).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const MODO := "res://src/historia/ModoHistoria.gd"

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var kit_antes := FileAccess.get_file_as_string("res://mapas/skills/kit.json")
	var frutas_antes := FileAccess.get_file_as_string("res://mapas/skills/frutas.json")
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(60)
	var ed := current_scene
	ed.call("_documento", _skill())
	await _quadros(5)
	var botao := ed.find_child("TestarNoJogo", true, false) as Button
	_ok("o editor tem o botão \"%s\"" % (botao.text if botao else "?"), botao != null)
	botao.pressed.emit()
	var aviso: Label = null
	for i in 600:
		await process_frame
		aviso = root.find_child("AvisoDoTeste", true, false) as Label
		if aviso != null:
			break
	await _fisica(20)
	var p: Node3D = get_first_node_in_group("player")
	var bonecos := current_scene.find_children("*", "BonecoDeDuelo", true, false).size() if current_scene else 0
	_ok("abriu a plataforma de teste: aviso \"%s\"" % (aviso.text if aviso else "?"), aviso != null and current_scene.get("progressao") != null)
	_ok("o Kit está comido (%s) e a tecla Z é a skill do editor (%s)" % [p.get("current_fruit_id") if p else "?",
		KitDoBuilder.skill("Z").get("identificacao", {}).get("id", "?")],
		p != null and str(p.get("current_fruit_id")) == KitDoBuilder.ID and str(KitDoBuilder.skill("Z").identificacao.id) == "teste_play")
	_ok("4 bonecos de treino (%d) e energia cheia" % bonecos, bonecos == 4 and is_equal_approx(float(p.get("energy")), float(p.get("max_energy"))))
	p.set("_intervalo_golpe", 0.0)
	p.begin_charge("Z")
	await physics_frame
	p.release_charge("Z")
	await _fisica(3)
	_ok("a tecla Z lança a skill do editor", not current_scene.find_children("SkillBuilder_teste_play", "", true, false).is_empty())
	await _fisica(40)

	# Esc volta ao editor com a mesma skill.
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 600:
		await process_frame
		if current_scene != null and current_scene.has_method("_documento") and root.find_child("TesteNoJogo", true, false) == null:
			break
	await _quadros(5)
	var doc: Dictionary = current_scene.get("skill") if current_scene else {}
	_ok("Esc voltou ao editor com a mesma skill (%s)" % str(doc.get("identificacao", {}).get("id", "?")),
		current_scene != null and current_scene.has_method("_documento") and str(doc.identificacao.id) == "teste_play")
	_ok("nada do jogo de verdade mudou (catálogo, pasta e mapa/save forçados)",
		SkillsPublicadas.pasta_forcada == "" and str(load(MODO).get("mapa_forcado")) == "" and str(load(MODO).get("progresso_forcado")) == ""
		and FileAccess.get_file_as_string("res://mapas/skills/kit.json") == kit_antes
		and FileAccess.get_file_as_string("res://mapas/skills/frutas.json") == frutas_antes
		and str(KitDoBuilder.skill("Z").get("identificacao", {}).get("id", "")) != "teste_play")

	# Sair do teste pelo MENU também limpa.
	(current_scene.find_child("TestarNoJogo", true, false) as Button).pressed.emit()
	for i in 600:
		await process_frame
		if root.find_child("AvisoDoTeste", true, false) != null:
			break
	await _fisica(10)
	root.get_node("GameFlow").back_to_menu()
	for i in 120:
		await process_frame
		if root.find_child("TesteNoJogo", true, false) == null:
			break
	_ok("saindo pelo menu, o teste se desfaz (pasta forçada \"%s\")" % SkillsPublicadas.pasta_forcada,
		root.find_child("TesteNoJogo", true, false) == null and SkillsPublicadas.pasta_forcada == "" and str(load(MODO).get("mapa_forcado")) == "")
	print("\nTESTAR_NO_JOGO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _skill() -> Dictionary:
	var s := Dados.novo()
	s.identificacao.id = "teste_play"
	s.identificacao.nome = "Teste Play"
	s.identificacao.fruta = ""
	s.ativacao.tecla = "Z"
	s.condicoes.exige_alvo = false
	return s


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
