class_name TrainingDummy
extends CharacterBody3D
## Boneco de treino (Fase 9) — usa o CORPO DO PLAYER (base). Fica imóvel no centro
## pra testar skills. Toma dano + KNOCKBACK (voa). Regras de reset:
##  - caiu do mapa (y < VOID) -> volta pro topo (mantém HP);
##  - morreu (HP<=0) OU 30s sem receber dano -> vida cheia + volta ao centro.
## Está no grupo "enemy" pra as skills (DamageZone + tornado da Suna) o afetarem.

const MAX_HP := 1000.0
const RESET_AFTER := 30.0          # segundos sem dano -> reseta
const CENTER := Vector3(0, 4, -8)   # à frente do spawn do player (não sobrepõe)
const VOID_Y := -40.0
const GRAVITY := 32.0
const MODEL_TARGET_H := 1.7
const FEET_Y := -0.8
const FRICTION := 10.0

var health := MAX_HP
var _since_damage := 0.0
var _model: Node3D
var _ap: AnimationPlayer


func _ready() -> void:
	add_to_group("enemy")           # alvo das skills
	add_to_group("dummy")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.6, 1.0)
	col.shape = shape
	add_child(col)
	var built := CharacterBuilder.build_character("base")
	_model = built["node"]
	add_child(_model)
	var ap = built.get("anim_player")
	if ap:
		ap.active = false            # como o Player faz: sem AnimationPlayer brigando
		_ap = ap
	_fit_model()

func _physics_process(delta: float) -> void:
	# CONGELADO (Hie Hie): fica imóvel enquanto durar o gelo.
	if has_meta("is_frozen") and get_meta("is_frozen"):
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	if (has_meta("in_vortex") and get_meta("in_vortex")) or (has_meta("in_kurouzu") and get_meta("in_kurouzu")) or (has_meta("in_black_hole") and get_meta("in_black_hole")):
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	# atrito horizontal: o knockback empurra e depois desacelera (o boneco "volta").
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
	move_and_slide()

	_since_damage += delta
	if global_position.y < VOID_Y:
		_reset(false)                # caiu -> volta pro topo (mantém HP)
	elif health <= 0.0 or _since_damage >= RESET_AFTER:
		_reset(true)                 # morreu ou 30s sem dano -> HP cheio + centro

func take_damage(amount: float, _from_pos: Vector3 = Vector3.ZERO, knockback: Vector3 = Vector3.ZERO) -> void:
	if get_meta("damage_immune", false) or get_meta("custom_pose", "") == "hibashira" or get_meta("in_black_hole", false):
		return
	health -= amount
	# Feedback de dano: pisca vermelho, número flutuante, som e contador na HUD.
	FxUtil.flash_red(_model)
	FxUtil.damage_number(get_tree().current_scene, global_position + Vector3.UP * 1.7, amount, Color(1.0, 0.9, 0.35))
	AudioFX.hurt(get_tree().current_scene, global_position + Vector3.UP * 1.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("add_damage_dealt"):
		hud.add_damage_dealt(amount)
	if knockback.length() > 0.1:
		var kb := knockback
		if not is_on_floor():
			kb *= 2.0
		# Correção de knockback: impede deslizamento absurdo se o golpe vier de cima
		if kb.y < 0.0 and is_on_floor():
			kb.y = 0.0
			kb.x *= 0.2
			kb.z *= 0.2
		kb.y = clampf(kb.y, -30.0, 30.0)
		velocity += kb
	_since_damage = 0.0

func _reset(full: bool) -> void:
	global_position = CENTER
	velocity = Vector3.ZERO
	_since_damage = 0.0
	if full:
		health = MAX_HP

# ---- ajuste do modelo (mesma ideia do Player._fit_model_to_body) ----
func _fit_model() -> void:
	if _model == null:
		return
	var ab := _model_aabb(_model)
	var ky := 1.0
	if ab.size.y > 0.01:
		ky = MODEL_TARGET_H / ab.size.y
	_model.scale = Vector3(ky, ky, ky * 1.85)
	_model.position.y = FEET_Y - ky * ab.position.y

func _model_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in _meshes(root):
		var a: AABB = mi.get_aabb()
		var rel: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		var wa: AABB = rel * a
		if first:
			out = wa
			first = false
		else:
			out = out.merge(wa)
	return out

func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out += _meshes(c)
	return out
