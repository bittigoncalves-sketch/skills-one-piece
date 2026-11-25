extends SceneTree
const Catalogo := preload("res://src/player/aparencia_historia.gd")
const Corpo := preload("res://src/player/corpo_historia.gd")
const PASTA := "res://art_src/validation/personalizacao_historia/"
var falhas := 0
var checks := 0


func _init() -> void:
	executar.call_deferred()


func executar() -> void:
	var velho := ProgressaoDoPersonagem.new().para_dict()
	velho.erase("aparencia")
	velho.nivel = 17
	ok(Catalogo.original(ProgressaoDoPersonagem.de_dict(velho).aparencia), "save antigo mantém todas as peças originais")
	for invalido: Variant in [null, 2, [], "../fora", {"cabelo": "../fora", "nariz": {}, "roupa": 2}]:
		velho.aparencia = invalido
		ok(Catalogo.original(ProgressaoDoPersonagem.de_dict(velho).aparencia), "save malformado usa catálogo seguro")
	var p := ProgressaoDoPersonagem.new()
	p.aparencia = Catalogo.normalizar({"cabelo": "cacheado", "sapatos": "tenis"})
	var salvo := ProgressaoDoPersonagem.de_dict(p.para_dict())
	ok(salvo.aparencia == p.aparencia, "aparência faz roundtrip")
	salvo.aparencia.cabelo = "careca"
	ok(p.aparencia.cabelo == "cacheado", "campanhas não compartilham dicionário")
	p.reiniciar()
	ok(Catalogo.original(p.aparencia), "reset limpa personalização")
	# Cada opção dos dois sexos deve montar sem recursos ausentes ou perder as mãos.
	for tipo: String in Corpo.TIPOS:
		for categoria: String in Catalogo.OPCOES:
			for id: String in Catalogo.OPCOES[categoria]:
				var a := Catalogo.normalizar({categoria: id})
				var modelo: Node3D = Corpo.construir(tipo, "escuro", a).node
				var cabeca := modelo.find_child("Cabeca", true, false) as MeshInstance3D
				ok(cabeca.material_override.albedo_texture != null and modelo.get_meta("aparencia_historia") == a, tipo + ": " + categoria + "/" + id)
				if categoria == "cabelo" and id not in ["original", "careca"]:
					var achou := false
					for no: Node in modelo.find_children("*", "Node3D", true, false):
						if no.get_meta("cabelo_historia", "") == id: achou = true
					ok(achou, "cabelo 3D carregado e preso ao rig")
				if categoria == "nariz" and id != "original":
					var nariz := modelo.find_child("NarizPersonalizado", true, false) as MeshInstance3D
					ok(nariz != null and nariz.get_parent().name == "Head" and nariz.mesh.get_aabb().size.z > .02, "nariz altera a geometria e acompanha Head")
				modelo.free()
	# Composição não modifica a textura base compartilhada.
	var original: Texture2D = load("res://assets/textures/skins_historia/masculino.svg")
	var antes := original.get_image().get_data()
	var personalizado: Node3D = Corpo.construir("masculino", "medio", {"roupa": "casaco", "sapatos": "tenis", "cabelo": "careca"}).node
	ok(original.get_image().get_data() == antes, "atlas base preservado após personalização")
	personalizado.free()
	var tela: Node = load("res://src/ui/escolha_corpo_historia.gd").new()
	tela.corpo_inicial = "feminino"
	root.add_child(tela)
	await quadros(8)
	for escolha: Dictionary in [
		{"sexo": "feminino", "tom": "claro", "roupa": "camisa", "cor_roupa": "creme", "calca": "escura", "sapatos": "tenis", "cabelo": "rabo_de_cavalo", "cor_cabelo": "ruivo", "nariz": "pequeno", "olhos": "grandes", "cor_olhos": "verde", "sobrancelhas": "arqueadas", "estampa_local": "peito", "oculos": "escuros", "roupa_intima": "cueca", "cor_calca": "azul"},
		{"sexo": "masculino", "tom": "moreno", "roupa": "casaco", "cor_roupa": "azul", "calca": "areia", "sapatos": "mocassim", "cabelo": "espetado", "cor_cabelo": "preto", "nariz": "reto", "olhos": "amendoados", "cor_olhos": "mel", "sobrancelhas": "espessas", "estampa_local": "original", "oculos": "original", "roupa_intima": "original", "cor_calca": "original"},
		{"sexo": "feminino", "tom": "muito_escuro", "roupa": "marinheiro", "cor_roupa": "vermelho", "calca": "listrada", "sapatos": "sandalia", "cabelo": "cacheado", "cor_cabelo": "castanho", "nariz": "largo", "olhos": "serenos", "cor_olhos": "azul", "sobrancelhas": "retas", "estampa_local": "peito", "oculos": "escuros", "roupa_intima": "original", "cor_calca": "verde"}]:
		(tela.find_child(str(escolha.sexo).capitalize(), true, false) as Button).pressed.emit()
		tela._selecionar_tom(escolha.tom)
		for categoria: String in Catalogo.OPCOES:
			if categoria == "estampa":
				continue          # a estampa é escolhida por arquivo (botão "Escolher imagem…"), coberta em test_sobretudo_historia
			var lista: OptionButton = tela._opcoes[categoria]
			var index: int = Catalogo.OPCOES[categoria].keys().find(escolha.get(categoria, "original"))
			lista.select(index)
			lista.item_selected.emit(index)
		await quadros(8)
		ok(tela._previa.modelo.get_meta("aparencia_historia") == Catalogo.normalizar(escolha), "editor atualiza todas as escolhas na prévia")
		tela._abas.current_tab = 3
		await quadros(4)
		await foto(str(escolha.sexo) + "_" + str(escolha.cabelo) + "_roupa")
		tela._abas.current_tab = 2
		await quadros(4)
		await foto(str(escolha.sexo) + "_" + str(escolha.cabelo) + "_rosto")
		tela._girar("Perfil")
		await quadros(3)
		await foto(str(escolha.sexo) + "_" + str(escolha.cabelo) + "_perfil")
		tela._girar("Frente")
	tela.queue_free()
	await quadros(3)
	print("PERSONALIZAÇÃO HISTORIA: %d/%d verificações passaram" % [checks - falhas, checks])
	quit(1 if falhas else 0)


func quadros(n: int) -> void:
	for i in n: await process_frame


func foto(nome: String) -> void:
	if "--capturar" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	ok(root.get_texture().get_image().save_png(PASTA + nome + ".png") == OK, "captura " + nome)


func ok(sim: bool, texto: String) -> void:
	checks += 1
	if not sim: falhas += 1
	print(("OK: " if sim else "FALHOU: ") + texto)
