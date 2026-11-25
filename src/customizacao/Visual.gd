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

# ============================================================================
#  PADRONIZAÇÃO TEMPORÁRIA (2026-09-08, pedido do dono)
#
#  Enquanto o MODELO DO PERSONAGEM está sendo atualizado, todo mundo joga com o
#  mesmo boneco: sem acessório, raça Humano e corpo cinza. A customização fica
#  bloqueada — não apagada.
#
#  ⚠️ GATILHO PARA DESFAZER: quando o modelo novo do personagem entrar. Vire
#  `PADRONIZADO` para `false` e o sistema inteiro volta como estava; nada aqui
#  destrói escolha nenhuma.
#
#  ⚠️ POR QUE AQUI E NÃO NO MENU. `Visual` é o ponto ÚNICO por onde a prévia do
#  menu e o modelo do Player passam — é a razão de esta classe existir (ver o
#  cabeçalho). Bloquear na tela deixaria o caminho do jogo aberto, que é
#  exatamente o defeito de 2026-08-29 que `Visual` veio consertar.
#
#  ⚠️ O QUE O JOGADOR ESCOLHEU CONTINUA NO DISCO. `user://visual.cfg` não é
#  reescrito por esta trava: `salvar()` está desligado enquanto ela vale, então
#  ninguém perde o personagem que montou. Desligar `PADRONIZADO` devolve tudo.
# ============================================================================
const PADRONIZADO := true

## A raça do boneco padrão. "humano" existe no catálogo como escolha explícita
## — é o personagem base, não a ausência de raça.
const RACA_PADRAO := "humano"

## O cinza da padronização.
##
## ⚠️ NÃO ENTRA em `Paleta.CORES`. Aquela lista é de cores de TIME, e `cor_idx`
## indexa ela — um índice que a REDE transmite. Acrescentar cinza lá o tornaria
## uma cor de time escolhível e mudaria o significado de um índice já em uso.
## Aqui ele é o que é: uma cor fixa de um estado temporário.
const COR_PADRAO := Color(0.55, 0.55, 0.57)

## Onde a escala original do modelo fica guardada — ver `escalar`.
const META_ESCALA_BASE := "visual_escala_base"

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
	if customizacao_bloqueada():
		return
	if id == "":
		acessorios.erase(parte)
	else:
		acessorios[parte] = id


static func definir_raca(id: String) -> void:
	raca = id
	# O Palhaço é uma transformação fechada: escolhas externas não atravessam
	# a maquiagem/roupa do Buggy e ficam literalmente nulas no estado salvo.
	if customizacao_bloqueada():
		acessorios.clear()
		olho = ""
		cor_grupo = "time"
		cor_idx = -1
		cabelo_idx = 0
		cor_grupo = "time"
		cor_idx = -1
		cabelo_idx = 0


static func customizacao_bloqueada() -> bool:
	# A padronização global vem PRIMEIRO: ela não depende de raça nenhuma, e é
	# justamente a raça que ela força.
	if PADRONIZADO:
		return true
	return Racas.bloqueia_customizacao(raca)


static func equipado(parte: String) -> String:
	return String(acessorios.get(parte, ""))


static func cor_do_corpo() -> Color:
	# A padronização ganha de tudo, inclusive da raça.
	if PADRONIZADO:
		return COR_PADRAO
	# ⚠️ A RAÇA VEM PRIMEIRO. O Oni é vermelho e o Lunariano é escuro por
	# definição — se a paleta ganhasse, escolher "verde" na aba Cor apagaria a
	# raça que o jogador acabou de escolher na aba ao lado.
	var da_raca := Racas.pele_de(raca)
	if da_raca.a > 0.0:
		return da_raca
	if cor_idx < 0:
		return Color(0, 0, 0, 0)         # alpha 0 = não pintar
	var lista: Array = Paleta.PELES if cor_grupo == "pele" else Paleta.CORES
	if cor_idx >= lista.size():
		return Color(0, 0, 0, 0)
	return lista[cor_idx]["cor"]


static func cor_do_cabelo() -> Color:
	# O boneco padrão é cinza inteiro — cabelo incluído, senão o corpo sai
	# uniforme e a cabeça continua com o tom que o jogador tinha escolhido.
	if PADRONIZADO:
		return COR_PADRAO
	# "cabelos sempre brancos como REGRA" para o Lunariano — mesma precedência.
	var da_raca := Racas.cabelo_de(raca)
	if da_raca.a > 0.0:
		return da_raca
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
	if is_instance_valid(modelo) and modelo.get_meta("preserve_original_materials", false):
		return
	if modelo == null or not is_instance_valid(modelo):
		return
	# Também normaliza configurações antigas carregadas do disco, que podem ter
	# acessórios gravados antes de o Palhaço virar um preset fechado.
	if customizacao_bloqueada():
		acessorios.clear()
		olho = ""
	# ⚠️ A RAÇA TAMBÉM É FORÇADA, e tem de ser aqui, ANTES do `pintar` lá
	# embaixo: `cor_do_corpo` dá precedência à pele da raça, então um "oni"
	# vindo do disco pintaria o corpo de vermelho e o cinza nunca apareceria.
	if PADRONIZADO:
		raca = RACA_PADRAO

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
	escalar(modelo)
	pintar(modelo, preservar_cor_do_jogo)


## O TAMANHO DA RAÇA no modelo (hoje, só o Gigante).
##
## ⚠️ TAMBÉM NA PRÉVIA, e não só em partida. A primeira versão deixava a escala
## inteira a cargo do Player: o Gigante crescia no jogo e a prévia mostrava um
## boneco de tamanho normal — o jogador escolheria a raça sem ver a única coisa
## que ela faz. Colisão e câmera continuam sendo do Player, porque o boneco da
## prévia não tem nem uma nem outra.
##
## A escala BASE é guardada em meta na primeira passagem: multiplicar sobre a
## escala corrente faria cada reaplicação crescer de novo — e `aplicar` é
## chamado a cada clique do menu.
static func escalar(modelo: Node3D) -> void:
	if modelo == null or not is_instance_valid(modelo):
		return
	if not modelo.has_meta(META_ESCALA_BASE):
		modelo.set_meta(META_ESCALA_BASE, modelo.scale)
	var base: Vector3 = modelo.get_meta(META_ESCALA_BASE)
	modelo.scale = base * Racas.escala_de(raca)


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
		# Pistolas da Mera são equipamento de fogo, não pele nem peça tingível.
		# A marca fica no nó-raiz e protege todas as caixas (carvão, ferro, latão
		# e brasa) tanto da cor de equipe quanto da customização do personagem.
		if nome.begins_with(Acessorios.MARCA) or nome.begins_with(Racas.MARCA) \
				or nome.begins_with(Corpo.MARCA) or nome.begins_with("MeraPistol_"):
			return true
		p = p.get_parent()
	return false


# --------------------------------------------------------------- persistência
static func salvar() -> void:
	# ⚠️ DESLIGADO enquanto a padronização vale. O estado em memória agora é o
	# boneco forçado, não a escolha do jogador; gravá-lo apagaria do disco o
	# personagem que ele montou antes — e a trava é temporária, então esse dado
	# ainda vai ser usado.
	if PADRONIZADO:
		return
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
