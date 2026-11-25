extends SceneTree
## Captura da Kira Kira remasterizada: trilha e arremesso do Z, pedras do X e pedra gigante do C.
## Weston isolado (docs/MODO_HISTORIA.md):
##   WAYLAND_DISPLAY=<socket> godot --display-driver wayland --rendering-driver vulkan --path . --script tools/dev_tests/captura_kira_z_x.gd -- <pasta>
var saida := "/tmp/kira_z_x"
var jogador
var cam: Camera3D

class Alvo extends CharacterBody3D:
	var health := 1000.0
	func _ready() -> void:
		add_to_group(AlvosDeGolpe.GRUPO)
		collision_layer = 1
		var hb := Node3D.new()
		hb.name = "Hurtbox"
		add_child(hb)
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		cs.shape = cap
		hb.add_child(cs)
		var m := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.4
		cm.height = 1.8
		m.mesh = cm
		add_child(m)
	func take_damage(valor: float, _o: Vector3, imp: Vector3, _s: float) -> void:
		health -= valor
		velocity = imp
	func _physics_process(delta: float) -> void:
		velocity.y -= 20.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
		move_and_slide()

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()

func q(n: int) -> void:
	for i in n:
		if is_instance_valid(jogador): jogador.capacidades.can_use_fruit = true
		await physics_frame

func foto(nome: String, lado := 7.0, alt := 2.5, recuo := 3.0, olhar_a := 6.0) -> void:
	var frente: Vector3 = _frente()
	var d := frente.cross(Vector3.UP).normalized()
	var base: Vector3 = jogador.global_position
	cam.global_position = base + d * lado + Vector3.UP * alt - frente * recuo
	cam.look_at(base + frente * olhar_a + Vector3.UP * 0.8)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])
	print("CAPTURA ", saida, "/", nome)

var _f := Vector3.FORWARD
func _frente() -> Vector3: return _f

func rodar_ate(c, cond: Callable, max_q := 240) -> void:
	for i in max_q:
		await q(1)
		if cond.call(): return

func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_kira_zx.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_kira_zx.json"))
	root.get_node("GameFlow").start_story()
	await q(200)
	jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var prog = current_scene.get("progressao")
	prog.fruta = "kira_kira"
	prog.fruta_ativa = true
	prog.skills["fruta"] = 1
	prog.item_ativo = prog.NENHUM_ITEM
	modo.equipar_fruta(jogador, "kira_kira")
	await q(20)
	var c = jogador.get_node("FrutaMinePiece")
	jogador.max_energy = 3000.0
	jogador.energy = 3000.0
	cam = Camera3D.new()
	cam.fov = 60.0
	root.add_child(cam)
	cam.current = true
	var f: Vector3 = c.olhar()
	f.y = 0.0
	_f = f.normalized()
	var inicio: Vector3 = jogador.global_position
	var a1 := Alvo.new()
	current_scene.add_child(a1)
	a1.global_position = inicio + _f * 12.0
	var a2 := Alvo.new()
	current_scene.add_child(a2)
	a2.global_position = inicio + _f * 12.0 + _f.cross(Vector3.UP).normalized() * 2.5
	await q(5)
	await foto("00_antes", 9.0, 3.0, 2.0, 7.0)
	# Z
	c.usar_tecla("Z", true)
	c.usar_tecla("Z", false)
	await q(14)
	await foto("01_z_trilha", 6.0, 2.0, -1.0, 3.0)
	await rodar_ate(c, func(): return not c.kira_investida.ativo, 120)
	await q(4)
	await foto("02_z_impacto", 8.0, 2.5, -6.0, 3.0)
	await q(14)
	await foto("03_z_arremesso", 12.0, 3.5, -8.0, 8.0)
	await q(40)
	print("Z alvo1 em ", a1.global_position.distance_to(inicio + _f * 12.0), " m do ponto original")
	# X
	c._recargas.clear()
	jogador.energy = 3000.0
	a1.global_position = jogador.global_position + _f * 16.0
	a2.global_position = jogador.global_position + _f * 16.0 + _f.cross(Vector3.UP).normalized() * 6.0
	a1.velocity = Vector3.ZERO
	await q(10)
	c.usar_tecla("X", true)
	c.usar_tecla("X", false)
	await q(18)
	await foto("04_x_pedras", 5.0, 2.0, 1.5, 6.0)
	await q(14)
	await foto("05_x_voo", 6.0, 2.2, -2.0, 9.0)
	await q(20)
	await foto("06_x_impacto", 7.0, 2.5, -8.0, 7.0)
	await q(80)
	# C
	c._recargas.clear()
	jogador.energy = 3000.0
	a1.global_position = jogador.global_position + _f * 22.0
	a1.velocity = Vector3.ZERO
	await q(10)
	c.usar_tecla("C", true)
	c.usar_tecla("C", false)
	await q(28)
	await foto("07_c_subindo", 6.0, 2.5, 0.0, 6.0)
	await q(40)
	await foto("08_c_voo", 8.0, 3.0, -3.0, 12.0)
	await rodar_ate(c, func(): return get_nodes_in_group("kira_pedra").is_empty(), 180)
	await foto("09_c_impacto", 12.0, 3.5, -10.0, 12.0)
	await q(8)
	await foto("10_c_depois", 12.0, 3.5, -10.0, 12.0)
	quit()
