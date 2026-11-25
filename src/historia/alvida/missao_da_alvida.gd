class_name MissaoDaAlvida
extends Node
# ============================================================================
#  MISSÃO DA ALVIDA (22/11/2026, 5ª missão) — o ORQUESTRADOR. Regras/estado/prêmio: `RegrasDaAlvida`; duelo: `DueloPpt`; atores e câmeras: `PalcoDaAlvida`; HUD: `HudDoDuelo`; boca: `BocaFalante`.
#  Fluxo (pedido do dono): baú entregue → a missão entra e a BÚSSOLA aponta o vendedor de navios → conversa em cena de rosto (câmera no rosto de quem fala, boca trocando de textura) → quem
#  ACERTOU os copos do Buggy recebe o BARRIL → o jogador "aparece no mar" DENTRO do barril fechado → o barril é pescado para o navio da Alvida → aberto → "um invasor!" → duelo de
#  pedra-papel-tesoura (7 vidas; empate = desvio) → vitória: cena de saída para a Ilha dos Macacos, 1000 moedas + 8000 XP · derrota: Ilha dos Macacos sem os itens (só os permanentes).
#  Quem errou os copos: o vendedor só fala (`sem_vitoria`) e a loja abre normal — sem barril (decisão do dono, 22/11).
#
#  POLÍTICA DE INTERRUPÇÃO: nada da cena/duelo é salvo. Fechar o jogo no meio = recomeçar pela conversa; NUNCA se atribui derrota ou prêmio sem o duelo acabar. O prêmio/penalidade é registrado NO
#  INSTANTE em que o duelo termina (antes da cena de saída), então pular a cena (ESC) não perde nem repete nada (`RegrasDaAlvida` é idempotente).
#  Só o jogador local vive isto (estado no progresso dele). GATILHO: coop real → o duelo roda no cliente dono e o servidor valida o resultado.
# ============================================================================
const ANCORA_DO_MAR := Vector3(430.0, 0.0, 40.0)      # mar aberto a leste do cais da vila (a ilha inicial termina em x=256; o píer chega a 280)
const VENDEDOR := "npc_vendedor_barcos"
const TEMPO_ENTRE_VERIFICACOES := 0.5
enum Etapa { OCIOSO, CONVERSA, BARRIL, DUELO, DESFECHO }

var progressao: ProgressaoDoPersonagem
var hud: HistoriaHud
var npcs: NpcsDaIlha
var jogador_de: Callable
var biblioteca: BibliotecaDeModelos
var ir_a_ilha: Callable = Callable()               # (id) -> bool: `ModoHistoria.ir_a_ilha`
var escala_de_tempo := 1.0                          # os testes encolhem as esperas (nunca as regras)
var etapa := Etapa.OCIOSO
var cena: CenaCinematografica
var musica: MusicaDoDesafio
var palco: PalcoDaAlvida
var duelo: DueloPpt
var hud_duelo: HudDoDuelo
var duelo_sorteio: Callable = Callable()            # injeta o sorteio da Alvida nos testes
var resultado := ""                                 # "vitoria" | "derrota" quando o duelo acaba (só leitura/testes)

var _bussola: Control
var _verificar_em := 0.0
var _avisou_missao := false
var _vendedor: NpcDaIlha
var _boca_do_vendedor: BocaFalante
var _caps_antes: Dictionary = {}
var _imune_antes := false
var _camera_duelo: Camera3D
var _camera_antes: Camera3D
var _veu: ColorRect
var _barril_do_vendedor: Node3D
var _em_rodada := false
var _tentativa := ""                               # id do duelo em curso: a derrota só vale uma vez por duelo


func _ready() -> void:
	name = "MissaoDaAlvida"
	cena = CenaCinematografica.new()
	cena.name = "CenaCinematografica"
	add_child(cena)
	musica = MusicaDoDesafio.new()
	musica.name = "MusicaDaAlvida"
	add_child(musica)
	cena.musica = null                              # a música da missão é minha (loop contínuo até o fim)
	if hud != null:
		cena.hud = hud
		cena.caixa = hud.caixa_de_fala()
		_bussola = hud.ligar_bussola_de_missao(progressao, Callable(self, "ponto_da_bussola"), jogador_de, "Vendedor")


