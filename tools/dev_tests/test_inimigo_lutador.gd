extends SceneTree
# ============================================================================
#  TESTE DO INIMIGO QUE LUTA — o boneco de duelo posto pela loja (30/09/2026).
#
#  Pedido do dono: o boneco de testes vira inimigo da aba "inimigos" do editor;
#  persegue e luta numa zona de 20 m em volta do ponto de nascimento; se o jogador
#  sai da zona, volta ao ponto; fora de combate regenera; morto, renasce em 1 minuto
#  no mesmo lugar; não dá XP. O jogador já nasce podendo bater (Combate 1).
#
#    A. a peça com o comportamento vira NINHO com o boneco em pé, no chão da peça,
#       virado como a peça (controle: outro modelo da categoria, sem comportamento,
#       continua `InimigoDoMapa`);
#    B. jogador FORA da zona: o boneco fica em casa;
#    C. jogador DENTRO: persegue e chega ao alcance;
#    D. luta: ataca de verdade e NÃO se defende (decisão do dono, 15/11/2026);
#    E. jogador sai da zona: volta para casa;
#    F. regenera fora de combate (controle: lutando, não);
#    G. morre sem dar XP, some e renasce no mesmo lugar, com vida cheia;
#    H. o jogador do Modo História já ataca desde o início (Combate 1).
#
#  Biblioteca, mapa e progresso de TESTE em `user://test_lutador/` — a loja, o mapa e
#  o progresso de quem joga não são tocados. O renascimento é encurtado para 2 s.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_inimigo_lutador.gd
# ============================================================================

const RAIZ := "user://test_lutador"
const MODELOS := RAIZ + "/modelos"
const MAPA := RAIZ + "/mapa.json"
const PROGRESSO := RAIZ + "/progresso.json"
const GLB_ESTATICO := "res://assets/models/arvore_voxel.glb"
## O ponto do boneco e para onde ele olha (graus, como no editor).
const CASA := Vector3(0, 0, 0)
const YAW_GRAUS := 90.0
## O jogador nasce a 40 m: FORA da zona de 20 m.
const SPAWN := Vector3(0, 1, 40)

var _falhas := 0
var _tempo_original := 60.0


func _init() -> void:
	await process_frame
	print("\n===== INIMIGO QUE LUTA (BONECO DE DUELO NO MAPA) =====")
	_limpar()
	var bib := _biblioteca()
	if bib == null:
		quit(1)
		return
	_escrever_mapa(bib)
	_tempo_original = InimigoDoMapa.tempo_de_renascer
	InimigoDoMapa.tempo_de_renascer = 2.0

	var modo: GDScript = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", PROGRESSO)
	MapaMontador.biblioteca = bib
	get_root().get_node("GameFlow").start_story()
	for i in 150:
		await process_frame

	var cena := current_scene
	var mapa := cena.get_node_or_null("Mapa") if cena else null
	var jogador: Node = cena.call("jogador_local") if cena and cena.has_method("jogador_local") else null
	_ok(mapa != null and jogador != null, "a cena do Modo História subiu com mapa e jogador")
	if mapa != null and jogador != null:
		var ninho := mapa.get_node_or_null("Ninho_lutador") as NinhoDeInimigo
		_marcacao(mapa, ninho)
		if ninho != null and is_instance_valid(ninho.boneco):
			_jogador_ja_luta(cena, jogador)
			await _em_casa(ninho, jogador)
			await _persegue(ninho, jogador)
			await _luta(ninho, jogador)
			await _volta(ninho, jogador)
			await _regenera(ninho, jogador)
			await _morre_e_renasce(cena, ninho)

	InimigoDoMapa.tempo_de_renascer = _tempo_original
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	MapaMontador.biblioteca = null
	_limpar()
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _plana(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


## Põe o jogador em `ponto` (no chão) e espera assentar.
func _levar(jogador: Node, ponto: Vector3) -> void:
	jogador.global_position = ponto + Vector3.UP
	jogador.velocity = Vector3.ZERO
	await _quadros(10)


# ------------------------------------------------------------------ montagem
func _biblioteca() -> BibliotecaDeModelos:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODELOS))
	var bib := BibliotecaDeModelos.new(MODELOS)
	bib.criar_categoria("inimigos")
	# O MESMO caminho que pôs o boneco na loja do dono.
	var r: Dictionary = load("res://tools/importar_boneco_na_loja.gd").importar(bib)
	if not r.get("ok", false):
		_ok(false, "importar o boneco na loja de teste: %s" % r)
		return null
	bib.set_meta("id_boneco", r["id"])
	# Controle: um modelo comum na MESMA categoria, sem comportamento.
	var e := ImportadorDeModelos.importar(bib, ProjectSettings.globalize_path(GLB_ESTATICO))
	if not e.get("ok", false):
		_ok(false, "importar o modelo estático: %s" % e)
		return null
	bib.marcar_categoria([e["id"]] as Array[String], InimigoDoMapa.CATEGORIA, true)
	bib.set_meta("id_estatico", e["id"])
	return bib


