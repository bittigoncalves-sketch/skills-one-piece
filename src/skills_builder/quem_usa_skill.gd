class_name QuemUsaSkill
extends RefCounted
## QUEM usa uma skill do Builder (decisão do dono, 06/10/2026): a atribuição mora na
## própria skill — Usuário (Jogador, Inimigo, Chefe, Animal) + "Quem usa" (o id):
##   • Inimigo: um modelo da categoria "inimigos" da loja — vale para o inimigo do
##     mapa daquele modelo e para o boneco de duelo do ninho daquele modelo;
##   • Chefe: a Harpia (Modo História) ou o Buggy (arena);
##   • Animal: uma espécie (modelo da loja com ficha de animal);
##   • Jogador: não escolhe — a skill vai para a tecla dela no Kit do Builder.
## A IA desta etapa usa as de Inimigo. Chefe e Animal ficam atribuídos e passam a
## valer quando a IA deles for feita (GATILHO: o dono pedir chefe/animal usando).

const CHEFES: Array[Dictionary] = [
	{"id": "harpia", "nome": "Harpia (Modo História)"},
	{"id": "buggy", "nome": "Buggy (arena)"},
]
## Usuários cujo "quem usa" a IA já lê.
const COM_IA: Array[String] = ["Jogador", "Inimigo"]


## [{id, nome}] que podem usar uma skill deste Usuário.
static func opcoes(dono: String, biblioteca: BibliotecaDeModelos = null) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	match dono:
		"Chefe":
			saida.assign(CHEFES)
		"Inimigo", "Animal":
			var bib := biblioteca if biblioteca != null else BibliotecaDeModelos.padrao()
			for id: String in bib.ids():
				var entra := InimigoDoMapa.CATEGORIA in bib.categorias_do_modelo(id) if dono == "Inimigo" \
					else not bib.ficha_de_animal(id).is_empty()
				if entra:
					saida.append({"id": id, "nome": str(bib.info(id).get("nome", id))})
			saida.sort_custom(func(a, b): return str(a.nome).naturalnocasecmp_to(str(b.nome)) < 0)
	return saida


static func usada_pela_ia(dono: String) -> bool:
	return dono in COM_IA
