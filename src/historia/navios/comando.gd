extends Node
## Interação do piloto; a física e a flutuação continuam pertencendo ao barco.
signal aviso(texto: String)
const ALCANCE := 2.8
var jogador_de: Callable
## Chave em `ProgressaoDoPersonagem.sistemas` do barco que está na água.
const SISTEMA_FROTA := "frota"
var barcos: Array[CharacterBody3D] = []
var barco: CharacterBody3D
var jogador: CharacterBody3D
var _camada := 0
var _mascara := 0
var _camera_distancia := 4.0
var _ponto_anterior := Vector3.ZERO
var _volume_piloto: CollisionShape3D
## Frota do jogador (10/10/2026): barcos comprados no vendedor do porto, salvos no
## progresso; ao abrir o jogo cada um atraca numa vaga perto do vendedor (`Cais`).
const Cais := preload("res://src/historia/navios/cais.gd")
const VENDEDOR := "npc_vendedor_barcos"
var progressao: ProgressaoDoPersonagem
var _raiz: Node3D
var _bib: BibliotecaDeModelos

## Tripulação (15/10/2026): com a janela ligada, Y no barco pergunta "Navegar?" e exige de 3
## a 6 aliados; sem ela (arena, testes antigos) o Y assume o leme direto, como sempre foi.
var janela: JanelaDaTripulacao
var companhia: Node3D
var tripulacao: Array[String] = []
var _pendente: CharacterBody3D
var _modos_antes := {}       # id → modo do pet antes de embarcar (volta ao desembarcar)
var _no_convez: Array[String] = []   # ids fixados no convés (os que não voam nem nadam)
var _humanos := {}                   # id → TripulanteHumano no convés
## Quem diz onde estão as ilhas (o `DetectorDeIlha.caixas`); a Nami usa para o rumo.
var ilhas_de: Callable
var _dica_da_nami := ""
var _relogio_da_nami := 0.0
const INTERVALO_DA_NAMI := 20.0

## NAVEGAÇÃO (15/10/2026, pedido do dono): depois de zarpar a viagem segue mesmo que o
## jogador solte o leme, com a faixa "NAVEGANDO" na tela, e SÓ termina quando o barco entra
## numa ilha (sai do mar para uma ilha). Com a Nami na tripulação é ELA quem dirige, até a
## ilha mais próxima que não seja a de onde se zarpou.
signal viagem_mudou(ativa: bool, subtitulo: String)
const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
var viagem_ativa := false
var nami_conduz := false
var destino := ""                   # id da ilha da Nami ("" sem ela)
var _barco_da_viagem: CharacterBody3D
var _ilha_de_origem := ""
## Se o jogador cai do barco (ou não está nele) a Nami PARA o navio e espera; ele volta ao subir.
var nami_parou := false
var _tempo_fora := 0.0
const TOLERANCIA_FORA := 0.6        # s fora do casco antes de a Nami parar (um pulo não conta)
const FOLGA_DO_CASCO := 0.5         # m além da borda ainda é "a bordo"
var _ultima_ilha := ""              # a última ilha onde o jogador esteve (a "de origem" quando se zarpa do mar)
var _relogio_da_ilha := 0.0
var _saiu_ao_mar := false
var _relogio_da_faixa := 0.0
var _subtitulo := ""

func _ready() -> void:
	add_to_group("navegacao_historia")

func ligar_no_mapa(raiz: Node3D, mapa: Dictionary, bib: BibliotecaDeModelos) -> int:
	_raiz = raiz
	_bib = bib
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] != "modelo" or not bib.tem(p["modelo"]) or preload("res://src/historia/navios/perfil_barco.gd").ancorado(p) \
				or not bib.categorias_do_modelo(p["modelo"]).has("navios") or bib.ficha_de_navio(p["modelo"]).is_empty():
			continue
		var original := raiz.get_node_or_null(NodePath(str(p["id"])))
		if original == null:
			continue
		var novo: CharacterBody3D = load("res://src/historia/navios/barco.gd").new()
		# Só troca a peça quando o barco se monta. Os barcos-casa (categoria navios,
		# mas casas na água — `perfil_barco.gd`) e qualquer modelo que falhe ficam
		# como estão: antes a peça era APAGADA e um barco sem leme entrava na lista,
		# derrubando a dica do HUD a cada quadro (medido 03/10/2026, mapa vivo).
		if not novo.configurar(bib, str(p["modelo"]), p["tamanho"]):
			novo.free()
			continue
		novo.posicionar_no_mapa(p)
		raiz.remove_child(original)
		original.queue_free()
		novo.name = str(p["id"])
		raiz.add_child(novo)
		barcos.append(novo)
	return barcos.size()

## Depois de uma ilha ser descarregada: esquece os barcos liberados com ela (o do jogador, em uso, nunca é).
func podar() -> void:
	barcos.assign(barcos.filter(func(b: CharacterBody3D) -> bool: return is_instance_valid(b) and not b.is_queued_for_deletion()))


