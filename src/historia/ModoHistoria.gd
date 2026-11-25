extends Node3D
# ============================================================================
#  MODO HISTÓRIA — orquestrador da cena (fino, como o `Main` da arena).
#
#  Etapa 1 do plano (docs/MODO_HISTORIA.md): SÓ a baseplate e o jogador andando.
#  Tudo o que o mundo tem sai do arquivo de mapa — nada de chão escrito aqui —
#  porque a etapa 2 é o editor de mapa, e ele vai editar esse mesmo arquivo.
#
#  O QUE ESTA CENA NÃO TEM, DE PROPÓSITO (é o que a arena tem e a história não):
#  placar, enchente, bonecos, árvores com fruta, chefe. O jogador nasce como
#  Civil (`CapacidadesDoJogador.civil()`): anda, pula e olha. A progressão libera o
#  resto — e desde 30/09/2026 a campanha começa com Combate 1, então o clique (o
#  corpo a corpo direcional) já funciona no nível 1 (decisão do dono).
#
#  INIMIGOS (16/09/2026): peça do mapa cujo modelo está na categoria "inimigos" da
#  loja ganha vida e some ao ser derrotada (`InimigoDoMapa`); derrotar dá XP. Desde
#  30/09/2026 renasce em 1 minuto no mesmo lugar.
#
#  INIMIGO QUE LUTA (30/09/2026): o "Boneco de duelo" da aba "inimigos" da loja
#  vira um `NinhoDeInimigo`: o boneco com o executor do jogador, perseguindo e
#  lutando numa zona de 20 m (`CerebroDeInimigo`), renascendo em 1 minuto. Sem XP.
#
#  BONECO DE DUELO (21/09/2026): o painel de teste (F8, antes a seção TESTE da
#  janela M) invoca um parceiro de treino com o mesmo executor do jogador
#  (`invocar_boneco`). Só em desenvolvimento, um por vez, e não dá XP — é
#  ferramenta de playtest.
#
#  Rede: singleplayer puro, servidor local offline (`GameFlow.start_story`). O
#  jogador é criado direto, sem `MultiplayerSpawner` — não há ninguém para quem
#  replicar. Se a história ganhar cooperativo, o nascimento passa a ser o do
#  `Main._spawn_player_data`, com spawner e synchronizer.
# ============================================================================

const MAPA_INICIAL := "res://mapas/historia/baseplate.json"
## Quando preenchido, abre este mapa no lugar do `MAPA_INICIAL`. Existe para os
## testes: o mapa do projeto é VIVO (o dono edita no editor), e um teste que medisse
## "a baseplate tem 1 peça" nele quebraria a cada peça nova — aconteceu em 14/09/2026.
static var mapa_forcado := ""
## Onde o progresso do personagem (nível, XP, atributos) é salvo. Teste troca.
const PROGRESSO_PADRAO := "user://historia/progresso.json"
static var progresso_forcado := ""
## Lançador de teste (`jogar_teste_ilha.sh`, 18/10/2026): nasce e renasce nesta ilha.
static var ilha_de_teste := ""
var raid: Node

## COMBATE DIRECIONAL (docs/PLANO_COMBATE_HISTORIA.md) — o clique inspirado em
## Chivalry 2. É o corpo a corpo do Modo História desde o fim da Fase 3 do plano
## (16/09/2026), quando o golpe novo passou a ter contato, dano e reação; a chave
## que o mantinha desligado foi apagada, como o gatilho mandava.
const ESTILO_CORPO_A_CORPO := "res://src/combat/direcional/estilos/boxe.tres"

## AKUMA NO MI DO MODO HISTÓRIA (22/09/2026). Cada fruta tem um perfil com os números
## DESTE modo (custo de energia, recarga, dano); a arena continua com `Balance.gd`. A
## fruta comida fica no progresso (`ProgressaoDoPersonagem.fruta`).
const PERFIS_DE_FRUTA := {"rocket": "res://src/historia/frutas/rocket.tres"}

## Chave pedida pelo painel F8 (`FerramentasDeTeste.MODOS_DO_BONECO`) → modo do cérebro.
const MODOS_DO_BONECO := {
	&"parado": CerebroDeTreino.Modo.PARADO,
	&"guarda": CerebroDeTreino.Modo.GUARDA_SEMPRE,
	&"ataca": CerebroDeTreino.Modo.ATACA_EM_CICLO,
	&"apara": CerebroDeTreino.Modo.APARA_E_RIPOSTA,
}
## Onde o boneco aparece: à frente do jogador, um passo além do alcance do jab
## (efetor 0,54 m; erra a 1,6 m) — quem começa a luta é o jogador, chegando perto.
const DISTANCIA_DO_BONECO := 1.8
## De quanto em quanto tempo o boneco "Ataca" solta um golpe. Dá tempo de ler a carga,
## defender e voltar ao neutro antes do próximo.
const INTERVALO_DO_BONECO := 1.5

## O status do personagem (tecla M). Aplicado ao corpo a cada mudança e gravado.
var progressao: ProgressaoDoPersonagem

var _hud: HistoriaHud
var _jogadores: Node3D
var _boneco: BonecoDeDuelo = null
var _companhia: Node3D
## Os bichos das áreas de animais do mapa (docs/ANIMAIS_CHECKPOINT.md).
var _animais: PopulacaoDeAnimais
## Baús de chefe (18/11/2026): cada chefe derrotado solta um com uma fruta (`src/historia/baus/baus_de_chefe.gd`).
const BausDeChefe := preload("res://src/historia/baus/baus_de_chefe.gd")
var baus_de_chefe: Node3D
var props_dos_macacos: Node3D
const DetectorDeIlha := preload("res://src/historia/ilhas/detector_de_ilha.gd")
var _ilhas: DetectorDeIlha
const LodDasIlhas := preload("res://src/historia/ilhas/lod_das_ilhas.gd")
const RelevoDasIlhas := preload("res://src/historia/ilhas/relevo_das_ilhas.gd")
var _lod: LodDasIlhas
var _zona_de_combate: ZonaDeCombate
var _nivel_dos_inimigos: NivelDosInimigos
## Modo Economia dos gráficos (bateria ou escolha do jogador): sombra mais leve e objetos minúsculos escondidos.
var _perfil: PerfilGrafico
## Spawn natural dos personagens do Mine Piece em todas as ilhas (23/10/2026).
var _streaming: StreamingDeIlhas
var _ia_inimigos: IaDosInimigos
var _ia_animais: IaDosAnimais
var _raiz_do_mapa: Node3D
var _destruicao: DestruicaoDeEstruturas
var _relevo_marinho: RelevoMarinho
var _coleta: Node
var spawn_natural: SpawnNaturalMinePiece
var _spawn_do_mapa := Vector3.INF        # onde se renasce na ilha inicial (ver `_atualizar_renascimento`)
## Frutas penduradas nas árvores frutíferas, a queda e a coleta (docs/FRUTAS_E_DOMA_CHECKPOINT.md).
var _pomar: PomarDaIlha
## A fruta do pomar na mão do jogador (Y tenta domar).
var _mao: FrutaNaMao
## O jogador na água (rasa, nado, mergulho).
var _na_agua: JogadorNaAgua
var _montarias: Node
var _navegacao: Node
## Pesca (03/10/2026): o minigame da vara e os NPCs postos pela loja (o pescador).
var _pesca: Pescaria
var _npcs: NpcsDaIlha
var desafio_buggy: DesafioDoBuggy
var resgate_do_bau: ResgateDoBau
var missao_da_alvida: MissaoDaAlvida
## Corrida de caranguejos (06/10/2026): o NPC da corrida e o F8 começam.
var corrida: CorridaDeCaranguejos
var _reiniciando_campanha := false


