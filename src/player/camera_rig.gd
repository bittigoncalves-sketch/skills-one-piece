class_name CameraRig
extends Node3D
# ============================================================================
#  CAMERA RIG — a câmera do jogador e tudo que se sente através dela.
#
#  Primeiro componente extraído do `Player.gd` (Fase 2 de
#  docs/ARQUITETURA_PLAYER.md). Foi escolhido para abrir porque é o de menor
#  risco: não tem RPC nenhum, quase só LÊ o estado do player, e o que ele
#  escreve é dele mesmo.
#
#  ESTE NÓ É O PIVÔ. A cadeia fica:
#      CameraRig (yaw/pitch) → Ombro (offset lateral) → SpringArm → Camera3D
#  O ombro empurra a câmera para a direita, deixando o corpo à esquerda e a mira
#  um pouco ao lado dele. O SpringArm impede a câmera de atravessar parede.
#
#  ---------------------------------------------------------------- FRONTEIRA
#  O princípio da arquitetura é: **cada componente é dono do seu estado; o
#  Player combina os resultados.** Aqui isso significa:
#
#   • O rig é DONO de: tremor, soco de FOV, fase do balanço, perspectiva,
#     distância da câmera e os nós da cadeia.
#   • O rig LÊ do player, por parâmetro: velocidade, se está no chão, se está
#     em sprint, a mira (yaw) e se a luneta está ligada.
#   • Quem quiser tremor ou soco de FOV **PEDE** (`pedir_shake`,
#     `pedir_fov_punch`) em vez de escrever no campo.
#
#  Esse último ponto é o motivo de o corte começar por aqui: `_fov_punch` tinha
#  TRÊS donos escrevendo direto (corpo a corpo, habilidades e o ciclo), e era um
#  dos 22 campos compartilhados que travavam a partição. Virou pedido.
# ============================================================================

## Multiplicador de altura da câmera. 1.0 para todo mundo; o Gigante sobe junto
## com o corpo, senão enxergaria a partir do próprio peito (2026-08-29).
var escala_do_corpo: float = 1.0

func definir_escala(e: float) -> void:
	escala_do_corpo = maxf(e, 0.05)

# Altura do pivô em 3ª pessoa, a partir do CENTRO do colisor (1,6 m de altura: a
# cabeça termina em +0,8). Era 2,2 — 1,4 m acima da cabeça; o dono pediu a câmera
# mais baixa em 16/09/2026 e escolheu a altura da cabeça (estilo por cima do ombro).
const CAM_HEIGHT_TPS := 1.0
const CAM_HEIGHT_FPS := 0.6   # altura do "olho" em 1ª pessoa
const SHOULDER_RIGHT := 1.1   # deslocamento p/ o ombro direito

# FOV por ESTADO. Degraus, não rampa: o salto de CORRENDO p/ SPRINT é o que faz
# o Shift dar o "clique" na mão.
#
# FOV_INTENSIDADE é o único número a mexer para calibrar a força do efeito. Os
# ganhos abaixo estão em graus "cheios" e guardam a PROPORÇÃO entre os estados;
# a intensidade escala todos juntos, então afinar não desmonta os degraus. Em
# 1.0 a variação era de 22° — forte demais em jogo. Em 0.10 sobra ~2,2°: o FOV
# respira sem chamar atenção.
const FOV_INTENSIDADE := 0.0
const FOV_BASE := 68.0
## Multiplicador do FOV de fora (puxar a pokébola fecha até 15 %, como o arco do Minecraft). 1 = sem efeito.
var fator_fov := 1.0
const FOV_G_ANDANDO := 4.0
const FOV_G_CORRENDO := 12.0
const FOV_G_SPRINT := 22.0
const FOV_G_AR := 3.0
const FOV_LUNETA := 22.0      # sniper da Buki: ~3x de aumento

