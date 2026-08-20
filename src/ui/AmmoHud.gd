class_name AmmoHud
extends Control
# ============================================================================
#  MUNIÇÃO NA TELA — canto inferior direito.
#
#  A munição é a PENALIDADE da Buki Buki no Mi; penalidade que o jogador não vê
#  não existe.
#
#  DOIS MODOS (o segundo entrou em 2026-08-11, a pedido do dono):
#
#   • ARMA NA MÃO  -> a arma empunhada, em letra grande: nome, contador
#     "balas / total" e o pente. É informação de mira.
#
#   • FRUTA EQUIPADA, MÃO VAZIA -> o ARSENAL: os quatro slots, cada um com a
#     silhueta, a capacidade e o estado (PRONTA ou os segundos que faltam de
#     recarga). Antes o painel simplesmente sumia, e some justo no momento em
#     que a decisão existe: de mão vazia a pergunta do jogador não é "quantas
#     balas me restam" (a resposta é sempre zero) — é "o que eu posso sacar
#     AGORA". O rodízio de armas é a mecânica central da fruta, e ele estava
#     sendo jogado de memória, com a resposta escondida num `print` do console.
#     Traço em vez de número seria devolver a mesma pergunta sem resposta.
#
#  Some por completo só quando a Buki Buki não está equipada — aí não há nada
#  a decidir e o canto volta a ser da mira.
#
#  POR QUE AQUI, e não numa das duas HUDs que já existiam:
#   • `StatusEffectsHud` é canto SUPERIOR direito e já divide o espaço com o
#     placar da partida (MatchHud). Munição é informação de mira, precisa ficar
#     perto do centro-baixo da tela, não no topo.
#   • `SkillBar` é canto inferior ESQUERDO e lista os quatro slots; enfiar o
#     contador lá misturaria "o que eu posso sacar" com "quanto me resta".
#  Inferior DIREITO é a convenção de FPS e é o único canto livre da tela.
#
#  Do StatusEffectsHud vem o padrão que EU REUSO: ícone DESENHADO no `_draw`
#  (sem .png que possa não importar num clone) e `Player.local_player()` para
#  achar o jogador — `get_first_node_in_group("player")` devolve o corpo do HOST
#  quando se está no cliente (bug real, docs/erros.md 2026-08-10).
# ============================================================================

const PlayerScript := preload("res://Player.gd")

const LARGURA := 250.0
const ALTURA := 78.0            # modo ARMA NA MÃO
const ALTURA_ARSENAL := 116.0   # modo ARSENAL: 4 linhas de 24 px + título
const MARGEM := 20.0
const LINHA := 24.0

const COR_APERTADO := Color(1.0, 0.35, 0.30)
const COR_PRONTA := Color(1.0, 0.82, 0.35)

var _painel: ColorRect
var _bloco_arma: Control
var _bloco_arsenal: Control
var _icone: ArmaIcone
var _nome: Label
var _contador: Label
var _pentes: PenteDeBalas
var _titulo: Label
var _linhas: Dictionary = {}    # slot -> {"icone": ArmaIcone, "nome": Label, "estado": Label}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir()
	visible = false

func _process(_dt: float) -> void:
	var eu := PlayerScript.local_player(get_tree())
	if not is_instance_valid(eu) or not eu.has_method("buki_arma") or not _com_a_fruta(eu):
		visible = false
		return
	visible = true

	var slot: String = str(eu.call("buki_arma"))
	var com_arma := slot != ""
	_bloco_arma.visible = com_arma
	_bloco_arsenal.visible = not com_arma
	var alt := ALTURA if com_arma else ALTURA_ARSENAL
	_painel.size = Vector2(LARGURA, alt)
	_painel.position = Vector2(size.x - LARGURA - MARGEM, size.y - alt - MARGEM)

	if com_arma:
		_atualizar_arma(eu, slot)
	else:
		_atualizar_arsenal(eu)

