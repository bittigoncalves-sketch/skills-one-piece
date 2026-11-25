extends SceneTree
## Fonte editável. Apenas Godot: voxels, faces expostas e cores por vértice.
## --headless --path . --script tools/gerar_buda_voxel.gd
const PASSO := 0.035
const DESTINO := "res://assets/models/buda/buda_voxel.tscn"
var voxels: Dictionary = {}

func _init() -> void:
	gerar()
	quit()

func gerar() -> void:
	# Corpo de oito gomos; topo levemente afundado e base achatada.
	for y in range(-12, 13):
		for x in range(-15, 16):
			for z in range(-15, 16):
				var altura := float(y) / 12.0
				var angulo := atan2(float(z), float(x))
				var raio := 13.0 * sqrt(maxf(0.0, 1.0 - altura * altura))
				raio *= 0.93 + 0.07 * cos(8.0 * angulo)
				if Vector2(x, z).length() <= raio and not (y > 9 and Vector2(x, z).length() < 3.0):
					var luz := clampf((float(y) + 12.0) / 24.0, 0.0, 1.0)
					var cor := Color("c98012").lerp(Color("ffdb64"), luz)
					if cos(8.0 * angulo) < -0.6:
						cor = cor.darkened(0.12)
					voxels[Vector3i(x, y, z)] = cor
	# Espirais quadradas em relevo, distribuídas ao redor de todos os gomos.
	var espiral := [Vector2i(-2,-3), Vector2i(3,-3), Vector2i(3,3), Vector2i(-3,3), Vector2i(-3,-1), Vector2i(1,-1), Vector2i(1,1), Vector2i(-1,1)]
	for gomo in 8:
		var a := TAU * float(gomo) / 8.0
		for i in range(espiral.size() - 1):
			var inicio: Vector2i = espiral[i]
			var fim: Vector2i = espiral[i + 1]
			var passos := maxi(absi(fim.x - inicio.x), absi(fim.y - inicio.y))
			for j in range(passos + 1):
				var uv := Vector2(inicio).lerp(Vector2(fim), float(j) / passos)
				var angulo := a + uv.x / 13.0
				var y := int(uv.y) + (1 if gomo % 2 == 0 else -2)
				var raio := 13.0 * sqrt(1.0 - pow(float(y) / 12.0, 2.0)) * (0.93 + 0.07 * cos(8.0 * angulo))
				for profundidade in [0.0, 0.7]:
					var p := Vector3i(roundi(cos(angulo) * (raio + profundidade)), y, roundi(sin(angulo) * (raio + profundidade)))
					voxels[p] = Color("a8660e")
	# Talo de jade: curva em degraus, presa ao centro do fruto.
	var talo := [Vector2i(0,10), Vector2i(0,15), Vector2i(2,18), Vector2i(5,18), Vector2i(7,16), Vector2i(7,14), Vector2i(5,14)]
	for i in range(talo.size() - 1):
		var inicio: Vector2i = talo[i]
		var fim: Vector2i = talo[i + 1]
		var passos := maxi(absi(fim.x - inicio.x), absi(fim.y - inicio.y))
		for j in range(passos + 1):
			var p := Vector2(inicio).lerp(Vector2(fim), float(j) / passos)
			for dx in range(-1, 1):
				for dz in range(-1, 1):
					voxels[Vector3i(roundi(p.x) + dx, roundi(p.y), dz)] = Color("35654b") if dz == 0 else Color("52855b")
	# Folha lanceolada, larga na base e afilada na ponta; nervura clara.
	for x in range(-10, 1):
		var largura := roundi(2.5 * sin(PI * float(-x) / 11.0))
		for z in range(-largura, largura + 1):
			for dy in [-1, 0]:
				voxels[Vector3i(x, 13 + int(-x / 3.0) + dy, z)] = Color("9bab51") if z == 0 and dy == 0 else Color("487a45")
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normais := [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0), Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
	for p: Vector3i in voxels:
		for n: Vector3i in normais:
			if voxels.has(p + n):
				continue
			var normal := Vector3(n)
			var u := Vector3.UP if n.y == 0 else Vector3.RIGHT
			var v := normal.cross(u)
			var centro := (Vector3(p) + normal * 0.5) * PASSO
			var cantos := [centro + (-u-v)*PASSO*0.5, centro + (u-v)*PASSO*0.5, centro + (u+v)*PASSO*0.5, centro + (-u+v)*PASSO*0.5]
			for indice in [0,2,1,0,3,2]:
				superficie.set_normal(normal)
				superficie.set_color(voxels[p])
				superficie.add_vertex(cantos[indice])
	superficie.index()
	var malha := superficie.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.72
	malha.surface_set_material(0, material)
	var modelo := Node3D.new()
	modelo.name = "BudaVoxel"
	var visual := MeshInstance3D.new()
	visual.name = "FrutaDourada"
	visual.mesh = malha
	modelo.add_child(visual)
	visual.owner = modelo
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DESTINO.get_base_dir()))
	var cena := PackedScene.new()
	assert(cena.pack(modelo) == OK)
	assert(ResourceSaver.save(cena, DESTINO) == OK)
	print("BUDA_VOXEL: ", voxels.size(), " voxels; ", malha.surface_get_array_index_len(0) / 3, " triângulos; ", malha.get_aabb())
	modelo.free()
