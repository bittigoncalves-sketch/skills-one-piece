extends CanvasLayer
## SCREEN FX (AUTOLOAD) — overlay 2D TRANSPARENTE (alpha) de game feel: VINHETA
## (por velocidade), FLASH de impacto e SPEED LINES (sprint). NÃO re-amostra a tela
## (sem screen_texture) -> nunca "branca a tela" mesmo se o shader falhar; a cor-base
## do ColorRect é transparente por segurança. Escala pelo dispositivo (GameFlow.device).
## Inclui filtro azul de Assistência de Mira e destaque vermelho em inimigos e outros seres.

const SHADER_CODE := """
shader_type canvas_item;
render_mode blend_mix;
uniform float vignette = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float speed_lines = 0.0;
uniform float blue_filter = 0.0;

void fragment() {
	vec2 dir = UV - vec2(0.5);
	float d = length(dir);
	// vinheta: preto nas bordas
	float vig = smoothstep(0.36, 0.85, d) * vignette;
	// speed lines: estrias brancas nas bordas
	float sl = 0.0;
	if (speed_lines > 0.001) {
		float ang = atan(dir.y, dir.x);
		float stripes = smoothstep(0.62, 0.5, abs(fract(ang * 14.0) - 0.5));
		float edge = smoothstep(0.30, 0.62, d);
		sl = stripes * edge * speed_lines * 0.6;
	}
	vec3 col = mix(vec3(0.0), vec3(1.0), sl);   // preto (vinheta) vs branco (linhas)
	float a = max(vig, sl);
	// filtro azul (assistência de mira / Haki da observação)
	if (blue_filter > 0.001) {
		col = mix(col, vec3(0.06, 0.22, 0.75), blue_filter);
		a = max(a, blue_filter * 0.32);
	}
	// flash por cima
	col = mix(col, flash_color.rgb, flash);
	a = max(a, flash);
	COLOR = vec4(col, a);                        // alpha 0 quando nada ativo -> transparente
}
"""

var _mat: ShaderMaterial
var _flash := 0.0
var _blue_filter_current := 0.0
var _blue_filter_target := 0.0

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
	# CA removida (causava tela branca); mantém a API viva com um flash bem sutil.
	flash(Color(1, 1, 1), strength * 0.08)

func set_vignette(v: float) -> void:
	_mat.set_shader_parameter("vignette", clampf(v, 0.0, 1.0) * _scale())

func set_speed_lines(v: float) -> void:
	_mat.set_shader_parameter("speed_lines", clampf(v, 0.0, 1.0) * _scale())

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
