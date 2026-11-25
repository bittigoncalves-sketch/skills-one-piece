extends SceneTree
## V2b: o terreno em BLOCOS no jogo de verdade (Modo História): o jogador fica de pé, as seções carregam ao redor dele, a malha
## distante ganha o furo e as técnicas cavam o chão. Cria o progresso de teste e anda um pouco.
##   godot --headless --path . --script tools/dev_tests/test_voxel_no_jogo.gd     (com MemoryMax)
const RelevoDasIlhas := preload("res://src/historia/ilhas/relevo_das_ilhas.gd")
var ok := 0
var falhas := 0
func frames(n: int) -> void:
	for i in n:
		await physics_frame
func confere(c: bool, m: String) -> void:
	if c:
		ok += 1
	else:
		falhas += 1
		print("FALHOU: ", m)
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_voxel_no_jogo.json")
	root.get_node("GameFlow").start_story()
	await frames(400)
	var j := get_first_node_in_group("player") as CharacterBody3D
	confere(RelevoDasIlhas.voxel, "o relevo em blocos está no modo voxel")
	var grades := get_nodes_in_group(GradeVoxel.GRUPO)
	confere(grades.size() >= 1, "há grades de terreno (%d)" % grades.size())
	var perto: GradeVoxel = null
	for g: GradeVoxel in grades:
		if g.secoes_com_malha() > 0 and (perto == null or g.secoes_com_malha() > perto.secoes_com_malha()):
			perto = g
	confere(perto != null, "a grade da ilha do jogador tem seções com malha")
	if perto != null:
		confere(not perto.tiles_colisao.is_empty(), "a colisão antiga está em faixas (%d)" % perto.tiles_colisao.size())
		var ativas := 0
		for t in perto.tiles_colisao:
			ativas += 1 if (perto.tiles_colisao[t] as CollisionShape3D).disabled else 0
		confere(ativas >= 4 and ativas < perto.tiles_colisao.size(), "só as faixas perto do jogador trocaram para blocos (%d de %d)" % [ativas, perto.tiles_colisao.size()])
	if perto != null:
		print("   (grade '%s': %d seções com malha, %d triângulos, %d guardadas)" % [perto.get_parent().get_meta("ilha"), perto.secoes_com_malha(), perto.triangulos(), perto.secoes_com_blocos()])
		var furo = (perto.get_parent().get_node("Malha") as MeshInstance3D).material_override.get_shader_parameter("furo_caixa")
		confere(furo is Vector4 and furo.z > furo.x, "a malha distante tem o furo ativo (%s)" % str(furo))
	confere(j.is_on_floor(), "o jogador está de pé no chão de blocos (y %.2f)" % j.global_position.y)
	# outras ilhas (longe) não carregam nada
	var carregadas := 0
	for g: GradeVoxel in grades:
		carregadas += 1 if g.secoes_com_malha() > 0 else 0
	confere(carregadas <= 2, "só a(s) grade(s) perto do jogador carregam (%d de %d)" % [carregadas, grades.size()])
	# andar: o chão acompanha e o jogador não cai
	var y0 := j.global_position.y
	for k in 6:
		j.global_position += Vector3(8, 0.5, 0)
		j.velocity = Vector3.ZERO
		await frames(45)
	confere(j.is_on_floor() and j.global_position.y > y0 - 6.0, "depois de andar 48 m o jogador segue no chão (y %.2f)" % j.global_position.y)
	# teletransporte longe dentro da ilha: a seção sob o jogador sai na hora
	j.global_position += Vector3(0, 0, 90)
	j.velocity = Vector3.ZERO
	await frames(30)
	confere(j.is_on_floor() or j.global_position.y > -1.0, "depois de um teletransporte de 90 m ninguém cai pelo mundo (y %.2f)" % j.global_position.y)
	print("VOXEL_NO_JOGO ok=%d falhas=%d" % [ok, falhas])
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
