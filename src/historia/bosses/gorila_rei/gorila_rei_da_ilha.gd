extends AnimalDaIlha
## Gorila-rei, chefe da Ilha dos Macacos (22/11/2026): `AnimalDaIlha` (território, perseguição, retorno ao covil, barra de chefe, baú, respawn) + o cérebro de golpes
## `CombateGorila` (avisos vermelhos). Sem skill builder. Plano e números: docs/ILHA_DOS_MACACOS_V2_PLANO.md, `config_gorila.gd`.
const ID_DA_ESPECIE := "gorila_rei"
@export var habilidades: Resource = preload("res://src/historia/bosses/gorila_rei/config_gorila.gd").new()
var combate: Node


func _ready() -> void:
	combate = load("res://src/historia/bosses/gorila_rei/combate_gorila.gd").new()
	combate.name = "CombateDoGorilaRei"
	combate.corpo = self
	combate.config = habilidades.duplicate()
	add_child(combate)


func _physics_process(delta: float) -> void:
	if estado == Estado.MORTO:
		super._physics_process(delta)
		return
	if is_instance_valid(combate) and combate.atualizar(delta):
		return
	super._physics_process(delta)
	if is_instance_valid(combate):
		combate.locomocao()


func take_damage(amount: float, from_pos: Vector3 = Vector3.ZERO, knockback: Vector3 = Vector3.ZERO, hitstun: float = 0.0) -> void:
	# Chefe pesado: golpe NÃO o empurra durante o aviso/golpe nem o faz perder a mira.
	if is_instance_valid(combate) and combate.ativo():
		knockback = Vector3.ZERO
	super.take_damage(amount, from_pos, knockback, hitstun)
	if vivo() and is_instance_valid(combate):
		combate.reagir_ao_golpe()


func _tentar_atacar(quem: Node3D, distancia: float) -> void:
	# O kit substitui o golpe genérico do animal.
	if is_instance_valid(combate):
		combate.escolher(quem, distancia)


func _morrer() -> void:
	if is_instance_valid(combate):
		combate.morreu()
	super._morrer()


func reviver(posicao: Vector3) -> void:
	super.reviver(posicao)
	if is_instance_valid(combate):
		combate.reiniciar()


func manter_ativo_para_lod() -> bool:
	return is_instance_valid(combate) and (combate.ativo() or em_combate())
