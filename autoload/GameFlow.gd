extends Node
## GameFlow (AUTOLOAD) — fachada única dos 3 modos do jogo.
##
## É o ÚNICO ponto que o Menu conhece. Hoje só troca de cena; nas fases de rede
## passará a: Singleplayer/Criar Sala -> ServerManager.host() + ClientManager.join
## ("127.0.0.1"); Entrar por ID -> ClientManager.join(ip). A interface NÃO muda,
## então o Menu e o resto do jogo não serão reescritos ao ligar a rede.

enum Mode { NONE, SINGLEPLAYER, HOST, CLIENT }

const NetConf = preload("res://network/NetworkConfig.gd")
const WORLD_SCENE := "res://Main.tscn"
const CONFIG_PATH := "user://settings.cfg"

var mode: int = Mode.NONE
var room_id: String = ""
var device: String = "pc"          # "celular" | "tablet" | "pc"
var is_dedicated: bool = false     # servidor dedicado (headless, sem player local)
# Farol da LAN: anuncia esta máquina por UDP enquanto ela hospeda, para quem
# entrar não precisar digitar ID nem IP. Ver network/LanDiscovery.gd.
var _farol: LanDiscovery = null

func _ready() -> void:
	print("[GameFlow] Display Server (Driver): ", DisplayServer.get_name())
	Input.use_accumulated_input = false
	
	_load_settings()
	# Fase 10: se lançado com "--server" (ex.: servidor.sh), sobe como DEDICADO —
	# hospeda e entra no mundo SEM criar um player local (o host não joga).
	# ADIADO: trocar de cena durante o _ready do autoload deixa a árvore "busy".
	if "--server" in OS.get_cmdline_user_args():
		start_dedicated.call_deferred()

## Servidor dedicado: hospeda e carrega o mundo, mas NÃO spawna player do host.
## Trocar p/ nuvem = só a porta/IP; a lógica do jogo é a mesma dos outros modos.
func start_dedicated(port: int = NetConf.DEFAULT_PORT) -> void:
	mode = Mode.HOST
	is_dedicated = true
	room_id = _generate_room_id()
	if not ServerManager.host(port):
		push_error("[GameFlow] servidor dedicado falhou na porta %d" % port)
		return
	print("[GameFlow] SERVIDOR DEDICADO no ar (porta %d, sala %s)" % [port, room_id])
	_ligar_farol_lan(port)   # dedicado também se anuncia: é o caso onde ninguém tem o ID
	_enter_world()

# ---- 3 MODOS (a mesma "entrada no mundo" p/ não duplicar lógica) ----
func start_singleplayer() -> void:
	mode = Mode.SINGLEPLAYER
	room_id = ""
	# Singleplayer = SERVIDOR LOCAL (host = você, peer id 1). Exatamente o mesmo
	# caminho do multiplayer -> zero lógica duplicada.
	if not ServerManager.host():
		push_error("[GameFlow] falha ao iniciar servidor local")
		return
	_enter_world()

func create_room() -> void:
	mode = Mode.HOST
	room_id = _generate_room_id()
	if not ServerManager.host():
		push_error("[GameFlow] falha ao criar sala")
		return
	print("[GameFlow] Sala criada -> ID ", room_id)
	_ligar_farol_lan(NetConf.DEFAULT_PORT)
	_enter_world()

# ---- CONECTAR POR LAN: entrar sem digitar nada ----
# O host anuncia por UDP em difusão; aqui a gente escuta e conecta no primeiro
# que responder. Ver network/LanDiscovery.gd.
#
# É corrotina (precisa esperar o farol) — quem chama usa `await`.
func join_lan(espera: float = LanDiscovery.ESPERA_PADRAO) -> Dictionary:
	var achado: Dictionary = await LanDiscovery.procurar(self, espera)
	if achado.is_empty():
		return {"ok": false, "motivo": "nenhuma sala aberta encontrada na rede local"}
	var ip: String = str(achado.get("ip", ""))
	mode = Mode.CLIENT
	room_id = str(achado.get("sala", ""))
	if not ClientManager.join(ip):
		push_error("[GameFlow] achei o host em %s mas a conexão falhou" % ip)
		return {"ok": false, "motivo": "achei o host em %s, mas a conexão falhou" % ip}
	_enter_world()
	return {"ok": true, "ip": ip, "sala": room_id}

