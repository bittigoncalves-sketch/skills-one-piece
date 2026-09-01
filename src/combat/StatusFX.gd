class_name StatusFX
extends RefCounted
# ============================================================================
#  STATUS DO PERSONAGEM — o registro do que está acontecendo com você AGORA.
#
#  O jogo já marcava os efeitos com `set_meta("is_frozen", true)` e parecidos.
#  Isso diz *o quê*, mas não *até quando* — e sem o "até quando" não dá para
#  mostrar contador na tela. Aqui os dois andam juntos.
#
#  COMO USAR, de dentro de um efeito:
#
#      StatusFX.aplicar(alvo, StatusFX.CONGELADO, 5.0)
#      StatusFX.remover(alvo, StatusFX.CONGELADO)      # se acabar antes da hora
#
#  Uma linha ao lado do `set_meta` que já existe. Não substitui o meta — o
#  código de jogo continua lendo `is_frozen` como sempre; isto é a camada de
#  APRESENTAÇÃO, e some sem quebrar nada.
#
#  ONDE FICA GUARDADO: num meta do próprio alvo (`_status_fx`), não num nó. Assim
#  vale para Player, TrainingDummy, inimigo — qualquer coisa que exista na cena —
#  sem obrigar ninguém a herdar de nada.
# ============================================================================

const META := "_status_fx"

# Ids dos status. Constantes em vez de string solta: erro de digitação em string
# vira status fantasma que nunca aparece e nunca some.
const CONGELADO := "congelado"
const QUEIMANDO := "queimando"
const SUGADO := "sugado"
const BURACO_NEGRO := "buraco_negro"
const SILENCIADO := "silenciado"
const INVULNERAVEL := "invulneravel"

# Nome, cor e desenho de cada um. O `icone` é o nome da figura que o
# `src/ui/StatusEffectsHud.gd` sabe desenhar — não é arquivo de imagem, é
# desenho procedural, no mesmo idioma do resto do jogo (sem asset para carregar,
# sem textura para sumir).
const CATALOGO := {
	CONGELADO:    {"nome": "Congelado",    "cor": Color(0.55, 0.85, 1.00), "icone": "gelo"},
	QUEIMANDO:    {"nome": "Queimando",    "cor": Color(1.00, 0.55, 0.15), "icone": "fogo"},
	SUGADO:       {"nome": "Sugado",       "cor": Color(0.85, 0.70, 0.35), "icone": "vortice"},
	BURACO_NEGRO: {"nome": "Buraco Negro", "cor": Color(0.62, 0.35, 0.90), "icone": "buraco"},
	SILENCIADO:   {"nome": "Sem Poderes",  "cor": Color(0.75, 0.30, 0.85), "icone": "proibido"},
	INVULNERAVEL: {"nome": "Invulnerável", "cor": Color(1.00, 0.88, 0.35), "icone": "escudo"},
}

# ------------------------------------------------------------------- escrita
## ⚠️ O CORPO DE FERRO RECUSA TUDO (2026-08-31, Fase 6 do plano de combate).
##
## Pedido do dono: a janela do Corpo de Ferro "torna a imunidade a qualquer
## efeito, mesmo que este esteja em ação". A recusa mora AQUI, e não numa lista
## de efeitos dentro do controlador, porque este é o único ponto por onde todo
## status entra: uma lista precisaria ser atualizada a cada efeito novo do jogo,
## e o primeiro que alguém esquecesse furaria a imunidade em silêncio.
const META_IRON := "iron_body_active"


static func aplicar(alvo: Node, id: String, duracao: float) -> void:
	if alvo == null or not is_instance_valid(alvo) or duracao <= 0.0:
		return
	# O próprio INVULNERAVEL do Corpo de Ferro passa: ele É o efeito da janela.
	if id != INVULNERAVEL and bool(alvo.get_meta(META_IRON, false)):
		return
	var mapa: Dictionary = alvo.get_meta(META, {})
	var agora := Time.get_ticks_msec()
	var novo_fim := agora + int(duracao * 1000.0)
	# Reaplicar um status que já está rodando ESTENDE, não encurta. Pisar de novo
	# no gelo com 4 s restantes e receber "5 s" tem que dar 5, nunca 4.
	var atual: Dictionary = mapa.get(id, {})
	var fim: int = maxi(novo_fim, int(atual.get("fim", 0)))
	mapa[id] = {"fim": fim, "total": maxf(duracao, float(atual.get("total", 0.0)))}
	alvo.set_meta(META, mapa)

static func remover(alvo: Node, id: String) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	var mapa: Dictionary = alvo.get_meta(META, {})
	if mapa.erase(id):
		alvo.set_meta(META, mapa)

# ------------------------------------------------------------------- leitura
# Os status vivos, do mais perto de acabar para o mais longe — quem está
# prestes a expirar interessa mais, e assim a lista não fica pulando de posição
# a cada frame.
#
# Devolve [{id, nome, cor, icone, restante, total}].
## Tira TODOS os status do alvo. É o que a janela do Corpo de Ferro faz ao
## abrir — "mesmo que este esteja em ação" quer dizer que os já rodando saem.
static func limpar_tudo(alvo: Node) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	# ⚠️ `ativos()` devolve DICIONÁRIOS (id, nome, cor, ícone, restante), não uma
	# lista de ids. Iterar como se fossem strings limpa nada e não avisa.
	for st in ativos(alvo):
		remover(alvo, String((st as Dictionary)["id"]))


static func ativos(alvo: Node) -> Array:
	if alvo == null or not is_instance_valid(alvo):
		return []
	var mapa: Dictionary = alvo.get_meta(META, {})
	if mapa.is_empty():
		return []
	var agora := Time.get_ticks_msec()
	var out: Array = []
	var expirados: Array = []
	for id in mapa:
		var restante := (int(mapa[id]["fim"]) - agora) / 1000.0
		if restante <= 0.0:
			expirados.append(id)
			continue
		var info: Dictionary = CATALOGO.get(id, {"nome": str(id), "cor": Color.WHITE, "icone": "generico"})
		out.append({
			"id": id,
			"nome": info["nome"],
			"cor": info["cor"],
			"icone": info["icone"],
			"restante": restante,
			"total": float(mapa[id]["total"]),
		})
	# Limpeza preguiçosa: quem lê é quem varre. Evita um timer por status.
	if not expirados.is_empty():
		for id in expirados:
			mapa.erase(id)
		alvo.set_meta(META, mapa)
	out.sort_custom(func(a, b): return float(a["restante"]) < float(b["restante"]))
	return out
