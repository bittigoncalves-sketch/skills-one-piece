class_name McNbt
extends RefCounted
## `CompoundTag` do Minecraft (o `getPersistentData()` das entidades: 1001 arquivos do mod usam).
## Como no Java: ler chave que não existe (ou de outro tipo) devolve o padrão (0, false, "").

var dados := {}
## Multiplica a chave "Range" (o lado do cubo do `RangeAttackProcedure`, a HITBOX do golpe) ao LER. Ajuste do jogo, não do mod: o mod
## guarda o valor dele em `dados` intacto. 1.0 = o do mod. Usado por `FrutasDoMod.ALCANCE_DO_ARO_ARO`.
var fator_de_alcance := 1.0


func contains(k: String, _tipo: int = -1) -> bool: return dados.has(k)
func remove(k: String) -> void: dados.erase(k)
func getAllKeys() -> Array: return dados.keys()
func isEmpty() -> bool: return dados.is_empty()


func getDouble(k: String) -> float:
	var v: Variant = dados.get(k)
	var f := float(v) if v is float or v is int else 0.0
	return f * fator_de_alcance if k == "Range" else f


func getFloat(k: String) -> float: return getDouble(k)


func getInt(k: String) -> int:
	var v: Variant = dados.get(k)
	return int(v) if v is float or v is int else 0


func getLong(k: String) -> int: return getInt(k)


func getBoolean(k: String) -> bool:
	var v: Variant = dados.get(k)
	return bool(v) if v is bool else (v is int and v != 0)


func getString(k: String) -> String:
	var v: Variant = dados.get(k)
	return v if v is String else ""


func getCompound(k: String) -> McNbt:
	var v: Variant = dados.get(k)
	if v is McNbt:
		return v
	return McNbt.new()


func putDouble(k: String, v: float) -> void: dados[k] = float(v)
func putFloat(k: String, v: float) -> void: dados[k] = float(v)
func putInt(k: String, v: int) -> void: dados[k] = int(v)
func putLong(k: String, v: int) -> void: dados[k] = int(v)
func putBoolean(k: String, v: bool) -> void: dados[k] = bool(v)
func putString(k: String, v: String) -> void: dados[k] = str(v)
func put(k: String, v: Variant) -> void: dados[k] = v


func copy() -> McNbt:
	var n := McNbt.new()
	n.dados = dados.duplicate(true)
	return n
