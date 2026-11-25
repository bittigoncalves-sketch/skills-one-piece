class_name TiposDeBloco
extends RefCounted
# ============================================================================
#  TIPOS E FORMAS DE BLOCO (11/11/2026, docs/MUNDO_VOXEL_PLANO.md, etapa V3).
#
#  Decisão do dono: degraus, lajes, janelas, portas… são TIPOS DE BLOCO (como no Minecraft), não geometria especial
#  do relevo. Um valor de célula = `tipo | (estado << 12)`; `tipo` 0 = ar.
#
#  As formas e a regra de escolha vêm do Minecraft 1.20.1 (decompilado do jar do CurseForge, receita em
#  `minecraft-fonte-vanilla-jar-curseforge`): `StairBlock` (8 octantes; tabela SHAPE_BY_STATE), `SlabBlock`
#  (0–8 / 8–16), `DoorBlock` (3/16 de espessura; aberta gira para o lado da dobradiça), `IronBarsBlock` /
#  `CrossCollisionBlock` (poste 2/16 e braços). Direção 2D como no jogo: 0 = sul (+z), 1 = oeste (−x),
#  2 = norte (−z), 3 = leste (+x).
#
#  ESTADO por forma:
#    CUBO    — 0.
#    LAJE    — 0 embaixo, 1 em cima, 2 dupla (cubo cheio).
#    ESCADA  — direção (bits 0–1) | metade (bit 2: 0 embaixo, 1 em cima) | forma (bits 3–5: 0 reta, 1 interna
#              esquerda, 2 interna direita, 3 externa esquerda, 4 externa direita — escolhida pelos vizinhos,
#              ver `RegrasDeBloco`).
#    PORTA   — direção | aberta (bit 2) | dobradiça à direita (bit 3) | metade de cima (bit 4).
#    PAINEL  — conexões: bit (1 << direção) para sul/oeste/norte/leste (janela de vidro, grade).
#    ALCAPAO — direção (bits 0–1) | aberto (bit 2) | metade de cima (bit 3); `TrapDoorBlock`: 3/16 de espessura.
#    OCTANTES — a máscara de 8 bits dos octantes ocupados (qualquer combinação: meio bloco em pé, canto…). É o que
#              o terreno em blocos usa para o que não é cubo, laje nem escada (ver `GeradorDeRelevo`).
#
#  Octantes: o cubo é 2×2×2 octantes (índice = x + 2y + 4z). Cubo, laje e escada se escrevem como máscara de
#  octantes — a oclusão entre vizinhos vira uma conta de bits. Porta e painel são caixas finas (em 16 avos).
# ============================================================================

enum Forma { CUBO, LAJE, ESCADA, PORTA, PAINEL, OCTANTES, ALCAPAO }

const BITS_TIPO := 12
const MASCARA_TIPO := 0xFFF

const AR := 0
const GRAMA := 1
const TERRA := 2
const PEDRA := 3
const AREIA := 4
const MADEIRA := 5
const GELO := 6
const BASALTO := 7
const VIDRO := 8
const AGUA := 9
const PORTA_MADEIRA := 10
const PAINEL_VIDRO := 11
## Terreno das ilhas em blocos: a cor única do `RelevoEmBlocos` (decisão do dono, 22/10/2026). Trocar por grama/terra/pedra por camada é só trocar o tipo no gerador.
const TERRENO := 12
# Blocos de construção (11/11/2026: "adicionar os demais blocos necessários"). Cada um é um cubo; os com forma ganham laje/escada.
const TRONCO := 13
const FOLHAS := 14
const TIJOLO := 15
const PEDREGULHO := 16
const NEVE := 17
const OBSIDIANA := 18
const ARGILA := 19
const LA_BRANCA := 20
const LA_VERMELHA := 21
const LA_AZUL := 22
const LA_VERDE := 23
const LA_AMARELA := 24
const ALCAPAO_MADEIRA := 25
## Lajes e escadas dos materiais abaixo: `LAJE_BASE + material`, `ESCADA_BASE + material`.
const LAJE_BASE := 64
const ESCADA_BASE := 96
const OCTANTES_BASE := 128
const MATERIAIS_COM_FORMAS: Array[int] = [GRAMA, TERRA, PEDRA, AREIA, MADEIRA, BASALTO, TERRENO, TIJOLO, PEDREGULHO]

