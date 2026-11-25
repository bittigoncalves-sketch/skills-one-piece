class_name SkillsPublicadas
extends RefCounted
## As skills do Builder que o JOGO usa (06/10/2026).
##
## Decisão do dono: "no projeto". O botão **Publicar** do Builder copia a skill
## validada para `res://mapas/skills/<id>.json` (no git, junto dos mapas): todo
## mundo que joga esta versão tem as mesmas skills, e na arena em rede só o ID
## trafega. A biblioteca `user://skills_builder` continua sendo o rascunho.
##
## O KIT do jogador (`kit.json`) diz qual skill vai em cada tecla. Só entra skill
## com Usuário = Jogador; publicar outra na mesma tecla a substitui no kit.
## Nada aqui executa código vindo de arquivo: tudo passa por `Dados.validar`.

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const PASTA := "res://mapas/skills"
const ARQUIVO_DO_KIT := "kit.json"
const FORMATO_DO_KIT := "skills-one-piece/kit-builder"
const VERSAO_DO_KIT := 1
const TECLAS: Array[String] = ["Z", "X", "C", "V", "F"]
const DONO_DO_KIT := "Jogador"
## FRUTAS DO BUILDER (06/10/2026, decisão do dono): fruta própria com nome, cor e teclas,
## que vira fruta de verdade no jogo. O Kit do Builder é a fruta "sem nome" (kit.json).
const ARQUIVO_DE_FRUTAS := "frutas.json"
const FORMATO_DE_FRUTAS := "skills-one-piece/frutas-builder"
## Ids que uma fruta do Builder não pode ter (o kit e as frutas da arena).
const ID_DO_KIT := "kit_builder"
## Preço na loja do Modo História (07/10/2026, pedido do dono: o Publicar põe a fruta à
## venda no vendedor de frutas). Padrão 1 moeda, como as 13 frutas da arena.
const PRECO_PADRAO := 1
const PRECO_MAXIMO := 99999

## Teste aponta para outra pasta e nunca toca a do projeto.
static var pasta_forcada := ""
## CHAVE DO BUILDER (27/10/2026, decisão do dono: "deixar o builder desativado"). DESLIGADO por padrão: nenhuma
## skill, fruta ou kit publicado no Builder entra no jogo (a ferramenta fica sem botão no menu). Reversível sem
## apagar nada: variável de ambiente `SOP_BUILDER=1` (é o que os testes do Builder usam) ou `ativo_forcado = 1`.
## O conteúdo do Mine Piece NÃO deve depender do Builder (AUDITORIA_FIDELIDADE_MINE_PIECE, A10/A11).
static var ativo_forcado := -1


static func ativo() -> bool:
	if ativo_forcado >= 0:
		return ativo_forcado == 1
	return OS.get_environment("SOP_BUILDER") == "1"


## Conteúdo do MOD que ainda mora no formato do Builder (skills `mp_*` e frutas `*_mine_piece` antigas). A Luta (A11) e a Nikyu (A10) já são
## NATIVAS (30/10/2026) e não passam mais por aqui.
static func e_do_mod(id: String) -> bool:
	return id.begins_with("mp_") or id.ends_with("_mine_piece")

static var _cache := {}            # id → skill validada
static var _teclas := {}           # tecla → id
static var _kit_lido := false
static var _frutas: Array[Dictionary] = []
static var _frutas_lidas := false
static var _preco_do_kit := -1     # −1 = ainda não lido


static func pasta() -> String:
	return pasta_forcada if not pasta_forcada.is_empty() else PASTA


static func recarregar() -> void:
	_preco_do_kit = -1
	_cache.clear()
	_teclas.clear()
	_kit_lido = false
	_frutas.clear()
	_frutas_lidas = false


