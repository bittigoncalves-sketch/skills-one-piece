extends SceneTree
## Dash aéreo: entradas, distâncias, escolhas de animação e regras existentes.
class CorpoFalso extends CharacterBody3D:
	var capacidades := CapacidadesDoJogador.new()
	var energy := 100.0
	func gastar_energia(valor: float) -> void:
		energy -= valor

var falhas := 0
var verificacoes := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var cena := Node3D.new()
	root.add_child(cena)
	current_scene = cena
	var corpo := CorpoFalso.new()
	cena.add_child(corpo)
	await process_frame
	corpo.capacidades.can_dash = true
	corpo.capacidades.custo_dash_no_ar = 0.0
	corpo.capacidades.recarga_dash_no_ar = 0.0
	var casos := [
		[Vector3.FORWARD, "frente"], [Vector3.BACK, "tras"],
		[Vector3.LEFT, "esquerda"], [Vector3.RIGHT, "direita"],
		[(Vector3.FORWARD + Vector3.LEFT).normalized(), "frente"],
		[(Vector3.BACK + Vector3.RIGHT).normalized(), "tras"],
	]
	for caso in casos:
		var ar := DashNoAr.new()
		ar.montar_em(corpo)
		var q := MoveFrame.new()
		q.dir = caso[0]
		q.dash_segurado = true
		ar.atualizar(0.016, q, false)
		_checar("direção " + str(caso[0]), ar.direcao().distance_to(caso[0]) < 0.001)
		_checar("clipe " + str(caso[1]), ar.clipe() == DashNoAr.CLIPES[caso[1]])
		var deslocamento := ar.velocidade(0.016) * 0.016
		q.dash_segurado = false
		for i in 20:
			ar.atualizar(0.016, q, false)
			deslocamento += ar.velocidade(0.016) * 0.016
		_checar("distância normalizada " + str(caso[0]), absf(deslocamento.length() - DashNoAr.DISTANCIA) < 0.001)
		_checar("fim sem imunidade", not ar.ativo() and not corpo.get_meta("damage_immune", false))
	for nome in DashNoAr.CLIPES:
		for caminho in [DashNoAr.CLIPES[nome], DashNoAr.CLIPES_ALTERNADOS[nome]]:
			_verificar_clipe(nome, caminho)
		var original := load(DashNoAr.CLIPES[nome]) as Animation
		var alternado := load(DashNoAr.CLIPES_ALTERNADOS[nome]) as Animation
		if original != null and alternado != null:
			var l := original.find_track(NodePath("Thigh_L:rotation"), Animation.TYPE_VALUE)
			var r := original.find_track(NodePath("Thigh_R:rotation"), Animation.TYPE_VALUE)
			var al := alternado.find_track(NodePath("Thigh_L:rotation"), Animation.TYPE_VALUE)
			var ar := alternado.find_track(NodePath("Thigh_R:rotation"), Animation.TYPE_VALUE)
			var troca_real := l >= 0 and r >= 0 and al >= 0 and ar >= 0
			if troca_real:
				var esquerda: Vector3 = original.value_track_interpolate(l, 0.095)
				var direita: Vector3 = original.value_track_interpolate(r, 0.095)
				troca_real = esquerda.distance_to(direita) > 0.1 and esquerda.distance_to(alternado.value_track_interpolate(ar, 0.095)) < 0.001 and direita.distance_to(alternado.value_track_interpolate(al, 0.095)) < 0.001
			_checar("o movimento das pernas realmente troca em " + nome, troca_real)
	var alternancia := DashNoAr.new()
	alternancia.montar_em(corpo)
	var q_alt := MoveFrame.new()
	q_alt.dir = Vector3.FORWARD
	for i in 4:
		q_alt.dash_segurado = true
		alternancia.atualizar(0.016, q_alt, false)
		_checar("dash %d alterna a perna" % (i + 1), alternancia.clipe() == (DashNoAr.CLIPES["frente"] if i % 2 == 0 else DashNoAr.CLIPES_ALTERNADOS["frente"]))
		q_alt.dash_segurado = false
		for j in 20: alternancia.atualizar(0.016, q_alt, false)
	# Apertar Q sem capacidade não pode gastar a próxima perna da sequência.
	corpo.capacidades.can_dash = false
	q_alt.dash_segurado = true
	alternancia.atualizar(0.016, q_alt, false)
	_checar("dash recusado não começa", not alternancia.ativo())
	q_alt.dash_segurado = false
	alternancia.atualizar(0.016, q_alt, false)
	corpo.capacidades.can_dash = true
	q_alt.dash_segurado = true
	alternancia.atualizar(0.016, q_alt, false)
	_checar("dash recusado não troca a próxima perna", alternancia.clipe() == DashNoAr.CLIPES["frente"])
	q_alt.dash_segurado = false
	for i in 20: alternancia.atualizar(0.016, q_alt, false)
	var mira := Vector3(0, 0.6, -0.8)
	for caso in [[1.0, 0.0, mira], [-1.0, 0.0, -mira], [1.0, -1.0, (mira + Vector3.LEFT).normalized()], [0.0, 1.0, Vector3.RIGHT]]:
		var ar := DashNoAr.new()
		ar.montar_em(corpo)
		var q := MoveFrame.new()
		q.f = caso[0]
		q.r = caso[1]
		q.dir = (q.frente * q.f + q.direita * q.r).normalized()
		q.dash_segurado = true
		ar.atualizar(0.016, q, false, mira)
		_checar("mira 3D f=%s r=%s" % [q.f, q.r], ar.direcao().distance_to(caso[2]) < 0.001)
	var vertical := DashNoAr.new()
	vertical.montar_em(corpo)
	var q_vertical := MoveFrame.new()
	q_vertical.f = 1.0
	q_vertical.dir = Vector3.FORWARD
	q_vertical.dash_segurado = true
	vertical.atualizar(0.016, q_vertical, false, Vector3(0, 0.99, -0.1).normalized())
	_checar("mira quase vertical dispara para cima", vertical.direcao().distance_to(Vector3.UP) < 0.001)
	_checar("cancelar remove imunidade", corpo.get_meta("damage_immune", false))
	vertical.cancelar()
	_checar("imunidade removida no cancelamento", not corpo.get_meta("damage_immune", false))
	print("DASH_AEREO: %d verificações; %d falhas" % [verificacoes, falhas])
	quit(1 if falhas else 0)

func _verificar_clipe(nome: String, caminho: String) -> void:
		var clip := load(caminho) as Animation
		_checar("clipe válido " + caminho, clip != null and is_equal_approx(clip.length, DashNoAr.TEMPO) and clip.get_track_count() >= 13)
		if clip != null:
			var joelhos_humanos := true
			for lado in ["L", "R"]:
				var faixa := clip.find_track(NodePath("Shin_" + lado + ":rotation"), Animation.TYPE_VALUE)
				if faixa < 0:
					joelhos_humanos = false
					continue
				for i in 29:
					var angulo: Vector3 = clip.value_track_interpolate(faixa, clip.length * i / 28.0)
					# Frente do corpo é -Z: o tornozelo deve dobrar para +Z no espaço da coxa.
					var canela := Basis.from_euler(angulo) * Vector3.DOWN
					if canela.z < -0.0001 or angulo.x < -PI:
						joelhos_humanos = false
			_checar("joelhos dobram para trás durante " + nome + " " + caminho, joelhos_humanos)

func _checar(nome: String, condicao: bool) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		push_error("FALHOU: " + nome)