func ativo() -> bool:
	return is_instance_valid(barco) and is_instance_valid(jogador)


## Atraca os barcos já comprados. Espera um quadro de física: as consultas da vaga só
## enxergam o cenário depois que ele entrou no espaço físico.
func ligar_frota(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	if prog == null or prog.barcos.is_empty():
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	# Só um barco volta ao cais: o último usado (ou o primeiro comprado, em save antigo).
	var id := str(prog.dados_de(SISTEMA_FROTA).get("ativo", ""))
	if not prog.barcos.has(id):
		id = str(prog.barcos.keys()[0])
	if barco_do_jogador(id) == null and not lancar(id).is_empty():
		push_warning("[Frota] sem vaga no cais para %s" % id)


## O barco `id` da frota já no mundo, ou null.
func barco_do_jogador(id: String) -> CharacterBody3D:
	for b in barcos:
		if is_instance_valid(b) and b.has_meta("frota") and str(b.get_meta("frota")) == id:
			return b
	return null


## O vendedor de barcos do mapa (a vaga é procurada em volta dele), ou null.
func vendedor() -> Node3D:
	for n in get_tree().get_nodes_in_group("npc"):
		if str(n.get("tipo")) == VENDEDOR:
			return n
	return null


## Põe o barco `id` da frota numa vaga do cais (cria se ainda não existe). Devolve "" ou
## o motivo de não ter dado.
func lancar(id: String) -> String:
	if _raiz == null or _bib == null:
		return "O porto não está pronto."
	var v := vendedor()
	if v == null:
		return "Não há vendedor de barcos no mapa."
	var b := barco_do_jogador(id)
	if b != null and b.has_meta("piloto"):
		return "Solte o leme antes de trazer o barco."
	# Um barco do jogador na água por vez: o resto da frota fica guardado, só no progresso.
	var ocupado := _outro_em_uso(id)
	if not ocupado.is_empty():
		return ocupado
	var novo := b == null
	if novo:
		b = load("res://src/historia/navios/barco.gd").new()
		if not b.configurar(_bib, id, _bib.tamanho_padrao(id)):
			b.free()
			return "Este barco não navega."
	var outros: Array[Dictionary] = []
	for o in barcos:
		if is_instance_valid(o) and o != b:
			outros.append({"centro": o.global_position, "raio": Cais.raio_de(o)})
	var excluir: Array[RID] = []
	if not novo:
		excluir.append_array(b.call("rids_proprios"))
	var t: Variant = Cais.vaga(v.get_world_3d().direct_space_state, v.global_position, b, outros, excluir)
	if t == null:
		if novo:
			b.free()
		return "Não há vaga livre no cais."
	if novo:
		b.name = "Barco_" + id
		b.set_meta("frota", id)
		b.transform = t
		_raiz.add_child(b)
		barcos.append(b)
		b.afundou.connect(_barco_afundou)
	else:
		b.definir_pilotado(false)
		b.global_transform = t
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, b.global_transform)
	if progressao != null:
		progressao.gravar_dados(SISTEMA_FROTA, {"ativo": id})
	return ""


## Barcos da frota, na água, que não são o `id`.
func _outros_da_frota(id: String) -> Array[CharacterBody3D]:
	var saida: Array[CharacterBody3D] = []
	for o in barcos:
		if is_instance_valid(o) and not o.is_queued_for_deletion() and o.has_meta("frota") and str(o.get_meta("frota")) != id:
			saida.append(o)
	return saida


## Antes de pôr o barco `id`: tira da água os outros barcos do jogador (limite de 1 spawnado).
## Devolve o motivo de recusa (alguém no leme ou viagem em curso) ou "" depois de recolher.
func _outro_em_uso(id: String) -> String:
	var outros := _outros_da_frota(id)
	for o in outros:
		if o.has_meta("piloto") or o == barco or (viagem_ativa and o == _barco_da_viagem):
			return "Já há um barco seu na água. Solte o leme e termine a viagem antes de trocar."
	for o in outros:
		barcos.erase(o)
		o.queue_free()
	return ""

