class_name TecnicasGoroMinePiece
extends RefCounted
# ============================================================================
#  AS TÉCNICAS DA GORO GORO NO MI DO MINE PIECE v14, TRADUZIDAS TICK A TICK.
#
#  `SkillGoroGoroProcedure` despacha pelo número da técnica (`skill % 50`):
#    21 Vari · 22 El Thor (agachado: ElThorFall) · 23 Sango · 25 Mamaragan
#    27 Kari Krash (contra-ataque da defesa perfeita) · 28 passiva (toque duplo W/S)
#    29 Raigo (só com o efeito Mamaragan)
#  Cada função roda UMA vez por tick (20/s) enquanto `D.skill` for a técnica, lendo e
#  escrevendo os mesmos contadores do mod (`cnt1`…`cnt6`, `cnt10`, `x_pos`…) em `c.D`.
#  As distâncias ficam em BLOCOS como no Java e só viram metros em `c.frente`,
#  `c.passo` etc. — é o que deixa conferir linha a linha contra a fonte.
#
#  Fonte: ~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14 (procedures/).
#  Adaptações declaradas (o resto é literal):
#    • a mira do JOGADOR é o retículo (`c.olhar`), regra do projeto para golpe que sai
#      do corpo; o mod usa o vetor de visão, que no Minecraft é a mesma reta;
#    • ElThorFall: o mod só mira por alvo de Mob; para jogador ele reaproveita a posição
#      guardada pela técnica anterior (defeito). Aqui o jogador mira pelo retículo;
#    • raios do céu: o mod começa em max(y + 64, 194) — 194 é o teto do mundo do
#      Minecraft. Aqui, 64 blocos acima do centro;
#    • quebra de blocos → marca visual (decisão do dono); "explosão" de carga cheia
#      (potência 0, sem dano) → clarão e som.
# ============================================================================

const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const DANO := Balance.MINE_PIECE_GORO
const Ataque := B.Ataque

var c   # GoroGoroMinePiece (o dono do estado, do corpo e da mira)


func _init(controlador) -> void:
	c = controlador


func executar(skill: int) -> void:
	match skill:
		21: vari()
		22: el_thor()
		23: sango()
		25: mamaragan()
		27: kari_krash()
		28: passiva()
		29: raigo()
		_:
			push_warning("Error : Goro Goro - %d" % skill)
			c.encerrar()


# --------------------------------------------------------------------- comuns
func _n(chave: String) -> float:
	return float(c.D.get(chave, 0.0))


func _somar(chave: String, v := 1.0) -> float:
	c.D[chave] = _n(chave) + v
	return c.D[chave]


func _cnt6_fator() -> float:
	return 1.0 + _n("cnt6") * 0.1


## A carga que todas as técnicas de segurar repetem: +0,1 por tick até 5; ao encher,
## a "explosão" de potência 0 do mod (sem dano, só o estouro).
func _carregar(onde: Vector3) -> void:
	if _n("cnt6") < 5.0:
		_somar("cnt6", 0.1)
		if _n("cnt6") >= 5.0:
			c.D["cnt6"] = 5.0
			c.fx_clarao(onde, 2.0)
			c.fx_som(onde, "sons/goro_carga", -4.0)


## As faíscas do corpo enquanto carrega (mais fortes com a carga cheia).
func _faiscas_de_carga() -> void:
	c.fx_faiscas(c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), int(2.0 * c.r),
		B.m(B.LARGURA_JOGADOR * 0.5), 3.0 if _n("cnt6") >= 5.0 else 1.0)


