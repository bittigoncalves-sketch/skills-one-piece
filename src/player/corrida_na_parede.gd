extends RefCounted
# ============================================================================
#  CORRIDA NA PAREDE (wall run) — fatia 2 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md
#  (03/10/2026). Substitui o "andar na superfície" (parede virava chão, 27/08),
#  removido de vez por decisão do dono.
#
#  Pedido do dono (referência Mirror's Edge Catalyst; velocidade de Titanfall 2):
#    "a parede continua sendo uma parede e a gravidade permanece normal";
#    a velocidade da corrida anterior é parcialmente mantida;
#    "o personagem não poderá ficar parado na parede. Conforme perde velocidade,
#    a gravidade passa a dominar e ele começa a cair";
#    dá para saltar para longe da parede.
#
#  FÍSICA. A gravidade aponta SEMPRE para baixo. O que segura o corpo é a
#  velocidade ao longo da parede: uma sustentação proporcional a ela anula parte
#  da gravidade (SUSTENTACAO na velocidade VEL_SUSTENTACAO). A velocidade cai
#  DESACELERACAO por segundo, então a sustentação cai junto e a queda vence —
#  um arco que sobe com o impulso de entrada e desce cada vez mais rápido.
#
#  CONTROLES (decisão do dono, estilo Mirror's Edge): Espaço correndo rente a uma
#  parede lateral entra; Espaço na parede salta para longe; Ctrl solta.
#
#  Mesmo molde dos outros componentes do Player: NÃO escreve `velocity` — recebe a
#  velocidade e devolve a velocidade. Publica o que o corpo e a animação precisam:
#  `normal`, `tangente`, `lado`, `progresso`.
# ============================================================================

## Velocidade horizontal mínima para entrar (m/s). A corrida é 4,2; andar não basta.
const VEL_MIN_ENTRADA := 3.5
## Ângulo máximo entre a corrida e o plano da parede ao entrar. Acima disto o
## corpo está indo DE FRENTE para a parede — é caso de escalada, não de wall run.
const ANGULO_MAX_ENTRADA := deg_to_rad(60.0)
## Alcance das sondas a partir do centro do corpo (raio da cápsula ~0,35 m).
const ALCANCE_LADO := 0.9
const ALCANCE_DIAGONAL := 1.15
## A parede tem de existir também na altura do ombro: mureta não serve.
const ALTURA_OMBRO := 0.6
## Ao entrar, a velocidade vertical sobe a pelo menos isto (m/s): o "passo" na parede.
const IMPULSO_SUBIDA := 5.0
## Fração da velocidade horizontal que vira velocidade ao longo da parede.
const RETEM_VELOCIDADE := 0.95
## Sustentação: 0,72 da gravidade anulada a VEL_SUSTENTACAO (proporcional abaixo).
## Calibrado em 03/10 (simulação conferida contra o jogo: 0,65 s × 0,63 s medido):
## corrida 4,2 m/s → 0,83 s e sobe 1,13 m; sprint 6,3 → 1,1 s e 1,35 m. A primeira
## versão (impulso 6, sustentação cheia a 7 m/s, perda 2,2) dava 0,58 s na corrida
## — lia como pulo de lado — e o sprint subiria ~2 m.
const SUSTENTACAO := 0.72
const VEL_SUSTENTACAO := 4.0
## Perda de velocidade ao longo da parede (m/s²).
const DESACELERACAO := 1.8
## Abaixo disto a parede solta.
const VEL_MIN := 2.5
const DURACAO_MAX := 1.8
## Tempo sem achar a parede antes de soltar (quina, junta entre blocos).
const FOLGA_SEM_PAREDE := 0.12
## Pressão contra a parede (m/s): mantém o contato de colisão entre quadros.
const ADERENCIA := 1.5
## Salto para longe: empurrão para fora, para cima e parte da velocidade ao longo.
const SALTO_FORA := 7.0
const SALTO_CIMA := 13.0
const SALTO_TANGENTE := 0.85
## Ao soltar sem saltar (Ctrl, fim de embalo), um afastamento pequeno.
const SOLTAR_FORA := 1.5
## Depois de sair, a MESMA parede só aceita de novo passado este tempo; a parede
## do outro lado aceita na hora (parede → salto → parede, como no Mirror's Edge).
const CARENCIA_MESMA_PAREDE := 0.35
## COYOTE (fatia 4): a parede acabou sozinha (embalo, tempo, quina) e o Espaço vem
## logo depois — ainda vale o salto da parede, com a última normal e velocidade.
const COYOTE := 0.15

