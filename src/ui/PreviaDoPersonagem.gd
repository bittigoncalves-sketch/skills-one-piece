class_name PreviaDoPersonagem
extends SubViewportContainer
# ============================================================================
#  A PRÉVIA 3D DO PERSONAGEM — o modelo de verdade num mundo só dele.
#
#  Saiu de dentro do menu de Customização (30/09/2026) quando a janela de Status
#  (tecla M) passou a mostrar o personagem também. Duas cópias da montagem
#  (viewport, luz, câmera, enquadramento) virariam duas verdades: cada correção
#  de enquadramento abaixo custou um bug, e teria de ser refeita na outra.
#  Quem usa: `CustomizacaoMenu` e `JanelaDeStatus`.
#
#  O modelo vem do `CharacterBuilder` com o visual salvo (`Visual.aplicar`) — o
#  MESMO que entra em partida, então o que se vê aqui é o que se leva, e não uma
#  maquete que pode divergir.
#
#  ⚠️ O viewport precisa de `own_world_3d = true`. Sem isso ele compartilha o
#  mundo da cena principal: a arena inteira apareceria atrás do personagem, e a
#  luz daqui vazaria para o jogo.
#
#  ⚠️ SÓ DESENHA VISÍVEL (`UPDATE_WHEN_PARENT_VISIBLE`). A janela de Status vive a
#  sessão inteira escondida; com `UPDATE_ALWAYS` ela renderizaria o personagem a
#  cada quadro de jogo sem ninguém ver.
# ============================================================================

## Personagem do `CharacterBuilder` a montar (`remontar` troca).
var personagem := "base"
## Definido pelas janelas da campanha. A customização da arena segue seu visual próprio.
var corpo_historia := ""
var tom_de_pele := "medio"
var aparencia_historia: Dictionary = {}
## Cor do disco sob os pés: quem hospeda escolhe a que conversa com o seu fundo.
var cor_da_base := Color(0.055, 0.10, 0.20)
## Montar o modelo já ao entrar na árvore. Falso para quem nasce escondido e monta
## ao abrir (a janela de Status): um personagem inteiro sem ninguém ver é desperdício.
var montar_ao_entrar := true
## A entrada da história usa frente fixa e dispensa o disco sob os pés.
var permitir_giro := true
var mostrar_base := true

var modelo: Node3D = null
var viewport: SubViewport = null
var camera: Camera3D = null
var _base: MeshInstance3D = null
var _giro := 0.0
var _arrastando := false


func _ready() -> void:
	stretch = true
	# O container é quem recebe o arrasto: é ele que ocupa a área do personagem.
	mouse_filter = Control.MOUSE_FILTER_STOP if permitir_giro else Control.MOUSE_FILTER_IGNORE
	gui_input.connect(arrastar)
	_montar_cena()
	if montar_ao_entrar:
		remontar()


## Monta o modelo de novo (ou troca por `id`) e aplica o visual salvo. Para mostrar o
## que mudou na customização, ou o personagem de outro corpo.
func remontar(id := "") -> void:
	if not id.is_empty():
		personagem = id
	if is_instance_valid(modelo):
		modelo.queue_free()
	modelo = null
	var da_historia := personagem == "base" and corpo_historia in ["masculino", "feminino"]
	var dados := preload("res://src/player/corpo_historia.gd").construir(corpo_historia, tom_de_pele, aparencia_historia) if da_historia else CharacterBuilder.build_character(personagem)
	modelo = dados.get("node") as Node3D
	if modelo == null:
		push_warning("[PreviaDoPersonagem] não consegui montar o personagem '%s'" % personagem)
		return
	modelo.rotation.y = _giro
	viewport.add_child(modelo)
	if not da_historia:
		Visual.carregar_uma_vez()
		Visual.aplicar(modelo)
	reenquadrar()


## ⚠️ SEM GIRO AUTOMÁTICO. O personagem girava sozinho na Customização, e isso
## atrapalha o que o menu existe para fazer: comparar duas opções. Quando ele nunca
## para, cada escolha aparece num ângulo diferente e a comparação vira memória. Ele
## fica parado e gira quando o jogador ARRASTA — quem quer ver as costas vê, na hora
## que quiser.
func arrastar(e: InputEvent) -> void:
	if not permitir_giro or modelo == null or not is_instance_valid(modelo):
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_arrastando = e.pressed
	elif e is InputEventMouseMotion and _arrastando:
		# 0,01 rad por pixel: uma volta completa em ~630 px, que é aproximadamente a
		# largura do painel da Customização. O gesto natural (arrastar de ponta a
		# ponta) dá a volta inteira.
		_giro -= (e as InputEventMouseMotion).relative.x * 0.01
		modelo.rotation.y = _giro


## ⚠️ SEMPRE ADIADO. `enquadrar` lê `global_transform` das malhas, e o Godot só
## propaga isso depois que a árvore processa. Chamar logo após equipar mede a peça
## nova ainda em repouso e devolve uma moldura errada — é o mesmo erro que já pôs a
## câmera dentro do tronco no `_ready` (ver docs/erros.md).
func reenquadrar() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	enquadrar()