# Afastamento em 3ª pessoa (ajustável no scroll, 2–15 m). Era 6,0; o dono pediu a
# câmera mais próxima do jogador em 16/09/2026 — vale para arena e Modo História.
var distancia: float = 4.0

## CÂMERA NO LEME (18/11/2026, pedido do dono: "o jogador tem que ver o mar tranquilamente e o que está na frente; afaste a câmera o suficiente em cada barco").
## Quem pilota chama `entrar_navegacao` com o enquadramento do casco (`enquadramento_de_barco`): a câmera recua e SOBE na medida do barco, o próprio casco deixa
## de empurrá-la para perto (o braço da mola ignora o barco) e o campo de visão abre um pouco. `sair_navegacao` devolve tudo como estava.
const FOV_NAVEGANDO := 1.12
var _altura_navegando := 0.0
var _distancia_min := 2.0
var _distancia_max := 15.0
var _fov_antes := 1.0
var _excluidos_navegando: Array[RID] = []
var navegando := false
var _ombro: Node3D
var _spring: SpringArm3D
## Close curto: quanto da distância normal vale agora e quanto tempo ainda dura.
var _close_fracao := 1.0
var _close_t := 0.0
var _cam: Camera3D
var _primeira_pessoa := false
## Terceiro modo da câmera (F5): na FRENTE do personagem, olhando para ele (como o F5 do Minecraft). A mira continua sendo a do rig (`direcao_da_mira`).
var _de_frente := false

var _shake: float = 0.0       # tremor de tela que decai
var _fov_punch: float = 0.0   # zoom-in momentâneo ao atacar (decai)
var _bob_t: float = 0.0       # fase do balanço ao andar/correr
var _no_chao_antes := true    # p/ detectar o instante do pouso

## Afastamento da câmera por estado. Os números são o que torna a mudança
## PERCEPTÍVEL: 1,1 m já se nota sem desorientar, e 2,6 m no sprint dá a sensação
## de abrir campo de visão para correr.
const AFASTA_ANDANDO := 1.1
const AFASTA_CORRENDO := 2.6
## Abaixo disto o jogador conta como parado (ruído de física não deve afastar).
const LIMIAR_PARADO := 0.06
## Ida mais lenta que a volta: ver a nota no `atualizar`.
const IDA_DA_CAMERA := 3.2
const VOLTA_DA_CAMERA := 6.0


# ------------------------------------------------------------------ montagem
# `dono` é o corpo: entra na exclusão do SpringArm para a câmera nunca colidir
# com o próprio jogador. `ativa` liga a Camera3D — só a do player local.
func montar(dono: CollisionObject3D, ativa: bool) -> void:
	_ombro = Node3D.new()
	_ombro.name = "Ombro"
	add_child(_ombro)

	_spring = SpringArm3D.new()
	_spring.name = "Spring"
	_spring.margin = 0.15
	var esfera := SphereShape3D.new()
	esfera.radius = 0.15
	_spring.shape = esfera
	_ombro.add_child(_spring)
	if dono:
		_spring.add_excluded_object(dono.get_rid())

	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.near = 0.05
	_cam.current = ativa
	_spring.add_child(_cam)
	if ativa:
		_cam.make_current()
	aplicar_perspectiva()

# A Camera3D, para quem precisa da direção da mira (tiro, raycast, alvo).
func camera() -> Camera3D:
	return _cam

func esta_montado() -> bool:
	return _cam != null

# ------------------------------------------------------------------- pedidos
# Tremor de tela. Pedido, não campo: vários sistemas querem sacudir a câmera, e
# nenhum deles precisa saber como o tremor decai.
func pedir_shake(quantidade: float) -> void:
	_shake = clampf(maxf(_shake, quantidade), 0.0, 1.0)

# Soco de FOV (zoom rápido no impacto). Era escrito direto por três domínios —
# ver o cabeçalho.
func pedir_fov_punch(quantidade: float) -> void:
	pass # _fov_punch = maxf(_fov_punch, quantidade) # Desabilitado a pedido (distorção)

