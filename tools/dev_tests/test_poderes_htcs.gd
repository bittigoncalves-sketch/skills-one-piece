extends SceneTree
## HTCS (13/11/2026): as 6 camadas de `PoderVfx` nascem sem erro, a fruta do mod liga carga/impacto, e os Small Meteors da Zushi (X) CAEM em ~1 s (no mod eram ~20 s).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_poderes_htcs.gd
var total := 0
var falhas := 0
func _init() -> void:
	rodar.call_deferred()
func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)
func q(n: int) -> void:
	for i in n:
		await physics_frame
func filhos_novos(antes: Dictionary) -> int:
	var n := 0
	for f in current_scene.get_children():
		if not antes.has(f):
			n += 1
	return n
func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_htcs.json"))
	modo.set("progresso_forcado", "user://test_htcs.json")
	root.get_node("GameFlow").start_story()
	await q(150)
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var onde := j.global_position + Vector3(0, 0, -6)
	var antes := {}
	for f in current_scene.get_children(): antes[f] = true
	var carga := PoderVfx.carga(j, j, Vector3(0, 1, 0), Color.CYAN, 1.0, 1.5, 20)
	ok(carga != null and carga.get_parent() == j, "carga nasce presa ao corpo")
	PoderVfx.soltar_carga(carga)
	var feixe := PoderVfx.feixe(j, j.global_position + Vector3.UP, onde, Color.CYAN, 0.5, 0.3)
	ok(feixe != null and feixe.get_child_count() == 2, "feixe: núcleo + halo")
	var pt := Node3D.new()
	current_scene.add_child(pt)
	var r := PoderVfx.rastro(j, pt, Color.CYAN)
	ok(r != null, "rastro nasce seguindo uma parte")
	PoderVfx.golpe(j, onde, Color.CYAN, 3.0, 0.9, PoderVfx.Forma.QUADRADO)
	await q(3)
	ok(filhos_novos(antes) >= 4, "golpe cria impacto, anel, rachadura e partículas (%d nós novos)" % filhos_novos(antes))
	for forma in [PoderVfx.Forma.CIRCULO, PoderVfx.Forma.QUADRADO, PoderVfx.Forma.TRIANGULO]:
		var t := PoderVfx._tex_anel(forma)
		ok(t != null and t.get_width() == 128, "anel de forma %d gerado" % forma)
	await q(180)
	ok(not is_instance_valid(feixe), "o feixe some sozinho")
	# a fruta do mod liga a camada de carga e de impacto
	ok(PoderDaFruta.COR.size() == 40 and PoderDaFruta.cor("zushi_zushi") != PoderVfx.COR_PADRAO, "as 40 frutas do mod têm cor própria")
	modo.equipar_fruta(j, "zushi_zushi")
	await q(20)
	var c = j.get_node_or_null("FrutaMinePiece")
	j.energy = j.max_energy
	c.usar_tecla("Z", true)
	await q(3)
	ok(c._carga_vfx != null, "segurar a tecla liga a CARGA do HTCS")
	c.usar_tecla("Z", false)
	await q(3)
	ok(c._carga_vfx == null, "soltar a tecla fecha a carga")
	var fitas := 0
	for f in current_scene.get_children():
		if f is RastroDePoder:
			fitas += 1
	ok(fitas >= 1, "a técnica liga o RASTRO da mão (%d fita)" % fitas)
	await q(120)
	# técnica SEM alvo (Gravity Blade no vazio, boneco longe): ainda assim há clímax visual
	modo.equipar_fruta(j, "mera_mera")
	await q(20)
	c = j.get_node_or_null("FrutaMinePiece")
	j.energy = j.max_energy
	var ant2 := {}
	for f in current_scene.get_children(): ant2[f] = true
	var t0 := Time.get_ticks_msec()
	c.usar_tecla("Z", true)
	await q(6)
	c.usar_tecla("Z", false)
	await q(45)
	ok(PoderDaFruta.ultimo_contato_ms < t0 and filhos_novos(ant2) >= 2, "técnica sem alvo ganha clímax no ponto de mira (%d nós novos)" % filhos_novos(ant2))
	modo.equipar_fruta(j, "zushi_zushi")
	await q(20)
	c = j.get_node_or_null("FrutaMinePiece")
	await q(100)
	# Small Meteors (X): o meteoro tem de pousar rápido
	j.energy = j.max_energy
	var meteoros := {}
	c.usar_tecla("X", true)
	await q(4)
	c.usar_tecla("X", false)
	var maior := 0
	for f in 200:
		await q(1)
		for n in current_scene.get_children():
			if str(n.name).begins_with("MC_meteor") and not meteoros.has(n):
				meteoros[n] = f
		for n in meteoros.keys():
			if not is_instance_valid(n):
				maior = maxi(maior, f - int(meteoros[n]))
				meteoros.erase(n)
	ok(maior > 0, "os Small Meteors nascem e pousam")
	ok(maior > 0 and maior <= 90, "a queda do meteoro leva %d quadros (≤ 90 ≈ 1,5 s; no mod ≈ 20 s)" % maior)
	print("test_poderes_htcs: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
