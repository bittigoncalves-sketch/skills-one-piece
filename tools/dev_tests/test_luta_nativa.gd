extends SceneTree
## A LUTA NATIVA (A11, 30/10/2026): o Estilo de Combate Base (item "Luta") pelo controlador nativo, sem o Skills Builder. Z/X/C DIRETOS
## (teclas reais, pela HUD), dano do mod (soco 9, pesado 11 × CNT6), empurrão forte em Z e X, no C só o último golpe empurra e os da rajada
## paralisam. Não cita classes do jogo por nome (o `--script` compilaria o Player cedo).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_luta_nativa.gd
const ID := "estilo_de_combate_base"
var p: Node3D
var c
var alvo: Node3D
var passou := 0
var falhas := 0
var Imob: GDScript
var Bal: GDScript
var Cat: GDScript

class Alvo extends StaticBody3D:
	var health := 50000.0
	var hits := 0
	var danos: Array[float] = []
	var kbs: Array[float] = []
	var preso: Array[bool] = []
	func take_damage(d: float, _origem := Vector3.ZERO, kb := Vector3.ZERO, _stun := 0.0) -> void:
		danos.append(d)
		kbs.append(kb.length())
		preso.append(bool(get_meta("is_frozen", false)))
		health -= d
		hits += 1

