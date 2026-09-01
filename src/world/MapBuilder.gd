class_name MapBuilder
extends RefCounted
# Mapa base FIXO = plataforma cinza EM GRADE (com buracos quadrados) + blocos cinza.
#
# A plataforma deixou de ser uma peça só: agora é uma grade de LAJES de CELL metros.
# Células marcadas como buraco simplesmente não existem — nem malha, nem colisão —
# então quem cai atravessa e some no vazio (a morte por queda mora no Player).
#
# Custo: as lajes vizinhas são fundidas em CORRIDAS horizontais (greedy) antes de
# virar geometria. Um mapa de 400 células vira ~40 corridas => ~40 shapes de colisão
# e 1 MultiMesh (1 draw call), em vez de 400 nós. O visual é idêntico ao de antes
# nas partes sólidas.

const PLATFORM_SIZE := 200.0   # lado da plataforma
const PLATFORM_THICK := 2.0
const OBSTACLE_COUNT := 90     # blocos cinza espalhados
const WORLD_SEED := 20260725   # semente fixa => mapa sempre igual

# ---- grade e buracos ----
const CELL := 10.0                       # lado da laje (= lado do buraco pequeno)
const GRID := int(PLATFORM_SIZE / CELL)  # 20 x 20 células
const HOLE_SEED := 20260810              # semente fixa dos buracos
const HOLES_SMALL := 12                  # buracos de 1x1 célula (10 x 10 m)
const HOLES_BIG := 4                     # buracos de 2x2 células (20 x 20 m)
const SAFE_RADIUS := 16.0                # nenhum buraco perto do spawn central
const BORDER_CELLS := 1                  # anel externo sempre sólido

# Preenchido por _pick_holes na primeira chamada; é determinístico pela semente,
# então serve de consulta para qualquer sistema (spawn, respawn, dummy, blocos).
static var _holes: Dictionary = {}

# ---------------------------------------------------------------- construção
static func build(parent: Node) -> Array:
	_pick_holes()
	_platform(parent)
	return _blocks(parent)

# ------------------------------------------------------------ consulta pública
# true se o ponto (x, z) do mundo está sobre um buraco (ou fora da plataforma).
static func is_hole(x: float, z: float) -> bool:
	_pick_holes()
	var gx := int(floor((x + PLATFORM_SIZE * 0.5) / CELL))
	var gz := int(floor((z + PLATFORM_SIZE * 0.5) / CELL))
	if gx < 0 or gz < 0 or gx >= GRID or gz >= GRID:
		return true
	return _holes.has(Vector2i(gx, gz))

# Versão com margem: true se QUALQUER canto de um retângulo w x d centrado em
# (x, z) cai num buraco. Usada para não pousar blocos/árvores na beirada.
static func is_hole_area(x: float, z: float, w: float, d: float) -> bool:
	var hw := w * 0.5
	var hd := d * 0.5
	for sx in [-hw, 0.0, hw]:
		for sz in [-hd, 0.0, hd]:
			if is_hole(x + sx, z + sz):
				return true
	return false

# ------------------------------------------------------------------ buracos
static func _pick_holes() -> void:
	if not _holes.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = HOLE_SEED

	# Os 2x2 vêm primeiro: são os mais difíceis de encaixar sem sobrepor.
	_place_holes(rng, HOLES_BIG, 2)
	_place_holes(rng, HOLES_SMALL, 1)

static func _place_holes(rng: RandomNumberGenerator, count: int, size: int) -> void:
	var lo := BORDER_CELLS
	var hi := GRID - BORDER_CELLS - size          # último índice que ainda cabe
	var placed := 0
	var tries := 0
	while placed < count and tries < 400:
		tries += 1
		var gx := rng.randi_range(lo, hi)
		var gz := rng.randi_range(lo, hi)
		if _fits(gx, gz, size):
			for dx in size:
				for dz in size:
					_holes[Vector2i(gx + dx, gz + dz)] = true
			placed += 1

# Cabe se nenhuma célula do bloco (nem a moldura de 1 célula ao redor) já é
# buraco — a moldura evita dois buracos colados virarem um rasgo enorme — e se
# está longe do spawn central.
static func _fits(gx: int, gz: int, size: int) -> bool:
	for dx in range(-1, size + 1):
		for dz in range(-1, size + 1):
			if _holes.has(Vector2i(gx + dx, gz + dz)):
				return false
	for dx in size:
		for dz in size:
			if _cell_center(gx + dx, gz + dz).length() < SAFE_RADIUS:
				return false
	return true

