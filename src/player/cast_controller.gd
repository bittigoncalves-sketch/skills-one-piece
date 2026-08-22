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

# SILÊNCIO (Yami Yami): enquanto vale, nenhuma habilidade sai. É estado do
# domínio de HABILIDADES — quem o liga é um golpe, e quem o consulta são os
# portões de cast. Por isso mora aqui, e não no Player.
var _suprimido: bool = false
var _suprimido_t: float = 0.0

var _carregando: bool = false   # segurando a tecla, mirando
var _slot: String = ""          # qual slot está sendo carregado
# Identidade do cast atual. Serve para o timer de um cast antigo não mandar no
# cast novo quando o jogador solta e aperta de novo rápido.
var _token: int = 0

# --------------------------------------------------- CHARGE-UP / CHARGED SKILL
# Mecânica nova (tarefa 5, 2026-08-12). O que a torna diferente de TODAS as
# outras skills, e por que ela precisa de estado próprio:
#
#   • a execução 3D começa no CLIQUE, não na soltura;
#   • enquanto a tecla fica pressionada a skill CRESCE;
#   • soltar dispara com a carga que houver;
#   • levar dano TAMBÉM dispara, com a carga que houver — ao contrário das
#     outras, que o dano CANCELA. Decisão do dono; ver docs/PEDIDO_2026-08-12.md.
#
# Guardo o efeito vivo aqui porque quem sabe a hora de soltar é o input, e quem
# sabe a direção é a mira do INSTANTE da soltura.
var _carregado: Node = null
var _slot_carregado := ""

# Quais golpes são carregáveis. Tabela em vez de `if` espalhado: quando a
# segunda skill carregável existir, é uma linha.
const CARREGAVEIS := {"goro_goro": ["V"], "gura_gura": ["X"], "mera_mera": ["V"]}

func montar_em(dono: Node) -> void:
	_dono = dono

# ------------------------------------------------------------------ leitura
func suprimido() -> bool:  return _suprimido
func tempo_de_silencio() -> float: return _suprimido_t
func carregando() -> bool: return _carregando
func carregando_skill() -> bool: return is_instance_valid(_carregado)

func _e_carregavel(fruta: String, slot_pedido: String) -> bool:
	return CARREGAVEIS.has(fruta) and slot_pedido in CARREGAVEIS[fruta]

# A tecla foi desligada pelo ESTILO em uso? Só faz sentido no modo "style" — no
# modo fruta a tabela consultada é outra e todas as 4 teclas existem.
func _slot_desabilitado(slot_pedido: String) -> bool:
	if _dono.combat_mode != "style":
		return false
	var estilo: String = _dono.estilo_atual()
	if not FightingStyles.STYLES.has(estilo):
		return false
	var skills: Dictionary = FightingStyles.STYLES[estilo].get("skills", {})
	if not skills.has(slot_pedido):
		return true          # slot que o estilo nem declara também não sai
	return bool((skills[slot_pedido] as Dictionary).get("desabilitado", false))
func slot() -> String:     return _slot
func token() -> int:       return _token

# SILENCIAR por um tempo. O maior pedido não vence de propósito: o golpe mais
# recente é quem manda, como no comportamento original.
func suprimir(duracao: float) -> void:
	_suprimido = true
	_suprimido_t = duracao
	StatusFX.aplicar(_dono, StatusFX.SILENCIADO, duracao)   # aparece no canto da tela
	print("🚫 PODERES DESATIVADOS POR YAMI YAMI! Tempo restante: ", duracao, "s")

func tick_silencio(delta: float) -> void:
	if not _suprimido:
		return
	_suprimido_t -= delta
	if _suprimido_t <= 0.0:
		_suprimido = false
		print("✨ Poderes reativados!")

# Usado pelo respawn/troca de fruta: aborta sem disparar nada.
func abortar() -> void:
	_carregando = false
	_slot = ""

