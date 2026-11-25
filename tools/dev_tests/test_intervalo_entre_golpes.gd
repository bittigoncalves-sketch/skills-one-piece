extends SceneTree
# ============================================================================
#  0,5 s ENTRE GOLPES DE FRUTA — arena e Modo História (07/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_intervalo_entre_golpes.gd
#
#  Pedido do dono: "adicionar restrição onde um ataque só pode ser lançado 0,5 segundos
#  após o outro". Decisão: golpes de fruta (Z/X/C/V) de todas as frutas, arena e
#  história; a skill do Builder escolhe o seu no editor. Teclas pela entrada de verdade
#  (`begin_charge`/`release_charge`); "saiu" = a recarga daquela tecla foi armada.
#    • fruta em código (Goro): Z, e o X logo depois é recusado; aos 0,3 s ainda; aos
#      0,55 s sai;
#    • Pika (Z/X/C do Builder, V do código): X do Builder e o V logo depois recusado;
#      depois de 0,55 s sai;
#    • a recarga das OUTRAS teclas não pausa (a trava antiga pausava);
#    • campo do editor: skill com `intervalo_depois` 1,2 s segura 1,2 s;
#    • servidor: `_autorizar_cast_remoto` recusa outra tecla antes de 0,4 s (folga de
#      80 %), aceita a mesma tecla (rajada; quem limita é a recarga) e aceita depois.
# ============================================================================

const PASTA := "user://test_intervalo_skills"

var _ok_n := 0
var _falhas := 0
var p: Node3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	root.get_node("GameFlow").start_singleplayer()
	await _fisica(150)
	p = _jogador()
	print("-- Arena --")
	await _codigo("goro_goro", "Z", "X")
	await _pika("arena")
	await _sem_pausa()
	await _servidor()
	await _campo_do_editor()

	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_intervalo_entre_golpes.json")
	root.get_node("GameFlow").start_story()
	await _fisica(150)
	p = _jogador()
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta("pika_pika")
	await _fisica(20)
	print("-- Modo História --")
	await _pika("história")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nINTERVALO_ENTRE_GOLPES %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## Fruta em código: a segunda tecla é recusada antes de 0,5 s e sai depois.
func _codigo(fruta: String, a: String, b: String) -> void:
	await _preparar(fruta)
	await _tecla(a)
	_ok("%s: %s saiu" % [fruta, a], _saiu(a))
	await _tecla(b)
	_ok("%s: %s logo depois é recusado (intervalo %.2f s)" % [fruta, b, p._intervalo_golpe], not _saiu(b))
	await _segundos(0.3)
	await _tecla(b)
	_ok("%s: aos ~0,3 s ainda é recusado" % fruta, not _saiu(b))
	await _segundos(0.3)
	await _tecla(b)
	_ok("%s: depois de 0,5 s o %s sai" % [fruta, b], _saiu(b))


## Pika: X do Builder e o V do código logo depois.
func _pika(rotulo: String) -> void:
	await _preparar("pika_pika")
	await _tecla("X")
	_ok("%s, Pika: X (Builder) saiu" % rotulo, _saiu("X"))
	await _tecla("V")
	_ok("%s, Pika: V (código) logo depois é recusado" % rotulo, not _saiu("V"))
	await _segundos(1.6)                    # o X dura 1,3 s; depois dele e do intervalo
	await _tecla("V")
	_ok("%s, Pika: depois do intervalo o V sai" % rotulo, _saiu("V"))


## A recarga das outras teclas continua andando durante o intervalo. Armado sem golpe
## em curso: com golpe em curso as outras recargas já param por outra regra (de antes,
## `_slot_em_uso`), que não é o que se mede aqui.
func _sem_pausa() -> void:
	await _preparar("goro_goro")
	p._fruit_cooldowns["X"] = 3.0
	p.armar_intervalo_de_golpe("Z")
	var x0: float = p._fruit_cooldowns["X"]
	await _segundos(0.3)
	_ok("a recarga do X anda durante o intervalo (%.2f → %.2f)" % [x0, p._fruit_cooldowns["X"]],
		p._fruit_cooldowns["X"] < x0 - 0.15)


## O servidor: outra tecla antes de 0,4 s é recusada; a mesma tecla passa; depois passa.
func _servidor() -> void:
	await _preparar("goro_goro")
	p._server_cast_next_ms.clear()
	p._server_proximo_golpe_ms = 0
	var o: Vector3 = p.global_position
	var aim := Vector3(0, 0, -1)
	_ok("servidor: Z aceito", p._autorizar_cast_remoto("Z", aim, o, 0, "fruit", "goro_goro"))
	p._server_cast_next_ms.clear()
	_ok("servidor: o mesmo Z de novo (rajada) não é barrado pelo intervalo",
		p._autorizar_cast_remoto("Z", aim, o, 0, "fruit", "goro_goro"))
	_ok("servidor: X logo depois é recusado", not p._autorizar_cast_remoto("X", aim, o, 0, "fruit", "goro_goro"))
	await _segundos(0.45)
	_ok("servidor: X depois de 0,45 s é aceito", p._autorizar_cast_remoto("X", aim, o, 0, "fruit", "goro_goro"))


## Campo do editor: uma skill da Pika com intervalo de 1,2 s segura 1,2 s.
func _campo_do_editor() -> void:
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	SkillsPublicadas.reconstruir_fruta_da_arena("pika_pika", "Pika Pika no Mi", "#ffd23f")
	var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mapas/skills/pika_raio_z.json"))
	s.configuracoes["intervalo_depois"] = 1.2
	s.ativacao["modo"] = "Pressionar"
	var r := SkillsPublicadas.publicar(s)
	_ok("editor: skill com intervalo 1,2 s é válida (%s)" % str(r.get("erros", [])), bool(r.ok))
	await _preparar("pika_pika")
	await _tecla("Z")
	_ok("editor: Z saiu", _saiu("Z"))
	await _segundos(0.8)
	await _tecla("V")
	_ok("editor: aos 0,8 s o V ainda é recusado (intervalo da skill 1,2 s)", not _saiu("V"))
	await _segundos(0.6)
	await _tecla("V")
	_ok("editor: aos 1,4 s o V sai", _saiu("V"))
	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()


# ------------------------------------------------------------------ apoio

func _preparar(fruta: String) -> void:
	if str(p.current_fruit_id) != fruta:
		p.equip_fruit(fruta)
	p.combat_mode = "fruit"
	if p.get("capacidades") != null:
		p.capacidades = CapacidadesDoJogador.completas()
	await _fisica(130)                       # nada do golpe anterior em curso
	for k in p._fruit_cooldowns.keys():
		p._fruit_cooldowns[k] = 0.0
	p._intervalo_golpe = 0.0
	p.energy = p.max_energy
	p.global_position = Vector3(p.global_position.x, p.global_position.y, p.global_position.z)


func _tecla(slot: String) -> void:
	p.energy = p.max_energy
	p.begin_charge(slot)
	await physics_frame
	p.release_charge(slot)
	await physics_frame


func _saiu(slot: String) -> bool:
	return float(p._fruit_cooldowns.get(slot, 0.0)) > 0.0


func _jogador() -> Node3D:
	for n in get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			return n
	return null


func _segundos(s: float) -> void:
	await _fisica(int(round(s * Engine.physics_ticks_per_second)))


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