func _ready() -> void:
	# Quem muda só na campanha pergunta por este grupo (10/10/2026: Z da Hie, V da Hie).
	add_to_group("modo_historia")
	DanoDaHistoria.ligar_para(progresso_forcado.is_empty())      # só a campanha de verdade; teste que força o save fica com o dano bruto
	# Carga em etapas com a tela de carregamento (MonitorDeCarga): enquanto carrega, a cena não processa nada.
	if MonitorDeCarga.vai_aguardar():
		process_mode = Node.PROCESS_MODE_DISABLED
	await MonitorDeCarga.etapa("Ambiente, luz e ciclo de dia e noite")
	WorldEnv.apply(self)
	# Dia e noite (10/10/2026): 24 min reais por dia, noite azul e legível.
	var ciclo := CicloDiaNoite.new()
	add_child(ciclo)
	ciclo.ligar(self)

	await MonitorDeCarga.etapa("Progresso do personagem", "lendo o save")
	progressao = ProgressaoDoPersonagem.carregar(caminho_do_progresso())
	if not await _escolher_corpo():
		return
	progressao.mudou.connect(_ao_mudar_progresso)
	progressao.itens_do_mod_mudaram.connect(_salvar_itens_adiado)

	await MonitorDeCarga.etapa("Interface do modo história (HUD)")
	_hud = HistoriaHud.new()
	_hud.name = "HistoriaHud"
	add_child(_hud)
	_hud.ligar_progressao(progressao)
	_dar_frutas_de_teste()
	await MonitorDeCarga.etapa("Recrutamento, companhia e fruta na mão")
	var recrutamento := preload("res://src/historia/tripulantes/recrutamento.gd").new()
	recrutamento.name = "Recrutamento"
	recrutamento.progressao = progressao
	recrutamento.jogador_de = jogador_local
	recrutamento.biblioteca = MapaMontador.biblioteca_em_uso()
	recrutamento.hud = _hud
	add_child(recrutamento)
	# Pokébola (30/10/2026): cubo na mão + arremesso; captura inimigo de vida vermelha e substitui o F.
	var captura := CapturaDeInimigos.new()
	captura.name = "CapturaDeInimigos"
	captura.progressao = progressao
	captura.jogador_de = jogador_local
	captura.recrutamento = recrutamento
	captura.hud = _hud
	add_child(captura)
	_hud.ligar_captura(captura)
	_hud.janela_de_status().pediu_reset_total.connect(reiniciar_campanha)
	_companhia = load("res://src/historia/pets/companhia.gd").new()
	_companhia.name = "Companhia"
	_companhia.alvo_de = jogador_local
	add_child(_companhia)
	# Pets (30/09/2026): moram no inventário (N) e mudam de comportamento pelo menu B.
	_companhia.progressao = progressao
	_mao = FrutaNaMao.new()
	_mao.name = "FrutaNaMao"
	_mao.progressao = progressao
	_mao.biblioteca = MapaMontador.biblioteca_em_uso()
	_mao.jogador_de = jogador_local
	add_child(_mao)
	_mao.pediu_doma.connect(_tentar_domar)
	_companhia.pet_morreu.connect(func(nome: String): _hud.avisar("%s morreu  ·  saiu do inventário para sempre" % nome))
	_hud.ligar_pets(_companhia, progressao, _mao)
	await MonitorDeCarga.etapa("Montarias e corrida de caranguejos")
	_montarias = preload("res://src/historia/pets/montaria.gd").new()
	_montarias.name = "Montarias"
	_montarias.jogador_de = jogador_local
	_montarias.biblioteca = MapaMontador.biblioteca_em_uso()
	add_child(_montarias)
	_hud.ligar_montaria(_montarias)
	corrida = CorridaDeCaranguejos.new()
	corrida.name = "CorridaDeCaranguejos"
	corrida.progressao = progressao
	corrida.companhia = _companhia
	corrida.montarias = _montarias
	corrida.jogador_de = jogador_local
	corrida.terminou.connect(_ao_terminar_corrida)
	add_child(corrida)
	# Treino de socos (20/11/2026): o instrutor do campo de treino inicia; câmera lateral, teclas no tempo, soco no boneco (`treino_de_soco.gd`).
	var treino := TreinoDeSoco.new()
	treino.name = "TreinoDeSoco"
	treino.progressao = progressao
	treino.jogador_de = jogador_local
	treino.aviso.connect(_hud.avisar)
	add_child(treino)
	# As ferramentas de teste (F8) só existem em build de desenvolvimento.
	var ferramentas := _hud.ferramentas_de_teste()
	if ferramentas != null:
		ferramentas.pediu_boneco.connect(invocar_boneco)
		ferramentas.pediu_remover_boneco.connect(remover_boneco)
		ferramentas.pediu_fruta.connect(dar_fruta)
		ferramentas.pediu_tirar_fruta.connect(tirar_fruta)
		ferramentas.pediu_corrida.connect(_correr_pelo_f8)
		ferramentas.pediu_ilha_dos_macacos.connect(_ir_a_ilha_dos_macacos)

	await MonitorDeCarga.etapa("Procedures do mod", "carregadas agora para não engasgar no meio da partida")
	Mc.aquecer()

	await MonitorDeCarga.etapa("Lendo o arquivo do mapa")
	var caminho := mapa_forcado if not mapa_forcado.is_empty() else MAPA_INICIAL
	var lido := MapaArquivo.carregar(caminho)
	if not lido["ok"]:
		var motivo := "Mapa do Modo História inválido (%s):\n- %s" \
			% [caminho, "\n- ".join(lido["erros"])]
		push_error(motivo)
		_hud.mostrar_erro(motivo)
		_terminar_carga()
		return

	var mapa: Dictionary = lido["mapa"]
	# CARGA POR DISTÂNCIA (28/10/2026, `StreamingDeIlhas`): a raiz do mapa nasce vazia; o relevo das ilhas, o oceano e o fundo do mar
	# (baratos) ficam sempre; as peças e tudo que nasce delas entram ilha por ilha, perto do jogador.
	var bib := MapaMontador.biblioteca_em_uso()
	MapaMontador.sem_geometria_do_terreno = not RelevoDasIlhas.desligado       # o relevo em blocos já faz o terreno
	await MonitorDeCarga.etapa("Preparando o mapa", "%d peças reunidas por ilha; só a ilha do jogador é montada agora" % (mapa["pecas"] as Array).size())
	var raiz_do_mapa := MapaMontador.criar_raiz(self)
	_raiz_do_mapa = raiz_do_mapa
	var caixas_das_ilhas: Dictionary = DetectorDeIlha.Ilhas.caixas(mapa)
	_streaming = StreamingDeIlhas.new()
	_streaming.name = "StreamingDeIlhas"
	add_child(_streaming)
	_streaming.configurar(raiz_do_mapa, mapa, bib, caixas_das_ilhas)
	_streaming.jogador_de = jogador_local
	_streaming.ao_ligar = _ligar_ilha
	_streaming.ao_desligar = _desligar_ilha
	_streaming.descarrega = not _carregar_tudo()
	# Relevo em blocos (22/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md): um corpo por ilha no
	# lugar da malha lisa das peças `terreno`. Sempre carregado: de longe a ilha é terra.
	await MonitorDeCarga.etapa("Relevo das ilhas (blocos)")
	var relevos := RelevoDasIlhas.montar(raiz_do_mapa, mapa)
	# O gelo do V da Hie pinta só o cenário (10/10/2026): marcado antes de as peças virarem
	# NPC, inimigo ou bicho. As texturas do gelo saem agora, no carregamento.
	await MonitorDeCarga.etapa("Cenário, gelo e oceano")
	MapaMontador.marcar_cenario(raiz_do_mapa)
	EraDoGelo.preparar()
	var oceano := preload("res://src/world/oceano_historia.gd").new()
	oceano.name = "Oceano"
	add_child(oceano)
	oceano.configurar(mapa)
	AguaDoMundo.registrar(mapa, oceano)
	# Chão embaixo do mar, para nadar e mergulhar (docs/AGUA_PLANO.md, A5): um por ilha;
	# relevo marinho desde 14/10/2026 (docs/MAR_HISTORIA_PLANO.md, E1).
	# O que entra no desenho por distância por ilha (fundos, inimigos, ninhos, NPCs).
	var por_ilha: Array = []
	por_ilha.append_array(relevos)
	await MonitorDeCarga.etapa("Fundo do mar de cada ilha")
	var montagem_do_fundo := FundoDoMar.preparar_por_ilha(self, mapa, oceano.get("bases"), oceano.get("nivel"))
	while montagem_do_fundo.passo():
		var prog := montagem_do_fundo.andamento()
		MonitorDeCarga.andamento(prog[0], prog[1], prog[2])
		await MonitorDeCarga.passo()
	var fundos := montagem_do_fundo.fundos
	_relevo_marinho = fundos[0].relevo if not fundos.is_empty() else null
	por_ilha.append_array(fundos)
	# O que vive no mar (recifes, naufrágios, encontros, peixes, visão submersa) liga num
	# ponto só: docs/MAR_HISTORIA_PLANO.md.
	await MonitorDeCarga.etapa("Mar: recifes, naufrágios e peixes")
	if not fundos.is_empty():
		var mar := preload("res://src/historia/mar/mar.gd").new()
		mar.name = "Mar"
		add_child(mar)
		mar.montar(fundos[0].relevo, jogador_local, {"raiz": raiz_do_mapa, "mapa": mapa,
			"bib": bib, "progressao": progressao, "hud": _hud,
			"navegacao": func() -> Node: return _navegacao, "ao_abater_besta": _ao_abater_besta})
		var f8 := _hud.ferramentas_de_teste()
		if f8 != null:
			f8.pediu_encontro_no_mar.connect(mar.forcar_encontro)
	await MonitorDeCarga.etapa("Sistemas do mundo (navegação, pesca, NPCs, animais, pomar...)")
	_navegacao = preload("res://src/historia/navios/comando.gd").new()
	_navegacao.name = "Navegacao"
	_navegacao.jogador_de = jogador_local
	add_child(_navegacao)
	_hud.ligar_navegacao(_navegacao)
	# "Navegar?" e a tripulação (15/10/2026): o Y no barco pergunta antes de assumir o leme.
	_navegacao.ilhas_de = func() -> Dictionary: return _ilhas.caixas if _ilhas != null else {}
	_navegacao.ligar_tripulacao(_hud.ligar_tripulacao(progressao, bib), _companhia)
	_pesca = Pescaria.new()
	_pesca.name = "Pescaria"
	_pesca.progressao = progressao
	_pesca.biblioteca = bib
	_pesca.jogador_de = jogador_local
	add_child(_pesca)
	_hud.ligar_pesca(_pesca)
	# Construções destrutíveis em blocos, só em volta do jogador (08/11/2026).
	_destruicao = DestruicaoDeEstruturas.new()
	_destruicao.name = "DestruicaoDeEstruturas"
	_destruicao.jogador_de = jogador_local
	add_child(_destruicao)
	_npcs = NpcsDaIlha.new()
	_npcs.name = "Npcs"
	_npcs.progressao = progressao
	_npcs.jogador_de = jogador_local
	add_child(_npcs)
	_hud.ligar_npcs(_npcs, progressao, bib)
	desafio_buggy = DesafioDoBuggy.new()          # o Buggy chega ao cais depois do treino (21/11/2026, docs/DESAFIO_DO_BUGGY_PLANO.md)
	desafio_buggy.progressao = progressao
	desafio_buggy.hud = _hud
	desafio_buggy.npcs = _npcs
	desafio_buggy.jogador_de = jogador_local
	desafio_buggy.biblioteca = bib
	add_child(desafio_buggy)
	resgate_do_bau = ResgateDoBau.new()           # 3ª missão (21/11/2026): o mímico e o Baú misterioso
	resgate_do_bau.progressao = progressao
	resgate_do_bau.hud = _hud
	resgate_do_bau.jogador_de = jogador_local
	add_child(resgate_do_bau)
	missao_da_alvida = MissaoDaAlvida.new()       # 5ª missão (22/11/2026): barril do vendedor de navios + duelo com a Alvida
	missao_da_alvida.progressao = progressao
	missao_da_alvida.hud = _hud
	missao_da_alvida.npcs = _npcs
	missao_da_alvida.jogador_de = jogador_local
	missao_da_alvida.biblioteca = bib
	missao_da_alvida.ir_a_ilha = ir_a_ilha
	add_child(missao_da_alvida)
	# Spawn natural (23/10/2026, pedido do dono: "permitir spawn em todas as ilhas"): os
	# personagens do mod nascem pelas regras do próprio mod em qualquer ilha.
	spawn_natural = SpawnNaturalMinePiece.new()
	spawn_natural.name = "SpawnNaturalMinePiece"
	add_child(spawn_natural)
	spawn_natural.ligar(raiz_do_mapa, mapa)
	spawn_natural.nasceu.connect(_ao_nascer_personagem_natural)
	_animais = PopulacaoDeAnimais.new()
	_animais.name = "Animais"
	add_child(_animais)
	_animais.animal_abatido.connect(_ao_abater_animal)
	_ia_inimigos = IaDosInimigos.new()
	_ia_inimigos.name = "IaDosInimigos"
	add_child(_ia_inimigos)
	_ia_animais = IaDosAnimais.new()
	_ia_animais.name = "IaDosAnimais"
	add_child(_ia_animais)
	_pomar = PomarDaIlha.new()
	_pomar.name = "Pomar"
	add_child(_pomar)
	_pomar.fruta_coletada.connect(_ao_coletar_fruta)
	_coleta = preload("res://src/historia/coleta/coleta_de_madeira.gd").new()
	_coleta.name = "ColetaDeMadeira"
	add_child(_coleta)
	_coleta.madeira_coletada.connect(func(qtd: int): _hud.avisar("+%d madeira · inventário N → MATERIAIS" % qtd))
	# Água: rasa deixa lento; funda, nado (docs/AGUA_PLANO.md).
	_na_agua = JogadorNaAgua.new()
	_na_agua.name = "JogadorNaAgua"
	_na_agua.jogador_de = jogador_local
	_na_agua.progressao = progressao
	add_child(_na_agua)
	_hud.ligar_agua(_na_agua)
	var luz_mergulho := preload("res://src/historia/agua/luz_de_mergulho.gd").new()
	luz_mergulho.name = "LuzDeMergulho"
	luz_mergulho.jogador_de = jogador_local
	add_child(luz_mergulho)
	# Em qual ilha o jogador está: teto de nível e aviso de chegada (Ilha dos Macacos).
	_ilhas = DetectorDeIlha.new()
	_ilhas.name = "DetectorDeIlha"
	_ilhas.progressao = progressao
	_ilhas.jogador_de = jogador_local
	add_child(_ilhas)
	_ilhas.ligar(mapa)
	_ilhas.chegou.connect(_ao_chegar_na_ilha)
	_ilhas.ilha_atual.connect(trocar_povoada)
	_ilhas.ilha_atual.connect(_atualizar_renascimento)
	_ilhas.ilha_atual.connect(_garantir_missao_da_ilha)      # a missão principal da ilha começa ao chegar (inclusive ao carregar um save lá)
	# Raid do Mine Piece (18/10/2026): bandeira na mão + segurar Z (src/historia/raid/raid.gd).
	raid = preload("res://src/historia/raid/raid.gd").new()
	raid.name = "Raid"
	raid.progressao = progressao
	raid.jogador_de = jogador_local
	raid.hud = _hud
	raid.raiz = raiz_do_mapa
	raid.caixas = _ilhas.caixas
	raid.ao_derrotar = _ao_derrotar_personagem_east_blue
	add_child(raid)
	baus_de_chefe = BausDeChefe.new()
	baus_de_chefe.name = "BausDeChefe"
	add_child(baus_de_chefe)
	baus_de_chefe.ligar(progressao, _hud, jogador_local)
	# Baú do topo das plataformas do Geppo (Ilha dos Macacos, 18/11/2026): fixo, uma vez por personagem, com a força de um chefe forte.
	for peca: Dictionary in mapa.get("pecas", []):
		if String(peca.get("id", "")) == "macacos_floresta_marca_do_bau_topo":
			baus_de_chefe.garantir_fixo(BausDeChefe.ID_DO_BAU_FIXO_DO_TOPO, (peca["posicao"] as Vector3) + Vector3.UP * 0.4, 150000.0)
	# Ilha dos Macacos v2 (22/11/2026): cachos de banana, totens e o fruto dourado das missões da ilha (E).
	props_dos_macacos = preload("res://src/historia/ilhas/macacos/props_de_missao.gd").new()
	props_dos_macacos.name = "PropsDosMacacos"
	add_child(props_dos_macacos)
	props_dos_macacos.ligar({"progressao": progressao, "hud": _hud}, jogador_local)
	if _ilhas.caixas.has(DetectorDeIlha.Ilhas.MACACOS):
		_hud.ligar_bussola(progressao, _ilhas.caixas[DetectorDeIlha.Ilhas.MACACOS], jogador_local)
	# Desenho por distância das ilhas JÁ montadas: longe = blocos + copas; fora de vista, nada. O chão (relevo, fundo) é de todas.
	_lod = LodDasIlhas.new()
	_lod.name = "LodDasIlhas"
	_lod.jogador_de = jogador_local
	add_child(_lod)
	_lod.preparar(_ilhas.caixas)
	_lod.registrar(por_ilha)
	_zona_de_combate = ZonaDeCombate.new()          # em combate: desenho curto e criaturas fora da zona latentes (10/11/2026)
	_zona_de_combate.name = "ZonaDeCombate"
	_zona_de_combate.jogador_de = jogador_local
	_zona_de_combate.raid = raid
	_zona_de_combate.lod = _lod
	add_child(_zona_de_combate)
	_nivel_dos_inimigos = NivelDosInimigos.new()      # inimigos comuns do mapa nunca ficam abaixo do jogador (10/11/2026)
	_nivel_dos_inimigos.name = "NivelDosInimigos"
	add_child(_nivel_dos_inimigos)
	_nivel_dos_inimigos.ligar(progressao)
	_perfil = PerfilGrafico.new()
	_perfil.name = "PerfilGrafico"
	_perfil.raiz_do_mapa = raiz_do_mapa
	add_child(_perfil)
	# AGORA as peças: o que não é de ilha nenhuma e a ilha do spawn (e, em testes, todas).
	_spawn_do_mapa = mapa["spawn"]["posicao"]
	var onde_nascer := _onde_nascer(mapa["spawn"]["posicao"])
	await _streaming.carregar_inicial(onde_nascer, _carregar_tudo())
	# Barcos comprados no vendedor (10/10/2026) atracam no cais dele — depois que os NPCs
	# e o cenário entram na física (a frota espera um quadro).
	_navegacao.ligar_frota(progressao)

	await MonitorDeCarga.etapa("Nascimento do jogador")
	_jogadores = Node3D.new()
	_jogadores.name = "Players"
	add_child(_jogadores)
	# Adiado pelo mesmo motivo do `Main`: criar o corpo no meio do `_ready` da
	# cena deixa a árvore "busy" para o que o Player monta no próprio `_ready`.
	preload("res://src/historia/missoes/inicio_da_jornada.gd").ligar(self)
	_nascer_jogador.call_deferred(onde_nascer)


