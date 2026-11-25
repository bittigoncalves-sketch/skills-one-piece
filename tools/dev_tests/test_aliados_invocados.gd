extends SceneTree
## REGRESSÃO (10/11/2026): "a fruta do biscoito gera aliados e eles não estão interativos". A criatura invocada por uma fruta nascia
## como `McCorpoDoMod` (corpo virtual: sem colisão, sem hurtbox, sem metas) e ficava parada. Agora nasce como `PersonagemMinePiece`
## (`McAliadoDoMod`), liga-se ao dono, persegue inimigos, segue o dono e é alvo de inimigos.
##   godot --headless --path . --script tools/dev_tests/test_aliados_invocados.gd
const MAPA := "user://test_aliados_invocados.json"
const SAVE := "user://test_aliados_invocados_progresso.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(160, 2, 160)
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var m = current_scene
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	m.call("equipar_fruta", j, "bisu_bisu")
	await quadros(30)
	# o mod cria o guerreiro pelo mesmo caminho que a técnica usa
	var dono := McEntidade.de(j)
	ItensDoMod.dar(self, ItensDoMod.BISCOITO, 5)           # o guerreiro de biscoito gasta 1 biscoito
	var tipo := Mc.tipo_entidade(&"minepiece:biscuit_warrrior")
	var ent: McEntidade = tipo.create(Mc.mundo(self), null, null, McVec3.de(j.global_position.x / 0.88 + 4.0, 0.0, j.global_position.z / 0.88), null, false, false)
	Mc.proc(&"SetSummonedEntityProcedure").execute(dono, ent)
	await quadros(5)
	var w := ent.no as PersonagemMinePiece
	ok(w != null, "o guerreiro é um PersonagemMinePiece (não o corpo virtual)")
	if w == null:
		print("test_aliados_invocados: %d ok, %d falhas" % [_ok, _f]); quit(1); return
	ok(w.collision_layer != 0 and w.get_node_or_null("Hurtbox") != null or w.find_children("*", "Area3D", true, false).size() > 0, "tem colisão e hurtbox")
	ok(w.is_in_group("invocados_do_jogador") and not w.is_in_group("enemy"), "aliado do jogador: no grupo dele e fora de 'enemy'")
	ok(not w.is_in_group(AlvosDeGolpe.GRUPO), "o jogador não o golpeia")
	ok(is_equal_approx(w.max_health, 70.0 * (1.0 + 0.0)) or w.max_health >= 70.0, "vida vem do mod (70 ou escalada pelo nível do dono)")
	ok(float(w.ficha.get("altura", 0.0)) > 3.0, "altura do mod (3,6 blocos × 0,88 m)")
	# 1) segue o dono: sem inimigo por perto, anda até ficar perto do jogador
	j.global_position = Vector3(20, 1, 0)
	var d0 := w.global_position.distance_to(j.global_position)
	await quadros(240)
	var d1 := w.global_position.distance_to(j.global_position)
	ok(d1 < d0 - 5.0, "segue o dono (distância %.1f → %.1f m)" % [d0, d1])
	# 2) persegue e fere um inimigo
	var inimigo := PersonagemMinePiece.new()
	inimigo.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	inimigo.position = w.global_position + Vector3(0, 0, -9)
	inimigo.ponto_de_origem = inimigo.position
	current_scene.add_child(inimigo)
	var v0 := inimigo.health
	var dist0 := w.global_position.distance_to(inimigo.global_position)
	await quadros(360)
	ok(w.cerebro != null and (w.cerebro.alvo == inimigo or inimigo.health < v0), "escolhe o inimigo como alvo")
	ok(inimigo.health < v0 or not inimigo.vivo(), "fere o inimigo (vida %.1f → %.1f)" % [v0, inimigo.health])
	# 3) o inimigo o enxerga como alvo (facção 'nenhuma' ataca todos)
	var e2 := PersonagemMinePiece.new()
	e2.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	e2.position = Vector3(-30, 0, -30)
	current_scene.add_child(e2)
	await quadros(5)
	ok(e2.cerebro._hostil_a(w), "inimigo comum vê o aliado do jogador como alvo")
	ok(dist0 > 0.0, "(controle) distância inicial medida")
	print("test_aliados_invocados: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
