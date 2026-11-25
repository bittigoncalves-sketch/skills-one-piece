class_name BalaDaBuki
extends Node
# ============================================================================
#  O COMPORTAMENTO DA BALA DA BUKI (22/11/2026) — filho da DamageZone do tiro.
#
#  A `DamageZone` só sabe ferir quem tem `take_damage`; ao bater em parede ela
#  continuava voando. Aqui mora o que faltava:
#
#    1. COLISÃO COM QUALQUER COISA: a bala para, some e EXPLODE — pequena em
#       Z/C/V, grande no canhão (X). Roda em TODOS os peers, porque a explosão é
#       visual; o dano em área do X só nasce no servidor.
#    2. AVISO AOS INIMIGOS: no nascimento do tiro (servidor), quem está no
#       corredor da bala ouve `esquivar_de_disparo` e pode dar o dash (recarga de
#       3 s, mantida pelo próprio inimigo).
#
#  POR QUE UM NÓ FILHO E NÃO UM `if` NA DamageZone: a DamageZone é usada por
#  ~40 golpes de fruta; mexer nela é mexer em todos. O filho morre junto com a
#  zona — a auditoria de vazamento continua em zero.
#
#  ORDEM: o pai (`DamageZone._physics_process`) anda e varre ANTES do filho, então
#  o dano direto do quadro já foi entregue quando este nó decide explodir.
# ============================================================================

const RAIO_DO_AVISO := 2.2        # largura do corredor da bala que alerta o inimigo
const ALCANCE_DO_AVISO := 70.0
const ATRASO_DA_LIBERACAO := 0.10 # a zona fica parada este tempo para o Area3D entregar o `body_entered` pendente

var zona: DamageZone = null
var slot := "Z"
var raio := 0.15
var dano := 0.0
var grande := false
var explode_pequena_cada := 1     # V: só uma em cada N balas ganha explosão (anti-lag)
var _anterior := Vector3.ZERO
var _explodiu := false
var _acertado: Node = null


## Pendura o comportamento na zona. `dano_do_tiro` alimenta o dano em área do X.
static func instalar(z: DamageZone, slot_da_arma: String, raio_da_bala: float,
		dano_do_tiro: float, cada: int = 1) -> BalaDaBuki:
	var b := BalaDaBuki.new()
	b.name = "BalaDaBuki"
	b.zona = z
	b.slot = slot_da_arma
	b.raio = raio_da_bala
	b.dano = dano_do_tiro
	b.grande = slot_da_arma == "X"
	b.explode_pequena_cada = maxi(cada, 1)
	z.add_child(b)
	z.hit_landed.connect(b._ao_ferir)
	return b


func _ready() -> void:
	_anterior = zona.global_position
	if _e_servidor():
		_avisar_inimigos()


func _e_servidor() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func _ao_ferir(alvo: Node) -> void:
	_acertado = alvo
	# "Quando atacados": quem leva o tiro e está pronto dá o dash logo em seguida.
	if _e_servidor() and is_instance_valid(alvo) and alvo.has_method("esquivar_de_disparo") and zona != null:
		alvo.call("esquivar_de_disparo", zona.vel.normalized(), 0.0)


func _physics_process(_delta: float) -> void:
	if _explodiu or zona == null or not is_instance_valid(zona):
		return
	var agora := zona.global_position
	var contato := _procurar_contato(_anterior, agora)
	_anterior = agora
	if contato.is_empty():
		return
	_detonar(contato["ponto"], contato["normal"])


