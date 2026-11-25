extends Node
## Nikyu Nikyu no Mi (Mine Piece v14), SkillNikyuNikyuProcedure — as técnicas do ciclo R:
##   21 Pad Ho (PadHoProcedure; com Shift: TsuppariPadHoProcedure)   custo 50
##   22 Ursus Shock (UrsusShockProcedure)                           custo 600
##   25 Assault (SkillAssaultNikyuNikyuProcedure)                   custo 200
##   28 Kuma Punch (SkillKumaPunchProcedure)                        custo 500
##   29 passiva do toque duplo W/S (SkillNikyuNikyuPassiveProcedure)
## Contadores com os nomes do mod (cnt1…cnt10); cnt6 é a carga (0 → 5, CNT6 = 1 + cnt6/10). Cada técnica é a tradução de um
## procedure só; a pata é a `PataNikyu` (PadEntity: textura clear, mas o PadLayer a desenha branca luminosa).
## Adaptações declaradas: BlockDestroyAllDirection (a pata quebrar blocos) vira só o efeito; a "explosão" de potência 0 vira
## clarão; a animação do jogador usa as poses do mod (punch_right, punch_gomu_pistol1, punch_right_jinbe). No Kuma Punch só o ramo
## do DONO da fruta (velocidade 6, sem exigir chão, fim da investida em cnt2 > 5): o ramo de quem não é dono é da IA. Ficam de
## fora o efeito COLLIDED, o StepBlock (degrau) da investida e os geradores de partícula em cone/anel (viram partículas soltas).
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const Pata := preload("res://src/combat/frutas_mine_piece/pata_nikyu.gd")

var c
var tecnica := 0
var cnt1 := 0
var cnt2 := 0.0
var cnt6 := 0.0
var cnt10 := 0
var cnt3 := 0
var _potencia := Vector3.ZERO     # x/y/z_power da Assault e do Kuma Punch, em blocos por tick (look × 6)
## Kuma Punch: o ponto (x/y/z_pos, cnt7…9) e a direção (x/y/z_power) do soco, fixados no cnt1 = 10.
var _origem_soco := Vector3.ZERO
var _rumo_soco := Vector3.ZERO
## Ursus Shock: a âncora e a mira do tick, que a pata de modo 1 lê.
var ancora := Vector3.ZERO
var rumo_ancora := Vector3.FORWARD


func iniciar(numero: int) -> void:
	tecnica = numero
	cnt1 = 0
	cnt2 = 0.0
	cnt6 = 0.0
	cnt10 = 0
	cnt3 = 0
	_potencia = Vector3.ZERO
	_origem_soco = Vector3.ZERO
	_rumo_soco = Vector3.ZERO
	ancora = c.pe()
	rumo_ancora = c.olhar()


func cancelar() -> void:
	pass   # as patas vivem sozinhas, como as entidades do mod


func passo() -> void:
	match tecnica:
		21:
			_pad_ho()
		22:
			_ursus_shock()
		25:
			_assault()
		28:
			_kuma_punch()
		29:
			_passiva()
		_:
			c.terminar()


# ------------------------------------------------------------------ comum
func _k6() -> float:
	return 1.0 + cnt6 * 0.1


func _tamanho() -> float:
	return B.tamanho(B.ALTURA_JOGADOR, B.LARGURA_JOGADOR)


## Cria a PadEntity: `potencia` = módulo do x/y/z_power (blocos por tick), `tamanho` = atributo SIZE, `carga` = cnt6.
func _pata(onde: Vector3, rumo: Vector3, potencia: float, tamanho: float, carga: float) -> void:
	var n := Pata.new()
	n.c = c
	n.potencia = potencia
	n.tamanho = tamanho
	n.cnt6 = carga
	n.rumo = rumo.normalized()
	c.get_tree().current_scene.add_child(n)
	n.global_position = onde


func _teleportar(pe: Vector3) -> void:
	c.ator.global_position += pe - c.pe()
	c.ator.velocity = Vector3.ZERO


func _solido(pe: Vector3, altura_b := B.ALTURA_JOGADOR, largura_b := B.LARGURA_JOGADOR) -> bool:
	return B.solido(c.ator.get_world_3d(), pe, altura_b, largura_b)


## Os três `entity.item.pickup` (volume = o alcance) do toque duplo e das investidas do Kuma Punch.
func _som_de_pegar(alcance: float) -> void:
	for i in 3:
		McVisual.som(c.get_tree(), "entity.item.pickup", McVec3.de_godot(c.pe()), alcance, 1.0)


func _som_e_nuvem(onde: Vector3, volume_explosao: float) -> void:
	VfxFrutaMinePiece.particulas(c.ator, "res://assets/mine_piece/visual/particulas/mc_cloud.png", 1, onde, 5,
		Vector3.ONE * B.m(0.1), B.m(0.25) / B.TICK * 0.25)
	var blocos := McVec3.de_godot(onde)
	McVisual.som(c.get_tree(), "entity.generic.explode", blocos, volume_explosao, 1.25)
	McVisual.som(c.get_tree(), "entity.player.attack.sweep", blocos, 1.0, 1.25)


# ------------------------------------------------------------------ 21 Pad Ho
func _pad_ho() -> void:
	cnt1 += 1
	if cnt1 == 1:
		cnt10 = 1 if c.shift else 0
	if cnt10 > 0:
		_tsuppari()
		return
	c.lentidao = 4 if cnt1 <= 5 else -1
	if cnt1 <= 5:
		c.recarga = c.recarga_total
		var meio: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)
		if cnt1 >= 4 and c.segurando:
			cnt1 = mini(cnt1, 4)
			if cnt6 < 5.0:
				cnt6 += 0.1
				if cnt6 >= 5.0:
					cnt6 = 5.0
					VfxGoroMinePiece.clarao(c.ator, meio, 0.8)
					VfxFrutaMinePiece.onda_de_choque(c.ator, meio - Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), 1.8, Color(1.0, 0.75, 0.45), 0.4)   # carga cheia: anel no chão
					McVisual.particula(c.get_tree(), "minecraft:enchanted_hit", McVec3.de_godot(meio), 20, 0.25, 0.25, 0.25, 1.0)
		var tipo := "minecraft:enchanted_hit" if cnt6 >= 5.0 else "minecraft:crit"
		McVisual.particula(c.get_tree(), tipo, McVec3.de_godot(meio), int(2.0 * _tamanho()),
			B.LARGURA_JOGADOR * 0.5, B.ALTURA_JOGADOR * 0.5, B.LARGURA_JOGADOR * 0.5, 0.0)
	if cnt1 == 7:
		c.pose("punch_right")
		var olhar: Vector3 = c.olhar()
		# x/y/z_pos: o centro do corpo + (1 + largura) blocos na direção em que olha.
		var onde: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5) + olhar * B.m(1.0 + B.LARGURA_JOGADOR)
		_pata(onde, olhar, 8.0, _tamanho() * (1.0 + cnt6 * 0.2), cnt6)
		_som_e_nuvem(onde, 1.0)
		# A repulsão: onda no ponto onde a pata aparece (antes só a pata pequena, que mal se lia).
		VfxFrutaMinePiece.onda_de_choque(c.ator, onde, B.m(3.0 * _tamanho() * (1.0 + cnt6 * 0.2)), Color(1.0, 0.8, 0.5), 0.45)
		VfxFrutaMinePiece.feixe(c.ator, c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), onde, B.m(1.0), Color(1.0, 0.8, 0.5), 0.3)
	if cnt1 > 10:
		c.terminar()


# ------------------------------------------------------------------ 21 com Shift: Tsuppari Pad Ho
## Rajada de patas pequenas: com Z segurado (e pelo menos 1,0 de cnt2) fica em cnt1 = 14 e solta uma por tick.
func _tsuppari() -> void:
	c.lentidao = 4
	if cnt1 <= 15:
		c.recarga = c.recarga_total
	if cnt1 >= 14:
		cnt2 += 0.1
		if c.segurando:
			cnt1 = mini(cnt1, 14)
		if cnt2 <= 1.0:
			cnt1 = mini(cnt1, 14)
	else:
		var meio: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)
		McVisual.particula(c.get_tree(), "minecraft:crit", McVec3.de_godot(meio), int(2.0 * _tamanho()),
			B.LARGURA_JOGADOR * 0.5, B.ALTURA_JOGADOR * 0.5, B.LARGURA_JOGADOR * 0.5, 0.0)
	if cnt1 == 14:
		c.pose("punch_right")
		var olhar: Vector3 = c.olhar()
		# yaw = YRot + 90° ± 90° e pitch = XRot + (rand − 0,9) × 90° do mod: a direção horizontal em que olha, com ±90°.
		var yaw_mc := atan2(olhar.z, olhar.x) + (randf() - 0.5) * PI
		var pitch_mc := -asin(clampf(olhar.y, -1.0, 1.0)) + (randf() - 0.9) * PI * 0.5
		var dis := (3.0 + B.LARGURA_JOGADOR) * randf()
		var deslocamento := Vector3(cos(yaw_mc) * cos(pitch_mc), sin(pitch_mc) * -1.0, sin(yaw_mc) * cos(pitch_mc)) * dis
		var onde: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5) + deslocamento * B.METROS_POR_BLOCO
		_pata(onde, olhar, 6.0, 0.25 * _tamanho(), -0.15)
		_som_e_nuvem(onde, 0.5)
	if cnt1 > 20:
		c.terminar()


