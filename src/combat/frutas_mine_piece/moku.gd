extends Node
## Moku Moku no Mi (Mine Piece v14), SkillMokuMokuProcedure — as técnicas do ciclo R:
##   21 White Fist (WhiteBlowProcedure)   23 White Vine (WhiteVineProcedure)
##   25 White Launcher (WhiteLauncher…)   30 White Out (WhiteOutProcedure)
## Contadores com os nomes do mod; cnt6 é a carga (CNT6 = 1 + cnt6/10).
## Adaptações declaradas: a "explosão" de potência 0 vira clarão; o "cloud" vanilla é a
## fumaça do mod (particle_big_smoke); sons vanilla (wither, sweep, explosão) usam os do
## combate do mod; o anel de nuvens do White Out (até ~1000 partículas/tick) vira um anel
## de fumaça por tick; blocos destruídos viram fumaça (o mapa não muda); a investida do
## White Launcher para no alvo (no mod a velocidade do tick do teleporte passa do alvo).
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const Punho := preload("res://src/combat/frutas_mine_piece/punho_moku.gd")
const Tornado := preload("res://src/combat/frutas_mine_piece/tornado_moku.gd")
const PASTA := "res://assets/mine_piece/frutas/moku/"
const FUMACA := PASTA + "particle_big_smoke.png"
## Um conjunto de sons por técnica (24/11/2026, `tools/generate_moku_audio.py`); os do combate do mod ficam de reserva.
const SONS := PASTA + "sons/moku_"

var c
var tecnica := 0
var cnt1 := 0
var cnt2 := 0
var cnt3 := 0
var cnt4 := 0
var cnt5 := 0.0
var cnt6 := 0.0
var cnt7 := 0
var cnt9 := 0
var cnt10 := 0
var _ponto := Vector3.ZERO     # D.x/y/z_pos
var _impulso := Vector3.ZERO   # D.x/y/z_power (blocos/tick)

func iniciar(numero: int) -> void:
	tecnica = numero
	cnt1 = 0; cnt2 = 0; cnt3 = 0; cnt4 = 0; cnt7 = 0; cnt9 = 0; cnt10 = 0
	cnt5 = 0.0; cnt6 = 0.0

func cancelar() -> void:
	c.invisivel(false)   # punho e tornado vivem sozinhos, como as entidades do mod

func passo() -> void:
	match tecnica:
		21:
			_punho_branco()
		23:
			_cipo_branco()
		25:
			_lancador_branco()
		30:
			_white_out()
		_:
			c.terminar()


# ------------------------------------------------------------------ comum
func _k6() -> float:
	return 1.0 + cnt6 * 0.1

func _tamanho() -> float:
	return B.tamanho(B.ALTURA_JOGADOR, B.LARGURA_JOGADOR)

func _meio() -> Vector3:
	return c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)

## A carga do mod (+passo por tick até 5; ao passar de 5, a explosão de potência 0).
func _carregar(passo_carga: float) -> void:
	if cnt6 > 5.0:
		cnt6 = 5.0
		VfxGoroMinePiece.clarao(c.ator, _meio(), 1.5)
	elif cnt6 < 5.0:
		cnt6 = snappedf(cnt6 + passo_carga, 0.001)
		if is_equal_approx(cnt6, 5.0):
			cnt6 = 5.01

func _fumaca(onde: Vector3, quantidade: int, espalhar_b: float, velocidade := 1.0) -> void:
	VfxFrutaMinePiece.particulas(c.ator, FUMACA, 12, onde, quantidade, Vector3.ONE * B.m(espalhar_b),
		velocidade, 0.7, 0.8, 32)

