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
	_ok(dummies == 1, "o dummy de treino continua (saco de pancadas)")
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
	_ok(Melee.COMBO.size() == 3, "combo de 3 passos")
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
	# A hitbox tem que nascer no frame do impacto. Se o `atraso` for maior que a
	# duração tocada, o golpe termina antes de machucar alguém.
	for i in Melee.COMBO.size():
		var g := Melee.passo(i)
		var tocada: float = Melee.clipe(i).length / float(g["vel"])
		_ok(float(g["atraso"]) < tocada,
			"passo %d (%s): hitbox em %.2fs cabe na animação de %.2fs"
				% [i, g["nome"], float(g["atraso"]), tocada])
	var perna := _amplitude(Melee.clipe(2), ["Thigh_R", "Shin_R", "Thigh_L", "Shin_L"])
	var braco := _amplitude(Melee.clipe(2), ["UpperArm_R", "ForeArm_R", "UpperArm_L", "ForeArm_L"])
	print("     chute: pernas %.0f vs braços %.0f" % [perna, braco])
	_ok(perna > braco, "o finalizador é de PERNA")
	_ok(float(Melee.passo(2)["kb"]) > float(Melee.passo(0)["kb"]) * 2.0,
		"o chute empurra mais que o dobro do soco (é ele que joga no buraco)")

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
