extends Node
## Hie Hie no Mi (Mine Piece v14), SkillHieHieProcedure — as técnicas do ciclo R:
##   21 Ice Block: Partisan  (IceBlockPartisan; com Shift: IceBlockPartisan2)
##   22 Ice Block: Pheasant Beak (IceBlockPheasantBeak)
##   24 Ice Ball (IceBallProcedure)
##   25 Ice Age (IceAgeProcedure)
## O 23 (IceSpikes) existe no despacho mas não no ciclo do jogador: fica fora, como no mod.
## Contadores com os nomes do mod (cnt1…cnt9); cnt6 é a carga (0 → 5, CNT6 = 1 + cnt6/10).
## Adaptações declaradas: BlockToIce vira placa de gelo no chão (o mapa não muda); a
## "explosão" de potência 0 da carga cheia vira clarão; sons vanilla (vidro, wither,
## respiração) usam o ice_generate do mod; as bolas de gelo extras da Ice Age só saem com
## Força > 9, efeito que o jogo não tem; Lentidão/congelamento leve nos alvos (Effect12
## antes do gelo) não entram — o gelo já prende.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const Lanca := preload("res://src/combat/frutas_mine_piece/lanca_de_gelo_hie.gd")
const Gelo := preload("res://src/combat/frutas_mine_piece/gelo_hie.gd")
const EraVisivel := preload("res://src/combat/frutas_mine_piece/era_do_gelo_visivel.gd")
const FrenteVisivel := preload("res://src/combat/frutas_mine_piece/frente_de_gelo_visivel.gd")
const PASTA := "res://assets/mine_piece/frutas/hie/"
## Um conjunto de sons por ataque (24/11/2026, `tools/generate_hie_audio.py`); o ice_generate do mod ficou só como reserva.
const SONS := PASTA + "sons/hie_"
const COR_GELO := Color(0.55, 0.8, 0.97, 0.42)   # packed_ice
## DamageFix com a mão vazia: atributo de ataque 1 → ×(1 + 0,333 × 0,333).
const DAMAGE_FIX := 1.0 + 0.333 * 0.333

var c
var tecnica := 0
var cnt1 := 0
var cnt2 := 0
var cnt3 := 0
var cnt4 := 0
var cnt5 := 0
var cnt6 := 0.0
var cnt7 := 0.0
var cnt9 := 0
var _alvo := Vector3.ZERO      # x/y/z_pos do mod: para onde as lanças olham
var _frente := Vector3.ZERO    # IceBall: a frente que avança
var _rumo := Vector3.FORWARD   # IceBall: cnt7/cnt8/cnt9 (o look do disparo)
var _era: Node3D                # Ice Age: o desenho (disco, cristais, névoa) que acompanha o raio do dano
var _estacas: Node3D            # Ice Ball: as estacas de gelo que brotam ao longo da frente (referência do Codex)

func iniciar(numero: int) -> void:
	tecnica = numero
	cnt1 = 0; cnt2 = 0; cnt3 = 0; cnt4 = 0; cnt5 = 0; cnt9 = 0
	cnt6 = 0.0; cnt7 = 0.0

func cancelar() -> void:
	# lanças, pássaros e gelo vivem sozinhos, como as entidades do mod; só o desenho da Ice Age é nosso.
	if is_instance_valid(_era):
		_era.encerrar()
	_era = null
	if is_instance_valid(_estacas):
		_estacas.encerrar()
	_estacas = null

func passo() -> void:
	match tecnica:
		21:
			_partisan()
		22:
			_bico_de_faisao()
		24:
			_bola_de_gelo()
		25:
			_era_do_gelo()
		_:
			c.terminar()


# ------------------------------------------------------------------ comum
func _k6() -> float:
	return 1.0 + cnt6 * 0.1

