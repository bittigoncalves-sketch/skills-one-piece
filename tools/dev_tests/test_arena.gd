extends SceneTree
# ============================================================================
#  TESTE DE REGRESSÃO DA ARENA — buracos, placar e corpo a corpo.
#
#  Sobe o jogo de verdade (Main.tscn via GameFlow) e checa, sem abrir janela:
#    1. a plataforma virou grade com buracos e o spawn ficou em zona sólida;
#    2. os inimigos saíram do mapa (só o dummy de treino continua);
#    3. cair num buraco conta MORTE e dá KILL pro último que bateu;
#    4. o combo de corpo a corpo tem os 3 passos com os membros certos.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_arena.gd
# ============================================================================

var _falhas := 0

func _init() -> void:
	await process_frame
	# Num script `-s` os autoloads existem na árvore mas NÃO viram identificador
	# de compilação — por isso `GameFlow.x` não compila aqui e o acesso é por nó.
	var game_flow := get_root().get_node("GameFlow")
	game_flow.start_singleplayer()
	for i in 180:
		await process_frame

	var main := current_scene
	print("\n===== ARENA (%s) =====" % main.name)
	_mapa(main)
	_inimigos()
	await _placar(main)
	_melee()
	await _melee_dano()
	_buki()

	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)

func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1

# ---------------------------------------------------------------------- mapa
func _mapa(main: Node) -> void:
	print("\n-- 1. mapa em grade com buracos --")
	var plat := main.get_node_or_null("Plataforma")
	_ok(plat != null, "plataforma existe")
	if plat == null:
		return
	var mmi := plat.get_node_or_null("Lajes") as MultiMeshInstance3D
	var shapes := 0
	for c in plat.get_children():
		if c is CollisionShape3D:
			shapes += 1
	var buracos: int = MapBuilder._holes.size()
	var celulas: int = MapBuilder.GRID * MapBuilder.GRID
	print("     %d células, %d de buraco, %d corridas de malha, %d shapes"
		% [celulas, buracos, mmi.multimesh.instance_count if mmi else -1, shapes])
	_ok(buracos > 0, "existem buracos na plataforma")
	_ok(mmi != null and mmi.multimesh.instance_count == shapes,
		"malha e colisão têm a mesma contagem de corridas")
	_ok(mmi != null and mmi.multimesh.instance_count < celulas,
		"corridas fundidas (menos geometria que células)")
	_ok(not MapBuilder.is_hole(0, 0), "spawn do jogador NÃO é buraco")
	_ok(not MapBuilder.is_hole(0, -8), "dummy de treino NÃO está sobre buraco")
	_ok(MapBuilder.is_hole(999, 999), "fora da plataforma conta como vazio")

# ------------------------------------------------------------------ inimigos
func _inimigos() -> void:
	print("\n-- 2. inimigos fora do mapa --")
	var no_grupo := get_root().get_tree().get_nodes_in_group("enemy")
	var dummies := 0
	var outros := 0
	for e in no_grupo:
		if e.is_in_group("dummy"):
			dummies += 1
		else:
			outros += 1
	print("     grupo \"enemy\": %d dummy(s), %d outro(s)" % [dummies, outros])
	_ok(outros == 0, "nenhum inimigo nasceu no mapa")
	_ok(dummies >= 1, "o dummy de treino continua (saco de pancadas)")
	_ok(ResourceLoader.exists("res://disabled/enemies/Enemy.gd"),
		"o código do inimigo continua no projeto (disabled/enemies/)")

