extends Node
# ============================================================================
#  RECRUTAMENTO POR CAPTURA (30/10/2026, pedido do dono).
#
#  Antes: inimigo derrotado esperava no chão ("Derrotado · aproxime-se"), e F recrutava (com a
#  bandeira) ou finalizava. Agora quem recruta é a POKÉBOLA (item da barra, tecla 4 no kit
#  inicial): arremessada num inimigo VIVO com vida vermelha (`Estilo.LIMITE_VERMELHO`, 25 %),
#  ele é capturado e entra na tripulação (humanos como recrutas, animais como pets). Inimigo que
#  chega a 0 de vida morre normalmente: não há mais escolha nem F. O F fica livre.
#
#  Só decide e executa a captura; quem arremessa a bola e mostra o cubo na mão é a
#  `CapturaDeInimigos`. Servidor/solo apenas (a tripulação mora no progresso local).
#  Chefes e membros da tripulação não são capturáveis.
# ============================================================================
const P := preload("res://src/historia/tripulantes/provisoes.gd")
const GRUPO := "recrutamento_historia"
enum Resultado { CAPTURADO, VIDA_ALTA, NAO_CAPTURAVEL, TRIPULACAO_CHEIA, SEM_PERMISSAO, ESCAPOU }

var progressao: ProgressaoDoPersonagem
var jogador_de: Callable
var biblioteca: BibliotecaDeModelos
var hud: Node


func _ready() -> void:
	add_to_group(GRUPO)


static func fracao_de_vida(alvo: Node) -> float:
	var maxima := float(alvo.get("max_health")) if alvo.get("max_health") != null else 0.0
	if maxima <= 0.0 or alvo.get("health") == null:
		return 1.0
	return clampf(float(alvo.get("health")) / maxima, 0.0, 1.0)


func _modelo_de(alvo: Node) -> String:
	var modelo := str(alvo.get_meta("modelo_recrutavel", ""))
	if alvo.get("especie") != null:
		modelo = str(alvo.get("especie"))
	return modelo


## Pode ser capturado AGORA? Não muda nada.
func avaliar(alvo: Node3D) -> Resultado:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return Resultado.SEM_PERMISSAO
	if alvo == null or not is_instance_valid(alvo) or not alvo.is_inside_tree() or alvo.is_in_group("player") \
			or alvo.has_meta("membro_tripulacao") or alvo.is_queued_for_deletion():
		return Resultado.NAO_CAPTURAVEL
	if alvo.get("health") == null or float(alvo.get("health")) <= 0.0:
		return Resultado.NAO_CAPTURAVEL
	if alvo.has_method("boss") and bool(alvo.call("boss")):
		return Resultado.NAO_CAPTURAVEL
	var ficha: Variant = alvo.get("ficha")
	if ficha is Dictionary and bool(ficha.get("chefe", false)):
		return Resultado.NAO_CAPTURAVEL
	var modelo := _modelo_de(alvo)
	if modelo.is_empty() or biblioteca == null or not biblioteca.tem(modelo):
		return Resultado.NAO_CAPTURAVEL
	if P.estado(progressao).membros.size() >= P.MAX_MEMBROS:
		return Resultado.TRIPULACAO_CHEIA
	return Resultado.CAPTURADO


## A pokébola acertou `alvo`: captura se puder. O corpo sai pelo caminho NORMAL de morte (XP, drops, respawn do
## ninho), sem animação de derrota (some na hora).
func capturar(alvo: Node3D, com_aviso := true) -> Resultado:
	var r := avaliar(alvo)
	if r != Resultado.CAPTURADO:
		return r
	var nome := str(biblioteca.info(_modelo_de(alvo)).get("nome", _modelo_de(alvo)))
	if alvo.has_method("nome_de_exibicao"):
		nome = str(alvo.call("nome_de_exibicao"))
	var dados := {"modelo": _modelo_de(alvo), "nome": nome}
	if not _recrutar(alvo, dados):
		return Resultado.TRIPULACAO_CHEIA
	alvo.set_meta("capturado", true)
	alvo.set_meta("dano_do_jogador", true)
	var jogador: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	alvo.visible = false
	alvo.take_damage(maxf(float(alvo.get("max_health")), 1.0) * 100.0,
		jogador.global_position if jogador != null else alvo.global_position, Vector3.ZERO, 0.0)
	if com_aviso:          # a animação de captura (3 estrelas) substitui o texto
		_avisar("%s capturado · entrou na tripulação (M › Pets)" % nome)
	return Resultado.CAPTURADO


