extends SceneTree
# ============================================================================
#  TESTE — Ilha Inicial gerada (relevo em blocos, rio, pontes, praia, assets).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_ilha_inicial.gd [-- mapa.json]
#
#  Sem argumento, confere o MAPA VIVO (só leitura). Duas partes:
#    A. o arquivo: grupos, emendas exatas entre blocos, nada no rio, peças pousadas
#       no chão, nascimento livre;
#    B. o jogo: o Modo História abre o mapa e o jogador DE VERDADE nasce no chão e
#       atravessa as duas pontes andando, sem cair no rio.
#  Progresso de teste em user:// — o de quem joga não é lido nem gravado.
# ============================================================================

const PROGRESSO := "user://test_ilha_progresso.json"
const PONTE_ABAIXO_DO_DECK := 3.2
const MEIA := 256.0

var _falhas := 0
var _caminho := "res://mapas/historia/baseplate.json"
var _mapa: Dictionary
var _blocos: Array[Dictionary] = []


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_caminho = args[0]
	print("\n===== ILHA INICIAL (%s) =====" % _caminho)
	var lido := MapaArquivo.carregar(_caminho)
	_ok(lido["ok"], "mapa válido %s" % str(lido["erros"]).left(200))
	if not lido["ok"]:
		quit(1)
		return
	_mapa = lido["mapa"]
	for p in _mapa["pecas"]:
		if p["tipo"] == "terreno":
			_blocos.append(p)
	_grupos()
	_emendas()
	_rio_e_chao()
	await _no_jogo()
	print("\nILHA_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------- A. arquivo
func _grupos() -> void:
	print("\n-- A1. o que a ilha tem --")
	var por_grupo := {}
	for p in _mapa["pecas"]:
		var g: String = p.get("grupo", "")
		por_grupo[g] = int(por_grupo.get(g, 0)) + 1
	print("     %s" % str(por_grupo))
	_ok(por_grupo.get("relevo", 0) == 64, "64 blocos de relevo (8×8 de 64 m)")
	_ok(por_grupo.get("praia", 0) == 36, "36 blocos no anel de praia")
	_ok(por_grupo.get("pontes", 0) == 2, "2 pontes (uma por cruzamento estrada × rio)")
	_ok(por_grupo.get("coliseu", 0) == 1, "o coliseu")
	_ok(por_grupo.get("vila", 0) >= 30, "vila com %d peças" % por_grupo.get("vila", 0))
	_ok(por_grupo.get("floresta", 0) >= 150, "floresta com %d peças" % por_grupo.get("floresta", 0))
	# 10/10/2026 (pedido do dono): nenhum barco no mapa — eles saem do vendedor de barcos,
	# que fica no porto (`tools/mapa_ilha/colocar_vendedor_de_barcos.gd`).
	var vendedor: bool = _mapa["pecas"].any(func(p): return str(p.get("modelo", "")) == "npc_vendedor_barcos")
	_ok(por_grupo.get("porto", 0) >= 6 and por_grupo.get("navios", 0) == 0 and vendedor,
		"porto (%d) sem barcos no mapa (%d) e com o vendedor de barcos" % [por_grupo.get("porto", 0), por_grupo.get("navios", 0)])
	var bib := BibliotecaDeModelos.padrao()
	var fora := 0
	for p in _mapa["pecas"]:
		if p["tipo"] == "modelo" and not bib.tem(p["modelo"]):
			fora += 1
	_ok(fora == 0, "todo modelo do mapa existe na loja (%d fora)" % fora)
	# Plantação atravessável (decisão do dono, 01/10): a malha de folhas custava 2–5 ms
	# por quadro a quem encostava.
	var colidem := []
	var atravessaveis := 0
	for p in _mapa["pecas"]:
		if p["tipo"] == "modelo" and bib.atravessavel(p["modelo"]):
			atravessaveis += 1
			if p["colisao"]:
				colidem.append(p["id"])
	_ok(bib.atravessavel("crops") and atravessaveis >= 1 and colidem.is_empty(),
		"plantações atravessáveis: %d peças, todas sem colisão %s" % [atravessaveis, str(colidem)])


func _emendas() -> void:
	print("\n-- A2. emendas entre blocos --")
	var pontos := {}       # Vector2i (mm) -> [alturas]
	var borda_ilha := {}   # pontos da borda da baseplate vistos pelos blocos da ilha
	for p in _blocos:
		var r: Dictionary = p["relevo"]
		var n: int = r["celulas"]
		var g := TerrenoDoMapa._grade(r, p["tamanho"])
		for j in n + 1:
			for i in n + 1:
				if i != 0 and j != 0 and i != n and j != n:
					continue
				var v: Vector3 = g[j * (n + 1) + i] + (p["posicao"] as Vector3)
				var chave := Vector2i(roundi(v.x * 1000.0), roundi(v.z * 1000.0))
				if not pontos.has(chave):
					pontos[chave] = []
				pontos[chave].append(v.y)
				if p["grupo"] == "relevo" and (absf(absf(v.x) - MEIA) < 0.001 or absf(absf(v.z) - MEIA) < 0.001):
					borda_ilha[chave] = true
	var pior := 0.0
	var compartilhados := 0
	for chave in pontos:
		var ys: Array = pontos[chave]
		if ys.size() < 2:
			continue
		compartilhados += 1
		for y in ys:
			pior = maxf(pior, absf(float(y) - float(ys[0])))
	_ok(compartilhados > 2000 and pior < 0.0005,
		"%d pontos de borda compartilhados, maior diferença %.6f m (fresta visível ≥ 0,5 mm)" % [compartilhados, pior])
	var soltos := 0
	for chave in borda_ilha:
		if (pontos[chave] as Array).size() < 2:
			soltos += 1
	_ok(borda_ilha.size() > 0 and soltos == 0,
		"borda da ilha × anel de praia: %d pontos, %d sem par (vértice solto = fresta)" % [borda_ilha.size(), soltos])


func _chao(x: float, z: float) -> float:
	for p in _blocos:
		var c: Vector3 = p["posicao"]
		var t: Vector3 = p["tamanho"]
		if absf(x - c.x) <= t.x * 0.5 and absf(z - c.z) <= t.z * 0.5:
			return TerrenoDoMapa.altura_local(p["relevo"], t, x - c.x, z - c.z) + c.y
	return NAN


func _rio_e_chao() -> void:
	print("\n-- A3. peças no lugar --")
	var planta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/mapa_ilha/planta.json"))
	var rio: Dictionary = planta["rio"]
	var no_rio: Array[String] = []
	var flutuando: Array[String] = []
	var enterrado: Array[String] = []
	var pousaveis := ["vila", "fazendas", "floresta", "campos", "coqueiros", "coliseu"]
	for p in _mapa["pecas"]:
		if p["tipo"] != "modelo":
			continue
		var c: Vector3 = p["posicao"]
		var t: Vector3 = p["tamanho"]
		var grupo: String = p.get("grupo", "")
		if grupo != "pontes" and grupo != "navios" and absf(c.x) < MEIA and absf(c.z) < MEIA:
			var largura := lerpf(rio["largura_norte"], rio["largura_sul"], (c.z + MEIA) / (2.0 * MEIA))
			var inclinacao := float(rio["amplitude"]) * PI / MEIA * cos(PI * c.z / MEIA)
			var d := absf(c.x - float(rio["amplitude"]) * sin(PI * c.z / MEIA)) / sqrt(1.0 + inclinacao * inclinacao)
			if d < largura * 0.5:
				no_rio.append(p["id"])
		if grupo in pousaveis:
			var fundo := c.y - t.y * 0.5
			var chao := _chao(c.x, c.z)
			if fundo - chao > 0.15:
				flutuando.append("%s (+%.2f)" % [p["id"], fundo - chao])
			# Os penhascos (`mountain*`) brotam do alto do morro: a base enterrada é o
			# desenho, não erro de pouso.
			if fundo - chao < -3.5 and not String(p["modelo"]).begins_with("mountain"):
				enterrado.append("%s (%.2f)" % [p["id"], fundo - chao])
	_ok(no_rio.is_empty(), "nenhuma peça no leito do rio %s" % str(no_rio.slice(0, 5)))
	_ok(flutuando.is_empty(), "nenhuma peça flutuando (centro da base > 15 cm do chão) %s" % str(flutuando.slice(0, 5)))
	_ok(enterrado.is_empty(), "nenhuma peça enterrada além de 3,5 m %s" % str(enterrado.slice(0, 5)))
	var s: Vector3 = _mapa["spawn"]["posicao"]
	var chao_s := _chao(s.x, s.z)
	_ok(s.y - chao_s > 0.5 and s.y - chao_s < 3.0, "nascimento %.2f m acima do chão (%s)" % [s.y - chao_s, s])
	var dentro := ""
	for p in _mapa["pecas"]:
		if p["tipo"] == "modelo":
			var c: Vector3 = p["posicao"]
			var t: Vector3 = p["tamanho"]
			if absf(s.x - c.x) < t.x * 0.5 and absf(s.z - c.z) < t.z * 0.5 and absf(s.y - c.y) < t.y * 0.5:
				dentro = p["id"]
	_ok(dentro.is_empty(), "nascimento fora de qualquer peça %s" % dentro)


# ---------------------------------------------------------------- B. jogo
func _no_jogo() -> void:
	print("\n-- B. no Modo História, com o jogador de verdade --")
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", _caminho)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	var t0 := Time.get_ticks_msec()
	root.get_node("GameFlow").start_story()
	for i in 150:
		await process_frame
	var jogador: Node3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	_ok(jogador != null, "o Modo História abriu a ilha (%d ms até 150 quadros)" % (Time.get_ticks_msec() - t0))
	if jogador != null:
		for i in 30:
			await physics_frame
		var s: Vector3 = _mapa["spawn"]["posicao"]
		_ok(jogador.is_on_floor() and jogador.global_position.distance_to(s) < 3.0,
			"nasce no chão da praça (%s)" % jogador.global_position)
		_ok(jogador._colisor.shape is CapsuleShape3D, "no Modo História o jogador colide como CÁPSULA (decisão de 01/10/2026)")
		await _pes_na_encosta(jogador)
		await _pes_andando(jogador)
		for p in _mapa["pecas"]:
			if p.get("grupo", "") == "pontes":
				await _atravessar(jogador, p)
		await _encostar_nas_casas(jogador)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))