func candidato() -> CharacterBody3D:
	var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or not j.is_inside_tree() or is_instance_valid(j.montaria):
		return null
	var melhor: CharacterBody3D
	var distancia := INF
	for b in barcos:
		if not is_instance_valid(b) or not b.is_inside_tree() or b.is_queued_for_deletion() or b.has_meta("piloto"):
			continue
		var comando: Node3D = b.get("leme")
		var d := j.global_position.distance_to(comando.global_position + Vector3.UP * .85)
		var alvo := comando.global_position + Vector3.UP * .85
		# Embarque pela borda também funciona desde a água, sem exigir que o
		# nadador salte a altura inteira do convés de um galeão.
		var tamanho: Vector3 = b.get("tamanho_casco")
		var local := b.to_local(j.global_position)
		var casco := Vector3(clampf(local.x, -tamanho.x*.5, tamanho.x*.5), local.y,
			clampf(local.z, -tamanho.z*.5, tamanho.z*.5))
		var agua := AguaDoMundo.nivel_em(j.global_position.x, j.global_position.z)
		if not is_nan(agua) and absf(j.global_position.y - agua) < 2.2:
			var beira := b.to_global(casco)
			var distancia_beira := j.global_position.distance_to(beira)
			if distancia_beira < d:
				d = distancia_beira
				alvo = beira
		if d > ALCANCE or d >= distancia:
			continue
		var consulta := PhysicsRayQueryParameters3D.create(j.global_position, alvo, 1)
		consulta.exclude = [j.get_rid()] + (b.call("rids_proprios") as Array[RID])
		if j.global_position.distance_squared_to(alvo) < .001 or j.get_world_3d().direct_space_state.intersect_ray(consulta).is_empty():
			melhor = b
			distancia = d
	return melhor

func interagir() -> bool:
	if ativo():
		sair()
		return true
	var b := candidato()
	if b == null:
		return false
	if viagem_ativa:
		# Já zarpou: sem nova pergunta. Com a Nami é ela quem manda; sem ela o jogador volta ao leme.
		if nami_conduz:
			if b == _barco_da_viagem and not jogador_a_bordo():
				_por_o_jogador_no_convez(b)      # Y perto do casco sobe a bordo; ela retoma o rumo
				aviso.emit("De volta a bordo")
			else:
				aviso.emit("A Nami está no leme  ·  rumo a %s" % Ilhas.nome(destino))
		elif b == _barco_da_viagem:
			assumir(b)
		return true
	if janela != null:
		# Navegar? → escolher a tripulação → só então o leme. A resposta chega nos sinais.
		_pendente = b
		janela.perguntar()
		return true
	assumir(b)
	return true


## Liga a janela "Navegar?"/tripulação e a companhia que fornece os corpos dos aliados.
func ligar_tripulacao(a_janela: JanelaDaTripulacao, a_companhia: Node3D) -> void:
	janela = a_janela
	companhia = a_companhia
	janela.recusou.connect(_ao_recusar)
	janela.insuficiente.connect(_ao_faltar_tripulacao)
	janela.zarpou.connect(_ao_zarpar)


func _ao_recusar() -> void:
	_pendente = null
	_levar_para_a_costa("Você ficou em terra  ·  Y no barco para navegar")


func _ao_faltar_tripulacao() -> void:
	_pendente = null
	_levar_para_a_costa("Tripulação insuficiente (mínimo %d)  ·  você voltou à costa" % Tripulacao.MINIMO)


func _ao_zarpar(ids: Array[String]) -> void:
	var b := _pendente
	_pendente = null
	if not is_instance_valid(b) or b != candidato():
		aviso.emit("O barco saiu do alcance  ·  chegue perto e aperte Y de novo")
		return
	_barco_da_viagem = b
	var caixas: Dictionary = ilhas_de.call() if ilhas_de.is_valid() else {}
	# "Próxima ilha" = a mais perto que NÃO é a de onde se zarpa; zarpando do mar, a de onde se veio.
	_ilha_de_origem = Ilhas.ilha_em(caixas, b.global_position)
	var ilha_de_partida := _ilha_de_origem if not _ilha_de_origem.is_empty() else _ultima_ilha
	var com_nami := Tripulacao.validos(ids, progressao).has(Tripulacao.id_do_humano("nami"))
	destino = _ilha_mais_proxima_exceto(caixas, b.global_position, ilha_de_partida) if com_nami else ""
	nami_conduz = com_nami and not destino.is_empty()
	if nami_conduz:
		_por_o_jogador_no_convez(b)
		b.definir_pilotado(true)
	elif not assumir(b):
		_barco_da_viagem = null
		return
	_embarcar(ids)
	viagem_ativa = true
	nami_parou = false
	_tempo_fora = 0.0
	_saiu_ao_mar = false
	_relogio_da_faixa = 0.0
	_atualizar_faixa(true)
	if nami_conduz:
		aviso.emit("Nami no leme  ·  rumo a %s" % Ilhas.nome(destino))
	else:
		aviso.emit("Tripulação a bordo: %d  ·  boa viagem!" % tripulacao.size())


## A ilha mais perto de `p` que não seja `exceto` (a de onde se zarpou). Só uma ilha no mapa:
## ela mesma, para a Nami não ficar sem destino.
func _ilha_mais_proxima_exceto(caixas: Dictionary, p: Vector3, exceto: String) -> String:
	var melhor := ""
	var melhor_d := INF
	for id in caixas:
		if str(id) == exceto:
			continue
		var d := Ilhas.distancia(caixas[id], p)
		if d < melhor_d:
			melhor_d = d
			melhor = str(id)
	return melhor


