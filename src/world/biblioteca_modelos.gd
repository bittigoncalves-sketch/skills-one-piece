class_name BibliotecaDeModelos
extends RefCounted
# ============================================================================
#  BIBLIOTECA DE MODELOS — os .glb importados pela LOJA do editor de mapa.
#
#  Mora em `src/world/` porque o JOGO também precisa dela: uma peça `modelo` no
#  mapa do Modo História aponta para um id daqui.
#
#    mapas/modelos/catalogo.json   quem é quem (id, nome exibido, medidas)
#    mapas/modelos/<id>.glb        a CÓPIA do arquivo importado (decisão do dono:
#                                  o mapa não depende do original no computador)
#
#  COMO UM MODELO É CARREGADO (duas portas, nesta ordem)
#  ----------------------------------------------------
#  1. `ResourceLoader` — quando o editor do Godot já importou o .glb. É o único
#     caminho que existe num jogo EXPORTADO (lá o .glb cru não vai no pacote).
#  2. `GLTFDocument` em tempo de execução — quando o arquivo acabou de ser
#     importado pela loja e o editor do Godot ainda não o viu (o caso normal
#     rodando por `./jogar.sh`).
#  ⚠️ NÃO VALIDADO EM EXPORTAÇÃO: o projeto não tem export templates instalados.
#  Gatilho: na primeira exportação, abrir um mapa com modelo no jogo exportado.
#
#  O .glb é só dado (malha, material, textura) — não executa código. É por isso
#  que ele pode vir de qualquer pasta, ao contrário de uma cena .tscn/.scn.
#
#  CATEGORIAS (14/09/2026 → 16/09/2026, decisão do dono): funcionam como ETIQUETA —
#  um modelo pode estar em várias ("Animal" e "Inimigo"). Só organizam a loja; não
#  mudam nada no jogo. Catálogo antigo, sem o campo, abre com tudo "sem categoria".
#  (Exceção que o jogo lê: "inimigos" — ver `InimigoDoMapa`.)
#
#  COMPORTAMENTO (30/09/2026): campo OPCIONAL que diz ao jogo que a peça não é só
#  um modelo — ex. "boneco_de_duelo" = o inimigo que luta. A biblioteca guarda e
#  devolve o texto; quem interpreta é o jogo (`InimigoDoMapa`). A loja não mostra
#  nem edita o campo, mas o preserva ao gravar.
#
#  TAMANHO PADRÃO (30/09/2026, decisão do dono): a maioria dos modelos chega MINÚSCULA
#  (casa de 1,5 m para um personagem de 1,6 m). `tamanho_padrao` é o tamanho em que o
#  modelo ENTRA no mapa — arrastado da loja ou posto pelo gerador da ilha. Ausente =
#  o tamanho do arquivo (o que sempre foi). A tabela que o preencheu, por tipo e medida
#  contra o jogador, é `tools/mapa_ilha/aplicar_tamanhos_padrao.gd`.
#
#  NAVIO (30/09/2026): ficha de propriedades dos barcos da categoria `navios`
#  (`FichaDeNavio`). Opcional; inválida conta como ausente.
#
#  MALHA DE COLISÃO PRÓPRIA (01/10/2026): se o .glb tiver uma malha cujo nome começa
#  com "Colisao", SÓ ela vira a colisão do modelo, e ela não aparece. Motivo medido: a
#  ponte do rio com colisão = malha inteira travava o jogador (colisor CAIXA) no meio
#  do deck — travessas e capeamento encostavam por baixo no plano do piso, e o
#  GodotPhysics trata cada triângulo sozinho: a aresta de cima de uma face vertical
#  rente ao piso vira parede de altura zero. Sem "Colisao", nada muda.
#
#  COLISÃO EM PARTES CONVEXAS (01/10/2026, decisão do dono para as CONSTRUÇÕES):
#  catálogo com "colisao": "partes" + arquivo `<id>.colisao.json` ao lado do .glb, com
#  os pontos de poucos volumes convexos que envolvem a estrutura (decomposição V-HACD
#  feita UMA vez por `tools/mapa_ilha/gerar_colisao_de_construcoes.gd` — ~1 s por
#  modelo, lento demais para abrir o mapa). O arquivo guarda o SHA do .glb: modelo
#  reimportado com outro conteúdo invalida as partes e a colisão volta a ser a malha
#  (com aviso) até gerar de novo. Sem o campo, nada muda.
#
#  Reimportar um modelo que já existe (`adicionar` com o mesmo id) PRESERVA o
#  tamanho padrão e a ficha quando a entrada nova não os traz: eles descrevem o
#  modelo no mundo, não o arquivo.
# ============================================================================

signal mudou

const RAIZ_PADRAO := "res://mapas/modelos"
const ARQUIVO_CATALOGO := "catalogo.json"
const FORMATO := "skills-one-piece/modelos"
const VERSAO := 1
const MAX_NOME := 60
const MAX_NOME_CATEGORIA := 40
# Acima disto a colisão vira a caixa do modelo: uma malha côncava de centenas de
# milhares de triângulos pesa na física do mapa inteiro. Número de partida, não
# medido — gatilho: primeiro modelo que precise de colisão fina acima dele.
const MAX_TRIANGULOS_COLISAO := 150000

