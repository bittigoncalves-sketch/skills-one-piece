class_name ParkourController
extends RefCounted
# ============================================================================
#  PARKOUR — os 8 movimentos que usam o cenário: vault, salto longo, wall run,
#  pouso de precisão, geppo (pulo duplo), escalada, mantle e travessia lateral.
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
#      avaliar()      → sonda paredes, decide escalar/correr na parede,
#                       resolve o pouso de precisão, recarrega o geppo
#      assumiu()      → "eu mando na velocidade deste quadro?"
#      velocidade()   → se assumiu: escalada ou wall run
#      aplicar_pulos()→ se não assumiu: vault, salto longo, pulo, geppo
#
#  As SONDAS de cenário (raios e colisões) vieram junto: elas só existiam para o
#  parkour. Usam o corpo do dono, que é passado no `montar_em`.
# ============================================================================

const CLIMB_SPEED := 4.5
const CLIMB_STICK_SPEED := 1.0
const CLIMB_WALL_NORMAL_MAX_Y := 0.2

## ANDAR NA SUPERFÍCIE. `ADERENCIA` é a pressão contra a superfície que mantém o
## contato de colisão entre quadros — mesma ideia do `CLIMB_STICK_SPEED`, e pelo
## mesmo motivo: sem ela um quadro sem toque solta o jogador.
const PAREDE_ADERENCIA := 2.5
## Alcance do raio que procura chão sob os pés. Generoso de propósito: o corpo
## flutua um pouco em relação à superfície, e um alcance curto perde o contato.
const PAREDE_ALCANCE := 2.0
## Quanto tempo sem achar superfície antes de soltar. Ver a nota da folga.
const PAREDE_FOLGA := 0.35
## Duração do rolamento no ar. Curto: é um floreio de saída, não uma acrobacia
## que tira o controle do jogador.
const ROLAMENTO_AR_DURACAO := 0.55
const PAREDE_PULO_FORA := 7.0    # empurrão para FORA da superfície ao cancelar
const PAREDE_PULO_CIMA := 6.0    # e para cima, para o cancelamento ler como pulo

var max_geppo: int = 1      # número de pulos duplos aéreos (Geppo / Técnica do CP9)

var _dono: CharacterBody3D = null
var _gravidade: float = 32.0
var _forca_pulo: float = 16.0

# ---- estado que atravessa quadros ----
var _escalando: bool = false

## ANDAR NA SUPERFÍCIE (2026-08-27) — substitui a escalada.
##
## ⚠️ A DIFERENÇA NÃO É COSMÉTICA. A escalada era um estado SEGURADO: soltar o
## espaço largava a parede. Este é um estado LIGADO: uma vez que entra, fica —
## o jogador anda pela superfície com WASD como andaria no chão, e cancela
## PULANDO. É o que o dono pediu ("não precisa ficar segurando as teclas").
##
## O preço é ENERGIA, drenada por segundo (o Player cobra; aqui só se declara o
## estado). Sem preço, andar na parede seria estritamente melhor que andar no
## chão e o chão deixaria de existir como decisão.
var _na_parede: bool = false
var _normal_parede: Vector3 = Vector3.ZERO
## Trava de um quadro: entrar e sair usam a MESMA tecla (espaço). Sem ela, o
## mesmo toque que gruda desgruda no quadro seguinte.
var _carencia_parede: float = 0.0
## Há quanto tempo o raio não acha superfície sob os pés. Ver a nota da folga.
var _folga_sem_chao: float = 0.0
var _base_sup: Basis = Basis.IDENTITY

## Tempo restante do ROLAMENTO NO AR — a cambalhota que sai ao largar a
## superfície. Pedido do dono: braços mirando os pés, pernas agachadas, cabeça
## indo ao joelho, corpo dobrado e GIRANDO.
var _rolando_no_ar: float = 0.0
## true no quadro em que o espaço foi usado para largar a superfície. Ver a nota
## em `aplicar_pulos`.
var _consumiu_espaco: bool = false
var _long_jump_t: float = 0.0   # janela de impulso horizontal (salto longo/vault)
var _geppo: int = 0             # geppos gastos desde o último apoio
var _pico_queda: float = 0.0    # maior velocidade de queda acumulada no ar
var _pouso_armado: bool = false # Espaço no ar armou o pouso de precisão
var _chao_antes: bool = false   # detecção da BATIDA no chão

