extends SceneTree
# ============================================================================
#  SONDA MULTIPLAYER GERAL — LADO HOST (2 processos). É o JUIZ do teste.
#
#  Por que existe: movimentação replicada, as DUAS mortes, regeneração de
#  energia, recarga de skill e recarga depois da morte só existem de verdade
#  quando há DOIS processos. Em um processo só o cliente É o servidor: a cópia
#  autoritativa e a cópia do dono são o MESMO objeto, e é justamente a diferença
#  entre elas que este teste mede.
#
#  Este script quase não age: ele OBSERVA a cópia autoritativa do corpo do
#  cliente dentro do processo do servidor. As únicas coisas que ele FAZ são as
#  que, no jogo de verdade, só o servidor pode fazer:
#     • aplicar dano (a `DamageZone` roda no servidor — item 2 por dano);
#     • zerar a energia da cópia autoritativa para provar que ela NÃO regenera
#       ali (item 3: a regen mora no `_physics_process`, que sai cedo quando
#       `_is_authority` é falso — Player.gd:682).
#
#  ---------------------------------------------------------------- O RELÓGIO
#  Não há relógio combinado entre os dois processos. O CLIENTE anuncia em que
#  fase está escrevendo o `current_fruit_id`, que é uma das 5 propriedades
#  replicadas (Main.gd:119). Cada troca fecha um segmento e abre outro — mesma
#  técnica do `net_buki_host_probe.gd`, e pela mesma razão: o protocolo é o
#  próprio sinal.
#
#  ⚠️ Suba ESTE primeiro. Porta 24565 é fixa e única.
#
#    godot --headless --path . --script tools/dev_tests/net_mp_host_probe.gd
# ============================================================================

const TIMEOUT := 900.0          # teto absoluto de coleta
const ESPERA_CLIENTE := 300.0   # quanto espera o cliente entrar

# ---- CONTRATO ENTRE AS DUAS SONDAS (tem que bater com o net_mp_client_probe) --
const FASES := {
	"gomu_gomu": "1 - MOVIMENTO",
	"bara_bara": "2A - MORTE POR DANO",
	"hie_hie":   "2B - MORTE POR QUEDA",
	"goro_goro": "3 - REGEN DE ENERGIA",
	"mera_mera": "4 - RECARGA DE SKILL",
	"gura_gura": "5 - RECARGA DEPOIS DA MORTE",
	"yami_yami": "6 - REGEN DE VIDA",
	"buki_buki": "FIM",
}
const FASE_INICIAL := "gomu_gomu"
# `suna_suna` é a fruta que o Main.gd entrega a TODO jogador ao nascer
# (Main.gd:114) — por isso ela NÃO é fase: se fosse, a máquina abriria sozinha
# antes de o cliente dizer qualquer coisa.

# Trajeto do item 1. As duas sondas conhecem os extremos, então dá para medir o
# ERRO EM METROS e não só "andou alguma coisa".
const MOV_INICIO := Vector3(-6.0, 30.0, 0.0)
const MOV_FIM := Vector3(6.0, 30.0, 0.0)

const DANO_GOLPE := 1024.0      # 2 golpes = 2048 = vida cheia
const DANO_NAO_FATAL := 512.0   # item 6

var _eu: Node = null            # corpo do HOST (peer 1)
var _cli: Node = null           # corpo do CLIENTE, cópia AUTORITATIVA
var _sb: Node = null            # placar (servidor-autoridade)
var _peer_cli := 0
var _t0 := 0.0
var _falhas := 0

var _fase := ""                 # fase corrente (só muda com beacon conhecido)
var _fase_t0 := 0.0
var _comecou := false           # já vi o beacon inicial?
var _linha: Array = []          # [t, beacon, fase] de cada transição
var _fruta_vazia: Array = []    # instantes em que o beacon caiu para "" (respawn)

# ---- item 1 ----
var _mov := {"dist": 0.0, "ult": Vector3.ZERO, "n": 0, "ini": Vector3.ZERO,
			"fim": Vector3.ZERO, "tem": false, "fechado": false, "t_ini": 0.0, "t_fim": 0.0}
