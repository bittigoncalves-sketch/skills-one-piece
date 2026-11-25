class_name FerramentasDeTeste
extends PanelContainer
## Editor de janelas (05/10/2026): o id desta janela no layout salvo.
const ID_DO_LAYOUT := "ferramentas"
# ============================================================================
#  FERRAMENTAS DE TESTE DO MODO HISTÓRIA — tecla F8, só em build de desenvolvimento.
#
#  Era a seção "TESTE" no fim da janela de Status (M). Saiu dela em 30/09/2026 a
#  pedido do dono: a janela de Status é interface de jogo, não de depuração. E
#  "só em build de desenvolvimento" sozinho não escondia nada — sem export
#  templates, o jogo sempre roda como build de desenvolvimento.
#
#  Existe porque ainda não há inimigos nem missões que deem XP: sem isto a
#  progressão não seria verificável jogando. Também invoca o BONECO DE DUELO do
#  combate corpo a corpo e dá/tira a fruta. O painel só PEDE (sinais abaixo);
#  quem cria o boneco e entrega a fruta é o `ModoHistoria`.
# ============================================================================

## Botões do boneco de duelo: rótulo → chave do modo (quem traduz a chave é o
## `ModoHistoria.MODOS_DO_BONECO`). Chave e não enum de propósito: citar o cérebro do
## combate aqui puxaria o combate para a compilação de quem só usa a HUD.
const MODOS_DO_BONECO := [["Parado", &"parado"], ["Só guarda", &"guarda"], ["Ataca", &"ataca"], ["Apara e responde", &"apara"]]
const LARGURA := 340.0
const COR_TITULO := Color(1.0, 0.58, 0.32)
const COR_SECAO := Color(0.62, 0.72, 0.78)

## Invocar o boneco de duelo no `modo` (chave de `MODOS_DO_BONECO`), ou trocar o modo
## do que já existe.
signal pediu_boneco(modo: StringName)
## Tirar o boneco de duelo da cena.
signal pediu_remover_boneco
## Comer a Akuma no Mi `id` (quem entrega é o `ModoHistoria`).
signal pediu_fruta(id: String)
## Tirar a fruta do personagem.
signal pediu_tirar_fruta
## Corrida de caranguejos (06/10/2026): larga sem precisar pôr o organizador no mapa.
signal pediu_corrida
## "Ir à Ilha dos Macacos" (08/10/2026): o Modo História põe o jogador no píer de lá.
signal pediu_ilha_dos_macacos
## "Besta do mar no barco" (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E5): força o encontro.
signal pediu_encontro_no_mar

var progressao: ProgressaoDoPersonagem
var _spawn_rotulo: Label
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
var _spawn_relogio := 0.0


