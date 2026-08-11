extends SceneTree
## Carrega TODO .gd do projeto e reporta o que NAO COMPILA.
##
## Existe porque `--editor --quit` NAO detecta isso: ele reimporta assets e
## atualiza o cache de class_name, mas nao carrega os scripts. Um erro de
## sintaxe ou de identificador passa batido e o jogo quebra so em execucao —
## foi assim que uma edicao automatica minha quebrou o IceFX inteiro (a Ice Age
## parou de funcionar) enquanto o check de import dizia "0 erros".
##
##   godot --headless --path . --script tools/dev_tests/test_compila.gd
func _init() -> void:
	var falhas := 0
	for f in _gd("res://"):
		var r = load(f)
		if r == null:
			print("  ❌ NAO COMPILA: ", f); falhas += 1
	print("scripts que nao compilam: ", falhas)
	quit(1 if falhas > 0 else 0)
func _gd(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null: return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if n in [".godot", "graphify-out", ".git"]: n = d.get_next(); continue
		var p := dir.path_join(n)
		if d.current_is_dir(): out.append_array(_gd(p))
		elif n.ends_with(".gd"): out.append(p)
		n = d.get_next()
	d.list_dir_end()
	return out
