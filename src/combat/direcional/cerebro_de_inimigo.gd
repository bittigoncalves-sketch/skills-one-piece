class_name CerebroDeInimigo
extends Node
# ============================================================================
#  CÉREBRO DE INIMIGO — o boneco de duelo como inimigo do mapa (30/09/2026).
#
#  Pedido do dono: o inimigo persegue o jogador e luta dentro de uma ZONA de 20 m
#  em volta do ponto onde o editor o pôs; se o jogador sai da zona (ou morre), ele
#  volta ao ponto; fora de combate, regenera vida.
#
#  Decide com a MESMA API que a entrada do jogador usa (`pedir_ataque`,
#  `erguer_guarda`, `baixar_guarda`) mais `andar`/`encarar` do corpo — igual ao
#  `CerebroDeTreino`, que continua sendo o parceiro previsível do F8. Este aqui é o
#  que se põe no mapa: anda, sorteia golpes e defende "às vezes", na leitura.
#
#  ------------------------------------------------------------------ ESTADOS
#    EM_CASA      parado no ponto, virado para onde o editor mandou; regenera
#    PERSEGUINDO  anda até o jogador (o jogador está dentro da zona)
#    LUTANDO      no alcance: golpes sorteados a intervalos; guarda/aparo na leitura
#    VOLTANDO     anda de volta ao ponto; regenera
#
#  A ZONA é medida do PONTO DE NASCIMENTO até o jogador — não do inimigo. Assim ele
#  nunca é puxado para longe de casa: segue o jogador só enquanto o jogador está lá.
#
#  ⚠️ Sem caminho (navmesh): anda em linha reta e escorrega em parede. GATILHO: o
#  primeiro mapa em que um inimigo precise contornar obstáculo → NavigationAgent3D.
#  ⚠️ Não cita `Player` por nome (armadilha do teste `godot -s`, ver o boneco): quem
#  entrega o alvo é um Callable.
# ============================================================================

enum Estado { EM_CASA, PERSEGUINDO, LUTANDO, VOLTANDO }

## Raio da zona de combate em volta do ponto de nascimento (pedido do dono).
const ZONA := 20.0
## Acima da caminhada do jogador (4,2 m/s), abaixo da corrida (6,3+): quem quer
## lutar é alcançado; quem corre, escapa.
const VELOCIDADE := 4.5
## Para de andar e luta a esta distância do jogador. O jab alcança ~1,5 m (erra a
## 1,6 m, medido no plano de combate) — perto o bastante para acertar, sem colar.
const ALCANCE := 1.3
## Histerese: só volta a perseguir além de ALCANCE + isto. Sem ela, um passo para
## trás do jogador fazia o inimigo alternar andar/lutar a cada quadro.
const FOLGA_DE_ALCANCE := 0.4
## Intervalo entre golpes, sorteado a cada golpe (ritmo fixo se defende pelo ritmo).
const INTERVALO_MINIMO := 1.1
const INTERVALO_MAXIMO := 1.9
## Para cada golpe do jogador lido no preparo, a reação sorteada: aparar (guarda no
## último instante), bloquear (guarda já) ou nada. O resto da fração é "nada".
const CHANCE_DE_APARO := 0.25
const CHANCE_DE_GUARDA := 0.35
## Aparo: ergue a guarda quando falta isto do preparo do golpe do jogador.
const ANTECEDENCIA_DO_APARO := 0.10
## Só lê golpe do jogador a esta distância (mais longe, ele não alcança mesmo).
const LEITURA := 2.6
## Fração da vida máxima regenerada por segundo fora de combate (cheia em 10 s).
const REGENERACAO := 0.10
## Distância do ponto que conta como "chegou em casa".
const CHEGOU := 0.35

signal estado_mudou(anterior: Estado, novo: Estado)

