class_name TexturasDeBloco
extends RefCounted
# ============================================================================
#  TEXTURAS DOS BLOCOS (12/11/2026) — o visual do Minecraft nos blocos da `GradeVoxel`.
#
#  Decisão do dono (12/11/2026): blocos com a textura vanilla 16×16, filtro mais próximo, sem contorno preto.
#  As texturas são do jar do Minecraft 1.20.1 e ficam em `assets/minecraft_local/block/` (FORA do git — Mojang; receita:
#  `tools/minecraft/copiar_da_extracao.py`, ver `docs/INVENTARIO_MINECRAFT.md`). Sem a pasta, `camada` devolve −1 e o
#  shader cai na cor do tipo (`TiposDeBloco.cor`): o jogo roda igual ao de antes, só sem textura.
#
#  COMO: cada (tipo, face) aponta para uma CAMADA de uma `Texture2DArray` (topo / lado / base por tipo). A tinta do
#  bioma (grama, folhas, água) é ASSADA na imagem ao montar a camada — o vanilla pinta em tempo de desenho, aqui o
#  bioma é um só (planície), então assar custa nada e a malha não precisa de cor por vértice. As folhas viram opacas
#  (como o gráfico "rápido" do Minecraft): a malha corta a face entre folhas vizinhas, e o furo do `cutout` mostraria
#  o outro lado da copa.
#
#  A tabela é lida em THREAD (a malha roda em `WorkerThreadPool`): depois de `iniciar()` só leitura.
# ============================================================================

const PASTA := "res://assets/minecraft_local/block/"
const LADO_PX := 16
## Arte própria em resolução alta: o shader usa o original; o atlas fornece a miniatura dos ícones.
const GRAMA_PERSONALIZADA := preload("res://assets/textures/terreno/grama_anime.png")
## Cores de bioma da planície (os pixels do `colormap/grass.png` e `foliage.png` em 0,8 / 0,4; água fixa do vanilla).
const TINTA_GRAMA := Color("#a1db55") # franja lateral alinhada à grama personalizada
const TINTA_FOLHA := Color("#77ab2f")
const TINTA_AGUA := Color("#3f76e4")

## Texturas de cada tipo: [topo, lado, base] (nome do arquivo sem `.png`) e a tinta. Vazio na base = igual ao lado.
## Chave = nome do tipo em `TiposDeBloco`.
const TABELA := {
	"grama": ["grass_block_top", "grass_block_side", "dirt", "grama"],
	"terra": ["dirt", "dirt", "dirt", ""],
	"pedra": ["stone", "stone", "stone", ""],
	"areia": ["sand", "sand", "sand", ""],
	"madeira": ["oak_planks", "oak_planks", "oak_planks", ""],
	"gelo": ["ice", "ice", "ice", ""],
	"basalto": ["basalt_top", "basalt_side", "basalt_top", ""],
	"vidro": ["glass", "glass", "glass", ""],
	"agua": ["water_still", "water_still", "water_still", "agua"],
	"porta_madeira": ["oak_door_bottom", "oak_door_bottom", "oak_door_bottom", ""],
	"painel_vidro": ["glass", "glass", "glass", ""],
	"terreno": ["stone", "stone", "stone", ""],
	"tronco": ["oak_log_top", "oak_log", "oak_log_top", ""],
	"folhas": ["oak_leaves", "oak_leaves", "oak_leaves", "folha"],
	"tijolo": ["bricks", "bricks", "bricks", ""],
	"pedregulho": ["cobblestone", "cobblestone", "cobblestone", ""],
	"neve": ["snow", "snow", "snow", ""],
	"obsidiana": ["obsidian", "obsidian", "obsidian", ""],
	"argila": ["clay", "clay", "clay", ""],
	"la_branca": ["white_wool", "white_wool", "white_wool", ""],
	"la_vermelha": ["red_wool", "red_wool", "red_wool", ""],
	"la_azul": ["blue_wool", "blue_wool", "blue_wool", ""],
	"la_verde": ["green_wool", "green_wool", "green_wool", ""],
	"la_amarela": ["yellow_wool", "yellow_wool", "yellow_wool", ""],
	"alcapao_madeira": ["oak_trapdoor", "oak_trapdoor", "oak_trapdoor", ""],
}

static var _pronto := false
## Textura de todas as camadas (null = sem arquivos locais).
static var matriz: Texture2DArray
## [tipo × 6 + face] → camada (−1 = sem textura). Faces como na malha: −x, +x, −y, +y, −z, +z.
static var camada_da_face := PackedInt32Array()
## Camada da metade de cima da porta (a de baixo é a do tipo).
static var camada_porta_de_cima := -1
## As imagens de cada camada (nível 0), para quem desenha ícones de bloco.
static var imagens_das_camadas: Array[Image] = []


