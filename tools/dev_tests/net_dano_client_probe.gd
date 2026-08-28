extends SceneTree
# ============================================================================
#  SONDA DE DANO RECÍPROCO — LADO CLIENTE (2 processos). É a TESTEMUNHA.
#
#  Quem aplica o dano é o host: a vida é do servidor e a `DamageZone` só fere
#  lá. Este processo existe para responder a pergunta que o host NÃO consegue
#  responder sozinho — "a vida que o servidor calculou chegou até aqui?".
#
#  É o bug de 2026-08-12 em forma de teste: a vítima morria com a BARRA CHEIA
#  na tela dela porque `health` não é replicado pelo MultiplayerSynchronizer (a
#  autoridade do corpo é o cliente, e pôr a vida lá deixaria cliente adulterado
#  imortal — Player.gd:1655). A vida atravessa por RPC, `net_vida_do_servidor`,
#  e RPC é justamente o que um teste de um processo só não exercita.
#
#  As DUAS vidas são conferidas aqui, e por motivos diferentes:
#    • a minha ....... o RPC chegou em quem apanhou;
#    • a do host ..... eu vejo o ADVERSÁRIO apanhar (o item 20 do plano: sem
#                      isso a barra do outro fica cheia enquanto ele morre).
#
#  Rode DEPOIS do host estar no ar:
#    godot --headless --path . --script tools/dev_tests/net_dano_client_probe.gd
# ============================================================================

# ---- CONTRATO ENTRE AS DUAS SONDAS (tem que bater com net_dano_host_probe) ----
# ⚠️ Estes números são a cópia do contrato, não uma segunda fonte de verdade. Se
# mudarem lá, mudam aqui — é o preço de dois processos sem memória compartilhada,
# e o mesmo arranjo que o net_mp_probe usa para as fases.
const F_HOST_FERE   := "bara_bara"
const F_CLI_FERE    := "hie_hie"
const F_TROCA       := "mera_mera"
const F_PROVA       := "goro_goro"
const F_FIM         := "buki_buki"

const VIDA_CHEIA       := 2048.0
# Fases 1 e 2: golpes de sentido único, julgados pelo host (delta imediato).
# Aqui só entram no log, para os dois relatórios contarem a mesma história.
const DANO_NO_CLIENTE  := 300.0
const DANO_NO_HOST     := 450.0
const TROCA_NO_CLIENTE := 128.0
const TROCA_NO_HOST    := 256.0
# A fase 3 ancora as duas vidas na CHEIA e bate uma vez em cada corpo. É esse
# par de números que os dois processos comparam.
const ALVO_CLIENTE := VIDA_CHEIA - TROCA_NO_CLIENTE   # 1920
const ALVO_HOST    := VIDA_CHEIA - TROCA_NO_HOST      # 1792

# Medindo o DEGRAU (ver `_seguir_o_degrau`), a leitura acontece no mesmo quadro
# da queda: não há janela para a regeneração entrar, e a tolerância volta a ser
# folga de float. Um teto frouxo aqui esconderia justamente o que o teste mede.
const TOL := 0.5

# Queda mínima para contar como golpe. A regen entra em décimos de hp por quadro;
# o menor golpe aferido é 128.
const DEGRAU_MIN := 20.0
const DANO_FANTASMA := 999.0    # o que eu tento me causar sozinho, na fase 4
const TETO_FASE := 90.0         # espera máxima por um beacon

var _p: Node = null             # meu corpo (autoridade minha)
var _host: Node = null          # corpo do host (cópia remota, aqui)
var _t0 := 0.0
var _falhas: Array[String] = []

# Snapshot tirado no fim da fase 3, ANTES de eu sujar a minha vida local na
# fase 4. Julgar depois mediria o meu próprio `take_damage` de mentira.
var _vi_minha := -1.0
var _vi_do_host := -1.0
var _minha_antes_da_prova := -1.0


