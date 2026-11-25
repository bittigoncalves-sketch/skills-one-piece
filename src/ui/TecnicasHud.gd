class_name TecnicasHud
extends Control
# ============================================================================
#  AS TÉCNICAS DO ITEM ATIVO NA TELA — Modo História (22/09/2026).
#
#  Uma linha por tecla da FICHA do modo (`PerfilDeFrutas`), com nome, recarga e
#  custo de energia. A espada usa a mesma janela, com Z e o estado do giro.
#
#  03/10/2026 (pedido do dono): é o MENU da fruta — só aparece com a fruta ATIVA na
#  barra de itens e mostra, de cada técnica, o tempo que ela leva para recarregar se
#  for usada ("recarga 6 s"); usada, a contagem regressiva; sem energia, o custo.
#
#  Por que não a `SkillBar` da arena: ela desenha os quatro slots fixos Z/X/C/V a
#  partir do `SkillSystem`, e o kit da história vem do perfil (hoje Z, X, C e F —
#  sem V). Adaptá-la mexeria no HUD da arena para ganhar nada. GATILHO: se a
#  história ganhar barra de técnicas igual à da arena, juntar as duas.
#
#  Lê o corpo a cada quadro, como as barras de vida/energia: recarga e energia
#  mudam por caminhos demais para valer um sinal de cada.
#
#  ⚠️ Não cita `Player`: quem entrega o corpo é a `HistoriaHud` (um script de teste
#  que cite o Player antes dos autoloads o envenena no cache).
# ============================================================================

const LARGURA := 440.0   # 390 antes (300 antes disso): "sem energia (500 ⚡)" e "100 ⚡ · recarga 7,5 s" (~170 px a 13 px) invadiam o nome na Mera — captura de 24/11/2026
const ALTURA_DA_LINHA := 26.0
const LARGURA_DO_ESTADO := 175.0   # o maior estado ("100 ⚡ · recarga 15 s", "sem energia (1000 ⚡)") a 13 px mede ~170 px
const ALTURA_DO_TITULO := 26.0
const MARGEM := 20.0
const RECUO := 10.0
## Editor de janelas (05/10/2026): o id desta janela no layout salvo.
const ID_DO_LAYOUT := "tecnicas"

var _titulo: Label
var _linhas := {}   # slot → {raiz, nome, estado}
var _fruta := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	visible = false


## Mostra as técnicas de `jogador` (nulo, sem fruta ou sem perfil = escondido).
## `fruta_ativa` = a fruta é o item ativo da barra (sem ela, o menu some).
func atualizar(jogador: Node, fruta_ativa := true) -> void:
	var perfil: PerfilDeFrutas = jogador.perfil_de_frutas if jogador != null and is_instance_valid(jogador) else null
	visible = fruta_ativa and perfil != null and not perfil.slots().is_empty()
	if not visible:
		return
	if perfil.fruta != _fruta:
		_montar(perfil)
	for slot in _linhas:
		_bloquear_linha(slot, false)
		if slot == "F" and perfil.fruta == "hie_hie":
			var estado_bici: Label = _linhas[slot]["estado"]
			estado_bici.text = "F para desmontar" if jogador.get_meta("bicicleta_gelo", false) else "F para montar"
			continue
		if perfil.fruta == "tori_tori_phoenix" and slot in ["Z", "F"]:
			var fenix: Node = jogador.get_node_or_null("Phoenix")
			var situacao: Label = _linhas[slot]["estado"]
			if fenix != null and slot == "F":
				situacao.text = "F: pousar · %.0fs" % fenix.voo if fenix.voo > 0 else ("F: decolar" if fenix.transformado else "use Z primeiro")
				continue
			if fenix != null and fenix.transformado:
				situacao.text = "Z: reverter"
				continue
		var t := perfil.tecnica(slot)
		var recarga := float(jogador.get("_fruit_cooldowns").get(slot, 0.0)) if jogador.get("_fruit_cooldowns") != null else 0.0
		# O custo vem do corpo (`custo_de_energia_do_cast`, a fonte única): no Kit do Builder
		# a ficha guarda uma FRAÇÃO, e o número de verdade depende da energia máxima.
		var custo: float = jogador.custo_de_energia_do_cast(slot) if jogador.has_method("custo_de_energia_do_cast") else (t.custo_de_energia if t != null else 0.0)
		# Tecla sem ficha (o F do Builder): a recarga é a do corpo.
		var recarga_total: float = t.recarga if t != null else (jogador.recarga_do_cast(slot) if jogador.has_method("recarga_do_cast") else 0.0)
		var sem_energia: bool = float(jogador.energy) + 0.001 < custo
		var bloqueada := custo > float(jogador.max_energy) + 0.001
		_bloquear_linha(slot, bloqueada)
		var estado: Label = _linhas[slot]["estado"]
		var nome: Label = _linhas[slot]["nome"]
		if bloqueada:
			estado.text = "requer %s ⚡" % _segundos(custo)
			estado.add_theme_color_override("font_color", Estilo.APAGADO)
		elif recarga > 0.05:
			estado.text = "faltam %s s" % _segundos(recarga)
			estado.add_theme_color_override("font_color", Estilo.APAGADO)
		elif sem_energia:
			estado.text = "sem energia (%s ⚡)" % _segundos(custo)
			estado.add_theme_color_override("font_color", Estilo.AVISO)
		else:
			estado.text = "recarga %s s" % _segundos(recarga_total)
			estado.add_theme_color_override("font_color", Estilo.LIGADO)
		nome.add_theme_color_override("font_color",
			Estilo.APAGADO if recarga > 0.05 or sem_energia else Color(1, 1, 1))


