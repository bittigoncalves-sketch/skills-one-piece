extends RefCounted
# ============================================================================
#  ROUPA DE BANDIDO — o manequim Base vestido de bandido (08/10/2026).
#
#  Pedido do dono: "adicionar no mapa bandidos com base no dummy que é capaz de lutar";
#  escolha dele: "Base com roupa de bandido". O corpo é o MESMO `PlayerRig` do boneco
#  de duelo; aqui só a roupa:
#    • colete de couro no tronco, braços de fora (pele), calça escura e botas;
#    • bandana amarrada na cabeça (com as pontas do nó caindo atrás), máscara de pano
#      cobrindo a metade de baixo do rosto e um cinto com fivela.
#  A cor da bandana varia por bandido (`variante`), para o bando não ser seis cópias.
#  Vale para o rig do jogo e para a cena exportada para a loja do editor (nos dois as
#  malhas do corpo se chamam `Geo_*` e a cabeça é o nó `Head`): fonte única.
#  Medidas da cabeça do Base (caixa 0,425 × 0,335 × 0,365 m, frente em −Z) e da
#  cintura conferidas no modelo (08/10/2026).
# ============================================================================

const BANDANAS := [Color(0.66, 0.12, 0.1), Color(0.14, 0.24, 0.5), Color(0.74, 0.55, 0.12)]
const COLETE := Color(0.36, 0.25, 0.15)
const CALCA := Color(0.2, 0.22, 0.27)
const BOTA := Color(0.11, 0.08, 0.06)
const PELE := Color(0.82, 0.62, 0.46)
const MASCARA := Color(0.17, 0.15, 0.14)
const CINTO := Color(0.09, 0.06, 0.04)
const FIVELA := Color(0.82, 0.66, 0.25)

const PARTES_BOTA := ["Foot", "Toe", "Heel", "Ankle"]
const PARTES_CALCA := ["Thigh", "Shin", "Knee", "Pelvis"]
const PARTES_PELE := ["Head", "Neck", "Palm", "Index", "Middle", "Ring", "Little", "Thumb", "Wrist",
	"UpperArm", "ForeArm", "Elbow"]
## Cabeça do Base no espaço da malha `Geo_Head_Runtime` (centro na origem, meia-medida),
## frente em −Z.
const CABECA_MEIA := Vector3(0.2125, 0.1675, 0.1825)
const MARCA := "RoupaDeBandido"


## Veste `raiz` (o modelo do rig ou a cena do .glb). `variante` escolhe a bandana.
static func vestir(raiz: Node, variante := 0) -> void:
	_pintar(raiz)
	# Presos à MALHA da cabeça (não ao nó `Head`): a malha fica deslocada do nó, e as
	# medidas de `CABECA_MEIA` são as da caixa dela (a 1ª versão caiu no meio da testa).
	var cabeca := raiz.find_child("Geo_Head_Runtime", true, false) as Node3D
	if cabeca != null and cabeca.get_node_or_null(MARCA) == null:
		cabeca.add_child(_acessorios_da_cabeca(BANDANAS[posmod(variante, BANDANAS.size())]))
	var cintura := raiz.find_child("Geo_Waist_Runtime", true, false) as Node3D
	if cintura != null and cintura.get_node_or_null(MARCA) == null:
		cintura.add_child(_cinto())


static func _pintar(no: Node) -> void:
	if no is MeshInstance3D and String(no.name).begins_with("Geo_"):
		var mi := no as MeshInstance3D
		var nome := String(mi.name)
		var cor := COLETE
		for parte in PARTES_CALCA:
			if parte in nome:
				cor = CALCA
		for parte in PARTES_BOTA:
			if parte in nome:
				cor = BOTA
		for parte in PARTES_PELE:
			if parte in nome:
				cor = PELE
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var original := mi.get_active_material(s)
				var mat: StandardMaterial3D = original.duplicate() if original is StandardMaterial3D else StandardMaterial3D.new()
				# As juntas do manequim são um tom mais escuras: mantém a proporção
				# (a mesma regra de `NpcDaIlha.tingir`).
				var escuro: float = (original as StandardMaterial3D).albedo_color.v / 0.735 if original is StandardMaterial3D else 1.0
				mat.albedo_color = Color(cor.r * escuro, cor.g * escuro, cor.b * escuro)
				mi.set_surface_override_material(s, mat)
	for filho in no.get_children():
		_pintar(filho)


static func _acessorios_da_cabeca(cor_da_bandana: Color) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = MARCA
	var m := CABECA_MEIA
	var folga := 0.012
	# Bandana: cobre o alto da cabeça (do meio da testa ao topo) e um pouco do topo.
	# Entre a bandana (de +0,04 m para cima) e a máscara (de −0,04 m para baixo) fica a
	# faixa dos olhos, de pele: é ela que faz ler "bandido mascarado".
	raiz.add_child(_caixa("Bandana", Vector3(m.x * 2 + folga * 2, 0.15, m.z * 2 + folga * 2),
		Vector3(0, 0.115, 0), cor_da_bandana))
	raiz.add_child(_caixa("BandanaFaixa", Vector3(m.x * 2 + folga * 3, 0.03, m.z * 2 + folga * 3),
		Vector3(0, 0.055, 0), cor_da_bandana.darkened(0.3)))
	# O nó atrás (+Z) e as duas pontas caindo.
	raiz.add_child(_caixa("No", Vector3(0.07, 0.06, 0.05), Vector3(0, 0.045, m.z + 0.03), cor_da_bandana.darkened(0.15)))
	for lado in [-1.0, 1.0]:
		var ponta := _caixa("Ponta", Vector3(0.06, 0.14, 0.02), Vector3(lado * 0.035, -0.03, m.z + 0.055),
			cor_da_bandana.darkened(0.1))
		ponta.rotation = Vector3(deg_to_rad(28.0), 0.0, lado * deg_to_rad(16.0))
		raiz.add_child(ponta)
	# Máscara de pano: a metade de baixo do rosto, do nariz ao queixo, com a dobra.
	raiz.add_child(_caixa("Mascara", Vector3(m.x * 2 + folga * 2, 0.13, m.z * 2 + folga * 2),
		Vector3(0, -0.105, 0), MASCARA))
	var dobra := _caixa("Dobra", Vector3(m.x * 2 * 0.7, 0.1, 0.025), Vector3(0, -0.15, -m.z - 0.02), MASCARA.lightened(0.08))
	dobra.rotation.x = deg_to_rad(-12.0)
	raiz.add_child(dobra)
	return raiz


static func _cinto() -> Node3D:
	var raiz := Node3D.new()
	raiz.name = MARCA
	raiz.add_child(_caixa("Cinto", Vector3(0.33, 0.06, 0.235), Vector3.ZERO, CINTO))
	raiz.add_child(_caixa("Fivela", Vector3(0.07, 0.05, 0.02), Vector3(0, 0, -0.125), FIVELA, 0.6))
	return raiz


static func _caixa(nome: String, tamanho: Vector3, onde: Vector3, cor: Color, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = 0.85 if metal == 0.0 else 0.35
	mat.metallic = metal
	caixa.material = mat
	mi.mesh = caixa
	mi.position = onde
	return mi
