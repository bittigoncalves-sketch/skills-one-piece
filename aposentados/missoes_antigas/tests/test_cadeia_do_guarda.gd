extends SceneTree
# ============================================================================
#  CADEIA DE MISSÕES DO GUARDA + BÚSSOLA (08/10/2026, docs/ILHA_DOS_MACACOS_PLANO.md,
#  etapa 3).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_cadeia_do_guarda.gd
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_cadeia_do_guarda.gd -- --tela
#
#  Pedido do dono: completar as missões do Guarda da vila facilita a busca da Ilha dos
#  Macacos; escolhas dele: conseguir um pet, uma Akuma no Mi, vencer a corrida dos
#  caranguejos e (18/10/2026) comprar 5 pães e 5 águas no vendedor de provisões; o prêmio é uma bússola que aponta para a ilha.
#  Na cena real da história (mapa e save de TESTE): uma por vez, na ordem; só conta o
#  que acontece depois de aceitar; a "?" e o contador seguem a missão da vez; a corrida
#  vale o 1º lugar; só a compra no vendedor conta, por item; a última dá a bússola, que aparece abaixo
#  das barras, aponta para a ilha girando com a câmera e some lá; o save guarda tudo.
# ============================================================================

const MAPA := "user://test_cadeia_do_guarda.json"
const SAVE := "user://test_cadeia_do_guarda_progresso.json"
const PASTA := "res://art_src/validation/ilha_dos_macacos"
const Missoes := preload("res://src/historia/missoes/missoes.gd")
const GUARDA := "npc_missao_bandidos"

