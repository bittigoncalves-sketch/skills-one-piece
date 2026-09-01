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
const CARREGAVEIS := {"goro_goro": ["V"], "gura_gura": ["X"], "mera_mera": ["V", "Z", "X", "C"], "bomu_bomu": ["Z", "X"]}

func montar_em(dono: Node) -> void:
	_dono = dono

# ------------------------------------------------------------------ leitura
func suprimido() -> bool:  return _suprimido
func tempo_de_silencio() -> float: return _suprimido_t
func carregando() -> bool: return _carregando
func carregando_skill() -> bool: return is_instance_valid(_carregado)

# Relógio da animação local da Mera Z. Mantê-lo no nó de carga garante que a
# pose, a barra e o instante de sacar terminem no mesmo quadro.
func progresso_mera_z() -> float:
	if _slot_carregado == "Z" and is_instance_valid(_carregado) and _carregado.has_method("progresso"):
		return _carregado.progresso()
	return 0.0

func progresso_mera_x() -> float:
	if _slot_carregado == "X" and is_instance_valid(_carregado) and _carregado.has_method("progresso"):
		return _carregado.progresso()
	return 0.0

func _e_carregavel(fruta: String, slot_pedido: String) -> bool:
	return CARREGAVEIS.has(fruta) and slot_pedido in CARREGAVEIS[fruta]

# A tecla foi desligada pelo ESTILO em uso? Só faz sentido no modo "style" — no
# modo fruta a tabela consultada é outra e todas as 4 teclas existem.
func _slot_desabilitado(slot_pedido: String) -> bool:
	if _dono.combat_mode == "fruit":
		var skills: Dictionary = SkillSystem.get_fruit_skills().get(_dono.current_fruit_id, {})
		return bool((skills.get(slot_pedido, {}) as Dictionary).get("desabilitado", false))
	if _dono.combat_mode != "style": return false
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

func limpar_silencio() -> void:
	_suprimido = false
	_suprimido_t = 0.0
	StatusFX.remover(_dono, StatusFX.SILENCIADO)

# Usado pelo respawn/troca de fruta: aborta sem disparar nada.
func abortar() -> void:
	_carregando = false
	_slot = ""
	# ⚠️ O NÓ DA CARGA FICAVA VIVO (corrigido em 2026-08-22). `abortar()` é o que o
	# respawn e a troca de fruta chamam, e ele zerava as duas flags sem tocar no
	# `_carregado` — então morrer no meio de um carregamento deixava o sol da
	# Mera, a orbe da Gura ou a nuvem do Mamaragan pendurados no mapa PARA SEMPRE,
	# com o jogador já vivo de novo do outro lado da arena. É metade do "a fruta
	# não desespawna as skills"; a outra metade eram os efeitos que nasciam fora
	# do contêiner (ver `FxUtil.mundo_de_skills`).
	#
	# `queue_free` e não `soltar`: abortar é CANCELAR. Quem quer soltar com a
	# carga que tem chama `liberar_por_dano()`, que é outra regra e é declarada.
	if is_instance_valid(_carregado):
		_carregado.queue_free()
	_carregado = null
	_slot_carregado = ""

