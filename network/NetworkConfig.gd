class_name NetworkConfig
extends RefCounted
## Constantes da camada de rede. Único lugar a mudar para servidor dedicado
## (basta apontar IP/porta) — o resto da arquitetura não muda.

const PORTA_PADRAO := 24565

## Porta do jogo. É 24565 em partida — a variável de ambiente SOP_PORTA existe
## SÓ para teste em paralelo: cada worktree/agente exporta uma porta e para de
## disputar o mesmo soquete. Antes disso toda bateria era obrigatoriamente em
## série ("Couldn't create an ENet host" quando dois subiam juntos), o que fazia
## dois agentes trabalhando ao mesmo tempo se atropelarem.
##
## Em partida normal ninguém define SOP_PORTA, então nada muda. É `static var` e
## não `const` porque ler ambiente é coisa de execução, não de compilação.
## Gatilho para revisitar: se algum dia a porta precisar mudar EM PARTIDA (ex.:
## servidor dedicado com várias salas na mesma máquina), isto vira parâmetro de
## verdade e sai do ambiente.
static var DEFAULT_PORT: int = _porta_do_ambiente(PORTA_PADRAO)

## O farol de LAN fica na porta seguinte à do jogo — assim UMA variável move as
## duas, e elas nunca saem de sincronia.
static var PORTA_FAROL: int = DEFAULT_PORT + 1

static func _porta_do_ambiente(padrao: int) -> int:
	var bruto := OS.get_environment("SOP_PORTA")
	if not bruto.is_valid_int():
		return padrao
	var p := int(bruto)
	# Abaixo de 1024 exige root; acima de 65535 não existe. Fora disso, ignora
	# em silêncio e usa o padrão: teste com porta inválida deve rodar, não morrer.
	if p < 1024 or p > 65535:
		push_warning("[rede] SOP_PORTA=%d fora da faixa 1024-65535, usando %d" % [p, padrao])
		return padrao
	return p
const MAX_PLAYERS := 50          # preparado p/ escalar (começa com 2)
const LOCAL_IP := "127.0.0.1"
const SERVER_ID := 1             # no modelo Godot, o host é o peer id 1