# --------------------------------------------- começar a segurar a tecla
func comecar(slot_pedido: String) -> void:
	if _suprimido:
		print("❌ Poderes desativados (Yami Yami).")
		return
	# TECLA DESABILITADA PELO ESTILO. Vem antes da recarga de propósito: uma tecla
	# que não existe não deve nem reclamar de recarga. Lê a FLAG dos dados
	# (`FightingStyles.STYLES[...]["desabilitado"]`), não o nome do estilo — ver o
	# comentário do dicionário lá.
	if _slot_desabilitado(slot_pedido):
		print("🚫 O estilo %s não usa a tecla %s." % [_dono.estilo_atual(), slot_pedido])
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

	if slot_pedido == "Z" and na_fruta and fruta == "yami_yami":
		print("🌑 Yami Pistol: ", "EMPUNHADA (Bt Dir=Mirar / Bt Esq=Atirar)"
			if _dono._disparo.alternar_yami() else "GUARDADA")
		return
	if (slot_pedido == "C" or slot_pedido == "X") and na_fruta and fruta == "yami_yami":
		if slot_pedido == "C":
			if not _dono.is_on_floor():
				print("❌ Black Hole requer contato com o solo!")
				return
		if _dono.has_method("pedir_iniciar_hold"):
			_dono.pedir_iniciar_hold(slot_pedido, fruta)
		_carregando = true
		_slot = slot_pedido
		_token += 1
		_dono.set_meta("is_casting", true)
		_dono.congelar_para_cast()
		pedir_cast(slot_pedido)
		return
	if slot_pedido == "C" and na_fruta and fruta == "bara_bara":
		if _dono.has_method("pedir_iniciar_hold"):
			_dono.pedir_iniciar_hold(slot_pedido, fruta)
		_carregando = true
		_slot = slot_pedido
		_token += 1
		_dono.set_meta("is_casting", true)
		pedir_cast(slot_pedido)
		return
	# EL THOR (X da Goro): o raio que sobe do BRAÇO é o GATILHO da reação
	if slot_pedido == "X" and na_fruta and fruta == "goro_goro":
		GoroFXGrande.gatilho_do_braco(_dono.get_tree().current_scene, _dono)
		
	# GURA GURA Z (INVESTIDA FÍSICA): Inicia imediatamente o estado de Rush do jogador
	if slot_pedido == "Z" and na_fruta and fruta == "gura_gura":
		var mira_c: Dictionary = _dono.mira_do_cast()
		if _dono.has_method("start_gura_rush"):
			_dono.start_gura_rush(mira_c["aim"])
		return

	# CHARGE-UP: a skill NASCE AGORA e cresce enquanto a tecla estiver segurada.
	# A recarga e a energia são cobradas no aperto, senão dava para "espiar" o
	# golpe de graça começando e cancelando.
	if _e_carregavel(fruta, slot_pedido):
		_carregando = true
		_slot = slot_pedido
		_slot_carregado = slot_pedido
		_token += 1
		_dono.set_meta("is_casting", true)
		_dono.trigger_skill_cooldown(slot_pedido)
		_dono.gastar_energia(_dono.ENERGY_SKILL)
		var mira_c: Dictionary = _dono.mira_do_cast()
		# ⚠️ A spec nasce AQUI, no aperto, e não na soltura. Duas razões:
		#   • o efeito 3D do charge-up já existe enquanto a tecla está segurada
		#     (o sol da Mera, a orbe da Gura), e ele precisa dos números;
		#   • a conjuração tem de ser a MESMA do começo ao fim, senão o golpe
		#     soltaria com um orçamento diferente do que começou.
		# `tempo_de_carga` da tabela é quem define a carga cheia — as três skills
		# carregáveis tinham três curvas diferentes antes disto.
		var spec_c := Balance.novo(fruta, slot_pedido)
		if spec_c == null:
			spec_c = DamageSpec.avulso(0.0)
		var dano_c: float = spec_c.dano
		# Carrega a skill X (Captura Sísmica)
		_dono.congelar_para_cast() # Exige concentração e congela

		if fruta == "gura_gura" and slot_pedido == "X":
			_carregado = GuraChargeNode.new(_dono, slot_pedido, spec_c)
			_dono.get_tree().current_scene.add_child(_carregado)
			_dono.add_camera_shake(0.3)
			_dono.set_meta("custom_pose", "gura_x_charge")
		elif fruta == "mera_mera" and slot_pedido == "V":
			_carregado = MeraChargeNode.new(_dono, slot_pedido, dano_c, spec_c)
			_dono.get_tree().current_scene.add_child(_carregado)
			_dono.add_camera_shake(0.5)
			_dono.set_meta("custom_pose", "mera_v_charge")
		else:
			_carregado = GoroFXGrande.mamaragan_carregado(
				_dono.get_tree().current_scene, mira_c["origem"], mira_c["aim"], dano_c, _dono, spec_c)
			_dono.add_camera_shake(0.85)
			_dono.pedir_soco_de_fov(8.0)
		_dono.pedir_soco_de_fov(8.0)
		return

	# Z RAJADA (Mera = balas de fogo; Hie = flechas de gelo) — começa ao
	# PRESSIONAR, não congela o corpo; para ao soltar ou ao acabar o pente.
	if slot_pedido == "Z" and na_fruta and (fruta == "mera_mera" or fruta == "hie_hie"):
		_dono.trigger_skill_cooldown("Z")
		# A rajada inteira é UMA conjuração: as 16 balas dividem o teto do slot Z
		# (200). Encerrar aqui abre uma conjuração nova a cada aperto de tecla —
		# sem isto, a segunda rajada nasceria com o orçamento da primeira gasto.
		_dono.encerrar_disparo()
		_dono._disparo.iniciar_rajada()
		return
		
	# GOMU GOMU GATLING (C): inicia a rajada imediatamente ao pressionar.
	#
	# ⚠️ NÃO chame `trigger_skill_cooldown("C")` aqui: `pedir_cast()`, chamado
	# duas linhas abaixo, JÁ coloca a recarga — e ele também É O GATE que lê
	# essa mesma recarga (`if _skill_cooldowns.get(slot, 0.0) > 0.0: return`,
	# bem no início da função). Chamar aqui primeiro travava a skill contra
	# ela mesma: a recarga entrava em 10s e, no MESMO quadro, `pedir_cast`
	# via a recarga > 0 e desistia sem nunca chegar a `pedir_cast_no_servidor`
	# — o Gatling nunca nascia, nem segurando a tecla pelos 2,2s inteiros
	# (medido em 2026-08-18 com `tools/dev_tests/probe_gomu_c.gd`).
	if slot_pedido == "C" and na_fruta and fruta == "gomu_gomu":
		_dono.gastar_energia(_dono.ENERGY_SKILL)
		pedir_cast("C")
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
	# CHARGE-UP: soltar dispara na mira DE AGORA, com a carga que houver.
	if is_instance_valid(_carregado) and slot_pedido == _slot_carregado:
		_liberar_carregado()
		return

	if _dono.combat_mode == "style" and _dono.estilo_atual() == "teste_animacao":
		return
	if (slot_pedido == "C" or slot_pedido == "X") and _dono.combat_mode == "fruit" and _dono.current_fruit_id == "yami_yami":
		if slot_pedido == "C":
			if _dono.has_meta("yami_black_hole_active"):
				_dono.set_meta("yami_black_hole_active", false)
		else:
			if _dono.has_meta("yami_kurouzu_active"):
				_dono.set_meta("yami_kurouzu_active", false)
		if _dono.has_method("pedir_cancelar_hold"):
			_dono.pedir_cancelar_hold(slot_pedido, "yami_yami")
		_carregando = false
		_slot = ""
		_dono.set_meta("is_casting", false)
		return
	if slot_pedido == "C" and _dono.combat_mode == "fruit" and _dono.current_fruit_id == "bara_bara":
		if _dono.has_meta("bara_cleave_active"):
			_dono.set_meta("bara_cleave_active", false)
		if _dono.has_method("pedir_cancelar_hold"):
			_dono.pedir_cancelar_hold(slot_pedido, "bara_bara")
		_carregando = false
		_slot = ""
		_dono.set_meta("is_casting", false)
		return
	# MERA MERA Z: soltar a tecla ENCERRA a rajada.
	if _dono._disparo.rajada_ativa() and slot_pedido == "Z":
		_dono._disparo.parar_rajada()
		return
		
	# GOMU GOMU GATLING: soltar a tecla cancela a metralhadora no meio.
	if slot_pedido == "C" and _dono.combat_mode == "fruit" and _dono.current_fruit_id == "gomu_gomu":
		if _dono.has_method("abort_gatling"):
			_dono.abort_gatling()
		return
	if not _carregando or _slot != slot_pedido:
		return
	_carregando = false
	_dono.pausar_animacao(false)
	_dono.gastar_energia(_dono.ENERGY_SKILL)   # skill consome energia
	pedir_cast(slot_pedido)

