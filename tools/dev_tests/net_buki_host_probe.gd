extends SceneTree
# ============================================================================
#  SONDA BUKI BUKI — LADO HOST (2 processos). É o JUIZ do teste.
#
#  Por que existe: os 4 RPCs do arsenal da Buki (`_net_buki_sacar_req`,
#  `_net_buki_sacar`, `_net_buki_guardar_req`, `_net_buki_guardar`) e a validação
#  de munição em `_do_server_bullet` NÃO aparecem em compilação nem em teste
#  headless de 1 processo — em singleplayer o cliente É o servidor e todo
#  `rpc_id(1, ...)` vira chamada local. Só com DOIS processos o caminho de rede
#  de verdade é exercitado.
#
#  Este script NÃO age: ele OBSERVA a cópia autoritativa do corpo do cliente
#  dentro do processo do servidor e transcreve, quadro a quadro:
#     • `_buki_visual`     -> a arma que o adversário VÊ na mão (chega por
#                             `_net_buki_sacar` / `_net_buki_guardar`);
#     • `_srv_buki_arma`   -> a arma que o SERVIDOR autoriza (só muda por
#                             `_do_server_buki_sacar/guardar`, e do lado do
#                             cliente só dá pra chegar lá pelos RPCs `_req`);
#     • `_srv_buki_municao`-> o pente autoritativo;
#     • nascimento de cada DamageZone na cena (filhas diretas de current_scene,
#       que é onde `BukiFX._projetil` as pendura);
#     • a vida do corpo do HOST (2048 cheia) — o alvo do cliente.
#
#  O tempo é fatiado em SEGMENTOS: cada troca de `_srv_buki_arma` fecha um e
#  abre outro. Assim a sonda se sincroniza sozinha com o cliente, sem combinar
#  relógio nem contar segundos — o protocolo é o próprio sinal.
#
#  ⚠️ Suba ESTE primeiro. Porta 24565 é fixa e única: dois processos hospedando
#  ao mesmo tempo = o segundo não acha servidor e trava até o timeout.
#
#    godot --headless --path . --script tools/dev_tests/net_buki_host_probe.gd
# ============================================================================

const TIMEOUT := 600.0          # teto absoluto (segundos)
# Folgado de propósito: o host sobe primeiro e fica de porta aberta. Quem abre o
# segundo terminal na mão demora, e sonda que desiste sozinha vira "não conectou"
# quando o problema era só o dedo do operador.
const ESPERA_CLIENTE := 300.0   # quanto espera o cliente entrar

var _eu: Node = null            # corpo do HOST (o alvo)
var _cli: Node = null           # corpo do CLIENTE, cópia autoritativa (servidor)
var _t0 := 0.0

var _zonas_vistas := {}         # instance_id -> true (pra contar só o NASCIMENTO)
var _nascimentos: Array = []    # uma linha por DamageZone: t, dano, slot, arma_srv
var _segs: Array = []           # linha do tempo por arma autorizada
var _seg: Dictionary = {}
var _visual: Array = []         # transições de `_buki_visual` (o que o host VÊ)
var _refis: Array = []          # recargas de pente DENTRO do mesmo segmento
var _dano_para_slot := {}       # dano por bala -> slot (identifica a arma da zona)
var _t_desarme := -1.0          # quando o servidor viu a arma sair da mão
var _falhas := 0

# Tolerância de UM quadro. O 5º tiro da sniper e o `_buki_guardar()` que ele
# dispara ("acabou a bala") chegam ao servidor no MESMO quadro: quando eu
# amostro, a arma já saiu da mão mas a zona daquele tiro ACABOU de nascer. Sem
# essa janela eu acusaria de fraude um tiro que foi pago — e mentir num teste de
# segurança é pior do que não ter teste.
const GRACA_QUADRO := 0.05

