class_name SniperScope
extends Control
# ============================================================================
#  LUNETA DA SNIPER — a vista pelo cano do fuzil da Buki Buki (slot C).
#
#  O ESTADO JÁ EXISTIA E JÁ FAZIA EFEITO; faltava só o DESENHO:
#    • `BukiController` liga `_luneta` no botão direito com a sniper na mão;
#    • `Player._input` derruba a sensibilidade do mouse para 0,38× enquanto ela
#      está ligada (sem isso o zoom PIORA a pontaria);
#    • `CameraRig.atualizar` fecha o FOV para 22° (contra 68° normais).
#  Ou seja: a câmera já dava zoom e o mouse já ficava fino, mas a tela continuava
#  a mesma tela de sempre — o jogador não tinha COMO SABER que estava com a
#  luneta, a não ser deduzindo pelo zoom. Este nó é a confirmação visual.
#
#  COMO SE LIGA AO JOGO — o padrão do AmmoHud/StatusEffectsHud:
#   • `Player.local_player(tree)` acha O MEU corpo. `get_first_node_in_group`
#     devolve o corpo do HOST quando se está no cliente (bug real,
#     docs/erros.md 2026-08-10) e a luneta piscaria conforme o ADVERSÁRIO mirasse;
#   • o estado sai por `get("_buki_scope")` (a vista só-leitura do Player) —
#     nada de método novo no Player, que é território de outro agente.
#
#  TUDO DESENHADO no `_draw`, sem um único arquivo de imagem: é o padrão do
#  projeto (ícones do StatusEffectsHud/AmmoHud) e sobrevive a clone novo, onde um
#  .png pode não importar. Também escala sozinho com a resolução — a lente é uma
#  fração de min(largura, altura), não um número de pixels.
#
#  ORDEM NA TELA: pendurado na Hud ANTES do AmmoHud de propósito. A máscara é
#  preta OPACA e cobre quem foi somado antes dela; o contador de balas fica por
#  cima. Com 5 tiros no pente, esconder a munição justo na hora do tiro caro
#  seria trocar um problema de leitura por outro.
# ============================================================================

const PlayerScript := preload("res://Player.gd")

# Raio da lente em fração de min(largura, altura). 0,40 = lente ocupando 80% da
# altura: sobra moldura preta suficiente para LER como luneta, sem estrangular o
# campo de visão a ponto de o jogador perder o alvo que já estava mirando.
const RAIO_TELA := 0.40
const FADE := 0.09              # segundos até a máscara ficar opaca (evita "pop")

const PRETO := Color(0, 0, 0, 1)
const COR_LINHA := Color(0.93, 0.96, 1.0, 0.92)
const COR_CONTORNO := Color(0, 0, 0, 0.75)
const COR_PONTO := Color(1.0, 0.35, 0.30)     # mesma da munição apertada (AmmoHud)
const COR_VIDRO := Color(0.62, 0.70, 0.78, 0.22)

var _mira_antiga: Control = null   # o "+" do Player, escondido enquanto o zoom roda
var _alfa := 0.0

func _ready() -> void:
	# ⚠️ `set_anchors_preset` sozinho NÃO mexe nos offsets: ele recalcula as
	# âncoras para PRESERVAR o retângulo atual, que aqui nasce 0×0. O painel do
	# placar já ficou fora da tela por isso.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	resized.connect(queue_redraw)

func _process(dt: float) -> void:
	var eu := PlayerScript.local_player(get_tree())
	var ligado := _com_luneta(eu) and not _menu_aberto()
	if ligado and not visible:
		_alfa = 0.0
		visible = true
		queue_redraw()
	elif not ligado and visible:
		visible = false
	_mira_normal(eu, not ligado)
	if not ligado:
		return
	_alfa = minf(_alfa + dt / FADE, 1.0)
	modulate.a = _alfa

func _exit_tree() -> void:
	# A mira normal não pode ficar refém deste nó: se a HUD morrer com a luneta
	# ligada, o jogador ficaria sem mira nenhuma.
	_mira_normal(null, true)

# Só-leitura. `_buki_scope` é uma vista do Player sobre o componente
# (Player.gd:170) e não tem setter — quem manda no estado é o BukiController.
func _com_luneta(eu: Node) -> bool:
	if eu == null:
		return false
	var v: Variant = eu.get("_buki_scope")
	if typeof(v) == TYPE_BOOL:
		return bool(v)
	# Rede de segurança: se a vista sumir do Player, pergunta ao componente.
	var comp: Variant = eu.get("_buki")
	if comp is Object and (comp as Object).has_method("luneta"):
		return bool((comp as Object).call("luneta"))
	return false

# A máscara é preta OPACA e a Hud inteira mora atrás dela. `_buki.atualizar`
# roda no `_physics_process` e lê o botão direto do `Input`, sem perguntar por
# menu nenhum: quem abrisse o inventário com o botão direito ainda apertado veria
# a tela preta e daria a HUD por travada. Menu aberto = luneta fora da frente.
func _menu_aberto() -> bool:
	var pai := get_parent()
	if pai != null and pai.has_method("is_menu_open"):
		return bool(pai.call("is_menu_open"))
	return false

