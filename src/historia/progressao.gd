class_name ProgressaoDoPersonagem
extends RefCounted
# Validação/migração do save: serializacao_do_progresso.gd (18/10/2026).
# ============================================================================
#  PROGRESSÃO DO PERSONAGEM — o sistema de status do Modo História. Sem nó.
#
#  FONTE: docs/references/modo_historia/modohistoriaplanejamento.pdf. Os números
#  daqui são os do documento; a seção de cada um está no comentário. Quem mostra é
#  a `JanelaDeStatus`; quem aplica no corpo é o `ModoHistoria`.
#
#  COMO O XP É GUARDADO (§5): `xp` é o progresso DENTRO do nível atual. Ao subir,
#  o requisito é descontado e o que sobra continua. Várias subidas de uma vez são
#  possíveis se o XP cobrir.
#
#  (A barreira do 7 e as missões especiais do documento saíram em 26/10/2026, A3; os pontos de
#  atributo também, A6: Força, Resistência, Vida e Armadura vêm do nível, como no Mine Piece —
#  ver `atributos_mine_piece.gd`.)
#
#  INTERPRETAÇÕES DECLARADAS (o documento não fecha estes pontos):
#    • combate libera com Skill de Combate ≥ 1 (§27); dash e pulo duplo são
#      desbloqueios da história, guardados à parte (§23, §24);
#    • técnicas Z/X/C/V seguem travadas: o documento não diz o que as libera;
# ============================================================================

signal mudou
## Só os itens do Mine Piece mudaram (biscoito…). NÃO usa `mudou`: quem ouve `mudou` reaplica a progressão (reequipa a fruta) e grava o save,
## o que, no meio de uma técnica, cancelava os poderes e refazia o estado da fruta (os aliados invocados morriam). 10/11/2026.
signal itens_do_mod_mudaram
## Cada nível ganho, na ordem ({de, para}).
signal subiu_de_nivel(de: int, para: int)
const FORMATO := "skills-one-piece/progresso"
## v3 (04/11/2026): `reanimacoes` — quando o coração voltou a bater (as 3 chances em 30 min).
const VERSAO := 3

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
## XP por nível e por abate: os do Mine Piece (decisão do dono, 18/10/2026 — antes era a
## tabela do §4, 1.000 → 500.000 e +25 mil por nível). Ver `recompensa_mine_piece.gd`.
const RegrasDeRecompensa := preload("res://src/historia/recompensa_mine_piece.gd")
const RegrasDosAtributos := preload("res://src/historia/atributos_mine_piece.gd")
## SEM nível máximo, sem teto por ilha e sem missão especial (26/10/2026, decisão do dono:
## "o mod manda, sem ajuste" — `docs/AUDITORIA_FIDELIDADE_MINE_PIECE.md`, A3). No Mine Piece o
## nível é só a função da recompensa (`UpdateBountyProcedure`); quem limita são os atributos.
## Energia: a do mod, função do nível (`atributos_mine_piece.gd`, A9 de 27/10/2026). Antes era 100 × nível
## (pedido de 23/10) e, antes, 10 + 5 por ponto de Energia.
## Habilidades de movimento do Barba Negra (15/10/2026): 1000 moedas cada.
const PRECO_HABILIDADE := 1000
## Preço por habilidade (08/11/2026: o pulo no ar passa a custar 10 moedas; 20/11/2026: o dash também, pedido do dono); a que não está aqui vale `PRECO_HABILIDADE`.
const PRECOS_HABILIDADE := {"pulo_duplo": 10, "dash": 10}


static func preco_da_habilidade(chave: String) -> int:
	return int(PRECOS_HABILIDADE.get(chave, PRECO_HABILIDADE))
const CUSTO_PULO_NO_AR := 30.0
const CUSTO_DASH_NO_AR := 20.0
## 20/11/2026 (dono): "dash sem tempo de recarga — ao terminar um já pode usar o outro". Só o dash em curso (0,28 s) separa um do outro; o que limita é a energia.
const RECARGA_DASH_NO_AR := 0.0
## 20/11/2026 (dono): o "pulo duplo" comprado virou GEPPO — pula no ar enquanto houver energia (30 por pulo). Sem teto de pulos; só a energia limita.
const SALTOS_DO_GEPPO_COMPRADO := 9999
const HABILIDADES_A_VENDA: Array[String] = ["pulo_duplo", "dash"]
## TÉCNICA GEPPO (18/11/2026, pedido do dono): "movimentação aérea com dash aéreo sem recarga e jumps no ar". Ensinada pelo Mestre do Geppo na Ilha dos Macacos
## (`loja_do_mestre_geppo.gd`). Com ela: `SALTOS_DO_GEPPO` pulos no ar por voo (recarregam no chão), dash no ar sem recarga e sem energia, pulo sem energia.
## Decisões minhas (a confirmar): 5 pulos, preço 2000, sem custo de energia. Fica FORA de `HABILIDADES_A_VENDA` (essa lista é a do Barba Negra).
const SALTOS_DO_GEPPO := 5
const PRECO_DO_GEPPO := 2000
const SKILL_MAXIMO := 4                      # §20
const NOMES_SKILL := ["Não aprendida", "Básica", "Treinada", "Avançada", "Domínio"]   # §20
## §28/§29
const TITULOS := {1: "Civil", 2: "Aprendiz", 3: "Lutador", 4: "Combatente", 5: "Especialista",
	6: "Elite", 7: "Mestre", 8: "Super-Humano", 9: "Lendário", 10: "Ápice"}
## Atributos MOSTRADOS na janela (derivados do nível, sem pontos): ver `atributos_mine_piece.gd`.
const ATRIBUTOS: Array[String] = ["forca", "resistencia", "vida", "armadura"]
const SKILLS: Array[String] = ["combate", "espada", "fruta"]
## O piso de cada skill. Decisão do dono (30/09/2026): o personagem já nasce lutando —
## Combate começa em 1 (Básica, libera o clique) e não desce disso; save antigo com 0
## sobe para 1 ao carregar. Diverge do PDF (§21–27: Civil sem skills, combate
## destravado pela história).
const SKILL_MINIMA := {"combate": 1}
## §8 — faixas de referência para quem for dar XP (inimigos, missões).
const XP_REFERENCIA := {
	"inimigo_comum": [5, 20], "inimigo_forte": [25, 75], "mini_boss": [100, 300], "boss": [500, 2000],
	"missao_simples": [50, 200], "missao_importante": [300, 1000], "missao_principal": [1000, 5000],
}

var raca := "humano"                         # §1
const RACAS := ["humano", "sharkman"]
## Vazio em campanha nova ou save antigo: a entrada pede a escolha antes do spawn.
var corpo := ""
const CORPOS := ["masculino", "feminino"]
const TonsDePele := preload("res://src/player/tons_de_pele.gd")
var tom_de_pele := TonsDePele.PADRAO
const AparenciaHistoria := preload("res://src/player/aparencia_historia.gd")
var aparencia: Dictionary = AparenciaHistoria.normalizar({})

func definir_corpo(id: String) -> bool:
	if id not in CORPOS or id == corpo:
		return false
	corpo = id
	mudou.emit()
	return true

func definir_raca(id: String) -> bool:
	if id not in RACAS or id == raca:
		return false
	raca = id
	mudou.emit()
	return true

