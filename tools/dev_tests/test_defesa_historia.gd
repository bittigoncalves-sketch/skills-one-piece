extends SceneTree
# ============================================================================
#  TESTE DE DEFESA DO COMBATE DIRECIONAL — guarda, postura e quebra, dois corpos.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md, Fase 4. O jogador real do Modo História
#  e um `BonecoDeDuelo`:
#    A. guarda frontal segura as 4 direções: sem dano, postura cai o da ficha;
#    B. a mesma guarda pelas costas não segura (controle de A);
#    C. postura baixa → QUEBRA sem dano, e o golpe seguinte ENTRA durante a quebra;
#    D. a guarda serve à IA: o boneco em guarda segura o jab do jogador;
#    E. o cérebro de treino luta sozinho (ataque em ciclo contra a guarda do jogador);
#    e o tempo do jogo nunca muda.
#
#  ⚠️ Montagem herdada do test_contato_historia (boneco nasce longe; jogador antes
#  do boneco ao posicionar; pré-condição de chão e distância contada).
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_defesa_historia.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_defesa_historia_progresso.json"
const D := GolpeDirecional.Direcao
const R := ResolucaoDeContato.Resultado
const PERTO := 1.1

var _falhas := 0
var _escala_de_tempo_mudou := false
var _posicoes_invalidas := 0


func _init() -> void:
	await process_frame
	print("\n===== DEFESA DO COMBATE DIRECIONAL =====")
	var mh: GDScript = load("res://src/historia/ModoHistoria.gd")
	mh.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	mh.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame

	var jogador := _jogador_local()
	jogador.capacidades = CapacidadesDoJogador.completas()
	# Este teste mede a GEOMETRIA do contato num duelo parado: o knockback Minecraft da
	# história (23/10/2026: 2 m de empurrão + 0,5 s invulnerável) desmontaria o "lado a
	# lado" entre golpes. Ele tem teste próprio (`test_knockback_minecraft`).
	jogador.knockback_minecraft = null
	jogador.max_health = 1000.0
	jogador.health = 1000.0
	var boneco: Node = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	boneco.name = "BonecoDeDuelo"
	boneco.vida_maxima = 100000.0
	boneco.position = Vector3(0, 0.8, -4.0)
	current_scene.add_child(boneco)
	await _quadros(10)

	await _guarda_frontal(jogador, boneco)
	await _pelas_costas(jogador, boneco)
	await _quebra(jogador, boneco)
	await _boneco_defende(jogador, boneco)
	await _cerebro(jogador, boneco)
	_ok(not _escala_de_tempo_mudou, "Engine.time_scale ficou em 1,0 o teste inteiro")
	_ok(_posicoes_invalidas == 0, "pré-condição: posicionamentos válidos (%d inválido(s))" % _posicoes_invalidas)

	mh.set("mapa_forcado", "")
	mh.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _jogador_local() -> Node:
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
		if not is_equal_approx(Engine.time_scale, 1.0):
			_escala_de_tempo_mudou = true


func _livres(jogador: Node, boneco: Node) -> void:
	var a: ExecutorCorpoACorpo = jogador.combate_direcional
	var b: ExecutorCorpoACorpo = boneco.combate_direcional
	a.baixar_guarda()
	b.baixar_guarda()
	for i in 180:
		if a.estado == ExecutorCorpoACorpo.Estado.NEUTRO and b.estado == ExecutorCorpoACorpo.Estado.NEUTRO:
			break
		await _quadros(1)
	a.postura = a.estilo.postura_maxima
	b.postura = b.estilo.postura_maxima


## Jogador na origem olhando para −Z; boneco à frente olhando para ele (ou o jogador
## de costas para o boneco, se `jogador_de_costas`).
func _posicionar(jogador: Node, boneco: Node, jogador_de_costas := false) -> void:
	await _livres(jogador, boneco)
	var yaw_jogador := PI if jogador_de_costas else 0.0
	jogador.velocity = Vector3.ZERO
	# O empurrão do dano NÃO mora na `velocity` (health_controller.gd): logo depois de
	# um acerto no jogador ele ainda o arrastava 6–9 cm após o teletransporte (16/09).
	jogador._vida._empurrao = Vector3.ZERO
	jogador.global_position = Vector3(0, jogador.global_position.y, 0)
	jogador._yaw = yaw_jogador
	jogador.modelo_visual().rotation.y = yaw_jogador
	await _quadros(2)
	boneco.parar()
	boneco.global_position = Vector3(0, jogador.global_position.y, -PERTO)
	# Yaw PI olha para +Z (para o jogador). Yaw 0 olha para −Z — errei isso na primeira
	# versão, e o boneco golpeava de costas para o jogador (zero contatos).
	boneco.encarar_yaw(PI)
	boneco.modelo_visual().rotation.y = PI
	await _quadros(8)
	var plano := Vector2(boneco.global_position.x, boneco.global_position.z - jogador.global_position.z).length()
	if absf(jogador.global_position.y - boneco.global_position.y) > 0.05 or absf(plano - PERTO) > 0.05:
		_posicoes_invalidas += 1
		print("     ⚠️ posição inválida: jogador %s, boneco %s" % [jogador.global_position, boneco.global_position])


