extends SceneTree
## RÉGUA DO BOSS — onda 1 do docs/PLANO_BOSS_IA.md (boss-auditor-linha-base).
##
## Não é teste (não começa com `test_`): não afirma nada, só MEDE. O validar.sh
## não o roda. Todos os agentes do Boss medem com ESTE arquivo, sem mudá-lo,
## para a comparação entre ondas ser justa.
##
## Um processo = um bot. O jogador REAL anda com física ligada e sem input
## humano: o `MoveFrame` dele é trocado por um `BotFrame` que devolve a direção
## do roteiro, e o resto da locomoção (velocidade 4,2 m/s, hitstop, arremesso,
## colisão) é o do jogo. O M1 do `kite` sai por `MeleeController.pedir`, o
## caminho real do clique. O Boss é o real, na arena normal, no ponto de spawn.
##
## Uso (porta própria obrigatória quando há outro agente rodando):
##   SOP_PORTA=25000 "$GODOT" --headless --path . --script tools/dev_tests/medir_boss_ia.gd \
##       -- --bot=strafe --semente=1 --rodada=A
##
## Argumentos (depois de `--`):
##   --bot=parado|strafe|recuo|kite|circulo|zigzag   (obrigatório)
##   --semente=N    semente do RNG global (padrão 1). O caminho do Boss não sorteia
##                  nada; a semente fixa o que o jogo sortear de passagem.
##   --rodada=X     subpasta da saída (padrão A)
##   --min=40       duração mínima em s de simulação (a rodada só acaba antes se o
##                  jogador morrer)
##   --max=120      teto em s: sem morte, a medição prolonga até aqui para achar o
##                  tempo de matar 2048
##   --saida=res://art_src/validation/boss_ia
##   --hitstop=1    1 = jogo como é. 0 = desliga `GameFlow.hit_stop`/slow-mo
##                  (marca `GameFlow.is_dedicated` DEPOIS do spawn do jogador).
##                  O hit-stop põe `Engine.time_scale` em 0,06 por 0,05 s de
##                  RELÓGIO DE PAREDE a cada acerto; isso desloca a simulação em
##                  ±1 quadro por golpe e faz rodadas iguais divergirem. Com 0, a
##                  mesma árvore dá CSV idêntico byte a byte (medido 13/09/2026).
##                  Use 0 para comparar ondas; 1 para o número absoluto.
##
## Saída: <saida>/rodada_<X>/decisao_<bot>.csv (log de decisão) e
##        <saida>/rodada_<X>/resumo_<bot>.json (grandezas). A última linha do
##        stdout é `RESUMO_JSON {...}`.
##
## Tempo = quadros de física / 60 (passo fixo), nunca relógio de parede.
## Dano = queda da `health` na cópia autoritativa (em um jogador, o host).
## A vida é a do jogo (2048) com a regeneração natural dele; nada é escrito
## na vida. "Tempo para matar" = instante em que o dano SOMADO chega a 2048.

