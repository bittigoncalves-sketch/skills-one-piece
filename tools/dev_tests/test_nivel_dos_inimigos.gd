extends SceneTree
## Nível dos inimigos (10/11/2026): comuns nunca abaixo do jogador (piso = nível − 1), sem acumular, sem baixar fortes, sem tocar chefe/raid/aliado.
##   godot --headless --path . --script tools/dev_tests/test_nivel_dos_inimigos.gd
const Barras := preload("res://src/ui/barras_de_criaturas.gd")
const MAPA := "user://test_nivel.json"
const SAVE := "user://test_nivel_p.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _bandido(id: String, pos: Vector3) -> PersonagemMinePiece:
	var b := PersonagemMinePiece.new()
	b.montar(DadosEastBlue.ficha(id), "mp_" + id)
	b.position = pos
	b.ponto_de_origem = pos
	current_scene.add_child(b)
	return b
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(160, 2, 160)
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var m = current_scene
	var prog: ProgressaoDoPersonagem = m.get("progressao")
	var j: Node3D = get_first_node_in_group("player")
	var nivel: NivelDosInimigos = m.get("_nivel_dos_inimigos")
	ok(nivel != null, "a cena tem o NivelDosInimigos")
	var comum := _bandido("bandit", j.global_position + Vector3(10, 0, 0))
	var boneco := BonecoDeDuelo.new()
	boneco.position = j.global_position + Vector3(-10, 0, 0)
	current_scene.add_child(boneco)
	var chefe := _bandido("higuma", j.global_position + Vector3(0, 0, 12))
	chefe.add_to_group(BarrasDeChefes.GRUPO)
	var raider := _bandido("bandit", j.global_position + Vector3(0, 0, -12))
	raider.set_meta("raider", true)
	await quadros(5)
	var nivel0 := Barras.nivel_de(comum)
	var vida0 := comum.max_health
	var vida_b0 := boneco.max_health
	prog.nivel = 12
	nivel.varrer()
	ok(Barras.nivel_de(comum) >= 11, "comum sobe ao piso do jogador nível 12 (de N%d para N%d)" % [nivel0, Barras.nivel_de(comum)])
	ok(comum.max_health > vida0 * 1.5 and is_equal_approx(comum.health / comum.max_health, 1.0), "vida escalada (%.0f → %.0f) e cheia" % [vida0, comum.max_health])
	ok(float(comum.get_meta("fator_dano_nivel")) > 1.2, "fator de dano do nível (%.2f)" % float(comum.get_meta("fator_dano_nivel")))
	ok(boneco.max_health > vida_b0 and Barras.nivel_de(boneco) >= 11, "boneco de duelo também sobe (N%d)" % Barras.nivel_de(boneco))
	ok(float(chefe.get_meta("nivel_base", -1)) == -1.0 and float(raider.get_meta("nivel_base", -1)) == -1.0, "chefe e inimigo de raid ficam como estão")
	# idempotente
	var v1 := comum.max_health
	nivel.varrer()
	ok(is_equal_approx(comum.max_health, v1), "varrer de novo não acumula")
	# jogador sobe: relativo, sem acumular
	prog.nivel = 20
	nivel.varrer()
	ok(Barras.nivel_de(comum) >= 19 and comum.max_health > v1, "subir de nível reaplica (N%d, vida %.0f)" % [Barras.nivel_de(comum), comum.max_health])
	var f20 := NivelDosInimigos.fator_de_vida(Barras.nivel_de(comum) - int(comum.get_meta("nivel_base")))
	ok(absf(comum.max_health - vida0 * f20) < 1.0, "vida = base × fator do nível (%.0f ≈ %.0f)" % [comum.max_health, vida0 * f20])
	# forte nunca baixa
	var forte := _bandido("bandit", j.global_position + Vector3(14, 0, 0))
	forte.nivel = 40
	var vf := forte.max_health
	nivel.ajustar(forte)
	ok(forte.nivel == 40 and is_equal_approx(forte.max_health, vf), "criatura acima do piso não é alterada")
	print("test_nivel_dos_inimigos: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
