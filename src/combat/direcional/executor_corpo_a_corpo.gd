class_name ExecutorCorpoACorpo
extends Node
# ============================================================================
#  EXECUTOR DO COMBATE DIRECIONAL — Modo História.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D1, D3, D4, D5, D6, D8, D9).
#  Inspiração: Chivalry 2.
#
#  Quem EXECUTA um golpe: relógio, fases, buffer, cancelamento, pose, contato,
#  reação. Quem DECIDE é outro — a entrada do jogador ou uma IA — e só chama
#  `pedir_ataque`. Por isso aqui não há Input, HUD, RPC nem `Player`: o corpo
#  chega por um `AtorDeCombate`.
#
#  ---------------------------------------------------------------- UM RELÓGIO
#  `_t_acao` conta desde o início do golpe, e a fase é DERIVADA dele pela ficha
#  (`GolpeDirecional.fase_em`). A pose, a varredura e as janelas leem esse mesmo
#  número.
#
#  ⚠️ Nada de SceneTreeTimer para regra de jogo. Timer agendado não enxerga
#  cancelamento: foi assim que a hitbox do M1 da arena ficou impossível de
#  cancelar (docs/erros.md, 2026-09-16; LISTA_DE_CORRECOES, item 59).
#
#  ---------------------------------------------------- CANCELAR = TROCAR O ID
#  Todo golpe nasce com um `id_acao` novo, e cancelar também troca o id. Quem
#  guardar referência a um golpe confere `golpe_valido(id)` antes de agir.
#
#  -------------------------------------------------------------- A ORDEM NO QUADRO
#  É filho do corpo e roda DEPOIS dele (ordem da árvore): o animador já escreveu o
#  corpo deste quadro quando o executor chega. Então, a cada quadro:
#     1. relógio e fases       2. pose sobre o animador      3. varredura no ATIVO
#  A varredura lê a posição REAL do punho depois da pose — o dano sai de onde o
#  punho está na tela, não de uma conta paralela.
#
#  ---------------------------------------------------------------- O CONTATO
#  Resolvido ANTES do dano (`ResolucaoDeContato`); só ACERTO chama o funil de dano
#  de sempre (`CombatResolver.aplicar`). A `DamageZone` e o `CombatResolver` da
#  arena ficam intocados.
#
#  --------------------------------------------------------------- O HITSTOP
#  POR ATOR: pausa o relógio deste executor e o do defensor. Nunca
#  `Engine.time_scale` — aquilo desacelera o mundo inteiro (LISTA, item 60).
# ============================================================================

const Sweep = preload("res://src/combat/SwordSweep.gd")

## Camadas de física que o golpe varre — as mesmas do Boss (personagens e cenário).
## Camadas 1–4 (corpos) + a da hurtbox de combate (`HurtboxDeCombate.CAMADA`).
const MASCARA_DE_CONTATO := 15 | (1 << 20)

signal estado_mudou(anterior: Estado, novo: Estado)
signal golpe_iniciado(golpe: GolpeDirecional, id_acao: int)
signal fase_mudou(id_acao: int, fase: GolpeDirecional.Fase)
signal golpe_encerrado(id_acao: int, motivo: StringName)
## O golpe deste executor tocou `alvo`. `resultado` é `ResolucaoDeContato.Resultado`
## e `lado` é `ResolucaoDeContato.Lado` (lado do DEFENSOR).
signal contato(id_acao: int, alvo: Node3D, resultado: int, lado: int, posicao: Vector3, golpe: GolpeDirecional)
## Este corpo foi atingido e entrou em reação.
signal reagiu(lado: int, pesado: bool)
## A guarda deste corpo segurou um golpe (sem dano; a postura caiu).
signal bloqueou(golpe: GolpeDirecional, posicao: Vector3)
## A guarda deste corpo quebrou: atordoado, sem guarda, pelo tempo da ficha.
signal guarda_quebrada(golpe: GolpeDirecional, posicao: Vector3)
## A guarda deste corpo APAROU `golpe`: quem atacou foi rebatido e a janela de riposte abriu.
signal aparou(golpe: GolpeDirecional, posicao: Vector3)
## O golpe deste corpo foi aparado: rebatido, sem agir, por `duracao_rebatido`.
signal rebatido()
## Este corpo fintou: trocou o golpe em preparo (`para` = direção nova, ou −1 = guarda).
signal fintou(de: int, para: int)

## GUARDA: RMB segurado, bloqueia no cone (e APARA na janela de um aperto novo).
## BAIXANDO: soltou; a guarda não volta até acabar. QUEBRA: a postura zerou.
## REBATIDO: o golpe deste corpo foi aparado.
enum Estado { NEUTRO, PREPARO, ATIVO, RECUPERACAO, REACAO, GUARDA, BAIXANDO, QUEBRA, REBATIDO }

## Quanto a guarda leva para subir da guarda de combate para a guarda erguida.
const ERGUER_GUARDA := 0.10
## Duração do tranco na pose quando a guarda segura um golpe.
const TRANCO_NA_GUARDA := 0.25
## Duração do gesto de aparo na pose (a guarda que desvia o golpe).
const GESTO_DE_APARO := 0.30
## Quanto uma troca de ação (guarda → golpe, finta, golpe → rebote) leva para levar a
## pose de uma para a outra. Sem isso a pose saltaria entre as duas num quadro.
const TRANSICAO_ENTRE_ACOES := 0.10

