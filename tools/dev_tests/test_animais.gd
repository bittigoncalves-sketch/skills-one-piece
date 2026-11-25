extends SceneTree
# ============================================================================
#  TESTE — animais da Ilha Inicial (01/10/2026, docs/ANIMAIS_CHECKPOINT.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_animais.gd
#
#  A. arquivo: fichas dos 30 animais, chefes, a peça `area_animais` (formato), as
#     áreas do mapa vivo (só leitura);
#  B. jogo: o Modo História abre o mapa vivo com o jogador de verdade e confere
#     nascimento (dentro da área, no chão, fora do rio), pés no chão, os quatro
#     comportamentos, chefe preso ao covil, morte (XP pela dificuldade, item "none"), renascer em
#     outro ponto da área, nível de detalhe por distância e animação.
#  Progresso de teste em user:// — o de quem joga não é lido nem gravado.
# ============================================================================

const PROGRESSO := "user://test_animais_progresso.json"
const MAPA := "res://mapas/historia/baseplate.json"
const MORROS := Vector2(-160.0, -140.0)
const RAIO_MORROS := 105.0

var _falhas := 0
var _mapa: Dictionary
var _bib: BibliotecaDeModelos


func _initialize() -> void:
	CliqueDeBlocos.ligado = false      # teste do SOCO direcional: o clique do Minecraft (V5) fica desligado, como `SOCO_ANTIGO=1`
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	seed(20261001)
	print("\n===== ANIMAIS DA ILHA =====")
	_bib = BibliotecaDeModelos.padrao()
	_fichas()
	_formato()
	var lido := MapaArquivo.carregar(MAPA)
	_ok(lido["ok"], "mapa vivo válido")
	if not lido["ok"]:
		quit(1)
		return
	_mapa = lido["mapa"]
	_areas_do_mapa()
	await _no_jogo()
	print("\nANIMAIS_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------- A. arquivo
func _fichas() -> void:
	print("\n-- A1. fichas da loja --")
	var animais: Array[String] = []
	for id in _bib.ids():
		if _bib.categorias_do_modelo(id).has("animais"):
			animais.append(id)
	var sem_ficha := animais.filter(func(id: String) -> bool: return _bib.ficha_de_animal(id).is_empty())
	_ok(animais.size() == 30 and sem_ficha.is_empty(), "30 animais na categoria, todos com ficha (sem: %s)" % str(sem_ficha))
	var chefes := animais.filter(func(id: String) -> bool: return _bib.ficha_de_animal(id)["boss"])
	chefes.sort()
	_ok(chefes == ["gorilla_-_animated_low_poly", "harpia_-_animated_low_poly"], "chefes = gorila e harpia (%s)" % str(chefes))
	var por := {}
	for id in animais:
		var f := _bib.ficha_de_animal(id)
		por[f["comportamento"]] = int(por.get(f["comportamento"], 0)) + 1
	_ok(por == {"presa": 8, "domestico": 14, "territorial": 4, "predador": 4},
		"comportamentos da tabela aprovada %s" % str(por))
	var xp_item := animais.all(func(id: String) -> bool:
		var f := _bib.ficha_de_animal(id)
		return int(f["xp"]) == FichaDeAnimal.xp_por_dificuldade(f) and f["item"] == "none" and not str(f["nome"]).is_empty())
	_ok(xp_item, "todo animal dá o XP da dificuldade (08/10/2026) e o item \"none\", e tem nome de exibição")
	var xp := func(id: String) -> int: return int(_bib.ficha_de_animal(id)["xp"])
	_ok(xp.call("rabbit") < xp.call("deer") and xp.call("deer") < xp.call("bear") and xp.call("bear") < xp.call("gorilla_-_animated_low_poly"),
		"mais difícil dá mais XP: coelho %d < veado %d < urso %d < gorila (chefe) %d" % [xp.call("rabbit"), xp.call("deer"),
		xp.call("bear"), xp.call("gorilla_-_animated_low_poly")])
	_ok(FichaDeAnimal.normalizar({"comportamento": "presa", "corpo": "saltador", "vida": -3}).is_empty(), "ficha com vida negativa recusada")
	_ok(FichaDeAnimal.normalizar({"comportamento": "voa", "corpo": "saltador"}).is_empty(), "comportamento desconhecido recusado")
	_ok(FichaDeAnimal.hostil(_bib.ficha_de_animal("bufalo")) and not FichaDeAnimal.hostil(_bib.ficha_de_animal("rabbit")),
		"territorial/predador são hostis (grupo enemy); presa e doméstico não")


func _formato() -> void:
	print("\n-- A2. a peça area_animais --")
	var base := {"formato": MapaArquivo.FORMATO, "versao": MapaArquivo.VERSAO, "nome": "t",
		"spawn": {"posicao": [0, 1, 0]}, "pecas": []}
	var peca := {"id": "a", "tipo": "area_animais", "posicao": [0, 1, 0], "tamanho": [20, 6, 20],
		"cor": "#40f0a8", "material": "liso", "colisao": true, "especie": "rabbit", "quantidade": 4}
	base["pecas"] = [peca]
	var lido := MapaArquivo.ler_texto(JSON.stringify(base))
	_ok(lido["ok"] and lido["mapa"]["pecas"][0]["quantidade"] == 4 and lido["mapa"]["pecas"][0]["colisao"] == false,
		"área válida lida; colisão sempre desligada (é região, não obstáculo)")
	if lido["ok"]:
		var volta := MapaArquivo.ler_texto(MapaArquivo.para_texto(lido["mapa"]))
		_ok(volta["ok"] and volta["mapa"]["pecas"][0]["especie"] == "rabbit", "ida e volta pelo texto mantém espécie e quantidade")
	for ruim in [{"quantidade": 0}, {"quantidade": 51}, {"quantidade": 2.5}, {"especie": "a b"}, {"especie": null}]:
		var p := peca.duplicate()
		p.merge(ruim, true)
		base["pecas"] = [p]
		_ok(not MapaArquivo.ler_texto(JSON.stringify(base))["ok"], "recusa %s" % str(ruim))


func _areas_do_mapa() -> void:
	print("\n-- A3. áreas no mapa vivo --")
	# Só as da Ilha Inicial: o "~70" foi o pedido para ela. A Ilha dos Macacos (08/10/2026)
	# tem os bandos dela (`macacos_animais_*`, 12 macacos), conferidos em test_ilha_dos_macacos.
	var areas: Array = []
	for p: Dictionary in _mapa["pecas"]:
		if p["tipo"] == "area_animais" and not String(p["id"]).begins_with("macacos_"):
			areas.append(p)
	var total := 0
	var especies := {}
	var sem_ficha := 0
	for a: Dictionary in areas:
		total += int(a["quantidade"])
		especies[a["especie"]] = true
		if _bib.ficha_de_animal(a["especie"]).is_empty():
			sem_ficha += 1
		if _bib.ficha_de_animal(a["especie"]).get("boss", false):
			var c := Vector2(a["posicao"].x, a["posicao"].z)
			_ok(c.distance_to(MORROS) < RAIO_MORROS and int(a["quantidade"]) == 1,
				"chefe %s: 1 só, no covil dos morros (%.0f m do centro)" % [a["especie"], c.distance_to(MORROS)])
	_ok(areas.size() >= 30 and especies.size() == 30, "%d áreas cobrindo as %d espécies" % [areas.size(), especies.size()])
	_ok(total >= 60 and total <= 80, "%d animais na ilha (pedido: ~70)" % total)
	_ok(sem_ficha == 0, "toda área aponta para um animal com ficha")


# --------------------------------------------------------------- B. jogo
func _no_jogo() -> void:
	print("\n-- B. no Modo História, com o jogador de verdade --")
	var modo_script: Script = load("res://src/historia/ModoHistoria.gd")
	modo_script.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo_script.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	var jogador: Node3D = null
	for i in 150:
		await process_frame
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	var modo := current_scene
	var pop := modo.get_node_or_null("Animais") as PopulacaoDeAnimais if modo else null
	_ok(jogador != null and pop != null, "Modo História aberto com a população de animais")
	if jogador == null or pop == null:
		return
	var esperado := 0
	for p in _mapa["pecas"]:
		if p["tipo"] == "area_animais":
			# 10/11/2026: as espécies da ilha toda nascem em dobro (PopulacaoDeAnimais.QUANTIDADE_NA_ILHA_TODA)
			var qtd := int(p["quantidade"])
			if PopulacaoDeAnimais.ESPECIES_PELA_ILHA_TODA.has(String(p["especie"])):
				qtd = maxi(int(ceil(float(qtd) * PopulacaoDeAnimais.QUANTIDADE_NA_ILHA_TODA)), 1)
			esperado += qtd
			var no := modo.find_child(String(p["id"]), true, false) as Node3D
			if no != null and no.visible:
				_ok(false, "volume da área %s aparece no jogo" % p["id"])
	_ok(pop.animais.size() == esperado, "%d de %d animais nasceram" % [pop.animais.size(), esperado])
	_nascimento(pop)
	await _pes_no_chao(pop)
	await _soco_real(pop, jogador)
	await _comportamentos(pop, jogador)
	await _chefe_preso(pop, jogador)
	await _morte_e_renascer(pop, jogador, modo)
	await _detalhe(pop, jogador)
	await _animacao(pop, jogador)
	await _custo(pop, jogador)
	modo_script.set("mapa_forcado", "")
	modo_script.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))


