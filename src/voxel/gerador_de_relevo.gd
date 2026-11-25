class_name GeradorDeRelevo
extends RefCounted
# ============================================================================
#  GERADOR DE RELEVO (11/11/2026, docs/MUNDO_VOXEL_PLANO.md, etapa V2) — o terreno de uma ilha como blocos, SOB DEMANDA.
#
#  O relevo em blocos (`RelevoEmBlocos`) já é um mapa de alturas em MEIOS blocos (0,44 m) — cada meio é um octante-coluna.
#  Aqui cada seção 16³ de blocos é gerada a partir dele, como o Minecraft gera um chunk a partir do ruído:
#    · octante (x, y, z) está ocupado se o nível `yy` dele está entre `fundo` e a altura `f` da coluna (`yy < f`);
#    · 8 octantes ocupados → cubo; só os de baixo → laje; os de baixo + degrau de um lado (ou canto) → escada;
#      qualquer outra combinação (o "lateral": meio bloco em pé) → bloco de octantes.
#
#  POR QUE SOB DEMANDA: o terreno das 11 ilhas tem 7,7 milhões de blocos sólidos (14 mil seções, ~220 MB como inteiros)
#  e quase tudo é miolo que ninguém vê. Aqui só a seção pedida é montada (na thread de malha), e só as seções EDITADAS
#  ficam guardadas na `GradeVoxel`. Puro e sem estado mutável depois de criado: pode rodar em qualquer thread.
# ============================================================================

const MEIO := RelevoEmBlocos.MEIO
const LADO := GradeVoxel.LADO
## Materiais do terreno por PROFUNDIDADE, como o Minecraft (12/11/2026): grama no topo, 3 de terra, pedra no resto.
## (A cor única `TERRENO` do relevo antigo deixou de ser usada aqui.) A profundidade conta em blocos a partir do topo da coluna.
const CAMADAS: Array[int] = [TiposDeBloco.GRAMA, TiposDeBloco.TERRA, TiposDeBloco.PEDRA]
const PROFUNDIDADE_DA_TERRA := 3

var relevo: RelevoEmBlocos
## Caixa de blocos (inclusive) que o relevo cobre; fora dela é ar.
var caixa_min := Vector3i.ZERO
var caixa_max := Vector3i.ZERO
static var _valor_da_mascara := PackedInt32Array()   # [camada × 256 + máscara de octantes] → valor da célula


func _init(r: RelevoEmBlocos) -> void:
	TiposDeBloco.iniciar()
	_tabela()
	relevo = r
	caixa_min = Vector3i(floori(float(r.origem.x) / 2.0), floori(float(r.fundo) / 2.0), floori(float(r.origem.y) / 2.0))
	var topo := r.fundo
	for h in r.f:
		if h != RelevoEmBlocos.SEM and h > topo:
			topo = h
	caixa_max = Vector3i(floori(float(r.origem.x + r.largura - 1) / 2.0), ceili(float(topo) / 2.0) - 1,
		floori(float(r.origem.y + r.profundidade - 1) / 2.0))


## Construída uma vez, na thread principal (a leitura depois é segura em qualquer thread).
static func _tabela() -> void:
	if not _valor_da_mascara.is_empty():
		return
	var t := PackedInt32Array()
	t.resize(256 * CAMADAS.size())
	for ci in CAMADAS.size():
		var mat: int = CAMADAS[ci]
		var o := ci * 256
		for m in 256:
			t[o + m] = TiposDeBloco.valor(TiposDeBloco.OCTANTES_BASE + mat, m)
		t[o] = TiposDeBloco.AR
		t[o + 0xFF] = mat
		for metade in 2:
			t[o + (0xCC if metade == 1 else 0x33)] = TiposDeBloco.valor(TiposDeBloco.LAJE_BASE + mat, metade)
		# Escadas: a máscara de cada (direção, metade, forma) do jogo (as embaixo e as de cabeça para baixo).
		for e in 40:
			var m := TiposDeBloco.octantes(TiposDeBloco.valor(TiposDeBloco.ESCADA_BASE + mat, e))
			if m != 0x33 and m != 0xCC and m != 0xFF:
				t[o + m] = TiposDeBloco.valor(TiposDeBloco.ESCADA_BASE + mat, e)
	_valor_da_mascara = t


## Camada (índice de `CAMADAS`) da célula cujo primeiro nível é `yy` numa coluna que sobe até `hmax` (meios blocos):
## 0 = grama (a célula tem o topo), 1 = terra, 2 = pedra.
static func camada_em(hmax: int, yy: int) -> int:
	var prof := (hmax - yy - 1) / 2
	if prof <= 0:
		return 0
	return 1 if prof <= PROFUNDIDADE_DA_TERRA else 2


