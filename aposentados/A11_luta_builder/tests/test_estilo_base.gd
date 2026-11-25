extends SceneTree
## Estilo de Combate Base (item "Luta" da barra, Z/X/C importadas do Mine Piece) no Modo História.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_estilo_base.gd
var p: Node3D
var alvo: Node3D
var longe: Node3D
var passou := 0
var falhas := 0
class Alvo extends StaticBody3D:
	var health := 5000.0
	var hits := 0
	var kb_max := 0.0
	var kb_dir := Vector3.ZERO
	func take_damage(d: float, _origem := Vector3.ZERO, kb := Vector3.ZERO, _stun := 0.0) -> void:
		health -= d
		hits += 1
		if kb.length() > kb_max:
			kb_max = kb.length()
			kb_dir = kb
func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func _alvo(pos: Vector3) -> Alvo:
	var a := Alvo.new()
	a.collision_layer = 1
	var col := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = .5
	forma.height = 1.8
	col.shape = forma
	a.add_child(col)
	current_scene.add_child(a)
	a.add_to_group("enemy")
	a.position = pos
	return a
func _limpar() -> void:
	for e in current_scene.find_children("SkillBuilder_*", "", true, false): e.queue_free()
	await frames(3)
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p.health = p.max_health
	p._fruit_cooldowns.clear()
	p._skill_cooldowns.clear()
	p._server_cast_next_ms.clear()
	p._intervalo_golpe = 0.0
	p._trava_pos_fruta = 0.0
	p._fruit_damage_lock_timer = 0.0
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	for a in [alvo, longe]:
		a.health = 5000.0
		a.hits = 0
		a.kb_max = 0.0
		a.kb_dir = Vector3.ZERO
	alvo.position = Vector3(0, 1, -9)
	longe.position = Vector3(30, 1, 30)
	await frames(5)
func _cast(tecla: String) -> void:
	p.begin_charge(tecla)
	await physics_frame
	p.release_charge(tecla)
