extends SceneTree
# ============================================================================
#  SONDA MULTIPLAYER GERAL — LADO CLIENTE (2 processos). É quem AGE.
#
#  Roteiro. Cada fase é ANUNCIADA ao host escrevendo `current_fruit_id` (uma das
#  5 propriedades replicadas — Main.gd:119). Não há relógio combinado: o host
#  fatia o tempo por essas trocas, como o `net_buki_host_probe.gd` faz.
#
#    1  MOVIMENTO      anda 12 m em linha reta; o host mede a cópia dele    [1]
#    2A MORTE POR DANO fica parado enquanto o SERVIDOR o mata a golpes      [2]
#    2B MORTE POR QUEDA se joga abaixo do VOID_Y e espera o servidor        [2]
#    3  ENERGIA        zera a própria energia e mede a subida               [3]
#    4  RECARGA        conjura Z, X e C e cronometra a liberação do slot    [4]
#    5  RECARGA+MORTE  conjura C, morre no meio e mede o que sobra          [5]
#    6  VIDA           toma dano e mede a vida ao longo do tempo            [6]
#
#  ⚠️ Headless não captura mouse (`MOUSE_MODE_CAPTURED` é sempre falso), então
#  nada aqui passa por `Input`: a locomoção real nunca sai do lugar. Para andar,
#  a sonda ESCREVE `global_position` a cada quadro — que é o mesmo campo
#  replicado, então o caminho de rede exercitado é o de verdade.
#
#  ⚠️ Uma sonda ocupa o lugar da HUD (grupo "hud") o teste inteiro. É por ela que
#  se sabe quantos avisos de dano o DONO do corpo recebeu — a resposta é uma das
#  descobertas do relatório.
#
#  Rode DEPOIS do host estar no ar (porta 24565 é fixa e única):
#    godot --headless --path . --script tools/dev_tests/net_mp_client_probe.gd
# ============================================================================

# ---- CONTRATO ENTRE AS DUAS SONDAS (tem que bater com o net_mp_host_probe) ----
const F_MOV := "gomu_gomu"
const F_DANO := "bara_bara"
const F_QUEDA := "hie_hie"
const F_ENERGIA := "goro_goro"
const F_RECARGA := "mera_mera"
const F_RECARGA_MORTE := "gura_gura"
const F_VIDA := "yami_yami"
const F_FIM := "buki_buki"

const MOV_INICIO := Vector3(-6.0, 30.0, 0.0)
const MOV_FIM := Vector3(6.0, 30.0, 0.0)
const MOV_VEL := 3.0            # m/s — velocidade de caminhada
# y=30 de propósito: acima dos 90 blocos do mapa e MUITO acima do VOID_Y. O que
# se mede aqui é replicação de posição, não colisão — um bloco no caminho viraria
# ruído sem relação com a rede.

const ESPERA_BEACON := 3.0      # o `current_fruit_id` leva ~2 s para replicar
const ESPERA_MORTE := 6.0       # `Scoreboard._dead_until` trava recontagem por 2 s

var _p: Node = null             # MEU corpo (sou a autoridade dele)
var _host: Node = null          # corpo do host, replicado até aqui
var _t0 := 0.0
var _falhas := 0
var _sonda: Node = null
var _recargas: Dictionary = {}  # slot -> tempo medido até liberar
var _tabela: Dictionary = {}    # RECARGA_POR_SLOT lida do próprio Player.gd

# Sonda que ocupa o lugar da HUD. O Player fala com ela pelo grupo "hud" e por
# `has_method`, exatamente como fala com a HUD de verdade (técnica do test_morte).
class SondaHud extends Node:
	var eventos: Array = []      # [dano, vida_no_instante, vida_max]

	func on_player_damaged(amount: float, hp: float, mhp: float) -> void:
		eventos.append([amount, hp, mhp])

	func zerar() -> void:
		eventos = []


