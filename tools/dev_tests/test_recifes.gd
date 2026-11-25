extends SceneTree
# ============================================================================
#  TESTE — recifes (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E2).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_recifes.gd
#
#  Lê o MAPA VIVO (só leitura). Planta os blocos da plataforma em volta da ilha inicial e
#  confere: determinismo, nada fora d'água, nada flutuando nem enterrado demais, corais de
#  recife na zona de recife, orçamento por bloco, e o esconder com a câmera fora d'água.
#  Controles: bloco de mar aberto (fundo, sem recife) e bloco em cima da ilha ficam vazios.
# ============================================================================

const Recifes := preload("res://src/historia/mar/recifes.gd")
const MAX_INSTANCIAS_BLOCO := 450
## Triângulos BRUTOS (entrada do LOD = memória, não o que a GPU desenha). O desenhado é
## medido pelo `medir_mar.gd` (A/B com e sem o Mar): +36 mil primitivas no recife mais
## denso (14/10/2026), pelo LOD automático da importação e o alcance de desenho.
const MAX_TRIANGULOS_BLOCO := 600000

var _falhas := 0


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	print("\n===== RECIFES =====")
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var oceano: Script = load("res://src/world/oceano_historia.gd")
	var bases: Array = mapa["pecas"].filter(func(p: Dictionary) -> bool: return oceano.e_base(p))
	var mundo := Node3D.new()
	root.add_child(mundo)
	var fundos := FundoDoMar.montar_por_ilha(mundo, mapa, bases, -0.65)
	var relevo: RelevoMarinho = fundos[0].relevo
	var recifes: Node3D = Recifes.new()
	mundo.add_child(recifes)
	recifes.configurar(relevo)
	_ok((recifes.get("_malhas") as Dictionary).size() == Recifes.ESPECIES.size(), "todas as %d espécies com malha no GLB" % Recifes.ESPECIES.size())

	# Plataforma em volta da ilha inicial: blocos de x,z em [-448, 448].
	var por_especie := {}
	var total := 0
	var fora_dagua := 0
	var flutuando := 0
	var enterrado := 0
	var recife_fora_da_zona := 0
	var de_recife := 0
	var maior_bloco := 0
	var maior_tri := 0
	var rasos := 0
	for bj in range(-7, 7):
		for bi in range(-7, 7):
			var c := Vector2i(bi, bj)
			var plantas: Dictionary = recifes.plantar(c)
			var n_bloco := 0
			var tri_bloco := 0
			for especie in plantas:
				var malha: Mesh = recifes.get("_malhas")[especie]
				var aabb := malha.get_aabb()
				var tri := _triangulos(malha)
				for inst in plantas[especie]:
					var t: Transform3D = inst["transform"]
					var escala := t.basis.get_scale().y
					var chao := relevo.altura(t.origin.x, t.origin.z)
					var topo := t.origin.y + aabb.size.y * escala
					total += 1
					n_bloco += 1
					tri_bloco += tri
					por_especie[especie] = int(por_especie.get(especie, 0)) + 1
					fora_dagua += int(topo > relevo.nivel - 0.3 and especie != "alga")
					rasos += int(relevo.nivel - chao < 3.0)
					flutuando += int(t.origin.y > chao + 0.05)
					enterrado += int(t.origin.y < chao - aabb.size.y * escala * 0.25 - 0.05)
					# Leque e anêmona também crescem em rocha fora do recife (de propósito).
					if Recifes.PESO_RECIFE.has(especie) and not especie in ["coral_leque", "anemona"]:
						de_recife += 1
						recife_fora_da_zona += int(relevo.recife(t.origin.x, t.origin.z) < 0.04)
			maior_bloco = maxi(maior_bloco, n_bloco)
			maior_tri = maxi(maior_tri, tri_bloco)
	print("     %d instâncias: %s" % [total, por_especie])
	_ok(total > 3000, "a plataforma da ilha inicial tem recife (%d instâncias)" % total)
	_ok(por_especie.size() == Recifes.ESPECIES.size(), "todas as espécies aparecem (%d/%d)" % [por_especie.size(), Recifes.ESPECIES.size()])
	_ok(rasos == 0, "nada nasce com menos de 3 m de água (%d)" % rasos)
	_ok(fora_dagua == 0, "nenhum coral passa da superfície (%d)" % fora_dagua)
	_ok(flutuando == 0, "nenhum flutua acima do chão (%d)" % flutuando)
	_ok(enterrado == 0, "nenhum enterrado mais que 1/4 da altura (%d)" % enterrado)
	_ok(recife_fora_da_zona == 0, "coral de recife só na zona de recife (%d de %d fora)" % [recife_fora_da_zona, de_recife])
	_ok(maior_bloco <= MAX_INSTANCIAS_BLOCO, "orçamento: maior bloco com %d instâncias (≤ %d)" % [maior_bloco, MAX_INSTANCIAS_BLOCO])
	_ok(maior_tri <= MAX_TRIANGULOS_BLOCO, "orçamento: maior bloco com %d triângulos (≤ %d, antes do LOD)" % [maior_tri, MAX_TRIANGULOS_BLOCO])

	# Determinismo.
	var a: Dictionary = recifes.plantar(Vector2i(5, 1))
	var b: Dictionary = recifes.plantar(Vector2i(5, 1))
	var iguais := a.keys() == b.keys()
	for k in a:
		iguais = iguais and (a[k] as Array).size() == (b[k] as Array).size()
		if iguais and not (a[k] as Array).is_empty():
			iguais = (a[k][0]["transform"] as Transform3D).is_equal_approx(b[k][0]["transform"])
	_ok(iguais, "determinístico: o mesmo bloco planta o mesmo recife")

	# Controles: mar aberto (x≈640) e em cima da ilha (x≈0).
	var aberto := _contar(recifes.plantar(Vector2i(10, 0)))
	var ilha := _contar(recifes.plantar(Vector2i(0, 0)))
	_ok(aberto < 15, "controle: mar aberto a ~64 m quase vazio (%d)" % aberto)
	_ok(ilha == 0, "controle: bloco em cima da ilha vazio (%d)" % ilha)

	# Montagem e esconder fora d'água.
	var cam := Camera3D.new()
	mundo.add_child(cam)
	recifes.set("camera_de", func() -> Camera3D: return cam)
	cam.global_position = Vector3(380, -8, 90)
	recifes.call("montar_em_volta", Vector2(380, 90), 100.0)
	await process_frame
	var mmis := recifes.find_children("*", "MultiMeshInstance3D", true, false)
	_ok(not mmis.is_empty() and mmis.all(func(m: MultiMeshInstance3D) -> bool: return m.visibility_range_end > 0.0 and m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),
		"%d MultiMesh montados, com alcance de desenho e sem sombra" % mmis.size())
	_ok(recifes.visible, "câmera submersa: recifes desenhados")
	cam.global_position = Vector3(380, 2, 90)
	await process_frame
	_ok(not recifes.visible, "câmera fora d'água: recifes escondidos (a superfície é opaca)")
	mundo.queue_free()
	await process_frame
	print("\nRECIFES_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


static func _contar(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += (d[k] as Array).size()
	return n


static func _triangulos(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var idx: PackedInt32Array = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		t += idx.size() / 3 if not idx.is_empty() else (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return t
