class_name BreathVFX
extends Node3D
## VFX reutilizável — FÔLEGO do personagem enquanto corre.
##
## Estilo One Piece / Blox Fruits / Rell Seas: baforadas de vapor arredondadas,
## brancas com leve tom azulado, translúcidas e de bordas suaves. Sai perto da boca,
## expande e sobe devagar, é levada para trás pelo deslocamento e some rápido.
## Ritmo de respiração (baforada → pausa → baforada); a frequência sobe com a
## velocidade. NÃO depende do Player.
##
## API pública:
##   set_running(bool)      -> liga/desliga
##   start_running()        -> = set_running(true)
##   stop_running()         -> = set_running(false)  (some imediatamente)
##   set_intensity(0..1.5)  -> velocidade/esforço: controla frequência e visibilidade
##
## Uso típico (no dono, ex.: Player):
##   _breath.set_running(is_moving)
##   _breath.set_intensity(speed / SPEED)   # 1.0 = corrida normal, 1.5 = sprint

const MAT_PATH := "res://VFX/BreathParticleMaterial.tres"

# Intervalo entre baforadas (s): lento no esforço baixo, rápido no sprint.
const INTERVAL_SLOW := 0.62
const INTERVAL_FAST := 0.30
# Abaixo disto o esforço é fraco demais -> quase não respira (efeito ~invisível).
const MIN_INTENSITY := 0.35
const MAX_INTENSITY := 1.5

@export var puff_amount: int = 8
@export var puff_lifetime: float = 0.55

var _particles: GPUParticles3D
var _running := false
var _intensity := 1.0
var _accum := 0.0

func _ready() -> void:
	# Aceita um GPUParticles3D já montado na cena (nó "Puffs"); senão, monta em código.
	_particles = get_node_or_null("Puffs") as GPUParticles3D
	if _particles == null:
		_particles = _build_particles()
		add_child(_particles)
	_particles.emitting = false

func start_running() -> void:
	set_running(true)

func stop_running() -> void:
	set_running(false)

func set_running(running: bool) -> void:
	if running == _running:
		return
	_running = running
	if not running:
		# Para IMEDIATAMENTE: nenhuma baforada nova; as vivas somem no fade curto (<0.55s).
		if _particles:
			_particles.emitting = false
		_accum = 0.0

## Intensidade 0..1.5 (velocidade/esforço): controla frequência e visibilidade.
func set_intensity(value: float) -> void:
	_intensity = clampf(value, 0.0, MAX_INTENSITY)

func _process(delta: float) -> void:
	if not _running or _intensity < MIN_INTENSITY:
		return
	_accum += delta
	var t := clampf((_intensity - MIN_INTENSITY) / (MAX_INTENSITY - MIN_INTENSITY), 0.0, 1.0)
	var interval := lerpf(INTERVAL_SLOW, INTERVAL_FAST, t)
	if _accum >= interval:
		_accum = 0.0
		_emit_puff()

func _emit_puff() -> void:
	# one_shot + explosiveness=1 => restart() dispara UMA baforada e para sozinho.
	_particles.restart()
	_particles.emitting = true

# ---------------------------------------------------------------- construção ---
func _build_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Puffs"
	p.amount = maxi(puff_amount, 1)
	p.lifetime = puff_lifetime
	p.one_shot = true
	p.explosiveness = 1.0                 # a baforada nasce toda de uma vez
	p.local_coords = true                 # baforadas SEGUEM o rosto (a boca) até sumirem
	p.fixed_fps = 30                       # leve
	p.process_material = _load_or_build_material()
	p.draw_pass_1 = _build_puff_mesh()
	return p

func _load_or_build_material() -> ParticleProcessMaterial:
	if ResourceLoader.exists(MAT_PATH):
		var m: Resource = load(MAT_PATH)
		if m is ParticleProcessMaterial:
			return m
	return build_process_material()

# Estático para o gerador do .tres também poder usar.
static func build_process_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.03
	# Frente do projeto = -Z. As baforadas ficam À FRENTE do rosto (levemente -Z) e
	# sobem devagar; como local_coords=true, acompanham o rosto até sumirem.
	pm.direction = Vector3(0.0, 0.7, -0.3)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.55
	pm.gravity = Vector3(0.0, 0.15, 0.0)   # sobe levemente
	pm.damping_min = 0.4
	pm.damping_max = 0.7
	# Expande lentamente ao longo da vida.
	pm.scale_min = 0.5
	pm.scale_max = 0.8
	pm.scale_curve = _grow_curve()
	# Branco com leve azul; alpha nasce, aparece e some suave.
	pm.color = Color(0.88, 0.93, 1.0, 1.0)
	pm.color_ramp = _fade_ramp()
	return pm

static func _grow_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.6))
	c.add_point(Vector2(1.0, 1.3))
	var ct := CurveTexture.new()
	ct.curve = c
	return ct

static func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(0.9, 0.94, 1.0, 0.0))
	g.add_point(0.25, Color(0.9, 0.94, 1.0, 0.55))
	g.set_offset(g.get_point_count() - 1, 1.0)
	g.set_color(g.get_point_count() - 1, Color(0.9, 0.94, 1.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	return gt

# Quad billboard com um "dot" radial suave (bordas macias, estilo vapor). Sem
# arquivo de imagem: textura de gradiente radial gerada em memória.
static func _build_puff_mesh() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true      # recebe a cor/alpha da partícula
	mat.albedo_texture = _soft_dot_texture()
	mat.disable_receive_shadows = true
	q.material = mat
	return q

static func _soft_dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_offset(0, 0.0)
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.55, Color(1, 1, 1, 0.7))
	g.set_offset(g.get_point_count() - 1, 1.0)
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 1.0)
	return t
