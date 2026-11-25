class_name EstampasHistoria
extends RefCounted
## ESTAMPAS DA ROUPA (19/11/2026, pedido do dono: "adicionar imagens à roupa, por exemplo um dragão, uma serpente").
## O jogador escolhe uma imagem do disco na customização; ela é VALIDADA, reduzida e COPIADA para `user://estampas/<id>.png`. A aparência guarda só o `id`
## (16 hex do hash do PNG reduzido — `AparenciaHistoria.id_de_estampa_valido`), nunca o caminho original: o save não depende de a imagem ficar no lugar, e um id
## só pode virar caminho dentro desta pasta.
##
## SEGURANÇA (arquivo escolhido pelo usuário = entrada não confiável): extensão permitida, tamanho do arquivo limitado ANTES de decodificar, dimensões limitadas
## DEPOIS (e a imagem é reduzida), reencodada como PNG (nada do arquivo original é guardado), id gerado por nós. GATILHO: se a campanha virar multiplayer com
## aparência replicada, o PNG precisa ir junto (hoje o id sozinho só resolve na máquina de quem o importou).
const Catalogo := preload("res://src/player/aparencia_historia.gd")
const PASTA := "user://estampas"
const EXTENSOES := ["png", "jpg", "jpeg", "webp"]
const MAX_BYTES := 8 * 1024 * 1024
const MAX_LADO_DE_ORIGEM := 8192
const LADO_GUARDADO := 256            # a estampa ocupa ~0,3 m no corpo: 256 px sobra e mantém o save pequeno
static var _cache: Dictionary = {}


## Importa a imagem em `caminho`. Devolve o id da estampa, ou "" se recusada (o motivo vai em `ultimo_erro`).
static var ultimo_erro := ""


static func importar(caminho: String) -> String:
	ultimo_erro = ""
	if not EXTENSOES.has(caminho.get_extension().to_lower()):
		ultimo_erro = "Use uma imagem PNG, JPG ou WEBP."
		return ""
	if not FileAccess.file_exists(caminho):
		ultimo_erro = "Não encontrei esse arquivo."
		return ""
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		ultimo_erro = "Não consegui abrir o arquivo."
		return ""
	var tamanho := f.get_length()
	f.close()
	if tamanho <= 0 or tamanho > MAX_BYTES:
		ultimo_erro = "A imagem precisa ter até %d MB." % (MAX_BYTES / 1048576)
		return ""
	var img := Image.load_from_file(caminho)
	if img == null or img.is_empty():
		ultimo_erro = "Não consegui ler essa imagem."
		return ""
	if maxi(img.get_width(), img.get_height()) > MAX_LADO_DE_ORIGEM:
		ultimo_erro = "A imagem é grande demais (máximo %d px de lado)." % MAX_LADO_DE_ORIGEM
		return ""
	return importar_imagem(img)


## Parte comum (e testável sem arquivo): reduz, reencoda e guarda.
static func importar_imagem(img: Image) -> String:
	if img == null or img.is_empty():
		ultimo_erro = "Imagem vazia."
		return ""
	var copia := img.duplicate() as Image
	copia.convert(Image.FORMAT_RGBA8)
	var maior := maxi(copia.get_width(), copia.get_height())
	if maior > LADO_GUARDADO:
		var k := float(LADO_GUARDADO) / float(maior)
		copia.resize(maxi(1, roundi(copia.get_width() * k)), maxi(1, roundi(copia.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var bytes := copia.save_png_to_buffer()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	var id := ctx.finish().hex_encode().substr(0, 16)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var saida := FileAccess.open(caminho_do_id(id), FileAccess.WRITE)
	if saida == null:
		ultimo_erro = "Não consegui guardar a imagem."
		return ""
	saida.store_buffer(bytes)
	saida.close()
	_cache.erase(id)
	return id


## Caminho do PNG guardado; "" para id inválido (a ÚNICA porta de id → arquivo).
static func caminho_do_id(id: String) -> String:
	return "%s/%s.png" % [PASTA, id] if Catalogo.id_de_estampa_valido(id) else ""


static func existe(id: String) -> bool:
	var c := caminho_do_id(id)
	return not c.is_empty() and FileAccess.file_exists(c)


## A textura da estampa, ou null (id inválido, arquivo sumido ou ilegível: a roupa fica sem estampa, nunca quebra).
static func textura(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	if not existe(id):
		return null
	var img := Image.load_from_file(caminho_do_id(id))
	if img == null or img.is_empty():
		return null
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	if _cache.size() >= 16:
		_cache.erase(_cache.keys()[0])
	_cache[id] = t
	return t


## Proporção largura/altura da estampa guardada (para o desenho não esticar).
static func proporcao(id: String) -> float:
	var t := textura(id)
	return float(t.get_width()) / float(maxi(1, t.get_height())) if t != null else 1.0