func _escrever_mapa(bib: BibliotecaDeModelos) -> void:
	var tamanho: Vector3 = bib.info(bib.get_meta("id_boneco"))["tamanho"]
	var pecas := [
		{"id": "baseplate", "tipo": "caixa", "posicao": [0, -1, 0], "rotacao_graus": [0, 0, 0],
			"tamanho": [128, 2, 128], "cor": "#767676", "material": "grade", "grade_celula": 4, "colisao": true},
		# Em pé no chão: centro a meia altura.
		{"id": "lutador", "tipo": "modelo", "modelo": bib.get_meta("id_boneco"),
			"posicao": [CASA.x, tamanho.y * 0.5, CASA.z], "rotacao_graus": [0, YAW_GRAUS, 0],
			"tamanho": [tamanho.x, tamanho.y, tamanho.z], "cor": "#ffffff", "material": "liso", "grade_celula": 4, "colisao": true},
		{"id": "estatico", "tipo": "modelo", "modelo": bib.get_meta("id_estatico"), "posicao": [-40, 1, -40],
			"rotacao_graus": [0, 0, 0], "tamanho": [1.4, 2, 1.4], "cor": "#ffffff", "material": "liso", "grade_celula": 4, "colisao": true},
	]
	var mapa := {"formato": "skills-one-piece/mapa", "versao": 1, "nome": "Teste lutador",
		"spawn": {"posicao": [SPAWN.x, SPAWN.y, SPAWN.z]}, "pecas": pecas}
	var f := FileAccess.open(MAPA, FileAccess.WRITE)
	f.store_string(JSON.stringify(mapa, "\t"))
	f.close()


# --------------------------------------------------------------------- A
func _marcacao(mapa: Node, ninho: NinhoDeInimigo) -> void:
	print("\n-- A. a peça do boneco vira ninho --")
	_ok(ninho != null and is_instance_valid(ninho.boneco), "a peça com o comportamento virou ninho com um boneco")
	_ok(mapa.get_node_or_null("lutador") == null, "a peça-modelo do editor saiu da cena do jogo")
	_ok(mapa.get_node_or_null("estatico") is InimigoDoMapa,
		"controle: outro modelo da categoria, sem comportamento, continua InimigoDoMapa")
	if ninho == null or not is_instance_valid(ninho.boneco):
		return
	var b := ninho.boneco
	_ok(b.is_in_group("enemy") and b.combate_direcional != null, "o boneco é inimigo e tem o executor do jogador")
	_ok(_plana(b.global_position - CASA) < 0.3, "nasceu no ponto do editor (a %.2f m)" % _plana(b.global_position - CASA))
	var yaw := b.modelo_visual().rotation.y
	_ok(absf(angle_difference(yaw, deg_to_rad(YAW_GRAUS))) < 0.05,
		"virado como a peça (%.0f° de %.0f°)" % [rad_to_deg(yaw), YAW_GRAUS])


# --------------------------------------------------------------------- H
func _jogador_ja_luta(cena: Node, jogador: Node) -> void:
	print("\n-- H. o jogador já nasce lutando (Combate 1) --")
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	_ok(prog.skills["combate"] == 1 and jogador.capacidades.can_attack,
		"campanha nova: Combate %d e o clique liberado" % prog.skills["combate"])
	_ok(not CapacidadesDoJogador.civil().can_attack,
		"controle: o Civil sem progressão continua travado (as travas seguem valendo)")


