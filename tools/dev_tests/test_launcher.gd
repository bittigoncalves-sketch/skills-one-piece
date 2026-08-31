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
	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## 1. QUANDO o launcher sai. Só no quarto golpe, e só com W.
func _a_regra_de_escolha() -> void:
	print("=== 1. a escolha ===")
	for passo in [0, 1, 2]:
		_ok("passo %d + W ainda é a cotovelada" % passo,
			ContextualMelee.resolver(_ctx(1.0, 0.0, passo)) == "context_elbow")
	_ok("passo 3 + W vira o LANÇAMENTO",
		ContextualMelee.resolver(_ctx(1.0, 0.0, 3)) == "context_launcher")
	# As outras direções não podem ser afetadas pelo passo do combo.
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
