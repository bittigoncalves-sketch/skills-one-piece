extends SceneTree
# ============================================================================
#  CLIPES DO BUILDER × ORIGINAL DO MIXAMO — fotos com GPU (07/10/2026). Não conserta.
#
#    DISPLAY=:1 "$(./find_godot.sh)" --fixed-fps 60 --path . --script tools/dev_tests/capturar_clipes_x_mixamo.gd -- <pasta> [clipe ...]
#
#  Em cada quadro: à ESQUERDA o esqueleto do .glb do Mixamo (palitos), à DIREITA o
#  Base tocando o .res como a prévia do editor toca (`arena_preview._aplicar_clipe`:
#  clipe + giro e altura do Corpo), com os mesmos palitos
#  por cima. Lado ESQUERDO do corpo em azul, DIREITO em laranja, coluna em branco.
#  Sai um PNG por clipe (5 instantes lado a lado) e a folha `clipes_x_mixamo.png`.
# ============================================================================

const Clipes := preload("res://src/skills_builder/clipes_de_skill.gd")
const AZUL := Color(0.25, 0.55, 1.0)
const LARANJA := Color(1.0, 0.55, 0.15)
const BRANCO := Color(0.95, 0.95, 0.95)
## [osso A, osso B, cor] do Mixamo e [papel A, papel B, cor] do nosso rig.
const PALITOS_MIXAMO := [
	["Hips", "Spine2", BRANCO], ["Spine2", "Neck", BRANCO], ["Neck", "Head", BRANCO],
	["LeftArm", "LeftForeArm", AZUL], ["LeftForeArm", "LeftHand", AZUL],
	["RightArm", "RightForeArm", LARANJA], ["RightForeArm", "RightHand", LARANJA],
	["LeftUpLeg", "LeftLeg", AZUL], ["LeftLeg", "LeftFoot", AZUL], ["LeftFoot", "LeftToeBase", AZUL],
	["RightUpLeg", "RightLeg", LARANJA], ["RightLeg", "RightFoot", LARANJA], ["RightFoot", "RightToeBase", LARANJA],
	["LeftArm", "RightArm", BRANCO], ["LeftUpLeg", "RightUpLeg", BRANCO],
]
const PALITOS_RIG := [
	["Torso", "Head", BRANCO],
	["UpperArm_L", "ForeArm_L", AZUL], ["ForeArm_L", "#mao_L", AZUL],
	["UpperArm_R", "ForeArm_R", LARANJA], ["ForeArm_R", "#mao_R", LARANJA],
	["Thigh_L", "Shin_L", AZUL], ["Shin_L", "Foot_L", AZUL], ["Foot_L", "#pe_L", AZUL],
	["Thigh_R", "Shin_R", LARANJA], ["Shin_R", "Foot_R", LARANJA], ["Foot_R", "#pe_R", LARANJA],
	["UpperArm_L", "UpperArm_R", BRANCO], ["Thigh_L", "Thigh_R", BRANCO],
]
const INSTANTES := 5
const LADO := 1.0