func _atravessar(jogador: Node3D, ponte: Dictionary) -> void:
	var c: Vector3 = ponte["posicao"]
	var t: Vector3 = ponte["tamanho"]
	var giro := deg_to_rad((ponte["rotacao_graus"] as Vector3).y)
	var dir := Vector3(sin(giro), 0.0, cos(giro))
	var deck := c.y - t.y * 0.5 + PONTE_ABAIXO_DO_DECK
	var inicio := c - dir * (t.z * 0.5 + 5.0)
	inicio.y = _chao(inicio.x, inicio.z) + 1.2
	jogador.global_position = inicio
	jogador.velocity = Vector3.ZERO
	# Câmera virada para o outro lado da ponte; confere o sentido andando um tico.
	jogador._yaw = atan2(-dir.x, -dir.z)
	jogador._update_pivot()
	for i in 20:
		await physics_frame
	_tecla(KEY_W, true)
	for i in 15:
		await physics_frame
	if (jogador.global_position - inicio).dot(dir) < 0.0:
		jogador._yaw += PI
		jogador._update_pivot()
	var menor_y := INF
	var avancou := 0.0
	for i in 60 * 14:
		await physics_frame
		menor_y = minf(menor_y, jogador.global_position.y)
		avancou = (jogador.global_position - inicio).dot(dir)
		if avancou > t.z + 9.0:
			break
	_tecla(KEY_W, false)
	for i in 20:
		await physics_frame
	# Leito do rio fica ~1,5–3 m abaixo do deck: cair na água daria y bem menor.
	_ok(avancou > t.z + 6.0 and menor_y > deck - 1.4 and jogador.is_on_floor(),
		"%s: atravessou %.1f m de %.1f, menor altura %.2f (deck nas pontas %.2f), terminou no chão" % [
		ponte["id"], avancou, t.z, menor_y, deck])