func _init() -> void:
	await process_frame
	_t0 = _agora()
	var gf := get_root().get_node("GameFlow")
	print("[CLI] conectando em 127.0.0.1 ...")
	if not gf.join_room("127.0.0.1"):
		print("[CLI] ❌ join_room falhou — o host está no ar?")
		quit(2)
		return

	var meu_id := 0
	for i in 1800:
		await process_frame
		meu_id = root.multiplayer.get_unique_id()
		_p = _corpo(str(meu_id))
		if _p != null:
			break
	if _p == null:
		print("[CLI] ❌ meu corpo nunca apareceu (id=%d). Grupo player: %s"
			% [meu_id, str(get_nodes_in_group("player").map(func(n): return n.name))])
		quit(3)
		return
	for i in 600:
		await process_frame
		_host = _corpo("1")
		if _host != null:
			break
	print("[CLI] meu corpo='%s' (peer %d) | corpo do host='%s'"
		% [_p.name, meu_id, _host.name if _host else "<NÃO ACHEI>"])
	print("[CLI] vida=%.0f/%.0f  energia=%.0f/%.0f  fruta de nascença='%s'"
		% [float(_p.health), float(_p.max_health), float(_p.energy),
			float(_p.max_energy), str(_p.current_fruit_id)])

	# A tabela de recargas vem do PRÓPRIO Player.gd. `Player` não tem
	# `class_name`, então `Player.RECARGA_POR_SLOT` não compila aqui — o mapa de
	# constantes do script é o caminho honesto (o teste não pode ter a sua cópia
	# da tabela: ela envelheceria em silêncio).
	var mapa: Dictionary = _p.get_script().get_script_constant_map()
	_tabela = mapa.get("RECARGA_POR_SLOT", {})
	print("[CLI] RECARGA_POR_SLOT lida do Player.gd: %s" % str(_tabela))
	print("[CLI] REGEN_ENERGIA = %.0f/s (HealthController)" % HealthController.REGEN_ENERGIA)

	# A sonda entra no lugar da HUD e fica lá o teste inteiro.
	var hud_real = get_first_node_in_group("hud")
	_sonda = SondaHud.new()
	_sonda.name = "SondaHudRede"
	current_scene.add_child(_sonda)
	_sonda.add_to_group("hud")
	if hud_real != null:
		hud_real.remove_from_group("hud")
	await process_frame
	print("[CLI] sonda de dano no lugar da HUD: %s\n" % str(get_first_node_in_group("hud") == _sonda))

	await _fase_movimento()
	await _fase_morte_por_dano()
	await _fase_morte_por_queda()
	await _fase_energia()
	await _fase_recarga()
	await _fase_recarga_apos_morte()
	await _fase_vida()

	await _marcar(F_FIM)
	print("\n[CLI] ===== %s =====" % ("TUDO OK DO LADO DO DONO" if _falhas == 0 else "%d FALHA(S) do lado do dono" % _falhas))
	print("[CLI] (o processo do HOST fecha o relatório da cópia autoritativa)")
	await _esperar(2.0)
	quit(1 if _falhas > 0 else 0)


