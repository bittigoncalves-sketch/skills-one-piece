extends SceneTree
# Despeja as animações assadas (.res, formato BINÁRIO do Godot) em JSON, para o
# editor em Python poder ABRIR e editar um clipe existente em vez de começar
# sempre do zero. Python não lê .res; lê JSON.
#
# Uso: godot --headless --path . -s tools/export_anims.gd

const ORIGEM := "res://assets/animations/"
const SAIDA := "res://tools/anim_editor/clips/"

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var dir := DirAccess.open(ORIGEM)
	if dir == null:
		print("✗ pasta ausente: ", ORIGEM)
		quit(1)
		return
	var indice: Array = []
	for arq in dir.get_files():
		var baixo := arq.to_lower()
		if not (baixo.ends_with(".res") or baixo.ends_with(".tres")):
			continue
		var a = load(ORIGEM + arq)
		if not (a is Animation):
			continue
		var anim: Animation = a
		var faixas := {}
		for i in anim.get_track_count():
			var caminho := String(anim.track_get_path(i))
			var papel := caminho.get_slice(":", 0)
			var prop := caminho.get_slice(":", 1)
			if prop != "rotation":
				continue
			var chaves: Array = []
			for k in anim.track_get_key_count(i):
				var t: float = anim.track_get_key_time(i, k)
				var v = anim.track_get_key_value(i, k)
				if v is Vector3:
					chaves.append([snappedf(t, 0.0001),
						[snappedf(v.x, 0.00001), snappedf(v.y, 0.00001), snappedf(v.z, 0.00001)]])
			if not chaves.is_empty():
				faixas[papel] = chaves
		if faixas.is_empty():
			continue
		var nome := arq.get_basename()
		var dados := {
			"name": nome,
			"length": snappedf(anim.length, 0.0001),
			"loop": anim.loop_mode != Animation.LOOP_NONE,
			"tracks": faixas,
		}
		var f := FileAccess.open(SAIDA + nome + ".json", FileAccess.WRITE)
		f.store_string(JSON.stringify(dados))
		f.close()
		indice.append({"name": nome, "length": dados["length"], "tracks": faixas.size()})
		print("  ✓ ", nome, "  %.2fs  %d faixas" % [anim.length, faixas.size()])

	var fi := FileAccess.open(SAIDA + "index.json", FileAccess.WRITE)
	fi.store_string(JSON.stringify({"clips": indice}, "  "))
	fi.close()
	print("CLIPES EXPORTADOS: ", indice.size())
	quit()