# ------------------------------------------------------------------ 22 Ursus Shock
## Trava o corpo (Lentidão X), cria a pata gigante no tick 1 e a mantém na frente; segurar Z prende cnt1 em 19 (e a pata
## continua colada), soltar a lança. cnt1 > 30 termina.
func _ursus_shock() -> void:
	cnt1 += 1
	c.lentidao = 9
	c.recarga = c.recarga_total
	rumo_ancora = c.olhar()
	# x_pos/y_pos/z_pos: o pé + 80% da altura + (1 + largura) blocos na direção em que olha.
	ancora = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.8) + rumo_ancora * B.m(1.0 + B.LARGURA_JOGADOR)
	if cnt1 == 1:
		c.pose("ursus_shock")
		var n := Pata.new()
		n.c = c
		n.modo = 1
		n.dono_exec = self
		n.tamanho = 20.0
		n.rumo = rumo_ancora
		c.get_tree().current_scene.add_child(n)
		n.global_position = ancora
	if cnt1 <= 20 and cnt1 >= 19 and c.segurando:
		cnt1 = mini(cnt1, 19)
		cnt2 += 0.1
	if cnt1 >= 19:
		c.pose("both_arm_front")
	if cnt1 > 30:
		c.terminar()


# ------------------------------------------------------------------ 25 Assault
## Fases do mod (cnt1 e cnt3): CARGA (cnt3 = 0) → INVESTIDA (cnt3 = 1, cnt1 = 0) → EXPLOSÃO (cnt1 ≥ 1, a pata de modo 3 no cnt1 = 9).
func _forca() -> float:
	var f = McEntidade.de(c.ator).getEffect(Mc.efeito(&"minecraft:strength"))
	return float(f.amplificador) if f != null else 0.0


func _assault() -> void:
	cnt2 += 1.0
	var alcance := _tamanho() * (1.0 + minf(_forca(), 50.0) * 0.025)
	var meio: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)
	if cnt1 == 0:
		if cnt3 == 0:
			_assault_carga(alcance, meio)
		else:
			_assault_investida(alcance)
	else:
		_assault_explosao(meio)


func _assault_carga(alcance: float, meio: Vector3) -> void:
	c.lentidao = 9
	c.recarga = c.recarga_total
	if cnt2 >= 9.0:
		if c.segurando:
			cnt2 = minf(cnt2, 9.0)
		if cnt6 > 5.0:
			cnt6 = 5.0
			VfxGoroMinePiece.clarao(c.ator, meio, 0.8)
			VfxFrutaMinePiece.onda_de_choque(c.ator, meio - Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), 1.8, Color(1.0, 0.75, 0.45), 0.4)   # carga cheia: anel no chão
		elif cnt6 == 5.0:
			cnt6 = 5.0
		else:
			cnt6 += 0.125
			if cnt6 == 5.0:
				cnt6 += 0.01
		var tipo := "minecraft:enchanted_hit" if cnt6 >= 5.0 else "minecraft:crit"
		McVisual.particula(c.get_tree(), tipo, McVec3.de_godot(meio), int(2.0 * _tamanho()),
			B.LARGURA_JOGADOR * 0.5, B.ALTURA_JOGADOR * 0.5, B.LARGURA_JOGADOR * 0.5, 0.0)
	if cnt2 >= 10.0 and not c.segurando:
		cnt2 = 0.0
		cnt3 = 1
		c.lentidao = -1
		_potencia = c.olhar() * 6.0
		McVisual.particula(c.get_tree(), "minecraft:cloud", McVec3.de_godot(c.pe()), int(10.0 * alcance),
			alcance * 0.25, 0.1, alcance * 0.25, 0.5)


## setDeltaMovement(power × 2) = 12 blocos por tick (o corpo vai por conta própria, com as colisões do jogo). A cada tick varre
## os 12 passos do caminho atrás do primeiro vivo dentro do cubo de 4 × alcance; achou: vai até colar nele e para. Acaba com
## cnt2 > 5 ou ao achar alvo (cnt1 = 8: o próximo tick já é a explosão).
func _assault_investida(alcance: float) -> void:
	c.invisivel(true)
	var passo := _potencia * 2.0
	var dir := passo.normalized()
	var distancia := _varrer(passo, alcance)
	if distancia >= 0.0:
		var passos := int(round(distancia))
		var pe_novo: Vector3 = c.pe()
		for i in passos:
			var prox := pe_novo + dir * B.METROS_POR_BLOCO
			if B.solido(c.ator.get_world_3d(), prox, B.ALTURA_JOGADOR, B.LARGURA_JOGADOR):
				break
			pe_novo = prox
		c.ator.global_position += pe_novo - c.pe()
		c.impulsionar(Vector3.ZERO)
		cnt1 = 8
	elif cnt2 > 5.0:
		c.impulsionar(Vector3.ZERO)
		cnt1 = 8
	else:
		c.impulsionar(passo)


## A varredura do caminho da investida (Assault e Kuma Punch): em `round(|passo|)` pontos de 1 bloco a partir do centro do corpo,
## o primeiro vivo atacável dentro do cubo de 4 × alcance. Devolve a distância até ele (GetDistanceIterator) ou −1 se não há.
func _varrer(passo: Vector3, alcance: float) -> float:
	var dis := passo.length()
	var dir := passo / dis if dis > 0.0 else Vector3.ZERO
	var centro_b: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)
	for i in maxi(int(round(maxf(dis, 1.0))), 1):
		var ponto := centro_b + dir * B.m(float(i))
		for alvo in AlvosDeGolpe.todos(c.get_tree()):
			if B.atacavel(c.ator, alvo) and B.no_cubo(alvo, ponto, 4.0 * alcance):
				return _distancia_ao(alvo)
	return -1.0


## GetDistanceIterator: a folga entre as duas caixas, em blocos.
func _distancia_ao(alvo: Node3D) -> float:
	var dim: Vector2 = B.dimensoes_b(alvo)
	var pe_a: Vector3 = c.pe()
	var pe_b: Vector3 = B.pe_de(alvo)
	var dy := maxf((pe_b.y - (pe_a.y + B.m(B.ALTURA_JOGADOR))) / B.METROS_POR_BLOCO, 0.0) if pe_b.y > pe_a.y \
		else maxf((pe_a.y - (pe_b.y + B.m(dim.x))) / B.METROS_POR_BLOCO, 0.0)
	var meia := B.LARGURA_JOGADOR * 0.5 + dim.y * 0.5
	var dx := maxf(absf(pe_a.x - pe_b.x) / B.METROS_POR_BLOCO - meia, 0.0)
	var dz := maxf(absf(pe_a.z - pe_b.z) / B.METROS_POR_BLOCO - meia, 0.0)
	return sqrt(dx * dx + dy * dy + dz * dz)


func _assault_explosao(meio: Vector3) -> void:
	c.invisivel(true)
	cnt1 += 1
	c.lentidao = 9
	c.impulsionar(Vector3.ZERO)
	if cnt1 == 9:
		var n := Pata.new()
		n.c = c
		n.modo = 3
		n.tamanho = 5.0 * _tamanho()
		n.cnt6 = -5.0 + cnt6 * 0.6
		n.rumo = c.olhar()
		c.get_tree().current_scene.add_child(n)
		n.global_position = meio       # a PadEntity nasce com o PÉ no centro do corpo do dono
	if cnt1 > 15:
		c.terminar()


# ------------------------------------------------------------------ 28 Kuma Punch
## Três fases do mod: CARGA (cnt1 = 0, cnt3 = 0; segurar Z prende cnt2 em 9) → INVESTIDA (cnt3 = 1, até achar alvo ou cnt2 > 5, e aí
## cnt1 = 5) → SOCO (cnt1 ≥ 6: preso; no cnt1 = 10 fixa ponto e mira; termina em 8 × CNT6 + 25).
func _kuma_punch() -> void:
	cnt2 += 1.0
	var alcance := _tamanho() * (1.0 + minf(_forca(), 50.0) * 0.025)
	if cnt1 != 0:
		_kuma_soco(alcance)
	elif cnt3 == 0:
		_kuma_carga(alcance)
	else:
		_kuma_investida(alcance)