func atualizar_espada(girando: bool, jogador: Node = null) -> void:
	visible = true
	if _fruta != "espada":
		_montar_linhas("espada", "Espada", {"Z": "Giro cortante"})
	var estado: Label = _linhas["Z"]["estado"]
	estado.text = "imune · Z cancela" if girando else "Z para girar"
	estado.add_theme_color_override("font_color", Estilo.AVISO if girando else Estilo.LIGADO)
	var custo: float = preload("res://src/historia/equipamentos/giro_da_espada.gd").CUSTO
	var bloqueada := jogador != null and not girando and float(jogador.get("max_energy")) < custo
	_bloquear_linha("Z", bloqueada)
	if bloqueada: estado.text = "requer %s ⚡" % _segundos(custo)
	elif jogador != null and not girando and float(jogador.get("energy")) < custo: estado.text = "sem energia (%s ⚡)" % _segundos(custo)


## Machado na mão (17/10/2026): Z (arremesso) e X (corte), com recarga e energia como nas frutas.
func atualizar_machado(habilidades: HabilidadesDoMachado) -> void:
	visible = true
	if _fruta != "machado":
		_montar_linhas("machado", "Machado", HabilidadesDoMachado.NOMES)
	for slot in _linhas:
		var e: Dictionary = habilidades.estado_da_tecla(slot)
		var estado: Label = _linhas[slot]["estado"]
		var nome: Label = _linhas[slot]["nome"]
		var bloqueada := bool(e.get("bloqueada", false))
		_bloquear_linha(slot, bloqueada)
		if bloqueada:
			estado.text = "requer %s ⚡" % _segundos(float(e["custo"]))
			estado.add_theme_color_override("font_color", Estilo.APAGADO)
		elif float(e["recarga"]) > 0.05:
			estado.text = "faltam %s s" % _segundos(float(e["recarga"]))
			estado.add_theme_color_override("font_color", Estilo.APAGADO)
		elif bool(e["sem_energia"]):
			estado.text = "sem energia (%s ⚡)" % _segundos(float(e["custo"]))
			estado.add_theme_color_override("font_color", Estilo.AVISO)
		else:
			estado.text = "recarga %s s" % _segundos(float(e["recarga_total"]))
			estado.add_theme_color_override("font_color", Estilo.LIGADO)
		nome.add_theme_color_override("font_color",
			Estilo.APAGADO if float(e["recarga"]) > 0.05 or bool(e["sem_energia"]) else Color(1, 1, 1))


## Lâminas EF de madeira (21/11/2026): Z Corte, X Meia-lua. Mesma leitura do machado.
func atualizar_lamina(habilidades) -> void:
	visible = true
	if _fruta != "lamina":
		_montar_linhas("lamina", "Lâmina de madeira", HabilidadesDaLamina.NOMES)
	for slot in _linhas:
		var e: Dictionary = habilidades.estado_da_tecla(slot)
		var estado: Label = _linhas[slot]["estado"]
		var nome: Label = _linhas[slot]["nome"]
		var bloqueada := bool(e.get("bloqueada", false))
		_bloquear_linha(slot, bloqueada)
		if bloqueada:
			estado.text = "requer %s ⚡" % _segundos(float(e["custo"]))
			estado.add_theme_color_override("font_color", Estilo.APAGADO)
		elif float(e["recarga"]) > 0.05:
			estado.text = "faltam %s s" % _segundos(float(e["recarga"]))
			estado.add_theme_color_override("font_color", Estilo.APAGADO)
		elif bool(e["sem_energia"]):
			estado.text = "sem energia (%s ⚡)" % _segundos(float(e["custo"]))
			estado.add_theme_color_override("font_color", Estilo.AVISO)
		else:
			estado.text = "recarga %s s" % _segundos(float(e["recarga_total"]))
			estado.add_theme_color_override("font_color", Estilo.LIGADO)
		nome.add_theme_color_override("font_color",
			Estilo.APAGADO if float(e["recarga"]) > 0.05 or bool(e["sem_energia"]) else Color(1, 1, 1))


