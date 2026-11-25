class_name ControladorFrutaDoMod
extends ControladorFrutaMinePiece
## O jogador usa a fruta pelo FLUXO DO MOD (decisão do dono, 03/11/2026): as teclas chamam as procedures traduzidas
## do Mine Piece (`KeyChangeTechniqueOnKeyPressed`, `KeyStartTechniqueOnKeyPressed/Released`), o efeito
## `minepiece:skill` executa o golpe da fruta e nada passa por skill builder nem por executor escrito à mão.
## Mesma interface do `ControladorFrutaMinePiece` (herda): o `Player`, o HUD e o `ModoHistoria` não mudam.
##
## O que o jogo empresta ao mod (PlayerVariables): fruta, energia, energia máxima, nível. A energia é UMA só:
## a do jogo (`ator.energy`); o que o mod gasta em `PlayerEnergy` volta para o jogo a cada quadro.
##

const PREFIXO := FrutasDoMod.PREFIXO
const PRIMEIRO_GOLPE := 21
const ULTIMO_GOLPE := 30
const SEM_NOME := "-----"
const FlorDeBuda = preload("res://src/combat/buda/flor_de_buda.gd")
const ZushiFujitora = preload("res://src/combat/zushi/zushi_fujitora.gd")
const UshiUshi = preload("res://src/combat/ushi/ushi_ushi.gd")
const KiraInvestida = preload("res://src/combat/kira/kira_investida.gd")
const KiraExplosao = preload("res://src/combat/kira/kira_explosao.gd")
const KiraPedras = preload("res://src/combat/kira/kira_pedras.gd")
const KiraPedra = preload("res://src/combat/kira/kira_pedra.gd")
const KiraVfx = preload("res://src/combat/kira/kira_vfx.gd")
var flor_de_buda: Node
var zushi_fujitora: Node         # Jigoku Tabi (K) e Abare Himatsuri (L) da Zushi Zushi
var ushi: Node                   # Ushi Ushi: 3 formas + Z/X/C autorais (src/combat/ushi)
var kira_investida: Node
var kira_pedras: Node
var _kira_trilha: Node3D
var _kira_movimento_remoto := 0.0
var _kira_direcao_remota := Vector3.ZERO

var _mc: McEntidade
var _v                           # PlayerVariables do mod (McVariaveisDoMod.PlayerVariables)
var _lista: Array = []           # [{numero, chave, custo}] — o que o mod oferece para esta fruta
var _energia_vista := 0.0
var _recarga_maxima := 1.0
## RECARGA POR TÉCNICA (12/11/2026, pedido do dono: "apenas o poder usado fica bloqueado até o cronômetro terminar"). O mod põe UM efeito global `minepiece:cooldown_time`
## que trava todas as técnicas; aqui o efeito é reivindicado pela técnica que o causou (`_recargas[número] = segundos`) e REMOVIDO do mod, então as outras seguem livres.
var _recargas := {}              # número da técnica → segundos que faltam
var _recargas_totais := {}       # número → total (para a barra do HUD)
var _tecnica_em_uso := 0         # a última técnica iniciada: é a dona do próximo recarregamento do mod
var _conquistas_vistas := -1
var paralelas: SessoesDoMod        # só nas logias do fluxo do mod: técnicas em paralelo (ver `SessoesDoMod`)     # a lista de golpes do mod depende de grades: refaz quando uma conquista é concluída


