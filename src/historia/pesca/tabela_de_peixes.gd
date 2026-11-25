class_name TabelaDePeixes
extends RefCounted
# ============================================================================
#  TABELA DE PEIXES — o que a pesca sorteia (03/10/2026).
#
#  Os peixes são os modelos da categoria "pesca" da loja (o dono importou ~36).
#  Aqui mora só o que a loja não sabe: nome em português e RARIDADE. A raridade
#  manda na briga (decisão do dono: "peixes raros puxam mais forte" —
#  `TensaoDaLinha.RARIDADES`) e na chance de vir.
#
#  Peixe que o dono apagar da loja sai do sorteio sozinho (`sortear` confere a
#  biblioteca). Peixe novo na loja só entra aqui ao ganhar uma linha.
#  GATILHO para virar dado da loja (campo no catálogo, editado pela loja): quando o
#  dono quiser mudar raridade sem código, ou peixe por lugar (rio × mar) / por isca.
# ============================================================================

## Chance de cada raridade vir (soma 100).
const CHANCE := {"comum": 60, "incomum": 28, "raro": 10, "lendario": 2}
const NOME_DA_RARIDADE := {"comum": "comum", "incomum": "incomum", "raro": "raro", "lendario": "lendário"}

## id do modelo na loja → [nome, raridade].
const PEIXES := {
	"goldfish": ["Peixe-dourado", "comum"],
	"blue_goldfish": ["Peixe-dourado-azul", "comum"],
	"tetra": ["Tetra", "comum"],
	"cardinal_fish": ["Peixe-cardeal", "comum"],
	"butterfly_fish": ["Peixe-borboleta", "comum"],
	"cowfish": ["Peixe-vaca", "comum"],
	"red_snapper": ["Vermelho", "comum"],
	"yellow_tang": ["Cirurgião-amarelo", "comum"],
	"tang": ["Cirurgião", "comum"],
	"blue_tang": ["Cirurgião-azul", "comum"],
	"royal_gramma": ["Grama-real", "comum"],
	"flatfish": ["Linguado", "comum"],
	"turbot": ["Pregado", "comum"],
	"armored_catfish": ["Cascudo", "comum"],
	"piranha": ["Piranha", "comum"],
	"clownfish": ["Peixe-palhaço", "incomum"],
	"zebra_clown_fish": ["Palhaço-zebra", "incomum"],
	"betta": ["Betta", "incomum"],
	"koi": ["Carpa koi", "incomum"],
	"parrot_fish": ["Peixe-papagaio", "incomum"],
	"coral_grouper": ["Garoupa-coral", "incomum"],
	"puffer": ["Baiacu", "incomum"],
	"moorish_idol": ["Ídolo-mouro", "incomum"],
	"flower_horn": ["Flower horn", "incomum"],
	"mandarin_fish": ["Peixe-mandarim", "incomum"],
	"humphead": ["Napoleão", "incomum"],
	"lionfish": ["Peixe-leão", "incomum"],
	"tuna": ["Atum", "raro"],
	"swordfish": ["Espadarte", "raro"],
	"black_lion_fish": ["Peixe-leão-negro", "raro"],
	"sunfish": ["Peixe-lua", "raro"],
	"shark": ["Tubarãozinho", "raro"],
	"blobfish": ["Peixe-bolha", "raro"],
	"anglerfish": ["Peixe-diabo", "lendario"],
	"goblin_shark": ["Tubarão-duende", "lendario"],
}


static func eh_peixe(id: String) -> bool:
	return PEIXES.has(id)


static func nome(id: String) -> String:
	return str(PEIXES[id][0]) if PEIXES.has(id) else id


static func raridade(id: String) -> String:
	return str(PEIXES[id][1]) if PEIXES.has(id) else "comum"


## Um peixe que exista na loja `bib` (null = qualquer da tabela). "" se nenhum existe.
## Sorteia a raridade pela CHANCE e, dentro dela, um peixe; raridade sem peixe na
## loja cai para a próxima mais comum.
static func sortear(rng: RandomNumberGenerator, bib: BibliotecaDeModelos = null) -> String:
	var por_raridade := {}
	for id: String in PEIXES:
		if bib == null or bib.tem(id):
			var r := raridade(id)
			por_raridade[r] = por_raridade.get(r, []) + [id]
	if por_raridade.is_empty():
		return ""
	var ordem: Array = CHANCE.keys()   # comum → lendário (ordem de declaração)
	var dado := rng.randi_range(1, 100)
	var escolhida := 0
	var acumulado := 0
	for i in ordem.size():
		acumulado += int(CHANCE[ordem[i]])
		if dado <= acumulado:
			escolhida = i
			break
	for i in range(escolhida, -1, -1):
		var lista: Array = por_raridade.get(ordem[i], [])
		if not lista.is_empty():
			return lista[rng.randi_range(0, lista.size() - 1)]
	for r in ordem:
		if por_raridade.has(r):
			return por_raridade[r][0]
	return ""
