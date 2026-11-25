class_name EntradaCorpoACorpo
extends Node
# ============================================================================
#  ENTRADA DO COMBATE DIRECIONAL — o jogador DECIDE aqui; o executor executa.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D10, D11). A IA não passa por este
#  arquivo: ela chama o executor direto. Por isso nada de regra de golpe mora
#  aqui — só "o que o jogador pediu".
#
#  ---------------------------------------------------------- AS DUAS AÇÕES
#  `combate_atacar` (botão esquerdo) e `combate_defender` (botão direito), no
#  InputMap. São as ÚNICAS ações do projeto: o resto do jogo lê tecla direto por
#  convenção (Player.gd, cabeçalho), e isso não muda. O toque funciona igual,
#  porque o `ToqueHud` sintetiza o mesmo `InputEventMouseButton`.
#
#  ------------------------------------------------------ A DIREÇÃO DO GOLPE
#  O corpo SEMPRE encara a mira (decisão do dono, 2026-08-27) e o mouse gira o
#  yaw direto. Então horizontal na tela = horizontal no espaço do personagem, e
#  a leitura pode ser feita no movimento relativo cru, sem câmera no meio.
#
#  Soma o movimento dos últimos `janela` segundos ANTES do clique, em radianos de
#  câmera (movimento × sensibilidade) — o mesmo gesto dá a mesma direção com
#  qualquer DPI de mouse que o jogo já trate. Nada é esperado DEPOIS do clique:
#  esperar a direção "firmar" atrasaria todo golpe.
#
#    abaixo da zona morta ........ FRENTE
#    horizontal dominante ........ PARA_ESQUERDA / PARA_DIREITA (sentido do mouse)
#    para cima ................... DE_CIMA
#    para baixo .................. FRENTE (reservado a um golpe de baixo)
#
#  ⚠️ O movimento é lido CRU, antes do limite do pitch. Olhando para o chão no
#  limite, o pitch não muda mais — mas o gesto para cima continua sendo gesto.
# ============================================================================

const ACAO_ATACAR := &"combate_atacar"
const ACAO_DEFENDER := &"combate_defender"

## Quanto tempo antes do clique conta para a direção.
@export_range(0.03, 0.4, 0.01, "suffix:s") var janela := 0.12
## Gesto menor que isto (em radianos de câmera) é FRENTE.
@export_range(0.0, 0.3, 0.005, "suffix:rad") var zona_morta := 0.035

# Amostras guardadas. O Godot ACUMULA o movimento do mouse num evento por quadro
# (`Input.use_accumulated_input`, ligado por padrão), então chegam no máximo ~FPS
# amostras por segundo: 64 cobrem a janela de 0,12 s até ~500 FPS. Estourar o anel
# não quebra nada — só as amostras mais antigas da janela deixam de somar.
const _CAPACIDADE := 64

var _executor: ExecutorCorpoACorpo
var _sensibilidade := 0.0035
var _defendendo := false
## Suspensa = os botões do mouse são de OUTRA coisa agora (arma de fruta sacada no
## Modo História: a pistola da Yami e as armas da Buki atiram no esquerdo e miram no
## direito — 03/10/2026). Sem soco, sem guarda; quem liga é o Player.
var suspensa := false
## Quem cede os botões do mouse ao clique do Minecraft (`CliqueDeBlocos`, V5): devolve true quando as mãos são DELE. Sem ele, nada muda.
var cedida := Callable()
# Anel fixo de amostras (movimento em rad, instante em ms): nada é alocado por evento.
var _mov: PackedVector2Array
var _ms: PackedInt64Array
var _proxima := 0
var _estilo_sequencia: EstiloCorpoACorpo
var _proximo_soco := 0
var _restante_sequencia := 0.0


func _init() -> void:
	_mov.resize(_CAPACIDADE)
	_ms.resize(_CAPACIDADE)
	_ms.fill(-1)


