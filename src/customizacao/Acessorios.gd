class_name Acessorios
extends RefCounted
# ============================================================================
#  CATÁLOGO DE ACESSÓRIOS — a fonte única do que se veste e de como se veste.
#
#  Quem usa: o menu de Customização (`src/ui/CustomizacaoMenu.gd`) e o Gear 2
#  (`src/player/gear2_controller.gd`), que invoca o chapéu na transformação.
#
#  ⚠️ POR QUE UM CATÁLOGO, E NÃO CADA UM COM O SEU CAMINHO. O Gear 2 nasceu com o
#  caminho do `.glb` e a conta de encaixe dentro dele. Assim que o menu precisou
#  do MESMO chapéu, isso viraria a segunda cópia — e a segunda cópia é como a
#  direção da frente virou bug neste projeto (cinco expressões iguais, e a quinta
#  saiu negada sem ninguém ter contra o que conferir). Uma fonte só.
#
#  ------------------------------------------------------------------- A PARTE
#  `parte` é o que resolve a exclusão mútua pedida pelo dono: dois acessórios da
#  MESMA parte não convivem, e equipar o novo tira o antigo sozinho. Isso mora no
#  dado, não no menu — assim vale para qualquer tela que equipe alguma coisa, e
#  um acessório novo não exige mexer na regra.
#
#  ------------------------------------------------------------------ O ENCAIXE
#  `fracao_engolida` diz quanto do nó de destino a peça ENGOLE, contado do topo
#  para baixo. O chapéu usa 1/3 (decisão do dono): ele VESTE o terço de cima da
#  cabeça em vez de pousar no topo — pousado lê como prato.
#
#  A altura sai da AABB do próprio nó de destino, medida em tempo de execução.
#  Repetir aqui um número que mora no `.scn` é o que faz o encaixe quebrar em
#  silêncio quando o modelo muda de proporção.
# ============================================================================

const BASE := "res://assets/models/acessorios/"
const CABELO := "res://assets/models/cabelos/"
const BOCA := "res://assets/models/bocas/"

