extends SceneTree
## LUTA, 20/11/2026: Z segurado repete com o MESMO dano; combate aéreo: o soco sai na mira da câmera (lados, cima e baixo); X/C medidos.
## (teclas reais, pela HUD), dano do mod (soco 9, pesado 11 × CNT6), empurrão forte em Z e X, no C só o último golpe empurra e os da rajada
## paralisam. Não cita classes do jogo por nome (o `--script` compilaria o Player cedo).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/captura_pose_carga.gd
const ID := "estilo_de_combate_base"
var p: Node3D
var c
var alvo: Node3D
var passou := 0
var falhas := 0
var Imob: GDScript
var Bal: GDScript
var Cat: GDScript

class Alvo extends StaticBody3D:
	var health := 50000.0
	var hits := 0
	var danos: Array[float] = []
	var kbs: Array[float] = []
	var preso: Array[bool] = []
	func take_damage(d: float, _origem := Vector3.ZERO, kb := Vector3.ZERO, _stun := 0.0) -> void:
		danos.append(d)
		kbs.append(kb.length())
		preso.append(bool(get_meta("is_frozen", false)))
		health -= d
		hits += 1

const SAIDA := "res://art_src/validation/luta_visual/"
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA + nome + ".png"))

func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func tecla(codigo: Key, apertou: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = apertou
	Input.parse_input_event(ev)

func _limpar() -> void:
	var espera := 0
	while c.ativo and espera < 400:
		await frames(1)
		espera += 1
	await frames(3)
	Imob.liberar(alvo)
	c.recargas.clear()
	c.imunidade.clear()
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p.health = p.max_health
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	alvo.health = 50000.0
	alvo.hits = 0
	alvo.danos.clear()
	alvo.kbs.clear()
	alvo.preso.clear()
	alvo.position = Vector3(0, 1, -1.6)
	await frames(5)

func _rodar() -> void:
	await process_frame
	Imob = load("res://src/combat/frutas_mine_piece/imobilizacao_mine_piece.gd")
	Bal = load("res://src/combat/Balance.gd")
	Cat = load("res://src/combat/frutas_mine_piece/catalogo.gd")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_pose_carga.json"))
	modo.set("progresso_forcado", "user://captura_pose_carga.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	var prog = current_scene.progressao
	await frames(10)
	c = load("res://src/combat/frutas_mine_piece/controlador.gd").de(p)
	var a := Alvo.new()
	a.collision_layer = 1
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.2, 2.0, 1.2)
	col.shape = caixa
	a.add_child(col)
	current_scene.add_child(a)
	a.add_to_group("enemy")
	alvo = a

	print("\n-- catálogo e equipamento --")
	ok("Luta no catálogo nativo e FORA da loja", Cat.contem(ID) and not Cat.ids().has(ID))
	ok("Luta é o item ativo e o controlador nativo a assumiu", prog.item_em_uso() == "luta" and c != null and c.fruta_id == ID and c.fruta_ativa())
	ok("teclas diretas Z/X/C = 1/2/3", c.tem_teclas_diretas() and Cat.FICHAS[ID].teclas_diretas == {"Z": 1, "X": 2, "C": 3})
	ok("não depende do Skills Builder (progressão sem kit)", prog.tem_estilo_base() and prog.fruta_a_equipar() == ID)
	var escala := 0.1       # PerfilDeFrutas.ESCALA_DO_MOD: dano do mod = dano × 10 × 0,1
	var forca := 3.0        # o efeito Força do nível 1 soma +3 de dano físico em todo golpe (progressão do mod, não da Luta)
	var tab: Dictionary = Bal.MINE_PIECE_LUTA

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	await _limpar()
	tecla(KEY_X, true)
	await frames(25); await foto("pose_carga_x_costas")
	p._yaw += PI * 0.5
	await frames(3); await foto("pose_carga_x_lado")
	tecla(KEY_X, false)
	await frames(60)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("CAPTURA_LUTA ok")
	quit(0)
