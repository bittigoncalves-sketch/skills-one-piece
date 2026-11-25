extends SceneTree
## E0 de docs/MINE_PIECE_COMPLETO_MEDICAO.md (23/10/2026): quantas procedures TRADUZIDAS do Mine
## Piece compilam no Godot. Meta da E0: ≥ 80 %. Os erros saem no log (SCRIPT ERROR ... reload (res://…)).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/compilar_procedures_mine_piece.gd

const PASTA := "res://src/minecraft/gerado/procedures/"


func _init() -> void:
	var ok := 0
	var falhas: Array[String] = []
	var dir := DirAccess.open(PASTA)
	var nomes := dir.get_files() if dir else PackedStringArray()
	for f in nomes:
		if not f.ends_with(".gd"):
			continue
		var s := ResourceLoader.load(PASTA + f, "", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
		if s != null and s.can_instantiate():
			ok += 1
		else:
			falhas.append(f)
	var total := ok + falhas.size()
	print("COMPILA %d/%d (%.1f %%)" % [ok, total, 100.0 * ok / maxi(total, 1)])
	for f in falhas.slice(0, 30):
		print("  NAO_COMPILA ", f)
	quit(0 if total > 0 and ok * 100 >= total * 80 else 1)