func _ready() -> void:
	ator = get_parent() as Player
	_mc = McEntidade.de(ator)
	_v = _mc.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	_v.PlayerDevilFruit = Mc.novo(&"ItemStack", [Mc.item(PREFIXO + fruta_id)])
	_v.UseDevilAbilities = true
	if fruta_id == "aro_aro":
		_mc.getPersistentData().fator_de_alcance = FrutasDoMod.ALCANCE_DO_ARO_ARO
	_v.PlayerSkill1 = 1.0
	if SessoesDoMod.contem(fruta_id):
		paralelas = SessoesDoMod.new()
		paralelas.c = self
	_sincronizar_para_o_mod()
	_montar_lista()
	_escolher(0)
	if fruta_id == "hito_hito_daibutsu":
		flor_de_buda = FlorDeBuda.new()
		flor_de_buda.name = "FlorDeBuda"
		flor_de_buda.controlador = self
		add_child(flor_de_buda)
	elif fruta_id == "zushi_zushi":
		zushi_fujitora = ZushiFujitora.new()
		zushi_fujitora.name = "ZushiFujitora"
		zushi_fujitora.controlador = self
		add_child(zushi_fujitora)
	elif fruta_id == "ushi_ushi_giraffe":
		ushi = UshiUshi.new()
		ushi.name = "UshiUshi"
		ushi.controlador = self
		add_child(ushi)
	elif fruta_id == "kira_kira":
		kira_investida = KiraInvestida.new()
		kira_investida.name = "KiraInvestida"
		kira_investida.controlador = self
		add_child(kira_investida)
		kira_pedras = KiraPedras.new()
		kira_pedras.name = "KiraPedras"
		kira_pedras.controlador = self
		add_child(kira_pedras)


func _sincronizar_para_o_mod() -> void:
	_v.PlayerEnergyMAX = ator.max_energy
	_v.PlayerEnergy = ator.energy
	_v.PlayerLevel = float(ator.get_meta("nivel_historia", 1))
	_energia_vista = ator.energy


## O que o mod gastou (ou devolveu) em `PlayerEnergy` desde o último quadro volta para a energia do jogo.
func _sincronizar_para_o_jogo() -> void:
	var delta: float = _energia_vista - float(_v.PlayerEnergy)
	if absf(delta) > 0.0001:
		if delta > 0.0:
			ator.gastar_energia(delta)
		else:
			ator.energy = minf(ator.max_energy, ator.energy - delta)
	_sincronizar_para_o_mod()


## Pergunta ao mod, golpe a golpe, o que a fruta oferece (nome, custo): a mesma procedure da tecla R.
func _montar_lista() -> void:
	_lista.clear()
	var guardado := [_v.PlayerSelectName, _v.PlayerSelectNumber, _v.PlayerSelectCost, _v.PlayerSelectCostOrgin]
	for n in range(PRIMEIRO_GOLPE, ULTIMO_GOLPE + 1):
		Mc.proc(&"KeyChangeTechniqueDevilFruitProcedure").execute(_mc.level(), _mc, _v.PlayerDevilFruit, float(n), 1.0)
		var chave := str(_v.PlayerSelectName)
		if chave != SEM_NOME and not chave.contains("attack") and not _lista.any(func(g): return g.chave == chave):
			_lista.append({"numero": n, "chave": chave, "custo": float(_v.PlayerSelectCostOrgin)})
	_v.PlayerSelectName = guardado[0]
	_v.PlayerSelectNumber = guardado[1]
	_v.PlayerSelectCost = guardado[2]
	_v.PlayerSelectCostOrgin = guardado[3]


func _escolher(indice: int) -> void:
	if _lista.is_empty():
		return
	selecao = int(_lista[posmod(indice, _lista.size())].numero)
	Mc.proc(&"KeyChangeTechniqueDevilFruitProcedure").execute(_mc.level(), _mc, _v.PlayerDevilFruit, float(selecao), 1.0)


func _indice_da_selecao() -> int:
	for i in _lista.size():
		if int(_lista[i].numero) == selecao:
			return i
	return 0


## Z X C V B N: a n-ésima técnica que o mod oferece (mesma ordem do R), cada uma na sua tecla.
func tem_teclas_diretas() -> bool:
	return true


func mapa_de_teclas() -> Dictionary:
	if is_instance_valid(ushi):
		var m := {}
		for t: String in ["Z", "X", "C"]:
			if ushi.numero_de(t) != 0: m[t] = ushi.numero_de(t)
		if ushi.forma != 2 and _lista.any(func(g): return int(g.numero) == UshiUshi.SKY_SLICER): m["V"] = UshiUshi.SKY_SLICER
		return m
	if is_instance_valid(kira_investida):
		var kira := {"Z": KiraInvestida.NUMERO}
		if _lista.any(func(g): return int(g.numero) == 24): kira["X"] = 24
		if _lista.any(func(g): return int(g.numero) == 25): kira["C"] = 25
		return kira
	var mapa := {}
	for i in mini(_lista.size(), TECLAS.size()):
		var indice := i + (1 if fruta_id == "hito_hito_daibutsu" and i >= 1 else 0)
		if indice < TECLAS.size(): mapa[TECLAS[indice]] = int(_lista[i].numero)
	if fruta_id == "hito_hito_daibutsu": mapa["X"] = FlorDeBuda.NUMERO
	return mapa


