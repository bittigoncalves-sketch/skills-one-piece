extends SceneTree
## As estruturas do Mine Piece convertidas (`tools/mine_piece/estrutura_para_glb.py`), com uma
## cápsula do tamanho do jogador (1,6 m) ao lado, para conferir forma, textura, orientação e
## escala (18/10/2026). Segunda imagem: só a malha `Colisao`, em magenta.
##   "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_estruturas_mine_piece.gd -- <arquivo.glb> ...
## Saída: art_src/validation/estruturas_mine_piece/<nome>_{visual,colisao}.png

const PASTA := "res://art_src/validation/estruturas_mine_piece"

func _init() -> void: _rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1400, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	for caminho in OS.get_cmdline_user_args():
		await _capturar(caminho)
	quit()


func _capturar(caminho: String) -> void:
	var cena := Node3D.new()
	root.add_child(cena)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.background_mode = Environment.BG_COLOR
	amb.environment.background_color = Color(0.55, 0.7, 0.85)
	amb.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	cena.add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.shadow_enabled = true
	cena.add_child(sol)
	var modelo := BibliotecaDeModelos.carregar_glb(caminho)
	if modelo == null:
		push_error("não abriu: " + caminho)
		cena.free()
		return
	cena.add_child(modelo)
	var caixa := AABB()
	var colisao: MeshInstance3D = null
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).begins_with("Colisao"):
			colisao = mi
			mi.visible = false
		else:
			caixa = caixa.merge(mi.get_aabb()) if caixa.size != Vector3.ZERO else mi.get_aabb()
	var jogador := MeshInstance3D.new()
	jogador.mesh = CapsuleMesh.new()
	(jogador.mesh as CapsuleMesh).height = 1.6
	(jogador.mesh as CapsuleMesh).radius = 0.4
	var mj := StandardMaterial3D.new()
	mj.albedo_color = Color(1.0, 0.25, 0.1)
	jogador.material_override = mj
	jogador.position = Vector3(caixa.end.x + 1.0, 0.8, caixa.get_center().z)
	cena.add_child(jogador)
	var cam := Camera3D.new()
	cena.add_child(cam)
	var centro := caixa.get_center()
	var raio := caixa.size.length() * 0.62
	cam.position = centro + Vector3(1.0, 0.75, 1.15).normalized() * raio * 1.35
	cam.look_at(centro)
	cam.fov = 50
	var nome := caminho.get_file().get_basename()
	for i in 4:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s_visual.png" % [PASTA, nome])
	if colisao != null:
		# Só a colisão, sombreada: dá para ver degrau, porta aberta e o que ficou sem hitbox.
		for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
			mi.visible = mi == colisao
		var mc := StandardMaterial3D.new()
		mc.albedo_color = Color(0.85, 0.3, 0.85)
		colisao.material_override = mc
		for i in 3:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_colisao.png" % [PASTA, nome])
	cena.queue_free()
	await process_frame