# Solta o golpe carregado na direção da mira ATUAL.
func _liberar_carregado() -> void:
	if not is_instance_valid(_carregado):
		_carregado = null
		_slot_carregado = ""
		_carregando = false
		return
	var mira: Dictionary = _dono.mira_do_cast()
	if _carregado.has_method("soltar"):
		_carregado.soltar(mira["aim"])
	_carregado = null
	_slot_carregado = ""
	_carregando = false
	_slot = ""
	_dono.set_meta("is_casting", false)

# ⚠️ DANO TAMBÉM LIBERA — e isso é o OPOSTO do que o `interrupt_casting` faz com
# todas as outras skills, que são canceladas. Decisão do dono: "libera com a
# carga que tiver". Chamado do `Player.take_damage`.
func liberar_por_dano() -> void:
	if is_instance_valid(_carregado):
		print("⚡ Charge-up interrompido por dano — sai com a carga que tem.")
		_liberar_carregado()

# Disparo imediato, sem segurar (compat + atalhos).
func conjurar_direto(slot_pedido: String) -> void:
	if _suprimido or _dono._skill_cooldowns.get(slot_pedido, 0.0) > 0.0:
		return
	if _dono._buki_ativa():
		_dono._buki_empunhar(slot_pedido)   # na Buki o slot empunha, não lança
		return
	pedir_cast(slot_pedido)

