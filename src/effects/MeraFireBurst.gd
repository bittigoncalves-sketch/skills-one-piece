extends Node3D
## Fogo TRANSITÓRIO da Mera: clarão de cano, impacto, explosão e a marca no chão.
##
## Um nó, vários modos — o mesmo desenho do `OpeSurgicalBurst`, que resolve
## shambles/gamma/impacto num arquivo só. O nó é dono do próprio tempo de vida e
## se apaga sozinho; quem chama não precisa agendar nada.
##
## ⚠️ ESTE ARQUIVO NÃO CAUSA DANO. Hitbox, autoridade e rede continuam com
## `FireFX`/`FireFXGrande`. É a mesma separação que a Ope faz entre `OpeVfx` e
## `OpeController`, e é o que permite mexer no visual sem tocar em balanceamento.

const GEO := preload("res://src/effects/MeraGeometry.gd")

const VIDA := {"muzzle": 0.22, "impact": 0.55, "explosion": 1.05, "scorch": 5.0}

var mode := "impact"
var scale_factor := 1.0
var direction := Vector3.FORWARD
## Onde o efeito deve aparecer. A fachada anexa de forma ADIADA (ver
## `MeraVfx._anexar`), então quem chama não pode escrever `global_position`
## direto — o nó ainda não está na árvore. O `_ready` aplica isto.
var spawn_global := Vector3.ZERO
var usar_spawn_global := false

var _age := 0.0
var _vida := 0.55
var _materiais: Array = []
var _anel: MeshInstance3D
var _anel_raio := 1.0
var _coroa: Node3D
var _marca: MeshInstance3D
var _marca_material: ShaderMaterial
## Raio pedido para a queimadura, ou 0 quando o modo não deixa marca.
## ⚠️ A marca NÃO nasce no `_ready`. `_ready` dispara dentro do `add_child`, e
## quem chama só escreve `global_position` DEPOIS — então traçar o chão ali
## media a origem do mundo, não o ponto do impacto. Num mapa com buracos isso
## desenhava queimadura no lugar errado (ou pendurada no ar). A Ope resolve o
## mesmo problema com um `project_floor()` explícito depois de posicionar; aqui
## a marca é montada no PRIMEIRO quadro, que é a mesma garantia sem depender de
## quem chama lembrar de uma segunda chamada.
var _marca_raio := 0.0
var _marca_pendente := false


func _ready() -> void:
	name = "MeraFireBurst_" + mode
	if usar_spawn_global:
		global_position = spawn_global
	_vida = float(VIDA.get(mode, 0.55))
	match mode:
		"muzzle": _montar_muzzle()
		"impact": _montar_impacto()
		"explosion": _montar_explosao()
		"scorch": _pedir_marca(scale_factor * 2.2)
		_: _montar_impacto()


# ------------------------------------------------------------------ montagem

func _montar_muzzle() -> void:
	# Curto, torcido e apontado para a frente: o cano cospe, não floresce.
	var comprimento := 0.85 * scale_factor
	var material := GEO.flame_material(comprimento, 2.6, 4.2, 0.35)
	_materiais.append(material)
	_coroa = Node3D.new()
	add_child(_coroa)
	_coroa.rotation = _girar_para(direction)
	for i: int in range(3):
		var pivot := Node3D.new()
		_coroa.add_child(pivot)
		pivot.rotation = Vector3(0.0, 0.0, 0.0)
		pivot.rotate_object_local(Vector3.UP, float(i) * 2.1)
		pivot.rotate_object_local(Vector3.RIGHT, 0.22 * float(i - 1))
		# Mesma regra do `GEO.plume`: nenhuma língua passa de `comprimento`, que é
		# o `span` do material.
		GEO.tongue(pivot, comprimento * (0.7 + 0.15 * float(i)), 0.16 * scale_factor,
			material, float(i) * 3.1, 7, 5)


## O impacto é o modo mais chamado da fruta — o C sozinho detona 45 vezes em
## cascata. Por isso ele ESCALA O CUSTO junto com o tamanho: impacto pequeno usa
## menos línguas, anel mais simples, e **não** consulta o chão. Um raycast por
## vagalume seriam 45 consultas ao espaço físico num intervalo de 2,25 s.
func _montar_impacto() -> void:
	var pequeno := scale_factor < 0.8
	var material := GEO.flame_material(1.5 * scale_factor, 1.9, 3.0, 0.5)
	_materiais.append(material)
	_coroa = Node3D.new()
	add_child(_coroa)
	var linguas := 3 if pequeno else 5
	for i: int in range(linguas):
		var ang := TAU * float(i) / float(linguas)
		var pivot := Node3D.new()
		_coroa.add_child(pivot)
		pivot.position = Vector3(cos(ang) * 0.45 * scale_factor, 0.0, sin(ang) * 0.45 * scale_factor)
		pivot.rotation = Vector3(sin(ang) * 0.42, -ang, -cos(ang) * 0.42)
		var aneis := 6 if pequeno else 11
		var lados := 5 if pequeno else 7
		GEO.tongue(pivot, 1.5 * scale_factor, 0.22 * scale_factor, material,
			float(i) * 1.618, aneis, lados)
	_anel_raio = 1.1 * scale_factor
	_anel = GEO.ring(self, _anel_raio, 0.07 * scale_factor, GEO.luminous(GEO.MID, 2.2))
	if not pequeno:
		_pedir_marca(scale_factor * 1.3)