# --------------------------------------------------------------------- B
func _em_casa(ninho: NinhoDeInimigo, jogador: Node) -> void:
	print("\n-- B. jogador fora da zona: fica em casa --")
	var b := ninho.boneco
	var cerebro := b.get_node("CerebroDeInimigo") as CerebroDeInimigo
	await _quadros(60)
	_ok(_plana(jogador.global_position - CASA) > CerebroDeInimigo.ZONA,
		"(pré-condição) o jogador está a %.0f m, fora dos %.0f m" % [_plana(jogador.global_position - CASA), CerebroDeInimigo.ZONA])
	_ok(cerebro.estado == CerebroDeInimigo.Estado.EM_CASA and _plana(b.global_position - CASA) < 0.3,
		"o boneco ficou em casa (estado %s, a %.2f m)" % [CerebroDeInimigo.Estado.keys()[cerebro.estado], _plana(b.global_position - CASA)])


# --------------------------------------------------------------------- C
func _persegue(ninho: NinhoDeInimigo, jogador: Node) -> void:
	print("\n-- C. jogador dentro da zona: persegue --")
	var b := ninho.boneco
	var cerebro := b.get_node("CerebroDeInimigo") as CerebroDeInimigo
	await _levar(jogador, CASA + Vector3(0, 0, 9))
	var viu_perseguir := false
	var chegou := false
	for i in 240:
		await _quadros(1)
		viu_perseguir = viu_perseguir or cerebro.estado == CerebroDeInimigo.Estado.PERSEGUINDO
		if cerebro.estado == CerebroDeInimigo.Estado.LUTANDO:
			chegou = true
			break
	var d := _plana(b.global_position - jogador.global_position)
	_ok(viu_perseguir, "entrou em PERSEGUINDO com o jogador a 9 m do ponto")
	_ok(chegou and d <= CerebroDeInimigo.ALCANCE + 0.3, "chegou ao alcance e passou a LUTAR (a %.2f m do jogador)" % d)


# --------------------------------------------------------------------- D
func _luta(ninho: NinhoDeInimigo, jogador: Node) -> void:
	print("\n-- D. luta de verdade --")
	var b := ninho.boneco
	var ex := b.combate_direcional
	var golpes := [0]
	ex.golpe_iniciado.connect(func(_g, _id): golpes[0] += 1)
	var vida_antes: float = jogador.health
	# O jogador também ataca: vira para o boneco e pede golpes; o boneco lê o preparo.
	var reagiu := 0
	var pedidos := 0
	var contatos := [0]
	ex.bloqueou.connect(func(_g, _p): contatos[0] += 1)
	ex.aparou.connect(func(_g, _p): contatos[0] += 1)
	var mira: Vector3 = b.global_position - jogador.global_position
	jogador._yaw = RosaDosVentos.yaw_para(Vector3(mira.x, 0, mira.z).normalized())
	jogador._update_pivot()
	for i in 360:
		await _quadros(1)
		if i % 80 == 10 and jogador.combate_direcional.pedir_ataque(GolpeDirecional.Direcao.FRENTE):
			pedidos += 1
		if jogador.combate_direcional.em_preparo() and ex.guarda_pedida():
			reagiu += 1
	_ok(golpes[0] >= 2, "o boneco atacou %d vezes em 6 s" % golpes[0])
	_ok(float(jogador.health) < vida_antes, "e os golpes dele tiram vida do jogador (%.1f → %.1f)" % [vida_antes, jogador.health])
	# Decisão do dono (15/11/2026): o inimigo não se defende. O jogador atacou (`pedidos`) e a guarda dele nunca subiu.
	_ok(pedidos >= 3 and reagiu == 0 and contatos[0] == 0,
		"não se defende: guarda nunca erguida durante o preparo (%d quadros em %d golpes; %d bloqueio/aparo)" % [reagiu, pedidos, contatos[0]])
	jogador.health = jogador.max_health


