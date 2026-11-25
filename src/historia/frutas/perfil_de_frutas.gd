class_name PerfilDeFrutas
extends Resource
# ============================================================================
#  OS NÚMEROS DE UMA FRUTA NO MODO HISTÓRIA.
#
#  Injetado no corpo pelo `ModoHistoria` (um ponto só, como o combate direcional).
#  **Nulo na arena** — e nulo quer dizer "faz o de sempre": `Balance.gd`,
#  `SkillSystem.get_slot_cooldown` e `Player.ENERGY_SKILL`. Nenhum caminho da arena
#  muda por causa deste arquivo.
#
#  Por que existe: a arena tem vida 2.048 e energia 4.096, e cobra 180 por técnica;
#  a história começa com vida 20 e energia 10. O mesmo golpe precisa de dois jogos
#  de números, e a fruta é a mesma.
# ============================================================================

## Id da fruta a que este perfil pertence (`Player.current_fruit_id`).
@export var fruta := ""
## Energia por segundo que o corpo recupera NESTE modo. 0 = usa a regra da arena
## (0,5% do máximo por segundo), que com energia 10 daria 0,05/s — lento demais.
@export_range(0.0, 10.0, 0.1, "suffix:/s") var regen_de_energia := 0.0
## Quanto do dano passa quando a guarda do combate direcional bloqueia (0,3 = 30%).
@export_range(0.0, 1.0, 0.05) var dano_bloqueado := 0.3
@export var tecnicas: Array[TecnicaDeFruta] = []
## Multiplica o dano das técnicas que vêm da tabela da ARENA (`Balance.novo`). 1 = a
## ficha já está na escala da história (a Rocket: dano escrito em cada técnica).
@export_range(0.0, 1.0, 0.001) var escala_de_dano := 1.0
## Fruta importada do Mine Piece (decisão do dono, 26/10/2026: "o mod manda, sem ajuste"):
## nenhum fator da história entra no dano — nem o +50 % das técnicas nem o −50 % do soco.
## A escala é só a do formato interno (dano do mod × 10 → `ESCALA_DO_MOD` devolve ao do mod).
var fiel_ao_mod := false


## A escala que as TÉCNICAS usam: a do perfil com o bônus da história (`Balance.HISTORIA_TECNICAS`).
func escala_das_tecnicas() -> float:
	if fiel_ao_mod or fruta in Balance.HISTORIA_SEM_BONUS_DE_TECNICA:
		return escala_de_dano
	# O estilo base (kit do Builder) não ganha o aumento das Akuma no Mi.
	if fruta == KitDoBuilder.ID:
		return escala_de_dano * Balance.HISTORIA_TECNICAS_ESTILO_BASE
	return escala_de_dano * Balance.HISTORIA_TECNICAS

# ------------------------------------------------------- frutas da arena (03/10/2026)
# Pedido do dono: o vendedor de frutas vende as frutas do singleplayer (arena) no
# Modo História. Decisão dele: "kit da arena, escala história" — os MESMOS golpes,
# com energia, recarga e dano da história. A ficha é gerada da arena (uma fonte só:
# fruta nova na arena aparece aqui sem arquivo novo).
#
# ESCALA = vida do inimigo da história / vida do jogador da arena (250 / 2.048): o
# golpe tira do inimigo a MESMA fração de vida que tira de um jogador na arena.
# `test_frutas_na_historia` confere contra `InimigoDoMapa.VIDA_PADRAO`.
const ESCALA_DA_ARENA := 250.0 / 2048.0
## Frutas do Mine Piece: o código guarda o dano do mod × 10 (`MundoMinePiece`); esta escala o
## devolve ao número do mod, sem converter vida de um jogo para o outro (1 ponto = 1 ponto).
const ESCALA_DO_MOD := 1.0 / 10.0
## Energia por tecla na história e regeneração por segundo. Escritos para a barra de 10;
## ×10 em 23/10/2026: energia virou 100 por nível (era 10 no nível 1) — a proporção do
## nível 1 fica a de antes, e cada nível acima dá mais usos.
const CUSTO_DA_ARENA := {"Z": 20.0, "X": 30.0, "C": 30.0, "V": 50.0, "F": 20.0}
const REGEN_DA_ARENA := 10.0
## Comportamento das técnicas geradas: "o golpe da arena, como ele é".
const COMPORTAMENTO_DA_ARENA := "arena"


