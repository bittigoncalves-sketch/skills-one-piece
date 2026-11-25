extends SceneTree
# O jogador nasce na ilha em que SAIU (22/11/2026), com o mapa real: save com local na Ilha dos Macacos -> nasce lá; e gravar_local grava a ilha certa.
#   godot --headless --path . --fixed-fps 60 --script tools/dev_tests/test_nascer_onde_saiu.gd
const ARQUIVO := "user://test_nascer_onde_saiu.json"
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
	print("  ilhas no mapa: ", caixas.keys())
	for destino in [Ilhas.MACACOS, Ilhas.EAST_BLUE]:
		if not caixas.has(destino):
			print("  (sem ", destino, " no mapa)"); continue
		var c: Rect2 = caixas[destino]
		var centro := c.get_center()
		var prog := ProgressaoDoPersonagem.new()
		prog.corpo = "masculino"
		prog.local_salvo = {"ilha": destino, "x": centro.x, "y": 3.0, "z": centro.y}
		prog.salvar(ARQUIVO)
		var modo = load("res://src/historia/ModoHistoria.gd")
		modo.set("progresso_forcado", ARQUIVO)
		root.get_node("GameFlow").start_story()
		await q(400)
		var p = get_first_node_in_group("player")
		var onde: String = Ilhas.ilha_em(caixas, p.global_position, 0.0) if p != null else "sem jogador"
		print("  nasceu em ", p.global_position if p != null else null, " -> ", onde)
		ok("save em %s: nasce em %s" % [destino, destino], onde == destino)
		# SALVAR: na praia (5 m fora da placa) e no ar, ao fechar, grava a ilha certa e DENTRO da placa
		var modo_no = current_scene
		var borda := Vector3(c.end.x + 5.0, 6.0, c.get_center().y)
		p.global_position = borda
		modo_no.gravar_local(true)
		var ls: Dictionary = modo_no.progressao.local_salvo
		var dentro: bool = c.has_point(Vector2(float(ls["x"]), float(ls["z"])))
		ok("fechando na praia (5 m fora, no ar) grava %s dentro da placa" % destino, str(ls["ilha"]) == destino and dentro)
		p.global_position = Vector3(c.end.x + 300.0, 6.0, c.end.y + 300.0)
		var antes: Dictionary = modo_no.progressao.local_salvo.duplicate()
		modo_no.gravar_local(true)
		ok("no mar aberto não sobrescreve o último chão", modo_no.progressao.local_salvo == antes)
		root.get_node("GameFlow").back_to_menu()
		await q(60)
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
