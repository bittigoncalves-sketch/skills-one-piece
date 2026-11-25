class_name DestruicaoDeEstruturas
extends Node
## Gerenciador da destruição de construções por blocos (08/11/2026, pedido do dono: "colocar limite de destruição ao redor do
## jogador e quando ele não está perto as construções voltam ao normal").
##
##  • `golpe(centro, raio)` é a porta única: skill, fruta, soco e espada chamam. Só vale a até `RAIO_DE_DESTRUICAO` do
##    jogador; a construção atingida é "aberta" (vira blocos) no primeiro golpe e as outras ficam intactas, sem custo.
##  • A cada `INTERVALO` s, construção aberta que ficou além de `RAIO_DE_DESTRUICAO + FOLGA` do jogador é RESTAURADA inteira.
##  • Um teto de blocos quebrados por quadro/segundo protege o desempenho de golpes contínuos (rajada, laser).
##
## Peça "construção" = corpo do grupo `assets_transformaveis` cujo modelo `CatalogoDeConstrucoes` reconhece.

const RAIO_DE_DESTRUICAO := 40.0
const FOLGA := 10.0
const INTERVALO := 1.0
## Raio máximo (m) de um golpe: um golpe de 40 blocos de lado não pode varrer 500 mil células de uma vez.
const RAIO_MAX_POR_GOLPE := 6.0
const ABERTURAS_POR_GOLPE := 3          # construções abertas por golpe (a abertura é a parte cara)

var jogador_de: Callable
var _abertas: Array[EstruturaDestrutivel] = []
var _construcoes := {}                  # id do modelo -> bool (cache de CatalogoDeConstrucoes)
var _bib: BibliotecaDeModelos
var _t := 0.0


func _ready() -> void:
	add_to_group("destruicao_de_estruturas")
	_bib = MapaMontador.biblioteca_em_uso()


## Entrada estática para quem golpeia: não faz nada fora do Modo História (sem gerenciador).
static func golpe(arvore: SceneTree, centro: Vector3, raio: float) -> int:
	if arvore == null:
		return 0
	var g := arvore.get_first_node_in_group("destruicao_de_estruturas") as DestruicaoDeEstruturas
	return g._golpe(centro, raio) if g != null else 0


func abertas() -> int:
	_limpar()
	return _abertas.size()


func _golpe(centro: Vector3, raio: float) -> int:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or j.global_position.distance_to(centro) > RAIO_DE_DESTRUICAO:
		return 0
	raio = minf(raio, RAIO_MAX_POR_GOLPE)
	var quebrados := 0
	var abertas_agora := 0
	for no in get_tree().get_nodes_in_group("assets_transformaveis"):
		var corpo := no as StaticBody3D
		if corpo == null or not _e_construcao(corpo):
			continue
		var caixa := _caixa(corpo)
		if caixa.size == Vector3.ZERO or not caixa.grow(raio).has_point(centro):
			continue
		var e := _aberta_de(corpo)
		if e == null:
			if abertas_agora >= ABERTURAS_POR_GOLPE:
				continue
			e = EstruturaDestrutivel.abrir_em(corpo)
			if e == null:
				continue
			_abertas.append(e)
			abertas_agora += 1
		quebrados += e.quebrar(centro, raio)
	return quebrados


func _process(delta: float) -> void:
	_t += delta
	if _t < INTERVALO:
		return
	_t = 0.0
	_limpar()
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	var limite := RAIO_DE_DESTRUICAO + FOLGA
	for e in _abertas.duplicate():
		var longe := j == null or _distancia(_caixa(e.corpo), j.global_position) > limite
		if longe:
			restaurar(e)


## Devolve uma construção aberta ao normal agora.
func restaurar(e: EstruturaDestrutivel) -> void:
	_abertas.erase(e)
	if is_instance_valid(e):
		e.restaurar()


func restaurar_tudo() -> void:
	for e in _abertas.duplicate():
		restaurar(e)


func _limpar() -> void:
	_abertas = _abertas.filter(func(e: EstruturaDestrutivel) -> bool: return is_instance_valid(e) and e.esta_aberta())


func _aberta_de(corpo: StaticBody3D) -> EstruturaDestrutivel:
	for e in _abertas:
		if is_instance_valid(e) and e.corpo == corpo:
			return e
	return null


func _e_construcao(corpo: StaticBody3D) -> bool:
	var modelo := corpo.get_node_or_null("Modelo")
	if modelo == null:
		return false
	var id := str(modelo.get_meta("modelo_id", ""))
	if not _construcoes.has(id):
		_construcoes[id] = not id.is_empty() and _bib != null and _bib.tem(id) \
			and CatalogoDeConstrucoes.e_construcao(id, _bib.categorias_do_modelo(id))
	return _construcoes[id]


## Caixa de mundo do desenho da peça (o `Modelo`), para descartar rápido o que está longe do golpe.
func _caixa(corpo: StaticBody3D) -> AABB:
	if corpo.has_meta("caixa_destrutivel"):
		return corpo.get_meta("caixa_destrutivel")
	var caixa := AABB()
	var primeira := true
	var modelo := corpo.get_node_or_null("Modelo")
	if modelo != null:
		for no in modelo.find_children("*", "MeshInstance3D", true, false):
			var mi := no as MeshInstance3D
			if mi.mesh == null:
				continue
			var c := mi.global_transform * mi.mesh.get_aabb()
			caixa = c if primeira else caixa.merge(c)
			primeira = false
	corpo.set_meta("caixa_destrutivel", caixa)
	return caixa


## Distância do ponto à caixa (0 se dentro).
static func _distancia(caixa: AABB, ponto: Vector3) -> float:
	var perto := ponto.clamp(caixa.position, caixa.end)
	return perto.distance_to(ponto)
