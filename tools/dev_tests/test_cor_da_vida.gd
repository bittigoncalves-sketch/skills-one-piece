extends SceneTree
## A cor da vida (30/10/2026): cheia verde, metade amarela, baixa vermelha; contínua; a barra do HUD a segue.
var _falhas := 0
func _init() -> void:
	call_deferred("_r")
func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _falhas += 1
func _perto(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01
func _r() -> void:
	_ok(_perto(Estilo.cor_da_vida(1.0), Estilo.VIDA), "100 % = verde")
	_ok(_perto(Estilo.cor_da_vida(0.5), Estilo.VIDA_AMARELA), "50 % = amarelo")
	_ok(_perto(Estilo.cor_da_vida(0.25), Estilo.VIDA_VERMELHA), "25 % = vermelho")
	_ok(_perto(Estilo.cor_da_vida(0.05), Estilo.VIDA_VERMELHA) and _perto(Estilo.cor_da_vida(0.0), Estilo.VIDA_VERMELHA), "abaixo de 25 % segue vermelho")
	var c75 := Estilo.cor_da_vida(0.75)
	_ok(c75.g > Estilo.VIDA_AMARELA.g * 0.9 and c75.r < Estilo.VIDA_AMARELA.r and c75.r > Estilo.VIDA.r, "75 % fica entre amarelo e verde")
	var c375 := Estilo.cor_da_vida(0.375)
	_ok(c375.r > Estilo.VIDA_VERMELHA.r * 0.9 and c375.g > Estilo.VIDA_VERMELHA.g and c375.g < Estilo.VIDA_AMARELA.g, "37,5 % fica entre vermelho e amarelo")
	var salto := 0.0
	var anterior := Estilo.cor_da_vida(0.0)
	for i in 101:
		var c := Estilo.cor_da_vida(i / 100.0)
		salto = maxf(salto, absf(c.r - anterior.r) + absf(c.g - anterior.g) + absf(c.b - anterior.b))
		anterior = c
	_ok(salto < 0.12, "contínua: maior salto entre 1 %% e 1 %% = %.3f" % salto)
	_ok(Estilo.LIMITE_VERMELHO == 0.25, "limite vermelho = 25 % (o da pokébola)")
	var barra := BarraHud.new()
	barra.cor_pela_vida = true
	barra.valor(0.2)
	_ok(_perto(barra.cor, Estilo.VIDA_VERMELHA), "BarraHud com cor_pela_vida fica vermelha em 20 %")
	barra.valor(1.0)
	_ok(_perto(barra.cor, Estilo.VIDA), "e verde de novo em 100 %")
	var fixa := BarraHud.new()
	fixa.valor(0.1)
	_ok(_perto(fixa.cor, Estilo.VIDA), "barra sem a opção (energia etc.) não muda de cor")
	print("\n%s" % ("TUDO CERTO" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas else 0)
