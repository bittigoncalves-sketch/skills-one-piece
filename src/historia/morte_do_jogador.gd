class_name MorteDoJogador
extends Node
# ============================================================================
#  A MORTE DO JOGADOR NO MODO HISTÓRIA (27/10/2026). Pedido do dono: "passar a emoção da morte ao jogador";
#  estilo escolhido por ele: dramático, tipo Souls.
#
#  Antes, morrer era instantâneo: a animação tocava e o corpo já reaparecia. Agora (≈ 5 s de tempo REAL):
#    0,0 s  golpe fatal: câmera lenta (×0,25), tela dessaturando com vinheta vermelha, o som desacelera e abafa
#           (filtro passa-baixa no Master), um estrondo grave e o primeiro batimento; o corpo cai (controles travados);
#    1,2 s  "VOCÊ MORREU" aparece, com quem te derrotou; os batimentos ficam mais lentos e somem;
#    3,6 s  fade para preto; no escuro o respawn (vida, ponto de renascimento) e o tempo/som voltam ao normal;
#    4,5 s  a tela volta do preto, já no ponto de renascimento.
#  Quem instala é o `ModoHistoria` (`Player.ao_morrer`); a arena segue com o respawn instantâneo do placar.
#  Tudo que mexe no jogo inteiro (tempo, áudio) é desfeito em `_exit_tree`, mesmo se a cena mudar no meio.
# ============================================================================

const ESCALA_DO_TEMPO := 0.25
const ESCALA_DO_AUDIO := 0.45
const T_TITULO := 1.2
const T_FADE_PRETO := 3.6
const DURACAO_DO_FADE := 0.8
const T_FIM := 4.6
const FREQ_PASSA_BAIXA := 700.0

