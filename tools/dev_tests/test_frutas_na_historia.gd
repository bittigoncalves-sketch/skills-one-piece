extends SceneTree
# ============================================================================
#  FRUTAS DA ARENA NO MODO HISTÓRIA (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_frutas_na_historia.gd
#
#  Pedido do dono: o vendedor de frutas vende as frutas do singleplayer (arena) no
#  Modo História. Decisão: "kit da arena, escala história" — os mesmos golpes, com a
#  energia, a recarga e o dano da história. A — contas: a escala é vida do inimigo da
#  história / vida da arena; `Balance.novo` escala dano, teto, reserva e partes sem
#  tocar o molde; a recarga da ficha é a que a arena aplica de fato (comparada com o
#  `Player.trigger_skill_cooldown` sem ficha, toda fruta e tecla). B — no jogo: para
#  cada fruta, comida pela progressão, cada tecla Z/X/C/V usada de verdade contra um
#  boneco de 250 de vida: cobra a energia da ficha (não os 180 da arena), põe a
#  recarga da ficha, e nenhum golpe tira mais da metade da vida dele.
# ============================================================================

const PROGRESSO := "user://test_frutas_na_historia.json"
const SLOTS: Array[String] = ["Z", "X", "C", "V"]

var _ok_n := 0
var _falhas := 0
var p: Node3D
var prog: ProgressaoDoPersonagem
var boneco: Node3D
var armas := 0
var armas_sem_soco := true


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	print("\n===== A: contas =====")
	_contas()
	print("\n===== B: no jogo =====")
	await _no_jogo()
	print("\nFRUTAS_NA_HISTORIA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _contas() -> void:
	var vida_da_arena: float = load("res://src/player/health_controller.gd").new().vida_max
	_ok("escala = vida do inimigo da história / vida da arena (%.4f = %.0f / %.0f)" % [PerfilDeFrutas.ESCALA_DA_ARENA, InimigoDoMapa.VIDA_PADRAO, vida_da_arena],
		is_equal_approx(PerfilDeFrutas.ESCALA_DA_ARENA, InimigoDoMapa.VIDA_PADRAO / vida_da_arena))
	var molde := Balance.spec("mera_mera", "V")
	var dano0 := molde.dano
	var s := Balance.novo("mera_mera", "V", 0.5)
	_ok("Balance.novo escala dano e teto e deixa o molde intacto (%.0f → %.0f; molde %.0f)" % [dano0, s.dano, molde.dano],
		is_equal_approx(s.dano, dano0 * 0.5) and is_equal_approx(s.teto, molde.teto * 0.5) and is_equal_approx(molde.dano, dano0))
	var com_partes := ""
	for f in SkillSystem.get_fruit_skills():
		for slot in SLOTS:
			var m := Balance.spec(f, slot)
			if m != null and not m.partes.is_empty() and com_partes.is_empty():
				com_partes = "%s/%s" % [f, slot]
	if not com_partes.is_empty():
		var partes := com_partes.split("/")
		var m := Balance.spec(partes[0], partes[1])
		var e := Balance.novo(partes[0], partes[1], 0.25)
		var nome: String = m.partes.keys()[0]
		_ok("as partes nomeadas também escalam (%s %s: %.0f → %.0f)" % [com_partes, nome, m.parte(nome), e.parte(nome)],
			is_equal_approx(e.parte(nome), m.parte(nome) * 0.25))
	var frutas := PerfilDeFrutas.frutas_da_arena()
	var problemas := []
	for f in frutas:
		var perfil := PerfilDeFrutas.da_arena(f)
		if perfil == null or not perfil.problemas().is_empty() or perfil.slots().is_empty():
			problemas.append(f)
	_ok("as %d frutas geram ficha válida (problemas: %s)" % [frutas.size(), str(problemas)], problemas.is_empty())


func _no_jogo() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	prog = current_scene.get("progressao")
	p.set_meta("damage_immune", true)

	# Recarga: a regra da arena (sem ficha) é a que a ficha mostra e aplica.
	var divergentes := []
	for f in PerfilDeFrutas.frutas_da_arena() + (["rocket"] as Array[String]):
		p.set("perfil_de_frutas", null)
		p.set("current_fruit_id", f)
		p.set("combat_mode", "fruit")
		for slot in SLOTS:
			(p.get("_fruit_cooldowns") as Dictionary).clear()
			p.trigger_skill_cooldown(slot)
			var aplicada := float((p.get("_fruit_cooldowns") as Dictionary).get(slot, -1.0))
			if not is_equal_approx(aplicada, SkillSystem.recarga_da_arena(slot, f)):
				divergentes.append("%s/%s %.0f≠%.0f" % [f, slot, aplicada, SkillSystem.recarga_da_arena(slot, f)])
	(p.get("_fruit_cooldowns") as Dictionary).clear()
	p.set("current_fruit_id", "")
	_ok("a recarga da ficha é a que a arena aplica, toda fruta e tecla (%s)" % str(divergentes), divergentes.is_empty())

	boneco = BonecoDeDuelo.new()
	boneco.name = "Alvo"
	boneco.position = Vector3(0, 1.0, -4.0)
	current_scene.add_child(boneco)
	for i in 20:
		await physics_frame
	var resumo := []
	for f in PerfilDeFrutas.frutas_da_arena():
		if FrutasDoMod.contem(f):
			continue   # 03/11/2026: o jogador usa esta fruta pelo FLUXO DO MOD (test_controlador_fruta_do_mod), não pelo kit da arena
		resumo.append(await _testar_fruta(f))
	_ok("arma de fruta sacada: o clique esquerdo atira e NÃO soca (%d armas testadas)" % armas, armas >= 2 and armas_sem_soco)
	print("\n   resumo (dano por tecla, de 250):")
	for linha in resumo:
		print("     ", linha)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")


func _testar_fruta(f: String) -> String:
	prog.tirar_fruta()
	for i in 4:
		await physics_frame
	prog.comer_fruta(f)
	for i in 20:
		await physics_frame
	var perfil: PerfilDeFrutas = p.get("perfil_de_frutas")
	if perfil == null or perfil.fruta != f or p.get("current_fruit_id") != f:
		_ok("%s: comida, no corpo com a ficha" % f, false)
		return "%s: não equipou" % f
	var linha := "%-11s" % f
	var energia_ok := true
	# A ficha foi escrita para 100 de energia por nível; com a energia do mod o custo vale ficha × proporção (27/10/2026).
	var _prop: float = preload("res://src/historia/atributos_mine_piece.gd").fator_de_custo_fora_do_mod(int(p.get_meta("nivel_historia", 1)))
	var recarga_ok := true
	var maior := 0.0
	var casts := 0
	# Ope: o X (Shambles) troca o corpo de lugar com o alvo e o deixa no alto — vai por
	# último, senão a ROOM da tecla seguinte nasce no ar.
	var ordem: Array[String] = perfil.slots()
	if f == "ope_ope":
		ordem = ["Z", "C", "V", "X"] as Array[String]
	for slot in ordem:
		p.global_position = Vector3(0, 1.0, 0)
		p.velocity = Vector3.ZERO
		p.set("_yaw", 0.0)
		(p.get("_fruit_cooldowns") as Dictionary).clear()
		# Cada tecla isolada: o intervalo de 0,5 s entre golpes (07/10/2026) tem teste
		# próprio (`test_intervalo_entre_golpes`); aqui zera como a recarga.
		p.set("_intervalo_golpe", 0.0)
		p.set("energy", float(p.get("max_energy")))
		boneco.set("health", 250.0)
		boneco.call("parar")
		boneco.global_position = Vector3(0, 1.0, -4.0)
		# Assenta no chão (o Black Hole exige o pé no chão).
		for i in 20:
			await physics_frame
		# Ope: X, C e V só existem dentro de uma ROOM (regra da fruta) — o Z a abre antes.
		if f == "ope_ope" and slot != "Z":
			# ROOM da tecla anterior: some antes (a nova nasce em volta de onde ele está).
			var antiga: Variant = p.get_meta("ope_room") if p.has_meta("ope_room") else null
			if is_instance_valid(antiga):
				(antiga as Node).queue_free()
				p.remove_meta("ope_room")
			# A Ope guarda a recarga também do lado do servidor.
			(p.get("_server_cast_next_ms") as Dictionary).clear()
			(p.get("_fruit_cooldowns") as Dictionary).clear()
			for i in 3:
				await physics_frame
			p.begin_charge("Z")
			await physics_frame
			p.release_charge("Z")
			for i in 70:
				await physics_frame
			(p.get("_fruit_cooldowns") as Dictionary).clear()
			(p.get("_server_cast_next_ms") as Dictionary).clear()
			p.set("_intervalo_golpe", 0.0)
			p.set("energy", float(p.get("max_energy")))
			boneco.set("health", 250.0)
		var e0: float = p.get("energy")
		var menor := e0
		p.begin_charge(slot)
		for i in 24:
			await physics_frame
			menor = minf(menor, float(p.get("energy")))
		p.release_charge(slot)
		for i in 10:
			await physics_frame
			menor = minf(menor, float(p.get("energy")))
		# Arma de fruta (Yami Z, Buki): a tecla SACA; o clique esquerdo atira — e o
		# combate direcional da história não pode socar junto (fica suspenso).
		var arma: bool = p.get("_yami_pistol_active") or str(p.get("_buki_weapon")) != ""
		var socou := false
		var balas0 := int(p.get("_buki_municao"))
		var atirou := false
		if arma:
			_mouse(MOUSE_BUTTON_LEFT, true)
			for i in 90:
				await physics_frame
				socou = socou or p.combate_direcional.ocupado()
			atirou = int(p.get("_buki_municao")) < balas0
			_mouse(MOUSE_BUTTON_LEFT, false)
			armas_sem_soco = armas_sem_soco and not socou
			armas += 1
		for i in 140:
			await physics_frame
			menor = minf(menor, float(p.get("energy")))
		var gasto: float = e0 - menor
		var recarga := float((p.get("_fruit_cooldowns") as Dictionary).get(slot, 0.0))
		var dano: float = 250.0 - float(boneco.get("health"))
		maior = maxf(maior, dano)
		var lancou := gasto > 0.01 or recarga > 0.01 or (arma and (dano > 0.0 or atirou))
		if arma:
			p.call("_buki_guardar")
			if p.get("_yami_pistol_active"):
				p.call("guardar_pistola_da_yami")
			for i in 5:
				await physics_frame
		if f == "suke_suke" and slot == "Z":
			# Camuflagem ALTERNÁVEL (Player._aplicar_invisibilidade): a energia é DRENADA enquanto invisível (não há custo fixo) e os 10 s de
			# recarga começam SOMENTE ao revelar. Medir antes de revelar dava "gastou 48 de 120, recarga 0" — falso defeito de 15/11/2026.
			var drenou := gasto > 0.01
			p.call("revelar_invisibilidade")
			for i in 5:
				await physics_frame
			var rec_z := float((p.get("_skill_cooldowns") as Dictionary).get("Z", 0.0))
			_ok("suke_suke/Z: drena energia invisível (%.1f) e a recarga da ficha (%.1f de %.0f s) começa ao revelar" % [gasto, rec_z, perfil.recarga(slot, 0)],
				drenou and absf(rec_z - perfil.recarga(slot, 0)) <= 0.5)
			casts += 1
			linha += "  Z:%3.0f" % dano
			continue
		casts += int(lancou)
		# A energia cobrada é a da ficha (até ~1 de regeneração no meio): nunca os 180.
		# Rajada: cada bala custa ~0,11 (a bala da arena na proporção da ficha).
		energia_ok = energia_ok and (arma or not lancou or (gasto <= (perfil.custo_de_energia(slot, 0) * _prop) * _vezes(f, slot) + 10.0 * _prop and (_sem_custo_fixo(f, slot) or gasto >= (perfil.custo_de_energia(slot, 0) * _prop) - 5.0 * _prop)))
		recarga_ok = recarga_ok and (not lancou or recarga <= perfil.recarga(slot, 0) + 0.01)
		linha += "  %s:%s" % [slot, ("%3.0f" % dano) if lancou else "  -"]
		if lancou and not arma and (gasto > (perfil.custo_de_energia(slot, 0) * _prop) * _vezes(f, slot) + _prop or (not _sem_custo_fixo(f, slot) and gasto < (perfil.custo_de_energia(slot, 0) * _prop) - 0.5 * _prop) or recarga > perfil.recarga(slot, 0) + 0.01):
			print("     ⚠ %s/%s gastou %.2f (ficha %.0f), recarga %.2f (ficha %.0f)" % [f, slot, gasto, (perfil.custo_de_energia(slot, 0) * _prop), recarga, perfil.recarga(slot, 0)])
		if not lancou:
			print("     ⚠ %s/%s não lançou (no chão %s, modo %s, motivo \"%s\")" % [f, slot, p.is_on_floor(), p.get("combat_mode"), p.get_meta("ope_feedback", "")])
	_ok("%s: as teclas lançam (%d de %d)" % [f, casts, perfil.slots().size()], casts >= perfil.slots().size() - 1)
	# Folgas e custos ×10 em 23/10/2026 (energia 100 por nível; era a barra de 10).
	_ok("%s: energia da ficha (20–50), recarga da ficha" % f, energia_ok and recarga_ok)
	_ok("%s: nenhum golpe tira mais da metade da vida do boneco (maior %.0f de 250)" % [f, maior], maior <= 125.0)
	return linha


## Golpes que a ARENA não cobra como técnica: a rajada Z (Mera, Hie) cobra por BALA, e o
## Kurouzu (X) e o Black Hole (C) da Yami são de graça lá. Fiel à arena, na escala.
func _sem_custo_fixo(f: String, slot: String) -> bool:
	return (slot == "Z" and f in ["mera_mera", "hie_hie"]) or (f == "yami_yami" and slot in ["X", "C"])


## Golpes que a ARENA cobra duas vezes (o Mamaragan, V da Goro: 360 lá, 10 aqui) —
## o kit da arena vem fiel, na escala da história. GATILHO: consertado na arena, tirar.
func _vezes(f: String, slot: String) -> float:
	return 2.0 if f == "goro_goro" and slot == "V" else 1.0


func _mouse(botao: MouseButton, pressionado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = botao
	ev.pressed = pressionado
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressionado else 0
	Input.parse_input_event(ev)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
