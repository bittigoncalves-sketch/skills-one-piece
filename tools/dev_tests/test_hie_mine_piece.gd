extends SceneTree
## Hie Hie (Mine Piece): loja e substituição da versão do Builder, R/Z, as quatro
## técnicas (custo, recarga, dano, congelar), quebrar o gelo, Lentidão, transformação
## elemental, migração do save e troca de fruta. Save e mapa isolados.
const MAPA := "user://test_hie_mine_piece_mapa.json"
const SAVE := "user://test_hie_mine_piece_progresso.json"
const ID := "hie_hie_mine_piece"
const ANTIGA := "hie_hie_no_mi_mine_piece"
const ESCALA := 1.0 / 10.0   # PerfilDeFrutas.ESCALA_DO_MOD: o dano do mod, sem conversão (26/10/2026)
var falhas := 0
var passou := 0
var lancas_criadas := 0

class Alvo extends Node3D:
	var health := 1000.0
	var combate_direcional = null
	func _ready() -> void:
		add_to_group("alvo_de_golpe")
		var hb := Area3D.new()
		hb.name = "Hurtbox"
		hb.collision_layer = 0
		hb.collision_mask = 0
		add_child(hb)
		var cs := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(4, 2, 2)
		cs.shape = caixa
		hb.add_child(cs)
	func take_damage(dano: float, _origem := Vector3.ZERO, _empurrao := Vector3.ZERO, _stun := 0.0) -> void:
		health -= dano

