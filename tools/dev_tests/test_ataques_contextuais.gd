extends SceneTree
## Regressão do clique contextual (docs/PLANO_COMBATE_CONTEXTUAL.md).
## ⚠️ 2026-09-13: as variações de movimento simples (W cotovelada, S chute
## recuando, A/D esquiva com gancho) foram apagadas a pedido do dono. Este teste
## passa a garantir o contrário: andar + clique no chão sai o combo M1, sem pose
## nem VFX contextual, e ainda causa dano.

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
	await _integracao("W", KEY_W, Vector3(0, 0, -2.15))
	await _integracao("S", KEY_S, Vector3(0, 0, -2.15))
	await _integracao("A", KEY_A, Vector3(0, 0, -2.15))
	await _integracao("D", KEY_D, Vector3(0, 0, -2.15))
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
	for entrada in [[1.0, 0.0], [-1.0, 0.0], [0.0, -1.0], [0.0, 1.0], [1.0, -1.0]]:
		_ok(ContextualMelee.resolver(_contexto(entrada[0], entrada[1])) == "",
			"andar %s + clique no chão é combo M1" % str(entrada))
	# ⚠️ A REGRA MUDOU EM 2026-08-31 (Fase 4 do plano): no ar agora existe UMA
	# variação, o chute aéreo. O que esta asserção sempre quis dizer continua
	# valendo — nenhuma das quatro de SOLO pode sair no ar —, e é isso que ela
	# passa a verificar, em vez de exigir vazio.
	const SO_NO_CHAO := ["context_launcher"]
	for entrada in [[1.0, 0.0], [-1.0, 0.0], [0.0, -1.0], [0.0, 1.0]]:
		var no_ar := ContextualMelee.resolver(_contexto(entrada[0], entrada[1], false))
		_ok(not (no_ar in SO_NO_CHAO),
			"no ar não entra variação de solo (entrada %s deu '%s')" % [str(entrada), no_ar])
	_ok(ContextualMelee.resolver(_contexto(0.0, 0.0, false)) == "context_air_kick",
		"no ar o clique resolve o chute aéreo")
	_ok(ContextualMelee.resolver(_contexto(1.0, 0.0, true, true)) == "", "sprint preserva rota Mink/futura")
	_ok(ContextualMelee.resolver(_contexto(1.0, 0.0, true, false, "sword")) == "", "arma preserva combo próprio")

func _integracao(nome: String, tecla: Key, alvo_em: Vector3) -> void:
	print("\n-- %s + M1 --" % nome)
	await _preparar()
	# O acerto do caso anterior deixa o boneco deslizando: sem zerar a velocidade,
	# ele sai do alcance e o caso seguinte erra por herança, não pelo golpe.
	_alvo.global_position = Vector3(0, _altura_base, 0) + alvo_em
	if "velocity" in _alvo:
		_alvo.velocity = Vector3.ZERO
	await _esperar(0.9)
	_alvo.global_position = Vector3(0, _altura_base, 0) + alvo_em
	var vida_antes := float(_alvo.get("health"))
	_aplicar([tecla])
	_player._request_melee()
	for _i in 12:
		if _player._melee.passo_em_curso() >= 0 or not String(_player._melee.contextual_id()).is_empty():
			break
		await _quadros(1)
	# Solta a tecla assim que o golpe sai: o que se mede é QUAL golpe saiu, não a
	# caminhada levando o jogador para fora do alcance durante o startup.
	_aplicar([])
	_ok(String(_player._melee.contextual_id()).is_empty(), "%s + clique não escolhe variação contextual" % nome)
	_ok(_player._melee.passo_em_curso() == 0, "%s + clique sai o 1º golpe do combo M1" % nome)
	_ok(not String(_player.get_meta("custom_pose", "")).begins_with("context_"), "%s + clique sem pose contextual" % nome)
	await _esperar(0.45)
	_ok(float(_alvo.get("health")) < vida_antes, "%s + clique acerta o alvo à frente com o M1" % nome)

func _preparar() -> void:
	_aplicar([])
	_player._melee.cancelar_golpe()
	# ⚠️ ZERAR A SEQUÊNCIA DO COMBO, e não só o golpe em voo: `cancelar_golpe`
	# preserva a sequência de propósito (dash-cancel), e cada caso deste teste
	# precisa começar do primeiro golpe.
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