func _nascimento(pop: PopulacaoDeAnimais) -> void:
	var fora := []
	var molhados := []
	var voo_errado := []
	for a in pop.animais:
		var o := a.ponto_de_origem
		var meio: Vector3 = a.area["meio"]
		var c: Vector3 = a.area["centro"]
		if absf(o.x - c.x) > meio.x + 0.01 or absf(o.z - c.z) > meio.z + 0.01:
			fora.append(a.especie)
		var chao := _chao(pop, o, pop.animais)
		if FichaDeAnimal.voa(a.ficha):
			if absf(o.y - chao.y - float(a.ficha["altura_voo"])) > 0.5:
				voo_errado.append(a.especie)
		elif _terreno_molhado(o):
			molhados.append(a.especie)
	_ok(fora.is_empty(), "todos nascem DENTRO da área da espécie %s" % str(fora))
	_ok(molhados.is_empty(), "nenhum bicho de chão nasce no rio %s" % str(molhados))
	_ok(voo_errado.is_empty(), "voadores nascem na altura de voo da espécie %s" % str(voo_errado))


## Pés no chão: corpo apoiado (is_on_floor) e, nos 22 sem esqueleto, a base da malha
## na origem do corpo (erro do dono em 01/10: pé flutuando é a primeira coisa que se vê).
func _pes_no_chao(pop: PopulacaoDeAnimais) -> void:
	var jogador := pop.jogador
	pop.jogador = null                       # sem LOD: todos andam
	for a in pop.animais:
		a.set_physics_process(true)
		a.estado = AnimalDaIlha.Estado.PARADO
		a.set("_relogio", 99.0)
	for i in 45:
		await physics_frame
	var no_ar := []
	var flutua := []
	for a in pop.animais:
		if FichaDeAnimal.voa(a.ficha):
			continue
		if not a.is_on_floor():
			no_ar.append(a.especie)
		if not a.animador.tem_clipes() and a.animador._caranguejo == null:
			var base := _base_da_malha(a)
			if absf(base) > 0.03:
				flutua.append("%s %.2f" % [a.especie, base])
	_ok(no_ar.is_empty(), "todo bicho de chão apoiado no chão depois de cair %s" % str(no_ar))
	_ok(flutua.is_empty(), "malha dos estáticos encosta no chão (±3 cm) %s" % str(flutua))
	pop.jogador = jogador
	for a in pop.animais:
		a.nivel_de_detalhe = -1                 # força reaplicar o LOD
	pop.atualizar_detalhe()