# O farol vive no próprio GameFlow (autoload), então sobrevive à troca de cena
# para o mundo — se morresse junto com o menu, o anúncio parava justamente
# quando a sala fica disponível.
func _ligar_farol_lan(porta: int) -> void:
	if _farol == null:
		_farol = LanDiscovery.new()
		_farol.name = "LanDiscovery"
		add_child(_farol)
	_farol.iniciar_farol(porta, room_id)

func join_room(id: String) -> bool:
	var code := id.strip_edges()
	if code.length() < 4:
		print("[GameFlow] ID/endereço de sala inválido: '", id, "'")
		return false
	mode = Mode.CLIENT
	room_id = code.to_upper()
	# O ID da sala CODIFICA o IP do host (base32). join = decodifica -> IP e conecta.
	# Se o jogador digitar um IP direto, também vale. Fallback = loopback (mesmo PC).
	var ip := code
	if not _looks_like_ip(code):
		var decoded := decode_room_id(code)
		ip = decoded if decoded != "" else NetConf.LOCAL_IP
	if not ClientManager.join(ip):
		push_error("[GameFlow] falha ao conectar em %s" % ip)
		return false
	_enter_world()
	return true

func quit_game() -> void:
	get_tree().quit()

## Camera Feel: HIT-STOP — micro-congelamento no impacto (dá peso ao golpe).
## Brevíssimo; o timer ignora o time_scale (volta em tempo real). Não roda em
## servidor dedicado (afetaria o sim de todos) e não empilha.
func hit_stop(duration: float = 0.05, scale: float = 0.06) -> void:
	if is_dedicated or Engine.time_scale < 1.0:
		return
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

## Slow-mo cinematográfico (ultimate): mais longo/forte que o hit-stop.
func slow_mo(scale: float = 0.35, duration: float = 0.14) -> void:
	if is_dedicated or Engine.time_scale < 1.0:
		return
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

# ---- preferências ----
func set_device(dev: String) -> void:
	device = dev
	_save_settings()

# ---- infra ----
func _enter_world() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)

func _looks_like_ip(s: String) -> bool:
	var parts := s.split(".")
	if parts.size() != 4:
		return false
	for p in parts:
		if not p.is_valid_int():
			return false
	return true

const RID_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # 32 símbolos (sem 0/O/1/I ambíguos)

# ID da sala = IP do host codificado em base32 (7 chars). Assim quem entrar com o ID
# reconecta no IP certo. Porta = DEFAULT_PORT (fixa).
func _generate_room_id() -> String:
	return encode_room_id(_local_ip())

func encode_room_id(ip: String) -> String:
	var parts := ip.split(".")
	if parts.size() != 4:
		return ""
	var v: int = 0
	for p in parts:
		v = (v << 8) | (int(p) & 255)
	var s := ""
	for i in 7:
		s = RID_CHARS[v & 31] + s
		v = v >> 5
	return s

func decode_room_id(code: String) -> String:
	var c := code.strip_edges().to_upper()
	if c.length() != 7:
		return ""
	var v: int = 0
	for ch in c:
		var idx := RID_CHARS.find(ch)
		if idx < 0:
			return ""
		v = (v << 5) | idx
	return "%d.%d.%d.%d" % [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]

# Melhor IP local (LAN privado) p/ montar o ID; fallback = loopback.
func _local_ip() -> String:
	var fallback := ""
	for a in IP.get_local_addresses():
		if a.count(".") != 3 or a.begins_with("127."):
			continue
		if fallback == "":
			fallback = a
		if a.begins_with("192.168.") or a.begins_with("10."):
			return a
		var seg := a.split(".")
		if seg[0] == "172" and seg[1].is_valid_int() and int(seg[1]) >= 16 and int(seg[1]) <= 31:
			return a
	return fallback if fallback != "" else NetConf.LOCAL_IP

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		device = str(cfg.get_value("client", "device", "pc"))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)   # preserva outras chaves
	cfg.set_value("client", "device", device)
	cfg.save(CONFIG_PATH)
