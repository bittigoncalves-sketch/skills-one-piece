class_name VooFoguete
extends RefCounted
# ============================================================================
#  BLAST OFF — o voo curto da Rocket (tecla F), Modo História.
#
#  Plano: `docs/frutas/rocket.md` e o vídeo do dono (22/09/2026). Medido nele:
#  o corpo vira de frente, dá um MORTAL PARA TRÁS subindo (~0,2–0,3 s), estica na
#  horizontal de bruços e plana devagar, envolto em explosões, por vários segundos.
#  O dono escolheu ~3 s de planagem e **pouso suave** no fim (sem dano de queda).
#
#  30/09/2026 — decisões do dono depois de jogar:
#    * **o MOUSE pilota, em 3D.** O rumo persegue a mira da câmera (sobe e desce
#      junto), com curva limitada — faz arco, não vira na hora. O WASD não mexe mais
#      no rumo. Antes o WASD desviava só no plano e girar a câmera não fazia nada
#      (medido: 0° de desvio com a câmera a 90°), por isso "não dava para virar".
#    * **o jogador VIRA o foguete** do impulso até tocar o chão (`forma_de_foguete`);
#      golpe no ar, dano, morte ou perder a fruta DESFAZEM a forma e o corpo desce
#      pelo pouso suave. A malha mora em `src/effects/forma_de_foguete.gd`.
#
#  ------------------------------------------------------------------ AS FASES
#    IMPULSO   sobe rápido em arco (0,30 s) — o mortal; o corpo está comprometido
#    PLANANDO  ~3 s seguindo a MIRA; encostar no chão mergulhando encerra
#    POUSANDO  retrofoguete: desce rápido longe do chão e freia perto dele
#
#  ---------------------------------------------------------------- A FRONTEIRA
#  Igual à do `DashController`: este componente **não escreve `velocity`**. Ele
#  devolve a velocidade que quer e quem combina é a etapa de locomoção do Player —
#  a única que escreve velocidade (docs/MOVIMENTO.md §1).
#
#  Dano recebido, morte, menu ou perder a fruta encerram o voo pelo caminho do
#  pouso suave, não por queda seca: acabar o voo não pode matar de queda.
# ============================================================================

## O chão de verdade (corpo que toma dano não é chão): a mesma conta dos golpes.
const MIRA := preload("res://src/combat/mira_de_rocket.gd")

## Subida do mortal: quanto tempo e com que velocidade vertical.
const IMPULSO := 0.30
const VELOCIDADE_DE_SUBIDA := 14.0
## Planagem: velocidade ao longo do rumo.
const VELOCIDADE := 9.0
## A virada da subida para a planagem: a velocidade faz ARCO nesse tempo em vez de dobrar
## num quadro. Medido antes (30/09/2026): no 1º quadro da planagem a velocidade virava
## ~77° de uma vez e o nariz do foguete ficava 78° fora da direção em que o corpo ia.
const ARCO := 0.30
## Curva do foguete: radianos por segundo que o rumo gira atrás da mira. Velocidade
## ANGULAR constante (não exponencial): 90° levam ~0,5 s, meia-volta ~1 s.
const GIRO := 3.2
## Até onde o nariz aponta para cima ou para baixo (60°). A câmera vai mais longe; o
## foguete não, senão olhar para o chão viraria parafuso.
const INCLINACAO_MAXIMA := 1.047
## Pouso (retrofoguete): a descida é proporcional à altura, entre os dois limites. O
## mínimo fica ABAIXO dos 2 m/s do `FallImpactController`: o toque não racha o chão.
const DESCIDA_MAXIMA := 10.0
const DESCIDA_MINIMA := 1.8
const FREIO := 1.5
## Colisor de 1,6 m centrado na origem: o pé fica 0,8 m abaixo dela.
const MEIA_ALTURA := 0.8
## Segurança: se nada tocar o chão (buraco), o pouso desiste e devolve o corpo à física.
const POUSO_MAXIMO := 8.0

enum Fase { PARADO, IMPULSO, PLANANDO, POUSANDO }

var _dono: Node3D = null
var _fase: Fase = Fase.PARADO
var _t := 0.0
var _rumo := Vector3.FORWARD
var _duracao_da_planagem := 3.0
var _forma := false


func montar_em(dono: Node3D) -> void:
	_dono = dono


func ativo() -> bool:
	return _fase != Fase.PARADO


## Voando de verdade (impulso ou planagem): é quando a gravidade não vale e a pose
## do voo manda. No pouso o corpo já está descendo para o chão.
func no_ar() -> bool:
	return _fase == Fase.IMPULSO or _fase == Fase.PLANANDO


func fase() -> String:
	return ["parado", "impulso", "planando", "pousando"][_fase]


func tempo() -> float:
	return _t


## Para onde o foguete aponta agora (3D, unitário).
func rumo() -> Vector3:
	return _rumo


## O jogador é o foguete agora? Do impulso até tocar o chão, se nada desfez a forma.
func forma_de_foguete() -> bool:
	return _forma and _fase != Fase.PARADO


