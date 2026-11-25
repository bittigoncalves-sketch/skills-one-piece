class_name GizmoDoEditor
extends Node3D
# ============================================================================
#  GIZMO — as alças de MOVER (setas), ESCALAR (bolinhas nas faces) e GIRAR
#  (anéis), com as cores de eixo de sempre: X vermelho, Y verde, Z azul.
#
#  O gizmo NÃO mexe em peça nenhuma. Ele só responde "qual alça está sob o mouse"
#  e "quanto o mouse andou ao longo dela desde o clique" (metros, ou radianos no
#  anel). Quem transforma isso em peça movida é o editor, pela `GizmoMatematica`
#  — assim o comportamento de cada ferramenta é testável sem mouse.
#
#  POR QUE A PEGA É EM ESPAÇO DE TELA
#  ----------------------------------
#  As alças são finas (a seta tem 5 cm de raio antes da escala). Um raio de
#  física contra elas erraria o clique toda hora. Projetar a alça na tela e medir
#  a distância em PIXELS dá a mesma tolerância perto e longe — é o que os editores
#  de 3D fazem.
#
#  O tamanho na tela é constante: a escala acompanha a distância da câmera.
# ============================================================================

## RELEVO (01/10/2026): o pincel de relevo — sem alça; quem trata é o editor.
enum Ferramenta { SELECIONAR, MOVER, ESCALAR, GIRAR, RELEVO }

const CORES := [Color(0.93, 0.27, 0.27), Color(0.36, 0.82, 0.30), Color(0.27, 0.52, 0.96)]
const COR_ATIVA := Color(1.0, 0.85, 0.2)
const TAMANHO_NA_TELA := 0.13          # fração da distância até a câmera
const PEGA_SETA_PX := 10.0
const PEGA_FACE_PX := 14.0
const PEGA_ANEL_PX := 8.0
const AMOSTRAS_DO_ANEL := 48

var ferramenta: int = Ferramenta.MOVER

var _camera: Camera3D
var _centro := Vector3.ZERO
var _base := Basis.IDENTITY
var _meio := Vector3.ONE
var _ligado := false
var _alcas: Array[Dictionary] = []
var _destacada := -1
var _arraste: Dictionary = {}


func configurar(camera: Camera3D) -> void:
	_camera = camera
	for eixo in 3:
		_alcas.append(_nova_alca("seta", eixo, 1, _malha_seta()))
		for sinal in [1, -1]:
			var bola := SphereMesh.new()
			bola.radius = 0.09
			bola.height = 0.18
			_alcas.append(_nova_alca("face", eixo, sinal, [bola]))
		var anel := TorusMesh.new()
		anel.inner_radius = 0.965
		anel.outer_radius = 1.035
		anel.rings = 48
		_alcas.append(_nova_alca("anel", eixo, 1, [anel]))
	_atualizar_visibilidade()


## `base` = eixos das alças (mundo para mover/girar; locais da peça para escalar).
## `meio` = meia-extensão da peça, onde as bolinhas de escalar ficam.
func mostrar(centro: Vector3, base: Basis, meio: Vector3) -> void:
	_centro = centro
	_base = base.orthonormalized()
	_meio = meio
	_ligado = true
	_atualizar_visibilidade()
	_posicionar()


func esconder() -> void:
	_ligado = false
	_arraste = {}
	_destacar(-1)
	_atualizar_visibilidade()


## Alguma alça está desenhada? (Para o teste e para o editor esconder no "Testar".)
func visible_alcas() -> bool:
	for a in _alcas:
		if (a["no"] as Node3D).visible:
			return true
	return false


func arrastando() -> bool:
	return not _arraste.is_empty()


func eixo_do_mundo(eixo: int) -> Vector3:
	return _base[eixo].normalized()


