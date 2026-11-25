extends SceneTree
# ============================================================================
#  MISSÃO "PROVISÕES PARA A VIAGEM" — save e migração (18/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_missao_provisoes.gd
#
#  Pedido do dono: o vendedor de provisões entra na missão; comprar 5 pães + 5 águas.
#  A cadeia inteira na cena real fica em `test_cadeia_do_guarda.gd`; aqui, só dados:
#  a contagem por item sobrevive ao save, save editado não pula a missão e o save
#  antigo ("peixes") vira "provisoes" sem dar a bússola de novo nem herdar peixes.
# ============================================================================

const Missoes := preload("res://src/historia/missoes/missoes.gd")
const Prov := preload("res://src/historia/tripulantes/provisoes.gd")
var falhas := 0
var total := 0


func _init() -> void:
	executar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func _com_missoes(missoes: Dictionary) -> ProgressaoDoPersonagem:
	var d := ProgressaoDoPersonagem.new().para_dict()
	d.missoes = missoes
	d.missoes["corrida"] = {"estado": "entregue", "abates": 1}
	return ProgressaoDoPersonagem.de_dict(JSON.parse_string(JSON.stringify(d)))


func executar() -> void:
	await process_frame
	var p := _com_missoes({})
	ok(p.aceitar_missao("provisoes"), "aceita depois da corrida")
	p.ouro = 10
	ok(Prov.comprar(p, "pao", 3) and Prov.comprar(p, "agua_potavel", 2), "compra 3 pães e 2 águas")
	Prov.comprar(p, "refeicao", 1)
	ok(p.abates_da_missao("provisoes") == 5, "refeição (fora dos itens da missão) não conta")
	var volta := ProgressaoDoPersonagem.de_dict(JSON.parse_string(JSON.stringify(p.para_dict())))
	ok(volta.abates_da_missao("provisoes") == 5 and Missoes.contagem("provisoes", volta) == "Pão 3 / 5 · Água potável 2 / 5",
		"o save guarda a contagem por item (\"%s\")" % Missoes.contagem("provisoes", volta))

	var editado := _com_missoes({"provisoes": {"estado": "aceita", "abates": 10, "itens": {"pao": 99, "refeicao": 7}}})
	ok(editado.estado_da_missao("provisoes") == Missoes.ACEITA and editado.abates_da_missao("provisoes") == 5,
		"save editado: abates = soma dos itens limitados (%d), sem água não fica pronta" % editado.abates_da_missao("provisoes"))

	var antigo_entregue := _com_missoes({"peixes": {"estado": "entregue", "abates": 10}})
	ok(antigo_entregue.estado_da_missao("provisoes") == Missoes.ENTREGUE and not antigo_entregue.missoes.has("peixes"),
		"save antigo com \"peixes\" entregue: provisões entregue (bússola não repete)")
	var antigo_aceito := _com_missoes({"peixes": {"estado": "aceita", "abates": 7}})
	ok(antigo_aceito.estado_da_missao("provisoes") == Missoes.ACEITA and antigo_aceito.abates_da_missao("provisoes") == 0,
		"save antigo com \"peixes\" aceita: provisões aceita do zero (peixe não é provisão)")
	var com_peixe := _com_missoes({})
	com_peixe.aceitar_missao("provisoes")
	com_peixe.guardar_item_de_pesca(TabelaDePeixes.PEIXES.keys()[0], 10)
	ok(com_peixe.abates_da_missao("provisoes") == 0, "pescar não conta mais")

	print("MISSAO_PROVISOES %d conferem | %d divergem" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
