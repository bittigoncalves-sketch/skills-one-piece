extends SceneTree
## ============================================================================
##  BUKI BUKI — PROVA DA MUNIÇÃO (regra nova do dono, 2026-08-11)
##
##  A auditoria das frutas (test_frutas.gd) só mede "o slot cria DamageZone e
##  não vaza nó". Isso não vê NADA da mecânica nova. O que este teste prova, e
##  que nenhum outro cobre:
##
##    1. a munição DECREMENTA a cada disparo — e o SAQUE NÃO GASTA BALA
##       (regra trocada pelo dono em 2026-08-11: sacar não atira mais, a arma
##       sai CHEIA e o primeiro tiro é do botão esquerdo). Este teste afirmava o
##       contrário — "12 = 1 no saque + 11 no clique" — e por isso passou a
##       falhar sozinho quando a regra mudou;
##    2. a arma SOME quando a munição zera;
##    3. o slot largado ENTRA EM RECARGA — por troca, por desistência e por
##       munição zerada (as três portas de saída);
##    4. TROCAR DE SKILL tira a arma da mão e põe a outra;
##    5. o SERVIDOR não deixa atirar sem bala (nenhuma DamageZone nasce);
##    6. o corpo some/volta na transformação do canhão (X).
##
##  Sobe o jogo de verdade (GameFlow), como o test_frutas — a máquina de estado
##  mora no Player e precisa de câmera, rig e árvore de cena.
##
##  Uso: godot --headless --path . --script tools/dev_tests/test_buki_buki.gd
## ============================================================================

var _p: Node = null
var _falhas := 0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(3.0)

	_p = _local()
	if _p == null:
		print("❌ não achei o jogador — a cena não subiu")
		quit(1)
		return

	_p.combat_mode = "fruit"
	_p.equip_fruit("buki_buki")
	_zerar_recargas()
	await _esperar(0.3)

	print("\n╔══════════════════════════════════════════════════════════╗")
	print("║  BUKI BUKI — MUNIÇÃO, TROCA E RECARGA                    ║")
	print("╚══════════════════════════════════════════════════════════╝")

	await _saque()
	await _decremento()
	await _troca_de_arma()
	await _municao_zerada()
	await _servidor_sem_bala()

	print("\n==========================================")
	if _falhas == 0:
		print("✅ BUKI BUKI OK — munição, troca e recarga")
	else:
		print("❌ %d falha(s)" % _falhas)
	quit(1 if _falhas > 0 else 0)

# ---------------------------------------------------------------- 1. o saque
func _saque() -> void:
	print("\n-- 1. sacar a arma (Z = pistola, 12 balas) --")
	_p.begin_charge("Z")
	await _esperar(0.4)
	_ok(_p.buki_arma() == "Z", "a arma FICA na mão depois do saque (arma='%s')" % _p.buki_arma())
	# REGRA NOVA (2026-08-11): sacar NÃO atira -> a pistola sai com as 12 balas.
	_ok(_p.buki_municao() == 12, "munição do dono = 12 de 12 (o saque não gasta bala) — deu %d" % _p.buki_municao())
	_ok(int(_p.get("_srv_buki_municao")) == 12,
		"o SERVIDOR carregou o mesmo número (%d)" % int(_p.get("_srv_buki_municao")))
	_ok(str(_p.get("_srv_buki_arma")) == "Z",
		"o SERVIDOR sabe QUAL arma está na mão (='%s') — sem isso ele recusa todo tiro"
		% str(_p.get("_srv_buki_arma")))
	_ok(_visivel("Z"), "a pistola está visível no rig")
	_ok(float(_p._skill_cooldowns["Z"]) == 0.0,
		"o slot empunhado NÃO está em recarga (recarga é do slot LARGADO) — %.1fs" % float(_p._skill_cooldowns["Z"]))

# ---------------------------------------------------------- 2. cada tiro conta
func _decremento() -> void:
	print("\n-- 2. cada disparo gasta uma bala --")
	var antes: int = _p.buki_municao()
	for i in 3:
		_p._buki.atirar()
		await process_frame
	_ok(_p.buki_municao() == antes - 3,
		"3 disparos = 3 balas a menos (%d -> %d)" % [antes, _p.buki_municao()])
	_ok(int(_p.get("_srv_buki_municao")) == antes - 3,
		"o contador do SERVIDOR acompanhou (%d)" % int(_p.get("_srv_buki_municao")))

