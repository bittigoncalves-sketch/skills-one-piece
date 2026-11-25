extends SceneTree
## Regressao geometrica do helper de feixe 3D.
##
## Execute:
##   godot --headless --path . --script tools/dev_tests/test_beam_visual_3d.gd

const Beam := preload("res://src/combat/beam_visual_3d.gd")

var _ok := 0
var _falhas := 0


func _init() -> void:
	var pai := Node3D.new()
	get_root().add_child.call_deferred(pai)
	await process_frame
	# Um pai transformado prova que a API realmente interpreta as pontas no
	# mundo, e nao apenas por acaso no espaco local de um Node3D identidade.
	pai.global_transform = Transform3D(
		Basis.from_euler(Vector3(0.2, 0.7, -0.1)), Vector3(4.0, 2.0, -3.0))

	var inicio := Vector3(-2.5, 1.3, 4.2)
	var fim := Vector3(7.1, 3.9, -8.4)
	var feixe: MeshInstance3D = Beam.criar(pai, inicio, fim, 0.16)
	_medir("criacao diagonal", feixe, inicio, fim)

	var material := feixe.material_override as StandardMaterial3D
	_checar("usa material StandardMaterial3D", material != null)
	_checar("material de malha mantem billboard desativado",
		material != null and material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED)
	_checar("a cor padrao do laser e amarela",
		material != null and material.albedo_color.r > 1.0
		and material.albedo_color.g > material.albedo_color.b * 2.0)

	var inicio_vertical := Vector3(1.0, -3.0, 2.0)
	var fim_vertical := Vector3(1.0, 8.0, 2.0)
	_checar("atualiza sem recriar a malha",
		Beam.atualizar(feixe, inicio_vertical, fim_vertical, 0.22))
	_medir("atualizacao vertical", feixe, inicio_vertical, fim_vertical)
	var cilindro := feixe.mesh as CylinderMesh
	_checar("atualiza o raio solicitado", absf(cilindro.top_radius - 0.22) < 0.001
		and absf(cilindro.bottom_radius - 0.22) < 0.001)

	_checar("segmento de comprimento zero e recusado",
		not Beam.atualizar(feixe, fim_vertical, fim_vertical))
	_checar("segmento degenerado fica invisivel", not feixe.visible)
	_checar("metadados preservam as duas pontas degeneradas",
		(feixe.get_meta(Beam.META_START) as Vector3).distance_to(fim_vertical) < 0.001
		and (feixe.get_meta(Beam.META_END) as Vector3).distance_to(fim_vertical) < 0.001)

	print("\n%d conferem | %d divergem" % [_ok, _falhas])
	pai.queue_free()
	quit(1 if _falhas > 0 else 0)


func _medir(nome: String, feixe: MeshInstance3D, inicio: Vector3, fim: Vector3) -> void:
	var cilindro := feixe.mesh as CylinderMesh
	var eixo := feixe.global_basis.y.normalized()
	var meia := cilindro.height * 0.5
	var ponta_a := feixe.global_position - eixo * meia
	var ponta_b := feixe.global_position + eixo * meia
	var erro_inicio := ponta_a.distance_to(inicio)
	var erro_fim := ponta_b.distance_to(fim)
	print("%s: erro inicio=%.5f m | erro fim=%.5f m" % [nome, erro_inicio, erro_fim])
	_checar("%s: inicio fica a menos de 5 cm" % nome, erro_inicio < 0.05)
	_checar("%s: fim fica a menos de 5 cm" % nome, erro_fim < 0.05)
	_checar("%s: eixo Y acompanha inicio -> fim" % nome,
		eixo.dot((fim - inicio).normalized()) > 0.999)
	_checar("%s: metadata beam_start e global" % nome,
		(feixe.get_meta(Beam.META_START) as Vector3).distance_to(inicio) < 0.001)
	_checar("%s: metadata beam_end e global" % nome,
		(feixe.get_meta(Beam.META_END) as Vector3).distance_to(fim) < 0.001)


func _checar(texto: String, condicao: bool) -> void:
	print("%s %s" % ["OK" if condicao else "FALHA", texto])
	if condicao:
		_ok += 1
	else:
		_falhas += 1
