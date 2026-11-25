extends SceneTree
# Teste dos clipes de locomoção/parkour no CONTRATO v2 (docs/PARKOUR_MIRRORS_EDGE_PLANO.md,
# "Contrato dos clipes"): para cada clipe novo carrega o .res assado pelo
# tools/bake_mixamo.gd e confere, contra medidas INDEPENDENTES do pipeline:
#
#   1. faixas: 13 <Papel>:rotation (Vector3) + Corpo:altura (float) + Corpo:giro
#      (float) + Corpo:deslocamento (Vector3), todas com as mesmas chaves;
#   2. metadados altura_quadril_m (≈ repouso do X Bot no Blender), origem (arquivo
#      que existe) e espelhado;
#   3. duração a ±1 quadro (1/30 s) da medida;
#   4. AMPLITUDE de rotação de cada papel > 0 — maior giro geodésico em relação à
#      1ª chave. Contar faixas/chaves dá "ok" em clipe congelado; isto não;
#   5. SALTO entre chaves vizinhas: o jogo interpola o euler LINEARMENTE, então o
#      que conta é a rotação que essa interpolação PERCORRE (< 30°) e quanto ela
#      passa do giro real entre as duas poses (gimbal). A diferença bruta de euler
#      NÃO serve de critério: perto de x = ±90° uma rotação real de 7° pede 80°+ de
#      euler sem defeito nenhum (medido nos 30 clipes); ela só sai no log;
#   6. deslocamento final do quadril a 10 % do medido (piso de 2 cm p/ clipe parado);
#   7. altura do quadril (1º quadro, mínimo, máximo) a 3 cm do medido;
#   8. giro final a 3° do medido e sem salto (> 30° entre chaves);
#   9. giro RETIRADO do tronco: nos clipes que giram >= 45°, o giro do Torso em
#      volta da vertical varia bem menos que o giro do corpo;
#  10. espelhados: amplitude de cada _L do espelho = a do _R do original (e vice-
#      versa), pose = reflexão exata da pose do lado oposto, deslocamento x e giro
#      com sinal trocado, resto igual.
#
# De onde vêm as medidas (REF): duração e deslocamento do briefing de 02/10/2026
# (Blender, quadril mixamorig:Hips) quando ele mediu; o resto, do script
# independente que lê o FBX direto no Blender (fonte "blender"; ver
# docs/ANIMACOES_MIXAMO.md). Eixos do Blender: frente = −Y, esquerda = +X, cima = +Z.
# No jogo: (x, y, z)_blender -> (−x, z, y), ÷ altura do quadril em repouso.
#
#   godot --headless --path . --script tools/dev_tests/test_clipes_parkour.gd
#   godot --headless --path . --script tools/dev_tests/test_clipes_parkour.gd -- --dir=/abs/pasta/
#   (--dir testa uma CÓPIA — é assim que se prova que o teste reprova clipe sabotado)

const DIR_PADRAO := "res://assets/animations/"
const PAPEIS := ["Torso", "Neck", "Head", "UpperArm_L", "ForeArm_L", "UpperArm_R", "ForeArm_R",
	"Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R"]
const ALTURA_QUADRIL_REF := 1.0427   # m — repouso do quadril do X Bot, medido no Blender
const QUADRO := 1.0 / 30.0           # 1 quadro do Mixamo
const AMPL_MIN_DEG := 0.05           # abaixo disto o papel está congelado
const PERCURSO_MAX_DEG := 30.0
const EXCESSO_MAX_DEG := 8.0         # percurso − giro real, entre chaves vizinhas
const DESL_TOL_REL := 0.10
const DESL_PISO_M := 0.02
const ALTURA_TOL_M := 0.03
const GIRO_TOL_DEG := 3.0
const GIRO_PASSO_MAX_DEG := 30.0
const GIRO_TRONCO_MIN_DEG := 45.0    # clipes que giram ao menos isto entram no item 9
const GIRO_TRONCO_FRACAO := 0.5      # yaw do Torso tem que variar menos que isto × |giro|
# Vertical no espaço das faixas <Papel>:rotation = +Y, a do jogo. Até 07/10/2026 era
# +Z: o baker aplicava o yflip no espaço do esqueleto do GLB (girado 90° em X) e as
# faixas saíam num referencial girado, o que em jogo deitava o boneco nos golpes. O
# gatilho deixado aqui ("se o baker passar a gravar no referencial do jogo, isto vira
# Vector3.UP") disparou com a conversão v3: docs/ANIMACOES_MIXAMO.md e docs/erros.md.
const VERTICAL_DA_FAIXA := Vector3.UP

