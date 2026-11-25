extends SceneTree
# ============================================================================
#  TESTE — visão submersa e o que só existe debaixo d'água (14/10/2026,
#  docs/MAR_HISTORIA_PLANO.md, E7). Modo História, MAPA VIVO (só leitura), progresso de TESTE.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_visao_submersa.gd
#
#  Fora d'água: névoa, cáusticas e neve marinha desligadas; blocos fundos do relevo, cascos
#  e decoração dos naufrágios escondidos; blocos da costa à vista. Dentro d'água: tudo
#  ligado, a tinta chapada da HUD sai, a névoa recebe a profundidade da câmera.
#  Controle: a costa (areia molhada vista de fora) nunca entra no grupo "só submerso".
# ============================================================================

const PROGRESSO := "user://test_visao_submersa_progresso.json"
var _falhas := 0


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	print("\n===== VISÃO SUBMERSA =====")
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://mapas/historia/baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 120:
		await process_frame
	var mar := current_scene.get_node_or_null("Mar")
	var visao: Node3D = mar.get("visao") if mar != null else null
	_ok(visao != null, "visão submersa ligada no Mar")
	if visao == null:
		_fim(modo)
		return
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.make_current()
	var so := get_nodes_in_group("so_submerso")
	var blocos_fundos := so.filter(func(n: Node) -> bool: return String(n.name).begins_with("Bloco_")).size()
	var cascos := so.filter(func(n: Node) -> bool: return n.name == "Modelo").size()
	var costeiros := 0
	for n in current_scene.find_children("Bloco_*", "MeshInstance3D", true, false):
		costeiros += int(not n.is_in_group("so_submerso"))
	print("     só submerso: %d nós (%d blocos fundos, %d cascos); %d blocos da costa" % [so.size(), blocos_fundos, cascos, costeiros])
	_ok(blocos_fundos > 100 and cascos == 5 and costeiros > 20, "blocos fundos e cascos no grupo; costa fora dele")

	# Fora d'água (perto do porto).
	cam.global_position = Vector3(300, 4, 40)
	for i in 3:
		await process_frame
	var escondidos := so.all(func(n: Node) -> bool: return not (n as Node3D).visible)
	_ok(not visao.get("submerso") and escondidos, "fora d'água: o que só existe submerso está escondido")
	_ok(not visao.get_node("NevoaDaAgua").visible and not visao.get_node("Causticas").visible and not visao.get_node("NeveMarinha").visible,
		"fora d'água: névoa, cáusticas e neve desligadas")
	# Controle: a costa continua à vista de fora.
	var costa_visivel := current_scene.find_children("Bloco_*", "MeshInstance3D", true, false).filter(
		func(n: Node) -> bool: return not n.is_in_group("so_submerso") and (n as Node3D).visible).size()
	_ok(costa_visivel > 0, "controle: blocos da costa à vista de fora d'água (%d)" % costa_visivel)

	# Dentro d'água.
	cam.global_position = Vector3(340, -9, 0)
	for i in 3:
		await process_frame
	var mostrados := so.all(func(n: Node) -> bool: return (n as Node3D).visible)
	_ok(visao.get("submerso") and mostrados, "dentro d'água: tudo à vista")
	_ok(visao.get_node("NevoaDaAgua").visible and visao.get_node("Causticas").visible and visao.get_node("NeveMarinha").visible,
		"dentro d'água: névoa, cáusticas e neve ligadas")
	var prof: float = (visao.get_node("NevoaDaAgua").material_override as ShaderMaterial).get_shader_parameter("profundidade_camera")
	_ok(absf(prof - 8.35) < 0.8, "a névoa recebe a profundidade da câmera (%.2f m)" % prof)
	var hud := current_scene.find_child("AguaHud", true, false)
	var tinta: Control = hud.get_node_or_null("VisaoSubmersa") if hud != null else null
	_ok(tinta == null or not tinta.visible, "a tinta chapada da HUD saiu")
	_fim(modo)


func _fim(modo: Script) -> void:
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\nVISAO_SUBMERSA_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)
