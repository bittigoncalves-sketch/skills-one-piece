extends Node3D
## Animação procedural da gaivota (30/09/2026). Fonte da geometria:
## `tools/blender/gaivota_pet.py` — frente −Z, asa direita em +X, vazios nas juntas.
##
## Duas poses-base misturadas por `voo` (0 = no chão, 1 = no ar) e três camadas por cima:
## `batida` (bater as asas; 0 = planar), `pouso` (freio: asas para cima, pernas à frente)
## e `mergulho` (asas recolhidas, bico para baixo). No chão, o animador cuida sozinho do
## olhar em volta, da bicada no chão e do passo.

## Batidas por segundo com força total (gaivota real: ~3 a 4).
const FREQUENCIA := 3.6
const AMPLITUDE := 0.85
const DIEDRO := 0.12

var voo := 0.0
var batida := 0.0
var pouso := 0.0
var mergulho := 0.0

var _corpo: Node3D
var _cabeca: Node3D
var _cauda: Node3D
var _asas: Array[Node3D] = []
var _pontas: Array[Node3D] = []
var _pernas: Array[Node3D] = []
var _fase := 0.0
var _tempo := 0.0
var _passo := 0.0
var _olhar := 0.0
var _olhar_alvo := 0.0
var _proximo_olhar := 1.0
var _bicada := 0.0
var _proxima_bicada := 3.0
var _corpo_y := 0.0


func montar(modelo: Node3D) -> void:
	_corpo = modelo.find_child("Corpo", true, false)
	_cabeca = modelo.find_child("Cabeca", true, false)
	_cauda = modelo.find_child("Cauda", true, false)
	for letra in ["E", "D"]:
		_asas.append(modelo.find_child("Asa_" + letra, true, false))
		_pontas.append(modelo.find_child("Ponta_" + letra, true, false))
		_pernas.append(modelo.find_child("Perna_" + letra, true, false))
	if _corpo != null:
		_corpo_y = _corpo.position.y


## `alvos`: voo, batida, pouso, mergulho (0..1, a transição é suavizada aqui).
## `curva`: rad/s de giro no plano (inclina o corpo). `subida`: velocidade vertical.
## `andando`: rapidez no chão.
func animar(delta: float, alvos: Dictionary, curva: float, subida: float, andando: float) -> void:
	if _corpo == null:
		return
	_tempo += delta
	voo = move_toward(voo, float(alvos.get("voo", 0.0)), delta * 3.0)
	batida = move_toward(batida, float(alvos.get("batida", 0.0)), delta * 4.0)
	pouso = move_toward(pouso, float(alvos.get("pouso", 0.0)), delta * 4.0)
	mergulho = move_toward(mergulho, float(alvos.get("mergulho", 0.0)), delta * 5.0)
	_fase += delta * TAU * FREQUENCIA * (0.35 + 0.65 * batida)

	var chao := 1.0 - voo
	for i in 2:
		var lado := -1.0 if i == 0 else 1.0
		# No ar: diedro + batida; a ponta segue atrasada (é o que faz a onda da asa).
		var bate := AMPLITUDE * batida * sin(_fase)
		var ar := Vector3(0.0, 0.0, lado * (DIEDRO + bate))
		var ponta_ar := Vector3(0.0, 0.0, lado * 0.45 * batida * sin(_fase - 0.7))
		# Pouso: asas altas e um pouco à frente, freando.
		ar = ar.lerp(Vector3(0.0, lado * 0.25, lado * 0.55), pouso)
		# Mergulho: varridas para trás e recolhidas.
		ar = ar.lerp(Vector3(0.0, -lado * 0.75, lado * 0.3), mergulho)
		ponta_ar = ponta_ar.lerp(Vector3(0.0, -lado * 0.5, 0.0), mergulho)
		# No chão: dobradas ao longo do flanco, pontas cruzando sobre a cauda.
		# Girada no próprio comprimento (x) ANTES de varrer: a corda fica em pé, colada ao
		# flanco. Sem isso, vista de cima a asa dobrada era uma placa larga (prévia 30/09).
		var dobrada := Vector3(1.15, -lado * 1.62, -lado * 0.18)
		var ponta_dobrada := Vector3(0.0, lado * 0.12, lado * 0.05)   # pontas cruzam sobre a cauda
		_asas[i].rotation = ar.lerp(dobrada, chao)
		_pontas[i].rotation = ponta_ar.lerp(ponta_dobrada, chao)
		# Pernas: recolhidas no voo, à frente no pouso, alternando no passo.
		var perna_chao := sin(_passo + (PI if i == 0 else 0.0)) * 0.4 * clampf(andando * 2.0, 0.0, 1.0)
		var perna_ar := lerpf(-1.25, 0.45, pouso)
		_pernas[i].rotation.x = lerpf(perna_ar, perna_chao, chao)

	# Corpo: inclina na curva, empina ao subir e no pouso, mergulha de bico.
	var rolar := clampf(-curva * 0.35, -0.6, 0.6) * voo
	var arfar := clampf(subida * 0.06, -0.45, 0.35) * voo + pouso * 0.35 - mergulho * 0.55
	_passo += delta * andando * 9.0
	var balanco := absf(sin(_passo)) * 0.018 * clampf(andando * 2.0, 0.0, 1.0) * chao
	_corpo.rotation = Vector3(arfar + 0.05 * chao, 0.0, rolar)
	# Sobe e desce um tico com a batida (a asa empurra o corpo).
	_corpo.position.y = _corpo_y + balanco + sin(_fase) * 0.02 * batida * voo

	# Cauda: abre no pouso e no ar lento; fecha no chão.
	if _cauda != null:
		_cauda.rotation.x = lerpf(-0.05, 0.12, chao) + pouso * 0.25
		_cauda.scale = Vector3(1.0 + 0.35 * maxf(pouso, voo * (1.0 - batida) * 0.3), 1.0, 1.0)

	_cabeca_viva(delta, chao, andando)


## No chão a gaivota olha em volta e bica o chão de vez em quando; no ar, a cabeça
## fica estável (compensa metade do arfar do corpo, como as aves de verdade).
func _cabeca_viva(delta: float, chao: float, andando: float) -> void:
	if _cabeca == null:
		return
	_proximo_olhar -= delta
	if _proximo_olhar <= 0.0:
		_olhar_alvo = randf_range(-0.9, 0.9) if chao > 0.5 else 0.0
		_proximo_olhar = randf_range(1.2, 3.2)
	_olhar = lerpf(_olhar, _olhar_alvo, clampf(delta * 6.0, 0.0, 1.0))
	_proxima_bicada -= delta
	if _proxima_bicada <= 0.0 and chao > 0.9 and andando < 0.2:
		_bicada = 0.45
		_proxima_bicada = randf_range(2.5, 6.0)
	_bicada = maxf(0.0, _bicada - delta)
	var desce := sin(clampf(_bicada / 0.45, 0.0, 1.0) * PI) * 0.95
	_cabeca.rotation = Vector3(-desce - _corpo.rotation.x * 0.5, _olhar, 0.0)


## Força a pose (sem transição) — para nascer já no ar ou já pousada.
func fixar(novo_voo: float) -> void:
	voo = novo_voo
