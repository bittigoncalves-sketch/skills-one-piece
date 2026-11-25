extends SceneTree
# ============================================================================
#  TESTE — pincel de relevo do editor de mapa (01/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_pincel_relevo.gd
#
#  Mapa em memória: 2×2 blocos de 16 m (mesma base −1,5 e mesmo Y, como os da ilha),
#  uma caixa pousada e o spawn. Nada é gravado em disco (a parte do editor usa
#  `user://test_pincel/`).
# ============================================================================

var _falhas := 0
const BASE := -1.5
const Y := 10.0
const N := 8


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	_elevar_e_emenda()
	_aplainar_e_pintar()
	_crescer()
	_pecas_acompanham()
	await _no_editor()
	print("\nPINCEL_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


## Chão plano a 1,5 m acima da base (y = 0 no mundo): fração 1500 de 10 m.
func _doc() -> DocumentoMapa:
	var pecas: Array[Dictionary] = []
	for tj in 2:
		for ti in 2:
			var r := TerrenoDoMapa.plano(N, 1500)
			pecas.append({"id": "b_%d_%d" % [ti, tj], "tipo": "terreno", "grupo": "",
				"posicao": Vector3(-8 + ti * 16, BASE + Y * 0.5, -8 + tj * 16), "rotacao_graus": Vector3.ZERO,
				"tamanho": Vector3(16, Y, 16), "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0,
				"colisao": true, "relevo": r})
	pecas.append({"id": "caixote", "tipo": "caixa", "grupo": "", "posicao": Vector3(2, 0.5, 2),
		"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(1, 1, 1), "cor": Color.RED, "material": "liso",
		"grade_celula": 4.0, "colisao": true})
	pecas.append({"id": "longe", "tipo": "caixa", "grupo": "", "posicao": Vector3(-14, 0.5, -14),
		"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(1, 1, 1), "cor": Color.RED, "material": "liso",
		"grade_celula": 4.0, "colisao": true})
	return DocumentoMapa.de_mapa({"nome": "t", "spawn": {"posicao": Vector3(1, 1.5, 0)}, "pecas": pecas, "grupos": []})


## Alturas de todos os pontos de borda, por posição de mundo (mm), em cada bloco.
func _emenda_pior(doc: DocumentoMapa) -> float:
	var pontos := {}
	for id in doc.ids():
		var p := doc.peca(id)
		if p["tipo"] != "terreno":
			continue
		var g := TerrenoDoMapa._grade(p["relevo"], p["tamanho"])
		for k in g.size():
			var v: Vector3 = g[k] + (p["posicao"] as Vector3)
			var chave := Vector2i(roundi(v.x * 1000), roundi(v.z * 1000))
			if not pontos.has(chave):
				pontos[chave] = []
			pontos[chave].append(v.y)
	var pior := 0.0
	for c in pontos:
		for y in pontos[c]:
			pior = maxf(pior, absf(float(y) - float(pontos[c][0])))
	return pior


func _elevar_e_emenda() -> void:
	print("\n-- A. elevar / abaixar --")
	var doc := _doc()
	var pincel := PincelDeRelevo.new()
	pincel.raio = 6.0
	pincel.forca = 1.0
	# No canto comum dos 4 blocos: a pincelada pega os quatro.
	var mudados := pincel.aplicar(doc, Vector3(0, 0, 0), 0.5)
	var centro := PincelDeRelevo.chao(doc, Vector2(0, 0))
	var borda := PincelDeRelevo.chao(doc, Vector2(5.5, 0))
	var fora := PincelDeRelevo.chao(doc, Vector2(7.5, 0))
	_ok(mudados.size() >= 4, "a pincelada no canto comum muda os 4 blocos (%d)" % mudados.size())
	_ok(absf(centro - 3.0) < 0.01, "o centro sobe VELOCIDADE × força × tempo = 3 m (%.3f)" % centro)
	_ok(borda > 0.0 and borda < 0.5, "a borda do pincel sobe pouco, sem quina (%.3f)" % borda)
	_ok(absf(fora) < 0.002, "fora do raio nada muda (%.4f)" % fora)
	_ok(_emenda_pior(doc) == 0.0, "emendas entre os 4 blocos continuam exatas (%.6f)" % _emenda_pior(doc))
	pincel.aplicar(doc, Vector3(0, 0, 0), 0.25, true)
	_ok(absf(PincelDeRelevo.chao(doc, Vector2(0, 0)) - 1.5) < 0.01, "Shift abaixa (3 m − 1,5 m = %.3f)" % PincelDeRelevo.chao(doc, Vector2(0, 0)))
	for i in 20:
		pincel.aplicar(doc, Vector3(0, 0, 0), 0.5, true)
	_ok(absf(PincelDeRelevo.chao(doc, Vector2(0, 0)) - BASE) < 0.01, "não afunda abaixo da base dos blocos (%.3f)" % PincelDeRelevo.chao(doc, Vector2(0, 0)))


func _aplainar_e_pintar() -> void:
	print("\n-- B. aplainar e pintar --")
	var doc := _doc()
	var pincel := PincelDeRelevo.new()
	pincel.raio = 6.0
	pincel.forca = 1.0
	pincel.aplicar(doc, Vector3(3, 0, 3), 0.4)                 # um morro
	pincel.modo = PincelDeRelevo.Modo.APLAINAR
	for i in 30:
		pincel.aplicar(doc, Vector3(3, 0, 3), 0.1, false, 0.8)  # nivela em 0,8 m
	var pior := 0.0
	for p in [Vector2(3, 3), Vector2(4, 2), Vector2(2, 4.5)]:
		pior = maxf(pior, absf(PincelDeRelevo.chao(doc, p) - 0.8))
	_ok(pior < 0.05, "aplainar leva o miolo à altura do começo da pincelada (erro %.3f)" % pior)
	_ok(_emenda_pior(doc) == 0.0, "emendas exatas depois de aplainar")
	pincel.modo = PincelDeRelevo.Modo.PINTAR
	pincel.solo = 2      # terra
	pincel.raio = 3.0
	pincel.aplicar(doc, Vector3(4, 0, 4), 0.1)
	var r: Dictionary = doc.peca("b_1_1")["relevo"]
	var solo: PackedByteArray = r["solo"]
	var dentro := solo[(4 / 2) * N + (4 / 2)]       # célula do centro (4,4) no bloco b_1_1
	var fora_do_raio := solo[(N - 1) * N + (N - 1)]
	_ok(dentro == 2 and fora_do_raio == 0, "pintar põe terra dentro do raio (%d) e não fora (%d)" % [dentro, fora_do_raio])


func _crescer() -> void:
	print("\n-- C. passar do topo: todos os blocos crescem juntos --")
	var doc := _doc()
	var pincel := PincelDeRelevo.new()
	pincel.raio = 6.0
	pincel.forca = 1.0
	var antes_longe := PincelDeRelevo.chao(doc, Vector2(-12, -12))
	for i in 6:
		pincel.aplicar(doc, Vector3(0, 0, 0), 0.5)          # +3 m por vez, 18 m > topo (8,5)
	var ys := {}
	for id in doc.ids():
		var p := doc.peca(id)
		if p["tipo"] == "terreno":
			ys[snappedf((p["tamanho"] as Vector3).y, 0.001)] = true
			ys["base%.3f" % PincelDeRelevo._base(p)] = true
	var topo := PincelDeRelevo.chao(doc, Vector2(0, 0))
	_ok(absf(topo - 18.0) < 0.05, "o morro passou do topo antigo e chegou a %.2f m" % topo)
	_ok(ys.size() == 2, "os 4 blocos com o MESMO Y novo e a mesma base (%s)" % str(ys.keys()))
	_ok(absf(PincelDeRelevo.chao(doc, Vector2(-12, -12)) - antes_longe) < 0.005, "longe do pincel a altura não mudou com o crescimento")
	_ok(_emenda_pior(doc) == 0.0, "emendas exatas depois de crescer")


func _pecas_acompanham() -> void:
	print("\n-- D. peças pousadas acompanham o chão --")
	var doc := _doc()
	var hist := HistoricoDeEdicao.new(doc)
	var pincel := PincelDeRelevo.new()
	pincel.raio = 8.0
	pincel.forca = 1.0
	hist.iniciar("Esculpir relevo")
	pincel.aplicar(doc, Vector3(2, 0, 2), 0.3)
	pincel.aplicar(doc, Vector3(2, 0, 2), 0.3)
	hist.concluir()
	var chao := PincelDeRelevo.chao(doc, Vector2(2, 2))
	var caixa: Vector3 = doc.peca("caixote")["posicao"]
	_ok(absf((caixa.y - 0.5) - chao) < 0.01, "a caixa pousada subiu junto (fundo %.3f, chão %.3f)" % [caixa.y - 0.5, chao])
	_ok(is_equal_approx((doc.peca("longe")["posicao"] as Vector3).y, 0.5), "a peça fora do pincel ficou onde estava")
	_ok(doc.spawn.y > 1.5 + 0.5, "o spawn dentro do pincel também acompanhou (%.2f)" % doc.spawn.y)
	_ok(hist.tamanho() == 1, "a pincelada inteira é UM passo de desfazer (%d)" % hist.tamanho())
	hist.desfazer()
	_ok(absf(PincelDeRelevo.chao(doc, Vector2(2, 2))) < 0.002 and is_equal_approx((doc.peca("caixote")["posicao"] as Vector3).y, 0.5),
		"desfazer devolve chão e caixa")
	hist.refazer()
	_ok(absf(PincelDeRelevo.chao(doc, Vector2(2, 2)) - chao) < 0.002, "refazer reaplica")


# ------------------------------------------------------------- E. no editor
func _no_editor() -> void:
	print("\n-- E. no editor: ferramenta Relevo (Ctrl+5), cursor e pincelada com o mouse --")
	var pasta := "user://test_pincel"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var caminho := pasta.path_join("mapa.json")
	MapaArquivo.salvar(caminho, _doc().para_mapa())
	var ed: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	ed.caminho_do_mapa = caminho
	root.add_child(ed)
	current_scene = ed
	for i in 8:
		await process_frame
	var cam: CameraLivre = ed._camera
	cam.posicionar(Vector3(0, 20, 18), Vector3(0, 0, 0))
	for i in 3:
		await physics_frame
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_5
	tecla.physical_keycode = KEY_5
	tecla.ctrl_pressed = true
	tecla.pressed = true
	root.push_input(tecla, true)
	await process_frame
	_ok(ed.ferramenta == GizmoDoEditor.Ferramenta.RELEVO and ed._painel_do_pincel.visible, "Ctrl+5 liga o pincel e mostra o painel")
	var alvo := cam.unproject_position(Vector3(0, 0, 0))
	var mov := InputEventMouseMotion.new()
	mov.position = alvo
	root.push_input(mov, true)
	await process_frame
	await process_frame
	_ok(ed._vista.cursor_do_pincel_visivel(), "o círculo do pincel aparece sobre o relevo")
	var raio_antes: float = ed.pincel.raio
	var colchete := InputEventKey.new()
	colchete.keycode = KEY_BRACKETRIGHT
	colchete.physical_keycode = KEY_BRACKETRIGHT
	colchete.pressed = true
	root.push_input(colchete, true)
	await process_frame
	_ok(ed.pincel.raio > raio_antes, "] aumenta o raio (%.1f → %.1f)" % [raio_antes, ed.pincel.raio])
	var passos_antes: int = ed.historico.tamanho()
	var aperta := InputEventMouseButton.new()
	aperta.button_index = MOUSE_BUTTON_LEFT
	aperta.position = alvo
	aperta.pressed = true
	root.push_input(aperta, true)
	for i in 30:
		await process_frame
	var solta := aperta.duplicate() as InputEventMouseButton
	solta.pressed = false
	root.push_input(solta, true)
	await process_frame
	var subiu := PincelDeRelevo.chao(ed.doc, Vector2(0, 0))
	_ok(subiu > 0.3, "segurar o botão ergue o chão sob o cursor (%.2f m)" % subiu)
	_ok(ed.historico.tamanho() == passos_antes + 1, "a pincelada virou um passo de desfazer")
	_ok(ed.selecao.vazia(), "pincelar não seleciona peça")
	ed.desfazer()
	_ok(absf(PincelDeRelevo.chao(ed.doc, Vector2(0, 0))) < 0.002, "Ctrl+Z desfaz a pincelada")
	ed.queue_free()
	for i in 2:
		await process_frame
