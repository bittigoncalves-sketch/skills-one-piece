class_name CorteHorizontal
extends Node3D
## O corte lançado do X do machado (17/10/2026): uma meia-lua plana, na horizontal, que sai
## do golpe e atravessa tudo à frente até o fim do alcance. Fere cada inimigo UMA vez.
##
## Só o dono do corpo o cria (mesma regra do `MachadoLancado`).

const Sweep := preload("res://src/combat/SwordSweep.gd")
const MASCARA_DE_ALVOS := 15 | (1 << 20)
const VELOCIDADE := 19.0
const VIDA := 0.55            # s → ~10 m de alcance
const LARGURA := 3.2          # m, ponta a ponta da lua
const ALTURA := 0.9           # m de espessura do corte (o que ele acerta acima/abaixo)
const PROFUNDIDADE := 0.5
const DANO := 20.0
const EMPURRAO := 8.0

var dono: Node3D
## Dano e cor próprios (21/11/2026: a meia-lua das lâminas de madeira reaproveita este corte com a madeira como tema).
var dano := DANO
var cor := Color(0.85, 0.95, 1.0)
var cor_emissiva := Color(0.55, 0.8, 1.0)
var direcao := Vector3.FORWARD
var _tempo := 0.0
var _feridos := {}
var _malha: MeshInstance3D
var _material: StandardMaterial3D


static func criar(quem: Node3D, origem: Vector3, rumo: Vector3, dano_ := DANO, cor_ := Color(0.85, 0.95, 1.0), emissiva_ := Color(0.55, 0.8, 1.0)) -> CorteHorizontal:
	var c := CorteHorizontal.new()
	c.dano = dano_
	c.cor = cor_
	c.cor_emissiva = emissiva_
	c.name = "CorteHorizontal"
	c.dono = quem
	rumo.y = 0.0
	c.direcao = rumo.normalized() if rumo.length() > 0.01 else -quem.global_basis.z
	quem.get_parent().add_child(c)
	c.global_position = origem
	c.global_basis = Basis.looking_at(c.direcao, Vector3.UP)
	return c


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(cor.r, cor.g, cor.b, 0.85)
	_material.emission_enabled = true
	_material.emission = cor_emissiva
	_malha = MeshInstance3D.new()
	_malha.mesh = _meia_lua()
	_malha.material_override = _material
	add_child(_malha)


func _physics_process(delta: float) -> void:
	_tempo += delta
	if _tempo >= VIDA or not is_instance_valid(dono):
		queue_free()
		return
	var de := global_position
	var para := de + direcao * VELOCIDADE * delta
	var espaco := get_world_3d().direct_space_state
	var excluir: Array[RID] = []
	if dono is CollisionObject3D:
		excluir.append((dono as CollisionObject3D).get_rid())
	# Parede à frente: o corte morre nela (o chão não conta, ele corre a meia altura).
	var raio := PhysicsRayQueryParameters3D.create(de, para + direcao * 0.3, 1, excluir)
	var bateu := espaco.intersect_ray(raio)
	if not bateu.is_empty() and not (bateu.collider as Object).has_method("take_damage") \
			and not HurtboxDeCombate.e_hurtbox(bateu.collider) and absf(bateu.normal.y) < 0.5:
		queue_free()
		return
	global_position = para
	_ferir(espaco, excluir)
	var u := _tempo / VIDA
	# Cresce um pouco e some nos últimos 40% do caminho.
	_malha.scale = Vector3.ONE * lerpf(0.85, 1.25, u)
	_material.albedo_color.a = 0.85 * clampf((1.0 - u) / 0.4, 0.0, 1.0)


func _ferir(espaco: PhysicsDirectSpaceState3D, excluir: Array[RID]) -> void:
	var forma := BoxShape3D.new()
	forma.size = Vector3(LARGURA, ALTURA, PROFUNDIDADE)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = global_transform
	consulta.collision_mask = MASCARA_DE_ALVOS
	consulta.exclude = excluir
	for hit in espaco.intersect_shape(consulta, 32):
		var alvo := HurtboxDeCombate.dono_de(hit.collider) as Node3D
		if alvo == null or not alvo.is_in_group("enemy") or _feridos.has(alvo.get_instance_id()):
			continue
		if alvo.get("health") == null or float(alvo.get("health")) <= 0.0:
			continue
		_feridos[alvo.get_instance_id()] = true
		var para_fora := alvo.global_position - dono.global_position
		para_fora.y = 0.0
		CombatResolver.aplicar(alvo, dano, 0, 0.0, alvo.global_position + Vector3.UP,
			(direcao * 0.6 + para_fora.normalized() * 0.4).normalized() * EMPURRAO, 0.3, 0.0, false, dono)


## Meia-lua plana (convexa para a frente, −Z): grossa no meio, afinando nas pontas.
static func _meia_lua() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var passos := 28
	var raio := LARGURA * 0.5 / sin(deg_to_rad(62.0))
	var espessura := 0.55
	var y := 0.03
	for i in passos:
		var a0 := lerpf(-62.0, 62.0, float(i) / passos)
		var a1 := lerpf(-62.0, 62.0, float(i + 1) / passos)
		var p := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
		for k in 2:
			var a := deg_to_rad(a0 if k == 0 else a1)
			var fino := cos(a / deg_to_rad(62.0) * PI * 0.5)
			var externo := Vector3(sin(a) * raio, 0.0, -cos(a) * raio + raio)
			var interno := externo + Vector3(0.0, 0.0, espessura * fino)
			p[k] = externo
			p[3 - k] = interno
		for face in [[0, 1, 2], [0, 2, 3]]:
			for idx in face:
				st.add_vertex((p[idx] as Vector3) + Vector3(0.0, y, 0.0))
	return st.commit()
