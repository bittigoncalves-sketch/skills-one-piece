extends SceneTree
class Fighter extends CharacterBody3D:
	var health := 2048.0
	var combat_mode := "sword"
	var _char_model: Node3D
	var _yoru: YoruSword
	var _yoru_combat: YoruController
	func lamina_da_espada() -> SwordBlade: return _yoru.lamina
class Target extends StaticBody3D:
	var damage := 0.0
	var hits := 0
	func take_damage(value: float, _origin: Vector3, _kb: Vector3, _stun: float) -> void:
		damage += value
		hits += 1
var world: Node3D
var player: Fighter
var target: Target
var checks := 0
var failures := 0
var seq := 0
func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print(("PASS " if condition else "FAIL ")+label)
func box(body: CollisionObject3D, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var resource := BoxShape3D.new()
	resource.size = size
	shape.shape = resource
	body.add_child(shape)
func _init() -> void:
	await process_frame
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	player = Fighter.new()
	world.add_child(player)
	player.position.y = 0.8
	box(player,Vector3(0.4,1.6,0.4))
	player._char_model = CharacterBuilder.build_character("base").node
	player.add_child(player._char_model)
	var bounds := PlayerModelKit.model_aabb(player._char_model)
	var factor := 1.5/bounds.size.y
	player._char_model.scale = Vector3.ONE*factor
	player._char_model.position.y = -0.8-factor*bounds.position.y
	var handle: Node3D = player._char_model.find_child("Weapon_R",true,false)
	handle.rotation.x = PI
	player._yoru = YoruSword.ligar_na_mao(handle)
	player._yoru.lamina.dono = player
	player._yoru_combat = YoruController.new()
	player.add_child(player._yoru_combat)
	player._yoru_combat.setup(player)
	player._yoru_combat.set_physics_process(false)
	var floor_body := StaticBody3D.new()
	world.add_child(floor_body)
	floor_body.position.y = -0.1
	box(floor_body,Vector3(30,0.2,30))
	target = Target.new()
	world.add_child(target)
	box(target,Vector3(0.5,1.6,0.5))
	await physics_frame
	await physics_frame
	for id in ["M1_1","M1_2","X"]:
		player.position = Vector3(0,0.82,0)
		target.position = Vector3(0,0.8,-(4.1 if id == "X" else 1.4))
		target.damage = 0
		target.hits = 0
		await physics_frame
		await run_action(id)
		ok(is_equal_approx(target.damage,float(YoruMoves.get_move(id).damage)),id+" dano único na lâmina: "+str(target.damage))
		ok(target.hits == 1,id+" um contato por alvo")
		ok(not player._yoru.lamina.esta_armada(),id+" desarma na recuperação")
	player.position = Vector3(0,0.82,0)
	target.position = Vector3(0,0.8,-1.4)
	target.damage = 0
	seq += 1
	player._yoru_combat.start_action("M1_1",seq,Vector3.FORWARD)
	player._yoru_combat._physics_process(0.1)
	player._yoru_combat.cancel("damage")
	for i in 50:
		player._yoru_combat._physics_process(1.0/60)
		await physics_frame
	ok(target.damage == 0 and not player._yoru.lamina.esta_armada(),"cancelar startup não rearma golpe antigo")
	player._yoru_combat.start_action("M1_1",seq,Vector3.FORWARD)
	ok(player._yoru_combat.action_id == "","sequência repetida não reinicia ação")
	seq += 1
	player._yoru_combat.start_action("C",seq,Vector3.FORWARD)
	player._yoru_combat._physics_process(0.12)
	ok(player._yoru_combat.is_parrying(player.position+Vector3.FORWARD),"C apara pela frente")
	ok(not player._yoru_combat.is_parrying(player.position+Vector3.BACK),"C deixa costas vulneráveis")
	player._yoru_combat.on_parry(target,target.position)
	ok(player._yoru_combat.next_m1() == "M1_2" and player._yoru_combat.can_start("M1_2"),"aparo abre resposta somente ao novo M1")
	player._yoru_combat.cancel("mode")
	player._yoru_combat._physics_process(0.5)
	ok(player._yoru_combat.cooldown("C") > 0,"cancelar conserva recarga")
	target.position = Vector3(0,0.8,-3)
	target.damage = 0
	target.hits = 0
	var wave := spawn_wave("Z")
	await wait_wave(wave)
	ok(target.damage == 110 and target.hits == 1,"Z onda aplica um único acerto")
	var wall := StaticBody3D.new()
	world.add_child(wall)
	wall.position = Vector3(0,1,-1.5)
	box(wall,Vector3(3,2,0.2))
	target.damage = 0
	await physics_frame
	wave = spawn_wave("Z")
	await wait_wave(wave)
	ok(target.damage == 0,"Z termina na parede")
	wall.queue_free()
	await physics_frame
	target.damage = 0
	wave = spawn_wave("V")
	await wait_wave(wave)
	ok(target.damage == 180,"V percorre solo e atinge alvo")
	floor_body.queue_free()
	# Duas plataformas separadas por buraco de 1m.
	for z in [0.0,-5.0]:
		var platform := StaticBody3D.new()
		world.add_child(platform)
		platform.position = Vector3(0,-0.1,z)
		box(platform,Vector3(8,0.2,4))
	target.position.z = -4
	target.damage = 0
	await physics_frame
	wave = spawn_wave("V")
	await wait_wave(wave)
	ok(target.damage == 0,"V termina na interrupção do solo")
	wave = spawn_wave("Z")
	await wait_wave(wave)
	ok(target.damage == 110,"Z cruza buraco sem depender de piso")
	print("YORU COMBAT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func run_action(id: String) -> void:
	seq += 1
	player._yoru_combat.start_action(id,seq,Vector3.FORWARD)
	var frames := int(ceil(YoruMoves.duration(id)*60))+2
	for i in frames:
		player._yoru_combat._physics_process(1.0/60)
		await physics_frame
func spawn_wave(id: String) -> YoruWave:
	var wave := YoruWave.new()
	world.add_child(wave)
	wave.position = Vector3(0,0.8,-0.5)
	wave.setup(player,id,Vector3.FORWARD,YoruMoves.get_move(id))
	return wave
func wait_wave(wave: YoruWave) -> void:
	for i in 150:
		await physics_frame
		if not is_instance_valid(wave): return
