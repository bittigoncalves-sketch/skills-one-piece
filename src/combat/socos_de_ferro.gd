class_name SocosDeFerro
extends Node3D
# ============================================================================
#  PX IRON PUNCHES — o X do estilo Pacifista.
#
#  Inspiracao mecanica (2026-09-03): Rush, o C da Rubber em Blox Fruits. O
#  pressionamento inicia uma rajada frontal curta; soltar depois do combo minimo
#  encerra, enquanto segurar prolonga ate o teto. Nao ha teleporte nem lock-on.
#
#  -------------------------------------------------------------- O QUE É CLONE
#  Clone de verdade: `duplicate()` do nó do braço do próprio jogador, com o
#  antebraço junto. Não é uma cápsula parecida — assim o soco herda a cor, a
#  escala e os acessórios daquele personagem sem que este arquivo saiba nada
#  sobre customização. O braço original NÃO some: quem voa é a cópia.
#
#  --------------------------------------------------------- POR QUE 2 m EXATOS
#  O alcance é o pedido, e ele é curto de propósito: é um golpe de pressão, não
#  um projétil. Quem quiser mudar mexe em `ALCANCE` — mas repare que a zona de
#  dano viaja PRESA ao braço, então esticar o alcance estica o acerto junto.
#
#  ⚠️ A DamageZone só aplica dano no SERVIDOR (ver DamageZone). Este nó roda em
#  todos os peers porque o VFX é presentation.
# ============================================================================

const MIN_SOCOS := 4        # toque nunca vira whiff acidental por latencia de key-up
const MAX_SOCOS := 12       # sustentacao cheia entrega o teto de dano do slot
const SOCOS := MAX_SOCOS    # alias de compatibilidade para sondas visuais antigas
const ANTECIPACAO := 0.10   # resposta abaixo de 150 ms, ainda com leitura de preparo
const INTERVALO := 0.09     # soft-stun de 0,14 s mantem o combo verdadeiro
const ALCANCE := 2.0        # pedido do dono, em metros
const IDA := 0.24
const RESOLUCAO := 0.10     # pausa curta no alcance máximo antes de desaparecer
const RAIO_DANO := 0.45
const COR_RASTRO := Color(1.0, 0.86, 0.08, 0.48)
const DURACAO_MINIMA := ANTECIPACAO + float(MIN_SOCOS) * INTERVALO
const DURACAO_MAXIMA := ANTECIPACAO + float(MAX_SOCOS) * INTERVALO

var _caster: Node3D = null
var _dano_total: float = 0.0
var _spec = null
var _dir: Vector3 = Vector3.FORWARD
var _lancados: int = 0
var _ate_o_proximo: float = ANTECIPACAO
var _cast_token: int = 0
var _parou_de_lancar := false
var _estado_finalizado := false


static func criar(mundo: Node, caster: Node3D, aim: Vector3, dano_total: float,
		spec = null, cast_token: int = 0) -> SocosDeFerro:
	var no := SocosDeFerro.new()
	no._caster = caster
	no._dano_total = dano_total
	no._spec = spec
	no._dir = aim.normalized()
	no._cast_token = cast_token
	mundo.add_child(no)
	return no


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_caster):
		queue_free()
		return
	if _cast_token > 0 and int(_caster.get_meta("px_token_X", 0)) != _cast_token:
		queue_free()
		return
	if bool(_caster.get_meta("px_iron_rush_cancelado", false)):
		_finalizar_estado()
		queue_free()
		return

	if not _parou_de_lancar:
		var segurando := bool(_caster.get_meta("px_iron_rush_ativo", false))
		if _lancados >= MAX_SOCOS or (not segurando and _lancados >= MIN_SOCOS):
			_parou_de_lancar = true
			if _lancados >= MAX_SOCOS:
				_caster.set_meta("px_iron_rush_ativo", false)
			_finalizar_estado()

	if _parou_de_lancar:
		# O gameplay ja terminou; os ultimos bracos conservam follow-through e
		# desaparecem so depois da resolucao visual.
		if get_child_count() == 0:
			queue_free()
		return

	_ate_o_proximo -= delta
	if _ate_o_proximo > 0.0:
		return
	_ate_o_proximo = INTERVALO
	# Alterna as mãos: uma sequência com o mesmo braço parece um soco repetido em
	# vídeo, não uma sequência.
	_lancar("R" if _lancados % 2 == 0 else "L")
	_lancados += 1


