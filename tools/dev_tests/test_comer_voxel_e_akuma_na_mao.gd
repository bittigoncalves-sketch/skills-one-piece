extends SceneTree
## Alimentos voxel e Akuma na mão (25/11/2026): cada comida/bebida mostra o SEU modelo voxel; a Akuma do slot selecionado fica na mão; comer a Akuma
## tem gesto com sons, só vale ao engolir e o gesto cortado a devolve; todos os sons da agenda existem.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_comer_voxel_e_akuma_na_mao.gd
const P = preload("res://src/historia/tripulantes/provisoes.gd")
const SAVE := "user://test_comer_voxel.json"
var falhas := 0
var total := 0
func _init() -> void: call_deferred("_r")
func ok(c: bool, m: String) -> void:
	total += 1
	if not c: falhas += 1
	print(("OK: " if c else "FALHOU: ") + m)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _r() -> void:
	await process_frame
	# --- sem jogo: modelos e sons existem
	var perfis: Array = AlimentosVoxel.PERFIL.keys()
	for id in perfis:
		ok(AlimentosVoxel.cena(id) != null, "modelo voxel de %s" % id)
		var caixa := _caixa(AlimentosVoxel.instanciar(id))
		ok(caixa.size.x > 0.05 and caixa.size.y > 0.05 and maxf(maxf(caixa.size.x, caixa.size.y), caixa.size.z) < 0.35, "%s cabe na mão (%s)" % [id, caixa.size])
	var rng := RandomNumberGenerator.new()
	var faltam: Array = []
	for variante in perfis + ["akuma:mera_mera"]:
		for tipo in ["comida", "agua"]:
			for e: Dictionary in AlimentosVoxel.agenda(variante, tipo):
				if AlimentosVoxel.som(e.som, rng) == null: faltam.append(e.som)
	ok(faltam.is_empty(), "todos os sons da agenda existem (faltam %s)" % str(faltam))
	ok(AlimentosVoxel.cena("akuma:mera_mera") != null and AlimentosVoxel.cena("akuma:hito_hito_nika") != null, "modelo da Akuma e do alias (Nika → Gomu Gomu)")
	ok(AlimentosVoxel.valida("maca") and AlimentosVoxel.valida("akuma:mera_mera") and not AlimentosVoxel.valida("../x") and not AlimentosVoxel.valida("akuma:nao_existe"), "variantes da rede: só as conhecidas")
	# --- jogo
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var pers = ProgressaoDoPersonagem.carregar(SAVE)
	pers.corpo = "masculino"
	pers.salvar(SAVE)
	root.get_node("GameFlow").start_story()
	await quadros(160)
	var cena = current_scene
	var j = cena.jogador_local()
	var prog: ProgressaoDoPersonagem = cena.progressao
	var ali = j.get_node("AlimentacaoVisual")
	j.set_meta("damage_immune", true)
	# alimentos: o modelo do item que vai ser consumido
	P.guardar(prog, "maca", 2)
	P.guardar(prog, "leite", 2)
	prog.item_ativo = "comida"
	prog.mudou.emit()
	await quadros(5)
	ok(ali.variante == "maca" and ali._tipo_visual == "maca", "comida equipada mostra a maçã voxel (%s / %s)" % [ali.variante, ali._tipo_visual])
	prog.item_ativo = "agua"
	prog.mudou.emit()
	await quadros(5)
	ok(ali.variante == "leite" and ali._tipo_visual == "leite", "bebida equipada mostra o leite voxel (%s)" % ali._tipo_visual)
	prog.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
	prog.mudou.emit()
	await quadros(5)
	# Akuma na mão
	prog.receber_fruta("mera_mera")
	prog.receber_fruta("gomu_gomu")
	var slot_mera := -1
	for i in range(InventarioMinecraft.HOTBAR_INI, InventarioMinecraft.HOTBAR_FIM):
		if InventarioMinecraft.id_de(prog.inventario.pilha(i)) == "akuma:mera_mera": slot_mera = i
	prog.inventario.selecionado = slot_mera - InventarioMinecraft.HOTBAR_INI
	await quadros(8)
	ok(ali._tipo_visual == "akuma:mera_mera" and is_instance_valid(ali.visual), "Akuma do slot selecionado fica na mão (%s)" % ali._tipo_visual)
	var tam := _caixa(ali.visual)
	ok(tam.size.y > 0.1, "a Akuma na mão tem tamanho (%s)" % tam.size)
	# comer: gesto com sons; o poder só ao engolir
	var clique = j.clique_de_blocos
	ok(clique != null, "o clique de blocos está instalado")
	var sons := [0]
	var antes_fruta := prog.fruta
	clique._comer_akuma_da_mao()
	await quadros(30)
	ok(ali.comendo_akuma() and prog.fruta == antes_fruta and prog.quantas_akuma("mera_mera") == 1, "comendo: gesto em curso, poder ainda não vale, fruta ainda no inventário")
	await quadros(80)
	ok(ali._som != null and is_instance_valid(ali._som), "o som de comer foi criado no jogador")
	await quadros(120)
	ok(not ali.comendo_akuma() and prog.fruta == "mera_mera" and prog.quantas_akuma("mera_mera") == 0, "engoliu: poder vale e a fruta saiu do inventário (%s)" % prog.fruta)
	# interrupção: a fruta volta intacta
	var slot_gomu := -1
	for i in range(InventarioMinecraft.HOTBAR_INI, InventarioMinecraft.HOTBAR_FIM):
		if InventarioMinecraft.id_de(prog.inventario.pilha(i)) == "akuma:gomu_gomu": slot_gomu = i
	prog.inventario.selecionado = slot_gomu - InventarioMinecraft.HOTBAR_INI
	await quadros(5)
	clique._comer_akuma_da_mao()                       # 1º clique: confirmação (já há fruta no corpo)
	clique._comer_akuma_da_mao()                       # 2º: começa
	await quadros(40)
	ok(ali.comendo_akuma(), "segundo clique inicia o gesto")
	j.set_meta("custom_pose", "golpe")                 # uma ação do corpo corta o gesto
	await quadros(5)
	j.remove_meta("custom_pose")
	ok(not ali.comendo_akuma() and prog.fruta == "mera_mera" and prog.quantas_akuma("gomu_gomu") == 1, "gesto cortado: continua com a Mera e a Gomu segue no inventário")
	modo.mapa_forcado = ""; modo.progresso_forcado = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("COMER_VOXEL %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
func _caixa(no: Node) -> AABB:
	var caixa := AABB()
	var primeiro := true
	if no == null: return caixa
	for mi in no.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY                  # transformação do mesh até `no` (inclusive), sem depender de estar na árvore
		var n: Node = mi
		while n != null and n is Node3D:
			t = (n as Node3D).transform * t
			if n == no: break
			n = n.get_parent()
		var a: AABB = t * (mi as MeshInstance3D).get_aabb()
		caixa = a if primeiro else caixa.merge(a)
		primeiro = false
	return caixa
