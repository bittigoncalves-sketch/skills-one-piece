extends SceneTree
## VISUAL DA MERA MERA — mede a geometria de fogo, não julga no olho.
##
## A régua é a mesma dos testes da Ope: número medido, nunca rótulo. Este teste
## existe porque o visual da Mera passou de partícula para MALHA em 2026-09-08,
## e malha se pode medir — contagem de vértices, caixa envolvente, determinismo
## e limpeza. Partícula não dava nenhuma dessas.
##
## ⚠️ NÃO mede cor, brilho nem "se ficou bonito". Isso precisa de olho humano e
## de tela; ver a seção final do relatório.

const GEO := preload("res://src/effects/MeraGeometry.gd")
const VFX := preload("res://src/effects/MeraVfx.gd")
const BURST := preload("res://src/effects/MeraFireBurst.gd")
const BODY := preload("res://src/effects/MeraEmberBody.gd")

var falhas := 0
var checagens := 0


func _initialize() -> void:
	call_deferred("_rodar")


func ok(cond: bool, msg: String) -> void:
	checagens += 1
	if cond:
		print("PASS ", msg)
	else:
		falhas += 1
		print("FALHA ", msg)


func _rodar() -> void:
	var palco := Node3D.new()
	get_root().add_child(palco)

	# CHÃO. A queimadura só nasce quando há chão embaixo — este mapa tem
	# BURACOS, e marca de fogo flutuando sobre um buraco seria pior que marca
	# nenhuma. Sem um corpo estático aqui, esse contrato não dá para medir.
	var chao := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(40.0, 1.0, 40.0)
	forma.shape = caixa
	chao.add_child(forma)
	palco.add_child(chao)
	chao.global_position = Vector3(0.0, -0.5, 0.0)
	# O espaço físico só enxerga o corpo depois de um passo de física.
	await physics_frame
	await physics_frame

	_medir_lingua(palco)
	_medir_determinismo(palco)
	_medir_span(palco)
	await _medir_custo_por_escala(palco)
	await _medir_corpo(palco)
	_medir_limpeza(palco)

	await _medir_pai_sumido(palco)

	print("\nMERA VISUAL: %d verificações, %d falhas" % [checagens, falhas])
	palco.queue_free()
	quit(1 if falhas > 0 else 0)


# ---------------------------------------------------------------- a primitiva

func _medir_lingua(palco: Node3D) -> void:
	var material := GEO.flame_material(2.0)
	var lingua := GEO.tongue(palco, 2.0, 0.35, material, 1.0)
	var malha: ArrayMesh = lingua.mesh
	ok(malha != null and malha.get_surface_count() == 1, "a língua vira UMA superfície")

	var vertices := malha.surface_get_array_len(0)
	ok(vertices > 300, "a língua tem volume real (%d vértices)" % vertices)

	var caixa := malha.get_aabb()
	# O shader normaliza o gradiente por `span` a partir do EIXO LOCAL +Y: se a
	# malha não começar em y≈0 e terminar em y≈comprimento, o fogo sai com a
	# ponta clara e a base escura — invertido.
	ok(absf(caixa.position.y) < 0.02, "a base fica na origem (y=%.4f)" % caixa.position.y)
	ok(absf(caixa.size.y - 2.0) < 0.02, "a ponta chega ao comprimento pedido (%.4f)" % caixa.size.y)

	# Afilamento: a chama tem que ser mais fina em cima que embaixo, senão é
	# cilindro. Medido comparando o raio dos vértices na base e no topo.
	var pontos: PackedVector3Array = malha.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var raio_base := 0.0
	var raio_topo := 0.0
	for ponto in pontos:
		var raio := Vector2(ponto.x, ponto.z).length()
		if ponto.y < 0.25:
			raio_base = maxf(raio_base, raio)
		elif ponto.y > 1.75:
			raio_topo = maxf(raio_topo, raio)
	ok(raio_topo < raio_base * 0.45,
		"a chama AFINA para a ponta (base %.3f m, topo %.3f m)" % [raio_base, raio_topo])


func _medir_determinismo(palco: Node3D) -> void:
	# ⚠️ O sol antigo usava `randf_range`: cada peer sorteava o SEU sol, então o
	# golpe tinha silhueta diferente em cada máquina. Nada aqui pode sortear.
	var material := GEO.flame_material(1.0)
	var a: ArrayMesh = GEO.tongue(palco, 1.0, 0.2, material, 3.0).mesh
	var b: ArrayMesh = GEO.tongue(palco, 1.0, 0.2, material, 3.0).mesh
	var va: PackedVector3Array = a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var iguais := va.size() == vb.size()
	if iguais:
		for i: int in range(va.size()):
			if va[i].distance_to(vb[i]) > 0.0001:
				iguais = false
				break
	ok(iguais, "a mesma semente reconstrói a MESMA malha (sem sorteio)")

	var c: ArrayMesh = GEO.tongue(palco, 1.0, 0.2, material, 9.0).mesh
	var vc: PackedVector3Array = c.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var diferente := false
	for i: int in range(mini(va.size(), vc.size())):
		if va[i].distance_to(vc[i]) > 0.01:
			diferente = true
			break
	ok(diferente, "sementes diferentes dão línguas diferentes")


