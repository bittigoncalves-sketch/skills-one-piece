extends MeshInstance3D
## Área de dano do Gorila-rei mostrada em VERMELHO no chão (22/11/2026, pedido do dono: "ataques com área de dano mostrada em vermelho").
## Só apresentação: quem decide o dano é o `CombateGorila`, com as MESMAS funções de geometria daqui (`dentro_disco`, `dentro_anel`,
## `dentro_faixa`), então o que se vê é exatamente o que machuca. Enche de 0 a 1 durante a preparação; `estourar()` acende no contato.
enum Forma { DISCO, ANEL, FAIXA }
const SOBE_DO_CHAO := 0.06
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform int forma = 0;
uniform float raio = 4.0;
uniform float raio_interno = 0.0;
uniform vec2 meio = vec2(1.5, 8.0);
uniform float enchimento = 0.0;
uniform float intensidade = 1.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float d;
	float ao_longo;
	if (forma == 0) {
		float r = length(lp.xz);
		d = r - raio;
		ao_longo = r / raio;
	} else if (forma == 1) {
		float r = length(lp.xz);
		d = max(r - raio, raio_interno - r);
		ao_longo = clamp((r - raio_interno) / max(raio - raio_interno, 0.001), 0.0, 1.0);
	} else {
		vec2 q = abs(lp.xz) - meio;
		d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
		ao_longo = clamp(0.5 - lp.z / (2.0 * meio.y), 0.0, 1.0);
	}
	float aa = max(fwidth(d), 0.001);
	float dentro = 1.0 - smoothstep(-aa, aa, d);
	float borda = dentro * smoothstep(-0.28 - aa, -0.28 + aa, d);
	float cheio = dentro * (1.0 - smoothstep(enchimento - 0.02, enchimento, ao_longo));
	ALBEDO = vec3(1.0, 0.06, 0.03);
	ALPHA = clamp(borda * 0.95 + cheio * 0.5 + dentro * 0.14, 0.0, 1.0) * intensidade;
}
"""
static var _shader: Shader
var _plano := PlaneMesh.new()
var _material := ShaderMaterial.new()
var forma := Forma.DISCO
var centro := Vector3.ZERO          # centro da forma no mundo (DISCO/ANEL) ou ponto médio (FAIXA)
var raio := 0.0
var raio_interno := 0.0
var inicio := Vector3.ZERO          # FAIXA
var fim := Vector3.ZERO
var largura := 0.0
var _intensidade := 1.0
var _enchimento := 0.0


func _ready() -> void:
	top_level = true
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_material.shader = _shader
	_material.render_priority = 10
	mesh = _plano
	material_override = _material


## Círculo cheio de `r` m em `c` (a altura é a do chão em `c`).
func disco(c: Vector3, r: float) -> void:
	forma = Forma.DISCO
	centro = c
	raio = r
	raio_interno = 0.0
	_plano.size = Vector2(r * 2.0, r * 2.0)
	global_transform = Transform3D(Basis.IDENTITY, Vector3(c.x, c.y + SOBE_DO_CHAO, c.z))
	_material.set_shader_parameter("forma", 0)
	_material.set_shader_parameter("raio", r)
	_aparecer()


## Anel entre `r_interno` e `r` m em torno de `c`.
func anel(c: Vector3, r_interno: float, r: float) -> void:
	forma = Forma.ANEL
	centro = c
	raio = r
	raio_interno = r_interno
	_plano.size = Vector2(r * 2.0, r * 2.0)
	global_transform = Transform3D(Basis.IDENTITY, Vector3(c.x, c.y + SOBE_DO_CHAO, c.z))
	_material.set_shader_parameter("forma", 1)
	_material.set_shader_parameter("raio", r)
	_material.set_shader_parameter("raio_interno", r_interno)
	_aparecer()


## Faixa de `a` até `b`, com `l` m de largura. O enchimento vai de `a` (o chefe) até `b`.
func faixa(a: Vector3, b: Vector3, l: float) -> void:
	forma = Forma.FAIXA
	inicio = a
	fim = b
	largura = l
	var caminho := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var comprimento := maxf(caminho.length(), 0.1)
	var direcao := caminho / comprimento
	centro = Vector3((a.x + b.x) * 0.5, a.y, (a.z + b.z) * 0.5)
	_plano.size = Vector2(l, comprimento)
	global_transform = Transform3D(Basis.looking_at(direcao, Vector3.UP), Vector3(centro.x, a.y + SOBE_DO_CHAO, centro.z))
	_material.set_shader_parameter("forma", 2)
	_material.set_shader_parameter("meio", Vector2(l * 0.5, comprimento * 0.5))
	_aparecer()


func _aparecer() -> void:
	_intensidade = 1.0
	_enchimento = 0.0
	_material.set_shader_parameter("enchimento", 0.0)
	_material.set_shader_parameter("intensidade", 1.0)
	visible = true


## `f` de 0 a 1: quanto da preparação já passou (o vermelho cheio chega à borda no contato).
func preencher(f: float) -> void:
	_enchimento = clampf(f, 0.0, 1.0) * 1.02
	_material.set_shader_parameter("enchimento", _enchimento)


## No contato: tudo aceso e some em 0,25 s.
func estourar() -> void:
	_material.set_shader_parameter("enchimento", 2.0)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: _material.set_shader_parameter("intensidade", v), 1.0, 0.0, 0.25)
	t.tween_callback(esconder)


func esconder() -> void:
	visible = false


# ------------------------------------------------------------------ geometria do dano (a MESMA do que se vê)
## `p` (plano XZ) dentro do círculo de `r` m em `c`?
static func dentro_disco(p: Vector3, c: Vector3, r: float) -> bool:
	return Vector2(p.x - c.x, p.z - c.z).length() <= r


static func dentro_anel(p: Vector3, c: Vector3, r_interno: float, r: float) -> bool:
	var d := Vector2(p.x - c.x, p.z - c.z).length()
	return d <= r and d >= r_interno


## `p` dentro da faixa de `a` a `b` com `l` m de largura (as pontas incluem meia largura, como o desenho)?
static func dentro_faixa(p: Vector3, a: Vector3, b: Vector3, l: float) -> bool:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var comprimento := ab.length()
	if comprimento < 0.001:
		return ap.length() <= l * 0.5
	var u := ab / comprimento
	var ao_longo := ap.dot(u)
	var lateral := absf(ap.dot(Vector2(-u.y, u.x)))
	return ao_longo >= 0.0 and ao_longo <= comprimento and lateral <= l * 0.5
