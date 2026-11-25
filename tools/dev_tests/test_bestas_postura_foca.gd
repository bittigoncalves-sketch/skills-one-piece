extends SceneTree
# ============================================================================
#  BESTAS DO MAR COM POSTURA DE FOCA E LEÃO-MARINHO (08/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_bestas_postura_foca.gd
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_bestas_postura_foca.gd -- --tela
#
#  Pedido do dono: "modificação nas animações das bestas do mar, bem como na velocidade
#  de rotação ao redor do próprio corpo; na terra, quando a besta estiver dormindo, ela
#  deve estar com o corpo completamente deitado, e o corpo deve estar deitado quando
#  estiver nadando no mar também; a besta não tem limite de respiração (...);
#  inspiração focas e leões-marinhos". Escolhas: giro lento na terra e ágil na água,
#  inclinando na curva; as 4 bestas (a serpente também).
#  Confere, na cena real da história (mapa e save de TESTE):
#    1. dormindo na areia: clipe deitado, cabeça baixa, área de dano comprida e baixa;
#    2. parada e andando na areia: ERETA, como antes (correção do dono no mesmo dia);
#    3. nadando: deitada, dorso perto da superfície e a cabeça fora; parada na água:
#       boia em pé ("de garrafa");
#    4. giro: ≤ 35°/s na areia, ~120°/s na água; inclina o corpo na curva só nadando;
#    5. anda para onde olha (não desliza de lado enquanto vira);
#    6. (08/10/2026, "movimentação à cabeça quando estiver nadando e dormindo para sempre
#       estar olhando para frente, na horizontal") dormindo, nadando, submersa, no meio
#       do mergulho e na curva inclinada, a cabeça olha à frente do corpo, nivelada.
#  O fôlego longo é medido em `test_rotina_oceano_bestas` (32,5 s submersa).
#  Com `--tela`, fotos em art_src/validation/bestas_mar/foca/.
# ============================================================================

const MAPA := "user://test_bestas_postura_foca.json"
const SAVE := "user://test_bestas_postura_foca_progresso.json"
const PASTA := "res://art_src/validation/bestas_mar/foca"
const DT := 1.0 / 60.0

var total := 0
var falhas := 0
var tela := false
var camera: Camera3D
var legenda: Label


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func foto(b: Node3D, nome: String, de := Vector3(15, 7, -17)) -> void:
	if not tela:
		return
	camera.global_position = b.global_position + b.global_basis * de
	camera.look_at(b.global_position + Vector3(0, 3, 0))
	camera.make_current()
	legenda.text = "%s · %s" % [b.especie, nome]
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA.path_join("%s_%s.png" % [b.especie, nome]))


func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	await process_frame
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(128, 2, 128)
	for i in 4:
		var tipo: String = ["bovina", "girafa", "javali", "serpente"][i]
		var id := "besta_mar_" + tipo
		var tamanho := bib.tamanho_padrao(id)
		mapa.pecas.append({"id": tipo, "tipo": "modelo", "modelo": id,
			"posicao": Vector3(40, tamanho.y / 2, -45 + i * 30), "tamanho": tamanho,
			"rotacao_graus": Vector3.ZERO, "colisao": true, "cor": Color.WHITE,
			"material": "liso", "grade_celula": 4.0})
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador: Node3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	jogador.global_position = Vector3(-55, .9, 55)
	var bestas: Array = get_nodes_in_group("bestas_do_mar")
	ok(bestas.size() == 4, "quatro bestas na cena (%d)" % bestas.size())
	if tela:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
		root.size = Vector2i(1280, 720)
		camera = Camera3D.new()
		current_scene.add_child(camera)
		var camada := CanvasLayer.new()
		root.add_child(camada)
		legenda = Label.new()
		legenda.position = Vector2(24, 24)
		legenda.add_theme_font_size_override("font_size", 26)
		camada.add_child(legenda)
	for b in bestas:
		b.set_physics_process(false)
	for b in bestas:
		await _uma(b)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("BESTAS_POSTURA_FOCA %d conferem | %d divergem" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)


