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

# A câmera virou COMPONENTE (Fase 2 — ver docs/ARQUITETURA_PLAYER.md). O rig é
# dono do tremor, do soco de FOV, do balanço, da perspectiva e da distância;
# aqui só sobra a referência a ele e o `_cam` de conveniência para a mira.

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
# PARKOUR -> src/player/parkour_controller.gd (Fase 4). Aqui só as VISTAS.
var _parkour := ParkourController.new()
var _is_climbing: bool:
	get: return _parkour.escalando()
var max_geppo: int:
	get: return _parkour.max_geppo
	set(v): _parkour.max_geppo = v
var _geppo_count: int:
	get: return _parkour.geppos()

var _camera: CameraRig        # componente: câmera, tremor, FOV, balanço, tela
var _cam: Camera3D            # atalho para `_camera.camera()` — a mira usa muito


# Sprint = Shift segurado com direção. Usado pela câmera e pelos efeitos de tela;
# o movimento tem a própria checagem em _physics_process.
func _is_sprinting() -> bool:
	return Input.is_key_pressed(KEY_SHIFT) and velocity.length_squared() > 0.5
var _long_jump_t: float:
	get: return _parkour.janela_impulso()
# O PEDIDO do jogador neste quadro (teclas + base da câmera) -> move_frame.gd.
# Vive entre quadros porque a borda do Espaço precisa lembrar o quadro anterior
# — era o campo `_space_was`, que saiu do Player junto.
var _quadro := MoveFrame.new()
# Janela da animação de ROLAMENTO. Tinha DOIS donos — o pouso de precisão e o
# dash escreviam nela direto. Virou PEDIDO (`pedir_rolamento`), no mesmo padrão
# do `pedir_shake` da câmera: quem quer rolar pede, o Player é o dono do prazo.
var _roll_t: float = 0.0
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
#
# Os números e o estado da esquiva moram em src/player/dash_controller.gd
# (Fase 4). Aqui ficam só as VISTAS, para quem observa de fora.
var _dash := DashController.new()
var _dash_t: float:
	get: return _dash.tempo()
var _dash_dir: Vector3:
	get: return _dash.direcao()
var _dash_cooldown: float:
	get: return _dash.recarga()
# Mera Mera Z: rajada de balas de fogo (segura pra atirar; para ao soltar ou 16 balas).
const RAPID_INTERVAL := 0.09
const RAPID_MAX := 16
var _rapid_fire: bool = false
var _rapid_count: int = 0
var _rapid_t: float = 0.0
var _gun_recoil: float = 0.0   # coice da rajada Z (1->0 por tiro) p/ a pose de mira
var _pistols: Array:           # pistolas nas DUAS mãos (visíveis só na rajada Z)
	get: return _rig.pistolas() if _rig else []
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
# O estado do arsenal vive em src/player/buki_controller.gd (Fase 5). Aqui só
# as VISTAS — os RPCs e a HUD continuam falando com o Player.
var _buki := BukiController.new()
var _buki_weapon: String:
	get: return _buki.arma()
var _buki_municao: int:
	get: return _buki.municao()
var _buki_scope: bool:
	get: return _buki.luneta()
var _buki_visual: String:
	get: return _buki.visual()
var _srv_buki_arma: String:
	get: return _buki._srv_arma
var _srv_buki_municao: int:
	get: return _buki.servidor_municao()
# As armas e o pivô são MONTADOS pelo rig (nascem e morrem com o modelo); quem
# decide qual aparece é o combate, aqui. Era o conflito de dois donos que o
# relatório apontou.
var _buki_armas: Dictionary:        # slot -> Node3D pré-construído (oculto)
	get: return _rig.armas_buki() if _rig else {}
var _buki_pivot: Node3D:            # pivô do canhão-corpo (X): gira com a mira
	get: return _rig.pivo_buki() if _rig else null
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

# ---- RIG E MODELO -> src/player/player_rig.gd (Fase 3) ----
# O componente é dono do CICLO DE VIDA do corpo visível (criar, medir, vestir,
# soltar). O que segue abaixo são VISTAS: propriedades só-leitura que encaminham
# para o rig.
#
# Por que vistas e não simplesmente `_rig.modelo()` em todo canto: `_char_model`
# é lido em ~42 pontos aqui dentro, e o `BukiFX.gd` o pega de fora por nome
# (`caster.get("_char_model")`). Getter mantém UM dono (o rig) e zero estado
# duplicado, sem precisar reescrever nada disso. Escrever nesses campos era o
# que o relatório chamava de conflito — e agora é impossível: não têm setter.
var _rig: PlayerRig = null