## Frutas que o dono quer à mão para TESTAR (30/10/2026): em build de desenvolvimento COM janela, o inventário já traz `frutas_de_teste()`
## (idempotente: só completa até a quantidade, não acumula a cada abertura). Fora do jogo de verdade (exportado) e fora dos testes headless, que
## partem de inventário vazio. Desde 18/11/2026 só com `SOP_FRUTAS_DE_TESTE=1` (antes, ligado por padrão). Grava no save do jogador, como qualquer ganho de item.
## 08/11/2026 (pedido do dono): 10 de CADA fruta importada do Mine Piece — as traduções nativas, a Goro e as que rodam pelo fluxo do mod.
const QUANTIDADE_DE_TESTE := 10

## Vida e energia regeneram nesta vez a velocidade da regra original (08/11/2026, pedido do dono). Ver `HealthController.fator_de_regeneracao`.
const REGENERACAO_DA_HISTORIA := 3.0


static func frutas_de_teste() -> Dictionary:
	var saida := {}
	var ids: Array[String] = CatalogoFrutasMinePiece.ids()
	ids.append(PerfilDeFrutas.GORO_MINE_PIECE)
	ids.append_array(PerfilDeFrutas.frutas_so_do_mod())
	for id in ids:
		saida[id] = QUANTIDADE_DE_TESTE
	return saida


## As logias refatoradas vão sempre ao inventário em build de desenvolvimento com janela (pedido do dono, 24/11/2026),
## sem precisar de `SOP_FRUTAS_DE_TESTE`. Quantidade pequena: é para provar cada técnica, não para jogar.
static func frutas_refatoradas_de_teste() -> Dictionary:
	var saida := {}
	for id: String in CatalogoFrutasMinePiece.REFATORADAS:
		saida[id] = 3
	return saida


func _dar_frutas_de_teste() -> void:
	if OS.is_debug_build() and DisplayServer.get_name() != "headless":
		var refatoradas := frutas_refatoradas_de_teste()
		for id: String in refatoradas:
			progressao.dar_fruta_de_teste(id, int(refatoradas[id]))
	# 18/11/2026 (pedido do dono): ninguém começa com frutas dadas. Só com `SOP_FRUTAS_DE_TESTE=1` (e build de desenvolvimento) para quem precisa testar.
	if not OS.is_debug_build() or DisplayServer.get_name() == "headless" or OS.get_environment("SOP_FRUTAS_DE_TESTE") != "1":
		return
	var frutas := frutas_de_teste()
	for id: String in frutas:
		progressao.dar_fruta_de_teste(id, int(frutas[id]))


## Testes e o modo `SOP_CARREGAR_TUDO=1` montam TODAS as ilhas na entrada (como antes da carga por distância, 28/10/2026). Sem janela
## (headless) o padrão é carregar tudo, para os testes antigos não dependerem de onde o jogador está; `carregar_tudo_forcado` = 0
## liga a carga por distância num teste.
static var carregar_tudo_forcado := -1


static func _carregar_tudo() -> bool:
	if carregar_tudo_forcado >= 0:
		return carregar_tudo_forcado == 1
	return OS.get_environment("SOP_CARREGAR_TUDO") == "1" or DisplayServer.get_name() == "headless"