static func iniciar() -> void:
	if _pronto:
		return
	_pronto = true
	TiposDeBloco.iniciar()
	camada_da_face.resize(256 * 6)
	camada_da_face.fill(-1)
	var imagens: Array[Image] = []
	var indice := {}                                  # "arquivo|tinta" → camada
	for t in 256:
		var nome := TiposDeBloco.nome[t]
		var base_t := TiposDeBloco.material_do[t]
		if nome == "" or base_t != t:
			continue
		var dados := _dados_do_tipo(nome)
		if dados.is_empty():
			continue
		for d in 6:
			var arq: String = dados[0] if d == 3 else (dados[2] if d == 2 else dados[1])
			# A tinta da grama é só do TOPO (o lado leva a franja tingida; a base é terra pura).
			var tinta: String = "" if (dados[3] == "grama" and d != 3) else dados[3]
			var chave := "%s|%s" % [arq, tinta]
			if not indice.has(chave):
				var img := _imagem(arq, tinta)
				if img == null:
					indice[chave] = -1
				else:
					indice[chave] = imagens.size()
					imagens.append(img)
			camada_da_face[t * 6 + d] = indice[chave]
	# Laje, escada e octantes usam a textura do cubo do mesmo material.
	for t in 256:
		var m := TiposDeBloco.material_do[t]
		if m != t:
			for d in 6:
				camada_da_face[t * 6 + d] = camada_da_face[m * 6 + d]
	var porta := _imagem("oak_door_top", "")
	if porta != null:
		camada_porta_de_cima = imagens.size()
		imagens.append(porta)
	imagens_das_camadas = imagens
	if not imagens.is_empty():
		var m := Texture2DArray.new()
		if m.create_from_images(imagens) == OK:
			matriz = m


static func _dados_do_tipo(nome: String) -> Array:
	if TABELA.has(nome):
		return TABELA[nome]
	var e := BlocosExtras.definicao_por_nome(nome)
	if not e.is_empty():
		return [e.topo, e.lado, e.base, e.tinta]
	# laje_x / escada_x / octantes_x não entram: herdam do cubo (`material_do`).
	return []


## Camada de uma face de um tipo; `estado` só importa para a porta (metade de cima).
static func camada(tipo: int, face: int, estado := 0) -> int:
	if tipo == TiposDeBloco.PORTA_MADEIRA and (estado >> 4) & 1 == 1 and camada_porta_de_cima >= 0:
		return camada_porta_de_cima
	return camada_da_face[tipo * 6 + face]


static func tem_textura() -> bool:
	return matriz != null


## Carrega uma textura do disco (RGBA8, 16×16, com a tinta assada). null se o arquivo não existe.
static func _imagem(arquivo: String, tinta: String) -> Image:
	if arquivo == "grass_block_top":
		var grama := GRAMA_PERSONALIZADA.get_image().duplicate() as Image
		grama.convert(Image.FORMAT_RGBA8)
		grama.resize(LADO_PX, LADO_PX, Image.INTERPOLATE_LANCZOS)
		grama.generate_mipmaps()
		return grama
	var caminho := ProjectSettings.globalize_path(PASTA + arquivo + ".png")
	if not FileAccess.file_exists(caminho):
		return null
	var img := Image.load_from_file(caminho)
	if img == null or img.is_empty():
		return null
	img.convert(Image.FORMAT_RGBA8)
	# Tira animada (água, lava): só o primeiro quadro.
	if img.get_height() > img.get_width():
		img = img.get_region(Rect2i(0, 0, img.get_width(), img.get_width()))
	if img.get_width() != LADO_PX:
		img.resize(LADO_PX, LADO_PX, Image.INTERPOLATE_NEAREST)
	if arquivo == "grass_block_side":
		_sobrepor(img, "grass_block_side_overlay", TINTA_GRAMA)
	match tinta:
		"grama":
			if arquivo != "grass_block_side":
				_tingir(img, TINTA_GRAMA, false)
		"folha":
			_tingir(img, TINTA_FOLHA, true)
		"agua":
			_tingir(img, TINTA_AGUA, false)
			for y in LADO_PX:
				for x in LADO_PX:
					var c := img.get_pixel(x, y)
					c.a = 0.72
					img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return img


## Multiplica a imagem (cinza no vanilla) pela tinta. `opaca`: pixel transparente vira a mesma cor escura (folha "rápida").
static func _tingir(img: Image, tinta: Color, opaca: bool) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if opaca and c.a < 0.5:
				c = Color(0.18, 0.22, 0.12, 1.0)
			else:
				c = Color(c.r * tinta.r, c.g * tinta.g, c.b * tinta.b, 1.0 if opaca else c.a)
			img.set_pixel(x, y, c)


## O vanilla desenha a franja verde da grama (`..._side_overlay`, cinza + alfa) tingida por cima do lado de terra.
static func _sobrepor(img: Image, arquivo: String, tinta: Color) -> void:
	var caminho := ProjectSettings.globalize_path(PASTA + arquivo + ".png")
	if not FileAccess.file_exists(caminho):
		return
	var topo := Image.load_from_file(caminho)
	if topo == null or topo.is_empty():
		return
	topo.convert(Image.FORMAT_RGBA8)
	for y in mini(img.get_height(), topo.get_height()):
		for x in mini(img.get_width(), topo.get_width()):
			var o := topo.get_pixel(x, y)
			if o.a > 0.0:
				var b := img.get_pixel(x, y)
				var c := Color(o.r * tinta.r, o.g * tinta.g, o.b * tinta.b, 1.0)
				img.set_pixel(x, y, b.lerp(c, o.a))
