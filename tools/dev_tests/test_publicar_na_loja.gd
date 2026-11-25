extends SceneTree
## 18/11/2026: fruta do Builder sem classificação vale o poder padrão (antes: 500 mil fixos).
const PRECO_PADRAO := 2500    # PerfilDeFrutas.PRECO_POR_PODER[PODER_PADRAO - 1]; escrito aqui porque citar PerfilDeFrutas na constante quebra o --script
# ============================================================================
#  "PUBLICAR NA LOJA" DO SKILLS BUILDER (07/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_publicar_na_loja.gd
#
#  Pedido do dono: "criar botão que disponibilize a fruta e skill criada na loja do modo
#  história, tornar esse botão o publicar atual". Decisão: preço no editor (padrão 1).
#  Numa pasta de TESTE (o catálogo do projeto fica intocado):
#    • o botão Publicar se chama "Publicar na loja";
#    • fruta nova + skill + preço 7 pelo botão → a fruta está à venda por 7 no vendedor;
#      com 6 moedas a compra é recusada, com 7 sai e vai ao inventário;
#    • skill sem fruta (Kit do Builder) com preço 3 → o Kit vira item por 3;
#    • a fruta da arena refeita (Pika) avisa que já é vendida e não ganha preço novo.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const PASTA := "user://test_publicar_na_loja_skills"
const LojaDeFrutas := preload("res://src/historia/npcs/loja_de_frutas.gd")

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PASTA.path_join("frutas.json")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PASTA.path_join("kit.json")))
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	var nova := SkillsPublicadas.criar_fruta("Teste Teste no Mi", "#44ccff")
	var fruta := str(nova.get("id", ""))
	_ok("fruta de teste criada (%s)" % fruta, bool(nova.ok))

	root.get_node("GameFlow").start_skills_builder()
	for i in 60:
		await process_frame
	var ed := current_scene
	var botao := ed.find_child("Publicar", true, false) as Button
	_ok("o botão chama-se \"%s\"" % (botao.text if botao else "?"), botao != null and botao.text == "Publicar na loja")

	# Fruta + skill + preço 7.
	ed.call("_documento", _skill("teste_loja_z", fruta, "Z"))
	await _quadros(5)
	ed.call("_mostrar_secao", "identificacao")
	await _quadros(5)
	var campo := ed.find_child("PrecoNaLoja", true, false) as SpinBox
	_ok("a Identificação tem o campo \"Preço na loja\"", campo != null)
	_ok("fruta usa o preço fixo do poder padrão (%d)" % PRECO_PADRAO, campo != null and not campo.editable and campo.value == PRECO_PADRAO)
	botao.pressed.emit()
	await _quadros(5)
	var aviso := str((ed.get("_status") as Label).text)
	_ok("o aviso usa o preço efetivo (%s)" % aviso, aviso.contains("venda") and aviso.contains("%d moedas" % PRECO_PADRAO))
	_ok("a fruta está à venda no vendedor", fruta in PerfilDeFrutas.frutas_a_venda())
	var loja := LojaDeFrutas.new()
	var prog := ProgressaoDoPersonagem.new()
	prog.ouro = PRECO_PADRAO - 1
	var linha := _linha(loja.linhas(prog, null), fruta)
	_ok("a linha mostra o preço do poder padrão e bloqueia saldo insuficiente", int(linha.get("preco", 0)) == PRECO_PADRAO and not _comprar_ativo(linha))
	_ok("saldo insuficiente recusa compra", loja.executar(prog, null, "comprar", fruta).contains("Sem moedas"))
	prog.ouro = PRECO_PADRAO
	loja.executar(prog, null, "comprar", fruta)
	_ok("com o preço exato compra: vai ao inventário e sobra 0 (ouro %d, guardadas %d)" % [prog.ouro, prog.quantas_akuma(fruta)],
		prog.ouro == 0 and prog.quantas_akuma(fruta) == 1)

	# Kit do Builder (sem fruta) com preço 3.
	ed.call("_documento", _skill("teste_loja_kit", "", "X"))
	await _quadros(5)
	ed.call("_mostrar_secao", "identificacao")
	await _quadros(5)
	campo = ed.find_child("PrecoNaLoja", true, false) as SpinBox
	if campo:
		campo.value = 3
	botao.pressed.emit()
	await _quadros(5)
	_ok("o Kit do Builder vira item por 3 (à venda: %s; preço %d)" % [KitDoBuilder.ID in PerfilDeFrutas.frutas_a_venda(), PerfilDeFrutas.preco_na_loja(KitDoBuilder.ID)],
		KitDoBuilder.ID in PerfilDeFrutas.frutas_a_venda() and PerfilDeFrutas.preco_na_loja(KitDoBuilder.ID) == 3)
	_ok("fruta da arena custa pelo poder (Mera = épica, 15 mil)", PerfilDeFrutas.preco_na_loja("mera_mera") == 15000)

	# A Pika refeita: já é vendida.
	SkillsPublicadas.reconstruir_fruta_da_arena("pika_pika", "Pika Pika no Mi", "#ffd23f")
	ed.call("_documento", _skill("teste_loja_pika", "pika_pika", "Z"))
	await _quadros(5)
	botao.pressed.emit()
	await _quadros(5)
	aviso = str((ed.get("_status") as Label).text)
	_ok("a Pika refeita avisa que já é vendida (%s)" % aviso, aviso.contains("já é vendida"))

	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	print("\nPUBLICAR_NA_LOJA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _skill(id: String, fruta: String, tecla: String) -> Dictionary:
	var s := Dados.novo()
	s.identificacao.id = id
	s.identificacao.nome = id
	s.identificacao.fruta = fruta
	s.ativacao.tecla = tecla
	return s


func _linha(linhas: Array, id: String) -> Dictionary:
	for l in linhas:
		if str(l.get("id", "")) == id:
			return l
	return {}


func _comprar_ativo(linha: Dictionary) -> bool:
	for b in linha.get("botoes", []):
		if str(b.get("acao", "")) == "comprar":
			return bool(b.get("ativo", false))
	return false


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
