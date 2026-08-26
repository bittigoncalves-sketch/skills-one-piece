class_name LanDiscovery
extends Node
# ============================================================================
#  DESCOBERTA AUTOMÁTICA NA REDE LOCAL — entrar sem digitar nada.
#
#  Antes, para jogar junto era preciso o ID da sala (7 chars que codificam o IP
#  do host em base32) ou o IP na mão. Isso obriga alguém a ler um código em voz
#  alta antes de toda partida.
#
#  COMO FUNCIONA: quem hospeda vira um FAROL — manda um pacote UDP curto em
#  difusão a cada segundo. Quem entra fica escutando a porta do farol por alguns
#  segundos e pega o **IP de quem enviou**, direto do socket. Achou, conecta.
#
#  Por que o IP vem do socket e não de dentro da mensagem: o host pode ter várias
#  placas (Wi-Fi, cabo, Docker, VPN) e escolher a errada para anunciar. O
#  endereço de origem do pacote é, por construção, o que consegue falar com este
#  cliente — não tem como estar errado.
#
#  Porta do farol é SEPARADA da porta do jogo: o ENet fica com a do jogo e o farol
#  com a 24566, então um não atrapalha o outro.
#
#  ⚠️ Difusão UDP não atravessa roteador. Isto vale para a MESMA rede local. Para
#  jogar pela internet continua valendo o ID da sala ou o IP direto.
# ============================================================================

const NetConf = preload("res://network/NetworkConfig.gd")
# Segue a porta do jogo (jogo+1), para que SOP_PORTA mova as duas juntas.
static var PORTA_FAROL: int = NetConf.PORTA_FAROL
const MAGICA := "SKILLSONEPIECE1"   # prefixo p/ não confundir com tráfego alheio
const INTERVALO := 1.0              # segundos entre anúncios
const ESPERA_PADRAO := 4.0          # quanto tempo o cliente escuta antes de desistir

var _udp: PacketPeerUDP = null
var _timer: Timer = null
var _porta_jogo := 0
var _sala := ""

# ------------------------------------------------------------------ HOST
# Começa a anunciar esta máquina. Chamar depois que o servidor subiu.
func iniciar_farol(porta_jogo: int, sala: String) -> void:
	parar_farol()
	_porta_jogo = porta_jogo
	_sala = sala
	_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)

	_timer = Timer.new()
	_timer.name = "FarolLan"
	_timer.wait_time = INTERVALO
	_timer.autostart = true
	add_child(_timer)
	_timer.timeout.connect(_anunciar)
	_anunciar()   # o primeiro sai na hora, sem esperar o primeiro tique
	print("[LAN] farol ligado (porta %d, sala %s) — quem entrar acha sozinho" % [porta_jogo, sala])

func parar_farol() -> void:
	if _timer and is_instance_valid(_timer):
		_timer.queue_free()
	_timer = null
	if _udp:
		_udp.close()
	_udp = null

func _anunciar() -> void:
	if _udp == null:
		return
	var msg := "%s|%d|%s" % [MAGICA, _porta_jogo, _sala]
	var dados := msg.to_utf8_buffer()
	for destino in _enderecos_de_difusao():
		_udp.set_dest_address(destino, PORTA_FAROL)
		_udp.put_packet(dados)

# 255.255.255.255 é bloqueado em algumas redes/adaptadores; por isso mandamos
# TAMBÉM na difusão de cada sub-rede em que esta máquina está (ex.: numa placa
# 192.168.11.15 vai também para 192.168.11.255). Um dos dois passa.
func _enderecos_de_difusao() -> Array:
	var out: Array = ["255.255.255.255"]
	for a in IP.get_local_addresses():
		if a.count(".") != 3 or a.begins_with("127."):
			continue
		var seg := a.split(".")
		if seg.size() != 4:
			continue
		var difusao: String = "%s.%s.%s.255" % [seg[0], seg[1], seg[2]]
		if not out.has(difusao):
			out.append(difusao)
	return out

# ----------------------------------------------------------------- CLIENTE
# Escuta o farol e devolve {"ip", "porta", "sala"} do primeiro host que aparecer,
# ou {} se ninguém respondeu dentro de `espera`.
#
# É corrotina: quem chama precisa dar `await`. Não trava o jogo — cede o quadro
# entre as leituras.
static func procurar(contexto: Node, espera: float = ESPERA_PADRAO) -> Dictionary:
	if contexto == null or not contexto.is_inside_tree():
		return {}
	var udp := PacketPeerUDP.new()
	if udp.bind(PORTA_FAROL) != OK:
		# Porta ocupada = já existe alguém escutando nesta máquina (outra
		# instância do jogo procurando ao mesmo tempo).
		push_warning("[LAN] não consegui escutar a porta %d" % PORTA_FAROL)
		return {}

	var fim := Time.get_ticks_msec() + int(espera * 1000.0)
	while Time.get_ticks_msec() < fim:
		while udp.get_available_packet_count() > 0:
			var texto := udp.get_packet().get_string_from_utf8()
			var ip := udp.get_packet_ip()
			var partes := texto.split("|")
			if partes.size() >= 3 and partes[0] == MAGICA and ip != "":
				udp.close()
				var achado := {"ip": ip, "porta": int(partes[1]), "sala": partes[2]}
				print("[LAN] host encontrado: %s (sala %s)" % [ip, partes[2]])
				return achado
		await contexto.get_tree().process_frame
	udp.close()
	print("[LAN] nenhum host anunciando em %.0f s" % espera)
	return {}