## Liga os sistemas a UMA ilha recém-montada (`StreamingDeIlhas`): cada um recebe só as peças dela. Corrotina.
func _ligar_ilha(id: String, sub: Dictionary) -> void:
	var bib := MapaMontador.biblioteca_em_uso()
	var raiz := _raiz_do_mapa
	var entidades: Array = []
	var criaturas: Array = []      # povoamento por ilha (10/11/2026): só a ilha do jogador tem criaturas ativas
	_subs_de_ilha[id] = sub
	await MonitorDeCarga.etapa("Companhia e navegação (navios)")
	_companhia.ligar_no_mapa(raiz, sub, bib)
	_navegacao.ligar_no_mapa(raiz, sub, bib)
	await MonitorDeCarga.etapa("NPCs")
	var n0 := _npcs.npcs.size()
	_npcs.ligar_no_mapa(raiz, sub, bib)
	entidades.append_array(_npcs.npcs.slice(n0))
	if props_dos_macacos != null:
		props_dos_macacos.ligar_no_mapa(raiz, sub)      # cachos, totens e fruto dourado das missões da Ilha dos Macacos
	await MonitorDeCarga.etapa("Inimigos do mapa")
	for inimigo in InimigoDoMapa.ligar_no_mapa(raiz, sub, bib):
		inimigo.derrotado.connect(_ao_derrotar_inimigo)
		entidades.append(inimigo)
		criaturas.append(inimigo)
	# Bestas colocadas pelo editor ganham rotina/combate, preservando o mapa salvo.
	await MonitorDeCarga.etapa("Bestas do mar")
	for besta in preload("res://src/historia/bestas_mar/populacao.gd").ligar(raiz, sub, bib, jogador_local, _relevo_marinho):
		besta.connect("morreu", _ao_abater_besta)
		criaturas.append(besta)
	# O boneco de duelo posto pela loja (aba "inimigos") luta de verdade e renasce.
	await MonitorDeCarga.etapa("Bonecos de duelo e bandidos")
	for ninho in NinhoDeInimigo.ligar_no_mapa(raiz, sub, bib, jogador_local):
		ninho.derrotado.connect(_ao_derrotar_lutador)
		entidades.append(ninho)
		criaturas.append(ninho)
	# Personagens do East Blue (Mine Piece, 17/10/2026): peças da loja com o comportamento
	# "mine_piece" viram personagens com a IA do mod (docs/EAST_BLUE_PLANO.md).
	await MonitorDeCarga.etapa("Personagens do Mine Piece (East Blue)", "modelos 3D e a IA do mod de cada um")
	for pers in PersonagensEastBlue.ligar_no_mapa(raiz, sub, bib):
		pers.derrotado.connect(_ao_derrotar_personagem_east_blue)
		entidades.append(pers)
		criaturas.append(pers)
	await MonitorDeCarga.etapa("Animais, pomar e coleta de madeira")
	if _deve_povoar(id):
		_animais.ligar(raiz, sub, bib, id, _caixa_da_ilha(id))
	else:
		_animais_pendentes[id] = true
	if _animais.jogador == null:
		var j := jogador_local()
		if j != null:
			_animais.definir_jogador(j)
	_latentes[id] = criaturas
	if not _deve_povoar(id):
		for c in criaturas:
			Povoamento.latente(c, true)
	_pomar.ligar(raiz, sub, bib, id)
	_coleta.ligar(raiz, sub, bib, progressao, _pomar)
	# Desenho por distância: ilha longe = relevo + blocos + copas; fora de vista, nada.
	await MonitorDeCarga.etapa("Desenho por distância (LOD)", "esconde o que está longe do jogador")
	if not id.is_empty():
		_lod.ligar_ilha(id, raiz, sub["pecas"], bib, _ilhas.caixas)
	_lod.registrar(entidades)
	if _perfil != null:
		_perfil.cobrir(raiz)


# --------------------------------------------------------------------------- povoamento por ilha (10/11/2026)
## Pedido do dono: "o spawn das criaturas fica restrito à ilha em que o jogador se encontra". Criaturas (inimigos, bonecos de duelo,
## personagens do East Blue, bestas, animais, spawn natural) só existem ATIVAS na ilha do jogador; as das outras ilhas montadas ficam
## latentes (`Povoamento`) e os animais nem são criados. Ao trocar de ilha, as da antiga ficam latentes e as da nova acordam.
## Sem restrição quando o mapa não tem ilhas (testes, editor) ou na carga total (`_carregar_tudo`, sem distância).
static var povoamento_por_ilha := true
var _povoada := ""
var _latentes := {}               # id da ilha → criaturas que ela criou
var _subs_de_ilha := {}           # id da ilha → sub-mapa (para criar os animais quando o jogador chegar)
var _animais_pendentes := {}      # id da ilha → true (animais ainda não criados)


func _restringe_por_ilha() -> bool:
	return povoamento_por_ilha and not _carregar_tudo() and _streaming != null


func _deve_povoar(id: String) -> bool:
	return not _restringe_por_ilha() or id.is_empty() or id == _povoada


## Chamado pelo detector quando o jogador passa a estar numa ilha (a primeira vez inclusive).
func trocar_povoada(novo: String) -> void:
	if not _restringe_por_ilha() or novo.is_empty() or novo == _povoada:
		return
	var antigo := _povoada
	_povoada = novo
	var bib := MapaMontador.biblioteca_em_uso()
	if not antigo.is_empty():
		_ia_inimigos.cancelar_fila()
		for c in _latentes.get(antigo, []):
			Povoamento.latente(c, true)
		var sub_antiga: Dictionary = _subs_de_ilha.get(antigo, {})
		if not sub_antiga.is_empty() and not _animais_pendentes.has(antigo):
			var ids: Array = []
			for p: Dictionary in sub_antiga.get("pecas", []):
				ids.append(p["id"])
			_animais.descarregar_ilha(antigo, ids)
			_animais_pendentes[antigo] = true
	var j := jogador_local()
	_ia_inimigos.ativar_em_lotes(_latentes.get(novo, []), j.global_position if j != null else Vector3.ZERO)
	if _animais_pendentes.has(novo) and _subs_de_ilha.has(novo):
		_animais_pendentes.erase(novo)
		_animais.ligar(_raiz_do_mapa, _subs_de_ilha[novo], bib, novo, _caixa_da_ilha(novo))
	if spawn_natural != null:
		spawn_natural.ilha_unica = novo


## Placa da ilha (para os animais que vivem na ilha toda). Vazia = mapa sem ilhas.
func _caixa_da_ilha(id: String) -> Rect2:
	return _streaming.caixas.get(id, Rect2()) if _streaming != null and not id.is_empty() else Rect2()


func ilha_povoada() -> String:
	return _povoada


## Tira a ilha dos sistemas ANTES de os nós dela serem liberados: as listas deixam de apontar para eles na hora.
func _desligar_ilha(id: String, ids_das_pecas: Array, nos: Array) -> void:
	if id.is_empty():
		return
	var da_ilha := {}
	for n in nos:
		if is_instance_valid(n):
			da_ilha[n.get_instance_id()] = true
	# Um nó é da ilha se ele ou um ancestral (até a raiz do mapa) está entre os que ela criou: as plantas de coleta, por exemplo, são
	# filhas das peças.
	var dela := func(n: Node) -> bool:
		var x := n
		while x != null and x != _raiz_do_mapa:
			if da_ilha.has(x.get_instance_id()):
				return true
			x = x.get_parent()
		return false
	_lod.descarregar_ilha(id)
	_latentes.erase(id)
	_subs_de_ilha.erase(id)
	if not _animais_pendentes.has(id):
		_animais.descarregar_ilha(id, ids_das_pecas)
	_animais_pendentes.erase(id)
	_pomar.descarregar_ilha(id)
	_npcs.npcs.assign(_npcs.npcs.filter(func(n: NpcDaIlha) -> bool: return is_instance_valid(n) and not dela.call(n)))
	_navegacao.barcos.assign(_navegacao.barcos.filter(func(b: CharacterBody3D) -> bool: return is_instance_valid(b) and not dela.call(b)))
	_coleta.plantas.assign(_coleta.plantas.filter(func(pl: Node) -> bool: return is_instance_valid(pl) and not dela.call(pl)))


## O barco que o jogador está pilotando impede a descarga da ilha onde está (e a do jogador nunca sai: a distância já garante).
func ilha_carregada(id: String) -> bool:
	return _streaming != null and _streaming.esta_carregada(id)


## Garante a ilha montada (corrotina): quem teletransporta o jogador para longe chama antes.
func garantir_ilha(id: String) -> void:
	if _streaming != null:
		await _streaming.garantir(id)


func _exit_tree() -> void:
	# O local NÃO é gravado aqui: neste ponto o jogador já saiu da árvore, `global_position` volta (0,0,0) e o save da Ilha dos Macacos era
	# sobrescrito por "ilha inicial, 0,0,0" (achado em 22/11/2026 abrindo e fechando o jogo de verdade). Quem grava: `_antes_de_sair` (tree_exiting).
	DanoDaHistoria.fator = 1.0
	DanoDaHistoria.fator_recebido = 1.0
	MapaMontador.sem_geometria_do_terreno = false      # o editor de mapa edita a peça lisa: nunca sem geometria


## Teste automatizado (`tools/dev_tests/…`) NÃO fica esperando a tela de escolha de corpo: ela bloqueava 263 testes que iniciam a história com progresso novo
## (15/11/2026). Escolhe sozinho o corpo de `corpo_de_teste` e SALVA no progresso, como a tela faria. O teste da própria tela liga `exigir_escolha_de_corpo`
## para ver a interface real. Fora de teste a entrada aparece em toda visita, com a aparência salva e os botões Jogar/Customizar.
static var exigir_escolha_de_corpo := false
static var corpo_de_teste := "masculino"


func _escolher_corpo() -> bool:
	if not exigir_escolha_de_corpo and GameFlow.executando_teste_automatizado():
		if progressao.corpo.is_empty():
			progressao.corpo = corpo_de_teste if corpo_de_teste in ProgressaoDoPersonagem.CORPOS else "masculino"
			progressao.salvar(caminho_do_progresso())
		return true
	var tela := preload("res://src/ui/entrada_historia.gd").new()
	tela.corpo = progressao.corpo
	tela.tom_de_pele = progressao.tom_de_pele
	tela.aparencia = progressao.aparencia.duplicate()
	add_child(tela)
	while true:
		var tipo: String = await tela.escolheu
		if tipo.is_empty():
			tela.queue_free()
			MonitorDeCarga.terminar()
			GameFlow.back_to_menu.call_deferred()
			return false
		var corpo_anterior := progressao.corpo
		var tom_anterior := progressao.tom_de_pele
		var aparencia_anterior := progressao.aparencia.duplicate()
		progressao.corpo = tipo
		progressao.tom_de_pele = tela.tom_de_pele
		progressao.aparencia = ProgressaoDoPersonagem.AparenciaHistoria.normalizar(tela.aparencia)
		if progressao.salvar(caminho_do_progresso()) == OK:
			tela.queue_free()
			return true
		progressao.corpo = corpo_anterior
		progressao.tom_de_pele = tom_anterior
		progressao.aparencia = aparencia_anterior
		tela.mostrar_erro()
	return false


## Onde o jogador nasce: o último chão gravado no save (se a ilha ainda existe no mapa e o ponto está nela), senão o spawn do mapa.
## Teste que escolhe a ilha (`ilha_de_teste`) ou força o save não usa isto: ele leva o jogador para onde precisa.
func _onde_nascer(spawn: Vector3) -> Vector3:
	var l := progressao.local_salvo
	if l.is_empty() or not ilha_de_teste.is_empty():
		return spawn
	var p := Vector3(float(l["x"]), float(l["y"]), float(l["z"]))
	if not _ilhas.caixas.has(str(l["ilha"])) or Ilhas_ilha_em(p) != str(l["ilha"]):
		return spawn
	return p + Vector3.UP * 0.3


