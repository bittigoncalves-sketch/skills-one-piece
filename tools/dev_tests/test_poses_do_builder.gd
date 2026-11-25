extends SceneTree
# ============================================================================
#  POSES DO SKILLS BUILDER (06/10/2026) — dados, transição, prévia e jogo.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_poses_do_builder.gd
#
#  Pedido do dono: poses de carregar/segurar/soltar/final feitas no Builder e
#  encadeadas com transição. Aqui: o contrato aceita/recusa poses; a transição chega
#  na pose; a prévia é reproduzível na régua; e o JOGADOR em jogo faz a mesma pose
#  que a prévia mostra no mesmo instante (a mesma conta do animador).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const Arena := preload("res://src/skills_builder/arena_preview.gd")
const MAPA := "user://test_poses_builder_mapa.json"
const PROGRESSO := "user://test_poses_builder.json"

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var s := _skill()

	# --- contrato
	_ok("skill com duas poses e dois blocos de Pose é válida (%s)" % str(Dados.validar(s).erros), Dados.validar(s).ok)
	var ruim := s.duplicate(true)
	ruim.poses[0].ossos["Rabo"] = [0, 0, 0]
	_ok("junta que não existe no rig é recusada", not Dados.validar(ruim).ok)
	ruim = s.duplicate(true)
	ruim.poses[0].ossos["UpperArm_R"] = [270, 0, 0]
	_ok("ângulo fora de −180..180 é recusado", not Dados.validar(ruim).ok)
	ruim = s.duplicate(true)
	ruim.eventos[0].parametros.pose = "nao_existe"
	_ok("bloco que cita pose inexistente é recusado", not Dados.validar(ruim).ok)
	var antiga := Dados.novo()
	antiga.erase("poses")
	antiga.animacao.erase("pose"); antiga.animacao.erase("transicao"); antiga.animacao.erase("pulso")
	_ok("skill antiga (sem poses e sem os campos novos) continua válida", Dados.validar(antiga).ok)

	# --- transição
	var alvo := {"UpperArm_R": Vector3(PI / 2, 0, 0)}
	var p := {}
	for i in 30:                       # 0,25 s de transição a 120 Hz = 30 passos
		p = PosesDeSkill.aproximar(p, alvo, 0.25, 1.0 / 120.0)
	var frac := (p.get("UpperArm_R", Vector3.ZERO) as Vector3).x / (PI / 2)
	_ok("em 'Transição' segundos a pose chega a ~95 %% (%.0f %%)" % (frac * 100.0), frac > 0.93 and frac < 0.97)

	# --- prévia
	var vp := SubViewport.new()
	vp.own_world_3d = true
	root.add_child(vp)
	var arena: Node3D = Arena.new()
	vp.add_child(arena)
	arena.set_process(false)
	arena.configurar(s)
	var no_braco: Node3D = (arena.get("_rig") as Dictionary).get("nodes", {}).get("UpperArm_R")
	var repouso: Vector3 = (arena.get("_rig") as Dictionary).get("rest", {}).get("UpperArm_R", Vector3.ZERO)
	_ok("a prévia achou as juntas do Base", no_braco != null)
	arena.buscar(0.45)
	var a1 := rad_to_deg(no_braco.rotation.x - repouso.x)
	arena.buscar(0.95)
	var a2 := rad_to_deg(no_braco.rotation.x - repouso.x)
	arena.buscar(0.6)
	var meio := rad_to_deg(no_braco.rotation.x - repouso.x)
	arena.buscar(0.6)
	var meio2 := rad_to_deg(no_braco.rotation.x - repouso.x)
	_ok("prévia: no fim do 1º bloco o braço está em ~90° (%.1f°)" % a1, absf(a1 - 90.0) < 6.0)
	_ok("prévia: no fim do 2º bloco, em ~−45° (%.1f°)" % a2, absf(a2 + 45.0) < 6.0)
	_ok("prévia: no meio da transição está entre as duas (%.1f°)" % meio, meio < 85.0 and meio > -40.0)
	_ok("prévia reproduzível na régua (%.3f = %.3f)" % [meio, meio2], is_equal_approx(meio, meio2))
	arena.mostrar_pose("braco_cima")
	_ok("o editor mostra a pose parada (%.1f°)" % rad_to_deg(no_braco.rotation.x - repouso.x),
		absf(rad_to_deg(no_braco.rotation.x - repouso.x) - 90.0) < 0.5)
	arena.mostrar_pose("")
	vp.queue_free()

	# --- jogo: o jogador faz a mesma pose
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	var jogador: Node3D = get_first_node_in_group("player")
	var anim: Node = null
	for c in jogador.get_children():
		if c is ProceduralAnimator:
			anim = c
	_ok("o jogador tem o animador procedural", anim != null)
	if anim != null:
		var braco: Node3D = (anim.get("_n") as Dictionary).get("UpperArm_R")
		var rep: Vector3 = (anim.get("_rest") as Dictionary).get("UpperArm_R", Vector3.ZERO)
		ExecutorDeSkill.lancar(current_scene, jogador, s, Vector3.FORWARD)
		for i in 27:                    # 0,45 s
			await physics_frame
		var j1 := rad_to_deg(braco.rotation.x - rep.x)
		for i in 30:                    # 0,95 s
			await physics_frame
		var j2 := rad_to_deg(braco.rotation.x - rep.x)
		_ok("jogo: em 0,45 s o braço do jogador está perto da prévia (%.1f° × %.1f°)" % [j1, a1], absf(j1 - a1) < 15.0)
		_ok("jogo: em 0,95 s também (%.1f° × %.1f°)" % [j2, a2], absf(j2 - a2) < 15.0)
		for i in 60:
			await physics_frame
		_ok("ao fim da skill o meta da pose sai do corpo", not jogador.has_meta("pose_de_skill"))
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nPOSES_DO_BUILDER %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _skill() -> Dictionary:
	var s := Dados.novo()
	s.poses = [
		{"id": "braco_cima", "nome": "Braço em cima", "ossos": {"UpperArm_R": [90, 0, 0]}},
		{"id": "braco_tras", "nome": "Braço atrás", "ossos": {"UpperArm_R": [-45, 0, 0]}},
	]
	s.eventos = [
		{"id": "p1", "tipo": "animacao", "inicio": 0.0, "duracao": 0.5, "habilitado": true,
			"parametros": {"pose": "braco_cima", "transicao": 0.15}},
		{"id": "p2", "tipo": "animacao", "inicio": 0.5, "duracao": 0.5, "habilitado": true,
			"parametros": {"pose": "braco_tras", "transicao": 0.2}},
	]
	s.configuracoes.duracao = 1.0
	return s


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
