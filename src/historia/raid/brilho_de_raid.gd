class_name BrilhoDeRaid
extends Node
## BRILHO AMARELO DOS INIMIGOS DA RAID ATRÁS DE ESTRUTURAS (08/11/2026, pedido do dono). Inimigo de raid vivo que o jogador NÃO vê porque há
## uma estrutura (parede, prédio, árvore, rocha) entre a câmera e ele ganha uma silhueta amarela translúcida desenhada por cima de tudo
## (`material_overlay` sem teste de profundidade). Visto de novo, o brilho some. Outros personagens (a roda de inimigos) não escondem ninguém:
## só o que é cenário conta. Só enxerga até `ALCANCE`.
const INTERVALO := 0.15
const ALCANCE := 70.0
const COR := Color(1.0, 0.85, 0.1, 0.55)

var raid: Node
var _t := 0.0
static var _material: StandardMaterial3D = null


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = COR
		_material.no_depth_test = true
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.render_priority = 100
	return _material


func _process(delta: float) -> void:
	_t += delta
	if _t < INTERVALO:
		return
	_t = 0.0
	var cam := get_viewport().get_camera_3d()
	for n in get_tree().get_nodes_in_group("personagens_east_blue"):
		var p := n as PersonagemMinePiece
		if p == null or not p.has_meta("raider"):
			continue
		var brilhar := cam != null and p.vivo() and not bool(p.get_meta("raid_caiu", false)) and escondido(cam.global_position, p)
		definir(p, brilhar)


## Há cenário entre `de` e o personagem (peito E cabeça bloqueados)? Corpos de personagem não contam; corpo a corpo de multidão não esconde.
static func escondido(de: Vector3, p: PersonagemMinePiece) -> bool:
	if de.distance_to(p.global_position) > ALCANCE:
		return false
	var altura := float(p.ficha.get("altura", 1.8))
	var espaco := p.get_world_3d().direct_space_state
	for fator in [0.5, 0.9]:
		if not _bloqueado(espaco, de, p.global_position + Vector3.UP * altura * fator, p):
			return false
	return true


static func _bloqueado(espaco: PhysicsDirectSpaceState3D, de: Vector3, ate: Vector3, alvo: Node3D) -> bool:
	var excluir: Array[RID] = [alvo.get_rid()]
	for salto in 5:
		var q := PhysicsRayQueryParameters3D.create(de, ate, 1)
		q.exclude = excluir
		var h := espaco.intersect_ray(q)
		if h.is_empty():
			return false
		var corpo: Object = h["collider"]
		if corpo is CharacterBody3D:
			excluir.append((corpo as CharacterBody3D).get_rid())      # gente não esconde: atravessa e continua
			continue
		return true
	return false


static func definir(p: PersonagemMinePiece, ligado: bool) -> void:
	if p._modelo == null:
		return
	if ligado == bool(p.get_meta("brilho_amarelo", false)):
		return
	p.set_meta("brilho_amarelo", ligado)
	for m in p._modelo.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_overlay = material() if ligado else null
