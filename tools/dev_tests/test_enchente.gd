extends SceneTree
# ============================================================================
#  A ENCHENTE DO FIM DA RODADA.
#
#  Pedido do dono (2026-09-01): "o que acontece quando o tempo zera? Ao invés de
#  apenas zerar o tempo, a plataforma começa a alagar (não permitir que a água
#  vaze da plataforma). A água vai subindo e qualquer jogador que caia na água e
#  seja completamente coberto por ela morre em 3 segundos. A água sobe até todos
#  estarem mortos e por fim exibe o placar e começa uma contagem de 10 segundos
#  para a próxima partida."
#
#  ⚠️ O QUE FALHA EM SILÊNCIO AQUI:
#   • "morre em 3 segundos" — matar INSTANTANEAMENTE ao encostar na água passa
#     por qualquer teste que só verifique "morreu". Por isso se prova que ele
#     continua vivo no meio do caminho.
#   • "completamente coberto" — água pela cintura não pode matar.
#   • "até todos estarem mortos" — com respawn ligado a fase nunca terminaria, e
#     o placar apareceria assim mesmo. Aqui há um segundo corpo em cena só para
#     provar que o primeiro NÃO volta.
#
#      DISPLAY=:1 godot --path . -s tools/dev_tests/test_enchente.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0
var _sb: Node = null
var _falso: Node3D = null


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	_sb = get_root().get_tree().get_first_node_in_group("scoreboard")
	if p == null or _sb == null:
		print("❌ sem jogador ou sem placar"); quit(1); return

	# Segundo corpo: o placar identifica jogador pelo NOME do nó (= peer id), e
	# só precisa de posição. Ele existe para segurar a fase de pé enquanto o
	# jogador de verdade se afoga — sem ele, a morte do único vivo encerraria a
	# enchente no mesmo quadro e não daria para observar nada.
	_falso = Node3D.new()
	_falso.name = "2"
	get_root().get_node("Main/Players").add_child(_falso)
	_falso.add_to_group("player")
	_falso.global_position = Vector3(0, 50, 0)

	await _comeca_a_alagar(p)
	await _tres_segundos(p)
	await _todos_mortos(p)
	await _proxima_partida()

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## 1. O TEMPO ZERAR NÃO ACABA MAIS A RODADA — ele abre a enchente.
func _comeca_a_alagar(p: Node3D) -> void:
	print("=== 1. o tempo zera e a plataforma alaga ===")
	_sb.time_left = 0.0
	await _quadros(6)
	_ok("zerar o tempo começa a enchente", bool(_sb.get("flooding")))
	# ⚠️ CONTROLE: o placar NÃO pode aparecer aqui. Era isso que acontecia antes
	# do pedido, e é o comportamento que a enchente substitui.
	_ok("o placar ainda NÃO aparece", not _sb.in_podium())

	var y0: float = float(_sb.get("flood_y"))
	await _quadros(40)
	var y1: float = float(_sb.get("flood_y"))
	print("   nível: %.2f -> %.2f m" % [y0, y1])
	_ok("a água sobe", y1 > y0)

	# "Não vaza da plataforma": a caixa d'água tem o lado exato da plataforma.
	var agua := _agua()
	_ok("existe água na cena", agua != null)
	if agua != null:
		var lado: float = float(agua.LADO)
		_ok("a água tem o lado exato da plataforma (não vaza)",
			absf(lado - float(load("res://src/world/MapBuilder.gd").PLATFORM_SIZE)) < 0.01)
		_ok("a água está visível durante a enchente", agua.visible)


