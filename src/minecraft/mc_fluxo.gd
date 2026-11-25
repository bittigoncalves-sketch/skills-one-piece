class_name McFluxo
extends RefCounted
## `Stream` do Java (`lista.stream().sorted(c).findFirst().orElse(null)` — o "mais perto" do
## MCreator). Comparador: `Comparator.comparingDouble(f)` vira a FUNÇÃO-CHAVE (`McFluxo.Comparador`).

var itens: Array = []


static func de(x: Variant) -> McFluxo:
	var f := McFluxo.new()
	f.itens = (x.values() if x is Dictionary else (x as Array).duplicate()) if x != null else []
	return f


class Comparador:
	extends RefCounted
	var chave: Callable
	var invertido := false
	func reversed() -> Comparador:
		var c := Comparador.new()
		c.chave = chave
		c.invertido = not invertido
		return c


static func comparando(chave: Callable) -> Comparador:
	var c := Comparador.new()
	c.chave = chave
	return c


func sorted(c: Variant = null) -> McFluxo:
	var r := de(itens)
	if c is Comparador:
		var cmp := c as Comparador
		r.itens.sort_custom(func(a, b): return (cmp.chave.call(a) > cmp.chave.call(b)) if cmp.invertido else (cmp.chave.call(a) < cmp.chave.call(b)))
	else:
		r.itens.sort()
	return r


func filter(f: Callable) -> McFluxo:
	var r := McFluxo.new()
	r.itens = itens.filter(func(x): return bool(f.call(x)))
	return r


func map(f: Callable) -> McFluxo:
	var r := McFluxo.new()
	r.itens = itens.map(f)
	return r


func limit(n: int) -> McFluxo:
	var r := McFluxo.new()
	r.itens = itens.slice(0, n)
	return r


func findFirst() -> McEntidade.Opcional:
	var o := McEntidade.Opcional.new()
	o.valor = itens[0] if not itens.is_empty() else null
	return o


func findAny() -> McEntidade.Opcional: return findFirst()
func anyMatch(f: Callable) -> bool: return itens.any(func(x): return bool(f.call(x)))
func allMatch(f: Callable) -> bool: return itens.all(func(x): return bool(f.call(x)))
func noneMatch(f: Callable) -> bool: return not anyMatch(f)
func count() -> int: return itens.size()
func toList() -> Array: return itens.duplicate()
func forEach(f: Callable) -> void:
	for x in itens:
		f.call(x)