var character_id: String:
	get: return _rig.character_id if _rig else "base"
var _animator: CharacterAnimator:
	get: return _rig.animador() if _rig else null
var _char_model: Node3D:
	get: return _rig.modelo() if _rig else null
var _proc_anim: ProceduralAnimator:   # animação procedural em tempo real do rig
	get: return _rig.procedural() if _rig else null
var _skel_anim: SkeletalAnimator:     # animador ESQUELETAL (personagens skinnados)
	get: return _rig.esqueletal() if _rig else null
var _is_skinned: bool:                # o personagem atual é skinnado (Skeleton3D)?
	get: return _rig.skinnado() if _rig else false
var _head_node: Node3D:               # cabeça do modelo atual (âncora do fôlego)
	get: return _rig.cabeca() if _rig else null
var _breath = null                   # VFX de fôlego (instância de VFX/BreathVFX.tscn; sem tipo p/ não depender do cache de class_name)

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

	# RIG E MODELO — componente próprio desde a Fase 3. Precisa existir ANTES do
	# set_character, que é justamente quem manda o rig montar o corpo.
	_rig = PlayerRig.new()
	_rig.name = "PlayerRig"
	add_child(_rig)
	_rig.montar_em(self)
	_dash.montar_em(self)
	_buki.montar_em(self, _rig)
	_parkour.montar_em(self, GRAVITY, JUMP_VELOCITY)

	# Substitui o quadrado cinza pelo modelo 3D Voxel e equipa a Akuma no Mi correspondente
	set_character(character_id)

	# Colisor do jogador.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.6, 1.0)
	col.shape = shape
	add_child(col)

	# CÂMERA — componente próprio desde a Fase 2. Ele monta a cadeia
	# (pivô → ombro → SpringArm → Camera3D) e é dono de tremor, FOV e balanço.
	# O `_cam` fica guardado aqui só porque a mira o consulta em 26 lugares.
	_camera = CameraRig.new()
	_camera.name = "CameraRig"
	add_child(_camera)
	_camera.montar(self, _is_authority)
	_cam = _camera.camera()

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
	if _camera:
		_camera.aplicar_perspectiva()
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
	elif event is InputEventMouseButton and _camera and not _camera.em_primeira_pessoa():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera.ajustar_distancia(-0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera.ajustar_distancia(0.5)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_authority:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		# Alterna 1a <-> 3a pessoa.
		if _camera:
			_camera.alternar_perspectiva()
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
		# `BukiController.atualizar`) — quem está de arma na mão atira, não soca.
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
	if _camera:
		_camera.apontar(_yaw, _pitch)

# ---- Camera Feel: screen-shake (h_offset/v_offset NÃO afetam a mira) ----
# Tremor de tela. Continua aqui porque MUITA gente de fora chama (efeitos das
# frutas, corpo a corpo, pouso) — o Player repassa ao rig em vez de expor o
# componente inteiro.
# ---------------------------------------------------------- PEDIDOS DA BUKI
# O `BukiController` (Fase 5) é dono do arsenal, mas NÃO escreve estado alheio.
# Estes são os pedidos dele — mesma disciplina do `pedir_shake` (Fase 2) e do
# `pedir_rolamento` (Fase 4).

# RECUO do canhão: o tranco empurra o jogador. `_kb_impulso` e `velocity` são do
# domínio de MOVIMENTO; o arsenal pede, não escreve.
func pedir_recuo(direcao: Vector3, forca: float) -> void:
	_kb_impulso += direcao * forca
	velocity.y += forca * 0.32

# Coice visual da arma (1 -> 0), lido pela pose de mira do animador. É
# compartilhado com a rajada Z e a pistola da Yami — por isso continua aqui.
func pedir_coice_de_arma() -> void:
	_gun_recoil = 1.0

# MIRA ASSISTIDA: puxa devagar (não trava) para um ponto. Quem escolhe o ALVO é
# quem tem a arma; quem é dono de `_yaw`/`_pitch` é o Player — decisão da Fase 2,
# porque quem os escreve é o input.
func mirar_suave_para(ponto: Vector3, delta: float, forca: float) -> void:
	var para: Vector3 = ponto - _cam.global_position
	var h := Vector2(para.x, para.z).length()
	_yaw = lerp_angle(_yaw, atan2(-para.x, -para.z), forca * delta)
	_pitch = lerpf(_pitch, clampf(atan2(para.y, h), -1.2, 0.5), forca * delta)
	_update_pivot()
	if _char_model:
		_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 14.0 * delta)