func recarga_por_tecnica() -> bool:
	return false


## A técnica que está rodando AGORA (para o asset 3D do projétil que ela cria): a sessão paralela em tick, ou a viva, ou a selecionada.
func tecnica_em_execucao() -> int:
	if paralelas != null:
		return paralelas.executando if paralelas.executando != 0 else (paralelas.vivo if paralelas.vivo != 0 else selecao)
	return selecao


## Tecla de transformação do mod (a dele é `N`; no jogo B e N são técnicas: aqui é `J`). Só vale para as frutas
## com a tag `minepiece:can_transform` (Zoan); o resto o `KeyTransform` do próprio mod ignora.
func transformar(para_tras := false) -> void:
	_pedir("transformar", para_tras)


func pode_transformar() -> bool:
	return _v != null and (_v.PlayerDevilFruit as McItem.Pilha).is_(Mc.estatico(&"ItemTags", &"create", [Mc.novo(&"ResourceLocation", ["minepiece:can_transform"])]))


func avisos() -> String:
	return "J transforma" if pode_transformar() else ""


## Forma atual do mod (0 = normal): atributo `minepiece:form`.
func forma_atual() -> int:
	return int(_mc.getAttributeValue(Mc.atributo(&"minepiece:form"))) if _mc != null else 0


## Um passo do mod na forma (0↔1): `sobe` = sem Shift (para a forma 1); senão volta à 0. Usado pelo ciclo de três formas da Ushi Ushi.
func _passo_do_mod(sobe: bool) -> void:
	_mc.setShiftKeyDown(not sobe)
	Mc.proc(&"KeyTransformOnKeyPressedProcedure").execute(_mc.level(), _mc)
	_mc.setShiftKeyDown(shift)


## A transformação temporária é visual e não altera o atributo de forma do mod.
## O servidor avisa os peers; quem já estava transformado mantém a forma ao fim.
func mostrar_forma_kira(ligada: bool, forma_anterior: int, direcao: Vector3) -> void:
	_aplicar_forma_kira(ligada, forma_anterior, direcao)
	if servidor() and is_inside_tree() and multiplayer.has_multiplayer_peer():
		_forma_kira_remota.rpc(ligada, forma_anterior, direcao)


@rpc("any_peer", "call_remote", "reliable")
func _forma_kira_remota(ligada: bool, forma_anterior: int, direcao: Vector3) -> void:
	if multiplayer.get_remote_sender_id() != 1 or servidor():
		return
	_aplicar_forma_kira(ligada, forma_anterior, direcao)


func _aplicar_forma_kira(ligada: bool, forma_anterior: int, direcao: Vector3) -> void:
	if not is_instance_valid(ator):
		return
	if not servidor() and ator._is_authority:
		_kira_movimento_remoto = KiraInvestida.DURACAO if ligada else 0.0
		_kira_direcao_remota = direcao
	if ligada:
		ator.set_meta("pose_externa", KiraInvestida.POSE)
		ator.set_meta("kira_investida_imune", true)
	elif ator.has_meta("pose_externa"):
		ator.remove_meta("pose_externa")
	if not ligada and ator.has_meta("kira_investida_imune"):
		ator.remove_meta("kira_investida_imune")
	KiraVfx.parar(_kira_trilha)
	_kira_trilha = KiraVfx.trilha(ator) if ligada else null
	if ligada and not is_instance_valid(ator.get_node_or_null("FormaZoan")):
		FormaZoan.aplicar(ator, "kira_kira", 1)
	elif not ligada and forma_anterior <= 0:
		FormaZoan.aplicar(ator, "kira_kira", 0)


func mostrar_explosao_kira(posicao: Vector3, direcoes: PackedVector3Array, dano: float, forte := false) -> void:
	KiraExplosao.criar(get_tree().current_scene, posicao, direcoes, ator, dano, forte)
	if servidor() and is_inside_tree() and multiplayer.has_multiplayer_peer():
		_explosao_kira_remota.rpc(posicao, direcoes, forte)