# ---- item 2A ----
var _dano := {"feito": false, "hp0": -1.0, "hp_pos_golpe1": -1.0, "hp_pos_fatal": -1.0,
			"hp_fim": -1.0, "mortes0": -1, "mortes1": -1, "kills0": -1, "kills1": -1,
			"t_golpe": 0.0, "t_respawn": -1.0, "dist_respawn": 1.0e9, "pos_fim": Vector3.ZERO}
# ---- item 2B ----
var _queda := {"mortes0": -1, "mortes1": -1, "y_min": 1.0e9, "t_abaixo": -1.0,
			"t_acima": -1.0, "dist_respawn": 1.0e9, "viu_abaixo": false, "viu_acima": false}
# ---- item 3 ----
var _en := {"zerou": false, "e0": -1.0, "e_fim": -1.0, "e_max": -1.0, "t_zero": 0.0, "n": 0}
# ---- item 6 ----
var _vd := {"bateu": false, "hp_antes": -1.0, "hp_depois_golpe": -1.0, "hp_fim": -1.0,
			"hp_max_visto": -1.0, "t_golpe": 0.0, "n": 0}


func _init() -> void:
	await process_frame
	_t0 = _agora()
	# Autoload em script `-s` não vira identificador de compilação -> pega por nó.
	get_root().get_node("GameFlow").create_room()
	print("[HOST] sala criada (porta 24565) — esperando o cliente...")

	for i in 900:
		await process_frame
		_eu = _corpo("1")
		if _eu != null:
			break
	if _eu == null:
		print("[HOST] ❌ meu corpo (peer 1) nunca apareceu")
		quit(3)
		return

	# `extends SceneTree` NÃO tem get_tree(): o script É a árvore.
	_sb = get_first_node_in_group("scoreboard")
	if _sb == null:
		print("[HOST] ❌ placar não está na árvore — sem ele nada de morte é medível")
		quit(3)
		return
	print("[HOST] meu corpo='%s' hp=%.0f/%.0f | placar='%s'"
		% [_eu.name, float(_eu.health), float(_eu.max_health), _sb.name])

	var fim_espera := Time.get_ticks_msec() + int(ESPERA_CLIENTE * 1000.0)
	while Time.get_ticks_msec() < fim_espera:
		await process_frame
		_cli = _corpo_do_cliente()
		if _cli != null:
			break
	if _cli == null:
		print("[HOST] ❌ nenhum cliente entrou em %.0fs — rode o net_mp_client_probe.gd" % ESPERA_CLIENTE)
		quit(3)
		return
	_peer_cli = str(_cli.name).to_int()
	print("[HOST] cliente conectado -> corpo '%s' (peer %d, authority=%d)"
		% [_cli.name, _peer_cli, _cli.get_multiplayer_authority()])
	print("[HOST] cópia AUTORITATIVA do cliente: hp=%.0f/%.0f  energia=%.0f/%.0f  fruta='%s'"
		% [float(_cli.health), float(_cli.max_health), float(_cli.energy),
			float(_cli.max_energy), str(_cli.current_fruit_id)])
	print("[HOST] VOID_Y=%.1f  RESPAWN=%s  ROUND_TIME=%.0fs (congelado nesta sonda)\n"
		% [Scoreboard.VOID_Y, str(Scoreboard.RESPAWN), Scoreboard.ROUND_TIME])

	var vivo := true
	var teto := Time.get_ticks_msec() + int(TIMEOUT * 1000.0)
	while vivo and Time.get_ticks_msec() < teto:
		await process_frame
		# `GameFlow.hit_stop()` põe a escala em 0,06 no impacto, e este teste MEDE
		# TEMPO. Sem forçar 1x a cada quadro a rede de segurança fica intermitente.
		Engine.time_scale = 1.0
		# A rodada dura 300 s; se ela virar, o pódio respawna todo mundo e devolve
		# as frutas — o que apagaria o beacon e as mortes no meio da medição.
		_sb.time_left = 1.0e9
		if not is_instance_valid(_cli) or not _cli.is_inside_tree():
			print("[HOST] cliente saiu da árvore — fim da coleta.")
			vivo = false
			break
		_passo()
		if _fase == "buki_buki":
			print("[HOST] o cliente anunciou FIM — fecho a coleta.")
			vivo = false
			break
	if vivo:
		print("[HOST] ⏱️ teto de %.0fs atingido — fim da coleta." % TIMEOUT)
	_relatorio()
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ máquina
func _passo() -> void:
	var beacon: String = str(_cli.current_fruit_id)

	# "" não é fase: é o RASTRO do respawn. `net_force_respawn` (Player.gd:1139)
	# devolve a fruta à árvore e zera `current_fruit_id` NO CLIENTE — a volta
	# desse "" até aqui é a prova, medida neste processo, de que o cliente de
	# fato executou o respawn que o servidor mandou.
	if beacon == "":
		if _fruta_vazia.is_empty() or str(_fruta_vazia[-1]["f"]) != _fase:
			_fruta_vazia.append({"t": _t(), "f": _fase})
			print("[HOST][t=%6.2f] 🍃 current_fruit_id do cliente voltou a '' — respawn confirmado (fase %s)"
				% [_t(), FASES.get(_fase, "?")])
	elif FASES.has(beacon) and beacon != _fase:
		if not _comecou and beacon != FASE_INICIAL:
			return          # ignora a fruta de nascença até o cliente falar
		_comecou = true
		_fase = beacon
		_fase_t0 = _agora()
		_linha.append({"t": _t(), "b": beacon, "f": str(FASES[beacon])})
		print("\n[HOST][t=%6.2f] ▶ FASE %s   (beacon '%s')" % [_t(), str(FASES[beacon]), beacon])
		_entrar_na_fase(beacon)

	match _fase:
		"gomu_gomu": _amostrar_movimento()
		"bara_bara": _amostrar_dano()
		"hie_hie":   _amostrar_queda()
		"goro_goro": _amostrar_energia()
		"yami_yami": _amostrar_vida()
		_: pass

