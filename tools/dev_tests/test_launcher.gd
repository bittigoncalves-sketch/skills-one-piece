extends SceneTree
# ============================================================================
#  LANÇAMENTO — Fase 3 de docs/PLANO_COMBATE_CONTEXTUAL.md
#
#  "Launcher + uma perseguição aérea: troca o quarto M1 por lançamento com W;
#   só uma continuação aérea por alvo, com bloqueios contra loop infinito."
#
#  ⚠️ O BLOQUEIO É O ITEM MAIS IMPORTANTE DAQUI. Um launcher que funciona e não
#  bloqueia é PIOR que nenhum launcher: lançar → perseguir → lançar prende o
#  alvo no ar e decide a luta sem o outro jogar. Por isso metade deste arquivo
#  mede o que NÃO pode acontecer.
#
#    DISPLAY=:1 godot --path . -s tools/dev_tests/test_launcher.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	_a_regra_de_escolha()
	await _o_impulso()
	await _a_perseguicao()
	await _o_chute_de_parede()
	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## 1. QUANDO o launcher sai. Só no quarto golpe, e só com W.
func _a_regra_de_escolha() -> void:
	print("=== 1. a escolha ===")
	# ⚠️ A REGRA MUDOU EM 2026-09-01. Antes, W dava cotovelada em qualquer passo
	# do combo — e era esse o defeito que o dono relatou: segurar W repetia a
	# mesma cotovelada para sempre. Agora a variação só ABRE a sequência; do
	# passo 1 em diante o clique pertence ao combo M1.
	_ok("passo 0 + W abre com a cotovelada",
		ContextualMelee.resolver(_ctx(1.0, 0.0, 0)) == "context_elbow")
	for passo in [1, 2]:
		_ok("passo %d + W já é combo M1, não cotovelada" % passo,
			ContextualMelee.resolver(_ctx(1.0, 0.0, passo)) == "")
	_ok("passo 3 + W vira o LANÇAMENTO",
		ContextualMelee.resolver(_ctx(1.0, 0.0, 3)) == "context_launcher")
	# As outras direções não podem ser afetadas pelo passo do combo.
	# No quarto golpe as outras direções continuam valendo: o passo 3 é a
	# exceção que existe para o lançamento, e ela não fecha S/A/D.
	_ok("passo 3 + S continua o chute recuando",
		ContextualMelee.resolver(_ctx(-1.0, 0.0, 3)) == "context_retreat_kick")
	_ok("passo 3 + A continua o gancho lateral",
		ContextualMelee.resolver(_ctx(0.0, -1.0, 3)) == "context_side_hook_l")
	# ⚠️ CONTROLE: sem W não há launcher, por mais avançado que o combo esteja.
	_ok("passo 3 SEM direção não vira lançamento (é o M1 normal)",
		ContextualMelee.resolver(_ctx(0.0, 0.0, 3)) == "")

	var e: Dictionary = ContextualMelee.especificacao("context_launcher")
	print("   dano do lançamento: %.0f (o finalizador M1 dá 112)" % float(e["dano"]))
	_ok("o lançamento dá MENOS que o finalizador que ele substitui",
		float(e["dano"]) < 112.0)
	_ok("o lançamento declara força vertical", float(e.get("lanca", 0.0)) > 0.0)