func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	var controle = load("res://src/combat/frutas_mine_piece/controlador.gd")
	var mapa := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, mapa.mapa)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	node_added.connect(func(n: Node) -> void:
		var sc: Script = n.get_script()
		if sc != null and sc.resource_path.ends_with("lanca_de_gelo_hie.gd"):
			lancas_criadas += 1)
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var p = get_first_node_in_group("player")
	var prog: ProgressaoDoPersonagem = current_scene.progressao

	# ------------------------------------------------ loja, substituição, save
	var venda := PerfilDeFrutas.frutas_a_venda()
	conferir("vende a tradução pelo preço da raridade (≥ 1000)", venda.has(ID) and PerfilDeFrutas.preco_na_loja(ID) == PerfilDeFrutas.PRECO_POR_PODER[PerfilDeFrutas.poder_da_fruta(ID) - 1])
	conferir("a versão do Builder saiu da loja", not venda.has(ANTIGA))
	conferir("nome com Mine Piece", PerfilDeFrutas.nome_da_fruta(ID) == "Hie Hie (Mine Piece)")
	var d := prog.para_dict()
	d["fruta"] = ANTIGA
	d["frutas_compradas"] = {ANTIGA: 1}
	var migrado := ProgressaoDoPersonagem.de_dict(d)
	conferir("save: fruta antiga equipada vira a tradução", migrado.fruta == ID)
	conferir("save: fruta antiga comprada vira a tradução", migrado.quantas_akuma(ID) == 1 and migrado.quantas_akuma(ANTIGA) == 0)
	d["fruta"] = "ope_ope_mine_piece"
	conferir("save: fruta Mine Piece equipada sobrevive ao recarregar", ProgressaoDoPersonagem.de_dict(d).fruta == "ope_ope_mine_piece")

	var loja = load("res://src/historia/npcs/loja_de_frutas.gd").new()
	prog.ouro = PerfilDeFrutas.preco_na_loja(ID)
	loja.executar(prog, null, "comprar", ID)
	conferir("compra pelo preço da raridade", prog.ouro == 0 and prog.quantas_akuma(ID) == 1)
	conferir("come a fruta comprada", prog.comer_fruta_comprada(ID))
	await quadros(15)
	var c = controle.de(p)
	conferir("controlador ativo", c != null and c.fruta_ativa())
	if c == null:
		finalizar(modo)
		return
	conferir("sem efeito logia (24/11/2026): nenhum corpo elemental nem voo forçado", c.corpo == null and c.paralelo)
	conferir("modelos importados", ResourceLoader.exists("res://assets/mine_piece/frutas/hie/mp_partisan.glb")
		and ResourceLoader.exists("res://assets/mine_piece/frutas/hie/mp_passaro.glb")
		and ResourceLoader.exists("res://assets/mine_piece/frutas/hie/mp_bola_de_gelo.glb"))
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	p.set_meta("damage_immune", true)
	await quadros(30)

	# ------------------------------------------------------------ ciclo R
	var ciclo := []
	for i in 4:
		ciclo.append(c.selecao)
		avancar(c)
		await quadros(2)
	conferir("R percorre 21 → 22 → 24 → 25 (%s)" % [ciclo], ciclo == [21, 22, 24, 25] and c.selecao == 21)
	avancar(c, true)
	await quadros(2)
	conferir("Shift+R volta", c.selecao == 25)
	avancar(c)
	await quadros(2)

	# ------------------------------------------------------ 21 Partisan
	var alvo := Alvo.new()
	current_scene.add_child(alvo)
	alvo.global_position = Vector3(0, 1.2, -9)
	p.max_energy = 4000.0      # o teto do mod (a energia é a do mod: 600 no nível 1, 4000 no 20)
	p.energy = p.max_energy
	var antes: float = p.energy
	tecla_sel(c, true)
	await quadros(1)
	conferir("Partisan começa", c.ativo and c.selecao == 21)
	conferir("custo 100 de energia, o do mod (%.3f)" % (antes - float(p.energy)), absf(antes - float(p.energy) - 100.0) < 0.5)
	conferir("recarga max(100 × 0,5, 5) ticks = 2,5 s", is_equal_approx(c.recarga_total, 2.5))
	await quadros(60)
	conferir("segurar prende cnt1 em 6 e carrega", c.ativo and c.executor.cnt1 == 6 and c.executor.cnt6 > 0.5)
	conferir("Lentidão IV na carga anda a 25%", c.lentidao == 4 and c.controla_movimento())
	conferir("carga não cria lança", get_nodes_in_group("lanca_de_gelo_hie_mine_piece").is_empty())
	var carga: float = c.executor.cnt6
	tecla_sel(c, false)
	await quadros(12)
	conferir("soltar cria as 4 lanças (%d)" % lancas_criadas, lancas_criadas == 4)
	await capturar("hie_partisan")
	await quadros(30)
	conferir("Partisan termina", not c.ativo)
	var esperado := 15.0 * (1.0 + carga * 0.1) * 10.0 * ESCALA
	# invulnerableTime: um acerto por janela de 10 ticks; a lança cravada no alvo ataca até
	# cnt2 > 10 e pode acertar de novo no tick 10 (como no mod). Nunca 4 lanças juntas.
	var acertos := (1000.0 - alvo.health) / esperado
	conferir("lança fere 15 × CNT6 por janela de imunidade (%.2f = %.2f × %.2f)" % [1000.0 - alvo.health, acertos, esperado],
		acertos > 0.99 and acertos < 2.01 and absf(acertos - roundf(acertos)) < 0.01)
	var gelos := get_nodes_in_group("gelo_hie_mine_piece")
	conferir("efeito 12: alvo preso numa bola de gelo", gelos.size() == 1 and alvo.get_meta("is_frozen", false))
	conferir("lança some ao congelar", get_nodes_in_group("lanca_de_gelo_hie_mine_piece").size() < 4)
	if gelos.size() == 1:
		var gelo = gelos[0]
		var vida_gelo: float = gelo.health
		conferir("vida do gelo 30 × CNT6 (%.2f)" % vida_gelo, absf(vida_gelo - 30.0 * (1.0 + carga * 0.1) * 10.0 * ESCALA) < 0.05)
		gelo.set_meta("autor_do_dano", p.get_instance_id())
		gelo.take_damage(999.0)
		conferir("o dono não quebra o próprio gelo", is_instance_valid(gelo) and gelo.health == vida_gelo)
		gelo.set_meta("autor_do_dano", 0)
		gelo.take_damage(999.0)
		await quadros(2)
		conferir("outro quebra o gelo e solta o alvo", get_nodes_in_group("gelo_hie_mine_piece").is_empty() and not alvo.get_meta("is_frozen", false))

	# ------------------------------------------------------ 22 Pheasant Beak
	await quadros(60)   # lanças cravadas vivem até cnt2 > 10 (como no mod)
	conferir("lanças expiram", get_nodes_in_group("lanca_de_gelo_hie_mine_piece").is_empty())
	c.recarga = 0.0
	alvo.health = 1000.0
	c.imunidade.clear()
	avancar(c)
	await quadros(2)
	p.energy = p.max_energy
	antes = p.energy
	tecla_sel(c, true)
	await quadros(1)
	conferir("Pheasant Beak custa 300 de energia e recarrega 7,5 s", c.selecao == 22 and absf(antes - float(p.energy) - 300.0) < 0.5 and is_equal_approx(c.recarga_total, 7.5))
	await quadros(1)
	tecla_sel(c, false)
	await quadros(30)
	var passaros := get_nodes_in_group("lanca_de_gelo_hie_mine_piece").filter(func(n): return n.passaro)
	conferir("o pássaro de gelo nasce", passaros.size() == 1 or alvo.health < 1000.0)
	await capturar("hie_passaro")
	await quadros(40)
	conferir("pássaro fere 20 × CNT6 (%.2f)" % (1000.0 - alvo.health), absf((1000.0 - alvo.health) - 20.0 * 10.0 * ESCALA) < 0.05)
	conferir("e congela", alvo.get_meta("is_frozen", false))
	for g in get_nodes_in_group("gelo_hie_mine_piece"):
		g.queue_free()
	await quadros(2)

	# ------------------------------------------------------------ 24 Ice Ball
	p.energy = p.max_energy
	c.recarga = 0.0
	alvo.health = 1000.0
	c.imunidade.clear()
	avancar(c)
	await quadros(2)
	tecla_sel(c, true)
	await quadros(2)
	tecla_sel(c, false)
	conferir("Ice Ball custa 250 de energia", c.selecao == 24 and c.ativo)
	await quadros(18)
	var cnt6_ib: float = c.executor.cnt6
	await capturar("hie_ice_ball")
	await quadros(50)
	conferir("Ice Ball termina", not c.ativo)
	conferir("frente congelante fere 15 × CNT6 (%.2f)" % (1000.0 - alvo.health), (1000.0 - alvo.health) >= 15.0 * 10.0 * ESCALA - 0.05)
	var gelo_ib := get_nodes_in_group("gelo_hie_mine_piece")
	var vida_ib := 30.0 * (1.0 + (cnt6_ib + 5.0) * 0.1) * 10.0 * ESCALA
	conferir("e congela com o gelo de cnt6 + 5 (%.2f / %.2f)" % [gelo_ib[0].health if gelo_ib.size() > 0 else 0.0, vida_ib],
		gelo_ib.size() == 1 and absf(gelo_ib[0].health - vida_ib) < 0.05)
	for g in gelo_ib:
		g.queue_free()
	await quadros(2)

	# ------------------------------------------------------------- 25 Ice Age
	c.recarga = 0.0
	alvo.health = 1000.0
	c.imunidade.clear()
	alvo.global_position = Vector3(5, 1.2, 0)
	avancar(c)
	await quadros(2)
	p.energy = p.max_energy
	antes = p.energy
	tecla_sel(c, true)
	await quadros(1)
	var custo_age := antes - float(p.energy)
	await quadros(3)
	conferir("Ice Age custa 600 de energia e prende o corpo (Lentidão X) (%.3f)" % custo_age, c.selecao == 25 and absf(custo_age - 600.0) < 0.5 and c.lentidao >= 9)
	tecla_sel(c, false)
	await quadros(30)
	await capturar("hie_ice_age")
	await quadros(30)
	conferir("Ice Age termina", not c.ativo)
	conferir("área de gelo fere em volta (%.2f)" % (1000.0 - alvo.health), alvo.health < 1000.0)
	conferir("e congela", alvo.get_meta("is_frozen", false))

	# ------------------------------------------- quebrar o próprio gelo no clique
	for g in get_nodes_in_group("gelo_hie_mine_piece"):
		g.queue_free()
	await quadros(2)
	var Gelo = load("res://src/combat/frutas_mine_piece/gelo_hie.gd")
	var preso = Gelo.congelar(alvo, alvo, p, 0.0, 1.8, 0.6)
	await quadros(2)
	conferir("jogador congelado fica preso", preso != null and p.get_meta("is_frozen", false))
	var cliques := 0
	while is_instance_valid(preso) and not preso.is_queued_for_deletion() and cliques < 10:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = true
		Input.parse_input_event(m)
		await quadros(2)
		cliques += 1
	conferir("clicar quebra o gelo (%d cliques; 30 de vida ÷ soco 9)" % cliques, cliques == 4 and not p.get_meta("is_frozen", false))

	# ------------------------------------- sem transformação elemental (logia removida)
	await quadros(5)
	p.remove_meta("damage_immune")
	var vel_antes: float = p.speed_multiplier
	for i in 4:
		p.take_damage(1.0, p.global_position + Vector3.FORWARD, Vector3.ZERO, 0.0)
		await quadros(35)      # fora da invulnerabilidade de 0,5 s entre os golpes
	conferir("4 golpes em 3 s NÃO transformam nem dão voo", c.corpo == null and not c.controla_movimento() and is_equal_approx(p.speed_multiplier, vel_antes))
	p.set_meta("damage_immune", true)
	await quadros(30)

	# --------------------------------------------------------- troca de fruta
	modo.equipar_fruta(p, "goro_goro_mine_piece")
	await quadros(10)
	conferir("troca remove o controlador", controle.de(p) == null)
	conferir("Goro continua equipável", p.current_fruit_id == "goro_goro_mine_piece")
	finalizar(modo)

