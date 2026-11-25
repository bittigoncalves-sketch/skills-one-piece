extends SceneTree
# ============================================================================
#  GERADOR DA ILHA INICIAL — relevo em blocos + assets da loja (30/09/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/gerar_ilha.gd -- [--saida res://...]
#
#  Sem `--saida`, grava o MAPA VIVO (`mapas/historia/baseplate.json`) — é o pedido do
#  dono. A cópia de antes está em `art_src/backups/mapa_historia/`.
#
#  Lê o desenho de `tools/mapa_ilha/planta.json` (aprovado pelo dono) e os tamanhos
#  da loja (`tamanho_padrao`, ver `aplicar_tamanhos_padrao.gd`). Determinístico: mesma
#  planta + mesmo catálogo = mesmo mapa.
#
#  Ordem do relevo (cada passo trabalha sobre o anterior):
#    base ondulada → morros → platôs (vila, porto, coliseu) e fazendas → costa (desce
#    a 0 na borda da baseplate) → estradas (aplainadas) → rio (leito + margens) →
#    cabeceiras das pontes.
#  Depois os ASSETS, sempre pousados no relevo pela MESMA conta da malha
#  (`TerrenoDoMapa.altura_local`) e recusados onde ocupariam rio, estrada ou outra
#  peça: vila, fazendas, porto + navios, serraria, coliseu, floresta, árvores
#  esparsas, coqueiros, pedras. A PRAIA é um anel de blocos de terreno em volta da
#  baseplate, descendo até abaixo do mar (ver `_anel_de_praia`).
#
#  ⚠️ Depois de gerado, o MAPA é a fonte: o dono edita no editor. Rodar de novo
#  apaga essas edições — só com pedido dele.
# ============================================================================

const PLANTA := "res://tools/mapa_ilha/planta.json"
const MAPA_VIVO := "res://mapas/historia/baseplate.json"
const SEMENTE := 300926

## Ponte da loja (modelo novo, `tools/blender/ponte_rio.py`): o deck fica em y = 0
## nas pontas e o modelo desce 3,2 m abaixo disso.
const PONTE := "ponte_rio_low_poly"
const PONTE_ABAIXO_DO_DECK := 3.2
## Mar do Modo História: nível do oceano relativo ao topo da baseplate (y = 0).
const NIVEL_MAR := -0.65
## O relevo nunca encosta no topo da baseplate (y = 0): no mesmo plano, os dois
## disputavam o pixel e uma linha verde da baseplate aparecia ao longo da praia.
const ACIMA_DA_BASE := 0.04
## Fundo comum de TODOS os blocos de terreno (abaixo do mar, para caber a praia).
const BASE_DOS_BLOCOS := -1.5

var planta: Dictionary
var meia: float
var passo: float                 # tamanho da célula (m)
var pontos: int                  # pontos da grade por lado
var H := PackedFloat32Array()     # altura (m acima da baseplate) por ponto
var A := PackedFloat32Array()     # nível da água por ponto (-1 = seco)
var S := PackedByteArray()        # solo por célula
var bib: BibliotecaDeModelos
var rng := RandomNumberGenerator.new()
var ruido := FastNoiseLite.new()
var ruido_fino := FastNoiseLite.new()
var estradas: Array = []          # [{pontos: PackedVector2Array, alturas: PackedFloat32Array}]
## Distância à estrada mais próxima e a altura dela, por ponto da grade — carimbadas
## só até RAIO_CAMPO das estradas (longe = INF). Calcular a distância a 420 trechos
## para cada um dos 66 mil pontos levaria dezenas de segundos.
const RAIO_CAMPO := 14.0
var D_est := PackedFloat32Array()
var H_est := PackedFloat32Array()
var pontes: Array = []            # [{centro: Vector2, dir: Vector2, comp: float, deck: float}]
var blocos := {}                  # "i_j" -> peça de terreno (para pousar assets)
var pecas: Array[Dictionary] = []
var grupos: Array[Dictionary] = []
var ocupado: Array = []           # [Vector3(x, z, raio)]
var contagem := {}
var tamanho_y := 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var saida := MAPA_VIVO
	var i := args.find("--saida")
	if i >= 0 and i + 1 < args.size():
		saida = args[i + 1]
	planta = JSON.parse_string(FileAccess.get_file_as_string(PLANTA))
	meia = planta["ilha"]["meia"]
	passo = float(planta["ilha"]["bloco"]) / float(planta["ilha"]["celulas_por_bloco"])
	pontos = int(2.0 * meia / passo) + 1
	bib = BibliotecaDeModelos.padrao()
	rng.seed = SEMENTE
	ruido.seed = SEMENTE
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 1.0 / 90.0
	ruido_fino.seed = SEMENTE + 1
	ruido_fino.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido_fino.frequency = 1.0 / 28.0

	var t0 := Time.get_ticks_msec()
	_relevo()
	_blocos_de_terreno()
	_anel_de_praia()
	_pontes()
	_coliseu()
	_vila()
	_fazendas()
	_porto()
	_serraria()
	_floresta()
	_arvores_esparsas()
	_coqueiros()
	var spawn := _spawn()
	var mapa := {"nome": "Ilha Inicial", "spawn": {"posicao": spawn}, "pecas": _com_baseplate(), "grupos": grupos}
	var validado := MapaArquivo.validar(_cru(mapa))
	if not validado["ok"]:
		push_error("mapa gerado não valida: %s" % str(validado["erros"]).left(600))
		quit(1)
		return
	var erro := MapaArquivo.salvar(saida, validado["mapa"])
	print("ILHA pecas=%d grupos=%d tamanho_y=%.1f altura_max=%.1f ms=%d -> %s (%s)" % [
		pecas.size() + 1, grupos.size(), tamanho_y, _maior(H), Time.get_ticks_msec() - t0, saida, error_string(erro)])
	for k in contagem:
		print("  %-12s %d" % [k, contagem[k]])
	quit(0 if erro == OK else 1)


