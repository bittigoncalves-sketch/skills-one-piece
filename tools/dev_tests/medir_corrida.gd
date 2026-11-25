extends SceneTree
# ============================================================================
#  MEDIR CORRIDA — o instrumento do SPRINT (Shift), em espaço GLOBAL do modelo.
#
#  godot --headless --path . -s tools/dev_tests/medir_corrida.gd
#
#  Não reprova nada: mede. O `test_walk_run` já cobre o que a marcha não pode
#  quebrar (deslize, pé plantado, cadência, loop); o que ele NÃO vê é justamente
#  o que decide se a corrida tem vida:
#
#   1. OLHAR REAL — o teste mede `-Head.x - Torso.x` e ignora a COLUNA, que neste
#      rig fica entre os dois (Torso→SpineLower→SpineMid→Chest→Neck→NeckUpper→
#      Head). Com o peito inclinado, o olhar medido lá pode estar nivelado
#      enquanto o personagem corre encarando o chão. Aqui o pitch sai do
#      `global_basis` da cabeça, que é o que o olho vê.
#   2. BALANÇO — amplitude pico a pico de cada elo que participa da corrida,
#      em GRAUS, para "aumentar o balanço" ser um número e não uma impressão.
#   3. TORÇÃO — quadril contra linha de ombro, em yaw global. É o item que
#      separa corrida de tubo deslizando.
#   4. SILHUETA NARUTO — média do braço em espaço local, que é o critério que o
#      `test_walk_run` cobra (tem que ficar <= -0,70 rad).
# ============================================================================
const DT := 1.0 / 60.0
const VEL_RUN := Vector3(0, 0, -7.0)
# Elos que a corrida move. Ordem de leitura: do centro para a ponta.
const ELOS := ["Torso", "SpineLower", "SpineMid", "Chest", "Neck", "NeckUpper", "Head",
	"Clavicle_L", "Clavicle_R", "Scapula_L", "Scapula_R",
	"UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R",
	"Wrist_L", "Wrist_R", "Hand_L", "Hand_R", "Index2_R", "Thumb2_R",
	"Thigh_R", "Shin_R", "Foot_R", "Ball_R"]

