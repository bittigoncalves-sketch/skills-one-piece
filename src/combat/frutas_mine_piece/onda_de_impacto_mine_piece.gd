extends Node3D
## EntityImpactWave (Mine Piece v14), AIImpactWaveProcedure, para o controlador genérico
## (a Goro tem a dela, modo 56). Modos: 0 (vida 25, cresce até 18), 1 (40, 30), 2 (15,
## 5 × CNT6). SIZE começa em 0,1 e cresce max(vida/tamanho, 1,5) por tick (a base desce
## metade); o corpo é 1,3 × SIZE. Por `vida` ticks: RangeAttack no meio do corpo, lado
## 1,5 × ((altura + largura) × 0,75 + 4), 16 × CNT6 (24 nos 6 últimos), empurrão 0,1
## (min(CNT6, 2) nos 6 últimos), e o KnockbackProcedure com o mesmo lado.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const LADO_BASE := 1.3       # ENTITY_IMPACT_WAVE: sized(1.3, 1.3)

var c
var modo := 0
var cnt6 := 0.0
var tamanho := 0.1
var modelo := ""            # o geo da entidade (o Laser da Pika: rubble + haki_yellow)
var cnt1 := 0.0
var _acumulado := 0.0
var _visual: Node3D
var cor_do_brilho := Color(1.0, 0.82, 0.18)        # a cor da luz da onda (a do Laser da Pika; outras frutas passam a sua)
var _material: StandardMaterial3D
var _anel: MeshInstance3D


func _ready() -> void:
	if not modelo.is_empty() and ResourceLoader.exists(modelo):
		_visual = (load(modelo) as PackedScene).instantiate()
		add_child(_visual)
		VfxFrutaMinePiece.render_do_mod(_visual)
		_brilhar()
		_escala()
		_criar_anel()


## O modelo do mod tem só ~11% de alfa: com depth pre-pass saía como lâminas amarelas sujas. Aqui a casca vira LUZ (somada, sem sombra, sem face escondida)
## e some com a vida da onda; a forma e o tamanho seguem os do mod.
func _brilhar() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(cor_do_brilho, 0.16)
	for malha in _visual.find_children("*", "MeshInstance3D", true, false):
		(malha as MeshInstance3D).material_override = _material


## O anel de choque no chão: um disco somado que cresce com a onda (raio = lado do corpo) e some junto.
func _criar_anel() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.7, 0.88, 1.0])
	grad.colors = PackedColorArray([Color(cor_do_brilho, 0.0), Color(cor_do_brilho, 0.0), Color(cor_do_brilho.lerp(Color.WHITE, 0.5), 0.9), Color(cor_do_brilho, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	var malha := QuadMesh.new()
	malha.size = Vector2.ONE
	malha.orientation = PlaneMesh.FACE_Y
	malha.material = mat
	_anel = MeshInstance3D.new()
	_anel.mesh = malha
	_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_anel)


func _vida() -> float:
	return 40.0 if modo == 1 else (15.0 if modo == 2 else 25.0)


func _tamanho_final(k6: float) -> float:
	return 30.0 if modo == 1 else (5.0 * k6 if modo == 2 else 18.0)


func _escala() -> void:
	if _visual != null:
		_visual.scale = Vector3.ONE * B.METROS_POR_BLOCO * tamanho
	if _anel != null:
		var lado := B.m(LADO_BASE * tamanho) * 2.0
		_anel.scale = Vector3(lado, 1.0, lado)
		_anel.position.y = B.m(cresce_y_do_anel())


## A onda desce metade do que cresce a cada tick (`global_position.y -= …`): o anel sobe de volta para ficar rente ao chão original.
func cresce_y_do_anel() -> float:
	return maxf(tamanho - 0.1, 0.0) * 0.5


func _physics_process(delta: float) -> void:
	if c == null or not is_instance_valid(c) or not is_instance_valid(c.ator) or not c.servidor():
		if c == null or not is_instance_valid(c):
			queue_free()
		return
	_acumulado += delta
	while _acumulado >= B.TICK and is_inside_tree():
		_acumulado -= B.TICK
		_tick()


func _tick() -> void:
	cnt1 += 1.0
	var k6 := 1.0 + cnt6 * 0.1
	var vida := _vida()
	var final := _tamanho_final(k6)
	if tamanho < final:
		var cresce := maxf(vida / final, 1.5)
		tamanho += cresce
		global_position.y -= B.m(cresce * 0.5)
		_escala()
	# some com a vida: o brilho cai e o anel esvai nos últimos 60% da duração
	var restante := clampf(1.0 - cnt1 / maxf(vida, 1.0), 0.0, 1.0)
	if _material != null:
		_material.albedo_color.a = 0.16 * clampf(restante * 2.2, 0.0, 1.0)
	if _anel != null:
		(_anel.mesh.material as StandardMaterial3D).albedo_color.a = clampf(restante * 1.8, 0.0, 1.0)
	var lado := LADO_BASE * tamanho
	var meio := global_position + Vector3.UP * B.m(lado * 0.5)
	var alcance := (lado + lado) * 0.75 + 4.0
	var forte := cnt1 > vida - 6.0
	var dano := (24.0 if forte else 16.0) * k6 + cnt1 * 0.001
	var empurrao := minf(k6, 2.0) if forte else 0.1
	B.ataque_em_area(c.ator, meio, meio, B.Ataque.new(dano, 1.5 * alcance, empurrao, false), c.tick,
		c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
	B.empurrar_area(c.ator, meio, meio, 1.5 * alcance, empurrao)
	VfxGoroMinePiece.fumaca(self, meio, int(2.0 * alcance), B.m(alcance * 0.1), 4.0)
	if cnt1 > vida:
		queue_free()