# ============================================================ 1 · MOVIMENTAÇÃO
func _fase_movimento() -> void:
	print("\n[CLI] ===== FASE 1: MOVIMENTAÇÃO REPLICA =====")
	await _marcar(F_MOV)
	_p.velocity = Vector3.ZERO
	_p.global_position = MOV_INICIO
	await _esperar(1.5)              # deixa a posição de partida chegar no host

	var dir: Vector3 = (MOV_FIM - MOV_INICIO).normalized()
	var total: float = MOV_INICIO.distance_to(MOV_FIM)
	var t_ini := _agora()
	var percorrido := 0.0
	var ult: Vector3 = _p.global_position
	var quadros := 0
	while percorrido < total - 0.0001:
		await process_frame
		Engine.time_scale = 1.0
		var d: float = minf((_agora() - t_ini) * MOV_VEL, total)
		# Escreve posição E zera velocidade: sem isso a gravidade acumula em
		# `velocity.y` e o `move_and_slide` do quadro seguinte puxa o corpo pra
		# baixo entre uma escrita e outra.
		_p.velocity = Vector3.ZERO
		_p.global_position = MOV_INICIO + dir * d
		var agora_pos: Vector3 = _p.global_position
		percorrido += Vector2(agora_pos.x - ult.x, agora_pos.z - ult.z).length()
		ult = agora_pos
		quadros += 1
	var dt := _agora() - t_ini
	var fim: Vector3 = _p.global_position
	print("   [dono] andei %.3f m em %.2f s (%d escritas de posição, %.2f m/s)"
		% [percorrido, dt, quadros, percorrido / maxf(dt, 0.001)])
	print("   [dono] de %s até %s (erro do alvo: %.4f m)"
		% [_v(MOV_INICIO), _v(fim), Vector2(fim.x - MOV_FIM.x, fim.z - MOV_FIM.z).length()])
	_ok(absf(percorrido - total) < 0.05,
		"o DONO percorreu %.3f m dos %.2f m combinados (erro %+.4f m)" % [percorrido, total, percorrido - total])
	# Fica parado 2,5 s para o host ver a posição ASSENTAR antes de trocar de fase.
	for i in 300:
		await process_frame
		Engine.time_scale = 1.0
		_p.velocity = Vector3.ZERO
		_p.global_position = MOV_FIM
	await _esperar(2.0)


# ========================================================= 2A · MORTE POR DANO
# Quem mata é o SERVIDOR: a `DamageZone` roda lá e o `health` NÃO está na lista
# de propriedades replicadas (Main.gd:119). Então aqui eu só espero — e meço o
# que o dono do corpo consegue perceber, que é a descoberta desta fase.
func _fase_morte_por_dano() -> void:
	print("\n[CLI] ===== FASE 2A: MORTE POR DANO (quem bate é o servidor) =====")
	# Longe do RESPAWN e DENTRO do raio seguro da plataforma (SAFE_RADIUS=16 no
	# MapBuilder: nenhum buraco por perto), senão uma queda acidental contaminaria
	# a morte por DANO que é o que se quer medir aqui.
	_p.velocity = Vector3.ZERO
	_p.global_position = Vector3(12.0, 8.0, 0.0)
	_p.health = _p.max_health
	await _esperar(1.5)
	_sonda.zerar()
	# O anúncio e o laço de medição colam de propósito: o host bate 4 s depois de
	# ver o beacon, e a medição precisa já estar aberta quando isso acontecer.
	_p.current_fruit_id = F_DANO
	print("[CLI][t=%6.2f] 📣 anunciei a fase '%s' e já entro no laço de medição" % [_t(), F_DANO])

	var hp0: float = float(_p.health)
	var pos0: Vector3 = _p.global_position
	var fruta0: String = str(_p.current_fruit_id)
	var hp_min := hp0
	var respawnou := false
	var t_ini := _agora()
	var t_respawn := -1.0
	while _agora() - t_ini < 18.0:
		await process_frame
		Engine.time_scale = 1.0
		hp_min = minf(hp_min, float(_p.health))
		# Distância em XZ: depois do teleporte para o RESPAWN a gravidade leva o
		# corpo até o chão (y=0), e uma distância 3D passaria dos 3 m só por isso.
		var dxz: float = Vector2(_p.global_position.x - Scoreboard.RESPAWN.x,
			_p.global_position.z - Scoreboard.RESPAWN.z).length()
		if not respawnou and dxz < 2.0:
			respawnou = true
			t_respawn = _agora() - t_ini
			print("   [dono] 💀 respawnei em %s aos %.2f s (vinha de %s)"
				% [_v(_p.global_position), t_respawn, _v(pos0)])
	var dxz_fim: float = Vector2(_p.global_position.x - Scoreboard.RESPAWN.x,
		_p.global_position.z - Scoreboard.RESPAWN.z).length()
	print("   [dono] vida: %.1f -> mínimo lido %.1f -> %.1f agora" % [hp0, hp_min, float(_p.health)])
	print("   [dono] energia agora: %.1f/%.1f | fruta: '%s' -> '%s'"
		% [float(_p.energy), float(_p.max_energy), fruta0, str(_p.current_fruit_id)])
	print("   [dono] avisos de dano que a HUD recebeu nesta fase: %d" % _sonda.eventos.size())
	_ok(respawnou, "o servidor me fez respawnar (distância XZ do RESPAWN = %.2f m, aos %.2f s)"
		% [dxz_fim, t_respawn])
	_ok(str(_p.current_fruit_id) == "",
		"o respawn devolveu a fruta à árvore ('%s' -> '%s')" % [fruta0, str(_p.current_fruit_id)])
	_ok(float(_p.health) == float(_p.max_health),
		"depois do respawn a vida está cheia (%.1f)" % float(_p.health))

	print("\n   ⚠️ ACHADO (relatado, NÃO corrigido) — o DONO nunca vê o próprio dano:")
	print("      vida mínima que o dono leu durante a morte inteira: %.1f de %.1f" % [hp_min, hp0])
	print("      avisos `on_player_damaged` recebidos: %d" % _sonda.eventos.size())
	print("      `health`/`energy` não estão no SceneReplicationConfig (Main.gd:119) e não têm RPC.")
	print("      A barra de vida do jogador atacado NÃO se mexe em partida de 2 PCs: ele morre")
	print("      com a barra cheia. O único sinal que chega é o teleporte do respawn.")
	await _esperar(ESPERA_MORTE)


