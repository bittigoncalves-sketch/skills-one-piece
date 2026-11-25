class_name DesafioDoBuggy
extends Node
# ============================================================================
#  DESAFIO DO BUGGY (21/11/2026) — o ORQUESTRADOR (docs/DESAFIO_DO_BUGGY_PLANO.md). As regras estão em `RegrasDoDesafioBuggy`; a cena e os atores em `ChegadaDoBuggy`;
#  os copos em `JogoDosCopos`. Aqui: quando a cena toca, a bússola, a corrida dos moradores, a conversa e o encadeamento até o resultado.
#
#  Fluxo: treino entregue → CENA (navio, desembarque) → [fase "chegou"] bússola aponta o cais + moradores correm para lá → o jogador chega perto do Buggy → falas de desafio
#  → jogo dos copos → acerto (4000 XP) ou erro (a missão da luta: treinar até o nível 3 e desafiar o Buggy no ringue). Recarregar o jogo no meio refaz o cais SEM a cena (estado vem do progresso).
#  Só o jogador local vê/joga (estado no progresso dele). GATILHO: coop real → estado no host.
# ============================================================================
const CAIS := Vector3(272.0, 0.0, 40.0)            # o deck de tábuas do píer da vila (medido numa vista aérea: tábuas em x≈262–273, z≈36–44; areia até x≈259; mar depois)
const MarcadorDeMissao := preload("res://src/ui/marcador_de_missao.gd")
const RAIO_DO_BUGGY := 6.0                          # m: perto assim dele a conversa começa
const RAIO_DA_ILHA := 160.0                         # moradores mais longe que isso (outras ilhas) não correm
const TEMPO_ENTRE_VERIFICACOES := 0.5
const PASSOS_ATRAS_DA_MESA := 2.5                  # m a oeste da mesa: o Buggy fica a ~5,3 m (dentro dos 6 m da conversa)
const PASSOS_FORA_DO_RINGUE := 5.5                   # m a oeste do centro do ringue (a borda fica a 3,2 m + cordas)
const REABRIR_OFERTA_APOS := 25.0                   # s: fechou a janela sem responder → pergunta de novo só depois disto

enum Etapa { OCIOSO, CENA, CORRIDA, FALANDO, JOGANDO, OFERTA, LUTA }

var progressao: ProgressaoDoPersonagem
var hud: HistoriaHud
var npcs: NpcsDaIlha
var jogador_de: Callable
var biblioteca: BibliotecaDeModelos
var etapa := Etapa.OCIOSO

var cena: CenaCinematografica
var chegada: ChegadaDoBuggy
var _jogo: JogoDosCopos
var _bussola: Control
var _verificar_em := 0.0
var _caminhada := -1.0                # s desde o fim da cena; -1 = não está caminhando (o Buggy e a tripulação vão do deck à praia)
var _t_cena := 0.0
var _oferta_livre_em := 0.0
var _interlocutor: InterlocutorDoBuggy
var _plateia_montada := false
var _fase_ao_abrir_oferta := ""
# TRÉGUA (pedido do dono, 21/11: um inimigo atrapalhou o teste): do começo da cena até o jogador resolver os copos e a oferta, o combate fica DESLIGADO — o jogador não ataca e as
# criaturas num raio em volta dele ficam latentes (como a `ZonaDeCombate` faz). Tudo volta ao fim. GATILHO: a luta N7 (próxima fatia) precisa ligar o combate de novo no cais.
const RAIO_DA_TREGUA := 140.0
var _tregua := false
var _caps_antes: Dictionary = {}
var _em_tregua: Array = []
var _foco: Camera3D = null
var _foco_antes: Camera3D = null
var _t_foco := 0.0
var musica: MusicaDoDesafio
var luta: LutaDoBuggy                  # a luta do ringue (22/11/2026): criada na primeira vez


func _ready() -> void:
	name = "DesafioDoBuggy"
	cena = CenaCinematografica.new()
	cena.name = "CenaCinematografica"
	add_child(cena)
	musica = MusicaDoDesafio.new()
	musica.name = "MusicaDoDesafio"
	add_child(musica)
	cena.musica = musica
	cena.faixa = MusicaDoDesafio.CHEGADA
	if hud != null:
		cena.hud = hud
		cena.caixa = hud.caixa_de_fala()
		_bussola = hud.ligar_bussola_de_missao(progressao, Callable(self, "ponto_da_bussola"), jogador_de)
	if progressao != null:
		progressao.subiu_de_nivel.connect(func(_de: int, _para: int) -> void: _tentar_liberar_luta())
		_restaurar()


