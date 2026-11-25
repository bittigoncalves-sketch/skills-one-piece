extends Node3D
# ============================================================================
#  EDITOR DE MAPA — orquestrador (etapa 2 do Modo História, docs/MODO_HISTORIA.md).
#
#  Estilo Roblox Studio, dentro do jogo. Edita o MESMO arquivo que o Modo História
#  lê (`ModoHistoria.MAPA_INICIAL`), e o "Testar" põe no mapa o MESMO jogador
#  Civil do modo (`ModoHistoria.colocar_civil`). Nada aqui tem cópia própria de
#  mapa ou de jogador.
#
#  QUEM FAZ O QUÊ
#  --------------
#    DocumentoMapa      o estado (sem nó)          HistoricoDeEdicao  desfazer
#    SelecaoDoEditor    o que está selecionado     OperacoesDoEditor  toda mudança
#    VistaDoMapa        a cena 3D e o clique       GizmoDoEditor      as alças
#    CameraLivre        voar                       Barra/Explorer/Propriedades
#  Este arquivo só traduz mouse e teclado em chamadas e mantém os painéis em dia.
#
#  ⚠️ `_input` × `_unhandled_input`. Começar algo (clique, olhar) é em
#  `_unhandled_input`: se o mouse está sobre um painel, o painel fica com o clique.
#  CONTINUAR (arrastar, olhar, soltar) é em `_input`: senão, passar o mouse por
#  cima de um painel no meio de um arraste congelaria a peça e o botão solto
#  nunca chegaria.
# ============================================================================

const ModoHistoria := preload("res://src/historia/ModoHistoria.gd")
const LIMIAR_DE_ARRASTE_PX := 5.0
const TEMPO_DO_AVISO := 4.0
const DICA := "Botão direito: olhar · WASD/QE: voar · F: enquadrar · H: hitboxes do mapa · Ctrl+H: alças na hitbox · Shift: sem grade · Ctrl+1-5: ferramentas (5 = relevo) · Ctrl+D duplica · Ctrl+G agrupa/separa · Alt+clique: peça dentro do grupo · Del apaga"

enum Modo { EDITANDO, TESTANDO }

## Arquivo editado. Trocável ANTES de entrar na árvore (o teste usa uma cópia).
var caminho_do_mapa: String = ModoHistoria.MAPA_INICIAL
## Biblioteca da loja. Nula = a do projeto (`mapas/modelos/`); o teste põe outra.
var biblioteca: BibliotecaDeModelos = null

var doc: DocumentoMapa
var historico: HistoricoDeEdicao
var selecao := SelecaoDoEditor.new()
var modo: int = Modo.EDITANDO
var ferramenta: int = GizmoDoEditor.Ferramenta.MOVER
## O gizmo está mexendo na PEÇA ou na HITBOX dela? (Ctrl+H alterna.) Volta para a
## peça sozinho ao trocar a seleção: alça que muda de dono sem avisar é armadilha.
var alvo_hitbox := false
var passo: float = BarraDoEditor.PASSO_INICIAL

var _vista: VistaDoMapa
var _camera: CameraLivre
var _gizmo: GizmoDoEditor
var _jogadores: Node3D
var _jogador: Node = null

var _interface: Control
var _barra: BarraDoEditor
var _explorer: ExplorerDoEditor
var _propriedades: PropriedadesDoEditor
var _loja: LojaDoEditor
var _lateral: Control
## Modo JANELAS (05/10/2026): o editor de janelas toma o lugar do 3D.
var _janelas: EditorDeJanelas
var _miniaturas: GeradorDeMiniaturas
var _fantasma: Label                  # nome do modelo seguindo o mouse no arraste da loja
var _arraste_loja := ""               # id do modelo sendo arrastado da loja
var _status: Label
var _retangulo: Panel
var _aviso_teste: Label
var _tempo_do_aviso := 0.0

var _clique: Dictionary = {}          # {ponto, aditivo} com o esquerdo apertado fora de alça
var _arraste: Dictionary = {}         # {info, foto} durante arraste de alça
var _explorer_pendente := false

## PINCEL DE RELEVO (Ctrl+5, 01/10/2026). Uma pincelada = do apertar ao soltar o
## botão esquerdo = UM passo de desfazer.
var pincel := PincelDeRelevo.new()
var _painel_do_pincel: PainelDoPincel
var _pincelando := false
var _alvo_aplainar := 0.0
var _mouse := Vector2.ZERO


