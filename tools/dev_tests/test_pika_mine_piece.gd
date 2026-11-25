extends SceneTree
## Pika Pika (Mine Piece): loja e substituição da versão do Builder, R/Z, as seis técnicas
## (lasers, Yata no Kagami + chute, Acceleration is Power, Yasakani, Ama no Murakumo como o
## item da fruta), a passiva por toque duplo, sem transformação (removida em 24/11/2026), save e troca. Save/mapa isolados.
const MAPA := "user://test_pika_mine_piece_mapa.json"
const SAVE := "user://test_pika_mine_piece_progresso.json"
const ID := "pika_pika_mine_piece"
const ANTIGA := "pika_pika_no_mi_mine_piece"
const ESCALA := 1.0 / 10.0   # PerfilDeFrutas.ESCALA_DO_MOD: o dano do mod, sem conversão (26/10/2026)
var falhas := 0
var passou := 0
var luzes_criadas := 0
var ondas_criadas := 0

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
		if sc != null and sc.resource_path.ends_with("luz_pika.gd"):
			luzes_criadas += 1
		if sc != null and sc.resource_path.ends_with("onda_de_impacto_mine_piece.gd"):
			ondas_criadas += 1)
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var p = get_first_node_in_group("player")
	var prog: ProgressaoDoPersonagem = current_scene.progressao

	# ------------------------------------------------ loja, substituição, save
	var venda := PerfilDeFrutas.frutas_a_venda()
	conferir("vende a tradução pelo preço da raridade (≥ 1000)", venda.has(ID) and PerfilDeFrutas.preco_na_loja(ID) == PerfilDeFrutas.PRECO_POR_PODER[PerfilDeFrutas.poder_da_fruta(ID) - 1])
	conferir("a versão do Builder saiu da loja", not venda.has(ANTIGA))
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
	p.set_meta("damage_immune", true)
	await a_postos(p, c, null)
	# 08/11/2026: cada técnica na sua tecla (Z X C V B N, na ordem do ciclo); R não troca mais nada.
	var teclas_da_fruta: Dictionary = c.mapa_de_teclas()
	conferir("Z X C V B N = 21 22 24 27 29 30 (%s)" % [teclas_da_fruta], teclas_da_fruta == {"Z": 21, "X": 22, "C": 24, "V": 27, "B": 29, "N": 30})
	tecla(KEY_R, true)
	tecla(KEY_R, false)
	await quadros(2)
	conferir("R não troca mais a técnica", c.selecao == 21)

	var alvo := Alvo.new()
	current_scene.add_child(alvo)

	# ------------------------------------------------------------- 21 Laser
	await a_postos(p, c, alvo)
	var antes: float = p.energy
	tecla_sel(c, true)
	await quadros(1)
	conferir("Laser custa 150 de energia (o custo do mod, sem conversão) e recarrega 3,75 s (gastou %.2f)" % (antes - float(p.energy)), c.ativo and absf(antes - float(p.energy) - 150.0) < 0.5 and is_equal_approx(c.recarga_total, 3.75))
	tecla_sel(c, false)
	await quadros(45)
	conferir("o feixe fere 17 × CNT6 (%.2f)" % (1000.0 - alvo.health), (1000.0 - alvo.health) >= 17.0 * 10.0 * ESCALA - 0.05)
	conferir("e deixa a onda de impacto (%d)" % ondas_criadas, ondas_criadas == 1)
	await capturar("pika_laser")
	await quadros(30)
	conferir("Laser termina", not c.ativo)

	# ------------------------------------------------------- 22 Amano-Iwato
	await a_postos(p, c, alvo)
	c.selecao = 22
	antes = p.energy
	tecla_sel(c, true)
	await quadros(1)
	var custo_ai := antes - float(p.energy)
	await quadros(4)
	conferir("Amano-Iwato custa 600 de energia e prende o corpo", absf(custo_ai - 600.0) < 0.5 and c.lentidao >= 9)
	tecla_sel(c, false)
	await quadros(80)
	conferir("o laser do pé fere 24 × CNT6 (%.2f)" % (1000.0 - alvo.health), (1000.0 - alvo.health) >= 24.0 * 10.0 * ESCALA - 0.05)
	await quadros(40)
	conferir("Amano-Iwato termina", not c.ativo)

	# ---------------------------------------------------- 24 Yata no Kagami
	await a_postos(p, c, alvo)
	c.selecao = 24
	tecla_sel(c, true)
	await quadros(1)
	tecla_sel(c, false)
	await quadros(60)
	conferir("Yata no Kagami: teleporta até o alvo (%.1f m)" % p.global_position.distance_to(alvo.global_position),
		p.global_position.distance_to(alvo.global_position) < 4.0)
	conferir("e o chute fere 17 × CNT6 (%.2f)" % (1000.0 - alvo.health), (1000.0 - alvo.health) >= 17.0 * 10.0 * ESCALA - 0.05)
	await quadros(40)
	conferir("Yata no Kagami termina", not c.ativo)

	# ---------------------------------------------- 27 Acceleration is Power!!!
	await a_postos(p, c, alvo)
	c.selecao = 27
	tecla_sel(c, true)
	await quadros(1)
	tecla_sel(c, false)
	await quadros(20)
	conferir("Acceleration: some e fica acima do alvo", p.get_meta("mine_piece_invisivel", false) and p.global_position.y > alvo.global_position.y + 1.0
		and absf(p.global_position.z - alvo.global_position.z) < 1.5)
	await quadros(50)
	conferir("mergulha e fere (%.2f)" % (1000.0 - alvo.health), alvo.health < 1000.0 and not p.get_meta("mine_piece_invisivel", false))
	await quadros(40)
	conferir("Acceleration termina", not c.ativo)

	# ---------------------------------------------- 29 Yasakani no Magatama
	await a_postos(p, c, alvo)
	alvo.global_position = Vector3(0, 6, -9)
	c.selecao = 29
	var origem: Vector3 = p.global_position
	tecla_sel(c, true)
	await quadros(1)
	tecla_sel(c, false)
	await quadros(30)
	conferir("Yasakani: o corpo salta (%.1f m acima)" % (p.global_position.y - origem.y), p.global_position.y > origem.y + 5.0)
	alvo.global_position = p.global_position + Vector3(0, 0, -9)   # na altura do salto
	await quadros(75)
	conferir("8 flechas de luz por tick (%d)" % luzes_criadas, luzes_criadas >= 8 * 10)
	await capturar("pika_yasakani")
	conferir("as flechas ferem (%.2f)" % (1000.0 - alvo.health), alvo.health < 1000.0)
	await quadros(100)
	conferir("volta ao ponto de partida e termina", not c.ativo and p.global_position.distance_to(origem) < 1.0)

	# ------------------------------------------------ 30 Ama no Murakumo
	await a_postos(p, c, alvo)
	c.selecao = 30
	var arma = p.get_node("EspadaDaHistoria")
	var barra := BarraDeItensHud.new()
	barra.progressao = prog
	tecla_sel(c, true)
	await quadros(1)
	tecla_sel(c, false)
	await quadros(5)
	conferir("30 vira o item da fruta: Ama no Murakumo", prog.espada_da_fruta == "amano_murakumo")
	conferir("o ícone da barra vira o da espada", barra.icone_do_item("fruta").ends_with("icone_espada_luz.png")
		and barra.nome_do_item("fruta") == "Ama no Murakumo Sword")
	conferir("com a fruta equipada, a espada de luz está na mão", arma.ativa and arma.espada_de_fruta() and arma.visual() != null)
	var mult: float = p.combate_direcional.multiplicador_de_dano
	conferir("o corte vale o dano do mod (8 → %.2f)" % (26.0 * mult), absf(26.0 * mult - 8.0 * 10.0 * ESCALA) < 0.05)
	conferir("save guarda a espada", ProgressaoDoPersonagem.de_dict(prog.para_dict()).espada_da_fruta == "amano_murakumo")
	prog.ativar_item("luta")
	await quadros(5)
	conferir("trocar de item solta a espada", not arma.espada_de_fruta() and is_equal_approx(p.combate_direcional.multiplicador_de_dano, 1.0))
	prog.ativar_item("fruta")
	await quadros(5)
	c = controle.de(p)
	conferir("voltar para a fruta devolve a espada", c != null and arma.ativa and arma.espada_de_fruta())
	c.recarga = 0.0
	c.selecao = 30   # o controlador recriado volta à primeira técnica
	tecla_sel(c, true)
	await quadros(1)
	tecla_sel(c, false)
	await quadros(5)
	conferir("usar o 30 de novo larga a espada", prog.espada_da_fruta.is_empty() and not arma.espada_de_fruta())
	barra.free()

	# ------------------------------------------------- 28 passiva (toque duplo)
	await a_postos(p, c, alvo)
	alvo.global_position = Vector3(0, 1.2, -60)
	var z0: float = p.global_position.z
	for i in 2:
		tecla_fisica(KEY_W, true)
		await quadros(7)
		tecla_fisica(KEY_W, false)
		await quadros(7)
	await quadros(20)
	conferir("toque duplo W: teleporte de luz para a frente (%.1f m)" % (z0 - p.global_position.z), z0 - p.global_position.z > 10.0)
	conferir("passiva não gasta energia", is_equal_approx(p.energy, p.max_energy))

	# ----------------------------------------------- transformação elemental
	p.remove_meta("damage_immune")
	var vel_antes: float = p.speed_multiplier
	for i in 4:
		p.take_damage(1.0, p.global_position + Vector3.FORWARD, Vector3.ZERO, 0.0)
		await quadros(35)      # fora da janela de invulnerabilidade de 0,5 s (10 tiques do Minecraft) entre os golpes
	conferir("4 golpes em 3 s NÃO transformam nem dão voo", c.corpo == null and not c.controla_movimento() and is_equal_approx(p.speed_multiplier, vel_antes))
	p.set_meta("damage_immune", true)
	prog.espada_da_fruta = "amano_murakumo"
	modo.equipar_fruta(p, "goro_goro_mine_piece")
	prog.comer_fruta("goro_goro_mine_piece")
	await quadros(10)
	conferir("troca remove o controlador e comer outra larga a espada", controle.de(p) == null and prog.espada_da_fruta.is_empty())
	finalizar(modo)

func tecla_fisica(codigo: Key, apertou: bool) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode = codigo
	evento.keycode = codigo
	evento.pressed = apertou
	Input.parse_input_event(evento)

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
	print("PIKA_MINE_PIECE %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