func _base_da_malha(a: AnimalDaIlha) -> float:
	var modelo := a.get_node("Visual/Modelo") as Node3D
	var lo := INF
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		var t := BibliotecaDeModelos._transformacao_ate(mi, a)
		var caixa := t * mi.get_aabb()
		lo = minf(lo, caixa.position.y)
	return lo


## Soco DE VERDADE (`_request_melee`) contra a hitbox de interação (01/10/2026): em jogo
## nenhum animal tomava dano — a cápsula de andar é um cilindro fino no centro e o
## coelho ficava abaixo do punho. Encostado de lado e na ANCA (fora do centro).
func _soco_real(pop: PopulacaoDeAnimais, jogador: Node3D) -> void:
	print("\n-- B1b. soco real na hitbox de interação --")
	var vaca := _um(pop, "cow")
	var t := vaca.tamanho_da_hitbox()
	_ok(t.z > 2.5 and t.y >= 1.6, "hitbox da vaca do tamanho do corpo +30%% (%s)" % t.snapped(Vector3.ONE * 0.01))
	var visual := vaca.get_node("Visual") as Node3D
	var frente := visual.global_transform.basis.z.normalized()
	var lado := visual.global_transform.basis.x.normalized()
	var anca := vaca.global_position - frente * t.z * 0.35
	_ok(await _socar(jogador, vaca, anca, lado, t.x * 0.5 + 0.5) > 0.0, "soco na ANCA da vaca tira vida (fora do centro do corpo)")
	for esp in ["sheep", "chicken"]:
		var bicho := _um(pop, esp)
		var lb := (bicho.get_node("Visual") as Node3D).global_transform.basis.x.normalized()
		_ok(await _socar(jogador, bicho, bicho.global_position, lb, bicho.tamanho_da_hitbox().x * 0.5 + 0.45) > 0.0,
			"soco na altura do peito acerta %s (%.2f m de altura)" % [esp, bicho.altura()])


