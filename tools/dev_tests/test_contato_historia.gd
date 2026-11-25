extends SceneTree
# ============================================================================
#  TESTE DE CONTATO DO COMBATE DIRECIONAL — dois corpos de verdade.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md, Fase 3. O jogador real do Modo História
#  contra um `BonecoDeDuelo` (mesmo rig, mesmo executor). Prova:
#    A. alcance: longe não acerta (controle), perto acerta UMA vez, no ATIVO;
#    B. o lado da reação sai da geometria, nas 4 direções e pelas costas, girando o
#       par em volta do mundo;
#    C. golpe interrompido no preparo não machuca (controle: o mesmo golpe inteiro
#       machuca, provado em A);
#    D. o tempo do jogo nunca muda (hitstop é por ator);
#    E. o boneco ataca o jogador SEM input nenhum — o mesmo executor servindo IA;
#    F. acerto no ATIVO não interrompe o golpe do JOGADOR (§7.1) — até 21/09 o
#       atordoamento do `take_damage` cancelava o golpe dele e não o do boneco;
#    G. golpe atrás de golpe, a pose não muda a ESCALA dos ossos — até 21/09 os pés do
#       boneco "Ataca" cresciam sem parar (0,61 × 1,67 depois de 13 golpes).
#
#  ⚠️ `BonecoDeDuelo` é carregado por `load` e citado só por instância: citar a
#  classe cruzaria com o Player na compilação do script (armadilha do test_modo_historia).
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_contato_historia.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_contato_historia_progresso.json"
const D := GolpeDirecional.Direcao
const L := ResolucaoDeContato.Lado
const PERTO := 1.1

var _falhas := 0
var _escala_de_tempo_mudou := false
var _posicoes_invalidas := 0


func _init() -> void:
	await process_frame
	print("\n===== CONTATO DO COMBATE DIRECIONAL =====")
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
	var boneco: Node = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	boneco.name = "BonecoDeDuelo"
	boneco.vida_maxima = 100000.0
	# ⚠️ LONGE do jogador ao nascer: sobreposto na origem, a física punha o jogador EM
	# CIMA da caixa do boneco e ele passava a ser carregado a cada teletransporte
	# (rastreado em 16/09 no roteiro de captura). `_posicionar` agora exige chão.
	boneco.position = Vector3(0, 0.8, -4.0)
	current_scene.add_child(boneco)
	await _quadros(10)

	await _alcance(jogador, boneco)
	await _lados(jogador, boneco)
	await _interrompido(jogador, boneco)
	await _boneco_ataca(jogador, boneco)
	await _troca_no_ativo(jogador, boneco)
	await _escala_dos_ossos(boneco)
	_ok(not _escala_de_tempo_mudou, "Engine.time_scale ficou em 1,0 o teste inteiro (hitstop é por ator)")
	_ok(_posicoes_invalidas == 0, "pré-condição: em todo posicionamento os dois corpos estavam no chão, lado a lado (%d inválido(s))" % _posicoes_invalidas)

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


## Quando a seção pede vida alta (`_folga_de_vida`), o teto é reposto a cada quadro: o Modo História reaplica o teto real (~24) depois do ajuste.
var _folga_de_vida := 0.0

func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
		if _folga_de_vida > 0.0:
			var j := get_first_node_in_group("player")
			if j != null and float(j.health) > 0.0 and float(j.max_health) < _folga_de_vida:
				j.max_health = _folga_de_vida
				j.health = _folga_de_vida
		if not is_equal_approx(Engine.time_scale, 1.0):
			_escala_de_tempo_mudou = true