# Onde a câmera olha. O yaw/pitch continuam sendo do Player, porque quem os
# escreve é o INPUT (e a mira assistida das armas) — o rig só aponta.
func apontar(yaw: float, pitch: float) -> void:
	rotation = Vector3(pitch, yaw, 0)

## F5 cicla: 3ª pessoa → 1ª pessoa → de FRENTE → 3ª pessoa. Devolve se ficou em 1ª pessoa (como antes).
func alternar_perspectiva() -> bool:
	if _forcada:
		return true          # arma da Buki na mão: a 1ª pessoa é obrigatória até guardar
	if _de_frente:
		_de_frente = false
	elif _primeira_pessoa:
		_primeira_pessoa = false
		_de_frente = true
	else:
		_primeira_pessoa = true
	aplicar_perspectiva()
	return _primeira_pessoa


## Buki Buki empunhada = FPS (22/11/2026). Guarda a perspectiva de antes e a devolve ao guardar a arma.
var _forcada := false
var _antes_1a := false
var _antes_frente := false
func forcar_primeira_pessoa(sim: bool) -> void:
	if sim and not _forcada:
		_antes_1a = _primeira_pessoa
		_antes_frente = _de_frente
		_forcada = true
		_primeira_pessoa = true
		_de_frente = false
	elif not sim and _forcada:
		_forcada = false
		_primeira_pessoa = _antes_1a
		_de_frente = _antes_frente
	aplicar_perspectiva()


func em_frente() -> bool:
	return _de_frente


## Para onde o personagem MIRA (o que ele olha), em qualquer modo. De frente a câmera olha para o personagem, então a mira NÃO é a direção dela.
func direcao_da_mira() -> Vector3:
	return -global_transform.basis.z

func em_primeira_pessoa() -> bool:
	return _primeira_pessoa

var _queda_agachar := 0.0

func atualizar_agachar(delta: float, queda: float) -> void:
	_queda_agachar = lerpf(_queda_agachar, queda, 1.0 - exp(-18.0 * delta))
	position.y = (CAM_HEIGHT_FPS if _primeira_pessoa else CAM_HEIGHT_TPS) * escala_do_corpo - _queda_agachar + (0.0 if _primeira_pessoa else _altura_navegando)

func aplicar_perspectiva() -> void:
	if _spring == null:
		return
	if _primeira_pessoa:
		position.y = CAM_HEIGHT_FPS * escala_do_corpo - _queda_agachar
		_ombro.position.x = 0.0
		_spring.spring_length = 0.0
	else:
		position.y = CAM_HEIGHT_TPS * escala_do_corpo - _queda_agachar + _altura_navegando
		_ombro.position.x = 0.0 if _de_frente else SHOULDER_RIGHT
		_spring.spring_length = distancia
	# De frente: o braço da mola gira meia volta e a câmera fica NA FRENTE do corpo, olhando para ele.
	_ombro.rotation.y = PI if _de_frente else 0.0

## Quanto a câmera recua além da distância base, por estado de movimento.
## Parado 0; andando um passo visível; correndo bem mais.
func _afastamento(spd: float, sprint: bool) -> float:
	if spd <= LIMIAR_PARADO:
		return 0.0
	return AFASTA_CORRENDO if sprint else AFASTA_ANDANDO


func ajustar_distancia(passo: float) -> void:
	distancia = clampf(distancia + passo, _distancia_min, _distancia_max)


## O enquadramento de um barco de `tamanho` (casco: x largura, y altura, z comprimento): {"distancia", "altura"} da câmera em metros.
## Recuo = 5 m + 85 % do comprimento (bote 6 m → ~10; chalupa 12 → ~15; barco-casa 18 → ~20; galeão 32 → ~32; de 8 a 36). Altura EXTRA sobre a cabeça do
## piloto = 1 m + 16 % do comprimento + 15 % da altura do casco (de 1,5 a 8 m): sobe o bastante para a linha de visão passar por cima da proa e do mastro.
## Decisão de design, não medição: valores de partida para o dono ajustar. GATILHO para rever: barco novo muito diferente (comprimento > 40 m ou casco de > 25 m de altura).
static func enquadramento_de_barco(tamanho: Vector3) -> Dictionary:
	return {
		"distancia": clampf(5.0 + tamanho.z * 0.85, 8.0, 36.0),
		"altura": clampf(1.0 + tamanho.z * 0.16 + tamanho.y * 0.15, 1.5, 8.0),
	}


