extends CharacterBody3D
# ============================================================================
#  Jogador = um bloco cinza. Anda (WASD / setas), pula (Espaco).
#  F5 alterna 1a <-> 3a pessoa. Mouse olha. ESC solta o mouse; segure pra sair.
#
#  Sem InputMap: le o teclado direto, entao o projeto roda sem configuracao.
# ============================================================================

const SPEED := 4.2
const JUMP_VELOCITY := 16.0
const GRAVITY := 32.0        # gravidade reforcada (Godot padrao ~9.8)
const MOUSE_SENS := 0.0035
const CLIMB_SPEED := 4.5
const CLIMB_STICK_SPEED := 1.0
const CLIMB_WALL_NORMAL_MAX_Y := 0.2

var cam_distance: float = 6.0 # afastamento da camera em 3a pessoa (ajustável com scroll)
const CAM_HEIGHT_TPS := 2.2  # altura do pivo em 3a pessoa
const CAM_HEIGHT_FPS := 0.6  # altura do "olho" em 1a pessoa
const SHOULDER_RIGHT := 1.1  # deslocamento p/ o ombro direito (over-the-shoulder)

var current_fruit_id: String = ""
var speed_multiplier: float = 1.0
var jump_multiplier: float = 1.0

# Vida (barra verde, HUD) — máx 2048. Foco continua no knockback pra fora do mapa,
# mas agora o dano importa e é mostrado.
var health: float = 2048.0
var max_health: float = 2048.0
# Energia (barra azul, HUD) — máx 4096. Regenera com o tempo; skills consomem.
var energy: float = 4096.0
var max_energy: float = 4096.0
const ENERGY_REGEN := 320.0        # por segundo
const ENERGY_BULLET := 10.0        # por bala da rajada Z
const ENERGY_SKILL := 180.0        # por skill lançada
var is_suppressed: bool = false
var suppression_timer: float = 0.0

var combat_mode: String = "fruit" # "fruit" ou "style"
var current_style_idx: int = 0
const STYLES_LIST: Array[String] = ["karate_tritao", "pacifista", "mink", "boxe", "cyborg", "teste_animacao"]

var _charging: bool = false
var _charge_slot: String = ""
# Nº de série do cast atual. Cada `begin_charge` emite um novo. O temporizador de
# 0.3 s que apaga `is_casting` no fim do golpe carrega o número do golpe DELE e só
# apaga se ainda for o mesmo — senão o temporizador do golpe ANTERIOR apagava o
# `is_casting` do golpe SEGUINTE, e o bloco do _physics_process lia isso como
# "cast interrompido" e engolia a skill seguinte.
var _cast_token: int = 0
var _movement_locked_timer: float = 0.0
# IMPULSO EXTERNO (knockback). NÃO pode viver dentro de `velocity`: o bloco de
# locomoção faz `velocity.x = dir.x * speed` — ATRIBUIÇÃO, não soma — e apagaria
# o empurrão no quadro seguinte. Foi exatamente isso que fez ninguém tomar
# knockback, nem em rede nem em um-jogador. Vive aqui, decai sozinho, e é somado
# à velocidade logo antes do move_and_slide.
var _kb_impulso: Vector3 = Vector3.ZERO
const KB_DECAIMENTO := 4.0   # 1/s — quanto o empurrão perde força por segundo

var _yaw := 0.0     # rotacao horizontal da camera
var _pitch := -0.25 # rotacao vertical da camera
var _first_person := false
var _is_climbing := false
var max_geppo: int = 1      # número de pulos duplos aéreos (Geppo / Técnica do CP9)
var _geppo_count: int = 0   # contador atual de geppo desde o último toque no chão

var _pivot: Node3D
var _shoulder: Node3D
var _spring: SpringArm3D
var _cam: Camera3D
var _shake: float = 0.0   # Camera Feel: tremor de tela (screen-shake) que decai
var _was_floor: bool = true   # p/ detectar aterrissagem
var _fov_punch: float = 0.0   # zoom-in momentâneo ao atacar (decai)

# FOV por ESTADO. Degraus, não rampa: o salto de CORRENDO p/ SPRINT é o que faz
# o Shift dar o "clique" na mão.
#
# FOV_INTENSIDADE é o único número a mexer para calibrar a força do efeito.
# Os ganhos abaixo estão em graus "cheios" e guardam a PROPORÇÃO entre os
# estados; a intensidade escala todos juntos, então afinar não desmonta os
# degraus. Em 1.0 a variação era de 22° — forte demais em jogo. Em 0.10 sobra
# ~2,2°: o FOV respira sem chamar atenção.
const FOV_INTENSIDADE := 0.10
const FOV_BASE := 68.0
const FOV_G_ANDANDO := 4.0
const FOV_G_CORRENDO := 12.0
const FOV_G_SPRINT := 22.0
const FOV_G_AR := 3.0

# Sprint = Shift segurado com direção. Usado pela câmera e pelos efeitos de tela;
# o movimento tem a própria checagem em _physics_process.
func _is_sprinting() -> bool:
	return Input.is_key_pressed(KEY_SHIFT) and velocity.length_squared() > 0.5
var _long_jump_t: float = 0.0 # Parkour: janela de impulso horizontal (salto longo/vault)
var _space_was: bool = false  # borda do Espaço (salto longo só na batida, não segurando)
var _was_on_floor: bool = false   # Parkour: detecção de POUSO (#4)
var _fall_peak: float = 0.0       # maior velocidade de queda acumulada no ar
var _precision_armed: bool = false # Espaço no ar armou o pouso de precisão
var _roll_t: float = 0.0          # janela da animação de ROLAMENTO (pós-pouso e dash)
# DASH (Q): esquiva curta e invencível. A DISTÂNCIA é o parâmetro de design; a
# velocidade sai dela. Assim mudar o alcance não obriga a recalcular nada, e o
# alcance fica escrito em metros no código em vez de escondido num multiplicador.
#
# VELOCIDADE DO DASH (pedido do dono do projeto, 2026-08-10): era 4 m em 0,4 s =
# 10 m/s, pouco mais que o dobro da caminhada (4,2 m/s) — o dash parecia um passo
# apressado, não uma esquiva. Agora 6 m em 0,28 s = **21,4 m/s**, mais de 2× o
# que era.
#
# Subi as duas pontas de propósito, e elas fazem coisas diferentes:
#   • encurtar o TEMPO é o que dá o tranco (a esquiva sai do lugar antes do
#     golpe chegar) — é daqui que vem a sensação de velocidade;
#   • aumentar a DISTÂNCIA é o que faz a esquiva valer taticamente, senão você
#     sai rápido e continua dentro da área do golpe.
#
# Para calibrar: mexa na DISTÂNCIA para mudar alcance e no TEMPO para mudar o
# tranco. A velocidade é consequência dos dois, não um terceiro botão.
const DASH_DISTANCE := 6.0        # metros percorridos por dash
const DASH_TIME := 0.28           # segundos de deslocamento
const DASH_COOLDOWN := 1.5        # recarga entre dashes
var _is_aiming_dash: bool = false # Segurando Q para dar o dash
var _dash_cooldown: float = 0.0   # Recarga da esquiva
var _dash_t: float = 0.0          # Tempo restante do movimento (dash)
var _dash_dir: Vector3 = Vector3.FORWARD # Direção TRAVADA no disparo do dash
var _bob_t: float = 0.0       # fase do balanço de câmera (head bob) ao andar/correr
# Mera Mera Z: rajada de balas de fogo (segura pra atirar; para ao soltar ou 16 balas).
const RAPID_INTERVAL := 0.09
const RAPID_MAX := 16
var _rapid_fire: bool = false
var _rapid_count: int = 0
var _rapid_t: float = 0.0
var _gun_recoil: float = 0.0   # coice da rajada Z (1->0 por tiro) p/ a pose de mira
var _pistols: Array = []       # pistolas nas DUAS mãos (visíveis só na rajada Z)
var _bullet_side: int = 0      # alterna a mão a cada tiro (0=esq, 1=dir)
var _yami_pistol_active: bool = false # Yami Z: pistola ativa por toggle
var _yami_shot_cooldown: float = 0.0  # cadência do tiro do Yami Z

# ---- BUKI BUKI: arma empunhada + munição (regra nova, 2026-08-11) ----
# A fruta virou um jogo de FPS: a tecla do slot SACA a arma, ela FICA na mão, o
# botão esquerdo atira, e a munição é a penalidade. Zerou a bala (ou trocou de
# slot) -> a arma some e AQUELE slot entra em recarga. Ver src/effects/BukiFX.gd.
#
# ONDE MORA A MUNIÇÃO — os dois lados, de propósito:
#   • `_buki_municao` é do DONO do corpo. É o que a HUD mostra e o que decide a
#     cadência local; precisa ser local senão o contador só se mexeria depois do
#     ida-e-volta de rede e a arma pareceria travada.
#   • `_srv_buki_municao` é do SERVIDOR (só a cópia autoritativa a usa). É ela
#     que autoriza o disparo em `_do_server_bullet`: sem bala, nenhuma
#     `DamageZone` nasce. Cliente mentindo não fere ninguém.
# O dono desconta ao pedir; o servidor desconta ao criar. Empate garantido
# porque os dois partem do mesmo número e o canal é `reliable`.
var _buki_weapon: String = ""       # slot empunhado no DONO ("" = mãos livres)
var _buki_municao: int = 0          # balas restantes (visão do dono / HUD)
var _buki_shot_cd: float = 0.0      # cadência do tiro
var _buki_scope: bool = false       # luneta da sniper (C) ativa
var _srv_buki_arma: String = ""     # SERVIDOR: qual arma este corpo empunha
var _srv_buki_municao: int = 0      # SERVIDOR: balas que ele ainda autoriza
var _buki_visual: String = ""       # arma VISÍVEL (roda em todos os peers)
var _buki_armas: Dictionary = {}    # slot -> Node3D pré-construído (oculto)
var _buki_pivot: Node3D = null      # pivô do canhão-corpo (X): gira com a mira
var _skill_cooldowns: Dictionary = {"Z": 0.0, "X": 0.0, "C": 0.0, "V": 0.0}
var aim_assist: bool = false   # assistência de mira (liga/desliga no E)

# ---- corpo a corpo (botão esquerdo): soco D -> soco E -> chute ----
# Ver src/combat/Melee.gd. `_melee_janela` conta o tempo que ainda resta pra
# encadear; zerou, o próximo clique volta ao primeiro soco.
var _melee_passo: int = 0
var _melee_janela: float = 0.0
var _melee_trava: float = 0.0   # recuperação: bloqueia o clique durante o golpe
var _melee_buffer: float = 0.0  # clique que chegou na recuperação, esperando a vez
const BUFFER_MELEE := 0.18      # até quanto antes da trava abrir o clique é guardado

# Qual slot está EM USO agora — "" se nenhum. Usado para congelar a recarga das
# outras técnicas (ver o laço de cooldown no _physics_process).
#
# Cobre as quatro formas de "habilidade em andamento" que o jogo tem:
# segurar para mirar (`_charging`), a rajada Z, o cast já solto mas ainda
# rodando (`is_casting`), e os golpes que travam o movimento por tempo
# (Gatling, Red Hawk, Kurouzu, Black Hole — todos gravam `active_skill`).
func _slot_em_uso() -> String:
	if _charging and _charge_slot != "":
		return _charge_slot
	if _rapid_fire:
		return "Z"
	if has_meta("is_casting") and get_meta("is_casting"):
		var s := str(get_meta("active_skill", ""))
		if s != "":
			return s
	if _movement_locked_timer > 0.0:
		return str(get_meta("active_skill", ""))
	return ""

# POSE DE ARMA (braço estendido, mirando): rajada Z, pistola da Yami e agora
# qualquer arma de BRAÇO da Buki. O canhão-corpo (X) fica de fora — lá o modelo
# está escondido, e mandar o rig fazer pose de pistoleiro seria trabalho à toa.
func _pose_de_arma() -> bool:
	return _rapid_fire or _yami_pistol_active or (_buki_weapon != "" and _buki_weapon != "X")

func trigger_skill_cooldown(slot: String) -> void:
	match slot:
		"Z": _skill_cooldowns["Z"] = 5.0
		"X": _skill_cooldowns["X"] = 7.0
		"C": _skill_cooldowns["C"] = 10.0
		"V": _skill_cooldowns["V"] = 60.0 # 1 minuto para skills ultimate em V
var _mesh: MeshInstance3D
var _crosshair: Control

# ELENCO TRANCADO: só o "base" (decisão do usuário) — é nele que a animação está
# sendo feita. Os outros modelos continuam no projeto, mas não são selecionáveis:
# ver CHARS_TRANCADOS em src/ui/CharacterMenu.gd.
const ELENCO_LIBERADO: Array[String] = ["base", "bluebuddy"]

var character_id: String = "base"
var _animator: CharacterAnimator
var _char_model: Node3D
var _proc_anim: ProceduralAnimator   # animação procedural em tempo real do rig
var _skel_anim: SkeletalAnimator = null   # animador ESQUELETAL (personagens skinnados)
var _is_skinned: bool = false             # o personagem atual é skinnado (Skeleton3D)?
var _breath = null                   # VFX de fôlego (instância de VFX/BreathVFX.tscn; sem tipo p/ não depender do cache de class_name)
var _head_node: Node3D               # cabeça do modelo atual (âncora do fôlego)

# ---- Rede (Fase 4) ----
# _is_authority = este player é controlado por ESTE cliente (input+câmera). No
# singleplayer o host é a autoridade -> tudo funciona igual. Players remotos só
# reproduzem a pose a partir do estado replicado (net_velocity/net_facing).
var _is_authority: bool = true

