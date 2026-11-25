extends SceneTree
# ============================================================================
#  CRATERAS QUE SE REFAZEM (31/10/2026) — `McRelevoCavavel` sobre o relevo em blocos de uma ilha:
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_relevo_cavavel_mine_piece.gd
#
#  Ilha sintética (40×40 meios, topo em 4 meios = 1,76 m, placa de 1 bloco abaixo de 0). Mede com raios de verdade:
#  cavar baixa o topo da coluna certa; o subsolo abre CAVERNA; dois blocos empilhados descem mais; vários
#  buracos no mesmo quadro refazem poucas seções; depois do tempo o terreno volta e quem ficou dentro sobe.
# ============================================================================

const B := RelevoEmBlocos.BLOCO
const MEIO := RelevoEmBlocos.MEIO
var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func esperar_refeitura(mundo: McMundo) -> void:
	for i in 600:
		mundo.tick()
		await physics_frame
		if not mundo.relevo.ocupado():
			break
	await quadros(3)


func topo_em(x: float, z: float) -> float:
	var raio := PhysicsRayQueryParameters3D.create(Vector3(x, 20.0, z), Vector3(x, -5.0, z))
	raio.collision_mask = 1
	var r := get_root().get_world_3d().direct_space_state.intersect_ray(raio)
	return r.position.y if not r.is_empty() else NAN


func rodar() -> void:
	var r := RelevoEmBlocos.new()
	r.origem = Vector2i(0, 0)
	r.largura = 40
	r.profundidade = 40
	r.f = PackedInt32Array()
	r.f.resize(1600)
	r.f.fill(4)
	r.cor = PackedByteArray()
	r.cor.resize(1600)
	r.paleta = [Color(0.6, 0.6, 0.55)]
	r.fundo = -2                                  # 1 bloco de placa embaixo do chão
	# V2b: o terreno é uma GRADE DE BLOCOS gerada do relevo (a colisão é das seções; o relevo antigo só desenha de longe).
	var grade := GradeVoxel.new()
	grade.gerador = GeradorDeRelevo.new(r)
	get_root().add_child(grade)
	grade.carregar_caixa(grade.gerador.caixa_min, grade.gerador.caixa_max)
	grade.esperar_tudo()
	await quadros(3)
	var mundo := Mc.mundo(self)
	mundo.relevo.tempo_para_refazer = 60

	print("\n-- cavar --")
	var cx := (5 * 2 + 1) * MEIO          # centro do bloco (5, ?, 5): meios 10..11
	ok(is_equal_approx(topo_em(cx, cx), 4 * MEIO), "antes: topo em %.3f m" % topo_em(cx, cx))
	var c5 := McVec3.de(5.0, 1.0, 5.0)          # bloco de cima (a coluna de 4 meios tem os blocos y = -1, 0 e 1)
	ok(mundo.getBlockState(c5).isSolid(), "o bloco do topo é sólido para a camada")
	mundo.setBlock(c5, Mc.bloco(&"minecraft:air").defaultBlockState(), 3)
	await esperar_refeitura(mundo)
	ok(is_equal_approx(topo_em(cx, cx), 2 * MEIO), "depois de tirar o bloco do topo, o chão está 1 bloco abaixo (%.3f m)" % topo_em(cx, cx))
	var vizinho := (7 * 2 + 1) * MEIO
	ok(is_equal_approx(topo_em(vizinho, vizinho), 4 * MEIO), "o vizinho não mudou (%.3f m)" % topo_em(vizinho, vizinho))
	ok(not mundo.getBlockState(c5).isSolid(), "o bloco cavado já não é sólido para a camada")
	ok(grade.secoes_com_blocos() == 1, "só a seção tocada fica guardada (%d)" % grade.secoes_com_blocos())

	print("\n-- caverna e pilha --")
	var c12 := (12 * 2 + 1) * MEIO
	mundo.setBlock(McVec3.de(12.0, 0.0, 12.0), Mc.bloco(&"minecraft:air").defaultBlockState(), 3)     # só o bloco do meio: abre uma CAVERNA
	await esperar_refeitura(mundo)
	ok(is_equal_approx(topo_em(c12, c12), 4 * MEIO) and not mundo.getBlockState(McVec3.de(12.0, 0.0, 12.0)).isSolid(), "tirar só o bloco do meio abre uma caverna (topo segue em %.3f m)" % topo_em(c12, c12))
	for y in [1, 0]:
		mundo.setBlock(McVec3.de(15.0, float(y), 15.0), Mc.bloco(&"minecraft:air").defaultBlockState(), 3)       # em qualquer ordem: o de cima primeiro
	await esperar_refeitura(mundo)
	var c15 := (15 * 2 + 1) * MEIO
	ok(is_equal_approx(topo_em(c15, c15), 0.0), "os dois blocos da pilha tirados descem até a placa (%.3f m)" % topo_em(c15, c15))
	mundo.setBlock(McVec3.de(16.0, 0.0, 16.0), Mc.bloco(&"minecraft:air").defaultBlockState(), 3)
	mundo.setBlock(McVec3.de(16.0, 1.0, 16.0), Mc.bloco(&"minecraft:air").defaultBlockState(), 3)     # de baixo ANTES do de cima
	await esperar_refeitura(mundo)
	var c16 := (16 * 2 + 1) * MEIO
	ok(is_equal_approx(topo_em(c16, c16), 0.0), "a ordem das chamadas não importa (baixo antes de cima): %.3f m" % topo_em(c16, c16))

	print("\n-- refazer --")
	var ocupante := CharacterBody3D.new()
	ocupante.add_to_group(AlvosDeGolpe.GRUPO)
	get_root().add_child(ocupante)
	ocupante.global_position = Vector3(c15, 0.1, c15)         # de pé no fundo da cratera
	for i in 80:
		mundo.tick()
		await physics_frame
	await esperar_refeitura(mundo)
	await quadros(3)
	ok(is_equal_approx(topo_em(cx, cx), 4 * MEIO) and is_equal_approx(topo_em(c15, c15), 4 * MEIO), "passado o tempo, o relevo VOLTA (%.3f m e %.3f m)" % [topo_em(cx, cx), topo_em(c15, c15)])
	ok(ocupante.global_position.y >= 4 * MEIO - 0.01, "quem estava dentro da cratera sobe para a superfície nova (y %.3f)" % ocupante.global_position.y)
	ok(mundo.relevo._regras.is_empty() and grade.secoes_com_blocos() == 0, "nenhum corte ativo, nenhuma seção guardada (%d)" % grade.secoes_com_blocos())

	print("\n-- vários buracos, uma refeitura --")
	var antes := grade.reconstrucoes
	for k in 6:
		mundo.setBlock(McVec3.de(3.0 + k * 3.0, 1.0, 10.0), Mc.bloco(&"minecraft:air").defaultBlockState(), 3)
	await process_frame
	await process_frame
	ok(mundo.relevo.ocupado(), "seis buracos no mesmo quadro agendam a refeitura")
	await esperar_refeitura(mundo)
	var todos := true
	for k in 6:
		var xx := ((3 + k * 3) * 2 + 1) * MEIO
		var h := topo_em(xx, (10 * 2 + 1) * MEIO)
		todos = todos and is_equal_approx(h, 2 * MEIO)
	ok(todos, "…e os seis ficam cavados")
	ok(grade.reconstrucoes - antes <= 2, "…com poucas seções refeitas (%d)" % (grade.reconstrucoes - antes))

	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
