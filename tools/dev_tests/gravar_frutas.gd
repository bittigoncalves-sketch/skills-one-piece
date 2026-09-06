extends SceneTree
# ============================================================================
#  GRAVADOR DE GOLPES — um clipe por (fruta × slot), pela CÂMERA DE VERDADE.
#
#  Instalado pela skill `multimodal-dev`. Uso:
#    DISPLAY=:1 godot --fixed-fps 30 --disable-vsync --path . \
#        -s tools/dev_tests/gravar_frutas.gd -- <pasta> [frutas=a,b] [slots=Z,X]
#  Depois o `mm.sh gravar` junta cada pasta num .mp4 com ffmpeg.
#
#  POR QUE ESTE ARQUIVO EXISTE, e não mais um `test_*`: o `test_frutas.gd` já
#  responde "o golpe SAI?" contando nós. Ele NÃO responde "o golpe está bonito e
#  no tempo certo?" — e é essa a pergunta que a comparação com referência faz.
#  Aqui a saída é IMAGEM em sequência, com tempo fixo, para virar vídeo
#  comparável quadro a quadro.
#
#  ⚠️ `--fixed-fps` NÃO É ENFEITE. Sem ele cada quadro leva o tempo que levar, e
#  o mp4 montado a 30 fps mente sobre a duração do golpe — que é exatamente o
#  número que o relatório de comparação cobra. Com ele, quadro = 1/30 s exato.
#
#  ⚠️ A PORTA 24565 NÃO PARALELIZA. Este script sobe o jogo; nada mais pode
#  estar rodando (nem `validar.sh`, nem outro agente). O `mm.sh gravar` põe um
#  lockfile por isso.
#
#  De onde veio cada pedaço:
#    • subir o jogo, congelar o relógio e achar o jogador  → test_frutas.gd
#    • câmera de verdade, esconder a HUD, congelar inimigo → gravar_clipes.gd
#    • a sequência de reset antes de disparar              → test_frutas.gd
# ============================================================================

# Excluídas por decisão do dono (2026-09-03): são as duas de qualidade já
# aprovada — a Gomu é o padrão-ouro e a Bara já tem spec própria. O baseline
# existe para as OUTRAS, que ainda vão ser comparadas contra referência.
const EXCLUIDAS := ["bara_bara", "gomu_gomu"]

const SLOTS := ["Z", "X", "C", "V"]
const QUADROS := 90            # 3,0 s a 30 fps — cobre wind-up + golpe + recuperação
const QUADROS_ANTES := 6       # a pose parada antes do golpe: é o "start" da linha do tempo
const ESPERA_LIMPEZA := 1.2    # deixa o VFX morrer antes do próximo clipe

var _p: Node3D
var _saida: String = "/tmp/clipes_frutas"
var _frutas_pedidas: Array = []
var _slots_pedidos: Array = []


func _init() -> void:
	_ler_argumentos()

	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame

	# O pódio no fim da rodada força respawn de todo mundo e devolve a fruta à
	# árvore — no meio de uma gravação longa isso esvazia os golpes seguintes.
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9

	_esconder_2d(get_root())

	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			_p = n
			break
	if _p == null:
		print("❌ sem jogador — a cena não subiu (porta 24565 ocupada?)")
		quit(1)
		return

	# Boneco que soca sozinho muda o clipe e ainda tira vida do gravador.
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	_p.set_meta("damage_immune", true)

	var skills: Dictionary = SkillSystem.get_fruit_skills()
	var alvos: Array = []
	for k in skills.keys():
		var fid := str(k)
		if not _frutas_pedidas.is_empty():
			if _frutas_pedidas.has(fid):
				alvos.append(fid)
		elif not EXCLUIDAS.has(fid):
			alvos.append(fid)
	alvos.sort()

	DirAccess.make_dir_recursive_absolute(_saida)
	print("\n▶ gravando %d fruta(s) em %s" % [alvos.size(), _saida])
	if _frutas_pedidas.is_empty():
		print("  excluídas por decisão do dono: %s" % ", ".join(EXCLUIDAS))

	var indice := {}
	for fid in alvos:
		_p.equip_fruit(fid)
		await _esperar(0.5)
		if str(_p.current_fruit_id) != fid:
			print("  ⚠ %s não equipou (ficou '%s') — pulando"
				% [fid, _p.current_fruit_id])
			continue

		for slot in SLOTS:
			if not _slots_pedidos.is_empty() and not _slots_pedidos.has(slot):
				continue
			var declarada: Dictionary = skills.get(fid, {}).get(slot, {})
			if bool(declarada.get("desabilitado", false)):
				print("  · %s %s: desabilitada por projeto" % [fid, slot])
				continue

			var pasta := "%s/%s_%s" % [_saida, fid, slot]
			DirAccess.make_dir_recursive_absolute(pasta)
			await _gravar_golpe(fid, slot, pasta)
			indice["%s_%s" % [fid, slot]] = {
				"fruta": fid, "slot": slot,
				"nome": str(declarada.get("nome", "")),
				"dano": declarada.get("dano", 0.0),
				"cooldown": declarada.get("cooldown", 0.0),
				"quadros": QUADROS_ANTES + _quadros_para(fid, slot),
				"fps_gravacao": 30,
				"pasta": pasta,
			}
			print("  ✓ %s %s — %s" % [fid, slot, declarada.get("nome", "")])

	var f := FileAccess.open("%s/indice.json" % _saida, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(indice, "\t"))
		f.close()
	print("\n✓ %d clipe(s). Índice: %s/indice.json" % [indice.size(), _saida])
	quit()


