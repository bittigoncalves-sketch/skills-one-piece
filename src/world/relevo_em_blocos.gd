class_name RelevoEmBlocos
extends RefCounted
# ============================================================================
#  RELEVO EM BLOCOS (22/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md) — o relevo de uma
#  ilha refeito em blocos sem textura, fundidos numa malha e numa colisão só.
#
#  Pedido do dono: blocagem com bloco, meio bloco, escada e "lateral" (meio bloco em
#  pé); cada ilha em cima de um bloco gigante (a placa); o MÍNIMO de dobras — blocos
#  encostados viram um só, a hitbox também; feito quando o jogo começa.
#
#  COMO: a fonte continua sendo as peças `terreno` (alturas). Os quatro tipos são
#  combinações de 2×2×2 MEIOS blocos (0,44 m), todos sem nada pendurado — então o
#  relevo inteiro é um mapa de alturas numa grade de meios blocos:
#
#      bloco       2 2 / 2 2        (altura de cada quarto da célula, em meios)
#      meio_bloco  1 1 / 1 1
#      lateral     0 2 / 0 2        (o lado alto inteiro, o outro vazio)
#      escada      1 2 / 1 2        (meio bloco + o lado alto)
#
#  Empilhar só fecha se o lado alto de uma célula partida tiver altura PAR em meios
#  (um lado alto ímpar sobre o lado baixo vazio seria meio bloco "lateral" pela metade,
#  que não está na lista). `_ajustar_celula` escolhe, entre as formas válidas, a mais
#  próxima do relevo.
#
#  FUSÃO: topo = retângulos de mesma altura e mesma COR; paredes = faixas iguais ao
#  longo de cada linha da grade; face de baixo e face entre vizinhos da mesma altura
#  não existem. A cor sai do NOME do solo (`COR_DOS_SOLOS`); hoje todas iguais, então
#  tudo funde. Pôr cores diferentes depois separa só o que tiver cor diferente.
#
#  A grade é a do MUNDO (origem em 0, 0, 0): estruturas do Mine Piece (blocos de 0,88 m)
#  e o relevo podem se alinhar.
# ============================================================================

const BLOCO := 0.88
## Meta do corpo do relevo em blocos de uma ilha (o valor é o próprio `RelevoEmBlocos`).
const META := "relevo_em_blocos"
## Grupo dos corpos de relevo (um por ilha): quem escava (`McRelevoCavavel`) os procura por ele.
const GRUPO := &"relevo_em_blocos"
const MEIO := BLOCO * 0.5
const SEM := -2147483648                 # meio sem coluna (fora das peças de terreno)
## Cada face avança isto sobre as vizinhas. A fusão cria junções em T (o canto de um
## retângulo no meio da aresta do outro) e ali a placa de vídeo deixa frestas de um pixel
## — pontinhos escuros no chão (captura de Wano, 22/10/2026). As faces que se sobrepõem
## são coplanares e da mesma cor: a sobra não aparece.
## ⚠️ EXCEÇÃO: a parede NÃO passa do topo (ver `_parede`). A colisão é esta mesma malha:
## 3 mm de parede acima do chão viravam uma lâmina na borda que prendia a cápsula ao
## descer (23/10/2026, `test_descer_degrau` 1/8 → 8/8). O topo já avança SOBRA além da
## parede e cobre a junção.
const SOBRA := 0.003
## Profundidade mínima do fundo das paredes de fora (metros): abaixo da praia mais funda.
const FUNDO_MINIMO := -1.76

const TIPOS: Array[String] = ["vazio", "bloco", "meio_bloco", "escada", "lateral"]
const BLOCO_T := 1
const MEIO_BLOCO_T := 2
const ESCADA_T := 3
const LATERAL_T := 4
## Cor por solo (os nomes de `TerrenoDoMapa.SOLOS`). Decisão do dono (22/10/2026): uma
## cor só por enquanto — trocar aqui, por solo, quando quiser cores.
## Cor em sRGB (como se escolhe); a paleta converte para linear, como `TerrenoDoMapa`
## (sem converter, saía quase branca — captura de 22/10/2026).
const COR_UNICA := Color("#9b9c92")
const COR_DOS_SOLOS := {
	"auto": COR_UNICA, "grama": COR_UNICA, "terra": COR_UNICA, "areia": COR_UNICA,
	"rocha": COR_UNICA, "mata": COR_UNICA, "leito": COR_UNICA,
}