## QUEM É "O MEU JOGADOR" NESTA TELA.
##
## O grupo "player" tem TODOS os corpos (é assim que o Placar, a DamageZone e os
## FX varrem a partida). Quem quer o corpo DESTE peer — HUD, barras, menus —
## precisa filtrar pela autoridade: `get_first_node_in_group("player")` devolve o
## PRIMEIRO da árvore, que no cliente é o corpo do HOST (ele nasceu antes).
##
## Era exatamente esse o bug: no cliente a HUD lia energia e mandava as teclas
## Z/X/C/V no corpo do host — um corpo sem autoridade, que não regenera energia
## (a regen do `_physics_process` só roda na autoridade) e engole todo pedido de skill
## (`_request_cast` corta em `not _is_authority`). No host o primeiro da árvore
## É o corpo dele, e por isso o bug NUNCA apareceu de quem hospeda.
static func local_player(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var todos := tree.get_nodes_in_group("player")
	for p in todos:
		if p.is_multiplayer_authority():
			return p
	# Sem autoridade nenhuma (corpo ainda não spawnado): melhor nada que o errado.
	return null

@export var net_velocity: Vector3 = Vector3.ZERO   # replicado (autoridade -> demais)
@export var net_facing: float = 0.0
@export var net_on_floor: bool = true

func _ready() -> void:
	add_to_group("player")   # o HUD encontra o jogador por este grupo
	_is_authority = is_multiplayer_authority()   # SP: host=autoridade -> true

	# Substitui o quadrado cinza pelo modelo 3D Voxel e equipa a Akuma no Mi correspondente
	set_character(character_id)

	# Colisor do jogador.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.6, 1.0)
	col.shape = shape
	add_child(col)

	# Cadeia da camera:
	#   _pivot (yaw/pitch)  ->  _shoulder (offset lateral)  ->  _spring  ->  _cam
	# O _shoulder empurra a camera pro ombro direito (over-the-shoulder),
	# deixando o corpo a esquerda e a mira um pouco a direita dele.
	_pivot = Node3D.new()
	add_child(_pivot)

	_shoulder = Node3D.new()
	_pivot.add_child(_shoulder)

	# SpringArm evita a camera atravessar paredes/blocos.
	_spring = SpringArm3D.new()
	_spring.margin = 0.15
	var sphere := SphereShape3D.new()
	sphere.radius = 0.15
	_spring.shape = sphere
	_shoulder.add_child(_spring)
	_spring.add_excluded_object(get_rid())  # nunca colidir com o próprio corpo do player

	_cam = Camera3D.new()
	_cam.near = 0.05
	_cam.current = _is_authority   # só a câmera do MEU player fica ativa
	_spring.add_child(_cam)

	# Mira + captura de mouse SÓ para o player local (players remotos não têm HUD/mira).
	if _is_authority:
		var layer := CanvasLayer.new()
		add_child(layer)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(center)
		var dot := Label.new()
		dot.text = "+"
		dot.add_theme_font_size_override("font_size", 24)
		center.add_child(dot)
		_crosshair = center
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_apply_perspective()
	_update_pivot()

func _apply_perspective() -> void:
	if _first_person:
		_pivot.position.y = CAM_HEIGHT_FPS
		_shoulder.position.x = 0.0
		_spring.spring_length = 0.0
	else:
		_pivot.position.y = CAM_HEIGHT_TPS
		_shoulder.position.x = SHOULDER_RIGHT
		_spring.spring_length = cam_distance
	_atualizar_visibilidade_corpo()   # some o corpo na 1ª pessoa (e no canhão da Buki)

func _input(event: InputEvent) -> void:
	if not _is_authority:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# LUNETA DA SNIPER: com o zoom ligado a mira anda mais devagar. Sem isso o
		# zoom só aumenta a imagem e piora a pontaria (o mesmo movimento de mouse
		# varre 3x mais mundo).
		var sens := MOUSE_SENS * (0.38 if _buki_scope else 1.0)
		_yaw -= event.relative.x * sens
		_pitch = clamp(_pitch - event.relative.y * sens, -1.2, 0.5)
		_update_pivot()
	elif event is InputEventMouseButton and not _first_person:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam_distance = clampf(cam_distance - 0.5, 2.0, 15.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam_distance = clampf(cam_distance + 0.5, 2.0, 15.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_authority:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		# Alterna 1a <-> 3a pessoa.
		_first_person = not _first_person
		_apply_perspective()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		# Cicla o modelo — hoje o elenco está trancado no "base", então F6 não
		# tem para onde ir. Liberar outro personagem é só acrescentar em
		# ELENCO_LIBERADO.
		if ELENCO_LIBERADO.size() > 1:
			var idx := ELENCO_LIBERADO.find(character_id)
			set_character(ELENCO_LIBERADO[(idx + 1) % ELENCO_LIBERADO.size()])
		else:
			print("[Personagem] elenco trancado em: ", ELENCO_LIBERADO[0])
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		toggle_combat_mode()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		_cycle_fruit()   # DEBUG: cicla entre as frutas pra testar as skills
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		aim_assist = not aim_assist   # liga/desliga a assistência de mira
		print("🎯 Assistência de mira: ", "LIGADA" if aim_assist else "DESLIGADA")
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("set_aim_assist"):
			hud.set_aim_assist(aim_assist)
		if Engine.has_singleton("ScreenFX") or get_node_or_null("/root/ScreenFX"):
			get_node("/root/ScreenFX").set_aim_assist(aim_assist, self)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if event.echo:
			get_tree().quit()
		else:
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("toggle_main_menu"):
				hud.toggle_main_menu()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# Com arma na mão o botão direito é MIRA (auxílio da Buki / luneta da
		# sniper / mira da Yami), não doma.
		if not _yami_pistol_active and _buki_weapon == "":
			_try_tame()   # Fase 8: botão direito DOMA o inimigo mirado
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Corpo a corpo. A pistola da Yami e as armas da Buki também usam o botão
		# esquerdo (têm tratamento próprio em `_process_yami_pistol` /
		# `_process_buki_arma`) — quem está de arma na mão atira, não soca.
		if not _yami_pistol_active and _buki_weapon == "":
			_request_melee()

func toggle_combat_mode() -> void:
	_buki_guardar()          # sai do modo fruta com arma na mão -> a arma cai
	_buki_mostrar_arma("")
	if combat_mode == "fruit":
		combat_mode = "style"
	else:
		combat_mode = "fruit"
	var active_style: String = STYLES_LIST[current_style_idx]
	print("⚔️ Alternou Modo de Combate (R): ", combat_mode.to_upper(), " - Estilo: ", active_style)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_combat_mode"):
		hud.update_combat_mode(combat_mode, active_style, current_fruit_id)

func set_fighting_style(style_id: String) -> void:
	var idx := STYLES_LIST.find(style_id)
	if idx >= 0:
		current_style_idx = idx
		combat_mode = "style"
		var active_style: String = STYLES_LIST[current_style_idx]
		print("🥋 Novo Estilo de Luta Selecionado (Menu M): ", active_style)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("update_combat_mode"):
			hud.update_combat_mode(combat_mode, active_style, current_fruit_id)

# Toca um clipe de ESTILO retargetado (Mixamo -> rig por-nós) pelo ProceduralAnimator.
# O clipe fica em res://assets/animations/<nome>.res (bakeado do FBX do Mixamo).
func play_style_anim(anim_name: String) -> void:
	if _proc_anim == null:
		return
	# .res = assado do Mixamo (binário). .tres = autorado no editor de animação
	# em Python (texto) — o Godot carrega os dois igual.
	var path := "res://assets/animations/%s.res" % anim_name
	if not ResourceLoader.exists(path):
		path = "res://assets/animations/%s.tres" % anim_name
	if not ResourceLoader.exists(path):
		print("[StyleAnim] animação não encontrada: ", anim_name,
			" (.res vem do baker do Mixamo, .tres do tools/anim_editor)")
		return
	var a = load(path)
	if a is Animation:
		_proc_anim.play_baked(a)
		lock_movement(a.length + 0.1, anim_name)

# --- Teste de Animação: cicla por TODOS os .res bakeados (Mixamo) ---
var _style_anims: Array = []
var _style_anim_idx: int = -1

func _scan_style_anims() -> void:
	_style_anims.clear()
	var d := DirAccess.open("res://assets/animations/")
	if d:
		for f in d.get_files():
			var b := f.to_lower()
			# .res vem do baker do Mixamo; .tres, do editor em Python
			if (b.ends_with(".res") or b.ends_with(".tres")) and not _style_anims.has(f.get_basename()):
				_style_anims.append(f.get_basename())
	_style_anims.sort()

func cycle_style_anim(dir: int) -> void:
	if _style_anims.is_empty():
		_scan_style_anims()
	if _style_anims.is_empty():
		return
	if _style_anim_idx < 0:
		_style_anim_idx = 0
	else:
		_style_anim_idx = wrapi(_style_anim_idx + dir, 0, _style_anims.size())
	var nm: String = _style_anims[_style_anim_idx]
	play_style_anim(nm)
	print("🎬 [", _style_anim_idx + 1, "/", _style_anims.size(), "] ", nm)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_anim_name"):
		hud.show_anim_name("%d/%d  %s" % [_style_anim_idx + 1, _style_anims.size(), nm])

func _update_pivot() -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0)

# ---- Camera Feel: screen-shake (h_offset/v_offset NÃO afetam a mira) ----
func add_camera_shake(amount: float) -> void:
	if _is_authority:
		_shake = clampf(maxf(_shake, amount), 0.0, 1.0)

func _process(delta: float) -> void:
	if not _is_authority or _cam == null:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	var spd := clampf(planar / SPEED, 0.0, 1.2)
	var on_floor := is_on_floor()

	# --- offsets da câmera = SHAKE + BOB (balanço ao andar/correr) ---
	var sh := _shake * 0.09
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 3.5, 0.0)
	var sx := randf_range(-sh, sh)
	var sy := randf_range(-sh, sh)
	# Head bob: frequência e amplitude crescem com a velocidade (só andando no chão).
	var moving := spd > 0.05 and on_floor
	_bob_t += delta * (4.0 + spd * 9.0)
	var amp := (spd * 0.024) if moving else 0.0
	_cam.h_offset = lerpf(_cam.h_offset, sx + cos(_bob_t) * amp, 0.5)
	_cam.v_offset = lerpf(_cam.v_offset, sy + absf(sin(_bob_t)) * amp, 0.5)

	# ---------------------------------------------------------------- FOV
	# Degraus por ESTADO, não uma rampa só: parado / andando / correndo / sprint.
	# O salto entre correr e sprintar é o que faz o Shift "dar o clique" — numa
	# rampa linear ele passa despercebido.
	_fov_punch = maxf(_fov_punch - delta * 22.0, 0.0)
	var ganho := 0.0
	if spd > 0.05:
		ganho = lerpf(FOV_G_ANDANDO, FOV_G_CORRENDO, clampf(spd, 0.0, 1.0))
		if _is_sprinting():
			ganho = lerpf(ganho, FOV_G_SPRINT, clampf((spd - 0.7) / 0.5, 0.0, 1.0))
	if not on_floor:
		ganho += FOV_G_AR                    # no ar abre um pouco: sensação de queda
	var alvo_fov: float = FOV_BASE + ganho * FOV_INTENSIDADE - _fov_punch
	# LUNETA DA SNIPER (Buki C, botão direito): o FOV desaba pra 22° — ~3x de
	# aumento. Sobrescreve o FOV de velocidade de propósito: mirar tem prioridade
	# sobre "respirar".
	if _buki_scope:
		alvo_fov = 22.0
	# Abre RÁPIDO e fecha DEVAGAR. Simétrico dá a impressão de a câmera "respirar"
	# junto com cada tranco do passo.
	var vel_fov := 9.0 if alvo_fov > _cam.fov else 3.5
	_cam.fov = lerpf(_cam.fov, alvo_fov, vel_fov * delta)

	# Camera tilt: rolagem ao andar de lado + leve gingado no ritmo do passo.
	var right := Basis(Vector3.UP, _yaw) * Vector3(1, 0, 0)
	var strafe := clampf(velocity.dot(right) / SPEED, -1.0, 1.0)
	var tilt := -strafe * 3.5 + (sin(_bob_t) * spd * 1.2 if moving else 0.0)
	_cam.rotation.z = lerpf(_cam.rotation.z, deg_to_rad(tilt), 6.0 * delta)

	# Recuo da câmera ao correr (só 3a pessoa)
	if not _first_person and _spring:
		_spring.spring_length = lerpf(_spring.spring_length, cam_distance + spd * 0.9, 4.0 * delta)

	# Shake ao aterrissar
	if on_floor and not _was_floor:
		add_camera_shake(0.3)
	_was_floor = on_floor

	# ------------------------------------------- EFEITOS DE VELOCIDADE
	# Antes só a vinheta era visível: ela entrava em spd 0.4 e as linhas só em
	# 0.85, que quase nunca se alcança — o resultado prático era "a tela escurece".
	# Agora quatro efeitos entram em faixas DIFERENTES, então a sensação cresce
	# por camadas em vez de só escurecer:
	#   0.35 -> arrasto radial (o mundo escorre nas bordas)
	#   0.50 -> linhas de velocidade
	#   0.62 -> aberração cromática
	#   0.70 -> vinheta (por último, e mais fraca que antes)
	var vel_fx: float = spd * (1.15 if _is_sprinting() else 1.0)
	ScreenFX.set_borrao(clampf((vel_fx - 0.35) * 0.7, 0.0, 0.5))
	ScreenFX.set_speed_lines(clampf((vel_fx - 0.50) * 0.8, 0.0, 0.4))
	ScreenFX.set_aberracao_base(clampf((vel_fx - 0.62) * 0.8, 0.0, 0.3))
	ScreenFX.set_vignette(clampf((vel_fx - 0.70) * 0.6, 0.0, 0.2))

func _physics_process(delta: float) -> void:
	if not _is_authority:
		_remote_process(delta)   # player de outro cliente: só reproduz o estado replicado
		return
	for g in _pistols:
		if is_instance_valid(g):
			g.visible = _rapid_fire or _yami_pistol_active
	energy = minf(energy + ENERGY_REGEN * delta, max_energy)   # regen contínua de energia
	if _yami_shot_cooldown > 0.0:
		_yami_shot_cooldown = maxf(_yami_shot_cooldown - delta, 0.0)
	# RECARGA CONGELA DURANTE UMA HABILIDADE (regra do dono do projeto).
	# Enquanto um golpe está em andamento, a recarga das OUTRAS técnicas para de
	# correr — só a do próprio golpe em uso continua. Sem isso dava para segurar
	# um golpe longo (Black Hole, 7 s de trava) e sair dele com a barra inteira
	# recarregada de graça: o tempo de um golpe pagava o tempo de todos.
	var em_uso := _slot_em_uso()
	for slot_k in _skill_cooldowns.keys():
		if _skill_cooldowns[slot_k] <= 0.0:
			continue
		if em_uso != "" and slot_k != em_uso:
			continue                       # congelado: outra habilidade está ativa
		_skill_cooldowns[slot_k] = maxf(_skill_cooldowns[slot_k] - delta, 0.0)
	if _yami_pistol_active:
		_process_yami_pistol(delta)
	if _buki_weapon != "":
		_process_buki_arma(delta)   # arma na mão: mira, cadência e munição
	# HOLD-TO-CAST / RAJADA Z: enquanto a tecla está SEGURADA (ou a rajada Z ativa), o
	# personagem fica PARADO — inclusive NO AR, sem gravidade — até soltar a tecla ou
	# as balas acabarem. Só a câmera continua livre (mira). A rajada dispara aqui.
	if _charging or _rapid_fire or _movement_locked_timer > 0.0 or (has_meta("is_frozen") and get_meta("is_frozen")) or (has_meta("in_vortex") and get_meta("in_vortex")) or (has_meta("in_kurouzu") and get_meta("in_kurouzu")) or (has_meta("in_black_hole") and get_meta("in_black_hole")):
		if _charging and not (has_meta("is_casting") and get_meta("is_casting")):
			_charging = false          # cast foi interrompido (ex.: dano) -> destrava
		else:
			velocity = Vector3.ZERO    # congela no lugar (sem gravidade)
			if _breath:
				_breath.set_running(false)
			# Rajada Z: vira o corpo p/ a direção da mira (pose de pistoleiro) + coice decai.
			if _rapid_fire and _char_model:
				_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 18.0 * delta)
			if _gun_recoil > 0.0:
				_gun_recoil = maxf(_gun_recoil - delta * 7.0, 0.0)
			if _proc_anim:
				# Na RAJADA Z não passa charge_slot: senão herda o active_skill ("C") e o
				# animator aplica o tremor de torso do Gatling, quebrando a pose das pistolas.
				var slot_to_pass = "" if _pose_de_arma() else (_charge_slot if _charging else get_meta("active_skill", ""))
				_proc_anim.update(velocity, is_on_floor(), false, delta, _pitch, false, _charging, slot_to_pass, "", _pose_de_arma(), _gun_recoil)
			move_and_slide()
			_tick_rapid_fire(delta)    # dispara as balas de fogo/gelo enquanto a rajada dura

			if _movement_locked_timer > 0.0:
				_movement_locked_timer -= delta
				
			return

	# Direcao relativa a ORIENTACAO REAL da camera (nada de adivinhar o yaw).
	var f := 0.0  # frente(+)/tras(-)
	var r := 0.0  # direita(+)/esquerda(-)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    f += 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  f -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): r += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  r -= 1.0

	# Base do pivo da camera pura (yaw), sem distorcao de pitch
	var cam_basis := Basis.from_euler(Vector3(0, _yaw, 0))
	var forward := -cam_basis.z
	var right := cam_basis.x

	var dir := (forward * f + right * r)
	if dir.length() > 1.0:
		dir = dir.normalized()
	# Rajada (Mera/Hie Z): fica PARADO enquanto atira; só a câmera gira. Volta a
	# andar ao soltar o botão ou acabar as balas (release_charge zera _rapid_fire).
	if _rapid_fire:
		dir = Vector3.ZERO

	# Corrida (Shift): Aumenta a velocidade em 1.5x ao segurar Shift enquanto se move
	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and dir.length_squared() > 0.01
	if _long_jump_t > 0.0:
		_long_jump_t -= delta
	# Borda do Espaço: salto longo/vault só disparam na BATIDA da tecla (não segurando).
	var space_down := Input.is_key_pressed(KEY_SPACE) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var space_just := space_down and not _space_was
	_space_was = space_down

	# POUSO DE PRECISÃO (#4): Espaço apertado NO AR (caindo) arma um rolamento; ao
	# tocar o chão após uma queda real, o player rola e PRESERVA o embalo + poeira.
	var on_floor_now := is_on_floor()
	if not on_floor_now:
		_fall_peak = maxf(_fall_peak, -velocity.y)
		if space_just and velocity.y < 3.0 and not _is_climbing:
			_precision_armed = true
	elif not _was_on_floor:                       # acabou de tocar o chão
		if _precision_armed and _fall_peak > 9.0:
			_long_jump_t = maxf(_long_jump_t, 0.28)
			_roll_t = 0.4                 # dispara a animação de rolamento
			_land_puff()
		_fall_peak = 0.0
		_precision_armed = false
	_was_on_floor = on_floor_now
	if _roll_t > 0.0:
		_roll_t -= delta

	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)

	var q_pressed := Input.is_physical_key_pressed(KEY_Q) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if q_pressed and _dash_cooldown <= 0.0 and _dash_t <= 0.0 and not _charging and not _rapid_fire and not _yami_pistol_active:
		_is_aiming_dash = true
	elif not q_pressed and _is_aiming_dash:
		_is_aiming_dash = false
		_dash_t = DASH_TIME
		_roll_t = DASH_TIME               # dispara a animação de rolamento
		_dash_cooldown = DASH_COOLDOWN
		set_meta("damage_immune", true)
		# Direção = TECLA segurada (W frente, D lado, S ré...). Sem tecla nenhuma,
		# usa a frente da câmera. Os dois já vêm do yaw puro, sem pitch: o dash é
		# sempre horizontal, e a suspensão da gravidade não vira empuxo.
		# Travada aqui: a esquiva vai aonde o jogador apontou ao disparar, e girar
		# a câmera no meio do dash não a curva.
		_dash_dir = dir.normalized() if dir.length_squared() > 0.01 else forward
		FxUtil.dash_effect(get_tree().current_scene, global_position, _dash_dir)

	# Consome o tempo de dash DEPOIS do gatilho, para o disparo já andar neste frame.
	# `dash_step` é quanto do dash cabe no frame: no último ele é MENOR que o delta.
	# Sem isso o dash anda um frame inteiro a mais (o `_dash_t` não zera exato — 1/60
	# não tem representação binária finita) e passa ~4% da distância pedida.
	var dash_step := 0.0
	if _dash_t > 0.0:
		dash_step = minf(_dash_t, delta)
		_dash_t = maxf(_dash_t - delta, 0.0)
		if _dash_t <= 0.0:
			set_meta("damage_immune", false) # Finaliza a invencibilidade


	var effective_speed := SPEED * speed_multiplier * (1.5 if is_sprinting else 1.0)
	if _long_jump_t > 0.0:
		effective_speed *= 1.5   # Parkour: impulso horizontal (salto longo / vault)

	# Escalada: no ar, segure ESPAÇO enquanto avança contra uma parede vertical.
	# W/sobe e S/desce; ao soltar Espaço ou perder a parede, a gravidade volta.
	var wants_climb := Input.is_key_pressed(KEY_SPACE) and f > 0.0
	var wall_normal := _climbable_wall_normal(dir)
	if _is_climbing and (not wants_climb or wall_normal == Vector3.ZERO):
		_is_climbing = false
	if not _is_climbing and wants_climb and not is_on_floor() and wall_normal != Vector3.ZERO:
		_is_climbing = true

	# WALL RUN (#3): no ar, CORRENDO (Shift) rente a uma parede LATERAL -> corre por ela.
	var side_wall := _wall_side_normal(dir) if not _is_climbing else Vector3.ZERO
	var wall_running := not _is_climbing and not is_on_floor() and is_sprinting and f > 0.0 and side_wall != Vector3.ZERO and velocity.y < 5.0

	# Recarrega as cargas do Geppo assim que apoiar no chão ou em paredes/escada
	if on_floor_now or _is_climbing or wall_running:
		_geppo_count = 0

	if _is_climbing:
		# Uma leve pressão contra a parede preserva o contato de colisão entre
		# frames; sem isso, ao mover apenas no eixo Y a escalada terminaria logo.
		# W sobe / S desce (#7), parado = segura; A/D faz travessia lateral (#8).
		var tang := wall_normal.cross(Vector3.UP).normalized()   # horizontal ao longo da parede
		velocity.x = -wall_normal.x * CLIMB_STICK_SPEED + tang.x * r * CLIMB_SPEED * 0.8
		velocity.z = -wall_normal.z * CLIMB_STICK_SPEED + tang.z * r * CLIMB_SPEED * 0.8
		velocity.y = CLIMB_SPEED * clampf(f, -1.0, 1.0)
		# SUBIR NA BEIRADA / MANTLE (#6): chegou ao TOPO (cabeça livre acima da beirada)
		# e empurra pra cima (W) -> impulso pra cima + pra frente e larga a parede.
		if f > 0.1 and _head_clear_of_wall(wall_normal):
			velocity = -wall_normal * 6.0 + Vector3.UP * (JUMP_VELOCITY * 0.8)
			_is_climbing = false
			_long_jump_t = 0.25
	elif wall_running:
		# WALL RUN: quase sem gravidade + corre ao longo da parede; Espaço = pula pra longe.
		velocity.y = maxf(velocity.y - GRAVITY * 0.12 * delta, -1.5)   # "cola" e cai devagar
		var tangent := side_wall.cross(Vector3.UP).normalized()        # horizontal, ao longo da parede
		if tangent.dot(forward) < 0.0:
			tangent = -tangent                                          # sentido = pra onde o player olha
		velocity.x = tangent.x * effective_speed - side_wall.x * 2.0    # corre + encosta na parede
		velocity.z = tangent.z * effective_speed - side_wall.z * 2.0
		if space_just:
			velocity = side_wall * 9.0 + Vector3.UP * (JUMP_VELOCITY * 0.85)   # empurra PRA LONGE
			_long_jump_t = 0.3
	else:
		# Gravidade.
		if not is_on_floor():
			velocity.y -= GRAVITY * delta

		# Pulo + PARKOUR.
		if is_on_floor() and is_sprinting and f > 0.0 and _long_jump_t <= 0.0 and _low_obstacle_ahead(dir):
			# VAULT automático: correndo contra um obstáculo BAIXO -> pula por cima.
			velocity.y = JUMP_VELOCITY * 0.7
			_long_jump_t = 0.35
		elif space_just and is_on_floor():
			# Salto longo SÓ na batida do Espaço correndo (evita velocidade infinita).
			if is_sprinting and f > 0.0:
				velocity.y = JUMP_VELOCITY * 0.95   # SALTO LONGO (Shift+Espaço)
				_long_jump_t = 0.55
			else:
				velocity.y = JUMP_VELOCITY * jump_multiplier   # pulo normal
		elif space_down and is_on_floor():
			velocity.y = JUMP_VELOCITY * jump_multiplier       # segurar Espaço = pulo normal
		elif space_just and not is_on_floor() and not _is_climbing and not wall_running and _geppo_count < max_geppo:
			# GEPPO (Técnica do CP9 / Pulo Duplo): chuta o ar com anel de ar comprimido!
			_geppo_count += 1
			_fall_peak = 0.0
			_precision_armed = false
			if dir.length_squared() > 0.01:
				velocity.x = dir.x * effective_speed * 1.35
				velocity.z = dir.z * effective_speed * 1.35
				velocity.y = JUMP_VELOCITY * jump_multiplier * 0.95
			else:
				velocity.y = JUMP_VELOCITY * jump_multiplier * 1.15
			add_camera_shake(0.28)
			AudioFX.whoosh(get_tree().current_scene, global_position, 1.35)
			AudioFX.snap(get_tree().current_scene, global_position, 0.85)
			FxUtil.geppo_effect(get_tree().current_scene, global_position + Vector3(0, -0.75, 0), dir, _yaw, self)
			if _proc_anim:
				_proc_anim.trigger_recovery("Z")

		if dash_step > 0.0:
			# Velocidade constante na direção travada, derivada da distância alvo.
			# O fator dash_step/delta encurta SÓ o último frame (nos demais é 1.0).
			# Sobrescrever o `velocity` inteiro zera o Y de propósito: durante o
			# dash NÃO há gravidade (nem queda, nem subida — só o plano).
			velocity = _dash_dir * (DASH_DISTANCE / DASH_TIME) * (dash_step / delta)
		else:
			velocity.x = dir.x * effective_speed
			velocity.z = dir.z * effective_speed

	# A FRENTE do personagem se move dinamicamente durante a locomoção.
	if _char_model:
		if _is_climbing and wall_normal != Vector3.ZERO:
			# Convenção do projeto: FRENTE = -Z. Ao escalar, a frente vira PARA DENTRO
			# da parede, ou seja, o -Z do modelo aponta ao longo de -wall_normal
			# (wall_normal aponta da parede para o jogador). Daí atan2(wn.x, wn.z).
			var target_rot := atan2(wall_normal.x, wall_normal.z)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, target_rot, 24.0 * delta)
		elif _dash_t > 0.0:
			var move_rot := atan2(-_dash_dir.x, -_dash_dir.z)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, move_rot, 35.0 * delta)
		elif dir.length_squared() > 0.01:
			var move_rot := atan2(-dir.x, -dir.z)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, move_rot, 35.0 * delta)
		else:
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 24.0 * delta)

	# Animação: rig procedural (por-nós) OU esqueletal (skinnado).
	if _skel_anim:
		_skel_anim.update(velocity, is_on_floor(), _is_climbing, delta, is_sprinting)
	elif _proc_anim:
		var parkour := ""
		if wall_running:
			parkour = "wall_run"
		elif _roll_t > 0.0:
			parkour = "roll"
		elif _long_jump_t > 0.0 and not on_floor_now:
			parkour = "long_jump"
		_proc_anim.update(velocity, is_on_floor(), _is_climbing, delta, _pitch, is_sprinting, false, "", parkour, _pose_de_arma(), _gun_recoil)

	_update_breath()
	_tick_rapid_fire(delta)   # Mera Z: dispara as balas de fogo enquanto a rajada está ativa
	_tick_melee(delta)        # corpo a corpo: janela de 2 s do combo + recuperação

	# Rede (Fase 4): a autoridade publica seu estado p/ os outros clientes replicarem.
	net_velocity = velocity
	net_on_floor = is_on_floor()
	if _char_model:
		net_facing = _char_model.rotation.y

	# Processamento de Supressão da Passiva Yami Yami
	if is_suppressed:
		suppression_timer -= delta
		if suppression_timer <= 0.0:
			is_suppressed = false
			print("✨ Poderes reativados!")

	# Verificação de Void (Morte ao cair no Void)
	if SkillSystem.process_void_check(self):
		return

	# Empurrão externo: somado DEPOIS da locomoção ter escrito velocity, e antes
	# de mover. Decai sozinho, então o controle volta ao jogador em ~1 s.
	if _kb_impulso.length_squared() > 0.01:
		velocity.x += _kb_impulso.x
		velocity.z += _kb_impulso.z
		_kb_impulso = _kb_impulso.move_toward(Vector3.ZERO, KB_DECAIMENTO * delta * _kb_impulso.length())
	else:
		_kb_impulso = Vector3.ZERO
	move_and_slide()