# --------------------------------------------------------------------- E
func _volta(ninho: NinhoDeInimigo, jogador: Node) -> void:
	print("\n-- E. jogador sai da zona: volta para casa --")
	var b := ninho.boneco
	var cerebro := b.get_node("CerebroDeInimigo") as CerebroDeInimigo
	var longe: Vector3 = b.global_position
	await _levar(jogador, CASA + Vector3(0, 0, 40))
	var voltou := false
	var viu_voltando := false
	for i in 400:
		await _quadros(1)
		viu_voltando = viu_voltando or cerebro.estado == CerebroDeInimigo.Estado.VOLTANDO
		if cerebro.estado == CerebroDeInimigo.Estado.EM_CASA:
			voltou = true
			break
	_ok(viu_voltando and voltou, "VOLTANDO e depois EM_CASA (saiu de %.1f m do ponto)" % _plana(longe - CASA))
	_ok(_plana(b.global_position - CASA) <= CerebroDeInimigo.CHEGOU + 0.1,
		"parou no ponto do editor (a %.2f m)" % _plana(b.global_position - CASA))


# --------------------------------------------------------------------- F
func _regenera(ninho: NinhoDeInimigo, jogador: Node) -> void:
	print("\n-- F. regenera fora de combate --")
	var b := ninho.boneco
	var cerebro := b.get_node("CerebroDeInimigo") as CerebroDeInimigo
	b.health = b.max_health * 0.5
	await _quadros(120)
	var ganho: float = (b.health - b.max_health * 0.5) / b.max_health
	_ok(ganho > 0.15 and ganho < 0.25, "em casa, 2 s regeneram %.0f%% da vida (10%%/s)" % (ganho * 100.0))

	# Controle: lutando não regenera. O jogador fica parado ao lado, sem bater.
	await _levar(jogador, CASA + Vector3(0, 0, 1.2))
	for i in 120:
		await _quadros(1)
		if cerebro.estado == CerebroDeInimigo.Estado.LUTANDO:
			break
	b.health = b.max_health * 0.5
	await _quadros(60)
	_ok(cerebro.estado == CerebroDeInimigo.Estado.LUTANDO and is_equal_approx(b.health, b.max_health * 0.5),
		"controle: lutando não regenera (%.0f%%)" % (b.health / b.max_health * 100.0))
	jogador.health = jogador.max_health
	await _levar(jogador, CASA + Vector3(0, 0, 40))


# --------------------------------------------------------------------- G
func _morre_e_renasce(cena: Node, ninho: NinhoDeInimigo) -> void:
	print("\n-- G. morre sem XP e renasce no mesmo lugar --")
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	var xp_antes := prog.xp
	var derrotas := [0]
	ninho.derrotado.connect(func(_n): derrotas[0] += 1)
	var morto := ninho.boneco
	var ref: WeakRef = weakref(morto)
	morto.take_damage(morto.max_health + 10.0)
	morto.take_damage(10.0)
	_ok(derrotas[0] == 1 and prog.xp == xp_antes, "derrota avisada UMA vez e sem XP (XP %d → %d)" % [xp_antes, prog.xp])
	var hud := cena.get_node_or_null("HistoriaHud")
	var aviso: String = hud.get("_aviso").text if hud != null else ""
	_ok(aviso.contains("volta em"), "a tela avisa que ele volta (\"%s\")" % aviso)
	await _quadros(80)
	_ok(ref.get_ref() == null and ninho.boneco == null, "o corpo derrotado some depois de 1 s")
	_ok(ninho.falta_para_renascer() > 0.0, "e o ninho conta o tempo para renascer (%.1f s)" % ninho.falta_para_renascer())
	for i in 120:
		await _quadros(1)
		if is_instance_valid(ninho.boneco):
			break
	var novo := ninho.boneco
	_ok(is_instance_valid(novo) and novo != morto, "renasceu (tempo encurtado para %.0f s no teste)" % InimigoDoMapa.tempo_de_renascer)
	if is_instance_valid(novo):
		await _quadros(20)
		_ok(_plana(novo.global_position - CASA) < 0.3 and is_equal_approx(novo.health, novo.max_health),
			"no MESMO ponto do editor (a %.2f m) e com a vida cheia" % _plana(novo.global_position - CASA))


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
