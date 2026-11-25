class_name McBlocosDinamicos
extends RefCounted
# ============================================================================
#  BLOCOS DINÂMICOS (31/10/2026) — os blocos que as técnicas do mod COLOCAM (`level.setBlock`):
#  gelo, gelo compacto, areia, terra, fogo, lava, água. O relevo das ilhas é uma malha fundida (não
#  se edita célula a célula), então os blocos novos vivem numa SOBREPOSIÇÃO esparsa, na grade do
#  mundo (0,88 m, a mesma do Mine Piece e do relevo em blocos):
#
#    célula (Vector3i) → { id, expira (tick do mundo; −1 = não expira), nó }
#
#  Decisão do dono (31/10): blocos SÓLIDOS DE VERDADE (cubo de 0,88 m com colisão na camada do
#  mundo) e que SOMEM SOZINHOS. O mod não tem tempo de vida (o bloco fica até algo o trocar), então
#  `VIDA_PADRAO` é só a rede de segurança do jogo: o que o mod desfaz por conta própria
#  (`setBlock … air`) é honrado na hora. Gatilho para revisitar: calibrar a vida depois de jogar.
#
#  Líquidos e fogo não têm colisão: são desenho (e a leitura `getBlockState` diz água/lava/fogo).
#  Teto de células: passando de `MAX_CELULAS` o MAIS ANTIGO sai (um meteoro não trava a placa de vídeo).
# ============================================================================

const B := 0.88                                  # MundoMinePiece.METROS_POR_BLOCO
const VIDA_PADRAO := 20 * 90                     # ticks (90 s)
const MAX_CELULAS := 600
const CAMADA_MUNDO := 1

## Aparência por bloco: cor, alfa, brilho (emissão). Fora daqui: pedra cinza.
const ESTILO := {
	&"minecraft:ice": {"cor": Color(0.62, 0.82, 1.0), "alfa": 0.72},
	&"minecraft:packed_ice": {"cor": Color(0.52, 0.72, 0.95), "alfa": 1.0},
	&"minecraft:blue_ice": {"cor": Color(0.40, 0.62, 0.95), "alfa": 1.0},
	&"minecraft:frosted_ice": {"cor": Color(0.7, 0.86, 1.0), "alfa": 0.8},
	&"minecraft:snow_block": {"cor": Color(0.96, 0.98, 1.0), "alfa": 1.0},
	&"minecraft:sand": {"cor": Color(0.86, 0.80, 0.55), "alfa": 1.0},
	&"minecraft:red_sand": {"cor": Color(0.70, 0.40, 0.20), "alfa": 1.0},
	&"minecraft:sandstone": {"cor": Color(0.82, 0.76, 0.56), "alfa": 1.0},
	&"minecraft:red_sandstone": {"cor": Color(0.68, 0.38, 0.18), "alfa": 1.0},
	&"minecraft:coarse_dirt": {"cor": Color(0.46, 0.34, 0.24), "alfa": 1.0},
	&"minecraft:rooted_dirt": {"cor": Color(0.50, 0.38, 0.28), "alfa": 1.0},
	&"minecraft:dirt": {"cor": Color(0.52, 0.38, 0.26), "alfa": 1.0},
	&"minecraft:stone": {"cor": Color(0.5, 0.5, 0.52), "alfa": 1.0},
	&"minecraft:cobblestone": {"cor": Color(0.45, 0.45, 0.47), "alfa": 1.0},
	&"minecraft:water": {"cor": Color(0.2, 0.4, 0.85), "alfa": 0.55},
	&"minecraft:lava": {"cor": Color(1.0, 0.45, 0.1), "alfa": 0.9, "brilho": 1.6},
	&"minecraft:fire": {"cor": Color(1.0, 0.55, 0.12), "alfa": 0.85, "brilho": 1.4},
	&"minecraft:soul_fire": {"cor": Color(0.3, 0.85, 1.0), "alfa": 0.85, "brilho": 1.4},
}
## Sem colisão (desenho só): líquidos e fogo.
const SEM_COLISAO: Array[StringName] = [&"minecraft:water", &"minecraft:lava", &"minecraft:fire", &"minecraft:soul_fire"]

var _mundo: McMundo
var _raiz: Node3D
var _celulas := {}                               # Vector3i → Dictionary
var _ordem: Array[Vector3i] = []                 # do mais antigo ao mais novo
var _malha: BoxMesh
var _forma: BoxShape3D
static var _materiais := {}


func _init(mundo: McMundo) -> void:
	_mundo = mundo


static func celula(pos: McVec3) -> Vector3i:
	return Vector3i(floori(pos.x), floori(pos.y), floori(pos.z))


## Este bloco é sólido (tem colisão e tapa a visão)? Tudo que não é ar, líquido ou fogo e tem estilo, ou a pedra.
static func e_solido(id: StringName) -> bool:
	return id != &"minecraft:air" and not (id in SEM_COLISAO) and ESTILO.has(id)