var estado: Estado = Estado.EM_CASA
var _boneco: BonecoDeDuelo
var _alvo_de: Callable
var _casa := Vector3.ZERO
var _yaw_de_casa := 0.0
var _direcoes: Array[int] = []
var _t_ataque := 0.0
var _proximo_ataque := 1.0
var _golpe_lido := -1
## Decisão do dono (15/11/2026): inimigo NÃO se defende (sem guarda nem aparo) — só anda e ataca. `true` religa a leitura do golpe
## do jogador (as chances abaixo voltam a valer); `test_inimigo_lutador`/defesa podem ligar para medir.
var defende := false
var _reacao := 0            # 0 nada, 1 bloquear, 2 aparar — sorteada por golpe lido


## `alvo_de` devolve o jogador (ou null); `casa` é o chão do ponto de nascimento.
func montar(boneco: BonecoDeDuelo, alvo_de: Callable, casa: Vector3, yaw_de_casa: float) -> void:
	_boneco = boneco
	_alvo_de = alvo_de
	_casa = casa
	_yaw_de_casa = yaw_de_casa
	if boneco.combate_direcional != null and boneco.combate_direcional.estilo != null:
		_direcoes = boneco.combate_direcional.estilo.direcoes_com_golpe()
	_proximo_ataque = randf_range(INTERVALO_MINIMO, INTERVALO_MAXIMO)


func _physics_process(delta: float) -> void:
	var t := Cronometro.ini()
	_physics_process_corpo(delta)
	Cronometro.fim(&"Cerebro.fisica", t)


func _physics_process_corpo(delta: float) -> void:
	if not is_instance_valid(_boneco) or _boneco.health <= 0.0 or _boneco.combate_direcional == null:
		return
	var ex := _boneco.combate_direcional
	var alvo := _alvo_valido()
	_decidir_estado(alvo, ex)
	match estado:
		Estado.EM_CASA:
			_boneco.andar(Vector3.ZERO)
			_boneco.encarar_yaw(_yaw_de_casa)
			_regenerar(delta)
		Estado.VOLTANDO:
			_andar_ate(_casa, ex)
			_regenerar(delta)
		Estado.PERSEGUINDO:
			_andar_ate(alvo.global_position, ex)
			_boneco.encarar(alvo.global_position)
			_defender(ex, alvo)
		Estado.LUTANDO:
			_boneco.andar(Vector3.ZERO)
			_boneco.encarar(alvo.global_position)
			if not _defender(ex, alvo):
				_atacar(ex, delta)


## O jogador, se estiver vivo e DENTRO da zona (medida do ponto de nascimento).
func _alvo_valido() -> Node3D:
	if not _alvo_de.is_valid():
		return null
	var alvo := _alvo_de.call() as Node3D
	if not is_instance_valid(alvo) or not alvo.is_inside_tree():
		return null
	if float(alvo.get("health")) <= 0.0:
		return null
	# Camuflagem Transparente (Suke Suke Z): além de 4 m o inimigo perde o jogador de vista (antes só o modelo sumia).
	if alvo.has_method("esta_camuflado") and bool(alvo.call("esta_camuflado")) \
			and _plana(alvo.global_position - _boneco.global_position).length() > 4.0:
		return null
	return alvo if _plana(alvo.global_position - _casa).length() <= ZONA else null


