extends SceneTree
## Captura com render dos quatro golpes da Nikyu Nikyu.
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
func _foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/nikyu/%s.png" % nome)
func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://capturar_nikyu.json")
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
	var mesh := MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	alvo.add_child(mesh)
	current_scene.add_child(alvo)
	alvo.add_to_group("enemy")
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	for tecla in ["Z", "X", "C", "V"]:
		await _limpar()
		alvo.position = Vector3(0, 1, -16)
		cam.global_position = Vector3(5.5, 2.6, 5.5)
		cam.look_at(Vector3(0, 1.5, -4))
		await _cast(tecla)
		var momentos: Array = {"Z": [30, 22], "X": [30, 14], "C": [30, 18], "V": [28, 8]}[tecla]
		await frames(momentos[0])
		await _foto(tecla + "_a")
		await frames(momentos[1])
		await _foto(tecla + "_b")
	quit()
