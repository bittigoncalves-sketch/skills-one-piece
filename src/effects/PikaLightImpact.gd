extends RefCounted
## Clarão compartilhado pelos impactos do Yasakani e da Chuva de Luz.

const COR_NUCLEO := Color(1.0, 0.99, 0.86, 1.0)
const COR_OURO := Color(1.0, 0.78, 0.16, 0.92)


## `raio_dano` > 0 faz o ANEL nascer do tamanho exato da hitbox que o
## chamador criou. Existe porque a Chuva de Luz desenhava um anel de 1,7 m
## sobre uma zona de dano de 2,2 m: quem visse o clarão e recuasse meio metro
## ainda levava o golpe, e aprendia uma distância que não é a verdadeira.
## Sem o argumento, mantém os raios antigos — os outros usos não mudam.
static func criar(world: Node, pos: Vector3, grande: bool = false,
		com_som: bool = false, raio_dano: float = 0.0) -> void:
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return
	var palco := Node3D.new()
	palco.name = "PikaImpactoGrande" if grande else "PikaImpacto"
	world.add_child(palco)
	palco.global_position = pos

	var flash := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.18 if not grande else 0.38
	esfera.height = esfera.radius * 2.0
	flash.mesh = esfera
	var mat := FxUtil.mesh_emissive_material(COR_NUCLEO, 12.0, true)
	flash.material_override = mat
	palco.add_child(flash)
	var final := 2.7 if not grande else 5.2
	var tw := flash.create_tween().set_parallel()
	tw.tween_property(flash, "scale", Vector3.ONE * final,
		0.16 if not grande else 0.24)
	tw.tween_property(mat, "albedo_color:a", 0.0,
		0.18 if not grande else 0.28)
	var raio_anel := raio_dano if raio_dano > 0.0 else (4.0 if grande else 1.7)
	GoroFX.shock_ring(palco, Vector3(0, 0.06, 0), COR_OURO,
		raio_anel, 0.28 if not grande else 0.42, 0.16)
	if grande:
		palco.add_child(GoroFX.sparks(28, 0.45, Vector3.UP, 82.0,
			3.0, 10.0, 0.12))
	if com_som:
		PikaAudio.play(world, pos, "impacto", 1.12 if not grande else 0.84)
	FxUtil.autofree(palco, 0.75)