## As frutas da arena que existem para vender (a Rocket é da história e vem do mapa).
## Forma de outra fruta não é fruta: "gomu_gomu_gear2" é o Gear 2 da Gomu.
static func frutas_da_arena() -> Array[String]:
	var todas: Array = SkillSystem.get_fruit_skills().keys()
	var saida: Array[String] = []
	for id in todas:
		if str(id) == "rocket":
			continue
		var forma := false
		for outra in todas:
			forma = forma or (outra != id and str(id).begins_with(str(outra) + "_"))
		if not forma:
			saida.append(str(id))
	return saida


## O que o vendedor de frutas vende: as da arena e as FRUTAS DO BUILDER prontas
## (decisão do dono, 06/10/2026: a Noro Noro no Mi é vendida como as outras).
static func frutas_a_venda() -> Array[String]:
	var saida := frutas_da_arena()
	for id in KitDoBuilder.frutas_prontas():
		if not CatalogoFrutasMinePiece.substituida(id):   # a tradução nativa toma o lugar
			saida.append(id)
	# O Kit do Builder (skills sem fruta) também vira item (07/10/2026, "Publicar na loja").
	if KitDoBuilder.disponivel(KitDoBuilder.ID):
		saida.append(KitDoBuilder.ID)
	# Goro Goro (Mine Piece), tradução do mod (18/10/2026): 1 moeda, pedido do dono.
	saida.append(GORO_MINE_PIECE)
	saida.append_array(CatalogoFrutasMinePiece.ids())
	# As demais frutas do mod (08/11/2026): o jogador as usa pelo fluxo do mod (`ControladorFrutaDoMod`). Ficam de fora as que
	# já têm venda (arena) e as que a tradução nativa cobre (Moku, Nikyu).
	saida.append_array(frutas_so_do_mod())
	return saida


## Frutas do mod que NÃO existem na arena nem têm tradução nativa: vendidas só pelo fluxo do mod, 1 moeda.
static func frutas_so_do_mod() -> Array[String]:
	var arena := frutas_da_arena()
	var saida: Array[String] = []
	for id in FrutasDoMod.FRUTAS:
		if arena.has(id) or CatalogoFrutasMinePiece.ids().has(id + "_mine_piece"):
			continue
		saida.append(id)
	return saida


## `GoroGoroMinePiece.ID`, escrito aqui: citar a classe puxaria o Player para todo
## script que usa esta ficha (e quebraria os testes `--script`, sem autoloads).
const GORO_MINE_PIECE := "goro_goro_mine_piece"