const BOTS := ["parado", "strafe", "recuo", "kite", "circulo", "zigzag"]
const TICKS := 60.0
const HP_ALVO := 2048.0
## Quadros de física entre o início da partida e o início do bot (Boss assenta).
const ASSENTAR := 120
## Jogador começa a esta distância do ponto de origem do Boss, no eixo +Z.
const DISTANCIA_INICIAL := 6.0
const STRAFE_TROCA := 1.2
const RECUO_GATILHO := 4.0
const RECUO_LIMITE := 20.0
const KITE_ALCANCE := 2.0
const KITE_RECUO := 5.0
const CIRCULO_RAIO := 3.0
## ZIGZAG (6º bot, aprovado pelo dono em 13/09/2026): mede a mira do corte contra
## quem foge SEM ir em linha reta. Mesmo ciclo do `recuo` (anda até 4 m; foge até
## o Boss perder o alvo ou 20 m; volta), mas na fuga a direção é a de afastamento
## do Boss (recalculada a cada quadro) girada ±35°, trocando de lado a cada 1,5 s
## (período 3,0 s).
##   radial  = 4,2·cos35° = 3,44 m/s: acima dos 3,2 m/s do Boss (a distância cresce
##             até os 4 m mínimos do corte) e dos 2 m/s do gatilho de fuga;
##   lateral = 4,2·sen35° = 2,41 m/s → 3,6 m de pico a pico por meia volta
##             (amplitude ±1,8 m em torno da linha média).
## Por que esses números (medido na 1ª versão, 45°/0,8 s): com radial 2,97 m/s o
## Boss encurtava a distância e quase não cortava (2 cortes em 30 s), e a meia
## volta de 0,8 s ≈ tempo entre a mira travar e a frente passar (~0,8 s) anulava o
## desvio (lateral na passagem 0,02 e 0,19 m). O resumo traz a fração da fuga com
## `flee_rate` >= 2 m/s para conferir que o gatilho vale.
const ZIGZAG_ANGULO := deg_to_rad(35.0)
const ZIGZAG_TROCA := 1.5
const AMOSTRA_LOG := 6              # uma linha a cada 0,1 s além dos eventos
const VEL_PARADO := 0.05
## Regra comum a todos os bots: sem alvo no cérebro do Boss por mais que isto, o
## bot volta andando até ele até ser reconhecido (ver `_roteiro`).
const REENGAJAR_APOS := 30

## O que o jogador PEDIU neste quadro, vindo do roteiro em vez do teclado.
class BotFrame extends MoveFrame:
	var bot_dir := Vector3.ZERO

	func ler(yaw: float, menu_fechado: bool = true) -> void:
		var base := RosaDosVentos.base_do_corpo(yaw)
		frente = -base.z
		direita = base.x
		dir = bot_dir
		if dir.length() > 1.0:
			dir = dir.normalized()
		f = dir.dot(frente)
		r = dir.dot(direita)
		sprint = false
		espaco_segurado = false
		espaco_agora = false
		dash_segurado = false

var boss: CharacterBody3D
var player: CharacterBody3D
var frame := 0
var bot := ""
var cfg := {}

# ---- estado do roteiro
var fase := ""
var fase_desde := 0
var strafe_sinal := 1.0
var retreat_dir := Vector3.ZERO
var retreat_origem := Vector3.ZERO
var cliques := 0
var desvios_buraco := 0
var sem_alvo_desde := -1
var fase_antes := ""
var quadros_reaproxima := 0

# ---- medição
var dano_total := 0.0
var dano_40 := 0.0
var ttk := -1.0
var morreu := false
var hp_antes := 0.0
var casts: Array = []              # {id, seq, t, dist, flee, acertou}
var ultimo_seq := 0
var ultimo_jab := "jab"
var golpes := {}                   # id -> {lancados, acertaram, dano}
var cortes: Array = []             # detalhes por corte
var corte_atual := {}
var ondas_vistas := {}
var arremessos := 0
var arremessado_antes := false
var parado := {}                   # categoria -> {s, s_em_alcance}
var corte_bloqueado_recarga := 0.0
var chase_perto := 0.0
var tempo_sim := 0.0
var quadros_fuga := 0               # fase "recua" com alvo e sem estar arremessado
var quadros_fuga_flee2 := 0         # ... e flee_rate >= flee_speed do corte                # soma do delta de física (encolhe no hit-stop)
var parado_cat_antes := ""
var parado_seq := 0
var parado_ge2 := 0.0               # parado fora da recarga, só sequências >= 2 quadros              # perseguindo (andando) com o alvo a <= 2 m
var soma_dist_alvo := 0.0
var quadros_alvo := 0
var soma_dist := 0.0
var boss_hp_antes := 0.0
var dano_no_boss := 0.0
var reacoes_boss := {}
var reacao_antes := ""
var nao_atribuido: Array = []
var saltos_de_seq := 0

