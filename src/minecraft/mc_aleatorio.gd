class_name McAleatorio
extends RefCounted
## `RandomSource` do Minecraft (`entity.getRandom()`, `RandomSource.create()`).

var rng: RandomNumberGenerator


static func de(r: RandomNumberGenerator = null) -> McAleatorio:
	var a := McAleatorio.new()
	a.rng = r if r != null else RandomNumberGenerator.new()
	if r == null:
		a.rng.randomize()
	return a


func nextFloat() -> float: return rng.randf()
func nextDouble() -> float: return rng.randf()
func nextBoolean() -> bool: return rng.randf() < 0.5
## `nextInt()` (qualquer) / `nextInt(n)` em [0, n) / `nextInt(a, b)` em [a, b).
func nextInt(a: int = -1, b: int = -1) -> int:
	if a < 0:
		return rng.randi()
	if b < 0:
		return rng.randi_range(0, a - 1)
	return rng.randi_range(a, b - 1)
func nextGaussian() -> float: return rng.randfn(0.0, 1.0)