func _kuma_carga(alcance: float) -> void:
	c.recarga = c.recarga_total      # o efeito COOLDOWN_TIME_COMBAT é reaplicado a cada tick da carga
	var meio: Vector3 = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)
	if cnt2 >= 9.0:
		if c.segurando:
			cnt2 = minf(cnt2, 9.0)
		if cnt6 < 5.0:
			cnt6 += 0.125
			if cnt6 >= 5.0:
				cnt6 = 5.0
				VfxGoroMinePiece.clarao(c.ator, meio, 0.8)
				VfxFrutaMinePiece.onda_de_choque(c.ator, meio - Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), 1.8, Color(1.0, 0.75, 0.45), 0.4)   # carga cheia: anel no chão
	var tipo := "minecraft:enchanted_hit" if cnt6 >= 5.0 else "minecraft:crit"
	McVisual.particula(c.get_tree(), tipo, McVec3.de_godot(meio), int(2.0 * _tamanho()),
		B.LARGURA_JOGADOR * 0.5, B.ALTURA_JOGADOR * 0.5, B.LARGURA_JOGADOR * 0.5, 0.0)
	if cnt2 >= 10.0:
		cnt2 = 0.0
		cnt3 = 1
		c.lentidao = -1
		_som_de_pegar(alcance)
		_potencia = c.olhar() * 6.0
		McVisual.particula(c.get_tree(), "minecraft:cloud", McVec3.de_godot(c.pe()), int(10.0 * alcance),
			alcance * 0.25, 0.1, alcance * 0.25, 0.5)


## Mesma varredura da Assault; ao achar, anda `round(distância)` passos de 1 bloco na mira, UM EIXO DE CADA VEZ (x, y, z), e para
## quando os três estão bloqueados. Termina com achar alvo ou cnt2 > 5 (o dono da fruta).
func _kuma_investida(alcance: float) -> void:
	c.invisivel(true)
	var passo := _potencia * 2.0
	var dir := passo.normalized()
	var distancia := _varrer(passo, alcance)
	if distancia >= 0.0 and int(round(distancia)) >= 1:
		var pe_novo: Vector3 = c.pe()
		for i in int(round(distancia)):
			var preso := true
			for eixo in [Vector3(dir.x, 0, 0), Vector3(0, dir.y, 0), Vector3(0, 0, dir.z)]:
				if not _solido(pe_novo + eixo * B.METROS_POR_BLOCO):
					pe_novo += eixo * B.METROS_POR_BLOCO
					preso = false
			if preso:
				break
		_teleportar(pe_novo)
	if distancia >= 0.0 or cnt2 > 5.0:
		c.impulsionar(Vector3.ZERO)
		cnt1 = 5
		c.pose("punch_gomu_pistol1")
		_som_de_pegar(alcance)
	else:
		c.impulsionar(passo)


func _kuma_soco(alcance: float) -> void:
	var k6 := 1.0 + cnt6 * 0.1
	cnt1 += 1
	c.lentidao = 9
	c.impulsionar(Vector3.ZERO)
	c.invisivel(cnt1 < 10)       # a Invisibilidade de 5 ticks da investida acaba aqui
	if cnt1 == 10:
		c.pose("punch_right_jinbe")
		_rumo_soco = c.olhar()
		# x/y/z_pos: o pé + 75% da altura + (0,6 + largura) blocos na direção em que olha.
		_origem_soco = c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.75) + _rumo_soco * B.m(0.6 + B.LARGURA_JOGADOR)
	if cnt1 >= 10:
		if cnt1 == 10:
			# O alcance do soco é uma LINHA no mod e não tinha desenho: feixe branco-âmbar da mão até a ponta + anel no chão do impacto.
			var ponta := _origem_soco + _rumo_soco * B.m(6.0 * alcance)
			VfxFrutaMinePiece.feixe(c.ator, _origem_soco, ponta, B.m(1.4 * alcance), Color(1.0, 0.82, 0.5), 0.45)
			VfxFrutaMinePiece.onda_de_choque(c.ator, ponta - Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5), B.m(4.0 * alcance), Color(1.0, 0.8, 0.5), 0.5)
		_kuma_golpes(alcance, k6)
		if cnt1 >= 8.0 * k6 + 25.0:
			c.terminar()


