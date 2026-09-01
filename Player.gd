class_name Player
extends CharacterBody3D

signal player_damaged(amount: float, hp: float, mhp: float)
signal aim_assist_changed(on: bool)
signal combat_mode_updated(mode: String, style_id: String, fruit_id: String)
signal anim_name_shown(text: String)

# ============================================================================
#  Jogador = um bloco cinza. Anda (WASD / setas), pula (Espaco).
#  F5 alterna 1a <-> 3a pessoa. Mouse olha. ESC solta o mouse; segure pra sair.
#
#  Sem InputMap: le o teclado direto, entao o projeto roda sem configuracao.
# ============================================================================

const SPEED := 4.2
const JUMP_VELOCITY := 16.0

## Quão depressa o corpo alcança a mira. Alto o bastante para não haver atraso
## perceptível entre girar o mouse e o golpe sair na direção nova; baixo o
## bastante para o giro não ser um corte seco. Era 24 no caso parado e 35 no caso
## em movimento — dois números para a mesma coisa, agora um só.
const VELOCIDADE_FACING := 26.0

## Altura do eixo do rolamento de costas, a partir dos pés. É a cintura: uma
## cambalhota gira em torno do centro de massa, não do chão nem da cabeça.
const ALTURA_DO_ROLAMENTO := 0.55

## ANDAR NA SUPERFÍCIE (a mecânica que substituiu a escalada). O custo por
## segundo é o que impede a mecânica de tornar o chão irrelevante: ela é um
## RECURSO, não um modo de locomoção grátis.
const CUSTO_PAREDE_POR_SEG := 22.0

## Gira o modelo para uma base ALVO preservando a ESCALA MUNDIAL dele.
##
## ⚠️ `global_basis = ...orthonormalized()` DESTRÓI A ESCALA. Uma base
## ortonormalizada tem escala 1, e o modelo do jogador está em **0,4167** — o
## personagem ficava 2,4× MAIOR ao encostar na parede. Com a Gura Gura, que
## escala o Player em 2×, preservar somente a escala local encolhe o modelo ao
## escrever no espaço global. Base carrega rotação E escala juntas; elas devem
## ser lidas e repostas no mesmo espaço.
func _girar_modelo(alvo: Basis, delta: float) -> void:
	if _char_model == null:
		return
	var escala_global: Vector3 = _char_model.global_transform.basis.get_scale()
	var atual := _char_model.global_basis.orthonormalized()
	var nova := atual.slerp(alvo.orthonormalized(), clampf(VELOCIDADE_FACING * delta, 0.0, 1.0))
	_char_model.global_basis = nova.orthonormalized().scaled(escala_global)


## true enquanto o corpo ainda está inclinado por ter andado numa superfície e
## precisa voltar a ficar em pé. Não vale durante o rolamento de costas, que
## inclina de propósito e tem o próprio desfazer.
func _endireitando() -> bool:
	if _char_model == null or _rolando_de_costas:
		return false
	return _char_model.global_transform.basis.y.normalized().dot(Vector3.UP) < 0.999


## Estado do rolamento de costas. `_pose_repouso` é a posição do modelo ANTES do
## giro — guardada, nunca suposta.
var _rolando_de_costas := false
var _pose_repouso := Vector3.ZERO
const GRAVITY := 32.0        # gravidade reforcada (Godot padrao ~9.8)
const MOUSE_SENS := 0.0035

# A câmera virou COMPONENTE (Fase 2 — ver docs/ARQUITETURA_PLAYER.md). O rig é
# dono do tremor, do soco de FOV, do balanço, da perspectiva e da distância;
# aqui só sobra a referência a ele e o `_cam` de conveniência para a mira.

# ⚠️ ATALHO DE DESENVOLVIMENTO, E ELE TEM UMA FONTE SÓ DESDE 2026-08-25.
#
# Havia TRÊS escritores da fruta inicial, e os três discordavam: este padrão
# dizia `bara_bara`, o `Main._spawn_player` equipava `mera_mera` (e vencia, por
# ser adiado), e o `test_initial_fruit` cobrava `gura_gura` — nome de uma sessão
# ainda mais antiga. O teste ficou vermelho e ninguém sabia qual dos três estava
# certo, porque não havia "certo": havia três opiniões.
#
# Agora o número mora aqui e os outros dois LEEM. Trocar a fruta de trabalho é
# mexer nesta linha.
#
# ⚠️ E ISTO NÃO É REGRA DE JOGO. A economia das frutas é achar a árvore,
# disputar o fruto e perdê-lo ao morrer (ver `docs/frutas/README.md`). Se este
# atalho chegar ao jogador final, essa economia deixa de existir.
# GATILHO para apagar: quando houver escolha de fruta/personagem no menu.
const FRUTA_INICIAL := "suke_suke"

var current_fruit_id: String = FRUTA_INICIAL
var active_style: String = "basic"
var combat_mode: String = "fruit" # "fruit" ou "style"
var speed_multiplier: float = 1.0
var jump_multiplier: float = 1.0

# Vida (barra verde, HUD) — máx 2048. Foco continua no knockback pra fora do mapa,
# mas agora o dano importa e é mostrado.
# VIDA/ENERGIA/EMPURRÃO -> src/player/health_controller.gd (Fase 8).
#
# Estas quatro são API PÚBLICA — `StatsHud`, `TargetSystem` e `GomuArm` leem, e
# os testes escrevem em `energy` para montar cenário. Por isso aqui a vista tem
# getter E setter: continua havendo UM dono do valor (o componente), mas a API
# não quebra. A regra "vista sem setter" vale para campo cujo write de fora é
# bug — não é o caso destes.
var _vida := HealthController.new()
var _mira := Mira.new()
var health: float:
	get: return _vida.vida
	set(v): _vida.vida = v
var max_health: float:
	get: return _vida.vida_max
	set(v): _vida.vida_max = v
# Energia (barra azul, HUD) — máx 4096. Regenera com o tempo; skills consomem.
var energy: float:
	get: return _vida.energia
	set(v): _vida.energia = v
var max_energy: float:
	get: return _vida.energia_max
	set(v): _vida.energia_max = v
const ENERGY_BULLET := 10.0        # por bala da rajada Z
const ENERGY_SKILL := 180.0        # por skill lançada
const ENERGIA_INVISIBILIDADE_POR_SEG := 55.0
# SILÊNCIO (Yami) -> CastController (passo 6d). Vistas: `is_suppressed` é lido
# em 5 pontos aqui e por sondas de fora.
var is_suppressed: bool:
	get: return _cast.suprimido()
var suppression_timer: float:
	get: return _cast.tempo_de_silencio()

var current_style_idx: int = 0
const STYLES_LIST: Array[String] = ["karate_tritao", "pacifista", "mink", "boxe", "cyborg", "teste_animacao"]

# ---- FSM DE COMBATE E INPUT BUFFER (Fase Nova) ----
var _fsm: PlayerStateMachine
var _input_buffer: Array = []
const BUFFER_WINDOW_MS = 400

func _add_input_to_buffer(action: String) -> void:
	_input_buffer.push_back({"action": action, "time": Time.get_ticks_msec()})
	if _input_buffer.size() > 10:
		_input_buffer.pop_front()

func _consume_input(action: String) -> bool:
	if has_meta("custom_pose") and get_meta("custom_pose") == "knockdown":
		return false
	if has_meta("is_frozen") and get_meta("is_frozen"):
		return false
		
	var current_time = Time.get_ticks_msec()
	_input_buffer = _input_buffer.filter(func(i): return current_time - i["time"] <= BUFFER_WINDOW_MS)
	for i in range(_input_buffer.size()):
		if _input_buffer[i]["action"] == action:
			_input_buffer.remove_at(i)
			return true
	return false

var hit_confirmed: bool = false

# ---------------------------------------------------------- GRUPOS DE ESTADO
# O "Attacking" único virou três fases em 2026-08-25 (§4.1 do
# PLANO_COMBATE_BATTLEGROUNDS). Quem só quer saber "está no meio de um golpe?"
# pergunta a estas listas em vez de repetir os três nomes — repetir era como o
# `in ["Attacking", "Casting", "Stunned"]` foi ficando para trás.
#
# "Casting" nunca existiu como nó (mesma armadilha do "Stunned"); fica na lista
# porque o dia que existir já entra funcionando, e listar um nome a mais não
# custa nada — o teste é de pertinência, não de existência.
const ESTADOS_DE_ATAQUE := ["AttackStartup", "AttackActive", "AttackRecovery"]
const ESTADOS_TRAVADOS := ["AttackStartup", "AttackActive", "AttackRecovery", "Casting", "Stunned"]

# Está no meio de um golpe do combo (qualquer das três fases)?
func esta_atacando() -> bool:
	return _fsm != null and _fsm.state != null and _fsm.state.name in ESTADOS_DE_ATAQUE

# O cast vive em src/player/cast_controller.gd (passo 6c). Aqui só as VISTAS —
# `_charging` é lido por 5 arquivos de fora.
var _cast := CastController.new()
var _charging: bool:
	get: return _cast.carregando()
var _charge_slot: String:
	get: return _cast.slot()
# Nº de série do cast atual. Cada `begin_charge` emite um novo. O temporizador de
# 0.3 s que apaga `is_casting` no fim do golpe carrega o número do golpe DELE e só
# apaga se ainda for o mesmo — senão o temporizador do golpe ANTERIOR apagava o
# `is_casting` do golpe SEGUINTE, e o bloco do _physics_process lia isso como
# "cast interrompido" e engolia a skill seguinte.
var _cast_token: int:
	get: return _cast.token()
	# _movement_locked_timer removido (FSM gerencia)
# IMPULSO EXTERNO (knockback). NÃO pode viver dentro de `velocity`: o bloco de
# locomoção faz `velocity.x = dir.x * speed` — ATRIBUIÇÃO, não soma — e apagaria
# o empurrão no quadro seguinte. Foi exatamente isso que fez ninguém tomar
# knockback, nem em rede nem em um-jogador. Vive aqui, decai sozinho, e é somado
# à velocidade logo antes do move_and_slide.

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
var _gear2: Gear2Controller   # componente: a transformação Gear 2 (slot V da Gomu)
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
# Mera Mera Z: rajada de balas de fogo (segura pra atirar; para ao soltar ou 8 balas).
# Rajada Z e pistola da Yami -> src/player/disparo_sustentado.gd (passo 6a).
# Aqui só as VISTAS.
var _disparo := DisparoSustentado.new()
const FootDustController = preload("res://src/player/foot_dust_controller.gd")
const RunAccelerationController = preload("res://src/player/run_acceleration_controller.gd")
const FallImpactController = preload("res://src/player/fall_impact_controller.gd")
const AirSlamFXClass = preload("res://src/effects/AirSlamFX.gd")
const SpinKickFXClass = preload("res://src/effects/SpinKickFX.gd")
const ContextualMeleeData = preload("res://src/combat/contextual_melee.gd")
const ContextualMeleeFXClass = preload("res://src/effects/contextual_melee_fx.gd")
const AfterimageTrail = preload("res://src/player/afterimage_trail.gd")
const IronBodyController = preload("res://src/player/iron_body_controller.gd")
var _poeira_dos_pes := FootDustController.new()
var _aceleracao_da_corrida := RunAccelerationController.new()
var _impacto_de_queda := FallImpactController.new()
var _ecos_de_movimento := AfterimageTrail.new()
var _corpo_de_ferro := IronBodyController.new()
var _rapid_fire: bool:
	get: return _disparo.rajada_ativa()
var _gun_recoil: float = 0.0   # coice da rajada Z (1->0 por tiro) p/ a pose de mira
var _pistols: Array:           # pistolas nas DUAS mãos (visíveis só na rajada Z)
	get: return _rig.pistolas() if _rig else []
var _yami_pistol_active: bool:
	get: return _disparo.yami_ativa()

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
var _fruit_cooldowns: Dictionary = {"Z": 0.0, "X": 0.0, "C": 0.0, "V": 0.0}
var _style_cooldowns: Dictionary = {"Z": 0.0, "X": 0.0, "C": 0.0, "V": 0.0}
var _skill_cooldowns: Dictionary:
	get: return _fruit_cooldowns if combat_mode == "fruit" else _style_cooldowns
var _combo_breaker_cooldown: float = 0.0
var aim_assist: bool = false   # Haki da Observação (liga/desliga no E)
var _gura_rush_active := false
var _gura_rush_timer := 0.0
var _gura_rush_dir := Vector3.ZERO
var _gura_rush_target: Node3D = null
var _gura_grab_timer := 0.0
var _bomu_rush_active := false
var _bomu_rush_timer := 0.0
var _bomu_grab_timer := 0.0
var _bomu_rush_dir := Vector3.ZERO
var _bomu_rush_target: Node3D = null
var _bomu_hand_charge: Node3D = null
var _mink_bite_dash := false
var _mink_bite_timer := 0.0
var _mink_bite_dir := Vector3.ZERO
var _mink_bite_target: Node3D = null
var _mink_hold_timer := 0.0
# A investida só é punida quando a mordida CONFIRMA o agarrão. Errar é uma
# abertura curta de movimento, não uma habilidade perdida.
const RECARGA_MORDIDA_MINK := 3.0
var _mink_bite_cooldown := 0.0
const RECARGA_QUEDA_ESMAGADORA := 3.0
var _air_slam_active := false
var _air_slam_cooldown := 0.0
var _spin_kick_active := false
var _spin_kick_angle := 0.0
var _spin_kick_rest_position := Vector3.ZERO
var _spin_kick_yaw := 0.0
const RECARGA_CHUTE_GIRATORIO := 5.0
var _spin_kick_cooldown := 0.0
# Ataques W/A/S/D compartilham o relógio do MeleeController. Estes campos são
# apenas a apresentação e a base congelada, inclusive nas cópias remotas.
var _contextual_attack_id := ""
var _contextual_attack_yaw := 0.0
var _contextual_presentation_token := 0
# Sequência monotônica do dono. Ela separa duas cotoveladas iguais em rede e
# permite que confirmação, rejeição e cancelamento atinjam somente o golpe que
# lhes deu origem — nunca uma ação posterior que reutilizou o mesmo ID.
var _contextual_attack_seq := 0
var _contextual_presented_seq := -1
# O servidor não lê teclado remoto; em vez disso valida enum, arma, chão,
# origem e cadência. A sequência e o token também impedem RPC repetido e timers
# de hitbox que sobreviveram a dano, dash-cancel ou respawn.
var _server_contextual_next_ms := 0
var _server_contextual_last_seq := -1
var _server_contextual_active_seq := -1
var _server_contextual_token := 0
var _server_contextual_deadline_ms := 0
# Após dano real, poderes de fruta aguardam uma janela curta. Estilos e M1
# continuam livres: esta é recuperação da Akuma no Mi, não um stun geral.
const TRAVA_FRUTA_APOS_DANO := 1.0
var _fruit_damage_lock_timer := 0.0
var _invisivel := false
var _materiais_antes_da_invisibilidade: Dictionary = {}

# ---- corpo a corpo (botão esquerdo): soco D -> soco E -> chute ----
# Ver src/combat/Melee.gd. `_melee_janela` conta o tempo que ainda resta pra
# encadear; zerou, o próximo clique volta ao primeiro soco.
# O combo vive em src/player/melee_controller.gd (Fase 7).
var _melee := MeleeController.new()

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
	var combat_locked = _fsm and _fsm.state and _fsm.state.name in ESTADOS_TRAVADOS
	if combat_locked:
		return str(get_meta("active_skill", ""))
	return ""

func abort_gatling() -> void:
	if not is_inside_tree():
		return
	var world = get_tree().current_scene
	if world:
		for child in world.get_children():
			if child is GomuGatling and child._caster == self:
				child.abort()

# POSE DE ARMA (braço estendido, mirando): rajada Z, pistola da Yami e agora
# qualquer arma de BRAÇO da Buki. O canhão-corpo (X) fica de fora — lá o modelo
# está escondido, e mandar o rig fazer pose de pistoleiro seria trabalho à toa.
func _pose_de_arma() -> bool:
	return _rapid_fire or _yami_pistol_active or (_buki_weapon != "" and _buki_weapon != "X")

# FONTE ÚNICA das recargas. Virou constante porque o SERVIDOR passou a precisar
# dos mesmos números para barrar o saque repetido da Buki (ver
# `BukiController.servidor_sacar`) — dois lugares com a mesma tabela escrita à
# mão é como o furo de munição infinita nasceu.
# V baixou de 60 para 25 s a pedido do dono (2026-08-12): com 60 s o ultimate
# saía uma vez por rodada de 5 min, e testar a mecânica de Charge-up exigia
# esperar um minuto por tentativa.
const RECARGA_POR_SLOT := {"Z": 5.0, "X": 7.0, "C": 10.0, "V": 25.0}

# ESTILO DE LUTA custa 1 MINUTO em qualquer slot (pedido do dono, 2026-08-12).
# É o preço de não depender de fruta: o estilo está SEMPRE disponível — não
# precisa achar árvore, não se perde na morte, não some quando outro jogador
# pega a fruta antes. Uma recarga própria e cara é o que impede o estilo de ser
# estritamente melhor que a fruta.
# ⚠️ Vale para TODOS os estilos, não só o Tritão — foi assim que o dono pediu
# ("para todos os ataques de skills que não sejam frutas").
const RECARGA_ESTILO := 60.0