var estilo: EstiloCorpoACorpo
var ator: AtorDeCombate
## Escala o dano dos golpes DESTE corpo. O mesmo estilo serve jogador e inimigo; o
## que muda é o quanto machuca — a vida do jogador na história começa em 20 e o
## gancho da ficha tira 30 (plano, §7.4). Um estilo por escala duplicaria poses.
var multiplicador_de_dano := 1.0
## Acerto recebido no PREPARO não interrompe o golpe (só o jogador da história liga; ver `receber_acerto`).
var armadura_no_preparo := false
## `max_strikes` do Epic Fight: quantos alvos UM golpe atinge (os mais próximos primeiro). 0 = sem limite (o comportamento de todas as outras armas).
var max_alvos := 0
## Sons da arma empunhada: `{golpe: [nomes], impacto: [nomes]}` (Epic Fight). Vazio = os sons padrão do jogo (`ApresentacaoDeCombate`).
var sons_da_arma := {}
## Escala extra SÓ no estilo desarmado — o que o executor recebeu em `montar` (23/10/2026:
## soco do jogador da história −50 %, `Balance.HISTORIA_SOCO`). Espada e machado trocam de
## estilo e ficam de fora; voltar ao desarmado volta a valer.
var multiplicador_desarmado := 1.0
var _estilo_desarmado: EstiloCorpoACorpo

var estado: Estado = Estado.NEUTRO
## O golpe em curso; nulo fora de ataque.
var golpe_atual: GolpeDirecional = null
## Identidade da ação corrente. Muda ao começar, ao cancelar e ao ser atingido.
var id_acao := 0

var _t_acao := 0.0
var _buffer_ativo := false
var _buffer_direcao: GolpeDirecional.Direcao = GolpeDirecional.Direcao.FRENTE

var _hitstop := 0.0
var _peso_pose := 0.0
var _pose := {}                # reaproveitado a cada quadro (PoseDeCombate escreve nele)
var _efetor_anterior := Vector3.ZERO
var _base_anterior := Vector3.INF
var _tem_efetor_anterior := false
var _ja_acertados := {}        # instance id → true, por golpe
var _acertou := false
## `id_acao` do golpe que levou um acerto no ATIVO. Até ele acabar, o atordoamento que o
## funil de dano deixa no corpo não o cancela (§7.1); as travas duras continuam valendo.
var _id_que_trocou := -1

# Postura de combate: tempo desde a volta ao neutro e a pose daquele instante.
var _t_neutro := INF
var _pose_saida := {}
## Quanto a pose do fim de uma ação leva para assentar na guarda.
const ASSENTAR_NA_GUARDA := 0.15

var _reacao_chave: ChaveDePose = null
var _reacao_duracao := 0.0
var _t_reacao := 0.0

## Resistência atual da guarda (interna; sem barra). Começa cheia.
var postura := 0.0
var _t_sem_bloquear := INF
## Intenção de defender (RMB segurado, ou a IA pedindo). A máquina de estados entra em
## GUARDA assim que o estado atual permitir — não é um evento que se perde.
var _guarda_pedida := false
var _t_estado := 0.0
var _t_tranco_guarda := INF
var _pose_a := {}   # buffers de mistura reaproveitados
var _pose_b := {}

## Tempo desde o último APERTO NOVO de guarda (não conta o botão segurado). A janela de
## aparo conta daqui, e não da entrada na guarda: apertar de novo durante BAIXANDO
## (0,2 s) gasta a janela antes de a guarda subir — o spam de aparo morre por construção.
var _t_desde_aperto := INF
## Tempo desde o último aparo bem-sucedido (janela de riposte).
var _t_riposte := INF
var _t_gesto_de_aparo := INF
## O golpe em curso é riposte (preparo acelerado; não finta).
var _riposte := false
## O golpe em curso já veio de uma finta (uma por ataque).
var _fintou := false
## Quanto falta da recuperação que a GUARDA interrompeu. Largar o golpe pela guarda
## serve para DEFENDER mais cedo, não para atacar mais cedo: até isto zerar, o clique de
## ataque segue a regra do buffer da recuperação (portão de game feel das Fases 4–5).
var _t_recuperacao_pendente := 0.0
## Quanto faltava do preparo de um golpe fintado para a guarda. Golpe começado antes
## disso herda a finta — "uma por ataque" não pode vazar pela guarda.
var _t_finta_pendente := 0.0
## O avanço que o corpo SOMOU neste quadro físico. O corpo pede `impulso_do_quadro()`
## antes de o executor andar o relógio; lido de novo na hora da pose, na virada de fase,
## ele já seria o do quadro seguinte (medido: 0,72 de "andando" num quadro só).
var _avanco_aplicado := Vector3.ZERO
var _pose_de_transicao := {}
var _t_transicao := INF


func montar(novo_ator: AtorDeCombate, novo_estilo: EstiloCorpoACorpo) -> void:
	ator = novo_ator
	estilo = novo_estilo
	_estilo_desarmado = novo_estilo
	postura = estilo.postura_maxima if estilo != null else 0.0


