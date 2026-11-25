extends Node3D
## FORMA DE FOGUETE — no Blast Off (F, Modo História) o jogador VIRA o foguete.
##
## Decisão do dono (30/09/2026): o corpo some e um foguete do tamanho dele assume, do
## impulso até tocar o chão; puff de fumaça ao entrar e ao sair. Golpe no ar desfaz a
## forma (quem decide é o `VooFoguete`, não este nó).
##
## Só APRESENTAÇÃO: não lê tecla, não escreve velocidade, não tem colisão. O Player
## cria este nó quando `VooFoguete.forma_de_foguete()` liga e chama `encerrar()` quando
## desliga — estado derivado, sem caminho em que o corpo fique escondido.
##
## Mesma linguagem do foguete do Z (`rocket_vfx.gd`: casco VERMELHO, ogiva CREME, aletas
## PRETAS), em escala de corpo — o jogador vira o próprio míssil. Materiais com luz de
## verdade no casco; só a chama é emissiva. Nariz em −Z (a frente do Godot).
const RVFX := preload("res://src/effects/rocket_vfx.gd")

const RAIO := 0.26
const CORPO := 1.05
## Quanto o foguete inclina nas curvas (rad por rad/s de giro) e o limite disso: é o que
## faz o jogador LER que a curva está acontecendo.
const INCLINACAO_POR_GIRO := 0.30
const INCLINACAO_MAXIMA := 0.65

var _casco: Node3D
var _chama: Node3D
var _nucleo: MeshInstance3D
var _envelope: MeshInstance3D
var _luz: OmniLight3D
var _fumaca: GPUParticles3D
var _brasas: GPUParticles3D
var _frente := Vector3.UP
var _rumo_plano := Vector3.FORWARD
var _inclinacao := 0.0
var _tempo := 0.0
var _primeiro_quadro := true
## Disco macio para a fumaça: sem ele cada partícula é um quadrado duro (medido na
## captura de 30/09/2026). Uma instância só, compartilhada.
static var _textura_fumaca: GradientTexture2D


func _ready() -> void:
	_casco = Node3D.new()
	_casco.name = "Casco"
	add_child(_casco)
	_montar_casco()
	_montar_chama()
	global_basis = _base(_frente)
	_puff(global_position + Vector3.DOWN * 0.6, 1.0)


## `velocidade` é a do corpo neste quadro; `pousando` põe o foguete de pé sobre a chama.
func atualizar(delta: float, velocidade: Vector3, pousando: bool) -> void:
	_tempo += delta
	var plano := Vector3(velocidade.x, 0.0, velocidade.z)
	var giro := 0.0
	if plano.length_squared() > 0.25:
		var novo := plano.normalized()
		# Sinal do giro pelo eixo de cima: positivo = curva à esquerda. No 1º quadro o
		# rumo anterior não existe — medir ali daria um tranco de inclinação.
		if not _primeiro_quadro:
			giro = _rumo_plano.signed_angle_to(novo, Vector3.UP) / maxf(delta, 0.001)
		_rumo_plano = novo
	_primeiro_quadro = false
	var alvo := _frente
	if pousando:
		# Retrofoguete: nariz para cima, levemente contra o movimento (freando).
		alvo = (Vector3.UP - plano * 0.06).normalized()
	elif velocidade.length_squared() > 0.25:
		alvo = velocidade.normalized()
	# O nariz acompanha rápido: a trajetória já é contínua (o voo faz arco na virada), a
	# suavização aqui só tira tremida — com 10/s ele ficava 36° atrasado no arco.
	_frente = _aproximar(_frente, alvo, 1.0 - exp(-20.0 * delta))
	_inclinacao = lerpf(_inclinacao,
			clampf(giro * INCLINACAO_POR_GIRO, -INCLINACAO_MAXIMA, INCLINACAO_MAXIMA),
			1.0 - exp(-8.0 * delta))
	# De pé o bocal ficaria 0,3 m dentro do chão (a origem do corpo é o centro do
	# colisor): sobe junto com a verticalidade. Filho do corpo, a posição segue sozinha;
	# a orientação é de mundo, porque quem gira o corpo não é o foguete.
	position = Vector3.UP * 0.3 * absf(_frente.y)
	global_basis = _base(_frente) * Basis(Vector3.BACK, _inclinacao)
	# A chama respira: comprimento e largura tremem um pouco, mais longa acelerando.
	var forca := 1.25 if velocidade.y > 6.0 else (0.8 if pousando else 1.0)
	var tremor := 1.0 + 0.12 * sin(_tempo * 43.0) + 0.07 * sin(_tempo * 71.0)
	_chama.scale = Vector3(1.0 + 0.05 * sin(_tempo * 57.0), 1.0 + 0.05 * sin(_tempo * 57.0),
			forca * tremor)
	_luz.light_energy = 1.4 * forca * tremor


