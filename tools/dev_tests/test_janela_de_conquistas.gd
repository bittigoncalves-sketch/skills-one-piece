extends SceneTree
# ============================================================================
#  ITEM 10: janela de CONQUISTAS do mod (aba da central, tecla M): lista as que o jogador faz, mostra feitas/total e acompanha a progressão.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_janela_de_conquistas.gd
# ============================================================================
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)

func q(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_janela_conquistas.json"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_janela_conquistas.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	var hud = get_first_node_in_group("hud")
	var central: CentralDeJanelas = hud.central()
	ok(central != null and central.tem_pagina("conquistas"), "a central tem a aba CONQUISTAS")
	var visiveis := JanelaDeConquistas.visiveis()
	ok(visiveis.size() >= 100 and visiveis.size() <= 123, "%d conquistas que o jogador faz (123 no mod, menos as automáticas do primeiro tick)" % visiveis.size())
	central.abrir("conquistas")
	await q(5)
	var janela: JanelaDeConquistas = hud._conquistas
	ok(janela.is_visible_in_tree(), "a aba abre")
	var nos_por_id := {}
	for no in janela.arvore.nos:
		nos_por_id[no.id] = no
	ok(visiveis.all(func(d): return nos_por_id.has(d.id)), "um nó na árvore por conquista (%d nós)" % janela.arvore.nos.size())
	var feitas0: int = visiveis.filter(func(d): return JanelaDeConquistas.feita(hud._barra.progressao, d)).size()
	ok(janela._cabecalho.text.contains("%d / %d" % [feitas0, visiveis.size()]), "cabeçalho mostra feitas/total (%s)" % janela._cabecalho.text)
	# conceder uma conquista e ver a janela acompanhar
	var ej := McEntidade.de(j)
	var alvo = null
	for d in visiveis:
		if not JanelaDeConquistas.feita(hud._barra.progressao, d):
			alvo = d
			break
	ok(alvo != null, "há uma conquista pendente para conceder (%s)" % (alvo.id if alvo != null else "-"))
	var def = ej.server.getAdvancements().getAdvancement(alvo.id)
	ej.getAdvancements().award(def, def.criterios[0])
	for c in def.criterios:
		ej.getAdvancements().award(def, c)
	await q(5)
	janela.atualizar()
	var feitas1: int = visiveis.filter(func(d): return JanelaDeConquistas.feita(hud._barra.progressao, d)).size()
	ok(feitas1 == feitas0 + 1, "conceder uma conquista sobe a contagem (%d → %d)" % [feitas0, feitas1])
	ok(janela._cabecalho.text.contains("%d / %d" % [feitas1, visiveis.size()]), "o cabeçalho acompanha (%s)" % janela._cabecalho.text)
	ok(nos_por_id[alvo.id].feita, "o nó da conquista concedida acende na árvore")
	print("\nconquistas: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