static var _padrao: BibliotecaDeModelos = null

var raiz: String

var _modelos := {}                  # id -> entrada do catálogo (normalizada)
var _ordem: Array[String] = []
# id -> PackedScene. Nas DUAS portas: o que o GLTFDocument gera é empacotado numa
# PackedScene em memória. Guardar o nó solto fora da árvore vazaria objetos ao
# fechar o jogo ("ObjectDB instances leaked").
var _cenas := {}
var _clipes_extra := {}      # id -> AnimationLibrary (ou null), ver _acoplar_clipes
var _faces := {}                    # id -> PackedVector3Array no espaço do modelo
# "id|tamanho" -> Shape3D já esticada. Cem árvores iguais dividem UMA forma: montar
# a trimesh (a árvore da física dentro dela) por peça custava ~1 ms cada, e a Ilha
# Inicial tem centenas (medido em 30/09/2026). A forma nunca é alterada depois de
# criada — outra peça com outro tamanho ganha outra forma.
var _formas := {}
var _partes := {}                   # id -> Array[PackedVector3Array] (pontos no espaço do modelo)
const FORMATO_COLISAO := "skills-one-piece/colisao"
const MAX_PARTES := 64
var _categorias: Array[Dictionary] = []   # [{id, nome}], na ordem de criação
var _regex_id := RegEx.create_from_string(MapaArquivo.PADRAO_ID)


## A biblioteca do projeto, carregada uma vez. Teste troca por uma própria.
static func padrao() -> BibliotecaDeModelos:
	if _padrao == null:
		_padrao = BibliotecaDeModelos.new(RAIZ_PADRAO)
	return _padrao


func _init(caminho_raiz: String) -> void:
	raiz = caminho_raiz
	recarregar()


# ------------------------------------------------------------------ catálogo
func recarregar() -> void:
	_modelos.clear()
	_ordem.clear()
	_categorias.clear()
	_cenas.clear()
	_clipes_extra.clear()
	_faces.clear()
	_formas.clear()
	_partes.clear()
	var caminho := raiz.path_join(ARQUIVO_CATALOGO)
	if not FileAccess.file_exists(caminho):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(caminho)) != OK or not (json.data is Dictionary) \
			or json.data.get("formato") != FORMATO:
		push_error("[Biblioteca] catálogo ilegível: %s" % caminho)
		return
	# Categorias ANTES dos modelos: a entrada de modelo só guarda categoria que existe.
	var cats: Variant = json.data.get("categorias", [])
	if cats is Array:
		for bruta in cats:
			if bruta is Dictionary and _regex_id.search(str(bruta.get("id", ""))) != null \
					and not tem_categoria(str(bruta["id"])):
				var nome_cat := str(bruta.get("nome", "")).strip_edges().left(MAX_NOME_CATEGORIA)
				_categorias.append({"id": str(bruta["id"]), "nome": nome_cat if not nome_cat.is_empty() else str(bruta["id"])})
	var lista: Variant = json.data.get("modelos")
	if not (lista is Array):
		return
	for bruto in lista:
		var entrada := _normalizar(bruto)
		if entrada.is_empty():
			push_warning("[Biblioteca] entrada inválida ignorada: %s" % str(bruto).left(120))
			continue
		_modelos[entrada["id"]] = entrada
		_ordem.append(entrada["id"])


func ids() -> Array[String]:
	return _ordem.duplicate()


func tem(id: String) -> bool:
	return _modelos.has(id)


func info(id: String) -> Dictionary:
	return (_modelos[id] as Dictionary).duplicate(true)


func caminho_do_arquivo(id: String) -> String:
	return raiz.path_join(id + ".glb")


## Id do modelo com este conteúdo, ou "" — importar o mesmo arquivo duas vezes
## não cria duas cópias.
func id_por_sha(sha256: String) -> String:
	for id in _ordem:
		if _modelos[id]["sha256"] == sha256:
			return id
	return ""


## Id a partir do nome do arquivo: minúsculas, sem acento, só A-Z a-z 0-9 _ -.
func novo_id(nome_do_arquivo: String) -> String:
	var limpo := _limpar_id(nome_do_arquivo.get_basename(), "modelo")
	var id := limpo
	var n := 2
	while _modelos.has(id) or FileAccess.file_exists(caminho_do_arquivo(id)):
		id = "%s_%d" % [limpo, n]
		n += 1
	return id


func adicionar(entrada: Dictionary) -> Error:
	var normal := _normalizar(entrada)
	if normal.is_empty():
		return ERR_INVALID_DATA
	if _modelos.has(normal["id"]):
		# Reimportado: a malha pode ter mudado, as formas guardadas também.
		_esquecer_formas(normal["id"])
		var antigo: Dictionary = _modelos[normal["id"]]
		for campo in ["tamanho_padrao", "navio", "colisao", "animal", "atravessavel", "escalavel", "frutifera"]:
			if not entrada.has(campo) and antigo.has(campo):
				normal[campo] = antigo[campo]
	_modelos[normal["id"]] = normal
	if not _ordem.has(normal["id"]):
		_ordem.append(normal["id"])
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