## Trocar equipamento limpa golpes/guarda/pose, preservando desgaste de postura.
func trocar_estilo(novo: EstiloCorpoACorpo) -> void:
	if estilo == novo:
		return
	var sofrendo := estado in [Estado.REACAO, Estado.QUEBRA, Estado.REBATIDO]
	var pendente := golpe_atual.duracao() - _t_acao if atacando() else 0.0
	var fim_punicao := estilo.duracao_da_quebra if estado == Estado.QUEBRA else estilo.duracao_rebatido
	var restante := maxf(0.0, fim_punicao - _t_estado)
	if not sofrendo:
		cancelar(&"equipamento")
	else:
		_buffer_ativo = false
	estilo = novo
	# Trocar arma não compra outro ataque imediato nem apaga quebra/reação/aparo.
	_t_recuperacao_pendente = maxf(_t_recuperacao_pendente, pendente)
	if estado in [Estado.QUEBRA, Estado.REBATIDO]:
		var novo_fim := estilo.duracao_da_quebra if estado == Estado.QUEBRA else estilo.duracao_rebatido
		_t_estado = novo_fim - restante
	postura = minf(postura, estilo.postura_maxima)
	_guarda_pedida = false
	_t_desde_aperto = INF
	_t_riposte = INF
	_hitstop = 0.0
	_peso_pose = 0.0
	_t_neutro = INF
	_pose.clear()
	_pose_saida.clear()
	_pose_de_transicao.clear()
	_tem_efetor_anterior = false
	_base_anterior = Vector3.INF


func _physics_process(delta: float) -> void:
	var t := Cronometro.ini()
	_physics_process_corpo(delta)
	Cronometro.fim(&"ExecutorCorpoACorpo.fisica", t)


func _physics_process_corpo(delta: float) -> void:
	if (get_parent().get_meta("giro_espada_ativo", false) or get_parent().get_meta("magu_cao_ativo", false) \
			or get_parent().get_meta("machado_arremesso_ativo", false) or get_parent().has_meta("combate_mine_piece")):
		return # a técnica assume a pose e o contato enquanto gira
	# Corpo lento (skill do Builder, 06/10/2026): o golpe inteiro anda no tempo dele.
	avancar(delta * Lentidao.fator(get_parent()))


# -------------------------------------------------------------------- pedidos
## Pedido de ataque vindo de quem decide. Devolve `true` se o golpe começou ou
## ficou guardado no buffer.
func pedir_ataque(direcao: GolpeDirecional.Direcao) -> bool:
	if get_parent() != null and get_parent().has_meta("combate_mine_piece"):
		return false
	if ator == null or estilo == null:
		return false
	match estado:
		Estado.NEUTRO, Estado.GUARDA, Estado.BAIXANDO:
			# Da guarda se ataca direto: o preparo do golpe já é o custo de largá-la.
			if not ator.pode_iniciar():
				return false
			if _t_recuperacao_pendente > 0.0:
				# A guarda tirou o corpo do golpe, mas a recuperação dele ainda corre.
				return _guardar_no_buffer(direcao, _t_recuperacao_pendente)
			return _iniciar_golpe(direcao, janela_de_riposte_aberta())
		Estado.PREPARO:
			# Clique com OUTRA direção no começo do preparo: finta (troca de golpe).
			return _fintar_para_golpe(direcao)
		Estado.RECUPERACAO:
			# Só o fim da recuperação guarda o clique (`_guardar_no_buffer`).
			if not ator.pode_iniciar():
				return false
			return _guardar_no_buffer(direcao, golpe_atual.duracao() - _t_acao)
	# ATIVO: o golpe está comprometido. REAÇÃO, QUEBRA, REBATIDO: sofrendo.
	return false


## Começar a defender (RMB apertado / IA). Vale até `baixar_guarda`.
## Um APERTO NOVO (a guarda não estava pedida) abre a janela de aparo e, no começo do
## preparo de um golpe, é uma finta para a guarda.
func erguer_guarda() -> void:
	var aperto_novo := not _guarda_pedida
	_guarda_pedida = true
	if aperto_novo:
		_t_desde_aperto = 0.0
		if estado == Estado.PREPARO:
			_fintar_para_guarda()
	_tentar_guarda()


## Parar de defender (RMB solto). A guarda passa por BAIXANDO antes de poder voltar.
func baixar_guarda() -> void:
	_guarda_pedida = false
	_t_desde_aperto = INF
	if estado == Estado.GUARDA:
		_mudar_estado(Estado.BAIXANDO)


func em_guarda() -> bool:
	return estado == Estado.GUARDA


func guarda_pedida() -> bool:
	return _guarda_pedida


## A guarda está na janela de aparo agora?
func aparando() -> bool:
	return estado == Estado.GUARDA and estilo != null and _t_desde_aperto <= estilo.janela_de_aparo


func janela_de_riposte_aberta() -> bool:
	return estilo != null and _t_riposte < estilo.janela_de_riposte


func golpe_e_riposte() -> bool:
	return _riposte and atacando()


## Este corpo APAROU `golpe`: abre a janela de riposte. A janela de aparo é gasta — o
## golpe seguinte do mesmo aperto é só bloqueado.
func aparar(_golpe: GolpeDirecional) -> void:
	_t_riposte = 0.0
	_t_gesto_de_aparo = 0.0
	_t_desde_aperto = INF


## O golpe deste corpo foi aparado: some, e o corpo fica rebatido sem agir.
func ser_aparado() -> void:
	_capturar_transicao()
	_buffer_ativo = false   # sofrer descarta o clique guardado, dentro ou fora de golpe
	if atacando():
		var id_interrompido := id_acao
		golpe_atual = null
		golpe_encerrado.emit(id_interrompido, &"aparado")
	id_acao += 1
	_mudar_estado(Estado.REBATIDO)
	rebatido.emit()


