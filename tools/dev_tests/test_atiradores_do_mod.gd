extends SceneTree
## ATIRADORES DO MOD (30/10/2026), pela cadeia fiel (sem Builder): o equipamento do CONSTRUTOR Java entra na mão (Helmeppo: pistola,
## Yasopp/Benn Beckman: fuzil, Charlos: pistola dourada); um marinheiro com fuzil e o Helmeppo ATIRAM no jogador (AIMob →
## CalculateAttack → AttackRifle), a bala nasce COM desenho e fere. O jogador NÃO fica imune: `damage_immune` o faz parecer criativo
## ao mod, que então não o mira (descoberto neste teste).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_atiradores_do_mod.gd
var _falhas := 0
var _j: Node3D
func _init() -> void:
	call_deferred("_r")
func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _falhas += 1
func _quadros(n: int) -> void:
	for i in n: await physics_frame

func _mao(p: Node) -> String:
	var it = McEntidade.de(p).getMainHandItem()
	return "" if it.isEmpty() else str(it.item.id).trim_prefix("minepiece:")

func _isolar(alvo: Node3D) -> void:
	for o in get_nodes_in_group("enemy") + get_nodes_in_group("npc"):
		if o != alvo and o != _j and o is Node3D and o.is_in_group("personagens_east_blue"):
			o.process_mode = Node.PROCESS_MODE_DISABLED
			(o as Node3D).global_position = Vector3(0, -800, 0)

## Fica a 10 m do atirador, de frente, até ele disparar (ou `segundos`). Devolve {corpos, desenhados, dano}.
## O desenho se mede no quadro SEGUINTE ao nascimento (`McCorpoDoMod.criar` põe o corpo na árvore antes de montar o desenho) e antes de
## a bala ser liberada.
func _observar(atirador: Node3D, segundos: int) -> Dictionary:
	var novos := []
	var ouv := func(no: Node):
		if str(no.name).begins_with("MC_bullet") or str(no.name).begins_with("MC_missile"):
			novos.append(no)
	node_added.connect(ouv)
	var vida0: float = _j.health
	var vistos := 0
	var desenhados := 0
	var conferidos := {}
	for i in segundos * 60:
		await physics_frame
		if i % 90 == 0:
			_j.global_position = atirador.global_position + Vector3(0, 0.3, 10.0)
			_j.velocity = Vector3.ZERO
		for n in novos:
			if is_instance_valid(n) and not conferidos.has(n.get_instance_id()):
				conferidos[n.get_instance_id()] = true
				vistos += 1
				if n._desenho != null and n._desenho.is_visible_in_tree():
					desenhados += 1
		if vistos >= 2 and _j.health < vida0:
			break
	node_added.disconnect(ouv)
	return {"corpos": vistos, "desenhados": desenhados, "dano": vida0 - _j.health}

func _r() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_atiradores.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_atiradores.json"))
	root.get_node("GameFlow").start_story()
	var limite := Time.get_ticks_msec() + 150000
	while _j == null and Time.get_ticks_msec() < limite:
		await physics_frame
		_j = get_first_node_in_group("player")
	await _quadros(240)
	_j.max_health = 100000.0
	_j.health = 100000.0

	print("\n-- equipamento do construtor Java --")
	var por_id := {}
	for p in get_nodes_in_group("personagens_east_blue"):
		var id := str(p.ficha.get("id", ""))
		if not por_id.has(id): por_id[id] = p
	for par in [["helmeppo", "pistol"], ["yasopp", "rifle"], ["benn_beckman", "rifle"], ["charlos", "pistol_gold"]]:
		if por_id.has(par[0]):
			var p: Node3D = por_id[par[0]]
			_ok(_mao(p) == par[1], "%s nasce com %s na mão (%s)" % [par[0], par[1], _mao(p)])
			var modelo := p.find_children("Arma_MAINHAND", "", true, false)
			_ok(not modelo.is_empty(), "%s: o modelo da arma está na mão do personagem" % par[0])
		else:
			print("  (", par[0], " não está no mapa)")
	var coletes := 0
	for p in get_nodes_in_group("personagens_east_blue"):
		if str(p.ficha.get("id", "")) == "marine" and _mao(p) != "":
			coletes += 1
	print("  marinheiros já armados (antes de chegar perto, o `ao_nascer` do mod ainda não rodou): ", coletes)

	print("\n-- marinheiro com fuzil atira --")
	var marinheiros := get_nodes_in_group("personagens_east_blue").filter(func(p): return str(p.ficha.get("id", "")) == "marine")
	_j.global_position = marinheiros[0].global_position + Vector3(0, 0.5, 14.0)
	await _quadros(600)         # chega perto: as IAs do mod passam a rodar e o `ao_nascer` (30 % fuzil) acontece
	var atirador: Node3D = null
	for p in marinheiros:
		if "rifle" in _mao(p):
			atirador = p
			break
	if atirador == null:       # o sorteio não deu fuzil a ninguém: dá a um, como o SetTagMarine faria
		atirador = marinheiros[0]
		McEntidade.de(atirador).setItemSlot(&"MAINHAND", Mc.novo(&"ItemStack", [Mc.item(&"minepiece:rifle")]))
		print("  (sorteio sem fuzil: equipei um)")
	_isolar(atirador)
	var r: Dictionary = await _observar(atirador, 25)
	_ok(r.corpos >= 1, "o marinheiro dispara: %d balas nasceram" % r.corpos)
	_ok(r.corpos >= 1 and r.desenhados == r.corpos, "TODAS as balas têm desenho (%d de %d)" % [r.desenhados, r.corpos])
	_ok(r.dano > 0.0, "e acertam o jogador (dano %.1f)" % r.dano)

	if por_id.has("helmeppo"):
		print("\n-- Helmeppo (pistola) atira --")
		var h: Node3D = por_id["helmeppo"]
		_j.health = 100000.0
		_j.global_position = h.global_position + Vector3(0, 0.5, 14.0)
		await _quadros(300)
		_isolar(h)
		var rh: Dictionary = await _observar(h, 25)
		print("  Helmeppo: balas=%d desenhadas=%d dano=%.1f" % [rh.corpos, rh.desenhados, rh.dano])
		_ok(rh.corpos >= 1, "o Helmeppo dispara com a pistola do construtor")
		_ok(rh.corpos >= 1 and rh.desenhados == rh.corpos, "e as balas dele têm desenho")

	modo.set("progresso_forcado", "")
	print("\n%s" % ("TUDO CERTO" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas else 0)
