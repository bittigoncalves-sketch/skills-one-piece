extends Node3D
# ============================================================================
#  O RAIGO: a MeteorEntity do Mine Piece v14 no modo 1 (AIMeteorProcedure).
#
#  Nasce 128 blocos acima da cabeça com SIZE 0,1 e cresce 0,03 por tick até 3
#  (~4,9 s, parada, carregando cnt6 até 2,5). Aí cai acelerando 0,01 bloco/tick²
#  até 1 bloco/tick, ferindo a cada tick o que estiver no cubo de 12 × tamanho em
#  volta da base. Quando a caixa dela (15 × SIZE blocos) toca o mundo — ou passam
#  200 ticks de queda — explode: a cada 5 ticks um RangeAttack de 20 × tamanho,
#  até 6 × tamanho ticks, e some.
#  `global_position` é a BASE da entidade, como no Minecraft.
# ============================================================================

const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const MODELO := "res://assets/mine_piece/goro/mp_goro_meteoro.glb"
const LADO_BASE := 15.0      # EntityType METEOR: sized(15, 15)

var c                        # o GoroGoroMinePiece de quem lançou
var tamanho := 0.1           # atributo SIZE
var cnt1 := 0.0
var cnt4 := 0.0
var cnt6 := 0.0
var power := Vector3.ZERO    # blocos/tick
var _acumulado := 0.0
var _visual: Node3D
var _diametro_do_modelo := 1.0
var _centro_do_modelo := Vector3.ZERO


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var cena := load(MODELO) as PackedScene if ResourceLoader.exists(MODELO) else null
	var corpo: Node3D = cena.instantiate() if cena != null else null
	if corpo == null:
		var esfera := MeshInstance3D.new()
		esfera.mesh = SphereMesh.new()
		corpo = esfera
	_visual.add_child(corpo)
	var caixa := AABB()
	for malha in corpo.find_children("*", "MeshInstance3D", true, false) + ([corpo] if corpo is MeshInstance3D else []):
		var mi := malha as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		caixa = caixa.merge(mi.get_aabb()) if caixa.has_volume() else mi.get_aabb()
		# Modo 1: textura tex_white2 (cinza 51 sólido) com luz (`entityTranslucent`): o
		# Raigo do mod é uma bola de nuvem escura, não um brilho.
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.2, 0.2)
		mat.roughness = 1.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
	_diametro_do_modelo = maxf(caixa.size.x, maxf(caixa.size.y, caixa.size.z)) if caixa.has_volume() else 1.0
	_centro_do_modelo = caixa.get_center()
	_atualizar_visual()


func _lado() -> float:
	return LADO_BASE * tamanho


func _r() -> float:
	return B.tamanho(_lado(), _lado())


func _atualizar_visual() -> void:
	var diametro := B.m(_lado())
	var escala := diametro / _diametro_do_modelo
	_visual.scale = Vector3.ONE * escala
	# A base da entidade é o pé da caixa; o modelo pode ter a origem em qualquer lugar.
	_visual.position = Vector3.UP * diametro * 0.5 - _centro_do_modelo * escala


func _physics_process(delta: float) -> void:
	if c == null or not is_instance_valid(c.ator):
		queue_free()
		return
	_acumulado += delta
	while _acumulado >= B.TICK and is_inside_tree():
		_acumulado -= B.TICK
		_tick()


func _tick() -> void:
	var fator := 1.0 + cnt6 * 0.1
	var r := _r()
	var lado := _lado()
	cnt1 += 1.0
	if tamanho < 3.0:
		cnt1 -= 1.0
		power = Vector3.ZERO
		tamanho += 0.03
		if cnt6 < 2.5:
			cnt6 += 0.1
		_atualizar_visual()
	else:
		power.y = maxf(power.y - 0.01, -1.0)
	if cnt1 <= 200.0:
		c.fx_fumaca(global_position + Vector3.UP * B.m(lado * 0.5), int(4.0 * r), B.m(r * 1.25))
		var dis := power.length()
		if dis == 0.0:
			return
		# teleport(+power × 0,1) e depois a velocidade `power` do próprio tick.
		var dir := power / dis
		var pos := global_position
		var num1 := 0.0
		for i in int(maxf(dis, 1.0)):
			num1 += 1.0
			if num1 > 0.0:
				num1 = -8.0 * r
				c.atacar(pos, B.Ataque.new(Balance.MINE_PIECE_GORO.meteoro_queda * fator, 12.0 * r, 1.0), pos)
			if c.solido(pos, lado, lado):
				c.fx_marca(pos, B.m(8.0 * r) * 0.5)
				break
			pos += dir * B.m(1.0)
		global_position += power * B.m(1.1)
		if c.solido(global_position, lado, lado) or c.solido(pos, lado, lado):
			cnt1 = maxf(cnt1, 200.0)
		return
	cnt4 += 1.0
	if cnt4 == 1.0:
		_visual.visible = false   # modo 2, textura "clear"
		c.fx_marca(global_position, B.m(10.0 * r) * 0.5)
		c.fx_som(global_position, "sons/goro_raigo_impacto", 6.0)
	if cnt4 <= maxf(r, 1.0):
		c.fx_clarao(global_position, B.m(2.0 * r) * 4.0, 0.3)
	if fmod(cnt4, 5.0) == 1.0:
		c.atacar(global_position, B.Ataque.new(Balance.MINE_PIECE_GORO.meteoro_explosao * fator, 20.0 * r, 2.5), global_position)
	if cnt4 < maxf(r * 6.0, 1.0):
		c.fx_fumaca(global_position + Vector3.UP * B.m(r), int(5.0 * r), B.m(4.0 * r), 3.0)
		c.fx_faiscas(global_position + Vector3.UP * B.m(r), int(10.0 * r), B.m(4.0 * r), 6.0)
	if cnt4 > r * 6.0:
		c.fx_fumaca(global_position, int(25.0 * r), B.m(2.0 * r), 2.0)
		c.fx_faiscas(global_position, int(25.0 * r), B.m(2.0 * r), 4.0)
		queue_free()
