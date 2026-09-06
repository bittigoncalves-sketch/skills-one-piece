extends "res://src/tests/BaseTest.gd"
# ============================================================================
#  OS TRÊS MODOS DE COMBATE — teclas 1, 2 e 3 (pedido do dono, 2026-09-06)
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_modos_de_combate.gd
#
#  Era um PAR alternado no R ("fruit" <-> "style"). Virou seleção direta de três:
#
#      1 -> fruit   Akuma no Mi
#      2 -> style   estilo de luta
#      3 -> sword   a Yoru na mão
#
#  Escolher QUAL fruta / QUAL estilo continua no menu do M.
#
#  O QUE CADA CHECAGEM DEFENDE:
#    1. os três modos existem e trocam;
#    2. entrar no 3 SACA a espada e sair dele a GUARDA — a espada é o único
#       modo com presença física, e sobrar Yoru na mão no modo fruta seria o
#       tipo de estado meio-trocado que ninguém percebe até bater;
#    3. no modo espada os slots Z/X/C/V ficam MUDOS. Todo consumidor de
#       `combat_mode` no Player é um `if == "style" ... else`, então sem portão
#       o terceiro valor cairia no ramo da FRUTA e o jogador conjuraria a Akuma
#       no Mi de espada na mão;
#    4. soltar uma carga continua passando mesmo no modo espada — barrar a
#       soltura deixaria a carga presa para sempre;
#    5. escolher um estilo no menu do M guarda a espada, porque passa pelo
#       mesmo caminho do 2.
# ============================================================================

var _pronto := false

func preparar() -> void:
	player.equipped_weapon = ""
	player.current_fruit_id = "pika_pika"

func is_test_done() -> bool:
	return _pronto

func _espada_na_mao() -> bool:
	var mao = player.get("_rig").item_handle
	return mao != null and mao.get_node_or_null("Yoru") != null

func test_step(f: int, _d: float) -> void:
	if f != 40:
		return

	# ------------------------------------------------------ 1. os três modos
	player.set_combat_mode("fruit")
	ok(player.combat_mode == "fruit", "1 = fruta (modo %s)" % player.combat_mode)
	ok(not _espada_na_mao(), "no modo fruta a espada NÃO está na mão")

	player.set_combat_mode("style")
	ok(player.combat_mode == "style", "2 = estilo (modo %s)" % player.combat_mode)

	# ------------------------------------------- 2. o 3 saca / sair guarda
	player.set_combat_mode("sword")
	ok(player.combat_mode == "sword", "3 = espada (modo %s)" % player.combat_mode)
	ok(_espada_na_mao(), "entrar no modo 3 SACOU a Yoru")

	# ------------------------------------------ 3. os slots ficam mudos
	ok(not player.pode_conjurar(), "no modo espada `pode_conjurar` é falso")
	var antes_z: float = player._fruit_cooldowns["Z"]
	player.cast_skill_slot("Z")
	player._request_cast("X")
	player.begin_charge("C")
	ok(player._fruit_cooldowns["Z"] == antes_z,
		"pedir Z de espada na mão não conjura nada (recarga %.2f)" % player._fruit_cooldowns["Z"])
	ok(not bool(player.get_meta("pika_c_active", false)),
		"nem o C sustentado da Pika dispara no modo espada")

	# --------------------------- 4. mas SOLTAR continua passando
	# Se o jogador trocar para espada com uma carga em curso, é o `soltar` que a
	# encerra; barrá-lo prenderia a carga para sempre.
	player.release_charge("C")
	ok(not bool(player.get("_charging")),
		"soltar uma carga funciona mesmo no modo espada")

	# ------------------------------------------ 2b. sair do 3 guarda
	player.set_combat_mode("fruit")
	ok(not _espada_na_mao(), "sair do modo 3 GUARDOU a Yoru")
	ok(player.pode_conjurar(), "e os slots voltaram a responder")

	# ------------------------- 5. o menu do M guarda a espada junto
	player.set_combat_mode("sword")
	ok(_espada_na_mao(), "de volta ao modo espada para o próximo caso")
	player.set_fighting_style("boxe")
	ok(player.combat_mode == "style",
		"escolher um estilo no menu do M vale como apertar o 2 (modo %s)" % player.combat_mode)
	ok(not _espada_na_mao(),
		"e guarda a Yoru — sem isso sobraria espada na mão com a barra de estilo")

	# ------------------------------------------------ modo inválido é ignorado
	player.set_combat_mode("banana")
	ok(player.combat_mode == "style", "modo desconhecido não troca nada")

	_pronto = true
