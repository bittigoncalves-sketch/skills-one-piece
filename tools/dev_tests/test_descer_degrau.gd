extends SceneTree
# ============================================================================
#  DESCER DO RELEVO EM BLOCOS (23/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md) — relato do
#  dono: "ao tentar descer do relevo de um bloco o personagem está travando".
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_descer_degrau.gd
#
#  O jogador do Modo História anda com W de verdade, de cima para baixo, por degraus de
#  relevo em blocos (malha fundida + colisão côncava, como nas ilhas): meio bloco, bloco,
#  dois blocos, quatro blocos — de frente e na diagonal. Passa se chega embaixo, além
#  da borda, sem ficar parado com W apertado.
# ============================================================================

const B := RelevoEmBlocos.BLOCO
const M := RelevoEmBlocos.MEIO
## Quadros seguidos andando menos que isto (m/quadro) com W apertado = preso.
const PARADO := 0.01
const QUADROS_PRESO := 20

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


## Degrau de relevo em blocos em `x`: alto (z > 0) e baixo (z < 0), alturas em metros.
func degrau(x: float, alto: float, baixo: float) -> RelevoEmBlocos:
	var t := TerrenoDoMapa.plano(32)
	var alturas: PackedInt32Array = t["alturas"]
	for j in 33:
		for i in 33:
			var z := (float(j) / 32.0 - 0.5) * 32.0
			alturas[j * 33 + i] = int(round((alto if z > 0.0 else baixo) / 20.0 * TerrenoDoMapa.ESCALA))
	t["alturas"] = alturas
	var relevo := RelevoEmBlocos.de_pecas([{"id": "degrau%d" % int(x), "posicao": Vector3(x, 10, 0),
		"tamanho": Vector3(32, 20, 32), "rotacao_graus": Vector3.ZERO, "relevo": t}])
	var corpo := StaticBody3D.new()
	corpo.set_meta(RelevoEmBlocos.META, relevo)
	var forma := CollisionShape3D.new()
	forma.shape = relevo.forma(relevo.triangulos())
	corpo.add_child(forma)
	current_scene.add_child(corpo)
	return relevo


## Anda com W na direção `yaw` a partir de `de` por `n` quadros. Devolve
## {fim, preso (maior sequência de quadros parado), log (quadros em que ficou parado)}.
func andar(de: Vector3, yaw: float, n: int) -> Dictionary:
	tecla(KEY_W, false)
	p.global_position = de
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	await quadros(15)
	tecla(KEY_W, true)
	var antes: Vector3 = p.global_position
	var seguidos := 0
	var maior := 0
	var log: Array[String] = []
	for q in n:
		await physics_frame
		var agora: Vector3 = p.global_position
		var mov := Vector2(agora.x - antes.x, agora.z - antes.z).length()
		if q > 10 and mov < PARADO:
			seguidos += 1
			if log.size() < 6:
				var normais := []
				for k in p.get_slide_collision_count():
					normais.append(p.get_slide_collision(k).get_normal().snappedf(0.01))
				log.append("q%d pos %s vel %s chão %s parede %s escala %s wallrun %s normais %s" % [q,
					agora.snappedf(0.01), p.velocity.snappedf(0.01), p.is_on_floor(), p.is_on_wall(),
					p._parkour.escalando(), p._parkour.correndo_na_parede(), normais])
		else:
			seguidos = 0
		maior = maxi(maior, seguidos)
		antes = agora
	tecla(KEY_W, false)
	await quadros(10)
	return {"fim": p.global_position, "preso": maior, "log": log}


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_descer_degrau.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	var acima: float = p.global_position.y        # centro do corpo acima do chão (placa em 0)

	# Alturas múltiplas de meio bloco: o ajuste não arredonda.
	var casos := [
		["meio bloco", 2 * M, 1 * M],
		["bloco", 3 * M, 1 * M],
		["dois blocos", 5 * M, 1 * M],
		["quatro blocos", 9 * M, 1 * M],
	]
	for n in casos.size():
		var x := 60.0 + n * 40.0
		var relevo := degrau(x, casos[n][1], casos[n][2])
		await quadros(3)
		for direcao in [["de frente", 0.0], ["na diagonal", deg_to_rad(40.0)]]:
			print("\n-- %s, %s --" % [casos[n][0], direcao[0]])
			var de := Vector3(x, relevo.altura(x, 4.0) + acima + 0.05, 4.0)
			var r := await andar(de, direcao[1], 150)
			var fim: Vector3 = r["fim"]
			var chao := relevo.altura(fim.x, fim.z)
			for linha in r["log"]:
				print("     " + linha)
			ok(fim.z < -2.0 and absf(fim.y - acima - chao) < 0.1 and r["preso"] < QUADROS_PRESO,
				"desceu (z %.1f, %.2f m acima do chão de baixo, parado %d quadros seguidos)" % [
					fim.z, fim.y - acima - casos[n][2], r["preso"]])

	print("\n%d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
