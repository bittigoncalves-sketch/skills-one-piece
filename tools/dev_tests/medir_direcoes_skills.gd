extends SceneTree
# ============================================================================
#  SONDA DE DIREÇÃO DAS SKILLS — o golpe vai para onde foi PEDIDO?
# ============================================================================
#
#  Uso:
#    export SOP_PORTA=<a sua porta>
#    godot --headless --path . -s tools/dev_tests/medir_direcoes_skills.gd
#    godot --headless --path . -s tools/dev_tests/medir_direcoes_skills.gd -- mera_mera
#    godot --headless --path . -s tools/dev_tests/medir_direcoes_skills.gd -- --inverter
#
#  ⚠️ SOBE O JOGO — disputa a porta. Não rode junto com `validar.sh`.
#
#  POR QUE ELA EXISTE
#  ------------------
#  Em 2026-08-25 o auto-mira e o lunge do corpo a corpo apontavam PARA TRÁS
#  (`-Vector3.FORWARD.rotated(...)`, dot = −1,00 contra a direção da hitbox) e
#  isso passou SEMANAS despercebido: a hitbox usava a direção certa, o golpe
#  acertava, e só o auxílio estava invertido. Não havia nenhuma medição que
#  fizesse a pergunta "para onde o efeito FOI?".
#
#  Esta sonda faz essa pergunta para **cada fruta × cada slot × cada direção**,
#  e responde com o número que denunciou aquele bug: o PRODUTO ESCALAR entre a
#  direção pedida e a direção real. Perto de +1 = obedeceu. Perto de −1 = foi
#  para o lado oposto.
#
#  COMO SE ACHA "PARA ONDE FOI"
#  ----------------------------
#  O que define para onde um golpe foi é onde ele pode MACHUCAR, não onde ele
#  brilha: a medição olha as `DamageZone` (grupo "hitbox") criadas por AQUELE
#  aperto de tecla. Para cada zona nova:
#
#    • guarda o ponto mais LONGE do jogador que ela alcançou na janela (uma
#      zona parada denuncia por onde nasceu; uma que voa denuncia por onde foi);
#    • o vetor da soma dessas contribuições, normalizado, é a DIREÇÃO REAL.
#
#  ⚠️ ZONAS NOVAS SÃO IDENTIFICADAS POR `instance_id`, não por contagem. Efeito
#  longo (gelo, tornado) sobrevive ao golpe seguinte; contar zonas atribuiria a
#  uma fruta o efeito da anterior — que é o mesmo defeito de método que fez
#  "32 sítios" virarem 28 em `docs/NUMEROS_MEDIDOS.md` §3.
#
#  GOLPE SEM DIREÇÃO NÃO É GOLPE ERRADO
#  ------------------------------------
#  Nem todo golpe aponta: onda de choque em volta de si, buff, aura. Reprovar
#  esses seria transformar a sonda numa fábrica de falso positivo — e sonda que
#  grita à toa deixa de ser lida. Então eles são DETECTADOS e CLASSIFICADOS:
#
#    CENTRADO  — as zonas nascem em cima do corpo (raio médio < %.2f m);
#    OMNI      — as zonas se espalham em volta e a soma se cancela
#                (anisotropia < %.2f: é radial, não direcional).
#
#  A anisotropia é |Σvᵢ| / Σ|vᵢ|: vale 1 quando tudo aponta para o mesmo lado e
#  0 quando o conjunto é simétrico. É ela que separa "explosão em volta" de
#  "jato para a frente" sem depender do nome do golpe.
# ============================================================================

const RAIO_MINIMO := 0.80        # abaixo disto o golpe nasce em cima do corpo
const ANISO_MINIMA := 0.30       # abaixo disto o conjunto é radial, não direcional
const DOT_OK := 0.65             # obedeceu
const DOT_INVERTIDO := 0.0       # abaixo de zero foi para o hemisfério errado

