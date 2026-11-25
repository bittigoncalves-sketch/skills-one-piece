extends SceneTree
## Pacote de 19/11/2026 (pedido do dono):
##   1. o INVENTÁRIO deixou de ser aba — frutas, pesca, armas e materiais moram na página MOCHILA (E), ao lado da grade;
##   2. a loja do Barba Negra é menor e NUNCA passa da tela;
##   3. o jogador do Modo História tem a altura dos piratas/marinheiros básicos.
## Mapa/progresso exclusivos; não usa nem grava a campanha do dono.
##   godot --headless --path . --script tools/dev_tests/test_mochila_e_tamanho.gd
const PROGRESSO := "user://teste_mochila_e_tamanho_progresso.json"
var _falhas := 0


func _init() -> void:
	call_deferred("_executar")


func _ok(condicao: bool, mensagem: String) -> void:
	print(("  ✅ " if condicao else "  ❌ ") + mensagem)
	if not condicao:
		_falhas += 1


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


## Altura (m) de um modelo fora da árvore: soma das transformações locais até as malhas.
static func _altura(n: Node, t := Transform3D.IDENTITY, acc: Array = []) -> float:
	var tt := t
	if n is Node3D:
		tt = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		acc.append(tt * (n as MeshInstance3D).mesh.get_aabb())
	for c in n.get_children():
		_altura(c, tt, acc)
	var lo := INF
	var hi := -INF
	for a: AABB in acc:
		lo = minf(lo, a.position.y)
		hi = maxf(hi, a.end.y)
	return hi - lo if not acc.is_empty() else 0.0


