class_name RegrasDaLutaDoBuggy
extends RefCounted
# ============================================================================
#  REGRAS DA LUTA DO BUGGY NO RINGUE (22/11/2026) — só decisões e contas, sem cena (testável). Pedido do dono: ringue de luta livre; a MESMA mecânica do treino
#  (`RegrasDoTreino`: uma tecla por vez) com METADE do tempo (1,2 s, igual ao treino; era 0,6 s até a 2ª rodada de 22/11) e a tecla F para DEFENDER; cada lutador tem 11 de vida; 11 acertos do jogador = vitória,
#  vida do jogador a zero = o Buggy vence. Recompensa: 350 moedas + 6500 XP (uma vez) e a missão do barril (Alvida) fica liberada.
#
#  Interpretação (do Claude, a confirmar com o dono): o treino sorteia teclas de ATAQUE (Z/X/C: acertou = soco, errou = nada); aqui a cada rodada sai ou um ataque do
#  jogador (Z/X/C) ou um ATAQUE DO BUGGY (F): defendeu = bloqueia, errou/estourou o tempo = o jogador perde 1 de vida. Errar um ataque NÃO tira vida (só perde a rodada).
#  O estado de UMA luta vive nesta instância; o que fica no save é a fase (`RegrasDoDesafioBuggy.LUTA_VENCIDA`).
#  GATILHO: a luta de outros chefes pede as mesmas contas → `VIDA`, `TEMPO_DO_PROMPT` e `CHANCE_DE_DEFESA` viram campos de uma ficha de luta.
# ============================================================================
const VIDA := 11
const TEMPO_DO_PROMPT := 1.2               # igual ao treino (`RegrasDoTreino.TEMPO_DO_PROMPT`); o dono decidiu em 22/11 (2ª rodada): era 0,6 s ("metade")
const TECLAS_DE_ATAQUE: Array[String] = ["Z", "X", "C"]
const TECLA_DE_DEFESA := "F"
const CHANCE_DE_DEFESA := 0.4              # fatia das rodadas em que o Buggy ataca
const MAX_SEGUIDAS := 3                    # no máximo 3 rodadas do mesmo tipo em fila (sem sequência injusta)
const XP := 6500
const OURO := 350

## Os três golpes (como no treino): Z rápido (um jab), X carregado (pausa para armar, impacto forte), C múltiplo (três socos). Valem para o jogador E para o Buggy.
## TODOS tiram 1 de vida por rodada acertada (decisão do dono, 22/11): o que muda é a animação e o peso do contato. `duracao` = do início do golpe ao fim da rodada.
const GOLPES := {
	"Z": {"nome": "rápido", "golpes": 1, "carga": 0.0, "forca": 0.5, "duracao": 0.4},
	"X": {"nome": "carregado", "golpes": 1, "carga": 0.35, "forca": 1.0, "duracao": 0.9},
	"C": {"nome": "múltiplo", "golpes": 3, "carga": 0.0, "forca": 0.3, "duracao": 0.7},
}
const INSTANTE_DO_CONTATO := 0.14          # s depois de armado
const INTERVALO_ENTRE_GOLPES := 0.14

enum Tipo { ATAQUE, DEFESA }

var vida_jogador := VIDA
var vida_buggy := VIDA
var rodadas := 0
var acertos := 0                           # ataques do jogador que acertaram
var defesas := 0                           # ataques do Buggy bloqueados
var erros := 0
var _ultimo_tipo := -1
var _seguidas := 0
var _ultima_tecla := ""


## A próxima rodada: {"tipo": Tipo, "tecla": String}. `sorteio` ∈ [0,1) decide o tipo, `sorteio_tecla` ∈ [0,1) a tecla (injetáveis: teste determinístico).
func proxima(sorteio: float, sorteio_tecla: float) -> Dictionary:
	var tipo := Tipo.DEFESA if sorteio < CHANCE_DE_DEFESA else Tipo.ATAQUE
	if tipo == _ultimo_tipo and _seguidas >= MAX_SEGUIDAS:
		tipo = Tipo.ATAQUE if tipo == Tipo.DEFESA else Tipo.DEFESA
	_seguidas = _seguidas + 1 if tipo == _ultimo_tipo else 1
	_ultimo_tipo = tipo
	var tecla := TECLA_DE_DEFESA
	if tipo == Tipo.ATAQUE:
		var i := mini(int(sorteio_tecla * TECLAS_DE_ATAQUE.size()), TECLAS_DE_ATAQUE.size() - 1)
		if TECLAS_DE_ATAQUE[i] == _ultima_tecla and sorteio_tecla < 0.6:     # como o treino: evita repetir demais a mesma tecla
			i = (i + 1) % TECLAS_DE_ATAQUE.size()
		tecla = TECLAS_DE_ATAQUE[i]
	_ultima_tecla = tecla
	rodadas += 1
	return {"tipo": tipo, "tecla": tecla}


## Fecha a rodada. `acertou` = apertou a tecla certa dentro do tempo. Devolve o efeito: {"dano_buggy": int, "dano_jogador": int, "bloqueou": bool}.
func resolver(tipo: int, acertou: bool) -> Dictionary:
	var efeito := {"dano_buggy": 0, "dano_jogador": 0, "bloqueou": false}
	if terminou():
		return efeito
	if tipo == Tipo.ATAQUE:
		if acertou:
			acertos += 1
			vida_buggy = maxi(vida_buggy - 1, 0)
			efeito["dano_buggy"] = 1
		else:
			erros += 1
	else:
		if acertou:
			defesas += 1
			efeito["bloqueou"] = true
		else:
			erros += 1
			vida_jogador = maxi(vida_jogador - 1, 0)
			efeito["dano_jogador"] = 1
	return efeito


func terminou() -> bool:
	return vida_buggy <= 0 or vida_jogador <= 0


func jogador_venceu() -> bool:
	return vida_buggy <= 0 and vida_jogador > 0


## Paga a vitória (uma vez): a missão `defender_a_vila` se cumpre e se entrega (6500 XP + 350 moedas, da tabela de missões) e a fase vira `luta_vencida`, que
## libera o barril da Alvida. Derrota não muda nada (dá para tentar de novo). Devolve {} se não era a hora (já venceu ou nunca aceitou) — impede pagar duas vezes.
static func concluir(prog: ProgressaoDoPersonagem, venceu: bool) -> Dictionary:
	if not venceu or not RegrasDoDesafioBuggy.luta_disponivel(prog):
		return {}
	var nivel_antes := prog.nivel
	var ouro_antes := prog.ouro
	var xp_antes := prog.xp
	prog.contar_abate("buggy")
	var entregue := prog.entregar_missao(RegrasDoDesafioBuggy.MISSAO_LUTA)
	RegrasDoDesafioBuggy.marcar_luta_vencida(prog)
	return {"venceu": true, "missao_entregue": entregue, "ouro": prog.ouro - ouro_antes, "xp_pedido": XP,
		"xp_ganho": prog.xp - xp_antes, "niveis": prog.nivel - nivel_antes}
