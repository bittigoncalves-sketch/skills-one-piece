extends SceneTree
# ============================================================================
#  ESCOLHA DO CORPO (gênero) AO ENTRAR NO MODO HISTÓRIA — 15/11/2026.
#
#  A tela `EscolhaCorpoHistoria` é aberta pelo Customizar da entrada. Sem corpo salvo, nada vem escolhido; concluir habilita Jogar na entrada, que persiste a escolha.
#  O seletor também pode ser testado sozinho. Testes automatizados não esperam a entrada (`ModoHistoria.exigir_escolha_de_corpo = false`): escolhem
#  `corpo_de_teste` sozinhos — este arquivo liga a interface real para conferi-la.
#
#    A. a tela sozinha: botões, nada escolhido, Entrar desabilitado, escolher habilita, o sinal sai com o tipo certo (masculino e feminino), Voltar sai com "";
#    B. a história de verdade com save novo: a tela aparece e ESPERA; escolher Feminino segue, grava no save e o jogador nasce feminino;
#    C. o save mantém a escolha (recarregar devolve o corpo); a entrada permite jogar sem customizar novamente;
#    E. os DOIS corpos cumprem o contrato das mãos separáveis da Bara Bara (`Hand_L/R` com `Geo_Palm_*_Runtime`): sem isso a fruta nem lança no Modo História;
#    D. política de teste: sem `exigir_escolha_de_corpo` a história sobe sozinha com o corpo de teste e grava no save.
#
#    DISPLAY=:1 godot --path . -s tools/dev_tests/test_escolha_de_corpo.gd          (a prévia 3D da tela usa SubViewport: precisa de janela)
# ============================================================================
const Tela := preload("res://src/ui/escolha_corpo_historia.gd")
const PROGRESSO_B := "user://test_escolha_corpo_b.json"
const PROGRESSO_D := "user://test_escolha_corpo_d.json"

var _ok_n := 0
var _falhas := 0
var _emitido: Array = []


func _ok(cond: bool, rotulo: String) -> void:
	if cond:
		_ok_n += 1
	else:
		_falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func quadros(n: int) -> void:
	for i in n:
		await process_frame


func _init() -> void:
	executar.call_deferred()


func _apagar(caminho: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(caminho))


