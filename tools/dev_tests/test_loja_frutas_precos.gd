extends SceneTree
const Loja := preload("res://src/historia/npcs/loja_de_frutas.gd")
const Sobrevivencia := preload("res://src/ui/SobrevivenciaHud.gd")
var total := 0
var falhas := 0
var tela := false

class HudDeTeste extends CanvasLayer:
	func is_menu_open() -> bool: return false

func _init() -> void: rodar.call_deferred()
func ok(sim: bool, mensagem: String) -> void:
	total += 1
	if not sim: falhas += 1
	print(("OK " if sim else "FALHA ") + mensagem)

func rodar() -> void:
	await process_frame
	tela = OS.get_cmdline_user_args().has("--tela")
	var p := ProgressaoDoPersonagem.new()
	var loja := Loja.new()
	for id in PerfilDeFrutas.frutas_a_venda():
		if id == KitDoBuilder.ID: continue
		# 18/11/2026: preço pelo PODER da fruta, de 1000 (comum) a 40000 (lendária).
		var poder := PerfilDeFrutas.poder_da_fruta(id)
		var so_do_mod := PerfilDeFrutas.frutas_so_do_mod().has(id)
		var esperado: int = PerfilDeFrutas.PRECO_POR_PODER[poder - 1]
		ok(poder >= 1 and poder <= 5 and esperado >= 1000, id + ": poder %d (%s), preço mínimo 1000" % [poder, PerfilDeFrutas.raridade_da_fruta(id)])
		ok(PerfilDeFrutas.PODER_DAS_FRUTAS.has(id), id + ": poder classificado na tabela (não cai no padrão)")
		ok(PerfilDeFrutas.preco_na_loja(id) == esperado, id + ": preço correto")
		p.ouro = esperado - 1
		loja.executar(p, null, "comprar", id)
		ok(p.ouro == esperado - 1 and p.quantas_akuma(id) == 0, id + ": saldo insuficiente não debita nem entrega")
		p.ouro = esperado
		loja.executar(p, null, "comprar", id)
		ok(p.ouro == 0 and p.quantas_akuma(id) == 1, id + ": compra cobra valor exato")
		p.remover_akuma(id, 99)                       # a mochila tem 36 vagas e a loja recusa (sem cobrar) quando cheia: libera a vaga
		var caminho := PerfilDeFrutas.imagem_na_loja(id)
		var imagem := load(caminho) as Texture2D
		var sufixo := id + "_mine_piece.png" if so_do_mod else id + ".png"
		if id == "hito_hito_daibutsu":                  # a Buda tem miniatura própria autorada (`PerfilDeFrutas.imagem_na_loja`), fora do padrão `<id>_mine_piece.png`
			sufixo = "buda_loja.png"
		ok(caminho.ends_with(sufixo) and imagem != null and (so_do_mod or imagem.get_width() == 128), id + ": miniatura própria importada")
	var anterior := -1
	var ordem := true
	for l in loja.linhas(p, null):
		ordem = ordem and int(l.preco) >= anterior
		anterior = int(l.preco)
	ok(ordem, "catálogo ordenado por preço crescente")
	var moedas := p.ouro
	loja.executar(p, null, "comprar", "fruta_inexistente")
	ok(p.ouro == moedas and p.quantas_akuma("fruta_inexistente") == 0, "id inválido não entrega fruta")
	root.size = Vector2i(1280, 720)
	var hud := HudDeTeste.new()
	root.add_child(hud)
	var status := Sobrevivencia.new()
	status.progressao = ProgressaoDoPersonagem.new()
	hud.add_child(status)
	for largura in [1280, 1920, 1024]:
		root.size = Vector2i(largura, 720)
		for i in 3: await process_frame
		var r := status.get_global_rect()
		var canvas_x := status.get_viewport_rect().size.x     # o esticamento do projeto ("expand") faz o canvas ser MAIS LARGO que a janela abaixo de 16:9 (1024 px → canvas 1280): o canto é do canvas
		ok(absf(r.end.x - (canvas_x - Sobrevivencia.MARGEM)) < 1 and absf(r.position.y - (Sobrevivencia.MARGEM + VidaEnergiaHud.FAIXA_DO_NIVEL)) < 1 and absf(r.size.x - VidaEnergiaHud.LARGURA) < 1 and absf(r.size.y - (2.0 * VidaEnergiaHud.ALTURA + VidaEnergiaHud.ESPACO)) < 1, "fome/sede do tamanho de vida/energia, no canto superior direito em %d px (canvas %.0f)" % [largura, canvas_x])
	root.size = Vector2i(1280, 720)
	var janela := JanelaDeLoja.new()
	hud.add_child(janela)
	var prog := ProgressaoDoPersonagem.new()
	prog.ouro = 500000
	janela.ligar(prog, BibliotecaDeModelos.padrao())
	var npc := NpcDaIlha.new()
	npc.tipo = "npc_vendedor_frutas"
	janela.abrir(npc)
	for i in 4: await process_frame
	var linhas: Node = janela.get("_lista")
	var completas := true
	for l in linhas.get_children():
		completas = completas and l.find_child("Imagem", true, false) != null and l.find_child("Preco", true, false) != null
	ok(completas and linhas.get_child_count() == PerfilDeFrutas.frutas_a_venda().size(), "todas as linhas têm imagem e preço")
	ok(janela.get_global_rect().end.x <= root.size.x and janela.get_global_rect().end.y <= root.size.y, "loja cabe em 1280 × 720")
	await foto("loja_inicio")
	janela.get("_rolagem").scroll_vertical = 330
	await foto("loja_demais")
	janela.hide()
	await foto("fome_sede_direita")
	npc.free()
	hud.free()
	print("LOJA E HUD: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)

func foto(nome: String) -> void:
	if not tela: return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var pasta := "res://art_src/validation/loja_frutas_hud"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	root.get_texture().get_image().save_png(pasta.path_join(nome + ".png"))
