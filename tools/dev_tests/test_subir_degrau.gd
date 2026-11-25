extends SceneTree
# ============================================================================
#  SUBIR DEGRAU (22/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md, E3) — o jogador do Modo
#  História andando com W de verdade:
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_subir_degrau.gd
#
#    • sobe um meio bloco (0,44 m) sem pular;
#    • sobe uma escada (meio bloco + bloco) sem pular;
#    • um bloco inteiro (0,88 m) barra;
#    • sobe uma rampa de relevo em blocos de verdade (malha fundida) sem prender;
#    • CORRENDO (Shift, 23/10/2026): meio bloco e escada sobem como andando — sem o
#      vault (pulo automático) que o parkour dava no meio bloco.
# ============================================================================

const B := RelevoEmBlocos.BLOCO
const M := RelevoEmBlocos.MEIO

var p: Node3D
var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func tecla(codigo: Key, pressionada: bool) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = pressionada
	Input.parse_input_event(evento)


func caixa(centro: Vector3, tamanho: Vector3) -> void:
	var corpo := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = tamanho
	forma.shape = s
	corpo.add_child(forma)
	current_scene.add_child(corpo)
	corpo.global_position = centro


var pico := 0.0                                  # y mais alto da última travessia


## Anda para −z (W com yaw 0) por `n` quadros a partir de `de`. Devolve a posição final.
## `correr` segura o Shift junto. Guarda em `pico` o y mais alto do caminho.
func andar(de: Vector3, n: int, correr := false) -> Vector3:
	tecla(KEY_W, false)
	tecla(KEY_SHIFT, false)
	p.global_position = de
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	await quadros(15)
	tecla(KEY_W, true)
	if correr:
		tecla(KEY_SHIFT, true)
	pico = p.global_position.y
	for i in n:
		await physics_frame
		pico = maxf(pico, p.global_position.y)
	tecla(KEY_W, false)
	tecla(KEY_SHIFT, false)
	await quadros(10)
	return p.global_position


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_subir_degrau.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	var y0: float = p.global_position.y           # parado no chão da placa (topo em 0)

	# Pistas separadas em x, obstáculos à frente (−z).
	caixa(Vector3(0, M * 0.5, -6), Vector3(4, M, 6))                        # meio bloco
	caixa(Vector3(8, M * 0.5, -4), Vector3(4, M, 2))                        # escada: meio bloco...
	caixa(Vector3(8, B * 0.5, -7), Vector3(4, B, 4))                        # ...e bloco
	caixa(Vector3(16, B * 0.5, -6), Vector3(4, B, 6))                       # bloco inteiro
	await quadros(3)

	print("\n-- meio bloco --")
	var fim := await andar(Vector3(0, y0, 0), 90)
	ok(absf(fim.y - (y0 + M)) < 0.06 and fim.z < -4.0, "em cima do meio bloco (subiu %.2f m, z %.1f)" % [fim.y - y0, fim.z])

	print("\n-- escada --")
	fim = await andar(Vector3(8, y0, 0), 110)
	ok(absf(fim.y - (y0 + B)) < 0.06 and fim.z < -6.0, "no topo da escada (subiu %.2f m, z %.1f)" % [fim.y - y0, fim.z])

	print("\n-- bloco inteiro barra --")
	fim = await andar(Vector3(16, y0, 0), 90)
	ok(fim.y - y0 < 0.1 and fim.z > -3.2, "parou na frente do bloco (subiu %.2f m, z %.1f)" % [fim.y - y0, fim.z])

	# Correndo: sem vault no que se sobe andando. Pulo do vault = ~0,7 da força do pulo,
	# subiria bem mais que meio bloco acima do topo; subir degrau não passa do topo.
	print("\n-- meio bloco CORRENDO --")
	fim = await andar(Vector3(0, y0, 0), 60, true)
	ok(absf(fim.y - (y0 + M)) < 0.06 and fim.z < -4.0 and pico - (y0 + M) < 0.15,
		"subiu sem pular (subiu %.2f m, pico %.2f m acima do topo, z %.1f)" % [fim.y - y0, pico - y0 - M, fim.z])

	print("\n-- escada CORRENDO --")
	fim = await andar(Vector3(8, y0, 0), 50, true)
	ok(absf(fim.y - (y0 + B)) < 0.06 and fim.z < -6.0 and pico - (y0 + B) < 0.15,
		"no topo sem pular (subiu %.2f m, pico %.2f m acima do topo, z %.1f)" % [fim.y - y0, pico - y0 - B, fim.z])

	print("\n-- rampa de relevo em blocos --")
	# Rampa 1:4 subindo para −z, como o teste do núcleo, em x = 40.
	var rampa := TerrenoDoMapa.plano(32)
	var alturas: PackedInt32Array = rampa["alturas"]
	for j in 33:
		for i in 33:
			var z := -8.0 + (float(j) / 32.0 - 0.5) * 32.0
			alturas[j * 33 + i] = int(round((0.3 + maxf(-z, 0.0) * 0.25) / 10.0 * TerrenoDoMapa.ESCALA))
	rampa["alturas"] = alturas
	var relevo := RelevoEmBlocos.de_pecas([{"id": "rampa", "posicao": Vector3(40, 5, -8), "tamanho": Vector3(32, 10, 32),
		"rotacao_graus": Vector3.ZERO, "relevo": rampa}])
	var corpo := StaticBody3D.new()
	corpo.set_meta(RelevoEmBlocos.META, relevo)
	var forma := CollisionShape3D.new()
	forma.shape = relevo.forma(relevo.triangulos())
	corpo.add_child(forma)
	current_scene.add_child(corpo)
	await quadros(3)
	var chao0 := relevo.altura(40.0, 6.0)
	fim = await andar(Vector3(40, chao0 + (y0 - 0.0) + 0.05, 6), 220)
	var chao_fim := relevo.altura(fim.x, fim.z)
	ok(fim.z < -12.0 and fim.y - chao_fim < 1.0, "subiu a rampa em blocos sem prender (z %.1f, %.2f m acima do início)" % [fim.z, fim.y - chao0 - y0])

	print("\n%d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
