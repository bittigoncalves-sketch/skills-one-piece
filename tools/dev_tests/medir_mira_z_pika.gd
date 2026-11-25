extends SceneTree
# ============================================================================
#  MIRA DO Z DA PIKA — medição (07/10/2026). Não conserta nada: mede.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/medir_mira_z_pika.gd
#
#  Pedido do dono: "calibrar a mira do laser Z". Para cada alvo, o retículo é posto
#  no peito do boneco pela CÂMERA (como o jogador mira) e o Z sai pela entrada de
#  verdade. Mede:
#    • retículo → ponto onde a linha do raio passa mais perto (erro da mira, m);
#    • de onde o raio nasce × a mão direita (Hand_R) (m);
#    • se o boneco levou o dano.
#  Mapa e progresso de TESTE; a Pika é a publicada no projeto.
# ============================================================================

const MAPA := "user://medir_mira_z_pika_mapa.json"
const PROGRESSO := "user://medir_mira_z_pika.json"
const CASOS := [
	{"nome": "reto 16 m", "alvo": Vector3(0.0, 1.0, -16.0)},
	{"nome": "direita 20 m", "alvo": Vector3(7.0, 1.0, -20.0)},
	{"nome": "esquerda 12 m", "alvo": Vector3(-8.0, 1.0, -12.0)},
	{"nome": "perto 5 m", "alvo": Vector3(1.0, 1.0, -5.0)},
	{"nome": "longe 34 m", "alvo": Vector3(-4.0, 1.0, -34.0)},
]

var p: Node3D
var cam: Camera3D


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _quadros(150)
	p = get_first_node_in_group("player")
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta("pika_pika")
	await _quadros(30)
	cam = p.get("_cam")
	var piores := 0.0
	for caso: Dictionary in CASOS:
		var b := BonecoDeDuelo.new()
		b.position = caso.alvo
		current_scene.add_child(b)
		await _lugar(Vector3(0, 0.8, 0))
		b.call("parar")
		var peito: Vector3 = b.global_position + Vector3.UP * 0.4
		await _mirar_em(peito)
		var retic := _ponto_do_reticulo()
		var vida0 := float(b.health)
		var mao := p.find_child("Hand_R", true, false) as Node3D
		p.set("energy", float(p.get("max_energy")))
		(p.get("_fruit_cooldowns") as Dictionary)["Z"] = 0.0
		p.begin_charge("Z")
		await physics_frame
		p.release_charge("Z")
		var linha := {}
		var mao_no_disparo := Vector3.INF
		for i in 40:
			await physics_frame
			if linha.is_empty():
				linha = _linha_do_raio()
				if not linha.is_empty() and mao != null:
					mao_no_disparo = mao.global_position
		var erro := INF
		var nasce_da_mao := INF
		if not linha.is_empty():
			var de: Vector3 = linha.de
			var dir: Vector3 = linha.dir
			var t := maxf(0.0, (retic - de).dot(dir))
			erro = retic.distance_to(de + dir * t)
			if mao_no_disparo.is_finite():
				nasce_da_mao = de.distance_to(mao_no_disparo)
		var dano := vida0 - float(b.health)
		piores = maxf(piores, erro)
		print("%-14s retículo %s | erro da linha %.2f m | raio nasce a %.2f m da mão | dano %.1f" % [
			caso.nome, retic.snapped(Vector3.ONE * 0.01), erro, nasce_da_mao, dano])
		b.queue_free()
		await _quadros(330)          # recarga do Z (5 s) não importa: zera; espera o raio sumir
	print("PIOR ERRO DA LINHA: %.2f m" % piores)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(0)


## O que o retículo marca: o raio da câmera (o mesmo de `Player.mira_do_cast`).
func _ponto_do_reticulo() -> Vector3:
	var frente := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + frente * 150.0)
	q.exclude = [(p as CollisionObject3D).get_rid()]
	q.collision_mask = ~HurtboxDeCombate.CAMADA & 0xFFFFFFFF
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else cam.global_position + frente * 150.0


## Início e rumo do VFX "Feixe" do Z em curso ({} se ainda não nasceu).
func _linha_do_raio() -> Dictionary:
	for e in current_scene.find_children("SkillBuilder_pika_raio_z", "", true, false):
		var estado: Dictionary = e.get("_estado")
		for ev: Dictionary in (e.get("skill") as Dictionary).get("eventos", []):
			if str(ev.tipo) == "vfx" and str(ev.get("parametros", {}).get("estilo", "")) == "Feixe":
				var st: Dictionary = estado.get(ev.id, {})
				if st.has("no") and is_instance_valid(st.no):
					var fx := st.no as Node3D
					return {"de": fx.global_position, "dir": -fx.global_basis.z.normalized()}
	return {}


func _mirar_em(ponto: Vector3) -> void:
	for i in 30:
		var d := (ponto - cam.global_position).normalized()
		p.set("_yaw", atan2(-d.x, -d.z))
		p.set("_pitch", asin(clampf(d.y, -1.0, 1.0)))
		p.call("_update_pivot")
		await process_frame


func _lugar(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await _quadros(20)


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