# -------------------------------------------------------------------- placar
func _placar(main: Node) -> void:
	print("\n-- 3. placar: queda dá morte e transfere a kill --")
	var sb = get_root().get_tree().get_first_node_in_group("scoreboard")
	_ok(sb != null, "placar na árvore")
	if sb == null:
		return
	_ok(absf(sb.time_left - Scoreboard.ROUND_TIME) < 5.0,
		"cronômetro começa em %d min" % int(Scoreboard.ROUND_TIME / 60.0))

	var p = get_root().get_tree().get_first_node_in_group("player")
	_ok(p != null, "jogador na árvore")
	if p == null:
		return
	var peer: int = str(p.name).to_int()

	# Um agressor fictício com o mesmo contrato de um player remoto.
	var vilao := Node3D.new()
	vilao.name = "99"
	vilao.add_to_group("player")
	main.add_child(vilao)
	await process_frame

	sb.register_hit(p, vilao)
	p.global_position = Vector3(0, -80, 0)     # jogado num buraco
	for i in 12:
		await process_frame

	var r: Array = sb.ranking()
	print("     ranking [peer, kills, mortes]: ", r)
	var kills_vilao := 0
	var mortes_player := 0
	for linha in r:
		if int(linha[0]) == 99:
			kills_vilao = int(linha[1])
		if int(linha[0]) == peer:
			mortes_player = int(linha[2])
	_ok(mortes_player == 1, "quem caiu levou 1 morte")
	_ok(kills_vilao == 1, "quem bateu por último levou a kill")
	_ok(p.global_position.y > 0.0, "quem caiu foi respawnado na plataforma")
	_ok(p.health == p.max_health, "respawn devolveu a vida cheia")
	vilao.queue_free()

