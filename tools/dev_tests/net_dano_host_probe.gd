extends SceneTree
# ============================================================================
#  SONDA DE DANO RECÍPROCO — LADO HOST (2 processos). É o JUIZ e o ALGOZ.
#
#  ------------------------------------------------- O BURACO QUE ISTO FECHA
#  O `net_mp_probe` já cobre dano em rede, mas só num sentido e só até a MORTE:
#  ele bate no cliente até matar. O `net_cast_probe` cobre o sentido inverso
#  (golpe do cliente vira hitbox no servidor), mas mede "a vida caiu", não
#  QUANTO caiu. Nenhum dos dois responde às três perguntas daqui:
#
#    1. os DOIS corpos apanham na mesma partida? (reciprocidade)
#    2. a quantia que chega é a quantia que foi pedida? (nem escalada, nem
#       duplicada, nem cortada por orçamento)
#    3. os DOIS processos concordam sobre a vida dos DOIS corpos?
#
#  A pergunta 2 tem dono: o `DAMAGE_SCALE = 0.12` que vivia dentro da
#  `DamageZone` fazia quem chamasse `take_damage` direto entregar 8,3x o valor
#  do funil (ver o cabeçalho do CombatResolver). Um teste que só olha "a vida
#  caiu" passa feliz com o dano 8x errado.
#
#  A pergunta 3 tem dono também: em 2026-08-12 a vítima morria com a BARRA
#  CHEIA na tela dela — a vida do servidor não atravessava a rede. Medir a vida
#  só neste processo não pega isso; por isso o cliente julga o mesmo número do
#  lado dele.
#
#  ------------------------------------------------- POR QUE O HOST BATE NOS DOIS
#  Não é assimetria de teste: é a regra do jogo. A vida é do SERVIDOR
#  (Player.gd:1659) e a `DamageZone` só fere no servidor. "O cliente feriu o
#  host" acontece, de verdade, como dano aplicado NESTE processo com a origem
#  no corpo do cliente — que é exatamente o que a fase 2 faz. Quem testa o
#  caminho do input do cliente até a hitbox é o `net_cast_probe`; duplicá-lo
#  aqui só tornaria o teste mais lento e mais frágil sem medir nada novo.
#
#  A fase 4 fecha o outro lado dessa regra: o cliente tentando se ferir sozinho
#  NÃO pode mexer na vida autoritativa. Cliente adulterado não vira dano.
#
#  ---------------------------------------------- DOIS RUIDOS QUE ESTRAGAM ISTO
#  Descobertos medindo, na primeira execucao desta sonda:
#
#  1. O `AutoDummy` PERSEGUE E SOCA. Os 48/54/64/112 do combo (Balance.gd:209)
#     apareceram no meio da contagem e moveram a vida do host sozinhos. Ja e
#     armadilha conhecida do projeto (test_segurar_ataque.gd:149,
#     test_physics.gd:89) — a mesma limpeza vale aqui.
#
#  2. A VIDA REGENERA: 0,5%/s = 10,24 hp/s, caindo para 1,02 hp/s nos 5 s
#     seguintes a um dano (health_controller.gd:110). Medido: a vida do host
#     SUBIU de 1553,9 para 1554,7 entre dois golpes meus.
#
#  A defesa contra os dois esta no desenho, nao numa tolerancia frouxa:
#     • os bonecos vao para y = -1000, congelados e imunes;
#     • a afericao ancora as duas vidas na CHEIA antes de bater. Ancorada no
#       maximo, a regen nao tem para onde subir (`minf(..., vida_max)`), entao
#       a janela antes do golpe fica exata;
#     • depois do golpe os dois corpos estao "em combate", onde a regen vale
#       1,02 hp/s. Do golpe ate a leitura do cliente passam ~3 s = ~3 hp, e a
#       tolerancia de rede (TOL_REDE) cobre isso com folga sem chegar perto do
#       menor golpe aferido (128).
#
#  Rode ANTES do cliente (a porta é fixa e única):
#    godot --headless --path . --script tools/dev_tests/net_dano_host_probe.gd
# ============================================================================