## 2. TRÊS SEGUNDOS COBERTO — nem instantâneo, nem com água pela cintura.
func _tres_segundos(p: Node3D) -> void:
	print("\n=== 2. morre em 3 s, coberto por completo ===")
	_ok("a constante declarada é 3 s", absf(float(_sb.DROWN_TIME) - 3.0) < 0.01)

	# ⚠️ O NÍVEL PRECISA SER SEGURADO A CADA QUADRO. A água sobe 1,5 m/s sozinha:
	#   escrever `flood_y` uma vez e esperar 4 s deixava o jogador 6 m submerso, e
	#   o teste acusava "água pela cintura mata" quando o que havia ali era água
	#   acima da cabeça. Foi assim que esta medida falhou da primeira vez.
	var topo: float = p.topo_da_cabeca()
	var pes: float = p.global_position.y
	await _manter_nivel((topo + pes) * 0.5, 4.0)
	print("   com água pela cintura (nível %.2f, cabeça em %.2f): eliminado=%s"
		% [float(_sb.get("flood_y")), topo, str(p._eliminado)])
	_ok("água pela cintura NÃO mata, nem depois de 4 s", not p._eliminado)

	# COBERTO POR COMPLETO: nível bem acima da cabeça, também segurado.
	var afogado: float = p.topo_da_cabeca() + 3.0
	await _manter_nivel(afogado, 1.5)
	_ok("aos 1,5 s submerso ele ainda está vivo", not p._eliminado)
	await _manter_nivel(afogado, 3.5)
	print("   depois de ~5 s submerso: eliminado=%s" % str(p._eliminado))
	_ok("submerso além dos 3 s, ele morre", p._eliminado)

	# ⚠️ NÃO RESPAWNA. O segundo corpo ainda está de pé, então a fase continua —
	# e é aqui que se vê que o afogado ficou fora, em vez de voltar ao centro.
	_ok("o afogado NÃO volta para o jogo", p._eliminado and not _sb.in_podium())


## 3. A ÁGUA SOBE ATÉ TODOS ESTAREM MORTOS.
func _todos_mortos(p: Node3D) -> void:
	print("\n=== 3. sobe até não sobrar ninguém ===")
	_ok("com um vivo em pé, a enchente continua", bool(_sb.get("flooding")))
	# Afunda o segundo corpo: agora não sobra ninguém.
	_falso.global_position = Vector3(0, -5, 0)
	await _esperar(5.0)
	print("   flooding=%s | placar=%s | contagem=%.1f s"
		% [str(_sb.get("flooding")), str(_sb.in_podium()), float(_sb.podium_left)])
	_ok("morto o último, a enchente termina", not bool(_sb.get("flooding")))
	_ok("o placar aparece", _sb.in_podium())
	_ok("a contagem para a próxima partida é de 10 s",
		absf(float(_sb.PODIUM_TIME) - 10.0) < 0.01)
	_ok("e ela já está correndo", float(_sb.podium_left) > 0.0)
	var agua := _agua()
	_ok("a água some junto com a enchente", agua == null or not agua.visible)


## 4. PASSADA A CONTAGEM, COMEÇA PARTIDA NOVA.
func _proxima_partida() -> void:
	print("\n=== 4. a próxima partida ===")
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 14000 and _sb.in_podium():
		await process_frame
	print("   placar fechou | tempo=%.0f s | alagando=%s"
		% [float(_sb.time_left), str(_sb.get("flooding"))])
	_ok("o placar sai depois da contagem", not _sb.in_podium())
	_ok("a rodada nova começa com o tempo cheio",
		absf(float(_sb.time_left) - float(_sb.ROUND_TIME)) < 2.0)
	_ok("e sem água na arena", not bool(_sb.get("flooding")))


# ------------------------------------------------------------------ apoio
func _agua() -> Node3D:
	for n in get_root().get_node("Main").get_children():
		if String(n.name) == "AguaDaArena":
			return n as Node3D
	return null


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


## Segura a linha d'água num valor fixo pelo tempo pedido, reescrevendo-a a cada
## quadro — a enchente é uma rampa, e sem isto qualquer medida de nível vira
## medida de "quanto tempo passou".
func _manter_nivel(y: float, segundos: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(segundos * 1000.0):
		_sb.flood_y = y
		await process_frame


func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond:
		_ok_n += 1
		print("   ✓ %s" % rotulo)
	else:
		_falhas += 1
		print("   ❌ %s" % rotulo)