## 2. O IMPULSO e o bloqueio.
func _o_impulso() -> void:
	print("\n=== 2. o impulso e o bloqueio contra loop ===")
	var alvo := AlvoNoAr.new()
	get_root().add_child(alvo)
	var e: Dictionary = ContextualMelee.especificacao("context_launcher")

	ContextualMelee._aplicar_lancamento(alvo, alvo, e, 1.0)
	await process_frame
	_ok("o lançamento chamou take_damage", alvo.chamadas.size() == 1)
	if alvo.chamadas.is_empty():
		return
	var c: Dictionary = alvo.chamadas[0]
	var kb: Vector3 = c["kb"]
	print("   knockback aplicado: %s (dano %.0f)" % [str(kb), float(c["dano"])])
	_ok("o impulso é PARA CIMA", kb.y > 5.0)
	_ok("o impulso é vertical, não horizontal", Vector2(kb.x, kb.z).length() < 0.01)
	_ok("o lançamento não soma dano (já veio da zona)", absf(float(c["dano"])) < 0.01)
	_ok("o alvo fica marcado como lançado", ContextualMelee.ja_esta_lancado(alvo))

	# ⚠️ O BLOQUEIO. Segunda tentativa no mesmo alvo, ainda no ar.
	ContextualMelee._aplicar_lancamento(alvo, alvo, e, 1.0)
	await process_frame
	_ok("um alvo JÁ no ar NÃO é lançado de novo (sem loop infinito)",
		alvo.chamadas.size() == 1)

	# A perseguição é uma só.
	_ok("a primeira perseguição é liberada", ContextualMelee.consumir_perseguicao(alvo))
	_ok("a segunda perseguição é RECUSADA", not ContextualMelee.consumir_perseguicao(alvo))

	# E ao tocar o chão tudo se limpa sozinho — senão o alvo ficaria imune a
	# lançamentos pelo resto da partida.
	alvo.no_chao = true
	_ok("tocar o chão limpa a marca", not ContextualMelee.ja_esta_lancado(alvo))
	ContextualMelee._aplicar_lancamento(alvo, alvo, e, 1.0)
	await process_frame
	_ok("depois de aterrissar, pode ser lançado de novo", alvo.chamadas.size() == 2)
	alvo.queue_free()


## 3. A PERSEGUIÇÃO AÉREA — "só uma continuação aérea por alvo".
##
## O segundo chute no mesmo lançamento ACERTA (dano, empurrão, hitstun), mas não
## SUSTENTA: o alvo cai. É o que quebra o loop sem tirar do jogador a
## possibilidade de encostar no adversário.
func _a_perseguicao() -> void:
	print("\n=== 3. a perseguição aérea ===")
	var e: Dictionary = ContextualMelee.especificacao("context_air_kick")
	_ok("o chute aéreo declara sustento", float(e.get("sustenta", 0.0)) > 0.0)
	print("   dano %.0f | sustento %.1f" % [float(e["dano"]), float(e.get("sustenta", 0.0))])

	var alvo := AlvoNoAr.new()
	get_root().add_child(alvo)

	# ⚠️ CONTROLE PRIMEIRO: quem NUNCA foi lançado não sustenta. O chute aéreo é
	# um golpe comum contra quem está no ar por conta própria.
	ContextualMelee._aplicar_sustento(alvo, alvo, e, 1.0)
	await process_frame
	_ok("alvo nunca lançado NÃO é sustentado", alvo.chamadas.is_empty())

	# Agora lança e persegue.
	var lanc: Dictionary = ContextualMelee.especificacao("context_launcher")
	ContextualMelee._aplicar_lancamento(alvo, alvo, lanc, 1.0)
	await process_frame
	var apos_lanc := alvo.chamadas.size()

	ContextualMelee._aplicar_sustento(alvo, alvo, e, 1.0)
	await process_frame
	_ok("a PRIMEIRA perseguição sustenta", alvo.chamadas.size() == apos_lanc + 1)
	if alvo.chamadas.size() > apos_lanc:
		var kb: Vector3 = alvo.chamadas[apos_lanc]["kb"]
		_ok("o sustento empurra para CIMA", kb.y > 1.0)

	ContextualMelee._aplicar_sustento(alvo, alvo, e, 1.0)
	await process_frame
	_ok("a SEGUNDA perseguição NÃO sustenta (o alvo cai)",
		alvo.chamadas.size() == apos_lanc + 1)
	alvo.queue_free()


