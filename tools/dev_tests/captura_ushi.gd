extends SceneTree
## Capturas e medição de quadro da Ushi Ushi com render REAL (precisa de display: Xephyr/X11; não roda em --headless).
##   Xephyr :77 -screen 1024x700 -ac &   DISPLAY=:77 godot --display-driver x11 --rendering-method gl_compatibility --path . --script tools/dev_tests/captura_ushi.gd
const PASTA := "res://art_src/validation/ushi_ushi/"
var j
var c
var u

class Alvo extends Node3D:
	var health := 1e9
	func _ready() -> void:
		add_to_group(AlvosDeGolpe.GRUPO)
		var m := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.7
		m.mesh = cap
		m.position.y = 0.0
		add_child(m)
	func take_damage(_d: float, _o: Vector3, _i: Vector3, _s: float) -> void:
		pass

func _init() -> void:
	executar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		var p = get_first_node_in_group("player")
		if p != null and p.capacidades != null: p.capacidades.can_use_fruit = true
		await physics_frame
		await process_frame

func foto(nome: String, vista: String, raio := 9.0) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(800, 520)
	vp.world_3d = j.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = 55
	var env := Environment.new()                       # luz NEUTRA (a do cenário é azulada e esverdeia o amarelo da pele)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.64, 0.66)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	cam.environment = env
	var base: Basis = j._char_model.global_basis.orthonormalized()
	var fwd := -base.z
	var dir := base.x
	var centro: Vector3 = j._char_model.global_position + Vector3.UP * 1.7
	match vista:
		"lado":
			cam.global_position = centro + dir * raio + fwd * 1.5
			cam.look_at(centro + fwd * 1.5)
		"tres_quartos":
			cam.global_position = centro + dir * raio * 0.6 + fwd * raio * 0.75 + Vector3.UP * 1.0
			cam.look_at(centro + fwd * 0.5)
		"lado_perto":
			cam.global_position = centro + dir * 5.8 - Vector3.UP * 0.8
			cam.look_at(centro + fwd * 0.3 - Vector3.UP * 0.4)
		"frente_perto":
			cam.global_position = centro + fwd * 6.0 + dir * 1.0 - Vector3.UP * 0.7
			cam.look_at(centro - Vector3.UP * 0.5)
		"tres_quartos_perto":
			cam.global_position = centro + fwd * 4.6 - dir * 3.8 - Vector3.UP * 0.6
			cam.look_at(centro - Vector3.UP * 0.5)
		"cima":
			cam.global_position = j._char_model.global_position + Vector3.UP * raio * 1.1 - fwd * 1.0
			cam.look_at(j._char_model.global_position + fwd * 3.0, fwd)
		"atras":
			cam.global_position = centro - fwd * raio * 0.6 + dir * raio * 0.35 + Vector3.UP * 1.2
			cam.look_at(centro + fwd * 7.0)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA + nome + ".png"))
	vp.queue_free()
	await process_frame
	if _congelado:
		_congelado = false
		Engine.time_scale = 0.12

var _congelado := false
var _alvos_visiveis: Array = []

## Avança até a fase `f` (no ponto `frac` do ATIVO) e CONGELA o tempo do jogo: o render por software leva ~3 quadros para fotografar e o golpe
## acabaria nesse meio tempo (a primeira rodada fotografou a recuperação, não o pico).
func ate_fase(f: int, frac: float) -> void:
	for i in 400:
		await physics_frame
		await process_frame
		if u.fase == f and u.tempo >= u._dados.p * (0.9 if f == 1 else 1.0) + (u._dados.a * frac if f == 2 else 0.0):
			Engine.time_scale = 0.0001
			_congelado = true
			return

