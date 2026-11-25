extends Node3D
## Pool local de impactos, rastros, manchas, retículos e estilhaços. Só existe enquanto
## a Rocket age.
##
## PALETA MEDIDA no vídeo do dono (ffmpeg palettegen nos quadros de explosão, 21/09/2026,
## registrada em docs/frutas/rocket.md). Antes daqui o efeito tinha duas cores inventadas;
## FOGO e NUCLEO agora apontam para os tons medidos mais próximos — a arena muda de tom
## por alguns pontos, não de linguagem.
const PRETO := Color(0.020, 0.004, 0.008)    # 050102 — estilhaço e mancha
const FUMACA := Color(0.173, 0.043, 0.043)   # 2C0B0B
const VERMELHO := Color(0.569, 0.122, 0.110) # 911F1C
const BRASA := Color(0.890, 0.251, 0.188)    # E34030
const FOGO := Color(0.949, 0.631, 0.282)     # F2A148
const AMARELO := Color(0.988, 0.820, 0.235)  # FCD13C
const CLARAO := Color(0.965, 0.949, 0.353)   # F6F25A
const CREME := Color(0.929, 0.890, 0.784)    # EDE3C8 — o anel claro do vídeo
const NUCLEO := AMARELO
## Quanto tempo cada camada nova vive.
const MANCHA_VIDA := 7.0
const ESTILHACO_VIDA := 0.85
const PILAR_VIDA := 0.55
## Âncora invisível que segue o antebraço: é onde o foguete do Z fica NA MÃO no preparo.
## Até 30/09/2026 ela carregava dois bocais metálicos com fogo, fumaça e luz — o
## "escapamento" que aparecia acima da cabeça em QUALQUER golpe. Removidos nos dois modos
## (decisão do dono, 30/09/2026); a âncora ficou porque o foguete na mão depende dela.
var _ancora: Node3D
var _impactos: Array[Dictionary] = []
var _rastro: MultiMeshInstance3D
var _tracos: Array[Dictionary] = []
var _cursor := 0
var _tempo := 0.0
var _manchas: Array[Dictionary] = []
var _cursor_mancha := 0
var _reticulos: Array[Dictionary] = []
var _cursor_reticulo := 0
var _estilhacos: MultiMeshInstance3D
var _cacos: Array[Dictionary] = []
var _pilar: Node3D
var _pilar_chama: MeshInstance3D
var _pilar_anel: MeshInstance3D
var _pilar_mat: StandardMaterial3D
var _pilar_t := 9.0
var _pilar_raio := 1.0
## O foguete: a mesma malha fica no braço durante o preparo e depois voa.
var _missil: Node3D
var _missil_de := Vector3.ZERO
var _missil_ate := Vector3.ZERO
var _missil_t := -1.0
var _missil_dur := 0.0
var _missil_gasto := false
## A chama do foguete do Z só acende no DISPARO. Na mão, acesa, ela ficava na altura da
## cabeça durante o preparo — o mesmo "fogo acima da cabeça" que o dono pediu para tirar
## (30/09/2026). Apagada no preparo, acender vira o sinal de que saiu.
var _missil_chama: Node3D

func _ready() -> void:
	add_to_group("rocket_vfx")
	_ancora = Node3D.new()
	add_child(_ancora)
	var esfera := SphereMesh.new()
	esfera.radius = 0.5
	esfera.height = 1.0
	esfera.radial_segments = 20
	esfera.rings = 10
	var anel := TorusMesh.new()
	anel.inner_radius = 0.85
	anel.outer_radius = 1.0
	anel.rings = 40
	anel.ring_segments = 8
	for _i in 6:
		var raiz := Node3D.new()
		add_child(raiz)
		var bola := MeshInstance3D.new()
		bola.mesh = esfera
		var mat := FxUtil.mesh_emissive_material(NUCLEO, 2.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bola.material_override = mat
		bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(bola)
		var onda := MeshInstance3D.new()
		onda.mesh = anel
		onda.material_override = mat
		onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(onda)
		raiz.visible = false
		_impactos.append({"raiz": raiz, "bola": bola, "onda": onda, "mat": mat,
			"t": 2.0, "raio": 1.0})
	_rastro = MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var haste := CylinderMesh.new()
	haste.top_radius = 0.035
	haste.bottom_radius = 0.10
	haste.height = 1.0
	haste.radial_segments = 8
	multi.mesh = haste
	multi.instance_count = 8
	_rastro.multimesh = multi
	var mat_trilha := FxUtil.mesh_emissive_material(FOGO, 2.0)
	mat_trilha.vertex_color_use_as_albedo = true
	mat_trilha.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rastro.material_override = mat_trilha
	_rastro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rastro)
	for i in 8:
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO))
		_tracos.append({"t": 2.0, "de": Vector3.ZERO, "ate": Vector3.ZERO})
	_montar_manchas()
	_montar_reticulos()
	_montar_estilhacos()
	_montar_pilar()
	_montar_missil()