func montar(executor: ExecutorCorpoACorpo, sensibilidade: float) -> void:
	if is_instance_valid(_executor):
		_executor.golpe_iniciado.disconnect(_ao_iniciar_golpe)
		_executor.golpe_encerrado.disconnect(_ao_encerrar_golpe)
	_executor = executor
	_sensibilidade = sensibilidade
	if _executor != null:
		_executor.golpe_iniciado.connect(_ao_iniciar_golpe)
		_executor.golpe_encerrado.connect(_ao_encerrar_golpe)
	_estilo_sequencia = null
	reiniciar_sequencia()
	_sincronizar_estilo()


## Movimento de câmera para a leitura de direção. Não consome o evento: a câmera
## do Player continua recebendo tudo.
func _input(evento: InputEvent) -> void:
	var m := evento as InputEventMouseMotion
	if m != null and _mira_ativa():
		registrar_movimento(m.relative, Time.get_ticks_msec())


## A GUARDA é lida pelo ESTADO do botão a cada quadro, e não pelos eventos de
## apertar/soltar: se o RMB for solto com um menu aberto, a UI engole o evento e a
## guarda ficaria erguida para sempre. Mouse solto (menu) = não está defendendo.
func _physics_process(delta: float) -> void:
	if _executor == null:
		return
	avancar_sequencia(delta)
	if suspensa or not _mira_ativa():
		reiniciar_sequencia()
	var segurando := not suspensa and not _cedida() and _mira_ativa() and Input.is_action_pressed(ACAO_DEFENDER)
	if segurando != _defendendo:
		atualizar_defesa(segurando)


func _cedida() -> bool:
	return cedida.is_valid() and bool(cedida.call())


## Ponto único que liga/desliga a defesa (o teste com tela usa o mesmo caminho).
func atualizar_defesa(segurando: bool) -> void:
	_defendendo = segurando
	if segurando:
		reiniciar_sequencia()
		_executor.erguer_guarda()
	else:
		_executor.baixar_guarda()


## Chamado pelo Player no topo do `_unhandled_input` (ponte explícita, e não
## ordem de propagação, para o teste poder entregar o evento direto).
## Devolve `true` quando o evento foi do combate e não deve seguir adiante.
func tratar(evento: InputEvent) -> bool:
	if _executor == null or not _mira_ativa() or suspensa or _cedida():
		return false   # mouse solto: o Player recaptura, como sempre (suspensa: a arma usa)
	if evento.is_action_pressed(ACAO_ATACAR):
		pedir_clique(Time.get_ticks_msec())
		return true
	# O RMB é do combate: o estado é lido no `_physics_process`, e o evento não segue
	# para o ramo antigo do botão direito do Player.
	if evento.is_action_pressed(ACAO_DEFENDER) or evento.is_action_released(ACAO_DEFENDER):
		return true
	return false


## Mesmo pedido usado pelo evento real e pela sonda sem captura de mouse.
## Só o início REAL avança o índice: spam e substituição do buffer não pulam socos.
func pedir_clique(agora_ms: int) -> bool:
	if _executor == null or suspensa:
		return false
	_sincronizar_estilo()
	var direcao := direcao_em(agora_ms)
	var extra := _encaixe_extra()
	if extra >= 0:
		return _executor.pedir_ataque(extra as GolpeDirecional.Direcao)
	if _estilo_sequencia != null and not _estilo_sequencia.sequencia_cliques.is_empty() \
			and gesto_em(agora_ms).length() < zona_morta:
		# Um segundo clique cedo não transforma o combo numa finta involuntária.
		if _executor.estado == ExecutorCorpoACorpo.Estado.PREPARO:
			return false
		direcao = _estilo_sequencia.sequencia_cliques[_proximo_soco] as GolpeDirecional.Direcao
	return _executor.pedir_ataque(direcao)


