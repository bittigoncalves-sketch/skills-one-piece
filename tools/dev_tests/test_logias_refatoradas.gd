extends SceneTree
## Bateria GENÉRICA das logias refatoradas (`CatalogoFrutasMinePiece.REFATORADAS`), 24/11/2026: para cada uma —
## está no inventário de teste; equipa sem corpo de logia (sem transformação nem voo forçado); as técnicas rodam em PARALELO
## (nenhuma trava as outras), cada uma com recarga própria; ao soltar tudo o controlador volta ao repouso; e os sons novos
## (`sons/<fruta>_*.wav`) existem, importam e cobrem pelo menos 2 por técnica. Save e mapa isolados.
const MAPA := "user://test_logias_refatoradas_mapa.json"
const SAVE := "user://test_logias_refatoradas_progresso.json"
const ESCALA := 1.0 / 10.0   # PerfilDeFrutas.ESCALA_DO_MOD: o dano do mod, sem conversão (26/10/2026)
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
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var p = get_first_node_in_group("player")
	var prog: ProgressaoDoPersonagem = current_scene.progressao

	for id: String in CatalogoFrutasMinePiece.REFATORADAS:
		await testar_fruta(modo, controle, p, prog, id)
	finalizar(modo)


func testar_fruta(modo, controle, p, prog: ProgressaoDoPersonagem, id: String) -> void:
	var nome := id.replace("_mine_piece", "")
	var ficha: Dictionary = CatalogoFrutasMinePiece.FICHAS.get(id, {})
	prog.remover_akuma(id, 99)
	conferir("[%s] dar_fruta_de_teste põe no inventário" % nome, prog.dar_fruta_de_teste(id, 3) and prog.quantas_akuma(id) >= 3)
	conferir("[%s] entra no preparo do modo história" % nome, modo.frutas_refatoradas_de_teste().has(id))
	if not CatalogoFrutasMinePiece.FICHAS.has(id):
		return   # controlador próprio (Goro Goro): paralelismo, sem logia e sons em `test_goro_mine_piece`
	prog.comer_fruta(id)   # é a progressão que manda no equipado: sem isto qualquer `mudou` reequipa a fruta anterior
	await quadros(20)
	var c = controle.de(p)
	conferir("[%s] controlador paralelo e sem efeito logia" % nome, c != null and c.paralelo and c.corpo == null and bool(ficha.get("sem_logia", false)))
	if c == null:
		return
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.set_meta("damage_immune", true)
	p.max_energy = 6000.0
	p.energy = p.max_energy
	var alvo := Alvo.new()
	current_scene.add_child(alvo)
	alvo.global_position = Vector3(0, 1.2, -9)
	var mapa: Dictionary = c.mapa_de_teclas()
	var teclas: Array = mapa.keys()
	conferir("[%s] uma tecla por técnica (%d)" % [nome, teclas.size()], teclas.size() == ficha.ciclo.size())
	# recarga declarada por técnica
	var com_recarga := true
	for f: Dictionary in ficha.ciclo:
		com_recarga = com_recarga and f.has("recarga")
	conferir("[%s] cada técnica declara a própria recarga" % nome, com_recarga)
	# aperta TODAS em quadros seguidos, segurando
	var maximo := 0
	for letra: String in teclas:
		tecla(OS.find_keycode_from_string(letra), true)
		await quadros(2)
		maximo = maxi(maximo, c.sessoes.size())
	await quadros(6)
	maximo = maxi(maximo, c.sessoes.size())
	conferir("[%s] várias técnicas vivas juntas, nenhuma travou as outras (pico %d de %d)" % [nome, maximo, teclas.size()], maximo >= mini(3, teclas.size()))
	var com_recarga_viva := 0
	for n in c.recargas.keys():
		if float(c.recargas[n]) > 0.0:
			com_recarga_viva += 1
	conferir("[%s] recarga por técnica (%d em recarga)" % [nome, com_recarga_viva], com_recarga_viva >= mini(3, teclas.size()))
	for letra: String in teclas:
		tecla(OS.find_keycode_from_string(letra), false)
	await quadros(700)
	c = controle.de(p)   # o controlador é recriado se o XP mudou (armadilha conhecida): reobter
	conferir("[%s] solta tudo e o controlador volta ao repouso" % nome, c != null and c.sessoes.is_empty() and not c.ativo and not c.controla_movimento())
	# sons novos
	var pasta := "res://assets/mine_piece/frutas/%s/sons/" % nome.split("_")[0]
	var sons := 0
	var todos_ok := true
	var da := DirAccess.open(pasta)
	if da != null:
		for arq in da.get_files():
			if arq.ends_with(".wav"):
				sons += 1
				todos_ok = todos_ok and load(pasta + arq) is AudioStream
	conferir("[%s] sons novos carregáveis (%d arquivos, ≥ 2 por técnica)" % [nome, sons], todos_ok and sons >= 2 * ficha.ciclo.size() - 1)
	alvo.queue_free()
	await quadros(2)

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
	print("LOGIAS_REFATORADAS %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
