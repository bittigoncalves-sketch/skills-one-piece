class_name ArvoreDeConquistas
extends Control
## A ÁRVORE DE RAÍZES DAS CONQUISTAS (11/11/2026, pedido do dono: "um caminho pelas conquistas como se fosse as raízes de uma árvore, cores
## diferentes para a dificuldade"). Desenha o grafo de `pai` do mod (`McConquistas`) como um sistema de raízes que desce de um tronco:
##  • DIFICULDADE = a `moldura` do mod → cor E forma (a forma garante a leitura sem depender da cor): task = Fácil (verde, círculo),
##    goal = Média (azul, hexágono), challenge = Difícil (violeta, estrela).
##  • Caminho concluído acende: a raiz que leva a uma conquista feita fica com seiva da cor dela (e um brilho que corre pelo galho);
##    a ainda não feita fica casca escura. Conquista com vários critérios mostra um arco de progresso no aro.
##  • Arrastar move, roda do mouse dá zoom no cursor, passar o mouse mostra título, dificuldade, descrição e estado.
## Só LÊ (`ProgressaoDoPersonagem.conquistas_mod` + `McConquistas.definicoes()`). Pais sem título (nós internos do mod) são pulados: o filho
## liga ao ancestral visível mais próximo; as categorias raiz (gatilho `tick`) e os ancestrais de tick entram como estrutura, sempre acesos.
## Toda a geometria é em coordenadas LÓGICAS da árvore; `_desloc` e `_zoom` a levam à tela.

const ID_TRONCO := "_tronco"
const X_PASSO := 96.0
const Y_PASSO := 120.0
const ZOOM_MIN := 0.2
const ZOOM_MAX := 2.2
const ZOOM_TEXTO := 0.5                 # abaixo disto os títulos somem (a árvore vira mapa)
const PULSO_HZ := 20.0                  # o brilho corre; redesenhar a cada quadro não compensa

## Dificuldade: moldura do mod → {nome, cor, forma}. `moldura` desconhecida cai em Fácil.
const NIVEIS := {
	"task": {"nome": "Fácil", "cor": Color(0.36, 0.84, 0.52), "forma": 0},
	"goal": {"nome": "Média", "cor": Color(0.30, 0.67, 1.0), "forma": 1},
	"challenge": {"nome": "Difícil", "cor": Color(0.78, 0.40, 1.0), "forma": 2},
}
const ORDEM_DOS_NIVEIS := ["task", "goal", "challenge"]
const COR_TRONCO := Color(0.95, 0.79, 0.40)
const COR_CASCA := Color(0.20, 0.135, 0.095)
const COR_CASCA_LUZ := Color(0.36, 0.25, 0.17)

class No:
	extends RefCounted
	var id := ""
	var def = null                       # McConquistas.Def (nulo no tronco)
	var pai: No = null
	var filhos: Array[No] = []
	var pos := Vector2.ZERO              # lógico
	var nivel := "task"
	var feita := false
	var fracao := 1.0                    # critérios feitos / total
	var folhas := 1
	var raio := 15.0
	var curva := PackedVector2Array()    # a raiz que chega neste nó (lógico), vazia no tronco
	var fase := 0.0                      # 0..1, deslocamento do brilho

var nos: Array[No] = []
var raiz: No = null
var progressao: ProgressaoDoPersonagem
var _zoom := 0.8
var _desloc := Vector2.ZERO
var _arrasto := false
var _sobre: No = null
var _tempo := 0.0
var _vista_pronta := false
var _acumulo := 0.0
var _fonte: Font
var _titulo_cache := {}                  # id → texto traduzido


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(320, 240)
	_fonte = get_theme_default_font()
	resized.connect(_ao_redimensionar)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))
	set_process(false)