## Mancha preta no chão: no vídeo ela FICA depois da explosão, é o que dá peso ao X.
func _montar_manchas() -> void:
	var disco := CylinderMesh.new()
	disco.top_radius = 1.0
	disco.bottom_radius = 1.0
	disco.height = 0.02
	disco.radial_segments = 22
	for _i in 8:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = PRETO
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var m := MeshInstance3D.new()
		m.mesh = disco
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_manchas.append({"no": m, "mat": mat, "t": MANCHA_VIDA + 1.0})


## Retículo do Air Strike: círculo com ponto no centro, vermelho, no chão, ANTES da
## explosão. Era o mesmo par esfera+traço de qualquer impacto — não avisava nada.
func _montar_reticulos() -> void:
	var aro := TorusMesh.new()
	aro.inner_radius = 0.86
	aro.outer_radius = 1.0
	aro.rings = 28
	aro.ring_segments = 6
	var ponto := CylinderMesh.new()
	ponto.top_radius = 0.16
	ponto.bottom_radius = 0.16
	ponto.height = 0.03
	ponto.radial_segments = 14
	for _i in 4:
		var raiz := Node3D.new()
		add_child(raiz)
		var mat := FxUtil.mesh_emissive_material(BRASA, 2.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for malha in [aro, ponto]:
			var m := MeshInstance3D.new()
			m.mesh = malha
			m.material_override = mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			raiz.add_child(m)
		raiz.visible = false
		_reticulos.append({"raiz": raiz, "mat": mat, "t": 9.0, "dur": 0.2, "raio": 1.0})


## Estilhaços pretos serrilhados tipo tinta — a marca visual da fruta no vídeo.
func _montar_estilhacos() -> void:
	_estilhacos = MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	var caco := PrismMesh.new()
	caco.size = Vector3(0.14, 0.34, 0.06)
	multi.mesh = caco
	multi.instance_count = 24
	_estilhacos.multimesh = multi
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = PRETO
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_estilhacos.material_override = mat
	_estilhacos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_estilhacos)
	for i in 24:
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3.ZERO))
		multi.set_instance_color(i, Color(PRETO, 0.0))
		_cacos.append({"t": ESTILHACO_VIDA + 1.0, "pos": Vector3.ZERO, "vel": Vector3.ZERO,
			"giro": Vector3.ZERO, "esc": 1.0})


## Pilar vertical de chamas do Rocket Crash, com o anel claro no chão.
func _montar_pilar() -> void:
	_pilar = Node3D.new()
	add_child(_pilar)
	var coluna := CylinderMesh.new()
	coluna.top_radius = 0.30
	coluna.bottom_radius = 1.0
	coluna.height = 1.0
	coluna.radial_segments = 20
	_pilar_mat = FxUtil.mesh_emissive_material(BRASA, 3.2)
	_pilar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pilar_chama = MeshInstance3D.new()
	_pilar_chama.mesh = coluna
	_pilar_chama.material_override = _pilar_mat
	_pilar_chama.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pilar.add_child(_pilar_chama)
	var anel := TorusMesh.new()
	anel.inner_radius = 0.90
	anel.outer_radius = 1.0
	anel.rings = 32
	anel.ring_segments = 6
	var mat_anel := FxUtil.mesh_emissive_material(CREME, 2.4)
	mat_anel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pilar_anel = MeshInstance3D.new()
	_pilar_anel.mesh = anel
	_pilar_anel.material_override = mat_anel
	_pilar_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pilar.add_child(_pilar_anel)
	_pilar.visible = false


