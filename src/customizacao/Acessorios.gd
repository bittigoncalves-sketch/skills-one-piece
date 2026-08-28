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

const CATALOGO := {
	"chapeu_palha": {
		"nome": "Chapéu de Palha",
		"parte": "cabeca",
		"cena": "res://assets/models/acessorios/chapeu_palha.glb",
		"fracao_engolida": 1.0 / 3.0,
	},
}

## Cada parte do corpo: o rótulo que a interface mostra e o NÓ do modelo onde as
## peças dela penduram. O nó vive aqui, e não em cada acessório, porque é
## propriedade da PARTE — dois chapéus não penduram em nós diferentes.
const PARTES := {
	"cabeca": {"rotulo": "Cabeça", "no": "Head"},
}

## Sufixo do nome do nó equipado. Serve para achar e remover o que já está lá
## sem depender de guardar referência — o modelo pode ter sido reconstruído.
const MARCA := "Acessorio_"


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
## Devolve o nó criado, ou `null` se não deu.
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

	var destino := no_da_parte(modelo, String(d["parte"]))
	if destino == null:
		push_warning("[Acessorios] parte '%s' não existe neste modelo" % d["parte"])
		return null
	var caminho := String(d["cena"])
	if not ResourceLoader.exists(caminho):
		push_warning("[Acessorios] arquivo ausente: " + caminho)
		return null

	var no := (load(caminho) as PackedScene).instantiate() as Node3D
	no.name = MARCA + id
	destino.add_child(no)
	var cx := caixa_do_no(destino)
	no.position = Vector3(0, cx.end.y - cx.size.y * float(d["fracao_engolida"]), 0)
	return no


## Tira o que estiver equipado naquela parte. Silencioso se não houver nada.
##
## ⚠️ VARRE POR PREFIXO, não pela lista do catálogo. Procurar só os ids que o
## catálogo conhece HOJE deixaria órfão inarredável qualquer peça equipada por um
## catálogo antigo — e órfão numa parte do corpo é justamente o que a exclusão
## mútua existe para impedir. O prefixo `MARCA` é o que identifica "isto é
## acessório", independentemente de o id ainda existir.
static func desequipar(modelo: Node3D, parte: String) -> void:
	var destino := no_da_parte(modelo, parte)
	if destino == null:
		return
	for f in destino.get_children():
		if String(f.name).begins_with(MARCA):
			destino.remove_child(f)
			f.queue_free()


## O nó do modelo onde as peças desta parte penduram.
static func no_da_parte(modelo: Node3D, parte: String) -> Node3D:
	if modelo == null or not is_instance_valid(modelo):
		return null
	var d: Dictionary = PARTES.get(parte, {})
	if d.is_empty():
		return null
	return modelo.find_child(String(d["no"]), true, false) as Node3D


static func equipado_na_parte(modelo: Node3D, parte: String) -> String:
	if modelo == null or not is_instance_valid(modelo):
		return ""
	for id in por_parte(parte):
		if modelo.find_child(MARCA + id, true, false) != null:
			return id
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