## Um golpe de `atacante` e os contatos que ele produziu (com o estado do defensor
## no instante do contato).
func _golpe(atacante: Node, defensor: Node, direcao: int) -> Array:
	var e: ExecutorCorpoACorpo = atacante.combate_direcional
	var d: ExecutorCorpoACorpo = defensor.combate_direcional
	var contatos: Array = []
	# O estado do defensor é o do quadro ANTERIOR ao contato: quando o sinal chega, a
	# resolução já o passou para REAÇÃO (primeira versão deste teste lia tarde).
	var antes_do_contato := [d.estado]
	var cb := func(_id, _alvo, resultado, _lado, _pos, golpe):
		contatos.append({"resultado": resultado, "golpe": golpe, "estado_defensor": antes_do_contato[0],
			"vida_defensor": float(defensor.health), "postura_defensor": d.postura})
	e.contato.connect(cb)
	_ok(e.pedir_ataque(direcao), "(preparação) %s começou %s" % [atacante.name, D.keys()[direcao]])
	for i in 150:
		antes_do_contato[0] = d.estado
		await _quadros(1)
		if not e.atacando():
			break
	e.contato.disconnect(cb)
	return contatos


# ---------------------------------------------------------------------- A
func _guarda_frontal(jogador: Node, boneco: Node) -> void:
	print("\n-- A. guarda frontal segura as quatro direções --")
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	for direcao in [D.FRENTE, D.PARA_ESQUERDA, D.PARA_DIREITA, D.DE_CIMA]:
		await _posicionar(jogador, boneco)
		e.erguer_guarda()
		await _quadros(10)
		var vida := float(jogador.health)
		var postura := e.postura
		var contatos := await _golpe(boneco, jogador, direcao)
		var g: GolpeDirecional = boneco.combate_direcional.estilo.golpe_para(direcao)
		var ok: bool = contatos.size() == 1 and contatos[0]["resultado"] == R.BLOQUEIO \
			and is_equal_approx(contatos[0]["vida_defensor"], vida) \
			and is_equal_approx(contatos[0]["postura_defensor"], postura - g.dano_de_postura)
		_ok(ok, "%s bloqueado: sem dano, postura %.0f → %.0f (ficha −%.0f); contatos %s" % [D.keys()[direcao], postura,
			contatos[0]["postura_defensor"] if contatos.size() > 0 else -1.0, g.dano_de_postura,
			str(contatos.map(func(c): return R.keys()[c["resultado"]]))])


# ---------------------------------------------------------------------- B
func _pelas_costas(jogador: Node, boneco: Node) -> void:
	print("\n-- B. a mesma guarda, de costas para o golpe --")
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	await _posicionar(jogador, boneco, true)
	e.erguer_guarda()
	await _quadros(10)
	var vida := float(jogador.health)
	var contatos := await _golpe(boneco, jogador, D.FRENTE)
	_ok(contatos.size() == 1 and contatos[0]["resultado"] == R.ACERTO and contatos[0]["vida_defensor"] < vida,
		"pelas costas a guarda não segura: ACERTO com dano (%s)" % str(contatos.map(func(c): return R.keys()[c["resultado"]])))


# ---------------------------------------------------------------------- C
func _quebra(jogador: Node, boneco: Node) -> void:
	print("\n-- C. postura baixa: quebra, e o golpe seguinte entra --")
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	await _posicionar(jogador, boneco)
	e.erguer_guarda()
	await _quadros(10)
	e.postura = 10.0
	var vida := float(jogador.health)
	var primeiro := await _golpe(boneco, jogador, D.PARA_ESQUERDA)
	# "Sem dano" = a vida não CAIU (ela regenera 0,5%/s entre a leitura e o contato).
	_ok(primeiro.size() == 1 and primeiro[0]["resultado"] == R.QUEBRA_DE_GUARDA and primeiro[0]["vida_defensor"] >= vida - 0.001,
		"postura 10 contra gancho (25): QUEBRA sem dano (%s)" % str(primeiro.map(func(c): return R.keys()[c["resultado"]])))
	_ok(e.estado == ExecutorCorpoACorpo.Estado.QUEBRA or e.estado == ExecutorCorpoACorpo.Estado.GUARDA,
		"(o jogador está em %s)" % ExecutorCorpoACorpo.Estado.keys()[e.estado])
	var segundo := await _golpe(boneco, jogador, D.FRENTE)
	_ok(segundo.size() == 1 and segundo[0]["resultado"] == R.ACERTO
		and segundo[0]["estado_defensor"] == ExecutorCorpoACorpo.Estado.QUEBRA,
		"o jab seguinte ENTRA ainda na quebra (resultado %s, jogador em %s) — a quebra rende um acerto"
		% [R.keys()[segundo[0]["resultado"]] if segundo.size() > 0 else "-",
		ExecutorCorpoACorpo.Estado.keys()[segundo[0]["estado_defensor"]] if segundo.size() > 0 else "-"])

	# Portão de game feel (16/09): a quebra tem de render acerto com QUALQUER golpe —
	# inclusive o overhand, o de maior resto (antes da invariante nova, não rendia).
	# Gancho: UM clique de reação, 0,25 s depois do contato. Overhand: clicando sem parar
	# desde a reação (o clique cedo demais é descartado; o que cabe no buffer fica).
	for caso in [[D.PARA_ESQUERDA, 0.25, false], [D.DE_CIMA, 0.25, true]]:
		await _quebra_e_resposta(jogador, boneco, caso[0], caso[1], caso[2])


