extends SceneTree
# ============================================================================
#  TESTE — Ilha dos Macacos (08/10/2026, docs/ILHA_DOS_MACACOS_PLANO.md, etapa 1).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_ilha_dos_macacos.gd [-- mapa.json]
#
#  Sem argumento, confere o MAPA VIVO (só leitura). Três partes:
#    A. o arquivo: placa, relevo e praia com a MESMA conta da ilha inicial (emendas
#       exatas), morros, chão de mata, trilha, píer, macacos, grupos, distância;
#    B. o mar: água entre as ilhas e UM fundo do mar por ilha, que se encontram no meio
#       sem sobrepor e sem degrau na costa;
#    C. o jogo: o Modo História abre o mapa, o jogador fica de pé na clareira e nada no
#       meio do caminho, e os 12 macacos nascem nos 4 bandos.
#  Progresso de teste em user:// — o de quem joga não é lido nem gravado.
# ============================================================================

const PROGRESSO := "user://test_ilha_dos_macacos_progresso.json"
const CENTRO := Vector2(1500, 0)
const MEIA := 128.0
const MACACO := "monkey_-_animated_low_poly"

var _falhas := 0
var _caminho := "res://mapas/historia/baseplate.json"
var _mapa: Dictionary
var _blocos: Array[Dictionary] = []      # todos os blocos de terreno do mapa
var _meus: Array[Dictionary] = []        # só os da Ilha dos Macacos


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
	print("\n===== ILHA DOS MACACOS (%s) =====" % _caminho)
	var lido := MapaArquivo.carregar(_caminho)
	_ok(lido["ok"], "mapa válido %s" % str(lido["erros"]).left(200))
	if not lido["ok"]:
		quit(1)
		return
	_mapa = lido["mapa"]
	for p in _mapa["pecas"]:
		if p["tipo"] == "terreno":
			_blocos.append(p)
			if String(p["id"]).begins_with("macacos_"):
				_meus.append(p)
	_arquivo()
	_emendas()
	await _mar()
	await _no_jogo()
	print("\nMACACOS_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


func _peca(id: String) -> Dictionary:
	for p in _mapa["pecas"]:
		if p["id"] == id:
			return p
	return {}


func _chao(x: float, z: float) -> float:
	for p in _blocos:
		var c: Vector3 = p["posicao"]
		var t: Vector3 = p["tamanho"]
		if absf(x - c.x) <= t.x * 0.5 and absf(z - c.z) <= t.z * 0.5:
			return TerrenoDoMapa.altura_local(p["relevo"], t, x - c.x, z - c.z) + c.y
	return NAN


# ------------------------------------------------------------- A. arquivo
func _arquivo() -> void:
	print("\n-- A1. a ilha no arquivo --")
	var base := _peca("baseplate_macacos")
	_ok(not base.is_empty() and base["tipo"] == "caixa" and (base["posicao"] as Vector3).is_equal_approx(Vector3(1500, -1, 0))
		and (base["tamanho"] as Vector3).is_equal_approx(Vector3(256, 2, 256)),
		"placa `baseplate_macacos` 256 × 256 m com centro em (1500, 0)")
	var principal := _peca("baseplate")
	var vao := 1500.0 - MEIA - ((principal["posicao"] as Vector3).x + (principal["tamanho"] as Vector3).x * 0.5)
	_ok(vao > 1000.0 and vao < 1300.0, "afastada da ilha inicial: %.0f m de mar entre as placas" % vao)
	var relevo := _meus.filter(func(p: Dictionary) -> bool: return p["grupo"] == "macacos_relevo")
	var praia := _meus.filter(func(p: Dictionary) -> bool: return p["grupo"] == "macacos_praia")
	_ok(relevo.size() == 16 and praia.size() == 20, "16 blocos de relevo (4 × 4 de 64 m) e 20 de praia (%d, %d)" % [relevo.size(), praia.size()])
	var t0: Vector3 = _blocos[0]["tamanho"]
	var mesmos := true
	for p in _blocos:
		var tp: Vector3 = p["tamanho"]
		mesmos = mesmos and is_equal_approx(tp.y, t0.y) and is_equal_approx((p["posicao"] as Vector3).y - tp.y * 0.5, -1.5)
	_ok(mesmos, "todos os blocos do mapa com o mesmo fundo (−1,5) e a mesma altura (%.1f m): pincel de relevo e emendas" % t0.y)
	var maior := -INF
	var codigos := {}
	for p: Dictionary in relevo:
		var c: Vector3 = p["posicao"]
		var t: Vector3 = p["tamanho"]
		var r: Dictionary = p["relevo"]
		for a in (r["alturas"] as PackedInt32Array):
			maior = maxf(maior, float(a) / TerrenoDoMapa.ESCALA * t.y - t.y * 0.5 + c.y)
		for s in (r["solo"] as PackedByteArray):
			codigos[s] = int(codigos.get(s, 0)) + 1
	_ok(maior > 15.0 and maior < 28.0, "morros: o mais alto a %.1f m (cabe no bloco)" % maior)
	var total := 0
	for k in codigos:
		total += codigos[k]
	var mata := float(codigos.get(5, 0)) / total
	_ok(mata > 0.4, "chão de mata (onde as árvores gigantes vão entrar) em %.0f %% da ilha" % (mata * 100.0))
	_ok(codigos.get(2, 0) > 100 and codigos.get(3, 0) > 500, "trilha e clareira de terra (%d células) e areia na costa (%d)" % [
		codigos.get(2, 0), codigos.get(3, 0)])
	# Praia: da borda da placa (no nível dela) até abaixo do mar.
	var na_borda := _chao(1500.0 - MEIA + 0.01, 40.0)
	var fora := _chao(1500.0 - MEIA - 23.0, 40.0)
	_ok(absf(na_borda - 0.04) < 0.05 and fora < -0.9, "praia: %.2f m na borda da placa, %.2f m a 23 m dela (mar a −0,65)" % [na_borda, fora])

	print("\n-- A2. píer, macacos e grupos --")
	# v2 (22/11/2026): o `dock_long` saiu; o cais é o modelo temático `macacos_cais` (Blender), girado 90° (a ponta aponta para −X), com o piso a +0,6 m.
	var pier := _peca("macacos_vila_cais")
	var ok_pier: bool = not pier.is_empty() and pier["modelo"] == "macacos_cais"
	if ok_pier:
		var c: Vector3 = pier["posicao"]
		var ponta := c.x - (pier["tamanho"] as Vector3).z * 0.5
		ok_pier = is_equal_approx((pier["rotacao_graus"] as Vector3).y, 90.0) and absf(c.z) < 0.1 and _chao(ponta + 1.0, 0.0) < -0.9
		print("     cais em %s, ponta em x=%.1f sobre fundo %.2f m" % [c, ponta, _chao(ponta + 1.0, 0.0)])
	_ok(ok_pier, "cais rústico na costa oeste, ponta sobre o mar")
	var bandos := 0
	var macacos := 0
	var errados: Array[String] = []
	for p in _mapa["pecas"]:
		if p["tipo"] != "area_animais" or not String(p["id"]).begins_with("macacos_") or p["especie"] == "gorila_rei":
			continue
		bandos += 1
		macacos += int(p["quantidade"])
		var c: Vector3 = p["posicao"]
		var t: Vector3 = p["tamanho"]
		var chao := _chao(c.x, c.z)
		if p["especie"] != MACACO or absf(c.x - CENTRO.x) + t.x * 0.5 > MEIA or absf(c.z - CENTRO.y) + t.z * 0.5 > MEIA \
				or chao < c.y - t.y * 0.5 or chao > c.y + t.y * 0.5:
			errados.append(p["id"])
	_ok(bandos == 4 and macacos == 12 and errados.is_empty(), "4 bandos de macacos (%d animais), dentro da placa e abraçando o chão %s" % [
		macacos, str(errados)])
	var pais := {}
	for g in _mapa["grupos"]:
		pais[g["id"]] = g["pai"]
	var filhos := true
	for g in ["macacos_relevo", "macacos_praia", "macacos_porto", "macacos_animais"]:
		filhos = filhos and pais.get(g, "") == "ilha_dos_macacos"
	_ok(pais.get("ilha_dos_macacos", "?") == "" and filhos, "grupo \"ilha_dos_macacos\" com relevo, praia, porto e animais dentro")


func _emendas() -> void:
	print("\n-- A3. emendas (relevo × relevo × praia) --")
	var pontos := {}
	var borda := {}
	for p in _meus:
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
				if p["grupo"] == "macacos_relevo" and (absf(absf(v.x - CENTRO.x) - MEIA) < 0.001 or absf(absf(v.z - CENTRO.y) - MEIA) < 0.001):
					borda[chave] = true
	var pior := 0.0
	var compartilhados := 0
	for chave in pontos:
		var ys: Array = pontos[chave]
		if ys.size() < 2:
			continue
		compartilhados += 1
		for y in ys:
			pior = maxf(pior, absf(float(y) - float(ys[0])))
	var soltos := 0
	for chave in borda:
		if (pontos[chave] as Array).size() < 2:
			soltos += 1
	_ok(compartilhados > 500 and pior < 0.0005, "%d pontos de borda compartilhados, maior diferença %.6f m" % [compartilhados, pior])
	_ok(borda.size() > 0 and soltos == 0, "borda da ilha × anel de praia: %d pontos, %d sem par (vértice solto = fresta)" % [
		borda.size(), soltos])


# ----------------------------------------------------------------- B. mar
func _mar() -> void:
	print("\n-- B. o mar entre as ilhas --")
	var mundo := Node3D.new()
	root.add_child(mundo)
	MapaMontador.montar(mundo, _mapa)
	var oceano: Node3D = load("res://src/world/oceano_historia.gd").new()
	mundo.add_child(oceano)
	oceano.configurar(_mapa)
	AguaDoMundo.registrar(_mapa, oceano)
	_ok(AguaDoMundo._no_mar(800.0, 0.0) and not AguaDoMundo._no_mar(1500.0, 0.0) and not AguaDoMundo._no_mar(0.0, 0.0),
		"mar no meio do caminho (800, 0); terra nas duas ilhas")
	var fundos := FundoDoMar.montar_por_ilha(mundo, _mapa, oceano.get("bases"))
	var nomes := fundos.map(func(f: FundoDoMar) -> String: return String(f.name))
	print("     fundos: %s" % ", ".join(fundos.map(func(f: FundoDoMar) -> String: return "%s (%d blocos)" % [f.name, f.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D).size()])))
	# Um por ilha do cadastro (17/10/2026: a Ilha do East Blue é a 3ª).
	var n_ilhas: int = preload("res://src/historia/ilhas/ilhas.gd").TABELA.size()
	_ok(fundos.size() == n_ilhas and "FundoDoMar" in nomes and "FundoDoMar_macacos" in nomes, "um fundo do mar por ilha (%d de %d)" % [fundos.size(), n_ilhas])
	# Relevo marinho (14/10/2026): blocos de uma grade GLOBAL, cada um da ilha mais perto —
	# nenhum bloco nos dois fundos (o encontro no meio é contínuo por construção).
	if fundos.size() == 2:
		var de_a := {}
		var nos_dois := 0
		for n in fundos[0].get_children():
			if n is MeshInstance3D:
				de_a[n.name] = true
		for n in fundos[1].get_children():
			if n is MeshInstance3D and de_a.has(n.name):
				nos_dois += 1
		_ok(nos_dois == 0, "os fundos se encontram no meio sem sobrepor (%d blocos repetidos)" % nos_dois)
	for i in 3:
		await physics_frame
	var espaco := mundo.get_world_3d().direct_space_state
	var raio := func(x: float, z: float) -> float:
		var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -120, z)))
		return float(hit["position"].y) if not hit.is_empty() else NAN
	var meio_e: float = raio.call(810.0, 30.0)
	var meio_d: float = raio.call(818.0, 30.0)
	# No meio do caminho passa a fossa (decisão do dono, 14/10: 60–80 m entre as ilhas).
	_ok(meio_e < -56.0 and meio_d < -56.0 and absf(meio_e - meio_d) < 4.0,
		"no encontro, fundo contínuo e fundo (fossa): %.2f | %.2f" % [meio_e, meio_d])
	# Borda de fora do anel de praia (24 m da placa): a areia termina um pouco acima do
	# fundo, que segue descendo por baixo dela. É o desenho da ilha inicial (o fundo
	# encosta na borda da PLACA); a dos macacos tem de ficar igual.
	var degrau_macacos: float = raio.call(1500.0 - MEIA - 23.9, 60.0) - raio.call(1500.0 - MEIA - 24.1, 60.0)
	var degrau_inicial: float = raio.call(256.0 + 23.9, -60.0) - raio.call(256.0 + 24.1, -60.0)
	var perto: float = raio.call(1500.0 - MEIA - 70.0, 60.0)
	_ok(absf(degrau_macacos - degrau_inicial) < 0.25 and perto < -3.0 and perto > -14.0,
		"costa como a da ilha inicial: fim da areia %.2f m acima do fundo (inicial %.2f m); a 70 m da placa, %.1f m" % [
			degrau_macacos, degrau_inicial, perto])
	AguaDoMundo.esquecer()
	mundo.queue_free()
	await process_frame


