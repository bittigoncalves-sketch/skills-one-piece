extends SceneTree
# Mede o MOVIMENTO REAL de cada papel num .res assado — em ROTAÇÃO, não na
# representação euler — e opcionalmente compara com uma cópia de referência.
#
# POR QUE ESTE TERCEIRO MEDIDOR EXISTE (2026-08-10, rebake dos 28 clipes):
# `medir_amplitude_res.gd` mede (max−min) por eixo do Vector3 euler. Isso é
# ótimo p/ achar clipe CONGELADO, mas NÃO serve p/ comparar antes/depois de um
# bake que conserta o desdobramento do euler: a chave que antes pulava de +179°
# p/ −179° inflava a amplitude em ~360° sem o membro ter se mexido. Ou seja, um
# clipe consertado APARECE como "perdeu amplitude" — quando na verdade só perdeu
# o giro parasita. Comparar amplitude euler antes/depois dá o veredito errado.
#
# Aqui as duas medidas são invariantes de representação (dois eulers que
# reconstroem a mesma Basis dão o mesmo número):
#   AMP  = maior ângulo geodésico entre a pose do papel e a pose de repouso.
#          "Quão longe o membro chega." Não muda com desdobramento.
#   PERC = comprimento total do caminho percorrido pelo papel ao longo do clipe,
#          amostrado a 240 Hz sobre a interpolação de VERDADE da faixa. Um giro
#          parasita de 360° entre duas chaves aparece aqui como +360°.
#   DIFF = (só com referência) maior diferença geodésica entre a pose nova e a
#          pose antiga, amostrada nos instantes das chaves ANTIGAS. É o teste
#          duro: se der ~0°, o rebake mudou só a representação, não o movimento.
#
# Uso:
#   godot --headless --path . --script tools/dev_tests/medir_pose_res.gd
#   godot --headless --path . --script tools/dev_tests/medir_pose_res.gd -- kicking
# Com referência: copie os .res antigos p/ o REF_DIR (caminho `user://`, fora do
# projeto) e rode igual — a comparação entra sozinha quando o arquivo existe.

const REF_DIR := "user://ref_anim/"
const REF_FPS := 30.0     # densidade de chaves dos .res antigos
const PASSO := 1.0 / 240.0

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
	var ref: Animation = null
	if FileAccess.file_exists(REF_DIR + nome + ".res"):
		ref = load(REF_DIR + nome + ".res")

	var papeis := []
	for ti in range(anim.get_track_count()):
		papeis.append(RigContrato.papel_de(anim.track_get_path(ti)))
	papeis.sort()

	var amp := {}
	var perc := {}
	var amp_ref := {}
	var perc_ref := {}
	var diff := {}
	for papel in papeis:
		amp[papel] = _amp(anim, papel)
		perc[papel] = _percurso(anim, papel)
		if ref != null:
			amp_ref[papel] = _amp(ref, papel)
			perc_ref[papel] = _percurso(ref, papel)
			diff[papel] = _diff(anim, ref, papel)

	var linha := "%-28s dur=%.4f" % [nome, anim.length]
	if ref != null:
		linha += " (ref %.4f, Δ%.4f)" % [ref.length, anim.length - ref.length]
	print(linha)
	for papel in papeis:
		var s := "    %-12s AMP=%7.1f°  PERC=%8.1f°" % [papel, rad_to_deg(amp[papel]), rad_to_deg(perc[papel])]
		if ref != null and amp_ref.has(papel) and amp_ref[papel] >= 0.0:
			s += "  | ref AMP=%7.1f° (Δ%+6.1f°)  ref PERC=%8.1f° (Δ%+8.1f°)  DIFF_max=%.3f°" % [
				rad_to_deg(amp_ref[papel]), rad_to_deg(amp[papel] - amp_ref[papel]),
				rad_to_deg(perc_ref[papel]), rad_to_deg(perc[papel] - perc_ref[papel]),
				rad_to_deg(diff[papel])]
		elif ref != null:
			s += "  | SEM_FAIXA_NA_REF"
		print(s)

func _ti(a: Animation, papel: String) -> int:
	# Aceita o caminho hierárquico atual e o formato antigo (um .res de
	# referência guardado antes do rebake ainda usa "<Papel>:rotation").
	return RigContrato.acha_faixa(a, papel)

# Maior ângulo geodésico entre a pose e o repouso (identidade).
func _amp(a: Animation, papel: String) -> float:
	var ti := _ti(a, papel)
	if ti < 0:
		return -1.0
	var m := 0.0
	var n := a.track_get_key_count(ti)
	for k in range(n):
		var v = a.track_get_key_value(ti, k)
		if v is Vector3:
			m = maxf(m, _ang(Basis.from_euler(v)))
	return m

# Comprimento do caminho percorrido, sobre a interpolação real da faixa.
func _percurso(a: Animation, papel: String) -> float:
	var ti := _ti(a, papel)
	if ti < 0:
		return -1.0
	var total := 0.0
	var ant: Basis = Basis()
	var passos := int(a.length / PASSO) + 1
	for i in range(passos + 1):
		var t: float = minf(float(i) * PASSO, a.length)
		var v = a.value_track_interpolate(ti, t)
		if not (v is Vector3):
			continue
		var b := Basis.from_euler(v)
		if i > 0:
			total += _ang(ant.inverse() * b)
		ant = b
	return total

# Maior diferença de POSE entre novo e referência, nos instantes das chaves da
# referência (que o bake novo, mais denso, também cobre).
func _diff(a: Animation, r: Animation, papel: String) -> float:
	var ta := _ti(a, papel)
	var tr := _ti(r, papel)
	if ta < 0 or tr < 0:
		return -1.0
	var m := 0.0
	for k in range(r.track_get_key_count(tr)):
		var t := r.track_get_key_time(tr, k)
		if t > a.length:
			continue
		var va = r.track_get_key_value(tr, k)
		var vb = a.value_track_interpolate(ta, t)
		if not (va is Vector3 and vb is Vector3):
			continue
		m = maxf(m, _ang(Basis.from_euler(va).inverse() * Basis.from_euler(vb)))
	return m

func _ang(b: Basis) -> float:
	var g: float = absf(b.get_rotation_quaternion().get_angle())
	if g > PI:
		g = TAU - g
	return g
