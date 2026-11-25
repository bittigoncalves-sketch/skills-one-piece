extends SceneTree
# ============================================================================
#  TESTE DOS INIMIGOS DO MODO HISTÓRIA (16/09/2026).
#
#  Pedido do dono: inimigos com vida, piscando vermelho ao tomar dano; o inimigo
#  é a peça cujo modelo está na categoria "inimigos" da loja. Decisões: some ao
#  zerar a vida e dá XP aleatório de 5 a 20.
#
#    A. só a peça com a categoria vira inimigo (controle: o mesmo .glb sem a
#       categoria continua cenário);
#    B. golpe de VERDADE (`_request_melee`, a hitbox real do corpo a corpo) tira
#       vida e pisca — e o Civil, com a trava, não tira (controle da trava);
#    C. dano 0 não tira vida nem pisca; zerar a vida some com a peça, dá XP entre
#       5 e 20 e avisa o mesmo número na tela;
#    D. (30/09/2026) o inimigo RENASCE no mesmo lugar, com a vida cheia, e dá XP de
#       novo. O teste encurta o minuto do jogo para 1 s.
#
#  Desde 30/09/2026 o jogador do Modo História já nasce com Combate 1 (bate desde o
#  começo); a trava do Civil continua sendo medida, pondo `civil()` à mão.
#
#  Biblioteca e mapa de TESTE em `user://test_inimigos/` — a loja, o mapa e o
#  progresso de quem joga não são tocados.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_inimigos_historia.gd
# ============================================================================

const RAIZ := "user://test_inimigos"
const MODELOS := RAIZ + "/modelos"
const MAPA := RAIZ + "/mapa.json"
const PROGRESSO := RAIZ + "/progresso.json"
const GLB := "res://assets/models/arvore_voxel.glb"

var _falhas := 0


func _init() -> void:
	CliqueDeBlocos.ligado = false      # teste do SOCO direcional: o clique do Minecraft (V5) fica desligado, como `SOCO_ANTIGO=1`
	await process_frame
	print("\n===== INIMIGOS DO MODO HISTÓRIA =====")
	_limpar()
	var bib := _biblioteca()
	if bib == null:
		quit(1)
		return
	_escrever_mapa(bib)

	var tempo_original := InimigoDoMapa.tempo_de_renascer
	InimigoDoMapa.tempo_de_renascer = 1.0
	var modo: GDScript = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", PROGRESSO)
	MapaMontador.biblioteca = bib
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame

	var cena := current_scene
	var mapa := cena.get_node_or_null("Mapa") if cena else null
	var jogador: Node = cena.call("jogador_local") if cena and cena.has_method("jogador_local") else null
	_ok(mapa != null and jogador != null, "a cena do Modo História subiu com mapa e jogador")
	if mapa != null and jogador != null:
		_marcacao(mapa)
		await _golpe_real(mapa.get_node_or_null("inimigo_frente"), jogador)
		await _morte_e_xp(cena, mapa.get_node_or_null("inimigo_longe"))

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	MapaMontador.biblioteca = null
	InimigoDoMapa.tempo_de_renascer = tempo_original
	_limpar()
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


# ------------------------------------------------------------------ montagem
## Dois modelos do MESMO .glb: só um recebe a categoria. Assim a única diferença
## entre inimigo e cenário é a etiqueta — é ela que o teste mede.
func _biblioteca() -> BibliotecaDeModelos:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELOS))
	var bib := BibliotecaDeModelos.new(MODELOS)
	var r := ImportadorDeModelos.importar(bib, ProjectSettings.globalize_path(GLB))
	if not r.get("ok", false):
		_ok(false, "importar o .glb de teste: %s" % r)
		return null
	var id: String = r["id"]
	var copia := (bib.info(id) as Dictionary)
	copia["id"] = "arvore_cenario"
	copia["nome"] = "Árvore cenário"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(bib.caminho_do_arquivo(id)),
		ProjectSettings.globalize_path(bib.caminho_do_arquivo("arvore_cenario")))
	bib.adicionar(copia)
	var cat := bib.criar_categoria("inimigos")
	_ok(cat.get("id", "") == InimigoDoMapa.CATEGORIA, "criar \"inimigos\" na loja dá o id que o jogo procura (%s)" % cat.get("id", ""))
	var so_um: Array[String] = [id]
	bib.marcar_categoria(so_um, InimigoDoMapa.CATEGORIA, true)
	bib.set_meta("id_inimigo", id)
	return bib


