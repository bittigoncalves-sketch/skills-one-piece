extends SceneTree
# FORMAS GIGANTES (Pehkui `scale`): o comando do mod muda o corpo do jogador (modelo, cápsula, hurtbox, câmera) e dos personagens.
#   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_formas_gigantes_mine_piece.gd
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

func perto(a: float, b: float, e := 0.02) -> bool:
	return absf(a - b) <= e

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_formas.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var ej := McEntidade.de(jogador)
	var mundo: McMundo = ej.level()
	var fonte := McComandos.Fonte.new()
	fonte.mundo = mundo
	fonte.entidade = ej
	fonte.posicao = ej.position()
	var capsula: CapsuleShape3D = jogador._colisor.shape
	var altura0: float = capsula.height
	var raio0: float = capsula.radius
	var modelo0: Vector3 = jogador._char_model.scale
	var bb0 := ej.getBbHeight()
	var olhos0 := ej.getEyeHeight()
	ok(perto(ej.escala(&"height"), 1.0), "escala inicial 1")

	# a forma gigante do mod (WhenRespawn: estilo Gigante)
	Mc.pedidos_sem_implementacao.clear()
	for c in ["scale set pehkui:width 4 @s", "scale set pehkui:height 4 @s", "scale set pehkui:reach 3 @s"]:
		McComandos.executar(fonte, c)
	await quadros(5)
	ok(perto(ej.escala(&"height"), 4.0) and perto(ej.escala(&"width"), 4.0) and perto(ej.escala(&"reach"), 3.0), "os três valores do mod guardados (4/4/3)")
	ok(perto(jogador._colisor.shape.height, altura0 * 4.0, 0.05), "cápsula 4× mais alta (%.2f → %.2f)" % [altura0, jogador._colisor.shape.height])
	ok(perto(jogador._colisor.shape.radius, raio0 * 4.0, 0.05), "e 4× mais larga")
	ok(jogador._char_model.scale.is_equal_approx(modelo0 * 4.0), "o modelo cresce junto (%s)" % str(jogador._char_model.scale))
	ok(perto(ej.getBbHeight(), bb0 * 4.0) and perto(ej.getEyeHeight(), olhos0 * 4.0), "a caixa que as procedures leem (getBbHeight %.1f, olhos %.1f)" % [ej.getBbHeight(), ej.getEyeHeight()])
	ok(not Mc.pedidos_sem_implementacao.has("comando:scale"), "o comando deixou de ser falta")
	# a base do corpo continua no chão: o fundo da cápsula não afundou
	var fundo: float = jogador._colisor.position.y - jogador._colisor.shape.height * 0.5
	var fundo0: float = jogador._colisor.position.y * 0.0 + (-altura0 * 0.5)
	ok(perto(fundo, fundo0, 0.05), "o fundo da cápsula segue no mesmo lugar (%.2f ≈ %.2f)" % [fundo, fundo0])
	# a câmera acompanha
	var esc_cam = jogador._camera.get("_escala") if "_escala" in jogador._camera else null
	print("   câmera: escala interna = %s" % str(esc_cam))
	# agachar volta ao tamanho CERTO da forma (não ao de antes)
	jogador._agachar.aplicar(true)
	jogador._agachar.aplicar(false)
	ok(perto(jogador._colisor.shape.height, altura0 * 4.0, 0.05), "depois de agachar a cápsula volta ao tamanho da forma")

	# add / subtract / reset / get
	McComandos.executar(fonte, "scale subtract pehkui:height 1 @s")
	ok(perto(ej.escala(&"height"), 3.0), "subtract 1 → 3")
	McComandos.executar(fonte, "scale add pehkui:height 0.5 @s")
	ok(perto(ej.escala(&"height"), 3.5), "add 0,5 → 3,5")
	McComandos.executar(fonte, "scale set pehkui:height 1 @s")
	McComandos.executar(fonte, "scale set pehkui:width 1 @s")
	McComandos.executar(fonte, "scale set pehkui:reach 1 @s")
	await quadros(5)
	ok(perto(jogador._colisor.shape.height, altura0, 0.05) and jogador._char_model.scale.is_equal_approx(modelo0), "voltar a 1 devolve o corpo ao normal")
	McComandos.executar(fonte, "scale set pehkui:height 999 @s")
	ok(ej.escala(&"height") <= McEntidade.ESCALA_MAXIMA, "teto de segurança (%.0f)" % ej.escala(&"height"))
	McComandos.executar(fonte, "scale set pehkui:height 1 @s")
	McComandos.executar(fonte, "scale set pehkui:motion 2 @s")
	ok(Mc.pedidos_sem_implementacao.has("comando:scale:motion"), "tipo de escala que o mod não usa é contado")

	# personagem do mod
	var arlong := PersonagemMinePiece.new()
	arlong.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	arlong.position = jogador.global_position + Vector3(0, 0, -8)
	arlong.ponto_de_origem = arlong.position
	arlong.set_meta("mc_sem_ia", true)
	current_scene.add_child(arlong)
	await quadros(5)
	var ea := McEntidade.de(arlong)
	var h0 := ea.getBbHeight()
	var cap_a: CapsuleShape3D
	for f in arlong.get_children():
		if f is CollisionShape3D and f.shape is CapsuleShape3D:
			cap_a = f.shape
	var alt_a0 := cap_a.height
	fonte.entidade = ea
	McComandos.executar(fonte, "scale set pehkui:height 2 @s")
	McComandos.executar(fonte, "scale set pehkui:width 2 @s")
	await quadros(3)
	ok(perto(ea.getBbHeight(), h0 * 2.0) and cap_a.height > alt_a0 * 1.9, "personagem: caixa e cápsula 2× (%.2f → %.2f)" % [alt_a0, cap_a.height])
	ok(arlong._modelo.scale.is_equal_approx(Vector3(2, 2, 2)), "personagem: modelo 2×")
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
