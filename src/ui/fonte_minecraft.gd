class_name FonteMinecraft
extends RefCounted
# ============================================================================
#  A FONTE DO MINECRAFT (12/11/2026) — montada em tempo de execução a partir das texturas bitmap do jar 1.20.1.
#
#  `ascii.png` (cada letra numa célula 8×8, largura variável) + `accented.png` (acentos latinos, célula 9×12) →
#  um `FontFile` de tamanho fixo. A largura de cada letra é a do vanilla: coluna mais à direita com pixel + 1;
#  o avanço soma 1 pixel de espaço. Sem os arquivos locais (`assets/minecraft_local/`, fora do git) `fonte()` devolve null
#  e quem chama fica com a fonte do tema — o jogo roda igual ao de antes.
#
#  ⚠️ Use tamanhos MÚLTIPLOS DE 8 (8, 16, 24…): é uma fonte de pixels, e `FIXED_SIZE_SCALE_INTEGER_ONLY` só amplia em
#  inteiros. Um `font_size` de 14 vira 8 (arredonda para baixo) — `tamanho_para()` já converte do tamanho "de design".
# ============================================================================

const PASTA := "res://assets/minecraft_local/gui/"
const CELULA := 8
const ALTURA_ACENTO := 12
## O `accented.png` tem células de 9×12 (144 px de largura).
const LARGURA_ACENTO := 9
## Linha de base: o 'A' do ascii sobe 7 px; o acento do 'Á' chega a 10.
const SUBIDA := 10
const DESCIDA := 2
## Letras com acento da língua portuguesa (e vizinhas) na grade de 16 colunas do `accented.png` (linha = índice da string).
const ACENTOS := ["ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏ", "ÐÑÒÓÔÕÖÙÚÛÜÝàáâã", "äåæçìíîïñòóôõöùú", "ûüýÿ"]
## Linha 15 do `accented.png`: "...ỳèéêë" — as quatro últimas colunas são è é ê ë.
const LINHA_EXTRA := 15
const COLUNA_EXTRA := 12
const EXTRA := "èéêë"

static var _tentou := false
static var _fonte: FontFile


## A fonte, ou null se as texturas locais não existem.
static func fonte() -> Font:
	if _tentou:
		return _fonte
	_tentou = true
	var ascii := _carregar("ascii.png")
	if ascii == null:
		return null
	var f := FontFile.new()
	f.fixed_size = CELULA
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	f.allow_system_fallback = true               # caractere que não existe aqui (→, •…) cai na fonte do sistema
	var tam := Vector2i(CELULA, 0)
	f.set_cache_ascent(0, CELULA, SUBIDA)
	f.set_cache_descent(0, CELULA, DESCIDA)
	# Textura 0: ascii; textura 1: acentos.
	f.set_texture_image(0, tam, 0, ascii)
	# ' ' (0x20) a '~' (0x7E): linhas 2 a 7 da grade 16×16 do ascii.
	for codigo in range(0x20, 0x7F):
		_glifo(f, 0, codigo, ascii, (codigo & 15) * CELULA, (codigo >> 4) * CELULA, CELULA, CELULA, 7, codigo == 0x20)
	var acentos := _carregar("accented.png")
	if acentos != null:
		f.set_texture_image(0, tam, 1, acentos)
		for linha in ACENTOS.size():
			for coluna in (ACENTOS[linha] as String).length():
				var ch := (ACENTOS[linha] as String).unicode_at(coluna)
				_glifo(f, 1, ch, acentos, coluna * LARGURA_ACENTO, linha * ALTURA_ACENTO, LARGURA_ACENTO, ALTURA_ACENTO, 10, false)
		for i in EXTRA.length():
			_glifo(f, 1, EXTRA.unicode_at(i), acentos, (COLUNA_EXTRA + i) * LARGURA_ACENTO, LINHA_EXTRA * ALTURA_ACENTO, LARGURA_ACENTO, ALTURA_ACENTO, 10, false)
	_fonte = f
	return _fonte


## Registra uma letra: recorta a coluna útil da célula e põe a linha de base certa. `base` = linhas da célula acima da linha de base.
static func _glifo(f: FontFile, textura: int, codigo: int, img: Image, x0: int, y0: int, largo: int, alto: int, base: int, espaco: bool) -> void:
	var tam := Vector2i(CELULA, 0)
	var largura := 0
	for x in largo:
		for y in alto:
			if x0 + x < img.get_width() and y0 + y < img.get_height() and img.get_pixel(x0 + x, y0 + y).a > 0.1:
				largura = maxi(largura, x + 1)
	if espaco:
		f.set_glyph_advance(0, CELULA, codigo, Vector2(4, 0))
		return
	if largura == 0:
		return
	f.set_glyph_advance(0, CELULA, codigo, Vector2(largura + 1, 0))
	f.set_glyph_texture_idx(0, tam, codigo, textura)
	f.set_glyph_uv_rect(0, tam, codigo, Rect2(x0, y0, largura, alto))
	f.set_glyph_size(0, tam, codigo, Vector2(largura, alto))
	f.set_glyph_offset(0, tam, codigo, Vector2(0, -base))


static func _carregar(nome: String) -> Image:
	var caminho := ProjectSettings.globalize_path(PASTA + nome)
	if not FileAccess.file_exists(caminho):
		return null
	var img := Image.load_from_file(caminho)
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## Tamanho de design (o `font_size` que o código já usa: 12, 14, 20…) → múltiplo de 8 mais próximo, no mínimo 8.
static func tamanho_para(design: int) -> int:
	return maxi(CELULA, int(round(float(design) / float(CELULA))) * CELULA)
