extends SceneTree
# ============================================================================
#  FRUTAS DA ARENA × NPCs DO MODO HISTÓRIA (05/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_frutas_acertam_npcs.gd
#
#  Pedido do dono: as frutas trazidas para o Modo História têm que afetar TODOS os
#  NPCs ("um dos que não funciona é o Z, X e V da Bara Bara"). Decisão: tudo que
#  luta ou vive — inimigo do mapa, boneco de duelo, animais (chefes inclusive). Os
#  NPCs de loja e os pets do jogador ficam de fora.
#
#  Três raias, 40 m uma da outra, com um alvo a 4 m à frente do jogador em cada:
#  o INIMIGO do mapa (peça da loja, corpo estático), o BONECO de duelo e um ANIMAL
#  (vaca). Para cada fruta da arena e cada tecla, o golpe sai de verdade em cada
#  raia e o dano no alvo é medido. Critério: golpe que machuca um deles machuca os
#  três (o kit da arena não escolhe alvo por tipo de NPC). As EXCEÇÕES abaixo são
#  impressas com o motivo, nunca escondidas.
# ============================================================================

const MAPA := "user://test_frutas_acertam_npcs_mapa.json"
const PROGRESSO := "user://test_frutas_acertam_npcs.json"
const RAIAS := {"inimigo": -40.0, "boneco": 0.0, "animal": 40.0}
const DIST := 4.0
const SLOTS: Array[String] = ["Z", "X", "C", "V"]

## Golpes que o critério não cobra, com o motivo (aparecem no relatório do teste).
## (06/10/2026: o C da Goro parou de atravessar o chão e o V da Pika passou a guiar
## raios a todo alvo até 50 m — as duas exceções de 05/10 saíram.)
const EXCECOES := {}
## Golpe de SEGURAR: soltar a tecla encerra (a barragem do C da Pika vai de 1,0 a 2,5 s).
const SEGURAR := {"pika_pika/C": 170}
## Golpe que cai LONGE de onde começa (X da Pika refeita no Builder, 06/10/2026: sobe,
## zigue-zague de 21 m — 5 m para a esquerda no fim — e a esfera explode lá): o jogador
## começa deslocado e olhando reto, para o golpe terminar em cima do alvo.
const PARTIDA := {"pika_pika/X": Vector3(5.0, 0.0, 21.0 - DIST)}

var _ok_n := 0
var _falhas := 0
var p: Node3D
var prog: ProgressaoDoPersonagem
var alvos := {}


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var bib := BibliotecaDeModelos.padrao()
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var tam := bib.info("pirate_captain")["tamanho"] as Vector3
	mapa["pecas"].append({"id": "inimigo_teste", "tipo": "modelo", "modelo": "pirate_captain",
		"posicao": Vector3(RAIAS["inimigo"], tam.y * 0.5, -DIST), "rotacao_graus": Vector3.ZERO, "tamanho": tam,
		"cor": Color.WHITE, "material": "liso", "colisao": true})
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	prog = current_scene.get("progressao")
	p.set_meta("damage_immune", true)

	alvos["inimigo"] = current_scene.find_child("inimigo_teste", true, false)
	var boneco := BonecoDeDuelo.new()
	boneco.name = "AlvoBoneco"
	boneco.position = Vector3(RAIAS["boneco"], 1.0, -DIST)
	current_scene.add_child(boneco)
	alvos["boneco"] = boneco
	var vaca := AnimalDaIlha.new()
	var ficha := FichaDeAnimal.normalizar(bib.ficha_de_animal("cow"))
	vaca.montar(bib, "cow", ficha, {"especie": "cow", "base": Basis(), "centro": Vector3(RAIAS["animal"], 0, -DIST), "meio": Vector3(4, 1, 4)})
	current_scene.add_child(vaca)
	vaca.global_position = Vector3(RAIAS["animal"], 0.0, -DIST)
	vaca.alvo = null                         # sem jogador: ela não segue nem foge dele
	alvos["animal"] = vaca
	for i in 20:
		await physics_frame
	_ok("três alvos na cena (inimigo %s, boneco, animal)" % alvos["inimigo"], alvos["inimigo"] is InimigoDoMapa and is_instance_valid(boneco) and is_instance_valid(vaca))

	var linhas := []
	var faltas := []
	# SOP_FRUTAS="suna_suna,bara_bara" limita (depuração); vazio = todas.
	var so := OS.get_environment("SOP_FRUTAS")
	for f in PerfilDeFrutas.frutas_da_arena():
		if not so.is_empty() and not f in so.split(","):
			continue
		var r := await _testar_fruta(f)
		linhas.append(r["linha"])
		faltas.append_array(r["faltas"])
	print("\n   dano por tecla (inimigo / boneco / animal):")
	for l in linhas:
		print("     ", l)
	_ok("golpe que machuca um NPC machuca os três (faltando: %s)" % str(faltas), faltas.is_empty())
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nFRUTAS_NPCS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _testar_fruta(f: String) -> Dictionary:
	prog.tirar_fruta()
	for i in 4:
		await physics_frame
	prog.comer_fruta(f)
	for i in 20:
		await physics_frame
	var perfil: PerfilDeFrutas = p.get("perfil_de_frutas")
	var linha := "%-11s" % f
	var faltas := []
	if perfil == null:
		return {"linha": linha + " sem ficha", "faltas": [f]}
	var ordem: Array[String] = perfil.slots()
	if f == "ope_ope":
		ordem = ["Z", "C", "V", "X"] as Array[String]   # Shambles (X) troca de lugar: por último
	for slot in ordem:
		var danos := {}
		for tipo: String in RAIAS:
			danos[tipo] = await _golpe(f, slot, tipo)
		# Mira e física têm variação: o alvo que ficou em zero quando os outros levaram
		# dano tem MAIS UMA chance. Zero de novo = o golpe não o enxerga.
		if danos.values().any(func(d): return d > 0.5):
			for tipo: String in RAIAS:
				if danos[tipo] <= 0.5:
					danos[tipo] = await _golpe(f, slot, tipo)
		linha += "  %s:%3.0f/%3.0f/%3.0f" % [slot, danos["inimigo"], danos["boneco"], danos["animal"]]
		var algum: bool = danos.values().any(func(d): return d > 0.5)
		if algum:
			for tipo in danos:
				if danos[tipo] > 0.5:
					continue
				var chave := "%s/%s" % [f, slot]
				if EXCECOES.has(chave):
					print("     · exceção %s→%s: %s" % [chave, tipo, EXCECOES[chave]])
				else:
					faltas.append("%s→%s" % [chave, tipo])
	return {"linha": linha, "faltas": faltas}


