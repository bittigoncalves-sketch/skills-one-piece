class_name Scoreboard
extends Node
# ============================================================================
#  PLACAR DA RODADA — kills, mortes e cronômetro. SERVIDOR-AUTORIDADE.
#
#  Regras (definidas pelo usuário):
#   - Rodada de 10 minutos. No fim: pódio de 8 s, todo mundo respawna no centro
#     com vida cheia, e então kills/mortes zeram e a rodada recomeça.
#   - Derrubar alguém conta KILL. Quem cai da plataforma (ou num buraco) leva
#     MORTE, e a kill vai para o ÚLTIMO que causou dano nele — desde que o
#     golpe tenha sido nos últimos CREDIT_WINDOW segundos. Passou disso, foi
#     queda burra: morte pra ele, kill pra ninguém.
#
#  POR QUE TUDO AQUI E NÃO NO PLAYER: cada cliente é autoridade do PRÓPRIO
#  corpo, então nenhum cliente pode ser dono da contagem — ele contaria só o que
#  vê. O servidor, ao contrário, tem a `position` de todos (replicada) e é quem
#  já roda a `DamageZone`. Então ele vê a queda E o autor do último golpe, que
#  são justamente os dois lados do crédito de kill.
#
#  O nó existe nos DOIS lados (é filho fixo do Main): no servidor ele decide, no
#  cliente ele só recebe o estado e serve de fonte para a HUD.
# ============================================================================

# 5 minutos de rodada (pedido do dono, 2026-08-12 — era 600). Rodada curta
# significa que a decisão sai por poucas kills, e é por isso que o desempate
# importa: ver `ranking()`, que ordena por kills e desempata por MENOS MORTES.
const ROUND_TIME := 300.0
const PODIUM_TIME := 10.0      # painel de fim de rodada (pedido do dono, 2026-09-01)

# ------------------------------------------------------------------ ENCHENTE
# Pedido do dono (2026-09-01): quando o tempo zera, a plataforma ALAGA em vez de
# a rodada simplesmente acabar. A água sobe, quem fica completamente coberto
# morre em 3 s, e ela continua subindo até não sobrar ninguém de pé. Só então o
# placar aparece, com 10 s para a próxima partida.
#
# ⚠️ QUEM MORRE NA ENCHENTE NÃO RESPAWNA. Essa é a regra que faz a fase existir:
#   com respawn, o afogado voltaria ao centro, cairia na água de novo e a
#   condição de fim ("todos mortos") nunca seria alcançada.
const FLOOD_RISE := 0.5        # m/s — escolhido pelo dono em jogo (testou 1,5 e 3,0)
const DROWN_TIME := 3.0        # segundos completamente submerso até morrer
const FLOOD_START_Y := 0.0     # topo da plataforma
# Teto de segurança. Não é o fim esperado da fase (o fim é todo mundo morto),
# é o que impede a água de subir para sempre se alguém ficar inalcançável —
# num bloco alto, num bug de colisão ou com o corpo preso fora da arena.
const FLOOD_MAX_Y := 80.0
const CREDIT_WINDOW := 10.0    # janela do crédito de kill por queda
const VOID_Y := -40.0          # abaixo disto = caiu do mapa
const RESPAWN := Vector3(0, 6, 0)
const SYNC_INTERVAL := 0.5     # o servidor reemite o estado 2x por segundo

# ---- estado (o servidor manda, o cliente espelha) ----
var time_left: float = ROUND_TIME
var podium_left: float = 0.0
var scores: Dictionary = {}          # peer:int -> {"k": int, "d": int}
var podium_snapshot: Array = []      # [[peer, kills, mortes]] ordenado, só no pódio
var flooding: bool = false           # a arena está alagando
var flood_y: float = FLOOD_START_Y   # nível da água em coordenada de mundo

# ---- só no servidor ----
var _last_hit: Dictionary = {}       # peer da vítima -> {"by": peer, "t": seg}
var _dead_until: Dictionary = {}     # peer -> instante até o qual ignoro a queda
var _submerso: Dictionary = {}       # peer -> segundos com a cabeça sob a água
var _eliminados: Dictionary = {}     # peer -> true (morreu na enchente, não volta)
var _sync_t: float = 0.0
var _clock: float = 0.0              # relógio local em segundos (não usa Time)