func _escrever_mapa(bib: BibliotecaDeModelos) -> void:
	var id: String = bib.get_meta("id_inimigo")
	var pecas := [
		{"id": "baseplate", "tipo": "caixa", "posicao": [0, -1, 0], "rotacao_graus": [0, 0, 0],
			"tamanho": [128, 2, 128], "cor": "#767676", "material": "grade", "grade_celula": 4, "colisao": true},
		# À frente do spawn (o jogador nasce olhando para −Z).
		_modelo("inimigo_frente", id, [0, 1, -2.3]),
		_modelo("inimigo_longe", id, [20, 1, -20]),
		_modelo("cenario", "arvore_cenario", [-20, 1, -20]),
	]
	var mapa := {"formato": "skills-one-piece/mapa", "versao": 1, "nome": "Teste inimigos",
		"spawn": {"posicao": [0, 1, 0]}, "pecas": pecas}
	var f := FileAccess.open(MAPA, FileAccess.WRITE)
	f.store_string(JSON.stringify(mapa, "\t"))
	f.close()


func _modelo(id: String, modelo: String, pos: Array) -> Dictionary:
	return {"id": id, "tipo": "modelo", "modelo": modelo, "posicao": pos, "rotacao_graus": [0, 0, 0],
		"tamanho": [1.4, 2, 1.4], "cor": "#ffffff", "material": "liso", "grade_celula": 4, "colisao": true}


# --------------------------------------------------------------------- A
func _marcacao(mapa: Node) -> void:
	print("\n-- A. a categoria marca o inimigo --")
	var frente := mapa.get_node_or_null("inimigo_frente")
	var cenario := mapa.get_node_or_null("cenario")
	_ok(frente is InimigoDoMapa, "peça com modelo da categoria \"inimigos\" virou inimigo")
	_ok(frente != null and frente.is_in_group("enemy"), "o inimigo está no grupo \"enemy\" (mira e técnicas de área)")
	_ok(frente is InimigoDoMapa and is_equal_approx(frente.health, InimigoDoMapa.VIDA_PADRAO),
		"nasce com a vida cheia (%.0f)" % (frente.health if frente is InimigoDoMapa else -1.0))
	_ok(cenario != null and not (cenario is InimigoDoMapa) and not cenario.has_method("take_damage"),
		"controle: o MESMO .glb sem a categoria continua cenário")
	_ok(frente != null and frente.get_node_or_null("Modelo") != null and frente.get_node_or_null("Colisao") != null,
		"virar inimigo não apagou o modelo nem a colisão da peça")


# --------------------------------------------------------------------- B
func _golpe_real(inimigo: Node, jogador: Node) -> void:
	print("\n-- B. golpe de verdade --")
	if not (inimigo is InimigoDoMapa):
		_ok(false, "sem inimigo à frente para bater")
		return
	for i in 30:
		await physics_frame
	# ⚠️ PERTO do inimigo, e ANTES do controle do Civil. O corpo a corpo do Modo
	# História (combate direcional, desde 16/09/2026) não tem o puxão automático do M1
	# da arena. MEDIDO: o jab avança o corpo 0,25 m e leva a mão 0,53 m à frente do
	# centro (+0,12 de raio). Partindo a 1,6 m do centro do inimigo (frente da
	# colisão a 0,7) a esfera encosta com margem ZERO e não acerta; a 1,4 m ou menos
	# acerta sempre. Do spawn (2,3 m) nenhum golpe chegaria, e "o Civil não tira
	# vida" passaria sem provar nada.
	jogador.global_position = Vector3(inimigo.global_position.x, jogador.global_position.y, inimigo.global_position.z + 1.3)
	jogador.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	print("  jogador em %s, inimigo em %s" % [jogador.global_position, inimigo.global_position])

	_ok(jogador.capacidades.can_attack, "o jogador do Modo História já nasce podendo bater (Combate 1)")
	# Controle da trava: o Civil pede o golpe e não tira vida.
	jogador.capacidades = CapacidadesDoJogador.civil()
	jogador._request_melee()
	for i in 45:
		await physics_frame
	_ok(is_equal_approx(inimigo.health, InimigoDoMapa.VIDA_PADRAO), "Civil (sem combate) não tira vida (%.0f)" % inimigo.health)

	jogador.capacidades = CapacidadesDoJogador.completas()
	var piscou := false
	jogador._request_melee()
	for i in 45:
		await physics_frame
		if not piscou and _tem_sobreposicao(inimigo):
			piscou = true
	var tirou: float = InimigoDoMapa.VIDA_PADRAO - inimigo.health
	_ok(tirou > 0.0, "com combate liberado, o soco real tira vida (%.0f)" % tirou)
	_ok(piscou, "o modelo pisca vermelho ao tomar o golpe")
	for i in 40:
		await physics_frame
	_ok(not _tem_sobreposicao(inimigo), "o vermelho some depois")
	jogador.capacidades = CapacidadesDoJogador.civil()

	# Dano 0 (empurrão extra do corpo a corpo): nem vida nem pisca.
	var antes: float = inimigo.health
	inimigo.take_damage(0.0, Vector3.ZERO, Vector3.FORWARD * 5.0, 0.2)
	await process_frame
	_ok(is_equal_approx(inimigo.health, antes) and not _tem_sobreposicao(inimigo), "dano 0 não tira vida nem pisca")