var nivel := 1
var xp := 0
## `PlayerBountyLimit` do mod: o teto de recompensa deste jogador (10.000 no início; sobe a cada abate).
var limite_de_recompensa := 10000.0
## Conquistas do Mine Piece (`McConquistas`): {id: [critérios feitos]}. Salvo junto; o `JogadorDoMod` usa a MESMA referência.
var conquistas_mod: Dictionary = {}
var ouro := 0                                # §13
var skills := {"combate": SKILL_MINIMA["combate"], "espada": 0, "fruta": 0}
var desbloqueios := {"dash": false, "pulo_duplo": false, "bussola": false, "geppo": false}
## Akuma no Mi comida (id da fruta) ou "". Uma por personagem: comer é definitivo no
## progresso salvo. Quem come ganha Fruta ≥ 1 (decisão do dono, 21/09/2026: "tudo na Fruta 1").
var fruta := ""
## Interruptor da fruta na janela M (01/10/2026, decisão do dono): desligada, o personagem
## fica como quem nunca comeu — sem técnicas nem voo E nadando normalmente. A fruta
## continua comida (ligar de novo devolve tudo). Comer uma fruta nova liga.
var fruta_ativa := true
## Item que a fruta pôs no lugar dela (Ama no Murakumo da Pika Mine Piece, 21/10/2026): o
## ícone da barra vira o do item e, com a fruta equipada, ele vai para a mão. Comer outra
## fruta o larga. "" = nenhum.
var espada_da_fruta := ""
## Pets do jogador: id DO PET → {"especie", "nome", "modo"}. Decisão do dono (30/09/2026):
## já começa com a gaivota e o caranguejo no inventário (tecla N). 01/10/2026: herbívoros
## domados com fruta viram pets — quantos quiser (vários da mesma espécie), no máximo 6
## fora; pet que MORRE sai daqui de vez. Os dois iniciais têm id = espécie ("gaivota",
## "caranguejo"), o que mantém os saves de antes válidos. Espécie = `CatalogoDePets`
## (corpo próprio) ou um animal da loja (`PetDomado`). Ao abrir o jogo começam GUARDADOS.
## 18/10/2026 (pedido do dono: "o jogador começar sem nenhum pet"): jogo novo começa VAZIO;
## quem já tem save continua com os pets dele.
var pets := {}
## Concessões únicas do mapa, independentes dos pets vivos. A marca permanece
## quando o pet morre para impedir que recarregar a vila o ressuscite.
var pets_do_mapa_recebidos := {}
## Aba PESCA do inventário: id do item → quantidade. Vazia até a pesca existir.
var pesca := {}
## Aba FRUTAS do inventário (01/10/2026): frutas do POMAR coletadas do chão — id do
## modelo da loja (categoria "frutas", ex.: "fruta_maca") → quantidade. Não confundir
## com `fruta`, que é a Akuma no Mi comida.
var frutas_do_pomar := {}
## BARRA DE ITENS 1–6 (03/10/2026, pedido do dono): UM item ativo por vez entre os
## que o personagem tem — "luta" (estilo de luta), "fruta" (Akuma no Mi comida),
## "espada" e "vara" (equipadas no N). Pistola ainda reservada.
## É o ativo que libera o uso (ver `capacidades`).
const ITENS_DA_BARRA: Array[String] = ["luta", "fruta", "espada", "pistola", "vara", "agua", "comida", "pokebola", "bandeira"]
const MAX_ITENS_DA_BARRA := 9
## Nada selecionado na barra (mãos livres). Não é um item: nenhum quadrado fica aceso.
const NENHUM_ITEM := "nenhum"
var item_ativo := "luta"
## Equipamentos que o personagem POSSUI (id → true). "vara_de_pesca" vem de graça
## com o pescador (NPC). Desde 10/11/2026 o jogador NÃO começa com a espada antiga (nem tem o machado).
var equipamentos: Dictionary = _equipamentos_iniciais()
var machado_equipado := false
var madeira := 0
## Itens do Mine Piece que o jogador tem (`minepiece:biscuit` → quantidade). Entram por `ItemHandlerHelper.giveItemToPlayer` do mod
## (ex.: a técnica Biscuit do Bisu Bisu) e saem quando uma técnica os gasta (cada aliado de biscoito custa 1). Mochila fiel ao Minecraft: pendente.
var itens_do_mod: Dictionary = {}                 # LEGADO: só lido de saves antigos (migra para o `inventario`)
## O inventário estilo Minecraft (hotbar, mochila, armadura, mão secundária, grade 2×2): `docs/INVENTARIO_MINECRAFT.md`.
var inventario: InventarioMinecraft = _novo_inventario()


## Esvazia o inventário (testes / personagem novo).
func zerar_inventario() -> void:
	inventario = _novo_inventario()
	_itens_sujos = true
	itens_do_mod_mudaram.emit()


func _novo_inventario() -> InventarioMinecraft:
	var inv := InventarioMinecraft.new()
	inv.mudou.connect(func(): itens_do_mod_mudaram.emit())
	return inv
var espada_equipada := false
## Lâmina do Epic Fight em uso no lugar da espada (10/11/2026; "" = a espada comum). Ver `LaminasEpicFight`.
var lamina_ef := ""
## Durabilidade restante de cada arma do Epic Fight (`id → usos`; ausente = cheia) e as que já quebraram (o mod: `hurtAndBreak(1)` por golpe que acerta).
## Segunda arma do Epic Fight, na MÃO ESQUERDA ("" = nenhuma). Duas adagas (ou duas espadas) = estilo dual do mod (`dagger_dual_*`).
var lamina_ef_sec := ""
var durabilidade_ef := {}
var ef_quebradas := {}
var vara_equipada := false
## O kit de construção (blocos de todas as formas) já foi entregue? Uma vez por personagem (V5: sem isto o jogador não teria o que colocar antes de quebrar).
var kit_de_blocos_entregue := false
var inventario_ef_entregue := false      # armas do Epic Fight postas na mochila (e kit de blocos de teste retirado) — uma vez
## Akuma no Mi COMPRADAS no vendedor de frutas e ainda não comidas: id → quantidade
## (03/10/2026). Decisão do dono: a compra vai para o inventário (N › FRUTAS) e se come
## quando quiser, trocando a atual. Só frutas da arena (`PerfilDeFrutas.frutas_da_arena`).
var frutas_compradas := {}
## Missões dos NPCs (08/10/2026): id → {"estado": "aceita"|"entregue", "abates": n}.
## Sem entrada = ainda disponível. A tabela (meta, recompensa) é `Missoes.TABELA`.
var missoes := {}
## Barcos comprados no vendedor do porto (10/10/2026): id do modelo da loja → true. Um de
## cada tipo; ao abrir o jogo cada um volta atracado ao cais do vendedor.
var barcos := {}
## Tripulantes humanos ganhos na roleta do Barba Negra (15/10/2026): id do
## `CatalogoDeTripulantes` → true. Sem repetição.
var recrutados := {}
## Estado de SISTEMAS que guardam o próprio formato (14/10/2026: o mar — baús de naufrágio
## já abertos). Aqui só se confere que é um dicionário por nome; o dono do sistema valida
## o conteúdo ao ler (`dados_de`). Sistema novo não precisa de campo novo neste arquivo.
var sistemas := {}

## Ilhas onde o personagem já pisou (vai para o save): aviso de chegada, bússola.
var ilhas_visitadas: Array[String] = [Ilhas.INICIAL]
## Instantes (ms de relógio real, época Unix) em que o jogador usou o minigame do coração: a
## janela de 3 chances em 30 minutos (`ReanimacaoDoCoracao`) sobrevive a fechar o jogo. Guarda só
## as últimas `MAX_REANIMACOES_GUARDADAS`; reiniciar a campanha zera junto com o resto.
const MAX_REANIMACOES_GUARDADAS := 8
var reanimacoes_ms: Array[int] = []