## A carga do mod: +0,1 por tick até 5; ao passar de 5, a explosão de potência 0 (clarão).
func _carregar(onde: Vector3, com_som := false) -> void:
	if cnt6 > 5.0:
		cnt6 = 5.0
		VfxGoroMinePiece.clarao(c.ator, onde, 1.5)
		if com_som:
			VfxFrutaMinePiece.som(c.ator, SONS + "bico_carga.wav", c.pe(), _k6())
	elif cnt6 < 5.0:
		cnt6 = snappedf(cnt6 + 0.1, 0.01)
		if is_equal_approx(cnt6, 5.0):
			cnt6 = 5.01

func _tamanho() -> float:
	return B.tamanho(B.ALTURA_JOGADOR, B.LARGURA_JOGADOR)

## A frente do corpo no mod: pé + altura × `altura` + look × `dist` blocos.
func _a_frente(altura: float, dist: float) -> Vector3:
	return c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * altura) + c.olhar() * B.m(dist)

func _particulas_de_carga() -> void:
	var meio: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)
	VfxFrutaMinePiece.particulas(c.ator, PASTA + "particle_ice.png", 12, meio, int(2.0 * _tamanho()),
		Vector3(B.m(B.LARGURA_JOGADOR * 0.5), B.m(B.ALTURA_JOGADOR * 0.5), B.m(B.LARGURA_JOGADOR * 0.5)), 0.0, 0.4, 0.35)

## A busca de alvo das lanças: 8 trechos de 6 blocos na mira (até o bloco), cubo de 12.
func _buscar_alvo() -> Vector3:
	var olhos: Vector3 = c.pe() + Vector3.UP * B.m(B.OLHOS_JOGADOR)
	var rumo: Vector3 = c.olhar()
	var ponto := olhos
	var dis := 6.0
	for i in 8:
		var ate := olhos + rumo * B.m(dis)
		var hit: Dictionary = c.ator.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(olhos, ate, B.MASCARA_MUNDO, [c.ator.get_rid()]))
		ponto = hit.position if not hit.is_empty() else ate
		var alvo := _alvo_nao_municao(ponto, 12.0)
		if alvo != null:
			return AlvosDeGolpe.centro(alvo)
		dis += 6.0
	return ponto

func _alvo_nao_municao(centro: Vector3, lado_b: float) -> Node3D:
	for alvo in AlvosDeGolpe.todos(c.ator.get_tree()):
		if alvo.has_meta(B.DONO):
			continue   # forge:ranged_ammo
		if B.atacavel(c.ator, alvo) and B.no_cubo(alvo, centro, lado_b):
			return alvo
	return null

func _lanca(onde: Vector3, passaro: bool, tamanho: float, carga: float, rumo: Vector3, vida: float) -> void:
	var n := Lanca.new()
	n.c = c.controlador()   # a lança vive além da sessão da técnica: o dono dela é o controlador
	n.passaro = passaro
	n.tamanho = tamanho
	n.cnt6 = carga
	n.rumo = rumo.normalized() if rumo.length_squared() > 0.0001 else c.olhar()
	n.health = vida
	c.get_tree().current_scene.add_child(n)
	n.global_position = onde

## A lateral do mod: cos(yaw + 90°)/sin(yaw + 90°) × cos(pitch) — a direita do corpo,
## encolhida quando a mira sobe ou desce.
func _direita() -> Vector3:
	var look: Vector3 = c.olhar()
	var plano := Vector3(look.x, 0.0, look.z)
	if plano.length_squared() < 0.0001:
		plano = RosaDosVentos.frente(c.ator._yaw)
	return plano.normalized().cross(Vector3.UP) * plano.length()

## RangeAttack com o efeito 12; `extra_cnt6` é o "cnt6 + 5" que o mod põe só durante o ataque
## (decide a vida da bola de gelo).
func _ataque_gelo(centro: Vector3, dano: float, lado_b: float, empurrao: float, extra_cnt6: float) -> void:
	var a := B.Ataque.new(dano, lado_b, empurrao, false)
	a.ignora_guarda = true
	var carga_do_gelo := cnt6 + extra_cnt6
	a.ao_ferir = func(alvo: Node) -> void:
		Gelo.congelar(c.ator, c.ator, alvo as Node3D, carga_do_gelo, B.ALTURA_JOGADOR, B.LARGURA_JOGADOR)
	B.ataque_em_area(c.ator, c.pe(), centro, a, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 1.0)


