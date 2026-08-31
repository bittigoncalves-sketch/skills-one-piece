class_name ContextualMelee
extends RefCounted
# ============================================================================
#  CORPO A CORPO CONTEXTUAL
#
#  A tabela é deliberadamente declarativa: o resolvedor escolhe um ID a partir
#  de uma fotografia do input, e Player/MeleeController usam a MESMA ficha para
#  frame data, deslocamento, dano e apresentação. Isso evita quatro `if`s no
#  Player divergirem do que a hitbox faz no servidor.
#
#  Documento de projeto: docs/PLANO_COMBATE_CONTEXTUAL.md
# ============================================================================

## ============================================================================
##  COUNTER HIT (Fase 2 de docs/PLANO_COMBATE_CONTEXTUAL.md)
##
##  "acertar um inimigo em startup adiciona hitstun e knockback moderados, sem
##   subir o dano" — o plano é explícito quanto ao dano, e o motivo é de design:
##  o prêmio por ler o adversário é TEMPO (ele fica mais tempo parado e mais
##  longe), não um pico de dano que encurtaria a luta.
##
##  ⚠️ QUEM DECIDE É O SERVIDOR. A pergunta "o alvo estava em startup?" é feita
##  em `golpear`, que só roda no servidor — é lá que a `DamageZone` nasce. Um
##  cliente não pode declarar que acertou um counter.
##
##  ⚠️ E É PERGUNTADA ANTES DO DANO. Depois do `take_damage` o golpe do alvo já
##  foi interrompido e a resposta seria sempre falsa; por isso o
##  `DamageZone.antes_do_acerto` existe.
## ============================================================================
const COUNTER_HITSTUN := 1.55   # +55% de tempo parado
const COUNTER_KNOCKBACK := 0.45 # +45% de empurrão, somado ao que já foi aplicado

const ESPECIFICACOES := {
	"context_elbow": {
		"nome": "Cotovelada de Avanço",
		"pose": "context_elbow",
		"startup": 0.14, "ativo": 0.08, "recuperacao": 0.20,
		"dano": 60.0, "knockback": 16.0, "hitstun": 0.62,
		"alcance": 1.45, "raio": 1.32,
		"deslocamento": 1.00, "direcao": "frente",
		"vfx": "cotovelo",
	},
	# ⚠️ SUBSTITUI O QUARTO M1, e por isso é a única variação que não é "mais uma
	# opção": ela TROCA o finalizador de 112 por 72. O que se perde em dano se
	# ganha em rota — o alvo sobe e abre a perseguição aérea, que é o item
	# seguinte do plano. Um launcher que também desse 112 seria escolha óbvia
	# sempre, e o finalizador normal deixaria de existir.
	"context_launcher": {
		"nome": "Lançamento",
		"pose": "context_launcher",
		"startup": 0.18, "ativo": 0.09, "recuperacao": 0.26,
		"dano": 72.0, "knockback": 12.0, "hitstun": 0.70,
		"alcance": 1.40, "raio": 1.34,
		"deslocamento": 0.55, "direcao": "frente",
		"vfx": "cotovelo",
		"lanca": 15.0,
	},
	"context_retreat_kick": {
		"nome": "Chute Recuando",
		"pose": "context_retreat_kick",
		"startup": 0.15, "ativo": 0.08, "recuperacao": 0.23,
		"dano": 56.0, "knockback": 17.0, "hitstun": 0.60,
		"alcance": 1.55, "raio": 1.30,
		"deslocamento": 0.85, "direcao": "tras",
		"vfx": "recuo",
	},
	"context_side_hook_l": {
		"nome": "Esquiva Esquerda + Gancho",
		"pose": "context_side_hook_l",
		"startup": 0.16, "ativo": 0.08, "recuperacao": 0.24,
		"dano": 58.0, "knockback": 15.0, "hitstun": 0.61,
		"alcance": 1.40, "raio": 1.28,
		"deslocamento": 1.10, "direcao": "esquerda",
		"vfx": "esquiva_l",
	},
	"context_side_hook_r": {
		"nome": "Esquiva Direita + Gancho",
		"pose": "context_side_hook_r",
		"startup": 0.16, "ativo": 0.08, "recuperacao": 0.24,
		"dano": 58.0, "knockback": 15.0, "hitstun": 0.61,
		"alcance": 1.40, "raio": 1.28,
		"deslocamento": 1.10, "direcao": "direita",
		"vfx": "esquiva_r",
	},
}