var saida := ""
var nos: Dictionary
var rest: Dictionary
var modelo: Node3D
var palitos_rig: Array = []
var palitos_mix: Array = []
var torso_pos0: Vector3


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var lista: Array = args.slice(1) if args.size() > 1 else ["running", "punching", "boxing", "kicking", "roundhouse_kick", "uppercut_jab"]
	root.size = Vector2i(900, 700)
	var mundo := Node3D.new()
	root.add_child(mundo)
	_cenario(mundo)
	modelo = CharacterBuilder.build_character("base").node
	mundo.add_child(modelo)
	modelo.position = Vector3(-LADO, 0, 0)        # visto de frente, −X do mundo fica à DIREITA da foto
	await process_frame
	var rig := BodyScanner.scan(modelo)
	nos = rig.nodes
	rest = rig.rest
	torso_pos0 = (nos.Torso as Node3D).position
	for p in PALITOS_RIG:
		palitos_rig.append(_palito(mundo, p[2]))
	for p in PALITOS_MIXAMO:
		palitos_mix.append(_palito(mundo, p[2]))
	_rotulo(mundo, "MIXAMO (original)", Vector3(LADO, 2.05, 0))
	_rotulo(mundo, "JOGO (.res + prévia)", Vector3(-LADO, 2.05, 0))
	var titulo := _rotulo(mundo, "", Vector3(0, 2.35, 0))
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.position = Vector3(1.1, 1.4, -4.8)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.fov = 50
	cam.make_current()
	var linhas: Array[Image] = []
	for clipe: String in lista:
		var linha := await _clipe(mundo, clipe, titulo)
		if linha:
			linha.save_png(saida.path_join("clipe_%s.png" % clipe))
			linhas.append(linha)
	if not linhas.is_empty():
		var folha := Image.create(linhas[0].get_width(), linhas[0].get_height() * linhas.size(), false, linhas[0].get_format())
		for i in linhas.size():
			folha.blit_rect(linhas[i], Rect2i(Vector2i.ZERO, linhas[i].get_size()), Vector2i(0, i * linhas[0].get_height()))
		folha.save_png(saida.path_join("clipes_x_mixamo.png"))
	print("CAPTURA OK: %d clipes em %s" % [linhas.size(), saida])
	quit(0)


func _clipe(mundo: Node3D, clipe: String, titulo: Label3D) -> Image:
	var caminho := Clipes.caminho(clipe)
	if OS.has_environment("PASTA_RES"):        # um bake de teste (`bake_mixamo.gd --saida=`)
		caminho = OS.get_environment("PASTA_RES").path_join(clipe + ".res")
	var info := ProceduralAnimator._clipe(caminho)
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if not info.has("anim") or doc.append_from_file(ProjectSettings.globalize_path("res://assets/animations_glb/%s.glb" % clipe), st) != OK:
		print("  ✗ ", clipe, ": sem .res ou .glb")
		return null
	var cena: Node3D = doc.generate_scene(st)
	mundo.add_child(cena)
	cena.visible = false                       # só os palitos do original aparecem
	var skel: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = cena.find_children("*", "AnimationPlayer", true, false)[0]
	var nome_anim: String = Array(ap.get_animation_list()).filter(func(n): return n != "RESET")[0]
	ap.play(nome_anim)
	ap.pause()
	var anim: Animation = info.anim
	var escala := 0.0
	var linha: Image = null
	for k in INSTANTES:
		var t := anim.length * (k + 0.5) / INSTANTES
		titulo.text = "%s   t = %.2f s de %.2f" % [clipe, t, anim.length]
		_pose_rig(info, t)
		ap.seek(t, true)
		if escala == 0.0:
			# Pela perna (coxa + canela) POSADA, depois do seek: o repouso do .glb não
			# está na escala das poses.
			var perna_mix := _global(skel, _id(skel, "LeftUpLeg")).distance_to(_global(skel, _id(skel, "LeftLeg"))) \
				+ _global(skel, _id(skel, "LeftLeg")).distance_to(_global(skel, _id(skel, "LeftFoot")))
			var perna_rig := (nos.Thigh_L as Node3D).global_position.distance_to((nos.Shin_L as Node3D).global_position) \
				+ (nos.Shin_L as Node3D).global_position.distance_to((nos.Foot_L as Node3D).global_position)
			escala = perna_rig / maxf(perna_mix, 0.001)
			print("  %s: escala do original %.3f (perna %.3f → %.3f)" % [clipe, escala, perna_mix, perna_rig])
		_pose_mixamo(skel, escala)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.resize(450, 350, Image.INTERPOLATE_BILINEAR)
		if linha == null:
			linha = Image.create(450 * INSTANTES, 350, false, img.get_format())
		linha.blit_rect(img, Rect2i(0, 0, 450, 350), Vector2i(450 * k, 0))
	cena.queue_free()
	return linha


