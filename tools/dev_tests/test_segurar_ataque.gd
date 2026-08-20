extends SceneTree
## ============================================================================
##  SEGURANDO UM ATAQUE, O JOGADOR ANDA? — a varredura das 9 frutas × 4 slots.
##
##  O relato (2026-08-15): "o jogador consegue se mover enquanto segura um
##  ataque". "Segurar" não é um estado só neste projeto — são três caminhos
##  diferentes dentro do `CastController.comecar()`, e cada um liga o
##  `_carregando` de um jeito. Por isso a sonda VARRE tudo em vez de conferir o
##  caso que o relato lembrou: um buraco encontrado à mão esconde os irmãos.
##
##  ------------------------------------------------------------------ A REGRA
##  A INVARIANTE é uma só, e é a que o `_etapa_travamento` promete:
##
##      `_charging` verdadeiro  ⇒  o corpo não anda.
##
##  Então o teste mede as duas coisas no MESMO quadro — o estado de carga e a
##  distância percorrida com W segurado. Medir só a distância não serve: um slot
##  que dispara na hora (o Z da Gura, o C da Gomu) TEM que deixar andar, e seria
##  falso positivo.
##
##  ⚠️ PRECISA DE JANELA: sem `MOUSE_MODE_CAPTURED` o `MoveFrame` ignora o
##  teclado e a sonda mede zero em tudo — passando por engano.
##      DISPLAY=:0 godot --path . --script tools/dev_tests/test_segurar_ataque.gd
## ============================================================================

const QUADROS_SEGURANDO := 40      # ~0,65 s de tecla presa
const TOLERANCIA := 0.30           # m — abaixo disso é assentamento, não caminhada

var _teclas := {}
var _player: Node = null

const FRUTAS := ["gura_gura", "yami_yami", "goro_goro", "mera_mera", "gomu_gomu",
	"bara_bara", "hie_hie", "suna_suna", "buki_buki"]
const SLOTS := ["Z", "X", "C", "V"]
const TECLA := {"Z": KEY_Z, "X": KEY_X, "C": KEY_C, "V": KEY_V}

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(3.0)

	_player = _local()
	if _player == null:
		print("❌ não achei o jogador")
		quit(1)
		return
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("### o mouse não capturou — rode COM janela (DISPLAY=:0)")
		quit(1)
		return

	_afastar_bonecos()

	# CONTROLE: a mesma corrida sem tecla de golpe. Sem ele, "andou pouco" não
	# distingue trava funcionando de tecla que nunca chegou.
	await _plantar()
	_aplicar([KEY_W])
	var p0: Vector3 = _player.global_position
	await _quadros(QUADROS_SEGURANDO)
	var controle: float = _plano(_player.global_position - p0)
	_aplicar([])
	print("")
	print("╔══════════════════════════════════════════════════════════════════╗")
	print("║  SEGURANDO UM ATAQUE, O JOGADOR ANDA?                            ║")
	print("╚══════════════════════════════════════════════════════════════════╝")
	print("  controle (só W, sem golpe): %.2f m em %d quadros" % [controle, QUADROS_SEGURANDO])
	if controle < 1.0:
		print("  ### o controle não andou: a tecla não chegou. Medição inválida.")
		quit(1)
		return
	print("")
	print("  %-12s %-4s | %-9s %-9s | %s" % ["fruta", "slot", "segurando", "andou", "veredito"])
	print("  " + "─".repeat(66))

	var furos := []
	for fruta in FRUTAS:
		for slot in SLOTS:
			var r := await _medir(fruta, slot)
			if r.is_empty():
				continue
			var segurando: bool = r["segurando"]
			var andou: float = r["andou"]
			# O FURO é a quebra da invariante: estava carregando E andou.
			var furo: bool = segurando and andou > TOLERANCIA
			var veredito := "FURO" if furo else ("travado" if segurando else "—")
			if furo:
				furos.append("%s %s (%.2f m)" % [fruta, slot, andou])
			print("  %-12s %-4s | %-9s %6.2f m  | %s" % [
				fruta, slot, "sim" if segurando else "não", andou, veredito])

	print("")
	if furos.is_empty():
		print("✅ NENHUM FURO — segurando um ataque, o corpo não anda.")
	else:
		print("❌ %d FURO(S): o jogador anda segurando o ataque" % furos.size())
		for f in furos:
			print("     • ", f)
	quit(1 if furos.size() > 0 else 0)

