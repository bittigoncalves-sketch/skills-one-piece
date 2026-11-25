extends Node3D
## AURA DE LENTIDÃO (06/10/2026) — a leitura de "tempo esticado" da Noro Noro no Mi.
##
## Direção escolhida pelo dono: FÓTONS CINTILANTES. Em quem está lento:
##   • cintilas rosa/lilás orbitando DEVAGAR o corpo, piscando em fases diferentes;
##   • um RASTRO FANTASMA: a cada 0,3 s, uma cópia translúcida lilás do corpo fica para
##     trás e desbota — o corpo lento deixa ecos de si mesmo.
## Some sozinha (com fade) quando a lentidão acaba. Fica filha do corpo, então anda com
## ele; os fantasmas vão para o mundo (não andam junto). Corpo skinnado (animal de malha
## única) só ganha as cintilas: copiar a malha skinnada mostraria a pose de repouso.

const ROSA := Color(1.0, 0.48, 0.85)
const LILAS := Color(0.71, 0.55, 1.0)
const CINTILAS := 12
const ORBITA_RAD_S := 0.9          # devagar: é a fruta da lentidão
const FANTASMA_A_CADA := 0.3
const FANTASMA_VIDA := 0.7
const MAX_FANTASMAS := 3

static var _textura: ImageTexture = null

var _cintilas: Array[MeshInstance3D] = []
var _fases: Array[float] = []
var _t := 0.0
var _proximo_fantasma := 0.0
var _saindo := 0.0                 # > 0 = desbotando para sumir
var _altura := 1.8


func _ready() -> void:
	var corpo := get_parent() as Node3D
	if corpo != null and corpo.has_method("centro_do_corpo"):
		_altura = maxf(0.8, (corpo.call("centro_do_corpo") - corpo.global_position).y * 2.0)
	var mat := material_de_cintila()
	for i in CINTILAS:
		var q := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE * 0.22
		q.mesh = quad
		var m := mat.duplicate() as StandardMaterial3D
		m.albedo_color = ROSA.lerp(LILAS, float(i % 3) / 2.0)
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		_cintilas.append(q)
		_fases.append(float(i) * 2.399)       # ângulo áureo: espalha sem repetir


func _process(delta: float) -> void:
	_t += delta
	var corpo := get_parent() as Node3D
	if corpo == null:
		return
	var vivo := Lentidao.fator_proprio(corpo) < 1.0
	if not vivo and _saindo <= 0.0:
		_saindo = 0.35
	var alpha := 1.0
	if _saindo > 0.0:
		_saindo -= delta
		alpha = clampf(_saindo / 0.35, 0.0, 1.0)
		if _saindo <= 0.0:
			queue_free()
			return
	var base_y := 0.0 if corpo.has_method("centro_do_corpo") else -_altura * 0.45
	for i in _cintilas.size():
		var f := _fases[i]
		var ang := f + _t * ORBITA_RAD_S * (1.0 if i % 2 == 0 else -0.7)
		var raio := 0.55 + 0.12 * sin(f * 3.0 + _t * 0.8)
		var y := base_y + fmod(f * 0.37 + _t * 0.18, 1.0) * _altura
		_cintilas[i].position = Vector3(cos(ang) * raio, y, sin(ang) * raio)
		var pisca := 0.55 + 0.45 * sin(_t * 3.1 + f * 5.0)
		_cintilas[i].scale = Vector3.ONE * (0.6 + 0.6 * pisca)
		(_cintilas[i].material_override as StandardMaterial3D).albedo_color.a = alpha * (0.4 + 0.6 * pisca)
	if vivo and _t >= _proximo_fantasma:
		_proximo_fantasma = _t + FANTASMA_A_CADA
		_deixar_fantasma(corpo)


## Uma cópia translúcida das malhas NÃO skinnadas do corpo, parada no mundo, desbotando.
func _deixar_fantasma(corpo: Node3D) -> void:
	var mundo := corpo.get_tree().current_scene
	if mundo == null or _contar_fantasmas(mundo) >= MAX_FANTASMAS * 4:
		return
	var eco := Node3D.new()
	eco.name = "FantasmaDeLentidao"
	eco.set_meta("fantasma_de", corpo.get_instance_id())
	mundo.add_child(eco)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(LILAS.r, LILAS.g, LILAS.b, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	var n := 0
	for m in corpo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_visible_in_tree() or mi.skin != null \
				or mi.get_parent() == self or mi.is_ancestor_of(self) or self.is_ancestor_of(mi):
			continue
		var copia := MeshInstance3D.new()
		copia.mesh = mi.mesh
		copia.material_override = mat
		copia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eco.add_child(copia)
		copia.global_transform = mi.global_transform
		n += 1
		if n >= 64:
			break
	if n == 0:
		eco.queue_free()
		return
	var tw := eco.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, FANTASMA_VIDA)
	tw.tween_callback(eco.queue_free)


static func _contar_fantasmas(mundo: Node) -> int:
	var n := 0
	for c in mundo.get_children():
		if c.name.begins_with("FantasmaDeLentidao"):
			n += 1
	return n


## Material das cintilas: quad virado para a câmera, aditivo, com a textura de estrela.
static func material_de_cintila() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = textura_de_cintila()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Estrela de quatro pontas com miolo redondo (64×64), gerada uma vez.
static func textura_de_cintila() -> ImageTexture:
	if _textura != null:
		return _textura
	var tam := 64
	var img := Image.create(tam, tam, false, Image.FORMAT_RGBA8)
	var c := (tam - 1) * 0.5
	for y in tam:
		for x in tam:
			var dx := (x - c) / c
			var dy := (y - c) / c
			var r := sqrt(dx * dx + dy * dy)
			var miolo := clampf(1.0 - r * 2.2, 0.0, 1.0)
			var raio_h := clampf(1.0 - absf(dy) * 14.0, 0.0, 1.0) * clampf(1.0 - absf(dx), 0.0, 1.0)
			var raio_v := clampf(1.0 - absf(dx) * 14.0, 0.0, 1.0) * clampf(1.0 - absf(dy), 0.0, 1.0)
			var a := clampf(miolo * miolo + (raio_h + raio_v) * 0.85, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_textura = ImageTexture.create_from_image(img)
	return _textura