## Para onde a bússola aponta (null = escondida): o vendedor de navios enquanto a missão está aceita e o duelo não aconteceu.
func ponto_da_bussola() -> Variant:
	if progressao == null or etapa != Etapa.OCIOSO:
		return null
	# Só LIBERADO: quem ainda não venceu o Buggy (`SEM_VITORIA`) não tem o que fazer com o vendedor — a bússola leva ao instrutor/Buggy (`DesafioDoBuggy`), 22/11/2026.
	if RegrasDaAlvida.situacao(progressao) != RegrasDaAlvida.LIBERADO:
		return null
	var v := _achar_vendedor()
	if v == null:
		return null
	var j := _jogador()
	if j != null and j.global_position.distance_to(v.global_position) < 4.0:
		return null
	return v.global_position


func _jogador() -> Node3D:
	return jogador_de.call() if jogador_de.is_valid() else null


func _achar_vendedor() -> NpcDaIlha:
	if is_instance_valid(_vendedor):
		return _vendedor
	if npcs == null:
		return null
	for n in npcs.npcs:
		if is_instance_valid(n) and n.tipo == VENDEDOR:
			_vendedor = n
			var loja := n.loja()
			if loja != null:
				loja.set("ao_conversar", Callable(self, "ao_conversar"))      # a HUD pergunta antes de abrir a loja
			return n
	return null


func _process(delta: float) -> void:
	if etapa != Etapa.OCIOSO:
		_manter_trava()
	_verificar_em -= delta
	if _verificar_em > 0.0 or progressao == null:
		return
	_verificar_em = TEMPO_ENTRE_VERIFICACOES
	_achar_vendedor()
	if RegrasDaAlvida.recuperar(progressao) and hud != null:
		hud.avisar("Missão da Alvida concluída: recompensa entregue.")
	if RegrasDaAlvida.liberar(progressao) and hud != null and not _avisou_missao:
		_avisou_missao = true
		hud.avisar("Missão: O barril da Alvida. Procure o vendedor de navios (bússola).")


# ------------------------------------------------------------------ a conversa
## Chamada pela loja do vendedor ao apertar E: devolve true se a conversa foi tomada pela missão (a loja NÃO abre agora).
func ao_conversar() -> bool:
	if etapa != Etapa.OCIOSO:
		return true
	match RegrasDaAlvida.situacao(progressao):
		RegrasDaAlvida.LIBERADO:
			_conversa_do_barril()
			return true
		RegrasDaAlvida.SEM_VITORIA:
			_conversa_sem_vitoria()
			return true
	return false


func _linhas(id: String, estado: String, padrao: Array[Dictionary]) -> Array[Dictionary]:
	return DialogosDeNpc.linhas(id, estado, padrao)


func _dur_da_linha(texto: String) -> float:
	return maxf(2.4, texto.length() * 0.065 + 1.3) * escala_de_tempo


## Um plano de fala: close no rosto do falante, legenda, boca mexendo (menos na pausa final) e, opcionalmente, um gesto.
func _plano_de_fala(ator: Node3D, boca: BocaFalante, linha: Dictionary, gesto := "", distancia := 1.25) -> Dictionary:
	var texto := str(linha.get("texto", ""))
	var dur := _dur_da_linha(texto)
	var cam := PalcoDaAlvida.close_do_rosto(ator, distancia)
	var de: Vector3 = cam["de"]
	var para: Vector3 = cam["para"]
	var pausa := 0.45 * maxf(escala_de_tempo, 0.2)
	var entrar := func() -> void:
		if boca != null:
			boca.falar(true)
		if not gesto.is_empty():
			var a := ator.find_child("AnimacoesDoElenco", true, false) as AnimacoesDoElenco
			if a != null:
				a.gesto(gesto)
	var atualizar := func(t: float, d: float) -> void:
		if boca != null and t > d - pausa:
			boca.falar(false)
	return {
		"dur": dur, "de": de, "para": para, "fov": float(cam["fov"]),
		"de_fim": de + (para - de).normalized() * 0.18,                  # dolly lento de aproximação
		"legenda": {"falante": str(linha.get("falante", "")), "texto": texto},
		"ao_entrar": entrar, "atualizar": atualizar,
	}


