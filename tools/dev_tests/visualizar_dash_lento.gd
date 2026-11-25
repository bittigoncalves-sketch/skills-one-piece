extends SceneTree
## Visualizador interativo dos clipes reais do dash no rig do Modo História.
## Fechar: Esc. Pausar: Espaço. Passo: setas. Direção: 1–4. Câmera: V.

const CORPO := preload("res://src/player/corpo_historia.gd")
const DURACAO := 0.28
const VELOCIDADE := 0.12
const DIRECOES := ["frente", "tras", "esquerda", "direita"]
const NOMES := ["FRENTE", "TRÁS", "ESQUERDA", "DIREITA"]
const OLHARES := [Vector3(2.7, 1.45, -3.6), Vector3(4, 1.35, 0), Vector3(0, 1.35, 4), Vector3(-4, 1.35, 0)]
const NOMES_CAMERA := ["3/4 de frente", "lado direito", "costas", "lado esquerdo"]

class LoopVisual extends Node:
	var app
	func _process(delta: float) -> void:
		app._atualizar_visual(delta)
	func _input(event: InputEvent) -> void:
		app._entrada_visual(event)

var anim: ProceduralAnimator
var camera: Camera3D
var titulo: Label
var estado: Label
var barra: ProgressBar
var direcao := 0
var lado_camera := 1 # perfil para observar claramente a flexão dos joelhos
var tempo := 0.0
var pausa := false
var espera := 0.0
var perna_alternada := false

func _init() -> void:
	_montar.call_deferred()

func _montar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var ambiente := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.14, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.90, 1.0)
	env.ambient_light_energy = 0.95
	ambiente.environment = env
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, -40, 0)
	luz.light_energy = 1.25
	mundo.add_child(luz)
	var modelo: Node3D = CORPO.construir("masculino")["node"]
	modelo.position.y = 0.35
	mundo.add_child(modelo)
	anim = ProceduralAnimator.new()
	modelo.add_child(anim)
	anim.setup(BodyScanner.scan(modelo))
	var piso := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 1.15
	disco.bottom_radius = 1.15
	disco.height = 0.04
	piso.mesh = disco
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.29, 0.36)
	piso.material_override = material
	piso.position.y = -0.06
	mundo.add_child(piso)
	camera = Camera3D.new()
	mundo.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	camera.current = true
	_atualizar_camera()
	var camada := CanvasLayer.new()
	mundo.add_child(camada)
	var fundo := ColorRect.new()
	fundo.color = Color(0.025, 0.04, 0.06, 0.90)
	fundo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fundo.offset_bottom = 135
	camada.add_child(fundo)
	titulo = Label.new()
	titulo.position = Vector2(24, 12)
	titulo.add_theme_font_size_override("font_size", 25)
	camada.add_child(titulo)
	estado = Label.new()
	estado.position = Vector2(25, 48)
	estado.add_theme_font_size_override("font_size", 17)
	camada.add_child(estado)
	var ajuda := Label.new()
	ajuda.position = Vector2(25, 78)
	ajuda.text = "ESPAÇO pausar  ·  ← / → quadro  ·  1–4 direção  ·  T troca perna  ·  V muda câmera  ·  ESC sair"
	ajuda.add_theme_font_size_override("font_size", 15)
	camada.add_child(ajuda)
	barra = ProgressBar.new()
	barra.position = Vector2(25, 111)
	barra.size = Vector2(400, 12)
	barra.max_value = DURACAO
	barra.show_percentage = false
	camada.add_child(barra)
	var loop := LoopVisual.new()
	loop.app = self
	mundo.add_child(loop)
	print("VISUALIZADOR_DASH pronto: espaço pausa, setas mudam quadro, 1–4 direção, V câmera, ESC sai")

func _atualizar_camera() -> void:
	camera.position = OLHARES[lado_camera]
	camera.look_at(Vector3(0, 1.15, 0), Vector3.UP)

func _atualizar_visual(delta: float) -> void:
	if not pausa:
		if tempo < DURACAO:
			tempo = minf(tempo + delta * VELOCIDADE, DURACAO)
		else:
			espera += delta
			if espera >= 0.8:
				espera = 0
				tempo = 0
				perna_alternada = not perna_alternada
				if not perna_alternada:
					direcao = (direcao + 1) % DIRECOES.size()
	anim.acao_clipe = DashNoAr.CLIPES_ALTERNADOS[DIRECOES[direcao]] if perna_alternada else DashNoAr.CLIPES[DIRECOES[direcao]]
	anim.acao_tempo = tempo
	anim.update(Vector3.ZERO, false, false, delta, 0.0)
	var fase := "preparação" if tempo < 0.065 else ("chute no ar" if tempo < 0.13 else ("impulso" if tempo < 0.21 else "recuperação"))
	titulo.text = "DASH NO AR   /   " + NOMES[direcao] + "   /   CÂMERA LENTA 12%"
	var perna_direita := (direcao == 2) != perna_alternada
	estado.text = "%s   ·   perna %s   ·   quadro %.2f / %.2f s   ·   câmera: %s   ·   %s" % [fase, "direita" if perna_direita else "esquerda", tempo, DURACAO, NOMES_CAMERA[lado_camera], "PAUSADO" if pausa else "reproduzindo"]
	barra.value = tempo

func _entrada_visual(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			quit()
		KEY_SPACE:
			pausa = not pausa
		KEY_LEFT:
			pausa = true
			tempo = maxf(tempo - 1.0 / 60.0, 0.0)
		KEY_RIGHT:
			pausa = true
			tempo = minf(tempo + 1.0 / 60.0, DURACAO)
		KEY_1, KEY_2, KEY_3, KEY_4:
			direcao = int(event.keycode) - int(KEY_1)
			tempo = 0.0
			espera = 0.0
		KEY_V:
			lado_camera = (lado_camera + 1) % OLHARES.size()
			_atualizar_camera()
		KEY_T:
			perna_alternada = not perna_alternada
			tempo = 0.0
			espera = 0.0
