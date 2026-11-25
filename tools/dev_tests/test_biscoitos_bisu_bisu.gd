extends SceneTree
## Bisu Bisu (10/11/2026, pedidos do dono): o biscoito da técnica Biscuit entra num contador salvo e aparece no HUD abaixo do "M"; cada aliado
## de biscoito (C/V) gasta 1; o aliado do C não expira; o aliado ataca qualquer inimigo do jogo; o nome composto da V sai traduzido;
## o inventário não tem mais a aba PETS e as frutas têm ícone.
##   godot --headless --path . --script tools/dev_tests/test_biscoitos_bisu_bisu.gd
const MAPA := "user://test_biscoitos.json"
const SAVE := "user://test_biscoitos_progresso.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	# ---- progressão pura: contador salvo/carregado
	var p := ProgressaoDoPersonagem.new()
	p.dar_item_do_mod("minepiece:biscuit", 3)
	ok(p.item_do_mod("minepiece:biscuit") == 3 and not p.gastar_item_do_mod("minepiece:biscuit", 4) and p.item_do_mod("minepiece:biscuit") == 3, "contador: não gasta mais do que tem")
	ok(p.gastar_item_do_mod("minepiece:biscuit", 2) and p.item_do_mod("minepiece:biscuit") == 1, "contador: gasta 2 de 3")
	ok(ProgressaoDoPersonagem.de_dict(p.para_dict()).item_do_mod("minepiece:biscuit") == 1, "contador: salvar/carregar")
	# ---- nome composto traduzido
	ok(McTexto.traduzir("entity.minepiece.biscuit_warrrior: minepiece.technique.shanks7") == "Biscuit Warrior: Assault Attack", "nome da V traduzido (%s)" % McTexto.traduzir("entity.minepiece.biscuit_warrrior: minepiece.technique.shanks7"))
	ok(McTexto.traduzir("entity.minepiece.biscuit_warrrior") == "Biscuit Warrior", "nome simples segue igual")
	# ---- cena real
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(160, 2, 160)
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var m = current_scene
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var prog: ProgressaoDoPersonagem = m.get("progressao")
	var avancos = McEntidade.de(j).conquistas_do_jogador()           # o mod libera os golpes por conquista (a varredura concede todas)
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(60)
	prog.guardar_akuma("bisu_bisu", 1)            # equipa pelo caminho do jogador: a fruta fica NA PROGRESSÃO e o item "fruta" na mão
	prog.comer_fruta_comprada("bisu_bisu")
	prog.item_ativo = "fruta"
	prog.mudou.emit()
	await quadros(40)
	var dono := McEntidade.de(j)
	# HUD: contador abaixo do M
	var hud = get_first_node_in_group("hud")
	var contador := hud.find_child("ContadorDeItens", true, false) as Control
	var indicador := hud.find_child("IndicadorM", true, false) as Control
	ok(contador != null and indicador != null and contador.position.y >= indicador.position.y + indicador.size.y, "contador de biscoitos abaixo do M (contador y=%s, M y=%s h=%s)" % [str(contador.position.y) if contador else "-", str(indicador.position.y) if indicador else "-", str(indicador.size.y) if indicador else "-"])
	# 1) a técnica Biscuit (B) entrega biscoito ao contador
	var c = j.get_node_or_null("FrutaMinePiece")
	var antes := prog.item_do_mod("minepiece:biscuit")
	var e := McEntidade.de(j)
	Mc.estatico(&"ItemHandlerHelper", &"giveItemToPlayer", [e, McItem.pilha(Mc.item(&"minepiece:biscuit"), 1)])
	ok(prog.item_do_mod("minepiece:biscuit") == antes + 1, "giveItemToPlayer do mod entra no contador")
	await quadros(2)
	ok(contador.visible and (contador.find_child("Numero", true, false) as Label).text == "×%d" % prog.item_do_mod("minepiece:biscuit"), "o HUD mostra a quantidade (%s)" % (contador.find_child("Numero", true, false) as Label).text)
	# 1b) REGRESSÃO (10/11/2026): mexer nos biscoitos NÃO emite `mudou` (quem o ouve reaplica a progressão, reequipa a fruta e grava o save);
	#     senão cada B/C/V cancelava os poderes e refazia o estado da fruta (os aliados eram descartados pela regra do mod).
	var ctrl_antes = j.get_node_or_null("FrutaMinePiece")
	var emitidos := [0]
	prog.mudou.connect(func(): emitidos[0] += 1)
	prog.dar_item_do_mod("minepiece:biscuit", 1)
	prog.gastar_item_do_mod("minepiece:biscuit", 1)
	await quadros(5)
	ok(emitidos[0] == 0, "dar/gastar biscoito não emite `mudou` (%d emissões)" % emitidos[0])
	ok(j.get_node_or_null("FrutaMinePiece") == ctrl_antes and ctrl_antes != null and ctrl_antes.fruta_ativa(), "o controlador da fruta segue o mesmo, ativo (fruta %s)" % j.current_fruit_id)
	# um `mudou` qualquer (XP, ouro…) também não pode derrubar a fruta equipada
	prog.mudou.emit()
	await quadros(10)
	ok(j.get_node_or_null("FrutaMinePiece") != null and j.get_node_or_null("FrutaMinePiece").fruta_ativa() and j.current_fruit_id == "bisu_bisu", "um `mudou` qualquer mantém a fruta equipada (%s)" % j.current_fruit_id)
	# 2) sem biscoito o guerreiro não nasce; com, gasta 1
	prog.zerar_inventario()
	var pos := McVec3.de(j.global_position.x / 0.88 + 3.0, 0.0, j.global_position.z / 0.88)
	var tipo := Mc.tipo_entidade(&"minepiece:biscuit_warrrior")
	ok(tipo.create(Mc.mundo(self), null, null, pos, null, false, false) == null, "sem biscoito não nasce guerreiro (nem corpo virtual)")
	prog.dar_item_do_mod("minepiece:biscuit", 2)
	var ent: McEntidade = tipo.create(Mc.mundo(self), null, null, pos, null, false, false)
	ok(ent != null and prog.item_do_mod("minepiece:biscuit") == 1, "com biscoito nasce e gasta 1 (restam %d)" % prog.item_do_mod("minepiece:biscuit"))
	Mc.proc(&"SetSummonedEntityProcedure").execute(dono, ent)
	await quadros(5)
	var w := ent.no as PersonagemMinePiece
	# 3) não expira: o `cnt_life` do mod passaria de 3600 ticks
	var dados := McEntidade.de(w).getPersistentData()
	dados.putDouble("cnt_life", 3590.0)
	await quadros(60)
	ok(is_instance_valid(w) and w.vivo() and dados.getDouble("cnt_life") < 100.0, "o guerreiro do C não expira (cnt_life %.0f)" % dados.getDouble("cnt_life"))
	# 4) ataca outro tipo de inimigo (boneco de duelo / bandido do mapa), não só personagens do East Blue
	var boneco := BonecoDeDuelo.new()
	boneco.position = w.global_position + Vector3(0, 0, -4)
	current_scene.add_child(boneco)
	await quadros(10)
	var vida0: float = boneco.health
	await quadros(420)
	ok(boneco.health < vida0 or not boneco.vivo(), "o aliado fere um boneco de duelo (%.0f → %.0f)" % [vida0, boneco.health])
	# 5) a técnica V (4 guerreiros) é recusada com menos de 4 biscoitos, sem gastar energia
	prog.zerar_inventario()
	prog.dar_item_do_mod("minepiece:biscuit", 3)
	j.energy = j.max_energy
	var e0: float = j.energy
	c = j.get_node_or_null("FrutaMinePiece")
	c.usar_tecla("V", true)
	await quadros(20)
	c.usar_tecla("V", false)
	await quadros(30)
	ok(is_equal_approx(j.energy, e0) or j.energy >= e0 - 0.01, "V com 3 biscoitos é recusada sem gastar energia (%.1f → %.1f)" % [e0, j.energy])
	# 6) Assault Attack (V): os 4 guerreiros nascem LIGADOS ao dono (todos no mesmo quadro) e NÃO morrem quando o ataque acaba (o `kill @s` do mod é
	#    ignorado enquanto o dono vive) — antes só o 1º era ligado e o fim do ataque matava os outros
	prog.zerar_inventario()
	prog.dar_item_do_mod("minepiece:biscuit", 6)
	for f in get_nodes_in_group("invocados_do_jogador"):
		f.queue_free()
	await quadros(5)
	j.energy = j.max_energy
	await quadros(400)
	c = j.get_node_or_null("FrutaMinePiece")
	c.usar_tecla("V", true); await quadros(60); c.usar_tecla("V", false)
	await quadros(900)
	var vivos := 0
	for f in get_nodes_in_group("invocados_do_jogador"):
		if is_instance_valid(f) and f.vivo():
			vivos += 1
	ok(vivos == 4, "V: os 4 guerreiros seguem vivos e ligados ao dono 15 s depois (%d)" % vivos)
	# 7) limite de 6 guerreiros: o 7º e o 8º apagam os mais antigos (pedido do dono)
	prog.zerar_inventario()
	prog.dar_item_do_mod("minepiece:biscuit", 20)
	for f in get_nodes_in_group("invocados_do_mod"):
		f.queue_free()
	await quadros(5)
	var criados: Array = []
	for k in 8:
		var e2: McEntidade = tipo.create(Mc.mundo(self), null, null, McVec3.de(j.global_position.x / 0.88 + 3.0 + k, 0.0, j.global_position.z / 0.88 + 4.0), null, false, false)
		Mc.proc(&"SetSummonedEntityProcedure").execute(dono, e2)
		criados.append(e2.no)
		await quadros(2)
	await quadros(5)
	var vivos6 := 0
	for f in get_nodes_in_group("invocados_do_mod"):
		if is_instance_valid(f) and not f.is_queued_for_deletion() and f.vivo():
			vivos6 += 1
	ok(vivos6 == McAliadoDoMod.MAXIMO_DE_GUERREIROS, "no máximo 6 guerreiros vivos (%d)" % vivos6)
	ok(not is_instance_valid(criados[0]) or criados[0].is_queued_for_deletion(), "o mais antigo foi apagado")
	ok(is_instance_valid(criados[7]) and not criados[7].is_queued_for_deletion(), "o mais novo segue")
	# ---- inventário
	var inv: InventarioDaHistoria = hud.call("inventario")
	ok(inv.find_child("Aba_pets", true, false) == null and inv.find_child("Aba_frutas", true, false) == null, "inventário sem as abas PETS e FRUTAS (frutas são itens)")
	prog.guardar_akuma("gomu_gomu", 1)
	prog.mudou.emit()
	# O inventário vive numa página da JANELA CENTRAL e só redesenha as listas quando está VISÍVEL (`_suja` até abrir): abre pela API da HUD, como o jogador (tecla do inventário).
	if not hud.call("inventario_aberto"):
		hud.call("alternar_inventario")
	await quadros(5)
	ok(ItensDeFruta.icone("akuma:gomu_gomu") != null and prog.inventario.contar("akuma:gomu_gomu") >= 1, "a Akuma é item do inventário e tem ícone")
	print("test_biscoitos_bisu_bisu: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
