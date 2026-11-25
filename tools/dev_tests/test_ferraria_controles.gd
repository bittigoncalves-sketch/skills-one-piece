extends SceneTree
var falhas := 0
var total := 0

func _init() -> void: rodar.call_deferred()
func ok(condicao: bool, texto: String) -> void:
	total += 1
	if not condicao: falhas += 1
	print(("OK " if condicao else "FALHA ") + texto)

func tecla(codigo: Key, fisica := false, eco := false) -> void:
	var e := InputEventKey.new()
	if fisica: e.physical_keycode = codigo
	else: e.keycode = codigo
	e.pressed = true
	e.echo = eco
	Input.parse_input_event(e)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)

func rodar() -> void:
	await process_frame
	var f := preload("res://src/ui/FerrariaHud.gd").new()
	root.add_child(f)
	f.set_process(false)
	var velocidade := f.velocidade_do_marcador()
	f.tempo = 0.25 / velocidade
	var baixa := f.posicao_do_marcador()
	f.tempo = 0.75 / velocidade
	ok(f.posicao_do_marcador() > baixa, "marcador sobe")
	f.tempo = 1.75 / velocidade
	ok(is_equal_approx(f.posicao_do_marcador(), baixa), "marcador desce sem saltar no topo")
	f.tempo = 0
	tecla(KEY_SPACE)
	ok(f.falhas == 1 and f.acertos == 0, "espaço fora do verde penaliza")
	var largura := f.zona_de_acerto().y - f.zona_de_acerto().x
	f.dificuldade = 2
	ok(f.velocidade_do_marcador() > velocidade and f.zona_de_acerto().y - f.zona_de_acerto().x < largura, "dificuldade acelera e estreita a zona")
	f.dificuldade = 1
	for i in 3:
		f.tempo = 0.5 / f.velocidade_do_marcador()
		tecla(KEY_SPACE, true)
	ok(f.etapa == 1, "espaço físico aquece em três acertos distintos")
	f.get("_alvos").get_child(0).focus_mode = Control.FOCUS_ALL
	f.get("_alvos").get_child(0).grab_focus()
	tecla(KEY_1)
	ok(f.acertos == 0, "tecla no ponto errado não avança mesmo com foco")
	tecla(KEY_2, true, true)
	ok(f.acertos == 0, "repetição automática não conta martelada")
	for i in f.ORDEM.size():
		var codigo: Key = (KEY_KP_1 if i % 2 == 0 else KEY_1) + f.ORDEM[i]
		tecla(codigo, i % 2 != 0)
		ok(f.get("_bancada").get("_ponto_do_impacto") == f.ORDEM[i], "impacto fica no ponto martelado %d" % (f.ORDEM[i] + 1))
	ok(f.etapa == 2, "1–4 físicos e teclado numérico completam a bigorna")
	ok(f.velocidade_do_marcador() > velocidade and f.zona_de_acerto().y - f.zona_de_acerto().x < largura, "resfriamento mais exigente que fornalha")
	for i in 3:
		f.tempo = 0.5 / f.velocidade_do_marcador()
		tecla(KEY_SPACE)
		if i == 0:
			tecla(KEY_SPACE)
			ok(f.acertos == 1, "spam na mesma janela não duplica acertos")
	ok(f.etapa == 3 and not f.ativa, "teclado completa as três etapas")
	tecla(KEY_ENTER)
	ok(f.etapa == 3 and not f.ativa, "enter após conclusão não reabre a recompensa")
	f.free()
	f = preload("res://src/ui/FerrariaHud.gd").new()
	root.add_child(f)
	f.set_process(false)
	for i in 3:
		f.tempo = 0.5 / f.velocidade_do_marcador(); f.acionar()
	f.restante = 2
	tecla(KEY_1)
	ok(not f.ativa and f.restante == 0, "penalidade esgota imediatamente")
	tecla(KEY_2)
	ok(f.acertos == 0, "martelada após falha não avança")
	tecla(KEY_ENTER)
	ok(f.ativa and f.etapa == 0 and f.falhas == 0, "enter reinicia depois de falhar")
	f.hide()
	f.tempo = 0.5 / f.velocidade_do_marcador()
	tecla(KEY_SPACE)
	ok(f.acertos == 0, "janela oculta não intercepta teclas")
	f.free()
	print("FERRARIA: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