func _entrar_na_fase(beacon: String) -> void:
	match beacon:
		"bara_bara":
			_dano["hp0"] = float(_cli.health)
			_dano["mortes0"] = _mortes(_peer_cli)
			_dano["kills0"] = _kills(1)
			print("     hp autoritativo do cliente ao entrar: %.1f | mortes=%d | kills do host=%d"
				% [_dano["hp0"], _dano["mortes0"], _dano["kills0"]])
		"hie_hie":
			_queda["mortes0"] = _mortes(_peer_cli)
			print("     mortes do peer %d ao entrar: %d" % [_peer_cli, _queda["mortes0"]])
		"goro_goro":
			_en["e0"] = float(_cli.energy)
		"yami_yami":
			_vd["hp_antes"] = float(_cli.health)

# ------------------------------------------------------- item 1: movimentação
func _amostrar_movimento() -> void:
	if bool(_mov["fechado"]):
		return
	var p: Vector3 = _cli.global_position
	if not bool(_mov["tem"]):
		# A medição só ABRE quando a cópia chega ao ponto de partida combinado. O
		# beacon chega antes de o cliente se posicionar, e sem esta trava o salto
		# "spawn -> ponto de partida" entrava na conta como caminho percorrido
		# (a 1ª rodada desta sonda mediu 17 m onde havia 12 — era esse salto).
		if Vector2(p.x - MOV_INICIO.x, p.z - MOV_INICIO.z).length() > 0.05:
			return
		_mov["tem"] = true
		_mov["ini"] = p
		_mov["ult"] = p
		_mov["t_ini"] = _t()
		print("[HOST][t=%6.2f] 📍 a cópia do cliente chegou ao ponto de partida %s — começo a somar o caminho"
			% [_t(), _v(p)])
	else:
		var a: Vector3 = _mov["ult"]
		var passo: float = Vector2(p.x - a.x, p.z - a.z).length()
		if passo > 0.0001:
			_mov["dist"] = float(_mov["dist"]) + passo
			_mov["ult"] = p
			_mov["n"] = int(_mov["n"]) + 1
			_mov["t_fim"] = _t()
	_mov["fim"] = p
	# E FECHA na chegada, pela mesma razão por que só abre na partida: o cliente
	# só troca o beacon DEPOIS de se posicionar para a fase seguinte, e o salto
	# até lá entraria na conta do caminho (a 2ª rodada mediu 18 m onde havia 12).
	if bool(_mov["tem"]) and Vector2(p.x - MOV_FIM.x, p.z - MOV_FIM.z).length() < 0.05:
		_mov["fechado"] = true
		print("[HOST][t=%6.2f] 🏁 a cópia do cliente chegou ao ponto de chegada %s — fecho a soma em %.3f m"
			% [_t(), _v(p), float(_mov["dist"])])