## O teleporte elétrico do Vari e da passiva: até `passos` passos de `velocidade`
## blocos na direção da mira, subindo degraus de até 8 blocos; para ao encostar num
## alvo (cubo de 3 × tamanho) quando `para_no_alvo`.
func _relampejar(velocidade: float, passos: int, para_no_alvo: bool) -> void:
	var pos: Vector3 = c.pe()
	var p: Vector3 = c.olhar() * B.m(velocidade)
	var um := B.m(1.0)
	for i in passos:
		var preso := true
		if para_no_alvo and B.primeiro_no_cubo(c.ator, pos, 3.0 * c.r) != null:
			break
		if not c.solido(pos + Vector3(p.x, 0, 0)):
			preso = false
			pos.x += p.x
		if not c.solido(pos + Vector3(0, 0, p.z)):
			preso = false
			pos.z += p.z
		if preso:
			for j in 8:
				if not c.solido(pos + Vector3.UP * um):
					pos.y += um
				if not c.solido(pos + p):
					preso = false
					break
		if not c.solido(pos + Vector3(0, p.y, 0)):
			preso = false
			pos.y += p.y
		if preso:
			break
	c.teleportar(pos)


func _estalo_no_corpo() -> void:
	var meio: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)
	c.fx_som(meio, "sons/goro_estalo", -6.0)
	c.fx_faiscas(meio, int(6.0 * c.r), B.m(0.1 * c.r), 6.0)


# ------------------------------------------------------------------ 21 · Vari
func vari() -> void:
	_somar("cnt2")
	var cnt6 := _cnt6_fator()
	if _n("cnt2") < 2.0:
		c.travar()
		if c.z:
			c.D["cnt2"] = 0.0
		_carregar(c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5))
		_faiscas_de_carga()
		if _n("cnt2") == 1.0:
			c.invisivel(0.5)   # anim -21/0 "invisibility" + Invisibilidade 5 ticks
		return
	var cnt3 := _somar("cnt3")
	if cnt3 == 1.0:
		c.fx_som(c.pe(), "sons/goro_passiva", -3.0)
		_estalo_no_corpo()
		_relampejar(0.5, 96, true)
		_estalo_no_corpo()
	c.pose("right_arm_front2")   # -19/2
	c.parar()
	if cnt3 > 5.0:
		var pos: Vector3 = c.frente(2.0 + c.r, 0.75)
		if cnt3 <= 6.0:
			c.fx_som(pos, "sons/goro_vari_trovao", 0.0)
			c.fx_marca(pos, B.m(12.0 * c.r) * 0.5)
		c.atacar(pos, Ataque.new((DANO.vari + cnt3 * 0.01) * cnt6, 24.0 * c.r, 0.1))
		c.fx_faiscas(pos, int(50.0 * c.r), B.m(0.1 * c.r), 12.0)
		c.fx_relampago(c.frente(0.6, 0.75), pos)
		c.fx_descarga(pos, B.m(6.0 * c.r))
		if fmod(cnt3, 3.0) == 2.0:
			c.fx_faiscas(pos, int(20.0 * c.r), B.m(4.0 * c.r), 1.0)
		if cnt3 > 18.0:
			c.encerrar()


# ---------------------------------------------------- 28 · passiva (toque duplo)
func passiva() -> void:
	var cnt2 := _somar("cnt2")
	if cnt2 < 2.0:
		c.travar()
		if cnt2 == 1.0:
			if _n("cnt1") == 0.0:
				c.D["cnt1"] = -1.0 if c.s else 1.0
			c.invisivel(0.5)
		return
	var cnt3 := _somar("cnt3")
	if cnt3 == 1.0:
		c.fx_som(c.pe(), "sons/goro_passiva", -3.0)
		_estalo_no_corpo()
		_relampejar(0.5 * _n("cnt1"), 64, _n("cnt1") == 1.0)
		_estalo_no_corpo()
	if cnt3 > 3.0:
		c.encerrar()


