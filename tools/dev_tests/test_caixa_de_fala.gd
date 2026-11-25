extends SceneTree
# Teste da caixa de fala cinematográfica (21/11/2026). Rodar:
#   godot --headless --path . --script tools/dev_tests/test_caixa_de_fala.gd
var _falhas := 0

func _ok(c: bool, m: String) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _falhas += 1

func _init() -> void:
	await process_frame
	print("\n===== CAIXA DE FALA =====")
	# Dados: fallback quando não há arquivo/estado.
	var padrao: Array[Dictionary] = [DialogosDeNpc.linha("A", "oi")]
	_ok(DialogosDeNpc.linhas("inexistente_xyz", "primeira", padrao) == padrao, "sem arquivo → padrão")
	var treino := DialogosDeNpc.linhas("treino", "estado_que_nao_existe", padrao)
	_ok(treino == padrao, "estado ausente → padrão")
	var caixa := CaixaDeFalaCinematografica.new()
	root.add_child(caixa)
	await process_frame
	var fim := [0]
	var duas: Array[Dictionary] = [DialogosDeNpc.linha("Instrutor", "Primeira fala longa o bastante."), DialogosDeNpc.linha("Instrutor", "Segunda.")]
	caixa.tocar(duas, func(): fim[0] += 1)
	_ok(caixa.ativa() and caixa.visible, "tocar liga a cena")
	_ok(not caixa.completa(), "texto começa incompleto (máquina de escrever)")
	caixa.avancar()
	_ok(caixa.completa() and caixa.linha_atual()["texto"].begins_with("Primeira"), "1º avançar completa a linha")
	caixa.avancar()
	_ok(caixa.linha_atual()["texto"] == "Segunda.", "2º avançar vai à próxima")
	caixa.avancar(); caixa.avancar()
	for i in 30:
		await process_frame
	_ok(not caixa.ativa() and fim[0] == 1, "fim roda o callback uma vez")
	# Pular com ESC-equivalente
	caixa.tocar(duas, func(): fim[0] += 1)
	caixa.pular()
	for i in 30:
		await process_frame
	_ok(not caixa.ativa() and fim[0] == 2, "pular encerra e chama o callback")
	# Vazio não trava
	var vazio: Array[Dictionary] = []
	caixa.tocar(vazio, func(): fim[0] += 1)
	_ok(not caixa.ativa() and fim[0] == 3, "sem linhas → callback imediato")
	print("\n" + ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)