## Posição para onde a bússola aponta (ou null = escondida): só enquanto falta o jogador chegar ao Buggy.
func ponto_da_bussola() -> Variant:
	if progressao == null or etapa == Etapa.CENA or etapa == Etapa.LUTA:
		return null
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	# Errou os copos e ainda não tem o nível da luta: a bússola leva ao INSTRUTOR (treinar até o nível 3); depois, ao Buggy (22/11/2026).
	if RegrasDoDesafioBuggy.deve_treinar(progressao):
		var instrutor := _achar_instrutor()
		if instrutor == null or (j != null and j.global_position.distance_to(instrutor.global_position) < 4.0):
			return null
		_nomear_bussola("Instrutor")
		return instrutor.global_position
	if chegada == null:
		return null
	var f := RegrasDoDesafioBuggy.fase(progressao)
	if f != RegrasDoDesafioBuggy.CHEGOU and f != RegrasDoDesafioBuggy.COPOS_ERRADO and not RegrasDoDesafioBuggy.luta_disponivel(progressao):
		return null
	if j != null and j.global_position.distance_to(chegada.ponto_do_buggy_na_praia()) < RAIO_DO_BUGGY * 1.5:
		return null
	_nomear_bussola("Cais")
	return chegada.ponto_do_buggy_na_praia()


func _nomear_bussola(nome: String) -> void:
	if _bussola != null:
		_bussola.set("nome_do_ponto", nome)


func _achar_instrutor() -> Node3D:
	if npcs == null:
		return null
	for n in npcs.npcs:
		if is_instance_valid(n) and n.tipo == "npc_treinador":
			return n
	return null


# ------------------------------------------------------------------ restaurar (carregou o jogo no meio)
func _restaurar() -> void:
	RegrasDoDesafioBuggy.migrar(progressao)             # save antigo parado em `copos_errado`/`recusou` → a missão da luta
	if RegrasDoDesafioBuggy.fase(progressao) == RegrasDoDesafioBuggy.NADA:
		return
	_montar_cais()
	chegada.colocar_na_praia()
	_plateia_montada = false
	_chamar_plateia(true)
	etapa = Etapa.CORRIDA


func _montar_cais() -> void:
	if chegada != null:
		return
	chegada = ChegadaDoBuggy.new()
	var raiz := get_parent()
	raiz.add_child(chegada)
	var base := CAIS
	var q := PhysicsRayQueryParameters3D.create(Vector3(base.x, 40.0, base.z), Vector3(base.x, -10.0, base.z))
	var r: Dictionary = raiz.get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		base.y = float((r["position"] as Vector3).y)
	chegada.montar(base, biblioteca)


# ------------------------------------------------------------------ quadro a quadro
func _process(delta: float) -> void:
	if progressao == null:
		return
	if etapa == Etapa.CENA and chegada != null:
		if not _tregua:
			_atualizar_tregua()
		_t_cena += delta
		if _t_cena < ChegadaDoBuggy.T_CHEGADA_DO_NAVIO:
			chegada.andar_navio(_t_cena)
			chegada.colocar_no_navio()
		else:
			chegada.andar_navio(ChegadaDoBuggy.T_CHEGADA_DO_NAVIO)
		return
	if _caminhada >= 0.0 and chegada != null:
		_caminhada += delta
		if chegada.caminhar_para_a_praia(_caminhada):
			_caminhada = -1.0
	_foco_andar(delta)
	_verificar_em -= delta
	if _verificar_em > 0.0:
		return
	_verificar_em = TEMPO_ENTRE_VERIFICACOES
	_atualizar_tregua()
	_atualizar_objetivos()
	_tentar_liberar_luta()
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or hud == null or hud.is_menu_open():
		return
	match etapa:
		Etapa.OCIOSO:
			if RegrasDoDesafioBuggy.deve_chegar(progressao) and not _treino_ativo() and j.get("health") != null and float(j.health) > 0.0:
				_iniciar_cena()
		Etapa.CORRIDA:
			if chegada != null and _caminhada < 0.0 and j.global_position.distance_to(chegada.buggy.global_position) <= RAIO_DO_BUGGY:
				_ao_chegar_perto(j)


