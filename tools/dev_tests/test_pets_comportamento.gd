extends SceneTree
# ============================================================================
#  TESTE DOS PETS: gaivota, comportamentos (menu B) e inventário (N) — 30/09/2026.
#
#  Pedido do dono: gaivota low poly que VOA e vive por conta própria — só segue quando
#  o jogador muda o comportamento; comportamentos livre/seguir/em guarda/agressivo pela
#  tecla B, para os dois pets; inventário na tecla N (pets e pesca), salvo no progresso.
#
#    A. inventário: começa com a gaivota e o caranguejo; aba PESCA vazia; o M não tem
#       mais pets (controle);
#    B. a gaivota sai do inventário no AR, em LIVRE;
#    C. livre: voa, pousa, anda no chão e decola de novo — em volta de CASA, sem seguir o
#       jogador (controle: jogador a 30 m e ela continua em casa);
#    D. livre no chão: o jogador chega perto e ela foge (decola);
#    E. menu B: abre para o pet mais perto; 2 = seguir; o modo fica SALVO no progresso;
#    F. seguir: acompanha o jogador (de cima) quando ele se afasta;
#    G. em guarda: mergulha e bica o inimigo perto do jogador; controle: inimigo a 12 m
#       não é alvo em guarda, mas é em agressivo;
#    H. caranguejo: livre passeia sem seguir; em guarda BELISCA o inimigo;
#    I. guardar pelo N tira o pet da cena.
#
#  ⚠️ Mapa e progresso FIXOS: o mapa vivo e o progresso do dono nunca são tocados.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_pets_comportamento.gd
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_pets_comportamento.json"

var _falhas := 0
var _cena: Node
var _hud: Node
var _jogador: Node3D


