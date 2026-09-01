class_name ExposicaoPublica
extends RefCounted
# ============================================================================
#  ABRIR A PORTA PARA FORA — hospedar para quem não está na mesma casa.
#
#  ------------------------------------------------------- O QUE FALTAVA
#  O jogo já hospedava e já era encontrado na LAN (`LanDiscovery`), e o ID da
#  sala codifica o IP do host em base32 (`GameFlow.encode_room_id`). Só que o IP
#  codificado é o LOCAL — `192.168.x.x` —, que não existe fora da rede de casa.
#  Um amigo de outra cidade recebia um ID válido para um endereço inalcançável.
#
#  Duas coisas resolvem isso, e as duas moram aqui:
#
#    1. O ROTEADOR PRECISA DEIXAR PASSAR. Um pedido que chega da internet na
#       porta 24565 bate no roteador, não no PC. UPnP pede ao próprio roteador
#       que encaminhe a porta para esta máquina.
#    2. O ID PRECISA CARREGAR O IP PÚBLICO. É o `query_external_address()`, que
#       pergunta ao roteador qual é o endereço dele visto de fora.
#
#  ------------------------------------------------------ EM OUTRA THREAD
#  ⚠️ `UPNP.discover()` é BLOQUEANTE e leva de 1 a 4 segundos: chamado na thread
#  principal, o jogo congela ao criar a sala. Aqui ele roda numa `Thread` e o
#  resultado chega por sinal.
#
#  ------------------------------------------------------ QUANDO NÃO DÁ
#  UPnP pode estar desligado no roteador, e em rede de operadora (CGNAT) não há
#  porta a abrir — o endereço público não é seu. Nos dois casos o resultado diz
#  o motivo em vez de falhar em silêncio, porque a saída é diferente: no
#  primeiro, ligar UPnP ou encaminhar a porta à mão; no segundo, só um túnel ou
#  VPN resolve, e isso está fora do que este arquivo faz.
# ============================================================================

## O pedido terminou. `ok` diz se a porta foi aberta; `ip_publico` vem vazio
## quando não deu para descobrir; `motivo` é texto para o jogador ler.
signal terminou(ok: bool, ip_publico: String, motivo: String)

const DESCRICAO := "Skills One Piece"
## Por quanto tempo o mapeamento vale, em segundos. 0 = permanente, e é o que
## evita a porta fechar no meio de uma partida longa.
const DURACAO := 0

var _thread: Thread = null
var _porta := 0


## Abre `porta` no roteador e descobre o IP público. O resultado chega em
## `terminou` — nada aqui bloqueia quem chamou.
func abrir(porta: int) -> void:
	if _thread != null:
		return
	_porta = porta
	_thread = Thread.new()
	_thread.start(_trabalho)


func _trabalho() -> void:
	var upnp := UPNP.new()
	var achou := upnp.discover()
	if achou != UPNP.UPNP_RESULT_SUCCESS:
		_responder(false, "", "o roteador não respondeu ao UPnP (código %d)" % achou)
		return
	var gateway := upnp.get_gateway()
	if gateway == null or not gateway.is_valid_gateway():
		_responder(false, "", "achei o roteador, mas ele não aceita encaminhar portas")
		return

	var externo := upnp.query_external_address()

	# ⚠️ APAGA ANTES DE CRIAR. `add_port_mapping` FALHA quando já existe um
	# mapeamento para aquela porta — e existe sempre que a sala foi aberta antes
	# e o jogo não chegou a fechá-la (fechou pela janela, travou, caiu a luz).
	# Medido: a primeira execução abriu, a segunda voltou `ok=false` com a porta
	# já aberta e funcionando. Sem esta limpeza, reabrir a sala falha na segunda
	# vez e o motivo não diz nada sobre o mapeamento antigo.
	upnp.delete_port_mapping(_porta, "UDP")
	upnp.delete_port_mapping(_porta, "TCP")
	# ⚠️ ENet usa UDP; o TCP entra junto porque alguns roteadores só listam o
	# mapeamento na interface quando as duas famílias estão lá, e isso é o que o
	# jogador vai conferir se algo não funcionar.
	var r_udp := upnp.add_port_mapping(_porta, _porta, DESCRICAO, "UDP", DURACAO)
	upnp.add_port_mapping(_porta, _porta, DESCRICAO, "TCP", DURACAO)
	if r_udp != UPNP.UPNP_RESULT_SUCCESS:
		_responder(false, externo,
			"o roteador recusou abrir a porta %d (código %d)" % [_porta, r_udp])
		return
	if externo.is_empty() or externo.begins_with("192.168.") \
			or externo.begins_with("10.") or externo.begins_with("100.64."):
		# Endereço externo que ainda é privado = a operadora está entre você e a
		# internet (CGNAT). A porta abriu no SEU roteador e não adianta.
		_responder(false, externo,
			"a porta abriu, mas o endereço externo (%s) ainda é privado: a operadora usa CGNAT e nenhuma porta sua é alcançável de fora"
				% externo)
		return
	_responder(true, externo, "porta %d aberta e endereço público %s" % [_porta, externo])


func _responder(ok: bool, ip: String, motivo: String) -> void:
	# `call_deferred` porque isto roda na thread de trabalho: emitir sinal daqui
	# entrega o callback na thread errada, e quem escuta mexe em nó de cena.
	call_deferred("_emitir", ok, ip, motivo)


func _emitir(ok: bool, ip: String, motivo: String) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	terminou.emit(ok, ip, motivo)


## Fecha o que foi aberto. Chamar ao encerrar a sala: mapeamento permanente que
## ninguém remove fica no roteador para sempre.
static func fechar(porta: int) -> void:
	var upnp := UPNP.new()
	if upnp.discover() != UPNP.UPNP_RESULT_SUCCESS:
		return
	upnp.delete_port_mapping(porta, "UDP")
	upnp.delete_port_mapping(porta, "TCP")
