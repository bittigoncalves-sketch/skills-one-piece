extends SceneTree
## Assets e HUD reais em cena isolada; --tela captura sem criar Player/capturar mouse.
const Barras := preload("res://src/ui/barras_de_criaturas.gd")
var falhas := 0
var total := 0
var barras: Control
var mundo: Node3D
var camera: Camera3D
var tela := false

class HudDeTeste extends CanvasLayer:
	var aberto := false
	func is_menu_open() -> bool: return aberto

class SistemaDeTeste extends Node:
	var jogador_de: Callable

func _init() -> void: rodar.call_deferred()
func ok(sim: bool, texto: String) -> void:
	total += 1
	if not sim: falhas += 1
	print(("OK " if sim else "FALHA ") + texto)

func atualizar() -> void:
	await physics_frame
	barras._process(0.3)

func linha(no: Node) -> Dictionary:
	for l in barras.get("_linhas"):
		if l.no == no: return l
	return {}

func animal(id: String, pos: Vector3, ficha: Dictionary) -> AnimalDaIlha:
	var a := AnimalDaIlha.new()
	mundo.add_child(a)
	a.position = pos
	a.montar(BibliotecaDeModelos.padrao(), id, ficha, {"centro": pos, "tamanho": Vector3(10, 5, 10)})
	a.set_physics_process(false)
	return a

func rodar() -> void:
	await process_frame
	tela = OS.get_cmdline_user_args().has("--tela")
	root.size = Vector2i(1280, 720)
	mundo = Node3D.new()
	root.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color("23333e")
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color.WHITE
	ambiente.environment.ambient_light_energy = 0.65
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	mundo.add_child(luz)
	luz.rotation_degrees = Vector3(-50, -25, 0)
	var chao := MeshInstance3D.new()
	chao.mesh = PlaneMesh.new()
	chao.mesh.size = Vector2(50, 50)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("425457")
	chao.material_override = material
	mundo.add_child(chao)
	camera = Camera3D.new()
	mundo.add_child(camera)
	camera.position = Vector3(6, 7, 16)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	var hud := HudDeTeste.new()
	root.add_child(hud)
	barras = Barras.new()
	hud.add_child(barras)
	barras.set_process(false)
	var urso := animal("bear", Vector3(-4, 0, 0), FichaDeAnimal.nova("predador", "quadrupede", {"nivel": 8}))
	var veado := animal("deer", Vector3(4, 0, -1), FichaDeAnimal.nova("presa", "quadrupede"))
	var pet := preload("res://src/historia/pets/caranguejo.gd").new()
	mundo.add_child(pet)
	pet.set_physics_process(false)
	pet.position = Vector3(0, 0, 1)
	pet.set_meta("nivel", 3)
	var boss := animal("gorilla_-_animated_low_poly", Vector3(1, 0, -8), FichaDeAnimal.nova("predador", "quadrupede", {"boss": true}))
	await atualizar()
	ok(not linha(urso).is_empty() and not linha(pet).is_empty() and not linha(veado).is_empty(), "hostil, aliado e neutro recebem barras")
	ok(barras.get("_linhas").size() == 3, "grupos duplicados não duplicam barras; boss excluído")
	ok(barras.get("_linhas").all(func(l): return l.cor == Color("70c991")), "todas as criaturas usam barra verde")
	ok(linha(urso).get("nivel") == 8 and linha(pet).get("nivel") == 3 and linha(veado).get("nivel") == 1, "níveis da ficha, metadado e padrão")
	urso.take_damage(100)
	await atualizar()
	ok(is_equal_approx(linha(urso).get("vida", -1), 0.5), "dano real reduz barra pela metade")
	ok(barras.ponto_acima(urso).y > urso.global_position.y and barras.ponto_acima(pet).y > pet.global_position.y, "âncoras ficam acima dos corpos")
	await foto("criaturas_depois")
	barras.hide()
	await foto("criaturas_antes")
	barras.show()
	var ponto: Vector2 = linha(pet).ponto
	pet.position.x += 1
	await atualizar()
	ok((linha(pet).ponto as Vector2).distance_to(ponto) > 1, "barra acompanha movimento")
	pet.health = 0
	await atualizar()
	ok(linha(pet).is_empty(), "morto perde barra")
	pet.health = pet.max_health
	await atualizar()
	ok(not linha(pet).is_empty(), "revivido recupera barra")
	pet.hide()
	await atualizar()
	ok(linha(pet).is_empty(), "criatura escondida não deixa barra flutuando")
	pet.show()
	pet.position = Vector3(0, 0, -100)
	await atualizar()
	ok(linha(pet).is_empty(), "distância oculta barra")
	pet.position = camera.position + camera.global_basis.z * 2
	await atualizar()
	ok(linha(pet).is_empty(), "atrás da câmera não projeta barra")
	pet.position = Vector3(0, 0, 1)
	var parede := StaticBody3D.new()
	mundo.add_child(parede)
	parede.position = camera.position.lerp(barras.ponto_acima(pet), 0.5)
	var col := CollisionShape3D.new()
	col.shape = BoxShape3D.new()
	col.shape.size = Vector3(4, 4, 1)
	parede.add_child(col)
	await atualizar()
	ok(linha(pet).is_empty(), "parede bloqueia barra")
	parede.free()
	hud.aberto = true
	await atualizar()
	ok(not barras.visible, "menu oculta barras")
	hud.aberto = false
	pet.free()
	await atualizar()
	ok(barras.get("_ancoras").size() <= 2, "criatura liberada limpa cache")
	ok(not Barras.elegivel(boss), "boss permanece excluído")
	urso.hide()
	veado.hide()
	boss.hide()
	var sistema := SistemaDeTeste.new()
	mundo.add_child(sistema)
	var humano := preload("res://src/historia/tripulantes/aliado_da_tripulacao.gd").new()
	humano.sistema = sistema
	mundo.add_child(humano)
	humano.montar("nami", BibliotecaDeModelos.padrao())
	humano.set_physics_process(false)
	camera.position = Vector3(0, 3.2, 7)
	camera.look_at(Vector3(0, 1.2, 0))
	await atualizar()
	ok(not linha(humano).is_empty(), "tripulante humano recebe barra")
	await foto("tripulante_depois")
	humano.hide()
	var besta := preload("res://src/historia/bestas_mar/besta_do_mar.gd").new()
	mundo.add_child(besta)
	var bib := BibliotecaDeModelos.padrao()
	besta.montar(bib, "besta_mar_bovina", {"tamanho": bib.tamanho_padrao("besta_mar_bovina"), "rotacao_graus": Vector3.ZERO})
	besta.set_physics_process(false)
	camera.position = Vector3(12, 12, -24)
	camera.look_at(Vector3(0, 4, 0))
	await atualizar()
	ok(not linha(besta).is_empty(), "besta marinha não boss recebe barra")
	ok(barras.ponto_acima(besta).y > topo_visual(besta), "barra da besta fica acima dos chifres")
	await foto("besta_pacifica_depois")
	besta.scale = Vector3.ONE * 1.5
	ok(barras.ponto_acima(besta).y > topo_visual(besta), "margem acompanha escala do corpo")
	mundo.free()
	hud.free()
	print("CRIATURAS: %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)

func topo_visual(no: Node3D) -> float:
	var topo := -INF
	for malha: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		if malha.mesh != null:
			topo = maxf(topo, (malha.global_transform * malha.get_aabb()).end.y)
	return topo

func foto(nome: String) -> void:
	if not tela: return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var pasta := "res://art_src/validation/vida_forja"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	root.get_texture().get_image().save_png(pasta.path_join(nome + ".png"))
