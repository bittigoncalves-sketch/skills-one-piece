extends SceneTree
## Mede o recuo pela via do MOD (KnockbackProcedure traduzido → EntityVectorProcedure → setDeltaMovement): o jogador empurra um pirata parado
## com `knockback` = 0,1 … 2,5 e se mede até onde ele vai (a IA do alvo é desligada para só medir o empurrão).
##   "$(./find_godot.sh)" --headless --fixed-fps 60 --path . --script tools/dev_tests/medir_empurrao_do_mod.gd
const SAVE := "user://medir_empurrao_mod.json"
func _init() -> void: rodar.call_deferred()
func quadros(n: int) -> void:
	for i in n: await physics_frame
func rodar() -> void:
	await process_frame
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(400, 2, 400)
	MapaArquivo.salvar("user://medir_empurrao_mapa.json", mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "user://medir_empurrao_mapa.json")
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var dono := McEntidade.de(j)
	print("knockback_mod | recuo máx (m) | em blocos do jogo (0,88 m)   [IA do alvo: %s]" % ("LIGADA" if "--ia" in OS.get_cmdline_user_args() else "desligada"))
	for k: float in [0.1, 0.5, 1.0, 1.5, 2.0, 2.5]:
		var ficha := DadosEastBlue.ficha("pirate")
		var alvo := PersonagemMinePiece.new()
		alvo.montar(ficha, str(ficha.get("modelo", "")))
		alvo.renasce = false
		current_scene.add_child(alvo)
		alvo.global_position = j.global_position + Vector3(0, 0.1, -3.0)
		await quadros(10)
		if not "--ia" in OS.get_cmdline_user_args():
			alvo.cerebro = null
		alvo.max_health = 100000.0
		alvo.health = 100000.0
		var p0 := alvo.global_position
		dono.getPersistentData().putDouble("knockback", k)
		dono.getPersistentData().putDouble("Range", 40.0)
		dono.getPersistentData().putDouble("effect", 0.0)
		Mc.proc(&"KnockbackProcedure").execute(Mc.mundo(self), j.global_position.x / 0.88, j.global_position.y / 0.88, j.global_position.z / 0.88, dono)
		var rec := 0.0
		for i in 300:
			await physics_frame
			rec = maxf(rec, p0.z - alvo.global_position.z)         # para longe do jogador (-Z)
		print("%5.1f | %8.2f | %6.1f" % [k, rec, rec / 0.88])
		alvo.queue_free()
		await quadros(5)
	quit()
