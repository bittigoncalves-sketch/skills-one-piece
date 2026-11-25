extends SceneTree
# ============================================================================
#  A TRAVA APÓS ATAQUE DE FRUTA (desligada em 2026-09-13), e a Mera sem carga.
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


## 2. A TRAVA. Desligada pelo dono em 2026-09-13 (TRAVA_POS_FRUTA = 0; "vai ser
## refeita de outra forma"). Verifica as duas coisas: desligada, nenhum ataque a
## arma e a recarga corre; e o MECANISMO continua funcionando se for armado, para
## quem religar não descobrir tarde que a pausa quebrou.
func _a_trava(p: Node3D) -> void:
	print("\n=== 2. a trava pós-fruta (desligada) ===")
	_ok("a trava está desligada (0 s)", absf(p.TRAVA_POS_FRUTA) < 0.001)

	p.combat_mode = "fruit"
	p.current_fruit_id = "mera_mera"
	p._trava_pos_fruta = 0.0
	for k in p._fruit_cooldowns.keys():
		p._fruit_cooldowns[k] = 0.0

	# Desligada: um ataque de fruta NÃO arma a trava e a recarga anda.
	p.trigger_skill_cooldown("Z")
	await _quadros(2)
	print("   depois de um ataque: trava %.1f s | recarga do Z %.1f s"
		% [p._trava_pos_fruta, p._fruit_cooldowns["Z"]])
	_ok("usar um ataque de fruta NÃO arma trava nenhuma", p._trava_pos_fruta <= 0.0)
	_ok("a recarga do slot começou", p._fruit_cooldowns["Z"] > 0.0)
	var cd0: float = p._fruit_cooldowns["Z"]
	await _quadros(90)
	_ok("sem trava, a recarga corre desde o primeiro instante", p._fruit_cooldowns["Z"] < cd0)

	# ⚠️ O MECANISMO, armado à mão: bloqueia a recarga enquanto corre.
	p._trava_pos_fruta = 5.0
	var cd_antes: float = p._fruit_cooldowns["Z"]
	var trava_antes: float = p._trava_pos_fruta
	# Quadros de PROCESSO não são ticks de física; 90 dão margem para a mudança.
	await _quadros(90)
	print("   armada à mão, 90 quadros: trava %.1f -> %.1f | recarga %.1f -> %.1f"
		% [trava_antes, p._trava_pos_fruta, cd_antes, p._fruit_cooldowns["Z"]])
	_ok("mecanismo preservado: a TRAVA anda", p._trava_pos_fruta < trava_antes)
	_ok("mecanismo preservado: a RECARGA fica parada", absf(p._fruit_cooldowns["Z"] - cd_antes) < 0.01)

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