func executar() -> void:
	if DisplayServer.get_name() == "headless":
		print("captura_ushi precisa de display real"); quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://ushi_captura.json")
	root.get_node("GameFlow").start_story()
	await quadros(240)
	j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var avancos = McEntidade.de(j).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	var prog = current_scene.get("progressao")
	prog.fruta = "ushi_ushi_giraffe"
	prog.skills["fruta"] = maxi(1, int(prog.skills.get("fruta", 0)))
	prog.fruta_ativa = true
	prog.item_ativo = prog.NENHUM_ITEM
	modo.equipar_fruta(j, "ushi_ushi_giraffe")
	await quadros(12)
	c = j.get_node("FrutaMinePiece")
	u = c.ushi
	j.max_energy = 5000.0
	j.energy = 5000.0
	c._sincronizar_para_o_mod()
	var aim: Vector3 = c.olhar()
	var plano := Vector3(aim.x, 0, aim.z).normalized()
	# alvos de referência (cápsulas) à frente
	for d in [4.0, 9.0, 14.0]:
		var a := Alvo.new()
		_alvos_visiveis.append(a)
		current_scene.add_child(a)
		a.global_position = j.global_position + plano * d + Vector3.UP * 0.9
	physics_frame.connect(func() -> void:
		var p = get_first_node_in_group("player")
		if p != null and p.capacidades != null: p.capacidades.can_use_fruit = true)
	# --- forma 0 (humano): Z (pescoço do peito), X (chute aéreo) e C (rajada de chutes)
	Engine.time_scale = 0.12
	await livre()
	await secao_z("00_humano")
	await secao_x("00_humano")
	if OS.get_cmdline_user_args().has("so_x0"):
		print("CAPTURA CONCLUIDA"); quit(0); return
	await secao_c("00_humano")
	# --- humanoide
	await trocar(1)
	print("INFO forma após trocar: %d" % u.forma)
	await foto("01_humanoide_parado", "tres_quartos", 7.0)
	var w := InputEventKey.new()
	w.keycode = KEY_W
	w.physical_keycode = KEY_W
	w.pressed = true
	Input.parse_input_event(w)
	await quadros(40)
	Engine.time_scale = 0.12
	for k in 8:                                         # 8 quadros de corrida em câmera lenta: apoio, suspensão, contrafase de braços e pernas
		await foto("02_humanoide_corrida_%d" % k, "lado", 6.5)
		if k % 2 == 0:
			await foto("02_humanoide_corrida_%d_atras" % k, "atras", 8.0)
	Engine.time_scale = 1.0
	w.pressed = false
	Input.parse_input_event(w)
	if OS.get_cmdline_user_args().has("so_corrida"):
		print("CAPTURA CONCLUIDA"); quit(0); return
	await quadros(40)
	Engine.time_scale = 0.12
	await secao_z("03_humanoide")
	await secao_x("04_humanoide")
	await secao_c("05_humanoide")
	# --- girafa
	await trocar(2)
	print("INFO forma após trocar: %d" % u.forma)
	await foto("10_girafa_parada", "tres_quartos", 11.0)
	await foto("10b_girafa_parada_lado", "lado", 11.0)
	w.pressed = true
	Input.parse_input_event(w)
	await quadros(40)
	Engine.time_scale = 0.12
	for k in 8:
		await foto("11_girafa_galope_%d" % k, "lado", 11.0)
	Engine.time_scale = 1.0
	w.pressed = false
	Input.parse_input_event(w)
	await quadros(40)
	Engine.time_scale = 0.12
	await livre()
	u.controlador.iniciar_recarga(1111, 0.0)
	c.usar_tecla("Z", true); c.usar_tecla("Z", false)
	await ate_fase(1, 0.0)
	await foto("14_girafa_Z_antecipacao", "lado", 12.0)
	Engine.time_scale = 0.12
	await ate_fase_ativa_com_alvo(6.0)
	await foto("15_girafa_Z_impacto", "lado", 13.0)
	await quadros(80)
	# --- Martelada: coice da preparação (t=0,24 s) e a varredura com o nariz, vista de cima
	await livre()
	u.controlador.iniciar_recarga(1112, 0.0)
	var arco := Alvo.new()
	_alvos_visiveis.append(arco)
	current_scene.add_child(arco)
	arco.global_position = j.global_position + plano * 3.4 + Vector3.UP * 0.9
	c.usar_tecla("X", true); c.usar_tecla("X", false)
	await ate_tempo(0.24)
	await foto("16a_girafa_X_coice_lado", "lado", 12.0)
	await foto("16b_girafa_X_coice_cima", "cima", 12.0)
	Engine.time_scale = 0.12
	await ate_fase(2, 0.1)
	await foto("17a_girafa_X_inicio_cima", "cima", 12.0)
	Engine.time_scale = 0.12
	await ate_fase(2, 0.55)
	await foto("17b_girafa_X_contato_cima", "cima", 12.0)
	await foto("17c_girafa_X_contato_lado", "lado", 12.0)
	Engine.time_scale = 0.12
	await ate_fase(2, 0.95)
	await foto("17d_girafa_X_fim_cima", "cima", 12.0)
	Engine.time_scale = 1.0
	print("CAPTURA CONCLUIDA")
	quit(0)