## Marcadores de missão (losango na tela) em CADA objetivo, 22/11/2026: o Buggy na missão dos copos e na da revanche (quando o nível chegou) e o instrutor na revanche
## enquanto falta nível. Ligar/desligar é barato: roda no ciclo de checagem de 0,5 s.
func _atualizar_objetivos() -> void:
	if progressao == null:
		return
	var buggy: Node3D = chegada.buggy if chegada != null else null
	var instrutor := _achar_instrutor()
	var f := RegrasDoDesafioBuggy.fase(progressao)
	MarcadorDeMissao.marcar(buggy, RegrasDoDesafioBuggy.MISSAO_COPOS, 2.9, f == RegrasDoDesafioBuggy.CHEGOU and etapa != Etapa.CENA)
	MarcadorDeMissao.marcar(buggy, RegrasDoDesafioBuggy.MISSAO_LUTA, 2.9, RegrasDoDesafioBuggy.luta_disponivel(progressao) and etapa != Etapa.LUTA)
	MarcadorDeMissao.marcar(instrutor, RegrasDoDesafioBuggy.MISSAO_LUTA, 3.6, RegrasDoDesafioBuggy.deve_treinar(progressao))


func _treino_ativo() -> bool:
	var t := get_tree().get_first_node_in_group("treino_de_soco")
	return t != null and t.has_method("ativo") and bool(t.ativo())


func _tentar_liberar_luta() -> void:
	if progressao != null and RegrasDoDesafioBuggy.liberar_luta(progressao) and hud != null:
		hud.avisar("Missão: Defender a vila. O Buggy espera por você no cais.")


# ------------------------------------------------------------------ a cena
func _legendas(estado: String, padrao: Array[Dictionary]) -> Array[Dictionary]:
	return DialogosDeNpc.linhas("buggy", estado, padrao)


func _iniciar_cena() -> void:
	_montar_cais()
	var padrao: Array[Dictionary] = [
		DialogosDeNpc.linha("Buggy", "Gyahaha! Então é esta a vila que vai pagar o meu tributo?"),
		DialogosDeNpc.linha("Buggy", "Aqui manda o Capitão Buggy, e eu gosto de jogos."),
		DialogosDeNpc.linha("Buggy", "Quem tiver coragem, venha ao cais."),
	]
	var planos := chegada.planos(_legendas("chegada", padrao))
	_t_cena = 0.0
	chegada.andar_navio(0.0)
	chegada.colocar_no_navio()
	etapa = Etapa.CENA
	if not cena.tocar(planos, _ao_fim_da_cena):
		etapa = Etapa.OCIOSO


func _ao_fim_da_cena(_pulou: bool) -> void:
	# 22/11/2026 (pedido do dono): o jogador NASCE de frente para o bando do Buggy e a conversa começa; antes ele tinha de seguir a bússola e correr até lá.
	chegada.colocar_na_praia()           # pulou ou terminou: o Buggy e a tripulação já estão na praia, sem a caminhada do deck
	_caminhada = -1.0
	RegrasDoDesafioBuggy.marcar_chegada(progressao)
	_plateia_montada = false
	_chamar_plateia(true)                # os moradores também já estão em volta da mesa
	etapa = Etapa.CORRIDA
	_levar_o_jogador_ao_bando()


## Põe o jogador a oeste da mesa, olhando para o Buggy, dentro do raio da conversa: a verificação periódica da etapa CORRIDA abre o desafio sozinha
## (`_ao_chegar_perto`), assim que a caixa de fala da cena liberar.
func _levar_o_jogador_ao_bando(passos_atras := PASSOS_ATRAS_DA_MESA) -> void:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or chegada == null:
		return
	var onde := chegada.ponto_no_chao(Vector3(ChegadaDoBuggy.POS_MESA.x - passos_atras, 0.0, ChegadaDoBuggy.POS_MESA.z))
	j.global_position = onde + Vector3.UP * 1.2
	if j is CharacterBody3D:
		(j as CharacterBody3D).velocity = Vector3.ZERO
	var para := chegada.buggy.global_position - j.global_position
	if j.get("_yaw") != null and Vector2(para.x, para.z).length_squared() > 0.01:
		j.set("_yaw", atan2(-para.x, -para.z))        # a mesma conta do Player: frente = −Z da base do yaw
	_verificar_em = 0.0                  # não espera o próximo intervalo de checagem


