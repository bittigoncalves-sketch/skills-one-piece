extends RefCounted
# ============================================================================
#  VISUAL DO INSTRUTOR (20/11/2026) — adapta ao rig real o design do Codex (`art_src/references/treino/01_treinador_frente_tres_quartos.png`): cabelo cacheado escuro, barba curta,
#  colete índigo (o quimono do catálogo), calça e botas escuras, FAIXA OCRE na cintura com a ponta caindo, ataduras claras nos punhos.
#  O catálogo de aparência da campanha cobre cabelo/roupa/barba; a faixa e as ataduras não existem nele, então saem daqui, presas às juntas do rig.
#  GATILHO: se outro NPC precisar de faixa/ataduras, vão para `DetalhesHistoria.ACESSORIOS` como peça do catálogo.
# ============================================================================
const APARENCIA := {"cabelo": "cabelo_curto_volumoso", "cor_cabelo": "preto", "roupa": "kimono", "calca": "escura", "sapatos": "pretos", "acc_rosto": "barba_curta",
	"olhos": "amendoados", "cor_olhos": "castanho", "sobrancelhas": "espessas", "nariz": "reto"}
const PELE := Color(0.86, 0.68, 0.52)
const OCRE := Color(0.84, 0.58, 0.1)
const CREME := Color(0.9, 0.86, 0.78)


## Pose de instruir (ref. `02_treinador_instruindo.png`): base aberta e agachada, punho esquerdo na guarda, braço direito esticado apontando para o boneco.
## Graus por osso (a convenção do `pose_de_skill` do jogador: 90° no ombro = braço na horizontal, para a frente); o animador do NPC soma por cima do idle.
const POSE_GRAUS := {
	"UpperArm_R": Vector3(90, 8, 0), "ForeArm_R": Vector3(0, 0, 0),
	"UpperArm_L": Vector3(35, 0, 22), "ForeArm_L": Vector3(105, 0, 0),
	"Thigh_R": Vector3(-22, 0, 14), "Thigh_L": Vector3(18, 0, -14), "Shin_R": Vector3(28, 0, 0), "Shin_L": Vector3(14, 0, 0),
	"Torso": Vector3(0, 18, 0), "Head": Vector3(0, -18, 0),
}


static func pose() -> Dictionary:
	var saida := {}
	for osso: String in POSE_GRAUS:
		saida[osso] = (POSE_GRAUS[osso] as Vector3) * PI / 180.0
	return saida


## Pose do instante `t` para o NPC (a animação por cima do idle: guarda, combo, aponta, gancho; `falando` → explica). Ver `AnimacoesDoInstrutor`.
static func pose_animada(t: float, falando: bool) -> Dictionary:
	return AnimacoesDoInstrutor.pose(t, falando, POSE_GRAUS)      # em GRAUS: a função converte


static func vestir(modelo: Node3D) -> void:
	if modelo == null:
		return
	var D := load("res://src/player/detalhes_historia.gd")
	var A := load("res://src/player/aparencia_historia.gd")
	D.aplicar(modelo, "masculino", "padrao", A.normalizar(APARENCIA))
	var coldres := modelo.find_child("MeraPistolHolsters", true, false) as Node3D
	if coldres != null:
		coldres.visible = false          # o cinto vermelho com coldres do rig base não combina com o instrutor
	_sem_mangas(modelo)
	var quadril := modelo.find_child("Torso", true, false) as Node3D      # corpo em blocos (21/11/2026): o quadril é uma caixa filha do `Torso`
	if quadril == null:
		quadril = modelo.find_child("Pelvis", true, false) as Node3D      # rig antigo
	if quadril != null:
		_faixa(quadril)
	for lado in ["L", "R"]:
		var punho := modelo.find_child("Wrist_" + lado, true, false) as Node3D
		if punho != null:
			_caixa(punho, "Atadura", Vector3(0.27, 0.16, 0.27), Vector3(0, 0.07, 0), CREME)      # um pouco mais larga que o antebraço (0,24) para cobrir sem z-fighting


## Colete sem manga (a referência do Codex): some a manga do quimono/camisa e os braços ficam cor de pele.
## Corpo em blocos: a manga é a caixa `Manga` e o braço já é de pele; o rig antigo ainda é tratado pelos `Geo_*`.
static func _sem_mangas(modelo: Node3D) -> void:
	for mi in modelo.find_children("*", "MeshInstance3D", true, false):
		var nome := str(mi.name)
		if nome.begins_with("kimono_manga") or nome == "Manga":
			(mi as Node3D).visible = false
		elif nome.begins_with(("Geo_UpperArm")) or nome.begins_with("Geo_ForeArm") or nome.begins_with("Geo_Shoulder") or nome.begins_with("Geo_ElbowJoint"):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			for s in m.mesh.get_surface_count():
				var mat := m.get_active_material(s)
				var novo: StandardMaterial3D = mat.duplicate() if mat is StandardMaterial3D else StandardMaterial3D.new()
				novo.albedo_color = PELE
				m.set_surface_override_material(s, novo)


static func _faixa(quadril: Node3D) -> void:
	# O obi do quimono vem vermelho por VERTEX COLOR (não se recolore pelo material): esta faixa ocre, mais larga e mais alta, o cobre por inteiro.
	# Corpo em blocos: o obi VERMELHO do `kimono_tronco` (medido no Torso: x ±0,29, z −0,20…+0,25, a partir de y 0,15) fica ACIMA do quadril (0…0,16),
	# então a faixa ocre cobre a altura do obi (y 0,12…0,32) e é um pouco maior que o quimono; o nó e a ponta caem na FRENTE (−Z).
	_caixa(quadril, "FaixaOcre", Vector3(0.62, 0.2, 0.49), Vector3(0, 0.22, 0.025), OCRE)
	_caixa(quadril, "NoDaFaixa", Vector3(0.12, 0.12, 0.06), Vector3(0.1, 0.22, -0.23), OCRE)
	_caixa(quadril, "PontaDaFaixa", Vector3(0.08, 0.34, 0.05), Vector3(0.12, 0.02, -0.24), OCRE)


static func _caixa(pai: Node3D, nome: String, tamanho: Vector3, pos: Vector3, cor: Color) -> void:
	var m := MeshInstance3D.new()
	m.name = nome
	var b := BoxMesh.new()
	b.size = tamanho
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	m.material_override = mat
	m.position = pos
	pai.add_child(m)