const SHADER := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform float forca : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 c = texture(tela, SCREEN_UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 d = mix(c.rgb, vec3(g), forca * 0.92);
	d *= mix(1.0, 0.72, forca);
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	float v = smoothstep(0.30, 1.30, length(p * vec2(1.0, 0.85)));
	d = mix(d, vec3(0.42, 0.0, 0.02), v * forca * 0.9);
	COLOR = vec4(d, 1.0);
}
"""

var jogador: Node3D
var por_causa_de := ""
var camada: CanvasLayer
var _veu: ColorRect
var _titulo: Label
var _causa: Label
var _preto: ColorRect
var _bus_efeito := -1
var _efeito: AudioEffectLowPassFilter
var _imune_antes := false
var _ativo := false
var _batimentos: Array[AudioStreamPlayer] = []

## Para os testes: a sequência terminou e devolveu o mundo.
signal terminou


## Gancho de `Player.ao_morrer`.
static func iniciar(quem: Node3D, caiu := false) -> void:
	var cena := quem.get_tree().current_scene
	if cena == null:
		quem.net_force_respawn()
		quem.morrendo = false
		return
	var m := MorteDoJogador.new()
	m.name = "MorteDoJogador"
	m.process_mode = Node.PROCESS_MODE_ALWAYS
	m.jogador = quem
	m.por_causa_de = _quem_matou(quem, caiu)
	cena.add_child(m)


static func _quem_matou(quem: Node3D, caiu: bool) -> String:
	if caiu:
		return "a queda"
	if quem.has_meta("autor_do_dano"):
		var autor := instance_from_id(int(quem.get_meta("autor_do_dano"))) as Node
		if autor != null and is_instance_valid(autor) and autor != quem:
			return str(autor.call("nome_de_exibicao")) if autor.has_method("nome_de_exibicao") else String(autor.name)
	return ""


func _ready() -> void:
	_ativo = true
	_montar_tela()
	_imune_antes = bool(jogador.get_meta("damage_immune", false))
	jogador.set_meta("damage_immune", true)            # morto não morre de novo
	jogador.set_meta("morte_ja_animada", true)
	jogador.net_eliminar()                             # trava os controles, vida 0, anima a queda
	Engine.time_scale = ESCALA_DO_TEMPO
	AudioServer.playback_speed_scale = ESCALA_DO_AUDIO
	_efeito = AudioEffectLowPassFilter.new()
	_efeito.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, _efeito)
	_bus_efeito = AudioServer.get_bus_effect_count(0) - 1
	_sequencia()


func _real(segundos: float) -> void:
	await get_tree().create_timer(segundos, true, false, true).timeout


func _tween() -> Tween:
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return t


func _sequencia() -> void:
	_estrondo()
	_batida(1.0)
	var t := _tween()
	t.set_parallel(true)
	t.tween_property(_veu.material, "shader_parameter/forca", 1.0, 0.7)
	t.tween_property(_efeito, "cutoff_hz", FREQ_PASSA_BAIXA, 1.4)
	await _real(0.9)
	if not _ativo:
		return
	_batida(0.8)
	await _real(T_TITULO - 0.9)
	if not _ativo:
		return
	var tt := _tween()
	tt.set_parallel(true)
	tt.tween_property(_titulo, "modulate:a", 1.0, 1.0)
	tt.tween_property(_causa, "modulate:a", 1.0, 1.6)
	await _real(1.0)
	if not _ativo:
		return
	_batida(0.5)
	await _real(T_FADE_PRETO - T_TITULO - 1.0)
	if not _ativo:
		return
	var tf := _tween()
	tf.tween_property(_preto, "color:a", 1.0, DURACAO_DO_FADE)
	await _real(DURACAO_DO_FADE)
	if not _ativo:
		return
	_renascer()
	await _real(T_FIM - T_FADE_PRETO - DURACAO_DO_FADE)
	var tv := _tween()
	tv.tween_property(_preto, "color:a", 0.0, 0.9)
	await _real(0.9)
	queue_free()


## No escuro: devolve o mundo ao normal e o jogador ao ponto de renascimento.
func _renascer() -> void:
	_veu.material.set_shader_parameter("forca", 0.0)
	_titulo.modulate.a = 0.0
	_causa.modulate.a = 0.0
	_restaurar_mundo()
	if is_instance_valid(jogador):
		jogador.net_force_respawn()
		if _imune_antes:
			jogador.set_meta("damage_immune", true)
		else:
			jogador.remove_meta("damage_immune")
		jogador.morrendo = false


func _restaurar_mundo() -> void:
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	if _efeito != null:
		var i := -1
		for k in AudioServer.get_bus_effect_count(0):
			if AudioServer.get_bus_effect(0, k) == _efeito:
				i = k
		if i >= 0:
			AudioServer.remove_bus_effect(0, i)
		_efeito = null


func _exit_tree() -> void:
	_ativo = false
	_restaurar_mundo()
	if is_instance_valid(jogador) and jogador.morrendo:
		# A cena mudou no meio da sequência: não deixa o corpo preso.
		jogador.morrendo = false
		if jogador.has_meta("morte_ja_animada"):
			jogador.remove_meta("morte_ja_animada")
		if not _imune_antes and jogador.has_meta("damage_immune"):
			jogador.remove_meta("damage_immune")
	terminou.emit()


# ------------------------------------------------------------------ tela
func _montar_tela() -> void:
	camada = CanvasLayer.new()
	camada.layer = 100
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(camada)
	_veu = ColorRect.new()
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("forca", 0.0)
	_veu.material = mat
	camada.add_child(_veu)
	var centro := VBoxContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(centro)
	_titulo = Label.new()
	_titulo.text = "VOCÊ MORREU"
	_titulo.name = "Titulo"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_font_size_override("font_size", 96)
	_titulo.add_theme_color_override("font_color", Color(0.72, 0.05, 0.07))
	_titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_titulo.add_theme_constant_override("outline_size", 14)
	_titulo.modulate.a = 0.0
	centro.add_child(_titulo)
	_causa = Label.new()
	_causa.name = "Causa"
	_causa.text = "derrotado por %s" % por_causa_de if not por_causa_de.is_empty() else ""
	if por_causa_de == "a queda":
		_causa.text = "a queda foi fatal"
	_causa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_causa.add_theme_font_size_override("font_size", 28)
	_causa.add_theme_color_override("font_color", Color(0.82, 0.8, 0.78))
	_causa.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_causa.add_theme_constant_override("outline_size", 8)
	_causa.modulate.a = 0.0
	centro.add_child(_causa)
	for c in centro.get_children():
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preto = ColorRect.new()
	_preto.name = "Preto"
	_preto.color = Color(0, 0, 0, 0)
	_preto.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camada.add_child(_preto)


# ------------------------------------------------------------------ som (sintetizado, sem arquivo)
func _tocar(stream: AudioStreamWAV, volume_db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Batimento (lub-dub): senóide grave com decaimento rápido; `forca` 1 = cheio.
func _batida(forca: float) -> void:
	_tocar(_wav(_amostras_do_batimento()), linear_to_db(clampf(forca, 0.05, 1.0)) - 3.0)


## Estrondo grave da morte: varredura de 120 a 35 Hz com ruído, ~1,6 s.
func _estrondo() -> void:
	_tocar(_wav(_amostras_do_estrondo()), -4.0)


const TAXA := 22050


func _amostras_do_batimento() -> PackedFloat32Array:
	var n := int(TAXA * 0.8)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / TAXA
		var v := sin(TAU * 52.0 * t) * exp(-t * 16.0)
		var t2 := t - 0.27
		if t2 > 0.0:
			v += 0.7 * sin(TAU * 46.0 * t2) * exp(-t2 * 18.0)
		a[i] = v * 0.9
	return a


func _amostras_do_estrondo() -> PackedFloat32Array:
	var n := int(TAXA * 1.6)
	var a := PackedFloat32Array()
	a.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 27102026
	var fase := 0.0
	for i in n:
		var t := float(i) / TAXA
		var f := lerpf(120.0, 35.0, minf(t / 1.2, 1.0))
		fase += TAU * f / TAXA
		var env := exp(-t * 2.2) * minf(t * 60.0, 1.0)
		a[i] = (sin(fase) * 0.8 + rng.randf_range(-1.0, 1.0) * 0.25 * exp(-t * 6.0)) * env
	return a


static func _wav(amostras: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(amostras.size() * 2)
	for i in amostras.size():
		bytes.encode_s16(i * 2, int(clampf(amostras[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = TAXA
	w.stereo = false
	w.data = bytes
	return w