## O que o mod faz a cada tick de cnt1 ≥ 10. Todos os RangeAttack levam x/y/z_knockback = mira × 6 (a velocidade do soco somada
## ao empurrão radial). `ataque_em_area` empurra a partir do dono, como o RangeAttack.
func _kuma_golpes(alcance: float, k6: float) -> void:
	var origem := _origem_soco
	var dir := _rumo_soco
	var extra := dir * 6.0
	var blocos := McVec3.de_godot(origem)
	if cnt1 <= 4.0 * k6 + 10.0:
		if cnt1 <= 1.0 * k6 + 10.0:
			for tom in [0.5, 0.75, 1.0]:
				McVisual.som(c.get_tree(), "entity.player.attack.sweep", blocos, 2.0 * alcance, tom)
		var a := B.Ataque.new(24.0 * k6, 8.0 * alcance, 1.5, false)
		a.empurrao_extra = extra
		B.ataque_em_area(c.ator, c.pe(), origem, a, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
		# ParticleGeneratorCircle (anel de crit ao longo do soco): partículas soltas no meio do trecho.
		McVisual.particula(c.get_tree(), "minecraft:crit", McVec3.de_godot(origem + dir * B.m(alcance * 0.5)),
			int(16.0 * alcance), alcance * 0.5, alcance * 0.5, alcance * 0.5, 0.1 * alcance)
	if cnt1 <= 8.0 * k6 + 10.0:
		# ParticleGenerator (cone de nuvem na mira, velocidade 6–12 × alcance): nuvens soltas ao longo da mira.
		for i in int(4.0 * alcance):
			McVisual.particula(c.get_tree(), "minecraft:cloud", McVec3.de_godot(origem + dir * B.m(randf_range(0.0, 6.0 * alcance))),
				1, 0.2 * alcance, 0.2 * alcance, 0.2 * alcance, 0.1)
	if cnt1 < 8.0 * k6 + 10.0:
		var pos := origem
		var dis := 0.0
		for i in int(minf(15.0, 5.0 * (cnt1 - 10)) * alcance):
			dis += 1.0
			if dis > 0.0:
				dis = -1.0 * alcance
				if cnt2 <= 8.0:
					var golpe := B.Ataque.new(18.0 * k6, 3.0 * alcance, 1.5, false)
					golpe.empurrao_extra = extra
					B.ataque_em_area(c.ator, c.pe(), pos, golpe, c.tick, c.imunidade, PerfilDeFrutas.ESCALA_DO_MOD, 0.3)
				# Chão sob o ponto (caixa de 3 × alcance): o mod quebra blocos (BlockDestroyAllDirection, 6 × CNT6, sem
				# partícula) e empurra em área; sem a grade de blocos do mod, só o empurrão.
				if _solido(pos - Vector3.UP * B.m(1.5 * alcance), 3.0 * alcance, 3.0 * alcance):
					B.empurrar_area(c.ator, c.pe(), pos, 3.0 * alcance, 1.5)
			pos += dir * B.METROS_POR_BLOCO


# ------------------------------------------------------------------ 29 passiva (toque duplo W/S)
## SkillNikyuNikyuPassiveProcedure: dois ticks presos (Lentidão X, Invisibilidade), depois 48 passos de 0,5 bloco na mira
## (cnt1 = +1 para a frente, −1 para trás; só para a frente para no primeiro alvo, cubo de 3 × tamanho), três ticks, fim.
func _passiva() -> void:
	cnt2 += 1.0
	var tam := _tamanho()
	if cnt2 < 2.0:
		c.lentidao = 9
		if cnt2 == 1.0:
			cnt1 = c.toque
			c.invisivel(true)
		return
	cnt3 += 1
	if cnt3 == 1:
		_som_de_pegar(tam)
		McVisual.particula(c.get_tree(), "minecraft:cloud", McVec3.de_godot(c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)),
			int(5.0 * tam), 0.1 * tam, 0.1 * tam, 0.1 * tam, 0.5)
		var pe: Vector3 = c.pe()
		var p: Vector3 = c.olhar() * B.m(0.5 * cnt1)
		for i in 48:
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
		_teleportar(pe)
		_som_de_pegar(tam)
		McVisual.particula(c.get_tree(), "minecraft:cloud", McVec3.de_godot(c.pe() + Vector3.UP * B.m(B.ALTURA_JOGADOR * 0.5)),
			int(5.0 * tam), 0.1 * tam, 0.1 * tam, 0.1 * tam, 0.5)
	if cnt3 > 3:
		c.terminar()