const REF := {
	"climbing_up_wall": {"dur": 2.03, "desl": Vector3(0, 0, 1.26), "fonte": "briefing/briefing", "z": Vector3(1.002, 1.002, 2.307), "giro": 0},
	"crouched_to_sprinting": {"dur": 0.53, "desl": Vector3(0.03, -1.44, 0.4), "fonte": "briefing/briefing", "z": Vector3(0.497, 0.497, 0.923), "giro": -12.9},
	"diagonal_wall_run": {"dur": 1.17, "desl": Vector3(-1.73, -1.71, 1.13), "fonte": "briefing/briefing", "z": Vector3(0.945, 0.945, 2.407), "giro": -104},
	"running_slide": {"dur": 1.57, "desl": Vector3(0, -6.7, 0), "fonte": "briefing/briefing", "z": Vector3(0.945, 0.249, 0.974), "giro": 0},
	"run_to_stop": {"dur": 0.93, "desl": Vector3(-0.01, -0.81, 0.02), "fonte": "briefing/briefing", "z": Vector3(0.945, 0.736, 0.981), "giro": -46.6},
	"sprint": {"dur": 0.57, "desl": Vector3(0, -3.29, 0), "fonte": "briefing/briefing", "z": Vector3(0.898, 0.891, 0.989), "giro": 0},
	"sprinting_forward_roll": {"dur": 1.2, "desl": Vector3(0.01, -5.8, 0.03), "fonte": "briefing/briefing", "z": Vector3(0.898, 0.128, 0.932), "giro": -4.9},
	"wall_run": {"dur": 0.97, "desl": Vector3(-1.86, -2.29, 0.53), "fonte": "briefing/briefing", "z": Vector3(0.945, 0.945, 1.957), "giro": -89.5},
	"idle": {"dur": 3.9, "desl": Vector3(-0.002, -0.001, 0), "fonte": "briefing/blender", "z": Vector3(0.969, 0.946, 0.978), "giro": 0.6},
	"falling_idle": {"dur": 0.73, "desl": Vector3(0, 0, 0), "fonte": "briefing/blender", "z": Vector3(0.941, 0.94, 0.941), "giro": 0},
	"idle_2": {"dur": 9.93, "desl": Vector3(0, 0, 0), "fonte": "briefing/blender", "z": Vector3(0.969, 0.969, 0.974), "giro": 0},
	"idle_3": {"dur": 3.27, "desl": Vector3(0, -0.001, 0.001), "fonte": "briefing/blender", "z": Vector3(0.969, 0.957, 1.014), "giro": 0},
	"running": {"dur": 0.73, "desl": Vector3(0, -3.32, 0), "fonte": "briefing/briefing", "z": Vector3(0.945, 0.926, 1.034), "giro": 0},
	"stand_to_cover": {"dur": 1.167, "desl": Vector3(-0.007, -1.178, -0.03), "fonte": "blender/blender", "z": Vector3(0.969, 0.814, 0.969), "giro": -110.8},
	"walking": {"dur": 1.07, "desl": Vector3(0, -1.85, 0), "fonte": "briefing/briefing", "z": Vector3(1.016, 0.949, 1.023), "giro": 0},
	"stand_to_cover_2": {"dur": 1.3, "desl": Vector3(-0.003, -1.209, -0.38), "fonte": "blender/blender", "z": Vector3(0.969, 0.571, 0.969), "giro": -133},
	"run_to_stop_2": {"dur": 0.9, "desl": Vector3(-0.01, -0.82, 0.03), "fonte": "briefing/briefing", "z": Vector3(0.945, 0.736, 0.976), "giro": -45.8},
	"left_turn": {"dur": 1.07, "desl": Vector3(0, 0, 0), "fonte": "briefing/briefing", "z": Vector3(0.969, 0.969, 0.989), "giro": 0.3},
	"right_turn": {"dur": 1.07, "desl": Vector3(0, 0, 0), "fonte": "briefing/briefing", "z": Vector3(0.969, 0.969, 0.986), "giro": 0},
	"jumping_up": {"dur": 0.27, "desl": Vector3(0.045, 0.071, -0.032), "fonte": "briefing/blender", "z": Vector3(0.969, 0.937, 0.969), "giro": 5.3},
	"falling_to_roll": {"dur": 1.5, "desl": Vector3(-0.05, -3.02, 0), "fonte": "briefing/briefing", "z": Vector3(0.94, 0.158, 0.979), "giro": -12.8},
	"hard_landing": {"dur": 2.03, "desl": Vector3(-0.018, -0.169, 0.028), "fonte": "briefing/blender", "z": Vector3(0.94, 0.473, 0.968), "giro": -13.3},
	"cover_to_stand": {"dur": 1.533, "desl": Vector3(0.004, 0.976, 0.379), "fonte": "blender/blender", "z": Vector3(0.59, 0.588, 0.969), "giro": 133},
	"idle_4": {"dur": 2.6, "desl": Vector3(0, 0, 0), "fonte": "briefing/blender", "z": Vector3(0.59, 0.589, 0.591), "giro": 0},
	"crouched_sneaking_left": {"dur": 1.3, "desl": Vector3(-1.343, 0, 0), "fonte": "blender/blender", "z": Vector3(0.764, 0.73, 0.771), "giro": 0},
	"crouched_sneaking_right": {"dur": 1.1, "desl": Vector3(1.207, -0.002, -0.003), "fonte": "blender/blender", "z": Vector3(0.729, 0.704, 0.738), "giro": 0.3},
	"left_cover_sneak": {"dur": 1.167, "desl": Vector3(-1.342, 0, 0), "fonte": "blender/blender", "z": Vector3(0.896, 0.895, 0.952), "giro": 0},
	"right_cover_sneak": {"dur": 1.167, "desl": Vector3(1.342, 0, 0), "fonte": "blender/blender", "z": Vector3(0.954, 0.894, 0.954), "giro": 0},
	"idle_5": {"dur": 2.3, "desl": Vector3(0, 0, 0), "fonte": "briefing/blender", "z": Vector3(0.939, 0.937, 0.939), "giro": 0},
	"cover_to_stand_2": {"dur": 1.167, "desl": Vector3(-0.02, 0.972, 0.017), "fonte": "blender/blender", "z": Vector3(0.939, 0.826, 0.955), "giro": 109.9},
}
const ESPELHOS := {"wall_run_espelhado": "wall_run", "diagonal_wall_run_espelhado": "diagonal_wall_run"}

