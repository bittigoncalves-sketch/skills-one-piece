extends SceneTree
# ============================================================================
#  TESTE — besta agressiva navegando (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E5).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_encontros_no_mar.gd
#
#  A. Probabilidade: média entre encontros (só sorteios) ≈ 5,5 min, com semente.
#  B. Modo História, MAPA VIVO (só leitura), progresso de TESTE: compra um bote, leva ao mar
#     aberto, assume o leme; encontro forçado → aviso (redemoinho) → besta surge mirando o
#     BARCO; o barco toma dano e o jogador não; o jogador acerta → a besta passa a mirar o
#     JOGADOR. Controles: perto da costa não é mar aberto; sem pilotar não há encontro.
#  C. Afundar: casco a zero afunda, solta o piloto na água e o barco sai da frota (perdido).
#  D. Recuo (2 min) e abate (XP).  E. Tempo até afundar sob ataque, medido.
# ============================================================================

const PROGRESSO := "user://test_encontros_progresso.json"
const ABERTO := Vector3(700, 0, 30)

var _falhas := 0
var _jogador: CharacterBody3D
var _nav: Node
var _enc: Node3D
var _prog: ProgressaoDoPersonagem


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	print("\n===== ENCONTROS NO MAR =====")
	_probabilidade()
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://mapas/historia/baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 120:
		await process_frame
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			_jogador = p
	_nav = current_scene.get("_navegacao")
	var mar := current_scene.get_node_or_null("Mar")
	_prog = current_scene.get("progressao")
	_ok(_jogador != null and _nav != null and mar != null, "Modo História com jogador, navegação e Mar")
	if _jogador == null or _nav == null or mar == null:
		_fim(modo)
		return
	_jogador.set_meta("damage_immune", false)
	_enc = mar.get("encontros")
	_enc.rng.seed = 99

	_ok(not _enc.mar_aberto(Vector3(290, 0, 40)), "controle: no porto não é mar aberto")
	_ok(_enc.mar_aberto(ABERTO), "a %s é mar aberto (%.0f m de água)" % [ABERTO, _enc.relevo.profundidade(ABERTO.x, ABERTO.z)])
	_ok(not _enc.forcar().is_empty() and _enc.fase == 0, "controle: sem pilotar, nenhum encontro")

	var barco := await _pilotar_bote()
	_ok(barco != null and _nav.ativo(), "pilotando um bote no mar aberto")
	if barco == null:
		_fim(modo)
		return
	var vida0: float = barco.get("health")
	_ok(vida0 > 0.0 and is_equal_approx(vida0, float(barco.get("max_health"))), "bote com vida cheia: %.0f" % vida0)

	# B. Aviso → besta mirando o barco.
	_ok(_enc.forcar().is_empty() and _enc.fase == 1, "encontro forçado: fase de AVISO")
	await _quadros(5)
	_ok(_enc.find_child("Redemoinho", true, false) != null, "redemoinho de aviso na água")
	await _segundos(3.3)
	var besta: Node3D = _enc.besta
	_ok(_enc.fase == 2 and is_instance_valid(besta), "a besta surgiu (%s)" % (besta.get("especie") if is_instance_valid(besta) else "—"))
	if not is_instance_valid(besta):
		_fim(modo)
		return
	_ok(besta.get("alvo") == barco and besta.get("agressiva"), "ela mira o BARCO")
	var vida_j: float = _jogador.get("health")
	var t0 := Time.get_ticks_msec()
	while float(barco.get("health")) >= vida0 and Time.get_ticks_msec() - t0 < 25000:
		await _quadros(10)
		_manter_no_leme(barco)
	_ok(float(barco.get("health")) < vida0, "o casco tomou dano (%.0f → %.0f)" % [vida0, float(barco.get("health"))])
	_ok(is_equal_approx(float(_jogador.get("health")), vida_j) or float(_jogador.get("health")) >= vida_j - 0.01,
		"o jogador não foi o alvo (vida %.0f)" % float(_jogador.get("health")))
	_ok(_nav.dica().contains("casco"), "o leme mostra o casco: \"%s\"" % _nav.dica())

	# O jogador acerta → alvo vira o jogador.
	CombatResolver.aplicar(besta, 10.0, 0, 0.0, _jogador.global_position, Vector3.ZERO, 0.3, 0.0, false, _jogador)
	await _quadros(2)
	_ok(besta.get("alvo") == _jogador, "acertada pelo jogador, passa a mirar o JOGADOR")

	# E. Tempo até afundar (taxa medida sob ataque, extrapolada para a vida cheia).
	var h_antes: float = barco.get("health")
	besta.set("alvo", barco)
	var t1 := Time.get_ticks_msec()
	await _segundos(15.0, barco)
	var perdido: float = h_antes - float(barco.get("health"))
	var dps := perdido / 15.0
	print("     taxa sob ataque: %.2f de casco/s → bote cheio afunda em ~%.0f s" % [dps, vida0 / maxf(dps, 0.001)])
	# Alvo (barco.gd): bote ~1 min. Abaixo de 35 s não dá tempo de reagir; acima de 110 s ele
	# nunca afunda num encontro (a besta desiste aos 120 s).
	var ate := vida0 / maxf(dps, 0.001)
	_ok(ate > 35.0 and ate < 110.0, "o bote afunda em ~%.0f s de ataque contínuo (alvo ~60 s: risco real, dá tempo de reagir)" % ate)

	# C. Afundar e perder.
	barco.take_damage(1.0e6)
	await _quadros(3)
	_ok(not _nav.ativo() and not _jogador.get_meta("pilotando", false), "afundando: o piloto foi solto")
	_ok(not _prog.barcos.has("boat"), "o bote saiu da frota (perdido)")
	await _segundos(5.0)
	_ok(not is_instance_valid(barco), "o barco afundou e saiu da cena")
	await _segundos(1.0)
	_ok(_enc.fase == 3 or _enc.fase == 0, "sem barco, a besta desiste (fase %d)" % _enc.fase)
	await _segundos(3.5)
	_ok(_enc.fase == 0 and not is_instance_valid(besta), "a besta mergulhou e sumiu")

	# D. Abate dá XP (novo bote, novo encontro).
	_enc.set("_folga", 0.0)
	_prog.ouro += 5
	barco = await _pilotar_bote()
	_ok(barco != null and _enc.forcar().is_empty(), "segundo encontro com outro bote")
	await _segundos(3.3)
	besta = _enc.besta
	var xp0 := _prog.xp
	var nivel0 := _prog.nivel
	if is_instance_valid(besta):
		besta.take_damage(1.0e6)
	await _quadros(3)
	_ok(_prog.xp != xp0 or _prog.nivel != nivel0, "abater a besta dá XP (%d → %d, nível %d → %d)" % [xp0, _prog.xp, nivel0, _prog.nivel])
	await _segundos(5.5)
	_ok(_enc.fase == 0 and not is_instance_valid(besta), "a besta abatida sai da cena e o mar volta à espera")
	_ok(_enc.get("_folga") > 60.0, "folga de %.0f s antes do próximo sorteio" % float(_enc.get("_folga")))
	_fim(modo)


