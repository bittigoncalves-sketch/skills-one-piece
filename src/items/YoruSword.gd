class_name YoruSword
extends Node3D
## A YORU empunhada: modelo, ponto de pega e as zonas da lâmina.
##
## ============================================================================
##  O PONTO DE PEGA — `handle`, e por que ele é um nó de verdade
## ============================================================================
##  Pedido do dono (2026-09-06): *"nomeie o cabo como handle e a mão do jogador
##  também, depois os ligue — assim será possível ter uma referência de onde
##  será segurada"*.
##
##  A espada anterior resolvia isso por número mágico: o `SwordPickup` empilhava
##  um cilindro em `y = -0.15` "para que a origem seja perto do centro da mão", e
##  quem quisesse saber onde a arma era segurada tinha de reconstruir a conta de
##  cabeça. Agora existe um nó chamado **`handle`**, na origem desta cena, e a
##  regra é de uma linha: **`handle` mora em cima de `Hand_R`**.
##
##  Os dois lados são nós nomeados de propósito. `Hand_R` é criado pelo
##  `player_rig` (era um `Node3D` anônimo guardado em `item_handle`), e `handle`
##  é criado aqui. Ligar os dois é `add_child` — não há offset escondido em
##  lugar nenhum, e mover a pega é mover UM nó.
##
## ============================================================================
##  A GEOMETRIA DO MODELO — medida, não estimada
## ============================================================================
##  `yoru3Dmodel.glb` chegou como UMA malha só (875 vértices, um nó
##  `mesh_node`, sem esqueleto e sem partes separadas). Não havia cabo para
##  renomear: foi preciso descobrir onde ele está.
##
##  A silhueta foi desenhada a partir das ARESTAS da malha (varrer só os
##  vértices engana numa malha esparsa como esta) e devolveu, no eixo Y:
##
##      +0,50 .. +0,27   pomo e cabo        (largura ~0,05)
##      +0,26 .. +0,19   GUARDA, a cruz     (largura 0,35 — a peça larga)
##      +0,19 .. -0,50   lâmina             (largura ~0,046)
##      -0,50            a ponta
##
##  Ou seja: **no modelo a lâmina aponta para -Y**, a mesma convenção do
##  `espadas_zoro.glb` — e o OPOSTO da espada empunhada anterior, cuja lâmina
##  subia em +Y a partir da mão. Daí a rotação de 180° abaixo; sem ela a Yoru
##  nasce apontando para o chão.
const CAMINHO := "res://assets/models/weapons/yoru.glb"

# Escala. O modelo vem normalizado em 1,0 de altura; a 2,0 a lâmina fica com
# 1,38 m — na vizinhança da espada antiga (1,2 m) e ainda lendo como montante,
# que é o que a Yoru é.
const ESCALA := 2.0

# Medidas do modelo CRU, em unidades dele. Ficam aqui juntas porque toda a
# montagem depende delas e porque foram medidas uma vez: se o `.glb` for
# trocado, é este bloco que se remede.
const CRU_PEGA_Y := 0.385        # centro do cabo
const CRU_GUARDA_Y := 0.19       # onde a lâmina começa
const CRU_PONTA_Y := -0.50       # a ponta

# Já no espaço da espada montada (pega na origem, lâmina para +Y).
const LAMINA_BASE := (CRU_PEGA_Y - CRU_GUARDA_Y) * ESCALA     # 0,39 m
const LAMINA_PONTA := (CRU_PEGA_Y - CRU_PONTA_Y) * ESCALA     # 1,77 m

var handle: Node3D = null
var lamina: SwordBlade = null
## Onde o fio começa e acaba, como NÓS. O rastro do golpe se pendura neles em
## vez de chutar um ponto a partir do cotovelo — ver
## `ProceduralAnimator.usar_lamina_no_rastro`.
var guarda: Node3D = null
var ponta: Node3D = null
var _modelo: Node3D = null


func _ready() -> void:
	name = "Yoru"
	_montar_modelo()

	# O `handle` é a ORIGEM desta cena. Ele não desloca nada — existe para que
	# "onde a espada é segurada" seja um nó que dá para selecionar, mover e
	# imprimir, em vez de um número dentro de uma expressão.
	handle = Node3D.new()
	handle.name = "handle"
	add_child(handle)

	lamina = SwordBlade.new()
	lamina.base = LAMINA_BASE
	lamina.ponta = LAMINA_PONTA
	add_child(lamina)

	guarda = Node3D.new()
	guarda.name = "guarda"
	add_child(guarda)
	guarda.position = Vector3(0.0, LAMINA_BASE, 0.0)

	ponta = Node3D.new()
	ponta.name = "ponta"
	add_child(ponta)
	ponta.position = Vector3(0.0, LAMINA_PONTA, 0.0)


func _montar_modelo() -> void:
	var cena := load(CAMINHO) as PackedScene
	if cena == null:
		push_warning("YoruSword: não achei %s" % CAMINHO)
		return
	_modelo = cena.instantiate() as Node3D
	if _modelo == null:
		return
	_modelo.name = "modelo"
	add_child(_modelo)

	# ⚠️ AS DUAS LINHAS QUE PÕEM A ESPADA NA MÃO, na ordem que importa.
	# O nó aplica `posicao + rotacao * ponto`. Girando 180° em X, o cabo do
	# modelo (que está em +0,385) vai para -0,385; subir a mesma medida devolve
	# o cabo à origem — que é onde `handle` está, que é onde a mão está.
	_modelo.scale = Vector3.ONE * ESCALA
	_modelo.rotation = Vector3(PI, 0.0, 0.0)
	_modelo.position = Vector3(0.0, CRU_PEGA_Y * ESCALA, 0.0)


## Liga a espada à mão nomeada do rig. Uma função porque o pedido era
## explicitamente "ligue os dois": quem lê o código vê a ligação acontecer, em
## vez de deduzi-la de um `add_child` solto no meio de outra coisa.
static func ligar_na_mao(mao: Node3D) -> YoruSword:
	if mao == null or not is_instance_valid(mao):
		return null
	var espada := YoruSword.new()
	mao.add_child(espada)
	espada.position = Vector3.ZERO      # handle sobre Hand_R, sem folga
	espada.rotation = Vector3.ZERO
	return espada