func Ilhas_ilha_em(p: Vector3) -> String:
	return DetectorDeIlha.Ilhas.ilha_em(_ilhas.caixas, p)


const INTERVALO_DO_LOCAL := 10.0
## Chegar a uma ilha NOVA grava na hora (1 s de checagem): não depende de o jogo fechar direito nem de esperar o relógio de 10 s.
const CHECAGEM_DE_ILHA := 1.0
## Além da placa ainda conta como "na ilha" (praia/costa): a placa exata deixava o morro e a praia de fora e o save ficava na ilha ANTERIOR (22/11/2026).
const MARGEM_DO_LOCAL := 8.0
var _relogio_do_local := INTERVALO_DO_LOCAL
var _relogio_da_ilha := CHECAGEM_DE_ILHA


## Grava onde o jogador está, se estiver NUMA ILHA e em pé no chão (no mar/barco/ar o último chão firme é mantido).
## `fechando`: no fechamento da janela grava mesmo no ar (um salto no último instante não pode custar a ilha inteira).
func gravar_local(fechando := false) -> void:
	var j := jogador_local()
	if j == null or not j.is_inside_tree() or progressao == null or _reiniciando_campanha or (not fechando and not j.is_on_floor()):
		return
	var id := DetectorDeIlha.Ilhas.ilha_em(_ilhas.caixas, j.global_position, MARGEM_DO_LOCAL)
	if id.is_empty():
		return
	var p := j.global_position
	# Fora da placa (praia): leva o ponto para dentro dela, senão o jogador nasceria na água.
	var caixa: Rect2 = _ilhas.caixas[id]
	if DetectorDeIlha.Ilhas.distancia(caixa, p) > 0.0:
		var dentro := Vector2(p.x, p.z).clamp(caixa.position + Vector2.ONE, caixa.end - Vector2.ONE)
		p = Vector3(dentro.x, p.y, dentro.y)
	progressao.local_salvo = {"ilha": id, "x": p.x, "y": p.y, "z": p.z}
	progressao.salvar(caminho_do_progresso())


func _process(delta: float) -> void:
	if not progresso_forcado.is_empty():
		return
	_relogio_do_local -= delta
	if _relogio_do_local <= 0.0:
		_relogio_do_local = INTERVALO_DO_LOCAL
		gravar_local()
	_relogio_da_ilha -= delta
	if _relogio_da_ilha <= 0.0:
		_relogio_da_ilha = CHECAGEM_DE_ILHA
		_gravar_se_mudou_de_ilha()


func _gravar_se_mudou_de_ilha() -> void:
	var j := jogador_local()
	if j == null or progressao == null or not j.is_on_floor():
		return
	var id := DetectorDeIlha.Ilhas.ilha_em(_ilhas.caixas, j.global_position, MARGEM_DO_LOCAL)
	if not id.is_empty() and str(progressao.local_salvo.get("ilha", "")) != id:
		gravar_local()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and progresso_forcado.is_empty():
		gravar_local(true)
	elif what == NOTIFICATION_READY:
		tree_exiting.connect(_antes_de_sair)


## `tree_exiting` sai ANTES dos filhos (o jogador ainda está na árvore): troca de cena e `quit()` também gravam o local.
func _antes_de_sair() -> void:
	if progresso_forcado.is_empty():
		gravar_local(true)


func _nascer_jogador(posicao: Vector3) -> void:
	var jogador := colocar_civil(_jogadores, multiplayer.get_unique_id(), posicao, progressao.corpo, progressao.tom_de_pele, progressao.aparencia)
	aplicar_progressao(jogador, progressao, true)
	if _animais != null:
		_animais.definir_jogador(jogador)
	if not ilha_de_teste.is_empty():
		# O raio até o chão precisa da física já com as peças do mapa.
		await get_tree().physics_frame
		await get_tree().physics_frame
		ir_a_ilha(ilha_de_teste, true)
	_terminar_carga()


## Fim da carga: devolve o processamento da cena e fecha o monitor (resumo no console e em `user://carga/ultima_carga.txt`).
func _terminar_carga() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	MonitorDeCarga.terminar()


static func caminho_do_progresso() -> String:
	return progresso_forcado if not progresso_forcado.is_empty() else PROGRESSO_PADRAO


func jogador_local() -> Player:
	if _jogadores == null or not multiplayer.has_multiplayer_peer():
		return null
	return _jogadores.get_node_or_null(str(multiplayer.get_unique_id())) as Player


## Status → corpo. `cheio` enche vida e energia (nascer); sem ele, ganhar Vida só
## aumenta o máximo e soma a diferença — tomar ponto não cura o que já apanhou.
static func aplicar_progressao(jogador: Player, prog: ProgressaoDoPersonagem, cheio := false) -> void:
	if jogador == null or prog == null:
		return
	JogadorDoMod.ligar(jogador, prog)        # conquistas e recompensa do Mine Piece (ver jogador_do_mod.gd)
	var hp_antes := jogador.max_health
	jogador.capacidades = prog.capacidades()
	# O nível do personagem no corpo: a condição "Nível mínimo" das skills do Builder.
	jogador.set_meta("nivel", prog.nivel)
	jogador.set_meta("bonus_fisico_historia", prog.RegrasDosAtributos.bonus_fisico(prog.nivel))
	jogador.set_meta("nivel_historia", prog.nivel)
	var modelo := jogador.modelo_visual()
	if is_instance_valid(modelo) and modelo.get_meta("raca_id", "") != prog.raca:
		preload("res://src/historia/agua/visual_sharkman.gd").aplicar(modelo, prog.raca)
	equipar_fruta(jogador, prog.fruta_a_equipar())
	var arma := jogador.get_node_or_null("EspadaDaHistoria")
	if arma != null:
		if not arma.has_meta("ef_durabilidade"):
			arma.set_meta("ef_durabilidade", true)
			arma.acertou_com_lamina.connect(_ao_acertar_com_lamina.bind(prog, arma))
		if prog.item_em_uso() == "espada" and prog.lamina_ef != "":
			arma.aplicar_lamina_ef(prog.lamina_ef)      # lâmina do Epic Fight (10/11/2026)
			arma.definir_secundaria(prog.lamina_ef_sec)
		else:
			arma.limpar_lamina_ef()
			arma.aplicar(prog.item_em_uso() == "espada")
	var alimentacao := jogador.get_node_or_null("AlimentacaoVisual")
	if alimentacao != null:
		var provisoes = preload("res://src/historia/tripulantes/provisoes.gd")
		var quantidade: int = provisoes.quantidade_agua(prog) if prog.item_em_uso() == "agua" else provisoes.quantidade_comida(prog)
		var em_uso := prog.item_em_uso()
		var qual: String = provisoes.proxima_bebida(prog) if em_uso == "agua" else (provisoes.proxima_comida(prog) if em_uso == "comida" else "")
		alimentacao.equipar(em_uso, quantidade, qual)       # `qual`: o modelo voxel do alimento que vai ser consumido
	jogador.max_health = prog.hp_maximo()
	jogador.max_energy = prog.energia_maxima()

	if cheio:
		jogador.health = jogador.max_health
		jogador.energy = jogador.max_energy
	else:
		jogador.health = clampf(jogador.health + maxf(jogador.max_health - hp_antes, 0.0), 0.0, jogador.max_health)
		jogador.energy = minf(jogador.energy, jogador.max_energy)


## Põe (ou tira) a Akuma no Mi no corpo: a fruta em si, os números deste modo e a
## regeneração de energia da história. Ponto ÚNICO — o Player não sabe que modo é.
static func equipar_fruta(jogador: Player, id: String) -> void:
	if jogador == null:
		return
	var perfil: PerfilDeFrutas = null
	if not id.is_empty() and PERFIS_DE_FRUTA.has(id):
		perfil = load(PERFIS_DE_FRUTA[id]) as PerfilDeFrutas
	elif id == GoroGoroMinePiece.ID:
		# Tradução do Mine Piece (18/10/2026): técnicas no controlador, R/Z do mod.
		perfil = GoroGoroMinePiece.perfil()
	elif FrutasDoMod.contem(id):
		perfil = FrutasDoMod.perfil(id)
	elif CatalogoFrutasMinePiece.contem(id):
		perfil = CatalogoFrutasMinePiece.perfil(id)
	elif KitDoBuilder.e_do_builder(id):
		# Kit e frutas do Builder (06/10/2026): as skills publicadas, escala da história.
		perfil = KitDoBuilder.perfil_da_historia(id)
	elif not id.is_empty():
		# Frutas da arena (vendedor de frutas, 03/10/2026): o kit da arena na escala da história.
		perfil = PerfilDeFrutas.da_arena(id)
	if perfil != null:
		var problemas := perfil.problemas()
		if not problemas.is_empty():
			push_warning("[Modo História] perfil da fruta %s: %s" % [id, ", ".join(problemas)])
	jogador.perfil_de_frutas = perfil
	jogador._vida.fator_de_regeneracao = REGENERACAO_DA_HISTORIA
	# A regeneração da arena é percentual (0,5%/s): com energia 10 dá 0,05/s. O perfil
	# manda o número da história; 0 devolve a regra da arena.
	# Sem fruta ou com fruta do Mine Piece: a regeneração do mod, pelo nível (A9); as da arena e do Builder têm a sua.
	if perfil == null or perfil.fiel_ao_mod:
		jogador._vida.regen_energia_do_modo = preload("res://src/historia/atributos_mine_piece.gd").energia_por_segundo(
			int(jogador.get_meta("nivel_historia", 1)))
		jogador._vida.regen_energia_mod_dobra_com_vida_cheia = true
	else:
		jogador._vida.regen_energia_do_modo = perfil.regen_de_energia
		jogador._vida.regen_energia_mod_dobra_com_vida_cheia = false
	var goro_mp := GoroGoroMinePiece.de(jogador)
	if id == GoroGoroMinePiece.ID and goro_mp == null:
		goro_mp = GoroGoroMinePiece.new()
		goro_mp.name = "GoroGoroMinePiece"
		jogador.add_child(goro_mp)
	elif id != GoroGoroMinePiece.ID and goro_mp != null:
		jogador.remove_child(goro_mp)   # sai já: a fruta seguinte não pode achá-lo
		goro_mp.queue_free()
	var fruta_mp := ControladorFrutaMinePiece.de(jogador)
	if fruta_mp != null and fruta_mp.fruta_id != id:
		jogador.remove_child(fruta_mp)
		fruta_mp.queue_free()
		fruta_mp = null
	if (FrutasDoMod.contem(id) or CatalogoFrutasMinePiece.contem(id)) and fruta_mp == null:
		# Fruta do mod: o jogador usa o FLUXO DO MOD (procedures traduzidas), sem skill builder nem executor
		# à mão (decisão do dono, 03/11/2026). As fichas antigas (`*_mine_piece`) seguem pelo controlador antigo.
		fruta_mp = ControladorFrutaDoMod.new() if FrutasDoMod.contem(id) else ControladorFrutaMinePiece.new()
		fruta_mp.name = "FrutaMinePiece"
		fruta_mp.fruta_id = id
		jogador.add_child(fruta_mp)
	if jogador.current_fruit_id != id:
		# Adiado como no nascimento: equipar mexe no modelo montado no `_ready`.
		jogador.call_deferred("equip_fruit", id)
	if not id.is_empty():
		jogador.combat_mode = "fruit"


