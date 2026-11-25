extends SceneTree
# ============================================================================
#  VIDA DOS CHEFES NO TOPO DA TELA (08/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_barras_de_chefes.gd
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_barras_de_chefes.gd -- --tela
#
#  Pedido do dono: "adicionar a capacidade do jogador ver no topo superior da tela quanto
#  de vida tem cada boss". Na cena real da história (mapa e save de TESTE), com um
#  gorila (chefe dos morros) e a Sea Serpent (chefe do mar):
#    longe → nenhuma barra; perto → a barra dele com nome e vida; dano → a barra desce;
#    dois perto → duas, a do mais perto em cima; chefe agressivo longe → aparece; chefe
#    morto → some; menu aberto → as barras somem.
# ============================================================================

const MAPA := "user://test_barras_de_chefes.json"
const SAVE := "user://test_barras_de_chefes_progresso.json"

var total := 0
var falhas := 0
var barras: BarrasDeChefes
var tela := false


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	await process_frame
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(128, 2, 128)
	mapa.pecas.append({"id": "area_gorila", "tipo": "area_animais", "especie": "gorilla_-_animated_low_poly",
		"quantidade": 1, "posicao": Vector3(-30, 4, -30), "tamanho": Vector3(8, 6, 8), "rotacao_graus": Vector3.ZERO,
		"colisao": false, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0})
	var tam := bib.tamanho_padrao("besta_mar_serpente")
	mapa.pecas.append({"id": "serpente", "tipo": "modelo", "modelo": "besta_mar_serpente",
		"posicao": Vector3(100, tam.y / 2, -30), "tamanho": tam, "rotacao_graus": Vector3.ZERO,
		"colisao": true, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0})
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador: Node3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	barras = current_scene.find_child("BarrasDeChefes", true, false) as BarrasDeChefes
	var chefes := get_nodes_in_group(BarrasDeChefes.GRUPO)
	ok(barras != null and chefes.size() == 2, "o HUD tem as barras e há 2 chefes no grupo (%d)" % chefes.size())
	if barras == null or chefes.size() != 2:
		quit(1)
		return
	var gorila: Node3D = chefes.filter(func(c): return c is AnimalDaIlha)[0]
	var serpente: Node3D = chefes.filter(func(c): return not (c is AnimalDaIlha))[0]
	for c in chefes:
		c.set_physics_process(false)          # parados: o teste é a barra, não a IA
	# O jogador nasce perto do covil: o gorila pode ter começado a perseguir antes de parar.
	gorila.estado = AnimalDaIlha.Estado.PARADO
	# 1. Longe de todos.
	jogador.global_position = Vector3(40, 1, 50)
	await quadros(12)
	ok(_linhas() == [], "longe dos dois chefes, nenhuma barra (%s)" % str(_linhas()))
	# 2. Perto do gorila.
	jogador.global_position = gorila.global_position + Vector3(0, 0, 25)
	await quadros(12)
	var l := _linhas()
	ok(l.size() == 1 and l[0].begins_with(gorila.nome_de_exibicao()) and l[0].ends_with("900 / 900"),
		"a 25 m do gorila, a barra dele com nome e vida (%s)" % str(l))
	await _foto("chefe_gorila")
	# 3. Dano.
	gorila.health -= 300.0
	await quadros(12)
	l = _linhas()
	var barra: BarraHud = barras.get("_linhas")[0].barra
	ok(l.size() == 1 and l[0].ends_with("600 / 900") and absf(barra.get("_r") - 600.0 / 900.0) < 0.01,
		"o dano baixa a barra (600 / 900, %.2f)" % barra.get("_r"))
	# 4. Dois perto: o mais perto em cima.
	serpente.global_position = gorila.global_position + Vector3(45, 0, 0)
	jogador.global_position = gorila.global_position + Vector3(10, 0, 0)
	await quadros(12)
	l = _linhas()
	ok(l.size() == 2 and l[0].begins_with(gorila.nome_de_exibicao()) and l[1].begins_with(serpente.nome_de_exibicao()),
		"os dois perto: duas barras, o mais perto (gorila) em cima (%s)" % str(l))
	await _foto("dois_chefes")
	# 5. Agressivo longe.
	serpente.global_position = Vector3(110, 0, 40)
	jogador.global_position = Vector3(-50, 1, 50)
	serpente.set("agressiva", true)
	await quadros(12)
	l = _linhas()
	ok(l.size() == 1 and l[0].begins_with(serpente.nome_de_exibicao()), "a Sea Serpent agressiva aparece mesmo longe (%s)" % str(l))
	# 6. Menu aberto: some.
	var hud := current_scene.find_child("HistoriaHud", true, false)
	if hud == null:
		hud = get_first_node_in_group("hud")
	hud.call("toggle_main_menu")
	await quadros(12)
	ok(not barras.visible, "com o menu aberto, as barras somem")
	hud.call("toggle_main_menu")
	await quadros(12)
	ok(barras.visible, "fechado o menu, voltam")
	# 7. Chefe morto: some.
	serpente.set("agressiva", false)
	jogador.global_position = gorila.global_position + Vector3(0, 0, 20)
	gorila.set_physics_process(true)
	gorila.set_meta(VidaEmBarras.META_MORTE_ABSOLUTA, true)   # 10 barras (10/11/2026): o teste quer o chefe MORTO
	gorila.take_damage(99999.0, jogador.global_position)
	await quadros(12)
	ok(_linhas() == [], "gorila morto: a barra some (%s)" % str(_linhas()))
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("BARRAS_DE_CHEFES %d conferem | %d divergem" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)


## Os textos das barras visíveis, de cima para baixo.
func _linhas() -> Array[String]:
	var saida: Array[String] = []
	for linha in barras.get("_linhas"):
		if (linha.raiz as Control).visible:
			saida.append((linha.nome as Label).text)
	return saida


func _foto(nome: String) -> void:
	if not tela:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/bandidos/%s.png" % nome)