func trigger_skill_cooldown(slot: String) -> void:
	if not RECARGA_POR_SLOT.has(slot):
		return
	if combat_mode == "style":
		_style_cooldowns[slot] = RECARGA_ESTILO
	else:
		if current_fruit_id == "":
			_fruit_cooldowns[slot] = 0.0
		elif current_fruit_id == "bomu_bomu" or current_fruit_id == "suke_suke":
			_fruit_cooldowns[slot] = 10.0
		else:
			_fruit_cooldowns[slot] = RECARGA_POR_SLOT[slot]
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

var _hitstop_timer: float = 0.0

@export var net_velocity: Vector3 = Vector3.ZERO   # replicado (autoridade -> demais)
@export var net_facing: float = 0.0
@export var net_on_floor: bool = true
# Estado visual de cargas que precisam aparecer antes do impacto. São somente
# apresentação: o servidor continua sendo a autoridade que cria o golpe final.
@export var net_charge_pose: String = ""
@export var net_charge_progress: float = 0.0

func _ready() -> void:
	add_to_group("player")
	# Autoridade = eu sou dono desse player (mesmo em singleplayer, id 1 é meu)
	_is_authority = is_multiplayer_authority()
	print("[Player] _ready! name=", name, " authority=", get_multiplayer_authority(), " is_auth=", _is_authority, " peer=", multiplayer.get_unique_id())   # SP: host=autoridade -> true

	# RIG E MODELO — componente próprio desde a Fase 3. Precisa existir ANTES do
	# set_character, que é justamente quem manda o rig montar o corpo.
	_rig = PlayerRig.new()
	_rig.name = "PlayerRig"
	add_child(_rig)
	_rig.montar_em(self)
	_dash.montar_em(self)

	_fsm = PlayerStateMachine.new()
	_fsm.name = "CombatFSM"
	_fsm.set_physics_process(false)
	
	# ⚠️ O NOME DO NÓ É O ENDEREÇO. `PlayerStateMachine.transition_to` resolve por
	# `has_node(nome)` e faz `return` calado quando não acha — foi assim que
	# "Stunned" ficou sendo pedido em sete pontos do arquivo sem nunca existir
	# (ver o cabeçalho de `CombatStateStunned.gd`). Estado novo entra AQUI, ou
	# ele não entra em lugar nenhum.
	var state_idle = CombatStateIdle.new()
	state_idle.name = "Idle"
	_fsm.add_child(state_idle)

	# As TRÊS fases do golpe (§4.1 do PLANO_COMBATE_BATTLEGROUNDS). Substituem o
	# antigo "Attacking", que não distinguia preparar de estar preso no rabo do
	# golpe — e era nessa diferença que morava o contra-jogo inteiro.
	var state_startup = CombatStateAttackStartup.new()
	state_startup.name = "AttackStartup"
	_fsm.add_child(state_startup)

	var state_active = CombatStateAttackActive.new()
	state_active.name = "AttackActive"
	_fsm.add_child(state_active)

	var state_recovery = CombatStateAttackRecovery.new()
	state_recovery.name = "AttackRecovery"
	_fsm.add_child(state_recovery)

	var state_stunned = CombatStateStunned.new()
	state_stunned.name = "Stunned"
	_fsm.add_child(state_stunned)

	var state_dashing = CombatStateDashing.new()
	state_dashing.name = "Dashing"
	_fsm.add_child(state_dashing)
	
	add_child(_fsm)
	_fsm.init(self, state_idle.get_path())
	_buki.montar_em(self, _rig)
	_disparo.montar_em(self)
	_poeira_dos_pes.montar_em(self)
	_corpo_de_ferro.montar_em(self)
	_cast.montar_em(self)
	_melee.montar_em(self)
	_vida.montar_em(self)
	_mira.montar_em(self)
	_parkour.montar_em(self, GRAVITY, JUMP_VELOCITY)

	# Substitui o quadrado cinza pelo modelo 3D Voxel e equipa a Akuma no Mi correspondente
	set_character(character_id)

	# Colisor do jogador.
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = COLISOR_BASE
	col.shape = shape
	add_child(col)
	_colisor = col

	# CÂMERA — componente próprio desde a Fase 2. Ele monta a cadeia
	# (pivô → ombro → SpringArm → Camera3D) e é dono de tremor, FOV e balanço.
	# O `_cam` fica guardado aqui só porque a mira o consulta em 26 lugares.
	_camera = CameraRig.new()
	_camera.name = "CameraRig"
	add_child(_camera)
	_camera.montar(self, _is_authority)
	_cam = _camera.camera()

	# Gear 2: a primeira TRANSFORMAÇÃO. Componente próprio porque tem estado com
	# entrada, duração e quatro saídas distintas (relógio, morte, troca de fruta,
	# troca de personagem) — ver o cabeçalho de `gear2_controller.gd`.
	_gear2 = Gear2Controller.new()
	_gear2.name = "Gear2"
	add_child(_gear2)
	_gear2.montar(self, _rig)

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
		
	# Se clicar na tela com o mouse solto (ex: após alt-tab), recaptura ele.
	# Menus abertos consomem o input antes, então isso só roda no jogo limpo.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
		# 2026-08-22: o E deixou de ser só assistência de mira. Com ele ligado, os
		# corpos e os ATAQUES EM VOO dos outros passam a ser desenhados através das
		# paredes (`ScreenFX`: `no_depth_test` no material de destaque).
		print("👁️ Observação (alvos e preparações através de paredes): ",
			"LIGADA" if aim_assist else "DESLIGADA")
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("set_aim_assist"):
			hud.set_aim_assist(aim_assist)
		if Engine.has_singleton("ScreenFX") or get_node_or_null("/root/ScreenFX"):
			get_node("/root/ScreenFX").set_aim_assist(aim_assist, self)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_request_combo_breaker()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_pedir_corpo_de_ferro()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not event.echo:
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
		# esquerdo (têm tratamento próprio em `DisparoSustentado` /
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
# ------------------------------------------------------- PEDIDO DO CORPO A CORPO
# O golpe tem que NASCER NO SERVIDOR: a `DamageZone` só machuca lá.
func pedir_golpe_no_servidor(passo: int, origem: Vector3, fwd: Vector3) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_melee(passo, origem, fwd)
	else:
		_net_melee.rpc_id(1, passo, origem, fwd)

# ------------------------------------------------------------ PEDIDOS DO CAST
# `CastController` (passo 6c) decide SE e COMO conjurar; o que é do Player
# continua do Player.

# A mira do cast: raio da câmera até o mundo, e a origem à frente do corpo.
# Fica aqui porque depende da câmera e do corpo — os dois são do Player.
func mira_do_cast() -> Dictionary:
	var frente := -_cam.global_transform.basis.z
	var origem := global_position + Vector3.UP * 1.0 + frente * 1.5
	var espaco := get_world_3d().direct_space_state
	var de := _cam.global_position
	var ate := de + frente * 150.0
	var par := PhysicsRayQueryParameters3D.create(de, ate)
	par.exclude = [get_rid()]
	# Ignora ÁREAS (triggers e a própria DamageZone) para a mira não bater no ar.
	par.collide_with_areas = false
	par.collide_with_bodies = true
	var hit := espaco.intersect_ray(par)
	var ponto: Vector3 = hit.position if not hit.is_empty() else ate
	return {"aim": (ponto - origem).normalized(), "origem": origem}

# Host/SP JÁ é o servidor -> executa a autoridade DIRETO (`rpc_id` a si mesmo é
# proibido pelo Godot). Cliente puro -> pede ao servidor (peer 1).
func pedir_cast_no_servidor(slot: String, aim: Vector3, origem: Vector3, charge: float = 0.0) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_cast(slot, aim, origem, charge)
	else:
		_net_cast.rpc_id(1, slot, aim, origem, charge)

func pedir_iniciar_hold(slot: String, fruit: String) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_net_start_hold(slot, fruit)
	else:
		_net_start_hold.rpc_id(1, slot, fruit)

@rpc("any_peer", "call_local", "reliable")
func _net_start_hold(slot: String, fruit: String) -> void:
	var cid = multiplayer.get_remote_sender_id()
	if cid != 0 and cid != get_multiplayer_authority() and multiplayer.is_server():
		return
	if fruit == "yami_yami":
		if slot == "C":
			set_meta("yami_black_hole_active", true)
		elif slot == "X":
			set_meta("yami_kurouzu_active", true)
	elif fruit == "bara_bara":
		if slot == "C":
			set_meta("bara_cleave_active", true)

func pedir_cancelar_hold(slot: String, fruit: String) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_net_cancel_hold(slot, fruit)
	else:
		_net_cancel_hold.rpc(slot, fruit)

@rpc("any_peer", "call_local", "reliable")
func _net_cancel_hold(slot: String, fruit: String) -> void:
	var cid = multiplayer.get_remote_sender_id()
	if cid != 0 and cid != get_multiplayer_authority() and multiplayer.is_server():
		return
	if fruit == "yami_yami":
		if slot == "C":
			set_meta("yami_black_hole_active", false)
		elif slot == "X":
			set_meta("yami_kurouzu_active", false)
	elif fruit == "bara_bara":
		if slot == "C":
			set_meta("bara_cleave_active", false)

# Carregar um golpe PRENDE o corpo no lugar. `velocity` é do domínio de
# movimento — por isso é pedido, não escrita.
func congelar_para_cast() -> void:
	velocity = Vector3.ZERO

# Pausar a animação enquanto mira é apresentação, e o animador é do rig.
func pausar_animacao(pausado: bool) -> void:
	if _animator and _animator.animation_player:
		_animator.animation_player.speed_scale = 0.0 if pausado else 1.0

# Guardar a pistola da Yami some com ela do rig também — o componente de
# disparo não conhece as pistolas (elas são do `PlayerRig`).
func guardar_pistola_da_yami() -> void:
	_disparo.desligar_yami()
	for g in _pistols:
		if is_instance_valid(g):
			g.visible = false

func pedir_soco_de_fov(quantidade: float) -> void:
	if _camera:
		_camera.pedir_fov_punch(quantidade)

func estilo_atual() -> String:
	return STYLES_LIST[current_style_idx] if current_style_idx < STYLES_LIST.size() else ""

# ------------------------------------------------- PEDIDOS DO DISPARO SUSTENTADO
# `DisparoSustentado` (passo 6a) é dono da rajada Z e da pistola da Yami, e não
# escreve estado alheio.

# `energy` é campo de TRÊS domínios (ciclo, skills, respawn) e está reservada
# para a Fase 8 — por isso é pedido, não escrita direta.
func gastar_energia(custo: float) -> void:
	_vida.gastar(custo)

# Bala SEM arma (rajada Z e pistola da Yami). O canal é o mesmo da Buki, e é por
# isso que ele mora aqui: RPC se resolve por CAMINHO DE NÓ.
func pedir_bala_simples(aim: Vector3, origem: Vector3) -> void:
	if not _is_authority or is_suppressed:
		return
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_bullet(aim, origem, "")
	else:
		_net_bullet_req.rpc_id(1, aim, origem, "")

# Aplica uma mira já calculada. Quem decide PARA ONDE olhar é quem tem a arma;
# `_yaw`/`_pitch` continuam sendo do Player (decisão da Fase 2, porque quem os
# escreve é o input). `forca_corpo` existe porque cada arma vira o corpo num
# ritmo diferente — a Yami em 20, a Buki em 14.
func aplicar_mira(novo_yaw: float, novo_pitch: float, delta: float, forca_corpo: float) -> void:
	_yaw = novo_yaw
	_pitch = novo_pitch
	_update_pivot()
	if _char_model:
		# ⚠️ Enquanto anda na superfície, o corpo é orientado pela NORMAL dela
		# (ver o bloco da frente). Escrever `rotation.y` aqui zeraria a
		# inclinação e o personagem voltaria a ficar em pé no ar.
		if not _parkour.na_parede():
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, forca_corpo * delta)

# ---------------------------------------------------------- PEDIDOS DA BUKI
# O `BukiController` (Fase 5) é dono do arsenal, mas NÃO escreve estado alheio.
# Estes são os pedidos dele — mesma disciplina do `pedir_shake` (Fase 2) e do
# `pedir_rolamento` (Fase 4).

# RECUO do canhão: o tranco empurra o jogador. O empurrão e a `velocity` são de
# domínio de MOVIMENTO; o arsenal pede, não escreve.
func pedir_recuo(direcao: Vector3, forca: float) -> void:
	_vida.empurrar_cru(direcao, forca)
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
		# ⚠️ Enquanto anda na superfície, o corpo é orientado pela NORMAL dela
		# (ver o bloco da frente). Escrever `rotation.y` aqui zeraria a
		# inclinação e o personagem voltaria a ficar em pé no ar.
		if not _parkour.na_parede():
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
## O parkour pergunta antes de grudar e a cada quadro: sem energia, não anda na
## superfície. Fica aqui porque `energy` é do Player.
func tem_energia_de_parede() -> bool:
	return energy > 0.0


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
	if _gear2:
		_gear2.atualizar(delta)

# (Antiga função _processar_estados_de_combate removida, lógica movida para os States)

