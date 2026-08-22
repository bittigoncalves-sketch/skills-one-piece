extends SceneTree
# ============================================================================
#  VARREDURA CLIENTE -> SERVIDOR — LADO CLIENTE (o ATOR). 2 processos.
#
#  Conjura TODAS as skills de TODAS as frutas, em roteiro fixo, e sai. Quem mede
#  é o host (`net_sweep_host_probe.gd`) — este processo não julga nada.
#
#  ---------------------------------------------------------------- COMO RODAR
#  HOST PRIMEIRO, depois este:
#
#    godot --headless --path . --script tools/dev_tests/net_sweep_host_probe.gd
#    godot --headless --path . --script tools/dev_tests/net_sweep_client_probe.gd
#
#  --------------------------------------------------------- POR QUE SEM `Input`
#  Em headless não há teclado, e o `_unhandled_input` nem roda. O roteiro chama
#  a API pública que o input chamaria: `begin_charge` / `release_charge`.
#
#  ⚠️ USA begin+release, NÃO `cast_skill_slot`, de propósito. As frutas têm três
#  arquétipos de disparo — tecla que solta na hora, tecla que SEGURA (Yami C,
#  Bara C), e tecla que CARREGA (Gura X, Mera V, Goro V). Só o par begin+release
#  cobre os três; `cast_skill_slot` atalha e nunca exercita a soltura, que é
#  exatamente onde o V da Goro Goro deixava de falar com o servidor.
#
#  ⚠️ AS TRÊS CONSTANTES ABAIXO TÊM DE SER IGUAIS ÀS DO HOST — é por elas que ele
#  atribui cada hitbox a um slot. Duplicadas de propósito (ver cabeçalho do host).
# ============================================================================

const JANELA_SLOT := 2.6
const ESPERA_FRUTA := 1.2
const SLOTS := ["Z", "X", "C", "V"]
const FRUTAS := [
	"gomu_gomu", "gura_gura", "mera_mera", "bara_bara",
	"goro_goro", "yami_yami", "suna_suna", "hie_hie", "buki_buki",
]

# Quanto a tecla fica PRESSIONADA antes de soltar. Precisa ser generoso: o
# `MamaraganChargeNode` só deixa arremessar depois de a orbe existir (T_ORB=0,70).
const SEGURAR := 0.9

var _p: Node = null
var _t0 := 0.0

func _t() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0

func _init() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec() / 1000.0
	var gf := get_root().get_node("GameFlow")
	if not gf.join_room(NetworkConfig.LOCAL_IP):
		print("[CLI] ❌ join_room falhou — o host está de pé?"); quit(2); return
	print("[CLI] conectando em %s..." % NetworkConfig.LOCAL_IP)

	# ⚠️ `multiplayer` NÃO existe num script `extends SceneTree` — é propriedade de
	# Node. Aqui se chega nele pela raiz, como o `net_cast_client_probe.gd` faz.
	var raiz := get_root()
	var meu_id := 0
	for i in 3000:
		await process_frame
		if raiz.multiplayer != null and raiz.multiplayer.has_multiplayer_peer():
			meu_id = raiz.multiplayer.get_unique_id()
			if meu_id != 0 and meu_id != 1:
				_p = _corpo(str(meu_id))
				if _p != null:
					break
	if _p == null:
		print("[CLI] ❌ meu corpo nunca apareceu (id=%d)" % meu_id); quit(2); return
	print("[CLI][t=%6.2f] meu corpo='%s'" % [_t(), _p.name])

	_p.combat_mode = "fruit"

	# ⚠️ ESPERA O EQUIP INICIAL ATERRISSAR ANTES DE COMEÇAR (2026-08-22).
	# `Main._spawn_player_data` faz `call_deferred("equip_fruit", "mera_mera")`.
	# Sem esta pausa, o primeiro `equip_fruit` do roteiro corria ANTES dele e era
	# sobrescrito: o host via `mera_mera` durante o bloco inteiro da primeira
	# fruta e atribuía as hitboxes dela à fruta errada. Foi o que aconteceu na
	# primeira execução — a Gomu apareceu zerada e a Mera com 60 zonas no C.
	await _esperar(2.5)
	print("[CLI][t=%6.2f] fruta de nascença assentou: '%s'" % [_t(), str(_p.current_fruit_id)])

	for fruta in FRUTAS:
		print("[CLI][t=%6.2f] ══ fruta: %s" % [_t(), fruta])
		_p.equip_fruit(fruta)
		await _esperar(ESPERA_FRUTA)
		for slot in SLOTS:
			await _um_slot(slot)

	print("[CLI][t=%6.2f] roteiro terminado — saindo" % _t())
	await _esperar(1.0)
	quit(0)

# Um slot: zera o que barraria o golpe, aperta, segura, solta, espera a janela.
func _um_slot(slot: String) -> void:
	if not is_instance_valid(_p):
		return
	var inicio := _t()
	# Recarga e energia zeradas: a sonda mede o CANAL DE REDE, não a economia.
	# Sem isto, o V (60 s de recarga) só sairia uma vez na varredura inteira.
	_p._skill_cooldowns[slot] = 0.0
	_p.energy = _p.max_energy
	_p.set_meta("is_casting", false)

	print("[CLI][t=%6.2f]   %s: begin_charge" % [_t(), slot])
	_p.begin_charge(slot)
	await _esperar(SEGURAR)
	if is_instance_valid(_p):
		print("[CLI][t=%6.2f]   %s: release_charge" % [_t(), slot])
		_p.release_charge(slot)
	# ⚠️ ARMAS PRECISAM DE CLIQUE, NÃO DE TECLA (2026-08-22).
	#
	# Na Buki Buki a tecla do slot EMPUNHA a arma; quem atira é o botão esquerdo.
	# Na Yami Yami o Z é um TOGGLE da pistola, idem. Sem simular o clique, a
	# varredura acusava as cinco como "não chegam ao servidor" — e a conclusão
	# seria falsa: elas nem tinham sido disparadas.
	#
	# Em headless não há mouse, então chamamos a mesma API que o clique chamaria
	# (`buki_controller.atirar` -> `Player.pedir_bala_da_buki`, e
	# `Player.pedir_bala_simples` para a pistola da Yami).
	await _disparar_se_for_arma(slot)

	# Fecha a janela do slot: o host atribui por tempo decorrido no bloco.
	var resto := JANELA_SLOT - (_t() - inicio)
	if resto > 0.0:
		await _esperar(resto)

# Três tiros, espaçados o bastante para passarem pela cadência da arma.
func _disparar_se_for_arma(slot: String) -> void:
	if not is_instance_valid(_p):
		return
	var fruta := str(_p.current_fruit_id)
	var e_buki := fruta == "buki_buki"
	var e_pistola_yami := fruta == "yami_yami" and slot == "Z"
	if not (e_buki or e_pistola_yami):
		return
	for i in 3:
		if not is_instance_valid(_p):
			return
		var mira: Dictionary = _p.mira_do_cast()
		if e_buki:
			# O controlador é quem sabe qual arma está na mão e cobra a munição.
			if _p._buki_ativa():
				_p._buki.atirar()
		else:
			_p.pedir_bala_simples(mira["aim"], mira["origem"])
		await _esperar(0.35)

func _esperar(s: float) -> void:
	var fim := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame

func _corpo(nome: String) -> Node:
	for n in get_nodes_in_group("player"):
		if str(n.name) == nome:
			return n
	return null
