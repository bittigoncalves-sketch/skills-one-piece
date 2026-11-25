class_name RegrasDeBloco
extends RefCounted
# ============================================================================
#  REGRAS DE COLOCAÇÃO E DE VIZINHANÇA (11/11/2026, etapa V3) — o que o Minecraft decide pelo bloco do lado:
#  a forma da escada (reta, canto interno/externo; `StairBlock.getStairsShape`), as conexões do painel de vidro
#  (`IronBarsBlock`), a porta de dois blocos. Tudo escreve na `GradeVoxel`; quem chama não precisa saber o estado.
# ============================================================================

const ESQ_ANTIHORARIO := 3                         # (direção + 3) % 4 = rotação anti-horária (CounterClockWise)


static func oposta(d: int) -> int:
	return (d + 2) % 4


static func anti_horaria(d: int) -> int:
	return (d + ESQ_ANTIHORARIO) % 4


# =================================================================== ESCADA
## Forma da escada em `c` com direção `d` e metade `metade` (0 embaixo, 1 em cima): porte de `StairBlock.getStairsShape`.
static func forma_da_escada(g: GradeVoxel, c: Vector3i, d: int, metade: int) -> int:
	var frente := g.obter(c + TiposDeBloco.DIRECAO[d])
	if TiposDeBloco.e_escada(frente) and _metade(frente) == metade:
		var d2 := _dir(frente)
		if d2 % 2 != d % 2 and _pode_tomar_forma(g, c, d, metade, oposta(d2)):
			return 3 if d2 == anti_horaria(d) else 4          # externa esquerda / direita
	var tras := g.obter(c + TiposDeBloco.DIRECAO[oposta(d)])
	if TiposDeBloco.e_escada(tras) and _metade(tras) == metade:
		var d2 := _dir(tras)
		if d2 % 2 != d % 2 and _pode_tomar_forma(g, c, d, metade, d2):
			return 1 if d2 == anti_horaria(d) else 2          # interna esquerda / direita
	return 0


static func _pode_tomar_forma(g: GradeVoxel, c: Vector3i, d: int, metade: int, para: int) -> bool:
	var v := g.obter(c + TiposDeBloco.DIRECAO[para])
	return not TiposDeBloco.e_escada(v) or _dir(v) != d or _metade(v) != metade


static func _dir(v: int) -> int:
	return TiposDeBloco.estado_de(v) & 3


static func _metade(v: int) -> int:
	return (TiposDeBloco.estado_de(v) >> 2) & 1


## Coloca uma escada do `material` (ex.: `TiposDeBloco.PEDRA`) olhando para `d`; `metade` 0 = degrau embaixo.
static func colocar_escada(g: GradeVoxel, c: Vector3i, material: int, d: int, metade := 0) -> void:
	var estado := d | (metade << 2)
	var tipo := TiposDeBloco.ESCADA_BASE + material
	g.definir(c, TiposDeBloco.valor(tipo, estado))
	g.definir(c, TiposDeBloco.valor(tipo, estado | (forma_da_escada(g, c, d, metade) << 3)))
	atualizar_vizinhos(g, c)


static func colocar_laje(g: GradeVoxel, c: Vector3i, material: int, metade := 0) -> void:
	g.definir(c, TiposDeBloco.valor(TiposDeBloco.LAJE_BASE + material, metade))
	atualizar_vizinhos(g, c)


# =================================================================== PAINEL
static func colocar_painel(g: GradeVoxel, c: Vector3i) -> void:
	g.definir(c, TiposDeBloco.valor(TiposDeBloco.PAINEL_VIDRO, conexoes_do_painel(g, c)))
	atualizar_vizinhos(g, c)


## Liga a cada lado onde há painel ou bloco inteiro e sólido (IronBarsBlock.attachsTo).
static func conexoes_do_painel(g: GradeVoxel, c: Vector3i) -> int:
	var bits := 0
	for d in 4:
		var v := g.obter(c + TiposDeBloco.DIRECAO[d])
		var t := TiposDeBloco.tipo_de(v)
		if t == 0:
			continue
		var f := TiposDeBloco.forma[t]
		if f == TiposDeBloco.Forma.PAINEL or (f == TiposDeBloco.Forma.CUBO and TiposDeBloco.colide[t] == 1):
			bits |= 1 << d
	return bits


