class_name ItensDoJogo
extends RefCounted
## ITENS NUMERADOS DO JOGO COMO ITENS DO INVENTÁRIO (10/11/2026, pedido do dono: "tornar o combate e todos os itens numerados parte do inventário"):
## luta, fruta, espada, vara, machado, água, comida, pokébola e bandeira são pilhas `jogo:<id>` (limite 1) no `InventarioMinecraft`. A hotbar (slots 36–44) manda: a tecla 1–9
## é o SLOT, e arrastar o item muda o número. A posse continua sendo da `ProgressaoDoPersonagem` (`itens_possuidos`); o inventário só os posiciona.
const PREFIXO := "jogo:"
const IDS: Array[String] = ["luta", "fruta", "espada", "vara", "machado", "agua", "comida", "pokebola", "bandeira"]
const ICONES := {
	"agua": "res://assets/ui/barra/agua.svg", "comida": "res://assets/ui/barra/comida.svg", "bandeira": "res://assets/ui/barra/bandeira.svg",
	"pokebola": "res://assets/ui/barra/pokebola.svg", "machado": "res://assets/ui/barra/machado.svg", "luta": "res://assets/ui/barra/luta.svg",
	"fruta": "res://assets/ui/barra/fruta.svg", "espada": "res://assets/ui/barra/espada.svg", "pistola": "res://assets/ui/barra/pistola.svg",
	"vara": "res://assets/ui/barra/vara.svg",
}
## Fruta com ícone próprio (a Rocket é um foguete — pedido do dono).
const ICONE_POR_FRUTA := {"rocket": "res://assets/ui/barra/rocket.svg"}
const NOMES := {"machado": "Machado", "luta": "Estilo de Combate Base", "fruta": "Fruta", "espada": "Espada", "pistola": "Pistola", "vara": "Vara de pesca"}
static var _texturas := {}


static func tag(id: String) -> String:
	return PREFIXO + id


static func e_do_jogo(tag_ou_id: String) -> bool:
	return tag_ou_id.begins_with(PREFIXO)


static func id_de(tag_ou_id: String) -> String:
	return tag_ou_id.trim_prefix(PREFIXO)


static func nome(id: String, prog: ProgressaoDoPersonagem = null) -> String:
	id = id_de(id)
	if id == "agua": return "Água · botão direito"
	if id == "comida": return "Comida · botão direito"
	if id == "bandeira": return "Bandeira negra · segurar Z inicia a raid"
	if id == "pokebola": return "Pokébola · segure o botão direito e solte · gasta 1 · chance pela raridade e pela vida do alvo · +3 a cada 5 min"
	if id == "fruta" and prog != null and not prog.fruta.is_empty():
		if KitDoBuilder.e_do_builder(prog.fruta):
			return "Fruta: " + KitDoBuilder.nome(prog.fruta)
		if CatalogoFrutasMinePiece.contem(prog.fruta):
			var ficha: Dictionary = CatalogoFrutasMinePiece.FICHAS[prog.fruta]
			if not prog.espada_da_fruta.is_empty():
				return str(ficha.espada.nome)
			return "Fruta: " + str(ficha.nome)
		return "Fruta: " + prog.fruta.capitalize()
	return str(NOMES.get(id, id.capitalize()))


static func caminho_do_icone(id: String, prog: ProgressaoDoPersonagem = null) -> String:
	id = id_de(id)
	if id == "fruta" and prog != null and ICONE_POR_FRUTA.has(prog.fruta):
		return ICONE_POR_FRUTA[prog.fruta]
	if id == "fruta" and prog != null and not prog.espada_da_fruta.is_empty() and CatalogoFrutasMinePiece.contem(prog.fruta):
		var icone := str(CatalogoFrutasMinePiece.FICHAS[prog.fruta].espada.icone)
		return icone if ResourceLoader.exists(icone) else ICONES.espada
	return str(ICONES.get(id, ""))


static func textura(id: String, prog: ProgressaoDoPersonagem = null) -> Texture2D:
	if prog != null and id_de(id) == "espada" and prog.lamina_ef != "" and prog.espada_equipada:
		var do_mod := LaminasEpicFight.icone(prog.lamina_ef)       # a arma do Epic Fight empunhada mostra o ÍCONE DO MOD na barra
		if do_mod != null:
			return do_mod
	var c := caminho_do_icone(id, prog)
	if c.is_empty() or not ResourceLoader.exists(c):
		return null
	if not _texturas.has(c):
		_texturas[c] = load(c)
	return _texturas[c]