# --------------------------------------------- começar a segurar a tecla
func comecar(slot_pedido: String) -> void:
	if _suprimido:
		print("❌ Poderes desativados (Yami Yami).")
		return
	if _dono.has_method("fruta_bloqueada_por_dano") and _dono.fruta_bloqueada_por_dano():
		print("💥 Fruta em recuperação após dano (%.1fs)." % _dono.get("_fruit_damage_lock_timer"))
		return
	# TECLA DESABILITADA PELO ESTILO. Vem antes da recarga de propósito: uma tecla
	# que não existe não deve nem reclamar de recarga. Lê a FLAG dos dados
	# (`FightingStyles.STYLES[...]["desabilitado"]`), não o nome do estilo — ver o
	# comentário do dicionário lá.
	if _slot_desabilitado(slot_pedido):
		print("🚫 Esta configuração não usa a tecla %s." % slot_pedido)
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
	if slot_pedido == "Z" and na_fruta and fruta == "suke_suke":
		if _dono.has_method("iniciar_invisibilidade"):
			_dono.iniciar_invisibilidade()
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
		elif fruta == "mera_mera" and slot_pedido == "Z":
			_carregado = MeraZChargeNode.new(self, _dono, slot_pedido, dano_c, spec_c)
			_dono.get_tree().current_scene.add_child(_carregado)
			_dono.add_camera_shake(0.2)
			_dono.set_meta("custom_pose", "mera_z_charge")
		elif fruta == "mera_mera" and (slot_pedido == "X" or slot_pedido == "C"):
			_carregado = MeraXChargeNode.new(self, _dono, slot_pedido, dano_c, spec_c)
			_dono.get_tree().current_scene.add_child(_carregado)
			_dono.add_camera_shake(0.3)
			if slot_pedido == "X":
				_dono.set_meta("custom_pose", "mera_x_charge")
		elif fruta == "bomu_bomu":
			_carregado = BomuFX.ChargeNode.new(_dono, slot_pedido, spec_c)
			_dono.get_tree().current_scene.add_child(_carregado)
			_dono.add_camera_shake(0.25)
			_dono.set_meta("custom_pose", "bomu_%s_charge" % slot_pedido.to_lower())
		else:
			# ⚠️ O MAMARAGAN (V da Goro) NÃO IA PARA A REDE (corrigido em 2026-08-22).
			#
			# Era o único carregável em que o nó local ERA o golpe: o
			# `MamaraganController.soltar()` lançava a bola ali mesmo e nunca
			# chamava `pedir_cast_no_servidor`. Consequências, as duas medidas:
			#   • NO CLIENTE — a bola e a `DamageZone` nasciam só do lado dele, e
			#     `DamageZone._on_body` sai cedo fora do servidor. O golpe gastava
			#     recarga (60 s) e energia e não feria ninguém. É o "V da Goro não
			#     atinge o servidor" do relato.
			#   • NO HOST — funcionava (local == autoritativo), mas os clientes não
			#     viam nada: nenhum `_net_play_cast` era emitido.
			#
			# Agora ele segue o mesmo desenho dos outros dois carregáveis: o nó
			# local é APENAS a carga (nuvens, orbe, jogador flutuando), e a soltura
			# pede o golpe ao servidor, que o reproduz em todos os peers.
			_carregado = MamaraganChargeNode.new(_dono, slot_pedido, dano_c, spec_c, mira_c)
			_dono.get_tree().current_scene.add_child(_carregado)
			_dono.add_camera_shake(0.85)
			_dono.pedir_soco_de_fov(8.0)
		_dono.pedir_soco_de_fov(8.0)
		return

	# Z RAJADA (Mera = balas de fogo; Hie = flechas de gelo) — começa ao
	# PRESSIONAR, não congela o corpo; para ao soltar ou ao acabar o pente.
	if slot_pedido == "Z" and na_fruta and (fruta == "hie_hie"):
		_dono.trigger_skill_cooldown("Z")
		# A rajada inteira é UMA conjuração: as 8 balas dividem o teto do slot Z
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
	if _dono.has_method("fruta_bloqueada_por_dano") and _dono.fruta_bloqueada_por_dano():
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
	if _dono.has_method("fruta_bloqueada_por_dano") and _dono.fruta_bloqueada_por_dano():
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