# ------------------------------------------------------- 21 Ice Block: Partisan
func _partisan() -> void:
	cnt1 += 1
	cnt2 += 1
	if cnt2 == 1:
		cnt5 = 1 if c.shift else 0
		VfxFrutaMinePiece.som(c.ator, SONS + "partisan_carga.wav", c.pe(), 0.8)
	if cnt5 == 1:
		_partisan_atras()
		return
	var tam := _tamanho()
	var frente := _a_frente(0.75, 1.0 + B.LARGURA_JOGADOR)
	var k6 := _k6()
	if cnt1 < 8:
		c.lentidao = 4
		c.recarga = c.recarga_total   # COOLDOWN_TIME renovado durante a carga
		_particulas_de_carga()
		if cnt1 >= 6 and c.segurando:
			cnt1 = mini(cnt1, 6)
			_carregar(frente)
	else:
		cnt3 += 1
		if cnt3 > 5:
			c.terminar()
			return
	if cnt3 > 1:
		return
	c.pose("yasakani_no_magatama")
	_alvo = _buscar_alvo()
	var distancia := 6.0 * tam * minf(cnt2 * 0.1 + 0.5, 1.0)
	var lado := _direita()
	var num1 := 0
	for i in 4:
		if num1 == 2:
			lado = -lado
		# O mod usa Math.sin(-45) em RADIANOS (o seno de −45 rad), não −45°: preservado.
		var altura := sin(-45.0) * -1.0 * distancia if num1 >= 1 and num1 <= 2 else 0.0
		var onde := frente + lado * B.m(distancia) + Vector3.UP * B.m(altura)
		if cnt3 == 1:
			_lanca(onde, false, 1.5 * k6 * tam, cnt6, _alvo - onde,
				float(Balance.MINE_PIECE_HIE.vida_partisan))
		else:
			VfxFrutaMinePiece.particulas(c.ator, PASTA + "particle_ice.png", 12, onde,
				int(tam * k6 * 0.5) + 1, Vector3.ONE * B.m(tam * k6 * 0.1), 0.0, 0.4, 0.4)
		num1 += 1
	if cnt3 == 1:
		VfxFrutaMinePiece.som(c.ator, SONS + "partisan_lancas.wav", frente, 1.0)


## IceBlockPartisan2 (Shift): lanças atrás do corpo, uma a cada 2 ticks numa das 5
## posições do leque; segurar Z mantém até cnt2 = 50.
func _partisan_atras() -> void:
	var tam := _tamanho()
	var atras := _a_frente(0.75, -3.0 - B.LARGURA_JOGADOR)
	var k6 := _k6()
	c.lentidao = 4
	c.recarga = c.recarga_total
	if cnt1 >= 8:
		cnt3 += 1
		if cnt3 > 19 and cnt2 < 50 and c.segurando:
			cnt3 = mini(cnt3, 19)
		if cnt3 > 20:
			c.terminar()
			return
	if cnt2 % 4 == 1:
		c.pose("right_arm_front")
	var atacar := cnt3 > 0 and cnt2 % 2 == 1
	if atacar:
		_alvo = _buscar_alvo()
	var distancia := 8.0 * tam * minf(cnt2 * 0.5, 1.0)
	var sorteio := randi_range(0, 4)
	var lado := _direita()
	for num1 in 5:
		var arco := 0.0 if num1 == 0 or num1 == 4 else (-90.0 if num1 == 2 else -45.0)
		if num1 == 2:
			lado = -lado
		var onde := atras + lado * B.m(distancia) + Vector3.UP * B.m(sin(arco) * -1.0 * distancia)
		VfxFrutaMinePiece.particulas(c.ator, PASTA + "particle_ice.png", 12, onde,
			int(tam * k6 * 0.5) + 1, Vector3.ONE * B.m(tam * k6 * 0.1), 0.0, 0.4, 0.4)
		if atacar and num1 == sorteio:
			_lanca(onde, false, 1.5 * k6 * tam, -1.0, _alvo - onde,
				float(Balance.MINE_PIECE_HIE.vida_partisan))
	if atacar:
		VfxFrutaMinePiece.som(c.ator, SONS + "partisan_lancas.wav", atras, 1.0)


