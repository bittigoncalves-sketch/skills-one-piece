class_name LayoutDeJanelas
extends RefCounted
# ============================================================================
#  LAYOUT DE JANELAS — o que o EDITOR DE JANELAS mudou nas janelas do Modo
#  História, e a aplicação disso no jogo (05/10/2026).
#
#  Pedido do dono: no editor de mapa, um modo "Janelas" (ao lado das hitboxes) em
#  que cada janela do jogo se edita como num canvas. Decisões dele: muda POSIÇÃO,
#  TAMANHO, TEXTO e APARÊNCIA (cor do texto, tamanho da fonte, cor de fundo); vale
#  para as janelas do Modo História; fica salvo NO PROJETO (vale para quem jogar).
#
#  O arquivo guarda só o que mudou, por janela e por elemento. O ENDEREÇO do elemento
#  (`caminho_de`) vai da raiz da janela até ele, um passo por nível: o NOME quando o nó
#  tem nome fixo, "#n" (posição entre os irmãos) quando foi criado sem nome — o Godot
#  batiza esses de "@Label@123", com número que muda a cada execução. "." = a janela.
#  Quem monta uma janela chama `aplicar` depois de se posicionar e de refazer o
#  conteúdo; endereço que não existe mais é ignorado. Linha gerada por dado (lista de
#  pets, peixes…) é endereçada pela POSIÇÃO na lista.
#
#  Campos de um elemento: pos [x, y] · tam [l, a] · texto · fonte (px) ·
#  cor_texto "#rrggbbaa" · cor_fundo "#rrggbbaa".
#  Elemento DENTRO de uma lista (container) não tem posição livre: a lista manda; o
#  tamanho vira o tamanho mínimo dele.
# ============================================================================

const CAMINHO := "res://mapas/janelas/layout.json"
const FORMATO := "skills-one-piece/janelas"
const VERSAO := 1
const CAMPOS: Array[String] = ["pos", "tam", "texto", "fonte", "cor_texto", "cor_fundo"]

## Testes: outro arquivo (nunca o do dono). "" = o do projeto.
static var caminho_forcado := ""
static var _dados: Dictionary = {}
static var _lido := false


static func caminho() -> String:
	return caminho_forcado if not caminho_forcado.is_empty() else CAMINHO


static func recarregar() -> void:
	_dados = {}
	_lido = true
	var c := caminho()
	if not FileAccess.file_exists(c):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(c)) != OK or not (json.data is Dictionary) \
			or json.data.get("formato") != FORMATO or not (json.data.get("janelas") is Dictionary):
		push_warning("[Janelas] layout ilegível, ignorado: %s" % c)
		return
	_dados = json.data["janelas"]


static func _garantir() -> void:
	if not _lido:
		recarregar()


## O que mudou em `janela` → {caminho do nó: {campo: valor}}.
static func da_janela(janela: String) -> Dictionary:
	_garantir()
	return _dados.get(janela, {})


static func do_elemento(janela: String, no: String) -> Dictionary:
	return da_janela(janela).get(no, {})


## Aplica tudo o que mudou em `janela` sobre `raiz` (a janela já montada).
static func aplicar(janela: String, raiz: Control) -> void:
	if raiz == null:
		return
	var muda := da_janela(janela)
	for caminho_no: String in muda:
		var alvo := no_por_caminho(raiz, caminho_no) as Control
		if alvo != null:
			aplicar_no(alvo, muda[caminho_no])


## Endereço estável de `no` dentro da janela `raiz` (ver o cabeçalho).
static func caminho_de(raiz: Node, no: Node) -> String:
	if no == raiz:
		return "."
	var passos: PackedStringArray = []
	var atual := no
	while atual != null and atual != raiz:
		var pai := atual.get_parent()
		if pai == null:
			return ""
		var nome := String(atual.name)
		passos.insert(0, ("#%d" % atual.get_index()) if nome.begins_with("@") else nome)
		atual = pai
	return "/".join(passos) if atual == raiz else ""


static func no_por_caminho(raiz: Node, caminho_no: String) -> Node:
	if caminho_no == "." or caminho_no.is_empty():
		return raiz
	var atual := raiz
	for passo in caminho_no.split("/"):
		if atual == null:
			return null
		if passo.begins_with("#"):
			var i := passo.substr(1).to_int()
			atual = atual.get_child(i) if i >= 0 and i < atual.get_child_count() else null
		else:
			atual = atual.get_node_or_null(NodePath(passo))
	return atual


static func aplicar_no(alvo: Control, campos: Dictionary) -> void:
	var em_lista := alvo.get_parent() is Container
	if campos.has("tam"):
		var t := _vec(campos["tam"])
		if em_lista:
			alvo.custom_minimum_size = t
		else:
			alvo.size = t
	if campos.has("pos") and not em_lista:
		alvo.position = _vec(campos["pos"])
	if campos.has("texto") and "text" in alvo:
		alvo.set("text", str(campos["texto"]))
	if campos.has("fonte"):
		alvo.add_theme_font_size_override("font_size", int(campos["fonte"]))
	if campos.has("cor_texto"):
		var c := Color.from_string(str(campos["cor_texto"]), Color.WHITE)
		alvo.add_theme_color_override("font_color", c)
		if alvo is Button:
			alvo.add_theme_color_override("font_hover_color", c)
			alvo.add_theme_color_override("font_pressed_color", c)
	if campos.has("cor_fundo"):
		pintar_fundo(alvo, Color.from_string(str(campos["cor_fundo"]), Color.BLACK))


## Fundo: ColorRect pela cor; painel e botão pela caixa de estilo (uma CÓPIA, para não
## pintar todas as janelas que dividem o mesmo estilo).
static func pintar_fundo(alvo: Control, cor: Color) -> void:
	if alvo is ColorRect:
		(alvo as ColorRect).color = cor
		return
	var chaves: Array[String] = ["panel"]
	if alvo is Button:
		chaves = ["normal", "hover", "pressed"]
	for chave in chaves:
		var atual := alvo.get_theme_stylebox(chave)
		var nova: StyleBoxFlat = atual.duplicate() if atual is StyleBoxFlat else StyleBoxFlat.new()
		nova.bg_color = cor
		alvo.add_theme_stylebox_override(chave, nova)


## Grava (na memória) um campo de um elemento. `salvar` escreve o arquivo.
static func gravar(janela: String, no: String, campo: String, valor: Variant) -> void:
	_garantir()
	if not CAMPOS.has(campo):
		return
	var j: Dictionary = _dados.get(janela, {})
	var e: Dictionary = j.get(no, {})
	e[campo] = _para_json(valor)
	j[no] = e
	_dados[janela] = j


## Volta o elemento ao original (esquece tudo o que mudou nele).
static func esquecer(janela: String, no: String) -> void:
	_garantir()
	if _dados.has(janela):
		(_dados[janela] as Dictionary).erase(no)
		if (_dados[janela] as Dictionary).is_empty():
			_dados.erase(janela)


static func salvar() -> Error:
	_garantir()
	var c := caminho()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(c.get_base_dir()))
	var f := FileAccess.open(c, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"formato": FORMATO, "versao": VERSAO, "janelas": _dados}, "\t", false))
	f.close()
	return OK


static func _para_json(v: Variant) -> Variant:
	if v is Vector2:
		return [snappedf(v.x, 0.5), snappedf(v.y, 0.5)]
	if v is Color:
		return "#" + (v as Color).to_html(true)
	if v is float:
		return snappedf(v, 0.5)
	return v


static func _vec(v: Variant) -> Vector2:
	if v is Array and (v as Array).size() == 2:
		return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO
