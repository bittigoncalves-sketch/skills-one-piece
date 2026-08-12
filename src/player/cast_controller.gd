class_name CastController
extends RefCounted
# ============================================================================
#  CAST — decidir SE e COMO conjurar. Passo 6c de docs/AUDITORIA_FASE6.md.
#
#  ------------------------------------------------------------- A FRONTEIRA
#  Este é o lado da DECISÃO. Ele não fala rede, não cria hitbox e não toca em
#  VFX:
#
#      CastController  →  decide, valida, mira
#      Player          →  fala rede (`_net_cast`), cria a hitbox
#                         (`_do_server_cast`) e apresenta (`_fire_skill`)
#
#  Os `@rpc` ficam no Player desde a Fase 5: RPC se resolve por CAMINHO DE NÓ, e
#  o canal de bala é compartilhado com a Buki e com a rajada Z. Mover o método
#  mudaria o protocolo das três mecânicas de uma vez.
#
#  ------------------------------------------------- POR QUE `begin_charge` É ASSIM
#  O `comecar()` parece uma pilha de casos especiais, e é — mas cada um deles é
#  uma REGRA DE JOGO diferente, não um remendo:
#
#    • Buki Buki    : a tecla EMPUNHA a arma, não lança golpe
#    • Yami Z       : a tecla é um TOGGLE de pistola
#    • Yami C       : exige contato com o solo (Black Hole)
#    • Mera/Hie Z   : é RAJADA — começa ao pressionar e NÃO congela o corpo
#    • estilo teste : dispara direto, sem carregar
#
#  Só o que sobra desses casos é que carrega de verdade (congela + pausa a
#  animação enquanto mira). Espalhar isso em cinco arquivos não deixaria mais
#  claro — deixaria mais difícil de ver a ordem em que as regras se aplicam,
#  que é o que realmente importa aqui.
#
#  ⚠️ Nunca chama `is_multiplayer_authority()`: a autoridade NÃO desce para
#  componentes criados no `_ready()` (medido na Fase 5: pai=7, filho=1).
# ============================================================================

var _dono: Node = null

var _carregando: bool = false   # segurando a tecla, mirando
var _slot: String = ""          # qual slot está sendo carregado
# Identidade do cast atual. Serve para o timer de um cast antigo não mandar no
# cast novo quando o jogador solta e aperta de novo rápido.
var _token: int = 0

func montar_em(dono: Node) -> void:
	_dono = dono

# ------------------------------------------------------------------ leitura
func carregando() -> bool: return _carregando
func slot() -> String:     return _slot
func token() -> int:       return _token

# Usado pelo respawn/troca de fruta: aborta sem disparar nada.
func abortar() -> void:
	_carregando = false
	_slot = ""

# --------------------------------------------- começar a segurar a tecla
func comecar(slot_pedido: String) -> void:
	if _dono.is_suppressed:
		print("❌ Poderes desativados (Yami Yami).")
		return
	if _dono._skill_cooldowns.get(slot_pedido, 0.0) > 0.0:
		print("⏳ Habilidade [%s] em recarga! Aguarde %.1fs." % [
			slot_pedido, _dono._skill_cooldowns[slot_pedido]])
		return
	if slot_pedido != "Z" and _dono._yami_pistol_active:
		_dono.guardar_pistola_da_yami()
		print("🌑 Yami Pistol desativada (Outra habilidade foi acionada).")
	# BUKI BUKI: a tecla não lança golpe — ela EMPUNHA a arma daquele slot.
	if _dono._buki_ativa():
		_dono._buki_empunhar(slot_pedido)
		return

	var fruta: String = _dono.current_fruit_id
	var na_fruta: bool = _dono.combat_mode == "fruit"

	if slot_pedido == "C" and na_fruta and fruta == "yami_yami" and not _dono.is_on_floor():
		print("❌ Black Hole requer contato com o solo!")
		return
	if slot_pedido == "Z" and na_fruta and fruta == "yami_yami":
		print("🌑 Yami Pistol: ", "EMPUNHADA (Bt Dir=Mirar / Bt Esq=Atirar)"
			if _dono._disparo.alternar_yami() else "GUARDADA")
		return
	if slot_pedido == "C" and na_fruta and fruta == "yami_yami":
		_dono.set_meta("yami_black_hole_active", true)
		_carregando = true
		_slot = "C"
		_dono.congelar_para_cast()
		pedir_cast("C")
		return
	# Z RAJADA (Mera = balas de fogo; Hie = flechas de gelo) — começa ao
	# PRESSIONAR, não congela o corpo; para ao soltar ou ao acabar o pente.
	if slot_pedido == "Z" and na_fruta and (fruta == "mera_mera" or fruta == "hie_hie"):
		_dono.trigger_skill_cooldown("Z")
		_dono._disparo.iniciar_rajada()
		return
	if _dono.combat_mode == "style" and _dono.estilo_atual() == "teste_animacao":
		_dono.gastar_energia(_dono.ENERGY_SKILL)
		pedir_cast(slot_pedido)
		return

	if _carregando:
		return
	_carregando = true
	_slot = slot_pedido
	_dono.congelar_para_cast()
	_token += 1                          # cast novo: o timer do anterior não manda
	_dono.set_meta("is_casting", true)   # interrompível por dano
	_dono.pausar_animacao(true)

# ----------------------------------------------- soltar a tecla -> dispara
func soltar(slot_pedido: String) -> void:
	if _dono.combat_mode == "style" and _dono.estilo_atual() == "teste_animacao":
		return
	if slot_pedido == "C" and _dono.combat_mode == "fruit" and _dono.current_fruit_id == "yami_yami":
		if _dono.has_meta("yami_black_hole_active"):
			_dono.set_meta("yami_black_hole_active", false)
		_carregando = false
		_slot = ""
		return
	# MERA MERA Z: soltar a tecla ENCERRA a rajada.
	if _dono._disparo.rajada_ativa() and slot_pedido == "Z":
		_dono._disparo.parar_rajada()
		return
	if not _carregando or _slot != slot_pedido:
		return
	_carregando = false
	_dono.pausar_animacao(false)
	_dono.gastar_energia(_dono.ENERGY_SKILL)   # skill consome energia
	pedir_cast(slot_pedido)

# Disparo imediato, sem segurar (compat + atalhos).
func conjurar_direto(slot_pedido: String) -> void:
	if _dono.is_suppressed or _dono._skill_cooldowns.get(slot_pedido, 0.0) > 0.0:
		return
	if _dono._buki_ativa():
		_dono._buki_empunhar(slot_pedido)   # na Buki o slot empunha, não lança
		return
	pedir_cast(slot_pedido)

# ------------------------------------------------------- pedido ao servidor
# Calcula a mira e entrega ao Player, que fala com a rede.
func pedir_cast(slot_pedido: String) -> void:
	if not _dono._is_authority or _dono.is_suppressed:
		return
	if _dono._skill_cooldowns.get(slot_pedido, 0.0) > 0.0:
		return
	# ⚠️ BUKI BUKI: aqui o slot está sendo EMPUNHADO, não gasto. A recarga dele só
	# começa quando a arma é LARGADA (troca, desistência ou munição zerada). Ligar
	# o cooldown no saque poria em recarga a arma que acabou de ir para a mão.
	if not _dono._buki_ativa():
		_dono.trigger_skill_cooldown(slot_pedido)
	if slot_pedido != "Z" and _dono._yami_pistol_active:
		_dono.guardar_pistola_da_yami()

	var mira: Dictionary = _dono.mira_do_cast()

	# Camera Feel ao usar skill (V = ultimate: mais forte + slow-mo + flash).
	var ult := slot_pedido == "V"
	_dono.add_camera_shake(0.85 if ult else 0.6)
	_dono.pedir_soco_de_fov(8.0 if ult else 5.0)
	ScreenFX.chromatic_pulse(0.7 if ult else 0.35)
	if ult:
		_dono.get_tree().root.get_node("GameFlow").slow_mo()
		ScreenFX.flash(Color(1, 1, 1), 0.3)

	_dono.pedir_cast_no_servidor(slot_pedido, mira["aim"], mira["origem"])
