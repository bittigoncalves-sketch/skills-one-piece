class_name ArmaUnica
extends RefCounted
## UMA ARMA SÓ (08/11/2026, pedido do dono): o sorteio de nascimento do mod (`SetTagPirate`/`SetTagMarine`) pode deixar o mesmo personagem
## com fuzil E espada (ou pistola e sabre). Na raid isso fica com UMA: o FUZIL de preferência, mas depende da distância em que ele nasceu do
## jogador — nascendo longe, o fuzil faz sentido; nascendo em cima, a espada. Fica só uma na mão; a outra sai do equipamento.

const FOGO: Array[String] = ["rifle", "pistol", "pistol_gold", "senriku", "rocket_launcher"]
const CORTE: Array[String] = ["saber", "sword", "katana", "cutlass"]
## Nascer a esta distância (m) ou mais do jogador: fica o fuzil. A raid nasce o espadachim entre 8 e 16 m e o atirador entre 18 e 34 m
## (15/11/2026): com 16, perto fica a espada e longe o fuzil.
const DISTANCIA_DO_FUZIL := 16.0
const MAOS: Array[String] = ["MAINHAND", "OFFHAND"]


static func preferir_fogo(distancia_de_nascimento: float) -> bool:
	return distancia_de_nascimento >= DISTANCIA_DO_FUZIL


## "fogo", "corte" ou "" para o id do item.
static func classe_de(id: String) -> String:
	var limpo := id.trim_prefix("minepiece:").trim_prefix("minecraft:")
	if limpo in FOGO:
		return "fogo"
	for c in CORTE:
		if limpo.contains(c):
			return "corte"
	return ""


## O que o corpo segura: {"MAINHAND": "fogo", "OFFHAND": "corte"} (só as mãos com arma).
static func armas_nas_maos(corpo: Node3D) -> Dictionary:
	var e := McEntidade.de(corpo)
	var saida := {}
	for mao in MAOS:
		var pilha := e.getItemBySlot(mao)
		if pilha != null and not pilha.isEmpty():
			var c := classe_de(str(pilha.item.id))
			if not c.is_empty():
				saida[mao] = c
	return saida


## Deixa só uma classe de arma. Devolve a que ficou ("fogo"/"corte") ou "" se já tinha no máximo uma.
static func aplicar(corpo: Node3D, fogo_preferido: bool) -> String:
	if corpo == null or not is_instance_valid(corpo) or not corpo.is_inside_tree():
		return ""
	var maos := armas_nas_maos(corpo)
	if not maos.values().has("fogo") or not maos.values().has("corte"):
		return ""
	var tirar := "corte" if fogo_preferido else "fogo"
	var e := McEntidade.de(corpo)
	for mao: String in maos:
		if maos[mao] == tirar:
			e.setItemSlot(mao, McItem.pilha(null, 0))
	var ficha: Variant = corpo.get("ficha")
	if ficha is Dictionary:
		if tirar == "corte":
			ficha["espada"] = false
		else:
			ficha["arma_de_fogo"] = false
	return "fogo" if fogo_preferido else "corte"