func _lancar(lado: String) -> void:
	var braco := _braco_do_jogador(lado)
	if braco == null:
		return
	var clone := braco.duplicate() as Node3D
	if clone == null:
		return
	add_child(clone)
	clone.global_transform = braco.global_transform
	clone.scale *= 1.12
	clone.set_meta("iron_punch", true)
	clone.set_meta("iron_punch_spawn_msec", Time.get_ticks_msec())
	_limpar_penduricalhos(clone)
	_destacar_clone(clone)
	_clarao_de_partida(clone.global_position)
	# Rastro rígido preso ao braço: continua atrás dele durante todo o trajeto e,
	# por usar material de malha, não vira um sprite de frente para a câmera.
	var rastro := BeamVisual3D.criar(clone, clone.global_position - _dir * 0.46,
		clone.global_position, 0.07, COR_RASTRO, 3.5, true)
	rastro.set_meta("iron_punch_trail", true)

	var zone := DamageZone.new()
	clone.add_child(zone)
	zone.position = Vector3.ZERO
	# Velocidade ZERO de propósito: quem carrega a zona é o braço, e uma zona que
	# também andasse sozinha percorreria o dobro do caminho.
	var golpe_final := _lancados == MAX_SOCOS - 1
	# Durante a rajada o alvo recebe apenas soft-stun, sem ser expulso dos 2 m.
	# Somente a sustentacao completa ganha um pequeno finisher de knockback.
	zone.setup(_dano_total / float(MAX_SOCOS), 14.0 if golpe_final else 0.0,
		Vector3.ZERO, IDA + 0.03, _caster, RAIO_DANO, null,
		0.32 if golpe_final else 0.14)
	if _spec != null:
		_spec.marcar(zone)

	_animar(clone, _alcance_livre(clone.global_position))


## O braço avança os 2 m e some. Some em vez de voltar porque, voltando, o clone
## cruzaria o alvo uma segunda vez e o golpe daria o dobro de acertos por soco.
func _animar(clone: Node3D, alcance_livre: float) -> void:
	var origem := clone.global_position
	var destino: Vector3 = origem + _dir * alcance_livre
	var lado := _dir.cross(Vector3.UP).normalized()
	if lado.length_squared() < 0.01:
		lado = Vector3.RIGHT
	var sinal := 1.0 if _lancados % 2 == 0 else -1.0
	var abertura := origem + lado * (0.30 * sinal)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Antecipação lateral curta tira o clone de trás das asas/corpo; o destino
	# continua a exatos 2 m da origem, portanto a mecânica não ganha alcance.
	tw.tween_property(clone, "global_position", abertura, 0.06)
	tw.tween_property(clone, "global_position", destino, IDA)
	tw.tween_interval(RESOLUCAO)
	tw.tween_callback(clone.queue_free)


## Parede e prop solido interrompem o braco; personagens nao. A margem do raio
## impede a esfera de dano de atravessar uma parede fina mesmo sem o centro
## geometrico cruza-la.
func _alcance_livre(origem: Vector3) -> float:
	var excluidos: Array[RID] = []
	if _caster is CollisionObject3D:
		excluidos.append((_caster as CollisionObject3D).get_rid())
	for _i in 12:
		var par := PhysicsRayQueryParameters3D.create(origem, origem + _dir * ALCANCE)
		par.collision_mask = 15
		par.collide_with_areas = false
		par.exclude = excluidos
		var hit := get_world_3d().direct_space_state.intersect_ray(par)
		if hit.is_empty():
			return ALCANCE
		var corpo = hit.get("collider")
		if corpo is CollisionObject3D and corpo.has_method("take_damage"):
			excluidos.append((corpo as CollisionObject3D).get_rid())
			continue
		return clampf(origem.distance_to(hit.position) - RAIO_DANO, 0.0, ALCANCE)
	return ALCANCE


func _finalizar_estado() -> void:
	if _estado_finalizado:
		return
	_estado_finalizado = true
	if is_instance_valid(_caster) and _caster.has_method("finalizar_skill_pacifista"):
		_caster.finalizar_skill_pacifista("X", _cast_token)


func _clarao_de_partida(pos: Vector3) -> void:
	var flash := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.14
	esfera.height = 0.28
	flash.mesh = esfera
	flash.material_override = FxUtil.mesh_emissive_material(COR_RASTRO, 3.5, true)
	add_child(flash)
	flash.global_position = pos
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "scale", Vector3.ONE * 2.4, 0.16)
	tw.parallel().tween_property(flash, "transparency", 1.0, 0.16)
	tw.tween_callback(flash.queue_free)


func _destacar_clone(no: Node) -> void:
	for filho in no.get_children():
		if filho is MeshInstance3D:
			(filho as MeshInstance3D).material_overlay = FxUtil.mesh_emissive_material(
				Color(1.0, 0.82, 0.08, 0.22), 2.2, true)
		_destacar_clone(filho)


## ⚠️ NÃO USE `_caster.get_node("_char_model")`: esse nó NÃO EXISTE mais (medido
## em 2026-09-01 — o modelo mora em `CharacterRoot_<char>/SkinPivot/GLBModel_…`).
## O caminho antigo sobrevive em `GuraChargeNode`, onde falha calado e a orb da
## carga simplesmente não aparece. Buscar a partir do jogador funciona para
## qualquer personagem do elenco, que é o que interessa aqui.
func _braco_do_jogador(lado: String) -> Node3D:
	var alvo := _caster.find_child("UpperArm_%s" % lado, true, false)
	if alvo == null:
		alvo = _caster.find_child("ForeArm_%s" % lado, true, false)
	return alvo as Node3D


## O braço carrega filhos que NÃO são braço: pistolas da Mera e as armas da Buki
## ficam penduradas no antebraço. Clonar tudo faria a sequência de socos sair
## atirando armas pelo mapa.
func _limpar_penduricalhos(no: Node) -> void:
	for c in no.get_children():
		var nome := String(c.name)
		if nome.begins_with("BukiArma") or nome.begins_with("MeraPistol"):
			c.queue_free()
		else:
			_limpar_penduricalhos(c)
