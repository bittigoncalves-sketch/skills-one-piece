extends SceneTree
## Colisão do relevo em faixas (V2b): a união das faixas é o mesmo chão do relevo inteiro, sem fresta nas divisas.
##   godot --headless --path . --script tools/dev_tests/test_relevo_em_faixas.gd
var ok := 0
var falhas := 0
func _init() -> void:
	rodar.call_deferred()
func confere(c: bool, m: String) -> void:
	if c:
		ok += 1
	else:
		falhas += 1
		print("FALHOU: ", m)
func rodar() -> void:
	var larg := 300
	var prof := 220
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.03
	var r := RelevoEmBlocos.new()
	r.origem = Vector2i(-37, 11)
	r.largura = larg
	r.profundidade = prof
	var reais := PackedFloat32Array()
	reais.resize(larg * prof)
	for j in prof:
		for i in larg:
			reais[j * larg + i] = 4.0 + (ruido.get_noise_2d(i, j) + 1.0) * 10.0
	var solo := PackedByteArray()
	solo.resize(larg * prof)
	r._paleta()
	r._ajustar(reais, solo)
	var inteiro := r.triangulos()
	var colisao_inteira := StaticBody3D.new()
	colisao_inteira.collision_layer = 2
	var c0 := CollisionShape3D.new()
	c0.shape = r.forma(inteiro)
	colisao_inteira.add_child(c0)
	root.add_child(colisao_inteira)
	var faixas := StaticBody3D.new()
	faixas.collision_layer = 4
	var tam := 64                                       # faixas de 64 meios: várias divisas dentro da ilha
	var faces_antes := r.faces
	var n_faixas := 0
	var area_faixas := 0.0
	for x0 in range(0, larg, tam):
		for z0 in range(0, prof, tam):
			var tri := r.triangulos_da_faixa(x0, mini(x0 + tam, larg), z0, mini(z0 + tam, prof))
			var v: PackedVector3Array = tri["vertices"]
			if v.is_empty():
				continue
			n_faixas += 1
			var cs := CollisionShape3D.new()
			cs.shape = ConcavePolygonShape3D.new()
			(cs.shape as ConcavePolygonShape3D).set_faces(v)
			faixas.add_child(cs)
			for t in v.size() / 3:
				area_faixas += (v[3 * t + 1] - v[3 * t]).cross(v[3 * t + 2] - v[3 * t]).length() * 0.5
	root.add_child(faixas)
	var area_inteira := 0.0
	var vi: PackedVector3Array = inteiro["vertices"]
	for t in vi.size() / 3:
		area_inteira += (vi[3 * t + 1] - vi[3 * t]).cross(vi[3 * t + 2] - vi[3 * t]).length() * 0.5
	print("   (%d faixas; área %.1f vs %.1f m²)" % [n_faixas, area_faixas, area_inteira])
	confere(n_faixas > 6, "várias faixas (%d)" % n_faixas)
	confere(absf(area_faixas / area_inteira - 1.0) < 0.06, "área das faixas ≈ área do relevo inteiro (%.3f)" % (area_faixas / area_inteira))
	await physics_frame
	await physics_frame
	var espaco := root.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var difere := 0
	var maior := 0.0
	var vazios := 0
	for k in 1500:
		# amostras perto das divisas (múltiplos de `tam` em meios) e em lugar qualquer
		var gi := float(r.origem.x) + (rng.randi_range(1, 4) * tam + rng.randf_range(-1.5, 1.5) if k % 2 == 0 else rng.randf_range(5, larg - 5))
		var gj := float(r.origem.y) + (rng.randi_range(1, 3) * tam + rng.randf_range(-1.5, 1.5) if k % 3 == 0 else rng.randf_range(5, prof - 5))
		var x := gi * RelevoEmBlocos.MEIO
		var z := gj * RelevoEmBlocos.MEIO
		var a := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -20, z), 2))
		var b := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -20, z), 4))
		if a.is_empty() and b.is_empty():
			continue
		if a.is_empty() != b.is_empty():
			vazios += 1
			continue
		maior = maxf(maior, absf(a.position.y - b.position.y))
		if absf(a.position.y - b.position.y) > 0.01:
			difere += 1
	confere(vazios == 0, "nenhum raio passa pela divisa das faixas (%d furos)" % vazios)
	confere(difere == 0, "o topo das faixas é o do relevo inteiro (%d divergem, maior %.5f m)" % [difere, maior])
	print("RELEVO_EM_FAIXAS ok=%d falhas=%d" % [ok, falhas])
	quit(1 if falhas > 0 else 0)