var _dir := DIR_PADRAO
var _falhas := 0
var _linhas := []

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			_dir = a.trim_prefix("--dir=")
			if not _dir.ends_with("/"):
				_dir += "/"
	print("test_clipes_parkour — pasta: ", _dir)
	print("%-28s %6s %8s %20s %22s %8s %7s %7s" % ["clipe", "dur s", "ampl°", "desl norm (x,y,z)", "desl m (x,y,z)", "giro°", "perc°", "exc°"])
	var resumo := {}
	for nome in REF:
		resumo[nome] = _clipe(nome, REF[nome], false)
	for esp in ESPELHOS:
		var orig: String = ESPELHOS[esp]
		var r: Dictionary = REF[orig].duplicate()
		var d: Vector3 = r.desl
		r.desl = Vector3(-d.x, d.y, d.z)      # (eixos do Blender: x é o lateral)
		r.giro = -float(r.giro)
		resumo[esp] = _clipe(esp, r, true)
		_espelho(esp, orig)
	for l in _linhas:
		print(l)
	print("")
	if _falhas == 0:
		print("✅ test_clipes_parkour: %d clipes (%d + %d espelhados), 0 falhas" % [resumo.size(), REF.size(), ESPELHOS.size()])
	else:
		print("❌ test_clipes_parkour: %d falha(s) em %d clipes" % [_falhas, resumo.size()])
	quit(1 if _falhas > 0 else 0)

