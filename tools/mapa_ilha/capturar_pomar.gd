extends SceneTree
# ============================================================================
#  CAPTURA DO POMAR E DA DOMA — fotos com GPU no Modo História de verdade (01/10/2026).
#
#    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/capturar_pomar.gd -- [--saida res://art_src/validation/pomar]
#
#  Abre o Modo História no mapa vivo (progresso de teste em user://) e fotografa:
#  pomares, uma frutífera de cada tipo de perto (frutas grudadas na copa), uma fruta
#  caída no chão, a floresta oeste enriquecida, a fruta na mão do personagem e um
#  coelho domado seguindo. Mede o tempo de quadro em cada vista. Só LÊ o mapa.
# ============================================================================

const PROGRESSO := "user://captura_pomar_progresso.json"
var saida := "res://art_src/validation/pomar"
var _camera: Camera3D


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A captura exige renderer real (rode sem --headless).")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.find("--saida") >= 0:
		saida = args[args.find("--saida") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	root.size = Vector2i(1280, 800)
	var modo_script: Script = load("res://src/historia/ModoHistoria.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo_script.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 160:
		await process_frame
	var modo := current_scene
	var pomar := modo.get_node("Pomar") as PomarDaIlha
	var pop := modo.get_node("Animais") as PopulacaoDeAnimais
	var jogador: Node3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	var hud: Node = modo.get("_hud")
	hud.set("visible", false)          # CanvasLayer: foto sem HUD
	_camera = Camera3D.new()
	_camera.far = 3000.0
	modo.add_child(_camera)
	_camera.make_current()
	print("POMAR arvores=%d frutas=%d" % [pomar.arvores.size(), pomar.arvores.reduce(func(n, a): return n + (a["galhos"] as Array).size(), 0)])

	await _vista("01_pomar_norte_vila", jogador, Vector3(155, 22, -20), Vector3(155, 4, -62))
	await _vista("02_pomar_fazenda", jogador, Vector3(80, 18, -120), Vector3(47, 4, -155))
	# Uma de cada tipo, de perto.
	var feitas := {}
	for a in pomar.arvores:
		var peca: Node3D = modo.find_child(String(a["id"]), true, false)
		var modelo := String(peca.get_node("Modelo").get_meta("modelo_id", "")) if peca else ""
		if peca == null or feitas.has(modelo):
			continue
		feitas[modelo] = true
		var c: Vector3 = peca.global_position
		var lado := Vector3(1, 0, 0.6).normalized()
		var t := peca.get_node("Modelo") as Node3D
		var caixa := _caixa(t)
		var dist := maxf(caixa.size.x, caixa.size.z) * 1.1 + 4.0
		await _vista("03_perto_%s" % modelo, jogador, c + lado * dist + Vector3(0, -caixa.size.y * 0.25, 0),
			c + Vector3(0, caixa.size.y * 0.1, 0))
	# Fruta caída: derruba uma e fotografa no chão.
	PomarDaIlha.tempo_de_rebrotar = 9999.0
	pomar.derrubar_uma()
	var item: FrutaNoChao = pomar.no_chao[-1]
	for i in 120:
		await physics_frame
		if item.no_chao:
			break
	await _vista("04_fruta_no_chao", jogador, item.global_position + Vector3(1.6, 0.9, 1.2), item.global_position)
	await _vista("05_floresta_oeste", jogador, Vector3(-120, 12, 40), Vector3(-160, 2, 10))
	# Chão da mata: de 5 m de um arbusto/cogumelo plantado, na altura dos olhos.
	for p in modo.find_children("natureza_*", "", true, false):
		var m := p.get_node_or_null("Modelo")
		var id := String(m.get_meta("modelo_id", "")) if m else ""
		if id.begins_with("floresta_bush") or id.begins_with("floresta_mushroom"):
			var c2: Vector3 = (p as Node3D).global_position
			await _vista("06_floresta_chao", jogador, c2 + Vector3(4.0, 1.4, 3.0), c2)
			break
	# Fruta na mão + coelho domado.
	var prog: ProgressaoDoPersonagem = modo.get("progressao")
	prog.ganhar_fruta_do_pomar("fruta_maca", 5)
	var mao := modo.get_node("FrutaNaMao") as FrutaNaMao
	mao.segurar("fruta_maca")
	var coelho: AnimalDaIlha = null
	for a in pop.animais:
		if a.especie == "rabbit" and a.vivo():
			coelho = a
			break
	jogador.global_position = coelho.global_position + Vector3(2.2, 0.6, 0)
	jogador.velocity = Vector3.ZERO
	pop.atualizar_detalhe()
	for i in 30:
		await physics_frame
	modo.set("chance_de_doma", 1.0)
	mao.pedir_doma()
	for i in 60:
		await physics_frame
	var j := jogador.global_position
	var frente := -jogador.global_transform.basis.z
	await _vista("07_fruta_na_mao_e_coelho_domado", jogador, j + Vector3(3.0, 1.2, 3.0), j + Vector3(0, 0.6, 0))
	var mao_no: Node3D = jogador.find_child("FrutaNaMao", true, false)
	if mao_no:
		var m := mao_no.global_position
		await _vista("08_mao_de_perto", jogador, m + Vector3(0.9, 0.3, 0.9), m)
	modo_script.set("progresso_forcado", "")
	modo_script.set("chance_de_doma", 0.35)
	PomarDaIlha.tempo_de_rebrotar = 300.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("CAPTURA_POMAR fotos em %s" % saida)
	quit()


func _caixa(no: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for mi: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		var c := mi.global_transform * mi.get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	return caixa


func _vista(nome: String, jogador: Node3D, de: Vector3, para: Vector3) -> void:
	# O "jogador" vai junto (LOD dos animais e nível de detalhe), sem cair no meio da foto.
	_camera.global_position = de
	_camera.look_at(para)
	for i in 10:
		await process_frame
	var t0 := Time.get_ticks_usec()
	for i in 30:
		await process_frame
	var ms := (Time.get_ticks_usec() - t0) / 30000.0
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(saida.path_join(nome + ".png")))
	print("FOTO %-40s quadro %.1f ms" % [nome, ms])
