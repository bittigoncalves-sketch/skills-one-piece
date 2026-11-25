class_name ItensDeBloco
extends RefCounted
# ============================================================================
#  BLOCOS COMO ITENS (11/11/2026, docs/MUNDO_VOXEL_PLANO.md, etapa V5) — a ponte entre a `GradeVoxel` e o inventário.
#
#  Um item de bloco é a pilha `bloco:<tipo>` (o tipo da `TiposDeBloco`; laje e escada de cada material são tipos próprios, como no
#  Minecraft). O ESTADO (direção da escada, metade da laje, dobradiça da porta) NÃO vive no item: nasce da colocação (`valor_ao_colocar`).
#  Aqui também moram as regras de "o que cai ao quebrar" e "quanto demora quebrar", para o clique e os testes lerem do mesmo lugar.
#
#  DUREZA: os valores do Minecraft 1.20.1 (`Blocks.java`). Tempo de quebra à mão = dureza × 1,5 s (`Player.getDestroySpeed`, sem ferramenta).
#  Ferramentas ainda não aceleram nada (gatilho: quando o machado/picareta existirem na mão, ler daqui `ferramenta_certa`).
# ============================================================================

const PREFIXO := "bloco:"
const SEGUNDOS_POR_DUREZA := 1.5
## Dureza por MATERIAL (laje, escada e octantes usam a do cubo do mesmo material). −1 = não quebra (água).
const DUREZA := {
	TiposDeBloco.GRAMA: 0.6, TiposDeBloco.TERRA: 0.5, TiposDeBloco.PEDRA: 1.5, TiposDeBloco.AREIA: 0.5, TiposDeBloco.MADEIRA: 2.0,
	TiposDeBloco.GELO: 0.5, TiposDeBloco.BASALTO: 1.25, TiposDeBloco.VIDRO: 0.3, TiposDeBloco.AGUA: -1.0,
	TiposDeBloco.PORTA_MADEIRA: 3.0, TiposDeBloco.PAINEL_VIDRO: 0.3, TiposDeBloco.TERRENO: 0.6, TiposDeBloco.TRONCO: 2.0,
	TiposDeBloco.FOLHAS: 0.2, TiposDeBloco.TIJOLO: 2.0, TiposDeBloco.PEDREGULHO: 2.0, TiposDeBloco.NEVE: 0.2,
	TiposDeBloco.OBSIDIANA: 50.0, TiposDeBloco.ARGILA: 0.6, TiposDeBloco.LA_BRANCA: 0.8, TiposDeBloco.LA_VERMELHA: 0.8,
	TiposDeBloco.LA_AZUL: 0.8, TiposDeBloco.LA_VERDE: 0.8, TiposDeBloco.LA_AMARELA: 0.8, TiposDeBloco.ALCAPAO_MADEIRA: 3.0,
}
## Materiais que no Minecraft exigem a ferramenta certa para soltar item e quebram 5× mais devagar sem ela (`requiresCorrectToolForDrops`:
## pedra, basalto, tijolo, pedregulho, obsidiana). NÃO aplicado ainda — `aplicar_ferramenta` fica falso porque o jogo não tem picareta; ligar
## quando existir (gatilho) e o clique passa a usar 100 em vez de 30 ticks por dureza (`BlockBehaviour.getDestroyProgress`).
const EXIGE_FERRAMENTA: Array[int] = [TiposDeBloco.PEDRA, TiposDeBloco.BASALTO, TiposDeBloco.TIJOLO, TiposDeBloco.PEDREGULHO, TiposDeBloco.OBSIDIANA]
static var aplicar_ferramenta := false
static var _icones := {}


static func id_do_tipo(tipo: int) -> String:
	return PREFIXO + str(tipo)


static func e_de_bloco(id: String) -> bool:
	return id.begins_with(PREFIXO)


## O tipo do bloco do item (0 se o id não é de bloco ou o tipo não existe).
static func tipo_do_item(id: String) -> int:
	if not e_de_bloco(id):
		return 0
	TiposDeBloco.iniciar()
	var t := int(id.trim_prefix(PREFIXO))
	return t if t > 0 and t < TiposDeBloco.nome.size() and not TiposDeBloco.nome[t].is_empty() else 0