## O alvo da mira (`passos` trechos de `passo_b` blocos, cubo de `lado_b`); sem alvo, o
## ponto do raio. `topo`: o mod mira o alto do corpo (y + altura) em vez do meio.
func _mirar(passos: int, passo_b: float, lado_b: float, topo := false) -> Vector3:
	var olhos: Vector3 = c.pe() + Vector3.UP * B.m(B.OLHOS_JOGADOR)
	var rumo: Vector3 = c.olhar()
	var ponto := olhos
	var dis := passo_b
	for i in passos:
		var ate := olhos + rumo * B.m(dis)
		var hit: Dictionary = c.ator.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(olhos, ate, B.MASCARA_MUNDO, [c.ator.get_rid()]))
		ponto = hit.position if not hit.is_empty() else ate
		for alvo in AlvosDeGolpe.todos(c.ator.get_tree()):
			if alvo.has_meta(B.DONO) or not B.atacavel(c.ator, alvo) or not B.no_cubo(alvo, ponto, lado_b):
				continue
			var pe := B.pe_de(alvo)
			return pe + Vector3.UP * B.m(B.dimensoes_b(alvo).x) if topo else AlvosDeGolpe.centro(alvo)
		dis += passo_b
	return ponto

## Sobe/desce até o corpo do jogador caber (InsideSolidCalculate em passos de 1 bloco).
func _livre_acima(pe: Vector3, maximo: int) -> Vector3:
	var mundo: World3D = c.ator.get_world_3d()
	for i in maximo:
		if B.solido(mundo, pe, B.ALTURA_JOGADOR, B.LARGURA_JOGADOR):
			pe += Vector3.UP * B.METROS_POR_BLOCO
		elif B.solido(mundo, pe + Vector3.UP * B.METROS_POR_BLOCO, B.ALTURA_JOGADOR, B.LARGURA_JOGADOR):
			break
		else:
			pe += Vector3.UP * B.METROS_POR_BLOCO
	return pe

func _chao_abaixo(pe: Vector3, maximo: int) -> Vector3:
	var mundo: World3D = c.ator.get_world_3d()
	for i in maximo:
		if B.solido(mundo, pe, B.ALTURA_JOGADOR, B.LARGURA_JOGADOR):
			pe -= Vector3.UP * B.METROS_POR_BLOCO
		elif B.solido(mundo, pe - Vector3.UP * B.METROS_POR_BLOCO, B.ALTURA_JOGADOR, B.LARGURA_JOGADOR):
			break
		else:
			pe -= Vector3.UP * B.METROS_POR_BLOCO
	# O mod anda na grade de blocos e cai rente ao chão; aqui o chão não é grade: encosta.
	var hit: Dictionary = mundo.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		pe + Vector3.UP * B.METROS_POR_BLOCO, pe - Vector3.UP * B.METROS_POR_BLOCO * 2.0, B.MASCARA_MUNDO))
	return hit.position if not hit.is_empty() else pe

func _teleportar(pe: Vector3) -> void:
	c.ator.global_position += pe - c.pe()
	c.ator.velocity = Vector3.ZERO