## Põe o jogador na origem olhando para `yaw`, e o boneco a `distancia` à frente,
## olhando de volta (ou de costas, se `de_costas`).
func _posicionar(jogador: Node, boneco: Node, yaw: float, distancia: float, de_costas := false) -> void:
	var executor: ExecutorCorpoACorpo = jogador.combate_direcional
	for i in 120:
		if not executor.ocupado() and not boneco.combate_direcional.ocupado():
			break
		await _quadros(1)
	var frente := -Basis.from_euler(Vector3(0, yaw, 0)).z
	jogador.velocity = Vector3.ZERO
	jogador.global_position = Vector3(0, jogador.global_position.y, 0)
	jogador._yaw = yaw
	jogador.modelo_visual().rotation.y = yaw
	# ⚠️ Jogador PRIMEIRO, e dois quadros de física antes do boneco. No mesmo quadro,
	# o boneco colidia com o jogador ainda na posição antiga (o avanço do golpe
	# anterior o deixa 0,25 m à frente) e era despenetrado 0,15 m — medido em 16/09.
	await _quadros(2)
	boneco.parar()
	boneco.global_position = jogador.global_position + frente * distancia
	var yaw_boneco := yaw if de_costas else yaw + PI
	boneco.encarar_yaw(yaw_boneco)
	boneco.modelo_visual().rotation.y = yaw_boneco
	await _quadros(8)
	var plano := Vector2(boneco.global_position.x - jogador.global_position.x, boneco.global_position.z - jogador.global_position.z).length()
	if absf(jogador.global_position.y - boneco.global_position.y) > 0.05 or absf(plano - distancia) > 0.05:
		_posicoes_invalidas += 1
		print("     ⚠️ posição inválida: jogador %s, boneco %s" % [jogador.global_position, boneco.global_position])


## Um golpe do jogador; devolve os contatos que ele produziu.
func _golpe(jogador: Node, direcao: int) -> Array:
	var executor: ExecutorCorpoACorpo = jogador.combate_direcional
	var contatos: Array = []
	var ao_contato := func(id, alvo, resultado, lado, _pos, golpe):
		contatos.append({"id": id, "alvo": alvo, "lado": lado, "estado": executor.estado,
			"golpe": golpe, "t": executor.tempo_da_acao(), "hitstop_ok": executor.em_hitstop()})
	executor.contato.connect(ao_contato)
	_ok(executor.pedir_ataque(direcao), "(preparação) o jogador começou %s" % D.keys()[direcao])
	for i in 150:
		await _quadros(1)
		if not executor.atacando():
			break
	executor.contato.disconnect(ao_contato)
	return contatos


# ---------------------------------------------------------------------- A
func _alcance(jogador: Node, boneco: Node) -> void:
	print("\n-- A. alcance e janela --")
	await _posicionar(jogador, boneco, 0.0, 4.0)
	var vida := float(boneco.health)
	var longe := await _golpe(jogador, D.FRENTE)
	_ok(longe.is_empty() and is_equal_approx(boneco.health, vida), "controle: a 4 m o jab não acerta nada")

	await _posicionar(jogador, boneco, 0.0, PERTO)
	vida = float(boneco.health)
	var reacoes: Array = []
	var ao_reagir := func(lado, _pesado): reacoes.append(lado)
	boneco.combate_direcional.reagiu.connect(ao_reagir)
	var perto := await _golpe(jogador, D.FRENTE)
	boneco.combate_direcional.reagiu.disconnect(ao_reagir)
	_ok(perto.size() == 1, "a %.1f m o jab acerta UMA vez (contatos: %d)" % [PERTO, perto.size()])
	if perto.size() >= 1:
		var c: Dictionary = perto[0]
		var g: GolpeDirecional = c["golpe"]
		_ok(c["estado"] == ExecutorCorpoACorpo.Estado.ATIVO and c["t"] >= g.preparo and c["t"] <= g.preparo + g.ativo + 0.02,
			"o contato aconteceu no ATIVO (t=%.3f s; ativo %.2f–%.2f)" % [c["t"], g.preparo, g.preparo + g.ativo])
		# Soco do jogador da história × 0,5 (23/10/2026, `Balance.HISTORIA_SOCO`).
		_ok(is_equal_approx(vida - boneco.health, g.dano * Balance.HISTORIA_SOCO + float(jogador.get_meta("bonus_fisico_historia", 0.0))),
			"tirou o dano da ficha × 0,5 + Força (%.0f de %.0f)" % [vida - boneco.health, g.dano])
		_ok(c["hitstop_ok"], "o atacante entrou em hitstop no contato")
	_ok(reacoes.size() == 1, "o boneco entrou em reação exatamente uma vez (%d)" % reacoes.size())