## Índice da alça mais próxima do ponto da tela, ou −1.
func alca_em(ponto: Vector2) -> int:
	if not _ligado or _camera == null:
		return -1
	var escala := _escala()
	var melhor := -1
	var melhor_d := INF
	for i in _alcas.size():
		var a := _alcas[i]
		if not (a["no"] as Node3D).visible:
			continue
		var d := _distancia_na_tela(a, ponto, escala)
		if d < melhor_d:
			melhor_d = d
			melhor = i
	return melhor


func destacar_sob(ponto: Vector2) -> void:
	if not arrastando():
		_destacar(alca_em(ponto))


## Começa a arrastar a alça `indice`. Devolve a descrição: tipo, eixo, sinal e o
## eixo no mundo — o editor precisa dela para saber o que fazer com o valor.
func comecar(indice: int, ponto: Vector2) -> Dictionary:
	var a := _alcas[indice]
	var eixo := eixo_do_mundo(a["eixo"])
	_arraste = {"alca": indice, "tipo": a["tipo"], "eixo": a["eixo"], "sinal": a["sinal"],
		"eixo_mundo": eixo, "centro": _centro}
	var origem := _camera.project_ray_origin(ponto)
	var direcao := _camera.project_ray_normal(ponto)
	if a["tipo"] == "anel":
		_arraste["anterior"] = GizmoMatematica.angulo_no_plano(origem, direcao, _centro, eixo)
		_arraste["total"] = 0.0
	else:
		_arraste["t0"] = GizmoMatematica.parametro_no_eixo(origem, direcao, _centro, eixo)
		_arraste["ultimo"] = 0.0
	_destacar(indice)
	return _arraste.duplicate()


## Quanto o mouse andou desde o clique: metros ao longo do eixo (positivo = para
## FORA na bolinha de escalar) ou radianos acumulados no anel.
func valor(ponto: Vector2) -> float:
	if not arrastando():
		return 0.0
	var origem := _camera.project_ray_origin(ponto)
	var direcao := _camera.project_ray_normal(ponto)
	var eixo: Vector3 = _arraste["eixo_mundo"]
	var centro: Vector3 = _arraste["centro"]
	if _arraste["tipo"] == "anel":
		var agora := GizmoMatematica.angulo_no_plano(origem, direcao, centro, eixo)
		if not is_nan(agora) and not is_nan(_arraste["anterior"]):
			# Soma passo a passo: dá para girar mais de meia volta sem o valor pular
			# de +180° para −180° no meio do arraste.
			_arraste["total"] += GizmoMatematica.diferenca_angular(_arraste["anterior"], agora)
		if not is_nan(agora):
			_arraste["anterior"] = agora
		return _arraste["total"]
	var t := GizmoMatematica.parametro_no_eixo(origem, direcao, centro, eixo)
	if is_nan(t) or is_nan(_arraste["t0"]):
		return _arraste["ultimo"]
	var v: float = (t - _arraste["t0"]) * float(_arraste["sinal"] if _arraste["tipo"] == "face" else 1)
	_arraste["ultimo"] = v
	return v


func terminar() -> void:
	_arraste = {}
	_destacar(-1)


func _process(_delta: float) -> void:
	if _ligado:
		_posicionar()


# ------------------------------------------------------------------ internos
func _posicionar() -> void:
	var escala := _escala()
	for a in _alcas:
		var no := a["no"] as Node3D
		var eixo := eixo_do_mundo(a["eixo"])
		var alinhada := _base_com_y_em(eixo).scaled(Vector3.ONE * escala)
		match a["tipo"]:
			"seta", "anel":
				no.global_transform = Transform3D(alinhada, _centro)
			"face":
				var ponto := _centro + eixo * float(a["sinal"]) * (_meio[a["eixo"]] + 0.35 * escala)
				no.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * escala), ponto)


func _escala() -> float:
	if _camera == null:
		return 1.0
	return maxf(_camera.global_position.distance_to(_centro) * TAMANHO_NA_TELA, 0.05)


