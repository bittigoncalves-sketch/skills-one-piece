class_name CerebroDeTreino
extends Node
# ============================================================================
#  CÉREBRO DE TREINO — a DECISÃO mais simples que faz um boneco lutar.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D1). Existe para separar decidir de
#  executar na prática: tudo o que ele faz é chamar a mesma API que a entrada do
#  jogador chama (`pedir_ataque`, `erguer_guarda`, `baixar_guarda`). Não é a IA de
#  inimigo da história — é um parceiro de treino previsível, bom para aprender a
#  defender e para os testes.
#
#  O relógio aqui é de DECISÃO (quando pedir), não de regra: se o executor recusar
#  um pedido (ocupado, atordoado), o cérebro só tenta de novo no próximo ciclo.
# ============================================================================

enum Modo {
	PARADO,           ## não faz nada (saco de pancada)
	GUARDA_SEMPRE,    ## segura a guarda o tempo todo, encarando o alvo
	ATACA_EM_CICLO,   ## a cada `intervalo`, o próximo golpe da `sequencia`
	APARA_E_RIPOSTA,  ## ergue a guarda na hora do golpe do alvo e responde com riposte
}

@export var modo: Modo = Modo.PARADO
@export_range(0.3, 10.0, 0.1, "suffix:s") var intervalo := 2.0
## Direções em ordem (`GolpeDirecional.Direcao`); repete do começo ao acabar.
@export var sequencia: Array[int] = [GolpeDirecional.Direcao.FRENTE]
## Encarar o alvo antes de decidir. Desligado, ele luta para onde já está virado.
@export var encarar_alvo := true
## APARA_E_RIPOSTA: aperta a guarda quando falta isto do preparo do alvo. Dentro da
## janela de aparo da ficha, apara; fora dela, só bloqueia — é o "reflexo" do boneco.
@export_range(0.0, 0.5, 0.01, "suffix:s") var antecedencia_do_aparo := 0.10

var _boneco: BonecoDeDuelo
var _alvo: Node3D
var _t := 0.0
var _indice := 0


func montar(boneco: BonecoDeDuelo, alvo: Node3D) -> void:
	_boneco = boneco
	_alvo = alvo


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_boneco) or _boneco.combate_direcional == null:
		return
	var executor := _boneco.combate_direcional
	if encarar_alvo and is_instance_valid(_alvo):
		_boneco.encarar(_alvo.global_position)
	match modo:
		Modo.PARADO:
			if executor.guarda_pedida():
				executor.baixar_guarda()
		Modo.GUARDA_SEMPRE:
			if not executor.guarda_pedida():
				executor.erguer_guarda()
		Modo.ATACA_EM_CICLO:
			_t += delta
			if _t >= intervalo and not sequencia.is_empty():
				if executor.pedir_ataque(sequencia[_indice] as GolpeDirecional.Direcao):
					_indice = (_indice + 1) % sequencia.size()
					_t = 0.0
		Modo.APARA_E_RIPOSTA:
			_aparar_e_responder(executor)


func _aparar_e_responder(executor: ExecutorCorpoACorpo) -> void:
	if executor.janela_de_riposte_aberta():
		if not sequencia.is_empty():
			executor.pedir_ataque(sequencia[_indice] as GolpeDirecional.Direcao)
			_indice = (_indice + 1) % sequencia.size()
		return
	var do_alvo := _alvo.get("combate_direcional") as ExecutorCorpoACorpo if is_instance_valid(_alvo) else null
	if do_alvo == null:
		return
	if do_alvo.em_preparo() and do_alvo.golpe_atual != null:
		var restante := do_alvo.golpe_atual.preparo - do_alvo.tempo_da_acao()
		if restante <= antecedencia_do_aparo and not executor.guarda_pedida():
			executor.erguer_guarda()
	elif not do_alvo.atacando() and executor.guarda_pedida():
		executor.baixar_guarda()
