extends SceneTree
const Piloto := preload("res://src/historia/corrida/piloto_de_caranguejo.gd")
var _p: RefCounted
var _c: Node
var _m: Node
var _ultimo := {}
func _init() -> void:
	_ir.call_deferred()
func _ir() -> void:
	await process_frame
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar("user://dbg_corrida_mapa.json", lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "user://dbg_corrida_mapa.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://dbg_corrida.json"))
	modo.set("progresso_forcado", "user://dbg_corrida.json")
	root.get_node("GameFlow").start_story()
	for i in 120: await physics_frame
	_c = current_scene.get("corrida")
	_m = current_scene.get("_montarias")
	print(_c.pedir_largada())
	_p = Piloto.new(); _p.caminho = _c.dados.caminho; _p.obstaculos = _c._obst; _p.configurar(42, 0.0, 0.0)
	_c.piloto_de_teste = _auto
	var g3: Dictionary = _c.dados.portoes[10]
	print("portao3 ", g3.nome, " p=", g3.p, " caminho=", g3.caminho)
	for k in range(int(g3.caminho) - 2, int(g3.caminho) + 8):
		print("  wp ", k, " ", _c.dados.caminho[k])
	for i in 60 * 100:
		await physics_frame
		var t: float = _c.tempo
		if t > 84.0 and t < 92.0 and i % 6 == 0:
			var siri: CharacterBody3D = _m.pet
			var pe: Vector3 = siri.global_position - _c._origem
			var col := siri.get_last_slide_collision()
			var quem := "-"
			if col != null:
				var o: Object = col.get_collider()
				quem = "%s n=%s" % [(o as Node).get_path() if o is Node else str(o), str(col.get_normal()).substr(0, 30)]
			print("t=%.2f pe=(%.2f,%.2f,%.1f) chao=%s parede=%s v=(%.1f,%.1f,%.1f) wp=%d dir=%s ativa=%s fator=%s atord=%s col=%s" % [t, pe.x, pe.y, pe.z, siri.is_on_floor(), siri.is_on_wall(), siri.velocity.x, siri.velocity.y, siri.velocity.z, _p.indice, str(_ultimo.get("dir")), _m.ativa(), str(siri.get_meta("locomocao_fator", "?")), str(siri.get_meta("locomocao_atordoado", "?")), quem])
	quit()
func _auto(delta: float) -> Dictionary:
	var siri: CharacterBody3D = _m.pet
	_ultimo = _p.comando(siri.global_position - _c._origem, siri.velocity, siri.is_on_floor(), delta)
	return _ultimo