# =================================================================== RELEVO
func _relevo() -> void:
	H.resize(pontos * pontos)
	A.resize(pontos * pontos)
	A.fill(-1.0)
	S.resize((pontos - 1) * (pontos - 1))
	_preparar_estradas()
	for j in pontos:
		for i in pontos:
			var x := -meia + i * passo
			var z := -meia + j * passo
			H[j * pontos + i] = _altura_antes_das_estradas(x, z)
	# Estradas: perfil suavizado ao longo do traçado, e o chão perto delas puxado
	# para esse perfil (estrada não sobe e desce com cada ondinha).
	for e in estradas:
		_perfil_da_estrada(e)
	_campo_das_estradas()
	for k in pontos * pontos:
		if D_est[k] < 9.0:
			H[k] = lerpf(H[k], H_est[k], 1.0 - smoothstep(3.2, 9.0, D_est[k]))
	_rio()
	_cabeceiras()
	for k in pontos * pontos:
		H[k] = maxf(H[k], ACIMA_DA_BASE)
	_pintar_solo()


func _altura_antes_das_estradas(x: float, z: float) -> float:
	var h := 2.3 + 1.4 * ruido.get_noise_2d(x, z) + 0.5 * ruido_fino.get_noise_2d(x, z)
	for r in planta["regioes"]:
		var c := Vector2(r["centro"][0], r["centro"][1])
		var d := Vector2(x, z).distance_to(c)
		var raio: float = r["raio"]
		if r["id"] == "morros":
			var f := maxf(0.0, 1.0 - pow(d / raio, 2.0))
			# Cristas: ruído "dobrado" dá linhas de serra em vez de bolha lisa.
			var crista := 1.0 - absf(ruido_fino.get_noise_2d(x * 0.7 + 400.0, z * 0.7))
			h += float(r["altura"]) * pow(f, 1.5) * (0.7 + 0.3 * crista)
		elif r["plana"]:
			h = lerpf(h, float(r["altura"]), 1.0 - smoothstep(raio * 0.7, raio, d))
		else:
			h += float(r["altura"]) * pow(maxf(0.0, 1.0 - pow(d / raio, 2.0)), 2.0)
	# Costa: desce a zero na borda da baseplate (onde começa o mar).
	var borda := minf(meia - absf(x), meia - absf(z))
	return maxf(0.0, lerpf(0.0, h, smoothstep(2.0, 42.0, borda)))


func _preparar_estradas() -> void:
	for e in planta["estradas"]:
		var pts := PackedVector2Array()
		for p in e["pontos"]:
			pts.append(Vector2(p[0], p[1]))
		# Amostra densa (2 m) para distância e perfil.
		var densa := PackedVector2Array()
		for s in pts.size() - 1:
			var a := pts[s]
			var b := pts[s + 1]
			var n := maxi(1, int(a.distance_to(b) / 2.0))
			for k in n:
				densa.append(a.lerp(b, float(k) / n))
		densa.append(pts[pts.size() - 1])
		estradas.append({"id": e["id"], "pontos": densa, "alturas": PackedFloat32Array()})


func _perfil_da_estrada(e: Dictionary) -> void:
	var cru := PackedFloat32Array()
	for p: Vector2 in e["pontos"]:
		cru.append(_amostra(p.x, p.y))
	var liso := PackedFloat32Array()
	liso.resize(cru.size())
	var janela := 9       # ±18 m
	for k in cru.size():
		var soma := 0.0
		var n := 0
		for d in range(-janela, janela + 1):
			var q := clampi(k + d, 0, cru.size() - 1)
			soma += cru[q]
			n += 1
		liso[k] = soma / n
	e["alturas"] = liso


func _campo_das_estradas() -> void:
	D_est.resize(pontos * pontos)
	D_est.fill(INF)
	H_est.resize(pontos * pontos)
	var r := int(ceil(RAIO_CAMPO / passo))
	for e in estradas:
		var pts: PackedVector2Array = e["pontos"]
		var hs: PackedFloat32Array = e["alturas"]
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var ab := b - a
			var i0 := int(floor((minf(a.x, b.x) + meia) / passo)) - r
			var i1 := int(ceil((maxf(a.x, b.x) + meia) / passo)) + r
			var j0 := int(floor((minf(a.y, b.y) + meia) / passo)) - r
			var j1 := int(ceil((maxf(a.y, b.y) + meia) / passo)) + r
			for j in range(maxi(j0, 0), mini(j1, pontos - 1) + 1):
				for i in range(maxi(i0, 0), mini(i1, pontos - 1) + 1):
					var p := Vector2(-meia + i * passo, -meia + j * passo)
					var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
					var d := p.distance_to(a + ab * t)
					var q := j * pontos + i
					if d < D_est[q]:
						D_est[q] = d
						H_est[q] = lerpf(hs[k], hs[k + 1], t)


## Distância (m) do ponto à estrada mais próxima; INF além de RAIO_CAMPO.
func _dist_estrada(x: float, z: float) -> float:
	var i := clampi(int(round((x + meia) / passo)), 0, pontos - 1)
	var j := clampi(int(round((z + meia) / passo)), 0, pontos - 1)
	return D_est[j * pontos + i]


# ---------------------------------------------------------------------- rio
func rio_x(z: float) -> float:
	return float(planta["rio"]["amplitude"]) * sin(PI * z / meia)


func _rio_largura(z: float) -> float:
	var t := (z + meia) / (2.0 * meia)
	return lerpf(planta["rio"]["largura_norte"], planta["rio"]["largura_sul"], t)


## Distância (aprox. perpendicular) ao eixo do rio: a diferença em X corrigida pela
## inclinação local do S.
func _rio_dist(x: float, z: float) -> float:
	var inclinacao := float(planta["rio"]["amplitude"]) * PI / meia * cos(PI * z / meia)
	return absf(x - rio_x(z)) / sqrt(1.0 + inclinacao * inclinacao)


