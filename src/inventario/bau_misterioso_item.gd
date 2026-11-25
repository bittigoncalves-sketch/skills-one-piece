class_name BauMisteriosoItem
extends RefCounted
## O "BAÚ MISTERIOSO" como ITEM DA MOCHILA (21/11/2026, 3ª missão; pedido do dono: "vira item da mochila"). Pilha única `historia:bau_misterioso` (limite 1). Entra ao pegar o drop do mímico e é
## CONSUMIDO na entrega ao Barba Negra (`RegrasDoResgateDoBau.entregar`). Mesmo padrão do `BauTesouros`. O ícone é o 16×16 do Codex (`tools/texturas/aplicar_texturas_bau.py`).
const ID := "historia:bau_misterioso"
const ICONE := "res://assets/ui/itens/bau_misterioso.png"
const NOME := "Baú misterioso · item de missão"
static var _icone: Texture2D


static func icone() -> Texture2D:
	if _icone == null and ResourceLoader.exists(ICONE):
		_icone = load(ICONE) as Texture2D
	return _icone


## Põe 1 na mochila. false (e NADA muda) se não couber.
static func receber(inventario: InventarioMinecraft) -> bool:
	return inventario.inserir(InventarioMinecraft.nova(ID)).isEmpty()


static func tem(inventario: InventarioMinecraft) -> bool:
	return inventario.contar(ID) > 0


## Tira 1 da mochila. false se não havia.
static func consumir(inventario: InventarioMinecraft) -> bool:
	return inventario.remover(ID, 1)
