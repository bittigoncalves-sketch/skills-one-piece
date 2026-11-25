class_name BossTelegraph
extends MeshInstance3D
## Marca vermelha no chão com a área de alcance do soco em curso: a cápsula que o
## punho varre (caminho + raio da hitbox), projetada no piso. Só apresentação —
## não decide dano; quem define o caminho é BossVisual, com a mesma pose do combate.
## Na preparação ela se enche do Boss até a ponta; no contato fica cheia; some na
## recuperação.
const FLOOR_OFFSET := 0.03
const FADE_OUT := 0.12
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float half_length = 0.5;
uniform float radius = 0.25;
uniform float fill = 0.0;
uniform float intensity = 1.0;
varying vec3 local_position;
void vertex() {
	local_position = VERTEX;
}
void fragment() {
	float core = max(half_length - radius, 0.0);
	float d = length(vec2(local_position.x, max(abs(local_position.z) - core, 0.0))) - radius;
	float aa = max(fwidth(d), 0.0005);
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float rim = inside * smoothstep(-0.04 - aa, -0.04 + aa, d);
	// 0 no lado do Boss, 1 na ponta do alcance (local -Z aponta para a ponta).
	float along = clamp(0.5 - local_position.z / (2.0 * half_length), 0.0, 1.0);
	float filled = inside * (1.0 - smoothstep(fill - 0.02, fill, along));
	ALBEDO = vec3(1.0, 0.07, 0.04);
	ALPHA = clamp(rim * 0.95 + filled * 0.5 + inside * 0.12, 0.0, 1.0) * intensity;
}
"""
static var _shader: Shader
var _plane := PlaneMesh.new()
var _material := ShaderMaterial.new()

func _ready() -> void:
	top_level = true
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material.shader = _shader
	mesh = _plane
	material_override = _material

## Caminho em coordenadas globais; a altura dos pontos é descartada.
func aim(start: Vector3, finish: Vector3, radius: float, floor_y: float) -> void:
	var path := Vector3(finish.x - start.x, 0, finish.z - start.z)
	var half_length := path.length() * 0.5 + radius
	_plane.size = Vector2(radius * 2.0, half_length * 2.0)
	var direction := path.normalized() if path.length_squared() > 0.0001 else Vector3.FORWARD
	global_transform = Transform3D(Basis.looking_at(direction, Vector3.UP),
		Vector3((start.x + finish.x) * 0.5, floor_y + FLOOR_OFFSET, (start.z + finish.z) * 0.5))
	_material.set_shader_parameter("half_length", half_length)
	_material.set_shader_parameter("radius", radius)

## `time` < 0 = sem golpe. Chamado a cada quadro pelo BossVisual.
func present(move: BossAbility, time: float, interrupted: bool) -> void:
	var recovery_time := time - move.windup - move.active
	var start := move.telegraph_start()
	visible = time >= start and time >= 0 and not interrupted and recovery_time < FADE_OUT
	if not visible:
		return
	var fill := smoothstep(start, move.windup, time)
	var intensity := 0.55 + 0.45 * fill
	if recovery_time >= 0:
		intensity = 1.0 - recovery_time / FADE_OUT
	_material.set_shader_parameter("fill", fill)
	_material.set_shader_parameter("intensity", intensity)