func _physics_process(delta: float) -> void:
	# HITSTOP LOCAL: Personagem congela e treme após um golpe, segurando o knockback
	if _hitstop_timer > 0.0:
		if _animator and _animator.animation_player:
			_animator.animation_player.speed_scale = 0.0
		_hitstop_timer -= delta
		if _char_model:
			_char_model.position.x = randf_range(-0.06, 0.06)
			_char_model.position.z = randf_range(-0.06, 0.06)
		if _hitstop_timer <= 0.0:
			if _char_model:
				_char_model.position.x = 0.0
				_char_model.position.z = 0.0
			if _animator and _animator.animation_player:
				_animator.animation_player.speed_scale = 1.0
		_etapa_publicar_rede()
		return # Ignora o movimento, mas agora a rede continua sendo enviada

	if _fsm:
		_fsm._physics_process(delta)

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
	# ⚠️ ANTES DO PORTÃO DE TRAVAMENTO, e isto NÃO é detalhe de ordem.
	# O tranco de dano estava depois, e a paralisia (que ESTE contador desliga)
	# faz `_etapa_travamento` devolver true — ou seja, o mecanismo que congela
	# bloqueava o relógio que descongela. Medido: alvo seguia congelado em 1,5 s
	# de uma paralisia de 1,2 s, e a pose nunca saía.
	# Mesma classe do item 23 (morrer segurando a tecla travava o jogo para
	# sempre): estado que só se apaga por um caminho que ele próprio fecha.
	var _hitstun_ativo = RecepcaoDeDano.tick(self, delta)
	if not _hitstun_ativo and _fsm and _fsm.state and _fsm.state.name == "Stunned":
		_fsm.transition_to("Idle")
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
	_corpo_de_ferro.atualizar(delta)
	for g in _pistols:
		if is_instance_valid(g):
			# A Mera Z usa as mesmas armas durante a carga: primeiro nos coldres,
			# depois nas mãos. O rig é dono desse estado para não apagar a arma no
			# quadro entre o fim da carga e o primeiro disparo.
			g.visible = _rapid_fire or _yami_pistol_active or _rig.pistolas_em_saque()
	_vida.regenerar(delta)     # regen contínua de energia
	if _invisivel:
		energy = maxf(energy - ENERGIA_INVISIBILIDADE_POR_SEG * delta, 0.0)
		if energy <= 0.0:
			revelar_invisibilidade()
	# RECARGA CONGELA DURANTE UMA HABILIDADE (regra do dono do projeto).
	# Enquanto um golpe está em andamento, a recarga das OUTRAS técnicas para de
	# correr — só a do próprio golpe em uso continua. Sem isso dava para segurar
	# um golpe longo (Black Hole, 7 s de trava) e sair dele com a barra inteira
	# recarregada de graça: o tempo de um golpe pagava o tempo de todos.
	var em_uso := _slot_em_uso()
	for slot_k in _fruit_cooldowns.keys():
		if _fruit_cooldowns[slot_k] <= 0.0:
			continue
		if em_uso != "" and slot_k != em_uso and combat_mode == "fruit":
			continue                       # congelado: outra habilidade está ativa
		_fruit_cooldowns[slot_k] = maxf(_fruit_cooldowns[slot_k] - delta, 0.0)
	
	for slot_k in _style_cooldowns.keys():
		if _style_cooldowns[slot_k] <= 0.0:
			continue
		if em_uso != "" and slot_k != em_uso and combat_mode == "style":
			continue                       # congelado: outra habilidade está ativa
		_style_cooldowns[slot_k] = maxf(_style_cooldowns[slot_k] - delta, 0.0)
	if _combo_breaker_cooldown > 0.0:
		_combo_breaker_cooldown = maxf(_combo_breaker_cooldown - delta, 0.0)
	if _mink_bite_cooldown > 0.0:
		_mink_bite_cooldown = maxf(_mink_bite_cooldown - delta, 0.0)
	if _air_slam_cooldown > 0.0:
		_air_slam_cooldown = maxf(_air_slam_cooldown - delta, 0.0)
	if _fruit_damage_lock_timer > 0.0:
		_fruit_damage_lock_timer = maxf(_fruit_damage_lock_timer - delta, 0.0)
	if _spin_kick_cooldown > 0.0:
		_spin_kick_cooldown = maxf(_spin_kick_cooldown - delta, 0.0)
	if _yami_pistol_active:
		_disparo.atualizar_yami(delta, _yaw, _pitch)
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
	if _charging or _rapid_fire or (has_meta("is_frozen") and get_meta("is_frozen")) or (has_meta("in_vortex") and get_meta("in_vortex")) or (has_meta("in_kurouzu") and get_meta("in_kurouzu")) or (has_meta("in_black_hole") and get_meta("in_black_hole")):
		if _charging and not (has_meta("is_casting") and get_meta("is_casting")):
			_cast.abortar()            # cast foi interrompido (ex.: dano) -> destrava
		else:
			velocity = Vector3.ZERO    # congela no lugar (sem gravidade)
			
			if _breath:
				_breath.set_running(false)
			# Rajada Z: vira o corpo p/ a direção da mira (pose de pistoleiro) + coice decai.
			if _rapid_fire and _char_model:
				if not _parkour.na_parede():
					_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw, 18.0 * delta)
			if _gun_recoil > 0.0:
				_gun_recoil = maxf(_gun_recoil - delta * 7.0, 0.0)
			if _proc_anim:
				# Na RAJADA Z não passa charge_slot: senão herda o active_skill ("C") e o
				# animator aplica o tremor de torso do Gatling, quebrando a pose das pistolas.
				var pose_custom := str(get_meta("custom_pose", ""))
				var slot_to_pass = "" if _pose_de_arma() or pose_custom == "mera_z_charge" or pose_custom == "mera_x_charge" else (_charge_slot if _charging else get_meta("active_skill", ""))
				var mera_z_progress := _cast.progresso_mera_z() if _cast else 0.0
				var mera_x_progress := _cast.progresso_mera_x() if _cast else 0.0
				# Esta publicação fica no caminho travado porque o `return` abaixo não
				# deixa `_etapa_publicar_rede` rodar enquanto a tecla está pressionada.
				net_charge_pose = pose_custom if pose_custom in ["mera_z_charge", "mera_x_charge"] else ""
				net_charge_progress = mera_x_progress if pose_custom == "mera_x_charge" else mera_z_progress if pose_custom == "mera_z_charge" else 0.0
				_proc_anim.update(velocity, is_on_floor(), false, delta, _pitch, false, _charging, slot_to_pass, "", _pose_de_arma(), _gun_recoil, mera_z_progress, _disparo.lado_do_ultimo_tiro(), mera_x_progress, pose_custom)
			move_and_slide()
			_disparo.tick_rajada(delta, ENERGY_BULLET)    # dispara as balas de fogo/gelo enquanto a rajada dura
			
			# ⚠️ Quem chegou aqui está travado por definição. O quadro
			# acaba aqui para TODOS os motivos de trava.
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
	var menu_aberto := false
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("is_menu_open"):
		menu_aberto = hud.is_menu_open()
		
	q.ler(_yaw, not menu_aberto)
	# Rajada (Mera/Hie Z): fica PARADO enquanto atira; só a câmera gira. Volta a
	# andar ao soltar o botão ou acabar as balas (release_charge zera _rapid_fire).
	if _rapid_fire or (has_meta("custom_pose") and get_meta("custom_pose") == "knockdown"):
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
	# DASH-CANCEL — agora só na RECUPERAÇÃO, e só se o golpe conectou.
	#
	# Antes valia em "Attacking" inteiro, o que incluía o startup: dava para
	# apertar, ver que ia acertar e sumir antes mesmo de a hitbox nascer. Com
	# as três fases a regra fica onde o §4.1 a colocou — startup e ativo são
	# compromisso, recuperação é onde há escolha.
	#
	# Quem responde é o próprio estado (`pode_cancelar_para_dash`), não um `if`
	# aqui: a regra do cancelamento é do estado que a sofre.
	var dash_bloqueado := _charging or _rapid_fire or _yami_pistol_active
	if _fsm and _fsm.state and _fsm.state.name != "Idle":
		dash_bloqueado = true
		if _fsm.state.name == "AttackRecovery" and _fsm.state.pode_cancelar_para_dash():
			dash_bloqueado = false # Dash cancel liberado!

	_dash.atualizar(delta, q, dash_bloqueado)

	if _dash.ativo() and _fsm and _fsm.state and _fsm.state.name != "Idle":
		# O golpe em voo morre junto com o estado. Sem isso o `MeleeController`
		# seguiria contando as fases de um golpe que a esquiva já cancelou, e a
		# `fase()` mentiria para a FSM no quadro seguinte.
		if _melee and _fsm.state.name in ESTADOS_DE_ATAQUE:
			_melee.cancelar_golpe()
		_fsm.transition_to("Idle") # Quebra o estado de combate se o dash conseguiu disparar

	# M1 normal não prende mais o deslocamento: o jogador pode andar enquanto
	# soca/chuta. As exceções são estilos especiais que controlam a própria
	# velocidade (hoje, a mordida Mink ao segurar alguém).
	var golpe_prende := _mink_hold_timer > 0.0
	if golpe_prende:
		q.travar_golpe()

	# `bonus_velocidade` é o impulso horizontal do salto longo / vault: o parkour
	# devolve o FATOR e quem multiplica é a etapa. Componente não escreve na
	# velocidade dos outros.
	# A corrida começa em 1,5× a caminhada e, mantida no chão por 3 segundos,
	# chega ao dobro dela (3× a caminhada). Qualquer interrupção zera o embalo.
	var impulso_corrida := _aceleracao_da_corrida.atualizar(delta,
		q.sprint and is_on_floor() and not _parkour.assumiu() and not golpe_prende)
	var effective_speed := SPEED * speed_multiplier * (1.5 if q.sprint else 1.0) * impulso_corrida * _parkour.bonus_velocidade()

	# ⚠️ O CUSTO DA SUPERFÍCIE É COBRADO AQUI, e não junto da velocidade. Andar
	# na parede entra por `_parkour.assumiu()` (a mesma porta da escalada e do
	# wall run), então um `elif` no bloco do dash NUNCA rodava — a energia não
	# saía e a mecânica ficava de graça. Um ponto só, que roda todo quadro.
	if _parkour.na_parede():
		energy = maxf(energy - CUSTO_PAREDE_POR_SEG * delta, 0.0)

	# QUEM MANDA NA VELOCIDADE DESTE QUADRO.
	# Escalada e wall run são exclusivos: enquanto valem, o parkour manda sozinho.
	if _parkour.assumiu():
		velocity = _parkour.velocidade(delta, q, velocity, effective_speed)
	else:
		# Gravidade.
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
			# A queda esmagadora usa exatamente 3× a aceleração da gravidade. A
			# velocidade do clique já foi triplicada na ativação; esta linha mantém
			# a mesma proporção até o pouso, sem impor uma velocidade artificial.
			if _air_slam_active:
				velocity.y -= GRAVITY * delta * 2.0

		# Vault, salto longo, pulo normal e geppo: o parkour recebe a velocidade
		# e devolve a velocidade — não escreve nela.
		velocity = _parkour.aplicar_pulos(q, velocity, effective_speed, is_on_floor(), jump_multiplier)

		if _dash.passo() > 0.0:
			velocity = _dash.velocidade(delta)

		elif _bomu_rush_active:
			velocity.x = _bomu_rush_dir.x * effective_speed * 4.6
			velocity.z = _bomu_rush_dir.z * effective_speed * 4.6
			_process_bomu_rush(delta)
		elif _gura_rush_active:
			velocity.x = _gura_rush_dir.x * effective_speed * 4.0
			velocity.z = _gura_rush_dir.z * effective_speed * 4.0
			_process_gura_rush(delta) # HITBOX e Timer da Investida!
		elif _mink_bite_dash:
			velocity.x = _mink_bite_dir.x * effective_speed * 3.8
			velocity.z = _mink_bite_dir.z * effective_speed * 3.8
			_process_mink_bite(delta)
		elif _mink_hold_timer > 0.0:
			velocity.x = 0.0
			velocity.z = 0.0
			_process_mink_hold(delta)
		elif _melee and _melee.contextual_ativo():
			_processar_movimento_contextual()
		elif _spin_kick_active:
			var giro_frente := RosaDosVentos.frente(_spin_kick_yaw)
			velocity.x = giro_frente.x * 8.0
			velocity.z = giro_frente.z * 8.0
		else:
			velocity.x = q.dir.x * effective_speed
			velocity.z = q.dir.z * effective_speed

	# ============================================================ A FRENTE
	# ⚠️ O CORPO OLHA PARA A MIRA, SEMPRE. Decisão do dono (2026-08-27).
	#
	# Antes a frente seguia o MOVIMENTO: andar para o lado virava o corpo para o
	# lado, e a mira só mandava quando o jogador estava parado. Isso faz sentido
	# num jogo de aventura, e é o oposto do que um jogo de luta/tiro precisa —
	# ali o que importa é para onde o golpe sai, e o golpe sai para onde a MIRA
	# aponta (`melee_controller` e as skills usam `_yaw`, não `q.dir`).
	#
	# Com o corpo seguindo o movimento, o adversário lia a direção ERRADA: via as
	# costas de quem ia acertá-lo de lado. Agora corpo e golpe apontam junto.
	#
	# ⚠️ UMA EXCEÇÃO, e ela não é negociável: ESCALANDO. A frente vira para
	# DENTRO da parede porque é isso que faz a escalada ler — um personagem
	# grudado numa parede de costas para ela seria pior que o problema original.
	# Aqui a mira não manda porque o corpo está preso à geometria.
	if _char_model:
		if _parkour.na_parede() and _parkour.normal_da_parede() != Vector3.ZERO:
			# ⚠️ O "PARA CIMA" DO CORPO VIRA A NORMAL DA SUPERFÍCIE. É isso que
			# faz o jogador ANDAR na parede em vez de escalá-la — a orientação do
			# que é o chão muda, que foi o pedido.
			#
			# A frente sai da direção do movimento projetada no plano; parado,
			# mantém a que já tinha, para o corpo não girar sozinho.
			var n := _parkour.normal_da_parede()
			# ⚠️ A FRENTE VEM DA MESMA BASE QUE O MOVIMENTO. Antes ela era `q.dir`
			# — a direção HORIZONTAL do mundo — projetada no plano da parede. Numa
			# parede vertical o W é justamente a componente que a projeção anula,
			# então só A e D sobravam: o corpo ficava sempre virado para a
			# direita ou para a esquerda, nunca para onde ele estava subindo.
			#
			# Movimento e olhar são a MESMA decisão; tirá-los de fontes
			# diferentes é como as cinco cópias da direção da frente que já
			# custaram caro aqui.
			var b_sup := _parkour.base_da_superficie()
			var frente_alvo := _char_model.global_transform.basis.z * -1.0
			if absf(q.f) > 0.01 or absf(q.r) > 0.01:
				frente_alvo = (-b_sup.z) * q.f + b_sup.x * q.r
			frente_alvo = frente_alvo - n * frente_alvo.dot(n)
			# ⚠️ QUANDO A PROJEÇÃO DEGENERA. Ao grudar, o corpo está ENCARANDO a
			# parede — a frente dele é anti-paralela à normal, e projetá-la no
			# plano da superfície dá ZERO. Sem esta saída o `if` abaixo falhava e
			# a orientação nunca mudava: o personagem grudava na parede em pé,
			# como se nada tivesse acontecido.
			#
			# A saída é "para cima da parede": a vertical do MUNDO projetada no
			# plano. Numa parede vertical isso aponta para o topo dela, que é a
			# direção que alguém andando nela naturalmente encara.
			if frente_alvo.length_squared() <= 0.001:
				frente_alvo = Vector3.UP - n * Vector3.UP.dot(n)
			if frente_alvo.length_squared() <= 0.001:
				frente_alvo = Vector3.FORWARD - n * Vector3.FORWARD.dot(n)
			if frente_alvo.length_squared() > 0.001:
				var alvo := Basis.looking_at(frente_alvo.normalized(), n)
				_girar_modelo(alvo, delta)
		elif _endireitando():
			# ⚠️ DESENTORTAR AO SAIR DA SUPERFÍCIE. Largar a parede não bastava:
			# o resto do código escreve só `rotation.y`, e escrever yaw numa base
			# INCLINADA preserva a inclinação — o personagem saía andando de lado
			# no ar para sempre. Aqui a base volta inteira para "em pé olhando
			# para a mira", e só então os escritores de yaw voltam a mandar.
			_girar_modelo(Basis.from_euler(Vector3(0.0, _char_model.rotation.y, 0.0)), delta)
		elif _parkour.escalando() and _parkour.parede_frontal() != Vector3.ZERO:
			# Convenção do projeto: FRENTE = -Z. Ao escalar, o -Z do modelo aponta
			# ao longo de -wall_normal (que aponta da parede para o jogador).
			var target_rot := atan2(_parkour.parede_frontal().x, _parkour.parede_frontal().z)
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, target_rot,
				VELOCIDADE_FACING * delta)
		elif not _contextual_attack_id.is_empty():
			# W/A/S/D fixa a direção no clique. A câmera ainda gira para mirar o
			# próximo golpe, mas não altera a silhueta do corpo comprometido.
			_char_model.rotation.y = _contextual_attack_yaw
		else:
			_char_model.rotation.y = lerp_angle(_char_model.rotation.y, _yaw,
				VELOCIDADE_FACING * delta)

	# A mira normalmente reescreve a orientação do modelo a cada quadro. Na aú,
	# isso mudaria o eixo da rotação no meio do movimento: captura-se o yaw no
	# clique e a estrelinha inteira segue a visão daquele instante.
	if _char_model and _spin_kick_active:
		_spin_kick_angle = fmod(_spin_kick_angle + TAU * delta / 0.42, TAU)
		var angulo_au := -_spin_kick_angle
		# A aú começa DE LADO para a câmera. Com o corpo 90° à direita, o eixo
		# lateral local (X) aponta para a frente da visão capturada, e a roda
		# atravessa o rumo do jogador em vez de fazê-lo cambalhotar para o lado.
		_char_model.rotation.y = _spin_kick_yaw + PI * 0.5
		_char_model.rotation.z = angulo_au
		_char_model.position.x = _spin_kick_rest_position.x + ALTURA_DO_ROLAMENTO * sin(angulo_au)
		_char_model.position.y = _spin_kick_rest_position.y + ALTURA_DO_ROLAMENTO * (1.0 - cos(angulo_au))

	# ⚠️ O GIRO DO ROLAMENTO DE COSTAS mora aqui, e não no animador, porque quem
	# tem a raiz do modelo é o Player. A pose encolhida sozinha pareceria um
	# agachamento; é o giro que faz virar cambalhota.
	#
	# Gira em X (para TRÁS = negativo, pela convenção frente = −Z) uma volta
	# inteira ao longo da esquiva. E compensa a POSIÇÃO: a origem do modelo está
	# nos PÉS, então girar ali jogaria o corpo através do chão. Deslocando por
	# `meia_altura·(1−cos)` em Y e `meia_altura·sin` em Z, o giro acontece em
	# torno da CINTURA, que é onde uma cambalhota gira de verdade.
	if _char_model:
		# A cambalhota de saída da superfície gira pelo MESMO mecanismo do
		# rolamento de costas — inclusive a compensação de posição, que é o que
		# faz girar em torno da cintura e não dos pés.
		var g := _dash.giro_do_rolamento() if _dash.ativo() and _dash.rumo_nome() == "tras" else 0.0
		if g <= 0.0 and _parkour.rolando_no_ar():
			g = _parkour.giro_do_rolamento_no_ar()
		if g > 0.0:
			# ⚠️ GUARDA O REPOUSO NO PRIMEIRO QUADRO DO GIRO, e soma o arco A
			# PARTIR dele. A primeira versão devolvia a posição para ZERO no fim —
			# mas o repouso do modelo NÃO é zero: é `y = −0,80` (o rig o abaixa
			# para os pés encostarem no chão). Resultado medido: o personagem
			# SUBIA 0,8 m no primeiro dash de costas e ficava lá.
			#
			# Assumir "o repouso é a origem" é o mesmo erro que a escala das
			# raças, onde devolver `Vector3.ONE` deformaria um rig que nasce com
			# 1,8. Repouso se GUARDA, não se supõe.
			if not _rolando_de_costas:
				_rolando_de_costas = true
				_pose_repouso = _char_model.position
			var ang := -TAU * g
			_char_model.rotation.x = ang
			_char_model.position.y = _pose_repouso.y + ALTURA_DO_ROLAMENTO * (1.0 - cos(ang))
			_char_model.position.z = _pose_repouso.z + ALTURA_DO_ROLAMENTO * sin(ang)
		elif _rolando_de_costas:
			# Volta ao REPOUSO GUARDADO assim que a esquiva acaba. Sem isto o
			# personagem ficaria de cabeça para baixo para sempre — `rotation.x`
			# não é escrito por mais ninguém, então ninguém o consertaria.
			_rolando_de_costas = false
			_char_model.rotation.x = 0.0
			_char_model.position.y = _pose_repouso.y
			_char_model.position.z = _pose_repouso.z

	# Animação: rig procedural (por-nós) OU esqueletal (skinnado).
	if _skel_anim:
		_skel_anim.update(velocity, is_on_floor(), _parkour.escalando(), delta, q.sprint)
	elif _proc_anim:
		var parkour := ""
		if _parkour.rolando_no_ar():
			# ⚠️ ANTES do wall_run e do roll: a cambalhota de saída é o estado
			# mais recente e tem de vencer o que estava tocando.
			parkour = "roll_ar"
		elif _parkour.correndo_na_parede():
			parkour = "wall_run"
		elif _roll_t > 0.0:
			# ⚠️ A pose depende do RUMO da esquiva. O dash já saía para os lados e
			# para trás (a direção vem da tecla), mas todos usavam a MESMA
			# animação: dar um passo para trás e mergulhar para a frente ficavam
			# iguais na tela. O rolamento de pouso, que não é dash, continua no
			# "roll" de frente.
			if _dash.ativo():
				match _dash.rumo_nome():
					"tras":     parkour = "roll_tras"
					"esquerda": parkour = "roll_lado_e"
					"direita":  parkour = "roll_lado_d"
					_:          parkour = "roll"
			else:
				parkour = "roll"
		elif _parkour.janela_impulso() > 0.0 and not on_floor_now:
			parkour = "long_jump"
		# ⚠️ NA SUPERFÍCIE, O ANIMADOR PRECISA ACHAR QUE ESTÁ NO CHÃO. Ele decide
		# entre ciclo de caminhada e pose de ar por `on_floor` — e andando na
		# parede o jogador NÃO está no chão do mundo, então tocava a pose de
		# queda e parecia que não havia animação nenhuma. Para o animador, a
		# superfície É o chão.
		#
		# E a velocidade vai SEM a componente de aderência: aquele empurrão
		# contra a parede é contato, não deslocamento, e faria o ciclo de
		# caminhada rodar com o jogador parado.
		var no_chao_anim: bool = is_on_floor() or _parkour.na_parede()
		var vel_anim: Vector3 = velocity
		if _parkour.na_parede():
			# ⚠️ TRADUZIR A VELOCIDADE PARA O PLANO QUE O ANIMADOR ENTENDE.
			# Ele mede a caminhada com `Vector2(velocity.x, velocity.z)` — só o
			# plano horizontal do MUNDO. Subir a parede é movimento em Y, que
			# ele não enxerga: andar para cima e para baixo não animava nada,
			# enquanto andar de lado animava.
			#
			# A saída é decompor a velocidade na base da SUPERFÍCIE (quanto é
			# "para frente", quanto é "para o lado") e reemitir isso na base
			# horizontal do corpo. O animador recebe uma caminhada com a
			# magnitude e a repartição certas, sem saber que há uma parede.
			var n_sup := _parkour.normal_da_parede()
			var no_plano := velocity - n_sup * velocity.dot(n_sup)
			var b_sup := _parkour.base_da_superficie()
			var v_frente: float = no_plano.dot(-b_sup.z)
			var v_lado: float = no_plano.dot(b_sup.x)
			vel_anim = RosaDosVentos.frente(_yaw) * v_frente \
				+ RosaDosVentos.direita(_yaw) * v_lado
		_proc_anim.update(vel_anim, no_chao_anim, _parkour.escalando(), delta, _pitch, q.sprint, false, "", parkour, _pose_de_arma(), _gun_recoil)