# -------------------------------------------------- 22 Ice Block: Pheasant Beak
func _bico_de_faisao() -> void:
	cnt1 += 1
	cnt2 += 1
	var frente := _a_frente(0.7, 1.0 + B.LARGURA_JOGADOR)
	var k6 := _k6()
	if cnt1 < 8:
		c.lentidao = 4
		c.recarga = c.recarga_total
		_particulas_de_carga()
		if cnt1 >= 6 and c.segurando:
			cnt1 = mini(cnt1, 6)
			_carregar(frente, true)
		c.pose("right_arm_front")
		return
	cnt3 += 1
	if cnt3 == 1:
		c.pose("punch_right")
		VfxFrutaMinePiece.particulas(c.ator, PASTA + "particle_ice.png", 12, frente, int(cnt6 * 5.0) + 1,
			Vector3.ONE * B.m(0.1 + cnt6 * 0.2), B.VELOCIDADE * 0.25, 0.6, 0.5)
		VfxFrutaMinePiece.som(c.ator, SONS + "bico_voo.wav", c.pe(), k6)
		_lanca(frente - Vector3.UP * B.m(3.0), true, 2.0 * k6, cnt6, c.olhar(),
			float(Balance.MINE_PIECE_HIE.vida_passaro))
	elif cnt3 > 5:
		c.terminar()


# --------------------------------------------------------------- 24 Ice Ball
func _bola_de_gelo() -> void:
	cnt1 += 1
	cnt4 += 1
	var frente := _a_frente(0.6, 1.5 + B.LARGURA_JOGADOR)
	if cnt4 == 1:
		VfxFrutaMinePiece.som(c.ator, SONS + "bola_carga.wav", c.pe(), 0.8)
	if cnt1 < 5:
		c.lentidao = 5
		c.recarga = c.recarga_total
		if cnt4 % 5 == 1:
			c.pose("both_arm_front")
		if c.segurando:
			cnt1 = mini(cnt1, 3)
		if cnt1 >= 3:
			if cnt6 < 5.0:
				cnt6 = snappedf(cnt6 + 0.1, 0.01)
			else:
				cnt6 = 5.0
				if cnt7 == 0.0:
					cnt7 = 1.0
					VfxGoroMinePiece.clarao(c.ator, frente, 1.5)
					VfxFrutaMinePiece.onda_de_choque(c.ator, frente, B.m(3.0 * _tamanho()), Color(0.55, 0.85, 1.0), 0.4)
	var k6 := _k6()
	if cnt1 < 5:
		return
	cnt2 += 1
	if cnt1 == 5:
		_rumo = c.olhar()
		_frente = frente
		VfxFrutaMinePiece.som(c.ator, SONS + "bola_rajada.wav", frente, k6)
		c.pose("punch_right")
	var alcance := minf(0.75, cnt2 * 0.05)
	if cnt2 < 12:
		for i in 4:
			_ataque_gelo(_frente, float(Balance.MINE_PIECE_HIE.bola) * k6, maxf(16.0 * alcance, 3.0), 0.01, 5.0)
			if not is_instance_valid(_estacas):
				_estacas = FrenteVisivel.criar(c.get_tree().current_scene)
			_estacas.espetar(_frente, _rumo, B.m(maxf(8.0 * alcance, 3.0)))
			VfxFrutaMinePiece.placa(c.ator, _frente, B.m(maxf(8.0 * alcance, 3.0)), COR_GELO)
			_frente += _rumo * B.METROS_POR_BLOCO
		var base := _a_frente(0.75, 1.0 + B.LARGURA_JOGADOR)
		VfxFrutaMinePiece.particulas(c.ator, PASTA + "particle_ice.png", 12, (base + _frente) * 0.5,
			int(8.0 * alcance) * 4 + 2, Vector3.ONE * B.m(alcance * 1.5), B.VELOCIDADE * 0.3, 0.5, 0.6, 48)
	if cnt2 >= 12:
		if is_instance_valid(_estacas):
			_estacas.encerrar()
		_estacas = null
		c.terminar()