func entrar_navegacao(enquadramento: Dictionary, excluir: Array[RID]) -> void:
	if navegando:
		sair_navegacao()
	navegando = true
	distancia = float(enquadramento["distancia"])
	_distancia_min = distancia * 0.6
	_distancia_max = distancia * 1.5
	_altura_navegando = float(enquadramento["altura"])
	_fov_antes = fator_fov
	fator_fov = FOV_NAVEGANDO
	_excluidos_navegando = excluir.duplicate()
	if _spring != null:
		for rid in _excluidos_navegando:
			_spring.add_excluded_object(rid)
	aplicar_perspectiva()


func sair_navegacao() -> void:
	if not navegando:
		return
	navegando = false
	if _spring != null:
		for rid in _excluidos_navegando:
			_spring.remove_excluded_object(rid)
	_excluidos_navegando.clear()
	_altura_navegando = 0.0
	_distancia_min = 2.0
	_distancia_max = 15.0
	fator_fov = _fov_antes
	aplicar_perspectiva()


## CLOSE CURTO (22/09/2026) — a câmera aproxima por `duracao` e volta sozinha.
##
## ⚠️ EXCEÇÃO DECLARADA. O projeto não força câmera nem usa soco de FOV (decisão do
## dono). O dono abriu exceção só para o impacto do Rocket Crash, depois de ver o
## close no vídeo de referência. Vale apenas na câmera de quem deu o golpe.
func aproximar(fracao: float, duracao: float) -> void:
	_close_fracao = clampf(fracao, 0.2, 1.0)
	_close_t = maxf(duracao, 0.0)


func em_close() -> bool:
	return _close_t > 0.0

