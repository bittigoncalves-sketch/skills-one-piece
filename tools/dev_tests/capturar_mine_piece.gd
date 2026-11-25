extends SceneTree
## Captura com render dos golpes das frutas "(Mine Piece)" no Modo História (17/10/2026).
##   "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_mine_piece.gd
## Três quadros por golpe (preparo, acerto, final) em art_src/validation/mine_piece/.

const PASTA := "res://art_src/validation/mine_piece"
## fruta → [[tecla, distância do alvo (m), segurar (quadros; 0 = toque)]]
const CASOS := {
	"pika_pika_no_mi_mine_piece": [["Z", 12.0, 50], ["X", 6.0, 0], ["C", 4.0, 0]],
	"hie_hie_no_mi_mine_piece": [["Z", 10.0, 0], ["X", 10.0, 40], ["C", 10.0, 0]],
	"moku_moku_no_mi_mine_piece": [["Z", 7.0, 0]],
	"nikyu_nikyu_no_mi_mine_piece": [["Z", 7.0, 30], ["X", 7.0, 0], ["C", 5.0, 0]],
}

var p: Node3D
var alvo: Node3D
## `-- esquerda` fotografa do outro lado (a favor do sol do mapa de teste).
var LADO := 1.0


class Alvo extends StaticBody3D:
	var health := 5000.0
	func take_damage(d: float, _origem := Vector3.ZERO, _kb := Vector3.ZERO, _stun := 0.0) -> void:
		health -= d


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await physics_frame


func _limpar(distancia: float) -> void:
	for e in current_scene.find_children("SkillBuilder_*", "", true, false): e.queue_free()
	await frames(3)
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p.health = p.max_health
	for campo in ["_fruit_cooldowns", "_skill_cooldowns", "_server_cast_next_ms"]:
		if campo in p: (p.get(campo) as Dictionary).clear()
	for campo in ["_intervalo_golpe", "_trava_pos_fruta", "_fruit_damage_lock_timer"]:
		if campo in p: p.set(campo, 0.0)
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	alvo.position = Vector3(0, 1, -distancia)
	alvo.health = 5000.0
	await frames(5)


func _foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s%s.png" % [PASTA, nome, "" if LADO > 0.0 else "_esq"])


func _rodar() -> void:
	await process_frame
	if OS.get_cmdline_user_args().has("esquerda"):
		LADO = -1.0
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://capturar_mine_piece.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	alvo = Alvo.new()
	alvo.collision_layer = 1
	var col := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = .5
	forma.height = 1.8
	col.shape = forma
	alvo.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	alvo.add_child(mesh)
	current_scene.add_child(alvo)
	alvo.add_to_group("enemy")
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	for fid: String in CASOS:
		current_scene.progressao.comer_fruta(fid)
		await frames(5)
		p.combat_mode = "fruit"
		for caso: Array in CASOS[fid]:
			var tecla: String = caso[0]
			var s := KitDoBuilder.skill(tecla, fid)
			var duracao := float(s.configuracoes.duracao)
			await _limpar(float(caso[1]))
			cam.current = true
			cam.global_position = Vector3(LADO * 7.0, 3.0, 4.0)
			cam.look_at(Vector3(0, 1.2, -float(caso[1]) * 0.5))
			var segurar := int(caso[2])
			var nome := "%s_%s" % [fid.get_slice("_", 0), tecla]
			p.begin_charge(tecla)
			if segurar > 0:
				await frames(segurar)
				await _foto(nome + "_1_carga")
			else:
				await frames(1)
			p.release_charge(tecla)
			# Depois de soltar: perto do golpe e no fim (em quadros de física, 60/s).
			var resto := maxf(duracao - float(segurar) / 60.0, 0.4)
			if segurar == 0:
				await frames(int(resto * 60.0 * 0.25))
				await _foto(nome + "_1_preparo")
			await frames(int(resto * 60.0 * 0.3))
			await _foto(nome + "_2_acerto")
			await frames(int(resto * 60.0 * 0.35))
			await _foto(nome + "_3_final")
			await frames(40)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
