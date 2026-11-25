class_name HistoriaHud
extends CanvasLayer
# ============================================================================
#  HUD DO MODO HISTÓRIA — o mínimo para jogar e sair, e nada da arena.
#
#  A `Hud` da arena traz barra de técnicas, placar, inventário, trava de fruta:
#  tudo que o personagem do Modo História ainda NÃO tem. Reaproveitá-la mostraria
#  botões de poderes que não existem. Esta HUD cumpre só o contrato que o Player
#  consulta pelo grupo "hud" (sempre com `has_method`, conferido em Player.gd):
#
#    • `toggle_main_menu()` — o ESC do Player abre o MESMO menu da arena;
#    • `is_menu_open()`     — com menu aberto o WASD para (MoveFrame.ler).
#
#  STATUS (16/09/2026): tecla M abre a `JanelaDeStatus`; subir de nível ou bater
#  na barreira do nível 7 mostra um aviso no topo por alguns segundos (§10, §6).
#
#  FERRAMENTAS DE TESTE (30/09/2026): F8, só em build de desenvolvimento
#  (`FerramentasDeTeste`). Eram a seção TESTE da janela de Status; saíram de lá
#  para ela ser interface de jogo. Aberto, o painel conta como menu, como o Status.
#
#  JANELA ÚNICA (30/10/2026, pedido do dono): o M abre a `CentralDeJanelas`, com botões no
#  topo para trocar entre STATUS (`JanelaDeStatus`), MOCHILA (a grade de slots + o painel de itens
#  `InventarioDaHistoria`: frutas, pesca, armas, materiais — a aba INVENTÁRIO deixou de existir em 19/11/2026) e PETS (`MenuDeComportamento`, a tripulação). As
#  teclas N e B deixaram de abrir qualquer coisa. Os pets são achados pelo grupo
#  `pets_historia` — nada disso passa pelo `ModoHistoria` além de `ligar_pets`.
#
#  VIDA E ENERGIA (21/09/2026): as barras da arena no canto superior esquerdo
#  (`VidaEnergiaHud`), lidas do corpo local a cada quadro.
#
#  TÉCNICAS DA FRUTA (22/09/2026): as teclas Z/X/C/V chegam ao corpo por AQUI. Na
#  arena quem encaminha é a `Hud`; sem isto, no Modo História a tecla não ia a lugar
#  nenhum. A trava de quem pode usar continua no Player (`capacidades.can_use_fruit`).
# ============================================================================

const MainMenuClass := preload("res://src/ui/MainMenu.gd")

const DURACAO_DO_AVISO := 4.0

var _menu: Control = null
var _toque: ToqueHud = null
var _janela: JanelaDeStatus = null
var _ferramentas: FerramentasDeTeste = null
var _inventario: InventarioDaHistoria = null
var _mochila: MochilaMinecraft = null
var _mao: FrutaNaMao = null
var _montaria: Node
var _navegacao: Node
## "Navegar?" e a escolha da tripulação (15/10/2026); modal, aberta pelo `comando.gd`.
var _tripulacao: JanelaDaTripulacao = null
var _faixa_navegando: FaixaNavegando = null
var _pesca: Pescaria = null
var _npcs: NpcsDaIlha = null
var _interagiveis: Array[Node] = []
var _loja: JanelaDeLoja = null
var _fala_cinema: CaixaDeFalaCinematografica = null
var _dica_montaria: Label
var _relogio_montaria := 0.0
var _menu_pets: MenuDeComportamento = null
## A janela única do M: hospeda o status, o inventário e a tripulação (antes M, N e B).
var _central: CentralDeJanelas = null
var _hud_mc: HudMinecraft = null
var _catalogo: CatalogoDeBlocos = null
var _conquistas: JanelaDeConquistas = null
## A pokébola: cubo na mão e arremesso (liga o `ModoHistoria`).
var _captura: CapturaDeInimigos = null
## O menu B procura o pet mais perto até esta distância do jogador.
const ALCANCE_DO_MENU_DE_PET := 20.0
var _vida_energia: VidaEnergiaHud = null
var _indicador_m: Label = null
var _itens_do_mod: ContadorDeItensHud = null
var _rastreador: Label = null
var _tecnicas: TecnicasHud = null
## Tecla → slot de técnica. O F não entra aqui: ele é o VOO, que não passa pelo
## caminho de cast (é movimento), e sim por `Player.pedir_voo_de_fruta`.
const SLOTS := {KEY_Z: "Z", KEY_X: "X", KEY_C: "C", KEY_V: "V"}
## Teclas das técnicas das frutas Mine Piece, na ordem do ciclo.
const TECLAS_DE_FRUTA := [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B, KEY_N, KEY_K, KEY_L]   # K e L: poderes extras da Zushi Zushi
var _aviso: Label = null
## Barra de itens 1–6 no centro inferior (03/10/2026).
var _barra: BarraDeItensHud = null
var _tempo_do_aviso := 0.0