# A HUD só existe para a Buki Buki: fora dela o canto inferior direito volta a
# ser da mira. `combat_mode`/`current_fruit_id` são lidos por `get()` porque o
# Player é território de outro agente — nada de método novo lá só por isto.
func _com_a_fruta(eu: Node) -> bool:
	return str(eu.get("combat_mode")) == "fruit" and str(eu.get("current_fruit_id")) == "buki_buki"

func _atualizar_arma(eu: Node, slot: String) -> void:
	var balas: int = int(eu.call("buki_municao"))
	var total: int = maxi(int(eu.call("buki_municao_max")), 1)
	_icone.slot = slot
	_icone.queue_redraw()
	_nome.text = "[%s] %s" % [slot, BukiFX.nome_da_arma(slot).to_upper()]
	_contador.text = "%d / %d" % [balas, total]
	# Vermelho no último terço: é o aviso de que o rodízio de armas vem aí.
	var apertado := float(balas) / float(total) <= 0.34
	_contador.add_theme_color_override("font_color",
		COR_APERTADO if apertado else Color(1, 1, 1))
	_pentes.balas = balas
	_pentes.total = total
	_pentes.cor = COR_APERTADO if apertado else COR_PRONTA
	_pentes.queue_redraw()

# Mão vazia: o que dá pra sacar. A recarga vem do `_skill_cooldowns` do Player —
# é o MESMO número que barra o saque em `_buki_empunhar`, então o que a HUD diz
# e o que a tecla faz não podem divergir.
func _atualizar_arsenal(eu: Node) -> void:
	var recargas = eu.get("_skill_cooldowns")
	for slot in BukiFX.SLOTS:
		var l: Dictionary = _linhas[slot]
		var cd := 0.0
		if recargas is Dictionary:
			cd = float((recargas as Dictionary).get(slot, 0.0))
		var pronta := cd <= 0.0
		# Capacidade junto do nome: é ela que o jogador compara na hora de escolher
		# (12 de pistola x 3 de canhão é a decisão inteira).
		(l["nome"] as Label).text = "%s · %d" % [
			BukiFX.nome_da_arma(slot).to_upper(), BukiFX.municao(slot)]
		(l["nome"] as Label).add_theme_color_override("font_color",
			Color(0.88, 0.92, 0.98) if pronta else Color(0.55, 0.57, 0.62))
		(l["estado"] as Label).text = "PRONTA" if pronta else "%.1fs" % cd
		(l["estado"] as Label).add_theme_color_override("font_color",
			COR_PRONTA if pronta else COR_APERTADO)
		var ic: ArmaIcone = l["icone"]
		ic.modulate = Color(1, 1, 1, 1.0 if pronta else 0.35)

# ------------------------------------------------------------------ construção
func _construir() -> void:
	_painel = ColorRect.new()
	_painel.color = Color(0, 0, 0, 0.55)
	_painel.size = Vector2(LARGURA, ALTURA)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_painel)

	_bloco_arma = _bloco()
	_bloco_arsenal = _bloco()

	# --- modo ARMA NA MÃO ---
	_icone = _fazer_icone(_bloco_arma, Vector2(12, 14), Vector2(48, 48))
	_nome = _texto(_bloco_arma, Vector2(70, 8), 15, Color(0.85, 0.90, 0.96))
	_contador = _texto(_bloco_arma, Vector2(70, 26), 30, Color(1, 1, 1))

	_pentes = PenteDeBalas.new()
	_pentes.position = Vector2(70, ALTURA - 16)
	_pentes.size = Vector2(LARGURA - 84, 8)
	_pentes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bloco_arma.add_child(_pentes)

	# --- modo ARSENAL (mão vazia) ---
	_titulo = _texto(_bloco_arsenal, Vector2(12, 4), 13, Color(0.70, 0.75, 0.82))
	_titulo.text = "BUKI BUKI — ARSENAL"
	var y := 22.0
	for slot in BukiFX.SLOTS:
		var tecla := _texto(_bloco_arsenal, Vector2(12, y), 14, Color(0.70, 0.75, 0.82))
		tecla.text = slot
		_linhas[slot] = {
			"icone": _fazer_icone(_bloco_arsenal, Vector2(26, y + 3), Vector2(18, 18), slot),
			"nome": _texto(_bloco_arsenal, Vector2(50, y), 14, Color(0.88, 0.92, 0.98)),
			"estado": _texto(_bloco_arsenal, Vector2(LARGURA - 62, y), 14, COR_PRONTA),
		}
		y += LINHA

