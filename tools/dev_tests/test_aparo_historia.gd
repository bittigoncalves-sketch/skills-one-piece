extends SceneTree
# ============================================================================
#  TESTE DE APARO, RIPOSTE E FINTA — dois corpos de verdade.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md, Fase 5. O jogador real do Modo História e
#  um `BonecoDeDuelo`:
#    A. guarda apertada na hora certa APARA: sem dano, sem postura, atacante rebatido;
#       a mesma guarda apertada cedo só BLOQUEIA (controle);
#    B. riposte depois do aparo acerta quem não se defende, e sai mais cedo que o
#       mesmo golpe sem riposte;
#    C. riposte NÃO é garantido: o rebatido que aperta a guarda logo segura (§7.5);
#    D. a finta desarma o aparo: o boneco apara o overhand, mas não a finta para gancho;
#    E. o cérebro "apara e riposta" pune um jab do jogador sozinho;
#    e o tempo do jogo nunca muda.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_aparo_historia.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_aparo_historia_progresso.json"
const D := GolpeDirecional.Direcao
const R := ResolucaoDeContato.Resultado
const PERTO := 1.1

var _falhas := 0
var _escala_de_tempo_mudou := false
var _posicoes_invalidas := 0


func _init() -> void:
	await process_frame
	print("\n===== APARO, RIPOSTE E FINTA =====")
	var mh: GDScript = load("res://src/historia/ModoHistoria.gd")
	mh.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	mh.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame

	var jogador := _jogador_local()
	jogador.capacidades = CapacidadesDoJogador.completas()
	jogador.max_health = 1000.0
	jogador.health = 1000.0
	var boneco: Node = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	boneco.name = "BonecoDeDuelo"
	boneco.vida_maxima = 100000.0
	boneco.position = Vector3(0, 0.8, -4.0)
	current_scene.add_child(boneco)
	await _quadros(10)

	await _aparo_na_hora(jogador, boneco)
	await _riposte(jogador, boneco)
	await _riposte_nao_garantido(jogador, boneco)
	await _finta_desarma_aparo(jogador, boneco)
	await _cerebro_apara(jogador, boneco)
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


func _ex(corpo: Node) -> ExecutorCorpoACorpo:
	return corpo.combate_direcional


## Jogador na origem olhando −Z; boneco à frente olhando para ele (yaw PI = +Z).
func _posicionar(jogador: Node, boneco: Node) -> void:
	_ex(jogador).baixar_guarda()
	_ex(boneco).baixar_guarda()
	for i in 240:
		if _ex(jogador).estado == ExecutorCorpoACorpo.Estado.NEUTRO and _ex(boneco).estado == ExecutorCorpoACorpo.Estado.NEUTRO:
			break
		await _quadros(1)
	await _quadros(45)   # janelas de riposte e aparo antigas vencem
	_ex(jogador).postura = _ex(jogador).estilo.postura_maxima
	_ex(boneco).postura = _ex(boneco).estilo.postura_maxima
	jogador.velocity = Vector3.ZERO
	jogador.global_position = Vector3(0, jogador.global_position.y, 0)
	jogador._yaw = 0.0
	jogador.modelo_visual().rotation.y = 0.0
	await _quadros(2)
	boneco.parar()
	boneco.global_position = Vector3(0, jogador.global_position.y, -PERTO)
	boneco.encarar_yaw(PI)
	boneco.modelo_visual().rotation.y = PI
	await _quadros(8)
	var plano := Vector2(boneco.global_position.x, boneco.global_position.z - jogador.global_position.z).length()
	if absf(jogador.global_position.y - boneco.global_position.y) > 0.05 or absf(plano - PERTO) > 0.05:
		_posicoes_invalidas += 1
		print("     ⚠️ posição inválida: jogador %s, boneco %s" % [jogador.global_position, boneco.global_position])


## Espera o relógio da ação de `e` passar de `t` (ou ela acabar).
func _ate_tempo(e: ExecutorCorpoACorpo, t: float) -> void:
	for i in 120:
		if not e.atacando() or e.tempo_da_acao() >= t:
			return
		await _quadros(1)


func _gravar(e: ExecutorCorpoACorpo) -> Array:
	var lista: Array = []
	e.contato.connect(func(_id, _alvo, resultado, _lado, _pos, golpe): lista.append({"resultado": resultado, "golpe": golpe, "t": e.tempo_da_acao()}))
	return lista


func _nomes(lista: Array) -> String:
	return str(lista.map(func(c): return R.keys()[c["resultado"]]))


