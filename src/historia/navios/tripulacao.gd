class_name Tripulacao
extends RefCounted
# ============================================================================
#  A TRIPULAÇÃO DA VIAGEM (15/10/2026) — quem pode ir no barco e se basta.
#
#  Pedido do dono: ao entrar no barco o jogo pergunta se vai navegar; sim → escolher
#  de 3 a 6 aliados; menos que 3 (ou "não") → volta para a costa. Aqui só a REGRA e os
#  dados (a janela é `JanelaDaTripulacao`, quem executa é `comando.gd`).
#
#  Aliados = os pets do progresso (gaivota, caranguejo, cavalo, domados) + os humanos
#  ganhos na roleta do Barba Negra (`ProgressaoDoPersonagem.recrutados`, ids com o prefixo
#  `humano_` para nunca colidir com o id de um pet).
#
#  Como cada categoria viaja (decisão do dono):
#    AVE      voa em volta do navio / pousa nele (o modo "seguir" da gaivota já faz isso);
#    MARINHA  nada FORA do barco e o segue (ainda não há pet marinho — `categoria()`
#             reconhece a categoria `bestas_do_mar` da biblioteca);
#    TERRESTRE fica no convés;
#    HUMANO   fica no convés e ajuda (Nami: rumo da ilha mais próxima, ver `comando.gd`).
# ============================================================================

const MINIMO := 3
const MAXIMO := 6

enum Categoria { AVE, MARINHA, TERRESTRE, HUMANO }
const NOMES_DA_CATEGORIA := {
	Categoria.AVE: "Ave", Categoria.MARINHA: "Besta marinha",
	Categoria.TERRESTRE: "Terrestre", Categoria.HUMANO: "Tripulante",
}
## Espécies do catálogo que voam (as domadas da loja usam `FichaDeAnimal.voa`).
const AVES: Array[String] = ["gaivota"]
const CATEGORIA_MARINHA := "bestas_do_mar"
const PREFIXO_HUMANO := "humano_"


static func id_do_humano(tripulante: String) -> String:
	return PREFIXO_HUMANO + tripulante


static func e_humano(id: String) -> bool:
	return id.begins_with(PREFIXO_HUMANO)


## `humano_nami` → `nami`.
static func tripulante_de(id: String) -> String:
	return id.trim_prefix(PREFIXO_HUMANO)


static func ficha_recrutada(prog: ProgressaoDoPersonagem, chave: String) -> Dictionary:
	var bruto: Variant = prog.dados_de("recrutas").get(chave, {})
	if not bruto is Dictionary or not bruto.get("modelo") is String or str(bruto.modelo).is_empty(): return {}
	var vida: Variant = bruto.get("vida", 100.0)
	if not (vida is int or vida is float) or not is_finite(float(vida)): return {}
	return {"modelo": bruto.modelo, "nome": str(bruto.get("nome", chave)).left(64), "vida": clampf(float(vida), 1, 1000000)}


## O aliado `id` (pet ou humano) como `{id, nome, especie, categoria}`; `{}` se não é do jogador.
static func aliado(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos, id: String) -> Dictionary:
	if prog == null:
		return {}
	if e_humano(id):
		var t := tripulante_de(id)
		var recrutado := ficha_recrutada(prog, t)
		if not recrutado.is_empty() and recrutado.get("modelo") is String:
			return {"id": id, "nome": str(recrutado.get("nome", t)), "especie": recrutado.modelo, "categoria": Categoria.HUMANO}
		if not prog.tem_recrutado(t):
			return {}
		return {"id": id, "nome": CatalogoDeTripulantes.nome(t), "especie": t, "categoria": Categoria.HUMANO}
	if not prog.tem_pet(id):
		return {}
	var especie := prog.especie_do_pet(id)
	return {"id": id, "nome": prog.nome_do_pet(id), "especie": especie, "categoria": categoria(especie, bib)}


static func categoria(especie: String, bib: BibliotecaDeModelos = null) -> Categoria:
	if AVES.has(especie):
		return Categoria.AVE
	if bib != null and bib.tem(especie):
		if bib.categorias_do_modelo(especie).has(CATEGORIA_MARINHA):
			return Categoria.MARINHA
		var ficha := bib.ficha_de_animal(especie)
		if not ficha.is_empty() and FichaDeAnimal.voa(ficha):
			return Categoria.AVE
	return Categoria.TERRESTRE


## Os aliados que o jogador pode levar: `{id, nome, especie, categoria}` na ordem do
## inventário. O `id` é a chave no progresso (pets) — a mesma que a `Companhia` usa.
static func disponiveis(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos = null) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	if prog == null:
		return lista
	for id in prog.pets:
		var especie := prog.especie_do_pet(str(id))
		lista.append({"id": str(id), "nome": prog.nome_do_pet(str(id)), "especie": especie,
			"categoria": categoria(especie, bib)})
	for t in CatalogoDeTripulantes.ids():
		if prog.tem_recrutado(t):
			lista.append(aliado(prog, bib, id_do_humano(t)))
	for t in prog.dados_de("recrutas"):
		if not str(t).begins_with("recruta_"): continue
		var a := aliado(prog, bib, id_do_humano(str(t)))
		if not a.is_empty(): lista.append(a)
	return lista.filter(func(a: Dictionary): return _vivo(prog, str(a.id)))


static func _vivo(prog: ProgressaoDoPersonagem, id: String) -> bool:
	var d := prog.dados_de("sobrevivencia")
	return not bool(d.get("membros", {}).get(id, {}).get("morto", false)) and not bool(d.get("historico_membros", {}).get(id, {}).get("morto", false))