# -------------------------------------------------------------- 22 · El Thor
func el_thor() -> void:
	var cnt1 := _somar("cnt1")
	_somar("cnt2")
	var cnt6 := _cnt6_fator()
	if cnt1 < 10.0:
		c.travar()
		if cnt1 >= 9.0 and c.z:
			c.D["cnt1"] = minf(_n("cnt1"), 8.0)
			_carregar(c.frente(0.5 + 0.5 * B.LARGURA_JOGADOR, 0.75, false, PI))
		_faiscas_de_carga()
		if cnt1 == 1.0:
			c.pose("energy_charge")   # -19/3
		return
	c.travar()
	_somar("cnt6", 0.01)
	if cnt1 == 10.0:
		if c.shift:
			c.D["cnt10"] = 1.0
		c.pose("punch_overhead" if _n("cnt10") > 0.0 else "punch_right_jinbe")   # 4/0 · -7/5
	if _n("cnt10") > 0.0:
		_el_thor_queda(cnt6)
	elif cnt1 < 15.0:
		c.fx_clarao(c.frente(2.0 + B.LARGURA_JOGADOR, 0.65, false), B.m(c.r))
	else:
		var cnt3 := _somar("cnt3")
		if cnt1 <= 15.0:
			var inicio: Vector3 = c.frente(1.0 + B.LARGURA_JOGADOR, 0.75)
			c.fx_som(inicio, "sons/goro_el_thor_feixe", 0.0)
			c.D["pos"] = inicio
			c.D["power"] = c.olhar()
		if cnt1 < 35.0:
			_feixe(cnt1, cnt3, cnt6, 1.0 + B.LARGURA_JOGADOR, 4.0, 8.0, 20.0, 6.0, 3.0, 6.0)
	if cnt1 > 35.0:
		c.encerrar()


## O laço do feixe (El Thor e ElThorFall): `min(cnt3 × 21, 64)` passos de 1 bloco a
## partir de `D.pos` na direção `D.power`; um RangeAttack de lado `lado` × tamanho a
## cada (`espaco` × tamanho / 2 + 1) blocos, começando quando `distancia` passa de 0;
## onde a caixa de `lado_solido` (rebaixada `descer` blocos) toca o mundo, a marca.
func _feixe(cnt1: float, cnt3: float, cnt6: float, distancia: float, espaco: float, lado: float,
		forte_depois: float, lado_solido: float, descer: float, raio_marca: float) -> void:
	var pos: Vector3 = c.D.get("pos", c.pe())
	var p: Vector3 = c.D.get("power", Vector3.DOWN)
	var passo := B.m(1.0)
	var passos := int(minf(cnt3 * 21.0, 64.0))
	var dis := 0.0
	var forte := cnt1 > forte_depois
	var dano := ((DANO.el_thor_forte if forte else DANO.el_thor) + 0.001 * cnt3) * cnt6
	var inicio := pos
	for i in passos:
		if distancia > 0.0:
			distancia = espaco * c.r * -0.5
			c.atacar(pos, Ataque.new(dano, lado * c.r, 0.5 if forte else 0.1))
		var desce := Vector3.UP * B.m(descer * c.r)
		if c.solido(pos - desce, lado_solido * c.r, lado_solido * c.r):
			if descer == 0.0 and not c.solido(pos - p * passo, lado_solido * c.r, lado_solido * c.r):
				c.fx_fumaca(pos, int(4.0 * c.r), B.m(0.25 * c.r))   # o pilar entrando no chão
			if dis > 0.0:
				dis = 4.0 * c.r * -0.5
				c.fx_marca(pos, B.m(raio_marca * c.r) * 0.5)
		pos += p * passo
		dis += 1.0
		distancia += 1.0
	if passos > 0:
		c.fx_feixe(inicio, pos, B.m(c.r * 0.5))


## ElThorFall: o pilar que cai do céu (El Thor com Shift no disparo).
func _el_thor_queda(cnt6: float) -> void:
	var cnt1 := _n("cnt1")
	if cnt1 < 15.0:
		if cnt1 == 10.0:
			c.D["pos"] = c.alvo_na_mira(16, 6.0, 12.0) + Vector3.UP * B.m(24.0)
		else:
			c.fx_clarao(c.D.get("pos", c.pe()) - Vector3.UP * B.m(8.0), B.m(c.r) * 4.0)
		return
	var cnt3 := _somar("cnt3")
	if cnt1 <= 15.0:
		c.fx_som(c.D.pos, "sons/goro_el_thor_queda", 0.0)
	c.D["power"] = Vector3.DOWN
	if cnt1 < 35.0:
		_feixe(cnt1, cnt3, cnt6, 0.0, 15.0, 20.0, 25.0, 10.0, 0.0, 10.0)