# ---------------------------------------------------------------------- B
func _lados(jogador: Node, boneco: Node) -> void:
	print("\n-- B. o lado da reação, em 4 orientações do mundo --")
	var casos := [
		[D.FRENTE, L.FRENTE, false],
		[D.PARA_ESQUERDA, L.ESQUERDA, false],
		[D.PARA_DIREITA, L.DIREITA, false],
		[D.DE_CIMA, L.FRENTE, false],
		[D.FRENTE, L.COSTAS, true],
	]
	var erros := PackedStringArray()
	var total := 0
	for yaw_i in 4:
		var yaw := TAU * yaw_i / 4.0 + 0.3
		for c in casos:
			await _posicionar(jogador, boneco, yaw, PERTO, c[2])
			var reacoes: Array = []
			var ao_reagir := func(lado, _pesado): reacoes.append(lado)
			boneco.combate_direcional.reagiu.connect(ao_reagir)
			var contatos := await _golpe(jogador, c[0])
			boneco.combate_direcional.reagiu.disconnect(ao_reagir)
			total += 1
			var lado_obtido: int = contatos[0]["lado"] if contatos.size() == 1 else -1
			var ok: bool = contatos.size() == 1 and lado_obtido == c[1] and reacoes.size() == 1 and reacoes[0] == c[1]
			if not ok:
				erros.append("yaw %.0f° %s%s → esperado %s, contatos %d, lado %s, reações %s" % [rad_to_deg(yaw),
					D.keys()[c[0]], " (de costas)" if c[2] else "", L.keys()[c[1]], contatos.size(),
					L.keys()[lado_obtido] if lado_obtido >= 0 else "-", str(reacoes)])
	for e in erros:
		print("     ❌ " + e)
	_ok(erros.is_empty(), "%d golpes (4 direções + costas × 4 orientações): %d fora do lado esperado" % [total, erros.size()])


# ---------------------------------------------------------------------- C
func _interrompido(jogador: Node, boneco: Node) -> void:
	print("\n-- C. golpe interrompido no preparo não machuca --")
	await _posicionar(jogador, boneco, 0.0, PERTO)
	await _quadros(60)
	var vida := float(boneco.health)
	var executor: ExecutorCorpoACorpo = jogador.combate_direcional
	executor.pedir_ataque(D.FRENTE)
	await _quadros(3)
	jogador.take_damage(0.5, jogador.global_position + Vector3.FORWARD, Vector3.ZERO, 0.6)
	await _quadros(60)
	_ok(is_equal_approx(boneco.health, vida), "jogador atordoado no preparo: o boneco não perdeu vida (%.1f → %.1f)" % [vida, boneco.health])
	jogador.health = jogador.max_health
	await _quadros(40)


# ---------------------------------------------------------------------- E
func _boneco_ataca(jogador: Node, boneco: Node) -> void:
	print("\n-- E. o boneco ataca pelo MESMO executor, sem input --")
	await _posicionar(jogador, boneco, 0.0, PERTO)
	await _quadros(60)
	# Vida alta de propósito: com a vida do Civil (20) um golpe pode matar, e o
	# renascimento enche a vida no mesmo quadro — a conta daria zero (visto em 16/09).
	jogador.max_health = 1000.0
	jogador.health = 1000.0
	_folga_de_vida = 1000.0
	var vida := float(jogador.health)
	var reacoes: Array = []
	var ao_reagir := func(lado, _pesado): reacoes.append(lado)
	jogador.combate_direcional.reagiu.connect(ao_reagir)
	var executor_boneco: ExecutorCorpoACorpo = boneco.combate_direcional
	# A vida é lida NO contato: a regeneração (0,5%/s do máximo) já devolveria uns
	# décimos até o fim do golpe — medido em 16/09 (2,8 em vez de 3,0).
	var vida_no_contato := [vida]
	var ao_contato := func(_id, _alvo, _res, _lado, _pos, _golpe): vida_no_contato[0] = float(jogador.health)
	executor_boneco.contato.connect(ao_contato)
	_ok(executor_boneco.pedir_ataque(D.PARA_ESQUERDA), "o boneco começou um gancho (pedido direto, sem entrada)")
	for i in 120:
		await _quadros(1)
		# O Modo História reaplica o teto de vida real (≈24) logo depois do ajuste acima: mantém a folga durante o golpe.
		if jogador.health > 0.0 and jogador.max_health < 1000.0 or vida_no_contato[0] == vida:
			jogador.max_health = 1000.0
			jogador.health = 1000.0
		if not executor_boneco.atacando():
			break
	jogador.combate_direcional.reagiu.disconnect(ao_reagir)
	executor_boneco.contato.disconnect(ao_contato)
	var golpe := executor_boneco.estilo.golpe_para(D.PARA_ESQUERDA)
	var esperado := golpe.dano * executor_boneco.multiplicador_de_dano
	# O dano que chega ao jogador passa pelo pipeline do mod (armadura, LivingDamageEvent e `ESCALA_DO_GOLPE_DE_MOB` ×10, 10/11/2026), então a
	# conta crua da ficha (`esperado`) deixou de ser exata: aqui vale "perdeu vida e não menos que a ficha reduzida pela armadura". O valor
	# fino do pipeline é medido em `test_jogador_mod`.
	var perdeu: float = vida - float(vida_no_contato[0])
	_ok(perdeu >= esperado * 0.5 and perdeu <= esperado * 6.0,
		"o jogador perdeu vida pelo golpe do boneco (%.1f; ficha × escala = %.1f, pipeline do mod escala)" % [perdeu, esperado])
	_ok(reacoes == [L.ESQUERDA], "o jogador reagiu pela ESQUERDA (%s)" % str(reacoes.map(func(x): return L.keys()[x])))
	jogador.health = jogador.max_health