## Z com alvo na ponta do pescoço: antecipação e impacto.
func secao_z(prefixo: String) -> void:
	await livre()
	u.controlador.iniciar_recarga(1101, 0.0)
	c.usar_tecla("Z", true); c.usar_tecla("Z", false)
	await ate_fase(1, 0.0)
	await foto(prefixo + "_Z_antecipacao", "lado", 7.0)
	Engine.time_scale = 0.12
	await ate_fase_ativa_com_alvo(5.0)
	await foto(prefixo + "_Z_impacto", "lado", 8.0)

## X: chute aéreo — agachar (0,15), pico/emissão (0,34), pouso (0,55).
## Esconde as cápsulas (tapavam o corpo) e põe marcadores nos pés: VERMELHO = direito, AZUL = esquerdo.
func preparar_vista_do_chute() -> void:
	for a in _alvos_visiveis:
		if is_instance_valid(a):
			a.visible = false
	var raiz: Node3D = j._char_model
	var forma_zoan = j.get_node_or_null("FormaZoan")
	for par in [["Foot_R", "RightLeg", Color(1, 0.1, 0.1)], ["Foot_L", "LeftLeg", Color(0.1, 0.3, 1)]]:
		var pai: Node3D = null
		var pos := Vector3.ZERO
		if forma_zoan != null and forma_zoan._topo.has(par[1]):
			pai = forma_zoan._topo[par[1]]            # forma 1: o marcador vai na peça VISÍVEL da perna (o rig humano está oculto)
			pos = Vector3(0, -0.62, 0)
		else:
			pai = raiz.find_child(par[0], true, false) as Node3D
		if pai == null: continue
		var antigo := pai.get_node_or_null("MarcadorUshi")
		if antigo != null: antigo.queue_free()
		var m := MeshInstance3D.new()
		m.name = "MarcadorUshi"
		var sph := SphereMesh.new()
		sph.radius = 0.12
		sph.height = 0.24
		m.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = par[2]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		m.material_override = mat
		m.position = pos
		pai.add_child(m)

func secao_x(prefixo: String) -> void:
	preparar_vista_do_chute()
	await livre()
	u.controlador.iniciar_recarga(1102, 0.0)
	c.usar_tecla("X", true); c.usar_tecla("X", false)
	for t in [0.15, 0.30, 0.34, 0.40, 0.55]:
		await ate_tempo(t)
		var nome := "%s_X_t%03d" % [prefixo, int(t * 100.0)]
		await foto(nome + "_frente", "frente_perto", 6.0)
		await foto(nome + "_3q", "tres_quartos_perto", 6.0)
		await foto(nome + "_lado", "lado_perto", 6.0)
		Engine.time_scale = 0.12

## C: picos do 1º (direita), 2º (esquerda) e 5º chutes, com os cortes saindo dos pés.
func secao_c(prefixo: String) -> void:
	await livre()
	u.controlador.iniciar_recarga(1103, 0.0)
	c.usar_tecla("C", true); c.usar_tecla("C", false)
	preparar_vista_do_chute()
	var p0: float = u._dados.p
	for k in [0, 1, 4]:
		await ate_tempo(p0 + 0.09 + float(k) * 0.14)
		var nome := "%s_C_pico%d_%s" % [prefixo, k + 1, "direita" if k % 2 == 0 else "esquerda"]
		await foto(nome + "_frente", "frente_perto", 6.0)
		await foto(nome + "_3q", "tres_quartos_perto", 6.0)
		await foto(nome + "_atras", "atras", 9.0)
		Engine.time_scale = 0.12