class MeraZChargeNode extends Node:
	var _cast_ctrl: CastController
	var _dono: Node
	var _slot: String
	var _dano: float
	var _tempo: float = 0.0
	var _spec: DamageSpec = null
	var _hand_fx: Array = []
	var _ui_canvas: CanvasLayer = null
	var _ui_bar: ProgressBar = null
	var _fired: bool = false

	func _init(cast_ctrl: CastController, dono: Node, slot: String, dano: float, spec: DamageSpec = null) -> void:
		_cast_ctrl = cast_ctrl
		_dono = dono
		_slot = slot
		_dano = dano
		_spec = spec

	func _ready() -> void:
		if is_instance_valid(_dono):
			# O saque começa na cintura. A pose `mera_z_charge` leva as mãos aos
			# coldres enquanto a barra enche; só no término as armas vão para a mira.
			if _dono.has_node("PlayerRig"):
				var rig := _dono.get_node("PlayerRig") as PlayerRig
				if rig:
					rig.guardar_pistolas_mera()
			var model := _dono.get("_char_model") as Node3D
			if is_instance_valid(model):
				var hand_r = model.find_child("*Hand_R*", true, false)
				var hand_l = model.find_child("*Hand_L*", true, false)
				var firefx = load("res://src/effects/FireFX.gd")
				var pm_r = firefx._flame_proc(Vector3.UP, 10.0, 0.5, 1.5, Vector3(0, 1.0, 0), 0.2, 0.5, 0.5)
				var pm_l = firefx._flame_proc(Vector3.UP, 10.0, 0.5, 1.5, Vector3(0, 1.0, 0), 0.2, 0.5, 0.5)

				var hand_blocks = [
					Vector3(0, 0, 0),       # palma
					Vector3(0, 0, -0.2),    # base do indicador
					Vector3(0, 0, -0.4),    # ponta do indicador
					Vector3(0, 0.2, 0)      # polegar para cima
				]
				var create_gun = func() -> MultiMeshInstance3D:
					var mmi = MultiMeshInstance3D.new()
					var mm = MultiMesh.new()
					mm.transform_format = MultiMesh.TRANSFORM_3D
					mm.instance_count = hand_blocks.size()
					var box = BoxMesh.new(); box.size = Vector3.ONE * 0.2
					mm.mesh = box
					for i in hand_blocks.size():
						mm.set_instance_transform(i, Transform3D(Basis(), hand_blocks[i]))
					mmi.multimesh = mm
					if firefx.has_method("_voxel_material"):
						mmi.material_override = firefx._voxel_material()
					return mmi

				if hand_r:
					var gun_r = create_gun.call()
					hand_r.add_child(gun_r)
					_hand_fx.append(gun_r)
					var fx_r = FxUtil.particles(20, 0.5, false, pm_r, FxUtil.grain(0.3))
					hand_r.add_child(fx_r)
					_hand_fx.append(fx_r)
				if hand_l:
					var gun_l = create_gun.call()
					hand_l.add_child(gun_l)
					_hand_fx.append(gun_l)
					var fx_l = FxUtil.particles(20, 0.5, false, pm_l, FxUtil.grain(0.3))
					hand_l.add_child(fx_l)
					_hand_fx.append(fx_l)

			_ui_canvas = CanvasLayer.new()
			var margin = MarginContainer.new()
			margin.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
			margin.offset_bottom = -200
			margin.offset_top = -220
			margin.offset_left = -150
			margin.offset_right = 150
			_ui_bar = ProgressBar.new()
			_ui_bar.max_value = _tempo_maximo()
			_ui_bar.value = 0.0
			_ui_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.1, 0.1, 0.1, 0.8)
			_ui_bar.add_theme_stylebox_override("background", sb)
			var sbf = StyleBoxFlat.new()
			sbf.bg_color = Color(1.0, 0.5, 0.1)
			_ui_bar.add_theme_stylebox_override("fill", sbf)
			margin.add_child(_ui_bar)
			_ui_canvas.add_child(margin)
			_dono.get_tree().current_scene.add_child(_ui_canvas)

	func _process(delta: float) -> void:
		if _fired:
			return
		_tempo = minf(_tempo + delta, _tempo_maximo())
		if is_instance_valid(_dono) and _dono.has_method("add_camera_shake"):
			_dono.add_camera_shake(minf(_tempo * 0.2, 0.5))
		if is_instance_valid(_ui_bar):
			_ui_bar.value = _tempo

		if _tempo >= _tempo_maximo() and is_instance_valid(_cast_ctrl):
			_fired = true
			_cast_ctrl._liberar_carregado()

	func progresso() -> float:
		return _tempo / _tempo_maximo()

	func _tempo_maximo() -> float:
		return _spec.tempo_de_carga if _spec != null and _spec.tempo_de_carga > 0.0 else 1.0

	func _exit_tree() -> void:
		for fx in _hand_fx:
			if is_instance_valid(fx):
				fx.queue_free()
		if is_instance_valid(_ui_canvas):
			_ui_canvas.queue_free()
		# Sem esta limpeza a pose de saque ficava gravada para sempre no Player:
		# o primeiro Z terminava, mas todo golpe seguinte continuava no estado
		# `mera_z_charge` e parecia travado.
		if is_instance_valid(_dono) and _dono.has_meta("custom_pose") and _dono.get_meta("custom_pose") == "mera_z_charge":
			_dono.remove_meta("custom_pose")
		# Carga abortada (morte, troca de fruta ou soltura antes de 100%): não
		# deixa armas fantasmas presas na cintura.
		if not _fired and is_instance_valid(_dono) and _dono.has_node("PlayerRig"):
			var rig := _dono.get_node("PlayerRig") as PlayerRig
			if rig:
				rig.esconder_pistolas_mera()

	func soltar(aim: Vector3) -> void:
		if is_instance_valid(_dono):
			if _tempo >= _tempo_maximo():
				# A barra acabou: transfere as duas armas para as mãos ANTES do
				# pedido de cast, então o primeiro tiro já sai da posição visível.
				if _dono.has_node("PlayerRig"):
					var rig := _dono.get_node("PlayerRig") as PlayerRig
					if rig:
						rig.empunhar_pistolas_mera()
						# Só guarda depois do último tiro: a duração acompanha a cadência
						# declarada pela própria rajada, sem um número mágico desatualizado.
						var holster_timer := _dono.get_tree().create_timer(
							DisparoSustentado.MAX_BALAS * DisparoSustentado.INTERVALO + 0.15)
						holster_timer.timeout.connect(func():
							if is_instance_valid(rig):
								rig.esconder_pistolas_mera())
				if _dono.has_method("pedir_soco_de_fov"):
					_dono.pedir_soco_de_fov(3.0)
				# O Z carregado não lança um VFX separado: ele liga a rajada real do
				# Player. Assim cada tiro sai do cano visível, alterna as mãos, recebe
				# coice e usa o canal servidor-autoritativo de balas.
				_dono.encerrar_disparo()
				_dono._disparo.iniciar_rajada()
			else:
				print("Mera Z cancelado: carga insuficiente (< %.2fs)." % _tempo_maximo())
		queue_free()

