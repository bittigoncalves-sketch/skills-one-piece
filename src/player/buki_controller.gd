class_name BukiController
extends RefCounted
# ============================================================================
#  BUKI BUKI NO MI — o arsenal: sacar, mirar, atirar, guardar.
#
#  Fase 5 de docs/ARQUITETURA_PLAYER.md. A PRIMEIRA fase que encosta em RPC.
#
#  ------------------------------------------- POR QUE ISTO É `RefCounted`
#  O plano previa avaliar se o componente viraria NÓ FILHO, levando os 4 `@rpc`
#  da Buki junto. A auditoria testou isso com host e cliente ENet de verdade:
#  **funciona** — o RPC chega e o broadcast volta. Mesmo assim ficou de fora, e
#  a razão não é medo:
#
#    O TIRO DA BUKI NÃO TEM RPC PRÓPRIO. Ele pega emprestado o canal de bala
#    compartilhado com a rajada Z da Mera/Hie e com a pistola da Yami
#    (`_net_bullet_req` -> `_do_server_bullet` -> `_net_bullet_play`), e é
#    DENTRO desse canal compartilhado que mora a autorização de munição.
#
#  Levar só `sacar`/`guardar` para um nó filho partiria o protocolo da Buki em
#  dois caminhos de rede, por ganho zero. Levar o canal de bala junto arrastaria
#  a Fase 6 (`SkillController`) para dentro da Fase 5 — o oposto de escopo
#  fechado.
#
#  **Gatilho para virar nó:** se a Buki ganhar canal de bala próprio, OU se
#  `_buki_visual` precisar de `MultiplayerSynchronizer` (hoje quem entra no meio
#  da partida não vê a arma na mão do adversário — a sincronia é por evento).
#  Nesse dia o `add_child` tem que ser feito em `Main._spawn_player_data`
#  **antes** do `set_multiplayer_authority`, que é recursivo.
#
#  ⚠️ **A autoridade NÃO desce para componentes criados no `_ready()`.** Medido:
#  pai=7, filho=1. `Main.gd:104-105` define a autoridade antes de o Player entrar
#  na árvore. Por isso este componente NUNCA chama `is_multiplayer_authority()`:
#  ele recebe a resposta de quem sabe.
#
#  ---------------------------------------------------------------- FRONTEIRA
#  Ele é dono do estado do arsenal. O que é do Player continua do Player, e é
#  pedido, não escrito:
#
#    `_dono.pedir_recuo(...)`        em vez de mexer em `_kb_impulso`/`velocity`
#    `_dono.mirar_suave_para(...)`   em vez de escrever `_yaw`/`_pitch`
#    `_dono.pedir_coice_de_arma()`   em vez de escrever `_gun_recoil`
#    `_dono.add_camera_shake(...)`   já era pedido desde a Fase 2
#
#  Os 4 `@rpc` e o encanamento de rede ficam no Player: RPC se resolve por
#  CAMINHO DE NÓ, então mover o método mudaria o protocolo. O que se moveu foi
#  o ESTADO e a REGRA; a tubulação ficou.
# ============================================================================

var _dono: Node = null
# O rig CONSTRÓI as armas (Fase 3); a Buki decide QUAL aparece. Referência
# direta entre componentes, com motivo: era o conflito de dois donos que o
# relatório apontou em `_buki_armas`.
var _rig: PlayerRig = null

# ---- do DONO do corpo (a cópia que o jogador controla) ----
var _arma: String = ""        # slot empunhado ("" = mãos livres)
var _municao: int = 0         # balas restantes — é o que a HUD mostra
var _cadencia: float = 0.0    # tempo até o próximo tiro
var _luneta: bool = false     # luneta da sniper (C) ligada

# ---- do SERVIDOR (só a cópia autoritativa usa) ----
#
# A MUNIÇÃO EXISTE NOS DOIS LADOS DE PROPÓSITO, e isso não é duplicação:
#   • `_municao` é do DONO. É o que a HUD mostra e o que decide a cadência
#     local; precisa ser local, senão o contador só se mexeria depois do
#     ida-e-volta de rede e a arma pareceria travada.
#   • `_srv_municao` é do SERVIDOR. É ela que autoriza o disparo: sem bala,
#     nenhuma `DamageZone` nasce. Cliente adulterado não fere ninguém.
# O dono desconta ao pedir; o servidor desconta ao criar. Empatam porque partem
# do mesmo número e o canal é `reliable`.
#
# ⚠️ São a MESMA grandeza em CÓPIAS DIFERENTES do mesmo nó, não dois campos de
# negócio. Unificar num campo só reproduz o bug de 2026-08-11 (sniper cheia,
# 5 balas, 0 DamageZone): na cópia do servidor o `_municao` nunca é escrito,
# porque `empunhar()` sai fora por falta de autoridade.
var _srv_arma: String = ""
var _srv_municao: int = 0