# ---- log
var log_linhas: PackedStringArray = []
var chave_antes := ""

func _init() -> void:
	cfg = _args()
	bot = str(cfg.bot)
	if not bot in BOTS:
		push_error("--bot= precisa ser um de %s" % [BOTS])
		quit(2)
		return
	seed(int(cfg.semente))
	OS.set_environment("SOP_BOSS_ENABLED", "1")
	await process_frame
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	for i in ASSENTAR:
		await physics_frame
	boss = get_first_node_in_group("boss")
	player = get_first_node_in_group("player")
	if boss == null or player == null:
		push_error("Boss ou jogador ausente (SOP_BOSS_ENABLED? porta ocupada?)")
		quit(3)
		return
	if str(cfg.hitstop) == "0":
		flow.is_dedicated = true
	player._quadro = BotFrame.new()
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(boss.home_position.x, 0.8, boss.home_position.z + DISTANCIA_INICIAL)
	hp_antes = player.health
	boss_hp_antes = boss.health
	ultimo_seq = boss.action_sequence
	_entrar("aproxima" if bot in ["recuo", "kite", "zigzag"] else bot)
	log_linhas.append("t,quadro,bot_fase,estado,acao,combo,reacao,alvo,dist,flee_rate,vel_boss,hp_jogador,cd_combo,cd_corte,cd_punho,parte,evento")
	var inicio_parede := Time.get_ticks_msec()
	var min_q := int(float(cfg.min) * TICKS)
	var max_q := int(float(cfg.max) * TICKS)
	while true:
		await physics_frame
		frame += 1
		tempo_sim += boss.get_physics_process_delta_time()
		var eventos := _observar()
		_roteiro()
		_registrar(eventos)
		if morreu or ttk >= 0.0:
			break
		if frame >= max_q:
			break
	player._quadro.bot_dir = Vector3.ZERO
	var parede_s := (Time.get_ticks_msec() - inicio_parede) / 1000.0
	_gravar(parede_s, min_q)
	quit(0)

# ------------------------------------------------------------------ roteiros
func _entrar(nova: String) -> void:
	fase = nova
	fase_desde = frame

func _plano(v: Vector3) -> Vector3:
	v.y = 0
	return v