## Goro Goro (Mine Piece), 18/10/2026: uma linha por técnica do ciclo do R; a selecionada
## leva [Z]. A recarga do mod é GLOBAL — usada uma, todas esperam.
func atualizar_goro_mine_piece(goro: GoroGoroMinePiece) -> void:
	atualizar_mine_piece(goro, GoroGoroMinePiece.ID, GoroGoroMinePiece.NOME)


func atualizar_mine_piece(goro: Node, fruta_id: String, nome_fruta: String) -> void:
	visible = true
	var estados: Array = goro.estado_das_tecnicas()
	# Duas técnicas com o MESMO nome (a Pika tem dois "Yasakani Sacred Jewel", 24 e 29) colapsavam numa linha só: a chave leva a tecla.
	var repetidos := {}
	for e in estados:
		repetidos[e.nome] = int(repetidos.get(e.nome, 0)) + 1
	var chaves: Array = []
	var nomes := {}
	for e in estados:
		var chave: String = str(e.nome) if int(repetidos[e.nome]) == 1 else "%s (%s)" % [e.nome, str(e.get("tecla", ""))]
		chaves.append(chave)
		nomes[chave] = chave
	var direta: bool = goro.has_method("tem_teclas_diretas") and goro.tem_teclas_diretas()
	var sufixo := "" if direta else "  ·  R troca"
	if _fruta != fruta_id or nomes.keys() != _linhas.keys():
		_montar_linhas(fruta_id, nome_fruta + sufixo, nomes)
	var titulo := _titulo
	if is_instance_valid(titulo):
		var avisos: String = goro.avisos()
		titulo.text = "%s%s%s" % [nome_fruta, sufixo, ("  ·  " + avisos) if not avisos.is_empty() else ""]
	for indice in estados.size():
		var e: Dictionary = estados[indice]
		var linha: Dictionary = _linhas[chaves[indice]]
		var estado: Label = linha.estado
		var bloqueada := bool(e.bloqueada)
		_bloquear_linha(chaves[indice], bloqueada)
		linha.tecla.text = ("[%s]" % e.tecla) if str(e.get("tecla", "")) != "" else ("[Z]" if e.selecionada else " · ")
		if bloqueada:
			estado.text = "requer %s ⚡" % _segundos(float(e.custo))
			estado.add_theme_color_override("font_color", Estilo.APAGADO)
		elif not str(e.get("requisito", "")).is_empty():
			estado.text = str(e.requisito)
			estado.add_theme_color_override("font_color", Estilo.APAGADO)
		elif float(e.recarga) > 0.05:
			estado.text = "faltam %s s" % _segundos(float(e.recarga))
			estado.add_theme_color_override("font_color", Estilo.APAGADO)
		elif bool(e.sem_energia):
			estado.text = "sem energia (%s ⚡)" % _segundos(float(e.custo))
			estado.add_theme_color_override("font_color", Estilo.AVISO)
		else:
			estado.text = "%s ⚡ · recarga %s s" % [_segundos(float(e.custo)), _segundos(float(e.recarga_total))]
			estado.add_theme_color_override("font_color", Estilo.LIGADO)
		linha.nome.add_theme_color_override("font_color", Estilo.AVISO if e.selecionada \
			else (Estilo.APAGADO if float(e.recarga) > 0.05 or bool(e.sem_energia) else Color(1, 1, 1)))


func texto_da_linha(slot: String) -> String:
	if not _linhas.has(slot):
		return ""
	return "%s %s" % [(_linhas[slot]["nome"] as Label).text, (_linhas[slot]["estado"] as Label).text]


func slots_na_tela() -> Array:
	return _linhas.keys()


## "6" para 6,0 e "7,5" para 7,5 (vírgula, como o resto da HUD).
static func _segundos(v: float) -> String:
	if absf(v - roundf(v)) < 0.05:
		return str(roundi(v))
	return ("%.1f" % v).replace(".", ",")