# Fôlego, rajada Z e a janela do combo de corpo a corpo.
func _etapa_ticks_de_combate(delta: float) -> void:
	_update_breath()
	_disparo.tick_rajada(delta, ENERGY_BULLET)   # Mera Z: dispara as balas de fogo enquanto a rajada está ativa
	_melee.tick(delta, _yaw)  # corpo a corpo: janela do combo + recuperação

# A autoridade publica seu estado para os outros clientes replicarem.
func _etapa_publicar_rede() -> void:

	# Rede (Fase 4): a autoridade publica seu estado p/ os outros clientes replicarem.
	net_velocity = velocity
	net_on_floor = is_on_floor()
	# A cópia local acabou a carga; limpa o estado visual que foi replicado no
	# caminho de trava. O golpe final continua viajando pelo RPC de cast normal.
	net_charge_pose = ""
	net_charge_progress = 0.0
	if _char_model:
		net_facing = _char_model.rotation.y

# Supressão de poderes e morte por queda. Devolve `true` se o quadro acabou aqui.
func _etapa_vida(delta: float) -> bool:

	# Processamento de Supressão da Passiva Yami Yami
	_cast.tick_silencio(delta)

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
	# É AQUI que o diagrama da arquitetura acontece: a locomoção já escreveu
	# `velocity`, e agora o empurrão — que é de OUTRO dono — é somado por cima.
	#
	# O `if` não é otimização: somar `Vector3.ZERO` normaliza −0,0 para +0,0, e o
	# traço de 492 quadros acusou exatamente isso (posições idênticas, sinal do
	# zero diferente). Sem empurrão, não se toca na velocidade — como antes.
	var empurrao := _vida.impulso_do_quadro(delta)
	if empurrao != Vector3.ZERO:
		velocity += empurrao
	var velocidade_y_antes_do_pouso := velocity.y
	move_and_slide()
	if _air_slam_active and is_on_floor():
		_finalizar_ataque_aereo()
	_impacto_de_queda.atualizar(self, is_on_floor(), velocidade_y_antes_do_pouso)
	_ecos_de_movimento.atualizar(delta, _char_model, _is_sprinting() and is_on_floor())
	_poeira_dos_pes.atualizar(delta, velocity, is_on_floor(),
		_dash.ativo() or _parkour.escalando() or _parkour.correndo_na_parede() or _charging or _rapid_fire)
	
	if _fsm and _fsm.state and _fsm.state.name == "Stunned":
		if is_on_wall() and empurrao.length_squared() > 4.0:
			var col = get_slide_collision(0)
			if col:
				var normal = col.get_normal()
				var bounce_vel = empurrao.bounce(normal) * 0.8 # Conserva 80% do momento
				_vida._empurrao = bounce_vel
				print("💥 Wall Bounce! Momentum: ", bounce_vel)

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
	# O servidor também costuma ver jogadores de clientes por este caminho;
	# portanto o relógio autoritativo do Corpo de Ferro não pode depender da
	# autoridade local.
	_corpo_de_ferro.atualizar(delta)
	# No servidor, os corpos dos clientes passam por este caminho. A trava da
	# fruta também precisa andar aqui, senão o servidor recusaria casts deles
	# para sempre depois do primeiro dano.
	if _fruit_damage_lock_timer > 0.0:
		_fruit_damage_lock_timer = maxf(_fruit_damage_lock_timer - delta, 0.0)
	velocity = net_velocity
	_buki_apontar_canhao()   # canhão-corpo da Buki acompanha o facing replicado
	if _char_model:
		_char_model.rotation.y = lerp_angle(_char_model.rotation.y, net_facing, 18.0 * delta)
	if _skel_anim:
		_skel_anim.update(net_velocity, net_on_floor, false, delta, false)
	elif _proc_anim:
		var charge_x := net_charge_progress if net_charge_pose == "mera_x_charge" else 0.0
		_proc_anim.update(net_velocity, net_on_floor, false, delta, _pitch, false,
			net_charge_pose != "", "", "", false, 0.0, 0.0, -1, charge_x, net_charge_pose)
	_poeira_dos_pes.atualizar(delta, net_velocity, net_on_floor, false)
	_impacto_de_queda.atualizar(self, net_on_floor, net_velocity.y)
	_ecos_de_movimento.atualizar(delta, _char_model, net_on_floor and Vector2(net_velocity.x, net_velocity.z).length() > SPEED * 1.35)

# Corpo de Ferro (F): o pedido do cliente nunca escreve imunidade diretamente.
# O servidor valida dono + recarga e só então replica o efeito de um segundo.
func _pedir_corpo_de_ferro() -> void:
	_resetar_impulso_de_corrida()
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_corpo_de_ferro()
	else:
		_net_corpo_de_ferro_req.rpc_id(1)

@rpc("any_peer", "reliable")
func _net_corpo_de_ferro_req() -> void:
	if not multiplayer.is_server():
		return
	var remetente := multiplayer.get_remote_sender_id()
	if remetente != 0 and remetente != get_multiplayer_authority():
		return
	_do_server_corpo_de_ferro()

func _do_server_corpo_de_ferro() -> void:
	if not _corpo_de_ferro.pronto():
		return
	if multiplayer.has_multiplayer_peer():
		_net_play_corpo_de_ferro.rpc()
	else:
		_net_play_corpo_de_ferro()

@rpc("any_peer", "call_local", "reliable")
func _net_play_corpo_de_ferro() -> void:
	if multiplayer.has_multiplayer_peer():
		var remetente := multiplayer.get_remote_sender_id()
		if remetente != 0 and remetente != 1:
			return
	_corpo_de_ferro.ativar_confirmado()
	print("🛡️ Corpo de Ferro: imune por 1 s. Recarga: 30 s.")

func limpar_silencio_de_corpo_de_ferro() -> void:
	_cast.limpar_silencio()

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
# ============================================================================
#  COR DO JOGADOR — identificação visual em partida online.
# ============================================================================
#
#  ⚠️ A COR VEM DO DADO DE SPAWN, e isso é a parte que importa. Ela poderia ser
#  sorteada aqui, ou derivada de `hash(peer_id)` — e as duas dariam cores
#  DIFERENTES EM CADA MÁQUINA, porque cada peer sortearia por conta própria.
#  Quem manda é o servidor: ele escolhe o índice em `Main._spawn_player_for`, e o
#  `MultiplayerSpawner` replica o dicionário de spawn inteiro. Todo mundo monta o
#  mesmo corpo com a mesma cor, sem RPC novo e sem propriedade replicada a mais.
## A lista mora em `src/customizacao/Paleta.gd` — dado puro, sem dependência de
## autoload. Aqui fica só o apelido, para os usos existentes não mudarem.
## Ver o cabeçalho do `Paleta.gd` para o porquê da mudança.
const CORES := Paleta.CORES

## Índice em `CORES`. −1 = sem cor atribuída (singleplayer, testes) — aí o
## personagem fica com a aparência original.
var cor_idx: int = -1

## O colisor e o tamanho de referência dele. Guardados porque o Gigante os
## redimensiona — ver `_aplicar_escala_de_raca`.
const COLISOR_BASE := Vector3(1.0, 1.6, 1.0)
var _colisor: CollisionShape3D = null
var _escala_base_do_modelo: Vector3 = Vector3.ONE

func nome_da_cor() -> String:
	return str(CORES[cor_idx]["nome"]) if cor_idx >= 0 and cor_idx < CORES.size() else "original"

## Chamada pelo `Main` no spawn. Guarda e pinta.
func aplicar_cor_do_jogador(idx: int) -> void:
	cor_idx = idx
	_tingir_modelo()

## Pinta o corpo. Precisa rodar DE NOVO a cada troca de personagem: `_rig.montar`
## constrói um modelo novo e o anterior (com a tinta) é descartado.
##
## ⚠️ Usa `material_override`, o mesmo caminho do `AutoDummy._recolor_model` —
## é o precedente do projeto para "este corpo é daquele time". Como ele cobre
## TODAS as malhas do modelo, uma arma da Buki que já esteja na mão no momento da
## pintura também é tingida; ela volta ao normal no próximo saque, que reconstrói
## o visual. Não vale complicar por isso enquanto for só cosmético.
## O TAMANHO DA RAÇA (Gigante). Decisão do dono, 2026-08-29: o gigante não é só
## um boneco maior — cresce a CÁPSULA e a CÂMERA junto.
##
## ⚠️ OS TRÊS OU NENHUM. Só o modelo cresceria e o gigante passaria por vãos em
## que visualmente não cabe, e levaria dano no ar em volta do corpo; só a
## cápsula e ele empacaria em porta nenhuma sem motivo visível. A câmera entra
## porque a altura do pivô é fixa em metros: sem ajustar, o gigante enxerga a
## partir do próprio peito.
func _aplicar_escala_de_raca() -> void:
	var e := Racas.escala_de(Visual.raca)
	if _char_model != null and is_instance_valid(_char_model):
		_char_model.scale = _escala_base_do_modelo * e
	if _colisor != null and is_instance_valid(_colisor):
		var forma := _colisor.shape as BoxShape3D
		if forma != null:
			forma.size = COLISOR_BASE * e
		# A cápsula cresce a partir do centro, então o corpo afundaria meio
		# tamanho no chão sem subir o colisor junto.
		_colisor.position.y = (COLISOR_BASE.y * (e - 1.0)) * 0.5
	if _camera != null and is_instance_valid(_camera):
		_camera.definir_escala(e)


func _tingir_modelo() -> void:
	if cor_idx < 0 or cor_idx >= CORES.size():
		return
	var modelo := _char_model
	if modelo == null or not is_instance_valid(modelo):
		return

	# ⚠️ A ESCOLHA DO JOGADOR VENCE A COR DE TIME QUANDO NÃO HÁ TIME (2026-08-29).
	#
	# Relato do dono: "ao logar a cor se torna automaticamente azul". No spawn o
	# `Main` dá a cada peer uma cor da paleta, e o peer 1 — o único que existe no
	# singleplayer — recebe a PRIMEIRA, que é azul. Sozinho no mundo não há quem
	# distinguir, então a cor de time não está resolvendo nada e só apaga o que
	# o jogador escolheu na Customização.
	#
	# Em partida com gente, a cor de time continua mandando: é ela que diz quem
	# é quem, e isso vale mais do que a preferência estética de cada um.
	if Visual.cor_do_corpo().a > 0.0 \
			and not (multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0):
		return

	var c: Color = CORES[cor_idx]["cor"]
	var malhas: Array = []
	FxUtil._collect_meshes(modelo, malhas)
	for m in malhas:
		if not (m is MeshInstance3D):
			continue
		# ⚠️ A COR DE TIME É DO CORPO, NÃO DO GUARDA-ROUPA. Sem esta linha o
		# `material_override` cobria TAMBÉM chapéu, cabelo e máscara — e como
		# ele vence o override de superfície com que os acessórios são pintados,
		# a cor original deles continuava lá embaixo, intacta e invisível. Era a
		# outra metade do relato: "a cor do acessório também fica azul".
		#
		# O código já sabia disso e tinha deixado passar: a nota acima dizia que
		# uma arma da Buki na mão saía tingida junto, e que "não vale complicar
		# enquanto for só cosmético". Com a Customização ligada ao mundo, passou
		# a valer — o jogador escolhe o cabelo e recebe outro.
		if Visual.e_adorno(m):
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		# Preto puro some contra a sombra; um mínimo de brilho próprio mantém a
		# silhueta legível sem clarear a cor.
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 0.35
		(m as MeshInstance3D).material_override = mat

func _setup_character_model(cid: String) -> void:
	# ⚠️ SAÍDA POR TROCA DE PERSONAGEM. `_rig.montar` constrói um modelo NOVO: as
	# malhas pintadas e o nó do chapéu vão embora com o antigo. Desligar antes
	# evita o chapéu órfão e faz o `_gear2` reapontar para o rig novo.
	if _gear2:
		_gear2.desativar()
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

	# O rig acabou de ser reconstruído: a tinta do modelo anterior foi embora com
	# ele. Repintar aqui é o que faz a cor sobreviver à troca de personagem.
	_tingir_modelo()

	# ⚠️ A CUSTOMIZAÇÃO ENTRA NO MUNDO AQUI (2026-08-29).
	#
	# Até agora o menu de Customização era um efeito colateral da tela: o
	# jogador montava o personagem, entrava na partida e jogava com o boneco
	# padrão. `Visual.aplicar` é a MESMA função que monta a prévia — é isso que
	# faz o que ele viu no menu ser o que ele recebe no jogo, em vez de dois
	# caminhos que podem divergir.
	#
	# DEPOIS do `_tingir_modelo`, e com `preservar_cor_do_jogo`: a cor de time
	# pinta TODAS as malhas, então rodar antes deixaria chapéu e cabelo da cor
	# do time; e sem o preservar, um jogador sem cor escolhida teria a tinta do
	# time apagada.
	#
	# Roda a cada remontagem do rig (troca de personagem, Gear 2) porque o
	# modelo novo nasce limpo — a peça equipada morreu com o modelo anterior.
	Visual.carregar_uma_vez()
	# A escala do rig recém-montado, ANTES de a raça mexer nela: é sobre esta
	# que o Gigante multiplica. Ler depois pegaria a escala já multiplicada e
	# cada remontagem deixaria o personagem maior que a anterior.
	_escala_base_do_modelo = _char_model.scale
	Visual.aplicar(_char_model, true)
	_aplicar_escala_de_raca()

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
	var pode_ver_corpo := (_camera == null or not _camera.em_primeira_pessoa()) and _buki_visual != "X"
	_char_model.visible = pode_ver_corpo and (not _invisivel or _is_authority)
	_aplicar_transparencia_invisivel()