# ======================================================== 2B · MORTE POR QUEDA
func _fase_morte_por_queda() -> void:
	print("\n[CLI] ===== FASE 2B: MORTE POR QUEDA (y < VOID_Y = %.1f) =====" % Scoreboard.VOID_Y)
	await _marcar(F_QUEDA)
	_sonda.zerar()
	var alvo := Vector3(0.0, Scoreboard.VOID_Y - 20.0, 0.0)
	_p.velocity = Vector3.ZERO
	_p.global_position = alvo
	print("   [dono] me joguei em %s (%.1f m abaixo do VOID_Y)"
		% [_v(alvo), Scoreboard.VOID_Y - alvo.y])

	var t_ini := _agora()
	var t_respawn := -1.0
	var hp_min: float = float(_p.health)
	while _agora() - t_ini < 20.0:
		await process_frame
		Engine.time_scale = 1.0
		hp_min = minf(hp_min, float(_p.health))
		# Sair do vazio é o sinal: `net_force_respawn` põe o corpo no RESPAWN e a
		# gravidade o desce até o chão logo em seguida — comparar com o ponto de
		# respawn em 3D erraria por causa dessa queda de 6 m.
		if t_respawn < 0.0 and _p.global_position.y > Scoreboard.VOID_Y:
			t_respawn = _agora() - t_ini
			print("   [dono] 🛬 respawnei em %s aos %.2f s" % [_v(_p.global_position), t_respawn])
			break
	print("   [dono] vida durante a queda: mínimo %.1f (entrei com %.1f)" % [hp_min, float(_p.max_health)])
	print("   [dono] avisos de dano na queda: %d (queda mata por POSIÇÃO, não por dano)" % _sonda.eventos.size())
	_ok(t_respawn >= 0.0, "o servidor mandou respawnar depois da queda (%.2f s)" % t_respawn)
	_ok(_sonda.eventos.size() == 0, "a queda matou SEM aplicar dano (%d eventos)" % _sonda.eventos.size())
	await _esperar(ESPERA_MORTE)