func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func tecla(codigo: Key, apertou: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = apertou
	Input.parse_input_event(ev)

func _limpar() -> void:
	await frames(3)
	Imob.liberar(alvo)
	c.recargas.clear()
	c.imunidade.clear()
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p.health = p.max_health
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	alvo.health = 50000.0
	alvo.hits = 0
	alvo.danos.clear()
	alvo.kbs.clear()
	alvo.preso.clear()
	alvo.position = Vector3(0, 1, -1.6)
	await frames(5)

func _rodar() -> void:
	await process_frame
	Imob = load("res://src/combat/frutas_mine_piece/imobilizacao_mine_piece.gd")
	Bal = load("res://src/combat/Balance.gd")
	Cat = load("res://src/combat/frutas_mine_piece/catalogo.gd")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_luta_nativa.json"))
	modo.set("progresso_forcado", "user://test_luta_nativa.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	var prog = current_scene.progressao
	await frames(10)
	c = load("res://src/combat/frutas_mine_piece/controlador.gd").de(p)
	var a := Alvo.new()
	a.collision_layer = 1
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.2, 2.0, 1.2)
	col.shape = caixa
	a.add_child(col)
	current_scene.add_child(a)
	a.add_to_group("enemy")
	alvo = a

	print("\n-- catálogo e equipamento --")
	ok("Luta no catálogo nativo e FORA da loja", Cat.contem(ID) and not Cat.ids().has(ID))
	ok("Luta é o item ativo e o controlador nativo a assumiu", prog.item_em_uso() == "luta" and c != null and c.fruta_id == ID and c.fruta_ativa())
	ok("teclas diretas Z/X/C = 1/2/3", c.tem_teclas_diretas() and Cat.FICHAS[ID].teclas_diretas == {"Z": 1, "X": 2, "C": 3})
	ok("não depende do Skills Builder (progressão sem kit)", prog.tem_estilo_base() and prog.fruta_a_equipar() == ID)
	var escala := 0.1       # PerfilDeFrutas.ESCALA_DO_MOD: dano do mod = dano × 10 × 0,1
	var forca := 3.0        # o efeito Força do nível 1 soma +3 de dano físico em todo golpe (progressão do mod, não da Luta)
	var tab: Dictionary = Bal.MINE_PIECE_LUTA

	print("\n-- menu de técnicas --")
	var hud = current_scene.get_node("HistoriaHud")
	var menu = hud.get("_tecnicas")
	await frames(5)
	ok("o menu mostra as três técnicas da Luta", menu.texto_da_linha("Soco") != "" and menu.texto_da_linha("Soco pesado") != "" and menu.texto_da_linha("Sequência de socos") != "")
	var teclas_ok := true
	for par in [["Soco", "[Z]"], ["Soco pesado", "[X]"], ["Sequência de socos", "[C]"]]:
		var linha: Dictionary = menu.get("_linhas")[par[0]]
		teclas_ok = teclas_ok and (linha.tecla as Label).text == par[1]
	ok("cada linha leva a SUA tecla ([Z] [X] [C]) e o título não manda apertar R", teclas_ok and not (menu.get("_titulo") as Label).text.contains("R troca"))

	print("\n-- Z: soco --")
	await _limpar()
	var antes: float = p.energy
	tecla(KEY_Z, true)
	await frames(1)
	tecla(KEY_Z, false)
	ok("Z começa o soco (técnica 1)", c.ativo and c.selecao == 1)
	ok("custa 2 de energia e recarrega 0,65 s", absf(antes - float(p.energy) - 2.0) < 0.5 and is_equal_approx(c.recarga_total, 0.65))
	ok("o golpe NÃO sai no mesmo quadro (acontece no 2º tick, 0,1 s)", alvo.hits == 0)
	await frames(12)
	ok("e já saiu uma vez no 2º tick", alvo.hits == 1)
	await frames(50)
	ok("um contato, dano 9 + Força 3 (o 9 é o do mod: 9 × CNT6) — %.2f" % (alvo.danos[0] if not alvo.danos.is_empty() else -1.0), alvo.hits == 1 and is_equal_approx(alvo.danos[0], float(tab.soco.dano) * escala + forca))
	ok("empurra 9 (era 3)", not alvo.kbs.is_empty() and absf(alvo.kbs[0] - 9.0) < 0.2)
	ok("termina em ~0,5 s e solta o corpo", not c.ativo and not p.has_meta("pose_de_skill"))
	await frames(60)
	ok("Z de novo depois da recarga funciona", true)

	print("\n-- recarga por técnica (não global) --")
	await _limpar()
	tecla(KEY_Z, true); await frames(1); tecla(KEY_Z, false)
	await frames(40)
	ok("com Z em recarga, o X começa (cada técnica tem a sua)", not c.ativo)
	tecla(KEY_X, true); await frames(1); tecla(KEY_X, false)
	ok("X começou durante a recarga do Z (técnica 2)", c.ativo and c.selecao == 2)
	await frames(90)
	await _limpar()
	tecla(KEY_Z, true); await frames(1); tecla(KEY_Z, false)
	await frames(35)           # fim do Z (0,5 s = 30 quadros)
	var antes_hits: int = alvo.hits
	tecla(KEY_Z, true); await frames(1); tecla(KEY_Z, false)
	await frames(3)
	ok("Z de novo ANTES de 0,65 s é recusado", not c.ativo or alvo.hits == antes_hits and c.recargas.get(1, 0.0) > 0.0 and not (c.ativo and c.selecao == 1 and c.recargas.get(1, 0.0) > 0.6))

	print("\n-- X: soco pesado --")
	await _limpar()
	tecla(KEY_X, true); await frames(1); tecla(KEY_X, false)
	await frames(20)
	ok("o pesado NÃO acerta antes do preparo (0,35 s + 2 ticks)", alvo.hits == 0)
	await frames(75)
	ok("um contato, dano 11 + Força 3 (o 11 é o do mod) — %.2f" % (alvo.danos[0] if not alvo.danos.is_empty() else -1.0), alvo.hits == 1 and is_equal_approx(alvo.danos[0], float(tab.pesado.dano) * escala + forca))
	ok("empurra 27 (era 18)", not alvo.kbs.is_empty() and absf(alvo.kbs[0] - 27.0) < 0.5)
	ok("custa 4 e termina sozinho", not c.ativo)
	await _limpar()
	tecla(KEY_X, true)
	await frames(40)
	ok("segurar X carrega sem acertar", c.ativo and alvo.hits == 0)
	await frames(60)           # passa do teto de carga (1,25 s): o golpe sai sozinho com o máximo
	tecla(KEY_X, false)
	await frames(80)
	ok("X carregado ganha 50 %% de dano (%.2f)" % (alvo.danos[0] if not alvo.danos.is_empty() else -1.0), alvo.hits == 1 and is_equal_approx(alvo.danos[0], float(tab.pesado.dano) * escala * 1.5 + forca))

	print("\n-- C: sequência --")
	await _limpar()
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	await frames(180)
	var n: int = alvo.kbs.size()
	ok("C acerta vários golpes (%d)" % n, n >= 7)
	var so_o_ultimo: bool = n >= 2 and alvo.kbs[n - 1] > 20.0
	for i in n - 1:
		so_o_ultimo = so_o_ultimo and alvo.kbs[i] < 0.001
	ok("só o ÚLTIMO golpe empurra (%.1f)" % (alvo.kbs[n - 1] if n > 0 else 0.0), so_o_ultimo)
	var presos := 0
	for i in range(1, n - 1):
		presos += 1 if alvo.preso[i] else 0
	ok("os da rajada acham o alvo paralisado (%d de %d)" % [presos, maxi(n - 2, 0)], n >= 4 and presos >= n - 2)
	ok("o golpe final chega com o alvo SOLTO", n >= 2 and not alvo.preso[n - 1])
	ok("rajada 0,8 por golpe e final 13,2, mais a Força 3 de cada um", n >= 2 and is_equal_approx(alvo.danos[0], float(tab.rajada.dano) * escala + forca) and is_equal_approx(alvo.danos[n - 1], float(tab["final"].dano) * escala + forca))
	await frames(40)
	ok("a paralisia acaba e a técnica termina", not Imob.ativa(alvo) and not c.ativo)
	await _limpar()
	tecla(KEY_C, true)
	await frames(220)          # segura além do teto (2,55 s)
	tecla(KEY_C, false)
	await frames(60)
	ok("segurar C prolonga a rajada até o teto e termina sozinho", alvo.hits > n and not c.ativo)

	print("\n-- interrupções --")
	await _limpar()
	tecla(KEY_X, true); await frames(1); tecla(KEY_X, false)
	await frames(4)
	p.health -= 1.0
	await frames(90)
	ok("apanhar no meio do preparo cancela: nenhum contato atrasado", alvo.hits == 0 and not c.ativo)
	await _limpar()
	ok("a Luta responde de novo depois de cancelar", true)
	tecla(KEY_Z, true); await frames(1); tecla(KEY_Z, false)
	await frames(60)
	ok("e o soco acerta", alvo.hits == 1)

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("LUTA_NATIVA %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
