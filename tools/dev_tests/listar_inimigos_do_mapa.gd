extends SceneTree
## Lista todo o grupo "enemy" do mapa real (carga total): classe/script, nome, ilha e se é chefe.
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	var Modo = load("res://src/historia/ModoHistoria.gd")
	Modo.set("progresso_forcado", "user://listar_inimigos.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://listar_inimigos.json"))
	root.get_node("GameFlow").start_story()
	for i in 300: await physics_frame
	var caixas: Dictionary = current_scene.get("_streaming").caixas
	var tabela := {}
	for n in get_nodes_in_group("enemy"):
		if not (n is Node3D): continue
		var sc = n.get_script()
		var tipo: String = str(sc.resource_path).get_file() if sc != null else n.get_class()
		var ilha: String = Ilhas.ilha_em(caixas, (n as Node3D).global_position, 120.0)
		var chefe := n.is_in_group("chefes") or n.is_in_group("boss")
		var k := "%s | %s | %s" % [tipo, ilha if ilha != "" else "mar/fora", "CHEFE" if chefe else "comum"]
		tabela[k] = tabela.get(k, []) + [str(n.name)]
	var chaves := tabela.keys()
	chaves.sort()
	for k in chaves:
		var nomes: Array = tabela[k]
		print("LISTA %-62s x%-3d %s" % [k, nomes.size(), ", ".join(nomes.slice(0, 4))])
	print("LISTA total=", get_nodes_in_group("enemy").size())
	quit()
