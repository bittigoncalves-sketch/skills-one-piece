extends SceneTree
# ============================================================================
#  TESTE — naufrágios, esqueletos e ouro (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E3/E4).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_naufragios.gd
#
#  Modo História com o MAPA VIVO (só leitura) e progresso de TESTE. Confere: os cascos do
#  mapa assentados no fundo (nenhum canto flutuando), material de madeira afundada,
#  colisão do casco, esqueletos na pose de morte, um baú fechado (com brilho) por casco;
#  o E pela HUD abre o baú ao alcance e paga UMA vez; salvar/recarregar mantém aberto;
#  controle: fora de alcance não há dica nem abertura.
# ============================================================================

const PROGRESSO := "user://test_naufragios_progresso.json"
const RECOMPENSAS := {"naufragio_galeao": 40, "naufragio_chalupa": 25, "naufragio_bote": 15}

var _falhas := 0


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	print("\n===== NAUFRÁGIOS =====")
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://mapas/historia/baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 120:
		await process_frame
	var jogador: CharacterBody3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	var mar := current_scene.get_node_or_null("Mar")
	_ok(jogador != null and mar != null, "Modo História com jogador e Mar")
	if jogador == null or mar == null:
		_fim(modo)
		return
	jogador.set_meta("damage_immune", true)
	var nauf: Node3D = mar.get("naufragios")
	var relevo: RelevoMarinho = mar.get("relevo")
	var registros: Dictionary = nauf.get("naufragios")
	_ok(registros.size() == 5, "5 naufrágios do mapa ligados (%d)" % registros.size())
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")

	# Assentamento, material, profundidade.
	var flutuando := 0
	var raso_fundo := 0
	var sem_material := 0
	for id in registros:
		var r: Dictionary = registros[id]
		var corpo: Node3D = r["corpo"]
		var bib := MapaMontador.biblioteca_em_uso()
		var info := bib.info(r["modelo"])
		var origem_y: float = corpo.global_position.y - (info["centro"] as Vector3).y
		var menor := INF
		for fx in [-0.45, 0.0, 0.45]:
			for fz in [-0.3, 0.0, 0.3]:
				var q: Vector3 = corpo.global_position + corpo.global_basis.x.normalized() * (info["tamanho"] as Vector3).x * fx \
					+ corpo.global_basis.z.normalized() * (info["tamanho"] as Vector3).z * fz
				menor = minf(menor, relevo.altura(q.x, q.z))
		flutuando += int(absf(origem_y - menor) > 0.05)
		var prof := relevo.nivel - menor
		raso_fundo += int(prof < 7.5 or prof > 23.0)
		for mi in corpo.find_children("*", "MeshInstance3D", true, false):
			var m := (mi as MeshInstance3D).material_override as ShaderMaterial
			sem_material += int(m == null or not String(m.shader.resource_path).ends_with("naufragio.gdshader"))
	_ok(flutuando == 0, "cascos assentados no fundo, nenhum canto flutuando (%d fora)" % flutuando)
	_ok(raso_fundo == 0, "todos entre 8 e 22 m de água (%d fora)" % raso_fundo)
	_ok(sem_material == 0, "madeira afundada em todas as malhas dos cascos (%d sem)" % sem_material)

	# Colisão do casco (raio de cima no centro bate no casco, não no fundo).
	for i in 3:
		await physics_frame
	var espaco := jogador.get_world_3d().direct_space_state
	# Grade 5×3 de raios sobre a pegada: o centro do galeão é o VÃO entre as metades.
	var sem_colisao := []
	for id in registros:
		var corpo: Node3D = registros[id]["corpo"]
		var tam: Vector3 = MapaMontador.biblioteca_em_uso().info(registros[id]["modelo"])["tamanho"]
		var batem := 0
		var outros := {}
		for fx in [-0.35, -0.17, 0.0, 0.17, 0.35]:
			for fz in [-0.15, 0.0, 0.15]:
				var c: Vector3 = corpo.global_position + corpo.global_basis.x.normalized() * tam.x * fx + corpo.global_basis.z.normalized() * tam.z * fz
				var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(c.x, relevo.nivel, c.z), Vector3(c.x, -100, c.z)))
				if not hit.is_empty() and hit["collider"] == corpo:
					batem += 1
				elif not hit.is_empty():
					outros[str(hit["collider"].name)] = true
		print("     %s %s: %d/15 raios no casco; outros: %s" % [id, registros[id]["modelo"], batem, outros.keys()])
		if batem < 3:
			sem_colisao.append(id)
	_ok(sem_colisao.is_empty(), "colisão do casco: todo naufrágio bloqueia raios na pegada (sem: %s)" % [sem_colisao])

	# Esqueletos na pose de morte e baús fechados com brilho.
	var esqueletos := 0
	var na_pose := 0
	for n in nauf.get_children():
		var aps := n.find_children("*", "AnimationPlayer", true, false)
		if not n.find_children("*", "Skeleton3D", true, false).is_empty() and not aps.is_empty():
			esqueletos += 1
			var ap := aps[0] as AnimationPlayer
			# Deitado de verdade: a cabeça perto do chão (de pé, ~1,4 m com a escala).
			var sk := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var cab := sk.find_bone("Head")
			var altura_cabeca := (sk.global_transform * sk.get_bone_global_pose(cab)).origin.y - (n as Node3D).global_position.y
			na_pose += int("Death" in String(ap.assigned_animation) and altura_cabeca < 0.5)
	_ok(esqueletos >= 10, "esqueletos decorativos: %d (marcadores: 3+2+1+3+2)" % esqueletos)
	_ok(na_pose == esqueletos, "todos DEITADOS na pose de morte, cabeça a < 0,5 m (%d/%d)" % [na_pose, esqueletos])
	var fechados := 0
	var com_luz := 0
	for id in registros:
		var bau: Node3D = registros[id].get("bau")
		fechados += int(bau != null and not registros[id]["aberto_na_cena"])
		com_luz += int(bau != null and not bau.find_children("*", "OmniLight3D", true, false).is_empty())
	_ok(fechados == registros.size() and com_luz == registros.size(), "um baú fechado e brilhando por casco (%d, %d luzes)" % [fechados, com_luz])

	# Controle: longe de qualquer baú → sem dica, E não abre.
	jogador.global_position = Vector3(300, -3, 0)
	await process_frame
	_ok(nauf.dica().is_empty() and not nauf.interagir(), "controle: longe de baú, sem dica e o E não abre")

	# Abrir pela HUD (tecla E de verdade), pagar uma vez.
	var id_alvo: String = registros.keys()[0]
	var alvo: Dictionary = registros[id_alvo]
	jogador.global_position = (alvo["ponto"] as Vector3) + Vector3(1.2, 0.5, 0)
	await process_frame
	_ok(nauf.dica() == "E — abrir o baú do naufrágio", "perto do baú: dica \"%s\"" % nauf.dica())
	var ouro0 := prog.ouro
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_E
	tecla.physical_keycode = KEY_E
	tecla.pressed = true
	Input.parse_input_event(tecla)
	for i in 4:
		await process_frame
	var pago: int = RECOMPENSAS[alvo["modelo"]]
	_ok(prog.ouro == ouro0 + pago, "E pela HUD abre e paga %d de ouro (%d → %d)" % [pago, ouro0, prog.ouro])
	_ok(alvo["aberto_na_cena"] == true and is_instance_valid(alvo["bau"]) and (alvo["bau"] as Node3D).find_children("*", "OmniLight3D", true, false).is_empty(),
		"o baú virou o aberto com ouro, sem brilho")
	_ok(not nauf.interagir() and prog.ouro == ouro0 + pago and nauf.dica().is_empty(), "segundo E não paga de novo (ouro %d), sem dica" % prog.ouro)

	# Salvar e recarregar.
	prog.salvar(PROGRESSO)
	var lido := ProgressaoDoPersonagem.carregar(PROGRESSO)
	var baus: Array = lido.dados_de("mar").get("baus", []) if lido != null else []
	_ok(baus.has(id_alvo) and baus.size() == 1, "save guarda o baú aberto (%s)" % [baus])
	_fim(modo)


func _fim(modo: Script) -> void:
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\nNAUFRAGIOS_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)
