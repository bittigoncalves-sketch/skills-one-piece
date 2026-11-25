extends SceneTree
## Mobs e inimigos sobem o relevo em blocos (08/11/2026): meio bloco andando, bloco inteiro pulando, parede alta não passa.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_escalada_de_mob.gd
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _caixa(raiz: Node3D, centro: Vector3, tamanho: Vector3) -> void:
	var c := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tamanho
	cs.shape = b
	c.add_child(cs)
	c.position = centro
	raiz.add_child(c)

## Anda para -Z (largura de 30 m de cada lado) contra um degrau de `altura` em z = -3 e devolve [altura do corpo, z]. Cada teste na sua faixa de X.
func _subir(raiz: Node3D, x: float, altura: float) -> Array:
	_caixa(raiz, Vector3(x, altura * 0.5, -8.0), Vector3(6.0, altura, 10.0))      # degrau de z -3 até -13
	var b := BonecoDeDuelo.new()
	raiz.add_child(b)
	b.global_position = Vector3(x, 0.1, 2.0)
	await quadros(10)
	for i in 240:
		b.andar(Vector3(0, 0, -3.0))
		await quadros(1)
	var r := [b.global_position.y, b.global_position.z]
	b.queue_free()
	return r

func rodar() -> void:
	await process_frame
	var raiz := Node3D.new()
	root.add_child(raiz)
	_caixa(raiz, Vector3(0, -0.5, 0), Vector3(400, 1, 400))
	var meio: Array = await _subir(raiz, 0.0, 0.44)
	ok(float(meio[0]) > 1.15 and float(meio[1]) < -4.0, "meio bloco (0,44 m): sobe andando (y %.2f, z %.1f)" % [meio[0], meio[1]])
	var inteiro: Array = await _subir(raiz, 20.0, 0.88)
	ok(float(inteiro[0]) > 1.55 and float(inteiro[1]) < -4.0, "bloco inteiro (0,88 m): pula e sobe (y %.2f, z %.1f)" % [inteiro[0], inteiro[1]])
	var parede: Array = await _subir(raiz, 40.0, 2.5)
	ok(float(parede[0]) < 1.0 and float(parede[1]) > -3.0, "parede de 2,5 m: não passa (y %.2f, z %.1f)" % [parede[0], parede[1]])
	EscaladaDeMob.ligada = false
	var sem_a: Array = await _subir(raiz, 60.0, 0.44)
	var sem_b: Array = await _subir(raiz, 80.0, 0.88)
	EscaladaDeMob.ligada = true
	ok(float(sem_a[1]) > -3.0 and float(sem_b[1]) > -3.0, "controle: sem a ajuda os dois degraus travam o corpo (z %.1f e %.1f) — era o defeito" % [sem_a[1], sem_b[1]])
	print("\nESCALADA_DE_MOB %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