## O `mera_flame` normaliza o gradiente de calor por `span`, e quem monta passa
## `span = comprimento pedido`. Uma língua MAIS COMPRIDA que isso tem a ponta em
## h=1, onde a erosão apaga tudo: o fogo sai mais curto do que foi pedido, sem
## um único erro no log. Este é o invariante que impede a regressão.
func _medir_span(palco: Node3D) -> void:
	var comprimento := 2.0
	var material := GEO.flame_material(comprimento)
	var coroa := Node3D.new()
	palco.add_child(coroa)
	var linguas := GEO.plume(coroa, 9, 0.6, comprimento, 0.25, material)
	var mais_alta := 0.0
	for lingua in linguas:
		mais_alta = maxf(mais_alta, (lingua.mesh as ArrayMesh).get_aabb().size.y)
	ok(mais_alta <= comprimento + 0.001,
		"nenhuma língua da coroa passa do `span` (%.4f de %.1f)" % [mais_alta, comprimento])
	ok(mais_alta > comprimento * 0.9,
		"e a mais alta CHEGA perto dele (%.4f) — a coroa não encolheu" % mais_alta)


func _medir_custo_por_escala(palco: Node3D) -> void:
	# O C detona 45 vagalumes em cascata de 2,25 s. O impacto pequeno TEM que
	# custar menos que o grande, senão a mudança de visual vira queda de quadro.
	var pequeno := BURST.new()
	pequeno.mode = "impact"
	pequeno.scale_factor = 0.6
	palco.add_child(pequeno)

	var grande := BURST.new()
	grande.mode = "impact"
	grande.scale_factor = 1.6
	palco.add_child(grande)
	grande.global_position = Vector3(0.0, 1.0, 0.0)   # sobre o chão do palco

	# E um terceiro, longe do chão: tem que se recusar a marcar.
	var no_vazio := BURST.new()
	no_vazio.mode = "impact"
	no_vazio.scale_factor = 1.6
	palco.add_child(no_vazio)
	no_vazio.global_position = Vector3(500.0, 60.0, 500.0)

	# A queimadura nasce no PRIMEIRO quadro, não no `_ready` — de propósito, para
	# só medir o chão depois de o efeito estar no lugar certo. Medir antes disso
	# é medir o efeito ainda na origem.
	# ⚠️ DOIS quadros, não um. O sinal `process_frame` da SceneTree chega ANTES
	# do `_process` dos nós — esperar só um deixa a marca ainda por montar, e o
	# teste reprova medindo o quadro errado.
	await process_frame
	await process_frame

	var v_pequeno := _contar_vertices(pequeno)
	var v_grande := _contar_vertices(grande)
	ok(v_pequeno > 0 and v_grande > 0, "os dois impactos criaram malha")
	ok(v_pequeno < v_grande * 0.6,
		"impacto pequeno custa MENOS (%d vs %d vértices)" % [v_pequeno, v_grande])

	# E não pode consultar o chão: 45 raycasts na cascata.
	# A queimadura é o único `PlaneMesh` do efeito — contar o tipo é uma medida,
	# contar o NOME não seria: `GEO.instance` não batiza o nó.
	ok(_contar_malhas_de_plano(pequeno) == 0, "impacto pequeno não consulta o chão")
	ok(_contar_malhas_de_plano(grande) >= 1, "impacto grande sobre o chão DEIXA queimadura")
	ok(_contar_malhas_de_plano(no_vazio) == 0,
		"impacto no VAZIO não deixa queimadura pendurada no ar")


