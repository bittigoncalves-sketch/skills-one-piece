extends SceneTree
## ============================================================================
##  O GOLPE PRENDE O CORPO? — NÃO deve prender, e isso é medido em METROS.
##
##  ⚠️ A REGRA MUDOU EM 2026-08-31, E A MUDANÇA É DO DONO.
##
##  O pedido original (2026-08-15) era: "ao clicar não vai ser possível se mover
##  até que a animação do combate se encerre". Ele foi REVOGADO com estas
##  palavras: "a remoção da trava de M1 foi proposital; apesar de ela fazer
##  sentido, travava o jogador demais, fazendo os movimentos não serem tão
##  fluidos".
##
##  Este arquivo continua existindo, e não virou lixo: o que ele guarda agora é
##  a regra NOVA — que o M1 deixa o corpo livre — e o item 4, que nunca mudou:
##  clicar no ar não pode congelar a queda.
##
##  A EXCEÇÃO (a mordida Mink, que ainda prende porque controla a própria
##  velocidade enquanto segura o alvo) é guardada pelo `test_mink_combate`, que
##  afere o `_mink_hold_timer` diretamente. Não se duplica aqui.
##
##  "Não vai ser possível se mover" vira número aqui: a DISTÂNCIA que o jogador
##  percorre segurando W durante o golpe. Zero é o alvo, e o controle é a mesma
##  corrida sem golpe nenhum — sem ele, um teste que mede "andou pouco" não
##  distingue trava funcionando de tecla que não chegou.
##
##  QUATRO PERGUNTAS:
##    1. ANDA?     o M1 NÃO pode prender: a distância durante o golpe tem de
##                 acompanhar o controle (a mesma corrida sem golpe nenhum).
##    2. PULA?     o Espaço durante o golpe TIRA os pés do chão — faz parte da
##                 fluidez que o dono pediu.
##    3. DESTRAVA? passada a animação, a corrida volta ao normal.
##    4. CAI?      clicar NO AR não pode congelar a queda (o defeito do
##                 `lock_movement`, que é a trava dos casts e zera a gravidade).
##
##  ⚠️ PRECISA DE JANELA. O `MoveFrame.ler()` ignora o teclado inteiro sem
##  `MOUSE_MODE_CAPTURED` — headless mede o vazio e passa por engano.
##      DISPLAY=:0 godot --path . --script tools/dev_tests/test_melee_trava.gd
## ============================================================================

var _teclas := {}
var _player: Node = null

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(3.0)

	_player = _local()
	if _player == null:
		print("❌ não achei o jogador — a porta 24565 pode estar ocupada")
		quit(1)
		return
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("### o mouse não capturou — rode COM janela (DISPLAY=:0)")
		quit(1)
		return

	_afastar_bonecos()

	print("")
	print("╔══════════════════════════════════════════════════════════════════╗")
	print("║  CORPO A CORPO — O M1 DEIXA O CORPO LIVRE?                       ║")
	print("╚══════════════════════════════════════════════════════════════════╝")

	var trava := Melee.recuo(0, "")
	var quadros := int(trava * 60.0)
	print("  golpe 1 '%s': animação %.2fs = trava %.2fs (%d quadros)" % [
		Melee.passo(0, "")["nome"], Melee.duracao_tocada(0, ""), trava, quadros])

	var falhas := 0

	# ---------------------------------------------------- 1) CONTROLE: só correr
	await _plantar()
	_aplicar([KEY_W])
	var p0: Vector3 = _player.global_position
	await _quadros(quadros)
	var corrida: float = _plano(_player.global_position - p0)
	_aplicar([])
	print("\n  CONTROLE — segurando W, sem golpe:  andou %.2f m" % corrida)
	if corrida < 1.0:
		print("  ### o controle não andou: a tecla não chegou. Medição inválida.")
		quit(1)
		return

	# ------------------------------------------------- 2) GOLPE: correr e clicar
	await _plantar()
	_aplicar([KEY_W])
	await _quadros(12)                     # já em velocidade de corrida
	_player._melee.pedir(_player._yaw)     # CAMINHO DE VERDADE (o mesmo do clique)
	var p1: Vector3 = _player.global_position
	var y_max: float = _player.global_position.y
	await _quadros(quadros)
	var travado: float = _plano(_player.global_position - p1)
	_aplicar([])
	print("  GOLPE    — segurando W, clicando:    andou %.2f m" % travado)
	# ⚠️ COMPARADO AO CONTROLE, não a um número fixo. O alvo agora é "anda
	# praticamente como quem não está socando": metade da corrida livre já
	# separa "não prende" de "prende um pouco", e não engessa a velocidade.
	var anda_ok: bool = travado > corrida * 0.5
	_dizer(anda_ok, "o M1 NÃO prende o corpo (%.2f m contra %.2f m do controle)" % [
		travado, corrida])
	falhas += 0 if anda_ok else 1

	# ------------------------------------------------------ 3) O ESPAÇO NÃO SALVA
	await _plantar()
	_player._melee.pedir(_player._yaw)
	await _quadros(4)
	_aplicar([KEY_W, KEY_SPACE])
	var chao_y: float = _player.global_position.y
	var subiu := 0.0
	for i in maxi(quadros - 8, 1):
		await _quadros(1)
		subiu = maxf(subiu, _player.global_position.y - chao_y)
	_aplicar([])
	var pulo_ok: bool = subiu > 0.20
	print("")
	_dizer(pulo_ok, "o Espaço TIRA os pés do chão durante o golpe (subiu %.2f m)" % subiu)
	falhas += 0 if pulo_ok else 1

	# ----------------------------------------------------------- 4) E DESTRAVA?
	await _esperar(1.2)                    # deixa a trava expirar por inteiro
	await _plantar()
	_aplicar([KEY_W])
	var p2: Vector3 = _player.global_position
	await _quadros(quadros)
	var depois: float = _plano(_player.global_position - p2)
	_aplicar([])
	var destrava_ok: bool = depois > corrida * 0.7
	_dizer(destrava_ok, "passada a animação a corrida volta (%.2f m contra %.2f m)" % [depois, corrida])
	falhas += 0 if destrava_ok else 1

	# ------------------------------------------------- 5) NO AR O CORPO CAI
	# É a diferença entre esta trava e o `lock_movement` dos casts: aquele zera a
	# velocidade INTEIRA e o jogador boiaria parado no ar durante todo o golpe.
	_player.global_position = Vector3(0, 8, 0)
	_player.velocity = Vector3.ZERO
	await _quadros(6)
	_player._melee.pedir(_player._yaw)
	var alto: float = _player.global_position.y
	await _quadros(20)
	var caiu: float = alto - _player.global_position.y
	var cai_ok: bool = caiu > 0.5
	print("")
	_dizer(cai_ok, "clicando NO AR o corpo continua caindo (caiu %.2f m em 20 quadros)" % caiu)
	falhas += 0 if cai_ok else 1

	print("")
	if falhas == 0:
		print("✅ O M1 NÃO PRENDE — o corpo anda e pula durante o golpe (2026-08-31).")
	else:
		print("❌ %d verificação(ões) falharam." % falhas)
	quit(1 if falhas > 0 else 0)