func iniciar_invisibilidade() -> void:
	# Z é alternável: a segunda pressão encerra a camuflagem voluntariamente.
	if _invisivel:
		revelar_invisibilidade()
		return
	if energy <= 0.0 or current_fruit_id != "suke_suke": return
	if multiplayer.has_multiplayer_peer():
		_pedir_invisibilidade.rpc_id(NetworkConfig.SERVER_ID)
	else:
		_aplicar_invisibilidade(true)

func revelar_invisibilidade() -> void:
	if not _invisivel: return
	if multiplayer.has_multiplayer_peer():
		_pedir_revelar_invisibilidade.rpc_id(NetworkConfig.SERVER_ID)
	else:
		_aplicar_invisibilidade(false)

@rpc("any_peer", "call_local", "reliable")
func _pedir_invisibilidade() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
	var remetente := multiplayer.get_remote_sender_id()
	if multiplayer.has_multiplayer_peer() and remetente != 0 and remetente != get_multiplayer_authority(): return
	_definir_invisibilidade.rpc(true)

@rpc("any_peer", "call_local", "reliable")
func _pedir_revelar_invisibilidade() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
	var remetente := multiplayer.get_remote_sender_id()
	if multiplayer.has_multiplayer_peer() and remetente != 0 and remetente != get_multiplayer_authority(): return
	_definir_invisibilidade.rpc(false)

@rpc("authority", "call_local", "reliable")
func _definir_invisibilidade(ativa: bool) -> void:
	_aplicar_invisibilidade(ativa)

func _aplicar_invisibilidade(ativa: bool) -> void:
	if _invisivel == ativa: return
	_invisivel = ativa
	if not ativa:
		trigger_skill_cooldown("Z") # os 10 s começam SOMENTE ao revelar
	_atualizar_visibilidade_corpo()

func _aplicar_transparencia_invisivel() -> void:
	if _char_model == null or not _is_authority: return
	for m in _char_model.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if mesh == null: continue
		if _invisivel:
			if not _materiais_antes_da_invisibilidade.has(mesh):
				_materiais_antes_da_invisibilidade[mesh] = mesh.material_override
			var mat := StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.70, 0.88, 1.0, 0.28)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.material_override = mat
		elif _materiais_antes_da_invisibilidade.has(mesh):
			mesh.material_override = _materiais_antes_da_invisibilidade[mesh]
	if not _invisivel:
		_materiais_antes_da_invisibilidade.clear()

# ---------------------------------------------------------------- combate ---
func _registrar_trava_de_fruta_por_dano(amount: float) -> void:
	if amount > 0.0:
		_fruit_damage_lock_timer = TRAVA_FRUTA_APOS_DANO

func fruta_bloqueada_por_dano() -> bool:
	return combat_mode == "fruit" and _fruit_damage_lock_timer > 0.0

## ⚠️ A JANELA QUE O COUNTER HIT PUNE. `true` do clique até a hitbox nascer —
## quando o corpo já está comprometido com um golpe e ainda não tem como acertar.
## Serve para o CONTEXTUAL e para o M1, porque `MeleeController.fase()` já
## responde pelos dois com o mesmo relógio.
##
## É consultado pelo SERVIDOR, no instante do impacto e antes de o dano correr —
## depois do dano o golpe do alvo já foi interrompido e a resposta seria sempre
## falsa (ver `DamageZone.antes_do_acerto`).
func em_startup_de_ataque() -> bool:
	return _melee != null and _melee.fase() == "startup"


func take_damage(amount: float, attacker_pos: Vector3 = Vector3.ZERO, base_knockback: Vector3 = Vector3.ZERO, hitstun_duration: float = 0.3) -> void:
	if _invisivel:
		revelar_invisibilidade()
	# `in_black_hole` entrou aqui em 2026-08-11: o Black Hole da Yami é CONTROLE
	# PURO — puxa, afunda e silencia, e quem mata é o buraco do mapa depois.
	# `TrainingDummy.gd:64` e `disabled/enemies/Enemy.gd` já recusavam dano de
	# quem está preso; só o jogador não recusava, e a mesma habilidade tinha
	# regra diferente dependendo de quem caía nela.
	# ⚠️ `iron_body_active` SAIU DESTA LISTA em 2026-08-31. Era aqui que a
	# invulnerabilidade total do Corpo de Ferro morava — a função retornava e o
	# golpe sumia inteiro. O dono pediu que a janela passasse a "cortar os danos
	# pela metade", e meia imunidade não cabe numa guarda que só sabe dizer
	# "sim ou não": o corte agora acontece logo abaixo, sobre o `amount`.
	if get_meta("damage_immune", false) or get_meta("custom_pose", "") == "hibashira" or get_meta("in_black_hole", false):
		print("🛡️ DANO E KNOCKBACK BLOQUEADOS! O usuário está IMUNE a danos durante a habilidade!")
		return
	_registrar_trava_de_fruta_por_dano(amount)
	_resetar_impulso_de_corrida()

	# ⚠️ CORPO DE FERRO CORTA O DANO PELA METADE (2026-08-31). Antes a janela dava
	# invulnerabilidade e o golpe sumia inteiro; agora ele chega, valendo metade.
	#
	# O corte é AQUI, no começo do funil, e não só na subtração da vida: o
	# `amount` segue para o feedback (número que sobe na tela) e para o RPC que
	# leva a vida ao dono. Cortar mais adiante mostraria ao jogador um número que
	# não foi o que ele tomou.
	if get_meta("iron_body_active", false):
		amount *= IronBodyController.FATOR_DE_DANO

	# 1. INTERRUPÇÃO DE ATAQUE SOBRE DANO
	#
	# ⚠️ O Charge-up é a EXCEÇÃO: nele o dano LIBERA o golpe com a carga que
	# houver, em vez de cancelar. Por isso ele vem ANTES do
	# `interrupt_casting`, que cancelaria. Decisão do dono — ver
	# docs/PEDIDO_2026-08-12.md.
	_cast.liberar_por_dano()
	SkillSystem.interrupt_casting(self)

	if _animator:
		_animator.trigger_damage()
	elif _skel_anim:
		_skel_anim.play_one_shot("damage")

	var morreu := _vida.sofrer_dano(amount)
	_feedback_de_dano(amount, hitstun_duration)

	# ⚠️ A VIDA É DO SERVIDOR — e ela precisa ATRAVESSAR a rede.
	#
	# A `DamageZone` roda no servidor, então este `take_damage` roda na cópia que
	# o servidor tem da vítima. Sem avisar o dono, cada lado fica com uma vida
	# própria e elas nunca se falam: medido em 2026-08-12, a vítima morria com a
	# BARRA CHEIA na tela dela — sem flash, sem som e sem número de dano.
	#
	# Por que RPC e não `MultiplayerSynchronizer`: o synchronizer replica DA
	# AUTORIDADE para os outros, e a autoridade do corpo é o CLIENTE. Pôr `health`
	# lá deixaria a vida nas mãos dele — cliente adulterado ficaria imortal, e o
	# dano que o servidor aplica seria sobrescrito no quadro seguinte.
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		net_vida_do_servidor.rpc(_vida.vida, amount)

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
		
	var hitstop_dur := clampf(amount * 0.003 + 0.06, 0.06, 0.16)
	_hitstop_timer = hitstop_dur
	velocity = Vector3.ZERO # Impact Frame Hold


	if morreu:
		die_and_respawn()

# Pisca vermelho, som de recepção e número flutuante. Roda em QUALQUER cópia que
# souber do dano — é o que faz o adversário te ver apanhar.
func _feedback_de_dano(amount: float, hitstun_duration: float = 0.3) -> void:
	FxUtil.flash_red(_char_model)
	FxUtil.bleed(get_tree().current_scene, global_position + Vector3.UP * 1.2, int(maxf(4, amount / 5.0)))
	AudioFX.hurt(get_tree().current_scene, global_position + Vector3.UP * 1.0)
	# ANIMAÇÃO DE RECEPÇÃO DE DANO (pedido do dono, 2026-08-14):
	# "vai ocorrer sempre que o jogador receber dano".
	# Fica AQUI, e não no `take_damage`, de propósito: este é o funil por onde
	# passa todo dano visível em QUALQUER cópia — o do servidor e o que chega por
	# `net_vida_do_servidor`. Pendurar no `take_damage` faria o adversário não ver
	# você apanhar, que é exatamente o bug do item 20.
	var dur_knockdown := get_meta("knockdown_dur", 0.0) as float
	if dur_knockdown > 0.0:
		RecepcaoDeDano.derrubar_com_animacao(self, dur_knockdown)
		remove_meta("knockdown_dur")
	else:
		RecepcaoDeDano.aplicar(self, hitstun_duration)
	# ⚠️ SÓ NA AUTORIDADE — e isto NÃO é otimização, é o bug B2 do §2.4 do plano.
	#
	# `_feedback_de_dano` roda em TODA cópia que sabe do dano (é o que faz o
	# adversário te ver apanhar, item 20). Mas quem TIRA do "Stunned" é o
	# `RecepcaoDeDano.tick` lá em cima, e ele fica ATRÁS do
	# `if not _is_authority: return`. Numa cópia remota o estado entraria e não
	# sairia nunca: stun eterno, visível só para os outros jogadores.
	#
	# Até 2026-08-25 isso era inofensivo por acidente — não existia nó "Stunned"
	# e a transição era um no-op calado. Criar o estado ACORDA o defeito, então
	# ele é fechado no mesmo movimento.
	#
	# Não custa nada visualmente: o tranco em tela é a pose do
	# `RecepcaoDeDano`, aplicada logo acima em todas as cópias. A FSM da cópia
	# remota não governa movimento nenhum (quem governa é `_remote_process`).
	#
	# ESCOPO: isto fecha a metade do B2 que esta frente acordou. A outra metade
	# — a corrida entre a escrita do estado e o reset — continua sendo trabalho
	# da frente de REDE (§7, Ordem 1, B1-B6).
	if _fsm and _is_authority:
		_fsm.transition_to("Stunned")
	FxUtil.damage_number(get_tree().current_scene, global_position + Vector3.UP * 1.7, amount, Color(1.0, 0.75, 0.2))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("on_player_damaged"):
		hud.on_player_damaged(amount, health, max_health)
	print("💥 Dano Recebido: ", amount, " | HP Restante: ", health, "/", max_health)

# O SERVIDOR manda a vida nova para todos. `call_remote` de propósito: quem
# emitiu (o servidor) já aplicou e já deu o feedback — repetir aqui piscaria e
# tocaria som duas vezes na tela dele.
#
# `dano > 0` = foi pancada, então dá feedback. `dano = 0` = foi restauração
# (respawn), e aí só o número muda.
@rpc("any_peer", "call_remote", "reliable")
func net_vida_do_servidor(nova_vida: float, dano: float) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return                      # só o servidor manda na vida
	_vida.vida = nova_vida
	if dano > 0.0:
		_registrar_trava_de_fruta_por_dano(dano)
		_feedback_de_dano(dano)
		_cast.liberar_por_dano()
		SkillSystem.interrupt_casting(self) # Usa o hitstun padrão na cópia remota (ou poderíamos enviar pelo RPC também)

# O SERVIDOR premia quem matou: 30 s de regeneração acelerada.
#
# É `@rpc` porque a regeneração só roda na AUTORIDADE — premiar a cópia do
# servidor não teria efeito nenhum sobre a vida que o jogador vê.
@rpc("any_peer", "call_local", "reliable")
func premiar_kill() -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return                       # só o servidor decide quem matou
	_vida.premiar_kill()

# RESTAURA a vida na cópia AUTORITATIVA e avisa todo mundo.
#
# ⚠️ Isto existe porque o `net_force_respawn` é mandado com `rpc_id(peer)` — só o
# DONO executa. A cópia do servidor, que é justamente a que a `DamageZone`
# machuca, ficava em 0 PARA SEMPRE: medido, 96,6 s depois do respawn o hp
# autoritativo ainda era 0,0 de 2048. Efeito em jogo: depois da primeira morte,
# qualquer acerto matava o cliente na hora, pelo resto da rodada.
func restaurar_vida_no_servidor() -> void:
	_vida.restaurar()
	RecepcaoDeDano.limpar(self)
	# ⚠️ A recarga da Buki tem DOIS relógios: `_skill_cooldowns` no dono (zerado
	# no `net_force_respawn`) e `_srv_recarga_ate` na cópia do servidor. Zerar só
	# um deixaria o jogador vendo o slot livre e o servidor recusando em
	# silêncio — o sintoma "apertei e não aconteceu nada".
	_buki.esquecer_recargas_do_servidor()
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		net_vida_do_servidor.rpc(_vida.vida, 0.0)

# Pedido do servidor para o DONO do corpo se empurrar. Só o servidor manda.
@rpc("any_peer", "call_local", "reliable")
func net_apply_knockback(base_knockback: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	_aplicar_knockback(base_knockback)

# Aplica o empurrão. As REGRAS (dobrar no ar, resistir andando contra) e o
# número moram no `HealthController`; aqui só se entrega o contexto que é do
# Player — chão e mira — e se soma o componente VERTICAL, que a locomoção não
# reatribui.
func _aplicar_knockback(base_knockback: Vector3) -> void:
	velocity.y += _vida.empurrar(base_knockback, is_on_floor(), _yaw)


# Porta de entrada da MORTE — chegam aqui os dois caminhos: vida zerada (a
# DamageZone, no servidor) e queda no vazio (SkillSystem.process_void_check).
#
# Quem decide é sempre o PLACAR, no servidor: ele conta a morte, resolve de quem
# é a kill e manda o dono do corpo respawnar. Num cliente puro esta função não
# faz nada de propósito — o servidor enxerga a queda pela `position` replicada e
# declara a morte de lá. Sem placar na árvore (testes isolados), respawna direto.
func die_and_respawn() -> void:
	# ⚠️ SAÍDA POR MORTE. Sem isto o corpo renasce com a pele do Gear 2 e o
	# chapéu, sem o estado — e a transformação viraria permanente pela porta dos
	# fundos. É um dos quatro caminhos de saída listados no `gear2_controller`.
	if _gear2:
		_gear2.desativar()
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
		limpar_skills_em_todos()
		FruitNet.respawn(current_fruit_id)
		current_fruit_id = ""
		speed_multiplier = 1.0
		jump_multiplier = 1.0

	# Morreu de arma na mão: ela some (em todos os peers — este RPC é call_local)
	# e o slot entra em recarga como em qualquer outro abandono.
	_buki_guardar()
	_buki_mostrar_arma("")

	# ⚠️ MORRER TEM QUE ABORTAR O CAST — sem isso o jogo trava DE VERDADE.
	#
	# Relatado jogando em 2026-08-12 e reproduzido aqui: quem morre **segurando**
	# a tecla de uma skill fica com `_charging = true` e `is_casting = true` para
	# sempre. Duas consequências, as duas permanentes:
	#
	#   • `_slot_em_uso()` passa a devolver aquele slot eternamente, e o laço de
	#     recarga CONGELA todos os outros ("o contador trava e nunca recarrega");
	#   • `CastController.comecar()` sai no `if _carregando: return` — ou seja,
	#     NENHUM poder funciona mais, pelo resto da partida.
	#
	# O respawn devolvia vida, fruta e recarga, mas deixava o cast pendurado.
	_cast.abortar()
	set_meta("is_casting", false)
	set_meta("active_skill", "")
	set_meta("yami_black_hole_active", false)
	set_meta("yami_kurouzu_active", false)
	set_meta("is_frozen", false)
	remove_meta("custom_pose")
	_gura_rush_active = false
	_gura_grab_timer = 0.0
	_gura_rush_timer = 0.0
	if is_instance_valid(_gura_rush_target):
		_gura_rush_target.set_meta("is_frozen", false)
		_gura_rush_target = null
	_encerrar_bomu_rush()
	# timer removido
	_disparo.parar_rajada()
	_disparo.desligar_yami()

	# Volta a máquina de estados para o básico para destravar o jogador
	if _fsm:
		_fsm.transition_to("Idle")

	# MORRER ZERA AS RECARGAS (decisão do dono, 2026-08-12). Antes elas
	# atravessavam a morte — medido: cast de C (10 s), morte com 7,967 s
	# restantes, e a recarga seguia correndo. Como o respawn também devolve a
	# fruta, o jogador voltava sem poder nenhum E com o relógio andando no vazio.
	for slot_k in _fruit_cooldowns.keys():
		_fruit_cooldowns[slot_k] = 0.0
	for slot_k in _style_cooldowns.keys():
		_style_cooldowns[slot_k] = 0.0

	_vida.restaurar()
	RecepcaoDeDano.limpar(self)
	# Orçamento de dano também morre com o corpo. Um pente cujo teto já tinha
	# sido gasto sobreviveria ao respawn e a primeira arma sacada na vida nova
	# não machucaria ninguém — mesmo tipo de vazamento do item 23 (`is_casting`
	# pendurado depois da morte).
	encerrar_disparo()
	velocity = Vector3.ZERO
	global_position = Scoreboard.RESPAWN   # centro da plataforma (zona sem buraco)

func suppress_skills_temporarily(duration: float) -> void:
	_cast.suprimir(duration)

func lock_movement(duration: float, skill_id: String = "") -> void:
	# Ignora o timer (FSM cuida), mas mantém metadata
	set_meta("active_skill", skill_id)

# CAST — a decisão mora em src/player/cast_controller.gd (passo 6c). Aqui ficam
# as cascas: a API pública que o input, a HUD e a rede já conhecem.
func begin_charge(slot: String) -> void:
	_resetar_impulso_de_corrida()
	_cast.comecar(slot)

func release_charge(slot: String) -> void:
	_cast.soltar(slot)

# Compat: disparo imediato (sem segurar).
func cast_skill_slot(slot_key: String) -> void:
	_resetar_impulso_de_corrida()
	_cast.conjurar_direto(slot_key)

func _request_cast(slot: String) -> void:
	_resetar_impulso_de_corrida()
	_cast.pedir_cast(slot)

# ---- casting SERVIDOR-AUTORIDADE ----
# Cliente PEDE o cast -> servidor valida e é dono da hitbox -> a PRESENTATION
# (VFX/anim) roda em TODOS os clientes; o dano/knockback (DamageZone) só é ativo
# no servidor. Sem peer (SP puro/harness) roda tudo local, idêntico.
@rpc("any_peer", "reliable")
func _net_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0) -> void:
	if multiplayer.is_server():
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
		_do_server_cast(slot, aim, origin, charge)