## Encosta o jogador `dist` ao lado de `ponto`, virado para ele, e dá 3 jabs. Devolve a
## vida tirada. Tenta os dois lados (um tronco pode estar no caminho de um deles).
func _socar(jogador: Node3D, alvo: AnimalDaIlha, ponto: Vector3, lado: Vector3, dist: float) -> float:
	var tirou := 0.0
	for sinal: float in [1.0, -1.0]:
		alvo.health = alvo.max_health
		alvo.set_physics_process(false)      # parado: mede a hitbox, não a fuga
		var p := ponto + lado * dist * sinal
		jogador.global_position = Vector3(p.x, alvo.global_position.y + 0.9, p.z)
		jogador.velocity = Vector3.ZERO
		for i in 12:
			await physics_frame
		if Vector2(jogador.global_position.x - p.x, jogador.global_position.z - p.z).length() > 0.6:
			continue                                 # caiu/escorregou: tenta o outro lado
		var d := ponto - jogador.global_position
		jogador.set("_yaw", atan2(-d.x, -d.z))
		jogador.call("_update_pivot")
		for k in 3:
			jogador._request_melee()
			for i in 40:
				await physics_frame
		tirou = alvo.max_health - alvo.health
		alvo.set_physics_process(true)
		if tirou > 0.0:
			break
	alvo.set_physics_process(true)
	if not alvo.vivo():
		alvo.reviver(alvo.global_position)
	alvo.health = alvo.max_health
	return tirou


func _comportamentos(pop: PopulacaoDeAnimais, jogador: Node3D) -> void:
	print("\n-- B2. comportamentos --")
	# PRESA: o jogador chega a 3 m de um coelho — ele foge.
	var coelho := _um(pop, "rabbit")
	await _encostar(jogador, coelho, 3.0)
	var d0 := _dist(jogador, coelho)
	for i in 90:
		await physics_frame
	_ok(coelho.estado == AnimalDaIlha.Estado.FUGINDO and _dist(jogador, coelho) > d0 + 2.0,
		"presa (coelho) FOGE do jogador: %.1f → %.1f m" % [d0, _dist(jogador, coelho)])
	# DOMÉSTICO: o cão ignora o jogador a 2 m.
	var cao := _um(pop, "dog")
	jogador.health = jogador.max_health
	await _encostar(jogador, cao, 2.0)
	for i in 120:
		await physics_frame
	_ok(cao.estado != AnimalDaIlha.Estado.FUGINDO and cao.estado != AnimalDaIlha.Estado.PERSEGUINDO
		and jogador.health == jogador.max_health, "doméstico (cão) ignora o jogador ao lado")
	# Apanhou: o doméstico corre uns segundos.
	cao.take_damage(1.0, jogador.global_position)
	_ok(cao.estado == AnimalDaIlha.Estado.FUGINDO, "doméstico que apanha corre")
	# TERRITORIAL: o búfalo ataca quem entra no espaço dele.
	var bufalo := _um(pop, "bufalo")
	_ok(bufalo.is_in_group("enemy") and not coelho.is_in_group("enemy"), "búfalo no grupo enemy, coelho não")
	jogador.health = jogador.max_health
	await _encostar(jogador, bufalo, 3.0)
	for i in 240:
		await physics_frame
	_ok(jogador.health < jogador.max_health, "territorial (búfalo) ataca: vida %.0f/%.0f" % [jogador.health, jogador.max_health])
	jogador.health = jogador.max_health
	# O búfalo empurra o jogador (knockback): sem esperar o empurrão acabar, o jogador
	# teleportado para perto do urso continuava sendo arrastado para longe na mesma
	# velocidade da corrida do urso, e a distância não caía (falha intermitente, 01/10).
	_afastar(jogador)
	for i in 90:
		await physics_frame
	jogador.health = jogador.max_health
	# PREDADOR: o urso vem de longe (alerta 14 m). Parte de um ponto LIVRE da área dele
	# (passeando, ele pode ter entrado entre os galhos de um aglomerado de árvore; o
	# destravamento disso tem verificação própria abaixo).
	var urso := _um(pop, "bear")
	urso.global_position = pop.sortear_ponto(urso.area, urso)
	urso.velocity = Vector3.ZERO
	await _encostar(jogador, urso, 11.0)
	var du := _dist(jogador, urso)
	for i in 120:
		await physics_frame
	_ok(urso.estado == AnimalDaIlha.Estado.PERSEGUINDO and _dist(jogador, urso) < du - 3.0,
		"predador (urso) persegue a 11 m: %.1f → %.1f m" % [du, _dist(jogador, urso)])
	jogador.health = jogador.max_health
	_afastar(jogador)