# --------------------------------------------------------------- corpo a corpo
func _melee() -> void:
	print("\n-- 4. combo de corpo a corpo --")
	_ok(Melee.JANELA == 2.0, "janela de encadeamento = 2 s")
	_ok(Melee.COMBO.size() == 4, "combo de 4 passos")
	var nomes: Array = []
	for i in Melee.COMBO.size():
		var g := Melee.passo(i)
		var c := Melee.clipe(i)
		nomes.append(g["nome"])
		_ok(c != null, "passo %d (%s) tem clipe" % [i, g["nome"]])
	print("     ", nomes)
	# Os dois socos são clipes AUTORAIS de lados opostos (não mais o mesmo clipe
	# espelhado). O que o teste garante é o que importa em tela: o primeiro golpe
	# é de braço direito e o segundo de esquerdo, com folga clara.
	var d0 := _amplitude(Melee.clipe(0), ["UpperArm_R", "ForeArm_R"])
	var e0 := _amplitude(Melee.clipe(0), ["UpperArm_L", "ForeArm_L"])
	var d1 := _amplitude(Melee.clipe(1), ["UpperArm_R", "ForeArm_R"])
	var e1 := _amplitude(Melee.clipe(1), ["UpperArm_L", "ForeArm_L"])
	print("     amplitude braço D/E — soco 1: %.0f/%.0f | soco 2: %.0f/%.0f" % [d0, e0, d1, e1])
	_ok(d0 > e0 * 1.5, "o primeiro soco usa o braço DIREITO")
	_ok(e1 > d1 * 1.5, "o segundo soco usa o braço ESQUERDO")
	_ok(Melee.passo(0)["anim"] != Melee.passo(1)["anim"],
		"os dois socos são clipes DIFERENTES (não o mesmo espelhado)")
	# ---- o IMPACTO cai no frame do soco, e o soco cabe em tela ----------------
	# `atraso` é uma FRAÇÃO do clipe: (pico − inicio)/vel. Mexer em `vel` ou
	# `inicio` sem recalcular o atraso é o erro que este bloco existe pra pegar —
	# ele não confere o número escrito, confere o número contra a ANIMAÇÃO.
	#
	# Membro que golpeia em cada passo (a tabela do Melee não diz, e é o que
	# define onde está o impacto). Passo 2 é perna ESQUERDA desde que o chute
	# virou lateral (`roundhouse_kick`, 2026-08-18) — ver a nota no cabeçalho
	# do `Melee.gd`; o passo 3 (finalizador) não mudou, continua perna D aqui.
	var membro := [["UpperArm_R", "ForeArm_R"], ["UpperArm_L", "ForeArm_L"], ["Thigh_L", "Shin_L", "Foot_L"], ["Thigh_R", "Shin_R", "Foot_R"]]
	for i in Melee.COMBO.size():
		var g := Melee.passo(i)
		var a := Melee.clipe(i)
		var tocada: float = Melee.duracao_tocada(i)
		var t_imp: float = Melee.impacto_no_clipe(i)          # em tempo de CLIPE
		var j: Array = _janela_acao(a, membro[i], t_imp)      # [t0, t1, t_pico, frac_no_impacto]
		print("     passo %d (%s): vel %.2fx inicio %.2fs -> %.2fs em tela | impacto t_clipe=%.3f, ação [%.3f..%.3f] pico %.3f (%.0f%% no impacto)"
			% [i, g["nome"], float(g["vel"]), float(g.get("inicio", 0.0)), tocada,
				t_imp, j[0], j[1], j[2], 100.0 * j[3]])
		_ok(float(g["atraso"]) + float(g["vida"]) <= tocada,
			"passo %d (%s): hitbox (%.2f+%.2f s) cabe na animação de %.2f s"
				% [i, g["nome"], float(g["atraso"]), float(g["vida"]), tocada])
		_ok(t_imp >= j[0] and t_imp <= j[1],
			"passo %d (%s): a hitbox nasce DENTRO do golpe do membro, não na guarda" % [i, g["nome"]])
		_ok(j[3] >= 0.9,
			"passo %d (%s): no instante da hitbox o membro está a %.0f%% da extensão máxima"
				% [i, g["nome"], 100.0 * j[3]])
		# Depois do impacto o golpe precisa FICAR em tela. Com o recuo colado no
		# `atraso` o clique seguinte troca o clipe 2 quadros depois do soco, e os
		# dois socos viram a mesma coisa: só a pose de guarda, que é idêntica nos
		# dois clipes. 0,15 s = 9 quadros a 60 fps.
		#
		# ⚠️ Desde 2026-08-15 o recuo NÃO é mais chave da tabela — ele é derivado
		# da duração da animação (`Melee.recuo()`), que é o que trava o clique E o
		# corpo. A asserção continua valendo: ela agora confere o PISO da conta.
		var rec: float = Melee.recuo(i)
		_ok(rec >= float(g["atraso"]) + 0.15,
			"passo %d (%s): %.0f ms de golpe em tela DEPOIS do impacto (recuo %.2f, impacto %.2f)"
				% [i, g["nome"], 1000.0 * (rec - float(g["atraso"])), rec, float(g["atraso"])])
		# A trava é a animação: o clique seguinte não pode abrir antes do fim.
		_ok(absf(rec - tocada) < 0.02 or rec > tocada,
			"passo %d (%s): a trava (%.2f s) cobre a animação inteira (%.2f s)"
				% [i, g["nome"], rec, tocada])
	# Ritmo: os dois socos não podem ter a mesma cadência, senão leem igual mesmo
	# sendo braços opostos (foi o relato do dono em 2026-08-11).
	_ok(absf(float(Melee.passo(0)["atraso"]) - float(Melee.passo(1)["atraso"])) >= 0.05,
		"os dois socos conectam em tempos DIFERENTES (%.2f s x %.2f s)"
			% [float(Melee.passo(0)["atraso"]), float(Melee.passo(1)["atraso"])])
	# Perna que golpeia no passo 2 (lê de `melee_guarda`, ver Melee.gd) contra
	# CADA braço isoladamente — não a soma dos dois. Chute giratório/lateral de
	# verdade (ex: `roundhouse_kick`) balança os DOIS braços pra compensar a
	# rotação do quadril, e a soma deles pode superar a soma das pernas sem que
	# o golpe deixe de ser um chute (medido: braços somados 369° > pernas
	# somadas 344° no `roundhouse_kick`, mas a perna que soca sozinha, 223°,
	# ainda bate cada braço isolado, 202° e 167°). Comparar perna-que-soca
	# contra braço isolado é o que sobra pra pegar de fato um clipe trocado
	# (ex: um soco entrando no lugar do chute).
	var perna_g := String(Melee.passo(2).get("melee_guarda", "")).trim_prefix("perna_")
	var perna: float
	var braco: float
	if perna_g in ["R", "L"]:
		perna = _amplitude(Melee.clipe(2), ["Thigh_%s" % perna_g, "Shin_%s" % perna_g])
		var braco_r := _amplitude(Melee.clipe(2), ["UpperArm_R", "ForeArm_R"])
		var braco_l := _amplitude(Melee.clipe(2), ["UpperArm_L", "ForeArm_L"])
		braco = maxf(braco_r, braco_l)
	else:
		perna = _amplitude(Melee.clipe(2), ["Thigh_R", "Shin_R", "Thigh_L", "Shin_L"])
		braco = _amplitude(Melee.clipe(2), ["UpperArm_R", "ForeArm_R", "UpperArm_L", "ForeArm_L"])
	print("     chute (perna %s): perna-que-soca %.0f vs braço isolado mais forte %.0f" % [perna_g, perna, braco])
	_ok(perna > braco, "o chute (passo 2) é de PERNA")
	_ok(Melee.passo(3)["kb"] > Melee.passo(0)["kb"] * 2.0, "o chute empurra mais que o dobro do soco (é ele que joga no buraco)")