# Contexto é uma fotografia, não uma segunda máquina de estados. `MeleeController`
# é o único dono do relógio; este arquivo só responde "qual ataque cabe?".
static func contexto_do_player(dono: Node, yaw: float) -> Dictionary:
	var frente := 0.0
	var lado := 0.0
	var quadro = dono.get("_quadro") if dono else null
	if quadro != null:
		frente = float(quadro.get("f"))
		lado = float(quadro.get("r"))
	# O clique pode chegar no mesmo quadro em que W/A/S/D foi pressionado. A
	# leitura direta fecha esse intervalo; o MoveFrame continua sendo a fonte
	# normal entre quadros e nos testes determinísticos.
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		frente = 1.0
	elif Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		frente = -1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		lado = 1.0
	elif Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		lado = -1.0
	var arma := str(dono.get("equipped_weapon")) if dono else ""
	var no_chao := false
	if dono and dono.has_method("is_on_floor"):
		no_chao = dono.call("is_on_floor")
	var corrida := Input.is_key_pressed(KEY_SHIFT) and (absf(frente) > 0.01 or absf(lado) > 0.01)
	var raca := ""
	var modelo = dono.get("_char_model") if dono else null
	if modelo is Node3D:
		raca = str((modelo as Node3D).get_meta("raca_id", ""))
	return {
		"grounded": no_chao,
		"sprinting": corrida,
		"weapon": arma,
		"input_forward": frente,
		"input_side": lado,
		"attack_yaw": yaw,
		"attack_basis": Basis(Vector3.UP, yaw),
		"race_id": raca,
		# Qual golpe do combo M1 sairia AGORA (0..3). O launcher só existe no
		# quarto, então o resolvedor precisa saber onde a sequência está.
		"combo_step": _passo_do_combo(dono),
	}


## O índice do próximo M1, lido do `MeleeController`. −1 quando não há combo em
## andamento ou o controlador não está acessível.
##
## ⚠️ É O PRÓXIMO, NÃO O EM CURSO. `_passo` é o que o `pedir()` vai usar; o
## `_passo_em_curso` é o que já está no ar. Ler o segundo faria o launcher sair
## um golpe atrasado.
static func _passo_do_combo(dono: Node) -> int:
	if dono == null:
		return -1
	var mc = dono.get("_melee")
	if mc == null:
		return -1
	var janela: float = float(mc.get("_janela"))
	# Janela vencida = a sequência recomeça do zero, e não há quarto golpe.
	if janela <= 0.0:
		return 0
	return int(mc.get("_passo"))

static func resolver(contexto: Dictionary) -> String:
	if not contexto.get("grounded", false):
		return ""
	if contexto.get("sprinting", false) or str(contexto.get("weapon", "")) != "":
		return ""
	# Lateral vence frente/ré se os dois vieram juntos: a leitura em tela fica
	# clara e coincide com a tabela de prioridade documentada.
	var lado := float(contexto.get("input_side", 0.0))
	if lado < -0.01:
		return "context_side_hook_l"
	if lado > 0.01:
		return "context_side_hook_r"
	var frente := float(contexto.get("input_forward", 0.0))
	if frente < -0.01:
		return "context_retreat_kick"
	if frente > 0.01:
		# No QUARTO golpe do combo (índice 3), W deixa de ser cotovelada e vira
		# lançamento — é a troca que o plano descreve. Nos três primeiros a
		# cotovelada continua valendo, senão o jogador perderia a variação de
		# avanço no meio da sequência.
		if int(contexto.get("combo_step", -1)) == 3:
			return "context_launcher"
		return "context_elbow"
	return ""

static func e_id_valido(id: String) -> bool:
	return ESPECIFICACOES.has(id)

static func especificacao(id: String) -> Dictionary:
	return ESPECIFICACOES.get(id, {})

static func duracao(id: String) -> float:
	var e := especificacao(id)
	return float(e.get("startup", 0.0)) + float(e.get("ativo", 0.0)) + float(e.get("recuperacao", 0.0))

static func startup(id: String) -> float:
	return float(especificacao(id).get("startup", 0.0))

static func ativo(id: String) -> float:
	return float(especificacao(id).get("ativo", 0.0))

static func recuperacao(id: String) -> float:
	return float(especificacao(id).get("recuperacao", 0.0))

static func fase(id: String, tempo: float) -> String:
	if not e_id_valido(id) or tempo >= duracao(id):
		return ""
	if tempo < startup(id):
		return "startup"
	if tempo < startup(id) + ativo(id):
		return "ativo"
	return "recuperacao"

