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
			"ancora": Vector3(0.5, 2.0 / 3.0, 0.5)}],
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
		"pecas": [{"cena": BASE + "luffy_calcao.glb", "no": "Torso",
			"ancora": Vector3(0.5, 0.10, 0.5)}],
	},
	"espadas_zoro": {
		"nome": "As 3 Espadas do Zoro", "parte": "cintura",
		# Do lado ESQUERDO do personagem (x = 0,0 na caixa), na altura do quadril.
		"pecas": [{"cena": BASE + "espadas_zoro.glb", "no": "Torso",
			"ancora": Vector3(0.06, 0.34, 0.62)}],
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
	"tronco":  {"rotulo": "Tronco",  "nos": ["Torso"]},
	"costas":  {"rotulo": "Costas",  "nos": ["Torso"]},
	"cintura": {"rotulo": "Cintura", "nos": ["Torso"]},
	"pernas":  {"rotulo": "Pernas",  "nos": ["Torso"]},
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
static func equipar(modelo: Node3D, id: String) -> Node3D:
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
		var caminho := String(peca["cena"])
		if not ResourceLoader.exists(caminho):
			push_warning("[Acessorios] arquivo ausente: " + caminho)
			continue
		var no := (load(caminho) as PackedScene).instantiate() as Node3D
		no.name = "%s%s_%d" % [_prefixo(String(d["parte"])), id, i]
		destino.add_child(no)
		var cx := caixa_do_no(destino)
		var a: Vector3 = peca.get("ancora", Vector3(0.5, 0.5, 0.5))
		no.position = cx.position + Vector3(cx.size.x * a.x, cx.size.y * a.y, cx.size.z * a.z)
		_converter_materiais(no)
		if primeiro == null:
			primeiro = no
		i += 1
	return primeiro


## ⚠️ TROCA O MATERIAL DO .glb PELO DO JOGO, mantendo a cor modelada.
##
## O Blender exporta um PBR comum. No mundo do jogo, que usa cel shading (banda
## de luz chapada, especular desligado), esse material fica LISO e escurece na
## sombra — o colete vermelho do Luffy saía como duas tiras marrons. Converter
## preserva a arte (a cor veio do modelo) e faz a peça pertencer à cena.
##
## É a mesma decisão já tomada para as peças de raça, pelo mesmo motivo.
static func _converter_materiais(raiz: Node3D) -> void:
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
			mi.set_surface_override_material(si, Materiais.superficie(cor))


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
