extends Control
## Ilustração vetorial editável da bancada; as regras vivem em FerrariaHud.
signal martelou(indice: int)
var etapa := 0
var alvo := 1
var impacto := 0.0
var acertou := true
var _ponto_do_impacto := 0
var _relogio := 0.0
const METAL := Color("72868b")
const LUZ := Color("b8ced0")
const OURO := Color("f2ca66")
const PONTOS := [Vector2(206, 88), Vector2(278, 88), Vector2(350, 88), Vector2(422, 88)]

func _ready() -> void:
	custom_minimum_size = Vector2(540, 190)
	mouse_filter = Control.MOUSE_FILTER_STOP

func atualizar(nova_etapa: int, novo_alvo: int) -> void:
	etapa = nova_etapa
	alvo = novo_alvo
	queue_redraw()

func tocar(sucesso: bool, indice := -1) -> void:
	acertou = sucesso
	_ponto_do_impacto = clampi(indice if indice >= 0 else alvo, 0, PONTOS.size() - 1)
	impacto = 1
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_relogio += delta
	impacto = maxf(0, impacto - delta * 2.5)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if etapa != 1: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = event.position * Vector2(600, 190) / size
		for i in PONTOS.size():
			if local.distance_to(PONTOS[i]) < 26:
				martelou.emit(i)
				accept_event()
				break

func _poly(pontos: Array, cor: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pontos), cor)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / Vector2(600, 190))
	draw_rect(Rect2(0, 0, 600, 190), Color("101e24"))
	# Madeira do banco e rebites: apoio comum às três ações.
	draw_rect(Rect2(12, 166, 576, 16), Color("503d30"))
	draw_line(Vector2(12, 167), Vector2(588, 167), Color("8f7353"), 2)
	for x in [28, 570]: draw_circle(Vector2(x, 175), 3, Color("c1a779"))
	match etapa:
		0: _fornalha()
		1: _bigorna()
		2: _tanque()

func _lamina(origem: Vector2, quente: bool) -> void:
	var cor := Color("ed9b4b") if quente else LUZ
	_poly([origem, origem + Vector2(277, 0), origem + Vector2(302, 15), origem + Vector2(277, 30), origem + Vector2(0, 30)], cor)
	_poly([origem + Vector2(0, 22), origem + Vector2(280, 22), origem + Vector2(302, 15), origem + Vector2(277, 30), origem + Vector2(0, 30)], Color("fff1bb") if quente else Color("e0eff0"))
	draw_line(origem + Vector2(12, 6), origem + Vector2(273, 6), Color("ffc66b") if quente else METAL, 2)
	draw_rect(Rect2(origem + Vector2(-64, 8), Vector2(64, 14)), Color("494f4f"))

func _fornalha() -> void:
	# Tijolos em juntas alternadas ao redor da boca escura.
	for fila in 5:
		for coluna in 6:
			var x := 152 + coluna * 48 + (fila % 2) * 24
			draw_rect(Rect2(x, 14 + fila * 30, 45, 27), Color("655449").lightened(float((fila + coluna) % 3) * 0.035))
	_poly([Vector2(213, 161), Vector2(213, 76), Vector2(233, 51), Vector2(267, 38), Vector2(323, 38), Vector2(359, 51), Vector2(379, 76), Vector2(379, 161)], Color("211d1c"))
	for i in 9:
		var x := 230.0 + i * 16
		var altura := 26 + 11 * sin(_relogio * 3 + i * 2) + impacto * 17
		_poly([Vector2(x - 11, 150), Vector2(x + 2, 150 - altura), Vector2(x + 12, 150)], Color("d66c36"))
		_poly([Vector2(x - 5, 150), Vector2(x + 3, 136 - impacto * 10), Vector2(x + 7, 150)], OURO)
	for i in 8: draw_circle(Vector2(234 + i * 17, 154), 8, Color("813c29"))
	_lamina(Vector2(174, 106), true)
	# Fole com couro plissado e bico voltado ao braseiro.
	_poly([Vector2(32, 114), Vector2(93, 87), Vector2(125, 124), Vector2(72, 147)], Color("876544"))
	for i in 5: draw_line(Vector2(44 + i * 10, 112 - i * 3), Vector2(76 + i * 9, 140 - i * 3), Color("b2946a"), 2)
	draw_line(Vector2(121, 122), Vector2(184, 141), METAL, 10)

func _bigorna() -> void:
	_poly([Vector2(125, 107), Vector2(440, 107), Vector2(489, 121), Vector2(421, 132), Vector2(389, 138), Vector2(380, 151), Vector2(419, 165), Vector2(209, 165), Vector2(241, 146), Vector2(213, 128), Vector2(141, 125)], Color("42535a"))
	draw_line(Vector2(125, 107), Vector2(440, 107), LUZ, 3)
	_lamina(Vector2(168, 73), true)
	for i in PONTOS.size():
		var p: Vector2 = PONTOS[i]
		var ativo := i == alvo
		draw_circle(p, 18, Color("1b2a30"))
		draw_arc(p, 19, 0, TAU, 40, OURO if ativo else METAL, 3 if ativo else 1, true)
		draw_string(ThemeDB.fallback_font, p + Vector2(-5, 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, OURO if ativo else LUZ)
	# Recuperação do martelo após o contato; o alvo continua livre para clicar.
	var batida: Vector2 = PONTOS[_ponto_do_impacto if impacto > 0 else alvo]
	var topo := Vector2(batida.x, 24 + impacto * 25)
	draw_line(topo + Vector2(7, 1), topo + Vector2(66, -15), Color("a47a4b"), 9)
	draw_rect(Rect2(topo - Vector2(15, 13), Vector2(30, 26)), METAL)
	draw_line(topo - Vector2(14, 12), topo + Vector2(14, -12), LUZ, 3)
	if impacto > 0:
		for i in 5:
			var p := Vector2(batida.x, 72)
			var dir := Vector2.from_angle(-PI + i * PI / 4)
			draw_line(p + dir * (10 + 20 * (1 - impacto)), p + dir * (19 + 20 * (1 - impacto)), Color(OURO if acertou else Color("dc6856"), impacto), 2)

func _tanque() -> void:
	_poly([Vector2(128, 99), Vector2(467, 99), Vector2(442, 164), Vector2(155, 164)], Color("65503d"))
	for i in 10: draw_line(Vector2(157 + i * 28, 110), Vector2(164 + i * 28, 160), Color("342b25"), 2)
	draw_rect(Rect2(151, 141, 295, 8), METAL)
	_elipse(Rect2(126, 76, 343, 49), Color("93acac"))
	_elipse(Rect2(133, 81, 329, 36), Color("315c6c"))
	_lamina(Vector2(165, 64 + impacto * 21), false)
	for i in 4:
		var x := 202 + i * 59
		draw_arc(Vector2(x, 101), 13 + impacto * 9, 0.1, PI - 0.1, 20, Color(LUZ, 0.45), 1.5, true)
		if impacto > 0:
			var pontos := PackedVector2Array()
			for j in 12: pontos.append(Vector2(x + sin(j * 0.6 + _relogio * 3) * 6, 80 - j * 4 - (1 - impacto) * 24))
			draw_polyline(pontos, Color(LUZ, impacto * 0.7), 3, true)

func _elipse(retangulo: Rect2, cor: Color) -> void:
	var pontos := PackedVector2Array()
	for i in 48: pontos.append(retangulo.get_center() + Vector2(cos(TAU * i / 48), sin(TAU * i / 48)) * retangulo.size * 0.5)
	draw_colored_polygon(pontos, cor)