func _probabilidade() -> void:
	print("\n-- A. probabilidade --")
	var Enc: Script = load("res://src/historia/mar/encontros_no_mar.gd")
	var p: float = Enc.chance_por_sorteio()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var soma := 0.0
	var n := 3000
	for k in n:
		var sorteios := 1
		while rng.randf() >= p:
			sorteios += 1
		soma += sorteios * Enc.INTERVALO
	var media := soma / n / 60.0
	_ok(media > 5.0 and media < 6.0, "média entre encontros navegando: %.2f min (pedido: 5–6)" % media)


func _pilotar_bote() -> CharacterBody3D:
	if not _prog.comprar_barco("boat", 1):
		_prog.ouro += 1
		_prog.comprar_barco("boat", 1)
	_nav.lancar("boat")
	var b: CharacterBody3D = _nav.barco_do_jogador("boat")
	if b == null:
		return null
	b.global_position = Vector3(ABERTO.x, AguaDoMundo.superficie_em(ABERTO.x, ABERTO.z), ABERTO.z)
	PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, b.global_transform)
	_jogador.global_position = (b.get("leme") as Node3D).global_position + Vector3.UP * 0.9
	await _quadros(3)
	return b if _nav.assumir(b) else null


func _manter_no_leme(b: Node3D) -> void:
	if is_instance_valid(b):
		b.call("definir_comando", 0.0, 0.0)


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _segundos(s: float, barco: Node3D = null) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await physics_frame
		_manter_no_leme(barco)


func _fim(modo: Script) -> void:
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\nENCONTROS_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)