func _agua(z: float) -> float:
	var r: Dictionary = planta["rio"]
	return lerpf(r["agua_meio"], r["agua_foz"], smoothstep(meia - 60.0, meia - 4.0, absf(z)))


func _rio() -> void:
	var margem: float = planta["rio"]["margem"]
	for j in pontos:
		for i in pontos:
			var x := -meia + i * passo
			var z := -meia + j * passo
			var k := j * pontos + i
			var d := _rio_dist(x, z)
			var meio_largo := _rio_largura(z) * 0.5
			if d > meio_largo + 2.0 * margem:
				continue
			var agua := _agua(z)
			var leito := maxf(0.0, agua - 0.95)
			var topo := maxf(H[k], agua + 0.45)
			if d < meio_largo:
				var t := d / meio_largo
				H[k] = leito + (agua - 0.15 - leito) * t * t
			elif d < meio_largo + margem:
				H[k] = lerpf(agua - 0.15, topo, smoothstep(0.0, 1.0, (d - meio_largo) / margem))
			else:
				H[k] = lerpf(topo, H[k], smoothstep(0.0, 1.0, (d - meio_largo - margem) / margem))
			# A água se estende um pouco por baixo do barranco (o barranco a esconde):
			# sem isso sobraria uma faixa seca entre a água e a margem.
			if d < meio_largo + margem * 0.55:
				A[k] = agua


# ------------------------------------------------------------------- pontes
func _cabeceiras() -> void:
	var margem: float = planta["rio"]["margem"]
	for e in estradas:
		var pts: PackedVector2Array = e["pontos"]
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var la := a.x - rio_x(a.y)
			var lb := b.x - rio_x(b.y)
			if la * lb > 0.0:
				continue
			# Cruzamento exato por bisseção.
			var lo := 0.0
			var hi := 1.0
			for _n in 40:
				var m := (lo + hi) * 0.5
				var p := a.lerp(b, m)
				if (p.x - rio_x(p.y)) * la > 0.0:
					lo = m
				else:
					hi = m
			var c := a.lerp(b, lo)
			var dir := (b - a).normalized()
			# Largura do rio medida AO LONGO da estrada (cruzamento oblíquo = vão maior).
			var tangente := Vector2(float(planta["rio"]["amplitude"]) * PI / meia * cos(PI * c.y / meia), 1.0).normalized()
			var seno := absf(dir.x * tangente.y - dir.y * tangente.x)
			var vao := (_rio_largura(c.y) + 2.0 * margem) / maxf(seno, 0.35)
			var comp := vao + 8.0
			var ponta_a := c - dir * comp * 0.5
			var ponta_b := c + dir * comp * 0.5
			# Média das duas margens: com a MAIOR, a margem baixa ganhava um monte
			# íngreme em volta da cabeceira (captura de 30/09/2026).
			var deck := (_amostra(ponta_a.x, ponta_a.y) + _amostra(ponta_b.x, ponta_b.y)) * 0.5 + 0.1
			pontes.append({"centro": c, "dir": dir, "comp": comp, "deck": deck, "estrada": e["id"]})
	# Aplaina o chão das duas cabeceiras na altura do deck.
	for p in pontes:
		for lado in [-1.0, 1.0]:
			var ponta: Vector2 = p["centro"] + p["dir"] * p["comp"] * 0.5 * lado
			# Raio externo largo: a rampa até a cabeceira fica suave nos dois lados.
			# A terra fica 3 cm ACIMA da ponta do deck: o colisor do jogador é uma
			# CAIXA (não sobe degrau), e com a terra abaixo a ponta do deck virava uma
			# parede de 5 cm na entrada (teste de 30/09/2026). Assim o deck emerge do
			# chão já subindo, sem face vertical exposta.
			_aplainar(ponta, 5.0, 16.0, p["deck"] + 0.03)


func _aplainar(c: Vector2, dentro: float, fora: float, altura: float) -> void:
	var r := int(ceil(fora / passo))
	var ci := int(round((c.x + meia) / passo))
	var cj := int(round((c.y + meia) / passo))
	for j in range(cj - r, cj + r + 1):
		for i in range(ci - r, ci + r + 1):
			if i < 0 or j < 0 or i >= pontos or j >= pontos:
				continue
			var p := Vector2(-meia + i * passo, -meia + j * passo)
			var w := 1.0 - smoothstep(dentro, fora, p.distance_to(c))
			if w > 0.0:
				H[j * pontos + i] = lerpf(H[j * pontos + i], altura, w)
				A[j * pontos + i] = -1.0 if w > 0.5 else A[j * pontos + i]


# --------------------------------------------------------------------- solo
func _pintar_solo() -> void:
	var n := pontos - 1
	var margem: float = planta["rio"]["margem"]
	var coliseu := _regiao("coliseu")
	var vila := _regiao("vila")
	var porto := _regiao("porto")
	for j in n:
		for i in n:
			var x := -meia + (i + 0.5) * passo
			var z := -meia + (j + 0.5) * passo
			var codigo := 0
			var d_rio := _rio_dist(x, z)
			var d_est := _dist_estrada(x, z)
			var borda := minf(meia - absf(x), meia - absf(z))
			if d_rio < _rio_largura(z) * 0.5 + margem * 0.8:
				codigo = 3                                                # areia da margem
			elif d_est < 3.0:
				codigo = 2                                                # terra
			elif Vector2(x, z).distance_to(_centro(porto)) < float(porto["raio"]) * 0.8 and borda > 6.0:
				codigo = 2
			elif Vector2(x, z).distance_to(_centro(vila)) < 13.0:
				codigo = 2                                                # praça
			elif _na_floresta(x, z) and Vector2(x, z).distance_to(_centro(coliseu)) > float(coliseu["raio"]) and borda > 34.0:
				codigo = 5                                                # chão de mata
			S[j * n + i] = codigo


