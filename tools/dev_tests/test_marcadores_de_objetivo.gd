extends SceneTree
## Marcadores de missão em CADA objetivo (22/11/2026): nós registrados, espécies vivas, limite por missão, ligar/desligar.
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1

class Alvo extends Node3D:
	var especie := ""
	var health := 10.0
	var ficha := {}

func _init() -> void: _rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	var M := preload("res://src/ui/marcador_de_missao.gd")
	var prog := ProgressaoDoPersonagem.new()
	var marcador: Control = M.new()
	root.add_child(marcador)
	marcador.progressao = prog
	marcador.jogador_de = func() -> Node3D: return null
	ok("sem missão aceita nada é marcado por objetivo", marcador.alvos().is_empty())
	# nós registrados (cachos de banana)
	var cachos: Array[Node3D] = []
	for i in 8:
		var n := Node3D.new()
		root.add_child(n)
		n.position = Vector3(i, 0, 0)
		M.marcar(n, "cesto_de_bananas", 3.2, true)
		cachos.append(n)
	ok("missão ainda não aceita: os cachos não aparecem", marcador.alvos().is_empty())
	prog.aceitar_missao("cesto_de_bananas")
	var a: Array = marcador.alvos()
	ok("missão aceita: cada objetivo ganha losango, no máximo %d por missão (%d)" % [M.MAX_POR_MISSAO, a.size()], a.size() == M.MAX_POR_MISSAO)
	ok("a altura do losango vem do registro (3,2 m)", a.all(func(x): return is_equal_approx(float(x["altura"]), 3.2)) and a.all(func(x): return not bool(x["entregar"])))
	for n in cachos:
		M.marcar(n, "cesto_de_bananas", 3.2, false)
	ok("colhido (desligado): o marcador some", marcador.alvos().is_empty())
	M.marcar(cachos[0], "cesto_de_bananas", 3.2, true)
	cachos[0].visible = false
	ok("objetivo escondido (colhido/visível=false) não é marcado", marcador.alvos().is_empty())
	cachos[0].visible = true
	ok("e volta a ser marcado se reaparece", marcador.alvos().size() == 1)
	# desligar por outra missão não apaga o registro da missão atual
	M.marcar(cachos[0], "os_quatro_totens", 6.0, false)
	ok("desligar para OUTRA missão não mexe no registro desta", marcador.alvos().size() == 1)
	# espécies vivas: Gorila-rei e macacos saqueadores
	var rei := Alvo.new()
	rei.especie = "gorila_rei"
	rei.add_to_group(AlvosDeGolpe.GRUPO)
	root.add_child(rei)
	prog.aceitar_missao("rei_da_selva")
	var com_rei: Array = marcador.alvos().filter(func(x): return x["no"] == rei)
	ok("Gorila-rei vivo é marcado (losango alto, 7,5 m)", com_rei.size() == 1 and is_equal_approx(float(com_rei[0]["altura"]), 7.5))
	rei.health = 0.0
	ok("Gorila-rei morto sai do marcador", marcador.alvos().filter(func(x): return x["no"] == rei).is_empty())
	var macacos: Array[Alvo] = []
	for i in 10:
		var m := Alvo.new()
		m.ficha = {"id": "macaco_humanoide"}
		m.add_to_group(AlvosDeGolpe.GRUPO)
		root.add_child(m)
		macacos.append(m)
	prog.aceitar_missao("os_saqueadores")
	var sq: Array = marcador.alvos().filter(func(x): return macacos.has(x["no"]))
	ok("saqueadores: marcados os %d mais perto (de 10 vivos)" % M.MAX_POR_MISSAO, sq.size() == M.MAX_POR_MISSAO)
	# dados das missões
	var Ms := preload("res://src/historia/missoes/missoes.gd")
	ok("a tabela marca o Gorila-rei e os saqueadores", Ms.dados("rei_da_selva")["marcar"]["alvos_de_golpe"] == "gorila_rei" and Ms.dados("os_saqueadores")["marcar"]["alvos_de_golpe"] == "macaco_humanoide")
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
