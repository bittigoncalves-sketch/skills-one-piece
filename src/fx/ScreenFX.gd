extends CanvasLayer
## SCREEN FX (AUTOLOAD) — overlay 2D TRANSPARENTE (alpha) de game feel: VINHETA
## (por velocidade), FLASH de impacto e SPEED LINES (sprint). NÃO re-amostra a tela
## (sem screen_texture) -> nunca "branca a tela" mesmo se o shader falhar; a cor-base
## do ColorRect é transparente por segurança. Escala pelo dispositivo (GameFlow.device).
## Inclui filtro azul de Assistência de Mira e destaque vermelho em inimigos e outros seres.

const SHADER_CODE := """
shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float speed_lines = 0.0;
uniform float blue_filter = 0.0;
uniform float borrao = 0.0;      // arrasto radial: puxa a imagem p/ fora nas bordas
uniform float aberracao = 0.0;   // separação de cor nas bordas
uniform float tempo = 0.0;

void fragment() {
	vec2 dir = UV - vec2(0.5);
	float d = length(dir);
	float borda = smoothstep(0.18, 0.72, d);   // 0 no centro, 1 nas bordas

	// ---- ARRASTO RADIAL: o mundo escorre pra fora enquanto o centro fica nítido.
	// É o que vende velocidade sem cegar quem está mirando.
	vec3 base = texture(tela, SCREEN_UV).rgb;
	if (borrao > 0.001) {
		vec3 soma = vec3(0.0);
		for (int i = 1; i <= 6; i++) {
			float k = float(i) / 6.0;
			soma += texture(tela, SCREEN_UV - dir * k * borrao * borda * 0.13).rgb;
		}
		base = mix(base, soma / 6.0, borda * clamp(borrao, 0.0, 1.0));
	}

	// ---- ABERRAÇÃO CROMÁTICA: só nas bordas, e só em velocidade/impacto.
	if (aberracao > 0.001) {
		float s = aberracao * borda * 0.006;
		base.r = texture(tela, SCREEN_UV + dir * s).r;
		base.b = texture(tela, SCREEN_UV - dir * s).b;
	}

	vec3 col = base;

	// ---- LINHAS DE VELOCIDADE: estrias radiais animadas, não estáticas.
	// Sem o deslocamento por `tempo` elas viram uma grade parada e o olho
	// interpreta como sujeira na tela, não como movimento.
	if (speed_lines > 0.001) {
		float ang = atan(dir.y, dir.x);
		float faixa = fract(ang * 13.0 + sin(ang * 41.0) * 0.35 + tempo * 1.7);
		float estria = smoothstep(0.62, 0.46, abs(faixa - 0.5));
		float alcance = smoothstep(0.26, 0.68, d);
		col = mix(col, vec3(1.0), estria * alcance * speed_lines * 0.55);
	}

	// ---- VINHETA por último entre os de velocidade, e mais suave que antes.
	col = mix(col, vec3(0.0), smoothstep(0.40, 0.92, d) * vignette);

	// filtro azul (assistência de mira / Haki da observação)
	if (blue_filter > 0.001) {
		col = mix(col, vec3(0.06, 0.22, 0.75), blue_filter * 0.32);
	}
	col = mix(col, flash_color.rgb, flash);
	COLOR = vec4(col, 1.0);
}
"""

var _mat: ShaderMaterial
var _flash := 0.0
var _blue_filter_current := 0.0
var _blue_filter_target := 0.0

var _tempo := 0.0
var _aberr_base := 0.0     # contínua, vinda da velocidade
var _aberr_pulso := 0.0    # pico de impacto/dash, decai sozinho
var aim_assist_active := false
var _local_player: Node3D = null
var _red_target_mat: StandardMaterial3D
var _highlight_timer := 0.0

func _ready() -> void:
	layer = 100
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0, 0, 0, 0)   # fallback transparente (se o shader falhar, NÃO branqueia)
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	rect.material = _mat
	add_child(rect)

	_red_target_mat = StandardMaterial3D.new()
	_red_target_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_red_target_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_red_target_mat.albedo_color = Color(1.0, 0.15, 0.18, 0.82)
	_red_target_mat.emission_enabled = true
	_red_target_mat.emission = Color(1.0, 0.12, 0.12)
	_red_target_mat.emission_energy_multiplier = 2.8

