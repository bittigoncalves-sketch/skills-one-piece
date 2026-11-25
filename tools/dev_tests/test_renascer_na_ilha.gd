extends SceneTree
# Morrer na Ilha dos Macacos NÃO volta o jogador à ilha inicial (22/11/2026), com o mapa real.
#   godot --headless --path . --fixed-fps 60 --script tools/dev_tests/test_renascer_na_ilha.gd
const ARQUIVO := "user://test_renascer_na_ilha.json"
var _f := 0
func ok(m: String, c: bool) -> void:
	print("  %s %s" % ["ok " if c else "FALHA", m]); if not c: _f += 1
func q(n: int) -> void:
	for i in n: await physics_frame

func _init() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	var Ilhas = load("res://src/historia/ilhas/ilhas.gd")
	var mapa: Dictionary = MapaArquivo.carregar("res://mapas/historia/baseplate.json")["mapa"]
	var caixas: Dictionary = Ilhas.caixas(mapa)
	if not caixas.has(Ilhas.MACACOS):
		print("  (sem Macacos no mapa)"); quit(1); return
	var c: Rect2 = caixas[Ilhas.MACACOS]
	var centro := c.get_center()
	var prog := ProgressaoDoPersonagem.new()
	prog.corpo = "masculino"
	prog.salvar(ARQUIVO)                 # sem local salvo: começa na ilha inicial
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", ARQUIVO)
	root.get_node("GameFlow").start_story()
	await q(500)
	var p = get_first_node_in_group("player")
	ok("começou na ilha inicial", Ilhas.ilha_em(caixas, p.global_position, 0.0) == Ilhas.INICIAL)
	# Viaja aos Macacos como quem chega de barco: NÃO é o caminho de teste que já renasce lá (`renascer_la`).
	current_scene.ir_a_ilha(Ilhas.MACACOS)
	await q(400)
	ok("chegou à Ilha dos Macacos", Ilhas.ilha_em(caixas, p.global_position, 0.0) == Ilhas.MACACOS)
	var ponto: Vector3 = p.ponto_de_renascimento
	ok("o ponto de renascimento passou para a Ilha dos Macacos (%s)" % [ponto], Ilhas.ilha_em(caixas, ponto, 0.0) == Ilhas.MACACOS)
	p.global_position = Vector3(centro.x, p.global_position.y, centro.y)
	await q(30)
	p.net_eliminar()
	await q(5)
	p.net_force_respawn()
	await q(10)
	ok("depois de morrer renasce na Ilha dos Macacos (%s)" % [p.global_position], Ilhas.ilha_em(caixas, p.global_position, 0.0) == Ilhas.MACACOS)
	# Voltar à inicial devolve o renascimento ao spawn do mapa.
	current_scene.ir_a_ilha(Ilhas.INICIAL)
	await q(400)
	ok("de volta à inicial renasce na inicial", Ilhas.ilha_em(caixas, p.ponto_de_renascimento, 0.0) == Ilhas.INICIAL)
	root.get_node("GameFlow").back_to_menu()
	await q(60)
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