# ---------------------------------------------------------------------- apoio
# Põe o jogador no chão, parado e sem golpe pendente. Esperar o CHÃO (e não um
# número fixo de quadros) é a lição do `medir_gura_rush.gd`: com espera fixa a
# medida mudava entre rodadas do mesmo código.
func _plantar() -> void:
	_aplicar([])
	_afastar_bonecos()
	_player.global_position = Vector3(0, 1.2, 0)
	_player.velocity = Vector3.ZERO
	_player._melee._trava = 0.0
	_player._melee._passo = 0
	_player._fsm.transition_to("Idle")
	var espera := 0
	while not _player.is_on_floor() and espera < 240:
		await _quadros(1)
		espera += 1
	await _quadros(10)

# Tira TODO boneco/inimigo do caminho antes de medir.
#
# ⚠️ NÃO É PARANOIA: o `AutoDummy` persegue e ATACA o jogador sozinho. Um golpe
# dele no meio da corrida de controle aplica hitstun (`combat_state = STUNNED`),
# a corrida morre e a sonda aborta por "medição inválida" — acusando o jogo por
# algo que é o cenário de teste. Aconteceu de verdade: a suíte só passou a
# sofrer disso quando o `AutoDummy` voltou a compilar e, portanto, a existir.
# É a mesma limpeza que o `test_arena` faz antes de medir dano.
func _afastar_bonecos() -> void:
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		if e is Node3D:
			e.set_meta("is_frozen", true)
			e.set_meta("damage_immune", true)
			(e as Node3D).global_position = Vector3(0, -1000, 0)

func _plano(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

func _dizer(ok: bool, texto: String) -> void:
	print("      %s %s" % ["✔" if ok else "✗", texto])

func _local() -> Node:
	for x in get_root().get_tree().get_nodes_in_group("player"):
		if x.is_multiplayer_authority():
			return x
	return null

func _aplicar(teclas: Array) -> void:
	for k in _teclas.keys():
		if not teclas.has(k): _tecla(k, false)
	for k in teclas:
		if not _teclas.has(k): _tecla(k, true)
	_teclas.clear()
	for k in teclas: _teclas[k] = true

func _tecla(code: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = apertada
	Input.parse_input_event(ev)

func _quadros(n: int) -> void:
	for i in n:
		Engine.time_scale = 1.0
		# ⚠️ REAFIRMA AS TECLAS TODO QUADRO, pelo mesmo motivo do `time_scale`.
		#
		# Rodando na bateria (`validar.sh`) sobem várias instâncias do Godot em
		# série e a janela NUNCA ganha foco. Ao perder foco o Godot solta todas as
		# teclas pressionadas, e o W injetado no início sumia: o controle caía de
		# 6,2 m para 0,6 m e a sonda abortava por medição inválida — corretamente,
		# mas por causa do ambiente, não do jogo.
		#
		# Reafirmar é idempotente para o `MoveFrame`, que lê `is_key_pressed`. E a
		# borda do Espaço continua certa: `espaco_agora` é derivada do quadro
		# anterior DENTRO do `MoveFrame`, então segurar não vira martelada.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await physics_frame

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
