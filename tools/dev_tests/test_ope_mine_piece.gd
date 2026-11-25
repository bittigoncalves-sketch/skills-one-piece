extends SceneTree
## Compra/comer pelo fluxo real, R/Z, carga, disparo e limpeza. Save isolado.
const MAPA := "user://test_ope_mine_piece_mapa.json"
const SAVE := "user://test_ope_mine_piece_progresso.json"
var falhas := 0
var passou := 0

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
		caixa.size = Vector3(12, 5, 2)
		cs.shape = caixa
		hb.add_child(cs)
	func take_damage(dano: float, _origem: Vector3, _empurrao: Vector3, _stun: float) -> void:
		health -= dano

func _init() -> void:
	rodar.call_deferred()

func rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	var controle = load("res://src/combat/frutas_mine_piece/controlador.gd")
	var id := "ope_ope_mine_piece"
	var mapa := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, mapa.mapa)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var p = get_first_node_in_group("player")
	var prog: ProgressaoDoPersonagem = current_scene.progressao
	var loja = load("res://src/historia/npcs/loja_de_frutas.gd").new()
	prog.ouro = PerfilDeFrutas.preco_na_loja(id)
	conferir("venda nativa pelo preço da raridade", PerfilDeFrutas.frutas_a_venda().has(id) and PerfilDeFrutas.preco_na_loja(id) == PerfilDeFrutas.PRECO_POR_PODER[PerfilDeFrutas.poder_da_fruta(id) - 1])
	conferir("nome com Mine Piece", PerfilDeFrutas.nome_da_fruta(id) == "Ope Ope (Mine Piece)")
	loja.executar(prog, null, "comprar", id)
	conferir("compra pelo preço da raridade", prog.ouro == 0 and prog.quantas_akuma(id) == 1)
	conferir("come fruta comprada", prog.comer_fruta_comprada(id))
	await quadros(15)
	var c = controle.de(p)
	conferir("controlador ativo", c != null and c.fruta_ativa())
	if c == null:
		finalizar(modo)
		return
	conferir("sem executor Builder", not KitDoBuilder.e_do_builder(id) and p.perfil_de_frutas.slots().is_empty())
	conferir("modelo importado", ResourceLoader.exists("res://assets/mine_piece/frutas/ope/mp_tex_stone.glb"))
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	p.set_meta("damage_immune", true)
	await quadros(30)
	var alvo := Alvo.new()
	current_scene.add_child(alvo)
	alvo.global_position = Vector3(0, 2, -8)
	p.energy = p.max_energy
	tecla(KEY_R, true)
	tecla(KEY_R, false)
	conferir("R mantém única técnica original 23", c.selecao == 23)
	var antes: float = p.energy
	tecla(KEY_Z, true)
	conferir("Z inicia", c.ativo)
	# (a regeneração do mod, 8/s, rende ~0,1 por quadro: tolerância 0,5)
	conferir("custo original 100 (sem conversão)", absf(antes - float(p.energy) - 100.0) < 0.5)
	conferir("recarga original 50 ticks=2,5s", is_equal_approx(c.recarga_total, 2.5))
	await quadros(100)
	conferir("segurar mantém cnt1=9", c.ativo and c.executor.cnt1 == 9)
	var pedras := get_nodes_in_group("entulho_ope_mine_piece")
	conferir("quatro entulhos, sem criar infinitamente ao carregar", pedras.size() == 4)
	conferir("não dispara durante a carga", pedras.all(func(n: Node) -> bool: return not n.lancado))
	conferir("carga não fere", is_equal_approx(alvo.health, 1000.0))
	await capturar("ope_carga")
	tecla(KEY_Z, false)
	await quadros(9)
	await capturar("ope_lancamento")
	await quadros(51)
	conferir("soltar termina técnica", not c.ativo)
	conferir("entulho fere ao atravessar alvo (%.2f)" % (1000.0 - alvo.health), alvo.health < 1000.0)
	conferir("invulnerableTime compartilhado: rajada não quadruplica dano", absf((1000.0 - alvo.health) - 15.4577) < 0.1)   # 18,87 da escala antiga (× 250/2048 × 10) → o dano do mod
	conferir("recarga impede repetição", not c.comecar())
	await quadros(660)
	conferir("entulhos expiram", get_nodes_in_group("entulho_ope_mine_piece").is_empty())
	c.recarga = 0.0
	tecla(KEY_Z, true)
	await quadros(20)
	conferir("novo uso após recarga", c.ativo and not get_nodes_in_group("entulho_ope_mine_piece").is_empty())
	modo.equipar_fruta(p, "goro_goro_mine_piece")
	await quadros(10)
	conferir("troca remove controlador e entulhos", controle.de(p) == null and get_nodes_in_group("entulho_ope_mine_piece").is_empty())
	conferir("Goro continua equipada", p.current_fruit_id == "goro_goro_mine_piece" and p.get_node_or_null("GoroGoroMinePiece") != null)
	finalizar(modo)

func tecla(codigo: Key, apertou: bool) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = apertou
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
	print("OPE_MINE_PIECE %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
