class_name DisparoSustentado
extends RefCounted
# ============================================================================
#  DISPARO SUSTENTADO — a rajada Z (Mera/Hie) e a pistola da Yami.
#
#  Passo 6a de docs/AUDITORIA_FASE6.md. As duas mecânicas ficaram no MESMO
#  componente porque não são vizinhas por acaso: dividem o **canal de bala**
#  (`_net_bullet_req` → `_do_server_bullet` → `_net_bullet_play`), pedem bala
#  pelo mesmo caminho e usam a mesma pistola do rig.
#
#  Separá-las em dois arquivos criaria dois donos para o mesmo pedido — o
#  problema que esta refatoração inteira combate.
#
#  ----------------------------------------------------------- POR QUE 6a
#  O plano original chamava de "6a" extrair só o estado CONTIDO (`_cast_token`,
#  `_rapid_*`, `_yami_shot_cooldown`, `suppression_timer`). Isso seria
#  refatoração de fachada: timers soltos não formam componente coerente, e o
#  resultado seria um arquivo sem responsabilidade própria.
#
#  O corte que se sustenta é por MECÂNICA. Medido antes de mover: `_rapid_fire`,
#  `_rapid_count`, `_rapid_t`, `_yami_pistol_active`, `_yami_shot_cooldown` e
#  `_bullet_side` não são usados por NENHUM arquivo fora do `Player.gd`.
#
#  ---------------------------------------------------------------- FRONTEIRA
#  Ele é dono do estado das duas mecânicas e **não escreve estado alheio**:
#
#    `_dono.gastar_energia(...)`     em vez de mexer em `energy` (é da Fase 8)
#    `_dono.pedir_bala_simples(...)` o canal de rede fica no Player (RPC resolve
#                                    por caminho de nó)
#    `_dono.pedir_coice_de_arma()`   em vez de escrever `_gun_recoil`
#    `_dono.aplicar_mira(...)`       em vez de escrever `_yaw`/`_pitch`
#    `_dono.add_camera_shake(...)`   já era pedido desde a Fase 2
#
#  ⚠️ Nunca chama `is_multiplayer_authority()`: a autoridade NÃO desce para
#  componentes criados no `_ready()` (medido na Fase 5: pai=7, filho=1). Ele
#  recebe a resposta por parâmetro.
# ============================================================================

const INTERVALO := 0.09     # cadência da rajada Z
const MAX_BALAS := 16       # a rajada para sozinha depois disto
const YAMI_CADENCIA := 0.35 # tempo entre tiros da pistola da Yami

var _dono: Node = null

# ---- rajada Z (Mera Mera / Hie Hie): segura para atirar ----
var _rajada: bool = false
var _rajada_n: int = 0      # balas já disparadas nesta rajada
var _rajada_t: float = 0.0  # tempo até a próxima bala

# ---- pistola da Yami: liga/desliga por toggle ----
var _yami: bool = false
var _yami_cd: float = 0.0

# Alterna a mão a cada tiro (0 = esquerda, 1 = direita). É das duas mecânicas:
# a pistola existe nas DUAS mãos e o disparo alterna.
var _mao: int = 0

func montar_em(dono: Node) -> void:
	_dono = dono

# ------------------------------------------------------------------ leitura
func rajada_ativa() -> bool: return _rajada
func yami_ativa() -> bool:   return _yami
# "Este corpo está com pistola na mão?" — é o que decide a visibilidade dela no
# rig e vários portões (soco, dash, troca de slot).
func armado() -> bool:       return _rajada or _yami

# --------------------------------------------------------------------- ações
func iniciar_rajada() -> void:
	_rajada = true
	_rajada_n = 0
	_rajada_t = 0.0

func parar_rajada() -> void:
	_rajada = false

# A pistola da Yami é TOGGLE: a mesma tecla saca e guarda. Devolve o estado novo
# para quem quiser avisar o jogador.
func alternar_yami() -> bool:
	_yami = not _yami
	return _yami

func desligar_yami() -> void:
	_yami = false