## F8 › Corrida: o mesmo caminho do organizador (requisito, trava, prêmio).
## F8 › "Ir à Ilha dos Macacos": põe o jogador em terra, na ponta do píer (teste).
func _ir_a_ilha_dos_macacos() -> void:
	ir_a_ilha(DetectorDeIlha.Ilhas.MACACOS)


## Leva o jogador à borda oeste da placa da ilha `id`, no chão. `renascer_la`: o ponto
## de renascer passa a ser ali (o lançador de teste, `TesteDeIlha`). Devolve se levou.
func ir_a_ilha(id: String, renascer_la := false) -> bool:
	var j := jogador_local()
	var caixa: Rect2 = _ilhas.caixas.get(id, Rect2())
	if j == null or not caixa.has_area():
		push_warning("[Modo História] ilha \"%s\" não está no mapa" % id)
		return false
	# Ilha ainda não montada (carga por distância): monta primeiro e só então leva o jogador (senão cairia no vazio).
	if _streaming != null and not _streaming.esta_carregada(id):
		_ir_a_ilha_quando_montada(id, renascer_la)
		return true
	j.global_position = _ponto_de_chegada(id)
	j.velocity = Vector3.ZERO
	if renascer_la:
		j.ponto_de_renascimento = j.global_position
	return true


## O chão na borda oeste da placa da ilha `id` (6 m para dentro), 1,2 m acima: onde `ir_a_ilha` põe o jogador e onde ele renasce depois de morrer lá.
func _ponto_de_chegada(id: String) -> Vector3:
	var caixa: Rect2 = _ilhas.caixas.get(id, Rect2())
	var onde := Vector3(caixa.position.x + 6.0, 80.0, caixa.get_center().y)
	var hit := jogador_local().get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(onde, onde + Vector3.DOWN * 120.0, 1))
	return (hit["position"] if not hit.is_empty() else Vector3(onde.x, 0.0, onde.z)) + Vector3.UP * 1.2


## Morrer numa ilha NÃO volta o jogador à inicial (pedido do dono, 22/11/2026): o ponto de renascimento acompanha a ilha em que ele está. Na ilha inicial
## vale o spawn do mapa; nas demais, o ponto de chegada dela (a borda oeste, longe do chefe).
func _atualizar_renascimento(id: String) -> void:
	var j := jogador_local()
	if j == null or id.is_empty() or not _ilhas.caixas.has(id):
		return
	if id == DetectorDeIlha.Ilhas.INICIAL:
		if _spawn_do_mapa != Vector3.INF:
			j.ponto_de_renascimento = _spawn_do_mapa
		return
	j.ponto_de_renascimento = _ponto_de_chegada(id)


func _ir_a_ilha_quando_montada(id: String, renascer_la: bool) -> void:
	await _streaming.garantir(id)
	ir_a_ilha(id, renascer_la)


func _correr_pelo_f8() -> void:
	var r := corrida.pedir_largada()
	_hud.avisar(r if not r.is_empty() else "Valendo! Não dá para descer do caranguejo até o fim da corrida.")


## O boneco de duelo do mapa NÃO dá XP (decisão do dono, 30/09/2026): só o aviso.
## O BANDIDO dá XP (08/10/2026) e conta para a missão do Guarda da vila. Desde 18/10/2026 o
## O trecho "  ·  +N moedas" do aviso de abate ("" se não pagou).
static func _moedas_txt(moedas: int) -> String:
	return "  ·  +%d moeda%s" % [moedas, "" if moedas == 1 else "s"] if moedas > 0 else ""


## XP de TODO abate é a recompensa do Mine Piece (`Recompensa`), pela vida/força da vítima.
const Recompensa := preload("res://src/historia/recompensa_mine_piece.gd")


## DROP DE PROVISÕES. 12/11/2026 (pedido do dono): inimigo derrotado solta pão (então 1–2 pães com 60 % de chance). 22/11/2026 (pedido do dono): TODO inimigo derrotado
## solta de 1 a 2 PÃES **e** de 1 a 2 ÁGUAS (potável), sempre — as chances viraram 100 %. Inimigo = bandido, inimigo do mapa, personagem do East Blue, capanga inclusive.
## Vai direto às provisões (Comida e Água da barra, botão direito). Boneco de duelo e animais não soltam. Devolve o trecho do aviso ("  ·  +2 pães  ·  +1 água") ou "".
## GATILHO: se virar farm de comida, voltar `CHANCE_DE_PAO`/`CHANCE_DE_AGUA` abaixo de 1,0.
const CHANCE_DE_PAO := 1.0
const PAES_POR_DROP := Vector2i(1, 2)
const CHANCE_DE_AGUA := 1.0
const AGUAS_POR_DROP := Vector2i(1, 2)
const ID_DA_AGUA := "agua_potavel"


func _sortear_provisoes() -> String:
	if progressao == null:
		return ""
	var Prov := preload("res://src/historia/tripulantes/provisoes.gd")
	var texto := ""
	if randf() < CHANCE_DE_PAO:
		var n := randi_range(PAES_POR_DROP.x, PAES_POR_DROP.y)
		if Prov.guardar(progressao, "pao", n):
			texto += "  ·  +%d pão" % n if n == 1 else "  ·  +%d pães" % n
	if randf() < CHANCE_DE_AGUA:
		var n := randi_range(AGUAS_POR_DROP.x, AGUAS_POR_DROP.y)
		if Prov.guardar(progressao, ID_DA_AGUA, n):
			texto += "  ·  +%d água" % n if n == 1 else "  ·  +%d águas" % n
	if not texto.is_empty():
		progressao.mudou.emit()
	return texto


func _ao_derrotar_lutador(ninho: NinhoDeInimigo) -> void:
	if ninho.comportamento != NinhoDeInimigo.BANDIDO:
		_hud.avisar("Boneco de duelo derrotado  ·  volta em %d s" % roundi(InimigoDoMapa.tempo_de_renascer))
		return
	var fama := Recompensa.xp_de_abate(float(NinhoDeInimigo.VIDA_DO_BANDIDO))
	var xp := progressao.previa_do_abate(fama)
	var moedas := progressao.ganhar_ouro_de_abate(xp)      # 1 moeda a cada 50 de XP (pedido do dono, 20/11/2026)
	if is_instance_valid(ninho.boneco):
		XpFlutuante.sobre(ninho.boneco, "Bandido", xp)       # o XP no lugar do nome, no mundo
	var texto := "Bandido derrotado  ·  +%d XP" % xp + _moedas_txt(moedas) + _sortear_provisoes()
	for id in progressao.contar_abate(NinhoDeInimigo.BANDIDO):
		var d := preload("res://src/historia/missoes/missoes.gd").dados(id)
		texto += "  ·  %s %d / %d" % [d["nome"], progressao.abates_da_missao(id), int(d["meta"])]
	# O aviso ANTES de somar o XP: se subir de nível, o "Level Up!" ganha da notificação.
	_hud.avisar(texto)
	progressao.ganhar_xp_de_abate(fama)


## Missão do Guarda "Vencer a corrida dos caranguejos": vale o 1º lugar (o prêmio de
## moedas da corrida é outro: completar em até 5:00).
func _ao_terminar_corrida(resultado: Dictionary) -> void:
	if bool(resultado.get("completou", false)) and int(resultado.get("posicao", 0)) == 1:
		progressao.contar_abate("corrida")


func _ao_chegar_na_ilha(ilha: String, primeira_vez: bool) -> void:
	var texto := "Você chegou à %s" % DetectorDeIlha.Ilhas.nome(ilha)
	_hud.avisar(texto)


## Ilha dos Macacos: pisar nela (ou nascer/carregar nela) aceita sozinha "O Rei da Selva" (a luta contra o Gorila-rei). Só uma vez: com a missão já aceita, pronta
## ou entregue, não faz nada.
func _garantir_missao_da_ilha(ilha: String) -> void:
	if ilha != DetectorDeIlha.Ilhas.MACACOS or progressao == null:
		return
	if progressao.aceitar_missao("rei_da_selva"):
		_hud.avisar("Nova missão: O Rei da Selva  ·  derrote o Gorila-rei no Trono (estrada a nordeste da vila)")


## XP pela dificuldade de cada espécie (ficha `xp`, 08/10/2026; era 1 para todos) e o
## item "none" (= nada, por enquanto — quando houver itens, é aqui que o drop entra).
func _ao_abater_animal(animal: AnimalDaIlha) -> void:
	var fama := Recompensa.xp_de_abate(animal.max_health, -1.0, -1.0, float(animal.ficha.get("armadura", 0.0)))
	var xp := progressao.previa_do_abate(fama)
	var moedas := progressao.ganhar_ouro_de_abate(xp)      # 1 moeda a cada 50 de XP (pedido do dono, 20/11/2026)
	XpFlutuante.sobre(animal, animal.nome_de_exibicao(), xp)
	_hud.avisar("%s abatido  ·  +%d XP%s" % [animal.nome_de_exibicao(), xp, _moedas_txt(moedas)])
	progressao.ganhar_xp_de_abate(fama)
	if animal.boss() and baus_de_chefe != null:
		baus_de_chefe.soltar(animal.global_position, float(fama), animal.nome_de_exibicao())
	if animal.especie == "gorila_rei":
		# Missão principal da ilha: conta e se ENTREGA sozinha (o prêmio chega na hora, sem NPC).
		progressao.contar_abate("gorila_rei")
		if progressao.entregar_missao("rei_da_selva"):
			var d := preload("res://src/historia/missoes/missoes.gd").dados("rei_da_selva")
			_hud.avisar("Missão concluída: %s  ·  +%d XP  ·  +%d moedas" % [d["nome"], int(d["xp"]), int(d["ouro"])])