func _falha(nome: String, msg: String) -> void:
	_falhas += 1
	_linhas.append("  ✗ %s: %s" % [nome, msg])

# --------------------------------------------------------------- um clipe
func _clipe(nome: String, ref: Dictionary, espelhado: bool) -> Dictionary:
	var caminho := _dir + nome + ".res"
	var a := ResourceLoader.load(caminho, "", ResourceLoader.CACHE_MODE_IGNORE) as Animation
	if a == null:
		_falha(nome, "não carregou " + caminho)
		return {}
	# 1. faixas
	var ti := {}
	for papel in PAPEIS:
		ti[papel] = a.find_track(NodePath(papel + ":rotation"), Animation.TYPE_VALUE)
	ti["altura"] = a.find_track(NodePath("Corpo:altura"), Animation.TYPE_VALUE)
	ti["giro"] = a.find_track(NodePath("Corpo:giro"), Animation.TYPE_VALUE)
	ti["desl"] = a.find_track(NodePath("Corpo:deslocamento"), Animation.TYPE_VALUE)
	for k in ti:
		if ti[k] < 0:
			_falha(nome, "faixa ausente: " + str(k))
			return {}
	var n := a.track_get_key_count(ti["Torso"])
	for k in ti:
		if a.track_get_key_count(ti[k]) != n or n < 2:
			_falha(nome, "faixa %s com %d chaves (Torso tem %d)" % [k, a.track_get_key_count(ti[k]), n])
			return {}
		if absf(a.track_get_key_time(ti[k], n - 1) - a.track_get_key_time(ti["Torso"], n - 1)) > 1e-6:
			_falha(nome, "faixa %s com chaves em outros instantes" % k)
	if typeof(a.track_get_key_value(ti["altura"], 0)) != TYPE_FLOAT or typeof(a.track_get_key_value(ti["giro"], 0)) != TYPE_FLOAT:
		_falha(nome, "Corpo:altura/Corpo:giro não são float")
	if typeof(a.track_get_key_value(ti["desl"], 0)) != TYPE_VECTOR3:
		_falha(nome, "Corpo:deslocamento não é Vector3")
	# 2. metadados
	var h := float(a.get_meta("altura_quadril_m", -1.0))
	if absf(h - ALTURA_QUADRIL_REF) > 0.005:
		_falha(nome, "altura_quadril_m = %.4f (medida no Blender: %.4f)" % [h, ALTURA_QUADRIL_REF])
	var origem := String(a.get_meta("origem", ""))
	if origem == "" or not FileAccess.file_exists(origem.get_slice("#", 0)):
		_falha(nome, "metadado origem inválido: '%s'" % origem)
	if not a.has_meta("espelhado") or bool(a.get_meta("espelhado")) != espelhado:
		_falha(nome, "metadado espelhado = %s (esperado %s)" % [str(a.get_meta("espelhado", "ausente")), espelhado])
	# 3. duração
	if absf(a.length - float(ref.dur)) > QUADRO + 0.001:
		_falha(nome, "duração %.3f s, medida %.3f s (tolerância 1 quadro)" % [a.length, ref.dur])
	# 4. amplitude e 5. salto, por papel
	var ampl_max := 0.0
	var perc_max := 0.0
	var exc_max := 0.0
	var euler_bruto := 0.0
	var pior_perc := ""
	var ampl_min := INF
	for papel in PAPEIS:
		var t: int = ti[papel]
		var q0 := Basis.from_euler(a.track_get_key_value(t, 0)).get_rotation_quaternion()
		var ampl := 0.0
		for k in n:
			var e: Vector3 = a.track_get_key_value(t, k)
			ampl = maxf(ampl, _ang(q0, Basis.from_euler(e).get_rotation_quaternion()))
			if k > 0:
				var e0: Vector3 = a.track_get_key_value(t, k - 1)
				var real := _giro_real(e0, e)
				var perc := _percurso(e0, e)
				var dd := e - e0
				euler_bruto = maxf(euler_bruto, maxf(absf(dd.x), maxf(absf(dd.y), absf(dd.z))))
				if perc > perc_max:
					perc_max = perc
					pior_perc = "%s @%.3fs" % [papel, a.track_get_key_time(t, k)]
				exc_max = maxf(exc_max, perc - real)
		if rad_to_deg(ampl) <= AMPL_MIN_DEG:
			_falha(nome, "papel %s CONGELADO (amplitude %.3f°)" % [papel, rad_to_deg(ampl)])
		ampl_max = maxf(ampl_max, ampl)
		ampl_min = minf(ampl_min, ampl)
	if rad_to_deg(perc_max) >= PERCURSO_MAX_DEG:
		_falha(nome, "salto: a interpolação percorre %.1f° entre duas chaves (%s)" % [rad_to_deg(perc_max), pior_perc])
	if rad_to_deg(exc_max) >= EXCESSO_MAX_DEG:
		_falha(nome, "gimbal: a interpolação passa %.1f° do giro real entre duas chaves" % rad_to_deg(exc_max))
	# 6. deslocamento final
	var b: Vector3 = ref.desl
	var esperado_m := Vector3(-b.x, b.z, b.y)
	var desl: Vector3 = a.track_get_key_value(ti["desl"], n - 1)
	var desl_m := desl * ALTURA_QUADRIL_REF
	var d0: Vector3 = a.track_get_key_value(ti["desl"], 0)
	if d0.length() > 1e-6:
		_falha(nome, "deslocamento não começa em zero: %s" % str(d0))
	var tol := maxf(DESL_TOL_REL * esperado_m.length(), DESL_PISO_M)
	if desl_m.distance_to(esperado_m) > tol:
		_falha(nome, "deslocamento final %s m, medido %s m (erro %.3f m > %.3f m)" % [_v(desl_m), _v(esperado_m), desl_m.distance_to(esperado_m), tol])
	# 7. altura
	var z: Vector3 = ref.z
	var alt := []
	for k in n:
		alt.append((1.0 + float(a.track_get_key_value(ti["altura"], k))) * ALTURA_QUADRIL_REF)
	for par in [["1º quadro", alt[0], z.x], ["mínima", alt.min(), z.y], ["máxima", alt.max(), z.z]]:
		if absf(float(par[1]) - float(par[2])) > ALTURA_TOL_M:
			_falha(nome, "altura do quadril %s %.3f m, medida %.3f m" % [par[0], par[1], par[2]])
	# 8. giro
	var giro_f := rad_to_deg(float(a.track_get_key_value(ti["giro"], n - 1)))
	if absf(giro_f - float(ref.giro)) > GIRO_TOL_DEG:
		_falha(nome, "giro final %.1f°, medido %.1f°" % [giro_f, ref.giro])
	var passo := 0.0
	for k in range(1, n):
		passo = maxf(passo, absf(float(a.track_get_key_value(ti["giro"], k)) - float(a.track_get_key_value(ti["giro"], k - 1))))
	if rad_to_deg(passo) > GIRO_PASSO_MAX_DEG:
		_falha(nome, "Corpo:giro salta %.1f° entre duas chaves" % rad_to_deg(passo))
	# 9. giro fora do tronco
	var yaw_torso := _amplitude_yaw(a, ti["Torso"])
	if absf(float(ref.giro)) >= GIRO_TRONCO_MIN_DEG:
		var teto := GIRO_TRONCO_FRACAO * absf(float(ref.giro))
		if yaw_torso >= teto:
			_falha(nome, "o Torso ainda carrega o giro: yaw do Torso varia %.1f° (teto %.1f° = %.0f %% de |giro| %.1f°)" % [yaw_torso, teto, GIRO_TRONCO_FRACAO * 100.0, absf(float(ref.giro))])
	print("%-28s %6.3f %8.1f %20s %22s %8.1f %7.1f %7.1f   menor ampl %.2f°, yaw Torso %.1f°, euler bruto %.1f°, %d chaves" % [nome, a.length, rad_to_deg(ampl_max),
		_v(desl), _v(desl_m), giro_f, rad_to_deg(perc_max), rad_to_deg(exc_max), rad_to_deg(ampl_min), yaw_torso, rad_to_deg(euler_bruto), n])
	return {"anim": a}

