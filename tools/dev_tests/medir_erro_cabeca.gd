extends SceneTree
# O rig DECLARA Head como filho de Torso (BodyScanner/RIG_PARENT/bake MAP), mas
# no base.scn/buggy.scn o pai REAL é Neck. Como as duas faixas são deltas
# relativos ao Torso, a do Neck entra DUAS VEZES na cabeça. Isto mede o erro.
const DIR := "res://assets/animations/"
func _init() -> void:
	var pior_global := 0.0
	var pior_clipe := ""
	var linhas := []
	var d := DirAccess.open(DIR)
	var nomes := []
	for f in d.get_files():
		if f.ends_with(".res"): nomes.append(f)
	nomes.sort()
	for f in nomes:
		var a: Animation = load(DIR + f)
		var ti_neck := -1
		var ti_head := -1
		for i in a.get_track_count():
			var r := String(a.track_get_path(i)).get_slice(":", 0)
			if r == "Neck": ti_neck = i
			elif r == "Head": ti_head = i
		if ti_neck < 0 or ti_head < 0: continue
		var pior := 0.0
		var n := a.track_get_key_count(ti_neck)
		for k in n:
			var e = a.track_get_key_value(ti_neck, k)
			if e is Vector3:
				var g := rad_to_deg(Basis.from_euler(e).get_rotation_quaternion().get_angle())
				pior = maxf(pior, g)
		linhas.append("%-34s erro máx. da cabeça: %6.2f°" % [f, pior])
		if pior > pior_global:
			pior_global = pior; pior_clipe = f
	for l in linhas: print(l)
	print("\nPIOR: %s com %.2f° de rotação parasita na cabeça" % [pior_clipe, pior_global])
	quit()
