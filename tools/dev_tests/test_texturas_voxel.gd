extends SceneTree
## Texturas dos personagens do Mine Piece no padrão voxel (18/11/2026): nenhuma `mp_*.png` acima de 64 px (sprites de item/partícula: 32 px).
## A arte é local (fora do git); sem ela o teste só avisa. Corrigir: `python3 -I tools/mine_piece/voxelizar_texturas.py` e reimportar.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_texturas_voxel.gd
func _init() -> void:
	var pasta := "res://mapas/modelos"
	var total := 0
	var fora: Array[String] = []
	for arq in DirAccess.get_files_at(pasta):
		if not (arq.begins_with("mp_") and arq.ends_with(".png")):
			continue
		var img := Image.load_from_file(ProjectSettings.globalize_path(pasta + "/" + arq))
		if img == null:
			continue
		total += 1
		var sprite := arq.ends_with("_cutlass.png") or arq.ends_with("_particle.png")
		var limite := 32 if sprite else 64
		if maxi(img.get_width(), img.get_height()) > limite:
			fora.append("%s %dx%d" % [arq, img.get_width(), img.get_height()])
	if total == 0:
		print("sem texturas mp_* locais: nada a conferir")
		quit(0)
		return
	for f in fora:
		print("FALHA acima do padrão voxel: ", f)
	print("TEXTURAS_VOXEL %d texturas | %d fora do padrão" % [total, fora.size()])
	quit(1 if not fora.is_empty() else 0)