# ---------------------------------------------------------------- 25 Ice Age
func _era_do_gelo() -> void:
	cnt1 += 1
	cnt9 += 1
	c.lentidao = 5
	var tam := _tamanho()
	var pe: Vector3 = c.pe()
	if cnt1 == 1:
		VfxFrutaMinePiece.som(c.ator, SONS + "era_carga.wav", pe, 1.0)
	if cnt9 % 5 == 1:
		c.pose("yamiyami_blackhole")
	if cnt1 <= 10:
		c.lentidao = 9
		c.recarga = c.recarga_total
		if c.segurando:
			cnt1 = mini(cnt1, 9)
		if cnt1 >= 4:
			if cnt6 < 5.0:
				cnt6 = snappedf(cnt6 + 0.1, 0.01)
			else:
				cnt6 = 5.0
				if cnt7 == 0.0:
					cnt7 = 1.0
					VfxGoroMinePiece.clarao(c.ator, pe, 2.0)
					VfxFrutaMinePiece.onda_de_choque(c.ator, pe, B.m(12.0 * tam), Color(0.55, 0.85, 1.0), 0.7)
		VfxFrutaMinePiece.particulas(c.ator, PASTA + "particle_ice.png", 12, pe, int(4.0 * tam),
			Vector3(B.m(0.5 * tam), 0.0, B.m(0.5 * tam)), 0.5 * B.VELOCIDADE * 0.1, 0.5, 0.4)
		return
	var k6 := _k6()
	cnt2 += 1
	if cnt2 == 1:
		VfxFrutaMinePiece.som(c.ator, SONS + "era_expande.wav", pe, k6)
	var ajuste := sqrt((20.0 + cnt2 * 0.1) * k6 * DAMAGE_FIX / 20.0)
	var dano := (float(Balance.MINE_PIECE_HIE.ice_age) + cnt2 * 0.1) * k6
	_ataque_gelo(pe, dano, minf(16.0, cnt2 * 2.0) * ajuste, 0.1 * k6, 5.0)
	# O VISÍVEL (15/11/2026): o mesmo raio do dano vira disco de geada + cristais + névoa. Antes só havia a placa translúcida.
	if not is_instance_valid(_era):
		var final := B.m(16.0 * sqrt((20.0 + 8 * 0.1) * k6 * DAMAGE_FIX / 20.0))
		_era = EraVisivel.criar(c.get_tree().current_scene, pe, c.ator, final)
	_era.set_raio(B.m(minf(16.0, cnt2 * 2.0) * ajuste))
	# A placa quadrada translúcida (BlockToIce do mod) saiu daqui: o disco de geada da `EraVisivel` já marca o chão e a placa aparecia como retângulos soltos (revisão do Codex, 24/11/2026).
	VfxFrutaMinePiece.particulas(c.ator, PASTA + "particle_ice.png", 12, pe + Vector3.UP * B.m(0.25 * tam),
		int(12.0 * tam * k6), Vector3(B.m(minf(8.0, cnt2 * 0.75 + 2.0) * ajuste), B.m(0.5 * tam),
		B.m(minf(8.0, cnt2 * 0.75 + 2.0) * ajuste)), B.VELOCIDADE * 0.1 * k6, 0.6, 0.6, 48)
	if cnt2 > 8:
		if is_instance_valid(_era):
			_era.encerrar()
		_era = null
		c.terminar()
