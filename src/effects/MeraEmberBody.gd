extends Node3D
## Corpo QUENTE e persistente da Mera: o punho do Hiken e o sol do Entei.
##
## Os dois são a mesma ideia — crosta de brasa por dentro, coroa de chama por
## fora —, mudando só escala e silhueta. Vale o mesmo argumento do
## `OpeSurgicalBurst`: um nó com modo, em vez de dois arquivos quase iguais.
##
## O QUE ISSO SUBSTITUI: o punho era um `MultiMesh` de ~60 caixas laranjas
## chapadas (`FireFX._voxel_material`) e o sol, caixas empilhadas. Caixa não tem
## silhueta de fogo; num quadro parado, o Hiken lia como um bloco. Aqui a crosta
## é deslocada por ruído no vértice (o mesmo recurso do `ope_rock.gdshader`) e a
## coroa dá o contorno.
##
## ⚠️ NÃO CAUSA DANO. É filho da `DamageZone`, e quem a move é ela.

const GEO := preload("res://src/effects/MeraGeometry.gd")

var mode := "fist"          # "fist" | "sun" | "trail"
var body_radius := 1.0
var direction := Vector3.FORWARD
## Núcleo em blocos em vez de esfera. O Entei se chama **Sol Quadrado** — a
## silhueta cúbica é o nome do golpe, não um acidente de implementação, então
## ela fica. O que muda é o material: era amarelo chapado, agora é crosta de
## magma com fenda acesa.
var faceted := false

var _age := 0.0
var _materiais: Array = []
var _crosta: ShaderMaterial
var _coroa: Node3D
var _nucleo: MeshInstance3D
var _nucleo_punho: MultiMeshInstance3D
var _heat := 1.0


func _ready() -> void:
	name = "MeraEmberBody_" + mode
	match mode:
		"sun": _montar_sol()
		"trail": _montar_rastro()
		_: _montar_punho()


func _montar_punho() -> void:
	# ⚠️ A SILHUETA VOLTOU A SER UM PUNHO (2026-09-08, segunda passagem). Na
	# primeira eu troquei os blocos por uma esfera achatada — e a captura
	# `03_hiken_punho.png` mostrou um meteoro. O golpe se chama **Punho** de
	# Fogo; a forma é o nome, do mesmo jeito que o quadrado é o nome do Sol
	# Quadrado. O que mudou em relação ao original é a SUPERFÍCIE.
	var bloco := body_radius * 0.37   # 1,35 de raio reproduz o `bs = 0.5` antigo
	# `feature_scale` é o tamanho do PUNHO (não do bloco): a fenda tem que ter a
	# escala da peça inteira. E `heat` fica em 0,85, não 1,0 — no máximo a crosta
	# também acende e o punho perde o contraste que dá volume.
	_crosta = GEO.ember_material(0.85, 1.0, 0.16, body_radius * 1.6)
	_materiais.append(_crosta)
	_nucleo_punho = GEO.fist_blocks(self, bloco, _crosta)

	# Os dedos apontam para -Z na disposição autorada, e `looking_at` alinha -Z
	# com a direção — então o punho voa de dedos à frente.
	var d := direction.normalized()
	if d.length_squared() > 0.01:
		var cima := Vector3.UP if absf(d.y) < 0.99 else Vector3.RIGHT
		_nucleo_punho.basis = Basis.looking_at(d, cima)

	var comprimento := body_radius * 2.6
	var chama := GEO.flame_material(comprimento, 2.1, 3.4, 0.48)
	_materiais.append(chama)
	_coroa = Node3D.new()
	add_child(_coroa)
	# A coroa cresce para +Y local; virar o nó faz o fogo escorrer para TRÁS.
	_coroa.rotation = _girar_para(-direction.normalized())
	GEO.plume(_coroa, 7, body_radius * 0.72, comprimento, body_radius * 0.30, chama)


