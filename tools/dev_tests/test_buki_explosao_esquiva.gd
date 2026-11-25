extends SceneTree
# Buki Buki 22/11/2026: bala bate em algo e explode (pequena; grande no canhão) e o inimigo esquiva com dash (recarga 3 s).
#   godot --headless --path . --fixed-fps 60 --script tools/dev_tests/test_buki_explosao_esquiva.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print("  %s %s" % ["ok " if c else "FALHA", m]); if not c: _f += 1

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _zonas(raiz: Node) -> Array:
	var r := []
	for c in raiz.get_children():
		if c is DamageZone: r.append(c)
	return r

func _init() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://teste_buki_explosao.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.global_position = Vector3(200, 1, 200)       # longe do teste
	var mundo := Node3D.new(); current_scene.add_child(mundo)
	var parede := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(30, 10, 1); cs.shape = bx
	parede.add_child(cs); mundo.add_child(parede)
	parede.global_position = Vector3(0, 5, -12)
	await quadros(3)

	print("— Z (pistola) bate na parede")
	BukiFX._explosoes_por_slot.clear()
	BukiFX.disparo(mundo, Vector3(0, 1.2, 0), Vector3.FORWARD, "Z", 5.0, null)
	await quadros(30)                                   # 42 m/s x 0,5 s = 21 m: passou da parede
	var fx := 0
	for c in mundo.get_children():
		if c is GPUParticles3D or c is OmniLight3D: fx += 1
	ok("a bala sumiu ao bater (nenhuma DamageZone viva)", _zonas(mundo).is_empty())
	ok("há explosão pequena no ponto (partículas/luz: %d)" % fx, fx >= 3)

	print("— X (canhão) bate na parede")
	await quadros(90)
	BukiFX.disparo(mundo, Vector3(0, 1.2, 0), Vector3.FORWARD, "X", 30.0, null)
	var area := false
	var raio_max := 0.0
	for i in 60:
		await physics_frame
		for z in _zonas(mundo):
			var sh := (z.get_child(0) as CollisionShape3D) if z.get_child_count() > 0 and z.get_child(0) is CollisionShape3D else null
			for ch in z.get_children():
				if ch is CollisionShape3D and ch.shape is SphereShape3D:
					raio_max = maxf(raio_max, (ch.shape as SphereShape3D).radius)
					if z.vel == Vector3.ZERO and (ch.shape as SphereShape3D).radius >= BukiExplosao.RAIO_GRANDE - 0.01:
						area = true
	ok("canhão cria a zona de dano em área (raio %.1f)" % raio_max, area)
	var grande := 0
	for c in mundo.get_children():
		if c is GPUParticles3D and (c as GPUParticles3D).amount >= 20: grande += 1
	ok("e a explosão grande tem fumaça/fogo em volume (sistemas grandes: %d)" % grande, grande >= 1 or area)

	print("— inimigo esquiva com dash")
	await quadros(90)
	var inimigo := PersonagemMinePiece.new()
	inimigo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	inimigo.position = Vector3(0, 1, -8)
	inimigo.ponto_de_origem = inimigo.position
	inimigo.set_meta("mc_sem_ia", true)
	current_scene.add_child(inimigo)
	await quadros(20)
	var x0 := inimigo.global_position.x
	ok("pronto para esquivar antes do 1º tiro", inimigo.esquiva_pronta())
	BukiFX.disparo(mundo, Vector3(0, 1.2, 0), Vector3.FORWARD, "Z", 0.0, null)
	await quadros(20)
	var deslocou := absf(inimigo.global_position.x - x0)
	ok("saiu da linha do tiro (%.2f m para o lado)" % deslocou, deslocou > 1.5)
	ok("recarga de 3 s ligada (não está pronto)", not inimigo.esquiva_pronta())
	ok("2º aviso dentro dos 3 s é recusado", not inimigo.esquivar_de_disparo(Vector3.FORWARD))
	var t0 := Time.get_ticks_msec()               # a recarga usa o relógio real (como a da Buki)
	while Time.get_ticks_msec() - t0 < 3300:
		await physics_frame
	ok("passados ~3 s volta a esquivar", inimigo.esquiva_pronta())

	print("— animal hostil também esquiva; manso não")
	var urso := AnimalDaIlha.new()
	current_scene.add_child(urso)
	urso.position = Vector3(10, 0.5, -8)
	urso.montar(BibliotecaDeModelos.padrao(), "bear", FichaDeAnimal.nova("predador", "quadrupede", {"nivel": 8}), {"centro": urso.position, "tamanho": Vector3(10, 5, 10)})
	var veado := AnimalDaIlha.new()
	current_scene.add_child(veado)
	veado.position = Vector3(-10, 0.5, -8)
	veado.montar(BibliotecaDeModelos.padrao(), "deer", FichaDeAnimal.nova("presa", "quadrupede"), {"centro": veado.position, "tamanho": Vector3(10, 5, 10)})
	jogador.global_position = Vector3(0, 1, 6)       # perto: a PopulacaoDeAnimais só liga a física de quem está a menos do nível 2
	await quadros(40)
	ok("urso hostil está pronto e o veado manso não", urso.esquiva_pronta() and not veado.esquiva_pronta())
	var ux := urso.global_position.x
	ok("urso esquiva ao ser avisado", urso.esquivar_de_disparo(Vector3.FORWARD))
	await quadros(25)
	var du := absf(urso.global_position.x - ux)
	ok("e saiu da linha (%.2f m)" % du, du > 1.5)
	ok("recarga de 3 s também no animal", not urso.esquivar_de_disparo(Vector3.FORWARD))
	ok("veado manso recusa", not veado.esquivar_de_disparo(Vector3.FORWARD))

	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