## ECONOMIA DAS FRUTAS (pedido do dono, 18/11/2026: "precificação a partir de 1000 moedas, variando de acordo com o poder da fruta"). Substitui a de 17/10 (500 mil
## nas demais, 1 moeda nas do Mine Piece). Cada fruta tem um PODER de 1 a 5 (a raridade); o preço sai da raridade e é a MESMA escala que o baú de chefe usa para
## sortear (`frutas_do_poder`). Poder = o papel da fruta no kit, lido do anime e das técnicas que o jogo já tem — decisão de design, não medição.
## Fruta fora da tabela (Builder, futuras) vale `PODER_PADRAO` até alguém classificá-la. GATILHO para rever: a economia de moedas mudar muito (hoje um baú de
## naufrágio paga 15–40) ou o jogador pedir ajuste fino de uma fruta.
const NOMES_DO_PODER := ["Comum", "Incomum", "Rara", "Épica", "Lendária"]
const PRECO_POR_PODER := [1000, 2500, 6000, 15000, 40000]
const PODER_PADRAO := 2
const PODER_DAS_FRUTAS := {
	# 1 · Comum: utilidade e golpes simples
	"bara_bara": 1, "buki_buki": 1, "suke_suke": 1, "bomu_bomu": 1, "noro_noro": 1, "riki_riki": 1, "kiro_kiro": 1, "bisu_bisu": 1,
	"supa_supa": 1, "batto_batto": 1, "horo_horo": 1,
	# 2 · Incomum: zoans comuns e paramecias de controle
	"kira_kira": 2, "mero_mero": 2, "soru_soru": 2, "uta_uta": 2, "inu_inu_wolf": 2, "ushi_ushi_giraffe": 2, "neko_neko_leopard": 2,
	# 3 · Rara: zoans antigos, e paramecias/logias de nicho
	"aro_aro": 3, "mochi_mochi": 3, "mori_mori": 3, "neko_neko_sabertiger": 3, "ryu_ryu_pteranodon": 3, "ryu_ryu_brachiosaurus": 3,
	"ryu_ryu_pachycephalosaurus": 3, "nikyu_nikyu_mine_piece": 3, "nikyu_nikyu": 3,
	# 4 · Épica: logias de elemento e paramecias de campo de batalha
	"mera_mera": 4, "hie_hie": 4, "suna_suna": 4, "kage_kage": 4, "zushi_zushi": 4, "gomu_gomu": 4, "imu": 4,
	"hie_hie_mine_piece": 4, "moku_moku_mine_piece": 4, "moku_moku": 4,
	# 5 · Lendária: míticas e as que decidem uma luta sozinhas
	"ope_ope": 5, "gura_gura": 5, "yami_yami": 5, "magu_magu": 5, "pika_pika": 5, "goro_goro": 5, "tori_tori_phoenix": 5,
	"hito_hito_daibutsu": 5, "uo_uo_seiryu": 5, "inu_inu_okuchi_no_makami": 5,
	"ope_ope_mine_piece": 5, "pika_pika_mine_piece": 5, "goro_goro_mine_piece": 5,
}


## Poder (1–5) da fruta; o Kit do Builder não é fruta (não tem poder).
static func poder_da_fruta(id: String) -> int:
	return int(PODER_DAS_FRUTAS.get(id, PODER_PADRAO))


static func raridade_da_fruta(id: String) -> String:
	return str(NOMES_DO_PODER[poder_da_fruta(id) - 1])


## As frutas à venda de um poder (as que o baú de chefe pode dar). O Kit do Builder fica de fora.
static func frutas_do_poder(poder: int) -> Array[String]:
	var saida: Array[String] = []
	for id in frutas_a_venda():
		if id != KitDoBuilder.ID and poder_da_fruta(id) == poder:
			saida.append(id)
	return saida


static func preco_na_loja(id: String) -> int:
	if id == KitDoBuilder.ID:
		return SkillsPublicadas.preco(id)
	return int(PRECO_POR_PODER[poder_da_fruta(id) - 1])

static func imagem_na_loja(id: String) -> String:
	if id == "hito_hito_daibutsu":
		return "res://assets/models/buda/buda_loja.png"
	if CatalogoFrutasMinePiece.contem(id):
		return str(CatalogoFrutasMinePiece.FICHAS[id].icone)
	if frutas_so_do_mod().has(id):
		return "res://assets/mine_piece/frutas/icones/%s_mine_piece.png" % id
	var caminho := "res://assets/ui/frutas/%s.png" % id
	return caminho if ResourceLoader.exists(caminho) else "res://assets/ui/barra/fruta.svg"