# ---- resultado da sondagem DESTE quadro ----
var _parede_frontal: Vector3 = Vector3.ZERO   # normal da parede escalável
var _parede_lateral: Vector3 = Vector3.ZERO   # normal da parede do wall run
var _correndo_parede: bool = false

func montar_em(dono: CharacterBody3D, gravidade: float, forca_pulo: float) -> void:
	_dono = dono
	_gravidade = gravidade
	_forca_pulo = forca_pulo

# ------------------------------------------------------------------ leitura
func escalando() -> bool:          return _escalando
func na_parede() -> bool:          return _na_parede
func normal_da_parede() -> Vector3: return _normal_parede
func correndo_na_parede() -> bool: return _correndo_parede
func assumiu() -> bool:            return _escalando or _correndo_parede or _na_parede
func geppos() -> int:              return _geppo
func janela_impulso() -> float:    return _long_jump_t
func parede_frontal() -> Vector3:  return _parede_frontal   # o facing usa p/ virar contra a parede

# Impulso horizontal do salto longo / vault. Multiplica a velocidade da etapa —
# devolver o FATOR em vez de mexer na velocidade mantém a etapa como quem combina.
func bonus_velocidade() -> float:
	return 1.5 if _long_jump_t > 0.0 else 1.0

# ------------------------------------------------------------------ avaliação
# Uma chamada por quadro, ANTES de qualquer escrita em `velocity`.
func avaliar(delta: float, q: MoveFrame, no_chao: bool) -> void:
	if _long_jump_t > 0.0:
		_long_jump_t -= delta

	# POUSO DE PRECISÃO: Espaço apertado NO AR (caindo) arma um rolamento; ao
	# tocar o chão após uma queda real, o player rola e PRESERVA o embalo.
	if not no_chao:
		_pico_queda = maxf(_pico_queda, -_dono.velocity.y)
		if q.espaco_agora and _dono.velocity.y < 3.0 and not _escalando:
			_pouso_armado = true
	elif not _chao_antes:                       # acabou de tocar o chão
		if _pouso_armado and _pico_queda > 9.0:
			_long_jump_t = maxf(_long_jump_t, 0.28)
			_dono.pedir_rolamento(0.4)
			_poeira_do_pouso()
		_pico_queda = 0.0
		_pouso_armado = false
	_chao_antes = no_chao

	# ANDAR NA SUPERFÍCIE — no lugar da escalada.
	#
	# ENTRA com UM toque de espaço encostando numa parede escalável, no ar.
	# FICA sem segurar nada. SAI pulando (o mesmo espaço), ou se a energia
	# acabar, ou se a superfície sumir debaixo dos pés.
	_carencia_parede = maxf(_carencia_parede - delta, 0.0)
	_rolando_no_ar = maxf(_rolando_no_ar - delta, 0.0)
	_parede_frontal = _normal_da_parede_escalavel(q.dir)

	if _na_parede:
		# ⚠️ O PULO CANCELA. É a única saída voluntária, e é intencional: com a
		# gravidade da superfície mandando, "soltar a tecla" não significa nada.
		if q.espaco_agora and _carencia_parede <= 0.0:
			_soltar_da_parede(true)
		elif not _dono.tem_energia_de_parede():
			_soltar_da_parede(false)      # acabou a energia: cai
		else:
			# ⚠️ A PERMANÊNCIA NÃO PODE DEPENDER DE TECLA. `_parede_frontal` vem de
			# `_normal_da_parede_escalavel(q.dir)` — sem direção no teclado ela é
			# ZERO. Usá-la como fallback obrigava o jogador a seguir segurando W,
			# que é exatamente o que esta mecânica veio eliminar.
			#
			# Agora só o que está SOB OS PÉS decide, e ele não olha para o
			# teclado.
			var atual := _superficie_sob_os_pes()
			if atual != Vector3.ZERO:
				_normal_parede = atual
				_folga_sem_chao = 0.0
			else:
				# ⚠️ E UMA FOLGA antes de soltar. A superfície some por um quadro
				# em quina, degrau ou quando a colisão empurra o corpo um dedo
				# para fora — soltar no primeiro quadro sem raio derrubava o
				# jogador em situações em que ele claramente ainda estava lá.
				_folga_sem_chao += delta
				if _folga_sem_chao > PAREDE_FOLGA:
					_soltar_da_parede(false)
	elif q.espaco_agora and not no_chao and _parede_frontal != Vector3.ZERO \
			and _carencia_parede <= 0.0 and _dono.tem_energia_de_parede():
		_na_parede = true
		_normal_parede = _parede_frontal
		_carencia_parede = 0.25
		_folga_sem_chao = 0.0
		_geppo = 0

	# A escalada antiga fica desligada, mas o campo continua para o wall run e o
	# mantle, que ainda consultam `_escalando`.
	_escalando = false

	# WALL RUN: no ar, CORRENDO rente a uma parede LATERAL -> corre por ela.
	_parede_lateral = _normal_da_parede_lateral(q.dir) if not _escalando else Vector3.ZERO
	_correndo_parede = not _escalando and not no_chao and q.sprint and q.f > 0.0 \
		and _parede_lateral != Vector3.ZERO and _dono.velocity.y < 5.0

	# Recarrega as cargas do Geppo assim que apoiar no chão ou em parede/escada.
	if no_chao or _escalando or _correndo_parede:
		_geppo = 0

