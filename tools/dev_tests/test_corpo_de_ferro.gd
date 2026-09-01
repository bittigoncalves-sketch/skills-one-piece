extends SceneTree
# ============================================================================
#  CORPO DE FERRO — a "defesa avançada", Fase 6 do plano de combate.
#
#  O plano dizia para NÃO reutilizar F. O dono resolveu por outro caminho: em
#  vez de achar outra tecla, a defesa PASSOU A SER o Corpo de Ferro (2026-08-31)
#  — "abre uma janela que corta os danos pela metade e torna a imunidade a
#  qualquer efeito, mesmo que este esteja em ação".
#
#  ⚠️ AS DUAS METADES ANDAM EM SENTIDOS OPOSTOS, e é isso que precisa ser
#  medido junto: o DANO afrouxou (era invulnerabilidade, virou metade) e os
#  EFEITOS apertaram (era uma lista de quatro, virou qualquer um). Testar só uma
#  delas deixaria passar exatamente a que foi na direção contrária.
#
#    DISPLAY=:1 godot --path . -s tools/dev_tests/test_corpo_de_ferro.gd
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

	await _o_dano(p)
	await _os_efeitos(p)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## 1. O DANO: metade durante a janela, inteiro fora dela.
func _o_dano(p: Node3D) -> void:
	print("=== 1. o dano cai pela metade ===")
	p.set_meta("iron_body_active", false)
	p.health = p.max_health
	var cheio: float = p.health
	p.take_damage(200.0)
	await _quadros(3)
	var sem: float = cheio - p.health
	print("   SEM corpo de ferro: 200 pedidos -> %.0f tirados" % sem)
	_ok("fora da janela o dano é inteiro", absf(sem - 200.0) < 1.0)

	p.health = p.max_health
	p.set_meta("iron_body_active", true)
	p.take_damage(200.0)
	await _quadros(3)
	var com: float = p.max_health - p.health
	print("   COM corpo de ferro: 200 pedidos -> %.0f tirados" % com)
	_ok("na janela o dano cai pela METADE", absf(com - 100.0) < 1.0)
	# ⚠️ E NÃO A ZERO: a habilidade deixou de ser invulnerabilidade, e o teste
	# precisa dizer isso — senão um `return` no take_damage passaria como acerto.
	_ok("o dano NÃO é anulado (não é mais invulnerabilidade)", com > 1.0)
	p.set_meta("iron_body_active", false)
	p.health = p.max_health


## 2. OS EFEITOS: qualquer um é recusado, e os que já rodavam saem.
func _os_efeitos(p: Node3D) -> void:
	print("\n=== 2. imunidade a qualquer efeito ===")
	p.set_meta("iron_body_active", false)
	StatusFX.limpar_tudo(p)

	# Um efeito JÁ EM AÇÃO antes da janela.
	StatusFX.aplicar(p, StatusFX.CONGELADO, 5.0)
	await _quadros(2)
	_ok("cenário: o alvo está congelado antes de apertar F",
		_tem(p, StatusFX.CONGELADO))

	p._corpo_de_ferro.ativar_confirmado()
	await _quadros(3)
	_ok("abrir a janela LIMPA o efeito que já estava em ação",
		not (_tem(p, StatusFX.CONGELADO)))

	# E durante a janela nenhum efeito novo entra — inclusive um que não estava
	# na lista fixa que existia antes.
	for id in [StatusFX.CONGELADO, StatusFX.SUGADO, StatusFX.SILENCIADO]:
		StatusFX.aplicar(p, id, 5.0)
	await _quadros(2)
	var entraram := 0
	for id in [StatusFX.CONGELADO, StatusFX.SUGADO, StatusFX.SILENCIADO]:
		if _tem(p, id):
			entraram += 1
	print("   efeitos que entraram durante a janela: %d de 3" % entraram)
	_ok("na janela NENHUM efeito novo entra", entraram == 0)

	# ⚠️ CONTROLE: fora da janela os efeitos voltam a funcionar. Sem ele, um
	# `StatusFX.aplicar` quebrado passaria como imunidade.
	p.set_meta("iron_body_active", false)
	StatusFX.aplicar(p, StatusFX.CONGELADO, 5.0)
	await _quadros(2)
	_ok("fora da janela os efeitos voltam a pegar",
		_tem(p, StatusFX.CONGELADO))
	StatusFX.limpar_tudo(p)


## ⚠️ `StatusFX.ativos` devolve DICIONÁRIOS (id, nome, cor, restante), e não uma
## lista de ids — perguntar `id in ativos()` responde sempre falso, sem erro.
func _tem(alvo: Node, id: String) -> bool:
	for st in StatusFX.ativos(alvo):
		if String((st as Dictionary)["id"]) == id:
			return true
	return false


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