# =================================================================== PORTA
## Porta de dois blocos: `c` é o de baixo. `direita` = dobradiça à direita (gira para o outro lado ao abrir).
static func colocar_porta(g: GradeVoxel, c: Vector3i, d: int, direita := false, aberta := false) -> void:
	var estado := d | ((1 if aberta else 0) << 2) | ((1 if direita else 0) << 3)
	g.definir(c, TiposDeBloco.valor(TiposDeBloco.PORTA_MADEIRA, estado))
	g.definir(c + Vector3i.UP, TiposDeBloco.valor(TiposDeBloco.PORTA_MADEIRA, estado | 16))


## Abre/fecha a porta que contém `c` (qualquer das duas metades). Devolve o novo estado (true = aberta).
static func alternar_porta(g: GradeVoxel, c: Vector3i) -> bool:
	var v := g.obter(c)
	if TiposDeBloco.tipo_de(v) != TiposDeBloco.PORTA_MADEIRA:
		return false
	var base := c - Vector3i.UP if (TiposDeBloco.estado_de(v) & 16) != 0 else c
	var aberta := false
	for k in 2:
		var p := base + Vector3i.UP * k
		var pv := g.obter(p)
		if TiposDeBloco.tipo_de(pv) != TiposDeBloco.PORTA_MADEIRA:
			continue
		var e := TiposDeBloco.estado_de(pv) ^ 4
		aberta = (e & 4) != 0
		g.definir(p, TiposDeBloco.valor(TiposDeBloco.PORTA_MADEIRA, e))
	return aberta


# =================================================================== ALÇAPÃO
## Alçapão de madeira: `metade` 0 = encostado embaixo, 1 = em cima; `direcao` é para onde ele cai quando aberto.
static func colocar_alcapao(g: GradeVoxel, c: Vector3i, direcao: int, metade := 0, aberto := false) -> void:
	g.definir(c, TiposDeBloco.valor(TiposDeBloco.ALCAPAO_MADEIRA, direcao | ((1 if aberto else 0) << 2) | (metade << 3)))


static func alternar_alcapao(g: GradeVoxel, c: Vector3i) -> bool:
	var v := g.obter(c)
	if TiposDeBloco.tipo_de(v) != TiposDeBloco.ALCAPAO_MADEIRA:
		return false
	var e := TiposDeBloco.estado_de(v) ^ 4
	g.definir(c, TiposDeBloco.valor(TiposDeBloco.ALCAPAO_MADEIRA, e))
	return (e & 4) != 0


# =================================================================== VIZINHANÇA
## Algo mudou em `c`: as escadas e os painéis do lado refazem a forma (`updateShape` do Minecraft).
## Chamar depois de quebrar ou colocar qualquer bloco que possa ter vizinhos assim.
static func atualizar_vizinhos(g: GradeVoxel, c: Vector3i) -> void:
	for d in 4:
		var p := c + TiposDeBloco.DIRECAO[d]
		var v := g.obter(p)
		if TiposDeBloco.e_escada(v):
			var e := TiposDeBloco.estado_de(v)
			var novo := (e & 7) | (forma_da_escada(g, p, e & 3, (e >> 2) & 1) << 3)
			if novo != e:
				g.definir(p, TiposDeBloco.valor(TiposDeBloco.tipo_de(v), novo))
		elif TiposDeBloco.tipo_de(v) == TiposDeBloco.PAINEL_VIDRO:
			var novo2 := conexoes_do_painel(g, p)
			if novo2 != TiposDeBloco.estado_de(v):
				g.definir(p, TiposDeBloco.valor(TiposDeBloco.PAINEL_VIDRO, novo2))


## Quebra o bloco em `c` (porta leva a outra metade junto) e atualiza os vizinhos.
static func quebrar(g: GradeVoxel, c: Vector3i) -> void:
	var v := g.obter(c)
	if TiposDeBloco.tipo_de(v) == TiposDeBloco.PORTA_MADEIRA:
		var base := c - Vector3i.UP if (TiposDeBloco.estado_de(v) & 16) != 0 else c
		g.definir(base, TiposDeBloco.AR)
		g.definir(base + Vector3i.UP, TiposDeBloco.AR)
	else:
		g.definir(c, TiposDeBloco.AR)
	atualizar_vizinhos(g, c)