## A guarda deste corpo segurou `golpe`: a postura cai e a pose dá um tranco.
func receber_bloqueio(golpe: GolpeDirecional) -> void:
	receber_bloqueio_de_postura(golpe.dano_de_postura)


## O mesmo bloqueio, para quem NÃO é golpe deste executor: a explosão de uma técnica de
## fruta gasta postura e dá o tranco na pose, sem ficha de golpe (22/09/2026).
func receber_bloqueio_de_postura(dano_de_postura: float) -> void:
	postura = maxf(postura - dano_de_postura, 0.0)
	_t_sem_bloquear = 0.0
	_t_tranco_guarda = 0.0


## A postura zerou: sem guarda e sem ataque por `duracao_da_quebra`. O corpo sai
## dela com `postura_apos_quebra`. Sem dano — o castigo é o próximo golpe entrar.
func quebrar_guarda(_golpe: GolpeDirecional) -> void:
	_buffer_ativo = false   # sofrer descarta o clique guardado, dentro ou fora de golpe
	if atacando():
		var id_interrompido := id_acao
		golpe_atual = null
		golpe_encerrado.emit(id_interrompido, &"quebra")
	id_acao += 1
	postura = estilo.postura_apos_quebra
	_t_sem_bloquear = 0.0
	_mudar_estado(Estado.QUEBRA)


## Interrompe a ação em curso. `motivo` segue no sinal (`&"impedido"`, `&"dano"`…).
func cancelar(motivo: StringName) -> void:
	_buffer_ativo = false
	if estado == Estado.NEUTRO:
		return
	var id_encerrado := id_acao
	id_acao += 1
	_encerrar(id_encerrado, motivo)


## Pausa este executor (relógio e pose congelados) por `duracao` segundos.
func pausar(duracao: float) -> void:
	_hitstop = maxf(_hitstop, duracao)


## Este corpo foi atingido por `golpe` pelo `lado` dele.
##
## Acerto no PREPARO ou na RECUPERAÇÃO interrompe (o tranco vence a intenção).
## Acerto no ATIVO NÃO interrompe: o golpe já está comprometido, e os dois trocam
## dano — regra declarada no plano (§7.1). O choque de dois ativos é V3.
##
## ⚠️ O dano chega DEPOIS, pelo `take_damage`, e o do Player atordoa sempre. Sem marcar o
## golpe aqui, `ator.impedido()` o cancelaria no quadro seguinte — só no jogador, porque
## o boneco não atordoa (achado em 21/09; `test_contato_historia`, seção F).
func receber_acerto(golpe: GolpeDirecional, lado: int) -> void:
	# `armadura_no_preparo` (decisão do dono, 15/11/2026): o jogador da história não perde a sequência de socos para um inimigo que o
	# acerta pelas costas — o PREPARO passa a ter a mesma proteção do ATIVO (o dano entra, o golpe segue).
	if estado == Estado.ATIVO or (armadura_no_preparo and estado == Estado.PREPARO):
		_id_que_trocou = id_acao
		return
	_buffer_ativo = false   # sofrer descarta o clique guardado, dentro ou fora de golpe
	if atacando():
		var id_interrompido := id_acao
		golpe_atual = null
		golpe_encerrado.emit(id_interrompido, &"acerto")
	id_acao += 1
	_reacao_chave = estilo.reacao_para(lado, golpe.pesado) if estilo != null else null
	_reacao_duracao = maxf(golpe.hitstun, 0.05)
	_t_reacao = 0.0
	_mudar_estado(Estado.REACAO)
	reagiu.emit(lado, golpe.pesado)


# ---------------------------------------------------------------------- ciclo
func avancar(delta: float) -> void:
	_avanco_aplicado = impulso_do_quadro()   # mesmo relógio que o corpo acabou de usar
	if _hitstop > 0.0:
		_hitstop = maxf(_hitstop - delta, 0.0)
		_posar(0.0)   # congelado, mas a pose continua sobre o animador
		return
	_regenerar_postura(delta)
	_t_estado += delta
	_t_tranco_guarda += delta
	_t_desde_aperto += delta
	_t_riposte += delta
	_t_gesto_de_aparo += delta
	_t_transicao += delta
	_t_recuperacao_pendente = maxf(_t_recuperacao_pendente - delta, 0.0)
	_t_finta_pendente = maxf(_t_finta_pendente - delta, 0.0)
	match estado:
		Estado.NEUTRO:
			pass
		Estado.REACAO:
			_t_reacao += delta
			if _t_reacao >= _reacao_duracao:
				_mudar_estado(Estado.NEUTRO)
		Estado.GUARDA:
			if ator != null and ator.impedido():
				_mudar_estado(Estado.NEUTRO)
		Estado.BAIXANDO:
			if _t_estado >= estilo.baixar_guarda:
				_mudar_estado(Estado.NEUTRO)
		Estado.QUEBRA:
			if _t_estado >= estilo.duracao_da_quebra:
				_mudar_estado(Estado.NEUTRO)
		Estado.REBATIDO:
			if _t_estado >= estilo.duracao_rebatido:
				_mudar_estado(Estado.NEUTRO)
		_:
			# O golpe que trocou dano no ATIVO só cai por trava dura, não pelo atordoamento.
			if ator != null and ator.impedido(_id_que_trocou != id_acao):
				cancelar(&"impedido")
			else:
				_avancar_golpe(delta)
	_soltar_buffer_pendente()
	_tentar_guarda()
	_posar(delta)
	if estado == Estado.ATIVO:
		_varrer()
	elif atacando():
		_seguir_efetor()


