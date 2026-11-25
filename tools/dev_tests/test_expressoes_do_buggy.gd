extends SceneTree
# Expressões/texturas do Buggy e animações do elenco (21/11/2026), com variantes SINTÉTICAS numa pasta de teste. Rodar:
#   godot --headless --path . --script tools/dev_tests/test_expressoes_do_buggy.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1

func _init() -> void:
	await process_frame
	print("\n===== EXPRESSÕES E ELENCO =====")
	var pasta := "user://teste_expressoes/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	_limpar(pasta)
	var base := Image.load_from_file(ProjectSettings.globalize_path("res://mapas/modelos/mp_buggy_corpo.png"))
	ok("atlas original 64×64", base != null and base.get_size() == Vector2i(64, 64))
	# variantes sintéticas: o rosto (x 8–15, y 8–15) numa cor distinta por expressão
	var cores := {"neutro": Color(0, 1, 0), "riso": Color(1, 1, 0), "raiva": Color(1, 0, 0), "surpresa": Color(0, 0, 1), "malicioso": Color(1, 0, 1), "derrotado": Color(0.2, 0.2, 0.2)}
	for e in cores:
		var im := base.duplicate() as Image
		for y in range(8, 16):
			for x in range(8, 16): im.set_pixel(x, y, cores[e])
		im.save_png(ProjectSettings.globalize_path(pasta + "buggy_rosto_%s.png" % e))
	ExpressoesDoBuggy.pasta = pasta
	var b := BibliotecaDeModelos.padrao()
	var buggy := (load(b.caminho_do_arquivo("mp_buggy")) as PackedScene).instantiate() as Node3D
	root.add_child(buggy)
	ok("sem arte nova de corpo → textura_do_corpo não muda nada", ExpressoesDoBuggy.textura_do_corpo(buggy, "mp_buggy") == 0)
	ok("expressão inexistente é ignorada", ExpressoesDoBuggy.expressao(buggy, "xyz") == 0)
	var original := ExpressoesDoBuggy._superficies(buggy, "mp_buggy_corpo.png")
	ok("o modelo tem superfícies com o atlas do corpo", original.size() > 0)
	for e in cores:
		var n := ExpressoesDoBuggy.expressao(buggy, e)
		var sup := ExpressoesDoBuggy._superficies(buggy, "mp_buggy_corpo.png")
		var m := (sup[0][0] as MeshInstance3D).get_active_material(sup[0][1]) as BaseMaterial3D
		var px := m.albedo_texture.get_image().get_pixel(10, 10)
		ok("expressão %s aplicada em %d superfícies (pixel do rosto = cor da variante)" % [e, n], n == sup.size() and px.is_equal_approx(cores[e]))
	# o corpo fora do rosto fica igual ao original
	var m2 := (ExpressoesDoBuggy._superficies(buggy, "mp_buggy_corpo.png")[0][0] as MeshInstance3D)
	var img := (m2.get_active_material(ExpressoesDoBuggy._superficies(buggy, "mp_buggy_corpo.png")[0][1]) as BaseMaterial3D).albedo_texture.get_image()
	ok("fora do rosto o atlas é idêntico ao original", img.get_pixel(40, 40).is_equal_approx(base.get_pixel(40, 40)) and img.get_pixel(3, 60).is_equal_approx(base.get_pixel(3, 60)))
	# outro Buggy do mundo (material do recurso importado) NÃO muda
	var outro := (load(b.caminho_do_arquivo("mp_buggy")) as PackedScene).instantiate() as Node3D
	root.add_child(outro)
	var so := ExpressoesDoBuggy._superficies(outro, "mp_buggy_corpo.png")
	var mo := (so[0][0] as MeshInstance3D).get_active_material(so[0][1]) as BaseMaterial3D
	ok("outra instância do modelo continua com o atlas original", mo.albedo_texture.get_image().get_pixel(10, 10).is_equal_approx(base.get_pixel(10, 10)))
	ok("do_estado mapeia as expressões do diálogo", ExpressoesDoBuggy.do_estado("erro_n7") == "riso" and ExpressoesDoBuggy.do_estado("desafio") == "malicioso" and ExpressoesDoBuggy.do_estado("acerto") == "derrotado")
	# textura nova do corpo
	var im2 := base.duplicate() as Image
	for y in range(20, 30): for x in range(20, 30): im2.set_pixel(x, y, Color(0, 1, 1))
	im2.save_png(ProjectSettings.globalize_path(pasta + "mp_buggy_corpo.png"))
	ExpressoesDoBuggy._cache.clear()
	var cabaji := (load(b.caminho_do_arquivo("mp_cabaji")) as PackedScene).instantiate() as Node3D
	root.add_child(cabaji)
	ok("textura nova do corpo aplicada ao Buggy (>0 superfícies)", ExpressoesDoBuggy.textura_do_corpo(buggy, "mp_buggy") > 0)
	ok("arte do Cabaji ausente → nada muda", ExpressoesDoBuggy.textura_do_corpo(cabaji, "mp_cabaji") == 0)
	# elenco animado
	var a := AnimacoesDoElenco.de(buggy)
	ok("animador criado e idle tocando", a != null and a.tem("idle") and a.tem("walk") and a.atual == "idle")
	a.andar(true); a._process(0.1)
	ok("andar(true) → walk", a.atual == "walk")
	a.andar(false); a._process(0.1)
	ok("andar(false) → volta ao idle", a.atual == "idle")
	ok("gesto existente toca", a.gesto("clap") and a.atual == "clap")
	ok("gesto inexistente é ignorado", not a.gesto("nao_existe"))
	var rich := AnimacoesDoElenco.de((load(b.caminho_do_arquivo("mp_richie")) as PackedScene).instantiate())
	ok("Richie (só idle/walk) ignora gestos sem quebrar", rich != null and not rich.gesto("clap") and rich.tem("walk"))
	a.falar(true)
	var gestos := {}
	for i in 900:
		a._process(0.05)
		gestos[a.atual] = true
	ok("falando por 45 s ele varia os gestos (≥ 2 diferentes além do idle)", gestos.size() >= 3)
	_limpar(pasta)
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)

func _limpar(pasta: String) -> void:
	var d := DirAccess.open(pasta)
	if d == null: return
	for f in d.get_files(): d.remove(f)
