extends Node
# ============================================================================
#  DESENHO POR DISTÂNCIA DAS ILHAS (08/10/2026, docs/ILHA_DOS_MACACOS_PLANO.md, etapa 4).
#
#  Pedido do dono: "quando o jogador sair de uma ilha e se afastar a um determinado
#  ponto a ilha passa a ser minimamente rendenizada, animais deixam de rendenizar,
#  construções se tornam blocos e assim por diante, quando não é possivel mais ver a
#  ilha ela para de rendenizar".
#
#  Cada ilha (`Ilhas`) tem um estado, pela distância da câmera até a PLACA dela:
#    PERTO  (até 400 m) ... tudo como sempre (com 250 m a troca aparecia: a vila ainda
#                           nítida a ~350 m virava caixas — fotos de 08/10/2026);
#    LONGE  (até 1,9 km) .. o relevo e os penhascos ficam; construções e pedras grandes
#                           viram BLOCOS na cor média do modelo; árvores viram COPAS
#                           simples (dois MultiMesh por ilha = 2 chamadas de desenho);
#                           objetos pequenos, NPCs e inimigos somem e param de processar;
#    OCULTA (além) ........ nada da ilha é desenhado (nem o fundo do mar dela). 1,9 km:
#                           a névoa (densidade 0,002) já cobre ~98 % da cor.
#  Os animais já somem sozinhos além de 80 m (`PopulacaoDeAnimais`). Os BARCOS ficam de
#  fora: andam entre as ilhas (um barco atracado nos macacos não é da ilha inicial).
#  Só muda alguma coisa quando o estado de uma ilha muda (folga de 15 m contra pisca);
#  a cada meio segundo é só a conta da distância.
#  O que NÃO faz: tirar da memória (os modelos continuam carregados) nem da física.
#  Gatilho para descarregar de verdade: memória medida acima do orçamento, ou 4+ ilhas.
# ============================================================================

signal mudou_estado(ilha: String, estado: int)

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
enum Estado { PERTO, LONGE, OCULTA }
const PERTO_ATE := 400.0
const VISIVEL_ATE := 1900.0
const FOLGA := 15.0
const INTERVALO := 0.5
## Peças até esta distância da placa são da ilha (praia, cais, construções do porto).
const MARGEM_DA_ILHA := 120.0
## Construção: base de pelo menos 5 m e 2,5 m de altura (o resto é "miúdo").
const BASE_DE_CONSTRUCAO := 5.0
const ALTURA_DE_CONSTRUCAO := 2.5
const CATEGORIAS_DE_ENTIDADE := ["inimigos", "npcs", "pets", "montarias", "bestas_do_mar", "boss", "animais"]
const PALAVRAS_DE_ARVORE := ["tree", "palm", "pine", "arvore", "pinheiro", "cerejeira", "coqueiro"]
const PALAVRAS_DE_MIUDO := ["dock", "pier", "ponte", "bridge"]
## Cor de parte com textura (ver `_cor_do_modelo`).
const COR_COPA := Color("#4f7040")
const COR_PEDRA := Color("#7d786c")

var jogador_de: Callable
## Distância até a placa em que a ilha ainda é desenhada por inteiro. A `ZonaDeCombate` a reduz enquanto o jogador está em combate.
var perto_ate := PERTO_ATE
var _ilhas := {}              # id → {caixa, estado, chao, grandes, arvores, miudos, entidades, blocos, copas}
var _relogio := 0.0
static var _cores := {}       # modelo → cor média (sRGB)


## Classifica as peças do mapa montado (`raiz`) por ilha e monta os substitutos (ocultos).
func ligar(raiz: Node3D, mapa: Dictionary, bib: BibliotecaDeModelos, caixas: Dictionary) -> void:
	_ligar_pecas(raiz, mapa.get("pecas", []), bib, caixas, caixas.keys())