func executar() -> void:
	await quadros(2)
	await _a_tela_sozinha()
	await _b_historia_com_save_novo()
	_c_persistencia()
	_e_contrato_das_maos()
	print("\nESCOLHA_DE_CORPO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


# --------------------------------------------------------------------- A
func _a_tela_sozinha() -> void:
	print("\n-- A. a tela sozinha --")
	var tela := Tela.new()
	root.add_child(tela)
	await quadros(3)
	tela.escolheu.connect(func(t: String) -> void: _emitido.append(t))
	var masc := tela.find_child("Masculino", true, false) as Button
	var fem := tela.find_child("Feminino", true, false) as Button
	var entrar := tela.find_child("Entrar", true, false) as Button
	var voltar := tela.find_child("Voltar", true, false) as Button
	_ok(masc != null and fem != null and entrar != null and voltar != null, "tem os botões Masculino, Feminino, Entrar e Voltar")
	_ok(tela.get("_selecionado") == "", "nada vem escolhido por padrão")
	_ok(entrar.disabled, "\"Entrar\" começa desabilitado")
	entrar.pressed.emit()
	_ok(_emitido.is_empty(), "apertar Entrar sem escolher não emite nada")
	fem.pressed.emit()
	_ok(not entrar.disabled and tela.get("_selecionado") == "feminino", "escolher Feminino habilita Entrar e marca 'feminino'")
	masc.pressed.emit()
	_ok(tela.get("_selecionado") == "masculino", "trocar para Masculino muda a seleção")
	entrar.pressed.emit()
	_ok(_emitido == ["masculino"], "Entrar emite o tipo escolhido: %s" % str(_emitido))
	tela.mostrar_erro()
	_ok(not entrar.disabled, "depois de um erro ao salvar, Entrar volta a habilitar")
	fem.pressed.emit()
	entrar.pressed.emit()
	_ok(_emitido == ["masculino", "feminino"], "o segundo envio sai 'feminino': %s" % str(_emitido))
	voltar.pressed.emit()
	_ok(_emitido.back() == "", "Voltar emite string vazia (volta ao menu)")
	tela.queue_free()
	await quadros(2)


# --------------------------------------------------------------------- B
func _b_historia_com_save_novo() -> void:
	print("\n-- B. a história com save novo mostra a tela e espera --")
	_apagar(PROGRESSO_B)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", PROGRESSO_B)
	modo.set("exigir_escolha_de_corpo", true)
	root.get_node("GameFlow").start_story()
	var tela: Node = null
	for i in 400:
		await process_frame
		tela = root.find_child("EntradaHistoria", true, false)
		if tela != null:
			break
	_ok(tela != null, "a tela de escolha aparece no save novo")
	if tela == null:
		return
	var entrada := tela
	(entrada.find_child("Customizar", true, false) as Button).pressed.emit()
	tela = entrada.find_child("EscolhaCorpoHistoria", true, false)
	await quadros(60)
	_ok(get_first_node_in_group("player") == null, "a história ESPERA a escolha (nenhum jogador nasceu)")
	(tela.find_child("Feminino", true, false) as Button).pressed.emit()
	(tela.find_child("Entrar", true, false) as Button).pressed.emit()
	(entrada.find_child("Jogar", true, false) as Button).pressed.emit()
	var jogador: Node = null
	for i in 600:
		await process_frame
		jogador = get_first_node_in_group("player")
		if jogador != null:
			break
	_ok(jogador != null, "escolhido o corpo, a história segue e o jogador nasce")
	if jogador != null:
		_ok(str(jogador.get_meta("corpo_historia", "")) == "feminino", "o jogador nasce com o corpo 'feminino' (%s)" % str(jogador.get_meta("corpo_historia", "")))
		_ok(current_scene.progressao.corpo == "feminino", "a progressão guarda 'feminino'")
	await quadros(5)
	_ok(root.find_child("EscolhaCorpoHistoria", true, false) == null, "a tela some depois de escolher")
	modo.set("exigir_escolha_de_corpo", false)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")


# --------------------------------------------------------------------- C
func _c_persistencia() -> void:
	print("\n-- C. a escolha fica salva na campanha --")
	var lido := ProgressaoDoPersonagem.carregar(PROGRESSO_B)
	_ok(lido.corpo == "feminino", "recarregar o save devolve o corpo escolhido ('%s')" % lido.corpo)
	var bruto := FileAccess.get_file_as_string(PROGRESSO_B)
	_ok(bruto.contains("\"corpo\": \"feminino\""), "o arquivo de save tem \"corpo\": \"feminino\"")
	_ok(not lido.corpo.is_empty(), "com corpo no save, a entrada pode jogar sem customizar novamente")
	var novo := ProgressaoDoPersonagem.new()
	_ok(novo.corpo == "", "um progresso novo começa SEM corpo (por isso a tela aparece)")
	_ok(not novo.definir_corpo("alienigena") and novo.corpo == "", "um tipo inválido é recusado")
	_ok(novo.definir_corpo("masculino") and novo.corpo == "masculino", "um tipo válido é aceito")


# --------------------------------------------------------------------- E
func _e_contrato_das_maos() -> void:
	print("\n-- E. contrato das mãos separáveis (Bara Bara) nos dois corpos --")
	var Corpo = load("res://src/player/corpo_historia.gd")
	for tipo in ["masculino", "feminino"]:
		var corpo: Node3D = Corpo.construir(tipo)["node"]
		root.add_child(corpo)
		for lado in ["L", "R"]:
			var mao := corpo.find_child("Hand_" + lado, true, false) as Node3D
			var palma := mao.find_child("Geo_Palm_%s_Runtime" % lado, true, false) if mao != null else null
			var geos := mao.find_children("Geo_*_Runtime", "MeshInstance3D", true, false) if mao != null else []
			_ok(mao != null and palma != null and geos.size() >= 13,
				"%s · mão %s: palma Geo_Palm_%s_Runtime + %d malhas Geo_*_Runtime (palma, 12 falanges, 3 do polegar)" % [tipo, lado, lado, geos.size()])
		var binding = load("res://src/characters/BaraHandBinding.gd").new()
		var ator := Node3D.new()
		root.add_child(ator)
		ator.set_meta("_x", 1)
		corpo.reparent(ator)
		# BaraHandBinding lê `actor.get("_char_model")`: um stub com a propriedade.
		var stub := _Ator.new()
		root.add_child(stub)
		stub._char_model = corpo
		_ok(binding.setup(stub), "%s: BaraHandBinding.setup aceita o corpo (%s)" % [tipo, binding.reason])
		binding.dispose()
		stub.queue_free()
		ator.queue_free()


class _Ator extends Node3D:
	var _char_model: Node3D