func _conversa_sem_vitoria() -> void:
	var v := _achar_vendedor()
	var j := _jogador()
	if v == null or j == null:
		return
	etapa = Etapa.CONVERSA
	_congelar(j, true)
	v.posicionar_em(v.global_position, j.global_position)
	var corpo := v.get_node("Corpo") as Node3D
	_boca_do_vendedor = _boca_do_vendedor if is_instance_valid(_boca_do_vendedor) else BocaFalante.de(corpo)
	var padrao: Array[Dictionary] = [DialogosDeNpc.linha("Vendedor de navios", "Ouvi falar do desafio dos copos. Você encontrou a pedra?")]
	var planos: Array[Dictionary] = []
	for l in _linhas("vendedor_barcos_barril", "sem_vitoria", padrao):
		planos.append(_plano_de_fala(corpo, _boca_do_vendedor, l))
	var ao_fim := func(_pulou: bool) -> void:
		if _boca_do_vendedor != null:
			_boca_do_vendedor.falar(false)
		_congelar(j, false)
		etapa = Etapa.OCIOSO
		if hud != null:
			hud.abrir_loja(v)                                         # sem barril: a loja é a de sempre
	if not cena.tocar(planos, ao_fim):
		_congelar(j, false)
		etapa = Etapa.OCIOSO


func _conversa_do_barril() -> void:
	var v := _achar_vendedor()
	var j := _jogador()
	if v == null or j == null:
		return
	etapa = Etapa.CONVERSA
	_preparar_jogador(j)
	v.posicionar_em(v.global_position, j.global_position)
	var corpo := v.get_node("Corpo") as Node3D
	_boca_do_vendedor = _boca_do_vendedor if is_instance_valid(_boca_do_vendedor) else BocaFalante.de(corpo)
	var padrao: Array[Dictionary] = [
		DialogosDeNpc.linha("Vendedor de navios", "Então você venceu o desafio dos copos do Buggy?"),
		DialogosDeNpc.linha("Vendedor de navios", "Tenho um jeito de levar você para o mar: entre neste barril."),
	]
	var planos: Array[Dictionary] = []
	for l in _linhas("vendedor_barcos_barril", "encontro", padrao):
		planos.append(_plano_de_fala(corpo, _boca_do_vendedor, l))
	var entrega: Array[Dictionary] = [DialogosDeNpc.linha("Vendedor de navios", "Feche a tampa e fique firme. Boa viagem!")]
	for l in _linhas("vendedor_barcos_barril", "entrega_barril", entrega):
		var p := _plano_de_fala(corpo, _boca_do_vendedor, l)
		# plano médio: o vendedor olha o jogador e entrega o barril (o barril aparece entre os dois)
		var meio := (v.global_position + j.global_position) * 0.5
		var lado := (j.global_position - v.global_position).cross(Vector3.UP).normalized()
		p["de"] = meio + lado * 3.4 + Vector3.UP * 1.5
		p["para"] = meio + Vector3.UP * 1.0
		p["de_fim"] = p["de"]
		p["para_fim"] = p["para"]
		p["fov"] = 50.0
		var antes: Callable = p["ao_entrar"]
		p["ao_entrar"] = func() -> void:
			antes.call()
			_mostrar_barril_do_vendedor(meio)
		planos.append(p)
	var ao_fim := func(_pulou: bool) -> void:
		if _boca_do_vendedor != null:
			_boca_do_vendedor.falar(false)
		_remover_barril_do_vendedor()
		_ao_receber_o_barril()
	if not cena.tocar(planos, ao_fim):
		_encerrar()


