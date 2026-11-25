extends SceneTree
## V5: o CLIQUE do Minecraft no jogo de verdade (Modo História): quebrar segurando, colocar, usar porta, bater com recarga.
## Não usa mouse: dirige `CliqueDeBlocos.avancar_com` com a mira que o raio de física devolve (o mesmo caminho do jogo).
##   godot --headless --path . --script tools/dev_tests/test_clique_de_blocos.gd     (com MemoryMax)
var ok := 0
var falhas := 0
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func confere(c: bool, m: String) -> void:
	if c:
		ok += 1
	else:
		falhas += 1
		print("FALHOU: ", m)
func _init() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	await process_frame
	# ---------------------------------------------------------- tabelas puras (sem jogo)
	TiposDeBloco.iniciar()
	confere(is_equal_approx(ItensDeBloco.tempo_de_quebra(TiposDeBloco.PEDRA), 2.25), "pedra: 1,5 × 1,5 s = 2,25 s")
	confere(is_equal_approx(ItensDeBloco.tempo_de_quebra(TiposDeBloco.valor(TiposDeBloco.ESCADA_BASE + TiposDeBloco.PEDRA, 0)), 2.25), "a escada de pedra demora como a pedra")
	confere(ItensDeBloco.tempo_de_quebra(TiposDeBloco.AGUA) < 0.0, "a água não quebra")
	confere(is_equal_approx(ItensDeBloco.tempo_de_quebra(TiposDeBloco.OBSIDIANA), 75.0), "obsidiana: 75 s à mão")
	confere(ItensDeBloco.drop_de(TiposDeBloco.valor(TiposDeBloco.LAJE_BASE + TiposDeBloco.PEDRA, 2)).quantidade == 2, "laje dupla dá 2 lajes")
	confere(ItensDeBloco.drop_de(TiposDeBloco.valor(TiposDeBloco.PORTA_MADEIRA, 16)).quantidade == 0, "a metade de cima da porta não dá nada (a de baixo dá a porta)")
	confere(ItensDeBloco.drop_de(TiposDeBloco.valor(TiposDeBloco.OCTANTES_BASE + TiposDeBloco.TERRENO, 0x35)).tipo == TiposDeBloco.TERRENO, "bloco de octantes do terreno dá 1 cubo de terreno")
	confere(ItensDeBloco.tipo_do_item("bloco:3") == TiposDeBloco.PEDRA and ItensDeBloco.tipo_do_item("bloco:999") == 0 and ItensDeBloco.tipo_do_item("minecraft:stone") == 0, "id de item ↔ tipo")
	confere(RegrasDeItens.limite("bloco:3") == 64 and RegrasDeItens.nome("bloco:3") == "Pedra" and RegrasDeItens.icone("bloco:3") != null, "a mochila sabe nome, limite e ícone do bloco")
	# a forma de cada bloco no raio (estáticos: sem jogo): laje, escada, porta fina
	var B := GradeVoxel.BLOCO
	var laje_v := TiposDeBloco.valor(TiposDeBloco.LAJE_BASE + TiposDeBloco.PEDRA, 0)
	var h_alto := CliqueDeBlocos._acertar_forma(Vector3(-1, 0.75 * B, 0.5 * B), Vector3.RIGHT, Vector3i.ZERO, laje_v)
	var h_baixo := CliqueDeBlocos._acertar_forma(Vector3(-1, 0.25 * B, 0.5 * B), Vector3.RIGHT, Vector3i.ZERO, laje_v)
	confere(h_alto.is_empty() and not h_baixo.is_empty() and h_baixo.normal == Vector3i(-1, 0, 0), "raio por cima da laje de baixo passa; por baixo acerta a face −x")
	var topo_laje := CliqueDeBlocos._acertar_forma(Vector3(0.5 * B, 2.0, 0.5 * B), Vector3.DOWN, Vector3i.ZERO, laje_v)
	confere(not topo_laje.is_empty() and topo_laje.normal == Vector3i.UP and absf(topo_laje.ponto.y - 0.5 * B) < 0.0001, "de cima o raio pousa no topo da laje, a meio bloco (%s)" % str(topo_laje.get("ponto")))
	var esc_v := TiposDeBloco.valor(TiposDeBloco.ESCADA_BASE + TiposDeBloco.PEDRA, 0)         # direção 0 (sul), embaixo, reta
	var por_cima := CliqueDeBlocos._acertar_forma(Vector3(0.5 * B, 2.0, 0.1 * B), Vector3.DOWN, Vector3i.ZERO, esc_v)
	var por_cima2 := CliqueDeBlocos._acertar_forma(Vector3(0.5 * B, 2.0, 0.9 * B), Vector3.DOWN, Vector3i.ZERO, esc_v)
	confere(not por_cima.is_empty() and not por_cima2.is_empty() and absf(por_cima.ponto.y - por_cima2.ponto.y) > 0.3 * B, "a escada tem dois níveis: o topo difere entre a frente e o fundo (%.2f x %.2f)" % [por_cima.get("ponto", Vector3.ZERO).y, por_cima2.get("ponto", Vector3.ZERO).y])
	var porta_v := TiposDeBloco.valor(TiposDeBloco.PORTA_MADEIRA, 0)                          # fechada, sul: 0–3/16 em z
	confere(not CliqueDeBlocos._acertar_forma(Vector3(0.5 * B, 0.5 * B, 0.6 * B), Vector3(0, 0, -1), Vector3i.ZERO, porta_v).is_empty()
		and CliqueDeBlocos._acertar_forma(Vector3(0.5 * B, 0.5 * B, 1.5 * B), Vector3(0, 0, -1), Vector3i.ZERO, porta_v).normal == Vector3i(0, 0, 1), "a porta fina é acertada pela face de trás/da frente, não pela célula inteira")
	var inv0 := InventarioMinecraft.new()
	inv0.inserir(ItensDeBloco.nova_pilha(TiposDeBloco.TIJOLO, 70))
	var inv1 := InventarioMinecraft.de_dict(inv0.para_dict())
	confere(inv1.contar("bloco:15") == 70, "bloco no inventário salva e carrega (%d)" % inv1.contar("bloco:15"))

	# ---------------------------------------------------------- o jogo
	var modo_cls = load("res://src/historia/ModoHistoria.gd")
	modo_cls.set("progresso_forcado", "user://test_clique_de_blocos.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_clique_de_blocos.json"))
	root.get_node("GameFlow").start_story()
	await frames(400)
	var j := get_first_node_in_group("player") as CharacterBody3D
	var modo := get_first_node_in_group("modo_historia")
	var prog: ProgressaoDoPersonagem = modo.progressao
	var clique := j.get("clique_de_blocos") as CliqueDeBlocos
	confere(clique != null, "o clique de blocos está instalado no jogador")
	if clique == null:
		print("RESULTADO: %d ok, %d falhas" % [ok, falhas])
		quit(1)
		return
	confere(prog.kit_de_blocos_entregue and prog.inventario.contar("bloco:3") == 0, "o kit de blocos de teste NÃO é mais entregue (pedra %d)" % prog.inventario.contar("bloco:3"))
	var meus := [[TiposDeBloco.PEDRA, 64], [TiposDeBloco.TIJOLO, 64], [TiposDeBloco.MADEIRA, 64], [TiposDeBloco.VIDRO, 32],
		[TiposDeBloco.ESCADA_BASE + TiposDeBloco.MADEIRA, 32], [TiposDeBloco.PORTA_MADEIRA, 8]]
	for k in meus.size():                                    # só na mochila (a hotbar é dos itens do jogo)
		prog.inventario.slots[InventarioMinecraft.MOCHILA_INI + k] = ItensDeBloco.nova_pilha(int(meus[k][0]), int(meus[k][1]))
	for k in range(InventarioMinecraft.HOTBAR_INI, InventarioMinecraft.HOTBAR_FIM):
		confere(not ItensDeBloco.e_de_bloco(InventarioMinecraft.id_de(prog.inventario.pilha(k))), "o kit não ocupa a hotbar (slot %d)" % k)
	prog.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
	prog.mudou.emit()
	clique.mira_ativa = func() -> bool: return true
	confere(clique.assume_as_maos(), "mãos livres: o clique assume")
	prog.item_ativo = "luta"
	confere(clique.assume_as_maos() or prog.item_em_uso() != "luta", "com o item luta o clique assume (ou o item não está na barra)")
	prog.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
	CliqueDeBlocos.ligado = false
	confere(not clique.assume_as_maos(), "chave desligada (SOCO_ANTIGO): o soco antigo volta")
	CliqueDeBlocos.ligado = true

	# ---------------------------------------------------------- mirar e quebrar segurando
	var p := j.global_position
	var de := p + Vector3(1.5, 2.0, 0.0)
	var mira := clique.alvo_em(de, Vector3.DOWN)
	confere(mira.tipo == &"bloco", "o raio para o chão acha um bloco da grade (%s)" % str(mira.get("tipo")))
	if mira.tipo != &"bloco":
		print("RESULTADO: %d ok, %d falhas" % [ok, falhas])
		quit(1)
		return
	var g: GradeVoxel = mira.grade
	var c: Vector3i = mira.celula
	var valor := g.obter(c)
	confere(valor != TiposDeBloco.AR and mira.normal == Vector3i.UP, "a célula mirada é sólida e a face é a de cima (%s)" % str(mira.normal))
	var tempo := ItensDeBloco.tempo_de_quebra(valor) / CliqueDeBlocos.VELOCIDADE_DO_SOCO      # o soco é 2× mais rápido
	var drop := ItensDeBloco.drop_de(valor)
	var antes := prog.inventario.contar(ItensDeBloco.id_do_tipo(int(drop.tipo)))
	var passo := 1.0 / 60.0
	var n := 0
	var meio := int(tempo / passo * 0.5)
	while n < meio:
		clique.avancar_com(mira, passo, true, false)
		n += 1
	confere(g.obter(c) == valor and clique.progresso > 0.4 and clique.progresso < 0.6, "na metade do tempo o bloco segue inteiro (progresso %.2f)" % clique.progresso)
	# soltar zera
	clique.avancar_com(mira, passo, false, false)
	confere(clique.progresso == 0.0, "soltar o botão zera o progresso")
	# mudar de bloco zera
	for k in 10:
		clique.avancar_com(mira, passo, true, false)
	var outra := mira.duplicate()
	outra.celula = c + Vector3i(1, 0, 0)
	if g.obter(outra.celula) != TiposDeBloco.AR:
		clique.avancar_com(outra, passo, true, false)
		confere(clique.progresso < 0.2, "mirar outro bloco recomeça o progresso (%.3f)" % clique.progresso)
	clique.avancar_com(mira, passo, false, false)
	n = 0
	var limite := int(tempo / passo) + 5
	while g.obter(c) == valor and n < limite:
		clique.avancar_com(mira, passo, true, false)
		n += 1
	confere(g.obter(c) == TiposDeBloco.AR, "segurando o tempo todo o bloco quebra (%d quadros, esperado ~%d)" % [n, int(tempo / passo)])
	confere(absf(float(n) - tempo / passo) <= 3.0, "o tempo de quebra bate com a dureza (%d vs %.0f)" % [n, tempo / passo])
	confere(prog.inventario.contar(ItensDeBloco.id_do_tipo(int(drop.tipo))) == antes + int(drop.quantidade), "o drop foi para o inventário (+%d)" % int(drop.quantidade))
	clique.avancar_com(mira, passo, false, false)

	# ---------------------------------------------------------- alcance a partir da MIRA, não do corpo
	var cam0 := p + Vector3(-4.0, 2.0, 0.0)                  # câmera 4 m atrás
	var olhos_t := p + Vector3(0, CliqueDeBlocos.ALTURA_DOS_OLHOS, 0)
	var aceitos_de_lado := 0
	var acima_do_alcance := 0                                # aceitos que a distância EM LINHA RETA do corpo recusaria
	for x in [1.0, 2.0, 3.0]:
		for zz in [-5.0, -4.0, -3.5, 3.5, 4.0, 5.0]:
			var m_l := clique.alvo_em(cam0, (p + Vector3(x, -1.5, zz)) - cam0)
			if m_l.tipo == &"bloco":
				aceitos_de_lado += 1
				var dir_l := ((p + Vector3(x, -1.5, zz)) - cam0).normalized()
				var ao_longo: float = (m_l.ponto - cam0).dot(dir_l) - (olhos_t - cam0).dot(dir_l)
				confere(ao_longo <= CliqueDeBlocos.ALCANCE + 0.01, "todo bloco aceito está dentro do alcance AO LONGO da mira (%.2f)" % ao_longo)
				if olhos_t.distance_to(m_l.ponto) > CliqueDeBlocos.ALCANCE:
					acima_do_alcance += 1
	confere(aceitos_de_lado > 0 and acima_do_alcance > 0, "a mira de lado alcança blocos que a distância reta do corpo recusaria (%d aceitos, %d além do reto)" % [aceitos_de_lado, acima_do_alcance])
	var m_longe := clique.alvo_em(cam0, (p + Vector3(12.0, -1.5, 0.0)) - cam0)
	confere(m_longe.tipo != &"bloco", "além do alcance da mira não é alvo")
	# câmera de frente: a mira é a do personagem
	var rig: Object = j.rig_da_camera()
	var a0: bool = rig.alternar_perspectiva()                     # 3ª → 1ª
	confere(a0 and rig.em_primeira_pessoa() and not rig.em_frente(), "F5: terceira → primeira pessoa")
	rig.alternar_perspectiva()                               # 1ª → frente
	confere(rig.em_frente() and not rig.em_primeira_pessoa(), "F5: primeira pessoa → de frente")
	await frames(5)
	var cam_f := j.get_viewport().get_camera_3d()
	var para_a_camera := (cam_f.global_position - j.global_position)
	var mira_rig: Vector3 = rig.direcao_da_mira()
	confere(para_a_camera.dot(Vector3(mira_rig.x, 0, mira_rig.z)) > 1.0, "de frente a câmera fica NA FRENTE do personagem, para onde ele mira (%.2f m)" % para_a_camera.dot(Vector3(mira_rig.x, 0, mira_rig.z)))
	confere((-cam_f.global_transform.basis.z).dot(mira_rig) < -0.9, "e olha de volta para ele (oposta à mira)")
	rig.alternar_perspectiva()                               # frente → 3ª
	confere(not rig.em_frente() and not rig.em_primeira_pessoa(), "F5: de frente → terceira pessoa de novo")
	await frames(5)

	# ---------------------------------------------------------- quebrar em TODAS as direções (baixo, cima, frente, trás, lados)
	var lim: Vector2 = j.limites_de_pitch()
	confere(lim.x <= -1.45 and lim.y >= 1.45, "com o clique nas mãos a mira vai quase à vertical, para baixo e para cima (%s)" % str(lim))
	var olhos_d := j.global_position + Vector3(0, CliqueDeBlocos.ALTURA_DOS_OLHOS, 0)
	var cel_olhos := GradeVoxel.celula_em(olhos_d)
	var dirs := {"baixo": Vector3.DOWN, "cima": Vector3.UP, "frente": Vector3(0, 0, -1), "trás": Vector3(0, 0, 1), "esquerda": Vector3(-1, 0, 0), "direita": Vector3(1, 0, 0)}
	var passos := {"baixo": Vector3i(0, -2, 0), "cima": Vector3i(0, 2, 0), "frente": Vector3i(0, 0, -2), "trás": Vector3i(0, 0, 2), "esquerda": Vector3i(-2, 0, 0), "direita": Vector3i(2, 0, 0)}
	for nome in dirs:
		var alvo_c: Vector3i = cel_olhos + passos[nome]
		var guardado := g.obter(alvo_c)
		g.definir(alvo_c, TiposDeBloco.PEDRA)                 # um bloco de pedra a 2 células dos olhos, naquela direção
		var m_d := clique.alvo_em(olhos_d, dirs[nome])
		var achou: bool = m_d.tipo == &"bloco" and m_d.celula == alvo_c
		if not achou:
			print("DBG ", nome, " ", m_d, " alvo=", alvo_c, " olhos=", olhos_d, " cel_olhos=", cel_olhos)
		confere(achou, "a mira dos olhos para %s acha o bloco naquela direção (%s)" % [nome, str(m_d.get("celula"))])
		if achou:
			var passos_q := int(ItensDeBloco.tempo_de_quebra(TiposDeBloco.PEDRA) / CliqueDeBlocos.VELOCIDADE_DO_SOCO / passo) + 14
			for k in passos_q:
				clique.avancar_com(m_d, passo, true, false)
			confere(g.obter(alvo_c) == TiposDeBloco.AR, "e quebra o bloco para %s" % nome)
			clique.avancar_com(m_d, passo, false, false)
		else:
			g.definir(alvo_c, guardado)

	# ---------------------------------------------------------- colocar
	await frames(10)
	var inv := prog.inventario
	inv.slots[InventarioMinecraft.HOTBAR_INI + 8] = ItensDeBloco.nova_pilha(TiposDeBloco.PEDRA, 5)
	inv.selecionado = 8
	var pedras_antes := inv.contar("bloco:3")
	g.esperar_tudo()                                         # a colisão da seção refeita entra em threads: sem isto o teste dependia da carga da máquina
	await frames(2)
	var mira2 := clique.alvo_em(de, Vector3.DOWN)          # agora o raio bate no fundo do buraco
	confere(mira2.tipo == &"bloco" and mira2.celula == c + Vector3i.DOWN, "depois de quebrar, a mira vê o bloco de baixo")
	clique.avancar_com(mira2, passo, false, true)
	confere(g.obter(c) == TiposDeBloco.PEDRA, "o botão direito com pedra na mão coloca a pedra na célula de cima (%d)" % TiposDeBloco.tipo_de(g.obter(c)))
	confere(inv.contar("bloco:3") == pedras_antes - 1, "gastou 1 da pilha da mão (%d → %d)" % [pedras_antes, inv.contar("bloco:3")])
	clique.avancar_com(mira2, passo, false, false)
	# repetir segurando: a cada 0,2 s
	var cont := [0]                                          # lambda captura por valor: o contador vai num Array
	clique.colocou.connect(func(_c, _v): cont[0] += 1)
	# SEM esperar a colisão: a mira vê o bloco recém-colocado pelos dados (a física só chega depois da thread de malha)
	for k in 30:                                             # 0,5 s segurando
		clique.avancar_com(clique.alvo_em(de, Vector3.DOWN), passo, false, true)
	var colocados: int = cont[0]
	confere(colocados >= 2 and colocados <= 3, "segurando o direito repete a colocação devagar (%d em 0,5 s)" % colocados)
	clique.avancar_com(mira2, passo, false, false)
	await frames(30)

	# ---------------------------------------------------------- não coloca dentro do jogador
	var aos_pes := {"tipo": &"bloco", "grade": g, "celula": c + Vector3i(0, -1, 0), "normal": Vector3i.UP, "ponto": p, "y_na_face": 1.0}
	var celula_dos_pes := GradeVoxel.celula_em(p + Vector3(0, 0.1, 0))
	aos_pes.celula = celula_dos_pes - Vector3i.UP
	var antes_pes := g.obter(celula_dos_pes)
	if antes_pes == TiposDeBloco.AR:
		clique.avancar_com(aos_pes, passo, false, true)
		clique.avancar_com(aos_pes, passo, false, false)
		confere(g.obter(celula_dos_pes) == TiposDeBloco.AR, "o bloco não nasce dentro do jogador")

	# ---------------------------------------------------------- formas: escada, laje, porta
	var topo := {"tipo": &"bloco", "grade": g, "celula": c + Vector3i(3, -2, 0), "normal": Vector3i.UP, "ponto": Vector3.ZERO, "y_na_face": 1.0}
	# acha um chão livre de verdade para 3 colocações: sobe a coluna até o ar
	var base := c + Vector3i(3, -2, 0)
	while g.obter(base + Vector3i.UP) != TiposDeBloco.AR and base.y < c.y + 8:
		base += Vector3i.UP
	topo.celula = base
	inv.slots[InventarioMinecraft.HOTBAR_INI + 8] = ItensDeBloco.nova_pilha(TiposDeBloco.ESCADA_BASE + TiposDeBloco.PEDRA, 3)
	clique.avancar_com(topo, passo, false, true)
	clique.avancar_com(topo, passo, false, false)
	var esc := g.obter(base + Vector3i.UP)
	confere(TiposDeBloco.e_escada(esc), "escada na mão vira ESCADA na grade (tipo %d)" % TiposDeBloco.tipo_de(esc))
	# laje embaixo, e a segunda no topo a completa
	inv.slots[InventarioMinecraft.HOTBAR_INI + 8] = ItensDeBloco.nova_pilha(TiposDeBloco.LAJE_BASE + TiposDeBloco.PEDRA, 3)
	var topo2 := topo.duplicate()
	topo2.celula = base + Vector3i(1, 0, 0)
	while g.obter(topo2.celula + Vector3i.UP) != TiposDeBloco.AR:
		topo2.celula += Vector3i.UP
	clique.avancar_com(topo2, passo, false, true)
	clique.avancar_com(topo2, passo, false, false)
	var lc: Vector3i = topo2.celula + Vector3i.UP
	var laje := g.obter(lc)
	confere(TiposDeBloco.tipo_de(laje) == TiposDeBloco.LAJE_BASE + TiposDeBloco.PEDRA and TiposDeBloco.estado_de(laje) == 0, "laje clicada em cima fica EMBAIXO (estado %d)" % TiposDeBloco.estado_de(laje))
	var sobre_laje := {"tipo": &"bloco", "grade": g, "celula": lc, "normal": Vector3i.UP, "ponto": Vector3.ZERO, "y_na_face": 0.5}
	clique.avancar_com(sobre_laje, passo, false, true)
	clique.avancar_com(sobre_laje, passo, false, false)
	confere(TiposDeBloco.estado_de(g.obter(lc)) == 2 and inv.pilha(InventarioMinecraft.HOTBAR_INI + 8).quantidade == 1, "outra laje por cima completa o bloco (estado %d, sobram %d)" % [TiposDeBloco.estado_de(g.obter(lc)), inv.pilha(InventarioMinecraft.HOTBAR_INI + 8).quantidade])
	# porta
	inv.slots[InventarioMinecraft.HOTBAR_INI + 8] = ItensDeBloco.nova_pilha(TiposDeBloco.PORTA_MADEIRA, 2)
	var topo3 := topo.duplicate()
	topo3.celula = base + Vector3i(0, 0, 3)
	while g.obter(topo3.celula + Vector3i.UP) != TiposDeBloco.AR or g.obter(topo3.celula + Vector3i(0, 2, 0)) != TiposDeBloco.AR and topo3.celula.y < base.y + 8:
		topo3.celula += Vector3i.UP
	clique.avancar_com(topo3, passo, false, true)
	clique.avancar_com(topo3, passo, false, false)
	var pc: Vector3i = topo3.celula + Vector3i.UP
	confere(TiposDeBloco.tipo_de(g.obter(pc)) == TiposDeBloco.PORTA_MADEIRA and TiposDeBloco.tipo_de(g.obter(pc + Vector3i.UP)) == TiposDeBloco.PORTA_MADEIRA, "a porta ocupa duas células")
	var fechada := (TiposDeBloco.estado_de(g.obter(pc)) & 4) == 0
	inv.selecionado = 0                                       # mão sem bloco: o direito só USA
	var na_porta := {"tipo": &"bloco", "grade": g, "celula": pc, "normal": Vector3i(0, 0, 1), "ponto": Vector3.ZERO, "y_na_face": 0.5}
	clique.avancar_com(na_porta, passo, false, true)
	clique.avancar_com(na_porta, passo, false, false)
	confere(fechada and (TiposDeBloco.estado_de(g.obter(pc)) & 4) != 0 and (TiposDeBloco.estado_de(g.obter(pc + Vector3i.UP)) & 4) != 0, "o botão direito na porta abre as duas metades")
	clique.avancar_com(na_porta, passo, false, true)
	clique.avancar_com(na_porta, passo, false, false)
	confere((TiposDeBloco.estado_de(g.obter(pc)) & 4) == 0, "e fecha de novo")
	# quebrar a porta: o drop é UMA porta e as duas metades somem
	var portas_antes := inv.contar("bloco:10")
	clique.quebrar(g, pc + Vector3i.UP)
	confere(g.obter(pc) == TiposDeBloco.AR and g.obter(pc + Vector3i.UP) == TiposDeBloco.AR and inv.contar("bloco:10") == portas_antes, "quebrar a metade de cima leva a porta toda (drop vem da metade de baixo)")

	# ---------------------------------------------------------- regras do Minecraft: atraso depois de quebrar, ar, direito durante a quebra
	var gx := clique.grade_de(c)
	var a1 := c + Vector3i(0, 0, 3)
	var a2 := c + Vector3i(0, 0, 4)
	g.definir(a1, TiposDeBloco.TERRA)
	g.definir(a2, TiposDeBloco.TERRA)
	var t_terra := ItensDeBloco.tempo_de_quebra(TiposDeBloco.TERRA) / CliqueDeBlocos.VELOCIDADE_DO_SOCO
	var m1 := {"tipo": &"bloco", "grade": g, "celula": a1, "normal": Vector3i.UP, "ponto": Vector3.ZERO, "y_na_face": 1.0}
	var m2 := {"tipo": &"bloco", "grade": g, "celula": a2, "normal": Vector3i.UP, "ponto": Vector3.ZERO, "y_na_face": 1.0}
	clique._atraso = 0.0                                     # o atraso de uma quebra anterior só se gasta segurando o botão
	var q1 := 0
	while g.obter(a1) != TiposDeBloco.AR and q1 < 600:
		clique.avancar_com(m1, passo, true, false)
		q1 += 1
	var q2 := 0
	while g.obter(a2) != TiposDeBloco.AR and q2 < 600:
		clique.avancar_com(m2, passo, true, false)         # sem soltar o botão: o 2º bloco espera o atraso de 5 ticks (÷ velocidade do soco)
		q2 += 1
	confere(float(q2 - q1) >= CliqueDeBlocos.ATRASO_APOS_QUEBRAR / passo - 2.0, "depois de quebrar, segurar o botão espera o atraso antes do próximo bloco (%d x %d quadros; atraso %.0f)" % [q2, q1, CliqueDeBlocos.ATRASO_APOS_QUEBRAR / passo])
	confere(absf(float(q1) - t_terra / passo) <= 3.0, "o tempo da terra bate com a dureza ao longo de uma quebra isolada (%d vs %.0f)" % [q1, t_terra / passo])
	clique.avancar_com(m1, passo, false, false)
	# no ar a quebra é 5× mais lenta
	g.definir(a1, TiposDeBloco.TERRA)
	j.velocity = Vector3(0, 30.0, 0)
	j.global_position += Vector3(0, 0.3, 0)
	await physics_frame
	var no_ar := not j.is_on_floor()
	var q3 := 0
	var antes_prog := 0.0
	if no_ar:
		for k in 20:
			clique.avancar_com(m1, passo, true, false)
		antes_prog = clique.progresso
		confere(antes_prog < 20.0 * passo * CliqueDeBlocos.VELOCIDADE_DO_SOCO / ItensDeBloco.tempo_de_quebra(TiposDeBloco.TERRA) * 0.5, "no ar o progresso de quebra anda a 1/5 (%.3f em 20 quadros)" % antes_prog)
	clique.avancar_com(m1, passo, false, false)
	g.definir(a1, TiposDeBloco.AR)
	j.velocity = Vector3.ZERO
	await frames(90)
	# direito não coloca enquanto o esquerdo está quebrando
	inv.slots[InventarioMinecraft.HOTBAR_INI + 8] = ItensDeBloco.nova_pilha(TiposDeBloco.PEDRA, 3)
	inv.selecionado = 8
	g.definir(a2, TiposDeBloco.TERRA)
	var topo_a2 := {"tipo": &"bloco", "grade": g, "celula": a2, "normal": Vector3i.UP, "ponto": Vector3.ZERO, "y_na_face": 1.0}
	for k in 5:
		clique.avancar_com(topo_a2, passo, true, false)        # começou a quebrar
	var mao_antes := inv.na_mao().quantidade
	clique.avancar_com(topo_a2, passo, true, true)             # esquerdo + direito juntos
	confere(inv.na_mao().quantidade == mao_antes, "o direito não coloca enquanto se quebra (startUseItem)")
	clique.avancar_com(topo_a2, passo, false, false)
	g.definir(a2, TiposDeBloco.AR)

	# ---------------------------------------------------------- hotbar: roda, vazio, volta, nome
	var barra: BarraDeItensHud = null
	for nb in root.find_children("*", "BarraDeItensHud", true, false):
		barra = nb as BarraDeItensHud
	confere(barra != null, "a barra de itens existe no Modo História")
	if barra != null:
		barra.selecionar(0)
		confere(barra.slot_destacado() == 0, "selecionar(0)")
		barra.rolar(1.0)                                    # roda para cima = slot anterior; do 0 volta ao 8
		confere(barra.slot_destacado() == 8, "roda para cima do slot 1 volta ao 9 (%d)" % barra.slot_destacado())
		barra.rolar(-1.0)                                   # para baixo = próximo; do 8 volta ao 0
		confere(barra.slot_destacado() == 0, "roda para baixo do slot 9 volta ao 1 (%d)" % barra.slot_destacado())
		for k in 3:
			barra.rolar(-1.0)
		confere(barra.slot_destacado() == 3, "três giros para baixo andam três slots (%d)" % barra.slot_destacado())
		# um slot vazio também é selecionável e deixa as mãos livres
		prog.inventario.slots[InventarioMinecraft.HOTBAR_INI + 4] = InventarioMinecraft.vazia()
		barra.selecionar(4)
		confere(barra.slot_destacado() == 4 and prog.item_em_uso() == "" and prog.inventario.selecionado == 4, "slot vazio selecionável: mãos livres")
		# bloco no slot: fica na mão e o clique assume
		prog.inventario.slots[InventarioMinecraft.HOTBAR_INI + 4] = ItensDeBloco.nova_pilha(TiposDeBloco.TIJOLO, 9)
		barra.selecionar(4)
		confere(prog.item_em_uso() == "" and InventarioMinecraft.id_de(prog.inventario.na_mao()) == "bloco:15" and clique.assume_as_maos(), "bloco no slot vira a mão do clique")
		confere(barra._nome.text == "Tijolo" and barra._nome_t > 1.5, "o nome do item aparece ao mudar (%s, %.1f s)" % [barra._nome.text, barra._nome_t])
		barra._process(2.0)
		confere(barra._nome.modulate.a == 0.0, "e some depois de 2 s")
	# I / O aproximam e afastam a câmera; a roda não mexe mais nela
	var z0: float = rig.distancia
	j.aplicar_zoom(1.0, 0.5)                                 # O: afasta (6 m/s × 0,5 s)
	var z1: float = rig.distancia
	j.aplicar_zoom(-1.0, 0.25)                               # I: aproxima
	var z2: float = rig.distancia
	confere(j.zoom_por_teclas and absf(z1 - z0 - 3.0) < 0.01 and absf(z1 - z2 - 1.5) < 0.01, "O afasta e I aproxima a câmera (%.2f → %.2f → %.2f)" % [z0, z1, z2])
	var roda := InputEventMouseButton.new()
	roda.button_index = MOUSE_BUTTON_WHEEL_UP
	roda.pressed = true
	var z3: float = rig.distancia
	j._input(roda)
	confere(is_equal_approx(rig.distancia, z3), "a roda do mouse não mexe mais na distância da câmera")

	# ---------------------------------------------------------- bater com recarga
	var gd := GDScript.new()
	gd.source_code = "extends CharacterBody3D\nvar vida := 1000.0\nfunc take_damage(d, _o = Vector3.ZERO, _k = Vector3.ZERO, _h = 0.0):\n\tvida -= d\n"
	gd.reload()
	var boneco := gd.new() as CharacterBody3D
	root.add_child(boneco)
	boneco.global_position = j.global_position + Vector3(1.0, 0, 0)
	var v0: float = boneco.get("vida")
	var d1 := clique.bater(boneco, boneco.global_position)
	var d2 := clique.bater(boneco, boneco.global_position)      # sem esperar a recarga
	confere(d1 > 0.0 and d2 < d1 * 0.35, "bater de novo sem esperar a recarga bate fraco (%.1f depois %.1f)" % [d1, d2])
	await create_timer(0.3).timeout
	clique.avancar(0.3, false, false, false)
	var d3 := clique.bater(boneco, boneco.global_position)
	confere(is_equal_approx(d3, CliqueDeBlocos.DANO_DA_MAO), "com a recarga completa bate com o dano da mão (%.1f)" % d3)
	confere(float(boneco.get("vida")) < v0, "o bicho perdeu vida pelo funil de dano (%.1f → %.1f)" % [v0, float(boneco.get("vida"))])
	# a mira diz "bicho" quando o raio o acerta primeiro
	var colisor := CollisionShape3D.new()
	colisor.shape = CapsuleShape3D.new()
	boneco.add_child(colisor)
	boneco.global_position = j.global_position + Vector3(0.0, 0.0, 1.6)
	await frames(3)
	var alvo_b := clique.alvo_em(boneco.global_position + Vector3(0, 0.3, -1.4), Vector3(0, 0, 1))
	confere(alvo_b.tipo == &"bicho" and alvo_b.corpo == boneco, "o raio que acerta um bicho devolve o bicho, não o bloco (%s)" % str(alvo_b.get("tipo")))
	boneco.queue_free()
	print("RESULTADO: %d ok, %d falhas" % [ok, falhas])
	quit(1 if falhas > 0 else 0)