# ⚠️ A BALA TEM QUE NASCER NO SERVIDOR, senão a `DamageZone` do cliente não fere
# ninguém e o sintoma vira "a arma não funciona" (docs/erros.md, 2026-08-10 —
# pistola da Yami). O canal é COMPARTILHADO com a rajada Z e a Yami: é por isso
# que a Fase 5 manteve os RPCs aqui em vez de levar o componente para nó filho.
func pedir_bala_da_buki(aim: Vector3, origem: Vector3, slot: String) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_bullet(aim, origem, slot)
	else:
		_net_bullet_req.rpc_id(1, aim, origem, slot)

# Encanamento de rede do saque/guardar. Fica no Player porque RPC se resolve por
# CAMINHO DE NÓ — mover o método mudaria o protocolo.
func avisar_servidor_do_saque(slot: String) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_buki_sacar(slot)
	else:
		_net_buki_sacar_req.rpc_id(1, slot)

func avisar_servidor_do_guardar() -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_buki_guardar()
	else:
		_net_buki_guardar_req.rpc_id(1)

# Pede a janela de ROLAMENTO. O maior pedido vence — dois gatilhos no mesmo
# quadro (pousar em cima de um dash) não devem encurtar a animação.
func pedir_rolamento(duracao: float) -> void:
	_roll_t = maxf(_roll_t, duracao)

func add_camera_shake(amount: float) -> void:
	if _is_authority and _camera:
		_camera.pedir_shake(amount)

func _process(delta: float) -> void:
	if not _is_authority or _camera == null:
		return
	# O rig recebe o estado de que precisa em vez de ir buscá-lo no Player —
	# é o que mantém a fronteira honesta e permite testá-lo sozinho.
	_camera.atualizar(delta, velocity, SPEED, is_on_floor(), _is_sprinting(), _yaw, _buki_scope)

func _physics_process(delta: float) -> void:
	# ETAPAS NOMEADAS (Fase 1 da arquitetura, 2026-08-11).
	#
	# Este método tinha 291 linhas e misturava movimento, parkour, dash,
	# habilidades, energia, animação, rede, Buki, câmera e melee. Era por causa
	# dele que a contagem por domínio dizia "MOVIMENTO: 45 linhas" — a
	# movimentação de verdade morava aqui dentro, sem nome.
	#
	# ⚠️ NADA saiu do arquivo nesta fase, de propósito. O objetivo é enxergar as
	# dependências e a ORDEM antes de mover código: cada etapa abaixo já é uma
	# fronteira candidata a virar componente (ver docs/ARQUITETURA_PLAYER.md).
	#
	# A ordem NÃO é arbitrária, e duas etapas cortam o quadro:
	#   • sem autoridade, o corpo só reproduz o estado replicado e nada mais roda;
	#   • travado (cast, rajada, congelado, vórtice, buraco negro) o personagem
	#     fica parado e o quadro termina ali;
	#   • morto no vazio, o respawn acontece e o resto do quadro é descartado.
	if not _is_authority:
		_remote_process(delta)   # player de outro cliente: só reproduz o estado replicado
		return
	_etapa_estado_de_combate(delta)
	if _etapa_travamento(delta):
		return
	_etapa_locomocao(delta)
	_etapa_ticks_de_combate(delta)
	_etapa_publicar_rede()
	if _etapa_vida(delta):
		return
	_etapa_mover(delta)

# Energia, recargas e o laço das armas na mão. Roda SEMPRE que há autoridade —
# inclusive travado, senão a recarga congelaria junto com o personagem.
func _etapa_estado_de_combate(delta: float) -> void:
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
	if _buki.empunhando():
		# O coice visual é COMPARTILHADO com a rajada Z e a pistola da Yami, então
		# quem decai é o Player. O componente só pede (`pedir_coice_de_arma`).
		if _gun_recoil > 0.0:
			_gun_recoil = maxf(_gun_recoil - delta * 7.0, 0.0)
		_buki.atualizar(delta, _pitch, _yaw, net_facing)   # mira, cadência e munição

