class_name McBloco
extends RefCounted
# ============================================================================
#  `Block` (o tipo, um por id: `Mc.bloco`) e, em `McBloco.Estado`, o `BlockState` que
#  `level.getBlockState(pos)` devolve. E1: só LEITURA, pelo mundo do jogo (que não é de blocos):
#    colisão no cubo do bloco → minecraft:stone (sólido, tapa a visão);
#    sem colisão abaixo do mar (y < 0) → minecraft:water; senão → minecraft:air.
#  Escrever bloco: `McMundo.setBlock` → `McBlocosDinamicos` (sobreposição sobre o relevo); cavar o relevo é `McRelevoCavavel`.
# ============================================================================

var id: StringName


func defaultBlockState() -> Estado: return Estado.de(self)
## Propriedades de estado (facing, waterlogged…): o mundo do jogo não tem — nenhuma.
class Definicao:
	extends RefCounted
	func getProperty(_nome: Variant) -> Variant: return null
	func getProperties() -> Array: return []
func getStateDefinition() -> Definicao: return Definicao.new()
func getDescriptionId() -> String: return "block." + String(id).replace(":", ".")
func _to_string() -> String: return String(id)


class Estado:
	extends RefCounted
	var bloco: McBloco
	static func de(b: McBloco) -> Estado:
		var e := Estado.new()
		e.bloco = b
		return e
	func getBlock() -> McBloco: return bloco
	func isAir() -> bool: return bloco.id == &"minecraft:air"
	func canOcclude() -> bool: return bloco.id == &"minecraft:stone" or McBlocosDinamicos.e_solido(bloco.id)
	func isSolid() -> bool: return canOcclude()
	func isSolidRender(_a: Variant = null, _b: Variant = null) -> bool: return canOcclude()
	func blocksMotion() -> bool: return canOcclude()
	func getFluidState() -> Estado: return self
	func isEmpty() -> bool: return bloco.id != &"minecraft:water" and bloco.id != &"minecraft:lava"
	func isSource() -> bool: return bloco.id == &"minecraft:water" or bloco.id == &"minecraft:lava"   # o mar do jogo é todo fonte
	## Propriedades de estado (lit, level, waterlogged…): o jogo não tem; `setValue` devolve o próprio estado.
	func setValue(_prop: Variant, _valor: Variant) -> Estado: return self
	func getValue(_prop: Variant) -> Variant: return false
	func is_(o: Variant) -> bool:
		if o is McBloco:
			return bloco == o
		return Mc.tag_contem(o, bloco.id, "tags_de_bloco")
	func getDestroySpeed(_a: Variant = null, _b: Variant = null) -> float: return 1.5 if canOcclude() else 0.0