# --------------------------------------------------------- 21 White Fist
func _punho_branco() -> void:
	if cnt1 < 8:
		cnt1 += 1
		cnt4 += 1
		if cnt1 == 1 and cnt4 == 1:
			VfxFrutaMinePiece.som(c.ator, SONS + "punho_carga.wav", c.pe(), 1.0)
		c.recarga = c.recarga_total
		c.lentidao = 5
		c.pose("punch_gomu_pistol1")
		VfxFrutaMinePiece.particulas(c.ator, FUMACA, 12, _meio(), int(2.0 * _tamanho()),
			Vector3(B.m(0.3), B.m(0.9), B.m(0.3)), 0.0, 0.5, 0.5)
		if cnt1 >= 4 and c.segurando:
			cnt1 = mini(cnt1, 6)
			_carregar(0.1)
		return
	c.lentidao = 9
	# O mod nunca dá valor a yaw/picth aqui (ficam 0): o punho nasce 2 larguras a +X do
	# mundo, à altura de 0,6 do corpo, qualquer que seja a mira. Preservado.
	var onde: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.6) + Vector3.RIGHT * B.m(2.0 * B.LARGURA_JOGADOR)
	if cnt3 == 1 or cnt3 == 8:
		cnt2 = 0
		# O soco branco era um disco chato e pequeno (5,2% da imagem): feixe de fumaça da mão até 6 m à frente + anel, a cada soco.
		var rumo: Vector3 = c.olhar()
		var mao: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.6)
		VfxFrutaMinePiece.feixe(c.ator, mao, mao + rumo * B.m(6.0 * _tamanho()), B.m(1.0 * _tamanho()), Color(0.95, 0.95, 1.0), 0.35)
		VfxFrutaMinePiece.onda_de_choque(c.ator, c.pe(), B.m(3.0 * _tamanho()), Color(0.95, 0.95, 1.0), 0.35)
	if cnt2 < 1:
		cnt2 = 1   # AttackStrongPunch: cnt2 + 1 → o golpe sai no cnt2 = 1
		GolpesMinePiece.soco_forte(c, cnt6)
		c.pose("punch_right" if cnt3 != 8 or randf() < 0.5 else "punch_left")
	cnt3 += 1
	if cnt3 == 1 or cnt3 == 8:
		_fumaca(onde, int(cnt6 * 5.0) + 2, 0.1 + cnt6 * 0.2, 2.0)
		VfxFrutaMinePiece.som(c.ator, SONS + "punho_soco.wav", c.pe(), 2.0 * _k6())
		var n := Punho.new()
		n.c = c.controlador()
		n.tamanho = _tamanho() * 2.5
		n.cnt6 = cnt6
		n.rumo = c.olhar()
		n.health = float(Balance.MINE_PIECE_MOKU.vida_punho)
		c.get_tree().current_scene.add_child(n)
		n.global_position = onde
	if cnt3 > 15:
		c.terminar()


# ---------------------------------------------------------- 23 White Vine
func _cipo_branco() -> void:
	cnt10 += 1
	var tam := _tamanho()
	if cnt10 == 1:
		VfxFrutaMinePiece.som(c.ator, SONS + "cipo_carga.wav", c.pe(), 1.2)
		_ponto = _livre_acima(_mirar(3, 8.0, 16.0, true), int(5.0 * tam))
		# O "cipó": o corpo vira fumaça e SOBE até o ponto acima do alvo. Rastro de nuvem da partida ao destino + anel nas duas pontas.
		var origem: Vector3 = c.pe()
		VfxFrutaMinePiece.rastro(c.ator, FUMACA, 12, origem + Vector3.UP * 1.0, _ponto, 18, 1.1)
		VfxFrutaMinePiece.onda_de_choque(c.ator, origem, B.m(5.0 * tam), Color(0.95, 0.95, 1.0), 0.5)
		VfxFrutaMinePiece.onda_de_choque(c.ator, _ponto, B.m(5.0 * tam), Color(0.95, 0.95, 1.0), 0.6)
	if cnt10 <= 20:
		c.invisivel(true)   # MobEffect INVISIBILITY, 2 ticks renovados
		c.pose("fly_front" if cnt10 >= 20 else "invisibility")
		var acima := _ponto
		if cnt10 < 20:
			_teleportar(acima)
			c.impulsionar(Vector3.ZERO)
		else:
			c.impulsionar(Vector3(0.0, 0.5, 0.0))
		var chao := _chao_abaixo(acima, int(24.0 * tam))
		if cnt10 == 10:
			var t := Tornado.new()
			t.c = c.controlador()
			t.tamanho = tam
			t.cnt6 = cnt6 + 4.0
			t.health = float(Balance.MINE_PIECE_MOKU.vida_tornado)
			c.get_tree().current_scene.add_child(t)
			t.global_position = chao
		# 32 traços de nuvem girando em volta, subindo até 8 × tamanho.
		var raio := B.m(4.0 * tam)
		for i in 4:
			var ang := randf() * TAU
			var alto := randf_range(0.0, 8.0) * tam * minf(cnt10 * 0.2, 1.0)
			_fumaca(chao + Vector3(cos(ang) * raio, B.m(alto), sin(ang) * raio), 2, tam, 1.0)
		if cnt10 == 2:
			VfxFrutaMinePiece.som(c.ator, SONS + "cipo_sobe.wav", c.pe(), 1.5)
		if cnt10 % 8 == 1:
			VfxFrutaMinePiece.som(c.ator, SONS + "fumaca.wav", chao, 2.0 * tam, randf_range(0.85, 1.1))
	else:
		c.invisivel(false)
	if cnt10 > 25:
		c.invisivel(false)
		c.terminar()