## Primeiro meio da grade (índice global) e tamanho, em meios.
var origem := Vector2i.ZERO
var largura := 0
var profundidade := 0
## Altura do topo de cada meio, em meios (y do mundo = f × MEIO). SEM = sem coluna.
var f := PackedInt32Array()
## Índice na `paleta` (cores LINEARES, prontas para o vértice) de cada meio.
var cor := PackedByteArray()
## Tipo do bloco do TOPO de cada célula (índice de TIPOS), para contar e testar.
var tipos := PackedByteArray()
var paleta: Array[Color] = []
var fundo := 0
var faces := 0                           # retângulos depois da fusão
var _cores_por_solo := PackedByteArray()  # código do solo → índice na paleta
var calculado := {}                        # triângulos de `calcular`
var lido_do_cache := false


## Relevo de UMA ilha a partir das suas peças `terreno` (dicionários do mapa).
static func de_pecas(pecas: Array) -> RelevoEmBlocos:
	var r := RelevoEmBlocos.new()
	r._montar(pecas)
	return r


## Tudo o que é só conta (amostra, células, fusão), guardando os triângulos em
## `calculado`. Sem nós nem recursos: pode rodar numa thread, uma ilha por thread.
func calcular(pecas: Array) -> void:
	_montar(pecas)
	calculado = triangulos()


# =================================================================== CACHE
## O resultado só muda quando as peças, as cores ou esta conta mudam. Abrir o Modo
## História com as 11 ilhas custava ~7 s de conta (medido em 22/10/2026, 12 núcleos):
## a 1ª abertura depois de uma mudança calcula e grava; as outras leem.
## ⚠️ Mudou a conta (ajuste, fusão, grade)? Suba VERSAO — senão o jogo lê o antigo.
const VERSAO := 5
const PASTA_CACHE := "user://relevo_em_blocos"


static func chave_de(pecas: Array) -> String:
	var partes: Array[String] = ["v%d" % VERSAO, str(COR_DOS_SOLOS.values())]
	for p: Dictionary in pecas:
		partes.append("%s|%s|%s|%s|%s" % [p["id"], p["posicao"], p["tamanho"], p["rotacao_graus"],
			TerrenoDoMapa.assinatura(p["relevo"])])
	return "|".join(partes).sha256_text()


## Calcula, ou lê do cache se a chave bater (e grava o calculado). Pode rodar numa thread.
func calcular_ou_ler(pecas: Array, nome: String) -> void:
	var chave := chave_de(pecas)
	var caminho := PASTA_CACHE.path_join(nome + ".bin")
	if _ler(caminho, chave):
		lido_do_cache = true
		return
	calcular(pecas)
	_gravar(caminho, chave)


