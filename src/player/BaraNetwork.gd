extends RefCounted
## Validação/custos e reconstrução tardia. RPCs ficam no caminho estável Player.
const BARA := preload("res://src/combat/BaraController.gd")

static func request(actor: Node3D, slot: String, token: int) -> void:
	if Time.get_ticks_msec() < int(actor.get_meta("bara_pending_until", 0)): return
	var target: Dictionary = actor.mira_do_cast()
	var reason := BARA.validation_reason(actor, slot, target.aim)
	if float(actor.energy) < float(actor.custo_de_energia_do_cast(slot)): reason = "Energia insuficiente."
	if reason != "":
		feedback(actor, reason)
		return
	actor.set_meta("bara_pending_until", Time.get_ticks_msec() + 1500)
	actor.pedir_cast_no_servidor(slot, target.aim, target.origem, 0.0, token)

static func feedback(actor: Node, reason: String) -> void:
	actor.set_meta("bara_pending_until", 0)
	actor.set_meta("bara_feedback", reason)
	actor.set_meta("bara_feedback_until", Time.get_ticks_msec() + 2200)

static func authorize(actor: Node3D, slot: String, aim: Vector3, origin: Vector3, token: int) -> bool:
	if actor.multiplayer.has_multiplayer_peer() and not actor.multiplayer.is_server(): return false
	var reason := BARA.validation_reason(actor, slot, aim)
	var key := "fruit/bara_bara/" + slot
	var now := Time.get_ticks_msec()
	if not origin.is_finite() or actor.global_position.distance_to(origin) > 4.5: reason = "Origem inválida."
	if token <= 0 or token <= int(actor.get_meta("bara_server_token", 0)): reason = "Pedido já processado."
	if now < int(actor._server_cast_next_ms.get(key, 0)) or float(actor._fruit_cooldowns.get(slot, 0)) > 0: reason = "Técnica em recarga."
	if float(actor.energy) < float(actor.custo_de_energia_do_cast(slot)): reason = "Energia insuficiente."
	if reason != "":
		if actor.multiplayer.has_multiplayer_peer() and not actor._is_authority:
			actor._net_bara_rejected.rpc_id(actor.get_multiplayer_authority(), reason)
		else: feedback(actor, reason)
		return false
	actor.set_meta("bara_server_token", token)
	actor._server_cast_next_ms[key] = now + int(SkillSystem.get_slot_cooldown(slot, "bara_bara") * 1000)
	actor.gastar_energia(actor.custo_de_energia_do_cast(slot))
	if actor._is_authority: actor.trigger_skill_cooldown(slot)
	return true

static func receive(actor: Node3D, data: Dictionary) -> void:
	var token := int(data.get("token", 0))
	if token <= int(actor.get_meta("bara_finished_token", 0)): return
	var action := BARA.action_for(actor)
	if action == null:
		if not BARA.DURATIONS.has(str(data.get("slot", ""))): return
		var parent: Node = actor._get_skills_container()
		if not parent.is_inside_tree(): return
		action = BARA.cast(parent, data.slot, data.aim, data.origin, actor, Balance.novo("bara_bara", data.slot, actor.escala_de_dano_da_fruta("bara_bara")), token)
	if action.cast_token == token: action.receive(data)

static func finish(actor: Node3D, token: int) -> void:
	actor.set_meta("bara_finished_token", maxi(token, int(actor.get_meta("bara_finished_token", 0))))
	var action := BARA.action_for(actor)
	if action != null and action.cast_token == token: action.finish()

static func cleanup(actor: Node) -> void:
	var binding = (actor.get_meta("bara_binding") if actor.has_meta("bara_binding") else null)
	if binding != null: binding.dispose()
	if actor.has_meta("bara_binding"): actor.remove_meta("bara_binding")
	if actor.has_meta("bara_binding_model"): actor.remove_meta("bara_binding_model")
