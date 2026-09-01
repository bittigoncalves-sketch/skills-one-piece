extends SceneTree
## Regressão da Fase 1 de docs/PLANO_COMBATE_CONTEXTUAL.md.
## Cobre resolução W/A/S/D, prioridade básica, root motion, pose, VFX, dano
## autoritativo em singleplayer e limpeza de estado ao fim da recuperação.

var _falhas := 0
var _teclas := {}
var _player: Node3D
var _alvo: Node3D
var _altura_base := 0.0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(2.2)
	_player = get_first_node_in_group("player")
	_alvo = get_first_node_in_group("dummy")
	if _player == null or _alvo == null:
		print("❌ Contextual: jogador ou dummy ausente")
		quit(1)
		return
	_altura_base = _player.global_position.y
	_player._yaw = 0.0

	print("\n===== ATAQUES CONTEXTUAIS =====")
	_resolvedor_puro()
	await _integracao("W", KEY_W, "context_elbow", Vector3(0, 0, -1), true)
	await _integracao("S", KEY_S, "context_retreat_kick", Vector3(0, 0, 1), false)
	await _integracao("A", KEY_A, "context_side_hook_l", Vector3(-1, 0, 0), false)
	await _integracao("D", KEY_D, "context_side_hook_r", Vector3(1, 0, 0), false)
	_aplicar([])
	print("===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)

func _ok(condicao: bool, texto: String) -> void:
	print(("  ✅ " if condicao else "  ❌ ") + texto)
	if not condicao:
		_falhas += 1

func _contexto(f: float = 0.0, r: float = 0.0, no_chao: bool = true, correndo: bool = false, arma: String = "") -> Dictionary:
	return {
		"grounded": no_chao,
		"sprinting": correndo,
		"weapon": arma,
		"input_forward": f,
		"input_side": r,
		"attack_yaw": 0.0,
	}

func _resolvedor_puro() -> void:
	print("\n-- resolvedor e prioridade --")
	_ok(ContextualMelee.resolver(_contexto(1.0)) == "context_elbow", "W resolve cotovelada")
	_ok(ContextualMelee.resolver(_contexto(-1.0)) == "context_retreat_kick", "S resolve chute recuando")
	_ok(ContextualMelee.resolver(_contexto(0.0, -1.0)) == "context_side_hook_l", "A resolve esquiva esquerda + gancho")
	_ok(ContextualMelee.resolver(_contexto(0.0, 1.0)) == "context_side_hook_r", "D resolve esquiva direita + gancho")
	_ok(ContextualMelee.resolver(_contexto(1.0, -1.0)) == "context_side_hook_l", "lateral vence W/S em entrada diagonal")
	# ⚠️ A REGRA MUDOU EM 2026-08-31 (Fase 4 do plano): no ar agora existe UMA
	# variação, o chute aéreo. O que esta asserção sempre quis dizer continua
	# valendo — nenhuma das quatro de SOLO pode sair no ar —, e é isso que ela
	# passa a verificar, em vez de exigir vazio.
	const SO_NO_CHAO := ["context_elbow", "context_retreat_kick",
		"context_side_hook_l", "context_side_hook_r", "context_launcher"]
	for entrada in [[1.0, 0.0], [-1.0, 0.0], [0.0, -1.0], [0.0, 1.0]]:
		var no_ar := ContextualMelee.resolver(_contexto(entrada[0], entrada[1], false))
		_ok(not (no_ar in SO_NO_CHAO),
			"no ar não entra variação de solo (entrada %s deu '%s')" % [str(entrada), no_ar])
	_ok(ContextualMelee.resolver(_contexto(0.0, 0.0, false)) == "context_air_kick",
		"no ar o clique resolve o chute aéreo")
	_ok(ContextualMelee.resolver(_contexto(1.0, 0.0, true, true)) == "", "sprint preserva rota Mink/futura")
	_ok(ContextualMelee.resolver(_contexto(1.0, 0.0, true, false, "sword")) == "", "arma preserva combo próprio")

func _integracao(nome: String, tecla: Key, id: String, rumo: Vector3, deve_danificar: bool) -> void:
	print("\n-- %s + M1 --" % nome)
	await _preparar()
	# O alvo fica no alcance do W. Nas demais entradas ele só garante que a
	# presença de outro corpo não impede a leitura da direção nem da pose.
	_alvo.global_position = Vector3(0, _altura_base, -2.15)
	var vida_antes := float(_alvo.get("health"))
	var pos_antes := _player.global_position
	_aplicar([tecla])
	_player._request_melee()
	await _esperar_inicio_contextual(id)
	var id_aceito := String(_player._melee.contextual_id())
	var ficha := ContextualMelee.especificacao(id)
	var pose_esperada := str(ficha.get("pose", ""))
	var pose_correta := String(_player.get_meta("custom_pose", "")) == pose_esperada
	var vfx := _player.get_node_or_null("ContextualMeleeFX_" + id)
	_ok(id_aceito == id, "%s escolhe o ID esperado" % nome)
	_ok(_player._melee.fase() == "startup" or _player._melee.fase() == "ativo", "%s entra no frame data contextual" % nome)
	_ok(pose_correta and vfx != null, "%s cria pose e VFX presos ao jogador" % nome)
	if nome == "W":
		# A visão pode mudar já no startup; a ação precisa manter a base aceita,
		# não perseguir a mira como se fosse um projétil guiado.
		_player._yaw = PI * 0.5
	# A raiz física percorre o rumo declarado, não a mira que possa mudar depois.
	await _esperar(0.13)
	var deslocamento := _player.global_position - pos_antes
	var moveu_no_rumo := Vector2(deslocamento.x, deslocamento.z).dot(Vector2(rumo.x, rumo.z)) > 0.10
	_ok(moveu_no_rumo, "%s aplica root motion no rumo contextual" % nome)
	if nome == "W":
		var modelo: Node3D = _player.get("_char_model")
		var fixou_base := absf(float(_player.get("_contextual_attack_yaw"))) < 0.01 \
			and modelo != null and absf(wrapf(modelo.rotation.y, -PI, PI)) < 0.18
		_ok(fixou_base, "W mantém direção e corpo congelados apesar da mira mudar")
	if deve_danificar:
		await _esperar(0.20)
		_ok(float(_alvo.get("health")) < vida_antes, "W cria hitbox autoritativa e causa dano")
	else:
		await _esperar(0.20)
	_aplicar([])
	await _esperar(0.42)
	_ok(not _player._melee.contextual_ativo() and String(_player.get_meta("custom_pose", "")).begins_with("context_") == false,
		"%s limpa relógio e pose ao terminar" % nome)

func _preparar() -> void:
	_aplicar([])
	_player._melee.cancelar_golpe()
	# ⚠️ ZERAR A SEQUÊNCIA DO COMBO, e não só o golpe em voo. Desde 2026-09-01 a
	# variação contextual OCUPA o passo 0 e deixa a janela aberta — é o que faz
	# segurar W dar cotovelada→soco→soco→lançamento em vez de quatro cotoveladas.
	# `cancelar_golpe` preserva a sequência de propósito (o dash-cancel é o
	# cancelamento legítimo, e o jogador pode retomar o combo), então cada caso
	# deste teste tem de pedir explicitamente um começo do zero — senão o
	# segundo caso em diante herda o combo do anterior e a variação nem é
	# oferecida.
	_player._melee._passo = 0
	_player._melee._janela = 0.0
	_player._server_contextual_next_ms = 0
	_player._input_buffer.clear()
	_player._yaw = 0.0
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(0, _altura_base, 0)
	if _player._fsm:
		_player._fsm.transition_to("Idle")
	var espera := 0
	while not _player.is_on_floor() and espera < 120:
		await _quadros(1)
		espera += 1
	await _quadros(3)

func _esperar_inicio_contextual(id: String) -> void:
	# A FSM consome o buffer no próximo tick físico. Quando um impacto anterior
	# aplicou hit-stop visual, dois `process_frame` não representam uma janela
	# estável; esperar pelo estado evita um falso negativo temporal do teste.
	for _i in 12:
		if String(_player._melee.contextual_id()) == id:
			return
		await _quadros(1)

func _aplicar(teclas: Array) -> void:
	for k in _teclas.keys():
		if not teclas.has(k):
			_evento_tecla(int(k), false)
	for k in teclas:
		if not _teclas.has(k):
			_evento_tecla(int(k), true)
	_teclas.clear()
	for k in teclas:
		_teclas[k] = true

func _evento_tecla(tecla: int, pressionada: bool) -> void:
	var evento := InputEventKey.new()
	evento.keycode = tecla
	evento.physical_keycode = tecla
	evento.pressed = pressionada
	Input.parse_input_event(evento)

func _quadros(qtd: int) -> void:
	for _i in qtd:
		await process_frame

func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