# RECARGA DO LADO DO SERVIDOR — slot -> instante (ms) em que ele esfria.
#
# ⚠️ Isto existe porque a recarga do jogador NÃO ANDA na cópia do servidor: o
# `_physics_process` sai cedo quando `_is_authority` é falso, e para o corpo de
# um cliente, no servidor, ele é falso. Ou seja, `_skill_cooldowns` fica em zero
# lá para sempre — não dá para "perguntar se o slot está quente".
#
# Por isso é CARIMBO DE TEMPO, não contador: não precisa de tique nenhum.
var _srv_recarga_ate: Dictionary = {}

# FOLGA da recarga do servidor, em ms.
#
# A recarga do dono começa na HORA em que ele guarda; a do servidor só quando o
# `guardar_req` chega — meia viagem depois. Num ping de 100 ms o servidor esfria
# ~50 ms mais tarde, e quem apertar exatamente no fim da recarga levaria uma
# recusa MUDA ("apertei e não aconteceu nada").
#
# 250 ms absorve a latência sem abrir o furo de volta: a menor recarga é de 5 s,
# então a folga vale 5% dela. Trapacear com isso renderia um saque a cada 4,75 s
# em vez de 5 — nada perto do reenchimento infinito que existia antes.
const FOLGA_RECARGA_MS := 250

# ---- apresentação: roda em TODOS os peers ----
var _visual: String = ""      # arma VISÍVEL (o adversário também vê)

func montar_em(dono: Node, rig: PlayerRig) -> void:
	_dono = dono
	_rig = rig

# ------------------------------------------------------------------ leitura
func arma() -> String:     return _arma
func municao() -> int:     return _municao
func municao_max() -> int: return BukiFX.municao(_arma)
func luneta() -> bool:     return _luneta
func visual() -> String:   return _visual
func empunhando() -> bool: return _arma != ""

# O saque zera junto com o modelo (troca de personagem leva as armas embora).
func esquecer_visual() -> void:
	_visual = ""

# ----------------------------------------------------------- ações do DONO
# EMPUNHAR (ou guardar, se for o mesmo slot). Só o dono do corpo passa por aqui.
func empunhar(slot: String, autoridade: bool, suprimido: bool) -> void:
	if not autoridade or suprimido:
		return
	if _arma == slot:
		print("🔫 Buki: %s GUARDADA — o slot %s entra em recarga." % [BukiFX.nome_da_arma(slot), slot])
		guardar()
		return
	if _arma != "":
		# TROCA DE SKILL: a arma anterior é perdida e o slot dela entra em recarga.
		print("🔫 Buki: larguei a %s pra sacar a %s." % [
			BukiFX.nome_da_arma(_arma), BukiFX.nome_da_arma(slot)])
		guardar()
	if _dono._skill_cooldowns.get(slot, 0.0) > 0.0:
		print("⏳ Buki: %s em recarga (%.1fs)." % [BukiFX.nome_da_arma(slot), _dono._skill_cooldowns[slot]])
		return
	# SACAR NÃO ATIRA (pedido do dono, 2026-08-11).
	#
	# Antes a 1ª bala saía no próprio saque: apertar a tecla já disparava, e a
	# munição começava descontada (12 = 1 no saque + 11 no clique). Em jogo isso
	# vira tiro que o jogador não pediu — ele saca para MIRAR, e o disparo tem
	# que ser decisão dele. A arma sai com a munição CHEIA.
	_arma = slot
	_municao = BukiFX.municao(slot)
	_cadencia = 0.0                 # pronta pra atirar assim que o dedo mandar
	_luneta = false
	print("🔫 Buki: %s EMPUNHADA — %d balas (Bt Esq = atirar%s)." % [
		BukiFX.nome_da_arma(slot), _municao,
		" / Bt Dir = luneta" if slot == "C" else " / Bt Dir = mira assistida"])

	# ⚠️ SACAR TEM QUE AVISAR O SERVIDOR — e isso quase se perdeu.
	#
	# Quando o tiro saiu do saque, saiu junto a linha `_request_cast(slot)`. Ela
	# foi lida como "isto atira", mas carregava outras DUAS coisas de carona:
	#   • gravar `_srv_arma`/`_srv_municao` — sem isso o servidor não sabe qual
	#     arma está na mão e RECUSA TODO TIRO (medido: sniper cheia, 5 balas,
	#     0 DamageZone criada);
	#   • mostrar a arma no rig — sem isso ela nunca aparece, e no canhão o corpo
	#     nem some.
	# Lição: remover chamada é tão perigoso quanto adicionar, quando ela tem
	# efeito colateral.
	_dono.avisar_servidor_do_saque(slot)

