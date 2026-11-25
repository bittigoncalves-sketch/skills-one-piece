extends SceneTree
## Moku Moku (Mine Piece): loja e substituição da versão do Builder, R/Z, as quatro
## técnicas (custo, recarga, dano, punho, tornado, investida, campo que prende), transformação
## elemental (removida em 24/11/2026: a Moku é paralela e sem efeito logia), migração do save e troca de fruta. Save e mapa isolados.
const MAPA := "user://test_moku_mine_piece_mapa.json"
const SAVE := "user://test_moku_mine_piece_progresso.json"
const ID := "moku_moku_mine_piece"
const ANTIGA := "moku_moku_no_mi_mine_piece"
const ESCALA := 1.0 / 10.0   # PerfilDeFrutas.ESCALA_DO_MOD: o dano do mod, sem conversão (26/10/2026)
var falhas := 0
var passou := 0
var punhos_criados := 0
var tornados_criados := 0

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
		if sc != null and sc.resource_path.ends_with("punho_moku.gd"):
			punhos_criados += 1
		if sc != null and sc.resource_path.ends_with("tornado_moku.gd"):
			tornados_criados += 1)
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var p = get_first_node_in_group("player")
	var prog: ProgressaoDoPersonagem = current_scene.progressao

	# ------------------------------------------------ loja, substituição, save
	var venda := PerfilDeFrutas.frutas_a_venda()
	conferir("vende a tradução pelo preço da raridade (≥ 1000)", venda.has(ID) and PerfilDeFrutas.preco_na_loja(ID) == PerfilDeFrutas.PRECO_POR_PODER[PerfilDeFrutas.poder_da_fruta(ID) - 1])
	conferir("a versão do Builder saiu da loja", not venda.has(ANTIGA))
	conferir("nome com Mine Piece", PerfilDeFrutas.nome_da_fruta(ID) == "Moku Moku (Mine Piece)")
	var d := prog.para_dict()
	d["fruta"] = ANTIGA
	d["frutas_compradas"] = {ANTIGA: 1}
	var migrado := ProgressaoDoPersonagem.de_dict(d)
	conferir("save: a antiga equipada e comprada vira a tradução", migrado.fruta == ID and migrado.quantas_akuma(ID) == 1)
	var loja = load("res://src/historia/npcs/loja_de_frutas.gd").new()
	prog.ouro = PerfilDeFrutas.preco_na_loja(ID)
	loja.executar(prog, null, "comprar", ID)
	conferir("compra pelo preço da raridade e come", prog.ouro == 0 and prog.comer_fruta_comprada(ID))
	await quadros(15)
	var c = controle.de(p)
	conferir("controlador ativo, paralelo e sem efeito logia (24/11/2026)", c != null and c.fruta_ativa() and c.corpo == null and c.paralelo)
	if c == null:
		finalizar(modo)
		return
	conferir("modelos importados", ResourceLoader.exists("res://assets/mine_piece/frutas/moku/mp_punho.glb")
		and ResourceLoader.exists("res://assets/mine_piece/frutas/moku/mp_tornado.glb"))
	p.set_meta("damage_immune", true)
	await a_postos(p, c, null)

	var ciclo := []
	for i in 4:
		ciclo.append(c.selecao)
		avancar(c)
		await quadros(2)
	conferir("R percorre 21 → 23 → 25 → 30 (%s)" % [ciclo], ciclo == [21, 23, 25, 30] and c.selecao == 21)

	# -------------------------------------------------------- 21 White Fist
	var alvo := Alvo.new()
	current_scene.add_child(alvo)
	await a_postos(p, c, alvo)
	var antes: float = p.energy
	tecla_sel(c, true)
	await quadros(1)
	conferir("White Fist custa 120 de energia e recarrega 3 s (gastou %.2f)" % (antes - float(p.energy)), c.ativo and absf(antes - float(p.energy) - 120.0) < 0.5 and is_equal_approx(c.recarga_total, 3.0))
	conferir("carga prende o corpo (Lentidão VI)", c.lentidao == 5 and c.controla_movimento())
	await quadros(4)
	tecla_sel(c, false)
	await quadros(80)
	conferir("White Fist termina", not c.ativo)
	conferir("dois punhos de fumaça (%d)" % punhos_criados, punhos_criados == 2)
	var por_punho := 18.0 * 10.0 * ESCALA
	conferir("punho fere 18 × CNT6 por janela de imunidade (%.2f / %.2f)" % [1000.0 - alvo.health, por_punho],
		absf((1000.0 - alvo.health) / por_punho - roundf((1000.0 - alvo.health) / por_punho)) < 0.02 and alvo.health < 1000.0)
	await capturar("moku_white_fist")

	# --------------------------------------------------------- 23 White Vine
	await a_postos(p, c, alvo)
	c.selecao = 23
	var altura_antes: float = p.global_position.y
	tecla_sel(c, true)
	await quadros(1)
	tecla_sel(c, false)
	await quadros(9)
	conferir("White Vine: o corpo some e sobe acima do alvo", p.get_meta("mine_piece_invisivel", false) and p.global_position.y > altura_antes + 1.0
		and absf(p.global_position.z - alvo.global_position.z) < 1.5)
	await quadros(30)
	conferir("o tornado nasce no chão (%d)" % tornados_criados, tornados_criados == 1 and not get_nodes_in_group("tornado_moku_mine_piece").is_empty())
	await capturar("moku_white_vine")
	conferir("o tornado fere (%.2f)" % (1000.0 - alvo.health), alvo.health < 1000.0)
	await quadros(60)
	conferir("White Vine termina e o corpo volta a aparecer", not c.ativo and not p.get_meta("mine_piece_invisivel", false))

	# ------------------------------------------------------ 25 White Launcher
	for t in get_nodes_in_group("tornado_moku_mine_piece"):
		t.queue_free()
	await a_postos(p, c, alvo)
	c.selecao = 25
	var dist_antes: float = p.global_position.distance_to(alvo.global_position)
	tecla_sel(c, true)
	await quadros(1)
	tecla_sel(c, false)
	await quadros(60)
	conferir("White Launcher: investida para no alvo (%.1f → %.1f m)" % [dist_antes, p.global_position.distance_to(alvo.global_position)],
		p.global_position.distance_to(alvo.global_position) < 2.5)
	conferir("e o soco forte no fim fere (%.2f)" % (1000.0 - alvo.health), alvo.health < 1000.0)
	await quadros(20)
	conferir("White Launcher termina", not c.ativo)

	# ------------------------------------------------------------ 30 White Out
	await a_postos(p, c, alvo)
	c.selecao = 30
	antes = p.energy
	tecla_sel(c, true)
	await quadros(1)
	conferir("White Out custa 300 de energia", absf(antes - float(p.energy) - 300.0) < 0.5)
	tecla_sel(c, false)
	await quadros(60)
	conferir("o campo de fumaça prende o alvo", ImobilizacaoMinePiece.ativa(alvo) and alvo.get_meta("is_frozen", false))
	conferir("preso não leva dano antes do estouro", is_equal_approx(alvo.health, 1000.0))
	await capturar("moku_white_out_campo")
	await quadros(60)
	await capturar("moku_white_out_estouro")
	conferir("estouro fere 18 × CNT6 (%.2f)" % (1000.0 - alvo.health), (1000.0 - alvo.health) >= 18.0 * 10.0 * ESCALA - 0.05)
	await quadros(90)
	conferir("White Out termina e solta o alvo", not c.ativo and not ImobilizacaoMinePiece.ativa(alvo) and not alvo.get_meta("is_frozen", false))

	# ----------------------------------------------- transformação elemental
	p.remove_meta("damage_immune")
	var vel_antes: float = p.speed_multiplier
	for i in 4:
		p.take_damage(1.0, p.global_position + Vector3.FORWARD, Vector3.ZERO, 0.0)
		await quadros(35)      # fora da invulnerabilidade de 0,5 s (10 tiques do Minecraft) entre os golpes
	conferir("4 golpes em 3 s NÃO transformam nem dão voo", c.corpo == null and not c.controla_movimento() and is_equal_approx(p.speed_multiplier, vel_antes))
	p.set_meta("damage_immune", true)

	modo.equipar_fruta(p, "goro_goro_mine_piece")
	await quadros(10)
	conferir("troca remove o controlador", controle.de(p) == null)
	finalizar(modo)

func a_postos(p, c, alvo) -> void:
	c.cancelar()
	c.recarga = 0.0
	c.imunidade.clear()
	if c.corpo != null:
		c.corpo.desfazer()
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	p.energy = p.max_energy
	if alvo != null:
		alvo.global_position = Vector3(0, 1.2, -9)
		alvo.health = 1000.0
	await quadros(30)

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
	print("MOKU_MINE_PIECE %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