func _init() -> void:
	await process_frame
	var c := await _montar("base")
	_rodar(c, 240)                      # estabiliza o filtro antes de medir
	var nodes: Dictionary = c.perfil.nodes
	var modelo: Node3D = c.modelo
	var raiz := modelo.find_child("CharacterRoot_base", true, false) as Node3D
	if raiz == null:
		raiz = modelo

	var mn := {}
	var mx := {}
	var soma := {}
	var n := 600
	for i in n:
		(c.anim as ProceduralAnimator).update(VEL_RUN, true, false, DT, 0.0, true)
		for r in ELOS:
			if not nodes.has(r):
				continue
			var rot: Vector3 = (nodes[r] as Node3D).rotation
			mn[r] = (mn[r] as Vector3).min(rot) if mn.has(r) else rot
			mx[r] = (mx[r] as Vector3).max(rot) if mx.has(r) else rot
			soma[r] = (soma.get(r, Vector3.ZERO) as Vector3) + rot
		# Pitch e yaw GLOBAIS (o que o olho vê), relativos ao corpo.
		for r in ["Chest", "Head", "Torso"]:
			if nodes.has(r):
				var g := _pitch_yaw(nodes[r] as Node3D, raiz)
				var k: String = "G_" + r
				mn[k] = (mn[k] as Vector3).min(g) if mn.has(k) else g
				mx[k] = (mx[k] as Vector3).max(g) if mx.has(k) else g
				soma[k] = (soma.get(k, Vector3.ZERO) as Vector3) + g

	print("\n########## 1. OLHAR E POSTURA — pitch GLOBAL (negativo = inclinado p/ frente)")
	for r in ["Torso", "Chest", "Head"]:
		var k: String = "G_" + r
		if not soma.has(k):
			continue
		var med: Vector3 = (soma[k] as Vector3) / float(n)
		print("  %-6s pitch %+6.1f°   yaw amp %5.1f°   (pitch varia %4.1f°)" % [r,
			rad_to_deg(med.x), rad_to_deg((mx[k] as Vector3).y - (mn[k] as Vector3).y),
			rad_to_deg((mx[k] as Vector3).x - (mn[k] as Vector3).x)])
	var olhar := rad_to_deg((((soma.get("G_Head", Vector3.ZERO)) as Vector3) / float(n)).x)
	print("  >>> OLHAR REAL: %+.1f°  (0 = horizonte; negativo = encarando o chão)" % olhar)

	print("\n########## 2. BALANÇO — amplitude pico a pico, espaço local")
	for r in ELOS:
		if not mn.has(r):
			continue
		var v: Vector3 = (mx[r] as Vector3) - (mn[r] as Vector3)
		if maxf(maxf(v.x, v.y), v.z) < deg_to_rad(0.25):
			print("  %-12s   PARADO" % r)
			continue
		print("  %-12s x %6.1f°  y %6.1f°  z %6.1f°" % [r,
			rad_to_deg(v.x), rad_to_deg(v.y), rad_to_deg(v.z)])

	print("\n########## 3. TORÇÃO — quadril contra linha de ombro (yaw global)")
	var q: Vector3 = (mx["G_Torso"] as Vector3) - (mn["G_Torso"] as Vector3)
	var o: Vector3 = (mx["G_Chest"] as Vector3) - (mn["G_Chest"] as Vector3)
	print("  quadril %.1f°  |  ombros %.1f°  |  razão %.2f (humano corre em torno de 1,0-1,6)"
		% [rad_to_deg(q.y), rad_to_deg(o.y), rad_to_deg(o.y) / maxf(rad_to_deg(q.y), 0.01)])

	# 5 varre TUDO, não só os elos escolhidos: é o item que responde "a corrida
	# usa mesmo as juntas novas?" sem depender de eu ter lembrado de listar cada
	# uma. Papel mudo aqui é papel que o modelo tem e a animação não move.
	print("\n########## 5. PAPÉIS MUDOS — juntas que o corpo tem e a corrida não usa")
	var mudos: Array[String] = []
	var vivos := 0
	for r in nodes:
		var mn2 := Vector3.ZERO
		var mx2 := Vector3.ZERO
		var primeiro := true
		for i in 120:
			(c.anim as ProceduralAnimator).update(VEL_RUN, true, false, DT, 0.0, true)
			var rot: Vector3 = (nodes[r] as Node3D).rotation
			if primeiro:
				mn2 = rot
				mx2 = rot
				primeiro = false
			else:
				mn2 = mn2.min(rot)
				mx2 = mx2.max(rot)
		var v2 := mx2 - mn2
		if maxf(maxf(v2.x, v2.y), v2.z) < deg_to_rad(0.25):
			mudos.append(r)
		else:
			vivos += 1
	print("  %d papéis com movimento, %d mudos" % [vivos, mudos.size()])
	if not mudos.is_empty():
		print("  mudos: " + ", ".join(mudos))

	print("\n########## 4. SILHUETA NARUTO — braço local (test_walk_run cobra <= -40,1°)")
	for r in ["UpperArm_L", "UpperArm_R"]:
		var med: Vector3 = (soma[r] as Vector3) / float(n)
		var rest: Vector3 = c.perfil.rest.get(r, Vector3.ZERO)
		print("  %-12s média %+6.1f° (rest %+.1f°)  ->  relativo %+6.1f°" % [r,
			rad_to_deg(med.x), rad_to_deg(rest.x), rad_to_deg(med.x - rest.x)])
	quit()

# Pitch/yaw de um nó em relação à raiz do personagem (não ao mundo: o modelo
# inteiro pode estar girado 180° para olhar -Z, e isso poluiria toda leitura).
func _pitch_yaw(n: Node3D, raiz: Node3D) -> Vector3:
	var b := raiz.global_basis.inverse() * n.global_basis
	return b.get_euler()

func _montar(cid: String) -> Dictionary:
	var m := CharacterBuilder.build_character(cid)["node"] as Node3D
	get_root().add_child(m)
	var caixa := PlayerModelKit.model_aabb(m)
	var ky: float = PlayerRig.CHAR_TARGET_H / caixa.size.y
	m.scale = Vector3(ky, ky, ky)
	m.position.y = PlayerRig.FEET_Y - ky * caixa.position.y
	await process_frame
	var prof := BodyScanner.scan(m)
	var anim := ProceduralAnimator.new()
	m.add_child(anim)
	anim.setup(prof)
	return {"modelo": m, "anim": anim, "perfil": prof}

func _rodar(c: Dictionary, quadros: int) -> void:
	for i in quadros:
		(c.anim as ProceduralAnimator).update(VEL_RUN, true, false, DT, 0.0, true)