## Posiciona o VFX de fôlego na frente da boca (segue cabeça + facing -Z) e regula
## a intensidade pela velocidade. Só "respira forte" correndo no chão.
func _update_breath() -> void:
	if _breath == null:
		return
	if _char_model and _head_node and is_instance_valid(_head_node):
		var yaw := _char_model.rotation.y
		var fwd := Basis(Vector3.UP, yaw) * Vector3(0, 0, -1)   # frente do projeto = -Z
		# À frente da boca (não atravessa o rosto) e um tico abaixo do centro da cabeça.
		_breath.global_position = _head_node.global_position + fwd * 0.28 + Vector3(0, -0.04, 0)
		_breath.rotation = Vector3(0, yaw, 0)   # local +Z = costas -> baforada vai p/ trás
	var planar := Vector2(velocity.x, velocity.z).length()
	var running := planar > 1.0 and is_on_floor() and not _is_climbing
	_breath.set_running(running)
	_breath.set_intensity(planar / SPEED)   # 1.0 = corrida normal, ~1.5 = sprint

## Chamado pelo braço elástico (GomuArm) quando o punho retorna ao corpo:
## dispara o tranco de recepção (chicote) na animação procedural.
func trigger_recovery_anim(slot: String = "Z") -> void:
	if _proc_anim:
		_proc_anim.trigger_recovery(slot)

