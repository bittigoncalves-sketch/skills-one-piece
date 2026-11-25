extends SceneTree
# ============================================================================
#  PERFURAÇÃO E GRAVIDADE DO PROJÉTIL DO MOD (14/11/2026): `AbstractArrow.setPierceLevel(n)` atravessa n+1 alvos;
#  `setNoGravity(true)` tira a queda. Antes eram `pass` (o projétil sumia no 1º alvo; as chamas do Higan pedem perfuração 50).
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_projetil_perfura.gd
# ============================================================================
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func alvo(z: float) -> PersonagemMinePiece:
	var a := PersonagemMinePiece.new()
	a.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	a.position = Vector3(0, 0.3, z)
	a.ponto_de_origem = a.position
	current_scene.add_child(a)
	a.set_meta("damage_immune", false)
	a.max_health = 1000000.0
	a.health = a.max_health
	return a

## Dispara de (0, 1, 0) para -Z; devolve o dano nos dois alvos e se o projétil ainda existe.
func atirar(pierce: int, sem_gravidade: bool, a1: PersonagemMinePiece, a2: PersonagemMinePiece, jogador: Node, a3: PersonagemMinePiece = null) -> Array:
	a1.health = a1.max_health
	a2.health = a2.max_health
	if a3 != null:
		a3.health = a3.max_health
	var ej := McEntidade.de(jogador)
	var mundo = ej.level()
	var p = Mc.novo(&"ProjectileFlameEntity", [Mc.tipo_entidade(&"minepiece:projectile_flame"), mundo])
	p.setOwner(ej)
	p.setBaseDamage(5.0)
	p.setPierceLevel(pierce)
	p.setNoGravity(sem_gravidade)
	p.setPos(0.0, 1.0 / 0.88, 0.0)
	p.shoot(0.0, 0.0, -1.0, 2.0, 0.0)
	mundo.addFreshEntity(p)
	var no: Node = p.no
	await quadros(12)
	var y_curto: float = p.getY() if is_instance_valid(no) and not no.is_queued_for_deletion() else NAN
	await quadros(48)
	var vivo := is_instance_valid(no) and not no.is_queued_for_deletion()
	return [a1.max_health - a1.health, a2.max_health - a2.health, vivo, y_curto, (a3.max_health - a3.health) if a3 != null else 0.0]

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_projetil_perfura.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var a1 := alvo(-3.0)
	var a2 := alvo(-4.5)
	await quadros(10)
	var r0: Array = await atirar(0, true, a1, a2, jogador)
	ok(r0[0] > 0.0 and r0[1] == 0.0, "perfuração 0: fere só o 1º alvo (%.0f / %.0f)" % [r0[0], r0[1]])
	ok(not r0[2], "perfuração 0: o projétil some no 1º acerto")
	var r1: Array = await atirar(1, true, a1, a2, jogador)
	ok(r1[0] > 0.0 and r1[1] > 0.0, "perfuração 1: atravessa e fere os dois (%.0f / %.0f)" % [r1[0], r1[1]])
	var a3 := alvo(-6.0)
	await quadros(5)
	var r2: Array = await atirar(1, true, a1, a2, jogador, a3)
	ok(r2[0] > 0.0 and r2[1] > 0.0 and r2[4] == 0.0, "perfuração 1: atravessa n+1 = 2 alvos e NÃO fere o 3º (%.0f / %.0f / %.0f)" % [r2[0], r2[1], r2[4]])
	ok(not r2[2], "perfuração 1: some ao esgotar a perfuração")
	# gravidade: sem alvos no caminho (aponta alto), compara a altura depois de 20 quadros
	a3.position = Vector3(50, 0.3, 54)
	a1.position = Vector3(50, 0.3, 50)
	a2.position = Vector3(50, 0.3, 52)
	await quadros(3)
	var com: Array = await atirar(0, false, a1, a2, jogador)
	var sem: Array = await atirar(0, true, a1, a2, jogador)
	ok(not is_nan(com[3]) and not is_nan(sem[3]) and com[3] < sem[3] - 0.1, "gravidade: com setNoGravity(false) cai (%.2f) e com true segue reto (%.2f)" % [com[3], sem[3]])
	# congelamento (Hie): 140 ticks = congelado; cai 2 por tick; o teto do golpe da Hie é 80
	var e1 := McEntidade.de(a1)
	e1.setTicksFrozen(80)
	ok(absf(e1.getPercentFrozen() - 80.0 / 140.0) < 0.001 and not e1.isFullyFrozen(), "congelamento: 80 ticks = %.2f, ainda não congelado" % e1.getPercentFrozen())
	await quadros(60)       # 60 quadros = ~20 ticks do mundo → perde ~40
	ok(e1.getTicksFrozen() < 80 and e1.getTicksFrozen() > 0, "congelamento: descongela com o tempo (%d)" % e1.getTicksFrozen())
	e1.setTicksFrozen(140)
	ok(e1.isFullyFrozen() and e1.getPercentFrozen() == 1.0, "congelamento: 140 ticks = congelado por completo")
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