static func _cell_center(gx: int, gz: int) -> Vector2:
	var half := PLATFORM_SIZE * 0.5
	return Vector2((gx + 0.5) * CELL - half, (gz + 0.5) * CELL - half)

# ----------------------------------------------------------------- plataforma
static func _platform(parent: Node) -> void:
	var body := StaticBody3D.new()
	body.name = "Plataforma"
	body.position = Vector3(0, -PLATFORM_THICK * 0.5, 0)  # topo em y=0

	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit

	var runs := _merge_runs()
	mm.instance_count = runs.size()

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Lajes"
	mmi.multimesh = mm
	# ⚠️ O CHÃO É O ÚNICO COM GRADE (Fase 4). Ele é a maior superfície da tela e
	# era a que menos dizia; a grade dá escala e mostra onde as células — e
	# portanto os buracos — começam e terminam. Um pouco mais escuro que antes
	# (era 0,52) para parar de dominar a imagem.
	mmi.material_override = Materiais.chao(Color(0.46, 0.46, 0.46), CELL)
	body.add_child(mmi)

	var half := PLATFORM_SIZE * 0.5
	for i in runs.size():
		var r: Dictionary = runs[i]
		var w: float = float(r["len"]) * CELL
		var cx: float = float(r["gx"]) * CELL + w * 0.5 - half
		var cz: float = (float(r["gz"]) + 0.5) * CELL - half
		var origin := Vector3(cx, 0.0, cz)

		# Malha: instância da caixa unitária escalada até o tamanho da corrida.
		mm.set_instance_transform(i, Transform3D(
			Basis.IDENTITY.scaled(Vector3(w, PLATFORM_THICK, CELL)), origin))

		# Colisão: uma caixa por corrida (shape próprio — cada corrida tem largura
		# diferente, então não dá pra compartilhar o recurso).
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(w, PLATFORM_THICK, CELL)
		col.shape = shape
		col.position = origin
		body.add_child(col)
	_bordas_visuais_dos_buracos(body)

	parent.add_child(body)

# Uma faixa escura no lado SEGURO de cada buraco. Não recebe colisão nem nó por
# borda: todas as tiras compartilham uma MultiMesh, então o aviso de abismo tem
# custo de um draw call em vez de dezenas. A grade ainda comunica a célula; a
# faixa comunica o perigo quando ela aparece pequena na tela.
static func _bordas_visuais_dos_buracos(body: Node3D) -> void:
	var tiras: Array[Transform3D] = []
	var lados := [
		{"passo": Vector2i(0, -1), "desloc": Vector3(0, 0.03, -CELL * 0.5 - 0.14), "escala": Vector3(CELL, 0.045, 0.28)},
		{"passo": Vector2i(0, 1),  "desloc": Vector3(0, 0.03, CELL * 0.5 + 0.14),  "escala": Vector3(CELL, 0.045, 0.28)},
		{"passo": Vector2i(-1, 0), "desloc": Vector3(-CELL * 0.5 - 0.14, 0.03, 0), "escala": Vector3(0.28, 0.045, CELL)},
		{"passo": Vector2i(1, 0),  "desloc": Vector3(CELL * 0.5 + 0.14, 0.03, 0),  "escala": Vector3(0.28, 0.045, CELL)},
	]
	for celula in _holes.keys():
		var c := celula as Vector2i
		var centro2 := _cell_center(c.x, c.y)
		for lado in lados:
			var vizinho: Vector2i = c + (lado["passo"] as Vector2i)
			if vizinho.x < 0 or vizinho.y < 0 or vizinho.x >= GRID or vizinho.y >= GRID or _holes.has(vizinho):
				continue
			var origem := Vector3(centro2.x, 0, centro2.y) + (lado["desloc"] as Vector3)
			tiras.append(Transform3D(Basis.IDENTITY.scaled(lado["escala"] as Vector3), origem))
	if tiras.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var unidade := BoxMesh.new()
	unidade.size = Vector3.ONE
	mm.mesh = unidade
	mm.instance_count = tiras.size()
	for i in tiras.size():
		mm.set_instance_transform(i, tiras[i])
	var faixa := MultiMeshInstance3D.new()
	faixa.name = "BordasDosAbismos"
	faixa.multimesh = mm
	faixa.material_override = Materiais.borda_abismo()
	body.add_child(faixa)

# Junta células sólidas vizinhas na MESMA linha (eixo X) numa corrida só.
# Devolve [{gx, gz, len}] — gx = primeira célula da corrida.
static func _merge_runs() -> Array:
	var out: Array = []
	for gz in GRID:
		var start := -1
		for gx in GRID + 1:   # +1 fecha a corrida que termina na borda
			var solid: bool = gx < GRID and not _holes.has(Vector2i(gx, gz))
			if solid and start < 0:
				start = gx
			elif not solid and start >= 0:
				out.append({"gx": start, "gz": gz, "len": gx - start})
				start = -1
	return out