## A coluna (x, z) desta célula está dentro da grade do relevo? (qualquer altura: é o que diz "esta célula é desta ilha").
func contem_coluna(c: Vector3i) -> bool:
	var i := 2 * c.x - relevo.origem.x
	var j := 2 * c.z - relevo.origem.y
	return i >= 0 and j >= 0 and i + 1 < relevo.largura and j + 1 < relevo.profundidade


## A seção tem alguma célula do relevo? (a caixa do relevo é folgada: só decide o que vale a pena gerar).
func cobre(sc: Vector3i) -> bool:
	var a := sc * LADO
	var b := a + Vector3i.ONE * (LADO - 1)
	return not (b.x < caixa_min.x or a.x > caixa_max.x or b.y < caixa_min.y or a.y > caixa_max.y
		or b.z < caixa_min.z or a.z > caixa_max.z)


## Blocos da seção (4096 valores), ou vazio se é só ar.
func gerar(sc: Vector3i) -> PackedInt32Array:
	if not cobre(sc):
		return PackedInt32Array()
	var r := relevo
	var f := r.f
	var fundo := r.fundo
	var dados := PackedInt32Array()
	dados.resize(GradeVoxel.VOLUME)
	var algum := false
	var y0 := sc.y * LADO * 2                          # nível (em meios) do primeiro octante da seção
	for lz in LADO:
		var cz := sc.z * LADO + lz
		for lx in LADO:
			var cx := sc.x * LADO + lx
			var i := 2 * cx - r.origem.x
			var j := 2 * cz - r.origem.y
			if i < 0 or j < 0 or i + 1 >= r.largura or j + 1 >= r.profundidade:
				continue
			var k := j * r.largura + i
			var h0 := f[k]
			var h1 := f[k + 1]
			var h2 := f[k + r.largura]
			var h3 := f[k + r.largura + 1]
			# SEM é o menor inteiro: a coluna sem relevo nunca passa em `yy < h`.
			var hmax := maxi(maxi(h0, h1), maxi(h2, h3))
			if hmax <= y0 or hmax == RelevoEmBlocos.SEM:
				continue
			var hmin := mini(mini(h0, h1), mini(h2, h3))
			for ly in LADO:
				var yy := y0 + 2 * ly
				if yy >= hmax:
					break
				var mascara := 0
				if yy >= fundo and yy + 2 <= hmin:
					mascara = 0xFF
				else:
					# octante = x + 2y + 4z; meio da coluna (x, z): h0 (−x,−z), h1 (+x,−z), h2 (−x,+z), h3 (+x,+z)
					for oy in 2:
						var nivel := yy + oy
						if nivel < fundo:
							continue
						if nivel < h0:
							mascara |= 1 << (2 * oy)
						if nivel < h1:
							mascara |= 2 << (2 * oy)
						if nivel < h2:
							mascara |= 16 << (2 * oy)
						if nivel < h3:
							mascara |= 32 << (2 * oy)
				if mascara != 0:
					dados[lx + LADO * (ly + LADO * lz)] = _valor_da_mascara[camada_em(hmax, yy) * 256 + mascara]
					algum = true
	return dados if algum else PackedInt32Array()


## Valor de UMA célula (para consultas pontuais que não valem montar a seção).
func valor_em(c: Vector3i) -> int:
	var sc := GradeVoxel.secao_de(c)
	if not cobre(sc):
		return TiposDeBloco.AR
	var r := relevo
	var i := 2 * c.x - r.origem.x
	var j := 2 * c.z - r.origem.y
	if i < 0 or j < 0 or i + 1 >= r.largura or j + 1 >= r.profundidade:
		return TiposDeBloco.AR
	var k := j * r.largura + i
	var hs := [r.f[k], r.f[k + 1], r.f[k + r.largura], r.f[k + r.largura + 1]]
	var hmax: int = maxi(maxi(hs[0], hs[1]), maxi(hs[2], hs[3]))
	var mascara := 0
	for oy in 2:
		var nivel := 2 * c.y + oy
		if nivel < r.fundo:
			continue
		for q in 4:
			if nivel < hs[q]:
				mascara |= 1 << ((q & 1) + 2 * oy + 4 * (q >> 1))
	return _valor_da_mascara[camada_em(hmax, 2 * c.y) * 256 + mascara]
