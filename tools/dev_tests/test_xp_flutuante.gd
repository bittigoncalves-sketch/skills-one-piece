extends SceneTree
# O XP no nome do inimigo derrotado (15/11/2026): ao derrotar um personagem do East Blue aparece um XpFlutuante com o nome e "+N XP", que some sozinho.
#   DISPLAY=:1 godot --path . -s tools/dev_tests/test_xp_flutuante.gd -- [pasta_de_captura]
var _ok_n := 0
var _falhas := 0
func _ok(c: bool, r: String) -> void:
	if c: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if c else "❌", r])
func quadros(n: int) -> void:
	for i in n:
		await physics_frame
func _flutuantes() -> Array:
	return current_scene.find_children("*", "Node3D", true, false).filter(func(n): return n is XpFlutuante)
func _init() -> void:
	rodar.call_deferred()
func rodar() -> void:
	var args := OS.get_cmdline_user_args()
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_xp_flutuante.json")
	root.get_node("GameFlow").start_story()
	await quadros(200)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var p := PersonagemMinePiece.new()
	var id_comum := ""                                   # um personagem que NÃO é chefe (chefe tem vida em barras e não morre de um golpe)
	for id in DadosEastBlue.ids():
		var f: Dictionary = DadosEastBlue.ficha(str(id))
		if not bool(f.get("chefe", false)) and str(f.get("faccao", "")) != "aliado":
			id_comum = str(id)
			break
	print("      personagem do teste: ", id_comum)
	p.montar(DadosEastBlue.ficha(id_comum), "mp_" + id_comum)
	p.position = j.global_position + Vector3(0, 0, -5)
	p.ponto_de_origem = p.position
	current_scene.add_child(p)
	current_scene._ao_nascer_personagem_natural(p)      # o mesmo caminho dos personagens que o jogo gera: liga `derrotado` ao fluxo de XP
	await quadros(20)
	_ok(_flutuantes().is_empty(), "antes do abate não há XP flutuante")
	var xp0: int = current_scene.progressao.xp
	p.take_damage(1.0e9, j.global_position, Vector3.ZERO, 0.0)
	for i in 150:                                        # a morte tem animação: o sinal `derrotado` vem depois dela
		await physics_frame
		if not _flutuantes().is_empty():
			break
	print("      xp antes/depois: ", xp0, " / ", current_scene.progressao.xp, " vivo=", p.vivo())
	var f := _flutuantes()
	_ok(f.size() == 1, "um XP flutuante aparece ao derrotar (%d)" % f.size())
	if f.size() == 1:
		var textos: Array = (f[0] as Node).get_children().filter(func(n): return n is Label3D).map(func(l): return (l as Label3D).text)
		print("      textos: ", textos)
		_ok(textos.size() == 1, "o corpo já tem plaqueta de nome: só o XP é acrescentado, logo acima dela")
		_ok(str(textos[0]).begins_with("+") and str(textos[0]).ends_with(" XP"), "mostra '+N XP' (%s)" % str(textos[0]))
		var ganho: int = int(str(textos[0]).trim_prefix("+").trim_suffix(" XP"))
		_ok(ganho > 0, "o número é positivo (%d)" % ganho)
		_ok(current_scene.progressao.xp - xp0 == ganho or current_scene.progressao.nivel > 1, "bate com o XP somado à progressão (%d)" % (current_scene.progressao.xp - xp0))
		if args.size() > 0:
			DirAccess.make_dir_recursive_absolute(args[0])
			await process_frame
			root.get_viewport().get_texture().get_image().save_png(args[0] + "/xp_flutuante.png")
	await create_timer(3.2).timeout
	_ok(_flutuantes().is_empty(), "o XP flutuante some sozinho")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nXP_FLUTUANTE %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
