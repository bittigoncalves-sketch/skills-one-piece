extends SceneTree
# Engrossa o personagem BASE no eixo FRENTE/TRÁS (Z).
#
# Ele nasceu com 0,25 m de profundidade contra 0,50 m de largura — de perfil vira
# uma tábua. Aqui os vértices de cada malha são escalados em Z (as juntas NÃO se
# movem: só o volume engorda) e a cena é regravada.
#
# Fatores por parte, não um multiplicador único: braço e perna já eram quadrados
# (0,25 × 0,25) e ficariam mais fundos que largos; o pé, ao contrário, precisa ser
# comprido pra frente.
#
# Uso: godot --headless --path . -s tools/engrossar_base.gd

const CENA := "res://assets/models/base.scn"
const ALVO_Z := {          # profundidade final, em metros
	"Torso": 0.36,
	"Head": 0.40,
	"UpperArm_L": 0.26, "UpperArm_R": 0.26,
	"ForeArm_L": 0.24, "ForeArm_R": 0.24,
	"Thigh_L": 0.30, "Thigh_R": 0.30,
	"Shin_L": 0.26, "Shin_R": 0.26,
	"Foot_L": 0.40, "Foot_R": 0.40,
}

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var packed = load(CENA)
	if packed == null:
		print("✗ não carregou ", CENA)
		quit(1)
		return
	var raiz: Node = packed.instantiate()
	get_root().add_child(raiz)

	# Contador em Array porque lambda de GDScript captura local por VALOR — um
	# `int` incrementado lá dentro não sai, e a cena nunca era salva.
	var conta := [0]
	_percorre(raiz, conta)

	if conta[0] == 0:
		print("nada a fazer — já está na profundidade alvo")
		quit()
		return

	# Todo nó precisa de owner pra entrar no PackedScene.
	_dono(raiz, raiz)
	var nova := PackedScene.new()
	if nova.pack(raiz) != OK:
		print("✗ falhou ao empacotar")
		quit(1)
		return
	var err := ResourceSaver.save(nova, CENA)
	print(("✓ regravado: " + CENA) if err == OK else ("✗ erro ao salvar: %d" % err))
	quit(0 if err == OK else 1)

func _percorre(n: Node, conta: Array) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var alvo = ALVO_Z.get(String(mi.name))
		if alvo != null:
			var atual: float = mi.mesh.get_aabb().size.z
			if atual > 0.0001 and absf(atual - float(alvo)) >= 0.0005:
				var f: float = float(alvo) / atual
				mi.mesh = _escalar_z(mi.mesh, f)
				print("  %-12s %.3f -> %.3f  (x%.2f)" % [mi.name, atual, float(alvo), f])
				conta[0] += 1
	for c in n.get_children():
		_percorre(c, conta)

func _dono(n: Node, raiz: Node) -> void:
	for c in n.get_children():
		c.owner = raiz
		_dono(c, raiz)

# Reconstrói a malha com Z escalado. Normais de caixa continuam alinhadas aos
# eixos, então não precisam de correção.
func _escalar_z(malha: Mesh, f: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for s in malha.get_surface_count():
		var arr := malha.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = Vector3(verts[i].x, verts[i].y, verts[i].z * f)
		arr[Mesh.ARRAY_VERTEX] = verts
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := malha.surface_get_material(s)
		if mat:
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out