func _init() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec() / 1000.0
	# Autoload em script `-s` não vira identificador de compilação -> pega por nó.
	get_root().get_node("GameFlow").create_room()
	print("[HOST] sala criada (porta 24565) — esperando o cliente...")

	for i in 900:
		await process_frame
		_eu = _corpo_por_nome("1")
		if _eu != null:
			break
	if _eu == null:
		print("[HOST] ❌ meu corpo (peer 1) nunca apareceu")
		quit(3)
		return
	print("[HOST] meu corpo = '%s'  hp=%.0f/%.0f" % [_eu.name, _eu.health, _eu.max_health])

	var fim_espera := Time.get_ticks_msec() + int(ESPERA_CLIENTE * 1000.0)
	while Time.get_ticks_msec() < fim_espera:
		await process_frame
		_cli = _corpo_do_cliente()
		if _cli != null:
			break
	if _cli == null:
		print("[HOST] ❌ nenhum cliente entrou em %.0fs — rode o net_buki_client_probe.gd" % ESPERA_CLIENTE)
		quit(3)
		return
	print("[HOST] cliente conectado -> corpo '%s' (authority=%d)"
		% [_cli.name, _cli.get_multiplayer_authority()])
	print("[HOST] hp inicial do ALVO (corpo do host) = %.1f" % _eu.health)
	print("[HOST] observando... (o cliente comanda; eu só meço)\n")

	# Dano por bala -> slot. É como eu identifico QUAL arma pariu cada DamageZone
	# sem depender do instante em que amostrei `_srv_buki_arma`.
	var fs: Dictionary = SkillSystem.get_fruit_skills().get("buki_buki", {})
	for slot in fs.keys():
		_dano_para_slot[float(fs[slot].get("dano", 0))] = str(slot)
	print("[HOST] dano por bala -> arma: %s" % str(_dano_para_slot))

	_abrir_seg(_arma(), _mun(), _hp())
	_sincronizar_zonas()   # ignora o que já existia antes de eu começar a contar

	var vivo := true
	var teto := Time.get_ticks_msec() + int(TIMEOUT * 1000.0)
	while vivo and Time.get_ticks_msec() < teto:
		await process_frame
		if not is_instance_valid(_cli) or not _cli.is_inside_tree():
			print("[HOST] cliente saiu da árvore — fim da coleta.")
			vivo = false
			break
		_amostrar()
	if vivo:
		print("[HOST] ⏱️ teto de %.0fs atingido — fim da coleta." % TIMEOUT)
	_fechar_seg()
	_relatorio()
	quit(1 if _falhas > 0 else 0)

# ------------------------------------------------------------------ amostragem
func _amostrar() -> void:
	var arma := _arma()
	var mun := _mun()
	var hp := _hp()
	var vis := str(_cli.get("_buki_visual"))

	# (a) o que o HOST VÊ na mão do cliente — só `_net_buki_sacar`/`_net_buki_guardar`
	# mexem nisso nesta cópia; nada de local roda aqui.
	if _visual.is_empty() or str(_visual[-1]["v"]) != vis:
		_visual.append({"t": _t(), "v": vis, "arma_srv": arma})
		print("[HOST][t=%6.2f] 👁️  _buki_visual: '%s'   (srv_arma='%s' srv_mun=%d)"
			% [_t(), vis, arma, mun])

	# (b) troca de arma autorizada = fecha um segmento e abre outro
	if arma != str(_seg.get("arma", "")):
		if arma == "":
			_t_desarme = _t()
		_fechar_seg()
		_abrir_seg(arma, mun, hp)
		print("[HOST][t=%6.2f] 🔐 srv_buki_arma -> '%s'  (pente=%d)" % [_t(), arma, mun])
	else:
		# recarga silenciosa DENTRO do mesmo segmento: o pente SUBIU sem trocar de
		# arma. Só `_do_server_buki_sacar` faz isso -> é saque repetido aceito.
		if mun > int(_seg["mun_fim"]):
			_refis.append({"t": _t(), "arma": arma, "de": int(_seg["mun_fim"]), "para": mun})
			print("[HOST][t=%6.2f] ♻️  PENTE RECARREGADO sem trocar de arma: %d -> %d ('%s')"
				% [_t(), int(_seg["mun_fim"]), mun, arma])
		_seg["mun_fim"] = mun
		_seg["mun_min"] = mini(int(_seg["mun_min"]), mun)
		_seg["hp_fim"] = hp

	# (c) nascimento de DamageZone (filhas diretas da cena, onde BukiFX as põe)
	var cena := current_scene
	if cena != null:
		for c in cena.get_children():
			if c is DamageZone and not _zonas_vistas.has(c.get_instance_id()):
				_zonas_vistas[c.get_instance_id()] = true
				_seg["zonas"] = int(_seg["zonas"]) + 1
				# A arma da zona vem do DANO POR BALA, não do instante em que
				# amostrei — assim a corrida de quadro não troca a etiqueta.
				var slot: String = str(_dano_para_slot.get(float(c.damage), "?"))
				_nascimentos.append({
					"t": _t(), "dano": float(c.damage), "slot": slot,
					"arma_srv": arma, "pente": mun,
					"desde_desarme": (_t() - _t_desarme) if _t_desarme >= 0.0 else -1.0,
				})
				print("[HOST][t=%6.2f] 💥 DamageZone #%d NASCEU  dano=%.1f (arma '%s') caster='%s' arma_srv='%s' pente=%d"
					% [_t(), _nascimentos.size(), float(c.damage), slot,
						(c.caster.name if is_instance_valid(c.caster) else "<null>"), arma, mun])