# --------------------------------------------------------------- espelho
func _espelho(esp: String, orig: String) -> void:
	var e := ResourceLoader.load(_dir + esp + ".res", "", ResourceLoader.CACHE_MODE_IGNORE) as Animation
	var o := ResourceLoader.load(_dir + orig + ".res", "", ResourceLoader.CACHE_MODE_IGNORE) as Animation
	if e == null or o == null:
		_falha(esp, "espelho ou original não carregou")
		return
	var M := Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1))
	var pior_amp := 0.0
	var pior_pose := 0.0
	for papel in PAPEIS:
		var lado: String = papel
		if papel.ends_with("_L"):
			lado = papel.left(-2) + "_R"
		elif papel.ends_with("_R"):
			lado = papel.left(-2) + "_L"
		var te := e.find_track(NodePath(papel + ":rotation"), Animation.TYPE_VALUE)
		var to := o.find_track(NodePath(lado + ":rotation"), Animation.TYPE_VALUE)
		if te < 0 or to < 0 or e.track_get_key_count(te) != o.track_get_key_count(to):
			_falha(esp, "faixa %s do espelho não casa com %s do original" % [papel, lado])
			continue
		var amp_e := _amplitude(e, te)
		var amp_o := _amplitude(o, to)
		pior_amp = maxf(pior_amp, absf(amp_e - amp_o))
		for k in e.track_get_key_count(te):
			var re := Basis.from_euler(e.track_get_key_value(te, k))
			var ro := M * Basis.from_euler(o.track_get_key_value(to, k)) * M
			pior_pose = maxf(pior_pose, rad_to_deg(_ang(re.get_rotation_quaternion(), ro.get_rotation_quaternion())))
	if pior_amp > 0.01:
		_falha(esp, "amplitude de papel do espelho difere da do lado oposto do original em %.3f°" % pior_amp)
	if pior_pose > 0.01:
		_falha(esp, "pose do espelho não é a reflexão da pose do lado oposto (erro %.3f°)" % pior_pose)
	var ed := e.find_track(NodePath("Corpo:deslocamento"), Animation.TYPE_VALUE)
	var od := o.find_track(NodePath("Corpo:deslocamento"), Animation.TYPE_VALUE)
	var eg := e.find_track(NodePath("Corpo:giro"), Animation.TYPE_VALUE)
	var og := o.find_track(NodePath("Corpo:giro"), Animation.TYPE_VALUE)
	var ea := e.find_track(NodePath("Corpo:altura"), Animation.TYPE_VALUE)
	var oa := o.find_track(NodePath("Corpo:altura"), Animation.TYPE_VALUE)
	var erro_corpo := 0.0
	for k in e.track_get_key_count(ed):
		var de: Vector3 = e.track_get_key_value(ed, k)
		var do_: Vector3 = o.track_get_key_value(od, k)
		erro_corpo = maxf(erro_corpo, de.distance_to(Vector3(-do_.x, do_.y, do_.z)))
		erro_corpo = maxf(erro_corpo, absf(float(e.track_get_key_value(eg, k)) + float(o.track_get_key_value(og, k))))
		erro_corpo = maxf(erro_corpo, absf(float(e.track_get_key_value(ea, k)) - float(o.track_get_key_value(oa, k))))
	var xe: float = (e.track_get_key_value(ed, e.track_get_key_count(ed) - 1) as Vector3).x
	var xo: float = (o.track_get_key_value(od, o.track_get_key_count(od) - 1) as Vector3).x
	if erro_corpo > 1e-5 or absf(xo) < 0.1 or signf(xe) == signf(xo):
		_falha(esp, "Corpo do espelho errado (erro %.6f; x final %.3f vs original %.3f — o sinal tem que trocar)" % [erro_corpo, xe, xo])
	print("  espelho %-28s amplitude _L/_R: maior diferença %.4f° | reflexão da pose: erro %.4f° | x final %.3f vs %.3f | giro final %.1f° vs %.1f°" % [esp, pior_amp, pior_pose, xe, xo,
		rad_to_deg(float(e.track_get_key_value(eg, e.track_get_key_count(eg) - 1))), rad_to_deg(float(o.track_get_key_value(og, o.track_get_key_count(og) - 1)))])

