extends RefCounted
## Baú colecionável dos naufrágios. Usa o modelo de baú já presente no mundo.
## A recompensa de ouro existente permanece na abertura do naufrágio.
const ID := "historia:bau_tesouros"
const ICONE := "res://assets/ui/itens/bau_tesouros.png"
const MODELO := "res://mapas/modelos/chest_closed.glb"
const LIMITE := 16
static var _icone: Texture2D


static func icone() -> Texture2D:
	if _icone == null:
		_icone = load(ICONE)
	return _icone


static func receber(inventario: InventarioMinecraft) -> bool:
	# Uma única unidade: inserir é integral ou devolve a unidade sem alterar slots.
	return inventario.inserir(InventarioMinecraft.nova(ID)).isEmpty()


static func modelo() -> Node3D:
	var cena := load(MODELO) as PackedScene
	return cena.instantiate() as Node3D