func _montar(perfil: PerfilDeFrutas) -> void:
	var nomes := {}
	for slot in perfil.slots():
		nomes[slot] = perfil.tecnica(slot).nome
	# Tecla F do Builder (o voo da Pika refeita, 07/10/2026): não está na ficha. Só se a
	# fruta TEM skill no F (17/10/2026: fruta do Builder sem F mostrava a linha "[F] F").
	if not nomes.has("F") and KitDoBuilder.pelo_builder(perfil.fruta, "F") and KitDoBuilder.tem("F", perfil.fruta):
		nomes["F"] = KitDoBuilder.nome_da_tecla("F", perfil.fruta)
	if perfil.fruta == "hie_hie": nomes["F"] = "Bicicleta de gelo"
	_montar_linhas(perfil.fruta, PerfilDeFrutas.nome_da_fruta(perfil.fruta), nomes)


func _montar_linhas(id: String, titulo_texto: String, nomes: Dictionary) -> void:
	for filho in get_children():
		filho.queue_free()
	_linhas.clear()
	_fruta = id
	var slots := nomes.keys()
	var altura := ALTURA_DO_TITULO + ALTURA_DA_LINHA * slots.size() + RECUO * 2
	# Âncora no canto inferior esquerdo e OFFSETS a partir dela. `position` aqui é no
	# espaço do pai (a CanvasLayer): y negativo punha o painel ACIMA do topo da tela —
	# a HUD de técnicas ficou invisível de 22/09 a 03/10/2026 (docs/erros.md).
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = MARGEM
	offset_right = MARGEM + LARGURA
	# A barra pode chegar a nove itens e ocupar o canto das técnicas em telas menores.
	var acima_da_barra := BarraDeItensHud.LADO + BarraDeItensHud.MARGEM + 18.0
	offset_top = -altura - MARGEM - acima_da_barra
	offset_bottom = -MARGEM - acima_da_barra
	var fundo := Panel.new()
	fundo.name = "Fundo"
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.size = size
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = Color(0.02, 0.075, 0.09, 0.78)
	caixa.set_corner_radius_all(6)
	caixa.set_border_width_all(1)
	caixa.border_color = Color(1, 1, 1, 0.18)
	fundo.add_theme_stylebox_override("panel", caixa)
	add_child(fundo)
	var titulo := _rotulo("%s  ·  técnicas" % titulo_texto, 14, Estilo.AVISO)
	titulo.name = "Titulo"
	_titulo = titulo   # o nome pode ganhar sufixo enquanto o painel antigo não saiu
	titulo.position = Vector2(RECUO, RECUO - 2)
	add_child(titulo)
	var y := RECUO + ALTURA_DO_TITULO
	for slot in slots:
		var sombra := ColorRect.new()
		sombra.color = Color(0.0, 0.0, 0.0, 0.65)
		sombra.position = Vector2(4, y)
		sombra.size = Vector2(LARGURA - 8, ALTURA_DA_LINHA)
		sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sombra.visible = false
		add_child(sombra)
		var tecla := _rotulo("[%s]" % slot, 15, Estilo.AVISO)
		tecla.position = Vector2(RECUO, y)
		add_child(tecla)
		var nome := _rotulo(nomes[slot], 15, Color(1, 1, 1))
		nome.position = Vector2(RECUO + 34, y)
		nome.size = Vector2(LARGURA - 44 - LARGURA_DO_ESTADO - RECUO - 6, ALTURA_DA_LINHA)   # termina ANTES do estado
		nome.clip_text = true
		nome.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS   # nome longo vira "Ice Block: Pheas…", não é cortado seco
		add_child(nome)
		var estado := _rotulo("", 13, Estilo.LIGADO)
		estado.position = Vector2(LARGURA - LARGURA_DO_ESTADO - RECUO, y + 2)
		estado.size = Vector2(LARGURA_DO_ESTADO, ALTURA_DA_LINHA)
		estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(estado)
		var cadeado := TextureRect.new()
		cadeado.texture = load("res://assets/ui/barra/cadeado.svg")
		cadeado.position = Vector2(RECUO, y + 3)
		cadeado.size = Vector2(20, 20)
		cadeado.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cadeado.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadeado.visible = false
		add_child(cadeado)
		_linhas[slot] = {"nome": nome, "estado": estado, "tecla": tecla, "sombra": sombra, "cadeado": cadeado}
		y += ALTURA_DA_LINHA
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)


func _bloquear_linha(slot: String, bloqueada: bool) -> void:
	_linhas[slot].sombra.visible = bloqueada
	_linhas[slot].cadeado.visible = bloqueada
	_linhas[slot].tecla.visible = not bloqueada


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Estilo.texto(tamanho, cor)
	l.text = texto
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