## A forma acabou: puff no lugar e some. O rastro que já saiu fica no mundo e se desfaz
## no tempo dele — sem isto a fumaça inteira sumiria no mesmo quadro do foguete.
func encerrar() -> void:
	_puff(global_position, 1.2)
	var mundo := FxUtil.mundo_de_skills(get_parent())
	if mundo != null and mundo.is_inside_tree():
		for p in [_fumaca, _brasas]:
			p.emitting = false
			p.reparent(mundo)
			FxUtil.autofree(p, p.lifetime + 0.2)
	queue_free()


## Olhando para `frente` (nariz = −Z). Na vertical o "cima" do foguete é o de trás do
## rumo — assim a escotilha encara a câmera na decolagem e não há salto de base quando o
## nariz deita (a projeção do UP já aponta para trás do rumo).
func _base(frente: Vector3) -> Basis:
	var cima := Vector3.UP
	if absf(frente.dot(cima)) > 0.98:
		cima = -_rumo_plano
	return Basis.looking_at(frente, cima)


## Gira `de` uma fração `peso` do ângulo até `para`. Não usa `Vector3.slerp`: com os dois
## quase opostos o eixo interno dele sai fora da norma e o Godot enche o log de "axis must
## be normalized" (medido: 38 erros numa rodada da suíte, 30/09/2026).
static func _aproximar(de: Vector3, para: Vector3, peso: float) -> Vector3:
	var angulo := de.angle_to(para)
	if angulo < 0.0001:
		return para
	var eixo := de.cross(para)
	if eixo.length_squared() < 0.000001:
		# De costas: qualquer eixo perpendicular serve.
		eixo = Vector3.RIGHT if absf(de.x) < 0.9 else Vector3.FORWARD
		eixo -= de * eixo.dot(de)
	return de.rotated(eixo.normalized(), angulo * peso).normalized()


func _montar_casco() -> void:
	var tinta := StandardMaterial3D.new()
	tinta.albedo_color = RVFX.VERMELHO.lightened(0.12)
	tinta.metallic = 0.35
	tinta.roughness = 0.38
	var creme := StandardMaterial3D.new()
	creme.albedo_color = RVFX.CREME
	creme.metallic = 0.2
	creme.roughness = 0.3
	var preto := StandardMaterial3D.new()
	preto.albedo_color = Color(0.06, 0.05, 0.06)
	preto.metallic = 0.6
	preto.roughness = 0.35
	var aco := StandardMaterial3D.new()
	aco.albedo_color = Color(0.20, 0.21, 0.23)
	aco.metallic = 0.85
	aco.roughness = 0.25

	var corpo := CylinderMesh.new()
	corpo.top_radius = RAIO
	corpo.bottom_radius = RAIO
	corpo.height = CORPO
	corpo.radial_segments = 32
	_peca(corpo, tinta, Vector3.ZERO, Vector3(PI * 0.5, 0, 0))

	# Ogiva: meio elipsoide saindo da boca do corpo (a outra metade fica escondida nele).
	var ogiva := SphereMesh.new()
	ogiva.radius = RAIO
	ogiva.height = 1.1
	ogiva.radial_segments = 32
	ogiva.rings = 16
	_peca(ogiva, creme, Vector3(0, 0, -CORPO * 0.5), Vector3(PI * 0.5, 0, 0))

	# Faixas pretas: base da ogiva e perto das aletas.
	var faixa := CylinderMesh.new()
	faixa.top_radius = RAIO + 0.012
	faixa.bottom_radius = RAIO + 0.012
	faixa.height = 0.07
	faixa.radial_segments = 32
	for z in [-CORPO * 0.5 + 0.05, CORPO * 0.5 - 0.30]:
		_peca(faixa, preto, Vector3(0, 0, z), Vector3(PI * 0.5, 0, 0))

	# Escotilha em cima: aro creme e vidro escuro — o lugar onde "está" o jogador.
	var aro := TorusMesh.new()
	aro.inner_radius = 0.075
	aro.outer_radius = 0.105
	aro.rings = 24
	aro.ring_segments = 10
	_peca(aro, creme, Vector3(0, RAIO - 0.005, -0.12), Vector3.ZERO)
	var vidro := StandardMaterial3D.new()
	vidro.albedo_color = Color(0.07, 0.11, 0.17)
	vidro.metallic = 0.3
	vidro.roughness = 0.06
	var lente := SphereMesh.new()
	lente.radius = 0.08
	lente.height = 0.07
	lente.radial_segments = 20
	lente.rings = 8
	_peca(lente, vidro, Vector3(0, RAIO - 0.01, -0.12), Vector3.ZERO)

	# Quatro aletas em X, varridas para trás (a borda alta fica na cauda).
	var aleta := PrismMesh.new()
	aleta.left_to_right = 1.0
	aleta.size = Vector3(0.42, 0.30, 0.035)
	for i in 4:
		var eixo := Node3D.new()
		eixo.rotation.z = PI * 0.25 + PI * 0.5 * float(i)
		_casco.add_child(eixo)
		var m := MeshInstance3D.new()
		m.mesh = aleta
		m.material_override = preto
		m.position = Vector3(0, RAIO + 0.15, CORPO * 0.5 - 0.2)
		m.rotation.y = -PI * 0.5
		eixo.add_child(m)

	# Bocal: a boca larga para trás.
	var bocal := CylinderMesh.new()
	bocal.top_radius = RAIO * 0.85
	bocal.bottom_radius = RAIO * 0.6
	bocal.height = 0.22
	bocal.radial_segments = 28
	_peca(bocal, aco, Vector3(0, 0, CORPO * 0.5 + 0.11), Vector3(PI * 0.5, 0, 0))


