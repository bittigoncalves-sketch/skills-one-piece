extends SceneTree
# Mede amplitude de movimento (max-min por eixo, somada, em graus) nas faixas
# "<Papel>:rotation" de um .res assado. Criterio objetivo p/ detectar clipe com
# membros congelados — contar faixas/chaves NAO serve (clipe congelado tem as
# mesmas 12 faixas e 57 chaves de um clipe bom).
#   godot --headless --path . --script tools/dev_tests/medir_amplitude_res.gd

const PAPEIS := ["UpperArm_R", "ForeArm_R", "UpperArm_L", "ForeArm_L",
	"Thigh_R", "Shin_R", "Thigh_L", "Shin_L", "Torso"]

func _init() -> void:
	var alvos := []
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		var d := DirAccess.open("res://assets/animations/")
		for f in d.get_files():
			if f.ends_with(".res"):
				alvos.append(f.get_basename())
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
	var linha := "%-26s dur=%.2fs " % [nome, anim.length]
	var soma_membros := 0.0
	for papel in PAPEIS:
		var ti := RigContrato.acha_faixa(anim, papel)
		if ti < 0:
			linha += "%s=SEM_FAIXA " % papel
			continue
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		var n := 60
		for i in range(n + 1):
			var t: float = anim.length * float(i) / float(n)
			var v = anim.value_track_interpolate(ti, t)
			if not (v is Vector3):
				continue
			lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
			hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
		var amp := rad_to_deg((hi.x - lo.x) + (hi.y - lo.y) + (hi.z - lo.z))
		linha += "%s=%.0f " % [papel, amp]
		if papel != "Torso":
			soma_membros += amp
	print(linha, " | SOMA_MEMBROS=%.0f" % soma_membros, "   <<< CONGELADO" if soma_membros < 10.0 else "")
