extends SceneTree
# ============================================================================
#  DIREÇÃO DOS BRAÇOS — escalada, borda, subida, wall run e nado (03/10/2026).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/medir_direcao_bracos.gd -- <pasta_das_fotos>
#
#  Relato do dono: "escala com as mãos para trás — houve uma inversão na direção";
#  o mesmo no nado. Convenção do rig (ProceduralAnimator, silhueta de sprint):
#  +X no UpperArm leva o braço para −Z (FRENTE); −X para +Z (costas).
#
#  Dirige o animador direto (como `tools/nado_montaria_preview.gd`), com o modelo
#  olhando para −Z, e mede a mão em relação ao OMBRO no espaço do modelo:
#  `frente` > 0 = mão à frente do ombro; `cima` > 0 = acima dele. Tira fotos de
#  lado para conferir a olho.
# ============================================================================

var j: CharacterBody3D
var camera: Camera3D
var saida := ""
var _ok_n := 0
var _falhas := 0


func _initialize() -> void:
	rodar.call_deferred()


func rodar() -> void:
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else ""
	var com_tela := DisplayServer.get_name() != "headless"
	root.size = Vector2i(900, 700)
	var mundo := Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	var modo: GDScript = load("res://src/historia/ModoHistoria.gd")
	j = modo.colocar_civil(mundo, 2, Vector3(0, .85, 0))
	j.set_physics_process(false)
	j.set_process(false)
	await process_frame
	j._char_model.rotation = Vector3.ZERO
	camera = Camera3D.new()
	mundo.add_child(camera)
	camera.fov = 40
	camera.make_current()
	var anim: Node = j._proc_anim
	var dt := 1.0 / 60.0

	# ESCALADA (escada): subindo a 2,2 m/s.
	var esc := await _amostrar(anim, func(): anim.update(Vector3(0, 2.2, 0), false, true, dt, 0.0), 120)
	_relatar("escalada", esc)
	_ok("escalada: as mãos vão à FRENTE (para a parede) — média %.2f m" % esc["frente_media"], esc["frente_media"] > 0.12)
	_ok("escalada: no alto do alcance a mão passa da cabeça (%.2f m acima do ombro)" % esc["cima_max"], esc["cima_max"] > 0.35)
	await _foto("escalada", com_tela)

	# PENDURADO NA BORDA.
	var borda := await _amostrar(anim, func(): anim.update(Vector3.ZERO, false, false, dt, 0.0, false, false, "", "borda"), 60)
	_relatar("borda", borda)
	_ok("borda: mãos acima e à frente (frente %.2f, cima %.2f)" % [borda["frente_media"], borda["cima_media"]], borda["frente_media"] > 0.05 and borda["cima_media"] > 0.35)
	await _foto("borda", com_tela)

	# SUBINDO A BORDA (meio da puxada: progresso 0,4).
	anim.subida_borda = 0.4
	var sub := await _amostrar(anim, func(): anim.update(Vector3(0, 3.6, 0), false, false, dt, 0.0, false, false, "", "subindo_borda"), 60)
	_relatar("subida", sub)
	_ok("subida: mãos à frente do ombro, empurrando a borda (frente %.2f)" % sub["frente_media"], sub["frente_media"] > 0.0)
	await _foto("subida", com_tela)
	anim.subida_borda = 0.0

	# WALL RUN com a parede à DIREITA (mão direita apoia).
	anim.parede_lado = 1
	var wr := await _amostrar(anim, func(): anim.update(Vector3(0, 0, -4.0), false, false, dt, 0.0, false, false, "", "wall_run"), 60, "R")
	_relatar("wall run (mão da parede)", wr)
	_ok("wall run: a mão da parede vai um pouco à FRENTE do ombro (%.2f m)" % wr["frente_media"], wr["frente_media"] > -0.02)
	await _foto("wall_run", com_tela)
	anim.parede_lado = 0

	# NADO (crawl): a mão deve ENTRAR à frente da cabeça e a puxada levá-la para trás.
	j.modo_na_agua = "nadando"
	for i in 60:
		anim.update(Vector3(0, 0, -2.6), false, false, dt, 0.0)
	var nado := await _amostrar(anim, func(): anim.update(Vector3(0, 0, -2.6), false, false, dt, 0.0), 180)
	_relatar("nado", nado)
	var cabeca := _local(anim._n.Head)
	var ombro := _local(anim._n.UpperArm_L)
	_ok("nado: no alcance máximo a mão passa da CABEÇA para a frente (mão %.2f m à frente do ombro; cabeça %.2f)" % [nado["frente_max"], -(cabeca.z - ombro.z)], nado["frente_max"] > -(cabeca.z - ombro.z) + 0.1)
	_ok("nado: a braçada vai à frente E volta atrás do ombro (%.2f → %.2f m)" % [nado["frente_min"], nado["frente_max"]], nado["frente_min"] < 0.0 and nado["frente_max"] > 0.3)
	await _foto("nado", com_tela)
	# Sequência do ciclo (≈ 1 ciclo a 4,8 rad/s ≈ 78 quadros): 8 fotos.
	for k in 8:
		for i in 10:
			anim.update(Vector3(0, 0, -2.6), false, false, dt, 0.0)
		await _foto("nado_%d" % k, com_tela)
	j.modo_na_agua = ""

	print("\nDIRECAO_BRACOS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## Roda `passo` `n` quadros e mede a mão (L, ou `lado`) contra o ombro.
func _amostrar(anim: Node, passo: Callable, n: int, lado := "L") -> Dictionary:
	var fs := []
	var cs := []
	for i in n:
		passo.call()
		await process_frame
		var mao := _local(anim._n["Hand_" + lado])
		var ombro := _local(anim._n["UpperArm_" + lado])
		fs.append(-(mao.z - ombro.z))       # frente do modelo = −Z
		cs.append(mao.y - ombro.y)
	var soma_f := 0.0
	var soma_c := 0.0
	for v in fs: soma_f += v
	for v in cs: soma_c += v
	return {"frente_media": soma_f / n, "frente_max": fs.max(), "frente_min": fs.min(),
		"cima_media": soma_c / n, "cima_max": cs.max()}


## Posição no espaço do MODELO, em metros (desfaz a escala do modelo).
func _local(n: Node3D) -> Vector3:
	var m: Transform3D = j._char_model.global_transform
	var escala: float = m.basis.get_scale().x
	return (m.affine_inverse() * n.global_position) * escala


func _relatar(nome: String, d: Dictionary) -> void:
	print("   %-24s frente média %+.2f (min %+.2f, max %+.2f) | cima média %+.2f (max %+.2f)" % [
		nome, d["frente_media"], d["frente_min"], d["frente_max"], d["cima_media"], d["cima_max"]])


func _foto(nome: String, com_tela: bool) -> void:
	if not com_tela or saida.is_empty():
		return
	# De lado (+X), o modelo olhando para −Z: a FRENTE dele fica à DIREITA da foto
	# (a direita da câmera, olhando para −X, é −Z).
	camera.position = j.global_position + Vector3(3.2, 0.9, 0)
	camera.look_at(j.global_position + Vector3(0, 0.6, 0))
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