func registrar_reanimacao(agora_ms: int) -> void:
	reanimacoes_ms.append(agora_ms)
	if reanimacoes_ms.size() > MAX_REANIMACOES_GUARDADAS:
		reanimacoes_ms = reanimacoes_ms.slice(reanimacoes_ms.size() - MAX_REANIMACOES_GUARDADAS)
	mudou.emit()      # grava no disco (o Modo História salva a cada mudança)

func reanimacoes_na_janela(agora_ms: int, janela_ms: int) -> int:
	var limite := agora_ms - janela_ms
	var n := 0
	for t in reanimacoes_ms:
		if t > limite:
			n += 1
	return n

## Ilha onde o personagem está agora ("" = no mar). Não vai para o save: quem marca é o
## `DetectorDeIlha` do Modo História, pela posição.
var ilha := Ilhas.INICIAL

## Último chão pisado numa ilha: {"ilha": id, "x": , "y": , "z": }. Vai para o save (19/11/2026: sair na Ilha dos
## Macacos fazia o jogo reabrir na ilha inicial). Vazio = nunca gravado → nasce no spawn do mapa.
var local_salvo: Dictionary = {}


# ------------------------------------------------------------------ leitura
func xp_necessario() -> int:
	return xp_para(nivel)


## XP para ir do nível `n` ao seguinte (limiares do `UpdateBountyProcedure`).
static func xp_para(n: int) -> int:
	return RegrasDeRecompensa.xp_para(n)


## Primeira chegada a uma ilha: entra na lista. Devolve true só na primeira vez.
func visitar(id: String) -> bool:
	if not Ilhas.existe(id) or id in ilhas_visitadas:
		return false
	ilhas_visitadas.append(id)
	mudou.emit()
	return true


func xp_restante() -> int:
	return maxi(xp_necessario() - xp, 0)


func titulo(n: int = -1) -> String:
	var qual := nivel if n < 0 else n
	# Do 11 em diante: "Ápice" até haver títulos por ilha (gatilho: a 2ª ilha).
	return TITULOS.get(qual, "Ápice" if qual > 10 else "?")


func hp_maximo() -> int:
	return RegrasDosAtributos.hp_maximo(nivel)


## O valor de um atributo mostrado, derivado do nível (A6).
func valor_do_atributo(atributo: String) -> int:
	match atributo:
		"forca": return RegrasDosAtributos.niveis_forca(nivel)
		"resistencia": return RegrasDosAtributos.niveis_resistencia(nivel)
		"vida": return hp_maximo()
		"armadura": return RegrasDosAtributos.armadura(nivel)
	return 0


func energia_maxima() -> int:
	return RegrasDosAtributos.energia_maxima(nivel)


## §27 + desbloqueios da história. Técnicas continuam travadas (ver cabeçalho).
func capacidades() -> CapacidadesDoJogador:
	var c := CapacidadesDoJogador.civil()
	# Barra de itens (03/10/2026): só o item ATIVO libera o uso. Luta = socos;
	# fruta = técnicas e voo (e socos); vara = pescar.
	var ativo := item_em_uso()
	c.can_attack = (int(skills["combate"]) >= 1 and ativo in ["", "luta", "fruta"]) \
		or (int(skills["espada"]) >= 1 and ativo == "espada") or ativo == "machado"
	c.can_dash = bool(desbloqueios["dash"])
	c.can_double_jump = bool(desbloqueios["pulo_duplo"])
	var proporcao := RegrasDosAtributos.fator_de_custo_fora_do_mod(nivel)      # pulo e dash são do jogo, não do mod
	c.custo_pulo_no_ar = CUSTO_PULO_NO_AR * proporcao
	c.custo_dash_no_ar = CUSTO_DASH_NO_AR * proporcao
	c.recarga_dash_no_ar = RECARGA_DASH_NO_AR
	if c.can_double_jump:
		c.saltos_no_ar = SALTOS_DO_GEPPO_COMPRADO
	if bool(desbloqueios["geppo"]):
		# Técnica Geppo: tudo no ar liberado, de graça e sem esperar.
		c.geppo = true
		c.can_dash = true
		c.can_double_jump = true
		c.saltos_no_ar = SALTOS_DO_GEPPO
		c.custo_pulo_no_ar = 0.0
		c.custo_dash_no_ar = 0.0
		c.recarga_dash_no_ar = 0.0
	# `can_use_skills` CONTINUA falso: ele abriria os modos 1/2/3, o T, o E e o Corpo de
	# Ferro da arena. A fruta libera só as técnicas dela e o voo.
	c.can_use_fruit = (fruta_em_uso() and ativo == "fruta") or (ativo == "luta" and tem_estilo_base())
	c.can_fly = fruta_em_uso() and ativo == "fruta"
	c.can_fish = ativo == "vara"
	return c


## ------------------------------------------------------------- inventário
func tem_pet(id: String) -> bool:
	return pets.has(id)


func especie_do_pet(id: String) -> String:
	return str(pets[id].get("especie", id)) if tem_pet(id) else id


func nome_do_pet(id: String) -> String:
	if not tem_pet(id):
		return CatalogoDePets.nome(id)
	var n := str(pets[id].get("nome", ""))
	return n if not n.is_empty() else CatalogoDePets.nome(especie_do_pet(id))


func modo_do_pet(id: String) -> StringName:
	return StringName(str(pets[id]["modo"])) if tem_pet(id) else CatalogoDePets.modo_inicial(id)


## Pet novo (domado). Id único "<espécie>_<n>"; nome com número se já houver um igual.
func adicionar_pet(especie: String, nome: String, modo: StringName = ModoDoPet.SEGUIR) -> String:
	var n := 1
	while pets.has("%s_%d" % [especie, n]):
		n += 1
	var id := "%s_%d" % [especie, n]
	var mesmos := 0
	for outro in pets:
		if especie_do_pet(outro) == especie:
			mesmos += 1
	pets[id] = {"especie": especie, "nome": nome if mesmos == 0 else "%s %d" % [nome, mesmos + 1],
		"modo": modo if ModoDoPet.valido(modo) else ModoDoPet.SEGUIR}
	_contar("pet")
	mudou.emit()
	return id


## Registra antes do sinal de adicionar_pet: o autosave recebe pet e concessão
## na mesma gravação. Abrir novamente o mapa não cria outra cópia.
func receber_pet_do_mapa(origem: String, especie: String, nome: String) -> String:
	if pets_do_mapa_recebidos.has(origem):
		return ""
	pets_do_mapa_recebidos[origem] = true
	return adicionar_pet(especie, nome)


## Pet morto: some do inventário DE VEZ (decisão do dono, 01/10/2026).
func remover_pet(id: String) -> void:
	if pets.erase(id):
		mudou.emit()


func definir_modo_do_pet(id: String, modo: StringName) -> void:
	if tem_pet(id) and ModoDoPet.valido(modo) and modo_do_pet(id) != modo:
		pets[id]["modo"] = modo
		mudou.emit()


## Fruta do pomar: vai para o INVENTÁRIO (pilha `pomar:<id>`, hotbar primeiro). O que não couber fica em `frutas_do_pomar` (excedente) até haver vaga.
func ganhar_fruta_do_pomar(id: String, quantidade := 1) -> void:
	if quantidade > 0 and not id.is_empty():
		_guardar_fruta(ItensDeFruta.tag_pomar(id), quantidade, frutas_do_pomar, id)
		mudou.emit()


## Gasta uma (a doma). `false` se não tinha.
func gastar_fruta_do_pomar(id: String) -> bool:
	if not _tirar_fruta(ItensDeFruta.tag_pomar(id), 1, frutas_do_pomar, id):
		return false
	mudou.emit()
	return true