## Quem dirige é a Nami: o jogador fica de pé no convés (e não na costa vendo o barco partir).
func _por_o_jogador_no_convez(b: CharacterBody3D) -> void:
	var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return
	var ponto: Vector3 = b.ponto_no_conves_livre()
	if is_nan(ponto.x):
		ponto = b.leme.global_position
	j.global_position = ponto + Vector3.UP * 0.9
	j.velocity = Vector3.ZERO


# ------------------------------------------------------------------ a viagem

func _physics_process(delta: float) -> void:
	if not viagem_ativa:
		_lembrar_a_ultima_ilha(delta)
		return
	if not is_instance_valid(_barco_da_viagem) or not _barco_da_viagem.is_inside_tree():
		_terminar_viagem("")
		return
	var caixas: Dictionary = ilhas_de.call() if ilhas_de.is_valid() else {}
	var ilha := Ilhas.ilha_em(caixas, _barco_da_viagem.global_position)
	if ilha.is_empty():
		_saiu_ao_mar = true
	elif _saiu_ao_mar or ilha != _ilha_de_origem:
		_terminar_viagem(ilha)
		return
	if nami_conduz:
		_nami_dirige(caixas)
	_relogio_da_faixa -= delta
	if _relogio_da_faixa <= 0.0:
		_relogio_da_faixa = 0.5
		_atualizar_faixa(false)


func _lembrar_a_ultima_ilha(delta: float) -> void:
	_relogio_da_ilha -= delta
	if _relogio_da_ilha > 0.0 or not ilhas_de.is_valid():
		return
	_relogio_da_ilha = 0.25
	var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return
	var ilha := Ilhas.ilha_em(ilhas_de.call(), j.global_position)
	if not ilha.is_empty():
		_ultima_ilha = ilha


## O piloto automático da Nami: vira para o ponto mais próximo da placa da ilha e acelera.
## Leme positivo é DIREITA (D), que é o giro horário visto de cima: o ângulo de `signed_angle_to`
## cresce no sentido anti-horário, daí o sinal trocado.
func _nami_dirige(caixas: Dictionary) -> void:
	if not caixas.has(destino):
		return
	var b := _barco_da_viagem
	if _ver_se_o_jogador_caiu(b):
		return
	var caixa: Rect2 = caixas[destino]
	var alvo := Vector3(clampf(b.global_position.x, caixa.position.x, caixa.end.x), b.global_position.y,
		clampf(b.global_position.z, caixa.position.y, caixa.end.y))
	var frente := -b.global_basis.z
	frente.y = 0.0
	var rumo := alvo - b.global_position
	rumo.y = 0.0
	if frente.length_squared() < 0.0001 or rumo.length_squared() < 0.0001:
		return
	var angulo := frente.signed_angle_to(rumo, Vector3.UP)
	var leme := clampf(-angulo * 2.2, -1.0, 1.0)
	var acelerador := 1.0 if absf(angulo) < 1.0 else 0.35
	b.definir_comando(acelerador, leme)


## O jogador está sobre o convés (ou a poucos cm da borda)? Fora disso — caiu na água, ficou na
## costa, foi longe — ele não está a bordo.
func jogador_a_bordo() -> bool:
	var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
	var b := _barco_da_viagem
	if j == null or not is_instance_valid(b) or not j.is_inside_tree() or not b.is_inside_tree():
		return false
	var local := b.to_local(j.global_position)
	var tamanho: Vector3 = b.get("tamanho_casco")
	var convez := b.to_local((b.get("leme") as Node3D).global_position).y
	return absf(local.x) <= tamanho.x * 0.5 + FOLGA_DO_CASCO and absf(local.z) <= tamanho.z * 0.5 + FOLGA_DO_CASCO \
		and local.y >= convez - 0.8 and local.y <= convez + 4.0


## A Nami PARA o navio se o jogador não está a bordo (pedido do dono): freia até quase zero, sem
## leme, e espera. Devolve `true` enquanto parada, para o piloto automático não acelerar de novo.
func _ver_se_o_jogador_caiu(b: CharacterBody3D) -> bool:
	if jogador_a_bordo():
		_tempo_fora = 0.0
		if nami_parou:
			nami_parou = false
			aviso.emit("Nami retomou o rumo")
			_atualizar_faixa(true)
		return false
	_tempo_fora += get_physics_process_delta_time()
	if _tempo_fora < TOLERANCIA_FORA and not nami_parou:
		return false
	if not nami_parou:
		nami_parou = true
		aviso.emit("Nami parou o navio  ·  volte a bordo (Y perto do casco)")
		_atualizar_faixa(true)
	# Freio ativo: o barco só desacelera devagar por inércia; ré curta contra a velocidade.
	var v: float = b.velocidade_atual()
	b.definir_comando(-0.6 if v > 0.4 else (0.3 if v < -0.4 else 0.0), 0.0)
	return true