# ---------------------------------------------------- item 2A: morte por DANO
func _amostrar_dano() -> void:
	# Espero o beacon assentar antes de bater. Na 1ª rodada desta sonda o host
	# batia 2 s depois de VER o beacon e a morte inteira acontecia ANTES de o
	# cliente entrar no laço de medição dele — que então não via respawn nenhum.
	# 4 s dá folga para os dois lados estarem na mesma fase.
	if not bool(_dano["feito"]) and _fase_t() > 4.0:
		_dano["feito"] = true
		_dano["t_golpe"] = _t()
		# `register_hit` é exatamente o que a DamageZone faz no servidor a cada
		# acerto (src/effects/DamageZone.gd) — sem ele a morte não credita kill.
		_sb.register_hit(_cli, _eu)
		print("[HOST][t=%6.2f] 🥊 golpe 1: take_damage(%.0f) na cópia autoritativa" % [_t(), DANO_GOLPE])
		_cli.take_damage(DANO_GOLPE)
		_dano["hp_pos_golpe1"] = float(_cli.health)
		print("[HOST][t=%6.2f] 🥊 golpe 2 (FATAL): take_damage(%.0f) — hp estava %.1f"
			% [_t(), DANO_GOLPE, _dano["hp_pos_golpe1"]])
		_cli.take_damage(DANO_GOLPE)
		_dano["hp_pos_fatal"] = float(_cli.health)
		_dano["mortes1"] = _mortes(_peer_cli)
		_dano["kills1"] = _kills(1)
		print("[HOST][t=%6.2f] hp autoritativo depois do fatal = %.1f | mortes=%d | kills do host=%d"
			% [_t(), _dano["hp_pos_fatal"], _dano["mortes1"], _dano["kills1"]])
	if bool(_dano["feito"]):
		var d: float = _cli.global_position.distance_to(Scoreboard.RESPAWN)
		if d < float(_dano["dist_respawn"]):
			_dano["dist_respawn"] = d
			if d < 3.0 and float(_dano["t_respawn"]) < 0.0:
				_dano["t_respawn"] = _t()
				print("[HOST][t=%6.2f] 🛬 a posição REPLICADA do cliente chegou ao RESPAWN (%.2f m) — %.2fs depois do golpe"
					% [_t(), d, _t() - float(_dano["t_golpe"])])
		_dano["hp_fim"] = float(_cli.health)
		_dano["pos_fim"] = _cli.global_position

# --------------------------------------------------- item 2B: morte por QUEDA
func _amostrar_queda() -> void:
	var y: float = _cli.global_position.y
	_queda["y_min"] = minf(float(_queda["y_min"]), y)
	if y < Scoreboard.VOID_Y:
		if not bool(_queda["viu_abaixo"]):
			_queda["viu_abaixo"] = true
			_queda["t_abaixo"] = _t()
			print("[HOST][t=%6.2f] 🕳️ vejo o cliente ABAIXO do VOID_Y (y=%.1f < %.1f) pela posição replicada"
				% [_t(), y, Scoreboard.VOID_Y])
	elif bool(_queda["viu_abaixo"]) and not bool(_queda["viu_acima"]):
		_queda["viu_acima"] = true
		_queda["t_acima"] = _t()
		_queda["mortes1"] = _mortes(_peer_cli)
		print("[HOST][t=%6.2f] 🛬 o cliente voltou para cima do vazio (y=%.2f) — %.2fs no buraco"
			% [_t(), y, _t() - float(_queda["t_abaixo"])])
	if bool(_queda["viu_abaixo"]):
		_queda["dist_respawn"] = minf(float(_queda["dist_respawn"]),
			_cli.global_position.distance_to(Scoreboard.RESPAWN))
	if int(_queda["mortes1"]) < 0:
		_queda["mortes1"] = _mortes(_peer_cli)