@rpc("any_peer", "call_remote", "reliable")
func _explosao_kira_remota(posicao: Vector3, direcoes: PackedVector3Array, forte := false) -> void:
	if multiplayer.get_remote_sender_id() == 1 and not servidor():
		KiraExplosao.criar(get_tree().current_scene, posicao, direcoes, null, 0.0, forte)


## Pose temporária dos braços no X/C (vazio = solta). Replicada para quem vê o corpo.
func mostrar_pose_kira(pose: Dictionary) -> void:
	_aplicar_pose_kira(pose)
	if servidor() and is_inside_tree() and multiplayer.has_multiplayer_peer():
		_pose_kira_remota.rpc(pose)


@rpc("any_peer", "call_remote", "reliable")
func _pose_kira_remota(pose: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() == 1 and not servidor():
		_aplicar_pose_kira(pose)


func _aplicar_pose_kira(pose: Dictionary) -> void:
	if not is_instance_valid(ator):
		return
	if pose.is_empty():
		if ator.has_meta("pose_externa") and ator.get_meta("pose_externa") != KiraInvestida.POSE:
			ator.remove_meta("pose_externa")
	else:
		ator.set_meta("pose_externa", pose)


## Uma pedra cúbica do X/C: o servidor cria com dano, os outros só desenham o mesmo voo.
func mostrar_pedra_kira(origem: Vector3, alvo: Vector3, tamanho: float, textura: String, dano: float, explosao: float,
		velocidade: float, subida: float, tempo_subida: float) -> void:
	_criar_pedra_kira(origem, alvo, tamanho, textura, dano, explosao, velocidade, subida, tempo_subida)
	if servidor() and is_inside_tree() and multiplayer.has_multiplayer_peer():
		_pedra_kira_remota.rpc(origem, alvo, tamanho, textura, explosao, velocidade, subida, tempo_subida)


@rpc("any_peer", "call_remote", "reliable")
func _pedra_kira_remota(origem: Vector3, alvo: Vector3, tamanho: float, textura: String, explosao: float,
		velocidade: float, subida: float, tempo_subida: float) -> void:
	if multiplayer.get_remote_sender_id() == 1 and not servidor():
		_criar_pedra_kira(origem, alvo, tamanho, textura, 0.0, explosao, velocidade, subida, tempo_subida)


func _criar_pedra_kira(origem: Vector3, alvo: Vector3, tamanho: float, textura: String, dano: float, explosao: float,
		velocidade: float, subida: float, tempo_subida: float) -> void:
	var pedra := KiraPedra.new()
	pedra.tamanho = tamanho
	pedra.textura = textura
	pedra.autor = ator
	pedra.dano = dano
	pedra.raio_de_explosao = explosao
	pedra.velocidade = velocidade
	pedra.destino = alvo
	pedra.altura_de_subida = subida
	pedra.tempo_de_subida = tempo_subida
	pedra.empurrao = 24.0 if explosao > 0.0 else 16.0
	var cena: Node3D = get_tree().current_scene as Node3D
	pedra.position = origem - (cena.global_position if cena != null else Vector3.ZERO)   # antes do _ready: ele lê a posição
	get_tree().current_scene.add_child(pedra)


func _executar(tipo: String, valor: bool) -> void:
	if is_instance_valid(kira_pedras) and (tipo == "tecla_x" or tipo == "tecla_c"):
		if valor: kira_pedras.iniciar(tipo.substr(6).to_upper())
		return
	if is_instance_valid(kira_investida) and tipo == "tecla_z":
		if valor: kira_investida.iniciar()
		return
	if is_instance_valid(ushi) and (tipo == "tecla_z" or tipo == "tecla_x" or tipo == "tecla_c"):
		if valor: ushi.iniciar(tipo.substr(6).to_upper())
		return
	if is_instance_valid(flor_de_buda) and tipo == "tecla_x":
		if valor: flor_de_buda.iniciar()
		return
	if is_instance_valid(zushi_fujitora) and (tipo == "tecla_k" or tipo == "tecla_l"):
		if valor: zushi_fujitora.iniciar(tipo.substr(6).to_upper())
		return
	if (is_instance_valid(flor_de_buda) and flor_de_buda.ativo or is_instance_valid(zushi_fujitora) and zushi_fujitora.ativo or is_instance_valid(ushi) and ushi.ativo or is_instance_valid(kira_investida) and kira_investida.ativo) and tipo != "shift":
		return
	if tipo.begins_with("tecla_"):
		_tecla_do_mod(tipo.substr(6).to_upper(), valor)
		return
	if tipo == "usar":
		segurando = valor
		if not fruta_ativa() or not ator.corpo_livre_para_golpe():
			return
		_sincronizar_para_o_mod()
		if valor:
			ativo = true
			Mc.proc(&"KeyStartTechniqueOnKeyPressedProcedure").execute(_mc)
			_carga_vfx = PoderDaFruta.carga(ator, _id_da_fruta(), _custo_da_tecnica())        # HTCS: a carga enquanto se segura
			PoderDaFruta.rastro_da_mao(ator, _id_da_fruta())             # HTCS: rastro da mão que executa
		else:
			Mc.proc(&"KeyStartTechniqueOnKeyReleasedProcedure").execute(_mc)
			PoderVfx.soltar_carga(_carga_vfx)
			_carga_vfx = null
			PoderDaFruta.assinatura(ator, _id_da_fruta(), selecao)        # a forma que identifica o golpe (Zushi C: o tigre)
			var custo_t := _custo_da_tecnica()
			PoderDaFruta.ativacao(ator, _id_da_fruta(), custo_t)          # anel de ativação da cor da fruta, tamanho pelo custo
			var desde := Time.get_ticks_msec() - 700        # HTCS: sem acerto em ~0,5 s depois de soltar → clímax no ponto de mira
			get_tree().create_timer(0.5, false).timeout.connect(func() -> void:
				if is_instance_valid(ator): PoderDaFruta.climax_sem_alvo(ator, _id_da_fruta(), desde, custo_t))
		_sincronizar_para_o_jogo()
	elif tipo == "transformar" and fruta_ativa() and not ativo and is_instance_valid(ushi):
		ushi.ciclar(valor)                               # Ushi Ushi: humano → humanoide → girafa (Shift/para trás: o inverso)
	elif tipo == "transformar" and fruta_ativa() and not ativo:
		_mc.setShiftKeyDown(valor)                       # Shift volta à forma anterior (como o mod)
		Mc.proc(&"KeyTransformOnKeyPressedProcedure").execute(_mc.level(), _mc)
		_mc.setShiftKeyDown(shift)
	elif tipo == "trocar" and fruta_ativa() and not ativo:
		_escolher(_indice_da_selecao() + (-1 if valor else 1))
	elif tipo == "shift":
		shift = valor
		_mc.setShiftKeyDown(valor)
	elif tipo == "tras":
		tras = valor


var _carga_vfx: Node3D              # emissor da CARGA do HTCS (partículas puxadas ao peito), até soltar
var _forma_desenhada := 0
var _tecla_recusada := ""       # tecla cuja técnica foi recusada por falta de item: o soltar dela é ignorado


## A forma do mod (atributo `minepiece:form`) vira corpo na tela: `FormaZoan` desenha o modelo da fruta e esconde o corpo.
func _atualizar_forma_visual() -> void:
	if is_instance_valid(ushi):
		ushi.sincronizar_com_o_mod()                     # a forma de tela é do módulo (ele monta o humanoide ou a girafa)
		return
	var forma := forma_atual()
	if forma != _forma_desenhada:
		_forma_desenhada = forma
		FormaZoan.aplicar(ator, fruta_id, forma)


func _physics_process(_delta: float) -> void:                 # (usa `_delta` abaixo)
	if not is_instance_valid(ator) or _v == null:
		return
	_kira_movimento_remoto = maxf(0.0, _kira_movimento_remoto - _delta)
	if ator._is_authority:
		_atualizar_forma_visual()
	if fruta_ativa() and ator._is_authority:
		# A mira (câmera) vira o `getLookAngle` do mod: sem isto todo projétil saía na mesma direção.
		ator.set_meta(McEntidade.META_MIRA, olhar())
	if ator._is_authority and fruta_ativa():
		var com_shift := Input.is_key_pressed(KEY_SHIFT)
		if com_shift != shift:
			_pedir("shift", com_shift)
	if servidor():
		var feitas: int = _mc.conquistas_do_jogador().concluidas
		if feitas != _conquistas_vistas:
			_conquistas_vistas = feitas
			_montar_lista()
			if not _lista.any(func(g): return int(g.numero) == selecao):
				_escolher(0)
		_sincronizar_para_o_jogo()
		# O efeito `minepiece:skill` ativo = a técnica em curso; sem ele o jogador está livre.
		ativo = (is_instance_valid(flor_de_buda) and flor_de_buda.ativo) or (is_instance_valid(zushi_fujitora) and zushi_fujitora.ativo) or (is_instance_valid(ushi) and ushi.ativo) or (is_instance_valid(kira_investida) and kira_investida.ativo) or (is_instance_valid(kira_pedras) and kira_pedras.ativo) or (_mc.hasEffect(Mc.efeito("minepiece:skill")) and float(_mc.getPersistentData().getDouble("skill")) != 0.0) or (paralelas != null and paralelas.tem())
		_atualizar_recargas(_delta)
		if paralelas != null:
			paralelas.passo(_delta)


## Reivindica o recarregamento global do mod para a técnica usada, tira o efeito do mod e conta o tempo de cada técnica.
func _atualizar_recargas(delta: float) -> void:
	var espera := _recarga_do_mod()
	if espera > 0.0:
		var dona := _tecnica_em_uso if _tecnica_em_uso != 0 else selecao
		_recargas[dona] = maxf(float(_recargas.get(dona, 0.0)), espera)
		_recargas_totais[dona] = maxf(float(_recargas_totais.get(dona, 0.0)), espera)
		_mc.removeEffect(Mc.efeito("minepiece:cooldown_time"))       # o mod não bloqueia mais as outras técnicas
	for n in _recargas.keys():
		_recargas[n] = maxf(0.0, float(_recargas[n]) - delta)
	recarga = float(_recargas.get(selecao, 0.0))
	_recarga_maxima = maxf(1.0, float(_recargas_totais.get(selecao, 1.0)))
	recarga_total = _recarga_maxima


## Segundos que faltam da técnica `numero` (0 = livre).
## Põe uma técnica DO JOGO (fora da lista do mod) em recarga; o HUD e a recusa de tecla leem o mesmo `_recargas`.
func iniciar_recarga(numero: int, segundos: float) -> void:
	_recargas[numero] = segundos
	_recargas_totais[numero] = segundos


func recarga_da_tecnica(numero: int) -> float:
	return float(_recargas.get(numero, 0.0))


## Segundos que faltam do recarregamento do mod (efeito `cooldown_time`, em ticks de 0,05 s).
func _recarga_do_mod() -> float:
	var e = _mc.getEffect(Mc.efeito("minepiece:cooldown_time"))
	return float(e.getDuration()) * 0.05 if e != null else 0.0


## Apertar escolhe a técnica da tecla e começa (KeyStart...Pressed); soltar só vale para a que está em curso.
func _tecla_do_mod(tecla: String, apertou: bool) -> void:
	var mapa := mapa_de_teclas()
	if not mapa.has(tecla):
		return
	if apertou:
		if not fruta_ativa() or (ativo and paralelas == null):
			return
		if paralelas != null and paralelas.em_curso(int(mapa[tecla])):
			return                           # a mesma técnica já corre: só vale a recarga dela, as outras seguem livres
		if recarga_da_tecnica(int(mapa[tecla])) > 0.0:
			_tecla_recusada = tecla          # SÓ esta técnica está recarregando: as outras teclas seguem livres
			return
		if is_instance_valid(zushi_fujitora) and int(mapa[tecla]) == zushi_fujitora.RUBBLE:
			if not zushi_fujitora.iniciar_rubble():
				_tecla_recusada = tecla      # o Rubble do mod não causa dano aqui: a versão própria assume (ver `ZushiFujitora`)
			return
		if not _tem_o_item_da_tecnica(int(mapa[tecla])):
			_tecla_recusada = tecla          # o SOLTAR desta tecla não pode rodar: não houve início (deixava o estado do mod sujo)
			return
		if paralelas != null:
			_atualizar_recargas(0.0)         # o recarregamento do mod que a técnica anterior renovou fica com ELA; senão o LogicStart recusa esta
		selecao = int(mapa[tecla])
		_tecnica_em_uso = selecao
		Mc.proc(&"KeyChangeTechniqueDevilFruitProcedure").execute(_mc.level(), _mc, _v.PlayerDevilFruit, float(selecao), 1.0)
		if paralelas != null:
			paralelas.antes_de_comecar()
		_executar("usar", true)
		if paralelas != null:
			paralelas.depois_de_comecar(selecao)
			if paralelas.vivo == selecao:
				SonsDasTecnicas.carga(ator, fruta_id)
	elif _tecla_recusada == tecla:
		_tecla_recusada = ""
	elif paralelas != null:
		var numero_solto := int(mapa[tecla])
		var estava_em_curso := paralelas.em_curso(numero_solto)
		if paralelas.soltar(numero_solto):
			selecao = numero_solto
			_executar("usar", false)
		if estava_em_curso:
			SonsDasTecnicas.disparo(ator, fruta_id, numero_solto)
	elif selecao == int(mapa[tecla]) and not (is_instance_valid(zushi_fujitora) and selecao == zushi_fujitora.RUBBLE):
		_executar("usar", false)


## Bisu Bisu: cada guerreiro de biscoito custa 1 biscoito (C cria 1, V cria 4). Sem eles a técnica nem começa (a energia não é gasta) e o HUD avisa.
func _tem_o_item_da_tecnica(numero: int) -> bool:
	if fruta_id != "bisu_bisu" or not McAliadoDoMod.GUERREIROS_POR_TECNICA.has(numero):
		return true
	var precisa: int = McAliadoDoMod.GUERREIROS_POR_TECNICA[numero]
	if ItensDoMod.quantidade(get_tree(), ItensDoMod.BISCOITO) >= precisa:
		return true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("avisar"):
		hud.avisar("Faltam biscoitos: esta técnica gasta %d (use a técnica Biscuit para criar)" % precisa)
	return false


## Custo de energia (do mod) da técnica selecionada, para escalar a carga e o clímax do HTCS.
func _custo_da_tecnica() -> float:
	for t in estado_das_tecnicas():
		if bool(t.get("selecionada", false)):
			return float(t.get("custo", 200.0))
	return 200.0


func _id_da_fruta() -> String:
	return str(ator.get("current_fruit_id")) if is_instance_valid(ator) else ""


func terminar() -> void:
	ativo = false
	segurando = false
	if is_instance_valid(_carga_vfx):        # o emissor da carga pode já ter sido liberado (troca de fruta no meio da técnica)
		PoderVfx.soltar_carga(_carga_vfx)
	_carga_vfx = null


func cancelar() -> void:
	if paralelas != null:
		paralelas.cancelar_tudo()
	if is_instance_valid(flor_de_buda): flor_de_buda.cancelar()
	if is_instance_valid(zushi_fujitora): zushi_fujitora.cancelar()
	if is_instance_valid(ushi): ushi.cancelar()
	if is_instance_valid(kira_investida): kira_investida.cancelar()
	if is_instance_valid(kira_pedras): kira_pedras.cancelar()
	terminar()


func _exit_tree() -> void:
	cancelar()
	if fruta_id == "kira_kira":
		_kira_movimento_remoto = 0.0
		KiraVfx.parar(_kira_trilha)
		if is_instance_valid(ator) and ator.has_meta("kira_investida_imune"):
			ator.remove_meta("kira_investida_imune")
		if is_instance_valid(ator) and ator.get_meta("pose_externa", {}) == KiraInvestida.POSE:
			ator.remove_meta("pose_externa")
	if is_instance_valid(ator) and ator.has_meta(McEntidade.META_MIRA):
		ator.remove_meta(McEntidade.META_MIRA)
	if _mc != null and _mc.valida():
		_mc.getPersistentData().fator_de_alcance = 1.0
	# Sem a fruta o corpo volta ao normal: percorre as formas do mod até a 0 (cada passo desfaz um modificador e a escala).
	if _mc != null and _mc.valida() and forma_atual() != 0:
		for i in 4:
			if forma_atual() == 0:
				break
			Mc.proc(&"KeyTransformOnKeyPressedProcedure").execute(_mc.level(), _mc)
	if is_instance_valid(ushi):
		ushi.limpar()
	if is_instance_valid(ator):
		FormaZoan.aplicar(ator, fruta_id, 0)
	if _mc != null and _mc.hasEffect(Mc.efeito("minepiece:skill")):
		_mc.removeEffect(Mc.efeito("minepiece:skill"))


## MobEffect SLOWNESS (`minecraft:movement_slowdown`) que a técnica do mod aplicou no jogador: amplificador, ou −1.
func _lentidao_do_mod() -> int:
	var e = _mc.getEffect(Mc.efeito("minecraft:movement_slowdown")) if _mc != null else null
	return int(e.getAmplifier()) if e != null else -1


## Lentidão X da técnica prende o corpo (−15 % de velocidade por nível; a partir do amplificador 6 não anda) — a conta
## do Minecraft, a mesma do controlador antigo. Só enquanto a técnica está em curso.
func controla_movimento() -> bool:
	if is_instance_valid(kira_investida) and kira_investida.ativo: return true
	if _kira_movimento_remoto > 0.0: return true
	if is_instance_valid(flor_de_buda) and flor_de_buda.ativo: return true
	if is_instance_valid(zushi_fujitora) and zushi_fujitora.ativo: return true
	if is_instance_valid(ushi) and ushi.controla_movimento(): return true
	return fruta_ativa() and ativo and _lentidao_do_mod() >= 0


func velocidade(_delta: float, atual: Vector3, q: MoveFrame) -> Vector3:
	if is_instance_valid(kira_investida) and kira_investida.ativo: return kira_investida.velocidade(atual)
	if _kira_movimento_remoto > 0.0: return Vector3(_kira_direcao_remota.x * KiraInvestida.VELOCIDADE, atual.y, _kira_direcao_remota.z * KiraInvestida.VELOCIDADE)
	if is_instance_valid(flor_de_buda) and flor_de_buda.ativo: return Vector3(0, minf(atual.y, 0), 0)
	if is_instance_valid(zushi_fujitora) and zushi_fujitora.ativo: return zushi_fujitora.velocidade(atual, q)
	if is_instance_valid(ushi) and ushi.controla_movimento(): return ushi.velocidade(atual, q)
	var v := Player.SPEED * ator.speed_multiplier * maxf(0.0, 1.0 - 0.15 * float(_lentidao_do_mod() + 1))
	return Vector3(q.dir.x * v, atual.y, q.dir.z * v)


func estado_das_tecnicas() -> Array:
	var saida := []
	var teclas := {}
	var mapa := mapa_de_teclas()
	for t: String in mapa:
		teclas[int(mapa[t])] = t
	for g: Dictionary in _lista:
		if is_instance_valid(kira_investida) and not teclas.has(int(g.numero)):
			continue
		if is_instance_valid(ushi) and (int(g.numero) != UshiUshi.SKY_SLICER or ushi.forma == 2):
			continue                                     # Z/X/C do mod saem: valem os autorais (`ushi.estados()`); o V só nas formas 0 e 1
		var custo: float = g.custo
		saida.append({"nome": McTexto.traduzir(g.chave), "selecionada": int(g.numero) == selecao, "custo": custo, "tecla": str(teclas.get(int(g.numero), "")),
			"recarga": recarga_da_tecnica(int(g.numero)), "recarga_total": maxf(1.0, float(_recargas_totais.get(int(g.numero), 1.0))),
			"sem_energia": ator.energy + 0.001 < custo, "bloqueada": ator.max_energy + 0.001 < custo})
	if is_instance_valid(flor_de_buda): saida.insert(mini(1,saida.size()), flor_de_buda.estado())
	if is_instance_valid(kira_investida): saida.push_front(kira_investida.estado())
	if is_instance_valid(zushi_fujitora): saida.append_array(zushi_fujitora.estados())
	if is_instance_valid(ushi): saida = ushi.estados() + saida
	return saida
