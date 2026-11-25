class_name RastroDeArma
extends Node3D
## RASTRO DA LÂMINA (12/11/2026) — o `trail_effects` do Epic Fight: uma fita entre o cabo e a ponta da arma durante a janela de rastro do golpe
## (`assets/epic_fight/trilhas.json`: `start_time`/`end_time` em segundos do CLIPE, ex. espada longa auto1 = 0,25–0,30 s). A janela vem do mod; a fita são as
## últimas `AMOSTRAS` posições (base + ponta) com alfa decrescente, em espaço do mundo (não acompanha o corpo). Sem janela no mod (golpe sem `trail_effects`), sem fita.
## Quem usa: `EspadaDaHistoria` com uma arma do Epic Fight na mão.

const AMOSTRAS := 10
const COR := Color(1.0, 1.0, 1.0, 0.55)

var executor: ExecutorCorpoACorpo
var arma: Node                    # `EspadaDaHistoria`: `ponto(&"EspadaBase"/&"EspadaPonta")`
var _malha := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _pontos: Array = []           # [[base, ponta], ...] do mais novo ao mais velho


func _ready() -> void:
	top_level = true
	_mi.mesh = _malha
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mi.material_override = m
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)


## A janela [início, fim] do rastro (s do clipe) do golpe em curso, ou vazio.
static func janela_do_golpe(golpe: GolpeDirecional) -> Vector2:
	if golpe == null or not golpe.clipe.begins_with("res://assets/epic_fight/res/ef_"):
		return Vector2(-1, -1)
	var nome := golpe.clipe.get_file().get_basename().trim_prefix("ef_")
	var t: Array = EpicFightDados.trilhas("combat/" + nome)
	if t.is_empty():
		return Vector2(-1, -1)
	var j: Dictionary = t[0]
	return Vector2(float(j.start_time), float(j.end_time))


func _physics_process(_d: float) -> void:
	if executor == null or arma == null or not is_instance_valid(arma):
		return
	var golpe := executor.golpe_atual
	var ativo := false
	if golpe != null and executor.atacando():
		var w := janela_do_golpe(golpe)
		var t_clipe: float = float(executor.get("_t_acao")) * golpe.velocidade_clipe
		ativo = w.x >= 0.0 and t_clipe >= w.x and t_clipe <= w.y + 0.05
	if ativo:
		var base: Vector3 = arma.ponto(&"EspadaBase")
		var ponta: Vector3 = arma.ponto(&"EspadaPonta")
		if base != Vector3.INF and ponta != Vector3.INF:
			_pontos.push_front([base, ponta])
	elif not _pontos.is_empty():
		_pontos.pop_back()                      # sem janela: a fita some pelo rabo
	while _pontos.size() > AMOSTRAS:
		_pontos.pop_back()
	_desenhar()


func _desenhar() -> void:
	_malha.clear_surfaces()
	if _pontos.size() < 2:
		return
	_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _pontos.size():
		var a := COR
		a.a *= 1.0 - float(i) / float(_pontos.size())
		_malha.surface_set_color(a)
		_malha.surface_add_vertex(_pontos[i][0])
		_malha.surface_set_color(a)
		_malha.surface_add_vertex(_pontos[i][1])
	_malha.surface_end()
