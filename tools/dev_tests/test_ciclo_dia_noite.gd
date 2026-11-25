extends SceneTree
# ============================================================================
#  CICLO DE DIA E NOITE (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_ciclo_dia_noite.gd
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_ciclo_dia_noite.gd -- --tela
#
#  Pedido do dono: ciclo de dia e noite; "à noite o jogador deve ver normalmente, não
#  escureça demais o mapa a ponto de impedir a visão". Escolha dele: 24 min por dia.
#  No MAPA VIVO (a vila), save de TESTE:
#    • começa às 8 h e anda 1 h por minuto real;
#    • meio-dia: sol forte com sombra, sem lua, sem estrelas;
#    • meia-noite: sol apagado, a LUA ilumina e faz a sombra, estrelas no céu;
#    • só uma luz com sombra por vez em todas as horas;
#    • amanhecer/entardecer: céu quente no horizonte;
#    • com tela: a cena à meia-noite guarda ≥ 45 % da luz do meio-dia e o contraste
#      continua (fotos das 4 horas em art_src/validation/ciclo_dia_noite/).
# ============================================================================

const SAVE := "user://test_ciclo_dia_noite_progresso.json"
const PASTA := "res://art_src/validation/ciclo_dia_noite"

var total := 0
var falhas := 0
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
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if tela:
		root.size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var cena := current_scene
	var ciclo := cena.find_child("CicloDiaNoite", false, false) as CicloDiaNoite
	ok(ciclo != null, "o Modo História tem o ciclo de dia e noite")
	if ciclo == null:
		return _fim()
	ok(absf(ciclo.hora - CicloDiaNoite.HORA_INICIAL) < 0.2, "começa às 8 h (%s)" % ciclo.texto_da_hora())
	var antes := ciclo.hora
	Engine.time_scale = 20.0
	await quadros(180)                       # 3 s × 20 = 60 s de jogo
	Engine.time_scale = 1.0
	ok(absf((ciclo.hora - antes) - 1.0) < 0.1, "1 minuto real = 1 hora (andou %.2f h)" % (ciclo.hora - antes))
	ciclo.pausado = true
	var sol := cena.get_node("Sol") as DirectionalLight3D
	var lua := cena.get_node("Lua") as DirectionalLight3D
	var ceu := ((cena.get_node("Ambiente") as WorldEnvironment).environment.sky.sky_material) as ShaderMaterial

	var p: Node3D = get_first_node_in_group("player")
	p.set("_pitch", deg_to_rad(-14.0))
	p.call("_update_pivot")
	var luz := {}
	for par in [[12.0, "meio_dia"], [18.6, "entardecer"], [0.0, "meia_noite"], [6.2, "amanhecer"]]:
		ciclo.definir_hora(par[0])
		await quadros(20)
		luz[par[1]] = await _foto(par[1])
		var sombras := int(sol.shadow_enabled and sol.visible) + int(lua.shadow_enabled and lua.visible)
		ok(sombras == 1, "%s: exatamente uma luz com sombra (%d)" % [par[1], sombras])
		match par[1]:
			"meio_dia":
				ok(sol.visible and sol.light_energy > 1.5 and not lua.visible, "meio-dia: sol forte (%.2f), sem lua" % sol.light_energy)
				ok(float(ceu.get_shader_parameter("estrelas")) < 0.01, "meio-dia: sem estrelas")
			"meia_noite":
				ok(not sol.visible and lua.visible and lua.light_energy > 0.5, "meia-noite: sol apagado, lua ilumina (%.2f)" % lua.light_energy)
				ok(float(ceu.get_shader_parameter("estrelas")) > 0.99, "meia-noite: estrelas no céu")
			"entardecer", "amanhecer":
				var h: Color = ceu.get_shader_parameter("cor_horizonte")
				ok(h.r > h.b, "%s: horizonte quente (%s)" % [par[1], str(h)])
	if tela:
		var dia: Dictionary = luz["meio_dia"]
		var noite: Dictionary = luz["meia_noite"]
		print("     luz média: meio-dia %.3f  ·  entardecer %.3f  ·  meia-noite %.3f  ·  amanhecer %.3f" % [
			dia["media"], luz["entardecer"]["media"], noite["media"], luz["amanhecer"]["media"]])
		print("     contraste (desvio): meio-dia %.3f  ·  meia-noite %.3f" % [dia["desvio"], noite["desvio"]])
		ok(noite["media"] >= dia["media"] * 0.45, "à meia-noite a cena guarda %.0f %% da luz do meio-dia (≥ 45 %%)" % (100.0 * noite["media"] / dia["media"]))
		ok(noite["desvio"] >= dia["desvio"] * 0.4, "e o contraste continua legível (%.0f %% do de dia)" % (100.0 * noite["desvio"] / dia["desvio"]))
	_fim()


## Foto (com tela) e a luz média/desvio do quadro inteiro.
func _foto(nome: String) -> Dictionary:
	if not tela:
		return {"media": 0.0, "desvio": 0.0}
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(PASTA.path_join(nome + ".png")))
	var soma := 0.0
	var soma2 := 0.0
	var n := 0
	for y in range(0, img.get_height(), 6):
		for x in range(0, img.get_width(), 6):
			var l := img.get_pixel(x, y).get_luminance()
			soma += l
			soma2 += l * l
			n += 1
	var media := soma / n
	return {"media": media, "desvio": sqrt(maxf(soma2 / n - media * media, 0.0))}


func _fim() -> void:
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nCICLO_DIA_NOITE %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
