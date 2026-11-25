extends SceneTree
## Corte lateral na horizontal do machado (17/10/2026): refaz as chaves dos golpes
## PARA_ESQUERDA e PARA_DIREITA de `estilos/machado.tres`. Antes os quatro golpes eram o
## mesmo corte vertical de lenhador.
##   "$(./find_godot.sh)" --headless --path . --script tools/criar_corte_horizontal_machado.gd
##
## Como a pose é CALCULADA, e não chutada: o fio do machado viaja num círculo horizontal em
## volta do corpo. Para cada instante do golpe entram a direção do cabo `h` (do corpo para a
## cabeça do machado) e a do fio `n` (a tangente do giro, por onde o fio avança). As mãos
## ficam NO cabo — a direita mais perto da cabeça, a esquerda 22 cm atrás — e o punho recebe
## a base (x = h × z, y = h, z = −n) com o mesmo "socket vira PI em X" de `giro_da_espada.gd`.
## A cabeça fica no fim do cabo e o fio é a face local −Z do encaixe (o modelo vai girado em
## Y por `MachadoDaHistoria`); conferido com `tools/dev_tests/test_machado_corte.gd`.

const ESTILO := "res://src/combat/direcional/estilos/machado.tres"
const ALTURA_DA_MAO := 1.10
## Alcance do punho direito a partir do centro do corpo (metros).
const RAIO_DO_BRACO := 0.26
## Ângulo (graus, 0 = à frente, + = direita) em que o golpe PARA_ESQUERDA começa e termina.
const ABERTURA := 78.0


func _init() -> void:
	var estilo: EstiloCorpoACorpo = load(ESTILO)
	for golpe in estilo.golpes:
		if golpe.direcao == GolpeDirecional.Direcao.PARA_ESQUERDA:
			_refazer(golpe, 1.0)
		elif golpe.direcao == GolpeDirecional.Direcao.PARA_DIREITA:
			_refazer(golpe, -1.0)
	_refazer_guarda(estilo.guarda)
	var erro := ResourceSaver.save(estilo, ESTILO)
	print("machado.tres salvo: ", error_string(erro))
	quit(0 if erro == OK else 1)


## `sentido` +1 = da direita para a esquerda do personagem; −1 = ao contrário.
func _refazer(golpe: GolpeDirecional, sentido: float) -> void:
	golpe.id = &"machado_corte_lateral_esquerda" if sentido > 0.0 else &"machado_corte_lateral_direita"
	golpe.nome = "Corte lateral"
	golpe.preparo = 0.34
	golpe.ativo = 0.26
	golpe.recuperacao = 0.44
	golpe.fator_movimento_preparo = 0.7
	golpe.fator_movimento_ativo = 0.45
	golpe.fator_movimento_recuperacao = 0.55
	golpe.giro_max_preparo = 360.0
	golpe.giro_max_ativo = 120.0
	golpe.giro_max_recuperacao = 240.0
	golpe.efetor = &"MachadoFio"
	# Cada chave: [fase, fração, curva, ângulo da cabeça, torso (°), passo atrás/à frente]
	var inicio := sentido * ABERTURA
	var fim := -sentido * ABERTURA
	var sequencia := [
		[GolpeDirecional.Fase.PREPARO, 0.8, ChaveDePose.Curva.SUAVE, inicio * 1.12, -sentido * 30.0],
		[GolpeDirecional.Fase.ATIVO, 0.0, ChaveDePose.Curva.SUAVE, inicio, -sentido * 24.0],
		[GolpeDirecional.Fase.ATIVO, 0.25, ChaveDePose.Curva.ACELERA, lerpf(inicio, fim, 0.25), -sentido * 12.0],
		[GolpeDirecional.Fase.ATIVO, 0.5, ChaveDePose.Curva.LINEAR, 0.0, 2.0 * sentido],
		[GolpeDirecional.Fase.ATIVO, 0.75, ChaveDePose.Curva.LINEAR, lerpf(inicio, fim, 0.75), sentido * 18.0],
		[GolpeDirecional.Fase.ATIVO, 1.0, ChaveDePose.Curva.DESACELERA, fim, sentido * 30.0],
		[GolpeDirecional.Fase.RECUPERACAO, 0.4, ChaveDePose.Curva.SUAVE, fim * 0.8, sentido * 12.0],
	]
	var chaves: Array[ChaveDePose] = []
	for s in sequencia:
		chaves.append(_chave(s[0], s[1], s[2], s[3], s[4], sentido))
	golpe.chaves = chaves


func _chave(fase: GolpeDirecional.Fase, fracao: float, curva: ChaveDePose.Curva,
		angulo: float, torso: float, sentido: float) -> ChaveDePose:
	var a := deg_to_rad(angulo)
	var h := Vector3(sin(a), 0.0, -cos(a))
	# Por onde o fio avança: tangente do círculo, no sentido do golpe.
	var viaja := Vector3(-cos(a), 0.0, -sin(a)) * sentido
	var pega_d := Vector3(0.10 + RAIO_DO_BRACO * h.x, ALTURA_DA_MAO, -0.14 + RAIO_DO_BRACO * h.z)
	# O fio do modelo é a face local −Z do cabo: ele aponta para ONDE O GOLPE VIAJA.
	var pegada := PegadaDoMachado.calcular(pega_d, h, viaja)
	var mao_d: Vector3 = pegada["mao_R"]
	var mao_e: Vector3 = pegada["mao_L"]
	var punho_d: Vector3 = pegada["punho_R"]
	var punho_e: Vector3 = pegada["punho_L"]
	var c := ChaveDePose.new()
	c.fase = fase
	c.fracao = fracao
	c.curva = curva
	c.usa_mao_direita = true
	c.mao_direita = mao_d
	c.cotovelo_direito = Vector3(0.8, -0.6, 0.3)
	c.usa_mao_esquerda = true
	c.mao_esquerda = mao_e
	c.cotovelo_esquerdo = Vector3(-0.8, -0.6, 0.3)
	c.rotacoes = {
		"Torso": Vector3(0, torso, 0),
		"SpineMid": Vector3(-4, torso * 0.3, 0),
		"Head": Vector3(0, -torso * 0.6, 0),
		"Wrist_R": Vector3(rad_to_deg(punho_d.x), rad_to_deg(punho_d.y), rad_to_deg(punho_d.z)),
		"Wrist_L": Vector3(rad_to_deg(punho_e.x), rad_to_deg(punho_e.y), rad_to_deg(punho_e.z)),
	}
	return c


## Guarda: o cabo na diagonal, para cima e à frente, as DUAS mãos nele (antes a esquerda
## ficava a 30 cm do cabo). O fio olha para a frente, um pouco à esquerda.
func _refazer_guarda(guarda: ChaveDePose) -> void:
	var h := Vector3(0.32, 0.78, -0.53)
	var pegada := PegadaDoMachado.calcular(Vector3(0.30, 1.08, -0.30), h, Vector3(-0.3, 0.0, -1.0))
	guarda.mao_direita = pegada["mao_R"]
	guarda.mao_esquerda = pegada["mao_L"]
	var rot := guarda.rotacoes.duplicate()
	var d: Vector3 = pegada["punho_R"]
	var e: Vector3 = pegada["punho_L"]
	rot["Wrist_R"] = Vector3(rad_to_deg(d.x), rad_to_deg(d.y), rad_to_deg(d.z))
	rot["Wrist_L"] = Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))
	guarda.rotacoes = rot