## Publica (ou republica) a skill. Devolve {ok, erros, caminho, tecla, substituiu}:
## `substituiu` = id da skill que ocupava a tecla no kit ("" se nenhuma).
static func publicar(skill: Dictionary) -> Dictionary:
	if not ativo():
		return {"ok": false, "erros": ["Skills Builder desativado (SOP_BUILDER=1 liga)."]}
	var v := Dados.validar(skill)
	if not v.ok:
		return {"ok": false, "erros": v.erros, "caminho": "", "tecla": "", "substituiu": ""}
	var s: Dictionary = v.skill
	var id := str(s.identificacao.id)
	var r: Dictionary = Dados.salvar_em(s, pasta().path_join(id + ".json"))
	if not r.ok:
		return {"ok": false, "erros": r.erros, "caminho": "", "tecla": "", "substituiu": ""}
	_cache[id] = s
	var destino := str(s.identificacao.get("fruta", ""))
	var do_jogador := str(s.identificacao.dono) == DONO_DO_KIT
	if do_jogador and not destino.is_empty() and fruta(destino).is_empty():
		return {"ok": false, "erros": ["A fruta \"%s\" não existe no catálogo." % destino], "caminho": r.caminho, "tecla": "", "substituiu": ""}
	var tecla := ""
	var anterior := ""
	# A skill sai de qualquer tecla em que estava (kit e frutas: mudou de tecla, de
	# fruta ou de dono)...
	var teclas := teclas_do_kit()
	for t in teclas.keys():
		if teclas[t] == id:
			teclas.erase(t)
	var frutas_novas: Array[Dictionary] = []
	for f in frutas():
		var copia := f.duplicate(true)
		for t in (copia.teclas as Dictionary).keys():
			if copia.teclas[t] == id:
				(copia.teclas as Dictionary).erase(t)
		frutas_novas.append(copia)
	# ...e entra na tecla dela, no kit ou na fruta escolhida, se for do jogador.
	if do_jogador:
		tecla = str(s.ativacao.tecla)
		if destino.is_empty():
			anterior = str(teclas.get(tecla, ""))
			teclas[tecla] = id
		else:
			for f in frutas_novas:
				if str(f.id) == destino:
					anterior = str((f.teclas as Dictionary).get(tecla, ""))
					f.teclas[tecla] = id
	var rk := _gravar_kit(teclas)
	if rk.ok:
		rk = _gravar_frutas(frutas_novas)
	if not rk.ok:
		return {"ok": false, "erros": rk.erros, "caminho": r.caminho, "tecla": "", "substituiu": ""}
	return {"ok": true, "erros": [], "caminho": r.caminho, "tecla": tecla, "substituiu": anterior, "fruta": destino}


# ------------------------------------------------------------------ frutas

## O catálogo: [{id, nome, cor, teclas: {tecla: id da skill}}].
static func frutas() -> Array[Dictionary]:
	if not _frutas_lidas:
		_frutas_lidas = true
		_frutas = _ler_frutas()
	if not ativo():
		return _frutas.filter(func(f: Dictionary) -> bool: return e_do_mod(str(f.id)))
	return _frutas.duplicate(true)


static func fruta(id: String) -> Dictionary:
	for f in frutas():
		if str(f.id) == id:
			return f
	return {}


## Tecla → skill (validada, do jogador, na tecla certa) de uma fruta do catálogo.
static func skills_da_fruta(id: String) -> Dictionary:
	var f := fruta(id)
	var saida := {}
	if f.is_empty():
		return saida
	for t: String in TECLAS:
		var sid := str((f.teclas as Dictionary).get(t, ""))
		if sid.is_empty():
			continue
		var s := skill(sid)
		if s.is_empty() or str(s.identificacao.dono) != DONO_DO_KIT or str(s.ativacao.tecla) != t:
			continue
		saida[t] = s
	return saida


## "Noro Noro no Mi" → "noro_noro" (o padrão das frutas do jogo: mera_mera, goro_goro):
## minúsculas ASCII, números e _, sem o "no Mi" do fim.
static func id_de_nome(nome: String) -> String:
	var base := nome.strip_edges().to_lower().trim_suffix(" no mi")
	for de in [["á","a"],["à","a"],["â","a"],["ã","a"],["é","e"],["ê","e"],["í","i"],["ó","o"],["ô","o"],["õ","o"],["ú","u"],["ç","c"]]:
		base = base.replace(de[0], de[1])
	var saida := ""
	for c in base:
		saida += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	while saida.contains("__"):
		saida = saida.replace("__", "_")
	return saida.trim_prefix("_").trim_suffix("_").left(48)