# ============================================================= 3 · REGEN DE ENERGIA
# ⚠️ A regen SÓ roda na AUTORIDADE: ela mora no `_etapa_estado_de_combate`, que o
# `_physics_process` só alcança depois do `if not _is_authority: return`
# (Player.gd:682). Medir na cópia do host acusaria um bug que não existe — por
# isso a subida é medida AQUI, no dono, e a prova negativa (cópia parada) é a
# sonda do host que faz.
func _fase_energia() -> void:
	print("\n[CLI] ===== FASE 3: REGENERAÇÃO DE ENERGIA (medida no DONO) =====")
	await _marcar(F_ENERGIA)
	await _esperar(1.0)

	_p.energy = 0.0
	var t_ini := _agora()
	var amostras: Array = []
	while _agora() - t_ini < 6.0:
		await process_frame
		Engine.time_scale = 1.0
		var e: float = float(_p.energy)
		amostras.append([_agora() - t_ini, e])
		if e >= float(_p.max_energy):
			break
	var t_fim: float = float(amostras[-1][0])
	var e_fim: float = float(amostras[-1][1])
	print("   [dono] energia 0 -> %.1f em %.3f s (teto = %.0f)" % [e_fim, t_fim, float(_p.max_energy)])
	# Amostra em 5 pontos só para o número não ser um único par de leituras.
	for frac in [0.2, 0.4, 0.6, 0.8, 1.0]:
		var idx: int = mini(int(amostras.size() * frac) - 1, amostras.size() - 1)
		if idx < 0:
			continue
		var ta: float = float(amostras[idx][0])
		var ea: float = float(amostras[idx][1])
		print("      t=%.3f s  energia=%8.1f   taxa acumulada=%.1f/s" % [ta, ea, ea / maxf(ta, 0.0001)])
	# A taxa medida usa o trecho ANTES do teto (senão o platô puxa a média pra baixo).
	var i_meio: int = int(amostras.size() * 0.5)
	var t_m: float = float(amostras[i_meio][0])
	var e_m: float = float(amostras[i_meio][1])
	var taxa: float = e_m / maxf(t_m, 0.0001)
	var esperado: float = HealthController.REGEN_ENERGIA
	print("   [dono] TAXA MEDIDA no meio da subida: %.1f/s (esperado %.1f/s, erro %+.2f%%)"
		% [taxa, esperado, (taxa - esperado) / esperado * 100.0])
	print("   [dono] tempo teórico do 0 ao teto: %.2f s | tempo medido até %.0f: %.3f s"
		% [float(_p.max_energy) / esperado, e_fim, t_fim])
	_ok(e_fim > 0.0, "a energia SUBIU sozinha no dono (0 -> %.1f)" % e_fim)
	_ok(absf(taxa - esperado) / esperado < 0.10,
		"a taxa medida (%.1f/s) bate com REGEN_ENERGIA=%.0f/s dentro de 10%%" % [taxa, esperado])
	await _esperar(1.0)