## Troca só o nome EXIBIDO. O id fica: é ele que os mapas guardam.
func renomear(id: String, nome: String) -> String:
	nome = nome.strip_edges()
	if not tem(id):
		return "o modelo \"%s\" não existe" % id
	if nome.is_empty() or nome.length() > MAX_NOME:
		return "o nome precisa ter de 1 a %d caracteres" % MAX_NOME
	_modelos[id]["nome"] = nome
	var erro := salvar_catalogo()
	mudou.emit()
	return "" if erro == OK else "não foi possível gravar o catálogo (%s)" % error_string(erro)


## Apaga o .glb copiado e a entrada. Peças de mapa que usavam viram marcador.
func remover(id: String) -> Error:
	if not tem(id):
		return ERR_DOES_NOT_EXIST
	var arquivo := ProjectSettings.globalize_path(caminho_do_arquivo(id))
	if FileAccess.file_exists(caminho_do_arquivo(id)):
		DirAccess.remove_absolute(arquivo)
	_modelos.erase(id)
	_ordem.erase(id)
	_cenas.erase(id)
	_clipes_extra.erase(id)
	_faces.erase(id)
	_esquecer_formas(id)
	if FileAccess.file_exists(caminho_das_partes(id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_das_partes(id)))
	var clipes := raiz.path_join(id + ".clipes.res")
	if FileAccess.file_exists(clipes):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(clipes))
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


# ---------------------------------------------------------------- categorias
func categorias() -> Array[Dictionary]:
	var copia: Array[Dictionary] = []
	for c in _categorias:
		copia.append(c.duplicate())
	return copia


func tem_categoria(id: String) -> bool:
	return _indice_categoria(id) >= 0


func nome_da_categoria(id: String) -> String:
	var i := _indice_categoria(id)
	return str(_categorias[i]["nome"]) if i >= 0 else id


## {ok, id, erro}. Nome repetido (sem diferenciar maiúscula) é recusado: duas
## "Animal" na lista seriam indistinguíveis no filtro.
func criar_categoria(nome: String) -> Dictionary:
	nome = nome.strip_edges()
	var motivo := _motivo_nome_categoria(nome, "")
	if not motivo.is_empty():
		return {"ok": false, "id": "", "erro": motivo}
	var base := _limpar_id(nome, "categoria")
	var id := base
	var n := 2
	while tem_categoria(id):
		id = "%s_%d" % [base, n]
		n += 1
	_categorias.append({"id": id, "nome": nome})
	var erro := salvar_catalogo()
	mudou.emit()
	return {"ok": erro == OK, "id": id, "erro": "" if erro == OK else error_string(erro)}


func renomear_categoria(id: String, nome: String) -> String:
	nome = nome.strip_edges()
	var i := _indice_categoria(id)
	if i < 0:
		return "a categoria não existe"
	var motivo := _motivo_nome_categoria(nome, id)
	if not motivo.is_empty():
		return motivo
	_categorias[i]["nome"] = nome
	var erro := salvar_catalogo()
	mudou.emit()
	return "" if erro == OK else error_string(erro)


## Apaga só a ETIQUETA: os modelos continuam na loja, sem ela.
func apagar_categoria(id: String) -> Error:
	var i := _indice_categoria(id)
	if i < 0:
		return ERR_DOES_NOT_EXIST
	_categorias.remove_at(i)
	for mid in _ordem:
		(_modelos[mid]["categorias"] as Array).erase(id)
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


## Põe (`dentro = true`) ou tira os modelos da categoria, gravando uma vez só.
func marcar_categoria(modelos: Array[String], categoria: String, dentro: bool) -> Error:
	if not tem_categoria(categoria):
		return ERR_DOES_NOT_EXIST
	for mid in modelos:
		if not tem(mid):
			continue
		var lista: Array = _modelos[mid]["categorias"]
		if dentro and not lista.has(categoria):
			lista.append(categoria)
		elif not dentro:
			lista.erase(categoria)
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


## O tamanho em que o modelo entra no mapa (loja e gerador). Sem padrão próprio,
## o tamanho do arquivo.
func tamanho_padrao(id: String) -> Vector3:
	if not tem(id):
		return Vector3.ONE
	return _modelos[id].get("tamanho_padrao", _modelos[id]["tamanho"])


## Grava o tamanho padrão (null tira). Recusa tamanho não positivo.
func definir_tamanho_padrao(id: String, tamanho: Variant) -> Error:
	if not tem(id):
		return ERR_DOES_NOT_EXIST
	if tamanho == null:
		_modelos[id].erase("tamanho_padrao")
	else:
		var t: Vector3 = tamanho
		if t.x <= 0.0 or t.y <= 0.0 or t.z <= 0.0 or not t.is_finite():
			return ERR_INVALID_PARAMETER
		_modelos[id]["tamanho_padrao"] = t
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


## ATRAVESSÁVEL (01/10/2026, decisão do dono para a plantação `crops`): a peça deste
## modelo entra no mapa com a colisão DESLIGADA — jogador e bichos passam por dentro.
## É só o padrão da inserção, como o tamanho padrão: quem decide é a caixa "Colisão"
## da peça (assim o editor nunca mostra colisão ligada numa peça que não colide).
func atravessavel(id: String) -> bool:
	return tem(id) and bool(_modelos[id].get("atravessavel", false))