# ------------------------------------------------- velocidade quando ASSUMIU
func velocidade(delta: float, q: MoveFrame, vel: Vector3, vel_efetiva: float) -> Vector3:
	if _na_parede:
		# ⚠️ A SUPERFÍCIE VIRA O CHÃO — E ISSO EXIGE UMA BASE PRÓPRIA.
		#
		# A primeira versão projetava `q.dir` no plano da parede. `q.dir` é
		# HORIZONTAL (vem do yaw da câmera), então numa parede vertical o W é
		# exatamente a componente que aponta PARA DENTRO — e a projeção a
		# anulava. Resultado medido: só A e D funcionavam, que foi o relato.
		#
		# Agora o movimento é montado na base DA SUPERFÍCIE: a normal é o "para
		# cima", a frente é a da câmera projetada no plano, e a direita sai do
		# produto vetorial. Aí W anda parede acima e A/D andam de lado, que é o
		# que "o bloco é o chão" quer dizer.
		var b := _base_da_superficie(q)
		_base_sup = b
		var n := _normal_parede
		var frente: Vector3 = -b.z
		var direita: Vector3 = b.x

		var mov := frente * q.f + direita * q.r
		if mov.length_squared() > 1.0:
			mov = mov.normalized()
		# O que sobraria "para dentro" vira pressão de contato: sem ela, um
		# quadro sem colisão soltaria o jogador.
		return mov * vel_efetiva + (-n * PAREDE_ADERENCIA)
	if _escalando:
		# Uma leve pressão contra a parede preserva o contato de colisão entre
		# quadros; sem isso, ao mover apenas no eixo Y a escalada terminaria logo.
		# W sobe / S desce, parado = segura; A/D faz travessia lateral.
		var tang := _parede_frontal.cross(Vector3.UP).normalized()
		vel.x = -_parede_frontal.x * CLIMB_STICK_SPEED + tang.x * q.r * CLIMB_SPEED * 0.8
		vel.z = -_parede_frontal.z * CLIMB_STICK_SPEED + tang.z * q.r * CLIMB_SPEED * 0.8
		vel.y = CLIMB_SPEED * clampf(q.f, -1.0, 1.0)
		# MANTLE: chegou ao TOPO (cabeça livre acima da beirada) e empurra pra
		# cima (W) -> impulso pra cima + pra frente e larga a parede.
		if q.f > 0.1 and _cabeca_livre_da_parede(_parede_frontal):
			vel = -_parede_frontal * 6.0 + Vector3.UP * (_forca_pulo * 0.8)
			_escalando = false
			_long_jump_t = 0.25
		return vel

	# WALL RUN: quase sem gravidade + corre ao longo da parede; Espaço = pula pra longe.
	vel.y = maxf(vel.y - _gravidade * 0.12 * delta, -1.5)   # "cola" e cai devagar
	var tangente := _parede_lateral.cross(Vector3.UP).normalized()
	if tangente.dot(q.frente) < 0.0:
		tangente = -tangente                                 # sentido = pra onde o player olha
	vel.x = tangente.x * vel_efetiva - _parede_lateral.x * 2.0   # corre + encosta na parede
	vel.z = tangente.z * vel_efetiva - _parede_lateral.z * 2.0
	if q.espaco_agora:
		vel = _parede_lateral * 9.0 + Vector3.UP * (_forca_pulo * 0.85)   # empurra PRA LONGE
		_long_jump_t = 0.3
	return vel