func _sincronizar_zonas() -> void:
	var cena := current_scene
	if cena == null:
		return
	for c in cena.get_children():
		if c is DamageZone:
			_zonas_vistas[c.get_instance_id()] = true

# -------------------------------------------------------------------- relatório
func _relatorio() -> void:
	print("\n╔══════════════════════════════════════════════════════════════════╗")
	print("║  BUKI BUKI EM REDE — MEDIDO NO PROCESSO DO HOST                  ║")
	print("╚══════════════════════════════════════════════════════════════════╝")

	print("\n-- linha do tempo do que o HOST VÊ na mão do cliente (_buki_visual) --")
	for v in _visual:
		print("   t=%6.2f  '%s'" % [float(v["t"]), str(v["v"])])

	print("\n-- segmentos por arma AUTORIZADA pelo servidor (_srv_buki_arma) --")
	print("   %-6s %-8s %-8s %-14s %-7s %s" % ["arma", "t_ini", "t_fim", "pente", "zonas", "hp do alvo"])
	for s in _segs:
		print("   %-6s %-8.2f %-8.2f %-14s %-7d %.1f -> %.1f" % [
			"'%s'" % str(s["arma"]), float(s["t_ini"]), float(s["t_fim"]),
			"%d->%d (min %d)" % [int(s["mun_ini"]), int(s["mun_fim"]), int(s["mun_min"])],
			int(s["zonas"]), float(s["hp_ini"]), float(s["hp_fim"])])

	var armados: Array = _segs.filter(func(s): return str(s["arma"]) != "")
	var desarmados: Array = _segs.filter(func(s): return str(s["arma"]) == "")
	var zonas_total := _zonas_vistas.size()

	# ------------------------------------------------------------------ item 1
	print("\n-- ITEM 1: SACAR REPLICA (o host vê a arma na mão do cliente) --")
	var sacadas: Array = _visual.filter(func(v): return str(v["v"]) != "")
	var nomes: Array = sacadas.map(func(v): return str(v["v"]))
	_ok(sacadas.size() > 0,
		"o host viu %d saque(s) chegar: %s  (nada local mexe em _buki_visual nesta cópia -> veio de `_net_buki_sacar`)"
		% [sacadas.size(), str(nomes)])
	var casaram := 0
	for v in sacadas:
		if str(v["v"]) == str(v["arma_srv"]):
			casaram += 1
	_ok(sacadas.size() > 0 and casaram == sacadas.size(),
		"em %d/%d saques o VISUAL bateu com a arma AUTORIZADA (_buki_visual == _srv_buki_arma)"
		% [casaram, sacadas.size()])

	# ------------------------------------------------------------------ item 2
	print("\n-- ITEM 2: GUARDAR REPLICA (a arma volta pra '' nos dois lados) --")
	var guardadas := 0
	for i in range(1, _visual.size()):
		if str(_visual[i]["v"]) == "" and str(_visual[i - 1]["v"]) != "":
			guardadas += 1
	_ok(guardadas > 0,
		"o host viu %d guardada(s) chegar (arma -> mãos livres via `_net_buki_guardar`)" % guardadas)

	# ------------------------------------------------------------------ item 3
	print("\n-- ITEM 3: O SERVIDOR É A AUTORIDADE DA MUNIÇÃO --")
	# Invariante que interessa e que NÃO depende do instante da amostragem:
	# por arma, o servidor não pode ter parido mais zonas do que a soma dos
	# pentes que ele mesmo autorizou. Cliente mentindo não fura esse teto.
	var teto_ok := true
	var contadas := 0
	for slot in ["Z", "X", "C", "V"]:
		var episodios: int = armados.filter(func(s): return str(s["arma"]) == slot).size()
		if episodios == 0:
			continue
		var nascidas: int = _nascimentos.filter(func(n): return str(n["slot"]) == slot).size()
		contadas += nascidas
		var teto: int = BukiFX.municao(slot) * episodios
		var ok_slot: bool = nascidas <= teto
		if not ok_slot:
			teto_ok = false
		print("     arma '%s': %d zona(s) nascida(s) para %d saque(s) autorizado(s) = teto %d -> %s"
			% [slot, nascidas, episodios, teto, "OK" if ok_slot else "ESTOUROU O PENTE"])
	_ok(teto_ok and contadas > 0,
		"nenhuma arma pariu mais DamageZone do que o pente que o SERVIDOR autorizou")

	# Zonas nascidas de mãos livres. As que caem DENTRO de um quadro do desarme
	# são o próprio tiro que esvaziou o pente (ele paga e guarda a arma no mesmo
	# quadro) — declaradas, não escondidas. Qualquer uma FORA dessa janela é
	# munição que o servidor deu de graça.
	var soltas: Array = _nascimentos.filter(func(n): return str(n["arma_srv"]) == "")
	var vazadas: Array = soltas.filter(func(n): return float(n["desde_desarme"]) > GRACA_QUADRO or float(n["desde_desarme"]) < 0.0)
	for n in soltas:
		print("     zona de mãos livres: t=%.2f arma '%s' dano=%.0f — %.3fs após o desarme %s"
			% [float(n["t"]), str(n["slot"]), float(n["dano"]), float(n["desde_desarme"]),
				"(corrida de quadro: é o tiro que ZEROU o pente)" if not vazadas.has(n) else "<<< VAZOU"])
	_ok(vazadas.is_empty(),
		"ZERO DamageZone nasceram sem arma autorizada fora da janela de %.0f ms — medido: %d de %d"
		% [GRACA_QUADRO * 1000.0, vazadas.size(), soltas.size()])
	print("     total de DamageZone nascidas na cena do host: %d" % zonas_total)

	# ------------------------------------------------------------------ item 4
	print("\n-- ITEM 4: O TIRO DO CLIENTE FERE DE VERDADE NO HOST --")
	var hp_ini: float = float(_segs[0]["hp_ini"]) if _segs.size() > 0 else 0.0
	var hp_fim: float = float(_segs[-1]["hp_fim"]) if _segs.size() > 0 else 0.0
	_ok(hp_fim < hp_ini,
		"vida do corpo do HOST caiu %.1f -> %.1f  (Δ = %+.1f de %.0f)"
		% [hp_ini, hp_fim, hp_fim - hp_ini, _eu.max_health if is_instance_valid(_eu) else 2048.0])
	for s in armados:
		var d: float = float(s["hp_fim"]) - float(s["hp_ini"])
		if absf(d) > 0.01:
			print("     durante a arma '%s': %.1f -> %.1f (%+.1f)"
				% [str(s["arma"]), float(s["hp_ini"]), float(s["hp_fim"]), d])

	# ------------------------------------------------------------------ item 5
	print("\n-- ITEM 5: OS 4 RPCs FORAM MESMO EXERCITADOS (prova por efeito) --")
	var n_sacar_req := armados.size()
	print("   _net_buki_sacar_req  (cliente->servidor) : %d vez(es)  — `_srv_buki_arma` só é escrita"
		% n_sacar_req)
	print("                                              por `_do_server_buki_sacar`, e do cliente")
	print("                                              não-servidor o único caminho até lá é esse RPC")
	print("   _net_buki_sacar      (servidor->todos)   : %d vez(es)  — `_buki_visual` != '' nesta cópia"
		% sacadas.size())
	print("                                              só pode ter vindo do broadcast")
	print("   _net_buki_guardar_req(cliente->servidor) : %d vez(es)  — `_srv_buki_arma` voltou a ''"
		% maxi(desarmados.size() - 1, 0))
	print("   _net_buki_guardar    (servidor->todos)   : %d vez(es)  — `_buki_visual` voltou a ''"
		% guardadas)
	print("   _net_bullet_req/_net_bullet_play          : %d zona(s) nascida(s) neste processo" % zonas_total)
	_ok(n_sacar_req > 0 and sacadas.size() > 0 and guardadas > 0 and zonas_total > 0,
		"os quatro caminhos de RPC do arsenal deixaram rastro medido neste processo")

	# ------------------------------------------------- achado extra (não é falha)
	print("\n-- ACHADO (relatado, NÃO corrigido): saque recarrega o pente sem checar recarga --")
	if _refis.is_empty():
		print("   nenhuma recarga silenciosa observada nesta rodada.")
	else:
		for r in _refis:
			print("   ⚠️ t=%6.2f  arma '%s': pente %d -> %d sem trocar de arma"
				% [float(r["t"]), str(r["arma"]), int(r["de"]), int(r["para"])])
		print("   `_do_server_buki_sacar` NÃO consulta `_skill_cooldowns` — o cooldown do slot")
		print("   é decidido só no cliente (`_buki_empunhar`). Cliente adulterado que repita")
		print("   `_net_buki_sacar_req` enche o pente autoritativo à vontade = munição infinita.")

	print("\n==================================================================")
	if _falhas == 0:
		print("✅ BUKI EM REDE OK — 7 checagens medidas no processo do host")
	else:
		print("❌ %d falha(s) do lado do host" % _falhas)