## ESCALÁVEL (03/10/2026, decisão do dono — fatia 3 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md):
## a peça deste modelo aceita ESCALADA frontal. O mapa não guarda o campo: o
## `MapaMontador` o lê daqui ao montar a peça e põe a meta `escalavel` no corpo, que
## é o que `src/player/escalada.gd` consulta. Construções, rochas e muros vêm
## marcados (`tools/mapa_ilha/aplicar_escalaveis.gd`); o resto se marca na loja.
func escalavel(id: String) -> bool:
	return tem(id) and bool(_modelos[id].get("escalavel", false))


## Marca ou desmarca vários modelos de uma vez (uma gravação só).
func definir_escalavel(ids: Array[String], sim: bool) -> Error:
	for id in ids:
		if not tem(id):
			return ERR_DOES_NOT_EXIST
	for id in ids:
		if sim:
			_modelos[id]["escalavel"] = true
		else:
			_modelos[id].erase("escalavel")
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


func definir_atravessavel(id: String, sim: bool) -> Error:
	if not tem(id):
		return ERR_DOES_NOT_EXIST
	if sim:
		_modelos[id]["atravessavel"] = true
	else:
		_modelos[id].erase("atravessavel")
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


## FRUTÍFERA (01/10/2026): as frutas (ids de modelos da loja, categoria "frutas") que a
## árvore pode dar — uma delas é sorteada por árvore no jogo. Os pontos onde elas
## ficam penduradas vêm do próprio .glb (vazios `Fruta_0..N` na superfície da copa,
## gerados por tools/blender/preparar_natureza.py). [] = não dá fruta.
func frutas_da_arvore(id: String) -> Array[String]:
	var lista: Array[String] = []
	if tem(id):
		for f in _modelos[id].get("frutifera", []):
			lista.append(String(f))
	return lista


func definir_frutifera(id: String, frutas: Array) -> Error:
	if not tem(id):
		return ERR_DOES_NOT_EXIST
	var limpa: Array[String] = []
	for f in frutas:
		if not (f is String) or _regex_id.search(f) == null:
			return ERR_INVALID_PARAMETER
		limpa.append(f)
	if limpa.is_empty():
		_modelos[id].erase("frutifera")
	else:
		_modelos[id]["frutifera"] = limpa
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


## A ficha de navio do modelo ({} = não é navio / sem ficha).
func ficha_de_navio(id: String) -> Dictionary:
	return (_modelos[id].get("navio", {}) as Dictionary).duplicate() if tem(id) else {}


## Grava a ficha ({} tira). Ficha inválida é recusada inteira.
func definir_ficha_de_navio(id: String, ficha: Dictionary) -> Error:
	if not tem(id):
		return ERR_DOES_NOT_EXIST
	if ficha.is_empty():
		_modelos[id].erase("navio")
	else:
		var normal := FichaDeNavio.normalizar(ficha)
		if normal.is_empty():
			return ERR_INVALID_PARAMETER
		_modelos[id]["navio"] = normal
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


## A ficha de animal do modelo ({} = não vive na ilha como animal).
func ficha_de_animal(id: String) -> Dictionary:
	return (_modelos[id].get("animal", {}) as Dictionary).duplicate() if tem(id) else {}


## Grava a ficha de animal ({} tira). Ficha inválida é recusada inteira.
func definir_ficha_de_animal(id: String, ficha: Dictionary) -> Error:
	if not tem(id):
		return ERR_DOES_NOT_EXIST
	if ficha.is_empty():
		_modelos[id].erase("animal")
	else:
		var normal := FichaDeAnimal.normalizar(ficha)
		if normal.is_empty():
			return ERR_INVALID_PARAMETER
		_modelos[id]["animal"] = normal
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


## O comportamento que o jogo dá à peça deste modelo ("" = só um modelo).
func comportamento_do_modelo(id: String) -> String:
	return str(_modelos[id].get("comportamento", "")) if tem(id) else ""


## Grava o comportamento do modelo ("" tira). Mesmo alfabeto do id.
## Triângulos da malha "Colisao" do modelo (ver `_triangulos_da_colisao`). 0 apaga.
func definir_triangulos_colisao(id: String, n: int) -> Error:
	if not tem(id):
		return ERR_DOES_NOT_EXIST
	_esquecer_formas(id)
	if n > 0:
		_modelos[id]["triangulos_colisao"] = n
	else:
		_modelos[id].erase("triangulos_colisao")
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


func definir_comportamento(id: String, comportamento: String) -> Error:
	if not tem(id):
		return ERR_DOES_NOT_EXIST
	if not comportamento.is_empty() and _regex_id.search(comportamento) == null:
		return ERR_INVALID_PARAMETER
	_modelos[id]["comportamento"] = comportamento
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


func categorias_do_modelo(id: String) -> Array[String]:
	var copia: Array[String] = []
	if tem(id):
		for c in _modelos[id]["categorias"]:
			copia.append(str(c))
	return copia


## Quantos modelos têm a categoria ("" = quantos não têm nenhuma).
func contar_na_categoria(categoria: String) -> int:
	var n := 0
	for mid in _ordem:
		var lista: Array = _modelos[mid]["categorias"]
		if (categoria.is_empty() and lista.is_empty()) or lista.has(categoria):
			n += 1
	return n


func _indice_categoria(id: String) -> int:
	for i in _categorias.size():
		if _categorias[i]["id"] == id:
			return i
	return -1


