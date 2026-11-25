class_name VelocidadeMinePiece
extends Node
# ============================================================================
#  VELOCIDADE E PULO DO MINE PIECE — `PlayerPhysicalAbilityProcedure` (l. 74–137), lido da fonte em 27/10/2026 (A6b da
#  auditoria). Roda a cada 2 tiques (0,1 s) e só para quem tem estilo de luta e nível ≥ 2 (n = nível − 1 > 0):
#
#    CORRENDO   Velocidade (efeito) com teto round(min(n × 0,5; 15)). A cada vez que o efeito (8 tiques) chega a 4 ou menos,
#               reaplica com amplificador min(atual + 1, teto): o corpo ACELERA um nível por ~0,2 s até o teto. Cada nível
#               vale +20 % (amplificador + 1 níveis).
#    AGACHADO   Pulo (efeito) com teto round(min(n / 4; 6)): enquanto agacha o amplificador sobe de 1 em 1 (carrega o pulo).
#    NO AR      o Pulo usa min(teto, round(min(Velocidade atual / 4; n / 4))): quem vem correndo rápido salta mais alto.
#
#  Os efeitos duram 8 tiques e somem sozinhos (parou de correr/agachar: o ganho cai em ~0,4 s). Pulo do Minecraft: velocidade
#  inicial 0,42 bloco/tick + 0,1 por nível. O Player multiplica `velocidade_mod` e `pulo_mod` (só na história).
#  NÃO portado: o dobro da Velocidade na forma Zoan e os estilos 7/18/Bomu (geppo): são da onda E4.
# ============================================================================

const TICK := 0.05
const DURACAO := 8
const PULO_BASE := 0.42               # blocos/tick do pulo do Minecraft
const POR_NIVEL_DE_PULO := 0.1

var jogador: Node3D
var _acumulado := 0.0
var _tick := 0
var _vel_amp := -1
var _vel_ticks := 0
var _pulo_amp := -1
var _pulo_ticks := 0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(jogador):
		return
	_acumulado += delta
	while _acumulado >= TICK:
		_acumulado -= TICK
		_tick += 1
		_vel_ticks = maxi(_vel_ticks - 1, 0)
		_pulo_ticks = maxi(_pulo_ticks - 1, 0)
		if _tick % 2 == 0:
			_regra()
	jogador.set("velocidade_mod", fator_de_velocidade())
	jogador.set("pulo_mod", fator_de_pulo())


## Quanto a Velocidade (efeito) multiplica o andar: +20 % por nível.
func fator_de_velocidade() -> float:
	return 1.0 + 0.2 * (_vel_amp + 1) if _vel_ticks > 0 else 1.0


## Quanto o Pulo (efeito) multiplica o pulo: (0,42 + 0,1 por nível) / 0,42.
func fator_de_pulo() -> float:
	return (PULO_BASE + POR_NIVEL_DE_PULO * (_pulo_amp + 1)) / PULO_BASE if _pulo_ticks > 0 else 1.0


func _regra() -> void:
	var n := maxi(int(jogador.get_meta("nivel_historia", 1)) - 1, 0)
	if n <= 0:
		_vel_ticks = 0
		_pulo_ticks = 0
		return
	var correndo: bool = jogador.call("_is_sprinting")
	var agachado: bool = jogador.get("_agachar").ativo if jogador.get("_agachar") != null else false
	var no_ar: bool = not bool(jogador.call("is_on_floor"))
	var vel_set := 0
	if correndo:
		var teto := roundi(minf(n * 0.5, 15.0))
		vel_set = _vel_amp + 1 if _vel_ticks > 0 else 0
		if _vel_ticks <= 4:
			_aplicar_velocidade(mini(vel_set, teto))
	if agachado or no_ar:
		var teto_pulo := roundi(minf(n / 4.0, 6.0))
		var pulo_set := 0
		if agachado:
			pulo_set = _pulo_amp + 1 if _pulo_ticks > 0 else 0
		else:
			pulo_set = roundi(minf(vel_set / 4.0, n / 4.0))
		if _pulo_ticks < 4:
			_aplicar_pulo(mini(teto_pulo, pulo_set))


## `addEffect` do Minecraft: amplificador maior troca; igual renova a duração; menor é ignorado.
func _aplicar_velocidade(amp: int) -> void:
	if _vel_ticks <= 0 or amp > _vel_amp:
		_vel_amp = amp
		_vel_ticks = DURACAO
	elif amp == _vel_amp:
		_vel_ticks = maxi(_vel_ticks, DURACAO)


func _aplicar_pulo(amp: int) -> void:
	if _pulo_ticks <= 0 or amp > _pulo_amp:
		_pulo_amp = amp
		_pulo_ticks = 8
	elif amp == _pulo_amp:
		_pulo_ticks = maxi(_pulo_ticks, 8)