# O personagem está preso a alguma coisa? Devolve `true` quando consumiu o
# quadro — quem chama tem que devolver na hora, sem seguir para a locomoção.
func _etapa_travamento(delta: float) -> bool:
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
				
				return true
	return false

# O CICLO FÍSICO — quem manda na velocidade deste quadro.
#
# Era um bloco de 206 linhas com entrada, parkour, dash, locomoção, facing e
# animação misturados, disputando 16 locais de quadro. A Fase 4 separou por
# RESPONSABILIDADE, não por verbo:
#
#   src/player/move_frame.gd         o que o jogador PEDIU (teclas + câmera)
#   src/player/parkour_controller.gd os 8 movimentos de cenário + as sondas
#   src/player/dash_controller.gd    a esquiva do Q
#
# A ordem abaixo é a regra do jogo, e é por isso que ela mora AQUI e não nos
# componentes: nenhum deles escreve `velocity`. Eles recebem e devolvem; quem
# atribui é esta etapa. Escalada e wall run são exclusivos — enquanto valem, o
# parkour manda sozinho e nem a gravidade roda.
#
# Sobraram 7 locais de quadro (eram 16). Continuam aqui de propósito: são o
# RESULTADO das decisões, e é justamente combiná-los que esta etapa faz.
func _etapa_locomocao(delta: float) -> void:
	# LEITURA do quadro: teclas + base da câmera -> src/player/move_frame.gd.
	# A etapa passou a DECIDIR sobre um pedido já lido, em vez de ler e decidir
	# ao mesmo tempo. Ler aqui dentro (e não antes) é de propósito: quando o
	# `_etapa_travamento` corta o quadro, a borda do Espaço NÃO avança — mesmo
	# comportamento de quando `_space_was` era campo do Player.
	var q := _quadro
	q.ler(_yaw)
	# Rajada (Mera/Hie Z): fica PARADO enquanto atira; só a câmera gira. Volta a
	# andar ao soltar o botão ou acabar as balas (release_charge zera _rapid_fire).
	if _rapid_fire:
		q.congelar()

	# PARKOUR -> src/player/parkour_controller.gd. Uma chamada resolve pouso de
	# precisão, sondagem de parede, decisão de escalar/correr na parede e recarga
	# do geppo. Antes isso estava espalhado em quatro pedaços da etapa.
	var on_floor_now := is_on_floor()
	_parkour.avaliar(delta, q, on_floor_now)

	if _roll_t > 0.0:
		_roll_t -= delta

	# ESQUIVA (Q) -> src/player/dash_controller.gd. Ele cuida de mira, recarga,
	# direção travada e tempo restante; aqui só se pergunta o que ele quer.
	# `bloqueado`: o combate está usando o corpo, não dá pra armar a esquiva.
	_dash.atualizar(delta, q, _charging or _rapid_fire or _yami_pistol_active)


	# `bonus_velocidade` é o impulso horizontal do salto longo / vault: o parkour
	# devolve o FATOR e quem multiplica é a etapa. Componente não escreve na
	# velocidade dos outros.
	var effective_speed := SPEED * speed_multiplier * (1.5 if q.sprint else 1.0) * _parkour.bonus_velocidade()

	# QUEM MANDA NA VELOCIDADE DESTE QUADRO.
	# Escalada e wall run são exclusivos: enquanto valem, o parkour manda sozinho.
	if _parkour.assumiu():
		velocity = _parkour.velocidade(delta, q, velocity, effective_speed)
	else:
		# Gravidade.
		if not is_on_floor():
			velocity.y -= GRAVITY * delta

		# Vault, salto longo, pulo normal e geppo: o parkour recebe a velocidade
		# e devolve a velocidade — não escreve nela.
		velocity = _parkour.aplicar_pulos(q, velocity, effective_speed, is_on_floor(), jump_multiplier)

		if _dash.passo() > 0.0:
			velocity = _dash.velocidade(delta)
		else:
			velocity.x = q.dir.x * effective_speed
			velocity.z = q.dir.z * effective_speed

	# A FRENTE do personagem se move dinamicamente durante a locomoção.
	if _char_model:
		if _parkour.escalando() and _parkour.parede_frontal() != Vector3.ZERO:
			# Convenção do projeto: FRENTE = -Z. Ao escalar, a frente vira PARA DENTRO
			# da parede, ou seja, o -Z do modelo aponta ao longo de -wall_normal
			# (wall_normal aponta da parede para o jogador). Daí atan2(wn.x, wn.z).
			var target_rot := atan2(_parkour.parede_frontal().x, _parkour.parede_frontal().z)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, target_rot, 24.0 * delta)
		elif _dash.ativo():
			var move_rot := atan2(-_dash.direcao().x, -_dash.direcao().z)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, move_rot, 35.0 * delta)
		elif q.dir.length_squared() > 0.01:
			var move_rot := atan2(-q.dir.x, -q.dir.z)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, move_rot, 35.0 * delta)
		else:
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 24.0 * delta)

	# Animação: rig procedural (por-nós) OU esqueletal (skinnado).
	if _skel_anim:
		_skel_anim.update(velocity, is_on_floor(), _parkour.escalando(), delta, q.sprint)
	elif _proc_anim:
		var parkour := ""
		if _parkour.correndo_na_parede():
			parkour = "wall_run"
		elif _roll_t > 0.0:
			parkour = "roll"
		elif _parkour.janela_impulso() > 0.0 and not on_floor_now:
			parkour = "long_jump"
		_proc_anim.update(velocity, is_on_floor(), _parkour.escalando(), delta, _pitch, q.sprint, false, "", parkour, _pose_de_arma(), _gun_recoil)