func _distancia_na_tela(a: Dictionary, ponto: Vector2, escala: float) -> float:
	var eixo := eixo_do_mundo(a["eixo"])
	match a["tipo"]:
		"seta":
			var p0 := _centro + eixo * 0.15 * escala
			var p1 := _centro + eixo * 1.1 * escala
			if _camera.is_position_behind(p0) or _camera.is_position_behind(p1):
				return INF
			var d := GizmoMatematica.distancia_ao_segmento_2d(ponto,
				_camera.unproject_position(p0), _camera.unproject_position(p1))
			return d if d <= PEGA_SETA_PX else INF
		"face":
			var centro_da_bola := (a["no"] as Node3D).global_position
			if _camera.is_position_behind(centro_da_bola):
				return INF
			var d := ponto.distance_to(_camera.unproject_position(centro_da_bola))
			return d if d <= PEGA_FACE_PX else INF
		"anel":
			var u := GizmoMatematica._perpendicular(eixo)
			var v := eixo.cross(u)
			var menor := INF
			var anterior := Vector2.INF
			for i in AMOSTRAS_DO_ANEL + 1:
				var ang := TAU * i / AMOSTRAS_DO_ANEL
				var p := _centro + (u * cos(ang) + v * sin(ang)) * escala
				if _camera.is_position_behind(p):
					anterior = Vector2.INF
					continue
				var tela := _camera.unproject_position(p)
				if anterior != Vector2.INF:
					menor = minf(menor, GizmoMatematica.distancia_ao_segmento_2d(ponto, anterior, tela))
				anterior = tela
			return menor if menor <= PEGA_ANEL_PX else INF
	return INF


func _atualizar_visibilidade() -> void:
	var tipo_visivel := {Ferramenta.MOVER: "seta", Ferramenta.ESCALAR: "face", Ferramenta.GIRAR: "anel"}
	for a in _alcas:
		(a["no"] as Node3D).visible = _ligado and tipo_visivel.get(ferramenta, "") == a["tipo"]


func _destacar(indice: int) -> void:
	if indice == _destacada:
		return
	_destacada = indice
	for i in _alcas.size():
		var a := _alcas[i]
		(a["mat"] as StandardMaterial3D).albedo_color = COR_ATIVA if i == indice else CORES[a["eixo"]]


func _nova_alca(tipo: String, eixo: int, sinal: int, malhas: Array) -> Dictionary:
	var no := Node3D.new()
	no.name = "%s_%s%s" % [tipo, "XYZ"[eixo], "+" if sinal > 0 else "-"]
	add_child(no)
	# Material por alça (e não um por eixo) para destacar só a que está sob o mouse.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = CORES[eixo]
	mat.no_depth_test = true              # alça visível mesmo atrás da peça
	mat.render_priority = 10
	for item in malhas:
		var parte := MeshInstance3D.new()
		if item is Array:                   # [malha, deslocamento em Y]
			parte.mesh = item[0]
			parte.position = Vector3(0, item[1], 0)
		else:
			parte.mesh = item
		parte.material_override = mat
		parte.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(parte)
	return {"tipo": tipo, "eixo": eixo, "sinal": sinal, "no": no, "mat": mat}


static func _malha_seta() -> Array:
	var haste := CylinderMesh.new()
	haste.top_radius = 0.025
	haste.bottom_radius = 0.025
	haste.height = 0.85
	var ponta := CylinderMesh.new()
	ponta.top_radius = 0.0
	ponta.bottom_radius = 0.08
	ponta.height = 0.22
	return [[haste, 0.425 + 0.1], [ponta, 1.0 + 0.06]]


## Base cujo +Y aponta para `eixo` (as malhas das alças são modeladas em Y).
static func _base_com_y_em(eixo: Vector3) -> Basis:
	var y := eixo.normalized()
	var x := GizmoMatematica._perpendicular(y)
	return Basis(x, y, x.cross(y)).orthonormalized()
