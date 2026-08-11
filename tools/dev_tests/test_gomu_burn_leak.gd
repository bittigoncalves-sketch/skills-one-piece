extends SceneTree
## Sonda focada: o V (Red Hawk) aplica BurnStatus nos inimigos no raio. Se o MESMO
## inimigo for queimado duas vezes, o segundo GPUParticles3D entra na árvore como
## "BurnVFX2" (Godot desambigua nomes), mas BurnStatus procura sempre por "BurnVFX"
## na hora de limpar. Este teste conta os nós PENDURADOS NO INIMIGO depois que
## todas as queimaduras já deviam ter acabado.

var world: Node3D
var caster: CharacterBody3D
var inimigo: CharacterBody3D

func _initialize() -> void:
	await process_frame
	_build()
	for i in 8:
		await physics_frame

	var base := _contar(inimigo)
	print("inimigo: %d nós antes" % base)

	# duas queimaduras sobrepostas no MESMO inimigo (V dura 3s de burn)
	_queimar(1.0)
	await create_timer(0.5).timeout
	_queimar(1.0)

	# 3s de burn + 1s de autofree do VFX + folga
	await create_timer(7.0).timeout
	var depois := _contar(inimigo)
	print("inimigo: %d nós depois (delta %+d)" % [depois, depois - base])
	for c in inimigo.get_children():
		print("   - %s (%s)" % [c.name, c.get_class()])
	quit()

func _queimar(dps: float) -> void:
	var burn = load("res://src/effects/BurnStatus.gd").new()
	burn.name = "RedHawkBurn"
	inimigo.add_child(burn)
	burn.setup(inimigo, 3.0, dps)

func _build() -> void:
	world = Node3D.new()
	get_root().add_child(world)
	caster = CharacterBody3D.new()
	world.add_child(caster)
	caster.global_position = Vector3(0, 1, 0)
	inimigo = CharacterBody3D.new()
	inimigo.name = "Inimigo"
	inimigo.set_script(GDScript.new())
	world.add_child(inimigo)
	inimigo.global_position = Vector3(0, 1, -5)
	inimigo.add_to_group("enemies")

func _contar(n: Node) -> int:
	var total := 1
	for c in n.get_children():
		total += _contar(c)
	return total
