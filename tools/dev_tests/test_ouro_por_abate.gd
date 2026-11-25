extends SceneTree
## Ouro por abate (20/11/2026): 1 moeda a cada 50 de XP efetivo, arredondado para baixo; sem XP (teto anti-farm) não paga.
##   godot --headless --path . --script res://tools/dev_tests/test_ouro_por_abate.gd
var passou := 0
var falhas := 0
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func _init() -> void:
	var p := ProgressaoDoPersonagem.new()
	ok("constante: 50 XP por moeda", ProgressaoDoPersonagem.XP_POR_MOEDA == 50)
	ok("49 XP = 0 moedas e não mexe no ouro", p.ganhar_ouro_de_abate(49) == 0 and p.ouro == 0)
	ok("50 XP = 1 moeda", p.ganhar_ouro_de_abate(50) == 1 and p.ouro == 1)
	ok("60 XP (um bandido) = 1 moeda", p.ganhar_ouro_de_abate(60) == 1 and p.ouro == 2)
	ok("150 XP = 3 moedas", p.ganhar_ouro_de_abate(150) == 3 and p.ouro == 5)
	ok("0 e XP negativo não pagam", p.ganhar_ouro_de_abate(0) == 0 and p.ganhar_ouro_de_abate(-100) == 0 and p.ouro == 5)
	var emitiu := [0]
	p.mudou.connect(func(): emitiu[0] += 1)
	p.ganhar_ouro_de_abate(100)
	ok("pagar emite `mudou` uma vez (salva)", emitiu[0] == 1 and p.ouro == 7)
	var d := p.para_dict()
	ok("o ouro vai para o save", ProgressaoDoPersonagem.de_dict(d).ouro == 7)
	print("OURO_POR_ABATE %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