func _uma(b: Node) -> void:
	var e: String = b.especie
	var praia := Vector3(40, 0.05, b.global_position.z)
	var mar := Vector3(110, 0, b.global_position.z)
	# --- 1. Na areia: posturas com a IA parada (a rotina não troca o estado no meio) ---
	b.global_position = praia
	b.rotation.y = 0.0
	await _posar(b, "idle", false)
	var em_pe := _altura_da_cabeca(b)
	b.set_meta("ref_cabeca", _angulos_da_cabeca(b))       # a régua da cabeça nivelada
	ok(b.animador.atual == "idle" and not b.deitada(), "%s: parada na areia fica em pé (cabeça a %.1f m)" % [e, em_pe])
	await foto(b, "areia_em_pe")
	await _posar(b, "dormindo", false)
	var deitada := _altura_da_cabeca(b)
	var caixa: Vector3 = b._forma_dano.size
	ok(b.animador.atual == "dormindo" and b.deitada() and deitada < em_pe * 0.4,
		"%s: dormindo, o corpo deita por inteiro (cabeça %.1f m; em pé %.1f m)" % [e, deitada, em_pe])
	ok(caixa.z > caixa.y * 1.5, "%s: deitada, a área de dano fica comprida e baixa (%.1f × %.1f m)" % [e, caixa.z, caixa.y])
	_nivelada(b, "dormindo")
	await foto(b, "dormindo")
	await foto(b, "dormindo_lado", Vector3(22, 4, 0))
	await _posar(b, "nadando_walk", false)
	var andando := _altura_da_cabeca(b)
	ok(b.animador.atual == "andando_terra" and not b.deitada() and andando > em_pe * 0.8,
		"%s: andando na areia fica ereta, como antes (cabeça a %.1f m)" % [e, andando])
	await foto(b, "andando_na_areia")
	# --- 2. Andando de verdade (IA ligada): para onde olha, sem deslizar de lado ---
	if not b.boss():
		b.set_physics_process(true)
		b.agressiva = false
		b.alvo = null
		b.velocity = Vector3.ZERO
		b._voltando = true
		b._banho = false
		b._passeando = false
		b._destino = praia + Vector3(0, 0, 25)        # atrás dela (ela olha −Z)
		b._rotina = 30.0
		b.mudar("nadando_walk")
		var lateral := 0.0
		for i in 90:
			await physics_frame
			var frente: Vector3 = -b.global_basis.z
			var v := Vector3(b.velocity.x, 0, b.velocity.z)
			if v.length() > .3:
				lateral = maxf(lateral, rad_to_deg(v.angle_to(Vector3(frente.x, 0, frente.z))))
		ok(lateral < 12.0, "%s: anda para onde olha (atraso máximo %.1f° enquanto vira)" % [e, lateral])
		b.set_physics_process(false)
	# --- 4. Giro na areia: pedir meia-volta por 1 s ---
	b.global_position = praia
	var giro_terra := await _giro_em(b, false)
	ok(giro_terra <= 36.0 and giro_terra >= 20.0, "%s: na areia vira devagar (%.0f° em 1 s)" % [e, giro_terra])
	ok(b._max_inclina < 0.05, "%s: na areia não inclina o corpo (%.2f rad)" % [e, b._max_inclina])
	# --- 3. Na água ---
	b.global_position = mar
	b.rotation.y = -PI / 2
	await _posar(b, "nadando_walk", true)
	var sup := AguaDoMundo.superficie_em(b.global_position.x, b.global_position.z)
	var cabeca := _osso_y(b, "cabeca") - sup
	var dorso := _osso_y(b, "pescoco_02") - sup
	ok(b.animador.atual == "nadando_walk" and b.deitada(), "%s: nadando, o corpo fica deitado" % e)
	ok(cabeca > 0.3 and dorso < 0.5, "%s: cabeça fora d'água (%.1f m) e o corpo na linha da superfície (%.1f m)" % [e, cabeca, dorso])
	_nivelada(b, "nadando")
	await foto(b, "nadando")
	# No meio do mergulho o corpo vai de nariz para baixo; a cabeça segue nivelada.
	b.mudar("mergulhando")
	for i in 70:
		b.animador.avancar(DT)
		b._postura(DT)
	_nivelada(b, "no meio do mergulho")
	await foto(b, "mergulhando", Vector3(22, 2, 0))
	await _posar(b, "idle", true)
	ok(b.animador.atual == "boiando" and not b.deitada(), "%s: parada na água boia em pé, como a foca \"de garrafa\"" % e)
	await foto(b, "boiando")
	await _posar(b, "nadando_submerso", true)
	_nivelada(b, "submersa")
	await foto(b, "submersa", Vector3(16, -1, -14))
	var giro_agua := await _giro_em(b, true)
	ok(giro_agua >= 80.0 and giro_agua <= 125.0, "%s: na água vira ágil (%.0f° em 1 s)" % [e, giro_agua])
	ok(b._max_inclina > 0.15, "%s: nadando, inclina o corpo na curva (%.2f rad)" % [e, b._max_inclina])
	ok(b.get_meta("tombo_da_cabeca", 99.0) < 6.0, "%s: na curva inclinada a cabeça não tomba (máx. %.1f°)" % [e, b.get_meta("tombo_da_cabeca", 99.0)])
	b.global_position = b.origem
	b.rotation.y = 0.0
	b._pivo.rotation.z = 0.0


