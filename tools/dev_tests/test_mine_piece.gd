extends SceneTree
## Frutas "(Mine Piece)" (feitas por `tools/criar_mine_piece.gd`, 17/10/2026) em jogo, pela
## entrada real de cada modo. Lê o catálogo PUBLICADO NO PROJETO.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_mine_piece.gd -- historia
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_mine_piece.gd -- arena
## História: a loja vende, comprar + comer equipa, e cada tecla acerta com o dano × 250/2048.
## Arena (singleplayer): o menu de personagem oferece a fruta, `pedir_fruta_do_builder`
## equipa, e cada tecla acerta com o dano do Builder.

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_mine_piece.json"
## fruta → [[tecla, distância do alvo (m), segurar (quadros; 0 = toque)]]
const CASOS := {
	"pika_pika_no_mi_mine_piece": [["Z", 9.0, 50], ["X", 6.0, 0], ["C", 4.0, 0]],
	"hie_hie_no_mi_mine_piece": [["Z", 9.0, 0], ["X", 9.0, 40], ["C", 9.0, 0]],
	"moku_moku_no_mi_mine_piece": [["Z", 6.0, 0]],
	"nikyu_nikyu_no_mi_mine_piece": [["Z", 6.0, 30], ["X", 7.0, 0], ["C", 5.0, 0]],
}

var p: Node3D
var alvo: Node3D
var historia := true
var passou := 0
var falhas := 0


class Alvo extends StaticBody3D:
	var health := 5000.0
	var hits := 0
	func take_damage(d: float, _origem := Vector3.ZERO, _kb := Vector3.ZERO, _stun := 0.0) -> void:
		health -= d
		hits += 1


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await physics_frame


func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1


func _limpar(distancia: float) -> void:
	for e in current_scene.find_children("SkillBuilder_*", "", true, false): e.queue_free()
	await frames(3)
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p.health = p.max_health
	for campo in ["_fruit_cooldowns", "_skill_cooldowns", "_server_cast_next_ms"]:
		if campo in p: (p.get(campo) as Dictionary).clear()
	for campo in ["_intervalo_golpe", "_trava_pos_fruta", "_fruit_damage_lock_timer"]:
		if campo in p: p.set(campo, 0.0)
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	alvo.position = Vector3(0, 1, -distancia)
	alvo.health = 5000.0
	alvo.hits = 0
	await frames(5)


func _cast(tecla: String, segurar: int) -> void:
	p.begin_charge(tecla)
	await frames(maxi(segurar, 1))
	p.release_charge(tecla)


func _rodar() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	historia = args.is_empty() or args[0] != "arena"
	SkillsPublicadas.recarregar()
	for fid in CASOS:
		ok("%s pronta no catálogo" % fid, KitDoBuilder.frutas_prontas().has(fid))
	var modo = load("res://src/historia/ModoHistoria.gd")
	if historia:
		modo.set("mapa_forcado", MAPA)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
		modo.set("progresso_forcado", PROGRESSO)
		root.get_node("GameFlow").start_story()
	else:
		root.get_node("GameFlow").start_singleplayer()
	await frames(150)
	p = get_first_node_in_group("player")
	if p == null:
		ok("o jogador nasceu", false)
		quit(1)
		return
	alvo = Alvo.new()
	alvo.collision_layer = 1
	var col := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = .5
	forma.height = 1.8
	col.shape = forma
	alvo.add_child(col)
	current_scene.add_child(alvo)
	alvo.add_to_group("enemy")
	var escala := PerfilDeFrutas.ESCALA_DA_ARENA if historia else 1.0

	for fid: String in CASOS:
		if historia and CatalogoFrutasMinePiece.substituida(fid):
			# 20/10/2026: a tradução nativa substitui a versão do Builder na campanha
			# (decisão do dono); a do Builder continua testada na arena.
			ok("%s fora da loja (substituída por %s)" % [fid, CatalogoFrutasMinePiece.atual(fid)],
				not PerfilDeFrutas.frutas_a_venda().has(fid))
			continue
		if historia:
			ok("%s à venda na loja" % fid, PerfilDeFrutas.frutas_a_venda().has(fid))
			var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
			prog.nivel = maxi(prog.nivel, 11) # 1100 de energia (100 × nível; custos ×10): os 110 de antes.
			prog.ouro = 100
			load("res://src/historia/npcs/loja_de_frutas.gd").new().executar(prog, null, "comprar", fid)
			prog.comer_fruta(fid)
		else:
			p.pedir_fruta_do_builder(fid)
		await frames(10)
		p.combat_mode = "fruit"
		ok("%s equipada" % fid, str(p.current_fruit_id) == fid)
		for caso: Array in CASOS[fid]:
			var tecla: String = caso[0]
			var s := KitDoBuilder.skill(tecla, fid)
			await _limpar(float(caso[1]))
			await _cast(tecla, int(caso[2]))
			await frames(150)
			var dano: float = 5000.0 - alvo.health
			# Na história: técnica × 1,5 e soco × 0,5 (23/10/2026, `Balance.HISTORIA_*`).
			var mult_historia := 1.0 if not historia else Balance.HISTORIA_TECNICAS
			var por_acerto := float(s.dano.valor) * escala * mult_historia
			# Um acerto vale o dano da skill (a carga mexe só no impulso); vários acertos
			# (rajadas, socos) valem múltiplos dele.
			var multiplo: float = dano / maxf(por_acerto, 0.001)
			ok("%s %s \"%s\": %d acerto(s), dano %.1f (%.2f × %.1f)" % [fid.get_slice("_", 0), tecla, s.identificacao.nome,
				alvo.hits, dano, multiplo, por_acerto], alvo.hits >= 1 and absf(multiplo - roundf(multiplo)) < 0.05)

	print("\nMINE PIECE (%s): %d passaram / %d falharam" % ["história" if historia else "arena", passou, falhas])
	if historia:
		modo.set("mapa_forcado", "")
		modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