func _chefe_preso(pop: PopulacaoDeAnimais, jogador: Node3D) -> void:
	print("\n-- B3. chefe preso ao covil --")
	var gorila := _um(pop, "gorilla_-_animated_low_poly")
	var c: Vector3 = gorila.area["centro"]
	var meio: Vector3 = gorila.area["meio"]
	# Jogador FORA do covil (6 m além da borda leste), dentro do alerta do gorila.
	gorila.global_position = _chao(pop, Vector3(c.x + meio.x - 3.0, 0, c.z)) + Vector3.UP * 0.1
	jogador.global_position = _chao(pop, Vector3(c.x + meio.x + 6.0, 0, c.z)) + Vector3.UP * 0.5
	jogador.velocity = Vector3.ZERO
	var max_fora := 0.0
	for i in 240:
		await physics_frame
		jogador.health = jogador.max_health
		max_fora = maxf(max_fora, absf(gorila.global_position.x - c.x) - meio.x)
	_ok(max_fora < 2.5 and gorila.estado != AnimalDaIlha.Estado.PERSEGUINDO,
		"com o jogador fora, o gorila não sai do covil (passou %.1f m da borda)" % max_fora)
	# Dentro do covil (6 m para o centro): persegue.
	jogador.global_position = _chao(pop, gorila.global_position - Vector3(6, 0, 0), [gorila]) + Vector3.UP * 0.5
	for i in 30:
		await physics_frame
		jogador.health = jogador.max_health
	_ok(gorila.estado == AnimalDaIlha.Estado.PERSEGUINDO, "jogador DENTRO do covil: o gorila ataca")
	_afastar(jogador)
	for i in 10:
		await physics_frame
	jogador.health = jogador.max_health


