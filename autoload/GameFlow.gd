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

## BONECOS DE TREINO — preferência do jogador, LIGADA por padrão (2026-08-23).
##
## Mora aqui, e não no `Main`, por dois motivos:
##   • o MENU precisa mexer nisto ANTES de a cena do mundo existir — o `Main`
##   nem foi instanciado quando o jogador marca a caixinha;
##   • é preferência, e preferência deste projeto se guarda em `settings.cfg`,
##   pelo mesmo par `_load_settings`/`_save_settings` que já serve o `device`.
##
## São DOIS interruptores e não um: o boneco parado é alvo de aferição de dano
## (toda medição da tabela do `Balance` é feita nele) e o automático é sparring
## que revida. Quem quer medir um golpe em paz desliga o segundo e mantém o
## primeiro — juntá-los num só tiraria justamente essa combinação.
const DUMMIES := {"TrainingDummy": "Boneco de treino", "AutoDummy": "Boneco automático"}
var dummies: Dictionary = {"TrainingDummy": true, "AutoDummy": true}

func dummy_ligado(tipo: String) -> bool:
	return bool(dummies.get(tipo, true))

## Liga/desliga um boneco E APLICA NO MUNDO se já houver mundo. Os dois passos
## andam juntos de propósito: o menu principal chama isto sem cena carregada (só
## grava), e a HUD chama em partida (grava e o mapa muda na hora). Quem chama não
## precisa saber em qual dos dois casos está.
func set_dummy(tipo: String, ligado: bool) -> void:
	if not DUMMIES.has(tipo):
		push_warning("[GameFlow] boneco desconhecido: '%s'" % tipo)
		return
	dummies[tipo] = ligado
	_save_settings()
	var arv := get_tree()
	var mundo: Node = arv.current_scene if arv else null
	if mundo and mundo.has_method("pedir_dummy"):
		mundo.pedir_dummy(tipo, ligado)

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
	# As sondas sobem a mesma arena da partida. O AutoDummy persegue e ataca,
	# interferindo no jogador no meio de cargas e medições; o TrainingDummy
	# passivo fica, pois é alvo legítimo de vários testes. Não usar set_dummy:
	# isso gravaria a preferência de teste no settings.cfg do jogador.
	if _executando_teste_automatizado():
		dummies["AutoDummy"] = false
		print("[GameFlow] teste automatizado: AutoDummy desativado")
	# Singleplayer = SERVIDOR LOCAL (host = você, peer id 1). Exatamente o mesmo
	# caminho do multiplayer -> zero lógica duplicada.
	if not ServerManager.host_offline():
		push_error("[GameFlow] falha ao iniciar servidor local offline")
		return
	_enter_world()

func _executando_teste_automatizado() -> bool:
	for arg in OS.get_cmdline_args():
		if "tools/dev_tests/" in arg or "src/tests/" in arg:
			return true
	return false

## ============================================================================
##  HOSPEDAR PARA FORA DA REDE DE CASA
##
##  `create_room()` continua sendo a sala de LAN: o ID codifica o IP local e só
##  vale para quem está na mesma casa. Esta versão faz o que falta para alguém
##  de outro lugar entrar:
##
##    1. sobe o servidor normalmente (é o mesmo ENet, a mesma porta);
##    2. pede ao roteador que encaminhe a porta (UPnP);
##    3. troca o ID da sala por um que codifica o IP PÚBLICO.
##
##  ⚠️ O ID SÓ É TROCADO SE A PORTA ABRIR. Um ID com IP público e porta fechada
##  é pior que um ID de LAN: o amigo digita, espera, e o erro não diz nada sobre
##  a porta. Quando o UPnP falha, a sala continua valendo na LAN e o motivo é
##  dito em voz alta.
##
##  A sala já está NO AR antes de o UPnP responder — ninguém espera o roteador
##  para começar a jogar em casa.
## ============================================================================
signal sala_publica_pronta(ok: bool, id_publico: String, motivo: String)

var _exposicao: ExposicaoPublica = null
var _porta_exposta := 0


func create_room_publica() -> void:
	create_room()
	if mode != Mode.HOST:
		return
	_porta_exposta = NetConf.DEFAULT_PORT
	_exposicao = ExposicaoPublica.new()
	_exposicao.terminou.connect(_ao_expor)
	print("[GameFlow] pedindo ao roteador a porta %d (UPnP)..." % _porta_exposta)
	_exposicao.abrir(_porta_exposta)


func _ao_expor(ok: bool, ip_publico: String, motivo: String) -> void:
	var id_publico := ""
	if ok and not ip_publico.is_empty():
		id_publico = encode_room_id(ip_publico)
		if not id_publico.is_empty():
			room_id = id_publico
		print("[GameFlow] sala PÚBLICA: %s (ID %s) — %s" % [ip_publico, id_publico, motivo])
	else:
		print("[GameFlow] a sala continua só na LAN — %s" % motivo)
	sala_publica_pronta.emit(ok, id_publico, motivo)


## Fecha a porta no roteador. Um mapeamento permanente que ninguém remove fica
## lá para sempre, e a próxima pessoa a usar a rede herda uma porta aberta.
func fechar_sala_publica() -> void:
	if _porta_exposta <= 0:
		return
	ExposicaoPublica.fechar(_porta_exposta)
	_porta_exposta = 0
	_exposicao = null


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
		for tipo in DUMMIES:
			dummies[tipo] = bool(cfg.get_value("client", "dummy_" + tipo, true))

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)   # preserva outras chaves
	cfg.set_value("client", "device", device)
	for tipo in DUMMIES:
		cfg.set_value("client", "dummy_" + tipo, dummy_ligado(tipo))
	cfg.save(CONFIG_PATH)
