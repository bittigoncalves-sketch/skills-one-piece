extends SceneTree
# ============================================================================
#  COLISÃO DAS CONSTRUÇÕES em partes convexas (01/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/gerar_colisao_de_construcoes.gd [-- id ...]
#
#  Decisão do dono: a hitbox das casas tem que ENVOLVER a própria estrutura e se
#  adaptar a ela; vale para as construções (casas, torres, templos, mercado, fazendas,
#  prédios do porto). Para cada uma, decompõe a malha visual em até MAX_PARTES volumes
#  convexos (V-HACD do Godot), grava `mapas/modelos/<id>.colisao.json` e marca
#  "colisao": "partes" no catálogo (`BibliotecaDeModelos`). Rodar de novo refaz.
#
#  Por que convexo e não a malha: a trimesh do modelo tem arestas soltas (degrau de
#  base, travessa, beiral) em que corpo nenhum desliza, e frestas por onde se entra na
#  parede; partes convexas fecham a estrutura e o jogador escorrega pela parede.
#  Por que offline: ~0,2–1 s por modelo — lento demais para abrir o mapa.
#
#  Mede a COBERTURA: fração dos pontos da superfície do modelo que ficam dentro (ou a
#  até 5 cm) de alguma parte. Baixa = parte da estrutura sem colisão.
# ============================================================================

const MAX_PARTES := 12
## Construções = os kits de prédio da tabela de tamanhos, menos o que é chão ou piso.
const NAO_CONSTRUCAO := ["crops", "farm_dirt", "farm-o4wptlsfin", "sawmill", "docks", "dock_2",
	"dock-xvikobh2un"]
const MAIS := ["well", "gazebo"]

var _espaco: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var fatores: Dictionary = (load("res://tools/mapa_ilha/aplicar_tamanhos_padrao.gd") as Script).get_script_constant_map()["FATORES"]
	var ids: Array = OS.get_cmdline_user_args()
	if ids.is_empty():
		for id in fatores:
			if not NAO_CONSTRUCAO.has(id):
				ids.append(id)
		ids.append_array(MAIS)
	var mundo := Node3D.new()
	root.add_child(mundo)
	_espaco = mundo.get_world_3d().direct_space_state
	var feitos := 0
	var pior := 1.0
	var t0 := Time.get_ticks_msec()
	for id in ids:
		if not bib.tem(id):
			push_error("fora da loja: " + id)
			continue
		var cena := bib.instanciar(id)
		var m := BibliotecaDeModelos.medir(cena)
		cena.free()
		if not (m["faces_colisao"] as PackedVector3Array).is_empty():
			print("PULADO %-30s tem malha \"Colisao\" própria" % id)
			continue
		var faces: PackedVector3Array = m["faces"]
		var partes := _decompor(faces)
		if partes.is_empty():
			push_error("decomposição vazia: " + id)
			continue
		bib.definir_partes_de_colisao(id, partes)
		var cobertura := await _cobertura(mundo, faces, partes)
		pior = minf(pior, cobertura)
		feitos += 1
		print("PARTES %-30s %2d volumes, %3d pontos, cobertura %5.1f %%" % [id, partes.size(), _soma_pontos(partes), cobertura * 100.0])
	print("COLISAO_CONSTRUCOES feitos=%d pior_cobertura=%.1f%% ms=%d" % [feitos, pior * 100.0, Time.get_ticks_msec() - t0])
	mundo.free()
	quit()


func _decompor(faces: PackedVector3Array) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in faces:
		st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	root.add_child(mi)
	var cfg := MeshConvexDecompositionSettings.new()
	cfg.max_convex_hulls = MAX_PARTES
	cfg.resolution = 100000
	cfg.max_num_vertices_per_convex_hull = 32
	cfg.max_concavity = 0.0025
	mi.create_multiple_convex_collisions(cfg)
	var partes: Array = []
	for cs in mi.find_children("*", "CollisionShape3D", true, false):
		var forma := (cs as CollisionShape3D).shape as ConvexPolygonShape3D
		if forma != null and forma.points.size() >= 4:
			partes.append(forma.points)
	mi.free()
	return partes


## Fração dos centros de triângulo (puxados 2 cm para dentro) que caem em alguma parte
## ou a até 5 cm dela.
func _cobertura(mundo: Node3D, faces: PackedVector3Array, partes: Array) -> float:
	var corpo := StaticBody3D.new()
	mundo.add_child(corpo)
	for pts in partes:
		var cs := CollisionShape3D.new()
		var forma := ConvexPolygonShape3D.new()
		forma.points = pts
		cs.shape = forma
		corpo.add_child(cs)
	await physics_frame
	await physics_frame
	var dentro := 0
	var total := 0
	var passo := maxi(1, faces.size() / 3 / 600)       # até ~600 amostras por modelo
	var esfera := SphereShape3D.new()
	esfera.radius = 0.05
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = esfera
	for k in range(0, faces.size() / 3, passo):
		var a := faces[k * 3]
		var b := faces[k * 3 + 1]
		var c := faces[k * 3 + 2]
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-12:
			continue
		var centro := (a + b + c) / 3.0 - n.normalized() * 0.02
		q.transform = Transform3D(Basis.IDENTITY, centro)
		total += 1
		if not _espaco.intersect_shape(q, 1).is_empty():
			dentro += 1
	corpo.free()
	return float(dentro) / maxf(total, 1)


static func _soma_pontos(partes: Array) -> int:
	var n := 0
	for pts in partes:
		n += (pts as PackedVector3Array).size()
	return n