func _ready() -> void:
	add_to_group("scoreboard")        # como a DamageZone e a HUD me acham

func _is_server() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _physics_process(delta: float) -> void:
	_clock += delta

	# O cliente também corre o relógio para o cronômetro não andar aos saltos
	# entre um sync e outro; o sync do servidor corrige a deriva.
	if podium_left > 0.0:
		podium_left = maxf(podium_left - delta, 0.0)
	elif not flooding:
		time_left = maxf(time_left - delta, 0.0)

	# A água sobe nos DOIS lados pelo mesmo motivo do cronômetro: entre um sync e
	# outro passam 0,5 s, e uma parede de água que andasse aos saltos entregaria
	# a rede. O sync do servidor corrige a deriva.
	if flooding:
		flood_y = minf(flood_y + FLOOD_RISE * delta, FLOOD_MAX_Y)

	if not _is_server():
		return

	_watch_falls()

	if podium_left <= 0.0 and not podium_snapshot.is_empty():
		_start_new_round()
	elif flooding:
		_tick_enchente(delta)
	elif time_left <= 0.0 and podium_snapshot.is_empty():
		_start_flood()

	_sync_t += delta
	if _sync_t >= SYNC_INTERVAL:
		_sync_t = 0.0
		_broadcast()

# ------------------------------------------------------------------- quedas
func _watch_falls() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node3D):
			continue
		var peer := _peer_of(p)
		if peer == 0:
			continue
		_ensure_entry(peer)
		if float(_dead_until.get(peer, 0.0)) > _clock:
			continue          # já contabilizado; espero o respawn acontecer
		if (p as Node3D).global_position.y < VOID_Y:
			_register_death(p, peer, true)

# --------------------------------------------------- API chamada de fora
# Chamada pela DamageZone (e pelo corpo a corpo) NO SERVIDOR a cada acerto.
# Guarda quem bateu por último em quem, com carimbo de tempo.
func register_hit(victim: Node, attacker: Node) -> void:
	if not _is_server() or victim == attacker:
		return
	var vp := _peer_of(victim)
	var ap := _peer_of(attacker)
	if vp == 0 or ap == 0 or vp == ap:
		return               # dummy/inimigo não entra no placar
	_ensure_entry(vp)
	_ensure_entry(ap)
	_last_hit[vp] = {"by": ap, "t": _clock}

# Chamada pelo Player.die_and_respawn — vale para os DOIS motivos de morte
# (vida zerada e queda no vazio); `by_fall` só muda o texto do log.
#
# Existe redundância PROPOSITAL com `_watch_falls`: o Player roda a checagem de
# queda no cliente dono do corpo, e lá esta função não faz nada (o `_is_server`
# corta). Quem de fato declara a morte de um cliente é o `_watch_falls` do
# servidor, pela posição replicada. O `_dead_until` garante que os dois caminhos
# nunca contem a mesma morte duas vezes.
func report_death(victim: Node, by_fall: bool = false) -> void:
	if not _is_server():
		return
	var peer := _peer_of(victim)
	if peer == 0:
		return
	if float(_dead_until.get(peer, 0.0)) > _clock:
		return
	_register_death(victim, peer, by_fall)