func _montar_explosao() -> void:
	# A explosão lê pelo ANEL que abre, não pela nuvem: é o que dá escala.
	var material := GEO.flame_material(3.2 * scale_factor, 1.4, 2.2, 0.62)
	_materiais.append(material)
	_coroa = Node3D.new()
	add_child(_coroa)
	GEO.plume(_coroa, 9, 1.0 * scale_factor, 3.2 * scale_factor, 0.52 * scale_factor, material)
	var nucleo := GEO.ember_material(1.0, 2.0, 0.16)
	_materiais.append(nucleo)
	GEO.shell(self, 0.75 * scale_factor, nucleo, 20)
	# ⚠️ ANEL LARANJA E FINO, NÃO BRANCO E GROSSO. A primeira versão usava
	# `CORE` (branco-amarelo) com energia 2,6 e largura 0,14 — em mistura
	# aditiva isso estourou a tela inteira na captura `05_hiken_explosao.png`:
	# a explosão virou um clarão branco que apagou o cenário. O anel tem que dar
	# a MEDIDA do estouro, não ofuscar o que ele acertou.
	_anel_raio = 1.4 * scale_factor
	_anel = GEO.ring(self, _anel_raio, 0.07 * scale_factor, GEO.luminous(GEO.MID, 1.3))
	_pedir_marca(scale_factor * 2.6)


func _pedir_marca(raio: float) -> void:
	_marca_raio = raio
	_marca_pendente = true


## A marca fica no chão logo abaixo do efeito. Sem chão, sem marca — uma
## queimadura flutuando no ar é pior que queimadura nenhuma, e este mapa tem
## buracos.
func _montar_marca(raio: float) -> void:
	var chao := _chao_abaixo()
	if is_inf(chao):
		return
	_marca = GEO.scorch(self, raio)
	_marca.global_position = Vector3(global_position.x, chao + 0.02, global_position.z)
	_marca_material = _marca.material_override as ShaderMaterial
	if _marca_material != null:
		_materiais.append(_marca_material)


## Devolve a altura do chão, ou `INF` quando não há chão embaixo — sentinela em
## vez de `null` porque o projeto compila com aviso-como-erro, e um retorno
## `Variant` reprova o parse.
func _chao_abaixo() -> float:
	if not is_inside_tree():
		return INF
	var espaco := get_world_3d().direct_space_state
	var consulta := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.4, global_position + Vector3.DOWN * 6.0, 15)
	var acerto := espaco.intersect_ray(consulta)
	if acerto.is_empty():
		return INF
	return (acerto["position"] as Vector3).y


# ---------------------------------------------------------------------- tempo

func _process(delta: float) -> void:
	if _marca_pendente:
		_marca_pendente = false
		_montar_marca(_marca_raio)
	_age += delta
	var t := clampf(_age / _vida, 0.0, 1.0)

	# A chama nasce cheia e some pelo fim — o oposto de um fade linear, que lê
	# como diminuir o volume em vez de apagar.
	var presenca := 1.0 - pow(t, 1.7)
	GEO.advance(_materiais, _age, presenca)

	if _marca_material != null:
		# A marca sobrevive à chama: ela esfria devagar e some depois.
		var t_marca := clampf(_age / _vida, 0.0, 1.0)
		_marca_material.set_shader_parameter("cooling", pow(t_marca, 0.55))
		_marca_material.set_shader_parameter("presence", 1.0 - pow(t_marca, 3.0))

	if _coroa != null:
		var crescer := 0.35 + 0.65 * pow(t, 0.45)
		_coroa.scale = Vector3.ONE * crescer

	if _anel != null:
		# O anel abre rápido e afina: leitura de onda de choque.
		var abertura := 1.0 + 2.6 * pow(t, 0.5)
		_anel.scale = Vector3(abertura, 1.0, abertura)
		var mat := _anel.material_override as StandardMaterial3D
		if mat != null:
			# Queda acelerada: o anel é brilhante no primeiro instante e some
			# rápido. Linear deixava ele forte tempo demais no meio do efeito.
			GEO.fade(mat, pow(1.0 - t, 2.2) * 0.7)

	if _age >= _vida:
		queue_free()


static func _girar_para(dir: Vector3) -> Vector3:
	# As malhas crescem para +Y; alinhar +Y com `dir`.
	var d := dir.normalized()
	if d.length_squared() < 0.01:
		return Vector3.ZERO
	var eixo := Vector3.UP.cross(d)
	if eixo.length_squared() < 0.000001:
		return Vector3.ZERO if d.y > 0.0 else Vector3(PI, 0.0, 0.0)
	return Basis(eixo.normalized(), Vector3.UP.angle_to(d)).get_euler()
