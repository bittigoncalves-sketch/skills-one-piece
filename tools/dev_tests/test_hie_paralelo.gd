extends SceneTree
## Hie Hie refatorada (24/11/2026): técnicas em PARALELO (uma não trava a outra), recarga por técnica,
## sem efeito logia, sons novos por ataque e fruta no inventário de teste. Save e mapa isolados.
const MAPA := "user://test_hie_paralelo_mapa.json"
const SAVE := "user://test_hie_paralelo_progresso.json"
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

	# ------------------------------------------------------------ paralelismo
	p.max_energy = 4000.0
	p.energy = p.max_energy
	var alvo := Alvo.new()
	current_scene.add_child(alvo)
	alvo.global_position = Vector3(0, 1.2, -9)
	conferir("sem corpo de logia", c.corpo == null)
	# Z (Partisan) segurado carregando; X, C e V entram DURANTE a carga, cada um na sua tecla.
	tecla(KEY_Z, true)
	await quadros(8)
	conferir("Z abre a sessão do Partisan", c.sessao_de(21) != null and c.sessoes.size() == 1)
	tecla(KEY_X, true)
	await quadros(2)
	conferir("X começa com o Z ainda carregando", c.sessao_de(22) != null and c.sessao_de(21) != null)
	tecla(KEY_C, true)
	await quadros(2)
	tecla(KEY_V, true)
	await quadros(2)
	conferir("C e V também: 4 técnicas vivas ao mesmo tempo (%d)" % c.sessoes.size(), c.sessoes.size() == 4)
	var cnt6_antes: float = c.sessao_de(21).executor.cnt6
	await quadros(10)
	conferir("a carga do Z segue andando enquanto as outras rodam", c.sessao_de(21) != null and c.sessao_de(21).executor.cnt6 > cnt6_antes)
	conferir("cada técnica tem a recarga PRÓPRIA (21: %.2f, 22: %.2f, 24: %.2f, 25: %.2f)" % [c.recargas[21], c.recargas[22], c.recargas[24], c.recargas[25]],
		c.recargas[21] > 0.0 and c.recargas[22] > 0.0 and c.recargas[24] > 0.0 and c.recargas[25] > 0.0)
	var energia: float = p.energy
	tecla(KEY_Z, false)
	tecla(KEY_Z, true)
	await quadros(2)
	conferir("repetir a mesma técnica viva não gasta energia nem abre outra sessão", absf(float(p.energy) - energia) < 5.0 and c.sessoes.size() == 4)
	tecla(KEY_Z, false)
	tecla(KEY_X, false)
	tecla(KEY_C, false)
	tecla(KEY_V, false)
	await quadros(60)
	conferir("soltar dispara: lanças e pássaro nascem (%d)" % lancas_criadas, lancas_criadas >= 5)
	conferir("a bola congelante e a era congelam o alvo", alvo.get_meta("is_frozen", false) or not get_nodes_in_group("gelo_hie_mine_piece").is_empty() or alvo.health < 1000.0)
	await quadros(500)
	conferir("todas terminam e o controlador volta ao repouso", c.sessoes.is_empty() and not c.ativo and not c.controla_movimento())

	# ---------------------------------------- recarga individual depois de terminar
	p.energy = p.max_energy
	for k in c.recargas.keys():
		c.recargas[k] = 0.0
	tecla(KEY_Z, true)
	await quadros(2)
	tecla(KEY_Z, false)
	await quadros(60)
	conferir("Partisan sozinho em recarga bloqueia só ele (2,5 s)", c.recargas[21] > 0.0 and c.sessao_de(21) == null)
	tecla(KEY_Z, true)
	await quadros(1)
	conferir("Z em recarga não reabre", c.sessao_de(21) == null)
	tecla(KEY_Z, false)
	tecla(KEY_X, true)
	await quadros(1)
	conferir("mas o X abre normalmente", c.sessao_de(22) != null)
	tecla(KEY_X, false)

	# -------------------------------- Partisan com Shift (lanças atrás do corpo) em paralelo (pedido do plano do Codex)
	await quadros(60)
	p.energy = p.max_energy
	for k in c.recargas.keys():
		c.recargas[k] = 0.0
	var antes_lancas := lancas_criadas
	tecla(KEY_SHIFT, true)   # o controlador relê o Shift do teclado a cada quadro: sem o evento de tecla, ele desfaz
	await quadros(3)
	tecla(KEY_Z, true)
	await quadros(4)
	var sessao_shift = c.sessao_de(21)
	conferir("Shift + Z abre o Partisan de trás (cnt5 = 1)", sessao_shift != null and sessao_shift.executor.cnt5 == 1)
	tecla(KEY_X, true)
	await quadros(2)
	conferir("e o X entra com ele em curso", c.sessao_de(22) != null and c.sessao_de(21) != null)
	tecla(KEY_X, false)
	await quadros(40)
	tecla(KEY_Z, false)
	await quadros(80)
	tecla(KEY_SHIFT, false)
	conferir("o Partisan de trás cria lanças (%d)" % (lancas_criadas - antes_lancas), lancas_criadas - antes_lancas >= 2)
	await quadros(300)

	# ------------------------------------------- inventário de teste das refatoradas
	conferir("a Hie está na lista das logias refatoradas", CatalogoFrutasMinePiece.REFATORADAS.has(ID))
	prog.remover_akuma(ID, 99)
	conferir("dar_fruta_de_teste põe a Hie no inventário", prog.dar_fruta_de_teste(ID, 3) and prog.quantas_akuma(ID) >= 3)
	conferir("o preparo do modo história inclui as refatoradas", modo.frutas_refatoradas_de_teste().has(ID))

	# ---------------------------------------------------------------- sons
	for cue in ["partisan_carga", "partisan_lancas", "bico_carga", "bico_voo", "bola_carga", "bola_rajada", "era_carga", "era_expande", "impacto", "congelar", "quebrar"]:
		var cam := "res://assets/mine_piece/frutas/hie/sons/hie_%s.wav" % cue
		conferir("som novo carregável: " + cue, ResourceLoader.exists(cam) and load(cam) is AudioStream)

	# ------------------------------------------------ troca de fruta cancela as sessões
	await quadros(5)
	modo.equipar_fruta(p, "goro_goro_mine_piece")
	await quadros(10)
	conferir("troca remove o controlador sem deixar sessão", controle.de(p) == null)
	finalizar(modo)

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
	print("HIE_PARALELO %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
