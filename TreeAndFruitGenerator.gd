class_name TreeAndFruitGenerator
extends Node

# ============================================================================
#  Gerador de 11 Árvores Místicas com Cores Únicas e Frutas 3D (Akuma no Mi)
#  As árvores são posicionadas sobre os cubos (obstáculos) da plataforma.
# ============================================================================

# Árvores que o mapa REALMENTE planta.
#
# ⚠️ Só entram as frutas que têm poderes no `SkillSystem`. Antes o mapa plantava
# as 11 definições abaixo, e algumas (`hito_hito_nika`,
# `tori_tori_phoenix`) davam frutas sem skill nenhuma — pegar uma delas virava
# Gomu Gomu **em silêncio**, por causa do fallback no `Player._fire_skill`. Era
# impossível perceber jogando: a fruta entrava no inventário com o nome certo e
# os golpes saíam errados.
#
# Filtrar aqui, e não remover as definições, é de propósito: a arte da árvore
# (cores, formato da copa) já está autorada e serve na hora que a fruta ganhar
# poderes. A Ope Ope agora tem kit próprio e volta ao mapa pelo mesmo filtro.
static func get_tree_definitions() -> Array[Dictionary]:
	var com_poder := SkillSystem.get_fruit_skills()
	var out: Array[Dictionary] = []
	var fora: Array[String] = []
	for d in _todas_as_definicoes():
		if com_poder.has(str(d.get("id", ""))) or str(d.get("id", "")) == "sem_fruta":
			out.append(d)
		else:
			fora.append(str(d.get("id", "")))
	if not fora.is_empty():
		print("🌳 [Árvores] fora do mapa por não terem skills: ", ", ".join(fora))
	return out

# Frutas do Mine Piece (18/10/2026, pedido do dono: "adicionar as frutas e árvores novas
# para as frutas que foram adicionadas através do mine piece"). São frutas do Skills
# Builder (`mapas/skills/frutas.json`), por isso ficam fora do filtro do `SkillSystem`; o
# `TreeScatter` as planta ALÉM das `TREE_COUNT` de sempre, sem mexer no mapa da arena.
static func get_tree_definitions_mine_piece() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in _DEFINICOES_MINE_PIECE:
		if KitDoBuilder.e_do_builder(str(d["id"])):
			out.append(d)
	return out

const _DEFINICOES_MINE_PIECE: Array[Dictionary] = [
	{
		"id": "pika_pika_no_mi_mine_piece", "nome": "Árvore da Luz (Pika Pika, Mine Piece)",
		"foliage_color": Color(1.0, 0.84, 0.32),     # Dourado de luz
		"trunk_color": Color(0.36, 0.28, 0.16),
		"fruit_color": Color(1.0, 0.93, 0.38),
		"fruit_glow": Color(1.0, 1.0, 0.62), "leaf_shape": "rounded"
	},
	{
		"id": "hie_hie_no_mi_mine_piece", "nome": "Árvore do Gelo (Hie Hie, Mine Piece)",
		"foliage_color": Color(0.82, 0.95, 1.0),     # Branco de geada
		"trunk_color": Color(0.55, 0.66, 0.76),
		"fruit_color": Color(0.55, 0.86, 1.0),
		"fruit_glow": Color(0.72, 0.96, 1.0), "leaf_shape": "crystal"
	},
	{
		"id": "moku_moku_no_mi_mine_piece", "nome": "Árvore da Fumaça (Moku Moku, Mine Piece)",
		"foliage_color": Color(0.8, 0.8, 0.84),      # Fumaça branca
		"trunk_color": Color(0.4, 0.38, 0.36),
		"fruit_color": Color(0.93, 0.93, 0.96),
		"fruit_glow": Color(0.78, 0.8, 0.86), "leaf_shape": "canopy"
	},
	{
		"id": "nikyu_nikyu_no_mi_mine_piece", "nome": "Árvore da Pata (Nikyu Nikyu, Mine Piece)",
		"foliage_color": Color(0.46, 0.3, 0.36),     # Ameixa escura
		"trunk_color": Color(0.25, 0.18, 0.15),
		"fruit_color": Color(0.56, 0.26, 0.42),
		"fruit_glow": Color(0.92, 0.52, 0.76), "leaf_shape": "split"
	},
]