func _bloco() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(c)
	return c

func _fazer_icone(pai: Control, pos: Vector2, tam: Vector2, slot := "Z") -> ArmaIcone:
	var i := ArmaIcone.new()
	i.slot = slot
	i.position = pos
	i.size = tam
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(i)
	return i

func _texto(pai: Control, pos: Vector2, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l


# ============================================================================
#  SILHUETA DA ARMA — desenhada, uma por slot. O jogador reconhece o que está na
#  mão pelo canto do olho, sem ler o nome. Serve nos dois tamanhos: 48 px no
#  modo arma-na-mão e 18 px na lista do arsenal (tudo é fração de `size`).
# ============================================================================
class ArmaIcone extends Control:
	var slot: String = "Z"
	const ACO := Color(0.80, 0.84, 0.90)
	const ESCURO := Color(0.45, 0.48, 0.54)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		match slot:
			"Z":   # pistola: cano curto + coronha
				draw_rect(Rect2(w * 0.14, h * 0.34, w * 0.62, h * 0.16), ACO)
				draw_rect(Rect2(w * 0.20, h * 0.50, w * 0.18, h * 0.30), ESCURO)
			"X":   # canhão: tubo grosso com a boca alargada
				draw_rect(Rect2(w * 0.12, h * 0.36, w * 0.62, h * 0.28), ACO)
				draw_rect(Rect2(w * 0.70, h * 0.28, w * 0.16, h * 0.44), ESCURO)
			"C":   # sniper: cano LONGO e fino + luneta em cima
				draw_rect(Rect2(w * 0.06, h * 0.44, w * 0.86, h * 0.10), ACO)
				draw_rect(Rect2(w * 0.34, h * 0.28, w * 0.30, h * 0.10), ESCURO)
				draw_rect(Rect2(w * 0.14, h * 0.54, w * 0.16, h * 0.24), ESCURO)
			_:     # minigun: feixe de canos
				for i in 3:
					draw_rect(Rect2(w * 0.16, h * (0.28 + i * 0.16), w * 0.66, h * 0.08), ACO)
				draw_rect(Rect2(w * 0.06, h * 0.24, w * 0.10, h * 0.44), ESCURO)


# ============================================================================
#  O PENTE — um risquinho por bala enquanto couber; virou barra quando não cabe
#  (o minigun tem 100). Ver as balas SUMIREM uma a uma é o que faz a penalidade
#  ser sentida; com 100 o que importa é a proporção.
# ============================================================================
class PenteDeBalas extends Control:
	var balas: int = 0
	var total: int = 1
	var cor: Color = Color(1.0, 0.82, 0.35)

	func _draw() -> void:
		if total <= 0:
			return
		if total <= 20:
			var passo := size.x / float(total)
			var largura := maxf(passo - 3.0, 2.0)
			for i in total:
				var c: Color = cor if i < balas else Color(1, 1, 1, 0.14)
				draw_rect(Rect2(i * passo, 0.0, largura, size.y), c)
		else:
			draw_rect(Rect2(0, 0, size.x, size.y), Color(1, 1, 1, 0.14))
			draw_rect(Rect2(0, 0, size.x * clampf(float(balas) / float(total), 0.0, 1.0), size.y), cor)