func _roteiro() -> void:
	var para_boss := _plano(boss.global_position - player.global_position)
	var d := para_boss.length()
	var u := para_boss / d if d > 0.001 else Vector3.FORWARD
	# Mira sempre no Boss: o corpo olha para a mira e o M1 sai para ela.
	player._yaw = atan2(-u.x, -u.z)
	var direita := Vector3(-u.z, 0, u.x)
	var quero := Vector3.ZERO
	# REENGAJAR (regra comum, declarada no relatório): o arremesso leva o jogador
	# para longe e, parado, ele sai do limite do encontro (22 m da origem) — o Boss
	# desiste e volta para casa, e a régua passaria o resto do tempo medindo nada.
	# Sem alvo por 0,5 s, o bot anda até o Boss até ser reconhecido e retoma o
	# roteiro. O `recuo` já tem essa volta dentro do próprio ciclo.
	if is_instance_valid(boss.controller.brain.target):
		sem_alvo_desde = -1
	elif sem_alvo_desde < 0:
		sem_alvo_desde = frame
	if not bot in ["recuo", "zigzag"]:
		if sem_alvo_desde >= 0 and frame - sem_alvo_desde > REENGAJAR_APOS:
			if fase != "reaproxima":
				fase_antes = "aproxima" if bot == "kite" else fase
				_entrar("reaproxima")
			quadros_reaproxima += 1
			player._quadro.bot_dir = _sem_buraco(u)
			return
		elif fase == "reaproxima":
			_entrar(fase_antes)
	match bot:
		"parado":
			quero = Vector3.ZERO
		"strafe":
			if frame > 1 and (frame - 1) % int(STRAFE_TROCA * TICKS) == 0:
				strafe_sinal = -strafe_sinal
			quero = direita * strafe_sinal
		"circulo":
			quero = (direita + u * clampf((d - CIRCULO_RAIO) * 1.0, -1.0, 1.0)).normalized()
		"recuo":
			if fase == "aproxima":
				quero = u
				if d <= RECUO_GATILHO:
					retreat_dir = -u
					_entrar("recua")
			if fase == "recua":
				quero = retreat_dir
				var perdeu: bool = not is_instance_valid(boss.controller.brain.target)
				if (perdeu and frame - fase_desde > 30) or d >= RECUO_LIMITE:
					_entrar("aproxima")
		"zigzag":
			if fase == "aproxima":
				quero = u
				if d <= RECUO_GATILHO:
					_entrar("recua")
			if fase == "recua":
				var lado := 1.0 if int((frame - fase_desde) / (ZIGZAG_TROCA * TICKS)) % 2 == 0 else -1.0
				quero = (-u).rotated(Vector3.UP, ZIGZAG_ANGULO * lado)
				var perdeu_z: bool = not is_instance_valid(boss.controller.brain.target)
				if (perdeu_z and frame - fase_desde > 30) or d >= RECUO_LIMITE:
					_entrar("aproxima")
		"kite":
			if fase == "aproxima":
				quero = u
				if d <= KITE_ALCANCE:
					cliques = 0
					_entrar("golpe")
			if fase == "golpe":
				quero = Vector3.ZERO
				var livre: bool = player._melee.trava() <= 0.0 and player.is_on_floor() and not player.esta_arremessado()
				if cliques < 2 and livre:
					player._melee.pedir(player._yaw)
					cliques += 1
				elif (cliques >= 2 and livre) or frame - fase_desde > int(3.0 * TICKS):
					retreat_dir = -u
					retreat_origem = player.global_position
					_entrar("recua")
			elif fase == "recua":
				quero = retreat_dir
				if _plano(player.global_position - retreat_origem).length() >= KITE_RECUO:
					_entrar("aproxima")
	player._quadro.bot_dir = _sem_buraco(quero)

## Proteção de medição: o roteiro não anda para dentro de buraco (morte por queda
## não é o que se mede). Conta quantos quadros precisou desviar.
func _sem_buraco(quero: Vector3) -> Vector3:
	if quero.length_squared() < 0.0001:
		return Vector3.ZERO
	for angulo in [0.0, 0.6, -0.6, 1.2, -1.2, PI / 2, -PI / 2]:
		var tentativa := quero.rotated(Vector3.UP, angulo)
		var proximo: Vector3 = player.global_position + tentativa * 1.0
		if not MapBuilder.is_hole_area(proximo.x, proximo.z, 1.0, 1.0):
			if angulo != 0.0:
				desvios_buraco += 1
			return tentativa
	desvios_buraco += 1
	return Vector3.ZERO

