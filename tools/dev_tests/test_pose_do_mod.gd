extends SceneTree
# Conversão dos clipes do jogador do mod para os papéis do rig (src/anim/pose_do_mod.gd).
#   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_pose_do_mod.gd
# Mede a DIREÇÃO que o osso aponta (braço pendurado = −Y; frente = −Z; direita do personagem = +X), não o número do ângulo.
const PoseDoMod = preload("res://src/anim/pose_do_mod.gd")
var total := 0
var falhas := 0

func _init() -> void:
	rodar()
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)

func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)

func aponta(e: Vector3) -> Vector3:
	return Basis.from_euler(e) * Vector3.DOWN          # osso pendurado, depois do giro

func rodar() -> void:
	ok(PoseDoMod.nomes().size() == 93, "93 clipes carregados (%d)" % PoseDoMod.nomes().size())
	var f := PoseDoMod.amostrar("both_arm_front", 0.0)
	var r := aponta(f.UpperArm_R)
	var l := aponta(f.UpperArm_L)
	ok(r.dot(Vector3.FORWARD) > 0.8 and l.dot(Vector3.FORWARD) > 0.8, "both_arm_front: os dois braços apontam para a FRENTE (%.2f, %.2f)" % [r.dot(Vector3.FORWARD), l.dot(Vector3.FORWARD)])
	ok(r.x < 0.0 and l.x > 0.0, "both_arm_front: os braços CONVERGEM (direito x=%.2f, esquerdo x=%.2f)" % [r.x, l.x])
	var cima := PoseDoMod.amostrar("both_arm_up", 0.0)
	ok(aponta(cima.UpperArm_R).y > 0.5 and aponta(cima.UpperArm_L).y > 0.5, "both_arm_up: os braços sobem")
	var d := PoseDoMod.amostrar("right_arm_front", 0.0)
	ok(aponta(d.UpperArm_R).dot(Vector3.FORWARD) > 0.8 and not d.has("UpperArm_L"), "right_arm_front: só o braço direito, para a frente")
	var chute := PoseDoMod.amostrar("kick_right", 0.0)
	ok(chute.has("Thigh_R"), "kick_right: tem a coxa direita")
	ok(PoseDoMod.amostrar("nao_existe", 0.0).is_empty(), "clipe desconhecido → vazio")
	# interpolação: backstep vai de 0 a algo em 0,1667 s
	var b0 := PoseDoMod.amostrar("backstep", 0.0)
	var b1 := PoseDoMod.amostrar("backstep", 0.1667)
	var bm := PoseDoMod.amostrar("backstep", 0.0833)
	ok(b0.UpperArm_R.length() < 0.001 and b1.UpperArm_R.length() > 0.5, "backstep: do repouso (%.3f) a uma pose (%.2f)" % [b0.UpperArm_R.length(), b1.UpperArm_R.length()])
	ok(bm.UpperArm_R.length() > b0.UpperArm_R.length() and bm.UpperArm_R.length() < b1.UpperArm_R.length(), "backstep: no meio da chave a pose está entre as duas")
	# hierarquia: a coxa NÃO acompanha o giro de torso (y de -12,5° no backstep): coxa = torso⁻¹ · perna
	ok(b1.has("Torso") and b1.has("Thigh_R"), "backstep: Torso e Thigh_R existem")
	var rec := Basis.from_euler(b1.Torso) * Basis.from_euler(b1.Thigh_R)
	var esperado := PoseDoMod._basis(Vector3(0, 0, 0))   # corpo do mod em pé no x=15 do body… compara o mundo da perna
	var body := PoseDoMod._basis(Vector3(15, 0, 0))
	var perna := PoseDoMod._basis(Vector3(-40.61108, 0, 0))
	ok((rec.get_euler() - (body * perna).get_euler()).length() < 0.001, "backstep: mundo da perna no rig = mundo da perna no mod (body·perna)")
	# posição: a morte do mod desce o corpo 14,1 px e o leva 14 px para TRÁS (+Z, frente é −Z) (body 14 + torso −4 = 10 px) enquanto gira para trás
	var morte := PoseDoMod.amostrar_posicoes("death", 0.5)
	var px := PoseDoMod.METROS_POR_PX
	ok(absf(morte.Torso.y + 14.1 * px) < 0.01 and absf(morte.Torso.z - 10.0 * px) < 0.01, "death: Torso desce %.2f m e vai %.2f m para trás" % [-morte.Torso.y, morte.Torso.z])
	ok(PoseDoMod.amostrar_posicoes("both_arm_front", 0.0).is_empty(), "clipe sem posição → vazio")
	ok(not PoseDoMod.segura("backstep") and PoseDoMod.duracao("backstep") > 0.3, "duração e 'segurar' lidos")
