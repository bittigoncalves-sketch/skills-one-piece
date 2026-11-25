class_name CenaCinematografica
extends Node
# ============================================================================
#  CENA CINEMATOGRÁFICA (21/11/2026) — o rodador de cutscenes do Modo História. Câmera PRÓPRIA por planos sobre o mundo real (sem trocar de cena: save, rede e mapa
#  continuam), tarjas + legendas pela `CaixaDeFalaCinematografica` (modo cena) e a HUD escondida. ESC pula; ao acabar OU pular, a câmera, a HUD e o jogador voltam
#  exatamente como estavam, e `ao_fim(pulou)` roda UMA vez.
#
#  Um PLANO é um dicionário:
#    dur       s (obrigatório, > 0)
#    de/para   Vector3: posição da câmera e ponto para onde ela olha (obrigatórios)
#    de_fim/para_fim   opcionais: a câmera anda até aqui ao longo do plano (suave); sem eles, câmera fixa
#    fov       graus (padrão 55)
#    balanco   Vector2(graus de rolagem, Hz) opcional: a câmera balança de lado (barril no mar, 22/11/2026)
#    legenda   {falante, texto} opcional (some sozinha ao fim do plano)
#    ao_entrar Callable opcional, chamado ao começar o plano (move atores, toca som…)
#    tremor    m opcional: câmera "na mão" (oscilação lenta de posição + rolagem mínima); 0,01–0,04 é sutil
#    fade_in / fade_out   s opcionais: o plano abre / fecha em preto (sobe/desce sozinho; não usar fade_out no último plano: a cena corta seca para o jogo)
#  `atualizar(t, dur)` Callable opcional: chamado todo quadro com o tempo do plano (animações de atores).
#  GATILHO: >3 cutscenes ou roteiro editado por dados → `RoteiroDeCena` em recurso (hoje a lista de planos é montada por código em cada cena).
# ============================================================================
signal terminou(pulou: bool)

var hud: Node = null                    # `HistoriaHud`: tem `modo_cinema(bool)` e a caixa de fala
var caixa: CaixaDeFalaCinematografica = null
var jogador: Node3D = null
var musica: MusicaDoDesafio = null      # opcional: se houver, `faixa` toca durante a cena e para (com fade) ao fim OU ao pular
var faixa := ""

var _planos: Array[Dictionary] = []
var _i := -1
var _t := 0.0
var _camera: Camera3D = null
var _camera_antes: Camera3D = null
var _ao_fim: Callable = Callable()
var _rodando := false
const FORCA_DA_VINHETA := 0.5
const SOMBRA_VINHETA := """shader_type canvas_item;
uniform float forca = 0.5;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.15, 1.0);
	COLOR = vec4(0.015, 0.02, 0.04, smoothstep(0.32, 0.82, length(d)) * forca);
}
"""
var _camada_fx: CanvasLayer = null       # vinheta + fade: criada DEPOIS de esconder as outras camadas, para continuar visível
var _fade: ColorRect = null
var _camadas_antes: Dictionary = {}      # CanvasLayer → visible antes da cena (todas as HUDs do jogo somem, menos a da caixa)


func rodando() -> bool:
	return _rodando


## Começa a cena. Devolve false (e não faz nada) se já há uma rodando ou a lista é inválida.
func tocar(planos: Array[Dictionary], ao_fim: Callable = Callable()) -> bool:
	if _rodando or planos.is_empty() or not validos(planos):
		return false
	_planos = planos
	_ao_fim = ao_fim
	_rodando = true
	_i = -1
	_camera_antes = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.name = "CameraDaCena"
	add_child(_camera)
	_camera.current = true
	if hud != null and hud.has_method("modo_cinema"):
		hud.call("modo_cinema", true)
	_esconder_outras_camadas()
	if caixa != null:
		caixa.entrar_em_cena()
		if not caixa.pediu_pular.is_connected(pular):
			caixa.pediu_pular.connect(pular)
	if musica != null and not faixa.is_empty():
		musica.tocar(faixa, false, 1.0)
	_proximo_plano()
	return true


static func validos(planos: Array[Dictionary]) -> bool:
	for p in planos:
		if float(p.get("dur", 0.0)) <= 0.0 or not (p.get("de") is Vector3) or not (p.get("para") is Vector3):
			return false
	return true


func pular() -> void:
	if _rodando:
		_fim(true)


func _proximo_plano() -> void:
	_i += 1
	if _i >= _planos.size():
		_fim(false)
		return
	_t = 0.0
	var p := _planos[_i]
	if caixa != null:
		var l: Dictionary = p.get("legenda", {})
		caixa.legenda(str(l.get("falante", "")), str(l.get("texto", "")))
	var entrar: Variant = p.get("ao_entrar")
	if entrar is Callable and (entrar as Callable).is_valid():
		(entrar as Callable).call()
	_aplicar(0.0)