func _atualizar_faixa(forcar: bool) -> void:
	var texto := ""
	if nami_conduz and nami_parou:
		texto = "Nami parou o navio  ·  volte a bordo"
	elif nami_conduz and not destino.is_empty() and is_instance_valid(_barco_da_viagem) and ilhas_de.is_valid():
		var caixas: Dictionary = ilhas_de.call()
		if caixas.has(destino):
			texto = "Nami conduz  ·  %s a %d m" % [Ilhas.nome(destino),
				roundi(Ilhas.distancia(caixas[destino], _barco_da_viagem.global_position))]
	else:
		texto = "Tripulação a bordo: %d" % tripulacao.size()
	if forcar or texto != _subtitulo:
		_subtitulo = texto
		viagem_mudou.emit(true, texto)


## O barco entrou numa ilha (ou sumiu): a viagem acaba, o barco para e a tripulação desce.
func _terminar_viagem(ilha: String) -> void:
	var b := _barco_da_viagem
	var era_nami := nami_conduz
	viagem_ativa = false
	nami_conduz = false
	nami_parou = false
	_tempo_fora = 0.0
	destino = ""
	if ativo():
		sair(true, true)
	if is_instance_valid(b):
		b.definir_comando(0.0, 0.0)
		if era_nami:
			b.definir_pilotado(false)
	_barco_da_viagem = null
	dispensar_tripulacao()
	_subtitulo = ""
	viagem_mudou.emit(false, "")
	if not ilha.is_empty():
		aviso.emit("Chegada: %s  ·  fim da navegação" % Ilhas.nome(ilha))


## A costa: perto do vendedor de barcos (o cais), no chão firme e fora d'água; sem
## vendedor no mapa, onde o jogador já está.
func ponto_da_costa() -> Variant:
	var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return null
	var v := vendedor()
	if v == null:
		return j.global_position
	var espaco := v.get_world_3d().direct_space_state
	for raio: float in [2.5, 4.0, 6.0, 9.0]:
		for k in 8:
			var p := v.global_position + Vector3.RIGHT.rotated(Vector3.UP, TAU * k / 8.0) * raio
			var consulta := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 6.0, p + Vector3.DOWN * 12.0, 1)
			var h := espaco.intersect_ray(consulta)
			if h.is_empty() or (h["normal"] as Vector3).y < .7:
				continue
			var agua := AguaDoMundo.nivel_em(p.x, p.z)
			if not is_nan(agua) and (h["position"] as Vector3).y < agua + .3:
				continue
			return (h["position"] as Vector3) + Vector3.UP * .9
	return v.global_position + Vector3.UP * .9


func _levar_para_a_costa(texto: String) -> void:
	var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null:
		return
	var p: Variant = ponto_da_costa()
	if p is Vector3:
		j.global_position = p
		j.velocity = Vector3.ZERO
	aviso.emit(texto)


# ------------------------------------------------------------------ aliados a bordo

## Cada aliado viaja do jeito da sua categoria (`Tripulacao`): ave e besta marinha ficam
## FORA do barco e o seguem (a gaivota no modo "seguir" já circula e pousa); o terrestre
## fica no convés. Humanos entram quando existir recrutamento (ver `Tripulacao`).
func _embarcar(ids: Array[String]) -> void:
	dispensar_tripulacao()
	if companhia == null or progressao == null:
		return
	var sobrevivencia := get_tree().get_first_node_in_group("sobrevivencia_historia")
	if sobrevivencia != null: ids = sobrevivencia.preparar_embarque(ids)
	var vaga := 0
	for id in Tripulacao.validos(ids, progressao):
		var alvo := Tripulacao.aliado(progressao, _bib, id)
		var categoria: Tripulacao.Categoria = alvo["categoria"]
		if categoria == Tripulacao.Categoria.HUMANO:
			_embarcar_humano(id, str(alvo["especie"]), vaga)
			vaga += 1
			continue
		# No mar o chão ao lado do jogador é água: o aliado nasce no convés (terrestre) ou
		# no ar em cima do barco (ave e besta marinha) — nunca pela busca de chão de sempre.
		var onde: Vector3 = _barco_da_viagem.to_global(posicao_no_convez(_barco_da_viagem, vaga)) if categoria == Tripulacao.Categoria.TERRESTRE \
			else _barco_da_viagem.leme.global_position + Vector3.UP * 3.0 + _barco_da_viagem.global_basis.x * (1.5 + vaga)
		if not companhia.esta_fora(id) and not companhia.chamar(id, onde):
			aviso.emit("%s não pôde embarcar: %s" % [progressao.nome_do_pet(id), str(companhia.get("motivo"))])
			continue
		var pet: CharacterBody3D = companhia.pet_fora(id)
		if pet == null:
			continue
		tripulacao.append(id)
		match categoria:
			Tripulacao.Categoria.TERRESTRE:
				_fixar_no_convez(pet, vaga)
				_no_convez.append(id)
				vaga += 1
			_:
				_modos_antes[id] = progressao.modo_do_pet(id)
				if pet.has_method("definir_modo"):
					pet.definir_modo(ModoDoPet.SEGUIR)

	if sobrevivencia != null: sobrevivencia.concluir_embarque()

