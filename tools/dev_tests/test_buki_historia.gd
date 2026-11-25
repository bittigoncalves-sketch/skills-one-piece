extends SceneTree
## Buki Buki DENTRO do Modo História (21/11/2026): equipa pela história, saca, atira e fere um inimigo da história; balas do V somem.
##   "$(./find_godot.sh)" --headless --path . --fixed-fps 60 --script tools/dev_tests/test_buki_historia.gd
var p
var passou := 0
var falhas := 0
func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, c: bool) -> void:
	print("%s %s" % ["OK" if c else "FALHA", nome])
	if c: passou += 1
	else: falhas += 1
func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_buki_hist.json"))
	modo.set("progresso_forcado", "user://test_buki_hist.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	var prog = current_scene.progressao
	prog.comer_fruta("buki_buki")
	await frames(30)
	ok("a Buki está equipada na história (id=%s)" % p.current_fruit_id, p.current_fruit_id == "buki_buki")
	p.energy = p.max_energy
	var b := BonecoDeDuelo.new()
	b.vida_maxima = 500.0
	b.position = Vector3(0, 1, -8)
	b.set_meta(EsquivaDeDisparo.META, 1 << 60)   # este teste mede o ACERTO: o boneco agora esquiva (22/11/2026), então fica sem esquiva aqui
	current_scene.add_child(b)
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	await frames(20)
	p.begin_charge("Z")
	await frames(30)
	ok("a pistola fica na mão (arma=%s, balas=%d)" % [p.buki_arma(), p.buki_municao()], p.buki_arma() == "Z" and p.buki_municao() == 12)
	for i in 6:
		p._buki.atirar()
		await frames(2)
		for n in current_scene.get_children():
			if n is DamageZone and i == 0:
				print("  zona em ", n.global_position, " vel ", n.vel, " dano ", n.damage, " jogador ", p.global_position)
		await frames(12)
	await frames(30)
	ok("a Buki feriu o inimigo da história (vida %.0f de 500)" % b.health, b.health < 500.0)
	# V: balas somem
	p.begin_charge("V")
	await frames(30)
	ok("minigun na mão (balas=%d)" % p.buki_municao(), p.buki_arma() == "V")
	for i in 30:
		p._buki.atirar()
		await frames(4)
	await frames(100)
	var vivas := 0
	for n in current_scene.get_children():
		if n is DamageZone: vivas += 1
	ok("depois da rajada as balas somem (zonas vivas: %d)" % vivas, vivas <= 2)
	# ---- poses por arma em camada sobre o andar/correr ----
	var m: Node3D = p.modelo_visual()
	var braco: Node3D = m.find_child("UpperArm_R", true, false)
	var coxa: Node3D = m.find_child("Foot_L", true, false)
	var nomes := []
	for n in m.find_children("*", "Node3D", true, false):
		if "_L" in n.name and ("Foot" in n.name or "Leg" in n.name or "Shin" in n.name or "Thigh" in n.name or "Ankle" in n.name): nomes.append(n.name)
	print("  nos da perna: ", nomes)
	var lido := {}
	for slot in ["Z", "C", "V"]:
		for k in p._skill_cooldowns.keys():
			p._skill_cooldowns[k] = 0.0          # o slot largado entra em recarga: o teste quer só ver a pose
		p.begin_charge(slot)
		p.release_charge(slot)
		await frames(40)
		lido[slot] = [p.buki_arma(), braco.rotation.x]
	print("  empunhaduras: ", lido)
	ok("cada arma tem a sua empunhadura (braço D: Z %.2f, C %.2f, V %.2f)" % [lido["Z"][1], lido["C"][1], lido["V"][1]],
		lido["Z"][0] == "Z" and lido["V"][0] == "V" and absf(lido["Z"][1] - lido["V"][1]) > 0.2 and absf(lido["C"][1] - lido["V"][1]) > 0.1)
	# anda de verdade (W) com a minigun na mão
	var tecla := func(k: Key, v: bool) -> void:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.keycode = k
		ev.pressed = v
		Input.parse_input_event(ev)
	var medir := func(correr: bool) -> Dictionary:
		if correr: tecla.call(KEY_SHIFT, true)
		tecla.call(KEY_W, true)
		for i in 40: await process_frame
		var r := {"zmin": 9.0, "zmax": -9.0, "bmin": 9.0, "bmax": -9.0, "v": 0.0}
		for i in 90:
			await process_frame
			var zl: float = p.to_local(coxa.global_position).z
			r["zmin"] = minf(r["zmin"], zl)
			r["zmax"] = maxf(r["zmax"], zl)
			r["bmin"] = minf(r["bmin"], braco.rotation.x)
			r["bmax"] = maxf(r["bmax"], braco.rotation.x)
			r["v"] = maxf(r["v"], Vector2(p.velocity.x, p.velocity.z).length())
		tecla.call(KEY_W, false)
		tecla.call(KEY_SHIFT, false)
		p.global_position = Vector3(0, 0.8, 0)
		p.velocity = Vector3.ZERO
		for i in 40: await process_frame
		return r
	var anda: Dictionary = await medir.call(false)
	print("  andando: ", anda)
	ok("andando com a minigun: o corpo anda (v %.1f m/s) — a pose é só dos braços; pernas/quadril são do sistema de marcha (não medidos aqui)" % anda["v"], anda["v"] > 1.0)
	ok("andando: o braço de arma fica na empunhadura (%.2f..%.2f; parado %.2f)" % [anda["bmin"], anda["bmax"], lido["V"][1]], absf((anda["bmax"] + anda["bmin"]) * 0.5 - lido["V"][1]) < 0.4)
	var corre: Dictionary = await medir.call(true)
	print("  correndo: ", corre)
	ok("correndo: a arma BAIXA em relação ao andar (%.2f vs %.2f)" % [(corre["bmax"] + corre["bmin"]) * 0.5, (anda["bmax"] + anda["bmin"]) * 0.5], (corre["bmax"] + corre["bmin"]) * 0.5 < (anda["bmax"] + anda["bmin"]) * 0.5 - 0.05)
	# ---- HUD da história: munição, luneta e marcador de acerto ----
	var hud = current_scene.get("_hud")
	ok("a HUD da história tem munição, luneta e marcador de acerto", hud.find_child("AmmoHud", true, false) != null and hud.find_child("SniperScope", true, false) != null and hud.find_child("MarcadorDeAcerto", true, false) != null)
	var marc = hud.find_child("MarcadorDeAcerto", true, false)
	marc.acionar(false)
	ok("o marcador acende ao acionar e apaga sozinho", marc.visible)
	await frames(30)
	ok("o marcador apagou depois de ~0,2 s", not marc.visible)
	print("\n%d ok, %d falha(s)" % [passou, falhas])
	quit(1 if falhas > 0 else 0)
