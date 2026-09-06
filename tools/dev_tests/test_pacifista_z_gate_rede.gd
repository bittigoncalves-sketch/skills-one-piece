extends SceneTree
## Regressao do gate de rede do Z Pacifista.
##
## `_net_play_cast` executa `FightingStyles.cast()` em cada copia do jogador.
## Numa copia remota/servidora, a meta local do pressionamento nao existe. A
## presentation autoritativa precisa, portanto, subir a meta e criar `LaserPX`
## por conta propria. Chamar o mesmo ponto de entrada diretamente deixa essa
## pre-condicao deterministica sem o custo e a instabilidade de dois processos.
##
## A implementacao anterior falha nas duas verificacoes centrais: encontrava a
## meta falsa, retornava antes de cria-la e nao instanciava o laser.
##
##   godot --headless --path . -s tools/dev_tests/test_pacifista_z_gate_rede.gd

const CAMINHO_LASER := "res://src/combat/laser_px.gd"

var _acertos := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var limite := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < limite and _jogador() == null:
		await process_frame

	var jogador := _jogador()
	if jogador == null:
		print("❌ jogador nao apareceu")
		quit(2)
		return

	# Simula a copia que recebeu `_net_play_cast`, mas nao recebeu o pressionamento
	# local da tecla. Nao use `begin_charge()`: ele subiria a meta e esconderia a
	# regressao que este teste existe para detectar.
	jogador.remove_meta("px_laser_ativo")
	_checar("a copia comeca sem a meta local do hold",
		not bool(jogador.get_meta("px_laser_ativo", false)))

	var mira: Dictionary = jogador.mira_do_cast()
	FightingStyles.cast(current_scene, "pacifista", 0, mira["origem"], mira["aim"],
		92.0, jogador, null)

	_checar("a presentation autoritativa liga px_laser_ativo",
		bool(jogador.get_meta("px_laser_ativo", false)))
	_checar("a presentation autoritativa cria LaserPX", _laser_de(jogador) != null)

	# Exercita o mesmo receptor usado quando o dono solta Z. Em SP a chamada
	# direta equivale ao corpo do RPC depois da validacao de remetente.
	jogador._net_cancel_hold("Z", "pacifista")
	_checar("o cancelamento autoritativo desliga a meta",
		not bool(jogador.get_meta("px_laser_ativo", false)))
	await physics_frame
	await physics_frame
	_checar("o LaserPX desaparece depois do cancelamento", _laser_de(jogador) == null)

	print("\n%d conferem | %d divergem" % [_acertos, _falhas])
	quit(1 if _falhas > 0 else 0)


func _jogador() -> Node:
	for no in get_nodes_in_group("player"):
		if no.is_multiplayer_authority():
			return no
	return null


func _laser_de(jogador: Node) -> Node:
	for filho in jogador.get_children():
		var script = filho.get_script()
		if script != null and script.resource_path == CAMINHO_LASER \
				and not filho.is_queued_for_deletion():
			return filho
	return null


func _checar(rotulo: String, condicao: bool) -> void:
	print("%s %s" % ["✓" if condicao else "❌", rotulo])
	if condicao:
		_acertos += 1
	else:
		_falhas += 1