## Igual a `arena_preview._aplicar_clipe` com intensidade 1.
func _pose_rig(info: Dictionary, t: float) -> void:
	var anim: Animation = info.anim
	for papel in nos:
		(nos[papel] as Node3D).rotation = rest.get(papel, Vector3.ZERO)
	for papel in info.faixas:
		if nos.has(papel):
			var alvo := Quaternion.from_euler(anim.value_track_interpolate(info.faixas[papel], t))
			(nos[papel] as Node3D).quaternion = alvo
	var tronco: Node3D = nos.Torso
	if info.has("giro"):
		tronco.basis = Basis(Vector3.UP, float(anim.value_track_interpolate(info.giro, t))) * tronco.basis
	var altura := float(anim.value_track_interpolate(info.altura, t)) if info.has("altura") else 0.0
	tronco.position = torso_pos0 + Vector3(0, altura * 0.8, 0)
	for i in PALITOS_RIG.size():
		_por(palitos_rig[i], _ponto_rig(PALITOS_RIG[i][0]), _ponto_rig(PALITOS_RIG[i][1]))


## Poses locais compostas (como o baker), viradas para −Z, na escala do Base, sem o
## deslocamento horizontal do quadril (o rig não anda).
func _pose_mixamo(skel: Skeleton3D, escala: float) -> void:
	var vira := Basis(Vector3.UP, PI)
	var hips := _global(skel, _id(skel, "Hips"))
	var pe := minf(_global(skel, _id(skel, "LeftToeBase")).y, _global(skel, _id(skel, "RightToeBase")).y)
	var centro := Vector3(hips.x, pe, hips.z)
	for i in PALITOS_MIXAMO.size():
		var a := vira * ((_global(skel, _id(skel, PALITOS_MIXAMO[i][0])) - centro) * escala)
		var b := vira * ((_global(skel, _id(skel, PALITOS_MIXAMO[i][1])) - centro) * escala)
		_por(palitos_mix[i], a + Vector3(LADO, 0, 0), b + Vector3(LADO, 0, 0))


func _global(skel: Skeleton3D, i: int) -> Vector3:
	var t := skel.get_bone_pose(i)
	var p := skel.get_bone_parent(i)
	while p >= 0:
		t = skel.get_bone_pose(p) * t
		p = skel.get_bone_parent(p)
	return skel.global_transform * t.origin


func _id(skel: Skeleton3D, nome: String) -> int:
	for n in ["mixamorig_" + nome, "mixamorig:" + nome, nome]:
		var i := skel.find_bone(n)
		if i >= 0:
			return i
	push_error("osso %s não achado" % nome)
	return 0


func _ponto_rig(nome: String) -> Vector3:
	if nome.begins_with("#mao_"):
		return (nos["ForeArm_" + nome.right(1)] as Node3D).global_transform * Vector3(0, -0.36, 0.02)
	if nome.begins_with("#pe_"):
		return (nos["Foot_" + nome.right(1)] as Node3D).global_transform * Vector3(0, -0.05, -0.2)
	return (nos[nome] as Node3D).global_position


func _palito(mundo: Node3D, cor: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.022
	c.bottom_radius = 0.022
	c.height = 1.0
	c.radial_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 10
	c.material = mat
	m.mesh = c
	mundo.add_child(m)
	return m


func _por(m: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	if d.length() < 0.001:
		m.visible = false
		return
	m.visible = true
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	m.global_transform = Transform3D(Basis(x, y, x.cross(y)).scaled_local(Vector3(1, d.length(), 1)), (a + b) * 0.5)


func _rotulo(mundo: Node3D, texto: String, onde: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 48
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = onde
	mundo.add_child(l)
	return l


func _cenario(mundo: Node3D) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.2, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	mundo.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 150, 0)
	mundo.add_child(sol)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(6, 4)
	chao.mesh = plano
	mundo.add_child(chao)