## Carga por distância: cria a tabela vazia de cada ilha (o chão — relevo e fundo do mar — se registra em `registrar`; as peças só
## quando a ilha é montada, em `ligar_ilha`).
func preparar(caixas: Dictionary) -> void:
	for id in caixas:
		if not _ilhas.has(id):
			_ilhas[id] = {"caixa": caixas[id], "estado": Estado.PERTO, "chao": [], "grandes": [], "arvores": [],
				"miudos": [], "entidades": [], "blocos": null, "copas": null}


## Carga por distância: liga SÓ as peças desta ilha (já montadas na `raiz`). `caixas` = as de todas as ilhas (a classificação por
## proximidade é a mesma de `ligar`).
func ligar_ilha(id: String, raiz: Node3D, pecas: Array, bib: BibliotecaDeModelos, caixas: Dictionary) -> void:
	_ligar_pecas(raiz, pecas, bib, caixas, [id])


## A ilha foi descarregada: libera os substitutos (blocos e copas) e esquece o que era das peças. O chão (relevo, fundo do mar)
## continua: ele nunca é descarregado.
func descarregar_ilha(id: String) -> void:
	var ilha: Dictionary = _ilhas.get(id, {})
	if ilha.is_empty():
		return
	for sub in [ilha.get("blocos"), ilha.get("copas")]:
		if sub != null and is_instance_valid(sub):
			sub.queue_free()
	ilha["blocos"] = null
	ilha["copas"] = null
	for grupo in ["grandes", "arvores", "miudos", "entidades"]:
		ilha[grupo] = []
	ilha["estado"] = Estado.PERTO


func _ligar_pecas(raiz: Node3D, pecas: Array, bib: BibliotecaDeModelos, caixas: Dictionary, quais: Array) -> void:
	for id in quais:
		if not _ilhas.has(id):         # o relevo e o fundo do mar já podem ter registrado o chão desta ilha
			_ilhas[id] = {"caixa": caixas[id], "estado": Estado.PERTO, "chao": [], "grandes": [], "arvores": [],
				"miudos": [], "entidades": [], "blocos": null, "copas": null}
	var dados_grandes := {}
	var dados_arvores := {}
	for id in quais:
		dados_grandes[id] = []
		dados_arvores[id] = []
	for p: Dictionary in pecas:
		var no := raiz.get_node_or_null(NodePath(String(p["id"]))) as Node3D
		# Só as peças do montador (StaticBody sem script): inimigo, ninho e NPC viram
		# nós próprios e entram por `registrar`.
		if no == null or no.get_script() != null or no.is_queued_for_deletion():
			continue
		var ilha := Ilhas.ilha_em(caixas, p["posicao"], MARGEM_DA_ILHA)
		if ilha.is_empty() or not (ilha in quais):
			continue
		var tipo := classificar(p, bib)
		match tipo:
			"chao":
				_ilhas[ilha]["chao"].append(no)
			"construcao":
				_ilhas[ilha]["grandes"].append(no)
				dados_grandes[ilha].append([p, _cor_do_modelo(no, String(p["modelo"]), COR_PEDRA)])
			"arvore":
				_ilhas[ilha]["arvores"].append(no)
				dados_arvores[ilha].append([p, _cor_do_modelo(no, String(p["modelo"]), COR_COPA)])
			"miudo":
				_ilhas[ilha]["miudos"].append(no)
	for id in quais:
		_ilhas[id]["blocos"] = _substituto("Blocos_" + id, dados_grandes[id], false)
		_ilhas[id]["copas"] = _substituto("Copas_" + id, dados_arvores[id], true)
		if int(_ilhas[id]["estado"]) != Estado.PERTO:      # ilha carregada já longe: as peças novas nascem no estado dela
			_aplicar(_ilhas[id], int(_ilhas[id]["estado"]))