# Reserva de decoração de perto. As marcas lineares foram removidas da arena
# principal: à distância elas se comprimiam em riscos escuros e quebravam a
# leitura limpa das lajes. A variação de altura, escala e três tons dos blocos
# já dá identidade ao cenário sem introduzir esse ruído.
#
# Mantida para uma futura arena menor, com câmera próxima e um LOD próprio.
static func _marcas_de_desgaste(parent: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED + 73
	var transformes: Array[Transform3D] = []
	var locais := 0
	var tentativas := 0
	while locais < 24 and tentativas < 300:
		tentativas += 1
		var px := rng.randf_range(-88.0, 88.0)
		var pz := rng.randf_range(-88.0, 88.0)
		if Vector2(px, pz).length() < 10.0 or is_hole_area(px, pz, 5.0, 5.0):
			continue
		locais += 1
		var ponta := Vector2(px, pz)
		var angulo := rng.randf_range(0.0, TAU)
		for _segmento in 3:
			var tamanho := rng.randf_range(0.55, 1.25)
			angulo += rng.randf_range(-0.45, 0.45)
			var dir := Vector2(sin(angulo), cos(angulo))
			var centro := ponta + dir * tamanho * 0.5
			transformes.append(Transform3D(
				Basis(Vector3.UP, angulo).scaled(Vector3(0.035, 0.014, tamanho)),
				Vector3(centro.x, 0.035, centro.y)))
			ponta += dir * tamanho
	if transformes.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var risco := BoxMesh.new()
	risco.size = Vector3.ONE
	mm.mesh = risco
	mm.instance_count = transformes.size()
	for i in transformes.size():
		mm.set_instance_transform(i, transformes[i])
	var marcas := MultiMeshInstance3D.new()
	marcas.name = "MarcasDeDesgaste"
	marcas.multimesh = mm
	marcas.material_override = Materiais.pedra_gasta(Color(0.22, 0.24, 0.28))
	parent.add_child(marcas)

# --------------------------------------------------------------------- blocos
static func _blocks(parent: Node) -> Array:
	var shared_mesh := BoxMesh.new()
	shared_mesh.size = Vector3.ONE
	var shared_shape := BoxShape3D.new()
	shared_shape.size = Vector3.ONE

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED

	var half := PLATFORM_SIZE * 0.5 - 6.0
	var out: Array = []
	for i in OBSTACLE_COUNT:
		var w := rng.randf_range(2.0, 6.0)
		var h := rng.randf_range(1.5, 9.0)
		var d := rng.randf_range(2.0, 6.0)
		var px := rng.randf_range(-half, half)
		var pz := rng.randf_range(-half, half)

		# Clareira no ponto de spawn do jogador.
		if Vector2(px, pz).length() < 8.0:
			continue
		# Bloco nenhum flutua sobre buraco (nem encosta na beirada dele).
		if is_hole_area(px, pz, w, d):
			continue

		var block := StaticBody3D.new()
		var m := MeshInstance3D.new()
		m.mesh = shared_mesh
		# Três tons de pedra gasta quebram a repetição dos pilares sem textura.
		var g: float = float([0.34, 0.45, 0.57][rng.randi_range(0, 2)]) + rng.randf_range(-0.025, 0.025)
		m.material_override = _gray(g, 0.8)
		block.add_child(m)

		var c := CollisionShape3D.new()
		c.shape = shared_shape
		block.add_child(c)

		block.scale = Vector3(w, h, d)
		block.position = Vector3(px, h * 0.5, pz)
		parent.add_child(block)

		out.append({"x": px, "z": pz, "top": h, "w": w, "d": d})
	return out

# ⚠️ ESTE É O FUNIL DO MUNDO INTEIRO. As duas chamadas dele fazem a plataforma
# em grade e os 90 blocos — ou seja, quase toda a superfície que aparece na
# tela. Por isso a Fase 3 do plano visual (banda de luz) começou aqui: um único
# ponto muda o estilo do mapa todo.
#
# `rough` deixou de ser usado: o shader de cel fixa rugosidade 1,0 e desliga o
# especular, porque brilho especular é gradiente e briga com faixa chapada. O
# parâmetro fica na assinatura para não mexer nas duas chamadas — e porque ele
# volta a valer se alguém devolver o material padrão.
static func _gray(value: float, rough: float) -> Material:
	return Materiais.pedra_gasta(Color(value * 0.94, value * 0.98, value))