func _embarcar_humano(id: String, tripulante: String, vaga: int) -> void:
	var h := TripulanteHumano.new()
	_barco_da_viagem.add_child(h)
	h.montar(tripulante, _bib, Tripulacao.ficha_recrutada(progressao, tripulante))
	h.position = posicao_no_convez(_barco_da_viagem, vaga)
	var passeio := PasseioNoConves.new()
	passeio.name = "Passeio"
	passeio.dono = h
	passeio.barco = _barco_da_viagem
	h.add_child(passeio)
	_humanos[id] = h
	tripulacao.append(id)
	var dono: Node = jogador_de.call() if jogador_de.is_valid() else null
	match str(CatalogoDeTripulantes.TRIPULANTES.get(tripulante, {}).get("ajuda", "")):
		"navegar":
			_relogio_da_nami = 0.0     # a primeira indicação sai já
		"pistola":
			var p := PistoleiroDeBordo.new()
			p.name = "Pistoleiro"
			p.tripulante = h
			p.barco = _barco_da_viagem
			p.dono = dono
			p.passeio = h.get_node("Passeio")
			h.add_child(p)
		"areia":
			h.get_node("Passeio").queue_free()      # ele voa: não anda pelo convés
			var v := VooDeAreia.new()
			v.name = "VooDeAreia"
			v.tripulante = h
			v.barco = _barco_da_viagem
			v.dono = dono
			h.add_child(v)


## A Nami a bordo? (só ela navega.)
func tem_navegadora() -> bool:
	return _humanos.has(Tripulacao.id_do_humano("nami"))


## O que a Nami diz agora: a PRÓXIMA ilha (a que ela vai buscar), a distância e o rumo ("" sem ela
## ou sem outra ilha no mapa).
func fala_da_navegadora() -> String:
	if not tem_navegadora() or not ilhas_de.is_valid() or not is_instance_valid(_barco_da_viagem):
		return ""
	var caixas: Dictionary = ilhas_de.call()
	var onde := _barco_da_viagem.global_position
	var proxima := destino if viagem_ativa and caixas.has(destino) else _ilha_mais_proxima_exceto(caixas, onde, _ilha_de_origem if not _ilha_de_origem.is_empty() else _ultima_ilha)
	if proxima.is_empty() or not caixas.has(proxima):
		return ""
	var caixa: Rect2 = caixas[proxima]
	var alvo := Vector2(clampf(onde.x, caixa.position.x, caixa.end.x), clampf(onde.z, caixa.position.y, caixa.end.y))
	return "Nami: próxima ilha é %s, a %d m, rumo %s" % [Ilhas.nome(proxima), roundi(Ilhas.distancia(caixa, onde)),
		Tripulacao.rumo_para(alvo - Vector2(onde.x, onde.z))]


## Posição do convés para o `n`-ésimo aliado de bordo (terrestre ou humano), no referencial do barco: em volta do leme,
## sem passar da borda do casco.
func posicao_no_convez(b: CharacterBody3D, n: int) -> Vector3:
	var base: Vector3 = b.to_local((b.get("leme") as Node3D).global_position)
	var tamanho: Vector3 = b.get("tamanho_casco")
	var deslocamentos: Array[Vector2] = [Vector2(-1.0, 1.0), Vector2(1.0, 1.0), Vector2(-1.0, 2.2),
		Vector2(1.0, 2.2), Vector2(0.0, 3.4), Vector2(0.0, -1.4)]
	var d := deslocamentos[n % deslocamentos.size()]
	var p := base + Vector3(d.x, 0.0, d.y)
	p.x = clampf(p.x, -tamanho.x * .45, tamanho.x * .45)
	p.z = clampf(p.z, -tamanho.z * .45, tamanho.z * .45)
	return p


func _fixar_no_convez(pet: CharacterBody3D, n: int) -> void:
	if not is_instance_valid(_barco_da_viagem):
		return
	pet.velocity = Vector3.ZERO
	pet.collision_mask = 0
	pet.set_physics_process(false)
	pet.set_process(false)
	if pet.get_parent() != null:
		pet.get_parent().remove_child(pet)
	_barco_da_viagem.add_child(pet)
	pet.position = posicao_no_convez(_barco_da_viagem, n)
	pet.rotation = Vector3.ZERO
	# Passeia pelo convés (o corpo é guiado pelo passeio, não pela física do pet).
	var passeio := PasseioNoConves.new()
	passeio.name = "Passeio"
	passeio.dono = pet
	passeio.barco = _barco_da_viagem
	passeio.velocidade = 0.6
	pet.add_child(passeio)