func quantas_frutas_do_pomar(id: String) -> int:
	return inventario.contar(ItensDeFruta.tag_pomar(id)) + int(frutas_do_pomar.get(id, 0))


## Frutas do pomar que o personagem tem (inventário + excedente): id → quantidade.
func frutas_do_pomar_guardadas() -> Dictionary:
	return _contar_frutas(ItensDeFruta.POMAR, frutas_do_pomar)


# ---- frutas como itens do inventário (25/11/2026): Akuma `akuma:<id>`, pomar `pomar:<id>`. O dicionário correspondente guarda só o EXCEDENTE.
## Guarda `qtd` do item no inventário; o que não couber vai para `excedente[chave]`. Devolve quantas entraram no inventário.
func _guardar_fruta(tag: String, qtd: int, excedente: Dictionary, chave: String) -> int:
	var resto := inventario.inserir(InventarioMinecraft.nova(tag, qtd))
	var sobrou: int = 0 if resto == null or resto.isEmpty() else int(resto.quantidade)
	if sobrou > 0:
		excedente[chave] = int(excedente.get(chave, 0)) + sobrou
	return qtd - sobrou


func _tirar_fruta(tag: String, qtd: int, excedente: Dictionary, chave: String) -> bool:
	var total := inventario.contar(tag) + int(excedente.get(chave, 0))
	if qtd <= 0 or total < qtd:
		return false
	var do_excedente := mini(int(excedente.get(chave, 0)), qtd)
	if do_excedente > 0:
		if int(excedente[chave]) - do_excedente <= 0:
			excedente.erase(chave)
		else:
			excedente[chave] = int(excedente[chave]) - do_excedente
	if qtd - do_excedente > 0:
		inventario.remover(tag, qtd - do_excedente)
	return true


func _contar_frutas(prefixo: String, excedente: Dictionary) -> Dictionary:
	var saida := {}
	for i in range(InventarioMinecraft.MOCHILA_INI, InventarioMinecraft.TOTAL):
		var id := InventarioMinecraft.id_de(inventario.pilha(i))
		if id.begins_with(prefixo):
			var chave := id.trim_prefix(prefixo)
			saida[chave] = int(saida.get(chave, 0)) + int(inventario.pilha(i).quantidade)
	for k in excedente:
		saida[k] = int(saida.get(k, 0)) + int(excedente[k])
	return saida


## Passa para o inventário o excedente (e o que saves antigos ainda guardam nos dicionários) e põe o Kit do Builder, se houver. Chamar ao carregar e ao abrir
## a mochila; GATILHO: se o excedente virar rotina, avisar o jogador ("mochila cheia") em vez de guardar calado.
func recolher_frutas_para_o_inventario() -> void:
	var mudou_algo := false
	for par in [[ItensDeFruta.AKUMA, frutas_compradas], [ItensDeFruta.POMAR, frutas_do_pomar]]:
		var dic: Dictionary = par[1]
		for id in dic.keys():
			var q := int(dic[id])
			dic.erase(id)
			if q > 0:
				_guardar_fruta(str(par[0]) + str(id), q, dic, str(id))
				mudou_algo = true
	if KitDoBuilder.disponivel() and inventario.contar(ItensDeFruta.tag_akuma(KitDoBuilder.ID)) == 0:
		inventario.inserir(InventarioMinecraft.nova(ItensDeFruta.tag_akuma(KitDoBuilder.ID), 1))
		mudou_algo = true
	if mudou_algo:
		mudou.emit()


func guardar_item_de_pesca(id: String, quantidade := 1) -> void:
	if quantidade > 0 and not id.is_empty():
		pesca[id] = int(pesca.get(id, 0)) + quantidade
		if TabelaDePeixes.eh_peixe(id):
			_contar("peixe", quantidade)
			if TabelaDePeixes.raridade(id) == "raro": _contar("peixe_raro", quantidade)
		mudou.emit()


## Os itens da barra, na ordem dos quadrados (tecla 1 = primeiro).
## Os itens numerados que o personagem POSSUI (ordem padrão). A barra mostra os que estão na HOTBAR do inventário, na ordem dos slots.
func itens_possuidos() -> Array[String]:
	var lista: Array[String] = []
	if int(skills["combate"]) >= 1:
		lista.append("luta")
	if tem_fruta():
		lista.append("fruta")
	if espada_equipada and (equipamentos.has("espada") or lamina_ef != ""):
		lista.append("espada")
	if vara_equipada and equipamentos.has("vara_de_pesca"):
		lista.append("vara")
	if machado_equipado and equipamentos.has("machado"):
		lista.append("machado")
	# As utilidades existem mesmo com estoque vazio e acompanham os itens equipados.
	# Água SEMPRE logo antes da comida (pedido do dono, 18/10/2026); pokébola logo antes da bandeira.
	lista.append("agua")
	lista.append("comida")
	lista.append("pokebola")
	lista.append("bandeira")
	return lista


var _itens_sujos := true


func _init() -> void:
	mudou.connect(func(): _itens_sujos = true)         # a posse pode ter mudado: o próximo `itens_da_barra` sincroniza o inventário


## Põe no inventário (hotbar primeiro, depois mochila) cada item do jogo que o personagem possui e ainda não está lá, e tira os que perdeu.
## Quem arrastar um deles pela janela muda o número da tecla: a posição manda (`itens_da_barra`).
func sincronizar_itens_do_jogo() -> void:
	_itens_sujos = false
	var possuidos := itens_possuidos()
	for id in ItensDoJogo.IDS:
		var t := ItensDoJogo.tag(id)
		var tem := inventario.contar(t) > 0 or InventarioMinecraft.id_de(inventario.cursor) == t
		for i in range(InventarioMinecraft.GRADE_INI, InventarioMinecraft.GRADE_FIM):
			tem = tem or InventarioMinecraft.id_de(inventario.pilha(i)) == t
		if id == "espada" and _arma_ef_na_mao_no_inventario():
			# a arma `ef:<lamina>` já É o item da espada: não cria (nem mantém) um `jogo:espada` a mais ao empunhá-la
			if inventario.contar(t) > 0:
				inventario.remover(t, inventario.contar(t))
			continue
		if possuidos.has(id) and not tem:
			var padrao := InventarioMinecraft.HOTBAR_INI + ItensDoJogo.IDS.find(id)        # slot padrão fixo (luta 1, fruta 2, …, bandeira 9)
			if inventario.pilha(padrao).isEmpty():
				inventario.slots[padrao] = InventarioMinecraft.nova(t, 1)
				inventario.mudou.emit()
			else:
				inventario.inserir(InventarioMinecraft.nova(t, 1))
		elif not possuidos.has(id) and tem:
			inventario.remover(t, inventario.contar(t))


## A arma do Epic Fight empunhada existe como item `ef:<lamina>` no inventário (mochila, hotbar ou cursor)?
func _arma_ef_na_mao_no_inventario() -> bool:
	if lamina_ef == "":
		return false
	var t := ItensEpicFight.id_do_item(lamina_ef)
	return inventario.contar(t) > 0 or InventarioMinecraft.id_de(inventario.cursor) == t