func _init() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec() / 1000.0
	var gf := get_root().get_node("GameFlow")
	print("[CLI] conectando em 127.0.0.1 ...")
	if not gf.join_room("127.0.0.1"):
		print("[CLI] ❌ join_room falhou"); quit(2); return

	var meu_id := 0
	for i in 1800:
		await process_frame
		meu_id = root.multiplayer.get_unique_id()
		_p = _corpo(str(meu_id))
		if _p != null:
			break
	if _p == null:
		print("[CLI] ❌ meu corpo nunca apareceu (id=%d)" % meu_id); quit(3); return

	for i in 900:
		await process_frame
		_host = _corpo("1")
		if _host != null:
			break
	if _host == null:
		print("[CLI] ❌ nao achei o corpo do host — sem ele nao da pra conferir a vida dele")
		quit(3); return
	print("[CLI][t=%6.2f] meu corpo='%s' (peer %d)  |  corpo do host='%s'"
		% [_t(), _p.name, meu_id, _host.name])

	if not await _esperar_fase(F_HOST_FERE):  return
	print("[CLI][t=%6.2f] fase 1 — devo apanhar %.0f" % [_t(), DANO_NO_CLIENTE])

	if not await _esperar_fase(F_CLI_FERE):   return
	print("[CLI][t=%6.2f] fase 2 — o host deve apanhar %.0f" % [_t(), DANO_NO_HOST])

	if not await _esperar_fase(F_TROCA):      return
	print("[CLI][t=%6.2f] fase 3 — afericao (ancora na vida cheia + um golpe em cada)" % _t())

	# ⚠️ MEDE O DEGRAU, NAO O ESTADO TARDIO.
	#
	# Fotografar a vida quando o host anuncia a proxima fase parecia bastar, e
	# nao basta: MEU corpo tem autoridade AQUI, entao o `_physics_process` dele
	# roda e regenera localmente. Pior, `net_vida_do_servidor` nao mexe no
	# `_t_ultimo_dano` desta copia — ela nao sabe que acabou de apanhar e
	# regenera a 10,24 hp/s em vez dos 1,02 hp/s da penalidade de combate.
	# Medido: 1930,2 onde o servidor tinha 1920,0, enquanto o corpo do host
	# (copia remota, que nao regenera aqui) batia exato.
	#
	# O que este teste quer saber e "o dano que o servidor calculou chegou ate
	# mim", e essa resposta esta no DEGRAU — o valor no quadro em que a vida
	# cai. O que a vida faz depois e outro assunto, medido a parte no item D.
	await _seguir_o_degrau()

	# Fase 4: tento me ferir sozinho. Se isto subir para o servidor, cliente
	# adulterado vira dano — e o host acusa.
	_minha_antes_da_prova = float(_p.health)
	print("[CLI][t=%6.2f] 🧪 chamando take_damage(%.0f) na MINHA copia local"
		% [_t(), DANO_FANTASMA])
	_p.take_damage(DANO_FANTASMA)
	await _esperar(2.0)
	print("[CLI][t=%6.2f] minha vida local depois da tentativa: %.1f" % [_t(), float(_p.health)])

	if not await _esperar_fase(F_FIM):        return
	_relatorio()
	quit(0 if _falhas.is_empty() else 1)


# ---------------------------------------------------------------- relatorio ---
func _relatorio() -> void:
	print("\n╔══════════════════════════════════════════════════════════════════╗")
	print("║  DANO RECIPROCO EM REDE — MEDIDO NO PROCESSO DO CLIENTE           ║")
	print("╚══════════════════════════════════════════════════════════════════╝")

	print("\n-- ITEM A: A VIDA DO SERVIDOR CHEGOU EM MIM --")
	_conferir("a minha vida", _vi_minha, ALVO_CLIENTE,
		"apanhei e a barra ficou cheia aqui — o net_vida_do_servidor nao chegou")

	print("\n-- ITEM B: EU VEJO O ADVERSARIO APANHAR --")
	_conferir("a vida do host", _vi_do_host, ALVO_HOST,
		"a barra do host ficou parada na minha tela enquanto ele apanhava")

	print("\n-- ITEM D: QUANTO A MINHA COPIA ANDOU SOZINHA DEPOIS DO GOLPE --")
	# Não é assertion: é o número que explica por que o item A mede o degrau.
	# Se um dia isto ficar perto de zero, a cópia do dono passou a respeitar a
	# penalidade de combate — e aí o item A pode voltar a ler a vida tardia.
	var deriva: float = _minha_antes_da_prova - _vi_minha
	print("   degrau do golpe ..: %.1f" % _vi_minha)
	print("   vida ~2 s depois .: %.1f  (andou %+.1f)" % [_minha_antes_da_prova, deriva])
	if deriva > 1.0:
		print("   ℹ️  a minha copia regenerou %.1f hp que o servidor NAO deu." % deriva)
		print("      `net_vida_do_servidor` nao mexe no `_t_ultimo_dano` desta copia,")
		print("      entao ela nao sabe que apanhou e regenera a 10,24 hp/s em vez de")
		print("      1,02. O servidor corrige no proximo dano; ate la a barra na minha")
		print("      tela mostra mais vida do que eu tenho.")

	print("\n-- ITEM C: O QUE EU TENTEI FAZER SOZINHO --")
	print("   chamei take_damage(%.0f) na minha copia local; a vida local foi de %.1f para %.1f."
		% [DANO_FANTASMA, _minha_antes_da_prova, float(_p.health)])
	print("   quem julga se isso vazou para a copia autoritativa e o processo do HOST.")

	if _falhas.is_empty():
		print("\n✅ A VIDA ATRAVESSOU A REDE NOS DOIS SENTIDOS")
	else:
		print("\n❌ %d FALHA(S)" % _falhas.size())
		for f in _falhas:
			print("   ✗ %s" % f)