func _executar() -> void:
	print("\n-- loja do Barba Negra cabe na tela --")
	var loja_npc = load("res://src/historia/npcs/loja_do_barba_negra.gd").new()
	_ok(loja_npc.escala_da_ui() < 1.0, "a loja do Barba Negra é menor que a padrão (escala %.2f; era 1,3)" % loja_npc.escala_da_ui())
	var prog_loja := ProgressaoDoPersonagem.new()
	var npc := NpcDaIlha.new()
	npc.tipo = "npc_barba_negra"
	for tela in [Vector2i(1280, 720), Vector2i(1024, 600), Vector2i(800, 500)]:
		var sub := SubViewport.new()
		sub.size = tela
		sub.disable_3d = true
		root.add_child(sub)
		var janela := JanelaDeLoja.new()
		sub.add_child(janela)
		janela.ligar(prog_loja, null)
		root.add_child(npc) if npc.get_parent() == null else null
		janela.abrir(npc)
		await _quadros(3)
		var cobre := janela.size * janela.scale
		var folga := JanelaDeLoja.MARGEM_DA_TELA - 0.5
		var centro: Vector2 = janela.get_global_transform() * Vector2.ZERO      # canto de cima à esquerda JÁ com a escala em torno do pivô
		_ok(cobre.x <= tela.x - 2.0 * folga and cobre.y <= tela.y - 2.0 * folga,
			"%dx%d: a janela (%.0fx%.0f já com escala %.2f) cabe na tela" % [tela.x, tela.y, cobre.x, cobre.y, janela.scale.x])
		_ok(centro.x >= 0.0 and centro.y >= 0.0 and centro.x + cobre.x <= tela.x + 0.5 and centro.y + cobre.y <= tela.y + 0.5,
			"%dx%d: e fica DENTRO da tela (canto %s)" % [tela.x, tela.y, str(centro.round())])
		sub.queue_free()

	print("\n-- mochila com os itens, sem aba Inventário --")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = PROGRESSO
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	root.get_node("GameFlow").start_story()
	await _quadros(100)
	var hud = current_scene.get_node("HistoriaHud")
	var central: CentralDeJanelas = hud.central()
	_ok(not central.tem_pagina("inventario") and central.find_child("Aba_inventario", true, false) == null, "não há mais a aba INVENTÁRIO")
	_ok(central.tem_pagina("mochila"), "a aba MOCHILA existe")
	hud.central().abrir("mochila")
	await _quadros(4)
	var inv: InventarioDaHistoria = hud.inventario()
	var mochila: MochilaMinecraft = hud.mochila()
	_ok(inv.is_visible_in_tree() and mochila.is_visible_in_tree() and hud.inventario_aberto(), "abrir a mochila mostra a grade E o painel de itens")
	for id in ["frutas", "pesca", "armas", "materiais"]:
		inv.mostrar_aba(id)
		await process_frame
		_ok(inv.find_child("Aba_" + id, true, false) != null, "painel da mochila tem a aba %s" % id.to_upper())
	print("  [diag] painel de itens: tamanho %s, mínimo %s; grade %s (escala %.2f)" % [str(inv.size), str(inv.get_combined_minimum_size()), str(mochila.size), mochila.escala])
	for c in inv.find_children("*", "Control", true, false):
		if (c as Control).get_combined_minimum_size().x > InventarioDaHistoria.LARGURA_NA_MOCHILA - 10.0:
			print("  [diag] largo: %s mínimo %s (%s)" % [str(inv.get_path_to(c)), str((c as Control).get_combined_minimum_size()), c.get_class()])
	var pagina := mochila._pagina()
	_ok(pagina != null and pagina.get_child(0).get_combined_minimum_size().x <= CentralDeJanelas.LARGURA, "a página MOCHILA pede no máximo a largura da central (%.0f de %.0f)" % [pagina.get_child(0).get_combined_minimum_size().x if pagina else 0.0, CentralDeJanelas.LARGURA])
	var lado_a_lado := mochila.global_position.x + mochila.size.x <= inv.global_position.x + 1.0
	_ok(lado_a_lado, "a grade fica à esquerda do painel de itens, sem sobrepor (%.0f ≤ %.0f)" % [mochila.global_position.x + mochila.size.x, inv.global_position.x])
	_ok(pagina != null and mochila.size.y <= pagina.size.y + 1.0 and inv.size.x <= InventarioDaHistoria.LARGURA_NA_MOCHILA + 1.0,
		"a grade cabe na página (%.0f de %.0f) e o painel de itens não passa de %.0f px" % [mochila.size.y, pagina.size.y if pagina else 0.0, InventarioDaHistoria.LARGURA_NA_MOCHILA])
	# o painel de itens não estoura a largura: nada dentro dele passa da borda direita
	var estoura := false
	for c in inv.find_children("*", "Control", true, false):
		if c.is_visible_in_tree() and (c as Control).get_global_rect().end.x > inv.get_global_rect().end.x + 1.0:
			estoura = true
	_ok(not estoura, "nenhum controle do painel de itens passa da borda dele")

	print("\n-- altura do jogador = a dos piratas e marinheiros básicos --")
	var inimigo := (load("res://mapas/modelos/mp_pirate_pirate1.glb") as PackedScene).instantiate()
	var alt_inimigo := _altura(inimigo)
	var jogador = hud._jogador_local()
	var modelo: Node3D = jogador._char_model
	var acc: Array = []
	for m in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh != null and mi.is_visible_in_tree():
			acc.append(mi.global_transform * mi.mesh.get_aabb())
	var lo := INF
	var hi := -INF
	for a: AABB in acc:
		lo = minf(lo, a.position.y)
		hi = maxf(hi, a.end.y)
	var alt_jogador := hi - lo
	_ok(absf(alt_jogador - alt_inimigo) <= 0.15, "o jogador mede %.2f m e o pirata básico %.2f m (tolerância 0,15)" % [alt_jogador, alt_inimigo])
	var capsula := jogador._colisor.shape as CapsuleShape3D
	_ok(capsula != null and absf(capsula.radius - jogador.RAIO_DA_CAPSULA) < 0.001, "a largura da cápsula não mudou (raio %.2f)" % (capsula.radius if capsula else -1.0))
	_ok(capsula != null and capsula.height >= alt_inimigo - 0.1, "a cápsula acompanha a altura (%.2f m)" % (capsula.height if capsula else -1.0))
	_ok(jogador._camera.escala_do_corpo > 1.3, "a câmera sobe junto (escala %.2f)" % jogador._camera.escala_do_corpo)
	# a arena segue com os 1,5 m de todos: o fator só é ligado pelo Modo História
	var da_arena = load("res://Player.gd").new()
	_ok(is_equal_approx(da_arena.escala_de_modo, 1.0) and is_equal_approx(da_arena.escala_do_corpo(), 1.0), "fora do Modo História o corpo continua em escala 1")
	da_arena.free()

	print("\n%s" % ("TUDO CERTO" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)
