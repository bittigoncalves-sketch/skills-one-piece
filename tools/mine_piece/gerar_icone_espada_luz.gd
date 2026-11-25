extends SceneTree
## Ícone da Ama no Murakumo (Pika Pika Mine Piece) para a barra de itens: a espada de luz
## importada (mp_espada_luz.glb, quadro 0 da textura) fotografada de lado, fundo transparente.
## Uso (precisa de renderização): DISPLAY=:1 <godot> --path . -s tools/mine_piece/gerar_icone_espada_luz.gd
const MODELO := "res://assets/mine_piece/frutas/pika/mp_espada_luz.glb"
const SAIDA := "res://assets/mine_piece/frutas/pika/icone_espada_luz.png"


func _init() -> void:
	gerar.call_deferred()


func gerar() -> void:
	await process_frame
	if not ResourceLoader.exists(MODELO):
		push_error("rode antes: python3 -I tools/mine_piece/importar_pika.py")
		quit(1)
		return
	var gerador := GeradorDeMiniaturas.new()
	root.add_child(gerador)
	var espada := (load(MODELO) as PackedScene).instantiate() as Node3D
	# O GLB está em blocos, pega na origem e lâmina em +Y (importar_pika.py grava o tamanho).
	var dados: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mine_piece/frutas/pika/espada_luz.json"))
	var comprimento := float(dados.ponta_blocos)
	await gerador.fotografar_cena(espada, Vector3(0, comprimento * 0.45, 0), comprimento * 0.55, SAIDA,
		Vector3(0.3, 0.2, 1.0), Color(0, 0, 0, 0), false)
	print("ícone em ", SAIDA)
	quit()
