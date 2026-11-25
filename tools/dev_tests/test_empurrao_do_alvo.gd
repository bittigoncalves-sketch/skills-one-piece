extends SceneTree
## O alvo acertado tem de SAIR do lugar (pedido do dono, 08/11/2026: "o knockback está insuficiente, ele fica parado no lugar
## ou recua um pouco"). Duas causas medidas aqui: a caminhada do inimigo somada ao empurrão o anulava, e o empurrão dos
## golpes de estilo (2–5 m/s, decaindo a 14 m/s²) rendia 0,1–0,9 m.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_empurrao_do_alvo.gd
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

## Quanto o corpo chegou a recuar (+X) em `n` quadros: depois do estontear ele volta a andar, então o fim não mede o golpe.
func _recuo_maximo(b: Node3D, x0: float, n: int) -> float:
	var maximo := 0.0
	for i in n:
		await physics_frame
		maximo = maxf(maximo, b.global_position.x - x0)
	return maximo

func _boneco(raiz: Node3D) -> BonecoDeDuelo:
	var b := BonecoDeDuelo.new()
	raiz.add_child(b)
	b.global_position = Vector3(0, 0.1, 0)
	return b

func rodar() -> void:
	await process_frame
	var raiz := Node3D.new()
	root.add_child(raiz)
	var chao := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(200, 1, 200)
	cs.shape = caixa
	chao.add_child(cs)
	chao.position.y = -0.5
	raiz.add_child(chao)
	var b := _boneco(raiz)
	await quadros(20)
	print("\n-- inimigo ANDANDO para o atacante (-X) e levando um jab (+X) --")
	var x0 := b.global_position.x
	b.andar(Vector3(-4.0, 0, 0))
	b.take_damage(10.0, Vector3(-2, 0, 0), Vector3(4.5, 0, 0), 0.25)
	var d := await _recuo_maximo(b, x0, 60)
	ok(d > 0.5, "o jab (4,5 m/s) o lança PARA TRÁS mesmo andando contra o golpe (%.2f m)" % d)
	b.queue_free()
	var b2 := _boneco(raiz)
	await quadros(20)
	x0 = b2.global_position.x
	b2.andar(Vector3(-4.0, 0, 0))
	b2.take_damage(10.0, Vector3(-2, 0, 0), Vector3(9.0, 0, 0), 0.5)
	d = await _recuo_maximo(b2, x0, 90)
	ok(d > 1.5, "o golpe forte (9 m/s) o lança bem longe (%.2f m)" % d)
	print("\nEMPURRAO_DO_ALVO %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