# ---- Fase 8: DOMAR inimigo (botão direito) ----
# DESATIVADO por ora (Fase 9): muito conteúdo pendente (frutas/estilos). Código
# mantido; é só religar TAMING_ENABLED = true quando quiser retomar os companions.
const TAMING_ENABLED := false

# Raycast da câmera; se mirar um inimigo perto, pede a doma ao SERVIDOR (autoridade).
func _try_tame() -> void:
	if not TAMING_ENABLED or _cam == null:
		return
	var from := _cam.global_position
	var to := from + (-_cam.global_transform.basis.z) * 9.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col = hit.get("collider")
	if col and col.is_in_group("enemy"):
		_request_tame(str(col.name))

func _request_tame(enemy_name: String) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_tame(enemy_name, str(name).to_int())
	else:
		_net_tame.rpc_id(1, enemy_name, str(name).to_int())

@rpc("any_peer", "reliable")
func _net_tame(enemy_name: String, owner_peer: int) -> void:
	if multiplayer.is_server():
		_do_tame(enemy_name, owner_peer)

func _do_tame(enemy_name: String, owner_peer: int) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.name == enemy_name and e.has_method("tame"):
			e.tame(owner_peer)
			return

## Player REMOTO (controlado por outro cliente): não simula física (a posição vem
## replicada). Só reproduz a animação a partir do estado replicado e vira o modelo
## pelo facing replicado, pra parecer vivo na tela dos outros.
func _remote_process(delta: float) -> void:
	velocity = net_velocity
	_buki_apontar_canhao()   # canhão-corpo da Buki acompanha o facing replicado
	if _char_model:
		_char_model.rotation.y = lerp_angle(_char_model.rotation.y, net_facing, 18.0 * delta)
	if _skel_anim:
		_skel_anim.update(net_velocity, net_on_floor, false, delta, false)
	elif _proc_anim:
		_proc_anim.update(net_velocity, net_on_floor, false, delta, _pitch, false)

# Parkour: há um obstáculo BAIXO logo à frente? (bate na altura do joelho, mas está
# livre na altura da cabeça -> dá pra pular por cima = vault).
func _low_obstacle_ahead(move_dir: Vector3) -> bool:
	var flat := Vector3(move_dir.x, 0.0, move_dir.z)
	if flat.length_squared() < 0.01:
		return false
	flat = flat.normalized()
	var space := get_world_3d().direct_space_state
	var base := global_position
	var low_q := PhysicsRayQueryParameters3D.create(base + Vector3(0, -0.4, 0), base + Vector3(0, -0.4, 0) + flat * 1.2)
	low_q.exclude = [get_rid()]
	if space.intersect_ray(low_q).is_empty():
		return false                       # nada na altura do joelho -> não é vault
	var hi_q := PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.7, 0), base + Vector3(0, 0.7, 0) + flat * 1.2)
	hi_q.exclude = [get_rid()]
	return space.intersect_ray(hi_q).is_empty()   # livre em cima -> obstáculo é baixo

# Wall run (#3): procura uma parede à ESQUERDA ou à DIREITA (perpendicular ao
# movimento) dentro de ~0.85m. Retorna a normal da parede (aponta pra fora dela).
func _wall_side_normal(move_dir: Vector3) -> Vector3:
	var flat := Vector3(move_dir.x, 0.0, move_dir.z)
	if flat.length_squared() < 0.01:
		return Vector3.ZERO
	flat = flat.normalized()
	var side := flat.cross(Vector3.UP)      # perpendicular horizontal
	var space := get_world_3d().direct_space_state
	var base := global_position
	for s in [side, -side]:
		var q := PhysicsRayQueryParameters3D.create(base, base + s * 0.85)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			if absf(n.y) < 0.3:             # parede vertical (não chão/teto)
				return n
	return Vector3.ZERO

# Mantle (#6): true quando a CABEÇA já passou do topo da parede (raio à altura da
# cabeça, em direção à parede, não bate em nada) -> dá pra subir na beirada.
func _head_clear_of_wall(wall_normal: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.95, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from - wall_normal * 0.9)  # -normal = pra parede
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()

# Poeira do pouso de precisão (#4).
func _land_puff() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 85.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -5.0, 0)
	pm.scale_min = 0.2
	pm.scale_max = 0.5
	pm.color_ramp = FxUtil.gradient([Color(0.82, 0.79, 0.72, 0.7), Color(0.82, 0.79, 0.72, 0)])
	var burst := FxUtil.particles(24, 0.5, true, pm, FxUtil.grain(0.3), 1.0)
	world.add_child(burst)
	burst.global_position = global_position + Vector3(0, -0.7, 0)
	FxUtil.autofree(burst, 0.8)

func _climbable_wall_normal(move_direction: Vector3) -> Vector3:
	# Usa as colisões do último movimento. Isso evita RayCast extra e faz a
	# escalada funcionar em qualquer StaticBody3D, inclusive os blocos do mapa.
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var normal := collision.get_normal()
		if abs(normal.y) <= CLIMB_WALL_NORMAL_MAX_Y and move_direction.dot(normal) < -0.15:
			return normal
	return Vector3.ZERO

# ----------------------------------------------------------- troca de modelo ---
# API pública usada pelo menu de Personagens (muda modelo e equipa a Akuma no Mi correta).
func set_character(cid: String) -> void:
	# Coage aqui também: abaixo o `match cid` escolhe a fruta inicial, e ele
	# precisa ver o personagem que de fato foi carregado.
	if not ELENCO_LIBERADO.has(cid):
		print("[Personagem] '", cid, "' está trancado — usando ", ELENCO_LIBERADO[0])
		cid = ELENCO_LIBERADO[0]
	_setup_character_model(cid)
	match cid:
		"ace":
			current_fruit_id = "mera_mera"
			combat_mode = "fruit"
		"buggy":
			current_fruit_id = "bara_bara"
			combat_mode = "fruit"
		"nami":
			current_fruit_id = "goro_goro"
			combat_mode = "fruit"
		"blackbeard":
			current_fruit_id = "yami_yami"
			combat_mode = "fruit"
		"crocodile":
			current_fruit_id = "suna_suna"
			combat_mode = "fruit"
		"base", _:
			current_fruit_id = "gomu_gomu"
			combat_mode = "fruit"
	var active_style: String = STYLES_LIST[current_style_idx] if current_style_idx < STYLES_LIST.size() else ""
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_combat_mode"):
		hud.update_combat_mode(combat_mode, active_style, current_fruit_id)

