extends SceneTree
# ============================================================================
#  COUNTER HIT — Fase 2 de docs/PLANO_COMBATE_CONTEXTUAL.md
#
#  O plano: "acertar um inimigo em startup adiciona hitstun e knockback
#  moderados, sem subir o dano. Exige confirmar fase do alvo no servidor."
#
#  Três coisas precisam ser verdade, e cada uma quebra sozinha:
#    1. a REGRA — o bônus é hitstun e empurrão, e o dano NÃO sobe;
#    2. a LEITURA — `em_startup_de_ataque` responde certo no Player de verdade;
#    3. a ORDEM — a fase do alvo é lida ANTES de o dano interrompê-lo.
#
#  ⚠️ A ORDEM É O ITEM QUE FALHA EM SILÊNCIO. `hit_landed` dispara DEPOIS do
#  `take_damage`, e o `take_damage` interrompe o golpe do alvo: lida ali, a
#  pergunta "estava em startup?" responde SEMPRE falso, e o counter nunca
#  aconteceria — sem erro, sem aviso, só nunca acontecendo.
#
#    DISPLAY=:1 godot --path . -s tools/dev_tests/test_counter_hit.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	p.set_meta("damage_immune", true)

	_regra()
	await _leitura_da_fase(p)
	await _ordem_dos_sinais(p)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## 1. A REGRA. Um alvo de mentira registra o que recebe — assim o bônus é
## verificável sem física, sem rede e sem depender de acertar alguém.
func _regra() -> void:
	print("=== 1. a regra do counter ===")
	var alvo := AlvoDeMentira.new()
	get_root().add_child(alvo)
	var e: Dictionary = ContextualMelee.especificacao("context_elbow")

	ContextualMelee._aplicar_counter(alvo, alvo, e, Vector3(0, 0, -1), 1.0)
	await process_frame
	_ok("o counter chama take_damage uma vez", alvo.chamadas.size() == 1)
	if alvo.chamadas.is_empty():
		return
	var c: Dictionary = alvo.chamadas[0]
	print("   dano %.1f | hitstun %.2f (base %.2f) | knockback %.2f"
		% [c["dano"], c["hitstun"], float(e["hitstun"]), Vector3(c["kb"]).length()])
	# O plano é explícito: o counter NÃO sobe o dano.
	_ok("o counter NÃO causa dano (o prêmio é tempo, não estrago)",
		absf(float(c["dano"])) < 0.01)
	_ok("o hitstun do counter é MAIOR que o do golpe normal",
		float(c["hitstun"]) > float(e["hitstun"]) * 1.2)
	_ok("o counter empurra mais", Vector3(c["kb"]).length() > 1.0)
	_ok("o alvo fica marcado para quem apresenta", alvo.has_meta("counter_hit_em"))
	alvo.queue_free()


## 2. A LEITURA, no Player de verdade: `em_startup_de_ataque` só pode ser
## verdadeiro na janela entre o clique e a hitbox.
func _leitura_da_fase(p: Node3D) -> void:
	print("\n=== 2. a leitura da fase no Player ===")
	_ok("parado, NÃO está em startup", not p.em_startup_de_ataque())

	# ⚠️ PELO CAMINHO REAL. Chamar `iniciar_ataque_contextual` direto no Player
	# NÃO passa pelo `MeleeController`, e é ele quem guarda o relógio que a
	# `fase()` lê — a resposta vinha "false" com o golpe rodando. O caminho de
	# verdade é a tecla mais `_request_melee`, como no `test_ataques_contextuais`.
	_tecla(KEY_W, true)
	p._request_melee()
	var esperou := 0
	while not p._melee.contextual_ativo() and esperou < 60:
		await process_frame
		esperou += 1
	_ok("o ataque contextual começou", p._melee.contextual_ativo())
	await _esperar(0.05)          # dentro do startup (0,14 s)
	var dentro: bool = p.em_startup_de_ataque()
	print("   dentro do startup (dura 0,14 s): %s | fase=%s"
		% [str(dentro), p._melee.fase()])
	_ok("durante o startup, responde SIM", dentro)

	_tecla(KEY_W, false)
	await _esperar(0.25)          # já passou para o ativo
	var depois: bool = p.em_startup_de_ataque()
	print("   passado o startup: %s | fase=%s" % [str(depois), p._melee.fase()])
	_ok("passado o startup, responde NÃO", not depois)
	await _esperar(0.6)


## 3. A ORDEM. `antes_do_acerto` tem de chegar antes de `hit_landed` — é o que
## permite ler a fase do alvo antes de o dano interrompê-la.
func _ordem_dos_sinais(p: Node3D) -> void:
	print("\n=== 3. a ordem dos sinais da DamageZone ===")
	var alvo := AlvoDeMentira.new()
	get_root().add_child(alvo)

	var ordem: Array[String] = []
	var zona := DamageZone.new()
	get_root().add_child(zona)
	zona.antes_do_acerto.connect(func(_a): ordem.append("antes"))
	zona.hit_landed.connect(func(_a): ordem.append("depois"))
	zona.global_position = alvo.global_position
	zona.setup(10.0, 5.0, Vector3.ZERO, 0.3, p, 2.0, null, 0.3)
	await _esperar(0.35)

	print("   ordem observada: %s" % str(ordem))
	_ok("os dois sinais dispararam", ordem.size() >= 2)
	if ordem.size() >= 2:
		_ok("'antes_do_acerto' vem ANTES de 'hit_landed'",
			ordem[0] == "antes" and ordem[1] == "depois")
	alvo.queue_free()
	if is_instance_valid(zona):
		zona.queue_free()


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _tecla(c: Key, d: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = c
	e.keycode = c
	e.pressed = d
	Input.parse_input_event(e)


func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame


## Alvo que só ANOTA o que recebeu. É um CharacterBody3D para a `DamageZone`
## (uma Area3D) conseguir enxergá-lo.
class AlvoDeMentira extends CharacterBody3D:
	var chamadas: Array = []
	var startup := false

	## ⚠️ SEM FORMA, A Area3D NÃO O VÊ. A primeira versão deste alvo era um
	## `CharacterBody3D` pelado, e a `DamageZone` — que é uma Area3D — nunca
	## registrava contato: os dois sinais saíam vazios e o teste reprovava a
	## ordem deles sem nunca tê-la observado.
	func _init() -> void:
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(1.0, 1.8, 1.0)
		forma.shape = caixa
		add_child(forma)

	func take_damage(amount: float, origem: Vector3 = Vector3.ZERO,
			kb: Vector3 = Vector3.ZERO, hitstun: float = 0.3) -> void:
		chamadas.append({"dano": amount, "origem": origem, "kb": kb, "hitstun": hitstun})

	func em_startup_de_ataque() -> bool:
		return startup