# ---------------------------------------------------------------------- F
## Acerto no ATIVO não interrompe (§7.1) — e vale para o JOGADOR, não só para o boneco.
## O `take_damage` do Player atordoa em todo dano; até 21/09 esse atordoamento
## cancelava o golpe dele no quadro seguinte ("impedido"), e o do boneco seguia.
func _troca_no_ativo(jogador: Node, boneco: Node) -> void:
	print("\n-- F. acerto no ATIVO não interrompe o golpe do jogador --")
	jogador.max_health = 1000.0
	jogador.health = 1000.0
	_folga_de_vida = 1000.0
	await _quadros(60)      # o empurrão do golpe da seção E ainda deslocava o jogador ~0,2 m: espera assentar
	var ej: ExecutorCorpoACorpo = jogador.combate_direcional
	var eb: ExecutorCorpoACorpo = boneco.combate_direcional

	# 1. O boneco bate nas COSTAS do jogador enquanto o jab dele corta o ar: o
	# acerto chega no ATIVO do jogador sem o jogador ter conectado antes.
	await _posicionar(jogador, boneco, 0.0, PERTO)
	jogador._yaw = PI
	jogador.modelo_visual().rotation.y = PI
	await _quadros(2)
	var estado_no_acerto := [-1]
	var fim_jogador := [&""]
	var ao_contato := func(_id, alvo, _res, _lado, _pos, _golpe):
		if alvo == jogador:
			estado_no_acerto[0] = ej.estado
	var ao_fim := func(_id, motivo): fim_jogador[0] = motivo
	eb.contato.connect(ao_contato)
	ej.golpe_encerrado.connect(ao_fim)
	ej.pedir_ataque(D.FRENTE)
	eb.pedir_ataque(D.FRENTE)
	for i in 90:
		await _quadros(1)
		if not ej.atacando() and not eb.atacando():
			break
	eb.contato.disconnect(ao_contato)
	ej.golpe_encerrado.disconnect(ao_fim)
	_ok(estado_no_acerto[0] == ExecutorCorpoACorpo.Estado.ATIVO,
		"(pré-condição) o golpe do boneco chegou com o jogador no ATIVO (%s)" \
			% (ExecutorCorpoACorpo.Estado.keys()[estado_no_acerto[0]] if estado_no_acerto[0] >= 0 else "sem contato"))
	_ok(fim_jogador[0] == &"fim",
		"o golpe do jogador foi até o fim apesar do acerto (encerrado por '%s')" % fim_jogador[0])

	# 2. Troca de frente: os dois jabs no mesmo quadro conectam e os dois seguem.
	# Decisão do dono (15/11/2026): o jogador tem ARMADURA NO PREPARO — a sequência de socos não é cortada por quem bate junto ou pelas
	# costas. (a) com a regra do jogo, o jab do jogador vai até o fim mesmo apanhando no preparo; (b) com o boneco
	# também protegido, os dois vão até o fim. Quem CONECTA depende do empurrão (o acerto afasta o alvo antes do ATIVO do outro): não se afirma.
	for boneco_protegido in [false, true]:
		await _quadros(60)      # o empurrão do acerto anterior ainda deslocava o jogador: espera assentar antes de posicionar
		await _posicionar(jogador, boneco, 0.0, PERTO)
		eb.armadura_no_preparo = boneco_protegido
		var conectou := {}
		var motivos := {}
		var cj := func(_id, _a, _r, _l, _p, _g): conectou["jogador"] = true
		var cb := func(_id, _a, _r, _l, _p, _g): conectou["boneco"] = true
		var fj := func(_id, m): motivos["jogador"] = m
		var fb := func(_id, m): motivos["boneco"] = m
		ej.contato.connect(cj)
		eb.contato.connect(cb)
		ej.golpe_encerrado.connect(fj)
		eb.golpe_encerrado.connect(fb)
		ej.pedir_ataque(D.FRENTE)
		eb.pedir_ataque(D.FRENTE)
		for i in 90:
			await _quadros(1)
			if not ej.atacando() and not eb.atacando():
				break
		ej.contato.disconnect(cj)
		eb.contato.disconnect(cb)
		ej.golpe_encerrado.disconnect(fj)
		eb.golpe_encerrado.disconnect(fb)
		eb.armadura_no_preparo = false
		var rotulo := "boneco também protegido" if boneco_protegido else "regra do jogo"
		_ok(motivos.get("jogador") == &"fim",
			"troca de frente (%s): o jab do jogador NÃO é cortado, vai até o fim (contatos %s, '%s')" % [rotulo, str(conectou.keys()), motivos.get("jogador")])
		if boneco_protegido:
			_ok(motivos.get("boneco") == &"fim",
				"troca de frente (%s): o jab do boneco também NÃO é cortado (contatos %s, '%s')" % [rotulo, str(conectou.keys()), motivos.get("boneco")])
	jogador.health = jogador.max_health


