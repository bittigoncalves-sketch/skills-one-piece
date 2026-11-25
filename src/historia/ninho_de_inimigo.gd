class_name NinhoDeInimigo
extends Node3D
# ============================================================================
#  NINHO DE INIMIGO — o lugar do mapa onde um inimigo que LUTA nasce e renasce.
#
#  Pedido do dono (30/09/2026): o boneco de duelo vira inimigo que se põe no mapa
#  pela loja do editor (aba "inimigos"); morto, volta em 1 minuto no MESMO lugar em
#  que foi posto. O modelo da loja é só o que o editor desenha: no jogo a peça some e
#  o ninho cria o boneco de verdade (`BonecoDeDuelo` + `CerebroDeInimigo`) no chão da
#  peça, virado para onde a peça estava virada.
#
#  Quem é ninho: peça `modelo` cujo modelo está na categoria "inimigos" E tem o
#  comportamento "boneco_de_duelo" no catálogo (`tools/importar_boneco_na_loja.gd`).
#  Os outros inimigos da categoria continuam `InimigoDoMapa` (alvo parado).
#
#  Sem XP (decisão do dono): quem dá XP por inimigo é o `ModoHistoria`, e ele não liga
#  o `derrotado` daqui ao XP.
#
#  ⚠️ Só no JOGO (`ModoHistoria`). No "Testar" do editor a peça continua modelo parado,
#  como os outros inimigos — o editor não pode perder o nó que representa a peça.
# ============================================================================

signal derrotado(ninho: NinhoDeInimigo)
signal nasceu(boneco: BonecoDeDuelo)

const COMPORTAMENTO := "boneco_de_duelo"
## Bandido (08/10/2026, pedido do dono: "bandidos com base no dummy que é capaz de
## lutar"): o MESMO boneco que luta, vestido de bandido (`RoupaDeBandido`). Diferente
## do boneco, dá XP e conta para a missão do Guarda da vila (`ModoHistoria`).
const BANDIDO := "bandido"
const COMPORTAMENTOS := [COMPORTAMENTO, BANDIDO]
const RoupaDeBandido := preload("res://src/historia/bandidos/roupa_de_bandido.gd")
## O boneco some um instante depois do golpe final (o último número de dano aparece).
const SUMIR_EM := 1.0
## Vida do bandido (17/10/2026, pedido do dono: 30). O boneco de duelo segue com os 250.
const VIDA_DO_BANDIDO := 30.0

var boneco: BonecoDeDuelo = null
var _alvo_de: Callable
var _yaw := 0.0
## O modelo da loja da peça que virou este ninho: é por ele que as skills do Builder
## (Usuário Inimigo, "Quem usa") encontram o boneco.
var modelo_da_loja := ""
## Qual dos `COMPORTAMENTOS` (o do modelo da peça).
var comportamento := COMPORTAMENTO
## A cor da bandana do bandido (sai do id da peça: o mesmo bandido sempre igual).
var variante := 0
var _relogio: Timer


## Troca cada peça com o comportamento por um ninho, na mesma raiz do mapa. Devolve os
## ninhos para quem monta a cena ligar `derrotado`. `alvo_de` devolve o jogador.
static func ligar_no_mapa(raiz: Node3D, mapa: Dictionary, biblioteca: BibliotecaDeModelos,
		alvo_de: Callable) -> Array[NinhoDeInimigo]:
	var ninhos: Array[NinhoDeInimigo] = []
	if raiz == null or biblioteca == null:
		return ninhos
	for p: Dictionary in mapa["pecas"]:
		if not eh_ninho(p, biblioteca):
			continue
		var ninho := NinhoDeInimigo.new()
		ninho.name = "Ninho_" + String(p["id"])
		ninho.position = pe_da_peca(p)
		ninho._yaw = deg_to_rad((p["rotacao_graus"] as Vector3).y)
		ninho._alvo_de = alvo_de
		ninho.modelo_da_loja = String(p["modelo"])
		ninho.comportamento = biblioteca.comportamento_do_modelo(p["modelo"])
		ninho.variante = absi(String(p["id"]).hash())
		raiz.add_child(ninho)
		var peca := raiz.get_node_or_null(NodePath(String(p["id"])))
		if peca != null:
			# Fora da árvore JÁ (e depois liberada): a caixa de colisão do modelo não
			# pode segurar o boneco nascendo em cima dela.
			raiz.remove_child(peca)
			peca.queue_free()
		ninhos.append(ninho)
	return ninhos


static func eh_ninho(p: Dictionary, biblioteca: BibliotecaDeModelos) -> bool:
	return InimigoDoMapa.eh_inimigo(p, biblioteca) \
		and biblioteca.comportamento_do_modelo(p["modelo"]) in COMPORTAMENTOS


## O chão da peça: o centro dela menos meia altura. O editor põe o modelo em pé no
## chão, então a base da caixa é onde os pés ficam.
static func pe_da_peca(p: Dictionary) -> Vector3:
	var tamanho: Vector3 = p["tamanho"]
	return (p["posicao"] as Vector3) - Vector3.UP * tamanho.y * 0.5


func _ready() -> void:
	add_to_group("ninhos_de_inimigo")         # o marcador de missão acha os bandidos
	_relogio = Timer.new()
	_relogio.name = "Renascer"
	_relogio.one_shot = true
	_relogio.timeout.connect(_nascer)
	add_child(_relogio)
	_nascer()


## Segundos até renascer (0 com o inimigo vivo).
func falta_para_renascer() -> float:
	return _relogio.time_left if _relogio != null and not _relogio.is_stopped() else 0.0


func _nascer() -> void:
	boneco = BonecoDeDuelo.new()
	boneco.name = "Bandido" if comportamento == BANDIDO else "Boneco"
	boneco.set_meta("faccao", "bandidos" if comportamento == BANDIDO else "bonecos")   # IA unificada por facção (10/11/2026)
	boneco.set_meta("modelo_recrutavel", modelo_da_loja)
	if comportamento == BANDIDO:
		boneco.vida_maxima = VIDA_DO_BANDIDO   # antes do add_child: o _ready copia para health
	# Posição ANTES de entrar na árvore: nascido na origem, ele pode aparecer dentro de
	# outro corpo e virar plataforma (docs/erros.md, 16/09). Um pouco acima do chão.
	boneco.position = Vector3.UP * (BonecoDeDuelo.COLISOR.y * 0.5 + 0.05)
	add_child(boneco)
	var modelo := boneco.modelo_visual()
	if modelo != null:
		modelo.rotation.y = _yaw
		if comportamento == BANDIDO:
			RoupaDeBandido.vestir(modelo, variante)
	boneco.encarar_yaw(_yaw)
	var cerebro := CerebroDeInimigo.new()
	cerebro.name = "CerebroDeInimigo"
	boneco.add_child(cerebro)
	cerebro.montar(boneco, _alvo_de, global_position, _yaw)
	boneco.derrotado.connect(_ao_derrotar)
	# Skills do Builder atribuídas ao modelo deste ninho (Usuário Inimigo, 06/10/2026).
	UsuarioDeSkills.ligar(boneco, modelo_da_loja)
	nasceu.emit(boneco)


func _ao_derrotar(morto: BonecoDeDuelo) -> void:
	derrotado.emit(self)
	get_tree().create_timer(SUMIR_EM).timeout.connect(morto.queue_free)
	if morto == boneco:
		boneco = null
	_relogio.start(InimigoDoMapa.tempo_de_renascer)