# ⚠️ TETO GENEROSO, e por um motivo medido. Com 2,5 s, `goro_goro V` e
# `mera_mera C` não chegavam a criar hitbox DENTRO da própria janela — e a zona
# nascia depois, já na medição da direção seguinte, produzindo um atraso de
# exatamente UM PASSO na tabela (LESTE lia NORTE, SUL lia LESTE, OESTE lia SUL).
# Isso não é golpe indo para o lado errado: é a janela ser mais curta que o
# golpe. Drenar a cena entre medições NÃO resolve — quando o dreno olha, a zona
# atrasada ainda não existe.
# O custo é baixo porque a janela FECHA 1 s depois da primeira zona
# (JANELA_POS_PRIMEIRA): golpe rápido continua rápido; só os lentos usam o teto.
const JANELA_MAX := 6.0          # teto de amostragem por golpe
const JANELA_POS_PRIMEIRA := 1.0 # depois da primeira zona, mais isto e encerra
const PAUSA := 0.30              # respiro entre golpes
const LIMITE_DRENO := 6.0        # teto da espera pela cena esvaziar

const SLOTS := ["Z", "X", "C", "V"]

var _player: Node = null
var _main: Node = null
var _inverter := false           # SABOTAGEM DE PROVA: manda o oposto do pedido
var _celulas: Array = []         # cada célula medida (dicionário)
var _falhas: Array = []


func _init() -> void:
	_rodar()