# ------------------------------------------------------------------ gravação
func _gravar_golpe(fid: String, slot: String, pasta: String) -> void:
	_preparar_cena(fid, slot)
	await _esperar(0.35)

	var q := 0
	# Os quadros ANTES do disparo dão a pose neutra — sem eles a linha do tempo
	# começa no meio do movimento e a fase "start" não existe para comparar.
	for _i in QUADROS_ANTES:
		await process_frame
		_salvar(pasta, q)
		q += 1

	_disparar(slot)

	for _i in _quadros_para(fid, slot):
		await process_frame
		_salvar(pasta, q)
		q += 1

	_limpar()
	await _esperar(ESPERA_LIMPEZA)


func _preparar_cena(fid: String, slot: String) -> void:
	_p.global_position = Vector3(0, 2.0, 0)
	_p.velocity = Vector3.ZERO
	# Para o Yasakani a referência precisa mostrar a seleção automática, não o
	# fallback da mira. Um alvo congelado fica no enquadramento; os demais somem.
	var primeiro_inimigo := true
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		if fid == "pika_pika" and slot == "C" and primeiro_inimigo:
			e.global_position = Vector3(0, 2, -14)
			primeiro_inimigo = false
		else:
			e.global_position = Vector3(0, 1, -900)
	if _p._camera and _p._camera.em_primeira_pessoa():
		_p._camera.alternar_perspectiva()
	# Três quartos, levemente de cima: enquadramento fixo para TODOS os clipes.
	# Fixo de propósito — comparar dois golpes filmados de ângulos diferentes é
	# comparar câmera, não golpe.
	_p._yaw = 0.0
	_p._pitch = -0.18
	if _p._camera:
		_p._camera.apontar(_p._yaw, _p._pitch)


func _disparar(slot: String) -> void:
	# A mesma sequência de reset do `test_frutas.gd`: sem ela o golpe não sai e o
	# clipe grava um boneco parado (falso negativo que já custou horas lá).
	_p._skill_cooldowns[slot] = 0.0
	_p.set_meta("is_casting", false)
	_p._cast.abortar()
	_p._rapid_fire = false
	_p.lock_movement(0.0, "")
	_p.energy = _p.max_energy
	# O C da Pika é canalizado: usar o mesmo caminho de pressionar/segurar do
	# jogador mantém o personagem suspenso e valida a interrupção por soltura.
	if str(_p.current_fruit_id) == "pika_pika" and slot == "C":
		_p.begin_charge(slot)
		return
	var origem: Vector3 = _p.global_position + Vector3.UP
	_p._fire_skill(slot, Vector3(0, 0, -1), origem)


func _limpar() -> void:
	if _p.has_method("limpar_skills_em_todos"):
		_p.limpar_skills_em_todos()
	elif _p.has_method("clear_spawned_skills"):
		_p.clear_spawned_skills()
	_p.set_meta("is_casting", false)
	_p.velocity = Vector3.ZERO


func _salvar(pasta: String, q: int) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png("%s/f%04d.png" % [pasta, q])


# ------------------------------------------------------------------ auxílios
func _ler_argumentos() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var a := str(args[i])
		if a.begins_with("frutas="):
			_frutas_pedidas = a.substr(7).split(",", false)
		elif a.begins_with("slots="):
			_slots_pedidos = a.substr(6).split(",", false)
		elif i == 0:
			_saida = a


func _esperar(seg: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seg * 1000.0):
		await process_frame


func _quadros_para(fid: String, slot: String) -> int:
	if fid == "pika_pika" and slot == "C":
		return 120 # 4,0 s: carga, rajada completa e encerramento natural.
	if fid == "pika_pika" and slot == "V":
		return 435 # 14,5 s: ativação, chuva, pico e dissipação completos.
	return QUADROS


func _esconder_2d(n: Node) -> void:
	# A HUD é 2D: não muda com o golpe e só ocuparia pixel da comparação.
	for f in n.get_children():
		if f is CanvasLayer or f is CanvasItem:
			f.visible = false
		else:
			_esconder_2d(f)
