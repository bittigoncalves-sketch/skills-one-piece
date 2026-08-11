class_name TreeAndFruitGenerator
extends Node

# ============================================================================
#  Gerador de 11 Árvores Místicas com Cores Únicas e Frutas 3D (Akuma no Mi)
#  As árvores são posicionadas sobre os cubos (obstáculos) da plataforma.
# ============================================================================

# Árvores que o mapa REALMENTE planta.
#
# ⚠️ Só entram as frutas que têm poderes no `SkillSystem`. Antes o mapa plantava
# as 11 definições abaixo, e 3 delas (`ope_ope`, `hito_hito_nika`,
# `tori_tori_phoenix`) davam frutas sem skill nenhuma — pegar uma delas virava
# Gomu Gomu **em silêncio**, por causa do fallback no `Player._fire_skill`. Era
# impossível perceber jogando: a fruta entrava no inventário com o nome certo e
# os golpes saíam errados.
#
# Filtrar aqui, e não remover as definições, é de propósito: a arte da árvore
# (cores, formato da copa) já está autorada e serve na hora que a fruta ganhar
# poderes. Dar skills a ela é o único passo que falta — e a regra do dono do
# projeto é não criar fruta nova antes de terminar as que existem.
static func get_tree_definitions() -> Array[Dictionary]:
	var com_poder := SkillSystem.get_fruit_skills()
	var out: Array[Dictionary] = []
	var fora: Array[String] = []
	for d in _todas_as_definicoes():
		if com_poder.has(str(d.get("id", ""))):
			out.append(d)
		else:
			fora.append(str(d.get("id", "")))
	if not fora.is_empty():
		print("🌳 [Árvores] fora do mapa por não terem skills: ", ", ".join(fora))
	return out