var ativo := false
## Normal da parede (aponta para FORA dela).
var normal := Vector3.ZERO
## Direção da corrida ao longo da parede (horizontal, unitária).
var tangente := Vector3.ZERO
## +1 = parede à DIREITA de quem corre; −1 = à esquerda.
var lado := 0
var tempo := 0.0
## true só no quadro em que saltou da parede (a animação usa para o impulso).
var saltou := false

var _vel := 0.0
var _folga := 0.0
var _carencia := 0.0
var _normal_saida := Vector3.ZERO
var _coyote := 0.0
var _tangente_saida := Vector3.ZERO
var _vel_saida := 0.0


## 0 no começo, 1 quando a velocidade chegou ao mínimo (para a animação).
func progresso() -> float:
	return clampf(1.0 - (_vel - VEL_MIN) / maxf(VEL_SUSTENTACAO - VEL_MIN, 0.01), 0.0, 1.0)


func velocidade_ao_longo() -> float:
	return _vel


## Uma vez por quadro, antes de `tentar_entrar`/`atualizar`.
func passar_tempo(delta: float) -> void:
	_carencia = maxf(_carencia - delta, 0.0)
	_coyote = maxf(_coyote - delta, 0.0)
	saltou = false


## Espaço logo depois de a parede acabar sozinha: devolve o salto da parede (e o
## consome), ou ZERO se a janela passou. No chão a janela não vale.
func salto_coyote(no_chao: bool) -> Vector3:
	if _coyote <= 0.0 or no_chao or ativo:
		_coyote = 0.0
		return Vector3.ZERO
	_coyote = 0.0
	saltou = true
	return _normal_saida * SALTO_FORA + _tangente_saida * _vel_saida * SALTO_TANGENTE + Vector3.UP * SALTO_CIMA


## Espaço apertado: entra se há parede lateral válida. Devolve true se entrou.
func tentar_entrar(corpo: CharacterBody3D, vel: Vector3) -> bool:
	if ativo:
		return false
	var plano := Vector3(vel.x, 0.0, vel.z)
	var v := plano.length()
	if v < VEL_MIN_ENTRADA:
		return false
	var dir := plano / v
	var n := _sondar_lados(corpo, dir)
	if n == Vector3.ZERO:
		return false
	# Ângulo entre a corrida e o plano da parede: |dir·n| = seno dele.
	var indo_para_parede := -dir.dot(n)
	if indo_para_parede > sin(ANGULO_MAX_ENTRADA) or indo_para_parede < -0.2:
		return false
	if _carencia > 0.0 and n.dot(_normal_saida) > 0.7:
		return false
	ativo = true
	normal = n
	tangente = _tangente_de(n, dir)
	lado = 1 if (-n).dot(tangente.cross(Vector3.UP)) > 0.0 else -1
	tempo = 0.0
	_folga = 0.0
	_vel = v * RETEM_VELOCIDADE
	return true


