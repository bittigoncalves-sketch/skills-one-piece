extends RefCounted
## Compõe uma única textura por aparência, usando fontes SVG autorais exportadas.
const Catalogo := preload("res://src/player/aparencia_historia.gd")
const Tons := preload("res://src/player/tons_de_pele.gd")
const Componentes := preload("res://assets/textures/skins_historia/componentes.json")
static var _cache: Dictionary = {}


static func textura(tipo: String, tom: String, opcoes: Dictionary) -> Texture2D:
	var a := Catalogo.normalizar(opcoes)
	if Catalogo.original(a):
		return load(Tons.caminho(tipo, tom))
	var chave := tipo + "/" + Tons.normalizar(tom) + "/" + JSON.stringify(a)
	if _cache.has(chave): return _cache[chave]
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="384" height="512" viewBox="0 0 384 512">'
	var dados: Dictionary = Componentes.data
	for linha in 8:
		for lado in 6:
			var parte: String = dados.original[tipo][linha][lado]
			if linha == 0:
				parte = dados.cabeca[tipo][lado]
				if a.cabelo == "original": parte += dados.cabelo[tipo][lado]
				if lado == 0:
					parte += dados.olhos[tipo][a.olhos] + dados.sobrancelhas[tipo][a.sobrancelhas]
					if a.nariz == "original": parte += dados.nariz[tipo]
			elif linha in [1, 2, 6] and a.roupa != "original" and not Catalogo.ROUPAS_EM_MALHA.has(a.roupa):      # sobretudo e moletom são malha própria (`DetalhesHistoria`); por baixo fica a camisa original
				parte = dados.roupas[a.roupa][str(linha)][lado]
			elif linha == 4 and a.calca != "original" and a.calca != "pregueada":      # a calça pregueada é malha (`DetalhesHistoria`)
				parte = dados.calcas[a.calca][lado]
			elif linha == 5 and a.sapatos != "original" and a.sapatos != "pretos":      # sapatos pretos: malha
				parte = dados.sapatos[a.sapatos][lado]
			svg += '<g transform="translate(%d %d)">%s</g>' % [lado * 64, linha * 64, parte]
	svg += "</svg>"
	var cores: Dictionary = Tons.CATALOGO.data[Tons.normalizar(tom)].duplicate()
	var cabelo := Catalogo.cor_cabelo(a)
	cores.cabelo = "#" + cabelo.to_html(false)
	cores.cabelo_luz = "#654032" if a.cor_cabelo == "original" else "#" + cabelo.lightened(.24).to_html(false)
	# Com o sobretudo a "cor da roupa" pinta o sobretudo, não a camisa de baixo.
	var cor_da_camisa: String = "original" if Catalogo.ROUPAS_EM_MALHA.has(a.roupa) else str(a.cor_roupa)
	var roupa := Color("c65e50" if tipo == "feminino" else "246d79") if cor_da_camisa == "original" else Color(Catalogo.CORES_ROUPA[cor_da_camisa])
	cores.roupa = "#" + roupa.to_html(false)
	cores.roupa_sombra = ("#873f40" if tipo == "feminino" else "#194d5b") if cor_da_camisa == "original" else "#" + roupa.darkened(.3).to_html(false)
	cores.roupa_luz = ("#db8570" if tipo == "feminino" else "#408593") if cor_da_camisa == "original" else "#" + roupa.lightened(.25).to_html(false)
	cores.olhos = ("#43776a" if tipo == "feminino" else "#3a5149") if a.cor_olhos == "original" else "#" + str(Catalogo.CORES_OLHOS[a.cor_olhos])
	var img := Image.new()
	var erro := img.load_svg_from_string(svg.format(cores))
	if erro != OK:
		push_error("[Personalização] não foi possível compor o atlas: " + error_string(erro))
		return load(Tons.caminho(tipo, tom))
	img.generate_mipmaps()
	var textura := ImageTexture.create_from_image(img)
	# Limite da prévia: escolhas antigas saem do cache, materiais vivos seguem válidos.
	if _cache.size() >= 32: _cache.erase(_cache.keys()[0])
	_cache[chave] = textura
	return textura