# ------------------------------------------------------- 3/4. trocar de skill
func _troca_de_arma() -> void:
	print("\n-- 3. trocar de skill: perde a arma e o slot largado esfria --")
	_p.begin_charge("X")
	await _esperar(0.4)
	_ok(_p.buki_arma() == "X", "agora empunha o canhão (arma='%s')" % _p.buki_arma())
	_ok(not _visivel("Z"), "a pistola SUMIU da mão")
	_ok(_visivel("X"), "o canhão apareceu")
	_ok(float(_p._skill_cooldowns["Z"]) > 0.0,
		"o slot Z abandonado entrou em RECARGA (%.1fs)" % float(_p._skill_cooldowns["Z"]))
	_ok(_p.buki_municao() == 3, "canhão nasce CHEIO: 3 tiros (deu %d)" % _p.buki_municao())
	# X = o jogador vira o canhão INTEIRO: o corpo tem que sumir.
	_ok(_p.get("_char_model") != null and not (_p.get("_char_model") as Node3D).visible,
		"no canhão (X) o CORPO some — a transformação é do jogador inteiro")

# ------------------------------------------------ 5. munição zerada = larga
func _municao_zerada() -> void:
	print("\n-- 4. acabar a munição derruba a arma e esfria o slot --")
	# 3 balas no canhão: as duas primeiras não largam a arma, a terceira sim.
	_p._buki.atirar()
	await process_frame
	_p._buki.atirar()
	await process_frame
	_ok(_p.buki_arma() == "X", "com 1 bala ainda na agulha a arma continua na mão (restam %d)" % _p.buki_municao())
	_p._buki.atirar()
	await _esperar(0.3)
	_ok(_p.buki_arma() == "", "munição em 0 -> mãos livres (arma='%s')" % _p.buki_arma())
	_ok(not _visivel("X"), "o canhão sumiu da tela")
	_ok(float(_p._skill_cooldowns["X"]) > 0.0,
		"o slot X entrou em RECARGA (%.1fs)" % float(_p._skill_cooldowns["X"]))
	_ok(_p.get("_char_model") != null and (_p.get("_char_model") as Node3D).visible,
		"o CORPO voltou depois da transformação")
	_ok(str(_p.get("_srv_buki_arma")) == "" and int(_p.get("_srv_buki_municao")) == 0,
		"o SERVIDOR também guardou a arma")

# --------------------------------------- 6. servidor recusa tiro sem munição
func _servidor_sem_bala() -> void:
	print("\n-- 5. sem bala o SERVIDOR não cria hitbox nenhuma --")
	var cena := current_scene
	var antes := _zonas(cena)
	# Pedido forjado, como faria um cliente adulterado: arma X, munição zerada.
	_p._do_server_bullet(Vector3(0, 0, -1), _p.global_position + Vector3.UP, "X")
	await _esperar(0.3)
	_ok(_zonas(cena) == antes,
		"nenhuma DamageZone nasceu do pedido sem munição (%d -> %d)" % [antes, _zonas(cena)])

	# E com munição de verdade ela nasce — senão o teste acima passaria por engano
	# (ex.: se `_do_server_bullet` estivesse quebrado para TODO mundo).
	_zerar_recargas()
	_p.begin_charge("C")
	await _esperar(0.4)
	var base := _zonas(cena)
	_p._buki.atirar()
	await _esperar(0.3)
	_ok(_zonas(cena) > base, "com bala, o disparo cria DamageZone (%d -> %d)" % [base, _zonas(cena)])
	_ok(_p.buki_arma() == "C" and _visivel("C"), "a sniper ficou empunhada entre os tiros")

# ------------------------------------------------------------------ utilidades
func _visivel(slot: String) -> bool:
	var armas: Dictionary = _p.get("_buki_armas")
	var n = armas.get(slot)
	return n is Node3D and is_instance_valid(n) and (n as Node3D).visible

func _zonas(raiz: Node) -> int:
	var n := 1 if raiz is DamageZone else 0
	for c in raiz.get_children():
		n += _zonas(c)
	return n

func _zerar_recargas() -> void:
	for k in _p._skill_cooldowns.keys():
		_p._skill_cooldowns[k] = 0.0

func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1

func _local() -> Node:
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
