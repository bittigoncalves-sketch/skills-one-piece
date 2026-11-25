extends SceneTree
## Integração: usa begin_charge/release_charge, perfil e Player reais.
var p: Node3D
var alvo: StaticBody3D
var passou := 0
var falhas := 0
class Alvo extends StaticBody3D:
	var health := 2000.0
	var hits := 0
	func take_damage(d: float, _origem:=Vector3.ZERO, _kb:=Vector3.ZERO, _stun:=0.0) -> void:
		health -= d
		hits += 1
func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n:
		Engine.time_scale = 1.0
		await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func preparar() -> void:
	p.limpar_skills_em_todos()
	await frames(3)
	p.global_position = Vector3(0,1,0)
	p.velocity = Vector3.ZERO
	p.health = p.max_health
	p.energy = p.max_energy
	p._fruit_cooldowns.clear()
	p._server_cast_next_ms.clear()
	p._intervalo_golpe = 0
	p._trava_pos_fruta = 0
	p._fruit_damage_lock_timer = 0
	p._yaw = 0
	p._pitch = 0
	p._update_pivot()
	alvo.position = Vector3(0,1,-8)
	alvo.health = 2000
	alvo.hits = 0
	await frames(5)
func cast(tecla: String) -> void:
	p.begin_charge(tecla)
	p.release_charge(tecla)
	await frames(3)
func _rodar() -> void:
	await process_frame
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_phoenix.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	if p == null:
		ok("jogador nasceu", false)
		quit(1)
		return
	current_scene.progressao.comer_fruta("tori_tori_phoenix")
	await frames(5)
	p.combat_mode = "fruit"
	alvo = Alvo.new()
	alvo.collision_layer = 2
	var col := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.55
	capsula.height = 2.0
	col.shape = capsula
	alvo.add_child(col)
	current_scene.add_child(alvo)
	alvo.add_to_group("enemy")
	ok("Phoenix na loja", PerfilDeFrutas.frutas_a_venda().has("tori_tori_phoenix"))
	ok("perfil Z X C V F", p.perfil_de_frutas.slots() == ["Z","X","C","V","F"])
	ok("perfil válido", p.perfil_de_frutas.problemas().is_empty())
	await preparar()
	await cast("F")
	ok("F exige transformação sem cobrar", p._phoenix.voo == 0 and is_equal_approx(p.energy,p.max_energy))
	await cast("Z")
	ok("Z transforma", p._phoenix.transformado and is_instance_valid(p._phoenix.forma))
	ok("corpo humano oculto", not p.modelo_visual().visible)
	ok("Z cobra energia e recarga", p.energy < p.max_energy and p._fruit_cooldowns.get("Z",0) > 0)
	await frames(65)
	await cast("F")
	ok("F liga voo", p._phoenix.voo > 0)
	var altura: float = p.position.y
	await frames(60)
	print("VOO altura=",altura," atual=",p.position," vel=",p.velocity," restante=",p._phoenix.voo)
	ok("voo decola e sustenta", p.position.y > altura+0.3 and p.velocity.y > -0.1)
	p.energy = 0
	await cast("F")
	ok("F desliga sem energia", p._phoenix.voo == 0)
	await frames(35)
	p.energy = 0
	await cast("Z")
	ok("Z reverte sem energia", not p._phoenix.transformado and p.modelo_visual().visible)
	for tecla in ["X","C","V"]:
		await preparar()
		if tecla == "V":
			alvo.position.z = -3
			p.health = p.max_health*0.5
		var inicio: Vector3 = p.global_position
		await cast(tecla)
		ok(tecla+" consome energia", p.energy < p.max_energy)
		ok(tecla+" arma recarga", p._fruit_cooldowns.get(tecla,0) > 0)
		await frames(100)
		var esperado: float = Balance.novo("tori_tori_phoenix",tecla,PerfilDeFrutas.ESCALA_DA_ARENA).dano
		ok(tecla+" dano único %.3f" % (2000-alvo.health), is_equal_approx(2000-alvo.health,esperado) and alvo.hits == 1)
		if tecla == "C": ok("C desloca o jogador", inicio.distance_to(p.global_position)>8)
		if tecla == "V": print("V hp=",p.health," pos=",p.position," bloqueio=",p._fruit_damage_lock_timer)
		if tecla == "V": ok("V cura 25%", p.health >= p.max_health*0.75 and p.health < p.max_health*0.77)
		await frames(60)
		ok(tecla+" limpa efeitos", get_nodes_in_group("phoenix_efeito").is_empty())
	await preparar()
	p.energy = 0
	await cast("X")
	ok("sem energia não lança X", get_nodes_in_group("phoenix_efeito").is_empty())
	await preparar()
	await cast("Z")
	await frames(35)
	await cast("F")
	p.take_damage(1.0)
	await frames(3)
	ok("dano interrompe voo", p._phoenix.voo == 0)
	await preparar()
	await cast("Z")
	p.equip_fruit("magu_magu")
	await frames(3)
	ok("troca restaura corpo e remove fênix", not p._phoenix.transformado and p.modelo_visual().visible and p._phoenix.get_child_count()==0)
	p.equip_fruit("tori_tori_phoenix")
	await preparar()
	for i in 5:
		await cast("Z")
		ok("transformação repetida %d" % i, p._phoenix.transformado)
		p.clear_spawned_skills()
		await frames(65)
	ok("cinco transformações sem nós acumulados", p._phoenix.get_child_count()==0)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("PHOENIX: %d passou / %d falhou" % [passou, falhas])
	quit(1 if falhas else 0)
