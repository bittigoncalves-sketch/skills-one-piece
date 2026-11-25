class_name PoseDoMod
extends RefCounted
## Clipes de animação do JOGADOR do Mine Piece (PlayerAnimator, 93 JSON) convertidos para os 13 papéis do rig
## (Torso, Head, UpperArm_*, Thigh_*…). Puro: dado um clipe e um tempo devolve {papel: Vector3 euler} no mesmo
## formato dos deslocamentos de `PikaPoses`/`GomuPoses` — o `ProceduralAnimator` só soma.
##
## CONVENÇÃO (medida, não suposta — ver `test_pose_do_mod`):
##   • O mod grava graus no espaço do modelo do Minecraft; o rig do jogo é Godot (frente −Z, +X à direita do
##     personagem, +X de rotação = braço/olhar para cima/frente). Rotação do rig = (−x, −y, +z), composta como
##     M = Rz · Ry · Rx (a ordem do Blockbench/ModelPart; é a mesma conta do `geo_para_glb.py`).
##   • HIERARQUIA: no mod `body` é a raiz (pernas descendem dele) e `torso` gira só o tronco com cabeça e braços; no
##     rig o `Torso` é a raiz de tudo, inclusive das pernas. Então Torso = body·torso, e cada Thigh = torso⁻¹·perna
##     (a perna do mod não acompanha o giro do `torso`; a do rig acompanharia).
##   • POSIÇÃO (`amostrar_posicoes`): o conversor validado do mod usa (−x, +y, +z) em pixels de modelo (÷16 = blocos); o
##     jogador tem 1,5 m para 1,8 bloco do Minecraft, então 1 px = 1,5/1,8/16 m. Torso = body + torso; a coxa descende do Torso
##     (perna − torso). Posição NÃO acompanha a rotação do `body` (soma simples). Escala dos clipes NÃO é aplicada.
## Os dados vêm de `tools/mine_piece/extrair_animacoes_do_jogador.py` (git-ignorado, regerável).

const CAMINHO := "res://assets/mine_piece/visual/animacoes_jogador.json"

static var _clipes: Dictionary = {}
static var _carregado := false


static func carregar() -> void:
	if _carregado:
		return
	_carregado = true
	var f := FileAccess.open(CAMINHO, FileAccess.READ)
	if f != null:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_clipes = d


static func tem(nome: String) -> bool:
	carregar()
	return _clipes.has(nome)


static func nomes() -> Array:
	carregar()
	return _clipes.keys()


static func duracao(nome: String) -> float:
	carregar()
	return float(_clipes[nome].duracao) if _clipes.has(nome) else 0.0


## Depois do último quadro o clipe volta ao corpo normal, salvo `hold_on_last_frame`.
static func segura(nome: String) -> bool:
	carregar()
	return bool(_clipes[nome].segurar) if _clipes.has(nome) else false


## Deslocamentos do rig no tempo `t` (s). Papéis sem trilha no clipe não aparecem (o corpo segue a locomoção).
static func amostrar(nome: String, t: float) -> Dictionary:
	carregar()
	if not _clipes.has(nome):
		return {}
	var ossos: Dictionary = _clipes[nome].ossos
	var giro := {}
	for osso: String in ossos:
		if ossos[osso].has("rotation"):
			giro[osso] = _basis(_valor(ossos[osso].rotation, t))
	var ident := Basis.IDENTITY
	var body: Basis = giro.get("body", ident)
	var torso: Basis = giro.get("torso", ident)
	var saida := {}
	if giro.has("body") or giro.has("torso"):
		saida["Torso"] = _euler(body * torso)
	if giro.has("head"):
		saida["Head"] = _euler(giro.head)
	if giro.has("right_arm"):
		saida["UpperArm_R"] = _euler(giro.right_arm)
	if giro.has("left_arm"):
		saida["UpperArm_L"] = _euler(giro.left_arm)
	var torso_inv := torso.inverse()
	if giro.has("right_leg"):
		saida["Thigh_R"] = _euler(torso_inv * giro.right_leg)
	if giro.has("left_leg"):
		saida["Thigh_L"] = _euler(torso_inv * giro.left_leg)
	return saida


## 1 px do modelo do mod em metros do jogador (altura 1,5 m ↔ 1,8 bloco de 16 px).
const METROS_POR_PX := 1.5 / 1.8 / 16.0


## Deslocamentos de POSIÇÃO do rig (metros, no espaço local do corpo) no tempo `t`.
static func amostrar_posicoes(nome: String, t: float) -> Dictionary:
	carregar()
	if not _clipes.has(nome):
		return {}
	var ossos: Dictionary = _clipes[nome].ossos
	var pos := {}
	for osso: String in ossos:
		if ossos[osso].has("position"):
			var v := _valor(ossos[osso].position, t)
			pos[osso] = Vector3(-v.x, v.y, v.z) * METROS_POR_PX
	var saida := {}
	var corpo: Vector3 = pos.get("body", Vector3.ZERO)
	var torso: Vector3 = pos.get("torso", Vector3.ZERO)
	if pos.has("body") or pos.has("torso"):
		saida["Torso"] = corpo + torso
	if pos.has("head"):
		saida["Head"] = pos.head
	for par in [["right_arm", "UpperArm_R"], ["left_arm", "UpperArm_L"]]:
		if pos.has(par[0]):
			saida[par[1]] = pos[par[0]]
	for par in [["right_leg", "Thigh_R"], ["left_leg", "Thigh_L"]]:
		if pos.has(par[0]):
			saida[par[1]] = pos[par[0]] - torso
	return saida


## Graus do mod → Basis no espaço do rig.
static func _basis(mc_graus: Vector3) -> Basis:
	var r := Vector3(deg_to_rad(-mc_graus.x), deg_to_rad(-mc_graus.y), deg_to_rad(mc_graus.z))
	return Basis(Vector3.BACK, r.z) * Basis(Vector3.UP, r.y) * Basis(Vector3.RIGHT, r.x)


## O `Node3D.rotation` e o `Quaternion.from_euler` do Godot usam YXZ: o vetor devolvido reproduz a rotação ali.
static func _euler(b: Basis) -> Vector3:
	return b.get_euler(EULER_ORDER_YXZ)


## Interpolação das chaves [[t, x, y, z, easing], …]: linear (ou o easing da chave de DESTINO), sem extrapolar.
static func _valor(chaves: Array, t: float) -> Vector3:
	if chaves.is_empty():
		return Vector3.ZERO
	var primeira: Array = chaves[0]
	if chaves.size() == 1 or t <= float(primeira[0]):
		return Vector3(primeira[1], primeira[2], primeira[3])
	for i in range(1, chaves.size()):
		var b: Array = chaves[i]
		if t <= float(b[0]):
			var a: Array = chaves[i - 1]
			var k := (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.00001)
			if str(b[4]) == "easeOutExpo":
				k = 1.0 if k >= 1.0 else 1.0 - pow(2.0, -10.0 * k)
			return Vector3(a[1], a[2], a[3]).lerp(Vector3(b[1], b[2], b[3]), k)
	var ultima: Array = chaves[chaves.size() - 1]
	return Vector3(ultima[1], ultima[2], ultima[3])
