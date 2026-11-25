class_name DueloPpt
extends RefCounted
# ============================================================================
#  DUELO DE PEDRA, PAPEL E TESOURA (22/11/2026, 5ª missão) — só regras, sem nó nem tela (testável). Pedido do dono: cada lutador tem 7 pontos de vida; quem vence a rodada
#  ACERTA um golpe no outro (−1 vida); EMPATE = o jogador DESVIA do golpe da Alvida (ninguém perde vida); quem acertar 7 golpes primeiro vence.
#  A Alvida escolhe ANTES do jogador (`sortear`) e não consulta a jogada dele; `jogar` revela as duas. Depois do fim (uma vida em 0) nada mais anda: `jogar` devolve {}.
#  O sorteio é injetável (`sorteio`: Callable → 0..2) para o teste fixar a sequência.
# ============================================================================
const VIDAS := 7
const PEDRA := 0
const PAPEL := 1
const TESOURA := 2
const NOMES := ["Pedra", "Papel", "Tesoura"]
## O que o jogador vê em cada rodada (o orquestrador casa com a animação).
const EMPATE := "desvio"                 # empate: a Alvida ataca e o jogador desvia
const ACERTO_DO_JOGADOR := "acerto_do_jogador"
const ACERTO_DA_ALVIDA := "acerto_da_alvida"

var vidas_do_jogador := VIDAS
var vidas_da_alvida := VIDAS
var rodadas := 0
var sorteio: Callable = Callable()        # () -> int 0..2; vazio = aleatório
var _alvida_escolheu := -1
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## 1 se `a` vence `b`, −1 se perde, 0 se empata. Pedra > tesoura > papel > pedra.
static func comparar(a: int, b: int) -> int:
	if a == b:
		return 0
	return 1 if (a - b + 3) % 3 == 1 else -1          # PEDRA(0) vence TESOURA(2); PAPEL(1) vence PEDRA(0); TESOURA(2) vence PAPEL(1)


func terminou() -> bool:
	return vidas_do_jogador <= 0 or vidas_da_alvida <= 0


## "jogador" | "alvida" | "" (ainda em jogo).
func vencedor() -> String:
	if vidas_da_alvida <= 0:
		return "jogador"
	if vidas_do_jogador <= 0:
		return "alvida"
	return ""


## A Alvida fecha a escolha da rodada (idempotente: chamar de novo não troca a jogada). Devolve a escolha SEM que o jogador a veja — o orquestrador só a mostra depois de `jogar`.
func sortear() -> int:
	if _alvida_escolheu < 0:
		_alvida_escolheu = int(sorteio.call()) if sorteio.is_valid() else _rng.randi_range(PEDRA, TESOURA)
		_alvida_escolheu = clampi(_alvida_escolheu, PEDRA, TESOURA)
	return _alvida_escolheu


## Resolve a rodada com a jogada do jogador. {} se o duelo acabou ou a jogada é inválida.
## → {jogador, alvida, evento, vidas_do_jogador, vidas_da_alvida, terminou, vencedor}
func jogar(jogada: int) -> Dictionary:
	if terminou() or jogada < PEDRA or jogada > TESOURA:
		return {}
	var dela := sortear()
	_alvida_escolheu = -1                           # a próxima rodada sorteia de novo
	var c := comparar(jogada, dela)
	var evento := EMPATE
	if c > 0:
		vidas_da_alvida -= 1
		evento = ACERTO_DO_JOGADOR
	elif c < 0:
		vidas_do_jogador -= 1
		evento = ACERTO_DA_ALVIDA
	rodadas += 1
	return {"jogador": jogada, "alvida": dela, "evento": evento, "vidas_do_jogador": vidas_do_jogador,
		"vidas_da_alvida": vidas_da_alvida, "terminou": terminou(), "vencedor": vencedor()}
