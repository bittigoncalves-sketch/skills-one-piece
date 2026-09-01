class_name RunAccelerationController
extends RefCounted

## Corrida sustentada: começa na corrida normal e dobra esse valor após 3 s.
const TEMPO_PARA_MAXIMO := 3.0
const MULTIPLICADOR_MAXIMO := 2.0
var _tempo_correndo := 0.0

func atualizar(delta: float, correndo_no_chao: bool) -> float:
	if not correndo_no_chao:
		_tempo_correndo = 0.0
		return 1.0
	_tempo_correndo = minf(_tempo_correndo + delta, TEMPO_PARA_MAXIMO)
	return lerpf(1.0, MULTIPLICADOR_MAXIMO, _tempo_correndo / TEMPO_PARA_MAXIMO)

func resetar() -> void:
	_tempo_correndo = 0.0

func multiplicador() -> float:
	return lerpf(1.0, MULTIPLICADOR_MAXIMO, _tempo_correndo / TEMPO_PARA_MAXIMO)
