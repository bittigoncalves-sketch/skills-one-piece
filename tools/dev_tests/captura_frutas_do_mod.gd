extends SceneTree
## Captura (com GPU) de CADA técnica das frutas do mod (13/11/2026): aperta a tecla, segura 0,5 s, solta e fotografa em 2 instantes.
## Revisão visual dos VFX de todas as frutas (a varredura headless só mede se a técnica começou).
##   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_frutas_do_mod.gd -- <pasta> fruta1 fruta2 ...
var saida := "/tmp/frutas_do_mod"
func _init() -> void:
	rodar.call_deferred()
func quadros(n: int) -> void:
	for i in n:
		await physics_frame
func foto(nome: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(saida + "/" + nome + ".png")
func rodar() -> void:
	var args := OS.get_cmdline_user_args()
	saida = args[0]
	DirAccess.make_dir_recursive_absolute(saida)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_frutas_do_mod.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = jogador.global_position + Vector3(0, 0, -8)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await quadros(10)
	var avancos = McEntidade.de(jogador).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	for id in args.slice(1):
		modo.equipar_fruta(jogador, "")
		await quadros(5)
		modo.equipar_fruta(jogador, id)
		await quadros(15)
		var c = jogador.get_node_or_null("FrutaMinePiece")
		if c == null or not c.fruta_ativa():
			print("FRUTA %s: NÃO EQUIPOU" % id)
			continue
		var lista: Array = c.estado_das_tecnicas()
		for i in mini(lista.size(), 6):
			var letra: String = ["Z", "X", "C", "V", "B", "N"][i]
			McEntidade.de(jogador).removeAllEffects()
			await quadros(3)
			jogador.energy = jogador.max_energy
			jogador.global_position = Vector3(0, 1, 0)
			jogador.velocity = Vector3.ZERO
			alvo.health = alvo.max_health
			c.usar_tecla(letra, true)
			await quadros(30)
			if is_instance_valid(c):
				c.usar_tecla(letra, false)
			await quadros(12)
			await foto("%s_%s_a" % [id, letra])
			await quadros(30)
			await foto("%s_%s_b" % [id, letra])
			await quadros(60)
	quit()
