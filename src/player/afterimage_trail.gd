class_name AfterimageTrail
extends RefCounted

const INTERVALO := 0.09
const VIDA := 0.46
const MAX_ECOS := 5
var _tempo := 0.0
var _ecos: Array[Dictionary] = []

func atualizar(delta: float, modelo: Node3D, ativo: bool) -> void:
	for eco in _ecos.duplicate():
		eco.vida -= delta
		if eco.vida <= 0.0 or not is_instance_valid(eco.no):
			if is_instance_valid(eco.no): eco.no.queue_free()
			_ecos.erase(eco)
	if not ativo or modelo == null or not is_instance_valid(modelo):
		_tempo = 0.0
		return
	_tempo += delta
	if _tempo < INTERVALO:
		return
	_tempo = 0.0
	_criar_eco(modelo)

func _criar_eco(modelo: Node3D) -> void:
	var mundo := modelo.get_tree().current_scene
	if mundo == null: return
	var eco := modelo.duplicate() as Node3D
	if eco == null: return
	eco.name = "EcoDeMovimento"
	eco.process_mode = Node.PROCESS_MODE_DISABLED
	# Alguns adornos usam shader para DEFINIR a própria silhueta (a chama 2D do
	# Lunariano). Como o eco recebe material neutro, manter esses nós mostraria o
	# quad-base como um retângulo. Remove só o que foi marcado pelo criador; asas,
	# caudas, chifres e o corpo continuam compondo a silhueta do rastro.
	_remover_elementos_sem_eco(eco)
	mundo.add_child(eco)
	eco.global_transform = modelo.global_transform
	_remover_colisao_e_colorir(eco, 0.30)
	_ecos.append({"no": eco, "vida": VIDA})
	while _ecos.size() > MAX_ECOS:
		var velho: Dictionary = _ecos.pop_front()
		if is_instance_valid(velho.no): velho.no.queue_free()
	for i in _ecos.size():
		var item: Dictionary = _ecos[i]
		_aplicar_alpha(item.no, 0.30 * (1.0 - float(i) / float(MAX_ECOS + 1)))

func _remover_colisao_e_colorir(no: Node, alpha: float) -> void:
	if no is CollisionObject3D:
		(no as CollisionObject3D).collision_layer = 0
		(no as CollisionObject3D).collision_mask = 0
	if no is CollisionShape3D:
		(no as CollisionShape3D).disabled = true
	if no is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Rastro neutro: conserva a silhueta, mas sem cor de energia/fogo.
		mat.albedo_color = Color(0.90, 0.94, 1.0, alpha)
		(no as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(no as MeshInstance3D).material_override = mat
	for filho in no.get_children(): _remover_colisao_e_colorir(filho, alpha)

func _remover_elementos_sem_eco(no: Node) -> void:
	for filho in no.get_children():
		if bool(filho.get_meta("afterimage_excluir", false)):
			no.remove_child(filho)
			filho.queue_free()
		else:
			_remover_elementos_sem_eco(filho)

func _aplicar_alpha(no: Node, alpha: float) -> void:
	if no is MeshInstance3D and (no as MeshInstance3D).material_override is StandardMaterial3D:
		((no as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.a = alpha
	for filho in no.get_children(): _aplicar_alpha(filho, alpha)