## A viagem acabou: os aliados voltam ao inventário e os modos dos pets, ao que eram.
func dispensar_tripulacao() -> void:
	for id in tripulacao:
		if _humanos.has(id):
			continue
		if _modos_antes.has(id) and companhia != null:
			var pet: CharacterBody3D = companhia.pet_fora(id)
			if pet != null and pet.has_method("definir_modo"):
				pet.definir_modo(_modos_antes[id])
		if companhia != null:
			companhia.recolher(id)
	for h in _humanos.values():
		if is_instance_valid(h):
			h.get_parent().remove_child(h)
			h.queue_free()
	_humanos.clear()
	_dica_da_nami = ""
	tripulacao.clear()
	_modos_antes.clear()
	_no_convez.clear()


func assumir(b: CharacterBody3D) -> bool:
	var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
	if ativo() or j == null or not j.is_multiplayer_authority() or b != candidato():
		return false
	if not j.corpo_livre_para_golpe() or j.esta_atacando() or j._voo.ativo() or j.esquivando():
		aviso.emit("Termine a ação atual para assumir o leme")
		return false
	var posicao: Vector3 = b.leme.global_position + Vector3.UP * .85
	var forma := CapsuleShape3D.new()
	forma.height = 1.6
	forma.radius = .38
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform.origin = posicao
	consulta.collision_mask = 1
	consulta.exclude = [j.get_rid()] + (b.call("rids_proprios") as Array[RID])
	if not j.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
		aviso.emit("Não há espaço livre no posto de comando")
		return false
	jogador = j
	barco = b
	_ponto_anterior = j.global_position
	_camada = j.collision_layer
	_mascara = j.collision_mask
	_camera_distancia = j._camera.distancia
	var tamanho: Vector3 = b.get("tamanho_casco")
	# 18/11/2026: recuo e altura pelo tamanho do casco, sem o casco empurrando a câmera (`CameraRig.entrar_navegacao`); antes: só 65 % do comprimento.
	j._camera.entrar_navegacao(CameraRig.enquadramento_de_barco(tamanho), b.call("rids_proprios") as Array[RID])
	j.navegacao = self
	j.collision_layer = 0
	j.collision_mask = 0
	j.velocity = Vector3.ZERO
	j.set_meta("pilotando", true)
	b.set_meta("piloto", j.get_instance_id())
	b.definir_pilotado(true)
	b.tree_exiting.connect(_barco_saindo, CONNECT_ONE_SHOT)
	j.tree_exiting.connect(_jogador_saindo, CONNECT_ONE_SHOT)
	_volume_piloto = CollisionShape3D.new()
	_volume_piloto.name = "VolumeDoPiloto"
	_volume_piloto.shape = forma
	b.add_child(_volume_piloto)
	_volume_piloto.position = b.to_local(posicao)
	_sincronizar(1.0/60)
	aviso.emit("%s  ·  W/S acelerar, frear e ré  ·  A/D virar  ·  Y soltar o leme" % str(b.get("nome_exibido")))
	return true

func atualizar(delta: float) -> bool:
	if not ativo():
		return false
	var atordoado: bool = jogador._fsm != null and jogador._fsm.state != null and jogador._fsm.state.name == "Stunned"
	if jogador.health <= 0 or jogador._arremesso.ativo() or atordoado \
			or jogador.get_meta("is_frozen", false) or jogador.get_meta("custom_pose", "") == "knockdown":
		sair(true)
		return false
	var hud := get_tree().get_first_node_in_group("hud")
	var livre: bool = hud == null or not hud.is_menu_open()
	var acelerador := 0.0
	var direcao := 0.0
	if livre:
		acelerador = float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
		direcao = float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	barco.definir_comando(acelerador, direcao)
	jogador.set_meta("leme_direcao", direcao)
	if tem_navegadora():
		_relogio_da_nami -= delta
		if _relogio_da_nami <= 0.0:
			_relogio_da_nami = INTERVALO_DA_NAMI
			_dica_da_nami = fala_da_navegadora()
			if not _dica_da_nami.is_empty():
				aviso.emit(_dica_da_nami)
	_sincronizar(delta)
	return true

func _sincronizar(delta: float) -> void:
	var comando: Node3D = barco.get("leme")
	jogador.global_position = comando.global_position + Vector3.UP * .85
	jogador.velocity = barco.get_real_velocity()
	jogador._char_model.global_rotation = Vector3(0, barco.global_rotation.y, 0)
	if jogador._proc_anim != null:
		jogador._proc_anim.update(jogador.velocity, true, false, delta, 0)
	if is_instance_valid(_volume_piloto):
		_volume_piloto.position = barco.to_local(jogador.global_position)
	HurtboxDeCombate.sincronizar(jogador)

