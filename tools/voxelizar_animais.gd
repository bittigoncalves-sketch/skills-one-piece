extends SceneTree
## Voxeliza os ANIMAIS do Modo História (menos as bestas do mar). Não toca nos .glb:
## grava `mapas/modelos/<id>.voxel.scn` (só as malhas de cubos, uma por MeshInstance3D do
## modelo, com o nome = caminho do nó) e `BibliotecaDeModelos.instanciar` troca a malha na hora,
## mantendo esqueleto, `Skin` (o original), animações e clipes extras.
##   godot --headless --path . --script tools/voxelizar_animais.gd [-- id1 id2 ...]
## Reverter = apagar os `*.voxel.scn` (e o .uid). Idempotente.

const PASTA := "res://mapas/modelos"
const RESOLUCAO := 32          # voxels no maior lado do modelo (padrão)
## Mais detalhe só para estes (10/11/2026, "melhora a skin deles"): o beagle, o gato e os dois pássaros foram DOBRADOS de tamanho no catálogo.
## Medido: o arquivo anterior tinha ~2400 cubos no beagle (≈ 96 voxels no maior lado, 307 KB); 64 daria 1110 (pior). Com o corpo 2× maior,
## 128 voxels deixam o cubo ~15 % menor que o de antes (mais detalhe de cor) por ~4300 cubos no beagle.
const RESOLUCAO_POR_MODELO := {"besta_mar_bovina": 72, "besta_mar_girafa": 96, "besta_mar_javali": 72, "besta_mar_serpente": 96, "beagle": 128, "cat": 128, "bird_2": 128, "bird-h5izaudltz": 128}
const EXTRAS := ["animals__farm__horse_1__base", "cavalo_da_vila_leve"]   # cavalos sem ficha de animal
## Categorias que NÃO entram por padrão. Pedindo o id explicitamente (`-- besta_mar_serpente`) entra: as bestas do mar foram voxelizadas assim em 18/11/2026.
const FORA := ["bestas_do_mar"]
const BESTAS := ["besta_mar_bovina", "besta_mar_girafa", "besta_mar_javali", "besta_mar_serpente"]

func _init() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var so := OS.get_cmdline_user_args()
	var feitos := 0
	var falhas: Array[String] = []
	for id in bib.ids():
		var info := bib.info(id)
		if not (info.has("animal") or EXTRAS.has(id) or (BESTAS.has(id) and so.has(id))):
			continue
		var proibido := false
		for cat: String in info.get("categorias", []):
			if FORA.has(cat):
				proibido = true
		if (proibido and not so.has(id)) or (not so.is_empty() and not so.has(id)):
			continue
		var erro := _voxelizar(bib, id)
		if erro.is_empty():
			feitos += 1
		else:
			falhas.append("%s: %s" % [id, erro])
	print("Animais voxelizados: %d" % feitos)
	for f in falhas:
		push_error(f)
	quit(0 if falhas.is_empty() else 1)

func _voxelizar(bib: BibliotecaDeModelos, id: String) -> String:
	return VoxelizadorDeMalha.gravar_modelo(bib, id, PASTA, int(RESOLUCAO_POR_MODELO.get(id, RESOLUCAO)))
