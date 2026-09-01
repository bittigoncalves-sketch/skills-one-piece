class_name ToqueHud
extends Control
# ============================================================================
#  CONTROLES DE TOQUE — o jogo jogável com os dedos.
#
#  ------------------------------------------------ A DECISÃO CENTRAL
#  Este HUD não cria um segundo caminho de input: ele INJETA os mesmos eventos
#  que o teclado e o mouse já produzem (`Input.parse_input_event`). O joystick
#  vira W/A/S/D, os botões viram as teclas deles, e o arrasto vira movimento de
#  mouse.
#
#  ⚠️ POR QUE ASSIM. Nove arquivos leem teclado ou mouse direto — `MoveFrame`,
#  `Player`, os controladores de dash, buki, disparo. Um caminho paralelo de
#  input exigiria mexer nos nove e manter os dois em sincronia para sempre:
#  toda regra nova (uma trava, um cancelamento) teria de ser escrita duas vezes,
#  e a segunda seria esquecida. Injetando, o jogo inteiro continua com UM
#  caminho de entrada, e o toque é só mais uma fonte dele.
#
#  O preço é que o analógico do joystick vira digital (W/A/S/D). Não se perde
#  nada: `MoveFrame.ler()` já trata `f` e `r` como −1/0/1 mesmo no teclado.
#
#  ------------------------------------------------ AS DUAS METADES DA TELA
#  Esquerda anda, direita olha — a convenção que todo jogo 3D de celular usa, e
#  que o jogador já conhece de outros. O arrasto da direita só vale FORA dos
#  botões, senão apertar uma skill giraria a câmera junto.
# ============================================================================

## Ligado à força, para dar de testar no PC sem um aparelho.
static var forcar := false

const RAIO_BASE := 110.0        # o círculo do joystick
const RAIO_MANOPLA := 46.0
const ZONA_MORTA := 0.22        # fração do raio abaixo da qual não anda
## Arrasto → giro. ⚠️ CALIBRADO CONTRA O POLEGAR, não escolhido no olho: com
## 1,35 a medição deu 75° para 160 px, ou seja meia volta a cada ~220 px — um
## polegar percorre isso sem querer, e a câmera ficava incontrolável. 0,55 põe a
## meia volta perto de 500 px, que é um arrasto deliberado numa tela de celular.
## O canto de onde o joystick pode nascer: metade da largura, 60% da altura, a
## partir da borda inferior esquerda.
const ZONA_MOV_X := 0.5
const ZONA_MOV_Y := 0.6

const SENS_CAMERA := 0.55

## ============================================================================
##  O LAYOUT (pedido do dono, 2026-08-31)
##
##  "as teclas de skill do lado do menu de habilidade, na ordem correta;
##   movimentação esquerda inferior; pulo direita inferior; o M no canto
##   superior direito."
##
##  ⚠️ AS SKILLS SE ALINHAM À `SkillBar` EM RUNTIME, não a números fixos. A barra
##  já mostra Z/X/C/V com nome e recarga de cada golpe, e o dedo tem de cair AO
##  LADO da linha que ele lê — se a barra mudar de tamanho, de fonte ou de
##  posição, botões em coordenada fixa descolariam dela e ninguém perceberia até
##  alguém errar a skill no meio de uma luta. Aqui cada botão pergunta onde está
##  a linha dele.
##
##  O canto inferior direito é da própria `SkillBar` (medido: 322x212 numa tela
##  de 1280x720). Por isso o PULO fica logo à esquerda dela, que é o "direita
##  inferior" possível sem cobrir o menu que o jogador precisa ler.
## ============================================================================

## Botões de posição FIXA, em fração da tela a partir do canto que cada um usa.
## As skills não entram aqui — elas se alinham à barra (ver `_centro_do_botao`).
const BOTOES := [
	# M1 no canto SUPERIOR direito, sozinho: é o botão mais usado e não pode
	# disputar espaço com o resto.
	{"nome": "M1",   "mouse": true,      "canto": "cima_dir",  "x": 0.09, "y": 0.14, "r": 62.0},
	# ⚠️ À ESQUERDA DA COLUNA DE SKILLS, não colado nela. As skills se alinham à
	# `SkillBar` e caem por volta de x=878 numa tela de 1280; a primeira versão
	# punha o PULO em x=883 — SOBRE o botão do C, com os dois círculos
	# praticamente no mesmo ponto. O teste agora confere que nenhum par de
	# botões se toca, porque conferir isso no olho falhou.
	{"nome": "PULO", "tecla": KEY_SPACE, "canto": "baixo_dir", "x": 0.42, "y": 0.11, "r": 54.0},
	{"nome": "DASH", "tecla": KEY_Q,     "canto": "baixo_dir", "x": 0.42, "y": 0.30, "r": 44.0},
	{"nome": "F",    "tecla": KEY_F,     "canto": "baixo_dir", "x": 0.55, "y": 0.19, "r": 44.0},
]