# ---- CONTRATO ENTRE AS DUAS SONDAS (tem que bater com net_dano_client_probe) --
# O host anuncia a fase escrevendo `current_fruit_id` no PRÓPRIO corpo: ele é a
# autoridade dele, e essa é uma das 5 propriedades replicadas (Main.gd:283).
# Mesma técnica do net_mp_probe, na direção contrária.
const FASES := {
	"bara_bara": "1 - O HOST FERE O CLIENTE",
	"hie_hie":   "2 - O CLIENTE FERE O HOST",
	"mera_mera": "3 - TROCA SIMULTANEA",
	"goro_goro": "4 - O CLIENTE TENTA SE FERIR SOZINHO",
	"buki_buki": "FIM",
}
const DANO_NO_CLIENTE  := 300.0
const DANO_NO_HOST     := 450.0
const TROCA_NO_CLIENTE := 128.0
const TROCA_NO_HOST    := 256.0
const VIDA_CHEIA       := 2048.0
# Vida que os DOIS processos devem ver ao fim da aferição (fase 3), que ancora
# na vida cheia e bate uma vez em cada corpo.
const ALVO_CLIENTE := VIDA_CHEIA - TROCA_NO_CLIENTE   # 1920
const ALVO_HOST    := VIDA_CHEIA - TROCA_NO_HOST      # 1792

# Tolerância do delta IMEDIATO (antes/depois no mesmo quadro): nada acontece
# entre as duas leituras, então isto é folga de float e nada mais.
const TOL := 0.5

const ESPERA_BEACON := 3.0      # o beacon leva ~2 s para replicar

var _eu: Node = null            # corpo do host
var _cli: Node = null           # cópia autoritativa do corpo do cliente
var _t0 := 0.0
var _falhas: Array[String] = []
var _linhas: Array[String] = []

# Cada aplicação de dano vira um registro: o que pedi, o que o funil devolveu, e
# o que a vida dos DOIS corpos fez. É a granularidade que separa "dano escalado"
# de "dano no corpo errado".
var _golpes: Array = []

# ⚠️ VALORES, NÃO REFERÊNCIAS. O cliente sai antes de o host fechar o relatório,
# e aí `_cli.health` estoura com "Invalid access on a previously freed object" —
# aconteceu na primeira execução desta sonda, e é o mesmo aviso que o
# net_cast_host_probe já carrega sobre o `name`.
var _cli_nome := ""
var _afericao_cli := -1.0
var _afericao_host := -1.0
var _sofreu_cli := 0.0
var _sofreu_host := 0.0


func _init() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec() / 1000.0
	get_root().get_node("GameFlow").create_room()
	print("[HOST] sala criada — esperando o cliente...")

	for i in 1200:
		await process_frame
		_eu = _corpo("1")
		if _eu != null:
			break
	if _eu == null:
		print("[HOST] ❌ meu proprio corpo nunca apareceu"); quit(2); return

	var esperou := 0
	while _cli == null and esperou < 6000:
		await process_frame
		esperou += 1
		for n in get_nodes_in_group("player"):
			if n.name != "1":
				_cli = n
	if _cli == null:
		print("[HOST] ❌ o cliente nunca conectou"); quit(3); return

	_cli_nome = str(_cli.name)
	print("[HOST][t=%6.2f] cliente conectado — corpos: eu='%s' (%.0f hp)  ele='%s' (%.0f hp)"
		% [_t(), _eu.name, _eu.health, _cli.name, _cli.health])

	_afastar_bonecos()

	# Cola os dois: knockback vai ZERADO, mas um corpo que nasce longe e cai do
	# mapa respawna com a vida cheia e estraga toda a contagem em silêncio.
	_cli.global_position = _eu.global_position + Vector3(0, 0, 3.0)
	await _esperar(1.0)

	# Vida cheia nos dois antes de contar: o cliente pode ter tomado queda ao
	# nascer, e aí a subtração mediria o tombo, não o meu golpe.
	_eu.health = VIDA_CHEIA
	_cli.health = VIDA_CHEIA
	await _esperar(1.0)
	print("[HOST][t=%6.2f] zerado o placar — eu=%.1f  ele=%.1f" % [_t(), _eu.health, _cli.health])

	await _fase_1_host_fere_cliente()
	await _fase_2_cliente_fere_host()
	await _fase_3_afericao()
	await _fase_4_prova_negativa()

	_anunciar("buki_buki")
	await _esperar(ESPERA_BEACON)

	_relatorio()
	quit(0 if _falhas.is_empty() else 1)


# ------------------------------------------------------------------- fases ---
func _fase_1_host_fere_cliente() -> void:
	_anunciar("bara_bara")
	await _esperar(ESPERA_BEACON)
	_bater(_cli, _eu, DANO_NO_CLIENTE, "host -> cliente")
	await _esperar(2.0)


func _fase_2_cliente_fere_host() -> void:
	_anunciar("hie_hie")
	await _esperar(ESPERA_BEACON)
	_bater(_eu, _cli, DANO_NO_HOST, "cliente -> host")
	await _esperar(2.0)