## Cria uma fruta no catálogo (sem teclas ainda). {ok, erros, id}. `estilo` = kit de um item
## do Modo História (o Estilo de Combate Base), que não é fruta nem entra na loja.
static func criar_fruta(nome: String, cor: String, estilo := false) -> Dictionary:
	if not ativo():
		return {"ok": false, "erros": ["Skills Builder desativado (SOP_BUILDER=1 liga)."]}
	var limpo := nome.strip_edges().left(40)
	var id := id_de_nome(limpo)
	if limpo.is_empty() or id.is_empty():
		return {"ok": false, "erros": ["Dê um nome à fruta."], "id": ""}
	if id == ID_DO_KIT or SkillSystem.get_fruit_skills().has(id) or not fruta(id).is_empty():
		return {"ok": false, "erros": ["Já existe uma fruta \"%s\"." % id], "id": ""}
	var re := RegEx.new()
	re.compile("^#[0-9a-fA-F]{6}$")
	var lista := frutas()
	lista.append({"id": id, "nome": limpo, "cor": cor if re.search(cor) != null else "#ff7ad9", "teclas": {}})
	if estilo:
		lista[-1].estilo = true
	var r := _gravar_frutas(lista)
	return {"ok": r.ok, "erros": r.erros, "id": id if r.ok else ""}


## Tira uma fruta do Builder do catálogo e da loja (07/10/2026: a "fruta do gelo" de teste,
## depois de o Z dela virar o da Hie). Os arquivos das skills ficam; saem a fruta e as teclas.
static func apagar_fruta(id: String) -> Dictionary:
	if not ativo():
		return {"ok": false, "erros": ["Skills Builder desativado (SOP_BUILDER=1 liga)."]}
	var lista := frutas()
	var resto: Array[Dictionary] = []
	for f in lista:
		if str(f.id) != id:
			resto.append(f)
	if resto.size() == lista.size():
		return {"ok": false, "erros": ["Fruta desconhecida: " + id]}
	return _gravar_frutas(resto)


## RECONSTRUIR uma fruta da arena no Builder (pedido do dono, 06/10/2026: "reconstrução
## da pika pika no mi através do editor com exceção do V"). A fruta continua sendo a da
## arena (`pika_pika`): as teclas com skill publicada aqui saem do Builder, as outras
## seguem o código dela. Só para id de fruta que o jogo tem.
static func reconstruir_fruta_da_arena(id: String, nome: String, cor: String) -> Dictionary:
	if not ativo():
		return {"ok": false, "erros": ["Skills Builder desativado (SOP_BUILDER=1 liga)."]}
	if not SkillSystem.get_fruit_skills().has(id):
		return {"ok": false, "erros": ["\"%s\" não é uma fruta da arena." % id], "id": ""}
	if not fruta(id).is_empty():
		return {"ok": true, "erros": [], "id": id}
	var re := RegEx.new()
	re.compile("^#[0-9a-fA-F]{6}$")
	var lista := frutas()
	lista.append({"id": id, "nome": nome.strip_edges().left(40), "cor": cor if re.search(cor) != null else "#ffd23f",
		"teclas": {}, "reconstroi": true})
	var r := _gravar_frutas(lista)
	return {"ok": r.ok, "erros": r.erros, "id": id if r.ok else ""}


## Esta fruta é uma da arena refeita no Builder (só algumas teclas)?
static func e_reconstruida(id: String) -> bool:
	return bool(fruta(id).get("reconstroi", false))


static func _ler_frutas() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var caminho := pasta().path_join(ARQUIVO_DE_FRUTAS)
	if not FileAccess.file_exists(caminho):
		return saida
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null or f.get_length() > Dados.MAX_BYTES:
		return saida
	var json := JSON.new()
	var dados: Variant = json.data if json.parse(f.get_as_text()) == OK else null
	if not dados is Dictionary or dados.get("formato") != FORMATO_DE_FRUTAS or not dados.get("frutas") is Array:
		push_warning("[SkillsPublicadas] catálogo de frutas inválido: " + caminho)
		return saida
	var re := RegEx.new()
	re.compile("^[a-z0-9_]{1,64}$")
	for item in dados.frutas:
		if not item is Dictionary or not item.get("id") is String or re.search(item.id) == null:
			continue
		var teclas := {}
		if item.get("teclas") is Dictionary:
			for t in item.teclas:
				if str(t) in TECLAS and item.teclas[t] is String and _id_valido(item.teclas[t]):
					teclas[str(t)] = item.teclas[t]
		var entrada := {"id": item.id, "nome": str(item.get("nome", item.id)).left(40),
			"cor": str(item.get("cor", "#ff7ad9")), "teclas": teclas}
		var preco_lido: Variant = item.get("preco")
		if (preco_lido is int or preco_lido is float) and float(preco_lido) >= 0.0:
			entrada.preco = int(clampf(float(preco_lido), 0, PRECO_MAXIMO))
		# Fruta da ARENA refeita no Builder (06/10/2026): só vale para id que o jogo tem.
		# Estilo de combate (14/10/2026): kit do item "Luta" do Modo História, não é fruta à venda.
		if bool(item.get("estilo", false)):
			entrada.estilo = true
		if bool(item.get("reconstroi", false)) and SkillSystem.get_fruit_skills().has(str(item.id)):
			entrada.reconstroi = true
		saida.append(entrada)
	return saida