## A barra: os itens do jogo que estão na HOTBAR, na ordem dos slots (a tecla é o slot; pode haver buracos que a HUD mostra vazios).
func itens_da_barra() -> Array[String]:
	if _itens_sujos:
		sincronizar_itens_do_jogo()
	var lista: Array[String] = []
	var possuidos := itens_possuidos()
	for i in range(InventarioMinecraft.HOTBAR_INI, InventarioMinecraft.HOTBAR_FIM):
		var t := InventarioMinecraft.id_de(inventario.pilha(i))
		if ItensDoJogo.e_do_jogo(t) and possuidos.has(ItensDoJogo.id_de(t)):
			lista.append(ItensDoJogo.id_de(t))
		elif lamina_ef != "" and t == ItensEpicFight.id_do_item(lamina_ef) and possuidos.has("espada"):
			lista.append("espada")             # a arma `ef:` empunhada faz o papel do item "espada"
	if not lista.has("espada") and possuidos.has("espada") and _arma_ef_na_mao_no_inventario():
		lista.append("espada")                 # a arma `ef:` está na mochila (equipada pela aba ARMAS): na mão sem slot de hotbar e SEM `jogo:espada` extra
	return lista


## O slot da hotbar (0–8) onde está o item do jogo `id`, ou −1.
func slot_da_barra(id: String) -> int:
	if _itens_sujos:
		sincronizar_itens_do_jogo()
	for i in range(InventarioMinecraft.HOTBAR_INI, InventarioMinecraft.HOTBAR_FIM):
		var t := InventarioMinecraft.id_de(inventario.pilha(i))
		if t == ItensDoJogo.tag(id) or (id == "espada" and lamina_ef != "" and t == ItensEpicFight.id_do_item(lamina_ef)):
			return i - InventarioMinecraft.HOTBAR_INI
	return -1


## O ativo de verdade: o escolhido, se ainda existe; senão o primeiro da barra.
## Devolve "" quando o jogador soltou o item (nada selecionado).
func item_em_uso() -> String:
	if item_ativo == NENHUM_ITEM:
		return ""
	var lista := itens_da_barra()
	if lista.has(item_ativo):
		return item_ativo
	return lista[0] if not lista.is_empty() else ""


## O machado saiu da mão (arremesso do Z, 17/10/2026): o item ativo vira o combate corpo a
## corpo, ou "mãos livres" se ele ainda não existe. O machado segue na barra.
func largar_machado() -> void:
	if item_em_uso() != "machado":
		return
	item_ativo = "luta" if itens_da_barra().has("luta") else NENHUM_ITEM
	mudou.emit()


## Ativa um item da barra. Escolher de novo o ativo SOLTA: fica sem nada selecionado
## ("mãos livres", 15/10/2026 — antes caía no quadrado 1). Devolve false se o item
## não está na barra.
## `alternar`: apertar o item que já está ativo o DESATIVA (botões da janela). A tecla numérica da barra NÃO alterna (19/11/2026, pedido do dono): `1` de novo mantém o
## estilo de luta ativo; só trocar de slot muda o item.
func ativar_item(id: String, alternar := true) -> bool:
	if not itens_da_barra().has(id):
		return false
	item_ativo = NENHUM_ITEM if (alternar and item_em_uso() == id) else id
	mudou.emit()
	return true


func ganhar_equipamento(id: String) -> bool:
	if id.is_empty() or equipamentos.has(id):
		return false
	equipamentos[id] = true
	if id == "vara_de_pesca":
		vara_equipada = true               # a vara vai para a HOTBAR, não fica só na aba PESCA (sem tomar a mão: `item_ativo` não muda)
	mudou.emit()
	return true


## Equipa/desequipa a vara (inventário N). Equipar já a deixa ATIVA na barra.
func equipar_vara(sim: bool) -> bool:
	if sim and not equipamentos.has("vara_de_pesca"):
		return false
	vara_equipada = sim
	if sim:
		item_ativo = "vara"
	mudou.emit()
	return true


## Inventário inicial: VAZIO. Desde 18/11/2026 ninguém recebe as lâminas do Epic Fight de graça (`ItensEpicFight.limpar_concedidos` tira as dos saves antigos).
static func _equipamentos_iniciais() -> Dictionary:
	return {}


## Usos que restam da arma do Epic Fight (a durabilidade do item no mod: madeira 59 … netherite 2031; uchigatana 1625).
func durabilidade_de(id: String) -> int:
	id = LaminasEpicFight.resolver(id)
	return int(durabilidade_ef.get(id, LaminasEpicFight.durabilidade_maxima(id)))


## Gasta usos (1 por golpe que acerta, como `WeaponItem.postHurtEnemy`). Quebrou (zerou)? A arma some do inventário, é guardada e não volta (`ef_quebradas`). Devolve true se quebrou.
func gastar_durabilidade(id: String, n := 1) -> bool:
	id = LaminasEpicFight.resolver(id)
	if not equipamentos.has(id):
		return false
	var resta := durabilidade_de(id) - n
	if resta > 0:
		durabilidade_ef[id] = resta
		return false
	durabilidade_ef.erase(id)
	ef_quebradas[id] = true
	equipamentos.erase(id)
	if lamina_ef == id:
		equipar_lamina(id, false)
	else:
		if lamina_ef_sec == id:
			lamina_ef_sec = ""
		mudou.emit()
	return true


## Segunda arma na mão esquerda. Só vale com a principal empunhada, do mesmo tipo dual do mod (adaga+adaga, espada+espada) e outro item.
func equipar_lamina_secundaria(id: String, sim: bool) -> bool:
	id = LaminasEpicFight.resolver(id)
	if not sim:
		lamina_ef_sec = ""
		mudou.emit()
		return true
	if not (equipamentos.has(id) and espada_equipada and LaminasEpicFight.pode_dual(lamina_ef, id)):
		return false
	lamina_ef_sec = id
	mudou.emit()
	return true


## Equipa (ou guarda) uma lâmina do Epic Fight. Usa o mesmo item "espada" da barra.
func equipar_lamina(id: String, sim: bool) -> bool:
	id = LaminasEpicFight.resolver(id)          # ids antigos (ef_adaga…) viram os itens do mod
	if sim and not (LaminasEpicFight.existe(id) and equipamentos.has(id)):
		return false
	espada_equipada = sim
	lamina_ef = id if sim else ""
	if not sim or not LaminasEpicFight.pode_dual(lamina_ef, lamina_ef_sec):
		lamina_ef_sec = ""                     # sem a principal (ou de outro tipo) não há segunda arma
	if sim:
		skills["espada"] = maxi(int(skills["espada"]), 1)
		item_ativo = "espada"
	elif item_ativo == "espada":
		item_ativo = "luta"
	mudou.emit()
	return true


## Item inicial (06/10/2026): equipar ensina Espada 1, como comer libera Fruta 1.
func equipar_espada(sim: bool) -> bool:
	if sim and not equipamentos.has("espada"):
		return false
	lamina_ef = ""
	espada_equipada = sim
	if sim:
		skills["espada"] = maxi(int(skills["espada"]), 1)
		item_ativo = "espada"
	elif item_ativo == "espada":
		item_ativo = "luta"
	mudou.emit()
	return true


func equipar_machado(sim: bool) -> bool:
	if sim and not equipamentos.has("machado"):
		return false
	machado_equipado = sim
	if sim:
		item_ativo = "machado"
	elif item_ativo == "machado":
		item_ativo = "luta"
	mudou.emit()
	return true


func ganhar_madeira(quantidade: int) -> void:
	if quantidade <= 0:
		return
	madeira += quantidade
	_contar("madeira", quantidade)
	mudou.emit()


func tem_fruta() -> bool:
	return not fruta.is_empty() and int(skills["fruta"]) >= 1


## O Estilo de Combate Base (item "Luta") existe? Sempre: é nativo (A11, 30/10/2026), não depende mais do Skills Builder.
func tem_estilo_base() -> bool:
	return CatalogoFrutasMinePiece.contem(CatalogoFrutasMinePiece.LUTA)