## Os moradores da ilha da vila vão ao cais (correndo) ou, se `ja_la`, aparecem lá (carregou o jogo).
func _chamar_plateia(ja_la: bool) -> void:
	if _plateia_montada or npcs == null or chegada == null:
		return
	_plateia_montada = true
	var moradores: Array[NpcDaIlha] = []
	for n in npcs.npcs:
		if is_instance_valid(n) and n.global_position.distance_to(CAIS) <= RAIO_DA_ILHA and not n.has_meta("morto") and not n.get_meta("escravizado", false) \
				and not NpcDaIlha.ficha(n.tipo).has("rig"):          # Barba Negra e afins (rig próprio) não são moradores da vila
			moradores.append(n)
	moradores.sort_custom(func(a: NpcDaIlha, b: NpcDaIlha) -> bool: return a.global_position.z < b.global_position.z)
	var lugares := chegada.posicoes_da_plateia(moradores.size())
	for i in moradores.size():
		var olhar := chegada.ponto_no_chao(ChegadaDoBuggy.POS_MESA) + Vector3.UP * 1.0          # todos olham para a mesa
		moradores[i].piso_minimo = ChegadaDoBuggy.PISO_DO_CAIS
		if ja_la:
			moradores[i].posicionar_em(lugares[i], olhar)
		else:
			moradores[i].correr_para(lugares[i], olhar)


# ------------------------------------------------------------------ o jogador chegou
func _ao_chegar_perto(j: Node3D) -> void:
	var f := RegrasDoDesafioBuggy.fase(progressao)
	if f == RegrasDoDesafioBuggy.CHEGOU:
		_abrir_desafio()
	elif RegrasDoDesafioBuggy.luta_disponivel(progressao):
		if Time.get_ticks_msec() / 1000.0 >= _oferta_livre_em:
			_pre_luta()
	elif f == RegrasDoDesafioBuggy.COPOS_ERRADO and Time.get_ticks_msec() / 1000.0 >= _oferta_livre_em:
		_abrir_oferta(false)


func _abrir_desafio() -> void:
	var caixa := hud.caixa_de_fala()
	if caixa == null or caixa.ativa():
		return
	var padrao: Array[Dictionary] = [
		DialogosDeNpc.linha("Buggy", "Gyahaha! Veio mesmo. Três copos, uma pedra, uma chance."),
		DialogosDeNpc.linha("Buggy", "Acerte onde a pedra está e eu te pago 4000 de experiência."),
		DialogosDeNpc.linha("Buggy", "Errou? Aí a vila fica comigo."),
	]
	etapa = Etapa.FALANDO
	_fala_do_buggy("desafio", padrao, _comecar_jogo, _legendas("regras", []))


func _comecar_jogo() -> void:
	if not RegrasDoDesafioBuggy.pode_jogar_copos(progressao):
		etapa = Etapa.CORRIDA
		return
	_jogo = JogoDosCopos.new()
	chegada.add_child(_jogo)
	_jogo.global_position = chegada.tampo_da_mesa()      # os copos ficam em cima da mesa, na praia
	_jogo.rotation.y = PI / 2.0                    # e se espalham ao longo de Z (de frente para quem vem da vila, a oeste)
	_jogo.preparar()
	_jogo.escolheu.connect(_ao_escolher)
	_jogo.terminou.connect(_ao_terminar_jogo)
	_jogo.iniciar()
	musica.tocar(MusicaDoDesafio.COPOS, true, 1.0, -9.0)             # tensão leve em loop até a escolha
	etapa = Etapa.JOGANDO
	if hud != null:
		hud.avisar("Siga a pedra. Mire num copo e aperte E.")


func _ao_escolher(acertou: bool) -> void:
	musica.parar(MusicaDoDesafio.COPOS, 0.8)
	var r := RegrasDoDesafioBuggy.resolver_copos(progressao, acertou)
	if r.is_empty():
		return
	if acertou and hud != null:
		hud.avisar("Acertou! +%d XP%s" % [int(r["xp"]), "  ·  NÍVEL %d!" % progressao.nivel if int(r["niveis"]) > 0 else ""])