func _ready() -> void:
	add_to_group("hud")
	add_child(preload("res://src/ui/barras_de_criaturas.gd").new())
	# Vida dos chefes no topo da tela (08/10/2026).
	add_child(BarrasDeChefes.new())
	add_child(BarraDeEstamina.new())   # Epic Fight (10/11/2026): o roll gasta estamina
	# Acima da camada da mira do Player (que é 1): sem isto o "+" do centro da tela
	# aparecia por cima da janela de status (captura de 16/09/2026).
	layer = 5
	# Joystick e câmera por toque. Ele se esconde sozinho fora de celular; sem ele
	# o Modo História simplesmente não andaria no Android. Os botões de golpe dele
	# chamam os mesmos métodos do Player, que já recusam pelas capacidades.
	_toque = ToqueHud.new()
	_toque.name = "ToqueHud"
	add_child(_toque)
	# Antes da janela de status e do menu (criados depois): eles cobrem as barras.
	_vida_energia = VidaEnergiaHud.new()
	_vida_energia.name = "VidaEnergia"
	add_child(_vida_energia)
	var carga_ef := CargaDeArmaHud.new()          # barra da habilidade inata da arma do Epic Fight (só com a arma na mão)
	carga_ef.name = "CargaDeArma"
	add_child(carga_ef)
	_indicador_m = EstiloDaHistoria.rotulo("M", EstiloDaHistoria.DOURADO, 22)
	_indicador_m.name = "IndicadorM"
	_indicador_m.custom_minimum_size = Vector2(44.0, 40.0)
	_indicador_m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicador_m.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_indicador_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicador_m.add_theme_stylebox_override("normal", EstiloDaHistoria.painel())
	add_child(_indicador_m)
	_indicador_m.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_itens_do_mod = ContadorDeItensHud.new()          # logo abaixo do "M" (pedido do dono, 10/11/2026)
	add_child(_itens_do_mod)
	_itens_do_mod.position = Vector2(0.0, _indicador_m.custom_minimum_size.y + 4.0)
	_tecnicas = TecnicasHud.new()
	_tecnicas.name = "Tecnicas"
	add_child(_tecnicas)
	# Buki Buki (21/11/2026): luneta, munição e marcador de acerto — a HUD da história não os tinha. Só aparecem com a fruta/arma (cada um se esconde sozinho).
	var luneta := SniperScope.new()
	luneta.name = "SniperScope"
	add_child(luneta)
	var municao := AmmoHud.new()
	municao.name = "AmmoHud"
	add_child(municao)
	var acerto := MarcadorDeAcerto.new()
	acerto.name = "MarcadorDeAcerto"
	add_child(acerto)


## Água: barra de fôlego e tinta submersa (atrás das outras peças do HUD).
func ligar_agua(na_agua: JogadorNaAgua) -> void:
	var agua := AguaHud.new()
	agua.name = "AguaHud"
	agua.na_agua = na_agua
	add_child(agua)
	move_child(agua, 0)


## Liga o status do personagem: cria a janela (fechada) e os avisos de nível.
func ligar_progressao(prog: ProgressaoDoPersonagem) -> void:
	if _itens_do_mod != null:
		_itens_do_mod.ligar(prog)
	_barra = BarraDeItensHud.new()
	_barra.name = "BarraDeItens"
	add_child(_barra)
	_barra.ligar(prog)
	_barra.trocou.connect(func(id: String): avisar("%s ativa" % _barra.nome_do_item(id)))
	if HudMinecraft.disponivel():
		# Corações, fome e XP do Minecraft acima da hotbar (12/11/2026). A barra de vida antiga some; a de energia fica.
		_hud_mc = HudMinecraft.new()
		_hud_mc.name = "HudMinecraft"
		_hud_mc.barra = _barra
		_hud_mc.progressao = prog
		add_child(_hud_mc)
		_barra.subir_nome(56.0)
		# sem `usar_coracoes()`: a vida fica na barra de cima, acima da energia (pedido do dono, 12/11/2026)
	_central = CentralDeJanelas.new()
	_central.name = "CentralDeJanelas"
	add_child(_central)
	_central.ligar(prog)
	_central.aba_mostrada.connect(_ao_mostrar_aba)
	_central.fechou.connect(_mouse_dos_paineis)
	_janela = JanelaDeStatus.new()
	_janela.name = "JanelaDeStatus"
	_janela.visible = false
	_central.adicionar_pagina("status", _janela)
	_janela.ligar(prog)

	# Depois da janela: aberto junto com ela, o painel fica por cima.
	if OS.is_debug_build():
		_ferramentas = FerramentasDeTeste.new()
		_ferramentas.name = "FerramentasDeTeste"
		_ferramentas.visible = false
		add_child(_ferramentas)
		_ferramentas.ligar(prog)

	_aviso = Label.new()
	_aviso.name = "AvisoDeNivel"
	_aviso.visible = false
	_aviso.add_theme_font_size_override("font_size", 22)
	_aviso.add_theme_color_override("font_color", JanelaDeStatus.COR_TITULO)
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aviso)
	# Faixa na largura toda com texto centralizado: com âncora no centro e tamanho
	# mínimo, o rótulo nascia vazio e o texto COMEÇAVA no meio da tela.
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# ABAIXO das barras de vida e energia (que acabam em y=112 desde o "NIVEL:n", 17/10/2026): o
	# aviso mais longo, centrado, mede 664 px e cobria a ponta da energia em qualquer tela até
	# ~1400 px de largura (medido em 21/09, `test_vida_energia_historia`).
	_aviso.offset_top = 116.0
	_aviso.offset_bottom = 148.0

	prog.subiu_de_nivel.connect(func(de: int, para: int):
		avisar("Level Up!  Nível %d → Nível %d" % [de, para]))


## Comida: reserva uma unidade, toca o clipe esticado e só no FIM paga a fome e dá a regeneração acelerada. Devolve se começou a comer.
func _comer_devagar(provisoes: GDScript, jogador: Node, alimentacao: Node) -> bool:
	if alimentacao.comendo():
		return false
	var prog: ProgressaoDoPersonagem = _barra.progressao
	var id: String = provisoes.proxima_comida(prog)
	if id.is_empty() or not provisoes.reservar(prog, id):
		return false
	var bonus: Dictionary = provisoes.bonus_de_regeneracao(id)
	alimentacao.comer(provisoes.tempo_de_comer(id),
		func():
			provisoes.aplicar_refeicao(prog, id)
			var vida: Object = jogador.get("_vida")
			if vida != null and vida.has_method("premiar_comida"): vida.premiar_comida(float(bonus.fator), float(bonus.duracao))
			avisar("%s  ·  regeneração acelerada por %d s" % [str(provisoes.ITENS[id].nome), roundi(float(bonus.duracao))]),
		func(): provisoes.devolver(prog, id))
	return true


