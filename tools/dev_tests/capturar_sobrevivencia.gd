extends SceneTree
## Cena isolada de UI: não cria Player e não captura o mouse do desktop.
const P := preload("res://src/historia/tripulantes/provisoes.gd")
const PASTA := "res://art_src/validation/sobrevivencia"
func _init() -> void: executar.call_deferred()
func executar() -> void:
	await process_frame
	root.size = Vector2i(1280, 800)
	var canvas := Control.new()
	root.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo := ColorRect.new()
	fundo.color = Color(0.035, 0.055, 0.075)
	canvas.add_child(fundo)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := ProgressaoDoPersonagem.new()
	p.ouro = 150
	for id in CatalogoDeTripulantes.ids():
		p.recrutados[id] = true
		P.adicionar(p, Tripulacao.id_do_humano(id))
	P.adicionar(p, "gaivota")
	P.adicionar(p, "caranguejo")
	var ids := ["sanji", "beto", "iara", "nami", "crocodile"]
	for i in ids.size(): P.atribuir(p, Tripulacao.id_do_humano(ids[i]), i)
	P.guardar(p, "pao", 60)
	P.guardar(p, "agua_potavel", 8)
	var menu := MenuDeComportamento.new()
	canvas.add_child(menu)
	menu.ligar(p, null)
	menu.abrir_tripulacao()
	await foto("tripulacao")
	menu.hide()
	var forge: Control = load("res://src/ui/FerrariaHud.gd").new()
	var centro := CenterContainer.new()
	canvas.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.add_child(forge)
	forge.set_process(false)
	forge.tempo = 0.5 / forge.velocidade_do_marcador()
	forge._atualizar_medidor()
	await foto("ferraria_fornalha")
	for i in 3:
		forge.tempo = 0.5 / forge.velocidade_do_marcador(); forge.acionar()
	await foto("ferraria_martelo")
	for alvo in forge.ORDEM: forge.martelar(alvo)
	forge.tempo = 0.5 / forge.velocidade_do_marcador()
	forge._atualizar_medidor()
	await foto("ferraria_resfriar")
	centro.hide()
	p.missoes["vara_inicial"] = {"estado": "entregue", "abates": 1}
	p.missoes["peixe_raro"] = {"estado": "entregue", "abates": 1}
	p.aceitar_missao("ferraria")
	var npc := NpcDaIlha.new()
	npc.tipo = "npc_ferreiro"
	var loja := JanelaDeLoja.new()
	canvas.add_child(loja)
	loja.ligar(p, BibliotecaDeModelos.padrao())
	loja.abrir(npc)
	loja.executar("forjar", "ferraria")
	loja.get("_ferraria").set_process(false)
	await foto("ferraria_na_loja")
	npc.free()
	quit()
func foto(nome: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA.path_join(nome + ".png"))
	print("CAPTURA: " + nome)
