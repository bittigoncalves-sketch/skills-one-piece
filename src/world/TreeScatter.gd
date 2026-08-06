class_name TreeScatter
extends RefCounted
# Distribui árvores de forma ALEATÓRIA em cima de blocos do mapa.
# Determinístico (semente fixa) enquanto o mapa estiver congelado.
# Depende do gerador do Gemini: TreeAndFruitGenerator.

static func scatter(parent: Node, blocks: Array, count: int, seed_value: int) -> void:
	if blocks.is_empty():
		return
	var defs := TreeAndFruitGenerator.get_tree_definitions()
	if defs.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# Embaralha os índices dos blocos e pega os primeiros `count`.
	var idxs: Array = []
	for i in blocks.size():
		idxs.append(i)
	for i in range(idxs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = idxs[i]
		idxs[i] = idxs[j]
		idxs[j] = tmp

	var n: int = min(count, idxs.size())
	for k in n:
		var b: Dictionary = blocks[idxs[k]]
		var def: Dictionary = defs[k % defs.size()]
		var tree := TreeAndFruitGenerator.create_tree_3d(def)
		tree.position = Vector3(b["x"], b["top"], b["z"])  # em cima do bloco
		tree.rotation.y = rng.randf_range(0.0, TAU)         # giro aleatório
		parent.add_child(tree)