func _ao_terminar_jogo() -> void:
	var acertou := _jogo != null and _jogo.acertou
	var fala_padrao: Array[Dictionary] = []
	if acertou:
		fala_padrao.append(DialogosDeNpc.linha("Buggy", "Hmpf... você achou a pedra. Palavra de pirata, a vila fica por hoje."))
	else:
		fala_padrao.append(DialogosDeNpc.linha("Buggy", "Gyahaha! Errou! Treine até o nível 3 e volte para lutar comigo no ringue."))
		fala_padrao.append(DialogosDeNpc.linha("Buggy", "Se me vencer, poupo a vila. Se não, ela é minha."))
	_limpar_jogo.call_deferred()
	var caixa := hud.caixa_de_fala()
	etapa = Etapa.FALANDO
	if acertou:
		_fala_do_buggy("acerto", fala_padrao, func() -> void: etapa = Etapa.CORRIDA)
	else:
		_fala_do_buggy("erro_n7", fala_padrao, func() -> void:
			etapa = Etapa.CORRIDA
			if hud != null:
				hud.avisar("Nova missão: Defender a vila  ·  treine com o instrutor até o nível %d (a bússola aponta) e desafie o Buggy no ringue." % RegrasDoDesafioBuggy.NIVEL_DA_LUTA))


func _limpar_jogo() -> void:
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(_jogo):
		_jogo.queue_free()
	_jogo = null


func _abrir_oferta(_depois_do_erro: bool) -> void:
	if hud == null or hud.loja_aberta():
		return
	if _interlocutor == null:
		_interlocutor = InterlocutorDoBuggy.new(progressao)
		add_child(_interlocutor)
	etapa = Etapa.OFERTA
	_fase_ao_abrir_oferta = RegrasDoDesafioBuggy.fase(progressao)
	_oferta_livre_em = Time.get_ticks_msec() / 1000.0 + REABRIR_OFERTA_APOS
	hud.abrir_loja(_interlocutor)
	if is_instance_valid(hud.janela_de_loja()) and not hud.janela_de_loja().visibility_changed.is_connected(_ao_fechar_oferta):
		hud.janela_de_loja().visibility_changed.connect(_ao_fechar_oferta)


func _ao_fechar_oferta() -> void:
	if hud != null and not hud.loja_aberta() and etapa == Etapa.OFERTA:
		etapa = Etapa.CORRIDA
		_tentar_liberar_luta()
		var f := RegrasDoDesafioBuggy.fase(progressao)
		if f != _fase_ao_abrir_oferta and (f == RegrasDoDesafioBuggy.ACEITOU or f == RegrasDoDesafioBuggy.RECUSOU):
			var padrao: Array[Dictionary] = []
			if f == RegrasDoDesafioBuggy.ACEITOU:
				padrao.append(DialogosDeNpc.linha("Buggy", "Corajoso. Treine até o nível 3 e eu te espero aqui no cais."))
			else:
				padrao.append(DialogosDeNpc.linha("Buggy", "Covarde! Então a vila já é minha. Gyahaha!"))
			_fala_do_buggy("aceitou" if f == RegrasDoDesafioBuggy.ACEITOU else "recusou", padrao, Callable())


# ------------------------------------------------------------------ conversar de novo (E perto do Buggy)
func _unhandled_input(evento: InputEvent) -> void:
	var k := evento as InputEventKey
	if k == null or not k.pressed or k.echo or not (k.keycode == KEY_E or k.physical_keycode == KEY_E):
		return
	if etapa != Etapa.CORRIDA or chegada == null or hud == null or hud.is_menu_open():
		return
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or j.global_position.distance_to(chegada.buggy.global_position) > 5.0:
		return
	var f := RegrasDoDesafioBuggy.fase(progressao)
	if RegrasDoDesafioBuggy.luta_disponivel(progressao):
		get_viewport().set_input_as_handled()
		_pre_luta()
	elif f == RegrasDoDesafioBuggy.ACEITOU or f == RegrasDoDesafioBuggy.RECUSOU or f == RegrasDoDesafioBuggy.COPOS_ERRADO:
		get_viewport().set_input_as_handled()
		_abrir_oferta(false)


# ------------------------------------------------------------------ a luta no ringue (22/11/2026)
## O Buggy provoca e a luta começa: ringue de luta livre no lugar da mesa, jogador e Buggy de luvas vermelhas (`LutaDoBuggy`).
func _pre_luta() -> void:
	var caixa := hud.caixa_de_fala()
	if caixa == null or caixa.ativa() or luta_ativa():
		return
	var padrao: Array[Dictionary] = [
		DialogosDeNpc.linha("Buggy", "Gyahaha! Treinou direitinho e ainda acha que me derruba? Ao ringue!"),
		DialogosDeNpc.linha("Buggy", "Z, X e C são os seus socos. F é para se defender. Onze vidas para cada um."),
		DialogosDeNpc.linha("Buggy", "Quem zerar o outro leva a vila. Gyahaha!"),
	]
	etapa = Etapa.FALANDO
	_fala_do_buggy("luta", padrao, _iniciar_luta)


