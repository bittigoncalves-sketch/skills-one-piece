extends Control
## HUD da história: só apresenta os valores do corpo, sem alterar dano/progressão.
const GRUPOS := ["enemy", "animais", "bestas_do_mar", "pets_historia", "npc"]
const ALCANCE := 40.0
const LARGURA := 84.0
const ALTURA := 7.0
const COR_VIDA := Color("70c991")
var _criaturas: Array[Node3D] = []
var _ancoras := {}
var _busca_em := 0.0
var _oclusao_em := 0.0
var _ocultas := {}
var _linhas: Array[Dictionary] = []

func _ready() -> void:
	name = "BarrasDeCriaturas"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func elegivel(no: Variant) -> bool:   # sem tipo: um nó já liberado quebraria a chamada
	if not is_instance_valid(no) or not no is Node3D or no.is_queued_for_deletion(): return false
	if no.is_in_group("player") or no.is_in_group(BarrasDeChefes.GRUPO): return false
	if no.has_method("boss") and bool(no.call("boss")): return false
	return no.get("health") != null and no.get("max_health") != null

static func nivel_de(no: Node) -> int:
	# Os corpos atuais ainda não têm progressão própria. Não confundir nível de
	# combate com nivel_de_detalhe (LOD) ou nível da água.
	var nivel: Variant = no.get("nivel")
	if nivel == null and no.has_meta("nivel"): nivel = no.get_meta("nivel")
	if nivel == null:
		var ficha: Variant = no.get("ficha")
		if ficha is Dictionary: nivel = ficha.get("nivel", 1)
	return maxi(1, int(nivel)) if nivel != null else 1

func _buscar() -> void:
	_criaturas.clear()
	var vistos := {}
	for grupo in GRUPOS:
		for no in get_tree().get_nodes_in_group(grupo):
			if not elegivel(no) or vistos.has(no): continue
			vistos[no] = true
			_criaturas.append(no)
	for no in _ancoras.keys():
		if not is_instance_valid(no) or not vistos.has(no):
			_ancoras.erase(no)
			_ocultas.erase(no)

func _ancora(no: Node3D) -> Dictionary:
	# AABB no espaço do corpo: respeita modelos com origem no centro e escalas
	# diferentes no editor. Não usa um deslocamento humano fixo para todo animal.
	var caixa := AABB()
	var achou := false
	for malha: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		if malha.mesh == null or not malha.is_visible_in_tree(): continue
		var local: Transform3D = no.global_transform.affine_inverse() * malha.global_transform
		var parte: AABB = local * malha.get_aabb()
		caixa = caixa.merge(parte) if achou else parte
		achou = true
	# O osso está DENTRO da cabeça. A distância até o topo da malha mantém
	# chifres/cabelos livres, inclusive nas bestas muito maiores que um humano.
	var cabeca := no.find_child("Head", true, false) as Node3D
	if cabeca != null:
		return {"cabeca": cabeca, "folga": maxf(0.15, caixa.end.y - no.to_local(cabeca.global_position).y)}
	for esqueleto: Skeleton3D in no.find_children("*", "Skeleton3D", true, false):
		for i in esqueleto.get_bone_count():
			var nome_osso: String = esqueleto.get_bone_name(i).to_lower()
			if nome_osso.ends_with("head") or nome_osso == "cabeca":
				var posicao := no.to_local(esqueleto.global_transform * esqueleto.get_bone_global_pose(i).origin)
				return {"esqueleto": esqueleto, "osso": i, "folga": maxf(0.15, caixa.end.y - posicao.y)}
	var ponto := Vector3(caixa.get_center().x, caixa.end.y, caixa.get_center().z) if achou else Vector3.UP * 2
	return {"ponto": ponto}

func ponto_acima(no: Node3D) -> Vector3:
	if not _ancoras.has(no): _ancoras[no] = _ancora(no)
	var a: Dictionary = _ancoras[no]
	var margem := Vector3.UP * (float(a.get("folga", 0)) * absf(no.global_basis.get_scale().y) + 0.3)
	if a.has("cabeca") and is_instance_valid(a.cabeca):
		return a.cabeca.global_position + margem
	if a.has("esqueleto") and is_instance_valid(a.esqueleto):
		var esqueleto: Skeleton3D = a.esqueleto
		return esqueleto.global_transform * esqueleto.get_bone_global_pose(a.osso).origin + margem
	return no.to_global(a.get("ponto", Vector3.UP * 2)) + Vector3.UP * 0.3

func _tapada(no: Node3D, camera: Camera3D, ponto: Vector3) -> bool:
	var raio := PhysicsRayQueryParameters3D.create(camera.global_position, ponto, 1)
	var hit := no.get_world_3d().direct_space_state.intersect_ray(raio)
	if hit.is_empty(): return false
	var corpo: Node = hit.collider
	return corpo != no and not no.is_ancestor_of(corpo)

func _process(delta: float) -> void:
	_busca_em -= delta
	if _busca_em <= 0:
		_busca_em = 0.25
		_buscar()
	_linhas.clear()
	var hud := get_parent()
	visible = not (hud.has_method("is_menu_open") and hud.call("is_menu_open"))
	var camera := get_viewport().get_camera_3d()
	if not visible or camera == null:
		queue_redraw()
		return
	_oclusao_em -= delta
	var conferir := _oclusao_em <= 0
	if conferir: _oclusao_em = 0.1
	for no in _criaturas:
		if not elegivel(no) or not no.is_inside_tree() or not no.is_visible_in_tree(): continue
		var vida := float(no.get("health"))
		var maxima := float(no.get("max_health"))
		if vida <= 0 or maxima <= 0: continue
		if camera.global_position.distance_squared_to(no.global_position) > ALCANCE * ALCANCE: continue
		var ponto := ponto_acima(no)
		if camera.is_position_behind(ponto): continue
		var tela := camera.unproject_position(ponto)
		if not get_viewport_rect().grow(-24).has_point(tela): continue
		if conferir or not _ocultas.has(no): _ocultas[no] = _tapada(no, camera, ponto)
		if _ocultas.get(no, false): continue
		_linhas.append({"no": no, "ponto": tela, "vida": clampf(vida / maxima, 0, 1), "nivel": nivel_de(no), "cor": Estilo.cor_da_vida(vida / maxima)})
	queue_redraw()

func _draw() -> void:
	var fonte := get_theme_default_font()
	for linha in _linhas:
		var caixa := Rect2(linha.ponto - Vector2(LARGURA * 0.5, ALTURA), Vector2(LARGURA, ALTURA))
		draw_rect(caixa.grow(2), Color("09151e"))
		draw_rect(caixa, Color("34414b"))
		draw_rect(Rect2(caixa.position, Vector2(LARGURA * linha.vida, ALTURA)), linha.cor)
		var texto := "N%d" % linha.nivel
		# Alinhado à esquerda, na ponta da barra (17/10/2026, pedido do dono); era centralizado.
		var pos: Vector2 = Vector2(caixa.position.x, linha.ponto.y - ALTURA - 7)
		draw_string_outline(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color("09151e"))
		draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f1eadb"))