func _morte_e_renascer(pop: PopulacaoDeAnimais, jogador: Node3D, modo: Node) -> void:
	print("\n-- B4. morte, XP e renascer --")
	PopulacaoDeAnimais.renasce_em = 1.2
	PopulacaoDeAnimais.boss_renasce_em = 1.2
	var prog: ProgressaoDoPersonagem = modo.get("progressao")
	var cao := _um(pop, "beagle")
	await _encostar(jogador, cao, 4.0)
	var xp0 := prog.xp
	var abatidos := []
	pop.animal_abatido.connect(func(a: AnimalDaIlha): abatidos.append(a))
	var onde_morreu := cao.global_position
	cao.take_damage(9999.0, jogador.global_position)
	cao.take_damage(9999.0, jogador.global_position)     # golpe no cadáver não conta
	var aviso: Label = modo.get("_hud").get("_aviso")
	# XP de abate = recompensa do Mine Piece pela vida/armadura (18/10/2026; era a ficha `xp`).
	var xp_cao := preload("res://src/historia/recompensa_mine_piece.gd").xp_de_abate(cao.max_health, -1.0, -1.0, float(cao.ficha.get("armadura", 0.0)))
	_ok(abatidos.size() == 1 and prog.xp == xp0 + xp_cao and xp_cao > 1, "morte dá o XP do Mine Piece (+%d) uma vez só (xp %d → %d)" % [xp_cao, xp0, prog.xp])
	_ok(aviso != null and aviso.text.contains("Beagle abatido") and aviso.text.contains("+%d XP" % xp_cao),
		"aviso no HUD: \"%s\"" % (aviso.text if aviso else "?"))
	_ok(not cao.is_in_group("enemy") and cao.collision_layer == 0, "cadáver não é alvo nem obstáculo")
	for i in 50:
		await physics_frame
	_ok(not cao.visible, "corpo some antes de renascer")
	for i in 60:
		await physics_frame
	var meio: Vector3 = cao.area["meio"]
	var c: Vector3 = cao.area["centro"]
	_ok(cao.vivo() and cao.health == cao.max_health
		and absf(cao.global_position.x - c.x) <= meio.x + 0.01 and absf(cao.global_position.z - c.z) <= meio.z + 0.01,
		"renasce vivo, vida cheia, num ponto da área (morreu a %.0f m de onde voltou)" % onde_morreu.distance_to(cao.global_position))
	# Chefe: volta ao covil (ponto de origem).
	var harpia := _um(pop, "harpia_-_animated_low_poly")
	harpia.global_position += Vector3(12, 0, 0)
	harpia.take_damage(99999.0)
	for i in 110:
		await physics_frame
	_ok(harpia.vivo() and harpia.global_position.distance_to(harpia.ponto_de_origem) < 0.5,
		"chefe renasce no covil (ponto de origem)")
	PopulacaoDeAnimais.renasce_em = 30.0
	PopulacaoDeAnimais.boss_renasce_em = 300.0


func _detalhe(pop: PopulacaoDeAnimais, jogador: Node3D) -> void:
	print("\n-- B5. nível de detalhe pela distância --")
	# Na praça da vila: há bicho perto, a meia distância e longe.
	jogador.global_position = (_mapa["spawn"]["posicao"] as Vector3) + Vector3.UP
	jogador.velocity = Vector3.ZERO
	for i in 3:
		await physics_frame
	pop.atualizar_detalhe()
	var errados := 0
	var conta := [0, 0, 0]
	for a in pop.animais:
		if not a.vivo():
			continue
		var d := Vector2(a.global_position.x - jogador.global_position.x, a.global_position.z - jogador.global_position.z).length()
		var n := 0 if d <= PopulacaoDeAnimais.ANIMADO_ATE else (1 if d <= PopulacaoDeAnimais.VISIVEL_ATE else 2)
		conta[n] += 1
		var certo := a.nivel_de_detalhe == n and a.visible == (n < 2) and a.animador.ligado == (n == 0) \
			and a.is_physics_processing() == (n < 2)
		if not certo:
			errados += 1
	_ok(errados == 0, "perto anima, médio anda sem animar, longe some e para (perto %d, médio %d, longe %d)" % conta)