static func nova_pilha(tipo: int, quantidade := 1) -> McItem.Pilha:
	return InventarioMinecraft.nova(id_do_tipo(tipo), quantidade)


static func nome(id: String) -> String:
	var t := tipo_do_item(id)
	return "" if t == 0 else TiposDeBloco.nome[t].replace("_", " ").capitalize()


# =================================================================== QUEBRAR
## Segundos para quebrar o bloco à mão. −1 = inquebrável.
static func tempo_de_quebra(valor: int) -> float:
	TiposDeBloco.iniciar()
	var m := TiposDeBloco.material_do[TiposDeBloco.tipo_de(valor)]
	var d: float = DUREZA.get(m, BlocosExtras.dureza(m))
	return -1.0 if d < 0.0 else d * SEGUNDOS_POR_DUREZA


## Multiplicador de tempo SEM a ferramenta certa (100/30 do `getDestroyProgress`); 1 enquanto `aplicar_ferramenta` é falso.
static func fator_sem_ferramenta(valor: int) -> float:
	if not aplicar_ferramenta:
		return 1.0
	TiposDeBloco.iniciar()
	return 100.0 / 30.0 if EXIGE_FERRAMENTA.has(TiposDeBloco.material_do[TiposDeBloco.tipo_de(valor)]) else 1.0


## O que o bloco quebrado devolve: `{tipo, quantidade}`. Laje dupla dá 2 lajes; a porta dá uma (a metade de cima não conta);
## o bloco de octantes (terreno em degrau lateral) dá 1 cubo do material — simplificação declarada (não há item de "meio bloco em pé").
static func drop_de(valor: int) -> Dictionary:
	TiposDeBloco.iniciar()
	var t := TiposDeBloco.tipo_de(valor)
	if t == 0 or t == TiposDeBloco.AGUA:
		return {"tipo": 0, "quantidade": 0}
	match TiposDeBloco.forma[t]:
		TiposDeBloco.Forma.OCTANTES:
			return {"tipo": TiposDeBloco.material_do[t], "quantidade": 1}
		TiposDeBloco.Forma.LAJE:
			return {"tipo": t, "quantidade": 2 if TiposDeBloco.estado_de(valor) == 2 else 1}
		TiposDeBloco.Forma.PORTA:
			return {"tipo": t, "quantidade": 0 if (TiposDeBloco.estado_de(valor) & 16) != 0 else 1}
	return {"tipo": t, "quantidade": 1}


# =================================================================== COLOCAR
## Direção horizontal (0 sul, 1 oeste, 2 norte, 3 leste — a do Minecraft) de um vetor de olhar.
static func direcao_de(olhar: Vector3) -> int:
	if absf(olhar.z) >= absf(olhar.x):
		return 0 if olhar.z > 0.0 else 2
	return 3 if olhar.x > 0.0 else 1


## Pode haver um bloco do `tipo` na célula `c`? (a célula está livre — ar ou água — e a porta tem as duas metades livres)
static func cabe(g: GradeVoxel, c: Vector3i, tipo: int) -> bool:
	if not _livre(g.obter(c)):
		return false
	if tipo == TiposDeBloco.PORTA_MADEIRA:
		return _livre(g.obter(c + Vector3i.UP)) and g.gerador != null and g.gerador.contem_coluna(c + Vector3i.UP)
	return true


static func _livre(v: int) -> bool:
	var t := TiposDeBloco.tipo_de(v)
	return t == TiposDeBloco.AR or t == TiposDeBloco.AGUA


