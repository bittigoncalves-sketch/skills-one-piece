class_name PetDomado
extends AnimalDaIlha
# ============================================================================
#  PET DOMADO — o herbívoro que comeu a fruta e passou a seguir o jogador (01/10/2026).
#
#  Decisão do dono: frutas do pomar domam herbívoros, que viram pets — quantos o
#  jogador quiser, no máximo 6 fora do inventário; pet que MORRE é apagado para sempre.
#
#  Mesmo corpo, animação e ataque do `AnimalDaIlha` (é o bicho de antes); muda o
#  cérebro: os quatro comportamentos do menu B (`ModoDoPet`), como a gaivota e o
#  caranguejo. Quem tem dano na ficha (búfalo, bisão, macaco) luta em guarda/agressivo;
#  o manso (coelho, ovelha…) nesses modos só acompanha.
# ============================================================================

signal modo_mudou(modo: StringName)

const SEGUE_ATE := 3.0          # para a esta distância do dono
const RETOMA_A := 4.5           # volta a andar quando passa disto
const CORRE_ACIMA_DE := 9.0
const TELEPORTA_ACIMA_DE := 45.0  # ficou para trás (o dono voou, correu muito): reaparece perto
const RAIO_LIVRE := 8.0

var alvo_de: Callable           # o dono (jogador local)
var modo: StringName = ModoDoPet.SEGUIR
var nome_exibido := ""
var pet_id := ""
var casa := Vector3.ZERO
var _livre_ate := 0.0


func montar_pet(bib: BibliotecaDeModelos, a_especie: String, a_ficha: Dictionary, id: String, nome: String,
		modo_inicial: StringName) -> void:
	montar(bib, a_especie, a_ficha, {})
	# Pet não tem hitbox de golpe: o soco do próprio dono não o acha (como a gaivota e o
	# caranguejo, na camada 0). Quem o fere é o bicho bravo, chamando `take_damage` direto.
	if _hurtbox != null:
		_hurtbox.free()
		_hurtbox = null
	remove_from_group("animais")
	remove_from_group("enemy")           # pet nunca é alvo dos outros pets nem da mira
	add_to_group("pets_historia")
	pet_id = id
	nome_exibido = nome
	name = "Pet_" + id
	modo = modo_inicial if ModoDoPet.valido(modo_inicial) else ModoDoPet.SEGUIR


func _ready() -> void:
	casa = global_position


## Troca o comportamento (menu B). Livre: passeia em volta de onde está agora.
func definir_modo(novo: StringName) -> void:
	if not ModoDoPet.valido(novo):
		return
	modo = novo
	if novo == ModoDoPet.LIVRE:
		casa = global_position
	estado = Estado.PARADO
	_relogio = 0.0
	modo_mudou.emit(novo)


func luta() -> bool:
	return float(ficha.get("dano", 0)) > 0.0


func _dono() -> Node3D:
	var d: Variant = alvo_de.call() if alvo_de.is_valid() else null
	return d as Node3D if d is Node3D and is_instance_valid(d) and (d as Node3D).is_inside_tree() else null


# Pet não renasce nem tem área: o cérebro é o dos modos.
func _pensar(_delta: float) -> void:
	var dono := _dono()
	alvo = dono
	if dono == null:
		estado = Estado.PARADO
		return
	var d_dono := _plano(dono.global_position - global_position).length()
	if modo != ModoDoPet.LIVRE and d_dono > TELEPORTA_ACIMA_DE:
		_reaparecer_perto(dono)
		return
	# Em guarda / agressivo: briga com o alvo do modo (só quem tem dano na ficha).
	var presa: Node3D = ModoDoPet.alvo(modo, dono, self) if luta() else null
	if estado == Estado.PERSEGUINDO and _vivo_no(oponente) and oponente != dono \
			and (ModoDoPet.no_raio(modo, dono, oponente) or oponente.get("oponente") == self):
		presa = oponente                 # continua na briga (inclusive revidando)
	if presa != null and luta():
		_perseguir(presa)
		var d := _plano(presa.global_position - global_position).length()
		_destino = presa.global_position
		_tentar_atacar(presa, d)
		return
	oponente = null
	match modo:
		ModoDoPet.LIVRE:
			if estado == Estado.PARADO and _relogio <= 0.0:
				estado = Estado.PASSEANDO
				var ang := randf() * TAU
				_destino = casa + Vector3(cos(ang), 0, sin(ang)) * randf_range(2.0, RAIO_LIVRE)
				_novo_relogio(6.0, 12.0)
			elif estado != Estado.PARADO and (_plano(_destino - global_position).length() < 0.8 or _relogio <= 0.0):
				estado = Estado.PARADO
				_novo_relogio(3.0, 8.0)
		_:
			# Seguir (e guarda/agressivo sem briga): atrás do dono, com folga.
			if d_dono > RETOMA_A or (estado != Estado.PARADO and d_dono > SEGUE_ATE):
				estado = Estado.VOLTANDO
				var atras := -dono.global_transform.basis.z
				_destino = dono.global_position + _plano(atras).normalized() * (SEGUE_ATE - 0.5)
			else:
				estado = Estado.PARADO


func _velocidade() -> float:
	var dono := _dono()
	if estado == Estado.VOLTANDO and dono != null:
		var d := _plano(dono.global_position - global_position).length()
		var corrida := float(ficha.get("corrida", 4.0))
		return corrida * (1.4 if d > CORRE_ACIMA_DE * 2.0 else 1.0) if d > CORRE_ACIMA_DE \
			else float(ficha.get("passeio", 1.0)) * 1.8
	return super._velocidade()


## Pet preso (atrás de casa, entre troncos): longe do dono, reaparece ao lado dele;
## perto, só para (o cérebro tenta de novo no quadro seguinte).
func _ao_empacar() -> void:
	var dono := _dono()
	if dono != null and _plano(dono.global_position - global_position).length() > 10.0:
		_reaparecer_perto(dono)
	else:
		estado = Estado.PARADO


## Pet não passeia como bicho selvagem (o cérebro dos modos decide).
func _passear() -> void:
	estado = Estado.PARADO
	_relogio = 0.3


func _reaparecer_perto(dono: Node3D) -> void:
	var lado := dono.global_transform.basis.x.normalized()
	global_position = dono.global_position + lado * 2.0 + Vector3.UP * 0.5
	velocity = Vector3.ZERO
	estado = Estado.PARADO


## Mesma vida e golpe do bicho; o revide vai para quem bateu.
func reagir_ao_golpe(from_pos: Vector3) -> void:
	var quem := _quem_bateu(from_pos)
	if quem == _dono():
		return                           # golpe do próprio dono (sem querer): não briga com ele
	if luta() and quem != null:
		_perseguir(quem)
	else:
		_fugir_de(from_pos)
