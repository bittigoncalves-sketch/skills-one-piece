extends Node3D
## Efeito finito: relógio local cancelável e hitbox no funil autoritativo comum.
const Forma := preload("res://src/effects/phoenix/forma_phoenix.gd")
var ator: Node3D
var spec: DamageSpec
var tipo := "X"
var rumo := Vector3.FORWARD
var tempo := 0.0
var zona: DamageZone
var disparou := false
var aneis: Array[MeshInstance3D] = []
var plumas: Array[Node3D] = []

func _ready() -> void:
	add_to_group("phoenix_efeito")
	var mat := Forma.material(Color("21cfff"), 1.2)
	for i in 3:
		var n := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.965
		torus.outer_radius = 1.0
		n.mesh = torus
		n.material_override = mat if i != 1 else Forma.material(Color("ffcd65"), 0.8)
		add_child(n)
		n.rotation = Vector3(i*0.6, 0, i*0.8)
		aneis.append(n)
	if tipo != "X":
		for i in 28:
			var p := Forma.pena(1.6, 0.25, 0.3, Forma.chama())
			add_child(p)
			p.rotation = Vector3(0.45, i*TAU/28, 0)
			plumas.append(p)
	if tipo == "X":
		Forma.volume(self, Vector3.ZERO, Vector3(0.6,0.6,1.2), mat)
		for i in 9:
			var p := Forma.pena(1.3, 0.09, 0.18, mat)
			add_child(p)
			p.rotation = Vector3(PI/2, 0, i*TAU/9)
			p.position = Vector3(cos(i*TAU/9)*0.4, sin(i*TAU/9)*0.4, 0.25)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(ator) or ator.current_fruit_id != "tori_tori_phoenix" or ator.health <= 0:
		queue_free()
		return
	tempo += delta
	if not disparou and ator.fruta_bloqueada_por_dano():
		queue_free()
		return
	if tipo == "C": global_position = ator.global_position + Vector3.UP*0.55
	var preparo := 0.22 if tipo == "X" else 0.45
	if not disparou and tempo >= preparo:
		disparou = true
		if tipo in ["X", "V"]:
			zona = DamageZone.new()
			add_child(zona)
			zona.setup(spec.dano, 12.0 if tipo == "X" else 18.0, Vector3.ZERO, 1.6 if tipo == "X" else 0.25, ator, 0.85 if tipo == "X" else 6.0)
			zona.collision_mask = 15
			zona.feedback_global = false
			spec.marcar(zona)
			zona.exige_linha_de_visao = tipo == "V"
			zona.origem_linha_de_visao = global_position
			AudioFX.impact(self, global_position, 1.2 if tipo == "X" else 0.8)
			if tipo == "X":
				zona.is_projectile = true
				zona.hit_landed.connect(func(_alvo: Node): queue_free())
				zona.collided_with_any.connect(func(_alvo: Node): queue_free())
		if tipo == "V" and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
			ator.health = minf(ator.max_health, ator.health + ator.max_health*0.25)
			if multiplayer.has_multiplayer_peer(): ator.net_vida_do_servidor.rpc(ator.health, 0.0)
	if tipo == "X" and disparou:
		var antes := global_position
		global_position += rumo*30.0*delta
		if is_instance_valid(zona): zona._varrer_caminho(antes, global_position)
	for i in aneis.size():
		var raio := (0.45+i*0.15) if tipo == "X" else lerpf(0.3, 6.0, clampf((tempo-preparo)/0.5, 0, 1))
		aneis[i].scale = Vector3.ONE*maxf(0.03, raio)
		aneis[i].rotate_y(delta*(2+i))
		if tempo > 1.1: aneis[i].scale *= maxf(0.01, (1.6-tempo)/0.5)
	for i in plumas.size():
		var angulo := i*TAU/plumas.size()
		var raio := lerpf(0.4, 6.0, clampf((tempo-preparo)/0.5, 0, 1))
		plumas[i].position = Vector3(cos(angulo)*raio, sin(tempo*7+i)*0.3, sin(angulo)*raio)
		plumas[i].scale = Vector3.ONE*maxf(0.01, 1.6-tempo)
	if tempo > (1.8 if tipo == "X" else 1.6): queue_free()