# -------------------------------------------------------------------- leitura
func ocupado() -> bool:
	return estado != Estado.NEUTRO


func atacando() -> bool:
	return estado == Estado.PREPARO or estado == Estado.ATIVO or estado == Estado.RECUPERACAO


func em_preparo() -> bool:
	return estado == Estado.PREPARO


## `true` enquanto `id` for a ação corrente e ela não tiver acabado.
func golpe_valido(id: int) -> bool:
	return id == id_acao and atacando()


func fase() -> GolpeDirecional.Fase:
	return golpe_atual.fase_em(_t_acao) if golpe_atual != null else GolpeDirecional.Fase.FIM


func tempo_da_acao() -> float:
	return _t_acao


func tem_buffer() -> bool:
	return _buffer_ativo


func em_hitstop() -> bool:
	return _hitstop > 0.0


func peso_da_pose() -> float:
	return _peso_pose


## Fração da velocidade de andar liberada agora (1,0 livre).
func fator_de_movimento() -> float:
	match estado:
		Estado.GUARDA, Estado.BAIXANDO:
			return estilo.fator_movimento_guarda
		Estado.QUEBRA, Estado.REBATIDO:
			return estilo.fator_movimento_quebra
	return golpe_atual.fator_movimento(fase()) if golpe_atual != null else 1.0


## Giro máximo do corpo agora, em rad/s (INF fora de ataque).
func giro_maximo() -> float:
	return golpe_atual.giro_maximo(fase()) if golpe_atual != null else INF


## Velocidade (m/s) que o golpe soma ao corpo neste quadro: o avanço da ficha,
## distribuído da metade do preparo ao fim do ativo. Acertar corta o resto — quem
## conecta para onde conectou (mesma regra do `advance` da Yoru). O corpo soma isto
## por cima da locomoção, como soma o knockback.
func impulso_do_quadro() -> Vector3:
	if golpe_atual == null or _acertou or _hitstop > 0.0 or golpe_atual.avanco <= 0.0 or ator == null:
		return Vector3.ZERO
	var inicio := golpe_atual.preparo * 0.5
	var fim := golpe_atual.preparo + golpe_atual.ativo
	if _t_acao < inicio or _t_acao >= fim:
		return Vector3.ZERO
	return ator.base_do_corpo() * Vector3.FORWARD * (golpe_atual.avanco / (fim - inicio))


# -------------------------------------------------------------------- interno
func _avancar_golpe(delta: float) -> void:
	var id := id_acao
	var antes := golpe_atual.fase_em(_t_acao)
	# Riposte: o PREPARO corre mais rápido (fator da ficha). O relógio é o mesmo — a pose,
	# a janela e o avanço seguem juntos, só chegam antes.
	if _riposte and antes == GolpeDirecional.Fase.PREPARO:
		_t_acao += delta / estilo.fator_de_riposte
	else:
		_t_acao += delta
	var agora := golpe_atual.fase_em(_t_acao)
	# Atravessa as fases UMA A UMA: um quadro longo (engasgo) não pode pular o
	# ATIVO sem avisá-lo — quem depende do sinal de fase perderia o golpe.
	var f: int = antes
	while f < agora and id == id_acao:
		f += 1
		_entrar_na_fase(id, f as GolpeDirecional.Fase)


func _iniciar_golpe(direcao: GolpeDirecional.Direcao, riposte := false, veio_de_finta := false) -> bool:
	var golpe := estilo.golpe_para(direcao)
	if golpe == null:
		return false
	if estado != Estado.NEUTRO:
		_capturar_transicao()
	_riposte = riposte
	# Riposte não finta; finta só uma por ataque — também a que passou pela guarda.
	_fintou = veio_de_finta or riposte or _t_finta_pendente > 0.0
	if riposte:
		_t_riposte = INF   # a janela foi usada
	id_acao += 1
	golpe_atual = golpe
	_t_acao = 0.0
	_buffer_ativo = false
	_tem_efetor_anterior = false
	_ja_acertados.clear()
	_acertou = false
	_mudar_estado(Estado.PREPARO)
	golpe_iniciado.emit(golpe, id_acao)
	fase_mudou.emit(id_acao, GolpeDirecional.Fase.PREPARO)
	if golpe.clipe != "" and ator != null:
		ator.tocar_clipe_de_golpe(golpe.clipe, golpe.duracao() * golpe.velocidade_clipe, golpe.velocidade_clipe)
	return true


func _entrar_na_fase(id: int, nova: GolpeDirecional.Fase) -> void:
	match nova:
		GolpeDirecional.Fase.ATIVO:
			_mudar_estado(Estado.ATIVO)
			fase_mudou.emit(id, nova)
		GolpeDirecional.Fase.RECUPERACAO:
			_mudar_estado(Estado.RECUPERACAO)
			fase_mudou.emit(id, nova)
		GolpeDirecional.Fase.FIM:
			fase_mudou.emit(id, nova)
			var guardado := _buffer_ativo
			var direcao := _buffer_direcao
			_encerrar(id, &"fim")
			if guardado and ator != null and ator.pode_iniciar():
				_iniciar_golpe(direcao)


func _encerrar(id_encerrado: int, motivo: StringName) -> void:
	if golpe_atual != null and golpe_atual.clipe != "" and ator != null:
		ator.parar_clipe_de_golpe()
	golpe_atual = null
	_t_acao = 0.0
	_buffer_ativo = false
	_mudar_estado(Estado.NEUTRO)
	golpe_encerrado.emit(id_encerrado, motivo)


