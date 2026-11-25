extends RefCounted
## Peças da loja viram criaturas só no jogo. O arquivo do mapa permanece intacto.
const Oceano := preload("res://src/world/oceano_historia.gd")
const Besta := preload("res://src/historia/bestas_mar/besta_do_mar.gd")
const Perfis := preload("res://src/historia/bestas_mar/perfis.json")
const COMPORTAMENTO := "besta_do_mar"


## `relevo` (14/10/2026, relevo marinho — docs/MAR_HISTORIA_PLANO.md): com ele, o ponto de
## passeio no mar é empurrado para fora até ter água para o corpo inteiro da espécie.
static func ligar(raiz: Node3D, mapa: Dictionary, bib: BibliotecaDeModelos, jogador_de: Callable,
		relevo: RelevoMarinho = null) -> Array[Node3D]:
	var criadas: Array[Node3D] = []
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] != "modelo" or not Perfis.data.has(str(p.get("modelo", ""))):
			continue
		# IDs conhecidos também migram mapas/catálogos anteriores ao comportamento.
		if not bib.tem(p["modelo"]):
			continue
		var antigo := raiz.get_node_or_null(NodePath(p["id"]))
		if antigo != null:
			raiz.remove_child(antigo)
			antigo.queue_free()
		var besta := Besta.new()
		besta.name = p["id"]
		besta.position = (p["posicao"] as Vector3) - Vector3.UP * (p["tamanho"] as Vector3).y * .5
		besta.alvo_de = jogador_de
		raiz.add_child(besta)
		besta.montar(bib, p["modelo"], p)
		besta.origem = besta.global_position
		var costa := pontos_da_costa(besta.origem, mapa, 5.0 * float(besta.get("_escala").x),
			relevo, float(besta.get("_altura")) + 3.0)
		besta.praia = costa.praia
		besta.mar = costa.mar
		besta.iniciar_rotina()
		criadas.append(besta)
	return criadas


## `mar` fica 100 m além da praia. Com `relevo`, segue para fora (até +400 m) até ter
## `profundidade` de água: a plataforma rasa (5–25 m, decisão do dono de 14/10) não cabe a
## girafa inteira a 100 m — o mergulho dela parou de cobrir o corpo (A/B no
## `test_rotina_oceano_bestas`: 32/32 com o fundo antigo, 29/32 com o relevo novo).
static func pontos_da_costa(origem: Vector3, mapa: Dictionary, margem: float,
		relevo: RelevoMarinho = null, profundidade := 0.0) -> Dictionary:
	var menor := INF
	var praia := origem
	var mar := Vector3.INF
	for p: Dictionary in mapa["pecas"]:
		if not Oceano.e_base(p):
			continue
		var centro: Vector3 = p["posicao"]
		var tamanho: Vector3 = p["tamanho"]
		var base := Basis(Vector3.UP, deg_to_rad((p["rotacao_graus"] as Vector3).y))
		var local := base.inverse() * (origem - centro)
		var meio := tamanho * .5
		for lado in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var beira := Vector3(clampf(local.x, -meio.x, meio.x), meio.y, clampf(local.z, -meio.z, meio.z))
			if lado.x != 0.0:
				beira.x = lado.x * meio.x
			else:
				beira.z = lado.z * meio.z
			var distancia := (base * beira + centro).distance_squared_to(origem)
			if distancia < menor:
				menor = distancia
				praia = centro + base * (beira - lado * margem)
				mar = centro + base * (beira + lado * (margem + 100.0))
	if relevo != null and mar.is_finite():
		var rumo := Vector3(mar.x - praia.x, 0.0, mar.z - praia.z).normalized()
		var extra := 0.0
		while extra < 400.0 and relevo.profundidade(mar.x + rumo.x * extra, mar.z + rumo.z * extra) < profundidade:
			extra += 10.0
		mar += rumo * extra
	return {"praia": praia, "mar": mar}