# ------------------------------------------------- pulos, no chão e no ar
# Vault, salto longo, pulo normal e geppo. Roda no ramo em que o parkour NÃO
# assumiu — por isso recebe e devolve a velocidade em vez de escrevê-la.
func aplicar_pulos(q: MoveFrame, vel: Vector3, vel_efetiva: float,
		no_chao: bool, mult_pulo: float) -> Vector3:
	# ⚠️ O ESPAÇO QUE LARGOU A SUPERFÍCIE JÁ FOI GASTO. Sem esta saída, o mesmo
	# toque cancelava a parede E consumia um pulo duplo no mesmo quadro — o
	# jogador era punido por usar o cancelamento que a mecânica exige. Zerar o
	# `_geppo` na saída não bastava: `aplicar_pulos` roda DEPOIS e gastava de
	# novo.
	if _consumiu_espaco:
		_consumiu_espaco = false
		return vel
	if no_chao and q.sprint and q.f > 0.0 and _long_jump_t <= 0.0 and _obstaculo_baixo_a_frente(q.dir):
		# VAULT automático: correndo contra um obstáculo BAIXO -> pula por cima.
		vel.y = _forca_pulo * 0.7
		_long_jump_t = 0.35
	elif q.espaco_agora and no_chao:
		# Salto longo SÓ na batida do Espaço correndo (evita velocidade infinita).
		if q.sprint and q.f > 0.0:
			vel.y = _forca_pulo * 0.95     # SALTO LONGO (Shift+Espaço)
			_long_jump_t = 0.55
		else:
			vel.y = _forca_pulo * mult_pulo   # pulo normal
	elif q.espaco_segurado and no_chao:
		vel.y = _forca_pulo * mult_pulo       # segurar Espaço = pulo normal
	elif q.espaco_agora and not no_chao and not _escalando and not _correndo_parede and _geppo < max_geppo:
		# GEPPO (Técnica do CP9 / Pulo Duplo): chuta o ar com anel de ar comprimido!
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
	return vel

func _efeitos_do_geppo(q: MoveFrame) -> void:
	var cena := _dono.get_tree().current_scene
	_dono.add_camera_shake(0.28)
	AudioFX.whoosh(cena, _dono.global_position, 1.35)
	AudioFX.snap(cena, _dono.global_position, 0.85)
	FxUtil.geppo_effect(cena, _dono.global_position + Vector3(0, -0.75, 0), q.dir, _dono._yaw, _dono)
	if _dono._proc_anim:
		_dono._proc_anim.trigger_recovery("Z")

# ============================================================ SONDAS DO CENÁRIO
# Vieram do Player junto com o parkour: só existiam para ele.

# Usa as colisões do último movimento. Isso evita RayCast extra e faz a escalada
# funcionar em qualquer StaticBody3D, inclusive os blocos do mapa.
## A base da SUPERFÍCIE: `y` = a normal (o "para cima"), `-z` = a frente, `x` = a
## direita. Uma fonte só, usada pelo movimento E pela animação — o animador
## precisa da mesma decomposição para saber quanto é "andar para frente".
func _base_da_superficie(q: MoveFrame) -> Basis:
	var n := _normal_parede
	var frente := q.frente - n * q.frente.dot(n)
	if frente.length_squared() <= 0.001:
		# A câmera olha direto para a parede: a frente projetada degenera.
		# "Para cima da parede" é a escolha natural — é para onde alguém andando
		# nela encara.
		frente = Vector3.UP - n * Vector3.UP.dot(n)
	if frente.length_squared() <= 0.001:
		frente = Vector3.FORWARD - n * Vector3.FORWARD.dot(n)
	return Basis.looking_at(frente.normalized(), n)


## A última base calculada. O Player usa para traduzir a velocidade da parede
## para o plano que o animador entende.
func base_da_superficie() -> Basis:
	return _base_sup


func rolando_no_ar() -> bool:
	return _rolando_no_ar > 0.0


