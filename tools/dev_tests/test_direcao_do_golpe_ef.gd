extends SceneTree
## Golpe do Epic Fight (13/11/2026, queixa do dono: "ao golpear a direção em que o personagem vira está errada" e "a espada cria uma nova espada no inventário"):
##  • o corpo vira para a MIRA no 1º quadro do golpe e o avanço do clipe (`Corpo:deslocamento`) vai para a frente do corpo, com a câmera em qualquer ângulo;
##  • empunhar a arma `ef:` NÃO cria um `jogo:espada` a mais (nem na hotbar nem na mochila).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_direcao_do_golpe_ef.gd
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_direcao_ef.json"))
	modo.set("progresso_forcado", "user://test_direcao_ef.json")
	root.get_node("GameFlow").start_story()
	await q(150)
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var ex: ExecutorCorpoACorpo = j.get("combate_direcional")
	var cm: Node3D = j.get("_char_model")
	for arma in ["ef_iron_longsword", "ef_iron_spear"]:
		if not LaminasEpicFight.existe(arma):
			continue
		prog.equipar_lamina(arma, true)
		await q(40)
		ok(prog.item_em_uso() == "espada", "%s: a arma fica na mão" % arma)
		ok(prog.inventario.contar(ItensDoJogo.tag("espada")) == 0, "%s: nenhum `jogo:espada` criado no inventário" % arma)
		for graus in [0, 90, 180, -90]:
			j.set("_yaw", deg_to_rad(graus))
			await q(40)
			var yaw := float(j.get("_yaw"))
			var p0: Vector3 = j.global_position
			ex.pedir_ataque(0)
			await q(3)
			ok(absf(wrapf(cm.rotation.y - yaw, -PI, PI)) < 0.05, "%s yaw %d: o corpo olha para a mira no golpe" % [arma, graus])
			await q(87)
			var d: Vector3 = j.global_position - p0
			var fr := Vector3(-sin(yaw), 0, -cos(yaw))
			var frente := d.dot(fr)
			var lado := d.dot(fr.cross(Vector3.UP))
			ok(frente > 0.1 and absf(lado) < 0.2 * frente, "%s yaw %d: o avanço vai para a frente da mira (frente %.2f, lado %.2f)" % [arma, graus, frente, lado])
			await q(40)
	print("test_direcao_do_golpe_ef: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
