extends SceneTree
# ============================================================================
#  VELOCIDADE E PULO DO MINE PIECE (27/10/2026, A6b): `PlayerPhysicalAbilityProcedure`.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_velocidade_mine_piece.gd
#
#  O componente é passo a passo (tique de 0,05 s) com um corpo de mentira: confere a rampa (um nível a cada 0,2 s), os tetos por
#  nível, a queda em ~0,4 s ao parar e a carga do pulo agachado, contra os números da procedure.
# ============================================================================

class CorpoFalso extends Node3D:
	var correndo := false
	var _agachar := Agachar.new()
	var chao := true
	func _is_sprinting() -> bool: return correndo
	func is_on_floor() -> bool: return chao
class Agachar extends RefCounted:
	var ativo := false

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func perto(a: float, b: float, tol := 0.0001) -> bool:
	return absf(a - b) <= tol


func andar(v: VelocidadeMinePiece, segundos: float) -> void:
	for i in int(segundos / 0.05):
		v._physics_process(0.05)


func novo(nivel: int) -> Array:
	var c := CorpoFalso.new()
	c.set_meta("nivel_historia", nivel)
	var v := VelocidadeMinePiece.new()
	v.jogador = c
	return [c, v]


func rodar() -> void:
	print("\n-- nível 1: sem ganho (n = nível − 1 = 0) --")
	var a := novo(1)
	a[0].correndo = true
	andar(a[1], 3.0)
	ok(perto(a[1].fator_de_velocidade(), 1.0), "correndo no nível 1 não ganha Velocidade")

	print("\n-- nível 21: Velocidade sobe um nível a cada ~0,2 s até o teto round(n × 0,5) = 10 --")
	var b := novo(21)
	b[0].correndo = true
	andar(b[1], 0.3)
	var f0: float = b[1].fator_de_velocidade()
	andar(b[1], 0.5)
	var f1: float = b[1].fator_de_velocidade()
	ok(f0 >= 1.2 - 0.0001 and f1 > f0, "começa em +20 %% e acelera (%.2f → %.2f)" % [f0, f1])
	andar(b[1], 3.0)
	ok(perto(b[1].fator_de_velocidade(), 1.0 + 0.2 * 11), "chega ao teto: 11 níveis = ×%.2f" % b[1].fator_de_velocidade())
	b[0].correndo = false
	andar(b[1], 0.6)
	ok(perto(b[1].fator_de_velocidade(), 1.0), "parou de correr: o ganho cai em ~0,4 s")

	print("\n-- nível 2: teto round(0,5) = 1 --")
	var c2 := novo(2)
	c2[0].correndo = true
	andar(c2[1], 3.0)
	ok(perto(c2[1].fator_de_velocidade(), 1.0 + 0.2 * 2), "nível 2 chega a Velocidade II (×1,4)")

	print("\n-- Pulo: agachado carrega até round(n / 4) --")
	var d := novo(21)
	d[0]._agachar.ativo = true
	andar(d[1], 0.15)
	var p0: float = d[1].fator_de_pulo()
	andar(d[1], 3.0)
	var teto := (0.42 + 0.1 * 6) / 0.42
	ok(p0 > 1.0 and perto(d[1].fator_de_pulo(), teto), "agachado o pulo sobe até o teto (×%.2f, esperado ×%.2f)" % [d[1].fator_de_pulo(), teto])
	d[0]._agachar.ativo = false
	andar(d[1], 0.6)
	ok(perto(d[1].fator_de_pulo(), 1.0), "soltou o agachar: o ganho de pulo some")

	print("\n-- no ar: o pulo vem da Velocidade que o corpo tinha --")
	var e := novo(21)
	e[0].correndo = true
	andar(e[1], 3.0)                                   # Velocidade no teto (amplificador 10)
	e[0].chao = false
	andar(e[1], 0.4)
	ok(e[1].fator_de_pulo() > 1.0, "no ar, quem vinha rápido ganha Pulo (×%.2f)" % e[1].fator_de_pulo())
	var f := novo(21)                                  # sem correr antes: Velocidade 0 → Pulo 0
	f[0].chao = false
	andar(f[1], 0.6)
	ok(f[1].fator_de_pulo() <= (0.42 + 0.1) / 0.42 + 0.0001, "no ar sem ter corrido, o Pulo fica no mínimo")

	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