func _process(delta: float) -> void:
	if not _rodando:
		return
	_t += delta
	var dur := float(_planos[_i]["dur"])
	var atualizar: Variant = _planos[_i].get("atualizar")
	if atualizar is Callable and (atualizar as Callable).is_valid():
		(atualizar as Callable).call(_t, dur)
	if _t >= dur:
		_proximo_plano()
	else:
		_aplicar(_t / dur)


## Vinheta fixa (escurece os cantos: foco no centro, cara de filme) e um preto para os fades, abaixo das tarjas/legendas da HUD.
func _montar_fx() -> void:
	_camada_fx = CanvasLayer.new()
	_camada_fx.name = "AcabamentoDaCena"
	_camada_fx.layer = (hud as CanvasLayer).layer - 1 if hud is CanvasLayer else 0
	add_child(_camada_fx)
	var vinheta := ColorRect.new()
	var sh := Shader.new()
	sh.code = SOMBRA_VINHETA
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("forca", FORCA_DA_VINHETA)
	vinheta.material = mat
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vinheta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada_fx.add_child(vinheta)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camada_fx.add_child(_fade)


## Opacidade do preto no instante `t` do plano `p` (fade_in no começo, fade_out no fim).
static func opacidade_do_fade(p: Dictionary, t: float) -> float:
	var dur := float(p.get("dur", 0.0))
	var a := 0.0
	var fi := float(p.get("fade_in", 0.0))
	var fo := float(p.get("fade_out", 0.0))
	if fi > 0.0:
		a = maxf(a, 1.0 - t / fi)
	if fo > 0.0:
		a = maxf(a, 1.0 - (dur - t) / fo)
	return clampf(a, 0.0, 1.0)


func _aplicar(k: float) -> void:
	if _camera == null or _i >= _planos.size():
		return
	var p := _planos[_i]
	var e := smoothstep(0.0, 1.0, k)
	var de: Vector3 = (p["de"] as Vector3).lerp(p.get("de_fim", p["de"]) as Vector3, e)
	var para: Vector3 = (p["para"] as Vector3).lerp(p.get("para_fim", p["para"]) as Vector3, e)
	_camera.fov = float(p.get("fov", 55.0))
	_camera.global_position = de
	if not de.is_equal_approx(para):
		var cima := Vector3.UP if absf((para - de).normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		_camera.look_at(para, cima)
	var tremor := float(p.get("tremor", 0.0))
	if tremor > 0.0:
		var s := Time.get_ticks_msec() / 1000.0
		_camera.global_position += _camera.global_transform.basis * Vector3(sin(s * 1.7) + 0.5 * sin(s * 4.3), sin(s * 2.3 + 1.0) + 0.5 * sin(s * 5.1), 0.0) * tremor
		_camera.rotate_object_local(Vector3.FORWARD, deg_to_rad(tremor * 25.0) * sin(s * 1.3 + 2.0))
	if _fade != null:
		_fade.color.a = opacidade_do_fade(p, k * float(p["dur"]))
	var balanco: Variant = p.get("balanco")
	if balanco is Vector2:
		_camera.rotate_object_local(Vector3.FORWARD, deg_to_rad((balanco as Vector2).x) * sin(Time.get_ticks_msec() / 1000.0 * TAU * (balanco as Vector2).y))


func _fim(pulou: bool) -> void:
	if not _rodando:
		return
	_rodando = false
	if caixa != null:
		caixa.sair_de_cena()
	if hud != null and hud.has_method("modo_cinema"):
		hud.call("modo_cinema", false)
	_devolver_camadas()
	if musica != null and not faixa.is_empty():
		musica.parar(faixa, 1.2 if pulou else 2.5)      # ao acabar de verdade a cauda da música some devagar; ao pular, mais rápido
	if _camera_antes != null and is_instance_valid(_camera_antes):
		_camera_antes.current = true
	if _camera != null:
		_camera.queue_free()
		_camera = null
	if _camada_fx != null:
		_camada_fx.queue_free()
		_camada_fx = null
		_fade = null
	var cb := _ao_fim
	_ao_fim = Callable()
	_planos = []
	terminou.emit(pulou)
	if cb.is_valid():
		cb.call(pulou)


## A HUD do jogador, a das criaturas, avisos de baú… são CanvasLayers próprias: esconde todas menos a que contém a caixa (que é a `hud`).
func _esconder_outras_camadas() -> void:
	_camadas_antes.clear()
	for c in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if c.is_queued_for_deletion():
			continue
		if c != hud and not (hud != null and hud.is_ancestor_of(c)):
			_camadas_antes[c] = (c as CanvasLayer).visible
			(c as CanvasLayer).visible = false


func _devolver_camadas() -> void:
	for c in _camadas_antes.keys():            # sem tipo no `for`: uma camada liberada durante a cena não pode quebrar a volta das outras
		if is_instance_valid(c):
			(c as CanvasLayer).visible = bool(_camadas_antes[c])
	_camadas_antes.clear()