# O catálogo completo, inclusive o que ainda não é plantável. Não apague nada
# daqui — é o inventário do que existe desenhado.
static func _todas_as_definicoes() -> Array[Dictionary]:
	return [
		{
			"id": "rocket", "nome": "Rocket Fruit",
			"foliage_color": Color(0.55, 0.22, 0.06),
			"trunk_color": Color(0.19, 0.16, 0.14),
			"fruit_color": Color(0.25, 0.28, 0.32),
			"fruit_glow": Color(1.0, 0.35, 0.03), "leaf_shape": "split"
		},
		{
			"id": "sem_fruta",
			"nome": "Fruta da Normalidade (Sem Fruta)",
			"foliage_color": Color(0.3, 0.3, 0.3),
			"trunk_color": Color(0.5, 0.5, 0.5),
			"fruit_color": Color(0.8, 0.8, 0.8),
			"fruit_glow": Color(0.1, 0.1, 0.1),
			"leaf_shape": "canopy"
		},
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
			"id": "bomu_bomu",
			"nome": "Árvore da Explosão (Bomu Bomu)",
			"foliage_color": Color(0.14, 0.10, 0.22),
			"trunk_color": Color(0.30, 0.18, 0.10),
			"fruit_color": Color(0.10, 0.08, 0.26),
			"fruit_glow": Color(1.0, 0.52, 0.12),
			"leaf_shape": "split"
		},
		{
			"id": "suke_suke",
			"nome": "Árvore da Camuflagem (Suke Suke)",
			"foliage_color": Color(0.38, 0.76, 0.82),
			"trunk_color": Color(0.18, 0.38, 0.42),
			"fruit_color": Color(0.52, 0.84, 0.86),
			"fruit_glow": Color(0.72, 1.0, 1.0),
			"leaf_shape": "crystal"
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
			# A Gura Gura tinha os 4 golpes prontos e passiva, e NENHUMA árvore —
			# ou seja, era impossível de obter jogando. Achado pela auditoria de
			# 2026-08-10 (docs/AUDITORIA_FRUTAS.md). Paleta de terremoto: rachadura
			# e ar deslocado.
			"id": "gura_gura",
			"nome": "Árvore do Abalo (Gura Gura)",
			"foliage_color": Color(0.35, 0.55, 0.75),     # Azul Tempestade
			"trunk_color": Color(0.30, 0.28, 0.30),       # Rocha Rachada
			"fruit_color": Color(0.55, 0.70, 0.90),       # Cristal de Choque
			"fruit_glow": Color(0.70, 0.85, 1.0),
			"leaf_shape": "split"
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

# ============================================================================
#  A ÁRVORE (2026-11-04) — seis formas voxel geradas por `ArvoreVoxel`
#
#  Formas: carvalho, pinheiro, palmeira, acácia, baobá e salgueiro. Cada fruta
#  recebe UMA forma fixa (pela ordem em `_todas_as_definicoes`, mod 6), então
#  a mesma fruta é sempre a mesma árvore — forma + cor ajudam a achá-la.
#
#  ⚠️ AS CORES POR FRUTA CONTINUAM VALENDO: `trunk_color` pinta a superfície 0
#  (tronco) e `foliage_color` a superfície 1 (copa), pelo funil `Materiais`.
#  O `arvore_voxel.glb` antigo segue em assets/ (testes de loja/inimigo o usam),
#  mas o mapa não o carrega mais.
# ============================================================================
static var _forma_por_id: Dictionary = {}

static func forma_da_arvore(id: String) -> String:
	if _forma_por_id.is_empty():
		var i := 0
		for d in _todas_as_definicoes() + _DEFINICOES_MINE_PIECE:
			_forma_por_id[str(d["id"])] = ArvoreVoxel.FORMAS[i % ArvoreVoxel.FORMAS.size()]
			i += 1
	return _forma_por_id.get(id, ArvoreVoxel.FORMAS[0])

static func create_tree_3d(def: Dictionary) -> Node3D:
	var tree_root := Node3D.new()
	tree_root.name = "Tree_" + def["id"]

	var forma := forma_da_arvore(str(def["id"]))
	var mi := MeshInstance3D.new()
	mi.name = "Modelo"
	mi.mesh = ArvoreVoxel.malha(forma)
	var cores := {"tronco": def["trunk_color"], "copa": def["foliage_color"],
		"copa_clara": (def["foliage_color"] as Color).lightened(0.14),
		"corte": def["trunk_color"], "coco_verde": Color("7ac143"), "coco_seco": Color("4a2f1a")}
	for i in mi.mesh.get_surface_count():
		mi.set_surface_override_material(i, Materiais.superficie(cores[mi.mesh.surface_get_name(i)]))
	tree_root.add_child(mi)

	# --- FRUTA 3D (AKUMA NO MI), ao lado do tronco ---
	var fruit_3d := create_fruit_3d(def)
	fruit_3d.position = ArvoreVoxel.posicao_da_fruta(forma)
	tree_root.add_child(fruit_3d)

	return tree_root

# Dicionário estático para rastrear todas as frutas 3D no mapa
static var active_fruits_map: Dictionary = {}

static func register_fruit(fruit_id: String, fruit_node: Node3D) -> void:
	active_fruits_map[fruit_id] = fruit_node

static func respawn_fruit(fruit_id: String) -> void:
	if active_fruits_map.has(fruit_id):
		# ⚠️ SEM TIPO até conferir: o mapa é estático e sobrevive à troca de cena. Saindo
		# da arena para o Modo História, a árvore já foi liberada, e ATRIBUIR a instância
		# morta a uma variável `Node3D` dá erro antes do `is_instance_valid` (log de 16/09/2026).
		var guardado: Variant = active_fruits_map[fruit_id]
		if not is_instance_valid(guardado):
			active_fruits_map.erase(fruit_id)
			return
		var node := guardado as Node3D
		if node:
			node.visible = true
			var area := node.find_child("PickupArea", true, false) as Area3D
			if area:
				area.monitoring = true
			print("🍃 A fruta [", fruit_id, "] voltou a existir na sua árvore!")

# Esconde+desativa a fruta na árvore (usado pela sincronização de rede — FruitNet).
static func hide_fruit(fruit_id: String) -> void:
	if active_fruits_map.has(fruit_id):
		# ⚠️ SEM TIPO até conferir: o mapa é estático e sobrevive à troca de cena. Saindo
		# da arena para o Modo História, a árvore já foi liberada, e ATRIBUIR a instância
		# morta a uma variável `Node3D` dá erro antes do `is_instance_valid` (log de 16/09/2026).
		var guardado: Variant = active_fruits_map[fruit_id]
		if not is_instance_valid(guardado):
			active_fruits_map.erase(fruit_id)
			return
		var node := guardado as Node3D
		if node:
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
## Frutas com MODELO AUTORAL trazem o proprio nó de coleta; as demais caem no
## corpo voxel montado logo abaixo. Virou tabela na terceira entrada (Goro, em
## 2026-09-12): três `if` iguais empilhados já eram o sinal de que a próxima
## fruta autoral ia copiar o bloco de novo.
const PICKUPS_AUTORAIS := {
	"hito_hito_daibutsu": "res://src/world/BudaFruitPickup.gd",
	"bara_bara": "res://src/world/BaraFruitPickup.gd",
	"ope_ope": "res://src/world/OpeFruitPickup.gd",
	"gomu_gomu": "res://src/world/GomuFruitPickup.gd",
	"goro_goro": "res://src/world/GoroFruitPickup.gd",
}

## Qual modelo voxel vale para este id: variantes (`*_no_mi_mine_piece`, `*_mine_piece`, `_gear2`) e Hito Hito Nika
## (= Gomu Gomu) usam o modelo da fruta base. Ver art_src/akuma_no_mi/LEIA-ME.md.
const _ALIAS_DE_MODELO := {"hito_hito_nika": "gomu_gomu"}


static func id_do_modelo(id: String) -> String:
	if _ALIAS_DE_MODELO.has(id):
		return _ALIAS_DE_MODELO[id]
	for sufixo in ["_no_mi_mine_piece", "_mine_piece", "_gear2"]:
		if id.ends_with(sufixo):
			return id.trim_suffix(sufixo)
	return id


static func create_fruit_3d(def: Dictionary) -> Node3D:
	var fid := str(def.get("id", ""))
	if PICKUPS_AUTORAIS.has(fid):
		var script := load(PICKUPS_AUTORAIS[fid]) as GDScript
		if script != null:
			var autoral: Node3D = script.new()
			autoral.name = "Fruit3D_" + fid
			register_fruit(fid, autoral)
			return autoral
		push_error("Fruta autoral sem script: " + str(PICKUPS_AUTORAIS[fid]))
	var fruit_root := Node3D.new()
	fruit_root.name = "Fruit3D_" + def["id"]
	# Modelo voxel próprio da Akuma no Mi (Blender, tools/akuma_no_mi/gerar_frutas.py): substitui o corpo cúbico genérico.
	var glb := "res://assets/models/akuma_no_mi/%s.glb" % id_do_modelo(fid)
	if ResourceLoader.exists(glb):
		var cena := load(glb) as PackedScene
		if cena != null:
			var modelo := cena.instantiate() as Node3D
			modelo.name = "Modelo"
			fruit_root.add_child(modelo)
			return _finalizar_pickup(fruit_root, fid)

	# --- 1. Corpo Central Cúbico Voxel ---
	var body_inst := MeshInstance3D.new()
	if def["id"] == "bomu_bomu":
		var body_sphere := SphereMesh.new()
		body_sphere.radius = 0.42
		body_sphere.height = 0.78
		body_inst.mesh = body_sphere
	else:
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
		if def["id"] == "bomu_bomu":
			continue
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
		if def["id"] == "bomu_bomu":
			continue
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
	elif def["id"] == "bomu_bomu":
		# Casca azul-marinho com espirais coral e pavio amarelo, inspirado na
		# referência. Todo detalhe é voxel/procedural, sem depender de textura.
		var fuse_mat := StandardMaterial3D.new()
		fuse_mat.albedo_color = Color(1.0, 0.72, 0.12)
		fuse_mat.emission_enabled = true; fuse_mat.emission = Color(1.0, 0.48, 0.06)
		fuse_mat.emission_energy_multiplier = 1.7
		for i in range(4):
			var fuse := MeshInstance3D.new()
			var fuse_box := BoxMesh.new(); fuse_box.size = Vector3(0.10, 0.18, 0.10)
			fuse.mesh = fuse_box
			fuse.position = Vector3(sin(i * 0.65) * 0.12, 0.46 + i * 0.13, 0.0)
			fuse.rotation.z = -0.42 + i * 0.22
			fuse.material_override = fuse_mat
			fruit_root.add_child(fuse)
		var spark := MeshInstance3D.new()
		var spark_mesh := SphereMesh.new(); spark_mesh.radius = 0.12; spark_mesh.height = 0.24
		spark.mesh = spark_mesh; spark.position = Vector3(0.18, 0.98, 0.0)
		spark.material_override = fuse_mat
		fruit_root.add_child(spark)
		# Espirais coral elevadas acompanham a casca arredondada, em vez de cubos.
		var swirl_mat := StandardMaterial3D.new()
		swirl_mat.albedo_color = Color(0.92, 0.28, 0.42)
		for i in range(7):
			var swirl := MeshInstance3D.new()
			var torus := TorusMesh.new(); torus.inner_radius = 0.055; torus.outer_radius = 0.082
			swirl.mesh = torus
			var a := TAU * float(i) / 7.0
			swirl.position = Vector3(cos(a) * 0.34, -0.22 + float(i % 3) * 0.20, sin(a) * 0.34)
			swirl.rotation = Vector3(PI * 0.5, 0.0, -a)
			swirl.material_override = swirl_mat
			fruit_root.add_child(swirl)

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

	return _finalizar_pickup(fruit_root, str(def["id"]))


## Área de toque + registro + giro: o que todo pickup de fruta tem, com o corpo cúbico genérico ou com o modelo próprio.
static func _finalizar_pickup(fruit_root: Node3D, fruit_id: String) -> Node3D:
	var area := Area3D.new()
	area.name = "PickupArea"
	var col := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 1.6 # Raio de toque do jogador
	col.shape = sphere_shape
	area.add_child(col)
	fruit_root.add_child(area)
	area.body_entered.connect(func(b): pickup_fruit(b, fruit_id))
	register_fruit(fruit_id, fruit_root)
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
