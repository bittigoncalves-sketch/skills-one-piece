class_name VisaoDeVida
extends CanvasLayer
# A TELA ACOMPANHA A VIDA (04/11/2026, pedido do dono: "modificar a cor e a intensidade da tela
# conforme a vida"). Mesma faixa do tempo local: nada acima de 60 % de vida; daí a cor vai sumindo
# (dessatura), a imagem escurece e puxa para o vermelho, e a vinheta vermelha fecha das bordas —
# no mínimo da vida o quadro é quase monocromático e vermelho. Abaixo de 25 % (zona vermelha) a
# vinheta ainda PULSA no ritmo de um coração que acelera quanto menos vida.
#
# Fica na camada 3, ABAIXO do HUD (camada 5): barras e textos seguem legíveis; só o mundo tinge. Some
# na morte/reanimação (essas sequências têm o próprio véu). A força anda suave (3 s⁻¹): curar
# desbota o efeito em vez de cortá-lo.

const SHADER := """
shader_type canvas_item;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform float forca : hint_range(0.0, 1.0) = 0.0;
uniform float pulso : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 c = texture(tela, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 d = mix(c, vec3(g), forca * 0.78);                          // perde a cor
	d *= mix(1.0, 0.74, forca);                                      // escurece
	d = mix(d, d * vec3(1.35, 0.55, 0.50), forca * 0.6);             // vira para o vermelho
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	float v = smoothstep(0.40 - 0.22 * forca, 1.25, length(p * vec2(1.0, 0.85)));
	float borda = v * (0.30 + 0.70 * forca) * (1.0 + 0.45 * pulso);  // a vinheta fecha e pulsa
	d = mix(d, vec3(0.50, 0.0, 0.03), clamp(borda, 0.0, 0.95));
	COLOR = vec4(d, 1.0);
}
"""

const RITMO_BASE := 1.1          # batidas por segundo no começo da zona vermelha
const SUAVIDADE := 3.0

var jogador: Node3D
var forca := 0.0
var _veu: ColorRect
var _t := 0.0


func _init() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	_veu = ColorRect.new()
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_veu.material = mat
	_veu.visible = false
	add_child(_veu)


## A força-alvo (0..1) para uma fração de vida: 0 acima de 60 %, 1 em 1 %.
static func forca_para(fracao: float) -> float:
	return clampf((TempoLocal.VIDA_INICIO - fracao) / (TempoLocal.VIDA_INICIO - TempoLocal.VIDA_FIM), 0.0, 1.0)


## Batimentos por segundo na zona vermelha: acelera quanto menos vida (0 fora dela).
static func ritmo_para(fracao: float) -> float:
	if fracao >= TempoLocal.ZONA_VERMELHA or fracao <= 0.0:
		return 0.0
	return RITMO_BASE + 1.6 * (1.0 - fracao / TempoLocal.ZONA_VERMELHA)


func _process(delta: float) -> void:
	_t += delta
	var alvo := 0.0
	var ritmo := 0.0
	if TempoLocal.ligado() and not bool(jogador.get("morrendo")):
		var f := TempoLocal.fracao_de_vida()
		alvo = forca_para(f)
		ritmo = ritmo_para(f)
	forca = move_toward(forca, alvo, delta * SUAVIDADE)
	var pulso := 0.0
	if ritmo > 0.0:
		pulso = pow(maxf(sin(_t * TAU * ritmo), 0.0), 6.0)
	_veu.visible = forca > 0.002
	if _veu.visible:
		var mat := _veu.material as ShaderMaterial
		mat.set_shader_parameter("forca", forca)
		mat.set_shader_parameter("pulso", pulso)