func _ready() -> void:
	add_to_group("hud")
	WorldEnv.apply(self)
	if biblioteca == null:
		biblioteca = BibliotecaDeModelos.padrao()
	# Antes da vista: é o montador que resolve as peças `modelo` do mapa.
	MapaMontador.biblioteca = biblioteca
	_montar_interface()

	var lido := MapaArquivo.carregar(caminho_do_mapa)
	if not lido["ok"]:
		# Não abre um mapa vazio no lugar: "Salvar" gravaria o vazio por cima do
		# arquivo quebrado, e o conserto à mão viraria perda.
		_avisar("Não foi possível abrir %s:\n- %s" % [caminho_do_mapa, "\n- ".join(lido["erros"])], true)
		_tempo_do_aviso = INF
		return

	doc = DocumentoMapa.de_mapa(lido["mapa"])
	historico = HistoricoDeEdicao.new(doc)

	_vista = VistaDoMapa.new()
	_vista.name = "Vista"
	add_child(_vista)
	_vista.ligar(doc)

	_jogadores = Node3D.new()
	_jogadores.name = "Players"
	add_child(_jogadores)

	_camera = CameraLivre.new()
	_camera.name = "CameraLivre"
	add_child(_camera)
	_camera.current = true
	_camera.posicionar(doc.spawn + Vector3(14, 12, 14), doc.spawn)

	_gizmo = GizmoDoEditor.new()
	_gizmo.name = "Gizmo"
	add_child(_gizmo)
	_gizmo.configurar(_camera)

	_miniaturas = GeradorDeMiniaturas.new()
	_miniaturas.name = "Miniaturas"
	add_child(_miniaturas)
	_loja.contar_uso = func(modelo_id: String) -> int: return OperacoesDoEditor.usos_do_modelo(doc, modelo_id)
	_loja.configurar(biblioteca, _miniaturas)
	_propriedades.biblioteca = biblioteca

	_ligar_sinais()
	_definir_ferramenta(ferramenta)
	_explorer.reconstruir(doc, selecao)
	_propriedades.mostrar(doc, selecao)
	_barra.atualizar_historico(historico)
	_avisar("Mapa \"%s\" aberto — %d peças." % [doc.nome, doc.quantidade()])


func _exit_tree() -> void:
	# A biblioteca do montador é estática: um editor de teste não pode deixá-la
	# apontando para a pasta dele depois de sair.
	if MapaMontador.biblioteca == biblioteca:
		MapaMontador.biblioteca = null


func _process(delta: float) -> void:
	if modo == Modo.EDITANDO and doc != null and ferramenta == GizmoDoEditor.Ferramenta.RELEVO and not editando_janelas():
		_passo_do_pincel(delta)
	if _tempo_do_aviso > 0.0 and _tempo_do_aviso != INF:
		_tempo_do_aviso -= delta
		if _tempo_do_aviso <= 0.0:
			_status.text = DICA
			_status.add_theme_color_override("font_color", EstiloDoEditor.TEXTO_FRACO)


# ----------------------------------------------------- contrato com o Player
# O Player procura o grupo "hud". Editando, não há jogador; testando, o ESC dele
# chama `toggle_main_menu` — que aqui significa "voltar ao editor".
func is_menu_open() -> bool:
	return modo != Modo.TESTANDO


func toggle_main_menu() -> void:
	if modo == Modo.TESTANDO:
		parar_teste.call_deferred()


# --------------------------------------------------------------------- input
func _unhandled_input(evento: InputEvent) -> void:
	if modo != Modo.EDITANDO or doc == null:
		return
	if editando_janelas():
		if evento is InputEventKey and evento.pressed and not evento.echo:
			var k := evento as InputEventKey
			if (k.ctrl_pressed or k.meta_pressed) and k.physical_keycode == KEY_S:
				_janelas.salvar()
				get_viewport().set_input_as_handled()
			elif not k.ctrl_pressed and k.physical_keycode == KEY_J:
				alternar_janelas()
				get_viewport().set_input_as_handled()
		return
	if evento is InputEventMouseButton:
		var b := evento as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_RIGHT and b.pressed:
			_camera.tratar_evento(b)
			get_viewport().set_input_as_handled()
		elif _camera.tratar_roda(b):
			get_viewport().set_input_as_handled()
		elif b.button_index == MOUSE_BUTTON_LEFT and b.pressed and ferramenta == GizmoDoEditor.Ferramenta.RELEVO:
			get_viewport().gui_release_focus()
			_mouse = b.position
			_comecar_pincelada()
			get_viewport().set_input_as_handled()
		elif b.button_index == MOUSE_BUTTON_LEFT and b.pressed:
			# Clicar no 3D tira o foco do painel: confirma o número que estava sendo
			# digitado (o campo envia no `focus_exited`) e devolve WASD à câmera.
			get_viewport().gui_release_focus()
			var indice := _gizmo.alca_em(b.position)
			if indice >= 0:
				_comecar_arraste(indice, b.position)
			else:
				_clique = {"ponto": b.position, "aditivo": b.ctrl_pressed or b.shift_pressed, "alt": b.alt_pressed}
			get_viewport().set_input_as_handled()
	elif evento is InputEventMouseMotion:
		_mouse = (evento as InputEventMouseMotion).position
		_gizmo.destacar_sob(_mouse)
	elif evento is InputEventKey and evento.pressed and not evento.echo:
		if _atalho(evento as InputEventKey):
			get_viewport().set_input_as_handled()