## "ope_ope" → "Ope Ope no Mi".
static func nome_da_fruta(id: String) -> String:
	if CatalogoFrutasMinePiece.contem(id):
		return str(CatalogoFrutasMinePiece.FICHAS[id].nome)
	if frutas_so_do_mod().has(id):
		return id.replace("_", " ").capitalize() + " (Mine Piece)"
	if id == "tori_tori_phoenix": return "Tori Tori no Mi · Phoenix"
	if id == "rocket":
		return "Rocket"
	if id == GORO_MINE_PIECE:
		return "Goro Goro (Mine Piece)"
	if KitDoBuilder.e_do_builder(id):
		return KitDoBuilder.nome(id)
	return id.replace("_", " ").capitalize() + " no Mi"


## A ficha de uma fruta da arena na escala da história (null se a fruta não existe).
static func da_arena(id: String) -> PerfilDeFrutas:
	var kit: Dictionary = SkillSystem.get_fruit_skills().get(id, {})
	if kit.is_empty():
		return null
	var p := PerfilDeFrutas.new()
	p.fruta = id
	p.regen_de_energia = REGEN_DA_ARENA
	p.escala_de_dano = ESCALA_DA_ARENA
	for slot: String in ["Z", "X", "C", "V", "F"]:
		# Tecla que o kit da arena desliga ("desabilitado") também não existe aqui.
		if not kit.has(slot) or (kit[slot] is Dictionary and bool((kit[slot] as Dictionary).get("desabilitado", false))):
			continue
		var t := TecnicaDeFruta.new()
		t.slot = slot
		var ficha: Variant = kit[slot]
		t.nome = str(ficha.get("nome", slot)) if ficha is Dictionary else slot
		t.comportamento = COMPORTAMENTO_DA_ARENA
		t.recarga = SkillSystem.recarga_da_arena(slot, id)
		t.custo_de_energia = float(CUSTO_DA_ARENA[slot])
		# Tecla refeita no Builder (Pika, 06/10/2026): nome e recarga da skill publicada.
		# A ENERGIA fica a da ficha da fruta (a economia da história), não a fração do
		# Builder (07/10/2026, `test_frutas_na_historia`).
		if KitDoBuilder.pelo_builder(id, slot):
			t.nome = KitDoBuilder.nome_da_tecla(slot, id)
			t.comportamento = KitDoBuilder.COMPORTAMENTO
			t.recarga = KitDoBuilder.recarga(slot, id)
		p.tecnicas.append(t)
	return p


func tecnica(slot: String) -> TecnicaDeFruta:
	for t in tecnicas:
		if t != null and t.slot == slot:
			return t
	return null


## As teclas que esta fruta usa neste modo, na ordem da ficha (a HUD lê daqui).
func slots() -> Array[String]:
	var saida: Array[String] = []
	for t in tecnicas:
		if t != null and t.valida():
			saida.append(t.slot)
	return saida


func tem(slot: String) -> bool:
	return tecnica(slot) != null


func custo_de_energia(slot: String, padrao: float) -> float:
	var t := tecnica(slot)
	return t.custo_de_energia if t != null else padrao


func recarga(slot: String, padrao: float) -> float:
	var t := tecnica(slot)
	return t.recarga if t != null else padrao


## Erros de preenchimento que só apareceriam jogando. Devolve a lista de problemas.
func problemas() -> Array[String]:
	var saida: Array[String] = []
	if fruta.is_empty():
		saida.append("perfil sem fruta")
	var vistos := {}
	for t in tecnicas:
		if t == null or not t.valida():
			saida.append("técnica sem slot ou sem comportamento")
			continue
		if vistos.has(t.slot):
			saida.append("dois golpes na mesma tecla: %s" % t.slot)
		vistos[t.slot] = true
		if t.custo_de_energia <= 0.0:
			saida.append("%s: custo de energia 0 (padrão neutro não foi preenchido)" % t.slot)
		if t.recarga <= 0.0:
			saida.append("%s: recarga 0" % t.slot)
	return saida
