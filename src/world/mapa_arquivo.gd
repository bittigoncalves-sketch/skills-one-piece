class_name MapaArquivo
extends RefCounted
# ============================================================================
#  MAPA EM ARQUIVO — ler, validar e gravar o formato de mapa do Modo História.
#
#  É a FONTE ÚNICA do mapa: o Modo História monta o mundo a partir deste arquivo,
#  e o editor de mapa (`src/editor_mapa/`) abre e grava exatamente o mesmo
#  arquivo. Nenhum dos dois guarda uma segunda cópia.
#
#  Este script não cria nó nenhum — quem transforma dado em mundo é o
#  `MapaMontador`. Separados porque o editor precisa validar e gravar sem montar.
#
#  POR QUE JSON, E NÃO .tres
#  -------------------------
#  1. Um `.tres` pode trazer script embutido, e carregá-lo EXECUTA esse script.
#     Mapa é o tipo de arquivo que se troca com outra pessoa; JSON é só dado.
#  2. Diff legível no git — cada peça é um bloco de texto.
#  3. Não depende de `class_name` no cache (armadilha nº 1 do projeto).
#  Custo aceito: a validação é nossa. Por isso ela é rígida e diz o motivo.
#
#  ⚠️ EXPORTAÇÃO: `.json` não é recurso do Godot e fica FORA do pacote exportado
#  por padrão. O `export_presets.cfg` inclui `mapas/*.json` de propósito.
#
#  FORMATO (versão 1)
#  ------------------
#    {
#      "formato": "skills-one-piece/mapa",
#      "versao": 1,
#      "nome": "Baseplate",
#      "spawn": { "posicao": [0, 3, 0] },
#      "pecas": [
#        { "id": "baseplate", "tipo": "caixa",
#          "posicao": [0, -1, 0], "rotacao_graus": [0, 0, 0],
#          "tamanho": [512, 2, 512], "cor": "#767676",
#          "material": "grade", "grade_celula": 4, "colisao": true }
#      ]
#    }
#
#  Medidas em metros, rotação em graus (é o que uma pessoa digita no editor).
#
#  TIPOS e a regra de tamanho de cada um (a física não aceita forma esticada: uma
#  SphereShape3D não vira elipsoide, então o arquivo não pode prometer uma):
#    caixa    — [x, y, z] livres
#    esfera   — x = y = z (diâmetro)
#    cilindro — x = z (diâmetro), y = altura; o eixo é o Y
#    cunha    — [x, y, z] livres; a rampa desce de −X (face em pé) para +X
#    modelo   — [x, y, z] livres = a CAIXA que o modelo ocupa (ele é esticado para
#               caber); exige "modelo": "<id da loja>" (ver BibliotecaDeModelos).
#               Cor e material não se aplicam a modelo.
#    area_animais — [x, y, z] livres = a REGIÃO onde uma espécie nasce (01/10/2026):
#               "especie": "<id do modelo na categoria Animais>", "quantidade": 1..50.
#               Volume translúcido no editor, invisível e sem colisão no jogo; o animal
#               nasce num ponto aleatório do chão dentro dela (ver `PopulacaoDeAnimais`).
#    terreno  — [x, y, z] livres = a CAIXA do bloco de relevo (30/09/2026); exige
#               "relevo": { celulas, alturas, solo?, agua? } — formato e regras em
#               `TerrenoDoMapa`. As alturas são fração do tamanho Y: esticar o bloco
#               estica o relevo. Cor e material não se aplicam (a cor é do solo).
#
#  HITBOX (23/09/2026) — opcional, por peça. AUSENTE = automático, que é o que
#  sempre foi: a colisão sai do tipo e do tamanho da peça (e, no modelo, da malha
#  dele). Presente, ela MANDA — e só ela:
#    "hitbox": { "forma": "cilindro", "deslocamento": [0, 1.4, 0],
#                "tamanho": [1.2, 2.8, 1.2], "rotacao_graus": [0, 0, 0] }
#  `forma` vem de FORMAS_HITBOX (inclui "capsula", que TIPOS não tem), o
#  deslocamento e a rotação são LOCAIS à peça, e o tamanho obedece à mesma regra
#  de forma não esticada do tamanho da peça. A hitbox não muda a aparência nem o
#  clique no editor: só o que o corpo colide. Com "colisao": false ela é ignorada.
#
#  GRUPOS (Ctrl+G do editor, 16/09/2026) — opcionais:
#    "grupos": [ { "id": "casa", "pai": "" }, { "id": "telhado", "pai": "casa" } ]
#    e cada peça pode ter "grupo": "<id do grupo>".
#  Grupo não tem posição própria: é só a hierarquia (as peças guardam onde estão
#  no mundo). O jogo IGNORA grupos — eles existem para o editor mover junto.
#  Recusado: id de grupo repetido ou igual a id de peça, pai/grupo que não existe,
#  e grupo que é ancestral de si mesmo.
#
#  Campo novo entra como OPCIONAL com padrão; campo que muda de sentido sobe a
#  `versao` — e aí este script precisa saber converter a antiga.
# ============================================================================