# O catálogo completo, inclusive o que ainda não é plantável. Não apague nada
# daqui — é o inventário do que existe desenhado.
static func _todas_as_definicoes() -> Array[Dictionary]:
	return [
		{
			"id": "mera_mera",
			"nome": "Árvore de Fogo (Mera Mera)",
			"foliage_color": Color(1.0, 0.35, 0.05),     # Laranja Fogo
			"trunk_color": Color(0.2, 0.1, 0.05),        # Ébano Escuro
			"fruit_color": Color(1.0, 0.2, 0.0),         # Vermelho Chama
			"fruit_glow": Color(1.0, 0.4, 0.1),
			"leaf_shape": "canopy"
		},
		{
			"id": "hie_hie",
			"nome": "Árvore de Gelo (Hie Hie)",
			"foliage_color": Color(0.45, 0.82, 1.0),      # Azul Gelo
			"trunk_color": Color(0.35, 0.45, 0.55),      # Cinza Glacial
			"fruit_color": Color(0.3, 0.75, 1.0),        # Ciano Cristal
			"fruit_glow": Color(0.5, 0.9, 1.0),
			"leaf_shape": "crystal"
		},
		{
			"id": "goro_goro",
			"nome": "Árvore Trovão (Goro Goro)",
			"foliage_color": Color(0.98, 0.9, 0.2),       # Amarelo Elétrico
			"trunk_color": Color(0.4, 0.3, 0.1),        # Madeira Queimada
			"fruit_color": Color(1.0, 0.95, 0.3),        # Ouro Raio
			"fruit_glow": Color(1.0, 1.0, 0.5),
			"leaf_shape": "canopy"
		},
		{
			"id": "gomu_gomu",
			"nome": "Árvore de Borracha (Gomu Gomu)",
			"foliage_color": Color(0.65, 0.25, 0.85),     # Violeta Púrpura
			"trunk_color": Color(0.45, 0.25, 0.15),      # Marrom Rústico
			"fruit_color": Color(0.8, 0.2, 0.4),         # Púrpura Borracha
			"fruit_glow": Color(0.9, 0.3, 0.6),
			"leaf_shape": "rounded"
		},
		{
			"id": "bara_bara",
			"nome": "Árvore Desmembrante (Bara Bara)",
			"foliage_color": Color(1.0, 0.2, 0.6),        # Rosa Choque
			"trunk_color": Color(0.6, 0.5, 0.6),        # Madeira Pálida
			"fruit_color": Color(0.9, 0.3, 0.7),        # Magentapack
			"fruit_glow": Color(1.0, 0.4, 0.8),
			"leaf_shape": "split"
		},
		{
			"id": "suna_suna",
			"nome": "Árvore Desértica (Suna Suna)",
			"foliage_color": Color(0.85, 0.7, 0.4),       # Dourado Areia
			"trunk_color": Color(0.5, 0.4, 0.25),       # Tronco Seco
			"fruit_color": Color(0.9, 0.75, 0.35),       # Âmbar Areia
			"fruit_glow": Color(1.0, 0.85, 0.5),
			"leaf_shape": "canopy"
		},
		{
			"id": "ope_ope",
			"nome": "Árvore da Cirurgia (Ope Ope)",
			"foliage_color": Color(0.1, 0.9, 0.85),      # Ciano Turquesa
			"trunk_color": Color(0.5, 0.6, 0.65),      # Prata Cirúrgico
			"fruit_color": Color(0.9, 0.2, 0.3),        # Vermelho Coração
			"fruit_glow": Color(0.0, 1.0, 0.9),
			"leaf_shape": "rounded"
		},
		{
			"id": "yami_yami",
			"nome": "Árvore Obscura (Yami Yami)",
			"foliage_color": Color(0.18, 0.05, 0.25),     # Roxo Escuro Trevas
			"trunk_color": Color(0.1, 0.1, 0.12),       # Negro Obsidiana
			"fruit_color": Color(0.2, 0.15, 0.3),       # Trevas Violeta
			"fruit_glow": Color(0.5, 0.1, 0.7),
			"leaf_shape": "canopy"
		},
		{
			"id": "hito_hito_nika",
			"nome": "Árvore do Sol (Nika / Gear 5)",
			"foliage_color": Color(0.98, 0.96, 0.9),      # Branco Místico
			"trunk_color": Color(0.8, 0.7, 0.5),        # Dourado Pálido
			"fruit_color": Color(1.0, 0.98, 0.85),       # Sol Branco
			"fruit_glow": Color(1.0, 1.0, 0.8),
			"leaf_shape": "rounded"
		},
		{
			"id": "tori_tori_phoenix",
			"nome": "Árvore Fênix (Tori Tori)",
			"foliage_color": Color(0.0, 0.75, 1.0),       # Cyan Fênix
			"trunk_color": Color(0.3, 0.2, 0.35),       # Madeira Mística
			"fruit_color": Color(0.2, 0.8, 1.0),        # Chamas Azuis
			"fruit_glow": Color(0.4, 0.9, 1.0),
			"leaf_shape": "crystal"
		},
		{
			"id": "buki_buki",
			"nome": "Árvore Arsenal (Buki Buki)",
			"foliage_color": Color(0.62, 0.66, 0.72),     # Aço Escovado
			"trunk_color": Color(0.28, 0.26, 0.24),      # Ferro Escuro
			"fruit_color": Color(0.78, 0.80, 0.85),      # Metal Polido
			"fruit_glow": Color(0.9, 0.93, 1.0),
			"leaf_shape": "crystal"
		}
	]