## O foguete em si: ogiva, corpo e três aletas. No vídeo ele é um OBJETO — aparece na mão
## e depois cruza o cenário; aqui era só uma chama de partículas presa ao antebraço.
func _montar_missil() -> void:
	_missil = Node3D.new()
	add_child(_missil)
	var casco := StandardMaterial3D.new()
	casco.albedo_color = VERMELHO
	casco.metallic = 0.35
	casco.roughness = 0.45
	var corpo := CapsuleMesh.new()
	corpo.radius = 0.11
	corpo.height = 0.52
	corpo.radial_segments = 14
	var m_corpo := MeshInstance3D.new()
	m_corpo.mesh = corpo
	m_corpo.material_override = casco
	m_corpo.rotation.x = PI * 0.5
	_missil.add_child(m_corpo)
	var ogiva := CylinderMesh.new()
	ogiva.top_radius = 0.0
	ogiva.bottom_radius = 0.11
	ogiva.height = 0.22
	ogiva.radial_segments = 14
	var m_ogiva := MeshInstance3D.new()
	m_ogiva.mesh = ogiva
	m_ogiva.material_override = FxUtil.mesh_emissive_material(CREME, 0.6)
	m_ogiva.rotation.x = PI * 0.5
	m_ogiva.position.z = 0.37
	_missil.add_child(m_ogiva)
	var aleta := BoxMesh.new()
	aleta.size = Vector3(0.02, 0.13, 0.14)
	var escuro := StandardMaterial3D.new()
	escuro.albedo_color = PRETO
	for i in 3:
		var a := MeshInstance3D.new()
		a.mesh = aleta
		a.material_override = escuro
		a.position = Vector3(0, 0, -0.22).rotated(Vector3.FORWARD, TAU * i / 3.0)
		a.position += Vector3(0.0, 0.10, 0.0).rotated(Vector3.FORWARD, TAU * i / 3.0)
		a.rotation.z = TAU * i / 3.0
		_missil.add_child(a)
	var chama := MeshInstance3D.new()
	chama.mesh = FxUtil.grain(0.26)
	chama.material_override = FxUtil.mesh_emissive_material(AMARELO, 3.0)
	chama.position.z = -0.34
	_missil.add_child(chama)
	_missil_chama = chama
	_missil.visible = false

## Retículo no chão, `dur` segundos antes da explosão chegar.
func reticulo(at: Vector3, dur: float, raio: float = 1.0, normal: Vector3 = Vector3.UP) -> void:
	var item: Dictionary = _reticulos[_cursor_reticulo % _reticulos.size()]
	_cursor_reticulo += 1
	item.t = 0.0
	item.dur = maxf(0.05, dur)
	item.raio = raio
	item.raiz.global_position = at + Vector3.UP * 0.03
	item.raiz.basis = _base_do_chao(normal)
	item.raiz.visible = true
	AudioFX.snap(self, at, 1.9)


## A mancha preta que fica. Só faz sentido em superfície voltada para cima.
func mancha(at: Vector3, raio: float, normal: Vector3 = Vector3.UP) -> void:
	var item: Dictionary = _manchas[_cursor_mancha % _manchas.size()]
	_cursor_mancha += 1
	item.t = 0.0
	item.no.global_position = at + normal.normalized() * 0.02
	item.no.basis = _base_do_chao(normal).scaled(Vector3(raio, 1.0, raio))
	item.no.visible = true


## Estilhaços pretos saindo do ponto do impacto.
func estilhacos(at: Vector3, raio: float, normal: Vector3 = Vector3.UP) -> void:
	var cima := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	for item in _cacos:
		item.t = 0.0
		item.pos = at
		var dir := (cima + Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2),
				randf_range(-1, 1))).normalized()
		item.vel = dir * randf_range(3.5, 7.0) * clampf(raio, 0.6, 3.0)
		item.giro = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		item.esc = randf_range(0.55, 1.3)