func _setup_character_model(cid: String) -> void:
	# GUARDA DA TRAVA DE ELENCO — aqui, não no set_character.
	# Este é o ponto por onde TODOS passam: menu, rede, e principalmente a troca
	# automática de aparência do equip_fruit() (o Main equipa suna_suna ao nascer,
	# o que virava Crocodile mesmo com o elenco trancado).
	if not ELENCO_LIBERADO.has(cid):
		cid = ELENCO_LIBERADO[0]

	if _char_model:
		_char_model.queue_free()
	if _animator:
		_animator.queue_free()

	character_id = cid
	# limpa estado do modelo anterior
	if _skel_anim:
		_skel_anim.queue_free()
		_skel_anim = null
	if _proc_anim:
		_proc_anim.queue_free()
		_proc_anim = null
	_pistols = []
	_buki_armas = {}          # morrem junto com o _char_model; o pivô do X é solto abaixo
	_buki_visual = ""
	_is_skinned = false

	var char_data := CharacterBuilder.build_character(cid)
	_char_model = char_data["node"]
	_is_skinned = char_data.get("skinned", false)   # antes do fit (afeta a escala)
	add_child(_char_model)
	_fit_model_to_body()   # normaliza tamanho e assenta os pés no chão

	# --- PERSONAGEM SKINNADO (Skeleton3D, ex.: Meshy AI) ---
	# RIG ÚNICO: o esqueleto do Meshy é mapeado nos 13 papéis do rig A pelo
	# SkeletonDriver (via BodyScanner), então ele usa o MESMO ProceduralAnimator
	# e os MESMOS clipes do Mixamo que os personagens voxel. O SkeletalAnimator
	# e os walks nativos por modelo ficaram obsoletos.
	if _is_skinned:
		_animator = null   # skinnado não usa CharacterAnimator (rig por-nós)
		# DIREÇÃO: modelos Meshy nascem olhando +Z (pra câmera); a convenção do jogo é
		# FRENTE = -Z. Giro a Armature 180° pra alinhar (o facing gira o _char_model).
		var arm := _char_model.find_child("Armature", true, false)
		if arm is Node3D:
			(arm as Node3D).rotation.y += PI
		# O AnimationPlayer do próprio modelo brigaria com o driver pelos ossos.
		var model_ap: AnimationPlayer = char_data.get("anim_player")
		if model_ap:
			model_ap.active = false
		_setup_procedural_anim(cid)
		_head_node = _char_model.find_child("Head", true, false) as Node3D
		# A pistola TAMBÉM vale no skinnado. Ela ficava de fora por acidente: o
		# `return` logo abaixo pulava a chamada que está depois deste bloco, então
		# nenhum personagem skinnado nunca teve pistola no golpe Z.
		#
		# Isso só passou a funcionar agora porque o `_attach_pistol` acha o membro
		# por `find_child("ForeArm_R")`, e até hoje os proxies do rig se chamavam
		# `RoleProxy_ForeArm_R` (ver docs/erros.md, 2026-08-10). Consertar um sem
		# o outro não adiantaria nada.
		#
		# ⚠️ O proxy GIRA com a animação mas não TRANSLADA — a pistola nasce na
		# posição de repouso da mão e acompanha a rotação, não o deslocamento do
		# osso. Mesma limitação das armas da Buki Buki.
		_attach_pistol(_char_model)
		_attach_buki_arsenal(_char_model)   # arsenal da Buki (oculto até empunhar)
		return

	_attach_pistol(_char_model)   # pistola na mão direita (oculta até a rajada Z)
	_attach_buki_arsenal(_char_model)   # arsenal da Buki (oculto até empunhar)

	# Marcador Visual de COSTAS: Mochila Dourada Emissiva em z = -0.35
	var back_marker := MeshInstance3D.new()
	back_marker.name = "BackMarkerVisual"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.42, 0.52, 0.18)
	back_marker.mesh = marker_mesh
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.8, 0.1)
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(1.0, 0.75, 0.1)
	marker_mat.emission_energy_multiplier = 2.5
	back_marker.material_override = marker_mat
	back_marker.position = Vector3(0, 0.1, 0.35)
	_char_model.add_child(back_marker)

	# Marcador Visual de FRENTE (PEITO): Insígnia Vermelha no Peito em z = -0.35
	var chest_marker := MeshInstance3D.new()
	chest_marker.name = "ChestMarkerFront"
	var chest_mesh := BoxMesh.new()
	chest_mesh.size = Vector3(0.35, 0.35, 0.15)
	chest_marker.mesh = chest_mesh
	var chest_mat := StandardMaterial3D.new()
	chest_mat.albedo_color = Color(1.0, 0.15, 0.15)
	chest_mat.emission_enabled = true
	chest_mat.emission = Color(1.0, 0.2, 0.1)
	chest_mat.emission_energy_multiplier = 3.0
	chest_marker.material_override = chest_mat
	chest_marker.position = Vector3(0, 0.15, -0.35)
	_char_model.add_child(chest_marker)

	_animator = CharacterAnimator.new()
	_animator.character_id = cid
	_animator.animation_player = char_data["anim_player"]
	add_child(_animator)
	# Os paths procedurais das animações são relativos ao CharacterRoot.
	# Deixamos isso explícito para não depender do valor padrão do Godot.
	if _animator.animation_player:
		_animator.animation_player.root_node = NodePath("..")
		# Desliga o AnimationPlayer antigo: ele mira nomes de nós antigos e
		# brigaria com a animação procedural que dirige o rig novo diretamente.
		_animator.animation_player.active = false

	_setup_procedural_anim(cid)

	# Fôlego (VFX): cacheia a cabeça (âncora da boca) e garante o componente.
	_head_node = _char_model.find_child("Head", true, false) as Node3D
	if _breath == null:
		_breath = load("res://VFX/BreathVFX.tscn").instantiate()
		add_child(_breath)   # filho do Player (sem a escala do rig)

	print("🎭 Modelo 3D Voxel Carregado: ", cid.capitalize())

# Animação PROCEDURAL: mede o corpo (BodyScanner) e dirige o rig em runtime.
# Serve os DOIS tipos de personagem — o BodyScanner resolve os 13 papéis em nós
# (voxel) ou em ossos via SkeletonDriver (skinnado), e devolve o mesmo perfil.
func _setup_procedural_anim(cid: String) -> void:
	if _proc_anim:
		_proc_anim.queue_free()
	_proc_anim = ProceduralAnimator.new()
	add_child(_proc_anim)
	_proc_anim.setup(BodyScanner.scan(_char_model))
	# Corpo girado 180° em Y: os offsets são autorados p/ FRENTE = -Z e precisam
	# ser espelhados. Vale só pro SkinPivot do Buggy — no SKINNADO a basis do
	# SkeletonDriver já inclui o giro da Armature, então marcar aqui aplicaria a
	# correção DUAS vezes e os membros balançariam ao contrário.
	if not _is_skinned and cid == "buggy" and _char_model.has_node("SkinPivot"):
		_proc_anim.is_backwards = true

# Normaliza o modelo importado (que vem grande) para a altura do jogador e
# assenta os PÉS no fundo da colisão (senão o boneco fica gigante e flutuando).
# Altura ÚNICA de TODOS os personagens jogáveis (voxel + skinnado) -> todos do mesmo
# tamanho. Basta mudar este número p/ deixar todos maiores/menores.
const CHAR_TARGET_H := 1.5
const MODEL_TARGET_H := CHAR_TARGET_H    # voxel
const SKINNED_TARGET_H := CHAR_TARGET_H  # skinnado (Meshy)
const FEET_Y := -0.8           # fundo da colisão = chão

# Cria a PISTOLA (oculta) na ponta do antebraço direito. Fica invisível até a rajada
# Z (mera/hie), quando `_pistol.visible` é ligado. Cano ao longo de -Y = aponta pra
# frente quando o braço estende na pose de mira (_finger_gun).
func _attach_pistol(model: Node3D) -> void:
	_pistols = []
	if model == null:
		return
	for side in ["ForeArm_L", "ForeArm_R"]:
		var arm := model.find_child(side, true, false)
		if not (arm is Node3D):
			continue
		var gun := PlayerModelKit.build_pistol()
		gun.position = Vector3(0, -0.36, 0.02)   # ponta do antebraço (mão)
		gun.visible = false
		(arm as Node3D).add_child(gun)
		_pistols.append(gun)

# ---------------------------------------------------------------- BUKI BUKI ---
# Constrói as QUATRO armas da fruta UMA VEZ, ocultas, junto com o personagem —
# exatamente como a pistola acima. Empunhar depois é só ligar a visibilidade.
#
# ⚠️ Por que não criar a arma na hora do saque: nó criado no golpe e mantido
# vivo entre golpes é indistinguível de VAZAMENTO para a auditoria
# (tools/dev_tests/test_frutas.gd conta nós antes/depois) — e, pior, cada troca
# de arma deixaria lixo na cena se um `queue_free` escapasse. Pré-construir
# custa 3 instâncias de .glb por personagem e elimina a classe de bug inteira.
func _attach_buki_arsenal(model: Node3D) -> void:
	for n in _buki_armas.values():
		if is_instance_valid(n):
			(n as Node).queue_free()
	_buki_armas = {}
	if is_instance_valid(_buki_pivot):
		_buki_pivot.queue_free()
	_buki_pivot = null
	_buki_visual = ""
	if model == null:
		return
	# O canhão do X não mora no braço: mora num pivô do CORPO, que gira com a
	# mira (o jogador inteiro virou o canhão).
	_buki_pivot = Node3D.new()
	_buki_pivot.name = "BukiPivot"
	_buki_pivot.position = Vector3(0, -0.15, 0)
	add_child(_buki_pivot)
	var braco := model.find_child("ForeArm_R", true, false) as Node3D
	for slot in BukiFX.SLOTS:
		var arma := BukiFX.arma_do_slot(slot)
		if arma == null:
			continue
		var papel := BukiFX.papel_do_slot(slot)
		var pai: Node3D = _buki_pivot if papel == "" else braco
		if pai == null:
			arma.free()          # rig sem ForeArm_R: essa arma simplesmente não existe
			continue
		arma.visible = false
		pai.add_child(arma)
		_buki_armas[slot] = arma

# PRESENTATION da arma empunhada — roda em TODOS os peers (chamada de dentro de
# `_fire_skill` e do `_net_buki_guardar`), então o adversário vê a arma na mão
# e vê o corpo virar canhão. "" = guardar tudo.
func _buki_mostrar_arma(slot: String) -> void:
	_buki_visual = slot
	for s in _buki_armas.keys():
		var n = _buki_armas[s]
		if not is_instance_valid(n):
			continue
		var ligar: bool = (s == slot)
		if ligar and not n.visible:
			BukiFX.onda_de_aco(n.get_parent())   # o aço descendo pelo membro
		n.visible = ligar
	_atualizar_visibilidade_corpo()

# O corpo some em DOIS casos: 1ª pessoa (já era) e canhão-corpo da Buki (X).
# Ficam no mesmo lugar porque brigavam: o `_apply_perspective` reacendia o corpo
# no meio da transformação.
func _atualizar_visibilidade_corpo() -> void:
	if _char_model == null:
		return
	_char_model.visible = (not _first_person) and _buki_visual != "X"

# Pistola, AABB e bake de profundidade -> PlayerModelKit (src/utils/).
func _fit_model_to_body() -> void:
	if _char_model == null:
		return
	var ab := PlayerModelKit.skeleton_aabb(_char_model) if _is_skinned else PlayerModelKit.model_aabb(_char_model)
	# Altura-alvo: skinnado (Meshy) é mais encorpado -> um pouco menor p/ casar com o mundo.
	var target_h := SKINNED_TARGET_H if _is_skinned else MODEL_TARGET_H
	if character_id == "blackbeard":
		target_h *= 1.5   # Barba Negra tem 1.5 de tamanho em comparação aos demais
	var ky := 1.0
	if ab.size.y > 0.01:
		ky = target_h / ab.size.y
	# Voxel: engrossa o eixo Z (1.85x). SKINNADO (Skeleton3D): escala UNIFORME —
	# escala não-uniforme num skeleton corrompe o skinning (transform NaN -> tela cinza).
	var zscale := ky if _is_skinned else ky * 1.85
	_char_model.scale = Vector3(ky, ky, zscale)
	# pés (base da AABB) no fundo da colisão
	_char_model.position.y = FEET_Y - ky * ab.position.y

# ---------------------------------------------------------------- combate ---
func take_damage(amount: float, attacker_pos: Vector3 = Vector3.ZERO, base_knockback: Vector3 = Vector3.ZERO) -> void:
	if get_meta("damage_immune", false) or get_meta("custom_pose", "") == "hibashira":
		print("🛡️ DANO E KNOCKBACK BLOQUEADOS! O usuário está IMUNE a danos durante a habilidade!")
		return

	# 1. INTERRUPÇÃO DE ATAQUE SOBRE DANO
	SkillSystem.interrupt_casting(self)

	if _animator:
		_animator.trigger_damage()
	elif _skel_anim:
		_skel_anim.play_one_shot("damage")

	health = maxf(health - amount, 0.0)
	# Feedback de dano: pisca vermelho, som de recepção e número flutuante.
	FxUtil.flash_red(_char_model)
	AudioFX.hurt(get_tree().current_scene, global_position + Vector3.UP * 1.0)
	FxUtil.damage_number(get_tree().current_scene, global_position + Vector3.UP * 1.7, amount, Color(1.0, 0.75, 0.2))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("on_player_damaged"):
		hud.on_player_damaged(amount, health, max_health)
	print("💥 Dano Recebido: ", amount, " | HP Restante: ", health, "/", max_health)

	# 2. KNOCKBACK ESCALADO E MODIFICADO POR AR E MOVIMENTO
	if base_knockback.length() > 0.1:
		# ⚠️ QUEM EMPURRA É O DONO DO CORPO, não quem calculou o dano.
		#
		# A `DamageZone` roda no SERVIDOR, então este `take_damage` roda na cópia
		# que o servidor tem da vítima. Se a vítima for de outro peer, mexer em
		# `velocity` aqui não vale nada: no quadro seguinte a replicação traz a
		# posição do dono e sobrescreve. Era por isso que ninguém tomava empurrão
		# em partida com dois PCs — e em um-jogador funcionava, porque lá o
		# servidor É o dono.
		#
		# Mando o knockback CRU, não o calculado: as duas regras que o modelam —
		# dobrar no ar e resistir andando contra — dependem de `is_on_floor()` e
		# do TECLADO da vítima. No servidor, `Input.is_key_pressed` lê o teclado
		# do HOST, não o do jogador que apanhou. Quem tem esses dados é o dono.
		if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
			var dono := get_multiplayer_authority()
			if multiplayer.get_peers().has(dono):
				net_apply_knockback.rpc_id(dono, base_knockback)
			return
		_aplicar_knockback(base_knockback)

	if health <= 0.0:
		die_and_respawn()

# Pedido do servidor para o DONO do corpo se empurrar. Só o servidor manda.
@rpc("any_peer", "call_local", "reliable")
func net_apply_knockback(base_knockback: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	_aplicar_knockback(base_knockback)

# Escala o empurrão pelas regras do jogo e aplica na própria velocidade.
# SEMPRE roda no dono do corpo — ver o comentário em take_damage.
func _aplicar_knockback(base_knockback: Vector3) -> void:
	if base_knockback.length() <= 0.1:
		return
	var final_knockback := SkillSystem.calculate_knockback(base_knockback, health, max_health)
	# Regra 1: Quando alguém é atingido no ar o knockback DOBRA.
	if not is_on_floor():
		final_knockback *= 2.0
		print("✈️ Atingido no AR! Knockback dobrado!")
	# Regra 2: O knockback pode ser reduzido em até 70% se tentar se mover para outra direção (nunca 100%).
	var f_kb := 0.0; var r_kb := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    f_kb += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  f_kb -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): r_kb += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  r_kb -= 1.0
	var move_attempt := ((-Basis.from_euler(Vector3(0, _yaw, 0)).z) * f_kb + (Basis.from_euler(Vector3(0, _yaw, 0)).x) * r_kb)
	if move_attempt.length_squared() > 0.01:
		move_attempt = move_attempt.normalized()
		var kb_dir := final_knockback.normalized()
		var dot := move_attempt.dot(kb_dir)
		if dot < 0.85: # Tentativa de mover para outra direção / resistir
			var reduction_pct := remap(clampf(dot, -1.0, 0.5), 0.5, -1.0, 0.0, 0.70)
			var mult := clampf(1.0 - reduction_pct, 0.30, 1.0) # Nunca menos que 30% (nunca reduzido completamente)
			final_knockback *= mult
			print("🛡️ Knockback Reduzido por Movimento (", int(reduction_pct * 100), "% resistido)!")
	# O componente HORIZONTAL vira impulso (senão a locomoção o sobrescreve no
	# próximo quadro); o VERTICAL entra direto na velocidade, porque o eixo Y não
	# é reatribuído pela locomoção — só pela gravidade.
	_kb_impulso += Vector3(final_knockback.x, 0.0, final_knockback.z)
	velocity.y += final_knockback.y
	print("🚀 Knockback Final Aplicado: ", final_knockback)