## O ARREMESSO (08/11/2026): sorteia pela conta dos jogos Pokémon (`ProbabilidadeDeCaptura`: raridade × vida). Só captura se sortear.
## Devolve {resultado, chance, chacoalhadas, raridade, a}. Quem não pode ser capturado (chefe, tripulação cheia...) não sorteia.
## Só SORTEIA (sem capturar nem avisar): a animação decide quando aplicar. Devolve o mesmo dicionário de `tentar`, com `capturou`.
func sortear_arremesso(alvo: Node3D, bola := 1.0) -> Dictionary:
	var pode := avaliar(alvo)
	if pode != Resultado.CAPTURADO:
		return {"resultado": pode, "capturou": false, "chance": 0.0, "chacoalhadas": 0, "raridade": "", "a": 0.0}
	var faixa := ProbabilidadeDeCaptura.faixa_de(alvo)
	var a := ProbabilidadeDeCaptura.valor_a(fracao_de_vida(alvo), float(faixa["taxa"]), bola)
	var sorteio := ProbabilidadeDeCaptura.sortear(a)
	return {"resultado": Resultado.CAPTURADO if bool(sorteio["capturou"]) else Resultado.ESCAPOU, "capturou": bool(sorteio["capturou"]),
		"chance": sorteio["chance"], "chacoalhadas": int(sorteio["chacoalhadas"]), "raridade": faixa["nome"], "a": a}


func tentar(alvo: Node3D, bola := 1.0) -> Dictionary:
	var pode := avaliar(alvo)
	if pode != Resultado.CAPTURADO:
		return {"resultado": pode, "chance": 0.0, "chacoalhadas": 0, "raridade": "", "a": 0.0}
	var faixa := ProbabilidadeDeCaptura.faixa_de(alvo)
	var a := ProbabilidadeDeCaptura.valor_a(fracao_de_vida(alvo), float(faixa["taxa"]), bola)
	var sorteio := ProbabilidadeDeCaptura.sortear(a)
	var resultado := Resultado.ESCAPOU
	if bool(sorteio["capturou"]):
		resultado = capturar(alvo)
	return {"resultado": resultado, "chance": sorteio["chance"], "chacoalhadas": sorteio["chacoalhadas"], "raridade": faixa["nome"], "a": a}


func mensagem(r: Resultado, alvo: Node) -> String:
	match r:
		Resultado.VIDA_ALTA:
			return "Vida ainda em %d%% · enfraqueça até ficar vermelha (abaixo de %d%%)" % [
				roundi(fracao_de_vida(alvo) * 100.0), roundi(Estilo.LIMITE_VERMELHO * 100.0)]
		Resultado.NAO_CAPTURAVEL:
			return "Este alvo não pode ser capturado"
		Resultado.TRIPULACAO_CHEIA:
			return "Tripulação cheia (%d) · libere uma vaga em M › Pets" % P.MAX_MEMBROS
	return ""


func _recrutar(alvo: Node3D, d: Dictionary) -> bool:
	var estado := P.estado(progressao)
	if estado.membros.size() >= P.MAX_MEMBROS:
		return false
	var id := ""
	# Animais entram pelo sistema de pets existente: modos, espécie e navegação próprios.
	if alvo.get_script().resource_path == "res://src/historia/animais/animal_da_ilha.gd":
		id = progressao.adicionar_pet(str(d.modelo), str(d.nome))
	else:
		var dados := progressao.dados_de("recrutas")
		var n := int(dados.get("sequencia", 0)) + 1
		var chave := "recruta_%d" % n
		while dados.has(chave):
			n += 1
			chave = "recruta_%d" % n
		dados.sequencia = n
		dados[chave] = {"modelo": d.modelo, "nome": d.nome, "vida": maxf(1, float(alvo.get("max_health")))}
		progressao.sistemas["recrutas"] = dados
		id = Tripulacao.id_do_humano(chave)
	if not P.adicionar(progressao, id):
		return false
	var vaga: int = estado.vagas.find("")
	if vaga >= 0:
		P.atribuir(progressao, id, vaga)
	return true


func _avisar(texto: String) -> void:
	if is_instance_valid(hud):
		hud.call("avisar", texto)