# ======================= CORPO A CORPO (botão esquerdo) =======================

# ----------------- SOFT LOCK-ON E LUNGE -----------------
func find_best_melee_target(radius: float = 12.0) -> Node3D:
	var best_target: Node3D = null
	var highest_score: float = -9999.0
	
	var candidates = get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player")
	for c in candidates:
		if c == self or not is_instance_valid(c):
			continue

		var dist = global_position.distance_to(c.global_position)
		if dist > radius:
			continue
			
		var dir_to_target = (c.global_position - global_position).normalized()
		# ⚠️ FRENTE INVERTIDA ATÉ 2026-08-25 — medido, não deduzido.
		#
		# Era `-Vector3.FORWARD.rotated(Vector3.UP, _yaw)`. `Vector3.FORWARD` já é
		# (0, 0, −1); negá-la dá (0, 0, +1), que é PARA TRÁS. Comparada com a
		# direção que a hitbox usa (`-Basis.from_euler(...).z`, em
		# `melee_controller.pedir`), o produto escalar é **−1,00 em todo yaw**.
		#
		# Consequência: o cone frontal selecionava alvos ATRÁS do jogador, e o
		# lunge o empurrava para longe do alvo — e para longe de onde a hitbox
		# ia nascer. Ver `docs/erros.md`.
		var forward = RosaDosVentos.frente(_yaw)   # definição canônica: RosaDosVentos
		
		var dot_prod = forward.dot(dir_to_target)
		
		# Cone frontal (dot > 0.0 significa à frente do jogador)
		if dot_prod > 0.0:
			var score = (dot_prod * 15.0) - dist
			if score > highest_score:
				highest_score = score
				best_target = c
				
	return best_target

func perform_melee_lunge(target: Node3D, lunge_force: float = 18.0) -> void:
	if not is_instance_valid(target):
		return
		
	# 1. Soft-Lock (Rodar para encarar)
	var dir = (target.global_position - global_position).normalized()
	dir.y = 0 
	if dir.length_squared() > 0.001:
		_yaw = atan2(-dir.x, -dir.z)
		if _char_model:
			_char_model.rotation.y = _yaw
			
	# 2. Lunge (Impulso Frontal Instantâneo)
	# Mesma correção de frente do `find_best_melee_target` — ver a nota lá.
	var forward = RosaDosVentos.frente(_yaw)   # definição canônica: RosaDosVentos
	# ⚠️ `lunge_force` NÃO FOI RECALIBRADO, e isso é medida, não omissão.
	# O §3.3 do plano pede um puxão de ~0,30 m por golpe. Isto aqui é um impulso
	# de UM QUADRO: `_etapa_locomocao` reescreve `velocity.x/z` no quadro
	# seguinte, então 18 m/s ÷ 60 = **0,30 m** — o número-alvo, já de pé. Trocar
	# 18 por 1,5 ("0,3 m/s") daria um puxão 60x menor.
	velocity = forward * lunge_force

# ----------------- COMBO BREAKER -----------------
func _request_combo_breaker() -> void:
	if _combo_breaker_cooldown > 0.0:
		print("Combo Breaker em cooldown (", snapped(_combo_breaker_cooldown, 0.1), "s restantes)")
		return
	
	# Só pode ativar se estiver tomando dano/hitstun (Stunned)
	var is_stunned = (_hitstop_timer > 0.0) or (_fsm and _fsm.state and _fsm.state.name == "Stunned")
	if is_stunned:
		print("💥 COMBO BREAKER ATIVADO!")
		_combo_breaker_cooldown = 45.0 # Cooldown longo punitivo
		
		# Destrava hitstop imediatamente
		if _hitstop_timer > 0.0:
			if _char_model:
				_char_model.position.x = 0.0
				_char_model.position.z = 0.0
			if _animator and _animator.animation_player:
				_animator.animation_player.speed_scale = 1.0
		_hitstop_timer = 0.0
		RecepcaoDeDano.limpar(self)
		
		# Limpa debuffs de stun
		if has_meta("is_frozen"): set_meta("is_frozen", false)
		if has_meta("in_vortex"): set_meta("in_vortex", false)
		if has_meta("in_black_hole"): set_meta("in_black_hole", false)
		if has_meta("in_kurouzu"): set_meta("in_kurouzu", false)
		if _fsm:
			_fsm.transition_to("Dashing") # Usa o estado de Dashing para fugir e ganhar invulnerabilidade
			
		# Feedback visual e knockback em área para afastar inimigos
		if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
			_do_server_combo_breaker(global_position)
		else:
			_net_combo_breaker.rpc_id(1, global_position)

@rpc("any_peer", "reliable")
func _net_combo_breaker(pos: Vector3) -> void:
	if multiplayer.is_server():
		_do_server_combo_breaker(pos)

func _do_server_combo_breaker(pos: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		_net_play_combo_breaker.rpc(pos)
	else:
		_net_play_combo_breaker(pos)

@rpc("any_peer", "call_local", "reliable")
func _net_play_combo_breaker(pos: Vector3) -> void:
	# Efeito visual de Explosão de Ki/Burst
	var vfx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	vfx.mesh = sphere
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.6, 1.0, 0.8) # Azul claro
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(0.2, 0.6, 1.0)
	m.emission_energy_multiplier = 3.0
	vfx.material_override = m
	vfx.position = pos
	var current_scene = get_tree().current_scene
	if current_scene: current_scene.add_child(vfx)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(vfx, "scale", Vector3.ONE * 6.0, 0.3)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.set_parallel(false)
	tw.tween_callback(vfx.queue_free)
	
	if current_scene and AudioFX: AudioFX.hurt(current_scene, pos) # Som placeholder
	
	# Empurra inimigos próximos (só o servidor empurra)
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		var espaco = get_world_3d().direct_space_state
		var par = PhysicsShapeQueryParameters3D.new()
		var shape_cast = SphereShape3D.new()
		shape_cast.radius = 6.0
		par.shape = shape_cast
		par.transform = Transform3D(Basis(), pos)
		par.collide_with_areas = false
		par.collide_with_bodies = true
		par.collision_mask = 15
		if self is CollisionObject3D: par.exclude = [get_rid()]
		
		var hits = espaco.intersect_shape(par)
		for h in hits:
			var col = h.get("collider")
			if col != self and col is Node3D and col.has_method("take_damage"):
				var dir = (col.global_position - pos).normalized()
				dir.y = 0.5
				col.take_damage(0.0, pos, dir * 25.0, 0.5)
				var placar = get_tree().get_first_node_in_group("scoreboard")
				if placar and placar.has_method("register_hit"):
					placar.register_hit(col, self) # Zero dano, forte knockback

# --------------------------------------------------------

# Combo: soco DIREITO -> soco ESQUERDO -> CHUTE, encadeáveis dentro de
# Melee.JANELA (2 s). Segue o MESMO trajeto de rede das skills: o dono pede, o
# servidor cria a hitbox, todo mundo reproduz a animação.
func _request_melee() -> void:
	if _fsm and _fsm.state and _fsm.state.name == "Stunned":
		return # Não faz buffer se estiver atordoado
	_add_input_to_buffer("attack")

## Espaço + M1 — chute giratório curto inspirado em luta de rua. Não depende de
## alvo para começar: é uma variação intencional de mobilidade e acerta quem
## entrar na faixa frontal durante o giro.
func tentar_chute_giratorio(_yaw_ignorado: float = 0.0) -> bool:
	if equipped_weapon != "" or not Input.is_key_pressed(KEY_SPACE):
		return false
	if _spin_kick_active or _air_slam_active:
		return true
	if _spin_kick_cooldown > 0.0:
		return false
	_encerrar_mordida_mink()
	if _melee:
		_melee.cancelar_golpe()
	_spin_kick_active = true
	_spin_kick_cooldown = RECARGA_CHUTE_GIRATORIO
	_spin_kick_angle = 0.0
	_spin_kick_yaw = _yaw
	if _char_model:
		_spin_kick_rest_position = _char_model.position
	set_meta("custom_pose", "spin_kick")
	var frente := RosaDosVentos.frente(_spin_kick_yaw)
	velocity.x = frente.x * 8.0
	velocity.z = frente.z * 8.0
	if is_on_floor():
		velocity.y = JUMP_VELOCITY * 0.62
	var impacto := get_tree().create_timer(0.16)
	impacto.timeout.connect(func():
		if not _spin_kick_active:
			return
		var mundo := get_tree().current_scene
		if mundo:
			SpinKickFXClass.disparar(mundo, global_position, RosaDosVentos.frente(_spin_kick_yaw), self))
	var fim := get_tree().create_timer(0.42)
	fim.timeout.connect(_encerrar_chute_giratorio)
	return true

func _encerrar_chute_giratorio() -> void:
	_spin_kick_active = false
	_spin_kick_angle = 0.0
	if _char_model:
		_char_model.rotation.z = 0.0
		_char_model.position = _spin_kick_rest_position
	if String(get_meta("custom_pose", "")) == "spin_kick":
		remove_meta("custom_pose")

## Queda esmagadora — M1 no ar com adversário abaixo. Esta consulta é separada
## do cone frontal normal porque o alvo pode estar diretamente sob os pés.
func tentar_ataque_aereo(_yaw_ignorado: float = 0.0) -> bool:
	if equipped_weapon != "" or is_on_floor() or _air_slam_active or _air_slam_cooldown > 0.0:
		return false
	# O mergulho só existe acima da altura que já é forte o bastante para rachar
	# o solo no pouso normal. A constante é a mesma do FallImpactController —
	# não há um segundo número de "queda alta" para os dois efeitos divergirem.
	if _altura_para_impacto_aereo() < FallImpactController.ALTURA_MINIMA:
		return false
	var alvo := _alvo_abaixo_para_queda()
	if alvo == null:
		return false
	# O mergulho ganha de qualquer outro especial: não pode sobrar agarrão,
	# pose ou timer da mordida enquanto o corpo está caindo.
	_encerrar_mordida_mink()
	if _melee:
		_melee.cancelar_golpe()
	_air_slam_active = true
	_air_slam_cooldown = RECARGA_QUEDA_ESMAGADORA
	# Se acabou de sair do ápice, ainda pode estar quase em 0: dá o primeiro
	# impulso descendente mínimo e, fora isso, triplica o vetor de queda real.
	velocity.y = -maxf(absf(velocity.y) * 3.0, 3.0)
	set_meta("custom_pose", "air_slam_dive")
	return true