# Porta de entrada da MORTE — chegam aqui os dois caminhos: vida zerada (a
# DamageZone, no servidor) e queda no vazio (SkillSystem.process_void_check).
#
# Quem decide é sempre o PLACAR, no servidor: ele conta a morte, resolve de quem
# é a kill e manda o dono do corpo respawnar. Num cliente puro esta função não
# faz nada de propósito — o servidor enxerga a queda pela `position` replicada e
# declara a morte de lá. Sem placar na árvore (testes isolados), respawna direto.
func die_and_respawn() -> void:
	var caiu := global_position.y < Scoreboard.VOID_Y
	var placar := get_tree().get_first_node_in_group("scoreboard")
	if placar and placar.has_method("report_death"):
		placar.report_death(self, caiu)
	else:
		net_force_respawn()

# Respawn de verdade. Só o DONO do corpo pode se teleportar (quem não é
# autoridade tem a posição sobrescrita pela replicação no frame seguinte), por
# isso o servidor pede por RPC em vez de mover na marra.
@rpc("any_peer", "call_local", "reliable")
func net_force_respawn() -> void:
	# Só o servidor (peer 1) manda respawnar; 0 = chamada local, sem rede.
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	print("💀 MORTE REGISTRADA! Respawnando na plataforma...")
	if _animator:
		_animator.trigger_death()
	elif _skel_anim:
		_skel_anim.play_one_shot("death")

	# Se o jogador possuía uma fruta, devolve a fruta para a sua árvore
	if current_fruit_id != "":
		TreeAndFruitGenerator.respawn_fruit(current_fruit_id)
		current_fruit_id = ""
		speed_multiplier = 1.0
		jump_multiplier = 1.0

	# Morreu de arma na mão: ela some (em todos os peers — este RPC é call_local)
	# e o slot entra em recarga como em qualquer outro abandono.
	_buki_guardar()
	_buki_mostrar_arma("")

	health = max_health
	energy = max_energy
	velocity = Vector3.ZERO
	global_position = Scoreboard.RESPAWN   # centro da plataforma (zona sem buraco)

func suppress_skills_temporarily(duration: float) -> void:
	is_suppressed = true
	suppression_timer = duration
	StatusFX.aplicar(self, StatusFX.SILENCIADO, duration)   # aparece no canto da tela
	print("🚫 PODERES DESATIVADOS POR YAMI YAMI! Tempo restante: ", duration, "s")

func lock_movement(duration: float, skill_id: String = "") -> void:
	_movement_locked_timer = maxf(_movement_locked_timer, duration)
	set_meta("active_skill", skill_id)

# Começa a segurar a skill: congela + pausa animação (mira com o mouse).
func begin_charge(slot: String) -> void:
	if is_suppressed:
		print("❌ Poderes desativados (Yami Yami).")
		return
	if _skill_cooldowns.get(slot, 0.0) > 0.0:
		print("⏳ Habilidade [%s] em recarga! Aguarde %.1fs." % [slot, _skill_cooldowns[slot]])
		return
	if slot != "Z" and _yami_pistol_active:
		_yami_pistol_active = false
		for g in _pistols: if is_instance_valid(g): g.visible = false
		print("🌑 Yami Pistol desativada (Outra habilidade foi acionada).")
	# BUKI BUKI: a tecla não lança golpe — ela EMPUNHA a arma daquele slot (e o
	# saque já dá o primeiro tiro). Ver o bloco BUKI BUKI no fim do arquivo.
	if _buki_ativa():
		_buki_empunhar(slot)
		return
	if slot == "C" and combat_mode == "fruit" and current_fruit_id == "yami_yami" and not is_on_floor():
		print("❌ Black Hole requer contato com o solo!")
		return
	if slot == "Z" and combat_mode == "fruit" and current_fruit_id == "yami_yami":
		_yami_pistol_active = not _yami_pistol_active
		print("🌑 Yami Pistol: ", "EMPUNHADA (Bt Dir=Mirar / Bt Esq=Atirar)" if _yami_pistol_active else "GUARDADA")
		return
	if slot == "C" and combat_mode == "fruit" and current_fruit_id == "yami_yami":
		set_meta("yami_black_hole_active", true)
		_charging = true
		_charge_slot = "C"
		velocity = Vector3.ZERO
		_request_cast("C")
		return
	# Z RAJADA (Mera = balas de fogo; Hie = flechas de gelo) — começa ao PRESSIONAR,
	# não congela o player; para ao soltar ou ao atingir RAPID_MAX.
	if slot == "Z" and combat_mode == "fruit" and (current_fruit_id == "mera_mera" or current_fruit_id == "hie_hie"):
		trigger_skill_cooldown("Z")
		_rapid_fire = true
		_rapid_count = 0
		_rapid_t = 0.0
		return
	if combat_mode == "style" and STYLES_LIST[current_style_idx] == "teste_animacao":
		energy = maxf(energy - ENERGY_SKILL, 0.0)
		_request_cast(slot)
		return
	if _charging:
		return
	_charging = true
	_charge_slot = slot
	velocity = Vector3.ZERO
	_cast_token += 1               # este cast é novo: o timer do anterior não manda nele
	set_meta("is_casting", true)   # interrompível por dano
	if _animator and _animator.animation_player:
		_animator.animation_player.speed_scale = 0.0

# Solta a tecla -> dispara a skill na direção mirada e destrava.
func release_charge(slot: String) -> void:
	if combat_mode == "style" and STYLES_LIST[current_style_idx] == "teste_animacao":
		return
	if slot == "C" and combat_mode == "fruit" and current_fruit_id == "yami_yami":
		if has_meta("yami_black_hole_active"):
			set_meta("yami_black_hole_active", false)
		_charging = false
		_charge_slot = ""
		return
	# MERA MERA Z: soltar a tecla ENCERRA a rajada.
	if _rapid_fire and slot == "Z":
		_rapid_fire = false
		return
	if not _charging or _charge_slot != slot:
		return
	_charging = false
	if _animator and _animator.animation_player:
		_animator.animation_player.speed_scale = 1.0
	energy = maxf(energy - ENERGY_SKILL, 0.0)   # skill consome energia
	_request_cast(slot)

# Compat: disparo imediato (sem segurar).
func cast_skill_slot(slot_key: String) -> void:
	if is_suppressed or _skill_cooldowns.get(slot_key, 0.0) > 0.0:
		return
	if _buki_ativa():
		_buki_empunhar(slot_key)   # na Buki o slot empunha, não lança
		return
	_request_cast(slot_key)

# ---- Fase 5: casting SERVIDOR-AUTORIDADE ----
# Cliente PEDE o cast -> servidor valida e é dono da hitbox -> a PRESENTATION
# (VFX/anim) roda em TODOS os clientes; o dano/knockback (DamageZone) só é ativo
# no servidor. Sem peer (SP puro/harness) roda tudo local, idêntico.
func _request_cast(slot: String) -> void:
	if not _is_authority or is_suppressed or _skill_cooldowns.get(slot, 0.0) > 0.0:
		return
	# ⚠️ BUKI BUKI: aqui o slot está sendo EMPUNHADO, não gasto. A recarga dele só
	# começa quando a arma é LARGADA (troca, desistência ou munição zerada) — ver
	# `_buki_guardar`. Disparar o cooldown no saque colocaria a arma que você
	# acabou de sacar em recarga com ela ainda na mão.
	if not _buki_ativa():
		trigger_skill_cooldown(slot)
	if slot != "Z" and _yami_pistol_active:
		_yami_pistol_active = false
		for g in _pistols: if is_instance_valid(g): g.visible = false
	var cam_dir := -_cam.global_transform.basis.z
	var origin := global_position + Vector3.UP * 1.0 + cam_dir * 1.5
	
	var space := get_world_3d().direct_space_state
	var cam_pos := _cam.global_position
	var end_pos := cam_pos + cam_dir * 150.0
	var query := PhysicsRayQueryParameters3D.create(cam_pos, end_pos)
	query.exclude = [get_rid()]
	
	# Ignora áreas (como triggers e a própria DamageZone) para a mira não bater no ar
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var hit := space.intersect_ray(query)
	var target_point := end_pos
	if not hit.is_empty():
		target_point = hit.position
		
	var aim := (target_point - origin).normalized()
	
	# Camera Feel ao usar skill (V = ultimate: mais forte + slow-mo + flash).
	var ult := slot == "V"
	add_camera_shake(0.85 if ult else 0.6)
	_fov_punch = 8.0 if ult else 5.0
	ScreenFX.chromatic_pulse(0.7 if ult else 0.35)
	if ult:
		GameFlow.slow_mo()
		ScreenFX.flash(Color(1, 1, 1), 0.3)
	# Host/SP JÁ é o servidor -> executa a autoridade DIRETO (rpc_id a si mesmo é
	# proibido pelo Godot). Cliente puro -> pede ao servidor (peer 1).
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_cast(slot, aim, origin)
	else:
		_net_cast.rpc_id(1, slot, aim, origin)

@rpc("any_peer", "reliable")
func _net_cast(slot: String, aim: Vector3, origin: Vector3) -> void:
	if multiplayer.is_server():
		_do_server_cast(slot, aim, origin)

# ======================= CORPO A CORPO (botão esquerdo) =======================
# Combo: soco DIREITO -> soco ESQUERDO -> CHUTE, encadeáveis dentro de
# Melee.JANELA (2 s). Segue o MESMO trajeto de rede das skills: o dono pede, o
# servidor cria a hitbox, todo mundo reproduz a animação.
func _request_melee() -> void:
	if not _is_authority or _charging:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("is_menu_open") and hud.is_menu_open():
		return
	# Clique durante a recuperação: em vez de sumir, fica GUARDADO e sai sozinho
	# quando a trava abrir (ver _tick_melee). Sem isso o combo pune quem clica no
	# ritmo — e os `recuo` cresceram (0,40->0,58 s) para o soco caber em tela, o
	# que só piora a janela em que o clique se perdia. Buffer curto de propósito:
	# clique de 1 s atrás não é intenção de agora.
	if _melee_trava > 0.0:
		if _melee_trava <= BUFFER_MELEE:
			_melee_buffer = BUFFER_MELEE
		return

	# Janela vencida (ou combo terminado) -> recomeça do primeiro soco.
	if _melee_janela <= 0.0 or _melee_passo >= Melee.COMBO.size():
		_melee_passo = 0
	var golpe := Melee.passo(_melee_passo)
	_melee_trava = float(golpe["recuo"])
	_melee_janela = Melee.JANELA

	var fwd := -Basis.from_euler(Vector3(0, _yaw, 0)).z
	var origem := global_position + Vector3.UP * 1.0
	# Tranco de câmera NO SOCO, não no clique. Eram disparados aqui, ou seja até
	# 0,5 s antes de a hitbox nascer: a tela sacudia na preparação e ficava parada
	# no impacto — exatamente o "o impacto não sai no momento do soco".
	var t_impacto := get_tree().create_timer(float(golpe["atraso"]))
	var forca: float = float(golpe["shake"])
	t_impacto.timeout.connect(func():
		add_camera_shake(forca)
		_fov_punch = 3.0)

	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_melee(_melee_passo, origem, fwd)
	else:
		_net_melee.rpc_id(1, _melee_passo, origem, fwd)
	_melee_passo += 1

@rpc("any_peer", "call_remote", "reliable")
func _net_melee(passo: int, origem: Vector3, fwd: Vector3) -> void:
	if multiplayer.is_server():
		_do_server_melee(passo, origem, fwd)

# SERVIDOR: cria a hitbox (a DamageZone só machuca no servidor) e manda todos
# reproduzirem a animação do golpe.
func _do_server_melee(passo: int, origem: Vector3, fwd: Vector3) -> void:
	Melee.golpear(get_tree().current_scene, self, passo, origem, fwd)
	if multiplayer.has_multiplayer_peer():
		_net_play_melee.rpc(passo)
	else:
		_net_play_melee(passo)

@rpc("any_peer", "call_local", "reliable")
func _net_play_melee(passo: int) -> void:
	var clipe := Melee.clipe(passo)
	if clipe and _proc_anim:
		var g := Melee.passo(passo)
		_proc_anim.play_baked(clipe, float(g["vel"]), float(g.get("inicio", 0.0)))

# Corre os dois relógios do combo. Chamado do _physics_process.
func _tick_melee(delta: float) -> void:
	if _melee_trava > 0.0:
		_melee_trava = maxf(_melee_trava - delta, 0.0)
		if _melee_trava == 0.0 and _melee_buffer > 0.0:
			_melee_buffer = 0.0
			_request_melee()      # clique guardado sai agora que a trava abriu
	if _melee_buffer > 0.0:
		_melee_buffer = maxf(_melee_buffer - delta, 0.0)
	if _melee_janela > 0.0:
		_melee_janela = maxf(_melee_janela - delta, 0.0)
		if _melee_janela == 0.0:
			_melee_passo = 0   # esfriou: o próximo clique volta ao soco direito