# A AFERIÇÃO. Os dois golpes no MESMO quadro, e é o número que os dois processos
# vão comparar.
#
# Simultâneo não é enfeite: o `CombatResolver` guarda orçamento num dicionário
# estático compartilhado por todos os casts, e dano recíproco no mesmo quadro é
# a situação em que um alvo poderia comer o orçamento do outro.
#
# ⚠️ ANCORAR TEM QUE ATRAVESSAR A REDE. Escrever `health` no servidor NÃO
# replica: a vida do jogador não está no MultiplayerSynchronizer de propósito
# (Player.gd:1655), ela só anda por `net_vida_do_servidor`. Sem o RPC abaixo o
# cliente seguiria com a vida velha e a comparação acusaria um bug que é da
# sonda. Mando com dano 0, que é o caso "restauração" que o respawn já usa.
func _fase_3_afericao() -> void:
	_anunciar("mera_mera")
	await _esperar(ESPERA_BEACON)

	_ancorar(_eu)
	_ancorar(_cli)
	await _esperar(1.0)
	print("[HOST][t=%6.2f] ⚓ ancorado na vida cheia — eu=%.1f  ele=%.1f"
		% [_t(), _eu.health, _cli.health])

	_bater(_cli, _eu, TROCA_NO_CLIENTE, "afericao: host -> cliente")
	_bater(_eu, _cli, TROCA_NO_HOST, "afericao: cliente -> host")

	# Fotografa ANTES de qualquer espera: daqui em diante a regen de combate
	# (1,02 hp/s) já corre, e é ela que a TOL_REDE do cliente vai absorver.
	_afericao_cli = float(_cli.health)
	_afericao_host = float(_eu.health)
	await _esperar(1.0)


# Põe a vida no máximo nos dois lados da rede. No máximo a regen não tem para
# onde subir, então a janela até o golpe é exata.
func _ancorar(corpo: Node) -> void:
	corpo.health = VIDA_CHEIA
	# `multiplayer` é de Node, não de SceneTree — aqui se lê pelo próprio corpo.
	if corpo.multiplayer != null and corpo.multiplayer.has_multiplayer_peer():
		corpo.net_vida_do_servidor.rpc(VIDA_CHEIA, 0.0)


# O cliente chama `take_damage` na cópia LOCAL dele. Aqui a vida autoritativa
# não pode se mexer.
func _fase_4_prova_negativa() -> void:
	_anunciar("goro_goro")
	await _esperar(ESPERA_BEACON)
	var antes: float = _cli.health
	await _esperar(6.0)          # tempo de sobra para o cliente tentar
	var depois: float = _cli.health
	_linhas.append("   fase 4: vida autoritativa do cliente %.1f -> %.1f" % [antes, depois])
	if absf(depois - antes) > TOL:
		_falhas.append("o take_damage LOCAL do cliente mexeu na vida autoritativa (%.1f -> %.1f)"
			% [antes, depois])


# ------------------------------------------------------------------ medicao ---
# Aplica dano pelo FUNIL (CombatResolver.aplicar), que é o único caminho legítimo
# de machucar alguém no jogo. `cast_id = 0` e `teto = 0` = golpe avulso, sem
# orçamento: entrega o valor cheio, que é o que torna a quantia verificável.
func _bater(alvo: Node, atacante: Node, dano: float, rotulo: String) -> void:
	var hp_alvo0: float = alvo.health
	var hp_outro0: float = atacante.health
	var devolvido: float = CombatResolver.aplicar(
		alvo, dano, 0, 0.0, atacante.global_position, Vector3.ZERO, 0.3)
	_golpes.append({
		"rotulo": rotulo,
		"pedido": dano,
		"devolvido": devolvido,
		"alvo": str(alvo.name),
		"queda_alvo": hp_alvo0 - alvo.health,
		"queda_outro": hp_outro0 - atacante.health,
	})
	print("[HOST][t=%6.2f] 🥊 %s — pedi %.1f, funil devolveu %.1f, vida %.1f -> %.1f"
		% [_t(), rotulo, dano, devolvido, hp_alvo0, alvo.health])


func _anunciar(beacon: String) -> void:
	_eu.current_fruit_id = beacon
	print("[HOST][t=%6.2f] 📣 fase '%s' — %s" % [_t(), beacon, FASES.get(beacon, "?")])