func luta_ativa() -> bool:
	return luta != null and luta.ativa()


func _iniciar_luta() -> void:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or chegada == null or not RegrasDoDesafioBuggy.luta_disponivel(progressao):
		etapa = Etapa.CORRIDA
		return
	if luta == null:
		luta = LutaDoBuggy.new()
		luta.name = "LutaDoBuggy"
		luta.progressao = progressao
		luta.terminou.connect(_ao_fim_da_luta)
		luta.aviso.connect(func(t: String) -> void:
			if hud != null: hud.avisar(t))
		add_child(luta)
	chegada.mesa.visible = false
	var motivo := luta.iniciar(j, chegada.buggy, chegada.animador_do_buggy(), chegada.ponto_no_chao(ChegadaDoBuggy.POS_MESA))
	if not motivo.is_empty():
		chegada.mesa.visible = true
		etapa = Etapa.CORRIDA
		return
	etapa = Etapa.LUTA


func _ao_fim_da_luta(resultado: Dictionary) -> void:
	# desmonta o palco: Buggy de volta à praia, mesa de volta, jogador fora do ringue (o ringue some junto com a luta).
	chegada.mesa.visible = true
	chegada.buggy.global_position = chegada.ponto_do_buggy_na_praia()
	chegada.virar_para_terra(chegada.buggy)
	var anim := chegada.animador_do_buggy()
	if anim != null:
		anim.soltar()
	_levar_o_jogador_ao_bando(PASSOS_FORA_DO_RINGUE)
	_oferta_livre_em = Time.get_ticks_msec() / 1000.0 + 8.0        # não reabre a luta no mesmo instante
	etapa = Etapa.CORRIDA
	var venceu := bool(resultado.get("venceu", false))
	if venceu:
		var r := RegrasDaLutaDoBuggy.concluir(progressao, true)
		if not r.is_empty() and hud != null:
			hud.avisar("Vitória! +%d XP  ·  +%d moedas%s" % [int(r.get("xp_pedido", 0)), int(r.get("ouro", 0)),
				"  ·  NÍVEL %d!" % progressao.nivel if int(r.get("niveis", 0)) > 0 else ""])
			hud.avisar("Nova missão liberada: o barril da Alvida (fale com o vendedor de navios).")
		_fala_do_buggy("luta_vencida", [DialogosDeNpc.linha("Buggy", "Impossível... Tá bom, tá bom! A vila é sua. Gyahaha... ai.")], Callable())      # (a fala de derrota do ringue já saiu na luta)
	elif not bool(resultado.get("cancelado", false)):
		_fala_do_buggy("luta_perdida", [DialogosDeNpc.linha("Buggy", "Gyahaha! Fraco! Volte quando souber se defender. Fale comigo (E) para lutar de novo.")], Callable())


# ------------------------------------------------------------------ trégua (combate desligado durante o desafio)
func quer_tregua() -> bool:
	if progressao == null:
		return false
	var f := RegrasDoDesafioBuggy.fase(progressao)
	return etapa == Etapa.CENA or f == RegrasDoDesafioBuggy.CHEGOU or f == RegrasDoDesafioBuggy.COPOS_ERRADO


func tregua_ativa() -> bool:
	return _tregua


func _atualizar_tregua() -> void:
	var quer := quer_tregua()
	if quer and not _tregua:
		_ligar_tregua()
	elif not quer and _tregua:
		_desligar_tregua()
	if _tregua:
		_varrer_criaturas()


func _ligar_tregua() -> void:
	_tregua = true
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j != null and j.get("capacidades") != null:
		var c = j.capacidades
		_caps_antes = {"can_attack": c.can_attack, "can_use_skills": c.can_use_skills, "can_use_fruit": c.can_use_fruit}
		c.can_attack = false
		c.can_use_skills = false
		c.can_use_fruit = false
	if hud != null:
		hud.avisar("Combate desativado durante o desafio do Buggy.")


