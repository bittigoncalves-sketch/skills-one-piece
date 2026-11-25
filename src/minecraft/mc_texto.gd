class_name McTexto
extends RefCounted
## `Component` do Minecraft (`Component.literal`, `getDisplayName()`): só o texto.

var texto := ""


static func de(t: Variant) -> McTexto:
	var c := McTexto.new()
	c.texto = str(t)
	return c


func getString() -> String: return texto
func copy() -> McTexto: return de(texto)
func withStyle(_estilo: Variant) -> McTexto: return self
func append(t: Variant) -> McTexto:
	texto += t.texto if t is McTexto else str(t)
	return self
func _to_string() -> String: return texto


## Textos do mod (en_us.json extraído em `mapas/east_blue/textos_do_mod.json`). SÓ para exibir ao jogador:
## as procedures comparam as chaves cruas entre si (ex.: nome do golpe), então `getString()` não traduz.
static var _textos: Dictionary = {}
static func traduzir(chave: String) -> String:
	if _textos.is_empty():
		var f := FileAccess.open("res://mapas/east_blue/textos_do_mod.json", FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			_textos = d if d is Dictionary else {"": ""}
	if _textos.has(chave):
		return str(_textos[chave])
	# Nome composto do mod (`Component.translatable(a).getString() + ": " + Component.translatable(b).getString()`): o texto sai com as chaves cruas
	# (ex. "entity.minepiece.biscuit_warrrior: minepiece.technique.shanks7"); traduz cada chave encontrada.
	if chave.contains(".") and not chave.contains(" "):
		return chave
	var rx := RegEx.create_from_string("[a-z0-9_]+(?:\\.[a-z0-9_]+)+")
	var saida := chave
	for m in rx.search_all(chave):
		var k := m.get_string()
		if _textos.has(k):
			saida = saida.replace(k, str(_textos[k]))
	return saida