## ⚠️ CADA ACESSÓRIO É UMA LISTA DE PEÇAS, não uma cena só. O chinelo são DOIS
## (um por pé) — e assim que apareceu um acessório de duas pontas, "uma cena num
## nó" deixou de servir. O chapéu continua sendo uma peça só; a estrutura é que
## passou a caber nos dois.
##
## `ancora` é 0..1 dentro da caixa do nó de destino, e o modelo tem a origem no
## ponto de encaixe (ver `tools/blender/acessorios.py`). Assim posicionar é
## multiplicar, sem compensar meia altura na mão.
##
## Na âncora, **z = 0 é a FRENTE** (o personagem olha para −Z).
const CATALOGO := {
	"chapeu_palha": {
		"nome": "Chapéu de Palha", "parte": "cabeca",
		# y = 2/3: a copa engole o terço de cima da cabeça (decisão do dono).
		"pecas": [{"cena": BASE + "chapeu_palha.glb", "no": "Head",
			"ref": Vector3(0.500, 0.500, 0.740),
			"ancora": Vector3(0.5, 2.0 / 3.0, 0.5)}],
	},
	# ---- a folha de design de 2026-08-29 (imagens para designs/acessórioscabeça.png)
	# Três assentam no TOPO e três cobrem o ROSTO — e é por isso que viraram duas
	# partes do corpo, não uma: o dono escolheu poder usar coroa e máscara juntas.
	# Os modelos têm a origem no ponto de encaixe, então `y = 1.0` é o topo do
	# crânio e `z = 0.0` é a face do rosto.
	"aureola": {
		"nome": "Auréola", "parte": "cabeca",
		# ⚠️ A ÚNICA PEÇA QUE BRILHA. Na folha ela é a fonte de luz da cena, e
		# sob o cel shading do jogo um anel amarelo chapado lê como aro de
		# plástico. Ver `brilha` no `_converter_materiais`.
		"brilha": true,
		"pecas": [{"cena": BASE + "aureola.glb", "no": "Head",
			"ref": Vector3(0.500, 0.500, 0.740),
			"ancora": Vector3(0.5, 1.0, 0.5)}],
	},
	"coroa": {
		"nome": "Coroa", "parte": "cabeca",
		"pecas": [{"cena": BASE + "coroa.glb", "no": "Head",
			"ref": Vector3(0.500, 0.500, 0.740),
			"ancora": Vector3(0.5, 1.0, 0.5)}],
	},
	"cartola": {
		"nome": "Cartola", "parte": "cabeca",
		"pecas": [{"cena": BASE + "cartola.glb", "no": "Head",
			"ref": Vector3(0.500, 0.500, 0.740),
			"ancora": Vector3(0.5, 1.0, 0.5)}],
	},
	"mascara_caveira": {
		"nome": "Máscara de Caveira", "parte": "rosto",
		"pecas": [{"cena": BASE + "mascara_caveira.glb", "no": "Head",
			"ref": Vector3(0.500, 0.500, 0.740),
			"ancora": Vector3(0.5, 0.5, 0.0)}],
	},
	"mascara_peste": {
		"nome": "Máscara da Peste", "parte": "rosto",
		"pecas": [{"cena": BASE + "mascara_peste.glb", "no": "Head",
			"ref": Vector3(0.500, 0.500, 0.740),
			"ancora": Vector3(0.5, 0.5, 0.0)}],
	},
	"mascara_covid": {
		"nome": "Máscara da Covid", "parte": "rosto",
		"pecas": [{"cena": BASE + "mascara_covid.glb", "no": "Head",
			"ref": Vector3(0.500, 0.500, 0.740),
			"ancora": Vector3(0.5, 0.5, 0.0)}],
	},
	"chinelo": {
		"nome": "Chinelo", "parte": "pes",
		"pecas": [
			{"cena": BASE + "chinelo.glb", "no": "Foot_R", "ancora": Vector3(0.5, 0.0, 0.5)},
			{"cena": BASE + "chinelo.glb", "no": "Foot_L", "ancora": Vector3(0.5, 0.0, 0.5)},
		],
	},
	"capa_marinha": {
		"nome": "Capa da Marinha", "parte": "costas",
		"pecas": [{"cena": BASE + "capa_marinha.glb", "no": "Torso",
			"ancora": Vector3(0.5, 1.0, 0.5)}],
	},
	"luffy_camisa": {
		"nome": "Colete do Luffy", "parte": "tronco",
		"pecas": [{"cena": BASE + "luffy_camisa.glb", "no": "Torso",
			"ancora": Vector3(0.5, 1.0, 0.5)}],
	},
	"luffy_calcao": {
		"nome": "Calção do Luffy", "parte": "pernas",
		# Um único .glb preso ao Torso não acompanha as pernas quando elas dobram.
		# O calção é, portanto, dividido em cintura + uma bainha por coxa. Cada
		# metade vira filha do nó que a animação realmente movimenta.
		"pecas": [
			{"gerador": "calcao_luffy_cintura", "no": "Torso",
				"ancora": Vector3(0.5, 0.10, 0.5)},
			{"gerador": "calcao_luffy_perna", "no": "Thigh_R",
				"ancora": Vector3(0.5, 0.31, 0.5)},
			{"gerador": "calcao_luffy_perna", "no": "Thigh_L",
				"ancora": Vector3(0.5, 0.31, 0.5)},
		],
	},
	"espadas_zoro": {
		"nome": "As 3 Espadas do Zoro", "parte": "cintura",
		# Do lado ESQUERDO do personagem (x = 0,0 na caixa), na altura do quadril.
		"pecas": [{"cena": BASE + "espadas_zoro.glb", "no": "Torso",
			"ancora": Vector3(0.06, 0.34, 0.62)}],
	},
	# ---- CABELOS (folha de 2026-08-29, metade de baixo)
	# ⚠️ SEM OLHOS. Os olhos que aparecem na folha ao lado dos cabelos são
	# referência de altura e nada mais — instrução explícita do dono. Quem
	# desenha olho é o `Corpo.gd`, e um cabelo que trouxesse o seu daria dois
	# pares na cara de quem escolhesse os dois.
	#
	# `tingivel` é o que faz a cor ser do JOGADOR e não do estilo: os modelos
	# saem do Blender numa cor neutra só, e a paleta pinta. Fixar preto no
	# espetado e loiro no curto, como na folha, impediria "moicano loiro".
	"cabelo_espetado": {
		"nome": "Espetado", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "espetado.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_baguncado": {
		"nome": "Bagunçado", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "baguncado.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_topete": {
		"nome": "Topete", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "topete.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_curto": {
		"nome": "Curto", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "curto.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_cacheado": {
		"nome": "Cacheado", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "cacheado.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_longo": {
		"nome": "Longo", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "longo.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_franja": {
		"nome": "Franja", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "franja.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_lateral": {
		"nome": "Lateral", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "lateral.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_moicano": {
		"nome": "Moicano", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "moicano.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_dread": {
		"nome": "Dread", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "dread.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_super_espetado": {
		"nome": "Super Espetado", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "super_espetado.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"cabelo_rabo_de_cavalo": {
		"nome": "Rabo de Cavalo", "parte": "cabelo", "tingivel": true,
		"pecas": [{"cena": CABELO + "rabo_de_cavalo.glb", "no": "Head",
			"ancora": Vector3(0.5, 1.0, 0.5), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	# ---- BOCAS (folha de 2026-08-29, metade de cima)
	# A cabeça do rig é lisa: a boca é placa fina na FACE FRONTAL, como o olho.
	# Âncora y=0,32 — bem abaixo dos olhos, que ficam em 0,60.
	"boca_neutra": {
		"nome": "Neutra", "parte": "boca",
		"pecas": [{"cena": BOCA + "neutra.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_sorriso": {
		"nome": "Sorriso", "parte": "boca",
		"pecas": [{"cena": BOCA + "sorriso.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_feliz": {
		"nome": "Feliz", "parte": "boca",
		"pecas": [{"cena": BOCA + "feliz.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_sorriso_com_dentes": {
		"nome": "Sorriso com Dentes", "parte": "boca",
		"pecas": [{"cena": BOCA + "sorriso_com_dentes.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_smirk": {
		"nome": "Smirk", "parte": "boca",
		"pecas": [{"cena": BOCA + "smirk.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_triste": {
		"nome": "Triste", "parte": "boca",
		"pecas": [{"cena": BOCA + "triste.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_surpreso": {
		"nome": "Surpreso", "parte": "boca",
		"pecas": [{"cena": BOCA + "surpreso.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_bravo": {
		"nome": "Bravo", "parte": "boca",
		"pecas": [{"cena": BOCA + "bravo.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_dentes_cerrados": {
		"nome": "Dentes Cerrados", "parte": "boca",
		"pecas": [{"cena": BOCA + "dentes_cerrados.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_assustado": {
		"nome": "Assustado", "parte": "boca",
		"pecas": [{"cena": BOCA + "assustado.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_tirando_lingua": {
		"nome": "Tirando Língua", "parte": "boca",
		"pecas": [{"cena": BOCA + "tirando_lingua.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
	"boca_desconfortavel": {
		"nome": "Desconfortável", "parte": "boca",
		"pecas": [{"cena": BOCA + "desconfortavel.glb", "no": "Head",
			"ancora": Vector3(0.5, 0.32, 0.0), "ref": Vector3(0.500, 0.500, 0.740)}],
	},
}

## Cada parte do corpo: o rótulo que a interface mostra e o NÓ do modelo onde as
## peças dela penduram. O nó vive aqui, e não em cada acessório, porque é
## propriedade da PARTE — dois chapéus não penduram em nós diferentes.
## Cada parte do corpo: o rótulo que a interface mostra e o NÓ onde as peças dela
## penduram — usado para LIMPAR a parte inteira antes de equipar outra coisa.
##
## ⚠️ `pes` tem DOIS nós, e por isso a limpeza varre uma lista, não um nó só.
const PARTES := {
	"cabeca":  {"rotulo": "Cabeça",  "nos": ["Head"]},
	# ⚠️ `rosto` pendura no MESMO nó que `cabeca`, e isso é de propósito: são
	# duas partes porque se excluem em grupos diferentes, não porque penduram em
	# lugares diferentes. Igual a tronco/costas/cintura/pernas, que dividem o
	# `Torso`. Quem separa uma limpeza da outra é a parte no NOME da peça.
	"rosto":   {"rotulo": "Rosto",   "nos": ["Head"]},
	"cabelo":  {"rotulo": "Cabelo",  "nos": ["Head"]},
	"boca":    {"rotulo": "Boca",    "nos": ["Head"]},
	"tronco":  {"rotulo": "Tronco",  "nos": ["Torso"]},
	"costas":  {"rotulo": "Costas",  "nos": ["Torso"]},
	"cintura": {"rotulo": "Cintura", "nos": ["Torso"]},
	"pernas":  {"rotulo": "Pernas",  "nos": ["Torso", "Thigh_R", "Thigh_L"]},
	"pes":     {"rotulo": "Pés",     "nos": ["Foot_R", "Foot_L"]},
}

## Sufixo do nome do nó equipado. Serve para achar e remover o que já está lá
## sem depender de guardar referência — o modelo pode ter sido reconstruído.
const MARCA := "Acessorio_"

## ⚠️ O NOME DA PEÇA CARREGA A PARTE: `Acessorio_<parte>_<id>_<i>`.
##
## Sem isso a limpeza por prefixo apagava demais: "tronco", "costas", "cintura" e
## "pernas" penduram todas no MESMO nó (`Torso`), então equipar as espadas
## (cintura) varria o colete (tronco) junto. Com a parte no nome, cada limpeza
## alcança só o que é dela — e continua alcançando ÓRFÃO, que é o motivo de a
## varredura ser por prefixo e não pela lista do catálogo.
static func _prefixo(parte: String) -> String:
	return "%s%s_" % [MARCA, parte]


static func ids() -> Array:
	return CATALOGO.keys()


static func por_parte(parte: String) -> Array:
	var out: Array = []
	for id in CATALOGO:
		if String(CATALOGO[id]["parte"]) == parte:
			out.append(id)
	return out


static func dados(id: String) -> Dictionary:
	return CATALOGO.get(id, {})


static func parte_de(id: String) -> String:
	return String(CATALOGO.get(id, {}).get("parte", ""))


## Veste `id` no `modelo`, tirando antes o que já ocupava a mesma parte.
## Devolve o primeiro nó criado, ou `null` se não deu.
## `tinta` só vale para peça marcada `tingivel` no catálogo (hoje, os cabelos):
## alpha 0 = "usa a cor do modelo". Passar a cor como ARGUMENTO, e não ler de um
## estado global, é o que mantém `Acessorios` sem saber que existe um menu.
static func equipar(modelo: Node3D, id: String, tinta: Color = Color(0, 0, 0, 0)) -> Node3D:
	var d := dados(id)
	if d.is_empty():
		push_warning("[Acessorios] id desconhecido: " + id)
		return null
	if modelo == null or not is_instance_valid(modelo):
		return null

	# A exclusão mútua acontece AQUI, e não em quem chama: assim qualquer tela
	# que equipe herda a regra de graça.
	desequipar(modelo, String(d["parte"]))

	var primeiro: Node3D = null
	var i := 0
	for p in d.get("pecas", []):
		var peca: Dictionary = p
		var destino := modelo.find_child(String(peca["no"]), true, false) as Node3D
		if destino == null:
			push_warning("[Acessorios] nó '%s' não existe neste modelo" % peca["no"])
			continue
		var gerada := peca.has("gerador")
		var no: Node3D = null
		if gerada:
			no = _criar_roupa_gerada(String(peca["gerador"]), destino)
		else:
			var caminho := String(peca["cena"])
			if not ResourceLoader.exists(caminho):
				push_warning("[Acessorios] arquivo ausente: " + caminho)
				continue
			no = (load(caminho) as PackedScene).instantiate() as Node3D
		if no == null:
			continue
		no.name = "%s%s_%d" % [_prefixo(String(d["parte"])), id, i]
		destino.add_child(no)
		_fixar_ao_rig(no)
		var cx := caixa_do_no(destino)
		var a: Vector3 = peca.get("ancora", Vector3(0.5, 0.5, 0.5))
		# A roupa gerada já posiciona cada painel no espaço do membro; os .glb
		# continuam usando a âncora única tradicional.
		if not gerada:
			no.position = cx.position + Vector3(cx.size.x * a.x, cx.size.y * a.y, cx.size.z * a.z)
		# ⚠️ A PEÇA SE AJUSTA À CABEÇA EM QUE VESTE (2026-08-29).
		#
		# A âncora sempre foi fração da caixa, mas o TAMANHO do .glb era
		# absoluto — e os dois modelos do jogo não têm a mesma cabeça: o menu
		# monta por `CharacterBuilder.build_character("base")`, cujo `Head` tem
		# 0,400 de profundidade, e a partida monta pelo rig, cujo `Head` tem
		# 0,740. Medido, não suposto: as duas tabelas de medidas dos scripts do
		# Blender divergem exatamente nisso, cada uma tirada de um modelo.
		#
		# O sintoma era o chapéu de palha aparecer esticado para trás na
		# prévia, atravessando a nuca — e valia para toda peça nova.
		#
		# `ref` é a caixa para a qual o modelo FOI FEITO; a razão entre a caixa
		# real e ela devolve a proporção. Não-uniforme de propósito: o que muda
		# entre as duas cabeças é só a profundidade, e é só nela que a peça
		# deve encolher.
		if peca.has("ref"):
			var r: Vector3 = peca["ref"]
			no.scale = Vector3(cx.size.x / r.x, cx.size.y / r.y, cx.size.z / r.z)
		var pintar := tinta if (bool(d.get("tingivel", false)) and tinta.a > 0.0) \
			else Color(0, 0, 0, 0)
		if not gerada:
			_converter_materiais(no, bool(d.get("brilha", false)), pintar)
		if primeiro == null:
			primeiro = no
		i += 1
	return primeiro


## Peças simples divididas por membro. O rig do jogador é hierárquico (não um
## Skeleton3D compartilhável), por isso roupa sem skin precisa nascer em cada
## membro que se move. Assim a bainha acompanha corrida, salto e golpes.
static func _criar_roupa_gerada(tipo: String, destino: Node3D) -> Node3D:
	var raiz := Node3D.new()
	var cx := caixa_do_no(destino)
	if tipo == "calcao_luffy_cintura":
		_adicionar_tecido(raiz, "Cintura", Vector3(cx.size.x * 1.08,
			maxf(0.08, cx.size.y * 0.12), cx.size.z * 1.08),
			cx.position + Vector3(cx.size.x * 0.5, cx.size.y * 0.12, cx.size.z * 0.5),
			Color(0.22, 0.34, 0.62))
	elif tipo == "calcao_luffy_perna":
		var altura := maxf(0.12, cx.size.y * 0.52)
		_adicionar_tecido(raiz, "Tecido", Vector3(cx.size.x * 1.12, altura,
			cx.size.z * 1.12), cx.position + Vector3(cx.size.x * 0.5,
			cx.size.y * 0.31, cx.size.z * 0.5), Color(0.22, 0.34, 0.62))
		_adicionar_tecido(raiz, "Bainha", Vector3(cx.size.x * 1.17,
			maxf(0.045, altura * 0.18), cx.size.z * 1.17),
			cx.position + Vector3(cx.size.x * 0.5, cx.size.y * 0.08, cx.size.z * 0.5),
			Color(0.90, 0.90, 0.88))
	else:
		push_warning("[Acessorios] roupa gerada desconhecida: " + tipo)
		return null
	return raiz


static func _adicionar_tecido(raiz: Node3D, nome: String, tamanho: Vector3,
		posicao: Vector3, cor: Color) -> void:
	var malha := MeshInstance3D.new()
	malha.name = nome
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	malha.mesh = caixa
	malha.position = posicao
	malha.material_override = Materiais.superficie(cor)
	raiz.add_child(malha)


## Importações podem marcar nós como `top_level`; nesse modo eles ignoram a
## transformação do pai e a roupa parece ficar parada no mundo. Forçamos o
## vínculo local em toda a árvore da peça antes de ela entrar em cena.
static func _fixar_ao_rig(raiz: Node3D) -> void:
	var fila: Array[Node] = [raiz]
	while not fila.is_empty():
		var atual: Node = fila.pop_back() as Node
		if atual is Node3D:
			(atual as Node3D).top_level = false
		for filho in atual.get_children():
			fila.append(filho)


## ⚠️ TROCA O MATERIAL DO .glb PELO DO JOGO, mantendo a cor modelada.
##
## O Blender exporta um PBR comum. No mundo do jogo, que usa cel shading (banda
## de luz chapada, especular desligado), esse material fica LISO e escurece na
## sombra — o colete vermelho do Luffy saía como duas tiras marrons. Converter
## preserva a arte (a cor veio do modelo) e faz a peça pertencer à cena.
##
## É a mesma decisão já tomada para as peças de raça, pelo mesmo motivo.
## `brilha` troca a superfície do jogo por luz própria — ver a nota da auréola no
## catálogo. É opcional e falso por padrão: uma peça que brilha sem motivo rouba
## a leitura do personagem inteiro.
static func _converter_materiais(raiz: Node3D, brilha: bool = false,
		tinta: Color = Color(0, 0, 0, 0)) -> void:
	var malhas: Array = []
	FxUtil._collect_meshes(raiz, malhas)
	for m in malhas:
		if not (m is MeshInstance3D):
			continue
		var mi := m as MeshInstance3D
		for si in mi.get_surface_override_material_count():
			var orig := mi.mesh.surface_get_material(si) if mi.mesh else null
			var cor := Color(0.7, 0.7, 0.7)
			if orig is StandardMaterial3D:
				cor = (orig as StandardMaterial3D).albedo_color
			elif orig is BaseMaterial3D:
				cor = (orig as BaseMaterial3D).albedo_color
			if tinta.a > 0.0:
				cor = tinta            # peça tingível: a cor é do jogador
			mi.set_surface_override_material(si,
				Materiais.brilho(cor) if brilha else Materiais.superficie(cor))


## Tira o que estiver equipado naquela parte. Silencioso se não houver nada.
##
## ⚠️ VARRE POR PREFIXO, não pela lista do catálogo. Procurar só os ids que o
## catálogo conhece HOJE deixaria órfão inarredável qualquer peça equipada por um
## catálogo antigo — e órfão numa parte do corpo é justamente o que a exclusão
## mútua existe para impedir.
static func desequipar(modelo: Node3D, parte: String) -> void:
	var pre := _prefixo(parte)
	for destino in nos_da_parte(modelo, parte):
		for f in destino.get_children():
			if String(f.name).begins_with(pre):
				destino.remove_child(f)
				f.queue_free()


## Os nós do modelo onde as peças desta parte penduram. Pode ser mais de um: os
## pés são dois.
static func nos_da_parte(modelo: Node3D, parte: String) -> Array:
	var out: Array = []
	if modelo == null or not is_instance_valid(modelo):
		return out
	var d: Dictionary = PARTES.get(parte, {})
	if d.is_empty():
		return out
	for nome in d["nos"]:
		var n := modelo.find_child(String(nome), true, false) as Node3D
		if n:
			out.append(n)
	return out


## Compatibilidade: o primeiro nó da parte (o Gear 2 e sondas antigas usam).
static func no_da_parte(modelo: Node3D, parte: String) -> Node3D:
	var l := nos_da_parte(modelo, parte)
	return l[0] if l.size() > 0 else null


static func equipado_na_parte(modelo: Node3D, parte: String) -> String:
	var pre := _prefixo(parte)
	for destino in nos_da_parte(modelo, parte):
		for f in destino.get_children():
			var nome := String(f.name)
			if nome.begins_with(pre):
				var resto := nome.substr(pre.length())
				var corte := resto.rfind("_")
				return resto.substr(0, corte) if corte > 0 else resto
	return ""


## A AABB do nó em espaço LOCAL dele — o mesmo espaço do acessório, já que ele
## entra como filho. Por isso não há conversão de escala aqui.
static func caixa_do_no(no: Node3D) -> AABB:
	if no is MeshInstance3D and (no as MeshInstance3D).mesh != null:
		return (no as MeshInstance3D).mesh.get_aabb()
	var uniao := AABB()
	var primeiro := true
	var malhas: Array = []
	FxUtil._collect_meshes(no, malhas)
	for m in malhas:
		if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
			var a: AABB = (m as MeshInstance3D).mesh.get_aabb()
			uniao = a if primeiro else uniao.merge(a)
			primeiro = false
	if primeiro:
		push_warning("[Acessorios] nó sem malha — caixa padrão")
		return AABB(Vector3(-0.25, 0.0, -0.25), Vector3(0.5, 0.5, 0.5))
	return uniao