## ⚠️ ENQUADRAMENTO MEDIDO, não números fixos. A primeira versão punha a câmera em
## (0, 1.0, 2.6) — e o modelo do `CharacterBuilder` vem no tamanho NATIVO dele, sem
## a escala que o rig aplica em partida. Resultado: a câmera nascia dentro do tronco
## e a tela mostrava uma parede verde. A moldura sai da caixa do próprio modelo:
## trocar de personagem ou mudar a proporção do rig continua enquadrando.
func enquadrar() -> void:
	if modelo == null or not is_instance_valid(modelo) or camera == null:
		return
	var cx := caixa_visual(modelo)
	var alvo := cx.position + cx.size * 0.5
	# O maior lado manda: personagem alto pede recuo por altura, largo por largura.
	# `tan(fov/2)` converte "quanto cabe" em "a que distância".
	var maior: float = maxf(cx.size.y, maxf(cx.size.x, cx.size.z))
	var dist: float = (maior * 0.5) / tan(deg_to_rad(camera.fov * 0.5))
	dist *= 1.35   # respiro nas bordas: personagem colado na moldura sufoca
	# ⚠️ CÂMERA NO −Z, não no +Z. O personagem olha para −Z (convenção do Godot e
	# deste projeto, ver `RosaDosVentos`), então pôr a câmera no +Z mostra as COSTAS.
	# ⚠️ IDEMPOTENTE: NÃO MOVE O MODELO. A primeira versão deslocava o modelo para
	# centrar o alvo no eixo — e cada nova chamada subtraía de novo, acumulando
	# DERIVA a cada troca de raça e de acessório. A mira usa o EIXO do modelo em X/Z
	# (o giro fica centrado) e a altura do centro da caixa em Y.
	var base := modelo.global_position
	var mira := Vector3(base.x, alvo.y, base.z)
	camera.position = Vector3(mira.x, mira.y, mira.z - dist)
	camera.look_at(mira, Vector3.UP)


## A caixa que o modelo realmente OCUPA, em coordenadas de MUNDO.
##
## ⚠️ MUNDO, não espaço do modelo. A primeira versão convertia para o espaço do
## modelo e devolvia 3,6 de altura — mas o rig tem escala 1,8, então o corpo mede
## 6,48 no mundo, que é onde a câmera está. A distância saía pela metade e o
## enquadramento pegava só a cabeça. `VisualInstance3D.get_aabb()` sozinho não
## serve: ele é da malha, não da hierarquia, e o rig tem membros em vários nós.
static func caixa_visual(raiz: Node3D) -> AABB:
	var malhas: Array = []
	FxUtil._collect_meshes(raiz, malhas)
	var uniao := AABB()
	var primeiro := true
	for m in malhas:
		if not (m is MeshInstance3D) or (m as MeshInstance3D).mesh == null:
			continue
		var mi := m as MeshInstance3D
		var a: AABB = mi.global_transform * mi.mesh.get_aabb()
		uniao = a if primeiro else uniao.merge(a)
		primeiro = false
	if primeiro:
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 2.0, 1.0))
	return uniao


func _montar_cena() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	# ⚠️ TRANSPARENTE, senão o personagem aparece dentro de um RETÂNGULO recortado
	# sobre o fundo de quem hospeda: o viewport pinta o próprio fundo antes da cena.
	viewport.transparent_bg = true
	viewport.size = Vector2i(520, 620)   # o container estica; vale até o 1º layout
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	add_child(viewport)

	var amb := WorldEnvironment.new()
	var env := Environment.new()
	# BG_CLEAR_COLOR (e não BG_COLOR) é o que respeita o `transparent_bg` acima: com
	# BG_COLOR o ambiente pinta a cor de qualquer jeito.
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.68, 0.90)
	env.ambient_light_energy = 0.9
	amb.environment = env
	viewport.add_child(amb)

	# Base baixa e escura: ancora os pés e separa a silhueta do fundo, sem virar um
	# segundo cenário dentro do menu.
	_base = MeshInstance3D.new()
	_base.visible = mostrar_base
	var disco := CylinderMesh.new()
	disco.top_radius = 2.25
	disco.bottom_radius = 2.45
	disco.height = 0.10
	disco.radial_segments = 48
	_base.mesh = disco
	_base.position = Vector3(0.0, -0.06, 0.0)
	_base.material_override = Materiais.superficie(cor_da_base)
	viewport.add_child(_base)

	var luz := DirectionalLight3D.new()
	luz.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(-38.0), 0.0)
	luz.light_energy = 1.5
	viewport.add_child(luz)
	# Recorte frio no lado oposto: destaca cabelo, asas e acessórios escuros contra o
	# fundo sem achatar a luz principal.
	var recorte := DirectionalLight3D.new()
	recorte.rotation = Vector3(deg_to_rad(-28.0), deg_to_rad(132.0), 0.0)
	recorte.light_color = Color(0.48, 0.72, 1.0)
	recorte.light_energy = 0.55
	viewport.add_child(recorte)

	camera = Camera3D.new()
	camera.fov = 42.0
	viewport.add_child(camera)
	camera.current = true
