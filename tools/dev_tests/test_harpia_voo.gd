extends SceneTree
# ============================================================================
#  HARPIA: VOO ENTRE AS PEDRAS, RONDA DOS PICOS, REAÇÃO E TORNADO MAIS RÁPIDO
#  (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_harpia_voo.gd
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_harpia_voo.gd -- --tela
#
#  Pedido do dono: "aumento da área de atuação da águia e garantir que ela se movimente
#  adequadamente entre as pedras; se o jogador a ataca ela alça voo e dá uma investida,
#  mas após a investida ela já ganha velocidade novamente voando ao redor dos picos;
#  aumentar velocidade de movimento do tornado que ela lança".
#  No MAPA VIVO (os morros de verdade), save de TESTE:
#    • território 150 × 130 m; picos achados nos dois montes;
#    • patrulha 20 s: anda sempre (sem empacar), nunca dentro da pedra, ronda os picos;
#    • combate: chega e investe; depois da investida NÃO pára — já sai a ≥ 14 m/s e volta
#      a rondar um pico;
#    • levou golpe (investida em recarga): alça voo na hora e investe de novo;
#    • tornado a 14 m/s (era 8).
# ============================================================================

const SAVE := "user://test_harpia_voo_progresso.json"
const PASTA := "res://art_src/validation/harpia_voo"
const ESPECIE := "harpia_-_animated_low_poly"

var total := 0
var falhas := 0
var tela := false
var h: AnimalDaIlha
var c: Node
var j: Node3D


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if tela:
		root.size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	for a in get_nodes_in_group("animais"):
		if (a as AnimalDaIlha).especie == ESPECIE:
			h = a
	ok(h != null, "a Harpia está no mapa vivo")
	if h == null:
		return _fim()
	c = h.get("combate")
	var meio: Vector3 = h.area["meio"]
	ok(meio.x * 2.0 >= 149.0 and meio.z * 2.0 >= 129.0, "território 150 × 130 m (era 80 × 70): %.0f × %.0f" % [meio.x * 2.0, meio.z * 2.0])

	# --- patrulha: jogador na beira do território, longe do alerta ---
	print("\n-- patrulha --")
	await _por_jogador(Vector2(-142, -95))
	c.config.raio_de_combate = 0.0
	h.global_position = Vector3(-150, 70, -150)
	await quadros(5)
	var picos: Array = c.get("_picos")
	if picos.is_empty():
		await quadros(30)
		picos = c.get("_picos")
	print("     picos: %s" % str(picos.map(func(p): return Vector3(roundf(p.x), roundf(p.y), roundf(p.z)))))
	ok(picos.size() >= 2 and picos.any(func(p): return p.y > 45.0), "achou os picos dos montes (%d, o mais alto a %.0f m)" % [picos.size(), picos[0].y if not picos.is_empty() else 0.0])
	var m := await _medir_voo(1200, picos)
	print("     patrulha 20 s: %.1f m/s médio · parada máx %.2f s · %d quadros dentro de pedra · %.0f %% perto de um pico · folga mínima %.1f m" % [
		m["media"], m["parada"], m["dentro"], 100.0 * m["perto_pico"], m["folga"]])
	ok(m["media"] >= 0.6 * float(c.config.velocidade_patrulha), "patrulha anda sempre (%.1f m/s)" % m["media"])
	ok(m["parada"] < 1.0, "nunca empaca (parada máxima %.2f s)" % m["parada"])
	ok(m["dentro"] == 0, "nunca entra na pedra (%d quadros)" % m["dentro"])
	ok(m["perto_pico"] >= 0.7, "ronda os picos (%.0f %% do tempo perto de um)" % (100.0 * m["perto_pico"]))
	await _foto("patrulha", picos[0])

	# --- combate: chega, investe, arremete e volta aos picos sem parar ---
	print("\n-- combate --")
	c.config.raio_de_combate = 60.0
	await _por_jogador(Vector2(-150, -120))
	var viu_investida := false
	for i in 900:
		await physics_frame
		if str(c.fase) == "investida":
			viu_investida = true
			break
	ok(viu_investida, "em combate ela chega e investe")
	while str(c.fase) == "investida":
		await physics_frame
	ok(str(c.fase) == "arremeter", "fim da investida: arremete (antes ficava 1 s parada no ar)")
	var vels: Array[float] = []
	var antes: Vector3 = h.global_position
	for i in 60:
		await physics_frame
		vels.append(h.global_position.distance_to(antes) * 60.0)
		antes = h.global_position
	var media := 0.0
	for v in vels:
		media += v / vels.size()
	var minima: float = vels.slice(6).min()
	ok(media >= 14.0 and minima >= 5.0, "no 1 s depois da investida: %.1f m/s médio, mínimo %.1f (não pára)" % [media, minima])
	await _foto("depois_da_investida", h.global_position)
	var perto_depois := 0
	for i in 180:
		await physics_frame
		if _dist_pico(picos) <= float(c.config.raio_orbita) + 12.0:
			perto_depois += 1
	ok(perto_depois >= 60, "e volta a rondar um pico (%d de 180 quadros perto)" % perto_depois)

	# --- reação: levou golpe com a investida em recarga ---
	print("\n-- reação a golpe --")
	for i in 600:
		if str(c.fase).is_empty() and float(c.get("_recarga_i")) > 2.0 and float(c.get("_reacao_livre_em")) <= float(c.get("_tempo")):
			break
		await physics_frame
	var y0 := h.global_position.y
	h.take_damage(5.0, j.global_position)
	await quadros(2)
	ok(str(c.fase) == "decolar", "levou golpe: alça voo na hora (fase %s)" % str(c.fase))
	await quadros(int(float(c.config.decolar) * 60.0))
	ok(h.global_position.y > y0 + 1.5, "subiu %.1f m antes de investir" % (h.global_position.y - y0))
	var investiu := false
	for i in 360:
		await physics_frame
		if str(c.fase) in ["preparar_investida", "investida"]:
			investiu = true
			break
	ok(investiu, "e investe contra quem bateu, mesmo com a recarga correndo")

	# --- tornado mais rápido ---
	print("\n-- tornado --")
	for i in 600:
		if str(c.fase).is_empty() and not c.ativo():
			break
		await physics_frame
	c.set("_recarga_v", 0.0)
	var lancou: bool = c.iniciar_vendaval(j)
	var t: Node3D = null
	for i in 200:
		await physics_frame
		var ts := get_nodes_in_group("tornados_harpia")
		if not ts.is_empty():
			t = ts[0]
			break
	ok(lancou and t != null and is_equal_approx(float(t.get("velocidade")), 14.0), "tornado lançado a 14 m/s")
	# Velocidade medida em campo aberto e plano (no morro a encosta íngreme o segura —
	# ele sobe no máximo ~27°, como antes subia ~20°).
	var campo := Vector3(56, 0, -78)      # campo aberto ao lado do acampamento norte
	var r := PhysicsRayQueryParameters3D.create(campo + Vector3.UP * 80, campo + Vector3.DOWN * 40, 1)
	var chao := h.get_world_3d().direct_space_state.intersect_ray(r)
	var solto: Node3D = load("res://src/historia/bosses/harpia/tornado_vendaval.gd").new()
	solto.velocidade = float(c.config.velocidade_tornado)
	solto.position = (chao["position"] if not chao.is_empty() else campo) + Vector3.UP * .05
	current_scene.add_child(solto)
	solto.configurar(h, Vector3.RIGHT)
	await quadros(2)
	var de := solto.global_position
	await quadros(60)
	var v := Vector2(solto.global_position.x - de.x, solto.global_position.z - de.z).length()
	print("     tornado em campo aberto: %.1f m/s" % v)
	ok(absf(v - 14.0) < 1.0, "em campo aberto anda a 14 m/s (%.1f; antes 8)" % v)
	solto.cancelar()
	_fim()