func avisar(texto: String) -> void:
	if _aviso == null:
		return
	_aviso.text = texto
	_aviso.visible = true
	_tempo_do_aviso = DURACAO_DO_AVISO


func janela_de_status() -> JanelaDeStatus:
	return _janela


func fala_em_cena() -> bool:
	return _fala_cinema != null and _fala_cinema.ativa()


## Cutscene (21/11/2026): esconde TODAS as peças da HUD menos a caixa cinematográfica e devolve cada uma como estava (quem já estava escondida continua).
var _antes_do_cinema: Dictionary = {}
func modo_cinema(ligado: bool) -> void:
	# `modulate.a = 0` e não `visible`: várias peças da HUD reafirmam o próprio `visible` a cada quadro.
	if ligado:
		_antes_do_cinema.clear()
		for filho in get_children():
			if filho is CanvasItem and filho != _fala_cinema:
				_antes_do_cinema[filho] = (filho as CanvasItem).modulate
				(filho as CanvasItem).modulate = Color(1, 1, 1, 0)
	else:
		for filho: Node in _antes_do_cinema:
			if is_instance_valid(filho):
				(filho as CanvasItem).modulate = _antes_do_cinema[filho]
		_antes_do_cinema.clear()


func caixa_de_fala() -> CaixaDeFalaCinematografica:
	return _fala_cinema


func status_aberto() -> bool:
	return _janela != null and _janela.visible


## O painel F8 (nulo fora de build de desenvolvimento).
func ferramentas_de_teste() -> FerramentasDeTeste:
	return _ferramentas


func ferramentas_abertas() -> bool:
	return _ferramentas != null and _ferramentas.visible


## Liga o inventário e a tripulação (abas da central do M) aos pets do jogador.
## Liga a captura de inimigos (pokébola) à HUD, que repassa o clique esquerdo.
func ligar_captura(captura: CapturaDeInimigos) -> void:
	_captura = captura


func ligar_pets(companhia: Node, prog: ProgressaoDoPersonagem, mao: FrutaNaMao = null) -> void:
	_mao = mao
	# 19/11/2026, pedido do dono: o inventário (frutas, pesca, armas, materiais) deixou de ser uma aba e passou para a MOCHILA (E). A página
	# tem a grade de slots à esquerda e o painel de itens (a mesma `InventarioDaHistoria`, embutida) à direita.
	_inventario = InventarioDaHistoria.new()
	_inventario.name = "Inventario"
	_inventario.embutir()
	_inventario.ligar(prog, companhia, mao)
	_inventario.aviso.connect(avisar)
	_mochila = MochilaMinecraft.new()
	_mochila.name = "MochilaMinecraft"
	_mochila.avisou.connect(avisar)
	var centro := CenterContainer.new()              # a grade fica CENTRALIZADA no espaço que sobra ao painel de itens
	centro.name = "CentroDaMochila"
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.add_child(_mochila)
	var pagina := HBoxContainer.new()
	pagina.name = "PaginaDaMochila"
	pagina.add_theme_constant_override("separation", 10)
	pagina.add_child(centro)
	pagina.add_child(_inventario)
	_mochila.largura_reservada = InventarioDaHistoria.LARGURA_NA_MOCHILA + 10.0
	_central.adicionar_pagina("mochila", pagina)
	_mochila.ligar(prog.inventario, prog)
	_catalogo = CatalogoDeBlocos.new()
	_central.adicionar_pagina("blocos", _catalogo)
	_catalogo.ligar(prog)
	if not BancadaEpicFight.ids().is_empty():
		var bancada := BancadaDeArmas.new()          # fabricação das armas do Epic Fight (só com as receitas do mod extraídas)
		_central.adicionar_pagina("bancada", bancada)
		bancada.ligar(prog)
	_menu_pets = MenuDeComportamento.new()
	_menu_pets.name = "MenuDeComportamento"
	_menu_pets.visible = false
	_central.adicionar_pagina("pets", _menu_pets)
	_conquistas = JanelaDeConquistas.new()
	_conquistas.name = "JanelaDeConquistas"
	_conquistas.visible = false
	_central.adicionar_pagina("conquistas", _conquistas)
	_conquistas.ligar(prog)
	_menu_pets.escolheu.connect(func(pet: Node, modo: StringName):
		avisar("%s  ·  %s" % [str(pet.get("nome_exibido")), ModoDoPet.nome(modo)])
		fechar_menu_de_pets())


func ligar_montaria(controle: Node) -> void:
	_montaria = controle
	controle.aviso.connect(avisar)
	_dica_montaria = Label.new()
	_dica_montaria.name = "DicaMontaria"
	_dica_montaria.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica_montaria.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dica_montaria)
	_dica_montaria.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dica_montaria.offset_left = -240
	_dica_montaria.offset_right = 240
	# Acima da barra de itens (que ocupa a base do centro, ~90 px).
	_dica_montaria.offset_top = -132
	_dica_montaria.offset_bottom = -100
	_dica_montaria.add_theme_color_override("font_shadow_color", Color.BLACK)
	_dica_montaria.add_theme_constant_override("shadow_offset_x", 1)
	_dica_montaria.add_theme_constant_override("shadow_offset_y", 1)