# ------------------------------------------------------ 25 White Launcher
func _lancador_branco() -> void:
	cnt2 += 1
	var alcance := _tamanho()
	if cnt1 != 0:
		# O golpe no fim da investida (AttackStrongPunch no cnt1 = 9, com o cnt6 + 2,5).
		cnt1 += 1
		c.lentidao = 9
		c.impulsionar(Vector3.ZERO)
		if cnt1 == 9:
			GolpesMinePiece.soco_forte(c, cnt6)
			VfxFrutaMinePiece.som(c.ator, SONS + "impacto.wav", c.pe(), 1.5)
		if cnt1 > 15:
			c.terminar()
		return
	cnt7 += 1
	if cnt3 == 0:
		c.lentidao = 9
		c.recarga = c.recarga_total
		if cnt2 == 9:
			VfxFrutaMinePiece.som(c.ator, SONS + "lancador_carga.wav", c.pe(), 1.0)
		if cnt2 >= 9:
			if c.segurando:
				cnt2 = mini(cnt2, 9)
			_carregar(0.125)
			VfxFrutaMinePiece.particulas(c.ator, FUMACA, 12, _meio(), int(2.0 * alcance),
				Vector3(B.m(0.3), B.m(0.9), B.m(0.3)), 0.0, 0.5, 0.5)
		if cnt2 >= 10 and not c.segurando and c.ator.is_on_floor():
			cnt2 = 0
			cnt3 = 1
			c.lentidao = -1
			_impulso = c.olhar() * 3.0
			_fumaca(c.pe(), int(10.0 * alcance), alcance * 0.25, 0.5 * B.VELOCIDADE * 0.1)
			VfxFrutaMinePiece.som(c.ator, SONS + "lancador_tiro.wav", c.pe(), 2.0 * alcance)
			c.pose("fly_front")
		return
	if cnt3 <= 1:
		var v := _impulso * 1.5
		c.impulsionar(v)
		var passo: Vector3 = v.normalized() if v.length_squared() > 0.0001 else c.olhar()
		var achou: Node3D = null
		var ponto: Vector3 = c.pe()
		for i in maxi(int(v.length()), 1):
			_fumaca(ponto, int(4.0 * alcance), alcance * 0.25, 0.25 * B.VELOCIDADE * 0.1)
			for alvo in AlvosDeGolpe.todos(c.ator.get_tree()):
				if alvo.has_meta(B.DONO) or not B.atacavel(c.ator, alvo):
					continue
				if B.no_cubo(alvo, ponto + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), 4.0 * alcance):
					achou = alvo
					break
			if achou != null:
				break
			ponto += passo * B.METROS_POR_BLOCO
		if achou != null:
			# Teleporta, bloco a bloco, a distância até o alvo (sem entrar em parede).
			var distancia := roundi(B.pe_de(achou).distance_to(c.pe()) / B.METROS_POR_BLOCO)
			var pe: Vector3 = c.pe()
			for i in distancia:
				var preso := true
				for eixo in [Vector3(passo.x, 0, 0), Vector3(0, passo.y, 0), Vector3(0, 0, passo.z)]:
					if not B.solido(c.ator.get_world_3d(), pe + eixo * B.METROS_POR_BLOCO, B.ALTURA_JOGADOR, B.LARGURA_JOGADOR):
						pe += eixo * B.METROS_POR_BLOCO
						preso = false
				if preso:
					break
			if distancia >= 1:
				_teleportar(pe)
			# Adaptação: no mod o setDeltaMovement deste tick continua depois do teleporte e
			# leva o corpo 4,5 blocos além do alvo (o soco sai no vazio); aqui a investida
			# para no alvo, que é o que a técnica pretende.
			c.impulsionar(Vector3.ZERO)
		if achou != null or cnt2 > 10:
			cnt3 = 2
		return
	cnt3 += 1
	c.impulsionar(Vector3.ZERO)
	if cnt3 >= 6:
		c.pose("punch_right")
		cnt1 = 8
		cnt6 += 2.5


