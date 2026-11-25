extends SceneTree
## ESC no Modo História (25/11/2026): abre "Configurações" (volume, sensibilidade, tela cheia, bonecos) e "Salvar e sair" grava o progresso e fecha o jogo.
## Save isolado e settings.cfg restaurado; o teste não fecha o programa (`fechar_o_jogo = false`).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_menu_de_pausa.gd
const PROGRESSO := "user://test_menu_de_pausa.json"
var _falhas := 0
func _init() -> void:
	call_deferred("_r")
func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _falhas += 1
func _quadros(n: int) -> void:
	for i in n: await physics_frame
func _r() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", PROGRESSO)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	var gf := root.get_node("GameFlow")
	var vol0: float = gf.get("volume"); var sens0: float = gf.get("sensibilidade"); var tela0: bool = gf.get("tela_cheia")
	var tt0: bool = gf.call("dummy_ligado", "TrainingDummy")
	gf.start_story()
	await _quadros(120)
	var cena := current_scene
	var prog = cena.progressao
	var hud = cena.get_node("HistoriaHud")
	hud.toggle_main_menu()                         # é o que o ESC do Player chama
	await _quadros(3)
	var menu = hud.get("_menu")
	_ok(menu is MenuDePausa and menu.is_open(), "ESC abre o menu de pausa (não o menu inicial)")
	_ok(menu.find_child("Painel", true, false) != null, "o painel Configurações existe")
	var titulos := []
	for l in menu.find_children("*", "Label", true, false): titulos.append(str(l.text))
	_ok("Configurações" in titulos, "o título é Configurações")
	_ok(menu.find_child("SalvarESair", true, false) != null and (menu.find_child("SalvarESair", true, false) as Button).text == "Salvar e sair", "tem a opção Salvar e sair")
	_ok(menu.find_child("Continuar", true, false) != null, "tem Continuar")
	(menu.find_child("Volume", true, false) as HSlider).value = 0.5
	(menu.find_child("Sensibilidade", true, false) as HSlider).value = 1.5
	(menu.find_child("TelaCheia", true, false) as CheckBox).button_pressed = true
	(menu.find_child("Boneco_TrainingDummy", true, false) as CheckBox).button_pressed = false
	_ok(absf(float(gf.get("volume")) - 0.5) < 0.001 and absf(float(gf.get("sensibilidade")) - 1.5) < 0.001 and bool(gf.get("tela_cheia")) and not gf.call("dummy_ligado", "TrainingDummy"),
		"os controles gravam as configurações")
	var cfg := ConfigFile.new()
	_ok(cfg.load("user://settings.cfg") == OK and absf(float(cfg.get_value("client", "volume", -1)) - 0.5) < 0.001 and float(cfg.get_value("client", "sensibilidade", -1)) == 1.5, "settings.cfg guarda volume e sensibilidade")
	menu.toggle()
	_ok(not menu.is_open(), "ESC de novo fecha")
	menu.open_menu()
	prog.ouro = 4321
	menu.fechar_o_jogo = false
	_ok(menu.salvar_e_sair(), "Salvar e sair grava o progresso")
	var lido := ProgressaoDoPersonagem.carregar(PROGRESSO)
	_ok(lido != null and lido.ouro == 4321, "o save tem o estado atual (ouro %d)" % (lido.ouro if lido else -1))
	# restaura as preferências do dono
	gf.call("set_volume", vol0); gf.call("set_sensibilidade", sens0); gf.call("set_tela_cheia", tela0); gf.call("set_dummy", "TrainingDummy", tt0)
	modo.set("mapa_forcado", ""); modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("MENU_DE_PAUSA falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)
