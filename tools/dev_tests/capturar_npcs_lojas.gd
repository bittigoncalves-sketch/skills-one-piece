extends SceneTree
# ============================================================================
#  NPCs E LOJAS — fotos (03/10/2026): os três NPCs, a loja do pescador vendendo
#  peixe, a do domador, a do vendedor de frutas e o menu de técnicas da fruta.
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_npcs_lojas.gd -- <pasta>
#
#  Mapa plano dos testes + os três NPCs; progresso de TESTE (rode com XDG_DATA_HOME
#  apontando para fora do save do dono).
# ============================================================================

const MAPA := "user://capturar_npcs_mapa.json"
const PROGRESSO := "user://capturar_npcs.json"
const ONDE := {"npc_pescador": Vector3(-3, 0, -6), "npc_domador": Vector3(0, 0, -7), "npc_vendedor_frutas": Vector3(3, 0, -6)}

var saida := ""
var cam: Camera3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var bib := BibliotecaDeModelos.padrao()
	for tipo: String in ONDE:
		var tam := bib.info(tipo)["tamanho"] as Vector3
		mapa["pecas"].append({"id": "peca_" + tipo, "tipo": "modelo", "modelo": tipo,
			"posicao": ONDE[tipo] + Vector3.UP * tam.y * 0.5, "rotacao_graus": Vector3(0, 0, 0), "tamanho": tam,
			"cor": Color.WHITE, "material": "liso", "colisao": true})
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 150:
		await physics_frame
	var p: Node3D = get_first_node_in_group("player")
	var cena := current_scene
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	var hud: HistoriaHud = cena.get("_hud")
	var npcs: NpcsDaIlha = cena.get("_npcs")
	p.set_meta("damage_immune", true)
	p.global_position = Vector3(0, 1, 0)
	cam = Camera3D.new()
	cam.fov = 45
	cena.add_child(cam)
	await _foto("npcs_os_tres", Vector3(0, 1.7, -1.5), Vector3(0, 1.1, -6.5))
	# Lojas: abertas pelo mesmo caminho do E.
	prog.guardar_item_de_pesca("tuna", 3)
	prog.guardar_item_de_pesca("koi", 2)
	prog.guardar_item_de_pesca("anglerfish", 1)
	prog.ganhar_ouro(4)
	var jogo := p.find_children("*", "Camera3D", true, false)[0] as Camera3D
	jogo.make_current()
	for tipo in ["npc_pescador", "npc_domador", "npc_vendedor_frutas"]:
		for n in npcs.npcs:
			if n.tipo == tipo:
				hud.abrir_loja(n)
		await _foto_atual("loja_" + tipo.trim_prefix("npc_"))
		hud.fechar_loja()
	# Menu da fruta: a Rocket ativa e o Z usado.
	cena.dar_fruta("rocket")
	for i in 20:
		await physics_frame
	await _foto_atual("menu_tecnicas_rocket")
	p.begin_charge("Z")
	for i in 3:
		await physics_frame
	p.release_charge("Z")
	for i in 40:
		await physics_frame
	await _foto_atual("menu_tecnicas_rocket_usada")
	print("fotos em ", saida)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(0)


func _foto(nome: String, de: Vector3, para: Vector3) -> void:
	cam.make_current()
	cam.global_position = de
	cam.look_at(para)
	await _foto_atual(nome)


func _foto_atual(nome: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))