## 0 no começo do rolamento no ar, 1 no fim. É o que o Player usa para girar o
## corpo — a pose encolhida sozinha pareceria um agachamento no ar.
func giro_do_rolamento_no_ar() -> float:
	if _rolando_no_ar <= 0.0:
		return 0.0
	return clampf(1.0 - (_rolando_no_ar / ROLAMENTO_AR_DURACAO), 0.0, 1.0)


## Solta a superfície. `pulando` = saída voluntária: ganha um empurrão para fora
## e para cima, que é o que faz o cancelamento PARECER um pulo em vez de um
## escorregão.
func _soltar_da_parede(pulando: bool) -> void:
	if not _na_parede:
		return
	_na_parede = false
	_carencia_parede = 0.25
	if pulando and _dono:
		_dono.velocity = _normal_parede * PAREDE_PULO_FORA + Vector3.UP * PAREDE_PULO_CIMA
		# ⚠️ NÃO CONSOME PULO DUPLO. Sair da superfície é a saída da mecânica,
		# não um salto aéreo: gastar o geppo aqui puniria o jogador por usar o
		# cancelamento que a própria mecânica exige. Zerar (em vez de só não
		# incrementar) devolve o recurso, como qualquer apoio devolve.
		_geppo = 0
		_rolando_no_ar = ROLAMENTO_AR_DURACAO
		_consumiu_espaco = true
	_normal_parede = Vector3.ZERO


## O que está sob os PÉS enquanto se anda na superfície — permite virar de uma
## face para outra (parede → teto) sem soltar.
func _superficie_sob_os_pes() -> Vector3:
	if _dono == null or _normal_parede == Vector3.ZERO:
		return Vector3.ZERO
	var espaco := _dono.get_world_3d().direct_space_state
	# Parte de um ponto um pouco AFASTADO da superfície: um raio que nasce dentro
	# do sólido não reporta acerto, e o corpo às vezes encosta.
	var de: Vector3 = _dono.global_position + _normal_parede * 0.35
	var par := PhysicsRayQueryParameters3D.create(de, de - _normal_parede * PAREDE_ALCANCE)
	par.exclude = [_dono.get_rid()]
	var h := espaco.intersect_ray(par)
	return h["normal"] if not h.is_empty() else Vector3.ZERO


func _normal_da_parede_escalavel(direcao: Vector3) -> Vector3:
	for i in _dono.get_slide_collision_count():
		var colisao := _dono.get_slide_collision(i)
		var normal := colisao.get_normal()
		if absf(normal.y) <= CLIMB_WALL_NORMAL_MAX_Y and direcao.dot(normal) < -0.15:
			return normal
	return Vector3.ZERO

func _normal_da_parede_lateral(direcao: Vector3) -> Vector3:
	var plano := Vector3(direcao.x, 0.0, direcao.z)
	if plano.length_squared() < 0.01:
		return Vector3.ZERO
	plano = plano.normalized()
	var lado := plano.cross(Vector3.UP)      # perpendicular horizontal
	var espaco := _dono.get_world_3d().direct_space_state
	var base := _dono.global_position
	for s in [lado, -lado]:
		var par := PhysicsRayQueryParameters3D.create(base, base + s * 0.85)
		par.exclude = [_dono.get_rid()]
		var hit := espaco.intersect_ray(par)
		if not hit.is_empty():
			var n: Vector3 = hit["normal"]
			if absf(n.y) < 0.3:              # parede vertical (não chão/teto)
				return n
	return Vector3.ZERO

# Mantle: true quando a CABEÇA já passou do topo da parede (raio à altura da
# cabeça, em direção à parede, não bate em nada) -> dá pra subir na beirada.
func _cabeca_livre_da_parede(normal_parede: Vector3) -> bool:
	var espaco := _dono.get_world_3d().direct_space_state
	var de := _dono.global_position + Vector3(0, 0.95, 0)
	var par := PhysicsRayQueryParameters3D.create(de, de - normal_parede * 0.9)  # -normal = pra parede
	par.exclude = [_dono.get_rid()]
	return espaco.intersect_ray(par).is_empty()

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
	var alto := PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.7, 0), base + Vector3(0, 0.7, 0) + plano * 1.2)
	alto.exclude = [_dono.get_rid()]
	return espaco.intersect_ray(alto).is_empty()   # livre em cima -> obstáculo é baixo

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
