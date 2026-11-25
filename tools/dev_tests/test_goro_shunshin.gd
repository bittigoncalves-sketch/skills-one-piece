extends SceneTree
# ============================================================================
#  SHUNSHIN (C da Goro) — o teleporte não atravessa chão nem parede (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_goro_shunshin.gd
#
#  Antes, `global_position += mira × 12` às cegas: mirando um alvo próximo a mira
#  desce ~11° e o corpo ia 2,4 m para baixo do chão — morte no vazio. Três casos com
#  o corpo real do jogador (Modo História, mapa de teste):
#    1. de pé, mirando 11° para baixo → corre rente ao chão os 12 m;
#    2. parede a 5 m → para encostado nela, do lado de cá;
#    3. no ar (6 m), mirando 45° para baixo → desce até o chão, não abaixo dele.
#  E o golpe de verdade (tecla C) mirando para baixo não mata o jogador.
# ============================================================================

const MAPA := "user://test_goro_shunshin_mapa.json"
const PROGRESSO := "user://test_goro_shunshin.json"

var _ok_n := 0
var _falhas := 0
var p: CharacterBody3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)

	# 1. De pé, mira 11° para baixo.
	await _pousar(Vector3(0, 1.0, 0))
	var chao_y := p.global_position.y
	_ok("de pé no começo (y=%.2f)" % chao_y, p.is_on_floor())
	GoroFX._teleportar(p, Vector3(0, -sin(deg_to_rad(11.0)), -cos(deg_to_rad(11.0))))
	var d1 := Vector2(p.global_position.x, p.global_position.z).length()
	_ok("de pé: corre rente ao chão (Δy=%.2f m)" % (p.global_position.y - chao_y), absf(p.global_position.y - chao_y) < 0.15)
	_ok("de pé: anda os 12 m (%.2f m)" % d1, d1 > 11.5)

	# 2. Parede a 5 m.
	var parede := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(8, 6, 1)
	forma.shape = caixa
	parede.add_child(forma)
	current_scene.add_child(parede)
	parede.global_position = Vector3(30, 3.0, -5.5)     # face de cá em z = −5
	await _pousar(Vector3(30, 1.0, 0))
	GoroFX._teleportar(p, Vector3(0, 0, -1))
	_ok("parede: para do lado de cá (z=%.2f, face em −5,0)" % p.global_position.z,
		p.global_position.z > -5.0 and p.global_position.z < -3.5)
	parede.queue_free()

	# 3. No ar, mirando 45° para baixo.
	await _pousar(Vector3(-30, 1.0, 0))
	var chao3 := p.global_position.y
	p.global_position = Vector3(-30, 6.0, 0)
	p.velocity = Vector3.ZERO
	await physics_frame
	GoroFX._teleportar(p, Vector3(0, -1, -1).normalized())
	_ok("no ar: desce até o chão, não abaixo (y=%.2f, chão %.2f)" % [p.global_position.y, chao3],
		p.global_position.y > chao3 - 0.15 and p.global_position.y < chao3 + 0.6)

	# 4. O golpe de verdade, mirando para baixo, não mata.
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	prog.comer_fruta("goro_goro")
	for i in 20:
		await physics_frame
	await _pousar(Vector3(0, 1.0, 20))
	p.set("_pitch", -0.35)
	p.call("_update_pivot")
	(p.get("_fruit_cooldowns") as Dictionary).clear()
	p.set("energy", float(p.get("max_energy")))
	var antes := p.global_position
	p.begin_charge("C")
	for i in 24:
		await physics_frame
	p.release_charge("C")
	for i in 90:
		await physics_frame
	var andou := Vector2(p.global_position.x - antes.x, p.global_position.z - antes.z).length()
	# Morrer no vazio devolve a fruta à árvore: a fruta continuar no corpo = não morreu.
	_ok("tecla C mirando para baixo: teleporta (%.1f m) e segue vivo (y=%.2f, fruta %s)" % [andou, p.global_position.y, p.get("current_fruit_id")],
		andou > 8.0 and p.global_position.y > chao_y - 0.3 and str(p.get("current_fruit_id")) == "goro_goro")

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nSHUNSHIN %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _pousar(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
