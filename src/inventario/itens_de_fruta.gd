class_name ItensDeFruta
extends RefCounted
## FRUTAS COMO ITENS DO INVENTÁRIO (25/11/2026, pedido do dono: "passar todas as frutas para o inventário normal, de vez"): a aba FRUTAS acabou.
## Akuma no Mi = pilha `akuma:<id>`; fruta do pomar (comida de domar) = pilha `pomar:<id>`; as duas empilham até 64 e entram na hotbar/mochila como
## qualquer item. Comer a Akuma: botão direito com ela na mão (ou no slot da mochila); a do pomar fica "na mão" quando seu slot da hotbar está selecionado.
## A posse é do INVENTÁRIO; `ProgressaoDoPersonagem.frutas_compradas/frutas_do_pomar` só guardam o EXCEDENTE que não coube (e saves antigos até migrarem).
const AKUMA := "akuma:"
const POMAR := "pomar:"
const LIMITE := 64
## Pasta dos ícones 2D novos (Codex, 32×32, nome = id do modelo da fruta; aliases usam o da base).
const PASTA_ICONES := "res://assets/ui/frutas/akuma/"
static var _texturas := {}


## Comer a Akuma `tag` (botão direito). `confirmado`: o jogador já aceitou perder a fruta que tem no corpo.
## `so_validar`: só confere (sem comer) e devolve "pode". Devolve {"estado": "comeu" | "pode" | "confirmar" | "igual" | "falhou", "texto": aviso}.
static func comer(prog: ProgressaoDoPersonagem, tag: String, confirmado: bool, so_validar := false) -> Dictionary:
	var id := id_de(tag)
	var nome_novo := nome(tag)
	if prog.fruta == id:
		return {"estado": "igual", "texto": "Você já está com a %s" % nome_novo}
	var antiga := prog.fruta
	if not antiga.is_empty() and not confirmado:
		return {"estado": "confirmar", "texto": "Comer a %s faz perder a %s — botão direito de novo para confirmar" % [nome_novo, PerfilDeFrutas.nome_da_fruta(antiga)]}
	if so_validar:
		# Pode comer: quem chamou anima o gesto (com som) e chama `comer` de verdade ao fim (`so_validar = false`).
		if id != KitDoBuilder.ID and prog.quantas_akuma(id) <= 0:
			return {"estado": "falhou", "texto": "Não deu para comer a %s" % nome_novo}
		return {"estado": "pode", "texto": ""}
	var ok := prog.comer_fruta(id) if id == KitDoBuilder.ID else prog.comer_fruta_comprada(id)
	if not ok:
		return {"estado": "falhou", "texto": "Não deu para comer a %s" % nome_novo}
	return {"estado": "comeu", "texto": "Comeu a %s%s  ·  Z, X, C e V na barra" % [nome_novo, "" if antiga.is_empty() else "  ·  perdeu a %s" % PerfilDeFrutas.nome_da_fruta(antiga)]}


static func tag_akuma(id: String) -> String:
	return AKUMA + id


static func tag_pomar(id: String) -> String:
	return POMAR + id


static func e_akuma(tag: String) -> bool:
	return tag.begins_with(AKUMA)


static func e_do_pomar(tag: String) -> bool:
	return tag.begins_with(POMAR)


static func e_de(tag: String) -> bool:
	return e_akuma(tag) or e_do_pomar(tag)


static func id_de(tag: String) -> String:
	return tag.trim_prefix(AKUMA).trim_prefix(POMAR)


static func nome(tag: String) -> String:
	var id := id_de(tag)
	if e_akuma(tag):
		return KitDoBuilder.NOME if id == KitDoBuilder.ID else PerfilDeFrutas.nome_da_fruta(id)
	var bib := MapaMontador.biblioteca_em_uso()
	return str(bib.info(id)["nome"]) if bib != null and bib.tem(id) else id.trim_prefix("fruta_").capitalize()


static func caminho_do_icone(tag: String) -> String:
	var id := id_de(tag)
	if e_akuma(tag):
		var novo := PASTA_ICONES + TreeAndFruitGenerator.id_do_modelo(id) + ".png"
		if ResourceLoader.exists(novo):
			return novo
	return PerfilDeFrutas.imagem_na_loja(id)


static func icone(tag: String) -> Texture2D:
	if _texturas.has(tag):
		return _texturas[tag]
	var caminho := caminho_do_icone(tag)
	var tex: Texture2D = load(caminho) as Texture2D if ResourceLoader.exists(caminho) else null
	_texturas[tag] = tex
	return tex