## Coloca o item `tipo` na célula `c` (já validada por `cabe`). `normal`: a face clicada, em eixo (Vector3i); `y_na_face`: onde na
## célula o raio bateu (0–1), para a metade da laje/escada/alçapão; `olhar`: para onde o jogador olha. Devolve o valor escrito (0 = nada).
## Laje: clicar numa laje do mesmo material na metade que falta a completa (vira bloco cheio), como no Minecraft.
static func colocar(g: GradeVoxel, c: Vector3i, tipo: int, normal: Vector3i, y_na_face: float, olhar: Vector3) -> int:
	TiposDeBloco.iniciar()
	var d := direcao_de(olhar)
	var em_cima := normal.y < 0 or (normal.y == 0 and y_na_face > 0.5)
	match TiposDeBloco.forma[tipo]:
		TiposDeBloco.Forma.CUBO:
			g.definir(c, TiposDeBloco.valor(tipo))
			RegrasDeBloco.atualizar_vizinhos(g, c)
		TiposDeBloco.Forma.LAJE:
			RegrasDeBloco.colocar_laje(g, c, TiposDeBloco.material_do[tipo], 1 if em_cima else 0)
		TiposDeBloco.Forma.ESCADA:
			RegrasDeBloco.colocar_escada(g, c, TiposDeBloco.material_do[tipo], d, 1 if em_cima else 0)
		TiposDeBloco.Forma.PORTA:
			RegrasDeBloco.colocar_porta(g, c, d, _dobradica_a_direita(g, c, d))
		TiposDeBloco.Forma.PAINEL:
			RegrasDeBloco.colocar_painel(g, c)
		TiposDeBloco.Forma.ALCAPAO:
			RegrasDeBloco.colocar_alcapao(g, c, RegrasDeBloco.oposta(d), 1 if em_cima else 0)
		_:
			return 0
	return g.obter(c)


## Clicar numa laje do mesmo tipo, na face que "falta", a completa: devolve true se completou (e o item deve ser gasto).
static func completar_laje(g: GradeVoxel, c: Vector3i, tipo: int, normal: Vector3i, y_na_face: float) -> bool:
	var v := g.obter(c)
	if TiposDeBloco.tipo_de(v) != tipo or TiposDeBloco.forma[tipo] != TiposDeBloco.Forma.LAJE:
		return false
	var e := TiposDeBloco.estado_de(v)
	# SlabBlock.canBeReplaced: a de baixo completa por cima (ou na metade de cima da lateral); a de cima, por baixo (ou na metade de baixo).
	var completa := (e == 0 and (normal.y > 0 or (normal.y == 0 and y_na_face > 0.5))) \
		or (e == 1 and (normal.y < 0 or (normal.y == 0 and y_na_face <= 0.5)))
	if completa:
		g.definir(c, TiposDeBloco.valor(tipo, 2))
		RegrasDeBloco.atualizar_vizinhos(g, c)
		return true
	return false


## Dobradiça à direita se há uma porta do mesmo lado esquerdo (par de portas duplas abre para os lados opostos).
static func _dobradica_a_direita(g: GradeVoxel, c: Vector3i, d: int) -> bool:
	var esquerda := TiposDeBloco.DIRECAO[RegrasDeBloco.anti_horaria(d)]
	var vizinha := TiposDeBloco.tipo_de(g.obter(c + esquerda))
	return vizinha == TiposDeBloco.PORTA_MADEIRA


# =================================================================== USAR
## Clique direito num bloco "de usar": abre/fecha porta e alçapão. Devolve true se usou.
static func usar(g: GradeVoxel, c: Vector3i) -> bool:
	var t := TiposDeBloco.tipo_de(g.obter(c))
	if t == TiposDeBloco.PORTA_MADEIRA:
		RegrasDeBloco.alternar_porta(g, c)
		return true
	if t == TiposDeBloco.ALCAPAO_MADEIRA:
		RegrasDeBloco.alternar_alcapao(g, c)
		return true
	return false


