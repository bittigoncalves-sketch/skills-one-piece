extends Node
## Pika Pika no Mi (Mine Piece v14), SkillPikaPikaProcedure — o ciclo R e a passiva:
##   21 Laser (KizaruLaser1)            22 Amano-Iwato (KizaruLaser2, o laser do pé)
##   24 "Yasakani Sacred Jewel" (SkillYatanoKagami — o mod rotula assim o Yata no Kagami)
##   27 Acceleration is Power!!! (SkillSpeedIsPower)
##   29 Yasakani Sacred Jewel (YasakaniNoMagatama)
##   30 Ama no Murakumo Sword (SkillAmanoMurakumo: a espada de luz no lugar da fruta)
##   28 passiva (SkillPikaPikaPassive1): toque duplo W/S, teleporte de luz, sem custo.
## Contadores com os nomes do mod; cnt6 é a carga (CNT6 = 1 + cnt6/10).
## Adaptações declaradas: "explosão" de potência 0 = clarão; partículas vanilla (end_rod,
## firework, flash) = luz do mod; sons vanilla = sons do mod (laser, explosão, movimento,
## soco); blocos destruídos = marca no chão; a 30 vira o item da fruta (decisão do dono):
## o ícone da barra passa a ser o da espada e, com a fruta equipada, ela vai para a mão
## (usar a 30 de novo larga a espada; comer outra fruta também).
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const Onda := preload("res://src/combat/frutas_mine_piece/onda_de_impacto_mine_piece.gd")
const Luz := preload("res://src/combat/frutas_mine_piece/luz_pika.gd")
const PASTA := "res://assets/mine_piece/frutas/pika/"
const COR_LUZ := Color(1.0, 0.85, 0.2)           # a luz da Pika (laser, clarões, onda): amarelo, não o azul-gelo padrão do clarão
const LUZ_P := PASTA + "particle_light_small.png"
const LUZ_G := PASTA + "particle_light_large.png"
const ESPADA := "amano_murakumo"
## DamageFix com a mão vazia: atributo de ataque 1 → ×(1 + 0,333 × 0,333).
const DAMAGE_FIX := 1.0 + 0.333 * 0.333

var c
var tecnica := 0
var cnt1 := 0
var cnt2 := 0
var cnt3 := 0
var cnt4 := 0
var cnt6 := 0.0
var cnt7 := 0
var cnt9 := 0
var cnt10 := 0
var _ponto := Vector3.ZERO     # D.x/y/z_pos
var _rumo := Vector3.ZERO      # D.x/y/z_power
var _origem := Vector3.ZERO
var _vel_mc := Vector3.ZERO    # o deltaMovement do Minecraft enquanto o corpo sobe (blocos/tick)
var _feixe: MeshInstance3D
var _inicio_feixe := Vector3.ZERO
var _cena_espada: PackedScene

func iniciar(numero: int) -> void:
	tecnica = numero
	cnt1 = 0; cnt2 = 0; cnt3 = 0; cnt4 = 0; cnt7 = 0; cnt9 = 0; cnt10 = 0
	cnt6 = 0.0
	_apagar_feixe()

func cancelar() -> void:
	_apagar_feixe()
	c.invisivel(false)
	# O controlador saiu (trocou de item ou de fruta): a espada de luz sai da mão.
	if not c.is_inside_tree() or not c.fruta_ativa():
		var arma = c.ator.get_node_or_null("EspadaDaHistoria") if is_instance_valid(c.ator) else null
		if arma != null and arma.espada_de_fruta():
			arma.aplicar_espada_de_fruta(false)

func passo() -> void:
	match tecnica:
		21:
			_laser(false)
		22:
			_laser(true)
		24:
			_espelho()
		27:
			_velocidade_e_poder()
		29:
			_yasakani()
		30:
			_ama_no_murakumo()
		28:
			_passiva()
		_:
			c.terminar()


# ------------------------------------------------------------------ comum
func _k6() -> float:
	return 1.0 + cnt6 * 0.1

func _tamanho() -> float:
	return B.tamanho(B.ALTURA_JOGADOR, B.LARGURA_JOGADOR)

func _meio() -> Vector3:
	return c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)

