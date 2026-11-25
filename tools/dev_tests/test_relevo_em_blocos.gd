extends SceneTree
# ============================================================================
#  RELEVO EM BLOCOS (22/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md, E1) — o núcleo, com
#  relevos de mentira (não abre o jogo):
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_relevo_em_blocos.gd
#
#    • plano: um tipo só e o mínimo de faces (1 topo + 4 paredes de fora);
#    • duas peças vizinhas da mesma altura fundem (as mesmas 5 faces, nada na emenda);
#    • rampa: altura dos blocos perto da fonte, degraus de meio bloco, escadas;
#    • penhasco: aparece a lateral; toda célula é um dos 4 tipos;
#    • colisão: um raio de cima bate na altura do bloco.
# ============================================================================

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


## Peça de terreno de lado `lado` m centrada em (cx, cz), base no y = 0, alturas pela função.
func peca(cx: float, cz: float, lado: float, altura: Callable, celulas := 16) -> Dictionary:
	var r := TerrenoDoMapa.plano(celulas)
	var alturas: PackedInt32Array = r["alturas"]
	for j in celulas + 1:
		for i in celulas + 1:
			var x := cx + (float(i) / celulas - 0.5) * lado
			var z := cz + (float(j) / celulas - 0.5) * lado
			alturas[j * (celulas + 1) + i] = int(round(float(altura.call(x, z)) / 10.0 * TerrenoDoMapa.ESCALA))
	r["alturas"] = alturas
	return {"posicao": Vector3(cx, 5.0, cz), "tamanho": Vector3(lado, 10.0, lado), "rotacao_graus": Vector3.ZERO, "relevo": r}


func rodar() -> void:
	var B := RelevoEmBlocos.BLOCO
	var M := RelevoEmBlocos.MEIO

	print("\n-- plano --")
	var plano := RelevoEmBlocos.de_pecas([peca(B * 5, B * 5, B * 10, func(_x, _z): return 3.0 * M)])
	plano.triangulos()
	ok(plano.contagem_de_tipos().keys() == ["meio_bloco"], "plano a 3 meios: só meio bloco %s" % plano.contagem_de_tipos())
	ok(plano.faces == 5, "plano: %d faces (1 topo + 4 paredes)" % plano.faces)
	ok(is_equal_approx(plano.altura(B * 5, B * 5), 3.0 * M), "plano: topo a %.2f m" % plano.altura(B * 5, B * 5))

	print("\n-- duas peças vizinhas fundem --")
	var duas := RelevoEmBlocos.de_pecas([peca(B * 5, B * 5, B * 10, func(_x, _z): return 4.0 * M),
		peca(B * 15, B * 5, B * 10, func(_x, _z): return 4.0 * M)])
	duas.triangulos()
	ok(duas.faces == 5, "duas peças à mesma altura: %d faces, nada na emenda" % duas.faces)
	ok(duas.contagem_de_tipos().keys() == ["bloco"], "4 meios = bloco inteiro %s" % duas.contagem_de_tipos())

	print("\n-- rampa suave (1:4) --")
	var rampa_f := func(x, _z): return 0.5 + x * 0.25
	var rampa := RelevoEmBlocos.de_pecas([peca(16.0, 8.0, 32.0, rampa_f, 32)])
	rampa.triangulos()
	var pior := 0.0
	var degrau := 0
	for j in range(4, rampa.profundidade - 4):
		for i in range(4, rampa.largura - 4):
			var x := (rampa.origem.x + i + 0.5) * M
			var z := (rampa.origem.y + j + 0.5) * M
			pior = maxf(pior, absf(rampa.altura(x, z) - float(rampa_f.call(x, z))))
			degrau = maxi(degrau, absi(rampa.f[j * rampa.largura + i + 1] - rampa.f[j * rampa.largura + i]))
	ok(pior <= M + 0.01, "rampa: bloco a no máximo %.2f m da fonte (≤ 1 meio)" % pior)
	ok(degrau <= 1, "rampa: maior degrau entre vizinhos = %d meio(s) (anda-se subindo meio bloco)" % degrau)
	ok(rampa.contagem_de_tipos().has("escada") or rampa.contagem_de_tipos().has("meio_bloco"),
		"rampa usa meio bloco/escada %s" % rampa.contagem_de_tipos())
	ok(rampa.faces < rampa.largura * rampa.profundidade / 8, "rampa: %d faces para %d meios" % [rampa.faces,
		rampa.largura * rampa.profundidade])

	print("\n-- penhasco --")
	var penhasco := RelevoEmBlocos.de_pecas([peca(8.0, 8.0, 16.0, func(x, _z): return 6.0 if x > 8.0 else 0.6, 64)])
	penhasco.triangulos()
	var tipos := penhasco.contagem_de_tipos()
	ok(tipos.has("lateral"), "penhasco tem lateral %s" % tipos)
	var validas := true
	for cj in penhasco.profundidade / 2:
		for ci in penhasco.largura / 2:
			var k := 2 * cj * penhasco.largura + 2 * ci
			var v := Vector4i(penhasco.f[k], penhasco.f[k + 1], penhasco.f[k + penhasco.largura], penhasco.f[k + penhasco.largura + 1])
			validas = validas and _valida(v)
	ok(validas, "toda célula é bloco, meio bloco, escada ou lateral (empilhados)")

	print("\n-- colisão --")
	var corpo := StaticBody3D.new()
	root.add_child(corpo)
	var col := CollisionShape3D.new()
	col.shape = rampa.forma(rampa.triangulos())
	corpo.add_child(col)
	for i in 3:
		await physics_frame
	var espaco := corpo.get_world_3d().direct_space_state
	var bate := 0
	var pontos := 0
	for x in [3.1, 9.7, 16.3, 22.9, 28.1]:
		for z in [3.3, 8.9, 12.1]:
			pontos += 1
			var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 50, z), Vector3(x, -50, z)))
			if not hit.is_empty() and absf((hit["position"] as Vector3).y - rampa.altura(x, z)) < 0.01:
				bate += 1
	ok(bate == pontos, "raio de cima bate no topo do bloco em %d/%d pontos" % [bate, pontos])

	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)


## Alturas de uma célula (ordem −x−z, +x−z, −x+z, +x+z) formam uma pilha dos 4 tipos.
static func _valida(v: Vector4i) -> bool:
	if v.x == v.y and v.y == v.z and v.z == v.w:
		return true
	for lados in [[[0, 2], [1, 3]], [[0, 1], [2, 3]]]:
		for troca in 2:
			var alto: Array = lados[1 - troca]
			var baixo: Array = lados[troca]
			if v[alto[0]] == v[alto[1]] and v[baixo[0]] == v[baixo[1]] and v[alto[0]] > v[baixo[0]] and v[alto[0]] % 2 == 0:
				return true
	return false