func _desligar_tregua() -> void:
	_tregua = false
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j != null and j.get("capacidades") != null and not _caps_antes.is_empty():
		var c = j.capacidades
		c.can_attack = bool(_caps_antes.get("can_attack", true))
		c.can_use_skills = bool(_caps_antes.get("can_use_skills", true))
		c.can_use_fruit = bool(_caps_antes.get("can_use_fruit", true))
	_caps_antes = {}
	for no in _em_tregua:
		if is_instance_valid(no) and no.has_meta("em_tregua_do_buggy"):
			no.remove_meta("em_tregua_do_buggy")
			Povoamento.latente(no, false)
	_em_tregua.clear()


## Criaturas hostis/animais num raio em volta do jogador ficam latentes (paradas e escondidas) enquanto durar a trégua; as que nascem depois entram na próxima varredura.
func _varrer_criaturas() -> void:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return
	for g in ZonaDeCombate.GRUPOS:
		for no in get_tree().get_nodes_in_group(g):
			if not (no is Node3D) or not is_instance_valid(no) or no.has_meta("em_tregua_do_buggy") or ZonaDeCombate.e_intocavel(no):
				continue
			if (no as Node3D).global_position.distance_to(j.global_position) <= RAIO_DA_TREGUA:
				Povoamento.latente(no, true)
				no.set_meta("em_tregua_do_buggy", true)
				_em_tregua.append(no)


# ------------------------------------------------------------------ foco da câmera no rosto do Buggy quando ele fala
## Fala do Buggy com a câmera no ROSTO dele, expressão por linha e gestos. `estado` escolhe as legendas (`DialogosDeNpc`, "buggy.json") e a expressão; `ao_fim` roda UMA vez.
func _fala_do_buggy(estado: String, padrao: Array[Dictionary], ao_fim: Callable, extra: Array[Dictionary] = []) -> void:
	var caixa := hud.caixa_de_fala()
	if estado == "erro_n7" or estado == "recusou":
		musica.tocar(MusicaDoDesafio.STING, false, 0.05, -4.0)          # a gargalhada instrumental do Buggy
	var linhas := _legendas(estado, padrao) + extra
	var anim := chegada.animador_do_buggy()
	_foco_no_rosto(true)
	ExpressoesDoBuggy.expressao(chegada.buggy, ExpressoesDoBuggy.do_estado(estado))
	if anim != null:
		anim.falar(true)
	if not caixa.linha_mudou.is_connected(_ao_mudar_linha):
		caixa.linha_mudou.connect(_ao_mudar_linha)
	caixa.tocar(linhas, func() -> void:
		_foco_no_rosto(false)
		if anim != null:
			anim.falar(false)
		ExpressoesDoBuggy.expressao(chegada.buggy, "neutro")
		if ao_fim.is_valid():
			ao_fim.call())


func _ao_mudar_linha(_i: int, linha: Dictionary) -> void:
	var expr := str(linha.get("expressao", ""))
	if not expr.is_empty() and chegada != null:
		ExpressoesDoBuggy.expressao(chegada.buggy, expr)


func _foco_no_rosto(ligar: bool) -> void:
	if ligar:
		if _foco != null or chegada == null:
			return
		_foco_antes = get_viewport().get_camera_3d()
		_foco = Camera3D.new()
		_foco.name = "CameraDoRosto"
		add_child(_foco)
		_foco.fov = 32.0
		_t_foco = 0.0
		_foco_andar(0.0)
		_foco.current = true
	elif _foco != null:
		if _foco_antes != null and is_instance_valid(_foco_antes):
			_foco_antes.current = true
		_foco.queue_free()
		_foco = null


## A câmera do rosto fica entre o Buggy e o jogador e se aproxima devagar (dolly) enquanto ele fala.
func _foco_andar(delta: float) -> void:
	if _foco == null or chegada == null:
		return
	_t_foco += delta
	var rosto := chegada.rosto_do_buggy()
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	var para_j := Vector3(-1.0, 0.0, 0.0)
	if j != null:
		para_j = Vector3(j.global_position.x - rosto.x, 0.0, j.global_position.z - rosto.z)
		para_j = para_j.normalized() if para_j.length() > 0.1 else Vector3(-1.0, 0.0, 0.0)
	var lado := para_j.cross(Vector3.UP) * 0.4
	var dist := lerpf(2.5, 1.7, smoothstep(0.0, 10.0, _t_foco))
	_foco.global_position = rosto + para_j * dist + lado + Vector3.UP * 0.12
	_foco.look_at(rosto, Vector3.UP)
