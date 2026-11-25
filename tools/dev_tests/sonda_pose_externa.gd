extends SceneTree
## Sonda: a meta `pose_externa` chega às JUNTAS reais do rig durante o X? (Codex #148: retornos antecipados no ProceduralAnimator podem pular o gancho.)
func _init() -> void:
	executar.call_deferred()

func manter() -> void:
	var p = get_first_node_in_group("player")
	if p != null and p.capacidades != null: p.capacidades.can_use_fruit = true

func executar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://ushi_sonda.json")
	root.get_node("GameFlow").start_story()
	for i in 240: await physics_frame
	var j = get_first_node_in_group("player")
	var av = McEntidade.de(j).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for cr in d.criterios: av.award(d, cr)
	var prog = current_scene.get("progressao")
	prog.fruta = "ushi_ushi_giraffe"
	prog.skills["fruta"] = maxi(1, int(prog.skills.get("fruta", 0)))
	prog.fruta_ativa = true
	prog.item_ativo = prog.NENHUM_ITEM
	modo.equipar_fruta(j, "ushi_ushi_giraffe")
	physics_frame.connect(manter)
	for i in 20: await physics_frame
	var c = j.get_node("FrutaMinePiece")
	var u = c.ushi
	j.max_energy = 5000.0
	j.energy = 5000.0
	c._sincronizar_para_o_mod()
	var raiz: Node3D = j._char_model
	var coxa: Node3D = raiz.find_child("Thigh_R", true, false)
	var torso: Node3D = raiz.find_child("Torso", true, false)
	for i in 30: await process_frame
	var rep: Basis = coxa.basis
	var rep_t: Basis = torso.basis
	print("SONDA joint Thigh_R encontrada=%s Torso=%s" % [coxa != null, torso != null])
	c.usar_tecla("X", true)
	c.usar_tecla("X", false)
	var pe_r0: Node3D = raiz.find_child("Foot_R", true, false)
	var y_min := 1e9
	var y_max := -1e9
	var d_max := 0.0
	var base_pe: Vector3 = pe_r0.global_position
	var max_dif := 0.0
	var max_dif_t := 0.0
	var tmax := 0.0
	for i in 90:
		await physics_frame
		await process_frame
		var dif := (coxa.basis.get_euler() - rep.get_euler()).length()
		if dif > max_dif:
			max_dif = dif
			tmax = u.tempo
		max_dif_t = maxf(max_dif_t, (torso.basis.get_euler() - rep_t.get_euler()).length())
		y_min = minf(y_min, pe_r0.global_position.y)
		y_max = maxf(y_max, pe_r0.global_position.y)
		d_max = maxf(d_max, (pe_r0.global_position - base_pe).length())
	print("SONDA X: maior desvio da junta Thigh_R vs repouso = %.2f rad (em t=%.2f s); Torso %.2f rad; meta pedida pico coxa %.2f rad" % [max_dif, tmax, max_dif_t, (UshiChute.pose_x(0.34).Thigh_R as Vector3).length()])
	print("SONDA pé D: y de %.2f a %.2f m (chão ~%.2f), deslocamento máximo %.2f m; char_model.y=%.2f" % [y_min, y_max, base_pe.y, d_max, raiz.position.y])
	var pe_r: Node3D = raiz.find_child("Foot_R", true, false)
	print("SONDA pé D existe=%s" % (pe_r != null))
	quit(0)
