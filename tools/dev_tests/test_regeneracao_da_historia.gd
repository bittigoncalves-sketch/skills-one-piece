extends SceneTree
## Regeneração de vida e energia (08/11/2026, pedido do dono): o Modo História regenera REGENERACAO_DA_HISTORIA vezes a regra original;
## a arena e os testes seguem em 1.0.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_regeneracao_da_historia.gd
func _init() -> void:
	var saida := []
	for f in [1.0, 3.0]:
		var h := HealthController.new()
		h.vida_max = 100.0
		h.energia_max = 600.0
		h.vida = 50.0
		h.energia = 100.0
		h.fator_de_regeneracao = f
		for i in 600:
			h.regenerar(1.0 / 60.0)
		saida.append([h.vida - 50.0, h.energia - 100.0])
	var ok_base := absf(saida[0][0] - 5.0) < 0.01 and absf(saida[0][1] - 30.0) < 0.01
	var ok_tres := absf(saida[1][0] - 15.0) < 0.01 and absf(saida[1][1] - 90.0) < 0.01
	print("  %s regra original (fator 1): vida +%.1f, energia +%.1f em 10 s" % ["✅" if ok_base else "❌", saida[0][0], saida[0][1]])
	print("  %s fator 3: vida +%.1f, energia +%.1f em 10 s" % ["✅" if ok_tres else "❌", saida[1][0], saida[1][1]])
	var script: GDScript = load("res://src/historia/ModoHistoria.gd")
	var constante_ok: bool = float(script.get_script_constant_map()["REGENERACAO_DA_HISTORIA"]) == 3.0
	print("  %s o Modo História usa 3×" % ("✅" if constante_ok else "❌"))
	var falhou := not (ok_base and ok_tres and constante_ok)
	print("\nREGENERACAO_DA_HISTORIA %s" % ("FALHOU" if falhou else "3/3"))
	quit(1 if falhou else 0)