# ---------------------------------------------------------------- 23 · Sango
func sango() -> void:
	var cnt1 := _somar("cnt1")
	_somar("cnt2")
	var cnt6 := _cnt6_fator()
	if cnt1 < 10.0:
		c.travar()
		if cnt1 >= 9.0 and c.z:
			c.D["cnt1"] = minf(_n("cnt1"), 8.0)
			_carregar(c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5))
		_faiscas_de_carga()
		c.pose("right_arm_up")   # -3/0
		return
	c.travar()
	var cnt3 := _somar("cnt3")
	c.pose("right_arm_up")
	if cnt3 < 5.0:
		var cabeca: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR + 1.0)
		if cnt3 == 1.0:
			c.fx_som(cabeca, "sons/goro_sango_raio", 0.0)
		var ceu := cabeca + Vector3(B.m(randi_range(-16, 16)), B.m(32.0), B.m(randi_range(-16, 16)))
		relampago(cabeca, ceu, _n("cnt6"))
	else:
		if cnt3 == 5.0:
			c.D["centro"] = c.alvo_na_mira(10, 6.0, 12.0)
		if cnt3 < 30.0:
			for i in randi_range(2, 4):
				var centro: Vector3 = c.D.get("centro", c.pe())
				var onde := raio_do_ceu(centro, 32.0, 10.0)
				c.atacar(onde, Ataque.new(DANO.sango * cnt6, 10.0, 0.1))
				if randf() < 0.25:
					c.criar_onda(onde, -5.0 + 0.5 * _n("cnt6"))
				else:
					c.fx_marca(onde, B.m(5.0) * 0.5)
	if cnt1 > 35.0:
		c.encerrar()


## LightningStrike2Procedure: o raio em zigue-zague de `de` até `ate`, em passos de
## 1/4 de bloco; a cada 4 passos um RangeAttack de lado 5 e, se o ponto estiver dentro
## de bloco, a marca e o fim do raio.
func relampago(de: Vector3, ate: Vector3, cnt6: float) -> void:
	var energia := 1.0 + cnt6 * 0.1
	var pos := de
	var pontos := PackedVector3Array([de])
	var total := int(round(de.distance_to(ate) / B.METROS_POR_BLOCO * 4.0 + 4.0))
	var alvo := ate
	for i in range(1, total + 1):
		var resto := alvo - pos
		var dis := resto.length()
		if dis < 0.0001:
			break
		if i < total and i % 4 == 1:
			# O mod sorteia até 8 desvios em volta do alvo (± 1,5 × a distância que falta).
			alvo = ate + Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * minf(dis, B.m(2.0)) * 3.0
			resto = alvo - pos
		pos += resto.normalized() * minf(B.m(0.25), dis)
		if i % 2 == 0:
			pontos.append(pos)
		if i % 4 == 0:
			c.atacar(pos, Ataque.new(DANO.relampago * energia, 5.0, 0.1))
			if c.solido(pos - Vector3.UP * B.m(0.5), 1.0, 1.0):
				c.fx_faiscas(pos, int(20.0 * energia), B.m(0.25), 6.0)
				c.fx_marca(pos, B.m(2.0))
				break
	pontos.append(pos)
	c.fx_raio(pontos, 0.25)


