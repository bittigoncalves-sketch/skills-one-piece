extends SceneTree
# Macacos humanoides (ficha `salta`): a decisão do pulo longo de perseguição (faixa 5–13 m, recarga, alvo vivo). Testada direto: a IA em jogo mexe no corpo e o dado medido ficava ruidoso (18/11/2026).
#   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_macaco_salta.gd
func _init() -> void:
	_r.call_deferred()
func _r() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_macaco_salta.json"))
	modo.set("progresso_forcado", "user://test_macaco_salta.json")
	var pe := ProgressaoDoPersonagem.carregar("user://test_macaco_salta.json")
	pe.corpo = "masculino"
	pe.salvar("user://test_macaco_salta.json")
	root.get_node("GameFlow").start_story()
	for i in 300: await physics_frame
	var j: Node3D = get_first_node_in_group("player")
	var raiz: Node3D = current_scene.get("_raiz_do_mapa")
	j.set_meta("damage_immune", true)
	var ficha := DadosEastBlue.ficha_do_modelo("mp_macaco_humanoide").duplicate(true)
	var m := PersonagemMinePiece.new()
	m.montar(ficha, "mp_macaco_humanoide")
	raiz.add_child(m)
	m.global_position = j.global_position + Vector3(0, 0, -30)
	for i in 40: await physics_frame
	m.set_physics_process(false)                      # a decisão do salto é testada direto, sem a IA mexendo no corpo
	_c("a ficha dos macacos tem `salta`", bool(ficha.get("salta", false)))
	_c("o macaco está no chão", m.is_on_floor())
	var alvo := Node3D.new()
	alvo.set_script(null)
	alvo.set_meta("x", 1)
	root.add_child(alvo)
	var jog := _AlvoFalso.new()
	root.add_child(jog)
	m.cerebro.alvo = jog
	var base := m.global_position
	for dist in [3.0, 20.0]:                          # perto demais e longe demais: não salta
		jog.global_position = base + Vector3(0, 0, dist)
		m._salto_espera = 0.0
		m.velocity = Vector3.ZERO
		m._salto_de_perseguicao(0.016)
		_c("a %.0f m NÃO salta" % dist, m.velocity.y == 0.0)
	jog.global_position = base + Vector3(0, 0, 9.0)
	m._salto_espera = 0.0
	m._salto_de_perseguicao(0.016)
	_c("a 9 m salta (vy = %.1f, impulso horizontal %.1f)" % [m.velocity.y, m._empurrao.length()], absf(m.velocity.y - PersonagemMinePiece.SALTO_IMPULSO.y) < 0.01 and absf(m._empurrao.length() - PersonagemMinePiece.SALTO_IMPULSO.x) < 0.01)
	_c("o impulso aponta para o alvo (+Z)", m._empurrao.z > 13.0)
	m.velocity = Vector3.ZERO
	m._salto_de_perseguicao(0.016)
	_c("recarga de %.1f s: não salta de novo logo" % PersonagemMinePiece.SALTO_RECARGA, m.velocity.y == 0.0 and m._salto_espera > 4.0)
	m._salto_espera = 0.0
	jog.health = 0.0
	m._salto_de_perseguicao(0.016)
	_c("alvo morto: não salta", m.velocity.y == 0.0)
	var sem := DadosEastBlue.ficha_do_modelo("mp_bandit")
	_c("o bandido comum não tem `salta`", not bool(sem.get("salta", false)))
	print("MACACO_SALTA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
class _AlvoFalso extends Node3D:
	var health := 24.0
var _ok_n := 0
var _falhas := 0
func _c(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