# Janela de AÇÃO de um membro dentro do clipe, MEDIDA — não declarada.
#
# Sinal = deslocamento do efetor (punho / pé) em relação à posição dele em t=0,
# por cinemática direta com segmentos de comprimento 1 no referencial do tronco
# (as faixas do .res só guardam rotação, então só o ângulo importa; o tamanho real
# do membro escala a curva inteira e não move o instante do máximo).
#
# Foi preciso testar três sinais para achar um que servisse aos três golpes:
#   • desvio ANGULAR das juntas — erra o chute em 0,22 s (a perna continua girando
#     na retração, e o pico cai depois do pé já ter voltado);
#   • alcance FRONTAL (−Z) — erra o uppercut, que sobe em vez de ir pra frente, e
#     no hook pega a mão da GUARDA (o outro braço) em vez da que soca;
#   • deslocamento do efetor — acerta os três (0,633 / 0,367 / 1,233).
#
# Devolve [inicio, fim, t_do_pico, fração_do_pico_no_instante_da_hitbox].
# "Ação" = trecho em que o sinal passa de 25% do pico; fora dele o membro está
# parado na guarda, e uma hitbox nascendo ali é dano sem golpe.
func _janela_acao(a: Animation, papeis: Array, t_hit: float) -> Array:
	if a == null:
		return [0.0, 0.0, 0.0, 0.0]
	var tis: Array = []
	for p in papeis:
		tis.append(a.find_track(NodePath(String(p) + ":rotation"), Animation.TYPE_VALUE))
	var passo_t := 1.0 / 120.0
	var pos: Array = []
	var t := 0.0
	while t <= a.length + 0.0001:
		var acc := Basis()
		var pt := Vector3.ZERO
		for k in tis.size():
			if tis[k] < 0:
				continue
			var v = a.value_track_interpolate(tis[k], minf(t, a.length))
			if v is Vector3:
				acc = acc * Basis.from_euler(v)
				pt += acc * Vector3(0, -1, 0)
		pos.append(pt)
		t += passo_t
	if pos.size() < 2:
		return [0.0, 0.0, 0.0, 0.0]
	var p0: Vector3 = pos[0]
	var sinal: Array = []
	for pt in pos:
		sinal.append((pt - p0).length())
	var pico := 0.0
	var t_pico := 0.0
	for i in sinal.size():
		if sinal[i] > pico:
			pico = sinal[i]
			t_pico = float(i) * passo_t
	if pico <= 0.0:
		return [0.0, 0.0, 0.0, 0.0]
	var t0 := -1.0
	var t1 := 0.0
	for i in sinal.size():
		if sinal[i] >= pico * 0.25:
			if t0 < 0.0:
				t0 = float(i) * passo_t
			t1 = float(i) * passo_t
	var idx: int = clampi(int(round(t_hit / passo_t)), 0, sinal.size() - 1)
	return [maxf(t0, 0.0), t1, t_pico, float(sinal[idx]) / pico]

