extends Node3D
## Projétil não teleguiado: nasce na boca no quadro de disparo, para no cenário.
const Colisao := preload("res://src/historia/bestas_mar/colisao_agua.gd")
const KNOCKBACK := 12.0
const RAIO := 0.65
const VELOCIDADE := 18.0
var atirador: Node3D
var rumo := Vector3.FORWARD
var dano := 6.0
var idade := 0.0
var _malha: MeshInstance3D


func _ready() -> void:
	add_to_group("efeitos_agua_bestas")
	_malha = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = RAIO
	esfera.height = RAIO * 2
	_malha.mesh = esfera
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.22, 0.7, 0.95, 0.68)
	mat.metallic = 0.12
	mat.roughness = 0.12
	mat.rim_enabled = true
	mat.rim = 0.9
	mat.emission_enabled = true
	mat.emission = Color(0.06, 0.24, 0.38)
	_malha.material_override = mat
	add_child(_malha)
	# Brilhos de superfície dão leitura de água, mesmo longe da luz principal.
	for i in 2:
		var brilho := MeshInstance3D.new()
		var bola := SphereMesh.new()
		bola.radius = RAIO * (0.18 if i == 0 else 0.07)
		bola.height = bola.radius * 2
		brilho.mesh = bola
		brilho.position = Vector3(-0.26 + i * .25, 0.35, -0.45)
		var branco := StandardMaterial3D.new()
		branco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		branco.albedo_color = Color(0.75, 0.95, 1)
		brilho.material_override = branco
		_malha.add_child(brilho)


func _physics_process(delta: float) -> void:
	idade += delta
	if idade > 7.0 or not is_instance_valid(atirador) or atirador.get("health") <= 0:
		queue_free()
		return
	_malha.scale = Vector3.ONE * (1.0 + sin(idade * 9) * .045)
	var de := global_position
	var viagem := rumo * VELOCIDADE * delta
	var contato := Colisao.varrer(atirador, de, viagem, RAIO)
	if contato.colidiu:
		var alvo: Node = contato.alvo
		if is_instance_valid(alvo) and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
			CombatResolver.aplicar(alvo, dano, 0, 0.0, de, rumo * KNOCKBACK + Vector3.UP * 2, .25, 0, false, null, atirador)
		global_position = contato.posicao
		_estourar()
		return
	global_position += viagem


func _estourar() -> void:
	set_physics_process(false)
	var t := create_tween().set_parallel(true)
	t.tween_property(_malha, "scale", Vector3.ONE * 1.9, .16)
	t.tween_property(_malha, "transparency", 1.0, .16)
	t.chain().tween_callback(queue_free)