func ligar(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	prog.mudou.connect(_atualizar)
	_atualizar()


func _ready() -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.03, 0.07, 0.09, 0.95)
	estilo.border_color = Color(COR_TITULO, 0.55)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(16)
	add_theme_stylebox_override("panel", estilo)
	custom_minimum_size = Vector2(LARGURA, 0)

	var rolagem := ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(rolagem)
	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 8)
	rolagem.add_child(coluna)

	var cabeca := HBoxContainer.new()
	coluna.add_child(cabeca)
	var titulo := _rotulo("FERRAMENTAS DE TESTE", COR_TITULO, 16)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabeca.add_child(titulo)
	cabeca.add_child(_rotulo("F8 fecha", COR_SECAO, 12))
	coluna.add_child(_rotulo("Só em desenvolvimento", COR_SECAO, 12))

	var xp := _secao(coluna, "Progressão")
	for qtd in [100, 1000, 10000, 100000]:
		xp.add_child(_botao("+%s XP" % JanelaDeStatus._milhar(qtd), func(): progressao.ganhar_xp(qtd)))
	xp.add_child(_botao("+100 ouro", func(): progressao.ganhar_ouro(100)))

	var skills := _secao(coluna, "Skills")
	for skill in ProgressaoDoPersonagem.SKILLS:
		skills.add_child(_botao("%s +1" % skill.capitalize(),
			func(): progressao.definir_skill(skill, (int(progressao.skills[skill]) + 1) % (ProgressaoDoPersonagem.SKILL_MAXIMO + 1))))

	var movimento := _secao(coluna, "Movimento")
	movimento.add_child(_botao("Dash liga/desliga", func(): progressao.desbloquear("dash", not progressao.desbloqueios["dash"])))
	movimento.add_child(_botao("Pulo duplo liga/desliga", func(): progressao.desbloquear("pulo_duplo", not progressao.desbloqueios["pulo_duplo"])))
	movimento.add_child(_botao("Bússola liga/desliga", func(): progressao.desbloquear("bussola", not progressao.desbloqueios["bussola"])))
	movimento.add_child(_botao("Ir à Ilha dos Macacos", func(): pediu_ilha_dos_macacos.emit()))
	movimento.add_child(_botao("Besta do mar no barco", func(): pediu_encontro_no_mar.emit()))

	# Spawn natural do Mine Piece (23/10/2026): verificação em jogo, ilha por ilha.
	var spawn := _secao(coluna, "Spawn natural (Mine Piece)")
	var botao_spawn: Button
	botao_spawn = _botao(_texto_do_spawn(), func():
		SpawnNaturalMinePiece.ligado = not SpawnNaturalMinePiece.ligado
		botao_spawn.text = _texto_do_spawn())
	spawn.add_child(botao_spawn)
	# IA do mod (camada Minecraft): dano real, visual das técnicas ainda não desenhado.
	var botao_ia: Button
	botao_ia = _botao(_texto_da_ia(), func():
		IaDoMod.ligada = not IaDoMod.ligada
		botao_ia.text = _texto_da_ia())
	spawn.add_child(botao_ia)
	_spawn_rotulo = _rotulo("", COR_SECAO, 12)
	_spawn_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD
	_spawn_rotulo.custom_minimum_size.x = 300.0
	spawn.add_child(_spawn_rotulo)

	# Os inimigos do mapa não lutam: sem um oponente no MESMO executor, defesa, aparo,
	# riposte e finta não se jogam (docs/PLANO_COMBATE_HISTORIA.md, §14, Fase 7a).
	var bonecos := _secao(coluna, "Boneco de duelo — combate corpo a corpo")
	bonecos.name = "Bonecos"
	for par in MODOS_DO_BONECO:
		bonecos.add_child(_botao(par[0], func(): pediu_boneco.emit(par[1])))
	bonecos.add_child(_botao("Remover boneco", func(): pediu_remover_boneco.emit()))

	# A fruta no jogo é uma peça do mapa; aqui é o atalho para provar o kit.
	var frutas := _secao(coluna, "Akuma no Mi")
	frutas.name = "Frutas"
	frutas.add_child(_botao("Comer Rocket", func(): pediu_fruta.emit("rocket")))
	# As skills publicadas no Skills Builder, como uma fruta (06/10/2026).
	var kit := _botao("Equipar Kit do Builder", func(): pediu_fruta.emit(KitDoBuilder.ID))
	kit.name = "EquiparKitDoBuilder"
	kit.disabled = not KitDoBuilder.disponivel()
	kit.tooltip_text = "Publique skills de Usuário Jogador no Skills Builder" if kit.disabled else ""
	frutas.add_child(kit)
	# Nikyu Nikyu (Mine Piece) nativa, A10: 5 no inventário (M › Inventário › Frutas), para provar as cinco técnicas e o som.
	var nikyu := _botao("Dar 5 Nikyu Nikyu (inventário)", func(): progressao.dar_fruta_de_teste(CatalogoFrutasMinePiece.NIKYU, 5))
	nikyu.name = "DarNikyu"
	frutas.add_child(nikyu)
	# Logias refatoradas (24/11/2026): 3 de cada no inventário para testar as técnicas em paralelo e os sons.
	var logias := _botao("Dar logias refatoradas (inventário)", func():
		for id: String in CatalogoFrutasMinePiece.REFATORADAS:
			progressao.dar_fruta_de_teste(id, 3))
	logias.name = "DarLogiasRefatoradas"
	frutas.add_child(logias)
	frutas.add_child(_botao("Tirar fruta", func(): pediu_tirar_fruta.emit()))
	# Pesca (03/10/2026): a vara sem precisar pôr o pescador no mapa.
	var pesca := _secao(coluna, "Pesca")
	pesca.add_child(_botao("Ganhar vara de pesca", func(): progressao.ganhar_equipamento("vara_de_pesca")))
	var corrida := _secao(coluna, "Corrida")
	var largar := _botao("Correr corrida de caranguejos", func(): pediu_corrida.emit())
	largar.name = "CorrerCorrida"
	corrida.add_child(largar)

	# Dia e noite (10/10/2026): ver a noite sem esperar 13 min de jogo.
	var hora := _secao(coluna, "Hora do dia")
	hora.add_child(_botao("Avançar 3 h", func():
		var ciclo := get_tree().get_first_node_in_group("ciclo_dia_noite")
		if ciclo != null:
			ciclo.call("avancar", 3.0)))

	var campanha := _secao(coluna, "Campanha")
	campanha.add_child(_botao("Reiniciar campanha", _confirmar_reinicio))


