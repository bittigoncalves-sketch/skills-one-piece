extends SceneTree
## Nikyu Nikyu no Mi (feita no Skills Builder) no Modo História, pela entrada real da fruta.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_nikyu_nikyu.gd
var p: Node3D
var alvo: Node3D
var passou := 0
var falhas := 0
var _desenho_gigante := false
class Alvo extends StaticBody3D:
	var health := 5000.0
	var hits := 0
	var kb_max := 0.0
	func take_damage(d: float, _origem := Vector3.ZERO, kb := Vector3.ZERO, _stun := 0.0) -> void:
		health -= d
		hits += 1
		kb_max = maxf(kb_max, kb.length())
func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func _limpar() -> void:
	for e in current_scene.find_children("SkillBuilder_*", "", true, false): e.queue_free()
	await frames(3)
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p.health = p.max_health
	p._fruit_cooldowns.clear()
	p._skill_cooldowns.clear()
	p._server_cast_next_ms.clear()
	p._intervalo_golpe = 0.0
	p._trava_pos_fruta = 0.0
	p._fruit_damage_lock_timer = 0.0
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	alvo.position = Vector3(0, 1, -9)
	alvo.health = 5000.0
	alvo.hits = 0
	alvo.kb_max = 0.0
	await frames(5)
func _cast(tecla: String) -> void:
	p.begin_charge(tecla)
	await physics_frame
	p.release_charge(tecla)
func _zonas() -> Array:
	var r: Array = []
	for z in current_scene.find_children("*", "DamageZone", true, false):
		if z.is_projectile: r.append(z)
	return r
func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_nikyu.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	current_scene.progressao.comer_fruta("nikyu_nikyu")
	await frames(5)
	p.combat_mode = "fruit"
	alvo = Alvo.new()
	alvo.collision_layer = 1
	var col := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = .5
	forma.height = 1.8
	col.shape = forma
	alvo.add_child(col)
	current_scene.add_child(alvo)
	alvo.add_to_group("enemy")
	ok("a loja oferece a Nikyu Nikyu", PerfilDeFrutas.frutas_a_venda().has("nikyu_nikyu"))
	ok("a fruta tem as quatro teclas", KitDoBuilder.disponivel("nikyu_nikyu") and p.perfil_de_frutas.slots().size() >= 4)
	var escala := PerfilDeFrutas.ESCALA_DO_MOD

	# Z — pata gigante
	await _limpar()
	await _cast("Z")
	await frames(45)
	var gigante := false
	for z in _zonas():
		var cs: Array = z.find_children("*", "CollisionShape3D", true, false)
		var maior := 0.0
		for mi in z.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			maior = maxf(maior, maxf(b.size.x, b.size.z))
		if maior >= 2.9: _desenho_gigante = true
		for c in cs:
			if c.shape is SphereShape3D and (c.shape as SphereShape3D).radius >= 0.55: gigante = true
	await frames(90)
	ok("Z lança a pata gigante (acerto de 0,6 m; desenho de 3,2 m)", gigante and _desenho_gigante)
	ok("Z acerta uma vez, com o dano certo (%.2f)" % (5000.0 - alvo.health), alvo.hits == 1 and is_equal_approx(5000.0 - alvo.health, 170.0 * escala))

	# X — metralhadora de patas em volta do jogador
	await _limpar()
	await _cast("X")
	var maximo := 0
	var em_volta := false
	for i in 90:
		await physics_frame
		var zs := _zonas()
		maximo = maxi(maximo, zs.size())
		for z in zs:
			if z.global_position.distance_to(p.global_position) < 3.4 and absf(z.global_position.z - p.global_position.z) > 0.3 and i < 40:
				em_volta = true
	await frames(120)
	ok("X solta patas em rajadas (pico %d simultâneas)" % maximo, maximo >= 8)
	ok("X as patas nascem em volta do corpo", em_volta)
	ok("X acerta o alvo várias vezes (%d)" % alvo.hits, alvo.hits >= 3)

	# C — Dor: cura pelo dano
	await _limpar()
	p.health = p.max_health * 0.3
	var antes: float = p.health
	await _cast("C")
	await frames(120)
	var dano_c: float = 5000.0 - alvo.health
	ok("C acerta (dano %.2f)" % dano_c, alvo.hits == 1 and dano_c > 0.0)
	var esperado: float = minf(p.max_health, antes + dano_c * 0.7)
	ok("C cura 70%% do dano (%.2f -> %.2f, esperado %.2f)" % [antes, p.health, esperado], absf(p.health - esperado) < 0.6)
	await _limpar()
	p.health = p.max_health * 0.3
	antes = p.health
	alvo.position = Vector3(300, 1, 300)
	await _cast("C")
	await frames(120)
	ok("C errando não cura", absf(p.health - antes) < 0.6)

	# V — pata pequena, explosão e grande empurrão
	await _limpar()
	await _cast("V")
	await frames(60)
	var explode: bool = alvo.hits >= 1
	await frames(30)
	ok("V acerta com explosão (dano %.2f)" % (5000.0 - alvo.health), explode and alvo.hits == 1)
	ok("V dá um grande empurrão (%.1f)" % alvo.kb_max, alvo.kb_max >= 20.0)

	# Segurar a tecla: parado no lugar, sem gravidade (até no ar).
	await _limpar()
	p.global_position = Vector3(0, 6, 0)
	p.velocity = Vector3.ZERO
	await frames(2)
	p.begin_charge("Z")
	await frames(40)
	ok("segurando o Z no ar o jogador não cai (y=%.2f)" % p.global_position.y, absf(p.global_position.y - 6.0) < 0.3)
	p.release_charge("Z")
	await frames(40)
	ok("soltando a tecla a gravidade volta (y=%.2f)" % p.global_position.y, p.global_position.y < 5.0)

	print("\nNIKYU: %d passaram / %d falharam" % [passou, falhas])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