## As quatro skills, na ORDEM da `SkillBar` — é o que "ordem correta" quer dizer:
## a mesma de cima para baixo que o jogador lê no menu.
const SKILLS := [
	{"nome": "Z", "tecla": KEY_Z},
	{"nome": "X", "tecla": KEY_X},
	{"nome": "C", "tecla": KEY_C},
	{"nome": "V", "tecla": KEY_V},
]
## ⚠️ O DEDO É MAIOR QUE A LINHA DO MENU. As linhas da `SkillBar` ficam a 32 px
## uma da outra — alinhar um botão a cada linha empilha círculos de 68 px e o
## dedo dispara a skill errada. Então a barra dá o LADO e o CENTRO, e o
## espaçamento é o que um dedo pede: 74 px entre centros, com raio 34 (68 de
## diâmetro, acima do mínimo confortável de toque).
const RAIO_SKILL := 34.0
const PASSO_SKILL := 74.0
## Respiro mínimo entre um botão e a borda da tela.
const MARGEM_TELA := 10.0
## Distância entre o botão e a borda esquerda da barra.
const FOLGA_DA_BARRA := 26.0
## Onde as skills caem se a `SkillBar` não for encontrada — só uma reserva para
## o jogo não ficar sem botão de golpe.
const SKILL_RESERVA_X := 0.30
const SKILL_RESERVA_Y0 := 0.62
const SKILL_RESERVA_DY := 0.10

var _base := Vector2.ZERO       # centro do joystick, fixado onde o dedo tocou
var _manopla := Vector2.ZERO
var _dedo_mov := -1             # índice do toque que controla o movimento
var _dedo_cam := -1             # e o que controla a câmera
var _teclas_ligadas := {}       # tecla -> true, para soltar o que foi apertado
var _dedo_botao := {}           # índice do toque -> qual botão ele segura


## O jogo está em modo toque? Em Android e iOS, sempre; no PC, só se forçado.
static func ativo() -> bool:
	return forcar or OS.get_name() in ["Android", "iOS"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = ativo()
	set_process_input(visible)


func _input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento is InputEventScreenTouch:
		_ao_tocar(evento as InputEventScreenTouch)
	elif evento is InputEventScreenDrag:
		_ao_arrastar(evento as InputEventScreenDrag)


func _ao_tocar(e: InputEventScreenTouch) -> void:
	if e.pressed:
		# Um botão sob o dedo tem prioridade: sem isso, apertar uma skill perto
		# da borda também giraria a câmera.
		var b := _botao_em(e.position)
		if b >= 0:
			_dedo_botao[e.index] = b
			_apertar(b, true)
			return
		# ⚠️ INFERIOR ESQUERDO, não a metade esquerda inteira (pedido do dono).
		# Com a metade toda, um toque alto à esquerda — onde ficam vida, energia
		# e o placar — armava o joystick e o jogador começava a andar sem querer
		# ao tentar ler a própria barra.
		if e.position.x < size.x * ZONA_MOV_X \
				and e.position.y > size.y * (1.0 - ZONA_MOV_Y) and _dedo_mov < 0:
			_dedo_mov = e.index
			_base = e.position          # o joystick nasce ONDE o dedo tocou
			_manopla = e.position
			queue_redraw()
		elif _dedo_cam < 0:
			_dedo_cam = e.index
	else:
		if _dedo_botao.has(e.index):
			_apertar(int(_dedo_botao[e.index]), false)
			_dedo_botao.erase(e.index)
		elif e.index == _dedo_mov:
			_dedo_mov = -1
			_soltar_direcoes()
			queue_redraw()
		elif e.index == _dedo_cam:
			_dedo_cam = -1


func _ao_arrastar(e: InputEventScreenDrag) -> void:
	if e.index == _dedo_mov:
		_manopla = e.position
		_atualizar_direcoes()
		queue_redraw()
	elif e.index == _dedo_cam:
		# Vira movimento de mouse: a câmera do Player já sabe reagir a isso, e
		# não precisa aprender um segundo jeito de girar.
		var m := InputEventMouseMotion.new()
		m.relative = e.relative * SENS_CAMERA
		m.position = e.position
		Input.parse_input_event(m)


## O vetor do joystick vira as quatro teclas de direção. Uma tecla só é
## injetada quando MUDA de estado — repetir `pressed` a cada quadro entupiria a
## fila de eventos sem mudar nada.
func _atualizar_direcoes() -> void:
	var v: Vector2 = _manopla - _base
	if v.length() > RAIO_BASE:
		v = v.normalized() * RAIO_BASE
		_manopla = _base + v
	var n := v / RAIO_BASE
	if n.length() < ZONA_MORTA:
		_soltar_direcoes()
		return
	_definir(KEY_W, n.y < -ZONA_MORTA)
	_definir(KEY_S, n.y > ZONA_MORTA)
	_definir(KEY_A, n.x < -ZONA_MORTA)
	_definir(KEY_D, n.x > ZONA_MORTA)
	# Longe do centro = correr. É o que substitui o Shift, que não tem dedo.
	_definir(KEY_SHIFT, n.length() > 0.82)


func _soltar_direcoes() -> void:
	for k in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_SHIFT]:
		_definir(k, false)