# ------------------------------------------------------------------ medição
## Estado visto no início do passo de física = resultado do passo anterior.
func _observar() -> PackedStringArray:
	var eventos: PackedStringArray = []
	var t := frame / TICKS
	var alvo_ok: bool = is_instance_valid(boss.controller.brain.target)
	var dist := _plano(boss.global_position - player.global_position).length()

	# golpes lançados: cada soco/corte/punho é um cast com action_sequence próprio
	if boss.action_sequence != ultimo_seq:
		if boss.action_sequence - ultimo_seq > 1:
			saltos_de_seq += 1
		ultimo_seq = boss.action_sequence
		var id := str(boss.action_id)
		if id != "":
			var cast := {"id": id, "seq": boss.action_sequence, "t": t, "dist": dist, "flee": boss.controller.brain.flee_rate, "acertou": false, "contato": false}
			casts.append(cast)
			_golpe(id).lancados += 1
			if id.begins_with("jab"):
				ultimo_jab = id
			eventos.append("inicio:%s" % id)
			if id == str(boss.definition.slash.id):
				corte_atual = {"t": t, "dist_inicio": snappedf(dist, 0.01), "flee_inicio": snappedf(boss.controller.brain.flee_rate, 0.01),
					"vel_jogador": snappedf(_plano(player.velocity).length(), 0.01), "frente": false, "acertou": false,
					"lateral_na_trava": null, "lateral_na_passagem": null, "resultado": "cancelado_antes_da_frente"}
				cortes.append(corte_atual)

	# golpe em curso chegou ao fim da preparação? (cancelado antes não conta como tentativa)
	if not casts.is_empty() and casts.back().seq == boss.action_sequence and str(boss.action_id) == casts.back().id \
			and not casts.back().contato and boss.action_elapsed >= boss.definition.move_for(casts.back().id).windup:
		casts.back().contato = true
		_golpe(casts.back().id).chegaram_ao_contato += 1

	# corte: posição do alvo quando a mira trava e quando a frente passa por ele
	if not corte_atual.is_empty():
		var slash: BossSlashAbility = boss.definition.slash
		if boss.action_id == str(slash.id) and corte_atual.lateral_na_trava == null and boss.action_elapsed >= slash.aim_time:
			var fwd := _plano(-boss.global_basis.z).normalized()
			var rel := _plano(player.global_position - boss.global_position)
			corte_atual.lateral_na_trava = snappedf((rel - fwd * rel.dot(fwd)).length(), 0.01)
			corte_atual.vel_lateral_na_trava = snappedf((_plano(player.velocity) - fwd * _plano(player.velocity).dot(fwd)).length(), 0.01)
			eventos.append("corte_trava")
		for onda in get_nodes_in_group(BossCombat.SLASH_GROUP):
			var chave := onda.get_instance_id()
			if not ondas_vistas.has(chave):
				ondas_vistas[chave] = {"origem": onda.global_position, "dir": _plano(onda._direction).normalized(), "passou": false, "registro": corte_atual}
				corte_atual.frente = true
				corte_atual.resultado = "errou"
				eventos.append("corte_frente")
		for chave in ondas_vistas.keys():
			var info: Dictionary = ondas_vistas[chave]
			if info.passou:
				continue
			var onda = instance_from_id(chave)
			var rel_j := _plano(player.global_position - info.origem)
			var ao_longo: float = rel_j.dot(info.dir)
			if not is_instance_valid(onda):
				info.passou = true
				if info.registro.lateral_na_passagem == null:
					info.registro.alem_do_alcance_m = snappedf(ao_longo, 0.01)
				continue
			var frente_onda: float = _plano(onda.global_position - info.origem).dot(info.dir)
			if frente_onda >= ao_longo:
				info.passou = true
				info.registro.lateral_na_passagem = snappedf((rel_j - info.dir * ao_longo).length(), 0.01)
				info.registro.distancia_na_passagem = snappedf(ao_longo, 0.01)
				eventos.append("corte_passou lat=%.2f" % info.registro.lateral_na_passagem)

	# dano no jogador (cópia autoritativa)
	var hp: float = player.health
	var delta_hp := hp - hp_antes
	if delta_hp > 40.0:
		morreu = true                 # respawn restaurou a vida
		eventos.append("respawn")
	elif delta_hp < -0.5:
		var valor := -delta_hp
		dano_total += valor
		if frame <= int(40 * TICKS):
			dano_40 += valor
		var fonte := _atribuir(valor)
		eventos.append("dano:%.0f:%s" % [valor, fonte])
		if ttk < 0.0 and dano_total >= HP_ALVO:
			ttk = t
	if hp <= 0.0 or player.get("_eliminado"):
		morreu = true
		if ttk < 0.0:
			ttk = t
	hp_antes = hp

	# arremesso do jogador
	var arremessado: bool = player.esta_arremessado()
	if arremessado and not arremessado_antes:
		arremessos += 1
		eventos.append("arremessado_por:%s" % str(boss.action_id))
	arremessado_antes = arremessado

	# dano e reação do Boss (kite)
	if boss.health < boss_hp_antes - 0.01:
		dano_no_boss += boss_hp_antes - boss.health
		eventos.append("boss_dano:%.0f" % (boss_hp_antes - boss.health))
	boss_hp_antes = boss.health
	if boss.reaction != reacao_antes and boss.reaction != "":
		reacoes_boss[boss.reaction] = int(reacoes_boss.get(boss.reaction, 0)) + 1
		eventos.append("boss_reacao:%s" % boss.reaction)
	reacao_antes = boss.reaction

	# parado sem agir com alvo
	var agindo: bool = boss.combat.busy() or boss.reaction != "" or boss.controller.controlled(boss) or boss.dead
	var vel := Vector2(boss.velocity.x, boss.velocity.z).length()
	var cat_quadro := ""
	if alvo_ok:
		soma_dist_alvo += dist
		quadros_alvo += 1
		if not agindo and vel < VEL_PARADO:
			var cat := "outro:" + str(boss.state)
			match str(boss.state):
				"guard":
					if boss.combat.cooldown_remaining > 0.0:
						cat = "guard_recarga_combo"
					elif boss.part_state != "attached":
						cat = "guard_punho_fora"
					else:
						cat = "guard_sem_ataque"
				"chase":
					cat = "chase_parado"
				"idle":
					cat = "idle_com_alvo"
			cat_quadro = cat
			if not parado.has(cat):
				parado[cat] = {"s": 0.0, "s_alvo_ate_2m": 0.0}
			parado[cat].s += 1.0 / TICKS
			if dist <= boss.definition.combo_break_distance:
				parado[cat].s_alvo_ate_2m += 1.0 / TICKS
	# Sequência de 1 quadro no fim de um golpe é ordem de observação (o golpe
	# encerra dentro de BossCombat.tick, depois do controlador): só >= 2 conta.
	if cat_quadro != "" and cat_quadro != "guard_recarga_combo" and cat_quadro == parado_cat_antes:
		parado_seq += 1
		parado_ge2 += (2.0 if parado_seq == 2 else 1.0) / TICKS
	else:
		parado_seq = 1
	parado_cat_antes = cat_quadro
	if alvo_ok:
		if not agindo and str(boss.state) == "chase" and vel >= VEL_PARADO and dist <= boss.definition.combo_break_distance:
			chase_perto += 1.0 / TICKS
		var slash: BossSlashAbility = boss.definition.slash
		if not agindo and boss.combat.slash_cooldown_remaining > 0.0 and boss.controller.brain.flee_rate >= slash.flee_speed \
				and dist >= slash.min_distance and dist <= slash.slash_range:
			corte_bloqueado_recarga += 1.0 / TICKS
	if fase == "recua" and alvo_ok and not arremessado:
		quadros_fuga += 1
		if boss.controller.brain.flee_rate >= boss.definition.slash.flee_speed:
			quadros_fuga_flee2 += 1
	soma_dist += dist
	return eventos

