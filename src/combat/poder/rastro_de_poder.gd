class_name RastroDePoder
extends Node3D
## Camada RASTRO do HTCS: fita que segue `parte` (braço, pé, lâmina) por `duracao` s e desbota por trás (~0,3 s). Amostra a posição a cada quadro
## e desenha um triangle strip de largura `largura` (perpendicular ao movimento e à câmera aproximada). Some sozinho.
const VIDA_DO_PONTO := 0.3
const MAX_PONTOS := 40

var parte: Node3D
var cor := Color(1, 0.85, 0.35)
var largura := 0.35
var duracao := 0.4

var _pontos: Array = []             # [posição, tempo de nascimento]
var _t := 0.0
var _quadros := 0
var _malha := ImmediateMesh.new()
var _mi := MeshInstance3D.new()


func _ready() -> void:
	top_level = true
	_mi.mesh = _malha
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	_mi.material_override = m
	add_child(_mi)
	_mi.top_level = true
	_mi.global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	_t += delta
	var segue := _t < duracao and is_instance_valid(parte) and parte.is_inside_tree()
	_quadros += 1
	if segue and _quadros > 2:                  # os 2 primeiros quadros: o rig ainda não posicionou a parte (o ponto nascia no pé)
		var novo: Vector3 = parte.global_position
		if not _pontos.is_empty() and (_pontos[-1][0] as Vector3).distance_to(novo) > 1.2:
			_pontos.clear()                     # salto (teletransporte do rig): recomeça a fita em vez de esticá-la
		_pontos.append([novo, _t])
		if _pontos.size() > MAX_PONTOS:
			_pontos.pop_front()
	while not _pontos.is_empty() and _t - float(_pontos[0][1]) > VIDA_DO_PONTO:
		_pontos.pop_front()
	_desenhar()
	if not segue and _pontos.is_empty():
		queue_free()


func _desenhar() -> void:
	_malha.clear_surfaces()
	if _pontos.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var olho := cam.global_position if cam != null else Vector3.UP * 10.0
	_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _pontos.size():
		var p: Vector3 = _pontos[i][0]
		var idade := clampf((_t - float(_pontos[i][1])) / VIDA_DO_PONTO, 0.0, 1.0)
		var prox: Vector3 = _pontos[mini(i + 1, _pontos.size() - 1)][0]
		var ant: Vector3 = _pontos[maxi(i - 1, 0)][0]
		var dir := (prox - ant).normalized()
		var lado := dir.cross((olho - p).normalized()).normalized() * largura * (1.0 - idade * 0.6)
		var base := cor.lerp(Color.WHITE, 0.15 * (1.0 - idade))
		var c := Color(base.r * 1.35, base.g * 1.35, base.b * 1.35, (1.0 - idade) * 0.8)        # somado e acima de 1,0: a fita brilha, não some no fundo claro
		_malha.surface_set_color(c)
		_malha.surface_add_vertex(p + lado)
		_malha.surface_set_color(c)
		_malha.surface_add_vertex(p - lado)
	_malha.surface_end()