func _definir(tecla: Key, ligada: bool) -> void:
	if bool(_teclas_ligadas.get(tecla, false)) == ligada:
		return
	_teclas_ligadas[tecla] = ligada
	var e := InputEventKey.new()
	e.physical_keycode = tecla
	e.keycode = tecla
	e.pressed = ligada
	Input.parse_input_event(e)


func _apertar(indice: int, ligado: bool) -> void:
	var b: Dictionary = _dados_do_botao(indice)
	if bool(b.get("mouse", false)):
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = ligado
		m.position = _centro_do_botao(indice)
		Input.parse_input_event(m)
	else:
		_definir(int(b["tecla"]), ligado)
	queue_redraw()


## O total de botões: os fixos mais as quatro skills. Os índices de `SKILLS`
## continuam depois dos de `BOTOES`.
func _total_botoes() -> int:
	return BOTOES.size() + SKILLS.size()


func _dados_do_botao(i: int) -> Dictionary:
	if i < BOTOES.size():
		return BOTOES[i]
	return SKILLS[i - BOTOES.size()]


func _raio_do_botao(i: int) -> float:
	if i < BOTOES.size():
		return float(BOTOES[i]["r"])
	return RAIO_SKILL


func _centro_do_botao(i: int) -> Vector2:
	if i >= BOTOES.size():
		return _centro_da_skill(i - BOTOES.size())
	var b: Dictionary = BOTOES[i]
	var fx := float(b["x"])
	var fy := float(b["y"])
	match String(b.get("canto", "baixo_dir")):
		"cima_dir":
			return Vector2(size.x * (1.0 - fx), size.y * fy)
		"baixo_esq":
			return Vector2(size.x * fx, size.y * (1.0 - fy))
		_:
			return Vector2(size.x * (1.0 - fx), size.y * (1.0 - fy))


## AO LADO da linha correspondente na `SkillBar`. Ver a nota do layout.
func _centro_da_skill(indice: int) -> Vector2:
	var b := _barra()
	if b == null:
		return Vector2(size.x * (1.0 - SKILL_RESERVA_X),
			size.y * (SKILL_RESERVA_Y0 + SKILL_RESERVA_DY * indice))
	var r: Rect2 = b.get_global_rect()
	var x := r.position.x - FOLGA_DA_BARRA - RAIO_SKILL
	# A coluna fica CENTRADA na barra: o primeiro botão sobe metade do total e
	# os quatro descem na ordem em que o menu os mostra.
	var meio := r.position.y + r.size.y * 0.5
	var altura := PASSO_SKILL * (SKILLS.size() - 1)
	var topo := meio - altura * 0.5
	# ⚠️ A COLUNA É MAIS ALTA QUE A BARRA. Quatro botões espaçados por dedo
	# ocupam 290 px; a `SkillBar` tem 212. Centrada nela, a coluna transbordava
	# a borda inferior — metade do botão do V ficava fora da tela e não dava
	# para apertar. Empurrar para dentro é o que garante que os quatro caibam.
	var minimo := RAIO_SKILL + MARGEM_TELA
	var maximo := size.y - RAIO_SKILL - MARGEM_TELA - altura
	topo = clampf(topo, minimo, maxf(minimo, maximo))
	return Vector2(x, topo + PASSO_SKILL * indice)


func _barra() -> Control:
	var hud := get_tree().get_first_node_in_group("hud") if get_tree() else null
	if hud == null:
		return null
	return hud.get_node_or_null("SkillBar") as Control


func _borda_esquerda_da_barra() -> float:
	var b := _barra()
	return b.get_global_rect().position.x if b != null else size.x * 0.72


## A linha de um slot dentro da barra, achada pelo rótulo `[Z]` que ela mostra.
func _linha_da_barra(letra: String) -> Control:
	var b := _barra()
	if b == null:
		return null
	for n in _descendentes(b):
		if n is Label and String((n as Label).text) == "[%s]" % letra:
			return n as Control
	return null


func _descendentes(n: Node) -> Array:
	var out: Array = [n]
	for f in n.get_children():
		out.append_array(_descendentes(f))
	return out


func _botao_em(p: Vector2) -> int:
	for i in _total_botoes():
		if p.distance_to(_centro_do_botao(i)) <= _raio_do_botao(i):
			return i
	return -1


func _draw() -> void:
	# JOYSTICK: só aparece com o dedo em cima. Um círculo fixo ocupando canto de
	# tela o tempo todo cobre o jogo sem precisar.
	if _dedo_mov >= 0:
		draw_circle(_base, RAIO_BASE, Color(1, 1, 1, 0.10))
		draw_arc(_base, RAIO_BASE, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(_manopla, RAIO_MANOPLA, Color(1, 1, 1, 0.28))

	var fonte := ThemeDB.fallback_font
	for i in _total_botoes():
		var b: Dictionary = _dados_do_botao(i)
		var c := _centro_do_botao(i)
		var r := _raio_do_botao(i)
		var apertado := _dedo_botao.values().has(i)
		draw_circle(c, r, Color(1, 1, 1, 0.22 if apertado else 0.12))
		draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.45), 2.0)
		var texto := String(b["nome"])
		var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(fonte, c + Vector2(-largura * 0.5, 7), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.85))