var total := 0
var falhas := 0
var tela := false
var modo_atual: Node
var prog: ProgressaoDoPersonagem
var loja: LojaDeNpc
var marca: Label3D
var rastreador: Label


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	await process_frame
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(128, 2, 128)
	var t_g := bib.tamanho_padrao(GUARDA)
	mapa.pecas.append(_peca("guarda", "modelo", Vector3(10, t_g.y / 2, 10), t_g, GUARDA))
	# A Ilha dos Macacos do teste: só a placa, no mesmo lugar da do mapa vivo.
	mapa.pecas.append(_peca("baseplate_macacos", "caixa", Vector3(1500, -1, 0), Vector3(256, 2, 256)))
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	modo_atual = current_scene
	prog = modo_atual.get("progressao")
	preload("res://tools/dev_tests/fixtures/jornada_concluida.gd").preparar(prog)
	var jogador: Node3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	if tela:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
		root.size = Vector2i(1280, 720)
	var npcs: NpcsDaIlha = modo_atual.get("_npcs")
	var guarda: NpcDaIlha = npcs.npcs.filter(func(n): return n.tipo == GUARDA)[0]
	marca = guarda.find_child("MarcaDeMissao", false, false) as Label3D
	jogador.global_position = guarda.global_position + Vector3(0, 1, 2)
	await quadros(10)
	ok(npcs.interagir(), "E perto do Guarda abre a conversa")
	loja = guarda.loja()
	rastreador = modo_atual.find_child("RastreadorDeMissoes", true, false) as Label
	var bussola := modo_atual.find_child("Bussola", true, false) as Control

	print("\n-- ordem e regras --")
	ok(Missoes.atual_do_npc(GUARDA, prog) == "bandidos" and loja.fala() == Missoes.dados("bandidos")["oferta"],
		"começa pelos bandidos (as missões de madeira saíram)")
	ok(not Missoes.TABELA.has("madeira") and not Missoes.TABELA.has("cortar_arvores"), "missões de madeira fora da tabela")
	await _oferta("bandidos", "Derrote 5 bandidos")
	ok(not prog.aceitar_missao("pet") and not prog.aceitar_missao("provisoes"), "não dá para pular a fila (pet e provisões recusados)")
	prog.adicionar_pet("beagle", "Antes")
	ok(prog.abates_da_missao("pet") == 0, "pet conseguido ANTES de aceitar não conta")
	_aceitar("bandidos")
	for i in 5:
		prog.contar_abate("bandido")
	_entregar("bandidos", 300, 50)

	print("\n-- pet --")
	await _oferta("pet", "Consiga um pet novo")
	_aceitar("pet")
	await quadros(20)
	ok(marca.visible and marca.modulate.is_equal_approx(NpcDaIlha.COR_MISSAO_EM_ANDAMENTO), "aceita: \"?\" cinza")
	var janela: JanelaDeLoja = get_first_node_in_group("hud").call("janela_de_loja")
	var fala_na_janela := (janela.find_child("Fala", true, false) as Label).text
	ok(fala_na_janela == Missoes.dados("pet")["andamento"], "a fala no alto da janela acompanha a missão: \"%s\"" % fala_na_janela)
	ok(rastreador.text.contains("Um companheiro de viagem — 0 / 1"), "na tela: \"%s\"" % rastreador.text)
	await _foto("cadeia_pet_na_tela")
	prog.adicionar_pet("beagle", "Companheiro")
	await quadros(20)
	ok(prog.estado_da_missao("pet") == Missoes.PRONTA and rastreador.text.contains("volte ao Guarda da vila"),
		"pet novo depois de aceitar: pronta (\"%s\")" % rastreador.text)
	ok(marca.modulate.is_equal_approx(NpcDaIlha.COR_MISSAO), "pronta: \"?\" amarela de novo")
	_entregar("pet", 150, 20)

	print("\n-- Akuma no Mi --")
	await _oferta("fruta", "Consiga uma Akuma no Mi")
	_aceitar("fruta")
	var fruta: String = PerfilDeFrutas.frutas_a_venda()[0]
	prog.ganhar_ouro(10000)
	ok(prog.comprar_fruta(fruta, 100) and prog.estado_da_missao("fruta") == Missoes.PRONTA, "comprar uma fruta (%s) conta" % fruta)
	_entregar("fruta", 200, 30)

	print("\n-- corrida --")
	await _oferta("corrida", "Vença a corrida dos caranguejos")
	_aceitar("corrida")
	modo_atual.call("_ao_terminar_corrida", {"completou": true, "posicao": 2})
	modo_atual.call("_ao_terminar_corrida", {"completou": false, "posicao": 1})
	ok(prog.estado_da_missao("corrida") == Missoes.ACEITA, "2º lugar ou corrida não completada não conta")
	modo_atual.call("_ao_terminar_corrida", {"completou": true, "posicao": 1})
	ok(prog.estado_da_missao("corrida") == Missoes.PRONTA, "1º lugar conta")
	_entregar("corrida", 250, 40)

	print("\n-- provisões (5 pães + 5 águas no vendedor) --")
	await _oferta("provisoes", "Compre 5 pães e 5 águas")
	_aceitar("provisoes")
	const Prov := preload("res://src/historia/tripulantes/provisoes.gd")
	var peixe: String = TabelaDePeixes.PEIXES.keys()[0]
	prog.guardar_item_de_pesca(peixe, 10)
	Prov.guardar(prog, "pao", 20)
	ok(prog.abates_da_missao("provisoes") == 0, "peixe pescado e pão ganho (não comprado) não contam")
	var vendedor := load("res://src/historia/npcs/loja_de_comida.gd").new() as LojaDeNpc
	var ids := vendedor.linhas(prog, null).map(func(l): return l.id)
	ok(ids == ["pao", "agua_potavel"], "o vendedor de provisões vende só pão e água (%s)" % [ids])
	ok(vendedor.executar(prog, null, "comprar", "refeicao").is_empty(), "refeição não é vendida")
	prog.ouro = 30
	vendedor.executar(prog, null, "dez", "pao")
	ok(prog.ouro == 20 and prog.estado_da_missao("provisoes") == Missoes.ACEITA and prog.abates_da_missao("provisoes") == 5,
		"10 pães comprados: a parte do pão para em 5, sem água ainda não fica pronta")
	for i in 4:
		vendedor.executar(prog, null, "comprar", "agua_potavel")
	ok(prog.abates_da_missao("provisoes") == 9 and Missoes.contagem("provisoes", prog) == "Pão 5 / 5 · Água potável 4 / 5",
		"contagem por item: \"%s\"" % Missoes.contagem("provisoes", prog))
	vendedor.executar(prog, null, "comprar", "agua_potavel")
	ok(prog.estado_da_missao("provisoes") == Missoes.PRONTA and prog.ouro == 15, "5 + 5 comprados: pronta, pagando 15 moedas")
	await quadros(5)
	ok(bussola != null and not bussola.visible, "antes do prêmio, nada de bússola")
	var aviso := _entregar("provisoes", 200, 30)
	ok(aviso.contains("BÚSSOLA") and bool(prog.desbloqueios["bussola"]), "prêmio: a bússola (\"%s\")" % aviso)
	await quadros(20)
	ok(not marca.visible and rastreador.text.is_empty(), "cadeia completa: a \"?\" some e o contador sai da tela")
	ok(loja.fala() == Missoes.dados("provisoes")["concluida"] and loja.linhas(prog, null)[0].botoes[0].texto == "Concluída",
		"depois ele só aponta o caminho: \"%s\"" % loja.fala())
	_fechar_janela()

	print("\n-- bússola --")
	await _bussola(jogador, bussola)

	print("\n-- save --")
	var volta := ProgressaoDoPersonagem.carregar(SAVE)
	var entregues := Missoes.TABELA.keys().all(func(id): return volta.estado_da_missao(id) == Missoes.ENTREGUE)
	ok(entregues and bool(volta.desbloqueios["bussola"]) and "ilha_dos_macacos" in volta.ilhas_visitadas,
		"o save guarda as 5 missões entregues, a bússola e a ilha visitada")

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("CADEIA_DO_GUARDA %d conferem | %d divergem" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)