# Criar Modelo 3D de Árvore Voxel com Cores Personalizadas
static func create_tree_3d(def: Dictionary) -> Node3D:
	var tree_root := Node3D.new()
	tree_root.name = "Tree_" + def["id"]

	# --- 1. TRONCO ---
	var trunk_mesh := BoxMesh.new()
	trunk_mesh.size = Vector3(0.8, 4.0, 0.8)
	var trunk_inst := MeshInstance3D.new()
	trunk_inst.mesh = trunk_mesh
	trunk_inst.position.y = 2.0 # eleva para apoiar na base
	
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = def["trunk_color"]
	trunk_mat.roughness = 0.85
	trunk_inst.material_override = trunk_mat
	tree_root.add_child(trunk_inst)

	# --- 2. FOLHAGEM (CORES E FORM A ÚNICA) ---
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = def["foliage_color"]
	leaf_mat.roughness = 0.6
	
	# Glow sutil na folhagem para destaque visual
	leaf_mat.emission_enabled = true
	leaf_mat.emission = def["foliage_color"] * 0.25

	var foliage_container := Node3D.new()
	foliage_container.position.y = 4.2
	tree_root.add_child(foliage_container)

	# Bloco Central da Copa
	var center_leaf := MeshInstance3D.new()
	var center_box := BoxMesh.new()
	center_box.size = Vector3(2.8, 2.4, 2.8)
	center_leaf.mesh = center_box
	center_leaf.material_override = leaf_mat
	foliage_container.add_child(center_leaf)

	# Blocos Auxiliares para dar volume Voxel à árvore
	var offset_positions := [
		Vector3(1.2, 0.4, 0), Vector3(-1.2, 0.4, 0),
		Vector3(0, 0.4, 1.2), Vector3(0, 0.4, -1.2),
		Vector3(0, 1.4, 0)
	]
	for pos in offset_positions:
		var sub_leaf := MeshInstance3D.new()
		var sub_box := BoxMesh.new()
		sub_box.size = Vector3(1.8, 1.6, 1.8)
		sub_leaf.mesh = sub_box
		sub_leaf.position = pos
		sub_leaf.material_override = leaf_mat
		foliage_container.add_child(sub_leaf)

	# --- 3. FRUTA 3D (AKUMA NO MI) SPAWNADA DEBAIXO DA ÁRVORE ---
	var fruit_3d := create_fruit_3d(def)
	fruit_3d.position = Vector3(0.6, 0.38, 0.6) # Posicionada debaixo da árvore, ao lado do tronco
	tree_root.add_child(fruit_3d)

	return tree_root

# Dicionário estático para rastrear todas as frutas 3D no mapa
static var active_fruits_map: Dictionary = {}

static func register_fruit(fruit_id: String, fruit_node: Node3D) -> void:
	active_fruits_map[fruit_id] = fruit_node

static func respawn_fruit(fruit_id: String) -> void:
	if active_fruits_map.has(fruit_id):
		var node: Node3D = active_fruits_map[fruit_id]
		if node and is_instance_valid(node):
			node.visible = true
			var area := node.find_child("PickupArea", true, false) as Area3D
			if area:
				area.monitoring = true
			print("🍃 A fruta [", fruit_id, "] voltou a existir na sua árvore!")

# Esconde+desativa a fruta na árvore (usado pela sincronização de rede — FruitNet).
static func hide_fruit(fruit_id: String) -> void:
	if active_fruits_map.has(fruit_id):
		var node: Node3D = active_fruits_map[fruit_id]
		if node and is_instance_valid(node):
			node.visible = false
			var area := node.find_child("PickupArea", true, false) as Area3D
			if area:
				area.monitoring = false

static func pickup_fruit(body: Node, fruit_id: String) -> void:
	if not (body.is_in_group("player") or body.has_method("equip_fruit")):
		return

	# SERVIDOR é a autoridade: clientes NÃO coletam sozinhos (o servidor detecta a
	# entrada — posições são replicadas — e reflete em todos via FruitNet).
	if body.multiplayer.has_multiplayer_peer() and not body.multiplayer.is_server():
		return

	var current_equipped: String = body.get("current_fruit_id") if "current_fruit_id" in body else ""

	# Devolve a fruta anterior (em TODOS os clientes) e esconde+equipa a nova (em TODOS).
	if current_equipped != "" and current_equipped != fruit_id:
		_fruit_net(body).respawn(current_equipped)
	var peer_id: int = str(body.name).to_int()   # nome do player = peer id
	_fruit_net(body).pickup(fruit_id, peer_id)
	print("🍎 Fruta [", fruit_id, "] coletada (peer ", peer_id, ")! Refletindo em todos.")