func _motivo_nome_categoria(nome: String, ignorar_id: String) -> String:
	if nome.is_empty() or nome.length() > MAX_NOME_CATEGORIA:
		return "o nome da categoria precisa ter de 1 a %d caracteres" % MAX_NOME_CATEGORIA
	for c in _categorias:
		if c["id"] != ignorar_id and str(c["nome"]).to_lower() == nome.to_lower():
			return "já existe a categoria \"%s\"" % c["nome"]
	return ""


func salvar_catalogo() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(raiz))
	var lista: Array = []
	for id in _ordem:
		var e: Dictionary = _modelos[id]
		var entrada := {"id": id, "nome": e["nome"], "arquivo": id + ".glb", "sha256": e["sha256"],
			"centro": _lista(e["centro"]), "tamanho": _lista(e["tamanho"]), "triangulos": e["triangulos"]}
		if not (e["categorias"] as Array).is_empty():
			entrada["categorias"] = e["categorias"].duplicate()
		if not str(e.get("comportamento", "")).is_empty():
			entrada["comportamento"] = e["comportamento"]
		if e.has("tamanho_padrao"):
			entrada["tamanho_padrao"] = _lista(e["tamanho_padrao"])
		if str(e.get("colisao", "")) == "partes":
			entrada["colisao"] = "partes"
		if e.has("triangulos_colisao"):
			entrada["triangulos_colisao"] = e["triangulos_colisao"]
		if not (e.get("animal", {}) as Dictionary).is_empty():
			entrada["animal"] = (e["animal"] as Dictionary).duplicate()
		if e.get("atravessavel", false):
			entrada["atravessavel"] = true
		if e.get("escalavel", false):
			entrada["escalavel"] = true
		if not (e.get("frutifera", []) as Array).is_empty():
			entrada["frutifera"] = (e["frutifera"] as Array).duplicate()
		if not (e.get("navio", {}) as Dictionary).is_empty():
			var ficha := {}
			for campo in FichaDeNavio.CAMPOS:
				ficha[campo] = e["navio"][campo]
			entrada["navio"] = ficha
		lista.append(entrada)
	var cats: Array = []
	for c in _categorias:
		cats.append({"id": c["id"], "nome": c["nome"]})
	var texto := JSON.stringify({"formato": FORMATO, "versao": VERSAO, "categorias": cats, "modelos": lista}, "\t", false) + "\n"
	var caminho := raiz.path_join(ARQUIVO_CATALOGO)
	var f := FileAccess.open(caminho + ".tmp", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(texto)
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho + ".tmp"),
		ProjectSettings.globalize_path(caminho))


# ------------------------------------------------------------------- modelos
## Uma cópia nova do modelo, fora da árvore, com a origem do ARQUIVO (sem
## centralizar). null se não houver como carregar.
func instanciar(id: String) -> Node3D:
	if not tem(id):
		return null
	var caminho := caminho_do_arquivo(id)
	if not _cenas.has(id):
		var inicio_us := Time.get_ticks_usec()
		var importada: Resource = null
		if ResourceLoader.exists(caminho):
			importada = ResourceLoader.load(caminho)
		if importada is PackedScene:
			_cenas[id] = importada
		else:
			var gerada := carregar_glb(caminho)
			if gerada == null:
				return null
			_cenas[id] = empacotar(gerada)
			gerada.free()
		if MonitorDeCarga.ativo:      # monitor de carga: o que custou ler do disco (cada modelo, uma vez)
			var arquivo := FileAccess.open(caminho, FileAccess.READ)
			MonitorDeCarga.recurso("modelo", id, (Time.get_ticks_usec() - inicio_us) / 1000.0, arquivo.get_length() if arquivo != null else 0)
	elif MonitorDeCarga.ativo:
		MonitorDeCarga.recurso_em_cache()
	var copia := (_cenas[id] as PackedScene).instantiate() as Node3D
	_esconder_colisao(copia)     # miniatura, editor e jogo: a malha de colisão nunca aparece
	_aplicar_voxel(id, copia)
	_acoplar_clipes(id, copia)
	return copia


## Animais voxel (tools/voxelizar_animais.gd): `<id>.voxel.scn` guarda uma malha de cubos por
## MeshInstance3D do modelo (nome = caminho do nó, "/" trocado por "|"). Aqui só se TROCA a
## malha: esqueleto, Skin e animações continuam os do .glb. Sem o arquivo, nada muda.
var _voxels := {}                  # id -> {caminho_do_nó: ArrayMesh} (vazio = sem versão voxel)

func _aplicar_voxel(id: String, modelo: Node3D) -> void:
	if not _voxels.has(id):
		var malhas := {}
		var arquivo := caminho_do_arquivo(id).get_basename() + ".voxel.scn"
		if ResourceLoader.exists(arquivo):
			var pacote := load(arquivo) as PackedScene
			if pacote != null:
				var raiz := pacote.instantiate()
				for filho in raiz.get_children():
					if filho is MeshInstance3D:
						malhas[String(filho.name)] = (filho as MeshInstance3D).mesh
				raiz.free()
		_voxels[id] = malhas
	var malhas: Dictionary = _voxels[id]
	if malhas.is_empty():
		return
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var chave := str(modelo.get_path_to(no)).replace("/", "|")
		if malhas.has(chave):
			(no as MeshInstance3D).mesh = malhas[chave]


