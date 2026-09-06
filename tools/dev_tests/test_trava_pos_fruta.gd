extends SceneTree
# ============================================================================
#  A TRAVA DE 5 SEGUNDOS APÓS QUALQUER ATAQUE DE FRUTA, e a Mera sem carga.
#
#  Pedidos do dono (2026-09-01):
#    • "elimina a necessidade de tempo para desferir ataques de frutas na Mera";
#    • "após o uso de qualquer ataque de fruta, um contador de 5 s; durante ele
#       o usuário não consegue usar os poderes, e a recarga das frutas é PAUSADA".
#
#  ⚠️ O ITEM QUE MAIS FALHA EM SILÊNCIO É A PAUSA. Se a trava contasse JUNTO com
#  as recargas, ela seria invisível em toda skill de recarga maior que 5 s — que
#  é quase todas — e o jogo pareceria idêntico ao de antes. Por isso aqui se mede
#  a recarga ANTES e DEPOIS de o tempo passar.
#
#      DISPLAY=:1 godot --path . -s tools/dev_tests/test_trava_pos_fruta.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	p.set_meta("damage_immune", true)

	_a_mera_sem_carga()
	await _a_trava(p)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## 1. A MERA NÃO CARREGA MAIS — nenhum dos quatro slots.
func _a_mera_sem_carga() -> void:
	print("=== 1. a Mera dispara no toque ===")
	# ⚠️ `load()` EM VEZ DO class_name GLOBAL: citar `CastController` aqui força o
	# GDScript a resolver a classe na COMPILAÇÃO deste script — que roda antes de
	# o projeto subir — e nesse caminho as constantes `preload` do Player.gd saem
	# nulas, deixando todos os controladores nulos e o jogador sem ticar.
	var carregaveis: Dictionary = load("res://src/player/cast_controller.gd").CARREGAVEIS
	_ok("a Mera saiu da lista de carregáveis", not carregaveis.has("mera_mera"))
	# ⚠️ CONTROLE: as outras frutas carregáveis continuam carregando. Sem ele,
	# esvaziar a lista inteira passaria como acerto.
	_ok("a Gura continua com o X carregável",
		carregaveis.has("gura_gura") and "X" in carregaveis["gura_gura"])
	_ok("a Goro continua com o V carregável",
		carregaveis.has("goro_goro") and "V" in carregaveis["goro_goro"])
	_ok("a Bomu continua com Z e X carregáveis",
		carregaveis.has("bomu_bomu") and carregaveis["bomu_bomu"].size() == 2)


## 2. A TRAVA: bloqueia os poderes e PAUSA as recargas.
func _a_trava(p: Node3D) -> void:
	print("\n=== 2. a trava de 5 s ===")
	_ok("a trava dura 5 s", absf(p.TRAVA_POS_FRUTA - 5.0) < 0.01)

	p.combat_mode = "fruit"
	p.current_fruit_id = "mera_mera"
	p._trava_pos_fruta = 0.0
	for k in p._fruit_cooldowns.keys():
		p._fruit_cooldowns[k] = 0.0

	# Um ataque de fruta arma a trava.
	p.trigger_skill_cooldown("Z")
	await _quadros(2)
	print("   depois de um ataque: trava %.1f s | recarga do Z %.1f s"
		% [p._trava_pos_fruta, p._fruit_cooldowns["Z"]])
	_ok("usar um ataque de fruta ARMA a trava", p._trava_pos_fruta > 4.0)
	_ok("e a recarga do slot também começou", p._fruit_cooldowns["Z"] > 0.0)

	# ⚠️ A PAUSA. Meia dúzia de quadros depois, a recarga NÃO pode ter andado.
	var cd_antes: float = p._fruit_cooldowns["Z"]
	var trava_antes: float = p._trava_pos_fruta
	# ⚠️ QUADROS DE PROCESSO NÃO SÃO TICKS DE FÍSICA. O decremento roda no
	# `_physics_process`, e 40 quadros de processo renderam menos de meio
	# segundo de física — pouco para a diferença aparecer com uma casa decimal.
	# 90 dão margem folgada, e o que importa aqui é a DIREÇÃO da mudança.
	await _quadros(90)
	print("   90 quadros depois: trava %.1f -> %.1f | recarga %.1f -> %.1f"
		% [trava_antes, p._trava_pos_fruta, cd_antes, p._fruit_cooldowns["Z"]])
	_ok("a TRAVA anda", p._trava_pos_fruta < trava_antes)
	_ok("mas a RECARGA fica parada", absf(p._fruit_cooldowns["Z"] - cd_antes) < 0.01)

	# ⚠️ CONTROLE DA PAUSA: com a trava vencida, a recarga volta a andar. Sem
	# isto, uma recarga QUEBRADA (que nunca anda) passaria como "pausada".
	p._trava_pos_fruta = 0.0
	var cd2: float = p._fruit_cooldowns["Z"]
	await _quadros(90)
	print("   sem a trava: recarga %.1f -> %.1f" % [cd2, p._fruit_cooldowns["Z"]])
	_ok("passada a trava, a recarga volta a correr",
		p._fruit_cooldowns["Z"] < cd2)

	for k in p._fruit_cooldowns.keys():
		p._fruit_cooldowns[k] = 0.0
	p._trava_pos_fruta = 0.0


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