func _rodar() -> void:
	await process_frame
	var args := PackedStringArray(OS.get_cmdline_user_args())
	_inverter = args.has("--inverter")
	var pedidas: Array = []
	for a in args:
		if not a.begins_with("--"):
			pedidas.append(a)

	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(3.0)
	_main = current_scene
	_player = _local()
	if _player == null:
		print("❌ não achei o jogador — a cena não subiu (porta ocupada?)")
		quit(1)
		return

	_preparar_bancada()

	print("\n╔══════════════════════════════════════════════════════════════╗")
	print("║  DIREÇÃO DAS SKILLS — o golpe vai para onde foi pedido?       ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	print("convenção: NORTE=−Z  SUL=+Z  LESTE=+X  OESTE=−X  (src/world/RosaDosVentos.gd)")
	if _inverter:
		print("🧪 SABOTAGEM LIGADA (--inverter): o `aim` entregue ao jogo é o OPOSTO")
		print("   do pedido. Toda célula direcional TEM que virar ❌ INVERTIDO —")
		print("   é assim que se prova que esta sonda sabe reprovar.")

	await _auxilio_corpo_a_corpo()

	var skills: Dictionary = SkillSystem.get_fruit_skills()
	var alvos: Array = []
	for k in skills.keys():
		if pedidas.is_empty() or pedidas.has(str(k)):
			alvos.append(str(k))
	alvos.sort()

	for fid in alvos:
		await _auditar_fruta(fid)

	_tabela()
	_resumo()


# ------------------------------------------------------------------ bancada
# ⚠️ OS BONECOS BATEM SOZINHOS E SUJAM A MEDIÇÃO: um soco do boneco automático
# empurra o jogador no meio da janela e o "origem de referência" deixa de valer.
# Mesmo remédio de `captura_visual.gd`: congela e manda para longe.
func _preparar_bancada() -> void:
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
		print("⏸  relógio da rodada congelado")
	var n := 0
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		if e is Node3D:
			e.global_position = Vector3(0, 1, -900)
		n += 1
	print("🧊 %d boneco(s) congelado(s) e afastado(s)" % n)
	_player.set_meta("damage_immune", true)


# --------------------------------------------- o bug de 2026-08-25, medido
# O auto-mira e o lunge não criam `DamageZone` — eles escolhem alvo e empurram
# o corpo. Se ficassem de fora, a sonda cobriria tudo MENOS o defeito que a
# originou. Aqui o teste é direto: um alvo à FRENTE e outro ATRÁS, e pergunta-se
# ao jogo qual ele escolhe e para onde ele pula.
func _auxilio_corpo_a_corpo() -> void:
	print("\n────────────────────────────────────────────────────────────")
	print("🎯 AUXÍLIO DO CORPO A CORPO (auto-mira + lunge) — o bug de 2026-08-25")
	if not _player.has_method("find_best_melee_target"):
		print("   (o Player não expõe `find_best_melee_target` — pulado)")
		return

	for nome in RosaDosVentos.CARDEAIS:
		var pedido: Vector3 = RosaDosVentos.MUNDO[nome]
		_posicionar(pedido)
		await _esperar(0.15)
		var origem: Vector3 = _player.global_position

		var frente_no := Node3D.new()
		frente_no.add_to_group("enemy")
		_main.add_child(frente_no)
		frente_no.global_position = origem + pedido * 5.0
		var tras_no := Node3D.new()
		tras_no.add_to_group("enemy")
		_main.add_child(tras_no)
		tras_no.global_position = origem - pedido * 5.0
		await process_frame

		var escolhido = _player.find_best_melee_target(12.0)
		var qual := "nenhum"
		var mira_ok := false
		if escolhido == frente_no:
			qual = "o da FRENTE"
			mira_ok = true
		elif escolhido == tras_no:
			qual = "o de TRÁS"

		var dot_lunge := 0.0
		if escolhido != null and _player.has_method("perform_melee_lunge"):
			_player.velocity = Vector3.ZERO
			_player.perform_melee_lunge(frente_no)
			var v: Vector3 = _player.velocity
			var vh := Vector3(v.x, 0, v.z)
			if vh.length() > 0.01:
				dot_lunge = vh.normalized().dot(pedido)
		_player.velocity = Vector3.ZERO

		var ok := mira_ok and dot_lunge > DOT_OK
		print("   encarando %-6s | auto-mira escolheu %-12s | dot(lunge, alvo) = %+.2f  %s"
			% [nome, qual, dot_lunge, "✓" if ok else "❌"])
		if not ok:
			_falhas.append("auxílio corpo a corpo encarando %s (mira=%s, lunge dot=%+.2f)"
				% [nome, qual, dot_lunge])
		frente_no.queue_free()
		tras_no.queue_free()
		await process_frame


# ------------------------------------------------------------------ auditoria
func _auditar_fruta(fid: String) -> void:
	print("\n────────────────────────────────────────────────────────────")
	print("🍎 %s" % fid.to_upper())
	_player.equip_fruit(fid)
	await _esperar(0.3)
	if str(_player.current_fruit_id) != fid:
		print("   ⚠ não equipou (ficou '%s') — pulando" % _player.current_fruit_id)
		return

	for slot in SLOTS:
		var linha := "   %s │" % slot
		for nome in RosaDosVentos.CARDEAIS:
			var c := await _confirmar(fid, slot, nome)
			_celulas.append(c)
			linha += " %-6s %s │" % [nome.substr(0, 1) + ("%+.2f" % c["dot"]), c["marca"]]
		print(linha)


# ⚠️ ACUSAÇÃO SÓ COM REPETIÇÃO. Golpe de ÁREA que fica bem na fronteira da
# classificação (o `Desert Girasole` da suna_suna é o caso) tem deslocamento
# quase nulo: normalizar um vetor curto amplia ruído, e o produto escalar da
# mesma célula pulou de −0,86 a +1,00 entre rodadas — ora "invertido", ora "ok".
#
# O bug de verdade que esta sonda existe para pegar NÃO era assim: o lunge dava
# −1,00 em TODO yaw, rodada após rodada. Consistência é a assinatura do defeito
# real, e ruído não a tem.
#
# Então: célula que sai INVERTIDO ou DESVIADO é medida de novo, até 3 vezes. Só
# vale a acusação se ela se repetir. Isso mantém o poder de reprovar (defeito
# consistente sobrevive) e tira o falso positivo de área.
func _confirmar(fid: String, slot: String, nome_dir: String) -> Dictionary:
	var c := await _medir(fid, slot, nome_dir)
	var t: String = c["tipo"]
	if t != "INVERTIDO" and t != "DESVIADO":
		return c
	var iguais := 1
	var pior := c
	for _i in 2:
		var d := await _medir(fid, slot, nome_dir)
		if String(d["tipo"]) == t:
			iguais += 1
			if absf(float(d["dot"])) > absf(float(pior["dot"])):
				pior = d
		else:
			pior = d if String(d["tipo"]) in ["OK", "CENTRADO", "OMNI"] else pior
	if iguais >= 2:
		pior["repeticoes"] = iguais
		return pior
	# não se repetiu: a acusação era ruído. Devolve a leitura estável e MARCA.
	pior["instavel"] = true
	pior["marca"] = " ~?  "
	return pior


# UMA célula da tabela: uma fruta, um slot, uma direção.
func _medir(fid: String, slot: String, nome_dir: String) -> Dictionary:
	var pedido: Vector3 = RosaDosVentos.MUNDO[nome_dir]
	_posicionar(pedido)
	await _esperar(0.1)

	# Estado limpo — mesmas travas que o `test_frutas` solta antes de disparar.
	_player._skill_cooldowns[slot] = 0.0
	_player.set_meta("is_casting", false)
	_player._cast.abortar()
	_player._rapid_fire = false
	_player.lock_movement(0.0, "")
	_player.energy = _player.max_energy

	var origem_ref: Vector3 = _player.global_position
	var origem: Vector3 = origem_ref + Vector3.UP
	var antigas := _ids_das_hitboxes()

	# A SABOTAGEM: manda o oposto do pedido, mas continua comparando com o
	# PEDIDO. É o "direção invertida" simulado do critério de sucesso.
	var aim := -pedido if _inverter else pedido
	_player._fire_skill(slot, aim, origem)

	# amostragem: guarda, por zona nova, o ponto mais longe do jogador
	var extremos: Dictionary = {}     # id -> Vector3 (offset horizontal)
	var t0 := Time.get_ticks_msec()
	var t_primeira := -1
	while true:
		var dt := Time.get_ticks_msec() - t0
		if dt > int(JANELA_MAX * 1000.0):
			break
		if t_primeira >= 0 and Time.get_ticks_msec() - t_primeira > int(JANELA_POS_PRIMEIRA * 1000.0):
			break
		for z in get_root().get_tree().get_nodes_in_group("hitbox"):
			if not (z is Node3D) or antigas.has(z.get_instance_id()):
				continue
			if t_primeira < 0:
				t_primeira = Time.get_ticks_msec()
			var d: Vector3 = z.global_position - origem_ref
			var h := Vector3(d.x, 0.0, d.z)
			var id := z.get_instance_id()
			if not extremos.has(id) or h.length() > (extremos[id] as Vector3).length():
				extremos[id] = h
		await process_frame

	var c := _classificar(extremos, pedido)
	c["fruta"] = fid
	c["slot"] = slot
	c["dir"] = nome_dir
	await _drenar()
	return c


# ⚠️ ESPERA ATÉ A CENA FICAR LIMPA, em vez de uma pausa fixa.
#
# A pausa fixa de 0,30 s não bastava: golpe com ATRASO (carregado, ou projétil
# que viaja e só então cria a zona) nasce DEPOIS do instantâneo `antigas` da
# medição seguinte e entra nela como se fosse dela. O sintoma é inconfundível —
# um atraso de exatamente UM PASSO na tabela:
#
#     goro_goro V→LESTE  deu real=NORTE
#     goro_goro V→SUL    deu real=LESTE
#     goro_goro V→OESTE  deu real=SUL
#
# ou seja, cada célula media o golpe da célula anterior. Três das cinco
# "desviadas" eram isso, não direção errada do jogo.
#
# Drenar é robusto porque não depende de adivinhar o atraso de cada golpe: só
# começa a próxima medição quando não há mais NENHUMA hitbox em cena.
func _drenar() -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(LIMITE_DRENO * 1000.0):
		if get_root().get_tree().get_nodes_in_group("hitbox").is_empty():
			# vazia: mais um respiro curto e segue, para o que estiver a caminho
			await _esperar(PAUSA)
			if get_root().get_tree().get_nodes_in_group("hitbox").is_empty():
				return
			t = Time.get_ticks_msec()
		await process_frame
	push_warning("[direcoes] a cena não esvaziou em %.1f s — a medição seguinte pode herdar zona" % LIMITE_DRENO)


func _classificar(extremos: Dictionary, pedido: Vector3) -> Dictionary:
	var n := extremos.size()
	if n == 0:
		return {"tipo": "SEM_HITBOX", "dot": 0.0, "marca": "  ·  ", "zonas": 0,
			"raio": 0.0, "aniso": 0.0, "real": "?"}

	var soma := Vector3.ZERO
	var soma_r := 0.0
	for id in extremos:
		var v: Vector3 = extremos[id]
		soma += v
		soma_r += v.length()
	var raio := soma_r / float(n)
	var aniso: float = (soma.length() / soma_r) if soma_r > 1e-6 else 0.0

	if raio < RAIO_MINIMO:
		return {"tipo": "CENTRADO", "dot": 0.0, "marca": " cen ", "zonas": n,
			"raio": raio, "aniso": aniso, "real": "—"}
	if aniso < ANISO_MINIMA:
		return {"tipo": "OMNI", "dot": 0.0, "marca": " omni", "zonas": n,
			"raio": raio, "aniso": aniso, "real": "—"}

	var real := soma.normalized()
	var dot := real.dot(pedido)
	var tipo := "OK"
	var marca := "  ✓  "
	if dot < DOT_INVERTIDO:
		tipo = "INVERTIDO"
		marca = "  ❌ "
	elif dot < DOT_OK:
		tipo = "DESVIADO"
		marca = "  ⚠  "
	return {"tipo": tipo, "dot": dot, "marca": marca, "zonas": n, "raio": raio,
		"aniso": aniso, "real": RosaDosVentos.nome_mais_proximo(real)}


# Põe o jogador no centro do mapa encarando a direção pedida. O yaw sai da
# rosa (`atan2(-x,-z)`), então quem manda no "encarar" é a convenção declarada.
func _posicionar(dir: Vector3) -> void:
	_player.global_position = Vector3(0, 2.0, 0)
	_player.velocity = Vector3.ZERO
	var yaw := RosaDosVentos.yaw_para(-dir if _inverter else dir)
	_player._yaw = yaw
	if "_char_model" in _player and _player._char_model:
		_player._char_model.rotation.y = yaw


func _ids_das_hitboxes() -> Dictionary:
	var d: Dictionary = {}
	for z in get_root().get_tree().get_nodes_in_group("hitbox"):
		d[z.get_instance_id()] = true
	return d

# -------------------------------------------------------------------- saída
func _tabela() -> void:
	print("\n╔══════════════════════════════════════════════════════════════════════════╗")
	print("║  TABELA  fruta × slot × direção — produto escalar (pedido · real)        ║")
	print("╚══════════════════════════════════════════════════════════════════════════╝")
	print("%-11s %-5s %8s %8s %8s %8s   %s" % ["fruta", "slot", "NORTE", "LESTE", "SUL", "OESTE", "veredito"])
	var fid_ant := ""
	var linha: Dictionary = {}
	for c in _celulas:
		if c["fruta"] != fid_ant and fid_ant != "":
			pass
		fid_ant = c["fruta"]
		var chave: String = "%s/%s" % [c["fruta"], c["slot"]]
		if not linha.has(chave):
			linha[chave] = {}
		linha[chave][c["dir"]] = c
	for chave in linha:
		# ⚠️ `chave` vem de um Dictionary, então é Variant: `chave.split(...)` não
		# tem tipo e o `:=` não infere. Tipar a variável resolve.
		var partes: PackedStringArray = String(chave).split("/")
		var txt := "%-11s %-5s" % [partes[0], partes[1]]
		var tipos: Dictionary = {}
		for nome in RosaDosVentos.CARDEAIS:
			var c: Dictionary = linha[chave][nome]
			tipos[c["tipo"]] = true
			if c["tipo"] == "OK" or c["tipo"] == "DESVIADO" or c["tipo"] == "INVERTIDO":
				txt += " %+8.2f" % c["dot"]
			elif c["tipo"] == "CENTRADO":
				txt += " %8s" % "centrado"
			elif c["tipo"] == "OMNI":
				txt += " %8s" % "omni"
			else:
				txt += " %8s" % "s/hitbox"
		txt += "   " + _veredito_da_linha(tipos)
		print(txt)


func _veredito_da_linha(tipos: Dictionary) -> String:
	if tipos.has("INVERTIDO"):
		return "❌ INVERTIDO em alguma direção"
	if tipos.has("DESVIADO"):
		return "⚠ desvia da direção pedida"
	if tipos.has("SEM_HITBOX"):
		return "· sem hitbox nesta janela"
	if tipos.has("OMNI"):
		return "omni — golpe em área, SEM direção (não se aplica)"
	if tipos.has("CENTRADO"):
		return "centrado em si — SEM direção (não se aplica)"
	return "✓ obedece nas 4 direções"


func _resumo() -> void:
	var invertidas: Array = []
	var desviadas: Array = []
	var mudas: Array = []
	var sem_direcao: Array = []
	for c in _celulas:
		var rot: String = "%s %s→%s (%+.2f, real=%s)" % [c["fruta"], c["slot"], c["dir"], c["dot"], c["real"]]
		match c["tipo"]:
			"INVERTIDO": invertidas.append(rot)
			"DESVIADO": desviadas.append(rot)
			"SEM_HITBOX": mudas.append("%s %s→%s" % [c["fruta"], c["slot"], c["dir"]])
			"CENTRADO", "OMNI": sem_direcao.append("%s %s (%s)" % [c["fruta"], c["slot"], c["tipo"]])

	print("\n╔══════════════════════════════════════════════════════════════╗")
	print("║  RESUMO                                                      ║")
	print("╚══════════════════════════════════════════════════════════════╝")
	print("células medidas ...............: %d" % _celulas.size())
	print("golpes SEM direção (classificados, não reprovados): %d célula(s)" % sem_direcao.size())
	print("\n❗ INVERTIDAS (o efeito foi para o hemisfério oposto ao pedido): %d" % invertidas.size())
	for r in invertidas:
		print("   ❌ %s" % r)
	print("\n⚠ DESVIADAS (obedecem só em parte, dot < %.2f): %d" % [DOT_OK, desviadas.size()])
	for r in desviadas:
		print("   ⚠ %s" % r)
	if not mudas.is_empty():
		print("\n· sem hitbox na janela de %.1f s: %d" % [JANELA_MAX, mudas.size()])
		for r in mudas:
			print("   · %s" % r)
	for f in _falhas:
		print("   ❌ %s" % f)

	var reprovou := not invertidas.is_empty() or not _falhas.is_empty()
	if _inverter:
		# Com a sabotagem ligada o resultado esperado é o INVERSO: se nada foi
		# pego, o detector é cego e ISSO é a falha.
		print("\n🧪 AUTOTESTE DA SABOTAGEM")
		if reprovou:
			print("   ✓ com o `aim` invertido a sonda pegou %d célula(s) — ela SABE reprovar."
				% invertidas.size())
			quit(0)
		else:
			print("   ❌ com o `aim` invertido a sonda não pegou NADA — ela não testa nada.")
			quit(1)
		return

	if reprovou:
		print("\n❌ REPROVADO — há golpe indo para o lado errado.")
		quit(1)
		return
	print("\n✓ nenhuma direção invertida.")
	quit(0)

# ------------------------------------------------------------------ utilidades
func _local() -> Node:
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null


func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
