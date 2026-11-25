extends SceneTree
## Integração pela entrada real da fruta; save isolado e alvos imóveis mensuráveis.
var p: Node3D
var alvo: Node3D
var falhas := 0
var passou := 0
var modo: Script
class Alvo extends StaticBody3D:
	var health := 2000.0
	var hits := 0
	func take_damage(d: float, _origem:=Vector3.ZERO, _kb:=Vector3.ZERO, _stun:=0.0) -> void:
		health-=d
		hits+=1
## Como a besta do mar: corpo de 16x14x20 m com Hurtbox próprio; o centro fica a 10 m da pele.
class Gigante extends StaticBody3D:
	var health := 5000.0
	var hits := 0
	func _init() -> void:
		var cs := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(16,14,20)
		cs.shape = caixa
		add_child(cs)
		var hb := StaticBody3D.new()
		hb.name = "Hurtbox"
		hb.collision_layer = 4          # como as hurtboxes do jogo: na camada 1 o raio da Magu o toma por PAREDE e explode no casco
		var h := CollisionShape3D.new()
		h.shape = caixa
		hb.add_child(h)
		add_child(hb)
		add_to_group(AlvosDeGolpe.GRUPO)
	func take_damage(d: float, _origem:=Vector3.ZERO, _kb:=Vector3.ZERO, _stun:=0.0) -> void:
		health-=d
		hits+=1
class Mar extends Node3D:
	var nivel := 2.0
	var bases: Array = [{"posicao":Vector3(500,0,500),"tamanho":Vector3.ONE,"rotacao_graus":Vector3.ZERO}]
func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA",nome])
	if cond: passou+=1
	else: falhas+=1
func _limpar() -> void:
	for n in get_nodes_in_group("magu_efeito"): n.encerrar()
	await frames(3)
	p.global_position=Vector3(0,1,0)
	p.velocity=Vector3.ZERO
	p.energy=p.max_energy
	p.health=p.max_health
	p._fruit_cooldowns.clear()
	p._skill_cooldowns.clear()
	p._server_cast_next_ms.clear()
	p._intervalo_golpe=0.0
	p._trava_pos_fruta=0.0
	p._fruit_damage_lock_timer=0.0
	p._yaw=0.0
	p._pitch=0.0
	p._update_pivot()
	alvo.position=Vector3(0,1,-8)
	alvo.health=2000
	alvo.hits=0
	await frames(5)
func _cast(tecla: String) -> Node3D:
	p.begin_charge(tecla)
	await physics_frame
	p.release_charge(tecla)
	await frames(2)
	var lista := get_nodes_in_group("magu_efeito")
	return lista.back() if not lista.is_empty() else null