## O que o corpo carrega agora: o estilo base com o item "Luta" na mão; senão a Akuma no Mi.
func fruta_a_equipar() -> String:
	if item_em_uso() == "luta" and tem_estilo_base():
		return CatalogoFrutasMinePiece.LUTA
	return fruta if fruta_em_uso() else ""


## Tem a fruta E ela está ligada: é o que decide técnicas, voo, aparência e afundar.
func fruta_em_uso() -> bool:
	return tem_fruta() and fruta_ativa


func definir_fruta_ativa(ativa: bool) -> void:
	if fruta_ativa != ativa:
		fruta_ativa = ativa
		mudou.emit()


## Comer uma Akuma no Mi: guarda a fruta e garante Fruta 1 (o que libera as técnicas).
## Devolve `false` se já era esta fruta — quem chama decide se avisa.
func comer_fruta(id: String) -> bool:
	if id.is_empty() or fruta == id:
		return false
	fruta = id
	fruta_ativa = true
	espada_da_fruta = ""
	if int(skills["fruta"]) < 1:
		skills["fruta"] = 1
	item_ativo = "fruta"          # a fruta recém-comida já vem ativa na barra
	_contar("fruta")
	mudou.emit()
	return true


## Tirar a fruta (hoje só pela seção TESTE). A skill Fruta CONTINUA onde estava: o que se
## perde é a fruta, não o domínio aprendido.
func tirar_fruta() -> void:
	if fruta.is_empty():
		return
	fruta = ""
	mudou.emit()


# ------------------------------------------------------------------ mudanças
## A recompensa (bounty) acumulada: o nível `n` começa em `recompensa_do_nivel(n)` e `xp` é o que já passou dele.
func recompensa_total() -> int:
	return RegrasDeRecompensa.recompensa_do_nivel(nivel) + xp


## ANTI-FARM e TETO do mod (`WhenEntityDieProcedure`, 27/10/2026; B2 da auditoria). Quem mata ganha a `fama` da vítima,
## mas a recompensa não passa do LIMITE DO JOGADOR (começa em 10.000 e sobe, a cada abate, para 3 × uma faixa da fama da
## vítima: <15 mil → mín(fama+3 mil, 15 mil) × 3; <150 mil → mín(fama+30 mil, 150 mil) × 3; <1,5 mi → mín(fama+300 mil,
## 1 mi) × 3; senão fama × 3) nem do teto da regra de jogo (`minepiecePlayerBountyLimit` 50 × 100.000 = 5 mi = nível 30).
## Devolve o XP que ENTRARIA, sem alterar nada (o aviso do "+N XP" usa isto).
func previa_do_abate(fama: int) -> int:
	if fama <= 0:
		return 0
	var limite := maxf(limite_de_recompensa, RegrasDeRecompensa.limite_por_vitima(fama))
	var total := float(recompensa_total())
	var novo := maxf(minf(minf(total + fama, limite), float(RegrasDeRecompensa.RECOMPENSA_MAXIMA)), total)
	return int(novo - total)


func ganhar_xp_de_abate(fama: int) -> int:
	if fama <= 0:
		return 0
	limite_de_recompensa = maxf(limite_de_recompensa, RegrasDeRecompensa.limite_por_vitima(fama))
	return ganhar_xp(previa_do_abate(fama))


## Soma XP e sobe o que der. Devolve os níveis ganhos nesta chamada.
func ganhar_xp(quantidade: int) -> int:
	if quantidade <= 0:
		return 0
	xp += quantidade
	var ganhos := _subir_o_que_der()
	mudou.emit()
	return ganhos


# ------------------------------------------------- missões dos NPCs (08/10/2026)
const Missoes := preload("res://src/historia/missoes/missoes.gd")


## "disponivel", "aceita", "pronta" (abates na meta, falta entregar) ou "entregue".
## Missões cujo alvo é uma luta (o `alvo` do evento que conta). Hoje só a dos bandidos; é a lista a crescer quando houver mais.
const ALVOS_DE_COMBATE: Array[String] = ["bandido"]


## Há uma missão de COMBATE aceita e ainda não cumprida? Os chefes não largam o jogador enquanto ela vale (`CerebroMinePiece`).
func tem_missao_de_combate() -> bool:
	for id in missoes:
		if ALVOS_DE_COMBATE.has(str(Missoes.dados(id).get("alvo", ""))) and estado_da_missao(id) == Missoes.ACEITA:
			return true
	return false


func estado_da_missao(id: String) -> String:
	var m: Dictionary = missoes.get(id, {})
	if m.is_empty():
		return Missoes.DISPONIVEL
	if m.get("estado") == Missoes.ENTREGUE:
		return Missoes.ENTREGUE
	if m.get("estado") == Missoes.FALHOU:
		return Missoes.FALHOU
	return Missoes.PRONTA if int(m.get("abates", 0)) >= int(Missoes.dados(id).get("meta", 1)) else Missoes.ACEITA


func abates_da_missao(id: String) -> int:
	return int((missoes.get(id, {}) as Dictionary).get("abates", 0))


func aceitar_missao(id: String) -> bool:
	if not Missoes.existe(id) or estado_da_missao(id) != Missoes.DISPONIVEL:
		return false
	var antes := str(Missoes.dados(id).get("depois_de", ""))
	if not antes.is_empty() and estado_da_missao(antes) != Missoes.ENTREGUE:
		return false                          # cadeia: uma por vez, na ordem
	if nivel < int(Missoes.dados(id).get("nivel_minimo", 0)):
		return false                          # missão com nível mínimo (a luta do Buggy, 21/11/2026)
	missoes[id] = {"estado": Missoes.ACEITA, "abates": 0}
	if bool(Missoes.dados(id).get("entrega_vara", false)):
		equipamentos["vara_de_pesca"] = true
		vara_equipada = true              # quem aceita a pesca já tem a vara na hotbar
	mudou.emit()
	return true


## Aconteceu o evento `alvo` (um "bandido" abatido, "pet" novo, "fruta" conseguida,
## "corrida" vencida, "peixe" pescado): soma nas missões ACEITAS que pedem esse alvo (até
## a meta). Devolve as missões que andaram. Missão com `itens` (18/10/2026, provisões)
## conta só a `parte` que ela pede, cada uma até a sua meta; `abates` = a soma.
func contar_abate(alvo: String, quantos := 1, parte := "") -> Array[String]:
	var andaram := _contar(alvo, quantos, parte)
	if not andaram.is_empty():
		mudou.emit()
	return andaram


## O mesmo sem emitir `mudou`: para quem já emite logo depois (um save só).
func _contar(alvo: String, quantos := 1, parte := "") -> Array[String]:
	var andaram: Array[String] = []
	for id in missoes:
		var d := Missoes.dados(id)
		if d.get("alvo") != alvo or estado_da_missao(id) != Missoes.ACEITA:
			continue
		if d.has("itens"):
			var pede := int((d.itens as Dictionary).get(parte, 0))
			if pede <= 0:
				continue
			var feitos: Dictionary = missoes[id].get_or_add("itens", {})
			feitos[parte] = mini(int(feitos.get(parte, 0)) + quantos, pede)
			var soma := 0
			for item in feitos:
				soma += int(feitos[item])
			missoes[id]["abates"] = mini(soma, int(d["meta"]))
		else:
			missoes[id]["abates"] = mini(abates_da_missao(id) + quantos, int(d["meta"]))
		andaram.append(id)
	return andaram