# --------------------------------------------------------------- rajada Z
# Uma bala a cada `INTERVALO`, enquanto houver energia e não passar de
# `MAX_BALAS`. Cada bala custa energia — é o que impede segurar o botão para
# sempre.
func tick_rajada(delta: float, custo_por_bala: float) -> void:
	if not _rajada:
		return
	if _dono.energy < custo_por_bala:
		_rajada = false                       # sem energia -> encerra a rajada
		return
	_rajada_t -= delta
	if _rajada_t > 0.0:
		return
	_rajada_t = INTERVALO
	_dono.gastar_energia(custo_por_bala)
	pedir_bala()
	_dono.add_camera_shake(0.12)              # Camera Feel: coice de cada tiro
	_dono.pedir_coice_de_arma()               # coice visual do braço (mira)
	_rajada_n += 1
	if _rajada_n >= MAX_BALAS:
		_rajada = false                       # acabou o pente da rajada

# UMA bala da rajada.
#
# MIRA CORRIGIDA: acha o ponto no mundo sob a mira (raycast) e faz a bala
# CONVERGIR nele partindo do cano da pistola — assim ela acerta exatamente onde
# a mira aponta, e não paralelo a ela.
func pedir_bala() -> void:
	var origem: Vector3 = _dono._mira.boca_da_pistola(_dono._pistols, _mao, _dono._cam)   # alterna esquerda/direita
	_mao = 1 - _mao
	var alvo: Vector3 = _dono._mira.ponto_de_mira(_dono._cam, _dono.aim_assist)
	var aim := alvo - origem
	if aim.length() < 0.01:
		aim = -_dono._cam.global_transform.basis.z
	aim = aim.normalized()
	origem += aim * 0.25                            # sai à frente do cano
	_dono.pedir_bala_simples(aim, origem)

# ----------------------------------------------------- pistola da Yami
# Botão direito MIRA (puxa para o alvo mais próximo), botão esquerdo ATIRA.
# `yaw`/`pitch` entram por parâmetro: quem é dono deles é o Player (Fase 2).
func atualizar_yami(delta: float, yaw: float, pitch: float) -> void:
	if _yami_cd > 0.0:
		_yami_cd = maxf(_yami_cd - delta, 0.0)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var alvo: Node3D = _dono._mira.mais_proximo(35.0)
		if alvo and is_instance_valid(alvo):
			var para: Vector3 = (alvo.global_position + Vector3.UP * 0.9) - _dono._cam.global_position
			var h := Vector2(para.x, para.z).length()
			# ⚠️ Números DIFERENTES dos da mira assistida da Buki, de propósito:
			# aqui o puxão é mais forte (15 contra 9) e o pitch abre bem mais
			# (±1,3 contra −1,2..0,5), porque a Yami mira alvo aéreo.
			var novo_yaw := lerp_angle(yaw, atan2(-para.x, -para.z), 15.0 * delta)
			var novo_pitch := lerpf(pitch, clampf(atan2(para.y, h), -1.3, 1.3), 15.0 * delta)
			_dono.aplicar_mira(novo_yaw, novo_pitch, delta, 20.0)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _yami_cd <= 0.0:
		_yami_cd = YAMI_CADENCIA
		_dono.pedir_coice_de_arma()
		var frente: Vector3 = -_dono._cam.global_transform.basis.z
		var origem: Vector3 = _dono.global_position + Vector3.UP * 1.2 + frente * 0.8
		var alvo_pt: Vector3 = _dono._mira.ponto_de_mira(_dono._cam, _dono.aim_assist)
		# ⚠️ A bala já foi criada DIRETO aqui, sem passar pelo servidor — e a
		# `DamageZone` só machuca no servidor. Sintoma relatado jogando: o tiro
		# da pistola da Yami saindo do CLIENTE não feria o jogador do servidor
		# (no host funcionava, porque lá o local JÁ é o servidor).
		# Ver docs/erros.md, 2026-08-10.
		_dono.pedir_bala_simples((alvo_pt - origem).normalized(), origem)
