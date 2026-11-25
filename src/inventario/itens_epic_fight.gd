class_name ItensEpicFight
extends RefCounted
## ARMAS DO EPIC FIGHT COMO ITENS DO INVENTÁRIO (12/11/2026, pedido do dono: "coloca as armas do epic fight" na hotbar e na mochila).
## Pilha `ef:<arma>` (limite 1), com a arma de `LaminasEpicFight` (id `ef_iron_longsword` → item `ef:iron_longsword`). A posse continua em `ProgressaoDoPersonagem.equipamentos`
## (durabilidade, quebra e a aba ARMAS seguem iguais); o item só POSICIONA a arma. Escolher o slot na hotbar equipa a arma (ver `BarraDeItensHud`).
const PREFIXO := "ef:"


static func e_de(id: String) -> bool:
	return id.begins_with(PREFIXO)


## "ef:iron_longsword" → "ef_iron_longsword" (id da `LaminasEpicFight`; "" se não é arma conhecida).
static func lamina_do_item(id: String) -> String:
	if not e_de(id):
		return ""
	var l := "ef_" + id.trim_prefix(PREFIXO)
	return l if LaminasEpicFight.existe(l) else ""


static func id_do_item(lamina: String) -> String:
	return PREFIXO + lamina.trim_prefix("ef_")


static func nome(id: String) -> String:
	var l := lamina_do_item(id)
	return "" if l == "" else str(LaminasEpicFight.dados(l).nome)


static func icone(id: String) -> Texture2D:
	var l := lamina_do_item(id)
	return null if l == "" else LaminasEpicFight.icone(l)


static func nova_pilha(lamina: String) -> McItem.Pilha:
	return InventarioMinecraft.nova(id_do_item(lamina), 1)


## LIMPEZA DO INVENTÁRIO (pedido do dono, 18/11/2026: "retirar as espadas e frutas que foram dadas"). Antes, todo personagem recebia as lâminas do Epic Fight
## (`LaminasEpicFight.conceder_a`), 10 de cada fruta importada (`ModoHistoria.frutas_de_teste`) e o kit de blocos de teste. Agora ninguém recebe nada disso;
## esta função tira o que saves antigos já carregam, UMA vez por personagem (marca em `sistemas.limpeza`). Frutas: tira até `quantidade_de_teste` de cada fruta
## que era dada (o que passar disso foi comprado/ganho e fica). Devolve true se limpou agora.
static func limpar_concedidos(prog: ProgressaoDoPersonagem, frutas_dadas := {}) -> bool:
	var marca := prog.dados_de("limpeza")
	if bool(marca.get("v1", false)):
		return false
	marca["v1"] = true
	prog.sistemas["limpeza"] = marca              # sem `gravar_dados`: um só `mudou` no fim
	prog.inventario_ef_entregue = true
	prog.kit_de_blocos_entregue = true
	for lamina in LaminasEpicFight.ids():
		prog.equipamentos.erase(lamina)
	prog.lamina_ef = ""
	prog.lamina_ef_sec = ""
	if prog.item_ativo == "espada" or prog.item_ativo == "machado":
		prog.item_ativo = "luta"
	prog.espada_equipada = false
	var inv := prog.inventario
	for i in inv.slots.size():
		var id := InventarioMinecraft.id_de(inv.pilha(i))
		if e_de(id) or _e_do_kit_antigo(i, id):
			inv.slots[i] = McItem.pilha(null, 0)
	for id in frutas_dadas:
		prog.remover_akuma(str(id), int(frutas_dadas[id]))
	inv.mudou.emit()
	prog.mudou.emit()
	return true


static func _e_do_kit_antigo(i: int, id: String) -> bool:
	var k := i - InventarioMinecraft.MOCHILA_INI
	return k >= 0 and k < KIT_ANTIGO.size() and i < InventarioMinecraft.MOCHILA_FIM and id == ItensDeBloco.id_do_tipo(int(KIT_ANTIGO[k]))


## Tipos do kit de blocos que as versões anteriores entregavam, na ordem dos slots da mochila (só serve à limpeza acima).
const KIT_ANTIGO := [
	TiposDeBloco.PEDRA, TiposDeBloco.TIJOLO, TiposDeBloco.MADEIRA, TiposDeBloco.VIDRO, TiposDeBloco.TRONCO,
	TiposDeBloco.ESCADA_BASE + TiposDeBloco.MADEIRA, TiposDeBloco.LAJE_BASE + TiposDeBloco.MADEIRA,
	TiposDeBloco.ESCADA_BASE + TiposDeBloco.PEDRA, TiposDeBloco.LAJE_BASE + TiposDeBloco.PEDRA,
	TiposDeBloco.PORTA_MADEIRA, TiposDeBloco.PAINEL_VIDRO, TiposDeBloco.ALCAPAO_MADEIRA,
	TiposDeBloco.LA_BRANCA, TiposDeBloco.LA_VERMELHA, TiposDeBloco.LA_AZUL, TiposDeBloco.AREIA,
]