func _luz(onde: Vector3, quantidade: int, espalhar_b: float, velocidade := 0.0, grande := false) -> void:
	VfxFrutaMinePiece.particulas(c.ator, LUZ_G if grande else LUZ_P, 5, onde, quantidade,
		Vector3.ONE * B.m(espalhar_b), velocidade, 0.4, 0.9 if grande else 0.35, 24, true)

func _som(nome: String, onde: Vector3, volume := 1.0, tom := 1.0) -> void:
	VfxFrutaMinePiece.som(c.ator, PASTA + nome + ".ogg", onde, volume, tom)

## Um som novo por técnica (24/11/2026, `tools/generate_pika_mp_audio.py`): sem grave, banda que varre — a lei da luz.
func _nsom(cue: String, onde: Vector3, volume := 1.0, tom := 1.0) -> void:
	VfxFrutaMinePiece.som(c.ator, PASTA + "sons/pika_" + cue + ".wav", onde, volume, tom)

## A carga do mod (+passo por tick até 5; ao passar de 5, a explosão de potência 0).
func _carregar(passo_carga: float, onde: Vector3) -> void:
	if cnt6 > 5.0:
		cnt6 = 5.0
		VfxGoroMinePiece.clarao(c.ator, onde, 1.5, 0.15, COR_LUZ)
	elif cnt6 < 5.0:
		cnt6 = snappedf(cnt6 + passo_carga, 0.001)
		if is_equal_approx(cnt6, 5.0):
			cnt6 = 5.01

## A frente do corpo (o x/y/z_pos do mod): pé + altura × `altura` + mira × `dist` blocos.
func _a_frente(altura: float, dist: float, com_pitch := true) -> Vector3:
	var olhar: Vector3 = c.olhar()
	if not com_pitch:
		olhar.y = 0.0
		olhar = olhar.normalized()
	return c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * altura) + olhar * B.m(dist)

func _teleportar(pe: Vector3) -> void:
	c.ator.global_position += pe - c.pe()
	c.ator.velocity = Vector3.ZERO

func _solido(pe: Vector3) -> bool:
	return B.solido(c.ator.get_world_3d(), pe, B.ALTURA_JOGADOR, B.LARGURA_JOGADOR)

## O alvo da mira para os golpes que vão até ele: `passos` trechos de `passo_b` blocos, cubo
## de `lado_b`; o ponto é o alto do corpo (y + altura). Sem alvo, o ponto do raio.
func _mirar_topo(passos: int, passo_b: float, lado_b: float) -> Vector3:
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
			return B.pe_de(alvo) + Vector3.UP * B.m(B.dimensoes_b(alvo).x)
		dis += passo_b
	return ponto

## InsideSolidCalculate em passos de 1 bloco: sobe até achar teto logo acima (ou `maximo`).
func _subir_ate_teto(pe: Vector3, maximo: int) -> Vector3:
	for i in maximo:
		if _solido(pe):
			pe += Vector3.UP * B.METROS_POR_BLOCO
		elif _solido(pe + Vector3.UP * B.METROS_POR_BLOCO):
			break
		else:
			pe += Vector3.UP * B.METROS_POR_BLOCO
	return pe

func _apagar_feixe() -> void:
	if is_instance_valid(_feixe):
		_feixe.queue_free()
	_feixe = null


# ------------------------------------------------- 21 Laser / 22 Amano-Iwato
## KizaruLaser1/2: carga (segurar prende cnt1 em 9/19), depois o feixe avança 20 blocos por
## tick em passos de 0,1 (um RangeAttack a cada 1,1 bloco) até bater, achar alvo ou o
## tempo acabar; aí explode e deixa a EntityImpactWave (modo 2 / 0).
func _laser(do_pe: bool) -> void:
	var ficha: Dictionary = Balance.MINE_PIECE_PIKA
	var fim_carga := 20 if do_pe else 10
	var fim_feixe := 28 if do_pe else 18
	var altura := 0.25 if do_pe else 0.75
	cnt1 += 1
	cnt9 += 1
	var k6 := _k6()
	if do_pe and cnt9 % 4 == 1:
		c.pose("right_leg_front")
	elif not do_pe:
		c.pose("right_arm_front")
	if cnt1 <= fim_carga:
		c.lentidao = 9 if do_pe else 4
		c.recarga = c.recarga_total
		var frente := _a_frente(altura, 0.6 + B.LARGURA_JOGADOR, false)
		if cnt3 == 0:
			cnt3 = 1
			_nsom("laser_carga", frente, 0.8)
			_luz(frente, 5, 0.0, 0.5 * B.VELOCIDADE * 0.05)
		_luz(frente, 1, 0.0)
		if cnt1 >= fim_carga - 1 and c.segurando:
			cnt1 = mini(cnt1, fim_carga - 1)
			_carregar(0.1, frente)
		return
	if cnt1 <= fim_feixe:
		_passo_do_feixe(do_pe, altura, fim_feixe, k6, ficha)
	if cnt1 > (35 if do_pe else 23):
		_apagar_feixe()
		c.terminar()