func _quebra_e_resposta(jogador: Node, boneco: Node, direcao_quebra: int, reacao: float, martelando: bool) -> void:
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	var b: ExecutorCorpoACorpo = boneco.combate_direcional
	await _posicionar(jogador, boneco)
	e.erguer_guarda()
	await _quadros(10)
	e.postura = 10.0
	var contatos: Array = []
	var antes := [e.estado]
	var cb := func(_id, _alvo, resultado, _lado, _pos, golpe): contatos.append([resultado, golpe, antes[0]])
	b.contato.connect(cb)
	b.pedir_ataque(direcao_quebra)
	for i in 120:
		antes[0] = e.estado
		await _quadros(1)
		if not contatos.is_empty():
			break
	var quebrou: bool = contatos.size() == 1 and contatos[0][0] == R.QUEBRA_DE_GUARDA
	await _quadros(int(round(reacao * 60.0)))
	var aceito := b.pedir_ataque(D.FRENTE)
	for i in 90:
		if aceito or not martelando:
			break
		await _quadros(1)
		aceito = b.pedir_ataque(D.FRENTE)
	for i in 150:
		antes[0] = e.estado
		await _quadros(1)
		if contatos.size() >= 2 and not b.atacando():
			break
	b.contato.disconnect(cb)
	var jab_entrou: bool = contatos.size() >= 2 and contatos[1][0] == R.ACERTO and contatos[1][2] == ExecutorCorpoACorpo.Estado.QUEBRA
	_ok(quebrou and aceito and jab_entrou,
		"quebra por %s, jab %s a %.2f s da quebra: %s (jogador em %s no contato)"
		% [D.keys()[direcao_quebra], "martelado" if martelando else "num clique", reacao,
		str(contatos.map(func(c): return R.keys()[c[0]])),
		ExecutorCorpoACorpo.Estado.keys()[contatos[1][2]] if contatos.size() >= 2 else "-"])


# ---------------------------------------------------------------------- D
func _boneco_defende(jogador: Node, boneco: Node) -> void:
	print("\n-- D. a guarda serve à IA --")
	await _posicionar(jogador, boneco)
	var b: ExecutorCorpoACorpo = boneco.combate_direcional
	b.erguer_guarda()
	# Espera a janela de APARO (0,2 s) FECHAR: o executor conta tempo pelo `delta` do quadro de processo (em headless 20 quadros de física valem ~0,08 s de jogo), então contar quadros
	# não garante passar da janela — com a guarda ainda "fresca" o jab caía no APARO em vez do bloqueio simples.
	for i in 600:
		await _quadros(1)
		if not b.aparando():
			break
	var vida := float(boneco.health)
	var contatos := await _golpe(jogador, boneco, D.FRENTE)
	_ok(contatos.size() == 1 and contatos[0]["resultado"] == R.BLOQUEIO and is_equal_approx(boneco.health, vida),
		"o boneco em guarda segura o jab do jogador sem dano (%s)" % str(contatos.map(func(c): return R.keys()[c["resultado"]])))
	b.baixar_guarda()


# ---------------------------------------------------------------------- E
func _cerebro(jogador: Node, boneco: Node) -> void:
	print("\n-- E. o cérebro de treino luta sozinho --")
	await _posicionar(jogador, boneco)
	var e: ExecutorCorpoACorpo = jogador.combate_direcional
	e.erguer_guarda()
	var cerebro := CerebroDeTreino.new()
	cerebro.modo = CerebroDeTreino.Modo.ATACA_EM_CICLO
	cerebro.intervalo = 1.0
	var seq: Array[int] = [D.FRENTE, D.PARA_ESQUERDA]
	cerebro.sequencia = seq
	cerebro.montar(boneco, jogador)
	boneco.add_child(cerebro)
	var resultados: Array = []
	var cb := func(_id, _alvo, resultado, _lado, _pos, _golpe): resultados.append(resultado)
	boneco.combate_direcional.contato.connect(cb)
	var vida := float(jogador.health)
	await _quadros(330)      # 5,5 s de FÍSICA: o ciclo do cérebro é ~2,3 s (intervalo 1,0 + preparo + recuperação, medido em 15/11/2026); em 3,6 s cabiam só 1–2 ataques
	boneco.combate_direcional.contato.disconnect(cb)
	cerebro.queue_free()
	_ok(resultados.size() >= 2 and resultados.all(func(r): return r == R.BLOQUEIO) and jogador.health >= vida - 0.001,
		"em 5,5 s o cérebro atacou %d vez(es), todas bloqueadas, sem dano (%s)"
		% [resultados.size(), str(resultados.map(func(r): return R.keys()[r]))])