func _animacao(pop: PopulacaoDeAnimais, jogador: Node3D) -> void:
	print("\n-- B6. animação --")
	# Vaca RIGGADA (02/10/2026, tools/blender/rig_animais.py): quem anda é o clipe "walk"
	# nos ossos, no ritmo do passeio da ficha; o nó do modelo fica parado.
	var vaca := _um(pop, "cow")
	await _encostar(jogador, vaca, 20.0)
	pop.atualizar_detalhe()
	var modelo := vaca.get_node("Visual/Modelo") as Node3D
	var ap_vaca := modelo.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var sk := modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var pata := sk.find_bone("perna_frente_3.L")
	vaca.estado = AnimalDaIlha.Estado.PASSEANDO
	vaca.set("_destino", vaca.global_position + Vector3(12, 0, 0))
	vaca.set("_relogio", 30.0)
	var zs := []
	for i in 60:
		await physics_frame
		zs.append(sk.get_bone_global_pose(pata).origin.z)
	_ok(ap_vaca.current_animation == "walk" and ap_vaca.is_playing(), "vaca andando toca o clipe walk (%s)" % ap_vaca.current_animation)
	_ok(zs.max() - zs.min() > 0.1, "a pata da frente vai e volta no passo: %.2f m" % (zs.max() - zs.min()))
	var rapidez := Vector2(vaca.velocity.x, vaca.velocity.z).length()
	_ok(absf(ap_vaca.speed_scale - clampf(rapidez / float(vaca.ficha["passeio"]), 0.5, 2.2)) < 0.05,
		"ritmo do clipe = rapidez / passeio (%.2f; %.2f m/s)" % [ap_vaca.speed_scale, rapidez])
	var vida := vaca.health
	vaca.take_damage(1.0, jogador.global_position)
	await physics_frame
	_ok(ap_vaca.current_animation == "damage", "golpe recebido toca o clipe damage (%s)" % ap_vaca.current_animation)
	vaca.health = vida
	# Longe: sem animação (o clipe pausa).
	vaca.animador.ligado = false
	for i in 5:
		await physics_frame
	_ok(not ap_vaca.is_playing(), "sem animação quando desligado (longe): clipe pausado")
	vaca.animador.ligado = true

	var bufalo := _um(pop, "bufalo")
	await _encostar(jogador, bufalo, 25.0)
	pop.atualizar_detalhe()
	bufalo.estado = AnimalDaIlha.Estado.PASSEANDO
	bufalo.set("_destino", bufalo.global_position + Vector3(0, 0, 12))
	bufalo.set("_relogio", 30.0)
	for i in 30:
		await physics_frame
	var ap: AnimationPlayer = bufalo.animador._ap
	_ok(ap != null and ap.is_playing() and ap.current_animation.to_lower().contains("walk"),
		"búfalo (rigado) toca o clipe de andar (%s)" % (ap.current_animation if ap else "?"))
	# Modelo que já veio com ossos ganha dano/ataque/morte pela biblioteca "extra"
	# (tools/mapa_ilha/clipes_dos_riggados.gd), sem tocar no .glb.
	var gorila := _um(pop, "gorilla_-_animated_low_poly")
	var clipes: Dictionary = gorila.animador._clipes
	_ok(str(clipes.get("dano", "")) == "extra/damage" and str(clipes.get("morto", "")) == "extra/death"
		and str(clipes.get("atacando", "")) == "extra/attack",
		"gorila: dano/morte/ataque vêm da biblioteca extra (%s, %s, %s)" % [clipes.get("dano", "-"), clipes.get("morto", "-"), clipes.get("atacando", "-")])
	_ok(str(clipes.get("andando", "")).ends_with("Gorilla_walk"), "gorila: o andar continua o clipe original (%s)" % clipes.get("andando", "-"))

	# Modelo sem esqueleto (a fallback procedural): o corpo inteiro sobe e desce.
	var estatico: AnimalDaIlha = null
	for a in pop.animais:
		if a.vivo() and not a.animador.tem_clipes() and a.ficha.get("corpo", "") in ["quadrupede", "ave_chao"]:
			estatico = a
			break
	if estatico == null:
		print("  (todos os animais têm clipes: sem procedural para medir)")
	else:
		await _encostar(jogador, estatico, 20.0)
		pop.atualizar_detalhe()
		var m2 := estatico.get_node("Visual/Modelo") as Node3D
		estatico.estado = AnimalDaIlha.Estado.PASSEANDO
		estatico.set("_destino", estatico.global_position + Vector3(12, 0, 0))
		estatico.set("_relogio", 30.0)
		var ys := []
		for i in 60:
			await physics_frame
			ys.append(m2.position.y)
		_ok(ys.max() - ys.min() > 0.005, "%s (estático) anda perto: sobe e desce %.3f m" % [estatico.especie, ys.max() - ys.min()])
		estatico.animador.ligado = false
		var parado := m2.position
		for i in 20:
			await physics_frame
		_ok(m2.position == parado, "sem animação quando desligado (longe)")
		estatico.animador.ligado = true
	_afastar(jogador)


