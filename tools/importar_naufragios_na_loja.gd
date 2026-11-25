extends SceneTree
## Cadastra os naufrágios (E3 do docs/MAR_HISTORIA_PLANO.md, 14/10/2026) na loja do
## editor, categoria "naufragios". Só estes três; preserva modelos e categorias existentes.
##   "$(./find_godot.sh)" --headless --path . --script tools/importar_naufragios_na_loja.gd
## Fonte: tools/blender/naufragios.py → art_src/mar/naufragio_<tipo>.glb.

const MODELOS := {
	"naufragio_galeao": "Naufrágio — galeão partido",
	"naufragio_chalupa": "Naufrágio — chalupa tombada",
	"naufragio_bote": "Naufrágio — bote emborcado",
}


func _initialize() -> void:
	var bib := BibliotecaDeModelos.padrao()
	if not bib.tem_categoria("naufragios"):
		var categoria := bib.criar_categoria("naufragios")
		if not categoria["ok"]:
			push_error(str(categoria))
			quit(1)
			return
	var falhas := 0
	for id in MODELOS:
		var origem := "res://art_src/mar/%s.glb" % id
		var cena := BibliotecaDeModelos.carregar_glb(origem)
		if cena == null:
			push_error("sem GLB: " + origem)
			falhas += 1
			continue
		var medidas := BibliotecaDeModelos.medir(cena)
		var caixa: AABB = medidas["aabb"]
		cena.free()
		var erro := DirAccess.copy_absolute(ProjectSettings.globalize_path(origem),
			ProjectSettings.globalize_path(bib.caminho_do_arquivo(id)))
		if erro != OK:
			push_error(error_string(erro))
			falhas += 1
			continue
		var entrada := {"id": id, "nome": MODELOS[id], "sha256": FileAccess.get_sha256(origem),
			"centro": caixa.get_center(), "tamanho": caixa.size, "triangulos": medidas["triangulos"],
			"categorias": ["naufragios"]}
		erro = bib.adicionar(entrada)            # reimportar = atualizar (preserva campos extras)
		print("NAUFRAGIO_NA_LOJA %s tamanho=%s triangulos=%d erro=%s" % [id, caixa.size, medidas["triangulos"], error_string(erro)])
		falhas += int(erro != OK)
	quit(1 if falhas > 0 else 0)