# ---------------------------------------------------------------- C. jogo
## Etapa 2: o detector marca a ilha, avisa a chegada, a visita sobe o teto e vai para o
## save. O jogador acabou de ser posto na clareira (veio da Ilha Inicial).
func _chegada(jogador: CharacterBody3D) -> void:
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var aviso: Label = current_scene.get("_hud").get("_aviso")
	for i in 45:
		await physics_frame
	_ok(prog.ilha == "ilha_dos_macacos" and "ilha_dos_macacos" in prog.ilhas_visitadas,
		"pisou na ilha: está na Ilha dos Macacos, visitada (%s)" % prog.ilha)
	_ok(aviso.visible and aviso.text.begins_with("Você chegou à Ilha dos Macacos"),
		"aviso de chegada: \"%s\"" % aviso.text)
	var salvo := ProgressaoDoPersonagem.carregar(PROGRESSO)
	_ok(salvo != null and "ilha_dos_macacos" in salvo.ilhas_visitadas, "a visita foi para o save (arquivo de teste)")
	# Volta à Ilha Inicial e de novo aos macacos: avisa, mas não é "primeira vez".
	var s: Vector3 = _mapa["spawn"]["posicao"]
	jogador.global_position = s
	for i in 45:
		await physics_frame
	_ok(prog.ilha == "ilha_inicial" and aviso.text == "Você chegou à Ilha Inicial", "de volta: \"%s\"" % aviso.text)
	jogador.global_position = Vector3(1488, _chao(1488, 4) + 1.2, 4)
	for i in 45:
		await physics_frame
	_ok(aviso.text == "Você chegou à Ilha dos Macacos", "segunda chegada sem repetir o teto: \"%s\"" % aviso.text)