## Bestas do mar também valem XP pela dificuldade (08/10/2026): a mesma regra dos
## animais, sobre a vida e o dano do perfil (bovina 175, girafa 135, javali 270, Sea
## Serpent 800).
func _ao_abater_besta(besta: Node3D) -> void:
	var ficha: Dictionary = besta.get("ficha")
	var fama := Recompensa.xp_de_abate(float(ficha.get("vida", 1.0)))
	var xp := progressao.previa_do_abate(fama)
	var moedas := progressao.ganhar_ouro_de_abate(xp)      # 1 moeda a cada 50 de XP (pedido do dono, 20/11/2026)
	XpFlutuante.sobre(besta, str(ficha.get("nome", "Besta do mar")), xp)
	_hud.avisar("%s abatida  ·  +%d XP%s" % [str(ficha.get("nome", "Besta do mar")), xp, _moedas_txt(moedas)])
	progressao.ganhar_xp_de_abate(fama)


## DOMA (decisões do dono, 01/10/2026): fruta do pomar na mão + Y perto de um herbívoro
## domável (até 3 m). Cada tentativa gasta 1 fruta; sorte fixa de 35 %. Domado vira pet
## no lugar (se houver menos de 6 fora; senão vai para o inventário).
const ALCANCE_DA_DOMA := 3.0
static var chance_de_doma := 0.35


func _tentar_domar(fruta_id: String) -> void:
	var jogador := jogador_local()
	if jogador == null or _animais == null:
		return
	var animal := _herbivoro_mais_perto(jogador)
	if animal == null:
		_hud.avisar("Nenhum animal domável a até %d m" % int(ALCANCE_DA_DOMA))
		return
	if not progressao.gastar_fruta_do_pomar(fruta_id):
		return
	var bib := MapaMontador.biblioteca_em_uso()
	var fruta := str(bib.info(fruta_id)["nome"]) if bib.tem(fruta_id) else fruta_id
	var nome := animal.nome_de_exibicao()
	if randf() >= chance_de_doma:
		_hud.avisar("%s comeu a %s, mas não confiou em você  ·  %d%% por fruta" % [nome, fruta.to_lower(),
			roundi(chance_de_doma * 100.0)])
		return
	var posicao := animal.global_position
	var yaw: float = animal.get("_yaw")
	_animais.retirar_domado(animal)
	var r: Dictionary = _companhia.adotar(animal.especie, nome, posicao, yaw)
	_hud.avisar("%s domado!%s" % [nome, "" if r["fora"] else "  ·  6 pets já fora: foi para o inventário (M › Inventário)"])


func _herbivoro_mais_perto(jogador: Node3D) -> AnimalDaIlha:
	var melhor: AnimalDaIlha = null
	var melhor_d := ALCANCE_DA_DOMA
	for a in _animais.animais:
		if not a.vivo() or not a.visible or not FichaDeAnimal.domavel(a.ficha):
			continue
		var d := Vector2(a.global_position.x - jogador.global_position.x,
			a.global_position.z - jogador.global_position.z).length() - a.raio_de_interacao()
		if d <= melhor_d and absf(a.global_position.y - jogador.global_position.y) < 3.0:
			melhor_d = d
			melhor = a
	return melhor


## Fruta do chão recolhida (passando por cima): vai para a aba FRUTAS do inventário.
func _ao_coletar_fruta(fruta_id: String) -> void:
	progressao.ganhar_fruta_do_pomar(fruta_id)
	var bib := MapaMontador.biblioteca_em_uso()
	_hud.avisar("+1 %s" % (str(bib.info(fruta_id)["nome"]) if bib.tem(fruta_id) else fruta_id))


## Personagem do East Blue: XP pela dificuldade (vida e dano do soco com a força dele),
## a mesma regra dos animais e das bestas.
func _ao_nascer_personagem_natural(p: PersonagemMinePiece) -> void:
	p.derrotado.connect(_ao_derrotar_personagem_east_blue)
	if _lod != null:
		_lod.registrar([p])


func _ao_derrotar_personagem_east_blue(p: PersonagemMinePiece) -> void:
	# 19/11/2026, bug do dono: marinheiros e piratas (capangas de raid e de bando) NÃO davam XP (regra de 08/11). Agora dão, como qualquer
	# personagem; o anti-farm segue no teto de `previa_do_abate`. Só o baú é exclusivo de chefe. GATILHO: se virar farm, limitar por ninho/raid.
	var fama := Recompensa.xp_do_personagem(p)
	var xp := progressao.previa_do_abate(fama)
	var moedas := progressao.ganhar_ouro_de_abate(xp)      # 1 moeda a cada 50 de XP (pedido do dono, 20/11/2026)
	XpFlutuante.sobre(p, p.nome_de_exibicao(), xp)
	var extra := ""
	if str(p.ficha.get("id", "")) == "macaco_humanoide":
		for id in progressao.contar_abate("macaco"):       # missão "Os saqueadores" (Ilha dos Macacos v2)
			var d := preload("res://src/historia/missoes/missoes.gd").dados(id)
			extra += "  ·  %s %d / %d" % [d["nome"], progressao.abates_da_missao(id), int(d["meta"])]
	_hud.avisar("%s derrotado  ·  +%d XP%s%s%s" % [p.nome_de_exibicao(), xp, _moedas_txt(moedas), _sortear_provisoes(), extra])
	progressao.ganhar_xp_de_abate(fama)
	if bool(p.ficha.get("chefe", false)) and baus_de_chefe != null:
		baus_de_chefe.soltar(p.global_position, float(fama), p.nome_de_exibicao())      # o chefe solta um baú com uma fruta


func _ao_derrotar_inimigo(inimigo: InimigoDoMapa) -> void:
	var fama := Recompensa.xp_de_abate(inimigo.max_health)
	var xp := progressao.previa_do_abate(fama)
	var moedas := progressao.ganhar_ouro_de_abate(xp)      # 1 moeda a cada 50 de XP (pedido do dono, 20/11/2026)
	# O aviso de XP vem ANTES de somar: se subir de nível, o "Level Up!" (emitido
	# dentro de `ganhar_xp`) toma o lugar dele — o marco raro ganha da notificação.
	XpFlutuante.sobre(inimigo, "Inimigo", xp)
	_hud.avisar("Inimigo derrotado  ·  +%d XP%s%s" % [xp, _moedas_txt(moedas), _sortear_provisoes()])
	progressao.ganhar_xp_de_abate(fama)


## TESTE (painel F8): um parceiro de treino com o MESMO corpo e o MESMO executor do
## jogador. Os inimigos do mapa são estáticos; sem ele, defesa, aparo, riposte e finta
## só existiam nos testes automáticos, e o playtest que o plano pede não tinha contra
## quem acontecer. Pedir de novo troca o modo e o traz de volta para a frente do jogador.
func invocar_boneco(chave: StringName) -> BonecoDeDuelo:
	var jogador := jogador_local()
	if jogador == null or jogador.combate_direcional == null or not MODOS_DO_BONECO.has(chave):
		return null
	var ponto := _ponto_do_boneco(jogador)
	if not is_instance_valid(_boneco) or _boneco.health <= 0.0:
		remover_boneco()
		_boneco = BonecoDeDuelo.new()
		_boneco.name = "BonecoDeDuelo"
		# Posição ANTES de entrar na árvore: nascido na origem, ele pode aparecer dentro do
		# jogador e virar plataforma (docs/erros.md, 16/09).
		_boneco.position = to_local(ponto)
		add_child(_boneco)
		var novo_cerebro := CerebroDeTreino.new()
		novo_cerebro.name = "CerebroDeTreino"
		_boneco.add_child(novo_cerebro)
		novo_cerebro.montar(_boneco, jogador)
		_boneco.derrotado.connect(_ao_derrotar_boneco)
	var cerebro := _boneco.get_node("CerebroDeTreino") as CerebroDeTreino
	cerebro.modo = MODOS_DO_BONECO[chave]
	cerebro.intervalo = INTERVALO_DO_BONECO
	cerebro.sequencia = _sequencia_sorteada(_boneco.combate_direcional.estilo)
	_boneco.combate_direcional.cancelar(&"trocou_de_modo")
	_boneco.combate_direcional.baixar_guarda()
	_boneco.parar()
	_boneco.global_position = ponto
	_boneco.encarar(jogador.global_position)
	_hud.avisar("Boneco de duelo pronto  ·  F8 troca o modo")
	return _boneco


func remover_boneco() -> void:
	if is_instance_valid(_boneco):
		# Fora da árvore JÁ: um boneco novo pedido no mesmo quadro não esbarra no velho.
		if _boneco.get_parent() != null:
			_boneco.get_parent().remove_child(_boneco)
		_boneco.queue_free()
	_boneco = null


func _ponto_do_boneco(jogador: Player) -> Vector3:
	var frente := jogador.combate_direcional.ator.base_do_corpo() * Vector3.FORWARD
	frente.y = 0.0
	frente = frente.normalized() if frente.length_squared() > 0.0001 else Vector3.FORWARD
	return jogador.global_position + frente * DISTANCIA_DO_BONECO


## Direções SORTEADAS entre as que o estilo tem: numa sequência fixa, o jogador
## defenderia pelo ritmo e não pela leitura da carga. (Direção sem golpe travaria o
## cérebro, que só avança a sequência quando o pedido é aceito.)
static func _sequencia_sorteada(estilo: EstiloCorpoACorpo) -> Array[int]:
	var existentes := estilo.direcoes_com_golpe()
	var sequencia: Array[int] = []
	for i in 16:
		sequencia.append(existentes.pick_random())
	return sequencia


## Cada golpe que acerta com uma arma do Epic Fight gasta 1 uso (o mod: `hurtAndBreak(1)`); zerou = quebrou, some do inventário.
static func _ao_acertar_com_lamina(id: String, prog: ProgressaoDoPersonagem, arma: Node) -> void:
	if prog != null and prog.gastar_durabilidade(id) and is_instance_valid(arma):
		var hud := arma.get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("avisar"):
			hud.avisar("%s quebrou!" % str(LaminasEpicFight.dados(id).get("nome", "A arma")))


func _ao_derrotar_boneco(boneco: BonecoDeDuelo) -> void:
	_hud.avisar("Boneco de duelo derrotado  ·  F8 invoca outro")
	# Um instante para o último acerto aparecer. Sem XP: é ferramenta de teste.
	get_tree().create_timer(1.0).timeout.connect(boneco.queue_free)


