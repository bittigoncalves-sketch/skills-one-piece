class_name BeamVisual3D
extends RefCounted
## Cilindro emissivo que ocupa exatamente o segmento global `inicio -> fim`.
##
## `CylinderMesh` nasce ao longo do eixo Y. Em vez de combinar `looking_at()`
## com uma rotacao de 90 graus, este helper constroi a base diretamente com Y
## na direcao do segmento. Isso tambem cobre miras verticais sem caso singular.

const LASER_YELLOW := Color(1.0, 0.88, 0.12, 0.96)
const MIN_LENGTH := 0.001

const META_VISUAL := &"beam_visual"
const META_START := &"beam_start"
const META_END := &"beam_end"
const META_DIRECTION := &"beam_direction"


## Cria, pendura no pai e posiciona um feixe em coordenadas globais.
static func criar(pai: Node, inicio: Vector3, fim: Vector3, raio: float = 0.1,
		cor: Color = LASER_YELLOW, energia: float = 8.0,
		aditivo: bool = true) -> MeshInstance3D:
	assert(pai != null, "BeamVisual3D requer um pai valido")
	var feixe := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = maxf(raio, MIN_LENGTH)
	cilindro.bottom_radius = maxf(raio, MIN_LENGTH)
	cilindro.height = MIN_LENGTH
	feixe.mesh = cilindro
	feixe.material_override = FxUtil.mesh_emissive_material(cor, energia, aditivo)
	feixe.set_meta(META_VISUAL, true)
	pai.add_child(feixe)
	atualizar(feixe, inicio, fim)
	if aditivo:
		_casca_de_brilho(feixe, raio, cor, energia)
	return feixe


## Halo do feixe: filho (herda posição, escala e comprimento do cilindro) mais largo e translúcido, somado — o núcleo fica nítido e a luz vaza em volta.
## Só em feixe aditivo; o filho usa o MESMO mesh, então `atualizar` (que muda a altura do CylinderMesh do pai) não o desfaz: ele escala em X/Z só.
static func _casca_de_brilho(feixe: MeshInstance3D, raio: float, cor: Color, energia: float) -> void:
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = feixe.mesh
	halo.material_override = FxUtil.mesh_emissive_material(Color(cor, 0.22), energia * 0.5, true)
	halo.scale = Vector3(2.6, 1.0, 2.6)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	feixe.add_child(halo)


## Move as pontas do feixe sem recriar a malha ou o material.
## Retorna `false` para um segmento degenerado; nesse caso ele fica invisivel.
static func atualizar(feixe: MeshInstance3D, inicio: Vector3, fim: Vector3,
		raio: float = -1.0) -> bool:
	assert(feixe != null, "BeamVisual3D.atualizar recebeu feixe nulo")
	assert(feixe.mesh is CylinderMesh,
		"BeamVisual3D.atualizar requer MeshInstance3D com CylinderMesh")

	var cilindro := feixe.mesh as CylinderMesh
	if raio >= 0.0:
		cilindro.top_radius = maxf(raio, MIN_LENGTH)
		cilindro.bottom_radius = maxf(raio, MIN_LENGTH)

	var vetor := fim - inicio
	var comprimento := vetor.length()
	var direcao := vetor / comprimento if comprimento > MIN_LENGTH else Vector3.ZERO
	feixe.set_meta(META_VISUAL, true)
	feixe.set_meta(META_START, inicio)
	feixe.set_meta(META_END, fim)
	feixe.set_meta(META_DIRECTION, direcao)

	if comprimento <= MIN_LENGTH:
		cilindro.height = MIN_LENGTH
		feixe.visible = false
		feixe.global_transform = Transform3D(Basis.IDENTITY, inicio)
		return false

	feixe.visible = true
	cilindro.height = comprimento
	feixe.global_transform = Transform3D(_base_com_y(direcao), inicio + vetor * 0.5)
	return true


## Base ortonormal destrorsa cujo eixo Y coincide com a direcao do cilindro.
static func _base_com_y(direcao: Vector3) -> Basis:
	var referencia := Vector3.UP if absf(direcao.dot(Vector3.UP)) < 0.999 else Vector3.RIGHT
	var eixo_x := referencia.cross(direcao).normalized()
	var eixo_z := eixo_x.cross(direcao).normalized()
	return Basis(eixo_x, direcao, eixo_z)