## NPCs, inimigos, ninhos e o fundo do mar: entram na ilha onde estão agora.
func registrar(nos: Array) -> void:
	var caixas := {}
	for id in _ilhas:
		caixas[id] = _ilhas[id]["caixa"]
	for no in nos:
		if not (no is Node3D) or not is_instance_valid(no):
			continue
		var n := no as Node3D
		# O corpo do relevo em blocos fica na origem: a ilha vem na meta.
		var ilha := str(n.get_meta("ilha")) if n.has_meta("ilha") else Ilhas.ilha_em(caixas, n.global_position, MARGEM_DA_ILHA)
		if ilha.is_empty() or not _ilhas.has(ilha):
			continue
		if n is FundoDoMar or RelevoEmBlocos.e_relevo(n):
			_ilhas[ilha]["chao"].append(n)       # o fundo só some com a ilha OCULTA
		else:
			_ilhas[ilha]["entidades"].append(n)


## "chao" (relevo, placa, penhascos: ficam até OCULTA), "construcao", "arvore",
## "miudo", "entidade" ou "ignorar" (áreas de animais e barcos).
static func classificar(p: Dictionary, bib: BibliotecaDeModelos) -> String:
	match String(p.get("tipo", "")):
		"area_animais":
			return "ignorar"
		"modelo":
			pass
		_:
			return "chao"
	var id_modelo := String(p.get("modelo", ""))
	var modelo := id_modelo.to_lower()
	# Barcos andam entre as ilhas; o ANCORADO (cenário, `perfil_barco.gd` `ancorado`) é da ilha.
	if (p.get("grupo", "") == "navios" or (bib != null and not bib.ficha_de_navio(id_modelo).is_empty())) \
			and not String(p.get("grupo", "")).ends_with("_ancorados"):
		return "ignorar"
	var categorias: Array = bib.info(id_modelo).get("categorias", []) if bib != null and bib.tem(id_modelo) else []
	if modelo.begins_with("npc_") or modelo == "bandido" or categorias.any(func(c): return c in CATEGORIAS_DE_ENTIDADE):
		return "entidade"
	if modelo.begins_with("mountain"):
		return "chao"
	# Naufrágio (14/10/2026): no fundo, só aparece mergulhando — de longe some como
	# miúdo, em vez de virar um bloco de construção colorido no fundo do mar.
	if "naufragios" in categorias:
		return "miudo"
	var t: Vector3 = p.get("tamanho", Vector3.ONE)
	if PALAVRAS_DE_ARVORE.any(func(w: String) -> bool: return w in modelo) or "arvores" in categorias:
		return "arvore" if t.y >= 2.0 else "miudo"
	if PALAVRAS_DE_MIUDO.any(func(w: String) -> bool: return w in modelo):
		return "miudo"
	if maxf(t.x, t.z) >= BASE_DE_CONSTRUCAO and t.y >= ALTURA_DE_CONSTRUCAO:
		return "construcao"
	return "miudo"


## O estado para a distância `d` (m até a placa), vindo de `atual`. Folga nos dois
## sentidos: parado na borda de um limite, o estado não fica piscando.
static func proximo_estado(atual: int, d: float, perto_ate := PERTO_ATE) -> int:
	if d > VISIVEL_ATE + (FOLGA if atual != Estado.OCULTA else -FOLGA):
		return Estado.OCULTA
	if d > perto_ate + (FOLGA if atual == Estado.PERTO else -FOLGA):
		return Estado.LONGE
	return Estado.PERTO


func estado_de(ilha: String) -> int:
	return int(_ilhas.get(ilha, {}).get("estado", Estado.PERTO))


func _process(delta: float) -> void:
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = INTERVALO
	atualizar()


func atualizar() -> void:
	var cam := get_viewport().get_camera_3d() if get_viewport() else null
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if cam == null and j == null:
		return
	var ref := cam.global_position if cam != null else j.global_position
	for id in _ilhas:
		var ilha: Dictionary = _ilhas[id]
		var atual: int = ilha["estado"]
		var novo := proximo_estado(atual, Ilhas.distancia(ilha["caixa"], ref), perto_ate)
		if novo != atual:
			ilha["estado"] = novo
			_aplicar(ilha, novo)
			mudou_estado.emit(id, novo)