## Octantes que tocam cada face da célula (ordem das faces: −x, +x, −y, +y, −z, +z).
const OCT_DA_FACE: Array[int] = [0x55, 0xAA, 0x33, 0xCC, 0x0F, 0xF0]
## SHAPE_BY_STATE do `StairBlock`: [forma × 4 + direção] → máscara de 4 bits dos octantes do degrau.
const ESCADA_MASCARA: Array[int] = [12, 5, 3, 10, 14, 13, 7, 11, 13, 7, 11, 14, 8, 4, 1, 2, 4, 1, 2, 8]
## Octante (x + 2y + 4z) de cada bit da máscara acima: para escada embaixo (degrau em cima) e em cima (degrau embaixo).
const ESCADA_OCT_EMBAIXO: Array[int] = [2, 3, 6, 7]
const ESCADA_OCT_EM_CIMA: Array[int] = [0, 1, 4, 5]
## Direção 2D → deslocamento da célula.
const DIRECAO: Array[Vector3i] = [Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(0, 0, -1), Vector3i(1, 0, 0)]

static var _pronto := false
static var forma := PackedByteArray()
static var translucido := PackedByteArray()
static var colide := PackedByteArray()
static var material_do := PackedByteArray()      # tipo → tipo do cubo do mesmo material (laje, escada e octantes se fundem com o cubo)
static var cor := PackedColorArray()            # LINEAR, com alfa
static var nome := PackedStringArray()
static var _oct_escada := PackedInt32Array()    # estado de escada → máscara de octantes


## Registra os tipos. Chamar na thread principal antes de qualquer malha (a leitura depois é segura em thread).
static func iniciar() -> void:
	if _pronto:
		return
	var n := 256
	forma.resize(n)
	translucido.resize(n)
	colide.resize(n)
	material_do.resize(n)
	cor.resize(n)
	nome.resize(n)
	colide.fill(1)
	_registrar(GRAMA, "grama", Color("#6aa84f"), Forma.CUBO)
	_registrar(TERRA, "terra", Color("#8a6a45"), Forma.CUBO)
	_registrar(PEDRA, "pedra", Color("#8b8c92"), Forma.CUBO)
	_registrar(AREIA, "areia", Color("#d8c88a"), Forma.CUBO)
	_registrar(MADEIRA, "madeira", Color("#a8794a"), Forma.CUBO)
	_registrar(GELO, "gelo", Color(0.66, 0.84, 0.96, 0.72), Forma.CUBO, true)
	_registrar(BASALTO, "basalto", Color("#4a4a52"), Forma.CUBO)
	_registrar(VIDRO, "vidro", Color(0.81, 0.91, 0.94, 0.35), Forma.CUBO, true)
	_registrar(AGUA, "agua", Color(0.2, 0.4, 0.85, 0.55), Forma.CUBO, true, false)
	_registrar(PORTA_MADEIRA, "porta_madeira", Color("#8a5a2b"), Forma.PORTA)
	_registrar(PAINEL_VIDRO, "painel_vidro", Color(0.81, 0.91, 0.94, 0.35), Forma.PAINEL, true)
	_registrar(TERRENO, "terreno", Color("#9b9c92"), Forma.CUBO)
	_registrar(TRONCO, "tronco", Color("#6b4f2a"), Forma.CUBO)
	_registrar(FOLHAS, "folhas", Color("#3f7d2e"), Forma.CUBO)
	_registrar(TIJOLO, "tijolo", Color("#9c4a3a"), Forma.CUBO)
	_registrar(PEDREGULHO, "pedregulho", Color("#6f6f73"), Forma.CUBO)
	_registrar(NEVE, "neve", Color("#f2f6f8"), Forma.CUBO)
	_registrar(OBSIDIANA, "obsidiana", Color("#1b1326"), Forma.CUBO)
	_registrar(ARGILA, "argila", Color("#9aa3b0"), Forma.CUBO)
	_registrar(LA_BRANCA, "la_branca", Color("#e8e8e8"), Forma.CUBO)
	_registrar(LA_VERMELHA, "la_vermelha", Color("#a8322d"), Forma.CUBO)
	_registrar(LA_AZUL, "la_azul", Color("#2f4fa8"), Forma.CUBO)
	_registrar(LA_VERDE, "la_verde", Color("#3f7a2c"), Forma.CUBO)
	_registrar(LA_AMARELA, "la_amarela", Color("#e0c63a"), Forma.CUBO)
	_registrar(ALCAPAO_MADEIRA, "alcapao_madeira", Color("#8a5a2b"), Forma.ALCAPAO)
	# Blocos extras do Minecraft (cubos; ver `BlocosExtras`).
	for d: Dictionary in BlocosExtras.todas():
		_registrar(int(d.id), str(d.nome), d.cor, Forma.CUBO, bool(d.transl))
	for m in MATERIAIS_COM_FORMAS:
		_registrar(LAJE_BASE + m, "laje_" + nome[m], cor[m].linear_to_srgb(), Forma.LAJE)
		_registrar(ESCADA_BASE + m, "escada_" + nome[m], cor[m].linear_to_srgb(), Forma.ESCADA)
		_registrar(OCTANTES_BASE + m, "octantes_" + nome[m], cor[m].linear_to_srgb(), Forma.OCTANTES)
	for t in n:
		material_do[t] = t
	for m in MATERIAIS_COM_FORMAS:
		material_do[LAJE_BASE + m] = m
		material_do[ESCADA_BASE + m] = m
		material_do[OCTANTES_BASE + m] = m
	_oct_escada.resize(40)
	for e in 40:
		var dir := e & 3
		var em_cima := (e >> 2) & 1 == 1
		var m := ESCADA_MASCARA[(e >> 3) * 4 + dir]
		var oct := 0xCC if em_cima else 0x33
		var onde := ESCADA_OCT_EM_CIMA if em_cima else ESCADA_OCT_EMBAIXO
		for bit in 4:
			if m & (1 << bit) != 0:
				oct |= 1 << onde[bit]
		_oct_escada[e] = oct
	_pronto = true


