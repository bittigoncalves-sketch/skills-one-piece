extends SceneTree
## Caça-vazamento dos golpes da Gomu Gomu.
##
## Conta os nós vivos da cena, dispara um slot (Z/X/C/V), espera o efeito acabar
## e conta de novo. Se a contagem NÃO voltar ao valor inicial, algum nó de VFX
## ficou pendurado no mundo para sempre. Repete 5x: vazamento cresce linear;
## "ainda não terminou" não cresce.
##
## Uso:
##   godot --headless --path . --script tools/dev_tests/test_gomu_leak.gd -- V
##   (sem argumento roda os quatro: Z X C V)

const REPS := 5
const WAIT_AFTER_CAST := 6.5

var world: Node3D
var caster: CharacterBody3D
var slots := {"Z": 0, "X": 1, "C": 2, "V": 3}

func _initialize() -> void:
	await process_frame
	_build_world()
	# deixa a física registrar o chão antes de qualquer raycast
	for i in 8:
		await physics_frame
	for i in 10:
		await process_frame

	var pedidos: Array = []
	for a in OS.get_cmdline_user_args():
		if slots.has(a.to_upper()):
			pedidos.append(a.to_upper())
	if pedidos.is_empty():
		pedidos = ["Z", "X", "C", "V"]

	var perfil := false
	for a in OS.get_cmdline_user_args():
		if a.to_upper() == "PERFIL":
			perfil = true

	if perfil:
		await _perfilar_duracao("V")
	else:
		for slot in pedidos:
			await _testar_slot(slot)

	print("\n=== FIM ===")
	quit()

func _build_world() -> void:
	world = Node3D.new()
	world.name = "World"
	get_root().add_child(world)

	# chão (camada 1) para os raycasts de mira/teleporte/plunge
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	cs.shape = box
	floor_body.add_child(cs)
	world.add_child(floor_body)
	floor_body.global_position = Vector3(0, -1, 0)

	caster = CharacterBody3D.new()
	caster.name = "Caster"
	world.add_child(caster)
	caster.global_position = Vector3(0, 1, 0)

	# rig mínimo: GomuFX procura os nós por nome
	for n in ["UpperArm_R", "UpperArm_L"]:
		var arm := Node3D.new()
		arm.name = n
		caster.add_child(arm)
		arm.position = Vector3(0.4 if n.ends_with("_R") else -0.4, 1.4, 0)

func _testar_slot(slot: String) -> void:
	var variant: int = slots[slot]
	print("\n=== SLOT %s (variant %d) ===" % [slot, variant])

	var base := _snapshot()
	print("  baseline: %d nós" % base.size())

	var deltas: Array = []
	for rep in REPS:
		caster.global_position = Vector3(0, 1, 0)
		GomuFX.cast(world, caster.global_position, Vector3.FORWARD, variant, 20.0, caster)
		await create_timer(WAIT_AFTER_CAST).timeout
		var agora := _snapshot()
		var d: int = agora.size() - base.size()
		deltas.append(d)
		print("  disparo %d -> %d nós (delta acumulado %+d)" % [rep + 1, agora.size(), d])

	var final := _snapshot()
	var hist := {}
	for id in final:
		if base.has(id):
			continue
		var n = instance_from_id(id)
		if n == null:
			continue
		var k: String = n.get_class()
		hist[k] = int(hist.get(k, 0)) + 1
	if hist.is_empty():
		print("  RESULTADO: sem vazamento (delta final 0)")
	else:
		print("  RESULTADO: VAZOU %d nó(s) em %d disparos -> %s" % [final.size() - base.size(), REPS, str(hist)])
		print("            (por disparo: %.1f)" % (float(final.size() - base.size()) / float(REPS)))

# Mede QUANTO TEMPO cada nó de efeito fica vivo — para provar que o conserto do
# vazamento não encurtou nenhum efeito. Amostra a cena a cada ~0.05 s.
func _perfilar_duracao(slot: String) -> void:
	var variant: int = slots[slot]
	print("\n=== PERFIL DE DURAÇÃO — SLOT %s ===" % slot)
	var base := _snapshot()

	caster.global_position = Vector3(0, 1, 0)
	var t0 := Time.get_ticks_msec()
	GomuFX.cast(world, caster.global_position, Vector3.FORWARD, variant, 20.0, caster)

	var nasceu := {}   # instance_id -> [classe, t_primeiro_visto]
	var morreu := {}   # instance_id -> t_ultimo_visto
	while Time.get_ticks_msec() - t0 < 7000:
		await create_timer(0.05).timeout
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		for id in _snapshot():
			if base.has(id):
				continue
			var n = instance_from_id(id)
			if n == null:
				continue
			if not nasceu.has(id):
				nasceu[id] = [n.get_class(), t]
			morreu[id] = t

	var linhas: Array = []
	for id in nasceu:
		var vivo: bool = instance_from_id(id) != null
		linhas.append("  %-20s nasce %.2fs  some %.2fs  (vida %.2fs)%s" % [
			nasceu[id][0], nasceu[id][1], morreu[id], morreu[id] - nasceu[id][1],
			"   <-- AINDA VIVO AOS 7s (VAZAMENTO)" if vivo else ""])
	linhas.sort()
	for l in linhas:
		print(l)
	var restou: int = _snapshot().size() - base.size()
	print("  nós extras restantes aos 7s: %d" % restou)

func _snapshot() -> Dictionary:
	var out := {}
	_collect(world, out)
	return out

func _collect(n: Node, out: Dictionary) -> void:
	out[n.get_instance_id()] = n.get_class()
	for c in n.get_children():
		_collect(c, out)