func _altura_para_impacto_aereo() -> float:
	if get_world_3d() == null:
		return 0.0
	var inicio := global_position + Vector3.UP * 0.15
	var consulta := PhysicsRayQueryParameters3D.create(inicio, inicio + Vector3.DOWN * 40.0, 15, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(consulta)
	if hit.is_empty():
		return 0.0
	return inicio.y - (hit["position"] as Vector3).y

func _alvo_abaixo_para_queda() -> Node3D:
	var melhor: Node3D = null
	var melhor_dist := INF
	for candidato in get_tree().get_nodes_in_group("enemy") + get_tree().get_nodes_in_group("player"):
		if candidato == self or not is_instance_valid(candidato) or not candidato is Node3D:
			continue
		var alvo := candidato as Node3D
		var delta := alvo.global_position - global_position
		# Só vale queda de verdade: o inimigo está abaixo e razoavelmente sob o
		# jogador, não um oponente distante que aconteça a estar mais baixo.
		if delta.y > -0.45 or Vector2(delta.x, delta.z).length() > 5.6:
			continue
		var dist := delta.length_squared()
		if dist < melhor_dist:
			melhor = alvo
			melhor_dist = dist
	return melhor

func _finalizar_ataque_aereo() -> void:
	_air_slam_active = false
	if String(get_meta("custom_pose", "")) == "air_slam_dive":
		remove_meta("custom_pose")
	var mundo := get_tree().current_scene
	if mundo:
		AirSlamFXClass.impactar(mundo, global_position + Vector3(0, -0.72, 0), self)


## Estilo Mink — galope, mordida e chute. Só nasce em sprint e com uma raça
## Mink montada no modelo; a escolha evita transformar qualquer M1 em especial.
func tentar_combo_mink(yaw: float) -> bool:
	if equipped_weapon != "" or not _is_sprinting() or _char_model == null:
		return false
	var raca := String(_char_model.get_meta("raca_id", ""))
	if not raca in ["mink_coelho", "mink_lobo", "mink_lobo_neve"]:
		return false
	if is_instance_valid(_mink_bite_target) and _mink_hold_timer > 0.0:
		_executar_chute_mink()
		return true
	if _mink_bite_dash:
		return true
	# Durante a recarga o clique segue para o M1 móvel normal. Assim o jogador
	# não fica sem atacar só porque a variação de corrida está indisponível.
	if _mink_bite_cooldown > 0.0:
		return false
	var alvo := find_best_melee_target(11.0)
	if alvo == null:
		return false
	var plano := alvo.global_position - global_position
	plano.y = 0.0
	if plano.length_squared() < 0.01:
		return false
	_mink_bite_dir = plano.normalized()
	_yaw = atan2(-_mink_bite_dir.x, -_mink_bite_dir.z)
	_mink_bite_target = alvo
	_mink_bite_dash = true
	_mink_bite_timer = 0.46
	set_meta("custom_pose", "mink_bite_dash")
	return true


func _process_mink_bite(delta: float) -> void:
	_mink_bite_timer -= delta
	if not is_instance_valid(_mink_bite_target) or _mink_bite_timer <= 0.0:
		_encerrar_mordida_mink()
		return
	var dist := global_position.distance_to(_mink_bite_target.global_position)
	if dist > 1.75:
		return
	_mink_bite_dash = false
	_mink_hold_timer = 1.15
	_mink_bite_cooldown = RECARGA_MORDIDA_MINK
	_mink_bite_target.set_meta("is_frozen", true)
	StatusFX.aplicar(_mink_bite_target, StatusFX.CONGELADO, _mink_hold_timer)
	# A mordida confirma o agarrão; o chute seguinte é o golpe de arremesso.
	_mink_bite_target.take_damage(54.0, _mink_bite_target.global_position, Vector3.ZERO, 0.28)
	set_meta("custom_pose", "mink_bite_hold")


func _process_mink_hold(delta: float) -> void:
	if not is_instance_valid(_mink_bite_target):
		_encerrar_mordida_mink()
		return
	_mink_hold_timer -= delta
	_mink_bite_target.global_position = global_position + _mink_bite_dir * 1.05 + Vector3.UP * 0.35
	if _mink_hold_timer <= 0.0:
		_encerrar_mordida_mink()


func _executar_chute_mink() -> void:
	if not is_instance_valid(_mink_bite_target):
		_encerrar_mordida_mink()
		return
	_mink_bite_target.set_meta("is_frozen", false)
	var impulso := (_mink_bite_dir + Vector3.UP * 0.32).normalized() * 48.0
	_mink_bite_target.take_damage(116.0, _mink_bite_target.global_position, impulso, 0.72)
	set_meta("custom_pose", "mink_kick")
	var limpar := get_tree().create_timer(0.34)
	limpar.timeout.connect(_encerrar_mordida_mink)


func _encerrar_mordida_mink() -> void:
	_mink_bite_dash = false
	_mink_bite_timer = 0.0
	_mink_hold_timer = 0.0
	if is_instance_valid(_mink_bite_target):
		_mink_bite_target.set_meta("is_frozen", false)
	_mink_bite_target = null
	if String(get_meta("custom_pose", "")).begins_with("mink_"):
		remove_meta("custom_pose")

## W/A/S/D — ataque contextual. O MeleeController é o dono do relógio; o
## Player só fixa direção, aplica root motion, apresenta e atravessa a rede.
func iniciar_ataque_contextual(id: String, yaw: float) -> bool:
	if not ContextualMeleeData.e_id_valido(id) or equipped_weapon != "":
		return false
	# O chute aéreo e o de parede existem justamente fora do chão; as variações
	# de solo continuam exigindo os pés apoiados. Ver `ContextualMelee.exige_chao`.
	if ContextualMeleeData.exige_chao(id) and not is_on_floor():
		return false
	if id == "context_retreat_kick" and not _recuo_contextual_livre(yaw):
		return false
	_resetar_impulso_de_corrida()
	_contextual_attack_seq += 1
	_apresentar_ataque_contextual(id, yaw, _contextual_attack_seq)
	var escala := scale.y
	var origem := global_position + Vector3.UP * escala
	pedir_ataque_contextual_no_servidor(_contextual_attack_seq, id, origem,
		RosaDosVentos.frente(yaw))
	return true

func sequencia_contextual_atual() -> int:
	return _contextual_attack_seq

func _recuo_contextual_livre(yaw: float) -> bool:
	if get_world_3d() == null:
		return false
	var frente := RosaDosVentos.frente(yaw)
	var inicio := global_position + Vector3.UP * 0.80
	var consulta := PhysicsRayQueryParameters3D.create(inicio, inicio - frente * 1.05, 15, [get_rid()])
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(consulta)
	if hit.is_empty():
		return true
	# Um adversário atrás não é parede e não deve desligar S + M1. A colisão
	# continua resolvida pelo CharacterBody; esta consulta só evita iniciar a
	# ação já comprimido contra cenário sólido.
	var collider = hit.get("collider")
	if collider is Node and ((collider as Node).is_in_group("player") or (collider as Node).is_in_group("enemy")):
		return true
	return false

func _processar_movimento_contextual() -> void:
	if _melee == null or not _melee.contextual_ativo():
		return
	var id := _melee.contextual_id()
	var frente := RosaDosVentos.frente(_contextual_attack_yaw)
	var rumo := ContextualMeleeData.direcao_de_deslocamento(id, frente)
	var velocidade := ContextualMeleeData.velocidade_de_deslocamento(id, _melee.tempo_na_fase())
	velocity.x = rumo.x * velocidade
	velocity.z = rumo.z * velocidade

func _limpar_vfx_contextual(id: String) -> void:
	# Uma nova ação pode reutilizar o mesmo ID antes de o fade da anterior acabar.
	# Limpar pelo prefixo evita uma pilha de telegráficos e garante que uma
	# rejeição local desapareça imediatamente, não após o autofree visual.
	var prefixo := "ContextualMeleeFX_" + id
	for filho in get_children():
		if str(filho.name).begins_with(prefixo):
			filho.queue_free()

func _apresentar_ataque_contextual(id: String, yaw: float, sequencia: int) -> void:
	# O host prevê antes de o RPC voltar. A deduplicação é por sequência, não por
	# ID: duas cotoveladas consecutivas são ações diferentes; o eco da primeira
	# não pode apagar nem recriar a segunda.
	if sequencia == _contextual_presented_seq:
		return
	if not _contextual_attack_id.is_empty() and _contextual_attack_id != id:
		_limpar_vfx_contextual(_contextual_attack_id)
	elif not _contextual_attack_id.is_empty():
		_limpar_vfx_contextual(id)
	_contextual_attack_id = id
	_contextual_attack_yaw = yaw
	_contextual_presented_seq = sequencia
	_contextual_presentation_token += 1
	var token := _contextual_presentation_token
	var ficha := ContextualMeleeData.especificacao(id)
	set_meta("custom_pose", str(ficha.get("pose", "")))
	if _char_model:
		_char_model.rotation.y = yaw
	ContextualMeleeFXClass.apresentar(self, id, yaw)
	# Este timer existe apenas para cópias remotas, que não rodam o
	# MeleeController da autoridade. O relógio de gameplay continua único e vive
	# no controlador; os 0,12 s cobrem a recuperação extra de whiff visual.
	var fim := get_tree().create_timer(ContextualMeleeData.duracao(id) + 0.12)
	fim.timeout.connect(func():
		if _contextual_presentation_token == token and _contextual_presented_seq == sequencia:
			encerrar_ataque_contextual(id))

func encerrar_ataque_contextual(id: String) -> void:
	if id != _contextual_attack_id:
		return
	var pose := str(ContextualMeleeData.especificacao(id).get("pose", ""))
	_contextual_attack_id = ""
	if String(get_meta("custom_pose", "")) == pose:
		remove_meta("custom_pose")

func cancelar_ataque_contextual(id: String, sequencia: int, avisar_servidor: bool = true) -> void:
	# Esta entrada é chamada pelo MeleeController em dash-cancel, troca por uma
	# ação de prioridade maior e limpeza de estado. O mesmo seq jamais cancela um
	# ataque iniciado depois.
	if sequencia != _contextual_attack_seq or id != _contextual_attack_id:
		return
	_contextual_presentation_token += 1
	_limpar_vfx_contextual(id)
	encerrar_ataque_contextual(id)
	if avisar_servidor:
		pedir_cancelamento_contextual_no_servidor(sequencia)

func _cancelar_contextual_local(sequencia: int) -> void:
	if sequencia != _contextual_attack_seq:
		return
	if _melee and _melee.has_method("cancelar_contextual_por_seq"):
		_melee.cancelar_contextual_por_seq(sequencia)
	elif not _contextual_attack_id.is_empty():
		cancelar_ataque_contextual(_contextual_attack_id, sequencia, false)

func pedir_ataque_contextual_no_servidor(sequencia: int, id: String, origem: Vector3, fwd: Vector3) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_do_server_contextual_melee(sequencia, id, origem, fwd)
	else:
		_net_contextual_melee.rpc_id(1, sequencia, id, origem, fwd)

func pedir_cancelamento_contextual_no_servidor(sequencia: int) -> void:
	if multiplayer.is_server() or not multiplayer.has_multiplayer_peer():
		_cancelar_contextual_servidor(sequencia, false)
	else:
		_net_cancel_contextual_melee.rpc_id(1, sequencia)

func _resetar_impulso_de_corrida() -> void:
	_aceleracao_da_corrida.resetar()

@rpc("any_peer", "call_remote", "reliable")
func _net_melee(passo: int, origem: Vector3, fwd: Vector3) -> void:
	if multiplayer.is_server():
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
		_do_server_melee(passo, origem, fwd)

@rpc("any_peer", "call_remote", "reliable")
func _net_contextual_melee(sequencia: int, id: String, origem: Vector3, fwd: Vector3) -> void:
	if multiplayer.is_server():
		var cid := multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority():
			return
		_do_server_contextual_melee(sequencia, id, origem, fwd)

@rpc("any_peer", "call_remote", "reliable")
func _net_cancel_contextual_melee(sequencia: int) -> void:
	if not multiplayer.is_server():
		return
	var cid := multiplayer.get_remote_sender_id()
	if cid != 0 and cid != get_multiplayer_authority():
		return
	_cancelar_contextual_servidor(sequencia, false)

func _esta_no_chao_contextual_servidor() -> bool:
	# Em cópias remotas o servidor não roda move_and_slide(), logo is_on_floor()
	# não descreve aquele corpo. A flag publicada pelo dono é só o primeiro
	# indício; o raycast do servidor confirma que existe solo próximo à posição
	# replicada antes de aceitar uma variação exclusiva do chão.
	if _is_authority:
		return is_on_floor()
	if not net_on_floor or get_world_3d() == null:
		return false
	var inicio := global_position + Vector3.UP * 0.35
	var fim := inicio + Vector3.DOWN * 2.10
	var consulta := PhysicsRayQueryParameters3D.create(inicio, fim, 15, [get_rid()])
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true
	return not get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()

func _rejeitar_contextual_servidor(sequencia: int) -> void:
	var dono := get_multiplayer_authority()
	if multiplayer.has_multiplayer_peer() and dono != multiplayer.get_unique_id():
		_net_contextual_rejected.rpc_id(dono, sequencia)
	else:
		_net_contextual_rejected(sequencia)

func _cancelar_contextual_servidor(sequencia: int = -1, rejeitado: bool = false) -> void:
	if _server_contextual_active_seq < 0:
		return
	if sequencia >= 0 and sequencia != _server_contextual_active_seq:
		return
	var seq_cancelada := _server_contextual_active_seq
	_server_contextual_token += 1
	_server_contextual_active_seq = -1
	_server_contextual_deadline_ms = 0
	var dono := get_multiplayer_authority()
	if multiplayer.has_multiplayer_peer() and dono != multiplayer.get_unique_id():
		if rejeitado:
			_net_contextual_rejected.rpc_id(dono, seq_cancelada)
		else:
			_net_contextual_cancelled.rpc_id(dono, seq_cancelada)
	elif rejeitado:
		_net_contextual_rejected(seq_cancelada)
	else:
		_net_contextual_cancelled(seq_cancelada)

func _contextual_servidor_pode_gerar_zona(sequencia: int, token: int) -> bool:
	return sequencia == _server_contextual_active_seq \
		and token == _server_contextual_token \
		and Time.get_ticks_msec() <= _server_contextual_deadline_ms

func _confirmar_acerto_contextual_servidor(sequencia: int) -> void:
	if sequencia != _server_contextual_active_seq:
		return
	var dono := get_multiplayer_authority()
	if multiplayer.has_multiplayer_peer() and dono != multiplayer.get_unique_id():
		_net_contextual_hit_confirmed.rpc_id(dono, sequencia)
	else:
		_net_contextual_hit_confirmed(sequencia)

func _do_server_contextual_melee(sequencia: int, id: String, origem: Vector3, fwd: Vector3) -> void:
	# O servidor não recebe teclas do cliente. Ele valida tudo que pode observar
	# sem inventar uma segunda simulação de input: enum, arma, chão, direção,
	# origem e cadência. A DamageZone abaixo continua sendo a única fonte de dano.
	# `last_seq` é marcada antes das demais recusas para que um pacote repetido
	# não possa ser testado indefinidamente até achar uma janela válida.
	if sequencia <= _server_contextual_last_seq:
		return
	_server_contextual_last_seq = sequencia
	if sequencia < 0 or not ContextualMeleeData.e_id_valido(id) or equipped_weapon != "":
		_rejeitar_contextual_servidor(sequencia)
		return
	# A exigência de chão é POR GOLPE desde a Fase 4: as variações aéreas seriam
	# rejeitadas aqui em partida com rede, e passariam no singleplayer — onde o
	# cliente é o servidor. O tipo de bug que só aparece com duas máquinas.
	if ContextualMeleeData.exige_chao(id) and not _esta_no_chao_contextual_servidor():
		_rejeitar_contextual_servidor(sequencia)
		return
	if fwd.length_squared() < 0.25 or absf(fwd.y) > 0.15:
		_rejeitar_contextual_servidor(sequencia)
		return
	if global_position.distance_to(origem) > 3.0 or absf(origem.y - global_position.y) > 2.5:
		_rejeitar_contextual_servidor(sequencia)
		return
	if id == "context_retreat_kick" and not _recuo_contextual_livre(atan2(-fwd.x, -fwd.z)):
		_rejeitar_contextual_servidor(sequencia)
		return
	var agora := Time.get_ticks_msec()
	if agora < _server_contextual_next_ms:
		_rejeitar_contextual_servidor(sequencia)
		return
	_server_contextual_next_ms = agora + int(ContextualMeleeData.duracao(id) * 1000.0)
	_server_contextual_active_seq = sequencia
	_server_contextual_token += 1
	_server_contextual_deadline_ms = _server_contextual_next_ms
	var frente := Vector3(fwd.x, 0.0, fwd.z).normalized()
	ContextualMeleeData.golpear(get_tree().current_scene, self, id, origem, frente,
		sequencia, _server_contextual_token)
	if multiplayer.has_multiplayer_peer():
		_net_play_contextual_melee.rpc(sequencia, id, frente)
	else:
		_net_play_contextual_melee(sequencia, id, frente)

@rpc("any_peer", "call_local", "reliable")
func _net_play_contextual_melee(sequencia: int, id: String, fwd: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	if not ContextualMeleeData.e_id_valido(id):
		return
	var plano := Vector3(fwd.x, 0.0, fwd.z)
	if plano.length_squared() < 0.001:
		return
	_apresentar_ataque_contextual(id, atan2(-plano.x, -plano.z), sequencia)

@rpc("any_peer", "call_remote", "reliable")
func _net_contextual_hit_confirmed(sequencia: int) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	if _melee and _melee.has_method("confirmar_contextual"):
		_melee.confirmar_contextual(sequencia)

@rpc("any_peer", "call_remote", "reliable")
func _net_contextual_rejected(sequencia: int) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	_cancelar_contextual_local(sequencia)

@rpc("any_peer", "call_remote", "reliable")
func _net_contextual_cancelled(sequencia: int) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender := multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1:
			return
	_cancelar_contextual_local(sequencia)

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
	if multiplayer.has_multiplayer_peer():
		var sender = multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1: return
	if not _proc_anim:
		return
	
	if equipped_weapon == "sword":
		# Para espada, tocar animação procedural no torso e braços para liberar pernas
		var g := Melee.passo(passo, equipped_weapon)
		var duracao = Melee.duracao_tocada(passo, equipped_weapon)
		var speed = 1.0 / maxf(duracao, 0.1) # Normalizado para 1.0s = fim da duração
		_proc_anim.play_procedural_slash(passo, speed)
	else:
		# Para normal, tocar clipe (.res) retargetado
		var clipe := Melee.clipe(passo, equipped_weapon)
		if clipe:
			var g := Melee.passo(passo, equipped_weapon)
			# `inicio` e `fim` DERIVADOS do frame data (2026-08-25): a janela é
			# posicionada para o pico medido do membro cair no fim do startup e
			# fechada na trava. Para a espada, que não foi convertida, os dois
			# devolvem o comportamento antigo (campo `inicio` da tabela, clipe
			# até o fim).
			_proc_anim.play_baked(clipe, float(g["vel"]),
				Melee.inicio(passo, equipped_weapon),
				String(g.get("melee_guarda", "")),
				Melee.fim_da_janela(passo, equipped_weapon))

# --- GURA GURA Z: INVESTIDA FÍSICA ---
func start_gura_rush(aim_dir: Vector3) -> void:
	if _gura_rush_active or _skill_cooldowns.get("Z", 0.0) > 0.0: return
	_gura_rush_active = true
	_gura_rush_timer = 0.6 # Tempo máximo correndo
	_gura_grab_timer = 0.0
	_gura_rush_target = null
	var flat = Vector3(aim_dir.x, 0, aim_dir.z)
	_gura_rush_dir = flat.normalized() if flat.length() > 0.1 else -global_transform.basis.z
	trigger_skill_cooldown("Z")
	gastar_energia(ENERGY_SKILL)
	congelar_para_cast()
	set_meta("custom_pose", "gura_rush")

func _process_gura_rush(delta: float) -> void:
	if _gura_grab_timer > 0.0:
		velocity = Vector3.ZERO # Para imediatamente
		_gura_grab_timer -= delta
		if _gura_grab_timer <= 0.0:
			_gura_rush_active = false
			remove_meta("custom_pose")
			if is_instance_valid(_gura_rush_target):
				_gura_rush_target.set_meta("is_frozen", false)
				_gura_rush_target = null
		elif is_instance_valid(_gura_rush_target):
			# Sincroniza e prende a posição do inimigo ao jogador de forma absoluta
			_gura_rush_target.global_position = global_position + _gura_rush_dir * 1.5 + Vector3.UP * 0.5
		return

	_gura_rush_timer -= delta
	if _gura_rush_timer <= 0.0:
		_gura_rush_active = false
		remove_meta("custom_pose")
		return
		
	# Detecção da hitbox de inimigo (Area3D ou Body) usando Shape Cast
	var mundo = get_world_3d()
	var par = PhysicsShapeQueryParameters3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.2
	par.shape = shape
	par.transform = Transform3D(Basis(), global_position + Vector3.UP * 1.0 + _gura_rush_dir * 1.5)
	par.collide_with_areas = true
	par.collide_with_bodies = true
	par.collision_mask = 15
	if self is CollisionObject3D: par.exclude = [get_rid()]
	
	var hits = mundo.direct_space_state.intersect_shape(par)
	for h in hits:
		var col = h.get("collider")
		if col != self and col is Node3D and col.has_method("take_damage") and not (col.has_meta("is_frozen") and col.get_meta("is_frozen")):
			_gura_rush_target = col
			_gura_rush_target.set_meta("is_frozen", true)
			StatusFX.aplicar(_gura_rush_target, StatusFX.CONGELADO, 1.0) # Desativa controle do alvo
			_gura_grab_timer = 0.5 # Tempo para sincronizar a animação do soco
			# Dispara o golpe visual (RPC) com charge 1.0 (golpe rápido e fatal)
			pedir_cast_no_servidor("Z", _gura_rush_dir, global_position, 1.0)
			break

# --- BOMU BOMU Z: corrida, agarrão e detonação ---
func start_bomu_rush(aim_dir: Vector3, _charge: float = 0.5) -> void:
	if _bomu_rush_active:
		return
	_bomu_rush_active = true
	_bomu_rush_timer = 0.72
	_bomu_grab_timer = 0.0
	var flat := Vector3(aim_dir.x, 0.0, aim_dir.z)
	_bomu_rush_dir = flat.normalized() if flat.length_squared() > 0.01 else -global_transform.basis.z
	set_meta("custom_pose", "bomu_z_charge")
	_bomu_hand_charge = BomuFX.criar_carga_na_mao(self)

func _process_bomu_rush(delta: float) -> void:
	if _bomu_grab_timer > 0.0:
		velocity = Vector3.ZERO
		_bomu_grab_timer -= delta
		if is_instance_valid(_bomu_rush_target):
			_bomu_rush_target.global_position = global_position + _bomu_rush_dir * 1.28 + Vector3.UP * 0.35
		if _bomu_grab_timer <= 0.0:
			pedir_cast_no_servidor("Z", _bomu_rush_dir, global_position, 0.5)
			_encerrar_bomu_rush()
		return
	_bomu_rush_timer -= delta
	if _bomu_rush_timer <= 0.0:
		_encerrar_bomu_rush()
		return
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.15
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position + Vector3.UP + _bomu_rush_dir * 1.35)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 15
	query.exclude = [get_rid()]
	for hit in get_world_3d().direct_space_state.intersect_shape(query):
		var alvo := hit.get("collider") as Node3D
		if alvo != self and is_instance_valid(alvo) and alvo.has_method("take_damage") and not alvo.get_meta("is_frozen", false):
			_bomu_rush_target = alvo
			_bomu_rush_target.set_meta("is_frozen", true)
			StatusFX.aplicar(_bomu_rush_target, StatusFX.CONGELADO, 0.42)
			_bomu_grab_timer = 0.20
			set_meta("custom_pose", "bomu_z_strike")
			break

func _encerrar_bomu_rush() -> void:
	_bomu_rush_active = false
	_bomu_rush_timer = 0.0
	_bomu_grab_timer = 0.0
	if is_instance_valid(_bomu_rush_target):
		_bomu_rush_target.set_meta("is_frozen", false)
		_bomu_rush_target = null
	if is_instance_valid(_bomu_hand_charge):
		_bomu_hand_charge.queue_free()
	_bomu_hand_charge = null
	if get_meta("custom_pose", "").begins_with("bomu_"):
		remove_meta("custom_pose")

# SERVIDOR = autoridade: (validaria cooldown/estado) e manda TODOS reproduzirem.
func _do_server_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0) -> void:
	if combat_mode == "fruit" and _fruit_damage_lock_timer > 0.0:
		return # validação autoritativa: cliente não pula a recuperação por RPC
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
		_net_play_cast.rpc(slot, aim, origin, charge)            # broadcast + call_local
	else:
		_net_play_cast(slot, aim, origin, charge)                # sem rede: local direto

