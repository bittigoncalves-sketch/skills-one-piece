class_name NpcsDaIlha
extends Node
# ============================================================================
#  NPCs DA ILHA — os personagens postos no mapa pela loja (aba "NPCs") ganham
#  vida no Modo História, e a tecla E abre a loja do mais perto (03/10/2026).
#
#  Quem é NPC: peça `modelo` cujo modelo tem um comportamento de
#  `NpcDaIlha.FICHAS` no catálogo (como o boneco de duelo e o caranguejo). No jogo
#  a peça some e o NPC de verdade nasce no chão dela, virado para onde ela estava
#  virada. No "Testar" do editor a peça continua modelo parado (o editor não perde
#  o nó da peça). Hoje: pescador, domador e vendedor de frutas.
# ============================================================================

## E perto de um NPC: a HUD abre a `JanelaDeLoja` dele.
signal pediu_loja(npc: NpcDaIlha)

const ALCANCE := 3.0

var progressao: ProgressaoDoPersonagem
var jogador_de: Callable
var npcs: Array[NpcDaIlha] = []


## Troca cada peça de NPC por um NPC vivo, na mesma raiz do mapa.
func ligar_no_mapa(raiz: Node3D, mapa: Dictionary, biblioteca: BibliotecaDeModelos) -> void:
	if raiz == null or biblioteca == null:
		return
	preload("res://src/historia/npcs/exposicao_cozinheiros.gd").ligar(raiz, mapa, biblioteca)
	for p: Dictionary in mapa["pecas"]:
		if p.get("tipo", "") != "modelo" or not biblioteca.tem(str(p.get("modelo", ""))):
			continue
		var tipo := biblioteca.comportamento_do_modelo(p["modelo"])
		if not NpcDaIlha.FICHAS.has(tipo):
			continue
		var npc := NpcDaIlha.new()
		npc.name = "Npc_" + String(p["id"])
		npc.tipo = tipo
		npc.biblioteca = biblioteca
		# Posição e giro ANTES de entrar na árvore (nascido na origem ele pode virar
		# plataforma de quem estiver lá — docs/erros.md, 16/09).
		npc.position = NinhoDeInimigo.pe_da_peca(p)
		npc.rotation.y = deg_to_rad((p["rotacao_graus"] as Vector3).y)
		var peca := raiz.get_node_or_null(NodePath(String(p["id"])))
		if peca != null:
			raiz.remove_child(peca)
			peca.queue_free()
		raiz.add_child(npc)
		npcs.append(npc)
	load("res://src/historia/missoes/inicio_da_jornada.gd").colocar_npcs(raiz, mapa, biblioteca, self)


## Depois de uma ilha ser descarregada: esquece os NPCs que foram liberados com ela.
func podar() -> void:
	npcs.assign(npcs.filter(func(n: NpcDaIlha) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion()))


## A "?" dos NPCs de missão segue o progresso (08/10/2026).
var _relogio_marcas := 0.0

func _process(delta: float) -> void:
	_relogio_marcas -= delta
	if _relogio_marcas > 0.0 or progressao == null:
		return
	_relogio_marcas = 0.25
	for n in npcs:
		if is_instance_valid(n) and not n.missao().is_empty():
			var da_vez := n.missao(progressao)          # "" = cadeia toda entregue
			n.marcar_missao(progressao.estado_da_missao(da_vez) if not da_vez.is_empty() else "entregue")


func mais_perto() -> NpcDaIlha:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return null
	var melhor: NpcDaIlha = null
	var dist := ALCANCE
	for n in npcs:
		if is_instance_valid(n) and not bool(n.get_meta("morto", false)) and not bool(n.get_meta("escravizado", false)):
			var d := j.global_position.distance_to(n.global_position)
			if d <= dist:
				dist = d
				melhor = n
	return melhor


func dica() -> String:
	var n := mais_perto()
	return "E — falar com o %s" % n.nome() if n != null else ""


## Tecla E. Devolve true se havia alguém para conversar.
func interagir() -> bool:
	var n := mais_perto()
	if n == null:
		return false
	var loja := n.loja()
	if loja != null:
		loja.set("progressao", progressao)      # a conversa de missão fala pelo estado
		n.falar(loja.fala())
	pediu_loja.emit(n)
	return true
