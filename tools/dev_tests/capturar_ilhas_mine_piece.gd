extends SceneTree
## Capturas das ilhas das estruturas do Mine Piece (18/10/2026): por ilha, vista aérea,
## a construção principal e cada navio ancorado (do mar, à altura do convés).
##   "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_ilhas_mine_piece.gd [-- --mapa=<arq> --so=<ilha>]
## Sem `--mapa`, o mapa vivo. Saída: art_src/validation/ilhas_mine_piece/<ilha>_*.png

const Gerador := preload("res://tools/mapa_ilha/gerar_ilhas_mine_piece.gd")
const PASTA := "res://art_src/validation/ilhas_mine_piece"


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await physics_frame


func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var so := ""
	var modo = load("res://src/historia/ModoHistoria.gd")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mapa="):
			modo.set("mapa_forcado", a.trim_prefix("--mapa="))
		elif a.begins_with("--so="):
			so = a.trim_prefix("--so=")
	modo.set("progresso_forcado", "user://capturar_ilhas_mine_piece.json")
	root.get_node("GameFlow").start_story()
	await frames(300)
	var p: Node3D = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	cam.far = 2500.0
	for id in Gerador.ILHAS:
		if not so.is_empty() and id != so:
			continue
		var d: Dictionary = Gerador.ILHAS[id]
		var c := Vector3(d["centro"].x, 0, d["centro"].y)
		var meia: float = d["meia"]
		# O jogador na água a oeste: a ilha fica PERTO para o desenho por distância.
		p.global_position = c + Vector3(-meia - 50.0, 2.0, 0)
		await frames(40)
		cam.global_position = c + Vector3(0, meia * 1.5, meia * 1.35)
		cam.look_at(c)
		await _foto(id + "_aerea")
		# A construção principal (a maior: o gerador distribui as maiores primeiro).
		var e := current_scene.find_child("%s%s_estrutura_0" % [Gerador.PREFIXO, id], true, false) as Node3D
		var alvo := e.global_position + Vector3(0, 4.0, 0)
		var t := BibliotecaDeModelos.padrao().tamanho_padrao(str(e.get_node("Modelo").get_meta("modelo_id")))
		var r := maxf(t.x, t.z)
		cam.global_position = alvo + Vector3(-r * 0.7, r * 0.45 + 4.0, r * 0.9)
		cam.look_at(alvo)
		await _foto(id + "_estrutura")
		var k := 0
		for no in current_scene.find_children("%s%s_navio_*" % [Gerador.PREFIXO, id], "", true, false):
			var n := no as Node3D
			if n == null or n.get_node_or_null("Modelo") == null:
				continue
			var fora := Vector3(n.global_position.x - c.x, 0, n.global_position.z - c.z).normalized()
			cam.global_position = n.global_position + fora * 55.0 + Vector3(0, 12, 0)
			cam.look_at(n.global_position + Vector3.UP * 4.0)
			await _foto("%s_navio_%d" % [id, k])
			k += 1
	# Ilhas antigas: as lojas novas e os navios ancorados.
	for id in Gerador.ANTIGAS:
		if not so.is_empty() and id != so:
			continue
		for no in current_scene.find_children("%s%s_*" % [Gerador.PREFIXO, id], "", true, false):
			var n := no as Node3D
			if n == null or n.get_node_or_null("Modelo") == null or "vendedor" in n.name:
				continue
			p.global_position = n.global_position + Vector3(-30, 3, 0)
			var raio := 30.0 if "loja" in n.name else 60.0
			cam.global_position = n.global_position + Vector3(-raio * 0.6, raio * 0.5, raio * 0.8)
			cam.look_at(n.global_position)
			await _foto(String(n.name).trim_prefix(Gerador.PREFIXO))
	modo.set("progresso_forcado", "")
	modo.set("mapa_forcado", "")
	quit()


func _foto(nome: String) -> void:
	# O desenho por distância reavalia a cada 0,5 s: antes disso a ilha ainda pode ser blocos.
	await frames(45)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [PASTA, nome])