# ------------------------------------------------------------ 30 White Out
func _white_out() -> void:
	cnt1 += 1
	cnt9 += 1
	var k6 := _k6()
	c.lentidao = 9
	if cnt1 <= 25:
		c.recarga = c.recarga_total
		if cnt9 % 5 == 1:
			c.pose("yamiyami_blackhole")
	if cnt1 >= 5 and cnt1 <= 25:
		# Anel de nuvens que fecha sobre o corpo (raio até 30 blocos).
		var raio := minf(5.0 * (cnt1 - 5), 30.0)
		var ang := randf() * TAU
		for i in 12:
			var r := B.m(raio * randf())
			var a := ang + i * TAU / 12.0
			VfxFrutaMinePiece.particulas(c.ator, FUMACA, 12, c.pe() + Vector3(cos(a) * r, B.m(randf() * 2.0), sin(a) * r),
				2, Vector3.ONE * B.m(1.0), 1.0, 0.8, 1.2, 4)
		if cnt2 == 0:
			cnt2 = 1
			VfxFrutaMinePiece.som(c.ator, SONS + "white_out_carga.wav", c.pe(), 1.5 + k6)
		if cnt1 >= 25 and c.segurando and cnt5 < 4.0:
			cnt1 = mini(cnt1, 24)
			cnt5 += 0.1
	if cnt1 > 35:
		if cnt1 <= 45:
			c.pose("enkai")
			var meio := _meio()
			_fumaca(meio, 24, 1.0, 4.0)
			var a := B.Ataque.new(float(Balance.MINE_PIECE_MOKU.white_out) * k6, 32.0 * k6, 2.0, false)
			B.ataque_em_area(c.ator, meio, meio, a, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
			B.empurrar_area(c.ator, meio, meio, 32.0 * k6, 2.0)
			if cnt1 <= 36:
				VfxGoroMinePiece.clarao(c.ator, meio, B.m(8.0), 0.25)
				VfxFrutaMinePiece.onda_de_choque(c.ator, meio, B.m(14.0 * k6), Color(0.95, 0.95, 1.0), 0.7)
				VfxFrutaMinePiece.som(c.ator, SONS + "white_out_nuvem.wav", meio, 2.5)
		if cnt1 > 45:
			c.terminar()
		return
	if cnt1 >= 10:
		# O campo de fumaça: quem está dentro fica preso (Lentidão X e sem técnica,
		# golpe, esquiva ou voo por 20 ticks) e é erguido 0,1 do chão.
		var lado := minf(cnt1 - 10, 24) * 2.0
		for alvo in AlvosDeGolpe.todos(c.ator.get_tree()):
			if alvo.has_meta(B.DONO) or not B.atacavel(c.ator, alvo) or not B.no_cubo(alvo, c.pe(), lado):
				continue
			ImobilizacaoMinePiece.aplicar(alvo, 20 * B.TICK)
			if alvo.has_method("is_on_floor") and alvo.is_on_floor():
				alvo.global_position += Vector3.UP * B.m(0.1)
