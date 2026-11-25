extends SceneTree
# ============================================================================
#  Z DA PIKA PARALISA SEGURANDO, ATÉ NO AR (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_pika_z_paralisa.gd
#
#  Pedido do dono: "Z da pika pika paralisa o jogador até mesmo no ar enquanto estiver
#  sendo segurado". Campo do Builder "Paralisa segurando" (Z da Pika ligado), só no
#  Modo História. Na cena real da história (mapa e save de TESTE), Pika comida:
#    • no ar, segurando Z ~1 s: não cai nem desliza;
#    • soltar: o raio sai e a queda volta;
#    • no chão, segurando: não anda;
#    • controle positivo: sem o perfil da história (= arena) o mesmo Z no ar CAI.
# ============================================================================

const SAVE := "user://test_pika_z_paralisa_progresso.json"
const MAPA := "user://test_pika_z_paralisa_mapa.json"

var total := 0
var falhas := 0
var p: Node3D       # sem tipo Player: tipar compila o Player.gd antes dos autoloads


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
	await process_frame
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	ok(prog.comer_fruta("pika_pika"), "come a Pika")
	await quadros(20)
	ok(str(p.get("current_fruit_id")) == "pika_pika" and p.get("perfil_de_frutas") != null, "Pika equipada com o perfil da história")
	ok(bool(KitDoBuilder.skill("Z", "pika_pika").get("ativacao", {}).get("paralisar_segurando", false)),
		"o Z publicado tem \"Paralisa segurando\" ligado")

	print("\n-- no ar --")
	var y_ar := await _no_ar_segurando()
	ok(absf(y_ar[0]) < 0.05 and y_ar[1] < 0.05, "segurando Z ~1 s no ar: caiu %.3f m, deslizou %.3f m" % [y_ar[0], y_ar[1]])
	p.release_charge("Z")
	var antes: float = p.global_position.y
	await quadros(45)
	ok(p.global_position.y < antes - 0.5, "soltou: a queda volta (%.2f m em 0,75 s)" % (antes - p.global_position.y))
	await quadros(90)
	p.call("clear_spawned_skills")

	print("\n-- no chão --")
	p.global_position = Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await quadros(40)
	var no_chao: Vector3 = p.global_position
	await _esperar_recarga()
	p.begin_charge("Z")
	p.velocity = Vector3(6, 0, 0)          # empurrão de andar: tem que ser anulado
	await quadros(40)
	ok(p.global_position.distance_to(no_chao) < 0.08, "segurando no chão: parado (%.3f m)" % p.global_position.distance_to(no_chao))
	p.release_charge("Z")
	await quadros(90)
	p.call("clear_spawned_skills")

	print("\n-- controle positivo: arena (sem perfil da história) --")
	var perfil: Variant = p.get("perfil_de_frutas")
	p.set("perfil_de_frutas", null)
	var arena := await _no_ar_segurando()
	ok(arena[0] > 1.0, "mesmo Z no ar, sem o Modo História: cai (%.2f m) — a arena não mudou" % arena[0])
	p.release_charge("Z")
	p.set("perfil_de_frutas", perfil)
	_fim()


## Põe o jogador a 8 m do chão, segura Z por 60 quadros e devolve [queda, deslize].
func _no_ar_segurando() -> Array:
	await _esperar_recarga()
	p.global_position = Vector3(0, 9.0, 0)
	p.velocity = Vector3.ZERO
	await quadros(2)
	p.begin_charge("Z")
	await quadros(4)
	var inicio: Vector3 = p.global_position
	await quadros(60)
	var fim: Vector3 = p.global_position
	return [inicio.y - fim.y, Vector2(fim.x - inicio.x, fim.z - inicio.z).length()]


func _esperar_recarga() -> void:
	(p.get("_fruit_cooldowns") as Dictionary)["Z"] = 0.0
	p.energy = p.max_energy
	await quadros(40)                      # 0,5 s entre golpes de fruta


func _fim() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAPA))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nPIKA_Z_PARALISA %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