## Entrega a missão pronta: XP e ouro da tabela, uma vez. Tudo ou nada.
func entregar_missao(id: String) -> bool:
	if estado_da_missao(id) != Missoes.PRONTA:
		return false
	var d := Missoes.dados(id)
	missoes[id]["estado"] = Missoes.ENTREGUE
	ouro += int(d.get("ouro", 0))
	if d.has("equipamento"): equipamentos[str(d.equipamento)] = true
	if d.has("alimentos"):
		preload("res://src/historia/tripulantes/provisoes.gd").guardar(self, "pao", int(d.alimentos))
	if desbloqueios.has(str(d.get("premio", ""))):
		desbloqueios[str(d["premio"])] = true     # a bússola da última missão do Guarda
	if d.has("fruta"):
		receber_fruta(str(d["fruta"]))          # recompensa extra: uma Akuma no Mi nas frutas guardadas (a missão só se entrega uma vez, então não duplica)
	if int(d.get("xp", 0)) > 0: ganhar_xp(int(d.xp))
	else: mudou.emit() # Missões sem XP também precisam salvar recompensa e conclusão.
	return true


## Barco afundado por besta (14/10/2026, decisão do dono): sai da frota para sempre.
func perder_barco(id: String) -> void:
	if barcos.erase(id):
		mudou.emit()


## Estado de um sistema (ver `sistemas`); {} se nunca gravou. Cópia: mudar não grava.
func dados_de(sistema: String) -> Dictionary:
	return (sistemas.get(sistema, {}) as Dictionary).duplicate(true)


func gravar_dados(sistema: String, dados: Dictionary) -> void:
	sistemas[sistema] = dados.duplicate(true)
	mudou.emit()


func item_do_mod(id: String) -> int:
	return inventario.contar(id)


func dar_item_do_mod(id: String, quantidade: int) -> void:
	if quantidade <= 0 or id.is_empty():
		return
	inventario.inserir(InventarioMinecraft.nova(id, quantidade))


## Gasta `quantidade` do item; false (e nada some) se não tem o bastante.
func gastar_item_do_mod(id: String, quantidade: int) -> bool:
	if quantidade <= 0:
		return true
	if item_do_mod(id) < quantidade:
		return false
	return inventario.remover(id, quantidade)


## OURO POR ABATE (20/11/2026, pedido do dono): 1 moeda a cada 50 de XP EFETIVO do abate (já com o teto anti-farm de `previa_do_abate`, então abate sem XP não paga).
## Arredonda para baixo: um abate de 60 XP paga 1 moeda, de 150 paga 3. Devolve as moedas pagas.
## GATILHO: se a economia ficar apertada/folgada, mexer SÓ em `XP_POR_MOEDA` (ou virar ficha por inimigo).
const XP_POR_MOEDA := 50

func ganhar_ouro_de_abate(xp_do_abate: int) -> int:
	var moedas := maxi(xp_do_abate, 0) / XP_POR_MOEDA
	if moedas > 0:
		ganhar_ouro(moedas)
	return moedas


func ganhar_ouro(quantidade: int) -> void:
	ouro = maxi(ouro + quantidade, 0)
	mudou.emit()


# ------------------------------------------------- lojas dos NPCs (03/10/2026)
# O ouro É a moeda das lojas (pescador compra peixe, domador vende pet, vendedor vende
# fruta). Cada operação é tudo ou nada e emite `mudou` uma vez (um save só).

## Vende até `quantidade` do item de pesca `id` a `preco` cada. Devolve quantos vendeu.
func vender_item_de_pesca(id: String, quantidade: int, preco: int) -> int:
	var tem := int(pesca.get(id, 0))
	var n := mini(maxi(quantidade, 0), tem)
	if n <= 0:
		return 0
	if tem - n <= 0:
		pesca.erase(id)
	else:
		pesca[id] = tem - n
	ouro += n * maxi(preco, 0)
	mudou.emit()
	return n


## Compra um pet da `especie` por `preco`. Vai para o inventário (N › PETS). Devolve o
## id do pet novo, ou "" sem ouro.
func comprar_pet(especie: String, nome: String, preco: int) -> String:
	if especie.is_empty() or ouro < preco:
		return ""
	ouro -= maxi(preco, 0)
	return adicionar_pet(especie, nome)   # emite `mudou` (com o ouro já descontado)


## Compra uma Akuma no Mi da arena por `preco`. Vai para o inventário (N › FRUTAS).
func comprar_fruta(id: String, preco: int) -> bool:
	if not PerfilDeFrutas.frutas_a_venda().has(id) or ouro < preco:
		return false
	if not inventario.pode_receber(ItensDeFruta.tag_akuma(id)):
		return false                                    # mochila cheia: não cobra
	ouro -= maxi(preco, 0)
	_guardar_fruta(ItensDeFruta.tag_akuma(id), 1, frutas_compradas, id)
	_contar("fruta")
	mudou.emit()
	return true


## Recebe uma fruta de graça (baú de chefe, 18/11/2026): vai para as guardadas (N › FRUTAS). false se a loja não vende essa fruta.
func receber_fruta(id: String) -> bool:
	if not PerfilDeFrutas.frutas_a_venda().has(id) or id == KitDoBuilder.ID:
		return false
	_guardar_fruta(ItensDeFruta.tag_akuma(id), 1, frutas_compradas, id)
	mudou.emit()
	return true


## Recebe uma arma do Epic Fight (baú de chefe, 18/11/2026): entra nos equipamentos e na mochila. false se já tem, não existe ou a mochila está cheia (nada muda).
func receber_arma(id: String) -> bool:
	if not LaminasEpicFight.existe(id) or equipamentos.has(id):
		return false
	if not inventario.inserir(ItensEpicFight.nova_pilha(id)).isEmpty():
		return false
	equipamentos[id] = true
	ef_quebradas.erase(id)
	mudou.emit()
	return true


## Compra uma habilidade de movimento (`HABILIDADES_A_VENDA`) do Barba Negra. Uma vez só.
func comprar_habilidade(chave: String, preco: int) -> bool:
	if not HABILIDADES_A_VENDA.has(chave) or bool(desbloqueios[chave]) or ouro < preco:
		return false
	ouro -= maxi(preco, 0)
	desbloqueios[chave] = true
	mudou.emit()
	return true


## Aprende a técnica Geppo por `preco` (Mestre do Geppo). Uma vez só; tudo-ou-nada.
func aprender_geppo(preco: int = PRECO_DO_GEPPO) -> bool:
	if bool(desbloqueios["geppo"]) or ouro < preco:
		return false
	ouro -= maxi(preco, 0)
	desbloqueios["geppo"] = true
	mudou.emit()
	return true


## Roleta do Barba Negra: cobra `preco` e recruta `id`, tudo-ou-nada (um `mudou`, um save).
## Quem sorteia é o `CatalogoDeTripulantes.sortear`; `false` = sem moedas, id inválido ou já recrutado.
func recrutar_por_sorteio(id: String, preco: int) -> bool:
	if not CatalogoDeTripulantes.existe(id) or recrutados.has(id) or ouro < preco or recrutados.size() >= 16:
		return false
	ouro -= maxi(preco, 0)
	recrutados[id] = true
	mudou.emit()
	return true


func tem_recrutado(id: String) -> bool:
	return recrutados.has(id)


## Compra o barco `id` (modelo da loja, categoria navios) por `preco`. Um de cada tipo.
func comprar_barco(id: String, preco: int) -> bool:
	if id.is_empty() or barcos.has(id) or ouro < preco:
		return false
	ouro -= maxi(preco, 0)
	barcos[id] = true
	mudou.emit()
	return true