# ------------------------------------------------------------------- utilidades
func _abrir_seg(arma: String, mun: int, hp: float) -> void:
	_seg = {"arma": arma, "t_ini": _t(), "t_fim": _t(), "mun_ini": mun,
			"mun_fim": mun, "mun_min": mun, "zonas": 0, "hp_ini": hp, "hp_fim": hp}

func _fechar_seg() -> void:
	if _seg.is_empty():
		return
	_seg["t_fim"] = _t()
	_segs.append(_seg.duplicate())

func _arma() -> String:
	return str(_cli.get("_srv_buki_arma")) if is_instance_valid(_cli) else ""

func _mun() -> int:
	return int(_cli.get("_srv_buki_municao")) if is_instance_valid(_cli) else 0

func _hp() -> float:
	return float(_eu.health) if is_instance_valid(_eu) else 0.0

func _t() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0

func _corpo_por_nome(n: String) -> Node:
	for p in get_nodes_in_group("player"):
		if str(p.name) == n:
			return p
	return null

func _corpo_do_cliente() -> Node:
	for p in get_nodes_in_group("player"):
		if str(p.name) != "1":
			return p
	return null

func _ok(cond: bool, msg: String) -> void:
	print(("   ✅ " if cond else "   ❌ ") + msg)
	if not cond:
		_falhas += 1
