extends SceneTree
# ============================================================================
#  KIT DO BUILDER NO MODO HISTÓRIA (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_kit_do_builder_historia.gd
#
#  Decisão do dono: as skills publicadas no Skills Builder se equipam "como uma
#  fruta". Aqui, com o Modo História de verdade (mapa e progresso de TESTE, skills
#  publicadas numa pasta de TESTE):
#    • equipar dá a ficha (teclas, escala da história) e o menu de técnicas;
#    • Z, X e F (o F roteado pela HUD) acertam inimigo do mapa, boneco e vaca com o
#      dano do Builder × 250/2048;
#    • energia = fração da barra, recarga = a do Builder;
#    • bloco de Movimento anda com o corpo;
#    • Segurar: soltar antes devolve a energia; segurar até o fim dispara;
#    • condição de alvo recusa sem gastar nada;
#    • o save guarda o kit; o inventário (N › FRUTAS) o mostra.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const MAPA := "user://test_kit_do_builder_mapa.json"
const PROGRESSO := "user://test_kit_do_builder.json"
const PASTA := "user://test_kit_do_builder_skills"
const RAIAS := {"inimigo": -40.0, "boneco": 0.0, "animal": 40.0}
const DIST := 4.0

var _ok_n := 0
var _falhas := 0
var p: Node3D       # sem tipo Player: tipar compila o Player.gd antes dos autoloads
var prog: ProgressaoDoPersonagem
var alvos := {}


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	_esvaziar()
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	# Hitbox a 3 m (alcança 4,5 m): o alvo está a 4 m. A padrão (2 m, raio 1,5) só pega
	# alvo a 4 m na PRÉVIA, que supõe alvo de 0,55 m de raio; os corpos do jogo são mais finos.
	_publicar("teste_z", "Z", 100.0, 20.0, 3.0, [_ev("hitbox", 0.0, 0.3, {"z": -3.0})])
	_publicar("teste_x", "X", 80.0, 10.0, 2.0, [_ev("projetil", 0.0, 0.1, {"velocidade": 20.0, "vida": 1.5})])
	_publicar("teste_f", "F", 60.0, 10.0, 4.0, [_ev("movimento", 0.0, 0.4, {"velocidade": 10.0, "distancia": 2.5, "curva": "Linear"}),
		_ev("hitbox", 0.3, 0.3)])
	_publicar("teste_v", "V", 50.0, 30.0, 1.0, [_ev("hitbox", 0.0, 0.3, {"z": -3.0})], {"modo": "Segurar", "carga": 0.5})
	_publicar("teste_c", "C", 40.0, 10.0, 1.0, [_ev("hitbox", 0.0, 0.3)], {}, {"exige_alvo": true, "distancia_maxima": 2.0}, 2.0)

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
	root.get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	prog = current_scene.get("progressao")
	p.set_meta("damage_immune", true)
	alvos["inimigo"] = current_scene.find_child("inimigo_teste", true, false)
	var boneco := BonecoDeDuelo.new()
	boneco.position = Vector3(RAIAS["boneco"], 1.0, -DIST)
	current_scene.add_child(boneco)
	alvos["boneco"] = boneco
	var vaca := AnimalDaIlha.new()
	vaca.montar(bib, "cow", FichaDeAnimal.normalizar(bib.ficha_de_animal("cow")), {"especie": "cow", "base": Basis(), "centro": Vector3(RAIAS["animal"], 0, -DIST), "meio": Vector3(4, 1, 4)})
	current_scene.add_child(vaca)
	vaca.global_position = Vector3(RAIAS["animal"], 0.0, -DIST)
	vaca.alvo = null
	alvos["animal"] = vaca

	# Equipar.
	prog.nivel = maxi(prog.nivel, 2)   # 200 de energia (100 × nível, 23/10/2026)
	prog.comer_fruta(KitDoBuilder.ID)
	for i in 20:
		await physics_frame
	var perfil: PerfilDeFrutas = p.get("perfil_de_frutas")
	_ok("equipado: fruta = kit_builder (%s)" % p.current_fruit_id, p.current_fruit_id == KitDoBuilder.ID)
	var teclas_esperadas: Array[String] = ["Z", "X", "C", "V", "F"]
	_ok("a ficha tem as teclas do kit: %s" % str(perfil.slots() if perfil else []), perfil != null and perfil.slots() == teclas_esperadas)
	_ok("dano na escala da história (%.4f)" % (perfil.escala_de_dano if perfil else 0.0), perfil != null and is_equal_approx(perfil.escala_de_dano, PerfilDeFrutas.ESCALA_DA_ARENA))
	var hud_tec := current_scene.find_child("Tecnicas", true, false)
	_ok("menu de técnicas visível com o kit", hud_tec != null and (hud_tec as CanvasItem).is_visible_in_tree())

	# Z, X e F nos três alvos.
	var esperado := {"Z": 100.0, "X": 80.0, "F": 60.0}
	for slot: String in ["Z", "X", "F"]:
		var linha := "   %s:" % slot
		var todos := true
		for tipo: String in RAIAS:
			var d: float = await _golpe(slot, tipo)
			linha += " %s=%.2f" % [tipo, d]
			todos = todos and absf(d - esperado[slot] * PerfilDeFrutas.ESCALA_DA_ARENA * Balance.HISTORIA_TECNICAS_ESTILO_BASE) < 0.05
		print(linha)
		_ok("%s acerta os três com %s × 250/2048 × 1,5 (estilo base, não 2,0 das Akuma) = %.2f" % [slot, esperado[slot], esperado[slot] * PerfilDeFrutas.ESCALA_DA_ARENA * Balance.HISTORIA_TECNICAS_ESTILO_BASE], todos)

	# Energia, recarga e movimento (raia do boneco).
	await _preparar("boneco")
	var antes_e := float(p.energy)
	var antes_z := p.global_position.z
	p.begin_charge("Z")
	var gasto := antes_e - float(p.energy)
	_ok("energia: custo fixo 20, capacidade %.0f (referência antiga %.1f, gastou %.2f)" % [p.max_energy, 0.2 * p.max_energy, gasto],
		absf(gasto - 20.0) < 0.05)
	_ok("recarga = a do Builder, 3 s (%.2f)" % float(p._fruit_cooldowns.get("Z", 0.0)), absf(float(p._fruit_cooldowns.get("Z", 0.0)) - 3.0) < 0.05)
	p.release_charge("Z")
	for i in 30:
		await physics_frame
	await _preparar("boneco")
	p.global_position = Vector3(10, 1.0, 0)
	for i in 10:
		await physics_frame
	antes_z = p.global_position.z
	await _tecla_f()
	for i in 40:
		await physics_frame
	_ok("F (Movimento 2,5 m à frente) anda com o corpo (%.2f m)" % (antes_z - p.global_position.z), antes_z - p.global_position.z > 2.0)

	# Segurar: cancelar devolve; segurar até o fim dispara.
	await _preparar("boneco")
	var vida_antes: float = alvos["boneco"].get("health")
	antes_e = float(p.energy)
	p.begin_charge("V")
	for i in 12:
		await physics_frame
	p.release_charge("V")
	for i in 30:
		await physics_frame
	_ok("Segurar soltado antes: energia volta (%.2f → %.2f) e não acerta" % [antes_e, float(p.energy)],
		float(p.energy) >= antes_e - 0.01 and is_equal_approx(float(alvos["boneco"].get("health")), vida_antes)
		and float(p._fruit_cooldowns.get("V", 0.0)) <= 0.0)
	p.begin_charge("V")
	for i in 45:
		await physics_frame
	p.release_charge("V")
	for i in 30:
		await physics_frame
	_ok("Segurar até o fim (0,5 s): acerta (%.2f)" % (vida_antes - float(alvos["boneco"].get("health"))),
		vida_antes - float(alvos["boneco"].get("health")) > 1.0)

	# Condição: exige alvo a 2 m — a 4 m recusa sem gastar.
	await _preparar("boneco")
	antes_e = float(p.energy)
	p.begin_charge("C")
	p.release_charge("C")
	_ok("condição de alvo (2 m) recusa a 4 m sem gastar energia nem recarga",
		is_equal_approx(float(p.energy), antes_e) and float(p._fruit_cooldowns.get("C", 0.0)) <= 0.0)

	# Inventário e save.
	var inv := current_scene.find_child("InventarioDaHistoria", true, false)
	if inv != null and inv.has_method("atualizar"):
		inv.call("atualizar")
	# O inventário só redesenha as listas quando está ABERTO (`_suja` até abrir): abre pela API da HUD.
	var hud_inv = get_first_node_in_group("hud")
	if hud_inv != null and hud_inv.has_method("inventario_aberto") and not hud_inv.call("inventario_aberto"):
		hud_inv.call("alternar_inventario")
		await physics_frame
		await physics_frame
	_ok("o Kit do Builder é item do inventário", prog.inventario.contar(ItensDeFruta.tag_akuma(KitDoBuilder.ID)) == 1)
	prog.salvar(PROGRESSO)
	var relido := ProgressaoDoPersonagem.carregar(PROGRESSO)
	_ok("o save guarda o kit (relido: %s)" % (relido.fruta if relido else "?"), relido != null and relido.fruta == KitDoBuilder.ID)

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	_esvaziar()
	print("\nKIT_DO_BUILDER %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ golpes

func _golpe(slot: String, tipo: String) -> float:
	await _preparar(tipo)
	var alvo: Node3D = alvos[tipo]
	var antes: float = alvo.get("health")
	if slot == "F":
		await _tecla_f()
	else:
		p.begin_charge(slot)
		await physics_frame
		p.release_charge(slot)
	for i in 70:
		await physics_frame
	var dano := antes - float(alvo.get("health"))
	p.call("clear_spawned_skills")
	return dano


## O F passa pela HUD da história (é ela que decide se o F é do kit ou do voo).
func _tecla_f() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_F
	ev.physical_keycode = KEY_F
	ev.pressed = true
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame
	var solta := InputEventKey.new()
	solta.keycode = KEY_F
	solta.physical_keycode = KEY_F
	solta.pressed = false
	Input.parse_input_event(solta)
	await physics_frame


func _preparar(tipo: String) -> void:
	var x: float = RAIAS[tipo]
	var alvo: Node3D = alvos[tipo]
	p.global_position = Vector3(x, 1.0, 0.0)
	p.velocity = Vector3.ZERO
	p.set("_yaw", 0.0)
	(p.get("_fruit_cooldowns") as Dictionary).clear()
	p.set("energy", float(p.get("max_energy")))
	if tipo == "boneco":
		alvo.call("parar")
		alvo.global_position = Vector3(x, 1.0, -DIST)
	elif tipo == "animal":
		alvo.call("reviver", Vector3(x, 0.0, -DIST))
	elif not alvo.call("vivo"):
		alvo.call("_renascer")
	alvo.set("health", float(alvo.get("max_health")))
	for i in 20:
		await physics_frame
	await _mirar(alvo)
	if tipo == "animal":
		alvo.set("estado", AnimalDaIlha.Estado.PARADO)
		alvo.global_position = Vector3(x, 0.0, -DIST)


## O retículo no centro do alvo (laço fechado, como em `test_frutas_acertam_npcs`).
func _mirar(alvo: Node3D) -> void:
	var centro := AlvosDeGolpe.centro(alvo)
	var cam: Camera3D = p.get("_cam")
	for i in 40:      # 40, não 14: alvo baixo e perto demora a assentar (ver test_frutas_acertam_npcs)
		var de := cam.global_position
		var frente := -cam.global_transform.basis.z
		var quer := (centro - de).normalized()
		if frente.angle_to(quer) < 0.008:
			return
		p.set("_yaw", float(p.get("_yaw")) + wrapf(atan2(-quer.x, -quer.z) - atan2(-frente.x, -frente.z), -PI, PI))
		p.set("_pitch", clampf(float(p.get("_pitch")) + asin(clampf(quer.y, -1, 1)) - asin(clampf(frente.y, -1, 1)), -1.3, 1.3))
		p.call("_update_pivot")
		for q in 6:
			await physics_frame


# ------------------------------------------------------------------ apoio

func _publicar(id: String, tecla: String, dano: float, custo: float, recarga: float, eventos: Array,
		ativacao: Dictionary = {}, condicoes: Dictionary = {}, alcance: float = 8.0) -> void:
	var s := Dados.novo()
	s.identificacao.id = id
	s.identificacao.nome = id
	s.identificacao.dono = "Jogador"
	s.ativacao.tecla = tecla
	for k in ativacao:
		s.ativacao[k] = ativacao[k]
	s.condicoes.exige_alvo = false
	for k in condicoes:
		s.condicoes[k] = condicoes[k]
	s.dano.valor = dano
	s.dano.empurrao = 0.0
	s.configuracoes.custo = custo
	s.configuracoes.recarga = recarga
	s.configuracoes.alcance = alcance
	s.eventos = eventos
	var fim := 0.0
	for e in eventos:
		fim = maxf(fim, float(e.inicio) + float(e.duracao))
	s.configuracoes.duracao = fim
	var r := SkillsPublicadas.publicar(s)
	if not r.ok:
		push_error("publicar %s: %s" % [id, str(r.erros)])


func _ev(tipo: String, inicio: float, duracao: float, params: Dictionary = {}) -> Dictionary:
	return {"id": "%s_%d" % [tipo, int(inicio * 100)], "tipo": tipo, "inicio": inicio, "duracao": duracao,
		"habilitado": true, "parametros": params}


func _esvaziar() -> void:
	var d := DirAccess.open(ProjectSettings.globalize_path(PASTA))
	if d:
		for nome in d.get_files():
			d.remove(nome)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