# A MIRA ANTIGA: o "+" que o Player monta no centro (Player.gd:350).
# DECISÃO: as duas NÃO convivem. O "+" cai exatamente no meio do retículo, onde
# fica o ponto de impacto — duas miras empilhadas no mesmo pixel não somam
# informação, só engordam o alvo e escondem o ponto vermelho. Enquanto a luneta
# estiver ligada quem manda é o retículo; ao soltar, o "+" volta na hora.
# Isto NÃO edita o Player: mexe na `visible` do nó que ele já expõe, e ninguém
# mais no projeto escreve nessa propriedade (grep: só a criação, em Player.gd:350).
func _mira_normal(eu: Node, mostrar: bool) -> void:
	if _mira_antiga == null or not is_instance_valid(_mira_antiga):
		_mira_antiga = null
		if eu != null:
			var c: Variant = eu.get("_crosshair")
			if c is Control:
				_mira_antiga = c as Control
	if _mira_antiga != null and _mira_antiga.visible != mostrar:
		_mira_antiga.visible = mostrar

# ---------------------------------------------------------------- o desenho
#  Cinco camadas, de baixo para cima:
#   1. máscara preta   — anel opaco do raio da lente até fora da tela;
#   2. vinheta do vidro— escurece de dentro para a borda (a lente não é um furo);
#   3. aro             — o corpo da luneta e o brilho do vidro;
#   4. retículo duplex — cruz fina no miolo, grossa nas pontas (é o desenho que
#                        os fuzis de verdade usam: as pontas grossas acham o
#                        centro no canto do olho, o miolo fino não cobre o alvo);
#   5. ponto de impacto— um pingo vermelho onde a bala vai.
func _draw() -> void:
	var meio := size * 0.5
	var r := minf(size.x, size.y) * RAIO_TELA
	if r <= 4.0:
		return

	# 1. MÁSCARA. `draw_arc` com largura grossa é um ANEL: a borda de dentro fica
	# em `raio - largura/2`, então o buraco tem exatamente `r`. A largura é a
	# diagonal inteira da tela, o que garante cobrir até os quatro cantos.
	var fora := size.length()
	draw_arc(meio, r + fora * 0.5, 0.0, TAU, 192, PRETO, fora, false)

	# 2. VINHETA — anéis empilhados, cada um um pouco mais opaco que o anterior.
	# Cada anel é ~3x mais largo que o passo entre eles: sem essa sobreposição a
	# vinheta sai LISTRADA (dá pra contar os anéis na tela).
	var passos := 22
	var largura_anel := (r * 0.34) / float(passos) * 3.0 + 2.0
	for i in passos:
		var t := float(i) / float(passos - 1)
		var raio_i := lerpf(r * 0.66, r, t)
		draw_arc(meio, raio_i, 0.0, TAU, 96, Color(0, 0, 0, 0.012 + 0.075 * t * t),
			largura_anel, true)

	# 3. ARO da luneta + reflexo do vidro logo dentro dele.
	draw_arc(meio, r * 0.985, 0.0, TAU, 192, Color(0.05, 0.05, 0.06, 0.95), r * 0.05, true)
	draw_arc(meio, r * 0.94, 0.0, TAU, 160, COR_VIDRO, maxf(r * 0.006, 1.0), true)

	# 4. RETÍCULO.
	var eixos: Array[Vector2] = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	var vao := r * 0.05          # o furo no centro: o alvo não fica coberto
	var troca := r * 0.46        # onde a linha fina vira linha grossa
	var ponta := r * 0.93
	for eixo: Vector2 in eixos:
		# Contorno preto por baixo: é o que mantém a cruz legível contra céu claro.
		draw_line(meio + eixo * vao, meio + eixo * ponta, COR_CONTORNO, 3.6, true)
		draw_line(meio + eixo * vao, meio + eixo * troca, COR_LINHA, 1.4, true)
		draw_line(meio + eixo * troca, meio + eixo * ponta, COR_LINHA, 3.0, true)
		# Marcas de elevação (mil-dots): a régua que dá NOÇÃO DE ESCALA ao zoom.
		var perp := Vector2(-eixo.y, eixo.x)
		for k in range(1, 4):
			var d := vao + (troca - vao) * (float(k) / 4.0)
			var meia := r * 0.016
			draw_line(meio + eixo * d - perp * meia, meio + eixo * d + perp * meia,
				COR_LINHA, 1.4, true)

	# 5. PONTO DE IMPACTO. Único elemento colorido do retículo: é ELE que o olho
	# procura, e o vão da cruz existe justamente para não cobri-lo.
	draw_circle(meio, maxf(r * 0.011, 2.6), COR_CONTORNO)
	draw_circle(meio, maxf(r * 0.007, 1.8), COR_PONTO)
