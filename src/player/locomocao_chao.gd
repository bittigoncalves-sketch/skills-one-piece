extends RefCounted
# ============================================================================
#  ESTADO DA LOCOMOÇÃO NO CHÃO — só PUBLICA (31/10/2026).
#
#  Quem move o corpo é a movimentação do Minecraft (`MovimentoMinecraft`). Este componente
#  LÊ a velocidade que o corpo fez e publica o que a animação e o corpo precisam: `estado`
#  ("parado" | "arrancando" | "correndo" | "freando" | "derrapando" | "combate" | "ar" |
#  "conduzido"), `rumo` (para onde o corpo olha fora do combate) e as inclinações da curva
#  (tg θ = v·ω/g) e da aceleração (tg θ = a/g). Fora do combate o corpo olha para onde anda.
# ============================================================================

## Acima disto a frenagem DERRAPA: o pé desliza (estado "derrapando", poeira) e a
## desaceleração é menor no começo.
const DERRAPA_ACIMA := 5.6
const GRAVIDADE := 32.0
const INCLINACAO_MAX := deg_to_rad(24.0)
const INCLINACAO_FRENTE_MAX := deg_to_rad(16.0)

## "parado" | "arrancando" | "correndo" | "freando" | "derrapando" | "freando_giro"
## | "girando" | "ar" | "combate" | "conduzido" (outro sistema manda: nado)
var estado := "parado"
## Yaw (convenção do projeto: frente(yaw) = (−sin, 0, −cos)) para onde o corpo deve
## olhar fora do combate.
var rumo := 0.0
## Inclinação lateral (rad, + = para a esquerda) e para a frente (+ = frente; − = trás).
var inclinacao := 0.0
var inclinacao_frente := 0.0
## 0..1 dentro do giro (a animação usa para o pivô).
var giro_progresso := 0.0

var _giro_t := 0.0
var _rumo_vel := 0.0          # rumo da velocidade no quadro anterior (para ω)
var _tinha_vel := false
var _vel_anterior := 0.0      # módulo da velocidade horizontal no quadro anterior (`observar`)


static func yaw_de(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


static func dir_de(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Quando a velocidade vem de FORA (a movimentação do Minecraft): não decide nada, só LÊ o
## que o corpo fez e publica o que a animação precisa — estado, rumo e as duas inclinações
## (mesma física da curva: tg θ = v·ω/g; e a da aceleração: tg θ = a/g).
func observar(delta: float, vel: Vector3, desejo: Vector3, no_chao: bool, combate: bool) -> void:
	var plano := Vector3(vel.x, 0.0, vel.z)
	var vn := plano.length()
	var quer := desejo.length_squared() > 0.0001
	_giro_t = 0.0
	giro_progresso = 0.0
	if not no_chao:
		estado = "ar"
	elif combate:
		estado = "combate"
	elif vn < 0.05 and not quer:
		estado = "parado"
	elif vn < 0.5 and quer:
		estado = "arrancando"
	elif quer:
		estado = "correndo"
	else:
		estado = "derrapando" if vn > DERRAPA_ACIMA else "freando"
	if vn > 0.3 and not combate:
		rumo = yaw_de(plano)
	elif quer and not combate:
		rumo = yaw_de(desejo)
	var r_vel := yaw_de(plano) if vn > 0.3 else _rumo_vel
	var omega := wrapf(r_vel - _rumo_vel, -PI, PI) / maxf(delta, 0.0001) if (_tinha_vel and vn > 0.3) else 0.0
	_rumo_vel = r_vel
	var acel := (vn - _vel_anterior) / maxf(delta, 0.0001)
	_vel_anterior = vn
	_tinha_vel = vn > 0.3
	var alvo_incl := clampf(atan(vn * omega / GRAVIDADE), -INCLINACAO_MAX, INCLINACAO_MAX) if no_chao else 0.0
	var alvo_frente := clampf(atan(acel / GRAVIDADE), -INCLINACAO_FRENTE_MAX, INCLINACAO_FRENTE_MAX) if no_chao else 0.0
	inclinacao = lerpf(inclinacao, alvo_incl, 1.0 - exp(-10.0 * delta))
	inclinacao_frente = lerpf(inclinacao_frente, alvo_frente, 1.0 - exp(-12.0 * delta))


## Quando OUTRO sistema manda na velocidade (o nado): o corpo continua olhando para
## onde vai, a inclinação de corrida some, e a corrida recomeça do zero ao sair.
## Sem isto o `rumo` congelava no último valor do chão e o corpo nadava de lado.
func acompanhar(delta: float, vel: Vector3, desejo: Vector3) -> void:
	estado = "conduzido"
	_giro_t = 0.0
	giro_progresso = 0.0
	var plano := Vector3(vel.x, 0.0, vel.z)
	if plano.length() > 0.3:
		rumo = yaw_de(plano)
	elif desejo.length_squared() > 0.0001:
		rumo = yaw_de(desejo)
	_tinha_vel = false
	inclinacao = lerpf(inclinacao, 0.0, 1.0 - exp(-10.0 * delta))
	inclinacao_frente = lerpf(inclinacao_frente, 0.0, 1.0 - exp(-12.0 * delta))
