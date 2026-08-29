class_name Visual
extends RefCounted
# ============================================================================
#  O QUE O JOGADOR ESCOLHEU — e a ÚNICA função que transforma isso num modelo.
#
#  ------------------------------------------------------------ POR QUE EXISTE
#  Até 2026-08-29 a customização era um efeito colateral da tela: o menu
#  chamava `Acessorios.equipar` direto no boneco da prévia, e a escolha morria
#  ali. O jogador montava o personagem, entrava na partida e jogava com o
#  boneco padrão — nada do que ele escolheu chegava ao mundo.
#
#  A saída não é o menu "mandar" a escolha para o Player. É haver UM estado, e
#  uma função que o aplica a QUALQUER modelo:
#
#      menu   -> Visual.aplicar(boneco da prévia)
#      jogo   -> Visual.aplicar(modelo do Player)
#
#  ⚠️ É POR ISSO QUE O MENU TAMBÉM PASSA POR AQUI, e não guarda o estado no
#  próprio boneco. Se a prévia usasse um caminho e a partida outro, as duas
#  poderiam divergir — e a prévia existe justamente para prometer o que a
#  partida vai cumprir. Com uma função só, "testar se o que escolhi apareceu no
#  jogo" vira comparar dois modelos que passaram pelo MESMO código.
#
#  ------------------------------------------------------------------ ESTADO
#  Estático, como o `CombatResolver`, e pelo mesmo motivo: é meia dúzia de
#  campos de vida longa, e um autoload novo entraria na ordem de inicialização
#  do `project.godot` sem precisar.
# ============================================================================

const ARQUIVO := "user://visual.cfg"

## parte do corpo -> id do acessório. Parte ausente = nada equipado ali.
static var acessorios: Dictionary = {}
static var raca: String = ""
static var olho: String = ""

## Cor do corpo: `idx < 0` = "original" (sem pintura). O grupo diz de qual
## lista o índice é — as duas são exclusivas, o corpo tem uma cor só.
static var cor_grupo: String = "time"
static var cor_idx: int = -1

## Cor do cabelo. Índice em `Paleta.CABELOS`; o dono escolheu que a cor é do
## jogador e não do estilo, então ela vive aqui e não no catálogo.
static var cabelo_idx: int = 0


# ------------------------------------------------------------------- escolhas
static func equipar(parte: String, id: String) -> void:
	if id == "":
		acessorios.erase(parte)
	else:
		acessorios[parte] = id


static func equipado(parte: String) -> String:
	return String(acessorios.get(parte, ""))


static func cor_do_corpo() -> Color:
	if cor_idx < 0:
		return Color(0, 0, 0, 0)         # alpha 0 = não pintar
	var lista: Array = Paleta.PELES if cor_grupo == "pele" else Paleta.CORES
	if cor_idx >= lista.size():
		return Color(0, 0, 0, 0)
	return lista[cor_idx]["cor"]


static func cor_do_cabelo() -> Color:
	if cabelo_idx < 0 or cabelo_idx >= Paleta.CABELOS.size():
		return Paleta.CABELOS[0]["cor"]
	return Paleta.CABELOS[cabelo_idx]["cor"]


# ------------------------------------------------------------------- aplicar
## Deixa `modelo` exatamente como o estado descreve. Idempotente: limpa antes de
## montar, então chamar duas vezes dá o mesmo resultado que chamar uma.
## `preservar_cor_do_jogo` existe por causa da COR DE TIME. No menu, escolher
## "Original" tem de LIMPAR a pintura anterior — é o que devolve o personagem à
## cor nativa. Em partida, limpar apagaria o `_tingir_modelo` do Player, que é
## quem pinta o corpo com a cor do time e é o que distingue os jogadores. Então
## lá a limpeza não acontece: sem escolha de cor, o que o jogo pintou fica.
static func aplicar(modelo: Node3D, preservar_cor_do_jogo: bool = false) -> void:
	if modelo == null or not is_instance_valid(modelo):
		return

	# ⚠️ LIMPA TODA PARTE, inclusive as que o estado não menciona. Sem isso,
	# reaplicar depois de tirar um chapéu deixaria o chapéu velho no lugar — o
	# estado diz o que HÁ, e o que ele não diz tem de sumir.
	for parte in Acessorios.PARTES:
		Acessorios.desequipar(modelo, parte)
	Racas.remover(modelo)
	Corpo.remover(modelo)

	for parte in acessorios:
		var id := String(acessorios[parte])
		Acessorios.equipar(modelo, id, cor_do_cabelo())
	if raca != "":
		Racas.aplicar(modelo, raca)
	if olho != "":
		Corpo.aplicar(modelo, olho)
	pintar(modelo, preservar_cor_do_jogo)


## Pinta o CORPO (e só ele) com a cor escolhida. Peça de raça marcada
## `segue_cor` conta como corpo — é o que faz orelha e rabo do Mink Lobo saírem
## da cor do personagem, que foi o pedido de 2026-08-28.
static func pintar(modelo: Node3D, preservar_cor_do_jogo: bool = false) -> void:
	if modelo == null or not is_instance_valid(modelo):
		return
	var cor := cor_do_corpo()
	if cor.a <= 0.0 and preservar_cor_do_jogo:
		return                    # sem escolha de cor: não mexe no que já está lá
	var malhas: Array = []
	FxUtil._collect_meshes(modelo, malhas)
	for m in malhas:
		if not (m is MeshInstance3D):
			continue
		if e_adorno(m) and not Racas.segue_cor(m):
			continue
		if cor.a <= 0.0:
			(m as MeshInstance3D).material_override = null
			continue
		# O MESMO material do jogo (cel shading). Uma prévia com outra
		# iluminação mentiria sobre a cor que vai aparecer em partida.
		(m as MeshInstance3D).material_override = Materiais.superficie(cor)


## Acessório, cabelo, boca ou peça de raça — o que NÃO é corpo.
static func e_adorno(n: Node) -> bool:
	var p: Node = n
	while p != null:
		var nome := String(p.name)
		if nome.begins_with(Acessorios.MARCA) or nome.begins_with(Racas.MARCA) \
				or nome.begins_with(Corpo.MARCA):
			return true
		p = p.get_parent()
	return false


# --------------------------------------------------------------- persistência
static func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("visual", "acessorios", acessorios)
	cfg.set_value("visual", "raca", raca)
	cfg.set_value("visual", "olho", olho)
	cfg.set_value("visual", "cor_grupo", cor_grupo)
	cfg.set_value("visual", "cor_idx", cor_idx)
	cfg.set_value("visual", "cabelo_idx", cabelo_idx)
	cfg.save(ARQUIVO)


## ⚠️ CARREGA UMA VEZ POR EXECUÇÃO. Quem precisa do estado são dois pontos que
## não se conhecem — o menu, ao abrir, e o Player, ao montar o rig — e qualquer
## um dos dois pode ser o primeiro (dá para entrar na partida sem passar pelo
## menu). Sem a guarda, o Player recarregaria do disco por cima do que o jogador
## acabou de escolher e ainda não foi salvo.
static var _carregado: bool = false

static func carregar_uma_vez() -> void:
	if _carregado:
		return
	_carregado = true
	carregar()


static func carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		return
	acessorios = cfg.get_value("visual", "acessorios", {})
	raca = String(cfg.get_value("visual", "raca", ""))
	olho = String(cfg.get_value("visual", "olho", ""))
	cor_grupo = String(cfg.get_value("visual", "cor_grupo", "time"))
	cor_idx = int(cfg.get_value("visual", "cor_idx", -1))
	cabelo_idx = int(cfg.get_value("visual", "cabelo_idx", 0))