## Pés no chão em encosta: com a caixa, +27 cm a 21° (medido em 01/10/2026).
func _pes_na_encosta(jogador: CharacterBody3D) -> void:
	var esp := jogador.get_world_3d().direct_space_state
	var pior := 0.0
	var mais_ingreme := 0.0
	for ponto in [Vector2(-175, -150), Vector2(-150, -120), Vector2(-120, -100), Vector2(-165, -175)]:
		var h := esp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(ponto.x, 200, ponto.y), Vector3(ponto.x, -50, ponto.y), 1, [jogador.get_rid()]))
		if h.is_empty():
			continue
		mais_ingreme = maxf(mais_ingreme, rad_to_deg((h["normal"] as Vector3).angle_to(Vector3.UP)))
		jogador.global_position = (h["position"] as Vector3) + Vector3.UP * 1.2
		jogador.velocity = Vector3.ZERO
		for i in 60:
			await physics_frame
		var chao := esp.intersect_ray(PhysicsRayQueryParameters3D.create(jogador.global_position, jogador.global_position + Vector3.DOWN * 5, 1, [jogador.get_rid()]))
		var pe := INF
		for mi in jogador._char_model.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh != null:
				pe = minf(pe, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).position.y)
		if not chao.is_empty():
			pior = maxf(pior, pe - float(chao["position"].y))
	# Desde o relevo em blocos (22/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md) a encosta é uma
	# escada de meios blocos: o chão sob os pés é sempre plano (0°). O que vale é a folga.
	var em_blocos := mais_ingreme < 1.0
	_ok((mais_ingreme > 15.0 or em_blocos) and pior < 0.06, "pés no chão nas encostas (%s): maior folga %.3f m" % [
		"relevo em blocos, degraus" if em_blocos else "até %.0f°" % mais_ingreme, pior])


