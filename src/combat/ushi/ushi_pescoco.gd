class_name UshiPescoco
extends Node3D
## Pescoço + cabeça da girafa, PROCEDURAIS (21/11/2026) — a mesma peça serve a três usos: a forma quadrúpede (`FormaGirafa`), a girafa
## humanoide (esconde a cabeça do modelo do mod enquanto o pescoço golpeia) e o corpo humano (o pescoço brota do peito).
## Eixos locais: o pescoço sobe em +Y; a frente é −Z. `pitch` inclina o pescoço para a frente (0 = em pé, PI/2 = deitado para a frente),
## `yaw` gira em torno da vertical (positivo = para a esquerda), `extensao` multiplica o comprimento (1 = repouso).
## Custo: 1 caixa de pescoço + 6 de crina + cabeça (6 caixas) — 13 MeshInstance3D, materiais compartilhados.

const CRINA := 6
var comprimento_base := 1.5
var largura := 0.22
var extensao := 1.0:
	set(v):
		extensao = maxf(v, 0.05)
		_ajustar()
var pitch := 0.0:
	set(v):
		pitch = v
		_orientar()
var yaw := 0.0:
	set(v):
		yaw = v
		_orientar()
var roll := 0.0:
	set(v):
		roll = v
		_orientar()

var _pescoco: MeshInstance3D
var _cabeca: Node3D
var _crina: Array[MeshInstance3D] = []


func _init(base := 1.5, grossura := 0.22) -> void:
	comprimento_base = base
	largura = grossura
	_pescoco = _caixa(self, Vector3(1, 1, 1), Vector3.ZERO, UshiMateriais.pele())
	for i in CRINA:
		_crina.append(_caixa(self, Vector3(largura * 0.32, largura * 0.5, largura * 0.62), Vector3.ZERO, UshiMateriais.escuro()))
	_cabeca = Node3D.new()
	add_child(_cabeca)
	_montar_cabeca()
	_ajustar()
	_orientar()


static func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	m.mesh = b
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(m)
	return m


func _montar_cabeca() -> void:
	var l := largura
	# Cabeça deitada para a frente (−Z): crânio, focinho, NARIZ (a ponta escura que é o martelo da martelada), chifrinhos e orelhas.
	_caixa(_cabeca, Vector3(l * 1.25, l * 1.1, l * 1.6), Vector3(0, l * 0.35, -l * 0.5), UshiMateriais.pele())
	_caixa(_cabeca, Vector3(l * 0.95, l * 0.85, l * 1.1), Vector3(0, l * 0.1, -l * 1.55), UshiMateriais.pele())
	_caixa(_cabeca, Vector3(l * 1.0, l * 0.9, l * 0.45), Vector3(0, l * 0.1, -l * 2.3), UshiMateriais.escuro())     # nariz
	for lado in [-1.0, 1.0]:
		_caixa(_cabeca, Vector3(l * 0.16, l * 0.8, l * 0.16), Vector3(lado * l * 0.35, l * 1.15, -l * 0.25), UshiMateriais.pele())      # ossicone
		_caixa(_cabeca, Vector3(l * 0.3, l * 0.3, l * 0.3), Vector3(lado * l * 0.35, l * 1.6, -l * 0.25), UshiMateriais.escuro())       # bolinha do ossicone
		_caixa(_cabeca, Vector3(l * 0.55, l * 0.16, l * 0.3), Vector3(lado * l * 0.85, l * 0.55, -l * 0.05), UshiMateriais.pele())      # orelha
		_caixa(_cabeca, Vector3(l * 0.12, l * 0.2, l * 0.2), Vector3(lado * l * 0.64, l * 0.55, -l * 1.0), UshiMateriais.escuro())      # olho


func _ajustar() -> void:
	var c := comprimento_base * extensao
	(_pescoco.mesh as BoxMesh).size = Vector3(largura, c, largura)
	_pescoco.position = Vector3(0, c * 0.5, 0)
	for i in _crina.size():
		var t := (float(i) + 0.5) / _crina.size()
		_crina[i].position = Vector3(0, c * t, largura * 0.52)
	_cabeca.position = Vector3(0, c, 0)


func _orientar() -> void:
	basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.BACK, roll)
	# A cabeça fica ~14° abaixo da horizontal no MUNDO, qualquer que seja a inclinação do pescoço (em pé: olha à frente; deitado: segue o eixo).
	if _cabeca != null:
		_cabeca.rotation.x = clampf(pitch, 0.0, 1.55) - 0.25


## Ponta do nariz no mundo (onde o martelo/aríete encosta).
func ponta() -> Vector3:
	return _cabeca.global_transform * Vector3(0, largura * 0.1, -largura * 2.5)


## Base (raiz do pescoço) no mundo.
func raiz() -> Vector3:
	return global_position


## Comprimento atual em metros, no mundo (já com a escala de quem o carrega).
func alcance_atual() -> float:
	return raiz().distance_to(ponta())
