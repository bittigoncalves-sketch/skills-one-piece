extends SceneTree
## A janela única do M (30/10/2026): M abre; botões de aba trocam Status/Inventário/Pets; B e N não abrem
## nada; mesmo tamanho nas três; aparência (cor, opacidade, escala) salva no progresso e restaurada.
## Mapa/progresso exclusivos; não usa nem grava a campanha do dono.
const PROGRESSO := "user://teste_central_de_janelas_progresso.json"
var _falhas := 0
var _hud: Node

func _init() -> void:
	call_deferred("_executar")

func _ok(condicao: bool, mensagem: String) -> void:
	print(("  ✅ " if condicao else "  ❌ ") + mensagem)
	if not condicao:
		_falhas += 1

func _quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _tecla(codigo: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = true
	root.push_input(ev, true)
	await process_frame

func _aba(id: String) -> void:
	(_hud.central().find_child("Aba_" + id, true, false) as Button).pressed.emit()
	await process_frame

func _executar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = PROGRESSO
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	root.get_node("GameFlow").start_story()
	await _quadros(100)
	_hud = current_scene.get_node("HistoriaHud")
	var c: CentralDeJanelas = _hud.central()
	_ok(c != null and c.tem_pagina("status") and c.tem_pagina("mochila") and c.tem_pagina("pets") and not c.tem_pagina("inventario") and c.find_child("Aba_inventario", true, false) == null, "a central tem status, mochila e pets — e NÃO tem mais a aba Inventário (19/11/2026)")
	_ok(not _hud.central_aberta() and not _hud.is_menu_open(), "começa fechada")

	print("\n-- B e N não abrem nada --")
	await _tecla(KEY_N)
	_ok(not _hud.central_aberta() and not _hud.inventario_aberto(), "N fechado: nada abre")
	await _tecla(KEY_B)
	_ok(not _hud.central_aberta() and not _hud.menu_de_pets_aberto(), "B fechado: nada abre")

	print("\n-- M abre e as abas trocam --")
	await _tecla(KEY_M)
	_ok(_hud.central_aberta() and _hud.status_aberto() and not _hud.inventario_aberto() and not _hud.menu_de_pets_aberto(),
		"M abre na aba Status (a primeira vez)")
	# O mouse (Input.mouse_mode) não existe em headless: fica sempre em 0. Só o estado de "menu aberto" é conferido aqui.
	_ok(_hud.is_menu_open(), "conta como menu aberto")
	var tamanhos := {}
	var rect_conteudo := {}
	for id in ["status", "mochila", "pets"]:
		await _aba(id)
		await process_frame
		var abertas := [_hud.status_aberto(), _hud.inventario_aberto(), _hud.menu_de_pets_aberto()]
		_ok(abertas.count(true) == 1 and abertas[["status", "mochila", "pets"].find(id)], "aba %s: só ela está aberta" % id)
		tamanhos[id] = c.size
		var rol := c.find_child("Rolagem_" + id, true, false)
		print("  [diag] aba %s: página min=%s tamanho=%s | rolagem=%s | mochila.escala=%.2f" % [id, str(c.pagina(id).get_combined_minimum_size()), str(c.pagina(id).size), str(rol.size) if rol else "-", _hud.mochila().escala])
		rect_conteudo[id] = (c.find_child("Conteudo", true, false) as Control).size
	_ok(tamanhos["status"].is_equal_approx(tamanhos["mochila"]) and tamanhos["status"].is_equal_approx(tamanhos["pets"]),
		"a janela tem o MESMO tamanho nas três abas (%s)" % str(tamanhos))
	_ok(rect_conteudo["status"].is_equal_approx(Vector2(CentralDeJanelas.LARGURA, CentralDeJanelas.ALTURA))
		and rect_conteudo["pets"].is_equal_approx(rect_conteudo["status"]), "o corpo mede %s × %s sempre (%s)" % [CentralDeJanelas.LARGURA, CentralDeJanelas.ALTURA, str(rect_conteudo)])
	await _tecla(KEY_N)
	_ok(_hud.menu_de_pets_aberto() and not _hud.inventario_aberto(), "N dentro da central não troca de aba")
	await _tecla(KEY_B)
	_ok(_hud.menu_de_pets_aberto(), "B dentro da central não troca nem fecha")

	print("\n-- fechar e reabrir na última aba --")
	await _aba("mochila")
	await _tecla(KEY_M)
	_ok(not _hud.central_aberta() and not _hud.inventario_aberto() and not _hud.is_menu_open(), "M fecha (de qualquer aba)")
	await _tecla(KEY_M)
	_ok(_hud.inventario_aberto(), "M reabre na última aba usada (Mochila, que abriga os itens do antigo Inventário)")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	_hud._input(esc)
	_ok(not _hud.central_aberta(), "ESC fecha")
	_ok(_hud.abrir_menu_de_pets() and _hud.menu_de_pets_aberto(), "o jogo pode pedir a aba Pets (tripulação)")
	_hud.central().fechar()
	_hud.alternar_status()
	_ok(_hud.status_aberto(), "alternar_status abre na aba Status")
	_hud.alternar_status()
	_ok(not _hud.central_aberta(), "e fecha")

	print("\n-- aparência --")
	await _tecla(KEY_M)
	var prog: ProgressaoDoPersonagem = current_scene.progressao
	var cor_antes := c.cor_de_destaque()
	(c.find_child("Cor_azul", true, false) as Button).pressed.emit()
	_ok(c.cor_de_destaque() != cor_antes and c.aparencia.cor == "azul", "a bolinha azul troca a cor de destaque")
	c.definir_opacidade(0.7)
	c.definir_escala(1.1)
	_ok(is_equal_approx(c.scale.x, minf(1.1, c.scale.x)) and c.scale.x <= 1.1 + 0.0001 and c.scale.x > 0.5, "a escala vale (ou encolhe para caber: %.2f)" % c.scale.x)
	var moldura: StyleBoxFlat = c.get_theme_stylebox("panel")
	_ok(is_equal_approx(moldura.bg_color.a, 0.7), "a opacidade chega ao fundo")
	c.definir_opacidade(0.01)
	_ok(is_equal_approx(float(c.aparencia.opacidade), CentralDeJanelas.OPACIDADE_MINIMA), "opacidade tem piso (%.2f)" % CentralDeJanelas.OPACIDADE_MINIMA)
	c.definir_opacidade(0.7)
	var salvo := prog.dados_de("janelas")
	_ok(salvo.get("cor") == "azul" and is_equal_approx(float(salvo.get("opacidade", 0)), 0.7) and is_equal_approx(float(salvo.get("escala", 0)), 1.1),
		"gravado no progresso")
	var volta := ProgressaoDoPersonagem.de_dict(JSON.parse_string(JSON.stringify(prog.para_dict())))
	_ok(volta.dados_de("janelas").get("cor") == "azul", "sobrevive ao salvar/carregar")
	c.restaurar_aparencia()
	_ok(c.aparencia.cor == "dourado" and is_equal_approx(float(c.aparencia.opacidade), 0.96) and is_equal_approx(float(c.aparencia.escala), 1.0),
		"Padrão restaura")
	# Uma central nova, ligada ao progresso salvo com azul, nasce azul.
	c.definir_cor("verde")
	var outra := CentralDeJanelas.new()
	root.add_child(outra)
	outra.ligar(volta)
	_ok(outra.aparencia.cor == "azul" and is_equal_approx(float(outra.aparencia.opacidade), 0.7), "central nova lê a aparência salva")
	outra.queue_free()
	await _tecla(KEY_M)

	print("\n%s" % ("TUDO CERTO" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	modo.mapa_forcado = ""
	modo.progresso_forcado = ""
	quit(1 if _falhas else 0)
