class_name McAabb
extends RefCounted
## `AABB` do Minecraft, em blocos.

var min_ := McVec3.new()
var max_ := McVec3.new()


static func de(a: McVec3, b: McVec3) -> McAabb:
	var r := McAabb.new()
	r.min_ = McVec3.de(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	r.max_ = McVec3.de(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return r


## `AABB.ofSize(centro, largura, altura, profundidade)`.
static func de_tamanho(c: McVec3, w: float, h: float, d: float) -> McAabb:
	return de(McVec3.de(c.x - w * 0.5, c.y - h * 0.5, c.z - d * 0.5), McVec3.de(c.x + w * 0.5, c.y + h * 0.5, c.z + d * 0.5))


func inflate(a: float, b: Variant = null, c: Variant = null) -> McAabb:
	var bb := a if b == null else float(b)
	var cc := a if c == null else float(c)
	return de(McVec3.de(min_.x - a, min_.y - bb, min_.z - cc), McVec3.de(max_.x + a, max_.y + bb, max_.z + cc))


func move(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> McAabb:
	return de(min_.add(a, b, c), max_.add(a, b, c))


func contains(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> bool:
	var p := McVec3._xyz(a, b, c)
	return p.x >= min_.x and p.x < max_.x and p.y >= min_.y and p.y < max_.y and p.z >= min_.z and p.z < max_.z


func intersects(o: McAabb) -> bool:
	return min_.x < o.max_.x and max_.x > o.min_.x and min_.y < o.max_.y and max_.y > o.min_.y \
		and min_.z < o.max_.z and max_.z > o.min_.z


func getCenter() -> McVec3:
	return McVec3.de((min_.x + max_.x) * 0.5, (min_.y + max_.y) * 0.5, (min_.z + max_.z) * 0.5)