## Pés no chão ANDANDO e CORRENDO: parado o pé sempre encostou; a animação de
## marcha fazia o corpo pairar ~14 cm (bob medido contra a altura agachada, 01/10).
func _pes_andando(jogador: CharacterBody3D) -> void:
	var esp := jogador.get_world_3d().direct_space_state
	var excluir: Array[RID] = [jogador.get_rid(), HurtboxDeCombate.rid_de(jogador)]
	jogador.global_position = Vector3(150, 6, 30)
	jogador.velocity = Vector3.ZERO
	jogador._yaw = atan2(-1.0, 0.0)
	jogador._update_pivot()
	for i in 40:
		await physics_frame
	for correr in [false, true]:
		_tecla(KEY_SHIFT, correr)
		_tecla(KEY_W, true)
		var soma := 0.0
		var n := 0
		var pior := -INF
		for i in 90:
			await physics_frame
			await process_frame
			if i < 20 or not jogador.is_on_floor():
				continue
			var chao := esp.intersect_ray(PhysicsRayQueryParameters3D.create(jogador.global_position + Vector3.UP,
				jogador.global_position + Vector3.DOWN * 5, 1, excluir))
			if chao.is_empty():
				continue
			var pe := INF
			for mi in jogador._char_model.find_children("*", "MeshInstance3D", true, false):
				if (mi as MeshInstance3D).is_visible_in_tree() and (mi as MeshInstance3D).mesh != null:
					pe = minf(pe, ((mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()).position.y)
			var d := pe - float(chao["position"].y)
			soma += d
			pior = maxf(pior, d)
			n += 1
		_tecla(KEY_W, false)
		_tecla(KEY_SHIFT, false)
		for i in 20:
			await physics_frame
		var media := soma / maxf(n, 1)
		_ok(n > 30 and media < 0.05 and pior < 0.07, "%s: pé mais baixo a %+.3f m do chão em média (pior %+.3f; antes ~+0,14)" % [
			"correndo" if correr else "andando", media, pior])


## Andando contra casas da vila: a parada tem que ser rente à parede (raio da cápsula
## + folga), não a metros dela por causa de base/degrau da malha.
func _encostar_nas_casas(jogador: CharacterBody3D) -> void:
	var esp := jogador.get_world_3d().direct_space_state
	var bib := BibliotecaDeModelos.padrao()
	var medidas: Array[float] = []
	for p in _mapa["pecas"]:
		if medidas.size() >= 8:
			break
		if p.get("grupo", "") != "vila" or p["tipo"] != "modelo" or bib.modo_de_colisao(p["modelo"]) != "partes":
			continue
		if (p["tamanho"] as Vector3).y < 4.0:
			continue
		var c: Vector3 = p["posicao"]
		var t: Vector3 = p["tamanho"]
		for ang in [0.0, 90.0, 180.0, 270.0]:
			var d := Vector3(sin(deg_to_rad(ang)), 0, cos(deg_to_rad(ang)))
			var ini := c + d * (maxf(t.x, t.z) * 0.5 + 3.0)
			# O terreno em blocos só tem colisão perto de quem precisa (jogador, entidades): vai até a casa antes de mirar o chão dela.
			jogador.global_position = Vector3(ini.x, 40.0, ini.z)
			jogador.velocity = Vector3.ZERO
			for q in 4:
				await physics_frame
			var h := esp.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(ini.x, 200, ini.z), Vector3(ini.x, -50, ini.z), 1, [jogador.get_rid()]))
			if h.is_empty() or not (String(h["collider"].name).begins_with("relevo") or RelevoEmBlocos.e_relevo(h["collider"])):
				continue
			jogador.global_position = (h["position"] as Vector3) + Vector3.UP * 1.0
			jogador.velocity = Vector3.ZERO
			for i in 10:
				await physics_frame
			for i in 150:
				jogador.velocity.x = -d.x * 3.0
				jogador.velocity.z = -d.z * 3.0
				jogador.velocity.y = 0.0 if jogador.is_on_floor() else jogador.velocity.y - 0.5
				jogador.move_and_slide()
				await physics_frame
			var peito := jogador.global_position + Vector3.UP * 0.3
			var vis := esp.intersect_ray(PhysicsRayQueryParameters3D.create(peito, peito - d * 12.0, 1, [jogador.get_rid()]))
			if not vis.is_empty():
				medidas.append(peito.distance_to(vis["position"]))
			break
	medidas.sort()
	var mediana: float = medidas[medidas.size() / 2] if not medidas.is_empty() else INF
	_ok(medidas.size() >= 5 and mediana < 0.7, "encostando em %d construções: parada mediana a %.2f m da parede (antes 0,5–4,7 m)" % [medidas.size(), mediana])


func _tecla(code: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = apertada
	Input.parse_input_event(ev)