# Retorna a velocidade física do root durante a parte explosiva. A distância
# declarada é dividida em 35% na antecipação e 65% na ação, garantindo que não
# exista um teleporte no primeiro quadro do impacto.
static func velocidade_de_deslocamento(id: String, tempo: float) -> float:
	var e := especificacao(id)
	if e.is_empty():
		return 0.0
	var distancia := float(e.get("deslocamento", 0.0))
	var su := startup(id)
	var at := ativo(id)
	if tempo < su and su > 0.0:
		return distancia * 0.35 / su
	if tempo < su + at and at > 0.0:
		return distancia * 0.65 / at
	return 0.0

static func direcao_de_deslocamento(id: String, fwd: Vector3) -> Vector3:
	var rumo := str(especificacao(id).get("direcao", "frente"))
	var frente := Vector3(fwd.x, 0.0, fwd.z).normalized()
	if frente.length_squared() < 0.001:
		frente = Vector3.FORWARD
	# Convenção do projeto: frente = -Z; frente × cima produz +X (direita).
	var direita := frente.cross(Vector3.UP).normalized()
	match rumo:
		"tras": return -frente
		"esquerda": return -direita
		"direita": return direita
		_: return frente

static func deslocamento_ate(id: String, tempo: float) -> float:
	# A mesma curva que alimenta o root motion local. O servidor usa este ponto
	# determinístico no nascimento da hitbox porque cópias remotas não executam
	# move_and_slide() no servidor; depender da posição atrasada do CharacterBody
	# faria o golpe nascer atrás de quem o jogador acabou de avançar.
	var e := especificacao(id)
	if e.is_empty() or tempo <= 0.0:
		return 0.0
	var distancia := float(e.get("deslocamento", 0.0))
	var su := startup(id)
	var at := ativo(id)
	if tempo < su and su > 0.0:
		return distancia * 0.35 * (tempo / su)
	if at > 0.0:
		return distancia * (0.35 + 0.65 * minf((tempo - su) / at, 1.0))
	return distancia

# Cria a hitbox no SERVIDOR. A origem foi validada pelo Player e a posição no
# instante ativo é reconstruída pela mesma curva do root motion. `sequencia` +
# `token` tornam o SceneTreeTimer cancelável: qualquer dano, dash-cancel ou
# respawn invalida o token antes de ele poder criar uma zona tardia.
static func golpear(mundo: Node, caster: Node3D, id: String, origem: Vector3, fwd: Vector3,
		sequencia: int = -1, token: int = 0) -> void:
	if mundo == null or caster == null or not e_id_valido(id):
		return
	var e := especificacao(id)
	var frente := Vector3(fwd.x, 0.0, fwd.z).normalized()
	if frente.length_squared() < 0.001:
		return
	var escala := caster.scale.y if "scale" in caster else 1.0
	var rumo := direcao_de_deslocamento(id, frente)
	var ponto_ativo := origem + rumo * deslocamento_ate(id, startup(id))
	var timer := mundo.get_tree().create_timer(startup(id))
	timer.timeout.connect(func():
		if not is_instance_valid(mundo) or not is_instance_valid(caster):
			return
		if caster.has_method("_contextual_servidor_pode_gerar_zona") \
			and not caster.call("_contextual_servidor_pode_gerar_zona", sequencia, token):
			return
		var zona := DamageZone.new()
		zona.name = "ContextualMelee_" + id
		mundo.add_child(zona)
		zona.global_position = ponto_ativo + frente * float(e["alcance"]) * escala
		zona.override_kb_dir = frente
		# COUNTER HIT: quem estava em startup no instante do impacto é anotado
		# ANTES de o dano correr, e recebe o bônus logo depois. Duas etapas
		# porque o hitstun do golpe normal precisa ter sido aplicado primeiro —
		# o bônus o substitui, em vez de ser sobrescrito por ele.
		var em_startup: Dictionary = {}
		zona.antes_do_acerto.connect(func(alvo):
			if alvo != null and is_instance_valid(alvo) \
					and alvo.has_method("em_startup_de_ataque") \
					and alvo.call("em_startup_de_ataque"):
				em_startup[alvo.get_instance_id()] = true)
		zona.hit_landed.connect(func(alvo):
			if alvo != null and is_instance_valid(alvo) \
					and em_startup.get(alvo.get_instance_id(), false):
				_aplicar_counter(alvo, caster, e, frente, escala)
			if float(e.get("lanca", 0.0)) > 0.0:
				_aplicar_lancamento(alvo, caster, e, escala)
			if is_instance_valid(caster):
				if caster.has_method("_confirmar_acerto_contextual_servidor"):
					caster.call("_confirmar_acerto_contextual_servidor", sequencia)
				elif "hit_confirmed" in caster:
					caster.hit_confirmed = true)
		zona.setup(float(e["dano"]) * escala, float(e["knockback"]) * escala,
			Vector3.ZERO, ativo(id), caster, float(e["raio"]) * escala, null, float(e["hitstun"]))
	)