# GUARDAR: a arma some e o slot largado entra em recarga. Chamado na troca, no
# fim da munição, ao trocar de fruta e ao morrer.
func guardar() -> void:
	if _arma == "":
		return
	_dono.trigger_skill_cooldown(_arma)   # a penalidade: aquele slot esfria
	_arma = ""
	_municao = 0
	_luneta = false
	_dono.avisar_servidor_do_guardar()

# ------------------------------------------------------- lado do SERVIDOR
# Carrega a munição autoritativa. Devolve `false` quando o saque não vale — daí
# o Player não faz broadcast nenhum.
# ⚠️ FURO FECHADO EM 2026-08-12 — MUNIÇÃO INFINITA.
#
# Antes esta função reenchia o pente sem olhar recarga nenhuma: a penalidade da
# fruta era decidida SÓ no cliente (`empunhar`). Quem mandasse
# `_net_buki_sacar_req` direto pulava a única penalidade que a Buki tem.
# Medido pela sonda de rede: com a recarga de Z quente (5,0s -> 2,8s -> 0,5s),
# repetindo o pedido, o pente autoritativo voltou 9 -> 12 DUAS VEZES — 6 zonas
# de dano onde o jogador honesto teria 3.
#
# Duas guardas fecham o caminho, e as DUAS são necessárias:
#   1. sacar com arma na mão põe a ANTERIOR em recarga — senão o trapaceiro
#      simplesmente nunca manda `guardar_req` e o slot nunca esfria;
#   2. só então se pergunta se o slot pedido está frio.
# Sem (1), (2) sozinha não barra nada: era exatamente esse o buraco.
func servidor_sacar(slot: String) -> bool:
	if not (ativa() and BukiFX.ARSENAL.has(slot)):
		return false
	if _srv_arma != "":
		servidor_guardar()               # a de agora paga a recarga dela
	if Time.get_ticks_msec() + FOLGA_RECARGA_MS < int(_srv_recarga_ate.get(slot, 0)):
		return false                     # slot ainda quente no SERVIDOR
	_srv_arma = slot
	_srv_municao = BukiFX.municao(slot)   # CHEIA: o saque não gasta bala
	return true

func servidor_guardar() -> void:
	if _srv_arma != "":
		# Mesma tabela do dono (`Player.RECARGA_POR_SLOT`): duas cópias do número
		# escritas à mão foi como o furo nasceu.
		var segundos: float = float(_dono.RECARGA_POR_SLOT.get(_srv_arma, 0.0))
		_srv_recarga_ate[_srv_arma] = Time.get_ticks_msec() + int(segundos * 1000.0)
	_srv_arma = ""
	_srv_municao = 0

# Quanto falta da recarga autoritativa deste slot, em segundos (0 = frio).
func servidor_recarga(slot: String) -> float:
	var falta := int(_srv_recarga_ate.get(slot, 0)) - Time.get_ticks_msec()
	return maxf(float(falta) / 1000.0, 0.0)

# Autoriza UM tiro e consome a bala. Sem bala, nenhum tiro sai — nem visual, nem
# `DamageZone`. Cliente adulterado não ganha munição infinita.
func servidor_autoriza_tiro(arma_pedida: String) -> bool:
	if _srv_arma != arma_pedida or _srv_municao <= 0:
		return false
	_srv_municao -= 1
	return true

func servidor_municao() -> int:
	return _srv_municao

# ---------------------------------------------- apresentação (TODOS os peers)
# Roda no dono E no adversário: é assim que se vê a arma na mão do outro e o
# corpo dele virar canhão.
func mostrar_arma(slot: String) -> void:
	_visual = slot
	var armas: Dictionary = _rig.armas_buki()
	for s in armas.keys():
		var n = armas[s]
		if not is_instance_valid(n):
			continue
		var ligar: bool = (s == slot)
		if ligar and not n.visible:
			BukiFX.onda_de_aco(n.get_parent())   # o aço descendo pelo membro
		n.visible = ligar
	_dono._atualizar_visibilidade_corpo()