# ============================================================ 4 · RECARGA DE SKILL
func _fase_recarga() -> void:
	print("\n[CLI] ===== FASE 4: RECARGA DE SKILL =====")
	_p.combat_mode = "fruit"
	_p.equip_fruit(F_RECARGA)        # equipar JÁ é o anúncio: escreve current_fruit_id
	await _esperar(ESPERA_BEACON)
	print("   [dono] fruta='%s' combat_mode='%s'" % [str(_p.current_fruit_id), str(_p.combat_mode)])
	# Perto do host: cast que erra tudo não prova nada sobre o caminho de rede.
	if _host != null:
		_p.global_position = _host.global_position + Vector3(0, 0, 4.0)
	await _esperar(0.5)

	for slot in ["Z", "X", "C"]:
		var esperado: float = float(_tabela.get(slot, 0.0))
		_zerar_recargas()
		_p.energy = _p.max_energy
		await process_frame
		var t_ini := _agora()
		_p.cast_skill_slot(slot)
		var logo_apos: float = float(_p._skill_cooldowns[slot])
		print("   -> cast_skill_slot('%s'): recarga escrita = %.2f s (tabela diz %.1f)"
			% [slot, logo_apos, esperado])
		var liberou := -1.0
		while _agora() - t_ini < esperado + 15.0:
			await process_frame
			Engine.time_scale = 1.0
			if float(_p._skill_cooldowns[slot]) <= 0.0:
				liberou = _agora() - t_ini
				break
		_recargas[slot] = liberou
		var erro: float = liberou - esperado
		print("      slot '%s' liberou em %.3f s (esperado %.1f s, erro %+.3f s)" % [slot, liberou, esperado, erro])
		_ok(absf(logo_apos - esperado) < 0.01,
			"a recarga de '%s' foi ARMADA em %.2f s (RECARGA_POR_SLOT diz %.1f)" % [slot, logo_apos, esperado])
		_ok(liberou > 0.0 and absf(erro) < 0.6,
			"o slot '%s' ficou indisponível %.3f s — %.1f s esperados (erro %+.3f s)" % [slot, liberou, esperado, erro])

	# V = 60 s. Medir a espera inteira somaria 1 minuto morto ao teste sem provar
	# nada novo — o mecanismo é o mesmo de Z/X/C. Meço só o valor ARMADO.
	_zerar_recargas()
	_p.trigger_skill_cooldown("V")
	var v_armado: float = float(_p._skill_cooldowns["V"])
	print("   -> 'V' (ultimate): recarga armada = %.2f s (tabela diz %.1f) — NÃO esperei os %.0f s"
		% [v_armado, float(_tabela.get("V", 0.0)), float(_tabela.get("V", 0.0))])
	_ok(absf(v_armado - float(_tabela.get("V", 0.0))) < 0.01,
		"a recarga de 'V' foi armada em %.2f s" % v_armado)
	_zerar_recargas()
	await _esperar(1.0)


