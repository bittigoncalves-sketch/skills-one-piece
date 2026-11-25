extends SceneTree
# ============================================================================
#  EDITOR DE POSES DO SKILLS BUILDER (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_editor_de_poses.gd
#
#  Pelo caminho da interface: seção Poses, Nova, girar junta, a prévia mostra,
#  Espelhar, Duplicar, Apagar, desfazer, e escolher a pose num bloco de Animação.
# ============================================================================

var _ok_n := 0
var _falhas := 0
var editor: Node


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(8)
	editor = current_scene
	editor.pasta_skills = "user://test_editor_de_poses"
	var arena: Node = editor.get("arena")

	editor._mostrar_secao("poses")
	await _quadros(2)
	_ok("a seção Poses abre (botão na lista)", editor.find_child("Poses", true, false) != null and editor.find_child("NovaPose", true, false) != null)
	(editor.find_child("NovaPose", true, false) as Button).pressed.emit()
	await _quadros(3)
	_ok("Nova cria uma pose (%d)" % (editor.skill.poses as Array).size(), (editor.skill.poses as Array).size() == 1)
	var spin := editor.find_child("UpperArm_R_x", true, false) as SpinBox
	_ok("as 13 juntas têm X/Y/Z", spin != null and editor.find_child("Foot_L_z", true, false) != null)
	if spin:
		spin.value = 90.0
		await _quadros(2)
	var ossos: Dictionary = editor.skill.poses[0].ossos
	_ok("girar o braço grava [90, 0, 0] (%s)" % str(ossos.get("UpperArm_R")), ossos.get("UpperArm_R") == [90.0, 0.0, 0.0])
	var rig: Dictionary = arena.get("_rig")
	var braco: Node3D = rig.get("nodes", {}).get("UpperArm_R")
	var rep: Vector3 = rig.get("rest", {}).get("UpperArm_R", Vector3.ZERO)
	_ok("a prévia mostra a pose (%.1f°)" % rad_to_deg(braco.rotation.x - rep.x), absf(rad_to_deg(braco.rotation.x - rep.x) - 90.0) < 0.5)

	(editor.find_child("EspelharPose", true, false) as Button).pressed.emit()
	await _quadros(3)
	ossos = editor.skill.poses[0].ossos
	_ok("Espelhar passa o braço para o outro lado (%s)" % str(ossos), ossos.has("UpperArm_L") and not ossos.has("UpperArm_R"))
	editor.desfazer()
	await _quadros(3)
	_ok("desfazer volta o braço direito", (editor.skill.poses[0].ossos as Dictionary).has("UpperArm_R"))

	(editor.find_child("DuplicarPose", true, false) as Button).pressed.emit()
	await _quadros(3)
	_ok("Duplicar cria a 2ª pose com as mesmas juntas", (editor.skill.poses as Array).size() == 2
		and editor.skill.poses[1].ossos == editor.skill.poses[0].ossos)
	(editor.find_child("ApagarPose", true, false) as Button).pressed.emit()
	await _quadros(3)
	_ok("Apagar remove a selecionada (%d)" % (editor.skill.poses as Array).size(), (editor.skill.poses as Array).size() == 1)

	# Escolher a pose num bloco de Animação.
	var id_pose := str(editor.skill.poses[0].id)
	var bloco := ""
	for e: Dictionary in editor.skill.eventos:
		if e.tipo == "animacao":
			bloco = str(e.id)
	editor.selecionar_evento(bloco)
	await _quadros(3)
	_ok("sair da seção Poses volta a prévia para a timeline", str(arena.get("pose_em_edicao")).is_empty())
	var lista := editor.find_child("pose", true, false) as OptionButton
	_ok("o bloco de Animação tem a lista de poses", lista != null and lista.item_count == 2)
	if lista:
		lista.select(1)
		lista.item_selected.emit(1)
		await _quadros(3)
	var params: Dictionary = {}
	for e: Dictionary in editor.skill.eventos:
		if str(e.id) == bloco:
			params = e.parametros
	_ok("escolher na lista grava a pose no bloco (%s)" % str(params.get("pose", "")), str(params.get("pose", "")) == id_pose)
	print("\nEDITOR_DE_POSES %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