func _tem_sobreposicao(inimigo: Node) -> bool:
	var pilha: Array[Node] = [inimigo.get_node_or_null("Modelo")]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		if n == null:
			continue
		if n is GeometryInstance3D and (n as GeometryInstance3D).material_overlay != null:
			return true
		pilha.append_array(n.get_children())
	return false


# --------------------------------------------------------------------- C
func _morte_e_xp(cena: Node, inimigo: Node) -> void:
	print("\n-- C. derrota: some e dá XP --")
	if not (inimigo is InimigoDoMapa):
		_ok(false, "sem o segundo inimigo")
		return
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	var xp_antes: int = prog.xp
	var nivel_antes: int = prog.nivel
	var ref: WeakRef = weakref(inimigo)
	var derrotas := [0]
	inimigo.derrotado.connect(func(_i): derrotas[0] += 1)
	inimigo.take_damage(InimigoDoMapa.VIDA_PADRAO - 1.0)
	_ok(inimigo.health > 0.0 and prog.xp == xp_antes, "quase morto: ainda de pé e sem XP")
	inimigo.take_damage(50.0)
	# Um segundo golpe no mesmo quadro (outra hitbox do mesmo ataque) não conta de novo.
	inimigo.take_damage(50.0)
	var ganho: int = prog.xp - xp_antes
	_ok(derrotas[0] == 1, "a derrota é avisada UMA vez (%d)" % derrotas[0])
	# XP do abate = a recompensa do mod pela vida da vítima (18/10/2026, F6; antes sorteava de 5 a 20), sujeita ao anti-farm.
	var esperado_xp: int = preload("res://src/historia/recompensa_mine_piece.gd").xp_de_abate(InimigoDoMapa.VIDA_PADRAO)
	_ok(ganho > 0 and ganho <= esperado_xp and prog.nivel >= nivel_antes, "XP ganho = recompensa do mod (%d de %d, com o anti-farm)" % [ganho, esperado_xp])
	var aviso := _texto_do_aviso(cena)
	_ok(aviso.contains("+%d XP" % ganho), "a tela avisa o mesmo XP (\"%s\")" % aviso)
	await process_frame
	await process_frame
	_ok(ref.get_ref() != null and not inimigo.visible and inimigo.collision_layer == 0
		and not inimigo.is_in_group("enemy"),
		"o inimigo derrotado sumiu da cena (invisível, sem colisão, fora do grupo) — adormecido para renascer")

	print("\n-- D. renasce no mesmo lugar --")
	var onde: Vector3 = inimigo.global_position
	_ok(inimigo.falta_para_renascer() > 0.0, "conta o tempo para voltar (%.1f s)" % inimigo.falta_para_renascer())
	for i in 150:
		await physics_frame
		if inimigo.vivo():
			break
	_ok(inimigo.vivo() and inimigo.visible and inimigo.collision_layer != 0 and inimigo.is_in_group("enemy"),
		"renasceu: visível, com colisão e no grupo (tempo encurtado para %.0f s)" % InimigoDoMapa.tempo_de_renascer)
	_ok(inimigo.global_position.is_equal_approx(onde) and is_equal_approx(inimigo.health, InimigoDoMapa.VIDA_PADRAO),
		"no MESMO lugar do editor e com a vida cheia (%.0f)" % inimigo.health)
	var xp_de_novo: int = prog.xp
	inimigo.take_damage(InimigoDoMapa.VIDA_PADRAO + 1.0)
	_ok(prog.xp > xp_de_novo and derrotas[0] == 2, "derrotado de novo, dá XP de novo (+%d)" % (prog.xp - xp_de_novo))



func _texto_do_aviso(cena: Node) -> String:
	var hud := cena.get_node_or_null("HistoriaHud")
	var rotulo = hud.get("_aviso") if hud else null
	return String(rotulo.text) if rotulo is Label else ""


func _limpar() -> void:
	_apagar(ProjectSettings.globalize_path(RAIZ))


func _apagar(caminho: String) -> void:
	var d := DirAccess.open(caminho)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(caminho.path_join(f))
	for sub in d.get_directories():
		_apagar(caminho.path_join(sub))
	DirAccess.remove_absolute(caminho)
