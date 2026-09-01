extends SceneTree
# ============================================================================
#  A SALA PÚBLICA ABRE MESMO A PORTA?
#
#  ⚠️ ESTE TESTE MEXE NO ROTEADOR. Ele abre o mapeamento e o FECHA no fim —
#  mapeamento permanente que ninguém remove fica lá depois que o jogo sai, e a
#  próxima pessoa a usar a rede herda uma porta aberta sem saber.
#
#      godot --headless --path . -s tools/dev_tests/test_sala_publica.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	var porta := NetworkConfig.DEFAULT_PORT + 900   # porta de teste, não a do jogo
	print("=== abrindo a porta %d ===" % porta)

	# ⚠️ NÃO CHAMAR DE `exp`: `exp()` é função nativa do GDScript (exponencial), e
	# a variável sombreia a função — o sinal nunca chegava e o teste acusava
	# "o UPnP não respondeu" num UPnP que respondia em 2,1 s.
	var expositor := ExposicaoPublica.new()
	# ⚠️ MUTAR, NUNCA REATRIBUIR. O lambda do GDScript captura por VALOR:
	# `resultado = {...}` lá dentro cria uma cópia e a variável daqui de fora
	# nunca muda — o teste ficava esperando para sempre e acusava "o UPnP não
	# respondeu" num UPnP que respondia em 2,1 s. Escrever numa CHAVE do
	# dicionário atravessa, porque o dicionário em si é o mesmo objeto.
	var resultado := {}
	expositor.terminou.connect(func(ok, ip, motivo):
		resultado["ok"] = ok
		resultado["ip"] = ip
		resultado["motivo"] = motivo)
	expositor.abrir(porta)

	var limite := Time.get_ticks_msec() + 20000
	while resultado.is_empty() and Time.get_ticks_msec() < limite:
		await process_frame
	if resultado.is_empty():
		print("❌ o UPnP não respondeu em 20 s")
		quit(1)
		return

	print("   ok=%s  ip=%s" % [str(resultado["ok"]), str(resultado["ip"])])
	print("   motivo: %s" % str(resultado["motivo"]))
	_ok("o pedido terminou sem travar o jogo", true)
	_ok("o roteador aceitou abrir a porta", bool(resultado["ok"]))
	_ok("o endereço público foi descoberto", not String(resultado["ip"]).is_empty())

	# O ID da sala precisa codificar esse endereço, senão o amigo recebe um
	# código que aponta para lugar nenhum.
	var gf := get_root().get_node("GameFlow")
	var id_publico: String = gf.encode_room_id(String(resultado["ip"]))
	print("   ID da sala para esse IP: %s" % id_publico)
	_ok("o IP público vira um ID de sala válido", id_publico.length() == 7)

	print("\n=== fechando a porta (não deixar aberta) ===")
	ExposicaoPublica.fechar(porta)
	print("   fechada.")

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
