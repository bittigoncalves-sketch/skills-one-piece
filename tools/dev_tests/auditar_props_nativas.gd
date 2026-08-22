extends SceneTree

# ============================================================================
# Auditor de propriedades inexistentes em tipos nativos do Godot.
# Uso: timeout 180 godot --headless --path . --script tools/dev_tests/auditar_props_nativas.gd
# ============================================================================

const PULAR := [".godot", "export_templates", "graphify-out", ".agents", "assets", ".git", ".local_data", "disabled"]

var re_novo_tipado: RegEx      # var x: Tipo = Tipo.new()
var re_novo_inferido: RegEx    # var x := Tipo.new()
var re_novo_simples: RegEx     # var x = Tipo.new()
var re_decl_tipada: RegEx      # var x: Tipo  (com ou sem valor)
var re_cast: RegEx             # var x := algo as Tipo
var re_reatrib: RegEx          # x = Tipo.new()
var re_membro_novo: RegEx      # a.b = Tipo.new()
var re_uso: RegEx              # x.prop = / x.prop.y =
var re_uso2: RegEx             # a.b.prop =
var re_func: RegEx
var re_params: RegEx

var achados := 0
var arquivos := 0
# Bases genéricas: variáveis desse tipo quase sempre guardam instância COM script
# anexado (Player.gd etc.), então a propriedade "faltante" vem do script, não do
# ClassDB. Reportar isso é ruído puro.
const BASES_GENERICAS := ["Object", "RefCounted", "Node", "Node2D", "Node3D", "CanvasItem",
	"Control", "Resource", "CharacterBody3D", "RigidBody3D", "Area3D", "StaticBody3D"]
var alta: Array[String] = []
var baixa: Array[String] = []

func _init() -> void:
	var ID := "[A-Za-z_][A-Za-z0-9_]*"
	var OP := "(?:=[^=]|\\+=|-=|\\*=|/=|=$)"
	re_novo_tipado   = RegEx.create_from_string("^\\s*(?:@onready\\s+)?var\\s+(%s)\\s*:\\s*%s\\s*=\\s*(%s)\\.new\\(" % [ID, ID, ID])
	re_novo_inferido = RegEx.create_from_string("^\\s*(?:@onready\\s+)?var\\s+(%s)\\s*:=\\s*(%s)\\.new\\(" % [ID, ID])
	re_novo_simples  = RegEx.create_from_string("^\\s*(?:@onready\\s+)?var\\s+(%s)\\s*=\\s*(%s)\\.new\\(" % [ID, ID])
	re_cast          = RegEx.create_from_string("^\\s*(?:@onready\\s+)?var\\s+(%s)\\s*:?=\\s*.+\\s+as\\s+(%s)\\s*$" % [ID, ID])
	re_decl_tipada   = RegEx.create_from_string("^\\s*(?:@onready\\s+)?var\\s+(%s)\\s*:\\s*(%s)\\s*(?:=|$)" % [ID, ID])
	re_reatrib       = RegEx.create_from_string("^\\s*(%s)\\s*=\\s*(%s)\\.new\\(" % [ID, ID])
	re_membro_novo   = RegEx.create_from_string("^\\s*(%s\\.%s)\\s*=\\s*(%s)\\.new\\(" % [ID, ID, ID])
	re_uso           = RegEx.create_from_string("^\\s*(%s)\\.(%s)\\s*%s" % [ID, ID, OP])
	re_uso2          = RegEx.create_from_string("^\\s*(%s\\.%s)\\.(%s)\\s*%s" % [ID, ID, ID, OP])
	re_func          = RegEx.create_from_string("^(?:static\\s+)?func\\s+")
	re_params        = RegEx.create_from_string("(%s)\\s*:\\s*(%s)" % [ID, ID])

	var lista: Array[String] = []
	_coletar("res://", lista)
	lista.sort()
	for f in lista:
		_analisar(f)
	print("\n########## CONFIANCA ALTA (tipo veio de `Tipo.new()`) ##########")
	for l in alta:
		print(l)
	print("\n########## CONFIANCA BAIXA (tipo veio de anotacao/cast; pode ter script) ##########")
	for l in baixa:
		print(l)
	print("\n=== %d arquivos .gd varridos | %d achados alta | %d achados baixa ===" % [arquivos, alta.size(), baixa.size()])
	quit()

