extends SceneTree
## DESEMPENHO ao rolar a hotbar (12/11/2026): custo de `selecionar` e de CADA ouvinte de `progressao.mudou` / `inventario.mudou`.
##   godot --path . -s tools/dev_tests/medir_rolar_hotbar.gd   (com janela: DISPLAY=:1; sem: --headless)
func _init() -> void:
	_rodar.call_deferred()
func quadros(n: int) -> void:
	for i in n:
		await physics_frame
func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_hotbar.json")
	root.get_node("GameFlow").start_story()
	await quadros(500)
	var prog = current_scene.get("progressao")
	var hud = get_first_node_in_group("hud")
	var barra = hud._barra
	# hotbar variada: luta, blocos, arma do Epic Fight na mão, itens vanilla
	prog.inventario.inserir(ItensDeBloco.nova_pilha(TiposDeBloco.PEDRA, 64))
	prog.inventario.inserir(ItensDeBloco.nova_pilha(TiposDeBloco.GRAMA, 64))
	prog.inventario.inserir(InventarioMinecraft.nova("minecraft:iron_ingot", 20))
	prog.equipar_lamina("ef_iron_longsword", true)
	await quadros(30)
	print("== OUVINTES prog.mudou: ", prog.mudou.get_connections().size(), " | inv.mudou: ", prog.inventario.mudou.get_connections().size())
	for sinal in [prog.mudou, prog.inventario.mudou]:
		var lista := []
		for c in sinal.get_connections():
			var cb: Callable = c.callable
			var t0 := Time.get_ticks_usec()
			for k in 20:
				cb.call() if cb.get_argument_count() == 0 else null
			var dt := (Time.get_ticks_usec() - t0) / 20.0
			lista.append([dt, str(cb.get_object()) + "::" + str(cb.get_method())])
		lista.sort_custom(func(a, b): return a[0] > b[0])
		for e in lista.slice(0, 8):
			print("  %8.0f µs  %s" % [e[0], e[1]])
	var piores := 0.0
	var soma := 0.0
	for i in 90:
		var t0 := Time.get_ticks_usec()
		barra.selecionar(i % 9)
		var dt := (Time.get_ticks_usec() - t0) / 1000.0
		soma += dt
		piores = maxf(piores, dt)
		await physics_frame
	print("== selecionar(): média %.2f ms, pior %.2f ms (90 trocas)" % [soma / 90.0, piores])
	var quadro_pior := 0.0
	for i in 90:
		var t0 := Time.get_ticks_usec()
		barra.selecionar(i % 9)
		await process_frame
		quadro_pior = maxf(quadro_pior, (Time.get_ticks_usec() - t0) / 1000.0)
	print("== quadro completo depois de trocar: pior %.2f ms" % quadro_pior)
	quit()
