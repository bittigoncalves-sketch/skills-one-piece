extends SceneTree
# D. Política de teste (15/11/2026): sem `exigir_escolha_de_corpo`, um teste automatizado que inicia a história com save NOVO não fica preso na tela de gênero:
# `ModoHistoria` escolhe `corpo_de_teste`, SALVA no progresso e o jogador nasce com esse corpo. É o que mantém de pé os 263 testes que chamam `start_story()`.
#   godot --headless --path . --script tools/dev_tests/test_escolha_de_corpo_politica_de_teste.gd
const PROGRESSO := "user://test_escolha_corpo_d.json"
var _ok_n := 0
var _falhas := 0
func _ok(cond: bool, rotulo: String) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
func _init() -> void:
	executar.call_deferred()
func executar() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", PROGRESSO)
	modo.set("corpo_de_teste", "feminino")
	root.get_node("GameFlow").start_story()
	var jogador: Node = null
	for i in 700:
		await process_frame
		jogador = get_first_node_in_group("player")
		if jogador != null:
			break
	_ok(jogador != null, "a história sobe sozinha com save novo (sem esperar a tela)")
	_ok(root.find_child("EscolhaCorpoHistoria", true, false) == null, "a tela de escolha NÃO aparece em teste automatizado")
	if jogador != null:
		_ok(str(jogador.get_meta("corpo_historia", "")) == "feminino", "o jogador nasce com `corpo_de_teste` ('feminino')")
	_ok(ProgressaoDoPersonagem.carregar(PROGRESSO).corpo == "feminino", "a escolha automática é SALVA no progresso")
	modo.set("corpo_de_teste", "masculino")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nPOLITICA_DE_TESTE %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