# SERVIDOR = autoridade: (validaria cooldown/estado) e manda TODOS reproduzirem.
func _do_server_cast(slot: String, aim: Vector3, origin: Vector3) -> void:
	# BUKI BUKI: o cast É o saque da arma. É AQUI, na cópia autoritativa, que a
	# munição do servidor é carregada — o cliente não escolhe quantas balas tem.
	# Já sai com uma a menos porque o próprio saque dispara o primeiro tiro.
	if _buki_ativa() and BukiFX.ARSENAL.has(slot):
		_srv_buki_arma = slot
		_srv_buki_municao = BukiFX.municao(slot)
	if multiplayer.has_multiplayer_peer():
		_net_play_cast.rpc(slot, aim, origin)            # broadcast + call_local
	else:
		_net_play_cast(slot, aim, origin)                # sem rede: local direto

# ---- MERA MERA Z: rajada de balas de fogo (servidor-autoridade, como o cast) ----
func _tick_rapid_fire(delta: float) -> void:
	if not _rapid_fire:
		return
	if energy < ENERGY_BULLET:
		_rapid_fire = false                              # sem energia -> encerra a rajada
		return
	_rapid_t -= delta
	if _rapid_t <= 0.0:
		_rapid_t = RAPID_INTERVAL
		energy = maxf(energy - ENERGY_BULLET, 0.0)       # cada bala gasta energia
		_request_bullet()
		add_camera_shake(0.12)                           # Camera Feel: coice de cada tiro
		_gun_recoil = 1.0                                # coice visual do braço (mira)
		_rapid_count += 1
		if _rapid_count >= RAPID_MAX:
			_rapid_fire = false                          # 16 balas -> para

func _request_bullet() -> void:
	if not _is_authority or is_suppressed:
		return
	# MIRA CORRIGIDA: acha o ponto no mundo sob a mira (raycast) e faz a bala CONVERGIR
	# nele partindo do cano da pistola — assim ela acerta exatamente onde a mira aponta.
	var target := _aim_target_point()
	var origin := _muzzle_pos(_bullet_side)              # alterna esquerda/direita a cada tiro
	_bullet_side = 1 - _bullet_side
	var aim := (target - origin)
	if aim.length() < 0.01:
		aim = -_cam.global_transform.basis.z
	aim = aim.normalized()
	origin += aim * 0.25                                 # sai à frente do cano
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_bullet(aim, origin, "")
	else:
		_net_bullet_req.rpc_id(1, aim, origin, "")

# Ponta do cano da pistola da mão `side` (0=esq, 1=dir); fallback = à frente do peito.
func _muzzle_pos(side: int) -> Vector3:
	if side < _pistols.size() and is_instance_valid(_pistols[side]):
		var g: Node3D = _pistols[side]
		return g.global_position - g.global_transform.basis.y * 0.34   # cano = -Y local
	return global_position + Vector3.UP * 1.0 - _cam.global_transform.basis.z * 1.2

# Ponto no mundo sob a MIRA. Com aim assist, puxa pro inimigo mais alinhado no cone.
func _aim_target_point() -> Vector3:
	var cam_pos := _cam.global_position
	var fwd := -_cam.global_transform.basis.z
	if aim_assist:
		var e := _aim_assist_target(cam_pos, fwd)
		if e != null:
			return e.global_position + Vector3.UP * 0.6
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(cam_pos, cam_pos + fwd * 200.0)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		return hit["position"]
	return cam_pos + fwd * 60.0

# Inimigo mais ALINHADO à mira dentro do cone (~25°) e alcance — p/ a assistência.
func _aim_assist_target(cam_pos: Vector3, fwd: Vector3) -> Node3D:
	var best: Node3D = null
	var best_align := 0.9      # cos do cone
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D):
			continue
		var to: Vector3 = (e.global_position + Vector3.UP * 0.6) - cam_pos
		var d := to.length()
		if d > 55.0 or d < 0.5:
			continue
		var align := fwd.dot(to / d)
		if align > best_align:
			best_align = align
			best = e
	return best

@rpc("any_peer", "reliable")
func _net_bullet_req(aim: Vector3, origin: Vector3, arma: String) -> void:
	if multiplayer.is_server():
		_do_server_bullet(aim, origin, arma)

# `arma` != "" -> é um tiro da Buki Buki, e aí o SERVIDOR é quem manda na munição.
func _do_server_bullet(aim: Vector3, origin: Vector3, arma: String = "") -> void:
	if arma != "":
		# Sem bala no contador do servidor, nenhum tiro sai — nem visual, nem
		# DamageZone. Cliente adulterado não ganha munição infinita.
		if _srv_buki_arma != arma or _srv_buki_municao <= 0:
			return
		_srv_buki_municao -= 1
	if multiplayer.has_multiplayer_peer():
		_net_bullet_play.rpc(aim, origin, arma)
	else:
		_net_bullet_play(aim, origin, arma)

@rpc("any_peer", "call_local", "reliable")
func _net_bullet_play(aim: Vector3, origin: Vector3, arma: String) -> void:
	if arma != "":
		# BUKI: o disparo tem cara de arma (fogacho, cápsula, projétil) e o dano
		# por bala vem do SkillSystem — a arma é escolhida pelo slot.
		var fs := SkillSystem.get_fruit_skills()
		var dano: float = 20.0
		if fs.has("buki_buki") and fs["buki_buki"].has(arma):
			dano = float(fs["buki_buki"][arma].get("dano", 20))
		BukiFX.disparo(get_tree().current_scene, origin, aim, arma, dano, self)
		return
	if get_tree() and get_tree().current_scene:
		AudioFX.gunshot(get_tree().current_scene, origin, randf_range(0.95, 1.12))
	if current_fruit_id == "hie_hie":
		IceFX.bullet(get_tree().current_scene, origin, aim, 8.0, self)   # flecha de gelo
	elif current_fruit_id == "yami_yami":
		YamiFX.bullet(get_tree().current_scene, origin, aim, 25.0, self) # bala de trevas abissais
	else:
		FireFX.bullet(get_tree().current_scene, origin, aim, 8.0, self)  # bala de fogo

@rpc("any_peer", "call_local", "reliable")
func _net_play_cast(slot: String, aim: Vector3, origin: Vector3) -> void:
	_fire_skill(slot, aim, origin)

# Presentation da skill (roda em todos): VFX pela fruta/estilo. A DamageZone criada
# dentro só aplica dano no SERVIDOR (ver DamageZone).
func _fire_skill(slot: String, aim: Vector3, origin: Vector3) -> void:
	var variant: int = ["Z", "X", "C", "V"].find(slot)
	if variant < 0:
		variant = 0

	if _animator:
		_animator.trigger_kill()

	var world := get_tree().current_scene

	if combat_mode == "style":
		var active_style: String = STYLES_LIST[current_style_idx]
		var sdata: Dictionary = FightingStyles.STYLES[active_style]["skills"][slot]
		var dano: float = float(sdata.get("dano", 25))
		print("🥊 ESTILO ", active_style.to_upper(), ": ", sdata.get("nome", slot))
		FightingStyles.cast(world, active_style, variant, origin, aim, dano, self)
	else:
		var fruit_skills := SkillSystem.get_fruit_skills()
		# ⚠️ Aqui existia `else "gomu_gomu"` — um fallback MUDO, e ele era a causa
		# de dois bugs relatados jogando:
		#   • pegar uma fruta sem skills (ope_ope, hito_hito_nika, tori_tori_phoenix)
		#     dava os golpes da Gomu Gomu com o nome da outra fruta na HUD;
		#   • depois de MORRER o jogador larga a fruta (`current_fruit_id = ""`) e
		#     passava a sair Gomu Gomu do nada, como se tivesse ganhado uma fruta.
		# Sem fruta não há poder de fruta. O golpe não sai, e diz por quê.
		if not fruit_skills.has(current_fruit_id):
			if current_fruit_id == "":
				print("🚫 Sem Akuma no Mi — pegue uma fruta numa árvore para usar poderes.")
			else:
				push_warning("[Fruta] '%s' não tem skills no SkillSystem" % current_fruit_id)
				print("🚫 A fruta '%s' ainda não tem poderes implementados." % current_fruit_id)
			return
		var fid := current_fruit_id
		var sdata: Dictionary = fruit_skills[fid][slot]
		var cor: Color = sdata.get("cor", Color.WHITE)
		var dano: float = float(sdata.get("dano", 20))
		print("⚡ FRUTA ", fid.to_upper(), ": ", sdata.get("nome", slot))

		match fid:
			"gomu_gomu": GomuFX.cast(world, origin, aim, variant, dano, self)
			"suna_suna": SandFX.cast(world, origin, aim, variant, dano, self)
			"mera_mera": FireFX.cast(world, origin, aim, variant, dano, self)
			"hie_hie":   IceFX.cast(world, origin, aim, variant, dano, self)
			"goro_goro": GoroFX.cast(world, origin, aim, variant, dano, self)
			"yami_yami": YamiFX.cast(world, origin, aim, variant, dano, self)
			"bara_bara": BaraFX.cast(world, origin, aim, variant, dano, self)
			"gura_gura": GuraFX.cast(world, origin, aim, variant, dano, self)
			"buki_buki":
				# SAQUE DA ARMA. Roda em TODOS os peers (este método é a
				# presentation do cast), então o adversário vê a arma aparecer
				# na mão / o corpo virar canhão. O tiro do saque sai junto.
				_buki_mostrar_arma(["Z", "X", "C", "V"][variant])
				BukiFX.cast(world, origin, aim, variant, dano, self)
			_: _generic_vfx(cor, aim, origin)

	# Fim da janela de interrupção DESTE golpe. Só apaga se nenhum cast novo tiver
	# começado nesse meio-tempo (senão engolia a skill seguinte — ver _cast_token).
	var tok := _cast_token
	get_tree().create_timer(0.3).timeout.connect(func():
		if _cast_token == tok:
			set_meta("is_casting", false))

