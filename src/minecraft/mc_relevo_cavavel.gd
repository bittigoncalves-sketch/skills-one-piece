class_name McRelevoCavavel
extends RefCounted
# ============================================================================
#  RELEVO CAVÁVEL (31/10/2026; reescrito sobre a GRADE DE BLOCOS em 11/11/2026, docs/MUNDO_VOXEL_PLANO.md, V2b) — as
#  crateras das técnicas do mod (`BlockDestroyAllDirection`: meteoro, tornado, relâmpago, buraco negro… ~10 ataques)
#  sobre o terreno das ilhas.
#
#  Decisão do dono: CRATERA QUE SE REFAZ. O buraco é real (visual e colisão) e a ilha volta ao normal depois de
#  `TEMPO_PARA_REFAZER`. O mod original deixa o buraco para sempre; refazer protege as ilhas feitas à mão (cidade, loja,
#  vendedores) — a regra do dono, não do mod.
#
#  COMO: o terreno de cada ilha é uma `GradeVoxel` (blocos em seções 16³; o relevo em blocos gera as seções sob demanda).
#    1. `cavar(célula)` só ANOTA o bloco removido (o procedure chama uma vez por bloco, em qualquer ordem);
#    2. no fim do quadro cada bloco anotado vira ar na grade da ilha — só as seções tocadas são refeitas (malha E colisão,
#       numa thread; ~0,3 ms na thread principal numa cratera de 500 blocos, contra ~148 ms da colisão única de antes);
#    3. o corte vira um registro; depois de `TEMPO_PARA_REFAZER` cada bloco volta a ser o que o terreno de base diz (se
#       ainda for ar — o que alguém construiu ali no meio tempo fica) e quem estava no buraco sobe para a superfície.
#  Agora há CAVERNAS de verdade: tirar um bloco do subsolo abre um buraco no subsolo (o modelo de alturas não deixava).
#
#  Limite conhecido (gatilho): construções/árvores sobre o relevo NÃO descem com ele; `RelevoEmBlocos.altura()` (animais, pomar,
#  spawn) continua lendo o terreno de BASE — numa cratera ainda aberta devolve a altura de antes.
# ============================================================================

const TEMPO_PARA_REFAZER := 20 * 180                # ticks (3 min)
const B := GradeVoxel.BLOCO

## Cada corte dura isto (ticks). Variável para o teste não esperar 3 minutos.
var tempo_para_refazer := TEMPO_PARA_REFAZER
var _mundo: McMundo
var _pendentes := {}                                 # Vector3i (bloco removido) → true
var _regras: Array = []                              # [{grade, celulas: Array[Vector3i], expira}]


func _init(mundo: McMundo) -> void:
	_mundo = mundo


## O procedure removeu o bloco `c` (grade do mundo). Aplicado no fim do quadro.
func cavar(c: Vector3i) -> void:
	if _pendentes.is_empty() and _mundo != null and _mundo.arvore != null:
		_aplicar.call_deferred()
	_pendentes[c] = true


func _grades() -> Array[Node]:
	if _mundo == null or _mundo.arvore == null:
		return []
	return _mundo.arvore.get_nodes_in_group(GradeVoxel.GRUPO)


## A grade de terreno cuja coluna contém esta célula (null = fora de toda ilha). Sem isto `setBlock(air)` não tem o que cavar.
func ilha_em(c: Vector3i) -> GradeVoxel:
	for n in _grades():
		var g := n as GradeVoxel
		if g != null and g.gerador != null and g.gerador.contem_coluna(c):
			return g
	return null


## A grade diz se a célula tem bloco? 1 = sim, 0 = não, −1 = a célula não está em ilha nenhuma. Vem dos DADOS (não da física):
## é o que o procedure de destruição precisa para varrer o cubo sem uma consulta de colisão por bloco.
func terra_em(c: Vector3i) -> int:
	var g := ilha_em(c)
	if g == null:
		return -1
	return 1 if g.obter(c) != TiposDeBloco.AR else 0


func _aplicar() -> void:
	if _pendentes.is_empty():
		return
	var t_ap := Cronometro.ini()
	_aplicar_medido()
	Cronometro.fim(&"McMundo.relevo_aplicar", t_ap)


func _aplicar_medido() -> void:
	var por_grade := {}                              # GradeVoxel → Array[Vector3i]
	var sem_ilha := 0
	for c: Vector3i in _pendentes:
		var g := ilha_em(c)
		if g == null:
			sem_ilha += 1
			continue
		if g.obter(c) == TiposDeBloco.AR:
			continue
		if not por_grade.has(g):
			por_grade[g] = [] as Array[Vector3i]
		(por_grade[g] as Array[Vector3i]).append(c)
	_pendentes.clear()
	if sem_ilha > 0:
		Mc._falta("bloco", "cavar_fora_de_ilha")
	for g: GradeVoxel in por_grade:
		var celulas: Array[Vector3i] = por_grade[g]
		for c in celulas:
			g.definir(c, TiposDeBloco.AR)
		_regras.append({"grade": g, "celulas": celulas, "expira": _mundo.tempo_de_jogo + tempo_para_refazer})


## Um tick do mundo: cortes vencidos se desfazem.
func tick(agora: int) -> void:
	if _regras.is_empty():
		return
	var vencidas: Array = []
	for reg: Dictionary in _regras:
		if agora >= int(reg.expira):
			vencidas.append(reg)
	for reg: Dictionary in vencidas:
		_regras.erase(reg)
		var g := reg.grade as GradeVoxel
		if not is_instance_valid(g) or g.gerador == null:
			continue
		var refeitas := {}
		var secoes := {}
		for c: Vector3i in reg.celulas:
			if g.obter(c) == TiposDeBloco.AR:            # o que foi construído ali no meio tempo fica
				var base := g.gerador.valor_em(c)
				if base != TiposDeBloco.AR:
					g.definir(c, base)
					refeitas[c] = true
					secoes[GradeVoxel.secao_de(c)] = true
		if not refeitas.is_empty():
			_subir_quem_ficou_dentro(g, refeitas)
		for sc: Vector3i in secoes:
			g.compactar(sc)                               # voltou ao terreno de base: a seção deixa de ser dado guardado


## Refeitura em curso ou pedida? (para os testes esperarem).
func ocupado() -> bool:
	if not _pendentes.is_empty():
		return true
	for n in _grades():
		var g := n as GradeVoxel
		if g != null and not g.pronto():
			return true
	return false


## A cratera se refez com gente dentro: quem ficou numa célula que voltou a ser bloco sobe para a primeira célula livre acima.
func _subir_quem_ficou_dentro(g: GradeVoxel, refeitas: Dictionary) -> void:
	var arvore := _mundo.arvore
	var candidatos: Array = arvore.get_nodes_in_group("player") + arvore.get_nodes_in_group(AlvosDeGolpe.GRUPO) \
		+ arvore.get_nodes_in_group("npc")
	for n in candidatos:
		var corpo := n as CharacterBody3D
		if corpo == null or not is_instance_valid(corpo):
			continue
		var p := corpo.global_position
		var cel := GradeVoxel.celula_em(p + Vector3.UP * 0.05)
		if not refeitas.has(cel) and not refeitas.has(cel + Vector3i.UP):
			continue
		while g.obter(cel) != TiposDeBloco.AR and cel.y < 4096:
			cel += Vector3i.UP
		corpo.global_position = Vector3(p.x, float(cel.y) * B + 0.05, p.z)
		corpo.velocity.y = maxf(corpo.velocity.y, 0.0)