# ------------------------------------------- corpo a corpo: dano UMA vez só
# A DamageZone já tem o dicionário `_hit` que impede repetir alvo na MESMA zona.
# O que este teste cobre é o que aquele dicionário NÃO cobre: um clique criando
# mais de uma zona, ou o combo andando dois passos de uma vez. Mede no boneco de
# treino, contando queda de vida — não confia em contador interno nenhum.
func _melee_dano() -> void:
	print("\n-- 4b. um clique = UMA aplicação de dano --")
	var p = get_root().get_tree().get_first_node_in_group("player")
	var d = get_root().get_tree().get_first_node_in_group("dummy")
	_ok(p != null and d != null, "jogador e boneco de treino na árvore")
	if p == null or d == null:
		return
	
	# Congela e afasta outros inimigos/dummies para não interferirem (ex: AutoDummy atacando e acertando d)
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		if e != d:
			e.set_meta("is_frozen", true)
			e.global_position = Vector3(0, -1000, 0)
			
	for i in Melee.COMBO.size():
		var g := Melee.passo(i)
		# Boneco à frente do jogador, dentro do alcance (alcance + raio = 3,0 m).
		d.global_position = Vector3(0, 1.0, -8.0)
		d.velocity = Vector3.ZERO
		d.health = 1000.0
		p.global_position = Vector3(0, 1.0, -6.2)
		p._yaw = 0.0                     # olhando pro −Z, onde está o boneco
		p._melee._passo = i
		p._melee._janela = Melee.JANELA
		p._melee._trava = 0.0
		p._melee._buffer = 0.0
		await process_frame
		var hp: float = d.health
		var aplicacoes := 0
		p._request_melee()
		# Espera em tempo REAL: o `atraso` da hitbox roda num SceneTreeTimer, e no
		# headless o número de quadros por segundo não é 60.
		var limite: int = Time.get_ticks_msec() + int(1000.0 * (float(g["atraso"]) + float(g["vida"]) + 0.9))
		while Time.get_ticks_msec() < limite:
			await process_frame
			if d.health < hp - 0.0001:
				aplicacoes += 1
				hp = d.health
			# O knockback tiraria o boneco do alcance e mascararia um 2º acerto.
			d.velocity = Vector3.ZERO
			d.global_position = Vector3(0, 1.0, -8.0)
		_ok(aplicacoes == 1, "passo %d (%s): %d aplicação(ões) de dano no clique (esperado 1)"
			% [i, g["nome"], aplicacoes])
	d.health = 1000.0
	p._melee._passo = 0
	p._melee._trava = 0.0

# ------------------------------------------------------------------ buki buki
# As armas viraram ASSET (.glb do Blender). O risco novo é silencioso: se o
# arquivo sumir ou o import não rodar, o BukiFX cai no plano B voxel e ninguém
# percebe — a fruta continua funcionando, só feia. Então o teste confere que o
# que está em uso é MESMO o .glb.
func _buki() -> void:
	print("\n-- 5. armas da Buki Buki em .glb --")
	for nome in ["metralhadora", "sniper", "canhao"]:
		var caminho: String = BukiFX.ARMAS[nome]
		_ok(ResourceLoader.exists(caminho), "%s: asset existe (%s)" % [nome, caminho.get_file()])
		var arma := BukiFX._arma(nome)
		_ok(arma != null and str(arma.name).begins_with("Buki_"),
			"%s: em uso é o .glb, não o plano B voxel" % nome)
		if arma:
			var tris := 0
			var ab := AABB()
			var primeiro := true
			for m in _malhas(arma):
				tris += (m as MeshInstance3D).mesh.get_faces().size() / 3
				var a: AABB = (m as MeshInstance3D).transform * (m as MeshInstance3D).mesh.get_aabb()
				ab = a if primeiro else ab.merge(a)
				primeiro = false
			print("     %-14s %5d tris  tam=(%.2f, %.2f, %.2f)" % [nome, tris, ab.size.x, ab.size.y, ab.size.z])
			# A arma aponta pra FRENTE do Godot (−Z). Se o eixo tivesse virado na
			# exportação, ela sairia apontando pra trás e o jogador atiraria em si.
			# Regra única desde que a lâmina saiu: as três são armas de cano, e a
			# lâmina era a exceção que exigia o `if` aqui.
			_ok(ab.position.z < -0.5, "%s: o cano aponta pra frente (−Z)" % nome)
			arma.queue_free()

func _malhas(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		out.append_array(_malhas(c))
	return out

# Amplitude de movimento (max-min) somada dos papéis, em graus.
func _amplitude(a: Animation, roles: Array) -> float:
	if a == null:
		return 0.0
	var total := 0.0
	for i in a.get_track_count():
		if not (String(a.track_get_path(i)).get_slice(":", 0) in roles):
			continue
		var lo := Vector3.ONE * 1e9
		var hi := Vector3.ONE * -1e9
		var t := 0.0
		while t <= a.length:
			var v = a.value_track_interpolate(i, t)
			if v is Vector3:
				lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
				hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
			t += 0.02
		total += rad_to_deg((hi - lo).length())
	return total