func _peca(malha: Mesh, material: Material, posicao: Vector3, giro: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = malha
	m.material_override = material
	m.position = posicao
	m.rotation = giro
	_casco.add_child(m)
	return m


func _montar_chama() -> void:
	# `_chama` fica na boca do bocal e escala em Z: a chama cresce PARA TRÁS a partir dali.
	_chama = Node3D.new()
	_chama.position = Vector3(0, 0, CORPO * 0.5 + 0.22)
	add_child(_chama)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = RAIO * 0.78
	cone.height = 0.95
	cone.radial_segments = 20
	_envelope = MeshInstance3D.new()
	_envelope.mesh = cone
	var fogo := FxUtil.mesh_emissive_material(RVFX.FOGO, 2.2)
	fogo.albedo_color.a = 0.75
	_envelope.material_override = fogo
	_envelope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_envelope.rotation.x = PI * 0.5
	_envelope.position.z = 0.95 * 0.5
	_chama.add_child(_envelope)
	var miolo := CylinderMesh.new()
	miolo.top_radius = 0.0
	miolo.bottom_radius = RAIO * 0.42
	miolo.height = 0.5
	miolo.radial_segments = 16
	_nucleo = MeshInstance3D.new()
	_nucleo.mesh = miolo
	_nucleo.material_override = FxUtil.mesh_emissive_material(RVFX.CLARAO, 3.2)
	_nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nucleo.rotation.x = PI * 0.5
	_nucleo.position.z = 0.25
	_chama.add_child(_nucleo)

	_luz = OmniLight3D.new()
	_luz.light_color = RVFX.FOGO
	_luz.omni_range = 4.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0, 0, CORPO * 0.5 + 0.5)
	add_child(_luz)

	# Rastro de fumaça: coordenadas de MUNDO, fica para trás e desenha a curva feita.
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3.BACK
	proc.spread = 10.0
	proc.initial_velocity_min = 1.5
	proc.initial_velocity_max = 3.0
	proc.gravity = Vector3.UP * 0.6
	proc.damping_min = 1.5
	proc.damping_max = 2.5
	proc.scale_min = 0.8
	proc.scale_max = 1.3
	proc.scale_curve = FxUtil.curve([[0.0, 0.45], [0.3, 1.0], [1.0, 1.7]])
	# Opaca o bastante para o rastro desenhar a curva: com o disco macio, 0,55 no começo
	# sumia contra o chão cinza (captura de 30/09/2026).
	proc.color_ramp = FxUtil.gradient([Color(0.66, 0.62, 0.58, 0.85),
			Color(0.42, 0.39, 0.37, 0.55), Color(0.25, 0.23, 0.22, 0.0)])
	var grao := FxUtil.grain(0.75)
	grao.material = _material_de_fumaca()
	_fumaca = FxUtil.particles(70, 1.2, false, proc, grao)
	_fumaca.local_coords = false
	_fumaca.visibility_aabb = AABB(Vector3.ONE * -30.0, Vector3.ONE * 60.0)
	_fumaca.position = Vector3(0, 0, CORPO * 0.5 + 0.35)
	add_child(_fumaca)

	# Brasas curtas saindo da chama.
	var fagulha := ParticleProcessMaterial.new()
	fagulha.direction = Vector3.BACK
	fagulha.spread = 16.0
	fagulha.initial_velocity_min = 5.0
	fagulha.initial_velocity_max = 8.0
	fagulha.gravity = Vector3.DOWN * 2.0
	fagulha.scale_curve = FxUtil.curve([[0.0, 1.0], [1.0, 0.0]])
	fagulha.color_ramp = FxUtil.gradient([RVFX.CLARAO, RVFX.FOGO, Color(RVFX.BRASA, 0.0)])
	var ponto := FxUtil.grain(0.07)
	ponto.material = FxUtil.particle_material(Color.WHITE, 2.0, true)
	_brasas = FxUtil.particles(34, 0.35, false, fagulha, ponto)
	_brasas.local_coords = false
	_brasas.visibility_aabb = AABB(Vector3.ONE * -20.0, Vector3.ONE * 40.0)
	_brasas.position = Vector3(0, 0, CORPO * 0.5 + 0.3)
	add_child(_brasas)


