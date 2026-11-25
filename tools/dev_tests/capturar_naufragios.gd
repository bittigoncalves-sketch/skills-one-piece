extends SceneTree
# ============================================================================
#  CAPTURA — naufrágios no jogo (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E3/E4).
#  Precisa de GPU. Modo História, MAPA VIVO (só leitura), progresso de TESTE.
#    "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_naufragios.gd -- --rotulo=e3
#  Para cada casco: vista de lado a ~14–24 m e o baú de perto. Fotos em
#  art_src/validation/mar/naufragio_<rotulo>_<id>_*.png.
# ============================================================================

const PROGRESSO := "user://capturar_naufragios_progresso.json"
const PASTA := "res://art_src/validation/mar"
var rotulo := "e3"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rotulo="):
			rotulo = a.trim_prefix("--rotulo=")
	root.size = Vector2i(1280, 720)
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://mapas/historia/baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 200:
		await process_frame
	var jogador: CharacterBody3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	jogador.set_meta("damage_immune", true)
	var mar := current_scene.get_node("Mar")
	var relevo: RelevoMarinho = mar.get("relevo")
	var registros: Dictionary = mar.get("naufragios").get("naufragios")
	for id in ["naufragio_1", "naufragio_2", "naufragio_3"]:
		var r: Dictionary = registros[id]
		var corpo: Node3D = r["corpo"]
		var lado := corpo.global_basis.z.normalized()
		var dist := 22.0 if r["modelo"] == "naufragio_galeao" else 13.0
		var olho := corpo.global_position + lado * dist + Vector3.UP * 1.0
		olho.y = minf(olho.y, relevo.nivel - 4.0)
		var para := corpo.global_position - olho
		await _foto(jogador, olho, atan2(-para.x, -para.z), -0.22, "%s_lado" % id)
		var bau: Vector3 = r["ponto"]
		var o2 := bau + Vector3(4.5, 1.2, 1.5)
		o2.y = minf(o2.y, relevo.nivel - 3.0)
		var p2 := bau - o2
		await _foto(jogador, o2, atan2(-p2.x, -p2.z), -0.35, "%s_bau" % id)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	quit()


func _foto(jogador: CharacterBody3D, pos: Vector3, yaw: float, pitch: float, nome: String) -> void:
	jogador.global_position = pos
	jogador.velocity = Vector3.ZERO
	jogador.set("_yaw", yaw)
	jogador.set("_pitch", pitch)
	jogador.call("_update_pivot")
	for i in 40:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join("naufragio_%s_%s.png" % [rotulo, nome])))
	print("NAUFRAGIO foto %s" % nome)