func _process(delta: float) -> void:
	# `tempo` anima as estrias de velocidade. Sem ele, as linhas ficam paradas e
	# o olho lê como sujeira na tela em vez de movimento.
	_tempo += delta
	_mat.set_shader_parameter("tempo", _tempo)
	# Aberração decai sozinha: quem dispara (impacto, dash) só dá o pico.
	if _aberr_pulso > 0.0:
		_aberr_pulso = maxf(_aberr_pulso - delta * 3.2, 0.0)
		_aplica_aberracao()
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 4.5, 0.0)
		_mat.set_shader_parameter("flash", _flash)
	if not is_equal_approx(_blue_filter_current, _blue_filter_target):
		_blue_filter_current = move_toward(_blue_filter_current, _blue_filter_target, delta * 5.0)
		_mat.set_shader_parameter("blue_filter", _blue_filter_current)
	if aim_assist_active:
		_highlight_timer -= delta
		if _highlight_timer <= 0.0:
			_highlight_timer = 0.15
			update_aim_highlights(true)

# ---- API ----
func flash(color: Color = Color(1, 1, 1), strength: float = 0.5) -> void:
	_mat.set_shader_parameter("flash_color", color)
	_flash = maxf(_flash, strength * _scale())
	_mat.set_shader_parameter("flash", _flash)

func chromatic_pulse(strength: float = 1.0) -> void:
	# Agora é aberração de verdade (o shader lê a tela). Some sozinha no _process.
	_aberr_pulso = maxf(_aberr_pulso, clampf(strength, 0.0, 2.0))
	_aplica_aberracao()

func set_vignette(v: float) -> void:
	_mat.set_shader_parameter("vignette", clampf(v, 0.0, 1.0) * _scale())

func set_speed_lines(v: float) -> void:
	_mat.set_shader_parameter("speed_lines", clampf(v, 0.0, 1.0) * _scale())

# Arrasto radial por velocidade: o mundo escorre nas bordas, o centro fica nítido.
func set_borrao(v: float) -> void:
	_mat.set_shader_parameter("borrao", clampf(v, 0.0, 1.0) * _scale())

# Aberração contínua (velocidade). O pulso de impacto soma por cima.
func set_aberracao_base(v: float) -> void:
	_aberr_base = clampf(v, 0.0, 1.0)
	_aplica_aberracao()

func _aplica_aberracao() -> void:
	_mat.set_shader_parameter("aberracao", (_aberr_base + _aberr_pulso) * _scale())

func _scale() -> float:
	match GameFlow.device:
		"celular": return 0.45
		"tablet": return 0.75
		_: return 1.0

# ---- Assistência de Mira: filtro azul + destaque vermelho ----
func set_aim_assist(active: bool, player: Node3D = null) -> void:
	aim_assist_active = active
	if player:
		_local_player = player
	_blue_filter_target = 1.0 if active else 0.0
	update_aim_highlights(active)

func update_aim_highlights(enable: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var targets: Array[Node3D] = []
	for g in ["enemy", "companion", "dummy"]:
		for node in tree.get_nodes_in_group(g):
			if node is Node3D and not targets.has(node):
				targets.append(node)
	for p in tree.get_nodes_in_group("player"):
		if p is Node3D and p != _local_player and not targets.has(p):
			targets.append(p)
	for target in targets:
		var meshes := _collect_all_meshes(target)
		for mi in meshes:
			if not is_instance_valid(mi):
				continue
			var geo := mi as GeometryInstance3D
			if geo == null:
				continue
			if enable:
				if geo.material_overlay == null or geo.material_overlay == _red_target_mat:
					geo.material_overlay = _red_target_mat
			else:
				if geo.material_overlay == _red_target_mat:
					geo.material_overlay = null

func is_aim_target_highlighted(node: Node3D) -> bool:
	if not aim_assist_active or node == null or node == _local_player:
		return false
	return node.is_in_group("enemy") or node.is_in_group("companion") or node.is_in_group("dummy") or (node.is_in_group("player") and node != _local_player)

func get_target_material() -> StandardMaterial3D:
	return _red_target_mat

func _collect_all_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out += _collect_all_meshes(c)
	return out