## Nuvem curta na troca de forma (entrar e sair): esconde o instante em que o corpo some
## ou volta. Nasce no contêiner de golpes do dono — limpo junto com os golpes dele.
func _puff(onde: Vector3, tamanho: float) -> void:
	var dono := get_parent()
	var mundo := FxUtil.mundo_de_skills(dono)
	if mundo == null:
		return
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.45 * tamanho
	proc.direction = Vector3.UP
	proc.spread = 180.0
	proc.initial_velocity_min = 1.8 * tamanho
	proc.initial_velocity_max = 3.6 * tamanho
	proc.gravity = Vector3.UP * 0.8
	proc.damping_min = 3.0
	proc.damping_max = 4.5
	proc.scale_curve = FxUtil.curve([[0.0, 0.6], [0.35, 1.0], [1.0, 1.4]])
	proc.color_ramp = FxUtil.gradient([Color(RVFX.CREME, 0.8),
			Color(0.55, 0.52, 0.5, 0.5), Color(0.35, 0.33, 0.32, 0.0)])
	var grao := FxUtil.grain(0.95 * tamanho)
	grao.material = _material_de_fumaca()
	var nuvem := FxUtil.particles(24, 0.7, true, proc, grao, 1.0)
	mundo.add_child(nuvem)
	# O contêiner `Skills_<jogador>` entra na cena por `call_deferred`: no 1º efeito de
	# cada vida ele ainda está fora da árvore, e lá `global_position` dá erro. Ele nasce
	# na origem da cena, então a posição local é a de mundo.
	if nuvem.is_inside_tree():
		nuvem.global_position = onde
	else:
		nuvem.position = onde
	FxUtil.autofree(nuvem, 1.2)
	if is_instance_valid(dono) and dono is Node3D:
		AudioFX.whoosh(dono, onde, 0.9)


static func _material_de_fumaca() -> StandardMaterial3D:
	var m := FxUtil.particle_material(Color.WHITE, 0.0, false)
	if _textura_fumaca == null:
		var rampa := Gradient.new()
		rampa.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
		rampa.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.8),
				Color(1, 1, 1, 0.25), Color(1, 1, 1, 0.0)])
		_textura_fumaca = GradientTexture2D.new()
		_textura_fumaca.gradient = rampa
		_textura_fumaca.fill = GradientTexture2D.FILL_RADIAL
		_textura_fumaca.fill_from = Vector2(0.5, 0.5)
		_textura_fumaca.fill_to = Vector2(1.0, 0.5)
		_textura_fumaca.width = 64
		_textura_fumaca.height = 64
	m.albedo_texture = _textura_fumaca
	return m
