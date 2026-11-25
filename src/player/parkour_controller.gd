class_name ParkourController
extends RefCounted
# ============================================================================
#  PARKOUR — os movimentos que usam o cenário: vault, salto longo, wall run,
#  pouso de precisão, geppo (pulo duplo), escalada, mantle e travessia lateral.
#
#  03/10/2026 (fatias 2 e 3 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md): o wall run
#  mora em `corrida_na_parede.gd` (gravidade normal, sustentação pela velocidade)
#  e a escalada frontal em `escalada.gd` (agarra sozinho, escada, borda sem
#  teleporte). O "andar na superfície" (parede vira chão, energia, cambalhota de
#  saída) e a escalada antiga com mantle foram removidos de vez.
#
#  Fase 4 de docs/ARQUITETURA_PLAYER.md, segundo corte do ciclo físico. A
#  medição dizia que dava: `_is_climbing` (14 de 16 usos), `_long_jump_t`
#  (10 de 11), `_geppo_count`, `_fall_peak`, `_precision_armed`, `_was_on_floor`
#  — todos viviam dentro do `_etapa_locomocao`. Nada de fora dependia deles.
#
#  --------------------------------------------------------------- A FRONTEIRA
#  Ele NÃO escreve `velocity`. **Recebe a velocidade e devolve a velocidade** —
#  quem atribui é a etapa. É o princípio da arquitetura levado a sério: cada
#  componente é dono do seu estado, o Player combina os resultados.
#
#  Fluxo de um quadro:
#
#      avaliar()      → decide entrar no wall run ou agarrar a parede, resolve o
#                       pouso de precisão, recarrega o geppo
#      assumiu()      → "eu mando na velocidade deste quadro?"
#      velocidade()   → se assumiu: wall run ou escalada
#      aplicar_pulos()→ se não assumiu: vault, salto longo, pulo, geppo
#
#  As SONDAS de cenário (raios e colisões) vieram junto: elas só existiam para o
#  parkour. Usam o corpo do dono, que é passado no `montar_em`.
# ============================================================================

const CorridaNaParede = preload("res://src/player/corrida_na_parede.gd")
const Escalada = preload("res://src/player/escalada.gd")
const SubirDegrau = preload("res://src/player/subir_degrau.gd")

var max_geppo: int = 1      # número de pulos duplos aéreos (Geppo / Técnica do CP9)

## O wall run (fatia 2). Público para o Player ler normal, tangente e lado.
var parede = CorridaNaParede.new()
## A escalada frontal (fatia 3). Público para o Player ler normal, estado e topo.
var escalada = Escalada.new()

var _dono: CharacterBody3D = null
var _gravidade: float = 32.0
var _forca_pulo: float = 16.0

# ---- estado que atravessa quadros ----
## BUFFER do Espaço (fatia 4): apertado um pouco ANTES de a parede ficar ao
## alcance ainda entra no wall run — desde que o toque não tenha virado pulo/geppo.
const BUFFER_ESPACO := 0.15
var _buffer_espaco := 0.0
## Salto da parede pedido pelo coyote; `aplicar_pulos` o entrega no lugar do pulo.
var _salto_pendente := Vector3.ZERO
## true no quadro em que o Espaço entrou no wall run: o mesmo toque não pode
## também saltar para longe.
var _entrou_agora: bool = false
var _long_jump_t: float = 0.0   # janela de impulso horizontal (salto longo/vault)
var _geppo: int = 0             # geppos gastos desde o último apoio
var _pico_queda: float = 0.0    # maior velocidade de queda acumulada no ar
var _pouso_armado: bool = false # Espaço no ar armou o pouso de precisão
var _chao_antes: bool = false   # detecção da BATIDA no chão

func montar_em(dono: CharacterBody3D, gravidade: float, forca_pulo: float) -> void:
	_dono = dono
	_gravidade = gravidade
	_forca_pulo = forca_pulo

# ------------------------------------------------------------------ leitura
func escalando() -> bool:          return escalada.ativo
func correndo_na_parede() -> bool: return parede.ativo
func assumiu() -> bool:            return escalada.ativo or parede.ativo
func geppos() -> int:              return _geppo
func janela_impulso() -> float:    return _long_jump_t

# Impulso horizontal do salto longo / vault. Multiplica a velocidade da etapa —
# devolver o FATOR em vez de mexer na velocidade mantém a etapa como quem combina.
func bonus_velocidade() -> float:
	return 1.5 if _long_jump_t > 0.0 else 1.0

## Larga a parede sem impulso (arremesso, morte, outro sistema tomou o corpo).
func cancelar() -> void:
	parede.cancelar()
	escalada.cancelar()
	_entrou_agora = false
	_buffer_espaco = 0.0
	_salto_pendente = Vector3.ZERO

