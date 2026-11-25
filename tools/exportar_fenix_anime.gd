extends SceneTree
## godot --headless --path . --script tools/exportar_fenix_anime.gd
const Forma := preload("res://src/effects/phoenix/forma_phoenix.gd")
func _init() -> void: _exportar.call_deferred()
func _exportar() -> void:
	var f := Forma.new()
	f.gerar_fonte = true
	root.add_child(f)
	f.set_process(false)
	var asset := Node3D.new()
	asset.name = "FenixAnime"
	root.add_child(asset)
	for c in f.get_children(): c.reparent(asset,false)
	_owners(asset,asset)
	var cena := PackedScene.new()
	var erro := cena.pack(asset)
	if erro==OK:
		DirAccess.make_dir_recursive_absolute("res://assets/models/phoenix")
		erro = ResourceSaver.save(cena,Forma.ASSET,ResourceSaver.FLAG_COMPRESS)
	print("FENIX_EXPORT erro=",erro," destino=",Forma.ASSET)
	asset.free()
	f.free()
	quit(0 if erro==OK else 1)
func _owners(n: Node, dono: Node) -> void:
	for c in n.get_children():
		c.owner = dono
		_owners(c,dono)