class MeraXChargeNode extends Node:
	var _cast_ctrl: CastController
	var _dono: Node
	var _slot: String
	var _dano: float
	var _tempo: float = 0.0
	var _spec: DamageSpec = null
	var _hand_fx: Array = []
	var _ui_canvas: CanvasLayer = null
	var _ui_bar: ProgressBar = null
	var _fired: bool = false

	func _init(cast_ctrl: CastController, dono: Node, slot: String, dano: float, spec: DamageSpec = null) -> void:
		_cast_ctrl = cast_ctrl
		_dono = dono
		_slot = slot
		_dano = dano
		_spec = spec

	func _ready() -> void:
		if is_instance_valid(_dono):
			if _dono.has_node("_char_model"):
				var model = _dono.get_node("_char_model")
				var hand_r = model.find_child("*Hand_R*", true, false)
				var firefx = load("res://src/effects/FireFX.gd")
				var pm_r = firefx._flame_proc(Vector3.UP, 15.0, 1.0, 2.5, Vector3(0, 1.0, 0), 0.5, 1.0, 1.0)
				if hand_r:
					var fx_r = FxUtil.particles(40, 0.5, false, pm_r, FxUtil.grain(0.5))
					hand_r.add_child(fx_r)
					_hand_fx.append(fx_r)

			_ui_canvas = CanvasLayer.new()
			var margin = MarginContainer.new()
			margin.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
			margin.offset_bottom = -200
			margin.offset_top = -220
			margin.offset_left = -150
			margin.offset_right = 150
			_ui_bar = ProgressBar.new()
			_ui_bar.max_value = _tempo_maximo()
			_ui_bar.value = 0.0
			_ui_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var sb = StyleBoxFlat.new()
			sb.bg_color = Color(0.1, 0.1, 0.1, 0.8)
			_ui_bar.add_theme_stylebox_override("background", sb)
			var sbf = StyleBoxFlat.new()
			sbf.bg_color = Color(1.0, 0.2, 0.0) # Vermelho intenso
			_ui_bar.add_theme_stylebox_override("fill", sbf)
			margin.add_child(_ui_bar)
			_ui_canvas.add_child(margin)
			_dono.get_tree().current_scene.add_child(_ui_canvas)

	func _process(delta: float) -> void:
		if _fired:
			return
		_tempo = minf(_tempo + delta, _tempo_maximo())
		if is_instance_valid(_dono) and _dono.has_method("add_camera_shake"):
			_dono.add_camera_shake(minf(_tempo * 0.3, 1.0))
		if is_instance_valid(_ui_bar):
			_ui_bar.value = _tempo

		if _tempo >= _tempo_maximo() and is_instance_valid(_cast_ctrl):
			_fired = true
			_cast_ctrl._liberar_carregado()

	func progresso() -> float:
		return _tempo / _tempo_maximo()

	func _tempo_maximo() -> float:
		return _spec.tempo_de_carga if _spec != null and _spec.tempo_de_carga > 0.0 else 1.5

	func _exit_tree() -> void:
		for fx in _hand_fx:
			if is_instance_valid(fx):
				fx.queue_free()
		if is_instance_valid(_ui_canvas):
			_ui_canvas.queue_free()
		if is_instance_valid(_dono) and _dono.has_meta("custom_pose") and _dono.get_meta("custom_pose") == "mera_x_charge":
			_dono.remove_meta("custom_pose")

	func soltar(aim: Vector3) -> void:
		if is_instance_valid(_dono):
			if _tempo >= _tempo_maximo():
				if _dono.has_method("pedir_soco_de_fov"):
					_dono.pedir_soco_de_fov(5.0)
				var mira := _dono.mira_do_cast() as Dictionary
				_dono.pedir_cast_no_servidor(_slot, aim, mira["origem"], _tempo_maximo())
			else:
				print("Mera X cancelado: carga insuficiente (< %.1fs)." % _tempo_maximo())
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

