extends SceneTree
# Mede o INSTANTE DO IMPACTO de um clipe: o momento em que o membro que golpeia
# alcança o ponto mais à FRENTE. É o número que o `src/combat/Melee.gd` usa para
# calibrar o `atraso` da hitbox (a hitbox tem que nascer no frame do impacto, não
# no do clique) — então ele precisa ser medido de novo sempre que um `.res` for
# reassado.
#
# Como: cinemática direta com segmentos de comprimento 1 (as faixas do `.res`
# guardam só rotação, então só o ÂNGULO importa; o tamanho real do membro escala
# a curva inteira e não move o instante do máximo). A pose de repouso de todo
# membro é para BAIXO (0,-1,0) e a frente do rig é −Z (o baker aplica o yflip).
#   posição do efetor = Σ (delta acumulado do papel) * (0,-1,0)
#   alcance frontal   = −Z dessa posição       <- o que vira o instante do golpe
#
# Compara com a cópia de referência em `user://ref_anim/` quando ela existir
# (mesma convenção do medir_pose_res.gd).
#
#   godot --headless --path . --script tools/dev_tests/medir_impacto_res.gd -- kicking punching

const REF_DIR := "user://ref_anim/"
const PASSO := 1.0 / 240.0

# nome -> cadeia de papéis, da raiz até o efetor.
const CADEIAS := {
	"perna_R": ["Torso", "Thigh_R", "Shin_R", "Foot_R"],
	"perna_L": ["Torso", "Thigh_L", "Shin_L", "Foot_L"],
	"braco_R": ["Torso", "UpperArm_R", "ForeArm_R"],
	"braco_L": ["Torso", "UpperArm_L", "ForeArm_L"],
}

func _init() -> void:
	var alvos := PackedStringArray(OS.get_cmdline_user_args())
	if alvos.is_empty():
		alvos = PackedStringArray(["kicking", "punching"])
	for nome in alvos:
		var anim: Animation = load("res://assets/animations/%s.res" % nome)
		if anim == null:
			print("✗ nao carregou: ", nome)
			continue
		var ref: Animation = null
		if FileAccess.file_exists(REF_DIR + nome + ".res"):
			ref = load(REF_DIR + nome + ".res")
		print("%s  dur=%.4fs%s" % [nome, anim.length,
			("" if ref == null else "   (ref dur=%.4fs)" % ref.length)])
		for c in CADEIAS:
			var a := _impacto(anim, CADEIAS[c])
			var s := "    %-8s impacto t=%.4fs  alcance=%.3f" % [c, a.x, a.y]
			if ref != null:
				var b := _impacto(ref, CADEIAS[c])
				s += "   | ref t=%.4fs (Δ%+.4fs) alcance=%.3f (Δ%+.3f)" % [b.x, a.x - b.x, b.y, a.y - b.y]
			print(s)
	quit()

# Retorna Vector2(instante do alcance frontal máximo, alcance).
func _impacto(a: Animation, cadeia: Array) -> Vector2:
	var tis := []
	for papel in cadeia:
		tis.append(RigContrato.acha_faixa(a, String(papel)))
	var melhor_t := 0.0
	var melhor := -INF
	var passos := int(a.length / PASSO) + 1
	for i in range(passos + 1):
		var t: float = minf(float(i) * PASSO, a.length)
		var acc := Basis()
		var p := Vector3.ZERO
		for j in range(cadeia.size()):
			if tis[j] < 0:
				continue
			var v = a.value_track_interpolate(tis[j], t)
			if not (v is Vector3):
				continue
			acc = acc * Basis.from_euler(v)
			if j > 0:   # o Torso só orienta a cadeia, não é segmento
				p += acc * Vector3(0, -1, 0)
		var frente := -p.z
		if frente > melhor:
			melhor = frente
			melhor_t = t
	return Vector2(melhor_t, melhor)