# =================================================================== ÍCONE
## Ícone 16×16 do bloco para a barra e a mochila: um cubo isométrico com a cor do bloco (sem depender de textura de fora).
static func icone(id: String) -> Texture2D:
	var t := tipo_do_item(id)
	if t == 0:
		return null
	if _icones.has(t):
		return _icones[t]
	TexturasDeBloco.iniciar()
	var cor := TiposDeBloco.cor[t].linear_to_srgb()
	cor.a = maxf(cor.a, 0.85)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var f := TiposDeBloco.forma[t]
	var cubo := _icone_texturizado(t, f)
	if cubo != null:
		var texc := ImageTexture.create_from_image(cubo)
		_icones[t] = texc
		return texc
	var media := _cor_media(t)
	if media.a > 0.0:
		cor = media
	for y in 16:
		for x in 16:
			var u := x - 7.5
			var v := y - 7.5
			# hexágono do cubo isométrico: topo claro, esquerda média, direita escura
			var dentro := absf(u) <= 7.0 and absf(v) <= 7.0 and (absf(u) * 0.5 + absf(v)) <= 7.2
			if not dentro:
				continue
			var tom := 1.0
			if v < -1.0 + absf(u) * 0.5 - 3.5:
				tom = 1.18
			elif u < 0.0:
				tom = 0.92
			else:
				tom = 0.72
			# laje/escada/alçapão/painel/porta: a metade de baixo some ou afina, para o ícone "dizer" a forma
			if f == TiposDeBloco.Forma.LAJE and v < 1.0:
				continue
			if f == TiposDeBloco.Forma.ESCADA and u > 0.0 and v < 1.0:
				continue
			if f == TiposDeBloco.Forma.PAINEL and absf(u) > 2.0:
				continue
			if f == TiposDeBloco.Forma.PORTA and absf(u) > 4.0:
				continue
			if f == TiposDeBloco.Forma.ALCAPAO and v < 3.0:
				continue
			var c := Color(minf(cor.r * tom, 1.0), minf(cor.g * tom, 1.0), minf(cor.b * tom, 1.0), cor.a)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_icones[t] = tex
	return tex


## Cor média da textura do topo (a cor do ícone chapado de laje/escada/porta quando há textura).
static func _cor_media(t: int) -> Color:
	var c := TexturasDeBloco.camada(t, 3)
	if c < 0 or c >= TexturasDeBloco.imagens_das_camadas.size():
		return Color(0, 0, 0, 0)
	var img := TexturasDeBloco.imagens_das_camadas[c]
	var soma := Color(0, 0, 0, 0)
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a > 0.5:
				soma += p
				n += 1
	return Color(soma.r / n, soma.g / n, soma.b / n, 1.0) if n > 0 else Color(0, 0, 0, 0)


## Cubo isométrico 16×16 com as texturas do vanilla (topo 100 %, esquerda 80 %, direita 60 %, como o `BlockRenderDispatcher`).
## Só para cubo e bloco de octantes; as outras formas usam o ícone chapado com a cor média.
static func _icone_texturizado(t: int, f: int) -> Image:
	if f != TiposDeBloco.Forma.CUBO and f != TiposDeBloco.Forma.OCTANTES:
		return null
	var ct := TexturasDeBloco.camada(t, 3)
	var cl := TexturasDeBloco.camada(t, 1)
	var fontes := TexturasDeBloco.imagens_das_camadas
	if ct < 0 or cl < 0 or ct >= fontes.size() or cl >= fontes.size():
		return null
	var topo := fontes[ct]
	var lado := fontes[cl]
	var tam := topo.get_width()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for py in 16:
		for px in 16:
			var x := px + 0.5
			var y := py + 0.5
			var c := Color(0, 0, 0, 0)
			# direita: x = 8 + s·7.5, y = 7 − s·3.5 + t·8
			var s := (x - 8.0) / 7.5
			var v := (y - 7.0 + s * 3.5) / 8.0
			if s >= 0.0 and s < 1.0 and v >= 0.0 and v < 1.0:
				c = lado.get_pixel(clampi(int(s * tam), 0, tam - 1), clampi(int(v * tam), 0, tam - 1))
				c = Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, c.a)
			else:
				# esquerda: x = 0.5 + s·7.5, y = 3.5 + s·3.5 + t·8
				s = (x - 0.5) / 7.5
				v = (y - 3.5 - s * 3.5) / 8.0
				if s >= 0.0 and s < 1.0 and v >= 0.0 and v < 1.0:
					c = lado.get_pixel(clampi(int(s * tam), 0, tam - 1), clampi(int(v * tam), 0, tam - 1))
					c = Color(c.r * 0.8, c.g * 0.8, c.b * 0.8, c.a)
				else:
					# topo: x = 8 + (a − b)·7.5, y = (a + b)·3.5
					var dif := (x - 8.0) / 7.5
					var som := y / 3.5
					var a := (som + dif) * 0.5
					var b := (som - dif) * 0.5
					if a >= 0.0 and a < 1.0 and b >= 0.0 and b < 1.0:
						c = topo.get_pixel(clampi(int(a * tam), 0, tam - 1), clampi(int(b * tam), 0, tam - 1))
			img.set_pixel(px, py, c)
	return img
