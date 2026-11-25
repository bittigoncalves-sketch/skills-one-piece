class_name RegrasDoResgateDoBau
extends RefCounted
# ============================================================================
#  REGRAS DO RESGATE DO BAÚ (21/11/2026, 3ª missão; pedido do dono) — só estado e recompensa, sem nó nem tela (testável).
#  Barba Negra dá a missão → a bússola aponta o baú, que é um MÍMICO → UM ataque certeiro o derruba e ele solta o "Baú misterioso" → o jogador PEGA o drop →
#  volta ao Barba Negra, que tira o item da mochila e entrega 20 moedas + 700 XP + a fruta Ushi Ushi no Mi (Girafa) (a tabela `Missoes`: `resgate_do_bau`). Vem DEPOIS do desafio do Buggy (`depois_de`).
#
#  Estado em `prog.sistemas["resgate_bau"]` = {"fase": ..., "drop": [x, y, z]} (persistido):
#    ""            a missão ainda não foi aceita
#    "procurando"  aceita: o mímico existe no mapa (fixo em `PONTO_DO_MIMICO`) e a bússola aponta para ele
#    "solto"       o mímico foi atingido: o drop está no chão em `drop` (recarregar refaz o drop no mesmo lugar)
#    "pego"        o jogador pegou o drop: a missão fica PRONTA (entregar ao Barba Negra)
#  Cada transição é idempotente (repetir o sinal não anda duas vezes nem paga duas vezes).
# ============================================================================
const CHAVE := "resgate_bau"
const MISSAO := "resgate_do_bau"
const ALVO := "bau_misterioso"
const NADA := ""
const PROCURANDO := "procurando"
const SOLTO := "solto"
const PEGO := "pego"
## Onde o mímico fica (plano, aberto e seco, a ~64 m do Barba Negra: medido por varredura do terreno em 21/11/2026). O chão real é achado por raio em tempo de execução.
const PONTO_DO_MIMICO := Vector3(194.0, 2.2, 74.0)


static func fase(prog: ProgressaoDoPersonagem) -> String:
	return str((prog.sistemas.get(CHAVE, {}) as Dictionary).get("fase", NADA))


static func _gravar(prog: ProgressaoDoPersonagem, nova: String, extra: Dictionary = {}) -> void:
	var d: Dictionary = prog.sistemas.get(CHAVE, {})
	d["fase"] = nova
	for k in extra:
		d[k] = extra[k]
	prog.sistemas[CHAVE] = d
	prog.mudou.emit()


## A missão foi aceita e ainda não começamos a procura? (o orquestrador chama `comecar`.)
static func deve_comecar(prog: ProgressaoDoPersonagem) -> bool:
	return fase(prog) == NADA and prog.estado_da_missao(MISSAO) == "aceita"


static func comecar(prog: ProgressaoDoPersonagem) -> bool:
	if not deve_comecar(prog):
		return false
	_gravar(prog, PROCURANDO)
	return true


## O mímico foi atingido em `onde`: o drop nasce ali. Só vale procurando; devolve false se já tinha sido (golpes repetidos não duplicam o drop).
static func mimico_atingido(prog: ProgressaoDoPersonagem, onde: Vector3) -> bool:
	if fase(prog) != PROCURANDO:
		return false
	_gravar(prog, SOLTO, {"drop": [onde.x, onde.y, onde.z]})
	return true


static func posicao_do_drop(prog: ProgressaoDoPersonagem) -> Variant:
	var d: Dictionary = prog.sistemas.get(CHAVE, {})
	var a: Variant = d.get("drop")
	if fase(prog) == SOLTO and a is Array and (a as Array).size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return null


## O jogador pegou o drop: o "Baú misterioso" ENTRA NA MOCHILA e a missão cumpre (1/1 → pronta). Só vale solto. Mochila cheia = devolve false e NADA muda (o drop continua no chão).
static func pegar_drop(prog: ProgressaoDoPersonagem) -> bool:
	if fase(prog) != SOLTO:
		return false
	if not BauMisteriosoItem.receber(prog.inventario):
		return false
	prog.contar_abate(ALVO)
	_gravar(prog, PEGO)
	return true


## O jogador está com o item para entregar?
static func tem_o_bau(prog: ProgressaoDoPersonagem) -> bool:
	return BauMisteriosoItem.tem(prog.inventario)


## ENTREGA ao Barba Negra: tira o item da mochila e paga (20 moedas + 700 XP + a Ushi Ushi no Mi, pela tabela `Missoes`). Tudo-ou-nada: sem o item (o jogador o perdeu/guardou fora da mochila) não paga e nada muda.
## Devolve `{"ok": bool, "motivo": String}`.
static func entregar(prog: ProgressaoDoPersonagem) -> Dictionary:
	if prog.estado_da_missao(MISSAO) != "pronta":
		return {"ok": false, "motivo": "A missão não está pronta."}
	if not tem_o_bau(prog):
		return {"ok": false, "motivo": "Você não está com o Baú misterioso."}
	BauMisteriosoItem.consumir(prog.inventario)
	var ok := prog.entregar_missao(MISSAO)
	return {"ok": ok, "motivo": "" if ok else "Não foi possível entregar."}