# ------------------------------------------------------- item 3: ENERGIA aqui
# Prova NEGATIVA e proposital: aqui é a cópia SEM autoridade. A regen mora no
# `_physics_process`, que devolve em `not _is_authority` (Player.gd:682-684) —
# então zerar a energia AQUI tem que ficar zerado para sempre. Quem regenera é o
# dono, e quem mede isso é a sonda do cliente.
func _amostrar_energia() -> void:
	if not bool(_en["zerou"]) and _fase_t() > 2.0:
		_en["zerou"] = true
		_en["t_zero"] = _t()
		_cli.energy = 0.0
		print("[HOST][t=%6.2f] 🔋 zerei a energia da CÓPIA AUTORITATIVA (era %.1f)" % [_t(), float(_en["e0"])])
	if bool(_en["zerou"]):
		var e: float = float(_cli.energy)
		_en["e_fim"] = e
		_en["e_max"] = maxf(float(_en["e_max"]), e)
		_en["n"] = int(_en["n"]) + 1

# ---------------------------------------------------------- item 6: VIDA aqui
func _amostrar_vida() -> void:
	if not bool(_vd["bateu"]) and _fase_t() > 2.0:
		_vd["bateu"] = true
		_vd["t_golpe"] = _t()
		# ⚠️ RESTAURO À MÃO, e isso É um achado: depois da morte por dano da fase
		# 2A o `net_force_respawn` foi entregue só ao DONO (rpc_id), então a
		# cópia autoritativa ficou com hp=0 para sempre. Sem este restauro,
		# qualquer dano aqui mataria de novo e o item 6 não teria o que medir.
		print("[HOST][t=%6.2f] ⚠️ hp autoritativo antes de restaurar: %.1f (era para estar cheio)"
			% [_t(), float(_vd["hp_antes"])])
		_cli.health = _cli.max_health
		_cli.take_damage(DANO_NAO_FATAL)
		_vd["hp_depois_golpe"] = float(_cli.health)
		print("[HOST][t=%6.2f] 🩸 dano não-fatal de %.0f -> hp=%.1f. Agora só observo."
			% [_t(), DANO_NAO_FATAL, _vd["hp_depois_golpe"]])
	if bool(_vd["bateu"]):
		var h: float = float(_cli.health)
		_vd["hp_fim"] = h
		_vd["hp_max_visto"] = maxf(float(_vd["hp_max_visto"]), h)
		_vd["n"] = int(_vd["n"]) + 1