func _aplicar(ilha: Dictionary, estado: int) -> void:
	var perto := estado == Estado.PERTO
	for no in ilha["chao"]:
		if is_instance_valid(no):
			no.visible = estado != Estado.OCULTA
	for grupo in ["grandes", "arvores", "miudos"]:
		for no in ilha[grupo]:
			if is_instance_valid(no):
				no.visible = perto
	for sub in [ilha["blocos"], ilha["copas"]]:
		if sub != null:
			sub.visible = estado == Estado.LONGE
	for no in ilha["entidades"]:
		if is_instance_valid(no):
			_entidade(no, perto)


## Some e para de processar; ao voltar, devolve EXATAMENTE como estava (um inimigo
## morto esperando renascer continua escondido).
func _entidade(no: Node3D, perto: bool) -> void:
	if no.has_meta(Povoamento.META):
		return          # criatura de outra ilha (latente): o povoamento manda, não o LOD
	if perto:
		if no.has_meta("lod_visivel"):
			no.visible = no.get_meta("lod_visivel")
			no.process_mode = no.get_meta("lod_processo")
			no.remove_meta("lod_visivel")
			no.remove_meta("lod_processo")
	elif not no.has_meta("lod_visivel"):
		no.set_meta("lod_visivel", no.visible)
		no.set_meta("lod_processo", no.process_mode)
		no.visible = false
		no.process_mode = Node.PROCESS_MODE_DISABLED


## Um MultiMesh por ilha: caixas (construções) ou copas (árvores), oculto até LONGE.
func _substituto(nome: String, dados: Array, copa: bool) -> MultiMeshInstance3D:
	if dados.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	if copa:
		var esfera := SphereMesh.new()
		esfera.radial_segments = 6
		esfera.rings = 3
		mm.mesh = esfera
	else:
		mm.mesh = BoxMesh.new()
	mm.instance_count = dados.size()
	for i in dados.size():
		var p: Dictionary = dados[i][0]
		var t: Vector3 = p["tamanho"]
		var base := Basis.from_euler((p["rotacao_graus"] as Vector3) * (PI / 180.0))
		var centro: Vector3 = p["posicao"]
		var escala := t
		if copa:
			# A copa ocupa os 3/4 de cima da árvore (o tronco some de longe).
			escala = Vector3(t.x * 0.8, t.y * 0.75, t.z * 0.8)
			centro += Vector3.UP * t.y * 0.125
		mm.set_instance_transform(i, Transform3D(base.scaled(escala), centro))
		mm.set_instance_color(i, dados[i][1])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	var mi := MultiMeshInstance3D.new()
	mi.name = nome
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	return mi


## Cor média do modelo (pesada pelo número de vértices de cada parte), uma vez por
## modelo. Parte com TEXTURA entra com `padrao` (copa ou pedra): muitos modelos usam uma
## paleta ("Atlas") quase toda branca com quadradinhos de cor — a média da textura dava
## branco, e a leitura nos UVs dava bege nas pedras e preto nas folhas recortadas
## (medido 08/10/2026). De longe, na névoa, a cor da categoria é o que se lê.
static func _cor_do_modelo(no: Node3D, modelo: String, padrao: Color) -> Color:
	if _cores.has(modelo):
		return _cores[modelo]
	var soma := Vector3.ZERO
	var peso := 0.0
	for mi in no.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null or not (mi as MeshInstance3D).visible:
			continue
		for s in m.get_surface_count():
			var mat := (mi as MeshInstance3D).get_active_material(s) as BaseMaterial3D
			if mat == null:
				continue
			var c := padrao if mat.albedo_texture != null else mat.albedo_color
			var w := float(maxi(m.surface_get_array_len(s), 1)) if m is ArrayMesh else 1.0
			soma += Vector3(c.r, c.g, c.b) * w
			peso += w
	var cor := Color(soma.x / peso, soma.y / peso, soma.z / peso) if peso > 0.0 else padrao
	_cores[modelo] = cor
	return cor