func _mostrar_barril_do_vendedor(onde: Vector3) -> void:
	_remover_barril_do_vendedor()
	_barril_do_vendedor = PalcoDaAlvida.carregar(biblioteca, PalcoDaAlvida.BARRIL)
	get_parent().add_child(_barril_do_vendedor)
	_barril_do_vendedor.scale = Vector3.ONE * PalcoDaAlvida.ESCALA_DO_BARRIL * 0.8
	_barril_do_vendedor.global_position = Vector3(onde.x, _chao_em(onde), onde.z)


func _remover_barril_do_vendedor() -> void:
	if is_instance_valid(_barril_do_vendedor):
		_barril_do_vendedor.queue_free()
	_barril_do_vendedor = null


func _chao_em(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 6.0, p.z), Vector3(p.x, p.y - 10.0, p.z))
	var r := get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return float((r["position"] as Vector3).y) if not r.is_empty() else p.y


# ------------------------------------------------------------------ o barril, o mar, o navio
func _ao_receber_o_barril() -> void:
	etapa = Etapa.BARRIL
	_montar_palco()
	await get_tree().physics_frame                  # o piso novo precisa existir na física antes de alguém pisar nele
	if not is_inside_tree() or palco == null:
		_encerrar()
		return
	musica.tocar(MusicaDoDesafio.COPOS, true, 1.5, -9.0)
	var j := _jogador()
	if j != null:
		j.global_position = palco.porto_do_barril() + Vector3.UP * 0.5       # o jogador "aparece no mar" (escondido dentro do barril)
		j.velocity = Vector3.ZERO
		j.visible = false
	var planos := _planos_do_barril()
	var ao_fim := func(_pulou: bool) -> void: _comecar_o_duelo()
	if not cena.tocar(planos, ao_fim):
		_comecar_o_duelo()


func _montar_palco() -> void:
	if palco != null:
		palco.queue_free()
	palco = PalcoDaAlvida.new()
	get_parent().add_child(palco)
	palco.montar(ANCORA_DO_MAR, biblioteca)


func _planos_do_barril() -> Array[Dictionary]:
	var planos: Array[Dictionary] = []
	var s := maxf(escala_de_tempo, 0.01)
	var conves_y := PalcoDaAlvida.CONVES_Y
	var porto := palco.porto_do_barril()
	# 1 — o jogador entra no barril e ele é posto no mar: câmera de TERCEIRA PESSOA (como a do jogador, atrás e acima), vendo o barril fechado boiar e balançar
	var entrar1 := func() -> void: palco.colocar_barril(0.0)
	var atualizar1 := func(_t: float, _d: float) -> void: palco.colocar_barril(0.0)
	planos.append({
		"dur": 6.0 * s, "de": porto + Vector3(6.0, 2.6, 2.5), "para": porto + Vector3(0, 0.9, 0), "de_fim": porto + Vector3(4.6, 2.2, 3.6), "para_fim": porto + Vector3(0, 0.9, 0), "fov": 55.0,
		"ao_entrar": entrar1, "atualizar": atualizar1,
	})
	# 2 — de fora: o barril é pescado (içado) para o convés
	var entrar2 := func() -> void:
		for i in palco.tripulacao.size():
			palco.gesto(palco.tripulacao[i], "right_arm_up" if i % 2 == 0 else "clap")
	var atualizar2 := func(t: float, d: float) -> void: palco.colocar_barril(clampf(t / d, 0.0, 1.0))
	planos.append({
		"dur": 9.0 * s,
		"de": palco.ponto_do_navio(Vector3(25.0, conves_y + 2.5, 16.0)), "para": palco.ponto_do_navio(Vector3(9.0, conves_y + 2.5, 8.0)),
		"de_fim": palco.ponto_do_navio(Vector3(20.0, conves_y + 5.5, 14.0)), "para_fim": palco.ponto_do_navio(Vector3(2.0, conves_y + 1.5, 9.5)), "fov": 55.0,
		"ao_entrar": entrar2, "atualizar": atualizar2,
	})
	# 3 — Alvida manda abrir
	var padrao: Array[Dictionary] = [
		DialogosDeNpc.linha("Alvida", "O que vocês pescaram? Abram esse barril!"),
		DialogosDeNpc.linha("Alvida", "Um invasor? Vamos resolver isso de uma vez."),
	]
	var abertura := _linhas("alvida", "abertura", padrao)
	var boca_a: BocaFalante = palco.bocas.get(palco.alvida)
	var p3 := _plano_de_fala(palco.alvida, boca_a, abertura[0])
	var base3: Callable = p3["ao_entrar"]
	p3["ao_entrar"] = func() -> void:
		palco.colocar_barril(1.0)
		palco.abrir_tampa(0.0)
		base3.call()
	planos.append(p3)
	# 4 — o barril no convés: a tampa salta (visto de fora, de perto)
	var centro := palco.ponto_da_arena(Vector3(0.0, 0.9, 0.0))
	var atualizar4 := func(t: float, d: float) -> void:
		palco.abrir_tampa(clampf((t / d - 0.3) / 0.5, 0.0, 1.0))
	planos.append({
		"dur": 3.2 * s, "de": centro + Vector3(-3.4, 1.4, -3.0), "para": centro, "de_fim": centro + Vector3(-2.6, 1.7, -2.4), "para_fim": centro + Vector3(0, 0.4, 0), "fov": 50.0,
		"atualizar": atualizar4,
	})
	# 5 — a Alvida: "Um invasor? Vamos resolver isso de uma vez." — e o duelo começa logo em seguida (sem explicar as regras)
	var p5 := _plano_de_fala(palco.alvida, boca_a, abertura[1], "right_arm_up", 1.15)
	var base5: Callable = p5["ao_entrar"]
	p5["ao_entrar"] = func() -> void:
		palco.abrir_tampa(1.0)
		base5.call()
	planos.append(p5)
	return planos