const FORMATO := "skills-one-piece/mapa"
const VERSAO := 1

# Tetos contra arquivo corrompido ou malicioso. Não são limite de jogo: um mapa
# de verdade fica muito abaixo. Se um dia um mapa legítimo bater aqui, suba o
# número E meça o custo de montagem (ver o gatilho no `MapaMontador`).
const MAX_BYTES := 8 * 1024 * 1024
const MAX_PECAS := 5000
const LIMITE_COORD := 100000.0
const TAMANHO_MIN := 0.05
const TAMANHO_MAX := 4096.0
const GRADE_MIN := 0.25
const GRADE_PADRAO := 4.0
const MAX_NOME := 80

const TIPOS: Array[String] = ["caixa", "esfera", "cilindro", "cunha", "modelo", "terreno", "area_animais"]
const QUANTIDADE_MAX := 50
## As que o editor oferece em "Forma". Modelo entra pela loja, não por aqui.
const TIPOS_PRIMITIVOS: Array[String] = ["caixa", "esfera", "cilindro", "cunha"]
const MATERIAIS: Array[String] = ["liso", "grade"]
## HITBOX (23/09/2026) — as formas que o VOLUME DE COLISÃO pode ter. É lista à parte
## de `TIPOS` de propósito: `TIPOS` é o que a peça É (e aparece na loja), e ninguém
## pediu peça em forma de cápsula. A cápsula existe aqui porque personagem, poste e
## tronco colidem melhor com ela do que com caixa.
const FORMAS_HITBOX: Array[String] = ["caixa", "esfera", "cilindro", "cunha", "capsula"]

# O id vira NOME DE NÓ. Ponto, dois-pontos, barra, arroba e aspas são proibidos
# em nome de nó — o Godot trocaria em silêncio e o editor perderia a peça.
const PADRAO_ID := "^[A-Za-z0-9_-]{1,64}$"