static func _gravar_frutas(lista: Array[Dictionary]) -> Dictionary:
	if not ativo():
		return {"ok": false, "erros": ["Skills Builder desativado (SOP_BUILDER=1 liga)."]}
	var caminho := pasta().path_join(ARQUIVO_DE_FRUTAS)
	var absoluto := ProjectSettings.globalize_path(caminho)
	DirAccess.make_dir_recursive_absolute(absoluto.get_base_dir())
	var temporario := absoluto + ".%d.tmp" % Time.get_ticks_usec()
	var f := FileAccess.open(temporario, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "erros": ["Não foi possível gravar as frutas: " + error_string(FileAccess.get_open_error())]}
	f.store_string(JSON.stringify({"formato": FORMATO_DE_FRUTAS, "versao": 1, "frutas": lista}, "\t") + "\n")
	f.close()
	var erro := DirAccess.rename_absolute(temporario, absoluto)
	if erro != OK:
		DirAccess.remove_absolute(temporario)
		return {"ok": false, "erros": ["Não foi possível salvar as frutas: " + error_string(erro)]}
	_frutas = lista.duplicate(true)
	_frutas_lidas = true
	return {"ok": true, "erros": []}


## O preço da fruta do Builder (ou do Kit, `ID_DO_KIT`) na loja do Modo História.
static func preco(fruta_id: String) -> int:
	if fruta_id == ID_DO_KIT or fruta_id.is_empty():
		if _preco_do_kit < 0:
			_preco_do_kit = _ler_preco_do_kit()
		return _preco_do_kit
	return int(fruta(fruta_id).get("preco", PRECO_PADRAO))


## Muda o preço na loja (a fruta no catálogo; o Kit no `kit.json`).
static func definir_preco(fruta_id: String, moedas: int) -> Dictionary:
	if not ativo():
		return {"ok": false, "erros": ["Skills Builder desativado (SOP_BUILDER=1 liga)."]}
	moedas = clampi(moedas, 0, PRECO_MAXIMO)
	if fruta_id == ID_DO_KIT or fruta_id.is_empty():
		_preco_do_kit = moedas
		return _gravar_kit(teclas_do_kit())
	var lista := frutas().duplicate(true)
	for f in lista:
		if str(f.id) == fruta_id:
			f.preco = moedas
			return _gravar_frutas(lista)
	return {"ok": false, "erros": ["Fruta desconhecida: " + fruta_id]}


static func _ler_preco_do_kit() -> int:
	var caminho := pasta().path_join(ARQUIVO_DO_KIT)
	if not FileAccess.file_exists(caminho):
		return PRECO_PADRAO
	var json := JSON.new()
	var dados: Variant = json.data if json.parse(FileAccess.get_file_as_string(caminho)) == OK else null
	var p: Variant = dados.get("preco") if dados is Dictionary else null
	return int(clampf(float(p), 0, PRECO_MAXIMO)) if (p is int or p is float) and float(p) >= 0.0 else PRECO_PADRAO


## A skill publicada com este id (validada), ou {} se não existe ou não valida.
static func skill(id: String) -> Dictionary:
	if not ativo() and not e_do_mod(id):
		return {}
	if _cache.has(id):
		return _cache[id]
	if not _id_valido(id):
		return {}
	var caminho := pasta().path_join(id + ".json")
	if not FileAccess.file_exists(caminho):
		return {}
	var r: Dictionary = Dados.carregar(caminho)
	if not r.ok:
		push_warning("[SkillsPublicadas] %s inválida: %s" % [caminho, "; ".join(r.erros)])
		return {}
	_cache[id] = r.skill
	return r.skill