# Equipa, segura a tecla do golpe + W, e mede. Devolve o estado de carga lido
# NO MEIO da janela (não no fim: alguns golpes soltam sozinhos).
func _medir(fruta: String, slot: String) -> Dictionary:
	await _plantar()
	_player.equip_fruit(fruta)
	_player.combat_mode = "fruit"
	_player._skill_cooldowns[slot] = 0.0
	_player.energy = _player.max_energy
	await _quadros(10)

	var p0: Vector3 = _player.global_position
	_aplicar([KEY_W, TECLA[slot]])
	var segurando := false
	for i in QUADROS_SEGURANDO:
		await _quadros(1)
		if i == int(QUADROS_SEGURANDO * 0.5):
			segurando = bool(_player._charging)
	var andou: float = _plano(_player.global_position - p0)
	_aplicar([])
	await _quadros(20)
	# Limpa o que o golpe tenha deixado ligado, senão o próximo caso herda.
	_player._cast.abortar()
	_player.set_meta("is_casting", false)
	_player.remove_meta("custom_pose")
	return {"segurando": segurando, "andou": andou}

# ---------------------------------------------------------------------- apoio
func _plantar() -> void:
	_aplicar([])
	_afastar_bonecos()
	_player.global_position = Vector3(0, 1.2, 0)
	_player.velocity = Vector3.ZERO
	_player._yaw = 0.0
	_player._fsm.transition_to("Idle")
	_player._melee._trava = 0.0
	_player._movement_locked_timer = 0.0
	var espera := 0
	while not _player.is_on_floor() and espera < 240:
		await _quadros(1)
		espera += 1
	await _quadros(10)

# Tira TODO boneco/inimigo do caminho antes de medir.
#
# ⚠️ NÃO É PARANOIA: o `AutoDummy` persegue e ATACA o jogador sozinho. Um golpe
# dele no meio da corrida de controle aplica hitstun (`combat_state = STUNNED`),
# a corrida morre e a sonda aborta por "medição inválida" — acusando o jogo por
# algo que é o cenário de teste. Aconteceu de verdade: a suíte só passou a
# sofrer disso quando o `AutoDummy` voltou a compilar e, portanto, a existir.
# É a mesma limpeza que o `test_arena` faz antes de medir dano.
func _afastar_bonecos() -> void:
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		if e is Node3D:
			e.set_meta("is_frozen", true)
			e.set_meta("damage_immune", true)
			(e as Node3D).global_position = Vector3(0, -1000, 0)

func _plano(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()

func _local() -> Node:
	for x in get_root().get_tree().get_nodes_in_group("player"):
		if x.is_multiplayer_authority():
			return x
	return null

func _aplicar(teclas: Array) -> void:
	for k in _teclas.keys():
		if not teclas.has(k): _tecla(k, false)
	for k in teclas:
		if not _teclas.has(k): _tecla(k, true)
	_teclas.clear()
	for k in teclas: _teclas[k] = true

func _tecla(code: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = apertada
	Input.parse_input_event(ev)

func _quadros(n: int) -> void:
	for i in n:
		Engine.time_scale = 1.0
		# ⚠️ REAFIRMA AS TECLAS TODO QUADRO, pelo mesmo motivo do `time_scale`.
		#
		# Rodando na bateria (`validar.sh`) sobem várias instâncias do Godot em
		# série e a janela NUNCA ganha foco. Ao perder foco o Godot solta todas as
		# teclas pressionadas, e o W injetado no início sumia: o controle caía de
		# 6,2 m para 0,6 m e a sonda abortava por medição inválida — corretamente,
		# mas por causa do ambiente, não do jogo.
		#
		# Reafirmar é idempotente para o `MoveFrame`, que lê `is_key_pressed`. E a
		# borda do Espaço continua certa: `espaco_agora` é derivada do quadro
		# anterior DENTRO do `MoveFrame`, então segurar não vira martelada.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		await physics_frame

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
