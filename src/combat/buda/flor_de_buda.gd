extends Node
## Extensão autoral do Buda do Mine Piece. A entrada e o dano rodam no servidor.
const NUMERO := 1001
const CUSTO := 40.0
const RECARGA := 10.0
const PREPARO := 1.2
const DURACAO := 2.8
const RAIO := 10.0
const VFX = preload("res://src/combat/buda/flor_de_buda_vfx.gd")
var controlador: Node
var ativo := false
var tempo := 0.0
var recarga := 0.0
var explodiu := false
var visual: Node3D
var forma: Node3D
var origem := Vector3.ZERO
var spec: DamageSpec

func iniciar() -> bool:
	var ator: Player = controlador.ator
	if not controlador.servidor() or ativo or controlador.ativo or recarga > 0.0 or controlador.recarga > 0.0:
		return false
	if not controlador.fruta_ativa() or controlador.forma_atual() <= 0 or not ator.corpo_livre_para_golpe() or ator.morrendo or not ator.is_on_floor():
		return false
	if ator.energy + 0.001 < CUSTO:
		return false
	ator.gastar_energia(CUSTO)
	controlador._sincronizar_para_o_mod()
	ativo = true
	controlador.ativo = true
	controlador.selecao = NUMERO
	ator.set_meta(ControladorFrutaMinePiece.META, controlador.get_instance_id())
	tempo = 0.0
	recarga = RECARGA
	explodiu = false
	# O pé do modelo acompanha o chão também quando a escala gigante está ativa.
	origem = ator._char_model.global_position
	forma = ator.get_node_or_null("FormaZoan")
	spec = Balance.novo("hito_hito_daibutsu", "X", ator.escala_de_dano_da_fruta("hito_hito_daibutsu"))
	visual = VFX.new()
	ator.get_tree().current_scene.add_child(visual)
	visual.global_position = origem
	return true

func _physics_process(delta: float) -> void:
	recarga = maxf(0.0, recarga - delta)
	if not ativo:
		return
	var ator: Player = controlador.ator
	if not is_instance_valid(ator) or not controlador.fruta_ativa() or controlador.forma_atual() <= 0 or ator.morrendo or not ator.corpo_livre_para_golpe() or not is_instance_valid(forma):
		cancelar()
		return
	tempo += delta
	var peso := smoothstep(0.0, 0.65, tempo) * (1.0 - smoothstep(2.15, DURACAO, tempo))
	forma.peso_flor = peso
	if is_instance_valid(visual): visual.avancar(tempo)
	if not explodiu and tempo >= PREPARO:
		explodiu = true
		_explodir()
	if tempo >= DURACAO:
		cancelar()

func _explodir() -> void:
	if not controlador.servidor(): return
	var ator: Player = controlador.ator
	var centro := origem + Vector3.UP * 1.0
	for alvo in AlvosDeGolpe.todos(get_tree()):
		if not MundoMinePiece.atacavel(ator, alvo) or CombatResolver.e_fogo_amigo(alvo, ator): continue
		if AlvosDeGolpe.distancia_ao_corpo(alvo, centro) > RAIO: continue
		var direcao: Vector3 = AlvosDeGolpe.centro(alvo) - centro
		direcao.y = 0.0
		CombatResolver.aplicar(alvo, spec.dano, spec.cast_id, spec.teto, centro,
			direcao.normalized()*12.0 + Vector3.UP*3.0, 0.4, 0.0, false, null, ator)

func cancelar() -> void:
	if is_instance_valid(forma): forma.peso_flor = 0.0
	if is_instance_valid(visual): visual.queue_free()
	visual = null
	forma = null
	if spec != null:
		CombatResolver.encerrar(spec.cast_id)
		spec = null
	if ativo and is_instance_valid(controlador):
		controlador.ativo = false
		var ator: Player = controlador.ator
		if is_instance_valid(ator) and int(ator.get_meta(ControladorFrutaMinePiece.META, 0)) == controlador.get_instance_id():
			ator.remove_meta(ControladorFrutaMinePiece.META)
	ativo = false

func _exit_tree() -> void:
	cancelar()

func estado() -> Dictionary:
	return {"nome": "Flor de Buda", "tecla": "X", "selecionada": ativo,
		"custo": CUSTO, "recarga": recarga, "recarga_total": RECARGA,
		"sem_energia": controlador.ator.energy + 0.001 < CUSTO,
		"bloqueada": controlador.ator.max_energy + 0.001 < CUSTO,
		"requisito": "requer transformação (J)" if controlador.forma_atual() <= 0 else ""}
