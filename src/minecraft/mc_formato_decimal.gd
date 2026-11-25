class_name McFormatoDecimal
extends RefCounted
## `java.text.DecimalFormat(padrão)` do mod: `"0.##"`, `"#.##"`, `"0.0"`, `"#"`… Só o que as procedures usam: parte inteira
## com no mínimo tantos dígitos quanto os `0` antes do ponto; decimais com no mínimo os `0` e no máximo `0` + `#`.
## Arredonda HALF_EVEN (o padrão do Java: 0,125 → 0,12; 0,135 → 0,14) e usa SEMPRE o ponto — o resultado vai para
## comandos em texto, onde a vírgula de um locale quebraria.

var _min_int := 1
var _min_dec := 0
var _max_dec := 0


static func de(padrao: Variant) -> McFormatoDecimal:
	var f := McFormatoDecimal.new()
	var p := str(padrao)
	var partes := p.split(".", true, 1)
	f._min_int = partes[0].count("0")
	if partes.size() > 1:
		f._min_dec = partes[1].count("0")
		f._max_dec = partes[1].count("0") + partes[1].count("#")
	return f


func format(x: Variant) -> String:
	var v := float(x)
	if is_nan(v):
		return "NaN"
	if is_inf(v):
		return "∞" if v > 0.0 else "-∞"
	var escala := pow(10.0, _max_dec)
	var bruto := absf(v) * escala
	var piso := floorf(bruto)
	var resto := bruto - piso
	var n := piso
	if absf(resto - 0.5) < 1.0e-9:
		n = piso if int(piso) % 2 == 0 else piso + 1.0       # metade: vai para o par
	elif resto > 0.5:
		n = piso + 1.0
	var inteiro := int(n / escala) if _max_dec > 0 else int(n)
	var dec := int(n - float(inteiro) * escala) if _max_dec > 0 else 0
	var txt_int := str(inteiro).pad_zeros(maxi(_min_int, 1)) if _min_int > 0 or inteiro > 0 else ""
	var txt_dec := str(dec).pad_zeros(_max_dec) if _max_dec > 0 else ""
	while txt_dec.length() > _min_dec and txt_dec.ends_with("0"):
		txt_dec = txt_dec.substr(0, txt_dec.length() - 1)
	var saida := txt_int + ("." + txt_dec if not txt_dec.is_empty() else "")
	if saida.is_empty():
		saida = "0"
	return ("-" if v < 0.0 and (inteiro != 0 or dec != 0) else "") + saida
