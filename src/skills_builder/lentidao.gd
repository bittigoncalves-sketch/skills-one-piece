class_name Lentidao
extends RefCounted
## LENTIDÃO de skill do Builder (06/10/2026) — Noro Noro no Mi: "desacelerar qualquer ser
## atingido", e a Z deixa "5 vezes mais lento". Decisão do dono: MOVIMENTO E AÇÕES.
##
## Um fator por corpo (1 = livre, 0,2 = 5× mais lento) com prazo, num meta do próprio
## corpo. Quem anda ou age multiplica o seu tempo/velocidade por `fator(corpo)`:
##   • andar: Player (velocidade efetiva), boneco (caminhada), animal (velocidade);
##   • ações: animador procedural (o tempo da pose), executor corpo a corpo (o golpe
##     inteiro), executor de skill do Builder, IA de skill do inimigo e o cérebro do
##     animal.
## Em rede, o fator vai para TODOS os peers do jogador atingido: quem move o corpo é
## o cliente dono dele, e só o servidor sabe do acerto.

const META := "lentidao_de_skill"
const AURA := "AuraDeLentidao"
const AURA_CENA := preload("res://src/skills_builder/aura_de_lentidao.gd")


## Deixa `corpo` com `fator` (0..1) por `segundos`. O mais lento vence se já estiver lento.
static func aplicar(corpo: Node, fator: float, segundos: float) -> void:
	if corpo == null or not is_instance_valid(corpo) or segundos <= 0.0 or fator >= 1.0:
		return
	if corpo.has_method("aplicar_lentidao_em_rede") and corpo.multiplayer.has_multiplayer_peer():
		corpo.aplicar_lentidao_em_rede(fator, segundos)
	else:
		aplicar_local(corpo, fator, segundos)


static func aplicar_local(corpo: Node, fator: float, segundos: float) -> void:
	var ate := Time.get_ticks_msec() + int(segundos * 1000.0)
	if corpo.has_meta(META):
		var atual: Dictionary = corpo.get_meta(META)
		if Time.get_ticks_msec() < int(atual.get("ate", 0)):
			fator = minf(fator, float(atual.get("fator", 1.0)))
			ate = maxi(ate, int(atual.get("ate", 0)))
	corpo.set_meta(META, {"fator": clampf(fator, 0.02, 1.0), "ate": ate})
	if corpo is Node3D and corpo.get_node_or_null(AURA) == null:
		var aura: Node3D = AURA_CENA.new()
		aura.name = AURA
		corpo.add_child(aura)


## Quanto o corpo anda e age agora (1 = livre): a lentidão de skill (`fator_proprio`) vezes o tempo
## local do Modo História (`TempoLocal`: vida baixa do jogador desacelera o mundo ao redor).
## É o ponto único por onde animais, bonecos, personagens do Mine Piece, executor de skill e
## animador procedural já passam — por isso o tempo local entra aqui.
static func fator(corpo: Node) -> float:
	return fator_proprio(corpo) * TempoLocal.fator_de(corpo)


## Só a lentidão APLICADA ao corpo (Noro Noro e afins). A aura de fótons usa este: o tempo local
## desacelera o mundo todo e não deve encher o mapa de auras.
static func fator_proprio(corpo: Node) -> float:
	if corpo == null or not corpo.has_meta(META):
		return 1.0
	var l: Dictionary = corpo.get_meta(META)
	if Time.get_ticks_msec() >= int(l.get("ate", 0)):
		corpo.remove_meta(META)
		return 1.0
	return float(l.get("fator", 1.0))


## Segundos que ainda faltam (0 = livre).
static func resta(corpo: Node) -> float:
	if corpo == null or not corpo.has_meta(META):
		return 0.0
	return maxf(0.0, (int((corpo.get_meta(META) as Dictionary).get("ate", 0)) - Time.get_ticks_msec()) / 1000.0)