## Clipes gerados para um modelo que já veio com ossos (`<id>.clipes.res`, uma
## AnimationLibrary — tools/mapa_ilha/clipes_dos_riggados.gd): entram no AnimationPlayer como
## a biblioteca "extra" ("extra/damage"...). O .glb original fica intocado.
func _acoplar_clipes(id: String, modelo: Node) -> void:
	var caminho := raiz.path_join(id + ".clipes.res")
	if not _clipes_extra.has(id):
		_clipes_extra[id] = ResourceLoader.load(caminho) if ResourceLoader.exists(caminho) else null
	var lib: AnimationLibrary = _clipes_extra[id]
	if lib == null:
		return
	var aps := modelo.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty() and not (aps[0] as AnimationPlayer).has_animation_library("extra"):
		(aps[0] as AnimationPlayer).add_animation_library("extra", lib)


## Coloca (ou atualiza) o modelo como filho "Modelo" de uma peça do mapa, esticado
## para a caixa `tamanho` e centralizado na origem da peça — assim posição e
## gizmo tratam o modelo igual a uma caixa.
func aplicar_em(corpo: Node3D, p: Dictionary) -> void:
	var atual := corpo.get_node_or_null("Modelo") as Node3D
	if atual != null and atual.get_meta("modelo_id", "") != p["modelo"]:
		corpo.remove_child(atual)
		atual.free()
		atual = null
	if atual == null:
		atual = instanciar(p["modelo"])
		if atual == null:
			atual = _marcador_de_modelo_ausente()
			push_warning("[Biblioteca] modelo \"%s\" não encontrado — peça \"%s\" virou marcador" % [p["modelo"], p["id"]])
		atual.name = "Modelo"
		atual.set_meta("modelo_id", p["modelo"])
		corpo.add_child(atual)
	var tamanho: Vector3 = p["tamanho"]
	if atual.get_meta("marcador", false):
		atual.scale = tamanho
		atual.position = Vector3.ZERO
		return
	var e: Dictionary = _modelos[p["modelo"]]
	var escala := _escala(tamanho, e["tamanho"])
	atual.scale = escala
	atual.position = -(e["centro"] as Vector3) * escala


## Colisão do modelo já esticado, em coordenadas da peça. Côncava (triângulos do
## modelo) até o teto; acima dele, ou sem modelo, a caixa.
## A colisão automática deste modelo é a MALHA dele (côncava, exata), e não uma
## caixa? É o que decide se o editor tem um volume simples para DESENHAR e ajustar:
## contra a malha não há caixa honesta para mostrar. Mesma condição de
## `forma_de_colisao` logo abaixo — as duas não podem discordar.
func colisao_e_malha(id: String) -> bool:
	return tem(id) and _triangulos_da_colisao(id) <= MAX_TRIANGULOS_COLISAO \
		and _faces_do_modelo(id).size() >= 3


## Triângulos que a física carregaria: os da malha "Colisao" quando o catálogo os conhece
## (`triangulos_colisao`, gravado por quem registra um modelo com colisão própria — as
## estruturas do Mine Piece, 18/10/2026, têm desenho de 200 mil e colisão de 70 mil);
## senão, os do desenho, como sempre.
func _triangulos_da_colisao(id: String) -> int:
	return int(_modelos[id].get("triangulos_colisao", _modelos[id]["triangulos"]))


func forma_de_colisao(id: String, tamanho: Vector3) -> Shape3D:
	if colisao_e_malha(id):
		var chave := "%s|%s" % [id, tamanho]
		if _formas.has(chave):
			return _formas[chave]
		var e: Dictionary = _modelos[id]
		var escala := _escala(tamanho, e["tamanho"])
		var t := Transform3D(Basis.from_scale(escala), -(e["centro"] as Vector3) * escala)
		var concava := ConcavePolygonShape3D.new()
		concava.set_faces(t * _faces_do_modelo(id))  # multiplicação nativa: sem laço em GDScript
		_formas[chave] = concava
		return concava
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	return caixa


func _esquecer_formas(id: String) -> void:
	for chave in _formas.keys():
		if String(chave).begins_with(id + "|") or String(chave).begins_with("partes|" + id + "|"):
			_formas.erase(chave)
	_partes.erase(id)


# ------------------------------------------------------- colisão em partes
func caminho_das_partes(id: String) -> String:
	return raiz.path_join(id + ".colisao.json")


## "partes" (volumes convexos) ou "malha" (os triângulos do modelo — o padrão).
func modo_de_colisao(id: String) -> String:
	return str(_modelos[id].get("colisao", "malha")) if tem(id) else "malha"