## 4. O CHUTE DE PAREDE — Fase 5 do plano.
func _o_chute_de_parede() -> void:
	print("\n=== 4. o chute de parede ===")
	var e: Dictionary = ContextualMelee.especificacao("context_wall_kick")
	print("   dano %.0f | deslocamento %.2f (o maior das variações)"
		% [float(e["dano"]), float(e["deslocamento"])])
	_ok("o chute de parede desloca mais que o aéreo comum",
		float(e["deslocamento"]) > float(ContextualMelee.especificacao("context_air_kick")["deslocamento"]))

	var com_parede := _ctx_ar(Vector3(1, 0, 0), false)
	_ok("no ar COM parede sai o chute de parede",
		ContextualMelee.resolver(com_parede) == "context_wall_kick")
	_ok("no ar SEM parede sai o chute aéreo comum",
		ContextualMelee.resolver(_ctx_ar(Vector3.ZERO, false)) == "context_air_kick")
	# ⚠️ UM POR CONTATO: gasto, volta a ser o chute aéreo comum.
	_ok("gasto o chute de parede, volta ao chute aéreo",
		ContextualMelee.resolver(_ctx_ar(Vector3(1, 0, 0), true)) == "context_air_kick")
	# ⚠️ E NO CHÃO A PAREDE NÃO VALE: lá quem manda são as variações de solo.
	var no_chao := _ctx(1.0, 0.0, 0)
	no_chao["wall_normal"] = Vector3(1, 0, 0)
	_ok("no CHÃO a parede não sequestra a cotovelada",
		ContextualMelee.resolver(no_chao) == "context_elbow")

	# A validação da normal: chão e teto não podem contar como parede.
	print("   limiar de normal: |n.y| < %.2f" % ContextualMelee.LIMIAR_NORMAL_PAREDE)
	_ok("o limiar recusa piso e teto (normal vertical)",
		ContextualMelee.LIMIAR_NORMAL_PAREDE < 0.5)

	# ⚠️ A EXIGÊNCIA DE CHÃO É POR GOLPE. Sem isto o servidor rejeitaria as duas
	# variações aéreas em partida com rede — e elas passariam no singleplayer,
	# onde o cliente é o servidor. Bug que só aparece com duas máquinas.
	print("\n   exige chão?")
	for id in ["context_elbow", "context_retreat_kick", "context_side_hook_l",
			"context_launcher"]:
		_ok("   %s exige chão" % id, ContextualMelee.exige_chao(id))
	for id in ["context_air_kick", "context_wall_kick"]:
		_ok("   %s NÃO exige chão" % id, not ContextualMelee.exige_chao(id))


func _ctx_ar(normal: Vector3, gasto: bool) -> Dictionary:
	return {
		"grounded": false, "sprinting": false, "weapon": "",
		"input_forward": 0.0, "input_side": 0.0,
		"attack_yaw": 0.0, "attack_basis": Basis.IDENTITY,
		"race_id": "", "combo_step": 0,
		"wall_normal": normal, "wall_kick_gasto": gasto,
	}


func _ctx(frente: float, lado: float, passo: int) -> Dictionary:
	return {
		"grounded": true, "sprinting": false, "weapon": "",
		"input_forward": frente, "input_side": lado,
		"attack_yaw": 0.0, "attack_basis": Basis.IDENTITY,
		"race_id": "", "combo_step": passo,
	}


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


## Alvo que anota o que recebe e finge estar no ar ou no chão sob comando.
##
## ⚠️ `Node3D`, e não `CharacterBody3D`: o Godot recusa sobrescrever o
## `is_on_floor()` nativo ("won't be called by the engine"), e aqui o alvo
## PRECISA mentir sobre estar no chão para que a limpeza da marca seja
## verificável. Este teste não usa a Area3D, então não há o que perder.
class AlvoNoAr extends Node3D:
	var chamadas: Array = []
	var no_chao := false

	func take_damage(amount: float, origem: Vector3 = Vector3.ZERO,
			kb: Vector3 = Vector3.ZERO, hitstun: float = 0.3) -> void:
		chamadas.append({"dano": amount, "origem": origem, "kb": kb, "hitstun": hitstun})

	func is_on_floor() -> bool:
		return no_chao
