extends SceneTree
## Registra no catálogo da loja os GLBs temáticos da Ilha dos Macacos v2 (`tools/blender/construcoes_macacos.py` → `mapas/modelos/macacos_*.glb`) e os NPCs
## de missão novos (`NpcDaIlha.FICHAS`). Idempotente. Só executar explicitamente:
##   "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/registrar_construcoes_macacos.gd
const ImportarNpcs := preload("res://tools/importar_npcs_na_loja.gd")
const MODELOS := {
	"macacos_cabana_geppo": ["Cabana do Mestre do Geppo", "construao"], "macacos_cabana_curandeiro": ["Cabana do Curandeiro", "construao"],
	"macacos_tenda": ["Tenda de palha", "construao"], "macacos_torre_vigia": ["Torre de vigia", "construao"],
	"macacos_cais": ["Cais rústico dos macacos", "construao"], "macacos_portal": ["Portal da selva", "construao"],
	"macacos_totem_alegre": ["Totem alegre", "construao"], "macacos_totem_guardiao": ["Totem guardião", "construao"],
	"macacos_totem_sabio": ["Totem sábio", "construao"], "macacos_altar_bananas": ["Altar das bananas", "construao"],
	"macacos_trono": ["Trono do Gorila-rei", "construao"], "macacos_fogueira": ["Fogueira da vila", "construao"],
	"macacos_cacho_banana": ["Cacho de banana", "itens"], "macacos_fruto_dourado": ["Fruto dourado", "itens"],
	"macacos_bananeira": ["Bananeira", "arvores"],
}


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var falhou := false
	for id: String in MODELOS:
		var caminho := "res://mapas/modelos/%s.glb" % id
		var cena := BibliotecaDeModelos.carregar_glb(caminho)
		if cena == null:
			push_error("GLB ausente ou inválido: " + caminho)
			falhou = true
			continue
		var medida := BibliotecaDeModelos.medir(cena)
		var caixa: AABB = medida["aabb"]
		cena.free()
		var erro := bib.adicionar({"id": id, "nome": MODELOS[id][0], "centro": caixa.get_center(), "tamanho": caixa.size, "tamanho_padrao": caixa.size,
			"triangulos": (medida["faces"] as PackedVector3Array).size() / 3, "sha256": FileAccess.get_sha256(caminho), "categorias": [MODELOS[id][1]]})
		print("  %s  %s  centro %s  (%s)" % [id, str(caixa.size), str(caixa.get_center()), error_string(erro)])
		falhou = falhou or erro != OK
	for r: Dictionary in ImportarNpcs.importar_todos(bib):
		print("  NPC: ", r["mensagem"] if r["ok"] else r["erro"])
		falhou = falhou or not r["ok"]
	quit(1 if falhou else 0)