func _mudar_estado(novo: Estado) -> void:
	if novo == estado:
		return
	var anterior := estado
	# Transição só entre AÇÕES diferentes. As fases de um mesmo golpe já são contínuas
	# na pose; misturar uma foto parada no começo do ATIVO atrasaria o punho justo
	# quando a varredura liga (quebraria a sincronia medida na Fase 3).
	if anterior != Estado.NEUTRO and novo != Estado.NEUTRO and not (_e_fase_de_golpe(anterior) and _e_fase_de_golpe(novo)):
		_capturar_transicao()
	estado = novo
	_t_estado = 0.0
	if novo == Estado.NEUTRO:
		_t_neutro = 0.0
		_pose_saida = _pose.duplicate(true)   # só na troca de estado, não por quadro
	estado_mudou.emit(anterior, novo)


## A camada de pose: entra em `transicao_entrada`, sai em `transicao_saida`.
##
## No NEUTRO, por `guarda_apos_acao` segundos, o corpo fica em GUARDA — a pose do
## fim da ação assenta nela em `ASSENTAR_NA_GUARDA` — e só depois devolve o corpo ao
## animador. Um golpe cancelado sai de ONDE ESTAVA, sem estalo.
func _posar(delta: float) -> void:
	if ator == null or estilo == null or estilo.guarda == null:
		return
	# Roll/deslize: o clipe é dono do corpo. Zera o peso (a guarda reentra suave ao
	# fim do clipe) em vez de sobrescrever os membros que o clipe acabou de escrever.
	if estado == Estado.NEUTRO and ator.corpo_em_acao():
		_peso_pose = 0.0
		return
	# Golpe com CLIPE (Epic Fight): o clipe é dono do corpo; a pose procedural não entra por cima.
	if golpe_atual != null and golpe_atual.clipe != "" and estado in [Estado.PREPARO, Estado.ATIVO, Estado.RECUPERACAO]:
		_peso_pose = 0.0
		return
	var em_postura := false
	if estado == Estado.NEUTRO:
		_t_neutro += delta
		em_postura = estilo.manter_postura or _t_neutro < estilo.guarda_apos_acao
	var alvo := 0.0 if estado == Estado.NEUTRO and not em_postura else 1.0
	var duracao := estilo.transicao_entrada if alvo > _peso_pose else estilo.transicao_saida
	_peso_pose = move_toward(_peso_pose, alvo, delta / duracao) if duracao > 0.0 else alvo
	if _peso_pose <= 0.0:
		return
	match estado:
		Estado.PREPARO, Estado.ATIVO, Estado.RECUPERACAO:
			PoseDeCombate.amostrar(golpe_atual, estilo.guarda, _t_acao, _pose)
		Estado.REACAO:
			if _reacao_chave != null:
				PoseDeCombate.reacao(estilo.guarda, _reacao_chave, _t_reacao / _reacao_duracao, _pose)
		Estado.GUARDA:
			if _t_gesto_de_aparo < GESTO_DE_APARO:
				PoseDeCombate.reacao(estilo.pose_guarda_erguida, estilo.pose_aparo,
					_t_gesto_de_aparo / GESTO_DE_APARO, _pose, estilo.guarda)
			elif _t_tranco_guarda < TRANCO_NA_GUARDA:
				PoseDeCombate.reacao(estilo.pose_guarda_erguida, estilo.pose_impacto_na_guarda,
					_t_tranco_guarda / TRANCO_NA_GUARDA, _pose, estilo.guarda)
			else:
				PoseDeCombate.guarda(estilo.guarda, _pose_a)
				PoseDeCombate.guarda(estilo.pose_guarda_erguida, _pose_b, estilo.guarda)
				PoseDeCombate.misturar(_pose_a, _pose_b,
					ChaveDePose.aplicar_curva(ChaveDePose.Curva.DESACELERA, _t_estado / ERGUER_GUARDA), _pose)
		Estado.BAIXANDO:
			PoseDeCombate.guarda(estilo.pose_guarda_erguida, _pose_a, estilo.guarda)
			PoseDeCombate.guarda(estilo.guarda, _pose_b)
			PoseDeCombate.misturar(_pose_a, _pose_b,
				ChaveDePose.aplicar_curva(ChaveDePose.Curva.SUAVE, _t_estado / estilo.baixar_guarda), _pose)
		Estado.QUEBRA:
			PoseDeCombate.reacao(estilo.guarda, estilo.pose_quebra_de_guarda,
				_t_estado / estilo.duracao_da_quebra, _pose)
		Estado.REBATIDO:
			PoseDeCombate.reacao(estilo.guarda, estilo.pose_rebatido,
				_t_estado / estilo.duracao_rebatido, _pose)
		Estado.NEUTRO:
			if em_postura:
				PoseDeCombate.guarda(estilo.guarda, _pose)
				if not _pose_saida.is_empty() and _t_neutro < ASSENTAR_NA_GUARDA:
					PoseDeCombate.misturar(_pose_saida, _pose.duplicate(true),
						ChaveDePose.aplicar_curva(ChaveDePose.Curva.SUAVE, _t_neutro / ASSENTAR_NA_GUARDA), _pose)
	if _t_transicao < TRANSICAO_ENTRE_ACOES and not _pose_de_transicao.is_empty() and not _pose.is_empty():
		PoseDeCombate.misturar(_pose_de_transicao, _pose,
			ChaveDePose.aplicar_curva(ChaveDePose.Curva.SUAVE, _t_transicao / TRANSICAO_ENTRE_ACOES), _pose)
	if not _pose.is_empty():
		# Sofrendo (tranco, quebra, rebote) o corpo é EMPURRADO, não anda: pernas com a pose e
		# pés derrapando. Lendo o empurrão como marcha, o boneco "corria" sob o acerto pesado.
		var arrastado := estado == Estado.REACAO or estado == Estado.QUEBRA or estado == Estado.REBATIDO
		var em_repouso := estado == Estado.NEUTRO or estado == Estado.GUARDA or estado == Estado.BAIXANDO
		ator.aplicar_pose(_pose, _peso_pose, estilo, _avanco_aplicado, delta, arrastado, em_repouso)


