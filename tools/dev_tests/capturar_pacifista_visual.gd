extends SceneTree
## Captura deterministica das fases visuais do Pacifista.
## Execute com renderizacao real:
## DISPLAY=:1 godot --path . --resolution 1286x730 -s tools/dev_tests/capturar_pacifista_visual.gd

const SAIDA := "/tmp/skills-one-piece-pacifista-visual"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(SAIDA)
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame
	var p: Node3D
	for no in get_nodes_in_group("player"):
		if no.is_multiplayer_authority():
			p = no
			break
	var alvo: Node3D
	for no in get_nodes_in_group("enemy"):
		if no is Node3D and no.has_method("take_damage"):
			alvo = no
			break
	if p == null or alvo == null:
		print("FALHA: jogador ou alvo ausente")
		quit(1)
		return
	p.set_fighting_style("pacifista")
	p.energy = p.max_energy
	alvo.set_physics_process(false)
	await physics_frame

	_zerar(p, "Z")
	p.begin_charge("Z")
	await _quadros(24)
	await _capturar("z_sustentado.png")
	p.release_charge("Z")
	await _quadros(90)

	# O alvo fica fora do alcance nesta captura para não esconder os braços com
	# números/partículas de dano; o teste funcional mede o alcance separadamente.
	_colocar_alvo_na_mira(p, alvo, 7.0)
	await physics_frame
	_zerar(p, "X")
	p.begin_charge("X")
	p.release_charge("X")
	await _quadros(28)
	await _capturar("x_sobreposicao.png")
	await _quadros(120)

	# Volta o alvo para média distância antes da ultimate.
	_colocar_alvo_na_mira(p, alvo, 8.0)
	await physics_frame
	_zerar(p, "V")
	p.begin_charge("V")
	p.release_charge("V")
	var tri := await _esperar_tri_beam(120)
	if tri == null:
		print("FALHA: controlador do V não nasceu")
		quit(1)
		return
	# Espera o estado, não um frame chutado: a ultimate ativa slow-motion e o
	# delta de jogo deixa de corresponder a N quadros de parede.
	while is_instance_valid(tri) and not tri._disparou \
			and tri._tempo < PXTriBeam.TEMPO_CARGA * 0.78:
		await physics_frame
	await _capturar("v_carga_tres_emissores.png")
	while is_instance_valid(tri) and not tri._disparou:
		await physics_frame
	await _quadros(3)
	await _capturar("v_tres_feixes.png")
	while is_instance_valid(tri) and not tri._ocultou_feixes:
		await physics_frame
	await _quadros(2)
	await _capturar("v_impacto.png")

	print("capturas salvas em %s" % SAIDA)
	quit(0)


func _zerar(p: Node, slot: String) -> void:
	p._skill_cooldowns[slot] = 0.0
	if p.get("_style_cooldowns") != null:
		p._style_cooldowns[slot] = 0.0


## Mantém o alvo no mesmo pixel da retícula. A câmera em 3ª pessoa fica no
## ombro direito; posicioná-lo a partir do corpo introduziria paralaxe e faria
## uma skill correta parecer deslocada na captura.
func _colocar_alvo_na_mira(p: Node3D, alvo: Node3D, distancia: float) -> void:
	var cam := p.get("_cam") as Camera3D
	if cam == null:
		return
	var frente := (-cam.global_basis.z).normalized()
	var ate_jogador := maxf((p.global_position - cam.global_position).dot(frente), 0.0)
	alvo.global_position = cam.global_position + frente * (ate_jogador + distancia)
	if alvo is CharacterBody3D:
		(alvo as CharacterBody3D).velocity = Vector3.ZERO


func _esperar_tri_beam(max_quadros: int) -> PXTriBeam:
	for i in max_quadros:
		var achado := _achar_tri_beam(current_scene)
		if achado != null and not achado._cargas.is_empty():
			return achado
		await physics_frame
	return null


func _achar_tri_beam(no: Node) -> PXTriBeam:
	if no is PXTriBeam:
		return no as PXTriBeam
	for filho in no.get_children():
		var achado := _achar_tri_beam(filho)
		if achado != null:
			return achado
	return null


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _capturar(nome: String) -> void:
	await process_frame
	await process_frame
	var imagem := get_root().get_texture().get_image()
	var erro := imagem.save_png(SAIDA.path_join(nome))
	print("%s %s" % ["OK" if erro == OK else "FALHA", nome])