# ------------------------------------------------------------------ o duelo
func _comecar_o_duelo() -> void:
	if palco == null:
		_encerrar()
		return
	etapa = Etapa.DUELO
	_tentativa = "%d_%d" % [Time.get_ticks_usec(), randi()]
	palco.barril.visible = false
	palco.corda.visible = false
	var j := _jogador()
	if j != null:
		j.global_position = palco.lugar_do_jogador() + Vector3.UP * 0.1
		j.velocity = Vector3.ZERO
		j.visible = true
		var yaw := -PI / 2.0                                          # olha para +X (a Alvida)
		if j.get("_yaw") != null:
			j._yaw = yaw
			j._update_pivot()
		var modelo: Variant = j.get("_char_model")
		if modelo is Node3D:
			(modelo as Node3D).rotation.y = yaw
	_camera_antes = get_viewport().get_camera_3d()
	_camera_duelo = Camera3D.new()
	_camera_duelo.name = "CameraDoDuelo"
	add_child(_camera_duelo)
	var cam := palco.plano_aberto_do_duelo()
	_camera_duelo.fov = float(cam["fov"])
	_camera_duelo.current = true
	_camera_duelo.global_position = cam["de"]
	_camera_duelo.look_at(cam["para"], Vector3.UP)
	if hud != null:
		hud.modo_cinema(true)
	duelo = DueloPpt.new()
	duelo.sorteio = duelo_sorteio
	duelo.sortear()                                               # a Alvida escolhe ANTES do jogador
	hud_duelo = HudDoDuelo.new()
	add_child(hud_duelo)
	hud_duelo.escolheu.connect(_ao_escolher)
	hud_duelo.bloquear(false)
	hud_duelo.mostrar_texto("Escolha: Pedra, Papel ou Tesoura")


func _ao_escolher(jogada: int) -> void:
	if etapa != Etapa.DUELO or duelo == null or _em_rodada or not is_instance_valid(hud_duelo):
		return                                                        # escolha no meio da animação (ou fora do duelo): ignorada
	hud_duelo.bloquear(true)
	var r := duelo.jogar(jogada)
	if r.is_empty():
		if not duelo.terminou():
			hud_duelo.bloquear(false)                                 # jogada inválida: devolve os botões
		return
	_em_rodada = true
	await _rodada(r)
	_em_rodada = false


func _esperar(s: float) -> void:
	await get_tree().create_timer(maxf(s * escala_de_tempo, 0.001)).timeout