## Come uma fruta comprada: sai do inventário e TROCA a fruta atual (a antiga se perde).
## Recusa a mesma fruta que já está comida (seria jogar a compra fora).
## Ferramenta de teste (F8, só em build de desenvolvimento): deixa o inventário com PELO MENOS `quantidade` desta fruta, sem gastar ouro.
## Idempotente (apertar de novo não acumula). Só frutas que a loja vende.
func dar_fruta_de_teste(id: String, quantidade: int) -> bool:
	if not PerfilDeFrutas.frutas_a_venda().has(id) or quantidade <= 0:
		return false
	var falta := quantidade - quantas_akuma(id)
	if falta > 0:
		_guardar_fruta(ItensDeFruta.tag_akuma(id), falta, frutas_compradas, id)
	mudou.emit()
	return true


func comer_fruta_comprada(id: String) -> bool:
	if fruta == id or not _tirar_fruta(ItensDeFruta.tag_akuma(id), 1, frutas_compradas, id):
		return false
	return comer_fruta(id)                # emite `mudou`


## Akuma no Mi que o personagem tem (inventário + excedente).
func quantas_akuma(id: String) -> int:
	return inventario.contar(ItensDeFruta.tag_akuma(id)) + int(frutas_compradas.get(id, 0))


## Põe `qtd` Akuma no inventário (o que não couber vira excedente). Devolve quantas entraram no inventário. Uso: recompensas, saves e testes.
func guardar_akuma(id: String, qtd := 1) -> int:
	var n := _guardar_fruta(ItensDeFruta.tag_akuma(id), qtd, frutas_compradas, id)
	mudou.emit()
	return n


## Todas as Akuma no Mi guardadas: id → quantidade.
func akumas_guardadas() -> Dictionary:
	return _contar_frutas(ItensDeFruta.AKUMA, frutas_compradas)


## Tira até `max_qtd` da fruta (limpeza de saves antigos); devolve quantas tirou.
func remover_akuma(id: String, max_qtd: int) -> int:
	var n := mini(max_qtd, quantas_akuma(id))
	if n > 0:
		_tirar_fruta(ItensDeFruta.tag_akuma(id), n, frutas_compradas, id)
	return n


func definir_skill(skill: String, valor: int) -> void:
	if SKILLS.has(skill):
		skills[skill] = clampi(valor, SKILL_MINIMA.get(skill, 0), SKILL_MAXIMO)
		mudou.emit()


func desbloquear(chave: String, ligado := true) -> void:
	if desbloqueios.has(chave):
		desbloqueios[chave] = ligado
		mudou.emit()


## Nova campanha (§21): tudo volta ao Civil nível 1. Mesmo objeto, para quem já
## está ligado nele (janela, cena) continuar ligado.
func reiniciar() -> void:
	var novo := ProgressaoDoPersonagem.new()
	corpo = novo.corpo
	tom_de_pele = novo.tom_de_pele
	aparencia = novo.aparencia.duplicate()
	raca = novo.raca
	fruta = novo.fruta
	fruta_ativa = novo.fruta_ativa
	espada_da_fruta = novo.espada_da_fruta
	ilha = novo.ilha
	local_salvo = {}
	nivel = novo.nivel
	xp = novo.xp
	limite_de_recompensa = novo.limite_de_recompensa
	ouro = novo.ouro
	skills = novo.skills
	desbloqueios = novo.desbloqueios
	pets = novo.pets
	pets_do_mapa_recebidos = novo.pets_do_mapa_recebidos
	pesca = novo.pesca
	frutas_do_pomar = novo.frutas_do_pomar
	item_ativo = novo.item_ativo
	equipamentos = novo.equipamentos
	vara_equipada = novo.vara_equipada
	kit_de_blocos_entregue = novo.kit_de_blocos_entregue
	inventario_ef_entregue = novo.inventario_ef_entregue
	espada_equipada = novo.espada_equipada
	lamina_ef = novo.lamina_ef
	durabilidade_ef = novo.durabilidade_ef
	lamina_ef_sec = novo.lamina_ef_sec
	ef_quebradas = novo.ef_quebradas
	machado_equipado = novo.machado_equipado
	inventario = novo.inventario
	inventario.mudou.connect(func(): itens_do_mod_mudaram.emit())
	madeira = novo.madeira
	frutas_compradas = novo.frutas_compradas
	missoes = novo.missoes
	barcos = novo.barcos
	recrutados = novo.recrutados
	sistemas = novo.sistemas
	ilhas_visitadas = novo.ilhas_visitadas
	mudou.emit()


func _subir_o_que_der() -> int:
	var ganhos := 0
	while xp >= xp_necessario():
		xp -= xp_necessario()
		nivel += 1
		ganhos += 1
		subiu_de_nivel.emit(nivel - 1, nivel)
	return ganhos


# ------------------------------------------------------------------ disco
func para_dict() -> Dictionary:
	return {"formato": FORMATO, "versao": VERSAO, "raca": raca, "corpo": corpo, "tom_de_pele": tom_de_pele, "aparencia": AparenciaHistoria.normalizar(aparencia), "nivel": nivel, "xp": xp, "limite_de_recompensa": limite_de_recompensa, "conquistas_mod": conquistas_mod.duplicate(true),
		"ouro": ouro, "skills": skills.duplicate(),
		"desbloqueios": desbloqueios.duplicate(),
		"fruta": fruta, "fruta_ativa": fruta_ativa, "espada_da_fruta": espada_da_fruta, "pets": pets.duplicate(true), "pesca": pesca.duplicate(),
		"frutas_do_pomar": frutas_do_pomar.duplicate(),
		"item_ativo": item_ativo, "equipamentos": equipamentos.duplicate(), "vara_equipada": vara_equipada, "kit_de_blocos_entregue": kit_de_blocos_entregue, "inventario_ef_entregue": inventario_ef_entregue,
		"espada_equipada": espada_equipada, "lamina_ef": lamina_ef, "lamina_ef_sec": lamina_ef_sec, "durabilidade_ef": durabilidade_ef.duplicate(), "ef_quebradas": ef_quebradas.duplicate(),
		"machado_equipado": machado_equipado, "madeira": madeira, "inventario": inventario.para_dict(),
		"pets_do_mapa_recebidos": pets_do_mapa_recebidos.duplicate(),
		"frutas_compradas": frutas_compradas.duplicate(), "missoes": missoes.duplicate(true),
		"barcos": barcos.duplicate(), "recrutados": recrutados.duplicate(), "ilhas_visitadas": ilhas_visitadas.duplicate(),
		"sistemas": sistemas.duplicate(true), "reanimacoes": reanimacoes_ms.duplicate(), "local_salvo": local_salvo.duplicate()}


## O arquivo de progresso fica no computador de quem joga e pode ser editado ou
## corromper. Tudo é PRESO a valores possíveis: nível mínimo 1,
## nada negativo. Campos antigos (`pontos`, `atributos`) são ignorados.
static func de_dict(d: Variant) -> ProgressaoDoPersonagem:
	return load("res://src/historia/serializacao_do_progresso.gd").de_dict(d)


static func carregar(caminho: String) -> ProgressaoDoPersonagem:
	if not FileAccess.file_exists(caminho):
		return ProgressaoDoPersonagem.new()
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(caminho)) != OK:
		push_warning("[Progressão] %s ilegível — começando do nível 1" % caminho)
		return ProgressaoDoPersonagem.new()
	return de_dict(json.data)


## Grava num temporário e troca: fechar o jogo no meio não deixa progresso truncado.
func salvar(caminho: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(caminho.get_base_dir()))
	var f := FileAccess.open(caminho + ".tmp", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(para_dict(), "\t", false) + "\n")
	f.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho + ".tmp"),
		ProjectSettings.globalize_path(caminho))
