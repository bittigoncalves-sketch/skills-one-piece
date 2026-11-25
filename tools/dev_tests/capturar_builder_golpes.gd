extends SceneTree
# ============================================================================
#  O EDITOR (Skills Builder) TOCANDO GOLPES DEPOIS DO REBAKE v3 — fotos com GPU (07/10/2026).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --fixed-fps 60 --path . --script tools/dev_tests/capturar_builder_golpes.gd -- <pasta>
#
#  Relato do dono: "as animações do skill builder continuam a aparentar estarem bugadas,
#  além de em grande parte ficarem muito parecidas". Para cada clipe, um bloco Animação
#  do tamanho do clipe e a prévia em 3 instantes (25 %, 50 %, 75 %). Recorte da arena
#  (boneco e alvo) ampliado, numa folha `builder_golpes.png` (linha = clipe).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const CLIPES := ["punching", "kicking", "roundhouse_kick", "uppercut_jab", "flying_kick", "armada"]
const FRACOES := [0.25, 0.5, 0.75]
## Região da arena (janela 1600×900) onde ficam o Base e o alvo.
const RECORTE := Rect2i(560, 140, 400, 240)

var saida := ""


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	saida = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1600, 900)
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(60)
	var ed := current_scene
	var folha: Image = null
	for c in CLIPES.size():
		var clipe: String = CLIPES[c]
		var dur := (load("res://assets/animations/%s.res" % clipe) as Animation).length
		var s := Dados.novo()
		s.identificacao.id = "golpe_" + clipe
		s.identificacao.nome = clipe
		s.configuracoes.duracao = dur
		s.eventos = [{"id": "golpe", "tipo": "animacao", "inicio": 0.0, "duracao": dur, "habilitado": true,
			"parametros": {"clipe": clipe, "velocidade": 1.0, "intensidade": 1.0}}]
		ed.call("_documento", s)
		await _quadros(10)
		ed.call("selecionar_evento", "golpe")
		for k in FRACOES.size():
			(ed.get("arena") as Node).call("buscar", dur * FRACOES[k])
			await _quadros(8)
			await RenderingServer.frame_post_draw
			# Recorte da arena em volta do boneco (a janela inteira deixa a pose pequena demais).
			var img := root.get_texture().get_image().get_region(RECORTE)
			img.resize(RECORTE.size.x * 3 / 2, RECORTE.size.y * 3 / 2, Image.INTERPOLATE_BILINEAR)
			var w := img.get_width()
			var h := img.get_height()
			if folha == null:
				folha = Image.create(w * FRACOES.size(), h * CLIPES.size(), false, img.get_format())
			folha.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(w * k, h * c))
	folha.save_png(saida.path_join("builder_golpes.png"))
	print("CAPTURA OK: ", saida.path_join("builder_golpes.png"))
	quit(0)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
