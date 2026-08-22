extends SceneTree
# ============================================================================
#  VERIFICADOR DE COMPILAÇÃO — todos os .gd do projeto, em ~10 s.
#
#      godot --headless --path . --script tools/dev_tests/checar_compilacao.gd
#
#  ⚠️ POR QUE `can_instantiate()` E NÃO `!= null`: o `load()` devolve o GDScript
#  MESMO com erro de parse. O script "carrega", mas nenhum método dele registra —
#  e o sintoma que aparece longe dali, em runtime, é:
#
#      Invalid call. Nonexistent function 'cast' in base 'GDScript'.
#
#  Foi exatamente assim que um erro de escopo no `BaraFX.gd` deixou a Bara Bara
#  INTEIRA sem hitbox (2026-08-22) sem quebrar o jogo: as outras oito frutas
#  seguiam funcionando, e só a varredura de rede acusou.
#
#  📌 8 scripts falham aqui por motivo CONHECIDO e não são regressão: os de
#  `src/audio/` e alguns `test_*.gd` da raiz citam autoloads (`AudioManager`,
#  `SoundLibrary`, `ServerManager`) que só existem quando o jogo sobe de verdade,
#  não no modo `--script`. Compare a lista com a de antes de mexer no código.
func _init() -> void:
	await process_frame
	var fila: Array[String] = ["res://"]
	var alvos: Array[String] = []
	var pular := ["addons", "export_templates", "graphify-out", "assets", ".godot", ".git"]
	while not fila.is_empty():
		var d: String = fila.pop_back()
		var dir := DirAccess.open(d)
		if dir == null: continue
		dir.list_dir_begin()
		var n := dir.get_next()
		while n != "":
			if not n.begins_with("."):
				var p := d.path_join(n)
				if dir.current_is_dir():
					if n not in pular: fila.append(p)
				elif n.ends_with(".gd"):
					alvos.append(p)
			n = dir.get_next()
		dir.list_dir_end()
	alvos.sort()
	var mal: Array[String] = []
	for p in alvos:
		var sc = load(p)
		if sc == null or not (sc as GDScript).can_instantiate():
			mal.append(p)
	print("\n=== %d scripts, %d NÃO COMPILAM ===" % [alvos.size(), mal.size()])
	for p in mal:
		print("  ❌ " + p)
	quit(1 if mal.size() > 0 else 0)
