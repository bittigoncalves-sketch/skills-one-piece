extends SceneTree
## Voxeliza TODAS as CASAS da biblioteca (casas, cabanas, torres-casa, depósitos, casas
## das vilas Mine Piece). Não toca nos .glb: grava `mapas/modelos/<id>.voxel.scn` e
## `BibliotecaDeModelos.instanciar` troca a malha na hora (colisão `.colisao.json` intacta).
##   godot --headless --path . --script tools/voxelizar_casas.gd [-- id1 id2 ...]
## Reverter = apagar os `*.voxel.scn` das casas (e o .uid). Idempotente.
## Os barcos-casa (categoria "navios") ficam de fora: são navios, não casas.

const PASTA := "res://mapas/modelos"
const RESOLUCAO := 48          # voxels no maior lado do modelo
const PADRAO := "house|hut|casa|cabin|cottage|cabana"
const FORA := ["navios"]

func _init() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var so := OS.get_cmdline_user_args()
	var rx := RegEx.create_from_string(PADRAO)
	var feitos := 0
	var falhas: Array[String] = []
	for id in bib.ids():
		var info := bib.info(id)
		if rx.search(id.to_lower()) == null or id.begins_with("mp_"):
			continue
		var proibido := false
		for cat: String in info.get("categorias", []):
			if FORA.has(cat):
				proibido = true
		if proibido or (not so.is_empty() and not so.has(id)):
			continue
		var erro := VoxelizadorDeMalha.gravar_modelo(bib, id, PASTA, RESOLUCAO)
		if erro.is_empty():
			feitos += 1
		else:
			falhas.append("%s: %s" % [id, erro])
	print("Casas voxelizadas: %d" % feitos)
	for f in falhas:
		push_error(f)
	quit(0 if falhas.is_empty() else 1)