# ------------------------------------------------------------------ avaliação
# Uma chamada por quadro, ANTES de qualquer escrita em `velocity`.
func avaliar(delta: float, q: MoveFrame, no_chao: bool) -> void:
	if _long_jump_t > 0.0:
		_long_jump_t -= delta

	# POUSO DE PRECISÃO: Espaço apertado NO AR (caindo) arma um rolamento; ao
	# tocar o chão após uma queda real, o player rola e PRESERVA o embalo.
	if not no_chao:
		_pico_queda = maxf(_pico_queda, -_dono.velocity.y)
		if q.espaco_agora and _dono.velocity.y < 3.0 and not assumiu():
			_pouso_armado = true
	elif not _chao_antes:                       # acabou de tocar o chão
		if _pouso_armado and _pico_queda > 9.0:
			_long_jump_t = maxf(_long_jump_t, 0.28)
			_dono.pedir_rolamento(0.4)
			_poeira_do_pouso()
		_pico_queda = 0.0
		_pouso_armado = false
	_chao_antes = no_chao

	# WALL RUN: Espaço correndo rente a uma parede lateral (no chão OU no ar). Vem
	# antes do pulo e do geppo — com parede ao lado, o Espaço é dela.
	parede.passar_tempo(delta)
	escalada.passar_tempo(delta)
	_entrou_agora = false
	_buffer_espaco = BUFFER_ESPACO if q.espaco_agora else maxf(_buffer_espaco - delta, 0.0)
	# Ctrl + pulo é um pulo agachado: não dispara vault, escalada ou wall run.
	if q.agachar_segurado and not assumiu():
		_buffer_espaco = 0.0
		_salto_pendente = Vector3.ZERO
		if no_chao:
			_geppo = 0
		return
	if q.espaco_agora and not assumiu():
		_salto_pendente = parede.salto_coyote(no_chao)
		if _salto_pendente != Vector3.ZERO:
			_buffer_espaco = 0.0
			_pouso_armado = false
	if _buffer_espaco > 0.0 and _salto_pendente == Vector3.ZERO and not assumiu() \
			and parede.tentar_entrar(_dono, _dono.velocity):
		_entrou_agora = true
		_buffer_espaco = 0.0
		_pouso_armado = false
	# ESCALADA: no ar, indo de frente contra parede ESCALÁVEL, agarra sozinho —
	# inclusive saindo de um wall run (parede → salto → agarrar).
	elif not no_chao and not assumiu() and _salto_pendente == Vector3.ZERO \
			and escalada.tentar_agarrar(_dono, _dono.velocity, q.dir):
		_entrou_agora = true
		_pouso_armado = false

	# Recarrega as cargas do Geppo assim que apoiar no chão ou em parede/escada.
	if no_chao or assumiu():
		_geppo = 0

# ------------------------------------------------- velocidade quando ASSUMIU
func velocidade(delta: float, q: MoveFrame, vel: Vector3, vel_efetiva: float) -> Vector3:
	if parede.ativo:
		return parede.atualizar(delta, _dono, vel, _gravidade, _dono.is_on_floor(),
			q.espaco_agora and not _entrou_agora, q.soltar_agora)
	if escalada.ativo:
		if _entrou_agora:
			return -escalada.normal * Escalada.ADERENCIA   # agarrou: para o corpo
		return escalada.atualizar(delta, _dono, q, vel)
	return vel

# ------------------------------------------------- pulos, no chão e no ar
# Vault, salto longo, pulo normal e geppo. Roda no ramo em que o parkour NÃO
# assumiu — por isso recebe e devolve a velocidade em vez de escrevê-la.
func aplicar_pulos(q: MoveFrame, vel: Vector3, vel_efetiva: float,
		no_chao: bool, mult_pulo: float) -> Vector3:
	var salto_explosivo := false
	if _salto_pendente != Vector3.ZERO:
		# Coyote do wall run: o Espaço vira o salto da parede, não pulo/geppo.
		vel = _salto_pendente
		_salto_pendente = Vector3.ZERO
		return vel
	if no_chao and q.sprint and q.f > 0.0 and _long_jump_t <= 0.0 and _obstaculo_baixo_a_frente(q.dir):
		# VAULT automático: correndo contra um obstáculo BAIXO -> pula por cima.
		vel.y = _forca_pulo * 0.7
		_long_jump_t = 0.35
	elif no_chao and (q.espaco_agora or q.espaco_segurado):
		_buffer_espaco = 0.0              # o pulo (simples e correndo) é do Minecraft: MovimentoMinecraft
	elif q.espaco_agora and not no_chao and not assumiu() and _geppo < _limite_de_geppo() \
			and _pode_pagar_pulo_no_ar():
		# GEPPO (Técnica do CP9 / Pulo Duplo): chuta o ar com anel de ar comprimido!
		_buffer_espaco = 0.0
		_pagar_pulo_no_ar()
		_geppo += 1
		_pico_queda = 0.0
		_pouso_armado = false
		if q.dir.length_squared() > 0.01:
			vel.x = q.dir.x * vel_efetiva * 1.35
			vel.z = q.dir.z * vel_efetiva * 1.35
			vel.y = _forca_pulo * mult_pulo * 0.95
		else:
			vel.y = _forca_pulo * mult_pulo * 1.15
		_efeitos_do_geppo(q)
		if _dono.current_fruit_id == "bomu_bomu":
			salto_explosivo = true
	if salto_explosivo and _dono.current_fruit_id == "bomu_bomu":
		BomuFX.salto_explosivo(_dono.get_tree().current_scene, _dono.global_position, q.dir)
	return vel