## A seleção basta para zarpar? (3 a 6 ids distintos e todos disponíveis.)
static func suficiente(ids: Array, prog: ProgressaoDoPersonagem) -> bool:
	return validos(ids, prog).size() >= MINIMO


## Só os ids que existem no progresso, sem repetição e no máximo `MAXIMO`.
static func validos(ids: Array, prog: ProgressaoDoPersonagem) -> Array[String]:
	var saida: Array[String] = []
	for id in ids:
		var s := str(id)
		if not aliado(prog, null, s).is_empty() and _vivo(prog, s) and not saida.has(s) and saida.size() < MAXIMO:
			saida.append(s)
	return saida


## O corpo do aliado para a vitrine 3D da janela: só o modelo (sem lógica, colisão nem
## animação), com a base em y=0 e a maior dimensão em 1 m. `null` se não há modelo.
static func modelo_de_vitrine(especie: String, bib: BibliotecaDeModelos = null) -> Node3D:
	var modelo: Node3D = null
	if CatalogoDeTripulantes.existe(especie):
		var da_biblioteca := CatalogoDeTripulantes.modelo_da_biblioteca(especie)
		if not da_biblioteca.is_empty():
			if bib != null and bib.tem(da_biblioteca):
				modelo = bib.instanciar(da_biblioteca)
		else:
			var feito := CharacterBuilder.build_character(str(CatalogoDeTripulantes.TRIPULANTES[especie]["rig"]))
			modelo = feito.get("node") as Node3D
	elif CatalogoDePets.existe(especie):
		var cena := load(String(CatalogoDePets.ESPECIES[especie]["cena"])) as GDScript
		var caminho: Variant = cena.get_script_constant_map().get("MODELO", "")
		if str(caminho) != "" and ResourceLoader.exists(str(caminho)):
			modelo = (load(str(caminho)) as PackedScene).instantiate() as Node3D
	elif bib != null and bib.tem(especie):
		modelo = bib.instanciar(especie)
	if modelo == null:
		return null
	var caixa := _caixa(modelo)
	var maior := maxf(caixa.size.x, maxf(caixa.size.y, caixa.size.z))
	var embrulho := Node3D.new()
	embrulho.add_child(modelo)
	if maior > 0.0001:
		var k := 1.0 / maior
		modelo.scale *= k
		modelo.position = Vector3(-caixa.get_center().x * k, -caixa.position.y * k, -caixa.get_center().z * k)
	return embrulho


static func _caixa(raiz: Node3D) -> AABB:
	var caixa := AABB()
	var primeiro := true
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var local := raiz.global_transform.affine_inverse() * mi.global_transform if raiz.is_inside_tree() \
			else _transformada_ate(mi, raiz)
		var c := local * mi.mesh.get_aabb()
		caixa = c if primeiro else caixa.merge(c)
		primeiro = false
	return caixa


## A transformada de `no` relativa a `raiz` quando a árvore ainda não existe (fora da cena).
static func _transformada_ate(no: Node3D, raiz: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var atual: Node = no
	while atual != null and atual != raiz:
		if atual is Node3D:
			t = (atual as Node3D).transform * t
		atual = atual.get_parent()
	return t


const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const VENTOS := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]


## A ilha mais próxima de `p`: `{ilha, nome, distancia, rumo}` (`{}` sem ilhas no mapa).
## `caixas` é o `DetectorDeIlha.caixas` (id → placa Rect2).
static func ilha_mais_proxima(caixas: Dictionary, p: Vector3) -> Dictionary:
	var melhor := {}
	for id in caixas:
		var caixa: Rect2 = caixas[id]
		var d := Ilhas.distancia(caixa, p)
		if melhor.is_empty() or d < float(melhor["distancia"]):
			var alvo := Vector2(clampf(p.x, caixa.position.x, caixa.end.x), clampf(p.z, caixa.position.y, caixa.end.y))
			melhor = {"ilha": str(id), "nome": Ilhas.nome(str(id)), "distancia": d,
				"rumo": rumo_para(alvo - Vector2(p.x, p.z))}
	return melhor


## O vento da direção `v` no plano (x, z): norte é −Z (a frente do mundo), leste é +X.
static func rumo_para(v: Vector2) -> String:
	if v.length_squared() < 0.0001:
		return VENTOS[0]
	var graus := fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0)
	return VENTOS[int(round(graus / 45.0)) % 8]


## O inimigo vivo mais perto de `de`, até `raio` m (`null` = nenhum). É o "qualquer inimigo" da
## pistola do Barba Negra e do Z do Crocodile: o grupo `enemy`, o mesmo da mira e dos pets.
static func inimigo_mais_proximo(arvore: SceneTree, de: Vector3, raio: float) -> Node3D:
	var melhor: Node3D = null
	var melhor_d := raio
	for n in arvore.get_nodes_in_group(ModoDoPet.GRUPO_INIMIGO):
		var inimigo := n as Node3D
		if not ModoDoPet.inimigo_vivo(inimigo):
			continue
		var d := de.distance_to(inimigo.global_position)
		if d <= melhor_d:
			melhor_d = d
			melhor = inimigo
	return melhor


## Escala `modelo` (um modelo da biblioteca, com a origem do arquivo) para ter `altura` m, os pés em
## y=0 e o centro em x=z=0 do pai. Devolve o próprio modelo.
static func ajustar_ao_chao(modelo: Node3D, altura: float) -> Node3D:
	var caixa := _caixa(modelo)
	if caixa.size.y <= 0.0001:
		return modelo
	var k := altura / caixa.size.y
	modelo.scale *= k
	modelo.position = Vector3(-caixa.get_center().x * k, -caixa.position.y * k, -caixa.get_center().z * k)
	return modelo