func _coletar(caminho: String, saida: Array[String]) -> void:
	var d := DirAccess.open(caminho)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var full := caminho.path_join(n)
		if d.current_is_dir():
			if not PULAR.has(n) and not n.begins_with("."):
				_coletar(full, saida)
		elif n.ends_with(".gd"):
			saida.append(full)
		n = d.get_next()
	d.list_dir_end()

var _cache_props := {}
func _props_validas(tipo: String) -> PackedStringArray:
	if _cache_props.has(tipo):
		return _cache_props[tipo]
	var out := PackedStringArray()
	if ClassDB.class_exists(tipo):
		for p in ClassDB.class_get_property_list(tipo, false):
			out.append(String(p.name))
	_cache_props[tipo] = out
	return out

func _analisar(caminho: String) -> void:
	var fa := FileAccess.open(caminho, FileAccess.READ)
	if fa == null:
		return
	arquivos += 1
	var linhas := fa.get_as_text().split("\n")
	fa.close()

	var tipos_classe := {}
	var tipos_func := {}

	for i in range(linhas.size()):
		var ln: String = linhas[i]
		var strip := ln.strip_edges()
		if strip.begins_with("#") or strip.is_empty():
			continue

		if re_func.search(strip) != null:
			tipos_func.clear()
			# parâmetros tipados viram fonte de tipo
			var ab := strip.find("(")
			var fb := strip.rfind(")")
			if ab >= 0 and fb > ab:
				for pm in re_params.search_all(strip.substr(ab + 1, fb - ab - 1)):
					tipos_func[pm.get_string(1)] = pm.get_string(2) + "|B"
			continue

		var indentado := ln.begins_with("\t") or ln.begins_with(" ")
		var alvo: Dictionary = tipos_func if indentado else tipos_classe

		var m := re_novo_tipado.search(ln)
		if m == null:
			m = re_novo_inferido.search(ln)
		if m == null:
			m = re_novo_simples.search(ln)
		if m != null:
			alvo[m.get_string(1)] = m.get_string(2) + "|A"
			continue
		m = re_cast.search(ln)
		if m != null:
			alvo[m.get_string(1)] = m.get_string(2) + "|B"
			continue
		m = re_decl_tipada.search(ln)
		if m != null:
			alvo[m.get_string(1)] = m.get_string(2) + "|B"
			continue
		m = re_membro_novo.search(ln)
		if m != null:
			alvo[m.get_string(1)] = m.get_string(2) + "|A"
			# não damos `continue`: a linha também é um uso de `a.b`
		m = re_reatrib.search(ln)
		if m != null:
			var nome := m.get_string(1)
			if tipos_func.has(nome):
				tipos_func[nome] = m.get_string(2) + "|A"
			elif tipos_classe.has(nome):
				tipos_classe[nome] = m.get_string(2) + "|A"
			else:
				alvo[nome] = m.get_string(2) + "|A"
			continue

		# ---- usos ----
		_checar(caminho, i, strip, ln, re_uso2, tipos_func, tipos_classe)
		_checar(caminho, i, strip, ln, re_uso, tipos_func, tipos_classe)

func _checar(caminho: String, i: int, strip: String, ln: String, re: RegEx, tf: Dictionary, tc: Dictionary) -> void:
	var m := re.search(ln)
	if m == null:
		return
	var v := m.get_string(1)
	var prop := m.get_string(2)
	var reg := ""
	if tf.has(v):
		reg = tf[v]
	elif tc.has(v):
		reg = tc[v]
	if reg == "":
		return
	var partes := reg.split("|")
	var tipo := partes[0]
	var conf := partes[1]
	if not ClassDB.class_exists(tipo):
		return
	if conf == "B" and BASES_GENERICAS.has(tipo):
		return
	var validas := _props_validas(tipo)
	if validas.has(prop):
		return
	if ClassDB.class_has_method(tipo, "set_" + prop):
		return
	achados += 1
	var parecidas := PackedStringArray()
	for pv in validas:
		if pv.contains(prop) or prop.contains(pv) or pv.similarity(prop) > 0.6:
			parecidas.append(pv)
	var msg := "%s:%d  [%s] propriedade INVALIDA '%s'\n    linha: %s" % [caminho, i + 1, tipo, prop, strip]
	if parecidas.size() > 0:
		msg += "\n    parecidas: %s" % ", ".join(parecidas)
	if conf == "A":
		alta.append(msg)
	else:
		baixa.append(msg)