func _por_jogador(xz: Vector2) -> void:
	var q := PhysicsRayQueryParameters3D.create(Vector3(xz.x, 150, xz.y), Vector3(xz.x, -50, xz.y), 1)
	q.exclude = [h.get_rid()]
	var hit := h.get_world_3d().direct_space_state.intersect_ray(q)
	j.global_position = (hit["position"] if not hit.is_empty() else Vector3(xz.x, 30, xz.y)) + Vector3.UP * 1.0
	j.velocity = Vector3.ZERO
	await quadros(20)


func _dist_pico(picos: Array) -> float:
	var melhor := INF
	for p: Vector3 in picos:
		melhor = minf(melhor, Vector2(p.x - h.global_position.x, p.z - h.global_position.z).length())
	return melhor


## Voo por `n` quadros: velocidade média, maior parada, quadros dentro de geometria,
## fração perto de um pico e menor folga do chão.
func _medir_voo(n: int, picos: Array) -> Dictionary:
	var espaco := h.get_world_3d().direct_space_state
	var esfera := SphereShape3D.new()
	esfera.radius = 0.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = esfera
	q.collision_mask = 1
	q.exclude = [h.get_rid(), (h.get("_hurtbox") as CollisionObject3D).get_rid(), (j as CollisionObject3D).get_rid()]
	var antes := h.global_position
	var andado := 0.0
	var parada := 0.0
	var maior_parada := 0.0
	var dentro := 0
	var perto := 0
	var contados := 0
	var folga := INF
	for i in n:
		await physics_frame
		var p := h.global_position
		var passo := p.distance_to(antes)
		antes = p
		if i < 120:
			continue                  # entrando na órbita
		contados += 1
		andado += passo
		parada = parada + 1.0 / 60.0 if passo * 60.0 < 1.0 else 0.0
		maior_parada = maxf(maior_parada, parada)
		q.transform.origin = h.centro_do_corpo()
		if not espaco.intersect_shape(q, 1).is_empty():
			dentro += 1
		if _dist_pico(picos) <= float(c.config.raio_orbita) + 12.0:
			perto += 1
		var r := PhysicsRayQueryParameters3D.create(p + Vector3.UP, p + Vector3.DOWN * 60.0, 1)
		r.exclude = q.exclude
		var hit := espaco.intersect_ray(r)
		if not hit.is_empty():
			folga = minf(folga, p.y - float(hit["position"].y))
	return {"media": andado / (contados / 60.0), "parada": maior_parada, "dentro": dentro,
		"perto_pico": float(perto) / maxf(contados, 1), "folga": folga}


func _foto(nome: String, olhar: Vector3) -> void:
	if not tela:
		return
	var anterior := root.get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.global_position = olhar + Vector3(45, 25, 45)
	cam.look_at(h.global_position)
	cam.make_current()
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join(nome + ".png")))
	print("     foto: ", PASTA.path_join(nome + ".png"))
	cam.queue_free()
	if anterior != null:
		anterior.make_current()


func _fim() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nHARPIA_VOO %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