## Lê e valida. Devolve `{ok, erros, mapa}` — nunca meio mapa: com qualquer erro,
## `ok` é false e `mapa` vem vazio.
static func carregar(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return _falha(["o arquivo não existe: %s" % caminho])
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return _falha(["não foi possível abrir %s (%s)"
			% [caminho, error_string(FileAccess.get_open_error())]])
	if f.get_length() > MAX_BYTES:
		return _falha(["%s tem %d bytes; o teto é %d" % [caminho, f.get_length(), MAX_BYTES]])
	return ler_texto(f.get_as_text())


static func ler_texto(texto: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(texto) != OK:
		return _falha(["JSON inválido na linha %d: %s"
			% [json.get_error_line(), json.get_error_message()]])
	return validar(json.data)


## Recebe o dado cru do JSON e devolve o mapa NORMALIZADO: vetores viram
## `Vector3`, cor vira `Color`, opcionais recebem o padrão. Junta TODOS os erros
## antes de recusar — quem edita à mão quer a lista inteira, não um por vez.
static func validar(bruto: Variant) -> Dictionary:
	if not (bruto is Dictionary):
		return _falha(["a raiz do mapa tem que ser um objeto { }"])
	var d: Dictionary = bruto
	var erros: Array[String] = []

	if d.get("formato") != FORMATO:
		erros.append("\"formato\" tem que ser \"%s\"" % FORMATO)
	var versao: Variant = d.get("versao")
	if not _numero(versao) or float(versao) != float(VERSAO):
		erros.append("\"versao\" %s não é suportada (esta build lê a %d)" % [str(versao), VERSAO])

	var nome := "Sem nome"
	if d.has("nome"):
		if d["nome"] is String and not String(d["nome"]).strip_edges().is_empty() \
				and String(d["nome"]).length() <= MAX_NOME:
			nome = String(d["nome"]).strip_edges()
		else:
			erros.append("\"nome\" tem que ser texto de 1 a %d caracteres" % MAX_NOME)

	var spawn := Vector3.ZERO
	if d.get("spawn") is Dictionary:
		spawn = _vetor((d["spawn"] as Dictionary).get("posicao"), "spawn.posicao",
			-LIMITE_COORD, LIMITE_COORD, erros)
	else:
		erros.append("\"spawn\" é obrigatório: { \"posicao\": [x, y, z] }")

	var pecas: Array[Dictionary] = []
	if not (d.get("pecas") is Array):
		erros.append("\"pecas\" é obrigatório e tem que ser uma lista")
	else:
		var lista: Array = d["pecas"]
		if lista.size() > MAX_PECAS:
			erros.append("%d peças; o teto é %d" % [lista.size(), MAX_PECAS])
		else:
			var regex := RegEx.create_from_string(PADRAO_ID)
			var vistos := {}
			for i in lista.size():
				var p := _peca(lista[i], i, regex, vistos, erros)
				if not p.is_empty():
					pecas.append(p)

	var grupos := _grupos(d.get("grupos", []), pecas, erros)

	if not erros.is_empty():
		return _falha(erros)
	var nenhum: Array[String] = []
	return {"ok": true, "erros": nenhum,
		"mapa": {"nome": nome, "spawn": {"posicao": spawn}, "pecas": pecas, "grupos": grupos}}


## Mapa normalizado → texto JSON. A ordem das chaves é a do formato acima (não
## alfabética), para o arquivo ler de cima para baixo como uma peça se descreve.
static func para_texto(mapa: Dictionary) -> String:
	var pecas: Array = []
	for p: Dictionary in mapa["pecas"]:
		var saida := {
			"id": p["id"],
			"tipo": p["tipo"],
		}
		if p["tipo"] == "modelo":
			saida["modelo"] = p["modelo"]
		if not str(p.get("grupo", "")).is_empty():
			saida["grupo"] = p["grupo"]
		saida.merge({
			"posicao": _lista(p["posicao"]),
			"rotacao_graus": _lista(p["rotacao_graus"]),
			"tamanho": _lista(p["tamanho"]),
			"cor": "#" + (p["cor"] as Color).to_html(false),
			"material": p["material"],
		})
		if p["material"] == "grade":
			saida["grade_celula"] = p["grade_celula"]
		saida["colisao"] = p["colisao"]
		if p["tipo"] == "terreno":
			saida["relevo"] = TerrenoDoMapa.para_json(p["relevo"])
		if p["tipo"] == "area_animais":
			saida["especie"] = p["especie"]
			saida["quantidade"] = p["quantidade"]
		# Sem hitbox própria o arquivo fica IGUAL ao de antes de a hitbox existir —
		# é o que mantém o mapa vivo do dono intocado ao abrir e salvar.
		var h: Dictionary = p.get("hitbox", {})
		if not h.is_empty():
			saida["hitbox"] = {
				"forma": h["forma"],
				"deslocamento": _lista(h["deslocamento"]),
				"tamanho": _lista(h["tamanho"]),
				"rotacao_graus": _lista(h["rotacao_graus"]),
			}
		pecas.append(saida)
	var raiz := {
		"formato": FORMATO,
		"versao": VERSAO,
		"nome": mapa["nome"],
		"spawn": {"posicao": _lista(mapa["spawn"]["posicao"])},
	}
	# Sem grupo nenhum o arquivo fica igual ao de antes dos grupos existirem.
	var grupos: Array = mapa.get("grupos", [])
	if not grupos.is_empty():
		var lista_grupos: Array = []
		for g: Dictionary in grupos:
			lista_grupos.append({"id": g["id"], "pai": g["pai"]})
		raiz["grupos"] = lista_grupos
	raiz["pecas"] = pecas
	return JSON.stringify(raiz, "\t", false) + "\n"


## Grava SÓ se o que sai relê como mapa válido, e grava num temporário antes de
## trocar — um editor que fecha no meio da gravação não pode deixar o mapa
## truncado no lugar do bom.
static func salvar(caminho: String, mapa: Dictionary) -> Error:
	var texto := para_texto(mapa)
	var releitura := ler_texto(texto)
	if not releitura["ok"]:
		push_error("[MapaArquivo] recusado, não relê: %s" % "; ".join(releitura["erros"]))
		return ERR_INVALID_DATA
	var temporario := caminho + ".tmp"
	var f := FileAccess.open(temporario, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(texto)
	f.close()
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporario), ProjectSettings.globalize_path(caminho))


# ------------------------------------------------------------------- internos
static func _peca(bruto: Variant, i: int, regex: RegEx, vistos: Dictionary,
		erros: Array[String]) -> Dictionary:
	var onde := "pecas[%d]" % i
	if not (bruto is Dictionary):
		erros.append("%s tem que ser um objeto { }" % onde)
		return {}
	var d: Dictionary = bruto
	var antes := erros.size()

	var id := ""
	if d.get("id") is String and regex.search(String(d["id"])) != null:
		id = String(d["id"])
		onde = "pecas[%d] \"%s\"" % [i, id]
		if vistos.has(id):
			erros.append("%s: id repetido (também em pecas[%d])" % [onde, vistos[id]])
		vistos[id] = i
	else:
		erros.append("%s: \"id\" tem que ter 1 a 64 caracteres entre A-Z a-z 0-9 _ -" % onde)

	var tipo := str(d.get("tipo", ""))
	if not TIPOS.has(tipo):
		erros.append("%s: \"tipo\" \"%s\" desconhecido (aceitos: %s)" % [onde, tipo, ", ".join(TIPOS)])

	var posicao := _vetor(d.get("posicao"), onde + ".posicao", -LIMITE_COORD, LIMITE_COORD, erros)
	var rotacao := _vetor(d.get("rotacao_graus", [0, 0, 0]), onde + ".rotacao_graus", -360.0, 360.0, erros)
	var tamanho := _vetor(d.get("tamanho"), onde + ".tamanho", TAMANHO_MIN, TAMANHO_MAX, erros)
	if tipo == "esfera" and not (is_equal_approx(tamanho.x, tamanho.y) and is_equal_approx(tamanho.x, tamanho.z)):
		erros.append("%s: esfera precisa de \"tamanho\" com x = y = z (diâmetro)" % onde)
	elif tipo == "cilindro" and not is_equal_approx(tamanho.x, tamanho.z):
		erros.append("%s: cilindro precisa de \"tamanho\" com x = z (diâmetro)" % onde)

	var cor := Color(0.46, 0.46, 0.46)
	var cor_txt: Variant = d.get("cor", "#767676")
	if cor_txt is String and String(cor_txt).length() == 7 and Color.html_is_valid(cor_txt):
		cor = Color.html(cor_txt)
	else:
		erros.append("%s: \"cor\" tem que ser \"#rrggbb\"" % onde)

	var material := str(d.get("material", "liso"))
	if not MATERIAIS.has(material):
		erros.append("%s: \"material\" \"%s\" desconhecido (aceitos: %s)"
			% [onde, material, ", ".join(MATERIAIS)])

	var grade := GRADE_PADRAO
	if d.has("grade_celula"):
		if _numero(d["grade_celula"]) and float(d["grade_celula"]) >= GRADE_MIN \
				and float(d["grade_celula"]) <= TAMANHO_MAX:
			grade = float(d["grade_celula"])
		else:
			erros.append("%s: \"grade_celula\" tem que ser número entre %s e %s"
				% [onde, GRADE_MIN, TAMANHO_MAX])

	# O id do modelo NÃO é conferido contra a loja aqui: um modelo apagado não pode
	# impedir o mapa de abrir. Quem monta a peça mostra um marcador no lugar.
	var modelo := ""
	if tipo == "modelo":
		if d.get("modelo") is String and regex.search(String(d["modelo"])) != null:
			modelo = String(d["modelo"])
		else:
			erros.append("%s: modelo precisa de \"modelo\" com o id da loja (A-Z a-z 0-9 _ -)" % onde)

	var colisao: Variant = d.get("colisao", true)
	if not (colisao is bool):
		erros.append("%s: \"colisao\" tem que ser true ou false" % onde)
		colisao = true

	var hitbox := _hitbox(d.get("hitbox"), onde + ".hitbox", erros)

	var relevo := {}
	if tipo == "terreno":
		relevo = TerrenoDoMapa.validar(d.get("relevo"), onde, erros)
	var especie := ""
	var quantidade := 0
	if tipo == "area_animais":
		# Como o id de modelo: espécie apagada da loja não impede o mapa de abrir (a
		# área só não gera ninguém, com aviso no log).
		if d.get("especie") is String and regex.search(String(d["especie"])) != null:
			especie = String(d["especie"])
		else:
			erros.append("%s: área de animais precisa de \"especie\" (id de modelo da loja)" % onde)
		var q: Variant = d.get("quantidade", 3)
		if _numero(q) and float(q) == floorf(float(q)) and int(q) >= 1 and int(q) <= QUANTIDADE_MAX:
			quantidade = int(q)
		else:
			erros.append("%s: \"quantidade\" tem que ser inteiro de 1 a %d" % [onde, QUANTIDADE_MAX])

	if erros.size() != antes:
		return {}
	var grupo_da_peca: Variant = d.get("grupo", "")
	if not (grupo_da_peca is String) or (not String(grupo_da_peca).is_empty() and regex.search(grupo_da_peca) == null):
		erros.append("%s: \"grupo\" tem que ser o id de um grupo" % onde)
		return {}
	var peca := {"id": id, "tipo": tipo, "posicao": posicao, "rotacao_graus": rotacao,
		"tamanho": tamanho, "cor": cor, "material": material,
		"grade_celula": grade, "colisao": colisao, "grupo": grupo_da_peca}
	if tipo == "modelo":
		peca["modelo"] = modelo
	if tipo == "terreno":
		peca["relevo"] = relevo
	if tipo == "area_animais":
		peca["especie"] = especie
		peca["quantidade"] = quantidade
		peca["colisao"] = false     # região, não obstáculo
	if not hitbox.is_empty():
		peca["hitbox"] = hitbox
	return peca


## A hitbox da peça, ou {} quando não há (o caso normal). Devolve {} também no
## erro — quem chama já recebeu a mensagem em `erros` e recusa o mapa inteiro.
static func _hitbox(bruto: Variant, onde: String, erros: Array[String]) -> Dictionary:
	if bruto == null:
		return {}
	if not (bruto is Dictionary):
		erros.append("%s tem que ser um objeto { } (ou não existir)" % onde)
		return {}
	var d: Dictionary = bruto
	var antes := erros.size()
	var forma := str(d.get("forma", ""))
	if not FORMAS_HITBOX.has(forma):
		erros.append("%s: \"forma\" \"%s\" desconhecida (aceitas: %s)"
			% [onde, forma, ", ".join(FORMAS_HITBOX)])
	var deslocamento := _vetor(d.get("deslocamento", [0, 0, 0]), onde + ".deslocamento",
		-LIMITE_COORD, LIMITE_COORD, erros)
	var rotacao := _vetor(d.get("rotacao_graus", [0, 0, 0]), onde + ".rotacao_graus",
		-360.0, 360.0, erros)
	var tamanho := _vetor(d.get("tamanho"), onde + ".tamanho", TAMANHO_MIN, TAMANHO_MAX, erros)
	# A física não faz esfera esticada nem cápsula de base oval: a mesma regra do
	# tamanho da peça vale aqui, senão o arquivo prometeria um volume impossível.
	if forma == "esfera" and not (is_equal_approx(tamanho.x, tamanho.y) and is_equal_approx(tamanho.x, tamanho.z)):
		erros.append("%s: esfera precisa de \"tamanho\" com x = y = z (diâmetro)" % onde)
	elif forma in ["cilindro", "capsula"] and not is_equal_approx(tamanho.x, tamanho.z):
		erros.append("%s: %s precisa de \"tamanho\" com x = z (diâmetro)" % [onde, forma])
	if erros.size() != antes:
		return {}
	return {"forma": forma, "deslocamento": deslocamento, "tamanho": tamanho,
		"rotacao_graus": rotacao}


static func _grupos(bruto: Variant, pecas: Array[Dictionary], erros: Array[String]) -> Array[Dictionary]:
	var grupos: Array[Dictionary] = []
	if not (bruto is Array):
		erros.append("\"grupos\" tem que ser uma lista")
		return grupos
	var regex := RegEx.create_from_string(PADRAO_ID)
	var ids_pecas := {}
	for p in pecas:
		ids_pecas[p["id"]] = true
	var pai_de := {}
	for i in (bruto as Array).size():
		var g: Variant = bruto[i]
		var onde := "grupos[%d]" % i
		if not (g is Dictionary) or regex.search(str(g.get("id", ""))) == null:
			erros.append("%s: grupo precisa de \"id\" (A-Z a-z 0-9 _ -)" % onde)
			continue
		var gid := str(g["id"])
		var pai := str(g.get("pai", ""))
		if pai_de.has(gid) or ids_pecas.has(gid):
			erros.append("%s \"%s\": id repetido (grupo ou peça)" % [onde, gid])
			continue
		pai_de[gid] = pai
		grupos.append({"id": gid, "pai": pai})
	for gid: String in pai_de:
		var pai: String = pai_de[gid]
		if not pai.is_empty() and not pai_de.has(pai):
			erros.append("grupo \"%s\": pai \"%s\" não existe" % [gid, pai])
			continue
		# Subir pelos pais: voltar ao próprio grupo = ciclo (a hierarquia não termina).
		var atual := pai
		for _passo in pai_de.size() + 1:
			if atual.is_empty() or not pai_de.has(atual):
				break
			if atual == gid:
				erros.append("grupo \"%s\" é ancestral de si mesmo" % gid)
				break
			atual = pai_de[atual]
	for p in pecas:
		if not str(p["grupo"]).is_empty() and not pai_de.has(p["grupo"]):
			erros.append("peça \"%s\": grupo \"%s\" não existe" % [p["id"], p["grupo"]])
	return grupos


static func _vetor(bruto: Variant, onde: String, minimo: float, maximo: float,
		erros: Array[String]) -> Vector3:
	if bruto is Array and (bruto as Array).size() == 3:
		var a: Array = bruto
		if _numero(a[0]) and _numero(a[1]) and _numero(a[2]):
			var v := Vector3(float(a[0]), float(a[1]), float(a[2]))
			if v.x >= minimo and v.y >= minimo and v.z >= minimo \
					and v.x <= maximo and v.y <= maximo and v.z <= maximo:
				return v
	erros.append("%s tem que ser [x, y, z] com números entre %s e %s" % [onde, minimo, maximo])
	return Vector3.ZERO


# JSON só produz float, mas `validar` também recebe dicionário montado em código
# (o editor, os testes) — onde o número pode ser int. NaN e infinito ficam fora:
# um só deles faz a peça sumir ou a física explodir sem erro nenhum.
static func _numero(v: Variant) -> bool:
	return (v is float and is_finite(v)) or v is int


static func _lista(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func _falha(erros: Array) -> Dictionary:
	var lista: Array[String] = []
	for e in erros:
		lista.append(str(e))
	return {"ok": false, "erros": lista, "mapa": {}}