func _rodar() -> void:
	await process_frame
	modo=load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado","res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado","user://test_magu_historia.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p=get_first_node_in_group("player")
	if p==null:
		ok("jogador nasceu",false)
		quit(1)
		return
	current_scene.progressao.comer_fruta("magu_magu")
	for i in 300:                              # a troca de fruta é assíncrona: espera ficar equipada (com 5 quadros fixos o perfil lido ainda era o de "sem fruta")
		await physics_frame
		if p.current_fruit_id == "magu_magu" and p.perfil_de_frutas != null and not p.perfil_de_frutas.slots().is_empty():
			break
	p.combat_mode="fruit"
	alvo=Alvo.new()
	alvo.collision_layer=2
	var col:=CollisionShape3D.new()
	var forma:=CapsuleShape3D.new()
	forma.radius=.5
	forma.height=1.8
	col.shape=forma
	alvo.add_child(col)
	current_scene.add_child(alvo)
	alvo.add_to_group("enemy")
	ok("loja oferece Magu",PerfilDeFrutas.frutas_a_venda().has("magu_magu"))
	# `magu_magu` é fruta do mod (`FrutasDoMod.contem`): o perfil não lista técnicas por slot (quem as lista é o controlador) — o que vale conferir é que a fruta está equipada e o perfil existe.
	ok("a Magu está equipada e tem perfil",p.current_fruit_id=="magu_magu" and p.perfil_de_frutas!=null)
	for tecla in ["Z","X"]:
		await _limpar()
		var e=await _cast(tecla)
		ok(tecla+" nasceu pela entrada",is_instance_valid(e))
		ok(tecla+" consome energia",p.energy<p.max_energy)
		ok(tecla+" aplica recarga",p._fruit_cooldowns.get(tecla,0)>0)
		await frames(25)
		ok(tecla+" respeita preparação lenta",alvo.hits==0)
		await frames(210)
		var esperado: float=Balance.novo("magu_magu",tecla,p.escala_de_dano_da_fruta("magu_magu")).dano      # a escala que o JOGO usa (hoje 0,1; a constante da arena, 0,122, deixou de valer para a Magu)
		ok(tecla+" dano único correto: %.3f" % (2000-alvo.health),is_equal_approx(2000-alvo.health,esperado) and alvo.hits==1)
	# Animações próprias: Z arma e soca; X faz o jogador surfar a onda numa prancha.
	await _limpar()
	alvo.position=Vector3(300,1,300)
	await _cast("Z")
	ok("Z arma o braço (pose magu_z_prep)",p.get_meta("custom_pose","")=="magu_z_prep")
	await frames(30)
	ok("Z solta o soco (pose magu_z_soco)",p.get_meta("custom_pose","")=="magu_z_soco")
	await frames(60)
	ok("Z limpa a pose",str(p.get_meta("custom_pose","")).is_empty())
	await _limpar()
	alvo.position=Vector3(300,1,300)
	var inicio: Vector3=p.global_position
	var onda=await _cast("X")
	ok("X assume a base de surfe",p.get_meta("custom_pose","")=="magu_x_surf")
	await frames(70)
	ok("X carrega o jogador (meta magu_surf)",p.has_meta("magu_surf"))
	ok("X move o jogador junto da onda (%.1f m)" % inicio.distance_to(p.global_position),inicio.distance_to(p.global_position)>1.5)
	ok("X põe a prancha sob o jogador",is_instance_valid(onda) and onda._prancha!=null and absf(onda._prancha.global_position.x-p.global_position.x)<1.0 and absf(onda._prancha.global_position.z-p.global_position.z)<1.0)
	ok("X leva o jogador à crista (%.1f m acima)" % (p.global_position.y-inicio.y),p.global_position.y-inicio.y>3.5)
	await frames(400)
	ok("X solta o jogador no fim",not p.has_meta("magu_surf") and str(p.get_meta("custom_pose","")).is_empty())
	ok("X sem prancha pendurada",get_nodes_in_group("magu_efeito").is_empty())
	# Tecla da habilidade SEGURADA prende o jogador no lugar (14/10/2026).
	await _limpar()
	alvo.position=Vector3(300,1,300)
	var tecla_w := InputEventKey.new()
	tecla_w.physical_keycode=KEY_W
	tecla_w.keycode=KEY_W
	tecla_w.pressed=true
	Input.parse_input_event(tecla_w)
	await frames(30)
	var livre: float=p.global_position.distance_to(Vector3(0,p.global_position.y,0))
	ok("sem tecla de habilidade o jogador anda com W (%.1f m)" % livre,livre>1.0)
	await _limpar()
	alvo.position=Vector3(300,1,300)
	p.begin_charge("Z")
	await frames(40)
	var preso: float=p.global_position.distance_to(Vector3(0,p.global_position.y,0))
	ok("Z segurado prende o jogador no lugar (%.2f m)" % preso,preso<0.4)
	p.release_charge("Z")
	await frames(40)
	var solto: float=p.global_position.distance_to(Vector3(0,p.global_position.y,0))
	ok("soltar o Z devolve o movimento (%.1f m)" % solto,solto>1.5)
	tecla_w.pressed=false
	Input.parse_input_event(tecla_w)
	await _limpar()
	# Alvo gigante: a pele a 16 m, o centro a 26 m.
	var gigante := Gigante.new()
	current_scene.add_child(gigante)
	gigante.add_to_group("enemy")      # a mira da Magu trava em inimigo (grupo `enemy`): o gigante precisa ser um, como os chefes do jogo
	alvo.position=Vector3(300,1,300)
	for tecla in ["Z","X"]:
		await _limpar()
		alvo.position=Vector3(300,1,300)
		gigante.global_position=Vector3(0,7,-26)
		gigante.health=5000.0
		gigante.hits=0
		await _cast(tecla)
		await frames(240)
		ok(tecla+" acerta alvo gigante (hits=%d)" % gigante.hits,gigante.hits>=1)
	gigante.queue_free()
	await _limpar()
	# REFERÊNCIA: a corrida real (W + Shift) sob a MESMA locomoção. Desde que o jogo usa o movimento do Minecraft (`MovimentoMinecraft`) toda velocidade estacionária sai
	# ~0,905 do valor nominal, então a regra "o cão é exatamente 2× a corrida" só se confere pela RAZÃO entre as duas medidas, não por um 12,6 fixo.
	p.global_position=Vector3(0,1,40)
	p.velocity=Vector3.ZERO
	alvo.position=Vector3(80,1,80)
	var w0:=InputEventKey.new()
	w0.physical_keycode=KEY_W
	w0.keycode=KEY_W
	w0.pressed=true
	var sh:=InputEventKey.new()
	sh.physical_keycode=KEY_SHIFT
	sh.keycode=KEY_SHIFT
	sh.pressed=true
	Input.parse_input_event(sh)
	Input.parse_input_event(w0)
	await frames(150)
	var corrida: float=Vector2(p.velocity.x,p.velocity.z).length()
	w0.pressed=false
	sh.pressed=false
	Input.parse_input_event(w0)
	Input.parse_input_event(sh)
	await frames(30)
	p.global_position=Vector3(0,1,40)
	p.velocity=Vector3.ZERO
	var cao=await _cast("C")
	await frames(30)
	ok("C transforma",p.get_meta("magu_cao_ativo",false))
	ok("C oculta jogador",not p.modelo_visual().visible)
	var hp: float=p.health
	p.take_damage(5,Vector3.ZERO,Vector3(4,3,1))
	ok("C imune a dano",p.health==hp)
	p.receber_arremesso(Vector3(5,8,5))
	ok("C imune a arremesso",not p.esta_arremessado())
	var captura=load("res://src/historia/bosses/harpia/captura_vento.gd")
	ok("C imune à captura da Harpia",captura.tomar(p,alvo)==null)

	# Entrada de movimento real; Shift não deve multiplicar novamente.
	var w:=InputEventKey.new()
	w.physical_keycode=KEY_W
	w.keycode=KEY_W
	w.pressed=true
	alvo.position=Vector3(80,1,80)
	Input.parse_input_event(w)
	await frames(200)      # 90 quadros (eram): a aceleração até a velocidade final ficou mais lenta; medir já no regime
	var vel: float=Vector2(p.velocity.x,p.velocity.z).length()
	# Fórmula do jogo (`Player`): SPEED × speed_multiplier × 1,5 × 2,0. O 12,6 fixo só valia com multiplicador 1,0; a passiva da fruta o altera.
	ok("C velocidade 2× corrida: cão %.2f / corrida %.2f = %.3f" % [vel, corrida, vel / maxf(corrida, 0.001)], corrida > 3.0 and absf(vel / corrida - 2.0) < 0.08)
	w.pressed=false
	Input.parse_input_event(w)
	alvo.global_position=p.global_position+Vector3(0,0,-.5)
	await frames(3)
	ok("C explode e restaura",not p.get_meta("magu_cao_ativo",false) and alvo.hits==1 and p.modelo_visual().visible)
	await _limpar()
	cao=await _cast("C")
	await frames(30)
	current_scene.progressao.tirar_fruta()
	await frames(2)
	ok("troca limpa C e imunidade",not p.get_meta("magu_cao_ativo",false) and not p.has_meta("magu_acao"))
	current_scene.progressao.comer_fruta("magu_magu")
	await frames(5)
	await _limpar()
	var vulcao=await _cast("V")
	await frames(60)
	# O vulcão nasce ATRÁS do jogador: oposto à mira, a 9 m.
	var atras:Vector3=vulcao.global_position-p.global_position
	atras.y=0
	ok("V nasce atras do jogador",atras.normalized().dot(vulcao.rumo)<-.95 and atras.length()>8.0)
	alvo.position=vulcao.global_position+Vector3(4,1,0)
	await frames(570)
	ok("V lava causa dano repetido",alvo.hits>=3 and alvo.health<2000)
	ok("V respeita teto",2000-alvo.health<=117.188)
	ok("V limpa campo",not is_instance_valid(vulcao))
	# Água registrada pelo mesmo serviço de rios/oceano do modo história.
	await _limpar()
	cao=await _cast("C")
	await frames(30)
	var mar:=Mar.new()
	current_scene.add_child(mar)
	AguaDoMundo.registrar({"pecas":[]},mar)
	await frames(2)
	ok("água destransforma C",not p.get_meta("magu_cao_ativo",false))
	ok("água solidifica visual",is_instance_valid(cao) and cao.fase=="pedra")
	await frames(45)
	ok("pedra desaparece",not is_instance_valid(cao))
	AguaDoMundo.esquecer()
	mar.queue_free()
	await _limpar()
	cao=await _cast("C")
	alvo.position=Vector3(80,1,80)
	await frames(410)
	ok("C encerra no limite",not is_instance_valid(cao) and not p.get_meta("magu_cao_ativo",false))
	# Dano volta após o término, e morte interrompe sem preservar o buff.
	var hp_depois: float=p.health
	p.take_damage(2,Vector3.ZERO,Vector3.ZERO,0.0)
	ok("imunidade não vaza após C",p.health<hp_depois)
	await _limpar()
	await frames(120)
	for tecla in ["Z","X"]:
		alvo.position=Vector3(80,1,80)
		var efeito=await _cast(tecla)
		await frames(75)
		var agua:=Mar.new()
		current_scene.add_child(agua)
		AguaDoMundo.registrar({"pecas":[]},agua)
		await frames(2)
		ok(tecla+" solidifica ao tocar água",is_instance_valid(efeito) and efeito.fase=="pedra")
		var hits_antes: int=alvo.hits
		await frames(50)
		ok(tecla+" pedra sem dano e removida",alvo.hits==hits_antes and not is_instance_valid(efeito))
		AguaDoMundo.esquecer()
		agua.queue_free()
		await _limpar()
	vulcao=await _cast("V")
	await frames(200)
	var agua:=Mar.new()
	current_scene.add_child(agua)
	AguaDoMundo.registrar({"pecas":[]},agua)
	await frames(2)
	var solidificadas:=0
	for placa in vulcao._placas:
		if float(placa.pedra)>=0: solidificadas+=1
	ok("V solidifica os 100 trechos de lava",solidificadas==100)
	await frames(45)
	var vivas:=0
	for placa in vulcao._placas:
		if is_instance_valid(placa.no): vivas+=1
	ok("V remove a lava solidificada",vivas==0)
	AguaDoMundo.esquecer()
	agua.queue_free()
	await _limpar()
	ok("sem efeitos pendurados",get_nodes_in_group("magu_efeito").is_empty())
	cao=await _cast("C")
	await frames(30)
	p.net_eliminar()
	await frames(2)
	ok("morte limpa transformação",not p.get_meta("magu_cao_ativo",false))
	modo.set("mapa_forcado","")
	modo.set("progresso_forcado","")
	current_scene.queue_free()
	await frames(90)
	print("MAGU: %d passaram / %d falharam" % [passou,falhas])
	quit(1 if falhas else 0)