## Pilar vertical de chamas: o fim do Rocket Crash no vídeo.
func pilar(at: Vector3, raio: float) -> void:
	_pilar_t = 0.0
	_pilar_raio = maxf(0.5, raio)
	_pilar.global_position = at
	_pilar.visible = true
	AudioFX.cannon(self, at, 0.7)


## O foguete sai do braço e cruza até `ate`. Some sozinho ao chegar, ou antes, quando a
## explosão dele avisa (`impacto`).
func missil_disparar(de: Vector3, ate: Vector3, velocidade: float) -> void:
	_missil_de = de
	_missil_ate = ate
	_missil_dur = maxf(0.02, de.distance_to(ate) / maxf(1.0, velocidade))
	_missil_t = 0.0
	_missil_gasto = true
	AudioFX.cannon(self, de, 1.25)
	AudioFX.whoosh(self, de, 0.8)


func _base_do_chao(normal: Vector3) -> Basis:
	var cima := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var eixo := Vector3.RIGHT if absf(cima.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := eixo.cross(cima).normalized()
	return Basis(cima.cross(z), cima, z)


func impacto(at: Vector3, raio: float, normal: Vector3 = Vector3.UP) -> void:
	var item: Dictionary = _impactos[_cursor % _impactos.size()]
	_cursor += 1
	item.t = 0.0
	item.raio = raio
	item.raiz.global_position = at
	var cima := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	var eixo := Vector3.RIGHT if absf(cima.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var z := eixo.cross(cima).normalized()
	item.raiz.basis = Basis(cima.cross(z), cima, z)
	item.raiz.visible = true
	AudioFX.impact(self, at, 0.75 if raio > 3 else 1.25)
	# Toda explosão joga estilhaço; a mancha só fica quando o chão recebeu o golpe
	# (X e C explodem no chão, o míssil do Z explode no alvo).
	if raio > 0.5:
		estilhacos(at, raio, normal)
		if normal.normalized().dot(Vector3.UP) > 0.8:
			mancha(at, raio * 1.15, normal)
	_missil_t = -1.0
	_missil.visible = false

func traco(de: Vector3, ate: Vector3, indice: int) -> void:
	var item: Dictionary = _tracos[indice % 8]
	item.t = 0.0
	item.de = de
	item.ate = ate

func atualizar(delta: float, ator: Node3D, pose: String) -> void:
	_tempo += delta
	_ancora.global_position = ator.global_position + Vector3.UP * 0.55
	var modelo: Node3D = ator.get("_char_model")
	if is_instance_valid(modelo): _ancora.global_basis = modelo.global_basis.orthonormalized()
	# Durante o soco (arena) e o Missile Fist (história) a âncora segue o antebraço real:
	# é dali que o foguete sai, nunca de um projétil solto no ar.
	if pose in ["rocket_z", "rocket_missil"] and is_instance_valid(ator.get("_proc_anim")):
		var nos: Dictionary = ator._proc_anim.get("_n")
		if nos.has("ForeArm_R") and is_instance_valid(nos.ForeArm_R):
			_ancora.global_position = nos.ForeArm_R.global_position
	for item in _impactos:
		item.t += delta
		var f: float = clampf(item.t / 0.52, 0, 1)
		item.raiz.visible = f < 1
		item.bola.scale = Vector3.ONE * maxf(0.01, item.raio * 1.35 * sin(f * PI))
		item.onda.scale = Vector3(1, 0.3, 1) * maxf(0.01, item.raio * (0.15 + 0.85 * f))
		item.mat.albedo_color.a = (1.0 - f) * 0.65
	for i in _tracos.size():
		var item: Dictionary = _tracos[i]
		item.t += delta
		var f: float = clampf(item.t / 0.22, 0, 1)
		var caminho: Vector3 = item.ate - item.de
		var b := Basis.IDENTITY
		if caminho.length_squared() > 0.001:
			b = Basis(Quaternion(Vector3.UP, caminho.normalized()))
		b = b.scaled(Vector3(maxf(0.001, 1-f), maxf(0.001, caminho.length()), maxf(0.001, 1-f)))
		_rastro.multimesh.set_instance_transform(i, Transform3D(b, (item.de + item.ate) * 0.5))
		_rastro.multimesh.set_instance_color(i, Color(FOGO, 1 - f))
	_atualizar_extras(delta, ator, pose)


## As camadas novas (23/09/2026): foguete na mão e voando, estilhaços, manchas,
## retículos e o pilar do C. Tudo por tempo, sem `SceneTreeTimer`.
func _atualizar_extras(delta: float, ator: Node3D, pose: String) -> void:
	if pose != "rocket_missil":
		_missil_gasto = false
	if _missil_t >= 0.0:
		_missil_t += delta
		var f: float = clampf(_missil_t / _missil_dur, 0, 1)
		_missil.global_position = _missil_de.lerp(_missil_ate, f)
		var caminho := _missil_ate - _missil_de
		if caminho.length_squared() > 0.001:
			_missil.look_at(_missil.global_position + caminho.normalized(), Vector3.UP)
		_missil.visible = true
		_missil_chama.visible = true
		if f >= 1.0:
			_missil_t = -1.0
			_missil.visible = false
	elif pose == "rocket_missil" and not _missil_gasto:
		# Antes do disparo o foguete fica NA MÃO: `_ancora` já segue o antebraço real.
		_missil.global_position = _ancora.global_position + Vector3.UP * 0.12
		_missil.global_basis = _ancora.global_basis.rotated(
				_ancora.global_basis.x.normalized(), deg_to_rad(38.0))
		_missil.visible = true
		_missil_chama.visible = false
	elif _missil.visible and pose != "rocket_missil":
		_missil.visible = false

	for i in _cacos.size():
		var caco: Dictionary = _cacos[i]
		if caco.t > ESTILHACO_VIDA:
			continue
		caco.t += delta
		caco.vel += Vector3.DOWN * 16.0 * delta
		caco.pos += caco.vel * delta
		var f: float = clampf(caco.t / ESTILHACO_VIDA, 0, 1)
		var giro: Vector3 = caco.giro * caco.t
		var b := Basis.from_euler(giro).scaled(Vector3.ONE * caco.esc * (1.0 - f * 0.45))
		_estilhacos.multimesh.set_instance_transform(i, Transform3D(b, caco.pos))
		_estilhacos.multimesh.set_instance_color(i, Color(PRETO, 1.0 - f))

	for item in _manchas:
		if item.t > MANCHA_VIDA:
			continue
		item.t += delta
		var f: float = clampf(item.t / MANCHA_VIDA, 0, 1)
		item.mat.albedo_color = Color(PRETO, 0.78 * (1.0 - f * f))
		item.no.visible = f < 1.0

	for item in _reticulos:
		if item.t > item.dur:
			continue
		item.t += delta
		var f: float = clampf(item.t / item.dur, 0, 1)
		# Pisca mais rápido perto da hora — é o aviso, não um enfeite.
		var pulso: float = 0.55 + 0.45 * absf(sin(f * PI * 4.0))
		item.raiz.scale = Vector3.ONE * item.raio * (1.0 - 0.18 * f)
		item.mat.albedo_color = Color(BRASA, pulso)
		item.raiz.visible = f < 1.0

	if _pilar_t <= PILAR_VIDA:
		_pilar_t += delta
		var f: float = clampf(_pilar_t / PILAR_VIDA, 0, 1)
		var altura: float = _pilar_raio * (1.2 + 5.2 * sqrt(f))
		_pilar_chama.scale = Vector3(_pilar_raio * (1.0 - 0.45 * f), altura, _pilar_raio * (1.0 - 0.45 * f))
		_pilar_chama.position.y = altura * 0.5
		_pilar_mat.albedo_color = Color(BRASA.lerp(AMARELO, f), 0.9 * (1.0 - f))
		_pilar_anel.scale = Vector3.ONE * _pilar_raio * (0.5 + 1.4 * f)
		_pilar.visible = f < 1.0