# O canhão-corpo (X) aponta pra onde a câmera olha; as armas de braço já seguem
# o membro.
#
# ⚠️ Roda TAMBÉM nas cópias remotas (`_remote_process`), e é o único trecho de
# Buki que roda sem autoridade. Guardar o componente inteiro atrás de
# `_is_authority` faria o adversário aparecer sempre apontando pro mesmo lado.
func apontar_canhao(autoridade: bool, pitch: float, yaw: float, facing: float) -> void:
	var pivo: Node3D = _rig.pivo_buki()
	if not is_instance_valid(pivo) or _visual != "X":
		return
	if autoridade:
		pivo.rotation = Vector3(pitch, yaw, 0)
	else:
		pivo.rotation = Vector3(0, facing, 0)

# --------------------------------------------------------------------- ciclo
# Roda todo quadro enquanto houver arma empunhada. NÃO congela o jogador: com
# arma na mão dá pra andar — é FPS, não pose de golpe.
func atualizar(delta: float, pitch: float, yaw: float, facing: float) -> void:
	if _cadencia > 0.0:
		_cadencia = maxf(_cadencia - delta, 0.0)
	apontar_canhao(true, pitch, yaw, facing)

	var bt_dir := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	# HABILIDADE ATIVA DA FRUTA: o botão direito faz a mira TENDER pro alvo mais
	# próximo. ⚠️ EXCEÇÃO DA SNIPER (C): ali o auxílio fica DESLIGADO e o botão
	# direito é a luneta — mira assistida com zoom seria tiro grátis.
	if _arma == "C":
		_luneta = bt_dir
	else:
		_luneta = false
		if bt_dir:
			_auxilio_de_mira(delta)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _cadencia <= 0.0:
		atirar()

# Mira assistida: puxa devagar (não trava) pro alvo mais próximo.
# Quem é dono de `_yaw`/`_pitch` é o Player (decisão da Fase 2) — aqui só se
# escolhe O ALVO e se PEDE a mira.
func _auxilio_de_mira(delta: float) -> void:
	var alvo: Node3D = _dono._alvo_mais_proximo(50.0)
	if alvo == null or not is_instance_valid(alvo):
		return
	_dono.mirar_suave_para(alvo.global_position + Vector3.UP * 0.9, delta, 9.0)

# UM TIRO. ⚠️ NADA de criar o efeito aqui: a bala tem que NASCER NO SERVIDOR,
# senão a DamageZone do cliente não fere ninguém e o sintoma vira "a arma não
# funciona" (docs/erros.md, 2026-08-10 — pistola da Yami).
func atirar() -> void:
	if _arma == "" or _municao <= 0:
		return
	var slot := _arma
	var d: Dictionary = BukiFX.ARSENAL[slot]
	_municao -= 1
	_cadencia = float(d["cadencia"])
	_dono.pedir_coice_de_arma()
	_dono.add_camera_shake(float(d["shake"]))

	var origem := boca_do_cano()
	var alvo_pt: Vector3 = _dono._aim_target_point()
	var aim := alvo_pt - origem
	aim = aim.normalized() if aim.length() > 0.01 else -_dono._cam.global_transform.basis.z
	origem += aim * 0.25
	_dono.pedir_bala_da_buki(aim, origem, slot)

	# RECUO do canhão: o tranco empurra o jogador pra trás — o tiro vira
	# mobilidade. O impulso é do domínio de MOVIMENTO, então vai como pedido.
	var recuo := float(d["recuo"])
	if recuo > 0.0:
		_dono.pedir_recuo(-aim, recuo)

	if _municao <= 0:
		print("🔫 Buki: %s SEM MUNIÇÃO — some da mão e o slot %s entra em recarga." % [
			BukiFX.nome_da_arma(slot), slot])
		guardar()

# Boca do cano da arma empunhada. Sem arma na árvore, cai no peito (mesma rede
# de segurança do `_muzzle_pos` da pistola).
func boca_do_cano() -> Vector3:
	var n = _rig.armas_buki().get(_arma)
	if n is Node3D and is_instance_valid(n) and (n as Node3D).is_inside_tree():
		var t := (n as Node3D).global_transform
		# Pistola aponta pro −Y do antebraço; o resto (.glb) pro −Z do próprio nó.
		if _arma == "Z":
			return t.origin - t.basis.y.normalized() * 0.34
		return t.origin - t.basis.z.normalized() * (1.7 if _arma == "X" else 0.9)
	return _dono.global_position + Vector3.UP * 1.2 + (-_dono._cam.global_transform.basis.z) * 0.9

# A fruta está equipada? Continua sendo pergunta ao Player: `current_fruit_id` é
# replicado pelo `MultiplayerSynchronizer` e está previsto para migrar na Fase 6.
func ativa() -> bool:
	return _dono._buki_ativa()