## Sistema com `dica() -> String` e `interagir() -> bool` que responde ao E (14/10/2026:
## baús de naufrágio, docs/MAR_HISTORIA_PLANO.md). Sistema novo registra aqui em vez de
## ganhar campo e ramo próprios nesta HUD.
func ligar_interagivel(no: Node) -> void:
	if not _interagiveis.has(no):
		_interagiveis.append(no)


func ligar_navegacao(controle: Node) -> void:
	_navegacao = controle
	controle.aviso.connect(avisar)
	# A faixa NAVEGANDO (15/10/2026): fica na tela até o barco entrar numa ilha.
	_faixa_navegando = FaixaNavegando.new()
	add_child(_faixa_navegando)
	controle.viagem_mudou.connect(_faixa_navegando.mostrar)


## A janela "Navegar?" / tripulação. O `comando.gd` a abre ao embarcar e escuta os sinais.
func ligar_tripulacao(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos) -> JanelaDaTripulacao:
	_tripulacao = JanelaDaTripulacao.new()
	_tripulacao.name = "JanelaDaTripulacao"
	_tripulacao.visible = false
	add_child(_tripulacao)
	_tripulacao.ligar(prog, bib)
	_tripulacao.visibility_changed.connect(_mouse_dos_paineis)
	return _tripulacao


func tripulacao_aberta() -> bool:
	return _tripulacao != null and _tripulacao.visible


func janela_da_tripulacao() -> JanelaDaTripulacao:
	return _tripulacao

## Pesca (03/10/2026): o medidor da briga e os avisos da vara.
func ligar_pesca(pescaria: Pescaria) -> void:
	_pesca = pescaria
	pescaria.aviso.connect(avisar)
	var medidor := PescaHud.new()
	medidor.name = "PescaHud"
	medidor.pescaria = pescaria
	medidor.visible = false
	add_child(medidor)
	move_child(medidor, 0)


## NPCs do mapa (pescador, domador, vendedor de frutas): E abre a loja do mais perto.
func ligar_npcs(npcs: NpcsDaIlha, prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos) -> void:
	_npcs = npcs
	_loja = JanelaDeLoja.new()
	_loja.name = "JanelaDeLoja"
	_loja.visible = false
	add_child(_loja)
	_loja.ligar(prog, bib)
	_loja.aviso.connect(avisar)
	_fala_cinema = CaixaDeFalaCinematografica.new()      # conversa em cena de filme (21/11/2026): tarjas + legenda acima do XP; vem DEPOIS da loja (desenha por cima)
	_fala_cinema.barra = _barra
	add_child(_fala_cinema)
	npcs.pediu_loja.connect(_conversar_com)
	# Missões em andamento no canto da tela (08/10/2026).
	# 17/10/2026: abaixo das barras de vida e energia (era o canto superior direito).
	_rastreador = preload("res://src/ui/rastreador_de_missoes.gd").new()
	_rastreador.set("progressao", prog)
	_rastreador.set("abaixo_de", _vida_energia)
	_rastreador.set("espaco_extra", _indicador_m.custom_minimum_size.y + 10.0 + ContadorDeItensHud.ALTURA + 4.0)   # reserva o contador abaixo do M
	add_child(_rastreador)
	# Marcador de missão na tela (10/10/2026): nos alvos da missão aceita; pronta, no NPC
	# que paga. Atrás das janelas (entra antes delas na ordem de desenho).
	var marcador: Control = preload("res://src/ui/marcador_de_missao.gd").new()
	marcador.set("progressao", prog)
	marcador.set("npcs", npcs)
	marcador.set("jogador_de", npcs.jogador_de)
	add_child(marcador)
	move_child(marcador, 0)


## Bússola para a Ilha dos Macacos (08/10/2026): abaixo das barras de vida e energia;
## aparece com o prêmio da última missão do Guarda.
func ligar_bussola(prog: ProgressaoDoPersonagem, caixa_da_ilha: Rect2, jogador_de: Callable) -> Control:
	var bussola: Control = preload("res://src/ui/bussola_hud.gd").new()
	bussola.set("progressao", prog)
	bussola.set("caixa", caixa_da_ilha)
	bussola.set("jogador_de", jogador_de)
	bussola.set("abaixo_de", _rastreador if _rastreador != null else _indicador_m)
	add_child(bussola)
	return bussola


## Bússola de missão (21/11/2026): aponta para o que `ponto_de` devolver (Vector3) e some com null. Segunda bússola, independente da das ilhas.
func ligar_bussola_de_missao(prog: ProgressaoDoPersonagem, ponto_de: Callable, jogador_de: Callable, nome := "Cais") -> Control:
	var bussola: Control = preload("res://src/ui/bussola_hud.gd").new()
	bussola.set("progressao", prog)
	bussola.set("jogador_de", jogador_de)
	bussola.set("ponto_de_missao", ponto_de)
	bussola.set("nome_do_ponto", nome)
	bussola.set("abaixo_de", _rastreador if _rastreador != null else _indicador_m)
	add_child(bussola)
	return bussola


func janela_de_loja() -> JanelaDeLoja:
	return _loja


func loja_aberta() -> bool:
	return _loja != null and _loja.visible


## O NPC com `dialogo()` fala primeiro em legendas e só então abre a janela; sem diálogo (ou já em cena), vai direto à janela como sempre.
func _conversar_com(npc: Node) -> void:
	var loja: Variant = npc.call("loja") if npc.has_method("loja") else null
	if loja != null and loja.has_method("intercepta") and loja.intercepta():
		return                                           # uma missão tomou a conversa (ex.: a Alvida, no vendedor de navios)
	if _fala_cinema != null and loja != null and loja.has_method("dialogo") and not _fala_cinema.ativa():
		var linhas: Array[Dictionary] = loja.dialogo()
		if not linhas.is_empty():
			_fala_cinema.barra = _barra
			_fala_cinema.tocar(linhas, abrir_loja.bind(npc))
			return
	abrir_loja(npc)