func _passo_do_feixe(do_pe: bool, altura: float, fim_feixe: int, k6: float, ficha: Dictionary) -> void:
	if cnt2 == 0:
		cnt2 = 1
		_ponto = _a_frente(altura, 0.6 + B.LARGURA_JOGADOR)
		_rumo = c.olhar()
		_inicio_feixe = _ponto
		_feixe = BeamVisual3D.criar(VfxGoroMinePiece._raiz(c.ator), _ponto, _ponto + _rumo * 0.1, 0.12 * k6)
	if cnt2 <= 5 + int(cnt6):
		c.lentidao = 9
		if cnt2 == 1:
			_nsom("laser_feixe", _ponto, (2.0 if do_pe else 1.0) * _tamanho())
			_luz(_ponto, 1, 0.0, 0.0, true)
	cnt2 += 1
	var mundo: World3D = c.ator.get_world_3d()
	var passo := _rumo * B.m(0.1)
	var dano := float(ficha.laser_pe if do_pe else ficha.laser) * k6
	var dis := 0
	for i in 200:
		dis += 1
		var achou := false
		if dis > 0:
			dis = -10
			B.ataque_em_area(c.ator, _ponto, _ponto, B.Ataque.new(dano, 2.0, 0.1, false), c.tick, c.imunidade,
				PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
			achou = B.primeiro_no_cubo(c.ator, _ponto, 2.0) != null
		var parede := false
		for eixo in [Vector3(passo.x, 0, 0), Vector3(0, passo.y, 0), Vector3(0, 0, passo.z)]:
			if B.solido(mundo, _ponto + eixo - Vector3.UP * 0.05, 0.1, 0.1):
				parede = true
			else:
				_ponto += eixo
		if parede or achou or cnt1 >= fim_feixe:
			_explodir_laser(do_pe, parede, dano, k6)
			cnt1 = maxi(cnt1, 99 if not do_pe else 28)
			break
	if is_instance_valid(_feixe):
		BeamVisual3D.atualizar(_feixe, _inicio_feixe, _ponto)

func _explodir_laser(do_pe: bool, parede: bool, dano: float, k6: float) -> void:
	var lado := (24.0 if do_pe else 12.0) * k6
	B.ataque_em_area(c.ator, _ponto, _ponto, B.Ataque.new(dano, lado, 1.0, false), c.tick, c.imunidade,
		PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
	if parede:
		VfxFrutaMinePiece.placa(c.ator, _ponto, B.m((8.0 * k6 if do_pe else 4.0) * 0.5), Color(0.1, 0.08, 0.02, 0.4), 6.0)
	var onda := Onda.new()
	onda.c = c.controlador()
	onda.modo = 0 if do_pe else 2
	onda.cnt6 = cnt6 if do_pe else cnt6 - 4.0
	onda.modelo = PASTA + "mp_onda_amarela.glb"
	VfxGoroMinePiece._raiz(c.ator).add_child(onda)
	onda.global_position = _ponto
	VfxGoroMinePiece.clarao(c.ator, _ponto, B.m(lado) * 0.25, 0.2, COR_LUZ)
	VfxFrutaMinePiece.onda_de_choque(c.ator, _ponto, B.m(lado) * 0.6, COR_LUZ, 0.5)
	_nsom("laser_explosao", _ponto, 8.0 * _tamanho())
	# AMATERASU (nome de jogo; One Piece Wiki, Pika Pika no Mi): o flash dos dois dedos que CEGA quem olha. Aqui só o flash na tela de quem está perto do impacto
	# (sem cegueira mecânica: isso não é do mod). Mais forte quanto mais perto; nada a mais de 25 m.
	var cena_fx: Node = c.get_tree().root.get_node_or_null("ScreenFX")
	if cena_fx != null and cena_fx.has_method("flash"):
		var d: float = (c.ator.global_position as Vector3).distance_to(_ponto)
		cena_fx.flash(Color(1.0, 0.97, 0.8), clampf(1.0 - d / 25.0, 0.0, 0.85))


# ------------------------------------------ 24 Yata no Kagami (+ KizaruKick)
func _espelho() -> void:
	cnt2 += 1
	cnt7 += 1
	var tam := _tamanho()
	if cnt3 == 0:
		c.lentidao = 3
		c.recarga = c.recarga_total
		if cnt2 >= 9:
			if c.segurando:
				cnt2 = mini(cnt2, 9)
			_carregar(0.125, _meio())
			_luz(_meio(), int(2.0 * tam), 0.3)
		if cnt2 >= 11:
			cnt2 = 0
			cnt3 = 1
			# 128 passos de 0,5 bloco na mira, do pé, até um alvo (cubo de 3) ou parede.
			var pe: Vector3 = c.pe()
			var p: Vector3 = c.olhar() * B.m(0.5)
			for i in 128:
				if B.primeiro_no_cubo(c.ator, pe, 3.0 * tam) != null:
					break
				var preso := true
				for eixo in [Vector3(p.x, 0, 0), Vector3(0, p.y, 0), Vector3(0, 0, p.z)]:
					if not _solido(pe + eixo):
						pe += eixo
						preso = false
				if preso:
					break
			_ponto = pe
			c.pose("both_arm_front")
		return
	cnt3 += 1
	c.impulsionar(Vector3.ZERO)
	if cnt3 < 8:
		c.lentidao = 9
		_luz(_ponto + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), int(2.0 * tam), tam * 0.5)
		var de: Vector3 = c.pe()
		for i in 6:
			_luz(de.lerp(_ponto, (i + 0.5) / 6.0), 1, 0.25)
		return
	if cnt3 == 8:
		_luz(_meio(), int(2.0 * tam), tam * 0.5, 0.0, true)
		_nsom("espelho_salto", _meio(), 2.0)
		# O teleporte de luz era invisível (só partículas esparsas): risco amarelo da partida ao destino + anel nas duas pontas.
		var de_luz: Vector3 = _meio()
		VfxFrutaMinePiece.feixe(c.ator, de_luz, _ponto + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), B.m(1.1 * tam), COR_LUZ, 0.4)
		VfxFrutaMinePiece.onda_de_choque(c.ator, c.pe(), B.m(3.0 * tam), COR_LUZ, 0.4)
		VfxFrutaMinePiece.onda_de_choque(c.ator, _ponto, B.m(3.0 * tam), COR_LUZ, 0.4)
		_teleportar(_ponto)
		# Vira para o alvo mais perto (cubo de 5): o chute sai nele.
		for alvo in AlvosDeGolpe.todos(c.ator.get_tree()):
			if alvo.has_meta(B.DONO) or not B.atacavel(c.ator, alvo) or not B.no_cubo(alvo, _meio(), 5.0 * tam):
				continue
			var d: Vector3 = AlvosDeGolpe.centro(alvo) - _meio()
			c.ator._yaw = atan2(-d.x, -d.z)
			c.ator._update_pivot()
			break
		cnt1 = 8
		cnt2 = 0
		cnt6 += 2.5
	_chute()
	if cnt3 >= 18:
		c.terminar()