func _oferta(id: String, tarefa: String) -> void:
	await quadros(20)
	var linha: Dictionary = loja.linhas(prog, null)[0]
	ok(Missoes.atual_do_npc(GUARDA, prog) == id and loja.fala() == Missoes.dados(id)["oferta"] and marca.visible
		and marca.modulate.is_equal_approx(NpcDaIlha.COR_MISSAO) and linha.botoes[0].texto == "Aceitar"
		and str(linha.detalhe).begins_with(tarefa),
		"a da vez é \"%s\": \"?\" amarela, \"%s\"" % [Missoes.dados(id)["nome"], linha.detalhe])


func _aceitar(id: String) -> void:
	var aviso := loja.executar(prog, null, "aceitar", id)
	ok(prog.estado_da_missao(id) == Missoes.ACEITA, "aceita \"%s\" (%s)" % [id, aviso])


func _entregar(id: String, xp: int, ouro: int) -> String:
	var ouro0 := prog.ouro
	var xp0 := _xp_total()
	var aviso := loja.executar(prog, null, "entregar", id)
	ok(prog.estado_da_missao(id) == Missoes.ENTREGUE and prog.ouro - ouro0 == ouro and _xp_total() - xp0 == xp,
		"entregue \"%s\": +%d XP, +%d ouro" % [id, _xp_total() - xp0, prog.ouro - ouro0])
	return aviso


## A agulha gira com a câmera: olhando para o leste, a ilha fica à frente (≈ 0°); para o
## norte, à direita (≈ +90°). Na ilha, some.
func _bussola(jogador: Node3D, bussola: Control) -> void:
	jogador.global_position = Vector3(10, 1.5, 12)
	jogador.set("_yaw", atan2(1.0, 0.0) * -1.0)          # olhando para +X (leste)
	jogador.call("_update_pivot")
	await quadros(10)
	var vida := modo_atual.find_child("VidaEnergia", true, false) as Control
	ok(bussola.visible and bussola.position.y >= vida.position.y + vida.size.y, "aparece abaixo das barras de vida e energia (y %.0f)" % bussola.position.y)
	var a_leste := rad_to_deg(bussola.call("angulo"))
	var rotulo := bussola.get_child(0) as Label
	ok(absf(a_leste) < 5.0 and rotulo.text.begins_with("Ilha dos Macacos") and rotulo.text.ends_with("km"),
		"olhando para o leste a agulha aponta para a frente (%.1f°), \"%s\"" % [a_leste, rotulo.text.replace("\n", " · ")])
	await _foto("bussola_na_tela")
	jogador.set("_yaw", 0.0)                              # olhando para −Z (norte)
	jogador.call("_update_pivot")
	await quadros(10)
	var a_norte := rad_to_deg(bussola.call("angulo"))
	ok(absf(a_norte - 90.0) < 5.0, "olhando para o norte a ilha fica à direita (%.1f°)" % a_norte)
	modo_atual.call("_ir_a_ilha_dos_macacos")
	await quadros(45)
	ok(prog.ilha == "ilha_dos_macacos" and not bussola.visible,
		"F8 › Ir à Ilha dos Macacos: lá a bússola some")


func _xp_total() -> int:
	var soma := prog.xp
	for n in range(1, prog.nivel):
		soma += ProgressaoDoPersonagem.xp_para(n)
	return soma


func _fechar_janela() -> void:
	var hud = get_first_node_in_group("hud")
	var janela = hud.call("janela_de_loja") if hud else null
	if janela:
		janela.visible = false


func _peca(id: String, tipo: String, onde: Vector3, tamanho: Vector3, modelo := "") -> Dictionary:
	var p := {"id": id, "tipo": tipo, "posicao": onde, "tamanho": tamanho, "rotacao_graus": Vector3.ZERO,
		"colisao": true, "cor": Color("#41a05d"), "material": "liso", "grade_celula": 4.0}
	if not modelo.is_empty():
		p["modelo"] = modelo
		p["cor"] = Color.WHITE
	return p


func _foto(nome: String) -> void:
	if not tela:
		return
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join(nome + ".png")))
