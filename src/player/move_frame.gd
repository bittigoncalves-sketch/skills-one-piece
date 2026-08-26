class_name MoveFrame
extends RefCounted
# ============================================================================
#  MOVE FRAME — o que o jogador PEDIU neste quadro.
#
#  Passo zero da Fase 4 (docs/ARQUITETURA_PLAYER.md). A Fase 1 mediu e concluiu:
#
#    "Os locais compartilhados são a métrica do acoplamento. Enquanto forem
#     tantos, MovementController, ParkourController e DashController são o MESMO
#     componente. A Fase 4 começa reduzindo essa lista, não criando três
#     arquivos."
#
#  O `_etapa_locomocao` carregava 16 locais de quadro que locomoção, parkour e
#  dash liam uns dos outros. Este objeto separa a metade que é **leitura pura**:
#  teclas e a base da câmera. Não decide nada, não escreve `velocity`, não toca
#  na física.
#
#      LER (aqui)  →  DECIDIR (etapa)  →  ESCREVER (velocity)
#
#  O ganho não é estético. Enquanto `f`, `r`, `dir` e a borda do Espaço fossem
#  locais soltos, qualquer separação em três arquivos teria que passar os quatro
#  de mão em mão — trocando acoplamento por cerimônia. Agora é UM parâmetro, e
#  dá pra MEDIR quantos campos cada candidato a controller realmente usa.
#
#  Também traz `_space_was` (a borda do Espaço) para dentro: era campo do Player
#  só porque a detecção de borda precisa lembrar o quadro anterior. Isso é
#  assunto de quem LÊ a tecla, não do Player.
# ============================================================================

var f: float = 0.0        # frente(+) / trás(-)
var r: float = 0.0        # direita(+) / esquerda(-)

var frente: Vector3 = Vector3.FORWARD   # -Z da câmera, sem pitch
var direita: Vector3 = Vector3.RIGHT    # +X da câmera, sem pitch
var dir: Vector3 = Vector3.ZERO         # direção pedida, já normalizada

var sprint: bool = false            # Shift COM movimento (segurar parado não conta)
var espaco_segurado: bool = false
var espaco_agora: bool = false      # BORDA: só no quadro em que o Espaço bate
var dash_segurado: bool = false     # Q segurado (mira do dash)

var _espaco_antes: bool = false

# `yaw` é a orientação real da câmera. Nada de adivinhar: a direção do
# movimento sai da mesma base que o jogador está vendo.
# `menu_fechado` é recebido do Player (via HUD). No Wayland, o mouse_mode
# às vezes perde sincronia com a janela. Confiar no estado da UI é mais seguro.
func ler(yaw: float, menu_fechado: bool = true) -> void:
	# Fallback seguro: ou o mouse está de fato capturado, ou sabemos que o menu
	# está fechado (resolve o bug do Wayland ignorar as teclas WASD).
	var ativo := menu_fechado and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or OS.get_name() == "Linux" or OS.get_name() == "FreeBSD")

	f = 0.0
	r = 0.0
	if ativo:
		# is_physical_key_pressed garante que a posição física WASD no teclado funcione,
		# não importando se o layout do SO do usuário é QWERTY, AZERTY, ou Dvorak.
		if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    f += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  f -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): r += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  r -= 1.0

	# Base do pivô da câmera PURA (só yaw), sem distorção de pitch — é o que faz
	# o dash ser sempre horizontal e olhar pra cima não virar empuxo.
	var base := Basis.from_euler(Vector3(0, yaw, 0))
	frente = -base.z
	direita = base.x

	dir = frente * f + direita * r
	if dir.length() > 1.0:
		dir = dir.normalized()

	sprint = Input.is_key_pressed(KEY_SHIFT) and dir.length_squared() > 0.01

	# Borda do Espaço: salto longo, vault e geppo só disparam na BATIDA da tecla.
	# Segurar não pode repetir o gatilho (viraria velocidade infinita).
	espaco_segurado = Input.is_key_pressed(KEY_SPACE) and ativo
	espaco_agora = espaco_segurado and not _espaco_antes
	_espaco_antes = espaco_segurado

	dash_segurado = Input.is_physical_key_pressed(KEY_Q) and ativo

# O combate CONGELA o movimento (rajada Z da Mera/Hie: fica parado atirando, só
# a câmera gira). É o Player quem decide isso — daí ser um pedido, e não uma
# leitura de tecla a mais aqui dentro.
func congelar() -> void:
	dir = Vector3.ZERO
	sprint = false

# O GOLPE PLANTA O CORPO — enquanto a animação do corpo a corpo corre, o jogador
# não anda nem sai do chão (pedido de 2026-08-15).
#
# Diferente do `congelar()`, este mata TAMBÉM o Espaço: "não dá para se mover
# durante o golpe" inclui não pular. Sem isso o pulo viraria o cancelamento
# grátis de todo golpe, e a trava não significaria nada.
#
# ⚠️ `dash_segurado` NÃO é tocado, de propósito. A esquiva é o cancelamento
# LEGÍTIMO do combo — quem decide se ela vale é o `dash_bloqueado` do Player, que
# já libera o dash-cancel depois de o golpe conectar (`hit_confirmed`). Zerar a
# tecla aqui tiraria essa decisão de quem é dono dela.
func travar_golpe() -> void:
	dir = Vector3.ZERO
	sprint = false
	f = 0.0
	r = 0.0
	espaco_segurado = false
	espaco_agora = false