## KizaruKick depois do cnt1 = 8 (o caminho que o Yata usa): três ticks de golpe na frente
## (17 × CNT6, cubo de 6, empurrão 2 + o KnockbackProcedure).
func _chute() -> void:
	cnt1 += 1
	if cnt1 < 8:
		return
	cnt2 += 1
	c.lentidao = 2
	var tam := _tamanho()
	if cnt2 > 3:
		return
	if cnt2 == 1:
		_nsom("espelho_chute", _meio(), tam)
		c.pose("kick_right" if randf() < 0.5 else "kick_left")
		_origem = _meio() + c.olhar() * B.m(3.0 * tam * tam)
		_luz(_origem, 1, 0.0, 0.0, true)
	var a := B.Ataque.new(float(Balance.MINE_PIECE_PIKA.chute) * _k6(), 6.0 * tam, 2.0, false)
	B.ataque_em_area(c.ator, c.pe(), _origem, a, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
	B.empurrar_area(c.ator, c.pe(), _origem, 6.0 * tam, 2.0)


# ----------------------------------------------- 27 Acceleration is Power!!!
func _velocidade_e_poder() -> void:
	cnt10 += 1
	var tam := _tamanho()
	var ficha: Dictionary = Balance.MINE_PIECE_PIKA
	if cnt10 == 1:
		_nsom("passiva_ida", _meio(), 1.5, 0.8)
		_luz(_meio(), int(tam), 0.25 * tam, 0.0, true)
		_ponto = _subir_ate_teto(_mirar_topo(8, 6.0, 12.0), int(8.0 * tam))
		# A subida: o corpo vira luz e some. Coluna de luz da partida ao ponto alto (antes: nada marcava para onde ele foi).
		VfxFrutaMinePiece.feixe(c.ator, c.pe(), _ponto, B.m(1.3 * tam), COR_LUZ, 0.5)
		VfxFrutaMinePiece.onda_de_choque(c.ator, c.pe(), B.m(4.0 * tam), COR_LUZ, 0.45)
	if cnt10 > 30:
		c.invisivel(false)
		c.terminar()
		return
	if cnt10 < 20:
		c.invisivel(true)
		c.pose("invisibility")
	elif cnt10 == 20:
		c.invisivel(false)
		c.pose("kick_right")
	c.impulsionar(Vector3.ZERO)
	if cnt10 <= 20:
		_teleportar(_ponto)
	# A descida bloco a bloco até o chão; do tick 20 em diante o corpo mergulha por ela,
	# ferindo a cada bloco (20, cubo de 6) e no chão (21, cubo de 12).
	var p := _ponto
	for i in int(24.0 * tam):
		if cnt10 >= 12:
			_luz(p, int(2.0 * tam), 0.25 * tam)
		if cnt10 >= 20:
			_teleportar(p)
			var a := B.Ataque.new(float(ficha.mergulho), 6.0 * tam, 1.5, false)
			B.ataque_em_area(c.ator, p, p, a, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
			B.empurrar_area(c.ator, p, p, 6.0 * tam, 1.5)
		if _solido(p):
			p -= Vector3.UP * B.METROS_POR_BLOCO
		elif _solido(p - Vector3.UP * B.METROS_POR_BLOCO):
			break
		else:
			p -= Vector3.UP * B.METROS_POR_BLOCO
	if cnt10 >= 20:
		if cnt10 == 20:
			_nsom("velocidade_soco", p, 2.0 * tam)
			_nsom("velocidade_soco", p, 2.0 * tam, 0.8)
			VfxGoroMinePiece.clarao(c.ator, p, B.m(4.0), 0.2, COR_LUZ)
			VfxFrutaMinePiece.onda_de_choque(c.ator, p, B.m(5.0), COR_LUZ, 0.4)
			VfxFrutaMinePiece.feixe(c.ator, _ponto, p, B.m(2.2 * tam), COR_LUZ, 0.45)   # o mergulho: coluna do alto até o impacto
		_luz(p, int(25.0 * tam), 2.0 * tam, 2.0, false)
		var a := B.Ataque.new(float(ficha.impacto_mergulho), 12.0 * tam, 1.5, false)
		B.ataque_em_area(c.ator, p, p, a, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
		B.empurrar_area(c.ator, p, p, 12.0 * tam, 1.5)
		VfxFrutaMinePiece.placa(c.ator, p, B.m(2.0 * tam), Color(0.1, 0.08, 0.02, 0.35), 6.0)
	else:
		# A luz girando em volta do ponto, com o zumbido de alta velocidade.
		var raio := B.m(16.0 * tam)
		for i in int(8.0 * tam):
			var ang := randf() * TAU
			_luz(p + Vector3(cos(ang) * raio, 0.0, sin(ang) * raio), 2, tam)
		if cnt10 % 2 == 1:
			_nsom("velocidade_passo", p + Vector3(raio, 0, 0), 2.0 * tam, randf_range(1.0, 1.25))


# ------------------------------------------------------ 29 Yasakani no Magatama
func _yasakani() -> void:
	cnt2 += 1
	var tam := _tamanho()
	var frente := _a_frente(0.75, 1.0 + B.LARGURA_JOGADOR)
	c.recarga = c.recarga_total   # COOLDOWN_TIME renovado em todo tick
	if cnt1 == 0:
		if cnt3 <= 0:
			if c.segurando:
				cnt3 = -2
				_carregar(0.1, frente)
				_luz(_meio(), int(2.0 * tam), 0.3)
			cnt3 = mini(cnt3 + 1, 0)
		if cnt3 >= 0:
			c.pose("invisibility")
			if cnt3 == 0:
				cnt2 = 0
				cnt3 = 1
				_origem = c.pe()
				# Salta: para cima (4 × tamanho blocos/tick); com S, para trás e para cima.
				var olhar: Vector3 = c.olhar()
				_vel_mc = Vector3(-olhar.x * 6.0, 4.0 * tam, -olhar.z * 6.0) if c.tras \
					else Vector3(c.ator.velocity.x / B.VELOCIDADE, 4.0 * tam, c.ator.velocity.z / B.VELOCIDADE)
				_luz(_meio(), int(2.0 * tam), 0.25 * tam, 0.05)
			elif _vel_mc.y < 0.2 or cnt2 > 5:
				cnt1 = 1
				_luz(_meio(), int(2.0 * tam), 0.25 * tam, 0.05)
			if cnt3 >= 1 and cnt1 == 0:
				# O corpo sobe com a física do Minecraft (gravidade 0,08, ar 0,98/0,91).
				c.impulsionar(_vel_mc)
				_vel_mc = Vector3(_vel_mc.x * 0.91, (_vel_mc.y - 0.08) * 0.98, _vel_mc.z * 0.91)
		return
	cnt1 += 1
	if cnt1 <= 10:
		if cnt1 == 2:
			_nsom("yasakani_disparo", frente, 2.0 * tam)
		_luz(frente, 2, 0.0)
	elif cnt1 < 40:
		cnt4 += 1
		var dano := ceilf(8.0 * float(Balance.MINE_PIECE_PIKA.flecha) * DAMAGE_FIX)
		var olhos: Vector3 = c.pe() + Vector3.UP * B.m(B.OLHOS_JOGADOR - 0.1)
		for i in 8:
			var rumo: Vector3 = c.olhar()
			# Projectile.shoot: direção + gaussiana × 0,0075 × imprecisão (35).
			rumo = (rumo.normalized() + Vector3(randfn(0.0, 1.0), randfn(0.0, 1.0), randfn(0.0, 1.0)) * 0.0075 * 35.0).normalized()
			var luz := Luz.new()
			luz.c = c.controlador()
			luz.rumo = rumo * 8.0
			luz.dano = dano
			luz.cnt6 = cnt6
			VfxGoroMinePiece._raiz(c.ator).add_child(luz)
			luz.global_position = olhos
		_luz(frente, 3, 0.1)
		_luz(_a_frente(0.75, -(5.0 + B.LARGURA_JOGADOR)), 1, 0.0, 0.0, true)
		if cnt1 % 2 == 1:
			_nsom("yasakani_final", c.pe(), 1.0)
	if cnt1 < 50:
		c.impulsionar(Vector3.ZERO)
		c.pose("yasakani_no_magatama")
	if cnt1 == 50:
		c.pose("invisibility")
		_luz(_meio(), int(2.0 * tam), 0.25 * tam, 0.05)
		_teleportar(_origem)
		_luz(_meio(), int(2.0 * tam), 0.25 * tam, 0.05)
	if cnt1 > 52:
		c.terminar()


# ------------------------------------------------------- 30 Ama no Murakumo
## SkillAmanoMurakumo: põe a espada de luz na mão (no mod, um item até ser largado).
## Aqui, decisão do dono: vira o item da fruta — o ícone da barra muda e a espada vai
## para a mão sempre que a fruta estiver equipada. Usar de novo larga.
func _ama_no_murakumo() -> void:
	var prog = _progresso()
	c.pose("both_arm_front")
	_nsom("espada_saca", c.pe())
	_nsom("espada_brilho", c.pe(), 0.8)
	if prog != null:
		prog.espada_da_fruta = "" if prog.espada_da_fruta == ESPADA else ESPADA
		prog.mudou.emit()
	c.terminar()

func _progresso():
	var cena: Node = c.get_tree().current_scene if c.is_inside_tree() else null
	return cena.get("progressao") if cena != null else null

## Cada quadro: com a fruta equipada e a espada pegada, ela fica na mão (EspadaDaHistoria
## com o modelo do mod); trocou de item, solta. A textura anima 5 quadros, 1 por tick.
func manter() -> void:
	var prog = _progresso()
	var arma = c.ator.get_node_or_null("EspadaDaHistoria") if is_instance_valid(c.ator) else null
	if arma == null or prog == null:
		return
	var quer: bool = prog.espada_da_fruta == ESPADA and c.fruta_ativa()
	if quer and not (arma.ativa and arma.espada_de_fruta()):
		if _cena_espada == null and ResourceLoader.exists(PASTA + "mp_espada_luz.glb"):
			_cena_espada = load(PASTA + "mp_espada_luz.glb")
		if _cena_espada == null:
			return
		var ficha: Dictionary = CatalogoFrutasMinePiece.FICHAS[CatalogoFrutasMinePiece.PIKA].espada
		arma.aplicar_espada_de_fruta(true, _cena_espada, Vector3.ZERO,
			Vector3(0, B.m(float(ficha.alcance_blocos)), 0), float(ficha.multiplicador))
		_brilho_da_espada(arma.visual())
	elif not quer and arma.espada_de_fruta():
		arma.aplicar_espada_de_fruta(false)
	if quer and arma.visual() != null:
		var m := arma.visual().get_meta("material_luz", null) as StandardMaterial3D
		if m != null:
			m.uv1_offset.y = float(int(Time.get_ticks_msec() / 50) % 5) * 0.2

## A espada brilha (textura animada do mod, sem luz, aditiva) e tem o tamanho do display
## de terceira pessoa (escala 2 × 15/16 do corpo do jogador).
func _brilho_da_espada(v: Node3D) -> void:
	if v == null:
		return
	v.scale *= B.METROS_POR_BLOCO * 2.0 * 0.9375
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PASTA + "espada_luz_tira.png"):
		m.albedo_texture = load(PASTA + "espada_luz_tira.png")
	m.uv1_scale = Vector3(1.0, 0.2, 1.0)
	for malha in v.find_children("*", "MeshInstance3D", true, false):
		(malha as MeshInstance3D).material_override = m
		(malha as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.set_meta("material_luz", m)


# ------------------------------------------------------------- 28 passiva
## SkillPikaPikaPassive1 (a mesma da Goro, com luz no lugar do raio): dois ticks presos e
## invisível, depois 64 passos de 0,5 bloco para a frente (W) ou para trás (S); para a
## frente para no primeiro alvo. Sem custo.
func _passiva() -> void:
	cnt2 += 1
	var tam := _tamanho()
	if cnt2 < 2:
		c.lentidao = 9
		if cnt2 == 1:
			cnt1 = c.toque
			c.invisivel(true)
		return
	cnt3 += 1
	if cnt3 == 1:
		_nsom("passiva_ida", _meio(), tam)
		_luz(_meio(), int(5.0 * tam), 0.1 * tam, 0.5)
		var pe: Vector3 = c.pe()
		var p: Vector3 = c.olhar() * B.m(0.5 * cnt1)
		for i in 64:
			if cnt1 == 1 and B.primeiro_no_cubo(c.ator, pe, 3.0 * tam) != null:
				break
			var preso := true
			for eixo in [Vector3(p.x, 0, 0), Vector3(0, 0, p.z)]:
				if not _solido(pe + eixo):
					pe += eixo
					preso = false
			if preso:
				for j in 8:
					if not _solido(pe + Vector3.UP * B.METROS_POR_BLOCO):
						pe += Vector3.UP * B.METROS_POR_BLOCO
					if not _solido(pe + p):
						preso = false
						break
			if not _solido(pe + Vector3(0, p.y, 0)):
				preso = false
				pe.y += p.y
			if preso:
				break
			if i % 4 == 0:
				_luz(pe + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), 1, 0.1 * tam)
		_teleportar(pe)
		_nsom("passiva_chegada", _meio(), tam)
		c.invisivel(false)
	if cnt3 > 3:
		c.terminar()
