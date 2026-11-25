extends SceneTree
## Golpe do Epic Fight não dobra o tronco além do limite (12/11/2026): espada longa, adaga e tachi chegavam a ~110° de inclinação.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_dobra_do_tronco_ef.gd
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
func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_dobra_ef.json"))
	modo.set("progresso_forcado", "user://test_dobra_ef.json")
	root.get_node("GameFlow").start_story()
	await q(150)
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var anim = j.get("_proc_anim")
	var ex: ExecutorCorpoACorpo = j.get("combate_direcional")
	for arma in ["ef_iron_longsword", "ef_iron_dagger", "ef_iron_tachi", "ef_iron_sword"]:
		if not LaminasEpicFight.existe(arma):
			continue
		prog.equipar_lamina(arma, true)
		await q(40)
		var pior := 0.0
		for golpe in 3:
			ex.pedir_ataque(0)
			for i in 40:
				await q(2)
				var cima: Vector3 = (anim._n["Torso"] as Node3D).quaternion * Vector3.UP
				pior = maxf(pior, cima.angle_to(Vector3.UP))
			await q(30)
		ok(pior <= 0.55, "%s: pior inclinação do tronco no golpe %.0f° (limite 29°)" % [arma, rad_to_deg(pior)])
	ok(anim.limite_da_dobra_do_tronco == 0.0 or is_equal_approx(anim.limite_da_dobra_do_tronco, 0.5), "o limite só vale durante o clipe do golpe")
	var arma = j.get_node_or_null("EspadaDaHistoria")
	ok(arma != null and not arma.giro.ligado and not arma.giro.alternar() and not arma.giro.ativo, "o giro cortante do Z está desligado (Z não faz nada)")
	print("test_dobra_do_tronco_ef: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