## O raio que cai do céu do Sango e da tempestade do Mamaragan: nasce a ± `espalha`
## blocos do `centro`, 64 blocos acima, e desce 2 blocos por passo (até 256) até um
## alvo entrar no cubo de `lado` blocos — e aí cai NELE — ou a caixa 5 × 5 tocar o
## mundo. Devolve o ponto de impacto.
func raio_do_ceu(centro: Vector3, espalha: float, lado: float) -> Vector3:
	var x := centro.x + B.m(randf_range(-espalha, espalha))
	var z := centro.z + B.m(randf_range(-espalha, espalha))
	var topo := centro.y + B.m(64.0)
	var passo := B.m(2.0)
	var fundo: float = c.chao_da_coluna(Vector3(x, topo, z), 5.0, 256 * passo)
	var onde := Vector3(x, fundo, z)
	# O primeiro alvo que a coluna alcança, descendo: o mais alto cujo corpo entra no cubo.
	var melhor := -INF
	for alvo in AlvosDeGolpe.todos(c.ator.get_tree()):
		if not B.atacavel(c.ator, alvo):
			continue
		var meio: Vector3 = AlvosDeGolpe.centro(alvo)
		var k := ceilf((topo - (meio.y + B.m(lado) * 0.5)) / passo)
		var y := topo - maxf(k, 0.0) * passo
		if y > fundo and y > melhor and B.no_cubo(alvo, Vector3(x, y, z), lado):
			melhor = y
			onde = meio
	c.fx_faiscas(onde, 20, B.m(8.0), 1.0)
	c.fx_raio_do_ceu(onde)
	return onde


# ------------------------------------------------------------ 25 · Mamaragan
func mamaragan() -> void:
	var cnt1 := _somar("cnt1")
	c.travar()
	c.pose("right_arm_front")   # -19/0
	if cnt1 == 1.0:
		c.fx_som(c.pe(), "sons/goro_mamaragan_trovao", 0.0)
	c.fx_faiscas(c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), int(c.r), B.m(0.1), 5.0)
	if cnt1 > 10.0:
		c.iniciar_mamaragan()
		c.encerrar()


## MamaraganOnEffectActiveTick: 2,5% por tick, 1–2 raios a ± 80 blocos do usuário,
## cada um com RangeAttack de lado 20 e uma onda de impacto.
func tempestade() -> void:
	if randf() >= 0.025:
		return
	for i in randi_range(1, 2):
		var onde := raio_do_ceu(c.pe(), 80.0, 10.0)
		c.fx_faiscas(onde, 40, B.m(8.0), 1.0)
		c.atacar(onde, Ataque.new(DANO.mamaragan, 20.0, 0.1))
		c.criar_onda(onde, -3.0)


# ---------------------------------------------------------------- 29 · Raigo
func raigo() -> void:
	var cnt1 := _somar("cnt1")
	c.travar()
	if cnt1 < 20.0:
		c.pose("both_arm_up")   # -4/2
		if _n("cnt2") == 0.0:
			c.D["cnt2"] = 1.0
			c.fx_som(c.pe(), "sons/goro_raigo_chamado", 0.0)
			c.criar_meteoro(c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR + 128.0))
	else:
		c.encerrar()


# ----------------------------------------------------------- 27 · Kari Krash
## O contra-ataque da defesa perfeita (JustGuardProcedure: skill 27, cnt2 = 1).
func kari_krash() -> void:
	var cnt2 := _somar("cnt2")
	if cnt2 < 2.0:
		c.travar()
		return
	c.parar()
	var cnt3 := _somar("cnt3")
	c.pose("right_arm_front")   # -19/0
	if cnt3 <= 1.0:
		c.D["pos"] = c.frente(2.0 + c.r, 0.75)
		c.fx_som(c.D.pos, "sons/goro_kari_krash", 0.0)
		c.fx_marca(c.D.pos, B.m(6.0 * c.r) * 0.5)
	var pos: Vector3 = c.D.pos
	c.atacar(pos, Ataque.new(DANO.kari_krash * _cnt6_fator(), 12.0 * c.r, 1.5))
	c.fx_relampago(c.frente(0.6, 0.75), pos)
	c.fx_faiscas(pos, int(18.0 * c.r), B.m(2.0 * c.r), 4.0)
	if fmod(cnt3, 2.0) == 1.0:
		c.fx_faiscas(pos, int(20.0 * c.r), B.m(4.0 * c.r), 1.0)
	if cnt3 > 10.0:
		c.encerrar()
