extends SceneTree
## O tronco acompanha a câmera (12/11/2026): olhar para baixo curva o corpo para a frente a partir da cintura, para cima inclina para trás; limite de olhar para cima subiu.
##   godot --headless --path . --script tools/dev_tests/test_inclinacao_do_tronco.gd
const MAPA := "user://test_inclinacao.json"
const SAVE := "user://test_inclinacao_progresso.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(64, 2, 64)
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var j = get_first_node_in_group("player")
	var anim = j.get("_proc_anim")
	ok(j.limites_de_pitch().y >= 1.2, "olhar para cima vai até ~72° (limite %.2f rad; era 0,5)" % j.limites_de_pitch().y)
	ok(j.limites_de_pitch().x <= -1.2, "olhar para baixo segue até ~69°")
	var rest: Vector3 = anim._rest.get("Torso", Vector3.ZERO)
	var medidas := {}
	for p in [-0.25, -1.2, 1.2]:
		for i in 90:
			anim.update(Vector3.ZERO, true, false, 0.016, p)
		medidas[p] = (anim._n["Torso"] as Node3D).rotation.x - rest.x
	ok(absf(medidas[-0.25]) < 0.03, "pitch de repouso: tronco em pé (%.3f rad)" % medidas[-0.25])
	ok(medidas[-1.2] > 0.25, "olhando para BAIXO o tronco se curva para a frente (%.2f rad = %.0f°)" % [medidas[-1.2], rad_to_deg(medidas[-1.2])])
	ok(medidas[1.2] < -0.25, "olhando para CIMA o tronco inclina para trás (%.2f rad = %.0f°)" % [medidas[1.2], rad_to_deg(medidas[1.2])])
	ok(absf(medidas[-1.2]) <= 0.7 and absf(medidas[1.2]) <= 0.7, "inclinação limitada (≤ 40°)")
	# a cabeça faz o resto: total do olhar > só o tronco
	var cab_rest: Vector3 = anim._rest.get("Head", Vector3.ZERO)
	for i in 90:
		anim.update(Vector3.ZERO, true, false, 0.016, -1.2)
	var cab: float = (anim._n["Head"] as Node3D).rotation.x - cab_rest.x
	ok(cab > 0.2, "a cabeça completa o olhar (%.2f rad)" % cab)
	print("test_inclinacao_do_tronco: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