func _vivo() -> bool:
	return is_inside_tree() and etapa == Etapa.DUELO and palco != null and is_instance_valid(hud_duelo)


## Uma rodada: revela as jogadas, anima (desvio / golpe / dano), atualiza os corações e, se o duelo acabou, vai ao desfecho. Os botões ficam bloqueados do clique ao fim da animação.
func _rodada(r: Dictionary) -> void:
	hud_duelo.mostrar_texto(hud_duelo.texto_da_revelacao(r))
	var j := _jogador()
	await _esperar(0.8)
	if not _vivo():
		return
	var evento := str(r["evento"])
	match evento:
		DueloPpt.EMPATE:
			palco.gesto(palco.alvida, "sword_overhead")                    # a Alvida ataca…
			await _esperar(0.45)
			_jogador_desvia(j)                                             # …e o jogador desvia
			await _esperar(1.0)
		DueloPpt.ACERTO_DO_JOGADOR:
			_jogador_ataca(j)
			await _esperar(0.55)
			if not _vivo():
				return
			hud_duelo.atualizar_vidas(int(r["vidas_do_jogador"]), int(r["vidas_da_alvida"]))
			palco.gesto(palco.alvida, "backstep")
			_empurrar(palco.alvida, Vector3.RIGHT * 0.7)
			_tremer()
			await _esperar(1.0)
		_:
			palco.gesto(palco.alvida, "sword_overhead")
			await _esperar(0.55)
			if not _vivo():
				return
			hud_duelo.atualizar_vidas(int(r["vidas_do_jogador"]), int(r["vidas_da_alvida"]))
			_jogador_recebe(j)
			_tremer()
			await _esperar(1.0)
	if not _vivo():
		return
	hud_duelo.atualizar_vidas(int(r["vidas_do_jogador"]), int(r["vidas_da_alvida"]))
	if bool(r["terminou"]):
		_desfecho(str(r["vencedor"]) == "jogador")
		return
	duelo.sortear()
	hud_duelo.mostrar_texto("Escolha: Pedra, Papel ou Tesoura")
	hud_duelo.bloquear(false)


func _jogador_ataca(j: Node3D) -> void:
	if j != null and j.has_method("play_style_anim"):
		j.play_style_anim("punching")
	_empurrar(j, Vector3.RIGHT * 0.5, 0.25)


func _jogador_desvia(j: Node3D) -> void:
	if j != null and j.has_method("play_style_anim"):
		j.play_style_anim("falling_to_roll")
	_empurrar(j, Vector3(0, 0, -1.6), 0.35)                   # rola para o lado e volta


func _jogador_recebe(j: Node3D) -> void:
	if j != null and j.has_method("play_style_anim"):
		j.play_style_anim("hard_landing")
	_empurrar(j, Vector3.LEFT * 0.7, 0.2)


## Desloca `no` por `delta` em `t` s; `volta` = depois retorna ao ponto de partida (golpe, desvio, dano); sem ela o corpo fica onde chegou (caminhada).
func _empurrar(no: Node3D, delta: Vector3, t := 0.2, volta := true) -> void:
	if no == null or not is_instance_valid(no):
		return
	var origem := no.global_position
	var tw := create_tween()
	tw.tween_property(no, "global_position", origem + delta, maxf(t * escala_de_tempo, 0.001))
	if volta:
		tw.tween_property(no, "global_position", origem, maxf(0.4 * escala_de_tempo, 0.001))


func _tremer() -> void:
	if not is_instance_valid(_camera_duelo):
		return
	var base := _camera_duelo.global_position
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_camera_duelo, "global_position", base + Vector3(randf_range(-0.12, 0.12), randf_range(-0.08, 0.08), 0), 0.04 * maxf(escala_de_tempo, 0.01))
	tw.tween_property(_camera_duelo, "global_position", base, 0.06 * maxf(escala_de_tempo, 0.01))