## Começa o voo apontando para `mira` (a frente da câmera). `duracao` vem da ficha.
func comecar(mira: Vector3, duracao: float) -> void:
	_rumo = Vector3.FORWARD
	_rumo = _alvo(mira)
	_duracao_da_planagem = maxf(duracao, 0.1)
	_fase = Fase.IMPULSO
	_t = 0.0
	_forma = true


## Encerra o voo PELO POUSO (nunca em queda livre): quem acabou de voar não morre
## de queda porque a técnica terminou.
func pousar() -> void:
	if _fase == Fase.IMPULSO or _fase == Fase.PLANANDO:
		_fase = Fase.POUSANDO
		_t = 0.0


## Golpe no ar, dano, morte ou perder a fruta: o corpo volta a ser gente e desce pelo
## pouso suave. Sem voo em curso não faz nada.
func desfazer_forma() -> void:
	if not ativo():
		return
	_forma = false
	pousar()


func cancelar() -> void:
	_fase = Fase.PARADO
	_t = 0.0
	_forma = false


## A velocidade deste quadro. `mira` é a frente da câmera em espaço de mundo (com a
## inclinação); `no_chao` vem do corpo.
func velocidade(delta: float, mira: Vector3, no_chao: bool) -> Vector3:
	_t += delta
	match _fase:
		Fase.IMPULSO:
			_girar(_alvo(mira), delta)
			if _t >= IMPULSO:
				_fase = Fase.PLANANDO
				_t = 0.0
			return _velocidade_da_subida()
		Fase.PLANANDO:
			_girar(_alvo(mira), delta)
			# Mergulhou até o chão: chegou. Sem isto o foguete arrastaria a barriga no
			# piso até o fim do tempo.
			if no_chao and _rumo.y < 0.0 and _t > 0.1:
				cancelar()
				return _plano(_rumo) * VELOCIDADE * 0.2
			if _t >= _duracao_da_planagem:
				_fase = Fase.POUSANDO
				_t = 0.0
			if _t < ARCO:
				return _velocidade_da_subida().lerp(_rumo * VELOCIDADE, smoothstep(0.0, ARCO, _t))
			return _rumo * VELOCIDADE
		Fase.POUSANDO:
			if no_chao or _t >= POUSO_MAXIMO:
				cancelar()
				return _plano(_rumo) * VELOCIDADE * 0.2
			var altura := _altura_do_chao()
			var descida := DESCIDA_MAXIMA if is_inf(altura) \
					else clampf(altura * FREIO, DESCIDA_MINIMA, DESCIDA_MAXIMA)
			return _plano(_rumo) * VELOCIDADE * 0.3 + Vector3.DOWN * descida
	return Vector3.ZERO


func _velocidade_da_subida() -> Vector3:
	return _plano(_rumo) * VELOCIDADE * 0.35 + Vector3.UP * VELOCIDADE_DE_SUBIDA


## O rumo que a mira pede: a mesma direção no plano, com a inclinação limitada. Olhando
## reto para cima ou para baixo o plano some — aí vale o rumo que já existia.
func _alvo(mira: Vector3) -> Vector3:
	if mira.length_squared() < 0.0001:
		return _rumo
	var m := mira.normalized()
	var plano := Vector3(m.x, 0.0, m.z)
	if plano.length_squared() < 0.0001:
		plano = _plano(_rumo)
	plano = plano.normalized()
	var inclinacao := clampf(asin(clampf(m.y, -1.0, 1.0)), -INCLINACAO_MAXIMA, INCLINACAO_MAXIMA)
	return (plano * cos(inclinacao) + Vector3.UP * sin(inclinacao)).normalized()


## Gira o rumo em direção a `para` com velocidade angular constante (`GIRO`).
func _girar(para: Vector3, delta: float) -> void:
	var angulo := _rumo.angle_to(para)
	if angulo < 0.0001:
		_rumo = para
		return
	var eixo := _rumo.cross(para)
	if eixo.length_squared() < 0.000001:
		# Exatamente de costas: qualquer eixo serve; o de cima faz a curva no plano.
		eixo = Vector3.UP if absf(_rumo.y) < 0.9 else Vector3.RIGHT
	_rumo = _rumo.rotated(eixo.normalized(), minf(angulo, GIRO * delta)).normalized()


static func _plano(v: Vector3) -> Vector3:
	var p := Vector3(v.x, 0.0, v.z)
	return p.normalized() if p.length_squared() > 0.0001 else Vector3.ZERO


## Distância do pé ao chão logo abaixo (INF sem chão em 60 m — buraco).
func _altura_do_chao() -> float:
	if not is_instance_valid(_dono) or not _dono.is_inside_tree():
		return INF
	var de := _dono.global_position
	var fora: Array[RID] = []
	if _dono is CollisionObject3D:
		fora.append((_dono as CollisionObject3D).get_rid())
	var chao := MIRA.solo(_dono.get_world_3d(), de, de + Vector3.DOWN * 60.0, fora)
	if chao.is_empty():
		return INF
	return maxf(0.0, de.y - MEIA_ALTURA - float(chao.position.y))