## Encaixa na tela abaixo das barras de vida e energia (que acabam em y = 86).
func posicionar() -> void:
	var tela := get_viewport_rect().size
	position = Vector2(20.0, 150.0)
	size = Vector2(LARGURA, maxf(200.0, tela.y - 170.0))
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)


static func _texto_da_ia() -> String:
	return "IA do mod (todos): " + ("ligada" if IaDoMod.ligada else "desligada")


static func _texto_do_spawn() -> String:
	return "Spawn natural: " + ("ligado" if SpawnNaturalMinePiece.ligado else "desligado")


## Contagem do spawn natural, uma vez por segundo com o painel aberto.
func _process(delta: float) -> void:
	if not visible or _spawn_rotulo == null:
		return
	_spawn_relogio -= delta
	if _spawn_relogio > 0.0:
		return
	_spawn_relogio = 1.0
	var sp := get_tree().get_first_node_in_group("spawn_natural_mine_piece") as SpawnNaturalMinePiece
	if sp == null:
		_spawn_rotulo.text = "sem spawn natural nesta cena"
		return
	var vivos := sp.vivos_por_ilha()
	var linhas: Array[String] = []
	for ilha in sp.nascidos_por_ilha:
		linhas.append("%s: %d vivos, %d nasceram" % [Ilhas.TABELA.get(ilha, {}).get("nome", ilha), int(vivos.get(ilha, 0)), int(sp.nascidos_por_ilha[ilha])])
	_spawn_rotulo.text = "\n".join(linhas) if not linhas.is_empty() else "nenhum nasceu ainda"


func _atualizar() -> void:
	pass


func _confirmar_reinicio() -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = "Voltar ao nível 1 (Civil) e apagar XP, ouro, atributos e skills?"
	d.ok_button_text = "Reiniciar"
	# Os pontos pendentes da janela de Status caem sozinhos: ela descarta o pedido
	# quando os pontos ficam abaixo dele (`JanelaDeStatus.atualizar`).
	d.confirmed.connect(func(): progressao.reiniciar())
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free()
	)
	add_child(d)
	d.popup_centered()


func _secao(coluna: VBoxContainer, titulo: String) -> HFlowContainer:
	coluna.add_child(_rotulo(titulo.to_upper(), COR_SECAO, 12))
	var fluxo := HFlowContainer.new()
	fluxo.add_theme_constant_override("h_separation", 6)
	fluxo.add_theme_constant_override("v_separation", 6)
	coluna.add_child(fluxo)
	return fluxo


func _rotulo(texto: String, cor: Color, tamanho: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", cor)
	l.add_theme_font_size_override("font_size", tamanho)
	return l


func _botao(texto: String, ao_clicar: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(ao_clicar)
	return b