## Grava as partes convexas do modelo (pontos no espaço do .glb) e liga o modo.
## `partes` vazio desliga (volta à malha) e apaga o arquivo.
func definir_partes_de_colisao(id: String, partes: Array) -> Error:
	if not tem(id):
		return ERR_DOES_NOT_EXIST
	_esquecer_formas(id)
	if partes.is_empty():
		_modelos[id].erase("colisao")
		if FileAccess.file_exists(caminho_das_partes(id)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho_das_partes(id)))
	else:
		var lista: Array = []
		for pts in partes:
			var plano: Array = []
			for v: Vector3 in (pts as PackedVector3Array):
				plano.append_array([snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)])
			lista.append(plano)
		var dado := {"formato": FORMATO_COLISAO, "versao": 1, "modelo": id, "sha256": _modelos[id]["sha256"],
			"partes": lista}
		var f := FileAccess.open(caminho_das_partes(id), FileAccess.WRITE)
		if f == null:
			return FileAccess.get_open_error()
		f.store_string(JSON.stringify(dado) + "\n")
		f.close()
		_modelos[id]["colisao"] = "partes"
	var erro := salvar_catalogo()
	mudou.emit()
	return erro


## As partes do modelo, validadas, no espaço do .glb ([] = não tem / inválidas).
func partes_de_colisao(id: String) -> Array:
	if _partes.has(id):
		return _partes[id]
	var saida: Array = []
	_partes[id] = saida
	if modo_de_colisao(id) != "partes" or not FileAccess.file_exists(caminho_das_partes(id)):
		return saida
	var dado: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho_das_partes(id)))
	if not (dado is Dictionary) or dado.get("formato") != FORMATO_COLISAO or not (dado.get("partes") is Array):
		push_warning("[Biblioteca] colisão em partes de \"%s\" ilegível — usando a malha" % id)
		return saida
	if str(dado.get("sha256", "")) != str(_modelos[id]["sha256"]):
		push_warning("[Biblioteca] colisão em partes de \"%s\" é de outra versão do .glb — usando a malha (gere de novo)" % id)
		return saida
	var brutas: Array = dado["partes"]
	if brutas.size() > MAX_PARTES:
		return saida
	for bruta in brutas:
		if not (bruta is Array) or (bruta as Array).size() % 3 != 0 or (bruta as Array).size() < 12:
			saida.clear()
			return saida
		var pts := PackedVector3Array()
		var a: Array = bruta
		for k in range(0, a.size(), 3):
			if not ((a[k] is float or a[k] is int) and (a[k + 1] is float or a[k + 1] is int) and (a[k + 2] is float or a[k + 2] is int)):
				saida.clear()
				return saida
			pts.append(Vector3(a[k], a[k + 1], a[k + 2]))
		saida.append(pts)
	return saida


## TODAS as formas de colisão do modelo esticado, em coordenadas da peça: as partes
## convexas, se o modelo as tiver; senão, a forma única de sempre.
func formas_de_colisao(id: String, tamanho: Vector3) -> Array[Shape3D]:
	var formas: Array[Shape3D] = []
	var partes := partes_de_colisao(id) if colisao_e_malha(id) else []
	if partes.is_empty():
		formas.append(forma_de_colisao(id, tamanho))
		return formas
	var chave := "partes|%s|%s" % [id, tamanho]
	if _formas.has(chave):
		return _formas[chave]
	var e: Dictionary = _modelos[id]
	var escala := _escala(tamanho, e["tamanho"])
	var t := Transform3D(Basis.from_scale(escala), -(e["centro"] as Vector3) * escala)
	for pts in partes:
		var convexa := ConvexPolygonShape3D.new()
		convexa.points = t * (pts as PackedVector3Array)
		formas.append(convexa)
	_formas[chave] = formas
	return formas


# ------------------------------------------------------------- utilitários
## Lê um .glb do disco em tempo de execução. Aceita caminho do SO ou res:// / user://.
static func carregar_glb(caminho: String) -> Node3D:
	var gltf := GLTFDocument.new()
	var estado := GLTFState.new()
	var absoluto := caminho if caminho.is_absolute_path() and not caminho.contains("://") \
		else ProjectSettings.globalize_path(caminho)
	if gltf.append_from_file(absoluto, estado) != OK:
		return null
	return gltf.generate_scene(estado) as Node3D


## Cena gerada → PackedScene. `pack` só guarda os nós cujo `owner` é a raiz, e o
## GLTFDocument não define owner: sem este laço a cena voltaria vazia.
static func empacotar(raiz_: Node) -> PackedScene:
	for no in raiz_.find_children("*", "", true, false):
		no.owner = raiz_
	var cena := PackedScene.new()
	cena.pack(raiz_)
	return cena


## Caixa, triângulos e malhas de uma cena de modelo (no espaço da raiz dela).
static func medir(cena: Node3D) -> Dictionary:
	var caixa := AABB()
	var primeira := true
	var faces := PackedVector3Array()
	var faces_colisao := PackedVector3Array()
	var malhas := 0
	for no in cena.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := _transformacao_ate(mi, cena)
		# A malha de colisão própria não é o modelo: fica fora da caixa, dos
		# triângulos e do desenho — só a física a usa.
		if e_malha_de_colisao(mi):
			faces_colisao.append_array(t * mi.mesh.get_faces())
			continue
		var local := t * mi.get_aabb()
		caixa = local if primeira else caixa.merge(local)
		primeira = false
		faces.append_array(t * mi.mesh.get_faces())
		malhas += 1
	return {"aabb": caixa, "faces": faces, "faces_colisao": faces_colisao, "malhas": malhas,
		"triangulos": faces.size() / 3}


## A malha que o autor do modelo marcou como colisão (nome começando com "Colisao").
static func e_malha_de_colisao(no: Node) -> bool:
	return String(no.name).to_lower().begins_with("colisao")


