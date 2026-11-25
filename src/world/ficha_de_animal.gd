class_name FichaDeAnimal
extends RefCounted
# ============================================================================
#  FICHA DE ANIMAL — como um animal da loja vive na ilha (01/10/2026).
#
#  Pedido do dono: os animais da categoria "Animais" espalhados pelo mapa, cada um com
#  um COMPORTAMENTO (tabela aprovada por ele): presa que foge, doméstico/fazenda,
#  territorial, predador; gorila e harpia são CHEFES presos a uma área. Morrem dando
#  1 XP e o item "none" (= nada, por enquanto) e renascem em 30 s num ponto aleatório da
#  área da espécie (chefe não).
#
#  A ficha mora no catálogo da loja (campo "animal" do modelo), como a de navio: um
#  lugar só por espécie, editável sem mexer em código.
# ============================================================================

const COMPORTAMENTOS: Array[String] = ["presa", "domestico", "territorial", "predador"]
## Como o corpo se move e anima (procedural para os modelos sem esqueleto).
const CORPOS: Array[String] = ["quadrupede", "saltador", "ave_chao", "rastejante", "voador", "caranguejo"]

## Valores de partida por comportamento (velocidades em m/s, distâncias em m).
const BASE := {
	"presa": {"vida": 25, "passeio": 1.4, "corrida": 6.5, "dano": 0, "alerta": 9.0, "alcance": 0.0, "recarga": 0.0},
	"domestico": {"vida": 40, "passeio": 1.0, "corrida": 3.0, "dano": 0, "alerta": 0.0, "alcance": 0.0, "recarga": 0.0},
	"territorial": {"vida": 160, "passeio": 1.3, "corrida": 5.0, "dano": 3, "alerta": 6.0, "alcance": 1.8, "recarga": 1.6},
	"predador": {"vida": 200, "passeio": 1.6, "corrida": 5.6, "dano": 4, "alerta": 14.0, "alcance": 1.8, "recarga": 1.4},
}
## `golpe_em`: segundos entre começar o ataque e o impacto (o quadro do golpe no clipe do
## rig; 0 = na hora, para modelo sem clipe de ataque).
const CAMPOS_NUMERICOS := ["vida", "passeio", "corrida", "dano", "alerta", "alcance", "recarga", "xp", "altura_voo", "golpe_em"]


## Ficha nova: valores do comportamento, mais o que vier em `extra`. Sem `xp` em
## `extra`, o XP sai da dificuldade (`xp_por_dificuldade`).
static func nova(comportamento: String, corpo: String, extra := {}) -> Dictionary:
	var f := {"comportamento": comportamento, "corpo": corpo, "boss": false, "xp": 1, "item": "none",
		"altura_voo": 0.0, "nome": "", "domavel": false, "golpe_em": 0.0}
	f.merge(BASE[comportamento])
	f.merge(extra, true)
	if not extra.has("xp"):
		f["xp"] = xp_por_dificuldade(f)
	return f


## XP por abater, pela DIFICULDADE (08/10/2026, pedido do dono: "modificar a
## experiência recebida por matar cada animal com base na dificuldade de cada um"; era
## 1 para todos): quanto ele aguenta (vida) e quanto machuca (dano).
## vida/10 × (1 + dano/2), arredondado, no mínimo 1 — coelho 1, veado 5, vaca 12,
## águia 17, búfalo 60, urso 77, harpia 280, gorila 405 (chefes caem na faixa
## mini-boss/boss do documento, inimigo forte 25–75 no meio). Serve às bestas do mar.
static func xp_por_dificuldade(f: Dictionary) -> int:
	var vida := maxf(float(f.get("vida", 1.0)), 0.0)
	var dano := maxf(float(f.get("dano", 0.0)), 0.0)
	return maxi(roundi(vida / 10.0 * (1.0 + dano / 2.0)), 1)


## Valida o que veio do catálogo. {} = sem ficha (ou inválida — um animal com vida
## negativa ou comportamento desconhecido não pode nascer).
static func normalizar(bruto: Variant) -> Dictionary:
	if not (bruto is Dictionary):
		return {}
	var d: Dictionary = bruto
	var comp := str(d.get("comportamento", ""))
	var corpo := str(d.get("corpo", ""))
	if not COMPORTAMENTOS.has(comp) or not CORPOS.has(corpo):
		return {}
	var f := nova(comp, corpo)
	for campo in CAMPOS_NUMERICOS:
		if not d.has(campo):
			continue
		var v: Variant = d[campo]
		if not ((v is float and is_finite(v)) or v is int) or float(v) < 0.0 or float(v) > 100000.0:
			return {}
		f[campo] = float(v)
	f["vida"] = maxf(float(f["vida"]), 1.0)
	f["boss"] = bool(d.get("boss", false))
	# Domável com fruta do pomar (decisão do dono, 01/10/2026: os herbívoros). Chefe nunca.
	f["domavel"] = bool(d.get("domavel", false)) and not f["boss"]
	f["item"] = str(d.get("item", "none"))
	# Nome de exibição (HUD, editor). Vazio = o nome do modelo na loja.
	f["nome"] = str(d.get("nome", "")).strip_edges().left(40)
	return f


static func domavel(f: Dictionary) -> bool:
	return bool(f.get("domavel", false)) and not bool(f.get("boss", false))


static func voa(f: Dictionary) -> bool:
	return str(f.get("corpo", "")) == "voador"


## Hostil = entra no grupo de inimigos (pets em guarda, mira assistida): quem ataca.
static func hostil(f: Dictionary) -> bool:
	return f.get("comportamento", "") in ["territorial", "predador"]