func _ler(caminho: String, chave: String) -> bool:
	if not FileAccess.file_exists(caminho):
		return false
	var arq := FileAccess.open_compressed(caminho, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if arq == null:
		return false
	var d: Variant = arq.get_var()
	if not (d is Dictionary) or d.get("chave", "") != chave:
		return false
	origem = d["origem"]
	largura = d["largura"]
	profundidade = d["profundidade"]
	f = d["f"]
	cor = d["cor"]
	tipos = d["tipos"]
	fundo = d["fundo"]
	faces = d["faces"]
	paleta.assign(d["paleta"])
	calculado = {"vertices": d["vertices"], "normais": d["normais"], "cores": d["cores"]}
	return true


func _gravar(caminho: String, chave: String) -> void:
	DirAccess.make_dir_recursive_absolute(PASTA_CACHE)
	var arq := FileAccess.open_compressed(caminho + ".tmp", FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if arq == null:
		return
	arq.store_var({"chave": chave, "origem": origem, "largura": largura, "profundidade": profundidade,
		"f": f, "cor": cor, "tipos": tipos, "fundo": fundo, "faces": faces, "paleta": paleta,
		"vertices": calculado["vertices"], "normais": calculado["normais"], "cores": calculado["cores"]})
	arq.close()
	# Troca atômica: uma abertura interrompida não deixa cache pela metade.
	DirAccess.rename_absolute(caminho + ".tmp", caminho)


## O colisor é (ou está dentro de) o corpo do relevo em blocos de uma ilha.
static func e_relevo(colisor: Object) -> bool:
	var n := colisor as Node
	if n == null:
		return false
	# O corpo da ilha, o nó "Malha"/"Colisao" dele, ou (relevo em blocos de verdade, V2b) uma SEÇÃO da `GradeVoxel` da ilha:
	# seção → grade → corpo da ilha.
	var p := n.get_parent()
	return n.has_meta(META) or (p != null and (p.has_meta(META) or (p.get_parent() != null and p.get_parent().has_meta(META))))


# =================================================================== AMOSTRAGEM
func _montar(pecas: Array) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Dictionary in pecas:
		var c: Vector3 = p["posicao"]
		var m: Vector3 = (p["tamanho"] as Vector3) * 0.5
		var raio := Vector2(m.x, m.z) if (p["rotacao_graus"] as Vector3).is_zero_approx() else Vector2.ONE * Vector2(m.x, m.z).length()
		lo = lo.min(Vector2(c.x, c.z) - raio)
		hi = hi.max(Vector2(c.x, c.z) + raio)
	if pecas.is_empty():
		return
	# Em células inteiras (2 meios), para cada célula ter os seus quatro meios.
	var c0 := Vector2i(floori(lo.x / BLOCO), floori(lo.y / BLOCO))
	var c1 := Vector2i(ceili(hi.x / BLOCO), ceili(hi.y / BLOCO))
	origem = c0 * 2
	largura = (c1.x - c0.x) * 2
	profundidade = (c1.y - c0.y) * 2
	var reais := PackedFloat32Array()
	reais.resize(largura * profundidade)
	reais.fill(NAN)
	var solo := PackedByteArray()
	solo.resize(largura * profundidade)
	for p: Dictionary in pecas:
		_amostrar(p, reais, solo)
	_paleta()
	_ajustar(reais, solo)


## Altura real (em meios) e solo de cada meio coberto pela peça.
func _amostrar(p: Dictionary, reais: PackedFloat32Array, solo: PackedByteArray) -> void:
	var r: Dictionary = p["relevo"]
	var tam: Vector3 = p["tamanho"]
	var pos: Vector3 = p["posicao"]
	var inversa := Basis.from_euler((p["rotacao_graus"] as Vector3) * (PI / 180.0)).inverse()
	var g := TerrenoDoMapa._grade(r, tam)
	var n: int = r["celulas"]
	var solos: PackedByteArray = r.get("solo", PackedByteArray())
	var m := tam * 0.5
	var raio := Vector2(m.x, m.z) if inversa.is_equal_approx(Basis.IDENTITY) else Vector2.ONE * Vector2(m.x, m.z).length()
	var i0 := maxi(floori((pos.x - raio.x) / MEIO) - origem.x, 0)
	var i1 := mini(ceili((pos.x + raio.x) / MEIO) - origem.x, largura)
	var j0 := maxi(floori((pos.z - raio.y) / MEIO) - origem.y, 0)
	var j1 := mini(ceili((pos.z + raio.y) / MEIO) - origem.y, profundidade)
	if inversa.is_equal_approx(Basis.IDENTITY):
		_amostrar_sem_giro(g, n, solos, pos, tam, i0, i1, j0, j1, reais, solo)
		return
	for j in range(j0, j1):
		for i in range(i0, i1):
			var k := j * largura + i
			if not is_nan(reais[k]):
				continue
			var mundo := Vector3((origem.x + i + 0.5) * MEIO, 0.0, (origem.y + j + 0.5) * MEIO)
			var l := inversa * (mundo - pos)
			var u := (l.x / tam.x + 0.5) * n
			var w := (l.z / tam.z + 0.5) * n
			if u < 0.0 or w < 0.0 or u > n or w > n:
				continue
			var y := _altura_na_grade(g, n, u, w)
			reais[k] = _acima_do_zero((pos.y + y) / MEIO)
			if not solos.is_empty():
				solo[k] = solos[clampi(int(w), 0, n - 1) * n + clampi(int(u), 0, n - 1)]


## Peça sem giro (todas as do gerador): a mesma conta de `_altura_na_grade`, escrita no
## laço — são centenas de milhares de amostras por ilha e a chamada custava metade.
func _amostrar_sem_giro(g: PackedVector3Array, n: int, solos: PackedByteArray, pos: Vector3, tam: Vector3,
		i0: int, i1: int, j0: int, j1: int, reais: PackedFloat32Array, solo: PackedByteArray) -> void:
	var ys := PackedFloat32Array()
	ys.resize(g.size())
	for q in g.size():
		ys[q] = (pos.y + g[q].y) / MEIO
	var por_x := n / tam.x
	var por_z := n / tam.z
	var tem_solo := not solos.is_empty()
	for j in range(j0, j1):
		var w := ((origem.y + j + 0.5) * MEIO - pos.z) * por_z + n * 0.5
		if w < 0.0 or w > n:
			continue
		var jj := mini(int(w), n - 1)
		var fw := w - jj
		var linha := j * largura
		for i in range(i0, i1):
			var k := linha + i
			if not is_nan(reais[k]):
				continue
			var u := ((origem.x + i + 0.5) * MEIO - pos.x) * por_x + n * 0.5
			if u < 0.0 or u > n:
				continue
			var ii := mini(int(u), n - 1)
			var fu := u - ii
			var a := jj * (n + 1) + ii
			var ya := ys[a]
			var yb := ys[a + 1]
			var yc := ys[a + n + 1]
			var yd := ys[a + n + 2]
			var y: float
			if (ii + jj) % 2 == 0:
				y = (ya + fw * (yc - ya) + fu * (yd - yc)) if fw > fu else (ya + fu * (yb - ya) + fw * (yd - yb))
			elif fu + fw <= 1.0:
				y = ya + fu * (yb - ya) + fw * (yc - ya)
			else:
				y = yd + (1.0 - fu) * (yc - yd) + (1.0 - fw) * (yb - yd)
			reais[k] = _acima_do_zero(y)
			if tem_solo:
				solo[k] = solos[jj * n + ii]


## Chão acima do zero do mundo (o topo da placa da ilha) fica com pelo menos MEIO bloco.
## Arredondado para 0, o topo do bloco coincidia com o da placa e as duas faces brigavam
## (faixa verde na costa de Wano, captura de 22/10/2026). O degrau de meio bloco na
## linha da costa se sobe andando.
static func _acima_do_zero(meios: float) -> float:
	return maxf(meios, 0.51) if meios > 0.0 else meios


## A mesma conta de `TerrenoDoMapa.altura_local` (triângulo a triângulo, diagonal em
## xadrez), sem alocar nada: são centenas de milhares de amostras por ilha.
static func _altura_na_grade(g: PackedVector3Array, n: int, u: float, w: float) -> float:
	var i := clampi(int(u), 0, n - 1)
	var j := clampi(int(w), 0, n - 1)
	var fu := u - i
	var fw := w - j
	var a := j * (n + 1) + i
	var ya := g[a].y
	var yb := g[a + 1].y
	var yc := g[a + n + 1].y
	var yd := g[a + n + 2].y
	if (i + j) % 2 == 0:
		# Triângulos (a, d, c) e (a, b, d): diagonal a–d.
		if fw > fu:
			return ya + fw * (yc - ya) + fu * (yd - yc)
		return ya + fu * (yb - ya) + fw * (yd - yb)
	# Triângulos (a, b, c) e (b, d, c): diagonal b–c.
	if fu + fw <= 1.0:
		return ya + fu * (yb - ya) + fw * (yc - ya)
	return yd + (1.0 - fu) * (yc - yd) + (1.0 - fw) * (yb - yd)


func _paleta() -> void:
	paleta.clear()
	for nome in TerrenoDoMapa.SOLOS:
		var c: Color = (COR_DOS_SOLOS.get(nome, COR_UNICA) as Color).srgb_to_linear()
		if not paleta.has(c):
			paleta.append(c)


func _indice_da_cor(codigo_solo: int) -> int:
	var nome: String = TerrenoDoMapa.SOLOS[clampi(codigo_solo, 0, TerrenoDoMapa.SOLOS.size() - 1)]
	return paleta.find((COR_DOS_SOLOS.get(nome, COR_UNICA) as Color).srgb_to_linear())


# =================================================================== CÉLULAS
func _ajustar(reais: PackedFloat32Array, solo: PackedByteArray) -> void:
	_cores_por_solo.resize(256)
	for codigo in 256:
		_cores_por_solo[codigo] = _indice_da_cor(codigo)
	f.resize(largura * profundidade)
	f.fill(SEM)
	cor.resize(largura * profundidade)
	tipos.resize((largura / 2) * (profundidade / 2))
	var minimo := INF
	var meia_largura := largura / 2
	for cj in profundidade / 2:
		for ci in meia_largura:
			var a := 2 * cj * largura + 2 * ci
			var ha := reais[a]
			var hb := reais[a + 1]
			var hc := reais[a + largura]
			var hd := reais[a + largura + 1]
			var cheia := not (is_nan(ha) or is_nan(hb) or is_nan(hc) or is_nan(hd))
			# Caminho rápido (quase toda célula): chão com menos de MEIO meio de diferença
			# dentro da célula — aí a forma mais próxima é sempre bloco/meio bloco uniforme
			# (com 0,5–1 meio, a escada pode ficar mais perto: vai para `_ajustar_celula`).
			if cheia and maxf(maxf(ha, hb), maxf(hc, hd)) - minf(minf(ha, hb), minf(hc, hd)) < 0.5:
				var n := roundi((ha + hb + hc + hd) * 0.25)
				f[a] = n
				f[a + 1] = n
				f[a + largura] = n
				f[a + largura + 1] = n
				tipos[cj * meia_largura + ci] = BLOCO_T if n % 2 == 0 else MEIO_BLOCO_T
				var c0 := _cores_por_solo[solo[a]]
				cor[a] = c0
				cor[a + 1] = c0
				cor[a + largura] = c0
				cor[a + largura + 1] = c0
				minimo = minf(minimo, n)
				continue
			var k := [a, a + 1, a + largura, a + largura + 1]
			var h := Vector4(ha, hb, hc, hd)
			if not cheia and is_nan(ha) and is_nan(hb) and is_nan(hc) and is_nan(hd):
				continue
			var forma: Array = _ajustar_celula(h) if cheia else _uniforme_dos_presentes(h)
			var v: Vector4i = forma[0]
			tipos[cj * (largura / 2) + ci] = forma[1]
			var c := _cores_por_solo[solo[k[0]]]
			for q in 4:
				if not is_nan(h[q]):
					f[k[q]] = v[q]
					cor[k[q]] = c
					minimo = minf(minimo, v[q])
	fundo = mini(int(minimo) - 1, floori(FUNDO_MINIMO / MEIO))


## Forma válida mais próxima das quatro alturas reais (em meios; ordem: −x−z, +x−z,
## −x+z, +x+z). Devolve [alturas inteiras, índice do tipo do topo].
static func _ajustar_celula(h: Vector4) -> Array:
	var melhor: Array = []
	var custo := INF
	var media := (h.x + h.y + h.z + h.w) * 0.25
	for n in [floori(media), ceili(media)]:
		var v := Vector4i(n, n, n, n)
		var c := _custo(v, h)
		if c < custo - 0.001:
			custo = c
			melhor = [v, BLOCO_T if n % 2 == 0 else MEIO_BLOCO_T]
	# Partida em dois lados: [índices de um lado], [do outro].
	for lados in [[[0, 2], [1, 3]], [[0, 1], [2, 3]]]:
		for troca in 2:
			var alto: Array = lados[1 - troca]
			var baixo: Array = lados[troca]
			var ma: float = (h[alto[0]] + h[alto[1]]) * 0.5
			var mb: float = (h[baixo[0]] + h[baixo[1]]) * 0.5
			for H in [2 * floori(ma / 2.0), 2 * ceili(ma / 2.0)]:
				for L in [floori(mb), ceili(mb)]:
					if H <= L:
						continue
					var v := Vector4i.ZERO
					v[alto[0]] = H
					v[alto[1]] = H
					v[baixo[0]] = L
					v[baixo[1]] = L
					var c := _custo(v, h)
					if c < custo - 0.001:
						custo = c
						# O topo da célula: escada se o lado baixo é meio bloco logo abaixo do alto.
						melhor = [v, ESCADA_T if (L % 2 != 0 and H == L + 1) else LATERAL_T]
	return melhor


static func _custo(v: Vector4i, h: Vector4) -> float:
	return absf(v.x - h.x) + absf(v.y - h.y) + absf(v.z - h.z) + absf(v.w - h.w)


## Célula na borda (parte dos meios fora das peças): bloco ou meio bloco na média.
static func _uniforme_dos_presentes(h: Vector4) -> Array:
	var soma := 0.0
	var n := 0
	for q in 4:
		if not is_nan(h[q]):
			soma += h[q]
			n += 1
	var v := roundi(soma / n)
	return [Vector4i(v, v, v, v), BLOCO_T if v % 2 == 0 else MEIO_BLOCO_T]


# =================================================================== CORTES (crateras)
## O relevo é um mapa de alturas, então cavar é BAIXAR colunas (de cima para baixo; cavernas internas não
## existem neste modelo). Cada corte é reversível: guarda-se a altura ORIGINAL de cada meio tocado (esparso) e
## a lista de cortes ativos; a altura de um meio é o menor entre o original e os cortes que o cobrem.
var _original := {}                       # índice do meio → altura original (só os tocados)
var _cortes := {}                         # id → {índice do meio: altura depois do corte}
var _proximo_corte := 1


## Índice do meio (coluna) em (i, j) da grade, ou −1 fora dela.
func indice(i: int, j: int) -> int:
	return j * largura + i if i >= 0 and j >= 0 and i < largura and j < profundidade else -1


## Aplica um corte: `alturas` = índice do meio → nova altura (em meios). Só BAIXA (nunca abaixo do `fundo`,
## a placa da ilha). Devolve o id do corte (0 se nada baixou).
func cortar(alturas: Dictionary) -> int:
	var efetivo := {}
	for k: int in alturas:
		var h := maxi(int(alturas[k]), fundo)
		if f[k] != SEM and h < f[k]:
			efetivo[k] = h
	if efetivo.is_empty():
		return 0
	for k: int in efetivo:
		if not _original.has(k):
			_original[k] = f[k]
		f[k] = mini(f[k], efetivo[k])
	var id := _proximo_corte
	_proximo_corte += 1
	_cortes[id] = efetivo
	return id


## Desfaz um corte; devolve os índices cujo valor mudou (para quem precisa reposicionar o que estava ali).
func desfazer_corte(id: int) -> PackedInt32Array:
	var mudou := PackedInt32Array()
	if not _cortes.has(id):
		return mudou
	var feito: Dictionary = _cortes[id]
	_cortes.erase(id)
	for k: int in feito:
		var novo: int = _original[k]
		for outro: Dictionary in _cortes.values():
			if outro.has(k):
				novo = mini(novo, int(outro[k]))
		if novo != f[k]:
			f[k] = novo
			mudou.append(k)
		if novo == _original[k]:
			_original.erase(k)
	return mudou


func cortes_ativos() -> int: return _cortes.size()


## Cópia só com o que `triangulos()` lê — para calcular numa thread enquanto o jogo segue mudando `f`.
func instantaneo() -> RelevoEmBlocos:
	var r := RelevoEmBlocos.new()
	r.origem = origem
	r.largura = largura
	r.profundidade = profundidade
	r.f = f.duplicate()
	r.cor = cor
	r.paleta = paleta.duplicate()
	r.fundo = fundo
	return r


## Altura (y do mundo) do topo do relevo em blocos sob (x, z); NAN fora.
func altura(x: float, z: float) -> float:
	var i := floori(x / MEIO) - origem.x
	var j := floori(z / MEIO) - origem.y
	if i < 0 or j < 0 or i >= largura or j >= profundidade or f[j * largura + i] == SEM:
		return NAN
	return f[j * largura + i] * MEIO


## Quantos blocos de cada tipo há no topo: nome → contagem.
func contagem_de_tipos() -> Dictionary:
	var c := {}
	for t in tipos:
		if t != 0:
			c[TIPOS[t]] = int(c.get(TIPOS[t], 0)) + 1
	return c


# =================================================================== MALHA
## Faixa de colunas (em meios) a triangular; −1 em `_fx1`/`_fz1` = o relevo inteiro. Só `triangulos_da_faixa` mexe.
var _fx0 := 0
var _fx1 := -1
var _fz0 := 0
var _fz1 := -1


## Os triângulos de UMA faixa [x0, x1) × [z0, z1) de meios (a COLISÃO por pedaços do relevo em blocos, V2b): os retângulos
## fundidos param na borda da faixa e a parede da linha x0/z0 é da faixa (a de x1/z1 é da vizinha; a última faixa leva a borda
## de fora). Usar numa CÓPIA (`instantaneo()`): muda estado interno, então não roda em duas threads sobre o mesmo objeto.
func triangulos_da_faixa(x0: int, x1: int, z0: int, z1: int) -> Dictionary:
	_fx0 = x0
	_fx1 = mini(x1, largura)
	_fz0 = z0
	_fz1 = mini(z1, profundidade)
	var t := triangulos()
	_fx1 = -1
	_fz1 = -1
	_fx0 = 0
	_fz0 = 0
	return t


## Triângulos da malha fundida (para a malha e para a colisão) e a cor de cada vértice.
func triangulos() -> Dictionary:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	faces = 0
	_topos(v, n, c)
	_paredes(v, n, c, true)
	_paredes(v, n, c, false)
	return {"vertices": v, "normais": n, "cores": c}


func malha(tri: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = tri["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = tri["normais"]
	arrays[Mesh.ARRAY_COLOR] = tri["cores"]
	var m := ArrayMesh.new()
	if (tri["vertices"] as PackedVector3Array).is_empty():
		return m
	# Sem compressão: vértice quantizado abriria fresta entre faces vizinhas.
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, 0)
	return m


func forma(tri: Dictionary) -> ConcavePolygonShape3D:
	var s := ConcavePolygonShape3D.new()
	s.set_faces(tri["vertices"])
	return s


## Topos: retângulos gulosos de mesma altura e mesma cor.
func _topos(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray) -> void:
	var usado := PackedByteArray()
	usado.resize(largura * profundidade)
	var i_fim := largura if _fx1 < 0 else _fx1
	var j_fim := profundidade if _fz1 < 0 else _fz1
	for j in range(_fz0, j_fim):
		for i in range(_fx0, i_fim):
			var k := j * largura + i
			if usado[k] or f[k] == SEM:
				continue
			var h := f[k]
			var cc := cor[k]
			var w := 1
			while i + w < i_fim and not usado[k + w] and f[k + w] == h and cor[k + w] == cc:
				w += 1
			var d := 1
			var cabe := true
			while j + d < j_fim and cabe:
				var base := (j + d) * largura + i
				for q in w:
					if usado[base + q] or f[base + q] != h or cor[base + q] != cc:
						cabe = false
						break
				if cabe:
					d += 1
			for jj in d:
				for q in w:
					usado[(j + jj) * largura + i + q] = 1
			var y := h * MEIO
			var x0 := (origem.x + i) * MEIO - SOBRA
			var x1 := (origem.x + i + w) * MEIO + SOBRA
			var z0 := (origem.y + j) * MEIO - SOBRA
			var z1 := (origem.y + j + d) * MEIO + SOBRA
			_quad(v, n, c, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), Vector3.UP, paleta[cc])


## Paredes entre meios de alturas diferentes (e na borda de fora, até o fundo), em
## faixas: ao longo de cada linha da grade, trechos seguidos com o mesmo vão e a mesma
## cor viram um retângulo. `em_x`: paredes viradas para ±x (linhas de x constante).
func _paredes(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, em_x: bool) -> void:
	var linhas := largura if em_x else profundidade
	var ao_longo := profundidade if em_x else largura
	# Passo no array entre vizinhos ao longo da linha e entre as duas colunas da parede.
	var passo_b := largura if em_x else 1
	var passo_a := 1 if em_x else largura
	# Faixa (ver `triangulos_da_faixa`): linhas [a0, a1) — mais a última linha se a faixa vai até a borda — e trechos [b0, b1).
	var fx1 := largura if _fx1 < 0 else _fx1
	var fz1 := profundidade if _fz1 < 0 else _fz1
	var a0 := _fx0 if em_x else _fz0
	var a1 := fx1 if em_x else fz1
	var b0 := _fz0 if em_x else _fx0
	var b1 := fz1 if em_x else fx1
	for a in range(a0, a1 + (1 if a1 == linhas else 0)):
		var aberto := false
		var ini := 0
		var k_sinal := 0
		var k_baixo := 0
		var k_alto := 0
		var k_cor := 0
		for b in range(b0, b1 + 1):
			var tem := false
			var sinal := 0
			var baixo := 0
			var alto := 0
			var cc := 0
			if b < b1:
				var k1 := b * passo_b + a * passo_a
				var h0 := f[k1 - passo_a] if a > 0 else SEM
				var h1 := f[k1] if a < linhas else SEM
				if h0 != h1:
					var e0 := h0 if h0 != SEM else fundo
					var e1 := h1 if h1 != SEM else fundo
					if e0 != e1:
						tem = true
						if e0 > e1:
							sinal = 1
							baixo = e1
							alto = e0
							cc = cor[k1 - passo_a]
						else:
							sinal = -1
							baixo = e0
							alto = e1
							cc = cor[k1]
			if aberto and (not tem or sinal != k_sinal or baixo != k_baixo or alto != k_alto or cc != k_cor):
				_parede(v, n, c, em_x, a, ini, b, Vector4i(k_sinal, k_baixo, k_alto, k_cor))
				aberto = false
			if tem and not aberto:
				aberto = true
				ini = b
				k_sinal = sinal
				k_baixo = baixo
				k_alto = alto
				k_cor = cc


func _f(i: int, j: int) -> int:
	if i < 0 or j < 0 or i >= largura or j >= profundidade:
		return SEM
	return f[j * largura + i]


func _parede(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, em_x: bool, a: int,
		b0: int, b1: int, chave: Vector4i) -> void:
	var y0 := chave.y * MEIO - SOBRA
	var y1 := chave.z * MEIO              # sem SOBRA: lâmina acima do chão prende quem desce
	if em_x:
		var x := (origem.x + a) * MEIO
		var z0 := (origem.y + b0) * MEIO - SOBRA
		var z1 := (origem.y + b1) * MEIO + SOBRA
		_quad(v, n, c, Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0),
			Vector3(chave.x, 0, 0), paleta[chave.w])
	else:
		var z := (origem.y + a) * MEIO
		var x0 := (origem.x + b0) * MEIO - SOBRA
		var x1 := (origem.x + b1) * MEIO + SOBRA
		_quad(v, n, c, Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z),
			Vector3(0, 0, chave.x), paleta[chave.w])


## Retângulo (p0..p3 em volta) virado para `normal`: dois triângulos na ordem que o
## Godot desenha de frente (horária para quem olha; ver `TerrenoDoMapa._indices`).
func _quad(v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray, p0: Vector3, p1: Vector3,
		p2: Vector3, p3: Vector3, normal: Vector3, cc: Color) -> void:
	if (p2 - p0).cross(p1 - p0).dot(normal) < 0.0:
		var t := p1
		p1 = p3
		p3 = t
	v.append_array([p0, p1, p2, p0, p2, p3])
	for q in 6:
		n.append(normal)
		c.append(cc)
	faces += 1
