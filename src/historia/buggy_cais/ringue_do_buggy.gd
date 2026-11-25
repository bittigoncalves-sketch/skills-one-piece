class_name RingueDoBuggy
extends Node3D
# ============================================================================
#  O RINGUE DE LUTA LIVRE (22/11/2026) — montado por CÓDIGO com caixas voxel (plataforma, saia com o nome, 4 postes, 3 cordas). Texturas do Codex em
#  `assets/textures/luta_do_buggy/` (ringue_lona, ringue_corda, ringue_poste, ringue_saia); sem o PNG usa cor lisa — nunca fica sem ringue.
#  A plataforma tem COLISÃO (o jogador pisa nela); as cordas não (são só visual: a luta não deixa ninguém sair).
# ============================================================================
const PASTA := "res://assets/textures/luta_do_buggy/"
const LADO := 6.4                    # m: o piso (cabe na areia da praia, ~10 m)
const ALTURA_DO_PISO := 0.5          # m: o topo da lona acima do chão
const ALTURA_DO_POSTE := 1.7         # m acima da lona
const COR_LONA := Color(0.93, 0.9, 0.82)
const COR_SAIA := Color(0.55, 0.07, 0.09)
const COR_CORDA := Color(0.82, 0.1, 0.12)
const COR_POSTE := Color(0.5, 0.52, 0.56)
const ALTURAS_DAS_CORDAS := [0.45, 0.85, 1.25]


## Monta o ringue com o centro do PISO em `chao` (o ponto no chão). O topo da lona fica em `chao.y + ALTURA_DO_PISO`.
func montar(chao: Vector3) -> void:
	name = "RingueDoBuggy"
	global_position = chao
	var meio := LADO * 0.5
	# plataforma (lona em cima, saia em volta) + colisão
	_caixa("Lona", Vector3(LADO, 0.08, LADO), Vector3(0, ALTURA_DO_PISO - 0.04, 0), _material("ringue_lona", COR_LONA))
	_caixa("Base", Vector3(LADO - 0.1, ALTURA_DO_PISO - 0.08, LADO - 0.1), Vector3(0, (ALTURA_DO_PISO - 0.08) * 0.5, 0), _material("ringue_saia", COR_SAIA, Vector3(4, 1, 1)))   # a saia 64×16 cobre 6,3 × 0,4 m: repete 4× para o BUGGY não esticar
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	corpo.collision_layer = 1
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(LADO, ALTURA_DO_PISO, LADO)
	forma.shape = caixa
	forma.position = Vector3(0, ALTURA_DO_PISO * 0.5, 0)
	corpo.add_child(forma)
	add_child(corpo)
	# postes e cordas (uma corda por lado e altura)
	var cantos := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in 4:
		var c: Vector2 = cantos[i]
		_caixa("Poste%d" % i, Vector3(0.22, ALTURA_DO_POSTE, 0.22), Vector3(c.x * (meio - 0.15), ALTURA_DO_PISO + ALTURA_DO_POSTE * 0.5, c.y * (meio - 0.15)), _material("ringue_poste", COR_POSTE))
		var proximo: Vector2 = cantos[(i + 1) % 4]
		for h in ALTURAS_DAS_CORDAS.size():
			var a := Vector3(c.x, 0, c.y) * (meio - 0.15)
			var b := Vector3(proximo.x, 0, proximo.y) * (meio - 0.15)
			var comprimento := a.distance_to(b)
			var centro := (a + b) * 0.5 + Vector3.UP * (ALTURA_DO_PISO + float(ALTURAS_DAS_CORDAS[h]))
			var no := _caixa("Corda%d_%d" % [i, h], Vector3(0.07, 0.07, comprimento), centro, _material("ringue_corda", COR_CORDA))
			no.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), centro)       # local: o comprimento da caixa (Z) corre de um poste ao outro
	# a cobertura dos postes: uma "capa" vermelha no topo
	for i in 4:
		var c: Vector2 = cantos[i]
		_caixa("Capa%d" % i, Vector3(0.3, 0.3, 0.3), Vector3(c.x * (meio - 0.15), ALTURA_DO_PISO + ALTURA_DO_POSTE + 0.1, c.y * (meio - 0.15)), _material("ringue_corda", COR_CORDA))


## Onde pisar: o topo da lona no ponto `local` (relativo ao centro do ringue).
func topo(local := Vector3.ZERO) -> Vector3:
	return global_position + Vector3(local.x, ALTURA_DO_PISO, local.z)


func _caixa(nome: String, tamanho: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = nome
	var b := BoxMesh.new()
	b.size = tamanho
	b.material = material
	m.mesh = b
	m.position = pos
	add_child(m)
	return m


func _material(nome: String, cor: Color, escala_uv := Vector3.ONE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var caminho := PASTA + nome + ".png"
	if ResourceLoader.exists(caminho):
		mat.albedo_texture = load(caminho) as Texture2D
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_scale = escala_uv
	else:
		mat.albedo_color = cor
	mat.roughness = 0.85
	return mat