# ---------------------------------------------------------------------- G
## Os ossos que o `AplicadorDePose` escreve (pernas pela IK, pé pela orientação, braços
## pela IK de dois ossos), dos dois lados.
const OSSOS_ESCRITOS := ["Thigh_L", "Thigh_R", "Shin_L", "Shin_R", "Foot_L", "Foot_R", "Ball_L", "Ball_R",
	"UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Hand_L", "Hand_R"]


## Golpe atrás de golpe, a escala LOCAL de cada osso escrito fica em 1. Escrever
## `global_basis` com a escala lida do global transformava o cisalhamento deixado pela IK
## em escala do pé, e o animador (que só escreve `rotation`) a guardava: somava a cada
## quadro. Medido em 21/09: pé (1,00; 0,61; 1,67) depois de 13 golpes do boneco "Ataca".
func _escala_dos_ossos(boneco: Node) -> void:
	print("\n-- G. golpe atrás de golpe, a escala dos ossos não muda --")
	boneco.parar()
	boneco.global_position = Vector3(0, boneco.global_position.y, -6.0)   # longe: golpeia o ar
	await _quadros(5)
	var executor: ExecutorCorpoACorpo = boneco.combate_direcional
	var modelo: Node3D = boneco.modelo_visual()
	var direcoes := [D.FRENTE, D.PARA_ESQUERDA, D.DE_CIMA, D.PARA_DIREITA]
	var golpes := 0
	for i in 720:   # 12 s: cerca de 12 golpes, as quatro direções
		await _quadros(1)
		if not executor.ocupado():
			if executor.pedir_ataque(direcoes[golpes % direcoes.size()]):
				golpes += 1
	var pior := 0.0
	var qual := "nenhum"
	for nome in OSSOS_ESCRITOS:
		var n := modelo.find_child(nome, true, false) as Node3D
		if n == null:
			continue
		var desvio := (n.scale - Vector3.ONE).abs()
		var maior := maxf(desvio.x, maxf(desvio.y, desvio.z))
		if maior > pior:
			pior = maior
			qual = "%s %s" % [nome, n.scale]
	_ok(golpes >= 8, "(pré-condição) o boneco deu %d golpes seguidos" % golpes)
	_ok(pior < 0.002, "a escala local dos %d ossos escritos continua 1 (pior desvio %.4f: %s)" \
		% [OSSOS_ESCRITOS.size(), pior, qual])
