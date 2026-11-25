class_name ApresentacaoDeCombate
extends Node
# ============================================================================
#  APRESENTAÇÃO DO COMBATE DIRECIONAL — som e câmera, a partir dos sinais.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D9). Separada da regra de propósito: o
#  executor decide o que aconteceu; aqui só se mostra. Trocar um som nunca mexe em
#  quando o golpe acerta.
#
#  O impacto de um golpe é a SOMA de camadas pequenas, cada uma de outro dono:
#    • hitstop por ator ................ executor (`pausar`)
#    • reação pelo lado ................ executor (`REACAO`, pose da ficha)
#    • flash, número, empurrão ......... o `take_damage` de quem apanha
#    • som, tremor de câmera e o impacto visual (`ImpactoDeCombate`) ... AQUI
#  E o estado nos BRAÇOS (30/09/2026, pedido do dono): azul defendendo, vermelho
#  atacando — `CorDosBracos`, filho desta, para jogador e boneco igual.
#  Sem soco de FOV: o dono desligou por distorção (`camera_rig.gd`).
#
#  Intensidades são as mínimas legíveis. Rastro do golpe e som por estilo ficam para
#  quando houver o estilo de espada (é onde eles mudam a leitura).
# ============================================================================

const TREMOR_ACERTO := 0.18
const TREMOR_PESADO := 0.32
const TREMOR_APANHOU := 0.22
const TREMOR_BLOQUEIO := 0.08
const TREMOR_QUEBRA := 0.30
const TREMOR_APARO := 0.20
const TREMOR_REBATIDO := 0.15

var _executor: ExecutorCorpoACorpo


func montar(executor: ExecutorCorpoACorpo) -> void:
	_executor = executor
	executor.fase_mudou.connect(_ao_mudar_fase)
	executor.contato.connect(_ao_contato)
	executor.reagiu.connect(_ao_reagir)
	executor.bloqueou.connect(_ao_bloquear)
	executor.guarda_quebrada.connect(_ao_quebrar)
	executor.aparou.connect(_ao_aparar)
	executor.rebatido.connect(_ao_ser_rebatido)
	var cor := CorDosBracos.new()
	cor.name = "CorDosBracos"
	add_child(cor)
	cor.montar(executor)


func _mundo() -> Node:
	return get_tree().current_scene if is_inside_tree() else null


func _ao_mudar_fase(_id: int, fase: GolpeDirecional.Fase) -> void:
	if fase != GolpeDirecional.Fase.ATIVO or _executor.golpe_atual == null or _mundo() == null:
		return
	var golpe := _executor.golpe_atual
	var onde := _executor.ator.posicao_do_no(golpe.efetor)
	if onde != Vector3.INF:
		if not _executor.sons_da_arma.is_empty() and SonsEpicFight.tocar(_mundo(), onde, _executor.sons_da_arma.get("golpe", [])):
			return                                       # o som do golpe é o da arma do mod
		AudioFX.whoosh(_mundo(), onde, 0.85 if golpe.pesado else 1.1)


## Lado de QUEM BATEU. O som do bloqueio e da quebra sai no lado de quem defende
## (`_ao_bloquear`, `_ao_quebrar`) para não tocar duas vezes.
func _ao_contato(_id: int, _alvo: Node3D, resultado: int, _lado: int, posicao: Vector3, golpe: GolpeDirecional) -> void:
	if _mundo() == null:
		return
	# O visual nasce aqui, uma vez por contato, para os quatro resultados: é quem bateu
	# que sabe o sentido do golpe.
	var corpo := _executor.ator.corpo()
	var sentido := posicao - corpo.global_position if is_instance_valid(corpo) else Vector3.FORWARD
	ImpactoDeCombate.criar(_mundo(), posicao, sentido, resultado, golpe.pesado)
	match resultado:
		ResolucaoDeContato.Resultado.ACERTO:
			if _executor.sons_da_arma.is_empty() or not SonsEpicFight.tocar(_mundo(), posicao, _executor.sons_da_arma.get("impacto", [])):
				AudioFX.impact(_mundo(), posicao, 0.8 if golpe.pesado else 1.0)
			_executor.ator.tremer_camera(TREMOR_PESADO if golpe.pesado else TREMOR_ACERTO)
		ResolucaoDeContato.Resultado.APARO:
			pass   # quem bateu sente pelo rebote (`_ao_ser_rebatido`)
		_:
			_executor.ator.tremer_camera(TREMOR_BLOQUEIO)


func _ao_bloquear(_golpe: GolpeDirecional, posicao: Vector3) -> void:
	if _mundo() != null:
		AudioFX.snap(_mundo(), posicao, 1.35)
	_executor.ator.tremer_camera(TREMOR_BLOQUEIO)


func _ao_quebrar(_golpe: GolpeDirecional, posicao: Vector3) -> void:
	if _mundo() != null:
		AudioFX.impact(_mundo(), posicao, 0.6)
	_executor.ator.tremer_camera(TREMOR_QUEBRA)


## O aparo soa diferente do bloqueio (mais grave e seco): é a leitura que diz ao
## jogador "agora é a sua vez".
func _ao_aparar(_golpe: GolpeDirecional, posicao: Vector3) -> void:
	if _mundo() != null:
		AudioFX.snap(_mundo(), posicao, 0.85)
	_executor.ator.tremer_camera(TREMOR_APARO)


func _ao_ser_rebatido() -> void:
	_executor.ator.tremer_camera(TREMOR_REBATIDO)


func _ao_reagir(_lado: int, _pesado: bool) -> void:
	_executor.ator.tremer_camera(TREMOR_APANHOU)
