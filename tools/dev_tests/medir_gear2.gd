extends SceneTree
# ============================================================================
#  GEAR 2 — o estado liga, dura, desliga, e aparece na tela?
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_gear2.gd -- <pasta>
#
#  Mede as quatro coisas que a transformação promete, cada uma com número:
#    1. o chapéu É INVOCADO na cabeça (e some ao sair)
#    2. a pele muda, e VOLTA exatamente ao que era
#    3. a fumaça existe enquanto dura
#    4. as saídas funcionam — relógio, morte e troca de fruta
#
#  E captura antes/durante/depois, porque cor e fumaça se julgam com o olho.
# ============================================================================

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/gear2"
	DirAccess.make_dir_recursive_absolute(saida)
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000: await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar: placar.time_left = 1.0e9
	_esconder_2d(get_root())
	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority(): p = n; break
	if p == null: print("❌ sem jogador"); quit(1); return
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true); e.global_position = Vector3(0, 1, -900)
	p.set_meta("damage_immune", true)
	p.equip_fruit("gomu_gomu")
	p.global_position = Vector3(0, 2.0, 0); p.velocity = Vector3.ZERO
	p._yaw = 0.0; p._pitch = -0.15; p._camera.apontar(0.0, -0.15)
	for i in 40: await process_frame

	var g = p._gear2
	if g == null: print("❌ o Player não tem _gear2"); quit(1); return

	var cam := Camera3D.new()
	get_root().get_tree().current_scene.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 3.0, 3.2)
	cam.look_at(Vector3(0, 2.3, 0), Vector3.UP)

	print("=== ANTES ===")
	var antes := _estado(p, g)
	_mostrar(antes)
	await _tirar(saida, "1_antes")

	print("\n=== ATIVANDO (V) ===")
	p._skill_cooldowns["V"] = 0.0
	p.energy = p.max_energy
	p._fire_skill("V", Vector3(0, 0, -1), p.global_position + Vector3.UP)
	for i in 45: await process_frame
	var durante := _estado(p, g)
	_mostrar(durante)
	await _tirar(saida, "2_durante")

	print("\n=== CONFERÊNCIAS ===")
	_ok("o estado liga", durante["ativo"])
	_ok("o chapéu foi invocado na cabeça", durante["chapeus"] == 1)
	_ok("o chapéu é filho do nó Head", durante["chapeu_no_head"])
	_ok("a pele mudou de cor", durante["cor_corpo"] != antes["cor_corpo"])
	_ok("há fumaça emitindo", durante["fumaca"])
	_ok("o relógio começou perto de 30 s", durante["restante"] > 28.0)

	# ⚠️ O PEDIDO DO DONO ERA NUMÉRICO: "chapéu quadrado incorporando na parte de
	# cima 1/3 da cabeça". Então a conferência também é: a copa tem de COMEÇAR na
	# linha de 2/3 da cabeça, não pousar no topo.
	var enc := _encaixe(p)
	print("   cabeça local: y de %.3f a %.3f (altura %.3f)" % [
		enc["y0"], enc["y1"], enc["alt"]])
	print("   chapéu apoia em y=%.3f | linha de 2/3 = %.3f | engole %.1f%% da cabeça" % [
		enc["apoio"], enc["dois_tercos"], enc["fracao"] * 100.0])
	_ok("a copa engole 1/3 da cabeça (±2%%)", absf(enc["fracao"] - 1.0/3.0) < 0.02)
	_ok("o chapéu é mais largo que a cabeça (lê como chapéu)", enc["larg_chapeu"] > enc["larg_cabeca"] * 1.5)
	print("   cor do corpo: antes %s → durante %s" % [
		str(antes["cor_corpo"]), str(durante["cor_corpo"])])

	print("\n=== SAÍDA PELO RELÓGIO (adiantado) ===")
	g._restante = 0.05
	for i in 20: await process_frame
	var depois := _estado(p, g)
	_mostrar(depois)
	await _tirar(saida, "3_depois")
	_ok("o estado desliga sozinho", not depois["ativo"])
	_ok("o chapéu some", depois["chapeus"] == 0)
	_ok("a pele volta ao que era", depois["cor_corpo"] == antes["cor_corpo"])

	print("\n=== SAÍDA POR MORTE ===")
	g.ativar()
	for i in 10: await process_frame
	p.die_and_respawn()
	for i in 30: await process_frame
	_ok("morrer desliga o Gear 2", not g.esta_ativo())
	_ok("morrer tira o chapéu", _contar_chapeus(p) == 0)

	print("\n=== SAÍDA POR TROCA DE FRUTA ===")
	p.equip_fruit("gomu_gomu")
	for i in 10: await process_frame
	g.ativar()
	for i in 10: await process_frame
	p.equip_fruit("mera_mera")
	for i in 20: await process_frame
	_ok("trocar de fruta desliga o Gear 2", not g.esta_ativo())
	_ok("trocar de fruta tira o chapéu", _contar_chapeus(p) == 0)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	if _falhas > 0:
		quit(1)
	quit(0)