func _golpe(id: String) -> Dictionary:
	if not golpes.has(id):
		golpes[id] = {"lancados": 0, "chegaram_ao_contato": 0, "acertaram": 0, "dano": 0.0}
	return golpes[id]

## Cada golpe tem dano próprio (jab 72, corte 90, punho 112): o valor identifica a
## fonte, e o golpe de jab é o que está em curso (ou o último).
func _atribuir(valor: float) -> String:
	var id := ""
	if absf(valor - boss.definition.slash.damage) < 1.5:
		id = str(boss.definition.slash.id)
	elif absf(valor - boss.definition.moves().back().damage) < 1.5:
		id = str(boss.definition.moves().back().id)
	elif absf(valor - boss.definition.ability.damage) < 1.5:
		id = str(boss.action_id) if str(boss.action_id).begins_with("jab") else ultimo_jab
	if id == "":
		nao_atribuido.append(snappedf(valor, 0.1))
		return "?"
	_golpe(id).dano += valor
	for i in range(casts.size() - 1, -1, -1):
		if casts[i].id == id:
			if not casts[i].acertou:
				casts[i].acertou = true
				golpes[id].acertaram += 1
			break
	if id == str(boss.definition.slash.id):
		for i in range(cortes.size() - 1, -1, -1):
			if cortes[i].frente:
				cortes[i].acertou = true
				cortes[i].resultado = "acertou"
				break
	return id

