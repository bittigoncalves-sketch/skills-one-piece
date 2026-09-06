extends SceneTree
# ============================================================================
#  A ÁGUA SOBE GRADUALMENTE? — pedido do dono (2026-09-01).
#
#  ⚠️ MEDE O TOPO VISÍVEL DA MALHA, não o `flood_y`. É a malha que o jogador vê:
#  o número pode subir liso enquanto o desenho anda aos degraus, se o nó visual
#  estiver lendo o valor num ritmo diferente do que o escreve.
#
#  ⚠️ E MEDE POR QUADRO DE RENDER. Amostrar de 0,5 em 0,5 s alisaria justamente
#  o defeito procurado — um salto dura um quadro.
#
#      DISPLAY=:1 godot --path . -s tools/dev_tests/medir_subida_agua.gd
# ============================================================================

const AMOSTRAS := 300


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var sb := get_root().get_tree().get_first_node_in_group("scoreboard")
	# Segura a fase de pé: sem isto o jogador se afoga e a subida termina no meio
	# da medição.
	var vivo := Node3D.new()
	vivo.name = "2"
	get_root().get_node("Main/Players").add_child(vivo)
	vivo.add_to_group("player")
	vivo.global_position = Vector3(0, 60, 0)

	sb.time_left = 0.0
	await _quadros(15)
	var agua := _agua()
	if agua == null:
		print("❌ sem água na cena"); quit(1); return

	print("\n=== 1. subida normal ===")
	var normal := await _amostrar(agua, 300, sb, 0.0)

	# ⚠️ A DERIVA DA REDE. O servidor reemite o nível 2x por segundo; se o cliente
	#   estiver alguns centímetros atrás, aquele pacote é uma CORREÇÃO. Copiar o
	#   valor cru faria a parede de água pular a cada meio segundo — que é
	#   exatamente o defeito que "subir gradualmente" exclui.
	print("\n=== 2. com correção de rede a cada 0,5 s (ritmo do sync) ===")
	var corrigida := await _amostrar(agua, 300, sb, 0.3)

	# CONTROLE AO CONTRÁRIO: uma divergência GRANDE tem de saltar mesmo — é troca
	# de estado (entrou agora, mudou de fase), não deriva. Se este caso não
	# saltasse, o amortecimento estaria engolindo o nível de verdade.
	print("\n=== 3. divergência grande (deve saltar, de propósito) ===")
	var grande := await _amostrar(agua, 120, sb, 5.0)

	print("\n--- veredito ---")
	_veredito("subida normal", normal, true)
	_veredito("com correção de rede", corrigida, true)
	_veredito("divergência grande", grande, false)
	quit(0)


func _amostrar(agua: Node3D, n: int, sb: Node, empurrao: float) -> Dictionary:
	var passos: Array = []
	var anterior := _topo(agua)
	var ultimo := Time.get_ticks_msec()
	for i in n:
		await process_frame
		# ⚠️ NO RITMO REAL DO SYNC (SYNC_INTERVAL = 0,5 s), medido em TEMPO e não em
		#   quadros: a primeira versão empurrava a cada 30 quadros, que a 144 Hz é
		#   uma correção a cada 0,2 s — deriva de 1,5 m/s, coisa que a rede não
		#   produz. O teste estava mais duro que a realidade e reprovava um
		#   amortecimento que servia.
		if empurrao != 0.0 and Time.get_ticks_msec() - ultimo >= 500:
			ultimo = Time.get_ticks_msec()
			sb.flood_y = float(sb.flood_y) + empurrao
		var agora := _topo(agua)
		passos.append(agora - anterior)
		anterior = agora

	var soma := 0.0
	var maior := -1e9
	var menor := 1e9
	var recuos := 0
	for d in passos:
		soma += float(d)
		maior = maxf(maior, float(d))
		menor = minf(menor, float(d))
		if float(d) < -0.0001:
			recuos += 1
	var media := soma / float(passos.size())
	var saltos := 0
	for d in passos:
		if float(d) > media * 3.0 and float(d) > 0.01:
			saltos += 1
	print("   passo médio %.4f m | maior %.4f (%.1fx) | menor %.4f | recuos %d | saltos %d"
		% [media, maior, maior / maxf(media, 1e-6), menor, recuos, saltos])
	return {"media": media, "maior": maior, "menor": menor, "recuos": recuos, "saltos": saltos}


## ⚠️ O CRITÉRIO É ABSOLUTO, EM METROS, e não uma razão sobre a média. A primeira
## versão exigia "passo máximo <= 2x a média" e reprovava o caso COM correção de
## rede — mas absorver deriva exige, por definição, andar um pouco mais depressa
## por alguns quadros. O critério punia o comportamento desejado. O que o jogador
## enxerga como solavanco é a distância em METROS num único quadro: 2,8 cm não se
## vê; meio metro se vê.
const SALTO_VISIVEL := 0.10   # m num único quadro


func _veredito(rotulo: String, m: Dictionary, deve_ser_liso: bool) -> void:
	var liso: bool = int(m["saltos"]) == 0 and int(m["recuos"]) == 0 \
		and float(m["maior"]) <= SALTO_VISIVEL
	var certo: bool = liso == deve_ser_liso
	print("   %s %-22s %s (esperado: %s)" % [
		"✓" if certo else "❌", rotulo,
		"GRADUAL" if liso else "aos saltos",
		"gradual" if deve_ser_liso else "saltar"])


## Topo visível: centro da caixa + metade da altura escalada.
func _topo(agua: Node3D) -> float:
	var malha: MeshInstance3D = agua.get_child(0)
	return malha.global_position.y + malha.scale.y * 0.5


func _agua() -> Node3D:
	for n in get_root().get_node("Main").get_children():
		if String(n.name) == "AguaDaArena":
			return n as Node3D
	return null


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