func liberar_para_captura() -> bool:
	return sair(true, true)

func sair(forcar := false, preservar_posicao := false) -> bool:
	if not is_instance_valid(jogador):
		return false
	var ponto: Variant = jogador.global_position if preservar_posicao else _ponto_livre()
	if ponto == null and not forcar:
		aviso.emit("Sem espaço para soltar o leme. Afaste o barco do obstáculo.")
		return false
	var j := jogador
	if j.tree_exiting.is_connected(_jogador_saindo):
		j.tree_exiting.disconnect(_jogador_saindo)
	if is_instance_valid(_volume_piloto):
		_volume_piloto.get_parent().remove_child(_volume_piloto)
		_volume_piloto.queue_free()
	_volume_piloto = null
	if is_instance_valid(barco):
		barco.definir_pilotado(false)
		barco.remove_meta("piloto")
		if barco.tree_exiting.is_connected(_barco_saindo):
			barco.tree_exiting.disconnect(_barco_saindo)
	j.collision_layer = _camada
	j.collision_mask = _mascara
	j._camera.sair_navegacao()
	j._camera.distancia = _camera_distancia
	j.navegacao = null
	j.set_meta("pilotando", false)
	j.remove_meta("leme_direcao")
	j.velocity = Vector3.ZERO
	if j.is_inside_tree():
		j.global_position = ponto if ponto is Vector3 else _ponto_anterior
	barco = null
	jogador = null
	if not forcar:
		aviso.emit("Leme livre  ·  Y para pilotar novamente")
	return true

func _ponto_livre() -> Variant:
	if not ativo() or not jogador.is_inside_tree() or not barco.is_inside_tree():
		return null
	var espaco := jogador.get_world_3d().direct_space_state
	var forma := CapsuleShape3D.new()
	forma.radius = .38
	forma.height = 1.6
	var comando: Node3D = barco.get("leme")
	for deslocamento: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var p := comando.global_position + barco.global_basis * deslocamento
		var raio := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 3, 1)
		raio.exclude = [jogador.get_rid()]
		var chao := espaco.intersect_ray(raio)
		if chao.is_empty() or (chao["normal"] as Vector3).y < .6:
			continue
		p = chao["position"] + Vector3.UP * .85
		var volume := PhysicsShapeQueryParameters3D.new()
		volume.shape = forma
		volume.transform.origin = p
		volume.collision_mask = 1
		volume.exclude = [jogador.get_rid()]
		# A cápsula adicional do piloto não pode bloquear sua própria saída.
		if is_instance_valid(_volume_piloto):
			_volume_piloto.disabled = true
		var livre := espaco.intersect_shape(volume, 1).is_empty()
		if is_instance_valid(_volume_piloto):
			_volume_piloto.disabled = false
		if livre:
			return p
	return null

func dica() -> String:
	if ativo():
		var casco := ""
		if float(barco.get("health")) < float(barco.get("max_health")):
			casco = "   |   casco %d/%d" % [ceili(float(barco.get("health"))), roundi(float(barco.get("max_health")))]
		var nami := "   |   " + fala_da_navegadora() if tem_navegadora() else ""
		return "Y · Soltar leme   |   W/S · Acelerar/frear   A/D · Virar   |   %.1f m/s%s%s" % [absf(float(barco.velocidade_atual())), casco, nami]
	var b := candidato()
	if viagem_ativa and nami_conduz:
		# A faixa NAVEGANDO já diz tudo; o leme é da Nami. Só oferece subir a bordo quando ela parou.
		return "Y · Subir a bordo  |  a Nami espera você" if nami_parou and b != null else ""
	return "Y · Pilotar " + str(b.get("nome_exibido")) if b != null else ""

## Besta afundou o barco (14/10/2026): o piloto fica na água onde está e o barco sai da
## frota para sempre (decisão do dono: compra-se outro no vendedor).
func _barco_afundou(b: CharacterBody3D) -> void:
	if b == barco:
		sair(true, true)
	if viagem_ativa and b == _barco_da_viagem:
		_terminar_viagem("")      # o casco se foi: a viagem e os do convés vão junto
	dispensar_tripulacao()
	barcos.erase(b)
	var id := str(b.get_meta("frota", ""))
	if progressao != null and not id.is_empty():
		progressao.perder_barco(id)
	aviso.emit("%s afundou  ·  compre outro no vendedor do porto" % str(b.get("nome_exibido")))


func _barco_saindo() -> void:
	sair(true)
func _jogador_saindo() -> void:
	sair(true)
func _exit_tree() -> void:
	if is_instance_valid(jogador):
		sair(true)