# VFX genérico para frutas ainda sem efeito dedicado.
func _generic_vfx(cor: Color, aim: Vector3, origin: Vector3) -> void:
	var vfx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	vfx.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(cor.r, cor.g, cor.b, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = 3.5
	vfx.material_override = m
	vfx.position = origin
	get_tree().current_scene.add_child(vfx)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(vfx, "position", origin + aim * 8.0, 0.45)
	tw.tween_property(vfx, "scale", Vector3.ONE * 5.0, 0.45)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.set_parallel(false)
	tw.tween_callback(vfx.queue_free)

func cast_skill(cor: Color) -> void:
	cast_skill_slot("Z")

# DEBUG (tecla T): cicla entre todas as frutas p/ testar as skills rapidamente.
func _cycle_fruit() -> void:
	var ids: Array = SkillSystem.get_fruit_skills().keys()
	var i: int = ids.find(current_fruit_id)
	var nxt: String = ids[(i + 1) % ids.size()]
	combat_mode = "fruit"       # garante que o cast use a fruta (não o estilo)
	equip_fruit(nxt)
	print("🔀 Fruta de teste: ", nxt)

func equip_fruit(fruit_id: String) -> void:
	current_fruit_id = fruit_id
	# Troca automática de aparência ao comer/equipar uma Akuma no Mi
	var new_cid := ""
	match fruit_id:
		"mera_mera": new_cid = "ace"
		"yami_yami": new_cid = "blackbeard"
		"suna_suna": new_cid = "crocodile"
		"goro_goro": new_cid = "nami"
		"bara_bara": new_cid = "buggy"
		"gomu_gomu": new_cid = "base"
	# Com o elenco trancado a aparência não muda — checa ANTES de anunciar, senão
	# o log diz "transformado em crocodile" e carrega o base logo abaixo.
	if new_cid != "" and not ELENCO_LIBERADO.has(new_cid):
		new_cid = ""
	if new_cid != "" and character_id != new_cid:
		print("🔄 Troca automática de aparência: comendo a fruta [", fruit_id, "] -> transformado em [", new_cid, "]!")
		_setup_character_model(new_cid)
	_yami_pistol_active = false
	# Trocou de fruta -> a arma da Buki cai da mão (e o slot dela esfria).
	_buki_guardar()
	_buki_mostrar_arma("")
	set_meta("yami_black_hole_active", false)
	var all_passives := FruitPassiveSystem.get_all_passives()
	if all_passives.has(fruit_id):
		var p_data: Dictionary = all_passives[fruit_id]
		speed_multiplier = float(p_data.get("speed_mod", 1.0))
		jump_multiplier = float(p_data.get("jump_mod", 1.0))
		print("⚡ Fruta Equipada: ", fruit_id, " | Passiva: ", p_data.get("nome", ""), " [Speed: x", speed_multiplier, " Jump: x", jump_multiplier, "]")

	# Atualiza a barra de tecnicas para a fruta equipada — vale para QUALQUER
	# caminho de coleta (esfera no chao OU fruta na arvore), consertando o caso
	# em que o poder era ganho mas a HUD nao refletia.
	# HUD só reflete a fruta do MEU player (equipar em player remoto não mexe no meu HUD).
	var hud := get_tree().get_first_node_in_group("hud")
	if _is_authority and hud and hud.has_method("update_skills_for_fruit"):
		hud.update_skills_for_fruit(fruit_id)

func _process_yami_pistol(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var target := _alvo_mais_proximo(35.0)
		if target and is_instance_valid(target):
			var to_target: Vector3 = (target.global_position + Vector3.UP * 0.9) - _cam.global_position
			var target_yaw := atan2(-to_target.x, -to_target.z)
			var h_dist := Vector2(to_target.x, to_target.z).length()
			var target_pitch := clampf(atan2(to_target.y, h_dist), -1.3, 1.3)
			_yaw = lerp_angle(_yaw, target_yaw, 15.0 * delta)
			_pitch = lerpf(_pitch, target_pitch, 15.0 * delta)
			_update_pivot()
			if _char_model:
				_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 20.0 * delta)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _yami_shot_cooldown <= 0.0:
		_yami_shot_cooldown = 0.35
		_gun_recoil = 1.0
		var cam_dir := -_cam.global_transform.basis.z
		var origin := global_position + Vector3.UP * 1.2 + cam_dir * 0.8
		var aim := _aim_target_point()
		var shoot_dir := (aim - origin).normalized()
		# ⚠️ Aqui a bala era criada DIRETO, sem passar pelo servidor — e a
		# `DamageZone` só machuca no servidor. Resultado relatado jogando: o tiro
		# da pistola da Yami saindo do CLIENTE não feria o jogador do servidor
		# (no host funcionava, porque lá o local JÁ é o servidor).
		#
		# Agora segue o mesmo trajeto da rajada Z: o dono pede, o servidor cria a
		# zona de dano, e todo mundo reproduz o visual.
		if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
			_do_server_bullet(shoot_dir, origin, "")
		else:
			_net_bullet_req.rpc_id(1, shoot_dir, origin, "")

# Corpo mais PRÓXIMO (inimigo ou outro jogador) dentro do alcance. Nasceu na
# pistola da Yami e hoje serve também o auxílio de mira da Buki Buki — por isso
# perdeu o nome próprio. Varre "enemy" E "player": numa arena PvP mirar só em
# inimigos deixaria o auxílio inútil.
func _alvo_mais_proximo(max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	if get_tree() and get_tree().current_scene:
		var cands := get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player")
		for c in cands:
			if not (c is Node3D) or c == self:
				continue
			var d: float = global_position.distance_to(c.global_position)
			if d < best_d and d > 0.2:
				best_d = d
				best = c
	return best

# ============================================================================
#  BUKI BUKI NO MI — a fruta virou FPS (regra nova do dono, 2026-08-11)
#
#  MÁQUINA DE ESTADO da arma, em quatro transições e nada mais:
#
#    mãos livres --[tecla do slot]--> EMPUNHADA(slot)   (+ tiro do saque)
#    EMPUNHADA(a) --[tecla de outro slot b]--> EMPUNHADA(b) e (a) EM RECARGA
#    EMPUNHADA(a) --[tecla do mesmo slot a]--> mãos livres e (a) EM RECARGA
#    EMPUNHADA(a) --[munição = 0]--> mãos livres e (a) EM RECARGA
#
#  Ou seja: largar a arma SEMPRE custa a recarga do slot largado — seja por
#  troca, por desistência ou por bala acabada. É isso que obriga o rodízio.
#
#  O modelo é o toggle da pistola da Yami (`_process_yami_pistol`), que já fazia
#  "aperta, a arma fica, botão esquerdo atira, outra skill guarda" — a Buki só
#  acrescenta munição por cima e sobe pros quatro slots.
# ============================================================================

func _buki_ativa() -> bool:
	return combat_mode == "fruit" and current_fruit_id == "buki_buki"

## Munição/arma para a HUD. Ver src/ui/AmmoHud.gd.
func buki_arma() -> String:
	return _buki_weapon
func buki_municao() -> int:
	return _buki_municao
func buki_municao_max() -> int:
	return BukiFX.municao(_buki_weapon)

# EMPUNHAR (ou guardar, se for o mesmo slot). Só o dono do corpo passa por aqui.
func _buki_empunhar(slot: String) -> void:
	if not _is_authority or is_suppressed:
		return
	if _buki_weapon == slot:
		print("🔫 Buki: %s GUARDADA — o slot %s entra em recarga." % [BukiFX.nome_da_arma(slot), slot])
		_buki_guardar()
		return
	if _buki_weapon != "":
		# TROCA DE SKILL: a arma anterior é perdida e o slot dela entra em recarga.
		print("🔫 Buki: larguei a %s pra sacar a %s." % [
			BukiFX.nome_da_arma(_buki_weapon), BukiFX.nome_da_arma(slot)])
		_buki_guardar()
	if _skill_cooldowns.get(slot, 0.0) > 0.0:
		print("⏳ Buki: %s em recarga (%.1fs)." % [BukiFX.nome_da_arma(slot), _skill_cooldowns[slot]])
		return
	# SACAR NÃO ATIRA (pedido do dono, 2026-08-11).
	#
	# Antes a 1ª bala saía no próprio saque: apertar a tecla já disparava, e a
	# munição começava descontada (12 = 1 no saque + 11 no clique). Em jogo isso
	# vira tiro que o jogador não pediu — ele saca para MIRAR, e o disparo tem
	# que ser decisão dele. Agora a tecla só empunha; quem atira é o botão
	# esquerdo, sempre. A arma sai com a munição CHEIA.
	_buki_weapon = slot
	_buki_municao = BukiFX.municao(slot)
	_buki_shot_cd = 0.0                 # pronta pra atirar assim que o dedo mandar
	_buki_scope = false
	print("🔫 Buki: %s EMPUNHADA — %d balas (Bt Esq = atirar%s)." % [
		BukiFX.nome_da_arma(slot), _buki_municao,
		" / Bt Dir = luneta" if slot == "C" else " / Bt Dir = mira assistida"])

	# ⚠️ SACAR TEM QUE AVISAR O SERVIDOR — e isso quase se perdeu.
	#
	# Quando tirei o tiro do saque, saiu junto a linha `_request_cast(slot)`. Eu a
	# li como "isto atira", mas ela carregava outras DUAS coisas de carona:
	#   • `_do_server_cast` gravava `_srv_buki_arma`/`_srv_buki_municao` — sem
	#     isso o servidor não sabe qual arma está na mão e RECUSA TODO TIRO
	#     (medido: sniper cheia, 5 balas, 0 DamageZone criada);
	#   • `_fire_skill` chamava `_buki_mostrar_arma` — sem isso a arma nunca
	#     aparece no rig, e no canhão o corpo nem some.
	#
	# Agora o saque tem caminho PRÓPRIO, que arma o estado e mostra a arma sem
	# disparar nada. Lição: remover chamada é tão perigoso quanto adicionar,
	# quando ela tem efeito colateral.
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_buki_sacar(slot)
	else:
		_net_buki_sacar_req.rpc_id(1, slot)

@rpc("any_peer", "reliable")
func _net_buki_sacar_req(slot: String) -> void:
	if multiplayer.is_server():
		_do_server_buki_sacar(slot)

# SERVIDOR: guarda qual arma este corpo empunha e com quanta munição, e manda
# todos os peers mostrarem a arma. O servidor é quem valida cada tiro depois.
func _do_server_buki_sacar(slot: String) -> void:
	if not (_buki_ativa() and BukiFX.ARSENAL.has(slot)):
		return
	_srv_buki_arma = slot
	_srv_buki_municao = BukiFX.municao(slot)   # CHEIA: o saque não gasta bala
	if multiplayer.has_multiplayer_peer():
		_net_buki_sacar.rpc(slot)
	else:
		_net_buki_sacar(slot)

@rpc("any_peer", "call_local", "reliable")
func _net_buki_sacar(slot: String) -> void:
	_buki_mostrar_arma(slot)

# GUARDAR: a arma some e o slot largado entra em recarga. Chamado na troca, no
# fim da munição, ao trocar de fruta e ao morrer.
func _buki_guardar() -> void:
	if _buki_weapon == "":
		return
	trigger_skill_cooldown(_buki_weapon)   # a penalidade: aquele slot esfria
	_buki_weapon = ""
	_buki_municao = 0
	_buki_scope = false
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_buki_guardar()
	else:
		_net_buki_guardar_req.rpc_id(1)

@rpc("any_peer", "reliable")
func _net_buki_guardar_req() -> void:
	if multiplayer.is_server():
		_do_server_buki_guardar()

# SERVIDOR: zera a munição autoritativa (nenhum tiro mais é aceito) e manda todo
# mundo tirar a arma da mão.
func _do_server_buki_guardar() -> void:
	_srv_buki_arma = ""
	_srv_buki_municao = 0
	if multiplayer.has_multiplayer_peer():
		_net_buki_guardar.rpc()
	else:
		_net_buki_guardar()

@rpc("any_peer", "call_local", "reliable")
func _net_buki_guardar() -> void:
	_buki_mostrar_arma("")

# ------------------------------------------------------- laço da arma na mão
# Roda todo frame enquanto houver arma empunhada (chamado do _physics_process,
# como o `_process_yami_pistol`). NÃO congela o jogador: com arma na mão dá pra
# andar — é FPS, não pose de golpe.
func _process_buki_arma(delta: float) -> void:
	if _buki_shot_cd > 0.0:
		_buki_shot_cd = maxf(_buki_shot_cd - delta, 0.0)
	if _gun_recoil > 0.0:
		_gun_recoil = maxf(_gun_recoil - delta * 7.0, 0.0)
	_buki_apontar_canhao()

	var bt_dir := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	# HABILIDADE ATIVA DA FRUTA: o botão direito faz a mira TENDER pro alvo mais
	# próximo. ⚠️ EXCEÇÃO DA SNIPER (C): ali o auxílio fica DESLIGADO e o botão
	# direito é a luneta — mira assistida com zoom seria tiro grátis.
	if _buki_weapon == "C":
		_buki_scope = bt_dir
	else:
		_buki_scope = false
		if bt_dir:
			_buki_auxilio_de_mira(delta)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _buki_shot_cd <= 0.0:
		_buki_atirar()

# O canhão-corpo (X) aponta pra onde a câmera olha; as armas de braço já seguem
# o membro. Roda também nas cópias remotas (ver `_remote_process`), senão o
# adversário vê um canhão apontando sempre pro norte.
func _buki_apontar_canhao() -> void:
	if not is_instance_valid(_buki_pivot) or _buki_visual != "X":
		return
	if _is_authority:
		_buki_pivot.rotation = Vector3(_pitch, _yaw, 0)
	else:
		_buki_pivot.rotation = Vector3(0, net_facing, 0)

# Mira assistida: puxa devagar (não trava) pro alvo mais próximo.
func _buki_auxilio_de_mira(delta: float) -> void:
	var alvo := _alvo_mais_proximo(50.0)
	if alvo == null or not is_instance_valid(alvo):
		return
	var para: Vector3 = (alvo.global_position + Vector3.UP * 0.9) - _cam.global_position
	var h := Vector2(para.x, para.z).length()
	_yaw = lerp_angle(_yaw, atan2(-para.x, -para.z), 9.0 * delta)
	_pitch = lerpf(_pitch, clampf(atan2(para.y, h), -1.2, 0.5), 9.0 * delta)
	_update_pivot()
	if _char_model:
		_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 14.0 * delta)

# UM TIRO. ⚠️ NADA de criar o efeito aqui: a bala tem que NASCER NO SERVIDOR,
# senão a DamageZone do cliente não fere ninguém e o sintoma vira "a arma não
# funciona" (docs/erros.md, 2026-08-10 — pistola da Yami). O trajeto é o mesmo
# da rajada Z: dono pede -> `_do_server_bullet` -> `_net_bullet_play`.
func _buki_atirar() -> void:
	if _buki_weapon == "" or _buki_municao <= 0:
		return
	var slot := _buki_weapon
	var d: Dictionary = BukiFX.ARSENAL[slot]
	_buki_municao -= 1
	_buki_shot_cd = float(d["cadencia"])
	_gun_recoil = 1.0
	add_camera_shake(float(d["shake"]))

	var origin := _buki_muzzle()
	var alvo_pt := _aim_target_point()
	var aim := alvo_pt - origin
	aim = aim.normalized() if aim.length() > 0.01 else -_cam.global_transform.basis.z
	origin += aim * 0.25
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_bullet(aim, origin, slot)
	else:
		_net_bullet_req.rpc_id(1, aim, origin, slot)

	# RECUO do canhão: o tranco empurra o jogador pra trás — o tiro vira mobilidade.
	var recuo := float(d["recuo"])
	if recuo > 0.0:
		_kb_impulso += -aim * recuo
		velocity.y += recuo * 0.32

	if _buki_municao <= 0:
		print("🔫 Buki: %s SEM MUNIÇÃO — some da mão e o slot %s entra em recarga." % [
			BukiFX.nome_da_arma(slot), slot])
		_buki_guardar()

# Boca do cano da arma empunhada. Sem arma na árvore, cai no peito (mesma rede
# de segurança do `_muzzle_pos` da pistola).
func _buki_muzzle() -> Vector3:
	var n = _buki_armas.get(_buki_weapon)
	if n is Node3D and is_instance_valid(n) and (n as Node3D).is_inside_tree():
		var t := (n as Node3D).global_transform
		# Pistola aponta pro −Y do antebraço; o resto (.glb) pro −Z do próprio nó.
		if _buki_weapon == "Z":
			return t.origin - t.basis.y.normalized() * 0.34
		return t.origin - t.basis.z.normalized() * (1.7 if _buki_weapon == "X" else 0.9)
	return global_position + Vector3.UP * 1.2 + (-_cam.global_transform.basis.z) * 0.9