func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_estilo_base.json"))   # sem progresso de rodada anterior
	modo.set("progresso_forcado", "user://test_estilo_base.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	var prog = current_scene.progressao
	alvo = _alvo(Vector3(0, 1, -9))
	longe = _alvo(Vector3(30, 1, 30))
	var escala := PerfilDeFrutas.ESCALA_DA_ARENA
	var id := KitDoBuilder.ID_ESTILO_BASE

	# Kit, HUD e integração real (sem a antiga rajada nem quebra-chão).
	ok("kit publicado só com Z/X/C", KitDoBuilder.teclas(id) == ["Z", "X", "C"])
	ok("estilo não é vendido como fruta", not KitDoBuilder.frutas_prontas().has(id))
	ok("Luta equipada", prog.item_em_uso() == "luta" and p.current_fruit_id == id)
	var menu: TecnicasHud = current_scene.get("_hud").get("_tecnicas")
	await frames(5)
	for tecla in ["Z", "X", "C"]:
		ok("HUD " + tecla, menu.texto_da_linha(tecla).begins_with(KitDoBuilder.nome_da_tecla(tecla, id)))
	for tecla in ["Z", "X"]:
		await _limpar()
		alvo.position = Vector3(0, 1, -1.6)
		await _cast(tecla)
		if tecla == "X":
			await frames(8)
			ok("pesado não acerta antes do preparo", alvo.hits == 0)
		await frames(65)
		var dano: float = Balance.MINE_PIECE_LUTA["soco" if tecla == "Z" else "pesado"].dano * escala
		ok(tecla + " um contato, dano correto: " + str(5000.0 - alvo.health), alvo.hits == 1 and is_equal_approx(5000.0-alvo.health, dano))
		ok(tecla + " alvo distante poupado", longe.hits == 0)
		ok(tecla + " limpa pose e ação", not p.has_meta("combate_mine_piece") and not p.has_meta("pose_de_skill"))
	# C: tap completa a sequência mínima; segurar prolonga até o teto do mod.
	await _limpar()
	alvo.position = Vector3(0, 1, -1.6)
	await _cast("C")
	await frames(120)
	var hits_curta: int = alvo.hits
	ok("C tem vários socos e final forte", hits_curta >= 7 and alvo.kb_max > 20)
	ok("C limpa estado", not p.has_meta("combate_mine_piece"))
	await _limpar()
	alvo.position = Vector3(0, 1, -1.6)
	p.begin_charge("C")
	await frames(200)
	p.release_charge("C")
	ok("C segurado prolonga e termina sozinho", alvo.hits > hits_curta and not p.has_meta("combate_mine_piece"))
	await _limpar()
	alvo.position = Vector3(0, 1, -1.6)
	p.begin_charge("X")
	await frames(40)
	ok("X segurado prepara sem contato antecipado", alvo.hits == 0 and p.has_meta("combate_mine_piece"))
	ok("servidor recusa outro golpe durante a carga", not p._autorizar_cast_remoto("Z", Vector3.FORWARD,
		p.global_position, 0, "fruit", id))
	ok("clique não sobrepõe a técnica", not p.combate_direcional.pedir_ataque(GolpeDirecional.Direcao.PARA_DIREITA))
	await frames(105)
	p.release_charge("X")
	ok("X carregado ganha 50% de dano e termina sozinho", alvo.hits == 1 and
		is_equal_approx(5000.0 - alvo.health, 165.0 * escala) and not p.has_meta("combate_mine_piece"))
	# Cancelar preparo por dano não pode deixar um contato atrasado.
	await _limpar()
	alvo.position = Vector3(0, 1, -1.6)
	await _cast("X")
	await frames(4)
	p.health -= 1
	await frames(60)
	ok("dano interrompe X antes do contato", alvo.hits == 0 and not p.has_meta("combate_mine_piece"))
	# Parede entre corpo e alvo não pode ser atravessada pela esfera do soco.
	await _limpar()
	alvo.position = Vector3(0, 1, -1.6)
	var parede := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.15)
	col.shape = box
	parede.add_child(col)
	current_scene.add_child(parede)
	parede.position = Vector3(0, 1, -0.8)
	await frames(3)
	await _cast("Z")
	await frames(60)
	ok("Z bloqueado por parede", alvo.hits == 0)
	parede.queue_free()
	await _limpar()
	await _cast("Z")
	await frames(60)
	ok("Z não atinge 9 m", alvo.hits == 0)
	await _limpar()
	alvo.position = Vector3(0, 1, -4.5)
	await _cast("Z")
	await frames(60)
	ok("área ampla original alcança 4,5 m", alvo.hits == 1)
	# Falta de energia e teclas inexistentes não criam executor.
	await _limpar()
	p.energy = 0
	alvo.position = Vector3(0, 1, -1.6)
	await _cast("X")
	ok("sem energia não inicia", not p.has_meta("combate_mine_piece"))
	await _limpar()
	await _cast("V")
	ok("V vazio não inicia", not p.has_meta("combate_mine_piece"))

	# trocar de item: a fruta comida volta ao assumir o item Fruta
	prog.comer_fruta("nikyu_nikyu")
	await frames(5)
	if prog.item_em_uso() != "fruta":
		prog.ativar_item("fruta")
		await frames(10)
	print("   (item ativo: %s, fruta: %s, ativa: %s)" % [prog.item_em_uso(), prog.fruta, prog.fruta_ativa])
	ok("item Fruta: o corpo carrega a Nikyu", p.current_fruit_id == "nikyu_nikyu" and p.capacidades.can_fly)
	prog.ativar_item("fruta")
	await frames(10)
	ok("soltar a fruta deixa nada selecionado (15/10/2026), sem voo nem técnicas da fruta", prog.item_em_uso() == "" and not p.capacidades.can_fly and not p.capacidades.can_use_fruit)
	prog.ativar_item("luta")
	await frames(10)
	ok("tecla da Luta liga o Estilo de Combate Base", prog.item_em_uso() == "luta" and p.current_fruit_id == id and not p.capacidades.can_fly)

	print("== %d ok, %d falhas" % [passou, falhas])
	quit(1 if falhas > 0 else 0)