# ------------------------------------------------------------------ desfecho
func _desfecho(venceu: bool) -> void:
	etapa = Etapa.DESFECHO
	resultado = "vitoria" if venceu else "derrota"
	if is_instance_valid(hud_duelo):
		hud_duelo.queue_free()
		hud_duelo = null
	# prêmio / penalidade: AGORA (idempotente) — pular a cena depois não muda nada
	var pago := RegrasDaAlvida.registrar_vitoria(progressao) if venceu else RegrasDaAlvida.registrar_derrota(progressao, _tentativa)
	var j := _jogador()
	var boca_a: BocaFalante = palco.bocas.get(palco.alvida)
	var estado := "vitoria" if venceu else "derrota"
	var padrao: Array[Dictionary] = [DialogosDeNpc.linha("Alvida", "Você venceu! Saia do meu navio!" if venceu else "Acabou! Joguem esse invasor de volta à ilha!")]
	var planos: Array[Dictionary] = []
	for l in _linhas("alvida", estado, padrao):
		var p := _plano_de_fala(palco.alvida, boca_a, l, "death" if venceu else "both_arm_up")
		planos.append(p)
	# saída: o jogador anda até a amurada (vitória) ou é derrubado e levado (derrota) — plano aberto
	var aberto := palco.plano_aberto_do_duelo()
	var dur_saida := 4.5 * maxf(escala_de_tempo, 0.01)
	var entrar_saida := func() -> void:
		if j != null and is_instance_valid(j) and j.has_method("play_style_anim"):
			j.play_style_anim("walking" if venceu else "dying")
		if venceu:
			_empurrar(j, Vector3(7.5, 0, 0), 4.0, false)               # caminha até a borda de boreste
		_fade(1.0, dur_saida * 0.85)
	planos.append({"dur": dur_saida, "de": aberto["de"], "para": aberto["para"], "fov": 55.0, "ao_entrar": entrar_saida})
	var ao_fim := func(_pulou: bool) -> void: _ir_para_a_ilha(venceu, pago)
	if hud != null:
		hud.modo_cinema(false)                                        # o duelo escondia a HUD; a cena liga de novo (sem aninhar)
	if not cena.tocar(planos, ao_fim):
		_ir_para_a_ilha(venceu, pago)


func _fade(alvo: float, dur: float) -> void:
	if not is_instance_valid(_veu):
		var camada := CanvasLayer.new()
		camada.layer = 100
		camada.name = "VeuDaAlvida"
		_veu = ColorRect.new()
		_veu.color = Color(0, 0, 0, 0)
		_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
		camada.add_child(_veu)
		add_child(camada)
	create_tween().tween_property(_veu, "color:a", alvo, maxf(dur, 0.001))


func _ir_para_a_ilha(venceu: bool, pago: Dictionary) -> void:
	_fade(1.0, 0.05)
	if is_instance_valid(_camera_duelo):
		_camera_duelo.queue_free()
		_camera_duelo = null
	if _camera_antes != null and is_instance_valid(_camera_antes):
		_camera_antes.current = true
	var j := _jogador()
	if j != null:
		j.visible = true
		j.velocity = Vector3.ZERO
	if palco != null:
		palco.queue_free()
		palco = null
	if ir_a_ilha.is_valid():
		ir_a_ilha.call(RegrasDaAlvida.ILHA_DE_VOLTA)
		var limite := 8.0
		while limite > 0.0 and j != null and is_instance_valid(j) and j.global_position.x < 1300.0:
			await get_tree().create_timer(0.1).timeout
			limite -= 0.1
	await get_tree().physics_frame
	if hud != null:
		hud.modo_cinema(false)
	_chegada_na_ilha(venceu, pago)