## Golpe de ar (no ar) ou de corrida (Shift com movimento), se o estilo tiver: o Epic Fight troca o auto por eles. −1 = nenhum.
func _encaixe_extra() -> int:
	if _executor == null or _executor.estilo == null or _executor.ator == null:
		return -1
	if _executor.estado != ExecutorCorpoACorpo.Estado.NEUTRO and _executor.estado != ExecutorCorpoACorpo.Estado.GUARDA:
		return -1                                           # no meio de um combo o clique segue a cadeia
	if _executor.ator.no_ar() and _executor.estilo.golpe_para(GolpeDirecional.Direcao.NO_AR) != null:
		return GolpeDirecional.Direcao.NO_AR
	if _executor.ator.em_corrida() and _executor.estilo.golpe_para(GolpeDirecional.Direcao.CORRIDA) != null:
		return GolpeDirecional.Direcao.CORRIDA
	return -1


func reiniciar_sequencia() -> void:
	_proximo_soco = 0
	_restante_sequencia = 0.0


func avancar_sequencia(delta: float) -> void:
	_sincronizar_estilo()
	if _executor == null:
		return
	if _executor.estado in [ExecutorCorpoACorpo.Estado.REACAO,
			ExecutorCorpoACorpo.Estado.QUEBRA, ExecutorCorpoACorpo.Estado.REBATIDO] \
			or (_executor.ator != null and _executor.ator.impedido() and not _executor.atacando()):
		reiniciar_sequencia()
	elif not _executor.atacando():
		_restante_sequencia = maxf(0.0, _restante_sequencia - delta)
		if _restante_sequencia <= 0.0:
			reiniciar_sequencia()


func _sincronizar_estilo() -> void:
	if _executor != null and _estilo_sequencia != _executor.estilo:
		_estilo_sequencia = _executor.estilo
		reiniciar_sequencia()


func _ao_iniciar_golpe(golpe: GolpeDirecional, _id: int) -> void:
	_sincronizar_estilo()
	if _estilo_sequencia == null or _estilo_sequencia.sequencia_cliques.is_empty():
		return
	var indice := _estilo_sequencia.sequencia_cliques.find(golpe.direcao)
	_proximo_soco = (indice + 1) % _estilo_sequencia.sequencia_cliques.size()


func _ao_encerrar_golpe(_id: int, motivo: StringName) -> void:
	if motivo == &"fim" and _estilo_sequencia != null:
		_restante_sequencia = _estilo_sequencia.janela_sequencia
	else:
		reiniciar_sequencia()


# ------------------------------------------------------------- leitura pura
func registrar_movimento(relativo_px: Vector2, agora_ms: int) -> void:
	_mov[_proxima] = relativo_px * _sensibilidade
	_ms[_proxima] = agora_ms
	_proxima = (_proxima + 1) % _CAPACIDADE


## Soma do gesto nos últimos `janela` segundos, em radianos (y para baixo, como a tela).
func gesto_em(agora_ms: int) -> Vector2:
	var limite := agora_ms - int(janela * 1000.0)
	var soma := Vector2.ZERO
	for i in _CAPACIDADE:
		if _ms[i] >= limite and _ms[i] <= agora_ms:
			soma += _mov[i]
	return soma


func direcao_em(agora_ms: int) -> GolpeDirecional.Direcao:
	return classificar(gesto_em(agora_ms), zona_morta)


static func classificar(gesto: Vector2, limiar: float) -> GolpeDirecional.Direcao:
	if gesto.length() < limiar:
		return GolpeDirecional.Direcao.FRENTE
	if absf(gesto.x) >= absf(gesto.y):
		return GolpeDirecional.Direcao.PARA_ESQUERDA if gesto.x < 0.0 else GolpeDirecional.Direcao.PARA_DIREITA
	return GolpeDirecional.Direcao.DE_CIMA if gesto.y < 0.0 else GolpeDirecional.Direcao.FRENTE


func esquecer_gesto() -> void:
	_ms.fill(-1)


func _mira_ativa() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or ToqueHud.ativo()
