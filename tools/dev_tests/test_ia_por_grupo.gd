extends SceneTree
## IA unificada separada em duas (10/11/2026): inimigos por FACÇÃO (coesão de esquadrão + alerta) e animais por LOCOMOÇÃO
## (voador / aquático / terrestre: só os raios mudam). Nós sintéticos; o jogador é um Node3D no grupo "player".
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)

func _boneco(nome: String, x: float) -> BonecoDeDuelo:
	var b := BonecoDeDuelo.new()
	b.name = nome
	b.set_meta("faccao", "bandidos" if nome == "Bandido" else "bonecos")     # como o ninho grava
	root.add_child(b)
	b.global_position = Vector3(x, 0, 0)
	b.add_to_group("enemy")
	return b

func _animal(grupo: String, voa: bool, x: float) -> Node3D:
	var gd := GDScript.new()
	gd.source_code = "extends CharacterBody3D\nvar ficha = {}\nvar health = 10.0\nvar max_health = 10.0\nfunc vivo(): return true\nfunc em_combate(): return false\n"
	gd.reload()
	var a := CharacterBody3D.new()
	a.set_script(gd)
	a.ficha = {"corpo": "voador" if voa else "quadrupede"}
	root.add_child(a)
	a.global_position = Vector3(x, 0, 0)
	a.add_to_group(grupo)
	return a

func _init() -> void: rodar.call_deferred()

func rodar() -> void:
	await process_frame
	var jogador := Node3D.new()
	jogador.add_to_group("player")
	root.add_child(jogador)
	jogador.global_position = Vector3.ZERO
	# ---------------------------------------------------- inimigos por facção
	var ia := IaDosInimigos.new()
	root.add_child(ia)
	ok(IaDosInimigos.faccao_de(_boneco("Bandido", 9999)) == "bandidos" and IaDosInimigos.faccao_de(_boneco("Boneco", 9999)) == "bonecos", "facção: Bandido = bandidos, Boneco = bonecos")
	var b1 := _boneco("Bandido", 55.0)     # dentro de 80 m: acordado por si
	var b3 := _boneco("Bandido", 82.0)     # além de 80 m, mas a 27 m do b1 → coesão o mantém acordado
	var b2 := _boneco("Bandido", 120.0)    # longe de todos → dorme
	var bo := _boneco("Boneco", 82.0)      # outra facção, além de 80 m, sem companheiro → dorme
	await process_frame
	ia.varrer(0.5)
	ok(not IaUnificada.dormindo(b1), "perto do jogador: acordado")
	ok(not IaUnificada.dormindo(b3), "coesão: a 27 m de um companheiro acordado, não congela")
	ok(IaUnificada.dormindo(b2), "longe de todos: dorme")
	ok(IaUnificada.dormindo(bo), "outra facção não ganha coesão de bando alheio: dorme")
	ok(not b2.is_physics_processing() and b2.get_child(0).process_mode == Node.PROCESS_MODE_DISABLED, "dormir para o corpo e os filhos")
	# alerta de facção
	var b4 := _boneco("Bandido", 70.0)
	var b5 := _boneco("Bandido", 300.0)
	var bo2 := _boneco("Boneco", 62.0)
	IaUnificada.dormir(b4); IaUnificada.dormir(b5); IaUnificada.dormir(bo2)
	IaUnificada.acordar_por_dano(b1)
	ok(not IaUnificada.dormindo(b4), "alerta: aliado da mesma facção a 15 m acorda")
	ok(IaUnificada.dormindo(b5), "alerta: aliado a 245 m continua dormindo")
	ok(IaUnificada.dormindo(bo2), "alerta: outra facção perto NÃO acorda")
	ok(int(b4.get_meta(IaUnificada.META_ATE, 0)) > Time.get_ticks_msec(), "alertado fica acordado por um tempo")
	# acordar ao chegar perto
	jogador.global_position = Vector3(110, 0, 0)
	ia.varrer(0.5)
	ok(not IaUnificada.dormindo(b2), "jogador a 10 m: o dormente acorda")
	jogador.global_position = Vector3.ZERO
	# ---------------------------------------------------- animais por locomoção
	var ani := IaDosAnimais.new()
	root.add_child(ani)
	var t := _animal("animais", false, 100.0)        # terrestre a 100 m: dorme (>70)
	var v := _animal("animais", true, 100.0)         # voador a 100 m: fica (<110)
	var q := _animal("bestas_do_mar", false, 100.0)  # aquático a 100 m: dorme (>90)
	var v_longe := _animal("animais", true, 130.0)   # voador a 130 m: dorme (>110)
	ok(IaDosAnimais.locomocao_de(t) == "terrestre" and IaDosAnimais.locomocao_de(v) == "voador" and IaDosAnimais.locomocao_de(q) == "aquatico", "locomoção: terrestre / voador / aquático")
	ani.varrer(0.5)
	ok(IaUnificada.dormindo(t), "terrestre a 100 m dorme")
	ok(not IaUnificada.dormindo(v), "voador a 100 m continua acordado (visto de mais longe)")
	ok(IaUnificada.dormindo(q), "aquático a 100 m dorme")
	ok(IaUnificada.dormindo(v_longe), "voador a 130 m dorme")
	jogador.global_position = Vector3(60, 0, 0)       # terrestre a 40 m: acorda (<50)
	ani.varrer(0.5)
	ok(not IaUnificada.dormindo(t), "terrestre a 40 m acorda")
	# chefe não dorme
	var chefe := _animal("animais", false, 500.0)
	chefe.add_to_group("chefes")
	jogador.global_position = Vector3.ZERO
	ani.varrer(0.5)
	ok(not IaUnificada.dormindo(chefe), "chefe nunca dorme")
	# gerenciadores separados: um não mexe nos do outro
	ok(not IaUnificada.dormindo(b1), "a IA dos animais não mexe nos inimigos")
	print("test_ia_por_grupo: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
