extends SceneTree
## Registra o GLB do Gorila-rei (`mapas/modelos/gorila_rei.glb`, feito por `tools/blender/gorila_rei.py`) no catálogo da loja, com a ficha de chefe.
## Idempotente (reimportar atualiza medidas e sha). Só executar explicitamente:
##   "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/registrar_gorila_rei.gd
const ID := "gorila_rei"
const CAMINHO := "res://mapas/modelos/gorila_rei.glb"
const VIDA := 1100.0                 # decisão 22/11/2026: "alta vida" + "duro mas justo" (a opção falava em ~600; subi porque os chefes da ilha inicial já têm 700–900)


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var cena := BibliotecaDeModelos.carregar_glb(CAMINHO)
	if cena == null:
		push_error("GLB ausente ou inválido: " + CAMINHO)
		quit(1)
		return
	var medida := BibliotecaDeModelos.medir(cena)
	var caixa: AABB = medida["aabb"]
	cena.free()
	var bib := BibliotecaDeModelos.padrao()
	var ficha := FichaDeAnimal.nova("predador", "quadrupede", {
		"boss": true, "nome": "Gorila-rei", "vida": VIDA, "passeio": 2.6, "corrida": 7.0, "dano": 14.0, "alerta": 30.0,
		"alcance": 4.0, "recarga": 2.0, "domavel": false, "golpe_em": 0.0})
	var erro := bib.adicionar({"id": ID, "nome": "Gorila-rei", "centro": caixa.get_center(), "tamanho": caixa.size, "tamanho_padrao": caixa.size,
		"triangulos": (medida["faces"] as PackedVector3Array).size() / 3, "sha256": FileAccess.get_sha256(CAMINHO),
		"categorias": ["animais", "boss"], "animal": ficha})
	print("GORILA_REI registrado: tamanho %s centro %s xp %s (%s)" % [str(caixa.size), str(caixa.get_center()), str(ficha["xp"]), error_string(erro)])
	quit(0 if erro == OK else 1)