# ------------------------------------------------------- pedido ao servidor
# Calcula a mira e entrega ao Player, que fala com a rede.
func pedir_cast(slot_pedido: String) -> void:
	if not _dono._is_authority or _suprimido:
		_dono.set_meta("is_casting", false)
		return
	if _dono.combat_mode == "fruit":
		var fid = _dono.current_fruit_id
		if fid == "" or fid == "sem_fruta":
			_dono.set_meta("is_casting", false)
			return
	if _dono._skill_cooldowns.get(slot_pedido, 0.0) > 0.0:
		_dono.set_meta("is_casting", false)
		return
	if slot_pedido == "V" and _dono.current_fruit_id == "bara_bara" and _dono.get_meta("bara_v_active", false):
		_dono.set_meta("is_casting", false)
		return
	# ⚠️ BUKI BUKI: aqui o slot está sendo EMPUNHADO, não gasto. A recarga dele só
	# começa quando a arma é LARGADA (troca, desistência ou munição zerada). Ligar
	# o cooldown no saque poria em recarga a arma que acabou de ir para a mão.
	if not _dono._buki_ativa():
		var eh_bara_v = (slot_pedido == "V" and _dono.current_fruit_id == "bara_bara")
		if not eh_bara_v:
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

class GuraChargeNode extends Node:
	var _dono: Node
	var _slot: String
	var _tempo: float = 0.0
	var _orb: Node3D = null
	# A spec da carga. Aqui ela serve só para o TETO do tempo de carga
	# (`tempo_de_carga`); quem cria a hitbox é o `_fire_skill` do lado do
	# servidor, na soltura, com a spec dele.
	var _spec: DamageSpec = null

	func _init(dono: Node, slot: String, spec: DamageSpec = null) -> void:
		_dono = dono
		_slot = slot
		_spec = spec
		if _slot == "X":
			# Cria a orb visual na mão do jogador
			if _dono.has_node("_char_model"):
				var model: Node = _dono.get_node("_char_model")
				var arm: Node = model.find_child("*ForeArm_R*", true, false)
				if arm and arm is Node3D:
					_orb = load("res://src/effects/SeismicOrb.gd").new()
					arm.add_child(_orb)
					_orb.position = Vector3(0, -0.3, 0) # Offset para a ponta do braço
				
	func _process(delta: float) -> void:
		# O teto da carga vem da tabela (`tempo_de_carga`), não de um `3.0`
		# escrito aqui: é ele que define onde a interpolação 192 -> 256 chega ao fim.
		var maximo: float = _spec.tempo_de_carga if _spec != null and _spec.tempo_de_carga > 0.0 else 3.0
		_tempo = minf(_tempo + delta, maximo)

		if is_instance_valid(_dono) and _dono.has_method("add_camera_shake"):
			_dono.add_camera_shake(minf(_tempo * 0.8, 2.5))
			
		if is_instance_valid(_orb):
			_orb.charge = _tempo
			
	func _exit_tree() -> void:
		if is_instance_valid(_dono) and _dono.has_meta("custom_pose") and _dono.get_meta("custom_pose") == "gura_x_charge":
			_dono.remove_meta("custom_pose")
		if is_instance_valid(_orb):
			_orb.queue_free()
			
	func soltar(aim: Vector3) -> void:
		if is_instance_valid(_dono):
			if _dono.has_method("pedir_soco_de_fov"):
				_dono.pedir_soco_de_fov(5.0)
			if Engine.has_singleton("ScreenFX"):
				Engine.get_singleton("ScreenFX").chromatic_pulse(0.4)
				
			var mira := _dono.mira_do_cast() as Dictionary
			
			if _slot == "X":
				# O aim que chega é a direção, e o servidor vai processar como projétil
				# Passamos origin + aim como 'target pos' para direcionar o projétil
				_dono.pedir_cast_no_servidor(_slot, mira["origem"] + aim * 100.0, mira["origem"], _tempo)
			else:
				_dono.pedir_cast_no_servidor(_slot, aim, mira["origem"], _tempo)
		queue_free()

