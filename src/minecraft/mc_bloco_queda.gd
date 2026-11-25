class_name McBlocoQueda
extends Node3D
# ============================================================================
#  BLOCO QUE CAI (`minecraft:falling_block`, 31/10/2026) — o entulho das crateras (`BlockDestroyAllDirection`,
#  buraco negro, meteoro): cada bloco destruído tem chance de virar um bloco em queda, lançado para fora.
#  `FallingBlockEntity.tick` do 1.20.1: gravidade 0,04 bloco/tick², arrasto 0,98, sem colisão lateral
#  elaborada; ao pousar vira bloco de novo (`setBlock`) se a célula estiver livre — senão some. Passou de
#  600 ticks, some. Anda em ticks de 20 Hz, em BLOCOS, e pousa pela física do mundo (raio do segmento).
#
#  Teto de `MAX` ao mesmo tempo: uma explosão grande não vira uma chuva de nós (o excedente é contado).
# ============================================================================

const GRUPO := "mc_blocos_em_queda"
const MAX := 80
const GRAVIDADE := 0.04
const ARRASTO := 0.98
const VIDA_MAX := 600
const B := 0.88
const TICK := 0.05

var bloco_id: StringName = &"minecraft:stone"
## deltaMovement em m/s (o mesmo campo `velocity` que `McEntidade.setDeltaMovement` escreve).
var velocity := Vector3.ZERO
var _mundo: McMundo
var _acum := 0.0
var _tempo := 0


static func criar(mundo: McMundo, pos_blocos: McVec3) -> McBlocoQueda:
	if mundo == null or mundo.arvore == null:
		return null
	if mundo.arvore.get_nodes_in_group(GRUPO).size() >= MAX:
		Mc._falta("bloco", "queda_cheia")
		return null
	var b := McBlocoQueda.new()
	b._mundo = mundo
	b.name = "BlocoQueda_%d" % Time.get_ticks_usec()
	b.add_to_group(GRUPO)
	var raiz: Node = mundo.arvore.current_scene if mundo.arvore.current_scene != null else mundo.arvore.root
	raiz.add_child(b)
	b.global_position = pos_blocos.para_godot() if pos_blocos != null else Vector3.ZERO
	b.definir_bloco(&"minecraft:stone")
	return b


## O bloco (e o desenho) que cai: `load(tag)` com `BlockState` chega aqui.
func definir_bloco(id: StringName) -> void:
	bloco_id = id
	var m := get_node_or_null("Cubo") as MeshInstance3D
	if m == null:
		m = MeshInstance3D.new()
		m.name = "Cubo"
		var caixa := BoxMesh.new()
		caixa.size = Vector3.ONE * B * 0.98
		m.mesh = caixa
		add_child(m)
	m.material_override = McBlocosDinamicos.material_de(id)


func vivo() -> bool: return not is_queued_for_deletion()


func _physics_process(delta: float) -> void:
	_acum += delta
	while _acum >= TICK and not is_queued_for_deletion():
		_acum -= TICK
		_tick()


## Um tick do `FallingBlockEntity`: gravidade, mover (parando no que a física do mundo tocar), arrasto.
func _tick() -> void:
	_tempo += 1
	if _tempo > VIDA_MAX or global_position.y < -200.0:
		queue_free()
		return
	var d := velocity * (TICK / B)                      # blocos/tick
	d.y -= GRAVIDADE
	var de := global_position
	var para := de + d * B
	var q := PhysicsRayQueryParameters3D.create(de, para + Vector3.DOWN * 0.0)
	q.collision_mask = MundoMinePiece.MASCARA_MUNDO
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and d.y <= 0.0:
		global_position = r.position + Vector3.UP * (B * 0.5)
		_pousar()
		return
	global_position = para
	d *= ARRASTO
	velocity = d * (B / TICK)


## Pousou: vira bloco se a célula estiver livre; senão o bloco se perde (como o do Minecraft sem `dropItem`).
func _pousar() -> void:
	# A primeira célula INTEIRA acima da superfície onde pousou (`ceil`): o chão do jogo não é alinhado à grade de
	# 0,88 m, e a célula "onde o centro está" atravessaria o chão e seria recusada (14–22 entulhos perdidos no medidor).
	var chao_y := global_position.y - B * 0.5
	var c := Vector3i(floori(global_position.x / B), ceili((chao_y - 0.001) / B), floori(global_position.z / B))
	var pos := McVec3.de(float(c.x), float(c.y), float(c.z))
	if _mundo.getBlockState(pos).isAir():
		_mundo.setBlock(pos, McBloco.Estado.de(Mc.bloco(bloco_id)), 3)
	# Célula ocupada: o bloco se perde. É o comportamento do FallingBlockEntity sem `dropItem`, não uma falta da camada.
	queue_free()