# Fôlego, rajada Z e a janela do combo de corpo a corpo.
func _etapa_ticks_de_combate(delta: float) -> void:
	_update_breath()
	_tick_rapid_fire(delta)   # Mera Z: dispara as balas de fogo enquanto a rajada está ativa
	_tick_melee(delta)        # corpo a corpo: janela de 2 s do combo + recuperação

# A autoridade publica seu estado para os outros clientes replicarem.
func _etapa_publicar_rede() -> void:

	# Rede (Fase 4): a autoridade publica seu estado p/ os outros clientes replicarem.
	net_velocity = velocity
	net_on_floor = is_on_floor()
	if _char_model:
		net_facing = _char_model.rotation.y

# Supressão de poderes e morte por queda. Devolve `true` se o quadro acabou aqui.
func _etapa_vida(delta: float) -> bool:

	# Processamento de Supressão da Passiva Yami Yami
	if is_suppressed:
		suppression_timer -= delta
		if suppression_timer <= 0.0:
			is_suppressed = false
			print("✨ Poderes reativados!")

	# Verificação de Void (Morte ao cair no Void)
	if SkillSystem.process_void_check(self):
		return true
	return false

# Aplica o empurrão externo e move de fato. É o ÚLTIMO passo do quadro: o
# knockback tem que entrar DEPOIS de a locomoção escrever `velocity`, senão ela
# o sobrescreve (foi exatamente esse o bug do empurrão que não funcionava).
func _etapa_mover(delta: float) -> void:

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

# TROCA DE PERSONAGEM — política aqui, montagem no rig.
#
# A GUARDA DA TRAVA DE ELENCO fica NESTE ponto, e não no `set_character`, porque
# aqui é por onde TODOS passam: menu, rede, e principalmente a troca automática
# de aparência do `equip_fruit()` (o Main equipa suna_suna ao nascer, o que
# virava Crocodile mesmo com o elenco trancado). Quem pode ser carregado é regra
# de JOGO — por isso não desceu para o componente, que monta o que mandarem.
func _setup_character_model(cid: String) -> void:
	if not ELENCO_LIBERADO.has(cid):
		cid = ELENCO_LIBERADO[0]

	_buki.esquecer_visual()   # o modelo antigo levou as armas embora
	_rig.montar(cid)

	# Fôlego (VFX): é do PLAYER, não do rig — sobrevive à troca de personagem e é
	# reaproveitado. Só o voxel tem (o skinnado saía pelo `return` antes deste
	# ponto no código antigo; a condição abaixo preserva isso exatamente).
	if not _rig.skinnado() and _breath == null:
		_breath = load("res://VFX/BreathVFX.tscn").instantiate()
		add_child(_breath)   # filho do Player (sem a escala do rig)