## O bônus do counter, aplicado DEPOIS do dano normal.
##
## `dano 0.0` de propósito: o plano manda não subir o dano, e o projeto já usa
## dano zero para "empurrão e hitstun sem machucar" — está escrito no cabeçalho
## do `CombatResolver` ("Empurrão, hitstun e crédito de kill são mecânicas
## SEPARADAS do dano"). O hitstun vai como TOTAL, porque `RecepcaoDeDano` fixa a
## duração em vez de somar; o knockback vai como o EXTRA, porque ele soma na
## velocidade do corpo.
static func _aplicar_counter(alvo: Node, caster: Node3D, e: Dictionary,
		frente: Vector3, escala: float) -> void:
	if not alvo.has_method("take_damage"):
		return
	var kb_extra: Vector3 = frente * float(e["knockback"]) * escala * COUNTER_KNOCKBACK
	var hitstun_total: float = float(e["hitstun"]) * COUNTER_HITSTUN
	var origem: Vector3 = caster.global_position if is_instance_valid(caster) else alvo.global_position
	alvo.take_damage(0.0, origem, kb_extra, hitstun_total)
	if alvo.has_method("set_meta"):
		# Marca para quem apresenta: o VFX de counter é outro assunto, e lê isto.
		alvo.set_meta("counter_hit_em", Time.get_ticks_msec())


## ============================================================================
##  LANÇAMENTO (Fase 3 de docs/PLANO_COMBATE_CONTEXTUAL.md)
##
##  "Launcher + uma perseguição aérea: troca o quarto M1 por lançamento com W;
##   só uma continuação aérea por alvo, com bloqueios contra loop infinito."
##
##  ⚠️ O BLOQUEIO É O REQUISITO, NÃO UM DETALHE. Sem ele, lançar → perseguir →
##  lançar de novo prende o alvo no ar indefinidamente, e quem começou a troca
##  ganha a luta sem o outro jogar. A regra: um corpo que JÁ ESTÁ no ar por
##  lançamento não pode ser lançado outra vez — a marca só é limpa quando ele
##  volta a tocar o chão.
## ============================================================================

## Enquanto esta marca existir, o alvo não pode ser lançado de novo.
const META_LANCADO := "lancado_no_ar"
## E esta diz que ele ainda tem UMA perseguição aérea disponível.
const META_PERSEGUICAO := "perseguicao_livre"


static func _aplicar_lancamento(alvo: Node, caster: Node3D, e: Dictionary,
		escala: float) -> void:
	if alvo == null or not is_instance_valid(alvo) or not alvo.has_method("take_damage"):
		return
	if ja_esta_lancado(alvo):
		return              # sem relançar: é o bloqueio contra o loop infinito

	var forca: float = float(e["lanca"]) * escala
	var origem: Vector3 = caster.global_position if is_instance_valid(caster) else alvo.global_position
	# ⚠️ Dano 0: o dano do golpe já foi aplicado pela própria zona. Aqui só o
	# impulso, pelo mesmo caminho que o counter usa.
	alvo.take_damage(0.0, origem, Vector3.UP * forca, float(e["hitstun"]))
	alvo.set_meta(META_LANCADO, true)
	alvo.set_meta(META_PERSEGUICAO, true)


## true enquanto o alvo estiver no ar por um lançamento. A marca se limpa
## sozinha quando ele volta ao chão — assim ninguém precisa lembrar de apagá-la,
## e um alvo que caiu pode ser lançado de novo numa troca posterior.
static func ja_esta_lancado(alvo: Node) -> bool:
	if alvo == null or not is_instance_valid(alvo):
		return false
	if not alvo.has_meta(META_LANCADO):
		return false
	if alvo.has_method("is_on_floor") and alvo.call("is_on_floor"):
		alvo.remove_meta(META_LANCADO)
		if alvo.has_meta(META_PERSEGUICAO):
			alvo.remove_meta(META_PERSEGUICAO)
		return false
	return true


## Consome a única perseguição aérea daquele alvo. Devolve false quando ela já
## foi usada — é o que impede a segunda continuação no mesmo lançamento.
static func consumir_perseguicao(alvo: Node) -> bool:
	if alvo == null or not is_instance_valid(alvo) or not alvo.has_meta(META_PERSEGUICAO):
		return false
	alvo.remove_meta(META_PERSEGUICAO)
	return true
