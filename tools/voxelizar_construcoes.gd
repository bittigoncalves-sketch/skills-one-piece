extends SceneTree
## Voxeliza TODAS as CONSTRUÇÕES (`CatalogoDeConstrucoes`) com o dado de interior que a destruição por blocos precisa
## (`VoxelizadorDeMalha`, metadados `voxel_*`). Não toca nos .glb: grava `mapas/modelos/<id>.voxel.scn`
## (a malha de cubos que `BibliotecaDeModelos.instanciar` já aplica por cima do modelo). Idempotente; substitui o que
## `voxelizar_casas.gd` gerou (aquele não guarda o interior).
##   godot --headless --path . --script tools/voxelizar_construcoes.gd [-- id1 id2 ...]
## Reverter = apagar os `*.voxel.scn` das construções (e o .uid).
##
## Resolução: o cubo mira ~LADO_ALVO metros NO MUNDO (tamanho padrão do modelo), com limites — um prédio de 120 m não vira 240
## cubos por lado (custo de memória e de reconstrução); nele o cubo fica maior.

const PASTA := "res://mapas/modelos"
const LADO_ALVO := 0.45
const RESOLUCAO_MIN := 24
const RESOLUCAO_MAX := 96

func _init() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var so := OS.get_cmdline_user_args()
	var feitos := 0
	var falhas: Array[String] = []
	for id in CatalogoDeConstrucoes.ids(bib):
		if not so.is_empty() and not so.has(id):
			continue
		var t := bib.tamanho_padrao(id)
		var maior := maxf(t.x, maxf(t.y, t.z))
		var resolucao := clampi(roundi(maior / LADO_ALVO), RESOLUCAO_MIN, RESOLUCAO_MAX)
		var erro := VoxelizadorDeMalha.gravar_modelo(bib, id, PASTA, resolucao, true)
		if erro.is_empty():
			feitos += 1
		else:
			falhas.append("%s: %s" % [id, erro])
	print("Construções voxelizadas: %d" % feitos)
	for f in falhas:
		push_error(f)
	quit(0 if falhas.is_empty() else 1)
