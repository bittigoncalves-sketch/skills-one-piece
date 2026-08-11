class_name StatusEffectsHud
extends Control
# ============================================================================
#  STATUS NA TELA — canto superior direito.
#
#  Uma janelinha por efeito ativo no SEU corpo: ícone, nome e quanto falta,
#  com uma barra que esvazia. Some sozinha quando o efeito acaba.
#
#  Lê `StatusFX.ativos(meu_corpo)` — ver src/combat/StatusFX.gd.
#
#  ⚠️ Usa `Player.local_player()`, não `get_first_node_in_group("player")`: no
#  cliente o primeiro do grupo é o corpo do HOST, e o painel mostraria os status
#  do adversário. Foi bug real (docs/erros.md, 2026-08-10).
#
#  Os ícones são DESENHADOS (`_draw`), não carregados de arquivo. Combina com o
#  resto do jogo, que é procedural, e evita um .png que pode sumir do repositório
#  ou não importar num clone novo.
# ============================================================================

const PlayerScript := preload("res://Player.gd")

const LARGURA := 208.0
const ALTURA := 46.0
const ESPACO := 6.0
const MARGEM := 20.0
# Empurrado para baixo do painel de placar, que também mora no topo-direito
# (ver src/ui/MatchHud.gd — cronômetro + tabela). Sem isso os dois se cobrem.
const TOPO := 210.0

var _linhas: Dictionary = {}   # id do status -> nó da janelinha

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_dt: float) -> void:
	var eu := PlayerScript.local_player(get_tree())
	var ativos: Array = StatusFX.ativos(eu) if eu else []

	var vistos := {}
	for i in ativos.size():
		var st: Dictionary = ativos[i]
		var id: String = st["id"]
		vistos[id] = true
		var linha: Control = _linhas.get(id)
		if linha == null:
			linha = _criar_linha(st)
			_linhas[id] = linha
			add_child(linha)
		_atualizar_linha(linha, st, i)

	# Quem sumiu da lista já expirou — tira da tela.
	for id in _linhas.keys():
		if not vistos.has(id):
			_linhas[id].queue_free()
			_linhas.erase(id)

# ---------------------------------------------------------------- construção
func _criar_linha(st: Dictionary) -> Control:
	var cor: Color = st["cor"]

	var painel := ColorRect.new()
	painel.color = Color(0, 0, 0, 0.55)
	painel.size = Vector2(LARGURA, ALTURA)
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Faixa da cor do efeito na borda esquerda — dá para reconhecer o status pelo
	# canto do olho, sem ler o nome.
	var faixa := ColorRect.new()
	faixa.color = cor
	faixa.position = Vector2(0, 0)
	faixa.size = Vector2(3, ALTURA)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(faixa)

	var icone := StatusIcone.new()
	icone.tipo = str(st["icone"])
	icone.cor = cor
	icone.position = Vector2(10, 7)
	icone.size = Vector2(32, 32)
	icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(icone)

	var nome := Label.new()
	nome.name = "Nome"
	nome.text = str(st["nome"])
	nome.position = Vector2(50, 4)
	nome.add_theme_font_size_override("font_size", 15)
	nome.add_theme_color_override("font_color", cor)
	nome.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	nome.add_theme_constant_override("outline_size", 4)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(nome)

	var tempo := Label.new()
	tempo.name = "Tempo"
	tempo.position = Vector2(50, 22)
	tempo.add_theme_font_size_override("font_size", 13)
	tempo.add_theme_color_override("font_color", Color(1, 1, 1))
	tempo.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	tempo.add_theme_constant_override("outline_size", 3)
	tempo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(tempo)

	var trilho := ColorRect.new()
	trilho.color = Color(1, 1, 1, 0.15)
	trilho.position = Vector2(50, ALTURA - 9)
	trilho.size = Vector2(LARGURA - 62, 4)
	trilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(trilho)

	var barra := ColorRect.new()
	barra.name = "Barra"
	barra.color = cor
	barra.position = trilho.position
	barra.size = trilho.size
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel.add_child(barra)

	return painel

func _atualizar_linha(linha: Control, st: Dictionary, indice: int) -> void:
	linha.position = Vector2(
		size.x - LARGURA - MARGEM,
		TOPO + indice * (ALTURA + ESPACO))

	var restante: float = float(st["restante"])
	var total: float = maxf(float(st["total"]), 0.001)

	var tempo := linha.get_node_or_null("Tempo") as Label
	if tempo:
		# Abaixo de 10 s mostra uma casa decimal: em efeito curto, ver "0,4 s"
		# correndo é o que dá a sensação de que vai acabar.
		tempo.text = ("%.1f s" % restante) if restante < 10.0 else ("%d s" % int(ceil(restante)))

	var barra := linha.get_node_or_null("Barra") as ColorRect
	if barra:
		barra.size.x = (LARGURA - 62.0) * clampf(restante / total, 0.0, 1.0)

	# Pisca no último segundo e meio — aviso de que está saindo.
	if restante < 1.5:
		linha.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
	else:
		linha.modulate.a = 1.0


# ============================================================================
#  ÍCONE DESENHADO — sem arquivo de imagem.
# ============================================================================
class StatusIcone extends Control:
	var tipo: String = "generico"
	var cor: Color = Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.42
		match tipo:
			"gelo":
				# Cubo em perspectiva: losango no topo + duas faces laterais. Lê
				# como cubo de gelo mesmo em 32 px, o que um cubo de frente não faz.
				var topo := PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r, -r * 0.45),
					c + Vector2(0, r * 0.1), c + Vector2(-r, -r * 0.45)])
				draw_colored_polygon(topo, cor)
				var esq := PackedVector2Array([
					c + Vector2(-r, -r * 0.45), c + Vector2(0, r * 0.1),
					c + Vector2(0, r), c + Vector2(-r, r * 0.45)])
				draw_colored_polygon(esq, cor.darkened(0.35))
				var dir := PackedVector2Array([
					c + Vector2(r, -r * 0.45), c + Vector2(0, r * 0.1),
					c + Vector2(0, r), c + Vector2(r, r * 0.45)])
				draw_colored_polygon(dir, cor.darkened(0.55))
			"fogo":
				var chama := PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r * 0.7, r * 0.2),
					c + Vector2(r * 0.35, r), c + Vector2(-r * 0.35, r),
					c + Vector2(-r * 0.7, r * 0.2)])
				draw_colored_polygon(chama, cor)
				draw_circle(c + Vector2(0, r * 0.35), r * 0.3, cor.lightened(0.5))
			"vortice":
				for i in 3:
					var raio := r * (1.0 - i * 0.28)
					draw_arc(c, raio, PI * 0.2 + i * 0.7, PI * 1.7 + i * 0.7, 18, cor, 2.5)
			"buraco":
				draw_circle(c, r, Color(0, 0, 0, 0.9))
				draw_arc(c, r, 0.0, TAU, 28, cor, 3.0)
			"proibido":
				draw_arc(c, r, 0.0, TAU, 28, cor, 3.0)
				draw_line(c + Vector2(-r, -r) * 0.7, c + Vector2(r, r) * 0.7, cor, 3.0)
			"escudo":
				var esc := PackedVector2Array([
					c + Vector2(0, -r), c + Vector2(r * 0.8, -r * 0.4),
					c + Vector2(0, r), c + Vector2(-r * 0.8, -r * 0.4)])
				draw_colored_polygon(esc, cor)
			_:
				draw_circle(c, r * 0.8, cor)