## Um golpe na raia de `tipo`; devolve o dano que o alvo levou.
func _golpe(f: String, slot: String, tipo: String) -> float:
	var x: float = RAIAS[tipo]
	var alvo: Node3D = alvos[tipo]
	var partida: Vector3 = PARTIDA.get("%s/%s" % [f, slot], Vector3.ZERO)
	p.global_position = Vector3(x, 1.0, 0.0) + partida
	p.velocity = Vector3.ZERO
	p.set("_yaw", 0.0)
	_recarregar()
	if tipo == "boneco":
		alvo.call("parar")
		alvo.global_position = Vector3(x, 1.0, -DIST)
	elif tipo == "animal":
		# Bicho acertado FOGE e golpe forte MATA (certo no jogo): a cada golpe ele volta
		# vivo e parado ao lugar, pelo mesmo caminho do jogo (`reviver`).
		alvo.call("reviver", Vector3(x, 0.0, -DIST))
	elif tipo == "inimigo":
		if not alvo.call("vivo"):
			alvo.call("_renascer")
		# O inimigo do mapa é empurrado/arrastado por golpes anteriores (a Ope o deixava fora da raia e a bola da Bara C errava:
		# 0 só na corrida completa, 15/11/2026). Volta ao lugar de origem como o boneco e o animal.
		if not has_meta("_pos_inimigo"):
			set_meta("_pos_inimigo", alvo.global_position)
		alvo.global_position = get_meta("_pos_inimigo")
		if "velocity" in alvo:
			alvo.set("velocity", Vector3.ZERO)
	alvo.set("health", float(alvo.get("max_health")))
	for i in 20:
		await physics_frame
	await _mirar(alvo)
	if partida != Vector3.ZERO:
		p.set("_yaw", 0.0)                 # reto: o fim do caminho é que cai no alvo
		p.set("_pitch", 0.0)
		p.call("_update_pivot")
	if tipo == "animal":
		alvo.set("estado", AnimalDaIlha.Estado.PARADO)
		alvo.global_position = Vector3(x, 0.0, -DIST)
	if f == "ope_ope" and slot != "Z":
		# X, C e V só existem dentro de uma ROOM, que o Z abre ali mesmo.
		var antiga: Variant = p.get_meta("ope_room") if p.has_meta("ope_room") else null
		if is_instance_valid(antiga):
			(antiga as Node).queue_free()
			p.remove_meta("ope_room")
		for i in 3:
			await physics_frame
		p.begin_charge("Z")
		await physics_frame
		p.release_charge("Z")
		for i in 70:
			await physics_frame
		_recarregar()
		alvo.set("health", float(alvo.get("max_health")))
	var antes: float = alvo.get("health")
	p.begin_charge(slot)
	# V costuma ser de CARGA: segura 1,5 s; os outros, um toque firme.
	for i in int(SEGURAR.get("%s/%s" % [f, slot], 90 if slot == "V" else 24)):
		await physics_frame
	p.release_charge(slot)
	for i in 10:
		await physics_frame
	var arma: bool = p.get("_yami_pistol_active") or str(p.get("_buki_weapon")) != ""
	if arma:
		# Sacar a arma do V leva 1,5 s, e o bicho volta a passear nesse meio-tempo (a
		# metralhadora atirava onde a vaca ESTAVA). O jogador mira de novo antes do gatilho.
		if tipo == "animal":
			alvo.set("estado", AnimalDaIlha.Estado.PARADO)
			alvo.global_position = Vector3(x, 0.0, -DIST)
			# A IA do bicho volta a passear durante a mira (~1,4 s); com arma de tiro
			# único (sniper) a bala ia para onde ele ESTAVA. Congelado só enquanto a arma
			# atira: aqui se mede se a bala fere o bicho, não se ele foge.
			alvo.set_physics_process(false)
		await _mirar(alvo)
		_mouse(true)
		for i in 90:
			await physics_frame
		_mouse(false)
	# V é ultimate: a onda da Gura nasce na borda do mapa e leva 2,5 s até aqui.
	for i in (330 if slot == "V" else 120):
		await physics_frame
	var dano: float = antes - float(alvo.get("health"))
	if tipo == "animal" and dano <= 0.5 and OS.get_environment("SOP_DEPURAR") == "1":
		print("     · vaca: estado=%s vida=%.0f camada=%d pos=%s visivel=%s grupos=%s" % [alvo.get("estado"), alvo.get("health"),
			(alvo as CollisionObject3D).collision_layer, alvo.global_position.snapped(Vector3.ONE * 0.1), alvo.visible, alvo.get_groups()])
	if arma:
		if tipo == "animal":
			alvo.set_physics_process(true)
		p.call("_buki_guardar")
		if p.get("_yami_pistol_active"):
			p.call("guardar_pistola_da_yami")
	# O que o golpe deixou no mapa (campo da Hie V: 50 s e até 55 m; chuva da Pika V:
	# 44 m) alcança a raia vizinha, a 40 m, e somaria outro uso ao dano medido lá.
	p.call("clear_spawned_skills")
	# Golpes que empurram o corpo (Shambles, investidas) não podem contaminar a próxima raia.
	for i in 5:
		await physics_frame
	return dano


