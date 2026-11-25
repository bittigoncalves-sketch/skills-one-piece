extends SceneTree
## 5 Nikyu Nikyu no inventário do Modo História para testes (30/10/2026): o botão do F8 enche o inventário, a aba Frutas mostra "× 5",
## comer uma a equipa (controlador nativo da Nikyu) e o contador cai. Save isolado; não toca o progresso do dono.
const PROGRESSO := "user://test_nikyu_inventario.json"
const ID := "nikyu_nikyu_mine_piece"
var _falhas := 0
func _init() -> void:
	call_deferred("_r")
func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _falhas += 1
func _quadros(n: int) -> void:
	for i in n: await physics_frame
func _r() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", PROGRESSO)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	root.get_node("GameFlow").start_story()
	await _quadros(120)
	var cena := current_scene
	var prog = cena.progressao
	var hud = cena.get_node("HistoriaHud")
	_ok(prog.quantas_akuma(ID) == 0, "começa sem Nikyu")
	_ok(not prog.dar_fruta_de_teste("fruta_que_nao_existe", 5), "fruta fora da loja é recusada")
	var painel = hud.ferramentas_de_teste()
	_ok(painel != null, "o painel F8 existe (build de desenvolvimento)")
	var botao := painel.find_child("DarNikyu", true, false) as Button
	_ok(botao != null, "botão Dar 5 Nikyu Nikyu no painel")
	botao.pressed.emit()
	_ok(prog.quantas_akuma(ID) == 5, "5 Nikyu no inventário")
	botao.pressed.emit()
	_ok(prog.quantas_akuma(ID) == 5, "apertar de novo não acumula (idempotente)")
	hud.central().abrir("mochila")
	await _quadros(3)
	_ok(prog.inventario.contar(ItensDeFruta.tag_akuma(ID)) == 5, "as 5 são uma pilha de item no inventário (hotbar/mochila), não uma aba")
	hud.central().fechar()
	_ok(prog.comer_fruta_comprada(ID), "comer uma do inventário")
	await _quadros(20)
	_ok(prog.fruta == ID and prog.quantas_akuma(ID) == 4, "equipada e sobram 4")
	var jogador = get_first_node_in_group("player")
	var ctl = load("res://src/combat/frutas_mine_piece/controlador.gd").de(jogador)
	_ok(ctl != null and ctl.fruta_ativa() and ctl.fruta_id == ID, "o controlador nativo da Nikyu assumiu o jogador")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\n%s" % ("TUDO CERTO" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas else 0)