# ---------------------------------------------------------------- relatorio ---
func _relatorio() -> void:
	print("\n╔══════════════════════════════════════════════════════════════════╗")
	print("║  DANO RECIPROCO EM REDE — MEDIDO NO PROCESSO DO HOST              ║")
	print("╚══════════════════════════════════════════════════════════════════╝")

	print("\n-- ITEM 1: A QUANTIA QUE CHEGA E A QUANTIA QUE FOI PEDIDA --")
	for g in _golpes:
		var pedido: float = float(g["pedido"])
		var devolvido: float = float(g["devolvido"])
		var queda: float = float(g["queda_alvo"])
		var ok := absf(devolvido - pedido) <= TOL and absf(queda - pedido) <= TOL
		print("   %s  pedido=%.1f  funil=%.1f  vida caiu=%.1f  %s"
			% ["✅" if ok else "❌", pedido, devolvido, queda, g["rotulo"]])
		if absf(devolvido - pedido) > TOL:
			_falhas.append("%s: o funil devolveu %.1f para um pedido de %.1f"
				% [g["rotulo"], devolvido, pedido])
		if absf(queda - pedido) > TOL:
			_falhas.append("%s: pedi %.1f de dano e a vida caiu %.1f"
				% [g["rotulo"], pedido, queda])

	print("\n-- ITEM 2: O DANO NAO VAZA PARA O CORPO ERRADO --")
	var vazou := false
	for g in _golpes:
		if absf(float(g["queda_outro"])) > TOL:
			vazou = true
			print("   ❌ %s: o ATACANTE tambem perdeu %.1f de vida"
				% [g["rotulo"], float(g["queda_outro"])])
			_falhas.append("%s feriu o proprio atacante (%.1f)"
				% [g["rotulo"], float(g["queda_outro"])])
	if not vazou:
		print("   ✅ em todos os %d golpes so o alvo perdeu vida" % _golpes.size())

	print("\n-- ITEM 3: RECIPROCIDADE (os DOIS apanharam nesta partida) --")
	# Somado dos golpes, não da vida final: a vida final anda sozinha (regen), e
	# o que a reciprocidade pergunta é se cada corpo recebeu dano DO OUTRO.
	for g in _golpes:
		if str(g["alvo"]) == _cli_nome:
			_sofreu_cli += float(g["queda_alvo"])
		else:
			_sofreu_host += float(g["queda_alvo"])
	print("   cliente '%s' recebeu %.1f de dano do host" % [_cli_nome, _sofreu_cli])
	print("   host    recebeu %.1f de dano do cliente" % _sofreu_host)
	if _sofreu_cli <= 0.0 or _sofreu_host <= 0.0:
		print("   ❌ um dos dois saiu ileso — nao houve troca")
		_falhas.append("faltou reciprocidade: cliente recebeu %.1f, host recebeu %.1f"
			% [_sofreu_cli, _sofreu_host])
	else:
		print("   ✅ os dois corpos apanharam, cada um por causa do outro")

	print("\n-- ITEM 4: A AFERICAO NA COPIA AUTORITATIVA --")
	print("   (o processo do CLIENTE confere estes MESMOS dois numeros)")
	_conferir("cliente", _afericao_cli, ALVO_CLIENTE)
	_conferir("host", _afericao_host, ALVO_HOST)

	print("\n-- ITEM 5: O CLIENTE NAO SE FERE SOZINHO --")
	for l in _linhas:
		print(l)
	print("   %s" % ("✅ a vida autoritativa ignorou o take_damage local do cliente"
		if _falhas.filter(func(f): return f.begins_with("o take_damage")).is_empty()
		else "❌ o cliente conseguiu mexer na propria vida autoritativa"))

	print("\n(o mesmo par de vidas e conferido no processo do CLIENTE — se lá")
	print(" divergir, o dano do servidor nao atravessou a rede)")
	if _falhas.is_empty():
		print("\n✅ DANO RECIPROCO OK")
	else:
		print("\n❌ %d FALHA(S)" % _falhas.size())
		for f in _falhas:
			print("   ✗ %s" % f)


func _conferir(quem: String, vida: float, alvo: float) -> void:
	if absf(vida - alvo) <= TOL:
		print("   ✅ %-8s vida = %.1f (esperado %.1f)" % [quem, vida, alvo])
	else:
		print("   ❌ %-8s vida = %.1f, esperado %.1f (Δ %.1f)" % [quem, vida, alvo, vida - alvo])
		_falhas.append("vida final do %s: %.1f, esperado %.1f" % [quem, vida, alvo])


# Tira TODO boneco/inimigo do caminho antes de medir. Mesma receita do
# `test_segurar_ataque._afastar_bonecos` — ver a nota 1 do cabeçalho.
func _afastar_bonecos() -> void:
	var n := 0
	for e in get_nodes_in_group("enemy"):
		if e is Node3D:
			e.set_meta("is_frozen", true)
			e.set_meta("damage_immune", true)
			(e as Node3D).global_position = Vector3(0, -1000, 0)
			n += 1
	print("[HOST] %d boneco(s) afastado(s) — o AutoDummy soca sozinho e move a vida" % n)


# ---------------------------------------------------------------- auxiliares ---
func _corpo(nome: String) -> Node:
	for n in get_nodes_in_group("player"):
		if n.name == nome:
			return n
	return null


func _t() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0


func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
