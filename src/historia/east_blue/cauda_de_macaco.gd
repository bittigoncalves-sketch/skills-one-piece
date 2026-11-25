extends Node3D
## CAUDA DOS MACACOS HUMANOIDES (18/11/2026): 6 segmentos de cubo (voxel) presos às costas do `torso`, curvando para cima, balançando de leve (onda defasada
## por segmento; mais rápida quando o corpo anda — `velocidade` pode ser ligada por quem quiser, hoje só o balanço de repouso). Só visual: sem colisão.
const SEGMENTOS := 6
const LADO := 0.085
const BALANCO_GRAUS := 11.0
const VELOCIDADE := 2.4
var _pivos: Array[Node3D] = []
var _fase := 0.0


## Monta a cauda na cor `cor`, nas costas do corpo (`torso`: origem no ombro, costas em +Z, quadril ~0,7 m abaixo).
static func em(torso: Node3D, cor: Color) -> void:
	var c := (load("res://src/historia/east_blue/cauda_de_macaco.gd") as GDScript).new() as Node3D
	c.name = "Cauda"
	torso.add_child(c)
	c.position = Vector3(0.0, -0.66, 0.16)
	c._montar(cor)


func _montar(cor: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = cor
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var pai: Node3D = self
	for i in SEGMENTOS:
		var pivo := Node3D.new()
		pivo.name = "Seg%d" % i
		pai.add_child(pivo)
		# Cada segmento sai do fim do anterior: primeiro para trás, depois subindo (a ponta enrola para cima).
		pivo.position = Vector3(0.0, 0.0, LADO * 1.0) if i > 0 else Vector3.ZERO
		pivo.rotation.x = deg_to_rad(-6.0 - 9.0 * i)       # cada segmento curva um pouco mais para cima
		var mi := MeshInstance3D.new()
		var caixa := BoxMesh.new()
		var lado := LADO * (1.0 - 0.07 * i)
		caixa.size = Vector3(lado, lado, LADO * 1.15)
		caixa.material = material
		mi.mesh = caixa
		mi.position = Vector3(0.0, 0.0, LADO * 0.55)
		pivo.add_child(mi)
		_pivos.append(pivo)
		pai = pivo


func _process(delta: float) -> void:
	_fase += delta * VELOCIDADE
	for i in _pivos.size():
		_pivos[i].rotation.y = deg_to_rad(BALANCO_GRAUS) * sin(_fase - i * 0.55) * (0.5 + 0.1 * i)