# ------------------------------------------------------------------ contagem
func _register_death(victim: Node, peer: int, by_fall: bool) -> void:
	_dead_until[peer] = _clock + 2.0     # trava anti-recontagem enquanto respawna
	_ensure_entry(peer)
	scores[peer]["d"] = int(scores[peer]["d"]) + 1

	var killer := 0
	var hit = _last_hit.get(peer)
	if hit != null and _clock - float(hit["t"]) <= CREDIT_WINDOW:
		killer = int(hit["by"])
	if killer != 0 and killer != peer:
		_ensure_entry(killer)
		scores[killer]["k"] = int(scores[killer]["k"]) + 1
		# Kill acelera a regeneração de quem matou por 30 s (pedido do dono,
		# 2026-08-12). Quem premia é o SERVIDOR, que é quem sabe de quem foi a
		# kill — e ele avisa o dono do corpo, porque a regen só roda na
		# autoridade (Player.gd:279-280).
		# ⚠️ Tem que chegar no DONO do corpo, não na cópia do servidor: a
		# regeneração roda dentro do `_physics_process`, que sai cedo quando
		# `_is_authority` é falso (Player.gd:279-280). Premiar a cópia errada não
		# faria efeito nenhum. Mesmo padrão do `_order_respawn` logo abaixo.
		var corpo := _corpo_do_peer(killer)
		if corpo and corpo.has_method("premiar_kill"):
			if not multiplayer.has_multiplayer_peer() or killer == multiplayer.get_unique_id():
				corpo.premiar_kill()
			elif multiplayer.get_peers().has(killer):
				corpo.premiar_kill.rpc_id(killer)
	_last_hit.erase(peer)

	var motivo := "caiu do mapa" if by_fall else "vida zerada"
	if killer != 0:
		print("💀 [Placar] peer %d morreu (%s) — kill de %d" % [peer, motivo, killer])
	else:
		print("💀 [Placar] peer %d morreu (%s) — sem kill (janela de %ds venceu)"
			% [peer, motivo, int(CREDIT_WINDOW)])

	# ⚠️ NA ENCHENTE NÃO HÁ RESPAWN. Vale para QUALQUER morte, não só o
	# afogamento: quem levar o último golpe com a água na cintura também fica
	# fora, senão ele volta inteiro no centro e a fase não termina nunca.
	if not flooding:
		_order_respawn(victim, peer)
	else:
		_eliminados[peer] = true
	_broadcast()

# O corpo é do CLIENTE dono: o servidor pede o respawn, não teleporta na marra
# (teleportar aqui seria sobrescrito no frame seguinte pela replicação).
func _order_respawn(victim: Node, peer: int) -> void:
	if not victim.has_method("net_force_respawn"):
		return
	if not multiplayer.has_multiplayer_peer() or peer == multiplayer.get_unique_id():
		victim.net_force_respawn()
	elif multiplayer.get_peers().has(peer):
		victim.net_force_respawn.rpc_id(peer)
		# ⚠️ O `rpc_id` acima faz SÓ O DONO respawnar. A cópia autoritativa — a
		# mesma que a `DamageZone` machuca — ficava com a vida em 0 para sempre.
		# Ver item 19 da LISTA_DE_CORRECOES.
		if victim.has_method("restaurar_vida_no_servidor"):
			victim.restaurar_vida_no_servidor()
	# Peer que caiu fora entre a queda e a ordem: nada a fazer — o nó dele sai da
	# árvore no _despawn_player_for. Sem esta guarda o rpc_id derruba um erro
	# "unknown peer ID" a cada frame enquanto o corpo órfão afunda no vazio.

# ------------------------------------------------------------------ enchente
func _start_flood() -> void:
	flooding = true
	flood_y = FLOOD_START_Y
	_submerso.clear()
	_eliminados.clear()
	print("🌊 [Placar] o tempo acabou — a plataforma começou a alagar")
	_broadcast()


## Um quadro de enchente: mede quem está submerso, afoga quem passou dos 3 s e
## encerra quando não sobra ninguém de pé.
func _tick_enchente(delta: float) -> void:
	var vivos := 0
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node3D):
			continue
		var peer := _peer_of(p)
		if peer == 0 or _eliminados.has(peer):
			continue
		vivos += 1
		# "Completamente coberto": o TOPO da cabeça abaixo da linha d'água. Medir
		# pelos pés afogaria quem está com água pela cintura.
		var coberto: bool = p.topo_da_cabeca() < flood_y if p.has_method("topo_da_cabeca") \
			else (p as Node3D).global_position.y + 0.8 < flood_y
		if coberto:
			_submerso[peer] = float(_submerso.get(peer, 0.0)) + delta
			if float(_submerso[peer]) >= DROWN_TIME:
				_afogar(p, peer)
				vivos -= 1
		else:
			# Sair da água zera a conta: o contador é de fôlego, não de castigo.
			_submerso.erase(peer)

	if vivos <= 0 or flood_y >= FLOOD_MAX_Y:
		if flood_y >= FLOOD_MAX_Y and vivos > 0:
			print("🌊 [Placar] a água chegou ao teto com %d de pé — encerrando mesmo assim" % vivos)
		_start_podium()