func _decidir_estado(alvo: Node3D, ex: ExecutorCorpoACorpo) -> void:
	var novo := estado
	if alvo != null:
		var d := _plana(alvo.global_position - _boneco.global_position).length()
		if estado == Estado.LUTANDO:
			if d > ALCANCE + FOLGA_DE_ALCANCE:
				novo = Estado.PERSEGUINDO
		elif d <= ALCANCE:
			novo = Estado.LUTANDO
		else:
			novo = Estado.PERSEGUINDO
	elif estado == Estado.PERSEGUINDO or estado == Estado.LUTANDO:
		novo = Estado.VOLTANDO
	elif estado == Estado.VOLTANDO and _plana(_casa - _boneco.global_position).length() <= CHEGOU:
		novo = Estado.EM_CASA
	if novo == estado:
		return
	var anterior := estado
	estado = novo
	if novo == Estado.VOLTANDO or novo == Estado.EM_CASA:
		# Desengajou: larga a guarda e esquece o golpe lido. O golpe em curso termina
		# sozinho (cancelar no meio pareceria um tranco sem motivo).
		if ex.guarda_pedida():
			ex.baixar_guarda()
		_golpe_lido = -1
	if novo == Estado.LUTANDO:
		# Chegou agora: um respiro antes do primeiro golpe, para o jogador ler a luta.
		_t_ataque = 0.0
		_proximo_ataque = randf_range(INTERVALO_MINIMO * 0.5, INTERVALO_MINIMO)
	estado_mudou.emit(anterior, novo)


## Anda em linha reta até `ponto`, parando no golpe, na reação e na quebra de guarda.
func _andar_ate(ponto: Vector3, ex: ExecutorCorpoACorpo) -> void:
	var caminho := _plana(ponto - _boneco.global_position)
	var livre := not ex.atacando() and ex.estado not in [ExecutorCorpoACorpo.Estado.REACAO,
		ExecutorCorpoACorpo.Estado.QUEBRA, ExecutorCorpoACorpo.Estado.REBATIDO]
	if not livre or caminho.length() < 0.05:
		_boneco.andar(Vector3.ZERO)
		return
	_boneco.andar(caminho.normalized() * VELOCIDADE)
	if estado == Estado.VOLTANDO:
		_boneco.encarar(ponto)


## Lê o golpe do jogador. Devolve `true` enquanto está defendendo (aí não ataca).
func _defender(ex: ExecutorCorpoACorpo, alvo: Node3D) -> bool:
	if not defende:
		if ex.guarda_pedida():
			ex.baixar_guarda()
		return false
	if ex.janela_de_riposte_aberta() and not _direcoes.is_empty():
		# Aparou: a resposta é imediata (é o que o aparo compra).
		if ex.guarda_pedida():
			ex.baixar_guarda()
		ex.pedir_ataque(_direcoes.pick_random() as GolpeDirecional.Direcao)
		return true
	var do_alvo := alvo.get("combate_direcional") as ExecutorCorpoACorpo
	var perto := _plana(alvo.global_position - _boneco.global_position).length() <= LEITURA
	if do_alvo != null and perto and do_alvo.em_preparo() and do_alvo.golpe_atual != null:
		if do_alvo.id_acao != _golpe_lido:
			_golpe_lido = do_alvo.id_acao
			var r := randf()
			_reacao = 2 if r < CHANCE_DE_APARO else (1 if r < CHANCE_DE_APARO + CHANCE_DE_GUARDA else 0)
		match _reacao:
			1:
				if not ex.guarda_pedida():
					ex.erguer_guarda()
			2:
				var falta := do_alvo.golpe_atual.preparo - do_alvo.tempo_da_acao()
				if falta <= ANTECEDENCIA_DO_APARO and not ex.guarda_pedida():
					ex.erguer_guarda()
		return _reacao != 0
	if ex.guarda_pedida() and (do_alvo == null or not do_alvo.atacando()):
		ex.baixar_guarda()
	return ex.guarda_pedida()


func _atacar(ex: ExecutorCorpoACorpo, delta: float) -> void:
	_t_ataque += delta
	if _t_ataque < _proximo_ataque or _direcoes.is_empty():
		return
	if ex.pedir_ataque(_direcoes.pick_random() as GolpeDirecional.Direcao):
		_t_ataque = 0.0
		_proximo_ataque = randf_range(INTERVALO_MINIMO, INTERVALO_MAXIMO)


func _regenerar(delta: float) -> void:
	if _boneco.health < _boneco.max_health:
		_boneco.health = minf(_boneco.max_health, _boneco.health + _boneco.max_health * REGENERACAO * delta)


static func _plana(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