func ate_tempo(t: float) -> void:
	for i in 900:
		await physics_frame
		await process_frame
		if u.tempo >= t and u.ativo:
			break
	_congelar()
	var raiz: Node3D = j._char_model
	var coxa := raiz.find_child("Thigh_R", true, false) as Node3D
	var pe := raiz.find_child("Foot_R", true, false) as Node3D
	var rel: Vector3 = raiz.global_basis.orthonormalized().inverse() * (pe.global_position - coxa.global_position)
	var rep := (j.get_meta("pose_externa").Thigh_R as Vector3) if j.has_meta("pose_externa") else Vector3.ZERO
	var eixo: Vector3 = raiz.global_basis.orthonormalized().inverse() * (coxa.global_basis * Vector3.DOWN)
	var shin := raiz.find_child("Shin_R", true, false) as Node3D
	var eixo_s: Vector3 = raiz.global_basis.orthonormalized().inverse() * (shin.global_basis * Vector3.DOWN) if shin != null else Vector3.ZERO
	print("DEBUG eixo da COXA (x dir, y cima, z trás) = (%.2f, %.2f, %.2f) | da CANELA = (%.2f, %.2f, %.2f) | pe é descendente da coxa: %s" % [eixo.x, eixo.y, eixo.z, eixo_s.x, eixo_s.y, eixo_s.z, coxa.is_ancestor_of(pe)])
	print("DEBUG perna(local do corpo: x dir, y cima, z trás) = (%.2f, %.2f, %.2f) | meta Thigh_R=%s" % [rel.x, rel.y, rel.z, str(rep)])
	print("DEBUG t=%.3f (pedido %.2f) coxaR.euler.x=%.2f foot_y=%.2f meta=%s hop_y=%.2f" % [u.tempo, t, coxa.basis.get_euler().x, pe.global_position.y, j.has_meta("pose_externa"), raiz.position.y])

## Espera (em tempo normal) o golpe/transformação anterior TERMINAR; depois volta à câmera lenta. Sem isto, em câmera lenta o golpe seguinte era recusado.
func livre() -> void:
	Engine.time_scale = 1.0
	_congelado = false
	for i in 900:
		await physics_frame
		await process_frame
		if not u.ativo and not c.ativo and u.bloqueio_de_forma <= 0.0:
			break
	await quadros(5)
	Engine.time_scale = 0.12

func trocar(alvo: int) -> void:
	for t in 4:
		await livre()
		if u.forma == alvo:
			break
		Engine.time_scale = 1.0
		c.transformar(false)
		await quadros(250)
		await livre()
	Engine.time_scale = 1.0
	await quadros(20)

func _congelar() -> void:
	Engine.time_scale = 0.0001
	_congelado = true

## Entra no ATIVO, põe um alvo (cápsula) NA PONTA do pescoço (raiz + mira × alcance) para o hit acontecer no quadro, e congela perto do pico.
func ate_fase_ativa_com_alvo(alcance: float) -> void:
	for i in 400:
		await physics_frame
		await process_frame
		if u.fase == 2:
			break
	var a := Alvo.new()
	_alvos_visiveis.append(a)                          # registrado: as seções de chute escondem TODOS os alvos (Codex #150)
	current_scene.add_child(a)
	a.global_position = u._raiz() + u._dir * (alcance - 0.4)
	for i in 400:
		await physics_frame
		await process_frame
		if u.fase == 2 and u.tempo >= u._dados.p + u._dados.a * 0.85:
			break
	_congelar()

func _resumo(a: Array[float]) -> String:
	var s := a.duplicate()
	s.sort()
	var soma := 0.0
	for v in s: soma += v
	return "n=%d média=%.1f p95=%.1f máx=%.1f" % [s.size(), soma / s.size(), s[int(s.size() * 0.95)], s[-1]]