func _init() -> void:
	await process_frame
	print("\n===== PETS: GAIVOTA, COMPORTAMENTOS E INVENTÁRIO =====")
	var mh: GDScript = load("res://src/historia/ModoHistoria.gd")
	mh.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	mh.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await process_frame
	_cena = current_scene
	_hud = _cena.get_node_or_null("HistoriaHud") if _cena != null else null
	_jogador = _cena.call("jogador_local") if _cena != null else null
	_ok(_hud != null and _jogador != null, "o Modo História subiu com HUD e jogador")
	if _hud != null and _jogador != null:
		await _quadros(30)
		_dar_pets_iniciais()
		await _inventario()
		var gaivota: Node3D = await _tirar_gaivota()
		if gaivota != null:
			await _livre(gaivota)
			await _fuga(gaivota)
			await _menu_b(gaivota)
			await _seguir(gaivota)
			await _guarda(gaivota)
		await _caranguejo()
		await _guardar()
	mh.set("mapa_forcado", "")
	mh.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _tecla(codigo: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = true
	get_root().push_input(ev, true)
	await process_frame


## Desde 18/10/2026 o jogo novo começa SEM pets (pedido do dono); este teste precisa dos dois para existir.
func _dar_pets_iniciais() -> void:
	var prog: ProgressaoDoPersonagem = _cena.progressao
	for especie in ["gaivota", "caranguejo"]:
		prog.pets[especie] = {"especie": especie, "nome": especie.capitalize(), "modo": str(CatalogoDePets.modo_inicial(especie))}
	prog.mudou.emit()


## B e N não abrem mais nada: o M abre a central e o botão de aba (como o clique) escolhe a janela.
func _abrir_aba(id: String) -> void:
	if not _hud.central_aberta():
		await _tecla(KEY_M)
	(_hud.central().find_child("Aba_" + id, true, false) as Button).pressed.emit()
	await process_frame


func _levar(ponto: Vector3) -> void:
	_jogador.global_position = ponto + Vector3.UP
	_jogador.velocity = Vector3.ZERO
	await _quadros(8)


static func _plana(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


# --------------------------------------------------------------------- A
func _inventario() -> void:
	print("\n-- A. inventário (aba do M) --")
	await _abrir_aba("mochila")
	var inv: InventarioDaHistoria = _hud.inventario()
	_ok(_hud.inventario_aberto() and _hud.is_menu_open(), "a aba Mochila do M (com o painel de itens) abre e conta como menu")
	# 10/11/2026: a aba PETS saiu do inventário (a TRIPULAÇÃO faz o mesmo); os pets seguem guardados na progressão.
	_ok(inv.find_child("Aba_pets", true, false) == null and _cena.get("progressao").pets.has("gaivota") and _cena.get("progressao").pets.has("caranguejo"),
		"inventário sem aba PETS; começa com a gaivota e o caranguejo guardados")
	inv.mostrar_aba("pesca")
	await process_frame
	_ok(inv.find_child("PescaVazia", true, false) != null and inv.find_child("PescaVazia", true, false).is_visible_in_tree(),
		"aba PESCA vazia: \"nenhum item ainda\"")
	inv.mostrar_aba("pets")
	_ok(_hud.janela_de_status().find_child("ChamarCaranguejo", true, false) == null,
		"controle: a janela de status não tem os pets (estão no Inventário)")


# --------------------------------------------------------------------- B
func _tirar_gaivota() -> Node3D:
	print("\n-- B. a gaivota sai do inventário --")
	_cena.get_node("Companhia").chamar("gaivota")           # pela Companhia (a aba PETS do inventário saiu em 10/11/2026)
	await _quadros(10)
	await _tecla(KEY_M)
	var companhia: Node = _cena.get_node("Companhia")
	var g: Node3D = companhia.pet_fora("gaivota")
	_ok(g != null and g.is_in_group("pets_historia"), "saiu: está na cena e no grupo dos pets")
	if g == null:
		return null
	_ok(g.modo == ModoDoPet.LIVRE, "começa LIVRE (decisão do dono: só segue quando mandada)")
	var chao: float = _jogador.global_position.y - 0.8
	_ok(g.global_position.y > chao + 1.0, "nasce no ar (%.1f m acima do chão)" % (g.global_position.y - chao))
	_ok(companhia.esta_fora("gaivota"), "a gaivota está fora")
	return g


# --------------------------------------------------------------------- C
func _livre(g: Node3D) -> void:
	print("\n-- C. livre: voa, pousa, anda e decola em volta de casa --")
	# Tempos curtos só no teste (no jogo: 10–20 s no ar, 5–12 s no chão).
	g.tempo_no_ar = Vector2(2.0, 2.5)
	g.tempo_no_chao = Vector2(2.5, 3.0)
	g.set("_voo_livre", 1.5)
	await _levar(g.casa + Vector3(30, 0, 0))   # longe: não espanta nem é seguido
	var vistos := {}
	var longe_de_casa := 0.0
	var pousou_no_chao := false
	for i in 900:
		await _quadros(1)
		vistos[g.estado] = true
		longe_de_casa = maxf(longe_de_casa, _plana(g.global_position - g.casa))
		if g.estado == g.Estado.NO_CHAO:
			pousou_no_chao = pousou_no_chao or absf(g.global_position.y - g.casa.y) < 0.6
		if vistos.has(g.Estado.NO_CHAO) and vistos.has(g.Estado.DECOLANDO) and g.estado == g.Estado.VOANDO:
			break
	_ok(vistos.has(g.Estado.VOANDO), "voou em volta de casa")
	_ok(vistos.has(g.Estado.POUSANDO) and pousou_no_chao, "pousou no chão perto de casa")
	_ok(vistos.has(g.Estado.DECOLANDO), "e decolou de novo sozinha")
	_ok(longe_de_casa < g.raio_livre.y + 4.0, "ficou em volta de casa (no máximo %.1f m)" % longe_de_casa)
	_ok(_plana(g.global_position - _jogador.global_position) > 18.0,
		"controle: NÃO seguiu o jogador, que está a 30 m (%.0f m dele)" % _plana(g.global_position - _jogador.global_position))


# --------------------------------------------------------------------- D
func _fuga(g: Node3D) -> void:
	print("\n-- D. livre no chão: foge do jogador --")
	g.tempo_no_chao = Vector2(30.0, 30.0)
	g.set("_voo_livre", 0.1)
	for i in 900:
		await _quadros(1)
		if g.estado == g.Estado.NO_CHAO:
			break
	_ok(g.estado == g.Estado.NO_CHAO, "(pré-condição) ela está no chão")
	await _levar(g.global_position + Vector3(1.5, 0, 0))
	var fugiu := false
	for i in 30:
		await _quadros(1)
		if g.estado == g.Estado.DECOLANDO:
			fugiu = true
			break
	_ok(fugiu, "o jogador chegou a 1,5 m e ela decolou")


# --------------------------------------------------------------------- E
func _menu_b(g: Node3D) -> void:
	print("\n-- E. menu B da tripulação --")
	var prog: ProgressaoDoPersonagem = _cena.progressao
	var provisoes := preload("res://src/historia/tripulantes/provisoes.gd")
	provisoes.adicionar(prog, "gaivota")
	provisoes.atribuir(prog, "gaivota", 5)
	await _abrir_aba("pets")
	await _quadros(2)
	var menu: MenuDeComportamento = _hud.menu_de_comportamento()
	_ok(_hud.menu_de_pets_aberto() and _hud.is_menu_open(), "a aba Pets do M abre a tripulação")
	var opcoes: Array = menu.get("_lista").find_children("*", "OptionButton", true, false)
	_ok(not opcoes.is_empty(), "comportamento individual disponível sem comandante")
	if not opcoes.is_empty(): opcoes[0].item_selected.emit(1)
	await _quadros(2)
	_ok(g.modo == ModoDoPet.SEGUIR, "opção Seguir aplica no pet")
	await _tecla(KEY_M)
	_ok(not _hud.menu_de_pets_aberto(), "M fecha a tripulação")
	_ok(prog.modo_do_pet("gaivota") == ModoDoPet.SEGUIR, "modo salvo no progresso")
	var salvo := ProgressaoDoPersonagem.carregar(PROGRESSO)
	_ok(salvo.modo_do_pet("gaivota") == ModoDoPet.SEGUIR, "modo salvo no arquivo")


# --------------------------------------------------------------------- F
func _seguir(g: Node3D) -> void:
	print("\n-- F. seguir --")
	var destino := _jogador.global_position + Vector3(-16, 0, 6)
	await _levar(destino - Vector3.UP)
	var perto := INF
	var alto := 0.0
	for i in 360:
		await _quadros(1)
		perto = _plana(g.global_position - _jogador.global_position)
		alto = g.global_position.y - _jogador.global_position.y
		# Com o dono parado ela circula a `raio_circulo` dele: chegar é ficar nesse anel.
		if perto < g.raio_circulo + 2.5 and i > 60:
			break
	_ok(perto < g.raio_circulo + 2.5, "foi atrás do jogador que andou 17 m (a %.1f m dele; circula a %.1f)" % [perto, g.raio_circulo])
	_ok(alto > 1.0, "voando por cima dele (%.1f m acima)" % alto)


# --------------------------------------------------------------------- G
func _guarda(g: Node3D) -> void:
	print("\n-- G. em guarda e agressivo --")
	g.definir_modo(ModoDoPet.GUARDA)
	var boneco: BonecoDeDuelo = _cena.call("invocar_boneco", &"parado")
	await _quadros(5)
	var vida: float = boneco.health
	var bicadas := [0]
	g.bicou.connect(func(_a): bicadas[0] += 1)
	for i in 300:
		await _quadros(1)
		if bicadas[0] > 0:
			break
	_ok(bicadas[0] > 0 and boneco.health < vida,
		"em guarda: mergulhou e bicou o inimigo perto do jogador (%.0f → %.0f)" % [vida, boneco.health])
	# Inimigo a 12 m do jogador: fora da guarda (6 m), dentro do agressivo (15 m).
	var longe := _jogador.global_position + Vector3(12, 0, 0)
	boneco.parar()
	boneco.global_position = longe
	await _quadros(90)
	var antes: int = bicadas[0]
	for i in 150:
		await _quadros(1)
	_ok(bicadas[0] == antes, "controle: em guarda, inimigo a 12 m não é alvo (%d bicadas)" % (bicadas[0] - antes))
	g.definir_modo(ModoDoPet.AGRESSIVO)
	for i in 360:
		await _quadros(1)
		if bicadas[0] > antes:
			break
	_ok(bicadas[0] > antes, "agressivo: vai caçar o inimigo a 12 m")
	g.definir_modo(ModoDoPet.SEGUIR)
	_cena.call("remover_boneco")
	await _quadros(30)


# --------------------------------------------------------------------- H
func _caranguejo() -> void:
	print("\n-- H. caranguejo com comportamentos --")
	var companhia: Node = _cena.get_node("Companhia")
	await _levar(Vector3(0, 0.3, 0))
	_ok(companhia.chamar("caranguejo"), "sai do inventário")
	await _quadros(60)
	var c: Node3D = companhia.pet_fora("caranguejo")
	if c == null:
		return
	_ok(c.modo == ModoDoPet.SEGUIR, "começa SEGUINDO (o que ele já fazia)")
	c.definir_modo(ModoDoPet.LIVRE)
	var casa: Vector3 = c.casa
	await _levar(casa + Vector3(0, 0, 25))
	var longe := 0.0
	var andou := 0.0
	var antes: Vector3 = c.global_position
	for i in 300:
		await _quadros(1)
		longe = maxf(longe, _plana(c.global_position - casa))
		andou += _plana(c.global_position - antes)
		antes = c.global_position
	_ok(andou > 1.0 and longe < 8.0, "livre: passeia em volta de casa (andou %.1f m, no máximo %.1f m dela)" % [andou, longe])
	_ok(_plana(c.global_position - _jogador.global_position) > 15.0, "controle: livre, não seguiu o jogador")

	c.definir_modo(ModoDoPet.GUARDA)
	await _levar(c.global_position + Vector3(0, 0, 3))
	var boneco: BonecoDeDuelo = _cena.call("invocar_boneco", &"parado")
	await _quadros(5)
	var vida: float = boneco.health
	var beliscoes := [0]
	c.beliscou.connect(func(_a): beliscoes[0] += 1)
	for i in 420:
		await _quadros(1)
		if beliscoes[0] > 0:
			break
	_ok(beliscoes[0] > 0 and boneco.health < vida, "em guarda: belisca o inimigo (%.0f → %.0f)" % [vida, boneco.health])
	_cena.call("remover_boneco")


# --------------------------------------------------------------------- I
func _guardar() -> void:
	print("\n-- I. guardar pelo inventário --")
	await _abrir_aba("mochila")
	var inv: InventarioDaHistoria = _hud.inventario()
	for especie in ["gaivota", "caranguejo"]:
		if _cena.get_node("Companhia").esta_fora(especie):
			_cena.get_node("Companhia").recolher(especie)       # a aba PETS do inventário saiu (10/11/2026): pela Companhia
	await _quadros(5)
	_ok(get_root().get_tree().get_nodes_in_group("pets_historia").is_empty(), "guardados: nenhum pet na cena")
	_ok(not _cena.get_node("Companhia").esta_fora("gaivota"), "e a gaivota segue guardada, pronta para sair de novo")
	await _tecla(KEY_M)