# ---------------------------------------------------------------------- A
func _aparo_na_hora(jogador: Node, boneco: Node) -> void:
	print("\n-- A. aparo na hora × guarda cedo --")
	var j := _ex(jogador)
	var b := _ex(boneco)
	var jab := b.estilo.golpe_para(D.FRENTE)

	# Controle: guarda apertada cedo (a janela vence antes do soco) só bloqueia.
	await _posicionar(jogador, boneco)
	j.erguer_guarda()
	await _quadros(30)
	var cedo := _gravar(b)
	b.pedir_ataque(D.FRENTE)
	await _ate_tempo(b, 5.0)
	_ok(cedo.size() == 1 and cedo[0]["resultado"] == R.BLOQUEIO, "controle: guarda apertada 0,5 s antes só BLOQUEIA (%s)" % _nomes(cedo))

	# Varredura do "pronto quando" da Fase 5, contada a partir do CONTATO medido acima
	# (não do fim do preparo): só o aperto que cabe na janela da ficha apara.
	var t_contato: float = cedo[0]["t"] if not cedo.is_empty() else jab.preparo
	for caso in [[0.25, R.BLOQUEIO], [0.15, R.APARO], [0.05, R.APARO]]:
		await _posicionar(jogador, boneco)
		var lista := _gravar(b)
		b.pedir_ataque(D.FRENTE)
		await _ate_tempo(b, t_contato - caso[0])
		var t_aperto := b.tempo_da_acao()
		j.erguer_guarda()
		for i in 60:
			await _quadros(1)
			if not lista.is_empty():
				break
		await _ate_tempo(b, 5.0)
		var antes: float = lista[0]["t"] - t_aperto if not lista.is_empty() else -1.0
		_ok(lista.size() == 1 and lista[0]["resultado"] == caso[1],
			"RMB %.2f s antes do contato (medido %.3f s; janela %.2f s) → %s (%s)"
			% [caso[0], antes, j.estilo.janela_de_aparo, R.keys()[caso[1]], _nomes(lista)])

	await _posicionar(jogador, boneco)
	var vida := float(jogador.health)
	var postura := j.postura
	var na_hora := _gravar(b)
	var rebotes := [0]
	b.rebatido.connect(func(): rebotes[0] += 1)
	b.pedir_ataque(D.FRENTE)
	await _ate_tempo(b, jab.preparo - 0.10)   # aperta 0,10 s antes do fim do preparo
	j.erguer_guarda()
	for i in 60:
		await _quadros(1)
		if not na_hora.is_empty():
			break
	_ok(na_hora.size() == 1 and na_hora[0]["resultado"] == R.APARO, "guarda apertada 0,10 s antes do soco APARA (%s)" % _nomes(na_hora))
	_ok(jogador.health >= vida - 0.001 and is_equal_approx(j.postura, postura), "aparo não custa vida nem postura (postura %.0f)" % j.postura)
	_ok(b.estado == ExecutorCorpoACorpo.Estado.REBATIDO and rebotes[0] == 1, "o boneco ficou REBATIDO (%s)" % ExecutorCorpoACorpo.Estado.keys()[b.estado])
	_ok(j.janela_de_riposte_aberta(), "a janela de riposte do jogador abriu")


# ---------------------------------------------------------------------- B
func _riposte(jogador: Node, boneco: Node) -> void:
	print("\n-- B. riposte acerta e sai mais cedo --")
	var j := _ex(jogador)
	var b := _ex(boneco)
	var jab := j.estilo.golpe_para(D.FRENTE)

	var tempo_normal := j.estilo.golpe_para(D.FRENTE).preparo   # o preparo do jab sem riposte

	await _posicionar(jogador, boneco)
	b.pedir_ataque(D.FRENTE)
	await _ate_tempo(b, jab.preparo - 0.10)
	j.erguer_guarda()
	for i in 60:
		await _quadros(1)
		if j.janela_de_riposte_aberta():
			break
	var vida_boneco := float(boneco.health)
	var ripostes := _gravar(j)
	_ok(j.pedir_ataque(D.FRENTE) and j.golpe_e_riposte(), "o jab logo depois do aparo sai como RIPOSTE")
	var quadros_ate_ativo := 0
	for i in 60:
		await _quadros(1)
		quadros_ate_ativo += 1
		if j.estado != ExecutorCorpoACorpo.Estado.PREPARO:
			break
	await _ate_tempo(j, 5.0)
	var segundos := quadros_ate_ativo / 60.0
	_ok(segundos <= tempo_normal * j.estilo.fator_de_riposte + 0.07 and segundos < tempo_normal,
		"o preparo do riposte levou %.3f s contra %.2f s do jab normal" % [segundos, tempo_normal])
	_ok(ripostes.size() == 1 and ripostes[0]["resultado"] == R.ACERTO and boneco.health < vida_boneco,
		"o riposte ACERTA o boneco rebatido que não se defende (%s)" % _nomes(ripostes))