class MeraChargeNode extends Node:
	var _dono: Node
	var _slot: String
	var _dano: float
	var _tempo: float = 0.0
	var _sun_ctrl: Node = null
	# Ver a nota em `GuraChargeNode._spec`: aqui o sol é VISUAL — na soltura ele
	# é destruído e o servidor instancia um sol sincronizado com a spec do cast.
	var _spec: DamageSpec = null

	func _init(dono: Node, slot: String, dano: float, spec: DamageSpec = null) -> void:
		_dono = dono
		_slot = slot
		_dano = dano
		_spec = spec

	func _ready() -> void:
		if is_instance_valid(_dono):
			# Instancia o controle do Sol sobre a cabeça do jogador
			var firefxgrande = load("res://src/effects/FireFXGrande.gd")
			_sun_ctrl = firefxgrande.EnteiSunController.new(_dono, _dono.global_position, Vector3(0,0,-1), _dano, _spec)
			_dono.get_tree().current_scene.add_child(_sun_ctrl)
			# Chamamos um novo método setup_charge() em EnteiSunController
			if _sun_ctrl.has_method("setup_charge"):
				_sun_ctrl.setup_charge()
			
	func _process(delta: float) -> void:
		# Mesmo motivo do `GuraChargeNode`: o teto da carga é da tabela.
		var maximo: float = _spec.tempo_de_carga if _spec != null and _spec.tempo_de_carga > 0.0 else 3.5
		_tempo = minf(_tempo + delta, maximo)

		if is_instance_valid(_dono) and _dono.has_method("add_camera_shake"):
			_dono.add_camera_shake(minf(_tempo * 0.5, 1.5))
			
		if is_instance_valid(_sun_ctrl) and _sun_ctrl.has_method("update_charge"):
			_sun_ctrl.update_charge(_tempo)
			
	func _exit_tree() -> void:
		if is_instance_valid(_dono) and _dono.has_meta("custom_pose") and _dono.get_meta("custom_pose") == "mera_v_charge":
			_dono.remove_meta("custom_pose")
		# Se soltou e _sun_ctrl ainda existe, nós o destruimos, pois
		# soltar() deveria ter lançado ele e transferido o controle.
		if is_instance_valid(_sun_ctrl) and not _sun_ctrl.get_meta("fired", false):
			_sun_ctrl.queue_free()
			
	func soltar(aim: Vector3) -> void:
		if is_instance_valid(_dono):
			if _dono.has_method("pedir_soco_de_fov"):
				_dono.pedir_soco_de_fov(5.0)
			if Engine.has_singleton("ScreenFX"):
				Engine.get_singleton("ScreenFX").chromatic_pulse(0.5)
				
			var mira := _dono.mira_do_cast() as Dictionary
			
			if is_instance_valid(_sun_ctrl):
				# Destrói o sol local, pois o _net_play_cast vai instanciar
				# um novo sol sincronizado e dispará-lo imediatamente para todos.
				_sun_ctrl.queue_free()
				
			# Manda pro servidor que foi castado, com o tempo como modificador
			# Isso fará o servidor instanciar a zona de dano
			_dono.pedir_cast_no_servidor(_slot, aim, mira["origem"], _tempo)
		queue_free()