# --------------------------------------------------------------- medidas
# Maior giro (geodésico) de uma faixa em relação à 1ª chave, em graus.
func _amplitude(a: Animation, t: int) -> float:
	var q0 := Basis.from_euler(a.track_get_key_value(t, 0)).get_rotation_quaternion()
	var m := 0.0
	for k in a.track_get_key_count(t):
		m = maxf(m, _ang(q0, Basis.from_euler(a.track_get_key_value(t, k)).get_rotation_quaternion()))
	return rad_to_deg(m)

# Quanto o yaw (giro em volta de VERTICAL_DA_FAIXA, pela decomposição swing-twist)
# da faixa varia ao longo do clipe (máx − mín, contínuo), em graus.
func _amplitude_yaw(a: Animation, t: int) -> float:
	var ant := 0.0
	var lo := INF
	var hi := -INF
	for k in a.track_get_key_count(t):
		var q := Basis.from_euler(a.track_get_key_value(t, k)).get_rotation_quaternion()
		var y := 2.0 * atan2(Vector3(q.x, q.y, q.z).dot(VERTICAL_DA_FAIXA), q.w)
		if k > 0:
			y += TAU * roundf((ant - y) / TAU)
		ant = y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return rad_to_deg(hi - lo)

# Rotação percorrida pela interpolação LINEAR de euler de `a` até `b` (rad) — o
# caminho que o membro faz em jogo entre duas chaves.
func _percurso(a: Vector3, b: Vector3) -> float:
	var soma := 0.0
	var ant := a
	for s in range(1, 9):
		var m := a.lerp(b, s / 8.0)
		soma += _giro_real(ant, m)
		ant = m
	return soma

func _giro_real(a: Vector3, b: Vector3) -> float:
	return _ang(Basis.from_euler(a).get_rotation_quaternion(), Basis.from_euler(b).get_rotation_quaternion())

# Ângulo entre duas rotações (rad), por atan2. NÃO use Quaternion.angle_to aqui:
# é 2·acos(dot) e, em float32, duas poses IGUAIS dão dot = 1 − 1 ulp = 0,056° —
# acima do limiar de "congelado" e do erro aceito no espelho.
func _ang(qa: Quaternion, qb: Quaternion) -> float:
	var d := qa.inverse() * qb
	return 2.0 * atan2(Vector3(d.x, d.y, d.z).length(), absf(d.w))

func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