func _seguir_efetor() -> void:
	var p := ator.posicao_do_no(golpe_atual.efetor) if ator != null else Vector3.INF
	_tem_efetor_anterior = p != Vector3.INF
	_efetor_anterior = p
	_base_anterior = ator.posicao_do_no(golpe_atual.efetor_base) if ator != null and golpe_atual.efetor_base != &"" else Vector3.INF


func _varrer() -> void:
	var golpe := golpe_atual
	var agora := ator.posicao_do_no(golpe.efetor)
	var espaco := ator.espaco()
	if agora == Vector3.INF or espaco == null:
		return
	var base := ator.posicao_do_no(golpe.efetor_base) if golpe.efetor_base != &"" else Vector3.INF
	# Soco/espada na fase ATIVA quebram construções em blocos (DestruicaoDeEstruturas limita ao redor do jogador).
	var arvore := ator.corpo().get_tree() if ator.corpo() != null else null
	DestruicaoDeEstruturas.golpe(arvore, agora, golpe.raio_de_contato + 0.25)
	if base != Vector3.INF:
		DestruicaoDeEstruturas.golpe(arvore, (base + agora) * 0.5, golpe.raio_de_contato + 0.25)
	if _tem_efetor_anterior:
		var id := id_acao
		var contatos: Array = []
		if base != Vector3.INF and _base_anterior != Vector3.INF:
			# Amostras sobrepostas da BASE à PONTA: não só a ponta nem esfera inflada.
			var passos := maxi(1, ceili(maxf(base.distance_to(agora), _base_anterior.distance_to(_efetor_anterior)) / golpe.raio_de_contato))
			for i in passos + 1:
				var u := float(i) / passos
				contatos.append_array(Sweep.contacts(espaco, _base_anterior.lerp(_efetor_anterior, u),
					base.lerp(agora, u), golpe.raio_de_contato, MASCARA_DE_CONTATO, ator.excluir()))
		else:
			contatos = Sweep.contacts(espaco, _efetor_anterior, agora, golpe.raio_de_contato,
				MASCARA_DE_CONTATO, ator.excluir())
		if max_alvos > 0 and contatos.size() > 1:
			var de := ator.corpo().global_position
			contatos.sort_custom(func(a, b): return de.distance_squared_to(a["position"]) < de.distance_squared_to(b["position"]))
		for hit in contatos:
			if max_alvos > 0 and _ja_acertados.size() >= max_alvos:
				break
			var alvo: Node3D = hit["body"]
			# Lâmina já além de uma parede não pode acertar pelo extremo distante.
			if base != Vector3.INF and (not Sweep.visible(espaco, ator.corpo().global_position, base, MASCARA_DE_CONTATO, ator.excluir()) \
					or not Sweep.visible(espaco, base, hit["position"], MASCARA_DE_CONTATO, ator.excluir())):
				continue
			var chave := alvo.get_instance_id()
			if _ja_acertados.has(chave):
				continue
			_ja_acertados[chave] = true
			_contato(alvo, hit["position"], agora - _efetor_anterior)
			if id != id_acao:
				return
	_base_anterior = base
	_efetor_anterior = agora
	_tem_efetor_anterior = true


func _contato(alvo: Node3D, posicao: Vector3, viagem: Vector3) -> void:
	if (alvo.get_meta("giro_espada_ativo", false) or alvo.get_meta("magu_cao_ativo", false)):
		return # imunidade também recusa reação/hitstop antes do funil de dano
	var golpe := golpe_atual
	var id := id_acao
	var defensor := alvo.get("combate_direcional") as ExecutorCorpoACorpo
	var base_defensor := defensor.ator.base_do_corpo() if defensor != null and defensor.ator != null \
		else alvo.global_basis.orthonormalized()
	var resultado := ResolucaoDeContato.resolver_entre(golpe, ator.corpo().global_position, defensor)
	var lado := ResolucaoDeContato.lado_do_impacto(viagem, ator.corpo().global_position,
		alvo.global_position, base_defensor)
	_acertou = true
	if resultado == ResolucaoDeContato.Resultado.APARO:
		# ⚠️ O atacante NÃO recebe hitstop aqui: somado ao rebote, ele passaria do
		# preparo do riposte, e o riposte viraria dano garantido (§7.5).
		defensor.aparar(golpe)
		defensor.pausar(golpe.hitstop)
		defensor.aparou.emit(golpe, posicao)
		ser_aparado()
		contato.emit(id, alvo, resultado, lado, posicao, golpe)
		return
	match resultado:
		ResolucaoDeContato.Resultado.BLOQUEIO:
			# A defesa é resolvida ANTES do dano: bloqueado, o funil de dano nem é chamado.
			defensor.receber_bloqueio(golpe)
			defensor.pausar(golpe.hitstop)
			defensor.bloqueou.emit(golpe, posicao)
		ResolucaoDeContato.Resultado.QUEBRA_DE_GUARDA:
			defensor.quebrar_guarda(golpe)
			defensor.pausar(golpe.hitstop)
			defensor.guarda_quebrada.emit(golpe, posicao)
		_:
			# A reação ANTES do dano: o `take_damage` do jogador atordoa, e a reação
			# precisa saber de que lado foi — informação que o funil de dano não carrega.
			if defensor != null:
				defensor.receber_acerto(golpe, lado)
				defensor.pausar(golpe.hitstop)
			var direcao := Vector3(viagem.x, 0.0, viagem.z)
			direcao = direcao.normalized() if direcao.length_squared() > 0.000001 else ator.base_do_corpo() * Vector3.FORWARD
			var mult := multiplicador_de_dano * (multiplicador_desarmado if estilo == _estilo_desarmado else 1.0)
			CombatResolver.aplicar(alvo, golpe.dano * mult, 0, 0.0, posicao, direcao * golpe.empurrao,
				golpe.hitstun, 0.0, false, ator.corpo())
	pausar(golpe.hitstop)
	contato.emit(id, alvo, resultado, lado, posicao, golpe)


