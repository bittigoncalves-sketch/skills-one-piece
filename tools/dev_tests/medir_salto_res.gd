extends SceneTree
# Mede o SALTO entre chaves vizinhas de um .res assado, por papel. Dois números,
# e a diferença entre eles é o diagnóstico:
#
#   EULER  = maior variação de UM eixo do Vector3 entre duas chaves. É o que a
#            interpolação LINEAR da faixa vai percorrer.
#   GIRO   = ângulo real da rotação entre as duas poses (geodésico).
#
#   EULER ≈ GIRO  -> o movimento é rápido mesmo; não há o que consertar na
#                    representação (só assar com mais fps, se incomodar).
#   EULER >> GIRO -> a faixa está mal condicionada (gimbal): o corpo mal se
#                    mexe e o euler dá um pulo. Aí a faixa euler não dá conta e
#                    o certo é faixa de quatérnion.
#
#   godot --headless --path . --script tools/dev_tests/medir_salto_res.gd
#   godot --headless --path . --script tools/dev_tests/medir_salto_res.gd -- punching

func _init() -> void:
	var alvos := []
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		var d := DirAccess.open("res://assets/animations/")
		for f in d.get_files():
			if f.ends_with(".res"):
				alvos.append(f.get_basename())
		alvos.sort()
	else:
		alvos = args
	for nome in alvos:
		_medir(nome)
	quit()

func _medir(nome: String) -> void:
	var anim: Animation = load("res://assets/animations/%s.res" % nome)
	if anim == null:
		print("✗ nao carregou: ", nome)
		return
	var pior_e := 0.0
	var pior_g := 0.0
	var pior_papel := "-"
	var pior_t := 0.0
	var chaves := 0
	var pior_perc := 0.0        # maior PERCURSO real percorrido entre duas chaves
	var pior_perc_papel := "-"
	var pior_perc_t := 0.0
	for ti in range(anim.get_track_count()):
		var papel := String(anim.track_get_path(ti)).get_slice(":", 0)
		var n := anim.track_get_key_count(ti)
		chaves += n
		for k in range(1, n):
			var a = anim.track_get_key_value(ti, k - 1)
			var b = anim.track_get_key_value(ti, k)
			if not (a is Vector3 and b is Vector3):
				continue
			var d: Vector3 = b - a
			var e := maxf(absf(d.x), maxf(absf(d.y), absf(d.z)))
			var g := _giro(a, b)
			if e > pior_e:
				pior_e = e
				pior_g = g
				pior_papel = papel
				pior_t = anim.track_get_key_time(ti, k)
			# PERCURSO: soma dos giros ao longo da interpolação LINEAR do euler,
			# amostrada fino. É o caminho que o membro faz de verdade em jogo.
			var passos := 16
			var perc := 0.0
			var ant: Vector3 = a
			for s in range(1, passos + 1):
				var m: Vector3 = a.lerp(b, float(s) / float(passos))
				perc += _giro(ant, m)
				ant = m
			if perc > pior_perc:
				pior_perc = perc
				pior_perc_papel = papel
				pior_perc_t = anim.track_get_key_time(ti, k)
	print("%-32s dur=%.2fs chaves=%d  EULER_max=%6.1f° (giro real %5.1f°, %s @%.2fs) | PERCURSO_max=%6.1f° (%s @%.2fs)%s"
		% [nome, anim.length, chaves, rad_to_deg(pior_e), rad_to_deg(pior_g), pior_papel, pior_t,
			rad_to_deg(pior_perc), pior_perc_papel, pior_perc_t,
			("   <<< PERCURSO ACIMA DE 30°" if rad_to_deg(pior_perc) > 30.0 else "")])

# Ângulo real (geodésico) entre duas poses dadas em euler.
func _giro(a: Vector3, b: Vector3) -> float:
	var g: float = absf((Basis.from_euler(a).inverse() * Basis.from_euler(b)).get_rotation_quaternion().get_angle())
	if g > PI:
		g = TAU - g
	return g