# Esfera varrida pelo passo do quadro + sobreposição no ponto final (cobre bala
# que nasce dentro da parede e bala rápida demais). Ignora o dono do tiro.
func _procurar_contato(de: Vector3, ate: Vector3) -> Dictionary:
	var mundo := zona.get_world_3d()
	if mundo == null:
		return {}
	var espaco := mundo.direct_space_state
	var excluir: Array[RID] = []
	if is_instance_valid(zona.caster) and zona.caster is CollisionObject3D:
		excluir.append((zona.caster as CollisionObject3D).get_rid())
	var esfera := SphereShape3D.new()
	esfera.radius = maxf(raio * 0.6, 0.08)       # um pouco menor que a hitbox: não explode "no ar" ao raspar
	var par := PhysicsShapeQueryParameters3D.new()
	par.shape = esfera
	par.collision_mask = 15
	par.collide_with_bodies = true
	par.collide_with_areas = false
	par.exclude = excluir
	par.transform = Transform3D(Basis(), de)
	par.motion = ate - de
	if (ate - de).length() > 0.001:
		var f := espaco.cast_motion(par)
		if f.size() >= 2 and f[1] < 1.0:
			var p := de.lerp(ate, f[1])
			return {"ponto": p, "normal": _normal_em(espaco, p, ate - de, excluir)}
	par.motion = Vector3.ZERO
	par.transform = Transform3D(Basis(), ate)
	if not espaco.intersect_shape(par, 1).is_empty():
		return {"ponto": ate, "normal": -(ate - de).normalized() if ate != de else Vector3.UP}
	return {}


# Normal da superfície no ponto: um raio curto no rumo do voo. Sem normal, o
# esguicho de fagulhas sai para cima.
func _normal_em(espaco: PhysicsDirectSpaceState3D, ponto: Vector3, rumo: Vector3, excluir: Array[RID]) -> Vector3:
	var r := PhysicsRayQueryParameters3D.create(ponto - rumo.normalized() * 0.2, ponto + rumo.normalized() * (raio + 0.6))
	r.collision_mask = 15
	r.exclude = excluir
	var h := espaco.intersect_ray(r)
	if not h.is_empty():
		return h["normal"]
	return -rumo.normalized() if rumo.length() > 0.001 else Vector3.UP


func _detonar(ponto: Vector3, normal: Vector3) -> void:
	if _explodiu:
		return
	_explodiu = true
	set_physics_process(false)
	zona.vel = Vector3.ZERO
	zona.global_position = ponto
	zona.visible = false                     # modelo e rastro somem; a hitbox espera o `body_entered` pendente
	var mundo := zona.get_parent()
	var fazer_visual := grande or _sorteia_pequena()
	if fazer_visual:
		BukiExplosao.visual(mundo, ponto, grande, normal)
	if grande and _e_servidor():
		BukiExplosao.area(mundo, ponto, dano, zona.caster, _acertado)
	# A zona é liberada logo depois — não no mesmo quadro (ver ATRASO_DA_LIBERACAO).
	zona.get_tree().create_timer(ATRASO_DA_LIBERACAO).timeout.connect(zona.queue_free)


func _sorteia_pequena() -> bool:
	var n: int = int(BukiFX._explosoes_por_slot.get(slot, 0))
	BukiFX._explosoes_por_slot[slot] = n + 1
	return n % explode_pequena_cada == 0


# Corredor da bala: o inimigo cuja distância até a RETA do tiro é pequena, à
# frente da boca, dentro do alcance, é avisado.
func _avisar_inimigos() -> void:
	var rumo := zona.vel.normalized()
	if rumo.length() < 0.5:
		return
	var origem := zona.global_position
	for e in AlvosDeGolpe.npcs(zona.get_tree()):
		if not (e is Node3D) or e == zona.caster or not e.has_method("esquivar_de_disparo"):
			continue
		var centro := AlvosDeGolpe.centro(e as Node3D)
		var ate := centro - origem
		var ao_longo := ate.dot(rumo)
		if ao_longo < 0.5 or ao_longo > ALCANCE_DO_AVISO:
			continue
		var fora := (ate - rumo * ao_longo).length()
		if fora > RAIO_DO_AVISO:
			continue
		e.call("esquivar_de_disparo", rumo, ao_longo / maxf(zona.vel.length(), 1.0))