## Cena curta na Ilha dos Macacos: o jogador chega (a câmera dá uma volta) com a legenda do que mudou; depois tudo volta ao normal.
func _chegada_na_ilha(venceu: bool, pago: Dictionary) -> void:
	var j := _jogador()
	if j == null:
		_encerrar()
		return
	var texto := "Você venceu a Alvida: +%d moedas  ·  +%d XP." % [int(pago.get("ouro", 0)), int(pago.get("xp", 0))] if venceu \
		else "Você perdeu o duelo. Os itens que carregava ficaram no navio da Alvida."
	var p := j.global_position + Vector3.UP * 1.3
	var entrar := func() -> void: _fade(0.0, 1.2 * maxf(escala_de_tempo, 0.01))
	var lista: Array[Dictionary] = [{
		"dur": 5.0 * maxf(escala_de_tempo, 0.01), "de": p + Vector3(3.2, 0.7, 4.2), "para": p, "de_fim": p + Vector3(-3.4, 0.9, 3.8), "para_fim": p, "fov": 50.0,
		"legenda": {"falante": "Ilha dos Macacos", "texto": texto}, "ao_entrar": entrar,
	}]
	var fim := func(_pulou: bool) -> void:
		if hud != null:
			hud.avisar(texto)
		_encerrar()
	if not cena.tocar(lista, fim):
		fim.call(false)


# ------------------------------------------------------------------ preparar / encerrar (SEMPRE restaura)
func _preparar_jogador(j: Node3D) -> void:
	_congelar(j, true)
	if j != null:
		_imune_antes = bool(j.get_meta("damage_immune", false))
		j.set_meta("damage_immune", true)
		var c: Variant = j.get("capacidades")
		if c != null:
			_caps_antes = {"can_attack": c.can_attack, "can_use_skills": c.can_use_skills, "can_use_fruit": c.can_use_fruit}
			c.can_attack = false
			c.can_use_skills = false
			c.can_use_fruit = false


## `ModoHistoria.aplicar_progressao` troca `jogador.capacidades` a cada `progressao.mudou` (a sobrevivência emite a cada 15 s): a trava de combate é REAPLICADA todo quadro enquanto há cena/duelo.
func _manter_trava() -> void:
	if _caps_antes.is_empty():
		return                                    # só o fluxo do barril liga trava/imunidade (`_preparar_jogador`); a conversa `sem_vitoria` não mexe em nada
	var j := _jogador()
	if j == null or not is_instance_valid(j):
		return
	var c: Variant = j.get("capacidades")
	if c != null and (c.can_attack or c.can_use_skills or c.can_use_fruit):
		c.can_attack = false
		c.can_use_skills = false
		c.can_use_fruit = false
	j.set_meta("damage_immune", true)


func _congelar(j: Node3D, sim: bool) -> void:
	if j != null and is_instance_valid(j):
		j.set_meta("em_cena", sim)                         # pausa fome/sede (sobrevivencia.gd)
		j.set_meta("is_frozen", sim)
		if sim:
			j.velocity = Vector3.ZERO


## Devolve TUDO: jogador, câmera, HUD, música, palco, véus. Idempotente (pode ser chamada de qualquer ponto).
func _encerrar() -> void:
	var j := _jogador()
	if j != null and is_instance_valid(j):
		j.visible = true
		j.set_meta("is_frozen", false)
		j.set_meta("em_cena", false)
		if _imune_antes:
			j.set_meta("damage_immune", true)
		else:
			j.remove_meta("damage_immune")
		var c: Variant = j.get("capacidades")
		if c != null and not _caps_antes.is_empty():
			c.can_attack = bool(_caps_antes.get("can_attack", true))
			c.can_use_skills = bool(_caps_antes.get("can_use_skills", true))
			c.can_use_fruit = bool(_caps_antes.get("can_use_fruit", true))
	_caps_antes = {}
	_imune_antes = false
	_remover_barril_do_vendedor()
	if is_instance_valid(hud_duelo):
		hud_duelo.queue_free()
	hud_duelo = null
	if is_instance_valid(_camera_duelo):
		_camera_duelo.queue_free()
	_camera_duelo = null
	if _camera_antes != null and is_instance_valid(_camera_antes):
		_camera_antes.current = true
	if palco != null:
		palco.queue_free()
		palco = null
	if hud != null:
		hud.modo_cinema(false)
	musica.parar(MusicaDoDesafio.COPOS, 2.0)
	if is_instance_valid(_veu):
		_veu.get_parent().queue_free()
	_veu = null
	etapa = Etapa.OCIOSO