## Entra em GUARDA se ela foi pedida e o estado atual deixa.
func _tentar_guarda() -> void:
	if not _guarda_pedida or ator == null or estilo == null:
		return
	match estado:
		Estado.NEUTRO:
			if ator.pode_iniciar():
				_mudar_estado(Estado.GUARDA)
		Estado.RECUPERACAO:
			# Só a parte final da recuperação cede à guarda: antes, o corpo está preso
			# ao golpe que soltou (§7.1).
			var liberada := golpe_atual.preparo + golpe_atual.ativo \
				+ golpe_atual.recuperacao * estilo.guarda_liberada_na_recuperacao
			if _t_acao >= liberada and ator.pode_iniciar():
				var pendente := golpe_atual.duracao() - _t_acao
				var id_encerrado := id_acao
				id_acao += 1
				_encerrar(id_encerrado, &"guarda")
				_t_recuperacao_pendente = pendente
				_mudar_estado(Estado.GUARDA)


func _regenerar_postura(delta: float) -> void:
	if estilo == null:
		return
	_t_sem_bloquear += delta
	if _t_sem_bloquear >= estilo.postura_atraso and postura < estilo.postura_maxima:
		postura = minf(postura + estilo.postura_regeneracao * delta, estilo.postura_maxima)


func _capturar_transicao() -> void:
	if not _pose.is_empty():
		_pose_de_transicao = _pose.duplicate(true)   # só na troca de ação, não por quadro
		_t_transicao = 0.0


## Finta pode acontecer agora? No começo do preparo, uma por ataque, com postura.
func pode_fintar() -> bool:
	if estado != Estado.PREPARO or golpe_atual == null or _fintou or _riposte or estilo == null:
		return false
	return _t_acao <= golpe_atual.preparo * estilo.janela_de_finta \
		and golpe_atual.preparo - _t_acao >= estilo.finta_minimo_restante \
		and postura >= estilo.custo_da_finta


func _fintar_para_golpe(direcao: GolpeDirecional.Direcao) -> bool:
	if not pode_fintar() or direcao == golpe_atual.direcao or estilo.golpe_para(direcao) == null:
		return false
	var de := golpe_atual.direcao
	_pagar_finta()
	golpe_encerrado.emit(id_acao, &"finta")
	_capturar_transicao()
	_iniciar_golpe(direcao, false, true)
	fintou.emit(de, direcao)
	return true


func _fintar_para_guarda() -> void:
	if not pode_fintar():
		return
	var de := golpe_atual.direcao
	_pagar_finta()
	_capturar_transicao()
	_t_finta_pendente = golpe_atual.preparo - _t_acao
	var id_encerrado := id_acao
	id_acao += 1
	_encerrar(id_encerrado, &"finta")
	_mudar_estado(Estado.GUARDA)
	fintou.emit(de, -1)


## Guarda o clique se faltar no máximo `buffer` para o corpo poder atacar. Mais cedo ele
## é descartado, e não guardado para depois: é isso que impede o spam de render golpe.
func _guardar_no_buffer(direcao: GolpeDirecional.Direcao, falta: float) -> bool:
	if falta > estilo.buffer:
		return false
	_buffer_ativo = true
	_buffer_direcao = direcao   # o mais recente vence: é a intenção de agora
	return true


## O clique guardado enquanto a recuperação interrompida pela guarda corria sai quando
## ela acaba (o do fim de um golpe inteiro sai em `_entrar_na_fase`).
func _soltar_buffer_pendente() -> void:
	if not _buffer_ativo or _t_recuperacao_pendente > 0.0:
		return
	if estado != Estado.NEUTRO and estado != Estado.GUARDA and estado != Estado.BAIXANDO:
		return
	_buffer_ativo = false
	if ator != null and ator.pode_iniciar():
		_iniciar_golpe(_buffer_direcao, janela_de_riposte_aberta())


func _pagar_finta() -> void:
	postura = maxf(postura - estilo.custo_da_finta, 0.0)
	_t_sem_bloquear = 0.0


static func _e_fase_de_golpe(e: Estado) -> bool:
	return e == Estado.PREPARO or e == Estado.ATIVO or e == Estado.RECUPERACAO