func _na_floresta(x: float, z: float) -> bool:
	var margem: float = planta["rio"]["margem"]
	return x < rio_x(z) - _rio_largura(z) * 0.5 - margem - 6.0


# =================================================================== BLOCOS
func _blocos_de_terreno() -> void:
	var celulas: int = planta["ilha"]["celulas_por_bloco"]
	var tam: float = planta["ilha"]["bloco"]
	var por_lado := int(2.0 * meia / tam)
	# MESMA base e MESMO tamanho Y em TODOS os blocos (ilha e anel de praia): o ponto
	# compartilhado vira o mesmo inteiro nos dois e a conta dá a mesma altura, bit a
	# bit. Escalas diferentes não fecham (fresta = pontinho preto; ver TerrenoDoMapa).
	tamanho_y = ceilf(_maior(H)) + 1.0 - BASE_DOS_BLOCOS
	_grupo("relevo")
	for tj in por_lado:
		for ti in por_lado:
			var alturas := PackedInt32Array()
			alturas.resize((celulas + 1) * (celulas + 1))
			var agua := PackedInt32Array()
			agua.resize((celulas + 1) * (celulas + 1))
			var molhado := false
			for j in celulas + 1:
				for i in celulas + 1:
					var k := (tj * celulas + j) * pontos + (ti * celulas + i)
					alturas[j * (celulas + 1) + i] = _fracao(H[k])
					if A[k] >= 0.0:
						agua[j * (celulas + 1) + i] = _fracao(A[k])
						molhado = true
					else:
						agua[j * (celulas + 1) + i] = -1
			var solo := PackedByteArray()
			solo.resize(celulas * celulas)
			for j in celulas:
				for i in celulas:
					solo[j * celulas + i] = S[(tj * celulas + j) * (pontos - 1) + ti * celulas + i]
			var id := "relevo_%d_%d" % [ti, tj]
			var p := {"id": id, "tipo": "terreno", "grupo": "relevo",
				"posicao": Vector3(-meia + (ti + 0.5) * tam, BASE_DOS_BLOCOS + tamanho_y * 0.5, -meia + (tj + 0.5) * tam),
				"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(tam, tamanho_y, tam),
				"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true,
				"relevo": {"celulas": celulas, "alturas": alturas, "solo": solo,
					"agua": agua if molhado else PackedInt32Array()}}
			pecas.append(p)
			blocos["%d_%d" % [ti, tj]] = p
	contagem["blocos"] = por_lado * por_lado


## Altura (m) → fração inteira do bloco. Uma conta só para todos os blocos.
func _fracao(h: float) -> int:
	return clampi(int(round((h - BASE_DOS_BLOCOS) / tamanho_y * TerrenoDoMapa.ESCALA)), 0, TerrenoDoMapa.ESCALA)


## Altura do chão como a MALHA desenha (triângulo exato), não a grade crua.
func chao(x: float, z: float) -> float:
	var tam: float = planta["ilha"]["bloco"]
	var ti := clampi(int(floor((x + meia) / tam)), 0, int(2.0 * meia / tam) - 1)
	var tj := clampi(int(floor((z + meia) / tam)), 0, int(2.0 * meia / tam) - 1)
	var p: Dictionary = blocos.get("%d_%d" % [ti, tj], {})
	if p.is_empty():
		return _amostra(x, z)
	var local := Vector2(x, z) - Vector2(p["posicao"].x, p["posicao"].z)
	var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], clampf(local.x, -tam * 0.5, tam * 0.5),
		clampf(local.y, -tam * 0.5, tam * 0.5))
	return y + float(p["posicao"].y)


## Altura bilinear da grade (antes de existirem blocos).
func _amostra(x: float, z: float) -> float:
	var u := clampf((x + meia) / passo, 0.0, pontos - 1.001)
	var w := clampf((z + meia) / passo, 0.0, pontos - 1.001)
	var i := int(u)
	var j := int(w)
	var fu := u - i
	var fw := w - j
	var a := lerpf(H[j * pontos + i], H[j * pontos + i + 1], fu)
	var b := lerpf(H[(j + 1) * pontos + i], H[(j + 1) * pontos + i + 1], fu)
	return lerpf(a, b, fw)


# =================================================================== ASSETS
## Põe um modelo da loja pousado no relevo. Recusa (false) se cair no rio, numa
## estrada ou em cima de outra peça. `raio` = quanto de chão ele ocupa (0 = do tamanho).
func colocar(modelo: String, x: float, z: float, yaw: float, grupo: String, opcoes := {}) -> bool:
	if not bib.tem(modelo):
		push_warning("modelo fora da loja: " + modelo)
		return false
	var escala: float = opcoes.get("escala", 1.0)
	var t := bib.tamanho_padrao(modelo) * escala
	var raio: float = opcoes.get("raio", maxf(t.x, t.z) * 0.5)
	var p2 := Vector2(x, z)
	if not opcoes.get("livre", false):
		if absf(x) > meia - 3.0 or absf(z) > meia - 3.0:
			return false
		if _rio_dist(x, z) < _rio_largura(z) * 0.5 + float(planta["rio"]["margem"]) + raio * 0.6:
			return false
		var d_est := _dist_estrada(x, z)
		var folga_est := 3.5 + raio * float(opcoes.get("folga_estrada", 0.8))
		# O campo só conhece RAIO_CAMPO: peça larga perto da estrada confere na mão.
		if d_est < folga_est or (folga_est > RAIO_CAMPO and _cruza_estrada(p2, folga_est)):
			return false
		for o in ocupado:
			if p2.distance_to(Vector2(o.x, o.y)) < raio + float(o.z) * float(opcoes.get("folga", 1.0)):
				return false
	var y: float
	if opcoes.has("y_base"):
		y = float(opcoes["y_base"])
	else:
		# O chão mais BAIXO sob a pegada: nenhum canto fica flutuando. No declive o
		# lado de cima afunda um pouco — é o que um prédio de verdade faz no morro.
		y = INF
		for c in [Vector2.ZERO, Vector2(0.4, 0.4), Vector2(-0.4, 0.4), Vector2(0.4, -0.4), Vector2(-0.4, -0.4)]:
			var off := Vector2(c.x * t.x, c.y * t.z).rotated(-deg_to_rad(yaw))
			y = minf(y, chao(x + off.x, z + off.y))
		if opcoes.get("natureza", false):
			# Aglomerado de árvores/pedra: o mais baixo de uma pegada de 29 m enterrava o
			# centro 4–6 m no morro (teste de 30/09/2026). Meio caminho entre o centro e
			# o canto mais baixo: nada flutua no meio, a borda de baixo flutua no máximo
			# metade do desnível — e desnível acima de MAX_DESNIVEL é recusado (quem
			# chama tenta o aglomerado menor).
			var centro := chao(x, z)
			if centro - y > MAX_DESNIVEL:
				return false
			y = centro - (centro - y) * 0.5
		y -= float(opcoes.get("afundar", 0.05))
	var id := _novo_id(modelo)
	pecas.append({"id": id, "tipo": "modelo", "modelo": modelo, "grupo": grupo,
		"posicao": Vector3(x, y + t.y * 0.5, z), "rotacao_graus": Vector3(0, fposmod(yaw + 180.0, 360.0) - 180.0, 0),
		"tamanho": t, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true})
	ocupado.append(Vector3(x, z, raio))
	contagem[grupo] = int(contagem.get(grupo, 0)) + 1
	return true