func _registrar(eventos: PackedStringArray) -> void:
	var alvo_ok: bool = is_instance_valid(boss.controller.brain.target)
	var chave := "%s|%s|%s|%s|%s" % [fase, boss.state, boss.action_id, boss.reaction, alvo_ok]
	if eventos.is_empty() and chave == chave_antes and frame % AMOSTRA_LOG != 0:
		return
	chave_antes = chave
	var dist := _plano(boss.global_position - player.global_position).length()
	log_linhas.append("%.3f,%d,%s,%s,%s,%d,%s,%d,%.3f,%.3f,%.2f,%.1f,%.2f,%.2f,%.2f,%s,%s" % [
		frame / TICKS, frame, fase, boss.state, boss.action_id, boss.combo_index, boss.reaction, 1 if alvo_ok else 0,
		dist, boss.controller.brain.flee_rate, Vector2(boss.velocity.x, boss.velocity.z).length(), player.health,
		boss.combat.cooldown_remaining, boss.combat.slash_cooldown_remaining, boss.combat.detached.cooldown,
		boss.part_state, " ".join(eventos)])

func _gravar(parede_s: float, min_q: int) -> void:
	var dur := frame / TICKS
	var taxa := {}
	for id in golpes:
		var g: Dictionary = golpes[id]
		taxa[id] = {"lancados": g.lancados, "chegaram_ao_contato": g.chegaram_ao_contato, "acertaram": g.acertaram, "dano": snappedf(g.dano, 0.1),
			"taxa_sobre_lancados": snappedf(float(g.acertaram) / g.lancados, 0.001) if g.lancados > 0 else null,
			"taxa_sobre_contato": snappedf(float(g.acertaram) / g.chegaram_ao_contato, 0.001) if g.chegaram_ao_contato > 0 else null}
	var slash_id := str(boss.definition.slash.id)
	var punho_id := str(boss.definition.moves().back().id)
	var parado_total := 0.0
	var parado_alcance := 0.0
	var parado_sem_recarga := 0.0
	var parado_sem_recarga_alcance := 0.0
	for cat in parado:
		parado[cat].s = snappedf(parado[cat].s, 0.001)
		parado[cat].s_alvo_ate_2m = snappedf(parado[cat].s_alvo_ate_2m, 0.001)
		parado_total += parado[cat].s
		parado_alcance += parado[cat].s_alvo_ate_2m
		if cat != "guard_recarga_combo":
			parado_sem_recarga += parado[cat].s
			parado_sem_recarga_alcance += parado[cat].s_alvo_ate_2m
	var cortes_frente := cortes.filter(func(c): return c.frente)
	var cortes_acertos := cortes.filter(func(c): return c.acertou)
	var resumo := {
		"bot": bot, "semente": int(cfg.semente), "rodada": str(cfg.rodada),
		"godot": Engine.get_version_info().string, "porta": OS.get_environment("SOP_PORTA"),
		"hitstop": str(cfg.hitstop) != "0", "tempo_simulado_s": snappedf(tempo_sim, 0.001),
		"distancia_inicial_m": DISTANCIA_INICIAL, "min_s": float(cfg.min), "max_s": float(cfg.max),
		"duracao_s": snappedf(dur, 0.001), "quadros": frame, "parede_s": snappedf(parede_s, 0.01),
		"tempo_real_x": snappedf(dur / parede_s, 0.01) if parede_s > 0 else null,
		"morreu": morreu, "atingiu_minimo": frame >= min_q or morreu,
		"ttk_2048_s": snappedf(ttk, 0.001) if ttk >= 0 else null,
		"ttk_extrapolado_s": snappedf(HP_ALVO / (dano_total / dur), 0.1) if ttk < 0 and dano_total > 0 else null,
		"dano_total": snappedf(dano_total, 0.1), "dano_40s": snappedf(dano_40, 0.1),
		"dps": snappedf(dano_total / dur, 0.01), "dps_40s": snappedf(dano_40 / minf(dur, 40.0), 0.01),
		"golpes": taxa,
		"cortes": {"lancados": taxa.get(slash_id, {}).get("lancados", 0), "com_frente": cortes_frente.size(),
			"acertaram": cortes_acertos.size(),
			"taxa_sobre_frentes": snappedf(float(cortes_acertos.size()) / cortes_frente.size(), 0.001) if cortes_frente.size() > 0 else null,
			"detalhes": cortes},
		"punho_destacado": {"usos": taxa.get(punho_id, {}).get("lancados", 0), "acertos": taxa.get(punho_id, {}).get("acertaram", 0)},
		"arremessos_no_jogador": arremessos,
		"parado_sem_agir": parado,
		"parado_total_s": snappedf(parado_total, 0.001), "parado_total_alvo_ate_2m_s": snappedf(parado_alcance, 0.001),
		"parado_fora_da_recarga_s": snappedf(parado_sem_recarga, 0.001),
		"parado_fora_da_recarga_alvo_ate_2m_s": snappedf(parado_sem_recarga_alcance, 0.001),
		"parado_fora_da_recarga_2q_ou_mais_s": snappedf(parado_ge2, 0.001),
		"corte_bloqueado_por_recarga_s": snappedf(corte_bloqueado_recarga, 0.001),
		"chase_com_alvo_ate_2m_s": snappedf(chase_perto, 0.001),
		"tempo_com_alvo_s": snappedf(quadros_alvo / TICKS, 0.001),
		"dist_media_com_alvo_m": snappedf(soma_dist_alvo / quadros_alvo, 0.001) if quadros_alvo > 0 else null,
		"dist_media_m": snappedf(soma_dist / frame, 0.001) if frame > 0 else null,
		"dano_no_boss": dano_no_boss, "reacoes_boss": reacoes_boss,
		"dano_nao_atribuido": nao_atribuido, "saltos_de_sequencia": saltos_de_seq,
		"desvios_de_buraco_quadros": desvios_buraco,
		"reaproximando_s": snappedf(quadros_reaproxima / TICKS, 0.001),
		"fuga_s": snappedf(quadros_fuga / TICKS, 0.001),
		"fuga_com_flee_rate_no_gatilho_frac": snappedf(float(quadros_fuga_flee2) / quadros_fuga, 0.001) if quadros_fuga > 0 else null,
	}
	var pasta := ProjectSettings.globalize_path(str(cfg.saida)).path_join("rodada_" + str(cfg.rodada))
	DirAccess.make_dir_recursive_absolute(pasta)
	var csv := FileAccess.open(pasta.path_join("decisao_%s.csv" % bot), FileAccess.WRITE)
	csv.store_string("\n".join(log_linhas) + "\n")
	csv.close()
	var texto := JSON.stringify(resumo, "  ", false)
	var arq := FileAccess.open(pasta.path_join("resumo_%s.json" % bot), FileAccess.WRITE)
	arq.store_string(texto + "\n")
	arq.close()
	print("RESUMO_JSON ", JSON.stringify(resumo, "", false))

func _args() -> Dictionary:
	var out := {"bot": "", "semente": "1", "rodada": "A", "min": "40", "max": "120", "saida": "res://art_src/validation/boss_ia", "hitstop": "1"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var partes := a.substr(2).split("=", true, 1)
			out[partes[0]] = partes[1]
	return out