func _afogar(vitima: Node, peer: int) -> void:
	_eliminados[peer] = true
	_submerso.erase(peer)
	print("🌊 [Placar] peer %d se afogou" % peer)
	# Conta como morte no placar (com crédito de kill, se alguém bateu nele há
	# pouco: empurrar alguém para a água no fim da rodada É uma kill).
	_register_death(vitima, peer, false)
	if not vitima.has_method("net_eliminar"):
		return
	if not multiplayer.has_multiplayer_peer() or peer == multiplayer.get_unique_id():
		vitima.net_eliminar()
	elif multiplayer.get_peers().has(peer):
		vitima.net_eliminar.rpc_id(peer)


# --------------------------------------------------------------- rodada
func _start_podium() -> void:
	podium_left = PODIUM_TIME
	podium_snapshot = ranking()
	# A água baixa junto com o fim da fase: o respawn logo abaixo devolve todo
	# mundo ao centro, e o centro não pode estar submerso.
	flooding = false
	flood_y = FLOOD_START_Y
	_submerso.clear()
	_eliminados.clear()
	print("🏁 [Placar] fim da rodada — pódio por %ds" % int(PODIUM_TIME))
	for p in get_tree().get_nodes_in_group("player"):
		var peer := _peer_of(p)
		if peer != 0:
			_dead_until[peer] = _clock + 2.0
			_order_respawn(p, peer)
	_broadcast()

func _start_new_round() -> void:
	podium_snapshot = []
	podium_left = 0.0
	time_left = ROUND_TIME
	for peer in scores:
		scores[peer] = {"k": 0, "d": 0}
	_last_hit.clear()
	print("🔔 [Placar] nova rodada de %d min" % int(ROUND_TIME / 60.0))
	_broadcast()

# ------------------------------------------------------------------ consulta
# [[peer, kills, mortes]] — mais kills primeiro; empate desempata por menos mortes.
func ranking() -> Array:
	var out: Array = []
	for peer in scores:
		out.append([int(peer), int(scores[peer]["k"]), int(scores[peer]["d"])])
	out.sort_custom(func(a, b):
		if a[1] != b[1]:
			return a[1] > b[1]
		return a[2] < b[2])
	return out

func in_podium() -> bool:
	return not podium_snapshot.is_empty()

func _ensure_entry(peer: int) -> void:
	if not scores.has(peer):
		scores[peer] = {"k": 0, "d": 0}

# O nome do nó do player É o peer id (ver Main._spawn_player_data). Qualquer
# outra coisa (dummy, inimigo) devolve 0 e fica fora do placar.
# Acha o corpo de um peer pelo nome do nó (o `Main` batiza o player com o id).
func _corpo_do_peer(peer: int) -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if _peer_of(p) == peer:
			return p
	return null

func _peer_of(n: Node) -> int:
	if n == null or not is_instance_valid(n) or not n.is_in_group("player"):
		return 0
	return str(n.name).to_int()

# ---------------------------------------------------------------- replicação
func _broadcast() -> void:
	if not multiplayer.has_multiplayer_peer():
		return                       # singleplayer: o estado local já é o oficial
	var packed: Dictionary = {}
	for peer in scores:
		packed[peer] = [int(scores[peer]["k"]), int(scores[peer]["d"])]
	_net_state.rpc({
		"t": time_left,
		"p": podium_left,
		"s": packed,
		"r": podium_snapshot,
		"fl": flooding,
		"f": flood_y,
	})

@rpc("authority", "call_remote", "reliable")
func _net_state(state: Dictionary) -> void:
	time_left = float(state.get("t", time_left))
	podium_left = float(state.get("p", 0.0))
	podium_snapshot = state.get("r", [])
	flooding = bool(state.get("fl", false))
	flood_y = float(state.get("f", FLOOD_START_Y))
	scores.clear()
	var packed: Dictionary = state.get("s", {})
	for peer in packed:
		var kd: Array = packed[peer]
		scores[int(peer)] = {"k": int(kd[0]), "d": int(kd[1])}
