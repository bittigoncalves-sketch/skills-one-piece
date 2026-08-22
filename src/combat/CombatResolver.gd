class_name CombatResolver
extends RefCounted
# ============================================================================
#  O FUNIL. Todo dano do jogo passa por aqui — com hitbox ou sem.
#
#  ------------------------------------------------- O PROBLEMA QUE ISTO FECHA
#  O projeto já tinha um funil: a `DamageZone`. E tinha um fator de escala
#  (`DAMAGE_SCALE = 0.12`) dentro dela. A consequência é que qualquer efeito que
#  chamasse `take_damage()` direto entregava o número CRU — 8,3x mais forte que
#  um golpe equivalente que usasse hitbox. Seis lugares faziam isso, e dois deles
#  eram as duas skills mais fortes do jogo por uma ordem de grandeza:
#
#      Yami V (Liberation) . 25 escombros x 72 cru = 1800 contra 2048 de vida
#      Bara V (Domínio) .... 90 cortes  x  9 cru =  810, num raio de 40 m
#
#  Dois outros (SandTornado, IceFX) tinham sido remendados à mão com
#  `* DamageZone.DAMAGE_SCALE` — o remendo funcionava e provava que a constante
#  estava no lugar errado.
#
#  Agora não há escala nenhuma: os números do `Balance` são finais, e o único
#  jeito de machucar alguém é passar por `aplicar()`.
#
#  ------------------------------------------------------------- O ORÇAMENTO
#  O anti-duplo-hit do projeto sempre foi por HITBOX (`DamageZone._hit`), não
#  por GOLPE. Isso está certo para o que ele resolve, e é insuficiente para
#  multi-hit: um Gatling cria 16 hitboxes, um El Thor 12, um Liberation 26 —
#  cada uma acerta o mesmo alvo uma vez, legitimamente, e o total não tinha
#  teto nenhum.
#
#  Aqui todas as hitboxes de uma conjuração compartilham um `cast_id`, e o
#  acumulado por (conjuração, alvo) é cortado no teto do slot. É a resposta ao
#  pedido "multi-hit deve possuir limite de dano total".
#
#  ⚠️ O TETO CORTA O DANO, NÃO O ACERTO. Quando o orçamento acaba, `aplicar()`
#  ainda chama `take_damage` com 0 — de propósito. Empurrão, hitstun e crédito
#  de kill são mecânicas SEPARADAS do dano, e neste jogo quem mata é o buraco do
#  mapa: um golpe que parasse de empurrar ao esgotar o orçamento perderia a sua
#  função principal. `Player.gd` já trata dano 0 assim no combo breaker.
#
#  ------------------------------------------------------------------ ESTADO
#  Estático, não autoload. O estado é um dicionário pequeno e de vida curta, e
#  um autoload novo entraria na ordem de inicialização do `project.godot` junto
#  com o `GameFlow` e os dois `ScreenFX` — risco desnecessário para guardar
#  meia dúzia de contadores.
# ============================================================================

# cast_id -> {"t": ticks_msec da criação, "alvos": { instance_id: acumulado }}
static var _gasto: Dictionary = {}
static var _proximo_id: int = 1

## Quanto tempo um orçamento sobrevive sem ser encerrado. Generoso de propósito:
## o campo do Ice Age dura 50 s e continua sendo A MESMA conjuração o tempo todo.
## Só existe porque nem todo efeito tem um ponto claro de "acabou" para chamar
## `encerrar()` — golpes que morrem por `autofree` ou com a cena, por exemplo.
const VALIDADE_MS := 90_000

## A partir de quantos orçamentos vivos vale a pena varrer os vencidos. A conta é
## barata e roda no servidor, mas não precisa correr a cada bala de minigun.
const LIMITE_ANTES_DE_VARRER := 64

# ---------------------------------------------------------------- identidade
## Abre uma conjuração. Chamado uma vez por aperto de tecla, via
## `DamageSpec.para_cast()`.
static func novo_cast() -> int:
	_proximo_id += 1
	if _gasto.size() > LIMITE_ANTES_DE_VARRER:
		_limpar_vencidos()
	return _proximo_id

# ------------------------------------------------------------------ aplicar
## Aplica dano a um alvo, respeitando o orçamento da conjuração.
## Devolve quanto foi REALMENTE tirado — 0,0 quando o teto já tinha sido atingido.
##
## `cast_id == 0` ou `teto <= 0` significam "sem orçamento": o golpe é avulso
## (uma bala da pistola da Yami, uma auditoria de `tools/dev_tests/`) e entrega
## o valor cheio. Não é um caso degenerado, é o caso do golpe de um acerto só.
static func aplicar(alvo: Node, dano: float, cast_id: int, teto: float,
		origem: Vector3, knockback: Vector3 = Vector3.ZERO, hitstun: float = 0.3) -> float:
	if alvo == null or not is_instance_valid(alvo):
		return 0.0
	if not alvo.has_method("take_damage"):
		return 0.0

	var final := maxf(dano, 0.0)
	if cast_id != 0 and teto > 0.0:
		final = _cobrar(cast_id, alvo, final, teto)

	# Sempre chama, mesmo com 0: ver a nota sobre teto x acerto no cabeçalho.
	alvo.take_damage(final, origem, knockback, hitstun)
	return final

## O orçamento propriamente dito. Separado de `aplicar` para ser testável sem
## um alvo vivo — ver `tools/dev_tests/test_balance.gd`.
static func _cobrar(cast_id: int, alvo: Node, pedido: float, teto: float) -> float:
	var conta: Dictionary = _gasto.get(cast_id, {})
	if conta.is_empty():
		conta = {"t": Time.get_ticks_msec(), "alvos": {}}
		_gasto[cast_id] = conta
	var alvos: Dictionary = conta["alvos"]
	var chave := alvo.get_instance_id()
	var ja: float = float(alvos.get(chave, 0.0))
	var permitido := clampf(teto - ja, 0.0, pedido)
	alvos[chave] = ja + permitido
	return permitido

## Fecha uma conjuração e devolve a memória. Opcional: o varredor de vencidos
## pega quem não chamar. Vale a pena chamar em golpes de vida longa que sabem
## a hora em que acabam (o V da Gura sabe; um projétil que some sozinho, não).
static func encerrar(cast_id: int) -> void:
	_gasto.erase(cast_id)

## Quanto uma conjuração já tirou de um alvo. Só leitura — existe para teste e
## para depuração em jogo.
static func gasto_em(cast_id: int, alvo: Node) -> float:
	if not _gasto.has(cast_id) or alvo == null or not is_instance_valid(alvo):
		return 0.0
	return float((_gasto[cast_id]["alvos"] as Dictionary).get(alvo.get_instance_id(), 0.0))

static func _limpar_vencidos() -> void:
	var agora := Time.get_ticks_msec()
	for id in _gasto.keys():
		if agora - int(_gasto[id]["t"]) > VALIDADE_MS:
			_gasto.erase(id)

## Zera tudo. O respawn e a troca de cena chamam: um orçamento que sobrevive à
## morte faria o golpe seguinte nascer com o teto já gasto. É o mesmo tipo de
## vazamento de estado de combate que travou o jogo no item 23 da lista de
## correções (`is_casting` pendurado depois da morte).
static func limpar_tudo() -> void:
	_gasto.clear()