# -------------------------------------------------------------------- relatório
func _relatorio() -> void:
	print("\n╔══════════════════════════════════════════════════════════════════╗")
	print("║  MULTIPLAYER — MEDIDO NO PROCESSO DO HOST (cópia autoritativa)   ║")
	print("╚══════════════════════════════════════════════════════════════════╝")

	print("\n-- linha do tempo das fases (anunciadas pelo cliente via current_fruit_id) --")
	for l in _linha:
		print("   t=%7.2f  %s" % [float(l["t"]), str(l["f"])])
	print("   respawns vistos pelo apagamento da fruta: %d" % _fruta_vazia.size())

	# ------------------------------------------------------------------ item 1
	print("\n-- ITEM 1: MOVIMENTAÇÃO REPLICA --")
	var esperado: float = Vector2(MOV_FIM.x - MOV_INICIO.x, MOV_FIM.z - MOV_INICIO.z).length()
	var ini: Vector3 = _mov["ini"]
	var fim: Vector3 = _mov["fim"]
	var desloc: float = Vector2(fim.x - ini.x, fim.z - ini.z).length()
	var erro_ini: float = Vector2(ini.x - MOV_INICIO.x, ini.z - MOV_INICIO.z).length()
	var erro_fim: float = Vector2(fim.x - MOV_FIM.x, fim.z - MOV_FIM.z).length()
	print("   trajeto combinado : %s -> %s  (%.2f m em XZ)" % [str(MOV_INICIO), str(MOV_FIM), esperado])
	print("   visto pelo host   : %s -> %s" % [_v(ini), _v(fim)])
	print("   caminho somado    : %.3f m em %d amostras (%.2f s de fase)"
		% [float(_mov["dist"]), int(_mov["n"]), float(_mov["t_fim"]) - float(_mov["t_ini"])])
	print("   deslocamento reto : %.3f m" % desloc)
	print("   ERRO no ponto de partida: %.3f m | ERRO no ponto de chegada: %.3f m" % [erro_ini, erro_fim])
	print("   ERRO do caminho percorrido: %+.3f m (%.2f%% de %.2f m)"
		% [float(_mov["dist"]) - esperado, absf(float(_mov["dist"]) - esperado) / esperado * 100.0, esperado])
	_ok(int(_mov["n"]) > 20, "o host viu o corpo do cliente se mexer em %d amostras (não é um teleporte só)"
		% int(_mov["n"]))
	_ok(erro_fim < 0.5, "a cópia do host parou a %.3f m do ponto de chegada combinado (tolerância 0,50 m)" % erro_fim)
	_ok(absf(float(_mov["dist"]) - esperado) < 1.0,
		"o caminho medido no host (%.3f m) bate com os %.2f m percorridos pelo dono (erro %+.3f m)"
		% [float(_mov["dist"]), esperado, float(_mov["dist"]) - esperado])

	# ----------------------------------------------------------------- item 2A
	print("\n-- ITEM 2A: MORTE POR DANO EM REDE --")
	print("   hp da cópia autoritativa: %.1f -> %.1f (golpe 1) -> %.1f (fatal) -> %.1f (fim da fase)"
		% [float(_dano["hp0"]), float(_dano["hp_pos_golpe1"]), float(_dano["hp_pos_fatal"]), float(_dano["hp_fim"])])
	print("   placar do peer %d: mortes %d -> %d | kills do host (peer 1): %d -> %d"
		% [_peer_cli, int(_dano["mortes0"]), int(_dano["mortes1"]),
			int(_dano["kills0"]), int(_dano["kills1"])])
	print("   posição replicada do cliente chegou a %.2f m do RESPAWN %s (%.2f s depois do golpe)"
		% [float(_dano["dist_respawn"]), str(Scoreboard.RESPAWN),
			float(_dano["t_respawn"]) - float(_dano["t_golpe"]) if float(_dano["t_respawn"]) >= 0.0 else -1.0])
	_ok(float(_dano["hp0"]) == float(_cli.max_health) if is_instance_valid(_cli) else false,
		"a cópia autoritativa entrou na fase com a vida cheia (%.1f)" % float(_dano["hp0"]))
	_ok(float(_dano["hp_pos_fatal"]) == 0.0,
		"o golpe fatal levou a vida autoritativa a ZERO (%.1f)" % float(_dano["hp_pos_fatal"]))
	_ok(int(_dano["mortes1"]) == int(_dano["mortes0"]) + 1,
		"o PLACAR DO HOST contou a morte por dano (%d -> %d)" % [int(_dano["mortes0"]), int(_dano["mortes1"])])
	_ok(int(_dano["kills1"]) == int(_dano["kills0"]) + 1,
		"a kill foi creditada ao host (%d -> %d)" % [int(_dano["kills0"]), int(_dano["kills1"])])
	_ok(float(_dano["dist_respawn"]) < 3.0,
		"o host VIU o cliente respawnar no RESPAWN (menor distância medida: %.2f m)" % float(_dano["dist_respawn"]))

	print("\n   ⚠️ ACHADO (relatado, NÃO corrigido) — a cópia autoritativa NUNCA volta a ter vida:")
	print("      hp no servidor %.2f s depois do respawn = %.1f de %.1f"
		% [_t() - float(_dano["t_golpe"]), float(_dano["hp_fim"]),
			float(_cli.max_health) if is_instance_valid(_cli) else 0.0])
	print("      `Scoreboard._order_respawn` manda `net_force_respawn.rpc_id(peer)` (Scoreboard.gd:156),")
	print("      então só o DONO restaura. O `_vida.restaurar()` nunca roda na cópia do servidor —")
	print("      que é justamente a que a `DamageZone` machuca. Efeito: depois da 1ª morte por dano,")
	print("      passados os 2 s de `_dead_until`, QUALQUER acerto mata o cliente na hora, para sempre.")

	# ----------------------------------------------------------------- item 2B
	print("\n-- ITEM 2B: MORTE POR QUEDA EM REDE --")
	print("   menor y replicado que o host viu: %.2f (VOID_Y = %.1f)"
		% [float(_queda["y_min"]), Scoreboard.VOID_Y])
	print("   placar do peer %d: mortes %d -> %d" % [_peer_cli, int(_queda["mortes0"]), int(_queda["mortes1"])])
	var dt_queda: float = float(_queda["t_acima"]) - float(_queda["t_abaixo"])
	print("   tempo entre 'vi ele no vazio' e 'ele voltou': %.3f s" % dt_queda)
	print("   menor distância até o RESPAWN depois da queda: %.2f m" % float(_queda["dist_respawn"]))
	_ok(bool(_queda["viu_abaixo"]) and float(_queda["y_min"]) < Scoreboard.VOID_Y,
		"o host enxergou a queda pela POSIÇÃO REPLICADA (y=%.2f < %.1f) — é assim que `_watch_falls` decide"
		% [float(_queda["y_min"]), Scoreboard.VOID_Y])
	_ok(int(_queda["mortes1"]) == int(_queda["mortes0"]) + 1,
		"o PLACAR DO HOST contou a morte por queda (%d -> %d)" % [int(_queda["mortes0"]), int(_queda["mortes1"])])
	_ok(bool(_queda["viu_acima"]) and float(_queda["dist_respawn"]) < 3.0,
		"o cliente respawnou no RESPAWN depois da queda (%.2f m) em %.3f s"
		% [float(_queda["dist_respawn"]), dt_queda])

	# ------------------------------------------------------------------ item 3
	print("\n-- ITEM 3: A CÓPIA SEM AUTORIDADE NÃO REGENERA ENERGIA (prova negativa) --")
	print("   energia da cópia autoritativa: %.1f -> zerada -> %.1f (máximo lido depois de zerar: %.1f, %d amostras)"
		% [float(_en["e0"]), float(_en["e_fim"]), float(_en["e_max"]), int(_en["n"])])
	print("   se ela regenerasse a %.0f/s, em %.2f s teria voltado ~%.0f"
		% [HealthController.REGEN_ENERGIA, _t() - float(_en["t_zero"]),
			minf(HealthController.REGEN_ENERGIA * (_t() - float(_en["t_zero"])), 4096.0)])
	_ok(int(_en["n"]) > 10 and float(_en["e_max"]) <= 0.01,
		"a energia da cópia do servidor ficou em %.2f — a regen só roda na AUTORIDADE (Player.gd:682)"
		% float(_en["e_max"]))

	# ------------------------------------------------------------------ item 6
	print("\n-- ITEM 6: A VIDA NÃO REGENERA (medido na cópia autoritativa) --")
	print("   hp: cheio %.1f -> dano de %.0f -> %.1f ... %.1f no fim (%d amostras, máximo lido %.1f)"
		% [float(_cli.max_health) if is_instance_valid(_cli) else 0.0, DANO_NAO_FATAL,
			float(_vd["hp_depois_golpe"]), float(_vd["hp_fim"]), int(_vd["n"]), float(_vd["hp_max_visto"])])
	_ok(int(_vd["n"]) > 10 and absf(float(_vd["hp_fim"]) - float(_vd["hp_depois_golpe"])) < 0.01,
		"a vida ficou PARADA em %.1f durante %.2f s — não existe regen de vida no jogo"
		% [float(_vd["hp_fim"]), _t() - float(_vd["t_golpe"])])

	print("\n==================================================================")
	if _falhas == 0:
		print("✅ MULTIPLAYER OK — todas as checagens do lado do host passaram")
	else:
		print("❌ %d falha(s) do lado do host" % _falhas)


# ------------------------------------------------------------------- utilidades
func _mortes(peer: int) -> int:
	if _sb == null:
		return 0
	for linha in _sb.ranking():
		if int(linha[0]) == peer:
			return int(linha[2])
	return 0

func _kills(peer: int) -> int:
	if _sb == null:
		return 0
	for linha in _sb.ranking():
		if int(linha[0]) == peer:
			return int(linha[1])
	return 0

func _corpo(nome: String) -> Node:
	for p in get_nodes_in_group("player"):
		if str(p.name) == nome:
			return p
	return null

func _corpo_do_cliente() -> Node:
	for p in get_nodes_in_group("player"):
		if str(p.name) != "1":
			return p
	return null

func _agora() -> float:
	return Time.get_ticks_msec() / 1000.0

func _t() -> float:
	return _agora() - _t0

func _fase_t() -> float:
	return _agora() - _fase_t0

func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]

func _ok(cond: bool, msg: String) -> void:
	print(("   ✅ " if cond else "   ❌ ") + msg)
	if not cond:
		_falhas += 1
