class_name GeradorDeMiniaturas
extends Node
# ============================================================================
#  MINIATURAS da loja — uma foto de cada modelo, tirada num SubViewport isolado.
#
#  A foto é CACHE, não dado do projeto: vai para `user://` com o SHA do modelo no
#  nome, então trocar o arquivo gera foto nova e clonar o projeto em outro PC só
#  refaz as fotos na primeira vez que a loja abre. Nada disso entra no git.
#
#  Uma foto por vez, na fila: cada uma custa dois quadros de renderização, e
#  importar uma pasta com trinta modelos não pode travar o editor de uma vez.
#
#  ⚠️ Sem tela (`--headless`) não há renderização: a foto não sai e a loja mostra
#  o nome sem imagem. É o que acontece nos testes — não é falha.
# ============================================================================

signal pronta(id: String, textura: Texture2D)

const TAMANHO := 128
const PASTA := "user://miniaturas_modelos"

var biblioteca: BibliotecaDeModelos

var _fila: Array[String] = []
var _texturas := {}                 # caminho da foto -> textura (não relê o PNG a cada lista)
var _trabalhando := false
var _cenas := {}                    # chave -> pedido de `pedir_cena` (na fila como "cena:<chave>")


func caminho_da_foto(id: String) -> String:
	var vista := "-frente" if biblioteca.categorias_do_modelo(id).has("bestas_do_mar") else ""
	return PASTA.path_join("%s-%s%s.png" % [id, str(biblioteca.info(id)["sha256"]).left(12), vista])


## A foto já pronta, sem renderizar nada; null se ainda não existe.
func em_cache(id: String) -> Texture2D:
	if biblioteca == null or not biblioteca.tem(id):
		return null
	return foto_salva(caminho_da_foto(id))


func pedir(id: String) -> void:
	if biblioteca == null or not biblioteca.tem(id) or _fila.has(id):
		return
	_fila.append(id)
	if not _trabalhando:
		_processar_fila()


## Foto de uma cena qualquer na MESMA fila (uma por vez): `criar` devolve o nó 3D. Avisa
## por `pronta(chave, textura)`. Quem pede pode sumir antes (o painel da loja de
## projéteis é refeito a cada edição): a espera mora aqui, não nele.
func pedir_cena(chave: String, criar: Callable, centro: Vector3, raio: float, caminho: String,
		direcao := Vector3(1.0, 0.7, 1.0), fundo := Color(0, 0, 0, 0), realcar := false) -> void:
	if _cenas.has(chave) or sem_tela():
		return
	_cenas[chave] = {"criar": criar, "centro": centro, "raio": raio, "caminho": caminho, "direcao": direcao, "fundo": fundo, "realcar": realcar}
	_fila.append("cena:" + chave)
	if not _trabalhando:
		_processar_fila()


func sem_tela() -> bool:
	return DisplayServer.get_name() == "headless"


func _processar_fila() -> void:
	_trabalhando = true
	while not _fila.is_empty():
		var id: String = _fila.pop_front()
		if id.begins_with("cena:"):
			var chave := id.trim_prefix("cena:")
			var c: Dictionary = _cenas[chave]
			var no: Node3D = c.criar.call()
			var foto := await fotografar_cena(no, c.centro, c.raio, c.caminho, c.direcao, c.fundo, c.realcar)
			_cenas.erase(chave)
			if foto != null:
				pronta.emit(chave, foto)
			continue
		if not biblioteca.tem(id) or sem_tela():
			continue
		var textura := await _fotografar(id)
		if textura != null:
			pronta.emit(id, textura)
	_trabalhando = false


func _fotografar(id: String) -> Texture2D:
	var modelo := biblioteca.instanciar(id)
	if modelo == null:
		return null
	var e := biblioteca.info(id)
	var raio: float = maxf((e["tamanho"] as Vector3).length() * 0.5, 0.05)
	# As bestas seguem a frente -Z do projeto; +Z escondia rosto, dentes e argola.
	var direcao := Vector3(1.0, 0.7, -1.0) if biblioteca.categorias_do_modelo(id).has("bestas_do_mar") else Vector3(1.0, 0.7, 1.0)
	return await fotografar_cena(modelo, e["centro"], raio, caminho_da_foto(id), direcao)


## Foto de QUALQUER nó 3D (a loja de projéteis do Skills Builder usa, 06/10/2026): o nó
## vai para um palco isolado, a câmera enquadra a esfera (centro, raio) vista de
## `direcao`, e a foto é gravada em `caminho`. `fundo` com alfa 0 = fundo transparente
## (forma com brilho aditivo some em fundo transparente: aí use um fundo escuro).
func fotografar_cena(no: Node3D, centro: Vector3, raio: float, caminho: String,
		direcao := Vector3(1.0, 0.7, 1.0), fundo := Color(0, 0, 0, 0), realcar := false) -> Texture2D:
	var palco := SubViewport.new()
	palco.size = Vector2i(TAMANHO, TAMANHO)
	palco.own_world_3d = true           # o modelo não aparece no mapa, nem o mapa na foto
	palco.transparent_bg = fundo.a <= 0.0
	palco.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(palco)

	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR if fundo.a <= 0.0 else Environment.BG_COLOR
	ambiente.environment.background_color = fundo
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color(0.85, 0.87, 0.92)
	ambiente.environment.ambient_light_energy = 0.7
	palco.add_child(ambiente)
	var sol := DirectionalLight3D.new()
	palco.add_child(sol)
	sol.rotation_degrees = Vector3(-50, -35, 0)
	if realcar:
		# Objeto escuro (ferro, aço) em fundo escuro some: luz de preenchimento do lado da
		# câmera e um contorno de luz por trás.
		ambiente.environment.ambient_light_energy = 1.1
		for par in [[direcao, 0.7], [-direcao + Vector3.UP * 0.6, 1.3]]:
			var luz := DirectionalLight3D.new()
			luz.light_energy = par[1]
			palco.add_child(luz)
			luz.look_at_from_position(Vector3.ZERO, -(par[0] as Vector3).normalized(),
				Vector3.UP if absf((par[0] as Vector3).normalized().y) < 0.95 else Vector3.BACK)
	palco.add_child(no)

	var camera := Camera3D.new()
	camera.fov = 40.0
	palco.add_child(camera)
	raio = maxf(raio, 0.05)
	var distancia := raio / sin(deg_to_rad(camera.fov * 0.5)) * 1.05
	camera.position = centro + direcao.normalized() * distancia
	camera.near = maxf(distancia * 0.01, 0.01)
	camera.far = distancia * 4.0 + raio
	camera.look_at(centro)
	camera.current = true

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagem := palco.get_texture().get_image()
	palco.queue_free()
	if imagem == null or imagem.is_empty():
		return null
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(caminho.get_base_dir()))
	imagem.save_png(caminho)
	_texturas[caminho] = ImageTexture.create_from_image(imagem)
	return _texturas[caminho]


## Foto já tirada em `caminho` (qualquer uma), sem renderizar; null se não existe.
func foto_salva(caminho: String) -> Texture2D:
	if _texturas.has(caminho):
		return _texturas[caminho]
	if not FileAccess.file_exists(caminho):
		return null
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if imagem == null or imagem.is_empty():
		return null
	_texturas[caminho] = ImageTexture.create_from_image(imagem)
	return _texturas[caminho]
