extends SceneTree
## Esquiva do Epic Fight (12/11/2026): com arma do mod o Q toca roll_forward/roll_backward, anda pela curva do clipe e é invulnerável o clipe inteiro.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_esquiva_epic_fight.gd
var total := 0
var falhas := 0
func _init() -> void:
	rodar.call_deferred()
func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)
func q(n: int) -> void:
	for i in n:
		await physics_frame
func tecla(codigo: Key, pressionada: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.physical_keycode = codigo
	e.pressed = pressionada
	Input.parse_input_event(e)
func rolar(j, teclas: Array) -> Dictionary:
	await q(60)                                     # parado, no chão, estamina cheia
	var d = j.get("_dash")
	for t in teclas:
		tecla(t, true)
	await q(2)
	var p0: Vector3 = j.global_position
	var frente: Vector3 = -j.global_basis.z
	tecla(KEY_Q, true)
	await q(3)
	tecla(KEY_Q, false)
	var r := {"rolando": d.rolando(), "clipe": d.clipe(), "imune_no_meio": false, "recarga": d.recarga()}
	await q(25)
	r["imune_no_meio"] = j.get_meta("damage_immune", false)
	var guarda := 0
	while d.rolando() and guarda < 200:               # até o roll acabar (sem contar o andar depois)
		await physics_frame
		guarda += 1
	r["delta"] = j.global_position - p0
	for t in teclas:
		tecla(t, false)
	await q(2)
	r["acabou"] = not d.rolando()
	r["imune_no_fim"] = j.get_meta("damage_immune", false)
	r["frente"] = frente
	return r
func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_esquiva_ef.json"))
	modo.set("progresso_forcado", "user://test_esquiva_ef.json")
	root.get_node("GameFlow").start_story()
	await q(150)
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var j = get_first_node_in_group("player")
	j.global_position = Vector3(0, 1.0, 0)
	# 1) com arma do mod, sem tecla de direção → roll_forward
	prog.equipar_lamina("ef_iron_longsword", true)
	await q(30)
	var r = await rolar(j, [])
	ok(r.rolando and r.clipe.ends_with("ef_roll_forward.res"), "arma do EF, sem direção: toca roll_forward (%s)" % r.clipe)
	ok(r.recarga == 0.0, "o roll do mod não tem recarga própria (só estamina)")
	ok(r.imune_no_meio, "invulnerável no meio do clipe")
	ok(r.acabou and not r.imune_no_fim, "acabou o clipe: vulnerável de novo")
	var andou: float = Vector2(r.delta.x, r.delta.z).length()
	ok(andou > 3.6 and andou < 5.6, "andou ~4,6 m pela curva do clipe (%.2f m)" % andou)
	ok((r.delta as Vector3).normalized().dot(r.frente) > 0.9, "para a frente da câmera")
	# 2) S → roll_backward, anda para trás
	var r2 = await rolar(j, [KEY_S])
	ok(r2.rolando and r2.clipe.ends_with("ef_roll_backward.res"), "S: toca roll_backward (%s)" % r2.clipe)
	ok((r2.delta as Vector3).normalized().dot(r2.frente) < -0.9, "anda para TRÁS")
	var a2: float = Vector2(r2.delta.x, r2.delta.z).length()
	ok(a2 > 3.6 and a2 < 5.6, "roll de costas também ~4,6 m (%.2f m)" % a2)
	# 3) sem arma do mod, o roll antigo (8 m, clipe do Mixamo) segue igual
	j.get_node("EspadaDaHistoria").limpar_lamina_ef()
	await q(30)
	var r3 = await rolar(j, [])
	ok(r3.rolando and r3.clipe == DashController.CLIPE, "sem arma do EF: o roll antigo do Mixamo (%s)" % r3.clipe)
	var a3: float = Vector2(r3.delta.x, r3.delta.z).length()
	ok(a3 > 6.5, "o roll antigo continua com ~8 m (%.2f m)" % a3)
	print("test_esquiva_epic_fight: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
