extends SceneTree
# Quantas chaves sobram se a curva for DECIMADA com tolerância angular? Mede o
# quanto os clipes de 60 fps podem virar curvas editáveis à mão sem mudar a pose.
const DIR := "res://assets/animations/"
const TOLS := [0.5, 1.0, 2.0]   # graus

func _init() -> void:
	var d := DirAccess.open(DIR)
	var nomes := []
	for f in d.get_files():
		if f.ends_with(".res"): nomes.append(f)
	nomes.sort()
	var tot_orig := 0
	var tot := {}
	for t in TOLS: tot[t] = 0
	print("clipe;chaves;" + ";".join(TOLS.map(func(x): return "tol_%.1f" % x))) 
	for f in nomes:
		var a: Animation = load(DIR + f)
		var orig := 0
		var red := {}
		for t in TOLS: red[t] = 0
		for i in a.get_track_count():
			var n := a.track_get_key_count(i)
			orig += n
			var vals := []
			var tempos := []
			for k in n:
				vals.append(a.track_get_key_value(i, k))
				tempos.append(a.track_get_key_time(i, k))
			for t in TOLS:
				red[t] += _decima(vals, tempos, deg_to_rad(float(t)))
		tot_orig += orig
		for t in TOLS: tot[t] += red[t]
		print("%s;%d;%s" % [f, orig, ";".join(TOLS.map(func(x): return str(red[x])))])
	print("\nTOTAL;%d;%s" % [tot_orig, ";".join(TOLS.map(func(x): return "%d (%.0f%%)" % [tot[x], 100.0*tot[x]/tot_orig]))])
	quit()

# Douglas-Peucker "guloso": mantém a chave sempre que a reta entre as duas
# vizinhas mantidas erra mais que a tolerância na pose intermediária.
func _decima(vals: Array, tempos: Array, tol: float) -> int:
	var n := vals.size()
	if n <= 2: return n
	var mantidas := 1
	var i0 := 0
	var i := 1
	while i < n:
		var erro := 0.0
		for j in range(i0 + 1, i + 1):
			var u: float = float(j - i0) / float(i - i0 + 0.0001)
			var lin: Vector3 = (vals[i0] as Vector3).lerp(vals[i], u)
			var db: Basis = Basis.from_euler(lin).inverse() * Basis.from_euler(vals[j])
			erro = maxf(erro, db.get_rotation_quaternion().get_angle())
		if erro > tol:
			mantidas += 1
			i0 = i - 1
			i = i0 + 1
		i += 1
	return mantidas + 1