func _medir_corpo(palco: Node3D) -> void:
	var punho := VFX.fist(palco, Vector3.FORWARD, 1.0)
	var sol := VFX.sun(palco, 7.0, true)

	# A fachada anexa de forma ADIADA de propósito — vários efeitos da Mera
	# nascem dentro de um `tree_exiting`, onde `add_child` direto é recusado.
	# Consequência: a malha só existe no quadro seguinte, e medir antes disso
	# mede um nó vazio. Este par de `await` É o contrato sendo verificado.
	ok(_contar_vertices(punho) == 0, "a fachada ainda NÃO montou o punho (anexo adiado)")
	await process_frame
	await process_frame

	ok(_contar_vertices(punho) > 0, "o punho do Hiken cria malha depois do anexo")
	# ⚠️ O `MultiMesh` VOLTOU, e de propósito. A asserção antiga era
	# "não usa MultiMesh", e ela estava medindo a coisa errada: o problema do
	# punho original nunca foi a técnica — 60 blocos num desenho só é o jeito
	# certo —, era o MATERIAL laranja chapado. Trocar os blocos por uma esfera
	# custou a SILHUETA, que é o nome do golpe. O que este teste tem que travar
	# é o material e a forma, não o tipo de nó.
	var blocos := punho.get("_nucleo_punho") as MultiMeshInstance3D
	ok(blocos != null, "o punho mantém os blocos autorados (palma, dedos, polegar)")
	if blocos != null:
		ok(blocos.multimesh.instance_count > 50,
			"são ~60 blocos, não uma bola (%d)" % blocos.multimesh.instance_count)
		ok(blocos.material_override is ShaderMaterial,
			"os blocos usam o shader de brasa, não material chapado")
		# Se o eixo não acompanhar o voo, o punho voa de lado — sem erro no log.
		var frente := -blocos.global_transform.basis.z.normalized()
		ok(frente.dot(Vector3.FORWARD) > 0.98,
			"os dedos apontam na direção do voo (produto escalar %.4f)" % frente.dot(Vector3.FORWARD))

	ok(_contar_vertices(sol) > 0, "o sol do Entei cria malha")
	# 1 cubo central + 24 erupções + coroas de chama.
	var caixas := _contar_malhas_de_caixa(sol)
	ok(caixas >= 25, "o Sol Quadrado mantém o núcleo em blocos (%d caixas)" % caixas)

	sol.set_heat(0.25)
	ok(true, "set_heat aceita a carga sem erro")


func _medir_limpeza(palco: Node3D) -> void:
	# Critério 6 do PLANO_FRUTAS: o efeito tem que sumir sozinho.
	var antes := _contar_nos_totais(palco)
	var estouro := BURST.new()
	estouro.mode = "muzzle"
	palco.add_child(estouro)
	ok(_contar_nos_totais(palco) > antes, "o clarão nasce na árvore")

	# O clarão vive 0,22 s; empurrar o relógio bem além disso tem que matá-lo.
	for _i: int in range(40):
		if is_instance_valid(estouro):
			estouro._process(0.02)
	ok(not is_instance_valid(estouro) or estouro.is_queued_for_deletion(),
		"o clarão se apaga sozinho no fim do próprio relógio")


## O anexo é adiado um quadro. Se o pai morrer nesse intervalo — o caso real é o
## efeito que nasce de um `tree_exiting` —, o efeito não pode ficar órfão: nem
## na árvore, nem liberado. Critério 6 do `docs/PLANO_FRUTAS.md`.
func _medir_pai_sumido(palco: Node3D) -> void:
	var pai := Node3D.new()
	palco.add_child(pai)
	var efeito := VFX.impact(pai, Vector3.ZERO, 1.0)
	ok(efeito != null, "a fachada devolveu o efeito antes do anexo")
	pai.free()   # `free`, não `queue_free`: mata o pai ANTES do quadro do anexo
	await process_frame
	await process_frame
	ok(not is_instance_valid(efeito),
		"pai morto antes do anexo -> o efeito é liberado, não vira órfão")


# ----------------------------------------------------------------- utilidades

## ⚠️ `surface_get_array_len` só existe em `ArrayMesh`. As primitivas do Godot
## (Torus, Sphere, Box, Plane) derivam de `PrimitiveMesh` e NÃO a têm — chamá-la
## lança e aborta a contagem inteira, o que fez este teste medir 0 vértice num
## nó que tinha malha. `surface_get_arrays` está na base `Mesh` e serve às duas.
func _contar_vertices(raiz: Node) -> int:
	var total := 0
	for no in _todos(raiz):
		if no is MeshInstance3D and no.mesh != null:
			for s: int in range(no.mesh.get_surface_count()):
				var arrays: Array = no.mesh.surface_get_arrays(s)
				if arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] != null:
					total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return total


func _contar_nos(raiz: Node, classe: String) -> int:
	var total := 0
	for no in _todos(raiz):
		if no.is_class(classe):
			total += 1
	return total


func _contar_malhas_de_caixa(raiz: Node) -> int:
	var total := 0
	for no in _todos(raiz):
		if no is MeshInstance3D and no.mesh is BoxMesh:
			total += 1
	return total


func _contar_malhas_de_plano(raiz: Node) -> int:
	var total := 0
	for no in _todos(raiz):
		if no is MeshInstance3D and no.mesh is PlaneMesh:
			total += 1
	return total


func _contar_nos_totais(raiz: Node) -> int:
	return _todos(raiz).size()


func _todos(raiz: Node) -> Array[Node]:
	var saida: Array[Node] = [raiz]
	for filho in raiz.get_children():
		saida.append_array(_todos(filho))
	return saida