# ================================================== 5 · RECARGA DEPOIS DA MORTE
# DESCOBERTA, não validação: não presumo qual é o comportamento certo. Conjuro,
# morro no meio da recarga e TRANSCREVO o que acontece com o contador.
func _fase_recarga_apos_morte() -> void:
	print("\n[CLI] ===== FASE 5: O QUE ACONTECE COM A RECARGA QUANDO EU MORRO =====")
	_p.combat_mode = "fruit"
	_p.equip_fruit(F_RECARGA_MORTE)
	await _esperar(ESPERA_BEACON)
	_zerar_recargas()
	_p.energy = _p.max_energy
	var slot := "C"
	var esperado: float = float(_tabela.get(slot, 0.0))
	var t_cast := _agora()
	_p.cast_skill_slot(slot)
	print("   [dono] conjurei '%s' — recarga armada em %.2f s (esperado %.1f)"
		% [slot, float(_p._skill_cooldowns[slot]), esperado])
	await _esperar(2.0)
	var cd_antes: float = float(_p._skill_cooldowns[slot])
	var t_antes := _agora() - t_cast
	print("   [dono] %.2f s depois do cast: recarga = %.3f s" % [t_antes, cd_antes])

	# Morro pela QUEDA, que é a morte que o cliente consegue disparar sozinho.
	_p.velocity = Vector3.ZERO
	_p.global_position = Vector3(0.0, Scoreboard.VOID_Y - 20.0, 0.0)
	var t_queda := _agora()
	var t_respawn := -1.0
	var cd_no_respawn := -1.0
	var t_liberou := -1.0
	var amostras: Array = []
	# Observo até a recarga LIBERAR de fato (ou 25 s de teto). Parar antes deixaria
	# a pergunta pela metade: o que interessa é se o slot volta no tempo da tabela
	# mesmo tendo havido uma morte no meio.
	while _agora() - t_queda < 25.0:
		await process_frame
		Engine.time_scale = 1.0
		var cd: float = float(_p._skill_cooldowns[slot])
		amostras.append([_agora() - t_cast, cd])
		if t_respawn < 0.0 and _p.global_position.y > Scoreboard.VOID_Y:
			t_respawn = _agora() - t_cast
			cd_no_respawn = cd
			print("   [dono] 💀 respawnei %.3f s depois do cast — recarga NESSE INSTANTE = %.3f s"
				% [t_respawn, cd_no_respawn])
		if cd <= 0.0:
			t_liberou = _agora() - t_cast
			break

	print("   [dono] --- transcrição da recarga de '%s' (esperada: %.1f s) ---" % [slot, esperado])
	var passos := 12
	for i in passos:
		var idx: int = mini(int(float(amostras.size() - 1) * float(i) / float(passos - 1)), amostras.size() - 1)
		print("      t=%6.3f s desde o cast  recarga=%6.3f s   (se apenas corresse: %6.3f s)"
			% [float(amostras[idx][0]), float(amostras[idx][1]),
				maxf(esperado - float(amostras[idx][0]), 0.0)])
	# Ponto de veredito: 2 s DEPOIS do respawn — longe o bastante da morte para as
	# três hipóteses darem números bem diferentes, e antes do fim da recarga.
	var t_alvo: float = t_respawn + 2.0
	var i_ver := amostras.size() - 1
	for i in amostras.size():
		if float(amostras[i][0]) >= t_alvo:
			i_ver = i
			break
	var t_ver: float = float(amostras[i_ver][0])
	var cd_ver: float = float(amostras[i_ver][1])
	var se_corresse: float = maxf(esperado - t_ver, 0.0)
	print("   [dono] VEREDITO MEDIDO em t=%.3f s (2 s depois do respawn): recarga = %.3f s" % [t_ver, cd_ver])
	print("          Se tivesse ZERADO no respawn      -> valeria 0.000 s")
	print("          Se tivesse CONTINUADO correndo    -> valeria %.3f s" % se_corresse)
	print("          Se tivesse CONGELADO na morte     -> valeria %.3f s" % cd_no_respawn)
	var diag := "INDEFINIDO — os números não batem com nenhuma das três hipóteses"
	if cd_ver <= 0.01 and se_corresse > 0.5:
		diag = "ZEROU NO RESPAWN — morrer devolve a habilidade de graça"
	elif absf(cd_ver - cd_no_respawn) < 0.05 and cd_no_respawn > 0.1:
		diag = "CONGELOU — a recarga parou de correr depois da morte"
	elif absf(cd_ver - se_corresse) < 0.30:
		diag = "CONTINUOU CORRENDO — morrer não devolve a habilidade nem a atrasa"
	print("   [dono] 🔎 %s" % diag)
	print("   [dono] o slot '%s' voltou a ficar disponível %.3f s depois do cast (tabela: %.1f s, erro %+.3f s)"
		% [slot, t_liberou, esperado, t_liberou - esperado])
	_ok(t_liberou > 0.0 and absf(t_liberou - esperado) < 0.6,
		"mesmo com uma morte no meio, '%s' liberou em %.3f s — os mesmos %.1f s de sempre" % [slot, t_liberou, esperado])
	print("   [dono] contexto: `net_force_respawn` (Player.gd:1126) NÃO toca em `_skill_cooldowns`;")
	print("          e a fruta é devolvida à árvore, então o jogador respawna SEM PODER NENHUM até")
	print("          pegar outra — a recarga do slot vira irrelevante nesse intervalo.")
	print("   [dono] fruta depois do respawn: '%s'" % str(_p.current_fruit_id))
	await _esperar(ESPERA_MORTE)