# PRESENTATION da arma empunhada — roda em TODOS os peers (chamada de dentro de
# `_fire_skill` e do `_net_buki_guardar`), então o adversário vê a arma na mão
# e vê o corpo virar canhão. "" = guardar tudo.
func _buki_mostrar_arma(slot: String) -> void:
	_buki.mostrar_arma(slot)

# O corpo some em DOIS casos: 1ª pessoa (já era) e canhão-corpo da Buki (X).
# Ficam no mesmo lugar porque brigavam: o `_apply_perspective` reacendia o corpo
# no meio da transformação.
func _atualizar_visibilidade_corpo() -> void:
	if _char_model == null:
		return
	_char_model.visible = (_camera == null or not _camera.em_primeira_pessoa()) and _buki_visual != "X"

# ---------------------------------------------------------------- combate ---
func take_damage(amount: float, attacker_pos: Vector3 = Vector3.ZERO, base_knockback: Vector3 = Vector3.ZERO) -> void:
	# `in_black_hole` entrou aqui em 2026-08-11: o Black Hole da Yami é CONTROLE
	# PURO — puxa, afunda e silencia, e quem mata é o buraco do mapa depois.
	# `TrainingDummy.gd:64` e `disabled/enemies/Enemy.gd` já recusavam dano de
	# quem está preso; só o jogador não recusava, e a mesma habilidade tinha
	# regra diferente dependendo de quem caía nela.
	if get_meta("damage_immune", false) or get_meta("custom_pose", "") == "hibashira" or get_meta("in_black_hole", false):
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
	if _camera: _camera.pedir_fov_punch(8.0 if ult else 5.0)
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
		if _camera: _camera.pedir_fov_punch(3.0))

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
	# ⚠️ SEGUNDO ESCRITOR do estado autoritativo da Buki — o gêmeo da armadilha
	# de 2026-08-11. Está morto pelo caminho de input (begin_charge e
	# cast_skill_slot desviam para `_buki_empunhar` e RETORNAM), mas continua
	# alcançável pelo RPC `_net_cast` vindo de um cliente. Some com ele e o
	# servidor volta a recusar tiro por caminho que ninguém lembra de testar.
	_buki.servidor_sacar(slot)
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
		if not _buki.servidor_autoriza_tiro(arma):
			return
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
	return _buki.municao_max()

# EMPUNHAR / GUARDAR: a regra mora no componente; aqui fica o que é do Player
# (autoridade e supressão) e o encanamento de rede.
func _buki_empunhar(slot: String) -> void:
	_buki.empunhar(slot, _is_authority, is_suppressed)

func _buki_guardar() -> void:
	_buki.guardar()

@rpc("any_peer", "reliable")
func _net_buki_sacar_req(slot: String) -> void:
	if multiplayer.is_server():
		_do_server_buki_sacar(slot)

# SERVIDOR: guarda qual arma este corpo empunha e com quanta munição, e manda
# todos os peers mostrarem a arma. O servidor é quem valida cada tiro depois.
func _do_server_buki_sacar(slot: String) -> void:
	if not _buki.servidor_sacar(slot):
		return
	if multiplayer.has_multiplayer_peer():
		_net_buki_sacar.rpc(slot)
	else:
		_net_buki_sacar(slot)

@rpc("any_peer", "call_local", "reliable")
func _net_buki_sacar(slot: String) -> void:
	_buki_mostrar_arma(slot)

@rpc("any_peer", "reliable")
func _net_buki_guardar_req() -> void:
	if multiplayer.is_server():
		_do_server_buki_guardar()

# SERVIDOR: zera a munição autoritativa (nenhum tiro mais é aceito) e manda todo
# mundo tirar a arma da mão.
func _do_server_buki_guardar() -> void:
	_buki.servidor_guardar()
	if multiplayer.has_multiplayer_peer():
		_net_buki_guardar.rpc()
	else:
		_net_buki_guardar()

@rpc("any_peer", "call_local", "reliable")
func _net_buki_guardar() -> void:
	_buki_mostrar_arma("")

func _buki_apontar_canhao() -> void:
	_buki.apontar_canhao(_is_authority, _pitch, _yaw, net_facing)