func _cruza_estrada(p: Vector2, raio: float) -> bool:
	for e in estradas:
		for q: Vector2 in e["pontos"]:
			if q.distance_to(p) < raio:
				return true
	return false


## Natureza em encosta: desnível máximo sob a pegada (m). A borda de baixo flutua no
## máximo metade disso (0,8 m).
const MAX_DESNIVEL := 1.6


## Tenta o aglomerado no tamanho sorteado e, se a encosta for íngreme demais para
## ele, em 70 % e 50 % (pegada menor = desnível menor).
func colocar_natureza(modelo: String, x: float, z: float, yaw: float, grupo: String, opcoes: Dictionary) -> bool:
	var escala: float = opcoes.get("escala", 1.0)
	for fator in [1.0, 0.7, 0.5]:
		var o := opcoes.duplicate()
		o["escala"] = escala * fator
		o["natureza"] = true
		if colocar(modelo, x, z, yaw, grupo, o):
			return true
	return false


## Escala sorteada em DEGRAUS, não contínua: peças do mesmo modelo e tamanho
## dividem a mesma forma de colisão na biblioteca (montar uma trimesh por árvore
## custava ~1 ms cada).
func _escala_sorteada() -> float:
	return [0.85, 1.0, 1.15][rng.randi() % 3]


## Ângulo (graus) que vira a frente do modelo (+Z, convenção glTF) para `alvo`.
static func olhar(de: Vector2, alvo: Vector2) -> float:
	var d := alvo - de
	return rad_to_deg(atan2(d.x, d.y))


func _novo_id(modelo: String) -> String:
	var base := modelo.left(40)
	var n := 1
	var ids := {}
	for p in pecas:
		ids[p["id"]] = true
	while ids.has("%s_%d" % [base, n]):
		n += 1
	return "%s_%d" % [base, n]


func _grupo(id: String) -> void:
	for g in grupos:
		if g["id"] == id:
			return
	grupos.append({"id": id, "pai": ""})


# --------------------------------------------------------------------- praia
## A praia é TERRENO: um anel de blocos de areia em volta da baseplate, do topo dela
## (y = 0) até abaixo do mar. Antes eram os módulos de areia da loja, mas o modelo
## (material comum) e o terreno (cel shader) davam DUAS areias de cores diferentes
## lado a lado (captura de 30/09/2026).
##
## ⚠️ Emenda com a ilha: o anel tem a MESMA base e o MESMO tamanho Y dos blocos da
## ilha, e na borda parte da altura EXATA do ponto da ilha ali (inclusive o barranco
## da foz do rio) — mesmo inteiro, mesma conta, mesma altura. Escalas diferentes
## deixavam até 0,56 m de degrau na foz (teste de 30/09/2026). O espaçamento ao longo
## da borda também é o mesmo (2 m): sem vértice solto.
const LARGURA_PRAIA := 24.0


func _anel_de_praia() -> void:
	_grupo("praia")
	var tam: float = planta["ilha"]["bloco"]
	var por_lado := int(2.0 * meia / tam)
	var w := LARGURA_PRAIA
	var faixas: Array = []
	for k in por_lado:
		var ao_longo := -meia + (k + 0.5) * tam
		faixas.append([Vector2(meia + w * 0.5, ao_longo), Vector2(w, tam)])     # leste
		faixas.append([Vector2(-meia - w * 0.5, ao_longo), Vector2(w, tam)])    # oeste
		faixas.append([Vector2(ao_longo, -meia - w * 0.5), Vector2(tam, w)])    # norte
		faixas.append([Vector2(ao_longo, meia + w * 0.5), Vector2(tam, w)])     # sul
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			faixas.append([Vector2(sx * (meia + w * 0.5), sz * (meia + w * 0.5)), Vector2(w, w)])
	var celulas: int = planta["ilha"]["celulas_por_bloco"]
	var n := 0
	for f in faixas:
		var c: Vector2 = f[0]
		var t: Vector2 = f[1]
		var alturas := PackedInt32Array()
		alturas.resize((celulas + 1) * (celulas + 1))
		for j in celulas + 1:
			for i in celulas + 1:
				var x := c.x + (float(i) / celulas - 0.5) * t.x
				var z := c.y + (float(j) / celulas - 0.5) * t.y
				alturas[j * (celulas + 1) + i] = _fracao(_altura_praia(x, z))
		var solo := PackedByteArray()
		solo.resize(celulas * celulas)
		solo.fill(3)
		pecas.append({"id": "praia_%d" % n, "tipo": "terreno", "grupo": "praia",
			"posicao": Vector3(c.x, BASE_DOS_BLOCOS + tamanho_y * 0.5, c.y), "rotacao_graus": Vector3.ZERO,
			"tamanho": Vector3(t.x, tamanho_y, t.y), "cor": Color.WHITE, "material": "liso",
			"grade_celula": 4.0, "colisao": true,
			"relevo": {"celulas": celulas, "alturas": alturas, "solo": solo, "agua": PackedInt32Array()}})
		n += 1
	contagem["praia"] = n


