extends SceneTree
# AUDITORIA dos clipes assados (.res/.tres) de res://assets/animations/.
# Mede, por clipe: tipo das faixas, papeis cobertos, nº de chaves, fps efetivo,
# modo de interpolação, loop, fechamento do ciclo (1ª vs última chave) e o maior
# salto entre chaves vizinhas. Só LÊ — não grava nada.
const DIR := "res://assets/animations/"
const ROLES := ["Torso","Neck","Head","UpperArm_L","ForeArm_L","UpperArm_R","ForeArm_R",
	"Thigh_L","Shin_L","Foot_L","Thigh_R","Shin_R","Foot_R"]

func _init() -> void:
	var d := DirAccess.open(DIR)
	var nomes := []
	for f in d.get_files():
		if f.ends_with(".res") or f.ends_with(".tres"):
			nomes.append(f)
	nomes.sort()
	print("clipe;dur_s;faixas;hierarquicas;papeis;chaves;fps;loop;fecha_ciclo_deg;salto_max_deg;papel_do_salto")
	for f in nomes:
		var a: Animation = load(DIR + f)
		if a == null:
			print(f, ";ERRO")
			continue
		var tipos := {}
		var papeis := {}
		var chaves := 0
		var interp := {}
		var fecha := 0.0
		var salto := 0.0
		var salto_papel := ""
		for i in a.get_track_count():
			var tt := a.track_get_type(i)
			tipos[tt] = true
			var path := String(a.track_get_path(i))
			var role := RigContrato.papel_de(path)
			papeis[role] = true
			var n := a.track_get_key_count(i)
			chaves += n
			if tt == Animation.TYPE_VALUE:
				interp[a.value_track_get_update_mode(i)] = true
			interp[a.track_get_interpolation_type(i)] = true
			if n >= 2:
				var v0 = a.track_get_key_value(i, 0)
				var vn = a.track_get_key_value(i, n - 1)
				if v0 is Vector3 and vn is Vector3:
					var db := Basis.from_euler(v0).inverse() * Basis.from_euler(vn)
					fecha = maxf(fecha, rad_to_deg(db.get_rotation_quaternion().get_angle()))
				for k in range(1, n):
					var pa = a.track_get_key_value(i, k - 1)
					var pb = a.track_get_key_value(i, k)
					if pa is Vector3 and pb is Vector3:
						var dd := Basis.from_euler(pa).inverse() * Basis.from_euler(pb)
						var g := rad_to_deg(dd.get_rotation_quaternion().get_angle())
						if g > salto:
							salto = g
							salto_papel = role
		var resolve := 0
		for i in a.get_track_count():
			resolve += 1 if String(a.track_get_path(i)).contains("/") else 0
		var faltando := []
		for r in ROLES:
			if not papeis.has(r):
				faltando.append(r)
		var fps := 0.0
		if a.length > 0.0 and a.get_track_count() > 0:
			fps = float(a.track_get_key_count(0) - 1) / a.length
		print("%s;%.3f;%d;%d/%d;%d(falta:%s);%d;%.1f;%d;%.2f;%.2f;%s" % [
			f, a.length, a.get_track_count(), resolve, a.get_track_count(),
			papeis.size(), ",".join(faltando), chaves, fps,
			a.loop_mode, fecha, salto, salto_papel])
	quit()