# ============================================================================
#  MAMARAGAN (V da Goro Goro) — a CARGA, não o golpe.
# ============================================================================
#
#  Existe desde 2026-08-22 para pôr o V da Goro no mesmo desenho dos outros dois
#  carregáveis. Antes, `mamaragan_carregado()` devolvia o EFEITO INTEIRO já
#  vivo, e a soltura dele lançava a bola localmente — o servidor nunca ficava
#  sabendo. Ver o comentário no `comecar()`.
#
#  O `MamaraganController` continua sendo quem desenha a carga (nuvens, correntes,
#  a orbe crescendo, o jogador flutuando): é bom e não foi reescrito. O que mudou
#  é quem termina o golpe — agora é a rede, como no `MeraChargeNode`.
class MamaraganChargeNode extends Node:
	var _dono: Node
	var _slot: String
	var _spec: DamageSpec = null
	var _ctrl: Node = null          # o MamaraganController local (só a carga)

	# ⚠️ `segurando` também faz parte do contrato herdado do `MamaraganController`
	# (o `test_charge_up.gd` lê os dois). Aqui é DERIVADO do controlador em vez de
	# duplicado: dois donos do mesmo estado é como se descobre, meses depois, que
	# um deles nunca foi atualizado.
	var segurando: bool:
		get: return is_instance_valid(_ctrl) and bool(_ctrl.get("segurando"))

	func _init(dono: Node, slot: String, dano: float, spec: DamageSpec, mira: Dictionary) -> void:
		_dono = dono
		_slot = slot
		_spec = spec
		if is_instance_valid(_dono):
			_ctrl = GoroFXGrande.mamaragan_carregado(
				_dono.get_tree().current_scene, mira["origem"], mira["aim"], dano, _dono, spec)

	# Quanto de carga já subiu, em 0..1. O controlador é quem sabe — a linha do
	# tempo dele (`T_ORB`, `T_CARGA`) é que faz a orbe crescer na tela, e usar
	# outro relógio aqui faria o dano discordar do que o jogador está vendo.
	#
	# ⚠️ O NOME É `carga_atual`, e não `carga`, de propósito: é a API que o
	# `MamaraganController` já expunha e que o `test_charge_up.gd` lê. Este nó
	# entrou na frente dele como o que o `CastController` segura, então herda o
	# contrato — trocar o nome quebraria o teste sem ganho nenhum.
	func carga_atual() -> float:
		if is_instance_valid(_ctrl) and _ctrl.has_method("carga_atual"):
			return float(_ctrl.carga_atual())
		return 0.0

	# O golpe só pode sair depois de a orbe existir — repassa a regra do controlador.
	func pode_soltar() -> bool:
		return is_instance_valid(_ctrl) and _ctrl.has_method("pode_soltar") and _ctrl.pode_soltar()

	func _exit_tree() -> void:
		if is_instance_valid(_ctrl):
			_ctrl.queue_free()

	func soltar(aim: Vector3) -> void:
		if is_instance_valid(_dono):
			if _dono.has_method("pedir_soco_de_fov"):
				_dono.pedir_soco_de_fov(5.0)
			var mira := _dono.mira_do_cast() as Dictionary
			# `carga()` ANTES de destruir o controlador — ele é quem guarda o tempo.
			var t := carga_atual()
			if is_instance_valid(_ctrl):
				_ctrl.queue_free()   # a carga local sai; o golpe vem pela rede
				_ctrl = null
			# `pedir_cast_no_servidor` converte em `_net_play_cast`, que roda em
			# TODOS os peers — inclusive neste. A carga viaja em SEGUNDOS, como
			# nas outras duas skills, porque é isso que `DamageSpec.valor_do_hit`
			# espera; `carga_atual()` devolve 0..1.
			var tempo_de_carga: float = _spec.tempo_de_carga if _spec != null else 3.0
			_dono.pedir_cast_no_servidor(_slot, aim, mira["origem"], t * tempo_de_carga)
		queue_free()
