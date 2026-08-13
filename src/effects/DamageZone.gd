class_name DamageZone
extends Area3D
# Área de dano móvel: aplica dano + knockback em corpos com take_damage() (menos
# o próprio caster). Já pronta para inimigos futuros; hoje só não acha alvos.

const DAMAGE_SCALE := 0.12   # foco é knockback, não dano -> dano bem baixo

var damage: float = 0.0
var knockback: float = 0.0
var vel: Vector3 = Vector3.ZERO
var caster: Node = null
var _hit: Dictionary = {}

# Cria a colisão e a agenda de vida. Chamar logo após add_child.
func setup(dmg: float, kb: float, velocity: Vector3, life: float, caster_node: Node, radius: float) -> void:
	damage = dmg
	knockback = kb
	vel = velocity
	caster = caster_node

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	add_child(col)

	body_entered.connect(_on_body)
	FxUtil.autofree(self, life)

# PARALISIA opcional: > 0 = o alvo congela por esse tempo em vez de ser
# empurrado. Usado pelos raios do El Thor, que prendem em vez de arremessar.
var paralisa: float = 0.0

func _physics_process(delta: float) -> void:
	if vel == Vector3.ZERO:
		return
	var antes := global_position
	global_position += vel * delta
	_varrer_caminho(antes, global_position)

# ⚠️ PROJÉTIL RÁPIDO ATRAVESSAVA O ALVO — e ninguém sabia.
#
# A zona anda por TELEPORTE (`global_position += vel * delta`), e a `Area3D` só
# enxerga quem está sobreposto NAQUELE quadro. A 60 Hz o passo é `vel / 60`:
# com alvo de 1,0 m e raio 0,16, a janela de acerto é ~1,32 m, ou seja acima de
# ~79 m/s a bala pula o alvo entre dois quadros.
#
# Medido em 2026-08-12 (24 disparos por velocidade):
#     79 m/s -> 24/24 acertos      125 m/s -> 16/24
#     95 m/s -> 20/24              200 m/s ->  9/24
# A sniper estava em 95: perdia 1 tiro em 6, sem o jogador ter como saber.
#
# Sub-passo de POSIÇÃO não resolve: a `Area3D` detecta uma vez por quadro de
# física, então mover em pedaços dentro do mesmo quadro não gera detecção nova.
# O que resolve é VARRER O CAMINHO com um raio — o que a bala passou por cima
# conta como acerto.
func _varrer_caminho(de: Vector3, ate: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return                      # só o servidor decide acerto
	var mundo := get_world_3d()
	if mundo == null:
		return
	var par := PhysicsRayQueryParameters3D.create(de, ate)
	par.collide_with_areas = false
	par.collide_with_bodies = true
	if is_instance_valid(caster) and caster is CollisionObject3D:
		par.exclude = [(caster as CollisionObject3D).get_rid()]
	var hit := mundo.direct_space_state.intersect_ray(par)
	if hit.is_empty():
		return
	var corpo = hit.get("collider")
	if corpo is Node3D and not _hit.has(corpo):
		_on_body(corpo as Node3D)

func _on_body(body: Node3D) -> void:
	# Autoridade de combate: só o SERVIDOR aplica dano/knockback. Em clientes a zona
	# é apenas visual/inerte (sem peer = SP -> is_server true -> aplica normalmente).
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if body == caster or _hit.has(body):
		return
	if body.has_method("take_damage"):
		_hit[body] = true
		var dir: Vector3 = body.global_position - global_position
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
		var kb: Vector3 = dir * knockback + Vector3.UP * knockback * 0.35
		# PARALISIA: prende em vez de arremessar. O `is_frozen` é o mesmo sinal
		# que o gelo já usa, e o `_etapa_travamento` do Player o respeita.
		if paralisa > 0.0:
			kb = Vector3.ZERO
			body.set_meta("is_frozen", true)
			StatusFX.aplicar(body, StatusFX.CONGELADO, paralisa)
			var t := get_tree().create_timer(paralisa)
			t.timeout.connect(func():
				if is_instance_valid(body):
					body.set_meta("is_frozen", false))
		# Dano BAIXO de propósito: o foco é o KNOCKBACK jogar o alvo pra fora do mapa.
		body.take_damage(damage * DAMAGE_SCALE, global_position, kb)
		# Crédito de kill: registra quem bateu por último em quem. Se o alvo cair
		# do mapa nos próximos segundos, a kill é de quem empurrou.
		var placar := get_tree().get_first_node_in_group("scoreboard")
		if placar and placar.has_method("register_hit"):
			placar.register_hit(body, caster)
		# Camera Feel no impacto: micro-pausa + flash quente + aberração cromática.
		var gf := get_node_or_null("/root/GameFlow")
		if gf and gf.has_method("hit_stop"):
			gf.hit_stop()
		var sfx := get_node_or_null("/root/ScreenFX")
		if sfx and sfx.has_method("flash"):
			sfx.flash(Color(1.0, 0.9, 0.6), 0.22)
			sfx.chromatic_pulse(0.5)