func abrir_loja(npc: Node) -> void:
	if _loja == null or (_menu != null and _menu.is_open()):
		return
	_loja.abrir(npc)
	_mouse_dos_paineis()


func fechar_loja() -> void:
	if _loja != null:
		_loja.fechar()
	_mouse_dos_paineis()

func _dica_de_interacao() -> String:
	if is_menu_open():
		return ""
	var j := _jogador_local()
	var bicicleta := j.get_node_or_null("BicicletaDeGelo") if j != null else null
	if bicicleta != null and (bicicleta.ativa() or bicicleta.disponivel()):
		return bicicleta.dica()
	# Linha na água manda na dica (o que fazer AGORA com a vara).
	if is_instance_valid(_pesca) and _pesca.ocupada():
		return _pesca.dica()
	if is_instance_valid(_montaria) and _montaria.ativa():
		return _montaria.dica()
	if is_instance_valid(_navegacao):
		var texto: String = _navegacao.dica()
		if not texto.is_empty():
			return texto
	if is_instance_valid(_npcs):
		var fala := _npcs.dica()
		if not fala.is_empty():
			return fala
	for n in _interagiveis:
		if is_instance_valid(n):
			var texto: String = n.dica()
			if not texto.is_empty():
				return texto
	var montar: String = _montaria.dica() if is_instance_valid(_montaria) else ""
	if montar.is_empty() and is_instance_valid(_pesca):
		return _pesca.dica()
	return montar


func barra() -> BarraDeItensHud:
	return _barra


func mochila() -> MochilaMinecraft:
	return _mochila


func inventario() -> InventarioDaHistoria:
	return _inventario


func menu_de_comportamento() -> MenuDeComportamento:
	return _menu_pets


## O painel de itens mora na página MOCHILA: está aberto quando essa página aparece (o `visible` do nó fica sempre verdadeiro).
func inventario_aberto() -> bool:
	return _inventario != null and _inventario.is_visible_in_tree()


func menu_de_pets_aberto() -> bool:
	return _menu_pets != null and _menu_pets.visible


func central() -> CentralDeJanelas:
	return _central


func central_aberta() -> bool:
	return _central != null and _central.aberta()


## O E sem nada para interagir: abre a central direto na aba MOCHILA (o inventário estilo Minecraft).
func abrir_mochila() -> void:
	if _central == null or central_aberta() or (_menu != null and _menu.is_open()):
		return
	_central.abrir("mochila")
	_mouse_dos_paineis()


## O M: abre a central na última aba usada, ou fecha (qualquer aba).
func alternar_central() -> void:
	if _central == null or (_menu != null and _menu.is_open()):
		return
	if _central.aberta():
		_central.fechar()
	else:
		_central.abrir()
	_mouse_dos_paineis()


## Alterna a central NA aba `id`: fecha se já está nela, senão abre (ou troca) para ela.
func _alternar_aba(id: String) -> bool:
	if _central == null or not _central.tem_pagina(id) or (_menu != null and _menu.is_open()):
		return false
	if _central.aberta() and _central.aba == id:
		_central.fechar()
	else:
		_central.abrir(id)
	_mouse_dos_paineis()
	return true


## Nome antigo, mantido: o "inventário" agora é a MOCHILA (aba única da central para a grade e os itens).
func alternar_inventario() -> void:
	if _barra != null and _barra.progressao != null:
		_barra.progressao.recolher_frutas_para_o_inventario()      # excedente de frutas + Kit do Builder entram na mochila ao abri-la
	_alternar_aba("mochila")


## Abre a aba PETS da central (a tripulação). Quem pede é o jogo, não uma tecla.
func abrir_menu_de_pets() -> bool:
	if _central == null or not _central.tem_pagina("pets") or (_menu != null and _menu.is_open()):
		return false
	_central.abrir("pets")
	_mouse_dos_paineis()
	return true


func fechar_menu_de_pets() -> void:
	if menu_de_pets_aberto():
		_central.fechar()
	_mouse_dos_paineis()


## O que cada aba faz ao ser mostrada (a central só troca a visibilidade).
func _ao_mostrar_aba(id: String) -> void:
	match id:
		"status":
			_janela.abrir(_jogador_local())
		"mochila":
			_inventario.mostrar_aba(_inventario.aba)
		"pets":
			_menu_pets.abrir_tripulacao()
		"conquistas":
			_conquistas.atualizar()
	_mouse_dos_paineis()


## O pet (grupo `pets_historia`) mais perto do jogador, até `ALCANCE_DO_MENU_DE_PET`.
func pet_mais_perto() -> Node3D:
	var jogador := _jogador_local() as Node3D
	if jogador == null:
		return null
	var melhor: Node3D = null
	var melhor_d := ALCANCE_DO_MENU_DE_PET
	for n in get_tree().get_nodes_in_group("pets_historia"):
		var pet := n as Node3D
		if pet == null or not pet.is_inside_tree():
			continue
		var d := pet.global_position.distance_to(jogador.global_position)
		if d <= melhor_d:
			melhor_d = d
			melhor = pet
	return melhor


func alternar_status() -> void:
	_alternar_aba("status")


func alternar_ferramentas() -> void:
	if _ferramentas == null or (_menu != null and _menu.is_open()):
		return
	_ferramentas.visible = not _ferramentas.visible
	if _ferramentas.visible:
		_ferramentas.posicionar()
	_mouse_dos_paineis()


## Mouse solto enquanto houver painel aberto (Status ou F8); fechar um deles com o
## outro ainda aberto não pode prender o mouse de volta no jogo.
func _mouse_dos_paineis() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if status_aberto() or ferramentas_abertas() \
		or inventario_aberto() or menu_de_pets_aberto() or loja_aberta() or tripulacao_aberta() or central_aberta() \
		else Input.MOUSE_MODE_CAPTURED