func _conferir(quem: String, vista: float, alvo: float, sintoma: String) -> void:
	if vista < 0.0:
		# Nenhuma QUEDA foi vista nesta cópia durante a aferição. É a assinatura
		# exata do bug de 2026-08-12: o servidor bateu, o host viu a vida cair, e
		# aqui não chegou nada. Confirmado sabotando o `net_vida_do_servidor.rpc`
		# — o host segue passando e só este processo acusa.
		print("   ❌ %s nunca caiu aqui — o dano do servidor nao chegou nesta copia" % quem)
		print("      sintoma no jogo: %s" % sintoma)
		_falhas.append("%s: nenhum degrau de dano chegou" % quem)
		return
	if absf(vista - alvo) <= TOL:
		print("   ✅ %s = %.1f (esperado %.1f)" % [quem, vista, alvo])
	else:
		print("   ❌ %s = %.1f, esperado %.1f (Δ %.1f)" % [quem, vista, alvo, vista - alvo])
		print("      sintoma no jogo: %s" % sintoma)
		_falhas.append("%s: vi %.1f, esperado %.1f" % [quem, vista, alvo])


# Acompanha as duas vidas quadro a quadro ate o host anunciar a fase seguinte, e
# guarda o valor logo apos cada QUEDA. A ancoragem tambem mexe na vida, mas para
# CIMA (vida cheia), entao nao se confunde com golpe.
func _seguir_o_degrau() -> void:
	var limite := Time.get_ticks_msec() + int(TETO_FASE * 1000.0)
	var ant_minha: float = float(_p.health)
	var ant_host: float = float(_host.health)
	while Time.get_ticks_msec() < limite:
		await process_frame
		if not is_instance_valid(_host) or not is_instance_valid(_p):
			return
		var h_minha: float = float(_p.health)
		var h_host: float = float(_host.health)
		# DEGRAU_MIN filtra a regen (decimos de hp por quadro) sem chegar perto
		# do menor golpe aferido (128).
		if ant_minha - h_minha >= DEGRAU_MIN:
			_vi_minha = h_minha
			print("[CLI][t=%6.2f] 📉 minha vida caiu %.1f -> %.1f" % [_t(), ant_minha, h_minha])
		if ant_host - h_host >= DEGRAU_MIN:
			_vi_do_host = h_host
			print("[CLI][t=%6.2f] 📉 vida do host caiu %.1f -> %.1f" % [_t(), ant_host, h_host])
		ant_minha = h_minha
		ant_host = h_host
		if str(_host.current_fruit_id) == F_PROVA:
			return


# ---------------------------------------------------------------- auxiliares ---
# Espera o host anunciar uma fase. O beacon é o `current_fruit_id` do corpo DELE,
# que replica até aqui porque a autoridade daquele corpo é o host.
func _esperar_fase(beacon: String) -> bool:
	var limite := Time.get_ticks_msec() + int(TETO_FASE * 1000.0)
	while Time.get_ticks_msec() < limite:
		await process_frame
		if not is_instance_valid(_host):
			print("[CLI] ❌ o corpo do host sumiu enquanto eu esperava '%s'" % beacon)
			quit(4)
			return false
		if str(_host.current_fruit_id) == beacon:
			return true
	print("[CLI] ❌ o host nunca anunciou a fase '%s' (esperei %.0f s)" % [beacon, TETO_FASE])
	quit(5)
	return false


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