## Rastro de projétil: só chama, sem crosta. Vive enquanto o pai viver — é por
## isso que mora AQUI (corpo persistente) e não no `MeraFireBurst`, que se apaga
## sozinho no fim do próprio relógio.
func _montar_rastro() -> void:
	var comprimento := body_radius * 5.0
	var chama := GEO.flame_material(comprimento, 3.0, 5.0, 0.42)
	_materiais.append(chama)
	_coroa = Node3D.new()
	add_child(_coroa)
	_coroa.rotation = _girar_para(direction.normalized())
	for i: int in range(3):
		var pivot := Node3D.new()
		_coroa.add_child(pivot)
		pivot.rotate_object_local(Vector3.UP, float(i) * 2.09)
		pivot.rotate_object_local(Vector3.RIGHT, 0.14)
		# i vai de 0 a 2, então o fator vai de 0,6 a 1,0 — nunca acima do `span`.
		GEO.tongue(pivot, comprimento * (0.6 + 0.2 * float(i)),
			body_radius * 0.9, chama, float(i) * 2.7, 8, 5)


func _montar_sol() -> void:
	# O sol é simétrico: a coroa sobe em volta inteira. `heat` é dirigido pela
	# carga, então o núcleo acende conforme o jogador segura.
	# `feature_scale` = o raio do corpo: sem isso a fenda de um sol de raio 7 sai
	# com a frequência de um punho de raio 1 e vira chuvisco.
	# E o calor de base sobe de 0,35 para 0,7 — um SOL não pode ler como pedra
	# apagada nem no começo da carga.
	_crosta = GEO.ember_material(0.7, 3.0, 0.09, body_radius)
	_materiais.append(_crosta)
	if faceted:
		_montar_nucleo_quadrado()
	else:
		_nucleo = GEO.shell(self, body_radius, _crosta, 32)

	var chama := GEO.flame_material(body_radius * 1.9, 1.5, 2.0, 0.58)
	_materiais.append(chama)
	_coroa = Node3D.new()
	add_child(_coroa)
	GEO.plume(_coroa, 11, body_radius * 0.95, body_radius * 1.9, body_radius * 0.34, chama)
	# Meia coroa virada para baixo fecha a silhueta por cima e por baixo.
	var inferior := Node3D.new()
	add_child(inferior)
	inferior.rotation = Vector3(PI, 0.0, 0.0)
	GEO.plume(inferior, 7, body_radius * 0.85, body_radius * 1.35, body_radius * 0.28, chama)


## O núcleo em blocos: um cubo central e erupções em volta, do mesmo jeito que o
## `FireFX._build_sun_model` fazia. A diferença é o material — e o deslocamento
## de vértice do `mera_ember` tira o canto perfeito, então lê como rocha
## incandescente, não como caixa.
func _montar_nucleo_quadrado() -> void:
	var lado := body_radius * 2.0
	var central := BoxMesh.new()
	central.size = Vector3.ONE * lado
	_nucleo = GEO.instance(self, central, _crosta)

	# Determinístico: mesmo sol, mesma silhueta em toda partida e em todo peer.
	# `randf_range` aqui faria o sol do cliente ser outro sol.
	for i: int in range(24):
		var f := float(i)
		var tamanho := lado * (0.21 + 0.19 * absf(sin(f * 1.7)))
		var bloco := BoxMesh.new()
		bloco.size = Vector3(tamanho, tamanho * (0.8 + 0.4 * absf(sin(f * 2.3))), tamanho)
		var visual := GEO.instance(self, bloco, _crosta)
		visual.position = Vector3(sin(f * 2.399) * body_radius * 0.82,
			sin(f * 1.117 + 1.3) * body_radius * 0.82,
			cos(f * 2.399) * body_radius * 0.82)
		visual.rotation = Vector3(f * 0.41, f * 0.77, f * 0.29)


## Quanto o corpo está aceso, 0 a 1. O Entei liga isto na carga; o Hiken deixa
## em 1 o tempo todo.
func set_heat(value: float) -> void:
	_heat = clampf(value, 0.0, 1.0)
	if _crosta != null:
		_crosta.set_shader_parameter("heat", _heat)


func _process(delta: float) -> void:
	_age += delta
	GEO.advance(_materiais, _age)
	if _coroa != null and mode != "trail":
		# A coroa gira devagar: sem isso, o fogo parado lê como escultura. O
		# rastro não gira — ele já se move junto com o projétil.
		_coroa.rotate_object_local(Vector3.UP, delta * 1.35)


static func _girar_para(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	if d.length_squared() < 0.01:
		return Vector3.ZERO
	var eixo := Vector3.UP.cross(d)
	if eixo.length_squared() < 0.000001:
		return Vector3.ZERO if d.y > 0.0 else Vector3(PI, 0.0, 0.0)
	return Basis(eixo.normalized(), Vector3.UP.angle_to(d)).get_euler()