## TESTE (painel F8): comer uma fruta agora. No jogo de verdade a fruta é uma peça do
## mapa (categoria "frutas"); este botão existe para provar o kit sem procurar a peça.
func dar_fruta(id: String) -> void:
	if id == KitDoBuilder.ID:
		if not KitDoBuilder.disponivel():
			_hud.avisar("Nenhuma skill de Jogador publicada no Skills Builder")
		elif progressao.comer_fruta(id):
			_hud.avisar("%s equipado  ·  %s" % [KitDoBuilder.NOME, ", ".join(KitDoBuilder.teclas())])
		else:
			_hud.avisar("O %s já está equipado" % KitDoBuilder.NOME)
		return
	if not PERFIS_DE_FRUTA.has(id):
		push_warning("[Modo História] fruta sem perfil: %s" % id)
		return
	if progressao.comer_fruta(id):
		_hud.avisar("Você comeu a %s  ·  Z, X, C e F liberados" % id.capitalize())
	else:
		_hud.avisar("Você já é usuário da %s" % id.capitalize())


func tirar_fruta() -> void:
	if progressao.fruta.is_empty():
		return
	progressao.tirar_fruta()
	_hud.avisar("Fruta removida")


## Só chamado depois da confirmação da janela M. Grava primeiro; um erro de
## disco mantém a campanha atual. Recarregar limpa também pets, barcos e efeitos.
func reiniciar_campanha() -> void:
	if _reiniciando_campanha:
		return
	var nova := ProgressaoDoPersonagem.new()
	var erro := nova.salvar(caminho_do_progresso())
	if erro != OK:
		_hud.avisar("Não foi possível reiniciar: falha ao salvar (%s)." % error_string(erro))
		return
	_reiniciando_campanha = true
	_recarregar_campanha.call_deferred()


func _recarregar_campanha() -> void:
	var erro := get_tree().reload_current_scene()
	if erro != OK:
		var restauracao := progressao.salvar(caminho_do_progresso())
		_reiniciando_campanha = restauracao != OK
		_hud.avisar("Não foi possível recarregar. Seu progresso foi preservado." if restauracao == OK else
			"Progresso zerado. Reabra o Modo História para começar novamente.")


## Itens do mod (biscoito) mudaram: só SALVA, com 3 s de atraso e sem reaplicar a progressão (reaplicar reequipa a fruta no meio da técnica).
var _salvar_itens_pendente := false

func _salvar_itens_adiado() -> void:
	if _salvar_itens_pendente or not is_inside_tree():
		return
	_salvar_itens_pendente = true
	get_tree().create_timer(3.0).timeout.connect(func():
		_salvar_itens_pendente = false
		if progressao != null and not _reiniciando_campanha:
			progressao.salvar(caminho_do_progresso()))


func _ao_mudar_progresso() -> void:
	if _reiniciando_campanha:
		return
	aplicar_progressao(jogador_local(), progressao)
	# Um item na mão por vez: vara/espada ativas guardam a fruta do pomar
	# (ela volta ao inventário; usam o mesmo encaixe da mão direita).
	if _mao != null and _mao.tem_fruta() and progressao.item_em_uso() in ["vara", "espada", "machado", "agua", "comida", "pokebola", "bandeira"]:
		_mao.guardar()
	var erro := progressao.salvar(caminho_do_progresso())
	if erro != OK:
		push_warning("[Modo História] progresso não foi salvo: %s" % error_string(erro))


## O jogador do Modo História, pronto e já na árvore. É FONTE ÚNICA: o "Testar" do
## editor de mapa chama esta mesma função, para o teste ser o jogo de verdade.
## `pai` precisa estar na origem (a posição é aplicada como local).
static func colocar_civil(pai: Node3D, id: int, posicao: Vector3, corpo := "masculino", tom := ProgressaoDoPersonagem.TonsDePele.PADRAO, aparencia: Dictionary = {}) -> Player:
	var jogador: Player = load("res://Player.gd").new()
	jogador.name = str(id)
	jogador.set_multiplayer_authority(id)
	jogador.set_meta("corpo_historia", corpo if corpo in ProgressaoDoPersonagem.CORPOS else "masculino")
	jogador.set_meta("tom_de_pele", ProgressaoDoPersonagem.TonsDePele.normalizar(tom))
	jogador.set_meta("aparencia_historia", ProgressaoDoPersonagem.AparenciaHistoria.normalizar(aparencia))
	# ANTES do `add_child`: o `_ready` do Player já pode ler as capacidades, e o
	# corpo não pode existir nem um quadro com o combate liberado.
	jogador.capacidades = CapacidadesDoJogador.civil()
	jogador.ecos_de_movimento_ligados = false
	# Cápsula no lugar da caixa: pés no chão em encosta e beirada baixa vencida
	# (decisão do dono, 01/10/2026 — só aqui; a arena segue com a caixa).
	jogador.colisor_capsula = true
	jogador.escala_de_modo = Player.escala_para_altura_dos_inimigos()      # 19/11/2026: do tamanho dos piratas e marinheiros básicos (antes 27 % menor)
	jogador.ponto_de_renascimento = posicao
	# `position` local antes de entrar é seguro com o pai na origem.
	# (A regra 3 do guia é sobre `global_position`/`look_at` fora da árvore.)
	jogador.position = posicao
	pai.add_child(jogador)
	instalar_combate_direcional(jogador)
	# O Player nasce com `FRUTA_INICIAL` para a arena. O Civil não tem fruta —
	# adiado como no `Main`, porque equipar mexe no modelo montado no `_ready`.
	jogador.call_deferred("equip_fruit", "")
	return jogador


## Pendura o combate direcional num jogador. PONTO ÚNICO de instalação (plano, D2):
## o jogo e o "Testar" do editor passam por `colocar_civil`, e é só daqui que ele
## nasce — nenhum `if modo_historia` espalhado pelo Player.
##
## Depois do `add_child` do corpo, de propósito: filho adicionado por último roda
## depois do Player no quadro, e o executor não precisa de nada do `_ready` dele.
## O CLIQUE DO MINECRAFT (V5): quebra/coloca blocos e bate com recarga no lugar do soco (`CliqueDeBlocos`, chave `SOCO_ANTIGO=1` volta ao soco).
## A progressão é achada pela árvore (o `ModoHistoria` a guarda; a instalação é estática como a do combate).
static func instalar_clique_de_blocos(jogador: Player, entrada: EntradaCorpoACorpo) -> void:
	if not CliqueDeBlocos.ligado:
		return
	var modo := jogador.get_tree().get_first_node_in_group("modo_historia") if jogador.is_inside_tree() else null
	var prog: ProgressaoDoPersonagem = modo.get("progressao") if modo != null else null
	if prog == null:
		return
	var clique := CliqueDeBlocos.new()
	clique.name = "CliqueDeBlocos"
	clique.montar(jogador, prog)
	jogador.add_child(clique)
	jogador.clique_de_blocos = clique
	var hud: Object = modo.get("_hud")
	if hud != null and hud.has_method("avisar"):
		clique.avisou.connect(hud.avisar)
	entrada.cedida = clique.assume_as_maos
	ItensEpicFight.limpar_concedidos(prog, frutas_de_teste())    # 18/11/2026: tira as lâminas e frutas que saves antigos receberam de graça (uma vez)


static func instalar_combate_direcional(jogador: Player) -> ExecutorCorpoACorpo:
	var executor := ExecutorCorpoACorpo.new()
	executor.name = "CombateDirecional"
	executor.montar(AtorJogador.new(jogador), load(ESTILO_CORPO_A_CORPO) as EstiloCorpoACorpo)
	# Soco do jogador −50 % (23/10/2026, `Balance.HISTORIA_SOCO`). O estilo é o mesmo dos
	# inimigos: a escala é do corpo, e só no estilo desarmado (espada/machado não).
	executor.multiplicador_desarmado = Balance.HISTORIA_SOCO
	jogador.add_child(executor)
	# Apanhar no estilo Minecraft (23/10/2026): empurrão fixo, pulinho e 0,5 s invulnerável.
	jogador.knockback_minecraft = KnockbackMinecraft.new()
	# Velocidade ao correr e Pulo ao agachar/no ar, como o `PlayerPhysicalAbilityProcedure` do mod (A6b).
	var vel_mp := VelocidadeMinePiece.new()
	vel_mp.name = "VelocidadeMinePiece"
	vel_mp.jogador = jogador
	jogador.add_child(vel_mp)
	# Vida zero = o coração para e o jogador joga o minigame para fazê-lo voltar (até 3 vezes em 30 min);
	# sem chance, nota baixa ou queda no vazio vale a morte de sempre (câmera lenta, texto, fade).
	jogador.ao_morrer = ReanimacaoDoCoracao.iniciar
	# Vida baixa desacelera o mundo ao redor (20 m) e, abaixo de 25 %, mostra as hitboxes dos disparos.
	var tempo_local := TempoLocalDaHistoria.new()
	tempo_local.name = "TempoLocalDaHistoria"
	tempo_local.jogador = jogador
	jogador.add_child(tempo_local)
	jogador.combate_direcional = executor
	executor.armadura_no_preparo = true      # a sequência de socos não é cortada por quem bate pelas costas (decisão do dono, 15/11/2026)
	# A entrada é do jogador; a IA chama o executor direto e não tem uma destas.
	var entrada := EntradaCorpoACorpo.new()
	entrada.name = "EntradaCorpoACorpo"
	entrada.montar(executor, Player.MOUSE_SENS)
	executor.add_child(entrada)
	jogador.entrada_combate_direcional = entrada
	jogador.zoom_por_teclas = true          # I/O aproximam e afastam a câmera; a roda é da hotbar
	instalar_clique_de_blocos(jogador, entrada)
	var arma := load("res://src/historia/equipamentos/espada_da_historia.gd").new() as Node
	arma.name = "EspadaDaHistoria"
	jogador.add_child(arma)
	var alimentacao := preload("res://src/historia/equipamentos/alimentacao_visual.gd").new()
	alimentacao.name = "AlimentacaoVisual"
	jogador.add_child(alimentacao)
	var bicicleta := preload("res://src/historia/equipamentos/bicicleta_de_gelo.gd").new()
	bicicleta.name = "BicicletaDeGelo"
	jogador.add_child(bicicleta)
	var apresentacao := ApresentacaoDeCombate.new()
	apresentacao.name = "ApresentacaoDeCombate"
	executor.add_child(apresentacao)
	apresentacao.montar(executor)
	if jogador.is_multiplayer_authority():
		var painel := DepuracaoDeCombate.new()
		painel.name = "DepuracaoDeCombate"
		painel.montar(executor)
		executor.add_child(painel)
	return executor