## Altura da areia fora da baseplate: 0 na borda, descendo até ~−1,3 m. A linha
## d'água (−0,65) cai entre 8 e 16 m da borda, ondulando com o ruído — praia reta
## de régua não existe.
func _altura_praia(x: float, z: float) -> float:
	# Ponto da borda da ilha mais perto (cai sobre um ponto da grade: mesmo passo).
	var bx := clampf(x, -meia, meia)
	var bz := clampf(z, -meia, meia)
	var borda := H[int(round((bz + meia) / passo)) * pontos + int(round((bx + meia) / passo))]
	var d := Vector2(x - bx, z - bz).length()
	if d <= 0.0:
		return borda
	var alcance := LARGURA_PRAIA * (0.75 + 0.35 * (ruido.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5))
	return lerpf(borda, -1.3, smoothstep(0.0, alcance, d))


# -------------------------------------------------------------------- pontes
func _pontes() -> void:
	_grupo("pontes")
	for p in pontes:
		var c: Vector2 = p["centro"]
		var dir: Vector2 = p["dir"]
		if not bib.tem(PONTE):
			push_warning("ponte ainda não está na loja: cruzamento em %s fica sem ponte" % str(c))
			continue
		var t := bib.tamanho_padrao(PONTE)
		t.z = p["comp"]
		var yaw := rad_to_deg(atan2(dir.x, dir.y))
		var y_centro: float = p["deck"] - PONTE_ABAIXO_DO_DECK + t.y * 0.5
		pecas.append({"id": "ponte_%s" % p["estrada"], "tipo": "modelo", "modelo": PONTE, "grupo": "pontes",
			"posicao": Vector3(c.x, y_centro, c.y), "rotacao_graus": Vector3(0, yaw, 0), "tamanho": t,
			"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true})
		ocupado.append(Vector3(c.x, c.y, p["comp"] * 0.5))
		contagem["pontes"] = int(contagem.get("pontes", 0)) + 1


# ------------------------------------------------------------------- coliseu
func _coliseu() -> void:
	_grupo("coliseu")
	var r := _regiao("coliseu")
	var c := _centro(r)
	# Futuro palco das invocações (pets) e das lutas com chefes — pedido do dono.
	colocar("coliseu", c.x, c.y, olhar(c, Vector2(-130, 140)), "coliseu", {"livre": true, "afundar": 0.3})


# ---------------------------------------------------------------------- vila
func _vila() -> void:
	_grupo("vila")
	var r := _regiao("vila")
	var c := _centro(r)
	colocar("town_center-cuqufjeifh", c.x, c.y, 0.0, "vila", {"livre": true})
	colocar("well", c.x + 11.0, c.y - 9.0, 20.0, "vila")
	# Anel 1: o comércio em volta da praça.
	var comercio := ["fantasy_inn", "market_stalls_compact", "village_market", "market_stalls-old8vu6lpl",
		"blacksmith", "market_stalls-puzz5f91oe", "storage_house", "market_stand", "market_stand-dgim5hgisb"]
	_anel(c, 25.0, comercio, "vila", 0.35)
	# Anel 2: as casas, viradas para a praça.
	var casas := ["fantasy_house-bh2xhwunmf", "house-k6tp5nfud2", "fantasy_house-dcpho4sua3", "house-rswoyslblu",
		"houses-gejac1uvvu", "temple-nr264crtsr", "house-vz1clbwmsx", "tower_house", "houses-vcodg5hfyi",
		"fantasy_stable", "house-nihggju7dw", "fantasy_barracks", "house-ojjirwv6bo", "fantasy_house-bh2xhwunmf"]
	_anel(c, 42.0, casas, "vila", 0.1)
	# Anel 3: a periferia — cabanas, depósitos e duas torres de vigia.
	var periferia := ["hut", "house_2", "storage_shed", "huts", "watch_tower-cmxuj2gt7d", "shack",
		"house-yladpcju8u", "hut-wxi3kau5ey", "storage_hut", "hut-4mjwbyd6vw", "watch_tower", "shack-huzljcbud2"]
	_anel(c, 58.0, periferia, "vila", 0.6)
	# Vida na praça: barris, caixotes, carroça e feno perto do mercado e do ferreiro.
	var props := ["barrel_2", "crate", "cart", "hay", "barrel_2", "package", "crate", "bench", "barrel", "cauldron"]
	for k in props.size():
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(15.0, 33.0)
		var p := c + Vector2.from_angle(a) * d
		colocar(props[k], p.x, p.y, rng.randf_range(-180.0, 180.0), "vila", {"folga_estrada": 0.3})


## Distribui `modelos` num anel em volta de `c`, virados para o centro, pulando o
## que cairia em estrada/rio/outra peça (tenta outros ângulos antes de desistir).
func _anel(c: Vector2, raio: float, modelos: Array, grupo: String, fase: float) -> void:
	var n := modelos.size()
	for k in n:
		var feito := false
		for tentativa in 10:
			var a := TAU * (float(k) + fase) / n + tentativa * 0.11 * (1 if tentativa % 2 == 0 else -1)
			var d := raio + rng.randf_range(-3.0, 3.0) + floorf(tentativa / 3.0) * 4.0
			var p := c + Vector2.from_angle(a) * d
			if colocar(modelos[k], p.x, p.y, olhar(p, c), grupo):
				feito = true
				break
		if not feito:
			contagem["recusados"] = int(contagem.get("recusados", 0)) + 1


# ------------------------------------------------------------------ fazendas
func _fazendas() -> void:
	_grupo("fazendas")
	var c := _centro(_regiao("fazendas"))
	var sede := ["farm-91wmlb9kko", "farm", "small_farm", "farm-91wmlb9kko", "small_farm", "storage_shed_2"]
	_anel(c, 26.0, sede, "fazendas", 0.2)
	# Campos: plantação em grade solta ao redor.
	for k in 10:
		var a := TAU * k / 10.0 + 0.3
		var p := c + Vector2.from_angle(a) * rng.randf_range(40.0, 52.0)
		colocar(["crops", "farm_dirt", "crops", "farm-o4wptlsfin"][k % 4], p.x, p.y, rad_to_deg(a), "fazendas",
			{"folga": 0.7})
	# Moinhos no alto, a leste, onde o vento pega.
	colocar("windmill", c.x + 34.0, c.y + 30.0, -30.0, "fazendas")
	colocar("windmill-jphoi9xdlg", c.x + 52.0, c.y - 6.0, 15.0, "fazendas")
	colocar("mill", c.x - 30.0, c.y + 34.0, 40.0, "fazendas")
	for k in 6:
		var p := c + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(12.0, 30.0)
		colocar("hay", p.x, p.y, rng.randf_range(-180, 180), "fazendas", {"folga_estrada": 0.3})


# --------------------------------------------------------------------- porto
func _porto() -> void:
	_grupo("porto")
	_grupo("navios")
	var r := _regiao("porto")
	var c := _centro(r)
	# Prédios do porto em terra, perto da praia.
	var predios := ["port-4se6lmhgpf", "shipping_port-rdx8w8uqip", "storage_house", "shipping_port",
		"docks", "port"]
	_anel(c + Vector2(-6, 0), 20.0, predios, "porto", 0.15)
	for k in 8:
		var p := c + Vector2(rng.randf_range(-4, 14), rng.randf_range(-22, 22))
		colocar(["barrel_2", "crate", "package", "barrel_2"][k % 4], p.x, p.y, rng.randf_range(-180, 180), "porto",
			{"folga_estrada": 0.3})
	# Píeres saindo da praia para o mar (eixo comprido do modelo = Z; giro 90 = +X).
	# Deck do cais a +0,6 m: o cais sem corda tem 5,66 m e o deck é o topo dele.
	var deck := 0.6
	var cais := [["dock_long", 10.0], ["dock_wide", 40.0], ["dock_long_no_rope", 75.0]]
	for item in cais:
		var t := bib.tamanho_padrao(item[0])
		var topo_deck: float = 5.66 if item[0] == "dock_long_no_rope" else t.y - 2.14
		# A areia da praia vai até x ≈ 266 (o mar começa ali): o cais nasce na areia
		# e avança 14 m sobre a água.
		colocar(item[0], meia + t.z * 0.5 + 2.0, item[1], 90.0, "porto",
			{"livre": true, "y_base": deck - topo_deck})
	# Navios atracados (y pela linha d'água: o casco afunda o calado no mar).
	_navio("ship", Vector2(meia + 44.0, 55.0), 0.0, 2.0)
	_navio("small_ship", Vector2(meia + 30.0, 0.0), 0.0, 0.7)
	_navio("house-g7esjlfi4v", Vector2(meia + 36.0, 86.0), 0.0, 1.1)
	_navio("house-2kytqgs4rh", Vector2(meia + 70.0, 18.0), 25.0, 1.2)
	_navio("boat", Vector2(meia + 18.0, 22.0), 10.0, 0.35)
	_navio("boat", Vector2(meia + 20.0, 29.0), -6.0, 0.35)
	# Um bote puxado para a areia, ao sul do porto.
	colocar("boat", meia - 9.0, 104.0, 75.0, "navios", {"livre": true, "afundar": 0.15})


func _navio(modelo: String, p: Vector2, yaw: float, calado: float) -> void:
	colocar(modelo, p.x, p.y, yaw, "navios", {"livre": true, "y_base": NIVEL_MAR - calado})


# ------------------------------------------------------------------ serraria
## Clareira de corte na beira da floresta, perto da ponte sul.
func _serraria() -> void:
	var c := Vector2(-48.0, 64.0)
	colocar("fantasy_sawmill", c.x, c.y, olhar(c, Vector2(-20, 80)), "floresta")
	for k in 7:
		var p := c + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(10.0, 22.0)
		colocar(["logs", "trees_cut", "sawmill", "logs", "trees_cut-zhm3d5kkrh", "sawmill_saw", "logs"][k],
			p.x, p.y, rng.randf_range(-180, 180), "floresta", {"folga": 0.6})


# ------------------------------------------------------------------- floresta
func _floresta() -> void:
	_grupo("floresta")
	var col := _regiao("coliseu")
	var morros := _regiao("morros")
	var espaco := 21.0
	var k := 0
	var z := -meia + 30.0
	while z < meia - 30.0:
		var x := -meia + 30.0
		while x < 0.0 + float(planta["rio"]["amplitude"]):
			var p := Vector2(x + rng.randf_range(-7, 7), z + rng.randf_range(-7, 7))
			x += espaco
			if not _na_floresta(p.x, p.y):
				continue
			if p.distance_to(_centro(col)) < float(col["raio"]) + 6.0:
				continue
			var alto := chao(p.x, p.y)
			var pinheiro := alto > 7.0 or rng.randf() < 0.5
			var nos_morros := p.distance_to(_centro(morros)) < float(morros["raio"]) * 0.55
			if nos_morros and rng.randf() < 0.3:
				# Topo dos morros: pedra no lugar de algumas árvores.
				colocar_natureza(["rocks-38eda0gjwz", "rocks-fy3szrmvue", "rocks-ifu6cm2xow", "rock_2"][k % 4], p.x, p.y,
					rng.randf_range(-180, 180), "floresta", {"escala": _escala_sorteada(), "afundar": 0.6, "raio": 4.0, "natureza": true})
			else:
				colocar_natureza("pine_trees" if pinheiro else "trees", p.x, p.y, rng.randf_range(-180, 180), "floresta",
					{"escala": _escala_sorteada(), "raio": 7.5, "folga": 0.9, "afundar": 0.25, "natureza": true})
			k += 1
		z += espaco
	# Penhascos de pedra no alto dos morros: o marco visto da vila.
	var cm := _centro(morros)
	colocar("mountain-xy4ej3zg3i", cm.x - 6.0, cm.y + 4.0, 20.0, "floresta", {"livre": true, "afundar": 2.5})
	colocar("mountains", cm.x + 26.0, cm.y - 18.0, -40.0, "floresta", {"livre": true, "afundar": 2.0})
	# Pedras soltas pela mata.
	for n in 26:
		var p := Vector2(rng.randf_range(-meia + 30, 40), rng.randf_range(-meia + 30, meia - 30))
		if _na_floresta(p.x, p.y):
			colocar(["rock", "rock-6cyts1cpil", "rock-bvlfuhfaui", "rocks-e1rgb5i2kf", "rock-rtlrqyjfms", "pedra"][n % 6],
				p.x, p.y, rng.randf_range(-180, 180), "floresta", {"afundar": 0.3, "raio": 2.0, "folga": 0.4})


## Leste do rio: árvores soltas nos campos, fora da vila, do porto e das fazendas.
func _arvores_esparsas() -> void:
	_grupo("campos")
	var evitar := [_regiao("vila"), _regiao("porto"), _regiao("fazendas")]
	for n in 140:
		var p := Vector2(rng.randf_range(-40, meia - 34), rng.randf_range(-meia + 34, meia - 34))
		if _na_floresta(p.x, p.y):
			continue
		var perto := false
		for r in evitar:
			if p.distance_to(_centro(r)) < float(r["raio"]) + 10.0:
				perto = true
		if perto:
			continue
		colocar_natureza("trees" if n % 3 else "pine_trees", p.x, p.y, rng.randf_range(-180, 180), "campos",
			{"escala": _escala_sorteada() * 0.75, "raio": 8.0, "afundar": 0.25, "natureza": true})
	for n in 16:
		var p := Vector2(rng.randf_range(-40, meia - 34), rng.randf_range(-meia + 34, meia - 34))
		if not _na_floresta(p.x, p.y):
			colocar(["rock", "rock-4vhwf8xubn", "rocks-e1rgb5i2kf", "pedra"][n % 4], p.x, p.y,
				rng.randf_range(-180, 180), "campos", {"afundar": 0.3, "raio": 2.0})


## Coqueiros na faixa de areia, em volta da ilha inteira.
func _coqueiros() -> void:
	_grupo("coqueiros")
	var palmeiras := ["palm_tree", "palm_tree-a6ckjyfsib", "palm_tree-p0tgwyxbgr"]
	for n in 150:
		var lado := n % 4
		var ao_longo := rng.randf_range(-meia + 20, meia - 20)
		var dentro := rng.randf_range(12.0, 30.0)
		var p: Vector2
		match lado:
			0: p = Vector2(meia - dentro, ao_longo)
			1: p = Vector2(-meia + dentro, ao_longo)
			2: p = Vector2(ao_longo, meia - dentro)
			_: p = Vector2(ao_longo, -meia + dentro)
		if chao(p.x, p.y) > 2.0 or _centro(_regiao("porto")).distance_to(p) < 40.0:
			continue
		colocar_natureza(palmeiras[n % 3], p.x, p.y, rng.randf_range(-180, 180), "coqueiros",
			{"escala": _escala_sorteada(), "raio": 3.0, "afundar": 0.2, "natureza": true})


# ------------------------------------------------------------------- spawn
func _spawn() -> Vector3:
	var s := Vector2(planta["spawn"][0], planta["spawn"][1])
	var c := _centro(_regiao("vila"))
	# Ao lado da fonte da praça, na direção do porto (por onde o jogador "chegou").
	var p := c + (s - c).normalized() * 12.0 if s.distance_to(c) > 1.0 else c + Vector2(12, 0)
	return Vector3(p.x, chao(p.x, p.y) + 1.5, p.y)


# ------------------------------------------------------------------- apoio
func _regiao(id: String) -> Dictionary:
	for r in planta["regioes"]:
		if r["id"] == id:
			return r
	return {}


static func _centro(r: Dictionary) -> Vector2:
	return Vector2(r["centro"][0], r["centro"][1])


static func _maior(v: PackedFloat32Array) -> float:
	var m := -INF
	for x in v:
		m = maxf(m, x)
	return m


## Mantém a baseplate do mapa vivo exatamente como está (cor, grade, tamanho).
func _com_baseplate() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var vivo := MapaArquivo.carregar(MAPA_VIVO)
	var base := {}
	if vivo["ok"]:
		for p in vivo["mapa"]["pecas"]:
			if p["id"] == "baseplate":
				base = p
	if base.is_empty():
		base = {"id": "baseplate", "tipo": "caixa", "posicao": Vector3(0, -1, 0), "rotacao_graus": Vector3.ZERO,
			"tamanho": Vector3(512, 2, 512), "cor": Color("#41a05d"), "material": "grade", "grade_celula": 4.0,
			"colisao": true, "grupo": ""}
	lista.append(base)
	lista.append_array(pecas)
	return lista


## Normalizado → dado cru do JSON (o validador quer o formato do arquivo).
func _cru(mapa: Dictionary) -> Dictionary:
	return JSON.parse_string(MapaArquivo.para_texto({"nome": mapa["nome"], "spawn": mapa["spawn"],
		"pecas": mapa["pecas"], "grupos": mapa["grupos"]}))