## A velocidade deste quadro na parede. `vel_y` entra com a velocidade vertical
## atual; na entrada o Player já a recebe e ela sobe a IMPULSO_SUBIDA aqui.
func atualizar(delta: float, corpo: CharacterBody3D, vel: Vector3, gravidade: float,
		no_chao: bool, saltar: bool, soltar: bool) -> Vector3:
	if not ativo:
		return vel
	var vy := vel.y
	if tempo == 0.0:
		vy = maxf(vy, IMPULSO_SUBIDA)
	tempo += delta

	# A parede ainda está lá? Segue paredes curvas pela normal nova.
	var n := _sondar_parede(corpo, normal)
	if n != Vector3.ZERO:
		normal = n
		tangente = _tangente_de(n, tangente)
		_folga = 0.0
	else:
		_folga += delta

	if saltar:
		var saida := normal * SALTO_FORA + tangente * _vel * SALTO_TANGENTE + Vector3.UP * SALTO_CIMA
		_sair()
		saltou = true
		return saida

	_vel = maxf(_vel - DESACELERACAO * delta, 0.0)
	var g := gravidade * (1.0 - SUSTENTACAO * clampf(_vel / VEL_SUSTENTACAO, 0.0, 1.0))
	vy -= g * delta

	var acabou := soltar or _vel < VEL_MIN or tempo > DURACAO_MAX \
		or _folga > FOLGA_SEM_PAREDE or (no_chao and tempo > 0.1 and vy <= 0.0)
	if acabou:
		var solta := tangente * _vel + normal * SOLTAR_FORA + Vector3.UP * vy
		var natural := not soltar and not no_chao
		var t_saida := tangente
		var v_saida := _vel
		_sair()
		if natural:
			_coyote = COYOTE
			_tangente_saida = t_saida
			_vel_saida = v_saida
		return solta
	return tangente * _vel - normal * ADERENCIA + Vector3.UP * vy


## Larga a parede sem impulso nenhum (morte, arremesso, outro sistema assumiu).
func cancelar() -> void:
	if ativo:
		_sair()


func _sair() -> void:
	ativo = false
	_normal_saida = normal
	_carencia = CARENCIA_MESMA_PAREDE
	_vel = 0.0
	tempo = 0.0


static func _tangente_de(n: Vector3, referencia: Vector3) -> Vector3:
	var t := n.cross(Vector3.UP).normalized()
	return -t if t.dot(referencia) < 0.0 else t


## Procura parede à esquerda e à direita de quem corre (de lado e na diagonal à
## frente). Devolve a normal da mais próxima, ou ZERO.
func _sondar_lados(corpo: CharacterBody3D, dir: Vector3) -> Vector3:
	var direita := dir.cross(Vector3.UP)
	var melhor := Vector3.ZERO
	var menor := INF
	for s: Vector3 in [direita, -direita]:
		for sonda: Array in [[s, ALCANCE_LADO], [(s + dir).normalized(), ALCANCE_DIAGONAL]]:
			var acerto := _raio_de_parede(corpo, sonda[0], sonda[1], 0.0)
			if acerto.is_empty():
				continue
			var d: float = (acerto["position"] - corpo.global_position).length()
			if d < menor and not _raio_de_parede(corpo, sonda[0], sonda[1], ALTURA_OMBRO).is_empty():
				menor = d
				melhor = acerto["normal"]
	return melhor


func _sondar_parede(corpo: CharacterBody3D, n: Vector3) -> Vector3:
	var acerto := _raio_de_parede(corpo, -n, ALCANCE_LADO + 0.3, 0.0)
	return acerto["normal"] if not acerto.is_empty() else Vector3.ZERO


## Raio horizontal a partir do corpo; só aceita superfície vertical que não seja
## outro personagem.
func _raio_de_parede(corpo: CharacterBody3D, direcao: Vector3, alcance: float, altura: float) -> Dictionary:
	var espaco := corpo.get_world_3d().direct_space_state
	var de := corpo.global_position + Vector3.UP * altura
	var par := PhysicsRayQueryParameters3D.create(de, de + direcao * alcance)
	par.exclude = [corpo.get_rid()]
	var h := espaco.intersect_ray(par)
	if h.is_empty() or absf((h["normal"] as Vector3).y) >= 0.3 or h["collider"] is CharacterBody3D:
		return {}
	return h
