extends SceneTree
## Dois processos: o cliente usa a entrada real; o host observa estados e hitboxes.
var anfitriao := false
var p: Node
var viu_forma := false
var viu_voo := false
var viu_reversao := false
var danos := {}
var curou := false
var feriu := false
func _init() -> void: rodar.call_deferred()
func esperar(segundos: float) -> void:
	await create_timer(segundos).timeout
func rodar() -> void:
	await process_frame
	anfitriao = OS.get_cmdline_user_args().has("host")
	var fluxo := root.get_node("GameFlow")
	fluxo.dummies["TrainingDummy"] = false
	fluxo.dummies["AutoDummy"] = false
	if anfitriao: fluxo.create_room()
	else: fluxo.join_room("127.0.0.1")
	var limite := Time.get_ticks_msec()+18000
	while Time.get_ticks_msec()<limite:
		await process_frame
		for n in get_nodes_in_group("player"):
			if (anfitriao and str(n.name)!="1") or (not anfitriao and n.is_multiplayer_authority()): p=n
		if is_instance_valid(p): break
	if not is_instance_valid(p):
		print("FALHA Phoenix rede: cliente ausente")
		quit(1)
		return
	if anfitriao: await observar()
	else: await conjurar()
func observar() -> void:
	var inicio := Time.get_ticks_msec()
	var ajustou_vida := false
	while Time.get_ticks_msec()-inicio<18000 and is_instance_valid(p):
		await physics_frame
		if not is_instance_valid(p): break
		if p.current_fruit_id != "tori_tori_phoenix": continue
		if not ajustou_vida:
			p.health = p.max_health*0.5
			p.net_vida_do_servidor.rpc(p.health,0.0)
			ajustou_vida = true
		viu_forma = viu_forma or p._phoenix.transformado
		viu_voo = viu_voo or p._phoenix.voo>0
		viu_reversao = viu_reversao or (viu_forma and not p._phoenix.transformado)
		curou = curou or p.health>=p.max_health*0.74
		for z in get_nodes_in_group("hitbox"):
			if z is DamageZone and z.caster == p:
				danos[int(z.damage)] = true
		for n in get_nodes_in_group("player"):
			if str(n.name)=="1" and n.health<n.max_health-50: feriu=true
	var passou := viu_forma and viu_voo and viu_reversao and curou and feriu \
		and danos.has(160) and danos.has(240) and danos.has(512)
	print("PHOENIX REDE: forma=%s voo=%s reversao=%s cura=%s dano_no_host=%s hitboxes=%s" % [viu_forma,viu_voo,viu_reversao,curou,feriu,danos.keys()])
	quit(0 if passou else 1)
func conjurar() -> void:
	p.combat_mode = "fruit"
	p.equip_fruit("tori_tori_phoenix")
	await esperar(2.0)
	for tecla in ["Z","F","F","Z","X","C","V"]:
		if tecla in ["X","C","V"]:
			for n in get_nodes_in_group("player"):
				if str(n.name)=="1": p.global_position=n.global_position+Vector3(0,0,3)
			p.velocity=Vector3.ZERO
			p._yaw=0
			p._pitch=0
			p._update_pivot()
			await esperar(.25)
		p.begin_charge(tecla)
		p.release_charge(tecla)
		await esperar(1.5)
	await esperar(7.0)
	quit()