## Põe a besta num estado com a IA parada: o clipe do meio (areia/água), a transição
## de postura inteira e a fundura na água assentada.
func _posar(b: Node, estado: String, agua: bool) -> void:
	b.nadando = agua
	b.mudar(estado)
	for i in 150:
		b.animador.avancar(DT)
		b._postura(DT)
		if agua:
			b.global_position.y = AguaDoMundo.superficie_em(b.global_position.x, b.global_position.z) - b._calado
	b._relogio_dano = 0.0
	b._postura(DT)
	await process_frame


## Ângulo virado em 1 s pedindo meia-volta, com a postura e o meio forçados.
func _giro_em(b: Node, agua: bool) -> float:
	b.nadando = agua
	b.animador.mudar("nadando_walk" if agua else "andando_terra")
	b._giro = 0.0
	b._pivo.rotation.z = 0.0
	var antes: float = b.rotation.y
	var atras: Vector3 = b.global_basis.z          # rumo pedido: meia-volta
	var maior := 0.0
	var tombo := 0.0
	for i in 60:
		b._encarar(atras, DT)
		b.animador.avancar(DT)
		b._postura(DT)
		maior = maxf(maior, absf(b._pivo.rotation.z))
		if agua:
			tombo = maxf(tombo, _angulos_da_cabeca(b).y)
		if agua and i == 30:
			await foto(b, "curva_na_agua_meio", Vector3(0, 6, -22))
		await process_frame
	b._max_inclina = maior
	b.set_meta("tombo_da_cabeca", tombo)
	return rad_to_deg(absf(wrapf(b.rotation.y - antes, -PI, PI)))


func _osso_y(b: Node, osso: String) -> float:
	var rig: Skeleton3D = b.animador.rig
	rig.force_update_all_bone_transforms()
	return (rig.global_transform * rig.get_bone_global_pose(rig.find_bone(osso))).origin.y


## Medida INDEPENDENTE da conta que nivela a cabeça (a régua é a besta parada em pé e
## a gravidade): (inclinação do vetor junta→boca, tombo do eixo lateral do osso,
## rumo do vetor junta→boca em relação ao corpo), em graus.
func _angulos_da_cabeca(b: Node) -> Vector3:
	var rig: Skeleton3D = b.animador.rig
	rig.force_update_all_bone_transforms()
	var cab := rig.global_transform * rig.get_bone_global_pose(rig.find_bone("cabeca"))
	var boca: Vector3 = b.animador.boca() - cab.origin
	var lateral := cab.basis.orthonormalized().x
	var corpo: Vector3 = -b.global_basis.z
	var rumo := rad_to_deg(Vector2(corpo.x, corpo.z).angle_to(Vector2(boca.x, boca.z)))
	return Vector3(rad_to_deg(asin(clampf(boca.normalized().y, -1.0, 1.0))), rad_to_deg(asin(clampf(absf(lateral.y), 0.0, 1.0))), rumo)


## Igual à besta parada em pé na areia (`_ref_cabeca`, medida no começo) e sem tombar.
func _nivelada(b: Node, quando: String) -> void:
	var a := _angulos_da_cabeca(b)
	var r: Vector3 = b.get_meta("ref_cabeca")
	ok(absf(a.x - r.x) < 5.0 and a.y < 5.0 and absf(a.z - r.z) < 5.0,
		"%s: %s, a cabeça olha à frente na horizontal (vs. em pé: inclinação %+.1f°, rumo %+.1f°; tombo %.1f°)" % [b.especie, quando, a.x - r.x, a.z - r.z, a.y])


func _altura_da_cabeca(b: Node) -> float:
	return _osso_y(b, "cabeca") - b.global_position.y
