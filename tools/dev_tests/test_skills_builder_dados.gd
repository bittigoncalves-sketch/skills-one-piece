extends SceneTree
const Dados := preload("res://src/skills_builder/dados_skill.gd")
var falhas := 0
var pasta := "/tmp/skills_builder_dados_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond: falhas += 1

func rodar() -> void:
	var d := Dados.novo()
	ok(Dados.validar(d).ok, "documento inicial completo é válido")
	var copia: Dictionary = Dados.validar(d).skill
	copia.dano.valor = 90
	ok(d.dano.valor == 25, "validação devolve cópia independente")
	for caso in [["identificacao", "id", "../escape"], ["identificacao", "nome", ""], ["dano", "valor", true], ["dano", "valor", NAN], ["dano", "valor", INF], ["dano", "valor", -1], ["projeteis", "quantidade", 1.5], ["vfx", "cor", "banana"], ["animacao", "clipe", "res://codigo.gd"], ["ativacao", "modo", "Outro"]]:
		copia = d.duplicate(true)
		copia[caso[0]][caso[1]] = caso[2]
		ok(not Dados.validar(copia).ok, "recusa valor inválido %s.%s: %s" % caso)
	for invalido in [null, [], 5, "texto"]:
		ok(not Dados.validar(invalido).ok, "raiz inválida é recusada")
	for caso in [["versao", 2], ["versao", true], ["formato", "outro"], ["eventos", {}], ["dano", null], ["extra", 1]]:
		copia = d.duplicate(true)
		copia[caso[0]] = caso[1]
		ok(not Dados.validar(copia).ok, "recusa raiz/campo " + str(caso[0]))
	for caso in [["id", "../x"], ["tipo", "codigo"], ["duracao", 0], ["inicio", 30], ["habilitado", 1], ["parametros", []], ["parametros", {"campo_inexistente":1}], ["parametros", {"velocidade":-5}]]:
		copia = d.duplicate(true)
		copia.eventos[0][caso[0]] = caso[1]
		ok(not Dados.validar(copia).ok, "evento inválido recusado: " + str(caso[0]))
	copia = d.duplicate(true)
	copia.eventos.append(copia.eventos[0].duplicate(true))
	ok(not Dados.validar(copia).ok, "ID de evento duplicado recusado")
	copia.eventos.resize(65)
	ok(not Dados.validar(copia).ok, "limite de eventos respeitado")
	copia = d.duplicate(true)
	copia.eventos[0].parametros = {"velocidade":2.0}
	ok(Dados.validar(copia).ok and Dados.parametros(copia, copia.eventos[0]).velocidade == 2.0 and copia.animacao.velocidade == 1.0, "override de evento preserva padrão global")
	var r := Dados.salvar(copia, pasta)
	ok(r.ok and Dados.listar(pasta).size() == 1, "salvamento cria biblioteca e arquivo")
	var carregado := Dados.carregar(r.caminho)
	# JSON converte inteiros em float; comparar a representação serializada.
	ok(carregado.ok and carregado.skill == JSON.parse_string(JSON.stringify(copia)), "JSON faz roundtrip integral")
	copia.dano.valor = 72
	ok(Dados.salvar(copia, pasta).ok and Dados.carregar(r.caminho).skill.dano.valor == 72, "salvamento substitui versão anterior")
	var invalida := copia.duplicate(true)
	invalida.dano.valor = -2
	ok(not Dados.salvar_em(invalida, r.caminho).ok and Dados.carregar(r.caminho).skill.dano.valor == 72, "dados inválidos não destroem arquivo existente")
	var f := FileAccess.open(pasta.path_join("corrompida.json"), FileAccess.WRITE)
	f.store_string("{ quebrado")
	f.close()
	ok(not Dados.carregar(pasta.path_join("corrompida.json")).ok, "JSON corrompido produz erro legível")
	f = FileAccess.open(pasta.path_join("grande.json"), FileAccess.WRITE)
	f.store_string(" ".repeat(Dados.MAX_BYTES + 1))
	f.close()
	ok(not Dados.carregar(pasta.path_join("grande.json")).ok, "arquivo acima de 1 MiB recusado")
	ok(not Dados.carregar(pasta.path_join("ausente.json")).ok, "arquivo ausente tratado")
	for caminho in Dados.listar(pasta): DirAccess.remove_absolute(caminho)
	DirAccess.remove_absolute(pasta)
	print("SKILLS_BUILDER_DADOS_RESULTADO falhas=%d" % falhas)
	quit(1 if falhas else 0)