func _input(evento: InputEvent) -> void:
	if modo != Modo.EDITANDO or doc == null or editando_janelas():
		return
	if not _arraste_loja.is_empty():
		_seguir_arraste_da_loja(evento)
		return
	if _pincelando:
		if evento is InputEventMouseMotion:
			_mouse = (evento as InputEventMouseMotion).position
		elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed:
			_terminar_pincelada()
			get_viewport().set_input_as_handled()
		elif evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
			_terminar_pincelada(true)
			get_viewport().set_input_as_handled()
		return
	if _camera.olhando():
		var solta := evento is InputEventMouseButton and (evento as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT
		if evento is InputEventMouseMotion or solta:
			_camera.tratar_evento(evento)
			get_viewport().set_input_as_handled()
		return
	if not _arraste.is_empty():
		if evento is InputEventMouseMotion:
			_mover_arraste((evento as InputEventMouseMotion).position)
			get_viewport().set_input_as_handled()
		elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed:
			terminar_arraste()
			get_viewport().set_input_as_handled()
		elif evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
			_cancelar_arraste()
			get_viewport().set_input_as_handled()
		return
	if not _clique.is_empty():
		if evento is InputEventMouseMotion:
			_desenhar_retangulo((evento as InputEventMouseMotion).position)
		elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed:
			soltar_clique((evento as InputEventMouseButton).position)
			get_viewport().set_input_as_handled()


func _atalho(k: InputEventKey) -> bool:
	var ctrl := k.ctrl_pressed or k.meta_pressed
	if ctrl:
		match k.physical_keycode:
			KEY_1: _definir_ferramenta(GizmoDoEditor.Ferramenta.SELECIONAR)
			KEY_2: _definir_ferramenta(GizmoDoEditor.Ferramenta.MOVER)
			KEY_3: _definir_ferramenta(GizmoDoEditor.Ferramenta.ESCALAR)
			KEY_4: _definir_ferramenta(GizmoDoEditor.Ferramenta.GIRAR)
			KEY_5: _definir_ferramenta(GizmoDoEditor.Ferramenta.RELEVO)
			KEY_D: duplicar()
			KEY_G: agrupar_ou_separar()
			KEY_H: alternar_alvo_da_hitbox()
			KEY_S: salvar()
			KEY_Z:
				if k.shift_pressed: refazer()
				else: desfazer()
			KEY_Y: refazer()
			_: return false
		return true
	if ferramenta == GizmoDoEditor.Ferramenta.RELEVO and k.keycode in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
		var fator := 1.15 if k.keycode == KEY_BRACKETRIGHT else 1.0 / 1.15
		pincel.raio = clampf(pincel.raio * fator, PincelDeRelevo.RAIO_MIN, PincelDeRelevo.RAIO_MAX)
		_painel_do_pincel.atualizar()
		return true
	match k.keycode:
		KEY_DELETE, KEY_BACKSPACE: apagar()
		KEY_F: enquadrar()
		KEY_H: alternar_hitboxes()
		KEY_J: alternar_janelas()
		KEY_F5: testar()
		KEY_ESCAPE: selecao.limpar()
		_: return false
	return true


# ------------------------------------------------------------ clique e arraste
func soltar_clique(ponto: Vector2) -> void:
	if _clique.is_empty():
		return
	var inicio: Vector2 = _clique["ponto"]
	var aditivo: bool = _clique["aditivo"]
	var dentro_do_grupo: bool = _clique.get("alt", false)
	_clique = {}
	_retangulo.visible = false
	if inicio.distance_to(ponto) >= LIMIAR_DE_ARRASTE_PX:
		var ids: Array[String] = []
		for achado in _vista.ids_no_retangulo(_camera, Rect2(inicio, ponto - inicio).abs()):
			var item := achado if achado == SelecaoDoEditor.SPAWN else doc.raiz_de(achado)
			if not ids.has(item):
				ids.append(item)
		if aditivo:
			ids.append_array(selecao.ids())
		selecao.definir(ids)
		return
	var id := _vista.escolher(_camera, ponto)
	# Clique pega o grupo mais de fora (como um Model do Roblox); Alt pega a peça.
	if not id.is_empty() and id != SelecaoDoEditor.SPAWN and not dentro_do_grupo:
		id = doc.raiz_de(id)
	if id.is_empty():
		if not aditivo:
			selecao.limpar()
	elif aditivo:
		selecao.alternar(id)
	else:
		selecao.definir([id])


func _desenhar_retangulo(ponto: Vector2) -> void:
	var inicio: Vector2 = _clique["ponto"]
	if inicio.distance_to(ponto) < LIMIAR_DE_ARRASTE_PX:
		return
	var r := Rect2(inicio, ponto - inicio).abs()
	_retangulo.position = r.position
	_retangulo.size = r.size
	_retangulo.visible = true


func _comecar_arraste(indice: int, ponto: Vector2) -> void:
	var info := _gizmo.comecar(indice, ponto)
	if info["tipo"] == "face" and (selecao.pecas().size() != 1 or selecao.tem_spawn()):
		_gizmo.terminar()
		return
	var nome: String = {"seta": "Mover", "face": "Escalar", "anel": "Girar"}[info["tipo"]]
	historico.iniciar(nome + (" hitbox" if alvo_hitbox else ""))
	_arraste = {"info": info, "foto": OperacoesDoEditor.foto(doc, selecao)}


func _mover_arraste(ponto: Vector2) -> void:
	var info: Dictionary = _arraste["info"]
	var livre := Input.is_key_pressed(KEY_SHIFT)
	var bruto := _gizmo.valor(ponto)
	# Anel: grade de 15° sempre que o Shift não está apertado, com ou sem grade de
	# metros (girar e mover têm incrementos independentes, como no Roblox).
	var passo_do_arraste := (0.0 if livre else 1.0) if info["tipo"] == "anel" else (0.0 if livre else passo)
	if alvo_hitbox:
		OperacoesDoEditor.aplicar_arraste_hitbox(doc, _arraste["foto"], info, bruto, passo_do_arraste)
	else:
		OperacoesDoEditor.aplicar_arraste(doc, _arraste["foto"], info, bruto, passo_do_arraste)
	var eixo: String = "XYZ"[info["eixo"]]
	match info["tipo"]:
		"seta":
			_avisar("Mover %s: %s m" % [eixo, _num(GizmoMatematica.grudar(bruto, passo_do_arraste))])
		"face":
			_avisar("Escalar %s%s: %s m" % ["+" if info["sinal"] > 0 else "−", eixo, _num(GizmoMatematica.grudar(bruto, passo_do_arraste))])
		"anel":
			var graus := rad_to_deg(bruto)
			_avisar("Girar %s: %s°" % [eixo, _num(snappedf(graus, OperacoesDoEditor.PASSO_GIRAR_GRAUS) if not livre else graus)])


func terminar_arraste() -> void:
	if _arraste.is_empty():
		return
	_gizmo.terminar()
	historico.concluir()
	_arraste = {}
	_atualizar_gizmo()


func _cancelar_arraste() -> void:
	_gizmo.terminar()
	historico.cancelar()
	_arraste = {}
	_atualizar_gizmo()
	_avisar("Arraste cancelado.")


# ------------------------------------------------------------ loja no mapa
## Modelo da loja no mapa: no centro da tela, ou no ponto de tela dado (arraste).
func inserir_modelo(modelo_id: String, ponto_tela: Variant = null) -> String:
	if doc == null or modo != Modo.EDITANDO or not biblioteca.tem(modelo_id):
		return ""
	# Tamanho PADRÃO (30/09/2026): a casa entra do tamanho de uma casa, não do
	# tamanho minúsculo em que o arquivo veio. Sem padrão, é o do arquivo.
	var tamanho: Vector3 = biblioteca.tamanho_padrao(modelo_id)
	var ponto := _vista.ponto_de_insercao(_camera, tamanho.y) if ponto_tela == null \
		else _vista.ponto_sob(_camera, ponto_tela, tamanho.y)
	var id := OperacoesDoEditor.inserir_modelo(doc, historico, selecao, modelo_id, tamanho, ponto, passo,
		not biblioteca.atravessavel(modelo_id))
	if ferramenta == GizmoDoEditor.Ferramenta.SELECIONAR:
		_definir_ferramenta(GizmoDoEditor.Ferramenta.MOVER)
	_avisar("Inserido \"%s\" como \"%s\"." % [biblioteca.info(modelo_id)["nome"], id])
	return id


func comecar_arraste_da_loja(modelo_id: String) -> void:
	if not biblioteca.tem(modelo_id):
		return
	_arraste_loja = modelo_id
	_fantasma.text = "◆ " + str(biblioteca.info(modelo_id)["nome"])
	_fantasma.position = get_viewport().get_mouse_position() + Vector2(14, 10)
	_fantasma.visible = true


func _seguir_arraste_da_loja(evento: InputEvent) -> void:
	if evento is InputEventMouseMotion:
		_fantasma.position = (evento as InputEventMouseMotion).position + Vector2(14, 10)
		get_viewport().set_input_as_handled()
	elif evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT and not evento.pressed:
		var modelo_id := _arraste_loja
		var ponto := (evento as InputEventMouseButton).position
		_arraste_loja = ""
		_fantasma.visible = false
		get_viewport().set_input_as_handled()
		if sobre_painel(ponto):
			_avisar("Solte o modelo sobre o mapa, não sobre um painel.")
		else:
			inserir_modelo(modelo_id, ponto)
	elif evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		_arraste_loja = ""
		_fantasma.visible = false
		get_viewport().set_input_as_handled()


## O ponto da tela cai em cima de barra, loja ou painel lateral?
func sobre_painel(ponto: Vector2) -> bool:
	for painel: Control in [_barra, _loja, _interface.get_node("Lateral")]:
		if painel.visible and painel.get_global_rect().has_point(ponto):
			return true
	return false


# ----------------------------------------------------------------- operações
func inserir(tipo: String) -> String:
	if doc == null or modo != Modo.EDITANDO:
		return ""
	var ponto := _vista.ponto_de_insercao(_camera, DocumentoMapa.TAMANHO_PADRAO.y)
	var id := OperacoesDoEditor.inserir(doc, historico, selecao, tipo, ponto, passo)
	if ferramenta == GizmoDoEditor.Ferramenta.SELECIONAR:
		_definir_ferramenta(GizmoDoEditor.Ferramenta.MOVER)
	_avisar("Inserida %s \"%s\"." % [OperacoesDoEditor.ROTULO_TIPO[tipo].to_lower(), id])
	return id


func duplicar() -> void:
	var novos := OperacoesDoEditor.duplicar(doc, historico, selecao)
	if not novos.is_empty():
		_avisar("%d peça(s) duplicada(s)." % novos.size())


## Ctrl+G: 2+ itens → agrupa; um grupo → separa um nível (o último agrupado sai
## primeiro, porque grupo de dentro continua inteiro).
func agrupar_ou_separar() -> void:
	if doc == null or modo != Modo.EDITANDO:
		return
	var itens := selecao.pecas()
	if itens.size() >= 2:
		var gid := OperacoesDoEditor.agrupar(doc, historico, selecao)
		if not gid.is_empty():
			_avisar("Agrupado em \"%s\" (%d peças). Ctrl+G de novo separa." % [gid, doc.pecas_de(gid).size()])
	elif itens.size() == 1 and doc.tem_grupo(itens[0]):
		var nome := itens[0]
		var filhos := OperacoesDoEditor.desagrupar(doc, historico, selecao)
		_avisar("Grupo \"%s\" separado em %d item(ns)." % [nome, filhos.size()])
	elif itens.size() == 1:
		_avisar("Selecione 2 ou mais itens para agrupar (Ctrl/Shift+clique).")


func apagar() -> void:
	var n := OperacoesDoEditor.apagar(doc, historico, selecao)
	if n > 0:
		_avisar("%d peça(s) apagada(s). Ctrl+Z desfaz." % n)
	elif selecao.tem_spawn():
		_avisar("O spawn não pode ser apagado — só movido.", true)


func desfazer() -> void:
	var nome := historico.nome_do_desfazer()
	var ids := historico.desfazer()
	_depois_do_historico(ids, "Desfeito: %s" % nome)


func refazer() -> void:
	var nome := historico.nome_do_refazer()
	var ids := historico.refazer()
	_depois_do_historico(ids, "Refeito: %s" % nome)


func _depois_do_historico(ids: Array[String], texto: String) -> void:
	if texto.ends_with(": "):
		return
	if not ids.is_empty():
		selecao.definir(ids)
	else:
		selecao.podar(doc)
	_avisar(texto)


func enquadrar() -> void:
	if selecao.vazia():
		return
	var c := OperacoesDoEditor.centro(doc, selecao)
	_camera.enquadrar(c, OperacoesDoEditor.raio(doc, selecao, c))


func salvar() -> Error:
	if doc == null:
		return ERR_UNCONFIGURED
	var erro := MapaArquivo.salvar(caminho_do_mapa, doc.para_mapa())
	if erro == OK:
		doc.marcar_salvo()
		_avisar("Salvo em %s." % caminho_do_mapa)
	elif OS.has_feature("template"):
		# Jogo exportado: `res://` é só leitura. Declarado em docs/MODO_HISTORIA.md.
		_avisar("Não dá para salvar o mapa num jogo exportado — rode pelo projeto (./jogar.sh).", true)
	else:
		_avisar("Falha ao salvar %s: %s" % [caminho_do_mapa, error_string(erro)], true)
	return erro


# ---------------------------------------------------------------- testar
func testar() -> void:
	if doc == null or modo != Modo.EDITANDO:
		return
	if not _arraste.is_empty():
		_cancelar_arraste()
	_terminar_pincelada()
	_vista.desenhar_pincel(null, 0.0, Color.WHITE)
	_painel_do_pincel.visible = false
	_clique = {}
	_retangulo.visible = false
	get_viewport().gui_release_focus()
	modo = Modo.TESTANDO
	_gizmo.esconder()
	_vista.modo_teste(true)
	_camera.ativa = false
	_interface.visible = false
	_aviso_teste.visible = true
	# O mapa em memória, como está AGORA — inclusive o que ainda não foi salvo.
	_jogador = ModoHistoria.colocar_civil(_jogadores, multiplayer.get_unique_id(), doc.spawn)
	# Números do documento (20 de vida, 10 de energia) com um Civil NOVO: testar o
	# mapa não lê nem grava o progresso salvo de quem joga.
	ModoHistoria.aplicar_progressao(_jogador, ProgressaoDoPersonagem.new(), true)


func parar_teste() -> void:
	if modo != Modo.TESTANDO:
		return
	if is_instance_valid(_jogador):
		_jogador.queue_free()
	_jogador = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modo = Modo.EDITANDO
	_camera.ativa = true
	_camera.make_current()
	_vista.modo_teste(false)
	_interface.visible = true
	_painel_do_pincel.visible = ferramenta == GizmoDoEditor.Ferramenta.RELEVO
	_aviso_teste.visible = false
	_atualizar_gizmo()
	_avisar("De volta ao editor.")


func jogador_do_teste() -> Node:
	return _jogador


# ------------------------------------------------------------------- sair
func sair() -> void:
	if doc != null and doc.sujo:
		var dialogo := ConfirmationDialog.new()
		dialogo.title = "Alterações não salvas"
		dialogo.dialog_text = "O mapa tem alterações que ainda não foram salvas."
		dialogo.ok_button_text = "Salvar e sair"
		dialogo.cancel_button_text = "Cancelar"
		dialogo.add_button("Sair sem salvar", true, "descartar")
		dialogo.confirmed.connect(func():
			if salvar() == OK:
				_voltar_ao_menu()
		)
		dialogo.custom_action.connect(func(acao):
			if acao == "descartar":
				_voltar_ao_menu()
		)
		add_child(dialogo)
		dialogo.popup_centered()
		return
	_voltar_ao_menu()


func _voltar_ao_menu() -> void:
	# Por nó, não pelo identificador do autoload: assim o script também compila em
	# `godot -s` (os testes), onde autoload não vira identificador.
	var fluxo := get_node_or_null("/root/GameFlow")
	if fluxo:
		fluxo.back_to_menu()


# --------------------------------------------------------- painéis e sinais
func _ligar_sinais() -> void:
	doc.peca_adicionada.connect(func(_id): _reconstruir_explorer())
	doc.peca_removida.connect(func(_id):
		selecao.podar(doc)
		_reconstruir_explorer()
	)
	doc.ordem_mudou.connect(_reconstruir_explorer)
	doc.hierarquia_mudou.connect(func():
		selecao.podar(doc)
		_reconstruir_explorer()
	)
	doc.peca_mudou.connect(func(id):
		_explorer.atualizar_peca(doc, id)
		# Mexer na hitbox muda a PEÇA: o desenho tem que acompanhar, e acompanha
		# também quando o mapa inteiro está visível (tecla H).
		if _selecao_toca(id) or _vista.vendo_todas_as_hitboxes():
			_vista.desenhar_hitboxes(selecao.ids())
		if _selecao_toca(id):
			_propriedades.atualizar()
			_atualizar_gizmo()
	)
	doc.spawn_mudou.connect(func():
		if selecao.tem_spawn():
			_propriedades.atualizar()
			_atualizar_gizmo()
	)
	doc.sujo_mudou.connect(_barra.marcar_sujo)
	historico.mudou.connect(func(): _barra.atualizar_historico(historico))
	selecao.mudou.connect(func():
		if alvo_hitbox:
			alvo_hitbox = false
			_barra.marcar_alvo_hitbox(false)
		_explorer.mostrar_selecao(selecao.ids())
		_propriedades.mostrar(doc, selecao)
		_vista.desenhar_selecao(selecao.ids())
		_vista.desenhar_hitboxes(selecao.ids())
		_atualizar_gizmo()
	)

	_barra.ferramenta_escolhida.connect(_definir_ferramenta)
	_barra.hitboxes_pedido.connect(alternar_hitboxes)
	_barra.janelas_pedido.connect(alternar_janelas)
	_barra.inserir_pedido.connect(func(tipo): inserir(tipo))
	_barra.passo_escolhido.connect(func(p): passo = p)
	_barra.desfazer_pedido.connect(desfazer)
	_barra.refazer_pedido.connect(refazer)
	_barra.salvar_pedido.connect(func(): salvar())
	_barra.testar_pedido.connect(testar)

	_explorer.selecao_pedida.connect(func(ids): selecao.definir(ids))
	_explorer.renomear_pedido.connect(func(antigo, novo):
		var motivo := OperacoesDoEditor.renomear(doc, historico, selecao, antigo, novo)
		if motivo.is_empty():
			_reconstruir_explorer()
		else:
			_avisar(motivo, true)
	)
	_propriedades.alterar_pedido.connect(func(campo, valor):
		OperacoesDoEditor.alterar(doc, historico, selecao, campo, valor)
	)
	_propriedades.aplicar_hitbox_pedido.connect(func():
		var pecas := selecao.pecas()
		if pecas.size() != 1:
			return
		var quantas := OperacoesDoEditor.aplicar_hitbox_em_iguais(doc, historico, pecas[0])
		_avisar("Hitbox aplicada em %d peça(s) iguais. Ctrl+Z desfaz tudo de uma vez." % quantas)
	)
	_propriedades.cor_ao_vivo.connect(func(cor):
		if not historico.aberta():
			historico.iniciar("Alterar cor")
		OperacoesDoEditor.alterar_sem_historico(doc, selecao, "cor", cor)
	)
	_propriedades.cor_fechada.connect(func(): historico.concluir())

	_loja.inserir_pedido.connect(func(modelo_id): inserir_modelo(modelo_id))
	_loja.arraste_pedido.connect(comecar_arraste_da_loja)
	_loja.aviso.connect(_avisar)
	_loja.biblioteca_mudou.connect(func():
		_vista.remontar_modelos()
		_propriedades.mostrar(doc, selecao)
	)


## A peça está selecionada, direto ou dentro de um grupo selecionado?
func _selecao_toca(id: String) -> bool:
	for item in selecao.pecas():
		if item == id or doc.dentro_de(id, item):
			return true
	return false


func _reconstruir_explorer() -> void:
	# Um "desfazer apagar 30 peças" emite 30 inclusões: reconstrói a lista uma vez.
	if _explorer_pendente:
		return
	_explorer_pendente = true
	_reconstruir_explorer_agora.call_deferred()


func _reconstruir_explorer_agora() -> void:
	_explorer_pendente = false
	_explorer.reconstruir(doc, selecao)


## J: troca o 3D pelo EDITOR DE JANELAS e volta. No modo janelas a loja, o painel da
## direita e a câmera do 3D saem de cena, e os atalhos do 3D (Del, F, WASD…) ficam
## desligados — Ctrl+S passa a salvar o layout das janelas.
func alternar_janelas() -> void:
	var ligar := not _janelas.ativo()
	if ligar:
		_janelas.biblioteca = biblioteca if biblioteca != null else MapaMontador.biblioteca_em_uso()
		_janelas.abrir()
	else:
		_janelas.fechar()
	_loja.visible = not ligar
	_lateral.visible = not ligar
	if ligar:
		_painel_do_pincel.visible = false
	elif ferramenta == GizmoDoEditor.Ferramenta.RELEVO:
		_painel_do_pincel.visible = true
	_camera.set_process(not ligar)
	_gizmo.visible = not ligar
	_barra.marcar_janelas(ligar)
	_avisar("Editor de janelas: %s" % ("escolha uma janela à esquerda" if ligar else "de volta ao 3D"))


func editando_janelas() -> bool:
	return _janelas != null and _janelas.ativo()


## H: mostra as hitboxes do mapa INTEIRO. A da peça selecionada aparece sempre —
## isto é para varrer o mapa atrás de colisão sobrando ou faltando.
func alternar_hitboxes() -> void:
	var ligado := not _vista.vendo_todas_as_hitboxes()
	_vista.ver_todas_as_hitboxes(ligado)
	_barra.marcar_hitboxes(ligado)
	_avisar("Hitboxes do mapa: %s" % ("visíveis" if ligado else "só a da seleção"))


## Ctrl+H: as alças passam a mexer na HITBOX da peça, e não na peça.
func alternar_alvo_da_hitbox() -> void:
	var pecas := selecao.pecas()
	if pecas.size() != 1 or selecao.tem_spawn() or not doc.tem(pecas[0]):
		_avisar("Selecione UMA peça para ajustar a hitbox dela.", true)
		return
	alvo_hitbox = not alvo_hitbox
	if alvo_hitbox and not doc.peca(pecas[0]).has("hitbox"):
		# Entrar no modo já LIGA a hitbox própria, partindo do volume de hoje: sem
		# isso a primeira alça arrastada não teria o que mover.
		OperacoesDoEditor.alterar(doc, historico, selecao, "hitbox.usar", true)
	_barra.marcar_alvo_hitbox(alvo_hitbox)
	_avisar("Gizmo em: %s (Ctrl+H alterna)" % ("HITBOX" if alvo_hitbox else "peça"))
	_atualizar_gizmo()


func _definir_ferramenta(f: int) -> void:
	if _pincelando and f != GizmoDoEditor.Ferramenta.RELEVO:
		_terminar_pincelada()
	ferramenta = f
	if _gizmo:
		_gizmo.ferramenta = f
	_barra.marcar_ferramenta(f)
	if _painel_do_pincel:
		_painel_do_pincel.visible = f == GizmoDoEditor.Ferramenta.RELEVO
		_painel_do_pincel.atualizar()
	if f != GizmoDoEditor.Ferramenta.RELEVO and _vista:
		_vista.desenhar_pincel(null, 0.0, Color.WHITE)
	_atualizar_gizmo()


# ------------------------------------------------------------ pincel de relevo
func _comecar_pincelada() -> void:
	var centro: Variant = _vista.ponto_no_relevo(_camera, _mouse)
	if centro == null:
		_avisar("Pincel de relevo: aponte para um bloco de terreno.")
		return
	_pincelando = true
	_alvo_aplainar = (centro as Vector3).y
	historico.iniciar("Pintar solo" if pincel.modo == PincelDeRelevo.Modo.PINTAR else "Esculpir relevo")


## `cancelar` (ESC): desfaz a pincelada em andamento sem guardar passo.
func _terminar_pincelada(cancelar := false) -> void:
	if not _pincelando:
		return
	_pincelando = false
	if cancelar:
		historico.cancelar()
	else:
		historico.concluir()


func _passo_do_pincel(delta: float) -> void:
	var centro: Variant = _vista.ponto_no_relevo(_camera, _mouse)
	var abaixar := Input.is_key_pressed(KEY_SHIFT)
	var cor := Color(1.0, 0.85, 0.3)
	match pincel.modo:
		PincelDeRelevo.Modo.ELEVAR:
			cor = Color(1.0, 0.45, 0.35) if abaixar else Color(0.45, 1.0, 0.5)
		PincelDeRelevo.Modo.PINTAR:
			cor = Color(0.4, 0.75, 1.0)
	_vista.desenhar_pincel(centro, pincel.raio, cor)
	if _pincelando and centro != null:
		# Teto no passo: um quadro travado não vira um morro de uma vez.
		pincel.aplicar(doc, centro, minf(delta, 0.05), abaixar, _alvo_aplainar)


func _atualizar_gizmo() -> void:
	if _gizmo == null:
		return
	if modo != Modo.EDITANDO or selecao.vazia() or ferramenta == GizmoDoEditor.Ferramenta.SELECIONAR \
			or ferramenta == GizmoDoEditor.Ferramenta.RELEVO:
		_gizmo.esconder()
		return
	if alvo_hitbox:
		var so := selecao.pecas()
		if so.size() != 1 or selecao.tem_spawn() or not doc.tem(so[0]):
			_gizmo.esconder()
			return
		var pose := OperacoesDoEditor.pose_da_hitbox(doc, so[0])
		_gizmo.mostrar(pose["centro"], pose["base"], pose["meio"])
		return
	if ferramenta == GizmoDoEditor.Ferramenta.ESCALAR:
		var pecas := selecao.pecas()
		if pecas.size() != 1 or selecao.tem_spawn() or not doc.tem(pecas[0]):
			_gizmo.esconder()
			return
		var p := doc.peca(pecas[0])
		_gizmo.mostrar(p["posicao"], Basis.from_euler((p["rotacao_graus"] as Vector3) * (PI / 180.0)),
			(p["tamanho"] as Vector3) * 0.5)
		return
	_gizmo.mostrar(OperacoesDoEditor.centro(doc, selecao), Basis.IDENTITY, Vector3.ZERO)


func _montar_interface() -> void:
	var camada := CanvasLayer.new()
	camada.name = "Interface"
	add_child(camada)
	_interface = Control.new()
	_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_interface)

	_barra = BarraDoEditor.new()
	_interface.add_child(_barra)
	_barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 8)
	_barra.sair_pedido.connect(sair)

	var lateral := VBoxContainer.new()
	_lateral = lateral
	lateral.name = "Lateral"
	lateral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Segunda garantia contra painel crescendo para fora da tela: o que não couber
	# é cortado na borda, em vez de empurrar o painel (ver `EstiloDoEditor.explicacao`).
	lateral.clip_contents = true
	_interface.add_child(lateral)
	lateral.anchor_left = 1.0
	lateral.anchor_right = 1.0
	lateral.anchor_bottom = 1.0
	lateral.offset_left = -310.0
	lateral.offset_right = -8.0
	lateral.offset_top = 56.0
	lateral.offset_bottom = -34.0
	_explorer = ExplorerDoEditor.new()
	_explorer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lateral.add_child(_explorer)
	_propriedades = PropriedadesDoEditor.new()
	_propriedades.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_propriedades.size_flags_stretch_ratio = 1.4
	lateral.add_child(_propriedades)

	# A loja à esquerda, na mesma faixa vertical do painel lateral da direita.
	_loja = LojaDoEditor.new()
	_loja.name = "Loja"
	_interface.add_child(_loja)
	_loja.anchor_bottom = 1.0
	_loja.offset_left = 8.0
	_loja.offset_right = 228.0
	_loja.offset_top = 56.0
	_loja.offset_bottom = -34.0

	_fantasma = EstiloDoEditor.rotulo("", false, 14)
	# Contorno escuro: texto branco puro sumia sobre o chão cinza-claro (captura
	# do arraste, 14/09/2026).
	_fantasma.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_fantasma.add_theme_constant_override("outline_size", 5)
	_fantasma.visible = false
	_fantasma.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_painel_do_pincel = PainelDoPincel.new(pincel)
	_painel_do_pincel.name = "PainelDoPincel"
	_painel_do_pincel.visible = false
	_interface.add_child(_painel_do_pincel)
	_painel_do_pincel.anchor_left = 0.5
	_painel_do_pincel.anchor_right = 0.5
	_painel_do_pincel.anchor_top = 1.0
	_painel_do_pincel.anchor_bottom = 1.0
	_painel_do_pincel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_painel_do_pincel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_painel_do_pincel.offset_bottom = -34.0
	# Centro da faixa LIVRE do 3D (loja 228 px à esquerda, lateral 310 px à direita),
	# não o centro da tela.
	_painel_do_pincel.offset_left = (228.0 - 310.0) * 0.5
	_painel_do_pincel.offset_right = (228.0 - 310.0) * 0.5

	_janelas = EditorDeJanelas.new()
	_interface.add_child(_janelas)
	_janelas.aviso.connect(_avisar)

	_status = EstiloDoEditor.rotulo(DICA, true)
	_interface.add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 10)

	_retangulo = Panel.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(EstiloDoEditor.DESTAQUE, 0.15)
	estilo.border_color = EstiloDoEditor.DESTAQUE
	estilo.set_border_width_all(1)
	_retangulo.add_theme_stylebox_override("panel", estilo)
	_retangulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_retangulo.visible = false
	_interface.add_child(_retangulo)
	_interface.add_child(_fantasma)

	_aviso_teste = EstiloDoEditor.rotulo("TESTANDO O MAPA — ESC volta ao editor", false, 16)
	_aviso_teste.visible = false
	camada.add_child(_aviso_teste)
	_aviso_teste.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)


func _avisar(texto: String, erro := false) -> void:
	if _status == null:
		return
	_status.text = texto
	_status.add_theme_color_override("font_color", EstiloDoEditor.ERRO if erro else EstiloDoEditor.TEXTO)
	_tempo_do_aviso = TEMPO_DO_AVISO
	if erro:
		push_warning("[Editor de mapa] " + texto)


static func _num(v: float) -> String:
	return PropriedadesDoEditor._numero(v).replace(".", ",")
