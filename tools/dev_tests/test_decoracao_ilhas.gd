extends SceneTree
## Decoração das demais ilhas (18/11/2026): cada ilha tem peças `deco_<ilha>_*` dentro da própria placa, ids únicos, nenhuma sobre construção existente.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_decoracao_ilhas.gd
const MINIMO := {"east_blue": 200, "vila_foosha": 100, "vila_shimotsuki": 100, "marinha_153": 50, "acampamento_pirata": 40, "acampamento_bandido": 40, "water_seven": 90, "wano": 90, "shandora": 100}
func _init() -> void:
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	var falhas := 0
	if not lido["ok"]:
		print("❌ mapa inválido")
		quit(1)
		return
	var pecas: Array = lido["mapa"]["pecas"]
	var ids := {}
	var bases := {}
	for p: Dictionary in pecas:
		if p["tipo"] == "caixa" and String(p["id"]).begins_with("baseplate_"):
			bases[String(p["id"]).trim_prefix("baseplate_")] = p
		ids[p["id"]] = ids.has(p["id"])
	var repetidos := ids.values().count(true)
	print(("  ✅ " if repetidos == 0 else "  ❌ ") + "ids únicos (%d repetidos)" % repetidos)
	falhas += 1 if repetidos > 0 else 0
	for ilha: String in MINIMO:
		var b: Dictionary = bases.get(ilha, {})
		var minhas := pecas.filter(func(p): return String(p["id"]).begins_with("deco_%s_" % ilha))
		var fora := 0
		var sobre := 0
		for p: Dictionary in minhas:
			var t: Vector3 = b["tamanho"]
			if absf(p["posicao"].x - b["posicao"].x) > t.x * 0.5 or absf(p["posicao"].z - b["posicao"].z) > t.z * 0.5:
				fora += 1
			for o: Dictionary in pecas:
				if o["tipo"] != "modelo" or String(o["id"]).begins_with("deco_") or not (String(o["modelo"]).begins_with("mpe_") or String(o["modelo"]) in ["blacksmith", "market_stalls_compact"]):
					continue
				var l := (Vector2(p["posicao"].x, p["posicao"].z) - Vector2(o["posicao"].x, o["posicao"].z)).rotated(deg_to_rad(o["rotacao_graus"].y))
				if absf(l.x) < o["tamanho"].x * 0.5 and absf(l.y) < o["tamanho"].z * 0.5:
					sobre += 1
		var ok := minhas.size() >= int(MINIMO[ilha]) and fora == 0 and sobre == 0
		print(("  ✅ " if ok else "  ❌ ") + "%s: %d peças (mín. %d), %d fora da placa, %d sobre construção" % [ilha, minhas.size(), MINIMO[ilha], fora, sobre])
		falhas += 0 if ok else 1
	print("DECORACAO_ILHAS %d falhas" % falhas)
	quit(1 if falhas > 0 else 0)