var _ok_n := 0
var _falhas := 0

func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])

func _estado(p: Node3D, g) -> Dictionary:
	return {
		"ativo": g.esta_ativo(),
		"restante": g.tempo_restante(),
		"chapeus": _contar_chapeus(p),
		"chapeu_no_head": _chapeu_no_head(p),
		"cor_corpo": _cor_do_corpo(p),
		"fumaca": _tem_fumaca(p),
	}

func _mostrar(e: Dictionary) -> void:
	print("   ativo=%s restante=%.1f chapéus=%d fumaça=%s cor=%s" % [
		str(e["ativo"]), e["restante"], e["chapeus"], str(e["fumaca"]), str(e["cor_corpo"])])

## Os números do encaixe, em unidades LOCAIS da cabeça — que são as mesmas do
## chapéu, já que ele entra como filho dela.
func _encaixe(p: Node) -> Dictionary:
	var cab: Node3D = null
	var cha: Node3D = null
	for x in _todos(p):
		if x.name == "Head" and x is Node3D: cab = x
		if String(x.name).begins_with(Acessorios.MARCA) and x is Node3D: cha = x
	if cab == null or cha == null:
		return {"y0": 0.0, "y1": 0.0, "alt": 0.0, "apoio": 0.0, "dois_tercos": 0.0,
			"fracao": 0.0, "larg_cabeca": 1.0, "larg_chapeu": 0.0}
	var a: AABB = (cab as MeshInstance3D).mesh.get_aabb()
	var larg_ch := 0.0
	var malhas: Array = []
	FxUtil._collect_meshes(cha, malhas)
	for m in malhas:
		if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
			larg_ch = maxf(larg_ch, (m as MeshInstance3D).mesh.get_aabb().size.x)
	var apoio: float = (cha as Node3D).position.y
	return {
		"y0": a.position.y, "y1": a.end.y, "alt": a.size.y,
		"apoio": apoio,
		"dois_tercos": a.end.y - a.size.y / 3.0,
		"fracao": (a.end.y - apoio) / a.size.y,
		"larg_cabeca": a.size.x, "larg_chapeu": larg_ch,
	}


func _contar_chapeus(p: Node) -> int:
	var n := 0
	for x in _todos(p):
		if String(x.name).begins_with(Acessorios.MARCA):
			n += 1
	return n

func _chapeu_no_head(p: Node) -> bool:
	for x in _todos(p):
		if String(x.name).begins_with(Acessorios.MARCA):
			# `x` vem de Array não tipado, logo é Variant: `:=` não infere.
			var pai: Node = (x as Node).get_parent()
			return pai != null and pai.name == "Head"
	return false

func _cor_do_corpo(p: Node) -> Color:
	# O torso é o maior pedaço e o mais representativo da "pele".
	for x in _todos(p):
		if x.name == "Torso" and x is MeshInstance3D:
			var mo := (x as MeshInstance3D).material_override
			if mo is StandardMaterial3D:
				return (mo as StandardMaterial3D).albedo_color
			return Color(0, 0, 0, 0)   # sem override
	return Color(0, 0, 0, 0)

func _tem_fumaca(p: Node) -> bool:
	for x in _todos(p):
		if x is GPUParticles3D and x.name == "Gear2Vapor":
			return (x as GPUParticles3D).emitting
	return false

func _tirar(saida: String, nome: String) -> void:
	for i in 8: await process_frame
	get_root().get_texture().get_image().save_png("%s/%s.png" % [saida, nome])

func _todos(n: Node) -> Array:
	var out: Array = [n]
	for f in n.get_children(): out.append_array(_todos(f))
	return out

func _esconder_2d(n: Node) -> void:
	for f in n.get_children():
		if f is CanvasLayer or f is CanvasItem: f.visible = false
		else: _esconder_2d(f)