# ---------------------------------------------------------------------- C
func _riposte_nao_garantido(jogador: Node, boneco: Node) -> void:
	print("\n-- C. riposte não é dano garantido --")
	var j := _ex(jogador)
	var b := _ex(boneco)
	var jab := b.estilo.golpe_para(D.FRENTE)
	await _posicionar(jogador, boneco)
	b.pedir_ataque(D.FRENTE)
	await _ate_tempo(b, jab.preparo - 0.10)
	j.erguer_guarda()
	for i in 60:
		await _quadros(1)
		if b.estado == ExecutorCorpoACorpo.Estado.REBATIDO:
			break
	# O rebatido aperta a guarda no mesmo instante em que foi aparado; o jogador responde
	# com riposte no mesmo quadro.
	b.erguer_guarda()
	var vida_boneco := float(boneco.health)
	var ripostes := _gravar(j)
	j.pedir_ataque(D.FRENTE)
	await _ate_tempo(j, 5.0)
	_ok(ripostes.size() == 1 and ripostes[0]["resultado"] != R.ACERTO and boneco.health >= vida_boneco - 0.001,
		"com a guarda apertada logo, o boneco segura o riposte (%s)" % _nomes(ripostes))


# ---------------------------------------------------------------------- D
func _finta_desarma_aparo(jogador: Node, boneco: Node) -> void:
	print("\n-- D. a finta desarma o aparo --")
	var j := _ex(jogador)
	var b := _ex(boneco)
	var over := j.estilo.golpe_para(D.DE_CIMA)
	# O boneco aperta a guarda para o contato do overhand (0,15 s antes do fim do preparo).
	var aperto := over.preparo - 0.15

	await _posicionar(jogador, boneco)
	var sem_finta := _gravar(j)
	j.pedir_ataque(D.DE_CIMA)
	await _ate_tempo(j, aperto)
	b.erguer_guarda()
	await _ate_tempo(j, 5.0)
	_ok(sem_finta.size() == 1 and sem_finta[0]["resultado"] == R.APARO,
		"controle: sem finta, o boneco apara o overhand (%s)" % _nomes(sem_finta))

	await _posicionar(jogador, boneco)
	var com_finta := _gravar(j)
	j.pedir_ataque(D.DE_CIMA)
	await _ate_tempo(j, over.preparo * j.estilo.janela_de_finta - 0.02)
	_ok(j.pedir_ataque(D.PARA_ESQUERDA), "(preparação) finta do overhand para o gancho")
	await _ate_tempo(j, aperto - over.preparo * j.estilo.janela_de_finta)
	b.erguer_guarda()
	await _ate_tempo(j, 5.0)
	_ok(com_finta.size() == 1 and com_finta[0]["resultado"] != R.APARO,
		"com a finta, o aparo do boneco vence antes do gancho chegar (%s)" % _nomes(com_finta))


# ---------------------------------------------------------------------- E
func _cerebro_apara(jogador: Node, boneco: Node) -> void:
	print("\n-- E. o cérebro apara e riposta sozinho --")
	var j := _ex(jogador)
	await _posicionar(jogador, boneco)
	var cerebro := CerebroDeTreino.new()
	cerebro.modo = CerebroDeTreino.Modo.APARA_E_RIPOSTA
	var seq: Array[int] = [D.FRENTE]
	cerebro.sequencia = seq
	cerebro.montar(boneco, jogador)
	boneco.add_child(cerebro)
	await _quadros(5)
	var do_jogador := _gravar(j)
	var do_boneco := _gravar(_ex(boneco))
	var vida := float(jogador.health)
	j.pedir_ataque(D.FRENTE)
	await _quadros(90)
	cerebro.queue_free()
	_ok(do_jogador.size() == 1 and do_jogador[0]["resultado"] == R.APARO, "o jab do jogador foi APARADO pelo cérebro (%s)" % _nomes(do_jogador))
	_ok(do_boneco.size() >= 1 and do_boneco[0]["resultado"] == R.ACERTO and jogador.health < vida,
		"e o riposte do boneco ACERTOU o jogador (%s)" % _nomes(do_boneco))