# --------------------------------------------------------------------- ciclo
# Chamado pelo Player todo quadro. Recebe o estado que precisa em vez de ir
# buscá-lo — é o que mantém a fronteira honesta.
## `parando`: o jogador SOLTOU as teclas e o corpo ainda está freando (02/10/2026,
## frenagem com derrapagem em `locomocao_chao.gd`). Para o afastamento, isso já é
## parado — ver a nota da volta abaixo.
func atualizar(delta: float, velocidade: Vector3, vel_ref: float, no_chao: bool,
		sprint: bool, yaw: float, luneta: bool, parando := false) -> void:
	if _cam == null:
		return
	var planar := Vector2(velocidade.x, velocidade.z).length()
	var spd := clampf(planar / maxf(vel_ref, 0.001), 0.0, 1.2)

	# --- offsets = TREMOR + BALANÇO (h_offset/v_offset NÃO afetam a mira) ---
	var sh := _shake * 0.09
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 3.5, 0.0)
	var sx := randf_range(-sh, sh)
	var sy := randf_range(-sh, sh)
	var andando := spd > 0.05 and no_chao
	_bob_t += delta * (4.0 + spd * 9.0)
	var amp := (spd * 0.024) if andando else 0.0
	_cam.h_offset = lerpf(_cam.h_offset, sx + cos(_bob_t) * amp, 0.5)
	_cam.v_offset = lerpf(_cam.v_offset, sy + absf(sin(_bob_t)) * amp, 0.5)

	# ------------------------------------------------------------------ FOV
	# A pedido do usuário, o FOV dinâmico e o soco de FOV foram removidos do jogo por completo.
	# Apenas a luneta altera o FOV.
	var alvo_fov: float = FOV_BASE * fator_fov
	
	if luneta:
		alvo_fov = FOV_LUNETA
		
	var vel_fov := 9.0 if alvo_fov > _cam.fov else 3.5
	_cam.fov = lerpf(_cam.fov, alvo_fov, vel_fov * delta)

	# --- inclinação: rolagem ao andar de lado + gingado no ritmo do passo ---
	var direita := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
	var strafe := clampf(velocidade.dot(direita) / maxf(vel_ref, 0.001), -1.0, 1.0)
	var tilt := -strafe * 3.5 + (sin(_bob_t) * spd * 1.2 if andando else 0.0)
	_cam.rotation.z = lerpf(_cam.rotation.z, deg_to_rad(tilt), 6.0 * delta)

	# Recuo da câmera ao correr (só 3ª pessoa)
	if not _primeira_pessoa and _spring:
		# ⚠️ AFASTAMENTO EM DEGRAUS, e não uma rampa contínua pela velocidade.
		# Pedido do dono: começou a andar, a câmera afasta um pouco DE FORMA
		# VISÍVEL; começou a correr, afasta mais; parou, volta ao normal.
		#
		# Degrau em vez de rampa porque o objetivo é o jogador PERCEBER a
		# mudança. Uma rampa proporcional dá quase nada na caminhada (era
		# `spd * 0.9`, ou seja ~0,4 andando) e a informação se perde.
		#
		# A volta é mais rápida que a ida (`VOLTA` > `IDA`): parar é uma decisão
		# do jogador e a câmera tem de obedecer na hora; sair andando é gradual.
		#
		# ⚠️ E "parar" é a DECISÃO, não o corpo zerado. Desde a frenagem de
		# 02/10 o corpo leva 0,3–0,6 s para parar; esperando a velocidade zerar,
		# a câmera ficava longe esse tempo todo (medido: 5,15 m contra 4,05 m
		# parado). O balanço e a inclinação continuam seguindo o corpo.
		var alvo_dist: float = distancia + (0.0 if parando else _afastamento(spd, sprint))
		if _close_t > 0.0:
			_close_t = maxf(_close_t - delta, 0.0)
			alvo_dist *= _close_fracao
		var vel_dist: float = VOLTA_DA_CAMERA if alvo_dist < _spring.spring_length else IDA_DA_CAMERA
		_spring.spring_length = lerpf(_spring.spring_length, alvo_dist, vel_dist * delta)

	# Tranco ao aterrissar
	if no_chao and not _no_chao_antes:
		pedir_shake(0.3)
	_no_chao_antes = no_chao

	_efeitos_de_tela(spd, sprint)

# ⚠️ OS EFEITOS DE VELOCIDADE NA TELA SAÍRAM (decisão do dono, 2026-08-27).
#
# Eram quatro camadas: borrão radial, linhas de velocidade, aberração cromática e
# vinheta. As linhas misturavam a imagem com BRANCO PURO
# (`mix(col, vec3(1.0), ...)` no shader do `ScreenFX`) — é o "esbranquiçamento"
# relatado; as outras três distorciam.
#
# O retorno de velocidade passou a ser a DISTÂNCIA DA CÂMERA. É melhor pelo mesmo
# motivo que a rosa dos ventos é melhor que cinco cópias: diz a mesma coisa sem
# atrapalhar o que o jogador precisa enxergar. Num jogo de luta, sujar a tela
# justamente quando o jogador se move é cobrar visão pelo movimento.
#
# As funções do `ScreenFX` continuam existindo — o flash de impacto e a visão do
# E usam a mesma camada. O que saiu foi ALIMENTÁ-LAS pela velocidade.
func _efeitos_de_tela(_spd: float, _sprint: bool) -> void:
	ScreenFX.set_borrao(0.0)
	ScreenFX.set_speed_lines(0.0)
	ScreenFX.set_aberracao_base(0.0)
	ScreenFX.set_vignette(0.0)

func _exit_tree() -> void:
	_ombro = null
	_spring = null
	_cam = null