func ligar(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	reconstruir()


# ------------------------------------------------------------------ dados e layout
## Nível de dificuldade de uma moldura do mod.
static func nivel_de(moldura: String) -> String:
	return moldura if NIVEIS.has(moldura) else "task"


## Conquistas que entram na árvore: as que o jogador faz + seus ancestrais com título (estrutura).
static func ids_da_arvore() -> Array:
	var defs := McConquistas.definicoes()
	var manter := {}
	for id: String in defs:
		var d: Variant = defs[id]
		if d != null and d.titulo != "" and d.gatilho != "tick":
			manter[id] = true
			var p: String = d.pai
			while defs.has(p) and defs[p] != null:
				if defs[p].titulo != "":
					manter[p] = true
				p = defs[p].pai
	return manter.keys()


func reconstruir() -> void:
	nos.clear()
	_titulo_cache.clear()
	var defs := McConquistas.definicoes()
	raiz = No.new()
	raiz.id = ID_TRONCO
	raiz.feita = true
	raiz.raio = 27.0
	nos.append(raiz)
	var por_id := {ID_TRONCO: raiz}
	var ids := ids_da_arvore()
	ids.sort()                           # ordem estável: a árvore não muda de cara entre aberturas
	for id: String in ids:
		var n := No.new()
		n.id = id
		n.def = defs[id]
		n.nivel = nivel_de(n.def.moldura)
		n.raio = [15.0, 17.0, 20.0][NIVEIS[n.nivel]["forma"]]
		n.fase = float(hash(id) & 0xffff) / 65535.0
		por_id[id] = n
		nos.append(n)
	for id: String in ids:
		var n: No = por_id[id]
		var p: String = n.def.pai
		while defs.has(p) and defs[p] != null and not por_id.has(p):
			p = defs[p].pai
		n.pai = por_id[p] if por_id.has(p) and p != id else raiz
		n.pai.filhos.append(n)
	_ordenar(raiz)
	var cursor := [0.0]
	_posicionar(raiz, 0, cursor)
	var meio: float = (cursor[0] - 1.0) * X_PASSO * 0.5
	for n in nos:
		n.pos.x -= meio
	for n in nos:
		if n.pai != null:
			n.curva = _raiz_entre(n.pai, n)
	atualizar()
	_vista_pronta = false
	_ao_redimensionar()


## Filhos com mais descendentes primeiro, depois pelo título: o galho grosso fica de um lado e o resultado é estável.
func _ordenar(n: No) -> void:
	for f in n.filhos:
		_ordenar(f)
	n.filhos.sort_custom(func(a: No, b: No) -> bool:
		if a.folhas != b.folhas:
			return a.folhas > b.folhas
		return a.id < b.id)


## Folhas ocupam colunas consecutivas; o pai fica no meio dos filhos; a profundidade é a linha.
func _posicionar(n: No, profundidade: int, cursor: Array) -> void:
	n.pos.y = profundidade * Y_PASSO
	if n.filhos.is_empty():
		n.folhas = 1
		n.pos.x = cursor[0] * X_PASSO
		cursor[0] += 1.0
		return
	n.folhas = 0
	for f in n.filhos:
		_posicionar(f, profundidade + 1, cursor)
		n.folhas += f.folhas
	n.pos.x = (n.filhos[0].pos.x + n.filhos[n.filhos.size() - 1].pos.x) * 0.5


## A raiz do pai ao filho: Bézier vertical com uma ondulação fixa (semente = id), para o galho parecer raiz e não régua.
static func _raiz_entre(pai: No, filho: No) -> PackedVector2Array:
	var a := pai.pos + Vector2(0, pai.raio * 0.8)
	var b := filho.pos - Vector2(0, filho.raio * 0.8)
	var dy := maxf(b.y - a.y, 1.0)
	var c1 := a + Vector2(0, dy * 0.62)
	var c2 := b - Vector2(0, dy * 0.42)
	var semente := float(hash(filho.id) & 0xffff) / 65535.0
	var saida := PackedVector2Array()
	const PASSOS := 16
	for i in PASSOS + 1:
		var t := float(i) / PASSOS
		var u := 1.0 - t
		var p := a * (u * u * u) + c1 * (3.0 * u * u * t) + c2 * (3.0 * u * t * t) + b * (t * t * t)
		p.x += sin(t * TAU * (1.0 + semente) + semente * 6.0) * 7.0 * sin(t * PI)
		saida.append(p)
	return saida


## Estado (feita, fração) a partir da progressão; barato, roda a cada mudança de progresso.
func atualizar() -> void:
	for n in nos:
		if n.def == null:
			continue
		if n.def.gatilho == "tick":
			n.feita = true
			n.fracao = 1.0
			continue
		var feitos: Array = progressao.conquistas_mod.get(n.id, []) if progressao != null else []
		var total: int = n.def.criterios.size()
		var certos: int = n.def.criterios.filter(func(c): return feitos.has(c)).size() if total > 0 else 0
		n.feita = total > 0 and certos >= total
		n.fracao = float(certos) / float(total) if total > 0 else 0.0
	queue_redraw()


## Contagem por dificuldade: {nivel: [feitas, total]} só das conquistas que o jogador faz (sem o tronco nem as categorias).
func contagem() -> Dictionary:
	var c := {}
	for nv in ORDEM_DOS_NIVEIS:
		c[nv] = [0, 0]
	for n in nos:
		if n.def == null or n.def.gatilho == "tick":
			continue
		c[n.nivel][1] += 1
		if n.feita:
			c[n.nivel][0] += 1
	return c


func texto_do(n: No) -> String:
	if n.def == null:
		return "MINE PIECE"
	if not _titulo_cache.has(n.id):
		_titulo_cache[n.id] = McTexto.traduzir(n.def.titulo)
	return _titulo_cache[n.id]


# ------------------------------------------------------------------ vista
func ver_tudo() -> void:
	if nos.is_empty() or size.x < 10.0:
		return
	_vista_pronta = true
	var r := Rect2(nos[0].pos, Vector2.ZERO)
	for n in nos:
		r = r.expand(n.pos)
	r = r.grow_individual(60.0, 50.0, 60.0, 90.0)
	_zoom = clampf(minf(size.x / r.size.x, size.y / r.size.y), ZOOM_MIN, 1.0)
	_desloc = size * 0.5 - (r.position + r.size * 0.5) * _zoom
	queue_redraw()


## O tronco no alto e centrado, com a árvore em tamanho de leitura (as raízes descem para fora da tela e se alcança com o arrasto).
func centralizar() -> void:
	if raiz == null or size.x < 10.0:
		return
	_vista_pronta = true
	_zoom = 0.85
	_desloc = Vector2(size.x * 0.5, 70.0) - raiz.pos * _zoom
	queue_redraw()


## A primeira medida válida enquadra a árvore inteira; depois disso o redimensionar só mantém a vista do jogador.
func _ao_redimensionar() -> void:
	if not _vista_pronta and size.x > 10.0 and not nos.is_empty():
		centralizar()
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var b := e as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			_arrasto = b.pressed
			accept_event()
		elif b.pressed and (b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			_dar_zoom(1.12 if b.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12, b.position)
			accept_event()
	elif e is InputEventMouseMotion:
		var m := e as InputEventMouseMotion
		if _arrasto:
			_desloc += m.relative
			queue_redraw()
		var novo := no_em(m.position)
		if novo != _sobre or _arrasto:
			_sobre = novo
			queue_redraw()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_sobre = null
		_arrasto = false
		queue_redraw()


func _dar_zoom(fator: float, ancora: Vector2) -> void:
	var novo := clampf(_zoom * fator, ZOOM_MIN, ZOOM_MAX)
	var logico := (ancora - _desloc) / _zoom
	_zoom = novo
	_desloc = ancora - logico * _zoom
	queue_redraw()


func a_tela(p: Vector2) -> Vector2:
	return _desloc + p * _zoom


func no_em(tela: Vector2) -> No:
	var lp := (tela - _desloc) / _zoom
	var melhor: No = null
	var dist := INF
	for n in nos:
		var d := n.pos.distance_to(lp)
		if d <= n.raio * 1.5 and d < dist:
			melhor = n
			dist = d
	return melhor


func _process(delta: float) -> void:
	_tempo += delta
	_acumulo += delta
	if _acumulo >= 1.0 / PULSO_HZ:
		_acumulo = 0.0
		queue_redraw()


# ------------------------------------------------------------------ desenho
func _draw() -> void:
	_desenhar_fundo()
	if raiz == null:
		return
	draw_set_transform(_desloc, 0.0, Vector2(_zoom, _zoom))
	for n in nos:
		if not n.curva.is_empty():
			_desenhar_raiz(n)
	for n in nos:
		_desenhar_no(n)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _zoom >= ZOOM_TEXTO:
		for n in nos:
			_desenhar_titulo(n)
	_desenhar_legenda()
	if _sobre != null:
		_desenhar_dica(_sobre)


func _desenhar_fundo() -> void:
	# Terra: do azul-petróleo do painel, quase preto, ao marrom fundo — a árvore "cresce" para baixo, dentro dela.
	var topo := Color(0.03, 0.085, 0.10)
	var fundo := Color(0.045, 0.04, 0.045)
	const FAIXAS := 16
	for i in FAIXAS:
		var t := float(i) / (FAIXAS - 1)
		draw_rect(Rect2(0, size.y * i / FAIXAS, size.x, size.y / FAIXAS + 1.0), topo.lerp(fundo, t))
	var centro := a_tela(raiz.pos if raiz != null else Vector2.ZERO)
	for i in 8:                              # luz do tronco: anéis fracos empilhados (borda macia, sem shader)
		draw_circle(centro, (60.0 + i * 34.0) * maxf(_zoom, 0.4), Color(COR_TRONCO, 0.012))


func _desenhar_raiz(n: No) -> void:
	var largura := 2.5 + sqrt(float(n.folhas)) * 1.7
	var cor: Color = NIVEIS[n.nivel]["cor"]
	draw_polyline(n.curva, COR_CASCA, largura, true)
	draw_polyline(_deslocada(n.curva, Vector2(-largura * 0.22, 0)), Color(COR_CASCA_LUZ, 0.55), maxf(largura * 0.32, 1.0), true)
	if n.feita:
		draw_polyline(n.curva, Color(cor, 0.9), maxf(largura * 0.42, 1.5), true)
		var t := fposmod(_tempo * 0.28 + n.fase, 1.0)
		var i := clampi(int(t * (n.curva.size() - 1)), 0, n.curva.size() - 1)
		draw_circle(n.curva[i], largura * 0.62, Color(1, 1, 1, 0.85))
		draw_circle(n.curva[i], largura * 1.1, Color(cor, 0.35))
	else:
		draw_polyline(n.curva, Color(cor, 0.16), maxf(largura * 0.28, 1.0), true)


static func _deslocada(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var s := PackedVector2Array()
	for v in p:
		s.append(v + d)
	return s


func _desenhar_no(n: No) -> void:
	if n.def == null:
		_desenhar_tronco(n)
		return
	var info: Dictionary = NIVEIS[n.nivel]
	var cor: Color = info["cor"]
	var contorno := _forma(n.pos, n.raio, int(info["forma"]))
	var foco := n == _sobre
	if n.feita:
		var pulso := 0.5 + 0.5 * sin(_tempo * 2.2 + n.fase * TAU)
		draw_circle(n.pos, n.raio * (1.9 + 0.25 * pulso), Color(cor, 0.10))
		draw_circle(n.pos, n.raio * 1.45, Color(cor, 0.16))
		draw_colored_polygon(contorno, cor.lerp(Color.WHITE, 0.15))
		draw_colored_polygon(_forma(n.pos, n.raio * 0.55, int(info["forma"])), cor.lerp(Color.WHITE, 0.72))
	else:
		draw_colored_polygon(contorno, Color(0.045, 0.05, 0.06))
		draw_colored_polygon(_forma(n.pos, n.raio * 0.5, int(info["forma"])), Color(cor, 0.12))
	var aro := Color(cor, 1.0 if n.feita or foco else 0.55)
	draw_polyline(_fechada(contorno), aro, 2.5 if foco else 2.0, true)
	if not n.feita and n.fracao > 0.0:        # progresso parcial: arco por fora do aro
		draw_arc(n.pos, n.raio * 1.28, -PI * 0.5, -PI * 0.5 + TAU * n.fracao, 24, cor, 3.0, true)
	if foco:
		draw_arc(n.pos, n.raio * 1.7, 0.0, TAU, 32, Color(1, 1, 1, 0.55), 1.5, true)


func _desenhar_tronco(n: No) -> void:
	var pulso := 0.5 + 0.5 * sin(_tempo * 1.6)
	draw_circle(n.pos, n.raio * (2.4 + 0.3 * pulso), Color(COR_TRONCO, 0.07))
	draw_circle(n.pos, n.raio * 1.5, Color(COR_TRONCO, 0.14))
	draw_circle(n.pos, n.raio, COR_CASCA)
	draw_arc(n.pos, n.raio, 0.0, TAU, 40, COR_TRONCO, 3.0, true)
	draw_circle(n.pos, n.raio * 0.5, COR_TRONCO)


## 0 círculo, 1 hexágono, 2 estrela de quatro pontas (8 vértices alternando raio longo e curto).
static func _forma(c: Vector2, r: float, tipo: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	match tipo:
		0:
			for i in 20:
				var a := TAU * i / 20.0
				p.append(c + Vector2(cos(a), sin(a)) * r)
		1:
			for i in 6:
				var a := TAU * i / 6.0 + PI / 6.0
				p.append(c + Vector2(cos(a), sin(a)) * r * 1.08)
		_:
			for i in 8:
				var a := TAU * i / 8.0 - PI * 0.5
				p.append(c + Vector2(cos(a), sin(a)) * r * (1.3 if i % 2 == 0 else 0.7))
	return p


static func _fechada(p: PackedVector2Array) -> PackedVector2Array:
	var f := p.duplicate()
	f.append(p[0])
	return f


func _desenhar_titulo(n: No) -> void:
	if _fonte == null:
		return
	var tamanho := clampi(roundi(13.0 * clampf(_zoom, 0.6, 1.3)), 9, 18)
	var largura := X_PASSO * _zoom * 0.98
	var centro := a_tela(n.pos + Vector2(0, n.raio * 1.5 + 4.0))
	var cor := COR_TRONCO if n.def == null else (EstiloDaHistoria.TEXTO if n.feita else EstiloDaHistoria.TEXTO_2)
	if n.def != null and not n.feita:
		cor = Color(cor, 0.78)
	var pos := Vector2(centro.x - largura * 0.5, centro.y + tamanho)
	draw_multiline_string_outline(_fonte, pos, texto_do(n), HORIZONTAL_ALIGNMENT_CENTER, largura, tamanho, 2, 4, Color(0, 0, 0, 0.85))
	draw_multiline_string(_fonte, pos, texto_do(n), HORIZONTAL_ALIGNMENT_CENTER, largura, tamanho, 2, cor)


func _desenhar_legenda() -> void:
	var caixa := Rect2(10, 10, 168, 18 + ORDEM_DOS_NIVEIS.size() * 22)
	draw_rect(caixa, Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(caixa, Color(COR_TRONCO, 0.4), false, 1.0)
	if _fonte == null:
		return
	var cont := contagem()
	var y := caixa.position.y + 18.0
	draw_string(_fonte, Vector2(caixa.position.x + 10, y - 2), "DIFICULDADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EstiloDaHistoria.TEXTO_3)
	for nv: String in ORDEM_DOS_NIVEIS:
		y += 22.0
		var info: Dictionary = NIVEIS[nv]
		var c: Color = info["cor"]
		var centro := Vector2(caixa.position.x + 20, y - 5)
		var forma := _forma(centro, 7.0, int(info["forma"]))
		draw_colored_polygon(forma, c)
		var f: Array = cont[nv]
		draw_string(_fonte, Vector2(caixa.position.x + 36, y), "%s  %d/%d" % [info["nome"], f[0], f[1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c.lerp(Color.WHITE, 0.35))


func _desenhar_dica(n: No) -> void:
	if _fonte == null:
		return
	var linhas: Array[String] = [texto_do(n)]
	var cor := COR_TRONCO
	if n.def != null:
		var info: Dictionary = NIVEIS[n.nivel]
		cor = info["cor"]
		linhas.append("Dificuldade: " + str(info["nome"]))
		var desc := McTexto.traduzir(n.def.descricao)
		if desc != "":
			linhas.append(desc)
		linhas.append("✔ Concluída" if n.feita else ("Em andamento (%d%%)" % roundi(n.fracao * 100.0) if n.fracao > 0.0 else "Ainda não feita"))
	else:
		linhas.append("A árvore de todas as conquistas.")
	const LARG := 270.0
	var altura := 14.0
	var tams := [15, 12, 13, 12]
	for i in linhas.size():
		altura += _fonte.get_multiline_string_size(linhas[i], HORIZONTAL_ALIGNMENT_LEFT, LARG, tams[i]).y + 3.0
	var alvo := a_tela(n.pos) + Vector2(n.raio * _zoom + 18.0, -altura * 0.5)
	alvo.x = clampf(alvo.x, 6.0, maxf(6.0, size.x - LARG - 20.0))
	alvo.y = clampf(alvo.y, 6.0, maxf(6.0, size.y - altura - 6.0))
	var r := Rect2(alvo, Vector2(LARG + 14.0, altura))
	draw_rect(r, Color(0.02, 0.05, 0.07, 0.96))
	draw_rect(r, Color(cor, 0.9), false, 2.0)
	var y := r.position.y + 8.0
	for i in linhas.size():
		var c2 := cor.lerp(Color.WHITE, 0.3) if i == 0 else (EstiloDaHistoria.TEXTO if i == 2 else EstiloDaHistoria.TEXTO_2)
		var h := _fonte.get_multiline_string_size(linhas[i], HORIZONTAL_ALIGNMENT_LEFT, LARG, tams[i]).y
		draw_multiline_string(_fonte, Vector2(r.position.x + 7.0, y + tams[i]), linhas[i], HORIZONTAL_ALIGNMENT_LEFT, LARG, tams[i], -1, c2)
		y += h + 3.0
