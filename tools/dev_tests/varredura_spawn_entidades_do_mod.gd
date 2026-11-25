extends SceneTree
# ============================================================================
#  VARREDURA (09/11/2026, item 7): nasce cada entidade do mod (`McCorpoDoMod`), deixa a IA do mod rodar por alguns quadros e imprime uma linha por id:
#    SPAWN <id> corpo=<sim|não> visual=<tipo> erros=<n>
#  Os "erros" são os SCRIPT ERROR que aparecem DURANTE aquele id (o script que chama separa por id). Uso:
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/varredura_spawn_entidades_do_mod.gd 2>&1 | grep -E "^SPAWN|SCRIPT ERROR"
# ============================================================================
func q(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://varredura_spawn.json"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://varredura_spawn.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var mundo: McMundo = Mc.mundo(self)
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mapas/east_blue/entidades_do_mod.json")).entidades
	var so: PackedStringArray = OS.get_cmdline_user_args()
	var ids: Array = dados.keys() if so.is_empty() else Array(so)
	var n := 0
	for id: String in ids:
		n += 1
		print("INICIO ", id)
		var pos := McEntidade.de(j).position().add(6.0 + (n % 5), 0.0, 6.0 + (n % 7))
		var e: McEntidade = Mc.tipo_entidade(&"minepiece:" + id).spawn(mundo, pos)
		await q(8)
		var corpo := e != null and e.valida()
		var visual := "-"
		if corpo:
			var no: Node = e.no
			visual = "glb" if (no.find_children("*", "MeshInstance3D", true, false).size() > 0) else "sem_malha"
		print("SPAWN %s corpo=%s visual=%s" % [id, "sim" if corpo else "nao", visual])
		if corpo:
			e.no.queue_free()
		await q(2)
	print("FIM_DA_VARREDURA ", ids.size())
	quit()
