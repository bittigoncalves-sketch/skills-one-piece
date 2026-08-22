class_name DamageSpec
extends RefCounted
# ============================================================================
#  O QUE UM GOLPE É — a descrição que viaja pela pipeline de combate.
#
#  Antes desta classe, o que atravessava o jogo era um `float damage` solto, e
#  ele significava coisas diferentes em skills diferentes: dano de um soco na
#  Gomu Z, dano POR BALA na Buki, orçamento a dividir em 16 no Gatling, dano de
#  CADA UM dos 25 escombros no Liberation da Yami. Quatro contratos, um número,
#  nenhuma forma de saber qual valia sem abrir o arquivo de efeitos.
#
#  Aqui o contrato é explícito no campo `tipo`, e é isso que permite:
#    • validar a tabela inteira num teste (tools/dev_tests/test_balance.gd);
#    • dar UM teto por conjuração a golpes que nascem em várias hitboxes;
#    • ter UMA curva de carregamento no jogo inteiro, em vez de três.
#
#  ------------------------------------------------------------ O `cast_id`
#  É a identidade de UMA conjuração. Todas as hitboxes nascidas do mesmo aperto
#  de tecla carregam o mesmo número, e é por ele que o `CombatResolver` soma o
#  que já foi entregue e corta o excedente.
#
#  ⚠️ Por isso a spec que sai do `Balance` é um MOLDE, não um golpe: ela tem
#  `cast_id == 0`. Quem dispara chama `para_cast()` e recebe uma CÓPIA com id
#  próprio. Reutilizar o molde faria dois jogadores diferentes compartilharem o
#  mesmo orçamento — o segundo a acertar não tiraria vida nenhuma.
# ============================================================================

enum Tipo {
	UNICO,      ## um acerto, um valor. O caso comum.
	MULTI,      ## vários acertos de `dano` cada, somando no máximo `teto`.
	CARREGADO,  ## interpola de `dano` a `dano_max` conforme o tempo de carga.
}

var tipo: Tipo = Tipo.UNICO
var dano: float = 0.0          ## único: o golpe. multi: por hit. carregado: o mínimo.
var dano_max: float = 0.0      ## só CARREGADO — o valor com a carga cheia.
var hits: int = 1              ## só MULTI — quantos acertos o golpe promete.
var teto: float = 0.0          ## máximo que UMA conjuração tira de UM alvo. 0 = sem teto.

## Quanto do `teto` fica GUARDADO para o acerto de clímax.
##
## ⚠️ POR QUE ISTO EXISTE. O orçamento é consumido em ORDEM DE CHEGADA, e há dois
## golpes cujo clímax chega POR ÚLTIMO: o soco final do Gatling e a coluna do El
## Thor. Os acertos pequenos comiam o teto inteiro antes, e o clímax — declarado
## na tabela como valendo mais — entregava ZERO. Medido: com teto 384 e socos de
## 80, o orçamento fechava no 5º soco e o 16º (o que arremessa) não tirava nada.
##
## As outras skills com parte nomeada não precisam de reserva porque resolvem o
## mesmo problema de outro jeito: no Liberation e no Ice Age o clímax chega
## PRIMEIRO, e no Kurouzu a soma fecha exata no teto. A reserva é a saída para
## quem não pode ter nenhuma das duas — uma barragem não tem como acabar antes
## de começar.
##
## Quem cobra sem `reservado` só enxerga `teto - reserva`; o clímax enxerga o
## teto inteiro. Ver `CombatResolver.aplicar`.
var reserva: float = 0.0
var tempo_de_carga: float = 0.0

## Sub-valores nomeados, para golpes que têm partes de peso diferente: a coluna
## final do El Thor, o arremesso do Kurouzu, a supernova do Inferno. Existe para
## que esses números morem AQUI, junto do resto do balanceamento, e não como
## `damage * 1.6` perdido no meio de um arquivo de partículas.
var partes: Dictionary = {}

## Identidade da conjuração. 0 = molde (ver o cabeçalho).
var cast_id: int = 0

# ------------------------------------------------------------------ fábricas
static func criar(t: Tipo, d: float, tt: float) -> DamageSpec:
	var s := DamageSpec.new()
	s.tipo = t
	s.dano = d
	s.teto = tt
	return s

## Spec de emergência para quem chama um efeito sem passar tabela — as auditorias
## de `tools/dev_tests/` fazem isso, e um `null` ali derrubaria o teste em vez de
## medir o golpe. Sem teto de propósito: um valor avulso não é uma conjuração.
static func avulso(d: float) -> DamageSpec:
	return criar(Tipo.UNICO, d, 0.0)

## A cópia com identidade própria. É o que o Player chama a cada aperto de tecla.
func para_cast() -> DamageSpec:
	var s := DamageSpec.new()
	s.tipo = tipo
	s.dano = dano
	s.dano_max = dano_max
	s.hits = hits
	s.teto = teto
	s.reserva = reserva
	s.tempo_de_carga = tempo_de_carga
	s.partes = partes          # só leitura em todo o jogo; não precisa duplicar
	s.cast_id = CombatResolver.novo_cast()
	return s

# -------------------------------------------------------------------- leitura
## Quanto vale UM acerto deste golpe. `carga` só importa em CARREGADO.
##
## A interpolação é linear de propósito: as três skills carregáveis tinham três
## curvas diferentes (`1 + carga/1.5` grampeado em 3, `1 + carga/3.0`, e uma
## máquina de estados própria no Mamaragan), e nenhuma delas expressava a faixa
## "mínimo -> máximo" que o balanceamento pede. Uma reta entre dois números que
## estão na tabela é legível e ajustável; uma curva exótica não.
func valor_do_hit(carga: float = 0.0) -> float:
	if tipo == Tipo.CARREGADO and tempo_de_carga > 0.0:
		return lerpf(dano, dano_max, clampf(carga / tempo_de_carga, 0.0, 1.0))
	return dano

## Sub-valor nomeado. `padrao` é devolvido quando a parte não existe, para um
## efeito nunca ficar sem número por causa de uma chave escrita errado.
func parte(nome: String, padrao: float = 0.0) -> float:
	return float(partes.get(nome, padrao))

## Carimba uma hitbox com esta conjuração. Duas linhas viram uma, e — mais
## importante — quem lê o efeito vê que a zona PERTENCE a um golpe com orçamento.
func marcar(zona: Node, e_climax: bool = false) -> void:
	if zona == null or not is_instance_valid(zona):
		return
	zona.cast_id = cast_id
	zona.teto = teto
	zona.reserva = reserva
	# `e_climax` = esta hitbox é a que a reserva estava guardando.
	zona.reservado = e_climax

func _to_string() -> String:
	var nome: String = ["unico", "multi", "carregado"][int(tipo)]
	if tipo == Tipo.CARREGADO:
		return "DamageSpec(%s %.0f->%.0f teto=%.0f id=%d)" % [nome, dano, dano_max, teto, cast_id]
	if tipo == Tipo.MULTI:
		return "DamageSpec(%s %.0f x%d teto=%.0f id=%d)" % [nome, dano, hits, teto, cast_id]
	return "DamageSpec(%s %.0f teto=%.0f id=%d)" % [nome, dano, teto, cast_id]