# `max_geppo` é quantos pulos no ar o CORPO aguenta; a capacidade diz se ele já
# APRENDEU a pular no ar (Modo História, `CapacidadesDoJogador`). Separados para
# que um estilo que dê +1 geppo não desbloqueie o pulo duplo de um Civil.
func _limite_de_geppo() -> int:
	if _dono and "capacidades" in _dono and not _dono.capacidades.can_double_jump:
		return 0
	if _dono and "capacidades" in _dono and _dono.capacidades != null and _dono.capacidades.saltos_no_ar >= 0:
		return maxi(max_geppo, _dono.capacidades.saltos_no_ar)       # técnica Geppo: vários pulos no ar
	return max_geppo


# Energia do pulo no ar (Modo História: 30; na arena é 0 e o pulo é de graça). Sem
# energia o Espaço no ar simplesmente não faz nada, e o contador de pulos não anda.
func _custo_do_pulo_no_ar() -> float:
	if _dono and "capacidades" in _dono and _dono.capacidades != null:
		return _dono.capacidades.custo_pulo_no_ar
	return 0.0


func _pode_pagar_pulo_no_ar() -> bool:
	return float(_dono.get("energy")) + 0.001 >= _custo_do_pulo_no_ar()


func _pagar_pulo_no_ar() -> void:
	var custo := _custo_do_pulo_no_ar()
	if custo > 0.0:
		_dono.call("gastar_energia", custo)


func _efeitos_do_geppo(q: MoveFrame) -> void:
	var cena := _dono.get_tree().current_scene
	_dono.add_camera_shake(0.28)
	AudioFX.whoosh(cena, _dono.global_position, 1.35)
	AudioFX.snap(cena, _dono.global_position, 0.85)
	FxUtil.geppo_effect(cena, _dono.global_position + Vector3(0, -0.75, 0), q.dir, _dono._yaw, _dono)
	if _dono._proc_anim:
		_dono._proc_anim.trigger_recovery("Z")

# ============================================================ SONDAS DO CENÁRIO
# Vieram do Player junto com o parkour: só existiam para ele. As do wall run e da
# escalada moram em `corrida_na_parede.gd` e `escalada.gd`.

# Vault: obstáculo na altura do joelho E livre acima -> dá pra pular por cima.
func _obstaculo_baixo_a_frente(direcao: Vector3) -> bool:
	var plano := Vector3(direcao.x, 0.0, direcao.z)
	if plano.length_squared() < 0.01:
		return false
	plano = plano.normalized()
	var espaco := _dono.get_world_3d().direct_space_state
	var base := _dono.global_position
	var baixo := PhysicsRayQueryParameters3D.create(base + Vector3(0, -0.4, 0), base + Vector3(0, -0.4, 0) + plano * 1.2)
	baixo.exclude = [_dono.get_rid()]
	if espaco.intersect_ray(baixo).is_empty():
		return false                       # nada na altura do joelho -> não é vault
	# Relevo em blocos (23/10/2026, pedido do dono): correndo contra um meio bloco o
	# jogador SOBE como andando, sem pulo. Livre na altura do degrau que o `SubirDegrau`
	# sobe sozinho (só com a cápsula, Modo História) = é degrau, não obstáculo de vault.
	if _dono.get("colisor_capsula") and _livre_acima_do_degrau(plano, espaco):
		return false
	var alto := PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.7, 0), base + Vector3(0, 0.7, 0) + plano * 1.2)
	alto.exclude = [_dono.get_rid()]
	return espaco.intersect_ray(alto).is_empty()   # livre em cima -> obstáculo é baixo


## Nada à frente logo acima da altura que o `SubirDegrau` sobe (a partir dos PÉS).
func _livre_acima_do_degrau(plano: Vector3, espaco: PhysicsDirectSpaceState3D) -> bool:
	var forma := _dono.get("_colisor") as CollisionShape3D
	if forma == null or not (forma.shape is CapsuleShape3D):
		return false
	var pes := forma.global_position.y - (forma.shape as CapsuleShape3D).height * 0.5
	var de := Vector3(_dono.global_position.x, pes + SubirDegrau.ALTURA + 0.02, _dono.global_position.z)
	var raio := PhysicsRayQueryParameters3D.create(de, de + plano * 1.2)
	raio.exclude = [_dono.get_rid()]
	return espaco.intersect_ray(raio).is_empty()

func _poeira_do_pouso() -> void:
	var mundo := _dono.get_tree().current_scene
	if mundo == null:
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
	var jato := FxUtil.particles(24, 0.5, true, pm, FxUtil.grain(0.3), 1.0)
	mundo.add_child(jato)
	jato.global_position = _dono.global_position + Vector3(0, -0.7, 0)
	FxUtil.autofree(jato, 0.8)