## O retículo no centro do alvo, como um jogador faria. Laço FECHADO: mede onde o
## raio da câmera bate de verdade e corrige o giro pela diferença de ângulo — a câmera
## suaviza e orbita (e a Gura dobra a escala do corpo), então mirar "na conta" errava.
func _mirar(alvo: Node3D) -> void:
	var centro := AlvosDeGolpe.centro(alvo)
	var cam: Camera3D = p.get("_cam")
	# 40 tentativas (eram 14): contra o alvo BAIXO e perto (a vaca) a câmera suavizada
	# demora a assentar, e o laço desistia com o retículo no CHÃO a 3 m — a arma de tiro
	# único errava a vaca e parecia defeito do golpe (medido em 06/10/2026).
	for i in 40:
		var de := cam.global_position
		var frente := -cam.global_transform.basis.z
		var par := PhysicsRayQueryParameters3D.create(de, de + frente * 80.0, 15, [p.get_rid()])
		var hit := p.get_world_3d().direct_space_state.intersect_ray(par)
		var ponto: Vector3 = hit["position"] if not hit.is_empty() else de + frente * 80.0
		var quer := (centro - de).normalized()
		var tem := frente.normalized()
		# Critério ANGULAR (centro do alvo): "o raio encostou no alvo" aceitava a BORDA,
		# e a mira que sai de outra origem raspava e passava reto.
		if tem.angle_to(quer) < 0.008:
			return
		var dyaw := atan2(-quer.x, -quer.z) - atan2(-tem.x, -tem.z)
		var dpitch := asin(clampf(quer.y, -1.0, 1.0)) - asin(clampf(tem.y, -1.0, 1.0))
		p.set("_yaw", float(p.get("_yaw")) + wrapf(dyaw, -PI, PI))
		p.set("_pitch", clampf(float(p.get("_pitch")) + dpitch, -1.3, 1.3))
		p.call("_update_pivot")
		for q in 6:
			await physics_frame
	print("     · mira NÃO convergiu em %s (ângulo %.3f rad)" % [alvo.name, (-cam.global_transform.basis.z).angle_to((centro - cam.global_position).normalized())])


func _recarregar() -> void:
	(p.get("_fruit_cooldowns") as Dictionary).clear()
	p.set("_intervalo_golpe", 0.0)     # 0,5 s entre golpes (07/10/2026): cada golpe isolado
	(p.get("_server_cast_next_ms") as Dictionary).clear()
	p.set("energy", float(p.get("max_energy")))
	# Guardar a arma da Buki põe a recarga NO SERVIDOR; sem zerar, o saque da raia
	# seguinte é recusado e nenhum tiro sai (o teste mediria munição, não alvo).
	(p.get("_buki") as Object).call("esquecer_recargas_do_servidor")


func _mouse(pressionado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressionado
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressionado else 0
	Input.parse_input_event(ev)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