# Criar Modelo 3D da Fruta do Diabo (Akuma no Mi) — ESTRITAMENTE CÚBICO E DETALHADO VOXEL
static func create_fruit_3d(def: Dictionary) -> Node3D:
	var fruit_root := Node3D.new()
	fruit_root.name = "Fruit3D_" + def["id"]

	# --- 1. Corpo Central Cúbico Voxel ---
	var body_inst := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.52, 0.52, 0.52)
	body_inst.mesh = body_box

	var fruit_mat := StandardMaterial3D.new()
	fruit_mat.albedo_color = def["fruit_color"]
	fruit_mat.roughness = 0.3
	fruit_mat.metallic = 0.1
	fruit_mat.emission_enabled = true
	fruit_mat.emission = def["fruit_glow"]
	fruit_mat.emission_energy_multiplier = 0.9
	body_inst.material_override = fruit_mat
	fruit_root.add_child(body_inst)

	# --- 2. Voxels de Canto (Bordas Cúbicas Chanfradas Voxel) ---
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = def["fruit_color"].darkened(0.1)
	edge_mat.roughness = 0.4

	var corner_offsets := [
		Vector3(0.24, 0.24, 0.24), Vector3(-0.24, 0.24, 0.24),
		Vector3(0.24, -0.24, 0.24), Vector3(-0.24, -0.24, 0.24),
		Vector3(0.24, 0.24, -0.24), Vector3(-0.24, 0.24, -0.24),
		Vector3(0.24, -0.24, -0.24), Vector3(-0.24, -0.24, -0.24)
	]
	for off in corner_offsets:
		var corner := MeshInstance3D.new()
		var c_box := BoxMesh.new()
		c_box.size = Vector3(0.16, 0.16, 0.16)
		corner.mesh = c_box
		corner.position = off
		corner.material_override = edge_mat
		fruit_root.add_child(corner)

	# --- 3. Detalhes de Espirais e Voxel Bumps ---
	var spiral_mat := StandardMaterial3D.new()
	spiral_mat.albedo_color = def["fruit_color"].lightened(0.3)
	spiral_mat.roughness = 0.2
	spiral_mat.emission_enabled = true
	spiral_mat.emission = def["fruit_glow"]
	spiral_mat.emission_energy_multiplier = 1.1

	var spiral_offsets := [
		Vector3(0.28, 0.1, 0.2), Vector3(-0.28, 0.1, 0.2),
		Vector3(0.28, -0.1, -0.2), Vector3(-0.28, -0.1, -0.2),
		Vector3(0.0, 0.28, 0.22), Vector3(0.0, -0.28, -0.22),
		Vector3(0.22, 0.0, 0.28), Vector3(-0.22, 0.0, -0.28)
	]
	for off in spiral_offsets:
		var bump := MeshInstance3D.new()
		var bump_box := BoxMesh.new()
		bump_box.size = Vector3(0.12, 0.12, 0.12)
		bump.mesh = bump_box
		bump.position = off
		bump.material_override = spiral_mat
		fruit_root.add_child(bump)

	# --- 4. DETALHES CÚBICOS ESPECÍFICOS POR FRUTA ---
	if def["id"] == "suna_suna":
		# Suna Suna: Anéis de dunas cúbicas de areia dourada
		var sand_mat := StandardMaterial3D.new()
		sand_mat.albedo_color = Color(0.95, 0.82, 0.45)
		sand_mat.roughness = 0.8
		sand_mat.emission_enabled = true
		sand_mat.emission = Color(1.0, 0.8, 0.3)
		sand_mat.emission_energy_multiplier = 1.3
		for i in range(4):
			var dune := MeshInstance3D.new()
			var dune_box := BoxMesh.new()
			dune_box.size = Vector3(0.18, 0.18, 0.18)
			dune.mesh = dune_box
			var angle := i * (PI / 2.0)
			dune.position = Vector3(cos(angle) * 0.34, (i - 1.5) * 0.14, sin(angle) * 0.34)
			dune.material_override = sand_mat
			fruit_root.add_child(dune)
	elif def["id"] == "mera_mera":
		# Mera Mera: Vértices de chamas cúbicas vermelhas/alaranjadas no topo
		var flame_mat := StandardMaterial3D.new()
		flame_mat.albedo_color = Color(1.0, 0.25, 0.0)
		flame_mat.emission_enabled = true
		flame_mat.emission = Color(1.0, 0.5, 0.0)
		flame_mat.emission_energy_multiplier = 2.0
		var f_offsets := [Vector3(0.15, 0.38, 0), Vector3(-0.15, 0.38, 0), Vector3(0, 0.42, 0.15)]
		for fo in f_offsets:
			var flame := MeshInstance3D.new()
			var f_box := BoxMesh.new()
			f_box.size = Vector3(0.12, 0.24, 0.12)
			flame.mesh = f_box
			flame.position = fo
			flame.material_override = flame_mat
			fruit_root.add_child(flame)

	# --- 5. Talo / Haste Cúbica de Madeira e Folha Voxel ---
	var stem_inst := MeshInstance3D.new()
	var stem_box := BoxMesh.new()
	stem_box.size = Vector3(0.08, 0.34, 0.08)
	stem_inst.mesh = stem_box
	stem_inst.position = Vector3(0, 0.44, 0)
	stem_inst.rotation_degrees = Vector3(15, 0, 20)

	var stem_mat := StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.18, 0.55, 0.18) # Verde talo
	stem_inst.material_override = stem_mat
	fruit_root.add_child(stem_inst)

	# Folha Cúbica Voxel no Talo
	var leaf_inst := MeshInstance3D.new()
	var leaf_box := BoxMesh.new()
	leaf_box.size = Vector3(0.24, 0.04, 0.14)
	leaf_inst.mesh = leaf_box
	leaf_inst.position = Vector3(0.1, 0.54, 0.04)
	leaf_inst.rotation_degrees = Vector3(0, 30, -15)
	leaf_inst.material_override = stem_mat
	fruit_root.add_child(leaf_inst)

	# --- 6. Area3D de Detecção de Toque do Jogador (Debaixo da Árvore) ---
	var area := Area3D.new()
	area.name = "PickupArea"
	var col := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 1.6 # Raio de toque do jogador
	col.shape = sphere_shape
	area.add_child(col)
	fruit_root.add_child(area)

	var fruit_id: String = def["id"]
	area.body_entered.connect(func(b): pickup_fruit(b, fruit_id))

	# Registra fruta no gerenciador estático
	register_fruit(fruit_id, fruit_root)

	# --- Animação Suave de Rotação Flutuante Cúbica ---
	var anim_script := GDScript.new()
	anim_script.source_code = "extends Node3D\nfunc _process(delta):\n\trotate_y(1.2 * delta)\n"
	anim_script.reload()
	fruit_root.set_script(anim_script)

	return fruit_root

# O autoload pego por CAMINHO, não por identificador.
#
# `FruitNet.x` escrito direto faz esta classe inteira falhar ao compilar em
# script `godot -s` ("Identifier not found: FruitNet"), porque ali os autoloads
# existem na árvore mas não viram identificador de compilação. O efeito é
# traiçoeiro: a classe some das ferramentas e devolve lista vazia sem avisar —
# foi assim que a auditoria de frutas reportou "0 árvores no mapa" e marcou as 9
# frutas como impossíveis de obter (ver docs/erros.md, 2026-08-10).
static func _fruit_net(ctx: Node) -> Node:
	if ctx and ctx.is_inside_tree():
		var n := ctx.get_node_or_null("/root/FruitNet")
		if n:
			return n
	return _FruitNetMudo.new()

# Dublê para quando não há autoload (ferramentas headless): engole a chamada em
# vez de derrubar quem está medindo.
class _FruitNetMudo extends Node:
	func pickup(_fruit_id: String, _peer_id: int) -> void: pass
	func respawn(_fruit_id: String) -> void: pass
