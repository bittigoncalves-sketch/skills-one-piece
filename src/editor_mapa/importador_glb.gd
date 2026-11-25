class_name ImportadorDeModelos
extends RefCounted
# ============================================================================
#  IMPORTADOR DE .glb — do computador para a biblioteca da loja. Sem nó.
#
#  Um arquivo só entra se passar em TUDO, nesta ordem (a primeira falha é o
#  motivo que aparece para a pessoa):
#
#    1. extensão .glb e tamanho até o teto;
#    2. cabeçalho binário glTF versão 2, com o comprimento declarado batendo com
#       o do arquivo (arquivo truncado para aqui, não no meio da leitura);
#    3. nada de arquivo EXTERNO (buffer ou imagem com "uri" que não seja data:) —
#       só o .glb é copiado, e a textura que morasse ao lado sumiria;
#    4. o Godot consegue gerar a cena, e ela tem pelo menos uma malha com volume.
#
#  Mesmo conteúdo (SHA-256) importado de novo não duplica: devolve o que já existe.
#  A cópia é conferida pelo SHA depois de gravada.
# ============================================================================

# Teto de partida para modelo de cenário. Gatilho: primeiro modelo legítimo
# recusado por tamanho — aí medir o tempo de importação e de montagem dele.
const LIMITE_BYTES := 150 * 1024 * 1024
const MAGICO_GLTF := 0x46546C67       # "glTF"
const CHUNK_JSON := 0x4E4F534A        # "JSON"


## {ok, erro, json} — `json` é o cabeçalho glTF já lido (para a checagem 3).
static func verificar(caminho: String, limite: int = LIMITE_BYTES) -> Dictionary:
	if caminho.get_extension().to_lower() != "glb":
		return _falha("não é .glb")
	if not FileAccess.file_exists(caminho):
		return _falha("o arquivo não existe")
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return _falha("sem permissão de leitura (%s)" % error_string(FileAccess.get_open_error()))
	var bytes := f.get_length()
	if bytes > limite:
		return _falha("tem %s; o teto da loja é %s" % [String.humanize_size(bytes), String.humanize_size(limite)])
	if bytes < 20:
		return _falha("arquivo vazio ou truncado")
	if f.get_32() != MAGICO_GLTF:
		return _falha("não é um glTF binário (cabeçalho errado)")
	var versao := f.get_32()
	if versao != 2:
		return _falha("glTF versão %d; só a versão 2 é aceita" % versao)
	if f.get_32() != bytes:
		return _falha("arquivo truncado (o tamanho declarado não bate)")
	var tamanho_json := f.get_32()
	if f.get_32() != CHUNK_JSON or tamanho_json <= 0 or tamanho_json > bytes - 20:
		return _falha("estrutura glTF inválida")
	var json := JSON.new()
	if json.parse(f.get_buffer(tamanho_json).get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return _falha("o cabeçalho JSON do glTF é ilegível")
	var externos := _uris_externas(json.data)
	if not externos.is_empty():
		return _falha("usa arquivos externos (%s) — exporte o .glb com tudo embutido" % ", ".join(externos))
	return {"ok": true, "erro": "", "json": json.data}


## {ok, id, erro, repetido}. `origem` é caminho do SO (vem da janela de arquivos).
static func importar(bib: BibliotecaDeModelos, origem: String, limite: int = LIMITE_BYTES) -> Dictionary:
	var nome := origem.get_file()
	var v := verificar(origem, limite)
	if not v["ok"]:
		return {"ok": false, "id": "", "erro": "%s: %s" % [nome, v["erro"]], "repetido": false}

	var sha := FileAccess.get_sha256(origem)
	var existente := bib.id_por_sha(sha)
	if not existente.is_empty():
		return {"ok": true, "id": existente, "erro": "", "repetido": true}

	var cena := BibliotecaDeModelos.carregar_glb(origem)
	if cena == null:
		return {"ok": false, "id": "", "erro": "%s: o Godot não conseguiu ler o modelo" % nome, "repetido": false}
	var medida := BibliotecaDeModelos.medir(cena)
	cena.free()
	var caixa: AABB = medida["aabb"]
	if medida["malhas"] == 0 or not caixa.size.is_finite() or caixa.size.length() < 0.001:
		return {"ok": false, "id": "", "erro": "%s: não tem malha visível" % nome, "repetido": false}

	var id := bib.novo_id(nome)
	var destino := bib.caminho_do_arquivo(id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bib.raiz))
	var erro := DirAccess.copy_absolute(origem, ProjectSettings.globalize_path(destino))
	if erro != OK or FileAccess.get_sha256(destino) != sha:
		if FileAccess.file_exists(destino):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(destino))
		return {"ok": false, "id": "", "erro": "%s: a cópia para a loja falhou (%s)" % [nome, error_string(erro)], "repetido": false}

	# Um lado da caixa pode ser zero (um plano). A peça precisa de volume mínimo
	# para o gizmo e para a escala não dividirem por zero.
	var tamanho := caixa.size.max(Vector3.ONE * MapaArquivo.TAMANHO_MIN)
	erro = bib.adicionar({"id": id, "nome": nome.get_basename(), "sha256": sha,
		"centro": caixa.get_center(), "tamanho": tamanho, "triangulos": medida["triangulos"]})
	if erro != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(destino))
		return {"ok": false, "id": "", "erro": "%s: não foi possível gravar o catálogo (%s)" % [nome, error_string(erro)], "repetido": false}
	return {"ok": true, "id": id, "erro": "", "repetido": false}


## Os .glb diretamente dentro da pasta (subpastas não entram), em ordem alfabética.
static func glbs_da_pasta(pasta: String) -> PackedStringArray:
	var achados := PackedStringArray()
	var dir := DirAccess.open(pasta)
	if dir == null:
		return achados
	for arquivo in dir.get_files():
		if arquivo.get_extension().to_lower() == "glb":
			achados.append(pasta.path_join(arquivo))
	achados.sort()
	return achados


static func _uris_externas(gltf: Dictionary) -> PackedStringArray:
	var externos := PackedStringArray()
	for grupo in ["buffers", "images"]:
		var lista: Variant = gltf.get(grupo, [])
		if not (lista is Array):
			continue
		for item in lista:
			if item is Dictionary and item.has("uri"):
				var uri := str(item["uri"])
				if not uri.begins_with("data:"):
					externos.append(uri.get_file().left(40))
	return externos


static func _falha(motivo: String) -> Dictionary:
	return {"ok": false, "erro": motivo, "json": {}}
