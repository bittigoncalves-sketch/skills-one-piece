class_name TempoLocalDaHistoria
extends Node
# Liga o TEMPO LOCAL (`TempoLocal`) no Modo História e, com a vida na zona vermelha (< 25 %),
# desenha o volume de cada hitbox de disparo num raio de 20 m. Filho do jogador: sai junto com ele.
#
# As hitboxes vêm do grupo "hitbox" (toda `DamageZone`, mais a do Rocket): cada uma ganha uma
# marca filha ("HitboxVisivel") com o formato REAL do colisor — esfera, caixa, cápsula ou cilindro
# em vermelho translúcido; formato raro ou gigante (> 15 m) vira só o contorno em linhas, para
# uma parede de 70 m não pintar a tela inteira. O disparo do próprio jogador não ganha marca
# (ele sabe onde atira; a marca é para enxergar o que vem na sua direção).

const NOME_MARCA := "HitboxVisivel"
const INTERVALO := 0.1
const LADO_MAXIMO_SOLIDO := 15.0
const COR := Color(1.0, 0.12, 0.1, 0.30)

var jogador: Node3D
var _acumulado := 0.0
static var _material: StandardMaterial3D = null


func _ready() -> void:
	TempoLocal.jogador = jogador
	var visao := VisaoDeVida.new()      # a tela tinge e escurece conforme a vida
	visao.name = "VisaoDeVida"
	visao.jogador = jogador
	add_child(visao)


func _exit_tree() -> void:
	if TempoLocal.jogador == jogador:
		TempoLocal.jogador = null
	_limpar_marcas()


func _process(delta: float) -> void:
	_acumulado += delta
	if _acumulado < INTERVALO:
		return
	_acumulado = 0.0
	atualizar_hitboxes()


## Uma passada: marca quem está no raio com a vida no vermelho e desmarca o resto.
func atualizar_hitboxes() -> void:
	var ativo := TempoLocal.zona_vermelha()
	for no in get_tree().get_nodes_in_group("hitbox"):
		var h := no as Node3D
		if h == null or not h.is_inside_tree():
			continue
		var marca := h.get_node_or_null(NOME_MARCA)
		var mostrar := ativo and deve_mostrar(h)
		if mostrar and marca == null:
			var nova := montar_marca(h)
			if nova != null:
				h.add_child(nova)
		elif not mostrar and marca != null:
			marca.queue_free()


## Dentro do raio e não é do jogador.
static func deve_mostrar(h: Node3D) -> bool:
	if not TempoLocal.ligado():
		return false
	if h.global_position.distance_to(TempoLocal.jogador.global_position) > TempoLocal.RAIO:
		return false
	var autor: Variant = h.get("caster")
	return not (autor is Node and TempoLocal.e_do_jogador(autor as Node))


## Marca com o volume de cada `CollisionShape3D` filho da hitbox (null se não houver nenhum).
static func montar_marca(h: Node3D) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = NOME_MARCA
	for filho in h.get_children():
		var cs := filho as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = malha_da_forma(cs.shape)
		if mi.mesh == null:
			mi.free()
			continue
		mi.transform = cs.transform
		mi.material_override = material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
	if raiz.get_child_count() == 0:
		raiz.free()
		return null
	return raiz


## Volume sólido do formato; gigante ou desconhecido = contorno em linhas (`get_debug_mesh`).
static func malha_da_forma(forma: Shape3D) -> Mesh:
	if forma is SphereShape3D:
		var r := (forma as SphereShape3D).radius
		if r * 2.0 <= LADO_MAXIMO_SOLIDO:
			var m := SphereMesh.new()
			m.radius = r
			m.height = r * 2.0
			m.radial_segments = 24
			m.rings = 12
			return m
	elif forma is BoxShape3D:
		var t := (forma as BoxShape3D).size
		if maxf(t.x, maxf(t.y, t.z)) <= LADO_MAXIMO_SOLIDO:
			var m := BoxMesh.new()
			m.size = t
			return m
	elif forma is CapsuleShape3D:
		var c := forma as CapsuleShape3D
		if maxf(c.height, c.radius * 2.0) <= LADO_MAXIMO_SOLIDO:
			var m := CapsuleMesh.new()
			m.radius = c.radius
			m.height = c.height
			return m
	elif forma is CylinderShape3D:
		var c := forma as CylinderShape3D
		if maxf(c.height, c.radius * 2.0) <= LADO_MAXIMO_SOLIDO:
			var m := CylinderMesh.new()
			m.top_radius = c.radius
			m.bottom_radius = c.radius
			m.height = c.height
			return m
	return forma.get_debug_mesh()


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = COR
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.resource_name = "hitbox_visivel"
	return _material


func _limpar_marcas() -> void:
	if not is_inside_tree():
		return
	for no in get_tree().get_nodes_in_group("hitbox"):
		var marca := no.get_node_or_null(NOME_MARCA)
		if marca != null:
			marca.queue_free()