func _no_jogo() -> void:
	print("\n-- C. no Modo História, com o jogador de verdade --")
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", _caminho)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 150:
		await process_frame
	var jogador: CharacterBody3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	_ok(jogador != null, "o Modo História abriu o mapa")
	if jogador != null:
		var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
		_ok(prog.ilha == "ilha_inicial" and prog.ilhas_visitadas == ["ilha_inicial"],
			"nasce na Ilha Inicial, só ela visitada")
		var clareira := Vector2(1488, 4)
		jogador.global_position = Vector3(clareira.x, _chao(clareira.x, clareira.y) + 1.2, clareira.y)
		jogador.velocity = Vector3.ZERO
		for i in 60:
			await physics_frame
		var acima := jogador.global_position.y - _chao(jogador.global_position.x, jogador.global_position.z)
		_ok(jogador.is_on_floor() and acima > 0.0 and acima < 1.5, "de pé na clareira da Ilha dos Macacos (%.2f m acima do chão)" % acima)
		await _chegada(jogador)
		var nivel := AguaDoMundo.nivel_em(800.0, 0.0)
		jogador.global_position = Vector3(800.0, nivel - 0.3, 0.0)
		jogador.velocity = Vector3.ZERO
		for i in 120:
			await physics_frame
		_ok(jogador.get("modo_na_agua") == "nadando", "no meio do caminho o jogador nada (%s)" % str(jogador.get("modo_na_agua")))
		_ok(prog.ilha == "", "no mar o jogador não está em ilha nenhuma")
	var pop := current_scene.get_node_or_null("Animais") as PopulacaoDeAnimais
	var na_ilha := 0
	var fora_da_area := 0
	if pop != null:
		for a in pop.animais:
			if not is_instance_valid(a) or not String(a.area.get("id", "")).begins_with("macacos_") or a.especie == "gorila_rei":
				continue
			na_ilha += 1
			var p: Vector3 = a.global_position
			if absf(p.x - CENTRO.x) > MEIA or absf(p.z - CENTRO.y) > MEIA:
				fora_da_area += 1
	_ok(na_ilha == 12 and fora_da_area == 0, "os 12 macacos nasceram na ilha (%d, %d fora dela)" % [na_ilha, fora_da_area])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
