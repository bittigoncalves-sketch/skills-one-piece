class_name McVec3
extends RefCounted
## `Vec3` (e `BlockPos`, com inteiros) do Minecraft, em BLOCOS — a unidade das procedures do
## Mine Piece. O tradutor converte `v.x()` em `v.x` (GDScript não tem campo e método com o mesmo
## nome). Imutável como no Java: toda operação devolve um novo.

var x := 0.0
var y := 0.0
var z := 0.0


static func de(a: float, b: float, c: float) -> McVec3:
	var v := McVec3.new()
	v.x = a
	v.y = b
	v.z = c
	return v


## Metros do Godot → blocos.
static func de_godot(p: Vector3) -> McVec3:
	return de(p.x / MundoMinePiece.METROS_POR_BLOCO, p.y / MundoMinePiece.METROS_POR_BLOCO,
		p.z / MundoMinePiece.METROS_POR_BLOCO)


## Blocos → metros do Godot.
func para_godot() -> Vector3:
	return Vector3(x, y, z) * MundoMinePiece.METROS_POR_BLOCO


static func _xyz(a: Variant, b: Variant, c: Variant) -> Vector3:
	if a is McVec3:
		return Vector3(a.x, a.y, a.z)
	if a is Vector3:                                   # já em blocos
		return a
	if a is float or a is int:
		return Vector3(float(a), float(b), float(c))
	Mc._falta("Vec3.operando", type_string(typeof(a)) + (":" + a.get_class() if a is Object else ""))
	return Vector3.ZERO


func add(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> McVec3:
	var o := _xyz(a, b, c)
	return de(x + o.x, y + o.y, z + o.z)


func subtract(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> McVec3:
	var o := _xyz(a, b, c)
	return de(x - o.x, y - o.y, z - o.z)


func scale(f: float) -> McVec3: return de(x * f, y * f, z * f)
func multiply(a: Variant, b: Variant = 1.0, c: Variant = 1.0) -> McVec3:
	var o := _xyz(a, b, c)
	return de(x * o.x, y * o.y, z * o.z)
func reverse() -> McVec3: return de(-x, -y, -z)
func lengthSqr() -> float: return x * x + y * y + z * z
func length() -> float: return sqrt(lengthSqr())
func horizontalDistance() -> float: return sqrt(x * x + z * z)
func horizontalDistanceSqr() -> float: return x * x + z * z
func dot(o: McVec3) -> float: return x * o.x + y * o.y + z * o.z
func cross(o: McVec3) -> McVec3: return de(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x)
func distanceToSqr(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> float:
	var o := _xyz(a, b, c)
	return (x - o.x) * (x - o.x) + (y - o.y) * (y - o.y) + (z - o.z) * (z - o.z)
func distanceTo(o: McVec3) -> float: return sqrt(distanceToSqr(o))


## Java: abaixo de 1e-4 de comprimento devolve o vetor zero.
func normalize() -> McVec3:
	var l := length()
	return de(0, 0, 0) if l < 1.0e-4 else de(x / l, y / l, z / l)


## Giros do Minecraft (radianos): `yRot` em volta de Y, `xRot` em volta de X.
func yRot(a: float) -> McVec3:
	var c := cos(a)
	var s := sin(a)
	return de(x * c + z * s, y, z * c - x * s)


func xRot(a: float) -> McVec3:
	var c := cos(a)
	var s := sin(a)
	return de(x, y * c + z * s, z * c - y * s)


# BlockPos: as mesmas coordenadas em inteiros.
func getX() -> int: return floori(x)
func getY() -> int: return floori(y)
func getZ() -> int: return floori(z)
func above(n: int = 1) -> McVec3: return de(x, y + n, z)
func below(n: int = 1) -> McVec3: return de(x, y - n, z)
func offset(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> McVec3: return add(a, b, c)
func getCenter() -> McVec3: return de(floor(x) + 0.5, floor(y) + 0.5, floor(z) + 0.5)
func north(n: int = 1) -> McVec3: return de(x, y, z - n)
func south(n: int = 1) -> McVec3: return de(x, y, z + n)
func east(n: int = 1) -> McVec3: return de(x + n, y, z)
func west(n: int = 1) -> McVec3: return de(x - n, y, z)
func relative(direcao: Variant, n: int = 1) -> McVec3:
	match str(direcao):
		"NORTH": return north(n)
		"SOUTH": return south(n)
		"EAST": return east(n)
		"WEST": return west(n)
		"UP": return above(n)
		"DOWN": return below(n)
	return self
func containing() -> McVec3: return de(floor(x), floor(y), floor(z))


func _to_string() -> String:
	return "(%.3f, %.3f, %.3f)" % [x, y, z]