# ============================================================ 6 · REGEN DE VIDA
# ⚠️ NÃO EXISTE regen de vida no jogo: o `HealthController` só regenera energia e
# `vida` só sobe em `restaurar()` (respawn). Esta fase não valida uma mecânica —
# ela PROVA COM NÚMERO que a vida fica parada, para o dono do projeto decidir se
# quer a mecânica.
func _fase_vida() -> void:
	print("\n[CLI] ===== FASE 6: A VIDA REGENERA? (medida no DONO) =====")
	_p.current_fruit_id = F_VIDA        # só o anúncio; nada de skill aqui
	await _esperar(ESPERA_BEACON)
	_sonda.zerar()

	_p.health = _p.max_health
	await process_frame
	var hp0: float = float(_p.health)
	# Dano local: é o único jeito de o DONO ter a vida abaixada, já que o dano de
	# rede fica preso na cópia do servidor (ver o achado da fase 2A).
	_p.take_damage(700.0)
	var hp1: float = float(_p.health)
	var t_ini := _agora()
	var amostras: Array = []
	while _agora() - t_ini < 8.0:
		await process_frame
		Engine.time_scale = 1.0
		amostras.append([_agora() - t_ini, float(_p.health)])
	var hp_fim: float = float(amostras[-1][1])
	var hp_max := hp1
	for a in amostras:
		hp_max = maxf(hp_max, float(a[1]))
	print("   [dono] vida: %.1f -> take_damage(700) -> %.1f" % [hp0, hp1])
	for frac in [0.25, 0.5, 0.75, 1.0]:
		var idx: int = mini(int(amostras.size() * frac) - 1, amostras.size() - 1)
		print("      t=%.2f s  vida=%.1f" % [float(amostras[idx][0]), float(amostras[idx][1])])
	print("   [dono] em %.2f s de observação: vida final %.1f, máximo lido %.1f, Δ = %+.3f"
		% [float(amostras[-1][0]), hp_fim, hp_max, hp_fim - hp1])
	print("   [dono] comparação: a ENERGIA, no mesmo corpo, sobe %.0f/s." % HealthController.REGEN_ENERGIA)
	_ok(absf(hp_fim - hp1) < 0.01,
		"a vida NÃO regenerou: parada em %.1f por %.2f s (Δ = %+.4f)" % [hp_fim, float(amostras[-1][0]), hp_fim - hp1])
	_ok(_sonda.eventos.size() == 1,
		"o dano local avisou a HUD 1 vez (%d eventos) — a HUD só sabe do dano que nasce no próprio processo"
		% _sonda.eventos.size())


# ------------------------------------------------------------------ utilidades
# Anuncia a fase ao host escrevendo o campo replicado e espera a viagem.
func _marcar(fase: String) -> void:
	_p.current_fruit_id = fase
	print("[CLI][t=%6.2f] 📣 anunciei a fase '%s' (esperando %.1fs pela replicação)"
		% [_t(), fase, ESPERA_BEACON])
	await _esperar(ESPERA_BEACON)

func _zerar_recargas() -> void:
	for k in _p._skill_cooldowns.keys():
		_p._skill_cooldowns[k] = 0.0

func _corpo(nome: String) -> Node:
	for p in get_nodes_in_group("player"):
		if str(p.name) == nome:
			return p
	return null

func _agora() -> float:
	return Time.get_ticks_msec() / 1000.0

func _t() -> float:
	return _agora() - _t0

func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]

func _ok(cond: bool, msg: String) -> void:
	print(("   ✅ " if cond else "   ❌ ") + msg)
	if not cond:
		_falhas += 1

func _esperar(secs: float) -> void:
	# TEMPO REAL: em headless os `process_frame` correm muito mais rápido que
	# 1/60, então contar quadros mede errado. E o `time_scale` é forçado a 1 a
	# cada quadro porque o `hit_stop` do GameFlow o derruba para 0,06 no impacto.
	var fim := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
		Engine.time_scale = 1.0