static func _esconder_colisao(modelo: Node) -> void:
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		if e_malha_de_colisao(no):
			(no as MeshInstance3D).visible = false


func _faces_do_modelo(id: String) -> PackedVector3Array:
	if not _faces.has(id):
		var copia := instanciar(id)
		if copia == null:
			return PackedVector3Array()
		var m := medir(copia)
		var propria: PackedVector3Array = m["faces_colisao"]
		_faces[id] = propria if not propria.is_empty() else m["faces"]
		copia.free()
	return _faces[id]


func _normalizar(bruto: Variant) -> Dictionary:
	if not (bruto is Dictionary):
		return {}
	var d: Dictionary = bruto
	var id := str(d.get("id", ""))
	if _regex_id.search(id) == null:
		return {}
	# O arquivo é SEMPRE `<id>.glb` na raiz: um catálogo editado à mão não consegue
	# apontar para fora da pasta ("../../algo").
	if d.has("arquivo") and str(d["arquivo"]) != id + ".glb":
		return {}
	var centro: Variant = _vetor(d.get("centro"))
	var tamanho: Variant = _vetor(d.get("tamanho"))
	if centro == null or tamanho == null:
		return {}
	var t: Vector3 = tamanho
	if t.x <= 0.0 or t.y <= 0.0 or t.z <= 0.0 or not t.is_finite():
		return {}
	var nome := str(d.get("nome", id)).strip_edges().left(MAX_NOME)
	# Só categorias que existem; repetida conta uma vez.
	var cats: Array[String] = []
	var brutas: Variant = d.get("categorias", [])
	if brutas is Array:
		for c in brutas:
			if c is String and tem_categoria(c) and not cats.has(c):
				cats.append(c)
	# Comportamento: texto curto no mesmo alfabeto do id; qualquer outra coisa vira "".
	var comportamento := str(d.get("comportamento", ""))
	if not comportamento.is_empty() and _regex_id.search(comportamento) == null:
		comportamento = ""
	var entrada := {"id": id, "nome": nome if not nome.is_empty() else id, "sha256": str(d.get("sha256", "")),
		"centro": centro, "tamanho": t, "triangulos": maxi(int(d.get("triangulos", 0)), 0), "categorias": cats,
		"comportamento": comportamento}
	# Opcionais: inválido conta como ausente (um catálogo editado à mão não pode
	# impedir a loja de abrir).
	var padrao_: Variant = _vetor(d.get("tamanho_padrao"))
	if padrao_ != null and (padrao_ as Vector3).x > 0.0 and (padrao_ as Vector3).y > 0.0 \
			and (padrao_ as Vector3).z > 0.0 and (padrao_ as Vector3).is_finite():
		entrada["tamanho_padrao"] = padrao_
	var ficha := FichaDeNavio.normalizar(d.get("navio"))
	if not ficha.is_empty():
		entrada["navio"] = ficha
	if str(d.get("colisao", "")) == "partes":
		entrada["colisao"] = "partes"
	if (d.get("triangulos_colisao") is float or d.get("triangulos_colisao") is int) and int(d["triangulos_colisao"]) > 0:
		entrada["triangulos_colisao"] = int(d["triangulos_colisao"])
	var animal := FichaDeAnimal.normalizar(d.get("animal"))
	if not animal.is_empty():
		entrada["animal"] = animal
	if d.get("atravessavel") == true:
		entrada["atravessavel"] = true
	if d.get("escalavel") == true:
		entrada["escalavel"] = true
	var frutas: Variant = d.get("frutifera", [])
	if frutas is Array and not (frutas as Array).is_empty() \
			and (frutas as Array).all(func(f): return f is String and _regex_id.search(f) != null):
		entrada["frutifera"] = (frutas as Array).duplicate()
	return entrada


static func _vetor(v: Variant) -> Variant:
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() == 3:
		var a: Array = v
		if (a[0] is float or a[0] is int) and (a[1] is float or a[1] is int) and (a[2] is float or a[2] is int):
			var r := Vector3(a[0], a[1], a[2])
			return r if r.is_finite() else null
	return null


static func _limpar_id(texto: String, padrao_: String) -> String:
	var base := texto.to_lower().strip_edges()
	var limpo := ""
	for c in base:
		if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c == "_" or c == "-":
			limpo += c
		elif c == " " or c == ".":
			limpo += "_"
	limpo = limpo.left(56)
	return limpo if not limpo.is_empty() else padrao_


static func _escala(tamanho: Vector3, original: Vector3) -> Vector3:
	return Vector3(tamanho.x / maxf(original.x, 0.0001), tamanho.y / maxf(original.y, 0.0001),
		tamanho.z / maxf(original.z, 0.0001))


static func _transformacao_ate(no: Node3D, raiz_: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var atual: Node = no
	while atual != null and atual != raiz_:
		if atual is Node3D:
			t = (atual as Node3D).transform * t
		atual = atual.get_parent()
	return t


static func _lista(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _marcador_de_modelo_ausente() -> Node3D:
	var marcador := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3.ONE
	marcador.mesh = caixa
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.2, 0.8, 0.5)   # magenta: "falta algo aqui"
	marcador.material_override = mat
	marcador.set_meta("marcador", true)
	return marcador