func tamanho() -> int: return _celulas.size()
## As células com bloco sobreposto dentro da caixa [a, b] (inclusive), em ordem x, y, z crescentes (a mesma das varreduras de cubo do mod).
func celulas_na_caixa(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	var saida: Array[Vector3i] = []
	for c: Vector3i in _celulas:
		if c.x >= a.x and c.x <= b.x and c.y >= a.y and c.y <= b.y and c.z >= a.z and c.z <= b.z:
			saida.append(c)
	saida.sort_custom(func(p: Vector3i, q: Vector3i) -> bool:
		if p.x != q.x:
			return p.x < q.x
		if p.y != q.y:
			return p.y < q.y
		return p.z < q.z)
	return saida


func id_em(c: Vector3i) -> StringName: return (_celulas[c] as Dictionary).id if _celulas.has(c) else &""


## Põe `id` na célula. `vida` em ticks (−1 = não expira). false se a camada não existe (sem árvore).
func colocar(c: Vector3i, id: StringName, vida := VIDA_PADRAO) -> bool:
	if _mundo == null or _mundo.arvore == null:
		return false
	if _celulas.has(c):
		remover(c)
	_garantir_raiz()
	var no := _criar_no(c, id)
	_raiz.add_child(no)
	_celulas[c] = {"id": id, "expira": (_mundo.tempo_de_jogo + vida) if vida >= 0 else -1, "no": no}
	_ordem.append(c)
	while _celulas.size() > MAX_CELULAS:
		remover(_ordem[0])
	return true


func remover(c: Vector3i) -> bool:
	if not _celulas.has(c):
		return false
	var no: Node3D = (_celulas[c] as Dictionary).no
	if is_instance_valid(no):
		no.queue_free()
	_celulas.erase(c)
	_ordem.erase(c)
	return true


## Um tick do mundo: o que passou da vida sai.
func tick(agora: int) -> void:
	if _celulas.is_empty():
		return
	var vencidas: Array[Vector3i] = []
	for c: Vector3i in _ordem:
		var e := (_celulas[c] as Dictionary).expira as int
		if e >= 0 and agora >= e:
			vencidas.append(c)
	for c in vencidas:
		remover(c)


func limpar() -> void:
	for c: Vector3i in _celulas.keys():
		remover(c)


func _garantir_raiz() -> void:
	if _raiz != null and is_instance_valid(_raiz):
		return
	_raiz = Node3D.new()
	_raiz.name = "BlocosDoMod"
	_mundo.arvore.root.add_child(_raiz)
	_malha = BoxMesh.new()
	_malha.size = Vector3.ONE * B
	_forma = BoxShape3D.new()
	_forma.size = Vector3.ONE * B


func _criar_no(c: Vector3i, id: StringName) -> Node3D:
	var no: Node3D
	var sem_colisao := id in SEM_COLISAO
	if sem_colisao:
		no = Node3D.new()
	else:
		var corpo := StaticBody3D.new()
		corpo.collision_layer = CAMADA_MUNDO
		corpo.collision_mask = 0
		var f := CollisionShape3D.new()
		f.shape = _forma
		corpo.add_child(f)
		no = corpo
	var m := MeshInstance3D.new()
	m.mesh = _malha
	m.material_override = material_de(id)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if sem_colisao else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	no.add_child(m)
	no.position = (Vector3(c) + Vector3.ONE * 0.5) * B
	no.set_meta("bloco_mc", id)
	return no


## Chama (fogo e fogo de alma): em vez do cubo laranja chapado, ruído que sobe, borda irregular e núcleo quente (13/11/2026, captura da Mera Mera).
const SHADER_CHAMA := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 cor_base : source_color = vec3(1.0, 0.45, 0.08);
uniform vec3 cor_nucleo : source_color = vec3(1.0, 0.9, 0.5);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float y = clamp(lp.y + 0.5, 0.0, 1.0);
	vec2 q = vec2((lp.x + lp.z) * 3.0, lp.y * 3.0 - TIME * 2.5);
	float n = ruido(q) * 0.65 + ruido(q * 2.3 + 7.0) * 0.35;
	float forma = smoothstep(0.0, 0.35, n - y * 0.75 + 0.25);
	float centro = 1.0 - length(vec2(lp.x, lp.z)) * 1.6;
	vec3 c = mix(cor_base, cor_nucleo, clamp(forma * (1.0 - y) * centro * 1.4, 0.0, 1.0));
	ALBEDO = c * 1.6;
	ALPHA = clamp(forma * 0.9, 0.0, 1.0);
}
"""


static func material_de(id: StringName) -> Material:
	if _materiais.has(id):
		return _materiais[id]
	if id == &"minecraft:fire" or id == &"minecraft:soul_fire":
		var sh := Shader.new()
		sh.code = SHADER_CHAMA
		var chama := ShaderMaterial.new()
		chama.shader = sh
		if id == &"minecraft:soul_fire":
			chama.set_shader_parameter("cor_base", Vector3(0.1, 0.55, 1.0))
			chama.set_shader_parameter("cor_nucleo", Vector3(0.7, 0.95, 1.0))
		_materiais[id] = chama
		return chama
	var est: Dictionary = ESTILO.get(id, {"cor": Color(0.55, 0.55, 0.58), "alfa": 1.0})
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(est.cor.r, est.cor.g, est.cor.b, est.alfa)
	if float(est.alfa) < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if est.has("brilho"):
		mat.emission_enabled = true
		mat.emission = est.cor
		mat.emission_energy_multiplier = float(est.brilho)
	_materiais[id] = mat
	return mat