# MIRA -> src/player/mira.gd (Fase 9). Estas três continuam aqui como cascas
# porque são a API que testes e componentes já conhecem.
func _muzzle_pos(side: int) -> Vector3:
	return _mira.boca_da_pistola(_pistols, side, _cam)

func _aim_target_point() -> Vector3:
	return _mira.ponto_de_mira(_cam, aim_assist)

func _aim_assist_target(cam_pos: Vector3, fwd: Vector3) -> Node3D:
	return _mira.alvo_alinhado(cam_pos, fwd)

@rpc("any_peer", "reliable")
func _net_bullet_req(aim: Vector3, origin: Vector3, arma: String) -> void:
	if multiplayer.is_server():
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
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
	if multiplayer.has_multiplayer_peer():
		var sender = multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1: return
	if arma != "":
		# BUKI: o disparo tem cara de arma (fogacho, cápsula, projétil) e o dano
		# por bala vem do `Balance`. O PENTE INTEIRO é uma conjuração só — as 100
		# balas do minigun dividem um orçamento, senão a arma com mais munição
		# seria automaticamente a mais forte.
		var spec_b := _spec_do_disparo("buki_buki", arma)
		BukiFX.disparo(get_tree().current_scene, origin, aim, arma, spec_b.dano, self, null, spec_b)
		return
	if get_tree() and get_tree().current_scene:
		AudioFX.gunshot(get_tree().current_scene, origin, randf_range(0.95, 1.12))
	# ⚠️ AQUI MORAVAM TRÊS LITERAIS (`8.0`, `25.0`, `8.0`) escritos à mão, que
	# ignoravam a tabela de skills — ela dizia 20 para a Mera Z e 28 para a Hie Z,
	# e nenhum dos dois era usado. Com 8 balas por rajada, o erro se multiplicava.
	var spec_r := _spec_do_disparo(current_fruit_id, "Z")
	if current_fruit_id == "hie_hie":
		IceFX.bullet(get_tree().current_scene, origin, aim, spec_r.dano, self, spec_r)
	elif current_fruit_id == "yami_yami":
		YamiFX.bullet(get_tree().current_scene, origin, aim, spec_r.dano, self, spec_r)
	else:
		FireFX.bullet(get_tree().current_scene, origin, aim, spec_r.dano, self, spec_r)

# ---------------------------------------------------- CONJURAÇÃO DE DISPARO
# A spec do pente/rajada em curso. Uma rajada de 8 balas e um pente de 100 são
# UMA conjuração, não 16 ou 100 — é isso que dá teto a elas.
#
# ⚠️ Só o valor do SERVIDOR importa: a `DamageZone` sai cedo em clientes, então
# cada peer ter o seu `cast_id` é inofensivo. Não vale a pena sincronizar.
var _spec_disparo: DamageSpec = null
var _spec_disparo_chave: String = ""

## Abre (ou reaproveita) a conjuração do disparo sustentado deste slot.
## Troca de arma ou de fruta abre uma conjuração nova — a chave carrega as duas.
func _spec_do_disparo(fruta: String, slot: String) -> DamageSpec:
	var chave := fruta + "/" + slot
	if _spec_disparo != null and _spec_disparo_chave == chave:
		return _spec_disparo
	var s := Balance.novo(fruta, slot)
	if s == null:
		s = DamageSpec.avulso(0.0)
	_spec_disparo = s
	_spec_disparo_chave = chave
	return s

## Fecha a conjuração de disparo. Chamado ao guardar a arma, ao parar a rajada e
## ao morrer: sem isto o pente seguinte nasceria com o orçamento do anterior já
## gasto, e a segunda arma sacada não machucaria ninguém.
func encerrar_disparo() -> void:
	if _spec_disparo != null:
		CombatResolver.encerrar(_spec_disparo.cast_id)
	_spec_disparo = null
	_spec_disparo_chave = ""

@rpc("any_peer", "call_local", "reliable")
func _net_play_cast(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0) -> void:
	if multiplayer.has_multiplayer_peer():
		var sender = multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1: return
	_fire_skill(slot, aim, origin, charge)

var _spawned_skills_container: Node3D

func _exit_tree() -> void:
	if is_instance_valid(_spawned_skills_container):
		_spawned_skills_container.queue_free()

func _get_skills_container() -> Node3D:
	if not is_instance_valid(_spawned_skills_container):
		_spawned_skills_container = Node3D.new()
		_spawned_skills_container.name = "Skills_" + name
		var sc = get_tree().current_scene
		if sc:
			sc.add_child.call_deferred(_spawned_skills_container)
		else:
			add_child.call_deferred(_spawned_skills_container)
	return _spawned_skills_container

# ⚠️ A LIMPEZA PRECISA ATRAVESSAR A REDE (2026-08-22).
#
# `clear_spawned_skills()` varre o contêiner `Skills_<jogador>` do peer em que
# roda — e `_fire_skill` é a PRESENTATION do golpe: ele roda em TODOS os peers,
# então cada um tem a sua cópia dos efeitos deste jogador. Limpar só localmente
# deixava as cópias vivas em todo mundo menos em quem trocou de fruta.
#
# Sintoma medido com a sonda de dois processos: os 45 vagalumes da Mera Mera
# continuavam no HOST depois de o cliente trocar de fruta, e detonavam minutos
# depois, já durante outra fruta. É o "quando o servidor morre ou troca de fruta
# a fruta não desespawna as skills" do relato, visto do outro lado.
#
# `call_local` para o pedido valer também em quem chamou; sem peer roda direto.
func limpar_skills_em_todos() -> void:
	if multiplayer.has_multiplayer_peer():
		_net_limpar_skills.rpc()
	else:
		clear_spawned_skills()

@rpc("any_peer", "call_local", "reliable")
func _net_limpar_skills() -> void:
	clear_spawned_skills()

func clear_spawned_skills() -> void:
	if is_instance_valid(_spawned_skills_container):
		for c in _spawned_skills_container.get_children():
			c.queue_free()

# Presentation da skill (roda em todos): VFX pela fruta/estilo. A DamageZone criada
# dentro só aplica dano no SERVIDOR (ver DamageZone).
func _fire_skill(slot: String, aim: Vector3, origin: Vector3, charge: float = 0.0) -> void:
	var variant: int = ["Z", "X", "C", "V"].find(slot)
	if variant < 0:
		variant = 0

	if _animator:
		_animator.trigger_kill()

	var world := _get_skills_container()

	if combat_mode == "style":
		var active_style: String = STYLES_LIST[current_style_idx]
		var sdata: Dictionary = FightingStyles.STYLES[active_style]["skills"][slot]
		# O dano vem do `Balance`, não da tabela do estilo — mesma fonte única das
		# frutas, para o corpo a corpo não ficar numa escala própria.
		var spec_e := Balance.spec_de_estilo(active_style, slot).para_cast()
		print("🥊 ESTILO ", active_style.to_upper(), ": ", sdata.get("nome", slot))
		FightingStyles.cast(world, active_style, variant, origin, aim, spec_e.dano, self, spec_e)
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
			elif current_fruit_id == "sem_fruta":
				print("🚫 Você comeu a Fruta da Normalidade. Suas skills não fazem nada.")
			else:
				push_warning("[Fruta] '%s' não tem skills no SkillSystem" % current_fruit_id)
				print("🚫 A fruta '%s' ainda não tem poderes implementados." % current_fruit_id)
			return
		var fid := current_fruit_id
		var sdata: Dictionary = fruit_skills[fid][slot]
		var cor: Color = sdata.get("cor", Color.WHITE)

		# A CONJURAÇÃO nasce aqui. `para_cast()` devolve uma cópia da spec com um
		# `cast_id` novo, e é ele que amarra todas as hitboxes deste golpe a um
		# orçamento só — ver src/combat/CombatResolver.gd.
		#
		# ⚠️ A spec tem de ser criada UMA vez por golpe e descer inteira até o
		# efeito. Deixar cada hitbox pedir a sua daria um orçamento por hitbox,
		# que é exatamente o teto que NÃO existia antes desta refatoração.
		var spec := Balance.novo(fid, slot)
		if spec == null:
			push_warning("[Balance] '%s/%s' não está na tabela de dano" % [fid, slot])
			spec = DamageSpec.avulso(0.0)
		var dano: float = spec.dano
		print("⚡ FRUTA ", fid.to_upper(), ": ", sdata.get("nome", slot))

		match fid:
			# ⚠️ O V DA GOMU NÃO É MAIS UM GOLPE — é a transformação Gear 2
			# (decisão do dono, 2026-08-27). Entra ANTES do `GomuFX.cast` porque
			# não cria hitbox nenhuma: é estado, não conjuração. O Red Hawk, que
			# era o V, segue vivo em `GomuFX._red_hawk` esperando o conjunto de
			# golpes transformado.
			"gomu_gomu":
				if slot == "V":
					if _gear2:
						_gear2.ativar()
				else:
					GomuFX.cast(world, origin, aim, variant, dano, self, spec)
			"suna_suna": SandFX.cast(world, origin, aim, variant, dano, self, spec)
			"mera_mera": FireFX.cast(world, origin, aim, variant, dano, self, charge, spec)
			"hie_hie":   IceFX.cast(world, origin, aim, variant, dano, self, spec)
			"goro_goro": GoroFX.cast(world, origin, aim, variant, dano, self, spec, charge)
			"yami_yami": YamiFX.cast(world, origin, aim, variant, dano, self, spec)
			"bara_bara": BaraFX.cast(world, origin, aim, variant, dano, self, spec)
			"gura_gura": GuraFX.cast(world, origin, aim, variant, dano, self, charge, spec)
			"bomu_bomu": BomuFX.cast(world, origin, aim, variant, dano, self, charge, spec)
			"buki_buki":
				# SAQUE DA ARMA. Roda em TODOS os peers (este método é a
				# presentation do cast), então o adversário vê a arma aparecer
				# na mão / o corpo virar canhão. O tiro do saque sai junto.
				_buki_mostrar_arma(["Z", "X", "C", "V"][variant])
				BukiFX.cast(world, origin, aim, variant, dano, self, spec)
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
	# ⚠️ SAÍDA POR TROCA DE FRUTA. O Gear 2 é da Gomu Gomu; sair dela tem de
	# largar a transformação junto, senão a pele e o chapéu ficam num personagem
	# que já é de outra fruta.
	if _gear2 and _gear2.esta_ativo():
		_gear2.desativar()
	# ⚠️ A FRUTA SOME DA ÁRVORE AO SER EQUIPADA — por QUALQUER caminho.
	#
	# Isto vive aqui, e não no `pickup_fruit`, porque equipar tem TRÊS entradas e
	# só uma delas escondia a fruta:
	#   • `TreeAndFruitGenerator.pickup_fruit` (encostar na árvore) — escondia;
	#   • `Main.gd:114`, a fruta de nascença — NÃO escondia;
	#   • `FruitNet._apply_pickup` e o ciclo de debug — dependiam do caminho.
	#
	# Sintoma medido em 2026-08-12: o jogador nascia com `suna_suna` e a
	# `suna_suna` continuava VISÍVEL na árvore. Em partida de dois, os dois
	# nasciam com ela e o mapa ainda oferecia uma terceira — o oposto do
	# equilíbrio que a regra existe para garantir.
	#
	# A fruta ANTERIOR volta para a árvore: trocar de poder devolve o antigo ao
	# mapa, exatamente como morrer devolve.
	if fruit_id != current_fruit_id:
		limpar_skills_em_todos()
		if current_fruit_id != "":
			TreeAndFruitGenerator.respawn_fruit(current_fruit_id)
		if fruit_id != "":
			TreeAndFruitGenerator.hide_fruit(fruit_id)

	_fruit_cooldowns.clear()
	current_fruit_id = fruit_id
	
	if fruit_id == "gura_gura":
		scale = Vector3(2.0, 2.0, 2.0)
	else:
		scale = Vector3.ONE
		
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
	_disparo.desligar_yami()
	# Trocou de fruta -> a arma da Buki cai da mão (e o slot dela esfria).
	_buki_guardar()
	_buki_mostrar_arma("")
	set_meta("yami_black_hole_active", false)
	set_meta("yami_kurouzu_active", false)
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

func _alvo_mais_proximo(max_dist: float) -> Node3D:
	return _mira.mais_proximo(max_dist)

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
#  O modelo é o toggle da pistola da Yami (`DisparoSustentado.atualizar_yami`), que já fazia
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
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
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
	if multiplayer.has_multiplayer_peer():
		var sender = multiplayer.get_remote_sender_id()
		if sender != 0 and sender != 1: return
	# Saque = pente novo = conjuração nova. Encerrar ANTES de mostrar a arma
	# garante que sacar a MESMA arma duas vezes devolva o orçamento cheio (a
	# troca entre armas diferentes já seria pega pela chave de `_spec_do_disparo`).
	encerrar_disparo()
	_buki_mostrar_arma(slot)

@rpc("any_peer", "reliable")
func _net_buki_guardar_req() -> void:
	if multiplayer.is_server():
		var cid = multiplayer.get_remote_sender_id()
		if cid != 0 and cid != get_multiplayer_authority(): return
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
	# Arma guardada, pente encerrado: o próximo saque começa com o orçamento cheio.
	encerrar_disparo()

func _buki_apontar_canhao() -> void:
	_buki.apontar_canhao(_is_authority, _pitch, _yaw, net_facing)

var equipped_weapon: String = ""

# ============================================================================
#  SISTEMA DE ITENS / EQUIPAMENTOS
# ============================================================================

func equip_item(item_node: Node3D) -> void:
	if item_node == null: return
	if _rig.item_handle == null: return
	
	var p = item_node.get_parent()
	if p:
		p.remove_child(item_node)
	
	_rig.item_handle.add_child(item_node)
	item_node.position = Vector3.ZERO
	item_node.rotation = Vector3.ZERO
	
	if item_node is SwordPickup:
		equipped_weapon = "sword"
		print("[Player] Arma equipada: sword")