func _custo(pop: PopulacaoDeAnimais, jogador: Node3D) -> void:
	print("\n-- B7. custo dos animais (cronometrado direto, headless) --")
	# Cronômetro em volta do _physics_process de cada bicho ativo (o move_and_slide
	# mora lá). NÃO usar o monitor TIME_PHYSICS_PROCESS: ele só muda ~1 vez por
	# segundo e um quadro isolado (teleporte do jogador) vira "média" de 10 ms.
	for lugar in [["vila", (_mapa["spawn"]["posicao"] as Vector3)], ["fazenda", Vector3(125, 0, -150)]]:
		jogador.global_position = _chao_em(lugar[1]) + Vector3.UP
		jogador.velocity = Vector3.ZERO
		pop.atualizar_detalhe()
		var ativos := pop.animais.filter(func(a: AnimalDaIlha) -> bool: return a.nivel_de_detalhe < 2)
		for a: AnimalDaIlha in ativos:
			a.set_physics_process(false)
		var soma := 0
		var pior := 0
		for q in 300:
			await physics_frame
			var t := Time.get_ticks_usec()
			for a: AnimalDaIlha in ativos:
				a._physics_process(1.0 / 60.0)
			var us := Time.get_ticks_usec() - t
			soma += us
			pior = maxi(pior, us)
		for a: AnimalDaIlha in ativos:
			a.set_physics_process(true)
		var media := soma / 300.0 / 1000.0
		_ok(media < 2.0 and pior < 6000, "%s: %d ativos de %d — %.2f ms/quadro (pior quadro %.2f ms)" % [
			lugar[0], ativos.size(), pop.animais.size(), media, pior / 1000.0])


# ------------------------------------------------------------------ apoio
func _um(pop: PopulacaoDeAnimais, especie: String) -> AnimalDaIlha:
	for a in pop.animais:
		if a.especie == especie and a.vivo():
			return a
	return null


## Põe o jogador a `distancia` do bicho num lugar JUSTO: chão de relevo (não em cima de
## um aglomerado de árvores de 12 m) e caminho livre até o bicho na altura do joelho.
func _encostar(jogador: Node3D, animal: AnimalDaIlha, distancia: float) -> void:
	var espaco := root.get_world_3d().direct_space_state
	var inicio := randf() * TAU
	var alvo := animal.global_position + Vector3(distancia, 0, 0)
	var chao := _chao_em(alvo)
	for k in 16:
		var dir := Vector3(1, 0, 0).rotated(Vector3.UP, inicio + k * TAU / 16.0)
		var p := animal.global_position + dir * distancia
		var h := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 300, p.z), Vector3(p.x, -50, p.z), 1, [animal.get_rid()]))
		if h.is_empty() or not String((h["collider"] as Node).get_meta("peca_id", "")).begins_with("relevo"):
			continue
		var de := animal.global_position + Vector3.UP * 0.8
		var ate := (h["position"] as Vector3) + Vector3.UP * 0.8
		var bloqueio := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de, ate, 1, [animal.get_rid()]))
		if not bloqueio.is_empty() and not String((bloqueio["collider"] as Node).get_meta("peca_id", "")).begins_with("relevo"):
			continue
		chao = h["position"]
		break
	jogador.global_position = chao + Vector3.UP * 0.5
	jogador.velocity = Vector3.ZERO
	animal.estado = AnimalDaIlha.Estado.PARADO
	animal.set("_relogio", 99.0)
	animal.get_parent().call("atualizar_detalhe")
	await physics_frame


func _afastar(jogador: Node3D) -> void:
	jogador.global_position = Vector3(0, 60, 250)     # sobre o mar ao sul: longe de todos
	jogador.velocity = Vector3.ZERO


func _dist(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


## Chão sob p. `ignorar`: corpos que o raio atravessa (um bicho parado longe, com a
## física desligada pelo LOD, continua no ponto onde nasceu e o raio bateria nele).
func _chao(pop: PopulacaoDeAnimais, p: Vector3, ignorar: Array = []) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 300, p.z), Vector3(p.x, -50, p.z), 1)
	var rids: Array[RID] = []
	for a: CollisionObject3D in ignorar:
		rids.append(a.get_rid())
	q.exclude = rids
	var h := pop.get_world_3d().direct_space_state.intersect_ray(q)
	return h["position"] if not h.is_empty() else Vector3(p.x, 0, p.z)


func _chao_em(p: Vector3) -> Vector3:
	var h := root.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(p.x, 300, p.z), Vector3(p.x, -50, p.z), 1))
	return h["position"] if not h.is_empty() else Vector3(p.x, 0, p.z)


func _terreno_molhado(p: Vector3) -> bool:
	for t in _mapa["pecas"]:
		if t["tipo"] != "terreno":
			continue
		var pos: Vector3 = t["posicao"]
		var tam: Vector3 = t["tamanho"]
		if absf(p.x - pos.x) <= tam.x * 0.5 and absf(p.z - pos.z) <= tam.z * 0.5:
			return TerrenoDoMapa.molhado_local(t["relevo"], tam, p.x - pos.x, p.z - pos.z)
	return false
