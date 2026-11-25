extends Node3D
## Ice Ball (C da Hie Mine Piece) — a parte VISÍVEL da frente que avança. O dano continua em `hie.gd` (`_bola_de_gelo`).
##
## Por que existe (24/11/2026): a referência do Codex (`art_src/references/logias_codex/hie/ice_ball.png`) mostra a frente como uma fileira de
## estacas de gelo que brotam do chão e prendem quem está no caminho; o jogo só desenhava uma placa translúcida (`VfxFrutaMinePiece.placa`).
## Aqui cada passo da frente semeia cristais (cones de 5 faces, o mesmo desenho da Ice Age) que SOBEM do chão em ease-out e somem em fade.
## Quem chama: `espetar(ponto, rumo, largura_m)` a cada passo da frente e `encerrar()` quando a técnica acaba.
const MAXIMO := 220
const POR_PASSO := 3
const DURACAO := 2.4        # s de vida de cada cristal depois de nascer
const SOBE := 0.3           # s que o cristal leva para subir
const COR := Color(0.62, 0.86, 1.0, 0.9)

var _mm: MultiMesh
var _mat: StandardMaterial3D
var _cristais: Array[Dictionary] = []   # {pos, alt, larg, incl, incl2, giro, nasceu}
var _idade := 0.0
var _fim_em := -1.0
var _rng := RandomNumberGenerator.new()


static func criar(pai: Node) -> Node3D:
	var n: Node3D = load("res://src/combat/frutas_mine_piece/frente_de_gelo_visivel.gd").new()
	pai.add_child(n)
	n._montar()
	return n


func _montar() -> void:
	_rng.seed = 2411
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COR
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 0.08
	_mat.vertex_color_use_as_albedo = true
	_mat.metallic_specular = 0.8
	_mat.emission_enabled = true
	_mat.emission = Color(0.35, 0.75, 1.0)
	_mat.emission_energy_multiplier = 0.9
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = cone
	_mm.instance_count = MAXIMO
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = _mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	mmi.global_transform = Transform3D.IDENTITY


## Semeia `POR_PASSO` cristais ao redor do ponto da frente; `rumo` é a direção da frente, `largura_m` a largura do dano (metade para cada lado).
func espetar(ponto: Vector3, rumo: Vector3, largura_m: float) -> void:
	var lado := Vector3(-rumo.z, 0.0, rumo.x).normalized()
	var chao := _chao_em(ponto)
	for i in POR_PASSO:
		if _cristais.size() >= MAXIMO:
			return
		var deslocamento := _rng.randf_range(-0.5, 0.5) * largura_m
		var pos := Vector3(ponto.x, chao, ponto.z) + lado * deslocamento + rumo * _rng.randf_range(-0.3, 0.3)
		_cristais.append({"pos": pos, "alt": _rng.randf_range(0.5, 1.7) * (1.0 - 0.5 * absf(deslocamento) / maxf(largura_m * 0.5, 0.1)),
			"larg": _rng.randf_range(0.18, 0.42), "incl": _rng.randf_range(-0.3, 0.3), "incl2": _rng.randf_range(-0.3, 0.3),
			"giro": _rng.randf() * TAU, "nasceu": _idade + _rng.randf() * 0.12, "cor": Color(0.30, 0.58, 0.92).lerp(Color(0.85, 0.95, 1.0), _rng.randf())})


func encerrar() -> void:
	if _fim_em < 0.0:
		_fim_em = _idade


func _chao_em(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 8.0, MundoMinePiece.MASCARA_MUNDO)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return float(hit.position.y) if not hit.is_empty() else p.y - 1.0


func _process(delta: float) -> void:
	_idade += delta
	var visiveis := 0
	var algum_vivo := false
	for i in _cristais.size():
		var c: Dictionary = _cristais[i]
		var t := _idade - float(c.nasceu)
		if t < 0.0:
			visiveis = i + 1
			_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), c.pos))
			algum_vivo = true
			continue
		var sobe := 1.0 - pow(1.0 - clampf(t / SOBE, 0.0, 1.0), 3.0)
		var desbota := 1.0 - clampf((t - (DURACAO - 0.6)) / 0.6, 0.0, 1.0)
		if desbota > 0.0:
			algum_vivo = true
		var altura := float(c.alt) * sobe * desbota
		var largura := float(c.larg) * (0.4 + 0.6 * sobe) * (0.4 + 0.6 * desbota)
		var base := Basis.from_euler(Vector3(float(c.incl), float(c.giro), float(c.incl2)))
		base = base.scaled(Vector3(largura * 2.0, maxf(altura, 0.001), largura * 2.0))
		_mm.set_instance_transform(i, Transform3D(base, (c.pos as Vector3) + Vector3.UP * altura * 0.5))
		_mm.set_instance_color(i, c.cor)
		visiveis = i + 1
	_mm.visible_instance_count = visiveis
	if (_fim_em >= 0.0 or _cristais.size() >= MAXIMO) and not algum_vivo and _idade > 0.5:
		queue_free()