static func _registrar(id: int, n: String, c: Color, f: int, transl := false, colisao := true) -> void:
	nome[id] = n
	cor[id] = c.srgb_to_linear()
	forma[id] = f
	translucido[id] = 1 if transl else 0
	colide[id] = 1 if colisao else 0


static func valor(tipo: int, estado := 0) -> int:
	return tipo | (estado << BITS_TIPO)


static func tipo_de(v: int) -> int:
	return v & MASCARA_TIPO


static func estado_de(v: int) -> int:
	return v >> BITS_TIPO


static func forma_de(v: int) -> int:
	return forma[v & MASCARA_TIPO]


static func e_escada(v: int) -> bool:
	return (v & MASCARA_TIPO) != 0 and forma[v & MASCARA_TIPO] == Forma.ESCADA


## Porta, painel e alçapão: caixas finas em vez de octantes.
static func e_de_caixas(f: int) -> bool:
	return f == Forma.PORTA or f == Forma.PAINEL or f == Forma.ALCAPAO


static func e_cubo_opaco(v: int) -> bool:
	var t := v & MASCARA_TIPO
	return t != 0 and forma[t] == Forma.CUBO and translucido[t] == 0


## Máscara de octantes ocupados pelo bloco (0 = não é feito de octantes: ar, porta, painel).
static func octantes(v: int) -> int:
	var t := v & MASCARA_TIPO
	if t == 0:
		return 0
	match forma[t]:
		Forma.CUBO:
			return 0xFF
		Forma.LAJE:
			return [0x33, 0xCC, 0xFF][mini(v >> BITS_TIPO, 2)]
		Forma.ESCADA:
			return _oct_escada[mini(v >> BITS_TIPO, 39)]
		Forma.OCTANTES:
			return (v >> BITS_TIPO) & 0xFF
	return 0


## Caixas finas do bloco, em 16 avos: [x0, y0, z0, x1, y1, z1] (porta e painel).
static func caixas(v: int) -> Array:
	var t := v & MASCARA_TIPO
	var e := v >> BITS_TIPO
	if t == 0:
		return []
	if forma[t] == Forma.PORTA:
		var dir := e & 3
		var aberta := (e >> 2) & 1 == 1
		var direita := (e >> 3) & 1 == 1
		var lado := dir if not aberta else (dir + (3 if direita else 1)) % 4
		# DoorBlock: SOUTH 0–3 em z, WEST 13–16 em x, NORTH 13–16 em z, EAST 0–3 em x.
		match lado:
			0: return [[0, 0, 0, 16, 16, 3]]
			1: return [[13, 0, 0, 16, 16, 16]]
			2: return [[0, 0, 13, 16, 16, 16]]
		return [[0, 0, 0, 3, 16, 16]]
	if forma[t] == Forma.ALCAPAO:
		var dir := e & 3
		var aberto := (e >> 2) & 1 == 1
		var em_cima := (e >> 3) & 1 == 1
		# TrapDoorBlock: fechado 0–3 (embaixo) ou 13–16 (em cima) em y; aberto vira parede do lado da direção.
		if not aberto:
			return [[0, 13, 0, 16, 16, 16]] if em_cima else [[0, 0, 0, 16, 3, 16]]
		match dir:
			0: return [[0, 0, 0, 16, 16, 3]]
			1: return [[13, 0, 0, 16, 16, 16]]
			2: return [[0, 0, 13, 16, 16, 16]]
		return [[0, 0, 0, 3, 16, 16]]
	if forma[t] == Forma.PAINEL:
		# CrossCollisionBlock.makeShapes(1, 1, 16, 0, 16): poste 7–9 e braços de 7–9 até a borda.
		var c: Array = [[7, 0, 7, 9, 16, 9]]
		if e & 1:
			c.append([7, 0, 7, 9, 16, 16])
		if e & 2:
			c.append([0, 0, 7, 8, 16, 9])
		if e & 4:
			c.append([7, 0, 0, 9, 16, 8])
		if e & 8:
			c.append([7, 0, 7, 16, 16, 9])
		return c
	return []