## Tecla → id, como está no `kit.json`.
static func teclas_do_kit() -> Dictionary:
	if not ativo():
		return {}
	if not _kit_lido:
		_kit_lido = true
		_teclas = _ler_kit()
	return _teclas.duplicate()


## Tecla → skill (validada, do jogador, na tecla certa). É o que o jogo equipa.
static func kit() -> Dictionary:
	var saida := {}
	var teclas := teclas_do_kit()
	for t: String in TECLAS:
		if not teclas.has(t):
			continue
		var s := skill(str(teclas[t]))
		if s.is_empty() or str(s.identificacao.dono) != DONO_DO_KIT or str(s.ativacao.tecla) != t:
			continue
		saida[t] = s
	return saida


static func tem_kit() -> bool:
	return not kit().is_empty()


## As skills publicadas atribuídas a `quem` dentro do Usuário `dono` (ex.: Inimigo /
## "pirate_captain"). Fora do kit: é o que a IA de inimigo usa.
static func atribuidas(dono: String, quem: String) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if quem.is_empty():
		return saida
	for caminho: String in Dados.listar(pasta()):
		var id := caminho.get_file().get_basename()
		if caminho.get_file() == ARQUIVO_DO_KIT or not _id_valido(id):
			continue
		var s := skill(id)
		if s.is_empty():
			continue
		var ident: Dictionary = s.identificacao
		if str(ident.dono) == dono and str(ident.get("atribuida_a", "")) == quem:
			saida.append(s)
	return saida


## Quem ocupa a tecla no kit ("" = livre).
static func dono_da_tecla(tecla: String) -> String:
	return str(teclas_do_kit().get(tecla, ""))


static func _id_valido(id: String) -> bool:
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9_-]{1,64}$")
	return re.search(id) != null


static func _ler_kit() -> Dictionary:
	var caminho := pasta().path_join(ARQUIVO_DO_KIT)
	if not FileAccess.file_exists(caminho):
		return {}
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null or f.get_length() > Dados.MAX_BYTES:
		return {}
	var json := JSON.new()      # `parse_string` grita no console com arquivo ruim
	var dados: Variant = json.data if json.parse(f.get_as_text()) == OK else null
	if not dados is Dictionary or dados.get("formato") != FORMATO_DO_KIT or not dados.get("teclas") is Dictionary:
		push_warning("[SkillsPublicadas] kit inválido: " + caminho)
		return {}
	var saida := {}
	for t in dados.teclas:
		var id: Variant = dados.teclas[t]
		if str(t) in TECLAS and id is String and _id_valido(id):
			saida[str(t)] = id
	return saida


static func _gravar_kit(teclas: Dictionary) -> Dictionary:
	if not ativo():
		return {"ok": false, "erros": ["Skills Builder desativado (SOP_BUILDER=1 liga)."]}
	var caminho := pasta().path_join(ARQUIVO_DO_KIT)
	var absoluto := ProjectSettings.globalize_path(caminho)
	DirAccess.make_dir_recursive_absolute(absoluto.get_base_dir())
	var temporario := absoluto + ".%d.tmp" % Time.get_ticks_usec()
	var f := FileAccess.open(temporario, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "erros": ["Não foi possível gravar o kit: " + error_string(FileAccess.get_open_error())]}
	var ordenado := {}
	for t: String in TECLAS:
		if teclas.has(t):
			ordenado[t] = teclas[t]
	f.store_string(JSON.stringify({"formato": FORMATO_DO_KIT, "versao": VERSAO_DO_KIT, "teclas": ordenado,
		"preco": preco(ID_DO_KIT)}, "\t") + "\n")
	f.close()
	var erro := DirAccess.rename_absolute(temporario, absoluto)
	if erro != OK:
		DirAccess.remove_absolute(temporario)
		return {"ok": false, "erros": ["Não foi possível salvar o kit: " + error_string(erro)]}
	_teclas = ordenado
	_kit_lido = true
	return {"ok": true, "erros": []}