# ⚠️ `_input`, não `_unhandled_input`: o Player também escuta o ESC no
# `_unhandled_input` e está MAIS FUNDO na árvore, então receberia primeiro e abriria
# o menu principal por cima da janela. Aqui a janela fecha e o ESC para.
func _input(evento: InputEvent) -> void:
	# A RODA do mouse anda a seleção da hotbar (como o Minecraft); a câmera aproxima/afasta no I/O. Menu aberto: a roda é da lista.
	var roda := evento as InputEventMouseButton
	if roda != null and roda.pressed and (roda.button_index == MOUSE_BUTTON_WHEEL_UP or roda.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
			and _barra != null and not is_menu_open() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_barra.rolar(1.0 if roda.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
		get_viewport().set_input_as_handled()
		return
	# Pokébola (item da barra), como o arco: BOTÃO DIREITO segurado puxa, solto atira (ver `CapturaDeInimigos`).
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_RIGHT and _captura != null:
		if evento.pressed:
			if _barra != null and _barra.progressao != null and _barra.progressao.item_em_uso() == "pokebola" \
					and not is_menu_open() and _captura.comecar_a_puxar():
				get_viewport().set_input_as_handled()
				return
		elif _captura.puxando():
			_captura.soltar()
			get_viewport().set_input_as_handled()
			return
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_RIGHT \
			and _barra != null and _barra.progressao != null and _barra.progressao.item_em_uso() in ["comida", "agua"] and not is_menu_open():
		var jogador := _jogador_local()
		if evento.pressed and jogador != null and float(jogador.health) > 0 \
				and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
			var provisoes := preload("res://src/historia/tripulantes/provisoes.gd")
			var item := _barra.progressao.item_em_uso()
			var alimentacao := jogador.get_node_or_null("AlimentacaoVisual")
			var consumiu := false
			if item == "agua":
				var bebida: String = provisoes.beber_da_barra_id(_barra.progressao)
				consumiu = not bebida.is_empty()
				if consumiu and alimentacao != null: alimentacao.apresentar(item, 0.0, bebida)
				if consumiu:
					var bonus: Dictionary = provisoes.bonus_de_energia_da_agua(bebida)
					var vida: Object = jogador.get("_vida")
					if vida != null and vida.has_method("premiar_agua"): vida.premiar_agua(float(bonus.fator), float(bonus.duracao))
					avisar("%s  ·  energia regenera %d× por %d s" % [str(provisoes.ITENS[bebida].nome), roundi(float(bonus.fator)), roundi(float(bonus.duracao))])
			elif alimentacao != null:
				consumiu = _comer_devagar(provisoes, jogador, alimentacao)      # comer leva tempo e acelera a regeneração (20/11/2026)
				if consumiu == false and alimentacao.comendo():
					get_viewport().set_input_as_handled()
					return                                                      # já está comendo: o clique não gasta outra unidade
			else:
				consumiu = provisoes.comer_da_barra(_barra.progressao)
			if consumiu:
				pass
			else:
				avisar("Sem água · compre água potável no vendedor de comida" if item == "agua" else "Sem comida · compre pão ou refeição no vendedor")
		get_viewport().set_input_as_handled()
		return
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	var k := evento as InputEventKey
	# A confirmação é modal: ESC cancela só o reset; M/N/F8 não abrem outra
	# janela por baixo nem devolvem o mouse ao jogo enquanto ela está aberta.
	if _janela != null and _janela.confirmacao_reset_aberta():
		if k.keycode == KEY_ESCAPE:
			_janela.cancelar_reset_total()
			get_viewport().set_input_as_handled()
		elif k.physical_keycode in [KEY_M, KEY_F8]:
			get_viewport().set_input_as_handled()
		return
	# Navegar?/tripulação é modal: só os botões respondem (sim/não, zarpar/cancelar) — nem o
	# ESC, nem M/N/F8 abrem outra coisa por cima, e tecla nenhuma chega ao jogo.
	if tripulacao_aberta():
		get_viewport().set_input_as_handled()
		return
	if k.physical_keycode == KEY_M and not k.ctrl_pressed and not (_menu != null and _menu.is_open()):
		alternar_central()
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_E and central_aberta() and _central.aba == "mochila":
		alternar_central()                       # o E também FECHA a mochila (como no Minecraft)
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_F8 and _ferramentas != null:
		alternar_ferramentas()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ESCAPE and central_aberta():
		alternar_central()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ESCAPE and ferramentas_abertas():
		alternar_ferramentas()
		get_viewport().set_input_as_handled()
	elif loja_aberta():
		# Loja aberta: E/ESC fecham; o resto não passa para o jogo.
		if k.physical_keycode == KEY_E or k.keycode == KEY_ESCAPE:
			fechar_loja()
		get_viewport().set_input_as_handled()
	elif menu_de_pets_aberto():
		# Aba PETS aberta: o resto das teclas não passa para o jogo.
		get_viewport().set_input_as_handled()
	elif k.physical_keycode >= KEY_1 and k.physical_keycode <= KEY_9 and _barra != null and not is_menu_open():
		# Hotbar do inventário: a tecla 1–9 escolhe o SLOT (item do jogo: ativa, um por vez; item comum: vai para a mão).
		if _barra.escolher(k.physical_keycode - KEY_1):
			get_viewport().set_input_as_handled()


## Z/X/C/V → o corpo. Espelha a `Hud` da arena (`src/ui/Hud.gd`), com as duas regras
## que ela aprendeu: o KEY-UP atravessa menu aberto (senão a técnica fica presa com a
## tecla "segurada") e o KEY-DOWN não passa com menu aberto.
func _unhandled_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or evento.echo:
		return
	var k := evento as InputEventKey
	var jogador := _jogador_local()
	if jogador == null:
		return
	# F: o voo da fruta. No Modo História o Corpo de Ferro não existe (ele anda com
	# `can_use_skills`, que fica falso), então a tecla é do Blast Off.
	# Kit do Builder com skill no F (06/10/2026): o F é dela — aperta e solta como Z/X/C/V.
	var fruta_atual := str(jogador.get("current_fruit_id"))
	if (k.keycode == KEY_F or k.physical_keycode == KEY_F) and fruta_atual == "hie_hie":
		if k.pressed and not is_menu_open():
			var bicicleta := jogador.get_node_or_null("BicicletaDeGelo")
			if bicicleta != null and bicicleta.alternar(): avisar(bicicleta.dica())
		get_viewport().set_input_as_handled()
		return
	# 07/10/2026: também a fruta da arena refeita com skill no F (o voo da Pika).
	if k.keycode == KEY_F and (KitDoBuilder.pelo_builder(fruta_atual, "F") or fruta_atual == "tori_tori_phoenix"):
		if not k.pressed:
			jogador.release_charge("F")
		elif not is_menu_open():
			jogador.begin_charge("F")
		get_viewport().set_input_as_handled()
		return
	if k.keycode == KEY_F and k.pressed and not is_menu_open():
		if jogador.has_method("pedir_voo_de_fruta") and jogador.pedir_voo_de_fruta():
			get_viewport().set_input_as_handled()
		return
	# E: conversar com o NPC mais perto (o pescador dá a vara); senão, o primeiro
	# interagível registrado que aceitar (baú de naufrágio...).
	if (k.physical_keycode == KEY_E or k.keycode == KEY_E) and k.pressed and not is_menu_open():
		if _npcs != null and _npcs.interagir():
			get_viewport().set_input_as_handled()
		elif _interagiveis.any(func(n: Node) -> bool: return is_instance_valid(n) and n.interagir()):
			get_viewport().set_input_as_handled()
		else:
			abrir_mochila()                      # nada para interagir: o E abre o inventário (10/11/2026, pedido do dono)
			get_viewport().set_input_as_handled()
		return
	# Montaria próxima tem prioridade; sem ela Y mantém a doma com fruta.
	if (k.physical_keycode == KEY_Y or k.keycode == KEY_Y) and k.pressed and not is_menu_open():
		if _montaria != null and _montaria.ativa():
			_montaria.interagir()
		elif _navegacao != null and _navegacao.interagir():
			pass
		elif _montaria != null and _montaria.interagir():
			pass
		elif _mao != null and _mao.tem_fruta():
			_mao.pedir_doma()
		else:
			avisar("Aproxime-se de uma montaria ou segure uma fruta (N › FRUTAS) para domar")
		get_viewport().set_input_as_handled()
		return
	# Teclas do mod que não dependem de fruta (09/11/2026): H = Haki do Rei, G = modo de batalha (ver `TeclasDoMod`).
	if k.pressed and not is_menu_open() and TeclasDoMod.tratar(jogador, k.physical_keycode):
		get_viewport().set_input_as_handled()
		return
	# Frutas Mine Piece (08/11/2026): cada técnica na sua tecla — Z X C V, e B N se houver mais; segurar carrega, soltar dispara.
	var fruta_mp := ControladorFrutaMinePiece.de(jogador)
	if fruta_mp != null and fruta_mp.fruta_ativa():
		var tecla := k.keycode if k.keycode != 0 else k.physical_keycode
		# Cada técnica na sua tecla (08/11/2026): Z X C V e, havendo mais, B N. R não troca mais nada.
		if tecla in TECLAS_DE_FRUTA:
			if not k.pressed or not is_menu_open():
				fruta_mp.usar_tecla(char(tecla), k.pressed)
			get_viewport().set_input_as_handled()
			return
		if tecla == KEY_R:
			get_viewport().set_input_as_handled()
			return
		# Zoan do mod: J transforma (a tecla do mod é N, que aqui é técnica), Shift+J volta à forma anterior.
		if tecla == KEY_J and fruta_mp.has_method("transformar"):
			if k.pressed and not is_menu_open():
				fruta_mp.transformar(k.shift_pressed)
				get_viewport().set_input_as_handled()
				return
	var goro_mp := GoroGoroMinePiece.de(jogador)
	if goro_mp != null and goro_mp.fruta_ativa():
		var tecla := k.keycode if k.keycode != 0 else k.physical_keycode
		if tecla in TECLAS_DE_FRUTA:
			if not k.pressed or not is_menu_open():
				goro_mp.usar_tecla(char(tecla), k.pressed)
			get_viewport().set_input_as_handled()
			return
		if tecla == KEY_R:
			get_viewport().set_input_as_handled()
			return
	var slot: String = SLOTS.get(k.keycode if k.keycode != 0 else k.physical_keycode, "")
	if slot.is_empty():
		return
	var espada := jogador.get_node_or_null("EspadaDaHistoria")
	if espada != null and espada.ativa and is_instance_valid(espada.habilidades_da_lamina) and espada.habilidades_da_lamina.disponivel():
		# Lâmina EF de madeira (21/11/2026): Z corta, X lança a meia-lua.
		if k.pressed and not k.echo and not is_menu_open():
			if slot == "Z":
				espada.habilidades_da_lamina.cortar()
			elif slot == "X":
				espada.habilidades_da_lamina.lancar_meia_lua()
		get_viewport().set_input_as_handled()
		return
	if espada != null and espada.ativa and is_instance_valid(espada.giro):
		if slot == "Z" and k.pressed and not is_menu_open():
			espada.giro.alternar()
		get_viewport().set_input_as_handled()
		return
	# Machado na mão (17/10/2026): Z arremessa, X corta na horizontal; as outras teclas ficam mudas.
	var machado := jogador.get_node_or_null("MachadoDaHistoria")
	if machado != null and machado.ativa and is_instance_valid(machado.habilidades):
		if k.pressed and not is_menu_open():
			if slot == "Z":
				machado.habilidades.lancar()
			elif slot == "X":
				machado.habilidades.cortar()
		get_viewport().set_input_as_handled()
		return
	if not k.pressed:
		if jogador.has_method("release_charge"):
			jogador.release_charge(slot)
		return
	if is_menu_open():
		return
	if jogador.has_method("begin_charge"):
		jogador.begin_charge(slot)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_relogio_montaria -= delta
	if _dica_montaria != null and is_instance_valid(_montaria) and _relogio_montaria <= 0:
		_relogio_montaria = .15
		_dica_montaria.text = _dica_de_interacao()
	_vida_energia.atualizar(_jogador_local())
	# Com o Status aberto as barras do canto ficariam cortadas pela borda da janela — e
	# ela mostra a mesma vida e energia, com as mesmas barras.
	if status_aberto():
		_vida_energia.visible = false
	_indicador_m.position = Vector2(0.0, _vida_energia.position.y + _vida_energia.size.y + 10.0)
	_indicador_m.visible = _jogador_local() != null
	if _itens_do_mod != null:                       # o contador de itens acompanha o M, logo abaixo dele
		_itens_do_mod.position = Vector2(0.0, _indicador_m.position.y + _indicador_m.custom_minimum_size.y + 4.0)
	# O menu das técnicas aparece com a fruta ATIVA na barra (03/10/2026) ou com a Luta, que só
	# tem linhas quando o Estilo de Combate Base está publicado (14/10/2026).
	var jogador := _jogador_local()
	var espada := jogador.get_node_or_null("EspadaDaHistoria") if jogador != null else null
	var machado := jogador.get_node_or_null("MachadoDaHistoria") if jogador != null else null
	if espada != null and espada.ativa and is_instance_valid(espada.habilidades_da_lamina) and espada.habilidades_da_lamina.disponivel():
		_tecnicas.atualizar_lamina(espada.habilidades_da_lamina)
	elif espada != null and espada.ativa and is_instance_valid(espada.giro) and espada.giro.ligado:
		_tecnicas.atualizar_espada(espada.giro.ativo, jogador)
	elif machado != null and machado.ativa and is_instance_valid(machado.habilidades):
		_tecnicas.atualizar_machado(machado.habilidades)
	elif GoroGoroMinePiece.de(jogador) != null and GoroGoroMinePiece.de(jogador).fruta_ativa():
		_tecnicas.atualizar_goro_mine_piece(GoroGoroMinePiece.de(jogador))
	elif ControladorFrutaMinePiece.de(jogador) != null and ControladorFrutaMinePiece.de(jogador).fruta_ativa():
		var mp := ControladorFrutaMinePiece.de(jogador)
		_tecnicas.atualizar_mine_piece(mp, mp.fruta_id, PerfilDeFrutas.nome_da_fruta(mp.fruta_id))
	else:
		_tecnicas.atualizar(jogador, _barra != null and _barra.progressao != null \
			and _barra.progressao.item_em_uso() in ["fruta", "luta"])
	if _tempo_do_aviso > 0.0:
		_tempo_do_aviso -= delta
		if _tempo_do_aviso <= 0.0 and _aviso:
			_aviso.visible = false
	# Com o Status aberto o aviso some (e volta ao fechar, se ainda tiver tempo): na
	# frente ele caía em cima da linha de Raça e Nível; atrás, vazava pelo fundo
	# translúcido. A janela já mostra o nível novo.
	if _aviso:
		_aviso.visible = _tempo_do_aviso > 0.0 and not status_aberto()


func _jogador_local() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null


## ESC no Modo História: menu de pausa "Configurações" + "Salvar e sair" (25/11/2026). O menu inicial (com os modos de jogo) só abre em erro de mapa.
func toggle_main_menu() -> void:
	if _menu == null or not (_menu is MenuDePausa):
		if _menu != null:
			_menu.queue_free()
		_menu = MenuDePausa.new()
		_menu.setup(self)
		add_child(_menu)
		_menu.open_menu()
		return
	_menu.toggle()


func _abrir_menu_inicial() -> void:
	if _menu == null or _menu is MenuDePausa:
		if _menu != null:
			_menu.queue_free()
		_menu = MainMenuClass.new()
		_menu.name = "MainMenu"
		_menu.setup(self)
		add_child(_menu)
		_menu.open_menu()
		return
	_menu.toggle()


func is_menu_open() -> bool:
	return (_menu != null and _menu.is_open()) or fala_em_cena() or status_aberto() or ferramentas_abertas() \
		or inventario_aberto() or menu_de_pets_aberto() or loja_aberta() or tripulacao_aberta() or central_aberta()


## Mapa inválido: sem mundo não há jogador, então o ESC do Player não existe.
## Mostra o motivo e abre o menu para a pessoa escolher outro modo.
func mostrar_erro(texto: String) -> void:
	var fundo := PanelContainer.new()
	fundo.name = "ErroDoMapa"
	add_child(fundo)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	fundo.position.y = 24.0
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	fundo.add_child(rotulo)
	_abrir_menu_inicial()
	# O menu cobre a tela inteira; o aviso tem que ficar por cima dele.
	move_child(fundo, get_child_count() - 1)


func faixa_navegando() -> FaixaNavegando:
	return _faixa_navegando