## 08/11/2026: o R não troca mais a técnica (cada uma tem a sua tecla). Os testes seguem a ordem do ciclo por aqui.
func avancar(c, para_tras := false) -> void:
	var ciclo: Array = CatalogoFrutasMinePiece.FICHAS[c.fruta_id].ciclo
	var i := 0
	for k in ciclo.size():
		if int(ciclo[k].numero) == c.selecao:
			i = k
	c.selecao = int(ciclo[posmod(i + (-1 if para_tras else 1), ciclo.size())].numero)


## A tecla (Z X C V B N) da técnica em `c.selecao`.
func tecla_sel(c, apertou: bool) -> void:
	var mapa: Dictionary = c.mapa_de_teclas()
	for letra: String in mapa:
		if int(mapa[letra]) == c.selecao:
			tecla(OS.find_keycode_from_string(letra), apertou)
			return


func tecla(codigo: Key, apertou: bool, shift := false) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = apertou
	evento.shift_pressed = shift
	Input.parse_input_event(evento)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func conferir(nome: String, ok: bool) -> void:
	if ok: passou += 1
	else: falhas += 1
	print("%s %s" % ["OK" if ok else "FALHA", nome])

func capturar(nome: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capturar" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var pasta := "res://art_src/validation/frutas_mine_piece"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	var imagem := root.get_texture().get_image()
	conferir("captura " + nome, imagem.save_png(pasta.path_join(nome + ".png")) == OK)

func finalizar(modo) -> void:
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("HIE_MINE_PIECE %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
